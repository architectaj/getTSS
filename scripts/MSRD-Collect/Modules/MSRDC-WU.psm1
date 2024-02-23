<#
.SYNOPSIS
   Module for extended installed Windows Updates report

.DESCRIPTION
   Collects information on installed Windows Updates and generates a report in .html format

.NOTES
   Author     : Robert Klemencz
   Requires   : At least PowerShell 5.1 (This module is not for stand-alone use. It is used automatically from within the main MSRD-Collect.ps1 script)
   Version    : See MSRD-Collect.ps1 version
   Feedback   : https://aka.ms/MSRD-Collect-Feedback
#>

$msrdLogPrefix = "Core"
$WUFile = $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "UpdateHistory.html"
$Script:WUErrors

Function msrdPrintUpdate ([string]$Category,[string]$ID,[string]$Operation,[string]$Date,[string]$ClientID,[string]$InstalledBy,[string]$OperationResult,[string]$Title,[string]$Description,[string]$HResult,[string]$UnmappedResultCode) {

	if ($Category -eq "QFE hotfix") { $Category = "Other updates not listed in history" }

	if (-not [String]::IsNullOrEmpty($ID)) {
		$NumberHotFixID = msrdToNumber $ID
		if($NumberHotFixID.Length -gt 5) {
			$SupportLink = "http://support.microsoft.com/kb/$NumberHotFixID"
		}
	} else {
		$ID = ""
		$SupportLink = ""
	}

	if ([String]::IsNullOrEmpty($Title)) {
		$Title = ""
	} else {
		if (($Title -like "*Security Update*System*") -or ($Title -like "*Cumulative Update*System*") -or ($Title -like "*Mise à jour cumulative*Windows*")) {
			$Title = "<b>" + $Title.Trim() + "</b>"
		} else {
			$Title = $Title.Trim()
		}
	}

	if ([String]::IsNullOrEmpty($Description)) {
		$Description = ""
	} else {
		$Description = $Description.Trim()
	}

	switch($OperationResult) {
        'Completed successfully' { $tdcircle = "circle_green" }
        'Operation was aborted' { $tdcircle = "circle_red" }
		'Completed with errors' { $tdcircle = "circle_red" }
		'Failed to complete' { $tdcircle = "circle_red" }
        'In progress' { $tdcircle = "circle_blue" }
        default { $tdcircle = "circle_white" }
	}

	if ((-not [String]::IsNullOrEmpty($HResult)) -and ($HResult -ne 0)) {
		$HResultHex = msrdConvertToHex $HResult
		$HResultArray = msrdGetWUErrorCodes $HResultHex

		$errmsg = "Error code: $HResultHex"

		if ($null -ne $HResultArray) {
			$errmsg = $errmsg + " (" + $HResultArray[0] + " - " + $HResultArray[1] + ")"
		}

		$HResultHex2 = msrdConvertToHex $UnmappedResultCode
		$errmsg = "<tr><td width='10px'><div class='circle_red'></div></td><td colspan='3'></td><td colspan='3' style='background-color: #FFFFDD'>$errmsg [$HResultHex2]</td></tr>"
	}

	$DiagMessage = "<tr>
		<td width='10px'><div class='$tdcircle'></div></td>
		<td width='17%' style='padding-left: 5px;'>$Category</td>
		<td width='11%'>$Date</td>
		<td width='6%'>$Operation</td>
		<td width='11%'>$OperationResult</td>
		<td width='7%'><a href='$SupportLink' target='_blank'>$ID</a></td>
		<td><span title='$Description' style='cursor: pointer'>$Title</span></td>
	</tr>"

	Add-Content $WUFile $DiagMessage
	if ($errmsg) { Add-Content $WUFile $errmsg }
}

Function msrdGetHotFixFromRegistry {
	$RegistryHotFixList = @{}
	$UpdateRegistryKeys = @("HKLM:\SOFTWARE\Microsoft\Updates")

	#if $OSArchitecture -ne X86 , should be 64-bit machine. we also need to check HKLM:\SOFTWARE\Wow6432Node\Microsoft\Updates
	if($OSArchitecture -ne "X86")
	{
		$UpdateRegistryKeys += "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Updates"
	}

	foreach($RegistryKey in $UpdateRegistryKeys) {
		If(Test-Path $RegistryKey) {
			$AllProducts = Get-ChildItem $RegistryKey -Recurse | Where-Object {$_.Name.Contains("KB") -or $_.Name.Contains("Q")}

			foreach($subKey in $AllProducts) {
				if($subKey.Name.Contains("KB") -or $subKey.Name.Contains("Q")) {
					$HotFixID = msrdGetHotFixID $subKey.Name

					if($RegistryHotFixList.Keys -notcontains $HotFixID) {
						$Category = [regex]::Match($subKey.Name,"Updates\\(?<Category>.*?)[\\]").Groups["Category"].Value
						$HotFix = @{HotFixID=$HotFixID;Category=$Category}
						foreach($property in $subKey.Property)
						{
							$HotFix.Add($property,$subKey.GetValue($property))
						}
						$RegistryHotFixList.Add($HotFixID,$HotFix)
					}
				}
			}
		}
	}
	return $RegistryHotFixList
}

