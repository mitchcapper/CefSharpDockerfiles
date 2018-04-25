Set-StrictMode -version latest;
$ErrorActionPreference = "Stop";
$WorkingDir = split-path -parent $MyInvocation.MyCommand.Definition;
. (Join-Path $WorkingDir 'functions.ps1')

$patches = dir . -Filter cefsharp_patch_*.diff;
foreach($patch in $patches){
    $name = $patch.Name;
    if ($name -ne "cefsharp_patch_placeholder.diff"){
        RunProc -proc "git" -opts "apply $name";
        Write-Host "Applied patch $name" -Foreground Magenta;
    }
}