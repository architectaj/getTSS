﻿# diag_net.ps1
# Created by tdimli
# March 2020
#
# Diagnostic functions for NET area

# version
$NET_version = "1.0.231214.0"

# Area and Area/Component arrays
$NET = @("BranchCache", "DAsrv", "DhcpSrv", "DNScli", "DNSsrv", "Firewall", "HTTP", "HypHost", "NCSI", "NetIO", "Proxy", "rpc", "smbcli", "srv", "VPN", "WFP", "WLAN") #"802Dot1x", "Auth", "BITS", "Container", "CSC", "DAcli", "DFScli", "DFSsrv", "DHCPcli", "General", "HypVM", "IIS", "IPAM", "MsCluster", "MBAM", "MBN", "Miracast", "NCSI", "NFScli", "NFSsrv", "NLB", "NPS", "RAS", "RDMA", "RDScli", "RDSsrv" "SDN" "SdnNC" "SQLtrace" "SBSL" "UNChard" "Winsock" "WIP" "WNV" "Workfolders"

#Component/Diagnostic Function arrays
#$802dot1x = @("net_802dot1x_KB4556307")
$branchcache = @("net_branchcache_KB4565457")
$dasrv = @("net_dasrv_KB4504598")
$dhcpsrv = @("net_dhcpsrv_KB4503857")
$dnscli = @("net_dnscli_KB4562541", "net_dnscli_KB4617560")
$dnssrv = @("net_dnssrv_KB4561750", "net_dnssrv_KB4569509", "net_dnssrv_KB5034471")
$firewall = @("net_firewall_KB4561854")
$http = @("net_http_KB5033495")
$hyphost = @("net_hyphost_KB4562593")
$ncsi = @("net_vpn_KB4550202", "net_proxy_KB4569506", "net_ncsi_KB4648334")
$netio = @("net_netio_KB4563820")
$proxy = @("net_proxy_KB4569506")
$rpc = @("net_rpc_KB2506972")
$smbcli = @("net_smbcli_KB5027830")
$srv = @("net_srv_KB4562940", "net_srv_KB4612362")
$wfp = @("net_netio_KB4563820")
$vpn = @("net_vpn_KB4553295", "net_vpn_KB4550202", "net_dnscli_KB4562541", "net_proxy_KB4569506")
$wlan = @("net_wlan_KB4557342")

# begin: diagnostic functions

#region 802dot1x
#region net_802dot1x_KB4556307
<# 
Component: 802dot1x
Checks for:
 A post-release issue starting with Feb 2020 updates
 Resolved in 2020.4B and later
 Network indication is skipped when a 802.1x re-auth occurs.
 If account-based VLANs are used, then this may cause connectivity issues
Created by: tdimli
#>
function net_802dot1x_KB4556307
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

    $issueMsg = "
Following 802.1x network adapter (wired or wireless) is in connected state
but has no connectivity:

{0}

You might be hitting an issue affecting wired 802.1x adapters when user logon
triggers a change of VLAN.

Resolution:
Please install following Windows Update (or a later one) to resolve 
this issue:

April 14, 2020—KB4549951 (OS Builds 18362.778 and 18363.778)
https://support.microsoft.com/help/4549951/windows-10-update-kb4549951

 - Addresses an issue that prevents a wired network interface from obtaining a
 new Dynamic Host Configuration Protocol (DHCP) IP address on new subnets and 
 virtual LANs (VLAN) after wired 802.1x re-authentication. The issue occurs if
 you use VLANs that are based on accounts and a VLAN change occurs after a user
 signs in.
