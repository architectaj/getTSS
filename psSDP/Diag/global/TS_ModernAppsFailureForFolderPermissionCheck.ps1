﻿#************************************************
# TS_ModernAppsFailureForFolderPermissionCheck.ps1
# Version 1.0.1
# Date: 3/13/2013
# Author: v-kaw
# Description:  [Idea ID 7512] [Windows] WinStore - Apps fail to start if default file permissions modified
# Rule number:  7512
# Rule URL:  http://sharepoint/sites/rules/Rule Submissions/Forms/DispForm.aspx?ID=7512
#************************************************

Import-LocalizedData -BindingVariable ScriptStrings
Display-DefaultActivity -Rule -RuleNumber 7512

$RuleApplicable = $false
$RootCauseDetected = $false
$RootCauseName = "RC_ModernAppsFailureForFolderPermissionCheck"

# ***************************
# Data Gathering
# ***************************
Function AppliesToSystem
{
	#Windows 8
	return ($OSVersion.Major -eq 6) -and ($OSVersion.Minor -eq 2)
}

# **************
# Detection Logic
# **************

Function GetMissingPermission($requiredPermissions, $actualPermissions)
{
	$missingPermission = @()
	foreach($requiredPermission in $requiredPermissions) {
		$find = $false
		foreach($actualPermission in $actualPermissions) {
			if(($requiredPermission -band $actualPermission) -eq $requiredPermission) {	#find required permission
				$find = $true
				break
			}
		}
		if($find -eq $false) {
			$missingPermission += $requiredPermission
		}
	}
	return $missingPermission
}

# FileSystemRights is bit type enum
# This function will list current permission and all permission included indirectly
# For example: 
#   If current permission is ReadAndExecute
#	This function will list: ReadData, ReadExtendedAttributes, ExecuteFile, ReadAttributes, ReadPermissions, Read, ReadAndExecute

Function GetCurrentPermissionStrings($actualPermissions)
{
	if(($null -eq $actualPermissions) -or ($actualPermissions.Count -eq 0))
	{
		return "No permissions"
	}
	else
	{
		$permissions = [System.Security.AccessControl.FileSystemRights] $actualPermissions
		return GetPermissionStrings $permissions
	}
}

Function GetPermissionStrings($permissions)
{
	$result = ""
	if($null -ne $permissions) {
		$result = [string]::Join(', ', ($permissions | ForEach-Object {$_.ToString()} | Sort-Object -Unique))
	}
	return $result
}

Function CheckAllAppPackagesPermissionsonFileSystem()
{
	$identity = "APPLICATION PACKAGE AUTHORITY\ALL APPLICATION PACKAGES"
	$PermissionsForWindowsAndProgramFolder = @([System.Security.AccessControl.FileSystemRights]::ReadAndExecute,[System.Security.AccessControl.FileSystemRights]::Synchronize)
	$PermissionsForWerFolder = @([System.Security.AccessControl.FileSystemRights]::AppendData,[System.Security.AccessControl.FileSystemRights]::ReadData,[System.Security.AccessControl.FileSystemRights]::Synchronize)
	$FoldersAndPermissions = @{$Env:ProgramFiles = $PermissionsForWindowsAndProgramFolder;$Env:windir = $PermissionsForWindowsAndProgramFolder;"$Env:APPDATA\..\Local\Microsoft\Windows\WER" = $PermissionsForWerFolder}
	$MissingPermissionForAnyFolder = $false
	
	Foreach($folder in $FoldersAndPermissions.Keys) {
		if(Test-Path -Path $folder) {                 
			$requiredPermissions = $FoldersAndPermissions[$folder]
			$folderAccess = (get-acl -path $folder).Access | Where-Object {$_.IdentityReference.value -eq $identity}
			# $actualPermissions = $folderAccess.FileSystemRights
			$actualPermissions = @()
			if($null -ne $folderAccess) {
				$folderAccess | ForEach-Object { $actualPermissions += $_.FileSystemRights }
			}
			$missingPermissions = GetMissingPermission -requiredPermissions $requiredPermissions -actualPermissions $actualPermissions

			if($missingPermissions.Count -gt 0) {                                               
				$MissingPermissionForAnyFolder = $true
				$actualPermissionStrings = GetCurrentPermissionStrings $actualPermissions
				$requiredPermissionStrings = GetPermissionStrings $requiredPermissions
				$missingPermissionStrings = GetPermissionStrings $missingPermissions
						   
				$InformationCollected = New-Object PSObject
				Add-Member -InputObject $InformationCollected -MemberType NoteProperty -Name "Account" -Value $identity
				Add-Member -InputObject $InformationCollected -MemberType NoteProperty -Name "Folder missing permissions" -Value (Convert-Path $folder) 
				Add-Member -InputObject $InformationCollected -MemberType NoteProperty -Name "Current Permissions" -Value $actualPermissionStrings   
				Add-Member -InputObject $InformationCollected -MemberType NoteProperty -Name "Expected Permissions" -Value $requiredPermissionStrings  
				Add-Member -InputObject $InformationCollected -MemberType NoteProperty -Name "Missing permissions" -Value $missingPermissionStrings
				Add-GenericMessage -Id $RootCauseName -InformationCollected $InformationCollected 
			}
		}
	}
	return $MissingPermissionForAnyFolder
}

