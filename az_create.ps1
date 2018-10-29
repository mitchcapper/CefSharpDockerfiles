[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)]
	[PSCredential] $admin_creds,
	[String] $shutdown_email,
	[String] $RESOURCE_GROUP="CEFTest",
	[String] $LOCATION="West US 2",
	[String] $MACHINE_SIZE="Standard_F32s_v2",
	[String] $SHUTDOWN_TIME="23:30",
	[String] $RANDOM_STR=""

)	
Set-StrictMode -version latest
$ErrorActionPreference = "Stop";
$rand_str = $RANDOM_STR;
if (! $rand_str){
	$rand_str = -join ((97..122) | Get-Random -Count 5 | % {[char]$_});
}
$VAULT_NAME = "CEFVault-" + $rand_str;
$SECRET_NAME="CEFPSCertSecret"
$CERT_PASS="dummy"
$SHUTDOWN_TIMEZONE="Pacific Standard Time";
$DIAG_STORAGE_ACT="estdiag86" + $rand_str;
Function WriteException($exp){
	write-host "Caught an exception:" -ForegroundColor Yellow -NoNewline
	write-host " $($exp.Exception.Message)" -ForegroundColor Red
	write-host "`tException Type: $($exp.Exception.GetType().FullName)"
	$stack = $exp.ScriptStackTrace;
	$stack = $stack.replace("`n","`n`t")
	write-host "`tStack Trace: $stack"
}

try{

Write-Host "RANDOM_STR FOR THIS SESSION: $rand_str"
$CERT_PASS_SEC=ConvertTo-SecureString -AsPlainText -Force $CERT_PASS
$cred = $admin_creds
#Connect-AzureRmAccount
#Set-AzureRmContext -SubscriptionName $SUBSCRIPTION

#Create or check for existing resource group
$resourceGroup = Get-AzureRmResourceGroup -Name $RESOURCE_GROUP  -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$RESOURCE_GROUP' does not exist. To create a new resource group, please enter a location.";
    if(!$LOCATION) {
        $LOCATION = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$RESOURCE_GROUP' in location '$LOCATION'";
    New-AzureRmResourceGroup -Name $RESOURCE_GROUP -Location $LOCATION | Out-Null;
}
else{
    Write-Host "Using existing resource group '$RESOURCE_GROUP'";
}


$vault = Get-AzureRmKeyVault -VaultName $VAULT_NAME -ErrorAction SilentlyContinue
if (! $vault){
	Write-Host "Creating key vault to store remote powershell certificate in: $VAULT_NAME"
	New-AzureRmKeyVault -VaultName $VAULT_NAME -ResourceGroupName $RESOURCE_GROUP -Location $LOCATION -EnabledForDeployment -EnabledForTemplateDeployment | Out-Null
	$vault = Get-AzureRmKeyVault -VaultName $VAULT_NAME
}else{
	Write-Host "Vault already exists not re-creating"
}
$certificateName = "CEFRemoteCert"
$secretURL = (Get-AzureKeyVaultSecret -VaultName $VAULT_NAME -Name $SECRET_NAME  -ErrorAction SilentlyContinue)
if (! $secretURL){
	Write-Host "Creating remote PS certificate"
	$thumbprint = (New-SelfSignedCertificate -DnsName $certificateName -CertStoreLocation Cert:\CurrentUser\My -KeySpec KeyExchange).Thumbprint
	$cert = (Get-ChildItem -Path cert:\CurrentUser\My\$thumbprint)
	$fileName = ".\$certificateName.pfx"

	Export-PfxCertificate -Cert $cert -FilePath $fileName -Password $CERT_PASS_SEC
	$fileContentBytes = Get-Content $fileName -Encoding Byte
	$fileContentEncoded = [System.Convert]::ToBase64String($fileContentBytes)

	$jsonObject = @"
	{
	  "data": "$filecontentencoded",
	  "dataType" :"pfx",
	  "password": "$CERT_PASS"
	}
"@

	$jsonObjectBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonObject)
	$jsonEncoded = [System.Convert]::ToBase64String($jsonObjectBytes)

	$secret = ConvertTo-SecureString -String $jsonEncoded -AsPlainText -Force
	Write-Host "Going to store certificate in vault"
	Set-AzureKeyVaultSecret -VaultName $VAULT_NAME -Name $SECRET_NAME -SecretValue $secret | Out-Null
	$secretURL = (Get-AzureKeyVaultSecret -VaultName $VAULT_NAME -Name $SECRET_NAME).Id
}else{
	Write-Host "Secure storage for cert already exists reusing"
	$secretURL = $secretURL.Id;
}

$json = Get-Content 'AzureTemplateParams.json' | Out-String | ConvertFrom-Json

$hashtable = @{}
$json.parameters.PSObject.Properties | Foreach { $hashtable[$_.Name] = $_.Value.value }
if (! $shutdown_email){
	$hashtable.autoShutdownStatus = $hashtable.autoShutdownNotificationStatus = "Disabled";
}
$hashtable.autoShutdownNotificationEmail = $shutdown_email;
$hashtable.PsRemoteSecretVaultID = $vault.ResourceID;
$hashtable.PsRemoteSecretUrl = $secretURL;
$hashtable.adminUsername = $cred.UserName;
$hashtable.adminPassword = $cred.Password;
$hashtable.location = $LOCATION;
$hashtable.diagnosticsStorageAccountName = $DIAG_STORAGE_ACT;
$hashtable.diagnosticsStorageAccountId = "Microsoft.Storage/storageAccounts/" + $DIAG_STORAGE_ACT;
$hashtable.virtualMachineSize = $MACHINE_SIZE;
$hashtable.autoShutdownTimeZone = $SHUTDOWN_TIMEZONE;
$hashtable.autoShutdownTime = $SHUTDOWN_TIME;
$resourceProviders = @("microsoft.network","microsoft.compute","microsoft.storage","microsoft.devtestlab");
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    Register-AzureRmResourceProvider -ProviderNamespace $ResourceProviderNamespace | Out-Null;
}

if($resourceProviders.length) {
    Write-Host "Registering resource providers";
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}


# Start the deployment
Write-Host "Starting deployment...";
New-AzureRmResourceGroupDeployment -ResourceGroupName $RESOURCE_GROUP -TemplateParameterObject $hashtable -TemplateFile 'AzureTemplateFile.json' | Out-Null;
$vm = Get-AzureRmVM -Name "CefTestVM" -ResourceGroupName $RESOURCE_GROUP
$ip =Get-AzureRmPublicIpAddress -Name "CefTestVM-ip" -ResourceGroupName $RESOURCE_GROUP
Write-Host "Public IP: " $ip.IpAddress

}catch{
	WriteException $_;
}