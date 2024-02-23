==================
 IMPORTANT NOTICE
==================
 
This script is designed to collect information that will help Microsoft Customer Support Services (CSS) troubleshoot an issue you may be experiencing with Azure Virtual Desktop or Remote Desktop Services or Windows 365 Cloud PC.
The collected data may contain Personally Identifiable Information (PII) and/or sensitive data, such as (but not limited to) IP addresses, PC names and user names.
The script will save the collected data in a subfolder and also compress the results into a ZIP file. The folder or ZIP file are not automatically sent to Microsoft. 
You can send the ZIP file to Microsoft CSS using a secure file transfer tool - Please discuss this with your support professional and also any concerns you may have. 
Find our privacy statement here: https://privacy.microsoft.com/en-US/privacystatement


============================================================================================================
 Table of Contents

  1. About MSRD-Collect
  2. How to use
  3. Available command line parameters
  4. Advanced GUI Mode
  5. Remote Mode
  6. No internet connection available
  7. User Context (aka collecting data related to a user other than the admin running the script)
  8. Presets
  9. Data being collected
 10. MSRD-Diag
 11. Scheduled Tasks to run Diagnostics
 12. Tool Author
 13. Feedback
============================================================================================================



====================================
 1. About MSRD-Collect (v240215.10)
====================================

 • Are you running into issues with your AVD and/or RDS machines or RDP connections?
 • Are you struggling to find the relevant logs/data on your machines for troubleshooting remote desktop related issues or you'd just like to know which data could be helpful?
 • Would you like an easy, scripted way to collect the relevant remote desktop related troubleshooting data from your machines?
 • Would you like to check if your AVD or RDS machines are configured correctly or if they are running into some known remote desktop related issues?

If the answer to any of these questions is 'yes', then this tool will be of great help to you!

MSRD-Collect is a PowerShell script to simplify data collection for troubleshooting Azure Virtual Desktop, Remote Desktop Services and Windows 365 Cloud PC related issues and a convenient method for submitting and following quick & easy action plans. ​​​​​​​

The collected data can help troubleshoot remote desktop related issues ranging from deployment and configuration, to session connectivity, profile (incl. FSLogix), media optimization for Teams, MSIX App Attach, Remote Assistance/Quick Assist/Remote Help and more.
Some scenarios are only viable for AVD deployments.

​​​​​​​The MSRD-Diag.html diagnostics report included in MSRD-Collect provides an extensive overview of the system to quickly pinpoint potential known issues and can significantly speed up troubleshooting.



===============
 2. How to use
===============

Run the script on Windows source or Windows target machines, as needed, based on the scenario you are investigating.

The script requires at least PowerShell version 5.1 and must be run with elevated permissions in order to collect all required data.

Running MSRD-Collect in PowerShell ISE is not supported. Please run the script in a regular elevated/admin PowerShell window.

Preferably run the script while logged in to the machine with a Domain Admin account and running PowerShell in the same Domain Admin account's context.
A local Administrator account can also be used, but the script will not have permissions to collect domains related information.
If logged in with a different account than the one running the script, collecting gpresult may fail.

--//--
Important: 

The script has multiple module (.psm1) files located in a "Modules" folder. This folder (with its underlying .psm1 files) must stay in the same folder as the main MSRD-Collect.ps1 file for the script to work properly.
Download the MSRD-Collect.zip package from the official public download location (https://aka.ms/MSRD-Collect) and extract all files from it, not just the MSRD-Collect.ps1.
The script will import the required module(s) on the fly when specific data is being invoked. You do not need to manually import the modules.

Depending on the OS and security settings of the computer where you downloaded the script, the .zip file may be "blocked" by default.
If you unzip and run this blocked version, you may be prompted by PowerShell to confirm if you want to run the script or each of its modules.
To avoid this, before unzipping the MSRD-Collect.zip file, go to the zip file's Properties, select 'Unblock' and 'Apply'.
After that you can unzip the script and use it.

Alternatively, you can unblock the main script file using the PowerShell command line:
	Unblock-File -Path C:\<path to the extracted script>\MSRD-Collect.ps1

MSRD-Collect.ps1 will also attempt to unblock its module files automatically, by running the following command at the start of the main script:
	Get-ChildItem -Recurse -Path C:\<path to the extracted script>\Modules\MSRDC*.psm1 | Unblock-File -Confirm:$false

--//--


The script can be used in the following ways:

	1) with a GUI: Start the script by running ".\MSRD-Collect.ps1" in an elevated PowerShell window and follow the on-screen guide. 
	There are two GUI modes you can use: "Advanced" and "Lite"

	  - In the "Advanced" version, you can choose between different display languages: Arabic, Chinese, Czech, Dutch, English (default), French, German, Hungarian, Italian, Japanese, Portuguese, Romanian, Spanish, Turkish
		These languages relate to the text displayed in the UI. 
		Machine types and Scenario names, collected data/diagnostics results and potential error messages encountered during script usage are displayed in English (or in the native language of the Operating System where applicable).
    
		The Advanced Mode also allows you to configure various script parameters and have access to various useful documentation.

		In this mode, you can also collect data from one or more remote computers, see below "Remote Mode" for more details.
	
		To adjust the font size in any of the output windows, use the 'CTRL + Mouse Scroll' combination.

		For more details on how to collect the data, see the "Advanced GUI Mode" section below.

	  - In the "Lite" version you have only the basic options to select the data collection scenarios and run the data collection/diagnostics, for everything else (e.g. user context, output location etc.) using default settings.

	2) without a GUI, using any combination of one or more scenario-based command line parameters, which will start the corresponding data collection automatically.
	See the available command line parameters and usage examples below.


