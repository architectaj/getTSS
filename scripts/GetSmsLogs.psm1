# GetSmsLogs.psm1 https://github.com/nedpyle/storagemigrationservicehelper
# https://raw.githubusercontent.com/nedpyle/storagemigrationservicehelper/master/StorageMigrationServiceHelper.psm1
# Date: Jun 15, 2020

# Windows Server Storage Migration Service Helper

# Copyright (c) Microsoft Corporation. All rights reserved.

# MIT License

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


Function GetSmsLogsFolder($Path, [ref]$SmsLogsFolder)
{
    $suffix = $null
    $folderNamePrefix = "StorageMigrationLog_$targetComputerName"
    
    do
    {
        $p = $Path + "\$folderNamePrefix"
        if ($null -ne $suffix)
        {
            $p += "_$suffix"
            $suffix += 1
        }
        else
        {
            $suffix = 1
        }
    } while (Test-Path $p -erroraction 'silentlycontinue')
    
    $SmsLogsFolder.value = $p
}

Function LogAction($message)
{
    Write-Output "==> $message"
}

Function GetSmsEventLogs($SmsLogsFolder)
{
    $names = @{
        "Microsoft-Windows-StorageMigrationService/Debug" = "$($targetComputerName)_Sms_Debug.log"
        "Microsoft-Windows-StorageMigrationService-Proxy/Debug" ="$($targetComputerName)_Proxy_Debug.log"
    }

    foreach ($key in $names.Keys)
    {
        $outFile = $names[$key]
        LogAction "Collecting traces for $($key) (outFile=$outFile)"
        
        $outFullFile = "$SmsLogsFolder\$outFile"
        
        if (! $computerNameWasProvided)
        {
            get-winevent -logname $key -oldest -ea SilentlyContinue | foreach-object {$_.Message} > "$outFullFile"
        }
        else
        {
            if ($null -eq $Credential)
            {
                Get-WinEvent -ComputerName $targetComputerName -logname $key -oldest -ea SilentlyContinue | foreach-object {$_.Message} > "$outFullFile"
            }
            else
            {
                Get-WinEvent -ComputerName $targetComputerName -Credential $Credential -logname $key -oldest -ea SilentlyContinue | foreach-object {$_.Message} > "$outFullFile"
            }
        }
    }
}

Function GetSmsEventLogs2($SmsLogsFolder)
{
    $names = @{
    "Microsoft-Windows-StorageMigrationService/Admin" = "$($targetComputerName)_Sms_Admin.log"
    "Microsoft-Windows-StorageMigrationService/Operational" = "$($targetComputerName)_Sms_Operational.log"

    "Microsoft-Windows-StorageMigrationService-Proxy/Admin" = "$($targetComputerName)_Proxy_Admin.log"
    "Microsoft-Windows-StorageMigrationService-Proxy/Operational" = "$($targetComputerName)_Proxy_Operational.log"
    }

    foreach ($key in $names.Keys)
    {
        $outFile = $names[$key]
        LogAction "Collecting traces for $($key) (outFile=$outFile)"
        
        $outFullFile = "$SmsLogsFolder\$outFile"
        
        if (! $computerNameWasProvided)
        {
            get-winevent -logname $key -oldest -ea SilentlyContinue | foreach-object { #write "$_.TimeCreated $_.Id $_.LevelDisplayName $_.Message"} > "$outFullFile"
                $id=$_.Id;
                $l = (0, (6 - $id.Length) | Measure-Object -Max).Maximum
                $m = "$($_.TimeCreated) {0,$l} $($_.LevelDisplayName) " -f $id
                $m += $_.Message
                $m
            } > "$outFullFile"

        }
        else
        {
            if ($null -eq $Credential)
            {
                Get-WinEvent -ComputerName $targetComputerName -logname $key -oldest -ea SilentlyContinue | foreach-object {#write "$_.TimeCreated $_.Id $_.LevelDisplayName $_.Message"} > "$outFullFile"
                    $id=$_.Id;
                    $l = (0, (6 - $id.Length) | Measure-Object -Max).Maximum
                    $m = "$($_.TimeCreated) {0,$l} $($_.LevelDisplayName) " -f $id
                    $m += $_.Message
                    $m
                } > "$outFullFile"
            }
            else
            {
                Get-WinEvent -ComputerName $targetComputerName -Credential $Credential -logname $key -oldest -ea SilentlyContinue | foreach-object {#write "$_.TimeCreated $_.Id $_.LevelDisplayName $_.Message"} > "$outFullFile"
                    $id=$_.Id;
                    $l = (0, (6 - $id.Length) | Measure-Object -Max).Maximum
                    $m = "$($_.TimeCreated) {0,$l} $($_.LevelDisplayName) " -f $id
                    $m += $_.Message
                    $m
                } > "$outFullFile"
            }
        }
    }
}


