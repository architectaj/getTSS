<#
.SYNOPSIS
   DEV Components and Scenarios module for learning and demoing TSS Framework usage.
   This is NOT related to any specific POD and not designed for learning and troubleshooting.

.DESCRIPTION
   DEV Components and Scenarios module for learning and demoing TSS Framework usage.
   This is NOT related to any specific POD and not designed for learning and troubleshooting.

.NOTES
	Dev. Lead: milanmil
   Authors     : milanmil, waltere
   Requires   : PowerShell V4(Supported from Windows 8.1/Windows Server 2012 R2)
   Version    : see $global:TssVerDateDEV

.LINK
	TSS https://internal.evergreen.microsoft.com/en-us/help/4619187
#>

<# latest changes
::  2023.08.07.0 [mm] _ADS: move ADS_EESummit to DEV_EESummit
::  2023.01.23.0 [we] _DEV: added function DevTest
::  2022.12.07.0 [we] _DEV: add -Scenario DEV_General
::  2022.01.05.0 [we] added FW function calls which were previously defined in _NET
::  2021.11.10.0 [we] #_# replaced all 'Get-WmiObject' with 'Get-CimInstance' to be compatible with PowerShell v7
#>

$global:TssVerDateDEV= "2023.08.17.0"

#region --- ETW component trace Providers ---
# Normal trace -> data will be collected in a single file
$DEV_TEST1Providers = @(
	'{CC85922F-DB41-11D2-9244-006008269001}' # LSA
	'{6B510852-3583-4E2D-AFFE-A67F9F223438}' # Kerberos
)

# Normal trace with multi etl files
# Syntax is: GUID!filename!flags!level 
# GUID is mandtory
# if filename is not provided TSS will create etl using Providers name, i.e. dev_test2 
# if flags is not provided, TSS defaults to 0xffffffff
# if level is not provided, TSS defaults to 0xff
$DEV_TEST2Providers = @(
	'{98BF1CD3-583E-4926-95EE-A61BF3F46470}!CertCli!0xffffff!0x05'
	'{6A71D062-9AFE-4F35-AD08-52134F85DFB9}!CertificationAuthority!0xff!0x07'
	'{B40AEF77-892A-46F9-9109-438E399BB894}!CertCli!0xfffffe!0x04'
	'{169EC169-5B77-4A3E-9DB6-441799D5CACB}!lsa!0xfffffffe'
	'{5BBB6C18-AA45-49B1-A15F-085F7ED0AA90}!CertificationAuthority!0xC43EFF!0x06'
	'{D0B639E0-E650-4D1D-8F39-1580ADE72784}!lsa!0xffffffff!0x0f'
)

# Single etl + multi flags
$DEV_TEST3Providers = @(
	'{D0B639E0-E650-4D1D-8F39-1580ADE72784}!lsa!0xC43EFF'
	'{169EC169-5B77-4A3E-9DB6-441799D5CACB}!lsa!0xffffff'
)

$DEV_TEST4Providers = @(
	'{D0B639E0-E650-4D1D-8F39-1580ADE72784}!lsa!0xC43EFF'
	'{169EC169-5B77-4A3E-9DB6-441799D5CACB}!lsa!0xffffff'
	'{D0B639E0-E650-4D1D-8F39-1580ADE72784}!lsa!0xffffffff!0x0f'
	'{5BBB6C18-AA45-49B1-A15F-085F7ED0AA90}!CertificationAuthority!0xC43EFF!0x06'
)

$DEV_EESummitDemoProviders = @(
	'{CA030134-54CD-4130-9177-DAE76A3C5791}!netlogon' # NETLOGON/ NETLIB
	'{E5BA83F6-07D0-46B1-8BC7-7E669A1D31DC}!netlogon' # Microsoft-Windows-Security-Netlogon
	'{8EE3A3BF-9379-4DAC-B376-038F498B19A4}!w32time' # Microsoft.Windows.W32Time
)


#select basic or full tracing option for the same etl guids using different flags
if ($global:CustomParams){
	Switch ($global:CustomParams[0]){
		"full" {$DEV_TEST5Providers = @(
				'{D0B639E0-E650-4D1D-8F39-1580ADE72784}!lsa!0xffffffff'
				'{169EC169-5B77-4A3E-9DB6-441799D5CACB}!lsa!0xffffffff'
				)
		}
		"basic" {$DEV_TEST5Providers = @(
				'{D0B639E0-E650-4D1D-8F39-1580ADE72784}!lsa!0xC43EFF'
				'{169EC169-5B77-4A3E-9DB6-441799D5CACB}!lsa!0xffffff'
				)
		}
		Default {$DEV_TEST5Providers = @(
				'{D0B639E0-E650-4D1D-8F39-1580ADE72784}!lsa!0xC43EFF'
				'{169EC169-5B77-4A3E-9DB6-441799D5CACB}!lsa!0xfffff!0x12'
				)
		}
	}
}
#endregion --- ETW component trace Providers ---

#region --- Scenario definitions ---
 
$DEV_General_ETWTracingSwitchesStatus = [Ordered]@{
	#'NET_Dummy' = $true
	'CommonTask NET' = $True  ## <------ the commontask can take one of "Dev", "NET", "ADS", "UEX", "DnD" and "SHA", or "Full" or "Mini"
	'NetshScenario InternetClient_dbg' = $true
	'Procmon' = $true
	#'WPR General' = $true
	'PerfMon ALL' = $true
	'PSR' = $true
	'Video' = $true
	'SDP NET' = $True
	'xray' = $True
	'CollectComponentLog' = $True
}
 
$DEV_ScenarioTraceList = [Ordered]@{
	'DEV_Scn1' = 'DEV scenario trace 1'
	'DEV_Scn2' = 'DEV scenario trace 2'
	"DEV_EESummitDemo"    = "DEV_EESummitDemo Trace, ADS_Kerb, PSR, Netsh"
}