When launched, the script will:

	a) present the Microsoft Diagnostic Tools End User License Agreement (EULA). You need to accept the EULA before you can continue using the script.
	Acceptance of the EULA will be stored in the registry under HKCU\Software\Microsoft\CESDiagnosticTools and you will not be prompted again to accept it as long as the registry key is in place.
	You can also use the "-AcceptEula" command line parameter to silently accept the EULA.
	This is a per user setting, so each user running the script will have to accept the EULA once.

	b) present an internal notice that the admin needs to confirm if they agree and want to continue with the data collection.


​​​​​​​If you are missing any of the data that the script should normally collect (see "Data being collected"), check the content of "*_MSRD-Collect-Log.txt" and "*_MSRD-Collect-Errors.txt" files for more information. Some data may not be present during data collection and thus not picked up by the script. This should be visible in one of the two text files.

Once the script has started, p​​​lease read the "IMPORTANT NOTICE" message and confirm if you agree to continue with the data collection.

Depending on the amount of data that needs to be collected, the script may need to run for up to a few minutes. 
During this time, the operating system's built-in commands run by MSRD-Collect might not respond or take a long time to complete. 
Please wait, as the tool should still be running in the background. If it is still stuck in the same place for over 5 minutes, try to close/kill it and collect data again.
If the issue keeps repeating with the same machine and at the same step, please send feedback to MSRDCollectTalk@microsoft.com.


PowerShell ExecutionPolicy
--------------------------

If the script does not start, complaining about execution restrictions, then in an elevated PowerShell console run:

	Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force -Scope Process

and verify with "Get-ExecutionPolicy -List" that no ExecutionPolicy with higher precedence is blocking execution of this script.
The script is digitally signed with a Microsoft Code Sign certificate.

After that run the MSRD-Collect script again.



======================================
 3. Available command line parameters
======================================

Scenario-based parameters:

	"-Core" 	 	  - Collects Core data + Runs Diagnostics

	"-Profiles" 	 	  - Collects all Core data + Profiles data + Runs Diagnostics

	"-Activation" 	 	  - Collects all Core data + OS Licensing/Activation data + Runs Diagnostics

	"-MSRA" 	 	  - Collects all Core data + Remote Assistance data + Runs Diagnostics

	"-SCard" 	 	  - Collects all Core data + Smart Card/RDGW data + Runs Diagnostics

	"-IME" 		 	  - Collects all Core data + input method data + Runs Diagnostics

	"-DumpPID <pid>" 	  - Generate a process dump based on the provided PID
			   	    This dump collection is part of the 'Core' dataset and works with any other scenario parameter except '-DiagOnly'

	"-Teams" 	 	  - Collects all Core data + Teams data + Runs Diagnostics (AVD Only)

	"-AppAttach"  	  - Collects all Core data + App Attach data + Runs Diagnostics  (AVD Only)

	"-HCI" 		 	  - Collects all Core data + Azure Stack HCI data + Runs Diagnostics  (AVD Only)

	"-NetTrace" 	 	  - Collects a netsh network trace (netsh trace start scenario=netconnection maxsize=2048 filemode=circular overwrite=yes report=yes)
		      	  	    If selected, it will always run first, before any other data collection/diagnostics

	"-DiagOnly" 	 	  - The script will skip all data collection and will only run the diagnostics part (even if other parameters have been specified)
	

Other parameters:

	"-Machine" 		  - Indicates the type of machine from where data is collected. This is a mandatory parameter when not using the GUI
		     		    Based on the provided value, only data specific to that machine type will be collected
		     		    Available values are:
					- "isAVD"    : Azure Virtual Desktop
					- "isRDS"    : Remote Desktop Services or direct RDP connections (on-prem and cloud)
					- "isW365"   : Windows 365 Cloud PC

	"-Role"   		  - Indicates the role of the machine in the selected remote desktop solution. This is a mandatory parameter when not using the GUI
		    		    Based on the provided value, only data specific to that role will be collected
		    		    Available values are:
					- isSource   : Source machine used to connect from, by using a Remote Desktop client
					- isTarget   : Target machine used to connect to or intermediate machine in the connection chain (e.g. RDWA, RDGW, RDCB, RDLS)

	"-AcceptEula" 		  - Silently accepts the Microsoft Diagnostic Tools End User License Agreement
	
	"-AcceptNotice" 	  - Silently accepts the internal Important Notice message on data collection

	"-OutputDir <path>" 	  - ​​​​​​Specify a custom directory where to store the collected files. By default, if this parameter is not specified, the script will store the collected data under "C:\MS_DATA". If the path specified does not exit, the script will attempt to create it

	"-UserContext <username>" - Defines the context in which some of the data will be collected
				    MSRD-Collect needs to be run with elevated priviledges to be able to collect all the relevant data, which can sometimes be an inconvenient when troubleshooting issues occuring only with non-admin users or even different admin users than the one running the script, where you need data from the affected user's profile, not the admin's profile running the script
				    With this option, you can specify that some data should be collected from another user's context (e.g. RDClientAutoTrace, Teams settings)
				    This does not apply to collecting HKCU registry keys from the other user. For now, HKCU output will still reflect the settings of the admin user running the script
	
	"-SkipAutoUpdate" 	  - Skips the automatic update check on launch for the current instance of the script (can be used for both GUI and command line mode)

	"-LiteMode" 		  - The script will open with a GUI in "Lite Mode" regardless of the Config\MSRDC-Config.cfg settings

	"-AssistMode" 		  - Accessibility option. The script will read out loud some of the key information and steps performed during data collection/diagnostics
 

You can combine multiple command line parameters to build your desired dataset.

Usage examples with parameters:

To collect only Core data (excluding Profiles, Teams, MSIX App Attach, MSRA, Smart Card, IME) from a machine that is used as the 'source/client' to connect to an AVD deployment

	.\MSRD-Collect.ps1 -Machine isAVD -Role isSource -Core