Function GetSystemEventLogs($SmsLogsFolder)
{
    $outFile = "$($targetComputerName)_System.log"
    $outFullFile = "$SmsLogsFolder\$outFile"
    
    if (! $computerNameWasProvided)
    {
        get-winevent -logname System -oldest -ea SilentlyContinue | foreach-object {
            $id=$_.Id;
            $l = (0, (6 - $id.Length) | Measure-Object -Max).Maximum
            $m = "$($_.TimeCreated) {0,$l} $($_.LevelDisplayName) " -f $id
            $m += $_.Message
            $m
        } > "$outFullFile"
    }
    else
    {
        if ($null -eq $Credential)
        {
            get-winevent -ComputerName $targetComputerName -logname System -oldest -ea SilentlyContinue | foreach-object {
                $id=$_.Id;
                $l = (0, (6 - $id.Length) | Measure-Object -Max).Maximum
                $m = "$($_.TimeCreated) {0,$l} $($_.LevelDisplayName) " -f $id
                $m += $_.Message
                $m
            } > "$outFullFile"
        }
        else
        {
            get-winevent -ComputerName $targetComputerName -Credential $Credential -logname System -oldest -ea SilentlyContinue | foreach-object {
                $id=$_.Id;
                $l = (0, (6 - $id.Length) | Measure-Object -Max).Maximum
                $m = "$($_.TimeCreated) {0,$l} $($_.LevelDisplayName) " -f $id
                $m += $_.Message
                $m
            } > "$outFullFile"
        }
    }
}

