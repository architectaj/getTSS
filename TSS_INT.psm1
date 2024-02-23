<#
.SYNOPSIS
	Biztalk Integration module for collecting traces

.DESCRIPTION
	Define ETW traces for Windows Biztalk Integration components 
	Add any custom tracing functinaliy for tracing Biztalk components
	For Developers:
	1. Component test: .\TSS.ps1 -Start -INT_TEST1
	2. Scenario test: .\TSS.ps1 -start -Scenario INT_MyScenarioTest

.NOTES
	Dev. Lead: niklase
	Authors	 : Niklas Engfelt <niklase@microsoft.com>
	Requires   : PowerShell V4 (Supported from Windows 8.1/Windows Server 2012 R2)
	Version    : see $global:TssVerDateINT

.LINK
	TSS https://internal.evergreen.microsoft.com/en-us/help/4619187
	INT https://internal.evergreen.microsoft.com/en-us/help/1234567 -todo
#>

<# latest changes (reverse chronological order)
::	2023.02.22.0 [we] add INT_MSMQ component and scenario
#>

#region --- Define local INT Variables
$global:TssVerDateINT= "2023.02.23.0"

$BinArch = "\Bin" + $global:ProcArch
$global:TMQexePath = $global:ScriptFolder + $BinArch + "\TMQ.exe"
#endregion --- Define local INT Variables

#------------------------------------------------------------
#region --- ETW component trace Providers ---
#------------------------------------------------------------

#---  Dummy Providers ---# #for components without a tracing GUID


#---  MSMQ Providers ---#
$INT_MSMQProviders = @(
	'{CE18AF71-5EFD-4F5A-9BD5-635E34632F69}' # Microsoft-Windows-MSMQ
	'{2787CC62-2654-4227-9B35-B53F838507AE}' # Microsoft-Windows-MSMQTriggers
	'{45033C79-EA31-4776-9BCD-94DB89AF3149}' # MSMQ: General
	'{322E0B22-0527-456E-A5EF-E5B591046A63}' # MSMQ: AC
	'{6E2C0612-BCF3-4028-8FF2-C60C288F1AF3}' # MSMQ: Networking
	'{DA1AF236-FAD6-4DA6-BD94-46395D8A3CF5}' # MSMQ: SRMP
	'{F8354C74-DE9F-48A5-8139-4ED1E9F20A1B}' # MSMQ: RPC
	'{5DC62C8C-BDF2-45A1-A06F-0C38CD5AF627}' # MSMQ: DS
	'{90E950BB-6ACE-4676-98E0-F6CDC1403670}' # MSMQ: Security
	'{8753D150-950B-4774-AC14-9C6CBFF56A50}' # MSMQ: Routing
	'{8FDA2BBD-347E-493C-B7D1-6B6FED88CE04}' # MSMQ: XACT_General
	'{485C37B0-9A15-4A2E-82E0-8E8C3A7B8234}' # MSMQ: XACT_Send
	'{7C916009-CF80-408B-9D91-9C2960118BE9}' # MSMQ: XACT_Receive
	'{1AC9B316-5B4E-4BBD-A2C9-1E70967A6FE1}' # MSMQ: XACT_Log
	'{A13EC7BB-D592-4B93-80DA-C783F9708BD4}' # MSMQ: Log
	'{71625F6D-559A-49C6-BA21-0AEB260DB97B}' # MSMQ: Profiling
	'{F707F440-AD58-47F8-93D3-BEA2F9E82FD2}' # MSMQ: ERRORLOGGING
)
#endregion --- ETW component trace Providers ---


#------------------------------------------------------------
#region --- Scenario definitions ---
#------------------------------------------------------------
$INT_General_ETWTracingSwitchesStatus = [Ordered]@{
	#'INT_Dummy' = $true
	#'CommonTask NET' = $True  ## <------ the commontask can take one of "Dev", "NET", "ADS", "UEX", "DnD" and "SHA", or "Full" or "Mini"
	'NetshScenario InternetClient_dbg' = $true
	'Procmon' = $true
	'WPR General' = $true
	'PerfMon ALL' = $true
	'PSR' = $true
	'Video' = $true
	'SDP Net' = $True
	'xray' = $True
	'CollectComponentLog' = $True
}