To collect Core + Profiles + MSIX App Attach + IME data ('Core' is collected implicitly when other scenarios are specified) from an AVD host

	.\MSRD-Collect.ps1 -Machine isAVD -Role isTarget -Profiles -AppAttach -IME

To only run Diagnostics without collecting Core or scenario based data from an RDS server (or a target machine of a non-AVD remote connection)

	.\MSRD-Collect.ps1 -Machine isRDS -Role isTarget -DiagOnly

To store the resulting files in a different folder than C:\MS_DATA

	.\MSRD-Collect.ps1 -OutputDir "E:\AVDdata\"

To collect Core data and also generate a process dump for a running process, based on the process PID (e.g. in this case a process with PID = 13380), from an AVD host

	.\MSRD-Collect.ps1 -Machine isAVD -Role isTarget -Core -DumpPID 13380

To start the script with the GUI (all additional parameters can be set also via the UI)

	.\MSRD-Collect.ps1



======================
 4. Advanced GUI Mode
======================

This guide is also displayed in the UI when you start the script in Advanced GUI Mode.

	Step 1: [Optional] Enter one or more computer names (NetBIOS or FQDN) in the 'Computer(s)' field, separated by a semicolon, from where you want to collect data. 
		The name of the local computer is used as the default value. If multiple machines have been specified, the data will be collected from each computer in a sequential order.

	Step 2: Select the context/environment in which the machine(s) are used:

		AVD		  - Azure Virtual Desktop
		RDS		  - Remote Desktop Services or direct (non-AVD/non-W365) RDP connection
		W365		  - Windows 365 Cloud PC

	Step 3: Select the role of the machine(s) in the given context/environment:

		Source		  - Source machine from where you connect to other machines using a Remote Desktop client
		Target		  - Target machine to which you connect to or any RDS server in a RDS deployment

For data collection:

	Step 4a: [Optional] Select one or more available scenarios:

		Profiles	  - Collect data for troubleshooting 'User Profiles' issues
		Activation	  - Collect data for troubleshooting 'OS Licensing/Activation' issues
		MSRA		  - Collect data for troubleshooting 'Remote Assistance' issues
		SCard	          - Collect data for troubleshooting 'Smart Card' issues
		IME		  - Collect data for troubleshooting 'Input Method' issues
		Teams		  - Collect data for troubleshooting 'Teams Media Optimization' issues (AVD/W365 only)
		AppAttach	  - Collect data for troubleshooting 'App Attach' issues (AVD only)
		HCI		  - Collect data for troubleshooting 'Azure Stack HCI' issues (AVD only)
		DumpPID		  - Collect a Process Dump of an existing process
		NetTrace	  - Collect a network trace (netsh)
		DiagOnly	  - Generate a Diagnostics report only

	Step 5a: Click the 'Start' button when ready. Data collection/diagnostics may take up to several minutes. 

For live diagnostics (only available for the local computer):

	Step 4b: Select the 'LiveDiag' option.

	Step 5b: Select the desired diagnostics category tab.

	Step 6: Click on the desired button within the selected tab to run the coresponding diagnostics check.



================
 5. Remote Mode
================

When using the "Advanced" GUI, you have the option to enter one or more computer names (NetBIOS or FQDN) from where you want to collect the data.

By default, the script is using the name of the local computer from where it was started, in order to collect data from it.
You can change this by adjusting the value in the 'Computer(s)' text box.

Requirements for remote data collection:

	• Network connectivity between the local and remote machines
	• Compatible PowerShell version on both the local and remote machines (at least PowerShell 5.1)
	• WinRM is enabled and properly configured on both the local and remote machines
	• Windows Firewall or any third-party firewalls need to allow WinRM traffic
	• Administrative privileges on both the local and remote machines to establish a remote PowerShell session
	• Implicit acceptance of the EULA and Notice that you receive when using the script on the local machine also for running it on all the remote machines
	• When specifying multiple computer names, delimit them using a semicolon (e.g.: computer1; computer2; computer3)
	
When used in Remote Mode, the script will attempt to:

	• Copy itself to the target computer under C:\MS_DATA\
	• Initiate a Remote PowerShell session to the target computer
		o The script will attempt to create the session first using the current admin user privileges and if that fails it will prompt to enter admin credentials for the remote computer
	• Execute itself on the target computer, redirecting the text output to the local GUI (the collected data remain on the remote computer, only the displayed messages are sent to the local GUI)
	• Open a File Explorer window when done, pointing to the location of the collected data on the remote computer (\\<RemoteComputer>\C$\MS_DATA\)
	
When specifying multiple computer names, the script is executed synchronously, collecting data from each computer at a time in the given order.
If any of the provided computers is not reachable or a remote PowerShell session cannot be established to it, the script will display an error message and move on to the next computer in the list.
	
This feature is using 'Get-Credential' to ask for the credentials required to access the remote computer.
Credentials are not saved by the script and are only used to establish the remote PowerShell session.
Get-Credential stores the credentials in a PSCredential object and the password as a SecureString.
For more information about SecureString data protection, see: https://learn.microsoft.com/en-us/dotnet/api/system.security.securestring?view=net-7.0#how-secure-is-securestring
	
While in Remote Mode, the background of the output area changes to black as a visual indicator.
	
Current limitations (may be lifted in future releases):

	• This feature is only available through the advanced UI
	• This feature is available for AVD and W365 scenarios only - when selecting 'RDS' the 'Computer(s)' text box is disabled and defaults to the local computer name
	• Remote LiveDiag is not available - when selecting 'LiveDiag' the 'Computer(s)' text box is disabled and defaults to the local computer name
	• Any filtering done through the 'Configure data collection' or 'Configure diagnostics' options do not apply to remote data collection/diagnostics
	• The progress bar indicator is not available while collecting data on a remote computer