# DEV_Scn1
$DEV_Scn1_ETWTracingSwitchesStatus = [Ordered]@{
	'DEV_TEST1' = $true
	#'DEV_TEST2' = $true   # Multi etl file trace
	#'DEV_TEST3' = $true   # Single trace
	#'DEV_TEST4' = $true 
	#'DEV_TEST5' = $true
	#'Netsh' = $true
	#'Netsh capturetype=both captureMultilayer=yes provider=Microsoft-Windows-PrimaryNetworkIcon provider={1701C7DC-045C-45C0-8CD6-4D42E3BBF387}' = $true
	#'NetshMaxSize 4096' = $true
	#'Procmon' = $true
	#'ProcmonFilter ProcmonConfiguration.pmc' = $True
	#'ProcmonPath C:\tools' = $True
	#'WPR memory' = $true
	#'WPR memory -onoffproblemdescription "test description"' = $true
	#'skippdbgen' = $true
	#'PerfMon smb' = $true
	#'PerfIntervalSec 20' = $true
	#'PerfMonlong general' = $true
	#'PerfLongIntervalMin 40' = $true
	#'NetshScenario InternetClient_dbg' = $true
	#'NetshScenario InternetClient_dbg,dns_wpp' = $true
	#'NetshScenario InternetClient_dbg,dns_wpp capturetype=both captureMultilayer=yes provider=Microsoft-Windows-PrimaryNetworkIcon provider={1701C7DC-045C-45C0-8CD6-4D42E3BBF387}' = $true
	#'PSR' = $true
	#'WFPdiag' = $true
	#'RASdiag' = $true
	#'PktMon' = $true
	#'AddDescription' = $true
	#'SDP rds' = $True
	#'SDP setup,perf' = $True
	#'SkipSDPList noNetadapters,skipBPA' = $True
	#'xray' = $True
	#'Video' = $True
	#'SysMon' = $True
	#'CommonTask Mini' = $True
	#'CommonTask Full' = $True
	#'CommonTask Dev' = $True
	#'noBasicLog' = $True
	#'noPSR' = $True
	#'noVideo' = $True
	#'Mini' = $True
	#'NoSettingList noSDP,noXray,noBasiclog,noVideo,noPSR' = $True
	#'Xperf Pool' = $True
	#'XPerfMaxFile 4096' = $True
	#'XperfTag TcpE+AleE+AfdE+AfdX' = $True
	#'XperfPIDs 100' = $True
	#'LiveKD Both' = $True
	#'WireShark' = $True
	#'TTD notepad.exe' = $True   # Single process [<processname.exe>|<PID>]
	#'TTD notepad.exe,cmd.exe' = $True   # Multiple processes
	#'TTD tokenbroker' = $True   # Service name
	#'TTD Microsoft.Windows.Photos' = $True  # AppX
	#"TTDPath $env:userprofile\Desktop\PartnerTTDRecorder_x86_x64\amd64\TTD" = $True	# for downlevel OS TTD will find Partner tttracer in \Bin** folder
	#'TTDMode Ring' = $True   # choose [Full|Ring|onLaunch]
	#'TTDMaxFile 2048' = $True
	#'TTDOptions XXX' = $True
	#'CollectComponentLog' = $True
	#'Discard' = $True
	#'ProcDump notepad.exe,mspaint.exe,tokenbroker' = $true
	#'ProcDumpOption Both' = $true
	#'ProcDumpInterval 3:10' = $True
	#'GPResult Both' = $True
	#'PoolMon Both' = $True
	#'Handle Both' = $True
}

# DEV_Scn2
Switch (global:FwGetProductTypeFromReg){
	"WinNT" {
		$DEV_Scn2_ETWTracingSwitchesStatus = [Ordered]@{
			'DEV_TEST1' = $true
			'DEV_TEST2' = $true  # Multi etl file trace
			'DEV_TEST3' = $true
			'DEV_TEST4' = $true   # Single trace
			'DEV_TEST5' = $False  # Disabled trace
			'UEX_Task' = $True	 # Outside of this module
		}
	}
	"ServerNT" {
		$DEV_Scn2_ETWTracingSwitchesStatus = [Ordered]@{
			'DEV_TEST1' = $true
			'DEV_TEST2' = $true
		}
	}
	"LanmanNT" {
		$DEV_Scn2_ETWTracingSwitchesStatus = [Ordered]@{
			'DEV_TEST1' = $true
			'DEV_TEST2' = $true
		}
	}
	Default {
		$DEV_Scn2_ETWTracingSwitchesStatus = [Ordered]@{
			'DEV_TEST1' = $true
			'DEV_TEST2' = $true
		}
	}
}

# Dev_Scn3 => Multi etl only
$DEV_Scn3_ETWTracingSwitchesStatus = [Ordered]@{
	'DEV_TEST2' = $true   # Multi etl file trace
}

$DEV_EESummitDemo_ETWTracingSwitchesStatus = [Ordered]@{
	'DEV_EESummitDemo' = $true
	'ADS_Kerb' = $true
	'Netsh' = $true
	'PSR' = $true
	'xray' = $true
	'noBasicLog' = $true
	'CollectComponentLog' = $True
}

#endregion --- Scenario definitions ---



#region Functions

#region Components Functions
#region -------------- DevTest -----------
# IMPORTANT: this trace should be used only for development and testing purposes

function DevTestPreStart{
	EnterFunc $MyInvocation.MyCommand.Name
	LogInfoFile "[$($MyInvocation.MyCommand.Name)] .. started"
	global:FwCollect_BasicLog

	#### Various EVENT LOG  actions ***
	# A simple way for exporting EventLogs in .evtx and .txt format is done by function FwAddEvtLog ($EvtLogsLAPS array is defined at bottom of this file)
	# Ex: ($EvtLogsLAPS) | ForEach-Object { FwAddEvtLog $_ _Stop_}
	
	#Event Log - Set Log - Enable
	$EventLogSetLogListOn = New-Object 'System.Collections.Generic.List[Object]'
	$EventLogSetLogListOn = @(  #LogName, enabled, retention, quiet, MaxSize
		@("Microsoft-Windows-CAPI2/Operational", "true", "false", "true", "102400000"),
		@("Microsoft-Windows-Kerberos/Operational", "true", "", "", "")
	)
	ForEach ($EventLog in $EventLogSetLogListOn)
	{
	 global:FwEventLogsSet $EventLog[0] $EventLog[1] $EventLog[2] $EventLog[3] $EventLog[4]
	}

	#Event Log - Export Log
	$EventLogExportLogList = New-Object 'System.Collections.Generic.List[Object]'
	$EventLogExportLogList = @(  #LogName, filename, overwrite
		@("Microsoft-Windows-CAPI2/Operational", "c:\dev\Capi2_Oper.evtx", "true"),
		@("Microsoft-Windows-Kerberos/Operational", "c:\dev\Kerberos_Oper.evtx", "true")
	)
	ForEach ($EventLog in $EventLogExportLogList)
	{
	 global:FwExportSingleEventLog $EventLog[0] $EventLog[1] $EventLog[2] 
	}
	#Event Log - Set Log - Disable
	$EventLogSetLogListOff = New-Object 'System.Collections.Generic.List[Object]'
	$EventLogSetLogListOff = @(  #LogName, enabled, retention, quiet, MaxSize
		@("Microsoft-Windows-CAPI2/Operational", "false", "", "", ""),
		@("Microsoft-Windows-Kerberos/Operational", "false", "", "", "")
	)
	ForEach ($EventLog in $EventLogSetLogListOff)
	{
	 global:FwEventLogsSet $EventLog[0] $EventLog[1] $EventLog[2] $EventLog[3] $EventLog[4]
	}

	#Event Log - Clear Log
	$EventLogClearLogList = New-Object 'System.Collections.Generic.List[Object]'
	$EventLogClearLogList = @(  #LogName, enabled, retention, quiet, MaxSize
		@("Microsoft-Windows-CAPI2/Operational"),
		@("Microsoft-Windows-Kerberos/Operational")
	)
	ForEach ($EventLog in $EventLogClearLogList)
	{
		global:FwEventLogClear $EventLog[0] 
	}


	#### Various REGISTRY manipulaiton functions ***
	# A simple way for exporting Regisgtry keys is done by function FwAddRegItem with a registry array defined at bottom of this file ($global:KeysWinLAPS)
	# Ex.: FwAddRegItem @("WinLAPS") _Stop_
	
	# RegAddValues
	$RegAddValues = New-Object 'System.Collections.Generic.List[Object]'

	$RegAddValues = @(  #RegKey, RegValue, Type, Data
		@("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\My Key", "my test1", "REG_DWORD", "0x1"),
		@("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\My Key", "my test2", "REG_DWORD", "0x2")
	)

	ForEach ($regadd in $RegAddValues)
	{
		global:FwAddRegValue $regadd[0] $regadd[1] $regadd[2] $regadd[3]
	}

	# RegExport in TXT
	LogInfo "[$global:TssPhase ADS Stage:] Exporting Reg.keys .. " "gray"
	$RegExportKeyInTxt = New-Object 'System.Collections.Generic.List[Object]'
	$RegExportKeyInTxt = @(  #Key, ExportFile, Format (TXT or REG)
		@("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\My Key", "C:\Dev\regtestexportTXT1.txt", "TXT"),
		@("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL", "C:\Dev\regtestexportTXT2.txt", "TXT")
	)
 
	ForEach ($regtxtexport in $RegExportKeyInTxt)
	{
		global:FwExportRegKey $regtxtexport[0] $regtxtexport[1] $regtxtexport[2]
	}

	# RegExport in REG
	$RegExportKeyInReg = New-Object 'System.Collections.Generic.List[Object]'
	$RegExportKeyInReg = @(  #Key, ExportFile, Format (TXT or REG)
		@("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\My Key", "C:\Dev\regtestexportREG1.reg", "REG"),
		@("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL", "C:\Dev\regtestexportREG2.reg", "REG")
	)
	ForEach ($regregexport in $RegExportKeyInReg)
	{
		global:FwExportRegKey $regregexport[0] $regregexport[1] $regregexport[2]
	}

	# RegDeleteValues
	$RegDeleteValues = New-Object 'System.Collections.Generic.List[Object]'
	$RegDeleteValues = @(  #RegKey, RegValue
		@("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\My Key", "my test1"),
		@("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\My Key", "my test2")
	)
	ForEach ($regdel in $RegDeleteValues)
	{
		global:FwDeleteRegValue $regdel[0] $regdel[1] 
	}
 

	#### FILE COPY Operations ***
	# Create Dest. Folder
	FwCreateFolder $global:LogFolder\Files_test2
	$SourceDestinationPaths = New-Object 'System.Collections.Generic.List[Object]'
	$SourceDestinationPaths = @(  #source (* wildcard is supported) and destination
		@("C:\Dev\my folder\test*", "$global:LogFolder\Files_test2"), 		#this will copy all files that match * criteria into dest folder
		@("C:\Dev\my folder\test1.txt", "$global:LogFolder\Files_test2") 	#this will copy test1.txt to destination file name and add logprefix
	)
	global:FwCopyFiles $SourceDestinationPaths
	EndFunc $MyInvocation.MyCommand.Name
}