"
    # updates (oldest update first), which when installed, may lead to this issue
    $effectingUpdates = @("KB4535996","KB4540673","KB4551762","KB4541335","KB4554364")
    # updates (oldest update first), which when installed, resolve this issue
    $resolvingUpdates = @("KB4549951","KB4550945", "KB4556799")

    if($offline) {
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }

    # issue only affects Win10 1903 or later, skip if earlier OS
    $curBuild = [Convert]::ToUInt32($wmi_Win32_OperatingSystem.BuildNumber)
    $reqBuild = 18362
    if ($curBuild -lt $reqBuild ) {
        LogWrite "OS version $($wmi_Win32_OperatingSystem.Version) not affected, skipping"
        return $RETURNCODE_SKIPPED
    }

    # Look for the issue
    $services = Get-Service -Name "dot3svc" -ErrorAction Ignore

    # issue only occurs with Wired Autoconfig, skip if it's not running
    if(($services.Count -eq 0) -or ($services.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running)) {
        # dot3svc (Wired AutoConfig) not running, nothing to check
        LogWrite "Wired AutoConfig (dot3svc) service is not running, nothing to check, skipping"
        return $RETURNCODE_SKIPPED
    }

    # dot3svc (Wired AutoConfig) is running
    try {
        $hotfixes = (Get-HotFix | Sort-Object -Property InstalledOn -Descending)
        foreach($hotfix in $hotfixes) {
            # look if any of the resolving updates that resolve this issue are installed
            if($resolvingUpdates.Contains($hotfix.HotFixID)) {
                LogWrite ("A resolving update ({0}) is installed!" -f $hotfix.HotFixID)
                break
            }
            # look if any of the effecting updates are installed
            if($effectingUpdates.Contains($hotfix.HotFixID)) {
                LogWrite ("An affected update ({0}) is installed!" -f $hotfix.HotFixID)
                # effecting update(s) installed, check for issue
                $netadapters = Get-NetAdapter
                foreach($netadapter in $netadapters) {
                    if(($netadapter.MediaConnectState -eq 1) -and ($netadapter.MediaType -eq "802.3")) { 
                        # adapter in connected state, test connectivity
                        LogWrite ("Testing adapter [{0}] for issue..." -f $netadapter.Name)
                        $netipconfig = Get-NetIPConfiguration -InterfaceIndex $netadapter.ifIndex
                        # has IP address?
                        if($netipconfig.IPv4Address.Count -gt 0) {
                            LogWrite "Pinging default gateway..."
                            $result = Test-Connection -ComputerName $netipconfig.IPv4DefaultGateway.NextHop -Count 1 -Quiet 
                            LogWrite ("Test-Connection returned: {0}" -f $result)
                            if($result -eq $false) {
                                # try again with ping count=4 to avoid false positives
                                $result = Test-Connection -ComputerName $netipconfig.IPv4DefaultGateway.NextHop -Count 4 -Quiet 
                                LogWrite ("Test-Connection (second try) returned: {0}" -f $result)
                                if($result -eq $false) {
                                    # Issue present
                                    $adapterInfo = "`tName: " + $netadapter.Name + ", IP Address: " + $netipconfig.IPv4Address
                                    $issueMsg = [string]::Format($issueMsg, $adapterInfo)
                                    ReportIssue $issueMsg $ISSUETYPE_ERROR #$effectingUpdates $resolvingUpdates
                                    # reporting one instance of the issue is sufficient
                                    break
                                }
                            }
                        }
                    }
                }
                # run the test once
                break
            }
        }
    }
    catch {
        LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_802Dot1x_KB4556307
#endregion 802dot1x

#region branchcache
#region net_branchcache_KB4565457
<# 
Component: BranchCache
Checks for:
 An open issue for systems that have configured BranchCache
 If the nummber of BranchCache *.dat files exceeds 1024, then this may cause not shrinking BC issues when it exceeds 180% of configured size
Created by: waltere
#>
function net_branchcache_KB4565457
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

    $issueMsg = "
This computer appears to be affected by a known issue:
BranchCache may fail to shrink cache size (CurrentSizeOnDiskAsNumberOfBytes) if 
the number of *.dat files exceeds 1024 in any PeerDistRepub subfolder, e.g.:
 C:\Windows\ServiceProfiles\NetworkService\AppData\Local\PeerDistRepub\Store\0\*.dat
or 
the total number of *.dat files exceeds 1024 AND 
CurrentSizeOnDiskAsNumberOfBytes breaches the 180% limit of configured MaxCacheSizeAsNumberOfBytes
The CurrentSizeOnDiskAsNumberOfBytes will never decrease as expected.

Note: This might not be directly related to the issue you are troubleshooting.

Indicators of this issue:
 - Number of *.dat files is higher than 1024 
 - CurrentSizeOnDiskAsNumberOfBytes exceeds 1.8 * MaxCacheSizeAsNumberOfBytes
 
Current Branch DataCache usage:
`t MaxCacheSizeAsPercentageOfDiskVolume : {0}
`t MaxCacheSizeAsNumberOfBytes          : {1}
`t CurrentSizeOnDiskAsNumberOfBytes     : {2} ( = {8} % of configured size)
`t CurrentActiveCacheSize               : {3}
`t Total number of *.dat files          : {4}
`t Number of *.dat files in subfolder   : {5} in Folder {6}

{7}

Resolution:
If you need to free the cache, following PowerShell cmdlet can be used to 
delete all data in all cache files:
 Clear-BCCache
"

    if($offline) {
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }

    # Look for the issue
	try	{
	    $curBuild = [Convert]::ToUInt32($wmi_Win32_OperatingSystem.BuildNumber)
        $minBuild = 10000
        if ($curBuild -lt $minBuild ) {
            LogWrite "OS version $($wmi_Win32_OperatingSystem.Version) not affected, skipping"
            return $RETURNCODE_SKIPPED
        }

        $bcs = (Get-BCStatus -ErrorAction Ignore)
        if ($bcs -eq $null) {
            LogWrite "Branchcache not installed, skipping"
            return $RETURNCODE_SKIPPED
        }

        if (!$bcs.BranchCacheIsEnabled) {
            LogWrite "Branchcache not enabled, skipping"
            return $RETURNCODE_SKIPPED
        }

        $bcd = (Get-BCDataCache -ErrorAction Ignore)
        if ($bcd -eq $null) {
            LogWrite "Get-BCDataCache failed, skipping"
            return $RETURNCODE_SKIPPED
        }

		$MaxCacheSizeAsPercentageOfDiskVolume = $bcd.MaxCacheSizeAsPercentageOfDiskVolume
		$MaxCacheSizeAsNumberOfBytes = $bcd.MaxCacheSizeAsNumberOfBytes
		$CurrentSizeOnDiskAsNumberOfBytes = $bcd.CurrentSizeOnDiskAsNumberOfBytes
		$CurrentActiveCacheSize = $bcd.CurrentActiveCacheSize * 100 
		$TotNrOfDatFiles  = (Get-ChildItem $ENV:Windir\ServiceProfiles\NetworkService\AppData\Local\PeerDistRepub\Store\0\*.dat -Recurse -ErrorAction Ignore).Count
		$BCDiskUsageInPercent = [math]::Round($CurrentSizeOnDiskAsNumberOfBytes / $MaxCacheSizeAsNumberOfBytes * 100)
		$MaxFilesPerFolder = 1024	# no subfolder should contain more than 1024 *.dat files

		# PeerDistRepubFT: Table of  Directory  | Count | LastWriteTime
		foreach ($file in (Get-ChildItem "$ENV:Windir\ServiceProfiles\NetworkService\AppData\Local\PeerDistRepub\Store\0\" -Directory -ErrorAction Ignore))
        {
            $DatFilesCount = (Get-ChildItem $File.FullName -Recurse -File -ErrorAction Ignore).Count
            $DatFilesFolderName = $($File.FullName)
            if ($DatFilesCount -gt $MaxFilesPerFolder ) {
                break
            }
			$PeerDistRepubFT = [pscustomobject] @{
				'Directory' = $File.FullName
				'Count' = (Get-ChildItem $File.FullName -Recurse -ErrorAction Ignore).Count
				'LastWriteTime' = $File.LastWriteTime
			}
		}
		$Breach180percent = $MaxCacheSizeAsNumberOfBytes * 1.8
		# Issue present if one subfolder exceeds $DatFilesCount -gt 1024
		if (($DatFilesCount -ge $MaxFilesPerFolder ) -or ($CurrentSizeOnDiskAsNumberOfBytes -gt $Breach180percent)) {
			# Issue detected
			$issueMsg = [string]::Format($issueMsg, $MaxCacheSizeAsPercentageOfDiskVolume, $MaxCacheSizeAsNumberOfBytes, $CurrentSizeOnDiskAsNumberOfBytes, $CurrentActiveCacheSize, $TotNrOfDatFiles, $DatFilesCount, $DatFilesFolderName, $PeerDistRepubFT, $BCDiskUsageInPercent)
			ReportIssue $issueMsg $ISSUETYPE_WARNING
		}
	}
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_branchcache_KB4565457
#endregion branchcache

#region dasrv
#region net_dasrv_KB4504598
<# 
Component: dasrv
Checks for:
 DA non-paged pool memory leak, tag NDnd
Created by: tdimli
#>
function net_dasrv_KB4504598
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offlin
    )

    $issueMsg = "
Considerable amount of non-paged pool memory is allocated with pool tag NDnd:

Tag  Bytes
NDnd {0}

On Direct Access Servers this may be caused by a known memory leak which 
can cause performance degradation due to reduced amount of memory left 
available. If the leak grows too large, it can also deplete the non-paged 
pool memory and may cause the server to crash.

Resolution
This issue is fixed for WS2016 with January 23, 2020 update KB4534307 :
  - Addresses an issue that might cause Direct Access servers to use a large 
  amount of non-paged pool memory ( pooltag: NDnd ). 

Issue is not present in WS2019 and later versions of Windows Servers.

For 2012R2, the solution is to upgrade to a later version where this issue does 
not occur.

Following workarounds can be used for 2012R2 until upgrade can be performed:
  1. Monitor the leak amount and restart servers regularly to avoid the leak 
  growing too large and to prevent NPP memory from being depleted.
  2. MTU size can be reduced down to 1232 bytes to try and avoid packet 
  fragmentation and the resulting leak. This did not work for most customers.
"

    $infoMsg = "
Considerable amount of non-paged pool memory is allocated with pool tag NDnd:

Tag  Bytes
NDnd {0}

Note: This might not be directly related to the issue you are troubleshooting.

This type of memory is used by NDIS to store network packet information.
This corresponds to more than 15K full-size Ethernet packets which is unusual 
and will benefit from further investigation.
Consider collecting an xperf trace, ensuring multiple allocs/leaks (at least 
1 MB) are captured in the trace. Poolmon can be used to monitor that:
  poolmon -iNDnd -p

Following command can be used to capture such a trace:
  1. xperf -on Base+CSwitch+POOL -stackwalk PoolAlloc+PoolFree+PoolAllocSession+PoolFreeSession -PoolTag NDnd -BufferSize 1024 -MaxBuffers 1024 -MaxFile 2048 -FileMode Circular 
  2. Wait for 5-10 minutes or until sufficient allocs/leaks are captured
  3. xperf -d c:\NDnd.etl 

Following command will capture a trace of size specified by MaxSize parameter 
and stop automatically (can also be stopped -if needed- by: xperf -stop):
  xperf -on Base+CSwitch+POOL -stackwalk PoolAlloc+PoolFree+PoolAllocSession+PoolFreeSession -PoolTag NDnd -BufferSize 1024 -MaxBuffers 1024 -MaxFile 1024 -f c:\NDnd.etl

Poolmon: https://docs.microsoft.com/en-us/windows-hardware/drivers/devtest/poolmon
xperf: https://docs.microsoft.com/en-us/windows-hardware/test/wpt/
"

    if($offline) {
        LogWrite "Running offline"
    }
    else {
        LogWrite "Running online"
    }

    # Look for the issue
	try	{
        $curBuild = [Convert]::ToUInt32($wmi_Win32_OperatingSystem.BuildNumber)
        $minBuild = 9200
        $maxBuild = 17134
        if (($curBuild -lt $minBuild) -or ($curBuild -gt $maxBuild)) {
            LogWrite "OS version $($wmi_Win32_OperatingSystem.Version) not affected, skipping"
            return $RETURNCODE_SKIPPED
        }

        # is DA running?
        $services = Get-Service -Name "RaMgmtSvc" -ErrorAction Ignore
        if (($services.Count -eq 0) -or ($services.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running)) {
            LogWrite "Not a DA Server, skipping"
            return $RETURNCODE_SKIPPED
        }

        $puSets = GetPoolUsageByTag "NDnd" "Nonp"
        if ($puSets.Count -gt 0) {
            $threshold = 30 * 1024 * 1024 # 30 MB / > 30K allocs
            $bytesInUse = 0
            foreach ($puSet in $puSets) {
                # find the highest bytes value
                if ($puSet[3] -gt $bytesInUse) {
                    $bytesInUse = $puSet[3]
                }
            }

            if ($bytesInUse -gt $threshold) {
                # we have high usage of NDnd which likely points to an issue
                $iType = $ISSUETYPE_INFO
                $iMsg = $infoMsg
		        $iMsg = [string]::Format($iMsg, $bytesInUse)
		        ReportIssue $iMsg $iType
            }
        }
	}
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_dasrv_KB4504598
#endregion dasrv

#region dhcpsrv
#region net_dhcpsrv_KB4503857
<#
Component: dhcpsrv
Checks for:
 The issue where a DHCP Server has Option 66 (Boot Server Host Name) defined
 but the name(s) cannot be resolved to IP addresses.
 This causes DHCP Server repeatedly spending time to resolve these names and
 prevents it from serving clients. This can cause DHCP outages.
Created by: tdimli
#>
function net_dhcpsrv_KB4503857
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

    $issueMsg = "
Following Option 66 (Boot Server Host Name) values are configured on this DHCP 
Server but cannot be resolved to IP address(es). This can cause a DHCP outage 
where DHCP clients will not be able to receive IP addresses!

Server name(s) that cannot be resolved:
=======================================
{0}
Option 66 config location(s):
=============================
{1}
Resolution:
===========
Check Option 66 entries listed above and ensure that all values are valid and 
any configured names can be resolved and resolved in a timely manner by the 
DHCP Server.

Option 66 entries can only contain a single hostname or IP address, multiple 
values within the same option are not supported. If there are any entries with 
multiple values, please correct them.

Please remove any Option 66 entries that
1. point to decommissioned servers or servers that do not exist anymore
2. are not being used anymore

For servers in the list that are still active and being used as boot servers:
1. Ensure DNS records are created for them so that the names can be resolved

To test if a name can be resolved: 
Command prompt: ping -4 <server-name>
Powershell: Resolve-DnsName -Name <server-name> -Type A
"

    if($offline) { 
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }

    # Resolve-DnsName requires WS2012 or later, skip if earlier OS
    $curBuild = [Convert]::ToUInt32($wmi_Win32_OperatingSystem.BuildNumber)
    $reqBuild = 9200
    if ($curBuild -lt $reqBuild ) {
        LogWrite "Cannot run on OS version $($wmi_Win32_OperatingSystem.Version), build $reqBuild or later required, skipping"
        return $RETURNCODE_SKIPPED
    }

    $services = Get-Service -Name "DHCPServer" -ErrorAction Ignore
    if(($services.Count -ne 1) -or ($services.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running)) {
        # No DHCP Server, nothing to check
        LogWrite "DHCPServer service is not running, nothing to check, skipping"
        return $RETURNCODE_SKIPPED
    }

    $dhcpexport = MakeFilename "dhcpexport" "xml"

    LogWrite "Exporting Dhcp Server data..."
    try{
        Export-DhcpServer -File $dhcpexport -Force 
    }
    catch {
        # export failed
        LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    LogWrite "Inspecting Dhcp Server data..."
    [xml]$Dhcp = Get-Content $dhcpexport

    $badOptions = ""
    $isCritical = $false
    $qTimeLimit = 1000 # anything -ge this will be considered critical failure
    [System.Collections.Generic.List[String]] $failedNames = New-Object "System.Collections.Generic.List[string]"

    # Check Server Options
    foreach ($option in $Dhcp.DHCPServer.IPv4.OptionValues.OptionValue) {
        if ($option.OptionId -eq 66) {
            if ($failedNames.Contains($option.Value)) {
                $qTime = 1
            }
            else {
                $qTime = ResolveDnsName $option.Value
            }
            if ($qTime -gt 0) {
                # failed, add error to return msg
                $badOptions += $option.Value + " (IPv4->Server Options)`r`n"
                if (!$failedNames.Contains($option.Value)) {
                    $failedNames.Add($option.Value)
                }
                if ($qTime -ge $qTimeLimit) {
                    # critical
                    $isCritical = $true
                    LogWrite "$($option.Value) [$qTime ms]"
                }
            }
        }
    }

    # Check IPv4 Policies
    foreach ($policy in $Dhcp.DHCPServer.IPv4.Policies.Policy) {
        foreach ($option in $policy.OptionValues.OptionValue) {
            if ($option.OptionId -eq 66) {
                if ($failedNames.Contains($option.Value)) {
                    $qTime = 1
                }
                else {
                    $qTime = ResolveDnsName $option.Value
                }
                if ($qTime -gt 0) {
                    # failed, add error to return msg
                    $badOptions += $option.Value + " (IPv4->Policies->" + $policy.Name + ")`r`n"
                    if (!$failedNames.Contains($option.Value)) {
                        $failedNames.Add($option.Value)
                    }
                    if ($qTime -ge $qTimeLimit) {
                        # critical
                        $isCritical = $true
                        LogWrite "$($option.Value) [$qTime ms]"
                    }
                }
            }
        }
    }

    # Check Scopes
    foreach ($scope in $Dhcp.DHCPServer.IPv4.Scopes.Scope) {

        # Scope Pptions
        foreach($option in $scope.OptionValues.OptionValue) {
            if ($option.OptionId -eq 66) {
                if ($failedNames.Contains($option.Value)) {
                    $qTime = 1
                }
                else {
                    $qTime = ResolveDnsName $option.Value
                }
                if ($qTime -gt 0) {
                    # failed, add error to return msg
                    $badOptions += $option.Value + " (IPv4->Scope[" + $scope.ScopeId + "])`r`n"
                    if (!$failedNames.Contains($option.Value)) {
                        $failedNames.Add($option.Value)
                    }
                    if ($qTime -ge $qTimeLimit) {
                        # critical
                        $isCritical = $true
                        LogWrite "$($option.Value) [$qTime ms]"
                    }
                }
            }
        }

        # Scope Policies
        foreach ($policy in $scope.Policies.Policy) {
            foreach ($option in $policy.OptionValues.OptionValue) {
                if ($option.OptionId -eq 66) {
                    if ($failedNames.Contains($option.Value)) {
                        $qTime = 1
                    }
                    else {
                        $qTime = ResolveDnsName $option.Value
                    }
                    if ($qTime -gt 0) {
                        # failed, add error to return msg
                        $badOptions += $option.Value + " (IPv4->Scope[" + $scope.ScopeId + "]->Policies->" + $policy.Name + ")`r`n"
                        if (!$failedNames.Contains($option.Value)) {
                            $failedNames.Add($option.Value)
                        }
                        if ($qTime -ge $qTimeLimit) {
                            # critical
                            $isCritical = $true
                            LogWrite "$($option.Value) [$qTime ms]"
                        }
                    }
                }
            }
        }
    }

    if ($failedNames.Count -gt 0){
        $failedNames.Sort()
        $tempInfo = ""
        foreach ($failedName in $failedNames) {
            $tempInfo += '"' + "$failedName" + '"' +"`r`n"
        }
        $issueMsg = [string]::Format($issueMsg, $tempInfo, $badOptions)
        $issueType = $ISSUETYPE_INFO
        if ($isCritical) {
            $issueType = $ISSUETYPE_ERROR
        }
        ReportIssue $issueMsg $issueType
    }
    else {
        # no issue found, no reason to keep DHCP Server export
        Remove-Item $dhcpexport -ErrorAction Ignore
    }

    return $RETURNCODE_SUCCESS
}

# Returns 
#  0 if name can be resolved
# or
#  query time in ms in case of failure
function ResolveDnsName
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [String]
        $DnsName
    )

    # no need to check if IP address
    try {
        if ($DnsName -match [IPAddress]$DnsName) {
            return 0
        }
    }
    catch {}

    $timeStart = (Get-Date).ToUniversalTime()
    $result = Resolve-DnsName -Name $DnsName -Type A -ErrorVariable DnsError -ErrorAction Ignore
    [UInt64] $timeTaken = ((Get-Date).ToUniversalTime() - $timeStart).TotalMilliseconds
    
    foreach($rec in $result) {
        if ($rec.IP4Address) {
            return 0
        }
    }

    if($timeTaken -eq 0){
        $timeTaken = 1 # return 1ms for 0ms failure case to avoid confusion with success case
    }

    return $timeTaken
}
#endregion net_dhcpsrv_KB4503857
#endregion dhcpsrv