$INT_MSMQ_ETWTracingSwitchesStatus = [Ordered]@{
	'INT_MSMQ' = $true
	'CommonTask INT' = $True
#	'NetshScenario InternetClient_dbg' = $true
#	'Procmon' = $true
#	'WPR General' = $true
#	'PerfMon ALL' = $true
	'PSR' = $true
	'Video' = $true
#	'SDP Net' = $True
#	'noBasicLog' = $true
	'xray' = $True
	'CollectComponentLog' = $True
}
#endregion --- Scenario definitions ---

#region ### Pre-Start / Post-Stop / Collect functions for trace components and scenarios 
#------------------------------------------------------------
#--- Platform Trace ---#
function INT_MSMQPreStart{
	EnterFunc $MyInvocation.MyCommand.Name
	#noop
	EndFunc $MyInvocation.MyCommand.Name
}
function INT_MSMQPostStop{
	EnterFunc $MyInvocation.MyCommand.Name
	#noop
	EndFunc $MyInvocation.MyCommand.Name
}
function CollectINT_MSMQLog{
	EnterFunc $MyInvocation.MyCommand.Name
	FwAddRegItem @("MSMQ") _Stop_
	LogInfo "[$($MyInvocation.MyCommand.Name)] collecting MSMQInfo at $TssPhase"
	$outFile = $PrefixTime + "MSMQInfo" + $TssPhase + ".txt"
	$Commands = @(
		"Get-WindowsFeature | ? Name -match `"msmq`" | ft -AutoSize | Out-File -Append $outFile"
		"Get-WindowsOptionalFeature -Online | ? FeatureName -match `"msmq`" | select FeatureName,State | ft -AutoSize | Out-File -Append $outFile"
		"Get-WinSystemLocale | Out-File -Append $outFile"
		"Get-WinUserLanguageList | Out-File -Append $outFile"
		"(dir C:\windows\system32\mqqm.dll).VersionInfo | fl | Out-File -Append $outFile"
		"(dir C:\windows\system32\drivers\mqac.sys).VersionInfo | fl | Out-File -Append $outFile"
		"(Get-Acl 'HKLM:\Software\Microsoft\MSMQ').Access | fl | Out-File -Append $outFile"
		"(Get-Acl 'C:\Windows\System32\MSMQ').Access | fl | Out-File -Append $outFile"
	)
	RunCommands $LogPrefix $Commands -ThrowException:$False -ShowMessage:$False

	If($IsServerSKU){
		if (Get-WindowsFeature | Where-Object {($_.Name -eq "RSAT-AD-PowerShell") -and ($_.installed -eq $true)}){
			LogInfo "RSAT AD tools are installed" "Green"
			$fRSATinst=$True
		}else{ 
			LogWarn "[$($MyInvocation.MyCommand.Name)] RSAT AD tools are missing. 'RSAT-AD-PowerShell' module is not installed."
			LogInfo "Please run: Install-WindowsFeature RSAT-AD-PowerShell" "Cyan"
		}
	} else {
		If($OSBuild -ge 9200) {
			if (Get-WindowsOptionalFeature -Online | Where-Object {($_.Name -eq "RSAT-AD-PowerShell") -and ($_.installed -eq $true)}){
				LogInfo "RSAT AD tools are installed" "Green"
				$fRSATinst=$True
			}else{ 
				LogWarn "[$($MyInvocation.MyCommand.Name)] RSAT AD tools are missing."
				LogInfo "Please run:`
		Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
		Import-Module -Name ActiveDirectory" "Cyan"
			}
		}
	}
	If($fRSATinst -eq "True"){
		# Get local computer object
		$cnObj = Get-ADComputer -Identity $env:COMPUTERNAME
		$ou = $cnObj.DistinguishedName		  # $ou = (Get-ADComputer $env:COMPUTERNAME).DistinguishedName	# $ou = "CN=MYCOMPUTERxxxx,CN=Computers,DC=mydomain,DC=local"
		$outFile = $PrefixTime + "MSMQ.Computer.objects" + $TssPhase + ".txt"
		$Commands = @(
			"AD-object properties: $ou | Out-File -Append $outFile"
			"Get-ADObject -Identity $ou -Properties * | fl | Out-File -Append $outFile"
			"Get-ADObject -Identity `"CN=msmq,$ou`" -Properties * | fl | Out-File -Append $outFile"
			)
		RunCommands $LogPrefix $Commands -ThrowException:$False -ShowMessage:$False
	}
	FwGet-SummaryVbsLog
	getTMQinfo
	EndFunc $MyInvocation.MyCommand.Name
}
#endregion ### Pre-Start / Post-Stop / Collect functions for trace components and scenarios 

#region --- HelperFunctions ---
function INT_start_common_tasks {
	#collect info for all tss runs at _Start_
	EnterFunc $MyInvocation.MyCommand.Name
	LogDebug "___switch Mini: $global:Mini" "cyan"
	if ($global:Mini -ne $true) {
		#LogInfoFile "PATH: $Env:Path"
		FwGetSysInfo _Start_
		FwGetSVC _Start_
		FwGetSVCactive _Start_ 
		FwGetTaskList _Start_
		FwGetSrvWkstaInfo _Start_
		FwGetNltestDomInfo _Start_
		FwGetKlist _Start_ 
		FwGetBuildInfo
		if ($global:noClearCache -ne $true) { FwClearCaches _Start_ } else { LogInfo "[$($MyInvocation.MyCommand.Name) skip FwClearCaches" }
		FwGetRegList _Start_
		FwGetPoolmon _Start_
		FwGetSrvRole
	}
	FwGetLogmanInfo _Start_
	LogInfoFile "___ INT_start_common_tasks DONE"
	EndFunc $MyInvocation.MyCommand.Name
}
function INT_stop_common_tasks {
	#collect info for all tss runs at _Stop_
	EnterFunc $MyInvocation.MyCommand.Name
	if ($global:Mini -ne $true) {
		FwGetDFScache _Stop_
		FwGetSVC _Stop_
		FwGetSVCactive _Stop_ 
		FwGetTaskList _Stop_
		FwGetKlist _Stop_
		FwGetWhoAmI _Stop_
		FwGetDSregCmd
		FwGetHotfix
		FwGetPoolmon _Stop_
		FwGetLogmanInfo _Stop_
		FwGetNltestDomInfo _Stop_
		FwListProcsAndSvcs _Stop_
		FwGetRegList _Stop_
		writeTesting "___ FwGetEvtLogList"
		("System", "Application") | ForEach-Object { FwAddEvtLog $_ _Stop_}
		FwGetEvtLogList _Stop_
	}
	FwGetSrvWkstaInfo _Stop_
	FwGetRegHives _Stop_
	FwCopyMemoryDump -DaysBack 2
	LogInfoFile "___ INT_stop_common_tasks DONE"
	EndFunc $MyInvocation.MyCommand.Name
}

function getTMQinfo{
	param(
		[Parameter(Mandatory=$False)]
		[String]$TssPhase = $global:TssPhase				# _Start_ or _Stop_
	)
	EnterFunc ($MyInvocation.MyCommand.Name + " at $TssPhase")
	if (!$global:IsLiteMode){
		if (Test-Path $global:TMQexePath){
			LogInfo "[$($MyInvocation.MyCommand.Name)] collecting TMQ.exe info at $TssPhase"
			$ClusterServiceKey="HKLM:\SYSTEM\CurrentControlSet\Services\ClusDisk"
			if (Test-Path $ClusterServiceKey){
				#In case of clustered MSMQ, we need to know the MSMQ cluster name (perhaps as optional input -clustername {MSMQClusteredServiceName} ), or if more advanced get all clustered resources and check if of type MSMQ and then issue following commands per MSMQ resource found. 
				$MSMQClusteredServiceName = Read-Host -Prompt "Please enter the MSMQClusteredServiceName, or hit ENTER to skip this step"
				LogInfoFile "[MSMQClusteredServiceName: User provided answer:] $MSMQClusteredServiceName"
				If(!([String]::IsNullOrEmpty($MSMQClusteredServiceName))) {
					$Commands = @(
						"$global:TMQexePath  state -s $MSMQClusteredServiceName -v -f -r | Out-File $PrefixTime`TMQ-state-cluster.txt"
						"$global:TMQexePath  site -s $MSMQClusteredServiceName -v -d | Out-File -Append $PrefixTime`TMQ-site-cluster.txt"
						"$global:TMQexePath  store -d -v -s $MSMQClusteredServiceName | Out-File -Append $PrefixTime`TMQ-store-cluster.txt"
					)
				}
			}else{
				$outFile = $PrefixTime + "tmqstate" + $TssPhase + ".txt"
				$Commands = @(
					"$global:TMQexePath  state -d -v | Out-File -Append $outFile"
					"$global:TMQexePath  site -d -v | Out-File -Append $outFile"
					"$global:TMQexePath  store -d -v | Out-File -Append $outFile"
				)
			}
			if($Commands){RunCommands $LogPrefix $Commands -ThrowException:$False -ShowMessage:$False}
		}else{LogWarn "[$($MyInvocation.MyCommand.Name)] 'TMQ.exe' not found in PATH"}
	}else{ LogInfo "Skipping TMQ.exe info in Lite mode"}
	EndFunc $MyInvocation.MyCommand.Name
}
#endregion --- HelperFunctions ---

