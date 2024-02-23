3<#
.SYNOPSIS
   Scenario module for collecting Microsoft Remote Desktop Diagnostics data

.DESCRIPTION
   Runs Diagnostics checks and generates a report in .html format

.NOTES
   Author     : Robert Klemencz
   Requires   : At least PowerShell 5.1 (This module is not for stand-alone use. It is used automatically from within the main MSRD-Collect.ps1 script)
   Version    : See MSRD-Collect.ps1 version
   Feedback   : https://aka.ms/MSRD-Collect-Feedback
#>

#region versions
$latestRDCver = "1.2.5112.0" #Desktop client (MSRDC)
$latestw365ver = "1.3.230.0" #Windows App unified client
$latestStoreCver = "10.2.3012.0" #Old AVD store client (URDC)
$latestAvdStoreApp = "1.2.4157.0" #New AVD store client (Preview)
$latestAvdHostApp = "1.2.5248.0" #AVD host app

$latestAvdAgentVer = "1.0.8297.800" #RDAgent

$latestWebRTCVer = "1.45.2310.13001" #Remote Desktop WebRTC
$latestMMRver = "1.0.2311.2004" #Multimedia Redirection
$minVCRverMMR = "14.32.31332.0" #Visual C++ Redistributable

$latestFSLogixVer = 29878463912 #FSLogix

$latestQAver = "2.0.22.0" #Quick Assist
#endregion versions

$msrdDiagFile = $global:msrdBasicLogFolder + "MSRD-Diag.html"
$msrdAgentpath = "$env:ProgramFiles\Microsoft RDInfra\"

$msrdUserProfilesDir = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" -Name ProfilesDirectory).ProfilesDirectory
$msrdUserProfilePath = "$msrdUserProfilesDir\$global:msrdUserprof"

$script:RDClient = (Get-ItemProperty hklm:\software\microsoft\windows\currentversion\uninstall\* | Where-Object {(($_.DisplayName -eq "Remote Desktop") -or ($_.DisplayName -eq "Remotedesktop")) -and ($_.Publisher -like "*Microsoft*")})

#region URL references
$msrdcRef = "<a href='https://learn.microsoft.com/en-us/azure/virtual-desktop/whats-new-client-windows' target='_blank'>What's new in the Remote Desktop client for Windows</a>"
$vmsizeRef = "<a href='https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/virtual-machine-recs#recommended-vm-sizes-for-standard-or-larger-environments' target='_blank'>Session host virtual machine sizing guidelines</a>"
$uwpcRef = "<a href='https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/clients/windows-whatsnew' target='_blank'>What's new in the Remote Desktop app for Windows</a>"
$avexRef = "<a href='https://learn.microsoft.com/en-us/fslogix/overview-prerequisites#configure-antivirus-file-and-folder-exclusions' target='_blank'>Configure Antivirus file and folder exclusions</a>"
$avexTeamsRef = "<a href='https://learn.microsoft.com/en-us/microsoftteams/troubleshoot/teams-administration/include-exclude-teams-from-antivirus-dlp' target='_blank'>Exclude antivirus and DLP applications from blocking Teams</a>"
$w10proRef = "<a href='https://learn.microsoft.com/en-us/lifecycle/products/windows-10-home-and-pro' target='_blank'>Windows 10 Home and Pro</a>"
$w10entRef = "<a href='https://learn.microsoft.com/en-us/lifecycle/products/windows-10-enterprise-and-education' target='_blank'>Windows 10 Enterprise and Education</a>"
$w81Ref = "<a href='https://learn.microsoft.com/en-us/lifecycle/products/windows-81' target='_blank'>Windows 8.1</a>"
$w2008r2Ref = "<a href='https://learn.microsoft.com/en-us/lifecycle/products/windows-server-2008-r2' target='_blank'>Windows Server 2008 R2</a>"
$w2012r2Ref = "<a href='https://learn.microsoft.com/en-us/lifecycle/products/windows-server-2012-r2' target='_blank'>Windows Server 2012 R2</a>"
$avdOSRef = "<a href='https://learn.microsoft.com/en-us/azure/virtual-desktop/prerequisites?tabs=portal#operating-systems-and-licenses' target='_blank'>Operating systems and licenses</a>"
$avdLicRef = "<a href='https://learn.microsoft.com/en-us/azure/virtual-desktop/apply-windows-license' target='_blank'>Apply Windows license to session host virtual machines</a>"
$fslogixRef = "<a href='https://learn.microsoft.com/en-us/fslogix/overview-release-notes' target='_blank'>FSLogix Release Notes</a>"
$cloudcacheRef = "<a href='https://learn.microsoft.com/en-us/fslogix/tutorial-cloud-cache-containers#configure-cloud-cache-for-smb' target='_blank'>Configure profile containers with Cloud Cache</a>"
$gpuRef = "<a href='https://learn.microsoft.com/en-us/azure/virtual-desktop/enable-gpu-acceleration' target='_blank'>Configure GPU acceleration for Azure Virtual Desktop</a>"
$mmrRef = "<a href='https://learn.microsoft.com/en-us/azure/virtual-desktop/whats-new-multimedia-redirection' target='_blank'>What's new in multimedia redirection?</a>"
$mmrReqRef = "<a href='https://learn.microsoft.com/en-us/azure/virtual-desktop/multimedia-redirection?tabs=edge#prerequisites' target='_blank'>Use multimedia redirection on Azure Virtual Desktop</a>"
$defenderRef = "<a href='https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/security-malware-windows-defender-disableantispyware' target='_blank'>DisableAntiSpyware</a>"
$webrtcRef = "<a href='https://learn.microsoft.com/en-us/azure/virtual-desktop/whats-new-webrtc' target='_blank'>What's new in the Remote Desktop WebRTC Redirector Service</a>"
$avdTsgRef = "<a href='https://learn.microsoft.com/en-us/azure/virtual-desktop/troubleshoot-agent' target='_blank'>Agent TSG</a>"
$spathTsgRef = "<a href='https://learn.microsoft.com/en-us/azure/virtual-desktop/troubleshoot-rdp-shortpath' target='_blank'>RDP Shortpath TSG</a>"
$fslogixTsgRef = "<a href='https://learn.microsoft.com/en-us/fslogix/troubleshooting-events-logs-diagnostics' target='_blank'>FSLogix TSG</a>"
$avdagentRef = "<a href='https://learn.microsoft.com/en-us/azure/virtual-desktop/whats-new-agent' target='_blank'>What's new in the Azure Virtual Desktop Agent?</a>"
$avdclassicRef = "<a href='https://learn.microsoft.com/en-us/azure/virtual-desktop/virtual-desktop-fall-2019/classic-retirement' target='_blank'>Azure Virtual Desktop (classic) retirement</a>"
$newTeamsFSLogixRef = "<a href='https://learn.microsoft.com/en-us/microsoftteams/new-teams-vdi-requirements-deploy#profile-and-cache-location-for-new-teams-client' target='_blank'>Upgrade to new Teams for Virtualized Desktop Infrastructure (VDI)</a>"
$newTeamsRef = "<a href='https://learn.microsoft.com/en-us/microsoftteams/new-teams-vdi-requirements-deploy#requirements' target='_blank'>Upgrade to new Teams for Virtualized Desktop Infrastructure (VDI)</a>"
$classicTeamsEoARef = "<a href='https://learn.microsoft.com/en-us/microsoftteams/new-teams-vdi-requirements-deploy#important-announcement-for-classic-teams-for-vdi' target='_blank'>Upgrade to new Teams for Virtualized Desktop Infrastructure (VDI)</a>"
#endregion URL references

#region hyperlinks
$computerName = $env:computername

$msrdErrorfileurl = "${computerName}_MSRD-Collect-Error.txt"

$agentInitinstfile = "${computerName}_AVD\${computerName}_AgentInstall_initial.txt"
$agentUpdateinstfile = "${computerName}_AVD\${computerName}_AgentInstall_updates.txt"
$agentBLinstfile = "${computerName}_AVD\${computerName}_AgentBootLoaderInstall_initial.txt"
$sxsinstfile = "${computerName}_AVD\${computerName}_SXSStackInstall.txt"
$genevainstfile = "${computerName}_AVD\${computerName}_GenevaInstall.txt"
$avdnettestfile = "${computerName}_AVD\${computerName}_avdnettest.log"
$montablesfolder = "${computerName}_AVD\Monitoring\MonTables"

$aplevtxfile = "${computerName}_EventLogs\${computerName}_Application.evtx"
$sysevtxfile = "${computerName}_EventLogs\${computerName}_System.evtx"
$rdsevtxfile = "${computerName}_EventLogs\${computerName}_RemoteDesktopServices.evtx"
$secevtxfile = "${computerName}_EventLogs\${computerName}_Security.evtx"

$fslogixfolder = "${computerName}_FSLogix"

$fwrfile = "${computerName}_Networking\${computerName}_FirewallRules.txt"
$ipcfgfile = "${computerName}_Networking\${computerName}_Ipconfig.txt"
$routefile = "${computerName}_Networking\${computerName}_Route.txt"
$domtrustfile = "${computerName}_Networking\${computerName}_Nltest-domtrusts.txt"

$GetRDSFarmDatafile = "${computerName}_RDS\${computerName}_GetFarmData.txt"
$getcapfile = "${computerName}_RDS\${computerName}_rdgw_ConnectionAuthorizationPolicy.txt"
$getrapfile = "${computerName}_RDS\${computerName}_rdgw_ResourceAuthorizationPolicy.txt"
$gracefile = "${computerName}_RDS\${computerName}_rdsh_GracePeriod.txt"
$tslsgroupfile = "${computerName}_RDS\${computerName}_TSLSMembership.txt"
$licpakfile = "${computerName}_RDS\${computerName}_rdls_LicenseKeyPacks.html"
$licoutfile = "${computerName}_RDS\${computerName}_rdls_IssuedLicenses.html"

$permDriveCfile = "${computerName}_SystemInfo\${computerName}_Permissions-DriveC.txt"
$dxdiagfile = "${computerName}_SystemInfo\${computerName}_DxDiag.txt"
$kmsfile = "${computerName}_SystemInfo\${computerName}_KMS-Servers.txt"
$slmgrfile = "${computerName}_SystemInfo\${computerName}_slmgr-dlv.txt"
$sysinfofile = "${computerName}_SystemInfo\${computerName}_SystemInfo.txt"
$avinfofile = "${computerName}_SystemInfo\${computerName}_AntiVirusProducts.txt"
$dsregfile = "${computerName}_SystemInfo\${computerName}_Dsregcmd.txt"
$instappsfile = "${computerName}_SystemInfo\${computerName}_InstalledApplications.txt"
$instrolesfile = "${computerName}_SystemInfo\${computerName}_InstalledRoles.txt"
$updhistfile = "${computerName}_SystemInfo\${computerName}_UpdateHistory.html"
$powerfile = "${computerName}_SystemInfo\${computerName}_PowerReport.html"
$gpresfile = "${computerName}_SystemInfo\${computerName}_Gpresult.html"
$winrmcfgfile = "${computerName}_SystemInfo\${computerName}_WinRM-Config.txt"
$pnputilMousefile = "${computerName}_SystemInfo\${computerName}_PnpUtil-Devices-Mouse.txt"
$pnputilKeyboardfile = "${computerName}_SystemInfo\${computerName}_PnpUtil-Devices-Keyboard.txt"

$regCredDelegationFile = "${computerName}_RegistryKeys\${computerName}_HKLM-SW-Policies.txt"
$regDefExclFile = "${computerName}_RegistryKeys\${computerName}_HKLM-SW-MS-WinDef-Exclusions.txt"

$machineKeysFile = "${computerName}_Certificates\${computerName}_ACL-MachineKeys.txt"

if ($global:msrdRDS) {
    $listenerPermFile = "${computerName}_RDS\${computerName}_ListenerPermissions.txt"
} else {
    $listenerPermFile = "${computerName}_AVD\${computerName}_ListenerPermissions.txt"
}

#endregion hyperlinks

$rdiagmsg = msrdGetLocalizedText "rdiagmsg"
$checkmsg = msrdGetLocalizedText "checkmsg"

$script:GPUreq = $false

if (msrdTestRegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\' -Value 'ReverseConnectionListener') {
    $script:msrdListenervalue = Get-ItemPropertyValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\' -name "ReverseConnectionListener"
} else {
    $script:msrdListenervalue = ""
}

if (Test-Path $msrdAgentpath) {
    $avdcheck = $true
} else {
    $avdcheck = $false
    $avdcheckmsg = "AVD Agent <span style='color: brown'>not found</span>. This machine does not seem to be part of an AVD host pool. Skipping additional AVD host specific checks."
}

$script:isDomain = (get-ciminstance -Class Win32_ComputerSystem).PartOfDomain

#region Main Diag functions

Function msrdLogDiag {
    param([Int]$Level = $Loglevel.Normal, [string]$Type, [string]$DiagTag, [string]$Message, [string]$Message2, [string]$Message3, [string]$Title, [int]$col, [string]$circle, $addAssist)

    $global:msrdPerc = "{0:P}" -f ($global:msrdProgress/100)

    switch($circle) {
        'green' { $tdcircle = "circle_green" }
        'red' { $tdcircle = "circle_red" }
        'blue' { $tdcircle = "circle_blue" }
        'no' { $tdcircle = "circle_no" }
        default { $tdcircle = "circle_white" }
    }

    if ($global:msrdLiveDiag) {
        if ($global:msrdLiveDiagSystem)         { $liveDiagBox = $global:psBoxLiveDiagSystem }
        elseif ($global:msrdLiveDiagAVDRDS)     { $liveDiagBox = $global:psBoxLiveDiagAVDRDS }
        elseif ($global:msrdLiveDiagAVDInfra)   { $liveDiagBox = $global:psBoxLiveDiagAVDInfra }
        elseif ($global:msrdLiveDiagAD)         { $liveDiagBox = $global:psBoxLiveDiagAD }
        elseif ($global:msrdLiveDiagNet)        { $liveDiagBox = $global:psBoxLiveDiagNet }
        elseif ($global:msrdLiveDiagLogonSec)   { $liveDiagBox = $global:psBoxLiveDiagLogonSec }
        elseif ($global:msrdLiveDiagIssues)     { $liveDiagBox = $global:psBoxLiveDiagIssues }
        elseif ($global:msrdLiveDiagOther)      { $liveDiagBox = $global:psBoxLiveDiagOther }
        else                                    { Write-Output "Error: No liveDiagBox found" }
    }

    Switch($Level) {
        "0" { # Normal
            $LogConsole = $True; $MessageColor = 'Yellow'
            [decimal]$global:msrdProgress = $global:msrdProgress + $global:msrdProgstep

            if (!$global:msrdGUI -and !($global:msrdGUIformLite -and $global:msrdGUIformLite.Visible) -and $global:msrdDiagnosing) {
                Write-Progress -Activity "Running diagnostics. Please wait..." -Status "$global:msrdPerc complete:" -PercentComplete $global:msrdProgress
            } elseif (($global:msrdGUI -or ($global:msrdGUIformLite -and $global:msrdGUIformLite.Visible)) -and $global:msrdDiagnosing) {
                $global:msrdProgbar.PerformStep()
                $global:msrdStatusBarLabel.Text = "$rdiagmsg"
            }

            if ($global:msrdLiveDiag) {
                if ($global:msrdLangID -eq "AR") { $msg = "$Message" + " :" + "$checkmsg" } else { $msg = "$checkmsg" + ": " + "$Message" }

                $paddingLength = 160 - $msg.Length
                $padding = ' ' * $paddingLength

                if ($global:msrdLangID -eq "AR") { $line = "$padding $msg <<<" } else { $line = ">>> $msg $padding" }
                $DiagMessage2Screen = "$line"

            } else {
                if ($global:msrdLangID -eq "AR") {
                    $date = Get-Date
                    $day = $date.Day.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $month = $date.Month.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $year = $date.Year.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $hour = $date.Hour.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $minute = $date.Minute.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $second = $date.Second.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $millisecond = $date.Millisecond.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $datemsg = "${hour}:${minute}:${second}.${millisecond} ${year}/${month}/${day}"
                } else {
			        $datemsg = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss.fff")
		        }

                $DiagMessage2Screen = $datemsg + " $checkmsg " + $Message
            }

            if ($DiagTag -eq "DeploymentCheck") {
                $DiagMessage = "<details open><summary style='user-select: none;'><span style='position:relative;'><a name='$DiagTag' style='position:absolute; top:-155px;'></a><b>$Message</b><span class='b2top'><a href='#'>^top</a></span></summary></span><div class='detailsP'><table class='tduo'><tbody>"
            } else {
                $DiagMessage = "</tbody></table></div></details><details open><summary style='user-select: none;'><span style='position:relative;'><a name='$DiagTag' style='position:absolute; top:-155px;'></a><b>$Message</b><span class='b2top'><a href='#'>^top</a></span></summary></span><div class='detailsP'><table class='tduo'><tbody>"
            }
        }

        "1" { # Info
            $LogConsole = $True; $MessageColor = 'White'
            [decimal]$global:msrdProgress = $global:msrdProgress + $global:msrdProgstep

            if (!$global:msrdGUI -and !($global:msrdGUIformLite -and $global:msrdGUIformLite.Visible) -and $global:msrdDiagnosing) {
                Write-Progress -Activity "Running diagnostics. Please wait..." -Status "$global:msrdPerc complete:" -PercentComplete $global:msrdProgress
            } elseif (($global:msrdGUI -or ($global:msrdGUIformLite -and $global:msrdGUIformLite.Visible)) -and $global:msrdDiagnosing) {
                $global:msrdProgbar.PerformStep()
                $global:msrdStatusBarLabel.Text = "$rdiagmsg"
            }

            if (-not $global:msrdLiveDiag) {
                if ($global:msrdLangID -eq "AR") {
                    $date = Get-Date
                    $day = $date.Day.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $month = $date.Month.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $year = $date.Year.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $hour = $date.Hour.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $minute = $date.Minute.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $second = $date.Second.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $millisecond = $date.Millisecond.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $datemsg = "${hour}:${minute}:${second}.${millisecond} ${year}/${month}/${day}"
                } else {
			        $datemsg = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss.fff")
		        }

                $DiagMessage2Screen = $datemsg + " " + $Message
            }
        }

        "2" { $LogConsole = $True; $MessageColor = 'Magenta' } # Warning
        "3" { $LogConsole = $True; $MessageColor = 'Red' } # Error

        "9" { # Diag file only

            function PadWithSpaces([string]$text, [int]$desiredLength, [switch]$rtl = $false) {

                if (($null -eq $text) -or ($text -eq "")) { $text = " " }
                $currentLength = $text.Length
                $spacesNeeded = [Math]::Max(0, $desiredLength - $currentLength)
                $tabs = " " * $spacesNeeded
                if ($rtl) {
                    return "$tabs $text"
                } else {
                    return "$text $tabs"
                }
            }

            $LogConsole = $False
            if ($global:msrdLangID -eq "AR") {
                $date = Get-Date
                $day = $date.Day.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $month = $date.Month.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $year = $date.Year.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $hour = $date.Hour.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $minute = $date.Minute.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $second = $date.Second.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $millisecond = $date.Millisecond.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $datemsg = "${hour}:${minute}:${second}.${millisecond} ${year}/${month}/${day}"
            } else {
			    $datemsg = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss.fff")
		    }

            $DiagMessage2Screen = $datemsg + " " + $Message

            if ($global:msrdLiveDiag) {
                $Message = $Message -replace '<[^>]+>', '' -replace '\(See[^)]*\)', '' -replace 'See MSRD-Collect-Error for more information.', ''
                $Message2 = $Message2 -replace '<[^>]+>', '' -replace '\(See[^)]*\)', ''
                $Message3 = $Message3 -replace '<[^>]+>', '' -replace '\(See[^)]*\)', ''

                if ($Message2 -like "Issues found in the '*") {
                    $Message3 = "Run the 'Core' or 'DiagOnly' data collection scenarios to get more details about these issues"
                }

                if ($circle -eq "red") { $liveDiagBox.SelectionBackColor = "Yellow" }
            }

            if ((-not $global:msrdLiveDiag) -and ($circle -eq "red")) {
                if ($Message) { $Message = "<span style='background-color: #FFFFDD'>$Message</span>" }
                if ($Message2) { $Message2 = "<span style='background-color: #FFFFDD'>$Message2</span>" }
                if ($Message3) { $Message3 = "<span style='background-color: #FFFFDD'>$Message3</span>" }
            }

            if ($Type -eq "Text") {
                if ($global:msrdLiveDiag) {
                    $liveDiagBox.SelectionStart = $liveDiagBox.TextLength
                    $liveDiagBox.SelectionLength = 0
                    $liveDiagBox.AppendText("$Message`r`n")
                    $liveDiagBox.ScrollToCaret()
                    $liveDiagBox.Refresh()
                } else {
                    $DiagMessage = "<tr><td width='10px'><div class='$tdcircle'></div></td><td class='cText' colspan='$col'>$Message</td></tr>"
                }

            } elseif ($Type -eq "Table1-2") {
                if ($global:msrdLiveDiag) {
                    $sectionLength = 30
                    $paddedMessage = PadWithSpaces $Message $sectionLength
                    $combinedMessage = "$paddedMessage$Message2"

                    $liveDiagBox.SelectionStart = $liveDiagBox.TextLength
                    $liveDiagBox.SelectionLength = 0
                    $liveDiagBox.AppendText("$combinedMessage`r`n")
                    $liveDiagBox.ScrollToCaret()
                    $liveDiagBox.Refresh()
                } else {
                    $DiagMessage = "<tr><td width='10px'><div class='$tdcircle'></div></td><td class='cTable1-2'>$Message</td><td colspan='2'>$Message2</td></tr>"
                }

            } elseif ($Type -eq "Table2-1") {
                if ($global:msrdLiveDiag) {
                    $sectionLength = 130
                    $paddedMessage = PadWithSpaces $message $sectionLength
                    $combinedMessage = "$paddedMessage$Message2"

                    $liveDiagBox.SelectionStart = $liveDiagBox.TextLength
                    $liveDiagBox.SelectionLength = 0
                    $liveDiagBox.AppendText("$combinedMessage`r`n")
                    $liveDiagBox.ScrollToCaret()
                    $liveDiagBox.Refresh()
                } else {
                    if ($Title) {
                        $DiagMessage = "<tr><td width='10px'><div class='$tdcircle'></div></td><td class='cTable2-1' colspan='2'>$Message <span title='$Title' style='cursor: pointer'>&#9432;</span></td><td class='cReg2'>$Message2</td></tr>"
                    } else {
                        $DiagMessage = "<tr><td width='10px'><div class='$tdcircle'></div></td><td class='cTable2-1' colspan='2'>$Message</td><td>$Message2</td></tr>"
                    }
                }

            } elseif ($Type -eq "Table1-3") {
                if ($global:msrdLiveDiag) {
                    $sectionLength = 30
                    $sectionLength2 = 100
                    $paddedMessage = PadWithSpaces $message $sectionLength
                    $paddedMessage2 = PadWithSpaces $message2 $sectionLength2
                    $combinedMessage = "$paddedMessage$paddedMessage2$message3"

                    $liveDiagBox.SelectionStart = $liveDiagBox.TextLength
                    $liveDiagBox.SelectionLength = 0
                    $liveDiagBox.AppendText("$combinedMessage`r`n")
                    $liveDiagBox.ScrollToCaret()
                    $liveDiagBox.Refresh()
                } else {
                    if ($Title) {
                            $DiagMessage = "<tr><td width='10px'><div class='$tdcircle'></div></td><td class='cTable1-3'>$Message</td><td class='cTable1-3b'>$Message2 <span title='$Title' style='cursor: pointer'>&#9432;</span></td><td>$Message3</td></tr>"
                    } else {
                            $DiagMessage = "<tr><td width='10px'><div class='$tdcircle'></div></td><td class='cTable1-3'>$Message</td><td class='cTable1-3b'>$Message2</td><td>$Message3</td></tr>"
                    }
                }

            } elseif ($Type -eq "HR") {
                if ($global:msrdLiveDiag) {
                    $dashChar = "-"  # The character used for the line
                    $charWidth = [System.Windows.Forms.TextRenderer]::MeasureText($dashChar, $liveDiagBox.Font).Width
                    $lineLength = [Math]::Ceiling($liveDiagBox.Width / $charWidth)
                    $line = $dashChar * $lineLength
                    $liveDiagBox.SelectionStart = $liveDiagBox.TextLength
                    $liveDiagBox.SelectionLength = 0
                    $liveDiagBox.AppendText("`r`n`n$line`r`n")
                    $liveDiagBox.ScrollToCaret()
                    $liveDiagBox.Refresh()
                } else {
                    $commonStyle = "style='height:5px; padding-left: 0px; padding-right: 0px; padding-bottom: 0px;'"
                    $hrTag = "<td><hr></td>"
                    if (!$col) { $col = 3 }
                    $hrTags = $hrTag * $col
                    $DiagMessage = "<tr $commonStyle><td></td>$hrTags</tr>"
                }

            } elseif ($Type -eq "Spacer") {
                if ($global:msrdLiveDiag) {
                    $liveDiagBox.SelectionStart = $liveDiagBox.TextLength
                    $liveDiagBox.SelectionLength = 0
                    $liveDiagBox.AppendText("`r`n")
                    $liveDiagBox.ScrollToCaret()
                    $liveDiagBox.Refresh()
                } else {
                    $DiagMessage = "<tr style='height:5px;'></tr>"
                }

            } elseif ($Type -eq "DL") {
                if ($global:msrdLiveDiag) {
                    $dashChar = "- "  # The character used for the line
                    $charWidth = [System.Windows.Forms.TextRenderer]::MeasureText($dashChar, $liveDiagBox.Font).Width
                    $lineLength = [Math]::Ceiling($liveDiagBox.Width / $charWidth)
                    $line = $dashChar * $lineLength
                    $liveDiagBox.SelectionStart = $liveDiagBox.TextLength
                    $liveDiagBox.SelectionLength = 0
                    $liveDiagBox.AppendText("`r`n$line`r`n")
                    $liveDiagBox.ScrollToCaret()
                    $liveDiagBox.Refresh()
                } else {
                    $DiagMessage = "<tr style='height:5px; padding-left: 0px; padding-right: 0px; padding-bottom: 0px;'><td></td><td><hr style='border-style: dashed; border-color: gray;'></td><td><hr style='border-style: dashed; border-color: gray;'></td><td><hr style='border-style: dashed; border-color: gray;'></td></tr>"
                }
            }
        }
    }

    If (($Color) -and $Color.Length -ne 0) { $MessageColor = $Color }

    if ($LogConsole) {
        if ($global:msrdGUI) {
            if ($global:msrdLiveDiag) {
                $liveDiagBox.SelectionStart = $liveDiagBox.TextLength
                $liveDiagBox.SelectionLength = 0
                $liveDiagBox.SelectionBackColor = "White"
                $liveDiagBox.AppendText("`r`n`n")

                if ($Level -eq $Loglevel.Normal) {
                    $currentLength = $liveDiagBox.TextLength
                    $liveDiagBox.AppendText("$DiagMessage2Screen`r`n")
                    $liveDiagBox.Select($currentLength, $DiagMessage2Screen.Length)
                    $liveDiagBox.SelectionBackColor = "#707070"
                    $liveDiagBox.SelectionColor = "White"

                    if ($global:msrdLangID -eq "AR") {
                        $liveDiagBox.SelectionAlignment = "Right"
                    } else {
                        $liveDiagBox.SelectionAlignment = "Left"
                    }
                } else {
                    $liveDiagBox.AppendText("$DiagMessage2Screen`r`n")
                    $liveDiagBox.SelectionAlignment = "Left"
                    $liveDiagBox.SelectionBackColor = "White"
                }

                $liveDiagBox.AppendText("`r`n")
                $liveDiagBox.ScrollToCaret()
                $liveDiagBox.Refresh()
            } else {
                $msrdPsBox.SelectionStart = $msrdPsBox.TextLength
                $msrdPsBox.SelectionLength = 0
                $msrdPsBox.SelectionColor = $MessageColor
                $msrdPsBox.AppendText("$DiagMessage2Screen`r`n")
                $msrdPsBox.ScrollToCaret()
                $msrdPsBox.Refresh()
            }
        } else {
            $host.ui.RawUI.ForegroundColor = $MessageColor
            Write-Output $DiagMessage2Screen
            $host.ui.RawUI.ForegroundColor = $global:msrdConsoleColor
        }
    }

    if ((($Level -eq $Loglevel.Normal) -or ($Level -eq $Loglevel.Info)) -and (-not $global:msrdLiveDiag)) {
        $DiagMessage2Screen | Out-File -Append $global:msrdOutputLogFile
    } elseif (($Level -eq $Loglevel.Warning) -and (-not $global:msrdLiveDiag)) {
        $DiagMessage2Screen | Out-File -Append $global:msrdWarningLogFile
    }

    if ((($global:msrdAssistMode -eq 1) -or $addAssist) -and ($Level -eq $Loglevel.Normal)) { msrdLogMessageAssistMode "$checkmsg $Message" }

    if (($Level -ne $Loglevel.Info) -and (-not $global:msrdLiveDiag)) { Add-Content $msrdDiagFile $DiagMessage }
}

Function msrdCheckRegKeyValue {
    Param([string]$RegPath, [string]$RegKey, [string]$RegValue, [string]$OptNote, [switch]$skipValue, [switch]$addWarning, [switch]$warnMissing = $false, $linkToReg, [string]$warnIfValue)

    if (msrdTestRegistryValue -path $RegPath -value $RegKey) {
        (Get-ItemProperty -path $RegPath).PSChildName | foreach-object -process {
            $key = Get-ItemPropertyValue -Path $RegPath -name $RegKey
            $keytype = $key.GetType().Name

            if ($keytype -like "*int*") {
                $hexkey = "0x{0:x8}" -f $key
                $key2 = "$key ($hexkey)"
            } elseif ($keytype -like "*byte*") {
                $hexkey = ($key | ForEach-Object { "{0:X2}" -f $_ }) -join ' '
                $key2 = $hexkey
            } else {
                $key2 = $key
            }

            if ($linkToReg) {
                $regfilecheck = Test-Path -Path ($global:msrdLogDir + $linkToReg)
                if ($regfilecheck) { $key2 += " (See: <a href='$linkToReg' target='_blank'>Reg export</a>)" }
            }

            if ($RegValue) {
                if ($key -eq $RegValue) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$RegPath<span style='color: blue'>$RegKey</span>" -Message2 "$key2" -Title "$OptNote" -circle "green"
                } else {
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$RegPath<span style='color: blue'>$RegKey</span>" -Message2 "$key2 (Expected: $RegValue)" -Title "$OptNote" -circle "red" #warning
                }
            } else {
                if ($skipValue) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$RegPath<span style='color: blue'>$RegKey</span>" -Message2 "found" -Title "$OptNote" -circle "blue"
                } else {
                    if ($addWarning) {
                        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$RegPath<span style='color: blue'>$RegKey</span>" -Message2 "$key2" -Title "$OptNote" -circle "red" #warning
                    } elseif ($warnIfValue -and ($key -eq $warnIfValue)) {
                        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$RegPath<span style='color: blue'>$RegKey</span>" -Message2 "$key2" -Title "$OptNote" -circle "red"
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$RegPath<span style='color: blue'>$RegKey</span>" -Message2 "$key2" -Title "$OptNote" -circle "blue"
                    }
                }
            }
        }
    } else {
        if ($warnMissing) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$RegPath<span style='color: blue'>$RegKey</span>" -Message2 "not found" -Title "$OptNote" -circle "red"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$RegPath<span style='color: blue'>$RegKey</span>" -Message2 "not found" -Title "$OptNote" -circle "white"
        }
    }
}

function msrdTestTCP {
    param([string]$Address,[int]$Port,[int]$Timeout = 20000)

    try {
        $Socket = New-Object System.Net.Sockets.TcpClient
        $Result = $Socket.BeginConnect($Address, $Port, $null, $null)
        $WaitHandle = $Result.AsyncWaitHandle
        if (!$WaitHandle.WaitOne($Timeout)) {
            throw [System.TimeoutException]::new('Connection Timeout')
        }
        $Socket.EndConnect($Result) | Out-Null
        $Connected = $Socket.Connected
        $remoteEndPoint = $Socket.Client.RemoteEndPoint
        $remoteIPAddress = $remoteEndPoint.Address.IPAddressToString
    } catch {
        $FailedCommand = $MyInvocation.Line.TrimStart()
        $FailedCommand = $FailedCommand -replace [regex]::Escape("`$url"), $Address -replace [regex]::Escape("`$port"), $Port
        msrdLogException ("$(msrdGetLocalizedText 'errormsg') $FailedCommand") -ErrObj $_
    } finally {
        if ($Socket) { $Socket.Dispose() }
        if ($WaitHandle) { $WaitHandle.Dispose() }
    }

    $Connected
    $remoteIPAddress
}

Function msrdCheckServicePort {
    param ([String]$service, [String[]]$tcpports, [String[]]$udpports, [int]$skipWarning, [switch]$stopWarning, $linkmsg)

    #check service status and port access
    $serv = Get-CimInstance Win32_Service -Filter "name = '$service'" | Select-Object Name, ProcessId, State, StartMode, StartName, DisplayName, Description

    if ($serv) {
        $msg3 = "$($serv.State) ($($serv.StartMode)) ($($serv.StartName))"
        if ($linkmsg) { $msg3 += " (See: $linkmsg)" }

        if (($serv.StartMode -eq "Disabled") -or (($serv.StartMode -eq "Stopped") -and $stopWarning)) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "Service" -Message2 "<b>$service</b> - $($serv.DisplayName)" -Message3 "$msg3" -Title "$($serv.Description)" -circle "red"
        } elseif ($serv.State -eq "Running") {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "Service" -Message2 "<b>$service</b> - $($serv.DisplayName)" -Message3 "$msg3" -Title "$($serv.Description)" -circle "green"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "Service" -Message2 "<b>$service</b> - $($serv.DisplayName)" -Message3 "$msg3" -Title "$($serv.Description)" -circle "blue"
        }

        #dependencies
        $dependsOn = (Get-Service -Name "$service").RequiredServices
        if ($dependsOn) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$service depends on the following system components"
            foreach ($dep in $dependsOn) {
                $depConfig = Get-CimInstance Win32_Service -Filter "name = '$($dep.Name)'" | Select-Object State, StartMode, StartName, DisplayName, Description
                if ($depConfig) {
                    if ($depConfig.State -eq "Running") {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($dep.Name) - $($depConfig.DisplayName)" -Message3 "$($depConfig.State) ($($depConfig.StartMode)) ($($depConfig.StartName))" -circle "green" -Title "$($depConfig.Description)"
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($dep.Name) - $($depConfig.DisplayName)" -Message3 "$($depConfig.State) ($($depConfig.StartMode)) ($($depConfig.StartName))" -circle "blue" -Title "$($depConfig.Description)"
                    }
                } else {
                    $depConfig = Get-Service "$($dep.Name)" | Select-Object Status, StartType, DisplayName
                    if ($depConfig.Status -eq "Running") {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($dep.Name) - $($depConfig.DisplayName)" -Message3 "$($depConfig.Status) ($($depConfig.StartType))" -circle "green"
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($dep.Name) - $($depConfig.DisplayName)" -Message3 "$($depConfig.Status) ($($depConfig.StartType))" -circle "blue"
                    }
                }
            }
        }

        $othersDepend = (Get-Service -Name "$service").DependentServices
        if ($othersDepend) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message ("System components depending on $service")
            foreach ($other in $othersDepend) {
                $otherConfig = Get-CimInstance Win32_Service -Filter "name = '$($other.Name)'" | Select-Object State, StartMode, StartName, DisplayName, Description
                if ($otherConfig) {
                    if ($otherConfig.State -eq "Running") {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($other.Name) - $($otherConfig.DisplayName)" -Message3 "$($otherConfig.State) ($($otherConfig.StartMode)) ($($otherConfig.StartName))" -circle "green" -Title "$($otherConfig.Description)"
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($other.Name) - $($otherConfig.DisplayName)" -Message3 "$($otherConfig.State) ($($otherConfig.StartMode)) ($($otherConfig.StartName))" -circle "blue" -Title "$($otherConfig.Description)"
                    }
                } else {
                    $otherConfig = Get-Service "$($other.Name)" | Select-Object Status, StartType, DisplayName
                    if ($otherConfig.Status -eq "Running") {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($other.Name) - $($otherConfig.DisplayName)" -Message3 "$($otherConfig.Status) ($($otherConfig.StartType))" -circle "green"
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($other.Name) - $($otherConfig.DisplayName)" -Message3 "$($otherConfig.Status) ($($otherConfig.StartType))" -circle "blue"
                    }
                }
            }
        }

        #recovery settings
        $outcmd = sc.exe qfailure $service
        if ($outcmd) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$service recovery settings"
            foreach ($fsout in $outcmd) {
                if (($fsout -like "*RESET*") -or ($fsout -like "*REBOOT*") -or ($fsout -like "*COMMAND*") -or ($fsout -like "*FAILURE*") -or ($fsout -like "*RUN PROCESS*") -or ($fsout -like "*RESTART*")) {
                    $fsrec1 = $fsout.Split(":")[0]; if ($fsrec1) { $fsrec1 = $fsrec1.Trim() }
                    $fsrec2 = $fsout.Split(":")[1]; if ($fsrec2) { $fsrec2 = $fsrec2.Trim() }
                    if ($fsrec2) {
                        if ($fsrec2 -ne " ") { $reccircle = "blue" } else { $reccircle = "white" }
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$fsrec1" -Message3 "$fsrec2" -circle "$reccircle"
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message3 "$fsrec1" -circle "blue"
                    }
                }
            }
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Could not retrieve $service service failure settings" -circle "red"
        }

        #ports
        If (!($global:msrdOSVer -like "*Server*2008*")) {
            if ($tcpports) {
                foreach ($port in $tcpports) {
                    $exptcplistener = Get-NetTCPConnection -OwningProcess $serv.ProcessId -LocalPort $port -ErrorAction Continue 2>>$global:msrdErrorLogFile

                    if ($exptcplistener) {
                        foreach ($tcpexp in $exptcplistener) {
                            $tcpexpaddr = $tcpexp.LocalAddress
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$service is listening on port" -Message2 "$port (TCP) (LocalAddress: $tcpexpaddr)" -circle "green"
                        }
                    } else {
                        $tcphijackpid = (Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue).OwningProcess
                        if ($tcphijackpid) {
                            foreach ($tcppid in $tcphijackpid) {
                                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                                $tcpaddress = $tcppid.LocalAddress
                                $tcphijackproc = (Get-WmiObject Win32_service | Where-Object ProcessId -eq "$tcppid").Name
                                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$service is not listening on TCP port $port (LocalAddress: $tcpaddress). The TCP port $port is being used by" -Message2 "$tcphijackproc ($tcppid)" -circle "red"
                            }
                        } else {
                            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "No process is listening on TCP port $port." -circle "red"
                        }
                    }
                }
            }

            if (!($global:msrdOSVer -like "*Server*2008*") -and !($global:msrdOSVer -like "*Server*2012*")) {
                if ($udpports) {
                    foreach ($port in $udpports) {
                        $expudplistener = Get-NetUDPEndpoint -OwningProcess $serv.ProcessId -LocalPort $port -ErrorAction Continue 2>>$global:msrdErrorLogFile

                        if ($expudplistener) {
                            foreach ($udpexp in $expudplistener) {
                                $udpexpaddr = $udpexp.LocalAddress
                                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$service is listening on port" -Message2 "$port (UDP) (LocalAddress: $udpexpaddr)" -circle "green"
                            }
                        } else {
                            $udphijackpid = (Get-NetUDPEndpoint -LocalPort $port -ErrorAction SilentlyContinue).OwningProcess
                            if ($udphijackpid) {
                                foreach ($udppid in $udphijackpid) {
                                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                                    $udpaddress = $udppid.LocalAddress
                                    $udphijackproc = (Get-WmiObject Win32_service | Where-Object ProcessId -eq "$udphijackpid").Name
                                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$service is not listening on UDP port $port (LocalAddress: $udpaddress). The UDP port $port is being used by" -Message2 "$udphijackproc ($udppid)" -circle "red"
                                }
                            } else {
                                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "No process is listening on UDP port $port." -circle "blue"
                            }
                        }
                    }
                }
            }
        }

    } else {
        if ($skipWarning -eq 1) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "Service" -Message2 "$service" -Message3 "not found"
        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "Service" -Message2 "$service" -Message3 "not found" -circle "red"
        }
    }
}

function msrdGetAppxInstallationDate {
    param (
        [string]$packageName
    )

    $appxPackage = Get-AppxPackage -Name $packageName -ErrorAction SilentlyContinue

    if ($appxPackage) {
        $packageFolder = Get-Item -LiteralPath $appxPackage.InstallLocation -ErrorAction SilentlyContinue

        if ($packageFolder) {
            $installationDateTime = $packageFolder.CreationTime
            $installationDate = $installationDateTime.ToString("yyyy/MM/dd")
        } else {
            $installationDate = "N/A"
        }

    } else {
        $installationDate = "N/A"
    }

    return $installationDate
}

#endregion Main Diag functions


#region System diag functions

Function msrdDiagDeployment {

    #deployment diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Core"
    $menucatmsg = "System"
    msrdLogDiag $LogLevel.Normal -DiagTag "DeploymentCheck" -Message $menuitemmsg

    $sysinfofileExists = Test-Path -Path ($global:msrdLogDir + $sysinfofile)
    $instappsfileExists = Test-Path -Path ($global:msrdLogDir + $instappsfile)
    $gpresfileExists = Test-Path -Path ($global:msrdLogDir + $gpresfile)
    $existingFiles = @()
    if ($sysinfofileExists) { $existingFiles += "<a href='$sysinfofile' target='_blank'>SystemInfo</a>" }
    if ($instappsfileExists) { $existingFiles += "<a href='$instappsfile' target='_blank'>InstalledApps</a>" }
    if ($gpresfileExists) { $existingFiles += "<a href='$gpresfile' target='_blank'>Gpresult</a>" }

    if ($existingFiles.Count -eq 0) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "FQDN" -Message2 "$global:msrdFQDN"
    } else {
        $filesString = $existingFiles -join " / "
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "FQDN" -Message2 "$global:msrdFQDN" -Message3 "(See: $filesString)"
    }

    if (!($isDomain)) {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "This machine is not joined to a domain." -circle "red" #warning
    }

    #Azure VM query
    Try {
        $AzureVMquery = Invoke-RestMethod -Headers @{"Metadata"="true"} -URI 'http://169.254.169.254/metadata/instance?api-version=2021-12-13' -Method Get -TimeoutSec 30

        $vmloc = $AzureVMquery.Compute.location
        $script:vmsize = $AzureVMquery.Compute.vmSize
        if ($AzureVMquery.Compute.sku -eq "") { $vmsku = "N/A" } else { $vmsku = $AzureVMquery.Compute.sku }
        if ($AzureVMquery.Compute.licenseType -eq "") { $global:msrdVmlictype = "N/A" } else { $global:msrdVmlictype = $AzureVMquery.Compute.licenseType }
    } Catch {
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
        $vmsku = "N/A"
        $vmloc = "N/A"
        $script:vmsize = "N/A"
        $global:msrdVmlictype = "N/A"
    }
    $global:azvmq = $true

    if (($global:msrdOSVer -like "*Server*") -and (Test-Path -Path ($global:msrdLogDir + $instrolesfile))) {
        $vmsku = "$vmsku (See: <a href='$instrolesfile' target='_blank'>InstalledRoles</a>)"
    }

    $OSArc = (Get-CimInstance -ClassName Win32_OperatingSystem).OSArchitecture

    if (!($global:msrdOSVer -like "*Windows 7*")) {

        if (($global:msrdOSVer -like "*Server*2008*") -or ($global:msrdOSVer -like "*Server*2012*")) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "OS" -Message2 "$global:msrdOSVer $OSArc (Build: $global:WinVerMajor.$global:WinVerBuild.$global:WinVerRevision)" -Message3 "SKU: $vmsku"
        } else {
            if ($global:WinVerMajor -like "*10*") {
                [string]$shortver = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion' DisplayVersion -ErrorAction SilentlyContinue).DisplayVersion
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "OS" -Message2 "$global:msrdOSVer $shortver $OSArc (Build: $global:WinVerMajor.$global:WinVerMinor.$global:WinVerBuild.$global:WinVerRevision)" -Message3 "SKU: $vmsku"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "OS" -Message2 "$global:msrdOSVer $OSArc (Build: $global:WinVerMajor.$global:WinVerMinor.$global:WinVerBuild.$global:WinVerRevision)" -Message3 "SKU: $vmsku"
            }
        }

        $unsupportedMsg = "This OS version is no longer supported. See: {0}. Please upgrade the machine to a more current, in-service, and supported Windows release."
        if ((($global:WinVerMajor -like "*10*") -and (@("10240", "10586", "14393", "15063", "16299", "17134", "17763", "18362", "18363", "19041", "19042", "19043") -contains $global:WinVerBuild) -and !($global:msrdOSVer -like "*Server*")) -or ($global:msrdOSVer -like "*Windows 8.1*")) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            $ref = switch -Wildcard ($global:msrdOSVer) {
                "*Pro*" { $w10proRef }
                "*Home*" { $w10proRef }
                "*Enterprise*" { $w10entRef }
                "*Education*" { $w10entRef }
                "*Windows 8.1*" { $w81Ref }
            }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 ($unsupportedMsg -f $ref) -circle "red"
        }

        if (($global:msrdOSVer -like "*Server 2008 R2*") -or ($global:msrdOSVer -like "*Server 2012 R2*")) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            $ref = switch -Wildcard ($global:msrdOSVer) {
                "*Server 2008 R2*" { $w2008r2Ref }
                "*Server 2012 R2*" { $w2012r2Ref }
            }
            if (($global:msrdOSVer -like "*2012 R2*") -and ($global:msrdAVD)) {
                $unsupportedMsg += " See the list of supported OS for AVD: $avdOSRef"
            }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 ($unsupportedMsg -f $ref) -circle "red"
        }

        if (($global:WinVerMajor -like "*10*") -and (@("19044", "22000") -contains $global:WinVerBuild) -and (($global:msrdOSVer -like "*Pro*") -or ($global:msrdOSVer -like "*Home*"))) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            $ref = switch -Wildcard ($global:msrdOSVer) {
                "*Pro*" { $w10proRef }
                "*Home*" { $w10proRef }
            }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 ($unsupportedMsg -f $ref) -circle "red"
        }
    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "OS" -Message2 "$global:msrdOSVer (Build: $global:WinVerMajor.$global:WinVerBuild.$global:WinVerRevision)" -Message3 "SKU: $vmsku"
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        $w7message = $unsupportedMsg
        if ($global:msrdAVD) {
            $w7message += " See the list of supported OS for AVD: $avdOSRef"
        }
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 $w7message -circle "red"
    }

    if ($global:msrdAVD -and $global:msrdTarget) {
        if (($global:msrdOSVer -like "*Pro*") -or ($global:msrdOSVer -like "*Enterprise N*") -or ($global:msrdOSVer -like "*LTSB*") -or ($global:msrdOSVer -like "*LTSC*") -or ($global:msrdOSVer -like "*Enterprise KN*")) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "If this machine is intended to be an AVD host, then this OS is not supported. See the list of supported operating systems for AVD hosts: $avdOSRef" -circle "red"
        }
    }

    #image type
    if ($avdcheck) {
        if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\Microsoft\RDInfraAgent" -value "AzureVmImageType") {
            $azvmtype = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\RDInfraAgent" -name "AzureVmImageType"
            if ($azvmtype -eq "Marketplace") {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Image Type" -Message2 "$azvmtype" -circle "green"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Image Type" -Message2 "$azvmtype" -circle "blue"
            }
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Image Type" -Message2 "N/A"
        }
    }

    #SystemProductName
    if (msrdTestRegistryValue -path "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation" -value "SystemProductName") {
        $sysprodname = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation" -name "SystemProductName"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Model" -Message2 "$sysprodname"
    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Model" -Message2 "N/A"
    }

    #check number of vCPUs
    $vCPUs = (Get-CimInstance -Namespace "root\cimv2" -Query "select NumberOfLogicalProcessors from Win32_ComputerSystem" -ErrorAction SilentlyContinue).NumberOfLogicalProcessors
    $vMemInit = (Get-CimInstance -Namespace "root\cimv2" -Query "select TotalPhysicalMemory from Win32_ComputerSystem" -ErrorAction SilentlyContinue).TotalPhysicalMemory
    $vMem = ("{0:N0}" -f ($vMemInit/1gb)) + " GB"

    if (($global:msrdOSVer -like "*Virtual Desktops*") -or ($global:msrdOSVer -like "*multi-session*") -or ($global:msrdOSVer -like "*Server*")) {
        if (($vCPUs -lt 4) -or ($vCPUs -gt 24)) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Size" -Message2 "$script:vmsize ($vCPUs vCPUs / $vMem RAM). Recommended is to have between 4 and 24 vCPUs for multi-session VMs. See $vmsizeRef" -circle "red"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Size" -Message2 "$script:vmsize ($vCPUs vCPUs / $vMem RAM)"
        }
    } else {
        if ($vCPUs -lt 4) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Size" -Message2 "$script:vmsize ($vCPUs vCPUs / $vMem RAM). Recommended is to have at least 4 vCPUs for single-session VMs. See $vmsizeRef" -circle "red"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Size" -Message2 "$script:vmsize ($vCPUs vCPUs / $vMem RAM)"
        }
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Location" -Message2 "$vmloc"

    #get timezone
    $ltz = Get-ItemPropertyValue -path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -name "TimeZoneKeyName" -ErrorAction SilentlyContinue
    if ($ltz) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "System Time Zone" -Message2 "$ltz"
    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "System Time Zone could not be retrieved" -circle "red"
    }
    $rtz = (Get-TimeZone).Id + " [" + (Get-TimeZone).DisplayName + "]"
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "In-session Time Zone" -Message2 "$rtz"

    #culture
    $cul = Get-Culture | Select-Object Name, DisplayName, KeyboardLayoutId
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "Culture" -Message2 "$($cul.DisplayName)" -Message3 "$($cul.Name) ($($cul.KeyboardLayoutId))"

    $muilang = (Get-WmiObject -Class Win32_OperatingSystem).MUILanguages
    $muilist = ""
    foreach ($ml in $muilang) {
        $muilist += $ml
        if ($ml -ne $muilang[-1]) { $muilist += "; " }
    }
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "MUI Language(s)" -Message2 "$muilist"

    #Azure resource id
    if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\Microsoft\RDInfraAgent" -value "AzureResourceId") {
        $arid = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\RDInfraAgent" -name "AzureResourceId"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Azure Resource Id" -Message2 "$arid"
    }

    #Azure VM id
    if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\Microsoft\RDInfraAgent" -value "AzureVmId") {
        $avmid = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\RDInfraAgent" -name "AzureVmId"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Azure VM Id" -Message2 "$avmid"
    }

    #AVD host GUID
    if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\Microsoft\RDInfraAgent" -value "GUID") {
        $hguid = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\RDInfraAgent" -name "GUID"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "AVD Host GUID" -Message2 "$hguid"
    }

    #OS install date
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    $OSinstallDate = (Get-CimInstance Win32_OperatingSystem).InstallDate
    $OSinstallDiff = [datetime]::Now - $OSinstallDate
    $OSage = "$($OSinstallDiff.Days)d $($OSinstallDiff.Hours)h $($OSinstallDiff.Minutes)m ago"
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "OS installation date/time" -Message2 "$OSinstallDate ($OSage)"

    #check last boot up time
    $lboott = (Get-CimInstance -ClassName win32_operatingsystem).lastbootuptime
    $lboottdif = [datetime]::Now - $lboott
    $sincereboot = "$($lboottdif.Days)d $($lboottdif.Hours)h $($lboottdif.Minutes)m ago"

    if ($lboottdif.TotalHours -gt 24) {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        if (Test-Path ($global:msrdLogDir + $powerfile)) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "Last boot up date/time" -Message2 "$lboott ($sincereboot). Rebooting daily could help clean out stuck sessions and avoid potential profile load issues." -circle "red" -Message3 "(See: <a href='$powerfile' target='_blank'>PowerReport</a>)"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Last boot up date/time" -Message2 "$lboott ($sincereboot). Rebooting daily could help clean out stuck sessions and avoid potential profile load issues." -circle "red"
        }
    } else {
        if (Test-Path ($global:msrdLogDir + $powerfile)) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "Last boot up date/time" -Message2 "$lboott ($sincereboot)" -Message3 "(See: <a href='$powerfile' target='_blank'>PowerReport</a>)"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Last boot up date/time" -Message2 "$lboott ($sincereboot)"
        }
    }

    #check .Net Framework (https://learn.microsoft.com/en-us/dotnet/framework/migration-guide/versions-and-dependencies)
    $dotnet = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Release
    if ($dotnet -ge 533320) { $dotnetver = "4.8.1 or later" }
    elseif (($dotnet -ge 528040) -and ($dotnet -lt 533320)) { $dotnetver = "4.8" }
    elseif (($dotnet -ge 461808) -and ($dotnet -lt 528040)) { $dotnetver = "4.7.2" }
    elseif (($dotnet -ge 461308) -and ($dotnet -lt 461808)) { $dotnetver = "4.7.1" }
    elseif (($dotnet -ge 460798) -and ($dotnet -lt 461308)) { $dotnetver = "4.7" }
    elseif (($dotnet -ge 394802) -and ($dotnet -lt 460798)) { $dotnetver = "4.6.2" }
    elseif (($dotnet -ge 394254) -and ($dotnet -lt 394802)) { $dotnetver = "4.6.1" }
    elseif (($dotnet -ge 393295) -and ($dotnet -lt 394254)) { $dotnetver = "4.6" }
    elseif (($dotnet -ge 379893) -and ($dotnet -lt 393295)) { $dotnetver = "4.5.2" }
    elseif (($dotnet -ge 378675) -and ($dotnet -lt 379893)) { $dotnetver = "4.5.1" }
    elseif (($dotnet -ge 378389) -and ($dotnet -lt 378675)) { $dotnetver = "4.5" }
    else { $dotnetver = "No .NET Framework 4.5 or later" }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    if ($global:msrdAVD -or $global:msrdW365) {
        if ($dotnet -lt 461808) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message ".Net Framework" -Message2 "$dotnetver - AVD/W365 requires .NET Framework 4.7.2 or later" -circle "red"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message ".Net Framework" -Message2 "$dotnetver" -circle "green"
        }
    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message ".Net Framework" -Message2 "$dotnetver"
    }

    #check Windows features
    If (!($global:msrdSource) -and !($global:msrdOSVer -like "*Server*2008*")) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Windows Features"
        $winfeat = "AppServerClient", "Microsoft-Hyper-V", "IsolatedUserMode", "Containers-DisposableClientVM"
        foreach ($wf in $winfeat) {
            $winOptFeat = Get-WindowsOptionalFeature -Online -FeatureName "$wf" -ErrorAction SilentlyContinue
            if ($winOptFeat) {
                if ($wf -eq "AppServerClient") { $circle = "green" } else { $circle = "blue" }
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($winOptFeat.DisplayName)" -Message3 "$($winOptFeat.State)" -circle $circle
            } else {
                if (($global:msrdOSVer -like "*Windows 1*Virtual Desktops*" -or $global:msrdOSVer -like "*Windows 1*multi-session*") -and ($wf -eq "AppServerClient")) {
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$wf" -Message3 "not found" -circle "red"
                } else {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$wf" -Message3 "not found"
                }
            }
        }
    }

    #checking for useful reg keys
    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\Setup\' -RegKey 'OOBEInProgress' -RegValue '0'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\Setup\' -RegKey 'SystemSetupInProgress' -RegValue '0'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\Setup\' -RegKey 'SetupPhase' -RegValue '0'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Control Panel\International\' -RegKey 'RestrictLanguagePacksAndFeaturesInstall' -OptNote 'Computer Policy: Restrict Language Pack and Language Feature Installation'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\MUI\Settings\' -RegKey 'MachineUILock' -OptNote 'Computer Policy: Force selected system UI language to overwrite the user UI language'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\MUI\Settings\' -RegKey 'PreferredUILanguages' -OptNote 'Computer Policy: Restricts the UI language Windows uses for all logged users'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Control Panel\Desktop\' -RegKey 'MultiUILanguageID' -OptNote 'User Policy: Restrict selection of Windows menus and dialogs language'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Control Panel\Desktop\' -RegKey 'PreferredUILanguages' -OptNote 'User Policy: Restricts the UI languages Windows should use for the selected user'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Control Panel\International\' -RegKey 'RestrictLanguagePacksAndFeaturesInstall' -OptNote 'User Policy: Restrict Language Pack and Language Feature Installation'

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagCPU {

    #CPU diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "CPU Utilization and Handles"
    $menucatmsg = "System"
    msrdLogDiag $LogLevel.Normal -DiagTag "CPUCheck" -Message $menuitemmsg

    $procs = Get-Process | Select-Object ProcessName, Id, CPU, Handles, NPM, PM, WS, Description

    $Top10CPU = $procs | Sort-Object CPU -desc | Select-Object -first 10
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -Message "Top 10 processes using the most CPU time on all processors" -col 7

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"

    if (-not $global:msrdLiveDiag) {
        Add-Content $msrdDiagFile "<tr align='center'><th width='10px'><div class='circle_no'></div></th><th>Process</th><th>Id</th><th>CPU(s)</th><th>Handles</th><th>NPM(K)</th><th>PM(K)</th><th>WS(K)</th></tr>"
    }

    foreach ($entry in $Top10CPU) {
        if ($entry.Description) {
            $desc = $entry.Description
        } else {
            $desc = "N/A"
        }

        if ($global:msrdLiveDiag) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 7 -Message "Process: $($entry.ProcessName) ($desc) - Id: $($entry.Id) - CPU(s): $($entry.CPU) - Handles: $($entry.Handles) - NPM(K): $($entry.NPM) - NPM(K): $($entry.PM) - WS(K): $($entry.WS)"
        } else {
            Add-Content $msrdDiagFile "<tr align='center'><td width='10px'><div class='circle_white'></div></td><td align='left' width='25%'>$($entry.ProcessName) ($desc)</td><td align='right'>$($entry.Id)</td><td align='right'>$($entry.CPU)</td><td align='right'>$($entry.Handles)</td><td align='right'>$($entry.NPM)</td><td align='right'>$($entry.PM)</td><td align='right'>$($entry.WS)</td></tr>"
        }
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR" -col 7

    $Top10Handles = $procs | Sort-Object Handles -desc | Select-Object -first 10
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -Message "Top 10 processes using the most handles" -col 7

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"

    if (-not $global:msrdLiveDiag) {
        Add-Content $msrdDiagFile "<tr align='center'><th width='10px'><div class='circle_no'></div></th><th>Process</th><th>Id</th><th>CPU(s)</th><th>Handles</th><th>NPM(K)</th><th>PM(K)</th><th>WS(K)</th></tr>"
    }

    foreach ($entry in $Top10Handles) {
        if ($entry.Description) {
            $desc = $entry.Description
        } else {
            $desc = "N/A"
        }

        if ($global:msrdLiveDiag) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 7 -Message "Process: $($entry.ProcessName) ($desc) - Id: $($entry.Id) - CPU(s): $($entry.CPU) - Handles: $($entry.Handles) - NPM(K): $($entry.NPM) - NPM(K): $($entry.PM) - WS(K): $($entry.WS)"
        } else {
            Add-Content $msrdDiagFile "<tr align='center'><td width='10px'><div class='circle_white'></div></td><td align='left' width='25%'>$($entry.ProcessName) ($desc)</td><td align='right'>$($entry.Id)</td><td align='right'>$($entry.CPU)</td><td align='right'>$($entry.Handles)</td><td align='right'>$($entry.NPM)</td><td align='right'>$($entry.PM)</td><td align='right'>$($entry.WS)</td></tr>"
        }
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagDrives {

    #disk diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Drives"
    $menucatmsg = "System"
    msrdLogDiag $LogLevel.Normal -DiagTag "DiskCheck" -Message $menuitemmsg

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 5 -Message "Local/Network drives"
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"

    $drvtype = "Unknown", "No Root Directory", "Removable Disk", "Local Disk", "Network Drive", "Compact Disc", "RAM Disk"
    $Vol = Get-CimInstance -NameSpace "root\cimv2" -Query "select * from Win32_LogicalDisk" -ErrorAction Continue 2>>$global:msrdErrorLogFile

    if (-not $global:msrdLiveDiag) {
        Add-Content $msrdDiagFile "<tr align='center'><th width='10px'><div class='circle_no'></div></th><th>Drive</th><th>Type</th><th>Total space (MB)</th><th>Free space (MB)</th><th>Percent free space</th></tr>"
    }

    foreach ($disk in $vol) {
        if ($null -ne $disk.Size) { $PercentFreeSpace = $disk.FreeSpace*100/$disk.Size }
        else { $PercentFreeSpace = 0 }

        $driveid = $disk.DeviceID
        $drivetype = $drvtype[$disk.DriveType]
        $ts = [math]::Round($disk.Size/1MB,2)
        $fs = [math]::Round($disk.FreeSpace/1MB,2)
        $pfs = [math]::Round($PercentFreeSpace,2)

        #warn if free space is below 5% of disk size
        if (($PercentFreeSpace -lt 5) -and (($drivetype -eq "Local Disk") -or ($drivetype -eq "Network Drive"))) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            if ($driveid -eq "C:") {
                if ($global:msrdLiveDiag) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 5 -Message "Drive: $driveid - Type: $drivetype - Total space (MB): $ts - Free space (MB): $fs - Percent free space: $pfs%"
                } else {
                    if (Test-Path ($global:msrdLogDir + $permDriveCfile)) {
                        Add-Content $msrdDiagFile "<tr align='center'><td width='10px'><div class='circle_red'></div></td><td>$driveid (See: <a href='$permDriveCfile' target='_blank'>Permissions</a>)</td><td>$drivetype</td><td>$ts</td><td>$fs</td><td><span style='color: red'>$pfs%</span></td></tr>"
                    } else {
                        Add-Content $msrdDiagFile "<tr align='center'><td width='10px'><div class='circle_red'></div></td><td>$driveid</td><td>$drivetype</td><td>$ts</td><td>$fs</td><td><span style='color: red'>$pfs%</span></td></tr>"
                    }
                }
            } else {
                if ($global:msrdLiveDiag) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 5 -Message "Drive: $driveid - Type: $drivetype - Total space (MB): $ts - Free space (MB): $fs - Percent free space: $pfs%"
                } else {
                    Add-Content $msrdDiagFile "<tr align='center'><td width='10px'><div class='circle_red'></div></td><td>$driveid</td><td>$drivetype</td><td>$ts</td><td>$fs</td><td><span style='color: red'>$pfs%</span></td></tr>"
                }
            }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -Message "You are running low on free space (less than 5%) on drive: $driveid" -col 5 -circle "red"
        } else {
            if ($driveid -eq "C:") {
                if ($global:msrdLiveDiag) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 5 -Message "Drive: $driveid - Type: $drivetype - Total space (MB): $ts - Free space (MB): $fs - Percent free space: $pfs%"
                } else {
                    if (Test-Path ($global:msrdLogDir + $permDriveCfile)) {
                        Add-Content $msrdDiagFile "<tr align='center'><td width='10px'><div class='circle_white'></div></td><td>$driveid (See: <a href='$permDriveCfile' target='_blank'>Permissions</a>)</td><td>$drivetype</td><td>$ts</td><td>$fs</td><td>$pfs%</td></tr>"
                    } else {
                        Add-Content $msrdDiagFile "<tr align='center'><td width='10px'><div class='circle_white'></div></td><td>$driveid</td><td>$drivetype</td><td>$ts</td><td>$fs</td><td>$pfs%</td></tr>"
                    }
                }
            } else {
                if ($global:msrdLiveDiag) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 5 -Message "Drive: $driveid - Type: $drivetype - Total space (MB): $ts - Free space (MB): $fs - Percent free space: $pfs%"
                } else {
                    Add-Content $msrdDiagFile "<tr align='center'><td width='10px'><div class='circle_white'></div></td><td>$driveid</td><td>$drivetype</td><td>$ts</td><td>$fs</td><td>$pfs%</td></tr>"
                }
            }
        }
    }

    #rdp redirected drives
    if (!($global:msrdSource)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR" -col 5
        $rdpdrives = net use
        if ($rdpdrives -and ($rdpdrives -like "*tsclient*")) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 5 -Message "Remote Desktop redirected drives"
            foreach ($rdpd in $rdpdrives) {
                if ($rdpd -like "*tsclient*") {
                    $rdpdregex1 = [regex]::new("\\\\[^ ]+")
                    $drive = $rdpdregex1.Match($rdpd).Value

                    $rdpdregex2 = [regex]::new("\\\\[^ ]+ *(.+)$")
                    $network = $rdpdregex2.Match($rdpd).Groups[1].Value
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$drive" -Message3 "$network" -circle "blue"
                }
            }
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 5 -Message "Remote Desktop redirected drives not found"
        }
    }

    #client side redirection
    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR" -col 5
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Terminal Server Client\' -RegKey 'DisableDriveRedirection' -RegValue '0'

    #host side redirection
    if (!($global:msrdSource)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fDisableCdm' -RegValue '0' -OptNote 'Computer Policy: Do not allow drive redirection'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'fDisableCdm' -RegValue '0'
        if ($global:msrdAVD -or $global:msrdW365) {
            if ($script:msrdListenervalue) {
                msrdCheckRegKeyValue ('HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\' + $script:msrdListenervalue + '\') -RegKey 'fDisableCdm' -RegValue '0'
            } else {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Active AVD listener configuration not found" -circle "red"
            }
        }
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }

}

Function msrdGetDispScale {

    #get display scale %
$code2 = @'
  using System;
  using System.Runtime.InteropServices;
  using System.Drawing;

  public class DPI {
    [DllImport("gdi32.dll")]
    static extern int GetDeviceCaps(IntPtr hdc, int nIndex);

    public enum DeviceCap { VERTRES = 10, DESKTOPVERTRES = 117 }

    public static float scaling() {
      Graphics g = Graphics.FromHwnd(IntPtr.Zero);
      IntPtr desktop = g.GetHdc();
      int LogicalScreenHeight = GetDeviceCaps(desktop, (int)DeviceCap.VERTRES);
      int PhysicalScreenHeight = GetDeviceCaps(desktop, (int)DeviceCap.DESKTOPVERTRES);
      return (float)PhysicalScreenHeight / (float)LogicalScreenHeight;
    }
  }
'@

if ($PSVersionTable.PSVersion.Major -eq 5) {
    Add-Type -TypeDefinition $code2 -ReferencedAssemblies 'System.Drawing.dll'
} else {
    Add-Type -TypeDefinition $code2 -ReferencedAssemblies 'System.Drawing.dll','System.Drawing.Common'
}

    $DScale = [Math]::round([DPI]::scaling(), 2) * 100
    if ($DScale) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Display scaling rate" -Message2 "$DScale%"
    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -Message "Display scaling rate could not be determined." -col 3 -circle "red"
    }
}

Function msrdDiagGraphics {

    #graphics diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Graphics"
    $menucatmsg = "System"
    msrdLogDiag $LogLevel.Normal -DiagTag "GPUCheck" -Message $menuitemmsg

    if (!($global:msrdOSVer -like "*Server*2008*") -and !($global:msrdOSVer -like "*Server*2012*")) {

        if (!($global:azvmq)) {
            Try {
                $AzureVMquery = Invoke-RestMethod -Headers @{"Metadata"="true"} -URI 'http://169.254.169.254/metadata/instance?api-version=2021-12-13' -Method Get -TimeoutSec 30

                $vmloc = $AzureVMquery.Compute.location
                $script:vmsize = $AzureVMquery.Compute.vmSize
                if ($AzureVMquery.Compute.sku -eq "") { $vmsku = "N/A" } else { $vmsku = $AzureVMquery.Compute.sku }
                if ($AzureVMquery.Compute.licenseType -eq "") { $global:msrdVmlictype = "N/A" } else { $global:msrdVmlictype = $AzureVMquery.Compute.licenseType }
            } Catch {
                $failedCommand = $_.InvocationInfo.Line.TrimStart()
                msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
                $vmsku = "N/A"
                $vmloc = "N/A"
                $script:vmsize = "N/A"
                $global:msrdVmlictype = "N/A"
            }
            $global:azvmq = $true
        }

        if (($script:vmsize -like "*NV*") -or ($script:vmsize -like "*NC*")) {
            if (Test-Path ($global:msrdLogDir + $dxdiagfile)) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "A GPU optimized VM size has been detected." -Message2 "(See: <a href='$dxdiagfile' target='_blank'>DxDiag</a>)" -circle "green"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -Message "A GPU optimized VM size has been detected." -col 3 -circle "green"
            }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -Message "Make sure all the prerequisites are met to take full advantage of the GPU capabilities. See $gpuRef" -col 3 -circle "blue"
            $script:GPUreq = $true
        } else {
            if (Test-Path ($global:msrdLogDir + $dxdiagfile)) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "This machine does not seem to be a GPU enabled Azure VM." -Message2 "(See: <a href='$dxdiagfile' target='_blank'>DxDiag</a>)" -circle "blue"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -Message "This machine does not seem to be a GPU enabled Azure VM." -col 3 -circle "blue"
            }
            $script:GPUreq = $false
        }
    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -Message "GPU-accelerated rendering and encoding are not supported for this OS version." -col 3 -circle "blue"
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"

    $gfx = Get-CimInstance -Class Win32_VideoController | Select-Object Name, DriverVersion
    $gfxdriverfound = $false
    if ($gfx) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Video Controllers"
        foreach ($item in $gfx) {
            $gfxname = $item.Name
            $gfxdriver = $item.DriverVersion
            if ($gfxname -like "*radeon*" -or $gfxname -like "*nvidia*") { $gfxdriverfound = $true }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$gfxname" -Message3 "$gfxdriver"
        }
    }

    if (($script:vmsize -like "*NV*" -or $script:vmsize -like "*NC*") -and (-not $gfxdriverfound)) {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "The VM size is GPU optimized but could not find any AMD or NVidia drivers installed." -circle "red"
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Monitors"

    $Monitors = Get-WmiObject WmiMonitorID -Namespace root\wmi -ErrorAction Continue 2>>$global:msrdErrorLogFile
    if ($Monitors) {
        ForEach ($Monitor in $Monitors) {
            $Manufacturer = ($Monitor.ManufacturerName | Where-Object {$_ -ne 0} | ForEach-Object {[char]$_}) -join ""
            $Name = ($Monitor.UserFriendlyName | Where-Object {$_ -ne 0} | ForEach-Object {[char]$_}) -join ""
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$Manufacturer" -Message3 "$Name"
        }
    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Could not retrieve monitor information. See <a href='$msrdErrorfileurl' target='_blank'>MSRD-Collect-Error</a> for more information." -circle "red"
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdGetDispScale  #Get display scale

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Terminal Server Client\' -RegKey 'EnableAdvancedRemoteFXRemoteAppSupport'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Terminal Server Client\' -RegKey 'EnableAdvancedRemoteFXRemoteAppSupport'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\Client\' -RegKey 'EnableHardwareMode' -OptNote "Computer Policy: Do not allow hardware accelerated decoding"

    if (!($global:msrdSource)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"

        if ($script:GPUreq) {
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'bEnumerateHWBeforeSW' -RegValue '1' -OptNote 'Computer Policy: Use hardware graphics adapters for all Remote Desktop Services sessions' -warnMissing
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'AVCHardwareEncodePreferred' -RegValue '1' -OptNote 'Computer Policy: Configure H.264/AVC hardware encoding for Remote Desktop Connections' -warnMissing
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'AVC444ModePreferred' -RegValue '1' -OptNote 'Computer Policy: Prioritize H.264/AVC 444 graphics mode for Remote Desktop Connections' -warnMissing
        } else {
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'bEnumerateHWBeforeSW' -RegValue '1' -OptNote 'Computer Policy: Use hardware graphics adapters for all Remote Desktop Services sessions'
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'AVCHardwareEncodePreferred' -RegValue '1' -OptNote 'Computer Policy: Configure H.264/AVC hardware encoding for Remote Desktop Connections'
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'AVC444ModePreferred' -RegValue '1' -OptNote 'Computer Policy: Prioritize H.264/AVC 444 graphics mode for Remote Desktop Connections'
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fEnableWddmDriver' -OptNote 'Computer Policy: Use WDDM graphics display driver for Remote Desktop Connections'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fEnableRemoteFXAdvancedRemoteApp' -OptNote 'Computer Policy: Use advanced RemoteFX graphics for RemoteApp'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'MaxMonitors' -OptNote 'Computer Policy: Limit number of monitors'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'MaxXResolution' -OptNote 'Computer Policy: Limit maximum display resolution'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'MaxYResolution' -OptNote 'Computer Policy: Limit maximum display resolution'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\H264Encoding\' -RegKey 'EnableAlwaysChroma'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\' -RegKey 'DWMFRAMEINTERVAL'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\' -RegKey 'fEnableRemoteFXAdvancedRemoteApp'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\' -RegKey 'IgnoreClientDesktopScaleFactor'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'MaxMonitors'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'MaxXResolution'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'MaxYResolution'
    }

    if (($global:msrdAVD -or $global:msrdW365) -and !($global:msrdSource)) {
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\rdp-sxs\' -RegKey 'MaxMonitors'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\rdp-sxs\' -RegKey 'MaxXResolution'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\rdp-sxs\' -RegKey 'MaxYResolution'
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\RdpCloudStackSettings\' -RegKey 'RAILDVCActivateThreshold'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\RdpCloudStackSettings\' -RegKey 'AVCMaxChromaKeyFrameDistance'
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\SideBySide\' -RegKey 'PreferExternalManifest'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Display\' -RegKey 'DisableGdiDPIScaling' -OptNote 'Computer Policy: Turn off GdiDPIScaling for applications'
    msrdCheckRegKeyValue -RegPath 'HKCU:\Control Panel\Desktop\' -RegKey 'DesktopDPIOverride'
    msrdCheckRegKeyValue -RegPath 'HKCU:\Control Panel\Desktop\' -RegKey 'LogPixels'
    msrdCheckRegKeyValue -RegPath 'HKCU:\Control Panel\Desktop\' -RegKey 'UserPreferencesMask'
    msrdCheckRegKeyValue -RegPath 'HKCU:\Control Panel\Desktop\' -RegKey 'Win8DpiScaling'

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagActivation {

    #activation diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "OS Activation / Licensing"
    $menucatmsg = "System"
    msrdLogDiag $LogLevel.Normal -DiagTag "KMSCheck" -Message $menuitemmsg

    try {
        $activ = Get-CimInstance SoftwareLicensingProduct -Filter "ApplicationID = '55c92734-d682-4d71-983e-d6ec3f16059f'" -Property Name, Description, licensestatus -OperationTimeoutSec 30 -ErrorAction Stop | Where-Object licensestatus -eq 1
        if ($activ) {
            if (Test-Path ($global:msrdLogDir + $slmgrfile)) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "Product Name" -Message2 "$($activ.Name)" -Message3 "(See: <a href='$slmgrfile' target='_blank'>slmgr-dlv</a>)"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Product Name" -Message2 "$($activ.Name)"
            }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Product Description" -Message2 "$($activ.Description)"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Product Name" -Message2 "N/A"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Product Description" -Message2 "N/A"
        }
    } catch {
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_

        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "An error occurred while trying to retrieve SoftwareLicensingProduct information. See <a href='$msrdErrorfileurl' target='_blank'>MSRD-Collect-Error</a> for more information." -circle "red"
    }

    $kms = Get-CimInstance SoftwareLicensingService | Select-Object KeyManagementServiceMachine, KeyManagementServicePort, DiscoveredKeyManagementServiceMachineIpAddress -ErrorAction Continue 2>>$global:msrdErrorLogFile
    if ($kms) {
        if ($kms.KeyManagementServiceMachine) { $kmsurl = $kms.KeyManagementServiceMachine; $kmsurlcircle = "blue" } else { $kmsurl = "N/A"; $kmsurlcircle = "white" }
        if ($kms.DiscoveredKeyManagementServiceMachineIpAddress) { $kmsip = $kms.DiscoveredKeyManagementServiceMachineIpAddress; $kmsipcircle = "blue" } else { $kmsip = "N/A"; $kmsipcircle = "white" }
        if ($kms.KeyManagementServicePort) { $kmsport = $kms.KeyManagementServicePort; $kmsportcircle = "blue" } else { $kmsport = "N/A"; $kmsportcircle = "white" }
    } else {
        $kmsurl = "N/A"; $kmsurlcircle = "white"
        $kmsip = "N/A"; $kmsipcircle = "white"
        $kmsport = "N/A"; $kmsportcircle = "white"
    }
    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    if (Test-Path ($global:msrdLogDir + $kmsfile)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "KMS machine" -Message2 "$kmsurl" -Message3 "(See: <a href='$kmsfile' target='_blank'>KMS-Servers</a>)" -circle $kmsurlcircle
    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "KMS machine" -Message2 "$kmsurl" -circle $kmsurlcircle
    }
    if (($global:msrdOSVer -like "*virtu*") -and ($kmsurl -notlike "*kms.core.*")) {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "AVD multi-session OS requires Azure KMS for proper activation but you are using a different KMS server ($kmsurl)" -circle "red"
    }
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "KMS IP address" -Message2 "$kmsip" -circle $kmsipcircle
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "KMS port" -Message2 "$kmsport" -circle $kmsportcircle

    Try {
        if ($kmsurl -and ($kmsurl -ne "N/A")) {
            $kmsconTest = msrdTestTCP "$kmsurl" "$kmsport"
            if ($kmsconTest[0] -eq "True") {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Connection test for KMS server '$kmsurl' ($kmsip)" -Message2 "TCP $kmsport`: Reachable" -circle "green"
            } else {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Connection test for KMS server '$kmsurl' ($kmsip)" -Message2 "TCP $kmsport`: Not reachable" -circle "red"
            }
        }
    } Catch {
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_

        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
    }

    if (($global:msrdAVD -or $global:msrdW365) -and !($global:msrdSource)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        if ($global:msrdVmlictype -eq "Windows_Client") {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "License Type" -Message2 "$global:msrdVmlictype" -circle "green"
        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "License Type" -Message2 "$global:msrdVmlictype. This is not the expected license type for an AVD/W365 machine. See: $avdLicRef" -circle "red"
        }
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagSSLTLS {

    #SSL/TLS diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "SSL / TLS"
    $menucatmsg = "System"
    msrdLogDiag $LogLevel.Normal -DiagTag "SSLCheck" -Message $menuitemmsg

    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002\' -RegKey 'Functions' -addWarning
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010002\' -RegKey 'EccCurves' -addWarning
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Cryptography\Configuration\SSL\00010003\' -RegKey 'Functions' -addWarning

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v2.0.50727\' -RegKey 'SchUseStrongCrypto' -RegValue '1'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v2.0.50727\' -RegKey 'SystemDefaultTlsVersions' -RegValue '1'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319\' -RegKey 'SchUseStrongCrypto' -RegValue '1'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319\' -RegKey 'SystemDefaultTlsVersions' -RegValue '1'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v2.0.50727\' -RegKey 'SchUseStrongCrypto' -RegValue '1'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v2.0.50727\' -RegKey 'SystemDefaultTlsVersions' -RegValue '1'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319\' -RegKey 'SchUseStrongCrypto' -RegValue '1'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319\' -RegKey 'SystemDefaultTlsVersions' -RegValue '1'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client\' -RegKey 'Enabled'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client\' -RegKey 'DisabledByDefault'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server\' -RegKey 'Enabled'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server\' -RegKey 'DisabledByDefault'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client\' -RegKey 'Enabled'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client\' -RegKey 'DisabledByDefault'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server\' -RegKey 'Enabled'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server\' -RegKey 'DisabledByDefault'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client\' -RegKey 'Enabled'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client\' -RegKey 'DisabledByDefault'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server\' -RegKey 'Enabled'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server\' -RegKey 'DisabledByDefault'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client\' -RegKey 'Enabled' -RegValue '1'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client\' -RegKey 'DisabledByDefault' -RegValue '0'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server\' -RegKey 'Enabled' -RegValue '1'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server\' -RegKey 'DisabledByDefault' -RegValue '0'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client\' -RegKey 'Enabled'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client\' -RegKey 'DisabledByDefault'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server\' -RegKey 'Enabled'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server\' -RegKey 'DisabledByDefault'

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagUAC {

    #User Access Control diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "User Account Control"
    $menucatmsg = "System"
    msrdLogDiag $LogLevel.Normal -DiagTag "UACCheck" -Message $menuitemmsg

    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -RegKey 'EnableLUA' -RegValue '1' -OptNote 'Computer Policy: User Account Control: Run all administrators in Admin Approval Mode'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -RegKey 'PromptOnSecureDesktop' -RegValue '1' -OptNote 'Computer Policy: User Account Control: Switch to the secure desktop when prompting for elevation'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -RegKey 'ConsentPromptBehaviorAdmin' -RegValue '5' -OptNote 'Computer Policy: User Account Control: Behavior of the elevation prompt for administrators in Admin Approval Mode'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -RegKey 'ConsentPromptBehaviorUser' -RegValue '3' -OptNote 'Computer Policy: User Account Control: Behavior of the elevation prompt for standard users'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -RegKey 'EnableUIADesktopToggle' -RegValue '0' -OptNote 'Computer Policy: User Account Control: Allow UIAccess applications to prompt for elevation without using the secure desktop'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -RegKey 'EnableInstallerDetection' -OptNote 'Computer Policy: User Account Control: Detect application installations and prompt for elevation'

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagInstaller {

    #Windows Installer diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Windows Installer"
    $menucatmsg = "System"
    msrdLogDiag $LogLevel.Normal -DiagTag "InstallerCheck" -Message $menuitemmsg

    msrdCheckServicePort -service msiserver

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdCheckRegKeyValue -RegPath 'HKLM:\Software\Policies\Microsoft\Windows\Installer\' -RegKey 'disablemsi' -OptNote 'Computer Policy: Turn off Windows Installer'
    msrdCheckRegKeyValue -RegPath 'HKLM:\Software\Policies\Microsoft\Windows\Installer\' -RegKey 'Logging'

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagSearch {

    #Windows Search diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Windows Search"
    $menucatmsg = "System"
    msrdLogDiag $LogLevel.Normal -DiagTag "SearchCheck" -Message $menuitemmsg

    msrdCheckServicePort -service wsearch

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows Search\' -RegKey 'EnablePerUserCatalog'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Apps\' -RegKey 'RoamSearch'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'RoamSearch'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC\' -RegKey 'RoamSearch'

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagWU {

    #Windows Update diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Windows Update"
    $menucatmsg = "System"
    msrdLogDiag $LogLevel.Normal -DiagTag "WUCheck" -Message $menuitemmsg

    if (Test-Path ($global:msrdLogDir + $updhistfile)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "OS Build" -Message2 ($global:WinVerMajor + "." + $global:WinVerMinor + "." + $global:WinVerBuild + "." + $global:WinVerRevision) -Message3 "(See: <a href='$updhistfile' target='_blank'>UpdateHistory</a>)"
    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "OS Build" -Message2 ($global:WinVerMajor + "." + $global:WinVerMinor + "." + $global:WinVerBuild + "." + $global:WinVerRevision)
    }

    $unsupportedMsg = "This OS version is no longer supported. Upgrade the OS to a supported version. See: {0}"

    if (($global:WinVerMajor -like "*10*") -and (@("10240", "10586", "14393", "15063", "16299", "17134", "17763", "18362", "18363", "19041", "19042", "19043") -contains $global:WinVerBuild) -and !($global:msrdOSVer -like "*Server*")) {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1
        $ref = switch -Wildcard ($global:msrdOSVer) {
            "*Pro*" { $w10proRef }
            "*Home*" { $w10proRef }
            "*Enterprise*" { $w10entRef }
            "*Education*" { $w10entRef }
        }
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 ($unsupportedMsg -f $ref) -circle "red"
    }

    if (($global:msrdOSVer -like "*Server 2008 R2*") -or ($global:msrdOSVer -like "*Server 2012 R2*")) {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        $ref = switch -Wildcard ($global:msrdOSVer) {
            "*Server 2008 R2*" { $w2008r2Ref }
            "*Server 2012 R2*" { $w2012r2Ref }
        }
        if (($global:msrdOSVer -like "*2012 R2*") -and ($global:msrdAVD)) {
            $unsupportedMsg += " See the list of supported OS for AVD: $avdOSRef"
        }
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 ($unsupportedMsg -f $ref) -circle "red"
    }

    if (($global:WinVerMajor -like "*10*") -and (@("19044", "22000") -contains $global:WinVerBuild) -and (($global:msrdOSVer -like "*Pro*") -or ($global:msrdOSVer -like "*Home*"))) {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1
        $ref = switch -Wildcard ($global:msrdOSVer) {
            "*Pro*" { $w10proRef }
            "*Home*" { $w10proRef }
        }
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 ($unsupportedMsg -f $ref) -circle "red"
    }

    $osLanguage = (Get-CimInstance -ClassName Win32_OperatingSystem).OSLanguage
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "OS Language" -Message2 $osLanguage
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"

    Try {
        $session = New-Object -ComObject "Microsoft.Update.Session"
        $searcher = $session.CreateUpdateSearcher()
	} Catch {
        msrdLogMessage $LogLevel.Error ("Error collecting updates information from Microsoft.Update.Session" + $_.Exception.Message)
    }

    #get latest install Windows Update if OS is English
        if ($osLanguage -eq "1033") {
            try {
                $historyCount = $searcher.GetTotalHistoryCount()
            } catch {
                $historyCount = 0
                $failedCommand = $_.InvocationInfo.Line.TrimStart()
                msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
            }

            if ($historyCount -gt 0) {
                $history = $searcher.QueryHistory(0, $historyCount)
                $monthlyUpdatesInstalled = $history | Where-Object { ($_.Title -like "*Monthly Rollup*" -or $_.Title -like "*Quality Rollup*" -or $_.Title -like "*Cumulative Update*System*") -and $_.Title -notlike "*.NET Framework*" -and $_.HResult -eq 0 }
                $latestInstalledUpdate = $monthlyUpdatesInstalled | Sort-Object -Property Date | Select-Object -Last 1
            } else {
                $latestInstalledUpdate = $null
            }

            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Latest Installed Monthly Rollup/Cumulative Update for Windows"
            if ($null -ne $latestInstalledUpdate) {
                $latestInstalledTitle = $latestInstalledUpdate.Title -replace '\s\(KB\d+\)$'
                $latestInstalledKB = [regex]::Match($latestInstalledUpdate.Title, '\(KB(\d+)\)').Groups[1].Value
                $latestInstalledDate = $latestInstalledUpdate.Date
                $latestInstalledUrl = $latestInstalledUpdate.SupportUrl

                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$latestInstalledTitle" -Message3 "KB: <a href='$latestInstalledUrl' target='_blank'>$latestInstalledKB</a> (Installed on: $latestInstalledDate)" -circle "blue"
            } else {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "No Monthly Rollup/Cumulative Updates found on your machine." -circle "red"
            }
        } else {
            $latestInstalledUpdate = $null
        }

    #get latest available Windows Update online
    try {
        $resultAvailable = $searcher.Search("Type='Software'")
        $monthlyUpdatesAvailable = $resultAvailable.Updates | Where-Object { ($_.Title -like "*Monthly Rollup*" -or $_.Title -like "*Quality Rollup*" -or $_.Title -like "*Cumulative Update*System*") -and $_.Title -notlike '*.NET Framework*' }
        $latestAvailableUpdate = $monthlyUpdatesAvailable | Sort-Object -Property LastDeploymentChangeTime | Select-Object -Last 1
    } catch {
        $latestAvailableUpdate = $null
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Latest Available Monthly Rollup/Cumulative Update for Windows"
    if ($null -ne $latestAvailableUpdate) {
        $latestAvailableTitle = $latestAvailableUpdate.Title -replace '\s\(KB\d+\)$'
        $latestAvailableKB = $latestAvailableUpdate.KBArticleIDs[0]
        $latestAvailableUrl = $latestAvailableUpdate.SupportUrl

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$latestAvailableTitle" -Message3 "KB: <a href='$latestAvailableUrl' target='_blank'>$latestAvailableKB</a>" -circle "blue"
    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "Could not retrieve information on the latest Monthly Rollup/Cumulative Update available online. You may have limited or no internet access. Make sure the system is fully updated." -circle "red"
    }

    $showUpdatesURL = $false
    if (($null -ne $latestInstalledUpdate) -and ($null -ne $latestAvailableUpdate)) {
        if ($latestInstalledUpdate.Date -lt $latestAvailableUpdate.LastDeploymentChangeTime) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "The latest installed Monthly Rollup/Cumulative Update on this machine is older than the latest Monthly Rollup/Cumulative Update available online. Please consider updating the OS." -circle "red"
            $showUpdatesURL = $true
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "You have the latest available Monthly Rollup/Cumulative Update installed." -circle "green"
        }
    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Verify if you have the latest Monthly Rollup/Cumulative Update installed." -circle "blue"
        $showUpdatesURL = $true
    }

    if ($showUpdatesURL -and (-not $global:msrdLiveDiag)) {
        if ($global:WinVerMajor -like "*10*") {
            $buildlist = @{
                "14393" = "<a href='https://support.microsoft.com/en-us/help/4000825' target='_blank'>Windows 10 and Windows Server 2016 update history</a>"
                "17763" = "<a href='https://support.microsoft.com/en-us/help/4464619' target='_blank'>Windows 10 and Windows Server 2019 update history</a>"
                "19044" = "<a href='https://support.microsoft.com/en-us/help/5008339' target='_blank'>Windows 10, version 21H2 update history</a>"
                "20348" = "<a href='https://support.microsoft.com/en-us/help/5005454' target='_blank'>Windows Server 2022 update history</a>"
                "22000" = "<a href='https://support.microsoft.com/en-us/help/5006099' target='_blank'>Windows 11, version 21H2 update history</a>"
                "22621" = "<a href='https://support.microsoft.com/en-us/help/5018680' target='_blank'>Windows 11, version 22H2 update history</a>"
                "22631" = "<a href='https://support.microsoft.com/en-us/help/5031682' target='_blank'>Windows 11, version 23H2 update history</a>"
            }

            foreach ($buildver in $buildlist.GetEnumerator()) {
                $buildnr = $buildver.Key
                $PatchURL = $buildver.Value

                if ($global:WinVerBuild -like "*$buildnr*") {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
                    $PatchHistory = "Check $PatchURL for more information on the available updates for this OS build."
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$PatchHistory" -circle "blue"
                }
            }
        }
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\' -RegKey 'WUServer' -OptNote 'Computer Policy: Specify intranet Microsoft update service location'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\' -RegKey 'WUStatusServer' -OptNote 'Computer Policy: Specify intranet Microsoft update service location'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\' -RegKey 'NoAutoUpdate' -OptNote 'Computer Policy: Configure Automatic Updates'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\' -RegKey 'AUOptions' -OptNote 'Computer Policy: Configure Automatic Updates'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\' -RegKey 'UseWUServer'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\' -RegKey 'RebootInProgress'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\' -RegKey 'RebootPending'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\' -RegKey 'RebootRequired'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\' -RegKey 'PostRebootReporting'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\' -RegKey 'IsOOBEInProgress'

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagWinRMPS {

    #WinRM/PowerShell diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "WinRM / PowerShell"
    $menucatmsg = "System"
    msrdLogDiag $LogLevel.Normal -DiagTag "WinRMPSCheck" -Message $menuitemmsg

    msrdCheckServicePort -service WinRM

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"

    if (Test-Path ($global:msrdLogDir + $winrmcfgfile)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "WinRM Configuration" -Message2 "(See: <a href='$winrmcfgfile' target='_blank'>WinRM-Config</a>)" -circle "blue"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    }

    $servstatus = (Get-CimInstance Win32_Service -Filter "name = 'WinRM'" -ErrorAction SilentlyContinue).State
    if ($servstatus -eq "Running") {
        $ipfilter = Get-Item WSMan:\localhost\Service\IPv4Filter
        if ($ipfilter.Value) {
            if ($ipfilter.Value -eq "*") {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "IPv4Filter" -Message2 "*" -circle "green"
            } else {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "IPv4Filter" -Message2 "$($ipfilter.Value)" -circle "red"
            }
        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "IPv4Filter" -Message2 "Empty value, WinRM will not listen on IPv4." -circle "red"
        }

        $ipfilter = Get-Item WSMan:\localhost\Service\IPv6Filter
        if ($ipfilter.Value) {
            if ($ipfilter.Value -eq "*") {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "IPv6Filter" -Message2 "*" -circle "green"
            } else {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "IPv6Filter" -Message2 "$($ipfilter.Value)" -circle "red"
            }
        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "IPv6Filter" -Message2 "Empty value, WinRM will not listen on IPv6." -circle "red"
        }
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    $fwrules5 = (Get-NetFirewallPortFilter -Protocol TCP | Where-Object { $_.localport -eq '5985' } | Get-NetFirewallRule)
    if ($fwrules5.count -eq 0) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Windows Firewall rule(s) for TCP port 5985" -Message2 "not found"
    } else {
        if (Test-Path ($global:msrdLogDir + $fwrfile)) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Windows Firewall rule(s) for TCP port 5985" -Message2 "found (See: <a href='$fwrfile' target='_blank'>FirewallRules</a>)" -circle "blue"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Windows Firewall rule(s) for TCP port 5985" -Message2 "found" -circle "blue"
        }
    }


    $fwrules6 = (Get-NetFirewallPortFilter -Protocol TCP | Where-Object { $_.localport -eq '5986' } | Get-NetFirewallRule)
    if ($fwrules6.count -eq 0) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Windows Firewall rule(s) for TCP port 5986" -Message2 "not found"
    } else {
        if (Test-Path $fwrfile) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Windows Firewall rule(s) for TCP port 5986" -Message2 "found (See: <a href='$fwrfile' target='_blank'>FirewallRules</a>)" -circle "blue"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Windows Firewall rule(s) for TCP port 5986" -Message2 "found" -circle "blue"
        }
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    if ($isDomain) {
        $DSsearch = New-Object DirectoryServices.DirectorySearcher([ADSI]"")
        $DSsearch.filter = "(samaccountname=WinRMRemoteWMIUsers__)"
        try {
            $results = $DSsearch.Findall()
        } catch {
            $failedCommand = $_.InvocationInfo.Line.TrimStart()
            msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
        }

        if ($results.count -gt 0) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Found $($results.Properties.distinguishedname)" -circle "green"
            if ($results.Properties.grouptype -eq  -2147483644) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "WinRMRemoteWMIUsers__ is a Domain local group." -circle "green"
            } elseif ($results.Properties.grouptype -eq -2147483646) {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "WinRMRemoteWMIUsers__ is a Global group." -circle "red"
            } elseif ($results.Properties.grouptype -eq -2147483640) {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "WinRMRemoteWMIUsers__ is a Universal group." -circle "red"
            }
            if (get-ciminstance -query "select * from Win32_Group where Name = 'WinRMRemoteWMIUsers__' and Domain = '$env:computername'") {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "The group WinRMRemoteWMIUsers__ is also present as machine local group." -circle "green"
            }
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "The WinRMRemoteWMIUsers__ was not found in the domain."
            if (get-ciminstance -query "select * from Win32_Group where Name = 'WinRMRemoteWMIUsers__' and Domain = '$env:computername'") {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "The group WinRMRemoteWMIUsers__ is present as machine local group." -circle "green"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "WinRMRemoteWMIUsers__ group was not found as machine local group."
            }
        }
    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "This machine is not joined to a domain." -circle "red"
        if (get-ciminstance -query "select * from Win32_Group where Name = 'WinRMRemoteWMIUsers__' and Domain = '$env:computername'") {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "The group WinRMRemoteWMIUsers__ is present as machine local group." -circle "green"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "WinRMRemoteWMIUsers__ group was not found as machine local group."
        }
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service\WinRS\' -RegKey 'AllowRemoteShellAccess' -OptNote 'Computer Policy: Allow Remote Shell Access'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Services\HTTP\Parameters\' -RegKey 'MaxRequestBytes'

    #security protocol
    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    $secprot = [System.Net.ServicePointManager]::SecurityProtocol
    if ($secprot) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "[Net.ServicePointManager]::SecurityProtocol" -Message2 "$secprot" -circle "blue"
    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "[Net.ServicePointManager]::SecurityProtocol" -Message2 "not found" -circle "blue"
    }

    #powershell
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    $PSlock = $ExecutionContext.SessionState.LanguageMode
    if ($PSlock -eq "FullLanguage") {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "PowerShell" -Message2 "Running Mode" -Message3 "$PSlock" -circle "green"
    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "PowerShell" -Message2 "Running Mode" -Message3 "$PSlock" -circle "red"
    }

    $pssexec = Get-ExecutionPolicy -List
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Execution policies"
    foreach ($entrypss in $pssexec) {
        $mode = $entrypss.ExecutionPolicy
        if ($mode -like "*Undefined*") {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($entrypss.Scope)" -Message3 "$mode"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($entrypss.Scope)" -Message3 "$mode" -circle "blue"
        }
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Modules"
    $instmodulelist = "Az.Accounts", "Az.Resources", "Az.DesktopVirtualization", "Microsoft.RDInfra.RDPowerShell"
    $instmodulelist | ForEach-Object -Process {
        $instmod = Get-InstalledModule -Name $_ -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        if ($instmod) {
            $instmodver = [string]$instmod.Version
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$_" -Message3 "$instmodver" -circle "blue"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$_" -Message3 "not found"
        }
    }

    $modulelist = "PowerShellGet", "PSReadLine"
    $modulelist | ForEach-Object -Process {
        $mod = Get-Module -Name $_ -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        if ($mod) {
            $modver = [string]$mod.Version
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$_" -Message3 "$modver" -circle "blue"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$_" -Message3 "not found"
        }
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

#endregion System diag functions


#region AVD/RDS diag functions

Function msrdDiagRedirection {

    #RD Redirection diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Device and Resource Redirection"
    $menucatmsg = $script:msrdMenuCat
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "RedirCheck"

    #client side redirections
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Terminal Server Client\' -RegKey 'DisableClipboardRedirection' -RegValue '0'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Terminal Server Client\' -RegKey 'DisableClipboardRedirection' -RegValue '0'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Terminal Server Client\' -RegKey 'DisableDriveRedirection' -RegValue '0'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Terminal Server Client\' -RegKey 'DisablePrinterRedirection' -RegValue '0'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Terminal Server Client\' -RegKey 'DisablePrinterRedirection' -RegValue '0'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Terminal Server Client\' -RegKey 'DisableWebAuthnRedirection'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fUsbRedirectionEnableMode' -OptNote 'Computer Policy: Allow RDP redirection of other supported RemoteFX USB devices from this computer'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"

    #host side redirections
    if (!($global:msrdSource)) {
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fDisableAudioCapture' -RegValue '0' -OptNote 'Computer Policy: Allow audio recording redirection'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fDisableCam' -RegValue '0' -OptNote 'Computer Policy: Allow audio and video playback redirection'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fDisableCameraRedir' -RegValue '0' -OptNote 'Computer Policy: Do not allow video capture redirection'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fDisableCcm' -RegValue '0' -OptNote 'Computer Policy: Do not allow COM port redirection'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fDisableCdm' -RegValue '0' -OptNote 'Computer Policy: Do not allow drive redirection'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fDisableClip' -RegValue '0' -OptNote 'Computer Policy: Do not allow clipboard redirection'
        msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fDisableClip' -RegValue '0' -OptNote 'User Policy: Do not allow clipboard redirection'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fDisableCpm' -RegValue '0' -OptNote 'Computer Policy: Do not allow client printer redirection'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fDisableLPT' -RegValue '0' -OptNote 'Computer Policy: Do not allow LPT port redirection'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fDisablePNPRedir' -RegValue '0' -OptNote 'Computer Policy: Do not allow supported Plug and Play device redirection'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fDisableWebAuthn' -RegValue '0' -OptNote 'Computer Policy: Do not allow WebAuthn redirection'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fEnableSmartCard' -RegValue '1' -OptNote 'Computer Policy: Do not allow smart card device redirection'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fEnableTimeZoneRedirection' -OptNote 'Computer Policy: Allow time zone redirection'
        msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fEnableTimeZoneRedirection' -OptNote 'User Policy: Allow time zone redirection'

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -RegKey 'fEnableSmartCard'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'fDisableAudioCapture' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'fDisableCam' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'fDisableCcm' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'fDisableCdm' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'fDisableClip' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'fDisableCpm' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'fDisableLPT' -RegValue '0'

        if ($global:msrdAVD -or $global:msrdW365) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
            if ($avdcheck) {
                $listenerregpath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\" + $script:msrdListenervalue + "\"
                msrdCheckRegKeyValue -RegPath $listenerregpath -RegKey 'fDisableAudioCapture' -RegValue '0'
                msrdCheckRegKeyValue -RegPath $listenerregpath -RegKey 'fDisableCam' -RegValue '0'
                msrdCheckRegKeyValue -RegPath $listenerregpath -RegKey 'fDisableCcm' -RegValue '0'
                msrdCheckRegKeyValue -RegPath $listenerregpath -RegKey 'fDisableCdm' -RegValue '0'
                msrdCheckRegKeyValue -RegPath $listenerregpath -RegKey 'fDisableClip' -RegValue '0'
                msrdCheckRegKeyValue -RegPath $listenerregpath -RegKey 'fDisableCpm' -RegValue '0'
                msrdCheckRegKeyValue -RegPath $listenerregpath -RegKey 'fDisableLPT' -RegValue '0'
            } else {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$avdcheckmsg" -circle "red"
            }
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout\' -RegKey 'IgnoreRemoteKeyboardLayout'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\I/O System\' -RegKey 'IoEnableSessionZeroAccessCheck' -RegValue '1'
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdTestAVExclusion {
    Param([string]$ExclPath, [array]$ExclValue, $Scope)

    #Antivirus Exclusion diagnostics
    if (Test-Path $ExclPath) {
        if ((Get-Item $ExclPath).Property) {
            $msgpath = Compare-Object -ReferenceObject(@((Get-Item $ExclPath).Property)) -DifferenceObject(@($ExclValue))

            if ($msgpath) {
                $valueNotConf = ($msgpath | Where-Object {$_.SideIndicator -eq '=>'}).InputObject
                $valueNotRec = ($msgpath | Where-Object {$_.SideIndicator -eq '<='}).InputObject

                if ($valueNotConf) {
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "The following recommended $Scope exclusions are not configured" -circle "red"
                    foreach ($entryNC in $valueNotConf) {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "$entryNC" -circle "red"
                    }
                } else {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "The recommended $Scope exclusions are configured" -circle "green"
                }

                if ($valueNotRec) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "The following values are configured but are not part of the public list of recommended exclusions for $Scope" -circle "blue"
                    foreach ($entryNR in $valueNotRec) {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "$entryNR" -circle "blue"
                    }
                }

            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "No differences found between the recommended and configured exclusions for $Scope" -circle "green"
            }

        } else {
            if (($Scope -eq "FSLogix") -and (((msrdTestRegistryValue -path "HKLM:\SOFTWARE\FSLogix\Profiles" -value "Enabled") -eq 1) -or ((msrdTestRegistryValue -path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC" -value "Enabled") -eq 1))) {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "No '$ExclPath' exclusions have been found" -circle "red"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "No '$ExclPath' exclusions have been found" -circle "blue"
            }
        }

    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "'$ExclPath' <span style='color: brown'>not found</span>" -circle "blue"
    }
}

Function msrdDiagFSLogix {

    #FSLogix diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "FSLogix"
    $menucatmsg = $script:msrdMenuCat
    msrdLogDiag $LogLevel.Normal -DiagTag "ProfileCheck" -Message $menuitemmsg

    $cmd = "$env:ProgramFiles\fslogix\apps\frx.exe"

    if (Test-path -path "$env:ProgramFiles\FSLogix\apps") {

        msrdCheckServicePort -service frxsvc -stopWarning
        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        msrdCheckServicePort -service frxccds

        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"

        if (Test-Path -path $cmd) {
            $cmdout = & $cmd version
            $cmdout | ForEach-Object -Process {
                $fsv1 = $_.Split(":")[0]
                $fsv2 = $_.Split(":")[-1]
                if ($fsv2 -like "*unknown*") {
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message $fsv1 -Message2 "unknown" -circle "red"
                } else {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message $fsv1 -Message2 "$fsv2" -circle "blue"
                }

                if ($fsv1 -like "Service*") {
                    if ($fsv2 -like "*unknown*") {
                        $script:frxverstrip = "unknown"
                    } else {
                        [int64]$script:frxverstrip = $fsv2.Replace(".","")
                    }
                }
            }
            if (($script:frxverstrip -lt $latestFSLogixVer) -and (!($script:frxverstrip -eq "unknown"))) {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "You are not using the latest available FSLogix release. Please consider updating. See: $fslogixRef" -circle "red"
            } elseif ($script:frxverstrip -eq "unknown") {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Could not retrieve all FSLogix version information" -circle "red"
            }

        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -Message "FSLogix seems to be installed, but $cmd could not be found" -col 3 -circle "red"
        }

        #profile container
        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        if (Test-Path -Path ($global:msrdLogDir + $fslogixfolder) -PathType Container) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "<b>Profile container</b>" -Message2 "(See: <a href='$fslogixfolder' target='_blank'>FSLogix logs</a>)"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "<b>Profile container</b>"
        }

        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'Enabled' -RegValue '1'

        if (!(msrdTestRegistryValue -path "HKLM:\SOFTWARE\FSLogix\Profiles\" -value "Enabled")) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "FSLogix <span style='color: blue'>Profile</span> Container 'Enabled' reg key <span style='color: brown'>not found</span>. Profile Container is not enabled." -circle "blue"
        }

        if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\FSLogix\Profiles\" -value "VHDLocations") {
            $pvhd = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\FSLogix\Profiles\" -name "VHDLocations"

            $var1P = $pvhd -split ";"
            $var2P = foreach ($varItemP in $var1P) {
                        if ($varItemP -like "AccountName=*") { $varItemP = "AccountName=xxxxxxxxxxxxxxxx"; $varItemP }
                        elseif ($varItemP -like "AccountKey=*") { $varItemP = "AccountKey=xxxxxxxxxxxxxxxx"; $varItemP }
                        else { $varItemP }
                    }
            $var3P = $var2P -join ";"
            $pvhd = $var3P

            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "HKLM:\SOFTWARE\FSLogix\Profiles\<span style='color: blue'>VHDLocations</span>" -Message2 "$pvhd" -circle "blue"

            $pconPath = $pvhd.split("\")[2]
            if ($pconPath) {
                $pconout = msrdTestTCP $pconPath 445
                if ($pconout[0] -eq "True") {
                    if ($pconout[1]) {
                        $pconip = $pconout[1]
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Connection test for Profile storage location '$pconPath' ($pconip)" -Message2 "TCP 445: Reachable" -circle "green"
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Connection test for Profile storage location '$pconPath'" -Message2 "TCP 445: Reachable" -circle "green"
                    }
                }
                if ($pconout.PingSucceeded) {
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Connection test for Profile storage location '$pconPath'" -Message2 "TCP 445: Not reachable" -circle "red"
                }
            }
        } else {
            if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\FSLogix\Profiles\" -value "Enabled") {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "HKLM:\SOFTWARE\FSLogix\Profiles\<span style='color: blue'>VHDLocations</span>" -Message2 "not found" -circle "red"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "HKLM:\SOFTWARE\FSLogix\Profiles\<span style='color: blue'>VHDLocations</span>" -Message2 "not found"
            }
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'CCDLocations' -skipValue

        if ((msrdTestRegistryValue -path "HKLM:\SOFTWARE\FSLogix\Profiles\" -value "VHDLocations") -and (msrdTestRegistryValue -path "HKLM:\SOFTWARE\FSLogix\Profiles\" -value "CCDLocations")) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Both Profile VHDLocations and Profile Cloud Cache CCDLocations reg keys are present. If you want to use Profile Cloud Cache, remove any setting for Profile 'VHDLocations'. See: $cloudcacheRef" -circle "red"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        }

        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'ConcurrentUserSessions' -RegValue '0' -OptNote 'Computer Policy: Allow concurrent user sessions'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'DeleteLocalProfileWhenVHDShouldApply' -RegValue '1' -OptNote 'Computer Policy: Delete local profile when FSLogix Profile should apply'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'SizeInMBs' -RegValue '30000' -OptNote 'Computer Policy: Size in MBs'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'VolumeType' -RegValue 'VHDX' -OptNote 'Computer Policy: Virtual disk type'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'FlipFlopProfileDirectoryName' -RegValue '1' -OptNote 'Computer Policy: Swap directory name components'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'InstallAppxPackages'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'LockedRetryCount' -RegValue '3'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'LockedRetryInterval' -RegValue '15'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'NoProfileContainingFolder' -RegValue '0' -OptNote 'Computer Policy: No containing folder'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'OutlookCachedMode' -OptNote 'Computer Policy: Set Outlook cached mode on successful container attach'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'ProfileType' -RegValue '0' -OptNote 'Computer Policy: Profile type'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'ReAttachIntervalSeconds' -RegValue '15'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'ReAttachRetryCount' -RegValue '3'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'RebootOnUserLogoff' -RegValue '0' -OptNote 'Computer Policy: Reboot computer when user logs off'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'RedirectType' -RegValue '2'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'RedirXMLSourceFolder' -OptNote 'Computer Policy: Provide RedirXML file to customize redirections'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'RoamSearch'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'ShutdownOnUserLogoff' -RegValue '0' -OptNote 'Computer Policy: Shutdown computer when user logs off'

        #office container
        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "<b>Office container</b>"

        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC\' -RegKey 'Enabled'

        if (!(msrdTestRegistryValue -path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC\" -value "Enabled")) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "FSLogix <span style='color: blue'>Office</span> Container 'Enabled' reg key <span style='color: brown'>not found</span>. Office Container is not enabled." -circle "blue"
        }

        if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC\" -value "VHDLocations") {
            $ovhd = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC\" -name "VHDLocations"

            $var1O = $ovhd -split ";"
            $var2O = foreach ($varItemO in $var1O) {
                        if ($varItemO -like "AccountName=*") { $varItemO = "AccountName=xxxxxxxxxxxxxxxx"; $varItemO }
                        elseif ($varItemO -like "AccountKey=*") { $varItemO = "AccountKey=xxxxxxxxxxxxxxxx"; $varItemO }
                        else { $varItemO }
                    }
            $var3O = $var2O -join ";"
            $ovhd = $var3O

            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "HKLM:\SOFTWARE\Policies\FSLogix\ODFC\<span style='color: blue'>VHDLocations</span>" -Message2 "$ovhd" -circle "blue"

            $oconPath = $ovhd.split("\")[2]
            if ($oconPath) {
                $oconout = msrdTestTCP $oconPath 445
                if ($oconout[0] -eq "True") {
                    if ($oconout[1]) {
                        $oconip = $oconout[1]
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Connection test for ODFC storage location '$oconPath - $oconip'" -Message2 "TCP 445: Reachable" -circle "green"
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Connection test for ODFC storage location '$oconPath'" -Message2 "TCP 445: Reachable" -circle "green"
                    }
                }
                if ($oconout.PingSucceeded) {
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Connection test for ODFC storage location '$oconPath'" -Message2 "TCP 445: Not reachable" -circle "red"
                }
            }
        } else {
            if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC\" -value "Enabled") {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "HKLM:\SOFTWARE\Policies\FSLogix\ODFC\<span style='color: blue'>VHDLocations</span>" -Message2 "not found" -circle "red"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "HKLM:\SOFTWARE\Policies\FSLogix\ODFC\<span style='color: blue'>VHDLocations</span>" -Message2 "not found"
            }
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC\' -RegKey 'CCDLocations' -skipValue

        if ((msrdTestRegistryValue -path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC\" -value "VHDLocations") -and (msrdTestRegistryValue -path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC\" -value "CCDLocations")) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Both Office VHDLocations and Office Cloud Cache CCDLocations reg keys are present. If you want to use Office Cloud Cache, remove any setting for Office 'VHDLocations'. See: $cloudcacheRef" -circle "red"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        }

        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC\' -RegKey 'IncludeOfficeActivation' -OptNote 'Computer Policy: Include Office activation data in container'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC\' -RegKey 'DeleteLocalProfileWhenVHDShouldApply' -RegValue '1' -OptNote 'Computer Policy: Delete local profile when FSLogix Profile should apply'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC\' -RegKey 'SizeInMBs' -RegValue '30000' -OptNote 'Computer Policy: Size in MBs'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC\' -RegKey 'VolumeType' -RegValue 'VHDX' -OptNote 'Computer Policy: Virtual dksik type'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC\' -RegKey 'FlipFlopProfileDirectoryName' -RegValue '1' -OptNote 'Computer Policy: Swap directory name components'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC\' -RegKey 'NoProfileContainingFolder' -RegValue '0' -OptNote 'Computer Policy: No containing folder'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC\' -RegKey 'OutlookCachedMode' -OptNote 'Computer Policy: Set Outlook cached mode on successful container attach'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC\' -RegKey 'VHDAccessMode' -OptNote 'Computer Policy: VHD access type'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC\' -RegKey 'RoamSearch'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Office\16.0\outlook\ost\' -RegKey 'NoOST' -OptNote 'Computer Policy: Do not allow an OST file to be created'

        #apps & other
        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "<b>Other relevant settings</b>"
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'LoggingEnabled' -RegValue '2'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'LogDir' -RegValue '%ProgramData%\FSLogix\Logs'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'LogFileKeepingPeriod' -RegValue '2'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'LoggingLevel' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'ConfigTool' -RegValue '1'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'IEPlugin' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'RuleEditor' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'JavaRuleEditor' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'Service' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'Profile' -RegValue '1'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'FrxLauncher' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'ODFC' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'RuleCompilation' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'Font' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'Network' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'Printer' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'AdsComputerGroup' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'DriverInterface' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'Search' -RegValue '1'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'SearchPlugin' -RegValue '0'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Logging\' -RegKey 'ProcessStart' -RegValue '0'

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Apps\' -RegKey 'CleanupInvalidSessions' -RegValue '1'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Apps\' -RegKey 'RoamRecycleBin'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Apps\' -RegKey 'RoamSearch'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Apps\' -RegKey 'VHDCompactDisk'

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\' -RegKey 'SpecialRoamingOverrideAllowed'
        msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\' -RegKey 'DisablePersonalDirChange' -addWarning
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos\Parameters\' -RegKey 'CloudKerberosTicketRetrievalEnabled' -OptNote 'Computer Policy: Allow retrieving the Microsoft Entra Kerberos Ticket Granting Ticket during logon'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos\Parameters\' -RegKey 'SupportedEncryptionTypes' -OptNote 'Computer Policy: Network security: Configure encryption types allowed for Kerberos' '' -addWarning
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\AzureADAccount\' -RegKey 'LoadCredKeyFromProfile'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters\' -RegKey 'CloudKerberosTicketRetrievalEnabled' -OptNote 'Computer Policy: Allow retrieving the Microsoft Entra Kerberos Ticket Granting Ticket during logon'

        #AV exclusions
        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        if (Test-Path ($global:msrdLogDir + $regDefExclFile)) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "<b>Windows Defender antivirus exclusions</b> ($avexRef)" -Message2 "(See: <a href='$regDefExclFile' target='_blank'>Defender Exclusions</a>)" -circle "blue"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "<b>Windows Defender antivirus exclusions</b> ($avexRef)"
        }

        #checking for actual Profiles VHDLocations value
        $pVHDpath = "HKLM:\SOFTWARE\FSLogix\Profiles\"
        $pVHDkey = "VHDLocations"
        if (msrdTestRegistryValue -path $pVHDpath -value $pVHDkey) {
            $pkey = (Get-ItemPropertyValue -Path $pVHDpath -name $pVHDkey).replace("`n","")
            $pkeyExtensions = @(
                "\*\*.VHD",
                "\*\*.VHD.lock",
                "\*\*.VHD.meta",
                "\*\*.VHD.metadata",
                "\*\*.VHDX",
                "\*\*.VHDX.lock",
                "\*\*.VHDX.meta",
                "\*\*.VHDX.metadata"
            )

            $pkeyArray = @()
            foreach ($pkeyExtension in $pKeyExtensions) {
                $pkeyArray += ($pkey + $pkeyExtension)
            }

        } else {
            #no path found, defaulting to generic value
            $pkeyArray = @("\\server-name\share-name\*\*.VHD", "\\server-name\share-name\*\*.VHD.lock", "\\server-name\share-name\*\*.VHD.meta", "\\server-name\share-name\*\*.VHD.metadata", "\\server-name\share-name\*\*.VHDX", "\\server-name\share-name\*\*.VHDX.lock", "\\server-name\share-name\*\*.VHDX.meta", "\\server-name\share-name\*\*.VHDX.metadata")
        }

        $ccdVHDkey = "CCDLocations"
        if (msrdTestRegistryValue -path $pVHDpath -value $ccdVHDkey) {
            $ccdkey = $True
        } else {
            $ccdkey = $false
        }

        $avRec = @("%TEMP%\*\*.VHD","%TEMP%\*\*.VHDX","%Windir%\TEMP\*\*.VHD","%Windir%\TEMP\*\*.VHDX")

        if ($ccdkey) {
            $ccdRec = @("%ProgramData%\FSLogix\Cache\*","%ProgramData%\FSLogix\Proxy\*")
            $recAVexclusionsPaths = $avRec + $pkeyArray + $ccdRec
        } else {
            $recAVexclusionsPaths = $avRec + $pkeyArray
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Cloud Cache is not enabled. The recommended Cloud Cache Exclusions will not be taken into consideration for this check. This may lead to false positives if you have the Cloud Cache Exclusions configured."
        }
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Windows Defender Paths exclusions for FSLogix (local config)"
        msrdTestAVExclusion -ExclPath "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths" -ExclValue $recAVexclusionsPaths -Scope "FSLogix"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Windows Defender Paths exclusions for FSLogix (policy config)"
        msrdTestAVExclusion -ExclPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions\Paths" -ExclValue $recAVexclusionsPaths -Scope "FSLogix"

        #Java
        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "<b>Java related installations</b>"

        $fsjava = Get-CimInstance -ClassName Win32_Product -Filter "Name like '%Java%'" -ErrorAction SilentlyContinue | Select-Object Name, Vendor, Version
        if ($fsjava) {
            foreach ($fsj in $fsjava) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($fsj.Name) ($($fsj.Vendor))" -Message3 "$($fsj.Version)" -circle "blue"
            }
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Java related installation(s) not found"
        }

    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "FSLogix installation <span style='color: brown'>not found</span>."
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagMultimedia {

    #Multimedia diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Multimedia"
    $menucatmsg = $script:msrdMenuCat
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "MultiMedCheck"

    $featuremp = Get-WindowsOptionalFeature -Online -FeatureName "MediaPlayback" -ErrorAction Continue 2>>$global:msrdErrorLogFile
    if ($featuremp) {
        if ($featuremp.State -eq "Enabled") {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Media Playback feature" -Message2 "$($featuremp.State)" -circle "green"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Media Playback feature" -Message2 "$($featuremp.State)" -circle "blue"
        }
    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Media Playback feature information could not be retrieved" -circle "red"
    }

    $featurewmp = Get-WindowsOptionalFeature -Online -FeatureName "WindowsMediaPlayer" -ErrorAction Continue 2>>$global:msrdErrorLogFile
    if ($featurewmp) {
        if ($featurewmp.State -eq "Enabled") {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Windows Media Player feature" -Message2 "$($featurewmp.State)" -circle "green"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Windows Media Player feature" -Message2 "$($featurewmp.State)" -circle "blue"
        }
    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Windows Media Player feature information could not be retrieved" -circle "red"
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone\' -RegKey 'Value' -RegValue 'Allow' -OptNote 'Microphone access - general'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone\NonPackaged\' -RegKey 'Value' -RegValue 'Allow' -OptNote 'Microphone access - desktop apps'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam\' -RegKey 'Value' -RegValue 'Allow' -OptNote 'Camera access - general'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam\NonPackaged\' -RegKey 'Value' -RegValue 'Allow' -OptNote 'Camera access - desktop apps'

    if (!($global:msrdSource)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fDisableAudioCapture' -RegValue '0' -OptNote 'Computer Policy: Allow audio recording redirection'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fDisableCam' -RegValue '0' -OptNote 'Computer Policy: Allow audio and video playback redirection'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fDisableCameraRedir' -RegValue '0' -OptNote 'Computer Policy: Do not allow video capture redirection'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'fDisableCam' -RegValue '0'
        if ($global:msrdAVD -or $global:msrdW365) {
            if ($script:msrdListenervalue) {
                msrdCheckRegKeyValue ('HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\' + $script:msrdListenervalue + '\') -RegKey 'fDisableCam' -RegValue '0'
            } else {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Active AVD listener configuration not found" -circle "red"
            }
        }
    }

    if ($global:msrdAVD -or $global:msrdW365) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        if ($script:RDClient) {
            msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\MSRDC\FeatureFlags\' -RegKey 'EnableMsMmrDVCPlugin'
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        }

        $instreg = @("hklm:\software\microsoft\windows\currentversion\uninstall\*", "hklm:\software\wow6432node\microsoft\windows\currentversion\uninstall\*")
        $instfound = $false
        $reqVCRfound = 0
        foreach ($instkey in $instreg) {
            $vcrinst = Get-ItemProperty $instkey | Where-Object { $_.DisplayName -like "*Microsoft Visual C++*Redistributable*" } -ErrorAction SilentlyContinue | Select-Object DisplayName, DisplayVersion
            if ($vcrinst) {
                $instfound = $true
                foreach ($vcr in $vcrinst) {
                    $reqVCR = 0
                    $regex = "(?<!@{DisplayName=}).*?(?=\s*-\s*[^\-]*$)"
                    $vcrdn = [regex]::Match($vcr.DisplayName.ToString(), $regex).Value.Trim()
                    $vcrVer = $vcr.DisplayVersion

                    # Split the versions into their components
                    $minverComponents = $minVCRverMMR -split '\.'
                    $versionToCheckComponents = $vcrVer -split '\.'

                    for ($i = 0; $i -lt $minverComponents.Count; $i++) {
                        $minComponent = [int]$minverComponents[$i]
                        $checkComponent = [int]$versionToCheckComponents[$i]

                        if ($minComponent -gt $checkComponent) {
                            $circle = "red"
                            break
                        } elseif ($minComponent -eq $checkComponent) {
                            $circle = "green"
                            $reqVCR++
                        } else {
                            $circle = "green"
                            $reqVCR = 4
                            break
                        }
                    }
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message $vcrdn -Message2 $vcrVer -circle $circle
                    if ($reqVCR -eq 4) { $reqVCRfound += 1 }
                }
            }
        }

        if ($reqVCRfound -eq 0) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            if ($global:msrdLiveDiag) {
                $novcrmsg = "The Microsoft Visual C++ Redistributable installation does not meet the minimum required version for AVD Multimedia Redirection. Please consider updating."
            } else {
                $novcrmsg = "The Microsoft Visual C++ Redistributable installation does not meet the minimum required version for AVD Multimedia Redirection. Please consider updating. See: $mmrReqRef"
            }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -Col 3 -Message $novcrmsg -Circle "red"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        }

        if (-not $instfound) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            $novcrmsg = "Microsoft Visual C++ Redistributable installation not found. AVD Multimedia Redirection requirements are not met."
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -Col 3 -Message $novcrmsg -Circle "red"
        }

        if (-not $global:msrdSource) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
            if (Test-Path 'HKLM:\SOFTWARE\Microsoft\RDAgentBootLoader') {

                $path= "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\"
                if (Test-Path $path) {
                    $MMRver = (Get-ChildItem -Path $path -ErrorAction Continue 2>>$global:msrdErrorLogFile | Get-ItemProperty | Select-Object DisplayName, DisplayVersion | Where-Object DisplayName -like "Remote Desktop Multimedia*").DisplayVersion
                    if ($MMRver) {
                        # Split the versions into their components
                        $latestverComponents = $latestMMRver -split '\.'
                        $versionToCheckComponents = $MMRver -split '\.'

                        # Ensure that both versions have the same number of components
                        if ($latestverComponents.Count -ne $versionToCheckComponents.Count) {
                            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $circle = "red"
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Version number mismatch (latest version: $latestMMRver / current version: $MMRver). Please report this to MSRDCollectTalk@microsoft.com" -circle $circle
                        } else {
                            $isNewer = $false
                            for ($i = 0; $i -lt $latestverComponents.Count; $i++) {
                                $latestComponent = [int]$latestverComponents[$i]
                                $checkComponent = [int]$versionToCheckComponents[$i]

                                if ($latestComponent -gt $checkComponent) {
                                    $isNewer = $true
                                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $circle = "red"
                                    break
                                } else {
                                    $circle = "green"
                                }
                            }
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Desktop Multimedia Redirection Service installation found" -Message2 "$MMRver" -circle $circle

                            if ($isNewer) {
                                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Older Remote Desktop Multimedia Redirection Service version found installed on this machine. Please consider updating. See: $mmrRef" -circle "red"
                            }
                        }

                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Remote Desktop Multimedia Redirection Service installation <span style='color: brown'>not found</span>."
                    }
                } else {
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Error retrieving Remote Desktop Multimedia Redirection Service information" -circle "red"
                }

                msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
                msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Google\Chrome\' -RegKey 'ExtensionSettings'
                msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\' -RegKey 'ExtensionSettings'
            } else {
                if (!($global:msrdSource)) {
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$avdcheckmsg" -circle "red"
                }
            }
        }

        # Check if cmd.exe is blocked by AppLocker
        $blockedApps = Get-WinEvent -LogName "Microsoft-Windows-AppLocker/EXE and DLL" -MaxEvents 1000 -ErrorAction SilentlyContinue | Where-Object { $_.Message -match "Denied" -and $_.Message -match "cmd.exe" }

        if ($blockedApps) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
            global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "cmd.exe is being blocked by AppLocker. Multimedia redirection won't work as expected if cmd.exe is blocked." -circle "red"
        }
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagQA {

    #Quick Assist diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Quick Assist / Remote Help"
    $menucatmsg = $script:msrdMenuCat
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "QACheck"

    #quick assist
    $qa = Get-AppxPackage -Name "*QuickAssist*" -ErrorAction SilentlyContinue | Select-Object Name, Version, InstallLocation

    if ($qa) {
        $QAver = $qa.Version

        # Split the versions into their components
        $latestverComponents = $latestQAver -split '\.'
        $versionToCheckComponents = $QAver -split '\.'

        # Ensure that both versions have the same number of components
        if ($latestverComponents.Count -ne $versionToCheckComponents.Count) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $circle = "red"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Version number mismatch (latest version: $latestQAver / current version: $QAver). Please report this to MSRDCollectTalk@microsoft.com" -circle $circle
        } else {
            $isNewer = $false
            for ($i = 0; $i -lt $latestverComponents.Count; $i++) {
                $latestComponent = [int]$latestverComponents[$i]
                $checkComponent = [int]$versionToCheckComponents[$i]

                if ($latestComponent -gt $checkComponent) {
                    $isNewer = $true
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $circle = "red"
                    break
                } else {
                    $circle = "green"
                }
            }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Quick Assist ($($qa.Name))" -Message2 "$($qa.version)" -circle $circle
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Path: $($qa.InstallLocation)"

            if ($isNewer) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "An older Quick Assist version is installed on this machine. Please consider updating." -circle "red"
            }
        }

    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Quick Assist installation <span style='color: brown'>not found</span>."
    }

    #remote help
    msrdLogDiag $LogLevel.DiagFileOnly -Type "DL"
    $rh = (Get-Item "$env:ProgramFiles\Remote Help\RemoteHelp.exe" -ErrorAction SilentlyContinue).VersionInfo | Select-Object FileName, ProductName, ProductVersion

    if ($rh) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Help" -Message2 "$($rh.ProductVersion)" -circle $circle
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Path: $($rh.FileName)"

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckServicePort -service "Remote Help"
    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Remote Help installation <span style='color: brown'>not found</span>."
    }

    #url checks in case either QA or RH are present
    if ($qa -or $rh) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Required Endpoints"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Shared by both Quick Assist and Remote Help"
        $QARHurls = @{
            "remoteassistance.support.services.microsoft.com" = @(443)
            "aria.microsoft.com" = @()
            "events.data.microsoft.com" = @(443)
            "flightproxy.skype.com" = @()
            "monitor.azure.com" = @()
            "registrar.skype.com" = @()
            "support.services.microsoft.com" = @()
            "trouter.skype.com" = @()
            "aadcdn.msauth.net" = @(443)
            "edge.skype.com" = @(443)
            "login.microsoftonline.com" = @(443)
            "remoteassistanceprodacs.communication.azure.com" = @(443)
        }
        msrdReqURLCheck -urls $QARHurls

        if ($qa) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Quick Assist specific"
            $QAurls = @{
                "cc.skype.com" = @()
                "live.com" = @(443)
                "turn.azure.com" = @(443)
            }
            msrdReqURLCheck -urls $QAurls
        }

        if ($rh) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Remote Help specific"
            $RHurls = @{
                "aadcdn.msftauth.net" = @(443)
                "graph.microsoft.com" = @(443)
                "alcdn.msauth.net" = @(443)
                "wcpstatic.microsoft.com" = @(443)
                "remotehelp.microsoft.com" = @(443)
                "trouter.teams.microsoft.com" = @()
                "trouter.communication.microsoft.com" = @()
            }
            msrdReqURLCheck -urls $RHurls
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Microsoft Edge WebView2 Runtime"
        msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}\' -RegKey 'pv'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}\' -RegKey 'pv'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}\' -RegKey 'pv'
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagRDPListener {

    #RDP/RD Listener diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "RDP / Listener"
    $menucatmsg = $script:msrdMenuCat
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "ListenerCheck"

    $linkmsg = ""
    if (Test-Path ($global:msrdLogDir + $listenerPermFile)) {
        $linkmsg = "<a href='$listenerPermFile' target='_blank'>Permissions</a>"
    }

    if (Test-Path ($global:msrdLogDir + $machineKeysFile)) {
        if ($linkmsg -ne "") { $linkmsg += " / " }
        $linkmsg += "<a href='$machineKeysFile' target='_blank'>MachineKeys</a>"
    }

    if ($linkmsg -ne "") {
        msrdCheckServicePort -service TermService -tcpports 3389 -udpports 3389 -stopWarning -linkmsg $linkmsg
    } else {
        msrdCheckServicePort -service TermService -tcpports 3389 -udpports 3389 -stopWarning
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "DL"
    msrdCheckServicePort -service SessionEnv -stopWarning
    msrdLogDiag $LogLevel.DiagFileOnly -Type "DL"
    msrdCheckServicePort -service UmRdpService -stopWarning
    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fDenyTSConnections' -RegValue '0' -OptNote 'Computer Policy: Allow users to connect remotely by using Remote Desktop Services'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fPromptForPassword' -OptNote 'Computer Policy: Always prompt for password upon connection'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fSingleSessionPerUser' -OptNote 'Computer Policy: Restrict RDS users to a single RDS session'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'MaxInstanceCount' -OptNote 'Computer Policy: Limit number of connections'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'SecurityLayer' -RegValue '2' -OptNote 'Computer Policy: Require use of specific security layer for remote (RDP) connections'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'SelectTransport' -RegValue '0' -OptNote 'Computer Policy: Select RDP transport protocols'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'UserAuthentication' -RegValue '1' -OptNote 'Computer Policy: Require user authentication for remote connections by using Network Level Authentication'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -RegKey 'fDenyTSConnections' -RegValue '0'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -RegKey 'fSingleSessionPerUser' -RegValue '1'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -RegKey 'IgnoreRegUserConfigErrors'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -RegKey 'KeepAliveInterval'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -RegKey 'KeepAliveEnable'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\' -RegKey 'SelfSignedCertificate'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\' -RegKey 'SelfSignedCertStore' -RegValue 'Remote Desktop'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'CitrixBackupRdpTcpLoadableProtocolObject' -addWarning
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'fEnableWinStation' -RegValue '1'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'InitialProgram'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'MaxInstanceCount' -RegValue '4294967295'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'LoadableProtocol_Object'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'PortNumber' -RegValue '3389'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'SecurityLayer' -RegValue '2'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'SSLCertificateSHA1Hash'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'UserAuthentication' -RegValue '1'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'WebSocketListenerPort' -RegValue '3387'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'WebSocketTlsListenerPort' -RegValue '3392'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'WebSocketURI'

    if ($global:msrdAVD -or $global:msrdW365) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        #checking if multiple AVD listener reg keys are present
        if (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\rdp-sxs*') {

            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
            $SxSlisteners = (Get-ItemProperty -path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\rdp-sxs*').PSChildName
            $SxSlisteners | foreach-object -process {
                if ($_ -ne "rdp-sxs") {
                    msrdCheckRegKeyValue -RegPath ('HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\' + $_ + '\') -RegKey 'fEnableWinStation'
                }
            }
        }
        else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "AVD listener (HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\rdp-sxs*) reg keys <span style='color: brown'>not found</span>. This machine is either not a AVD VM or the AVD listener is not configured properly." -circle "red"
        }

        #checking for the current AVD listener version and "fReverseConnectMode"
        if (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations') {
            if ($script:msrdListenervalue) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "<b>The AVD listener currently in use is: $script:msrdListenervalue</b>"
                msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\ClusterSettings\' -RegKey 'SessionDirectoryListener' -RegValue $script:msrdListenervalue
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"

                $listenerregpath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\" + $script:msrdListenervalue + "\"
                msrdCheckRegKeyValue -RegPath $listenerregpath -RegKey 'fReverseConnectMode' -RegValue '1'
                msrdCheckRegKeyValue -RegPath $listenerregpath -RegKey 'InitialProgram'
                msrdCheckRegKeyValue -RegPath $listenerregpath -RegKey 'MaxInstanceCount' -RegValue '4294967295'
                msrdCheckRegKeyValue -RegPath $listenerregpath -RegKey 'SecurityLayer' -RegValue '2'
                msrdCheckRegKeyValue -RegPath $listenerregpath -RegKey 'SSLCertificateSHA1Hash'
                msrdCheckRegKeyValue -RegPath $listenerregpath -RegKey 'UserAuthentication' -RegValue '1'
            } else {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\ReverseConnectionListener' <span style='color: brown'>not found</span>. This machine is either not a AVD VM or the AVD listener is not configured properly." -circle "red"
            }
        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations' <span style='color: brown'>not found</span>. This machine is not properly configured for either AVD or RDS connections." -circle "red"
        }
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Quota System\' -RegKey 'EnableCpuQuota'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Services\TSFairShare\Disk\' -RegKey 'EnableFairShare'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Services\TSFairShare\NetFS\' -RegKey 'EnableFairShare'

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagRDSRoles {

    #RDS Roles diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "RDS Roles"
    $menucatmsg = $script:msrdMenuCat
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "RolesCheck"

    $script:foundRDS = (Get-WindowsFeature -Name RDS-* -ErrorAction Continue 2>>$global:msrdErrorLogFile) | Where-Object { $_.InstallState -eq "Installed" }

    Function msrdDotNetTrustCheck {
        param([string] $pspath)

        $tcheck = (Get-WebConfiguration -Filter '/system.web/trust' -PSPath "$pspath" -ErrorAction Continue 2>>$global:msrdErrorLogFile).level
        if ($tcheck) {
            if ($tcheck -eq "Full") {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$pspath" -Message3 $tcheck -circle "green"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$pspath" -Message3 $tcheck -circle "red"
            }
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$pspath" -Message3 "Error retrieving or value not found" -circle "red"
        }
    }

    #gateway
    if ($script:foundRDS.Name -eq "RDS-GATEWAY") {
        if ((Test-Path ($global:msrdLogDir + $getcapfile)) -and (Test-Path ($global:msrdLogDir + $getrapfile))) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "<b>Remote Desktop Gateway role</b>" -Message2 "Installed (See: <a href='$getcapfile' target='_blank'>CAP</a> / <a href='$getrapfile' target='_blank'>RAP</a>)" -circle "green"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "<b>Remote Desktop Gateway role</b>" -Message2 "Installed" -circle "green"
        }
        if ($global:msrdAVD -and $global:msrdTarget) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Having the Remote Desktop Gateway role installed on an AVD host is not supported" -circle "red"
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckServicePort -service TSGateway -udpports 3391 -stopWarning

        msrdLogDiag $LogLevel.DiagFileOnly -Type "DL"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "IIS .Net Trust Levels"

        Import-Module WebAdministration

        msrdDotNetTrustCheck "MACHINE/WEBROOT"
        msrdDotNetTrustCheck "MACHINE/WEBROOT/APPHOST"
        msrdDotNetTrustCheck "MACHINE/WEBROOT/APPHOST/Default Web Site"
        msrdDotNetTrustCheck "MACHINE/WEBROOT/APPHOST/Default Web Site/Rpc"
        msrdDotNetTrustCheck "MACHINE/WEBROOT/APPHOST/Default Web Site/RpcWithCert"

        Remove-Module WebAdministration

    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Desktop Gateway role" -Message2 "not found"
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Terminal Server Gateway\' -RegKey 'SkipMachineNameAttribute'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\TerminalServerGateway\Config\Core\' -RegKey 'EnforceChannelBinding'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\TerminalServerGateway\Config\Core\' -RegKey 'IasTimeout'

    #web access
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    if ($script:foundRDS.Name -eq "RDS-WEB-ACCESS") {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "<b>Remote Desktop Web Access role</b>" -Message2 "Installed" -circle "green"
        if ($global:msrdAVD -and $global:msrdTarget) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Having the Remote Desktop Web Access role installed on an AVD host is not supported" -circle "red"
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckServicePort -service W3SVC  -stopWarning

        msrdLogDiag $LogLevel.DiagFileOnly -Type "DL"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "IIS .Net Trust Levels"

        Import-Module WebAdministration

        msrdDotNetTrustCheck "MACHINE/WEBROOT"
        msrdDotNetTrustCheck "MACHINE/WEBROOT/APPHOST"
        msrdDotNetTrustCheck "MACHINE/WEBROOT/APPHOST/Default Web Site"
        msrdDotNetTrustCheck "MACHINE/WEBROOT/APPHOST/Default Web Site/RDWeb"
        msrdDotNetTrustCheck "MACHINE/WEBROOT/APPHOST/Default Web Site/RDWeb/Pages"

        Remove-Module WebAdministration

        #RDWeb client components
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"

        $isWebClientModule = Get-Module -ListAvailable -Name RDWebClientManagement

        if ($isWebClientModule) {
            try {
                $rdwcver = (Get-RDWebClientPackage -ErrorAction SilentlyContinue).Version
                if ($rdwcver) {
                    foreach ($wcver in $rdwcver) {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Desktop Web Client" -Message2 "$wcver" -circle "blue"
                    }
                } else {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Desktop Web Client" -Message2 "not found"
                }
            } catch {
                $failedCommand = $_.InvocationInfo.Line.TrimStart()
                msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Desktop Web Client" -Message2 "not found"
            }

            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Remote Desktop Web Client PowerShell prerequisites"

            $rdwcProvs = "NuGet"
            $rdwcProvs | ForEach-Object -Process {
                try {

                    if ($_ -eq "NuGet") {
                        if (!(Get-PackageProvider -ListAvailable | Where-Object { $_.Name -eq 'NuGet' } -ErrorAction SilentlyContinue)) {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$_" -Message3 "not found"
                            return
                        }
                    }

                    $rdwcProvVer = [String](Get-PackageProvider -Name $_ -ErrorAction SilentlyContinue).Version
                    if ($rdwcProvVer) {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$_" -Message3 "$rdwcProvVer" -circle "blue"
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$_" -Message3 "not found"
                    }
                } catch {
                    $failedCommand = $_.InvocationInfo.Line.TrimStart()
                    msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$_" -Message3 "not found"
                }
            }

            $rdwcMods = "PackageManagement", "PowerShellGet"
            $rdwcMods | ForEach-Object -Process {
                try {
                    $rdwcmodver = [String](Get-Module -Name $_ -ErrorAction SilentlyContinue).Version
                    if ($rdwcmodver) {
                        if (($_ -eq "PowerShellGet") -and ($rdwcmodver -eq "1.0.0.1")) {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$_" -Message3 "$rdwcmodver" -circle "red"
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "This $_ version does not support installing the web client management module" -circle "red"
                        } else {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$_" -Message3 "$rdwcmodver" -circle "blue"
                        }
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$_" -Message3 "not found"
                    }
                } catch {
                    $failedCommand = $_.InvocationInfo.Line.TrimStart()
                    msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$_" -Message3 "not found"
                }
            }

            $rdwcMods = "RDWebClientManagement"
            $rdwcMods | ForEach-Object -Process {
                try {
                    $rdwcmodver = [String](Get-InstalledModule -Name $_ -ErrorAction SilentlyContinue).Version
                    if ($rdwcmodver) {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$_" -Message3 "$rdwcmodver" -circle "blue"
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$_" -Message3 "not found"
                    }
                } catch {
                    $failedCommand = $_.InvocationInfo.Line.TrimStart()
                    msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$_" -Message3 "not found"
                }
            }

            try {
                $rdwcconfig = Get-RDWebClientDeploymentSetting -ErrorAction SilentlyContinue | Select-Object Name, Value
                if ($rdwcconfig) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Remote Desktop Web Client Deployment Settings"
                    foreach ($wcconfig in $rdwcconfig) {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($wcconfig.Name)" -Message3 "$($wcconfig.Value)" -circle "blue"
                    }
                } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Desktop Web Client Deployment Settings" -Message2 "not found"
                }
            } catch {
                $failedCommand = $_.InvocationInfo.Line.TrimStart()
                msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Desktop Web Client Deployment Settings" -Message2 "not found"
            }

            try {
                $rdwccert = Get-RDWebClientBrokerCert -ErrorAction SilentlyContinue | Select-Object Subject, Thumbprint, NotAfter
                if ($rdwccert) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Remote Desktop Web Client Broker Certificate"
                    $wcthresholdDate = (Get-Date).AddDays(30)
                    if ($rdwccert.NotAfter) {
                        $wcexpdate = Get-Date ($rdwccert.NotAfter)
                        $wcexpdiff = $wcexpdate - $wcthresholdDate
                        if ($wcexpdiff -lt "30") {
                            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "Expires on: $wcexpdate" -Message3 "Subject: $($rdwccert.Subject)" -circle "red"
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "Thumbprint: $($rdwccert.Thumbprint)" -circle "red"
                        } else {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "Expires on: $wcexpdate" -Message3 "Subject: $($rdwccert.Subject)" -circle "blue"
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "Thumbprint: $($rdwccert.Thumbprint)" -circle "blue"
                        }
                    } else {
                        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Remote Desktop Web Client Broker Certificate information could not be retrieved" -circle "red"
                    }
                } else {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Desktop Web Client Broker Certificate information" -Message2 "not found"
                }
            } catch {
                $failedCommand = $_.InvocationInfo.Line.TrimStart()
                msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Desktop Web Client Broker Certificate information" -Message2 "not found"
            }

        } else {
			msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Remote Desktop Web Client PowerShell management module not found. Skipping further RD Web Client checks" -circle "blue"
        }

    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Desktop Web Access role" -Message2 "not found"
    }

    #broker
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    if ($script:foundRDS.Name -eq "RDS-CONNECTION-BROKER") {
        if (Test-Path ($global:msrdLogDir + $GetRDSFarmDatafile)) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "<b>Remote Desktop Connection Broker role</b>" -Message2 "Installed (See: <a href='$GetRDSFarmDatafile' target='_blank'>GetRDSFarmData</a>)" -circle "green"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "<b>Remote Desktop Connection Broker role</b>" -Message2 "Installed" -circle "green"
        }
        if ($global:msrdAVD -and $global:msrdTarget) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Having the Remote Desktop Connection Broker role installed on an AVD host is not supported" -circle "red"
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckServicePort -service Tssdis -stopWarning
        msrdLogDiag $LogLevel.DiagFileOnly -Type "DL"
        msrdCheckServicePort -service RDMS -stopWarning
        msrdLogDiag $LogLevel.DiagFileOnly -Type "DL"
        msrdCheckServicePort -service TScPubRPC -tcpports 5504 -stopWarning
        msrdLogDiag $LogLevel.DiagFileOnly -Type "DL"
        msrdCheckServicePort -service 'MSSQL$MICROSOFT##WID'

        # DB access
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        $HighAvailabilityBroker = Get-RDConnectionBrokerHighAvailability -ErrorAction SilentlyContinue
        If ($null -eq $HighAvailabilityBroker) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "The Connection Broker is not configured for High Availability" -circle "blue"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "The Connection Broker is configured for High Availability" -circle "blue"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Client Access Name (Round Robin DNS)" -Message2 $HighAvailabilityBroker.ClientAccessName -circle "blue"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "ActiveManagementServer" -Message2 $HighAvailabilityBroker.ActiveManagementServer -circle "blue"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "DatabaseConnectionString" -Message2 $HighAvailabilityBroker.DatabaseConnectionString -circle "blue"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "DatabaseSecondaryConnectionString" -Message2 $HighAvailabilityBroker.DatabaseSecondaryConnectionString -circle "blue"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "DatabaseFilePath" -Message2 $HighAvailabilityBroker.DatabaseFilePath -circle "blue"
        }
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"

        # Certificates
        msrdLogDiag $LogLevel.DiagFileOnly -Type "DL"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "RDS deployment certificates"
        $rdscert = Get-RDCertificate -ErrorAction Continue 2>>$global:msrdErrorLogFile | Select-Object Role, Level, ExpiresOn, Subject, SubjectAlternateName, Thumbprint
        if ($rdscert) {
            $thresholdDate = (Get-Date).AddDays(30)
            foreach ($cert in $rdscert) {
                $certlvl = $cert.Level
                if ($cert.ExpiresOn) {
                    $expdate = Get-Date ($cert.ExpiresOn)
                    $expdiff = $expdate - $thresholdDate
                    if (($expdiff -lt "30") -or ($certlvl -ne "Trusted")) {
                        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "$($cert.Role)" -Message2 "$certlvl - Expires on: $expdate" -Message3 "Subject: $($cert.Subject)" -circle "red"
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "Thumbprint: $($cert.Thumbprint)" -Message3 "SAN: $($cert.SubjectAlternateName)" -circle "red"
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "$($cert.Role)" -Message2 "$certlvl - Expires on: $expdate" -Message3 "Subject: $($cert.Subject)" -circle "blue"
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "Thumbprint: $($cert.Thumbprint)" -Message3 "SAN: $($cert.SubjectAlternateName)" -circle "blue"
                    }
                } else {
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "$($cert.Role)" -Message2 "$certlvl" -circle "red"
                }
            }
        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Remote Desktop certificates information not found or could not be retrieved" -circle "red"
        }

    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Desktop Connection Broker role" -Message2 "not found"
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\CentralizedPublishing\' -RegKey 'Redirector'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\CentralizedPublishing\' -RegKey 'RedirectorAlternateAddress'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\CentralizedPublishing\' -RegKey 'Port'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\ClusterSettings\' -RegKey 'DeploymentServerName'

    #session host
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    if ($script:foundRDS.Name -eq "RDS-RD-Server") {
        if (Test-Path ($global:msrdLogDir + $gracefile)) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "<b>Remote Desktop Session Host role</b>" -Message2 "Installed (See: <a href='$gracefile' target='_blank'>GracePeriod</a>)" -circle "green"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "<b>Remote Desktop Session Host role</b>" -Message2 "Installed" -circle "green"
        }
    } else {
        if ($global:msrdAVD) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Desktop Session Host role" -Message2 "not found" -circle "red"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "This machine is running a Windows Server OS but the Remote Desktop Session Host role is not installed. This role is required for AVD VMs running Windows Server OS." -circle "red"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Desktop Session Host role" -Message2 "not found"
        }
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'CertTemplateName' -OptNote 'Computer Policy: Server authentication certificate template'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'SessionDirectoryLocation' -OptNote 'Computer Policy: Configure RD Connection Broker server name'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'SessionDirectoryClusterName' -OptNote 'Computer Policy: Configure RD Connection Broker farm name'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'ParticipateInLoadBalancing' -OptNote 'Computer Policy: Use RD Connection Broker load balancing'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'SessionDirectoryActive' -OptNote 'Computer Policy: Join RD Connection Broker'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'SessionDirectoryExposeServerIP' -OptNote 'Computer Policy: Use IP Address Redirection'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -RegKey 'SessionDirectoryActive'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -RegKey 'TSServerDrainMode' -RegValue '0'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\ClusterSettings\' -RegKey 'SessionDirectoryClusterName'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\ClusterSettings\' -RegKey 'SessionDirectoryLocation'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\ClusterSettings\' -RegKey 'SessionDirectoryRedirectionIP'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\ClusterSettings\' -RegKey 'ParticipateInLoadBalancing'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\ClusterSettings\' -RegKey 'ServerWeight'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\ClusterSettings\' -RegKey 'UvhdEnabled'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\ClusterSettings\' -RegKey 'UvhdShareUrl'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\TSAppSrv\VirtualIP\' -RegKey 'EnableVirtualIP' -OptNote 'Computer Policy: Turn on Remote Desktop IP Virtualization'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\TSAppSrv\VirtualIP\' -RegKey 'VirtualMode' -OptNote 'Computer Policy: Turn on Remote Desktop IP Virtualization'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\TSAppSrv\VirtualIP\' -RegKey 'PerApp' -OptNote 'Computer Policy: Turn on Remote Desktop IP Virtualization'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\TSAppSrv\VirtualIP\' -RegKey 'VIPAdapter' -OptNote 'Computer Policy: Select the network adapter to be used for Remote Desktop IP Virtualization'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\TSAppSrv\VirtualIP\' -RegKey 'PromptOnIPLeaseFail' -OptNote 'Computer Policy: Do not use Remote Desktop Session Host server IP address when virtual IP address is not available'

    if ($global:msrdRDS -and $global:msrdTarget) {
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Services\WinSock2\Parameters\AppId_Catalog\2C69D9F1\' -RegKey 'AppFullPath'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Services\WinSock2\Parameters\AppId_Catalog\2C69D9F1\' -RegKey 'PermittedLspCategories'
    }

    #license server
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    if ($script:foundRDS.Name -eq "RDS-Licensing") {
        if ((Test-Path ($global:msrdLogDir + $licpakfile)) -and (Test-Path ($global:msrdLogDir + $licoutfile))) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "<b>Remote Desktop Licensing role</b>" -Message2 "Installed (See: <a href='$licpakfile' target='_blank'>LicenseKeyPacks.html</a> / <a href='$licoutfile' target='_blank'>IssuedLicenses.html</a>)" -circle "green"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "<b>Remote Desktop Licensing role</b>" -Message2 "Installed" -circle "green"
        }
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckServicePort -service TermServLicensing -stopWarning

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        $licactivation = (Invoke-CimMethod -ClassName Win32_TSLicenseServer -MethodName GetActivationStatus -ErrorAction Continue 2>>$global:msrdErrorLogFile).ActivationStatus
        if ($null -ne $licactivation) {
            if ($licactivation -eq 0) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Desktop license server activation status" -Message2 "Activated" -circle "green"
            } elseif ($licactivation -eq 1) {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Desktop license server activation status" -Message2 "Not activated" -circle "red"
            } else {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Remote Desktop license server activation status: An unknown error occurred. It is not known whether the Remote Desktop license server is activated" -circle "red"
            }
        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Desktop license server activation status" -Message2 "Could not be retrieved" -circle "red"
        }

        $licTSLSG = (Invoke-CimMethod -ClassName Win32_TSLicenseServer -MethodName IsLSinTSLSGroup -ErrorAction Continue 2>>$global:msrdErrorLogFile).IsMember
        if ($licTSLSG) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Remote Desktop license server is a member of the Terminal Server License Servers group in the domain." -circle "green"
        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Remote Desktop license server is either not a member of the Terminal Server License Servers group in the domain, not joined to a domain or the domain cannot be contacted." -circle "red"
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fSecureLicensing' -OptNote 'Computer Policy: License server security group'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fPreventLicenseUpgrade' -OptNote 'Computer Policy: Prevent license upgrade'

    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Desktop Licensing role" -Message2 "not found"
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagRDClient {

    #RD Client diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Remote Desktop Clients"
    $menucatmsg = $script:msrdMenuCat
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "RDCCheck"

    #MSTSC
    $mstscVer = (Get-Item $env:windir\System32\mstsc.exe).VersionInfo.ProductVersion
    if ($mstscVer) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Microsoft RD client (MSTSC)" -Message2 "$mstscVer" -circle "blue"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Path" -Message2 "$env:windir\System32\mstsc.exe" -circle "blue"
    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Microsoft RD client (MSTSC)" -Message2 "not found" -circle "red"
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Workspaces\' -RegKey 'DefaultConnectionURL'

    #AVD desktop client (MSRDC)
    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    if ($script:RDClient) {
        foreach ($RDCitem in $script:RDClient) {
            $RDCver = $RDCitem.DisplayVersion
            if ($RDCitem.InstallDate) {
                $RDCdate = $RDCitem.InstallDate
                $RDCdate = [datetime]::ParseExact($RDCdate, "yyyyMMdd", $null).ToString("yyyy/MM/dd")
            } else {
                $RDCdate = "N/A"
            }
            if ($RDCitem.InstallLocation) { $RDCloc = $RDCitem.InstallLocation } else { $RDCloc = "N/A" }

            # Split the versions into their components
            $latestverComponents = $latestRDCver -split '\.'
            $versionToCheckComponents = $RDCver -split '\.'

            # Ensure that both versions have the same number of components
            if ($latestverComponents.Count -ne $versionToCheckComponents.Count) {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $circle = "red"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Version number mismatch (latest version: $latestRDCver / current version: $RDCver). Please report this to MSRDCollectTalk@microsoft.com" -circle $circle
            } else {
                $isNewer = $false
                for ($i = 0; $i -lt $latestverComponents.Count; $i++) {
                    $latestComponent = [int]$latestverComponents[$i]
                    $checkComponent = [int]$versionToCheckComponents[$i]

                    if ($latestComponent -gt $checkComponent) {
                        $isNewer = $true
                        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $circle = "red"
                        break
                    } else {
                        $circle = "green"
                    }
                }
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Windows Desktop client" -Message2 "$RDCver (Installed on: $RDCdate)" -circle $circle
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Path" -Message2 "$RDCloc" -circle "blue"

                if ($isNewer) {
                    if ($global:msrdLiveDiag) {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "An older (no longer supported) Windows Desktop client version is installed on this machine. Please update to the latest Public or Insider version." -circle "red"
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "An older (no longer supported) Windows Desktop client version is installed on this machine. Please update to the latest Public or Insider version. See: $msrdcRef" -circle "red"
                    }
                }
            }

            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        }

        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\MSRDC\Policies\' -RegKey 'AutomaticUpdates'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\MSRDC\Policies\' -RegKey 'ReleaseRing' -addWarning
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\MSRDC\Settings\' -RegKey 'SuppressAppInstalledFromStoreError'

    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Windows Desktop client" -Message2 "not found"
    }

    #New AVD store client
    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    $avdStoreApp = Get-AppxPackage -name MicrosoftCorporationII.AzureVirtualDesktopClient
    $avdStoreAppVer = $avdStoreApp.Version
    if ($avdStoreApp.InstallLocation) { $avdStoreAppLoc = $avdStoreApp.InstallLocation } else { $avdStoreAppLoc = "N/A" }

    if ($avdStoreApp) {
        # Split the versions into their components
        $latestverComponents = $latestAvdStoreApp -split '\.'
        $versionToCheckComponents = $avdStoreAppVer -split '\.'

        # Ensure that both versions have the same number of components
        if ($latestverComponents.Count -ne $versionToCheckComponents.Count) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $circle = "red"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Version number mismatch (latest version: $latestAvdStoreApp / current version: $avdStoreAppVer). Please report this to MSRDCollectTalk@microsoft.com" -circle $circle
        } else {
            $isNewer = $false
            for ($i = 0; $i -lt $latestverComponents.Count; $i++) {
                $latestComponent = [int]$latestverComponents[$i]
                $checkComponent = [int]$versionToCheckComponents[$i]

                if ($latestComponent -gt $checkComponent) {
                    $isNewer = $true
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $circle = "red"
                    break
                } else {
                    $circle = "green"
                }
            }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Azure Virtual Desktop Store client" -Message2 "$avdStoreAppVer (Installed on: $(msrdGetAppxInstallationDate 'MicrosoftCorporationII.AzureVirtualDesktopClient'))" -circle $circle
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Path" -Message2 "$avdStoreAppLoc" -circle "blue"

            if ($isNewer) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "An older Azure Virtual Desktop Store client version is installed on this machine. Please consider updating." -circle "red"
            }
        }

    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Azure Virtual Desktop Store client" -Message2 "not found"
    }

    #New AVD host app
    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    $avdHostApp = Get-AppxPackage -name MicrosoftCorporationII.AzureVirtualDesktopHostApp
    $avdHostAppVer = $avdHostApp.Version
    if ($avdHostApp.InstallLocation) { $avdHostAppLoc = $avdHostApp.InstallLocation } else { $avdHostAppLoc = "N/A" }

    if ($avdHostApp) {
        # Split the versions into their components
        $latestverComponents = $latestAvdHostApp -split '\.'
        $versionToCheckComponents = $avdHostAppVer -split '\.'

        # Ensure that both versions have the same number of components
        if ($latestverComponents.Count -ne $versionToCheckComponents.Count) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $circle = "red"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Version number mismatch (latest version: $latestAvdHostApp / current version: $avdHostAppVer). Please report this to MSRDCollectTalk@microsoft.com" -circle $circle
        } else {
            $isNewer = $false
            for ($i = 0; $i -lt $latestverComponents.Count; $i++) {
                $latestComponent = [int]$latestverComponents[$i]
                $checkComponent = [int]$versionToCheckComponents[$i]

                if ($latestComponent -gt $checkComponent) {
                    $isNewer = $true
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $circle = "red"
                    break
                } else {
                    $circle = "green"
                }
            }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Azure Virtual Desktop Host App" -Message2 "$avdHostAppVer (Installed on: $(msrdGetAppxInstallationDate 'MicrosoftCorporationII.AzureVirtualDesktopHostApp'))" -circle $circle
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Path" -Message2 "$avdHostAppLoc" -circle "blue"

            if ($isNewer) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "An older Azure Virtual Desktop Host App version is installed on this machine. Please consider updating." -circle "red"
            }
        }

    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Azure Virtual Desktop Host App" -Message2 "not found"
    }

    #Windows App client
    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    $w365client = Get-AppxPackage -name MicrosoftCorporationII.Windows365
    $w365ver = $w365client.Version
    if ($w365client.InstallLocation) { $w365loc = $w365client.InstallLocation } else { $w365loc = "N/A" }

    if ($w365client) {
        # Split the versions into their components
        $latestverComponents = $latestw365ver -split '\.'
        $versionToCheckComponents = $w365ver -split '\.'

        # Ensure that both versions have the same number of components
        if ($latestverComponents.Count -ne $versionToCheckComponents.Count) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $circle = "red"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Version number mismatch (latest version: $latestw365ver / current version: $w365ver). Please report this to MSRDCollectTalk@microsoft.com" -circle $circle
        } else {
            $isNewer = $false
            for ($i = 0; $i -lt $latestverComponents.Count; $i++) {
                $latestComponent = [int]$latestverComponents[$i]
                $checkComponent = [int]$versionToCheckComponents[$i]

                if ($latestComponent -gt $checkComponent) {
                    $isNewer = $true
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $circle = "red"
                    break
                } else {
                    $circle = "green"
                }
            }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Windows App client" -Message2 "$w365ver (Installed on: $(msrdGetAppxInstallationDate 'MicrosoftCorporationII.Windows365'))" -circle $circle
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Path" -Message2 "$w365loc" -circle "blue"

            if ($isNewer) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "An older Windows App client version is installed on this machine. Please consider updating." -circle "red"
            }
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckRegKeyValue -RegPath 'HKCU:\Software\Microsoft\Windows365\' -RegKey 'Environment'
    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Windows App client" -Message2 "not found"
    }

    #Old RD store (UWP) client
    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    $StoreClient = Get-AppxPackage -name microsoft.remotedesktop
    $StoreCver = $StoreClient.Version
    $StoreCloc = $StoreClient.InstallLocation

    if ($StoreClient) {
        # Split the versions into their components
        $latestverComponents = $latestStoreCver -split '\.'
        $versionToCheckComponents = $StoreCver -split '\.'

        # Ensure that both versions have the same number of components
        if ($latestverComponents.Count -ne $versionToCheckComponents.Count) {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $circle = "red"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Version number mismatch (latest version: $latestStoreCver / current version: $StoreCver). Please report this to MSRDCollectTalk@microsoft.com" -circle $circle
        } else {
            $isNewer = $false
            for ($i = 0; $i -lt $latestverComponents.Count; $i++) {
                $latestComponent = [int]$latestverComponents[$i]
                $checkComponent = [int]$versionToCheckComponents[$i]

                if ($latestComponent -gt $checkComponent) {
                    $isNewer = $true
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $circle = "red"
                    break
                } else {
                    $circle = "green"
                }
            }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Windows Remote Desktop (UWP) client" -Message2 "$StoreCver (Installed on: $(msrdGetAppxInstallationDate 'microsoft.remotedesktop'))" -circle $circle
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Path" -Message2 "$StoreCloc" -circle "blue"

            if ($isNewer) {
                if ($global:msrdLiveDiag) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "An older Windows Remote Desktop (UWP) client version is installed on this machine. Please consider updating." -circle "red"
                } else {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "An older Windows Remote Desktop (UWP) client version is installed on this machine. Please consider updating. See: $uwpcRef" -circle "red"
                }
            }
        }
    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Windows Remote Desktop (UWP) client" -Message2 "not found"
    }

    #RD web client
    if (!($global:msrdRDS) -and !($global:msrdTarget)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Remote Desktop Web Client for AVD"
        $webclienturls = @{
            "client.wvd.microsoft.com" = @()
            "rdweb.wvd.azure.us" = @()
            "rdweb.wvd.azure.cn" = @()
        }
        msrdReqURLCheck -urls $webclienturls
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Terminal Server Client\' -RegKey 'DisableUDPTransport'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Terminal Server Client\' -RegKey 'EnableCredSSPSupport'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Terminal Server Client\' -RegKey 'RDGClientTransport'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    $browserRegPath = 'HKLM:\SOFTWARE\Clients\StartMenuInternet'
    $registeredBrowsers = Get-Item -LiteralPath $browserRegPath | Get-Item -ErrorAction SilentlyContinue | Get-ChildItem | ForEach-Object {
        $_.PSChildName
    }
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Web browsers registered on this system"
    if ($registeredBrowsers.Count -gt 0) {
        $registeredBrowsers | ForEach-Object {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 $_ -circle "blue"
        }
    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "No registered web browsers found" -circle "red"
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagLicensing {

    #RD Licensing diagnostics
    $global:msrdSetWarning = $false
    msrdLogDiag $LogLevel.Normal -Message "Remote Desktop Licensing" -DiagTag "LicCheck"

    if (($script:foundRDS.Name -eq "RDS-Licensing") -or ($script:foundRDS.Name -eq "RDS-RD-Server")) {
        if (Test-Path ($global:msrdLogDir + $tslsgroupfile)) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "RD Session Host and/or RD Licensing role(s) detected" -Message2 "(See: <a href='$tslsgroupfile' target='_blank'>TSLSMembership</a>)" -circle "blue"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        }
    }

    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'LicenseServers' -OptNote 'Computer Policy: Use the specified Remote Desktop license servers'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'LicensingMode' -OptNote 'Computer Policy: Set the Remote Desktop licensing mode'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\'-RegKey  'fDisableTerminalServerTooltip' -OptNote 'Computer Policy: Hide notifications about RD Licensing problems that affect the RD Session Host server'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Services\TermService\Parameters\LicenseServers\' -RegKey 'SpecifiedLicenseServers'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\Licensing Core\' -RegKey 'LicensingMode'

    if ($global:msrdOSVer -like "*Windows Server*") {
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\' -RegKey 'X509 Certificate' -skipValue
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\' -RegKey 'X509 Certificate ID' -skipValue
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\RCM\' -RegKey 'X509 Certificate2' -skipValue
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Services\TermServLicensing\Parameters\' -RegKey 'MaxVerPages'
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagTimeLimits {

    #Session Time Limit diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Session Time Limits"
    $menucatmsg = $script:msrdMenuCat
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "STLCheck"

    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'MaxIdleTime' -OptNote 'Computer Policy: Set time limit for active but idle RDS sessions'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'MaxIdleTime' -OptNote 'User Policy: Set time limit for active but idle RDS sessions'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'MaxConnectionTime' -OptNote 'Computer Policy: Set time limit for active RDS sessions'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'MaxConnectionTime' -OptNote 'User Policy: Set time limit for active RDS sessions'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'MaxDisconnectionTime' -OptNote 'Computer Policy: Set time limit for disconnected sessions'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'MaxDisconnectionTime' -OptNote 'User Policy: Set time limit for disconnected sessions'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'RemoteAppLogoffTimeLimit' -OptNote 'Computer Policy: Set time limit for logoff of RemoteApp sessions'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'RemoteAppLogoffTimeLimit' -OptNote 'User Policy: Set time limit for logoff of RemoteApp sessions'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fResetBroken' -OptNote 'Computer Policy: End session when time limits are reached'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fResetBroken' -OptNote 'User Policy: End session when time limits are reached'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'MaxIdleTime'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'MaxConnectionTime'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'MaxDisconnectionTime'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'fResetBroken'

    if ($global:msrdAVD -or $global:msrdW365) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        if ($avdcheck) {
            $listenerregpath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\" + $script:msrdListenervalue + "\"
            msrdCheckRegKeyValue -RegPath $listenerregpath -RegKey 'MaxIdleTime'
            msrdCheckRegKeyValue -RegPath $listenerregpath -RegKey 'MaxConnectionTime'
            msrdCheckRegKeyValue -RegPath $listenerregpath -RegKey 'MaxDisconnectionTime'
            msrdCheckRegKeyValue -RegPath $listenerregpath -RegKey 'fResetBroken'
        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$avdcheckmsg" -circle "red"
        }
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -RegKey 'InactivityTimeoutSecs' -OptNote 'Computer Policy: Interactive logon: Machine inactivity limit'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters\' -RegKey '\AutoDisconnect' -OptNote 'Computer Policy: Microsoft network server: Amount of idle time required before suspending session'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop\' -RegKey 'ScreenSaveTimeOut' -OptNote 'User Policy: Screen saver timeout'

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagTeams {

    #Microsoft Teams diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Teams Media Optimization"
    $menucatmsg = $script:msrdMenuCat
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "TeamsCheck"

    if ($global:msrdOSVer -like "*Windows 1*") {

        msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Terminal Server Client\' -RegKey 'IsSwapChainRenderingEnabled'
        msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Terminal Server Client\Default\AddIns\WebRTC Redirector\' -RegKey 'UseHardwareEncoding'
        msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Terminal Server Client\Default\AddIns\WebRTC Redirector\' -RegKey 'DisableHWDecoder'
        msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Terminal Server Client\Default\AddIns\WebRTC Redirector\' -RegKey 'SettingsEnabled'

        if (($global:msrdAVD -or $global:msrdW365) -and !($global:msrdSource)) {
            if ($avdcheck) {
                #Checking Teams deployment
                $verpath = $msrdUserProfilePath + "\AppData\Roaming\Microsoft\Teams\settings.json"

                if (Test-Path $verpath) {
                    if ($PSVersionTable.PSVersion -like "*5.1*") {
                        $response = Get-Content $verpath -ErrorAction Continue
                        $response = $response -creplace 'enableIpsForCallingContext','enableIPSForCallingContext'
                        $response = $response | ConvertFrom-Json
                        $TeamsVer = $response.version
                        if ($response.ring) { $TeamsRing = $response.ring } else { $TeamsRing = "N/A" }
                        $TeamsEnv = $response.environment
                    } else {
                        $TeamsVer = (Get-Content $verpath -ErrorAction Continue | ConvertFrom-Json -AsHashTable).version
                        $TeamsRing = (Get-Content $verpath -ErrorAction Continue | ConvertFrom-Json -AsHashTable).ring
                        $TeamsEnv = (Get-Content $verpath -ErrorAction Continue | ConvertFrom-Json -AsHashTable).environment
                    }
                } else {
					$TeamsVer = "N/A"
					$TeamsRing = "N/A"
					$TeamsEnv = "N/A"
                }

                #Checking Classic Teams installation info
                msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
                $TeamsUserPath = $msrdUserProfilePath + "\AppData\Local\Microsoft\Teams\current\Teams.exe"
                if (Test-Path $TeamsUserPath) {
                    if ($global:msrdW365) {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Classic Teams 'per-user' installation <span style='color: blue'>found</span>" -Message2 "$TeamsVer" -circle "blue"
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Path" -Message2 "$TeamsUserPath" -circle "blue"
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Ring" -Message2 "$TeamsRing" -circle "blue"
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Environment" -Message2 "$TeamsEnv" -circle "blue"
                    } else {
                        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Classic Teams 'per-user' installation <span style='color: blue'>found</span>" -Message2 "$TeamsVer" -circle "red"
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Path" -Message2 "$TeamsUserPath" -circle "red"
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Classic Teams per-user installation only works on personal host pools. If your deployment uses pooled host pools, it is recommended to use per-machine installation instead." -circle "red"
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Ring" -Message2 "$TeamsRing" -circle "blue"
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Environment" -Message2 "$TeamsEnv" -circle "blue"
                    }
                } else {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Classic Teams 'per-user' installation for the current user <span style='color: brown'>not found</span>"
                }

                msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
                $TeamsMachinePath = "${env:ProgramFiles(x86)}\Microsoft\Teams\current\Teams.exe"
                if (Test-Path $TeamsMachinePath) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Classic Teams 'per-machine' installation <span style='color: blue'>found</span>" -Message2 "$TeamsVer" -circle "blue"
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Path" -Message2 "$TeamsMachinePath" -circle "blue"
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Ring" -Message2 "$TeamsRing" -circle "blue"
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Environment" -Message2 "$TeamsEnv" -circle "blue"
                } else {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Classic Teams 'per-machine' installation <span style='color: brown'>not found</span>"
                }

                if ((Test-Path $TeamsUserPath) -or (Test-Path $TeamsMachinePath)) {
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "The classic Teams for VDI will reach end of availability on June 30th, 2024. Please consider switching to the new Teams for VDI. See: $classicTeamsEoARef" -circle "red"
                }

                #Checking (New) Teams MSIX installation info
                msrdLogDiag $LogLevel.DiagFileOnly -Type "DL"
                $TeamsNewInfo = Get-AppxPackage -name "msteams" | Select-Object Version, InstallLocation
                if ($TeamsNewInfo) {
					$TeamsNewVer = $TeamsNewInfo.Version
					$TeamsNewLoc = $TeamsNewInfo.InstallLocation
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "New Teams installation <span style='color: blue'>found</span>" -Message2 "$TeamsNewVer" -circle "blue"
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Path" -Message2 "$TeamsNewLoc" -circle "blue"

                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
                    if (Test-path -path "$env:ProgramFiles\FSLogix\apps") {
                        if (($script:frxverstrip -lt 29871630241) -and (!($script:frxverstrip -eq "unknown"))) {
                            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "You are running an older version of FSLogix. The new Teams for VDI requires at least FSLogix version 2.9.8716.30241 for proper integration. Please consider updating. See: $newTeamsFSLogixRef" -circle "red"
                        }
                    }

                    If ($global:msrdOSVer -like "*Server*2016*") {
                        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "The new Teams for VDI is not supported on Windows Server 2016. Please consider upgrading. See: $newTeamsRef" -circle "red"
                    }
                } else {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "New Teams installation <span style='color: brown'>not found</span>"
                }

                msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
                $path= "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\"
                if (Test-Path $path) {
                    $WebRTC = Get-ChildItem -Path $path -ErrorAction Continue 2>>$global:msrdErrorLogFile | Get-ItemProperty | Select-Object DisplayName, DisplayVersion, InstallDate | Where-Object DisplayName -eq "Remote Desktop WebRTC Redirector Service"
                    if ($WebRTC) {
                        $WebRTCver = $WebRTC.DisplayVersion

                        if ($WebRTC.InstallDate) {
                            $WebRTCdate = $WebRTC.InstallDate
                            $WebRTCdate = [datetime]::ParseExact($WebRTCdate, "yyyyMMdd", $null).ToString("yyyy/MM/dd")
                        } else {
                            $WebRTCdate = "N/A"
                        }

                        # Split the versions into their components
                        $latestverComponents = $latestWebRTCVer -split '\.'
                        $versionToCheckComponents = $WebRTCver -split '\.'

                        # Ensure that both versions have the same number of components
                        if ($latestverComponents.Count -ne $versionToCheckComponents.Count) {
                            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $circle = "red"
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Version number mismatch (latest version: $latestWebRTCVer / current version: $WebRTCver). Please report this to MSRDCollectTalk@microsoft.com" -circle $circle
                        } else {
                            $isNewer = $false
                            for ($i = 0; $i -lt $latestverComponents.Count; $i++) {
                                $latestComponent = [int]$latestverComponents[$i]
                                $checkComponent = [int]$versionToCheckComponents[$i]

                                if ($latestComponent -gt $checkComponent) {
                                    $isNewer = $true
                                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $circle = "red"
                                    break
                                } else {
                                    $circle = "green"
                                }
                            }
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Remote Desktop WebRTC Redirector Service" -Message2 "$WebRTCver (Installed on: $WebRTCdate)" -circle $circle

                            if ($isNewer) {
                                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "You are not using the latest available Remote Desktop WebRTC Redirector Service version. Please consider updating. See: $webrtcRef" -circle "red"
                            }
                        }

                    } else {
                        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Error retrieving Remote Desktop WebRTC Redirector Service information" -circle "red"
                    }
                } else {
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Error retrieving Remote Desktop WebRTC Redirector Service information" -circle "red"
                }

                msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"

                msrdCheckServicePort -service RDWebRTCSvc -tcpports 9500

                #Checking reg keys
                msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
                msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Office\Teams\' -RegKey 'DisableFallback'
                msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Teams\' -RegKey 'disableAutoUpdate'
                msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Teams\' -RegKey 'DisableFallback'
                msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Teams\' -RegKey 'IsWVDEnvironment' -RegValue '1'
                msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\AddIns\WebRTC Redirector\' -RegKey 'Enabled' -RegValue '1'
                msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\AddIns\WebRTC Redirector\Policy\' -RegKey 'DisableRAILAppSharing'
                msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\AddIns\WebRTC Redirector\Policy\' -RegKey 'DisableRAILScreenSharing'
                msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\AddIns\WebRTC Redirector\Policy\' -RegKey 'ShareClientDesktop'
                msrdCheckRegPath 'HKLM:\SOFTWARE\Citrix\PortICA' 'This path should not exist on an AVD-only deployment'
                msrdCheckRegPath 'HKLM:\SOFTWARE\VMware, Inc.\VMware VDM\Agent' 'This path should not exist on an AVD-only deployment'
                msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\WOW6432Node\Citrix\WebSocketService\' -RegKey 'ProcessWhitelist' -RegValue 'msedgewebview2.exe '

                msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Microsoft Edge WebView2 Runtime"
                msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}\' -RegKey 'pv'
                msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}\' -RegKey 'pv'
                msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}\' -RegKey 'pv'

                #Teams AV Exclusions
                msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
                if (Test-Path ($global:msrdLogDir + $regDefExclFile)) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "<b>Windows Defender antivirus exclusions</b> ($avexTeamsRef)" -Message2 "(See: <a href='$regDefExclFile' target='_blank'>Defender Exclusions</a>)" -circle "blue"
                } else {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "<b>Windows Defender antivirus exclusions</b> ($avexTeamsRef)"
                }

                $recTeamsAVexclusionsProcs = @(
                    "$msrdUserProfilesDir\*\AppData\Local\Microsoft\Teams\current\teams.exe",
                    "$msrdUserProfilesDir\*\AppData\Local\Microsoft\Teams\update.exe",
                    "$msrdUserProfilesDir\*\AppData\Local\Microsoft\Teams\current\squirrel.exe",
                    "$msrdUserProfilesDir\*\AppData\Local\Microsoft\TeamsMeetingAddin",
                    "ms-teams.exe",
                    "ms-teamsupdate.exe"
                )

                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Windows Defender Processes exclusions for Teams (local config)"
                msrdTestAVExclusion -ExclPath "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Processes" -ExclValue $recTeamsAVexclusionsProcs -Scope "Teams"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Windows Defender Processes exclusions for Teams (policy config)"
                msrdTestAVExclusion -ExclPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions\Processes" -ExclValue $recTeamsAVexclusionsProcs -Scope "Teams"

            } else {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$avdcheckmsg" -circle "red"
            }
        }
    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Windows 10+ OS <span style='color: brown'>not found</span>. Skipping check (not applicable)."
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagW365 {

    #Windows 365 diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Windows 365 Boot"
    $menucatmsg = $script:msrdMenuCat
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "CPCCheck"

    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\CloudDesktop\' -RegKey 'BootToCloudMode' -RegValue '1'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\WindowsLogon\' -RegKey 'OverrideShellProgram' -RegValue '1'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\SharedPC\' -RegKey '01' -RegValue '1'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\SharedPC\' -RegKey '18' -RegValue '1'

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagW365reqUrls {

    #Windows 365 diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Windows 365 Required Endpoints"
    $menucatmsg = "AVD/W365 Infra"
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "CPCreqUrlsCheck"

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Review also the client and host <a href='#URLCheck'>AVD Required Endpoints</a>"

    if (!($global:msrdSource)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Windows 365 Enterprise"

        $w365EntUrls = [Ordered]@{
            "windows365.microsoft.com" = @(443)
            "cpcsaamssa1prodprap01.blob.core.windows.net" = @(443)
            "cpcsaamssa1prodprau01.blob.core.windows.net" = @(443)
            "cpcsaamssa1prodpreu01.blob.core.windows.net" = @(443)
            "cpcsaamssa1prodpreu02.blob.core.windows.net" = @(443)
            "cpcsaamssa1prodprna01.blob.core.windows.net" = @(443)
            "cpcsaamssa1prodprna02.blob.core.windows.net" = @(443)
            "cpcstcnryprodprap01.blob.core.windows.net" = @(443)
            "cpcstcnryprodprau01.blob.core.windows.net" = @(443)
            "cpcstcnryprodpreu01.blob.core.windows.net" = @(443)
            "cpcstcnryprodpreu02.blob.core.windows.net" = @(443)
            "cpcstcnryprodprna01.blob.core.windows.net" = @(443)
            "cpcstcnryprodprna02.blob.core.windows.net" = @(443)
            "cpcstprovprodpreu01.blob.core.windows.net" = @(443)
            "cpcstprovprodpreu02.blob.core.windows.net" = @(443)
            "cpcstprovprodprna01.blob.core.windows.net" = @(443)
            "cpcstprovprodprna02.blob.core.windows.net" = @(443)
            "cpcstprovprodprap01.blob.core.windows.net" = @(443)
            "cpcstprovprodprau01.blob.core.windows.net" = @(443)
            "prna01.prod.cpcgateway.trafficmanager.net" = @(443)
            "prna02.prod.cpcgateway.trafficmanager.net" = @(443)
            "preu01.prod.cpcgateway.trafficmanager.net" = @(443)
            "preu02.prod.cpcgateway.trafficmanager.net" = @(443)
            "prap01.prod.cpcgateway.trafficmanager.net" = @(443)
            "prau01.prod.cpcgateway.trafficmanager.net" = @(443)
            "endpointdiscovery.cmdagent.trafficmanager.net" = @(443)
            "registration.prna01.cmdagent.trafficmanager.net" = @(443)
            "registration.preu01.cmdagent.trafficmanager.net" = @(443)
            "registration.prap01.cmdagent.trafficmanager.net" = @(443)
            "registration.prau01.cmdagent.trafficmanager.net" = @(443)
            "registration.prna02.cmdagent.trafficmanager.net" = @(443)
            "login.microsoftonline.com" = @(443)
            "login.live.com" = @(443)
            "enterpriseregistration.windows.net" = @(443)
            "global.azure-devices-provisioning.net" = @(443, 5671)
            "hm-iot-in-prod-prap01.azure-devices.net" = @(443, 5671)
            "hm-iot-in-prod-prau01.azure-devices.net" = @(443, 5671)
            "hm-iot-in-prod-preu01.azure-devices.net" = @(443, 5671)
            "hm-iot-in-prod-prna01.azure-devices.net" = @(443, 5671)
            "hm-iot-in-prod-prna02.azure-devices.net" = @(443, 5671)
            "hm-iot-in-2-prod-preu01.azure-devices.net" = @(443, 5671)
            "hm-iot-in-2-prod-prna01.azure-devices.net" = @(443, 5671)
            "hm-iot-in-3-prod-preu01.azure-devices.net" = @(443, 5671)
            "hm-iot-in-3-prod-prna01.azure-devices.net" = @(443, 5671)
        }

        msrdReqURLCheck -urls $w365EntUrls

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Windows 365 Government"

        $w365GovUrls = [Ordered]@{
            "ghp01.ghp.cpcgateway.usgovtrafficmanager.net" = @(443)
            "gcp01.gcp.cpcgateway.usgovtrafficmanager.net" = @(443)
            "cpcstprovghpghp01.blob.core.usgovcloudapi.net" = @(443)
            "cpcsaamssa1ghpghp01.blob.core.usgovcloudapi.net" = @(443)
            "cpcstcnryghpghp01.blob.core.usgovcloudapi.net" = @(443)
            "cpcsacnrysa1ghpghp01.blob.core.usgovcloudapi.net" = @(443)
            "cpcstprovgcpgcp01.blob.core.usgovcloudapi.net" = @(443)
            "cpcsaamssa1gcpgcp01.blob.core.usgovcloudapi.net" = @(443)
            "cpcstcnrygcpgcp01.blob.core.usgovcloudapi.net" = @(443)
            "cpcsacnrysa1gcpgcp01.blob.core.usgovcloudapi.net" = @(443)
            "windows365.microsoft.us" = @(443)
            "portal.manage.microsoft.us" = @(443)
            "m.manage.microsoft.us" = @(443)
            "mam.manage.microsoft.us" = @(443)
            "wip.mam.manage.microsoft.us" = @(443)
            "Fef.FXPASU01.manage.microsoft.us" = @(443)
            "portal.manage.microsoft.com" = @(443)
            "m.manage.microsoft.com" = @(443)
            "fef.msuc03.manage.microsoft.com" = @(443)
            "mam.manage.microsoft.com" = @(443)
            "wip.mam.manage.microsoft.com" = @(443)
            "login.microsoftonline.us" = @(443)
            "login.live.com" = @(443)
            "login.microsoftonline.com" = @(443)
            "global.azure-devices-provisioning.us" = @(443, 5671)
            "hm-iot-in-ghp-ghp01.azure-devices.us" = @(443, 5671)
            "hm-iot-in-gcp-gcp01.azure-devices.us" = @(443, 5671)
            "endpointdiscovery.ghp.cmdagent.usgovtrafficmanager.net" = @(443)
            "endpointdiscovery.gcp.cmdagent.usgovtrafficmanager.net" = @(443)
            "registration.ghp01.cmdagent.usgovtrafficmanager.net" = @(443)
            "registration.gcp01.cmdagent.usgovtrafficmanager.net" = @(443)
            "hm-iot-in-gcb-gcb01.azure-devices.us" = @(443, 5671)
            "hm-iot-in-ghb-ghb01.azure-devices.us" = @(443, 5671)
            "rdweb.wvd.azure.us" = @(443)
            "rdbroker.wvd.azure.us" = @(443)
            "rdweb.wvd.microsoft.com" = @(443)
            "rdbroker.wvd.microsoft.com" = @(443)
            "download.microsoft.com" = @(443)
            "software-download.microsoft.com" = @(443)
        }

        msrdReqURLCheck -urls $w365GovUrls

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Intune"

        $w365IntuneUrls = [Ordered]@{
            "manage.microsoft.com" = @(80, 443)
            "prod.do.dsp.mp.microsoft.com" = @()
            "windowsupdate.com" = @()
            "dl.delivery.mp.microsoft.com" = @(443)
            "update.microsoft.com" = @(443)
            "delivery.mp.microsoft.com" = @()
            "tsfe.trafficshaping.dsp.mp.microsoft.com" = @(443)
            "emdl.ws.microsoft.com" = @(443)
            "do.dsp.mp.microsoft.com" = @()
            "notify.windows.com" = @()
            "wns.windows.com" = @(443)
            "devicelistenerprod.microsoft.com" = @(443)
            "devicelistenerprod.eudb.microsoft.com" = @(443)
            "login.windows.net" = @(443)
            "blob.core.windows.net" = @()
            "time.windows.com" = @()
            "www.msftconnecttest.com" = @(443)
            "www.msftncsi.com" = @(443)
            "s-microsoft.com" = @()
            "clientconfig.passport.net" = @(443)
            "windowsphone.com" = @(443)
            "approdimedatahotfix.azureedge.net" = @(443)
            "approdimedatapri.azureedge.net" = @(443)
            "approdimedatasec.azureedge.net" = @(443)
            "euprodimedatahotfix.azureedge.net" = @(443)
            "euprodimedatapri.azureedge.net" = @(443)
            "euprodimedatasec.azureedge.net" = @(443)
            "naprodimedatahotfix.azureedge.net" = @(443)
            "naprodimedatapri.azureedge.net" = @(443)
            "swda01-mscdn.azureedge.net" = @(443)
            "swda02-mscdn.azureedge.net" = @(443)
            "swdb01-mscdn.azureedge.net" = @(443)
            "swdb02-mscdn.azureedge.net" = @(443)
            "swdc01-mscdn.azureedge.net" = @(443)
            "swdc02-mscdn.azureedge.net" = @(443)
            "swdd01-mscdn.azureedge.net" = @(443)
            "swdd02-mscdn.azureedge.net" = @(443)
            "swdin01-mscdn.azureedge.net" = @(443)
            "swdin02-mscdn.azureedge.net" = @(443)
            "ekcert.spserv.microsoft.com" = @(443)
            "ekop.intel.com" = @(443)
            "ftpm.amd.com" = @(443)
            "itunes.apple.com" = @(443)
            "mzstatic.com" = @(443)
            "phobos.apple.com" = @(443)
            "5-courier.push.apple.com" = @(443)
            "ax.itunes.apple.com.edgesuite.net" = @(443)
            "ocsp.apple.com" = @(443)
            "phobos.itunes-apple.com.akadns.net" = @(443)
            "intunecdnpeasd.azureedge.net" = @(443)
            "channelservices.microsoft.com" = @()
            "go-mpulse.net" = @()
            "infra.lync.com" = @()
            "resources.lync.com" = @()
            "support.services.microsoft.com" = @()
            "trouter.skype.com" = @()
            "vortex.data.microsoft.com" = @(443)
            "edge.skype.com" = @(443)
            "remoteassistanceprodacs.communication.azure.com" = @(443)
            "lgmsapeweu.blob.core.windows.net" = @(443)
            "fd.api.orgmsg.microsoft.com" = @(443)
            "ris.prod.api.personalization.ideas.microsoft.com" = @(443)
            "contentauthassetscdn-prod.azureedge.net" = @(443)
            "contentauthassetscdn-prodeur.azureedge.net" = @(443)
            "contentauthrafcontentcdn-prod.azureedge.net" = @(443)
            "contentauthrafcontentcdn-prodeur.azureedge.net" = @(443)
        }
        msrdReqURLCheck -urls $w365IntuneUrls
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

#endregion AVD/RDS diag functions


#region AVD Infra functions

Function msrdDiagAgentStack {

    #AVD Agent/Stack diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "AVD Agents / SxS Stack"
    if ($global:msrdW365) { $menucatmsg = "AVD/W365 Infra" } else { $menucatmsg = "AVD Infra" }
    msrdLogDiag $LogLevel.Normal -DiagTag "AgentStackCheck" -Message $menuitemmsg

    if ($avdcheck) {
        if (Test-Path 'HKLM:\SOFTWARE\Microsoft\RDAgentBootLoader') {

            msrdCheckServicePort -service RDAgentBootLoader -stopWarning

            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
            if (msrdTestRegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\RDAgentBootLoader\' -Value 'CurrentBootLoaderVersion') {
                $AVDBLA = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\RDAgentBootLoader\' -name "CurrentBootLoaderVersion"
                $AVDbootloaderdate = (Get-ItemProperty  hklm:\software\microsoft\windows\currentversion\uninstall\* | Where-Object {($_.DisplayName -eq "Remote Desktop Agent Boot Loader" -and $_.DisplayVersion -eq $AVDBLA)}).InstallDate
                $AVDbootloaderdate = [datetime]::ParseExact($AVDbootloaderdate, "yyyyMMdd", $null).ToString("yyyy/MM/dd")

                if (Test-Path ($global:msrdLogDir + $agentBLinstfile)) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "Agent BootLoader" -Message2 "Current version (Installed on: $AVDbootloaderdate)" -Message3 "$AVDBLA (See: <a href='$agentBLinstfile' target='_blank'>AgentBootLoaderInstall</a>)" -circle "blue"
                } else {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "Agent BootLoader" -Message2 "Current version (Installed on: $AVDbootloaderdate)" -Message3 "$AVDBLA" -circle "blue"
                }

            } else {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "Agent BootLoader" -Message2 "'HKLM:\SOFTWARE\Microsoft\RDAgentBootLoader\CurrentBootLoaderVersion' <span style='color: brown'>not found</span>." -circle "red"
            }

            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
            if (msrdTestRegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\RDAgentBootLoader\' -Value 'DefaultAgent') {

                $AVDagent = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\RDAgentBootLoader\' -name "DefaultAgent"
                $AVDagentver = $AVDagent.split("_")[1]
                $AVDagentdate = (Get-ItemProperty  hklm:\software\microsoft\windows\currentversion\uninstall\* | Where-Object {($_.DisplayName -eq "Remote Desktop Services Infrastructure Agent" -and $_.DisplayVersion -eq $AVDagentver)}).InstallDate
                $AVDagentdate = [datetime]::ParseExact($AVDagentdate, "yyyyMMdd", $null).ToString("yyyy/MM/dd")

                # Split the versions into their components
                $latestverComponents = $latestAvdAgentVer -split '\.'
                $versionToCheckComponents = $AVDagentver -split '\.'

                # Ensure that both versions have the same number of components
                $isNewer = $false
                if ($latestverComponents.Count -ne $versionToCheckComponents.Count) {
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $circle = "red"
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "AVD Agent version number mismatch (latest version: $latestAvdAgentVer / current version: $AVDagentver). Please report this to MSRDCollectTalk@microsoft.com" -circle $circle
                } else {
                    for ($i = 0; $i -lt $latestverComponents.Count; $i++) {
                        $latestComponent = [int]$latestverComponents[$i]
                        $checkComponent = [int]$versionToCheckComponents[$i]

                        if ($latestComponent -gt $checkComponent) {
                            $isNewer = $true
                            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $circle = "red"
                            break
                        } elseif ($latestComponent -lt $checkComponent) {
                            $circle = "blue"
                            break
                        } else {
                            $circle = "blue"
                        }
                    }
                }

                if (Test-Path ($global:msrdLogDir + $agentInitinstfile)) {
                    if (Test-Path -Path ($global:msrdLogDir + $agentUpdateinstfile)) {
                        if (Test-Path -Path ($global:msrdLogDir + $montablesfolder) -PathType Container) {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "AVD Agent" -Message2 "Current version (Installed on: $AVDagentdate)" -Message3 "$AVDagentver (See: <a href='$agentInitinstfile' target='_blank'>AgentInstall</a> / <a href='$agentUpdateinstfile' target='_blank'>AgentUpdates</a> / <a href='$montablesfolder' target='_blank'>MonTables</a>)" -circle $circle
                        } else {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "AVD Agent" -Message2 "Current version (Installed on: $AVDagentdate)" -Message3 "$AVDagentver (See: <a href='$agentInitinstfile' target='_blank'>AgentInstall</a> / <a href='$agentUpdateinstfile' target='_blank'>AgentUpdates</a>)" -circle $circle
                        }
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "AVD Agent" -Message2 "Current version (Installed on: $AVDagentdate)" -Message3 "$AVDagentver (See: <a href='$agentInitinstfile' target='_blank'>AgentInstall</a>)" -circle $circle
                    }
                } else {
                    if (Test-Path ($global:msrdLogDir + $agentUpdateinstfile)) {
                        if (Test-Path ($global:msrdLogDir + $montablesfolder)) {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "AVD Agent" -Message2 "Current version (Installed on: $AVDagentdate)" -Message3 "$AVDagentver (See: <a href='$agentUpdateinstfile' target='_blank'>AgentInstall</a> / <a href='$montablesfolder' target='_blank'>MonTables</a>)" -circle $circle
                        } else {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "AVD Agent" -Message2 "Current version (Installed on: $AVDagentdate)" -Message3 "$AVDagentver (See: <a href='$agentUpdateinstfile' target='_blank'>AgentInstall</a>)" -circle $circle
                        }
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "AVD Agent" -Message2 "Current version (Installed on: $AVDagentdate)" -Message3 "$AVDagentver" -circle $circle
                    }
                }

                if ($isNewer) {
                    if ($global:msrdLiveDiag) {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "The current AVD Agent is not the latest available version. You might be using Scheduled Agent Update or the latest version has not been rolled out to your session host yet. If this persists long term, additional investigation may be required. " -circle "red"
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "The current AVD Agent is not the latest available version. You might be using Scheduled Agent Update or the latest version has not been rolled out to your session host yet. If this persists long term, additional investigation may be required. See: $avdagentRef" -circle "red"
                    }
                }

                if (msrdTestRegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\RDAgentBootLoader\' -Value 'PreviousAgent') {
                    $AVDagentpre = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\RDAgentBootLoader\' -name "PreviousAgent"
                    $AVDagentverpre = $AVDagentpre.split("_")[1]
                    $AVDagentdatepre = (Get-ItemProperty  hklm:\software\microsoft\windows\currentversion\uninstall\* | Where-Object {($_.DisplayName -eq "Remote Desktop Services Infrastructure Agent" -and $_.DisplayVersion -eq $AVDagentverpre)}).InstallDate
                    $AVDagentdatepre = [datetime]::ParseExact($AVDagentdatepre, "yyyyMMdd", $null).ToString("yyyy/MM/dd")
                } else {
                    $AVDagentverpre = "N/A"
                    $AVDagentdatepre = "N/A"
                }
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "Previous version (Installed on: $AVDagentdatepre)" -Message3 "$AVDagentverpre" -circle "blue"
            } else {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "'HKLM:\SOFTWARE\Microsoft\RDAgentBootLoader\DefaultAgent' <span style='color: brown'>not found</span>. This machine is either not part of an AVD host pool or it is not configured properly." -circle "red"
            }

        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "RDAgentBootLoader configuration <span style='color: brown'>not found</span>. This machine is either not part of an AVD host pool or it is not configured properly." -circle "red"
            if ($hp) {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "VM is part of host pool '$hp' but the HKLM:\SOFTWARE\Microsoft\RDAgentBootLoader registry key could not be found. You may have issues accessing this VM through AVD." -circle "red"
            }
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        if (Test-Path 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent') {

            if (msrdTestRegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent\SxsStack\' -Value 'CurrentVersion') {
                $sxsstack = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent\SxsStack' -name "CurrentVersion"
                $sxsstackpath = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent\SxsStack' -name $sxsstack
                $sxsstackver = $sxsstackpath.split("-")[1].trimend(".msi")
                $sxsstackdate = (Get-ItemProperty  hklm:\software\microsoft\windows\currentversion\uninstall\* | Where-Object {($_.DisplayName -eq "Remote Desktop Services SxS Network Stack" -and $_.DisplayVersion -eq $sxsstackver)}).InstallDate
                $sxsstackdate = [datetime]::ParseExact($sxsstackdate, "yyyyMMdd", $null).ToString("yyyy/MM/dd")

                if (Test-Path ($global:msrdLogDir + $sxsinstfile)) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "SxS Stack" -Message2 "Current version (Installed on: $sxsstackdate)" -Message3 "$sxsstackver (See: <a href='$sxsinstfile' target='_blank'>SxSStackInstall</a>)" -circle "blue"
                } else {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "SxS Stack" -Message2 "Current version (Installed on: $sxsstackdate)" -Message3 "$sxsstackver" -circle "blue"
                }

            } else {
                $sxsstackver = "N/A"
                $sxsstackdate = "N/A"
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "SxS Stack" -Message2 "Current version: <span style='color: brown'>not found</span>. Check if the SxS Stack was installed properly." -circle "red"
            }

            if (msrdTestRegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent\SxsStack\' -Value 'PreviousVersion') {
                $sxsstackpre = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent\SxsStack' -name "PreviousVersion"
                if (($sxsstackpre) -and ($sxsstackpre -ne "")) {
                    $sxsstackpathpre = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent\SxsStack' -name $sxsstackpre
                    $sxsstackverpre = $sxsstackpathpre.split("-")[1].trimend(".msi")
                    $sxsstackdatepre = (Get-ItemProperty  hklm:\software\microsoft\windows\currentversion\uninstall\* | Where-Object {($_.DisplayName -eq "Remote Desktop Services SxS Network Stack" -and $_.DisplayVersion -eq $sxsstackverpre)}).InstallDate
                    $sxsstackdatepre = [datetime]::ParseExact($sxsstackdatepre, "yyyyMMdd", $null).ToString("yyyy/MM/dd")
                } else {
                    $sxsstackverpre = "N/A"
                    $sxsstackdatepre = "N/A"
                }
            } else {
                $sxsstackverpre = "N/A"
                $sxsstackdatepre = "N/A"
            }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "Previous version (Installed on: $sxsstackdatepre)" -Message3 "$sxsstackverpre" -circle "blue"

        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "RDInfraAgent configuration <span style='color: brown'>not found</span>. This machine is either not part of an AVD host pool or it is not configured properly." -circle "red"
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        if (Test-Path 'HKLM:\SOFTWARE\Microsoft\RDMonitoringAgent') {
            if (msrdTestRegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\RDMonitoringAgent\' -Value 'CurrentVersion') {
                $genevaver = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\RDMonitoringAgent' -name "CurrentVersion"
                $genevadate = (Get-ItemProperty hklm:\software\microsoft\windows\currentversion\uninstall\* | Where-Object {($_.DisplayName -like "*Remote Desktop Services Infrastructure Geneva Agent*" -and $_.DisplayVersion -eq $genevaver)} -ErrorAction SilentlyContinue).InstallDate
                if ($genevadate) {
                    $genevadate = [datetime]::ParseExact($genevadate, "yyyyMMdd", $null).ToString("yyyy/MM/dd")
                    $circle = "blue"
                } else {
                    $genevadate = "N/A - Possible installation failure"
                    $circle = "red"; $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                }

                if (Test-Path ($global:msrdLogDir + $genevainstfile)) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "AVD Geneva Agent" -Message2 "Current version (Installed on: $genevadate)" -Message3 "$genevaver (See: <a href='$genevainstfile' target='_blank'>GenevaInstall</a>)" -circle $circle
                } else {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "AVD Geneva Agent" -Message2 "Current version (Installed on: $genevadate)" -Message3 "$genevaver" -circle $circle
                }

            } else {
                $genevaver = "N/A"
                $genevadate = "N/A"
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "AVD Geneva Agent" -Message2 "Current version: <span style='color: brown'>not found</span>. Check if the AVD Geneva Monitoring Agent was installed properly." -circle "red"
            }
        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "RDMonitoringAgent configuration <span style='color: brown'>not found</span>. This machine is either not part of an AVD host pool or it is not configured properly." -circle "red"
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent\' -RegKey 'IsRegistered' -RegValue '1' -warnMissing
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent\' -RegKey 'RegistrationToken'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent\ByPass\' -RegKey 'EnableStackVersionBypass'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent\ByPass\' -RegKey 'StackByPassVersion'

    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$avdcheckmsg" -circle "red"
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagHP {

    #AVD host pool diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "AVD Host Pool"
    if ($global:msrdW365) { $menucatmsg = "AVD/W365 Infra" } else { $menucatmsg = "AVD Infra" }
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "HPCheck"

    If (Test-Path 'HKLM:\SOFTWARE\Microsoft\RDMonitoringAgent') {
        if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\Microsoft\RDMonitoringAgent" -value "SessionHostPool") {
            $script:hp = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\RDMonitoringAgent" -name "SessionHostPool"
        } else { $hp = $false }

        if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\Microsoft\RDInfraAgent" -value "Geography") {
            $geo = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\RDInfraAgent" -name "Geography"
        } else { $geo = "N/A" }

        if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\Microsoft\RDMonitoringAgent" -value "Tenant") {
            $rg = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\RDMonitoringAgent" -name "Tenant"
        } else { $rg = "N/A" }

        if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\Microsoft\RDMonitoringAgent" -value "Cluster") {
            $cluster = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\RDMonitoringAgent" -name "Cluster"
        } else { $cluster = "N/A" }

        if ($hp) {
            if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\Microsoft\RDMonitoringAgent" -value "Ring") {
                $ring = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\RDMonitoringAgent" -name "Ring"
            } else { $ring = "N/A" }

            if (-not $global:msrdLiveDiag) {
                Add-Content $msrdDiagFile "<tr align='center'><th width='10px'><div class='circle_no'></div></th><th>Host Pool</th><th>Ring</th><th>Resource Group</th><th>Geography</th><th>Cluster</th></tr>"
            }

            if ($ring -eq "R0") {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                if ($global:msrdLiveDiag) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 4 -Message "Host Pool: $hp - Ring: $ring (Validation) - Resource Group: $rg - Geography: $geo - Cluster: $cluster"
                } else {
                   Add-Content $msrdDiagFile "<tr align='center'><td width='10px'><div class='circle_red'></div></td><td>$hp</td><td>$ring (Validation)</td><td>$rg</td><td>$geo</td><td>$cluster</td></tr>"
                }
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 4 -Message "This host pool is in the validation ring (R0). Validation ring deployments are intended for testing, not for production use!" -circle "red"
            } else {
                if ($global:msrdLiveDiag) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 4 -Message "Host Pool: $hp - Ring: $ring (Production) - Resource Group: $rg - Geography: $geo - Cluster: $cluster"
                } else {
                    Add-Content $msrdDiagFile "<tr align='center'><td width='10px'><div class='circle_white'></div></td><td>$hp</td><td>$ring (Production)</td><td>$rg</td><td>$geo</td><td>$cluster</td></tr>"
                }
            }

            if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\Microsoft\RDInfraAgent" -value "HostPoolArmPath") {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
                $armpath = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\RDInfraAgent" -name "HostPoolArmPath"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Host pool ARM path" -Message2 "$armpath"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "'HostPoolArmPath' not found. This machine is either not registered as an AVD VM or it is part of an AVD Classic deployment. AVD Classic will retire on September 30, 2026. If this VM is part of an AVD Classic deployment then you should transition to the ARM-based Azure Virtual Desktop before that date. See: $avdclassicRef" -circle "blue"
            }

        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 4 -Message "'HKLM\SOFTWARE\Microsoft\RDMonitoringAgent' reg key found, but this machine is not part of an AVD host pool. It might have host pool registration issues." -circle "red"
        }

    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 4 -Message "'HKLM\SOFTWARE\Microsoft\RDMonitoringAgent' reg key not found. This machine is either not part of an AVD host pool or it is not configured properly." -circle "red"
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}


Function msrdDiagHealthCheck {

    #AVD latest Health Check results
    $global:msrdSetWarning = $false
    $menuitemmsg = "AVD Health Check"
    if ($global:msrdW365) { $menucatmsg = "AVD/W365 Infra" } else { $menucatmsg = "AVD Infra" }
    msrdLogDiag $LogLevel.Normal -DiagTag "AVDHealthCheck" -Message $menuitemmsg

    if ($avdcheck) {
        if (Test-Path 'HKLM:\SOFTWARE\Microsoft\RDInfraAgent\HealthCheckReport') {

            $HCjsonString = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\RDInfraAgent\HealthCheckReport\" -Name "AgentHealthCheckReport"
            $HCjsonObject = ConvertFrom-Json $HCjsonString

            foreach ($entry in $HCjsonObject.PSObject.Properties) {
                $healthCheck = $entry.Value

                $lastHealthCheckInUTC = $healthCheck.AdditionalFailureDetails.LastHealthCheckInUTC
                try {
                    $dateTimeFromString = Get-Date $lastHealthCheckInUTC
                } catch {
                    msrdLogException ("$(msrdGetLocalizedText "errormsg") Invoke-WebRequest $dateTimeFromString") -ErrObj $_
                    continue  # Skip to the next iteration of the loop
                }
                $currentDateTime = Get-Date
                $age = $currentDateTime - $dateTimeFromString
                $lastHealthCheckInUTC = $lastHealthCheckInUTC -replace 'T', ' ' -replace 'Z', ''
                $lastHealthCheckInUTC += " ($($age.Days)d $($age.Hours)h $($age.Minutes)m $($age.Seconds)s ago)"

                $healthCheckResult = $healthCheck.HealthCheckResult
                $message = $healthCheck.AdditionalFailureDetails.Message
                $errorCode = $healthCheck.AdditionalFailureDetails.ErrorCode

                # Display ErrorCode only if it's different from 0
                if ($errorCode -ne 0) {
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "<b>$($entry.Name)</b>"
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "LastHealthCheckInUTC" -Message2 $lastHealthCheckInUTC -circle "blue"
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "HealthCheckResult" -Message2 $healthCheckResult -circle "red"
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Message" -Message2 $message -circle "red"
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "ErrorCode" -Message2 $errorCode -circle "red"
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
                } else {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "<b>$($entry.Name)</b>"
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "LastHealthCheckInUTC" -Message2 $lastHealthCheckInUTC -circle "blue"
                    if ($healthCheckResult -eq 1) { $HCcircle = "green" } else { $HCcircle = "blue" }
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "HealthCheckResult" -Message2 $healthCheckResult -circle $HCcircle
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Message" -Message2 $message -circle $HCcircle
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
                }
            }
        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Health Check Report not found" -circle "red"
        }
    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$avdcheckmsg" -circle "red"
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}


function msrdReqURLCheck {
	param(
        [ValidateNotNullOrEmpty()]$urls
    )

    foreach ($entry in $urls.GetEnumerator()) {
        $url = $entry.Key
        $ports = $entry.Value

        if ($url -notlike "1*") {
            try {
                $dnscheck = Resolve-DnsName -Name $url -QuickTimeout -ErrorAction SilentlyContinue
                if ($dnscheck) { $msg3dns = "DNS resolution: <span style='color: green'>Successful</span>" } else { $msg3dns = "DNS resolution: <span style='color: red'>Failed</span>" }
            } catch {
                $failedCommand = $_.InvocationInfo.Line.TrimStart()
                $failedCommand = $failedCommand -replace [regex]::Escape("`$url"), $url

                msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
                $msg3dns = "DNS resolution: <span style='color: red'>Failed</span>"
            }
        } else {
            $msg3dns = ""
        }

        $msg3tcp = ""; $errcounter = 0
        if ($ports.Count -gt 0) {
            foreach ($port in $ports) {
				$tcpcheck = msrdTestTCP -address $url -port $port
				if ($tcpcheck[0] -eq "True") {
					$msg3tcp += "TCP $port" + ": <span style='color: green'>Reachable</span>"
				} else {
					$msg3tcp += "TCP $port" + ": <span style='color: red'>Not reachable</span>"
                    $errcounter += 1
				}

                if ($port -ne $ports[-1]) { $msg3tcp += " / " }
                if ($errcounter -gt 0) { $msg3tcp += " (See: <a href='$msrdErrorfileurl' target='_blank'>MSRD-Collect-Error</a>)" }
			}
        }

        if (($dnscheck -or ($msg3dns -eq "")) -and (($errcounter -eq 0) -or ($ports.Count -eq 0))) {
            $urlcircle = "green"
        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            $urlcircle = "red"
        }

        if ($msg3dns -ne "") {
            if ($ports.Count -gt 0) {
                $message3 = "$msg3dns / $msg3tcp"
            } else {
                $message3 = $msg3dns
            }
        } elseif ($ports.Count -gt 0) {
            $message3 = $msg3tcp
        } else {
			$message3 = "no information avaialble"
            $urlcircle = "red"
		}
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 $url -Message3 $message3 -circle $urlcircle
    }
}

Function msrdDiagURL {

    #AVD required URLs diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "AVD Required Endpoints"
    if ($global:msrdW365) { $menucatmsg = "AVD/W365 Infra" } else { $menucatmsg = "AVD Infra" }
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "URLCheck"

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "<b>AVD Client Endpoints</b>"

    $RDCUrlsAzAll = [Ordered]@{
        "go.microsoft.com" = @(443)
        "aka.ms" = @(443)
        "privacy.microsoft.com" = @(443)
        "query.prod.cms.rt.microsoft.com" = @(443)
        "learn.microsoft.com" = @(443)
    }

    $RDCUrlsAzCloud = [Ordered]@{
        "login.microsoftonline.com" = @(443)
        "wvd.microsoft.com" = @()
        "servicebus.windows.net" = @()
    }

    $RDCUrlsAzUSGov = [Ordered]@{
        "login.microsoftonline.us" = @(443)
        "wvd.azure.us" = @()
        "servicebus.usgovcloudapi.net" = @()
    }

    $RDCUrlsAzChina = [Ordered]@{
        "wvd.azure.cn" = @()
        "servicebus.chinacloudapi.cn" = @()
    }

    $w365clienturls = [Ordered]@{
        "azure.com" = @(80,443)
        "graph.microsoft.com" = @(443)
        "microsoft.com" = @(80,443)
        "msauth.net" = @()
        "msedge.net" = @()
        "msftauth.net" = @()
        "msocdn.com" = @()
        "office.com" = @(80,443)
        "office.net" = @()
        "office365.com" = @(80,443)
        "outlook.live.com" = @(80,443)
        "windows.cloud.microsoft" = @(443)
        "windows365.microsoft.com" = @(443)
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Azure (all)"
    msrdReqURLCheck -urls $RDCUrlsAzAll
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Azure Cloud specific"
    msrdReqURLCheck -urls $RDCUrlsAzCloud
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Azure for US Government specific"
    msrdReqURLCheck -urls $RDCUrlsAzUSGov
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Azure China specific"
    msrdReqURLCheck -urls $RDCUrlsAzChina
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Windows App specific"
    msrdReqURLCheck -urls $w365clienturls

    if (($global:msrdAVD -or $global:msrdW365) -and !($global:msrdSource)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "<b>AVD Host Endpoints</b>"

        $AVDUrlsAzAll = [Ordered]@{
            "169.254.169.254" = @(80)
            "168.63.129.16" = @(80)
        }

        $AVDUrlsAzCloud = [Ordered]@{
            "login.microsoftonline.com" = @(443)
            "wvd.microsoft.com" = @()
            "prod.warm.ingest.monitor.core.windows.net" = @()
            "catalogartifact.azureedge.net" = @(443)
            "gcs.prod.monitoring.core.windows.net" = @(443)
            "kms.core.windows.net" = @(1688)
            "azkms.core.windows.net" = @(1688)
            "mrsglobalsteus2prod.blob.core.windows.net" = @(443)
            "wvdportalstorageblob.blob.core.windows.net" = @(443)
            "oneocsp.microsoft.com" = @(80)
            "www.microsoft.com" = @(80)
        }

        $AVDUrlsAzUSGov = [Ordered]@{
            "login.microsoftonline.us" = @(443)
            "wvd.azure.us" = @()
            "prod.warm.ingest.monitor.core.usgovcloudapi.net" = @()
            "gcs.monitoring.core.usgovcloudapi.net" = @(443)
            "kms.core.usgovcloudapi.net" = @(1688)
            "mrsglobalstugviffx.blob.core.usgovcloudapi.net" = @(443)
            "wvdportalstorageblob.blob.core.usgovcloudapi.net" = @(443)
            "ocsp.msocsp.com" = @(80)
        }

        $AVDUrlsAzChina = [Ordered]@{
            "login.partner.microsoftonline.cn" = @(443)
            "wvd.azure.cn" = @()
            "mooncake.warmpath.chinacloudapi.cn" = @(443)
            "monitoring.core.chinacloudapi.cn" = @(443)
            "blob.core.chinacloudapi.cn" = @()
            "servicebus.chinacloudapi.cn" = @()
            "table.core.chinacloudapi.cn" = @()
            "queue.core.chinacloudapi.cn" = @()
            "kms.core.chinacloudapi.cn" = @(1688)
            "mrsglobalstcne2mc.blob.core.chinacloudapi.cn" = @(443)
            "wvdportalcontainer.blob.core.chinacloudapi.cn" = @(443)
            "crl.digicert.cn" = @(443)
            "microsoft.com" = @(443)
            "prod.warm.ingest.monitor.core.chinacloudapi.cn" = @()
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Azure (all)"
        msrdReqURLCheck -urls $AVDUrlsAzAll
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Azure Cloud specific"
        msrdReqURLCheck -urls $AVDUrlsAzCloud
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Azure for US Government specific"
        msrdReqURLCheck -urls $AVDUrlsAzUSGov
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Azure China specific"
        msrdReqURLCheck -urls $AVDUrlsAzChina


        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        If ($avdcheck) {
            $toolfolder = Get-ChildItem $msrdAgentpath -Directory | Foreach-Object {If (($_.psiscontainer) -and ($_.fullname -like "*RDAgent_*")) { $_.Name }} | Select-Object -Last 1
            $URLCheckToolPath = $msrdAgentpath + $toolfolder + "\WVDAgentUrlTool.exe"

            if (Test-Path $URLCheckToolPath) {
                Try {
                    $urlout = & $URLCheckToolPath
                    $urlna = $false
                    foreach ($urlline in $urlout) {
                        if (!($urlline -eq "") -and !($urlline -like "*===========*") -and !($urlline -like $null) -and ($urlline -ne "WVD") -and !($urlline -like "*Acquired on*") -and !($urlline -like "*Agent URL Tool*") -and !($urlline -like "*Copyright*")) {

                            if ($urlline -like "*Not Accessible*") { $urlna = $true }

                            if ($urlline -like "*Version*") {
                                $uver = $urlline.Split(" ")[1]
                                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Azure Virtual Desktop Agent URL Tool" -Message2 "$uver"

                            } elseif (($urlline -like "*.com") -or ($urlline -like "*.net") -or ($urlline -like "*.us") -or ($urlline -like "*.cn")) {
                                if ($urlna) {
                                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "$urlline" -circle "red"
                                } else {
                                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "$urlline" -circle "green"
                                }

                            } elseif ($urlline -like "UrlsAccessibleCheck*") {
                                $urlc2 = $urlline.Split(": ")[-1]
                                $urlc1 = $urlline.Trimend($urlc2)
                                if ($urlc2 -like "*HealthCheckSucceeded*") {
                                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$urlc1" -Message2 "$urlc2" -circle "green"
                                } else {
                                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$urlc1" -Message2 "$urlc2" -circle "red"
                                }

                            } elseif (($urlline -like "*Unable to extract*") -or ($urlline -like "*Failed to connect to the Agent*") -or ($urlline -like "*Tool failed with*")) {
                                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$urlline" -circle "red"

                            } else {
                                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$urlline"
                            }
                        }
                    }
                } Catch {
                    $failedCommand = $_.InvocationInfo.Line.TrimStart()
                    msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
                    Continue
                }
            } else {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$msrdAgentpath found, but 'WVDAgentUrlTool.exe' is missing, skipping check. You should be running agent version 1.0.2944.1200 or higher." -circle "red"
            }

        } else {
            if (!($global:msrdSource)) {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$avdcheckmsg" -circle "red"
            }
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "<b>Optional URLs (not required for AVD but needed for other services):</b>"

        $optionalUrlsAzAll = [Ordered]@{
            "www.msftconnecttest.com" = @(443)
            "events.data.microsoft.com" = @(443)
            "prod.do.dsp.mp.microsoft.com" = @()
            "azure-dns.com" = @()
            "azure-dns.net" = @()
            "oneclient.sfx.ms" = @(443)
            "g.live.com" = @(80,443)
            "digicert.com" = @(80, 443)
            "verisign.com" = @(80, 443)
            "verisign.net" = @(80, 443)
            "globalsign.com" = @(80, 443)
            "globalsign.net" = @(80, 443)
        }

        $optionalurls = [Ordered]@{
            "login.windows.net" = @(443)
            "crl.microsoft.com" = @(80, 443)
            "mscrl.microsoft.com" = @(80, 443)
            "passwordreset.microsoftonline.com" = @(80, 443)
            "auth.microsoft.com" = @()
            "entrust.net" = @(80, 443)
        }

        $optionalurlsChina = [Ordered]@{
            "login.chinacloudapi.cn" = @(443)
            "digicert.cn" = @()
            "globalsign.cn" = @(80, 443)
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Azure (all)"
        msrdReqURLCheck -urls $optionalUrlsAzAll
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Azure Cloud"
        msrdReqURLCheck -urls $optionalurls
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Azure China"
        msrdReqURLCheck -urls $optionalurlsChina
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

function msrdCheckSiteURLStatus {
    Param([Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$URIkey, [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$URL)

    try {
        $request = Invoke-WebRequest -Uri $URL -UseBasicParsing -TimeoutSec 30

        if ($request) {
            if ($request.StatusCode -eq "200") {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message $URIkey -Message2 "$URL" -Message3 "Reachable ($($request.StatusDescription) - $($request.StatusCode))" -circle "green"
            } else {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message $URIkey -Message2 "$URL" -Message3 "Not reachable ($($request.StatusDescription) - $($request.StatusCode))" -circle "red"
            }
        }
    } catch {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message $URIkey -Message2 "$URL" -Message3 "Not reachable" -circle "red"
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
    }
}

Function msrdDiagURIHealth {

    #AVD service URI diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "AVD Services URI Health"
    if ($global:msrdW365) { $menucatmsg = "AVD/W365 Infra" } else { $menucatmsg = "AVD Infra" }
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "BrokerURICheck"

    $brokerURIregpath = "HKLM:\SOFTWARE\Microsoft\RDInfraAgent\"

    if (Test-Path $brokerURIregpath) {
        $brokerURIregkey = "BrokerURI"
            if (msrdTestRegistryValue -path $brokerURIregpath -value $brokerURIregkey) {
                $brokerURI = Get-ItemPropertyValue -Path $brokerURIregpath -name $brokerURIregkey
                $brokerURI = $brokerURI + "api/health"
                msrdCheckSiteURLStatus $brokerURIregkey $brokerURI
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "'$brokerURIregpath$brokerURIregkey' <span style='color: brown'>not found</span>. This machine doesn't seem to be a AVD VM or it is not configured properly." -circle "red"
            }

        $brokerURIGlobalregkey = "BrokerURIGlobal"
            if (msrdTestRegistryValue -path $brokerURIregpath -value $brokerURIGlobalregkey) {
                $brokerURIGlobal = Get-ItemPropertyValue -Path $brokerURIregpath -name $brokerURIGlobalregkey
                $brokerURIGlobal = $brokerURIGlobal + "api/health"
                msrdCheckSiteURLStatus $brokerURIGlobalregkey $brokerURIGlobal
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "'$brokerURIregpath$brokerURIGlobalregkey' <span style='color: brown'>not found</span>. This machine doesn't seem to be a AVD VM or it is not configured properly." -circle "red"
            }

        $diagURIregkey = "DiagnosticsUri"
            if (msrdTestRegistryValue -path $brokerURIregpath -value $diagURIregkey) {
                $diagURI = Get-ItemPropertyValue -Path $brokerURIregpath -name $diagURIregkey
                $diagURI = $diagURI + "api/health"
                msrdCheckSiteURLStatus $diagURIregkey $diagURI
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "'$brokerURIregpath$diagURIregkey' <span style='color: brown'>not found</span>. This machine doesn't seem to be a AVD VM or it is not configured properly." -circle "red"
            }

        $BrokerResourceIdURIGlobalregkey = "BrokerResourceIdURIGlobal"
            if (msrdTestRegistryValue -path $brokerURIregpath -value $diagURIregkey) {
                $BrokerResourceIdURIGlobal = Get-ItemPropertyValue -Path $brokerURIregpath -name $BrokerResourceIdURIGlobalregkey
                $BrokerResourceIdURIGlobal = $BrokerResourceIdURIGlobal + "api/health"
                msrdCheckSiteURLStatus $BrokerResourceIdURIGlobalregkey $BrokerResourceIdURIGlobal
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "'$brokerURIregpath$BrokerResourceIdURIGlobalregkey' <span style='color: brown'>not found</span>. This machine doesn't seem to be a AVD VM or it is not configured properly." -circle "red"
            }

    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$avdcheckmsg" -circle "red"
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagHCI {

    #AVD Azure Stack HCI diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Azure Stack HCI"
    if ($global:msrdW365) { $menucatmsg = "AVD/W365 Infra" } else { $menucatmsg = "AVD Infra" }
    msrdLogDiag $LogLevel.Normal -Message "Azure Stack HCI" -DiagTag "HCICheck"

    if ($avdcheck) {
        msrdCheckServicePort -service GCArcService -skipWarning 1
        msrdCheckServicePort -service ExtensionService -skipWarning 1
        msrdCheckServicePort -service himds -skipWarning 1
    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$avdcheckmsg" -circle "red"
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

function msrdAVDShortpathCheck {

    if ($global:avdnettestpath -ne "") {
        $avdok = $false
        try {
            cmd /c $global:avdnettestpath | Out-File "avdnettesttemp.txt"
            $avdout = Get-Content "avdnettesttemp.txt"
            Remove-Item "avdnettesttemp.txt" -Force

            $avdout = $avdout -split "`n" | Where-Object { $_ -ne "" }
            $avdpattern = '(?i)\b(?:https?://|www\.)\S+\b'

            if ($avdout) {
                foreach ($avdline in $avdout) {
                    if ($avdline -like "*AVD Network Test Version*") {
                        $aver = $avdline.Split(" ")[-1]
                        if (Test-Path -Path ($global:msrdLogDir + $avdnettestfile)) {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "AVD Network Test Version" -Message2 "$aver (See: <a href='$avdnettestfile' target='_blank'>avdnettest</a>)" -circle "blue"
                        } else {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "AVD Network Test Version" -Message2 "$aver"
                        }
                    } elseif ($avdline -like "*...*") {
                        $avdc2 = $avdline.Split("... ")[-1]
                        $avdc1 = $avdline.Trimend($avdc2)
                        if ($avdc2 -like "*OK*") {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$avdc1" -Message2 "$avdc2" -circle "green"
                        } else {
                            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$avdc1" -Message2 "$avdc2" -circle "red"
                        }
                    } elseif (($avdline -like "*cone shaped*") -or ($avdline -like "*you have access to TURN servers*")) {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$avdline" -circle "green"
                        $avdok = $true
                    } else {
                        if ($avdline -match $avdpattern) {
                            $avdreplace = "<a href='https://go.microsoft.com/fwlink/?linkid=2204021' target='_blank'>https://go.microsoft.com/fwlink/?linkid=2204021</a>"
                            $avdline = $avdline -replace $avdpattern, $avdreplace
                        }

                        if ($avdok) {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$avdline" -circle "green"
                        } else {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$avdline" -circle "red"
                        }
                    }
                }
            }

        } catch {
            $failedCommand = $_.InvocationInfo.Line.TrimStart()
            msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
            Continue
        }
    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        $notfoundmsg = "avdnettest.exe could not be found. Skipping check. Information on RDP Shortpath for AVD availability will be incomplete. Make sure you download and unpack the full package of MSRD-Collect or TSS."
        if ($global:msrdGUI) {
            msrdAddOutputBoxLine ("$notfoundmsg") "Magenta"
        } else {
            msrdLogMessage $LogLevel.Warning $notfoundmsg
        }
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$notfoundmsg" -circle "red"
    }
}

Function msrdDiagShortpath {

    #AVD Shortpath diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "RDP Shortpath"
    if ($global:msrdW365) { $menucatmsg = "AVD/W365 Infra" } else { $menucatmsg = "AVD Infra" }
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "UDPCheck"

    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\Client\' -RegKey 'fClientDisableUDP'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Terminal Server Client\' -RegKey 'DisableUDPTransport'

    If (!($global:msrdOSVer -like "*Server*2008*")) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        #Checking if there are Firewall rules for UDP 3390
        $fwrulesUDP = (Get-NetFirewallPortFilter -Protocol UDP | Where-Object { $_.localport -eq '3390' } | Get-NetFirewallRule)
        if ($fwrulesUDP.count -eq 0) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Windows Firewall rule(s) for UDP port 3390" -Message2 "not found"
        } else {
            if (Test-Path $fwrfile) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Windows Firewall rule(s) for UDP port 3390" -Message "found (See: <a href='$fwrfile' target='_blank'>FirewallRules</a>)" -circle "blue"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Windows Firewall rule(s) for UDP port 3390" -Message2 "found" -circle "blue"
            }
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        # Checking Teredo configuration
        $teredo = Get-NetTeredoConfiguration
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Teredo configuration"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "Type" -Message3 "$($teredo.Type)"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "ServerName" -Message3 "$($teredo.ServerName)"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "RefreshIntervalSeconds" -Message3 "$($teredo.RefreshIntervalSeconds)"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "ClientPort" -Message3 "$($teredo.ClientPort)"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "ServerVirtualIP" -Message3 "$($teredo.ServerVirtualIP)"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "DefaultQualified" -Message3 "$($teredo.DefaultQualified)"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "ServerShunt" -Message3 "$($teredo.ServerShunt)"
    }

    if (($global:msrdAVD -or $global:msrdW365) -and !($global:msrdSource)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"

        if ($avdcheck) {
            #Checking for events 131 in the past 5 days
            $StartTimeSP = (Get-Date).AddDays(-5)
            If (Get-WinEvent -FilterHashtable @{logname="Microsoft-Windows-RemoteDesktopServices-RdpCoreCDV/Operational"; id="131"; StartTime=$StartTimeSP} -MaxEvents 1 -ErrorAction SilentlyContinue | where-object { $_.Message -like '*UDP*' }) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "UDP events 131 have been found in the 'Microsoft-Windows-RemoteDesktopServices-RdpCoreCDV/Operational' event logs" -Message2 "RDP Shortpath <span style='color: green'>has been used</span> within the last 5 days" -circle "green"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "UDP events 131 have not been found in the 'Microsoft-Windows-RemoteDesktopServices-RdpCoreCDV/Operational' event logs" -Message2 "RDP Shortpath <span style='color: brown'>has not been used</span> within the last 5 days" -circle "blue"
            }

            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "RDP Shortpath for <span style='color: blue'>managed</span> networks"
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fUseUdpPortRedirector' -RegValue '1' -OptNote 'Computer Policy: Enable RDP Shortpath for managed networks'
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'UdpRedirectorPort' -RegValue '3390' -OptNote 'Computer Policy: Enable RDP Shortpath for managed networks'

            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
            # Checking if TermService is listening for UDP
            $udplistener = Get-NetUDPEndpoint -OwningProcess ((get-ciminstance win32_service -Filter "name = 'TermService'").ProcessId) -LocalPort 3390 -ErrorAction SilentlyContinue

            if ($udplistener) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "TermService is listening on UDP port 3390."
            } else {
                # Checking the process occupying UDP port 3390
                $procpid = (Get-NetUDPEndpoint -LocalPort 3390 -LocalAddress 0.0.0.0 -ErrorAction SilentlyContinue).OwningProcess

                if ($procpid) {
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "TermService is NOT listening on UDP port 3390. RDP Shortpath is not configured properly. The UDP port 3390 is being used by" -circle "red"
                    tasklist /svc /fi "PID eq $procpid" | Out-File -Append $msrdDiagFile
                } else {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "No process is listening on UDP port 3390. RDP Shortpath for managed networks is not enabled." -circle "blue"
                }
            }

            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "RDP Shortpath for <span style='color: blue'>public</span> networks"
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'SelectTransport' -RegValue '0' -OptNote 'Computer Policy: Select RDP transport protocols'
            msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\' -RegKey 'ICEControl'
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'ICEEnableClientPortRange'
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'ICEClientPortBase'
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'ICEClientPortRange'

        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$avdcheckmsg" -circle "red"
        }
    }

    #Checking STUN server connectivity and NAT type
    if (!($global:msrdRDS)) {
        if ($global:msrdAVD -or $global:msrdW365) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        }
        msrdAVDShortpathCheck
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

#endregion AVD Infra functions


#region AD functions

Function msrdDiagEntraJoin {

    #Microsoft Entra join diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Microsoft Entra Join"
    $menucatmsg = "Active Directory"
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "AADJCheck"

    if (!($global:msrdOSVer -like "*Server*2008*") -and !($global:msrdOSVer -like "*Server*2012*")) {
        $script:DsregCmdStatus = try {
            dsregcmd /status
        } catch {
            $failedCommand = $_.InvocationInfo.Line.TrimStart()
            msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_

            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "An error occurred during 'dsregcmd /status'. See <a href='$msrdErrorfileurl' target='_blank'>MSRD-Collect-Error</a> for more information." -circle "red"
            Continue
        }

        Function msrdGetDsregcmdInfo {
            Param([Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$dsregentry, [switch]$file = $false)

            $global:msrdSetWarning = $false
            $menuitemmsg = "Microsoft Entra Join"
            $menucatmsg = "Active Directory"

            foreach ($entry in $script:DsregCmdStatus) {
                $ds1 = $entry.Split(":")[0]
                $ds1 = $ds1.Trim()
                if ($ds1 -like "*$dsregentry*") {
                    $ds2 = $entry -split ":" | Select-Object -Skip 1
                    if (($ds2 -like "*FAILED*") -or ($ds2 -like "*Error*")) { $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1; $dsregcircle = "red" } else { $dsregcircle = "blue" }
                    if ($file) {
                        if (Test-Path ($global:msrdLogDir + $dsregfile)) {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message $ds1 -Message2 "$ds2" -Message3 "(See: <a href='$dsregfile' target='_blank'>Dsregcmd</a>)" -circle $dsregcircle
                        } else {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message $ds1 -Message2 "$ds2" -circle $dsregcircle
                        }
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message $ds1 -Message2 "$ds2" -circle $dsregcircle
                    }
                }
            }

            if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
        }

        msrdGetDsregcmdInfo 'AzureAdJoined' -file
        msrdGetDsregcmdInfo 'WorkplaceJoined'
        msrdGetDsregcmdInfo 'DeviceAuthStatus'
        msrdGetDsregcmdInfo 'TenantName'
        msrdGetDsregcmdInfo 'TenantId'
        msrdGetDsregcmdInfo 'DeviceID'
        msrdGetDsregcmdInfo 'DeviceCertificateValidity'
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\pku2u\' -RegKey 'AllowOnlineID' -RegValue '1'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDJ\' -RegKey 'AzureVmComputeMetadataEndpoint' -RegValue 'http://169.254.169.254/metadata/instance/compute'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDJ\' -RegKey 'AzureVmMsiTokenEndpoint' -RegValue 'http://169.254.169.254/metadata/identity/oauth2/token'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDJ\' -RegKey 'AzureVmTenantIdEndpoint' -RegValue 'http://169.254.169.254/metadata/identity/info'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin\' -RegKey 'BlockAADWorkplaceJoin'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WorkplaceJoin\' -RegKey 'autoWorkplaceJoin'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\IdentityStore\LoadParameters\{B16898C6-A148-4967-9171-64D755DA8520}\' -RegKey 'Enabled'

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdGetDCInfo {

        Try {
            $vmdomain = [System.Directoryservices.Activedirectory.Domain]::GetComputerDomain()
            $trusteddc = nltest /sc_query:$vmdomain

            foreach ($entry in $trusteddc) {
                if (!($entry -like "The command completed*") -and !($entry -like "*correctement*") -and !($entry -like "*correctamente*") -and !($entry -like "*Befehl wurde *")) {
                    if (($entry -like "*Trusted DC Name*") -or ($entry -like "*Nom du contrôleur de domaine approuvé*") -or ($entry -like "*Nombre DC de confianza*") -or ($entry -like "*Vertrauenswürdiger Domänencontrollername*")) {
                        $tdcn = $entry.Split(" ")[3]
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Trusted DC Name" -Message2 "$tdcn" -circle "blue"
                    } elseif (($entry -like "*Connection Status*") -or ($entry -like "*Statut de la connexion*") -or ($entry -like "*Estado de conexión*")) {
                        $tdccs = $entry.Split(" ")[-1]
                        if ($tdccs -like "*Success*") {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Trusted DC Connection Status" -Message2 "$tdccs" -circle "green"
                        } else {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Trusted DC Connection Status" -Message2 "$tdccs" -circle "blue"
                        }
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$entry"
                    }
                }
            }

            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
            $alldc = nltest /dnsgetdc:$vmdomain
            foreach ($dcentry in $alldc) {
                if (!($dcentry -like "The command completed*") -and !($dcentry -like "*correctement*") -and !($dcentry -like "*correctamente*") -and !($dcentry -like "*Befehl wurde *")) {
                    if (($dcentry -like "*DCs in pseudo-random order*") -or ($dcentry -like "*Site specific*") -or ($dcentry -like "*dans un ordre pseudo*") -or ($dcentry -like "*Nom spécifique*") -or ($dcentry -like "*en orden pseudoaleatorio*") -or ($dcentry -like "*específico del*") -or ($dcentry -like "*Liste der Domänencontroller in*") -or ($dcentry -like "*standortspezifisch*")) {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$dcentry"
                    } else {
                        $dc0 = $dcentry.split(" ")[0]
                        $dc1 = $dcentry.split(" ")[1]
                        $dc2 = $dcentry.split(" ")[2]
                        if (($dc0 -eq "") -and ($dc1 -eq "") -and ($dc2 -eq "")) {
                            $dcfqdn = $dcentry.split(" ")[3]
                            $dcip = $dcentry.trim("$dc0 + $dc1 + $dc2")
                            $dcip2 = $dcip.trim("$dcfqdn")
                            if ($dcip2) {
                                $dcip2 = $dcip2.TrimStart()
                                if ($global:msrdLiveDiag) { $dcip2 = $dcip2 -replace '\s+', ' / ' } else { $dcip2 = $dcip2 -replace '\s+', '<br>' }
                            }

                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$dcfqdn" -Message3 "$dcip2" -circle "blue"
                        } else {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "$dcentry" -circle "blue"
                        }
                    }
                }
            }

            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
            $alltrust = nltest /domain_trusts /all_trusts
            foreach ($trustentry in $alltrust) {
                if (!($trustentry -like "The command completed*") -and !($trustentry -like "*correctement*") -and !($trustentry -like "*correctamente*") -and !($trustentry -like "*Befehl wurde *")) {
                    if (($trustentry -like "*List of domain trusts*") -or ($trustentry -like "*Liste des approbations*")) {
                        if (Test-Path ($global:msrdLogDir + $domtrustfile)) {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$trustentry" -Message2 "(See: <a href='$domtrustfile' target='_blank'>Nltest-domtrust</a>)" -circle "blue"
                        } else {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$trustentry"
                        }
                    } else {
                        $trust1 = $trustentry.split("(")[0]; if ($trust1) { $trust1 = $trust1.TrimStart() }
                        $trust2 = $trustentry.trimstart($trust1)
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$trust1" -Message3 "$trust2" -circle "blue"
                    }
                }
            }
        } Catch {
            $failedCommand = $_.InvocationInfo.Line.TrimStart()
            msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_

            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "An error occurred while trying to retrieve DC information. See <a href='$msrdErrorfileurl' target='_blank'>MSRD-Collect-Error</a> for more information." -circle "red"
        }
}

Function msrdDiagDC {

    #Domain diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Domain"
    $menucatmsg = "Active Directory"
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "DCCheck"

    if ($isDomain) {

        Try {
            $outcmd = Test-ComputerSecureChannel -Verbose 4>&1
            foreach ($outopt in $outcmd) {
                if ($outopt -like "False") {
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1"-Message "Domain secure channel connection" -Message2 "$outopt" -circle "red"
                } elseif ($outopt -like "True") {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Domain secure channel connection" -Message2 "$outopt" -circle "green"
                } elseif ($outopt -like "*broken*") {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$outopt" -circle "red"
                } elseif (($outopt -like "*good condition*") -or ($outopt -like "*guten Zustand*")) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$outopt" -circle "green"
                } elseif (!($outopt -like "*Performing the operation*") -and !($outopt -like "*Ausführen des Vorgangs*")) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$outopt" -circle "blue"
                }
            }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        } Catch {
            $failedCommand = $_.InvocationInfo.Line.TrimStart()
            msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_

            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Could not test secure channel connection. See <a href='$msrdErrorfileurl' target='_blank'>MSRD-Collect-Error</a> for more information." -circle "red"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        }

        msrdGetDCInfo

    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "This machine is not joined to a domain." -circle "red"
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

#endregion AD functions


#region Networking functions

Function msrdGetDNSInfo {

    Try {
        $dnsip = Get-DnsClientServerAddress -AddressFamily IPv4
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Local network interface DNS configuration"
        foreach ($entry in $dnsip) {
            if (!($entry.InterfaceAlias -like "Loopback*")) {
                $ip = $entry.ServerAddresses
                if ($global:msrdLiveDiag) { $ip = $ip -join " / " } else { $ip = $ip -join "<br>" }
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($entry.InterfaceAlias)" -Message3 "$ip" -circle "blue"
            }
        }
    } Catch {
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
        Continue
    }

    Try {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        $vmdomain = [System.Directoryservices.Activedirectory.Domain]::GetComputerDomain()
        $dcdns = $vmdomain | ForEach-Object {$_.DomainControllers} |
            ForEach-Object {
                $hostEntry= [System.Net.Dns]::GetHostByName($_.Name)
                New-Object -TypeName PSObject -Property @{
                        Name = $_.Name
                        IPAddress = $hostEntry.AddressList[0].IPAddressToString
                    }
                } | Select-Object Name, IPAddress

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "DNS servers available in the domain '$($vmdomain.Name)'"
        foreach ($dcentry in $dcdns) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($dcentry.Name)" -Message3 "$($dcentry.IPAddress)"
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    } Catch {
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
    }
}

Function msrdDiagDNS {

    #DNS diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "DNS"
    $menucatmsg = "Networking"
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "DNSCheck"

    msrdGetDNSInfo

    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters\' -RegKey 'EnableNetbios' -OptNote 'Computer Policy: Configure NetBIOS settings'

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdGetFirewallInfo {

    msrdCheckServicePort -service mpssvc

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    $FWProfiles = Get-NetFirewallProfile -PolicyStore ActiveStore

    if (Test-Path ($global:msrdLogDir + $fwrfile)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Windows Firewall profiles" -Message2 "(See: <a href='$fwrfile' target='_blank'>FirewallRules</a>)" -circle "blue"
    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Windows Firewall profiles"
    }

    $FWProfiles | ForEach-Object -Process {
        If ($_.Enabled -eq "True") {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($_.Name) profile" -Message3 "Enabled" -circle "green"
        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($_.Name) profile" -Message3 "Disabled" -circle "red"
        }
    }

    Try {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        $3fw = Get-CimInstance -NameSpace "root\SecurityCenter2" -Query "select * from FirewallProduct" -ErrorAction SilentlyContinue
        if ($3fw) {
            foreach ($3fwentry in $3fw) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Third party firewall found: $($3fwentry.displayName)" -circle "blue"
            }
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Third party firewall(s) <span style='color: brown'>not found</span>" -circle "white"
        }

    } Catch {
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_

        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "An error occurred while trying to retrieve third party firewall information. See <a href='$msrdErrorfileurl' target='_blank'>MSRD-Collect-Error</a> for more information." -circle "red"
        Continue
    }
}

Function msrdDiagFirewall {

    #Firewall diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Firewall"
    $menucatmsg = "Networking"
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "FWCheck"

    msrdGetFirewallInfo

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagProxy {

    #Proxy diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Proxy"
    $menucatmsg = "Networking"
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "ProxCheck"

    $binval = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" -Name WinHttpSettings).WinHttPSettings
    $proxylength = $binval[12]
    if ($proxylength -gt 0) {
        $proxy = -join ($binval[(12+3+1)..(12+3+1+$proxylength-1)] | ForEach-Object {([char]$_)})
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "NETSH WINHTTP proxy is configured" -Message2 "$proxy" -circle "red"
        $bypasslength = $binval[(12+3+1+$proxylength)]

        if ($bypasslength -gt 0) {
            $bypasslist = -join ($binval[(12+3+1+$proxylength+3+1)..(12+3+1+$proxylength+3+1+$bypasslength)] | ForEach-Object {([char]$_)})
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Bypass list" -Message2 "$bypasslist" -circle "red"
        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Bypass list" -Message2 "<span style='color:red'>Not configured</span>" -circle "red"
        }
    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "NETSH WINHTTP proxy configuration" -Message2 "not found"
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"

    # Query for the WPAD CNAME record
    $dnsResultCNAME = Resolve-DnsName -Name "wpad" -Type CNAME -ErrorAction SilentlyContinue
    if ($dnsResultCNAME) {
        $nameHostCNAME = $dnsResultCNAME.NameHost
        $ttlCNAME = $dnsResultCNAME.QueryResults.QueryResultsTTL
		$global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "WPAD (CNAME record)" -Message2 "$nameHostCNAME (TTL: $ttlCNAME)" -circle "red"
    } else {
		msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "WPAD (CNAME record)" -Message2 "not found"
	}

    # Query for the WPAD A record
    $dnsResultA = Resolve-DnsName -Name "wpad" -Type A -ErrorAction SilentlyContinue
    if ($dnsResultA) {
		$ipAddressA = $dnsResultA.IPAddress
		$ttlA = $dnsResultA.QueryResults.QueryResultsTTL
		$global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
		msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "WPAD (A record)" -Message2 "$ipAddressA (TTL: $ttlA)" -circle "red"
	} else {
		msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "WPAD (A record)" -Message2 "not found"
	}

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"

    function GetBitsadmin {
        Param([string]$batype)

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Device-wide IE proxy configuration ($batype)"
        $outcmd = bitsadmin /util /getieproxy $batype
        foreach ($outopt in $outcmd) {
            if (($outopt -like "*Proxy usage:*") -or ($outopt -like "*Auto discovery script URL:*") -or ($outopt -like "*Proxy list:*") -or ($outopt -like "*Proxy bypass:*")) {
                $p1 = $outopt.Split(":")[0]
                $p2 = $outopt.Trim($p1 + ": ")
                if ($p2 -like "*AUTODETECT*") {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 $p1 -Message3 "$p2" -circle "blue"
                } else {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 $p1 -Message3 "$p2" -circle "red"
                }
            }
        }
    }

    GetBitsadmin "LOCALSERVICE"
    GetBitsadmin "LOCALSYSTEM"
    GetBitsadmin "NETWORKSERVICE"

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\' -RegKey 'DisableProxyAuthenticationSchemes'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\' -RegKey 'ProxyEnable'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\' -RegKey 'ProxyEnable'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\' -RegKey 'ProxyServer' -addWarning
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\' -RegKey 'ProxyServer' -addWarning
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\' -RegKey 'ProxyOverride'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\' -RegKey 'ProxyOverride'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\' -RegKey 'AutoConfigURL' -addWarning
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\' -RegKey 'AutoConfigURL' -addWarning
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections\' -RegKey 'WinHttpSettings'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections\' -RegKey 'DefaultConnectionSettings'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp\' -RegKey 'DisableWpad'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp\' -RegKey 'TcpAutotuning'
    msrdCheckRegKeyValue -RegPath 'HKU:\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\' -RegKey 'ProxyEnable'
    msrdCheckRegKeyValue -RegPath 'HKU:\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections\' -RegKey 'DefaultConnectionSettings'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\' -RegKey 'ProxySettings' -OptNote 'Computer Policy: Configure address or URL of proxy server'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Edge\' -RegKey 'ProxySettings' -OptNote 'User Policy: Configure address or URL of proxy server'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\NetworkIsolation\' -RegKey 'DProxiesAuthoritive' -OptNote 'Computer Policy: Proxy definitions are authoritative'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\NetworkIsolation\' -RegKey 'DomainProxies' -OptNote 'Computer Policy: Internet proxy servers for apps'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\NetworkIsolation\' -RegKey 'DomainLocalProxies' -OptNote 'Computer Policy: Intranet proxy servers for apps'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\NetworkIsolation\' -RegKey 'CloudResources' -OptNote 'Computer Policy: Intranet proxy servers for apps'

    #zscaler
    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    try {
        $ZScalerCheck = Invoke-RestMethod -Uri "https://ip.zscaler.com" -Method Get -TimeoutSec 30

        if ($ZScalerCheck) {
            $ZScalerResponse = [regex]::Match($ZScalerCheck, '<div class="headline">(.*?)</div>').Groups[1].Value -replace '<span.*?>(.*?)</span>', '$1'.Trim()
            $ZScalerDetails = [regex]::Match($ZScalerCheck, '<div class="details">(.*?)</div>').Groups[1].Value -replace '<span.*?>(.*?)</span>', '$1'.Trim()

            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "ZScaler information (based on <a href='https://ip.zscaler.com' target='_blank'>https://ip.zscaler.com</a>)"
            if ($ZscalerResponse -like "*you are not going through the Zscaler proxy service*") {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "[ZScaler reply] $ZScalerResponse" -circle "green"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "[ZScaler reply] $ZScalerResponse" -circle "red"
            }
            $zs = $false
            foreach ($Zitem in $ZScalerDetails) {
                if ($Zitem -like "*You are accessing the Internet via Zscaler*") {
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                    $zs = $true
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "[ZScaler reply] $Zitem" -circle "red"
                } elseif ($zs) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "[ZScaler reply] $Zitem" -circle "red"
                } else {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "[ZScaler reply] $Zitem" -circle "green"
                }
            }

        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "ZScaler information (based on <a href='https://ip.zscaler.com' target='_blank'>https://ip.zscaler.com</a>) could not be retrieved." -circle "red"
        }
    } Catch {
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
        $zerrmsg = "$($_.CategoryInfo.Reason): $($_.Exception.Message)"

        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "An error occurred during the ZScaler usage check ($zerrmsg). This usually happens when the machine has no internet access or there are some underlying network issues or restrictions. See <a href='$msrdErrorfileurl' target='_blank'>MSRD-Collect-Error</a> for more information." -circle "red"
    }

    #checking for proxy in nslookup wpad
    $nslookupOutput = nslookup wpad 2>$null
    $outputLines = $nslookupOutput -split "`r`n"
    $server = ""
    $address = ""
    $proxyEntries = @()

    # Process each line of the output
    $index = 0
    while ($index -lt $outputLines.Length) {
        $line = $outputLines[$index]
        if ($line -match '^Server:') {
            $server = $line -replace '^Server:\s+', ''
            $address = $outputLines[$index + 1] -replace '^Address:\s+', ''
        }
        elseif ($line -match '^Name:\s+proxy') {
            $name = $line -replace '^Name:\s+', ''
            $addressAndAliases = @($outputLines[($index + 1)..($index + 3)] -replace 'Address:\s{2}', 'Address: ' -replace 'Aliases:\s{2}', 'Aliases: ')
            $proxyEntries += @{
                Name = $name
                AddressAndAliases = $addressAndAliases
            }
        }

        $index++
    }

    # Output the extracted data
    if ($proxyEntries.Count -gt 0) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Found proxy reference in nslookup output"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "Server: $server ($address)"
        foreach ($entry in $proxyEntries) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "Name: $($entry.Name) ($($entry.AddressAndAliases[0])) - $($entry.AddressAndAliases[1..($entry.AddressAndAliases.Length - 1)])"
        }
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagNWCore {

    $global:msrdSetWarning = $false
    $menuitemmsg = "Core NET"
    $menucatmsg = "Networking"
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "NWCCheck"

    msrdCheckServicePort -service lmhosts -stopWarning #TCP/IP NetBIOS Helper
    msrdLogDiag $LogLevel.DiagFileOnly -Type "DL"
    msrdCheckServicePort -service lmhosts -stopWarning
    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"

    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Rpc\Internet\' -RegKey 'Ports'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Rpc\Internet\' -RegKey 'PortsInternetAvailable'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Rpc\Internet\' -RegKey 'UseInternetPorts'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectionStatusIndicator\' -RegKey 'NoActiveProbe' -RegValue 0
    msrdCheckRegKeyValue -RegPath 'HKLM:\System\CurrentControlSet\Services\NlaSvc\Parameters\Internet\' -RegKey 'EnableActiveProbing' -RegValue 1
    msrdCheckRegKeyValue -RegPath 'HKLM:\System\CurrentControlSet\Services\Tcpip\Parameters\' -RegKey 'DefaultTTL'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\' -RegKey 'DhcpNameServer'
    msrdCheckRegKeyValue -RegPath 'HKLM:\System\CurrentControlSet\Services\Tcpip\Parameters\' -RegKey 'MaxUserPort'
    msrdCheckRegKeyValue -RegPath 'HKLM:\System\CurrentControlSet\Services\Tcpip\Parameters\' -RegKey 'KeepAliveInterval'
    msrdCheckRegKeyValue -RegPath 'HKLM:\System\CurrentControlSet\Services\Tcpip\Parameters\' -RegKey 'KeepAliveTime'
    msrdCheckRegKeyValue -RegPath 'HKLM:\System\CurrentControlSet\Services\Tcpip\Parameters\' -RegKey 'TcpMaxDataRetransmissions' -RegValue '5'
    msrdCheckRegKeyValue -RegPath 'HKLM:\System\CurrentControlSet\Services\Tcpip\Parameters\' -RegKey 'TcpNumConnections'
    msrdCheckRegKeyValue -RegPath 'HKLM:\System\CurrentControlSet\Services\Tcpip\Parameters\' -RegKey 'TcpTimedWaitDelay'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters\' -RegKey 'MaxNegativeCacheTtl'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Services\NetLogon\Parameters\' -RegKey 'NegativeCachePeriod'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\' -RegKey 'AlwaysExpectDomainController'

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagRouting {

    $global:msrdSetWarning = $false
    $menuitemmsg = "Routing"
    $menucatmsg = "Networking"
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "RoutingCheck"

    #route
    if ((Test-Path ($global:msrdLogDir + $routefile)) -and (-not $global:msrdLiveDiag)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "Route information" -Message3 "(See: <a href='$routefile' target='_blank'>Route</a>)"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    }

    #default gateway
    $defaultGateway = Get-NetRoute | Where-Object { $_.DestinationPrefix -eq '0.0.0.0/0' } | Select-Object -ExpandProperty NextHop
    if ($global:msrdLiveDiag) { $defaultGateway = $defaultGateway -join " / " } else { $defaultGateway = $defaultGateway -join "<br>" }
    if ($defaultGateway) {
		msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Default gateway" -Message2 "$defaultGateway" -circle "blue"
	} else {
		$global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
		msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Default gateway could not be retrieved." -circle "red"
	}

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdCheckRegKeyValue -RegPath 'HKLM:\System\CurrentControlSet\Services\Tcpip\Parameters\' -RegKey 'IpEnableRouter'
    msrdCheckRegKeyValue -RegPath 'HKLM:\Software\Policies\Microsoft\Windows\TCPIP\v6Transition\' -RegKey 'force_Tunneling'

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagIPAddresses {

    #IP address diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "IP Addresses"
    $menucatmsg = "Networking"
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "PublicIPCheck"

    if ((Test-Path ($global:msrdLogDir + $ipcfgfile)) -and (-not $global:msrdLiveDiag)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Local IP addresses" -Message2 "(See: <a href='$ipcfgfile' target='_blank'>Ipconfig</a>)"
    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Local IP addresses"
    }

    $networkAdapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=true" -ErrorAction SilentlyContinue
    if ($networkAdapters) {
        foreach ($adapter in $networkAdapters) {
            $adapterName = $adapter.Description
            $ipAddresses = $adapter.IPAddress
            $adapterId = $adapter.SettingID
            $connectionProfile = Get-NetConnectionProfile -ErrorAction SilentlyContinue | Where-Object { $_.InstanceID -eq $adapterId }
            if ($connectionProfile) {
                $networkName = $connectionProfile.Name
                $networkCategory = $connectionProfile.NetworkCategory
            } else {
                $networkName = "N/A"
                $networkCategory = "N/A"
            }

            if ($global:msrdLiveDiag) { $ipAddresses = $ipAddresses -join " / " } else { $ipAddresses = $ipAddresses -join "<br>" }

            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$adapterName (Network: $networkName - Category: $networkCategory)" -Message3 $ipAddresses
        }
    } else {
		$global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
		msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Could not find any network adapters with associated IP addresses." -circle "red"
    }
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Public IP addresses"

    try {
        $pubip = Invoke-RestMethod -Uri "https://ipinfo.io/json" -Method Get -TimeoutSec 30

        if ($pubip) {
            foreach ($pip in $pubip) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "Public IP" -Message3 "$($pubip.ip)"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "City/Region" -Message3 "$($pubip.city)/$($pubip.region)"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "Country" -Message3 "$($pubip.country)"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "Organization" -Message3 "$($pubip.org)"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "Timezone" -Message3 "$($pubip.timezone)"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
            }
        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Public IP information could not be retrieved." -circle "red"
        }

    } Catch {
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_

        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Public IP information could not be retrieved. See <a href='$msrdErrorfileurl' target='_blank'>MSRD-Collect-Error</a> for more information." -circle "red"
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}


Function msrdDiagPortUsage {

    #Top 5 TCP/UDP consumers
    $global:msrdSetWarning = $false
    $menuitemmsg = "Port Usage"
    $menucatmsg = "Networking"
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "PortUsageCheck"

    #Function to get services for svchost process
    function GetSvchostServices {
        param ($ProcessId)

        $tasklistOutput = tasklist /svc /fi "imagename eq svchost.exe" | findstr /C:"$ProcessId"
        ($tasklistOutput -split '\s+', 3)[-1].Trim()
    }

    # Function to process netstat output
    function GetNetstatProcesses {
        param ($Protocol)

        netstat -anobq | Select-String $Protocol | ForEach-Object {
            $line       = $_.Line -split '\s+'
            $processId  = $line[-1]
            $processName = (Get-Process -Id $processId -ErrorAction SilentlyContinue).ProcessName

            if ($processName -notin 'Idle', 'System') {
                $port = $line[2] -replace '(.+):(\d+)', '$2'
                $properties = @{
                    Protocol = $Protocol
                    ProcessName = if ($processName -eq 'svchost') {
                        "svchost ($(GetSvchostServices -ProcessId $processId))"
                    } else {
                        $processName
                    }
                    ProcessId = $processId
                    Port = $port
                }

                [PSCustomObject]$properties
            }
        } | Group-Object ProcessName | ForEach-Object {
            $processName = $_.Name
            $uniqueProcessIds = $_.Group.ProcessId | Select-Object -Unique
            $uniquePorts = $_.Group.Port | Select-Object -Unique
            $totalPortCount = $uniquePorts.Count
            $individualCounts = $_.Group | Group-Object ProcessId | ForEach-Object {
                    "$($_.Name)"
            }
            [PSCustomObject]@{
                Protocol = $Protocol
                ProcessName = "$processName"
                ProcessPortCount = "is using a total of $totalPortCount $($Protocol) $(If ($totalPortCount -eq 1) { 'port' } else { 'ports' })"
                ProcessPIDs = "across $($individualCounts.Count) PID$(If ($individualCounts.Count -eq 1) { '' } else { 's' }) ($($individualCounts -join ', '))"
                Count = $totalPortCount
            }

        } | Sort-Object Count -Descending | Select-Object -First 5
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "These values represent a snapshot of the system's status at the time the script was executed and are intended only as a reference point. Keep in mind that network port usage can fluctuate rapidly, and the information may change in a matter of seconds."
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"

    $tcpData = Get-NetTCPConnection -ErrorAction SilentlyContinue
    if ($tcpData) {
        $totalTCPPorts = ($tcpData | Group-Object LocalPort).Count
        $totalTCPPortsBound = ($tcpData | Where-Object { $_.State -eq 'Bound' } | Group-Object LocalPort).Count
        $totalTCPPortsTimeWait = ($tcpData | Where-Object { $_.State -eq 'TimeWait' } | Group-Object LocalPort).Count
        $totalTCPPortsCloseWait = ($tcpData | Where-Object { $_.State -eq 'CloseWait' } | Group-Object LocalPort).Count

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Total TCP ports in use across all local IP addresses" -Message2 "$totalTCPPorts" -circle "blue"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Total TCP ports in BOUND state" -Message2 "$totalTCPPortsBound" -circle "blue"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Total TCP ports in TIME_WAIT state" -Message2 "$totalTCPPortsTimeWait" -circle "blue"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Total TCP ports in CLOSE_WAIT state" -Message2 "$totalTCPPortsCloseWait" -circle "blue"

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Top 5 processes using the most TCP ports"

        $tcpProcesses = GetNetstatProcesses -Protocol 'TCP'
        if ($tcpProcesses) {
            $tcpProcesses | ForEach-Object {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "$($_.ProcessName)" -Message2 "$($_.ProcessPortCount)" -Message3 "$($_.ProcessPIDs)" -circle "blue"
            }
        } else {
		    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "No processes found using TCP ports" -circle "blue"
        }

    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "No TCP connections found" -circle "blue"
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "DL"

    $udpData = Get-NetUDPEndpoint -ErrorAction SilentlyContinue
    if ($udpData) {
        $totalUDPPorts = ($udpData | Group-Object LocalPort).Count

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Total UDP Ports in use across all local IP addresses" -Message2 "$totalUDPPorts" -circle "blue"

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
	    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Top 5 processes using the most UDP ports"

        $udpProcesses = GetNetstatProcesses -Protocol 'UDP'
	    if ($udpProcesses) {
		    $udpProcesses | ForEach-Object {
			    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "$($_.ProcessName)" -Message2 "$($_.ProcessPortCount)" -Message3 "$($_.ProcessPIDs)" -circle "blue"
		    }
	    } else {
		    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "No processes found using UDP ports" -circle "blue"
	    }

    } else {
		msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "No UDP connections found" -circle "blue"
    }

	if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagVPN {

    #VPN diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "VPN"
    $menucatmsg = "Networking"
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "VPNCheck"

    try {
        $vpn = Get-VpnConnection -ErrorAction Continue 2>>$global:msrdErrorLogFile
        if ($vpn) {
            foreach ($v in $vpn) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Name" -Message2 "$($v.Name)"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "ServerAddress" -Message2 "$($v.ServerAddress)"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "DnsSuffix" -Message2 "$($v.DnsSuffix)"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Guid" -Message2 "$($v.Guid)"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "ConnectionStatus" -Message2 "$($v.ConnectionStatus)" -circle "blue"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "RememberCredentials" -Message2 "$($v.RememberCredential)"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "SplitTunneling" -Message2 "$($v.SplitTunneling)"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "IdleDisconnectSeconds" -Message2 "$($v.IdleDisconnectSeconds)" -circle "blue"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "PlugInApplicationID" -Message2 "$($v.PlugInApplicationID)"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "ProfileType" -Message2 "$($v.ProfileType)"
                if ($v.Proxy -and ($v.Proxy -ne "")) {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Proxy" -Message2 "$($v.Proxy)" -circle "blue"
                } else {
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Proxy" -Message2 "$($v.Proxy)"
                }

                if ($v -ne $vpn[-1]) { msrdLogDiag $LogLevel.DiagFileOnly -Type "DL" }
            }
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "VPN connection profile information <span style='color: brown'>not found</span>"
        }

    } Catch {
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_

        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "VPN information could not be retrieved. See <a href='$msrdErrorfileurl' target='_blank'>MSRD-Collect-Error</a> for more information." -circle "red"
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

#endregion Networking functions


#region Logon/Security functions

Function msrdDiagAuth {

    #Authentication/Logon diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Authentication / Logon"
    $menucatmsg = "Logon / Security"
    msrdLogDiag $LogLevel.Normal -DiagTag "AuthCheck" -Message $menuitemmsg

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "User context" -Message2 "$global:msrdUserprof"

    msrdCheckRegKeyValue -RegPath 'HKLM:\Policies\Microsoft\Windows\System\' -RegKey 'DefaultCredentialProvider'

    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI') {
        if (msrdTestRegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\' -Value 'LastLoggedOnProvider') {
            $logonprov = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI' -name "LastLoggedOnProvider"
            $credprovpath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers\$logonprov"
            if (Test-Path $credprovpath) {
                $credprov = Get-ItemPropertyValue -Path $credprovpath -name "(Default)"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Last Logged On Credential Provider used" -Message2 "$credprov"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Last Logged On Credential Provider used" -Message2 "<span style='color: brown'>not found</span>"
            }
        }
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Terminal Server Client\' -RegKey 'DisableWebAuthnRedirection'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Terminal Server Client\' -RegKey 'DisableWebAuthnRedirection'

    if (!($global:msrdSource)) {
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fDisableWebAuthn' -RegValue '0' -OptNote 'Computer Policy: Do not allow WebAuthn redirection'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -RegKey 'bAllowFastReconnect'
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos\Parameters\' -RegKey 'MaxTokenSize'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\' -RegKey 'AppSetup'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\' -RegKey 'AutoAdminLogon'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\' -RegKey 'ForceAutoLogon' -RegValue '0'

    if (!($global:msrdSource)) {
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System\' -RegKey 'ProcessTSUserLogonAsync' -OptNote 'Computer Policy: Allow asynchronous user Group Policy processing when logging on through Remote Desktop Services'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fQueryUserConfigFromDC'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fQueryUserConfigFromLocalMachine'
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\' -RegKey 'AllowDefaultCredentials' -OptNote 'Computer Policy: Allow delegating default credentials' -linkToReg $regCredDelegationFile
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\' -RegKey 'AllowDefCredentialsWhenNTLMOnly' -OptNote 'Computer Policy: Allow delegating default credentials with NTLM-only server authentication' -linkToReg $regCredDelegationFile
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\' -RegKey 'DenyDefaultCredentials' -OptNote 'Computer Policy: Deny delegating default credentials' -linkToReg $regCredDelegationFile
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\' -RegKey 'AllowFreshCredentials' -OptNote 'Computer Policy: Allow delegating fresh credentials' -linkToReg $regCredDelegationFile
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\' -RegKey 'AllowFreshCredentialsWhenNTLMOnly' -OptNote 'Computer Policy: Allow delegating fresh credentials with NTLM-only server authentication' -linkToReg $regCredDelegationFile
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\' -RegKey 'DenyFreshCredentials' -OptNote 'Computer Policy: Deny delegating fresh credentials' -linkToReg $regCredDelegationFile
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\' -RegKey 'AllowSavedCredentials' -OptNote 'Computer Policy: Allow delegating saved credentials' -linkToReg $regCredDelegationFile
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\' -RegKey 'AllowSavedCredentialsWhenNTLMOnly' -OptNote 'Computer Policy: Allow delegating saved credentials with NTLM-only server authentication' -linkToReg $regCredDelegationFile
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\' -RegKey 'DenySavedCredentials' -OptNote 'Computer Policy: Deny delegating saved credentials' -linkToReg $regCredDelegationFile
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\' -RegKey 'RestrictedRemoteAdministration' -OptNote 'Computer Policy: Restrict delegation of credentials to remote servers'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\' -RegKey 'RestrictedRemoteAdministrationType' -OptNote 'Computer Policy: Restrict delegation of credentials to remote servers'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters\' -RegKey 'MaxTicketAge' -OptNote 'Computer Policy: Maximum lifetime for service ticket' -RegValue '600'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters\' -RegKey 'MaxUserTicketLifetime' -OptNote 'Computer Policy: Maximum lifetime for user ticket' -RegValue '10'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters\' -RegKey 'MaxRenewAge' -OptNote 'Computer Policy: Maximum lifetime for user ticket renewal' -RegValue '7'

    #checking if there are stored entries in credential manager for MSTSC or AVD (source machine only)
    if ($global:msrdSource) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"

        $credentialList = cmdkey /list
        $filteredCredentials = $credentialList | Where-Object { $_ -match "Target: .*TERMSRV.*|.*RDPClient.*" }

        if ($filteredCredentials) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "TERMSRV/RDPClient entries stored in Credential Manager for the current user"

            $redactedCredentials = $filteredCredentials -replace '(?<=:UID:)[^:]*|:UID:[^:]*', ''
            foreach ($cred in $redactedCredentials) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 $cred -circle "blue"
            }
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "No TERMSRV or RDPClient entries have been found stored in Credential Manager for the current user."
        }
        $credentialList = $null
        $filteredCredentials = $null
        $redactedCredentials = $null
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }


}

Function msrdGetAntivirusInfo {

    #get Antivirus information
    Try {
        $AVprod = (Get-CimInstance -Namespace root\SecurityCenter2 -Class AntiVirusProduct -ErrorAction SilentlyContinue).displayName | Select-Object -Unique

        if ($AVprod) {
            if (Test-Path ($global:msrdLogDir + $avinfofile)) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message "Antivirus software" -Message3 "(See: <a href='$avinfofile' target='_blank'>AntiVirusProducts</a>)" -circle "blue"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Antivirus software"
            }
            foreach ($AVPentry in $AVprod) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "$AVPentry" -circle "blue"
            }
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Antivirus software <span style='color: brown'>not found</span>."
        }

    } Catch {
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_

        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "An error occurred while trying to retrieve Antivirus information. See <a href='$msrdErrorfileurl' target='_blank'>MSRD-Collect-Error</a> for more information." -circle "red"
        Continue
    }

    If (!($global:msrdOSVer -like "*Server*2008*") -and !($global:msrdOSVer -like "*Server*2012*")) {
        $DefPreference = Get-MpPreference | Select-Object DisableAutoExclusions, RandomizeScheduleTaskTimes, SchedulerRandomizationTime, ProxyServer, ProxyPacUrl, ProxyBypass, ForceUseProxyOnly, ScanScheduleTime, ScanScheduleQuickScanTime, ScanOnlyIfIdleEnabled
        if ($DefPreference) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"

            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Defender settings"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3"  -Message2 "DisableAutoExclusions" -Message3 "$($DefPreference.DisableAutoExclusions)" -circle "blue"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3"  -Message2 "RandomizeScheduleTaskTimes" -Message3 "$($DefPreference.RandomizeScheduleTaskTimes)" -circle "blue"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3"  -Message2 "SchedulerRandomizationTime" -Message3 "$($DefPreference.SchedulerRandomizationTime)" -circle "blue"

            if ($DefPreference.ProxyServer) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "ProxyServer" -Message3 "$($DefPreference.ProxyServer)" -circle "blue"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "ProxyServer" -Message3 "$($DefPreference.ProxyServer)"
            }

            if ($DefPreference.ProxyPacUrl) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "ProxyPacUrl" -Message3 "$($DefPreference.ProxyPacUrl)" -circle "blue"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "ProxyPacUrl" -Message3 "$($DefPreference.ProxyPacUrl)"
            }

            if ($DefPreference.ProxyBypass) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "ProxyBypass" -Message3 "$($DefPreference.ProxyBypass)" -circle "blue"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "ProxyBypass" -Message3 "$($DefPreference.ProxyBypass)"
            }

            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "ForceUseProxyOnly" -Message3 "$($DefPreference.ForceUseProxyOnly)" -circle "blue"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "ScanScheduleTime" -Message3 "$($DefPreference.ScanScheduleTime)" -circle "blue"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "ScanScheduleQuickScanTime" -Message3 "$($DefPreference.ScanScheduleQuickScanTime)" -circle "blue"
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "ScanOnlyIfIdleEnabled" -Message3 "$($DefPreference.ScanOnlyIfIdleEnabled)" -circle "blue"
        }
    }
}

function msrdGetUserRights {

    #get User Rights policy information
    [array]$localrights = $null

    function msrdGetSecurityPolicy {

        # Fail script if we can't find SecEdit.exe
        $SecEdit = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::System)) "SecEdit.exe"
        if (-not (Test-Path $SecEdit)) {
            msrdLogException ("File not found - '$SecEdit'") -ErrObj $_
            return
        }
        # LookupPrivilegeDisplayName Win32 API doesn't resolve logon right display names, so use this hashtable
        $UserLogonRights = @{
"SeBatchLogonRight"				    = "Log on as a batch job"
"SeDenyBatchLogonRight"			    = "Deny log on as a batch job"
"SeDenyInteractiveLogonRight"	    = "Deny log on locally"
"SeDenyNetworkLogonRight"		    = "Deny access to this computer from the network"
"SeDenyRemoteInteractiveLogonRight" = "Deny log on through Remote Desktop Services"
"SeDenyServiceLogonRight"		    = "Deny log on as a service"
"SeInteractiveLogonRight"		    = "Allow log on locally"
"SeNetworkLogonRight"			    = "Access this computer from the network"
"SeRemoteInteractiveLogonRight"	    = "Allow log on through Remote Desktop Services"
"SeServiceLogonRight"			    = "Log on as a service"
}

        # Create type to invoke LookupPrivilegeDisplayName Win32 API
        $Win32APISignature = @'
[DllImport("advapi32.dll", SetLastError=true)]
public static extern bool LookupPrivilegeDisplayName(
string systemName,
string privilegeName,
System.Text.StringBuilder displayName,
ref uint cbDisplayName,
out uint languageId
);
'@

        $AdvApi32 = Add-Type advapi32 $Win32APISignature -Namespace LookupPrivilegeDisplayName -PassThru

        # Use LookupPrivilegeDisplayName Win32 API to get display name of privilege (except for user logon rights)

        function msrdGetPrivilegeDisplayName {
        param ([String]$name)

            $displayNameSB = New-Object System.Text.StringBuilder 1024
            $languageId = 0
            $ok = $AdvApi32::LookupPrivilegeDisplayName($null, $name, $displayNameSB, [Ref]$displayNameSB.Capacity, [Ref]$languageId)

            if ($ok) { $displayNameSB.ToString() }
            else {
                # Doesn't lookup logon rights, so use hashtable for that
                if ($UserLogonRights[$name]) { $UserLogonRights[$name] }
                else { $name }
            }
        }

        # Translates a SID in the form *S-1-5-... to its account name;
        function msrdGetAccountName {
        param ([String]$principal)

            try {
                $sid = New-Object System.Security.Principal.SecurityIdentifier($principal.Substring(1))
                $sid.Translate([Security.Principal.NTAccount])
            } catch { $principal }
        }

        $TemplateFilename = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
        $LogFilename = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
        $StdOut = & $SecEdit /export /cfg $TemplateFilename /areas USER_RIGHTS /log $LogFilename

        if ($LASTEXITCODE -eq 0) {
            $dtable = $null
            $dtable = New-Object System.Data.DataTable
            $dtable.Columns.Add("Privilege", "System.String") | Out-Null
            $dtable.Columns.Add("PrivilegeName", "System.String") | Out-Null
            $dtable.Columns.Add("Principal", "System.String") | Out-Null

            Select-String '^(Se\S+) = (\S+)' $TemplateFilename | Foreach-Object {
                $Privilege = $_.Matches[0].Groups[1].Value
                $Principals = $_.Matches[0].Groups[2].Value -split ','
                foreach ($Principal in $Principals) {
                    $nRow = $dtable.NewRow()
                    $nRow.Privilege = $Privilege
                    $nRow.PrivilegeName = msrdGetPrivilegeDisplayName $Privilege
                    $nRow.Principal = msrdGetAccountName $Principal
                    $dtable.Rows.Add($nRow)
                }
                return $dtable
            }
        } else {
            msrdLogException ("$(msrdGetLocalizedText "errormsg") $StdOut") -ErrObj $_
        }
        Remove-Item $TemplateFilename, $LogFilename -ErrorAction SilentlyContinue
    }

    $localrights += msrdGetSecurityPolicy
    $localrights = $localrights | Select-Object Privilege, PrivilegeName, Principal -Unique | Where-Object { ($_.Privilege -like "*NetworkLogonRight") -or ($_.Privilege -like "*RemoteInteractiveLogonRight")}
    $RDUfound = $false

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "User Rights policies"
    Foreach ($LR in $localrights) {
        if (!($LR -like "Privilege*")) {
            $lrprincipal = $LR.Principal
            $lrprivilege = $LR.Privilege
            if (($lrprivilege -like "*SeRemoteInteractiveLogonRight*") -and (($lrprincipal -like "*BUILTIN\Remote Desktop Users*") -or ($lrprincipal -like "*BUILTIN\Administrators*") -or ($lrprincipal -like "*VORDEFINIERT\Administratoren*") -or ($lrprincipal -like "*VORDEFINIERT\Remotedesktopbenutzer*") -or ($lrprincipal -like "*BUILTIN\Administrateurs*") -or ($lrprincipal -like "*BUILTIN\Utilisateurs du Bureau à distance*"))) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($LR.PrivilegeName) ($lrprivilege)" -Message3 "$lrprincipal" -circle "green"
            } elseif (($lrprivilege -like "*SeDenyRemoteInteractiveLogonRight*") -and (($lrprincipal -like "*BUILTIN\Remote Desktop Users*") -or ($lrprincipal -like "*BUILTIN\Administrators*"))) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($LR.PrivilegeName) ($lrprivilege)" -Message3 "$lrprincipal" -circle "red"
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($LR.PrivilegeName) ($lrprivilege)" -Message3 "$lrprincipal" -circle "blue"
            }

            if (($lrprivilege -like "*SeRemoteInteractiveLogonRight*") -and (($lrprincipal -like "*BUILTIN\Remote Desktop Users*") -or ($lrprincipal -like "*VORDEFINIERT\Remotedesktopbenutzer*"))) {
                $RDUfound = $true
            }
        }
    }

    if (-not $RDUfound) {
         msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "The 'BUILTIN\Remote Desktop Users' group has not been found in the 'Allow log on through Remote Desktop Services' User Rights policy. You may have issues connecting to this machine over RDP." -circle "red"
    }
}

Function msrdDiagSecurity {

    #Security diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Security"
    $menucatmsg = "Logon / Security"
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "SecCheck"

    #check TPM
    $tpmstatus = Get-Tpm -ErrorAction SilentlyContinue | Select-Object TpmPresent, TpmReady, TpmEnabled, TpmActivated, TpmOwned, ManufacturerVersion
    if ($tpmstatus.TpmPresent) { $TpmPresent = $tpmstatus.TpmPresent; $tpmcircle = "blue" } else { $TpmPresent = "N/A"; $tpmcircle = "white" }
    if ($tpmstatus.TpmReady) { $TpmReady = $tpmstatus.TpmReady } else { $TpmReady = "N/A" }
    if ($tpmstatus.TpmEnabled) { $TpmEnabled = $tpmstatus.TpmEnabled } else { $TpmEnabled = "N/A" }
    if ($tpmstatus.TpmActivated) { $TpmActivated = $tpmstatus.TpmActivated } else { $TpmActivated = "N/A" }
    if ($tpmstatus.TpmOwned) { $TpmOwned = $tpmstatus.TpmOwned } else { $TpmOwned = "N/A" }
    if ($tpmstatus.ManufacturerVersion) { $TpmManVersion = $tpmstatus.ManufacturerVersion } else { $TpmManVersion = "N/A" }
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "TPM Status" -Message2 "Present: $TpmPresent | Ready: $TpmReady | Enabled: $TpmEnabled | Activated: $TpmActivated | Owned: $TpmOwned" -circle $tpmcircle

    $tmpwmi = (Get-CimInstance -Namespace "Root\CIMv2\Security\MicrosoftTpm" -ClassName Win32_Tpm -ErrorAction SilentlyContinue).SpecVersion
    if ($tmpwmi) { $TpmSpecVersion = $tmpwmi } else { $TpmSpecVersion = "N/A" }
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message2 "Manufacturer version: $TpmManVersion | Specification version: $TpmSpecVersion" -circle $tpmcircle

    #check secure boot
    try {
        $secboot = Confirm-SecureBootUEFI
        if ($secboot) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Secure Boot" -Message2 "Enabled" -circle "green"
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Secure Boot" -Message2 "Not enabled"
        }
    } catch {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message "Secure Boot" -Message2 "Not supported" -circle "blue"
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdGetAntivirusInfo  #get antivirus software information

    if (!($global:msrdSource)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        msrdGetUserRights  #get user rights policies information
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"

    if ($global:msrdOSVer -like "*Windows Server*") {
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\' -RegKey 'DisableAntiSpyware' -RegValue 'false'

        if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\" -value "DisableAntiSpyware") {
            $key = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\" -name "DisableAntiSpyware"
            if ($key -eq "true") {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "It is not recommended to disable Windows Defender, unless you are using another Antivirus software. See: $defenderRef" -circle "red"
            }
        }
    }

    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\' -RegKey 'ImpersonateCheckProtection' -addWarning
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\' -RegKey 'LmCompatibilityLevel'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\' -RegKey 'RestrictRemoteSam'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\' -RegKey 'RestrictRemoteSamAuditOnlyMode'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -RegKey 'DisableLockWorkstation' -OptNote 'Computer Policy: Remove Lock Computer'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\CredSSP\Parameters\' -RegKey 'AllowEncryptionOracle' -OptNote 'Computer Policy: Encryption Oracle Remediation'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos\Parameters\' -RegKey 'SupportedEncryptionTypes' -OptNote 'Computer Policy: Network security: Configure encryption types allowed for Kerberos' -addWarning

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard\' -RegKey 'EnableVirtualizationBasedSecurity' -OptNote 'Computer Policy: Turn On Virtualization Based Security (Device Guard)'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard\' -RegKey 'LsaCfgFlags' -OptNote 'Computer Policy: Turn On Virtualization Based Security (Device Guard)'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard\' -RegKey 'RequirePlatformSecurityFeatures' -OptNote 'Computer Policy: Turn On Virtualization Based Security (Device Guard)'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\' -RegKey 'EnableVirtualizationBasedSecurity'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\' -RegKey 'RequirePlatformSecurityFeatures'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\' -RegKey 'LsaCfgFlags'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\' -RegKey 'RestrictedRemoteAdministration' -OptNote 'Computer Policy: Restrict delegation of credentials to remote servers'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\' -RegKey 'RestrictedRemoteAdministrationType' -OptNote 'Computer Policy: Restrict delegation of credentials to remote servers'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\' -RegKey 'DisableRestrictedAdmin'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0\' -RegKey 'AuditReceivingNTLMTraffic' -OptNote 'Computer Policy: Network security: Restrict NTLM: Audit Incoming NTLM Traffic'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0\' -RegKey 'ClientAllowedNTLMServers' -OptNote 'Computer Policy: Network security: Restrict NTLM: Add remote server exceptions for NTLM authentication'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0\' -RegKey 'RestrictReceivingNTLMTraffic' -OptNote 'Computer Policy: Network security: Restrict NTLM: Incoming NTLM traffic'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0\' -RegKey 'RestrictSendingNTLMTraffic' -OptNote 'Computer Policy: Network security: Restrict NTLM: Outgoing NTLM traffic to remote servers'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters\' -RegKey 'AuditNTLMInDomain' -OptNote 'Computer Policy: Network security: Restrict NTLM: Audit NTLM authentication in this domain'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters\' -RegKey 'DCAllowedNTLMServers' -OptNote 'Computer Policy: Network security: Restrict NTLM: Add server exceptions in this domain'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters\' -RegKey 'RestrictNTLMInDomain' -OptNote 'Computer Policy: Network security: Restrict NTLM: NTLM authentication in this domain'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Browser\' -RegKey 'AllowSmartScreen'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\device\Browser\AllowSmartScreen\' -RegKey 'value'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\SmartScreen\EnableSmartScreenInShell\' -RegKey 'value'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\' -RegKey 'SmartScreenEnabled'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\' -RegKey 'SmartScreenEnabled' -OptNote 'Computer Policy: Configure Microsoft Defender SmartScreen'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Edge\' -RegKey 'SmartScreenEnabled' -OptNote 'User Policy: Configure Microsoft Defender SmartScreen'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System\' -RegKey 'EnableSmartScreen' -OptNote 'Computer Policy: Configure Windows Defender SmartScreen'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\WOW6432Node\Policies\Microsoft\Edge\' -RegKey 'SmartScreenEnabled'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop\' -RegKey 'ScreenSaveActive' -OptNote 'User Policy: Enable screen saver'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop\' -RegKey 'ScreenSaverIsSecure' -OptNote 'User Policy: Password protect the screen saver'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\' -RegKey 'ScreenSaverGracePeriod'

    if (($global:msrdAVD -or $global:msrdW365) -and !($global:msrdSource)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        if ($avdcheck) {
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fEnableScreenCaptureProtect' -OptNote 'Computer Policy: Enable screen capture protection'
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fEnableWatermarking' -OptNote 'Computer Policy: Enable watermarking'
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'WatermarkingHeightFactor' -OptNote 'Computer Policy: Enable watermarking'
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'WatermarkingOpacity' -OptNote 'Computer Policy: Enable watermarking'
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'WatermarkingQrScale' -OptNote 'Computer Policy: Enable watermarking'
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'WatermarkingWidthFactor' -OptNote 'Computer Policy: Enable watermarking'
        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$avdcheckmsg" -circle "red"
        }
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\' -RegKey 'DisallowRun' -OptNote 'User Policy: Do not run specified Windows applications'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\' -RegKey 'RestrictRun' -OptNote 'User Policy: Run only specified Windows applications'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Windows\System\' -RegKey 'DisableCMD' -OptNote 'User Policy: Prevent access to the command prompt'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx\' -RegKey 'BlockNonAdminUserInstall' -OptNote 'Computer Policy: Prevent non-admin users from installing packaged Windows apps' -addWarning

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -RegKey 'DisableRegistryTools' -OptNote 'User Policy: Prevent access to registry editing tools'
    msrdCheckRegKeyValue -RegPath 'HKU:\.DEFAULT\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -RegKey 'DisableRegistryTools'
    msrdCheckRegKeyValue -RegPath 'HKU:\S-1-5-18\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -RegKey 'DisableRegistryTools'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdCheckServicePort -service AppIDSvc

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

#endregion Logon/Security functions


#region Known Issues

Function msrdDiagIssues {
    Param([Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$IssueType, [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$LogName,
        [array]$LogID, [array]$Message, [array]$Provider, [string]$lvl, [string]$helpurl, [string]$evtxfile)

    #diagnostics of potential issues showing up in Event logs (based on messages)
    if ($lvl -eq "Full") { $evlvl = @(1,2,3,4) } elseif ($lvl -eq "None") { $evlvl = @(0) } else { $evlvl = @(1,2,3) }

    msrdLogDiag $LogLevel.Info -Message "[Diag] '$IssueType' issues in '$LogName' event logs"

    $StartTimeA = (Get-Date).AddDays(-5)
    if ($LogID) { $geteventDiag = Get-WinEvent -FilterHashtable @{logname="$LogName"; id=$LogID; StartTime=$StartTimeA; Level=$evlvl} -ErrorAction SilentlyContinue }
    else { $geteventDiag = Get-WinEvent -FilterHashtable @{logname="$LogName"; StartTime=$StartTimeA; Level=$evlvl} -ErrorAction SilentlyContinue }

    if ($IssueType -eq "Agent") { $issuefile = "MSRD-Diag-AgentIssues.txt" }
    elseif ($IssueType -eq "MSIXAA") { $issuefile = "MSRD-Diag-MSIXAAIssues.txt" }
    elseif ($IssueType -eq "FSLogix") { $issuefile = "MSRD-Diag-FSLogixIssues.txt" }
    elseif ($IssueType -eq "Shortpath") { $issuefile = "MSRD-Diag-ShortpathIssues.txt" }
    elseif ($IssueType -eq "Crash") { $issuefile = "MSRD-Diag-Crashes.txt" }
    elseif ($IssueType -eq "ProcessHang") { $issuefile = "MSRD-Diag-ProcessHangs.txt" }
    elseif ($IssueType -eq "BlackScreen") { $issuefile = "MSRD-Diag-PotentialBlackScreens.txt" }
    elseif ($IssueType -eq "TCP") { $issuefile = "MSRD-Diag-TCPIssues.txt" }
    elseif ($IssueType -eq "RDLicensing") { $issuefile = "MSRD-Diag-RDLicensingIssues.txt" }
    elseif ($IssueType -eq "RDGateway") { $issuefile = "MSRD-Diag-RDGatewayIssues.txt" }
    elseif ($IssueType -eq "DomainTrust") { $issuefile = "MSRD-Diag-DomainTrustIssues.txt" }
    elseif ($IssueType -eq "FailedLogon") { $issuefile = "MSRD-Diag-FailedLogons.txt" }

    $exportfile = $global:msrdBasicLogFolder + $issuefile
    $issuefileurl = $global:msrdLogFilePrefix + $issuefile
    $issuefiledisp = $issuefile.Split("-")[2].Split(".")[0]
    $issuefilelink = "<a href='$issuefileurl' target='_blank'>$issuefiledisp</a>"

    $evtxfilelink = "<a href='$evtxfile' target='_blank'>$LogName Event Logs</a>"

    $pad = 13
    $counter = 0

    If ($geteventDiag) {
        if ($Message) {
            foreach ($eventItem in $geteventDiag) {
                foreach ($msg in $Message) {
                    if ($eventItem.Message -like "*$msg*") {
                        $counter = $counter + 1
                         if (-not $global:msrdLiveDiag) {
                            "TimeCreated".PadRight($pad) + " : " + $eventItem.TimeCreated 2>&1 | Out-File -Append ($exportfile)
                            "EventLog".PadRight($pad) + " : " + $LogName 2>&1 | Out-File -Append ($exportfile)
                            "ProviderName".PadRight($pad) + " : " + $eventItem.ProviderName 2>&1 | Out-File -Append ($exportfile)
                            "Id".PadRight($pad) + " : " + $eventItem.Id 2>&1 | Out-File -Append ($exportfile)
                            "Level".PadRight($pad) + " : " + $eventItem.LevelDisplayName 2>&1 | Out-File -Append ($exportfile)
                            "Message".PadRight($pad) + " : " + $eventItem.Message 2>&1 | Out-File -Append ($exportfile)
                            "" 2>&1 | Out-File -Append ($exportfile)
                         }
                    }
                }
            }
        } elseif ($Provider) {
            foreach ($eventItem in $geteventDiag) {
                foreach ($prv in $Provider) {
                    if ($eventItem.ProviderName -eq $prv) {
                        $counter = $counter + 1
                         if (-not $global:msrdLiveDiag) {
                            "TimeCreated".PadRight($pad) + " : " + $eventItem.TimeCreated 2>&1 | Out-File -Append ($exportfile)
                            "EventLog".PadRight($pad) + " : " + $LogName 2>&1 | Out-File -Append ($exportfile)
                            "ProviderName".PadRight($pad) + " : " + $eventItem.ProviderName 2>&1 | Out-File -Append ($exportfile)
                            "Id".PadRight($pad) + " : " + $eventItem.Id 2>&1 | Out-File -Append ($exportfile)
                            "Level".PadRight($pad) + " : " + $eventItem.LevelDisplayName 2>&1 | Out-File -Append ($exportfile)
                            "Message".PadRight($pad) + " : " + $eventItem.Message 2>&1 | Out-File -Append ($exportfile)
                            "" 2>&1 | Out-File -Append ($exportfile)
                         }
                    }
                }
            }
        } else {
			foreach ($eventItem in $geteventDiag) {
				$counter = $counter + 1
				 if (-not $global:msrdLiveDiag) {
					"TimeCreated".PadRight($pad) + " : " + $eventItem.TimeCreated 2>&1 | Out-File -Append ($exportfile)
					"EventLog".PadRight($pad) + " : " + $LogName 2>&1 | Out-File -Append ($exportfile)
					"ProviderName".PadRight($pad) + " : " + $eventItem.ProviderName 2>&1 | Out-File -Append ($exportfile)
					"Id".PadRight($pad) + " : " + $eventItem.Id 2>&1 | Out-File -Append ($exportfile)
					"Level".PadRight($pad) + " : " + $eventItem.LevelDisplayName 2>&1 | Out-File -Append ($exportfile)
					"Message".PadRight($pad) + " : " + $eventItem.Message 2>&1 | Out-File -Append ($exportfile)
					"" 2>&1 | Out-File -Append ($exportfile)
				 }
			}
        }
    }

    if ($counter -gt 0) {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        if ($evtxfile) {
            if ($helpurl) { $msg3 = "(See: $issuefilelink / $evtxfilelink / $helpurl)" } else { $msg3 = "(See: $issuefilelink / $evtxfilelink)" }
        } else {
            if ($helpurl) { $msg3 = "(See: $issuefilelink / $helpurl)" } else { $msg3 = "(See: $issuefilelink)" }
        }
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message $IssueType -Message2 "Issues found in the '$LogName' event logs" -Message3 $msg3 -circle "red"
    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-2" -Message $IssueType -Message2 "No known issues found in the '$LogName' event logs" -circle "green"
    }

    [System.GC]::Collect()
}

function msrdDiagAVDIssueEvents {

    #AVD events issues
    $global:msrdSetWarning = $false
    $menuitemmsg = "Issues found in Event Logs over the past 5 days"
    $menucatmsg = "Known Issues"
    if ($avdcheck) {
        msrdDiagIssues -IssueType 'Agent' -LogName 'Application' -LogID @(3019,3277,3389,3703) -Message @('Transport received an exception','ENDPOINT_NOT_FOUND','INVALID_FORM','INVALID_REGISTRATION_TOKEN','NAME_ALREADY_REGISTERED','DownloadMsiException','InstallationHealthCheckFailedException','InstallMsiException','AgentLoadException','BootLoader exception','Unable to retrieve DefaultAgent from registry','MissingMethodException','RD Gateway Url') -lvl 'Full' -helpurl $avdTsgRef -evtxfile $aplevtxfile
        msrdDiagIssues -IssueType 'Agent' -LogName 'RemoteDesktopServices' -LogID @(0) -Message @('IMDS not accessible','Monitoring Agent Launcher file path was NOT located','NOT ALL required URLs are accessible!','SessionHost unhealthy','Unable to connect to the remote server','Unhandled status [ConnectFailure] returned for url','System.ComponentModel.Win32Exception (0x80004005)','Unable to extract and validate URLs','PingHost: Could not PING url','Unable to locate running process') -lvl 'Full' -helpurl $avdTsgRef -evtxfile $rdsevtxfile
        msrdDiagIssues -IssueType 'Shortpath' -LogName 'Microsoft-Windows-RemoteDesktopServices-RdpCoreCDV/Operational' -LogID @(135,226) -Message @('UDP Handshake Timeout','UdpEventErrorOnMtReqComplete') -lvl 'Full' -helpurl $spathTsgRef
        msrdDiagIssues -IssueType 'Shortpath' -LogName 'RemoteDesktopServices' -LogID @(0) -Message @('TURN check threw exception','TURN relay health check failed') -lvl 'Full' -evtxfile $rdsevtxfile -helpurl $spathTsgRef

        if (!($global:msrdW365)) {
            if ($global:WinVerBuild -lt 19041) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "MSIX App Attach requires Windows 10 Enterprise or Windows 10 Enterprise multi-session, version 20H2 or later. Skipping check for MSIX App Attach issues (not applicable)." -circle "white"
            } else {
                msrdDiagIssues -IssueType 'MSIXAA' -LogName 'RemoteDesktopServices' -LogID @(0) -Provider @('Microsoft.RDInfra.AppAttach.AgentAppAttachPackageListServiceImpl','Microsoft.RDInfra.AppAttach.AppAttachServiceImpl','Microsoft.RDInfra.AppAttach.SysNtfyServiceImpl','Microsoft.RDInfra.AppAttach.UserImpersonationServiceImpl','Microsoft.RDInfra.RDAgent.AppAttach.CimVolume','Microsoft.RDInfra.RDAgent.AppAttach.ImagedMsixExtractor','Microsoft.RDInfra.RDAgent.AppAttach.MsixProcessor','Microsoft.RDInfra.RDAgent.AppAttach.VhdVolume','Microsoft.RDInfra.RDAgent.AppAttach.VirtualDiskManager','Microsoft.RDInfra.RDAgent.Service.AppAttachHealthCheck', 'Microsoft.RDInfra.RDAgent.EtwReader.AppAttachProcessParser') -evtxfile $rdsevtxfile
            }
        }

    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$avdcheckmsg" -circle "red"
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

function msrdDiagRDIssueEvents {

    #RD events issues
    $global:msrdSetWarning = $false
    $menuitemmsg = "Issues found in Event Logs over the past 5 days"
    $menucatmsg = "Known Issues"

    msrdDiagIssues -IssueType 'BlackScreen' -LogName 'Application' -LogID @(4005) -Message @('The Windows logon process has unexpectedly terminated') -evtxfile $aplevtxfile
    msrdDiagIssues -IssueType 'BlackScreen' -LogName 'System' -LogID @(7011,10020) -Message @('was reached while waiting for a transaction response from the AppReadiness service','The machine wide Default Launch and Activation security descriptor is invalid') -evtxfile $sysevtxfile
    msrdDiagIssues -IssueType 'FailedLogon' -LogName 'Security' -LogID @(4625) -lvl 'None' -evtxfile $secevtxfile

    if (Test-path -path "$env:ProgramFiles\FSLogix\apps") {
        msrdDiagIssues -IssueType 'FSLogix' -LogName 'Microsoft-FSLogix-Apps/Admin' -Provider @('Microsoft-FSLogix-Apps') -helpurl $fslogixTsgRef
        msrdDiagIssues -IssueType 'FSLogix' -LogName 'Microsoft-FSLogix-Apps/Operational' -Provider @('Microsoft-FSLogix-Apps') -helpurl $fslogixTsgRef
        msrdDiagIssues -IssueType 'FSLogix' -LogName 'RemoteDesktopServices' -LogID @(0) -Message @('The disk detach may have invalidated handles','ErrorCode: 743') -lvl 'Full' -evtxfile $rdsevtxfile -helpurl $fslogixTsgRef
        msrdDiagIssues -IssueType 'FSLogix' -LogName 'System' -LogID @(4) -Message @('The Kerberos client received a KRB_AP_ERR_MODIFIED error from the server') -lvl 'Full' -evtxfile $sysevtxfile -helpurl $fslogixTsgRef
    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "FSLogix installation <span style='color: brown'>not found</span>. Skipping check for FSLogix issues (not applicable)." -circle "white"
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

function msrdDiagCommonIssueEvents {

    #common issues
    $global:msrdSetWarning = $false
    $menuitemmsg = "Issues found in Event Logs over the past 5 days"
    $menucatmsg = "Known Issues"
    msrdDiagIssues -IssueType 'Crash' -LogName 'Application' -LogID @(1000) -Message @('Faulting application name') -evtxfile $aplevtxfile
    msrdDiagIssues -IssueType 'Crash' -LogName 'System' -LogID @(41,6008) -Message @('The system rebooted without cleanly shutting down first','was unexpected') -evtxfile $sysevtxfile
    msrdDiagIssues -IssueType 'DomainTrust' -LogName 'System' -LogID @(5719) -Message @('not able to set up a secure session with a domain controller') -evtxfile $sysevtxfile
    msrdDiagIssues -IssueType 'ProcessHang' -LogName 'Application' -LogID @(1002) -Message @('stopped interacting with Windows') -evtxfile $aplevtxfile
    msrdDiagIssues -IssueType 'TCP' -LogName 'System' -LogID @(4227,4231) -Message @('TCP/IP failed to establish','port space has failed') -evtxfile $sysevtxfile

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

function msrdDiagRDLicensingIssueEvents {

    #RD Licensing issues
    $global:msrdSetWarning = $false
    $menuitemmsg = "Issues found in Event Logs over the past 5 days"
    $menucatmsg = "Known Issues"
    msrdDiagIssues -IssueType 'RDLicensing' -LogName 'System' -Provider @('Microsoft-Windows-TerminalServices-Licensing') -evtxfile $sysevtxfile
    msrdDiagIssues -IssueType 'RDLicensing' -LogName 'Microsoft-Windows-TerminalServices-Licensing/Admin'
    msrdDiagIssues -IssueType 'RDLicensing' -LogName 'Microsoft-Windows-TerminalServices-Licensing/Operational'

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

function msrdDiagRDGatewayIssueEvents {

    #RD Gateway issues
    $global:msrdSetWarning = $false
    $menuitemmsg = "Issues found in Event Logs over the past 5 days"
    $menucatmsg = "Known Issues"
    msrdDiagIssues -IssueType 'RDGateway' -LogName 'Microsoft-Windows-TerminalServices-Gateway/Admin'
    msrdDiagIssues -IssueType 'RDGateway' -LogName 'Microsoft-Windows-TerminalServices-Gateway/Operational'

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagLogonIssues {

    #potential logon issues diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Potential Logon/Logoff Issue Generators"
    $menucatmsg = "Known Issues"
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "BlackCheck"
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Incorrect configuration of one or more of the below values can sometimes lead to logon or logoff issues like: black screens, delays, remote desktop window disappearing etc."
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "When investigating such issues, also take into consideration the results of the 'Third party software' check below."
    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"

    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\NetCache\' -RegKey 'DisableFRAdminPin'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\NetCache\{3EB685DB-65F9-4CF6-A03A-E3EF65729F3D}\' -RegKey 'DisableFRAdminPinByFolder' -OptNote 'AppData(Roaming) folder redirection'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\NetCache\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}\' -RegKey 'DisableFRAdminPinByFolder' -OptNote 'Desktop folder redirection'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\NetCache\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}\' -RegKey 'DisableFRAdminPinByFolder' -OptNote 'Start Menu folder redirection'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\NetCache\{FDD39AD0-238F-46AF-ADB4-6C85480369C7}\' -RegKey 'DisableFRAdminPinByFolder' -OptNote 'Documents folder redirection'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\NetCache\{33E28130-4E1E-4676-835A-98395C3BC3BB}\' -RegKey 'DisableFRAdminPinByFolder' -OptNote 'Pictures folder redirection'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\NetCache\{4BD8D571-6D19-48D3-BE97-422220080E43}\' -RegKey 'DisableFRAdminPinByFolder' -OptNote 'Music folder redirection'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\NetCache\{18989B1D-99B5-455B-841C-AB7C74E4DDFC}\' -RegKey 'DisableFRAdminPinByFolder' -OptNote 'Videos folder redirection'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\NetCache\{1777F761-68AD-4D8A-87BD-30B759FA33DD}\' -RegKey 'DisableFRAdminPinByFolder' -OptNote 'Favorites folder redirection'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\NetCache\{56784854-C6CB-462b-8169-88E350ACB882}\' -RegKey 'DisableFRAdminPinByFolder' -OptNote 'Contacts folder redirection'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\NetCache\{374DE290-123F-4565-9164-39C4925E467B}\' -RegKey 'DisableFRAdminPinByFolder' -OptNote 'Downloads folder redirection'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\NetCache\{BFB9D5E0-C6A9-404C-B2B2-AE6DB6AF4968}\' -RegKey 'DisableFRAdminPinByFolder' -OptNote 'Links folder redirection'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\NetCache\{7D1D3A04-DEBB-4115-95CF-2F29DA2920DA}\' -RegKey 'DisableFRAdminPinByFolder' -OptNote 'Searches folder redirection'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\NetCache\{4C5C32FF-BB9D-43B0-B5B4-2D72E54EAAA4}\' -RegKey 'DisableFRAdminPinByFolder' -OptNote 'Saved Games folder redirection'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Active Setup\Installed Components\{89820200-ECBD-11cf-8B85-00AA005B4340}\' -RegKey 'IsInstalled'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'AVCHardwareEncodePreferred' -OptNote 'Computer Policy: Configure H.264/AVC hardware encoding for Remote Desktop Connections'
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata\' -RegKey 'PreventDeviceMetadataFromNetwork' -OptNote 'Computer Policy: Prevent device metadata retrieval from the Internet' -addWarning
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\' -RegKey 'DenyDeviceClasses' -OptNote 'Computer Policy: Prevent Installation of devices using drivers that match these device setup classes' -addWarning
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\' -RegKey 'DenyDeviceIDs' -OptNote 'Computer Policy: Prevent Installation of devices that match any of these device IDs' -addWarning
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\' -RegKey 'DenyInstanceIDs' -OptNote 'Computer Policy: Prevent Installation of devices that match any of these device instance IDs' -addWarning
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\' -RegKey 'DenyRemovableDevices' -OptNote 'Computer Policy: Prevent Installation of Removable Devices' -addWarning
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\' -RegKey 'DenyUnspecified' -OptNote 'Computer Policy: Prevent installation of devices not described by other policy settings' -addWarning

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\' -RegKey 'AppReadinessPreShellTimeoutMs'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -RegKey 'FirstLogonTimeout'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\' -RegKey 'DelayedDesktopSwitchTimeout'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\' -RegKey 'Shell' -RegValue 'explorer.exe'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\' -RegKey 'ShellAppRuntime' -RegValue 'ShellAppRuntime.exe'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\' -RegKey 'Userinit' -RegValue "$env:windir\system32\userinit.exe,"

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\LSA\' -RegKey 'CrashOnAuditFail' -OptNote 'Computer Policy: Audit: Shut down system immediately if unable to log security audits' -warnIfValue '2'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKCU:\Control Panel\Desktop\' -RegKey 'AutoEndTasks'
    msrdCheckRegKeyValue -RegPath 'HKCU:\Control Panel\Desktop\' -RegKey 'HungAppTimeout'
    msrdCheckRegKeyValue -RegPath 'HKCU:\Control Panel\Desktop\' -RegKey 'WaitToKillAppTimeout'
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\' -RegKey 'WaitToKillServiceTimeout'
    msrdCheckRegKeyValue -RegPath 'HKU:\.DEFAULT\Control Panel\Desktop\' -RegKey 'AutoEndTasks'
    msrdCheckRegKeyValue -RegPath 'HKU:\.DEFAULT\Control Panel\Desktop\' -RegKey 'HungAppTimeout'

    if (Test-path -path "$env:ProgramFiles\FSLogix\apps") {
        if (($script:frxverstrip -lt $latestFSLogixVer) -and (!($script:frxverstrip -eq "unknown"))) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "You are not using the latest available FSLogix release. Please consider updating. See: $fslogixRef" -circle "red"
        }
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdCheckServicePort -service AppXSvc

    msrdLogDiag $LogLevel.DiagFileOnly -Type "DL"
    msrdCheckServicePort -service AppReadiness

    msrdLogDiag $LogLevel.DiagFileOnly -Type "DL"
    msrdCheckServicePort -service smphost

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"

    #Checking System Hive size
    $hivePath = "$env:windir\System32\Config\SYSTEM"
    if (Test-Path $hivePath) {
        $hiveSize = (Get-Item $hivePath).length
        $hiveSizeMB = $hiveSize / 1MB
        if ($hiveSizeMB -gt 1000) {
            $hiveCircle = "red"; $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        } elseif ($hiveSizeMB -lt 300) { $hiveCircle = "green" } else { $hiveCircle = "blue" }
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "SYSTEM registry hive size" -Message2 "$hiveSizeMB MB" -circle $hiveCircle
    } else {
        $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "The SYSTEM registry hive file could not be found at $hivePath" -circle "red"
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    $countregKeys = @('HKLM:\SOFTWARE\Microsoft\Windows Search\CrawlScopeManager\Windows\SystemIndex\DefaultRules', 'HKLM:\SOFTWARE\Microsoft\Windows Search\CrawlScopeManager\Windows\SystemIndex\WorkingSetRules')
    foreach ($kreg in $countregKeys) {
        if (Test-Path -Path $kreg) {
            $keyCountBloat = Get-ChildItem -Path $creg | Measure-Object | Select-Object -ExpandProperty Count
            if ($keyCountBloat -gt 5000) { $kCircle = "red" } else { $kCircle = "blue" }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$kreg" -Message2 "$keyCountBloat keys found" -circle $kCircle
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message $kreg -Message2 "not found"
        }
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    $countregValues = @('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Notifications','HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules', 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedInterfaces\IfIso\FirewallRules', 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\RestrictedServices\AppIso\FirewallRules')
    foreach ($vreg in $countregValues) {
        if (Test-Path -Path $vreg) {
            $valueCountBloat = (Get-ItemProperty -Path $vreg | Get-Member -MemberType NoteProperty).Count
            if ($valueCountBloat -gt 5000) { $vCircle = "red" } else { $vCircle = "blue" }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$vreg" -Message2 "$valueCountBloat values found" -circle $vCircle
        } else {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message $vreg -Message2 "not found"
        }
    }
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\' -RegKey 'DeleteUserAppContainersOnLogoff' -RegValue '1'

    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\DriverDatabase\DeviceIds\TS_INPT\TS_KBD\' -RegKey 'termkbd.inf' -warnMissing
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\DriverDatabase\DeviceIds\TS_INPT\TS_MOU\' -RegKey 'termmou.inf' -warnMissing

    if (!($global:msrdSource)) {
        if ($global:msrdAVD -or $global:msrdW365) {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\TERMINPUT_BUS\UMB\", "HKLM:\SYSTEM\CurrentControlSet\Enum\TERMINPUT_BUS_SXS\UMB\"
        } else {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\TERMINPUT_BUS\UMB\"
        }
        foreach ($regP in $regPath) {

            if (Test-Path -Path $regP) {
                if ($regP -eq "HKLM:\SYSTEM\CurrentControlSet\Enum\TERMINPUT_BUS\UMB\") {
                    $umbfile = "${computerName}_RegistryKeys\${computerName}_HKLM-System-CCS-Enum-TERMINPUT_BUS.txt"
                    $umbname = "TERMINPUT_BUS\UMB\"
                } elseif ($regP -eq "HKLM:\SYSTEM\CurrentControlSet\Enum\TERMINPUT_BUS_SXS\UMB\") {
                    $umbfile = "${computerName}_RegistryKeys\${computerName}_HKLM-System-CCS-Enum-TERMINPUT_BUS_SXS.txt"
                    $umbname = "TERMINPUT_BUS_SXS\UMB\"
                }

                $keyNames = Get-ChildItem -Path $regP -Name -ErrorAction Continue 2>>$global:msrdErrorLogFile

                if ($keyNames) {
                    $sessions = @{}
                    foreach ($keyName in $keyNames) {
                        $match = $keyName -match "^(\d+)&(\w+)&(\d+)&Session(\d+)(Keyboard|Mouse)(\d+)$"
                        if ($match) {
                            $sessionId = [int]$matches[4]
                            $deviceType = $matches[5]
                            $deviceId = [int]$matches[6]
                            if (!$sessions.ContainsKey($sessionId)) {
                                $sessions[$sessionId] = @{
                                    "keyboardIds" = @()
                                    "mouseIds" = @()
                                }
                            }
                            if ($deviceType -eq "Keyboard") {
                                $sessions[$sessionId]["keyboardIds"] += $deviceId
                            } elseif ($deviceType -eq "Mouse") {
                                $sessions[$sessionId]["mouseIds"] += $deviceId
                            }
                        } else {
                            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Error retrieving information from '$keyName'" -circle "red"
                        }
                    }

                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
                    # File paths
                    $UMBpath1 = $umbfile; $tag1 = "$umbname registry"
                    $UMBpath2 = $pnputilKeyboardfile; $tag2 = "Pnputil Keyboard"
                    $UMBpath3 = $pnputilMousefile; $tag3 = "Pnputil Mouse"

                    # Check file availability
                    $availableFiles = @()
                    if (Test-Path -Path ($global:msrdLogDir + $UMBpath1)) { $availableFiles += $UMBpath1 }
                    if (Test-Path -Path ($global:msrdLogDir + $UMBpath2)) { $availableFiles += $UMBpath2 }
                    if (Test-Path -Path ($global:msrdLogDir + $UMBpath3)) { $availableFiles += $UMBpath3 }

                    # Build HTML for clickable hyperlinks
                    $htmlFiles = foreach ($file in $availableFiles) {
                        $tagVariableName = "tag" + ([array]::IndexOf($availableFiles, $file) + 1)
                        $tag = Get-Variable -Name $tagVariableName -ValueOnly
                        $link = "<a href='$file' target='_blank'>$tag</a>"
                        $link
                    }

                    # Display message
                    if ($availableFiles.Count -gt 0) {
                        $htmlFilesList = $htmlFiles -join ' / '
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Keyboard and mouse entries per remote session under $regP" -Message2 "(See: $htmlFilesList)"
                    } else {
                        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Keyboard and mouse entries per remote session under $regP"
                    }

                    foreach ($session in $sessions.Keys) {
                        $keyboardCount = $sessions[$session]["keyboardIds"].Count
                        $mouseCount = $sessions[$session]["mouseIds"].Count
                        $msgwarn = $false

                        $keyboardIds = $sessions[$session]["keyboardIds"] -join ", "
                        if ($keyboardIds -eq "") { $keyboardIds = "N/A" }
                        if ($keyboardCount -ne 1) {
                            $msgwarn = $true
                            if ($sessions[$session]["keyboardIds"] -notcontains 0) {
                                $msgkeyboard = "Keyboard entries found: $keyboardCount (Expected: 1) [Value(s): $keyboardIds] (Keyboard 0 not found)"
                            } else {
                                $msgkeyboard = "Keyboard entries found: $keyboardCount (Expected: 1) [Value(s): $keyboardIds]"
                            }
                        } else {
                            if ($sessions[$session]["keyboardIds"] -notcontains 0) {
                                $msgwarn = $true
                                $msgkeyboard = "Keyboard entries found: $keyboardCount [Value(s): $keyboardIds] (Keyboard 0 not found)"
                            } else {
                                $msgkeyboard = "Keyboard entries found: $keyboardCount [Value(s): $keyboardIds]"
                            }
                        }

                        $mouseIds = $sessions[$session]["mouseIds"] -join ", "
                        if ($mouseIds -eq "") { $mouseIds = "N/A" }
                        if ($mouseCount -ne 1) {
                            $msgwarn = $true
                            if ($sessions[$session]["mouseIds"] -notcontains 0) {
                                $msgmouse = "Mouse entries found: $mouseCount (Expected: 1) [Value(s): $mouseIds] (Mouse 0 not found)"
                            } else {
                                $msgmouse = "Mouse entries found: $mouseCount (Expected: 1) [Value(s): $mouseIds]"
                            }
                        } else {
                            if ($sessions[$session]["mouseIds"] -notcontains 0) {
                                $msgwarn = $true
                                $msgmouse = "Mouse entries found: $mouseCount [Value(s): $mouseIds] (Mouse 0 not found)"
                            } else {
                                $msgmouse = "Mouse entries found: $mouseCount [Value(s): $mouseIds]"
                            }
                        }

                        if ($msgwarn) {
                            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "Session ID: $session" -Message3 "$msgkeyboard" -circle "red"
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message3 "$msgmouse" -circle "red"
                        } else {
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "Session ID: $session" -Message3 "$msgkeyboard" -circle "green"
                            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message3 "$msgmouse" -circle "green"
                        }
                    }
                } else {
                    $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$regP found but Session Keyboard/Mouse information could not be retrieved. See <a href='$msrdErrorfileurl' target='_blank'>MSRD-Collect-Error</a> for more information." -circle "red"
                }
            } else {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$regP" -Message2 "not found"
            }
        }
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

#endregion Known Issues


#region Other

Function msrdDiagOffice {

    #Microsoft Office diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Office"
    $menucatmsg = "Other"
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "MSOCheck"

    $oversion = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\O365ProPlusRetail* -ErrorAction Continue 2>>$global:msrdErrorLogFile

    if ($oversion) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Office installation(s)"
        foreach ($oitem in $oversion) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($oitem.Displayname)" -Message3 "$($oitem.DisplayVersion)" -circle "blue"
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        msrdCheckServicePort -service "ClickToRunSvc"

        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\common\' -RegKey 'InsiderSlabBehavior' -RegValue '2' -OptNote 'Computer Policy: Show the option for Office Insider'
        msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\outlook\cached mode\' -RegKey 'enable' -RegValue '1'
        msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\outlook\cached mode\' -RegKey 'syncwindowsetting' -RegValue '1' -OptNote 'Computer Policy: Cached Exchange Mode Sync Settings'
        msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\outlook\cached mode\' -RegKey 'CalendarSyncWindowSetting' -RegValue '1'
        msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Policies\Microsoft\office\16.0\outlook\cached mode\' -RegKey 'CalendarSyncWindowSettingMonths' -RegValue '1'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\officeupdate\' -RegKey 'hideupdatenotifications' -RegValue '1' -OptNote 'Computer Policy: Hide Update Notifications'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\officeupdate\' -RegKey 'hideenabledisableupdates' -RegValue '1' -OptNote 'Computer Policy: Hide option to enable or disable updates'

    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Office installation <span style='color: brown'>not found</span>."
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagOD {

    #Microsoft OneDrive diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "OneDrive"
    $menucatmsg = "Other"
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "MSODCheck"

    $ODM86 = "${env:ProgramFiles(x86)}\Microsoft OneDrive" + '\OneDrive.exe'
    $ODM = "$env:ProgramFiles\Microsoft OneDrive" + '\OneDrive.exe'
    $ODU = "$ENV:localappdata" + '\Microsoft\OneDrive\OneDrive.exe'

    $ODM86test = Test-Path $ODM86
    $ODMtest = Test-Path $ODM
    $ODUtest = Test-Path $ODU

    if (($ODM86test) -or ($ODMtest) -or ($ODUtest)) {

        if ($ODMtest) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "OneDrive installation ($ODM)" -Message2 "per-machine" -circle "blue"
        } elseif ($ODM86test) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "OneDrive installation ($ODM86)" -Message2 "per-machine" -circle "blue"
        } else {
            $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "OneDrive installation ($ODU)" -Message2 "per-user" -circle "red"
        }

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckServicePort -service "OneDrive Updater Service"

        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Processes running"
        msrdProcessCheck -proc "OneDrive" -intName "OneDrive" -noSpacer1
        msrdProcessCheck -proc "shellappruntime" -intName "ShellAppRuntime" -noSpacer2

        msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\OneDrive\' -RegKey 'AllUsersInstall' -RegValue '1'

        if (!($global:msrdSource)) {
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'ConcurrentUserSessions' -RegValue '0' -OptNote 'Computer Policy: Allow concurrent user sessions'
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\FSLogix\Profiles\' -RegKey 'ProfileType' -RegValue '0' -OptNote 'Computer Policy: Profile type'
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\OneDrive\' -RegKey 'WarningMinDiskSpaceLimitInMB' -OptNote 'Computer Policy: Warn users who are low on disk space'
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\FSLogix\ODFC\' -RegKey 'VHDAccessMode' -RegValue '0' -OptNote 'Computer Policy: VHD access type'
        }

        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\' -RegKey 'OneDrive'
        msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\' -RegKey 'OneDrive'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce\' -RegKey 'OneDrive'
        msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce\' -RegKey 'OneDrive'

        if (!($global:msrdSource)) {
            msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\RailRunonce\' -RegKey 'OneDrive'
        }

    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "OneDrive installation <span style='color: brown'>not found</span>."
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdDiagPrinting {

    #Printing diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Printing"
    $menucatmsg = "Other"
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "PrintCheck"

    msrdCheckServicePort -service spooler

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    $printlist = Get-Printer | Select-Object Name, DriverName -ErrorAction Continue | Sort-Object Name 2>>$global:msrdErrorLogFile
    if ($printlist) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Printer(s)"
        foreach ($printitem in $printlist) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table1-3" -Message2 "$($printitem.Name)" -Message3 "$($printitem.DriverName)"
        }
    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Printers <span style='color: brown'>not found</span>"
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Terminal Server Client\' -RegKey 'DisablePrinterRedirection' -RegValue '0'
    msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Terminal Server Client\' -RegKey 'DisablePrinterRedirection' -RegValue '0'

    if (!($global:msrdSource)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Providers\Client Side Rendering Print Provider\' -RegKey 'RemovePrintersAtLogoff'
        msrdCheckRegKeyValue -RegPath 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows\' -RegKey 'MaintainDefaultPrinter'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC\' -RegKey 'RpcNamedPipeAuthentication'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Print\' -RegKey 'RpcAuthnLevelPrivacyEnabled'

        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\' -RegKey 'fDisableCpm' -RegValue '0' -OptNote 'Computer Policy: Do not allow client printer redirection'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\' -RegKey 'fDisableCpm' -RegValue '0'

        if ($global:msrdAVD -or $global:msrdW365) {
            if ($script:msrdListenervalue) {
                msrdCheckRegKeyValue -RegPath ('HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\' + $script:msrdListenervalue + '\') -RegKey 'fDisableCpm' -RegValue '0'
            } else {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Active AVD listener configuration not found" -circle "red"
            }
        }
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

Function msrdProcessCheck {
    Param([Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$proc, [string]$intName, [switch]$noSpacer1, [switch]$noSpacer2, [switch]$addWarning, $warnMessage)

    try {
        $check = Get-Process $proc -ErrorAction SilentlyContinue
        if ($null -eq $check) {
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$intName ($proc)" -Message2 "not found"
        } else {
            $vendor = (Get-Process $proc | Group-Object -Property Company).Name
            if (($null -eq $vendor) -or ($vendor -eq "")) { $vendor = "N/A" }
            $counter = (Get-Process $proc | Group-Object -Property ProcessName).Count
            $desc = (Get-Process $proc | Group-Object -Property Description).Name
            $path = (Get-Process $proc | Group-Object -Property Path).Name
            $prodver = (Get-Process $proc | Group-Object -Property ProductVersion).Name
            if (($null -eq $desc) -or ($desc -eq "")) { $desc = "N/A" }
            if (($null -eq $prodver) -or ($prodver -eq "")) { $prodver = "N/A" }
            if (($null -eq $path) -or ($path -eq "")) { $path = "N/A" }

            if ($addWarning) {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                $pcCircle = "red"
            } else {
                $pcCircle = "blue"
            }

            if (!($noSpacer1)) { msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer" }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$proc ($intName) found running on this system in $counter instance(s)" -Message2 "$prodver" -circle $pcCircle
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Company: $vendor - Description: $desc" -circle $pcCircle
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Path: $path" -circle $pcCircle
            if ($addWarning -and $warnMessage) {
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "$warnMessage" -circle $pcCircle
            }
            if (!($noSpacer2)) { msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer" }
        }
    } catch {
        $FailedCommand = $MyInvocation.Line.TrimStart()
        msrdLogException ("$(msrdGetLocalizedText 'errormsg') $FailedCommand") -ErrObj $_
    }
}

Function msrdCheckRegPath {
    Param([Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$RegPath, [string]$OptNote)

    $isPath = Test-Path -path $RegPath
    if ($isPath) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$RegPath" -Message2 "found" -Title "$OptNote" -circle "red"
    }
    else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$RegPath" -Message2 "not found" -Title "$OptNote"
    }
}

Function msrdDiagCitrix3P {

    #Citrix and other 3rd party software diagnostics
    $global:msrdSetWarning = $false
    $menuitemmsg = "Third Party Software"
    $menucatmsg = "Other"
    msrdLogDiag $LogLevel.Normal -Message $menuitemmsg -DiagTag "3pCheck"

    $CitrixProd = (Get-ItemProperty  hklm:\software\microsoft\windows\currentversion\uninstall\* | Where-Object {($_.DisplayName -like "*Citrix*")})
    $CitrixProd2 = (Get-ItemProperty  hklm:\software\wow6432node\microsoft\windows\currentversion\uninstall\* | Where-Object {($_.DisplayName -like "*Citrix*")})

    if ($CitrixProd -or $CitrixProd2) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Citrix products"
    }

    if ($CitrixProd) {
        foreach ($cprod in $CitrixProd) {
            if ($cprod.DisplayVersion) { $cprodDisplayVersion = $cprod.DisplayVersion } else { $cprodDisplayVersion = "N/A" }
            if ($cprod.InstallDate) {
                $cprodInstallDate = $cprod.InstallDate
                $cprodInstallDate = [datetime]::ParseExact($cprodInstallDate, "yyyyMMdd", $null).ToString("yyyy/MM/dd")
            } else {
                $cprodInstallDate = "N/A"
            }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$($cprod.DisplayName)" -Message2 "$cprodDisplayVersion (Installed on: $cprodInstallDate)" -circle "blue"

            if (($CitrixProd -like "*Citrix Virtual Apps and Desktops*") -and (($cprodDisplayVersion -eq "1912.0.4000.4227") -or ($cprodDisplayVersion -like "2109.*") -or ($cprodDisplayVersion -like "2112.*"))) {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "An older Citrix Virtual Apps and Desktops version has been found. Please consider updating. You could be running into issues described in: https://support.citrix.com/article/CTX338807" -circle "red"
            }
        }
    } elseif ($CitrixProd2) {
        foreach ($cprod2 in $CitrixProd2) {
            if ($cprod2.DisplayVersion) { $cprod2DisplayVersion = $cprod2.DisplayVersion } else { $cprod2DisplayVersion = "N/A" }
            if ($cprod2.InstallDate) {
                $cprod2InstallDate = $cprod2.InstallDate
                $cprod2InstallDate = [datetime]::ParseExact($cprod2InstallDate, "yyyyMMdd", $null).ToString("yyyy/MM/dd")
            } else {
                $cprod2InstallDate = "N/A"
            }
            msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "$($cprod2.DisplayName)" -Message2 "$cprod2DisplayVersion (Installed on: $cprod2InstallDate)" -circle "blue"

            if (($CitrixProd2 -like "*Citrix Virtual Apps and Desktops*") -and (($cprod2DisplayVersion -eq "1912.0.4000.4227") -or ($cprod2DisplayVersion -like "2109.*") -or ($cprod2DisplayVersion -like "2112.*"))) {
                $global:msrdSetWarning = $true; $global:msrdIssueCounter += 1;
                msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "An older Citrix Virtual Apps and Desktops version has been found. Please consider updating. You could be running into issues described in: https://support.citrix.com/article/CTX338807" -circle "red"
            }
        }

    } else {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Table2-1" -Message "Citrix products" -Message2 "not found"
    }

    if (($CitrixProd) -or ($CitrixProd2)) {
        msrdLogDiag $LogLevel.DiagFileOnly -Type "Spacer"
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Citrix\Graphics\' -RegKey 'SetDisplayRequiredMode'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Citrix\GroupPolicy\' -RegKey 'GpoCacheEnabled'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Citrix\GroupPolicy\' -RegKey 'CacheGpoExpireInHours'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Citrix\Ica\GroupPolicy\' -RegKey 'EnforceUserPolicyEvaluationSuccess'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Citrix\Reconnect\' -RegKey 'DisableGPCalculation'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Citrix\Reconnect\' -RegKey 'FastReconnect'
        msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\services\CtxUvi\' -RegKey 'UviProcessExcludes'
        if ($global:msrdW365) {
            msrdCheckRegKeyValue -RegPath 'HKLM:\SOFTWARE\Citrix\VirtualDesktopAgent\' -RegKey 'NgsConnected'
        }
    }

    msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
    msrdLogDiag $LogLevel.DiagFileOnly -Type "Text" -col 3 -Message "Third party processes and settings"
    msrdProcessCheck -proc "aakore" -intName "Acronis Cyber Protect" -noSpacer1
    msrdProcessCheck -proc "cyber-protect-service" -intName "Acronis Cyber Protect"
    msrdProcessCheck -proc "WebCompanion" -intName "Adaware"
    msrdProcessCheck -proc "DefendpointService" -intName "BeyondTrust"
    msrdProcessCheck -proc "vpnagent" -intName "Cisco AnyConnect"
    msrdProcessCheck -proc "csagent" -intName "CrowdStrike"
    msrdProcessCheck -proc "csfalconservice" -intName "CrowdStrike Falcon Sensor"
    msrdProcessCheck -proc "secureconnector" -intName "ForeScout SecureConnector"
    msrdProcessCheck -proc "hwtag" -intName "Forcepoint Endpoint Security Agent"
    msrdProcessCheck -proc "sgpm" -intName "Forcepoint Stonesoft VPN"
    msrdProcessCheck -proc "mcshield" -intName "McAfee"
    msrdProcessCheck -proc "stAgentSvc" -intName "Netskope Client"
    msrdProcessCheck -proc "NVDisplay.Container" -intName "NVIDIA"
    msrdProcessCheck -proc "GpVpnApp" -intName "Palo Alto GlobalProtect"
    msrdProcessCheck -proc "PanGPA" -intName "Palo Alto GlobalProtect"
    msrdProcessCheck -proc "PanGPS" -intName "Palo Alto GlobalProtect"
    msrdProcessCheck -proc "sentinelagent" -intName "SentinelOne Agent"
    msrdProcessCheck -proc "SAVService" -intName "Sophos Anti-Virus"
    msrdProcessCheck -proc "SEDService" -intName "Sophos Endpoint Defense Service"
    msrdCheckRegKeyValue -RegPath 'HKLM:\SYSTEM\CurrentControlSet\Services\Sophos Endpoint Defense\EndpointFlags\' -RegKey 'modernweb.offloading.enabled'
    msrdProcessCheck -proc "SophosNtpService" -intName "Sophos Network Threat Protection"
    msrdProcessCheck -proc "SSPService" -intName "Sophos System Protection Service"
    msrdProcessCheck -proc "swi_fc" -intName "Sophos Web Intelligence Service"
    msrdProcessCheck -proc "wssad" -intName "Symantec WSS Agent"
    msrdProcessCheck -proc "nessusd" -intName "Tenable Nessus"
    msrdProcessCheck -proc "TSPrintManagementService" -intName "TerminalWorks TSPrint Server"
    msrdProcessCheck -proc "tmiacagentsvc" -intName "Trend Micro Application Control"
    msrdProcessCheck -proc "endpointbasecamp" -intName "Trend Micro Endpoint Basecamp"
    msrdProcessCheck -proc "tmbmsrv" -intName "Trend Micro Unauthorized Change Prevention"
    msrdProcessCheck -proc "ivpagent" -intName "Trend Micro Vulnerability Protection"

    if ($global:msrdOSVer -like "*virtu*") {
        msrdProcessCheck -proc "ZSAService" -intName "Zscaler" -noSpacer2 -addWarning -warnMessage "Currently (July 2023) Zscaler does not support using the Zscaler Client Connector on multi-session OS. This is valid until further notice. See the <a href='https://help.zscaler.com/downloads/zscaler-technology-partners/data/zscaler-and-azure-traffic-forwarding-deployment-guide/Zscaler-Azure-Traffic-Forwarding-Deployment-Guide-FINAL.pdf' target='_blank'>Zscaler documentation</a> for Zscaler's latest statement."
    } else {
        msrdProcessCheck -proc "ZSAService" -intName "Zscaler" -noSpacer2
    }

    if (($global:msrdSetWarning) -and (-not $global:msrdLiveDiag)) { msrdHtmlSetMenuWarning -htmloutfile "$msrdDiagFile" -MenuItem $menuitemmsg -MenuCat $menucatmsg }
}

#endregion Other


#start
Function msrdRunUEX_RDDiag {
    param ([bool[]]$varsSystem, [bool[]]$varsAVDRDS, [bool[]]$varsInfra, [bool[]]$varsAD, [bool[]]$varsNET, [bool[]]$varsLogSec, [bool[]]$varsIssues, [bool[]]$varsOther)

    #main Diag
    if ($global:msrdAVD) { $script:msrdMenuCat = "AVD/RDS" } elseif ($global:msrdRDS) { $script:msrdMenuCat = "RDS" } elseif ($global:msrdW365) { $script:msrdMenuCat = "W365/RDS" }

    $global:msrdIssueCounter = 0

    msrdLogMessage $LogLevel.Info -Message "$rdiagmsg`n" -Color "Cyan"

    msrdCreateLogFolder $global:msrdLogDir

    if ($global:msrdSource) { $TitleRole = "Source" } elseif ($global:msrdTarget) { $TitleRole = "Target" }
    if ($global:msrdW365) {
        $TitleScenario = "W365 $TitleRole"
    } elseif ($global:msrdAVD) {
        $TitleScenario = "AVD $TitleRole"
    } elseif ($global:msrdRDS) {
        $TitleScenario = "RDS $TitleRole"
    }

    msrdHtmlInit $msrdDiagFile
    msrdHtmlHeader -htmloutfile $msrdDiagFile -title "MSRD-Diag ($TitleScenario): $($env:computername)" -fontsize "small"
    msrdHtmlBodyDiag -htmloutfile $msrdDiagFile -title "Microsoft CSS Remote Desktop Diagnostics Report ($TitleScenario)" -varsSystem $varsSystem -varsAVDRDS $varsAVDRDS -varsInfra $varsInfra -varsAD $varsAD -varsNET $varsNET -varsLogSec $varsLogSec -varsIssues $varsIssues -varsOther $varsOther

    #system
    if ($varsSystem[0]) { msrdDiagDeployment }
    if ($varsSystem[1]) { msrdDiagCPU }
    if ($varsSystem[2]) { msrdDiagDrives }
    if ($varsSystem[3]) { msrdDiagGraphics }
    if (!($global:msrdSource)) { if ($varsSystem[4]) { msrdDiagActivation } }
    if ($varsSystem[5]) { msrdDiagSSLTLS }
    if ($varsSystem[6]) { msrdDiagUAC }
    if ($varsSystem[7]) { msrdDiagInstaller }
    if (!($global:msrdSource)) { if ($varsSystem[8]) { msrdDiagSearch } }
    if ($varsSystem[9]) { msrdDiagWU }
    if ($varsSystem[10]) { msrdDiagWinRMPS }

    #avd/rds/w365
    if ($varsAVDRDS[0]) { msrdDiagRedirection }
    if (!($global:msrdSource)) { if ($varsAVDRDS[1]) { msrdDiagFSLogix } }
    if ($varsAVDRDS[2]) { msrdDiagMultimedia }
    if ($varsAVDRDS[3]) { msrdDiagQA }
    if (!($global:msrdSource)) {
        if ($varsAVDRDS[4]) { msrdDiagRDPListener }
        if ($global:msrdOSVer -like "*Windows Server*") { if ($varsAVDRDS[5]) { msrdDiagRDSRoles } }
    }
    if ($varsAVDRDS[6]) { msrdDiagRDClient }
    if (!($global:msrdSource)) {
        if ($varsAVDRDS[7]) { msrdDiagLicensing }
        if ($varsAVDRDS[8]) { msrdDiagTimeLimits }
    }
    if (!($global:msrdRDS)) { if ($varsAVDRDS[9]) { msrdDiagTeams } }

    if ($global:msrdW365) { if ($varsAVDRDS[10]) { msrdDiagW365 } }

    #avd infra
    if ($global:msrdAVD -or $global:msrdW365) {
        if (!($global:msrdSource)) {
            if ($varsInfra[0]) { msrdDiagHP }
            if ($varsInfra[1]) { msrdDiagAgentStack }
            if ($varsInfra[2]) { msrdDiagHealthCheck }
        }
    }
    if (!($global:msrdRDS)) { if ($varsInfra[3]) { msrdDiagURL } }
    if (!($global:msrdSource)) {
        if ($global:msrdAVD -or $global:msrdW365) { if ($varsInfra[4]) { msrdDiagURIHealth } }
        if ($global:msrdAVD) { if ($varsInfra[5]) { msrdDiagHCI } }
    }
    if (!($global:msrdRDS)) { if ($varsInfra[6]) { msrdDiagShortpath } }

    if ($global:msrdW365) { if ($varsInfra[7]) { msrdDiagW365reqUrls } }

    #ad
    if ($varsAD[0]) { msrdDiagEntraJoin }
    if ($varsAD[1]) { msrdDiagDC }

    #networking
    if ($varsNET[0]) { msrdDiagNWCore }
    if ($varsNET[1]) { msrdDiagDNS }
    if ($varsNET[2]) { msrdDiagFirewall }
    if ($varsNET[3]) { msrdDiagIPAddresses }
    if ($varsNET[4]) { msrdDiagPortUsage }
    if ($varsNET[5]) { msrdDiagProxy }
    if ($varsNET[6]) { msrdDiagRouting }
    if ($varsNET[7]) { msrdDiagVPN }

    #logon/security
    if ($varsLogSec[0]) { msrdDiagAuth }
    if ($varsLogSec[1]) { msrdDiagSecurity }

    #known issues
    if ($varsIssues[0]) {
        msrdLogDiag $LogLevel.Normal -Message "Issues identified in Event Logs over the past 5 days" -DiagTag "IssuesCheck"
        if (!($global:msrdSource)) {
            if ($global:msrdAVD -or $global:msrdW365) {
                msrdDiagAVDIssueEvents
                msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
            }

            $needHR = $false
            if ($script:foundRDS.Name -eq "RDS-Licensing") { msrdDiagRDLicensingIssueEvents; $needHR = $true }
            if ($script:foundRDS.Name -eq "RDS-GATEWAY") { msrdDiagRDGatewayIssueEvents; $needHR = $true }
            if ($needHR) { msrdLogDiag $LogLevel.DiagFileOnly -Type "HR" }
            msrdDiagRDIssueEvents
            msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        }

        msrdDiagCommonIssueEvents
        if (!($global:msrdSource)) { if ($varsIssues[1]) { msrdDiagLogonIssues } }
    }

    #other
    if (!($global:msrdSource)) {
        if ($varsOther[0]) { msrdDiagOffice }
        if ($varsOther[1]) { msrdDiagOD }
    }
    if ($varsOther[2]) { msrdDiagPrinting }
    if ($varsOther[3]) { msrdDiagCitrix3P }

    msrdHtmlEnd $msrdDiagFile
    msrdHtmlSetIssueCounter -htmloutfile "$msrdDiagFile"
}

Export-ModuleMember -Function *
# SIG # Begin signature block
# MIInvwYJKoZIhvcNAQcCoIInsDCCJ6wCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAWyjK9NU3QGBpg
# l/35bKxKhj8TDageZK3rA01a9anLNaCCDXYwggX0MIID3KADAgECAhMzAAADrzBA
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
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIDuQOk0mNRwNLFPGqd+Dq+kK
# o66Y9WKqUyXCabnDXDOAMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAMOmakBNal3xIcet5x5RZM6FYkOsQVONvsZwSU85CVEx87D2rq0/SgKTK
# W0X3PlpJxaskvzzei/kCGDDwurvfMRifW0yohuiqNLZZGIxV3x7S1qdzI5tsI3Yg
# XNO5JPCiP9igCd/thZ8ci60aUSPK7zbV7678eccE13VKuDf+tcuRk87IMM0L7Wxz
# SAuw5fnsoBVBqmDVH9BcIlrMTCCd0JVEnOjMqGc1pNso6nXWhRscZmc+43/4B/7Z
# nB5PCMEUHjC8ssMGGCOqXPrWdHVTq8ah+0HORa1R3HtIgg2xVsy2fi41OqYs99Tt
# RsYocMxwgACE4nFSGBL94YrxkR4BE6GCFykwghclBgorBgEEAYI3AwMBMYIXFTCC
# FxEGCSqGSIb3DQEHAqCCFwIwghb+AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsq
# hkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCA+SCVVInsN6bGv8egC0yR+rL21XWM8BAsfCCPFwemhywIGZbql3kah
# GBMyMDI0MDIyMDEyMTY1OS4yMTFaMASAAgH0oIHYpIHVMIHSMQswCQYDVQQGEwJV
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
# IgQg8RQKQu6tEwGJfdggf9/nw5BhmGdPV2l+gMER6khOjBowgfoGCyqGSIb3DQEJ
# EAIvMYHqMIHnMIHkMIG9BCAriSpKEP0muMbBUETODoL4d5LU6I/bjucIZkOJCI9/
# /zCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB4pmZ
# lfHc4yDrAAEAAAHiMCIEINj9jjwk1TLFNQu7Sl1tdDvaw/Ukh0QzLxJqZLRW9zR8
# MA0GCSqGSIb3DQEBCwUABIICAI+qnRIHnOdzDgXz/1BMB/MI4njxarpJ7EJWPYDY
# UN4uB+ElYWIgovw43Xu2vSHg/lvjJ84BXv3gp51pojJLqPDKBBvRoM9g13ThLu6x
# xIk8cpcGBpqOCVd/SwzErKFlfqfc0PY6aIA6KWjR1lnC3vrNdr8bIMMgs+UdRX16
# MqiBfiXqgCJ0FYISNVRmX4Dt7VCvfsqagsjyj6/7Jg0XbMY1vG2k6fNRXvbuwOXI
# 7035Ko529qB5F5HSazxTnBF4lCnAgp3qybhTKcLb5zYWBvhC5dGoIMFcW2aMMm7U
# UMz9cVlmUPvkEo6AmSUJykplESEz4nvwMa7LTI6cSLmOuFkNOHm6yParCj/lzHeB
# GLx7aedl7PvX3p0imDjX/GXlRkrWmWhs5P3detCLLEvC+aI6X0KZSApgLsY5PeIy
# MOgHMHNqzckUKtXxF2c6iFPFIhkDSjL4JPe17eI5X8WaZajKnSwyBrtO73o/xFB8
# T1VKRPj+OLDNFMglErBdHUtGPRXPauVB3T5GBwuMycqDPa0Vq7+ICaSMsJSemimI
# 7T4PDljnni1unfySYkIMHXHOS4TYax3QHcULvCDYJdv/0H0X78T6FoNFLlo+b5PK
# VC5TOrZIakf5FNo3OrLWVoOa5AqYuBbDSprDDsRut7JhLj+etQ2N/ssLe5oBKoGP
# enxc
# SIG # End signature block