=====================================
 6. No internet connection available
=====================================

By default, the script will check for updates on launch and will prompt you to download the latest version of the script if available.

If the computer you are running the script on does not have internet access, the script will not be able to check for updates or download the latest version of the script.
In this case, the script will display a warning message and a popup window asking if you'd like to disable automatic update check.

If you select 'Yes', the script will not check for updates anymore on subsequent launches.
Regardless if you select 'Yes' or 'No', the script will continue with the current execution.


=================================================================================================
 7. User Context (aka collecting data related to a user other than the admin running the script)
=================================================================================================

MSRD-Collect needs to be run with elevated priviledges to be able to collect all the relevant data.
As such, when it comes to collecting certain user specific data (e.g. AVD Desktop client traces, Teams settings), by default the script will collect the data from the admin user's profile who launched the script.

While this is ok as long as that admin user can also reproduce the issue, it can sometimes be an inconvenient when troubleshooting issues occuring only with non-admin users or even different admin users than the one running the script.
For those scenarios you'd need data from the affected user's profile, not the admin's profile running the script.
For that you need to tell the script from which user's profile to collect the data.

You can do that by changing the 'user context' within the script:
	• either through the advanced UI ('Tools\Set user context' option)
	• or when launching the script with command line parameters, add: "-UserContext <username>"

So, for example:

If you just run the script as 'adminA', it will look for user specific logs inside the profile of 'adminA'.
If the issue is with 'userB' then:
	• 'userB' would need to be either admin too, and start the script as 'userB'
	• or if that's not possible and you have to start the script as 'adminA', then change the user context within the script to 'userB', either through the UI or command line parameter

This will result in the script still running as admin (e.g. 'adminA'), but at the same time it will collect the user specific logs/traces only from the profile folder of the specified user (e.g. 'userB').

Note: This does not apply to collecting HKCU registry keys or gpresult from the other user. Currently HKCU and gpresult output will still be the ones from the admin user who launched the script.

Important: The profile folder of 'userB' has to exist on the system. If it doesn't exist, the script will display an error message and will not continue with the data collection.



============
 8. Presets
============

When using the advanced UI, if you are not sure which options to select (machine type, machine role, scenarios), check out the 'Presets' menu.
The Presets menu contains options to select predefined settings for specific troubleshooting scenarios.

If a preset matches the scenario you are troubleshooting, select it and the script will automatically select the required options for you.
After selecting a preset, all you need to do is to press the 'Start' button to begin the data collection/diagnostics.



=========================
 9. Data being collected
=========================

The collected data is stored in a subfolder under C:\MS_DATA\ and at the end of the data collection, the results are archived into a .zip file also under C:\MS_DATA\. 
No data is automatically uploaded to Microsoft.
You can change the default C:\MS_DATA\ location either through the GUI (Tools/Set Output Location...) or by command line using the "-OutputDir <location>" parameter.

The script will only collect the data that is relevant for the selected machine type (AVD, RDS or W365) and role (Source or Target).
The below lists contain all the data that can be collected by the available scenarios, regardless of the selected machine type and role.

