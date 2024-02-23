<#
.SYNOPSIS
   Scenario module for collecting Microsoft Remote Desktop Core related data

.DESCRIPTION
   Collect 'Core' troubleshooting data, suitable for generic Microsoft Remote Desktop troubleshooting

.NOTES
   Author     : Robert Klemencz
   Requires   : At least PowerShell 5.1 (This module is not for stand-alone use. It is used automatically from within the main MSRD-Collect.ps1 script)
   Version    : See MSRD-Collect.ps1 version
   Feedback   : https://aka.ms/MSRD-Collect-Feedback
#>

$msrdLogPrefix = "Core"
$msrdCertLogFolder = $global:msrdBasicLogFolder + "Certificates\"
$msrdDumpFolder = $global:msrdBasicLogFolder + "Dumps\"
$msrdMonTablesFolder = $global:msrdGenevaLogFolder + "MonTables\"
$msrdMonConfigFolder = $global:msrdGenevaLogFolder + "Configuration\"
$msrdRDClientFolder = $global:msrdBasicLogFolder + "RDClient\"
$msrdMDMLogFolder = $global:msrdBasicLogFolder + "MDM\"
$msrdCCMLogFolder = $global:msrdBasicLogFolder + "CCM\"

$msrdUserProfilesDir = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" -Name ProfilesDirectory).ProfilesDirectory
$msrdUserProfilePath = "$msrdUserProfilesDir\$global:msrdUserprof"

$bodyRDLS = '<style>
BODY { background-color:#E0E0E0; font-family: sans-serif; font-size: small; }
table { background-color: white; border-collapse:collapse; border: 1px solid black; padding: 10px; }
td { padding-left: 10px; padding-right: 10px; }
</style>'

$global:msrdFQDN = [System.Net.Dns]::GetHostByName(($env:computerName)).HostName

$script:isDomain = (get-ciminstance -Class Win32_ComputerSystem).PartOfDomain

If (!("Win32Api.NetApi32" -as [type])) {
    Add-Type -MemberDefinition @"
[DllImport("netapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern uint NetApiBufferFree(IntPtr Buffer);
[DllImport("netapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern int NetGetJoinInformation(
    string server,
    out IntPtr NameBuffer,
    out int BufferType);
"@ -Namespace Win32Api -Name NetApi32
}


Function msrdGetAVDMonTables {

    #get AVD monitoring tables data
    msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "msrdGetAVDMonTables"
    $MTfolder = "$env:windir\System32\config\systemprofile\AppData\Roaming\Microsoft\Monitoring\Tables"

    if (Test-path -path $MTfolder) {
        msrdCreateLogFolder $msrdMonTablesFolder

        Try {
            Switch(Get-ChildItem -Path "$env:ProgramFiles\Microsoft RDInfra\") {
                {$_.Name -match "RDMonitoringAgent"} {
                    $convertpath = "$env:ProgramFiles\Microsoft RDInfra\" + $_.Name + "\Agent\table2csv.exe"
                }
            }
        } Catch {
            msrdLogException ("ERROR: An error occurred during preparing Monitoring Tables conversion") -ErrObj $_
            Continue
        }

        Try {
            Switch(Get-ChildItem -Path $MTfolder) {
                {($_.Name -notmatch "00000") -and ($_.Name -match ".tsf")} {
                    $monfile = $MTfolder + "\" + $_.name
                    cmd /c $convertpath -path $msrdMonTablesFolder $monfile 2>&1 | Out-Null
                }
            }
        } Catch {
            msrdLogException ("ERROR: An error occurred during getting Monitoring Tables data") -ErrObj $_
            Continue
        }

    } else {
        msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "Monitoring\Tables folder not found"
    }
}

Function msrdGetAVDMonConfig {

    #get AVD monitoring configuration
    msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "msrdGetAVDMonConfig"
    $MCfolder = "$env:windir\System32\config\systemprofile\AppData\Roaming\Microsoft\Monitoring\Configuration"

    if (Test-path -path $MCfolder) {
        Try {
            Copy-Item $MCfolder $msrdMonConfigFolder -Recurse -ErrorAction Continue 2>&1 | Out-Null
        } Catch {
            msrdLogException ("Error: An error occurred during getting Monitoring Configuration data") -ErrObj $_
        }

    } else {
        msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "Monitoring\Configuration folder not found"
    }
}

Function msrdGetWinRMConfig {

    #get WinRM information
    msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Exporting WinRM configuration"
    if ((get-service -name WinRM).status -eq "Running") {
        Try {
            $config = Get-ChildItem WSMan:\localhost\ -Recurse -ErrorAction Continue 2>>$global:msrdErrorLogFile
            if (!($config)) {
                msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "Cannot connect to localhost, trying with FQDN $global:msrdFQDN"

                try {
                    Connect-WSMan -ComputerName $global:msrdFQDN -ErrorAction Continue 2>>$global:msrdErrorLogFile
                    $config = Get-ChildItem WSMan:\$global:msrdFQDN -Recurse -ErrorAction Continue 2>>$global:msrdErrorLogFile
                    Disconnect-WSMan -ComputerName $global:msrdFQDN -ErrorAction Continue 2>>$global:msrdErrorLogFile
                } catch {
                    msrdLogException ("ERROR: An error occurred during msrdGetWinRMConfig / Connect-WSMan") -ErrObj $_
                }
            }
            $config | Format-Table Name, Value -AutoSize -Wrap | out-file -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "WinRM-Config.txt")
        } Catch {
            msrdLogException ("ERROR: An error occurred during msrdGetWinRMConfig") -ErrObj $_
        }

        Try {
            winrm get winrm/config | Format-Table Name, Value -AutoSize -Wrap 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "WinRM-Config.txt")
        } Catch {
            msrdLogException ("ERROR: An error occurred during winrm get winrm/config") -ErrObj $_
        }

        Try {
            winrm e winrm/config/listener | Format-Table Name, Value -AutoSize -Wrap 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "WinRM-Config.txt")
        } Catch {
            msrdLogException ("ERROR: An error occurred during winrm e winrm/config/listener") -ErrObj $_
        }

    } else {
        msrdLogMessage $LogLevel.Warning -LogPrefix $msrdLogPrefix -Message "WinRM service is not running. Skipping collection of WinRM configuration data"
    }
}

Function msrdGetNBDomainName {

    $pNameBuffer = [IntPtr]::Zero
    $joinStatus = 0
    $apiResult = [Win32Api.NetApi32]::NetGetJoinInformation(
        $null,               # lpServer
        [Ref] $pNameBuffer,  # lpNameBuffer
        [Ref] $joinStatus    # BufferType
    )
    if ($apiResult -eq 0) {
        [Runtime.InteropServices.Marshal]::PtrToStringAuto($pNameBuffer)
        [Void] [Win32Api.NetApi32]::NetApiBufferFree($pNameBuffer)
    }
}

Function msrdGetRdClientAutoTrace {

    #get AVD RDClientAutoTrace files
    $MSRDCfolder = $msrdUserProfilePath + '\AppData\Local\Temp\DiagOutputDir\RdClientAutoTrace\*'

    if (Test-path -path $MSRDCfolder) {
        msrdCreateLogFolder $msrdRDClientFolder
        msrdCreateLogFolder ($msrdRDClientFolder + "RdClientAutoTrace\")

        $m = $MSRDCfolder.TrimEnd("\*")
        msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Copy-Item $m"
        #Getting only traces from over the past 5 days
        (Get-ChildItem $MSRDCfolder | Where-Object { $_.LastWriteTime -ge (Get-Date).AddDays(-5) }) | ForEach-Object {
            Try {
                Copy-Item $_.FullName "$msrdRDClientFolder\RdClientAutoTrace" -Recurse -ErrorAction Continue 2>&1 | Out-Null
            } Catch {
                msrdLogException ("Error: An exception occurred in msrdGetRdClientAutoTrace.") -ErrObj $_
                Continue
            }
        }
    } else {
        msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "'$MSRDCfolder' folder not found"
    }
}

Function msrdGetRdClientSub {

    #get AVD RD Client subscription information
    $MSRDCsub = $msrdUserProfilePath + '\AppData\Local\rdclientwpf\ISubscription.json'

    if (Test-path -path $MSRDCsub) {
        msrdCreateLogFolder $msrdRDClientFolder
        msrdCreateLogFolder ($msrdRDClientFolder + "DesktopClient\")

        msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Copy-Item $MSRDCsub"
        Try {
            Copy-Item $MSRDCsub "$msrdRDClientFolder\DesktopClient" -ErrorAction Continue 2>&1 | Out-Null
        } Catch {
            msrdLogException ("Error: An exception occurred in msrdGetRdClientSub.") -ErrObj $_
        }
    } else {
        msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "'$MSRDCsub' not found"
    }
}

Function msrdGetW365Logs {

    #get AVD RDClientAutoTrace files
    $W365folder = $msrdUserProfilePath + '\AppData\Local\Temp\DiagOutputDir\Windows365\Logs\*'

    if (Test-path -path $W365folder) {
        msrdCreateLogFolder $msrdRDClientFolder
        msrdCreateLogFolder ($msrdRDClientFolder + "WindowsApp\")

        $m = $W365folder.TrimEnd("\*")
        msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Copy-Item $m"
        #Getting logs
        (Get-ChildItem $W365folder) | ForEach-Object {
            Try {
                Copy-Item $_.FullName "$msrdRDClientFolder\WindowsApp" -Recurse -ErrorAction Continue 2>&1 | Out-Null
            } Catch {
                msrdLogException ("Error: An exception occurred in msrdGetMobiusLogs.") -ErrObj $_
                Continue
            }
        }
    } else {
        msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "'$W365folder' folder not found"
    }
}

Function msrdFileVersion {
    param([string] $FilePath, [bool] $Log = $false)

    if (Test-Path -Path $FilePath) {
        $fileobj = Get-item $FilePath
        $filever = $fileobj.VersionInfo.FileMajorPart.ToString() + "." + $fileobj.VersionInfo.FileMinorPart.ToString() + "." + $fileobj.VersionInfo.FileBuildPart.ToString() + "." + $fileobj.VersionInfo.FilePrivatepart.ToString()

        if ($log) {
            ($FilePath + "," + $filever + "," + $fileobj.CreationTime.ToString("yyyyMMdd HH:mm:ss")) 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "KeyFileVersions.csv")
        }
        return $filever | Out-Null
    } else {
        return ""
    }
}

function msrdGetRDLSDBInfo {

    #get RD licensing database information
    $RDSLSKP = msrdGetRDRoleInfo Win32_TSLicenseKeyPack "root\cimv2"
    if ($RDSLSKP) {
        $KPtitle = "Installed RDS license packs"
        $RDSLSKP | ConvertTo-Html -Title $KPtitle -body $bodyRDLS -Property PSComputerName, ProductVersion, Description, TypeAndModel, TotalLicenses, AvailableLicenses, IssuedLicenses, KeyPackId, KeyPackType, ProductVersionId, AccessRights, ExpirationDate | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "rdls_LicenseKeyPacks.html")
    } else {
        msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "[WARNING] Failed to get Win32_TSLicenseKeyPack."
    }

    $RDSLSIL = msrdGetRDRoleInfo Win32_TSIssuedLicense "root\cimv2"
    if ($RDSLSIL) {
        $KPtitle = "Issued RDS licenses"
        $RDSLSIL | ConvertTo-Html -Title $KPtitle -body $bodyRDLS -Property PSComputerName, LicenseId, sIssuedToUser, sIssuedToComputer, IssueDate, ExpirationDate, LicenseStatus, KeyPackId, sHardwareId | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "rdls_IssuedLicenses.html")
    } else {
        msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "[WARNING] Failed to get Win32_TSIssuedLicense."
    }
}

function msrdGetRDGWInfo {

    #get RD Gateway information
    $RDSGWLB = msrdGetRDRoleInfo Win32_TSGatewayLoadBalancer root\cimv2\TerminalServices
    if ($RDSGWLB)
    { $RDSGWLB | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "rdgw_LoadBalancer.txt") }
    else { msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "[WARNING] Failed to get Win32_TSGatewayLoadBalancer." }

    $RDSGWRAD = msrdGetRDRoleInfo Win32_TSGatewayRADIUSServer root\cimv2\TerminalServices
    if ($RDSGWRAD)
    { $RDSGWRAD | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "rdgw_RADIUSServer.txt") }
    else { msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "[WARNING] Failed to get Win32_TSGatewayRADIUSServer." }

    $RDSGWRAP = msrdGetRDRoleInfo Win32_TSGatewayResourceAuthorizationPolicy root\cimv2\TerminalServices
    if ($RDSGWRAP)
    { $RDSGWRAP | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "rdgw_ResourceAuthorizationPolicy.txt") }
    else { msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "[WARNING] Failed to get Win32_TSGatewayResourceAuthorizationPolicy." }

    $RDSGWCAP = msrdGetRDRoleInfo Win32_TSGatewayConnectionAuthorizationPolicy root\cimv2\TerminalServices
    if ($RDSGWCAP)
    { $RDSGWCAP | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "rdgw_ConnectionAuthorizationPolicy.txt") }
    else { msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "[WARNING] Failed to get Win32_TSGatewayConnectionAuthorizationPolicy." }

    $RDSGWRG = msrdGetRDRoleInfo Win32_TSGatewayResourceGroup root\cimv2\TerminalServices
    if ($RDSGWRG)
    { $RDSGWRG | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "rdgw_ResourceGroup.txt") }
    else { msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "[WARNING] Failed to get Win32_TSGatewayResourceGroup." }

    $RDSGWS = msrdGetRDRoleInfo Win32_TSGatewayServerSettings root\cimv2\TerminalServices
    if ($RDSGWS)
    { $RDSGWS | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "rdgw_ServerSettings.txt") }
    else { msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "[WARNING] Failed to get Win32_TSGatewayServerSettings." }

    msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "NPS filtered event logs"
    $eventlog = "Security"
    $msixaalog = $global:msrdEventLogFolder + $env:computername + "_NPS_filtered.evtx"

    if (Get-WinEvent -ListLog $eventlog -ErrorAction SilentlyContinue) {
        Try {
            wevtutil epl $eventlog $msixaalog "/q:*[System [Provider[@Name='NPS']]]"
        } Catch {
            msrdLogException "Error: An error occurred while exporting the MSIXAA logs" -ErrObj $_
        }
    } else {
        msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "Event log '$eventlog' not found"
    }
}