Function msrdGetHotFixID ($strContainID) {
	return [System.Text.RegularExpressions.Regex]::Match($strContainID,"(KB|Q)\d+(v\d)?").Value
}

Function msrdToNumber ($strHotFixID) {
	return [System.Text.RegularExpressions.Regex]::Match($strHotFixID,"([0-9])+").Value
}

Function msrdFormatStr ([string]$strValue,[int]$NumberofChars) {

	if([String]::IsNullOrEmpty($strValue)) {
		$strValue = " "
		return $strValue.PadRight($NumberofChars," ")
	} else {
		if($strValue.Length -lt $NumberofChars) {
			return $strValue.PadRight($NumberofChars," ")
		} else {
			return $strValue.Substring(0,$NumberofChars)
		}
	}
}

# dates with dd/mm/yy hh:mm:ss
Function msrdFormatDateTime ($dtLocalDateTime,[Switch]$SortFormat) {

	if([string]::IsNullOrEmpty($dtLocalDateTime)) { return "" }

	if($SortFormat.IsPresent) {
		# Obtain dates on yyyymmdddhhmmss
		return Get-Date -Date $dtLocalDateTime -Format "yyyyMMddHHmmss"
	} else {
		return Get-Date -Date $dtLocalDateTime -Format G
	}
}

Function msrdValidatingDateTime ($dateTimeToValidate) {

	if([String]::IsNullOrEmpty($dateTimeToValidate)) { return $false }

	$ConvertedDateTime = Get-Date -Date $dateTimeToValidate

	if($null -ne $ConvertedDateTime) {
		if(((Get-Date) - $ConvertedDateTime).Days -le $NumberOfDays) { return $true }
	}

	return $false
}

Function msrdGetOSSKU ($SKU) {

	switch ($SKU) {
		0  {return ""}
		1  {return "Ultimate Edition"}
		2  {return "Home Basic Edition"}
		3  {return "Home Basic Premium Edition"}
		4  {return "Enterprise Edition"}
		5  {return "Home Basic N Edition"}
		6  {return "Business Edition"}
		7  {return "Standard Server Edition"}
		8  {return "Datacenter Server Edition"}
		9  {return "Small Business Server Edition"}
		10 {return "Enterprise Server Edition"}
		11 {return "Starter Edition"}
		12 {return "Datacenter Server Core Edition"}
		13 {return "Standard Server Core Edition"}
		14 {return "Enterprise Server Core Edition"}
		15 {return "Enterprise Server Edition for Itanium-Based Systems"}
		16 {return "Business N Edition"}
		17 {return "Web Server Edition"}
		18 {return "Cluster Server Edition"}
		19 {return "Home Server Edition"}
		20 {return "Storage Express Server Edition"}
		21 {return "Storage Standard Server Edition"}
		22 {return "Storage Workgroup Server Edition"}
		23 {return "Storage Enterprise Server Edition"}
		24 {return "Server For Small Business Edition"}
		25 {return "Small Business Server Premium Edition"}
		175 {return "Enterprise for Virtual Desktops Edition"}
	}
}

Function msrdGetOS() {

	$WMIOS = Get-WmiObject -Class Win32_OperatingSystem
	$StringOS = $WMIOS.Caption

	if($null -ne $WMIOS.CSDVersion) {
		$StringOS += " - " + $WMIOS.CSDVersion
	}

	if(($null -ne $WMIOS.OperatingSystemSKU) -and ($WMIOS.OperatingSystemSKU.ToString().Length -gt 0)) {
		$StringOS += " ("+(msrdGetOSSKU $WMIOS.OperatingSystemSKU)+")"
	}

	return $StringOS
}