#region dnscli
#region net_dnscli_KB4562541
<# 
Component: dnscli, vpn, da, ras
Checks for:
 The issue where multiple NRPT policies are configured and are in conflict.
 This will result in none of configured NRPT policies being applied.
Created by: tdimli 
#>
function net_dnscli_KB4562541
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

    $issueMsg = "
This computer has local NRPT rules configured when there are also domain 
group policy NRPT rules present. This can cause unexpected name resolution 
behaviour. 
When domain group policy NRPT rules are configured, local NRPT rules are 
ignored and not applied:
`tIf any NRPT settings are configured in domain Group Policy, 
`tthen all local Group Policy NRPT settings are ignored.

More Information:
https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn593632(v=ws.11)

Resolution:
Inspect configured NRPT rules and decide which ones to keep, local or domain 
Group Policy NRPT rules. 

Registry key where local group policy NRPT rules are stored:
  {0}

Registry key where domain group policy NRPT rules are stored:
  {1}

Note: Even if domain group policy registry key is empty, local group policy 
NRPT rules will still be ignored. Please delete the domain group policy 
registry key if it is not being used.
If it is being re-created, identify the policy re-creating it and remove the 
corresponding policy configuration.
"

    if($offline) {
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }

    # Look for the issue
    $localNRPTpath = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
    $domainNRPTpath = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\DnsClient"
    $DnsPolicyConfig = "DnsPolicyConfig"

    try
    {
        # are there any local NRPTs configured which risk being ignored?
        if ((Get-ChildItem -Path "Registry::$localNRPTpath\$DnsPolicyConfig" -ErrorAction Ignore).Count -gt 0) {
            # does domain policy NRPT key exist (empty or not)?
            $domainNRPT = (Get-ChildItem -Path "Registry::$domainNRPTpath" -ErrorAction Ignore)
            if ($domainNRPT -ne $null) {
                if ($domainNRPT.Name.Contains("$domainNRPTpath\$DnsPolicyConfig")) {
                    # issue present: domain Group Policy NRPT key present, local Group Policy NRPT settings are ignored
                    $issueMsg = [string]::Format($issueMsg, "$localNRPTpath\$DnsPolicyConfig", "$domainNRPTpath\$DnsPolicyConfig")
                    ReportIssue $issueMsg $ISSUETYPE_ERROR
                }
            }
        }
    }
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_dnscli_KB4562541
#region net_dnscli_KB4617560
<# 
Component: dnscli
Checks for:
 The issue where DNS names cannot be resolved if SearchList registry value is 
 not of type string.
Created by: tdimli 
#>
function net_dnscli_KB4617560
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

    $issueMsg = "
This computer has SearchList registry value defined as a type other than string:

Key:   HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters
Value: SearchList

This may break DNS name resolution. 

Resolution:
Please inspect and ensure above registry value has the correct type and contains 
a valid DNS suffix search list.

More information on DNS suffix search list:
https://docs.microsoft.com/en-us/troubleshoot/windows-client/networking/configure-domain-suffix-search-list-domain-name-system-clients
"

    if($offline) {
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }

    # Look for the issue
    $issueFound = $false
    try
    {
        $regKey = (Get-Item -Path HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters -ErrorAction Ignore)
        if ($regKey -ne $null) {
            if ($regkey.Property.Contains("SearchList")) {
                $regType = $regKey.GetValueKind('SearchList')
                if ($regType -ne $null) {
                    if ($regType -ne 'String') {
                        $issueFound = $true
                    }
                }
            }
        }
        # issue found?
        if ($issueFound) {
            ReportIssue $issueMsg $ISSUETYPE_ERROR
        }
    }
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_dnscli_KB4617560
#endregion dnscli

#region dnssrv
#region net_dnssrv_KB4561750
<# 
Component: dnssrv
Checks for:
 Checks if DNS Server has failed to use the specified interface
 as indicated by event 410
Created by: tdimli
#>
function net_dnssrv_KB4561750
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

    $issueMsg = @"
This DNS Server was configured to listen only on specific IP address(es) but has 
failed to do so. When such a failure occurs, DNS Server will delete the 
configured specific IP address(es) and will listen on all available IP addresses 
instead.

An event is logged in DNS Server event log to indicate this, most recent 
occurrence is displayed below:

Event ID: 410
Logname: DNS Server
Logged: {0}
The DNS server list of restricted interfaces does not contain a valid IP address 
for the server computer. The DNS server will use all IP interfaces on the machine. 
Use the DNS manager server properties, interfaces dialog, to verify and reset the 
IP addresses the DNS server should listen on. For more information, see 
"To restrict a DNS server to listen only on selected addresses" 
in the online Help.

Cause
The problem is that the network interface card for the configured IP address 
was not ready when DNS Server service was starting and as such, it could not 
be used.

As indicated by DNS event 410, this behaviour is expected: DNS Server checks 
existing IP addresses during service start and if none match the configured 
IP addresses, this configuration is considered invalid as DNS Server cannot run 
without any IP addresses. This configuration is deleted and DNS Server 
reverts to listen on all available IP addresses.

Resolution
To resolve this, the "Startup type" of "DNS Server" service can be changed 
to "Automatic (Delayed Start)”.
"@

    if($offline) {
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }

    # Look for the issue
	try	{

        $services = Get-Service -Name "DNS" -ErrorAction Ignore
        if($services.Count -ne 1) {
            LogWrite "Not a DNS Server, skipping"
            return $RETURNCODE_SKIPPED
        }

        $xrayStartTime = (Get-Date) - (New-TimeSpan -Day 30)
        $Event410 = Get-WinEvent -FilterHashtable @{ LogName="DNS Server"; Id=@(410); StartTime=$xrayStartTime} -MaxEvents 100 -ErrorAction Ignore | Sort-Object -Property TimeCreated -Descending

        if ($Event410.Count -gt 0) {
            # Get the latest occurrence
            $mostRecent = $Event410 | Select-Object -First 1

            $issueMsg = [string]::Format($issueMsg, $mostRecent.TimeCreated)
            ReportIssue $issueMsg $ISSUETYPE_ERROR
        }
	}
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_dnssrv_KB4561750
#region net_dnssrv_KB4569509
<# 
Component: dnssrv
Checks for:
 Checks if this DNS Server is protected against vulnerability described in 
 CVE-2020-1350
Created by: tdimli
#>
function net_dnssrv_KB4569509
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

    $issueMsg = "
{0}

Background:
On July 14, 2020, Microsoft released a security update for the issue that is 
described in CVE-2020-1350 | Windows DNS Server Remote Code Execution 
Vulnerability. This advisory describes a Critical Remote Code Execution (RCE) 
vulnerability that affects Windows servers that are configured to run the DNS 
Server role. 

A registry-based workaround can be used to help protect an affected Windows 
server, and it can be implemented without requiring an administrator to restart 
the server. Because of the volatility of this vulnerability, administrators may 
have to implement the workaround before they apply the security update in order 
to enable them to update their systems by using a standard deployment cadence.

For more information please see following support article:
https://support.microsoft.com/help/4569509
"

    $msgNoUpdateNoRegistry = "
This DNS Server is not protected against the vulnerability as described in:
CVE-2020-1350 | Windows DNS Server Remote Code Execution Vulnerability
https://portal.msrc.microsoft.com/en-US/security-guidance/advisory/CVE-2020-1350

We strongly recommend that server administrators apply the security update at 
their earliest convenience.