function DevTestPostStop{
	EnterFunc $MyInvocation.MyCommand.Name
	LogInfoFile "[$($MyInvocation.MyCommand.Name)] .. started"
	EndFunc $MyInvocation.MyCommand.Name
}
#endregion -------------- DevTest -----------

### Pre-Start / Post-Stop / Collect / Diag function for Components tracing

##### Pre-Start / Post-Stop function for trace
function DEV_TEST1PreStart{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	# Testing FwSetEventLog
	#FwSetEventLog "Microsoft-Windows-CAPI2/Operational" -EvtxLogSize:100000 -ClearLog
	#FwSetEventLog 'Microsoft-Windows-CAPI2/Catalog Database Debug' -EvtxLogSize:102400000
	#$PowerShellEvtLogs = @("Microsoft-Windows-PowerShell/Admin", "Microsoft-Windows-PowerShell/Operational")
	#FwSetEventLog $PowerShellEvtLogs
	EndFunc $MyInvocation.MyCommand.Name
}
function DEV_TEST1PostStart{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	EndFunc $MyInvocation.MyCommand.Name
}
function DEV_TEST1PreStop{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	#LogWarn "** Will do Forced Crash now" cyan
	#FwDoCrash
	EndFunc $MyInvocation.MyCommand.Name
}

function DEV_TEST1PostStop{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	# Testing FwResetEventLog
	#FwResetEventLog 'Microsoft-Windows-CAPI2/Operational'
	#FWResetEventLog 'Microsoft-Windows-CAPI2/Catalog Database Debug'
	#$PowerShellEvtLogs = @("Microsoft-Windows-PowerShell/Admin", "Microsoft-Windows-PowerShell/Operational")
	#FwResetEventLog $PowerShellEvtLogs
	EndFunc $MyInvocation.MyCommand.Name
}


function DEV_TEST2PreStart{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	EndFunc $MyInvocation.MyCommand.Name
}
function DEV_TEST2PostStop{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	EndFunc $MyInvocation.MyCommand.Name
}

