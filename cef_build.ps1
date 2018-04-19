Set-StrictMode -version latest;
$ErrorActionPreference = "Stop";
$WorkingDir = split-path -parent $MyInvocation.MyCommand.Definition;
. (Join-Path $WorkingDir 'functions.ps1')

$build_args_add = "";
if ($env:DUAL_BUILD -eq "1"){
	$cores = (Get-WmiObject -class Win32_processor).NumberOfLogicalProcessors + 2; #ninja defaults to number of procs + 2 
	if ($cores % 2 -eq 1){
		$cores +=1;
	}
	$build_args_add = "-j " + ($cores/2);
}
Function RunBuild{
    [CmdletBinding()]
    Param($build_args_add,$version)
    return RunProc "host" -proc "c:/code/depot_tools/ninja.exe" -opts "$build_args_add -C out/Release_GN_$version cefclient" -no_wait;
}
RunProc -proc "c:/code/depot_tools/python.bat" -errok -opts "c:/code/automate/automate-git.py --download-dir=c:/code --branch=$env:CHROME_BRANCH --no-build --no-debug-build --no-distrib";
Set-Location -Path c:/code/chromium/src/cef;
if (! (Test-Path /code/already_patched -PathType Leaf)){
    "1" > /code/already_patched
    if ($env:GN_DEFINES -contains "proprietary_codecs"){
    	#I was unable to generate a patch that worked across branches so manually patching the file per: https://bitbucket.org/chromiumembedded/cef/issues/2352/windows-3239-build-fails-due-to-missing
    	$str = [system.io.file]::ReadAllText("c:/code/chromium/src/cef/BUILD.gn");
    	$str = $str -replace "deps = \[\s+`"//components/crash/core/common`",", "deps = [`n      `"//components/crash/core/common`",`n      `"//media:media_features`",";
    	$str | Out-File "c:/code/chromium/src/cef/BUILD.gn" -Encoding ASCII;
    }
    RunProc -proc "c:/code/chromium/src/cef/cef_create_projects.bat" -errok -opts "";
}
Set-Location -Path c:/code/chromium/src;
$px64 = RunBuild -build_args_add $build_args_add -version "x64";
$px86 = RunBuild -build_args_add $build_args_add -version "x86";
$MAX_FAILURES=20;
$x86_fails=0;
$x64_fails=0;
#There can be a race conditions we try to patch out the media failures one above
while ($true){
	$retry=$false;
    if ($px86.HasExited -and $px86.ExitCode -ne 0 -and $x86_fails -lt $MAX_FAILURES){
        $x86_fails++;
        $px86 = RunBuild -build_args_add $build_args_add -version "x86";
        $retry=$true;
    }
    if ($px64.HasExited -and $px64.ExitCode -ne 0 -and $x64_fails -lt $MAX_FAILURES){
        $x64_fails++;
        $px64 = RunBuild -build_args_add $build_args_add -version "x64";
        $retry=$true;
    }
    if ($px64.HasExited -and $px86.HasExited -and ! $retry){
    	break;
    }
    Start-Sleep -s 15
}
$px64.WaitForExit();
$px86.WaitForExit();
if ($px64.ExitCode -ne 0){
	throw "x64 build failed with $($px64.ExitCode)";
}
if ($px86.ExitCode -ne 0){
	throw "x86 build failed with $($px86.ExitCode)";
}

Set-Location -Path C:/code/chromium/src/cef/tools/;
RunProc -proc "C:/code/chromium/src/cef/tools/make_distrib.bat" -opts "--ninja-build --allow-partial";
RunProc -proc "C:/code/chromium/src/cef/tools/make_distrib.bat" -opts "--ninja-build --allow-partial --x64-build";
if (@(dir -Filter "cef_binary_3.*_windows32.zip" "c:/code/chromium/src/cef/binary_distrib/").Count -ne 1){
	throw "Not able to find win32 file as expected";
}
if (@(dir -Filter "cef_binary_3.*_windows64.zip" c:/code/chromium/src/cef/binary_distrib/).Count -ne 1){
	throw "Not able to find win64 file as expected";
}
mkdir c:/code/binaries;
copy-item c:/code/chromium/src/cef/binary_distrib/*.zip -destination  C:/code/binaries;
Set-Location -Path /;
Remove-Item -Recurse -Force c:/code/chromium;