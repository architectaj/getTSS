<#
.SYNOPSIS
	CRM module for collecting traces

.DESCRIPTION
	Define ETW traces for Windows CRM components 
	Add any custom tracing functinaliy for tracing CRM components
	For Developers:
	1. Component test: .\TSS.ps1 -Start -CRM_TEST1
	2. Scenario test: .\TSS.ps1 -start -Scenario CRM_MyScenarioTest

.NOTES
	Dev. Lead: Julien.Clauzel
	Authors    : Julien.Clauzel@microsoft.com; remib@microsoft.com
	Requires   : PowerShell V4 (Supported from Windows 8.1/Windows Server 2012 R2)
	Version    : see $global:TssVerDateCRM

.LINK
	TSS https://internal.evergreen.microsoft.com/en-us/help/4619187
	CRM https://internal.evergreen.microsoft.com/en-us/help/1234567
#>

<# latest changes (reverse chronological order)
::  2023.08.12.0 [we] replaced $CRM_DummyProviders with @()
::  2023.02.23.0 [we] upd psSDP for CRMbase; add CRM_IISdump scenario (tbd soon)
::  2023.02.21.0 [we] add FwGet-SummaryVbsLog for CRM_Platform
::  2023.02.18.0 [we] add CRM_Platform component and scenario
#>

#region --- Define local CRM Variables
$global:TssVerDateCRM= "2023.08.12.0"

#endregion --- Define local CRM Variables
#------------------------------------------------------------
#region --- ETW component trace Providers ---
#------------------------------------------------------------

#---  Dummy Providers ---# #for components without a tracing GUID
$CRM_DummyProviders = @(	#for components without a tracing GUID
	'{eb004a05-9b1a-11d4-9123-0050047759bc}' # Dummy tcp for switches without tracing GUID (issue #70)
)
$CRM_PlatformProviders = @()
$CRM_IISdumpProviders = @()
#endregion --- ETW component trace Providers ---


#------------------------------------------------------------
#region --- Scenario definitions ---
#------------------------------------------------------------
$CRM_General_ETWTracingSwitchesStatus = [Ordered]@{
	#'CommonTask NET' = $True  ## <------ the commontask can take one of "Dev", "NET", "ADS", "UEX", "DnD" and "SHA", or "Full" or "Mini"
	'NetshScenario InternetClient_dbg' = $true
	'Procmon' = $true
	'WPR General' = $true
	'PerfMon ALL' = $true
	'PSR' = $true
	'Video' = $true
	'SDP CRMBase' = $True
	'xray' = $True
	'CollectComponentLog' = $True
}

$CRM_Platform_ETWTracingSwitchesStatus = [Ordered]@{
	'CRM_Platform' = $true
	#'CommonTask NET' = $True
#	'NetshScenario InternetClient_dbg' = $true
#	'Procmon' = $true
#	'WPR General' = $true
#	'PerfMon ALL' = $true
	'PSR' = $true
	'Video' = $true
#	'SDP CRMbase' = $True
	'noBasicLog' = $true
	'xray' = $True
	'CollectComponentLog' = $True
}
$CRM_IISdump_ETWTracingSwitchesStatus = [Ordered]@{
	'CRM_IISdump' = $true
	#'CommonTask NET' = $True
#	'NetshScenario InternetClient_dbg' = $true
#	'Procmon' = $true
#	'WPR General' = $true
#	'PerfMon ALL' = $true
	'PSR' = $true
	'Video' = $true
#	'SDP CRMbase' = $True
	'noBasicLog' = $true
	'xray' = $True
	'CollectComponentLog' = $True
}

#endregion --- Scenario definitions ---

