<# Script name: tss_WorkFoldersDiag.ps1

#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  
# THIS SAMPLE CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
# WHETHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
# IF THIS CODE AND INFORMATION IS MODIFIED, THE ENTIRE RISK OF USE OR RESULTS IN
# CONNECTION WITH THE USE OF THIS CODE AND INFORMATION REMAINS WITH THE USER. 
#
# Author:
#     Anu Raghavan (araghav) - August, 2013
# Version: 8.1
#>

#region ::::: Script Input PARAMETERS :::::
[CmdletBinding()]param(
  [Parameter(Mandatory=$true, Position=0)] [String] $DataPath,
  [Parameter(Mandatory=$false, Position=1)] [Switch] $AdvancedMode = $false,
  [Parameter(Mandatory=$false, Position=2)] [Int] $TraceLevel = 255,
  [Parameter(Mandatory=$false, Position=3)] [Switch] $Cleanup = $false,
  [Parameter(Mandatory=$false, Position=4)] [Switch] $RunTrace = $false,
  [Parameter(Mandatory)]
  [ValidateSet("Start","Stop")]
  [string]$Stage
)
$ScriptVer="22.02.04"	#Date: 2022-02-04
$OutputDirectory = $DataPath
$LogSeparator = '################################################################################################################'
#endregion ::::: Script Input PARAMETERS :::::

function Get-EventsTxt($EventLog, $OutFile)
# SYNOPSIS: extract Eventlog content in TXT format
{	$Events = Get-WinEvent $EventLog -MaxEvents 300 -ErrorAction SilentlyContinue
    if($null -eq $Events)
    {   # Error occurred - do nothing
	    Write-Host ' $EventLog : No event log entries found.'
    }
    else
    {   'Number of event log entries collected: ' + $Events.Count | Out-File $OutFile
	    foreach($Event in $Events)
	    {   $LogSeparator | Out-File $OutFile -append
		    $Event | Out-File $OutFile -append
		    'Full message:' | Out-File $OutFile -append
		    $Event.Message | Out-File $OutFile -append
	    }
    }
}

function Get-Registry($Path, $OutFile)
# SYNOPSIS: get the content of Registry keys
{
    if ((Test-Path $Path) -eq $true)
    {
        Get-Item $Path | Out-File $OutFile -append
	    Get-ChildItem $Path -Recurse | Out-File $OutFile -append
    }
}