Function GetSystemInfo($SmsLogsFolder)
{
    if (! $computerNameWasProvided)
    {
        $remoteFeatures = Get-WindowsFeature
        
        $windows = $env:systemroot
	    $orcver = Get-ChildItem $windows\sms\* | Format-List versioninfo
	    $proxyver = Get-ChildItem $windows\smsproxy\* | Format-List versioninfo
        
    }
    else
    {
        if ($null -eq $Credential)
        {
            $remoteFeatures = Get-WindowsFeature -ComputerName $targetComputerName
        }
        else
        {
            $remoteFeatures = Get-WindowsFeature -ComputerName $targetComputerName -Credential $Credential
        }
    }
    
    $remoteFeatures | Format-Table -AutoSize
    
    if ($computerNameWasProvided)
    {
        # We want to find out whether SMS cmdlets are present on the local computer
        $features = Get-WindowsFeature *SMS*
    }
    else
    {
        $features = $remoteFeatures
    }

    $areSmsCmdletsAvailable = $false
    $isSmsInstalled = $false
    Write-Output $orcver
    Write-Output $proxyver
    
    foreach ($feature in $features)
    {
        if ($feature.Name -eq "RSAT-SMS")
        {
            $areSmsCmdletsAvailable = $feature.Installed
            break
        }
    }
    
    foreach ($feature in $remoteFeatures)
    {
        if ($feature.Name -eq "SMS")
        {
            $isSmsInstalled = $feature.Installed
            break
        }
    }
    
    Write-Output "areSmsCmdletsAvailable: $areSmsCmdletsAvailable"
    Write-Output "isSmsInstalled: $isSmsInstalled"

    if ($areSmsCmdletsAvailable -and $isSmsInstalled)
    {
        if (! $computerNameWasProvided)
        {
            $smsStates = Get-SmsState
        }
        else
        {
            if ($null -eq $Credential)
            {
                $smsStates = Get-SmsState -OrchestratorComputerName $targetComputerName
            }
            else
            {
                $smsStates = Get-SmsState -OrchestratorComputerName $targetComputerName -Credential $Credential
            }
        }
        
        Write-Output $smsStates
Write-Output "After ###################"

        foreach ($state in $smsStates)
        {
            $job = $state.Job
            Write-Output "+++"
            Write-Output "Inventory summary for job: $job"
            
            if (! $computerNameWasProvided)
            {
                $inventorySummary = Get-SmsState -Name $job -InventorySummary
            }
            else
            {
                if ($null -eq $Credential)
                {
                    $inventorySummary = Get-SmsState -OrchestratorComputerName $targetComputerName -Name $job -InventorySummary
                }
                else
                {
                    $inventorySummary = Get-SmsState -OrchestratorComputerName $targetComputerName -Credential $Credential -Name $job -InventorySummary
                }
            }
            
            Write-Output $inventorySummary

            foreach ($entry in $inventorySummary)
            {
                $device = $entry.Device
                Write-Output "!!!"
                Write-Output "Inventory config detail for device: $device"

                if (! $computerNameWasProvided)
                {
                    $detail = Get-SmsState -Name $job -ComputerName $device -InventoryConfigDetail
                }
                else
                {
                    if ($null -eq $Credential)
                    {
                        $detail = Get-SmsState -OrchestratorComputerName $targetComputerName -Name $job -ComputerName $device -InventoryConfigDetail
                    }
                    else
                    {
                        $detail = Get-SmsState -OrchestratorComputerName $targetComputerName -Credential $Credential -Name $job -ComputerName $device -InventoryConfigDetail
                    }
                }

                Write-Output $detail

                Write-Output "!!!"
                Write-Output "Inventory SMB detail for device: $device"

                if (! $computerNameWasProvided)
                {
                    $detail = Get-SmsState -Name $job -ComputerName $device -InventorySMBDetail
                }
                else
                {
                    if ($null -eq $Credential)
                    {
                        $detail = Get-SmsState -OrchestratorComputerName $targetComputerName -Name $job -ComputerName $device -InventorySMBDetail
                    }
                    else
                    {
                        $detail = Get-SmsState -OrchestratorComputerName $targetComputerName -Credential $Credential -Name $job -ComputerName $device -InventorySMBDetail
                    }
                }

                Write-Output $detail
            }

            if ($state.LastOperation -ne "Inventory")
            {
                Write-Output "+++"
                Write-Output "Transfer summary for job: $job"

                if (! $computerNameWasProvided)
                {
                    $transferSummary = Get-SmsState -Name $job -TransferSummary
                }
                else
                {
                    if ($null -eq $Credential)
                    {
                        $transferSummary = Get-SmsState -OrchestratorComputerName $targetComputerName -Name $job -TransferSummary
                    }
                    else
                    {
                        $transferSummary = Get-SmsState -OrchestratorComputerName $targetComputerName -Credential $Credential -Name $job -TransferSummary
                    }
                }
                
                Write-Output $transferSummary

                foreach ($entry in $inventorySummary)
                {
                    $device = $entry.Device
                    Write-Output "!!!"
                    Write-Output "Transfer SMB detail for device: $device"

                    if (! $computerNameWasProvided)
                    {
                        $detail = Get-SmsState -Name $job -ComputerName $device -TransferSMBDetail
                    }
                    else
                    {
                        if ($null -eq $Credential)
                        {
                            $detail = Get-SmsState -OrchestratorComputerName $targetComputerName -Name $job -ComputerName -ComputerName $device $device -TransferSMBDetail
                        }
                        else
                        {
                            $detail = Get-SmsState -OrchestratorComputerName $targetComputerName -Credential $Credential -Name $job -ComputerName $device -ComputerName $device -TransferSMBDetail
                        }
                    }

                    Write-Output $detail
                }
                
                Write-Output "+++"
                Write-Output "Cutover summary for job: $job"

                if (! $computerNameWasProvided)
                {
                    $cutoverSummary = Get-SmsState -Name $job -CutoverSummary
                }
                else
                {
                    if ($null -eq $Credential)
                    {
                        $cutoverSummary = Get-SmsState -OrchestratorComputerName $targetComputerName -Name $job -CutoverSummary
                    }
                    else
                    {
                        $cutoverSummary = Get-SmsState -OrchestratorComputerName $targetComputerName -Credential $Credential -Name $job -CutoverSummary
                    }
                }

                Write-Output $cutoverSummary
            }
            Write-Output "==="
        }

    }
}

