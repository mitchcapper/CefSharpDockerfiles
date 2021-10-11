Set-StrictMode -version latest;
$ErrorActionPreference = "Stop";
$WorkingDir = split-path -parent $MyInvocation.MyCommand.Definition;
. (Join-Path $WorkingDir 'functions.ps1')

if (! $env:ARCHES){
	$env:ARCHES = "x86 x64 amd64";
}
$ARCHES = $env:ARCHES.Split(" ");
$ARCHES_TO_BITKEY = @{};
foreach ($arch in $ARCHES) {
	$arch_bit = $arch;
	if ($arch_bit.StartsWith("x")) {
		$arch_bit = $arch.Substring(1);
		if ($arch_bit -eq "86"){
			$arch_bit = "32";
		}
		$ARCHES_TO_BITKEY[$arch] = $arch_bit;
	}
}


Function CopyBinaries{
	foreach ($arch in $ARCHES) {
		$arch_bit = $ARCHES_TO_BITKEY[$arch];
		if (@(dir -Filter "cef_binary_*_windows$($ARCHES_TO_BITKEY[$arch]).$env:BINARY_EXT" "c:/code/chromium_git/chromium/src/cef/binary_distrib/").Count -ne 1){
			throw "Not able to find win$ARCHES_TO_BITKEY[$arch] file as expected";
		}
	}

	mkdir c:/code/binaries -Force;
	copy-item ("c:/code/chromium_git/chromium/src/cef/binary_distrib/*." + $env:BINARY_EXT) -destination  C:/code/binaries;
	Set-Location -Path /;
	if ($env:CEF_SAVE_SOURCES -eq "1"){
		RunProc -errok -proc ($env:ProgramFiles + "\\7-Zip\\7z.exe") -opts "a -aoa -y -mx=1 -r -tzip c:\code\sources.zip c:/code/chromium_git/chromium";
	}
	echo $null >> c:/code/chromium_git/done
}

$build_args_add = "";
if (! $env:BINARY_EXT){
	$env:BINARY_EXT="zip";
}
if ($env:BINARY_EXT -eq "7z"){
	$env:CEF_COMMAND_7ZIP="C:/Program Files/7-Zip/7z.exe";
}


$env:CEF_ARCHIVE_FORMAT = $env:BINARY_EXT;
if ($env:DUAL_BUILD -eq "1" -and $env:CHROME_BRANCH -lt 3396){ #newer builds can take a good bit more time linking just let run with double the proc count
	$cores = ([int]$env:NUMBER_OF_PROCESSORS) + 2; #ninja defaults to number of procs + 2 
	if ($cores % 2 -eq 1){
		$cores +=1;
	}
	$build_args_add = "-j " + ($cores/2);
}
if (Test-Path c:/code/chromium_git/done -PathType Leaf){
	Write-Host "Already Done just copying binaries";
	CopyBinaries;
	exit 0;
}


Function RunBuild{
    [CmdletBinding()]
    Param($build_args_add,$version)
    return RunProc -verbose_mode "host" -proc "c:/code/depot_tools/ninja.exe" -opts "$build_args_add -C out/Release_GN_$version cefclient" -no_wait;
}

$chrome_data = Invoke-RestMethod -Uri 'https://omahaproxy.appspot.com/all.json'
$win_data = $chrome_data | Where  { $_.os -eq "win64"} | Select -First 1
$branch_data = $win_data.versions | Where {$_.true_branch -eq $env:CHROME_BRANCH} | Select -First 1
$latest_tag = $branch_data.version

if ($Env:SHALLOW -eq "1"){
	if (! (Test-Path /code/chromium_git/cef/.git)){ #we will manually clone this out first time or wont be on right branch
		Runproc -proc "c:/code/depot_tools/git.bat" -opts "clone --depth 1 --branch $env:CHROME_BRANCH https://bitbucket.org/chromiumembedded/cef.git c:/code/chromium_git/cef"; #as shallow fails if they don't speify the branch so we will do it first for them
	}
	if (! (Test-Path /code/chromium_git/chromium/src/.git)){ #as we now use no update for source we need to check it out
		Runproc -proc "c:/code/depot_tools/git.bat" -opts "-c core.deltaBaseCacheLimit=2g clone  --depth=1 --branch $latest_tag --progress https://chromium.googlesource.com/chromium/src.git c:/code/chromium_git/chromium/src";
	}
}