#region Registry Key modules for FwAddRegItem
	$global:KeysMSMQ = @("HKLM:Software\Microsoft\MSMQ")
#endregion Registry Key modules

#region groups of Eventlogs for FwAddEvtLog
	<# Example:
	$global:EvtLogsEFS		= @("Microsoft-Windows-NTFS/Operational", "Microsoft-Windows-NTFS/WHC")
	#>
#endregion groups of Eventlogs

Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *
# SIG # Begin signature block
# MIInzgYJKoZIhvcNAQcCoIInvzCCJ7sCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAV3e2kuEOckKhe
# NsVSUNHULWAqUHoEUzCnrqBFxYNXW6CCDYUwggYDMIID66ADAgECAhMzAAADri01
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
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIKQS
# AiLTXGYFzmudpRJqAu6wIcZon+plG7ECnE7gmkUcMEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEAW59UYXgPIDeQyJGPHp7OJ8aUOXQTt1UYUfZq
# 0gZAkO/bvrtnXpaXFtsuHuAl/Z4zASCol34se6c9rB/39CcvFfENDOuIb4Fm9rxp
# vCyurV38ltx4UgAPm0gUJovC8hoc31xBIerHpvS1umUT4MGUR16/rwZ2EYDSVMS4
# V7qxvJskLyaBEXjGf20ei65w1ooKH+WSgnAEIW+7p9+hhTsrdEDxUY5vuepnrmzL
# bEY0OxU3pdtHUzMwUzzWFkiFEeq2e7IwauLbPZLcrvZOs1gUIwWKjmPusO5g8I5X
# tcrCtE08UCCSy+H7xyZZli4qRTHKArmKD/wrZP9IFp9+caWoKaGCFykwghclBgor
# BgEEAYI3AwMBMYIXFTCCFxEGCSqGSIb3DQEHAqCCFwIwghb+AgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFZBgsqhkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCAEeuvGtE5VTOiGyPZXxvXFBcuHp2rcdGEt
# XSlv4+T7OgIGZbqk2qVTGBMyMDI0MDIyMDEyMTU1NS43NzNaMASAAgH0oIHYpIHV
# MIHSMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQL
# EyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsT
# HVRoYWxlcyBUU1MgRVNOOjNCRDQtNEI4MC02OUMzMSUwIwYDVQQDExxNaWNyb3Nv
# ZnQgVGltZS1TdGFtcCBTZXJ2aWNloIIReDCCBycwggUPoAMCAQICEzMAAAHlj2rA
# 8z20C6MAAQAAAeUwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# UENBIDIwMTAwHhcNMjMxMDEyMTkwNzM1WhcNMjUwMTEwMTkwNzM1WjCB0jELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9z
# b2Z0IElyZWxhbmQgT3BlcmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjozQkQ0LTRCODAtNjlDMzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAKl7
# 4Drau2O6LLrJO3HyTvO9aXai//eNyP5MLWZrmUGNOJMPwMI08V9zBfRPNcucreIY
# SyJHjkMIUGmuh0rPV5/2+UCLGrN1P77n9fq/mdzXMN1FzqaPHdKElKneJQ8R6cP4
# dru2Gymmt1rrGcNe800CcD6d/Ndoommkd196VqOtjZFA1XWu+GsFBeWHiez/Pllq
# cM/eWntkQMs0lK0zmCfH+Bu7i1h+FDRR8F7WzUr/7M3jhVdPpAfq2zYCA8ZVLNgE
# izY+vFmgx+zDuuU/GChDK7klDcCw+/gVoEuSOl5clQsydWQjJJX7Z2yV+1KC6G1J
# VqpP3dpKPAP/4udNqpR5HIeb8Ta1JfjRUzSv3qSje5y9RYT/AjWNYQ7gsezuDWM/
# 8cZ11kco1JvUyOQ8x/JDkMFqSRwj1v+mc6LKKlj//dWCG/Hw9ppdlWJX6psDesQu
# QR7FV7eCqV/lfajoLpPNx/9zF1dv8yXBdzmWJPeCie2XaQnrAKDqlG3zXux9tNQm
# z2L96TdxnIO2OGmYxBAAZAWoKbmtYI+Ciz4CYyO0Fm5Z3T40a5d7KJuftF6CTocc
# c/Up/jpFfQitLfjd71cS+cLCeoQ+q0n0IALvV+acbENouSOrjv/QtY4FIjHlI5zd
# JzJnGskVJ5ozhji0YRscv1WwJFAuyyCMQvLdmPddAgMBAAGjggFJMIIBRTAdBgNV
# HQ4EFgQU3/+fh7tNczEifEXlCQgFOXgMh6owHwYDVR0jBBgwFoAUn6cVXQBeYl2D
# 9OXSZacbUzUZ6XIwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3Nv
# ZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUy
# MDIwMTAoMSkuY3JsMGwGCCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDov
# L3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1l
# LVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUB
# Af8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQAD
# ggIBADP6whOFjD1ad8GkEJ9oLBuvfjndMyGQ9R4HgBKSlPt3pa0XVLcimrJlDnKG
# gFBiWwI6XOgw82hdolDiMDBLLWRMTJHWVeUY1gU4XB8OOIxBc9/Q83zb1c0RWEup
# gC48I+b+2x2VNgGJUsQIyPR2PiXQhT5PyerMgag9OSodQjFwpNdGirna2rpV23EU
# wFeO5+3oSX4JeCNZvgyUOzKpyMvqVaubo+Glf/psfW5tIcMjZVt0elswfq0qJNQg
# oYipbaTvv7xmixUJGTbixYifTwAivPcKNdeisZmtts7OHbAM795ZvKLSEqXiRUjD
# YZyeHyAysMEALbIhdXgHEh60KoZyzlBXz3VxEirE7nhucNwM2tViOlwI7EkeU5hu
# dctnXCG55JuMw/wb7c71RKimZA/KXlWpmBvkJkB0BZES8OCGDd+zY/T9BnTp8si3
# 6Tql84VfpYe9iHmy7PqqxqMF2Cn4q2a0mEMnpBruDGE/gR9c8SVJ2ntkARy5Sflu
# uJ/MB61yRvT1mUx3lyppO22ePjBjnwoEvVxbDjT1jhdMNdevOuDeJGzRLK9HNmTD
# C+TdZQlj+VMgIm8ZeEIRNF0oaviF+QZcUZLWzWbYq6yDok8EZKFiRR5otBoGLvaY
# FpxBZUE8mnLKuDlYobjrxh7lnwrxV/fMy0F9fSo2JxFmtLgtMIIHcTCCBVmgAwIB
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
# aGFsZXMgVFNTIEVTTjozQkQ0LTRCODAtNjlDMzElMCMGA1UEAxMcTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIaAxUA942iGuYFrsE4wzWD
# d85EpM6RiwqggYMwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAN
# BgkqhkiG9w0BAQUFAAIFAOl+1LMwIhgPMjAyNDAyMjAxNTM1MTVaGA8yMDI0MDIy
# MTE1MzUxNVowdDA6BgorBgEEAYRZCgQBMSwwKjAKAgUA6X7UswIBADAHAgEAAgIN
# ZjAHAgEAAgISOzAKAgUA6YAmMwIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEE
# AYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GB
# AIpysElI0/XLRqOKmHo+m227xCEZtsr/3xLd/MV1hK6hl5Jmie8e9Qv//8ogOpWk
# qJH3Z0oNgrww/WWmI0RPhbWqweaZQjErzifgKTJqlztZyiIIs3pUxlUz2LHwPi8B
# XHUtQWd4apjcbMetANVp6gvB/SBOUw3wHemGQcpOkg6RMYIEDTCCBAkCAQEwgZMw
# fDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMd
# TWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAHlj2rA8z20C6MAAQAA
# AeUwDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRAB
# BDAvBgkqhkiG9w0BCQQxIgQgOWdCu68V9X4A+aCGIPMSSwT23yoMEMQurjd8DpPs
# NAowgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCAVqdP//qjxGFhe2YboEXeb
# 8I/pAof01CwhbxUH9U697TCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwAhMzAAAB5Y9qwPM9tAujAAEAAAHlMCIEIBsAbimdI+ye2UIiP0NL+ZRH
# oPI3NgLOHJjAAqJlKaGwMA0GCSqGSIb3DQEBCwUABIICAAUGbGgKcH580+QpKC88
# +cgS4lp+oUa2PS2+/rzoIVPLfnhFeeYI5qiwJ6jdXY55wALR5lQwwZxtdnKSuxoB
# gu1etnpY4TcAlegIRa4A4aw9VMB2TQSxLASN/wb7xE48TkeZwRxEy0kHEwOvlx2b
# KvAVig78+LQt5Xiflv5ZluzXoDeuCj4tu7IH42i/AkSCSSBatWIgZtfHCBlxXvDv
# WUxXg4/EvsosD0I/wFZ/+1djyeWozl5SbTISzA4BW1Ngjv15PYJZpWudVX+eXfJR
# EWyXM1M18WRfOsbuydOpYVfgGOhCPVof55WuSiKxROWW3+TpP6n+KWzFl5UgjvSi
# y4H2N7wwkJDbpERr3eEBC4e02V+K4G+O6Zrfb9grIp7wG0FYSJ2grle6Z0fkXo9u
# HLhCTJPmh/AmWdKO9WZYD0BcNS/tuuWMh8geMCtW6icp06HlymwNoMVh3lldcnt4
# QT6/odqukw9iBTsHZJ2R8BOmH1izfQsjar3Un+jU57IKe/B0YD/07m0MlRnky+Tw
# wfwd+9d5OCYUbdzN+Kvo1r9te91fOHg8MDy3URPPwTIxmsOl5Epc2w08Yw2J0jR/
# wXwnBQ9mBwfsJVfZTapMzUopgGzSB3otqHxV/SLreVmUHwWsLDW9BXEQLaUWwSXQ
# CEF0LLOvWI4EjoNfOdAF5wio
# SIG # End signature block
