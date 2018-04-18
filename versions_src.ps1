$VAR_CHROME_BRANCH="3239";
$VAR_CEFSHARP_VERSION="63.0.90";
$VAR_CEFSHARP_BRANCH="cefsharp/63";
$VAR_BASE_DOCKER_FILE="microsoft/dotnet-framework:4.7.1-windowsservercore"; #microsoft/dotnet-framework:4.7.1-windowsservercore-1709
$VAR_DUAL_BUILD="0"; #set to 1 to build x86 and x64 together, mainly to speed up linking which is single threaded, note may need excess ram.
$VAR_GN_DEFINES="";
$VAR_GYP_DEFINES=""; #use_jumbo_build=true see http://magpcss.org/ceforum/viewtopic.php?p=37293 about enabling this if you are doing proprietary_codecs as well, note this does not seem to actually cause a problem however in the builds we tested.
$VAR_CEF_VERSION_STR="auto"; #can set to "3.3239.1723" or similar if you have multiple binaries that Docker_cefsharp might find