Function Get-SmsLogs (
    [string] $ComputerName = $null,
    [System.Management.Automation.PSCredential] $Credential = $null,
    [string] $Path = (Get-Item -Path ".\").FullName
)
{
    $error.Clear()
    
    if ($null -eq $ComputerName -or $ComputerName -eq "")
    {
        $computerNameWasProvided = $false
        $targetComputerName = "$env:ComputerName"
    }
    else
    {
        $computerNameWasProvided = $true
        $targetComputerName = $ComputerName
    }

    [string]$smsLogsFolder = ""
    
    GetSmsLogsFolder -Path $path -SmsLogsFolder ([ref]$smsLogsFolder)

    LogAction "Creating directory '$smsLogsFolder'"
    $null = New-Item -Path $smsLogsFolder -Type Directory
    
    Start-Transcript -Path "$smsLogsFolder\$($targetComputerName)_Get-SmsLogs.log" -Confirm:0
    
    $date = Get-Date
    Write-Output "Get-SmsLogs started on $date"
    
    Write-Output "ComputerName: '$ComputerName'"
    Write-Output "TargetComputerName: '$targetComputerName'"
    Write-Output "Path: '$Path'"

    GetSmsEventLogs  -SmsLogsFolder $SmsLogsFolder
    GetSmsEventLogs2 -SmsLogsFolder $SmsLogsFolder
    GetSystemEventLogs -SmsLogsFolder $SmsLogsFolder
    GetSystemInfo -SmsLogsFolder $SmsLogsFolder
    
    $date = Get-Date
    Write-Output "Get-SmsLogs finished on $date"
    
    Stop-Transcript

    Compress-Archive -Path $SmsLogsFolder -DestinationPath $SmsLogsFolder -CompressionLevel Optimal
    
    LogAction "ZIP file containing the logs: '$($SmsLogsFolder).zip'"
}

Export-ModuleMember -Function Get-SmsLogs
# SIG # Begin signature block
# MIInvwYJKoZIhvcNAQcCoIInsDCCJ6wCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAgAAgg6UHeKdKQ
# FmD/T3zaovgmvApsGFatBo3dSqTRmKCCDXYwggX0MIID3KADAgECAhMzAAADrzBA
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
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIAKypfTRyOd3mBYBUeWsQLCo
# udc0FfOo+f3LEkZc7GwoMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEADOllJCIcyv7L0GuZnHA7L6migxcKO7JjPRj+Pi1fOQSxPcPOlxB9hsFW
# HXtsA9bd0iWSCwk0FOE2oXNUx2yHtw9K2BEM3/oGpLzH1/575RRDKS4apwnTYWiS
# lpwFTrZ/QKJ+YlWLhztlL4sT3JqUpBu9olntMs+VztLSy+8Nm1p1iSlpyhXCihZW
# cJSJ9kyKGsmHC6kf9MyvQOGTd0lOtnzAc7sGrQ+LHeWDSBb+ctVdmdpZah6tRw+8
# EwVXGgPlhI27kJzvICPVcT5/Qd/FvmAP5ck5jkwOQNp12RXDw8cB1RKUKvzXUP2/
# 7u3T1OMjhjMqkbGeG9h/2Zp1y0bAXKGCFykwghclBgorBgEEAYI3AwMBMYIXFTCC
# FxEGCSqGSIb3DQEHAqCCFwIwghb+AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsq
# hkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCDuSf+SdmvI6ZuK5dlXjRvdMxwTk8q8Q/rpLE+9PK9gPgIGZbqlXieW
# GBMyMDI0MDIyMDEyMTY1OS4wMDVaMASAAgH0oIHYpIHVMIHSMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJl
# bGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNO
# OkQwODItNEJGRC1FRUJBMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNloIIReDCCBycwggUPoAMCAQICEzMAAAHcweCMwl9YXo4AAQAAAdwwDQYJ
# KoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjMx
# MDEyMTkwNzA2WhcNMjUwMTEwMTkwNzA2WjCB0jELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3Bl
# cmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpEMDgyLTRC
# RkQtRUVCQTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAIvIsyA1sjg9kSKJzelrUWF5
# ShqYWL83amn3SE5JyIVPUC7F6qTcLphhHZ9idf21f0RaGrU8EHydF8NxPMR2KVNi
# AtCGPJa8kV1CGvn3beGB2m2ltmqJanG71mAywrkKATYniwKLPQLJ00EkXw5TSwfm
# JXbdgQLFlHyfA5Kg+pUsJXzqumkIvEr0DXPvptAGqkdFLKwo4BTlEgnvzeTfXukz
# X8vQtTALfVJuTUgRU7zoP/RFWt3WagahZ6UloI0FC8XlBQDVDX5JeMEsx7jgJDdE
# nK44Y8gHuEWRDq+SG9Xo0GIOjiuTWD5uv3vlEmIAyR/7rSFvcLnwAqMdqcy/iqQP
# MlDOcd0AbniP8ia1BQEUnfZT3UxyK9rLB/SRiKPyHDlg8oWwXyiv3+bGB6dmdM61
# ur6nUtfDf51lPcKhK4Vo83pOE1/niWlVnEHQV9NJ5/DbUSqW2RqTUa2O2KuvsyRG
# MEgjGJA12/SqrRqlvE2fiN5ZmZVtqSPWaIasx7a0GB+fdTw+geRn6Mo2S6+/bZEw
# S/0IJ5gcKGinNbfyQ1xrvWXPtXzKOfjkh75iRuXourGVPRqkmz5UYz+R5ybMJWj+
# mfcGqz2hXV8iZnCZDBrrnZivnErCMh5Flfg8496pT0phjUTH2GChHIvE4SDSk2hw
# WP/uHB9gEs8p/9Pe/mt9AgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQU6HPSBd0OfEX3
# uNWsdkSraUGe3dswHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYD
# VR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9j
# cmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwG
# CCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIw
# MjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcD
# CDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBANnrb8Ewr8eX/H1s
# Kt3rnwTDx4AqgHbkMNQo+kUGwCINXS3y1GUcdqsK/R1g6Tf7tNx1q0NpKk1JTupU
# JfHdExKtkuhHA+82lT7yISp/Y74dqJ03RCT4Q+8ooQXTMzxiewfErVLt8Wefebnc
# ST0i6ypKv87pCYkxM24bbqbM/V+M5VBppCUs7R+cETiz/zEA1AbZL/viXtHmryA0
# CGd+Pt9c+adsYfm7qe5UMnS0f/YJmEEMkEqGXCzyLK+dh+UsFi0d4lkdcE+Zq5JN
# jIHesX1wztGVAtvX0DYDZdN2WZ1kk+hOMblUV/L8n1YWzhP/5XQnYl03AfXErn+1
# Eatylifzd3ChJ1xuGG76YbWgiRXnDvCiwDqvUJevVRY1qy4y4vlVKaShtbdfgPyG
# eeJ/YcSBONOc0DNTWbjMbL50qeIEC0lHSpL2rRYNVu3hsHzG8n5u5CQajPwx9Pzp
# sZIeFTNHyVF6kujI4Vo9NvO/zF8Ot44IMj4M7UX9Za4QwGf5B71x57OjaX53gxT4
# vzoHvEBXF9qCmHRgXBLbRomJfDn60alzv7dpCVQIuQ062nyIZKnsXxzuKFb0TjXW
# w6OFpG1bsjXpOo5DMHkysribxHor4Yz5dZjVyHANyKo0bSrAlVeihcaG5F74SZT8
# FtyHAW6IgLc5w/3D+R1obDhKZ21WMIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJ
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
# bmQgT3BlcmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpE
# MDgyLTRCRkQtRUVCQTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUAHDn/cz+3yRkIUCJfSbL3djnQEqaggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AOl+12kwIhgPMjAyNDAyMjAxNTQ2NDlaGA8yMDI0MDIyMTE1NDY0OVowdDA6Bgor
# BgEEAYRZCgQBMSwwKjAKAgUA6X7XaQIBADAHAgEAAgIJHDAHAgEAAgIR4DAKAgUA
# 6YAo6QIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAID
# B6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBAH7/G50oJwgXvHQ/Cisv
# /+4NgU7bsuZ84u0SOjDYlbV7RwcbvJnVOVh0ENJgvC/BbCyK/w/Ni2TVm9mRwP0i
# scVoFa50km3ZuokQuXwXX5C9EI9biLrktz0Bn96PRXNlPWITZxbcxcMJiES65rYn
# OK7un4sD2flSovKorqkDXzsEMYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgUENBIDIwMTACEzMAAAHcweCMwl9YXo4AAQAAAdwwDQYJYIZIAWUDBAIB
# BQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQx
# IgQge3jTjjqiiUSM7MyoSVjUlp6GrSChcOE+qbLuM0oUHHIwgfoGCyqGSIb3DQEJ
# EAIvMYHqMIHnMIHkMIG9BCBTpxeKatlEP4y8qZzjuWL0Ou0IqxELDhX2TLylxIIN
# NzCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB3MHg
# jMJfWF6OAAEAAAHcMCIEIMq+2CFXJYA28rws+5gL9LlWmreOOAJUqesR6p1SI0xw
# MA0GCSqGSIb3DQEBCwUABIICAFPPE6tZgKA6AdXorR0RxyNDP5+9hDzp6/zd1FlN
# 92+QCDkTztSrPylEGXmhYGSQcFVUZu9c17XvpaBkn2uX03x+ciMNmYqyyYRj8t5+
# dUoHMYoCRo4+Hf5C5JUOd8o/FaQvfeq+32tiO5vV810owz0+16YO2Jg087Qk916z
# WeNozx/2UCRBwh2zZ8WKIyDTE7hwI/pvor7cZCj4BQFa17ouUmFS8RX7/38+uJY0
# 0AtXk3Iuoup42mx7IselIC0vGHvsrJgIn7xKVG3AIT7wXt57wA95aQWOwTyzL8O6
# nJQqHTK7bYvQjk2kCmPWcVkI4BS5nlp8+aq0vzPnhhdfkUXkV3vccehB0AsOP9gZ
# MuNXr72zgCw+UkF+SmCdrDlE6xUgc7NFQcHAcedNiJ3TX12dcNhk/G5bkaigqM9C
# T1roD8WlKQ7132RavJ0hdS1od0vZlaX3VeGCyaECij8wvcO2a2wYM80mQtt9Kv2g
# ctzZSWW1HGnnJjmpbpERhej1+TbDkKMoBbGsSsesj4L2EmXdX3CSyxNNBgHJbGra
# dh4kpZh3JuUqxOgd0wrC7s4pbEZkOmNYC1JwHsZuS74PfdHFhc47Kwb21LmNB+1K
# XFyN14m1obvjyh2ogxbiM3zGRoG4WxB5n+wMyW40l0Cc8Jfw5XYkNT2JvdNVYpgf
# /yMf
# SIG # End signature block
