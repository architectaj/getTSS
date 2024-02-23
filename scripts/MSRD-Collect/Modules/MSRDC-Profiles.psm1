<#
.SYNOPSIS
   Scenario module for collecting Microsoft Remote Desktop Profiles related data

.DESCRIPTION
   Collect Profiles related troubleshooting data (incl. FSLogix, OneDrive)

.NOTES
   Author     : Robert Klemencz
   Requires   : At least PowerShell 5.1 (This module is not for stand-alone use. It is used automatically from within the main MSRD-Collect.ps1 script)
   Version    : See MSRD-Collect.ps1 version
   Feedback   : https://aka.ms/MSRD-Collect-Feedback
#>

$msrdLogPrefix = "Profiles"
$FSLogixLogFolder = $global:msrdBasicLogFolder + "FSLogix\"

Function msrdGetFSLogixLogFiles {
    Param([Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$LogFilePath,
        [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$LogFileDestination)

    #get FSLogix log files
    msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Copy-Item $LogFilePath"
    if (Test-path -path "$LogFilePath") {
        Try {
            msrdCreateLogFolder $LogFileDestination
            Copy-Item $LogFilePath $LogFileDestination -Recurse -ErrorAction Continue 2>&1 | Out-Null
        } Catch {
            $failedCommand = $_.InvocationInfo.Line.TrimStart()
            msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
        }
    } else {
        msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "'$LogFilePath' folder not found"
    }
}

Function msrdGetFSLogixCompact {

    #get FSLogix compact action logs
    msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "FSLogix VHD compaction events"
    $startTime = (Get-Date).AddDays(-5)

    $diskCompactionEvents = Get-WinEvent -FilterHashtable @{StartTime = $startTime; logname = 'Microsoft-FSLogix-Apps/Operational'; id = 57} -ErrorAction SilentlyContinue

    if ($diskCompactionEvents) {
        $compactionMetrics = $diskCompactionEvents | Select-Object `
            @{l="Timestamp";e={$_.TimeCreated}},`
            @{l="Path";e={$_.Properties[0].Value}},`
            @{l="WasCompacted";e={$_.Properties[1].Value}},`
            @{l="TimeSpent(ms)";e={[math]::round($_.Properties[7].Value,2)}},`
            @{l="MaxSupportedSize(MB)";e={[math]::round($_.Properties[2].Value,2)}},`
            @{l="MinSupportedSize(MB)";e={[math]::round($_.Properties[3].Value,2)}},`
            @{l="InitialSize(MB)";e={[math]::round($_.Properties[4].Value,2)}},`
            @{l="FinalSize(MB)";e={[math]::round($_.Properties[5].Value,2)}},`
            @{l="SavedSpace(MB)";e={[math]::round($_.Properties[6].Value,2)}}

        $compactionMetrics | Out-File -FilePath ($FSLogixLogFolder + $global:msrdLogFilePrefix + "vhdCompactionEvents.txt") -Append
    } else {
        msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "FSLogix VHD compaction events not found"
    }
}

Function msrdGetFSLogixRedirXML {

    #get FSLogix redirection xml information
    msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "FSLogix Redirections XML"

    if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\FSLogix\Profiles\" -value "RedirXMLSourceFolder") {
        $pxml = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\FSLogix\Profiles\" -name "RedirXMLSourceFolder"
        $pxmlfile = $pxml + "\redirections.xml"
        $pxmlout = $FSLogixLogFolder + $env:computername + "_redirectionsXML.txt"

        if (Test-Path -Path $pxmlfile) {
            Try {
                Copy-Item $pxmlfile $pxmlout -ErrorAction Continue 2>&1 | Out-Null
            } Catch {
                msrdLogException ("Error: An exception occurred in msrdGetFSLogixRedirXML $pxmlfile.") -ErrObj $_
            }
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "'$pxmlfile' log not found"
        }
    } else {
        msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "RedirXMLSourceFolder registry key not found"
    }
}

Function msrdGetProfilesRegKeys {

    msrdCreateLogFolder $msrdRegLogFolder
    $regs = @{
        'HKCU:\SOFTWARE\Microsoft\Office' = 'SW-MS-Office'
        'HKCU:\SOFTWARE\Microsoft\OneDrive' = 'SW-MS-OneDrive'
        'HKLM:\SOFTWARE\Microsoft\OneDrive' = 'SW-MS-OneDrive'
        'HKLM:\SOFTWARE\Microsoft\Windows Search' = 'SW-MS-WindowsSearch'
        'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' = 'SW-MS-WinNT-CV-ProfileList'
        'HKCU:\Volatile Environment' = 'VolatileEnvironment'
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\Credential Providers' = 'SW-MS-Win-CV-Auth-CredProviders'
        'HKLM:\SYSTEM\CurrentControlSet\Services\ProfSvc' = 'System-CCS-Svc-ProfSvc'
    }

    if (-not $global:msrdW365) {
        $regs += @{
            'HKLM:\SYSTEM\CurrentControlSet\Enum\SCSI\Disk&Ven_Msft&Prod_Virtual_Disk' = 'System-CCS-Enum-SCSI-ProdVirtualDisk'
            'HKLM:\SOFTWARE\FSLogix' = 'SW-FSLogix'
            'HKLM:\SYSTEM\CurrentControlSet\Services\frxccd' = 'System-CCS-Svc-frxccd'
            'HKLM:\SYSTEM\CurrentControlSet\Services\frxccds' = 'System-CCS-Svc-frxccds'
        }
    }

    msrdGetRegKeys -LogPrefix $msrdLogPrefix -RegHashtable $regs
}

Function msrdGetProfilesEventLogs {

    msrdCreateLogFolder $global:msrdEventLogFolder
    $logs = @{
        'Microsoft-Windows-User Profile Service/Operational' = 'UserProfileService-Operational'
    }

    if (-not $global:msrdW365) {
        $logs += @{
            'Microsoft-Windows-VHDMP-Operational' = 'VHDMP-Operational'
            'Microsoft-FSLogix-Apps/Admin' = 'FSLogix-Apps-Admin'
            'Microsoft-FSLogix-Apps/Operational' = 'FSLogix-Apps-Operational'
            'Microsoft-FSLogix-CloudCache/Admin' = 'FSLogix-CloudCache-Admin'
            'Microsoft-FSLogix-CloudCache/Operational' = 'FSLogix-CloudCache-Operational'
        }

        $eventlog = "Microsoft-Windows-Ntfs/Operational"
        msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Filtered $eventlog event logs"
        $ntfslog = $global:msrdEventLogFolder + $env:computername + "_NTFS_filtered.evtx"

        if (Get-WinEvent -ListLog $eventlog -ErrorAction SilentlyContinue) {
            Try {
                wevtutil epl $eventlog $ntfslog "/q:*[System[(EventID=4 or EventID=142)]]"
            } Catch {
                msrdLogException "Error: An error occurred while exporting the NTFS logs" -ErrObj $_
            }
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "Event log '$eventlog' not found"
        }
    }

    msrdGetEventLogs -LogPrefix $msrdLogPrefix -EventHashtable $logs
}

Function msrdGetFSLogixData {

    if (Test-path -path "$env:ProgramFiles\FSLogix") {

        msrdCreateLogFolder $FSLogixLogFolder
        msrdGetFSLogixCompact
        msrdGetFSLogixRedirXML

        if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\FSLogix\Logging\" -value "LogDir") {
            $fslogixlogsloc = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\FSLogix\Logging\" -name "LogDir"
        } else {
            $fslogixlogsloc = "$env:ProgramData\FSLogix\Logs"
        }

        if (Test-Path -path $fslogixlogsloc) {
            msrdGetFSLogixLogFiles -LogFilePath "$fslogixlogsloc\*" -LogFileDestination ($FSLogixLogFolder + "Logs")

            $Commands = @(
                "tree '$fslogixlogsloc' /f 2>&1 | Out-File -Append '" + $FSLogixLogFolder + "Logs\" + $global:msrdLogFilePrefix + "tree_ProgFiles-FSLogixLogs.txt'"
            )
            msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "'$fslogixlogsloc' folder not found"
        }

        $fslogixrulesloc = "$env:ProgramFiles\FSLogix\Apps\Rules"
        if (Test-Path -path $fslogixrulesloc) {
            msrdCreateLogFolder ($FSLogixLogFolder + "AppsRules")
            msrdGetFSLogixLogFiles -LogFilePath "$fslogixrulesloc\*" -LogFileDestination ($FSLogixLogFolder + "AppsRules")

            $Commands = @(
                "tree '$fslogixrulesloc' /f 2>&1 | Out-File -Append '" + $FSLogixLogFolder + "AppsRules\" + $global:msrdLogFilePrefix + "tree_ProgFiles-FSLogixAppsRules.txt'"
            )
            msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "'$fslogixrulesloc' folder not found"
        }

        $fslogixCompiledrulesloc = "$env:ProgramFiles\FSLogix\Apps\CompiledRules"
        if (Test-Path -path $fslogixCompiledrulesloc) {
            msrdCreateLogFolder ($FSLogixLogFolder + "AppsRules")
            $Commands = @(
                "tree '$fslogixCompiledrulesloc' /f 2>&1 | Out-File -Append '" + $FSLogixLogFolder + "AppsRules\" + $global:msrdLogFilePrefix + "tree_ProgFiles-FSLogixAppsCompiledRules.txt'"
            )
            msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "'$fslogixCompiledrulesloc' folder not found"
        }

        $fslogixfrxloc = "$env:ProgramFiles\FSLogix\Apps\frx.exe"
        if (Test-path -path $fslogixfrxloc) {
            $Commands = @(
                "cmd /c '$fslogixfrxloc' version 2>&1 | Out-File -Append '" + $FSLogixLogFolder + $global:msrdLogFilePrefix + "frx-list.txt'"
                "cmd /c '$fslogixfrxloc' list-redirects 2>&1 | Out-File -Append '" + $FSLogixLogFolder + $global:msrdLogFilePrefix + "frx-list.txt'"
                "cmd /c '$fslogixfrxloc' list-rules 2>&1 | Out-File -Append '" + $FSLogixLogFolder + $global:msrdLogFilePrefix + "frx-list.txt'"
            )
            msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "'$fslogixfrxloc' not found"
        }

        #if applicable, removing accountname and account key from the exported CCDLocations reg key for security reasons
        $ccdRegOutP = $msrdRegLogFolder + $global:msrdLogFilePrefix + "HKLM-SW-FSLogix.txt"
        if (Test-Path -path $ccdRegOutP) {
            $ccdContentP = Get-Content -Path $ccdRegOutP
            $ccdReplaceP = foreach ($ccdItemP in $ccdContentP) {
                if ($ccdItemP -like "*CCDLocations*") {
                    $var1P = $ccdItemP -split ";"
                    $var2P = foreach ($varItemP in $var1P) {
                                if ($varItemP -like "AccountName=*") { $varItemP = "AccountName=xxxxxxxxxxxxxxxx"; $varItemP }
                                elseif ($varItemP -like "AccountKey=*") { $varItemP = "AccountKey=xxxxxxxxxxxxxxxx"; $varItemP }
                                else { $varItemP }
                            }
                    $var3P = $var2P -join ";"
                    $var3P
                } else {
                    $ccdItemP
                }
            }
            $ccdReplaceP | Set-Content -Path $ccdRegOutP
        }

        $ccdRegOutO = $msrdRegLogFolder + $global:msrdLogFilePrefix + "HKLM-SW-Policies.txt"
        if (Test-Path -path $ccdRegOutO) {
            $ccdContentO = Get-Content -Path $ccdRegOutO
            $ccdReplaceO = foreach ($ccdItemO in $ccdContentO) {
                if ($ccdItemO -like "*CCDLocations*") {
                    $var1O = $ccdItemO -split ";"
                    $var2O = foreach ($varItemO in $var1O) {
                                if ($varItemO -like "AccountName=*") { $varItemO = "AccountName=xxxxxxxxxxxxxxxx"; $varItemO }
                                elseif ($varItemO -like "AccountKey=*") { $varItemO = "AccountKey=xxxxxxxxxxxxxxxx"; $varItemO }
                                else { $varItemO }
                            }
                    $var3O = $var2O -join ";"
                    $var3O
                } else {
                    $ccdItemO
                }
            }
            $ccdReplaceO | Set-Content -Path $ccdRegOutO
        }

        msrdGetLocalGroupMembership -logPrefix $msrdLogPrefix -groupName "FSLogix ODFC Exclude List" -outputFile ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "LocalGroupsMembership.txt")
        msrdGetLocalGroupMembership -logPrefix $msrdLogPrefix -groupName "FSLogix ODFC Include List" -outputFile ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "LocalGroupsMembership.txt")
        msrdGetLocalGroupMembership -logPrefix $msrdLogPrefix -groupName "FSLogix Profile Exclude List" -outputFile ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "LocalGroupsMembership.txt")
        msrdGetLocalGroupMembership -logPrefix $msrdLogPrefix -groupName "FSLogix Profile Include List" -outputFile ($global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "LocalGroupsMembership.txt")

        if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\FSLogix\Profiles\" -value "VHDLocations") {
            $pvhd = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\FSLogix\Profiles\" -name "VHDLocations"

            $Commands = @(
                "icacls $pvhd 2>&1 | Out-File -Append " + $FSLogixLogFolder + $global:msrdLogFilePrefix + "folderPermissions.txt"
            )
            msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
        }

        if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC\" -value "VHDLocations") {
            $ovhd = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Policies\FSLogix\ODFC\" -name "VHDLocations"

            $Commands = @(
                "icacls $ovhd 2>&1 | Out-File -Append " + $FSLogixLogFolder + $global:msrdLogFilePrefix + "folderPermissions.txt"
            )
            msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
        }


        #Collecting AAD Kerberos Auth for FSLogix
        $Commands = @(
                "klist get krbtgt 2>&1 | Out-File -Append " + $FSLogixLogFolder + $global:msrdLogFilePrefix + "klist-get-krbtgt.txt"
            )
        msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True

        if (msrdTestRegistryValue -path "HKLM:\SOFTWARE\FSLogix\Profiles\" -value "VHDLocations") {
                $pvhd = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\FSLogix\Profiles\" -name "VHDLocations" -ErrorAction SilentlyContinue
                $pconPath = $pvhd.split("\")[2]
                if ($pconPath) {
                    $Commands = @(
                        "klist get cifs/$pconPath 2>&1 | Out-File -Append " + $FSLogixLogFolder + $global:msrdLogFilePrefix + "klist-get-cifs-ProfileVHDLocations.txt"
                    )
                    msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
                }
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "'HKLM:\SOFTWARE\FSLogix\Profiles\VHDLocations' not found. Skipping 'klist get cifs/...'"
        }

    } else {
        msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $msrdLogPrefix -Message "'$env:ProgramFiles\FSLogix' folder not found"
    }
}

# Collecting User Profiles troubleshooting data
Function msrdCollectUEX_AVDProfilesLog {
    param( [bool[]]$varsProfiles )

    " " | Out-File -Append $global:msrdOutputLogFile
    $profilesmsg = msrdGetLocalizedText "profilesmsg"
    msrdLogMessage $LogLevel.Info ("$profilesmsg")

    if ($varsProfiles[0]) {
        msrdLogMessageAssistMode "Collect User Profiles related event logs"
        msrdGetProfilesEventLogs
    } #profiles event logs

    if ($varsProfiles[1]) {
        msrdLogMessageAssistMode "Collect User Profiles related registry keys"
        msrdGetProfilesRegKeys
    } #profiles reg keys

    if ($varsProfiles[2]) {
        msrdLogMessageAssistMode "Collect WhoAmI information"
        #whoami information
        msrdCreateLogFolder $global:msrdSysInfoLogFolder
        $Commands = @(
            "Whoami /all 2>&1 | Out-File -Append '" + $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "WhoAmI-all.txt'"
        )
        msrdRunCommands -LogPrefix $msrdLogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
    }

    if ($varsProfiles[3] -and (-not $global:msrdW365)) {
        msrdLogMessageAssistMode "Collect FSLogix data"
        msrdGetFSLogixData
    } #fslogix logs
}

Export-ModuleMember -Function msrdCollectUEX_AVDProfilesLog
# SIG # Begin signature block
# MIIoOQYJKoZIhvcNAQcCoIIoKjCCKCYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAYT/U9Gnpmdx6U
# Xw6GaDUmnHPZ40ziS6MMR8nAW7pdO6CCDYUwggYDMIID66ADAgECAhMzAAADri01
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
# cVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCGgowghoGAgEBMIGVMH4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01p
# Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAAOuLTVRyFOPVR0AAAAA
# A64wDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIOmP
# 8w1XnqEYn2Lg6I9+FxvEkUHDOQzagKJv+KrxCI20MEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEA33zl7o7HgfykjwG9iNP3J9jrKcI9YZOsnymn
# UU42UTxD44IPwivLwoTmVcclsib7XSEtGwIpfXDbsDyCwVMk48e6CYWok0a4BCc7
# m01RRU/xRgivT+oRRCTyseap6ii5GiJmjBTSqF4uUd148P0CtRg6fsX7ea+vhyHA
# +CQ6jF9zK7GWCnwlaxp6QZuOD0kRFxMl/3R6YQ5Dd9zZ3UPjlVztsBQPqxXRlEPO
# qn16yL9Csp63ba/tMlR75Qd+TfjuwFrv2QdG2am04PzX4BIzDdqvi/HYzgi34u8k
# fGAh6hCagbVDEfEb4MQLN3nnDu5k351aI8W3pforVCna+U9RdaGCF5QwgheQBgor
# BgEEAYI3AwMBMYIXgDCCF3wGCSqGSIb3DQEHAqCCF20wghdpAgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCDqBwEhTNWq8OTd9mBXi/zNU9+xlAwgKhga
# v0nNcGGcRwIGZc3/hhoqGBMyMDI0MDIyMDEyMTcwMi45ODVaMASAAgH0oIHRpIHO
# MIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQL
# ExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxk
# IFRTUyBFU046OTIwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFNlcnZpY2WgghHqMIIHIDCCBQigAwIBAgITMwAAAecujy+TC08b6QAB
# AAAB5zANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAx
# MDAeFw0yMzEyMDYxODQ1MTlaFw0yNTAzMDUxODQ1MTlaMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046OTIwMC0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Uw
# ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDCV58v4IuQ659XPM1DtaWM
# v9/HRUC5kdiEF89YBP6/Rn7kjqMkZ5ESemf5Eli4CLtQVSefRpF1j7S5LLKisMWO
# GRaLcaVbGTfcmI1vMRJ1tzMwCNIoCq/vy8WH8QdV1B/Ab5sK+Q9yIvzGw47TfXPE
# 8RlrauwK/e+nWnwMt060akEZiJJz1Vh1LhSYKaiP9Z23EZmGETCWigkKbcuAnhvh
# 3yrMa89uBfaeHQZEHGQqdskM48EBcWSWdpiSSBiAxyhHUkbknl9PPztB/SUxzRZj
# UzWHg9bf1mqZ0cIiAWC0EjK7ONhlQfKSRHVLKLNPpl3/+UL4Xjc0Yvdqc88gOLUr
# /84T9/xK5r82ulvRp2A8/ar9cG4W7650uKaAxRAmgL4hKgIX5/0aIAsbyqJOa6OI
# GSF9a+DfXl1LpQPNKR792scF7tjD5WqwIuifS9YUiHMvRLjjKk0SSCV/mpXC0BoP
# kk5asfxrrJbCsJePHSOEblpJzRmzaP6OMXwRcrb7TXFQOsTkKuqkWvvYIPvVzC68
# UM+MskLPld1eqdOOMK7Sbbf2tGSZf3+iOwWQMcWXB9gw5gK3AIYK08WkJJuyzPqf
# itgubdRCmYr9CVsNOuW+wHDYGhciJDF2LkrjkFUjUcXSIJd9f2ssYitZ9CurGV74
# BQcfrxjvk1L8jvtN7mulIwIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFM/+4JiAnzY4
# dpEf/Zlrh1K73o9YMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8G
# A1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMv
# Y3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBs
# BggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUy
# MDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUH
# AwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4ICAQB0ofDbk+llWi1c
# C6nsfie5Jtp09o6b6ARCpvtDPq2KFP+hi+UNNP7LGciKuckqXCmBTFIhfBeGSxvk
# 6ycokdQr3815pEOaYWTnHvQ0+8hKy86r1F4rfBu4oHB5cTy08T4ohrG/OYG/B/gN
# nz0Ol6v7u/qEjz48zXZ6ZlxKGyZwKmKZWaBd2DYEwzKpdLkBxs6A6enWZR0jY+q5
# FdbV45ghGTKgSr5ECAOnLD4njJwfjIq0mRZWwDZQoXtJSaVHSu2lHQL3YHEFikun
# bUTJfNfBDLL7Gv+sTmRiDZky5OAxoLG2gaTfuiFbfpmSfPcgl5COUzfMQnzpKfX6
# +FkI0QQNvuPpWsDU8sR+uni2VmDo7rmqJrom4ihgVNdLaMfNUqvBL5ZiSK1zmaEL
# BJ9a+YOjE5pmSarW5sGbn7iVkF2W9JQIOH6tGWLFJS5Hs36zahkoHh8iD963LeGj
# ZqkFusKaUW72yMj/yxTeGEDOoIr35kwXxr1Uu+zkur2y+FuNY0oZjppzp95AW1le
# hP0xaO+oBV1XfvaCur/B5PVAp2xzrosMEUcAwpJpio+VYfIufGj7meXcGQYWA8Um
# r8K6Auo+Jlj8IeFS6lSvKhqQpmdBzAMGqPOQKt1Ow3ZXxehK7vAiim3ZiALlM0K5
# 46k0sZrxdZPgpmz7O8w9gHLuyZAQezCCB3EwggVZoAMCAQICEzMAAAAVxedrngKb
# SZkAAAAAABUwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmlj
# YXRlIEF1dGhvcml0eSAyMDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIy
# NVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UE
# AxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXI
# yjVX9gF/bErg4r25PhdgM/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjo
# YH1qUoNEt6aORmsHFPPFdvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1y
# aa8dq6z2Nr41JmTamDu6GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v
# 3byNpOORj7I5LFGc6XBpDco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pG
# ve2krnopN6zL64NF50ZuyjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viS
# kR4dPf0gz3N9QZpGdc3EXzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYr
# bqgSUei/BQOj0XOmTTd0lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlM
# jgK8QmguEOqEUUbi0b1qGFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSL
# W6CmgyFdXzB0kZSU2LlQ+QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AF
# emzFER1y7435UsSFF5PAPBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIu
# rQIDAQABo4IB3TCCAdkwEgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIE
# FgQUKqdS/mTEmr6CkTxGNSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWn
# G1M1GelyMFwGA1UdIARVMFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEW
# M2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5
# Lmh0bTATBgNVHSUEDDAKBggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBi
# AEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV
# 9lbLj+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3Js
# Lm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAx
# MC0wNi0yMy5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2
# LTIzLmNydDANBgkqhkiG9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv
# 6lwUtj5OR2R4sQaTlz0xM7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZn
# OlNN3Zi6th542DYunKmCVgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1
# bSNU5HhTdSRXud2f8449xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4
# rPf5KYnDvBewVIVCs/wMnosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU
# 6ZGyqVvfSaN0DLzskYDSPeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDF
# NLB62FD+CljdQDzHVG2dY3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/
# HltEAY5aGZFrDZ+kKNxnGSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdU
# CbFpAUR+fKFhbHP+CrvsQWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKi
# excdFYmNcP7ntdAoGokLjzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTm
# dHRbatGePu1+oDEzfbzL6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZq
# ELQdVTNYs6FwZvKhggNNMIICNQIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJp
# Y2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjkyMDAtMDVF
# MC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMK
# AQEwBwYFKw4DAhoDFQCzcgTnGasSwe/dru+cPe1NF/vwQ6CBgzCBgKR+MHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA6X5sAjAi
# GA8yMDI0MDIyMDAwMDgzNFoYDzIwMjQwMjIxMDAwODM0WjB0MDoGCisGAQQBhFkK
# BAExLDAqMAoCBQDpfmwCAgEAMAcCAQACAh4kMAcCAQACAhOuMAoCBQDpf72CAgEA
# MDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAI
# AgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAEjBdhxc2Dy1IiI/abmk2E8Is2Yg
# KjvpKrgHVxrmR6uToVLP+UTfGUj2Wdk6mOU9tYSo2+fynkECZN0DoKjTEGh4Crnk
# ehLBVuWNgWLsCZc4U+fPnNmgZ2qAoDCCXREnJR9JIJm5UtNXteuMozC7q8xxg/do
# s4gse4eoUCHByHFAsQF2yQH4lw0AL5Ue8QK/wBmQWo0hdzZhEo/AGIWBJd5X4190
# yduqpmJpj4buYrRtrFQzbAVLlTIHmz8KofO3bdLsozBU9WK9+/+8a1AXn1SyEt5h
# LUX4UrzcmTMmM9UIFyLGwG1hDOrZI6UOtwP+SPLuYv5fTIvLKjn62cj88bgxggQN
# MIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAecu
# jy+TC08b6QABAAAB5zANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0G
# CyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCCcYH+TG/b7JJ8iPNqCWCnFmgYn
# vOTzhO8i7Su4bi3pkTCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIOU2XQ12
# aob9DeDFXM9UFHeEX74Fv0ABvQMG7qC51nOtMIGYMIGApH4wfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAHnLo8vkwtPG+kAAQAAAecwIgQg5strNsYb
# AJScKAE5aG3Lom5LvoS5tFxoBQ4e8fINHe0wDQYJKoZIhvcNAQELBQAEggIAq9bO
# BnKtdx8zxvb1ENbzBZ4K6iN68wCiBj9WA+Q65y2xLh8+fdjXEDi0mH0v4rHdoy8w
# gyU1hoz8KmdmhjgFbedxY9Xv04/7w238TfophCZVTLhaXHqSIVMYuFeaHaGcLvRD
# Wv0zECpcQO/IvFslnyzSeK3JUj/xhNRMinRAfCxfBPqXmLJawShBz5qMrcUxxJ0z
# 58jmfFsQWxcRppuKzVZNoLM1nByFJyBsuWKe//8qfz6kIHfVxOmziWjwVDc7vvTL
# dyvosiLdft7+jdTUgC7ir0CRTnB3CcgcmNY3QsT0Q8X1DM/yHL5Jdt1z3sEDj+IY
# 8UI7L07FNvvlO2jBpar9selmxyqThmDjSSZ6cL6QzHmvaIodHRx1SrjV4s8JX43G
# RKIqekI8LiCKQAgIFQLEK0fMwCQslJNAUUccOg9mHBJGGTCA6oIYrgoH4iCz8mGl
# hPN4oQ6Xnnfj3vi2ZredZmGGkppB9ZvF19vcQ2TNG3ZssWr29Whek4InViCDhbpr
# HlOWzr9zKz0+vRir2qwUvc/4ieideHMMW9YaiV+dTJN4LmDSfxB761sbg+5Twnnb
# 8YYyXbprkRsSKQPrQ4GMPOwmTnUhcZ9JvsfKnqu4nD3M8psMvKxhjMjtOFDnPwUU
# qT8PyONlYX9hLxils9qJyuHkY2qB7jyjyWMrFkY=
# SIG # End signature block
