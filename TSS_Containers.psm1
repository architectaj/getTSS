<#
.SYNOPSIS
	This module is part of TSS FW and implements support for tracing Container scenarios


.DESCRIPTION
	This module is part of TSS FW and implements support for tracing Container scenarios


.NOTES
	Dev. Lead: wiaftrin, milanmil
	Authors		: wiaftrin, milanmil
	Requires	: PowerShell V4(Supported from Windows 8.1/Windows Server 2012 R2)
	Version		: see $global:TssVerDateCONTAINERS

.LINK
	TSS https://internal.evergreen.microsoft.com/en-us/help/4619187

#>

<# latest changes

::  2023.10.10.0 [we] _Containers: replaced TSS.ps1 with $($global:ScriptName)
#>

[cmdletbinding(PositionalBinding = $false, DefaultParameterSetName = "Default")]
param(
[Parameter(ParameterSetName = "Default")]
[string]$containerId
)

$global:TssVerDateCON= "2023.10.10.0"

#region event_logs_registry

	$_EVENTLOG_LIST_START = @(
		# LOGNAME!FLAG1|FLAG2|FLAG3
		"Application!NONE"
		"System!NONE"
		"Microsoft-Windows-CAPI2/Operational!CLEAR|SIZE|EXPORT"
		"Microsoft-Windows-Kerberos/Operational!CLEAR"
		"Microsoft-Windows-Kerberos-key-Distribution-Center/Operational!DEFAULT"
		"Microsoft-Windows-Kerberos-KdcProxy/Operational!DEFAULT"
		"Microsoft-Windows-WebAuth/Operational!DEFAULT"
		"Microsoft-Windows-WebAuthN/Operational!EXPORT"
		"Microsoft-Windows-CertPoleEng/Operational!CLEAR"
		"Microsoft-Windows-IdCtrls/Operational!EXPORT"
		"Microsoft-Windows-User Control Panel/Operational!EXPORT"
		"Microsoft-Windows-Authentication/AuthenticationPolicyFailures-DomainController!DEFAULT"
		"Microsoft-Windows-Authentication/ProtectedUser-Client!DEFAULT"
		"Microsoft-Windows-Authentication/ProtectedUserFailures-DomainController!DEFAULT"
		"Microsoft-Windows-Authentication/ProtectedUserSuccesses-DomainController!DEFAULT"
		"Microsoft-Windows-Biometrics/Operational!EXPORT"
		"Microsoft-Windows-LiveId/Operational!EXPORT"
		"Microsoft-Windows-AAD/Analytic!DEFAULT"
		"Microsoft-Windows-AAD/Operational!EXPORT"
		"Microsoft-Windows-User Device Registration/Debug!DEFAULT"
		"Microsoft-Windows-User Device Registration/Admin!EXPORT"
		"Microsoft-Windows-HelloForBusiness/Operational!EXPORT"
		"Microsoft-Windows-Shell-Core/Operational!DEFAULT"
		"Microsoft-Windows-WMI-Activity/Operational!DEFAULT"
		"Microsoft-Windows-GroupPolicy/Operational!DEFAULT"
		"Microsoft-Windows-Crypto-DPAPI/Operational!EXPORT"
		"Microsoft-Windows-Containers-CCG/Admin!NONE"
	)
	$_EVENTLOG_LIST_STOP = @(
	# LOGNAME!FLAGS
	"Application!DEFAULT"
	"System!DEFAULT"
	"Microsoft-Windows-CAPI2/Operational!NONE"
	"Microsoft-Windows-Kerberos/Operational!NONE"
	"Microsoft-Windows-Kerberos-key-Distribution-Center/Operational!NONE"
	"Microsoft-Windows-Kerberos-KdcProxy/Operational!NONE"
	"Microsoft-Windows-WebAuth/Operational!NONE"
	"Microsoft-Windows-WebAuthN/Operational!ENABLE"
	"Microsoft-Windows-CertPoleEng/Operational!NONE"
	"Microsoft-Windows-IdCtrls/Operational!ENABLE"
	"Microsoft-Windows-User Control Panel/Operational!NONE"
	"Microsoft-Windows-Authentication/AuthenticationPolicyFailures-DomainController!NONE"
	"Microsoft-Windows-Authentication/ProtectedUser-Client!NONE"
	"Microsoft-Windows-Authentication/ProtectedUserFailures-DomainController!NONE"
	"Microsoft-Windows-Authentication/ProtectedUserSuccesses-DomainController!NONE"
	"Microsoft-Windows-Biometrics/Operational!ENABLE"
	"Microsoft-Windows-LiveId/Operational!ENABLE"
	"Microsoft-Windows-AAD/Analytic!NONE"
	"Microsoft-Windows-AAD/Operational!ENABLE"
	"Microsoft-Windows-User Device Registration/Debug!NONE"
	"Microsoft-Windows-User Device Registration/Admin!ENABLE"
	"Microsoft-Windows-HelloForBusiness/Operational!ENABLE"
	"Microsoft-Windows-Shell-Core/Operational!ENABLE"
	"Microsoft-Windows-WMI-Activity/Operational!ENABLE"
	"Microsoft-Windows-GroupPolicy/Operational!DEFAULT"
	"Microsoft-Windows-Crypto-DPAPI/Operational!ENABLE"
	"Microsoft-Windows-Containers-CCG/Admin!ENABLE"
	"Microsoft-Windows-CertificateServicesClient-Lifecycle-System/Operational!ENABLE"
	"Microsoft-Windows-CertificateServicesClient-Lifecycle-User/Operational!ENABLE"
)

$_REG_ADD_START = @(
	# KEY!NAME!TYPE!VALUE
	"HKLM\SYSTEM\CurrentControlSet\Control\Lsa\NegoExtender\Parameters!InfoLevel!REG_DWORD!0xFFFF"
	"HKLM\SYSTEM\CurrentControlSet\Control\Lsa\Pku2u\Parameters!InfoLevel!REG_DWORD!0xFFFF"
	"HKLM\SYSTEM\CurrentControlSet\Control\LSA!SPMInfoLevel!REG_DWORD!0xC43EFF"
	"HKLM\SYSTEM\CurrentControlSet\Control\LSA!LogToFile!REG_DWORD!1"
	"HKLM\SYSTEM\CurrentControlSet\Control\LSA!NegEventMask!REG_DWORD!0xF"
	"HKLM\SYSTEM\CurrentControlSet\Control\LSA!LspDbgInfoLevel!REG_DWORD!0x41C24800"
	"HKLM\SYSTEM\CurrentControlSet\Control\LSA!LspDbgTraceOptions!REG_DWORD!0x1"
)