Data collected in the "Core" scenario:

	• Log files
		o C:\Packages\Plugins\Microsoft.Azure.ActiveDirectory.AADLoginForWindows\
		o C:\Packages\Plugins\Microsoft.Compute.JsonADDomainExtension\<version>\Status\
		o C:\Packages\Plugins\Microsoft.EnterpriseCloud.Monitoring.MicrosoftMonitoringAgent\<version>\Status\
		o C:\Packages\Plugins\Microsoft.Powershell.DSC\<version>\Status\​​​​​​​
		o %programfiles%\Microsoft RDInfra\AgentInstall.txt
		o %programfiles%\Microsoft RDInfra\​GenevaInstall.txt
		o %programfiles%\Microsoft RDInfra\MsRdcWebRTCSvc.txt
		o %programfiles%\Microsoft RDInfra\MsRdcWebRTCSvcMsiInstall.txt
		o %programfiles%\Microsoft RDInfra\MsRdcWebRTCSvcMsiUninstall.txt
		o %programfiles%\Microsoft RDInfra\​SXSStackInstall.txt
		o %programfiles%\Microsoft RDInfra\WVDAgentManagerInstall.txt
		o %programfiles%\MsRDCMMRHost\MsRDCMMRHostInstall.log
		o <default user profile location>\AgentInstall.txt
		o <default user profile location>\AgentBootLoaderInstall.txt
		o <default user profile location>\<username running the script>\AppData\Local\Temp\RDMSUI-trace.log
		o %windir%\debug\NetSetup.log
		o %windir%\Temp\MsRDCMMRHostInstall.log
		o %windir%\Temp\ScriptLog.log
		o C:\WindowsAzure\Logs\MonitoringAgent.log
		o C:\WindowsAzure\Logs\TransparentInstaller.log
		o C:\WindowsAzure\Logs\WaAppAgent.log
		o C:\WindowsAzure\Logs\Plugins\
		o %windir%\Logs\RDMSDeploymentUI.txt
		o %windir%\System32\tssesdir\*.xml
		o %windir%\web\rdweb\App_Data\rdweb.log
		• %windir%\inf\setupapi.dev.log and %windir%\inf\setupapi.app.log
		• %windir%\panther\Setupact.log
		• %windir%\Logs\CBS\CBS.log
		• CCM client logs from C:\Windows\CCM\Logs\ (all, except the ones containing '*SCClient*', '*SCNotify*', '*SCToastNotification*')
	• Local group membership information
		o Remote Desktop Users
		o RDS Management Servers (if available and 'RDS' machine type selected)
		o RDS Remote Access Servers (if available and 'RDS' machine type selected)
		o RDS Endpoint Servers (if available and 'RDS' machine type selected)
	• The content of the "<default user profile location>\%username%\AppData\Local\Temp\DiagOutputDir\RdClientAutoTrace" folder (available on devices used as source clients to connect to AVD hosts) from the past 5 days, containing:
		o AVD remote desktop client connection ETL traces
		o AVD remote desktop client application ETL traces
		o AVD remote desktop client upgrade log (MSI.log)
	• "%localappdata%\rdclientwpf\ISubscription.json" file
	• "Qwinsta /counter" output
	• DxDiag output in .txt format with no WHQL check
	• Geneva, Remote Desktop and Remote Assistance Scheduled Task information
	• "Azure Instance Metadata service endpoint" request info
	• Convert existing .tsf files on AVD hosts from under "%windir%\System32\config\systemprofile\AppData\Roaming\Microsoft\Monitoring\Tables" into .csv files and collect the resulting .csv files
	• AVD Monitoring Agent environment variables
	• Output of "%programfiles%\Microsoft Monitoring Agent\Agent\TestCloudConnection.exe"
	• "dsregcmd /status" output
	• AVD Services API health check (BrokerURI, BrokerURIGlobal, DiagnosticsUri, BrokerResourceIdURIGlobal)
	• Event Logs
		o Application
		o Microsoft-Windows-AAD/Operational
		o Microsoft-Windows-AppLocker/EXE and DLL
		o Microsoft-Windows-AppLocker/Packaged app-Execution
		o Microsoft-Windows-AppLocker/Packaged app-Deployment
		o Microsoft-Windows-AppLocker/MSI and Script
		o Microsoft-Windows-AppModel-Runtime/Admin
		o Microsoft-Windows-AppReadiness/Admin
		o Microsoft-Windows-AppReadiness/Operational
		o Microsoft-Windows-AppXDeployment/Operational
		o Microsoft-Windows-AppXDeploymentServer/Operational
		o Microsoft-Windows-AppXDeploymentServer/Restricted
		o Microsoft-Windows-AppxPackaging/Operational
		o Microsoft-Windows-CAPI2/Operational
		o Microsoft-Windows-Diagnostics-Performance/Operational
		o Microsoft-Windows-DSC/Operational
		o Microsoft-Windows-GroupPolicy/Operational
		o Microsoft-Windows-HelloForBusiness/Operational
		o Microsoft-Windows-Kernel-PnP/Device Configuration
		o Microsoft-Windows-Kernel-PnP/Device Management
		o Microsoft-Windows-NetworkProfile/Operational
		o Microsoft-Windows-NTLM/Operational
		o Microsoft-Windows-PowerShell/Operational
		o Microsoft-Windows-RemoteDesktopServices
		o Microsoft-Windows-RemoteDesktopServices-RdpCoreCDV/Admin
		o Microsoft-Windows-RemoteDesktopServices-RdpCoreCDV/Operational
		o Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Admin
		o Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational
		o Microsoft-Windows-RemoteDesktopServices-SessionServices/Operational
		o Microsoft-Windows-Shell-Core/Operational
		o Microsoft-Windows-SMBClient/Connectivity
		o Microsoft-Windows-SMBClient/Operational
		o Microsoft-Windows-SMBClient/Security
		o Microsoft-Windows-SMBServer/Connectivity
		o Microsoft-Windows-SMBServer/Operational
		o Microsoft-Windows-SMBServer/Security
		o Microsoft-Windows-TaskScheduler/Operational
		o Microsoft-Windows-TerminalServices-LocalSessionManager/Admin
		o Microsoft-Windows-TerminalServices-LocalSessionManager/Operational
		o Microsoft-Windows-TerminalServices-PnPDevices/Admin
		o Microsoft-Windows-TerminalServices-PnPDevices/Operational
		o Microsoft-Windows-TerminalServices-RDPClient/Operational
		o Microsoft-Windows-TerminalServices-RemoteConnectionManager/Admin
		o Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational
		o Microsoft-Windows-TerminalServices-TSV-VmHostAgent/Admin
		o Microsoft-Windows-TerminalServices-TSV-VmHostAgent/Operational
		o Microsoft-Windows-User Device Registration/Admin
		o Microsoft-Windows-WER-Diagnostics/Operational
		o Microsoft-Windows-WinINet-Config/ProxyConfigChanged
		o Microsoft-Windows-Winlogon/Operational
		o Microsoft-Windows-WinRM/Operational
		o Microsoft-Windows-Workplace Join/Admin
		o Microsoft-WindowsAzure-Diagnostics/Bootstrapper
		o Microsoft-WindowsAzure-Diagnostics/GuestAgent
		o Microsoft-WindowsAzure-Diagnostics/Heartbeat
		o Microsoft-WindowsAzure-Diagnostics/Runtime
		o Microsoft-WindowsAzure-Status/GuestAgent
		o Microsoft-WindowsAzure-Status/Plugins
		o Security
		o Setup
		o System
	• Registry keys
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\MSRDC
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\RdClientRadc
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\Remote Desktop​
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\Terminal Server Client
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings
		o HKEY_CURRENT_USER\SOFTWARE\Policies
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Azure\DSC
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\MSRDC
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NET Framework Setup\NDP
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Ole
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDAgentBootLoader
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDInfraAgent
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDMonitoringAgent
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\MSLicensing
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Ole
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Terminal Server Client
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\TermServLicensing
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies
		o ​​​​​​​HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
		o ​​​​​​​HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\Exclusions
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\TerminalServerGateway
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon
		o HKEY_LOCAL_MACHINE\SOFTWARE\Policies
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\CloudDomainJoin
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\CoDeviceInstallers
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\CrashControl
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Cryptography
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server​​
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\TERMINPUT_BUS
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\TERMINPUT_BUS_SXS
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\i8042prt
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\MSSQL$MICROSOFT##WID
		o ​​​​​​​HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\RDAgentBootLoader
        o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\RDMS
        o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\TermServLicensing
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\TermService
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip
        o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\TScPubRPC
        o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\TSFairShare
        o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tssdis
        o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\TSGateway
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\UmRdpService
        o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W3SVC
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WinRM​​
		o HKEY_LOCAL_MACHINE\SYSTEM\DriverDatabase\DeviceIds\TS_INPT
		o HKEY_USERS\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings
	• Filtered NPS event logs if available, when the RD Gateway role is detected
	• Networking information (firewall rules, ipconfig /all, network profiles, netstat -anob, proxy configuration, route table, winsock show catalog, Get-NetIPInterface, netsh interface Teredo show state)
	• Details of the running processes and services
	• List of installed software (on both machine and user level)
	• Information on installed AntiVirus products
	• List of top 10 processes using CPU at the moment when the script is running
	• "gpresult /h" and "gpresult /r /v" output
	• "fltmc filters" and "fltmc volumes" output
	• File versions of the currently running binaries
	• File versions of key binaries (Windows\System32\*.dll, Windows\System32\*.exe, Windows\System32\*.sys, Windows\System32\drivers\*.sys)
	• Basic system information
	• .NET Framework information
	• "Get-DscConfiguration" and "Get-DscConfigurationStatus" output
	• Msinfo32 output (.nfo)
	• PowerShell version
	• WinRM configuration information
	• WMI ProviderHostQuotaConfiguration
	• Windows Update History
	• Output of "Test-DscConfiguration -Detailed"
	• Output of "%programfiles%\NVIDIA Corporation\NVSMI\nvidia-smi.exe" (if the NVIDIA GPU drivers are already installed on the machine)
	• Certificate store information ('My' and 'AAD Token Issuer')
	• Certificate thumbprint information ('My', 'AAD Token Issuer', 'Remote Desktop')
	• SPN information (WSMAN, TERMSRV)
	• "nltest /sc_query:<domain>" and "nltest /dnsgetdc:<domain>" output
	• Remote Desktop Gateway information, incl. RAP and CAP policies (if RDGW role is installed - for Server OS deployments)
	• Remote Desktop Connection Broker information, incl. GetRDSFarmData output (if RDCB role is installed - for Server OS deployments)
	• Remote Desktop Web Access information, incl. IIS Server configuration (if RDWA role is installed - for Server OS deployments)
	• Remote Desktop License Server information, incl. installed and issued licenses (if RDLS role is installed - for Server OS deployments)
	• Tree output of the "%windir%\RemotePackages" and "%programfiles%\Microsoft RDInfra" folder's content
	• "tasklist /v" output
	• ACL for "%programdata%\Microsoft\Crypto\RSA\MachineKeys" and "%programdata%\Microsoft\Crypto\RSA\MachineKeys\f686aace6942fb7f7ceb231212eef4a4_"
	• ACL for 'HKLM\SOFTWARE\Microsoft\SystemCertificates\Remote Desktop'
	• ACL for 'HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM' (if the RD Session Host role is installed)
	• List of AppLocker rules collections
	• Information on installed Firewall products
	• Information on Power Settings ('powercfg /list', 'powercfg /query', 'powercfg /systempowerreport')
	• Verbose list of domain trusts
	• NTFS permissions from the C:\ drive
	• "pnputil /e" output
	• Members of the 'Terminal Server License Servers' group in the domain, if the machine is domain-joined and has either the RD Session Host or RD Licensing role installed
	• Environment variables
	• Debug log for RDP Shortpath availability using 'avdnettest.exe'
	• Output of the WVDAgentUrlTool on AVD and W365 hosts
	• "Get-PnpDevice -PresentOnly" output
	• General 'PermissionsAllowed' and 'PermissionsDenied' information on the available listeners (RDP, SxS, ICA) for the assigned users/groups and granular information for the current user
	• MDM diagnostic information (results of: mdmdiagnosticstool.exe -area "DeviceEnrollment;DeviceProvisioning;Autopilot")
	• TlsWarning (termsrv\licensing) scheduled task information, if the RD Session Host role is installed
	• "MSI*.log" files corresponding to the 'Geneva' and 'MsRDCMMRHost' installations for AVD/W365, if available
	• Windows 365 app logs from '<default user profile location>\%username%\AppData\Local\Temp\DiagOutputDir\Windows365\Logs'
	• WMI query output for 'Win32_TerminalServiceSetting', 'Win32_Terminal', 'Win32_TSClientSetting', 'Win32_TSPermissionsSetting', 'Win32_TSEnvironmentSetting', 'Win32_TSGeneralSetting', 'Win32_TSLogonSetting', 'Win32_TSNetworkAdapterSetting', 'Win32_TSRemoteControlSetting', 'Win32_TSSessionSetting', 'Win32_TSSessionDirectory'
	• 'tree' output of '%windir%\System32\config\systemprofile\AppData\Roaming\Microsoft\Monitoring', if available
	• 'netsh interface tcp show global' and 'netsh interface udp show global' output
	• PsPing output for:
		o 8.8.8.8:443
		o rdweb.wvd.microsoft.com:443 (if 'AVD' or 'W365' machine type and 'Source' machine role are selected)
		o rdbroker.wvd.microsoft.com:443 (if 'AVD' or 'W365' machine type and 'Target' machine role are selected)
	• Wired and Wireless LAN settings (only when using the 'Source' machine role)
	• Wireless network report for the past 5 days (only when using the 'Source' machine role)