function Get-WorkFoldersInfo
# SYNOPSIS: collect WorkFolder client and server info
{
	param (
	  [Parameter(Mandatory=$true, Position=0)] [String] $OutputDirectory,
	  [Parameter(Mandatory=$false, Position=1)] [Switch] $AdvancedMode = $false,
	  [Parameter(Mandatory=$false, Position=2)] [Int] $TraceLevel = 255,
	  [Parameter(Mandatory=$false, Position=3)] [Switch] $Cleanup = $True,
	  [Parameter(Mandatory=$false, Position=4)] [Switch] $RunTrace = $false,
	  [Parameter(Mandatory)]
        [ValidateSet("Start","Stop")]
        [string]$Stage
	)

	$OldErrorActionPreference = $ErrorActionPreference
	$ErrorActionPreference = "SilentlyContinue"

	# Validate input
	$Done = $false
	while ($Done -eq $false)
	{
		if ($null -eq $OutputDirectory)	{	$Done = $false	}
		elseif ((Test-Path $OutputDirectory) -eq $false) {	$Done = $false	}
		else {	$Done = $true	}

		if ($Done -eq $false)
		{	Write-Error "Path selected is invalid."
			$OutputDirectory = Read-Host "Specify another path for OutputDirectory [Note that all contents already present in this directory will be erased.]"
		}
	}
	while (($TraceLevel -lt 1) -or ($TraceLevel -gt 255))
	{	$TraceLevel = Read-Host "Invalid trace level specified. Please specify a value between 1 and 255"}

	# Create Temp directory structure to accumulate output + Collect generic info
	$Script:TempOutputPath = $OutputDirectory + '\Temp'
	$Script:GeneralDirectory = $Script:TempOutputPath + '\General'
	$Script:IsServer = Test-Path ($env:Systemroot + '\System32\SyncShareSvc.dll')
	$Script:IsClient = Test-Path ($env:Systemroot + '\System32\WorkFoldersSvc.dll')
	
if ($Stage -eq "Start") 
{ 
	Write-Host "v$ScriptVer Starting collection of debug information for Work Folders on this machine ..." -ForegroundColor White -BackgroundColor DarkGreen
	Write-Host "$(Get-Date -Format 'HH:mm:ss') Setting up WorkFoldersDiag environment ..."
	if ($AdvancedMode) {  	Write-Host "... running in AdvancedMode" }

	New-Item $Script:TempOutputPath -type directory | Out-Null
	New-Item $Script:GeneralDirectory -type directory | Out-Null
	$GeneralInfoFile = $Script:GeneralDirectory + '\' + $env:COMPUTERNAME + '_MachineInfo.txt'
	$LocalVolumesFile = $Script:GeneralDirectory + '\' + $env:COMPUTERNAME + '_LocalVolumes.txt'
	$ClusterVolumesFile = $Script:GeneralDirectory + '\' + $env:COMPUTERNAME + '_ClusterVolumes.txt'
	'VersionString: ' + [System.Environment]::OSVersion.VersionString | Out-File $GeneralInfoFile
	'Version: ' + [System.Environment]::OSVersion.Version | Out-File $GeneralInfoFile -append
	'ServicePack: ' + [System.Environment]::OSVersion.ServicePack | Out-File $GeneralInfoFile -append
	'Platform: ' + [System.Environment]::OSVersion.Platform | Out-File $GeneralInfoFile -append

	$OS = Get-CimInstance -class win32_OperatingSystem
	if ($OS.ProductType -gt 1)
	{	'OS SKU Type: Server' | Out-File $GeneralInfoFile -append
		try { $Cluster = Get-Cluster -EA Ignore}
		catch { 
			#Write-host "...not running on cluster environment"
			}
		$IsCluster = $null -ne $Cluster
		if ($IsCluster) {  'This machine is part of a cluster' | Out-File $GeneralInfoFile -append }
		else {    'This machine is a stand alone machine, it is not part of a cluster' | Out-File $GeneralInfoFile -append }
	}
	else
	{	'OS SKU Type: Client' | Out-File $GeneralInfoFile -append}


	if ($Script:IsServer) {
		'Work Folders server component is installed on this machine.' | Out-File $GeneralInfoFile -append 
		'List of versions of binaries for the Work Folders server component:' | Out-File $GeneralInfoFile -append
		$ServerBinaries = @(
		($env:Systemroot + '\System32\SyncShareSvc.dll'),
		($env:Systemroot + '\System32\SyncShareSrv.dll'),
		($env:Systemroot + '\System32\SyncShareTTLib.dll'),
		($env:Systemroot + '\System32\SyncShareTTSvc.exe')
		)
		Foreach($Binary in $ServerBinaries)
		{ 	[System.Diagnostics.FileVersionInfo]::GetVersionInfo($Binary) | Format-List | Out-File $GeneralInfoFile -append }
		Copy-Item ($env:Systemroot + '\System32\SyncShareSvc.config') $Script:GeneralDirectory
		$WFmode = "Server"
	}
	if ($Script:IsClient) {
		'Work Folders client component is installed on this machine.' | Out-File $GeneralInfoFile -append
		'List of versions of binaries for the Work Folders client component:' | Out-File $GeneralInfoFile -append
		$ClientBinaries = @(
		($env:Systemroot + '\System32\WorkFoldersShell.dll'),
		($env:Systemroot + '\System32\WorkFoldersGPExt.dll'),
		($env:Systemroot + '\System32\WorkFoldersControl.dll'),
		($env:Systemroot + '\System32\WorkFoldersSvc.dll'),
		($env:Systemroot + '\System32\WorkFolders.exe')
		)
		Foreach($Binary in $ClientBinaries)
		{ 	[System.Diagnostics.FileVersionInfo]::GetVersionInfo($Binary) | Format-List | Out-File $GeneralInfoFile -append }
		$WFmode = "Client"
	}
	
	$WFmodeDirectory = $null
	$WFmodeDirectory = $Script:TempOutputPath + '\' + $WFmode
	New-Item $WFmodeDirectory -type directory | Out-Null
		
	"List of local volumes:" | Out-File $LocalVolumesFile -append
	Get-WmiObject Win32_Volume | Out-File $LocalVolumesFile -append

	if ($IsCluster)
	{
		"List of cluster volumes:" | Out-File $ClusterVolumesFile -append
		Get-WmiObject MSCluster_Resource -Namespace root/mscluster | where-object{$_.Type -eq 'Physical Disk'} |
			ForEach-Object{ Get-WmiObject -Namespace root/mscluster -Query "Associators of {$_} Where ResultClass=MSCluster_Disk" } |
			ForEach-Object{ Get-WmiObject -Namespace root/mscluster -Query "Associators of {$_} Where ResultClass=MSCluster_DiskPartition" } |
			Out-File $ClusterVolumesFile -append
	}

	if ($RunTrace) {  	Write-Host "... Start Work Folders tracing" 
		### Start Work Folders tracing
		#Write-Host "$(Get-Date -Format 'HH:mm:ss') Start Work Folders $WFmode tracing ..."
		$TracesDirectory = $Script:TempOutputPath + '\Traces'
		New-Item $TracesDirectory -type directory | Out-Null
		$TracingCommand = 'logman start WorkFoldersTrace -o "$TracesDirectory\WorkFoldersTrace.etl" --max -ets -p "{111157cb-ee69-427f-8b4e-ef0feaeaeef2}" 0xffffffff ' + $TraceLevel
		Invoke-Expression $TracingCommand | Out-Null # start traces
		$TracingCommand = 'logman start WorkFoldersTraceEFS -o "$TracesDirectory\WorkFoldersTraceEFS.etl" --max -ets -p "{C755EF4D-DE1C-4E7D-A10D-B8D1E26F5035}" 0xffffffff ' + $TraceLevel
		Invoke-Expression $TracingCommand | Out-Null # start EFS traces
		$TracingCommand = 'logman start WorkFoldersTraceESE -o "$TracesDirectory\WorkFoldersTraceESE.etl" --max -ets -p "{1284E99B-FF7A-405A-A60F-A46EC9FED1A7}" 0xffffffff ' + $TraceLevel
		Invoke-Expression $TracingCommand | Out-Null # start ESE traces
		Write-Host "$(Get-Date -Format 'HH:mm:ss') Work Folders $WFmode Tracing started."
		
		### Start Interactive Repro
		Write-Host "`n === Please reproduce the WorkFolder problem then press the 's' key to stop tracing. ===`n" -ForegroundColor Green
		do {
			$UserDone = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
		} until ($UserDone.Character -ieq 's')
		###
		Write-Host "$(Get-Date -Format 'HH:mm:ss') Collecting WorkFolder traces with TraceLevel $TraceLevel ..."

		Start-Sleep(5) # Allow time to make sure traces get written

		Invoke-Expression 'logman stop WorkFoldersTrace -ets' | Out-Null # stop traces
		Invoke-Expression 'logman stop WorkFoldersTraceEFS -ets' | Out-Null # stop EFS traces
		Invoke-Expression 'logman stop WorkFoldersTraceESE -ets' | Out-Null # stop ESE traces

		Write-Host "$(Get-Date -Format 'HH:mm:ss') WorkFolder Tracing stopped."
	}
}
if ($Stage -eq "Stop") 
{	
	###
	if ($Script:IsClient) {$WFmode = "Client"}
	if ($Script:IsServer)
	{
		$ServerSetting = Get-SyncServerSetting
		$Shares = Get-SyncShare
		$WFmode = "Server"
	}
	
	$WFmodeDirectory = $Script:TempOutputPath + '\' + $WFmode
	
	if ($AdvancedMode)
	{ #_# Stopping Service WorkFolderssvc
		if ($Script:IsClient) { Write-Host "$(Get-Date -Format 'HH:mm:ss') Stopping Service WorkFolderssvc."
						Stop-Service WorkFolderssvc }
		if ($Script:IsServer) { Write-Host "$(Get-Date -Format 'HH:mm:ss') Stopping Services SyncShareSvc, SyncShareTTSvc."
						Stop-Service SyncShareSvc
						Stop-Service SyncShareTTSvc }
	}

	Write-Host "$(Get-Date -Format 'HH:mm:ss') Saving WorkFolders $WFmode configuration information ..."
	$ConfigDirectory = $WFmodeDirectory + '\Config'
	New-Item $ConfigDirectory -type directory | Out-Null
	$RegConfigFile = $ConfigDirectory + '\' + $env:COMPUTERNAME + '_RegistryConfig.txt'
	$MetadataDirectory = $WFmodeDirectory + '\' + $WFmode + 'Metadata'
	if ($AdvancedMode) { New-Item $MetadataDirectory -type directory | Out-Null   }

	if ($Script:IsServer)
	{
		Get-Registry 'hklm:\SYSTEM\CurrentControlSet\Services\SyncShareSvc' $RegConfigFile
		Get-Registry 'hklm:\SYSTEM\CurrentControlSet\Services\SyncShareTTSvc' $RegConfigFile
		$SyncShareSrvHive = 'hklm:\SOFTWARE\Microsoft\Windows\CurrentVersion\SyncShareSrv'
		if ($IsCluster) { $SyncShareSrvHive = 'hklm:\Cluster\SyncShareSrv' }
		Get-Registry $SyncShareSrvHive $RegConfigFile

		$ConfigFile = $ConfigDirectory + '\' + $env:COMPUTERNAME + '_CmdletConfig.txt'
		$LogSeparator | Out-File $ConfigFile -append
		'Config for sync server:' | Out-File $ConfigFile -append
		$LogSeparator | Out-File $ConfigFile -append
		$ServerSetting | Out-File $ConfigFile -append
		$LogSeparator | Out-File $ConfigFile -append
		'End config for sync server:' | Out-File $ConfigFile -append
		$LogSeparator | Out-File $ConfigFile -append

		foreach ($Share in $Shares)
		{
			$LogSeparator | Out-File $ConfigFile -append
			'Config for sync share ' + $Share.Name | Out-File $ConfigFile -append
			$LogSeparator | Out-File $ConfigFile -append
			$Share | Out-File $ConfigFile -append

			$acl = Get-Acl $Share.Path -EA SilentlyContinue
			'ACLs on ' + $Share.Path + ':' | Out-File $ConfigFile -append
			$acl | Out-File $ConfigFile -append
			$acl.Access | Out-File $ConfigFile -append

			$acl = Get-Acl $Share.StagingFolder -EA SilentlyContinue
			'ACLs on ' + $Share.StagingFolder + ':' | Out-File $ConfigFile -append
			$acl | Out-File $ConfigFile -append
			$acl.Access | Out-File $ConfigFile -append

			$MetadataFolder = $Share.StagingFolder + '\Metadata'
			$acl = Get-Acl $MetadataFolder -EA SilentlyContinue
			'ACLs on ' + $MetadataFolder + ':' | Out-File $ConfigFile -append
			$acl | Out-File $ConfigFile -append
			$acl.Access | Out-File $ConfigFile -append

			if ($AdvancedMode) { Get-ChildItem $MetadataFolder | ForEach-Object{ Copy-Item $_.FullName $MetadataDirectory } }
			
			foreach ($user in $Share.User)
			{
				'Full list of users on this sync share:' | Out-File $ConfigFile -append
				$user | Out-File $ConfigFile -append
			}

			$LogSeparator | Out-File $ConfigFile -append
			'End config for sync share ' + $Share.Name | Out-File $ConfigFile -append
			$LogSeparator | Out-File $ConfigFile -append
		}
	}

	if ($Script:IsClient)
	{
		Get-Registry 'hklm:SOFTWARE\Microsoft\Windows\CurrentVersion\WorkFolders' $RegConfigFile
		Get-Registry 'hkcu:SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\WorkFolders' $RegConfigFile
		Get-Registry 'hkcu:SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings' $RegConfigFile
		if ($AdvancedMode) { Get-ChildItem ($env:LOCALAPPDATA + '\Microsoft\Windows\WorkFolders\Metadata') | ForEach-Object{ Copy-Item $_.FullName $MetadataDirectory } }
	}

	### event log entries
	Write-Host "$(Get-Date -Format 'HH:mm:ss') Collecting WorkFolders $WFmode event log entries ..."
	$EventLogDirectory = $WFmodeDirectory + '\' + $WFmode + 'EventLogs'
	New-Item $EventLogDirectory -type directory | Out-Null

	if ($Script:IsServer)
	{
		Get-EventsTxt Microsoft-Windows-SyncShare/Operational ($EventLogDirectory + '\' + $env:COMPUTERNAME + '_SyncShare_Operational.txt')
		#_# ToDo: Get-EventsTxt Microsoft-Windows-SyncShare/Debug ($EventLogDirectory + '\' + $env:COMPUTERNAME + '_SyncShare_Debug.txt')
		Get-EventsTxt Microsoft-Windows-SyncShare/Reporting ($EventLogDirectory + '\' + $env:COMPUTERNAME + '_SyncShare_Reporting.txt')
	}

	if ($Script:IsClient)
	{
		Get-EventsTxt Microsoft-Windows-WorkFolders/Operational ($EventLogDirectory + '\' + $env:COMPUTERNAME + '_WorkFolders_Operational.txt')
		#_# ToDo: Get-EventsTxt Microsoft-Windows-WorkFolders/Debug ($EventLogDirectory + '\' + $env:COMPUTERNAME + '_WorkFolders_Debug.txt')
		#_# ToDo: Get-EventsTxt Microsoft-Windows-WorkFolders/Analytic ($EventLogDirectory + '\' + $env:COMPUTERNAME + '_WorkFolders_Analytic.txt')
		Get-EventsTxt Microsoft-Windows-WorkFolders/WHC ($EventLogDirectory + '\' + $env:COMPUTERNAME + '_WorkFolders_ManagementAgent.txt')
	}
	Write-Host "$(Get-Date -Format 'HH:mm:ss') Collection of WorkFolders $WFmode event log entries done."

	if ($AdvancedMode)
	{ #_# Starting Service WorkFolderssvc
		if ($Script:IsClient) {  Write-Host "$(Get-Date -Format 'HH:mm:ss') Restarting Service WorkFolderssvc"
						Start-Service WorkFolderssvc }
		if ($Script:IsServer) {  Write-Host "$(Get-Date -Format 'HH:mm:ss') Restarting Services SyncShareSvc, SyncShareTTSvc"
						Start-Service SyncShareSvc
						Start-Service SyncShareTTSvc }
	}
	### Compress data
	Write-Host "$(Get-Date -Format 'HH:mm:ss') Finalizing/Zipping output ..."
	# In the output directory, remove the system and hidden attributes from files
	attrib ($Script:TempOutputPath + '\*') -H -S /s
	# Zip the output directory
	Add-Type -AssemblyName System.IO.Compression
	Add-Type -AssemblyName System.IO.Compression.FileSystem
	$OutputZipFile = $OutputDirectory + '\' + $env:COMPUTERNAME + '_WorkFoldersDiagOutput.zip'
	[System.IO.Compression.ZipFile]::CreateFromDirectory($Script:TempOutputPath, $OutputZipFile)
	Write-Host "All information have been saved in $OutputZipFile." -ForegroundColor Green 

	###
	Write-Host "Cleaning up environment ..."
	if ($Cleanup) { Write-Host "$(Get-Date -Format 'HH:mm:ss') Cleaning output directory $Script:TempOutputPath ..."
					Remove-Item $Script:TempOutputPath -Recurse -Force }

	$ErrorActionPreference = $OldErrorActionPreference
	Write-Host "$(Get-Date -Format 'HH:mm:ss') Done - tss_WorkFoldersDiag" -ForegroundColor White -BackgroundColor DarkGreen
	Write-Host " "
}
} # end of function Get-WorkFoldersInfo

#region ::::: MAIN ::::
Get-WorkFoldersInfo -OutputDirectory $dataPath $AdvancedMode -TraceLevel $TraceLevel -Stage $Stage
#endregion ::::: MAIN :::::


# SIG # Begin signature block
# MIInvwYJKoZIhvcNAQcCoIInsDCCJ6wCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBO3X5nRSPI+pqT
# fVFpR+EvNb4WJQN5JztzJfBjdAQZ6KCCDXYwggX0MIID3KADAgECAhMzAAADrzBA
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
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIEvtH5WImO30R+uO3z/vnhj0
# HbkyOaig9CYZOVJtqelQMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEATwghFoFdUo4MvKkazQSS6Ou+PKd15jAR5EkRzEvqjAge5a4GbYFgtEEW
# tQSB8wLZfkTgYRCziqlQBSC0fVm36u99G69qvMDyTmQ7HvRnCzz3+xDLcAg8r2D8
# DZ++EOR63NxRNr7LCJ4fY0oKZo7vussHTH7nMHb4xVbKzf/nl3PQrzxMDW7SlNBa
# fACqjTpd48h7OOjJonghF97KUzQOLh/pmPC+cz2Xi3husu1xI7Vm6IMOiw8XwQDU
# qo/Y34KpCDtWIic+b5YXFtfRPabALuRrH3lPm8Mv29DJaU5V4Oy4boZnRm3rPyHy
# JRB+6pV6K6phaz0BampN4xLTMjzAdaGCFykwghclBgorBgEEAYI3AwMBMYIXFTCC
# FxEGCSqGSIb3DQEHAqCCFwIwghb+AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsq
# hkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCDdTyg1oaHQcL73aQ81G3LXQtYPIpRTDYXL05WbZTSRHwIGZbqk2rEi
# GBMyMDI0MDIyMDEyMTY1OS41ODVaMASAAgH0oIHYpIHVMIHSMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJl
# bGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNO
# OjNCRDQtNEI4MC02OUMzMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNloIIReDCCBycwggUPoAMCAQICEzMAAAHlj2rA8z20C6MAAQAAAeUwDQYJ
# KoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjMx
# MDEyMTkwNzM1WhcNMjUwMTEwMTkwNzM1WjCB0jELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3Bl
# cmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjozQkQ0LTRC
# ODAtNjlDMzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAKl74Drau2O6LLrJO3HyTvO9
# aXai//eNyP5MLWZrmUGNOJMPwMI08V9zBfRPNcucreIYSyJHjkMIUGmuh0rPV5/2
# +UCLGrN1P77n9fq/mdzXMN1FzqaPHdKElKneJQ8R6cP4dru2Gymmt1rrGcNe800C
# cD6d/Ndoommkd196VqOtjZFA1XWu+GsFBeWHiez/PllqcM/eWntkQMs0lK0zmCfH
# +Bu7i1h+FDRR8F7WzUr/7M3jhVdPpAfq2zYCA8ZVLNgEizY+vFmgx+zDuuU/GChD
# K7klDcCw+/gVoEuSOl5clQsydWQjJJX7Z2yV+1KC6G1JVqpP3dpKPAP/4udNqpR5
# HIeb8Ta1JfjRUzSv3qSje5y9RYT/AjWNYQ7gsezuDWM/8cZ11kco1JvUyOQ8x/JD
# kMFqSRwj1v+mc6LKKlj//dWCG/Hw9ppdlWJX6psDesQuQR7FV7eCqV/lfajoLpPN
# x/9zF1dv8yXBdzmWJPeCie2XaQnrAKDqlG3zXux9tNQmz2L96TdxnIO2OGmYxBAA
# ZAWoKbmtYI+Ciz4CYyO0Fm5Z3T40a5d7KJuftF6CToccc/Up/jpFfQitLfjd71cS
# +cLCeoQ+q0n0IALvV+acbENouSOrjv/QtY4FIjHlI5zdJzJnGskVJ5ozhji0YRsc
# v1WwJFAuyyCMQvLdmPddAgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQU3/+fh7tNczEi
# fEXlCQgFOXgMh6owHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYD
# VR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9j
# cmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwG
# CCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIw
# MjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcD
# CDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBADP6whOFjD1ad8Gk
# EJ9oLBuvfjndMyGQ9R4HgBKSlPt3pa0XVLcimrJlDnKGgFBiWwI6XOgw82hdolDi
# MDBLLWRMTJHWVeUY1gU4XB8OOIxBc9/Q83zb1c0RWEupgC48I+b+2x2VNgGJUsQI
# yPR2PiXQhT5PyerMgag9OSodQjFwpNdGirna2rpV23EUwFeO5+3oSX4JeCNZvgyU
# OzKpyMvqVaubo+Glf/psfW5tIcMjZVt0elswfq0qJNQgoYipbaTvv7xmixUJGTbi
# xYifTwAivPcKNdeisZmtts7OHbAM795ZvKLSEqXiRUjDYZyeHyAysMEALbIhdXgH
# Eh60KoZyzlBXz3VxEirE7nhucNwM2tViOlwI7EkeU5hudctnXCG55JuMw/wb7c71
# RKimZA/KXlWpmBvkJkB0BZES8OCGDd+zY/T9BnTp8si36Tql84VfpYe9iHmy7Pqq
# xqMF2Cn4q2a0mEMnpBruDGE/gR9c8SVJ2ntkARy5SfluuJ/MB61yRvT1mUx3lypp
# O22ePjBjnwoEvVxbDjT1jhdMNdevOuDeJGzRLK9HNmTDC+TdZQlj+VMgIm8ZeEIR
# NF0oaviF+QZcUZLWzWbYq6yDok8EZKFiRR5otBoGLvaYFpxBZUE8mnLKuDlYobjr
# xh7lnwrxV/fMy0F9fSo2JxFmtLgtMIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJ
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
# bmQgT3BlcmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjoz
# QkQ0LTRCODAtNjlDMzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUA942iGuYFrsE4wzWDd85EpM6RiwqggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AOl+1LMwIhgPMjAyNDAyMjAxNTM1MTVaGA8yMDI0MDIyMTE1MzUxNVowdDA6Bgor
# BgEEAYRZCgQBMSwwKjAKAgUA6X7UswIBADAHAgEAAgINZjAHAgEAAgISOzAKAgUA
# 6YAmMwIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAID
# B6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBAIpysElI0/XLRqOKmHo+
# m227xCEZtsr/3xLd/MV1hK6hl5Jmie8e9Qv//8ogOpWkqJH3Z0oNgrww/WWmI0RP
# hbWqweaZQjErzifgKTJqlztZyiIIs3pUxlUz2LHwPi8BXHUtQWd4apjcbMetANVp
# 6gvB/SBOUw3wHemGQcpOkg6RMYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgUENBIDIwMTACEzMAAAHlj2rA8z20C6MAAQAAAeUwDQYJYIZIAWUDBAIB
# BQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQx
# IgQgCEL2mkTG07NXkUsVoMN/m/i7GVJ44m3wa2W71C3qinkwgfoGCyqGSIb3DQEJ
# EAIvMYHqMIHnMIHkMIG9BCAVqdP//qjxGFhe2YboEXeb8I/pAof01CwhbxUH9U69
# 7TCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB5Y9q
# wPM9tAujAAEAAAHlMCIEIBsAbimdI+ye2UIiP0NL+ZRHoPI3NgLOHJjAAqJlKaGw
# MA0GCSqGSIb3DQEBCwUABIICAFCPpb79uXTX1jgAF6w6V/oGeHn8EebKLZLWUjLE
# ctWBLj0VYNPplptb8h3oUkdbj1Je4UXyaP6OlAB7HDoEJmLVlH8qvlRAd93UZzoI
# jCiseOvH4Zfae/2pSfDTGhSeHabb1vjXR8jS3um2M05TKufyvy7Ov/W/0BhuPg7U
# mBZtD5QhL77YHApIUGd2cx032w/bgtjpFC/mTLQLmsMHF3iZyPzejw9C878dLA35
# Xs1Hbn0t/lhtd2S/oo4O8fwaLGqnjfYeZJJNUbQ5+bQ3aWsSTrbJdrCvFohkzvvD
# V89BR9e14BIQi7NDkvzsb53FvCoynFtQFwxqk/vfxiqElY5v1Co9F3g0OpRkasVc
# +1AznkyLMKc6hMfjm9QmtrW5E4KDshJZJGejjzYGwLi5H9nz6Z+dRoqgcc2dYvRD
# EJhO9sm5YJV1MxMOklAR4eEzutBlxQhy4MI8+nFiWWSulI/YRC8cWsqIYgBYHww8
# cqjRTJ1gVYXLv+RDWgfVBgQj2Nwx7mhUOTErTEnBxf7kucvQaWoNCm5FvXcVu2DY
# bZ8AnxQhDQNuy8Vc6WnWWbEQEp1eBn3E/rkloE0WqnsSd8MVwe3qBnFjtBpqpo0b
# piw25EPM3vF7mnq5y01lSR0EHkbAkXVw26hNWqqzEXkW8j7qzXbOHmVQoXVy7C2w
# p38m
# SIG # End signature block