A registry-based workaround can be used to help protect an affected Windows 
server, and it can be implemented without requiring an administrator to restart 
the server. Because of the volatility of this vulnerability, administrators may 
have to implement the workaround before they apply the security update in order 
to enable them to update their systems by using a standard deployment cadence.
"

    $msgNoUpdateRegistry = "
This DNS Server does not appear to have the update to resolve the vulnerability 
as described in:
CVE-2020-1350 | Windows DNS Server Remote Code Execution Vulnerability
https://portal.msrc.microsoft.com/en-US/security-guidance/advisory/CVE-2020-1350

The registry-based workaround has been applied. The registry-based workaround 
provides protections to a system when you cannot apply the security update 
immediately and should not be considered as a replacement to the security update. 
We strongly recommend that server administrators apply the security update at 
their earliest convenience.
"

    $msgUpdateAndRegistry = "
This DNS Server has the update to resolve the vulnerability as described in:
CVE-2020-1350 | Windows DNS Server Remote Code Execution Vulnerability
https://portal.msrc.microsoft.com/en-US/security-guidance/advisory/CVE-2020-1350

The registry-based workaround also seems to be in place. The workaround is 
compatible with the security update. However, the registry modification will 
no longer be needed after the update is applied. Best practices dictate that 
registry modifications be removed when they are no longer needed to prevent 
potential future impact that could result from running a nonstandard 
configuration.
"

    if($offline) {
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }

    # list of updates (for various OS versions) that first fixed this issue
    $requiredUpdates = @(
        "KB4565503", # 2004
        "KB4565483", # 1903 & 1909
        "KB4558998", # 2019
        "KB4565511", # 2016
        "KB4565541", # 2012 R2
        "KB4565537", # 2012
        "KB4565524", # 2008 R2 SP1
        "KB4565536"  # 2008 SP2
    )

    # Look for the issue
	try	{

        $services = Get-Service -Name "DNS" -ErrorAction Ignore
        if(($services.Count -ne 1) -or ($services.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running)) {
            LogWrite "Not an active DNS Server, nothing to check, skipping"
            return $RETURNCODE_SKIPPED
        }
        
        # check if a resolving update is installed
        $update = HasRequiredUpdate $requiredUpdates

        # check for the registry value workaround
        $regKey = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DNS\Parameters" 
        $regVal = "TcpReceivePacketSize"
        $rItemProperty = Get-ItemProperty -Path "Registry::$regKey" -Name $regVal -ErrorAction Ignore

        if(($rItemProperty) -and ($($rItemProperty.$regVal) -le 0xFF00)) {
            $registry = $true
        }
        else {
            $registry = $false
        }

        if ($update) {
            if ($registry) {
                # update installed but still has the registry workaround in place
                $issueMsg = [string]::Format($issueMsg, $msgUpdateRegistry)
                ReportIssue $issueMsg $ISSUETYPE_INFO
            }
            else {
                # nothing to do: update installed and registry workaround is not present
                LogWrite "A resolving update is installed"
            }
        }
        else {
            if ($registry) {
                # update not installed but protected by registry workaround
                $issueMsg = [string]::Format($issueMsg, $msgNoUpdateRegistry)
                ReportIssue $issueMsg $ISSUETYPE_INFO
            }
            else {
                # vulnerable: no update and no registry workaround in place
                $issueMsg = [string]::Format($issueMsg, $msgNoUpdateNoRegistry)
                ReportIssue $issueMsg $ISSUETYPE_ERROR
            }
        }
	}
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_dnssrv_KB4569509
#region net_dnssrv_KB5034471
<# 
Component: dnssrv
 Checks if this DNS Server has RPC disabled
#>
function net_dnssrv_KB5034471
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

    $issueMsg = "
This DNS Server has RPC disabled.

Please check following registry value which is set to 0:

HKEY_LOCAL_MACHINE\System\CurrentControlSet\services\DNS\Parameters
Name: RpcProtocol
Type: REG_DWORD

Values explained:
0x0 Disables RPC for DNS server service
0x1 Enables RPC over TCP/IP.
0x2 Enables RPC over named pipes.
0x4 Enables RPC over local procedure call (LPC).
0xFFFFFFFF Enables all RPC protocols. ( default )

Value 0 ( zero ) should not be used as it disables all management of the DNS 
server service either locally or remotely.

Value 4 ( four ) can be used to restrict management of the DNS server service 
to users logged on locally to the DNS server.

The DNS server service must be restarted for changes to these values to take effect.

Resolution:
Please choose an appropriate new value for this registry parameter. 
You can set the new value directly in registry or via dnscmd.exe tool: 
dnscmd /rpcprotocol [0x0|0x1|0x2|0x4|0xFFFFFFFF]
"

    # Look for the issue
    try
    {
        $services = Get-Service -Name "DNS" -ErrorAction Ignore
        if(($services.Count -ne 1) -or ($services.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running)) {
            LogWrite "Not an active DNS Server, skipping"
            return $RETURNCODE_SKIPPED
        }

        # check for the registry value
        $regKey = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DNS\Parameters" 
        $regVal = "RpcProtocol"
        $rItemProperty = Get-ItemProperty -Path "Registry::$regKey" -Name $regVal -ErrorAction Ignore

        if(($rItemProperty) -and ($($rItemProperty.$regVal) -eq 0)) {
            # Issue detected
            ReportIssue $issueMsg $ISSUETYPE_ERROR
        }
    }
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_dnssrv_KB5034471
#endregion dnssrv

#region firewall
#region net_Firewall_KB4561854
<# 
Component: Firewall
Checks for:
 The issue where the Svchost process hosting BFE and Windows Defender Firewall
 takes up an unusual amount of CPU and RAM resources.
 This causes a performance degradation.
Created by: dosorr
#>
function net_firewall_KB4561854
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

    $issueMsg = "
Several duplicates of same firewall rules are present on this device. 
This will lead to unnecessary and additional CPU and memory load on the host 
and can cause a performance degradation. This additional load will appear as 
high CPU and memory consumption by the Svchost process hosting BFE service and 
Windows Defender Firewall.

Duplicate firewall rules:

`t{0} instances of {1}
`t{2} instances of {3}

Note: The higher the number, the more CPU cycles and memory are consumed!

Resolution:
You can delete these duplicate rules using following commands:
  netsh advfirewall firewall delete rule name=`"Core Networking - Teredo (ICMPv6-In)`"
  netsh advfirewall firewall delete rule name=`"Core Networking - Teredo (ICMPv6-Out)`"

You might also want to disable ""Teredo interface"" to prevent this from 
happening again. You can use following GPO setting to disable it:
  Computer Configuration\AdministrativeTeamplates\Network\TCPIPSettings\IPv6TransitionTechnologies
  Set Teredo State: Disabled
"

    if($offline) {
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }

    # Look for the issue
	try	{
        $curBuild = [Convert]::ToUInt32($wmi_Win32_OperatingSystem.BuildNumber)
        $minBuild = 10000
        if ($curBuild -lt $minBuild ) {
            LogWrite "OS version $($wmi_Win32_OperatingSystem.Version) not affected, skipping"
            return $RETURNCODE_SKIPPED
        }

        # halve the run-time checking number of duplicate rules for both -in and -out in one call
        $TeredoRuleName = "Core Networking - Teredo (ICMPv6-*)"
		$TeredoRuleCount = (Get-NetFirewallRule -DisplayName $TeredoRuleName -ErrorAction Ignore).Count

		# Issue present if any of the rule is present at least 10 times
		if($TeredoRuleCount -ge 20) {
            # do the full work only if needed
            $TeredoOutRuleName = "Core Networking - Teredo (ICMPv6-Out)"
		    $TeredoInRuleName = "Core Networking - Teredo (ICMPv6-In)"
            $TeredoOutRuleCount = (Get-NetFirewallRule -DisplayName $TeredoOutRuleName -ErrorAction Ignore).Count
		    $TeredoInRuleCount = (Get-NetFirewallRule -DisplayName $TeredoInRuleName -ErrorAction Ignore).Count
			# Issue detected
			$issueMsg = [string]::Format($issueMsg, $TeredoOutRuleCount, $TeredoOutRuleName, $TeredoInRuleCount, $TeredoInRuleName)
			ReportIssue $issueMsg $ISSUETYPE_ERROR
		}
	}
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_Firewall_KB4561854
#endregion firewall


#region http
#region net_http_KB5033495

function net_http_KB5033495
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

    $issueMsg = "
HTTP/3 is enabled on this device, however this device doesn't support TLS 1.3.
This will cause future certificate bindings to HTTP.sys listeners to fail with SEC_E_ALGORITHM_MISMATCH.
For instance, adding a certificate binding with
""netsh http add sslcert ipport:<IPADDRESS:PORT> certhash=<CERTIFICATE THUMBPRINT> appid=<APP ID>"" will fail with
""SSL Certificate add failed. Error: 1""

More Information:
https://techcommunity.microsoft.com/t5/networking-blog/enabling-http-3-support-on-windows-server-2022/ba-p/2676880

Resolution:
To disable HTTP/3 and resolve this issue, please delete
following registry entry or change its value to 0:

`t{0}
`tName : {1}
`tType : REG_DWORD
`tValue: 0

This change will require a restart of the ""HTTP"" service to take
effect.
"

    # Look for the issue
    try
    {
        $curBuild = [Convert]::ToUInt32($wmi_Win32_OperatingSystem.BuildNumber)
	# Releases post Windows Server 2022 are not affected
        $maxBuild = 20348
        if ($curBuild -ge $maxBuild) {
            LogWrite "OS version $($wmi_Win32_OperatingSystem.Version) not affected, skipping"
            return $RETURNCODE_SKIPPED
        }

        $regKeyPath = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\HTTP\Parameters"
        $regKeySetting = "EnableHttp3"
        $rItemProperty = Get-ItemProperty -Path "Registry::$regKeyPath" -Name $regKeySetting -ErrorAction Ignore
        # Issue if EnableHttp3 is set to 1
        if(($rItemProperty) -and ($($rItemProperty.$regKeySetting) -ne 0)) {
            # Issue detected
            $issueMsg = [string]::Format($issueMsg, $regKeyPath, $regKeySetting)
            ReportIssue $issueMsg $ISSUETYPE_ERROR
        }
    }
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_http_KB5033495
#endregion http

#region hyphost
#region net_hyphost_KB4562593
<# 
Component: vmswitch
Checks for:
 NET: Hyper-V: Multicast, broadcast or unknown unicast 
 packet storm exhausts non-paged pool memory or causes 3B/9E bugchecks on Hyper-V hosts
Created by: vidou 
#>
function net_hyphost_KB4562593
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

    $issueMsg = "
