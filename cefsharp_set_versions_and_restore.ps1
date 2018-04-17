Set-StrictMode -version latest;
$ErrorActionPreference = "Stop";

Function UpdateProject($path,$original_version,$new_version){
    $xml = [xml](Get-Content ($path));
    Write-Host  doing $path;
    $node = $xml.SelectSingleNode("//Project/Import/@Project");
    $ns = new-object Xml.XmlNamespaceManager $xml.NameTable
    $ns.AddNamespace("msb", "http://schemas.microsoft.com/developer/msbuild/2003")
    $nodes = $xml.SelectNodes("//msb:Import",$ns);
    $changed = $false;
    foreach ($node in $nodes){
        if ($node.HasAttribute("Project") -and $node.Project -like "*" + $original_version + "*"){
            $node.Project = $node.Project -replace $original_version, $new_version;
            $changed=$true;
        }
        if ($node.HasAttribute("Condition") -and $node.Condition -like "*" + $original_version + "*"){
            $node.Condition = $node.Condition -replace $original_version, $new_version;
            $changed=$true;
        }
    }
    if ($changed){
        $xml.Save($path);
        Write-Host Updated $path;
    }
}



$WorkingDir = split-path -parent $MyInvocation.MyCommand.Definition;
if ($env:CEF_VERSION_STR -eq "auto"){
    $name = (dir -Filter cef.redist.x64.*.nupkg $env:PACKAGE_SOURCE)[0].Name;
    $name = ($name -replace "cef.redist.x64.", "") -replace ".nupkg", "";
    if ($name -and $name.StartsWith("3." + $env:CHROME_BRANCH) ) {
        $env:CEF_VERSION_STR = $name;
        setx /M CEF_VERSION_STR $env:CEF_VERSION_STR;
    }
}

$CefSharpCorePackagesXml = [xml](Get-Content (Join-Path $WorkingDir 'CefSharp.Core\Packages.config'))
$original_version = $CefSharpCorePackagesXml.SelectSingleNode("//packages/package[@id='cef.sdk']/@version").value;



$nuget = Join-Path $WorkingDir ".\nuget\NuGet.exe"
if(-not (Test-Path $nuget)) {
    Invoke-WebRequest 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile $nuget;
}


$sdk_path = [io.path]::combine($env:PACKAGE_SOURCE,"cef.sdk." + $env:CEF_VERSION_STR + ".nupkg");

if(-not (Test-Path $sdk_path)) {
    throw "The sdk and redist packages should be in the $env:PACKAGE_SOURCE folder but $sdk_path is missing";
}
#Check each subfolder for a packages.config, then check each for any of the 3 values
$CHECK_IDS = ("cef.sdk","cef.redist.x64","cef.redist.x86");
$folders = dir -Directory;
foreach ($folder in $folders){
    $package_config_path = [io.path]::combine($WorkingDir,$folder,'Packages.config');
    if(-not (Test-Path $package_config_path)) {
        continue;
    }
    $xml = [xml](Get-Content ($package_config_path));
    $changed=$false;
    foreach ($node_name in $CHECK_IDS){
        $node = $xml.SelectSingleNode("//packages/package[@id='" + $node_name +"']/@version");
        if ($node -and $node.value -ne $env:CEF_VERSION_STR){
            $changed=$true;
            $node.value = $env:CEF_VERSION_STR;
        }
    }
    if ($changed){
        $xml.Save($package_config_path);
        Write-Host Updated $package_config_path;
    }
    $projects = dir $folder -Filter *.*proj;
    foreach($project in $projects){
        $project_path = [io.path]::combine($WorkingDir,$folder,$project );
        UpdateProject $project_path $original_version $env:CEF_VERSION_STR;
    }
}
#Previously there was a bug in 63 where vs2017 was flagged as 2015 for the bin packages.
$props_path = "CefSharp.props";
$content = Get-Content $props_path;
$bad_str = "'15.0'`">2015</VisualStudioProductVersion>";
$good_str = "'15.0'`">2017</VisualStudioProductVersion>";
if ($content -like "*" + $bad_str    + "*"){
    $content = $content -replace $bad_str   , $good_str;
    $content > $props_path;
    Write-Host  Updated $props_path;
}
$args = "restore -source `"$env:PACKAGE_SOURCE`" -FallbackSource https://api.nuget.org/v3/index.json CefSharp3.sln";
$p = Start-Process -Wait -PassThru -FilePath $nuget -ArgumentList $args;
if (($ret = $p.ExitCode) ) { throw ('Install failed with exit code 0x{0:x}' -f $ret) };