function msrdGetRDCBInfo {

    #get RD Connection Broker information
    $RDCBW = msrdGetRDRoleInfo Win32_Workspace root\cimv2\TerminalServices
    if ($RDCBW)
    { $RDCBW | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "rdcb_Workspace.txt") }
    else { msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "[WARNING] Failed to get Win32_Workspace" }

    $RDCBCPF = msrdGetRDRoleInfo Win32_RDCentralPublishedFarm root\cimv2\TerminalServices
    if ($RDCBCPF)
    { $RDCBCPF | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "rdcb_CentralPublishedFarm.txt") }
    else { msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "[WARNING] Failed to get Win32_RDCentralPublishedFarm" }

    $RDCBCPDS = msrdGetRDRoleInfo Win32_RDCentralPublishedDeploymentSettings root\cimv2\TerminalServices
    if ($RDCBCPDS)
    { $RDCBCPDS | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "rdcb_CentralPublishedDeploymentSettings.txt") }
    else { msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "[WARNING] Failed to get Win32_RDCentralPublishedDeploymentSettings" }

    $RDCBCPFA = msrdGetRDRoleInfo Win32_RDCentralPublishedFileAssociation root\cimv2\TerminalServices
    if ($RDCBCPFA)
    { $RDCBCPFA | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "rdcb_CentralPublishedFileAssociation.txt") }
    else { msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "[WARNING] Failed to get Win32_RDCentralPublishedFileAssociation" }

    $RDCBPDA = msrdGetRDRoleInfo Win32_RDPersonalDesktopAssignment root\cimv2\TerminalServices
    if ($RDCBPDA)
    { $RDCBPDA | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "rdcb_PersonalDesktopAssignment.txt") }
    else { msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "[WARNING] Failed to get Win32_RDPersonalDesktopAssignment" }

    $RDCBSDC = msrdGetRDRoleInfo Win32_SessionDirectoryCluster root\cimv2
    if ($RDCBSDC)
    { $RDCBSDC | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "rdcb_SessionDirectoryCluster.txt") }
    else { msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "[WARNING] Failed to get Win32_SessionDirectoryCluster" }

    $RDCBDS = msrdGetRDRoleInfo Win32_RDMSDeploymentSettings root\cimv2\rdms
    if ($RDCBDS)
    { $RDCBDS | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "rdcb_RDMSDeploymentSettings.txt") }
    else { msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "[WARNING] Failed to get Win32_RDMSDeploymentSettings" }


    #rdms logging
    $rdmsuilogfile = "$env:windir\Logs\RDMSDeploymentUI.txt"
    if (Test-Path -Path $rdmsuilogfile) {
        msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdRDSLogFolder -LogFilePath $rdmsuilogfile -LogFileID 'rdcb_RDMSDeploymentUI.txt'
    }

    $rdmsuitracefile = $msrdUserProfilePath + "\AppData\Local\Temp\RDMSUI-trace.log"
    if (Test-Path -Path $rdmsuitracefile) {
        msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdRDSLogFolder -LogFilePath $rdmsuitracefile -LogFileID 'rdcb_RDMSUI-trace.log'
    }

    $tssesdirPath = "$env:windir\system32\tssesdir\*.xml"
    if (Test-Path -Path $tssesdirPath) {
        msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Collecting %windir%\system32\tssesdir\*.xml"
        msrdCreateLogFolder $global:msrdRDSLogFolder

        $destinationPath = $global:msrdRDSLogFolder + "\tssesdir"
        msrdCreateLogFolder $destinationPath

        $tssesdirXmlFiles = Get-ChildItem -Path $tssesdirPath -Filter "*.xml" -File
        foreach ($file in $tssesdirXmlFiles) {
            $destinationFile = Join-Path -Path $destinationPath -ChildPath $file.Name
            Copy-Item -Path $file.FullName -Destination $destinationFile
        }
    }
}

function msrdGetRDWAInfo {

    #get RD Web Access information
    $Commands = @(
        "$env:windir\SYSTEM32\INETSRV\APPCMD list config 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "rdwa_IISConfig.txt'"
    )
    msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True

    $rdweblogfiles = "$env:windir\web\rdweb\App_Data\rdweb*.log"
    if (Test-Path -Path $rdweblogfiles) {
        msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Collecting %windir%\web\rdweb\App_Data\rdweb*.log"
        msrdCreateLogFolder $global:msrdRDSLogFolder

        $sourcePath = "$env:windir\web\rdweb\App_Data\"
        $destinationPath = $global:msrdRDSLogFolder + "\RDWebLogs"
        msrdCreateLogFolder $destinationPath

        $filesToCopy = Get-ChildItem -Path $sourcePath -Filter "rdweb*.log" -File
        foreach ($file in $filesToCopy) {
            $destinationFile = Join-Path -Path $destinationPath -ChildPath $file.Name
            Copy-Item -Path $file.FullName -Destination $destinationFile
        }
    }
}

Function msrdGetPowerInfo {

    #get Windows Power Management information
    if (($global:WinVerMajor -eq "10") -and ($global:msrdOSVer -notlike "*Windows Server*")) {

        msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "powercfg /systempowerreport"
        $powercfgpath = $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "PowerReport.html"
        Start-Job { powercfg /systempowerreport /output $args } -ArgumentList $powercfgpath | Out-Null
    }

    $Commands = @(
        "powercfg /list 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "PowerSettings.txt'"
        "powercfg /query 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "PowerSettings.txt'"
    )
    msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
}

Function GetRDSFarmData {

    #get RDS deployment information
    Import-Module remotedesktop 2>&1 | Out-File -Append ($global:msrdErrorLogFile)

    #Get Servers of the farm:
    $servers = Get-RDServer -ErrorAction Continue 2>>$global:msrdErrorLogFile
    $BrokerServers = @()
    $WebAccessServers = @()
    $RDSHostServers = @()
    $GatewayServers = @()

    foreach ($server in $servers) {
	    switch ($server.Roles) {
	        "RDS-CONNECTION-BROKER" {$BrokerServers += $server.Server}
	        "RDS-WEB-ACCESS" {$WebAccessServers += $server.Server}
	        "RDS-RD-SERVER" {$RDSHostServers += $server.Server}
	        "RDS-GATEWAY" {$GatewayServers += $server.Server}
	    }
    }

    "Machines involved in the deployment : " + $servers.Count 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    "	-Broker(s) : " + $BrokerServers.Count 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")

    foreach ($BrokerServer in $BrokerServers) {
		    "		" +	$BrokerServer 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
            Try {
                $BrokerServicesStatus = Get-CimInstance -ComputerName $BrokerServer -Query "SELECT * FROM Win32_Service WHERE Name='rdms' OR Name='tssdis' OR Name='tscpubrpc'" -ErrorAction Stop
                foreach ($stat in $BrokerServicesStatus) {
                    "		      - " + $stat.Name + " service is " + $stat.State 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
                }
            } catch {
                msrdLogException ("$(msrdGetLocalizedText "errormsg") BrokerServicesStatus check") -ErrObj $_
                Continue
            }
    }

    " "	 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    "	-RDS Host(s) : " + $RDSHostServers.Count 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")

    foreach ($RDSHostServer in $RDSHostServers) {
		    "		" +	$RDSHostServer 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
            Try {
                $RDSHostServicesStatus = Get-CimInstance -ComputerName $RDSHostServer -Query "SELECT * FROM Win32_Service WHERE Name='TermService'" -ErrorAction Stop
                foreach ($stat in $RDSHostServicesStatus) {
                    "		      - " + $stat.Name +  " service is " + $stat.State 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
                }
            } catch {
                msrdLogException ("$(msrdGetLocalizedText "errormsg") RDSHostServicesStatus check") -ErrObj $_
                Continue
            }
    }

    " "  2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    "	-Web Access Server(s) : " + $WebAccessServers.Count 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")

    foreach ($WebAccessServer in $WebAccessServers) {
		    "		" +	$WebAccessServer 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    }

    " " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    "	-Gateway server(s) : " + $GatewayServers.Count 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")

    foreach ($GatewayServer in $GatewayServers) {
		    "		" +	$GatewayServer 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
            Try {
                $GatewayServicesStatus = Get-CimInstance -ComputerName $GatewayServer -Query "SELECT * FROM Win32_Service WHERE Name='TSGateway'" -ErrorAction Stop
                foreach ($stat in $GatewayServicesStatus) {
                    "		      - " + $stat.Name + " service is " + $stat.State 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
                }
            } catch {
                msrdLogException ("$(msrdGetLocalizedText "errormsg") GatewayServicesStatus check") -ErrObj $_
                Continue
            }
    }
    " " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")

    #Get active broker server.
    $ActiveBroker = Invoke-CimMethod -ClassName Win32_RDMSEnvironment -MethodName GetActiveServer -Namespace ROOT\cimv2\rdms -ErrorAction Continue 2>>$global:msrdErrorLogFile

    $ConnectionBroker = $ActiveBroker.ServerName
    "ActiveManagementServer (broker) : " +	$ActiveBroker.ServerName 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    " " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")

    # Deployment Properties
    "Deployment details : " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    # Is Broker configured in High Availability?
    $HighAvailabilityBroker = Get-RDConnectionBrokerHighAvailability -ErrorAction Continue 2>>$global:msrdErrorLogFile
    $BoolHighAvail = $false
    If ($null -eq $HighAvailabilityBroker)
    {
	    $BoolHighAvail = $false
	    "	Is Connection Broker configured for High Availability : " + $BoolHighAvail 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    }
    else
    {
	    $BoolHighAvail = $true
	    "	Is Connection Broker configured for High Availability : " + $BoolHighAvail 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
	    "		- Client Access Name (Round Robin DNS) : " + $HighAvailabilityBroker.ClientAccessName 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
	    "		- DatabaseConnectionString : " + $HighAvailabilityBroker.DatabaseConnectionString 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
        "		- DatabaseSecondaryConnectionString : " + $HighAvailabilityBroker.DatabaseSecondaryConnectionString 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
	    "		- DatabaseFilePath : " + $HighAvailabilityBroker.DatabaseFilePath 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    }

    #Gateway Configuration
    $GatewayConfig = Get-RDDeploymentGatewayConfiguration -ConnectionBroker $ConnectionBroker -ErrorAction Continue 2>>$global:msrdErrorLogFile
    "	Gateway Mode : " + $GatewayConfig.GatewayMode 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    if ($GatewayConfig.GatewayMode -eq "custom")
    {
    "		- LogonMethod : " + $GatewayConfig.LogonMethod 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    "		- GatewayExternalFQDN : " + $GatewayConfig.GatewayExternalFQDN 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    "		- GatewayBypassLocal : " + $GatewayConfig.BypassLocal 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    "		- GatewayUseCachedCredentials : " + $GatewayConfig.UseCachedCredentials 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")

    }

    # RD Licencing
    $LicencingConfig = Get-RDLicenseConfiguration -ConnectionBroker $ConnectionBroker -ErrorAction Continue 2>>$global:msrdErrorLogFile
    "	Licencing Mode : " + $LicencingConfig.Mode 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    if ($LicencingConfig.Mode -ne "NotConfigured")
    {
    "		- Licencing Server(s) : " + $LicencingConfig.LicenseServer.Count 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    foreach ($licserver in $LicencingConfig.LicenseServer)
    {
    "		       - Licencing Server : " + $licserver 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    }

    }
    # RD Web Access
    "	Web Access Server(s) : " + $WebAccessServers.Count 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    foreach ($WebAccessServer in $WebAccessServers)
    {
    "	     - Name : " + $WebAccessServer 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    "	     - Url : " + "https://" + $WebAccessServer + "/rdweb" 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    }

    # Certificates
    "	Certificates " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    $certificates = Get-RDCertificate -ConnectionBroker $ConnectionBroker -ErrorAction Continue 2>>$global:msrdErrorLogFile
    foreach ($certificate in $certificates)
    {
    "		- Role : " + $certificate.Role 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    "			- Level : " + $certificate.Level 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    "			- Expires on : " + $certificate.ExpiresOn 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    "			- Issued To : " + $certificate.IssuedTo 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    "			- Issued By : " + $certificate.IssuedBy 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    "			- Thumbprint : " + $certificate.Thumbprint 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    "			- Subject : " + $certificate.Subject 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    "			- Subject Alternate Name : " + $certificate.SubjectAlternateName 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")

    }
    " " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")

    #RDS Collections
    $collectionnames = Get-RDSessionCollection -ErrorAction Continue 2>>$global:msrdErrorLogFile
    $client = $null
    $connection = $null
    $loadbalancing = $null
    $Security = $null
    $UserGroup = $null
    $UserProfileDisks = $null

    "RDS Collections : " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
    foreach ($Collection in $collectionnames)
    {
	    $CollectionName = $Collection.CollectionName
	    "	Collection : " +  $CollectionName 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
	    "		Resource Type : " + $Collection.ResourceType 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
	    if ($Collection.ResourceType -eq "RemoteApp programs")
	    {
		    "			Remote Apps : " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    $remoteapps = Get-RDRemoteApp -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -ErrorAction Continue 2>>$global:msrdErrorLogFile
		    foreach ($remoteapp in $remoteapps)
		    {
			    "			- DisplayName : " + $remoteapp.DisplayName 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
			    "				- Alias : " + $remoteapp.Alias 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
			    "				- FilePath : " + $remoteapp.FilePath 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
			    "				- Show In WebAccess : " + $remoteapp.ShowInWebAccess 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
			    "				- CommandLineSetting : " + $remoteapp.CommandLineSetting 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
			    "				- RequiredCommandLine : " + $remoteapp.RequiredCommandLine 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
			    "				- UserGroups : " + $remoteapp.UserGroups 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    }
	    }

    #       $rdshServers
		    $rdshservers = Get-RDSessionHost -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -ErrorAction Continue 2>>$global:msrdErrorLogFile
		    "		Servers in that collection : " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    foreach ($rdshServer in $rdshservers)
		    {
			    "			- SessionHost : " + $rdshServer.SessionHost 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
			    "				- NewConnectionAllowed : " + $rdshServer.NewConnectionAllowed 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    }

		    $client = Get-RDSessionCollectionConfiguration -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -Client -ErrorAction Continue 2>>$global:msrdErrorLogFile
		    "		Client Settings : " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- MaxRedirectedMonitors : " + $client.MaxRedirectedMonitors 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- RDEasyPrintDriverEnabled : " + $client.RDEasyPrintDriverEnabled 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- ClientPrinterRedirected : " + $client.ClientPrinterRedirected 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- ClientPrinterAsDefault : " + $client.ClientPrinterAsDefault 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- ClientDeviceRedirectionOptions : " + $client.ClientDeviceRedirectionOptions 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    " " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")

		    $connection = Get-RDSessionCollectionConfiguration -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -Connection -ErrorAction Continue 2>>$global:msrdErrorLogFile
		    "		Connection Settings : " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- DisconnectedSessionLimitMin : " + $connection.DisconnectedSessionLimitMin 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- BrokenConnectionAction : " + $connection.BrokenConnectionAction 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- TemporaryFoldersDeletedOnExit : " + $connection.TemporaryFoldersDeletedOnExit 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- AutomaticReconnectionEnabled : " + $connection.AutomaticReconnectionEnabled 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- ActiveSessionLimitMin : " + $connection.ActiveSessionLimitMin 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- IdleSessionLimitMin : " + $connection.IdleSessionLimitMin 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    " " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")

		    $loadbalancing = Get-RDSessionCollectionConfiguration -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -LoadBalancing -ErrorAction Continue 2>>$global:msrdErrorLogFile
		    "		Load Balancing Settings : " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    foreach ($SessHost in $loadbalancing)
		    {
		    "			- SessionHost : " + $SessHost.SessionHost 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "				- RelativeWeight : " + $SessHost.RelativeWeight 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "				- SessionLimit : " + $SessHost.SessionLimit 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    }
		    " " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")

		    $Security = Get-RDSessionCollectionConfiguration -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -Security -ErrorAction Continue 2>>$global:msrdErrorLogFile
		    "		Security Settings : " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- AuthenticateUsingNLA : " + $Security.AuthenticateUsingNLA 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- EncryptionLevel : " + $Security.EncryptionLevel 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- SecurityLayer : " + $Security.SecurityLayer 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    " " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")

		    $UserGroup = Get-RDSessionCollectionConfiguration -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -UserGroup -ErrorAction Continue 2>>$global:msrdErrorLogFile
		    "		User Group Settings : " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- UserGroup  : " + $UserGroup.UserGroup 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    " " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")

		    $UserProfileDisks = Get-RDSessionCollectionConfiguration -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -UserProfileDisk -ErrorAction Continue 2>>$global:msrdErrorLogFile
		    "		User Profile Disk Settings : " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- EnableUserProfileDisk : " + $UserProfileDisks.EnableUserProfileDisk 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- MaxUserProfileDiskSizeGB : " + $UserProfileDisks.MaxUserProfileDiskSizeGB 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- DiskPath : " + $UserProfileDisks.DiskPath 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- ExcludeFilePath : " + $UserProfileDisks.ExcludeFilePath 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- ExcludeFolderPath : " + $UserProfileDisks.ExcludeFolderPath 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- IncludeFilePath : " + $UserProfileDisks.IncludeFilePath 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "			- IncludeFolderPath : " + $UserProfileDisks.IncludeFolderPath 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    " " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")

		    $usersConnected = Get-RDUserSession -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -ErrorAction Continue 2>>$global:msrdErrorLogFile
		    "		Users connected to this collection : " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    foreach ($userconnected in $usersConnected)
		    {
		    "			User : " + $userConnected.DomainName + "\" + $userConnected.UserName 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "				- HostServer : " + $userConnected.HostServer 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    "				- UnifiedSessionID : " + $userConnected.UnifiedSessionID 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
		    }
		    " " 2>&1 | Out-File -Append ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "GetFarmData.txt")
        }
} #to rename