Data collected additionally to the "Core" dataset, depending on the selected scenario or command line parameter(s) used:

When using "-Profiles" scenario/parameter:

	• Log files
		o %programdata%\FSLogix\Logs (or from the location specified in the registry under HKEY_LOCAL_MACHINE\SOFTWARE\FSLogix\Logging\LogDir)
	• FSLogix tool output (frx list-redirects, frx list-rules, frx version)
	• Registry keys
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\Office​
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\OneDrive
		o HKEY_CURRENT_USER\Volatile Environment
		o HKEY_LOCAL_MACHINE\SOFTWARE\FSLogix
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Search
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Enum\SCSI\Disk&Ven_Msft&Prod_Virtual_Disk
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\frxccd
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\frxccds
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\ProfSvc
	• Output of 'whoami /all'
	• Event Logs
		o Microsoft-FSLogix-Apps/Admin
		o Microsoft-FSLogix-Apps/Operational
		o Microsoft-FSLogix-CloudCache/Admin
		o Microsoft-FSLogix-CloudCache/Operational
		o Microsoft-Windows-Ntfs/Operational (filtered output for events 4 and 142 only)
		o Microsoft-Windows-User Profile Service/Operational
		o Microsoft-Windows-VHDMP/Operational
	• Local group membership information
		o FSLogix ODFC Exclude List
		o FSLogix ODFC Include List
		o FSLogix Profile Exclude List
		o FSLogix Profile Include List
	• ACL for the FSLogix Profiles and ODFC storage locations
	• 'klist get krbtgt' output
	• 'klist get cifs/<FSLogix Profiles VHDLocations storage>' output
	• A filtered output of the VHD Disk Compaction metric events for FSLogix for the past 5 days
	• The content of the '%programfiles%\FSLogix\Apps\Rules' folder
	• 'tree' output of '%programfiles%\FSLogix\Apps\Rules', if available
	• 'tree' output of '%programfiles%\FSLogix\Apps\CompiledRules', if available