# Reg Delete
$_REG_DELETE = @(
	# KEY!NAME
	"HKLM\SYSTEM\CurrentControlSet\Control\LSA!SPMInfoLevel"
	"HKLM\SYSTEM\CurrentControlSet\Control\LSA!LogToFile"
	"HKLM\SYSTEM\CurrentControlSet\Control\LSA!NegEventMask"
	"HKLM\SYSTEM\CurrentControlSet\Control\LSA\NegoExtender\Parameters!InfoLevel"
	"HKLM\SYSTEM\CurrentControlSet\Control\LSA\Pku2u\Parameters!InfoLevel"
	"HKLM\SYSTEM\CurrentControlSet\Control\LSA!LspDbgInfoLevel"
	"HKLM\SYSTEM\CurrentControlSet\Control\LSA!LspDbgTraceOptions"
	"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Diagnostics!GPSvcDebugLevel"
)

# Reg Query
$_REG_QUERY = @(
	# KEY!CHILD!FILENAME
	# File will be written ending with <FILENAME>-key.txt
	# If the export already exists it will be appended
	"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa!CHILDREN!Lsa"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies!CHILDREN!Polices"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System!CHILDREN!SystemGP"
	"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer!CHILDREN!Lanmanserver"
	"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanWorkstation!CHILDREN!Lanmanworkstation"
	"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Netlogon!CHILDREN!Netlogon"
	"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL!CHILDREN!Schannel"
	"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Cryptography!CHILDREN!Cryptography-HKLMControl"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography!CHILDREN!Cryptography-HKLMSoftware"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Cryptography!CHILDREN!Cryptography-HKLMSoftware-Policies"
	"HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Cryptography!CHILDREN!Cryptography-HKCUSoftware-Policies"
	"HKEY_CURRENT_USER\SOFTWARE\Microsoft\Cryptography!CHILDREN!Cryptography-HKCUSoftware"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\SmartCardCredentialProvider!CHILDREN!SCardCredentialProviderGP"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication!CHILDREN!Authentication"
	"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Authentication!CHILDREN!Authentication-Wow64"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon!CHILDREN!Winlogon"
	"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Winlogon!CHILDREN!Winlogon-CCS"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\IdentityStore!CHILDREN!Idstore-Config"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\IdentityCRL!CHILDREN!Idstore-Config"
	"HKEY_USERS\.Default\Software\Microsoft\IdentityCRL!CHILDREN!Idstore-Config"
	"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Kdc!CHILDREN!KDC"
	"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\KPSSVC!CHILDREN!KDCProxy"
	"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\CloudDomainJoin!CHILDREN!RegCDJ"
	"HKEY_CURRENT_USER\Software\Microsoft\Windows NT\CurrentVersion\WorkplaceJoin!CHILDREN!RegWPJ"
	"HKEY_CURRENT_USER\Software\Microsoft\Windows NT\CurrentVersion\WorkplaceJoin\AADNGC!CHILDREN!RegAADNGC"
	"HKEY_LOCAL_MACHINE\Software\Policies\Windows\WorkplaceJoin!CHILDREN!REGWPJ-Policy"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Winbio!CHILDREN!Wbio"
	"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\WbioSrvc!CHILDREN!Wbiosrvc"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Biometrics!CHILDREN!Wbio-Policy"
	"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\EAS\Policies!CHILDREN!EAS"
	"HKEY_CURRENT_USER\SOFTWARE\Microsoft\SCEP!CHILDREN!Scep"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\SQMClient!CHILDREN!MachineId"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Policies\PassportForWork!CHILDREN!NgcPolicyIntune"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\PassportForWork!CHILDREN!NgcPolicyGp"
	"HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\PassportForWork!CHILDREN!NgcPolicyGpUser"
	"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Cryptography\Ngc!CHILDREN!NgcCryptoConfig"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\PolicyManager\current\device\DeviceLock!CHILDREN!DeviceLockPolicy"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Policies\PassportForWork\SecurityKey!CHILDREN!FIDOPolicyIntune"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\FIDO!CHILDREN!FIDOGp"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Rpc!CHILDREN!RpcGP"
	"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NTDS\Parameters!CHILDREN!NTDS"
	"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LDAP!CHILDREN!LdapClient"
	"HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\DeviceGuard!CHILDREN!DeviceGuard"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\CCMSetup!CHILDREN!CCMSetup"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\CCM!CHILDREN!CCM"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework\v2.0.50727!NONE!DotNET-TLS"
	"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319!NONE!DotNET-TLS"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\.NETFramework\v4.0.30319!NONE!DotNET-TLS"
	"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v2.0.50727!NONE!DotNET-TLS"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\SharedPC!NONE!SharedPC"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess!NONE!Passwordless"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Authz!CHILDREN!Authz"
	"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp!NONE!WinHttp-TLS"
	"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp!NONE!WinHttp-TLS"
	"HKEY_LOCAL_MACHINE\Software\Microsoft\Enrollments!CHILDREN!MDMEnrollments"
	"HKEY_LOCAL_MACHINE\Software\Microsoft\EnterpriseResourceManager!CHILDREN!MDMEnterpriseResourceManager"
	"HKEY_CURRENT_USER\Software\Microsoft\SCEP!CHILDREN!MDMSCEP-User"
	"HKEY_CURRENT_USER\S-1-5-18\Software\Microsoft\SCEP!CHILDREN!MDMSCEP-SystemUser"
)

#endregion event_logs_registry

#region container_functions

