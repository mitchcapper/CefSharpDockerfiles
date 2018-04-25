$VAR_CHROME_BRANCH="3239";
$VAR_CEFSHARP_VERSION="63.0.90";
$VAR_CEFSHARP_BRANCH="cefsharp/63";
$VAR_BASE_DOCKER_FILE="microsoft/dotnet-framework:4.7.1-windowsservercore"; #microsoft/dotnet-framework:4.7.1-windowsservercore-1709
$VAR_DUAL_BUILD="0"; #set to 1 to build x86 and x64 together, mainly to speed up linking which is single threaded, note may need excess ram.
$VAR_GN_DEFINES="";
$VAR_GYP_DEFINES="";
$VAR_CEF_BUILD_ONLY=$false;#Only build CEF do not build cefsharp or the cef-binary.
$VAR_CEF_VERSION_STR="auto"; #can set to "3.3239.1723" or similar if you have multiple binaries that Docker_cefsharp might find
$VAR_HYPERV_MEMORY_ADD="--memory=30g"; #only matters if using HyperV, Note your swap file alone must be this big or able to grow to be this big, 30G is fairly safe for single build will need 60G for dual build.
if ($false){ #Sample 65 overrides
	$VAR_CHROME_BRANCH="3325";
	$VAR_CEFSHARP_VERSION="65.0.90";
	$VAR_CEFSHARP_BRANCH="master";
}