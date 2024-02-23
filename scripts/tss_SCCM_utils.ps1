###########################################################################################################################
# Utility Script: This is a library of utility functions for SCCM taken from psSDP.
# Description: Load common variables/functions.
#		 		1. Defines commonly used functions in the Troubleshooter
#		 		2. Defines global variables
#		 		3. Detects Configuration Manager Client and Server Roles Installation Status
#				4. Detects Install and Log Locations for Client, Server, Admin Console and WSUS
#				5. Executes WSUSutil.exe checkhealth, if WSUS is installed.
# Author: credits to the original authors in psSDP, gathered by TSS Dev Team
###########################################################################################################################

# check if the script is already loaded and if not, load it and set the flag
if (-not $script:SCCM_utils) {
	$script:SCCM_utils = $true
	LogInfo 'Loading SCCM utility functions.' White
}
else {
	LogWarn 'SCCM utility functions already loadad. Skipping ...'
	return
}

trap [Exception] {
	LogException 'Something went wrong:' $_
	continue
}

# function Definitions
##########################
function AddTo-CMClientSummary() {
	# Adds the specified name/value to the appropriate CMClient PS Objects so that they can be dumped to File & Report in DC_FinishExecution.
	param (
		$Name,
		$Value,
		[switch]$NoToSummaryFile,
		[switch]$NoToSummaryReport
	)
	process {
		EnterFunc $MyInvocation.MyCommand.Name
		if (-not($NoToSummaryFile)) {
			Add-Member -InputObject $global:CMClientFileSummaryPSObject -MemberType NoteProperty -Name $Name -Value $Value
		}

		if (-not($NoToSummaryReport)) {
			Add-Member -InputObject $global:CMClientReportSummaryPSObject -MemberType NoteProperty -Name $Name -Value $Value
		}
		EndFunc $MyInvocation.MyCommand.Name
	}
}

function AddTo-CMServerSummary() {
	# Adds the specified name/value to the appropriate CMServer PS Objects so that they can be dumped to File & Report in DC_FinishExecution.
	param (
		$Name,
		$Value,
		[switch]$NoToSummaryFile,
		[switch]$NoToSummaryReport
	)
	process {
		EnterFunc $MyInvocation.MyCommand.Name
		if (-not($NoToSummaryFile)) {
			Add-Member -InputObject $global:CMServerFileSummaryPSObject -MemberType NoteProperty -Name $Name -Value $Value
		}

		if (-not($NoToSummaryReport)) {
			Add-Member -InputObject $global:CMServerReportSummaryPSObject -MemberType NoteProperty -Name $Name -Value $Value
		}
		EndFunc $MyInvocation.MyCommand.Name
	}
}

function AddTo-CMDatabaseSummary() {
	# Adds the specified name/value to the appropriate CMDatabase PS Objects so that they can be dumped to File & Report in DC_FinishExecution.
	param (
		$Name,
		$Value,
		[switch]$NoToSummaryFile,
		[switch]$NoToSummaryReport,
		[switch]$NoToSummaryQueries
	)
	process {
		EnterFunc $MyInvocation.MyCommand.Name
		if (-not($NoToSummaryFile)) {
			Add-Member -InputObject $global:CMDatabaseFileSummaryPSObject -MemberType NoteProperty -Name $Name -Value $Value
		}

		if (-not($NoToSummaryReport)) {
			Add-Member -InputObject $global:CMDatabaseReportSummaryPSObject -MemberType NoteProperty -Name $Name -Value $Value
		}

		if (-not($NoToSummaryQueries)) {
			Add-Member -InputObject $global:CMDatabaseQuerySummaryPSObject -MemberType NoteProperty -Name $Name -Value $Value
		}
		EndFunc $MyInvocation.MyCommand.Name
	}
}

function Get-ADKVersion() {
	process {
		EnterFunc $MyInvocation.MyCommand.Name
		LogInfo 'Get-ADKVersion: Entering'
		$UninstallKey = 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
		$ADKKey = Get-ChildItem $UninstallKey -Recurse | ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.DisplayName -like '*Assessment and Deployment Kit*' }

		if ($ADKKey) {
			return $ADKKey.DisplayVersion
		}
		else {
			return 'ADK Version Not Found.'
		}
		LogInfo 'Get-ADKVersion: Leaving'
		EndFunc $MyInvocation.MyCommand.Name
	}
}

function Get-TSRemote {
	EnterFunc $MyInvocation.MyCommand.Name
	# Get-TSRemote is used to identify when the environment is running under TS_Remote
	# The following return values can be returned:
	#    0 - No TS_Remote environment
	#    1 - Under TS_Remote environment, but running on the local machine
	#    2 - Under TS_Remote environment and running on a remote machine
	if ($null -ne $global:TS_RemoteLevel) {
		return $global:TS_RemoteLevel
	}
	else {
		return 0
	}
	EndFunc $MyInvocation.MyCommand.Name
}

function Check-RegKeyExists($RegKey) {
	EnterFunc $MyInvocation.MyCommand.Name
	# To check if a Registry Key exists
	# Taken from Kurt Saren's FEP Scripts
	$RegKey = $RegKey -replace 'HKLM\\', 'HKLM:\'
	$RegKey = $RegKey -replace 'HKCU\\', 'HKCU:\'
	try {
		return (Test-Path $RegKey)
	}
	catch {}
	EndFunc $MyInvocation.MyCommand.Name
}

function Get-RegValue($RegKey, $RegValue) {
	EnterFunc $MyInvocation.MyCommand.Name
	# To get a specified Registry Value
	# Taken from Kurt Saren's FEP Scripts
	$RegKey = $RegKey -replace 'HKLM\\', 'HKLM:\'
	$RegKey = $RegKey -replace 'HKCU\\', 'HKCU:\'
	try {
		if (Check-RegValueExists $RegKey $RegValue) {
			return (Get-ItemProperty -Path $RegKey -ErrorAction Ignore).$RegValue
		}
		else {
			return $null
		}
	}
	catch {
		LogException 'Error occurred while accessing registry:' $_
		$false
	}
	EndFunc $MyInvocation.MyCommand.Name
}

function Check-RegValueExists($RegKey, $RegValue) {
	EnterFunc $MyInvocation.MyCommand.Name

	# To check if a Registry Value exists
	$RegKey = $RegKey -replace 'HKLM\\', 'HKLM:\'
	$RegKey = $RegKey -replace 'HKCU\\', 'HKCU:\'
	try {
		if (Test-Path $RegKey) {
			$property = Get-ItemProperty -Path $RegKey -Name $RegValue -ErrorAction Ignore
			if ($property) {
				$true
			}
			else {
				$false
			}
		}
		else {
			$false
		}
	}
	catch {
		LogException 'Error occurred while accessing registry:' $_
		$false
	}
	EndFunc $MyInvocation.MyCommand.Name
}

function Get-RegValueWithError($RegKey, $RegValue) {
	# Modified version of Get-RegValue to get the error as well, instead of checking if the value is null everytime I call Get-RegValue
	$RegKey = $RegKey -replace 'HKLM\\', 'HKLM:\'
	$RegKey = $RegKey -replace 'HKCU\\', 'HKCU:\'
	if (Check-RegValueExists $RegKey $RegValue) {
		$Value = (Get-ItemProperty -Path $RegKey -ErrorAction SilentlyContinue -ErrorVariable RegError).$RegValue
		if ($RegError.Count -gt 0) {
			Return "ERROR: $($RegValue.Exception[0].Message)"
		}
		if ($null -ne $Value) {
			Return $Value
		}
		else {
			return 'ERROR: Registry value is NULL.'
		}
	}
	else {
		return 'ERROR: Registry value does not exist.'
	}
}

function Get-ComputerArchitecture() {
	EnterFunc $MyInvocation.MyCommand.Name
	# The function below is used to build the global variable $OSArchitecture.
	# You can use the $OSArchitecture to define the computer architecture. Current Values are:
	# X86 - 32-bit
	# AMD64 - 64-bit
	# IA64 - 64-bit
	if (($Env:PROCESSOR_ARCHITEW6432).Length -gt 0) {
		#running in WOW
		return $Env:PROCESSOR_ARCHITEW6432
	}
	else {
		return $Env:PROCESSOR_ARCHITECTURE
	}
	EndFunc $MyInvocation.MyCommand.Name
}

