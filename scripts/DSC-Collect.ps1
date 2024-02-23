param( [string]$DataPath, [switch]$AcceptEula )

$version = "DSC-Collect (20230419)"
# by Gianni Bragante - gbrag@microsoft.com

Function GetStore($store) {
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
      } elseif (($ext.oid.value -eq "2.5.29.35") -or ($ext.oid.value -eq "2.5.29.1")) { 
        $asn = New-Object Security.Cryptography.AsnEncodedData ($ext.oid,$ext.RawData)
        $aki = $asn.Format($true).ToString().Replace(" ","")
        $aki = (($aki -split '\n')[0]).Replace("KeyID=","").Trim()
        $row.AuthorityKeyIdentifier = $aki
      } elseif (($ext.oid.value -eq "1.3.6.1.4.1.311.21.7") -or ($ext.oid.value -eq "1.3.6.1.4.1.311.20.2")) { 
        $asn = New-Object Security.Cryptography.AsnEncodedData ($ext.oid,$ext.RawData)
        $tmpl = $asn.Format($true).ToString().Replace(" ","")
        $template = (($tmpl -split '\n')[0]).Replace("Template=","").Trim()
        $row.Template = $template
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

$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal = new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
if (-not $myWindowsPrincipal.IsInRole($adminRole)) {
  Write-Output "This script needs to be run as Administrator"
  exit
}

$global:Root = Split-Path (Get-Variable MyInvocation).Value.MyCommand.Path
$resName = "DSC-Results-" + $env:computername +"-" + $(get-date -f yyyyMMdd_HHmmss)

if ($DataPath) {
  if (-not (Test-Path $DataPath)) {
    Write-Host "The folder $DataPath does not exist"
    exit
  }
  $global:resDir = $DataPath + "\" + $resName
} else {
  $global:resDir = $global:Root + "\" + $resName
}
New-Item -itemtype directory -path $global:resDir | Out-Null

$global:outfile = $global:resDir + "\script-output.txt"
$global:errfile = $global:resDir + "\script-errors.txt"

Import-Module ($global:Root + "\Collect-Commons.psm1") -Force -DisableNameChecking

Write-Log $version
if ($AcceptEula) {
  Write-Log "AcceptEula switch specified, silently continuing"
  $eulaAccepted = ShowEULAIfNeeded "DSC-Collect" 2
} else {
  $eulaAccepted = ShowEULAIfNeeded "DSC-Collect" 0
  if($eulaAccepted -ne "Yes")
   {
     Write-Log "EULA declined, exiting"
     exit
   }
 }
Write-Log "EULA accepted, continuing"

Write-Log "PowerShell version"
$PSVersionTable | Out-File -FilePath ($global:resDir + "\PSVersion.txt") -Append

if (Test-Path -Path "C:\Program Files\WindowsPowerShell\DscService\RegistrationKeys.txt") {
  Write-Log "Registration keys"
  Copy-Item "C:\Program Files\WindowsPowerShell\DscService\RegistrationKeys.txt" ($global:resDir + "\RegistrationKeys.txt")
}

Write-Log "Collecing the dumps of the WMIPrvSE process having dsccore.dll or dsctimer.dll loaded"
try {
  $list = Get-Process -Name "WmiPrvSe" -ErrorAction SilentlyContinue 2>>$global:errfile
}
catch {
  Write-Log "Can't find any running WMIPrvSE process"
}
if (($list | measure).count -gt 0) {
  foreach ($proc in $list)
  {
    #$prov = Get-Process -id $proc.id -Module -ErrorAction SilentlyContinue | Where-Object {($_.ModuleName -eq "dsccore.dll") -or ($_.ModuleName -eq "dsctimer.dll") } 
    if ((Get-Process -id $proc.id -Module -ErrorAction SilentlyContinue | Where-Object {$_.ModuleName -eq "dsccore.dll" } | Measure).Count -gt 0) {
      Write-Log ("Found " + $proc.Name + "(" + $proc.id + ")")
      CreateProcDump $proc.id $global:resDir "WMIPrvSE-DSCCore"
    }
    if ((Get-Process -id $proc.id -Module -ErrorAction SilentlyContinue | Where-Object {$_.ModuleName -eq "dsctimer.dll" } | Measure).Count -gt 0) {
      Write-Log ("Found " + $proc.Name + "(" + $proc.id + ")")
      CreateProcDump $proc.id $global:resDir "WMIPrvSE-DSCTimer"
    }
  }
}

$DSCDb = "C:\Program Files\WindowsPowerShell\DscService\Devices.edb"
if (Test-Path -Path ($env:windir + "\System32\inetsrv\Config\ApplicationHost.config")) {
  Write-Log "IIS ApplicationHost.config"
  Copy-Item "C:\Windows\System32\inetsrv\Config\ApplicationHost.config" ($global:resDir + "\ApplicationHost.config")

  $doc = (Get-content ($env:windir + "\System32\inetsrv\Config\ApplicationHost.config")) -as [xml]
  $logdir = ($doc.configuration.'system.applicationHost'.log.ChildNodes[1].directory).Replace("%SystemDrive%", $env:SystemDrive)
  
  foreach ($site in $doc.configuration.'system.applicationHost'.sites.site) {
    Write-Log ("Copying web.config and logs for the website " + $site.name)
    $sitedir = $global:resDir + "\websites\" + $site.name
    New-Item -itemtype directory -path $sitedir | Out-Null
    write-host $site.name, $site.application.ChildNodes[0].physicalpath
    $path = ($site.application.ChildNodes[0].physicalpath).Replace("%SystemDrive%", $env:SystemDrive)
    if (Test-Path -Path ($path + "\web.config")) {
      Copy-Item -path ($path + "\web.config") -destination $sitedir -ErrorAction Continue 2>>$global:errfile

      $siteLogDir = ($logdir + "\W3SVC" + $site.id)
      $last = Get-ChildItem -path ($siteLogDir) | Sort CreationTime -Descending | Select Name -First 1 
      Copy-Item ($siteLogDir + "\" + $last.name) $sitedir -ErrorAction Continue 2>>$global:errfile

      if ($site.name -eq "PSDSCPullServer") {
        FileVersion -Filepath ($path + "\bin\Microsoft.Powershell.DesiredStateConfiguration.Service.dll") -Log $true
        # GetFileVersion ($path + "\bin\Microsoft.Powershell.DesiredStateConfiguration.Service.dll")
        $docDSC = (Get-content ($path + "\web.config")) -as [xml]
        foreach ($conf in $docDSC.configuration.appSettings.add) {
          if ($conf.key -eq "dbconnectionstr") {
            $DSCDb = $conf.value
            Write-Log ("DSC dbconnectionstr = " + $DSCDb )
          }
        }
      }
    }
  }
 }

if (Test-Path -Path "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config\web.config") {
  Write-Log "Globabl web.config"
  Copy-Item "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config\web.config" ($global:resDir + "\global-web.config")
}

$dir = $env:windir + "\system32\logfiles\HTTPERR"
if (Test-Path -path $dir) {
  $last = Get-ChildItem -path ($dir) | Sort CreationTime -Descending | Select Name -First 1 
  Copy-Item ($dir + "\" + $last.name) $global:resDir\httperr.log -ErrorAction Continue 2>>$global:errfile
}

Write-Log "DISM logs"
Compress-Archive -Path ($env:windir + "\Logs\DISM") -DestinationPath ($global:resDir + "\dism.zip")

Write-Log "CBS logs"
Compress-Archive -Path ($env:windir + "\Logs\CBS") -DestinationPath ($global:resDir + "\cbs.zip")

if (Test-Path -Path "C:\Program Files\WindowsPowerShell\DscService\Devices.edb") {
  $cmd = "cmd.exe /c esentutl.exe /y """ + $DSCDb +  """ /vssrec"
  Write-Log $cmd
  Invoke-Expression $cmd
  Move-Item .\Devices.edb $global:resDir
}

Write-Log "DSC Configuration"
Copy-Item "C:\Windows\System32\Configuration" -Recurse $global:resDir

if (Test-Path -Path "C:\WindowsAzure\Logs\WaAppAgent.log") {
  Write-Log "Windows Azure Guest Agent log"
  Copy-Item "C:\WindowsAzure\Logs\WaAppAgent.log" ($global:resDir + "\WaAppAgent.log")
}

if (Test-Path -Path "C:\WindowsAzure\Logs\Plugins\Microsoft.Powershell.DSC") {
  Write-Log "Azure DSC Extension Logs"
  Copy-Item "C:\WindowsAzure\Logs\Plugins\Microsoft.Powershell.DSC" -Recurse ($global:resDir + "\AzureDSCLogs")
}

if (Test-Path -Path "C:\Packages\Plugins\Microsoft.Powershell.DSC") {
  Write-Log "Azure DSC Extension Package"
  Copy-Item "C:\Packages\Plugins\Microsoft.Powershell.DSC" -Recurse ($global:resDir + "\AzureDSCPackage")
}

if (Test-Path -Path "C:\Windows\Temp\ScriptLog.log") {
  Write-Log "Windows Virtual Desktop log"
  Copy-Item "C:\Windows\Temp\ScriptLog.log" ($global:resDir + "\WVD-ScriptLog.log")
}

if (Test-Path -Path "HKLM:\SOFTWARE\Microsoft\Azure\DSC") {
  Write-Log "Exporting registry key HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Azure\DSC"
  $cmd = "reg export HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Azure\DSC """+ $global:resDir + "\AzureDSC.reg.txt"" /y >>""" + $global:outfile + """ 2>>""" + $global:errfile + """"
  Invoke-Expression $cmd
}

if (Test-Path -Path "C:\Program Files\WindowsPowerShell\DscService\Configuration") {
  Write-Log "DSC Service Configuration"
  New-Item -itemtype directory -path ($global:resDir + "\DscService") | Out-Null
  Copy-Item "C:\Program Files\WindowsPowerShell\DscService\Configuration" -Recurse ($global:resDir + "\DscService")
}

Write-Log "Installed certificates"
Get-ChildItem Cert:\LocalMachine\My\ | Out-File -FilePath ($global:resDir + "\CertLocalMachineMy.txt")

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
$col = New-Object system.Data.DataColumn Template,([string]); $tbCert.Columns.Add($col)

GetStore "My"
GetStore "CA"
GetStore "Root"

Write-Log "Matching issuer thumbprints"
$aCert = $tbCert.Select("Store = 'My' or Store = 'CA'")
foreach ($cert in $aCert) {
  $aIssuer = $tbCert.Select("SubjectKeyIdentifier = '" + ($cert.AuthorityKeyIdentifier).tostring() + "'")
  if ($aIssuer.Count -gt 0) {
    $cert.IssuerThumbprint = ($aIssuer[0].Thumbprint).ToString()
  }
}
$tbcert | Export-Csv ($global:resDir + "\certificates.tsv") -noType -Delimiter "`t"

Write-Log "Get-Module output"
Get-Module -ListAvailable | Out-File -FilePath ($global:resDir + "\Get-Module.txt")

Write-Log "Get-DscResource output"
Get-DscResource | Out-File -FilePath ($global:resDir + "\Get-DscResource.txt")

Write-Log "Get-DscLocalConfigurationManager output"
$lcm = Get-DscLocalConfigurationManager 
$lcm | Out-File -FilePath ($global:resDir + "\Get-DscLocalConfigurationManager.txt")
("ConfigurationDownloadManagers.serverURL = " + $lcm.ConfigurationDownloadManagers.serverURL) | Out-File -FilePath ($global:resDir + "\Get-DscLocalConfigurationManager.txt") -Append
("ReportManagers.serverURL = " + $lcm.ReportManagers.serverURL) | Out-File -FilePath ($global:resDir + "\Get-DscLocalConfigurationManager.txt") -Append

try {
  Write-Log "Get-DscConfiguration output"
  Get-DscConfiguration | Out-File -FilePath ($global:resDir + "\Get-DscConfiguration.txt")
} 
catch {
  Write-Log "Get-DscConfiguration failed, DSC not configured on this machine?"
}

Write-Log "Get-DscConfigurationStatus output"
Get-DscConfigurationStatus -all 2>>$global:errfile | Out-File -FilePath ($global:resDir + "\Get-DscConfigurationStatus.txt")

$dir = $env:windir + "\system32\inetsrv"
if (Test-Path -Path ($dir + "\appcmd.exe")) {
  $cmd = $dir + "\appcmd list wp >""" + $global:resDir + "\IIS-WorkerProcesses.txt""" + $RdrErr
  Write-Log $cmd
  Invoke-Expression ($cmd) | Out-File -FilePath $global:outfile -Append  

  $lines = Get-Content ($global:resDir + "\IIS-WorkerProcesses.txt")
  foreach ($line in $lines) {
    $aLine = $line.Split("""")
    if ($aLine[2] -match "applicationPool:PSWS") {
      CreateProcDump $aLine[1] $global:resDir "W3WP"
    }
  }
}

Write-Log "Get-WinSystemLocale output"
"Get-WinSystemLocale" | Out-File -FilePath ($global:resDir + "\LanguageInfo.txt") -Append
Get-WinSystemLocale | Out-File -FilePath ($global:resDir + "\LanguageInfo.txt") -Append

Write-Log "Exporting registry key HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\HTTP"
$cmd = "reg export HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\HTTP """+ $global:resDir + "\HTTP.reg.txt"" /y" + $RdrOut + $RdrErr
Write-Log $cmd
Invoke-Expression $cmd

Write-Log "Exporting ipconfig /all output"
$cmd = "ipconfig /all >""" + $global:resDir + "\ipconfig.txt""" + $RdrErr
Write-Log $cmd
Invoke-Expression ($cmd) | Out-File -FilePath $global:outfile -Append

Export-EventLog "Application"
Export-EventLog "System"
Export-EventLog "Microsoft-Windows-WMI-Activity/Operational"
Export-EventLog "Microsoft-Windows-DSC/Operational"
Export-EventLog "Microsoft-Windows-CAPI2/Operational"
Export-EventLog "Microsoft-Windows-Powershell-DesiredStateConfiguration-PullServer/Operational"
Export-EventLog "Microsoft-Windows-PowerShell-DesiredStateConfiguration-FileDownloadManager/Operational"
Export-EventLog "Microsoft-Windows-ManagementOdataService/Operational"
Export-EventLog "Microsoft-Windows-PowerShell/Operational"
Export-EventLog "Microsoft-Windows-WinRM/Operational"

Write-Log "WinHTTP proxy configuration"
$cmd = "netsh winhttp show proxy >""" + $global:resDir + "\WinHTTP-Proxy.txt""" + $RdrErr
Write-Log $cmd
Invoke-Expression ($cmd) | Out-File -FilePath $global:outfile -Append

Write-Log "NSLookup WPAD"
"------------------" | Out-File -FilePath ($global:resDir + "\WinHTTP-Proxy.txt") -Append
"NSLookup WPAD" | Out-File -FilePath ($global:resDir + "\WinHTTP-Proxy.txt") -Append
"" | Out-File -FilePath ($global:resDir + "\WinHTTP-Proxy.txt") -Append
$cmd = "nslookup wpad >>""" + $global:resDir + "\WinHTTP-Proxy.txt""" + $RdrErr
Write-Log $cmd
Invoke-Expression ($cmd) | Out-File -FilePath $global:outfile -Append

Write-Log "Collecting details about running processes"
if (ListProcsAndSvcs) {
  CollectSystemInfoWMI
  ExecQuery -Namespace "root\cimv2" -Query "select * from Win32_Product" | Sort-Object Name | Format-Table -AutoSize -Property Name, Version, Vendor, InstallDate | Out-String -Width 400 | Out-File -FilePath ($global:resDir + "\products.txt")

  Write-Log "Collecting the list of installed hotfixes"
  Get-HotFix -ErrorAction SilentlyContinue 2>>$global:errfile | Sort-Object -Property InstalledOn | Out-File $global:resDir\hotfixes.txt

  Write-Log "Collecing GPResult output"
  $cmd = "gpresult /h """ + $global:resDir + "\gpresult.html""" + $RdrErr
  write-log $cmd
  Invoke-Expression ($cmd) | Out-File -FilePath $global:outfile -Append

  $cmd = "gpresult /r >""" + $global:resDir + "\gpresult.txt""" + $RdrErr
  Write-Log $cmd
  Invoke-Expression ($cmd) | Out-File -FilePath $global:outfile -Append
} else {
  Write-Log "WMI is not working"
  $proc = Get-Process | Where-Object {$_.Name -ne "Idle"}
  $proc | Format-Table -AutoSize -property id, name, @{N="WorkingSet";E={"{0:N0}" -f ($_.workingset/1kb)};a="right"},
  @{N="VM Size";E={"{0:N0}" -f ($_.VirtualMemorySize/1kb)};a="right"},
  @{N="Proc time";E={($_.TotalProcessorTime.ToString().substring(0,8))}}, @{N="Threads";E={$_.threads.count}},
  @{N="Handles";E={($_.HandleCount)}}, StartTime, Path | 
  Out-String -Width 300 | Out-File -FilePath ($global:resDir + "\processes.txt")
  CollectSystemInfoNoWMI
}
# SIG # Begin signature block
# MIInvwYJKoZIhvcNAQcCoIInsDCCJ6wCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAoPhUXbwmRuXCf
# YKddOGdxkA3tOdgoMrzNasNmMf3HQKCCDXYwggX0MIID3KADAgECAhMzAAADrzBA
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
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIP1G8ZBJd3xiYQHnl3mwNjIl
# U2fvVpKpFrCKXEzMVbcAMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEArF48FI+rexFuzz+sUMcyYJP0TDAQP41rE+twHs0nsVCjsFBJyWg4RsPj
# Nopjk5LIWbR2eSgZszzGg2hej34zIMbldUIt0bGiI/bOVy9JqiEiHmNsOhiV+nXs
# S7JWyWEa80QEkcWljIUsGbnsFrkQo/9Z9fZwkYJu7EcRkUt6rciHmZLBi70MvCIG
# Ci4Lhzqu1Su2i8xEWaU1ZhCRi92A2YPUta58ie+8PTVufjRNoKD9gGG3vf3Yo5CA
# MD8Ydjd7UnI2GP/KRiomQ3h2GsGKfeB6QEN/Z8LWVEdhTdNObegd2JY1uJsZfVY/
# BfWSoeC1nw5zjU5b3EG3HeWO1y8O76GCFykwghclBgorBgEEAYI3AwMBMYIXFTCC
# FxEGCSqGSIb3DQEHAqCCFwIwghb+AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsq
# hkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCBB4ioVbrkgTutwVj3p5LZ7UkgOPip+tPrvWjMchkEPeAIGZbqiEEHS
# GBMyMDI0MDIyMDEyMTY1OC4zMzVaMASAAgH0oIHYpIHVMIHSMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJl
# bGFuZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNO
# Ojg2REYtNEJCQy05MzM1MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNloIIReDCCBycwggUPoAMCAQICEzMAAAHdXVcdldStqhsAAQAAAd0wDQYJ
# KoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjMx
# MDEyMTkwNzA5WhcNMjUwMTEwMTkwNzA5WjCB0jELMAkGA1UEBhMCVVMxEzARBgNV
# BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jv
# c29mdCBDb3Jwb3JhdGlvbjEtMCsGA1UECxMkTWljcm9zb2Z0IElyZWxhbmQgT3Bl
# cmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjo4NkRGLTRC
# QkMtOTMzNTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAKhOA5RE6i53nHURH4lnfKLp
# +9JvipuTtctairCxMUSrPSy5CWK2DtriQP+T52HXbN2g7AktQ1pQZbTDGFzK6d03
# vYYNrCPuJK+PRsP2FPVDjBXy5mrLRFzIHHLaiAaobE5vFJuoxZ0ZWdKMCs8acjhH
# UmfaY+79/CR7uN+B4+xjJqwvdpU/mp0mAq3earyH+AKmv6lkrQN8zgrcbCgHwsqv
# vqT6lEFqYpi7uKn7MAYbSeLe0pMdatV5EW6NVnXMYOTRKuGPfyfBKdShualLo88k
# G7qa2mbA5l77+X06JAesMkoyYr4/9CgDFjHUpcHSODujlFBKMi168zRdLerdpW0b
# BX9EDux2zBMMaEK8NyxawCEuAq7++7ktFAbl3hUKtuzYC1FUZuUl2Bq6U17S4CKs
# qR3itLT9qNcb2pAJ4jrIDdll5Tgoqef5gpv+YcvBM834bXFNwytd3ujDD24P9Dd8
# xfVJvumjsBQQkK5T/qy3HrQJ8ud1nHSvtFVi5Sa/ubGuYEpS8gF6GDWN5/KbveFk
# dsoTVIPo8pkWhjPs0Q7nA5+uBxQB4zljEjKz5WW7BA4wpmFm24fhBmRjV4Nbp+n7
# 8cgAjvDSfTlA6DYBcv2kx1JH2dIhaRnSeOXePT6hMF0Il598LMu0rw35ViUWcAQk
# UNUTxRnqGFxz5w+ZusMDAgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQUbqL1toyPUdpF
# yyHSDKWj0I4lw/EwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYD
# VR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9j
# cmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwG
# CCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIw
# MjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcD
# CDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAC5U2bINLgXIHWbM
# cqVuf9jkUT/K8zyLBvu5h8JrqYR2z/eaO2yo1Ooc9Shyvxbe9GZDu7kkUzxSyJ1I
# ZksZZw6FDq6yZNT3PEjAEnREpRBL8S+mbXg+O4VLS0LSmb8XIZiLsaqZ0fDEcv3H
# eA+/y/qKnCQWkXghpaEMwGMQzRkhGwcGdXr1zGpQ7HTxvfu57xFxZX1MkKnWFENJ
# 6urd+4teUgXj0ngIOx//l3XMK3Ht8T2+zvGJNAF+5/5qBk7nr079zICbFXvxtidN
# N5eoXdW+9rAIkS+UGD19AZdBrtt6dZ+OdAquBiDkYQ5kVfUMKS31yHQOGgmFxuCO
# zTpWHalrqpdIllsy8KNsj5U9sONiWAd9PNlyEHHbQZDmi9/BNlOYyTt0YehLbDov
# mZUNazk79Od/A917mqCdTqrExwBGUPbMP+/vdYUqaJspupBnUtjOf/76DAhVy8e/
# e6zR98PkplmliO2brL3Q3rD6+ZCVdrGM9Rm6hUDBBkvYh+YjmGdcQ5HB6WT9Rec8
# +qDHmbhLhX4Zdaard5/OXeLbgx2f7L4QQQj3KgqjqDOWInVhNE1gYtTWLHe4882d
# /k7Lui0K1g8EZrKD7maOrsJLKPKlegceJ9FCqY1sDUKUhRa0EHUW+ZkKLlohKrS7
# FwjdrINWkPBgbQznCjdE2m47QjTbMIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJ
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
# bmQgT3BlcmF0aW9ucyBMaW1pdGVkMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjo4
# NkRGLTRCQkMtOTMzNTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUANiNHGWXbNaDPxnyiDbEOciSjFhCggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AOl+1M4wIhgPMjAyNDAyMjAxNTM1NDJaGA8yMDI0MDIyMTE1MzU0MlowdDA6Bgor
# BgEEAYRZCgQBMSwwKjAKAgUA6X7UzgIBADAHAgEAAgIROzAHAgEAAgIU6zAKAgUA
# 6YAmTgIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAID
# B6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBAFwXC+hYoaHbUS7VcR29
# dmdLKgSxXeyhs13vmkOLQTxUDzHuhEQOcfcwIYlAPaJcd1R6Mc/WkCZGXr0ZB35X
# w2HqnDSDwe1mZuITaCzFuPxRTqKAgI7L9L/kj3ua5GNtc/NBRrlPMyx3qFRsKITF
# i71X5TTzaYAM261baFztbDhCMYIEDTCCBAkCAQEwgZMwfDELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgUENBIDIwMTACEzMAAAHdXVcdldStqhsAAQAAAd0wDQYJYIZIAWUDBAIB
# BQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQx
# IgQg0LIO9cgBC33Qh8lxfTlJEwx2DV9A5kEV6jP8vOxtCC4wgfoGCyqGSIb3DQEJ
# EAIvMYHqMIHnMIHkMIG9BCBh/w4tmmWsT3iZnHtH0Vk37UCN02lRxY+RiON6wDFj
# ZjCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB3V1X
# HZXUraobAAEAAAHdMCIEIA/x5yFjDf2ETKAA2doWpZHnl3XsOqD31cwMfKv1rNPZ
# MA0GCSqGSIb3DQEBCwUABIICACFDAyBU7bnpM4fF4XdzkhR3WufF4jCJBZ2/RG8J
# rgtvG7GPStLehKtJvdZK/aAv9ZTrEdZj7h6LV0NRVg1zRLbkx3R7OwmRoFGtmmSh
# uJF4kULZppH5CoEtbGsQuqDwbfPwiUWrKyUYwxuIkapzm5d/nCVPtSKQVihzpZPr
# XY7N/eNcMNuenCuTJIfyWwVRQS4Ev5eK1Vv9SstI3MtPbiATpJVvYMvBZ6L8K6Yj
# 4OH8KaVE1Lgq+Eh/lMUGZg2M06qpTH8wTP13MePshHik89sWc9Ew6Ib97jpLnu+q
# D6T4qM2ZP0BuLBROaaoEaXYP8SVkNGpgvRwBoezgSoHyHamtIhCSva95bjYkDCVX
# /KJfpPgf5tn7OA39ZEnn6jB3AK2BbrAO03VUxJ0F/x/WDkd4iTELRXAfO8AIa5p9
# fehP9W1WVzZhFSKXpuH0hSKcRFSpE2O7c8CgiRQapZ4Or8zY76ORoh/ME2Be7Uwk
# haeZHba/s+WeEADiUtx0nF9fLHHcUrXnqQWWJ1sG7CqjLe64fMIpQEixQVCovm4L
# 3htrwg8/ApPLXwflOxC7CPfbEGH1h1Jni5z5ciCJE1tf8NQRMa6ezxSvzkjbYfIv
# J0774XIW+VfpTrs+IXbwOggYuByiH8u6O1vZsOM6PUXiNOtnLaIdCziHPIErOmJh
# 2OXV
# SIG # End signature block
