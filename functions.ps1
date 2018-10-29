Set-StrictMode -version latest;
$ErrorActionPreference = "Stop";
Function RunProc{
    [CmdletBinding()]
    Param($proc,$opts,
    [switch] $errok,
    [switch] $dry_run,
    [switch] $no_wait,
    [ValidateSet("verbose","host","none")] 
	[String] $verbose_mode="host"
    )
    if ($proc.ToUpper().EndsWith(".PL")){
        $path = (C:\Windows\system32\where.exe $proc | Out-String).Trim()
        $opts = "$path $opts";
        $proc="perl";       
    }
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo;
    $pinfo.FileName = $proc;
    $working = Convert-Path .;
    $verbose_str = "Running: $proc $opts in $working";
    if ($verbose_mode -eq "host"){
    	Write-Host $verbose_str -Foreground Green;
    }elseif($verbose_mode -eq "verbose"){
		Write-Verbose $verbose_str;
    }
    $pinfo.WorkingDirectory = $working;
    $pinfo.UseShellExecute = $false;
    $pinfo.Arguments = $opts;
    $p = New-Object System.Diagnostics.Process;
    $p.StartInfo = $pinfo;
    if ($dry_run){
    	return $null;
    }
    $p.Start() | Out-Null;
    if ($no_wait){
    	return $p;
    }
    $p.WaitForExit();
    if ($p.ExitCode -ne 0 -and -not $errok){
        throw "Process $proc $opts exited with non zero code: $($p.ExitCode) aborting!" ;
    }
    if ($errok){
        return $p.ExitCode;
    }
}
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
Function confirm($str){
	return $PSCmdlet.ShouldContinue($str, "");
}
$global:last_time = Get-Date;
$global:PERF_FILE="";
Function TimerNow($name){
	$now = Get-Date;
	$diff = ($now -  $global:last_time).TotalSeconds.ToString("0.0");
	$str = "$(Get-Date) $name took $diff secs";
	Write-Host $str  -ForegroundColor Green;
	if ($PERF_FILE -ne ""){
		$str | out -FilePath $PERF_FILE -Append;
	}
	$global:last_time = $now;
}
Function WriteException($exp){
	write-host "Caught an exception:" -ForegroundColor Yellow -NoNewline
	write-host " $($exp.Exception.Message)" -ForegroundColor Red
	write-host "`tException Type: $($exp.Exception.GetType().FullName)"
	$stack = $exp.ScriptStackTrace;
	$stack = $stack.replace("`n","`n`t")
	write-host "`tStack Trace: $stack"
}