function Invoke-Container {

	[Cmdletbinding(DefaultParameterSetName = "Default")]
	param(
		[Parameter(Mandatory = $true)]
		[string]$ContainerId,
		[switch]$Nano,
		[Parameter(ParameterSetName = "PreTraceDir")]
		[switch]$PreTrace,
		[Parameter(ParameterSetName = "AuthDir")]
		[switch]$AuthDir,
		[switch]$UseCmd,
		[switch]$Record,
		[switch]$Silent,
		[Parameter(Mandatory = $true)]
		[string]$Command,
		[string]$WorkingFolder
	)

	<#
	$Workingdir = $_BASE_LOG_DIR #"C:\AuthScripts"
	if ($PreTrace) {
		$Workingdir += "\authlogs\PreTraceLogs"
	}

	if ($AuthDir) {
		$Workingdir += "\authlogs"
	}
	#>

	If($PSBoundParameters.ContainsKey("WorkingFolder")) {
		$Workingdir = $WorkingFolder
	}
	else {
		$Workingdir = "c:\TSS" #in TSS all commands, by default, run in TSS, otherwise use $WorkingFolder
	}




	Write-Verbose "Running Container command: $Command"
	if ($Record) {
		if ($Nano) {
			docker exec -u Administrator -w $Workingdir $ContainerId cmd /c "$Command" *>> $_CONTAINER_DIR\container-output.txt
		}
		elseif ($UseCmd) {
			docker exec -w $Workingdir $ContainerId cmd /c "$Command" *>> $_CONTAINER_DIR\container-output.txt
		}
		else {
			docker exec -w $Workingdir $ContainerId powershell -ExecutionPolicy Unrestricted "$Command" *>> $_CONTAINER_DIR\container-output.txt
		}
	}
	elseif ($Silent) {
		if ($Nano) {
			docker exec -u Administrator -w $Workingdir $ContainerId cmd /c "$Command" *>> Out-Null
		}
		elseif ($UseCmd) {
			docker exec -w $Workingdir $ContainerId cmd /c "$Command" *>> Out-Null
		}
		else {
			docker exec -w $Workingdir $ContainerId powershell -ExecutionPolicy Unrestricted "$Command" *>> Out-Null
		}
	}
	else {
		$Result = ""
		if ($Nano) {
			$Result = docker exec -u Administrator -w $Workingdir $ContainerId cmd /c "$Command"
		}
		elseif ($UseCmd) {
			$Result = docker exec -w $Workingdir $ContainerId cmd /c "$Command"
		}
		else {
			$Result = docker exec -w $Workingdir $ContainerId powershell -ExecutionPolicy Unrestricted "$Command"
		}
		return $Result
	}
}

function Check-ContainerIsNano {
	param($ContainerId)

	# This command is finicky and cannot use a powershell variable for the command
	$ContainerBase = Invoke-Container -ContainerId $containerId -UseCmd -Command "reg query `"hklm\software\microsoft\windows nt\currentversion`" /v EditionID"
	Write-Verbose "Container Base: $ContainerBase"
	# We only check for nano server as it is the most restrictive
	if ($ContainerBase -like "*Nano*") {
		return $true
	}
	else {
		return $false
	}
}

function Get-ContainersInfo {

	param($ContainerId)
	Get-NetFirewallProfile > $_CONTAINER_DIR\firewall_profile.txt
	Get-NetConnectionProfile >> $_CONTAINER_DIR\firewall_profile.txt
	netsh advfirewall firewall show rule name=* > $_CONTAINER_DIR\firewall_rules.txt
	netsh wfp show filters file=$_CONTAINER_DIR\wfpfilters.xml 2>&1 | Out-Null
	docker ps > $_CONTAINER_DIR\container-info.txt
	docker inspect $(docker ps -q) >> $_CONTAINER_DIR\container-info.txt
	docker network ls > $_CONTAINER_DIR\container-network-info.txt
	docker network inspect $(docker network ls -q) >> $_CONTAINER_DIR\container-network-info.txt

	docker top $containerId > $_CONTAINER_DIR\container-top.txt
	docker logs $containerId > $_CONTAINER_DIR\container-logs.txt

	wevtutil.exe set-log "Microsoft-Windows-Containers-CCG/Admin" /enabled:false 2>&1 | Out-Null
	wevtutil.exe export-log "Microsoft-Windows-Containers-CCG/Admin" $_CONTAINER_DIR\Containers-CCG_Admin.evtx /overwrite:true 2>&1 | Out-Null
	wevtutil.exe set-log "Microsoft-Windows-Containers-CCG/Admin" /enabled:true /rt:false /q:true 2>&1 | Out-Null
	Get-EventLog -LogName Application -Source Docker -After (Get-Date).AddMinutes(-30)  | Sort-Object Time | Export-CSV $_CONTAINER_DIR\docker_events.csv

}

function Check-ContainsScripts {
	param(
		$ContainerId,
		[switch]$IsNano
	)

	if ($IsNano) {
		$Result = Invoke-Container -ContainerId $containerId -Nano -Command "if exist auth.wprp (echo true)"

		if ($Result -eq "True") {

			$Result = Invoke-Container -ContainerId $containerId -Nano -Command "type auth.wprp"
			$Result = $Result[1]
			if (!$Result.Contains($_Authscriptver)) {
				$InnerScriptVersion = $Result.Split(" ")[1].Split("=")[1].Trim("`"")
				Write-Host "$ContainerId Script Version mismatch" Yellow
				Write-Host "Container Host Version: $_Authscriptver" Yellow
				Write-Host "Container Version: $InnerScriptVersion" Yellow
				return $false
			}
			Out-File -FilePath $_CONTAINER_DIR\script-info.txt -InputObject "SCRIPT VERSION: $_Authscriptver"
			return $true
		}
		else {
			return $false
		}
	}
	else {
		$StartResult = Invoke-Container -ContainerId $containerId -Command "Test-Path $($global:ScriptName)" -WorkingFolder "C:\TSS\TSSv2"
		$StopResult = Invoke-Container -ContainerId $containerId -Command "Test-Path $($global:ScriptName)" -WorkingFolder "C:\TSS\TSSv2"
		if ($StartResult -eq "True" -and $StopResult -eq "True") {
			# Checking script version
			<#
			$InnerScriptVersion = Invoke-Container -ContainerId $containerId -Command ".\start-auth.ps1 -accepteula -version"
			if ($InnerScriptVersion -ne $_Authscriptver) {
				Write-Host "$ContainerId Script Version mismatch" -ForegroundColor Yellow
				Write-Host "Container Host Version: $_Authscriptver" -ForegroundColor Yellow
				Write-Host "Container Version: $InnerScriptVersion" -ForegroundColor Yellow
				return $false
			}
			else {
				Out-File -FilePath $_CONTAINER_DIR\script-info.txt -InputObject "SCRIPT VERSION: $_Authscriptver"
				return $true
			}#>			
			return $true
		}
		else {
			#Write-Host "Container: $ContainerId missing tracing scripts!" -ForegroundColor Yellow
			return $false
		}
	}
}