#Check to see if rule is applicable to this computer
if (AppliesToSystem)
{
       $RuleApplicable = $true
              
       if (CheckAllAppPackagesPermissionsonFileSystem)
       {
              $RootCauseDetected = $true 
       }
}      

# *********************
# Root Cause processing
# *********************

if ($RuleApplicable)
{
       if ($RootCauseDetected)
       {
              # Red/ Yellow Light
              Update-DiagRootCause -id $RootCauseName -Detected $true
       }
       else
       {
              # Green Light
              Update-DiagRootCause -id $RootCauseName -Detected $false
       }
}


# SIG # Begin signature block
# MIInlQYJKoZIhvcNAQcCoIInhjCCJ4ICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCMTyWEesXxeukV
# EcWR8xKm81FH1UcAsN3RyWggqGDJPqCCDXYwggX0MIID3KADAgECAhMzAAACy7d1
# OfsCcUI2AAAAAALLMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjIwNTEyMjA0NTU5WhcNMjMwNTExMjA0NTU5WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQC3sN0WcdGpGXPZIb5iNfFB0xZ8rnJvYnxD6Uf2BHXglpbTEfoe+mO//oLWkRxA
# wppditsSVOD0oglKbtnh9Wp2DARLcxbGaW4YanOWSB1LyLRpHnnQ5POlh2U5trg4
# 3gQjvlNZlQB3lL+zrPtbNvMA7E0Wkmo+Z6YFnsf7aek+KGzaGboAeFO4uKZjQXY5
# RmMzE70Bwaz7hvA05jDURdRKH0i/1yK96TDuP7JyRFLOvA3UXNWz00R9w7ppMDcN
# lXtrmbPigv3xE9FfpfmJRtiOZQKd73K72Wujmj6/Su3+DBTpOq7NgdntW2lJfX3X
# a6oe4F9Pk9xRhkwHsk7Ju9E/AgMBAAGjggFzMIIBbzAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUrg/nt/gj+BBLd1jZWYhok7v5/w4w
# RQYDVR0RBD4wPKQ6MDgxHjAcBgNVBAsTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEW
# MBQGA1UEBRMNMjMwMDEyKzQ3MDUyODAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzci
# tW2oynUClTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEG
# CCsGAQUFBwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0
# MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAJL5t6pVjIRlQ8j4dAFJ
# ZnMke3rRHeQDOPFxswM47HRvgQa2E1jea2aYiMk1WmdqWnYw1bal4IzRlSVf4czf
# zx2vjOIOiaGllW2ByHkfKApngOzJmAQ8F15xSHPRvNMmvpC3PFLvKMf3y5SyPJxh
# 922TTq0q5epJv1SgZDWlUlHL/Ex1nX8kzBRhHvc6D6F5la+oAO4A3o/ZC05OOgm4
# EJxZP9MqUi5iid2dw4Jg/HvtDpCcLj1GLIhCDaebKegajCJlMhhxnDXrGFLJfX8j
# 7k7LUvrZDsQniJZ3D66K+3SZTLhvwK7dMGVFuUUJUfDifrlCTjKG9mxsPDllfyck
# 4zGnRZv8Jw9RgE1zAghnU14L0vVUNOzi/4bE7wIsiRyIcCcVoXRneBA3n/frLXvd
# jDsbb2lpGu78+s1zbO5N0bhHWq4j5WMutrspBxEhqG2PSBjC5Ypi+jhtfu3+x76N
# mBvsyKuxx9+Hm/ALnlzKxr4KyMR3/z4IRMzA1QyppNk65Ui+jB14g+w4vole33M1
# pVqVckrmSebUkmjnCshCiH12IFgHZF7gRwE4YZrJ7QjxZeoZqHaKsQLRMp653beB
# fHfeva9zJPhBSdVcCW7x9q0c2HVPLJHX9YCUU714I+qtLpDGrdbZxD9mikPqL/To
# /1lDZ0ch8FtePhME7houuoPcMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkq
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
# /Xmfwb1tbWrJUnMTDXpQzTGCGXUwghlxAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAALLt3U5+wJxQjYAAAAAAsswDQYJYIZIAWUDBAIB
# BQCggbAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIODc8NBpbIc+D3JJatfq1ZRm
# beqLDyw+e7UNRKVk1yIhMEQGCisGAQQBgjcCAQwxNjA0oBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEcgBpodHRwczovL3d3dy5taWNyb3NvZnQuY29tIDANBgkqhkiG9w0B
# AQEFAASCAQBx1sajcMt4yDbba485ly919Pa5uH+sXI4ujdNnGu5MzBoHfitzBYlS
# sYL8WnkMpR2ehGYOmENKl9dzBU/iDVA5BtEidN/OL+gzBRREF370uVzJoBOVv1qU
# W8cY6M5ozQWkn9PhdipeNJbEr3XIEky9kSr6BmDIy+fFLMezojni4wOPjopdH7Z4
# gCx4Hao2mR7Dje1wrNDiB/fy00W2ExyczPY5yqW+nKN+dAlmWvbRp39YNEYuJmbX
# TwSNGs7OFxakWEZ6XP4pVZBMVw65I9g2XIHWMUbjf5EdrLtDFRd/EvEogBmQ1h1m
# /EWL+WRDlPLUsNfv2WCCuRNsPJbVg+FEoYIW/TCCFvkGCisGAQQBgjcDAwExghbp
# MIIW5QYJKoZIhvcNAQcCoIIW1jCCFtICAQMxDzANBglghkgBZQMEAgEFADCCAVEG
# CyqGSIb3DQEJEAEEoIIBQASCATwwggE4AgEBBgorBgEEAYRZCgMBMDEwDQYJYIZI
# AWUDBAIBBQAEIB/CIjlWFwacIN8a9m9mpmJMi8QNcGsPc/F5Rian1zvGAgZi1/U5
# XXAYEzIwMjIwODAxMDc0MjIyLjIwOFowBIACAfSggdCkgc0wgcoxCzAJBgNVBAYT
# AlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBB
# bWVyaWNhIE9wZXJhdGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOjIyNjQt
# RTMzRS03ODBDMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNl
# oIIRVDCCBwwwggT0oAMCAQICEzMAAAGYdrOMxdAFoQEAAQAAAZgwDQYJKoZIhvcN
# AQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMjExMjAyMTkw
# NTE1WhcNMjMwMjI4MTkwNTE1WjCByjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9u
# czEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046MjI2NC1FMzNFLTc4MEMxJTAjBgNV
# BAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQDG1JWsVksp8xG4sLMnfxfit3ShI+7G1MfTT+5XvQzu
# AOe8r5MRAFITTmjFxzoLFfmaxLvPVlmDgkDi0rqsOs9Al9jVwYSFVF/wWC2+B76O
# ysiyRjw+NPj5A4cmMhPqIdNkRLCE+wtuI/wCaq3/Lf4koDGudIcEYRgMqqToOOUI
# V4e7EdYb3k9rYPN7SslwsLFSp+Fvm/Qcy5KqfkmMX4S3oJx7HdiQhKbK1C6Zfib+
# 761bmrdPLT6eddlnywls7hCrIIuFtgUbUj6KJIZn1MbYY8hrAM59tvLpeGmFW3Gj
# eBAmvBxAn7o9Lp2nykT1w9I0s9ddwpFnjLT2PK74GDSsxFUZG1UtLypi/kZcg9We
# nPAZpUtPFfO5Mtif8Ja8jXXLIP6K+b5LiQV8oIxFSBfgFN7/TL2tSSfQVcvqX1mc
# SOrx/tsgq3L6YAxI6Pl4h1zQrcAmToypEoPYNc/RlSBk6ljmNyNDsX3gtK8p6c7H
# CWUhF+YjMgfanQmMjUYsbjdEsCyL6QAojZ0f6kteN4cV6obFwcUEviYygWbedaT8
# 6OGe9LEOxPuhzgFv2ZobVr0J8hl1FVdcZFbfFN/gdjHZ/ncDDqLNWgcoMoEhwwzo
# 7FAObqKaxfB5zCBqYSj45miNO5g3hP8AgC0eSCHl3rK7JPMr1B+8JTHtwRkSKz/+
# cwIDAQABo4IBNjCCATIwHQYDVR0OBBYEFG6RhHKNpsg3mgons7LR5YHTzeE3MB8G
# A1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCG
# Tmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUy
# MFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4w
# XAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwG
# A1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZIhvcNAQELBQAD
# ggIBACT6B6F33i/89zXTgqQ8L6CYMHx9BiaHOV+wk53JOriCzeaLjYgRyssJhmnn
# J/CdHa5qjcSwvRptWpZJPVK5sxhOIjRBPgs/3+ER0vS87IA+aGbf7NF7LZZlxWPO
# l/yFBg9qZ3tpOGOohQInQn5zpV23hWopaN4c49jGJHLPAfy9u7+ZSGQuw14CsW/X
# RLELHT18I60W0uKOBa5Pm2ViohMovcbpNUCEERqIO9WPwzIwMRRw34/LgjuslHJo
# p+/1Ve/CfyNqweUmwepQHJrd+wTLUlgm4ENbXF6i52jFfYpESwLdAn56o/pj+grs
# d2LrAEPQRyh49rWvI/qZfOhtT2FWmzFw6IJvZ7CzT1O+Fc0gIDBNqass5QbmkOkK
# Yy9U7nFA6qn3ZZ+MrZMsJTj7gxAf0yMkVqwYWZRk4brY9q8JDPmcfNSjRrVfpYyz
# EVEqemGanmxvDDTzS2wkSBa3zcNwOgYhWBTmJdLgyiWJGeqyj1m5bwNgnOw6NzXC
# iVMzfbztdkqOdTR88LtAJGNRjevWjQd5XitGuegSp2mMJglFzRwkncQau1BJsCj/
# 1aDY4oMiO8conkmaWBrYe11QCS896/sZwSdnEUJak0qpnBRFB+THRIxIivCKNbxG
# 2QRZ8dh95cOXgo0YvBN5a1p+iJ3vNwzneU2AIC7z3rrIbN2fMIIHcTCCBVmgAwIB
# AgITMwAAABXF52ueAptJmQAAAAAAFTANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0
# IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTAwHhcNMjEwOTMwMTgyMjI1
# WhcNMzAwOTMwMTgzMjI1WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOThpkzntHIhC3miy9ckeb0O
# 1YLT/e6cBwfSqWxOdcjKNVf2AX9sSuDivbk+F2Az/1xPx2b3lVNxWuJ+Slr+uDZn
# hUYjDLWNE893MsAQGOhgfWpSg0S3po5GawcU88V29YZQ3MFEyHFcUTE3oAo4bo3t
# 1w/YJlN8OWECesSq/XJprx2rrPY2vjUmZNqYO7oaezOtgFt+jBAcnVL+tuhiJdxq
# D89d9P6OU8/W7IVWTe/dvI2k45GPsjksUZzpcGkNyjYtcI4xyDUoveO0hyTD4MmP
# frVUj9z6BVWYbWg7mka97aSueik3rMvrg0XnRm7KMtXAhjBcTyziYrLNueKNiOSW
# rAFKu75xqRdbZ2De+JKRHh09/SDPc31BmkZ1zcRfNN0Sidb9pSB9fvzZnkXftnIv
# 231fgLrbqn427DZM9ituqBJR6L8FA6PRc6ZNN3SUHDSCD/AQ8rdHGO2n6Jl8P0zb
# r17C89XYcz1DTsEzOUyOArxCaC4Q6oRRRuLRvWoYWmEBc8pnol7XKHYC4jMYcten
# IPDC+hIK12NvDMk2ZItboKaDIV1fMHSRlJTYuVD5C4lh8zYGNRiER9vcG9H9stQc
# xWv2XFJRXRLbJbqvUAV6bMURHXLvjflSxIUXk8A8FdsaN8cIFRg/eKtFtvUeh17a
# j54WcmnGrnu3tz5q4i6tAgMBAAGjggHdMIIB2TASBgkrBgEEAYI3FQEEBQIDAQAB
# MCMGCSsGAQQBgjcVAgQWBBQqp1L+ZMSavoKRPEY1Kc8Q/y8E7jAdBgNVHQ4EFgQU
# n6cVXQBeYl2D9OXSZacbUzUZ6XIwXAYDVR0gBFUwUzBRBgwrBgEEAYI3TIN9AQEw
# QTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9E
# b2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBkGCSsGAQQB
# gjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/
# MB8GA1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJ
# oEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01p
# Y1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYB
# BQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9v
# Q2VyQXV0XzIwMTAtMDYtMjMuY3J0MA0GCSqGSIb3DQEBCwUAA4ICAQCdVX38Kq3h
# LB9nATEkW+Geckv8qW/qXBS2Pk5HZHixBpOXPTEztTnXwnE2P9pkbHzQdTltuw8x
# 5MKP+2zRoZQYIu7pZmc6U03dmLq2HnjYNi6cqYJWAAOwBb6J6Gngugnue99qb74p
# y27YP0h1AdkY3m2CDPVtI1TkeFN1JFe53Z/zjj3G82jfZfakVqr3lbYoVSfQJL1A
# oL8ZthISEV09J+BAljis9/kpicO8F7BUhUKz/AyeixmJ5/ALaoHCgRlCGVJ1ijbC
# HcNhcy4sa3tuPywJeBTpkbKpW99Jo3QMvOyRgNI95ko+ZjtPu4b6MhrZlvSP9pEB
# 9s7GdP32THJvEKt1MMU0sHrYUP4KWN1APMdUbZ1jdEgssU5HLcEUBHG/ZPkkvnNt
# yo4JvbMBV0lUZNlz138eW0QBjloZkWsNn6Qo3GcZKCS6OEuabvshVGtqRRFHqfG3
# rsjoiV5PndLQTHa1V1QJsWkBRH58oWFsc/4Ku+xBZj1p/cvBQUl+fpO+y/g75LcV
# v7TOPqUxUYS8vwLBgqJ7Fx0ViY1w/ue10CgaiQuPNtq6TPmb/wrpNPgkNWcr4A24
# 5oyZ1uEi6vAnQj0llOZ0dFtq0Z4+7X6gMTN9vMvpe784cETRkPHIqzqKOghif9lw
# Y1NNje6CbaUFEMFxBmoQtB1VM1izoXBm8qGCAsswggI0AgEBMIH4oYHQpIHNMIHK
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxN
# aWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMgVFNT
# IEVTTjoyMjY0LUUzM0UtNzgwQzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3Rh
# bXAgU2VydmljZaIjCgEBMAcGBSsOAwIaAxUA8ywe/iF5M8fIU2aT6yQ3vnPpV5Og
# gYMwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYw
# JAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0B
# AQUFAAIFAOaRnKMwIhgPMjAyMjA4MDEwODI4MTlaGA8yMDIyMDgwMjA4MjgxOVow
# dDA6BgorBgEEAYRZCgQBMSwwKjAKAgUA5pGcowIBADAHAgEAAgISNDAHAgEAAgIR
# qTAKAgUA5pLuIwIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAow
# CAIBAAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBAGW0b6G1nxJf
# Sz+162eIfZKEeCT5UlfEbylGeWHEIa2FOqerhClam6wPRPAJD+i5gmNDLWEXoJhE
# 9mfD/DNtILqESrGPO8DLhy1fGnzIFrHCh+Hmog+1BobdtTTDsZ63lI6Mp6+O44xP
# gtveVE5cjYmTGOZttcbmk0FXsnRiWdbDMYIEDTCCBAkCAQEwgZMwfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAGYdrOMxdAFoQEAAQAAAZgwDQYJYIZI
# AWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG
# 9w0BCQQxIgQgmHvIMcPQ0Ca/STrUHPKx6bfOHn3L7TPkg3dq0jTjfNUwgfoGCyqG
# SIb3DQEJEAIvMYHqMIHnMIHkMIG9BCC/ps4GOTn/9wO1NhHM9Qfe0loB3slkw1FF
# 3r+bh21WxDCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMz
# AAABmHazjMXQBaEBAAEAAAGYMCIEIITB9XHZkmFVJEo8WDGAMhrrxCbnPT0sQRQc
# 2rAtWwOFMA0GCSqGSIb3DQEBCwUABIICAE7zWvBMy9R2DqIbKCeB/a50fXWt2ef5
# sYdgPr8nXEwMa36w+/jNJA+OZYP+zgFktHQRR2zBEI6DG84WWnnqc49VIAZLQRwz
# lqJNaoLkXXi0gSpuYDaQb/l5kTbMT5+D7oo9LhNAf5Bek7pb9M7mjrRwHYkET60R
# 3nS9BuEb+Pt394S4F3dQy1aSFbx7yVxMCT/5WA9Y5sWgsKAtRaJBlwfGDCuqhY20
# jDIiRRYYMfWhTNw57BvSS44/aO9XsLhq7rqqOjdpcI902nJ7/8zUXWhMn08IqmoY
# A4iObWlFjHT+OW8EPl9P96qphpztHQd72IPM7gyuzcIkiBBtllV8z/JGJs4wxalU
# zjyycmzx8ZXrVCiCYdevf9U+gf1KZjTTlI4AEMUblUmavOO5Qx28e2zs8UosZ/di
# TALQq6cqWygvbxLibHH0alNfjPZSAUUKnyd8a8ObPdPP91yFxyL88QgURxCJtXGc
# Ue8CER9AoPsIDX/P6yPvSOWs/cQwVBdlJMJFz8jm/77mjTtjJEUW2r1P/T3svgRy
# TgLtLVC8Y3c96DtcWIbPT0XuCflNr0L0kiu2eua5fuPPmdNVxEzQJWQIO92wm1cj
# Zdrh0fBkR8l4FjAAuXIbEZ5y6yFNmKPRnNZCzb2sVwIg/EE6KPVlb7ffPlpe0dQj
# tg/FhIgM5Acs
# SIG # End signature block