#region ### Pre-Start / Post-Stop / Collect functions for trace components and scenarios 
#------------------------------------------------------------
#--- Platform Trace ---#
function CRM_PlatformPreStart{
	EnterFunc $MyInvocation.MyCommand.Name
	LogInfo "enable Debug Registry settings for CMR Platform tracing."
	$RegPathMSCRM = "HKCU:\Software\Microsoft\MSCRMClient"
	if (Test-Path $RegPathMSCRM){
		$CRMRole = "Client"
		EnableCRMRegKeys -RegPathMSCRM $RegPathMSCRM -CRMRole $CRMRole
	}else{
		LogInfo "the reg key 'HKEY_CURRENT_USER\Software\Microsoft\MSCRMClient' was not found on this machine make sure this is the CRM client machine" "Gray"
	}
	$RegPathMSCRM = "HKLM:\Software\Microsoft\MSCRM"
	if (Test-Path $RegPathMSCRM ){
		$CRMRole = "Server"
		EnableCRMRegKeys -RegPathMSCRM $RegPathMSCRM -CRMRole $CRMRole
	}
	else{
		LogInfo "the reg key 'HKEY_LOCAL_MACHINE\Software\MICROSOFT\MSCRM'  was not found on this machine make sure this is the CRM server machine" "Gray"
	}
	LogInfo "see KB How to enable tracing in Microsoft Dynamics CRM https://support.microsoft.com/en-us/topic/how-to-enable-tracing-in-microsoft-dynamics-crm-818e8774-e123-4995-417d-7ea02395c6d0" "Cyan"
	EndFunc $MyInvocation.MyCommand.Name
}
function EnableCRMRegKeys{
	param(
		[String]$RegPathMSCRM,
		[String]$CRMRole
	)
	EnterFunc $MyInvocation.MyCommand.Name
	[int]$TraceEnabled = 1
	[int]$TraceCallStack = 1
	[string]$TraceCategories = "*:Verbose"
	[int]$TraceFileSizeLimit = 100
	$CRMCliSrv = get-Item -path $RegPathMSCRM
	$TraceRefresh = $CRMCliSrv.GetValue("TraceRefresh")
	if($null -ne $TraceRefresh){
		$TraceRefresh = $TraceRefresh + 1
	}else{
		$TraceRefresh = 1
	}
	switch($CRMRole){
		"Client" {
			$Global:TraceRefreshClient = $TraceRefresh
			$RegistryKey = "HKCU\Software\Microsoft\MSCRMClient"}
		"Server" {
			$Global:TraceRefreshServer = $TraceRefresh
			$RegistryKey = "HKLM\Software\Microsoft\MSCRM"}
	}
	FwAddRegValue "$RegistryKey" "TraceEnabled" "REG_DWORD" $TraceEnabled
	FwAddRegValue "$RegistryKey" "TraceCallStack" "REG_DWORD" $TraceCallStack 
	FwAddRegValue "$RegistryKey" "TraceFileSizeLimit" "REG_DWORD" $TraceFileSizeLimit 
	FwAddRegValue "$RegistryKey" "TraceRefresh" "REG_DWORD" $TraceRefresh
	FwAddRegValue "$RegistryKey" "TraceCategories"  "REG_SZ" $TraceCategories
	LogInfoFile "Platforms registry keys set at $RegistryKey"
	LogInfoFile "TraceEnabled      =$TraceEnabled"
	LogInfoFile "TraceCallStack    =$TraceCallStack"
	LogInfoFile "TraceRefresh      =$TraceRefresh"
	LogInfoFile "TraceCategories   =$TraceCategories"
	LogInfoFile "TraceFileSizeLimit=$TraceFileSizeLimit"
	EndFunc $MyInvocation.MyCommand.Name
}
function CRM_PlatformPostStop{
	EnterFunc $MyInvocation.MyCommand.Name
	#turn off client trace
	if (Test-Path "HKCU:\Software\Microsoft\MSCRMClient"){
		set-itemproperty -path "HKCU:\Software\Microsoft\MSCRMClient" -type DWORD -name "TraceEnabled" -value 0
		set-itemproperty -path "HKCU:\Software\Microsoft\MSCRMClient" -type DWORD -name "TraceRefresh" -value ($Global:TraceRefreshClient -1)
		LogInfo "Turned off CRM trace for Client"
	}
	#turn off server trace
	if (Test-Path "HKLM:\Software\Microsoft\MSCRM"){
		set-itemproperty -path "HKLM:\Software\Microsoft\MSCRM" -type DWORD -name "TraceEnabled" -value 0
		set-itemproperty -path "HKLM:\Software\Microsoft\MSCRM" -type DWORD -name "TraceRefresh" -value ($Global:TraceRefreshServer -1)
		LogInfo "Turned off CRM trace for Server"
		#Forcing tracing cache to update
		$installDir =(Get-ItemProperty HKLM:\Software\Microsoft\MSCRM).CRM_Server_InstallDir
		$xml = [xml](Get-Content "$($installDir)\CRMWeb\web.config")
		$xml.Save("$($installDir)\CRMWeb\web.config")
	}
	EndFunc $MyInvocation.MyCommand.Name
}
function CollectCRM_PlatformLog{
	EnterFunc $MyInvocation.MyCommand.Name
	# aka SDP: Get-CRMPlatformTrace
	[string]$Clientpath = ($Env:USERPROFILE + "\Local Settings\Application Data\Microsoft\MSCRM\Traces")
	[string]$Serverpath = ($Env:ProgramFiles + "\Microsoft Dynamics CRM\Trace")
	#get client logs
	LogInfo "The client path is being set to $($Clientpath)"
	if (Test-Path $Clientpath){
		$file_count = (dir $Clientpath).count
		LogInfo "There are $($file_count) files located in the $($Clientpath) folder"
		$Platformslogs = Get-ChildItem -Path $Clientpath -Filter *.log | Where-Object {$_.LastWriteTime -gt (Get-Date).AddDays(-1)} | Sort-Object -property @{Expression="LastWriteTime";Descending=$true}
		if ($null -ne $Platformslogs){
			LogInfo "Client: copying recent $($Platformslogs.count) log files from $($Clientpath)"
			$SourceDestinationPaths = New-Object 'System.Collections.Generic.List[Object]'
			$SourceDestinationPaths.add(@("$Platformslogs", "$global:LogFolder" ))
			FwCopyFiles $SourceDestinationPaths -ShowMessage:$False
		}
	}else{ LogInfo "Path $Clientpath not found on this machine" "Magenta"}
	#get server logs
	LogInfo "The server path is being set to $($Serverpath)"
	if (Test-Path $Serverpath){
		$file_count = (dir $Serverpath).count
		LogInfo "There are $($file_count) files located in the $($Serverpath) folder"
		$ServerPlatformslogs = Get-ChildItem -Path $Serverpath -Filter *.log | Where-Object {$_.LastWriteTime -gt (Get-Date).AddDays(-1)} | Sort-Object -property @{Expression="LastWriteTime";Descending=$true}
		if ($null -ne $ServerPlatformslogs){
			LogInfo "Server: copying recent $($ServerPlatformslogs.count) *.log files from $($Serverpath)"
			$SourceDestinationPaths = New-Object 'System.Collections.Generic.List[Object]'
			$SourceDestinationPaths.add(@("$ServerPlatformslogs", "$global:LogFolder"))
			FwCopyFiles $SourceDestinationPaths -ShowMessage:$False
		}
	}else{ LogInfo "Path $Serverpath not found on this machine" "Magenta"}
	FwGet-SummaryVbsLog
	EndFunc $MyInvocation.MyCommand.Name
}