This server had to allocate high amount of memory for packets in a vRss queue 
due to low resource on the physical NIC. 
This will cause packets to be dropped until the queue size falls below 512 MB.

Note: This might not be directly related to the issue you are troubleshooting.
 If you are troubleshooting an issue related to network connectivity/packet 
 drops, or server performance or crashes, then this is likely to be related.

The maximum memory that had to be allocated reached {0} MB within the last {1} 
days checked.
The higher this figure, the more the packet drops and the longer it lasts.

You can obtain more details by reviewing following events in System Event log:
ProviderName: {2}
Event Ids   : {3}

If you are a Microsoft Support Professional, please review KB4562593 for 
further assistance.
"

    if($offline) {
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }

    $minBuild = 14393 
    $curBuild = [Convert]::ToUInt32($wmi_Win32_OperatingSystem.BuildNumber)
    $productType = [Convert]::ToUInt32($wmi_Win32_OperatingSystem.ProductType)
    $operatingSystemSKU = [Convert]::ToUInt32($wmi_Win32_OperatingSystem.OperatingSystemSKU)
    
    # issue may only affect Win10 Server above RS1
    if (($curBuild -lt $minBuild) -or ($productType -eq 1) -or ($operatingSystemSKU -eq 175)) {
        LogWrite "Not affected, skipping"
        return $RETURNCODE_SKIPPED
    }

    try {
        #Checking that Hypv and at least one VMSwith is present
        $res = Get-WindowsFeature Hyper-V -ErrorAction Ignore
        if ( $res.InstallState -ne "Installed")
        {
            LogWrite "Hyper-V not installed, skipping"
            return $RETURNCODE_SKIPPED
        }

        #$IssueFound = $false
        #$VmSwitchCount = 0
        $VmSwitchCount = (Get-VMSwitch -ErrorAction Ignore).Count
        
        # if there is no vSwitch then exit
        if ( $VmSwitchCount -lt 1)
        {
            LogWrite "No vmswitch, skipping"
            return $RETURNCODE_SKIPPED
        }

        # examine System event log
        $providerName="Microsoft-Windows-Hyper-V-VmSwitch"
        $eventId = "252"
        $queueThreshold = 512
        $maxQueueSize = 0
        $days = 14
        $xrayStartTime = (Get-Date) - (New-TimeSpan -Day $days)
        $Log = Get-WinEvent -FilterHashtable @{ LogName="System"; Id=$eventId; ProviderName=$providerName; StartTime=$xrayStartTime } -ErrorAction Ignore
        
        if ($Log -ne $null)
        {
            $IssueFound = $Log.Message.Split(" ") | ForEach-Object{ 
                if( $_ -match "MB")
                { 
                    $CurrentQueueSize=$_ -replace '(\d+).*','$1'
                    if ( [int]$CurrentQueueSize -gt $queueThreshold)
                    {
                        if ($CurrentQueueSize -gt $maxQueueSize) {
                            $maxQueueSize = $CurrentQueueSize
                        }
                        return $true
                    }
                }
            }

            if ( $IssueFound)
            {
                $issueMsg = [string]::Format($issueMsg, $maxQueueSize, $days, $providerName, $eventId)
    		    ReportIssue $issueMsg $ISSUETYPE_ERROR
            }
        }
    }
    catch {
        LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_hyphost_KB4562593
#endregion hyphost

#region ncsi
#region net_ncsi_KB4648334
<# 
Component: ncsi, nla
Checks for:
 The issue where corporate connectivity is configured on a non-DA client
 This will result in NCSI/NLA network detection issues
Created by: tdimli, jcabrera
#>
function net_ncsi_KB4648334
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )
$issueMsg = "
This computer has corporate connectivity configured.
Corporate connectivity is only needed for Direct Access (DA) but this device 
does not appear to have DA configured (no IPHTTPS interface configured).

Corporate connectivity configuration on a non-DA client may cause network 
detection problems with NCSI.

Resolution:
If this computer is not using Direct Access, please remove corporate connectivity 
configuration to avoid network detection issues.

Registry key where corporate connectivity configuration is stored:
  {0}

Note: If the registry key is being re-created, identify the policy that is 
re-creating it and remove the corresponding policy configuration.
"

    if($offline) {
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }

    # Look for the issue
    $CorporateConnectivityPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator\CorporateConnectivity"

    try
    {
        $curBuild = [Convert]::ToUInt32($wmi_Win32_OperatingSystem.BuildNumber)
        $minBuild = 10000 
        if ($curBuild -gt $minBuild) {
            # Windows 10
            # is corporate connectivity configured?
            $regKey = (Get-Item -Path $CorporateConnectivityPath -ErrorAction Ignore)
            LogWrite "$CorporateConnectivityPath exists? $($regkey -ne $null)"
            if ($regKey -ne $null) {
                # is DirectAccess configured (IPHTTPS interface present)?
                if ($null -eq (Get-NetIPHttpsConfiguration -ErrorAction Ignore)) {
                    # issue present: corporate connectivity configured without a DA client
                    $issueMsg = [string]::Format($issueMsg, $CorporateConnectivityPath)
                    ReportIssue $issueMsg $ISSUETYPE_ERROR
                }
            }
        }
        else {
            # issue does not apply to pre-Windows 10
            return $RETURNCODE_SKIPPED
        }
    }
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_ncsi_KB4648334
#endregion ncsi

#region netio
#region net_netio_KB4563820
<# 
Component: dasrv
Checks for:
 NETIO/WFP non-paged pool memory leak, tag Afqc
Created by: tdimli
#>
function net_netio_KB4563820
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

    $issueMsg = "
Considerable amount of {1} pool memory is allocated with pool tag {0}:

Tag  Bytes
{0} {2}

Windows 10 clients and servers (1809 or later) may leak non-paged pool memory 
(NPP, tag Afqc) in certain scenarios.

This memory leak can cause performance degradation due to reduced amount of 
memory left available. If the leak grows too large, it can deplete the {1}  
pool memory and cause the computer to crash.

Resolution
We are currently working on a long-term resolution to address this issue.
Following workarounds can be used until a resolution becomes available:
  1. Monitor the leak amount and restart affected computers regularly to avoid 
  the leak growing too large and to prevent {1} pool memory from being depleted.
  2. If possible, reduce amount of UDP traffic
"

    $infoMsg = "
Considerable amount of {1} pool memory is allocated with pool tag {0}:

Tag: {0}
Pool: {1}
Allocs in use: {3}
Bytes in use: {4}

Note: This might not be directly related to the issue you are troubleshooting.

This tag is used by {2}

{3} allocations being in use for this tag is unusual and may benefit from 
further investigation.
Consider collecting an xperf trace, ensuring multiple allocs/leaks (at least 
1 MB) are captured in the trace. Poolmon can be used to monitor that:
  poolmon -i{0}

Following command can be used to capture such a trace:
  1. xperf -on Base+CSwitch+POOL -stackwalk PoolAlloc+PoolFree+PoolAllocSession+PoolFreeSession -PoolTag {0} -BufferSize 1024 -MaxBuffers 1024 -MaxFile 2048 -FileMode Circular 
  2. Wait for 5-10 minutes or until sufficient allocs/leaks are captured
  3. xperf -d c:\{0}.etl 

Following command will capture a trace of size specified by MaxSize parameter 
and stop automatically (can also be stopped -if needed- by: xperf -stop):
  xperf -on Base+CSwitch+POOL -stackwalk PoolAlloc+PoolFree+PoolAllocSession+PoolFreeSession -PoolTag {0} -BufferSize 1024 -MaxBuffers 1024 -MaxFile 1024 -f c:\{0}.etl

Poolmon: https://docs.microsoft.com/en-us/windows-hardware/drivers/devtest/poolmon
xperf: https://docs.microsoft.com/en-us/windows-hardware/test/wpt/
"

    if($offline) {
        LogWrite "Running offline"
    }
    else {
        LogWrite "Running online"
    }

    # Look for the issue
    $tag = "Afqc"
    $pooltype = "Nonp"
    $comp = "TCPIP/WFP" # who uses this tag
    $threshold = 10 * 1024 # if over 10K allocs are leaked

	try	{
        $puSets = GetPoolUsageByTag $tag $pooltype
        if ($puSets.Count -gt 0) {
            $bytesInUse = 0
            $allocsInUse = 0
            $doubleAllocs = $false
            foreach ($puSet in $puSets) {
                # find the highest diff between allocs and frees
                if ($puSet[2] -gt $allocsInUse) {
                    $allocsInUse = $puSet[2]
                    $bytesInUse = $puSet[3]
                    if ($puSet[0] -ge (2 * $puSet[1])) { # alloc twice, free once issue
                        $doubleAllocs = $true
                    }
                }
            }

            $prodType = [Convert]::ToUInt32($wmi_Win32_OperatingSystem.ProductType)
            $curBuild = [Convert]::ToUInt32($wmi_Win32_OperatingSystem.BuildNumber)
            $minBuild = 17763

            if ($prodType -eq 1) {
                # only checking client SKUs, not servers
                if ($allocsInUse -gt $threshold) {
                    # is this the Afqc/AppLocker issue which affects Win10 RS5 and later?
                    $curBuild = [Convert]::ToUInt32($wmi_Win32_OperatingSystem.BuildNumber)
                    $minBuild = 17763
                    if ($curBuild -lt $minBuild) {
                        # not KB4563820 but we do have high usage of Afqc which still points to an issue
                        LogWrite "OS (Build:$curBuild) not affected by KB4563820 issue, this seems to be a new $tag mem leak"
                        $issueMsg = [string]::Format($infoMsg, $tag, $pooltype, $comp, $allocsInUse, $bytesInUse)
                        $issueType = $ISSUETYPE_INFO
                    }
                    elseif ($doubleAllocs) { 
                        # confirmed double alloc issue as per KB4563820
                        LogWrite "There are twice as many allocs as frees, definitely KB4563820"
		                $issueMsg = [string]::Format($issueMsg, $tag, $pooltype, $bytesInUse)
                        $issueType = $ISSUETYPE_ERROR
                    }
                    else { 
                        # not sure, might be KB4563820 or not, log as info for review
                        LogWrite "There is a leak but not sure if same issue as KB4563820, needs confirmation"
                        $issueMsg = [string]::Format($issueMsg, $tag, $pooltype, $bytesInUse)
                        $issueType = $ISSUETYPE_INFO
                    }
		            ReportIssue $issueMsg $issueType
                }
            }
            else {
                # server SKU
                LogWrite "ProductType ($prodType) is not client, skipping"
                return $Global:RETURNCODE_SKIPPED
            }
        }
	}
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_netio_KB4563820
#endregion netio

#region proxy
#region net_proxy_KB4569506
<# 
Component: vpn
Checks for:
 An issue where modern apps like Edge might stop working or NLA might display 
 "No Internet" after some 3rd party VPNs connect