function Check-GMSA-Stop {
	param($ContainerId)

	$CredentialString = docker inspect -f "{{ .HostConfig.SecurityOpt }}" $ContainerId

	if ($CredentialString -ne "[]") {
		Write-Verbose "GMSA Credential String: $CredentialString"
		# NOTE(will): We need to check if we have RSAT installed
		if ((Get-Command "Test-ADServiceAccount" -ErrorAction "SilentlyContinue") -ne $null) {
			$ServiceAccountName = $(docker inspect -f "{{ .Config.Hostname }}" $ContainerId)
			$Result = "`nSTOP:`n`nRunning Test-ADServiceAccount $ServiceAccountName`nResult:"
			try {
				$Result += Test-ADServiceAccount -Identity $ServiceAccountName -Verbose -ErrorAction SilentlyContinue
			}
			catch {
				$Result += "Unable to find object with identity $containerId"
			}

			Out-File $_CONTAINER_DIR\gMSATest.txt -InputObject $Result -Append
		}

		$CredentialName = $CredentialString.Replace("[", "").Replace("]", "")
		$CredentialName = $CredentialName.Split("//")[-1]
		$CredentialObject = Get-CredentialSpec | Where-Object { $_.Name -eq $CredentialName }
		Copy-Item $CredentialObject.Path $_CONTAINER_DIR
	}
}

function Check-GMSA-Start {
	param($ContainerId)

	$CredentialString = docker inspect -f "{.HostConfig.SecurityOpt}" $ContainerId
	if ($CredentialString -ne "[]") {
		Write-Verbose "GMSA Credential String: $CredentialString"
		# We need to check if we have Test-ADServiceAccount
		if ((Get-Command "Test-ADServiceAccount" -ErrorAction "SilentlyContinue") -ne $null) {
			$ServiceAccountName = $(docker inspect -f "{{ .Config.Hostname }}" $ContainerId)
			$Result = "START:`n`nRunning: Test-ADServiceAccount $ServiceAccountName`nResult:"

			try {
				$Result += Test-ADServiceAccount -Identity $ServiceAccountName -Verbose -ErrorAction SilentlyContinue
			}
			catch {
				$Result += "Unable to find object with identity $containerId"
			}

			Out-File $_CONTAINER_DIR\gMSATest.txt -InputObject $Result
		}
	}
}

function Generate-WPRP {
	param($ContainerId)
	$Header = @"
<?xml version="1.0" encoding="utf-8"?>
<WindowsPerformanceRecorder Version="$_Authscriptver" Author="Microsoft Corporation" Copyright="Microsoft Corporation" Company="Microsoft Corporation">
  <Profiles>

"@
	$Footer = @"
  </Profiles>
</WindowsPerformanceRecorder>
"@


	$Netmon = "{2ED6006E-4729-4609-B423-3EE7BCD678EF}"

	$ProviderList = (("NGC", $NGC),
	 ("Biometric", $Biometric),
	 ("LSA", $LSA),
	 ("Ntlm_CredSSP", $Ntlm_CredSSP),
	 ("Kerberos", $Kerberos),
	 ("KDC", $KDC),
	 ("SSL", $SSL),
	 ("WebAuth", $WebAuth),
	 ("Smartcard", $Smartcard),
	 ("CredprovAuthui", $CredprovAuthui),
	 ("AppX", $AppX),
	 ("SAM", $SAM),
	 ("kernel", $Kernel),
	 ("Netmon", $Netmon))

	# NOTE(will): Checking if Client SKU
	$ClientSKU = Invoke-Container -ContainerId $ContainerId -Nano -Command "reg query HKLM\SYSTEM\CurrentControlSet\Control\ProductOptions /v ProductType | findstr WinNT"
	if ($ClientSKU -ne $null) {
		$ProviderList.Add(("CryptNcryptDpapi", $CryptNcryptDpapi))
	}

	foreach ($Provider in $ProviderList) {
		$ProviderName = $Provider[0]
		$Header += @"
	<EventCollector Id="EventCollector$ProviderName" Name="EventCollector$ProviderName">
	  <BufferSize Value="64" />
	  <Buffers Value="4" />
	</EventCollector>

"@
	}

	$Header += "`n`n"

	# Starting on provider generation

	foreach ($Provider in $ProviderList) {
		$ProviderCount = 0
		$ProviderName = $Provider[0]

		foreach ($ProviderItem in $Provider[1]) {
			$ProviderParams = $ProviderItem.Split("!")
			$ProviderGuid = $ProviderParams[0].Replace("{", '').Replace("}", '')
			$ProviderFlags = $ProviderParams[1]

			$Header += @"
	<EventProvider Id="$ProviderName$ProviderCount" Name="$ProviderGuid"/>

"@
			$ProviderCount++
		}
	}

	# Generating profiles
	foreach ($Provider in $ProviderList) {
		$ProviderName = $Provider[0]
		$Header += @"
  <Profile Id="$ProviderName.Verbose.File" Name="$ProviderName" Description="$ProviderName.1" LoggingMode="File" DetailLevel="Verbose">
	<Collectors>
	  <EventCollectorId Value="EventCollector$ProviderName">
		<EventProviders>

"@
		$ProviderCount = 0
		for ($i = 0; $i -lt $Provider[1].Count; $i++) {
			$Header += "`t`t`t<EventProviderId Value=`"$ProviderName$ProviderCount`" />`n"
			$ProviderCount++
		}

		$Header += @"
		</EventProviders>
	  </EventCollectorId>
	</Collectors>
  </Profile>
  <Profile Id="$ProviderName.Light.File" Name="$ProviderName" Description="$ProviderName.1" Base="$ProviderName.Verbose.File" LoggingMode="File" DetailLevel="Light" />
  <Profile Id="$ProviderName.Verbose.Memory" Name="$ProviderName" Description="$ProviderName.1" Base="$ProviderName.Verbose.File" LoggingMode="Memory" DetailLevel="Verbose" />
  <Profile Id="$ProviderName.Light.Memory" Name="$ProviderName" Description="$ProviderName.1" Base="$ProviderName.Verbose.File" LoggingMode="Memory" DetailLevel="Light" />

"@

		# Keep track of the providers that are currently running
		Out-File -FilePath "$_CONTAINER_DIR\RunningProviders.txt" -InputObject "$ProviderName" -Append
	}


	$Header += $Footer

	# Writing to a file
	Out-file -FilePath "auth.wprp" -InputObject $Header -Encoding ascii

}

