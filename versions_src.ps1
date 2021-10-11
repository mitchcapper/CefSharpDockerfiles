$VAR_CHROME_BRANCH="3370";
$VAR_CEFSHARP_VERSION="75.0.90";
$VAR_CEFSHARP_BRANCH="cefsharp/75";
$VAR_BASE_DOCKER_FILE="mcr.microsoft.com/windows/servercore:1809-amd64";#mcr.microsoft.com/windows/servercore:1903-amd64
$VAR_DUAL_BUILD="0"; #set to 1 to build all arches together, mainly to speed up linking which is single threaded, note may need excess ram.
$VAR_BUILD_ARCHES="x86 x64 arm64";
$VAR_GN_DEFINES="";
$VAR_CEF_BUILD_MOUNT_VOL_NAME=""; #force using this volume for building, allows resuming MUST BE LOWER CASE
$VAR_GN_ARGUMENTS="--ide=vs2019 --sln=cef --filters=//cef/*";
$VAR_GYP_DEFINES="";
$VAR_CEF_BUILD_ONLY=$false;#Only build CEF do not build cefsharp or the cef-binary.
$VAR_CEF_USE_BINARY_PATH=""; #If you want to use existing CEF binaries point this to a local folder where the cef_binary*.zip files are. It will skip the long CEF build step then but still must make the VS container for the cefsharp building.  Note will copy a dockerfile into this folder.
$VAR_REMOVE_VOLUME_ON_SUCCESSFUL_BUILD=$true;
$VAR_CEF_BINARY_EXT="zip"; #Can be zip,tar.bz2, 7z Generally do not change this off of Zip unless you are supplying your own binaries using $VAR_CEF_USE_BINARY_PATH above, and they have a different extension, will try to work with the other formats however
$VAR_CEF_SAVE_SOURCES="0"; #normally sources are deleted before finishing the CEF build step.  Set to 1 to create a /code/sources.zip archive that has them (note it is left in docker image, must use docker cp to copy it out, it is also around 30GB).
$VAR_CEF_VERSION_STR="auto"; #can set to "3.3239.1723" or similar if you have multiple binaries that Docker_cefsharp might find
$VAR_HYPERV_MEMORY_ADD="--memory=30g"; #only matters if using HyperV, Note your swap file alone must be this big or able to grow to be this big, 30G is fairly safe for single build will need 60G for dual build.
if ($false){ #Sample 65 overrides
	$VAR_CHROME_BRANCH="3325";
	$VAR_CEFSHARP_VERSION="65.0.90";
	$VAR_CEFSHARP_BRANCH="master";
}