## SMS Provider and Database functions
#########################################
function Get-DBConnection() {
	param (
		$DatabaseServer,
		$DatabaseName
	)
	process {
		EnterFunc $MyInvocation.MyCommand.Name
		LogInfo 'Get-DBConnection: Entering'
		try {
			# Get NetBIOS name of the Database Server
			if ($DatabaseServer.Contains('.')) {
				$DatabaseServer = $DatabaseServer.Substring(0, $DatabaseServer.IndexOf('.'))
			}

			# Prepare a Connection String
			if ($DatabaseName.Contains('\')) {
				$InstanceName = $DatabaseName.Substring(0, $DatabaseName.IndexOf('\'))
				$DatabaseName = $DatabaseName.Substring($DatabaseName.IndexOf('\') + 1)
				$strConnString = "Integrated Security=SSPI; Application Name=ConfigMgr Diagnostics; Server=$DatabaseServer\$InstanceName; Database=$DatabaseName"
			}
			else {
				$strConnString = "Integrated Security=SSPI; Application Name=ConfigMgr Diagnostics; Server=$DatabaseServer; Database=$DatabaseName"
			}

			$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
			$SqlConnection.ConnectionString = $strConnString
			LogInfo "SQL Connection String: $strConnString"

			$Error.Clear()
			$SqlConnection.Open()
			LogInfo 'Get-DBConnection: Successful'

			# Reset Error Variable only when we're connecting to SCCM database and the connection is successful.
			# if SCCM database connection failed, TS_CheckSQLConfig will retry connection to MASTER, but we don't want to reset Error Variable in that case, if connection succeeds.
			if ($DatabaseName.ToUpper() -ne 'MASTER') {
				$global:DatabaseConnectionError = $null
			}
		}
		catch [Exception] {
			$global:DatabaseConnectionError = $_
			$SqlConnection = $null
			LogWarn "Get-DBConnection: Failed with Error: $global:DatabaseConnectionError"
		}

		LogInfo 'Get-DBConnection: Leaving'
		return $SqlConnection
		EndFunc $MyInvocation.MyCommand.Name
	}
}

# function Definitions
##########################################

function Get-SCCMOsVerName($bn) {
	EnterFunc $MyInvocation.MyCommand.Name
	switch ($bn) {
		22631 { return 'W11v23H2' }
		22621 { return 'W11v22H2' }
		22000 { return 'W11v21H2' }
		20348 { return 'WS2022' }
		22000 { return 'Win11' }
		19044 { return 'W10v21H2' }
		19043 { return 'W10v21H1' }
		19042 { return 'W10v20H2' }
		19041 { return 'W10v2004' }
		17763 { return 'W10v1809/WS2019' }
		14393 { return 'W10v1607/WS2016' }
		10240 { return 'W10rtm' }
		9600 { return 'W8.1/WS2012R2' }
		9200 { return 'W8/WS2012' }
		7601 { return 'W7/WS2008R2 SP1' }
		7600 { return 'W7/WS2008R2 RTM' }
		6003 { return 'Vista/WS2008' }
		6002 { return 'Vista/WS2008' }
		default { return 'unknown-OS' }
	}
	EndFunc $MyInvocation.MyCommand.Name
}

function Get-SCCMOsSkuName($sku) {
	EnterFunc $MyInvocation.MyCommand.Name
	switch ($sku) {
		# GetProductInfo function
		# http://msdn.microsoft.com/en-us/library/ms724358.aspx
		#
		0 { return '' }
		1 { return 'Ultimate Edition' }
		2 { return 'Home Basic Edition' }
		3 { return 'Home Basic Premium Edition' }
		4 { return 'Enterprise Edition' }
		5 { return 'Home Basic N Edition' }
		6 { return 'Business Edition' }
		7 { return 'Standard Server Edition' }
		8 { return 'Datacenter Server Edition' }
		9 { return 'Small Business Server Edition' }
		10 { return 'Enterprise Server Edition' }
		11 { return 'Starter Edition' }
		12 { return 'Datacenter Server Core Edition' }
		13 { return 'Standard Server Core Edition' }
		14 { return 'Enterprise Server Core Edition' }
		15 { return 'Enterprise Server Edition for Itanium-Based Systems' }
		16 { return 'Business N Edition' }
		17 { return 'Web Server Edition' }
		18 { return 'Cluster Server Edition' }
		19 { return 'Home Server Edition' }
		20 { return 'Storage Express Server Edition' }
		21 { return 'Storage Standard Server Edition' }
		22 { return 'Storage Workgroup Server Edition' }
		23 { return 'Storage Enterprise Server Edition' }
		24 { return 'Server For Small Business Edition' }
		25 { return 'Small Business Server Premium Edition' } # 0x00000019
		26 { return 'Home Premium N Edition' } # 0x0000001a
		27 { return 'Enterprise N Edition' } # 0x0000001b
		28 { return 'Ultimate N Edition' } # 0x0000001c
		29 { return 'Web Server Edition (core installation)' } # 0x0000001d
		30 { return 'Windows Essential Business Server Management Server' } # 0x0000001e
		31 { return 'Windows Essential Business Server Security Server' } # 0x0000001f
		32 { return 'Windows Essential Business Server Messaging Server' } # 0x00000020
		33 { return 'Server Foundation' } # 0x00000021
		34 { return 'Windows Home Server 2011' } # 0x00000022 not found
		35 { return 'Windows Server 2008 without Hyper-V for Windows Essential Server Solutions' } # 0x00000023
		36 { return 'Server Standard Edition without Hyper-V (full installation)' } # 0x00000024
		37 { return 'Server Datacenter Edition without Hyper-V (full installation)' } # 0x00000025
		38 { return 'Server Enterprise Edition without Hyper-V (full installation)' } # 0x00000026
		39 { return 'Server Datacenter Edition without Hyper-V (core installation)' } # 0x00000027
		40 { return 'Server Standard Edition without Hyper-V (core installation)' } # 0x00000028
		41 { return 'Server Enterprise Edition without Hyper-V (core installation)' } # 0x00000029
		42 { return 'Microsoft Hyper-V Server' } # 0x0000002a
		43 { return 'Storage Server Express (core installation)' } # 0x0000002b
		44 { return 'Storage Server Standard (core installation)' } # 0x0000002c
		45 { return 'Storage Server Workgroup (core installation)' } # 0x0000002d
		46 { return 'Storage Server Enterprise (core installation)' } # 0x0000002e
		47 { return 'Starter N' } # 0x0000002f
		48 { return 'Professional Edition' } #0x00000030
		49 { return 'ProfessionalN Edition' } #0x00000031
		50 { return 'Windows Small Business Server 2011 Essentials' } #0x00000032
		51 { return 'Server For SB Solutions' } #0x00000033
		52 { return 'Server Solutions Premium' } #0x00000034
		53 { return 'Server Solutions Premium (core installation)' } #0x00000035
		54 { return 'Server For SB Solutions EM' } #0x00000036
		55 { return 'Server For SB Solutions EM' } #0x00000037
		55 { return 'Windows MultiPoint Server' } #0x00000038
		#not found: 3a
		59 { return 'Windows Essential Server Solution Management' } #0x0000003b
		60 { return 'Windows Essential Server Solution Additional' } #0x0000003c
		61 { return 'Windows Essential Server Solution Management SVC' } #0x0000003d
		62 { return 'Windows Essential Server Solution Additional SVC' } #0x0000003e
		63 { return 'Small Business Server Premium (core installation)' } #0x0000003f
		64 { return 'Server Hyper Core V' } #0x00000040
		#0x00000041 not found
		#0x00000042-48 not supported
		76 { return 'Windows MultiPoint Server Standard (full installation)' } #0x0000004C
		77 { return 'Windows MultiPoint Server Premium (full installation)' } #0x0000004D
		79 { return 'Server Standard (evaluation installation)' } #0x0000004F
		80 { return 'Server Datacenter (evaluation installation)' } #0x00000050
		84 { return 'Enterprise N (evaluation installation)' } #0x00000054
		95 { return 'Storage Server Workgroup (evaluation installation)' } #0x0000005F
		96 { return 'Storage Server Standard (evaluation installation)' } #0x00000060
		98 { return 'Windows 8 N' } #0x00000062
		99 { return 'Windows 8 China' } #0x00000063
		100 { return 'Windows 8 Single Language' } #0x00000064
		101 { return 'Windows 8' } #0x00000065
		102 { return 'Professional with Media Center' } #0x00000067
	}
	EndFunc $MyInvocation.MyCommand.Name
}

function Get-SCCMSrvSKU {
	EnterFunc $MyInvocation.MyCommand.Name
	try {
		$IsServerSKU = (Get-CimInstance -Class CIM_OperatingSystem -ErrorAction Stop).Caption -like '*Server*'
	}
	catch {
		LogException 'An exception happened in Get-CimInstance for CIM_OperatingSystem' $_
		$IsServerSKU = $False
	}
	return $IsServerSKU
	EndFunc $MyInvocation.MyCommand.Name
}

function Get-SCCMSrvRole {
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string] $Outfile
	)
	EnterFunc $MyInvocation.MyCommand.Name
	if ($IsServerSKU) {
		# get Windows Feature and Role (on Windows Server 2008R2+)
		Get-WindowsFeature | Where-Object { $_.installed -eq $true } | Out-File -Append $OutputFile
		Get-WindowsFeature -ErrorAction Stop | Out-File -Append $OutputFile
	}
	else {
		if ($bn -gt 9200) {
			# Client >= 2012
			Get-WindowsOptionalFeature -Online | Format-Table -AutoSize | Out-File -Append $OutputFile
		}
	}
	EndFunc $MyInvocation.MyCommand.Name
}

# Taken from https://gallery.technet.microsoft.com/scriptcenter/Get-PendingReboot-Query-bdb79542
function Get-PendingReboot {
	<#
	.SYNOPSIS
		Gets the pending reboot status on a local or remote computer.

	.DESCRIPTION
		This function will query the registry on a local or remote computer and determine if the
		system is pending a reboot, from either Microsoft Patching or a Software Installation.
		For Windows 2008+ the function will query the CBS registry key as another factor in determining
		pending reboot state.  "PendingFileRenameOperations" and "Auto Update\RebootRequired" are observed
		as being consistant across Windows Server 2003 & 2008.

		CBServicing = Component Based Servicing (Windows 2008)
		WindowsUpdate = Windows Update / Auto Update (Windows 2003 / 2008)
		CCMClientSDK = SCCM 2012 Clients only (DetermineifRebootPending method) otherwise $null value
		PendFileRename = PendingFileRenameOperations (Windows 2003 / 2008)

	.PARAMETER ComputerName
		A single Computer or an array of computer names.  The default is localhost ($env:COMPUTERNAME).

	.PARAMETER ErrorLog
		A single path to send error data to a log file.

	.EXAMPLE
		PS C:\> Get-PendingReboot -ComputerName (Get-Content C:\ServerList.txt) | Format-Table -AutoSize

		Computer CBServicing WindowsUpdate CCMClientSDK PendFileRename PendFileRenVal RebootPending
		-------- ----------- ------------- ------------ -------------- -------------- -------------
		DC01     False   False           False      False
		DC02     False   False           False      False
		FS01     False   False           False      False

		This example will capture the contents of C:\ServerList.txt and query the pending reboot
		information from the systems contained in the file and display the output in a table. The
		null values are by design, since these systems do not have the SCCM 2012 client installed,
		nor was the PendingFileRenameOperations value populated.

	.EXAMPLE
		PS C:\> Get-PendingReboot

		Computer     : WKS01
		CBServicing  : False
		WindowsUpdate      : True
		CCMClient    : False
		PendComputerRename : False
		PendFileRename     : False
		PendFileRenVal     :
		RebootPending      : True

		This example will query the local machine for pending reboot information.

	.EXAMPLE
		PS C:\> $Servers = Get-Content C:\Servers.txt
		PS C:\> Get-PendingReboot -Computer $Servers | Export-Csv C:\PendingRebootReport.csv -NoTypeInformation

		This example will create a report that contains pending reboot information.

	.LINK
		Component-Based Servicing:
		http://technet.microsoft.com/en-us/library/cc756291(v=WS.10).aspx

		PendingFileRename/Auto Update:
		http://support.microsoft.com/kb/2723674
		http://technet.microsoft.com/en-us/library/cc960241.aspx
		http://blogs.msdn.com/b/hansr/archive/2006/02/17/patchreboot.aspx

		SCCM 2012/CCM_ClientSDK:
		http://msdn.microsoft.com/en-us/library/jj902723.aspx

	.NOTES
		Author:  Brian Wilhite
		Email:   bcwilhite (at) live.com
		Date:    29AUG2012
		PSVer:   2.0/3.0/4.0/5.0
		Updated: 01DEC2014
		UpdNote: Added CCMClient property - Used with SCCM 2012 Clients only
			Added ValueFromPipelineByPropertyName=$true to the ComputerName parameter
			Removed $Data variable from the PSObject - it is not needed
			Bug with the way CCMClientSDK returned null value if it was false
			Removed unneeded variables
			Added PendFileRenVal - Contents of the PendingFileRenameOperations Reg Entry
			Removed .Net Registry connection, replaced with WMI StdRegProv
			Added ComputerPendingRename
	#>
	[CmdletBinding()]
	param (
		[Parameter(Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[Alias('CN', 'Computer')]
		[String[]]$ComputerName = "$env:COMPUTERNAME"
	)

	begin { }## Begin Script Block
	process {
		EnterFunc $MyInvocation.MyCommand.Name
		LogInfo "$($MyInvocation.MyCommand.Name) entered."
		$Computer = $ComputerName
		# Get the local computer name
		$localComputerName = [System.Net.Dns]::GetHostName()

		try {
			## Setting pending values to false to cut down on the number of else statements
			$CompPendRen, $PendFileRename, $Pending, $SCCM = $false, $false, $false, $false

			## Setting CBSRebootPend to null since not all versions of Windows has this value
			$CBSRebootPend = $null

			## Check if $env:COMPUTERNAME matches the local computer name
			if ($env:COMPUTERNAME -eq $localComputerName) {
				LogInfo "$($MyInvocation.MyCommand.Name) is running on the local computer omitting the -ComputerName parameter."
				try {
					## Querying WMI for build version
					$WMI_OS = Get-CimInstance -Class Win32_OperatingSystem -Property BuildNumber, CSName -ErrorAction Stop
				}
				catch {
					LogWarn "Error occurred: $($_.Exception.Message)"
					LogWarn "CimException: $($_.Exception.InnerException.Message)"
				}
			}
			else {
				LogInfo "$($MyInvocation.MyCommand.Name) is about to run on a remote on $Computer."
				try {
					## Querying WMI for build version
					$WMI_OS = Get-CimInstance -Class Win32_OperatingSystem -Property BuildNumber, CSName -ComputerName $Computer -ErrorAction Stop
				}
				catch {
					LogWarn "Error occurred: $($_.Exception.Message)"
					LogWarn "CimException: $($_.Exception.InnerException.Message)"
				}
			}

			## Making registry connection to the local/remote computer
			$HKLM = [UInt32] '0x80000002'
			$WMI_Reg = [WMIClass] "\\$Computer\root\default:StdRegProv"

			## if Vista/2008 & Above query the CBS Reg Key
			if ([Int32]$WMI_OS.BuildNumber -ge 6001) {
				$RegSubKeysCBS = $WMI_Reg.EnumKey($HKLM, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\')
				$CBSRebootPend = $RegSubKeysCBS.sNames -contains 'RebootPending'
			}

			## Query WUAU from the registry
			$RegWUAURebootReq = $WMI_Reg.EnumKey($HKLM, 'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\')
			$WUAURebootReq = $RegWUAURebootReq.sNames -contains 'RebootRequired'

			## Query PendingFileRenameOperations from the registry
			$RegSubKeySM = $WMI_Reg.GetMultiStringValue($HKLM, 'SYSTEM\CurrentControlSet\Control\Session Manager\', 'PendingFileRenameOperations')
			$RegValuePFRO = $RegSubKeySM.sValue

			## Query ComputerName and ActiveComputerName from the registry
			$ActCompNm = $WMI_Reg.GetStringValue($HKLM, 'SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName\', 'ComputerName')
			$CompNm = $WMI_Reg.GetStringValue($HKLM, 'SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName\', 'ComputerName')
			if ($ActCompNm -ne $CompNm) {
				$CompPendRen = $true
			}

			## if PendingFileRenameOperations has a value set $RegValuePFRO variable to $true
			if ($RegValuePFRO) {
				$PendFileRename = $true
			}

			## Determine SCCM 2012 Client Reboot Pending Status
			## To avoid nested 'if' statements and unneeded WMI calls to determine if the CCM_ClientUtilities class exist, setting EA = 0
			$CCMClientSDK = $null
			$CCMSplat = @{
				NameSpace    = 'ROOT\ccm\ClientSDK'
				Class        = 'CCM_ClientUtilities'
				Name         = 'DetermineifRebootPending'
				ComputerName = $Computer
				ErrorAction  = 'Stop'
			}
			## Try CCMClientSDK
			try {
				$CCMClientSDK = Invoke-WmiMethod @CCMSplat
			}
			catch [System.UnauthorizedAccessException] {
				$CcmStatus = Get-Service -Name CcmExec -ComputerName $Computer -ErrorAction SilentlyContinue
				if ($CcmStatus.Status -ne 'Running') {
					LogWarn "$($MyInvocation.MyCommand.Name) Error: CcmExec service is not running."
					$CCMClientSDK = $null
				}
			}
			catch {
				$CCMClientSDK = $null
			}

			if ($CCMClientSDK) {
				if ($CCMClientSDK.returnValue -ne 0) {
					LogWarn "$($MyInvocation.MyCommand.Name) Error: DetermineifRebootPending returned error code $($CCMClientSDK.returnValue)."
				}
				if ($CCMClientSDK.IsHardRebootPending -or $CCMClientSDK.RebootPending) {
					$SCCM = $true
				}
			}
			else {
				$SCCM = $null
			}

			## Creating Custom PSObject and Select-Object Splat
			$SelectSplat = @{
				Property = (
					'Computer',
					'RebootPending',
					'CBS',
					'WindowsUpdate',
					'CCMClientSDK',
					'PendingComputerRename',
					'PendingFileRenameOperations',
					'PendingFileRenameValue'
				)
			}
			New-Object -TypeName PSObject -Property @{
				Computer                    = $WMI_OS.CSName
				RebootPending               = ($CompPendRen -or $CBSRebootPend -or $WUAURebootReq -or $SCCM -or $PendFileRename)
				CBS                         = $CBSRebootPend
				WindowsUpdate               = $WUAURebootReq
				CCMClientSDK                = $SCCM
				PendingComputerRename       = $CompPendRen
				PendingFileRenameOperations = $PendFileRename
				PendingFileRenameValue      = $RegValuePFRO
			} | Select-Object @SelectSplat
		}
		catch {
			LogException "$($MyInvocation.MyCommand.Name) Error:" $_
		}
		LogInfo "$($MyInvocation.MyCommand.Name) exited."
		EndFunc $MyInvocation.MyCommand.Name
	} ## End Process
	End { }## End End
}
## End function Get-PendingReboot

function Get-CertInfo {
	param ($Path)
	EnterFunc $MyInvocation.MyCommand.Name
	$CertInfoTemp = Get-ChildItem $Path -ErrorAction SilentlyContinue
	if (($CertInfoTemp | Measure-Object).Count -gt 0) {
		$return = $CertInfoTemp | Select-Object Subject, Issuer, Thumbprint, HasPrivateKey, NotAfter, NotBefore, FriendlyName | Format-Table -AutoSize | Out-String -Width 1000
	}
	else {
		$return = "`r`n  None.`r`n`r`n"
	}
	return $return
	EndFunc $MyInvocation.MyCommand.Name
}

function Replace-XMLChars($RAWString) {
	EnterFunc $MyInvocation.MyCommand.Name
	$RAWString -replace ('&', '&amp;') -replace ("`"", '&quot;') -Replace ("'", '&apos;') -replace ('<', '&lt;') -replace ('>', '&gt;')
	EndFunc $MyInvocation.MyCommand.Name
}

function GetAgeDescription($TimeSpan, [switch] $Localized) {
	EnterFunc $MyInvocation.MyCommand.Name
	$Age = $TimeSpan
	if ($Age.Days -gt 0) {
		$AgeDisplay = $Age.Days.ToString()
		if ($Age.Days -gt 1) {
			if ($Localized.IsPresent) {
				$AgeDisplay += ' ' + $UtilsCTSStrings.ID_Days
			}
			else {
				$AgeDisplay += ' Days'
			}
		}
		else {
			if ($Localized.IsPresent) {
				$AgeDisplay += ' ' + $UtilsCTSStrings.ID_Day
			}
			else {
				$AgeDisplay += ' Day'
			}
		}
	}
	else {
		if ($Age.Hours -gt 0) {
			if ($AgeDisplay.Length -gt 0) { $AgeDisplay += ' ' }
			$AgeDisplay = $Age.Hours.ToString()
			if ($Age.Hours -gt 1) {
				if ($Localized.IsPresent) {
					$AgeDisplay += ' ' + $UtilsCTSStrings.ID_Hours
				}
				else {
					$AgeDisplay += ' Hours'
				}
			}
			else {
				if ($Localized.IsPresent) {
					$AgeDisplay += ' ' + $UtilsCTSStrings.ID_Hour
				}
				else {
					$AgeDisplay += ' Hour'
				}
			}
		}
		if ($Age.Minutes -gt 0) {
			if ($AgeDisplay.Length -gt 0) { $AgeDisplay += ' ' }
			$AgeDisplay += $Age.Minutes.ToString()
			if ($Age.Minutes -gt 1) {
				if ($Localized.IsPresent) {
					$AgeDisplay += ' ' + $UtilsCTSStrings.ID_Minutes
				}
				else {
					$AgeDisplay += ' Minutes'
				}
			}
			else {
				if ($Localized.IsPresent) {
					$AgeDisplay += ' ' + $UtilsCTSStrings.ID_Minute
				}
				else {
					$AgeDisplay += ' Minute'
				}
			}
		}
		if ($Age.Seconds -gt 0) {
			if ($AgeDisplay.Length -gt 0) { $AgeDisplay += ' ' }
			$AgeDisplay += $Age.Seconds.ToString()
			if ($Age.Seconds -gt 1) {
				if ($Localized.IsPresent) {
					$AgeDisplay += ' ' + $UtilsCTSStrings.ID_Seconds
				}
				else {
					$AgeDisplay += ' Seconds'
				}
			}
			else {
				if ($Localized.IsPresent) {
					$AgeDisplay += ' ' + $UtilsCTSStrings.ID_Second
				}
				else {
					$AgeDisplay += ' Second'
				}
			}
		}
		if (($Age.TotalSeconds -lt 1)) {
			if ($AgeDisplay.Length -gt 0) { $AgeDisplay += ' ' }
			$AgeDisplay += $Age.TotalSeconds.ToString()
			if ($Localized.IsPresent) {
				$AgeDisplay += ' ' + $UtilsCTSStrings.ID_Seconds
			}
			else {
				$AgeDisplay += ' Seconds'
			}
		}
	}
	return $AgeDisplay
	EndFunc $MyInvocation.MyCommand.Name
}

filter FormatBytes {
	param ($bytes, $precision = '0')
	EnterFunc $MyInvocation.MyCommand.Name
	trap [Exception] {
		LogException "ScriptErrorText [FormatBytes] - Bytes: $bytes / Precision: $precision -InvokeInfo $MyInvocation" $_
		continue
	}

	if ($null -eq $bytes) {
		$bytes = $_
	}

	if ($null -ne $bytes) {
		$bytes = [double] $bytes
		foreach ($i in ('Bytes', 'KB', 'MB', 'GB', 'TB')) {
			if (($bytes -lt 1000) -or ($i -eq 'TB')) {
				$bytes = ($bytes).tostring('F0' + "$precision")
				return $bytes + " $i"
			}
			else {
				$bytes /= 1KB
			}
		}
	}
	EndFunc $MyInvocation.MyCommand.Name
}

function Get-CimOutput {
	param (
		[Parameter(Mandatory = $true)]
		[string]$Namespace,
		[Parameter(Mandatory = $false)]
		[string]$ClassName,
		[Parameter(Mandatory = $false)]
		[string]$Query,
		[Parameter(Mandatory = $false)]
		[string]$DisplayName,
		[Parameter(Mandatory = $false)]
		[switch]$FormatList,
		[Parameter(Mandatory = $false)]
		[switch]$FormatTable
	)

	if ($DisplayName) {
		$DisplayText = $DisplayName
	}
	else {
		$DisplayText = $ClassName
	}

	$results = "`r`n=================================`r`n"
	$results += " $DisplayText `r`n"
	$results += "=================================`r`n`r`n"

	if ($ClassName) {
		$Temp = Get-CimData -Namespace $Namespace -ClassName $ClassName
	}

	if ($Query) {
		$Temp = Get-CimData -Namespace $Namespace -Query $Query
	}

	if ($Temp) {
		if ($FormatList) {
			$results += ($Temp | Format-List | Out-String -Width 500).Trim()
		}

		if ($FormatTable) {
			$results += ($Temp | Format-Table -AutoSize | Out-String -Width 500).Trim()
		}

		$results += "`r`n"
	}
	else {
		$results += "    No Instances.`r`n"
	}

	return $results
}

function Get-CimData {
	param (
		[Parameter(Mandatory = $true)]
		[string]$Namespace,
		[Parameter(Mandatory = $false)]
		[string]$ClassName,
		[Parameter(Mandatory = $false)]
		[string]$Query
	)

	if ($ClassName) {
		$Temp = Get-CimInstance -Namespace $Namespace -Class $ClassName -ErrorVariable WMIError -ErrorAction SilentlyContinue
	}

	if ($Query) {
		$Temp = Get-CimInstance -Namespace $Namespace -Query $Query -ErrorVariable WMIError -ErrorAction SilentlyContinue
	}

	if ($WMIError.Count -ne 0) {
		if ($WMIError[0].Exception.Message -eq '') {
			$results = $WMIError[0].Exception.ToString()
		}
		else {
			$results = $WMIError[0].Exception.Message
		}
		$WMIError.Clear()
		return $results
	}

	if (($Temp | Measure-Object).Count -gt 0) {
		$results = $Temp | Select-Object * -ExcludeProperty __GENUS, __CLASS, __SUPERCLASS, __DYNASTY, __RELPATH, __PROPERTY_COUNT, __DERIVATION, __SERVER, __NAMESPACE, __PATH, PSComputerName, Scope, Path, Options, ClassPath, Properties, SystemProperties, Qualifiers, Site, Container
	}
	else {
		$results = $null
	}
	return $results
}

function Get-TimeZone {
	param ($tzi)

	# we just need the first element
	# local time = UTC - bias, where bias is represented in minutes
	# https://docs.microsoft.com/en-us/windows/win32/api/timezoneapi/ns-timezoneapi-time_zone_information

	try {
		$bias = [int32]"0x$($tzi.split(' ')[0])"

		if ($bias -eq 0) { 'UTC' }
		elseif ($bias -lt 0) { return "UTC +$([Math]::Abs($bias)) minutes" }
		else { return "UTC -$bias minutes" }
	}
	catch { return 'n/a' }
}

function Export-SiteInfo {
	param (
		[Parameter(Mandatory = $true)]
		$obj,
		[Parameter(Mandatory = $false)]
		$t = $tab,
		[Parameter(Mandatory = $false)]
		[switch]$isSec,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[String]$ExportFile
	)

	if ($isSec) {
		$siteType = 'Secondary'
		$t += "`t"
	}

	"$t$($obj.siteCode) | $siteType | $($obj.Version) | Install Directory: $($obj.InstallDir)" | Out-File $ExportFile -Append
	"$($t)Site Server: $($obj.ServerName) | Time Zone: $(Get-TimeZone $obj.TimeZoneInfo)" | Out-File $ExportFile -Append
}

function Get-BoundariesNotInAnyGroups () {
	param (
		$SMSProvServer,
		$SMSProvNamespace
	)

	process {
		$BoundaryNotInGroups = @()
		Get-CimInstance -Query 'SELECT * FROM SMS_Boundary WHERE GroupCount = 0' -ComputerName $SMSProvServer -Namespace $SMSProvNamespace | `
			ForEach-Object {
			$BoundaryType = switch ($_.BoundaryType) {
				0 { 'IP Subnet' }
				1 { 'AD Site' }
				2 { 'IPv6 Prefix' }
				3 { 'IP Range' }
				default { 'Unknown' }
			}

			$Boundary = @{'BoundaryID' = $_.BoundaryID
				'BoundaryType'            = $BoundaryType
				'DisplayName'             = $_.DisplayName
				'Value'                   = $_.Value
				'SiteSystems'             = $_.SiteSystems
			}

			$BoundaryObject = New-Object PSObject -Property $Boundary
			$BoundaryNotInGroups += $BoundaryObject
		}

		# $BoundaryNotInGroups | Select BoundaryID, BoundaryType, DisplayName, Value, SiteSystems | Sort BoundaryType | Format-Table -AutoSize
		return $BoundaryNotInGroups
	}
}

function Get-Boundaries () {
	param (
		$SMSProvServer,
		$SMSProvNamespace
	)

	process {
		# Boundary Groups
		$BoundaryResults = "#######################`r`n"
		$BoundaryResults += "# All Boundary Groups #`r`n"
		$BoundaryResults += "#######################`r`n"
		$BoundaryGroups = Get-CimInstance -Query 'SELECT * FROM SMS_BoundaryGroup LEFT JOIN SMS_BoundaryGroupSiteSystems ON SMS_BoundaryGroupSiteSystems.GroupId = SMS_BoundaryGroup.GroupId' -ComputerName $SMSProvServer -Namespace $SMSProvNamespace -ErrorAction SilentlyContinue -ErrorVariable WMIError
		if ($WMIError.Count -eq 0) {
			if ($null -ne $BoundaryGroups) {
				$BoundaryGroups = Get-BoundaryGroupsFromWmiResults -BoundaryGroupsFromWmi $BoundaryGroups
				$BoundaryResults += $BoundaryGroups | Sort-Object GroupID | Format-Table -AutoSize | Out-String -Width 2048
			}
			else {
				$BoundaryResults += "    None.`r`n`r`n"
			}
		}
		else {
			$BoundaryResults += "    ERROR: $($WMIError[0].Exception.Message)`r`n`r`n"
			$WMIError.Clear()
		}

		# Boundaries with multiple Sites for Assignment
		$BoundaryResults += "###################################################`r`n"
		$BoundaryResults += "# Boundaries set for Assignment to multiple Sites #`r`n"
		$BoundaryResults += "###################################################`r`n"
		$BoundariesWithAssignments = Get-CimInstance -Query 'SELECT * FROM SMS_Boundary WHERE GroupCount > 0' -ComputerName $SMSProvServer -Namespace $SMSProvNamespace -ErrorAction SilentlyContinue -ErrorVariable WMIError
		if ($WMIError.Count -eq 0) {
			if ($null -ne $BoundariesWithAssignments) {
				$BoundaryMultipleAssignments = $BoundariesWithAssignments | ForEach-Object { $asc = $_.DefaultSiteCode | Where-Object { $_ }; if ($asc.Count -gt 1) { $_ } }
				if ($null -ne $BoundaryMultipleAssignments) {
					$BoundaryMultipleAssignments = Get-BoundariesFromWmiResults -BoundariesFromWmi $BoundaryMultipleAssignments
					$BoundaryResults += $BoundaryMultipleAssignments
				}
				else {
					$BoundaryResults += "`r`n    None.`r`n`r`n"
				}
			}
			else {
				$BoundaryResults += "`r`n    None.`r`n`r`n"
			}
		}
		else {
			$BoundaryResults += "    ERROR: $($WMIError[0].Exception.Message)`r`n`r`n"
			$WMIError.Clear()
		}

		# Boundaries not in any groups
		$BoundaryResults += "#########################################`r`n"
		$BoundaryResults += "# Boundaries not in any Boundary Groups #`r`n"
		$BoundaryResults += "#########################################`r`n"
		$BoundaryNotInGroups = Get-CimInstance -Query 'SELECT * FROM SMS_Boundary WHERE GroupCount = 0' -ComputerName $SMSProvServer -Namespace $SMSProvNamespace -ErrorAction SilentlyContinue -ErrorVariable WMIError
		if ($WMIError.Count -eq 0) {
			if ($null -ne $BoundaryNotInGroups) {
				$BoundaryNotInGroups = Get-BoundariesFromWmiResults -BoundariesFromWmi $BoundaryNotInGroups
				$BoundaryResults += $BoundaryNotInGroups
			}
			else {
				$BoundaryResults += "`r`n    None.`r`n`r`n"
			}
		}
		else {
			$BoundaryResults += "`r`n    ERROR: $($WMIError[0].Exception.Message)`r`n`r`n"
			$WMIError.Clear()
		}

		# Members for each Boundary Group
		$BoundaryResults += "#############################`r`n"
		$BoundaryResults += "# Boundary Group Membership #`r`n"
		$BoundaryResults += "#############################`r`n`r`n"
		$Members = Get-CimInstance -Query 'SELECT * FROM SMS_Boundary JOIN SMS_BoundaryGroupMembers ON SMS_BoundaryGroupMembers.BoundaryID = SMS_Boundary.BoundaryID' -ComputerName $SMSProvServer -Namespace $SMSProvNamespace -ErrorAction SilentlyContinue -ErrorVariable WMIError
		if ($WMIError.Count -eq 0) {
			if ($null -ne $Members) {
				#foreach ($Member in $($Members.SMS_BoundaryGroupMembers | Select GroupID -Unique)) { # Works with PowerShell 3.0
				foreach ($Member in $($Members | Select-Object -ExpandProperty SMS_BoundaryGroupMembers | Select-Object GroupID -Unique)) {
					# Works with PowerShell 2.0
					$BoundaryResults += "Boundary Members for Boundary Group ID: $($Member.GroupId)`r`n"
					$BoundaryResults += "===================================================`r`n"
					$MembersWmi = $Members | Where-Object { $_.SMS_BoundaryGroupMembers.GroupID -eq $Member.GroupId } | Select-Object -ExpandProperty SMS_Boundary
					$MemberBoundary = Get-BoundariesFromWmiResults -BoundariesFromWmi $MembersWmi
					$BoundaryResults += $MemberBoundary
				}
			}
			else {
				$BoundaryResults += "    Boundary Groups have no members.`r`n`r`n"
			}
		}
		else {
			$BoundaryResults += "    ERROR: $($WMIError[0].Exception.Message)`r`n`r`n"
			$WMIError.Clear()
		}

		return $BoundaryResults
	}
}

function Get-BoundaryGroupsFromWmiResults () {
	param (
		$BoundaryGroupsFromWmi
	)

	$BoundaryGroups = @()

	foreach ($Group in ($BoundaryGroupsFromWmi | Select-Object -ExpandProperty SMS_BoundaryGroup | Select-Object GroupId -Unique)) {
		$BoundaryGroupWmi = $BoundaryGroupsFromWmi | Select-Object -ExpandProperty SMS_BoundaryGroup | Where-Object { $_.GroupId -eq $Group.GroupId } | Select-Object -Unique
		$SiteSystems = ''
		$SiteSystems = $BoundaryGroupsFromWmi | Select-Object -ExpandProperty SMS_BoundaryGroupSiteSystems | Where-Object { $_.GroupId -eq $Group.GroupId } | Select-Object -ExpandProperty ServerNalPath `
		| ForEach-Object { $SiteSystem = $_; $SiteSystem.Split('\\')[2] }
		$BoundaryGroup = @{
			'GroupID'            = $BoundaryGroupWmi.GroupID
			'Name'               = $BoundaryGroupWmi.Name
			'AssignmentSiteCode' = $BoundaryGroupWmi.DefaultSiteCode
			'Shared'             = $BoundaryGroupWmi.Shared
			'MemberCount'        = $BoundaryGroupWmi.MemberCount
			'SiteSystemCount'    = $BoundaryGroupWmi.SiteSystemCount
			'SiteSystems'        = $SiteSystems -join '; '
			'Description'        = $BoundaryGroupWmi.Description
		}

		$BoundaryGroupObject = New-Object PSObject -Property $BoundaryGroup
		$BoundaryGroups += $BoundaryGroupObject
	}

	return ($BoundaryGroups | Select-Object GroupID, Name, AssignmentSiteCode, Shared, MemberCount, SiteSystemCount, SiteSystems, Description)
}

function Get-BoundariesFromWmiResults () {
	param (
		$BoundariesFromWmi
	)

	$Boundaries = @()

	foreach ($BoundaryWmi in $BoundariesFromWmi) {
		$BoundaryType = switch ($BoundaryWmi.BoundaryType) {
			0 { 'IP Subnet' }
			1 { 'AD Site' }
			2 { 'IPv6 Prefix' }
			3 { 'IP Range' }
			default { 'Unknown' }
		}

		if (($BoundaryWmi.DefaultSiteCode | Where-Object { $_ }).Count -gt 1) {
			$AssignmentSiteCode = $BoundaryWmi.DefaultSiteCode -join '; '
		}
		else {
			$AssignmentSiteCode = $BoundaryWmi.DefaultSiteCode -join ''
		}

		$Boundary = @{
			'BoundaryID'         = $BoundaryWmi.BoundaryID
			'DisplayName'        = $BoundaryWmi.DisplayName
			'BoundaryType'       = $BoundaryType
			'Value'              = $BoundaryWmi.Value
			'AssignmentSiteCode' = $AssignmentSiteCode
			'SiteSystems'        = $BoundaryWmi.SiteSystems -join '; '
		}

		$BoundaryObject = New-Object PSObject -Property $Boundary
		$Boundaries += $BoundaryObject
	}

	return ($Boundaries | Select-Object BoundaryID, DisplayName, BoundaryType, Value, AssignmentSiteCode, SiteSystems | Sort-Object BoundaryID | Format-Table -AutoSize | Out-String -Width 2048)
}

function Get-WmiOutput {
	param (
		[Parameter(Mandatory = $false)]
		[string]$ClassName,
		[Parameter(Mandatory = $false)]
		[string]$Query,
		[Parameter(Mandatory = $false)]
		[string]$DisplayName,
		[Parameter(Mandatory = $false)]
		[switch]$FormatList,
		[Parameter(Mandatory = $false)]
		[switch]$FormatTable
	)

	if ($DisplayName) {
		$DisplayText = $DisplayName
	}
	else {
		$DisplayText = $ClassName
	}

	$results = "`r`n=================================`r`n"
	$results += " $DisplayText `r`n"
	$results += "=================================`r`n`r`n"

	if ($ClassName) {
		$Temp = Get-WmiData -ClassName $ClassName
	}

	if ($Query) {
		$Temp = Get-WmiData -Query $Query
	}

	if ($Temp) {
		if ($FormatList) {
			$results += ($Temp | Format-List | Out-String).Trim()
		}

		if ($FormatTable) {
			$results += ($Temp | Format-Table | Out-String -Width 500).Trim()
		}

		$results += "`r`n"
	}
	else {
		$results += "    No Instances.`r`n"
	}

	return $results
}

function Get-WmiData {
	param (
		[Parameter(Mandatory = $false)]
		[string]$ClassName,
		[Parameter(Mandatory = $false)]
		[string]$Query
	)

	if ($ClassName) {
		$Temp = Get-CimInstance -ComputerName $SMSProviderServer -Namespace $SMSProviderNamespace -Class $ClassName -ErrorVariable WMIError -ErrorAction SilentlyContinue
	}

	if ($Query) {
		$Temp = Get-CimInstance -ComputerName $SMSProviderServer -Namespace $SMSProviderNamespace -Query $Query -ErrorVariable WMIError -ErrorAction SilentlyContinue
	}

	if ($WMIError.Count -ne 0) {
		if ($WMIError[0].Exception.Message -eq '') {
			$results = $WMIError[0].Exception.ToString()
		}
		else {
			$results = $WMIError[0].Exception.Message
		}
		$WMIError.Clear()
		return $results
	}

	if (($Temp | Measure-Object).Count -gt 0) {
		$results = $Temp | Select-Object * -ExcludeProperty __GENUS, __CLASS, __SUPERCLASS, __DYNASTY, __RELPATH, __PROPERTY_COUNT, __DERIVATION, __SERVER, __NAMESPACE, __PATH, PSComputerName, Scope, Path, Options, ClassPath, Properties, SystemProperties, Qualifiers, Site, Container
	}
	else {
		$results = $null
	}

	return $results
}

#region --- SQL helper functions ---

# Taken from DC_CollectSQL.ps1 from OpsMgr
# ===============================================================
function WriteConnectionEvents($currentEventID) {
	Get-Event | ForEach-Object {
		if ($_.SourceIdentifier -eq $currentEventID) {
			$CurrentEventIdentifier = $_.EventIdentifier
			$info = $_.SourceEventArgs
			Remove-Event -EventIdentifier $CurrentEventIdentifier
			$info.Message
		}
	}
}

function Run-SQLCommandtoFile {
	param (
		$SqlQuery,
		$outFile,
		$DisplayText,
		$collectFiles = $false,
		$fileDescription = '',
		$ZipFile = '',
		$OutputWidth = 1024,
		[switch]$HideSqlQuery,
		[switch]$NoSecondary
	)
	process {
		# Reset DisplayText to SqlQuery if it's not provided
		if ($null -eq $DisplayText) {
			$DisplayText = $SqlQuery
		}

		# Skip secondary site
		if ($NoSecondary -and ($SiteType -eq 2)) {
			AddTo-CMDatabaseSummary -NoToSummaryReport -NoToSummaryFile -Name $DisplayText -Value 'Not available on a Secondary Site'
			return
		}

		# Standardize text added to summary file "Review $outFileName"
		if ($ZipFile -eq '') {
			$outFileName = $outFile
		}
		else {
			$outFileName = $ZipFile + $outFile.Substring($outFile.LastIndexOf('\'))
		}

		# Hide SQL Query from output if specified
		if ($HideSqlQuery) {
			'=' * ($DisplayText.Length + 4) + "`r`n-- " + $DisplayText + "`r`n" + '=' * ($DisplayText.Length + 4) + "`r`n" | Out-File -FilePath $outFile -Append
			LogInfo "Current Query = $DisplayText"
		}
		else {
			'=' * ($SqlQuery.Length + 2) + "`r`n-- " + $DisplayText + "`r`n" + $SqlQuery + "`r`n" + '=' * ($SqlQuery.Length + 2) + "`r`n" | Out-File -FilePath $outFile -Append
			LogInfo "Current Query = $SqlQuery"
		}

		LogInfo "$DisplayText"

		$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
		$SqlCmd.CommandText = $SqlQuery
		$SqlCmd.Connection = $global:DatabaseConnection

		$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
		$SqlAdapter.SelectCommand = $SqlCmd

		$SqlTable = New-Object System.Data.DataTable
		try {
			$SqlAdapter.Fill($SqlTable) | Out-Null

			$results = ($SqlTable | Select-Object * -ExcludeProperty RowError, RowState, HasErrors, Table, ItemArray | Format-Table -AutoSize -Wrap -Property * `
				| Out-String -Width $OutputWidth).Trim()
			$results += "`r`n`r`n"
			$results | Out-File -FilePath $outFile -Append

			AddTo-CMDatabaseSummary -NoToSummaryReport -NoToSummaryFile -Name $DisplayText -Value "Review $outFileName"

			if ($collectFiles -eq $true) {
				CollectFiles -filesToCollect $outFile -fileDescription $fileDescription -sectionDescription $sectiondescription -noFileExtensionsOnDescription
			}
		}
		catch [Exception] {
			AddTo-CMDatabaseSummary -NoToSummaryReport -NoToSummaryFile -Name $DisplayText -Value "ERROR: $_"
		}
	}
}

function Run-SQLCommandtoFileWithInfo {
	param (
		$SqlQuery,
		$outFile,
		$DisplayText,
		$collectFiles = $false,
		$ZipFile = '',
		[switch]$HideSqlQuery,
		[switch]$SkipEvents
	)
	process {
		# Reset DisplayText to SqlQuery if it's not provided
		if ($null -eq $DisplayText) {
			$DisplayText = $SqlQuery
		}

		# Standardize text added to summary file "Review $outFileName"
		if ($ZipFile -eq '') {
			$outFileName = $outFile
		}
		else {
			$outFileName = $ZipFile + $outFile.Substring($outFile.LastIndexOf('\'))
		}

		# Hide SQL Query from output if specified
		if ($HideSqlQuery) {
			'=' * ($DisplayText.Length + 4) + "`r`n-- " + $DisplayText + "`r`n" + '=' * ($DisplayText.Length + 4) + "`r`n" | Out-File -FilePath $outFile -Append
			LogInfo "Current Query = $DisplayText"
		}
		else {
			'=' * ($SqlQuery.Length + 2) + "`r`n-- " + $DisplayText + "`r`n" + $SqlQuery + "`r`n" + '=' * ($SqlQuery.Length + 2) + "`r`n" | Out-File -FilePath $outFile -Append
			LogInfo "Current Query = $SqlQuery"
		}

		LogInfo "$DisplayText"

		if (-not $SkipEvents) {
			$eventID = $outFile
			Register-ObjectEvent -InputObject $global:DatabaseConnection -EventName InfoMessage -SourceIdentifier $eventID
		}

		$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
		$SqlCmd.Connection = $global:DatabaseConnection
		$SqlCmd.CommandText = $SqlQuery
		$SqlCmd.CommandTimeout = 0

		$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
		$SqlAdapter.SelectCommand = $SqlCmd

		$DataSet = New-Object System.Data.DataSet

		try {
			$SqlAdapter.Fill($DataSet)

			if ($DataSet.Tables.Count -gt 0) {
				foreach ($table in $DataSet.Tables) {
					$table | Format-Table -AutoSize | Out-String -Width 2048 | Out-File -FilePath $outFile -Append
				}
			}

			if (-not $SkipEvents) {
				if (($RemoteStatus -eq 0) -or ($RemoteStatus -eq 1)) {
					WriteConnectionEvents $eventID | Out-String -Width 2048 | Out-File -FilePath $outFile -Append
				}
				Else {
					'Message Information Events cannot be obtained Remotely. Run Diagnostics locally on a Primary or Central Site to obtain this data.' | Out-File -FilePath $outFile -Append
				}
			}

			if ($collectFiles -eq $true) {
				CollectFiles -filesToCollect $outFile -fileDescription "$DisplayText" -sectionDescription $sectionDescription -noFileExtensionsOnDescription
			}

			AddTo-CMDatabaseSummary -NoToSummaryReport -NoToSummaryFile -Name $DisplayText -Value "Review $outFileName"
		}
		catch [Exception] {
			AddTo-CMDatabaseSummary -NoToSummaryReport -NoToSummaryFile -Name $DisplayText -Value "ERROR: $_"
		}
	}
}

function Get-SQLValue {
	param (
		[string]$SqlQuery,
		[string]$ColumnName,
		[string]$DisplayText
	)

	LogInfo "$DisplayText"

	$Result = New-Object -TypeName PSObject

	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $SqlQuery
	$SqlCmd.Connection = $global:DatabaseConnection

	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd

	LogInfo "Current Query = $SqlQuery"
	$SqlTable = New-Object System.Data.DataTable
	try {
		$SqlAdapter.Fill($SqlTable) | Out-Null
		$ActualValue = $SqlTable | Select-Object -ExpandProperty $ColumnName -ErrorAction SilentlyContinue
		$Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value $ActualValue
		$Result | Add-Member -MemberType NoteProperty -Name 'Error' -Value $null
	}
	catch [Exception] {
		$Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value $null
		$Result | Add-Member -MemberType NoteProperty -Name 'Error' -Value $_
	}

	# Return column value
	return $Result
}

function Get-SQLValueWithError {
	param (
		[string]$SqlQuery,
		[string]$ColumnName,
		[string]$DisplayText
	)

	$ResultValue = Get-SQLValue -SqlQuery $SqlQuery -ColumnName $ColumnName -DisplayText $DisplayText
	if ($null -eq $ResultValue.Error) {
		return $ResultValue.Value
	}
	else {
		return $ResultValue.Error
	}
}

function Format-XML ([xml]$xml, $indent = 2) {
	$StringWriter = New-Object System.IO.StringWriter
	$XmlWriter = New-Object System.XMl.XmlTextWriter $StringWriter
	$xmlWriter.Formatting = 'indented'
	$xmlWriter.Indentation = $Indent
	$xml.WriteContentTo($XmlWriter)
	$XmlWriter.Flush()
	$StringWriter.Flush()
	return $StringWriter.ToString()
}

#function RunSQLCommandtoCSVfunction
#{
#    param (
#		$cmd,
#		$outfile
#		)
#	process
#	{
#		$out = $ComputerName + "_SQL_" + $outfile + ".csv"

#		Write-DiagProgress -Activity $ScriptStrings.ID_SCCM_ACTIVITY_CM12SQL -Status $cmd
#		$da = new-object System.Data.SqlClient.SqlDataAdapter ($cmd, $connnectionstring)
#		$dt = new-object System.Data.DataTable
#		$da.fill($dt) | out-null

#		$dt | Export-CSV -Path $out
#		CollectFiles -filesToCollect $out -fileDescription "$cmd" -sectionDescription $sectiondescription

#	}
#}

function Check-SQLValue {
	param (
		[string]$Query,
		[string]$ColumnName,
		[string]$CompareOperator = 'eq',
		$DesiredValue,
		[string]$RootCauseName,
		[string]$ColumnDisplayName = $ColumnName
	)

	# InformationCollected for Update-DiagRootcause
	Set-Variable -Name InformationCollected -Scope Local
	$InformationCollected = New-Object PSObject

	# InfoSummary for $ComplianceSummary
	Set-Variable -Name InfoSummary -Scope Script
	$InfoSummary = New-Object PSObject
	#$InfoSummary = @()
	Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Name' -Value $ColumnDisplayName
	$Result = Get-SQLValue -SqlQuery $Query -ColumnName $ColumnName -ColumnDisplayName $ColumnDisplayName
	if ($null -ne $Result.Error) {
		LogInfo "Value of $ColumnName is Unknown. SQL Query Failed with ERROR: $($Result.Error)"
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Actual Value' -Value 'Unknown'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Desired Value' -Value $DesiredValue
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'N/A'
		$script:ComplianceSummary += $InfoSummary
		return
	}

	$ActualValue = $Result.Value

	if ($null -ne $ActualValue) {
		# TODO: Replace this with [string]::IsNullOrEmpty() ???
		Add-Member -InputObject $InformationCollected -MemberType NoteProperty -Name $ColumnDisplayName -Value "$ActualValue. Desired Value: $DesiredValue"
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Actual Value' -Value $ActualValue
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Desired Value' -Value $DesiredValue

		# Check whether Actual Value of specified column is equal to the Desired Value
		if ($CompareOperator -eq 'eq') {
			if ($ActualValue -eq $DesiredValue) {
				LogInfo "$ColumnName = $ActualValue. Compliant." 'DarkGreen'
				Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'Compliant'
			}
			else {
				LogInfo "$ColumnName = $ActualValue. Desired Value = $DesiredValue. Not Compliant!" 'DarkRed'
				Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'Not-Compliant'
				Update-DiagRootCause -id $RootCauseName -Detected $true
				Add-GenericMessage -Id $RootCauseName -InformationCollected $InformationCollected
			}
		}

		# Check whether Actual Value of specified column is greater than the Desired Value. Used to check counts of rows in specific tables.
		if ($CompareOperator -eq 'gt') {
			if ($ActualValue -gt $DesiredValue) {
				LogInfo "$ColumnName is $ActualValue which is greater than the Desired Value $DesiredValue. Not Compliant!" 'DarkRed'
				Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'Not-Compliant'
				Update-DiagRootCause -id $RootCauseName -Detected $true
				Add-GenericMessage -Id $RootCauseName -InformationCollected $InformationCollected
			}
			else {
				LogInfo "$ColumnName is $ActualValue which is less than the Desired Value $DesiredValue. Compliant." 'DarkGreen'
				Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'Compliant'
			}
		}
	}
	else {
		# Actual Value was null
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Actual Value' -Value $null
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Desired Value' -Value $DesiredValue
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'N/A'
		LogInfo "SQL Query succeeded but the value of $ColumnName is Null."
	}

	# Add InfoSummary to ComplianceSummary array
	$script:ComplianceSummary += $InfoSummary
}

function Get-SQLValue {
	param (
		[string]$SqlQuery,
		[string]$ColumnName,
		[string]$ColumnDisplayName
	)

	LogInfo "Checking the Value of: $ColumnDisplayName"

	$Result = New-Object -TypeName PSObject

	$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
	$SqlCmd.CommandText = $SqlQuery
	$SqlCmd.Connection = $global:DatabaseConnection

	$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
	$SqlAdapter.SelectCommand = $SqlCmd

	LogInfo "Getting the value of $ColumnDisplayName"
	$SqlTable = New-Object System.Data.DataTable
	try {
		$SqlAdapter.Fill($SqlTable) | Out-Null
		$ActualValue = $SqlTable | Select-Object -ExpandProperty $ColumnName -ErrorAction SilentlyContinue
		$Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value $ActualValue
		$Result | Add-Member -MemberType NoteProperty -Name 'Error' -Value $null
	}
 catch [Exception] {
		$Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value $null
		$Result | Add-Member -MemberType NoteProperty -Name 'Error' -Value $_
	}

	# Return column value
	return $Result
}

function Parse-DRSBacklogResult {
	param ($DRSBacklogResult)

	$RootCauseName = 'RC_DRSBacklog'

	# InformationCollected for Update-DiagRootcause
	Set-Variable -Name InformationCollected -Scope Local
	$InformationCollected = New-Object PSObject

	# InfoSummary for $ComplianceSummary
	Set-Variable -Name InfoSummary -Scope Script
	$InfoSummary = New-Object PSObject
	#$InfoSummary = @()
	Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Name' -Value 'Change Tracking Backlog'

	if ($null -ne $DRSBacklogResult.Error) {
		LogInfo "ChangeTrackingBacklog Result is Unknown. SQL Query Failed with ERROR: $($DRSBacklogResult.Error)"
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Actual Value' -Value 'Unknown'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Desired Value' -Value 'Less Than RetentionPeriod + 5 days'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'Unknown'
		$script:ComplianceSummary += $InfoSummary
		return
	}

	if ($null -eq $DRSBacklogResult.Value) {
		LogInfo 'ChangeTrackingBacklog Result is Unknown. Value returns was null!'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Actual Value' -Value 'Unknown'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Desired Value' -Value 'Less Than RetentionPeriod + 5 days'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'Unknown'
		$script:ComplianceSummary += $InfoSummary
		return
	}

	$ActualValue = $DRSBacklogResult.Value

	if ($ActualValue -eq 0) {
		LogInfo 'ChangeTrackingBacklog Result value is 0. Not Applicable!'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'Not Applicable'
		$script:ComplianceSummary += $InfoSummary
		return
	}

	if ($ActualValue -eq -1) {
		LogInfo 'ChangeTrackingBacklog result = -1. This means we did not find the row for ConfigMgr database in sys.change_tracking_databases'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'N/A. Did not find the row for ConfigMgr database in sys.change_tracking_databases'
		$DRSBacklogDescription = 'Change Tracking Backlog detection was aborted, because there was no row found for the ConfigMgr database in the sys.change_tracking_databases table, and this should be investigated.'
		Update-DiagRootCause -id $RootCauseName -Detected $true	-Parameter @{'DRSBacklogDescription' = $DRSBacklogDescription }
		Add-GenericMessage -Id $RootCauseName -InformationCollected $InformationCollected
		$script:ComplianceSummary += $InfoSummary
		return
	}

	if ($ActualValue -eq -2) {
		LogInfo 'ChangeTrackingBacklog result = -2. This means retention unit is not set to DAYS. ConfigMgr UI does not allow changing the retention unit.'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'N/A. Retention Unit in sys.change_tracking_databases is not set to DAYS. ConfigMgr UI does not allow changing the retention unit.'
		$DRSBacklogDescription = 'Change Tracking Backlog detection was aborted, because retention unit in sys.change_tracking_databases table is not set to DAYS. ConfigMgr console does not allow changing the retention unit. Please ensure that retention unit is set to DAYS in SQL.'
		Update-DiagRootCause -id $RootCauseName -Detected $true	-Parameter @{'DRSBacklogDescription' = $DRSBacklogDescription }
		Add-GenericMessage -Id $RootCauseName -InformationCollected $InformationCollected
		$script:ComplianceSummary += $InfoSummary
		return
	}

	if ($ActualValue -eq -3) {
		LogInfo 'ChangeTrackingBacklog result = -3. This means period is greater than 14 days. ConfigMgr UI only allows setting retention period between 1 and 14.'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'N/A. Retention Period in sys.change_tracking_databases is greater than 14 days. ConfigMgr UI only allows setting retention period between 1 and 14.'
		$DRSBacklogDescription = 'Change Tracking Backlog detection was aborted, because Retention Period in sys.change_tracking_databases is greater than 14 days. ConfigMgr console only allows setting retention period between 1 and 14. Please set the retention period to a supported value from the ConfigMgr console.'
		Update-DiagRootCause -id $RootCauseName -Detected $true	-Parameter @{'DRSBacklogDescription' = $DRSBacklogDescription }
		Add-GenericMessage -Id $RootCauseName -InformationCollected $InformationCollected
		$script:ComplianceSummary += $InfoSummary
		return
	}

	if (-not $ActualValue.Contains('.')) {
		LogInfo "ChangeTrackingBacklog result = $ActualValue. This value is unexpected."
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'Unknown!'
		$script:ComplianceSummary += $InfoSummary
	}

	$BacklogDays = $ActualValue.Substring(0, $ActualValue.IndexOf('.'))
	$RetentionPeriod = $ActualValue.Substring($ActualValue.IndexOf('.') + 1)

	Add-Member -InputObject $InformationCollected -MemberType NoteProperty -Name 'Change Tracking Backlog Result' -Value "Backlog Days = $BacklogDays, Retention Period = $RetentionPeriod. Desired Value: Less than Retention Period + 5 days"
	Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Actual Value' -Value "Backlog Days = $BacklogDays, Retention Period = $RetentionPeriod"
	Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Desired Value' -Value 'Less Than RetentionPeriod + 5 days'

	# We are here, which means result value is in format x.x and issue was detected - Major means Backlog Days, Minor means Retention Period
	if ([int]$BacklogDays -gt [int]$RetentionPeriod + 5) {
		LogInfo "ChangeTrackingBacklog result = $ActualValue. This means we detected a backlog of $BacklogDays days with current retention period of $RetentionPeriod days. Not Compliant!" 'DarkRed'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'Not-Compliant!'
		$DRSBacklogDescription = "Change Tracking Backlog of $BacklogDays days was detected, which is greater than $([int]$RetentionPeriod + 5) days (Current Retention Period ($RetentionPeriod) + 5 days)."
		Update-DiagRootCause -id $RootCauseName -Detected $true	-Parameter @{'DRSBacklogDescription' = $DRSBacklogDescription }
		Add-GenericMessage -Id $RootCauseName -InformationCollected $InformationCollected
		$script:ComplianceSummary += $InfoSummary
	}
	else {
		LogInfo "ChangeTrackingBacklog result = $ActualValue. This means we detected a backlog of $BacklogDays days with current retention period of $RetentionPeriod days. Compliant!" 'DarkGreen'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'Compliant'
		$script:ComplianceSummary += $InfoSummary
	}
}

function Parse-DBSchemaChangeHistoryResult {
	param ($DBSchemaChangeHistoryResult)

	$RootCauseName = 'RC_DBSchemaChangeHistory'

	# InformationCollected for Update-DiagRootcause
	Set-Variable -Name InformationCollected -Scope Local
	$InformationCollected = New-Object PSObject

	# InfoSummary for $ComplianceSummary
	Set-Variable -Name InfoSummary -Scope Script
	$InfoSummary = New-Object PSObject
	#$InfoSummary = @()
	Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Name' -Value 'DBSchemaChangeHistory Size'

	if ($null -ne $DBSchemaChangeHistoryResult.Error) {
		LogInfo "DBSchemaChangeHistorySize Result is Unknown. SQL Query Failed with ERROR: $($DRSBacklogResult.Error)"
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Actual Value' -Value 'Unknown'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Desired Value' -Value 'Less Than 5% of DB Size OR Less Than 10GB'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'N/A'
		$script:ComplianceSummary += $InfoSummary
		return
	}

	if ($null -eq $DBSchemaChangeHistoryResult.Value) {
		LogInfo 'DBSchemaChangeHistorySize Result is Unknown. Value returned was null!'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Actual Value' -Value 'Unknown'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Desired Value' -Value 'Less Than 5% of DB Size OR Less Than 10GB'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'Unknown'
		$script:ComplianceSummary += $InfoSummary
		return
	}

	$ActualValue = $DBSchemaChangeHistoryResult.Value

	if ($ActualValue -eq 0) {
		LogInfo "DBSchemaChangeHistorySize result = $ActualValue. Not Applicable!"
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'Not Applicable.'
		$script:ComplianceSummary += $InfoSummary
		return
	}

	if (-not $ActualValue.Contains('.')) {
		LogInfo "DBSchemaChangeHistory result = $ActualValue. This value is unexpected."
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'Unknown.'
		$script:ComplianceSummary += $InfoSummary
		return
	}

	$DBSize = $ActualValue.Substring(0, $ActualValue.IndexOf('.')) -as [int]
	$TableSize = $ActualValue.Substring($ActualValue.IndexOf('.') + 1) -as [int]

	Add-Member -InputObject $InformationCollected -MemberType NoteProperty -Name 'DBSchemaChangeHistorySize Result' -Value "Table Size = $($TableSize)MB, Database Size = $($DBSize)MB. Desired Value: Less Than 5% of DB Size OR Less Than 10GB"
	Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Actual Value' -Value "Table Size = $($TableSize)MB, Database Size = $($DBSize)MB"
	Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Desired Value' -Value 'Less Than 5% of DB Size OR Less Than 10GB'

	$percentage = ($TableSize / $DBSize) * 100

	if (($percentage -gt 5) -or ($TableSize -gt 10240)) {
		LogInfo "DBSchemaChangeHistorySize Result: Table Size = $($TableSize)MB, Database Size = $($DBSize)MB. Table size exceeds threshold. Not Compliant!" 'DarkRed'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'Not-Compliant!'
		$DBSchemaChangeHistoryDescription = "DBSChemaChangeHistory table size is greater than 5% of Database Size or 10GB. Table Size = $($TableSize)MB, Database Size = $($DBSize)MB"
		Update-DiagRootCause -id $RootCauseName -Detected $true	-Parameter @{'DBSchemaChangeHistoryDescription' = $DBSchemaChangeHistoryDescription }
		Add-GenericMessage -Id $RootCauseName -InformationCollected $InformationCollected
		$script:ComplianceSummary += $InfoSummary
	}
	else {
		LogInfo "DBSchemaChangeHistorySize result = $ActualValue. Compliant!" 'DarkGreen'
		Add-Member -InputObject $InfoSummary -MemberType NoteProperty -Name 'Result State' -Value 'Compliant'
		$script:ComplianceSummary += $InfoSummary
	}
}
# ===============================================================
#endregion --- SQL helper functions ---

# Helper function to find next available drive for IIS 7.0 Shared configuration file copy
function Get-NextFreeDrive {
	68..90 | ForEach-Object { "$([char]$_):" } | Where-Object { 'h:', 'k:', 'z:' -notcontains $_ } | Where-Object { (New-Object System.IO.DriveInfo $_).DriveType -eq 'noRootdirectory' }
}

function ParseSSLFlags {
	param (
		$sslFlag
	)
	process {
		$RetVal = ''
		if ($sslFlag -eq 0) { $RetVal = 'None' }
		if ($sslFlag -eq 8) { $RetVal = 'Require SSL - Ignore client certificates' }
		if ($sslFlag -eq 40) { $RetVal = 'Require SSL - Accept client certificates ' }
		if ($sslFlag -eq 104) { $RetVal = 'Require SSL - Require client certificates ' }
		if ($sslFlag -band 256) { $RetVal += ' - Require 128-bit SSL' }
		return $RetVal
	}
}

function Copy-Files {
	# Copy files with specified filter
	# Uses Recurse if specified. Filtering is done by -Filter switch which takes only a single parameter.
	param(
		$Source,
		$Destination,
		$Filter,
		[switch]$Recurse,
		[switch]$RenameFileToPath
	)
	process {
		LogInfo "Copying $Filter files from $Source to $Destination"

		if (Test-Path $Source) {
			if ($Recurse) {
				$Files = Get-ChildItem $Source -Recurse -Filter $Filter | Where-Object { -not ($_.FullName -like '*SDIAG_*') -and -not($_.FullName -like '*MATS-Temp*') }
			}
			else {
				$Files = Get-ChildItem $Source -Filter $Filter | Where-Object { -not ($_.FullName -like '*SDIAG_*') -and -not($_.FullName -like '*MATS-Temp*') }
			}
			$FileCount = ($Files | Measure-Object).Count
			if ($FileCount -eq 0) {
				LogInfo 'No files match the Include criteria.'
				return
			}
			LogInfo "Found $FileCount files matching specified criteria"
			$Files | `
				ForEach-Object {
				$FilePath = $_.FullName

				if ($RenameFileToPath) {
					$DestFileName = ($FilePath -replace '\\', '_' ) -replace ':', ''
				}
				else {
					$DestFileName = $_.Name
				}
				Copy-Item $FilePath (Join-Path $Destination $DestFileName) -ErrorAction SilentlyContinue -ErrorVariable CopyErr -Force
				if ($CopyErr.Count -ne 0) {
					LogInfo "ERROR occurred while copying $Source files: $($CopyErr.Exception)"
				}
				$CopyErr.Clear()
			}
		}
		else {
			LogInfo "$Source does not exist."
		}
	}
}

function Copy-FilesWithStructure {
	# Copy files with structure
	# Always uses Recurse and filtering is done by -Include switch which can take multiple parameters.
	param (
		$Source,
		$Destination,
		$Include
	)
	process {
		# This function uses -Include with Get-ChildItem so that multiple patterns can be specified
		if ($Source.EndsWith('\')) {
			$Source = $Source.Substring(0, $Source.Length - 1)
		}
		LogInfo "Copying $Include files from $Source to $Destination"
		if (Test-Path $Source) {
			try {
				$Files = Get-ChildItem $Source -Recurse -Include $Include | Where-Object { -not ($_.FullName -like '*SDIAG_*') -and -not($_.FullName -like '*MATS-Temp*') }
				$FileCount = ($Files | Measure-Object).Count
				if ($FileCount -eq 0) {
					LogInfo 'No files match the Include criteria.'
					return
				}
				LogInfo "Found $FileCount files matching specified criteria"
				$Files | ForEach-Object {
					$relativePath = $_.FullName.Substring($Source.Length)   # Get the relative path of the file
					$targetFolder = Join-Path $Destination $relativePath | Split-Path  # Get the target folder path
					if (-not (Test-Path $targetFolder)) {
						New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null  # Create the target folder if it doesn't exist
					}
					$targetFile = Join-Path $targetFolder $_.Name  # Get the target file path
					Copy-Item $_.FullName -Destination $targetFile -Force -ErrorAction SilentlyContinue -ErrorVariable CopyErr    # Copy and overwrite the file
					if ($CopyErr.Count -ne 0) {
						LogInfo "ERROR occurred while copying $($_.FullName): $($CopyErr.Exception)"
					}
					$CopyErr.Clear()
				}
			}
			catch [Exception] {
				LogException 'ERROR:' $_
			}
		}
		else {
			LogWarn "$Source does not exist."
		}
	}
}


function UtilsAddXMLElement {
	param(
		[string] $ElementName = 'Item',
		[string] $Value,
		[string] $AttributeName = 'Name',
		[string] $AttributeValue,
		[string] $xpath = '/Root',
		[xml] $XMLDoc)
	trap [Exception] {
		LogException "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)):" $_
	}
	[System.Xml.XmlElement] $rootElement = $xmlDoc.SelectNodes($xpath).Item(0)
	if ($null -ne $rootElement) {
		[System.Xml.XmlElement] $element = $xmlDoc.CreateElement($ElementName)
		if ($null -ne $attributeValue) { $element.SetAttribute($AttributeName, $attributeValue) }
		if ($null -ne $Value) {
			if ($Host.Version.Major -gt 1) {
				#PowerShell 2.0
				$element.innerXML = $Value
			}
			else {
				$element.set_InnerXml($Value)
			}
		}
		$x = $rootElement.AppendChild($element)
	}
	else {
		LogInfo "UtilsAddXMLElement: Error: Path $xpath returned a null value. Current XML document: `n $($xmlDoc.get_OuterXml())"
		LogInfo "               ElementName = $ElementName`n               Value: $Value`n               AttributeName: $AttributeName`n               AttributeValue: $AttributeValue"
	}
}


#TODO: What's happening with $InformationCollected? Where should we output our findings?
#TODO: Did not migrate functions 'Update-DiagRootCause' and 'Add-GenericMessage' from # WindowsCSSToolsDevRep\Dev\ALL\TSSv2\psSDP\Diag\global\utils_Remote.ps1
function Get-ServiceStatus ($ServiceName, $DesiredState = 'Running', $DesiredStartMode = 'Automatic', $RCDescription = '') {
	$RootCauseName = 'RC_ServiceStatus'
	$InformationCollected = New-Object PSObject
	$Service = Get-CimInstance Win32_Service | Where-Object { $_.Name -eq $ServiceName }
	if ($Service -is [CimInstance]) {
		LogInfo "Checking the status of: $($Service.DisplayName)"

		if ($Service.State -ne $DesiredState) {
			$InformationCollected | Add-Member -MemberType NoteProperty -Name 'Name' -Value ($Service.Name)
			$InformationCollected | Add-Member -MemberType NoteProperty -Name 'Start Mode' -Value ($Service.StartMode)
			$InformationCollected | Add-Member -MemberType NoteProperty -Name 'Current State' -Value ($Service.State)
			# WindowsCSSToolsDevRep\Dev\ALL\TSSv2\psSDP\Diag\global\utils_Remote.ps1
			#Update-DiagRootCause -id $RootCauseName -Detected $true -InstanceId $ServiceName -Parameter @{'ServiceName' = $Service.DisplayName; 'DesiredStartMode' = $DesiredStartMode; 'RCDescription' = $RCDescription }
			#Add-GenericMessage -Id $RootCauseName -InformationCollected $InformationCollected
		}
	}
}

function Get-ServiceDisabled (
	$ServiceName,
	$DesiredStartMode = 'Manual',
	$RCDescription = '') {
	$RootCauseName = 'RC_ServiceMode'

	$InformationCollected = New-Object PSObject
	$Service = Get-CimInstance Win32_Service | Where-Object { $_.Name -eq $ServiceName }
	if ($Service -is [CimInstance]) {
		LogInfo "Checking the status of: $($Service.DisplayName)"

		if ($Service.StartMode -eq 'Disabled') {
			$InformationCollected | Add-Member -MemberType NoteProperty -Name 'Name' -Value ($Service.Name)
			$InformationCollected | Add-Member -MemberType NoteProperty -Name 'Start Mode' -Value ($Service.StartMode)
			$InformationCollected | Add-Member -MemberType NoteProperty -Name 'Current State' -Value ($Service.State)
			# WindowsCSSToolsDevRep\Dev\ALL\TSSv2\psSDP\Diag\global\utils_Remote.ps1
			#Update-DiagRootCause -id $RootCauseName -Detected $true -InstanceId $ServiceName -Parameter @{'ServiceName' = $Service.DisplayName; 'DesiredStartMode' = $DesiredStartMode; 'RCDescription' = $RCDescription }
			#Add-GenericMessage -Id $RootCauseName -InformationCollected $InformationCollected
		}
	}
}

#region --- WU helper functions ---
function GetHotFixFromRegistry {
	$RegistryHotFixList = @{}
	$UpdateRegistryKeys = @('HKLM:\SOFTWARE\Microsoft\Updates')

	#if $OSArchitecture -ne X86 , should be 64-bit machine. we also need to check HKLM:\SOFTWARE\Wow6432Node\Microsoft\Updates
	if ($OSArchitecture -ne 'X86') {
		$UpdateRegistryKeys += 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Updates'
	}

	foreach ($RegistryKey in $UpdateRegistryKeys) {
		If (Test-Path $RegistryKey) {
			$AllProducts = Get-ChildItem $RegistryKey -Recurse | Where-Object { $_.Name.Contains('KB') -or $_.Name.Contains('Q') }

			foreach ($subKey in $AllProducts) {
				if ($subKey.Name.Contains('KB') -or $subKey.Name.Contains('Q')) {
					$HotFixID = GetHotFixID $subKey.Name
					if ($RegistryHotFixList.Keys -notcontains $HotFixID) {
						$Category = [regex]::Match($subKey.Name, 'Updates\\(?<Category>.*?)[\\]').Groups['Category'].Value
						$HotFix = @{HotFixID = $HotFixID; Category = $Category }
						foreach ($property in $subKey.Property) {
							$HotFix.Add($property, $subKey.GetValue($property))
						}
						$RegistryHotFixList.Add($HotFixID, $HotFix)
					}
				}
			}
		}
	}
	return $RegistryHotFixList
}

function GetHotFixID($strContainID) {
	return [System.Text.RegularExpressions.Regex]::Match($strContainID, '(KB|Q)\d+(v\d)?').Value
}

function ToNumber($strHotFixID) {
	return [System.Text.RegularExpressions.Regex]::Match($strHotFixID, '([0-9])+').Value
}

function FormatStr([string]$strValue, [int]$NumberofChars) {
	if ([String]::IsNullOrEmpty($strValue)) {
		$strValue = ' '
		return $strValue.PadRight($NumberofChars, ' ')
	}
	else {
		if ($strValue.Length -lt $NumberofChars) {
			return $strValue.PadRight($NumberofChars, ' ')
		}
		else {
			return $strValue.Substring(0, $NumberofChars)
		}
	}
}

# Make sure all dates are with dd/mm/yy hh:mm:ss
function FormatDateTime($dtLocalDateTime, [Switch]$SortFormat) {
	trap {
		LogException '[FormatDateTime] Error Convert date time' $_
		continue
	}

	if ([string]::IsNullOrEmpty($dtLocalDateTime)) {
		return ''
	}

	if ($SortFormat.IsPresent) {
		# Obtain dates on yyyymmdddhhmmss
		return Get-Date -Date $dtLocalDateTime -Format 'yyyyMMddHHmmss'
	}
	else {
		return Get-Date -Date $dtLocalDateTime -Format G
	}
}

function ValidatingDateTime($dateTimeToValidate) {
	trap {
		LogException '[ValidateDateTime] Error' $_
		continue
	}

	if ([String]::IsNullOrEmpty($dateTimeToValidate)) {
		return $false
	}

	$ConvertedDateTime = Get-Date -Date $dateTimeToValidate

	if ($null -ne $ConvertedDateTime) {
		if (((Get-Date) - $ConvertedDateTime).Days -le $NumberOfDays) {
			return $true
		}
	}

	return $false
}

function GetUpdateResultString($OperationResult) {
	switch ($OperationResult) {
		'Completed successfully' { return "<span xmlns:v=`"urn:schemas-microsoft-com:vml`"><v:group id=`"Inf1`" class=`"vmlimage`" style=`"width:15px;height:15px;vertical-align:middle`" coordsize=`"100,100`" title=`"Completed successfully`"><v:oval class=`"vmlimage`" style=`"width:100;height:100;z-index:0`" fillcolor=`"#009933`" strokecolor=`"#C0C0C0`" /></v:group></span>" }
		'In progress' { return "<span xmlns:v=`"urn:schemas-microsoft-com:vml`"><v:group class=`"vmlimage`" style=`"width:14px;height:14px;vertical-align:middle`" coordsize=`"100,100`" title=`"In progress`"><v:roundrect class=`"vmlimage`" arcsize=`"10`" style=`"width:100;height:100;z-index:0`" fillcolor=`"#00FF00`" strokecolor=`"#C0C0C0`" /><v:shape class=`"vmlimage`" style=`"width:100; height:100; z-index:0`" fillcolor=`"white`" strokecolor=`"white`"><v:path v=`"m 40,25 l 75,50 40,75 x e`" /></v:shape></v:group></span>" }
		'Operation was aborted' { return "<span xmlns:v=`"urn:schemas-microsoft-com:vml`"><v:group class=`"vmlimage`" style=`"width:15px;height:15px;vertical-align:middle`" coordsize=`"100,100`" title=`"Operation was aborted`"><v:roundrect class=`"vmlimage`" arcsize=`"20`" style=`"width:100;height:100;z-index:0`" fillcolor=`"#290000`" strokecolor=`"#C0C0C0`" /><v:line class=`"vmlimage`" style=`"z-index:2`" from=`"52,30`" to=`"52,75`" strokecolor=`"white`" strokeweight=`"8px`" /></v:group></span>" }
		'Completed with errors' { return "<span xmlns:v=`"urn:schemas-microsoft-com:vml`"><v:group class=`"vmlimage`" style=`"width:15px;height:15px;vertical-align:middle`" coordsize=`"100,100`" title=`"Completed with errors`"><v:shape class=`"vmlimage`" style=`"width:100; height:100; z-index:0`" fillcolor=`"yellow`" strokecolor=`"#C0C0C0`"><v:path v=`"m 50,0 l 0,99 99,99 x e`" /></v:shape><v:rect class=`"vmlimage`" style=`"top:35; left:45; width:10; height:35; z-index:1`" fillcolor=`"black`" strokecolor=`"black`"></v:rect><v:rect class=`"vmlimage`" style=`"top:85; left:45; width:10; height:5; z-index:1`" fillcolor=`"black`" strokecolor=`"black`"></v:rect></v:group></span>" }
		'Failed to complete' { return "<span xmlns:v=`"urn:schemas-microsoft-com:vml`"><v:group class=`"vmlimage`" style=`"width:15px;height:15px;vertical-align:middle`" coordsize=`"100,100`" title=`"Failed to complete`"><v:oval class=`"vmlimage`" style=`"width:100;height:100;z-index:0`" fillcolor=`"red`" strokecolor=`"#C0C0C0`"></v:oval><v:line class=`"vmlimage`" style=`"z-index:1`" from=`"25,25`" to=`"75,75`" strokecolor=`"white`" strokeweight=`"3px`"></v:line><v:line class=`"vmlimage`" style=`"z-index:2`" from=`"75,25`" to=`"25,75`" strokecolor=`"white`" strokeweight=`"3px`"></v:line></v:group></span>" }
		Default { return "<span xmlns:v=`"urn:schemas-microsoft-com:vml`"><v:group id=`"Inf1`" class=`"vmlimage`" style=`"width:15px;height:15px;vertical-align:middle`" coordsize=`"100,100`" title=`"{$OperationResult}`"><v:oval class=`"vmlimage`" style=`"width:100;height:100;z-index:0`" fillcolor=`"#FF9933`" strokecolor=`"#C0C0C0`" /></v:group></span>" }
	}
}

<# Get-SCCMOsSkuName #>
<#
function GetOSSKU($SKU) {
	switch ($SKU) {
		0 { return '' }
		1 { return 'Ultimate Edition' }
		2 { return 'Home Basic Edition' }
		3 { return 'Home Basic Premium Edition' }
		4 { return 'Enterprise Edition' }
		5 { return 'Home Basic N Edition' }
		6 { return 'Business Edition' }
		7 { return 'Standard Server Edition' }
		8 { return 'Datacenter Server Edition' }
		9 { return 'Small Business Server Edition' }
		10 { return 'Enterprise Server Edition' }
		11 { return 'Starter Edition' }
		12 { return 'Datacenter Server Core Edition' }
		13 { return 'Standard Server Core Edition' }
		14 { return 'Enterprise Server Core Edition' }
		15 { return 'Enterprise Server Edition for Itanium-Based Systems' }
		16 { return 'Business N Edition' }
		17 { return 'Web Server Edition' }
		18 { return 'Cluster Server Edition' }
		19 { return 'Home Server Edition' }
		20 { return 'Storage Express Server Edition' }
		21 { return 'Storage Standard Server Edition' }
		22 { return 'Storage Workgroup Server Edition' }
		23 { return 'Storage Enterprise Server Edition' }
		24 { return 'Server For Small Business Edition' }
		25 { return 'Small Business Server Premium Edition' }
	}
}
#>

function GetOS() {
	$WMIOS = Get-CimInstance -Class Win32_OperatingSystem

	$StringOS = $WMIOS.Caption

	if ($null -ne $WMIOS.CSDVersion) {
		$StringOS += ' - ' + $WMIOS.CSDVersion
	}
	else {
		$StringOS += ' - Service Pack not installed'
	}

	if (($null -ne $WMIOS.OperatingSystemSKU) -and ($WMIOS.OperatingSystemSKU.ToString().Length -gt 0)) {
		$StringOS += ' (' + (Get-SCCMOsSkuName $WMIOS.OperatingSystemSKU) + ')'
	}

	return $StringOS
}

# Query SID of an object using WMI and return the account name
function ConvertSIDToUser([string]$strSID) {
	trap {
		LogException '[ConvertSIDToUser] Error convert User SID to User Account' $_
		continue
	}

	if ([string]::IsNullOrEmpty($strSID)) {
		return
	}

	if ($strSID.StartsWith('S-1-5')) {
		$UserSIDIdentifier = New-Object System.Security.Principal.SecurityIdentifier `
		($strSID)
		$UserNTAccount = $UserSIDIdentifier.Translate( [System.Security.Principal.NTAccount])
		if ($UserNTAccount.Value.Length -gt 0) {
			return $UserNTAccount.Value
		}
		else {
			return $strSID
		}
	}

	return $strSID
}

function ConvertToHex([int]$number) {
	return ('0x{0:x8}' -f $number)
}

function GetUpdateOperation($Operation) {
	switch ($Operation) {
		1 { return 'Install' }
		2 { return 'Uninstall' }
		Default { return 'Unknown(' + $Operation + ')' }
	}
}

function GetUpdateResult($ResultCode) {
	switch ($ResultCode) {
		0 { return 'Not started' }
		1 { return 'In progress' }
		2 { return 'Completed successfully' }
		3 { return 'Completed with errors' }
		4 { return 'Failed to complete' }
		5 { return 'Operation was aborted' }
		Default { return 'Unknown(' + $ResultCode + ')' }
	}
}

function GetWUErrorCodes($HResult) {
	if ($null -eq $Script:WUErrors) {
		$WUErrorsFilePath = Join-Path $PWD.Path 'WUErrors.xml'
		if (Test-Path $WUErrorsFilePath) {
			[xml] $Script:WUErrors = Get-Content $WUErrorsFilePath
		}
		else {
			LogInfo '[Error]: Did not find the WUErrors.xml file, can not load all WU errors'
		}
	}

	$WUErrorNode = $Script:WUErrors.ErrV1.err | Where-Object { $_.n -eq $HResult }

	if ($null -ne $WUErrorNode) {
		$WUErrorCode = @()
		$WUErrorCode += $WUErrorNode.name
		$WUErrorCode += $WUErrorNode.'#text'
		return $WUErrorCode
	}

	return $null
}

function PrintHeaderOrXMLFooter([switch]$IsHeader, [switch]$IsXMLFooter) {
	if ($IsHeader.IsPresent) {
		if ($OutputFormats -contains 'TXT') {
			# TXT formate Header
			LineOut -IsTXTFormat -Value ([String]::Format('{0} {1} {2} {3} {4} {5} {6} {7} {8}',
												(FormatStr 'Category' 20),
												(FormatStr 'Level' 6),
												(FormatStr 'ID' 10),
												(FormatStr 'Operation' 11),
												(FormatStr 'Date' 23),
												(FormatStr 'Client' 18),
												(FormatStr 'By' 28),
												(FormatStr 'Result' 23),
					'Title'))
			LineOut -IsTXTFormat -Value ('-').PadRight(200, '-')
		}

		if ($OutputFormats -contains 'CSV') {
			# CSV formate Header
			LineOut -IsCSVFormat -Value ('Category,Level,ID,Operation,Date,Client,By,Result,Title')
		}

		if ($OutputFormats -contains 'HTM') {
			# XML format Header
			LineOut -IsXMLFormat -IsXMLLine -Value "<?xml version=`"1.0`" encoding=`"UTF-8`"?>"
			LineOut -IsXMLFormat -IsOpenTag -TagName 'Root'
			LineOut -IsXMLFormat -IsOpenTag -TagName 'Updates'
			LineOut -IsXMLFormat -IsXMLLine -Value ("<Title name=`"QFE Information from`">" + $Env:COMPUTERNAME + '</Title>')
			LineOut -IsXMLFormat -IsXMLLine -Value ("<OSVersion name=`"Operating System`">" + (GetOS) + '</OSVersion>')
			LineOut -IsXMLFormat -IsXMLLine -Value ("<TimeField name=`"Local time`">" + [DateTime]::Now.ToString() + '</TimeField>')
		}
	}

	if ($IsXMLFooter) {
		if ($OutputFormats -contains 'HTM') {
			LineOut -IsXMLFormat -IsCloseTag -TagName 'Updates'
			LineOut -IsXMLFormat -IsCloseTag -TagName 'Root'
		}
	}
}

function LineOut([string]$TagName, [string]$Value, [switch]$IsTXTFormat, [switch]$IsCSVFormat, [switch]$IsXMLFormat, [switch]$IsXMLLine, [switch]$IsOpenTag, [switch]$IsCloseTag) {
	if ($IsTXTFormat.IsPresent) {
		[void]$Script:SbTXTFormat.AppendLine($Value)
	}

	if ($IsCSVFormat.IsPresent) {
		[void]$Script:SbCSVFormat.AppendLine($Value)
	}

	if ($IsXMLFormat.IsPresent) {
		if ($IsXMLLine.IsPresent) {
			[void]$Script:SbXMLFormat.AppendLine($Value)
			return
		}

		if (($TagName -eq $null) -or ($TagName -eq '')) {
			LogWarn"[Warning]: Did not provide valid TagName: $TagName, will not add this Tag."
			return
		}

		if ($IsOpenTag.IsPresent -or $IsCloseTag.IsPresent) {
			if ($IsOpenTag.IsPresent) {
				[void]$Script:SbXMLFormat.AppendLine('<' + $TagName + '>')
			}

			if ($IsCloseTag.IsPresent) {
				[void]$Script:SbXMLFormat.AppendLine('</' + $TagName + '>')
			}
		}
		else {
			[void]$Script:SbXMLFormat.AppendLine('<' + $TagName + '>' + $Value + '</' + $TagName + '>')
		}
	}
}

function PrintUpdate([string]$Category, [string]$SPLevel, [string]$ID, [string]$Operation, [string]$Date, [string]$ClientID, [string]$InstalledBy, [string]$OperationResult, [string]$Title, [string]$Description, [string]$HResult, [string]$UnmappedResultCode) {
	if ($OutputFormats -contains 'TXT') {
		LineOut -IsTXTFormat -Value ([String]::Format('{0} {1} {2} {3} {4} {5} {6} {7} {8}',
												(FormatStr $Category 20),
												(FormatStr $SPLevel 6),
												(FormatStr $ID 10),
												(FormatStr $Operation 11),
												(FormatStr $Date 23),
												(FormatStr $ClientID 18),
												(FormatStr $InstalledBy 28),
												(FormatStr $OperationResult 23),
				$Title))
	}

	if ($OutputFormats -contains 'CSV') {
		LineOut -IsCSVFormat -Value ([String]::Format('{0},{1},{2},{3},{4},{5},{6},{7},{8}',
				$Category,
				$SPLevel,
				$ID,
				$Operation,
				$Date,
				$ClientID,
				$InstalledBy,
				$OperationResult,
				$Title))
	}

	if ($OutputFormats -contains 'HTM') {
		if ($Category -eq 'QFE hotfix') {
			$Category = 'Other updates not listed in history'
		}

		if (-not [String]::IsNullOrEmpty($ID)) {
			$NumberHotFixID = ToNumber $ID
			if ($NumberHotFixID.Length -gt 5) {
				$SupportLink = "http://support.microsoft.com/kb/$NumberHotFixID"
			}
		}
		else {
			$ID = ''
			$SupportLink = ''
		}

		if ([String]::IsNullOrEmpty($Date)) {
			$DateTime = ''
		}
		else {
			$DateTime = FormatDateTime $Date -SortFormat
		}

		if ([String]::IsNullOrEmpty($Title)) {
			$Title = ''
		}
		else {
			$Title = $Title.Trim()
		}

		if ([String]::IsNullOrEmpty($Description)) {
			$Description = ''
		}
		else {
			$Description = $Description.Trim()
		}

		# Write the Update to XML Formate
		LineOut -IsXMLFormat -TagName 'Update' -IsOpenTag
		LineOut -IsXMLFormat -TagName 'Category' -Value $Category
		if (-not [String]::IsNullOrEmpty($SPLevel)) {
			LineOut -IsXMLFormat -TagName 'SPLevel' -Value $SPLevel
		}
		LineOut -IsXMLFormat -TagName 'ID' -Value $ID
		LineOut -IsXMLFormat -TagName 'SupportLink' -Value $SupportLink
		LineOut -IsXMLFormat -TagName 'Operation' -Value $Operation
		LineOut -IsXMLFormat -TagName 'Date' -Value $Date
		LineOut -IsXMLFormat -TagName 'SortableDate' -Value $DateTime
		LineOut -IsXMLFormat -TagName 'ClientID' -Value $ClientID
		LineOut -IsXMLFormat -TagName 'InstalledBy' -Value $InstalledBy
		LineOut -IsXMLFormat -TagName 'OperationResult' -Value $OperationResult
		LineOut -IsXMLFormat -TagName 'Title' -Value $Title
		LineOut -IsXMLFormat -TagName 'Description' -Value $Description

		if ((-not [String]::IsNullOrEmpty($HResult)) -and ($HResult -ne 0)) {
			$HResultHex = ConvertToHex $HResult
			$HResultArray = GetWUErrorCodes $HResultHex

			LineOut -IsXMLFormat -IsOpenTag -TagName 'HResult'
			LineOut -IsXMLFormat -TagName 'HEX' -Value $HResultHex
			if ($null -ne $HResultArray) {
				LineOut -IsXMLFormat -TagName 'Constant' -Value $HResultArray[0]
				LineOut -IsXMLFormat -TagName 'Description' -Value $HResultArray[1]
			}
			LineOut -IsXMLFormat -IsCloseTag -TagName 'HResult'
			LineOut -IsXMLFormat -TagName 'UnmappedResultCode' -Value (ConvertToHex $UnmappedResultCode)
		}

		LineOut -IsXMLFormat -TagName 'Update' -IsCloseTag

		if (($ExportOnly.IsPresent -eq $false) -and (ValidatingDateTime $Date)) {
			if ($null -ne $LatestUpdates_Summary.$Date) {
				$LatestUpdates_Summary.$Date = $LatestUpdates_Summary.$Date.Insert($LatestUpdates_Summary.$Date.LastIndexOf('</table>'), "<tr><td width=`"40px`" align=`"center`">" + (GetUpdateResultString $OperationResult) + "</td><td width=`"60px`"><a href=`"$SupportLink`" Target=`"_blank`">$ID</a></td><td>$Category</td></tr>")
			}
			else {
				$LatestUpdates_Summary | Add-Member -MemberType NoteProperty -Name $Date -Value ("<table><tr><td width=`"40px`" align=`"center`">" + (GetUpdateResultString $OperationResult) + "</td><td width=`"60px`"><a href=`"$SupportLink`" Target=`"_blank`">$ID</a></td><td>$($Category): $($Title)</td></tr></table>")
			}

			$Script:LatestUpdateCount++
		}
	}
}

function GenerateHTMFile([string] $XMLFileNameWithoutExtension) {
	trap {
		LogException '[GenerateHTMFile] Error creating HTM file' $_
		continue
	}

	$UpdateXslFilePath = Join-Path $pwd.path 'UpdateHistory.xsl'
	if (Test-Path $UpdateXslFilePath) {
		$XSLObject = New-Object System.Xml.Xsl.XslTransform
		$XSLObject.Load($UpdateXslFilePath)
		if (Test-Path ($XMLFileNameWithoutExtension + '.XML')) {
			$XSLObject.Transform(($XMLFileNameWithoutExtension + '.XML'), ($XMLFileNameWithoutExtension + '.HTM'))
		}
		else {
			LogWarn 'Error: HTML file was not generated'
		}
	}
	else {
		LogWarn "Error: Did not find the UpdateHistory.xsl, won't generate HTM file."
	}
}
#endregion --- WU helper functions ---

function CheckForHotfix ($hotfixID, $title, $Warn = '') {
	$link = 'http://support.microsoft.com/kb/' + $hotfixID
	if (-not (($script:hotfixesWMI.HotfixID) -contains $hotfixID)) {
		"No          $hotfixID - $title   ($link)" | Out-File -FilePath $OutputFile -Append
		If ($Warn -match 'Yes') {
			LogInfo 'This system is not up-to-date. Many known issues are resolved by applying latest cumulative update!' 'Cyan'
			LogInfo "*** [WARNING] latest OS cumulative KB $hotfixID is missing.`n Please update this machine with recommended Microsoft KB $hotfixID and verify if your issue is resolved." 'Magenta'
			$Global:MissingCU = $hotfixID
		}
	}
	else {
		"Yes         $hotfixID - $title   ($link)" | Out-File -FilePath $OutputFile -Append
	}
}

# Successfully loaded SCCM utility functions.
if ($script:SCCM_utils) {
	LogInfo 'Successfully loaded SCCM utility functions.' White
}
# SIG # Begin signature block
# MIInvwYJKoZIhvcNAQcCoIInsDCCJ6wCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA1lFdeAu13DB/W
# tWKJn5Whc2pkiHqasigJSBTjRNVOa6CCDXYwggX0MIID3KADAgECAhMzAAADrzBA
# DkyjTQVBAAAAAAOvMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjMxMTE2MTkwOTAwWhcNMjQxMTE0MTkwOTAwWjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDOS8s1ra6f0YGtg0OhEaQa/t3Q+q1MEHhWJhqQVuO5amYXQpy8MDPNoJYk+FWA
# hePP5LxwcSge5aen+f5Q6WNPd6EDxGzotvVpNi5ve0H97S3F7C/axDfKxyNh21MG
# 0W8Sb0vxi/vorcLHOL9i+t2D6yvvDzLlEefUCbQV/zGCBjXGlYJcUj6RAzXyeNAN
# xSpKXAGd7Fh+ocGHPPphcD9LQTOJgG7Y7aYztHqBLJiQQ4eAgZNU4ac6+8LnEGAL
# go1ydC5BJEuJQjYKbNTy959HrKSu7LO3Ws0w8jw6pYdC1IMpdTkk2puTgY2PDNzB
# tLM4evG7FYer3WX+8t1UMYNTAgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQURxxxNPIEPGSO8kqz+bgCAQWGXsEw
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzUwMTgyNjAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAISxFt/zR2frTFPB45Yd
# mhZpB2nNJoOoi+qlgcTlnO4QwlYN1w/vYwbDy/oFJolD5r6FMJd0RGcgEM8q9TgQ
# 2OC7gQEmhweVJ7yuKJlQBH7P7Pg5RiqgV3cSonJ+OM4kFHbP3gPLiyzssSQdRuPY
# 1mIWoGg9i7Y4ZC8ST7WhpSyc0pns2XsUe1XsIjaUcGu7zd7gg97eCUiLRdVklPmp
# XobH9CEAWakRUGNICYN2AgjhRTC4j3KJfqMkU04R6Toyh4/Toswm1uoDcGr5laYn
# TfcX3u5WnJqJLhuPe8Uj9kGAOcyo0O1mNwDa+LhFEzB6CB32+wfJMumfr6degvLT
# e8x55urQLeTjimBQgS49BSUkhFN7ois3cZyNpnrMca5AZaC7pLI72vuqSsSlLalG
# OcZmPHZGYJqZ0BacN274OZ80Q8B11iNokns9Od348bMb5Z4fihxaBWebl8kWEi2O
# PvQImOAeq3nt7UWJBzJYLAGEpfasaA3ZQgIcEXdD+uwo6ymMzDY6UamFOfYqYWXk
# ntxDGu7ngD2ugKUuccYKJJRiiz+LAUcj90BVcSHRLQop9N8zoALr/1sJuwPrVAtx
# HNEgSW+AKBqIxYWM4Ev32l6agSUAezLMbq5f3d8x9qzT031jMDT+sUAoCw0M5wVt
# CUQcqINPuYjbS1WgJyZIiEkBMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
# hkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5
# IDIwMTEwHhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQg
# Q29kZSBTaWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEAq/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03
# a8YS2AvwOMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akr
# rnoJr9eWWcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0Rrrg
# OGSsbmQ1eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy
# 4BI6t0le2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9
# sbKvkjh+0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAh
# dCVfGCi2zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8k
# A/DRelsv1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTB
# w3J64HLnJN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmn
# Eyimp31ngOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90
# lfdu+HggWCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0w
# ggHpMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2o
# ynUClTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYD
# VR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBa
# BgNVHR8EUzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2Ny
# bC9wcm9kdWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsG
# AQUFBwEBBFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNV
# HSAEgZcwgZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsG
# AQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABl
# AG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKb
# C5YR4WOSmUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11l
# hJB9i0ZQVdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6
# I/MTfaaQdION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0
# wI/zRive/DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560
# STkKxgrCxq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQam
# ASooPoI/E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGa
# J+HNpZfQ7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ah
# XJbYANahRr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA
# 9Z74v2u3S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33Vt
# Y5E90Z1WTk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr
# /Xmfwb1tbWrJUnMTDXpQzTGCGZ8wghmbAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAOvMEAOTKNNBUEAAAAAA68wDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIPChRJEb8a2H6r8p3/7p5JvO
# HXZFKDmueyCJ0UqneX4FMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAfr4QkDIJxcTbrHBhoPj0W785oAPOUrXcRld/dB+s6n6CSexlNxmEp3Hx
# Y78SHnu9UrKOVtjmoknprM8CoH9DfNYQHLjWTMso/8emY4QoRBEEG254lPOFz5sW
# diqZtbeRmvujwbmRYkp31ICQ9PHlbDCuLQ9WCx2A9I7S861dgFBeMZtk5OWnduAT
# KvQ8BsOdFCk+qd3ILfUHua2zLn1GqcOcZj6yZR7FsOzIrRixVM+O6Q2nTjHEyx1l
# p54j7FspHc+UTUVlx98QhW3GI/4FZ6Ga+2EfSvo04HAK+hkvzMPSSRONuwuRHq2Y
# 0YL7+ZOIKLTuUlJRc1KSOzlyVhLf7qGCFykwghclBgorBgEEAYI3AwMBMYIXFTCC
# FxEGCSqGSIb3DQEHAqCCFwIwghb+AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsq
# hkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCAfZCh2Ag6q0uud0/G3VEX+P5QsWEoKOxh/U05xLGz5KQIGZbql3kav
# GBMyMDI0MDIyMDEyMTY1OS40MTZaMASAAgH0oIHYpIHVMIHSMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJl
# bGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNO
# OkZDNDEtNEJENC1EMjIwMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNloIIReDCCBycwggUPoAMCAQICEzMAAAHimZmV8dzjIOsAAQAAAeIwDQYJ
# KoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjMx
# MDEyMTkwNzI1WhcNMjUwMTEwMTkwNzI1WjCB0jELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3Bl
# cmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpGQzQxLTRC
# RDQtRDIyMDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALVjtZhV+kFmb8cKQpg2mzis
# DlRI978Gb2amGvbAmCd04JVGeTe/QGzM8KbQrMDol7DC7jS03JkcrPsWi9WpVwsI
# ckRQ8AkX1idBG9HhyCspAavfuvz55khl7brPQx7H99UJbsE3wMmpmJasPWpgF05z
# ZlvpWQDULDcIYyl5lXI4HVZ5N6MSxWO8zwWr4r9xkMmUXs7ICxDJr5a39SSePAJR
# IyznaIc0WzZ6MFcTRzLLNyPBE4KrVv1LFd96FNxAzwnetSePg88EmRezr2T3HTFE
# lneJXyQYd6YQ7eCIc7yllWoY03CEg9ghorp9qUKcBUfFcS4XElf3GSERnlzJsK7s
# /ZGPU4daHT2jWGoYha2QCOmkgjOmBFCqQFFwFmsPrZj4eQszYxq4c4HqPnUu4hT4
# aqpvUZ3qIOXbdyU42pNL93cn0rPTTleOUsOQbgvlRdthFCBepxfb6nbsp3fcZaPB
# fTbtXVa8nLQuMCBqyfsebuqnbwj+lHQfqKpivpyd7KCWACoj78XUwYqy1HyYnStT
# me4T9vK6u2O/KThfROeJHiSg44ymFj+34IcFEhPogaKvNNsTVm4QbqphCyknrwBy
# qorBCLH6bllRtJMJwmu7GRdTQsIx2HMKqphEtpSm1z3ufASdPrgPhsQIRFkHZGui
# hL1Jjj4Lu3CbAmha0lOrAgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQURIQOEdq+7Qds
# lptJiCRNpXgJ2gUwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYD
# VR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9j
# cmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwG
# CCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIw
# MjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcD
# CDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAORURDGrVRTbnulf
# sg2cTsyyh7YXvhVU7NZMkITAQYsFEPVgvSviCylr5ap3ka76Yz0t/6lxuczI6w7t
# Xq8n4WxUUgcj5wAhnNorhnD8ljYqbck37fggYK3+wEwLhP1PGC5tvXK0xYomU1nU
# +lXOy9ZRnShI/HZdFrw2srgtsbWow9OMuADS5lg7okrXa2daCOGnxuaD1IO+65E7
# qv2O0W0sGj7AWdOjNdpexPrspL2KEcOMeJVmkk/O0ganhFzzHAnWjtNWneU11WQ6
# Bxv8OpN1fY9wzQoiycgvOOJM93od55EGeXxfF8bofLVlUE3zIikoSed+8s61NDP+
# x9RMya2mwK/Ys1xdvDlZTHndIKssfmu3vu/a+BFf2uIoycVTvBQpv/drRJD68eo4
# 01mkCRFkmy/+BmQlRrx2rapqAu5k0Nev+iUdBUKmX/iOaKZ75vuQg7hCiBA5xIm5
# ZIXDSlX47wwFar3/BgTwntMq9ra6QRAeS/o/uYWkmvqvE8Aq38QmKgTiBnWSS/uV
# PcaHEyArnyFh5G+qeCGmL44MfEnFEhxc3saPmXhe6MhSgCIGJUZDA7336nQD8fn4
# y6534Lel+LuT5F5bFt0mLwd+H5GxGzObZmm/c3pEWtHv1ug7dS/Dfrcd1sn2E4gk
# 4W1L1jdRBbK9xwkMmwY+CHZeMSvBMIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJ
# mQAAAAAAFTANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNh
# dGUgQXV0aG9yaXR5IDIwMTAwHhcNMjEwOTMwMTgyMjI1WhcNMzAwOTMwMTgzMjI1
# WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBAOThpkzntHIhC3miy9ckeb0O1YLT/e6cBwfSqWxOdcjK
# NVf2AX9sSuDivbk+F2Az/1xPx2b3lVNxWuJ+Slr+uDZnhUYjDLWNE893MsAQGOhg
# fWpSg0S3po5GawcU88V29YZQ3MFEyHFcUTE3oAo4bo3t1w/YJlN8OWECesSq/XJp
# rx2rrPY2vjUmZNqYO7oaezOtgFt+jBAcnVL+tuhiJdxqD89d9P6OU8/W7IVWTe/d
# vI2k45GPsjksUZzpcGkNyjYtcI4xyDUoveO0hyTD4MmPfrVUj9z6BVWYbWg7mka9
# 7aSueik3rMvrg0XnRm7KMtXAhjBcTyziYrLNueKNiOSWrAFKu75xqRdbZ2De+JKR
# Hh09/SDPc31BmkZ1zcRfNN0Sidb9pSB9fvzZnkXftnIv231fgLrbqn427DZM9itu
# qBJR6L8FA6PRc6ZNN3SUHDSCD/AQ8rdHGO2n6Jl8P0zbr17C89XYcz1DTsEzOUyO
# ArxCaC4Q6oRRRuLRvWoYWmEBc8pnol7XKHYC4jMYctenIPDC+hIK12NvDMk2ZItb
# oKaDIV1fMHSRlJTYuVD5C4lh8zYGNRiER9vcG9H9stQcxWv2XFJRXRLbJbqvUAV6
# bMURHXLvjflSxIUXk8A8FdsaN8cIFRg/eKtFtvUeh17aj54WcmnGrnu3tz5q4i6t
# AgMBAAGjggHdMIIB2TASBgkrBgEEAYI3FQEEBQIDAQABMCMGCSsGAQQBgjcVAgQW
# BBQqp1L+ZMSavoKRPEY1Kc8Q/y8E7jAdBgNVHQ4EFgQUn6cVXQBeYl2D9OXSZacb
# UzUZ6XIwXAYDVR0gBFUwUzBRBgwrBgEEAYI3TIN9AQEwQTA/BggrBgEFBQcCARYz
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9Eb2NzL1JlcG9zaXRvcnku
# aHRtMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIA
# QwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNX2
# VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwu
# bWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEw
# LTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYt
# MjMuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCdVX38Kq3hLB9nATEkW+Geckv8qW/q
# XBS2Pk5HZHixBpOXPTEztTnXwnE2P9pkbHzQdTltuw8x5MKP+2zRoZQYIu7pZmc6
# U03dmLq2HnjYNi6cqYJWAAOwBb6J6Gngugnue99qb74py27YP0h1AdkY3m2CDPVt
# I1TkeFN1JFe53Z/zjj3G82jfZfakVqr3lbYoVSfQJL1AoL8ZthISEV09J+BAljis
# 9/kpicO8F7BUhUKz/AyeixmJ5/ALaoHCgRlCGVJ1ijbCHcNhcy4sa3tuPywJeBTp
# kbKpW99Jo3QMvOyRgNI95ko+ZjtPu4b6MhrZlvSP9pEB9s7GdP32THJvEKt1MMU0
# sHrYUP4KWN1APMdUbZ1jdEgssU5HLcEUBHG/ZPkkvnNtyo4JvbMBV0lUZNlz138e
# W0QBjloZkWsNn6Qo3GcZKCS6OEuabvshVGtqRRFHqfG3rsjoiV5PndLQTHa1V1QJ
# sWkBRH58oWFsc/4Ku+xBZj1p/cvBQUl+fpO+y/g75LcVv7TOPqUxUYS8vwLBgqJ7
# Fx0ViY1w/ue10CgaiQuPNtq6TPmb/wrpNPgkNWcr4A245oyZ1uEi6vAnQj0llOZ0
# dFtq0Z4+7X6gMTN9vMvpe784cETRkPHIqzqKOghif9lwY1NNje6CbaUFEMFxBmoQ
# tB1VM1izoXBm8qGCAtQwggI9AgEBMIIBAKGB2KSB1TCB0jELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxh
# bmQgT3BlcmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpG
# QzQxLTRCRDQtRDIyMDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUAFpuZafp0bnpJdIhfiB1d8pTohm+ggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AOl+11kwIhgPMjAyNDAyMjAxNTQ2MzNaGA8yMDI0MDIyMTE1NDYzM1owdDA6Bgor
# BgEEAYRZCgQBMSwwKjAKAgUA6X7XWQIBADAHAgEAAgI98DAHAgEAAgIRXjAKAgUA
# 6YAo2QIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAID
# B6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBAFdj05bCS79zk94lJyoh
# SYYUwgtp5qzf6hEyJuKI5hMzkqurA3ZUtT/FM4sK8a1ypzPW6ygqvVO8HYeRDlmk
# bo3iTY+eFiZlptT5Xcod8nqaz0tWyoM+FZwvRi7b/ykz/TvX5JOKapRv4JbWacMv
# 4ljbTBxvyx72jCgsQLfgs4dYMYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgUENBIDIwMTACEzMAAAHimZmV8dzjIOsAAQAAAeIwDQYJYIZIAWUDBAIB
# BQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQx
# IgQg7cQVPVqQ1jaBlaXfWlWGE0TdMyZjFhqsGkG1kEOLliwwgfoGCyqGSIb3DQEJ
# EAIvMYHqMIHnMIHkMIG9BCAriSpKEP0muMbBUETODoL4d5LU6I/bjucIZkOJCI9/
# /zCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB4pmZ
# lfHc4yDrAAEAAAHiMCIEINj9jjwk1TLFNQu7Sl1tdDvaw/Ukh0QzLxJqZLRW9zR8
# MA0GCSqGSIb3DQEBCwUABIICAAN4HjKGneIiUVCO0ovRSQnBkPo6fN0RYQzTMHpv
# dc3PqeESVxPbCePAkmeAwLuXi23jJ/i+noR2hJeg7ruWFBzxNe45O3yPjvXJUWEX
# ZQcivjXh5OCvzXYGiopzs7HeLz3xNCPp8khQwJsBpZ+qUS6w0V0gxMpI5Q9aOfR+
# ueLCYXPhEpJIwZHNdwiPy9meLjGi+LWHsDZrkLMilnsCMhjsSrAMV/zmdgdZLbNN
# jzSDGkrv4Tm2r7uB80mQmZWnniLafcyoN7lsDDiw7y104P+qFEz5TgE84aUdNOjj
# Y+vvAKB133KNadoXrRylCiXpP+hJQpT7bTpDsXWYSLv4Pz1deJdDkPc71QUd8hO1
# U60MDmL8r1dqds+V8fy5iP34TY18UTCE5Oom9IXpNQijAVwgvTKmrbmL/upI/Ftu
# 7Fv2PRVVJ0ciYoDcwAL+lPuCcZ0ABpdwBZXSiOdJgvGsxF8JsPsqKQta6+cYamEz
# DBDYPtGHMGpFxIzKTmTX3KZBSjXRPIRxNZejYPooIOFApa6zsYSBCG1VFTTMywUA
# q7dCmryR9GNm4pjXGMm2sqkk+90k+cmvbydDedZwRqmdY8/ifTMAjAe7Tn6vEiFD
# E7iFkkwPIet5jiSGEHpEGaxl5gRCJTKtYgKUZ5Liur4mN38KJFEfpRp9CAuCxt4W
# Y88M
# SIG # End signature block
