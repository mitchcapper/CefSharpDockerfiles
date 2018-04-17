[CmdletBinding()]
Param(
	[Switch] $NoSkip
)

Set-StrictMode -version latest;
$ErrorActionPreference = "Stop";
if ((Get-MpPreference).DisableRealtimeMonitoring -eq $false){
	Write-Host Warning, windows defender is enabled it will slow things down. -Foreground Red 
}

$last_time = Get-Date;
function out {
	Param(
		[Parameter(Mandatory = $true, ParameterSetName = "ByPath", Position = 0)]
  		$FilePath,
		[Parameter(Mandatory = $true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true, ParameterSetName = "ByPath", Position = 1)]
  		$InputObject,
  		[switch] $Append
  		)
		Begin {
			if (! $Append){
				Out-File -FilePath $FilePath -Encoding ASCII;
			}
		}
		Process {
				Out-File -Append -InputObject $InputObject -FilePath $FilePath	-Encoding ASCII
		}
}

Function RunProc{
    [CmdletBinding()]
    Param($proc,$opts,
    [switch] $errok)
    Write-Verbose "Running: $proc $opts"
    if ($proc.ToUpper().EndsWith(".PL")){
        $path = (C:\Windows\system32\where.exe $proc | Out-String).Trim()
        $opts = "$path $opts";
        $proc="perl";       
    }
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $proc
    $working = Convert-Path .
    $pinfo.WorkingDirectory = $working
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $opts
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    if ($p.ExitCode -ne 0 -and -not $errok){
        throw "Process $proc $opts exited with non zero code aborting!" 
    }
    if ($errok){
        return $p.ExitCode;
    }
}

Function TimerNow($name){
	$now = Get-Date;
	$diff = ($now -  $start_time).TotalSeconds.ToString("0.0");
	Write-Host $name took $diff  -ForegroundColor Green;
	$last_time = $now;
}
$start_time = Get-Date;
$end_time = Get-Date;


echo packages_cefsharp.zip | out .dockerignore
echo binaries.zip | out .dockerignore -Append
if (! (Test-Path ./binaries.zip -PathType Leaf) -or $NoSkip){
	TimerNow("Starting");
	RunProc -proc "docker" -opts "build -f Dockerfile_vs -t vs ."
	TimerNow("VSBuild");
	RunProc -proc "docker" -opts "build -f Dockerfile_cef -t cef ."
	TimerNow("CEF Build");
	docker rm cef
	RunProc -proc "docker" -opts "run --name cef cef cmd /C echo CopyVer"
	RunProc -proc "docker" -opts "cp cef:/binaries.zip ."
	TimerNow("Copy CEF Binary Local (1GB+)");
	echo packages_cefsharp.zip  | out .dockerignore
	RunProc -proc "docker" -opts "build -f Dockerfile_cef_compiled -t cef_compiled ."
	TimerNow("Add CEF package to clean cef_compiled image");
	echo binaries.zip | out .dockerignore -Append
}else{
		Write-Host binaries.zip already exists, skipping initial vs, cef, and cef_compiled build. Use flag NoSkip to avoid this. -ForegroundColor Red
}
RunProc -proc "docker" -opts "build -f Dockerfile_cef_binary -t cef_binary ."
TimerNow("CEF Binary compile");
RunProc -proc "docker" -opts "build -f Dockerfile_cefsharp -t cefsharp ."
TimerNow("CEFSharp compile");
docker rm cefsharp
RunProc -proc "docker" -opts "run --name cefsharp cefsharp cmd /C echo CopyVer"
RunProc -proc "docker" -opts "docker cp cefsharp:/packages_cefsharp.zip ."