# Query SID of an object using WMI and return the account name
Function msrdConvertSIDToUser([string]$strSID)  {

	if([string]::IsNullOrEmpty($strSID)) { return }

	if($strSID.StartsWith("S-1-5")) {
		$UserSIDIdentifier = New-Object System.Security.Principal.SecurityIdentifier `
    	($strSID)
		$UserNTAccount = $UserSIDIdentifier.Translate( [System.Security.Principal.NTAccount])
		if($UserNTAccount.Value.Length -gt 0) {
			return $UserNTAccount.Value
		} else {
			return $strSID
		}
	}
	return $strSID
}

Function msrdConvertToHex([int]$number) {
	return ("0x{0:x8}" -f $number)
}

Function msrdGetUpdateOperation($Operation) {

	switch ($Operation) {
		1 { return "Install" }
		2 { return "Uninstall" }
		Default { return "Unknown("+$Operation+")" }
	}
}

Function msrdGetUpdateResult($ResultCode) {

	switch ($ResultCode) {
		0 { return "Not started" }
		1 { return "In progress" }
		2 { return "Completed successfully" }
		3 { return "Completed with errors" }
		4 { return "Failed to complete" }
		5 { return "Operation was aborted" }
		Default { return "Unknown("+$ResultCode+")" }
	}
}

Function msrdGetWUErrorCodes($HResult) {

	if ($null -eq $Script:WUErrors) {

		$WUErrorsFilePath = "$global:msrdScriptpath\Config\MSRDC-WU.xml"

		if(Test-Path -Path $WUErrorsFilePath) {
			[xml] $Script:WUErrors = Get-Content $WUErrorsFilePath
		} else {
			"[Error]: Did not find the Config\MSRDC-WU.xml file, cannot load all WU error code information" | Out-File -Append ($global:msrdErrorLogFile)
		}
	}

	$WUErrorNode = $Script:WUErrors.ErrV1.err | Where-Object {$_.n -eq $HResult}

	if ($null -ne $WUErrorNode) {
		$WUErrorCode = @()
		$WUErrorCode += $WUErrorNode.name
		$WUErrorCode += $WUErrorNode."#text"
		return $WUErrorCode
	}
	return $null
}


# Start here
Function msrdRunUEX_MSRDWU {

	msrdLogMessage $LogLevel.Normal -LogPrefix $msrdLogPrefix -Message "Exporting Windows Update history"

	msrdCreateLogFolder $global:msrdSysInfoLogFolder

	$global:msrdGetos = msrdGetOS

	msrdHtmlInit $WUFile
	msrdHtmlHeader -htmloutfile $WUFile -title "Update History : $($env:computername)" -fontsize "11px"
    msrdHtmlBodyWU -htmloutfile $WUFile -title "Update History for $global:msrdFQDN"

	# Get updates from the com object
	Try {
		$Session = New-Object -ComObject Microsoft.Update.Session
		$Searcher = $Session.CreateUpdateSearcher()
		$HistoryCount = $Searcher.GetTotalHistoryCount()
	} Catch {
        msrdLogMessage $LogLevel.Error ("Error collecting updates information from Microsoft.Update.Session" + $_.Exception.Message)
		$HistoryCount = 0
    }

	if ($HistoryCount -gt 0) {
		$ComUpdateHistory = $Searcher.QueryHistory(1,$HistoryCount)
	} else {
		$ComUpdateHistory = @()
		"`nNo updates found on Microsoft.Update.Session`n" | Out-File -Append $global:msrdOutputLogFile
	}

	# Get updates from the Wmi object Win32_QuickFixEngineering
	$QFEHotFixList = New-Object "System.Collections.ArrayList"
	$QFEHotFixList.AddRange(@(Get-WmiObject -Class Win32_QuickFixEngineering))

	# Get updates from the regsitry keys
	$RegistryHotFixList = msrdGetHotFixFromRegistry

	# Format each update history to the stringbuilder
	foreach($updateEntry in $ComUpdateHistory) {

		# Do not list the updates on which the $updateEntry.ServiceID = '117CAB2D-82B1-4B5A-A08C-4D62DBEE7782' or '855e8a7c-ecb4-4ca3-b045-1dfa50104289'. These are Windows Store updates and are bringing inconsistent results
		if (($updateEntry.ServiceID -ne '117CAB2D-82B1-4B5A-A08C-4D62DBEE7782') -and ($updateEntry.ServiceID -ne '855e8a7c-ecb4-4ca3-b045-1dfa50104289')) {

			$HotFixID = msrdGetHotFixID $updateEntry.Title
			$HotFixIDNumber = msrdToNumber $HotFixID
			$strInstalledBy = ""

			if(($HotFixID -ne "") -or ($HotFixIDNumber -ne "")) {
				foreach($QFEHotFix in $QFEHotFixList) {
					if(($QFEHotFix.HotFixID -eq $HotFixID) -or ((msrdToNumber $QFEHotFix.HotFixID) -eq $HotFixIDNumber)) {
						$strInstalledBy = msrdConvertSIDToUser $QFEHotFix.InstalledBy

						#Remove the duplicate HotFix in the QFEHotFixList
						$QFEHotFixList.Remove($QFEHotFix)
						break
					}
				}
			}

			# Remove the duplicate HotFix in the RegistryHotFixList
			if ($RegistryHotFixList.Keys -contains $HotFixID) { $RegistryHotFixList.Remove($HotFixID) }

			$strCategory = ""
			if($updateEntry.Categories.Count -gt 0) { $strCategory = $updateEntry.Categories.Item(0).Name }

			if ([String]::IsNullOrEmpty($strCategory)) { $strCategory = "(None)" }

			$strOperation = msrdGetUpdateOperation $updateEntry.Operation
			$strDateTime = msrdFormatDateTime $updateEntry.Date
			$strResult = msrdGetUpdateResult $updateEntry.ResultCode

			msrdPrintUpdate -Category $strCategory -ID $HotFixID -Operation $strOperation -Date $strDateTime -ClientID $updateEntry.ClientApplicationID -InstalledBy $strInstalledBy -OperationResult $strResult -Title $updateEntry.Title -Description $updateEntry.Description -HResult $updateEntry.HResult -UnmappedResultCode $updateEntry.UnmappedResultCode
		}
	}

	Add-Content $WUFile "</table></div></details>
	<details open>
		<summary>
			<a name='QFE'></a><b>Other - QFE</b><span class='b2top'><a href='#'>^top</a></span>
		</summary>
		<div class='detailsP'>
			<table class='tduo'>
				<tr style='text-align: left;'>
					<th width='10px'><div class='circle_no'></div></th><th style='padding-left: 5px;'>Category</th><th>Date/Time</th><th>Operation</th><th>Result</th><th>KB</th><th>Description</th>
				</tr>"
	# Output the Non History QFEFixes
	foreach($QFEHotFix in $QFEHotFixList) {
		$strInstalledBy = msrdConvertSIDToUser $QFEHotFix.InstalledBy
		$strDateTime = msrdFormatDateTime $QFEHotFix.InstalledOn
		$strCategory = ""

		# Remove the duplicate HotFix in the RegistryHotFixList
		if($RegistryHotFixList.Keys -contains $QFEHotFix.HotFixID) {
			$strCategory = $RegistryHotFixList[$QFEHotFix.HotFixID].Category
			$strRegistryDateTime = msrdFormatDateTime $RegistryHotFixList[$QFEHotFix.HotFixID].InstalledDate

			if ([String]::IsNullOrEmpty($strInstalledBy)) {
				$strInstalledBy = $RegistryHotFixList[$QFEHotFix.HotFixID].InstalledBy
			}

			$RegistryHotFixList.Remove($QFEHotFix.HotFixID)
		}

		if ([string]::IsNullOrEmpty($strCategory)) {
			$strCategory = "QFE hotfix"
		}

		if ($strDateTime.Length -eq 0) {
			$strDateTime = $strRegistryDateTime
		}

		if ([string]::IsNullOrEmpty($QFEHotFix.Status)) {
			$strResult = "Completed successfully"
		} else {
			$strResult = $QFEHotFix.Status
		}

		msrdPrintUpdate -Category $strCategory -ID $QFEHotFix.HotFixID -Operation "Install" -Date $strDateTime -ClientID "" -InstalledBy $strInstalledBy -OperationResult $strResult -Title $QFEHotFix.Description -Description $QFEHotFix.Caption
	}

	Add-Content $WUFile "</table></div></details>
	<details open>
		<summary>
			<a name='REG'></a><b>Other - Registry</b><span class='b2top'><a href='#'>^top</a></span>
		</summary>
		<div class='detailsP'>
			<table class='tduo'>
				<tr style='text-align: left;'>
					<th width='10px'><div class='circle_no'></div></th><th style='padding-left: 5px;'>Category</th><th>Date/Time</th><th>Operation</th><th>Result</th><th>KB</th><th>Description</th>
				</tr>"
	# Generating information for updates found on registry
	foreach ($key in $RegistryHotFixList.Keys) {
		$strCategory = $RegistryHotFixList[$key].Category
		$HotFixID = $RegistryHotFixList[$key].HotFixID
		$strDateTime = $RegistryHotFixList[$key].InstalledDate
		$strInstalledBy = $RegistryHotFixList[$key].InstalledBy
		$ClientID = $RegistryHotFixList[$key].InstallerName

		if ($HotFixID.StartsWith("Q")) {
			$Description = $RegistryHotFixList[$key].Description
		} else {
			$Description = $RegistryHotFixList[$key].PackageName
		}

		if ([string]::IsNullOrEmpty($Description)) {
			$Description = $strCategory
		}

		msrdPrintUpdate -Category $strCategory -ID $HotFixID -Operation "Install" -Date $strDateTime -ClientID $ClientID -InstalledBy $strInstalledBy -OperationResult "Completed successfully" -Title $strCategory -Description $Description
	}

	# Creating output files
	msrdHtmlEnd $WUFile

	$Session = $null
}

Export-ModuleMember -Function msrdRunUEX_MSRDWU
# SIG # Begin signature block
# MIInvwYJKoZIhvcNAQcCoIInsDCCJ6wCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBAnlh30Kd3qltx
# iCMD2HvzcFb3e/5H7D/clH1KtrzmB6CCDXYwggX0MIID3KADAgECAhMzAAADrzBA
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
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIEreb+SN/PEstR7OuxZl/+F6
# QZfr2dnfdJ8mMLhO69WfMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAo+w1qqfG2s0HJpKXdyqaldyfcEJHsev3g8+TjAYfSmcRcGoA4tirEAGV
# 4A77RCtPAgvqOYbTJej8ipmVS3xEMU8MsollYqWaGOoarSySM0Yswfg3Oi+1o+N8
# cYJfMhJrIWIfruc2FWkK0h0K9I92wlD1lL1OVzWa/FuuugTdZaPENKoEEdlV3oWS
# 485ge4y6MW8xVkWAAfTFVyGyX/H1fy3eFlNHrodzvV/JpahUsUOjsJFRgNeDPQB2
# zD5thSICkiPd2wBRUESZKgT4/DUS31lgYwXElayUViAK3lmswk7PhUET1DINvnSz
# zOrpysZvfZ72KG8nZwFEGcql3c6esaGCFykwghclBgorBgEEAYI3AwMBMYIXFTCC
# FxEGCSqGSIb3DQEHAqCCFwIwghb+AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsq
# hkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCAoUh1ZiB4LT2rPPUsS+Bl0Ov1oP+RNknG4Aro58fm0wAIGZbqiEEIn
# GBMyMDI0MDIyMDEyMTY1OS44NjZaMASAAgH0oIHYpIHVMIHSMQswCQYDVQQGEwJV
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
# IgQgu9wdh8Sfy3YZInUsWQDEdSy6iaJ3Mtj+3SRrGLMytMswgfoGCyqGSIb3DQEJ
# EAIvMYHqMIHnMIHkMIG9BCBh/w4tmmWsT3iZnHtH0Vk37UCN02lRxY+RiON6wDFj
# ZjCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB3V1X
# HZXUraobAAEAAAHdMCIEIA/x5yFjDf2ETKAA2doWpZHnl3XsOqD31cwMfKv1rNPZ
# MA0GCSqGSIb3DQEBCwUABIICAJM7RdKM3zEaXovE3DZTGTlaWP6y9LzruLDkI3UN
# P2OANZ16WyF+oSL3rg+tKhlruLQSEUU8evhKdMgFyJe+JsMsoHyYIrR0FrQMvA55
# Bvx/9W66aXDJlHotkuayX+6MrOcmNlngRih+gHkkI9+UJeUMruciT2vi2VLsYtzg
# ipQswjTNGMBLV+WGME/boElHwSpXUpXhNsF80KexiHDaQHtixNCMlXhTqVe2Elru
# flY4F3vnUfADgWHpzwXtbz2AJGO6QQCJuZIHWyi7fw4n8GBb5nDnsbukkMu3vaj8
# noqOnfNLAfj5hVLn/i5pCW3umMKkeWNA6BrHaOm4GlQ7+LTPo6gagKv80gWE+MSF
# 56I8zF5Sm3UiTs26SbFOucYbpgQOMxHwuM7JGNk9mxgYpStsLPzfoUWQMk+fqKaT
# SkoyhTXJZ74GUcHUcXe5Y7V12KsBfjYVqp6E9dWb6jYaVpSOIGqloTHF8aNJ0PnF
# SAxfJ7kV/GvRoyciamPbKbSZ58MQXAo0g1ETDrlvk9B81ihXldy0uRp/pPfFdQc3
# jgsTFIBUzKkIYYz4vZd1qPJIhe+uk+Ydwlmh5v//QY35UtvhJGnCi+RtRD1Oelj6
# XrFDqOCVMr1EdefaLID1ml6XniDhnujnd0NFA744SndNF/Ke4tQu6eOmWexc5q8H
# ZD7O
# SIG # End signature block