When using "-Activation" scenario/parameter:
	• 'licensingdiag.exe' output
	• 'slmgr.vbs /dlv' output
	• List of available KMS servers in the VM's domain (if domain joined)

		
When using "-MSIXAA" or "-AppAttach" scenario/parameter:

	• Event Logs
		o Microsoft-Windows-AppXDeploymentServer/Operational
		o Microsoft-Windows-RemoteDesktopServices (filtered for MSIX App Attach events only)


When using "-Teams" scenario/parameter:

	• Log files, if available in the selected user's context
		o %programfiles(x86)%\Microsoft\Teams\SquirrelSetup.log
		o %programfiles(x86)%\Microsoft\Teams\current\SquirrelSetup.log
		o %localappdata%\Microsoft\Teams\current\SquirrelSetup.log
		o %localappdata%\Microsoft\Teams\current\current\SquirrelSetup.log
		o %userprofile%\Downloads\MSTeams Diagnostics Logs*
		o %userprofile%\Downloads\PROD-WebLogs*
	• Registry keys
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Teams
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\RDWebRTCSvc
	• Event Logs
		o Microsoft-Windows-AppxPackaging/Operational
		o Microsoft-Windows-AppXDeploymentServer/Operational
	• Output of 'Get-AppxPackage' for '*MSTeams*' and '*MicrosoftTeams*'


When using "-MSRA" scenario/parameter:

	• Local group membership information
		o Distributed COM Users
		o Offer Remote Assistance Helpers
	• Registry keys
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Remote Assistance
	• Event Logs
		o Microsoft-Windows-RemoteAssistance/Admin
		o Microsoft-Windows-RemoteAssistance/Operational
		o Microsoft-Windows-RemoteHelp/Operational
	• Information on the COM Security permissions
	• Remote Help installation logs


When using "-SCard" scenario/parameter:

	• Event Logs
		o Microsoft-Windows-Kerberos-KDCProxy/Operational
		o Microsoft-Windows-SmartCard-Audit/Authentication
		o Microsoft-Windows-SmartCard-DeviceEnum/Operational
		o Microsoft-Windows-SmartCard-TPM-VCard-Module/Admin
		o Microsoft-Windows-SmartCard-TPM-VCard-Module/Operational
	• "certutil -scinfo -silent" output
	• RD Gateway information when ran on the KDC Proxy server and the RD Gateway role is present
		o Server Settings, Resource Authorization Policy, Connection Authorization Policy


When using "-IME" scenario/parameter:

	• Registry keys
		o HKEY_CURRENT_USER\Control Panel\International
		o HKEY_CURRENT_USER\Keyboard Layout
		o HKEY_CURRENT_USER\SOFTWARE\AppDataLow\Software\Microsoft\IME
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\CTF
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\IME
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\IMEMIP
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\IMEJP
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\Input
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\InputMethod
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\Keyboard
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\Speech
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\Speech Virtual
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\Speech_OneCore
		o HKEY_CURRENT_USER\SOFTWARE\Microsoft\Spelling
		o HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layouts
		o HKEY_LOCAL_MACHINE\SYSTEM\Keyboard Layout
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\CTF
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\IME
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\IMEJP
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\IMEKR
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\IMETC
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Input
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\InputMethod
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\MTF
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\MTFFuzzyFactors
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\MTFInputType
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\MTFKeyboardMappings
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Speech
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Speech_OneCore
		o HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Spelling
	• 'tree' output for the following folders:
		o %APPDATA%\Microsoft\IME
		o %APPDATA%\Microsoft\InputMethod
		o %LOCALAPPDATA%\Microsoft\IME
		o %windir%\System32\IME
		o %windir%\IME
	• 'Get-Culture' and 'Get-WinUserLanguageList' output