function Start-NanoTrace {
	param($ContainerId)

	# Event Logs
	foreach ($EventLog in $_EVENTLOG_LIST_START) {
		$EventLogParams = $EventLog.Split("!")
		$EventLogName = $EventLogParams[0]
		$EventLogOptions = $EventLogParams[1]

		$ExportLogName += ".evtx"

		if ($EventLogOptions -ne "NONE") {
			Invoke-Container -ContainerId $ContainerId -Nano -Record -Command "wevtutil set-log $EventLogName /enabled:true /rt:false /q:true"

			if ($EventLogOptions.Contains("EXPORT")) {
				$ExportName = $EventLogName.Replace("Microsoft-Windows-", "").Replace(" ", "_").Replace("/", "_")
				Invoke-Container -ContainerId $ContainerId -Nano -Record -PreTrace -Command "wevtutil export-log $EventLogName $ExportName /overwrite:true"
			}
			if ($EventLogOptions.Contains("CLEAR")) {
				Invoke-Container -ContainerId $ContainerId -Nano -Record -Command "wevtutil clear-log $EventLogName"
			}
			if ($EventLogOptions.Contains("SIZE")) {
				Invoke-Container -ContainerId $ContainerId -Nano -Record -Command "wevtutil set-log $EventLogName /ms:102400000"
			}
		}
	}

	# Reg Add
	foreach ($RegAction in $_REG_ADD_START) {
		$RegParams = $RegAction.Split("!")
		$RegKey = $RegParams[0]
		$RegName = $RegParams[1]
		$RegType = $RegParams[2]
		$RegValue = $RegParams[3]

		Invoke-Container -ContainerId $ContainerId -Nano -Record -Command "reg add $RegKey /v $RegName /t $RegType /d $RegValue /f"
	}

	Get-Content "$_CONTAINER_DIR\RunningProviders.txt" | ForEach-Object {
		Invoke-Container -ContainerId $ContainerId -Nano -Record -Command "wpr -start auth.wprp!$_ -instancename $_"
	}


}

function Stop-NanoTrace {
	param($ContainerId)

	Get-Content "$_CONTAINER_DIR\RunningProviders.txt" | ForEach-Object {
		Invoke-Container -ContainerId $ContainerId -Nano -AuthDir -Record -Command "wpr -stop $_`.etl -instancename $_"
	}

	# Cleaning up registry keys
	foreach ($RegDelete in $_REG_DELETE) {
		$DeleteParams = $RegDelete.Split("!")
		$DeleteKey = $DeleteParams[0]
		$DeleteValue = $DeleteParams[1]
		Invoke-Container -ContainerId $ContainerId -Nano -Record -Command "reg delete `"$DeleteKey`" /v $DeleteValue /f"
	}

	# Querying registry keys
	foreach ($RegQuery in $_REG_QUERY) {
		$QueryParams = $RegQuery.Split("!")
		$QueryKey = $QueryParams[0]
		$QueryOptions = $QueryParams[1]
		$QueryOutput = $QueryParams[2]

		$QueryOutput = "$QueryOutput`-key.txt"
		$AppendFile = Invoke-Container -ContainerId $ContainerId -AuthDir -Nano -Command "if exist $QueryOutput (echo True)"

		Write-Verbose "Append Result: $AppendFile"
		$Redirect = "> $QueryOutput"

		if ($AppendFile -eq "True") {
			$Redirect = ">> $QueryOutput"
		}


		if ($QueryOptions -eq "CHILDREN") {
			Invoke-Container -ContainerId $ContainerId -AuthDir -Nano -Record -Command "reg query `"$QueryKey`" /s $Redirect"
		}
		else {
			Invoke-Container -ContainerId $ContainerId -AuthDir -Nano -Record -Command "reg query `"$QueryKey`" $Redirect"
		}

	}

	foreach ($EventLog in $_EVENTLOG_LIST_STOP) {
		$EventLogParams = $EventLog.Split("!")
		$EventLogName = $EventLogParams[0]
		$EventLogOptions = $EventLogParams[1]

		$ExportName = $EventLogName.Replace("Microsoft-Windows-", "").Replace(" ", "_").Replace("/", "_")

		if ($EventLogOptions -ne "DEFAULT") {
			Invoke-Container -ContainerId $ContainerId -Nano -Record -Command "wevtutil set-log $EventLogName /enabled:false"
		}

		Invoke-Container -ContainerId $ContainerId -Nano -Record -AuthDir -Command "wevtutil export-log $EventLogName $ExportName.evtx /overwrite:true"

		if ($EventLogOptions -eq "ENABLE") {
			Invoke-Container -ContainerId $ContainerId -Nano -Record -Command "wevtutil set-log $EventLogName /enabled:true /rt:false" *>> $_CONTAINER_DIR\container-output.txt
		}
	}
}
#endregion container_functions

#region FW_functions