function DEV_TEST3PreStart{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	EndFunc $MyInvocation.MyCommand.Name
}
function DEV_TEST3PostStop{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
<#
	$SourceDestinationPaths = New-Object 'System.Collections.Generic.List[Object]'
	$SourceDestinationPaths = @(
		@("$env:ProgramData\Microsoft\WlanSvc\*", "$global:LogFolder\files_ProgramData_WlanSvc"),
		@("C:\Subst_E\test2\2_SDP_RFL", "$global:LogFolder"),
		@("C:\Subst_E\test1\SDP_RFL", "$global:LogFolder\SDP_RFL"),
		@("C:\Subst_E\test2\2_SDP_RFL\*", "$global:LogFolder\SDP_RFL2")
	)
	FwCopyFolders $SourceDestinationPaths -ShowMessage:$True
#>	
	#FwCreateFolder $global:LogFolder\Test2
	$SourceDestinationPaths = New-Object 'System.Collections.Generic.List[Object]'
	$SourceDestinationPaths = @(
		@("C:\Subst_E\folder-missing\*", "$global:LogFolder\folder-missing\"),
		@("C:\Subst_E\test1\file-missing.txt", "$global:LogFolder\file-missing\"),
		@("C:\Subst_E\test1\SDP_RFL\*", "$global:LogFolder\test1-SDP-RFL"),	#<== don't forget the comma when having multi-line arrays!
		@("C:\Subst_E\test2\2_SDP_RFL\Win10*.txt", "$global:LogFolder\Test2\"),
		@("C:\Subst_E\test3\SDP_RFL\WIN10-22H2_230630-181531__Log-transcript.txt", "$global:LogFolder\Test3\my-new.txt")
	)
	FwCopyFiles  $SourceDestinationPaths -ShowMessage:$True
	EndFunc $MyInvocation.MyCommand.Name
}

##### Data Collection
function CollectDEV_TEST1Log{
	EnterFunc $MyInvocation.MyCommand.Name

	$LogPrefix = "Dev_TEST1"
	$LogFolderforDEV_TEST1 = "$Logfolder\Dev_TEST1"
	FwCreateFolder $LogFolderforDEV_TEST1

	<#
	<#--- Log functions ---#>
	#LogDebug "This is message from LogDebug."
	#LogInfo "This is message from LogInfo."
	#LogWarn "This is message from LogWarn."
	#LogError "This is message from LogError."
	#Try{
	#	Throw "Test exception"
	#}Catch{
	#	LogException "This is message from LogException" $_
	#}
	#LogInfoFile "This is message from LogInfoFile."
	#LogWarnFile "This is message from LogWarnFile."
	#LogErrorFile "This is message from LogErrorFile."

	<#--- Test ExportEventLog and FwExportEventLogWithTXTFormat ---#>
	#FwExportEventLog 'System' $LogFolderforDEV_TEST1
	#ExportEventLog "Microsoft-Windows-DNS-Client/Operational" $LogFolderforDEV_TEST1
	#FwExportEventLogWithTXTFormat 'System' $LogFolderforDEV_TEST1

	<#--- FwSetEventLog and FwResetEventLog ---#>
	#$EventLogs = @(
	#	'Microsoft-Windows-WMI-Activity/Trace'
	#	'Microsoft-Windows-WMI-Activity/Debug'
	#)
	#FwSetEventLog $EventLogs
	#Start-Sleep 20
	#FwResetEventLog $EventLogs

	<#--- FwAddEvtLog and FwGetEvtLogList ---#>  
	#($EvtLogsBluetooth) | ForEach-Object { FwAddEvtLog $_ _Stop_}	# see #region groups of Eventlogs for FwAddEvtLog
	#_# Note: FwGetEvtLogList should be called in _Start_Common_Tasks and _Start_Common_Tasks POD functions, otherwise it is called in FW FwCollect_BasicLog/FwCollect_MiniBasicLog functions
		
	<#--- FwAddRegItem and FwGetRegList ---#>
	#FwAddRegItem @("SNMP", "Tcp") _Stop_	# see #region Registry Key modules for FwAddRegItem
	#_# Note: FwGetRegList should be called in _Start_Common_Tasks and _Start_Common_Tasks POD functions, otherwise it is called in FW FwCollect_BasicLog/FwCollect_MiniBasicLog functions

	<#--- Test RunCommands --#>
	#$outFile = "$LogFolderforDEV_TEST1\netinfo.txt"
	#$Commands = @(
	#	"IPCONFIG /ALL | Out-File -Append $outFile"
	#	"netsh interface IP show config | Out-File -Append $outFile"
	#)
	#RunCommands "$LogPrefix" $Commands -ThrowException:$False -ShowMessage:$True

	<#--- FwCopyFiles ---#>
	# Case 1: Copy a single set of files
	#$SourceDestinationPaths = New-Object 'System.Collections.Generic.List[Object]'
	#$SourceDestinationPaths.add(@("C:\Temp\*", "$LogFolderforDEV_TEST1"))
	#FwCopyFiles $SourceDestinationPaths

	# Case 2: Copy a single file
	#$SourceDestinationPaths = New-Object 'System.Collections.Generic.List[Object]'
	#$SourceDestinationPaths.add(@("C:\temp\test-case2.txt", "$LogFolderforDEV_TEST1"))
	#FwCopyFiles $SourceDestinationPaths

	# Case 3: Copy multi sets of files
	#$SourceDestinationPaths = New-Object 'System.Collections.Generic.List[Object]'
	#$SourceDestinationPaths = @(
	#	@("C:\temp\*", "$LogFolderforDEV_TEST1"),
	#	@("C:\temp2\test-case3.txt", "$LogFolderforDEV_TEST1")
	#)
	#FwCopyFiles $SourceDestinationPaths

	<#--- FwExportRegistry and FwExportRegToOneFile ---#>
	#LogInfo '[$LogPrefix] testing FwExportRegistry().'
	#$RecoveryKeys = @(
	#	('HKLM:System\CurrentControlSet\Control\CrashControl', "$LogFolderforDEV_TEST1\Basic_Registry_CrashControl.txt"),
	#	('HKLM:System\CurrentControlSet\Control\Session Manager\Memory Management', "$LogFolderforDEV_TEST1\Basic_Registry_MemoryManagement.txt"),
	#	('HKLM:Software\Microsoft\Windows NT\CurrentVersion\AeDebug', "$LogFolderforDEV_TEST1\Basic_Registry_AeDebug.txt"),
	#	('HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Option', "$LogFolderforDEV_TEST1\Basic_Registry_ImageFileExecutionOption.txt"),
	#	('HKLM:System\CurrentControlSet\Control\Session Manager\Power', "$LogFolderforDEV_TEST1\Basic_Registry_Power.txt")
	#)
	#FwExportRegistry $LogPrefix $RecoveryKeys
	#
	#$StartupKeys = @(
	#	"HKCU:Software\Microsoft\Windows\CurrentVersion\Run",
	#	"HKCU:Software\Microsoft\Windows\CurrentVersion\Runonce",
	#	"HKCU:Software\Microsoft\Windows\CurrentVersion\RunonceEx"
	#)
	#FwExportRegToOneFile $LogPrefix $StartupKeys "$LogFolderforDEV_TEST1\Basic_Registry_RunOnce_reg.txt"

	<#---FwCaptureUserDump ---#>
	# Service
	#FwCaptureUserDump -Name "Winmgmt" -DumpFolder $LogFolderforDEV_TEST1 -IsService:$True
	# Process
	#FwCaptureUserDump -Name "notepad" -DumpFolder $LogFolderforDEV_TEST1
	# PID
	#FwCaptureUserDump -ProcPID 4524 -DumpFolder $LogFolderforDEV_TEST1
	
	<#---general collect functions - often used in _Start/Stop_common_tasks---#>
	#FwClearCaches _Start_ 
	#FwCopyWindirTracing IPhlpSvc 
	#FwDoCrash 
	#FwGetCertsInfo _Stop_ Basic
	#FwGetEnv 
	#FwGetGPresultAS 
	#FwGetKlist 
	#FwGetMsInfo32 
	#FwGetNltestDomInfo 
	#FwGetPoolmon 
	#FwGetProxyInfo 
	#FwGetQwinsta 
	#FwGetRegHives 
	#FwRestartInOwnSvc WebClient
	#FwGetSVC 
	#FwGetSVCactive 
	#FwGetSysInfo 
	#FwGetTaskList 
	#FwGetWhoAmI
	#FwTest-TCPport -ComputerName "cesdiagtools.blob.core.windows.net" -Port 80 -Timeout 900
	
	EndFunc $MyInvocation.MyCommand.Name
}
function CollectDEV_TEST2Log
{
	EnterFunc $MyInvocation.MyCommand.Name
	LogInfo "$($MyInvocation.MyCommand.Name) is called."
	EndFunc $MyInvocation.MyCommand.Name
}

##### Diag function
function RunDEV_TEST1Diag
{
	EnterFunc $MyInvocation.MyCommand.Name
	If($global:BoundParameters.containskey('InputlogPath')){
		$diagpath = $global:BoundParameters['InputlogPath']
		LogInfo "diagpath = $diagpath"
	}
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	EndFunc $MyInvocation.MyCommand.Name
}
<#
function RunDEV_TEST2Diag
{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	EndFunc $MyInvocation.MyCommand.Name
}
#>
#endregion Components Functions

#region Scenario Functions

### Pre-Start / Post-Stop / Collect / Diag function for scenario tracing
##### Common tasks
function DEV_Start_Common_Tasks{
	EnterFunc $MyInvocation.MyCommand.Name
	LogInfo "$($MyInvocation.MyCommand.Name) is called."
	#FwGetRegList _Start_
	#FwGetEvtLogList _Start_
	EndFunc $MyInvocation.MyCommand.Name
}

function DEV_Stop_Common_Tasks{
	EnterFunc $MyInvocation.MyCommand.Name
	LogInfo "$($MyInvocation.MyCommand.Name) is called."
	#FwGetRegList _Stop_
	#FwGetEvtLogList _Stop_
	EndFunc $MyInvocation.MyCommand.Name
}

##### DEV_Scn1
function DEV_Scn1ScenarioPreStart
{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	EndFunc $MyInvocation.MyCommand.Name
}
function DEV_Scn1ScenarioPostStart
{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	EndFunc $MyInvocation.MyCommand.Name
}
function DEV_Scn1ScenarioPreStop
{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	EndFunc $MyInvocation.MyCommand.Name
}
function DEV_Scn1ScenarioPostStop
{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	EndFunc $MyInvocation.MyCommand.Name
}
function CollectDEV_Scn1ScenarioLog
{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	EndFunc $MyInvocation.MyCommand.Name
}
function RunDEV_Scn1ScenarioDiag
{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	EndFunc $MyInvocation.MyCommand.Name
}

##### DEV_Scn2
function DEV_Scn2ScenarioPreStart
{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	EndFunc $MyInvocation.MyCommand.Name
}
function DEV_Scn2ScenarioPostStop
{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	EndFunc $MyInvocation.MyCommand.Name
}
function CollectDEV_Scn2ScenarioLog
{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	EndFunc $MyInvocation.MyCommand.Name
}
<#
function RunDEV_Scn2ScenarioDiag
{
	EnterFunc $MyInvocation.MyCommand.Name
	LogMessage $Loglevel.Info "$($MyInvocation.MyCommand.Name) is called."
	EndFunc $MyInvocation.MyCommand.Name
}
#>


#region DEV_EESummitDemo
function DEV_EESummitDemoPreStart {
	EnterFunc $MyInvocation.MyCommand.Name
	LogInfo "[$($MyInvocation.MyCommand.Name)] .. Enabling Netlogon service debug log"
	FwAddRegValue "HKLM\System\CurrentControlSet\Services\Netlogon\Parameters" "DbFlag" "REG_DWORD" "$global:NetLogonFlag"
	EndFunc $MyInvocation.MyCommand.Name
}

function DEV_EESummitDemoPostStop {
	EnterFunc $MyInvocation.MyCommand.Name
	LogInfo "[$($MyInvocation.MyCommand.Name)] .. Disabling Netlogon service debug log"
	FwAddRegValue "HKLM\System\CurrentControlSet\Services\Netlogon\Parameters" "DbFlag" "REG_DWORD" "0x0"
	EndFunc $MyInvocation.MyCommand.Name
}

function CollectDEV_EESummitDemoLog {
EnterFunc $MyInvocation.MyCommand.Name
	LogInfo "[$($MyInvocation.MyCommand.Name)] Collecting DEV_EESummitDemo logs started."
	# init variables
	$ComputerSystem = Get-WmiObject -Namespace "root\CIMv2" -Class Win32_ComputerSystem
	if (!([string]::IsNullOrEmpty($ComputerSystem))) {
		#$ComputerDomain = $ComputerSystem.Domain
		$DomainRole = $ComputerSystem.DomainRole
	} else {
		#$ComputerDomain = "WORKGROUP"
		$DomainRole = 0
	}
	$RootDSE = [ADSI]"LDAP://RootDSE"
	$DefaultNamingContext = $RootDSE.defaultNamingContext
	if ($Null -ne $DefaultNamingContext) {
		$ConfigurationNamingContext = $RootDSE.configurationNamingContext
		$DCAccessible = $True
	} else {
		$DCAccessible = $False
	}

	#setting commands to execute
	if (($DomainRole -eq 1) -Or ($DomainRole -eq 3) -Or ($DomainRole -eq 4) -Or ($DomainRole -eq 5)) { # Member Workstation, Member Server, BDC, or PDC
		if ($DCAccessible -eq $True) {
			$Commands = @(
				"nltest /dclist: | Out-File -Append $($PrefixTime)nltest_dclist.txt"
				"nltest /dsgetsite | Out-File -Append $($PrefixTime)nltest_dsgetsite.txt"
				"nltest /domain_trusts /all_trusts /v | Out-File -Append $($PrefixTime)nltest_domain_trusts_all_trusts_v.txt"
				"nltest /trusted_domains | Out-File -Append $($PrefixTime)nltest_trusted_domains.txt"
				"w32tm /query /status /verbose | Out-File -Append $($PrefixTime)w32tm_query_status.txt"
				"w32tm /query /configuration | Out-File -Append $($PrefixTime)w32tm_query_config.txt"
				"w32tm /query /peers /verbose | Out-File -Append $($PrefixTime)w32tm_query_peers.txt"
			)
		} else {
			#do nothing
		}
	}
	# executing commands:
	RunCommands $LogPrefix $Commands -ThrowException:$False -ShowMessage:$False

	# FW conveniance function for GPO relevant data
	FwGetGPresultAS 

	# files to copy: source , destination
	$SourceDestinationPaths = @(
		@("$Env:SYSTEMROOT\debug\dcpromo.log", "$($PrefixTime)dcpromo.log"),
		@("$Env:SYSTEMROOT\debug\dcpromoui.log", "$($PrefixTime)dcpromoui.log"),
		@("$Env:SYSTEMROOT\debug\netlogon.log", "$($PrefixTime)netlogon.log"),
		@("$Env:SYSTEMROOT\debug\netsetup.log", "$($PrefixTime)netsetup.log")
	)
	# copying files
	FwCopyFiles $SourceDestinationPaths

	# export registry
	$global:KeysEESummitDemo = @(
		"HKLM:System\CurrentControlSet\Services\W32Time"
		"HKLM:Software\Policies\Microsoft\W32Time"
		"HKLM:System\CurrentControlSet\Services\Netlogon\Parameters"
		"HKLM:Software\Microsoft\Windows NT\CurrentVersion\Winlogon\GPExtensions\{D76B9641-3288-4f75-942D-087DE603E3EA}"
	)
	FwAddRegItem @("EESummitDemo") _Stop_

	#export event logs
	$EvtEESummitDemo = @("Application", "System", "Directory Service")
	($EvtEESummitDemo) | ForEach-Object { FwAddEvtLog $_ _Stop_}

	LogInfo "[$($MyInvocation.MyCommand.Name)] Collecting DEV_EESummit logs ended."
	EndFunc $MyInvocation.MyCommand.Name
}

function CollectDEV_EESummitDemoScenarioLog{
	LogInfo "[$($MyInvocation.MyCommand.Name)] Collecting DEV_EESummitDemoScenario logs started."
	CollectDEV_EESummitDemoLog
}
#endregion DEV_EESummitDemo


#endregion Scenario Functions

#endregion Functions

#region Registry Key modules for FwAddRegItem
<#
	$global:KeysSNMP = @("HKLM:System\CurrentControlSet\Services\SNMP", "HKLM:System\CurrentControlSet\Services\SNMPTRAP")
	$global:KeysWinLAPS = @(
		"HKLM:Software\Microsoft\Policies\LAPS"
		"HKLM:Software\Microsoft\Windows\CurrentVersion\Policies\LAPS"
		"HKLM:Software\Policies\Microsoft Services\AdmPwd"
		"HKLM:Software\Microsoft\Windows\CurrentVersion\LAPS\Config"
		"HKLM:Software\Microsoft\Windows\CurrentVersion\LAPS\State"
		"HKLM:Software\Microsoft\Windows NT\CurrentVersion\Winlogon\GPExtensions\{D76B9641-3288-4f75-942D-087DE603E3EA}"
	)
#>
	<# Example:
	$global:KeysHyperV = @("HKLM:Software\Microsoft\Windows NT\CurrentVersion\Virtualization", "HKLM:System\CurrentControlSet\Services\vmsmp\Parameters")
	#>

 # B) section of NON-recursive lists
 <#
 	$global:KeysDotNETFramework = @(
		"HKLM:Software\Microsoft\.NETFramework\v2.0.50727"
		"HKLM:Software\Wow6432Node\Microsoft\.NETFramework\v2.0.50727"
		"HKLM:Software\Microsoft\.NETFramework\v4.0.30319"
		"HKLM:Software\Wow6432Node\Microsoft\.NETFramework\v4.0.30319"
	)
#>

#endregion Registry Key modules


#endregion Registry Key modules

#region groups of Eventlogs for FwAddEvtLog
<#
	$EvtLogsBluetooth 	= @("Microsoft-Windows-Bluetooth-BthLEPrepairing/Operational", "Microsoft-Windows-Bluetooth-MTPEnum/Operational")
#	$EvtLogsLAPS		= @("Microsoft-Windows-LAPS-Operational", "Microsoft-Windows-LAPS/Operational")
	<# Example:
	$global:EvtLogsEFS	= @("Microsoft-Windows-NTFS/Operational", "Microsoft-Windows-NTFS/WHC")
	#>
#endregion groups of Eventlogs

# Deprecated parameter list. Property array of deprecated/obsoleted params.
#   DeprecatedParam: Parameters to be renamed or obsoleted in the future
#   Type           : Can take either 'Rename' or 'Obsolete'
#   NewParam       : Provide new parameter name for replacement only when Type=Rename. In case of Type='Obsolete', put null for the value.
$DEV_DeprecatedParamList = @(
<#
	@{DeprecatedParam='DEV_kernel';Type='Rename';NewParam='WIN_kernel'}
#	@{DeprecatedParam='DEV_SAM';Type='Rename';NewParam='DEV_SAMsrv'} # <-- this currently fails
	@{DeprecatedParam='DEV_EEsummitDemo';Type='Rename';NewParam='DEV_EEsummitDemo'}
#>
)
Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *



# SIG # Begin signature block
# MIInzgYJKoZIhvcNAQcCoIInvzCCJ7sCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCMmVHHsIA2ii6u
# GDXO3Plyn8H5L3n1LVa9MPEzey4MZqCCDYUwggYDMIID66ADAgECAhMzAAADri01
# UchTj1UdAAAAAAOuMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjMxMTE2MTkwODU5WhcNMjQxMTE0MTkwODU5WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQD0IPymNjfDEKg+YyE6SjDvJwKW1+pieqTjAY0CnOHZ1Nj5irGjNZPMlQ4HfxXG
# yAVCZcEWE4x2sZgam872R1s0+TAelOtbqFmoW4suJHAYoTHhkznNVKpscm5fZ899
# QnReZv5WtWwbD8HAFXbPPStW2JKCqPcZ54Y6wbuWV9bKtKPImqbkMcTejTgEAj82
# 6GQc6/Th66Koka8cUIvz59e/IP04DGrh9wkq2jIFvQ8EDegw1B4KyJTIs76+hmpV
# M5SwBZjRs3liOQrierkNVo11WuujB3kBf2CbPoP9MlOyyezqkMIbTRj4OHeKlamd
# WaSFhwHLJRIQpfc8sLwOSIBBAgMBAAGjggGCMIIBfjAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUhx/vdKmXhwc4WiWXbsf0I53h8T8w
# VAYDVR0RBE0wS6RJMEcxLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVsYW5kIE9wZXJh
# dGlvbnMgTGltaXRlZDEWMBQGA1UEBRMNMjMwMDEyKzUwMTgzNjAfBgNVHSMEGDAW
# gBRIbmTlUAXTgqoXNzcitW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIw
# MTEtMDctMDguY3JsMGEGCCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDEx
# XzIwMTEtMDctMDguY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIB
# AGrJYDUS7s8o0yNprGXRXuAnRcHKxSjFmW4wclcUTYsQZkhnbMwthWM6cAYb/h2W
# 5GNKtlmj/y/CThe3y/o0EH2h+jwfU/9eJ0fK1ZO/2WD0xi777qU+a7l8KjMPdwjY
# 0tk9bYEGEZfYPRHy1AGPQVuZlG4i5ymJDsMrcIcqV8pxzsw/yk/O4y/nlOjHz4oV
# APU0br5t9tgD8E08GSDi3I6H57Ftod9w26h0MlQiOr10Xqhr5iPLS7SlQwj8HW37
# ybqsmjQpKhmWul6xiXSNGGm36GarHy4Q1egYlxhlUnk3ZKSr3QtWIo1GGL03hT57
# xzjL25fKiZQX/q+II8nuG5M0Qmjvl6Egltr4hZ3e3FQRzRHfLoNPq3ELpxbWdH8t
# Nuj0j/x9Crnfwbki8n57mJKI5JVWRWTSLmbTcDDLkTZlJLg9V1BIJwXGY3i2kR9i
# 5HsADL8YlW0gMWVSlKB1eiSlK6LmFi0rVH16dde+j5T/EaQtFz6qngN7d1lvO7uk
# 6rtX+MLKG4LDRsQgBTi6sIYiKntMjoYFHMPvI/OMUip5ljtLitVbkFGfagSqmbxK
# 7rJMhC8wiTzHanBg1Rrbff1niBbnFbbV4UDmYumjs1FIpFCazk6AADXxoKCo5TsO
# zSHqr9gHgGYQC2hMyX9MGLIpowYCURx3L7kUiGbOiMwaMIIHejCCBWKgAwIBAgIK
# YQ6Q0gAAAAAAAzANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlm
# aWNhdGUgQXV0aG9yaXR5IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEw
# OTA5WjB+MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYD
# VQQDEx9NaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+la
# UKq4BjgaBEm6f8MMHt03a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc
# 6Whe0t+bU7IKLMOv2akrrnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4D
# dato88tt8zpcoRb0RrrgOGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+
# lD3v++MrWhAfTVYoonpy4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nk
# kDstrjNYxbc+/jLTswM9sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6
# A4aN91/w0FK/jJSHvMAhdCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmd
# X4jiJV3TIUs+UsS1Vz8kA/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL
# 5zmhD+kjSbwYuER8ReTBw3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zd
# sGbiwZeBe+3W7UvnSSmnEyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3
# T8HhhUSJxAlMxdSlQy90lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS
# 4NaIjAsCAwEAAaOCAe0wggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRI
# bmTlUAXTgqoXNzcitW2oynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTAL
# BgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBD
# uRQFTuHqp8cx0SOJNDBaBgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jv
# c29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3JsMF4GCCsGAQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFf
# MDNfMjIuY3J0MIGfBgNVHSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEF
# BQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1h
# cnljcHMuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkA
# YwB5AF8AcwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn
# 8oalmOBUeRou09h0ZyKbC5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7
# v0epo/Np22O/IjWll11lhJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0b
# pdS1HXeUOeLpZMlEPXh6I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/
# KmtYSWMfCWluWpiW5IP0wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvy
# CInWH8MyGOLwxS3OW560STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBp
# mLJZiWhub6e3dMNABQamASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJi
# hsMdYzaXht/a8/jyFqGaJ+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYb
# BL7fQccOKO7eZS/sl/ahXJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbS
# oqKfenoi+kiVH6v7RyOA9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sL
# gOppO6/8MO0ETI7f33VtY5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtX
# cVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCGZ8wghmbAgEBMIGVMH4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01p
# Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAAOuLTVRyFOPVR0AAAAA
# A64wDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEICRg
# 6A5+sa4uyZ/QTkpu/eaW6pSVMBBIW1wdF0BfhBGVMEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEAx06lDWZupzvqS+PD8I1ixqh8LuNN7DF7x0T0
# oXnATAGJUHyToxVMOWN+uCQ+Na2cMfUhg14Rm76OOSOTCNXbV6NOwTL6G6DBac0g
# XSdt3d5ZyioKkgp+aLJALq6UxU4b7H1V/P4xwy3U8YptGWXtQGntLYADmBPhbMME
# ri9BI/ysLh7/4OnL5D03WHTexp1/af8fbKAbJdLZ8vlnSVyAX13CupGfl/R+gWyN
# yd992UYubXPNE7ZcvuroDepHzTZXwXE2YENuV+iAGftPXg7o0QNtnz2WRHb2LYjK
# 2BqDva4GsMGBBuSuV2WkxoKMD6sBE5LjzQ+5bLfqqTNb8fRSwaGCFykwghclBgor
# BgEEAYI3AwMBMYIXFTCCFxEGCSqGSIb3DQEHAqCCFwIwghb+AgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFZBgsqhkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCCyCdI5RCVq5+xYoy4H/5sfjQp4j4/eZwxd
# 4oTBGbBWUwIGZbqd/PzvGBMyMDI0MDIyMDEyMTU1Ni41ODZaMASAAgH0oIHYpIHV
# MIHSMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQL
# EyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsT
# HVRoYWxlcyBUU1MgRVNOOjhENDEtNEJGNy1CM0I3MSUwIwYDVQQDExxNaWNyb3Nv
# ZnQgVGltZS1TdGFtcCBTZXJ2aWNloIIReDCCBycwggUPoAMCAQICEzMAAAHj372b
# mhxogyIAAQAAAeMwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# UENBIDIwMTAwHhcNMjMxMDEyMTkwNzI5WhcNMjUwMTEwMTkwNzI5WjCB0jELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9z
# b2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjo4RDQxLTRCRjctQjNCNzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAL6k
# DWgeRp+fxSBUD6N/yuEJpXggzBeNG5KB8M9AbIWeEokJgOghlMg8JmqkNsB4Wl1N
# EXR7cL6vlPCsWGLMhyqmscQu36/8h2bx6TU4M8dVZEd6V4U+l9gpte+VF91kOI35
# fOqJ6eQDMwSBQ5c9ElPFUijTA7zV7Y5PRYrS4FL9p494TidCpBEH5N6AO5u8wNA/
# jKO94Zkfjgu7sLF8SUdrc1GRNEk2F91L3pxR+32FsuQTZi8hqtrFpEORxbySgiQB
# P3cH7fPleN1NynhMRf6T7XC1L0PRyKy9MZ6TBWru2HeWivkxIue1nLQb/O/n0j2Q
# Vd42Zf0ArXB/Vq54gQ8JIvUH0cbvyWM8PomhFi6q2F7he43jhrxyvn1Xi1pwHOVs
# bH26YxDKTWxl20hfQLdzz4RVTo8cFRMdQCxlKkSnocPWqfV/4H5APSPXk0r8Cc/c
# Mmva3g4EvupF4ErbSO0UNnCRv7UDxlSGiwiGkmny53mqtAZ7NLePhFtwfxp6ATIo
# jl8JXjr3+bnQWUCDCd5Oap54fGeGYU8KxOohmz604BgT14e3sRWABpW+oXYSCyFQ
# 3SZQ3/LNTVby9ENsuEh2UIQKWU7lv7chrBrHCDw0jM+WwOjYUS7YxMAhaSyOahpb
# udALvRUXpQhELFoO6tOx/66hzqgjSTOEY3pu46BFAgMBAAGjggFJMIIBRTAdBgNV
# HQ4EFgQUsa4NZr41FbehZ8Y+ep2m2YiYqQMwHwYDVR0jBBgwFoAUn6cVXQBeYl2D
# 9OXSZacbUzUZ6XIwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUy
# MDIwMTAoMSkuY3JsMGwGCCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1l
# LVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUB
# Af8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQAD
# ggIBALe+my6p1NPMEW1t70a8Y2hGxj6siDSulGAs4UxmkfzxMAic4j0+GTPbHxk1
# 93mQ0FRPa9dtbRbaezV0GLkEsUWTGF2tP6WsDdl5/lD4wUQ76ArFOencCpK5svE0
# sO0FyhrJHZxMLCOclvd6vAIPOkZAYihBH/RXcxzbiliOCr//3w7REnsLuOp/7vlX
# JAsGzmJesBP/0ERqxjKudPWuBGz/qdRlJtOl5nv9NZkyLig4D5hy9p2Ec1zaotiL
# iHnJ9mlsJEcUDhYj8PnYnJjjsCxv+yJzao2aUHiIQzMbFq+M08c8uBEf+s37YbZQ
# 7XAFxwe2EVJAUwpWjmtJ3b3zSWTMmFWunFr2aLk6vVeS0u1MyEfEv+0bDk+N3jms
# CwbLkM9FaDi7q2HtUn3z6k7AnETc28dAvLf/ioqUrVYTwBrbRH4XVFEvaIQ+i7es
# DQicWW1dCDA/J3xOoCECV68611jriajfdVg8o0Wp+FCg5CAUtslgOFuiYULgcxnq
# zkmP2i58ZEa0rm4LZymHBzsIMU0yMmuVmAkYxbdEDi5XqlZIupPpqmD6/fLjD4ub
# 0SEEttOpg0np0ra/MNCfv/tVhJtz5wgiEIKX+s4akawLfY+16xDB64Nm0HoGs/Gy
# 823ulIm4GyrUcpNZxnXvE6OZMjI/V1AgSAg8U/heMWuZTWVUMIIHcTCCBVmgAwIB
# AgITMwAAABXF52ueAptJmQAAAAAAFTANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0
# IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTAwHhcNMjEwOTMwMTgyMjI1
# WhcNMzAwOTMwMTgzMjI1WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOThpkzntHIhC3miy9ckeb0O
# 1YLT/e6cBwfSqWxOdcjKNVf2AX9sSuDivbk+F2Az/1xPx2b3lVNxWuJ+Slr+uDZn
# hUYjDLWNE893MsAQGOhgfWpSg0S3po5GawcU88V29YZQ3MFEyHFcUTE3oAo4bo3t
# 1w/YJlN8OWECesSq/XJprx2rrPY2vjUmZNqYO7oaezOtgFt+jBAcnVL+tuhiJdxq
# D89d9P6OU8/W7IVWTe/dvI2k45GPsjksUZzpcGkNyjYtcI4xyDUoveO0hyTD4MmP
# frVUj9z6BVWYbWg7mka97aSueik3rMvrg0XnRm7KMtXAhjBcTyziYrLNueKNiOSW
# rAFKu75xqRdbZ2De+JKRHh09/SDPc31BmkZ1zcRfNN0Sidb9pSB9fvzZnkXftnIv
# 231fgLrbqn427DZM9ituqBJR6L8FA6PRc6ZNN3SUHDSCD/AQ8rdHGO2n6Jl8P0zb
# r17C89XYcz1DTsEzOUyOArxCaC4Q6oRRRuLRvWoYWmEBc8pnol7XKHYC4jMYcten
# IPDC+hIK12NvDMk2ZItboKaDIV1fMHSRlJTYuVD5C4lh8zYGNRiER9vcG9H9stQc
# xWv2XFJRXRLbJbqvUAV6bMURHXLvjflSxIUXk8A8FdsaN8cIFRg/eKtFtvUeh17a
# j54WcmnGrnu3tz5q4i6tAgMBAAGjggHdMIIB2TASBgkrBgEEAYI3FQEEBQIDAQAB
# MCMGCSsGAQQBgjcVAgQWBBQqp1L+ZMSavoKRPEY1Kc8Q/y8E7jAdBgNVHQ4EFgQU
# n6cVXQBeYl2D9OXSZacbUzUZ6XIwXAYDVR0gBFUwUzBRBgwrBgEEAYI3TIN9AQEw
# QTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9E
# b2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/
# MB8GA1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJ
# oEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01p
# Y1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYB
# BQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9v
# Q2VyQXV0XzIwMTAtMDYtMjMuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCdVX38Kq3h
# LB9nATEkW+Geckv8qW/qXBS2Pk5HZHixBpOXPTEztTnXwnE2P9pkbHzQdTltuw8x
# 5MKP+2zRoZQYIu7pZmc6U03dmLq2HnjYNi6cqYJWAAOwBb6J6Gngugnue99qb74p
# y27YP0h1AdkY3m2CDPVtI1TkeFN1JFe53Z/zjj3G82jfZfakVqr3lbYoVSfQJL1A
# oL8ZthISEV09J+BAljis9/kpicO8F7BUhUKz/AyeixmJ5/ALaoHCgRlCGVJ1ijbC
# HcNhcy4sa3tuPywJeBTpkbKpW99Jo3QMvOyRgNI95ko+ZjtPu4b6MhrZlvSP9pEB
# 9s7GdP32THJvEKt1MMU0sHrYUP4KWN1APMdUbZ1jdEgssU5HLcEUBHG/ZPkkvnNt
# yo4JvbMBV0lUZNlz138eW0QBjloZkWsNn6Qo3GcZKCS6OEuabvshVGtqRRFHqfG3
# rsjoiV5PndLQTHa1V1QJsWkBRH58oWFsc/4Ku+xBZj1p/cvBQUl+fpO+y/g75LcV
# v7TOPqUxUYS8vwLBgqJ7Fx0ViY1w/ue10CgaiQuPNtq6TPmb/wrpNPgkNWcr4A24
# 5oyZ1uEi6vAnQj0llOZ0dFtq0Z4+7X6gMTN9vMvpe784cETRkPHIqzqKOghif9lw
# Y1NNje6CbaUFEMFxBmoQtB1VM1izoXBm8qGCAtQwggI9AgEBMIIBAKGB2KSB1TCB
# 0jELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMk
# TWljcm9zb2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1U
# aGFsZXMgVFNTIEVTTjo4RDQxLTRCRjctQjNCNzElMCMGA1UEAxMcTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIaAxUAPYiXu8ORQ4hvKcuE
# 7GK0COgxWnqggYMwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAN
# BgkqhkiG9w0BAQUFAAIFAOl+0N4wIhgPMjAyNDAyMjAxNTE4NTRaGA8yMDI0MDIy
# MTE1MTg1NFowdDA6BgorBgEEAYRZCgQBMSwwKjAKAgUA6X7Q3gIBADAHAgEAAgIT
# 0DAHAgEAAgIRhTAKAgUA6YAiXgIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEE
# AYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GB
# AMXz79M6Hsz8abIWVOHEj7Q+95YDYtIF59tXGt2BJsb6m7Y1/QD8wPbHK31d0OMd
# I7MNq5Gp+tsbRqUfJvcvF24fkeeaAk4WnI/B1M5Y6clMyMwyP5yhGHPT/2CpveXe
# AoIu6P2Fvq8+NT2d4wDnx6Ir02DvL5vgUEG4T1xy/AAlMYIEDTCCBAkCAQEwgZMw
# fDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMd
# TWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAHj372bmhxogyIAAQAA
# AeMwDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRAB
# BDAvBgkqhkiG9w0BCQQxIgQgLDYAcSbXUL9gLlSlaG9O4CGzG9ZWdY0CVrsROxRs
# r7owgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCAz1COr5bD+ZPdEgQjWvcIW
# uDJcQbdgq8Ndj0xyMuYmKjCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwAhMzAAAB49+9m5ocaIMiAAEAAAHjMCIEIC67bLUdvhwxGnlwg4WWp3Km
# Qx/KYyJiM+0z7xYkba3UMA0GCSqGSIb3DQEBCwUABIICACOfhVb4T2oy3BdCHUAX
# k25ruwEfADNkv+lAlWpiJHPwEQtTaRTL6YU6pVMtvHB7tyOg0ECJNskkiEo/ZkzI
# njxx0KeRtEVBp2mRck1yM6FNvKrDnTMI5JgW+cCacpWvXn8GY7d/B0kjk4Hdv/3R
# Ryc8wxd4A5pAcgh5fJAPsHIFhrT3nJJHLrPl90b1EDIE7rzY95rWNtDl8rmEbnad
# 1MsgdbHTR2cp5w+4i93AYbhzNsU66jxKqmp8LK+MbC++0AjqxBmpFT8Kjck68xsq
# RiuN1wmvZ6SuqNkInnduT+HIOTvIgkOnm0Kf71dsSuKHI/3WdwgEBY9f0CxPf9sO
# I8lIWrFOpyAYI/ChNBTmdX+eB4h1hNaFJUYe4qLo21NzYzCLpcHS+fhuhKDMQJ6R
# HxS6fLRTKpsTWTTHmEQL1U/3N033o3LsTD9OH/x23hJzsV5yAEOFw3C0VHG5hvn4
# dnesEyNkvXxRFb1PmfjqRW3yTTNHEXsGah5GKjm5HVxbI0zXV/vkeFhTwpvIt1RY
# +gz1Fbje5x+CR2+CqzDk49ry6zHr6FYgzrCL5rh4azMNOnt4K8XFe0CMUA5sdEAE
# Pc6JUe/z3XaGmimRHOQ7k57ZxIYPquvHShqH8j7k4AbmCkHJjTCRcHhCYnQQhST8
# rsANjP15JfDFCd6WLgovtDtF
# SIG # End signature block