Created by: tdimli
#>
function net_proxy_KB4569506
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

    $issueMsg = @"

This computer has received an invalid option from DHCP Server:
Option 252, Proxy autodiscovery

Network interface, length and value of the invalid option received:
{0}

This may cause NCSI to fail to detect network connectivity and 
show "No Internet" 

Note: This might not be directly related to the issue you are troubleshooting.
 If you are troubleshooting an issue related to proxy and/or NCSI connectivity
 detection, then this is probably related.

Resolution
Either remove this invalid option from DHCP server or configure it with a 
valid URL.
"@

    if($offline) {
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }

    # Look for the issue
	try	{
        $curBuild = [Convert]::ToUInt32($wmi_Win32_OperatingSystem.BuildNumber)
        $minBuild = 10000
        if ($curBuild -lt $minBuild ) {
            LogWrite "OS version $($wmi_Win32_OperatingSystem.Version) not affected, skipping"
            return $RETURNCODE_SKIPPED
        }

        # Windows 10
        $error = $false
        $ifs = $null
        $connections = (Get-NetAdapter -ErrorAction Ignore)
        foreach ($netAdapter in $connections) {
            if ($netAdapter.MediaConnectionState -eq "Connected") {
                $itemProp = (Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\Tcpip\Parameters\Interfaces\$($netAdapter.InterfaceGuid) -Name DhcpInterfaceOptions -ErrorAction Ignore)
                if (!$itemProp) {
                    continue
                }
                $DhcpInterfaceOptions = $itemProp.DhcpInterfaceOptions
	            $pointer = 0
	            while ($pointer -lt $DhcpInterfaceOptions.length) 
	            {
		            $code = $DhcpInterfaceOptions[$pointer]
		            $pointer += 4
                    $cLength = $DhcpInterfaceOptions[$pointer]
		            $pointer += 4
		            $length = $DhcpInterfaceOptions[$pointer]
                    $pointer += 3 * 4
	
		            if ($code -eq 252)
		            {
                        if ($length -lt 6) {
                            # check for Internet connectivity
                            $prf = (Get-NetConnectionProfile -InterfaceAlias $netAdapter.Name -ErrorAction Ignore)
                            if ($prf) {
                                if ($prf.IPv4Connectivity -ne "Internet") {
                                    if ($error) {
                                        $ifs += "`n"
                                    }
                                    else {
                                        $error = $true
                                    }
                                    # add adapter name
                                    $ifs += $netAdapter.Name
                                    # add option length and value
                                    $ifs += ", $length, "
                                    if ($length -gt 0) {
                                        for ($i=0; $i -lt $length; $i++)
                                        {
                                            if ($DhcpInterfaceOptions[$pointer + $i] -eq '`n') {
                                                $wpadOptionValue += "\n"
                                            }
                                            elseif ($DhcpInterfaceOptions[$pointer + $i] -eq '`r') {
                                                $wpadOptionValue += "\r"
                                            }
                                            elseif ($DhcpInterfaceOptions[$pointer + $i] -eq 0) {
                                                $wpadOptionValue += "\0"
                                            }
                                            else {
                                                LogWrite $DhcpInterfaceOptions[$pointer + $i]
                                                $wpadOptionValue += [char] $DhcpInterfaceOptions[$pointer + $i]
                                            }
                                        }
                                    }
                                    else {
                                        $wpadOptionValue = "<empty>"
                                    }
                                    $ifs += $wpadOptionValue
                                    break
                                }
                            }
                        }
		            }

                    $pointer += $cLength + $length
                    $align = 4 - ($pointer % 4)
                    if ($align -lt 4) {
                        $pointer += $align
                    }
	            }
            }
        }
        if ($error) {
            $issueMsg = [string]::Format($issueMsg, $ifs)
		    ReportIssue $issueMsg $ISSUETYPE_ERROR
        }
	}
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_proxy_KB4569506
#endregion proxy

#region rpc
#region net_rpc_KB2506972
<# 
Component: rpc
Checks for:
 The issues caused by enabling group policies 
 "Restrictions for unauthenticated RPC clients"
 and 
 "RPC endpoint mapper client authentication"
Created by: tdimli 
#>
function net_rpc_KB2506972
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )
$issueMsg = @"
This computer has one or more of the following policies enabled:

 Computer Configuration \ <policies> \ Administrative Templates \ System \ Remote Procedure Call
  Restrictions for unauthenticated RPC clients
  RPC endpoint mapper client authentication

Which map to the DWORD registry settings:

 HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Rpc
  RestrictRemoteClients
  EnableAuthEpResolution

This machine has these values currently configured as:
{0}
When you enable these authentication protections for RPC, you are no longer 
allowing applications to anonymously query the endpoint mapper: These two settings 
add an additional authentication "callback capability" to RPC connections. 
The problem is most applications don't have the capability to satisfy this 
requirements and fail as a result. This will break most applications including 
some Windows functionality. 

Note: This might not be directly related to the issue you are troubleshooting.
 If you are troubleshooting an issue that is listed in the document linked below,
 then this is probably related.

For more information as well as how to fix this:
 "Restrictions for Unauthenticated RPC Clients: The group policy that punches your domain in the face"
 https://techcommunity.microsoft.com/t5/ask-the-directory-services-team/restrictions-for-unauthenticated-rpc-clients-the-group-policy/ba-p/399128
"@

    if($offline) {
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }

    # Look for the issue
    $regKey = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Rpc" 

    $regVals = @("EnableAuthEpResolution", "RestrictRemoteClients")
    $errMsg = ""
    $issueFound = $false

    try
    {
        foreach ($regVal in $regVals) {
            $rItemProperty = Get-ItemProperty -Path "Registry::$regKey" -Name $regVal -ErrorAction Ignore
            if ($rItemProperty) {
                $errMsg += " $regVal = $($rItemProperty.$regVal)`r`n"
                if ($($rItemProperty.$regVal) -ne 0) {
                    $issueFound = $true
                }
            }
        }
        if ($issueFound) {
            # issue present
            $issueMsg = [string]::Format($issueMsg, $errMsg)
            ReportIssue $issueMsg $ISSUETYPE_INFO
        }
    }
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_rpc_KB2506972
#endregion rpc

#region smbcli
#region net_smbcli_KB5027830
<# 
Component: TBD
Checks for:
 Describe the issue being detected
Created by: <your alias>, optional
#>
function net_smbcli_KB5027830
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )
$issueMsg = "Workstation Service is not running, this will prevent you from being able 
to connect to SMB shares.
 
This is most likely caused by the missing ComputerName value in registry:

 HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName

Please check this registry key and restore the missing ComnputerName value.

Example:
reg add HKLM\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName /t REG_SZ /v ComputerName /d YourComputerName /f
"

    if($offline) {
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }

    # Look for the issue
    try
    {
        $services = Get-Service -Name "LanmanWorkstation" -ErrorAction Ignore
        if(($services.Count -ne 1) -or ($services.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running)) {
            $regVal = Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\ComputerName\ActiveComputerName' -Name 'ComputerName' -ErrorAction Ignore
            if (-not $regVal -or ($regVal.ComputerName.Length -eq 0)) {
                ReportIssue $issueMsg $ISSUETYPE_ERROR
            }
        }
        else {
            # LanmanWorkstation running, nothing to check
            return $RETURNCODE_SKIPPED
        }
    }
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}

# Helper function(s) can be defined here if you must, strictly for use by this diagnostic function only
# Using helper functions from other diagnostics is prohibited (here today, gone tomorrow as xray is dynamic!)

#endregion net_smbcli_KB5027830
#endregion smbcli

#region srv
#region net_srv_KB4562940
<# 
Component: srv
Checks for:
 The presence of SMBServer 1020/1031/1032 Events
 indicating a stalled I/O of more than 15 Seconds or Live Dump generation.
 Likely Cause: Broken Filterdrivers or extremely poor Storage Performance.
Created by: huberts
#>
function net_srv_KB4562940
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

    $issueMsg = "
This SMB Server has encountered file system operation(s) that has taken longer 
than expected.
The underlying file system has taken too long to respond to an operation. 
This typically indicates a problem with the storage and not SMB.

Note: This might not be directly related to the issue you are troubleshooting.
 If you are troubleshooting an issue related to server performance or hung SMB 
 server, then this is probably related.

An event is logged when file system operation takes longer than the default 
threshold of 15 seconds (120 seconds for asynchronous operations):
Microsoft-Windows-SMBServer/Operational Eventlog, EventID 1020

The latest occurrence was at:
{0}

There have been at least {1} occurrences in the last {2} days.
{3}

For information on troubleshooting SMB-Server Event ID 1020 warnings:
https://docs.microsoft.com/en-us/troubleshoot/windows-server/networking/troubleshoot-event-id-1020-warnings-file-server

"

    $issueMsg1 = "
Additionally the SMB Server tried to generate a live kernel dump because it 
encountered a problem. The reason for this dump is likely the same long-running 
filesystem operation.
Please check the Microsoft-Windows-SMBServer/Operational event log, look for 
event IDs 1031 & 1032 for further details, including the dump reason.
If a live dump was successfully created it can be found under:
%SystemRoot%\LiveKernelReports 
Such a dump is immensely useful for further troubleshooting.
"

    $AdditionalMsgText= "
There seems to be no live kernel dump(s) generated.
"

	# we can run offline, but need a seperate logic to retrieve information from exported .evtx files
    if($offline) {
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }

    # Get-SmbShare requires WS2012 or later, skip if earlier OS
    $curBuild = [Convert]::ToUInt32($wmi_Win32_OperatingSystem.BuildNumber)
    $reqBuild = 9200
    if ($curBuild -lt $reqBuild ) {
        LogWrite "Cannot run on OS version $($wmi_Win32_OperatingSystem.Version), build $reqBuild or later required, skipping"
        return $RETURNCODE_SKIPPED
    }
    
    # Look for the issue
    try {
	    # Get a list of shares to see if we are actually on a fileserver
        # Ignore Default Shares such as Temp$, IPC$, etc.
        $SMBshares = Get-SmbShare -ErrorAction Ignore | Where-Object {$_.Path -notlike "$Env:WinDir*" -and $_.Name -notlike "IPC$" -and $_.Name -notmatch "^[A-Z]{1}\$" }
        if ($SMBshares.Count -eq 0) {
            # no shares found -> nothing to check
            LogWrite "No Fileserver Shares found. Nothing to check. Skipping"
            return $RETURNCODE_SKIPPED
        }

        # get a maximum of $NumberOfEventsToCheck Events from the Eventlog (in order to limit runtime)
        $NumberOfEventsToCheck = 500
        $days = 30
        $xrayStartTime = (Get-Date) - (New-TimeSpan -Day $days)
        $Eventlog = Get-WinEvent -FilterHashtable @{ LogName="Microsoft-Windows-SMBServer/Operational"; Id=@(1020, 1031, 1032); StartTime=$xrayStartTime} -MaxEvents $NumberOfEventsToCheck -ErrorAction Ignore | Sort-Object -Property TimeCreated -Descending

        $Event1020 = $EventLog | Where-Object {$_.ID -eq 1020}
        if ($Event1020.Count -gt 0) {
            # OK! We found some 1020 Event!
            if ($Event1020.Count -gt 1) {
                $issueType = $ISSUETYPE_ERROR
            }
            else {
                $issueType = $ISSUETYPE_WARNING
            }
            # Check the latest occurrence
            $1020_NewestOccurence = $Event1020 | Select-Object -First 1

            # Now lets check if we also have Messages stating that the Server tried to generate a Live Dump and if so provide further input.
            $DumpEvent = $EventLog | Where-Object {$_.ID -eq 1031}
            if ($DumpEvent.Count -ne 0) {
                $AdditionalMsgText = $issueMsg1
            }

            $issueMsg = [string]::Format($issueMsg, $1020_NewestOccurence.TimeCreated, $Event1020.Count, $days, $AdditionalMsgText)
            ReportIssue $issueMsg $issueType
        }
    }
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_srv_KB4562940