function FWStart-ContainerTracing
{
	Param(
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[String]$containerId,
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[String]$TSSScriptsSourceFolderonHost,
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[String]$TSSScriptTargetFolderInContainer,
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[String]$TSSStartCommandToExecInContainer,
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[String]$TSSWorkingFolderInContainer
	)
	EnterFunc $MyInvocation.MyCommand.Name

	# Confirm that docker is in our path
	$DockerExists = (Get-Command "docker.exe" -ErrorAction SilentlyContinue) -ne $null
	if ($DockerExists) {
		LogInfo "Docker.exe found"
		$RunningContainers = $(docker ps -q)
		if ($containerId -in $RunningContainers) {
			LogInfo "$containerId found"
			$_CONTAINER_DIR = "$_BASE_C_DIR`-$containerId"
			if ((Test-Path $_CONTAINER_DIR\started.txt)) {
				LogInfo "Container tracing already started. Please run $($global:ScriptName) -stop to stop the tracing and start tracing again"
					exit
				}
			New-Item $_CONTAINER_DIR -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
			Remove-Item $_CONTAINER_DIR\* -Recurse -ErrorAction SilentlyContinue | Out-Null

			# Confirm the running container base image
			if (Check-ContainerIsNano -ContainerId $containerId) {

				LogInfo "Container Image is NanoServer"
				Out-File -FilePath $_CONTAINER_DIR\container-base.txt -InputObject "Nano"

				# We need to use the wprp for the auth data collection
				if (!(Test-Path "$_CONTAINER_DIR\auth.wprp") -and !(Test-Path "$_CONTAINER_DIR\RunningProviders.txt")) {
					Generate-WPRP -ContainerId $containerId
				}

				# Checking if the container has the tracing scripts
				if (Check-ContainsScripts -ContainerId $containerId -IsNano) {
					LogInfo "Starting container tracing - please wait..."
					Start-NanoTrace -ContainerId $containerId
				}
				else {
					LogInfo "Container: $containerId missing tracing script!" Yellow
					# $_BASE_LOG_DIR could be used insted of C:\authscripts
					LogInfo "Please copy the auth.wprp into the $TSSScriptTargetFolderInContainer\TSSv2 directory in the container then run $($global:ScriptName) -containerId $containerId $TSSCommand again
	Example:
	`tdocker stop $containerId
	`tdocker cp auth.wprp $containerId`:\$TSSScriptTargetFolderInContainer
	`tdocker start $containerId
	`t.\$($global:ScriptName) -containerId $containerId $TSSStartCommandToExecInContainer" Yellow
						return
				}

			}
			else {
				LogInfo "Container Image is Standard"
				Out-File -FilePath $_CONTAINER_DIR\container-base.txt -InputObject "Standard"

				if (Check-ContainsScripts -ContainerId $containerId) {
					LogInfo "Starting container tracing - please wait..."
					Invoke-Container -ContainerId $ContainerId -Record -Command "TSSv2\$($global:ScriptName) $TSSStartCommandToExecInContainer"
				}
				else {

				LogInfo "Copy TSS script to container started."
				docker stop $containerId 2>&1 | Out-Null
				docker cp $TSSScriptsSourceFolderonHost $containerId`:\$TSSScriptTargetFolderInContainer 2>&1 | Out-Null
				docker start $containerId 2>&1 | Out-Null
				LogInfo "Copy TSS script to container completed."
				LogInfo "Starting trace command $($global:ScriptName) $TSSStartCommandToExecInContainer"
				Invoke-Container -ContainerId $ContainerId -Record -Command "TSSv2\$($global:ScriptName) $TSSStartCommandToExecInContainer"
				LogInfo "TSS Tracing started, tracing runs, please use $($global:ScriptName) -Stop command to stop tracing"
				<#
					LogInfo "Please copy $TSSScriptsSourceFolderonHost into the $TSSScriptTargetFolderInContainer directory in the container and run TSS.ps1 -containerId $containerId $TSSStartCommandToExecInContainer again
	Example:
	`tdocker stop $containerId
	`tdocker cp $TSSScriptsSourceFolderonHost $containerId`:\$TSSScriptTargetFolderInContainer
	`tdocker start $containerId
	`tdocker exec -w $TSSWorkingFolderInContainer $containerId powershell -ExecutionPolicy Unrestricted `".\TSS.ps1 $TSSStartCommandToExecInContainer`"" Yellow
	#>
					exit #return
				}
			}
		}
		else {
			LogInfo "Failed to find $containerId"
			return
		}
	}
	else {
		LogInfo "Unable to find docker.exe in system path."
		return
	}

	Check-GMSA-Start -ContainerId $containerId

	# Start Container Logging
	$installedBuildVer = New-Object System.Version([version]$Global:OS_Version)
	$minPktMonBuildVer = New-Object System.Version([version]("10.0.17763.1852"))
	if ($($installedBuildVer.CompareTo($minPktMonBuildVer)) -ge 0) { # if installed Build version is greater than OS Build 17763.1852 from KB5000854
		pktmon start --capture -f $_CONTAINER_DIR\Pktmon.etl -s 4096 2>&1 | Out-Null
	}
	else {
		netsh trace start capture=yes persistent=yes report=disabled maxsize=4096 scenario=NetConnection traceFile=$_CONTAINER_DIR\netmon.etl | Out-Null
	}

	Add-Content -Path $_CONTAINER_DIR\script-info.txt -Value ("Data collection started on: " + (Get-Date -Format "yyyy/MM/dd HH:mm:ss"))
	Add-Content -Path $_CONTAINER_DIR\started.txt -Value "Started"

	return	
}