Function msrdGetCertStore($store) {

    $certlist = Get-ChildItem ("Cert:\LocalMachine\" + $store)

    foreach ($cert in $certlist) {
        $EKU = ""
        foreach ($item in $cert.EnhancedKeyUsageList) {
            if ($item.FriendlyName) {
                $EKU += $item.FriendlyName + " / "
            } else {
                $EKU += $item.ObjectId + " / "
            }
        }

        $row = $tbcert.NewRow()

        foreach ($ext in $cert.Extensions) {
            if ($ext.oid.value -eq "2.5.29.14") {
                $row.SubjectKeyIdentifier = $ext.SubjectKeyIdentifier.ToLower()
            }
            if (($ext.oid.value -eq "2.5.29.35") -or ($ext.oid.value -eq "2.5.29.1")) {
                $asn = New-Object Security.Cryptography.AsnEncodedData ($ext.oid,$ext.RawData)
                $aki = $asn.Format($true).ToString().Replace(" ","")
                $aki = (($aki -split '\n')[0]).Replace("KeyID=","").Trim()
                $row.AuthorityKeyIdentifier = $aki
            }
        }

        if ($EKU) {$EKU = $eku.Substring(0, $eku.Length-3)}
        $row.Store = $store
        $row.Thumbprint = $cert.Thumbprint.ToLower()
        $row.Subject = $cert.Subject
        $row.Issuer = $cert.Issuer
        $row.NotAfter = $cert.NotAfter
        $row.EnhancedKeyUsage = $EKU
        $row.SerialNumber = $cert.SerialNumber.ToLower()
        $tbcert.Rows.Add($row)
    }
}

function msrdGetDump {
    param ([int]$pidProc)

    #get process dump
    if ($pidProc) {
        if ($global:msrdProcDumpExe -ne "") {
            $procname = Get-Process -id $pidProc -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
            if ($procname) {
                msrdCreateLogFolder $msrdDumpFolder
                msrdLogMessage $LogLevel.Info ('Collecting Process Dump for PID ' + $pidProc + ' (' + $procname + ')')
                try {
                    $Commands = @(
                        "$global:msrdProcDumpExe -AcceptEula -ma $pidProc $msrdDumpFolder 2>&1 | Out-File -Append " + $msrdDumpFolder + $global:msrdLogFilePrefix + "ProcDumpOutput.txt"
                    )
                    msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$True -ShowMessage:$True -ShowError:$True
                } catch {
                    $failedCommand = $_.InvocationInfo.Line.TrimStart()
                    msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
                }
            } else {
                msrdLogMessage $LogLevel.Info ('A process with PID ' + $pidProc + ' could not be found')
                msrdLogMessage $LogLevel.Error ('A process with PID ' + $pidProc + ' could not be found')
            }
        }
    } else {
        if ($global:msrdGUI) {
            msrdAddOutputBoxLine ("Error in msrdGetDump - $pidProc not found") "Magenta"
        } else {
            msrdLogMessage $LogLevel.Warning ("Error in msrdGetDump - $pidProc not found")
        }
    }
}

function msrdGetCoreEventLogs {
    param( [bool[]]$varsCore )

    #get event logs
    " " | Out-File -Append $global:msrdOutputLogFile
    msrdCreateLogFolder $global:msrdEventLogFolder

    if ($varsCore[0]) {
        $logs = @{ 'Security' = 'Security' }
        msrdGetEventLogs -LogPrefix $msrdLogPrefix -EventHashtable $logs
    }

    $logs = @{ #generic logs
        'System' = 'System'
        'Application' = 'Application'
        'Setup' = 'Setup'
        'Microsoft-Windows-AAD/Operational' = 'AAD-Operational'
        'Microsoft-Windows-AppLocker/EXE and DLL' = 'AppLocker-EXEandDLL'
        'Microsoft-Windows-AppLocker/Packaged app-Execution' = 'AppLocker-Packagedapp-Execution'
        'Microsoft-Windows-AppLocker/Packaged app-Deployment' = 'AppLocker-Packagedapp-Deployment'
        'Microsoft-Windows-AppLocker/MSI and Script' = 'AppLocker-MSIandScript'
        'Microsoft-Windows-AppXDeployment/Operational' = 'AppXDeployment-Operational'
        'Microsoft-Windows-AppXDeploymentServer/Operational' = 'AppXDeploymentServer-Operational'
        'Microsoft-Windows-AppXDeploymentServer/Restricted' = 'AppXDeploymentServer-Restricted'
        'Microsoft-Windows-CAPI2/Operational' = 'CAPI2-Operational'
        'Microsoft-Windows-Diagnostics-Performance/Operational' = 'DiagnosticsPerformance-Operational'
        'Microsoft-Windows-GroupPolicy/Operational' = 'GroupPolicy-Operational'
        'Microsoft-Windows-HelloForBusiness/Operational' = 'HelloForBusiness-Operational'
        'Microsoft-Windows-Kernel-PnP/Configuration' = 'KernelPnP-DeviceConfiguration'
        'Microsoft-Windows-Kernel-PnP/Device Management' = 'KernelPnP-DeviceManagement'
        'Microsoft-Windows-NetworkProfile/Operational' = 'NetworkProfile-Operational'
        'Microsoft-Windows-NTLM/Operational' = 'NTLM-Operational'
        'Microsoft-Windows-Shell-Core/Operational' = 'Shell-Core-Operational'
        'Microsoft-Windows-SMBClient/Operational' = 'SMBClient-Operational'
        'Microsoft-Windows-SMBClient/Connectivity' = 'SMBClient-Connectivity'
        'Microsoft-Windows-SMBClient/Security' = 'SMBClient-Security'
        'Microsoft-Windows-TaskScheduler/Operational' = 'TaskScheduler-Operational'
        'Microsoft-Windows-TerminalServices-LocalSessionManager/Admin' = 'TerminalServicesLocalSessionManager-Admin'
        'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational' = 'TerminalServicesLocalSessionManager-Operational'
        'Microsoft-Windows-TerminalServices-PnPDevices/Admin' = 'TerminalServicesPnPDevices-Admin'
        'Microsoft-Windows-TerminalServices-PnPDevices/Operational' = 'TerminalServicesPnPDevices-Operational'
        'Microsoft-Windows-TerminalServices-Printers/Admin' = 'TerminalServicesPrinters-Admin'
        'Microsoft-Windows-TerminalServices-Printers/Operational' = 'TerminalServicesPrinters-Operational'
        'Microsoft-Windows-User Device Registration/Admin' = 'UserDeviceRegistration-Admin'
        'Microsoft-Windows-WER-Diag/Operational' = 'WER-Diagnostics-Operational'
        'Microsoft-Windows-WinINet-Config/ProxyConfigChanged' = 'WinHttp-ProxyConfigChanged'
        'Microsoft-Windows-Workplace Join/Admin' = 'WorkplaceJoin-Admin'
    }

    if ($global:msrdSource) { #source specific
        $logs += @{ #generic logs
            'Microsoft-Windows-RemoteApp and Desktop Connections/Admin' = 'RemoteAppAndDesktopConnections-Admin'
            'Microsoft-Windows-RemoteApp and Desktop Connections/Operational' = 'RemoteAppAndDesktopConnections-Operational'
            'Microsoft-Windows-TerminalServices-ClientUSBDevices/Admin' = 'TerminalServicesClientUSBDevices-Admin'
            'Microsoft-Windows-TerminalServices-ClientUSBDevices/Operational' = 'TerminalServicesClientUSBDevices-Operational'
            'Microsoft-Windows-TerminalServices-RDPClient/Operational' = 'RDPClient-Operational'
        }
    }

    if (!($global:msrdSource)) { #target specific
        $logs += @{
            'Microsoft-Windows-AppReadiness/Admin' = 'AppReadiness-Admin'
            'Microsoft-Windows-AppReadiness/Operational' = 'AppReadiness-Operational'
            'Microsoft-Windows-AppModel-Runtime/Admin' = 'AppModel-Runtime-Admin'
            'Microsoft-Windows-AppxPackaging/Operational' = 'AppxPackaging-Operational'
            'Microsoft-WindowsAzure-Diagnostics/Bootstrapper' = 'WindowsAzure-Diag-Bootstrapper'
            'Microsoft-WindowsAzure-Diagnostics/GuestAgent' = 'WindowsAzure-Diag-GuestAgent'
            'Microsoft-WindowsAzure-Diagnostics/Heartbeat' = 'WindowsAzure-Diag-Heartbeat'
            'Microsoft-WindowsAzure-Diagnostics/Runtime' = 'WindowsAzure-Diag-Runtime'
            'Microsoft-WindowsAzure-Status/GuestAgent' = 'WindowsAzure-Status-GuestAgent'
            'Microsoft-WindowsAzure-Status/Plugins' = 'WindowsAzure-Status-Plugins'
            'Microsoft-Windows-DSC/Operational' = 'DSC-Operational'
            'Microsoft-Windows-PowerShell/Operational' = 'PowerShell-Operational'
            'Microsoft-Windows-RemoteDesktopServices-RdpCoreCDV/Admin' = 'RemoteDesktopServicesRdpCoreCDV-Admin'
            'Microsoft-Windows-RemoteDesktopServices-RdpCoreCDV/Operational' = 'RemoteDesktopServicesRdpCoreCDV-Operational'
            'Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Admin' = 'RemoteDesktopServicesRdpCoreTS-Admin'
            'Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational' = 'RemoteDesktopServicesRdpCoreTS-Operational'
            'Microsoft-Windows-RemoteDesktopServices-SessionServices/Operational' = 'RemoteDesktopServicesSessionServices-Operational'
            'Microsoft-Windows-SMBServer/Operational' = 'SMBServer-Operational'
            'Microsoft-Windows-SMBServer/Connectivity' = 'SMBServer-Connectivity'
            'Microsoft-Windows-SMBServer/Security' = 'SMBServer-Security'
            'Microsoft-Windows-TerminalServices-RemoteConnectionManager/Admin' = 'TerminalServicesRemoteConnectionManager-Admin'
            'Microsoft-Windows-TerminalServices-RemoteConnectionManager/Operational' = 'TerminalServicesRemoteConnectionManager-Operational'
            'Microsoft-Windows-TerminalServices-ServerUSBDevices/Admin' = 'TerminalServicesServerUSBDevices-Admin'
            'Microsoft-Windows-TerminalServices-ServerUSBDevices/Operational' = 'TerminalServicesServerUSBDevices-Operational'
            'Microsoft-Windows-Winlogon/Operational' = 'Winlogon-Operational'
            'Microsoft-Windows-WinRM/Operational' = 'WinRM-Operational'
        }

        if ($global:msrdRDS) { #RDS target specific
            $logs += @{
                'Microsoft-Windows-Rdms-UI/Admin' = 'Microsoft-Windows-Rdms-UI-Admin'
                'Microsoft-Windows-Rdms-UI/Operational' = 'Rdms-UI-Operational'
                'Microsoft-Windows-Remote-Desktop-Management-Service/Admin' = 'RemoteDesktopManagementService-Admin'
                'Microsoft-Windows-Remote-Desktop-Management-Service/Operational' = 'RemoteDesktopManagementService-Operational'
                'Microsoft-Windows-RemoteApp and Desktop Connection Management/Admin' = 'RemoteAppAndDesktopConnections-Management-Admin'
                'Microsoft-Windows-RemoteApp and Desktop Connection Management/Operational' = 'RemoteAppAndDesktopConnections-Management-Operational'
                'Microsoft-Windows-TerminalServices-SessionBroker/Admin' = 'TerminalServicesSessionBroker-Admin'
                'Microsoft-Windows-TerminalServices-SessionBroker/Operational' = 'TerminalServicesSessionBroker-Operational'
                'Microsoft-Windows-TerminalServices-SessionBroker-Client/Admin' = 'TerminalServicesSessionBroker-Client-Admin'
                'Microsoft-Windows-TerminalServices-SessionBroker-Client/Operational' = 'TerminalServicesSessionBroker-Client-Operational'
                'Microsoft-Windows-TerminalServices-TSAppSrv-TSVIP/Admin' = 'TerminalServicesTSAppSrv-TSVIP-Admin'
                'Microsoft-Windows-TerminalServices-TSAppSrv-TSVIP/Operational' = 'TerminalServicesTSAppSrv-TSVIP-Operational'
                'Microsoft-Windows-TerminalServices-TSV-VmHostAgent/Admin' = 'TerminalServicesTSV-VmHostAgent-Admin'
                'Microsoft-Windows-TerminalServices-TSV-VmHostAgent/Operational' = 'TerminalServicesTSV-VmHostAgent-Operational'
            }
        }

        if ($global:msrdRDS -or $global:msrdAVD) { #not CPC specific
            $logs += @{
                'Microsoft-Windows-TerminalServices-Gateway/Admin' = 'TerminalServicesGateway-Admin'
                'Microsoft-Windows-TerminalServices-Gateway/Operational' = 'TerminalServicesGateway-Operational'
                'Microsoft-Windows-TerminalServices-Licensing/Admin' = 'TerminalServicesLicensing-Admin'
                'Microsoft-Windows-TerminalServices-Licensing/Operational' = 'TerminalServicesLicensing-Operational'
                'Microsoft-Windows-TerminalServices-TSAppSrv-TSMSI/Admin' = 'TerminalServicesTSAppSrv-TSMSI-Admin'
                'Microsoft-Windows-TerminalServices-TSAppSrv-TSMSI/Operational' = 'TerminalServicesTSAppSrv-TSMSI-Operational'
            }
        }

        if ($global:msrdAVD -or $global:msrdW365) { #avd target specific
            $logs += @{ 'RemoteDesktopServices' = 'RemoteDesktopServices' }
        }
    }

    msrdGetEventLogs -LogPrefix $msrdLogPrefix -EventHashtable $logs
}

function msrdGetCoreRegKeys {

    #get registry keys
    " " | Out-File -Append $global:msrdOutputLogFile
    msrdCreateLogFolder $msrdRegLogFolder

    $regs = @{ #generic
        'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' = 'SW-MS-NetFS-NDP'
        'HKLM:\SOFTWARE\Microsoft\Ole' = 'SW-MS-Ole'
        'HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters' = 'SW-MS-VM-GuestParams'
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings' = 'SW-MS-Win-CV-InternetSettings'
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings' = 'SW-MS-Win-CV-InternetSettings'
        'HKU:\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings' = 'Def-SW-MS-Win-CV-InternetSettings'
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies' = 'SW-MS-Win-CV-Policies'
        'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' = 'SW-MS-Win-WindowsErrorReporting'
        'HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions' = 'SW-MS-WinDef-Exclusions'
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers' = 'SW-MS-WinNT-CV-AppCompatFlags-Layers'
        'HKLM:\SOFTWARE\Policies' = 'SW-Policies'
        'HKCU:\SOFTWARE\Policies' = 'SW-Policies'
        'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' = 'System-CCS-Control-CrashControl'
        'HKLM:\SYSTEM\CurrentControlSet\Control\Cryptography' = 'System-CCS-Control-Cryptography'
        'HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin' = 'System-CCS-Control-CloudDomainJoin'
        'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' = 'System-CCS-Control-LSA'
        'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders' = 'System-CCS-Control-SecurityProviders'
        'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' = 'System-CCS-Control-SessMan-MemoryManagement'
        'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip' = 'System-CCS-Svc-Tcpip'
        'HKLM:\SYSTEM\CurrentControlSet\Services\WinRM' = 'System-CCS-Svc-WinRM'
    }

    if ($global:msrdSource) { #source specific

        $regs += @{ #generic source
            'HKLM:\SOFTWARE\Microsoft\Terminal Server Client' = 'SW-MS-TerminalServerClient'
            'HKCU:\SOFTWARE\Microsoft\Terminal Server Client' = 'SW-MS-TerminalServerClient'
            'HKLM:\SOFTWARE\Microsoft\MSLicensing' = 'SW-MS-MSLicensing'
        }

        if ($global:msrdAVD -or $global:msrdw365) { #AVD+W365 source specific
            $regs += @{
                'HKLM:\SOFTWARE\Microsoft\MSRDC' = 'SW-MS-MSRDC'
                'HKCU:\SOFTWARE\Microsoft\MSRDC' = 'SW-MS-MSRDC'
                'HKCU:\SOFTWARE\Microsoft\RdClientRadc' = 'SW-MS-RdClientRadc'
                'HKCU:\SOFTWARE\Microsoft\Remote Desktop' = 'SW-MS-RemoteDesktop'
            }
        }
    }

    if (!($global:msrdSource)) { #target specific
        $regs += @{ #generic target
            'HKLM:\SOFTWARE\Microsoft\Azure\DSC' = 'SW-MS-Azure-DSC'
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI' = 'SW-MS-Win-CV-Auth-LogonUI'
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' = 'SW-MS-Win-CV-Run'
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' = 'SW-MS-Win-CV-Run'
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' = 'SW-MS-Win-CV-RunOnce'
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' = 'SW-MS-Win-CV-RunOnce'
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup' = 'SW-MS-Win-CV-Setup'
            'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server' = 'SW-MS-WinNT-CV-TerminalServer'
            'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' = 'SW-MS-WinNT-CV-Winlogon'
            'HKLM:\SYSTEM\CurrentControlSet\Control\CoDeviceInstallers' = 'System-CCS-Control-CoDeviceInstallers'
            'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' = 'System-CCS-Control-TerminalServer'
            'HKLM:\SYSTEM\CurrentControlSet\Enum\TERMINPUT_BUS' = 'System-CCS-Enum-TERMINPUT_BUS'
            'HKLM:\SYSTEM\CurrentControlSet\Enum\TERMINPUT_BUS_SXS' = 'System-CCS-Enum-TERMINPUT_BUS_SXS'
            'HKLM:\SYSTEM\CurrentControlSet\Services\i8042prt' = 'System-CCS-Svc-i8042prt'
            'HKLM:\SYSTEM\CurrentControlSet\Services\TermService' = 'System-CCS-Svc-TermService'
            'HKLM:\SYSTEM\CurrentControlSet\Services\UmRdpService' = 'System-CCS-Svc-UmRdpService'
            'HKLM:\SYSTEM\DriverDatabase\DeviceIds\TS_INPT' = 'System-DriverDB-DeviceIds-TS_INPT'
        }

        if ($global:msrdRDS) { #RDS target specific
            $regs += @{
                'HKLM:\SYSTEM\CurrentControlSet\Services\MSSQL$MICROSOFT##WID' = 'System-CCS-Svc-MSSQL$MICROSOFT##WID'
                'HKLM:\SYSTEM\CurrentControlSet\Services\RDMS' = 'System-CCS-Svc-RDMS'
                'HKLM:\SYSTEM\CurrentControlSet\Services\TScPubRPC' = 'System-CCS-Svc-TScPubRPC'
                'HKLM:\SYSTEM\CurrentControlSet\Services\Tssdis' = 'System-CCS-Svc-Tssdis'
                'HKLM:\SYSTEM\CurrentControlSet\Services\W3SVC' = 'System-CCS-Svc-W3SVC'
            }
        }

        if ($global:msrdRDS -or $global:msrdAVD) { #RDS+AVD target specific
            if ($global:msrdOSVer -like "*Server*") {
                $regs += @{
                    'HKLM:\SOFTWARE\Microsoft\TermServLicensing' = 'SW-MS-TermServLicensing'
                    'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\TerminalServerGateway' = 'SW-MS-WinNT-CV-TerminalServerGateway'
                    'HKLM:\SYSTEM\CurrentControlSet\Services\TermServLicensing' = 'System-CCS-Svc-TermServLicensing'
                    'HKLM:\SYSTEM\CurrentControlSet\Services\TSGateway' = 'System-CCS-Svc-TSGateway'
                }
            } else {
                $regs += @{
                    'HKLM:\SYSTEM\CurrentControlSet\Services\TSFairShare' = 'System-CCS-Svc-TSFairShare'
                }
            }
        }

        if ($global:msrdAVD -or $global:msrdw365) { #AVD+W365 target specific
            $regs += @{
                'HKLM:\SOFTWARE\Microsoft\RDMonitoringAgent' = 'SW-MS-RDMonitoringAgent'
                'HKLM:\SOFTWARE\Microsoft\RDInfraAgent' = 'SW-MS-RDInfraAgent'
                'HKLM:\SOFTWARE\Microsoft\RDAgentBootLoader' = 'SW-MS-RDAgentBootLoader'
                'HKLM:\SYSTEM\CurrentControlSet\Services\RDAgentBootLoader' = 'System-CCS-Svc-RDAgentBootLoader'
            }
        }
    }

    msrdGetRegKeys -LogPrefix $msrdLogPrefix -RegHashtable $regs
}

function msrdGetCoreRDPNetADInfo {
    param( [bool[]]$varsCore )

    #get RDP, networking and AD information
    " " | Out-File -Append $global:msrdOutputLogFile
    msrdCreateLogFolder $global:msrdNetLogFolder
    msrdCreateLogFolder $global:msrdSysInfoLogFolder

    $Commands = @( #generic
        "Get-NetConnectionProfile | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "NetConnectionProfile.txt'"
        "Get-NetIPInterface | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "NetIPInterface.txt'"
        "Get-NetIPInterface | fl | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "NetIPInterface.txt'"
        "netstat -anobq 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "Netstat.txt'"
        "ipconfig /all 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "Ipconfig.txt'"
        "netsh interface tcp show global 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "NetshInterfaceGlobal.txt'"
        "netsh interface udp show global 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "NetshInterfaceGlobal.txt'"
        "netsh winhttp show proxy 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "Proxy.txt'"
        "netsh winsock show catalog 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "WinsockCatalog.txt'"
        "netsh interface Teredo show state 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "Teredo.txt'"
        "netsh advfirewall firewall show rule name=all 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "FirewallRules.txt'"
        "nslookup wpad 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "Nslookup.txt'"
        "bitsadmin /util /getieproxy LOCALSYSTEM 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "Proxy.txt'"
        "bitsadmin /util /getieproxy NETWORKSERVICE 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "Proxy.txt'"
        "bitsadmin /util /getieproxy LOCALSERVICE 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "Proxy.txt'"
        "route print 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "Route.txt'"
    )

    if ($global:msrdPsPingExe -ne "") {
        $Commands += @("cmd /c $global:msrdPsPingExe 8.8.8.8:443 -nobanner /accepteula 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "PsPing.txt'")

        if ($global:msrdAVD -or $global:msrdW365) {
            $Commands += @("nslookup rdweb.wvd.microsoft.com 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "Nslookup.txt'")

            if ($global:msrdSource) {
                $Commands += @("cmd /c $global:msrdPsPingExe rdweb.wvd.microsoft.com:443 -nobanner /accepteula 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "PsPing.txt'")
            } else {
                $Commands += @("cmd /c $global:msrdPsPingExe rdbroker.wvd.microsoft.com:443 -nobanner /accepteula 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "PsPing.txt'")
            }
        }
    }

    if (!($global:msrdOSVer -like "*Server*2008*") -and !($global:msrdOSVer -like "*Server*2012*")) {
        if ($varsCore[0]) {
            $Commands += @("dsregcmd /status 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "Dsregcmd.txt'")
        }
    }

    msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True


    Try {
        $vmdomain = [System.Directoryservices.Activedirectory.Domain]::GetComputerDomain()
        $Commands = @(
            "nltest /sc_query:$vmdomain 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "Nltest-scquery.txt'"
            "nltest /dnsgetdc:$vmdomain 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "Nltest-dnsgetdc.txt'"
            "nltest /domain_trusts /all_trusts /v 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "Nltest-domtrusts.txt'"
        )
        msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
    } Catch {
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
    }

    if ($global:msrdSource) { #source only
        $Commands = @(
            "netsh lan show settings 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "NetshLanSettings.txt'"
            "netsh wlan show settings 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "NetshLanSettings.txt'"
            "netsh wlan show wlanreport duration='5' 2>&1 | Out-File -Append '" + $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "NetshWlanReport.txt'"
        )
        msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True

        $wlanreportpath = "$env:ProgramData\Microsoft\Windows\WlanReport\wlan-report-latest.html"
        if (Test-Path -Path $wlanreportpath) {
            $wlanreporttarget = $global:msrdNetLogFolder + $global:msrdLogFilePrefix + "NetshWlanReport.html"
            "Copy-Item '$wlanreportpath' to '$wlanreporttarget'" | Out-File -Append ($global:msrdNetLogFolder + $global:msrdLogFilePrefix + "NetshWlanReport.txt")

			Copy-Item -Path $wlanreportpath -Destination $wlanreporttarget -Force -ErrorAction Continue 2>>$global:msrdErrorLogFile
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "'$wlanreportpath' not found"
        }
    }

    if (!($global:msrdSource)) { #target only
        if ($global:msrdAVD -or $global:msrdW365) { $global:rdtreefolder = $global:msrdAVDLogFolder } else { $global:rdtreefolder = $global:msrdRDSLogFolder }

        msrdCreateLogFolder $rdtreefolder
        $Commands = @("tree '$env:windir\RemotePackages' /f 2>&1 | Out-File -Append '" + $rdtreefolder + $global:msrdLogFilePrefix + "tree_Win-RemotePackages.txt'")

        if ($global:msrdAVD -or $global:msrdW365) { #target only without RDS
            $msrdAgentpath = "$env:ProgramFiles\Microsoft RDInfra\"
            $Commands += @("tree '$msrdAgentpath' /f 2>&1 | Out-File -Append '" + $global:msrdAVDLogFolder + $global:msrdLogFilePrefix + "tree_ProgFiles-MicrosoftRDInfra.txt'")

            if (Test-Path -Path $msrdAgentpath) { #run WVDAgentUrlTool
                $toolfolder = Get-ChildItem $msrdAgentpath -Directory | Foreach-Object {If (($_.psiscontainer) -and ($_.fullname -like "*RDAgent_*")) { $_.Name }} | Select-Object -Last 1
                $URLCheckToolPath = $msrdAgentpath + $toolfolder + "\WVDAgentUrlTool.exe"

                $Commands += @("& '$URLCheckToolPath' 2>&1 | Out-File -Append '" + $global:msrdAVDLogFolder + $global:msrdLogFilePrefix + "WVDAgentUrlTool.txt'")
            } else {
                msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "WVDAgentUrlTool.exe not found ($msrdAgentpath folder not found)."
            }
        }

        msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
    }
}

function msrdGetCoreSchedTasks {

    if ($global:msrdAVD -or $global:msrdW365) { #get task scheduler information
        msrdCreateLogFolder $global:msrdSchtaskFolder

        if (Get-ScheduledTask -TaskPath '\RemoteDesktop\*' -ErrorAction Ignore) {

            if ($global:msrdUserprof) {
                $rdschedUser = "\RemoteDesktop\" + $global:msrdUserprof + "\"
            } else {
                $rdschedUser = "\RemoteDesktop\" + [System.Environment]::UserName + "\"
            }

            msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Exporting Remote Desktop Scheduled Tasks information"
            Get-ScheduledTask -TaskPath "$rdschedUser" | Export-ScheduledTask 2>&1 | Out-File -Append ($global:msrdSchtaskFolder + $global:msrdLogFilePrefix + "schtasks_RemoteDesktop.xml")
            Get-ScheduledTaskInfo -TaskName "Remote Desktop Feed Refresh Task" -TaskPath "$rdschedUser" 2>&1 | Out-File -Append ($global:msrdSchtaskFolder + $global:msrdLogFilePrefix + "schtasks_RemoteDesktop_Info.txt")
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "Remote Desktop Scheduled Tasks not found"
        }
    }
}

function msrdGetCoreSystemInfo {

    #get system information
    " " | Out-File -Append $global:msrdOutputLogFile
    msrdCreateLogFolder $global:msrdSysInfoLogFolder

    msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Exporting details about currently running processes and key system binaries"

    if ($PSVersionTable.psversion.ToString() -ge "3.0") {
        $StartTime= @{e={$_.CreationDate.ToString("yyyyMMdd HH:mm:ss")};n="Start time"}
    } else {
        $StartTime= @{n='StartTime';e={$_.ConvertToDateTime($_.CreationDate)}}
    }

    Try {
        $proc = Get-CimInstance -Namespace "root\cimv2" -Query "select Name, CreationDate, ProcessId, ParentProcessId, WorkingSetSize, UserModeTime, KernelModeTime, ThreadCount, HandleCount, CommandLine, ExecutablePath from Win32_Process" -ErrorAction Continue 2>>$global:msrdErrorLogFile
        if ($proc) {
            $proc | Sort-Object Name | Format-Table -AutoSize -property @{e={$_.ProcessId};Label="PID"}, @{e={$_.ParentProcessId};n="Parent"}, Name,
            @{N="WorkingSet";E={"{0:N0}" -f ($_.WorkingSetSize/1kb)};a="right"},
            @{e={[DateTime]::FromFileTimeUtc($_.UserModeTime).ToString("HH:mm:ss")};n="UserTime"}, @{e={[DateTime]::FromFileTimeUtc($_.KernelModeTime).ToString("HH:mm:ss")};n="KernelTime"},
            @{N="Threads";E={$_.ThreadCount}}, @{N="Handles";E={($_.HandleCount)}}, $StartTime, CommandLine | Out-String -Width 500 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "RunningProcesses.txt")

            $binlist = $proc | Group-Object -Property ExecutablePath
            foreach ($file in $binlist) {
                if ($file.Name) {
                    msrdFileVersion -Filepath ($file.name) -Log $true 2>&1 | Out-Null
                }
            }

            $pad = 27
            $OS = Get-CimInstance -Namespace "root\cimv2" -Query "select Caption, CSName, OSArchitecture, BuildNumber, InstallDate, LastBootUpTime, LocalDateTime, TotalVisibleMemorySize, FreePhysicalMemory, SizeStoredInPagingFiles, FreeSpaceInPagingFiles from Win32_OperatingSystem" -ErrorAction SilentlyContinue 2>>$global:msrdErrorLogFile
            $CS = Get-CimInstance -Namespace "root\cimv2" -Query "select Model, Manufacturer, SystemType, NumberOfProcessors, NumberOfLogicalProcessors, TotalPhysicalMemory, DNSHostName, Domain, DomainRole from Win32_ComputerSystem" -ErrorAction SilentlyContinue 2>>$global:msrdErrorLogFile
            $BIOS = Get-CimInstance -Namespace "root\cimv2" -query "select BIOSVersion, Manufacturer, ReleaseDate, SMBIOSBIOSVersion from Win32_BIOS" -ErrorAction SilentlyContinue 2>>$global:msrdErrorLogFile
            $TZ = Get-CimInstance -Namespace "root\cimv2" -Query "select Description from Win32_TimeZone" -ErrorAction SilentlyContinue 2>>$global:msrdErrorLogFile
            $PR = Get-CimInstance -Namespace "root\cimv2" -Query "select Name, Caption from Win32_Processor" -ErrorAction SilentlyContinue 2>>$global:msrdErrorLogFile

            $ctr = Get-Counter -Counter "\Memory\Pool Paged Bytes" -ErrorAction SilentlyContinue 2>>$global:msrdErrorLogFile
            if ($ctr) { $PoolPaged = $ctr.CounterSamples[0].CookedValue }

            $ctr = Get-Counter -Counter "\Memory\Pool Nonpaged Bytes" -ErrorAction SilentlyContinue 2>>$global:msrdErrorLogFile
            if ($ctr) { $PoolNonPaged = $ctr.CounterSamples[0].CookedValue }

            "Computer name".PadRight($pad) + " : " + $OS.CSName 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "Model".PadRight($pad) + " : " + $CS.Model 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "Manufacturer".PadRight($pad) + " : " + $CS.Manufacturer 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "BIOS Version".PadRight($pad) + " : " + $BIOS.BIOSVersion 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "BIOS Manufacturer".PadRight($pad) + " : " + $BIOS.Manufacturer 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "BIOS Release date".PadRight($pad) + " : " + $BIOS.ReleaseDate 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "SMBIOS Version".PadRight($pad) + " : " + $BIOS.SMBIOSBIOSVersion 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "SystemType".PadRight($pad) + " : " + $CS.SystemType 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "Processor".PadRight($pad) + " : " + $PR.Name + " / " + $PR.Caption 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "Processors physical/logical".PadRight($pad) + " : " + $CS.NumberOfProcessors + " / " + $CS.NumberOfLogicalProcessors 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "Memory physical/visible".PadRight($pad) + " : " + ("{0:N0}" -f ($CS.TotalPhysicalMemory/1mb)) + " MB / " + ("{0:N0}" -f ($OS.TotalVisibleMemorySize/1kb)) + " MB" 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "Pool Paged / NonPaged".PadRight($pad) + " : " + ("{0:N0}" -f ($PoolPaged/1mb)) + " MB / " + ("{0:N0}" -f ($PoolNonPaged/1mb)) + " MB" 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "Free physical memory".PadRight($pad) + " : " + ("{0:N0}" -f ($OS.FreePhysicalMemory/1kb)) + " MB" 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "Paging files size / free".PadRight($pad) + " : " + ("{0:N0}" -f ($OS.SizeStoredInPagingFiles/1kb)) + " MB / " + ("{0:N0}" -f ($OS.FreeSpaceInPagingFiles/1kb)) + " MB" 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "Operating System".PadRight($pad) + " : " + $OS.Caption + " " + $OS.OSArchitecture 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")

            if (($global:msrdOSVer -like "*Server*2008*") -or ($global:msrdOSVer -like "*Server*2012*")) {
                "Build Number".PadRight($pad) + " : " + $global:WinVerMajor + "." + $global:WinVerBuild + "." + $global:WinVerRevision 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            } else {
                "Build Number".PadRight($pad) + " : " + $global:WinVerMajor + "." + $global:WinVerMinor + "." + $global:WinVerBuild + "." + $global:WinVerRevision 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            }

            "Installation type".PadRight($pad) + " : " + (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").InstallationType 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "Time zone".PadRight($pad) + " : " + $TZ.Description 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "Install date".PadRight($pad) + " : " + $OS.InstallDate 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "Last boot time".PadRight($pad) + " : " + $OS.LastBootUpTime 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "Local time".PadRight($pad) + " : " + $OS.LocalDateTime 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "DNS Hostname".PadRight($pad) + " : " + $CS.DNSHostName 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "DNS Domain name".PadRight($pad) + " : " + $CS.Domain 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            "NetBIOS Domain name".PadRight($pad) + " : " + (msrdGetNBDomainName) 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
            $roles = "Standalone Workstation", "Member Workstation", "Standalone Server", "Member Server", "Backup Domain Controller", "Primary Domain Controller"
            "Domain role".PadRight($pad) + " : " + $roles[$CS.DomainRole] 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")

            " " | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")

            $drives = @()
            $drvtype = "Unknown", "No Root Directory", "Removable Disk", "Local Disk", "Network Drive", "Compact Disc", "RAM Disk"
            $Vol = Get-CimInstance -NameSpace "root\cimv2" -Query "select * from Win32_LogicalDisk" -ErrorAction Continue 2>>$global:msrdErrorLogFile
            foreach ($disk in $vol) {
                    $drv = New-Object PSCustomObject
                    $drv | Add-Member -type NoteProperty -name Letter -value $disk.DeviceID
                    $drv | Add-Member -type NoteProperty -name DriveType -value $drvtype[$disk.DriveType]
                    $drv | Add-Member -type NoteProperty -name VolumeName -value $disk.VolumeName
                    $drv | Add-Member -type NoteProperty -Name TotalMB -Value ($disk.size)
                    $drv | Add-Member -type NoteProperty -Name FreeMB -value ($disk.FreeSpace)
                    $drives += $drv
                }
            $drives | Format-Table -AutoSize -property Letter, DriveType, VolumeName, @{N="TotalMB";E={"{0:N0}" -f ($_.TotalMB/1MB)};a="right"}, @{N="FreeMB";E={"{0:N0}" -f ($_.FreeMB/1MB)};a="right"} 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
        } else {
            $proc = Get-Process | Where-Object {$_.Name -ne "Idle"}
            $proc | Format-Table -AutoSize -property id, name, @{N="WorkingSet";E={"{0:N0}" -f ($_.workingset/1kb)};a="right"},
            @{N="VM Size";E={"{0:N0}" -f ($_.VirtualMemorySize/1kb)};a="right"},
            @{N="Proc time";E={($_.TotalProcessorTime.ToString().substring(0,8))}}, @{N="Threads";E={$_.threads.count}},
            @{N="Handles";E={($_.HandleCount)}}, StartTime, Path | Out-String -Width 300 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "RunningProcesses.txt")
        }
    } Catch {
        msrdLogMessage $LogLevel.Error ("Error collecting details about currently running processes" + $_.Exception.Message)
    }

    msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "gpresult /h"
    $gpresultpath = $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "Gpresult.html"
    Start-Job { gpresult /h $args } -ArgumentList $gpresultpath | Out-Null

    $Commands = @(
        "gpresult /r /z 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "Gpresult-rz.txt'"
        "Get-Process | Sort-Object CPU -desc | Select-Object -first 10 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "RunningProcesses-Top10CPU.txt'"
        "Get-WmiObject -Namespace root\SecurityCenter2 -Class AntiVirusProduct 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "AntiVirusProducts.txt'"
        "Get-CimInstance -NameSpace 'root\SecurityCenter2' -Query 'select * from FirewallProduct' 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "FirewallProducts.txt'"
        "fltmc filters 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "Fltmc.txt'"
        "fltmc volumes 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "Fltmc.txt'"
        "tasklist /v 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "Tasklist.txt'"
        "icacls C:\ 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "Permissions-DriveC.txt'"
        "Get-ChildItem Env: | Format-Table -AutoSize -Wrap | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "EnvironmentVariables.txt'"
        "(Get-Item -Path '$env:windir\System32\*.exe').VersionInfo | Format-List -Force 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "System32_EXE.txt'"
        "(Get-Item -Path '$env:windir\System32\*.sys').VersionInfo | Format-List -Force 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "System32_SYS.txt'"
        "(Get-Item -Path '$env:windir\System32\drivers\*.sys').VersionInfo | Format-List -Force 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "Drivers.txt'"
        "(Get-AppLockerPolicy -Effective).RuleCollections 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "AppLockerRules.txt'"
        "dxdiag /whql:off /t '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "DxDiag.txt' 2>&1 | Out-Null"
    )

    if (!($global:msrdSource)) {
        $Commands += @(
            "Get-DscConfiguration 2>&1 | Format-Table -AutoSize -Wrap | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "DscConfiguration.txt'"
            "Get-DscConfigurationStatus -all 2>&1 | Format-Table -AutoSize -Wrap | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "DscConfiguration.txt'"
            "Test-DscConfiguration -Detailed 2>&1 | Format-Table -AutoSize -Wrap | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "DscConfiguration.txt'"
        )
    }
    msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True

    $dllpath = $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "System32_DLL.txt"
    $windir = $env:windir
    msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "(Get-Item -Path '$windir\System32\*.dll').VersionInfo"
    Start-Job -ScriptBlock { (Get-Item -Path "$using:windir\System32\*.dll").VersionInfo | Format-List -Force 2>&1 | Out-File $using:dllpath } | Out-Null

    if ($global:WinVerMajor -eq "10") {
        $Commands = @(
            "pnputil /enum-drivers 2>&1 | Out-File -Append " + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "PnpUtil-Drivers.txt"
            "pnputil /enum-devices /ids /relations /drivers /class Keyboard 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "PnpUtil-Devices-Keyboard.txt'"
            "pnputil /enum-devices /ids /relations /drivers /class Mouse 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "PnpUtil-Devices-Mouse.txt'"
            "Get-PnpDevice -PresentOnly | Format-Table -AutoSize -Wrap 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "PnpDevice.txt'"
            "Get-MpComputerStatus 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "AntiVirusProducts.txt'"
        )
    } else {
        $Commands = @(
            "pnputil -e 2>&1 | Out-File -Append " + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "PnpUtil-Drivers.txt"
        )
    }
    msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True

    msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "msinfo32 /nfo"
    $mspathnfo = $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "Msinfo32.nfo"
    Start-Job { msinfo32 /nfo $args } -ArgumentList $mspathnfo | Out-Null

    #get WMI quota
    msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Collecting provider host quota details"
    $quota = Get-CimInstance -Namespace "Root" -Query "select * from __ProviderHostQuotaConfiguration" -ErrorAction Continue 2>>$global:msrdErrorLogFile
    if ($quota) {
        ("ThreadsPerHost : " + $quota.ThreadsPerHost + "`r`n") + `
        ("HandlesPerHost : " + $quota.HandlesPerHost + "`r`n") + `
        ("ProcessLimitAllHosts : " + $quota.ProcessLimitAllHosts + "`r`n") + `
        ("MemoryPerHost : " + $quota.MemoryPerHost + "`r`n") + `
        ("MemoryAllHosts : " + $quota.MemoryAllHosts + "`r`n") | Out-File -FilePath ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "ProviderHostQuotaConfiguration.txt")
    }

    #get setup info
    msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdSysInfoLogFolder -LogFilePath "$env:windir\panther\Setupact.log" -LogFileID 'Setupact.log'
    msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdSysInfoLogFolder -LogFilePath "$env:windir\inf\setupapi.dev.log" -LogFileID 'setupapi-dev.log'
    msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdSysInfoLogFolder -LogFilePath "$env:windir\inf\setupapi.app.log" -LogFileID 'setupapi-app.log'
    msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdSysInfoLogFolder -LogFilePath "$env:windir\Logs\CBS\CBS.log" -LogFileID 'CBS.log'

    #get WinRM configuration
    msrdGetWinRMConfig

    #get system power configuration information
    msrdGetPowerInfo

    msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Exporting list of installed applications"
    $paths=@(
      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\',
      'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\',
      'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\',
      'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\'
    )
    foreach($path in $paths) {
        if (Test-Path -Path $path) {
            "Based on $path" 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "InstalledApplications.txt")
            Get-ChildItem -Path $path -ErrorAction SilentlyContinue | Get-ItemProperty | Select-Object DisplayName, Publisher, InstallDate, DisplayVersion | Format-Table -AutoSize -Wrap | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "InstalledApplications.txt")
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "'$path' not found"
        }
    }

    #get nvidia gpu configuration if available
    $gpuInfo = Get-CimInstance -ClassName Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*" }

    if ($gpuInfo) { # If NVIDIA GPU is present
        msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "NVIDIA SMI"
        $nvidiasmiPath = "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
        if (Test-Path -Path $nvidiasmiPath) {
            $Commands = @("cmd /c '$nvidiasmiPath' 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "nvidia-smi.txt'")
            msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
        } else {
            $nvidiaDriverStorePath = Get-ChildItem -Path "C:\Windows\System32\DriverStore\FileRepository\nv*\nvidia-smi.exe" -Recurse | Select-Object -First 1 -ExpandProperty FullName
            if ($nvidiaDriverStorePath) {
                $Commands = @("cmd /c '$nvidiaDriverStorePath' 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "nvidia-smi.txt'")
                msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
            } else {
    		    msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "'nvidia-smi.exe' not found"
            }
        }
    } else { # If NVIDIA GPU is not present
		msrdLogMessage $LogLevel.InfoLogFileOnly -LogPrefix $msrdLogPrefix -Message "No NVIDIA GPU detected"
    }

    #get PS and .Net version information
    msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Exporting PowerShell and .Net version information"
    "PowerShell Information:" 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
    $PSVersionTable | Format-Table Name, Value 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
    ".Net Framework Information:" 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")
    Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name version -EA 0 | Where-Object { $_.PSChildName -Match '^(?!S)\p{L}'} | Select-Object PSChildName, version 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SystemInfo.txt")

    #get Windows services information
    msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Exporting Windows services information"
    $svc = Get-CimInstance -NameSpace "root\cimv2" -Query "select  ProcessId, DisplayName, StartMode,State, Name, PathName, StartName from Win32_Service" -ErrorAction Continue
    if ($svc) {
        $svc | Sort-Object DisplayName | Format-Table -AutoSize -Property ProcessId, DisplayName, StartMode,State, Name, PathName, StartName | Out-String -Width 400 2>&1 | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "Services.txt")
    }

    #Collecting certificates information
    if (!($global:msrdSource)) {
        msrdCreateLogFolder $msrdCertLogFolder

        $Commands = @(
            "certutil -verifystore -v MY 2>&1 | Out-File -Append '" + $msrdCertLogFolder + $global:msrdLogFilePrefix + "Certificates-My.txt'"
            "certutil -verifystore -v 'AAD Token Issuer' 2>&1 | Out-File -Append '" + $msrdCertLogFolder + $global:msrdLogFilePrefix + "Certificates-AAD.txt'"
            "certutil -verifystore -v 'Remote Desktop' 2>&1 | Out-File -Append '" + $msrdCertLogFolder + $global:msrdLogFilePrefix + "Certificates-RemoteDesktop.txt'"
            "Get-Acl -Path '$env:ProgramData\Microsoft\Crypto\RSA\MachineKeys' 2>&1 | Select-Object -ExpandProperty Access 2>&1 | Out-File -Append '" + $msrdCertLogFolder + $global:msrdLogFilePrefix + "ACL-MachineKeys.txt'"
            "Get-Acl -Path '$env:ProgramData\Microsoft\Crypto\RSA\MachineKeys\f686aace6942fb7f7ceb231212eef4a4_*' 2>&1 | Select-Object -ExpandProperty Access 2>&1 | Out-File -Append '" + $msrdCertLogFolder + $global:msrdLogFilePrefix + "ACL-MachineKeys.txt'"
            "Get-Acl -Path 'HKLM:\SOFTWARE\Microsoft\SystemCertificates\Remote Desktop' 2>&1 | Select-Object -ExpandProperty Access 2>&1 | Out-File -Append '" + $msrdCertLogFolder + $global:msrdLogFilePrefix + "ACL-SystemCertificates-RemoteDesktop.txt'"
        )
        msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$False

        $tbCert = New-Object system.Data.DataTable
        $col = New-Object system.Data.DataColumn Store,([string]); $tbCert.Columns.Add($col)
        $col = New-Object system.Data.DataColumn Thumbprint,([string]); $tbCert.Columns.Add($col)
        $col = New-Object system.Data.DataColumn Subject,([string]); $tbCert.Columns.Add($col)
        $col = New-Object system.Data.DataColumn Issuer,([string]); $tbCert.Columns.Add($col)
        $col = New-Object system.Data.DataColumn NotAfter,([DateTime]); $tbCert.Columns.Add($col)
        $col = New-Object system.Data.DataColumn IssuerThumbprint,([string]); $tbCert.Columns.Add($col)
        $col = New-Object system.Data.DataColumn EnhancedKeyUsage,([string]); $tbCert.Columns.Add($col)
        $col = New-Object system.Data.DataColumn SerialNumber,([string]); $tbCert.Columns.Add($col)
        $col = New-Object system.Data.DataColumn SubjectKeyIdentifier,([string]); $tbCert.Columns.Add($col)
        $col = New-Object system.Data.DataColumn AuthorityKeyIdentifier,([string]); $tbCert.Columns.Add($col)
        msrdGetCertStore "My"
        $aCert = $tbCert.Select("Store = 'My' ")
        foreach ($cert in $aCert) {
            $aIssuer = $tbCert.Select("SubjectKeyIdentifier = '" + ($cert.AuthorityKeyIdentifier).tostring() + "'")
            if ($aIssuer.Count -gt 0) {
            $cert.IssuerThumbprint = ($aIssuer[0].Thumbprint).ToString()
            }
        }
        $tbcert | Export-Csv ($msrdCertLogFolder + $global:msrdLogFilePrefix + "Certificates-My.csv") -noType -Delimiter "`t" -Append

        #Collecting SPN information
        if ($script:isDomain) {
            $Commands = @(
                "setspn -L " + $env:computername + " 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SPN.txt'"
                "setspn -Q WSMAN/" + $env:computername + " 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SPN.txt'"
                "setspn -Q WSMAN/" + $global:msrdFQDN + " 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SPN.txt'"
                "setspn -F -Q WSMAN/" + $env:computername + " 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SPN.txt'"
                "setspn -F -Q WSMAN/" + $global:msrdFQDN + " 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SPN.txt'"
                "setspn -Q TERMSRV/" + $env:computername + " 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SPN.txt'"
                "setspn -Q TERMSRV/" + $global:msrdFQDN + " 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SPN.txt'"
                "setspn -F -Q TERMSRV/" + $env:computername + " 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SPN.txt'"
                "setspn -F -Q TERMSRV/" + $global:msrdFQDN + " 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "SPN.txt'"
            )
            msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
        }
    }
}

function msrdGetWUInfo {

    #get installed updates
    Import-Module -Name "$PSScriptRoot\MSRDC-WU" -DisableNameChecking -Force
    msrdRunUEX_MSRDWU
    Remove-Module MSRDC-WU
}

function msrdGetMDMinfo {

    #get MDM information
    " " | Out-File -Append $global:msrdOutputLogFile
    msrdCreateLogFolder $msrdMDMLogFolder

    $mdmpath = "$env:windir\System32\MdmDiagnosticsTool.exe"
    if (Test-Path -Path $mdmpath) {
        $Commands = @(
            "mdmdiagnosticstool.exe -area 'DeviceEnrollment;DeviceProvisioning;Autopilot' -zip '" + $msrdMDMLogFolder + $global:msrdLogFilePrefix + "MDMDiagReport.zip' 2>&1 | Out-File -Append '" + $msrdMDMLogFolder + $global:msrdLogFilePrefix + "mdmdiagnosticstool.txt'"
        )
        msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
    } else {
        msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "'$mdmpath' not found"
    }
}


function msrdGetCoreRoles {

    #get RDS roles information
    msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Installed Remote Desktop Roles"

    msrdCreateLogFolder $global:msrdSysInfoLogFolder

    $isRoleInst = Get-WindowsFeature | Where-Object { $_.InstallState -eq "Installed" }
    $isRoleInst | Out-File -Append ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "InstalledRoles.txt")

    $script:isRDSinst = (Get-WindowsFeature -Name RDS-*) | Where-Object { $_.InstallState -eq "Installed" }
    if ($script:isRDSinst) {
        msrdCreateLogFolder $global:msrdRDSLogFolder
    }

    #Collecting RDLS information
    if ($script:isRDSinst.Name -eq "RDS-Licensing") {
        " " | Out-File -Append $global:msrdOutputLogFile
        msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Remote Desktop Licensing"
        msrdGetRDLSDBInfo
    }

    #Collecting RDSH information
    if ($script:isRDSinst.Name -eq "RDS-RD-Server") {
        " " | Out-File -Append $global:msrdOutputLogFile
        msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Remote Desktop Session Host"

        $Commands = @(
            "cmd /c 'wmic /namespace:\\root\CIMV2\TerminalServices PATH Win32_TerminalServiceSetting WHERE (__CLASS !=`"`") CALL GetGracePeriodDays' 2>&1 | Out-File -Append '" + $global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "rdsh_GracePeriod.txt'"
            "Get-Acl -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM' 2>&1 | Select-Object -ExpandProperty Access 2>&1 | Out-File -Append '" + $global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "ACL-TerminalServer-RCM.txt'"
        )
        msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True

        msrdCreateLogFolder $global:msrdSchtaskFolder
        if ($ScheduledTasks = Get-ScheduledTask -TaskPath '\Microsoft\Windows\termsrv\licensing\' -ErrorAction Ignore) {
            $ScheduledTasks | ForEach-Object -Process {
                $Commands = @(
                    "Export-ScheduledTask -TaskName $($_.TaskName) -TaskPath '\Microsoft\Windows\termsrv\licensing' 2>&1 | Out-File -Append '" + $global:msrdSchtaskFolder + $global:msrdLogFilePrefix + "schtasks_" + $_.TaskName + ".xml'"
                    "Get-ScheduledTaskInfo -TaskName $($_.TaskName) -TaskPath '\Microsoft\Windows\termsrv\licensing' 2>&1 | Out-File -Append '" + $global:msrdSchtaskFolder + $global:msrdLogFilePrefix + "schtasks_" + $_.TaskName + "_Info.txt'"
                )
                msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
            }
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "TlsWarning (termsrv\licensing) Scheduled Task not found"
        }
    }

    if (($script:isRDSinst.Name -eq "RDS-Licensing") -or ($script:isRDSinst.Name -eq "RDS-RD-Server")) {
        msrdGetLocalGroupMembership -logPrefix $msrdLogPrefix -groupName "Terminal Server License Servers" -outputFile ($global:msrdRDSLogFolder + $global:msrdLogFilePrefix + "TSLSMembership.txt") -isDomain $true
    }

    if ($global:msrdRDS) {
        #Collecting RDCB/GetRDSFarmData information
        if ($script:isRDSinst.Name -eq "RDS-CONNECTION-BROKER") {
            " " | Out-File -Append $global:msrdOutputLogFile
            msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "RDS GetRDSFarmData"
            GetRDSFarmData

            " " | Out-File -Append $global:msrdOutputLogFile
            msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Remote Desktop Connection Broker"
            msrdGetRDCBInfo
        }

        #Collecting RDGW information
        if ($script:isRDSinst.Name -eq "RDS-GATEWAY") {
            " " | Out-File -Append $global:msrdOutputLogFile
            msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Remote Desktop Gateway"
            msrdGetRDGWInfo
        }

        #Collecting RDWA information
        if ($script:isRDSinst.Name -eq "RDS-WEB-ACCESS") {
            " " | Out-File -Append $global:msrdOutputLogFile
            msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Remote Desktop Web Access"
            msrdGetRDWAInfo
        }
    }
}

function msrdGetCoreRDSAVDInfo {

    #get RDS and AVD related data
    msrdCreateLogFolder $global:msrdSysInfoLogFolder

    if (!($global:msrdSource)) {
        msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Copy-Item 'C:\WindowsAzure\Logs\Plugins\*'"
        if (Test-path -path 'C:\WindowsAzure\Logs\Plugins') {
            Copy-Item 'C:\WindowsAzure\Logs\Plugins\*' $global:msrdSysInfoLogFolder -Recurse -ErrorAction Continue 2>>$global:msrdErrorLogFile
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "WindowsAzure Plugins logs not found"
        }

        msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Copy-Item 'C:\Packages\Plugins\*\*\Status'"
        $sourceFolder = "C:\Packages\Plugins"
        if (Test-Path -Path $sourceFolder) {
            $subfolders = Get-ChildItem -Path $sourceFolder -Directory -Recurse -Filter "Status" 2>&1 | Out-Null

            foreach ($subfolder in $subfolders) {
                $statusFolder = Join-Path -Path $subfolder.Parent.FullName -ChildPath "Status"
                if (Test-Path -Path $statusFolder) {
                    # Build the destination folder path dynamically based on the subfolder path
                    $destinationSubfolder = $subfolder.FullName.Replace($sourceFolder, $global:msrdSysInfoLogFolder)

                    # Create the destination folder if it does not exist
                    if (!(Test-Path -Path $destinationSubfolder)) {
                        New-Item -ItemType Directory -Path $destinationSubfolder -Force
                    }

                    # Copy only the "Status" subfolder and its contents
                    $statusFiles = Get-ChildItem -Path $statusFolder -Recurse 2>&1 | Out-Null
                    foreach ($statusFile in $statusFiles) {
                        $relativePath = $statusFile.FullName.Replace($statusFolder, "")
                        $destinationPath = Join-Path -Path $destinationSubfolder -ChildPath $relativePath
                        Try {
                            Copy-Item -Path $statusFile.FullName -Destination $destinationPath -Force -ErrorAction Continue 2>&1 | Out-Null
                        } Catch {
                            $failedCommand = $_.InvocationInfo.Line.TrimStart()
                            msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
                        }
                    }
                }
            }
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "C:\Packages\Plugins not found"
        }

        msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdSysInfoLogFolder -LogFilePath 'C:\WindowsAzure\Logs\MonitoringAgent.log' -LogFileID 'MonitoringAgent.log'
        msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdSysInfoLogFolder -LogFilePath 'C:\WindowsAzure\Logs\TransparentInstaller.log' -LogFileID 'TransparentInstaller.log'
        msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdSysInfoLogFolder -LogFilePath 'C:\WindowsAzure\Logs\WaAppAgent.log' -LogFileID 'WaAppAgent.log'

        msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Copy-Item '$env:windir\CCM\Logs\*'"
        if (Test-path -path '$env:windir\CCM\Logs') {
            Copy-Item '$env:windir\CCM\Logs\*' $msrdCCMLogFolder -Recurse -Exclude '*SCClient*', '*SCNotify*', '*SCToastNotification*' -ErrorAction Continue 2>>$global:msrdErrorLogFile
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "CCM logs not found"
        }


        msrdCreateLogFolder $global:msrdNetLogFolder
        msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdNetLogFolder -LogFilePath "$env:windir\debug\NetSetup.LOG" -LogFileID 'NetSetup.log'

        msrdCreateLogFolder $global:msrdTechFolder
        $Commands = @(
            "qwinsta /counter 2>&1 | Out-File -Append '" + $global:msrdTechFolder + $global:msrdLogFilePrefix + "Qwinsta.txt'"
            "Get-CimInstance -NameSpace 'root\cimv2\TerminalServices' -Query 'select * from Win32_TerminalServiceSetting' 2>&1 | Out-File -Append '" + $global:msrdTechFolder + $global:msrdLogFilePrefix + "WMI_TS_CLASSES.log'"
            "Get-CimInstance -NameSpace 'root\cimv2\TerminalServices' -Query 'select * from Win32_Terminal' 2>&1 | Out-File -Append '" + $global:msrdTechFolder + $global:msrdLogFilePrefix + "WMI_TS_CLASSES.log'"
            "Get-CimInstance -NameSpace 'root\cimv2\TerminalServices' -Query 'select * from Win32_TSClientSetting' 2>&1 | Out-File -Append '" + $global:msrdTechFolder + $global:msrdLogFilePrefix + "WMI_TS_CLASSES.log'"
            "Get-CimInstance -NameSpace 'root\cimv2\TerminalServices' -Query 'select * from Win32_TSPermissionsSetting' 2>&1 | Out-File -Append '" + $global:msrdTechFolder + $global:msrdLogFilePrefix + "WMI_TS_CLASSES.log'"
            "Get-CimInstance -NameSpace 'root\cimv2\TerminalServices' -Query 'select * from Win32_TSEnvironmentSetting' 2>&1 | Out-File -Append '" + $global:msrdTechFolder + $global:msrdLogFilePrefix + "WMI_TS_CLASSES.log'"
            "Get-CimInstance -NameSpace 'root\cimv2\TerminalServices' -Query 'select * from Win32_TSGeneralSetting' 2>&1 | Out-File -Append '" + $global:msrdTechFolder + $global:msrdLogFilePrefix + "WMI_TS_CLASSES.log'"
            "Get-CimInstance -NameSpace 'root\cimv2\TerminalServices' -Query 'select * from Win32_TSLogonSetting' 2>&1 | Out-File -Append '" + $global:msrdTechFolder + $global:msrdLogFilePrefix + "WMI_TS_CLASSES.log'"
            "Get-CimInstance -NameSpace 'root\cimv2\TerminalServices' -Query 'select * from Win32_TSNetworkAdapterSetting' 2>&1 | Out-File -Append '" + $global:msrdTechFolder + $global:msrdLogFilePrefix + "WMI_TS_CLASSES.log'"
            "Get-CimInstance -NameSpace 'root\cimv2\TerminalServices' -Query 'select * from Win32_TSRemoteControlSetting' 2>&1 | Out-File -Append '" + $global:msrdTechFolder + $global:msrdLogFilePrefix + "WMI_TS_CLASSES.log'"
            "Get-CimInstance -NameSpace 'root\cimv2\TerminalServices' -Query 'select * from Win32_TSSessionSetting' 2>&1 | Out-File -Append '" + $global:msrdTechFolder + $global:msrdLogFilePrefix + "WMI_TS_CLASSES.log'"
            "Get-CimInstance -NameSpace 'root\cimv2\TerminalServices' -Query 'select * from Win32_TSSessionDirectory' 2>&1 | Out-File -Append '" + $global:msrdTechFolder + $global:msrdLogFilePrefix + "WMI_TS_CLASSES.log'"
        )
        msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True

    }

    if (!($global:msrdRDS)) {

        if ($global:msrdSource) {
            msrdGetRdClientAutoTrace
            msrdGetRdClientSub
            msrdGetW365Logs
        }

        msrdCreateLogFolder $global:msrdAVDLogFolder
        if ($global:avdnettestpath -ne "") {
            $global:avdnettestpathlog = "$global:msrdLogDir${env:computername}_AVD\${env:computername}_avdnettest.log"

            $Commands = @(
                "cmd /c $global:avdnettestpath --log-level debug --log-file '$global:avdnettestpathlog' 2>&1 | Out-Null"
            )
            msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
        }
    }

    if (!($global:msrdSource)) {
        msrdGetLocalGroupMembership -logPrefix $msrdLogPrefix -groupName "Administrators" -outputFile ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "LocalGroupsMembership.txt")
        msrdGetLocalGroupMembership -logPrefix $msrdLogPrefix -groupName "Remote Desktop Users" -outputFile ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "LocalGroupsMembership.txt")
    }

    if ($global:msrdRDS -and !($global:msrdSource)) {
        msrdGetLocalGroupMembership -logPrefix $msrdLogPrefix -groupName "RDS Remote Access Servers" -outputFile ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "LocalGroupsMembership.txt")
        msrdGetLocalGroupMembership -logPrefix $msrdLogPrefix -groupName "RDS Management Servers" -outputFile ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "LocalGroupsMembership.txt")
        msrdGetLocalGroupMembership -logPrefix $msrdLogPrefix -groupName "RDS Endpoint Servers" -outputFile ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "LocalGroupsMembership.txt")
    }

    if (($global:msrdAVD -or $global:msrdW365) -and !($global:msrdSource)) {
        msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdTechFolder -LogFilePath "$msrdUserProfilesDir\AgentInstall.txt" -LogFileID 'AgentInstall_initial.txt'
        msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdTechFolder -LogFilePath "$msrdUserProfilesDir\AgentBootLoaderInstall.txt" -LogFileID 'AgentBootLoaderInstall_initial.txt'
        msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdTechFolder -LogFilePath "$env:ProgramFiles\Microsoft RDInfra\AgentInstall.txt" -LogFileID 'AgentInstall_updates.txt'
        msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdTechFolder -LogFilePath "$env:ProgramFiles\Microsoft RDInfra\GenevaInstall.txt" -LogFileID 'GenevaInstall.txt'
        msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdTechFolder -LogFilePath "$env:ProgramFiles\Microsoft RDInfra\SXSStackInstall.txt" -LogFileID 'SXSStackInstall.txt'
        msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdTechFolder -LogFilePath "$env:ProgramFiles\Microsoft RDInfra\MsRdcWebRTCSvc.txt" -LogFileID 'MsRdcWebRTCSvc.txt'
        msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdTechFolder -LogFilePath "$env:ProgramFiles\Microsoft RDInfra\MsRdcWebRTCSvcMsiInstall.txt" -LogFileID 'MsRdcWebRTCSvcMsiInstall.txt'
        msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdTechFolder -LogFilePath "$env:ProgramFiles\Microsoft RDInfra\MsRdcWebRTCSvcMsiUninstall.txt" -LogFileID 'MsRdcWebRTCSvcMsiUninstall.txt'
        msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdTechFolder -LogFilePath "$env:ProgramFiles\MsRDCMMRHost\MsRDCMMRHostInstall.log" -LogFileID 'MsRDCMMRHostInstall.log'
        msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdTechFolder -LogFilePath "$env:windir\Temp\MsRDCMMRHostInstall.log" -LogFileID 'MsRDCMMRHostInstall-fpe.log'
        msrdGetLogFiles -LogPrefix $msrdLogPrefix -Type Files -OutputFolder $global:msrdTechFolder -LogFilePath "$env:windir\Temp\ScriptLog.log" -LogFileID 'ScriptLog.log'

        #collect MSI*.log files for AVD components
        Function msrdGetMSIlog {
            param( $sourcePath, $destinationPath, $searchString )

            if ($sourcePath -eq $msrdUserProfilesDir) {
                foreach ($userProfile in Get-ChildItem -Path $sourcePath -Directory -ErrorAction SilentlyContinue) {
                    $tempPath = Join-Path $userProfile.FullName "AppData\Local\Temp"

                    # Find MSI*.log files containing the specified string
                    $filesToCopy = Get-ChildItem -Path $tempPath -Filter "MSI*.log" -Recurse -ErrorAction SilentlyContinue | Where-Object { Get-Content $_.FullName | Select-String -Pattern $searchString }

                    # Copy the files to the destination with modified names
                    foreach ($file in $filesToCopy) {
                        $fileName = $file.Name
                        $modifiedFileName = $global:msrdLogFilePrefix + $searchString + "_" + $fileName
                        $destinationFile = Join-Path $destinationPath $modifiedFileName
                        Copy-Item $file.FullName -Destination $destinationFile -Force
                    }
                }
            } else {
                $filesToCopy = Get-ChildItem -Path $sourcePath -Filter "MSI*.log" -ErrorAction SilentlyContinue | Where-Object { Get-Content $_.FullName | Select-String -Pattern $searchString }

                foreach ($file in $filesToCopy) {
                    $fileName = $file.Name
                    $modifiedFileName = $global:msrdLogFilePrefix + $searchString + "_" + $fileName
                    $destinationFile = Join-Path $destinationPath $modifiedFileName
                    Copy-Item $file.FullName -Destination $destinationFile -Force
                }
            }
        }
        msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "MSI installation logs for AVD components"
        msrdGetMSIlog -sourcePath "$env:windir\Temp" -destinationPath $global:msrdTechFolder -searchString "Geneva"
        msrdGetMSIlog -sourcePath "$env:windir\Temp" -destinationPath $global:msrdTechFolder -searchString "MsMMRHostInstaller"
        msrdGetMSIlog -sourcePath $msrdUserProfilesDir -destinationPath $global:msrdTechFolder -searchString "Geneva"
        msrdGetMSIlog -sourcePath $msrdUserProfilesDir -destinationPath $global:msrdTechFolder -searchString "MsMMRHostInstaller"

        msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "BrokerURI/api/health and BrokerURIGlobal/api/health status"
        $brokerURIregpath = "HKLM:\SOFTWARE\Microsoft\RDInfraAgent\"

        $brokerout = $global:msrdAVDLogFolder + $global:msrdLogFilePrefix + "AVDServicesURIHealth.txt"
        $brokerURIregkey = "BrokerURI"
            if (msrdTestRegistryValue -path $brokerURIregpath -value $brokerURIregkey) {
                try {
                    $brokerURI = (Get-ItemPropertyValue -Path $brokerURIregpath -name $brokerURIregkey) + "api/health"
                    "$brokerURI" | Out-File -Append $brokerout
                    Invoke-WebRequest $brokerURI -UseBasicParsing | Out-File -Append $brokerout
                    "`n" | Out-File -Append $brokerout
                } catch {
                    msrdLogException ("$(msrdGetLocalizedText "errormsg") Invoke-WebRequest $brokerURI") -ErrObj $_
                }
            } else {
                msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "Reg key '$brokerURIregpath$brokerURIregkey' not found"
            }

        $brokerURIGlobalregkey = "BrokerURIGlobal"
            if (msrdTestRegistryValue -path $brokerURIregpath -value $brokerURIGlobalregkey) {
                try {
                    $brokerURIGlobal = (Get-ItemPropertyValue -Path $brokerURIregpath -name $brokerURIGlobalregkey) + "api/health"
                    "$brokerURIGlobal" | Out-File -Append $brokerout
                    Invoke-WebRequest $brokerURIGlobal -UseBasicParsing | Out-File -Append $brokerout
                    "`n" | Out-File -Append $brokerout
                } catch {
                    msrdLogException ("$(msrdGetLocalizedText "errormsg") Invoke-WebRequest $brokerURIGlobal") -ErrObj $_
                }
            } else {
                msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "Reg key '$brokerURIregpath$brokerURIGlobalregkey' not found"
            }

        $diagURIregkey = "DiagnosticsUri"
            if (msrdTestRegistryValue -path $brokerURIregpath -value $diagURIregkey) {
                try {
                    $diagURI = (Get-ItemPropertyValue -Path $brokerURIregpath -name $diagURIregkey) + "api/health"
                    "$diagURI" | Out-File -Append $brokerout
                    Invoke-WebRequest $diagURI -UseBasicParsing | Out-File -Append $brokerout
                    "`n" | Out-File -Append $brokerout
                } catch {
                    msrdLogException ("$(msrdGetLocalizedText "errormsg") Invoke-WebRequest $diagURI") -ErrObj $_
                }
            } else {
                msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "Reg key '$brokerURIregpath$diagURIregkey' not found"
            }

        $brokerResURIGlobalregkey = "BrokerResourceIdURIGlobal"
            if (msrdTestRegistryValue -path $brokerURIregpath -value $brokerResURIGlobalregkey) {
                try {
                    $brokerResURIGlobal = (Get-ItemPropertyValue -Path $brokerURIregpath -name $brokerResURIGlobalregkey) + "api/health"
                    "$brokerResURIGlobal" | Out-File -Append $brokerout
                    Invoke-WebRequest $brokerResURIGlobal -UseBasicParsing | Out-File -Append $brokerout
                } catch {
                    msrdLogException ("$(msrdGetLocalizedText "errormsg") Invoke-WebRequest $brokerResURIGlobal") -ErrObj $_
                }
            } else {
                msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "Reg key '$brokerURIregpath$brokerResURIGlobalregkey' not found"
            }
        #endregion URI

        #region Collecting Geneva Monitoring information
        " " | Out-File -Append $global:msrdOutputLogFile

        msrdCreateLogFolder $global:msrdGenevaLogFolder

        Try {
            msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Azure Instance Metadata Service (IMDS) endpoint accessibility"
            $request = [System.Net.WebRequest]::Create("http://169.254.169.254/metadata/instance/network?api-version=2021-12-13")
            $request.Proxy = [System.Net.WebProxy]::new()
            $request.Headers.Add("Metadata","True")
            $request.Timeout = 10000
            $request.GetResponse() | Out-File -Append ($global:msrdGenevaLogFolder + $global:msrdLogFilePrefix + "IMDSRequestInfo.txt")

        } Catch {
            msrdLogException ("$(msrdGetLocalizedText "errormsg") $request") -ErrObj $_
        }

        msrdCreateLogFolder $global:msrdSchtaskFolder

        if (Get-ScheduledTask GenevaTask* -ErrorAction Ignore) {

            msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Exporting Geneva Scheduled Tasks information"
            (Get-ScheduledTask GenevaTask*).TaskName | ForEach-Object -Process {
                Export-ScheduledTask -TaskName $_ 2>&1 | Out-File -Append ($global:msrdSchtaskFolder + $global:msrdLogFilePrefix + "schtasks_" + $_ + ".xml")
                Get-ScheduledTaskInfo -TaskName $_ 2>&1 | Out-File -Append ($global:msrdSchtaskFolder + $global:msrdLogFilePrefix + "schtasks_" + $_ + "_Info.txt")
            }
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "Geneva Scheduled Tasks not found"
        }

        $Commands = @(
            "tree '$env:windir\System32\config\systemprofile\AppData\Roaming\Microsoft\Monitoring' /f 2>&1 | Out-File -Append '" + $global:msrdGenevaLogFolder + $global:msrdLogFilePrefix + "tree_Monitoring.txt'"
        )
        msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True

        msrdGetAVDMonTables
        msrdGetAVDMonConfig

        $tccpath = "$env:ProgramFiles\Microsoft Monitoring Agent"
        if (Test-Path -Path $tccpath) {
            $Commands = @(
                "cmd /c `"$env:ProgramFiles\Microsoft Monitoring Agent\Agent\TestCloudConnection.exe`" 2>&1 | Out-File -Append '" + $global:msrdGenevaLogFolder + $global:msrdLogFilePrefix + "AMA-TestCloudConnection.txt'"
            )
            msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True

            Get-ChildItem Env: | Where-Object {$_.Name -like "*monitoring*" -or $_.Value -like "*monitoring*"} | Format-Table -AutoSize -Wrap | Out-File -Append ($global:msrdGenevaLogFolder + $global:msrdLogFilePrefix + "MonitoringVariables.txt")
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "Microsoft Monitoring Agent components not found"
        }
        #endregion geneva
    }
}

Function msrdGetRDListenerPermissions {

    msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Detailed Listener permissions for the assigned groups and the current user"

    # check if a user is a member of a local group
    function IsUserInLocalGroup {
        param([string]$userName, [string]$groupName)
        $output = & net localgroup $groupName 2>&1
        return $output -match "^\s*(?:$userName|.+\\$userName)\s*$"
    }

    function IsUserInDomainGroup {
        param([string]$userName, [string]$groupName)

        Add-Type -AssemblyName System.DirectoryServices.AccountManagement

        try {
            $domainContext = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain)
            $userPrincipal = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($domainContext, $userName)
            $groupPrincipal = [System.DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($domainContext, $groupName)

            # Check if the group was found and then if the user is a member of the group
            if ($null -ne $groupPrincipal) {
                return $userPrincipal.IsMemberOf($groupPrincipal)
            }

            # Group not found, return false
            return $false
        } catch {
            msrdLogMessage $LogLevel.Error -LogPrefix $msrdLogPrefix -Message "Error checking domain group membership: $_"
            return $false
        }
    }

    # extract the group name without the "BUILTIN\" prefix
    function GetCleanGroupName {
        param([string]$accountName)
        $prefix = "BUILTIN\"
        if ($accountName -like "$prefix*") {
            return $accountName.Substring($prefix.Length)
        }
        return $accountName
    }

    $computer = "LocalHost"
    $namespace = "root\CIMV2\TerminalServices"
    $currentUserName = $global:msrdUserprof

    # check group permissions
    Function CheckGroupPermissions {
        param([int]$permissionsAllowed)
        if ($permissionsAllowed -band 1) { "    WINSTATION_QUERY" }
        if ($permissionsAllowed -band 2) { "    WINSTATION_SET" }
        if ($permissionsAllowed -band 64) { "    WINSTATION_RESET" }
        if ($permissionsAllowed -band 983048) { "    WINSTATION_VIRTUAL | STANDARD_RIGHTS_REQUIRED" }
        if ($permissionsAllowed -band 16) { "    WINSTATION_SHADOW" }
        if ($permissionsAllowed -band 32) { "    WINSTATION_LOGON" }
        if ($permissionsAllowed -band 4) { "    WINSTATION_LOGOFF" }
        if ($permissionsAllowed -band 128) { "    WINSTATION_MSG" }
        if ($permissionsAllowed -band 256) { "    WINSTATION_CONNECT" }
        if ($permissionsAllowed -band 512) { "    WINSTATION_DISCONNECT" }
    }

    $listeners = Get-CimInstance -ClassName Win32_TSAccount -ComputerName $computer -Namespace $namespace -ErrorAction SilentlyContinue | Where-Object { ($_.TerminalName -like '*RDP-Tcp*' -or $_.TerminalName -like '*rdp-sxs*' -or $_.TerminalName -like '*ICA-Tcp*') } | Select-Object TerminalName, AccountName, SID, PermissionsAllowed, PermissionsDenied, Status

    if ($listeners) {
        $headerPerms = @"
======================================
$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss.fff')) : Get-WmiObject -class Win32_TSAccount -computername $computer -namespace $namespace -ErrorAction SilentlyContinue | Where-Object { (`$_.TerminalName -like '*RDP-Tcp*' -or `$_.TerminalName -like '*rdp-sxs*' -or `$_.TerminalName -like '*ICA-Tcp*') } | Select-Object TerminalName, AccountName, SID, PermissionsAllowed, PermissionsDenied, Status | Format-Table -AutoSize -Wrap
======================================`n
Bitmask values for interpreting the permissions:
    WINSTATION_QUERY = 1
    WINSTATION_SET = 2
    WINSTATION_RESET = 64
    WINSTATION_VIRTUAL | STANDARD_RIGHTS_REQUIRED = 983048
    WINSTATION_SHADOW = 16
    WINSTATION_LOGON = 32
    WINSTATION_LOGOFF = 4
    WINSTATION_MSG = 128
    WINSTATION_CONNECT = 256
    WINSTATION_DISCONNECT = 512
======================================
"@

        msrdCreateLogFolder $global:msrdTechFolder

        $headerPerms | Out-File -Append ($global:msrdTechFolder + $global:msrdLogFilePrefix + "ListenerPermissions.txt")
        $listeners | Format-Table -AutoSize -Wrap | Out-File -Append ($global:msrdTechFolder + $global:msrdLogFilePrefix + "ListenerPermissions.txt")

        # Iterate through each listener and check group membership and permissions for the current user
        $userFound = $false
        $headerCUser = @"
======================================
$((Get-Date).ToString('yyyy/MM/dd HH:mm:ss.fff')) : Listener permissions for the current user: $currentUserName
======================================`n
"@
        $headerCUser | Out-File -Append ($global:msrdTechFolder + $global:msrdLogFilePrefix + "ListenerPermissions-CurrentUser.txt")

        foreach ($listener in $listeners) {
            $groupName = $listener.AccountName
            $cleanGroupName = GetCleanGroupName $groupName
            $permissionsAllowed = $listener.PermissionsAllowed
            $listenerName = $listener.TerminalName

            if ($groupName -like "*$currentUserName*") {
                # Check if the user is directly assigned to the listener
                "This user is directly assigned to the $listenerName listener." | Out-File -Append ($global:msrdTechFolder + $global:msrdLogFilePrefix + "ListenerPermissions-CurrentUser.txt")
                "This user has the following permissions on the $listenerName listener:`n" | Out-File -Append ($global:msrdTechFolder + $global:msrdLogFilePrefix + "ListenerPermissions-CurrentUser.txt")
                CheckGroupPermissions $permissionsAllowed | Out-File -Append ($global:msrdTechFolder + $global:msrdLogFilePrefix + "ListenerPermissions-CurrentUser.txt")
                "`n" | Out-File -Append ($global:msrdTechFolder + $global:msrdLogFilePrefix + "ListenerPermissions-CurrentUser.txt")
                $userFound = $true
            } else {
                # Check if the group is local or domain-based and then check membership accordingly
                if ($groupName -like "BUILTIN\*") {
                    $isMember = IsUserInLocalGroup $currentUserName $cleanGroupName
                } else {
                    $isMember = IsUserInDomainGroup $currentUserName $cleanGroupName
                }

                if ($isMember) {
                    "This user is a member of the '$groupName' group, assigned to the $listenerName listener." | Out-File -Append ($global:msrdTechFolder + $global:msrdLogFilePrefix + "ListenerPermissions-CurrentUser.txt")
                    "This group has the following permissions on the $listenerName listener:`n" | Out-File -Append ($global:msrdTechFolder + $global:msrdLogFilePrefix + "ListenerPermissions-CurrentUser.txt")
                    CheckGroupPermissions $permissionsAllowed | Out-File -Append ($global:msrdTechFolder + $global:msrdLogFilePrefix + "ListenerPermissions-CurrentUser.txt")
                    "`n" | Out-File -Append ($global:msrdTechFolder + $global:msrdLogFilePrefix + "ListenerPermissions-CurrentUser.txt")
                    $userFound = $true
                }
            }
        }

        if (-not $userFound) {
            "This user does not seem to be assigned to any of the available remote desktop listeners, neither directly with their user account nor as direct members of any directly assigned group.`nThe user may still be part of nested groups, but the current version of the script cannot retrieve those membership information." | Out-File -Append ($global:msrdTechFolder + $global:msrdLogFilePrefix + "ListenerPermissions-CurrentUser.txt")
        }

    } else {
        msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "[WARNING] Failed to get detailed Listener permissions."
    }
}


# Collecting Core troubleshooting data
Function msrdCollectUEX_AVDCoreLog {
    param( [bool[]]$varsCore, [bool]$dumpProc, [int]$pidProc )

    #main Core
    " " | Out-File -Append $global:msrdOutputLogFile
    msrdLogMessage $LogLevel.Info "$(msrdGetLocalizedText "rdcmsg")`n" -Color "Cyan"
    " " | Out-File -Append $global:msrdOutputLogFile

    msrdLogMessage $LogLevel.Info ("$(msrdGetLocalizedText "coremsg")")

    if($dumpProc -and $pidProc) {
        msrdLogMessageAssistMode "Collecting process dumps"
        msrdGetDump -pidProc $pidProc
    } #Collecting process dumps

    if ($varsCore[0]) {
        msrdLogMessageAssistMode "Collecting RDS/AVD information"
        msrdGetCoreRDSAVDInfo
    } #Collect RDS/AVD information

    if ($varsCore[1]) {
        msrdLogMessageAssistMode "Collecting RDS/AVD logs"
        msrdGetCoreEventLogs -varsCore $varsCore[2]
    } #Collect event logs

    if ($varsCore[3]) {
        msrdLogMessageAssistMode "Collecting RDS/AVD registry keys"
        msrdGetCoreRegKeys
    } #Collect reg keys

    if ($varsCore[4]) {
        msrdLogMessageAssistMode "Collecting Networking/AD information"
        msrdGetCoreRDPNetADInfo -varsCore $varsCore[5]
    } #Collect RDP and Net info

    if ($varsCore[6]) {
        msrdLogMessageAssistMode "Collecting RDS/AVD scheduled tasks information"
        msrdGetCoreSchedTasks
    } #Remote Desktop scheduled tasks

    if ($varsCore[7]) {
        msrdLogMessageAssistMode "Collecting system information"
        msrdGetCoreSystemInfo
    } #Collect system information

    if ($varsCore[8]) {
        msrdLogMessageAssistMode "Collecting Windows Update history"
        msrdGetWUInfo
    } #Collect system information

    if ($varsCore[9]) {
        msrdLogMessageAssistMode "Collecting MDM information"
        msrdGetMDMinfo
    } #Collect system information

    if ($varsCore[10] -and !($global:msrdSource) -and ($global:msrdOSVer -like "*Windows Server*")) {
        msrdLogMessageAssistMode "Collecting RDS roles information"
        msrdGetCoreRoles
    } #RDS roles and data

    if ($varsCore[11] -and !($global:msrdSource)) {
        msrdLogMessageAssistMode "Collecting detailed RDP Listener permissions for the assigned groups and the current user"
        msrdGetRDListenerPermissions
    } #listener permissions
}

Export-ModuleMember -Function msrdCollectUEX_AVDCoreLog
# SIG # Begin signature block
# MIInvwYJKoZIhvcNAQcCoIInsDCCJ6wCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB9nWI4WLoJe8fH
# ngiXeVIaS9nb+mDW6ZVZJeI3YyufcqCCDXYwggX0MIID3KADAgECAhMzAAADrzBA
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
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIGfSAK2sB4acFviQVcs9HkeL
# VKcvJLqvh2qWuerwIZuzMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEATm4xM9BJH+yFmZhRslaqg7SwNVzx6zCJRXcqUuziSjOsvLS2glJjlRRD
# YBkWeHbL4zYrZDwLshODPNZ6z1/RUIxVm23nDpJwzEwTF+/e0pPPyRiII1AoTM46
# 2tWjs6m6fO1YlYANz5dBq0Cypu8axd1TaG3cy2H6aM9/ZmNLdn3kZDe947JU5FBy
# WiraKEsHmOsfLYmQ9UGBrXmVeC+IR9UuADG+4VZpvzruxlZytBpOige6IXbWOqVt
# M1/2VZFkZrkgAReWPUrd/2b6clkTv6f43L38ML0O3OaZA+gN/0yunglDDGIfRaaV
# rXzMZeB8h38Q4XqQJi7N6N6RIIVPK6GCFykwghclBgorBgEEAYI3AwMBMYIXFTCC
# FxEGCSqGSIb3DQEHAqCCFwIwghb+AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsq
# hkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCAwj9dTT8mRhAA8Qz3oqRyBlEYJKDwq3pxh3vagpnQquwIGZbqk2rE8
# GBMyMDI0MDIyMDEyMTY1OS45MTdaMASAAgH0oIHYpIHVMIHSMQswCQYDVQQGEwJV
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
# IgQgJf++pmr6STcSXzXPh448GVciHlOlgjNFMq7sS3i/HK0wgfoGCyqGSIb3DQEJ
# EAIvMYHqMIHnMIHkMIG9BCAVqdP//qjxGFhe2YboEXeb8I/pAof01CwhbxUH9U69
# 7TCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB5Y9q
# wPM9tAujAAEAAAHlMCIEIBsAbimdI+ye2UIiP0NL+ZRHoPI3NgLOHJjAAqJlKaGw
# MA0GCSqGSIb3DQEBCwUABIICAFit5CW2MHgF3bI45fyZLDI1f0d1OUBILX/6JUsp
# 06An64zxqLS9eqlsnJ4N/QkyTQ8KD1wcSoWokartgmv5jsEj6KdrJhiTZcpYRD2M
# EQY4I9NeQFDcTQlK7lFwLm4886DQc99O5YA97GfiiBAiXv9qzhQ1PawfnHCedM9Y
# FncjiTzoTyvjQQ38Zw+Bt+yZyzlg8xb5CxM7X48Wj5d4F8Eg926+z9hrjRjZDCna
# 7vfeZhubVxKgwqckPhXMps2nA7mbDXUOBGc1hTtDtMfnpxIKcUf7oD9wfXF1vKz6
# 4aZVhX0kWFpheoi/4/jnlwQZWc2SJuKyhT3KiIgSuLD8vE++Vj6IimL8cKfDNAV2
# wazIaIBK2GMke7iq0xF+DxUgESqBfLukQvz312gR/1Wxp3JLcW963wApxFJ9tN9P
# Otuz3q892QPcUduurtX609bvFBdcW+F48iRSkTlnDAtayGK3tKATaYWAawIZUV+c
# efY0D5t19oJjdC5xRngr/EQVIhTJc6lLFA42BPRHVg5u6DupQllSr2g4h1KDr46i
# mLobUWd1kPmyb6U7lmhJLBMZtJngubs4qpWg8JT/XWSf7SQgNJ+4OcObrgllVaqN
# cPuq1F87xQn426EE/1FY05nKaBFRa+Xfmodb9vDCB0NrocRbbtn06VLvkbkmxVi5
# aDy/
# SIG # End signature block