#--- CRM IIS dump ---#
function CRM_IISdumpPreStart{
	EnterFunc $MyInvocation.MyCommand.Name
	LogInfo "...Not implemented - Coming soon" "Cyan"
	EndFunc $MyInvocation.MyCommand.Name
}
function CollectCRM_IISdumpLog{
	EnterFunc $MyInvocation.MyCommand.Name
	LogInfo "...Not implemented - Coming soon" "Cyan"
	EndFunc $MyInvocation.MyCommand.Name
}

#endregion ### Pre-Start / Post-Stop / Collect functions for trace components and scenarios 

#region Registry Key modules for FwAddRegItem
	<# Example:
	$global:KeysHyperV = @("HKLM:Software\Microsoft\Windows NT\CurrentVersion\Virtualization", "HKLM:System\CurrentControlSet\Services\vmsmp\Parameters")
	#>
#endregion Registry Key modules

#region groups of Eventlogs for FwAddEvtLog
	<# Example:
	$global:EvtLogsEFS		= @("Microsoft-Windows-NTFS/Operational", "Microsoft-Windows-NTFS/WHC")
	#>
#endregion groups of Eventlogs

Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *
# SIG # Begin signature block
# MIIoLQYJKoZIhvcNAQcCoIIoHjCCKBoCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAdE3cKTN9/+M2T
# epPc2Q7Ce6vCJnPzisMvSrlpKuo78KCCDXYwggX0MIID3KADAgECAhMzAAADrzBA
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
# /Xmfwb1tbWrJUnMTDXpQzTGCGg0wghoJAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAOvMEAOTKNNBUEAAAAAA68wDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINAFFeJPHF3bWJAHEbd35ZnL
# y+q9dFOdp0qEhCMjhXXbMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAlo2oSxiUhLmboL45t7a3AFQIE6UIsDX66UPYbvUCn+5orhVcMJU4qXnl
# 6YgMpHdmgIswI9iyYFEIHrHOQdhmFh5fZYxN/zwHachXK+okxtHw3I90zR+qjqEJ
# RjmOadGM7Fsjsb9wP1ZQ+ZVGlfbKIpryk54iBNA+qtNntYyrnX1EewnUWLvrc7SZ
# JgIfqv+OaEzIkyJRqWzaxqGR07lm8PBoteTvrd0JWgyZparnX92B3LZdWp3CG2UQ
# 1Q5zu6bWwDFOgfA1y36XymAWeymuwNybAfGqmxkEa4hEnyMCcEkkDEqv0CkR4QLL
# Q+iF31EVCrwsm6dtitvQSqYyYGBwXaGCF5cwgheTBgorBgEEAYI3AwMBMYIXgzCC
# F38GCSqGSIb3DQEHAqCCF3AwghdsAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsq
# hkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCCP2V0T+5OHp0mlIXbHrROPam75Ehxe4G9DhESRmU/YqgIGZc5B3VFa
# GBMyMDI0MDIyMDEyMTU1Mi44OTFaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046RjAwMi0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wg
# ghHtMIIHIDCCBQigAwIBAgITMwAAAfI+MtdkrHCRlAABAAAB8jANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yMzEyMDYxODQ1
# NThaFw0yNTAzMDUxODQ1NThaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25z
# MScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046RjAwMi0wNUUwLUQ5NDcxJTAjBgNV
# BAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQC85fPLFwppYgxwYxkSEeYvQBtnYJTtKKj2FKxzHx0f
# gV6XgIIrmCWmpKl9IOzvOfJ/k6iP0RnoRo5F89Ad29edzGdlWbCj1Qyx5HUHNY8y
# u9ElJOmdgeuNvTK4RW4wu9iB5/z2SeCuYqyX/v8z6Ppv29h1ttNWsSc/KPOeuhzS
# AXqkA265BSFT5kykxvzB0LxoxS6oWoXWK6wx172NRJRYcINfXDhURvUfD70jioE9
# 2rW/OgjcOKxZkfQxLlwaFSrSnGs7XhMrp9TsUgmwsycTEOBdGVmf1HCD7WOaz5EE
# cQyIS2BpRYYwsPMbB63uHiJ158qNh1SJXuoL5wGDu/bZUzN+BzcLj96ixC7wJGQM
# BixWH9d++V8bl10RYdXDZlljRAvS6iFwNzrahu4DrYb7b8M7vvwhEL0xCOvb7WFM
# sstscXfkdE5g+NSacphgFfcoftQ5qPD2PNVmrG38DmHDoYhgj9uqPLP7vnoXf7j6
# +LW8Von158D0Wrmk7CumucQTiHRyepEaVDnnA2GkiJoeh/r3fShL6CHgPoTB7oYU
# /d6JOncRioDYqqRfV2wlpKVO8b+VYHL8hn11JRFx6p69mL8BRtSZ6dG/GFEVE+fV
# mgxYfICUrpghyQlETJPITEBS15IsaUuW0GvXlLSofGf2t5DAoDkuKCbC+3VdPmlY
# VQIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFJVbhwAm6tAxBM5cH8Bg0+Y64oZ5MB8G
# A1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCG
# Tmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUy
# MFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4w
# XAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwG
# A1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQD
# AgeAMA0GCSqGSIb3DQEBCwUAA4ICAQA9S6eO4HsfB00XpOgPabcN3QZeyipgilcQ
# SDZ8g6VCv9FVHzdSq9XpAsljZSKNWSClhJEz5Oo3Um/taPnobF+8CkAdkcLQhLdk
# Shfr91kzy9vDPrOmlCA2FQ9jVhFaat2QM33z1p+GCP5tuvirFaUWzUWVDFOpo/O5
# zDpzoPYtTr0cFg3uXaRLT54UQ3Y4uPYXqn6wunZtUQRMiJMzxpUlvdfWGUtCvnW3
# eDBikDkix1XE98VcYIz2+5fdcvrHVeUarGXy4LRtwzmwpsCtUh7tR6whCrVYkb6F
# udBdWM7TVvji7pGgfjesgnASaD/ChLux66PGwaIaF+xLzk0bNxsAj0uhd6QdWr6T
# T39m/SNZ1/UXU7kzEod0vAY3mIn8X5A4I+9/e1nBNpURJ6YiDKQd5YVgxsuZCWv4
# Qwb0mXhHIe9CubfSqZjvDawf2I229N3LstDJUSr1vGFB8iQ5W8ZLM5PwT8vtsKEB
# wHEYmwsuWmsxkimIF5BQbSzg9wz1O6jdWTxGG0OUt1cXWOMJUJzyEH4WSKZHOx53
# qcAvD9h0U6jEF2fuBjtJ/QDrWbb4urvAfrvqNn9lH7gVPplqNPDIvQ8DkZ3lvbQs
# Yqlz617e76ga7SY0w71+QP165CPdzUY36et2Sm4pvspEK8hllq3IYcyX0v897+X9
# YeecM1Pb1jCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZI
# hvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# MjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAy
# MDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
# AQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25Phdg
# M/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPF
# dvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6
# GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBp
# Dco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50Zu
# yjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3E
# XzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0
# lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1q
# GFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ
# +QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PA
# PBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkw
# EgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxG
# NSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARV
# MFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAK
# BggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMC
# AYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvX
# zpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20v
# cGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYI
# KwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG
# 9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0x
# M7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmC
# VgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449
# xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wM
# nosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDS
# PeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2d
# Y3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxn
# GSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+Crvs
# QWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokL
# jzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL
# 6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNQ
# MIICOAIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEn
# MCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOkYwMDItMDVFMC1EOTQ3MSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQBr
# i943cFLH2TfQEfB05SLICg74CKCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA6X6vBjAiGA8yMDI0MDIyMDA0NTQz
# MFoYDzIwMjQwMjIxMDQ1NDMwWjB3MD0GCisGAQQBhFkKBAExLzAtMAoCBQDpfq8G
# AgEAMAoCAQACAgoxAgH/MAcCAQACAhLrMAoCBQDpgACGAgEAMDYGCisGAQQBhFkK
# BAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJ
# KoZIhvcNAQELBQADggEBADjmsKoWqFgl2ggUpXEu0AaGTjrURyjBw4+ipI43o/AF
# y9eAayTEypM6XSh/5m18JEVpYnpLQ49h+8ZS05I/hByhx/NATJPqcTyaSn7MwZFy
# kdNm84XNC7KwI/hZrtQD59wHJRIu6EIDPjrNaNj9zLk/eAcsuxgALpPYOW5DUCkb
# d8iqag5pHKWIrnCFyAfRdC550YIJcQlFs0S9DK1a5/fki9KgJ68xL1v9XTh/ssaN
# RjIg6ky55eQY3/OZv/d5ap/yg1veZzdr977YueAqyvLKib27YlArxLwuWPTzx50Q
# zMrtFLg+CdHINLfINLCJ19x/chODkt3FeFvukgXbwlsxggQNMIIECQIBATCBkzB8
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1N
# aWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAfI+MtdkrHCRlAABAAAB
# 8jANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEE
# MC8GCSqGSIb3DQEJBDEiBCBBYOUnTZzXQ+Ghq8jVvQaNhWVM4yeWANutSO9UdaFY
# vzCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIPjaPh0uMVJc04+Y4Ru5BUUb
# HE4suZ6nRHSUu0XXSkNEMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTACEzMAAAHyPjLXZKxwkZQAAQAAAfIwIgQgnwIZ6TTIjEVTkaVgIxqL1g47
# XN46/ceOIBNP4Pu99h4wDQYJKoZIhvcNAQELBQAEggIAi/pXp/rycaXtfXqMDL6p
# 4s5IRopb7Sn+5kOq7evGwMVDLnnDGCKvM7CVSw89eOKKg/z5kJViRJGCS6wrw6XF
# nbtBDyfdphpcUYBGeuuE5y5XMZMO2I/lItoBAcyjXoYgKiJcnOuycswzzDnHLVWM
# M9VjfzHHy4IX0fEBvzpwXe8GrSHzUCR512R+6L4rxec7hiHUdP5Nt5vfgJOgOgvZ
# S2F/C47RxcV0KYwlzKKXUasABx3ObbJAnibUwrC5O5hIbIWdiA7H9Ufkexx4m6JW
# a6xEFTRVUWI/xEFcbPhsOE3oYwT+AdQHKddM+3UD7o7TkePmSx2Ysv/ev09b1p6J
# 7GaHo76ZJWCyWNrac6KrgLceDj1tBNKO5SnrraMaADQR2d/K83QIOQN5dRCBg6zV
# CoFUbLFrPl70SN34gZPXBb3YBab346LyRH4BuPypK1ClagOsmykAJhvLpdAzLoVr
# DEYHP7GQGmBpgqEoWwRDBE8cqF+DuhXvUOCS76mUL0wXvP7Rqp5nke+RB5u9ygkZ
# tiGnXcCO5eRFZqGbSwFAaK6MxVlkSPVFqfxmVwqzhqAE3rwJj/piFMgXJetbhisx
# Yq3jia5q1YykbypoygCi2xKy0hCp0eBGzQRGO0Un5eUdRkkJq1/Rk9DU3bJVIYJ3
# BCt60wWomTwSLXIPZPZ2Qng=
# SIG # End signature block