function FWStop-ContainerTracing
{
	Param(
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[String]$containerId,
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[String]$TSSStopCommandToExecInContainer,
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[String]$TSSWorkingFolderInContainer
	)
	EnterFunc $MyInvocation.MyCommand.Name

	$_CONTAINER_DIR = "$_BASE_C_DIR`-$containerId"

   # no need to check this again
   # if (!(Test-Path "$_CONTAINER_DIR\started.txt")) {
   #		 LogInfo "Container tracing already started. Please run TSS.ps1 $TSSStopCommandToExecInContainer to stop the tracing and start tracing again"
   #		 return
   #  }

	LogInfo "Stopping Container tracing"
	$RunningContainers = $(docker ps -q)
	if ($containerId -in $RunningContainers) {
		LogInfo "$containerId Found"
		LogInfo "Stopping data collection..."
		if ((Get-Content $_CONTAINER_DIR\container-base.txt) -eq "Nano") {
			LogInfo "Stopping Nano container data collection"
			# NOTE(will) Stop the wprp
			Stop-NanoTrace -ContainerId $containerId
		}
		else {
			LogInfo "Stopping Standard container data collection"
			Invoke-Container -ContainerId $containerId -Record -Command "TSSv2\$($global:ScriptName) $($TSSStopCommandToExecInContainer)"
		}
	}
	else {
		LogInfo "Failed to find $containerId"
		return
	}

	LogInfo "`Collecting Container Host Device configuration information, please wait..."
	Check-GMSA-Stop -ContainerId $containerId
	Get-ContainersInfo -ContainerId $containerId

	# Stop Pktmon
	if ((Get-HotFix | Where-Object { $_.HotFixID -gt "KB5000854" -and $_.Description -eq "Update" } | Measure-object).Count -ne 0) { #we# better check for OS Build 17763.1852 or higher!
		pktmon stop 2>&1 | Out-Null
		pktmon list -a > $_CONTAINER_DIR\pktmon_components.txt
	}
	else {
		# consider removing it and using TSS FW for network trace 
		netsh trace stop | Out-Null
	}

	Add-Content -Path $_CONTAINER_DIR\script-info.txt -Value ("Data collection stopped on: " + (Get-Date -Format "yyyy/MM/dd HH:mm:ss"))
	if ((Test-Path $_CONTAINER_DIR\started.txt)) {
		Remove-Item -Path $_CONTAINER_DIR\started.txt -Force | Out-Null
		}



	LogInfo "The tracing is stopping, please wait..."
	docker stop $containerId 2>&1 | Out-Null
	docker cp $containerId`:\MS_DATA $_CONTAINER_DIR 2>&1 | Out-Null
	docker start $containerId 2>&1 | Out-Null
	LogInfo "Data copied to $_CONTAINER_DIR"
	docker exec --privileged $containerId cmd /c rd /s /q C:\TSS
	docker exec --privileged $containerId cmd /c rd /s /q c:\MS_DATA
	LogInfo "The tracing has been completed, please find the data in $_CONTAINER_DIR on the host machine."

	<#Please copy the collected data to the logging directory"
		LogInfo "Example:
	`tdocker stop $containerId
	`tdocker cp $containerId`:\MS_DATA $_CONTAINER_DIR
	`tdocker start $containerId" Yellow
	 #>
	 return

}


function global:FWEnter-ContainerTracing
{
	Param(
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[String]$fwcontainerId,
		[parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[String]$fwTSSScriptsSourceFolderonHost,
		[parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[String]$fwTSSScriptTargetFolderInContainer,
		[parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[String]$fwTSSStartCommandToExecInContainer,
		[parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[String]$fwTSSStopCommandToExecInContainer
	)
	EnterFunc $MyInvocation.MyCommand.Name


	$_BASE_LOG_DIR = "C:\MS_DATA" #$global:LogFolder #".\authlogs"
	$_LOG_DIR = $_BASE_LOG_DIR
	$_CH_LOG_DIR = "$_BASE_LOG_DIR\container-host"
	$_BASE_C_DIR = "$_BASE_LOG_DIR`-container"
	$_C_LOG_DIR = "$_BASE_LOG_DIR\container"

	$TSScontainerId = $fwcontainerId 
	$TSSScriptsSourceFolderonHost = (Get-Location).Path #Split-Path (Get-Location).Path -parent
	$TSSScriptTargetFolderInContainer =  "TSS" # we should always use "TSS", if required use $fwTSSScriptTargetFolderInContainer
	$TSSWorkingFolderInContainer = "$fwTSSScriptTargetFolderInContainer\TSSv2"
	$TSSStartCommandToExecInContainer = $fwTSSStartCommandToExecInContainer
	$TSSStopCommandToExecInContainer = $fwTSSStopCommandToExecInContainer

	if (($TSSStartCommandToExecInContainer -ne "") -and ($TSSStopCommandToExecInContainer -ne ""))
	{
		LogInfo ("Invalid Call to FWEnter-ContainerTracing: please specify start or stop tracing command, not both of them at the same time")
		Exit
	}

	if ($TSSStartCommandToExecInContainer -ne "")
	{
	FWStart-ContainerTracing -containerId $TSScontainerId -TSSScriptsSourceFolderonHost $TSSScriptsSourceFolderonHost `
			-TSSScriptTargetFolderInContainer $TSSScriptTargetFolderInContainer -TSSStartCommandToExecInContainer $TSSStartCommandToExecInContainer -TSSWorkingFolderInContainer $TSSWorkingFolderInContainer
	}
	elseif ($TSSStopCommandToExecInContainer -ne "")
	{
		FWStop-ContainerTracing -containerId $TSScontainerId -TSSStopCommandToExecInContainer $TSSStopCommandToExecInContainer -TSSWorkingFolderInContainer $TSSWorkingFolderInContainer
	}
	else
	{
		LogInfo ("Please specify either start or stop command")
	}

}

#endregion FW_functions

Export-ModuleMember -Function * -Cmdlet * -Variable * -Alias *


# SIG # Begin signature block
# MIIoLQYJKoZIhvcNAQcCoIIoHjCCKBoCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCblBjx4unD4+H1
# tG/2eGceARcx2lhuheKOXyBS2B3owKCCDXYwggX0MIID3KADAgECAhMzAAADrzBA
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
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIC0biaqHKhaMNOV/PYU4ynEe
# hJhC7Vx9B66GrhEtGCKtMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAL40S/ltZGtmscqb3uxsUrmAgpYRBzztXEJbCAtSnmn10HJjhtRM7bx2p
# 2UzDDRX8XlMmA6LSbiheciy+ziNSjMJGSevsZjD/QwLAW5fBf1sqQxWQLi2AN2te
# USN01+Zv0Kv/pPotNHG8sVYKciU7wc4ST0GAeaZ/G0hri8u7J847JdLXNc47CHnk
# BWp9CZjEEMkRNr6j9n4B5sjzM8KvTPF9vgMfN8H+JeEhR8PwTpNvh27x2/ok7GkA
# 7H3zp82YqfOaY5vwLpfIAn2IkmmakUG1NifBd3dXFaw/cWgMKrkt1RO1SmInJ4Gq
# znBv9KvUdiIgSNbkqzqUVi1lAYzm/KGCF5cwgheTBgorBgEEAYI3AwMBMYIXgzCC
# F38GCSqGSIb3DQEHAqCCF3AwghdsAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsq
# hkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCAXeOmlkYK41cCUZ3gDBhDZCsAX+clc+BlrzvR1Tu2fCwIGZc4Fupm5
# GBMyMDI0MDIyMDEyMTU1NC4wMzNaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTAwMC0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wg
# ghHtMIIHIDCCBQigAwIBAgITMwAAAevgGGy1tu847QABAAAB6zANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yMzEyMDYxODQ1
# MzRaFw0yNTAzMDUxODQ1MzRaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25z
# MScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTAwMC0wNUUwLUQ5NDcxJTAjBgNV
# BAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQDBFWgh2lbgV3eJp01oqiaFBuYbNc7hSKmktvJ15NrB
# /DBboUow8WPOTPxbn7gcmIOGmwJkd+TyFx7KOnzrxnoB3huvv91fZuUugIsKTnAv
# g2BU/nfN7Zzn9Kk1mpuJ27S6xUDH4odFiX51ICcKl6EG4cxKgcDAinihT8xroJWV
# ATL7p8bbfnwsc1pihZmcvIuYGnb1TY9tnpdChWr9EARuCo3TiRGjM2Lp4piT2lD5
# hnd3VaGTepNqyakpkCGV0+cK8Vu/HkIZdvy+z5EL3ojTdFLL5vJ9IAogWf3XAu3d
# 7SpFaaoeix0e1q55AD94ZwDP+izqLadsBR3tzjq2RfrCNL+Tmi/jalRto/J6bh4f
# PhHETnDC78T1yfXUQdGtmJ/utI/ANxi7HV8gAPzid9TYjMPbYqG8y5xz+gI/SFyj
# +aKtHHWmKzEXPttXzAcexJ1EH7wbuiVk3sErPK9MLg1Xb6hM5HIWA0jEAZhKEyd5
# hH2XMibzakbp2s2EJQWasQc4DMaF1EsQ1CzgClDYIYG6rUhudfI7k8L9KKCEufRb
# K5ldRYNAqddr/ySJfuZv3PS3+vtD6X6q1H4UOmjDKdjoW3qs7JRMZmH9fkFkMzb6
# YSzr6eX1LoYm3PrO1Jea43SYzlB3Tz84OvuVSV7NcidVtNqiZeWWpVjfavR+Jj/J
# OQIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFHSeBazWVcxu4qT9O5jT2B+qAerhMB8G
# A1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCG
# Tmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUy
# MFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4w
# XAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwG
# A1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQD
# AgeAMA0GCSqGSIb3DQEBCwUAA4ICAQCDdN8voPd8C+VWZP3+W87c/QbdbWK0sOt9
# Z4kEOWng7Kmh+WD2LnPJTJKIEaxniOct9wMgJ8yQywR8WHgDOvbwqdqsLUaM4Nre
# rtI6FI9rhjheaKxNNnBZzHZLDwlkL9vCEDe9Rc0dGSVd5Bg3CWknV3uvVau14F55
# ESTWIBNaQS9Cpo2Opz3cRgAYVfaLFGbArNcRvSWvSUbeI2IDqRxC4xBbRiNQ+1qH
# XDCPn0hGsXfL+ynDZncCfszNrlgZT24XghvTzYMHcXioLVYo/2Hkyow6dI7uULJb
# KxLX8wHhsiwriXIDCnjLVsG0E5bR82QgcseEhxbU2d1RVHcQtkUE7W9zxZqZ6/jP
# maojZgXQO33XjxOHYYVa/BXcIuu8SMzPjjAAbujwTawpazLBv997LRB0ZObNckJY
# yQQpETSflN36jW+z7R/nGyJqRZ3HtZ1lXW1f6zECAeP+9dy6nmcCrVcOqbQHX7Zr
# 8WPcghHJAADlm5ExPh5xi1tNRk+i6F2a9SpTeQnZXP50w+JoTxISQq7vBij2nitA
# sSLaVeMqoPi+NXlTUNZ2NdtbFr6Iir9ZK9ufaz3FxfvDZo365vLOozmQOe/Z+pu4
# vY5zPmtNiVIcQnFy7JZOiZVDI5bIdwQRai2quHKJ6ltUdsi3HjNnieuE72fT4eWh
# xtmnN5HYCDCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZI
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
# MCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOkEwMDAtMDVFMC1EOTQ3MSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQCA
# Bol1u1wwwYgUtUowMnqYvbul3qCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA6X5ypjAiGA8yMDI0MDIyMDAwMzY1
# NFoYDzIwMjQwMjIxMDAzNjU0WjB3MD0GCisGAQQBhFkKBAExLzAtMAoCBQDpfnKm
# AgEAMAoCAQACAhuPAgH/MAcCAQACAhLTMAoCBQDpf8QmAgEAMDYGCisGAQQBhFkK
# BAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJ
# KoZIhvcNAQELBQADggEBAJdEwt4I+Zb1EWFtkSN3d6aUjw8PZwdXP8kP1PZ/k+4B
# /q59gq6i989T+xrszxWaBdvXHmFuJs1jse/3Lisai4vLGotBQ6aHR7HGw+EkJtxK
# f1sFzH9OPc7Ag+8enJ4mmgmvQ4tw9hsgtnZz9h0dMj8gw4/E19o4iAaXsVIOmMWe
# S9ujlgeFZxqPpDrjs40CKx/7RgjxXErHs898wYrFNOOIc9CT1iyr+DDADPTCI/fK
# 1c1NXG5YRC9Z1a32BJeFEB+tVQ8cPWHINl7ZpLmQAdJqw7/X1lacq8yf4WLJ6wiq
# eHoRQsshXHUfe7HmvUbSq79+4MB9QikBmkkNU6FPsIsxggQNMIIECQIBATCBkzB8
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1N
# aWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAevgGGy1tu847QABAAAB
# 6zANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEE
# MC8GCSqGSIb3DQEJBDEiBCB5zjxwjlCwHcYIKtEOosXTEMIsLFKEaAsntohrzX/T
# +TCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIM63a75faQPhf8SBDTtk2DSU
# gIbdizXsz76h1JdhLCz4MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTACEzMAAAHr4BhstbbvOO0AAQAAAeswIgQgYzLPB6A03xqlxyuMg5gDUI5t
# lYUbwgT0+N2Mwbrer08wDQYJKoZIhvcNAQELBQAEggIAMAfx2jq1wUzihX+uGfm1
# rUWC0Vaic9uAncSRo8bEOF/cr90FaFFDRRwiVVb1xPaLDC5fa6G3c5bV0M6XfN+W
# xUhGqJyxp4OCB1xz/+cQtlQy76lITB/w9/7iSo0DpE27i3KyuNHxZQ4eVm/FK8TG
# ZfQaMMLfLo03hJPaVROsKtgCG2Mng8ESNcpreFx790zXMXxR34kpXr85KIYvvHVk
# gWDfEnJM0WE3ioA9PltQA6npmID/TSA0/ki38fcJj6OGHcuLqFd4CCaN1oiMA/zM
# gZEOpxzpa1b60bKagGfulHs7yNoSIMJnMlT/dteaKtWZXTRgEYqVVMKE35uDnZTR
# N+e+cYHJJvegva9rrxseOB/OkWRm4qygiStwCl/pu+NCuxBa9Bz4HAp5izSRpANx
# nGTPLqbhnYNN9Nodv3YCMKK1GDwPn1iAQBl/zOb7vMTHadIOSElSAkANEMIWTNQL
# I+mEuCwlji6F5ZawGx+iwtYPsf9sqx/OfY5Wx6IM5EuVDC93sP0KK9R+wGJ/Lqrj
# kW87wuPoBMqAu2fAkB/St7CzgnKeP6Kur92LZfx33iqtHCUE6uV6XjxrQkTUc5Bv
# qW72EdaU2ARItw2xwkubqIOc3rJHxeBBS93t9U7st4fqbQXqw2xUdglL3cIFwiKm
# Xi8l0/C16s725GqewH2WiWg=
# SIG # End signature block
