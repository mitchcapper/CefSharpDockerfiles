# CefSharp Dockerfiles
<!-- MarkdownTOC autolink="true" -->

- [Summary](#summary)
- [Thanks](#thanks)
- [Quick Start](#quick-start)
- [Caveats](#caveats)
- [Requirements](#requirements)
- [Server Setup](#server-setup)
	- [Docker For Windows Config File](#docker-for-windows-config-file)
	- [Azure Specifics](#azure-specifics)
		- [Azure Auto Create Scripts](#azure-auto-create-scripts)
	- [Estimated time requirements](#estimated-time-requirements)
	- [HyperV Isolation \(for server or Windows 10 client\) Mode](#hyperv-isolation-for-server-or-windows-10-client-mode)
- [Build Process](#build-process)
	- [Dual Build Flag](#dual-build-flag)
- [Docker for Windows Caveats](#docker-for-windows-caveats)
	- [How requirements were determined](#how-requirements-were-determined)
- [Patching CEF / CEFSharp](#patching-cef--cefsharp)
- [Building only CEF or CEFSharp](#building-only-cef-or-cefsharp)
- [General Warnings for build flags:](#general-warnings-for-build-flags)
- [Additional Resources](#additional-resources)

<!-- /MarkdownTOC -->

## Summary
Automated chrome cef building and/or cefsharp building dockerfiles and scripts.

While the processes of building CEF and CEFSHARP are not hard they require a very exacting environment and build steps can take a _long_ time so are annoying to repeat.  The goal if this repo is a collection of scripts to automate everything to make it easy for anyone to do.  We are using Docker to run everything in a container as it makes it much easier to reproduce and won't pollute your dev environment with all the pre-reqs.  You can easily tweak the exact versions you want to build, and the build flags.  From creating a VM on your cloud provider of choice (or your own machine) it is about 20 minutes of setup, starting a build script, and just waiting a few hours for it to spit out the compiled binaries.  It has been tested with 63, 65, and 67 but would likely work for any modern chrome build without changes (in most cases).


## Thanks
Thanks to the fantastic CEFSharp team, especially @amaitland who works insanely hard on the open source project.  @perlun provided some great direction on the Windows building and was also a huge help.  Please support CEFSharp if you use it, even if you do a small monthly donation of $10 or $25 it can be a big help: https://salt.bountysource.com/teams/cefsharp

## Quick Start
For a super fast start look at the [azure auto provision option below](#azure-auto-create-scripts).  As long as you have an azure account created it can create the entire setup and build in a few commands.
If using Azure create a F32_v2 VM with the image "Windows Server 2016 Datacenter - with Containers", if using another machine just install docker for windows (make sure you have 20GB (40GB for chrome < 65) of ram between actual ram + page file). Set the [Docker For Windows Config File](#docker-for-windows-config-file) changing the path to the folder to store data on (suggested local temp drive) and restart docker service.   Copy the items from this repo into a folder. Copy the versions_src.ps1 to versions.ps1 and change the variables to what you want: for example ```$VAR_GN_DEFINES="is_official_build=true proprietary_codecs=true ffmpeg_branding=Chrome";$VAR_DUAL_BUILD="1";```. Only use DUAL_BUILD if you have 30 gigs of ram or more, otherwise leave it at 0 and the build will take an extra 20-40 minutes.  If you are building in process isolation mode (recommended) make sure the base image file is the same build as your actual OS.  IE if you are on windows Fall 2018 release 1803 (10.0.17134) change VAR_BASE_DOCKER_FILE to the 1803 image. Run ./build.ps1 and it should build the packages. 


## Caveats
Beware if using the exact same version string as an official CEF Build as it will mean you need to make sure your nuget source is always used before the master source.  If you use a slightly different minor build you will not have that problem.  For CefSharp you can use a manual higher fake minor version number(ie .99) to not get confused with the official builds (but the CEF build note above still applies).

In part we use the latest version of several installers/build tools if they changed so might the success of these dockerfiles.  It does not build the debug versions of CEF or CEFSharp.   This could be added as an option pretty easily (but would probably at-least double build times). For some reason I had issues getting the automated build script for CEF to work doing the calls by hand is pretty basic however.

Window 10 Client (Pro) by default with docker uses HyperV isolation, this mode is very non performant vs process isolation mode.

## Requirements
The following requirements are for chrome 63(and more or less 65 and 67) and the current vs_2017 installer, they may change over time.  Compiling is largely CPU bound but linking is largely IO bound.

- At least 20GB of ram dedicated to this would recommend 30GB total with page file to make sure you don't run out (older builds like 63 were 32GB with 40GB total).  You can have any amount of that 20/30GB as a page file, just beware the less actual ram the much slower linking will be.
- At least 250GB of space.


## Server Setup
There is not much in terms of a software requirements other than docker. You can run it on Windows Server or Windows 10 Client.
For Windows 10 Client Install it from https://store.docker.com/editions/community/docker-ce-desktop-windows. For server Docker EE from: https://docs.docker.com/install/windows/docker-ee/#docker-universal-control-plane-and-windows (or standard docker for windows for desktops) if docker is not auto installed.   If installing on Windows 10 Client make sure to see the Hyper V Notes below.

### Docker For Windows Config File
You will want a docker configuration with options similar to this. Note if you are on Windows 10 Client you will need to leave isolation=hyperv in the config file.  On windows client you can use the docker settings (Right-click on the Docker whale icon in the on the task bar, then click "Settings..." then click to advanced mode). For server the file is edited directly (or created if it didn't exist) at C:\ProgramData\docker\config\daemon.json
```
{
  "registry-mirrors": [],
  "insecure-registries": [],
  "debug": true,
  "experimental": false,
  "exec-opts": [
    "isolation=process"
  ],
  "data-root": "d:/docker_data",
  "storage-opts": [
    "size=400G"
  ]
}
```
### Azure Specifics
If you are new to Azure it is pretty easy to get started and they will give you $200 for your first month free so there will be no costs. Below we even have an auto deploy script if you prefer not to do it by hand.
An Azure F32 v2 is pretty good, its only 256 gigs of space but that should be ok.  ~$2.72 an hour in WestUS2 running the latest windows image. You can use the prebuilt image "Windows Server 2016 Datacenter - with Containers" or a newer one if it exists.  You can either use one with a full shell (pre 1709) or one of the newer builds like "Windows Server 2016 Datacenter - with Containers 1803".  Without a full shell you won't have explorer and remote desktop will just open a command prompt. You can launch notepad and manage it all through there (or use remote PS) but a full shell is easier for some people.  Use the local SSD as the docker storage folder (note this will likely get wiped if you de-allocate the machine so do the entire build at once).  You could potentially hook up a huge number of disks in raid 0 configuration to get somewhat decent speed that way.
Create a new resource, search for the prebuilt image noted above.  You do not need managed disks, assign a random user/password, new network/storage/etc is all fine.  For the size make sure you select one of the F series (F32 recommended). It won't show by default, leave HD type set to SSD put Min CPU's at 32 and Ram at 64 then hit "View all".

I suggest auto-shutdown to make sure you don't leave it running.

#### Azure Auto Create Scripts
If you have an azure account already created you can use the az_create.ps1 script to automatically setup the VM for you.  It will create everything under a new "CEFTest" resource group to make cleanup at the end easy. You can adjust the settings at the top if desired but really the only important options you pass as options to it.  It will setup the VM and enable remote powershell to make the process very easy. Just launch powershell (or type powershell into the run box in windows).  If the first time using powershell with azure you will need to install the tools for azure: ```Install-Module -Name AzureRM -Scope CurrentUser```.  Next change to the folder with all the CefSharpDockerfiles (cd c:\downloads\CefSharpDockerfiles for example).

Login with your azure credentials first:
```Connect-AzureRmAccount```

Then if you have multiple subscriptions set the one you want with:
```Set-AzureRmContext -SubscriptionName "My Subscription"```

Next run this and enter a new username and password to configure the new VM with:
```$cred = Get-Credential -Message "Enter user and password for remote machine admin"```

Next we will run the deploy script, by default it can configure the machine to automatically shutdown at 11:30 PDT if you provide an email it will do this and notify you.  If you do not you need to manually turn the machine off when done. You can adjust time and such in the az_create.ps1 at the top (along with some other items but likely you do not need to adjust them):
```./az_create.ps1 -admin_creds $cred -shutdown_email "john@gmail.com"```

It should print out when done Public IP: 123.123.123.123

Next set this in a variable $IP_ADDY like:
```$IP_ADDY = "123.123.123.123"```

**Note we are disabling the security checks in the remote powershell session.  This could make you vulnerable to MITM attacks if on an unsafe network.**

Next create the remote powershell session and copy the files over by running:
```
$so = New-PsSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck;
$remote = New-PSSession -ComputerName $IP_ADDY -UseSSL -SessionOption $so -Credential $cred;

Invoke-Command -Session $remote $_ -ScriptBlock { mkdir C:/CefSharpDockerfiles; }
Get-ChildItem -Path "./" | Copy-Item -ToSession $remote -Destination "C:/CefSharpDockerfiles/"

Copy-Item -ToSession $remote daemon.json -Destination "c:/ProgramData/docker/config/daemon.json";
Invoke-Command -Session $remote $_ -ScriptBlock { Restart-Service Docker; }
```

Next we will "enter" the remote machine via powershell:
```
Enter-PSSession $remote
```

Then you should see your terminal is like ```[123.123.123.123]: PS c:\>``` showing you are on the remote machine.

Finally we start the build:
```
cd C:/CefSharpDockerfiles
./build.ps1
```

When done exit out the remote session by typing: ```exit```

Finally we copy the resulting files locally:
```Copy-Item -FromSession $remote "c:/CefSharpDockerfiles/packages_cefsharp.zip" -Destination ".";```

You could also expose the docker server to the internet and use remote docker commands rather than running the powershell remotely.  When done you can delete the entire CEFTest resource group from the azure portal as well to clean everything up.


### Estimated time requirements
With the Azure F32 v2 host above the total estimated build time is about 2.1 hours (~$6 on azure). Machines are nice 600MB/sec read/write to the local disk.  The time could be cut close to in half if you used a F64 v2 VM, but your cost will remain the same (as its twice the price for twice the power).  Note it can vary somewhat dramatically for the not cef build steps based on the luck of the draw (but the cef build is most of the build time).  It seems local IO depending on what physical host it is spun up on can cause 30-50% performance fluxes.  Most of the build steps make efficient use of the machine however: The git cloning is not very efficient. It is 30 minutes of the cef build time below. It doesn't quite max out network or IO. The linking stage is also not super efficient see the DUAL_BUILD flag below to help with that. Linking will take 20+ minutes per platform (40 total unless run concurrently).  Here are the individual build/commit times:
- pull source image: 5 minutes
- vs: 11 minutes
- cef: 1.8 hours (with DUAL_BUILD)
- cef-binary: 3 minutes
- cefsharp: 4 minutes

### HyperV Isolation (for server or Windows 10 client) Mode
HyperV isolation mode should be avoided if possible.  It is slower, and more prone to fail.  For Windows 10 client there is not a **legal** alternative.  NOTE: If you are not using process isolation mode you WILL need to set ```$VAR_HYPERV_MEMORY_ADD``` and make sure your page file is properly sized (recommend a page file at least a few gigs bigger as it needs that amount of FREE page file space).  It will set the memory on every docker build step to up the default memory limit.  Technically this is primarily needed in the CEF build step.   NOTE if you stop docker during a build with HyperV it does not properly kill off the hyperV container restart docker to fix this.

## Build Process
Once docker is setup and running copy this repo to a local folder.  Copy versions_src.ps1 to versions.ps1 and change the version strings to match what you want.  NOTE BASE_DOCKER_FILE must match the same kernel as the host machine IF you are using process isolation mode.  This means you cannot use the 1709 image on an older host and you can use and older image on a 1709 host.  Either base file is fine however to use just match it to the host.  

Next run build.ps1 and if you are lucky you will end up with a cefsharp_packages.zip file with all the nupkg files you need:)  Beware that as docker might be flaky(especially in hyperV mode) you may need to call build.ps1 a few times.  It should largely just resume.   Once it is done building you will have the cefsharp_packages.zip file.  If you want any of the CEF binaries, or symbol files, you can copy them from the CEF image like: ```docker cp cef:c:/code/binaries/*.zip .```

To be safer you can run the biggest build command by hand. The hardest (longest) build step if the CEF build at the start. You can comment out the last step in the dockerfile and manually do that step and commit it.  Infact you can just docker run the build image from before than manually call cef_build.ps1 one or more times (it should do a decent job at auto-resuming) until success.  If you are using a proper host with enough ram it should be able to automatically  build 9 times out of 10 (if not higher) with its current redundant tries.  Of course if you prefer to manually run the commands from it you can do that too. To do so comment out the final build step in Dockerfile_cef then run the following:
```
	#So if the autmate-git.py doesn't work (if something errors out it doesn't always stop at the right point) try running the build steps manually that are there.
	# From the c:/code/chromium/src folder run the build hooks to download tools: gclient runhooks
	# From the c:/code/chromium/src/cef folder run the following to make the projects: ./cef_create_projects.bat
	# From the c:/code/chromium/src
	# ninja -C out/Release_GN_x64 cefclient
	# ninja -C out/Release_GN_x86 cefclient
	# cd C:/code/chromium/src/cef/tools/
	# C:/code/chromium/src/cef/tools/make_distrib.bat --ninja-build --allow-partial;
	# c:/code/chromium/src/cef/tools/make_distrib.bat --ninja-build --allow-partial --x64-build;
	# Allow partial needed if not building debug builds, make sure to run it when done or run the cef_build last few commands to create the archive with the result and to clean up the workspace of the source files.
```
### Dual Build Flag
Note the DUAL_BUILD may speed up builds by running x86 and x64 builds concurrently (each with 1/2 as many threads).  This is primarily useful during linking.  Linking is largely single threaded and takes awhile and is single thread CPU bound (given enough IO). The main issue is memory usage.  If both linking steps run at once you may need nearly 30GB of memory at once (in worst case older builds would use up to 50GB).  It would be better if they linked at slightly separate times but as every compute system was different there did not seem to be a good way to determine how long to sleep for to make it most efficient.


## Docker for Windows Caveats
- Most of these issues become an issue on the longer docker runs and disk speed. On an Azure VM it rarely fails out.  There has been some redundancy added to build scripts to address these issues.
- It is slow and Docker for windows can be flaky (especially in HyperV mode). Keep in mind this is running latest 16299 w/ 32 gigs of ram. Sometimes it will miss a step that should be cached and redo it. It seems less flaky running docker in process isolation mode (--isolation=process) instead of hyper-v mode.  This is a legal compile time limitation however that windows clients cannot use this mode.  Granted building your own docker windows binary is also not that hard.  If using hyperv mode please see the server setup for HyperV notes.
- Make sure to disable file indexing on the drive used for docker data and DISABLE any anti-virus / windows defender it will hugely slow you down.  The build script will try to notify you if it notices defender is doing real time monitoring.  If you are using a dedicated build drive (in azure or locally) disabling indexing is recommended: To disable file indexing right  click on the drive and uncheck allow indexing.  If you leave indexing on it may slow building down but should not break anything.
- Space is massively hogged and it is super slow with large numbers of small files and large files are rewritten 3 extra times when a container is committed.  To avoid this we will remove repos/etc used during a build step before it finishes to speed things up. 
- windowsfilter behind the scenes is exceptionally non performant.  This primarily comes into play after a build step is finished and it needs to create the diff for the result.  First you work in the vhd file, so all changes made while it is building or you are running it happen in the VHD.	Second after commit / build step finishes the container will exit. Docker will not return until it fully commits this build step (but the container will NOT show running). Docker starts the diff with the VHD and copies all the files for that layer to docker_data\tmp\random_id\.  Oddly it actually seems to create one random tmp random id folders with duplicate data from the VM, then it reads each file in this tmp folder writing it to another docker-data\tmp\random_id\ folder.  It slowly deletes from one of them once it finishes writing the second.   Then it makes another copy to the docker_data\windowsfilter\final_id permanent folder then removes the temp folder and the original VHD.   I am not sure why all the copying.  This can take A LONG time (hours on a 7200 rpm drive), the only way to know if this is going on is watch your storage. If docker is writing then its doing it.  Use procmon.exe if it is reading from a VHD writing to a tmp folder then its step 1.  If it is reading from one tmp folder and writing to another tmp folder that is step 2.  If it is reading from a tmp folder and writing to a windowsfilter sub folder then it is on the final step 3.  
- Sometimes docker may start to mis-behave often restarting docker may fix the problem.  Sometimes a full reboot is needed.

### How requirements were determined
- Space: windows base ~6 gigs, ~9 gigs for the finished visual studio build image.  Another 20 or so when done with cefsharp.   Chrome will take 200 gigs or so during build for the VHD, we remove the bulk of this before it finishes though.  So for docker storage I would recommend 16 + 200 = ~ 220 gigs of space + some buffer so maybe 250GB. 
- Memory: For Chrome 63 bare minimum memory requirements (actual + page file) for JUST the linker is x86: 24.2 GB x64: 25.7 GB. For chrome 67 however the memory requirements are much lower, only 13GB for linking! I would make sure you have at least 24 gigs of ram to be safe with OS and other overhead, for older versions at least 32GB.

## Patching CEF / CEFSharp
- If so desired you can patch CEF or CEFSharp relatively easily. Place a file named cef_patch_XXXX.diff or cefsharp_patch_XXXX.diff to the build folder. You can change XXX to whatever you want, and even have multiple if desired. It will automatically be applied with git apply.  This works for several different patch formats (anything git apply will take will work).

## Building only CEF or CEFSharp
- You can build just CEF and not cefsharp by setting $VAR_CEF_BUILD_ONLY to $true in the versions.ps1. 
- If you want to only build CEFSharp you will need to provide the CEF binaries (either you built or official ones from: http://opensource.spotify.com/cefbuilds/index.html). You should download both 32 bit and 64 bit standard distribution versions and put them in a local folder.  Then edit versions.ps1 and set $VAR_CEF_USE_BINARY_PATH to the local folders. You should then set $VAR_CEF_BINARY_EXT to the extension of them (ie zip or tar.bz2 for example).

## General Warnings for build flags:
- Cannot do component builds as it will not work for other items
- Remove_webcore_debug_symbols seemed to also cause issues
- DON'T USE is_win_fastlink as it is only for debug builds not for release
- YOU MUST DO A --quiet VS install for headless, otherwise it will just hang forever.
- use_jumbo_build see http://magpcss.org/ceforum/viewtopic.php?p=37293 about enabling this if you are doing proprietary_codecs as well, note this does not seem to actually cause a problem however in the builds we tested.

## Additional Resources
The following were helpful:
- http://perlun.eu.org/en/2017/11/30/building-chromium-and-cef-from-source
- https://bitbucket.org/chromiumembedded/cef/wiki/MasterBuildQuickStart.md
- https://docs.microsoft.com/en-us/visualstudio/install/advanced-build-tools-container
- https://docs.microsoft.com/en-us/visualstudio/install/build-tools-container
- https://chromium.googlesource.com/chromium/src/+/lkcr/docs/windows_build_instructions.md