#region net_srv_KB4612362
# Created by edspatar
# March 2021
<# 
Component: srv
 
 Checks for:
 Checks for the presence of SMBServer 1015 Events
 indicating an SMB Decryption Failed.
 Likely Cause: One of the RDS users becomes idle and SMB server disconnected its 
 SMB session with the underlying TCP connection for all user SMB sessions built 
 on that TCP connection.
#>
function net_srv_KB4612362
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

$NumberOfEventsToCheck = 500

$issueMsg = @"
This server has logged "Decrypt call failed" error events:
 Microsoft-Windows-SMBServer/Security Eventlog, EventID 1015

The latest occurrence was at:
{0}

There have been at least {1} occurrence(s) in the last {2} days.

This event commonly occurs because a previous SMB session no longer exists.
It may also be caused by packets that are altered on the network between 
the computers due to either errors or a "man-in-the-middle" attack.

If the SMB client is an RDS Server, these events maybe expected due to multiple 
users sharing the same session and when one times out, it will trigger this event 
on others. To confirm, please check for instances of following event on the 
Terminal Server:

Microsoft-Windows-SMBclient/Connectivity
Event ID 30805  
Microsoft-Windows-SMBClient  
Warning
The connection to the share was lost.      
Error: The remote user session has been deleted...

If the server is a Windows Failover Cluster file server, then this message 
may also occur when the file share moves between cluster nodes. There will also 
be an anti-event 30808 indicating the session to the server was re-established. 
If the server is not a failover cluster, it is likely that the server was previously 
online, but it is now inaccessible over the network.

Workaround: To prevent these errors, SMB Encryption can be disabled.
"@

	# we can run offline, but need a seperate logic to retrieve information from exported .evtx files
    if($offline) {
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }
    
    # Look for the issue
    try {
	    # Check if SMB encryption is enabled at server level, if not check for shares with EncryptData enabled
        # Ignore Default Shares such as Temp$, IPC$, etc.
        $SMBEncryptedServer = Get-SmbServerConfiguration -ErrorAction Ignore | Where-Object -Property "EncryptData" -eq $true
		if ($SMBEncryptedServer.Count -eq 0) {
			$SMBEncryptedShares = Get-SmbShare -ErrorAction Ignore | Where-Object {$_.Path -notlike "$Env:WinDir*" -and $_.Name -notlike "IPC$" -and $_.Name -notmatch "^[A-Z]{1}\$" -and $_.EncryptData -eq $true}
			if ($SMBEncryptedShares.Count -eq 0) {
				# no shares found -> nothing to check
				LogWrite "No encrypted shares found, nothing to check, skipping"
				return $RETURNCODE_SKIPPED
			}
        }

        # get a maximum of $NumberOfEventsToCheck Events from the Eventlog (in order to limit runtime)
        $NumberOfEventsToCheck = 500
        $days = 30
        $xrayStartTime = (Get-Date) - (New-TimeSpan -Day $days)
        $Event1015 = Get-WinEvent -FilterHashtable @{ LogName="Microsoft-Windows-SMBServer/Security"; Id=@(1015); StartTime=$xrayStartTime} -MaxEvents $NumberOfEventsToCheck -ErrorAction Ignore | Sort-Object -Property TimeCreated -Descending

        if ($Event1015.Count -gt 0) {
            # OK! We found some 1015 events!
            if ($Event1020.Count -gt 10) {
                $issueType = $ISSUETYPE_ERROR
            }
            else {
                $issueType = $ISSUETYPE_WARNING
            }

            # Check the latest occurrence
            $1015_NewestOccurance = $Event1015 | Select-Object -First 1

            $issueMsg = [string]::Format($issueMsg, $1015_NewestOccurance.TimeCreated, $Event1015.Count, $days)
            ReportIssue $issueMsg $issueType
        }       
    }

	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_srv_KB4612362
#endregion srv

#region vpn
#region net_vpn_KB4553295
<# 
Component: aovpn
Checks for:
 An issue where AoVPN might not detect that it's inside
Created by: tdimli
#>
function net_vpn_KB4553295
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

    $issueMsg = @"
There is a domain authenticated connection which is not in the trusted network 
list configured for Always on VPN (AoVPN) connection:
{0}

This might lead to unnecessary AoVPN connections being triggered.

Note: This might not be directly related to the issue you are troubleshooting.
 If you are troubleshooting an issue related to AoVPN trusted network detection 
 and/or AoVPN client initiating a connection when already have connectivity to 
 a DomainAuthenticated network, then this is likely to be related.

Resolution
To avoid an AoVPN connection being established when already connected to a domain 
network via "{0}", add its network name "{1}" to AoVPN 
configuration as a trusted network, e.g.:
<TrustedNetworkDetection>{2}{1}</TrustedNetworkDetection>
"@

    if($offline) {
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }

    # Look for the issue
	try	{
        $curBuild = [Convert]::ToUInt32($wmi_Win32_OperatingSystem.BuildNumber)
        $minBuild = 10000
        if ($curBuild -lt $minBuild ) {
            LogWrite "OS version $($wmi_Win32_OperatingSystem.Version) not affected, skipping"
            return $RETURNCODE_SKIPPED
        }

        # Windows 10
        $vpnConn = (Get-VpnConnection -ErrorAction Ignore)
        if ($vpnConn) {
            $trigger = (Get-VpnConnectionTrigger -ConnectionName $vpnConn.Name -ErrorAction Ignore)
            if ($trigger) {
                $trustedNetworks = $trigger.TrustedNetwork
                if ($trustedNetworks) {
                    $connections = (Get-NetConnectionProfile -NetworkCategory DomainAuthenticated -ErrorAction Ignore)
                    foreach ($conn in $connections) {
                        if ($vpnConn.Name -ne $conn.InterfaceAlias) {
                            if (!$trustedNetworks.Contains($conn.Name)) {
                                $iType = $ISSUETYPE_ERROR
                                $badconn = $conn
                            }
                        }
                    }
                    if ($iType -eq $ISSUETYPE_ERROR) {
                        foreach ($net in $trustedNetworks) {
                            $trustedNetworkList += $net + ","
                        }
		                $issueMsg = [string]::Format($issueMsg, $badconn.InterfaceAlias, $badconn.Name, $trustedNetworkList)
		                ReportIssue $issueMsg $iType
                    }
                }
            }
        }
	}
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_vpn_KB4553295

#region net_vpn_KB4550202
<# 
Component: vpn
Checks for:
 An issue where modern apps like Edge might stop working or NLA might display 
 "No Internet" after some 3rd party VPNs connect
Created by: tdimli
#>
function net_vpn_KB4550202
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

    $issueMsg = @"
There is a 3rd party VPN connection which is connected but hidden:
Name: {0}
Guid: {1}

Being hidden when connected might prevent NLA from detecting connectivity 
over this VPN connection and can lead to connectivity issues.

Note: This might not be directly related to the issue you are troubleshooting.
 If you are troubleshooting an issue related to VPN connectivity, such as 
 modern apps like Edge etc. stop working or NLA displaying "No Internet" after 
 a 3rd party VPN is connected.

Resolution
Ensure the VPN adapter is visible when connected. Contact VPN vendor for 
further assistance.
"@

    if($offline) {
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }

    # Look for the issue
	try	{
        $curBuild = [Convert]::ToUInt32($wmi_Win32_OperatingSystem.BuildNumber)
        $minBuild = 10000
        if ($curBuild -lt $minBuild ) {
            LogWrite "OS version $($wmi_Win32_OperatingSystem.Version) not affected, skipping"
            return $RETURNCODE_SKIPPED
        }

        # Windows 10
        $vpnConn = (Get-VpnConnection -ErrorAction Ignore)
        if ($vpnConn) {
            if ($vpnConn.ConnectionStatus -eq "Connected") {
                $connections = (Get-NetConnectionProfile -ErrorAction Ignore)
                $vpnHidden = $true
                foreach ($conn in $connections) {
                    if ($vpnConn.Name -eq $conn.InterfaceAlias) {
                        $vpnHidden = $false
                        LogWrite "VPN not hidden"
                    }
                }
                if ($vpnHidden) {
                    foreach ($net in $trustedNetworks) {
                        $trustedNetworkList += $net + ","
                    }
		            $issueMsg = [string]::Format($issueMsg, $vpnConn.Name, $vpnConn.Guid)
		            ReportIssue $issueMsg $ISSUETYPE_ERROR
                }
            }
            else {
                LogWrite "VPN not connected, skipping"
                return $RETURNCODE_SKIPPED
            }
        }
        else {
            LogWrite "No VPN connection, skipping"
            return $RETURNCODE_SKIPPED
        }
	}
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_vpn_KB4550202
#endregion vpn

#region wlan
#region net_wlan_KB4557342
<# 
Component: wlan
Checks for:
 The issue where WLAN profiles cannot be deleted, their password changed or
 network forgotten. 
Created by: dosorr 
#>
function net_wlan_KB4557342
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

    $issueMsg = "
WLAN Profile Hash Table Lookup is disabled on this device. 
This can cause issues when deleting a WiFi profile, forgetting a WiFi network 
or changing its password. For instance, deleting a WLAN profile with 
""netsh wlan delete profile ProfileName"" can fail with ""Element not found.""

Resolution:
To enable WLAN Profile Hash Table Lookup and resolve this issue, please delete 
following registry entry or change its value to 1: 

`t{0}
`tName : {1}
`tType : REG_DWORD
`tValue: 1