When using "-HCI" scenario/parameter:
	• Log files
		o %programdata%\AzureConnectedMachineAgent\Log\himds.log
		o %programdata%\AzureConnectedMachineAgent\Log\azcmagent.log
		o %programdata%\GuestConfig\arc_policy_logs\gc_agent.log
		o %programdata%\GuestConfig\ext_mgr_logs\gc_ext.log
	• Information on Azure Instance Metadata Service (IMDS) endpoint accessibility specific for Azure Stack HCI


When using "-NetTrace" scenario/parameter (If selected, it will always run first, before any other data collection/diagnostics):
	• 'netsh' trace (netsh trace start scenario=netconnection maxsize=2048 filemode=circular overwrite=yes report=yes)


When using "-DumpPID" scenario/parameter:
	• Generates a process dump of the process corresponding to the provided PID using ProcDump from SysInternals (ProcDump.exe -AcceptEula -ma <PID>)



===============
 10. MSRD-Diag
===============

MSRD-Collect also generates diagnostics reports containing an extensive overview of the system to quickly pinpoint several known issues and significantly speed up troubleshooting.
The reports may include checks for options/features that are not available on the system. This is expected as Diagnostics aims to cover as many topics as possible in one. 
Always place the results into the right troubleshooting context.
New diagnostics checks may be added in each new release, so make sure to always use the latest version of the script for the best troubleshooting experience.​​

Important: MSRD-Diag is not a replacement of a full data analysis. Depending on the scenario, further data collection and analysis may be needed.

You can access the diagnostics results in two ways:

1) As a .html report 

	When collecting any scenario-based data, or when using the 'DiagOnly' scenario, the script generates a *_MSRD-Diag.html file with the results of the diagnostic checks.
	Additional output files might be generated too, based on what type of issues have been identified over the past 5 days (e.g. for AVD Agent, FSLogix, MSIX App Attach, RDP Shortpath, Black Screen, TCP, process hang or process/system crash).

2) Live, through the Advanced GUI

	When using the 'LiveDiag' feature in the advanced GUI, you can more granularly run the diagnostics checks per category directly in the UI. No files are generated in this case.


The script performs the following diagnostics, grouped in categories, from Remote Desktop (AVD/RDS/W365) perspective:

	• System
		o Overview of the system the script is running on ('Core' information)
		o Top 10 processes using the most CPU time on all processors and top 10 processes using the most handles
		o Drives information for local, network and remote desktop redirected disk drives
		o Graphics configuration
		o OS activation / licensing
		o SSL/TLS configuration
		o User Account Control (UAC) configuration
		o Windows Installer information
		o Windows Search information
		o Windows Update information
		o WinRM and PowerShell configuration / requirements
	
	• AVD/RDS/W365
		o Remote Desktop device and resource redirection configuration
		o FSLogix configuration
		o Multimedia configuration (Multimedia Redirection and Audio/Video privacy settings)
		o Quick Assist and Remote Help information
		o RDP and Remote Desktop listener settings
		o Remote Desktop client information
		o Remote Desktop licensing configuration
		o RDS deployment information and individual RDS roles configuration
		o Remote Desktop 'Session Time Limits' and other network time limit policy settings
		o AVD media optimization configuration for Teams and basic Teams installation information

	• AVD Infra
		o AVD host pool information
		o AVD Agent and SxS Stack information	
		o AVD Health Check (status of the latest health checks performed by the AVD agent)
		o AVD required endpoints accesibility
		o AVD Services URI health status (BrokerURI, BrokerURIGlobal, DiagnosticsUri, BrokerResourceIdURIGlobal)
		o AVD on Azure Stack HCI configuration
	    o RDP ShortPath configuration for both managed and public networks
		o Windows 365 Cloud PC information (incl. required endpoints)

	• Active Directory
		o Microsoft Entra Join configuration
		o Domain and Domain Controller information
		
	• Networking
		• Core networking registry keys and services status
		• DNS configuration (Windows 10+ and Server OS)
		• Firewall configuration (Firewall software available inside the VM - does not apply to external firewalls)
		• Public IP address information
		• Port Usage (total number of TCP/UDP ports in use + top 5 processes using the most TCP/UDP ports)
		• Proxy configuration
		• Routing information
		• VPN connection profile information

	• Logon/Security
		o Authentication and Logon information
		o TPM and Secure Boot status information
		o Antivirus information
		o Remote Desktop related security settings and requirements

	• Known Issues
		o Filtered event log entries from over the past 5 days, for the following scenarios:
			o AVD agent related issues
			o Black Screen issues
			o Domain Trust issues
			o Failed Logon issues
			​​​​o FSLogix related issues
			o MSIX App Attach related issues
			o Process and system crashes
			o Process hangs
			o RD Licensing related issues (when the RD Licensing role is installed)
			o RD Gateway related issues (when the RD Gateway role is installed)
			o RDP ShortPath issues
			o TCP issues
		o Potential logon/logoff issue generators (like black screens, delays, disappearing remote desktop windows)

	• Other
		• Microsoft Office information
		• OneDrive configuration and requirements for FSLogix compatibility
		• Printing information (spooler service status, available printers)
		• Installed Citrix components and some other 3rd party software which may be relevant in various troubleshooting scenarios



========================================
 11. Scheduled Tasks to run Diagnostics
========================================

Through the Advanced Mode GUI, you can set up scheduled tasks to run the diagnostics checks and generate the MSRD-Diag.html report.
You can find the option under "Tools\Create scheduled task..."
You can create scheduled tasks with the following frequencies: Once, Daily, Weekly, Monthly
The Scheduled Tasks will run under "NT AUTHORITY\SYSTEM" account.



=================
 12. Tool Author
=================

Robert Klemencz @ Microsoft



==============
 13. Feedback
==============

To provide feedback about MSRD-Collect use our feedback form at: https://aka.ms/MSRD-Collect-Feedback

