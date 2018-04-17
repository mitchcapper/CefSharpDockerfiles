Set-StrictMode -version latest;
$ErrorActionPreference = "Stop";

$VARS = @{ ####NOTE: Due to a limitation in this script and dockerfiles you cannot have any of these be empty.  For example GN_DEFINES is set to is_debug=false which does not alter or build in any way, as we are building release, but we need to have something in there.
			GN_DEFINES="is_debug=false";
			GYP_DEFINES="target_arch=x64 "; #use_jumbo_build=true see http://magpcss.org/ceforum/viewtopic.php?p=37293 about enablign this if you are doing proprietary_codecs as well
			CHROME_BRANCH="3239";
			CEFSHARP_VERSION="63.0.90";
            CEF_VERSION_STR="auto"; #can set to "3.3239.1723" or similar if you have multiple binaries that Docker_cefsharp might find
			CEFSHARP_BRANCH="cefsharp/63";
			DUAL_BUILD="0"; #set to one to build x86 and x64 together, mainly to speed up linking which is single threaded, note may need excess ram
};



$files = @(dir -Filter "Dockerfile_*" .);
$WorkingDir = split-path -parent $MyInvocation.MyCommand.Definition;

foreach ($file in $files){
	$file = Join-Path $WorkingDir $file;
	$content = [system.io.file]::ReadAllText($file);
	$before_content = $content;
	foreach ($key in $VARS.Keys){
		$content = $content -replace ("ENV " + $key + "[^\r\n]+"), ("ENV " + $key + " " + $VARS.$key);
	}
	$file_new = $file; #inplace update
	if ($content -ne $before_content){
		Write-Host Updated $file_new;
		$content | Out-File $file_new -Encoding ASCII;
	}
}