This change will require a restart of the ""WLAN AutoConfig"" service to take 
effect.
"

    if($offline) {
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }

    # Look for the issue
    try
    {
        $curBuild = [Convert]::ToUInt32($wmi_Win32_OperatingSystem.BuildNumber)
        $minBuild = 10000
        if ($curBuild -lt $minBuild ) {
            LogWrite "OS version $($wmi_Win32_OperatingSystem.Version) not affected, skipping"
            return $RETURNCODE_SKIPPED
        } 

        # Windows 10
        $regKeyPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WlanSvc" 
        $regKeySetting = "EnableProfileHashTableLookup"
        $rItemProperty = Get-ItemProperty -Path "Registry::$regKeyPath" -Name $regKeySetting -ErrorAction Ignore

        # Issue if EnableProfileHashTableLookup is set to 0
        if(($rItemProperty) -and ($($rItemProperty.$regKeySetting) -eq 0))
        {
            # Issue detected
            $issueMsg = [string]::Format($issueMsg, $regKeyPath, $regKeySetting)
            ReportIssue $issueMsg $ISSUETYPE_ERROR
        }
    }
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}
#endregion net_wlan_KB4557342
#endregion wlan

# end: diagnostic functions

Export-ModuleMember -Function * -Variable *
# SIG # Begin signature block
# MIIoKgYJKoZIhvcNAQcCoIIoGzCCKBcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBms3s/hRGhR0SZ
# ytvut+K1sANnJjdKqJWeiqfznOO3paCCDXYwggX0MIID3KADAgECAhMzAAADrzBA
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
# /Xmfwb1tbWrJUnMTDXpQzTGCGgowghoGAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAOvMEAOTKNNBUEAAAAAA68wDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEINoS9GX/IBoqN5FEZ9M7nPfL
# Gopm5wyucmvnDuG1l92hMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAS7WaprtARH5nvYo0YaMw3Qe5CHb+dxS8r+5+dblZzycVI3f5+VC5a2TF
# 9cLtJbHuaZ5l1vjjG6iGN2WMY9Qo9EBSpE0mESwUisaj1BUGa/oxJERZvqxj+7cR
# I7FEzHono0T4m2xH96qM4lBYoAQ/S1BuQNG+QH26oWQH5m7TPJkSSsiTCA24aWeB
# FbIHclF7rbVcKsU2hL7sU4Mmtf/Cq0PVFnvtrdWklpBiarC9Ma3asJvBo1qgF6Ad
# 1fPVDzH1zJHgX+2Jnlfb9KW4w8neiABVLquaMljMv6ydfWqwschfygkZpRXvfyCA
# KxWjotmi+UElDRggWSvQdvmPpBeOf6GCF5QwgheQBgorBgEEAYI3AwMBMYIXgDCC
# F3wGCSqGSIb3DQEHAqCCF20wghdpAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsq
# hkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCBBgTKlDw5plD8ZPcunFnugsMbBB7/eET0iyFGflxjiUAIGZc4N3Fgg
# GBMyMDI0MDIyMDEyMTU1NC4wMTNaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046OEQwMC0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wg
# ghHqMIIHIDCCBQigAwIBAgITMwAAAfPFCkOuA8wdMQABAAAB8zANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yMzEyMDYxODQ2
# MDJaFw0yNTAzMDUxODQ2MDJaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25z
# MScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046OEQwMC0wNUUwLUQ5NDcxJTAjBgNV
# BAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQD+n6ba4SuB9iSO5WMhbngqYAb+z3IfzNpZIWS/sgfX
# hlLYmGnsUtrGX3OVcg+8krJdixuNUMO7ZAOqCZsXUjOz8zcn1aUD5D2r2PhzVKjH
# tivWGgGj4x5wqWe1Qov3vMz8WHsKsfadIlWjfBMnVKVomOybQ7+2jc4afzj2XJQQ
# SmE9jQRoBogDwmqZakeYnIx0EmOuucPr674T6/YaTPiIYlGf+XV2u6oQHAkMG56x
# YPQikitQjjNWHADfBqbBEaqppastxpRNc4id2S1xVQxcQGXjnAgeeVbbPbAoELhb
# w+z3VetRwuEFJRzT6hbWEgvz9LMYPSbioHL8w+ZiWo3xuw3R7fJsqe7pqsnjwvni
# P7sfE1utfi7k0NQZMpviOs//239H6eA6IOVtF8w66ipE71EYrcSNrOGlTm5uqq+s
# yO1udZOeKM0xY728NcGDFqnjuFPbEEm6+etZKftU9jxLCSzqXOVOzdqA8O5Xa3E4
# 1j3s7MlTF4Q7BYrQmbpxqhTvfuIlYwI2AzeO3OivcezJwBj2FQgTiVHacvMQDgSA
# 7E5vytak0+MLBm0AcW4IPer8A4gOGD9oSprmyAu1J6wFkBrf2Sjn+ieNq6Fx0tWj
# 8Ipg3uQvcug37jSadF6q1rUEaoPIajZCGVk+o5wn6rt+cwdJ39REU43aWCwn0C+X
# xwIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFMNkFfalEVEMjA3ApoUx9qDrDQokMB8G
# A1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCG
# Tmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUy
# MFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4w
# XAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwG
# A1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQD
# AgeAMA0GCSqGSIb3DQEBCwUAA4ICAQDfxByP/NH+79vc3liO4c7nXM/UKFcAm5w6
# 1FxRxPxCXRXliNjZ7sDqNP0DzUTBU9tS5DqkqRSiIV15j7q8e6elg8/cD3bv0sW4
# Go9AML4lhA5MBg3wzKdihfJ0E/HIqcHX11mwtbpTiC2sgAUh7+OZnb9TwJE7pbEB
# PJQUxxuCiS5/r0s2QVipBmi/8MEW2eIi4mJ+vHI5DCaAGooT4A15/7oNj9zyzRAB
# TUICNNrS19KfryEN5dh5kqOG4Qgca9w6L7CL+SuuTZi0SZ8Zq65iK2hQ8IMAOVxe
# wCpD4lZL6NDsVNSwBNXOUlsxOAO3G0wNT+cBug/HD43B7E2odVfs6H2EYCZxUS1r
# gReGd2uqQxgQ2wrMuTb5ykO+qd+4nhaf/9SN3getomtQn5IzhfCkraT1KnZF8TI3
# ye1Z3pner0Cn/p15H7wNwDkBAiZ+2iz9NUEeYLfMGm9vErDVBDRMjGsE/HqqY7QT
# STtDvU7+zZwRPGjiYYUFXT+VgkfdHiFpKw42Xsm0MfL5aOa31FyCM17/pPTIKTRi
# KsDF370SwIwZAjVziD/9QhEFBu9pojFULOZvzuL5iSEJIcqopVAwdbNdroZi2HN8
# nfDjzJa8CMTkQeSfQsQpKr83OhBmE3MF2sz8gqe3loc05DW8JNvZ328Jps3LJCAL
# t0rQPJYnOzCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZI
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
# 6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNN
# MIICNQIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEn
# MCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjhEMDAtMDVFMC1EOTQ3MSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQBu
# +gYs2LRha5pFO79g3LkfwKRnKKCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA6X56xjAiGA8yMDI0MDIyMDAxMTEz
# NFoYDzIwMjQwMjIxMDExMTM0WjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDpfnrG
# AgEAMAcCAQACAhNvMAcCAQACAhMyMAoCBQDpf8xGAgEAMDYGCisGAQQBhFkKBAIx
# KDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZI
# hvcNAQELBQADggEBAGpSWnvJZMg4EKBPPShZS/NVdDoUbwt81ScL7uxrFCgH019o
# zYtEbrjF6WaLTXYJIgR4VqoBQEi8bxD7S73yW0k3Eb8B/B7SSao9YVn9vu4/yI7u
# MQUyX/wJKqA+BbllZ8iX8UAzAGra/cly3pGRmQrU2Nvb/iKmoHeNvVVYh9O+/6DG
# t/H0dzP2JWAP1XINgNODoE/cZqHR/uQx3diTUdEU5uX7FAU7czHiEIKeSU6qNX3a
# zNen3kJ7cdz1gAs0wsxzCm/MT0wMM1he9WO4XcDLTbPZn9pRA6e8n7BQ29KsFPfK
# CHB6DPiPbXCHyl1q3tH7/3qdcvTWZm7Fh/xh/UoxggQNMIIECQIBATCBkzB8MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNy
# b3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAfPFCkOuA8wdMQABAAAB8zAN
# BglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8G
# CSqGSIb3DQEJBDEiBCAVEzFK3qB90GBmG6/f6d2aLYkGYHVqYSZmNQPxfy3a8TCB
# +gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIBi82TSLtuG4Vkp8wBmJk/T+RAh8
# 41sG/aDOwxg6O2LoMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTACEzMAAAHzxQpDrgPMHTEAAQAAAfMwIgQg+muP1e+I16ZwriIZOrvbgfEm00gh
# xOshBRhjp4rQxEMwDQYJKoZIhvcNAQELBQAEggIARITSC0Hh3bgL/Fsm4e9x/Pbu
# QUbLwqDDdcVpVO+rHQaQfWqMW3G2JnVTicgmIWTgwmyY++ju6130icUdC0OZOjYa
# VlQOO7VSvfDdaToLsw7mvb7GqxGTLPg+4Ou90WtkKV3Ace0OAD4qJXkzFWo6Itkp
# n1169KCLm3Bo5Wp+T/t7E4EUHcBis0B4wtyYTud/Y3e24H3w9of/o5nLPDkH3292
# woP9+WFUBsEIJJ2V/pcqYDzZHXZ2wKVIVH91To1KSXx7bmE7Uf08CTdmwh7lqOTx
# WbgRbopNVHZsUZR4CGQMYWLlJh3UHHPnLVKlXRJawp3CwLLA6nPAgTNG8dDRc0eK
# wYHDSAwX2agSumDZhzyMwGpUnMUtG83y4pDKeOfo/qVD+G95iDEmaNHydRRUD+bT
# o756Mp0jvmeuAd9iuvOR1hBNGV4xgLe7pE23DZgubt/ebHZjdEiGB0AM2HSXA0h9
# Us1rxQV1ltFPEV00tL6qBHHDgY9R4wnU3uB3awKwe3Gs/QiBgCPZR+FfuO8koewQ
# +tyQ0aYY+0G7pkIX6IBQvOfN0heSjnHNVzuGlp2yzcQXNduGSjbYuQateicxmwtP
# fExYIXfwwn0XaZ3omQZgvzQUvIPmZxWIlnx7u3cS5TVEuFSLMz22BN6d9+RovGfT
# yU2WZ+mQUfurjr1F4g8=
# SIG # End signature block