# --no-update can't do no update for first time
RunProc -proc "c:/code/depot_tools/python.bat" -opts "c:/code/automate/automate-git.py --download-dir=c:/code/chromium_git --branch=$env:CHROME_BRANCH --no-build --depot-tools-dir=c:/code/depot_tools  --no-debug-build --no-distrib --no-depot-tools-update"; #not sure why allowed errok before
Set-Location -Path c:/code/chromium_git/cef;
if (! (Test-Path /code/chromium_git/already_patched -PathType Leaf)){
    copy c:/code/*.ps1 .
    copy c:/code/*.diff .
    ./cef_patch.ps1
    if ($env:GN_DEFINES -contains "proprietary_codecs" -and $env:CHROME_BRANCH -lt 3396){
    	#I was unable to generate a patch that worked across branches so manually patching the file per: https://bitbucket.org/chromiumembedded/cef/issues/2352/windows-3239-build-fails-due-to-missing
    	#this is only needed for versions < 3396
    	$str = [system.io.file]::ReadAllText("c:/code/chromium_git/cef/BUILD.gn");
    	$str = $str -replace "deps = \[\s+`"//components/crash/core/common`",", "deps = [`n      `"//components/crash/core/common`",`n      `"//media:media_features`",";
    	$str | Out-File "c:/code/chromium_git//cef/BUILD.gn" -Encoding ASCII;
    }
    Set-Location -Path c:/code/chromium_git/chromium/src/cef
    RunProc -proc "c:/code/chromium_git/cef/cef_create_projects.bat" -errok -opts "";
    "1" > /code/chromium_git/already_patched    
}
Set-Location -Path c:/code/chromium_git/chromium/src;

# track the build procs and build failures per arch
$build_procs = @{}
$build_fails = @{}
foreach ($arch in $ARCHES) {
	$build_fails[$arch] = -1;
}

$MAX_FAILURES=20;

while ($true){
	$retry=$false;
	foreach ($arch in $ARCHES) {
		if ( ! $build_procs.ContainsKey($arch) -or ($build_procs[$arch].HasExited -and $build_procs[$arch].ExitCode -ne 0 -and $build_fails[$arch] -lt $MAX_FAILURES)){
			$build_fails[$arch]++;#starts at -1 so ok to increment first no matter the result;)
			$build_procs[$arch] = RunBuild -build_args_add $build_args_add -version $arch;
	        if ($env:DUAL_BUILD -ne "1"){
	        	$build_procs[$arch].WaitForExit();
	        }
	        $retry=$true;
		}
	}

	$all_exited=$true;
	foreach ($arch in $ARCHES){
		if (! $build_procs[$arch].HasExited){
			$all_exited=$false;
		}
	}
	if ($all_exited -and ! $retry){
		break;
	}
    Start-Sleep -s 15
}
foreach ($arch in $ARCHES){
 	$build_procs[$arch].WaitForExit();
 	if ($build_procs[$arch].ExitCode -ne 0){
		throw "$arch build failed with $($build_procs[$arch].ExitCode)";
	}
}
if ($env:CHROME_BRANCH -ge 4406) { #need to manually build sandbox lib now
	Set-Location -Path C:/code/chromium_git/chromium/src/cef;
	RunProc -proc "c:/code/depot_tools/python.bat" -opts "tools\gn_args.py";

	Set-Location -Path C:/code/chromium_git/chromium/src;	
	foreach ($arch in $ARCHES){

		RunProc -proc "c:/code/depot_tools/gn.bat" -opts "gen out/Release_GN_$($arch)_sandbox";
		RunProc -verbose_mode "host" -proc "c:/code/depot_tools/ninja.exe" -opts "-C out/Release_GN_$($arch)_sandbox cef_sandbox";
	}
}

Set-Location -Path C:/code/chromium_git/chromium/src/cef/tools/;
foreach ($arch in $ARCHES){
	$distrib_add = "--$($arch)-build";
	if ($arch -eq "x86"){
		$distrib_add = "";
	}
	RunProc -proc "C:/code/chromium_git/chromium/src/cef/tools/make_distrib.bat" -opts "--ninja-build --allow-partial $distrib_add";
}

CopyBinaries;
#Remove-Item -Recurse -Force c:/code/chromium_git/chromium; #no longer removing source by default as stored in a volume now