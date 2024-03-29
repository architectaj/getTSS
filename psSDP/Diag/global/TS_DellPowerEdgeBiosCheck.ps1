#************************************************
# TS_DellPowerEdgeBiosCheck.ps1
# Version 1.0.1
# Date: 5/9/2012
# Author: v-alyao
# Description:  [Idea ID 2842] [Windows] Alert Engineers if they are working on a Dell machine models R910, R810 and M910
# Rule number:  2842
# Rule URL:  //sharepoint/sites/rules/Rule%20Submissions/Forms/DispForm.aspx?ID=2842
#************************************************
Import-LocalizedData -BindingVariable ScriptStrings
Display-DefaultActivity -Rule -RuleNumber 2842
$RuleApplicable = $false
$RootCauseDetected = $false
$RootCauseName = "RC_DellPowerEdgeBiosCheck"
$PublicContent = ""
$InternalContent = "https://sharepoint.partners.extranet.microsoft.com/sites/Onestop/CTSSQL/Pages/sql%20corruption%20dell%20machines%20scribble%20pattern%207f87312b.aspx"
$Verbosity = "Error"
$Visibility = "3"
$SupportTopicsID = "8121"
$InformationCollected = new-object PSObject

# **************
# Detection Logic
# **************
#Check to see if rule is applicable to this computer
if((($OSVersion.Major -eq 5) -and ($OSVersion.Minor -eq 2)) -or #Server 2003
			   (($OSVersion.Major -eq 6) -and ($OSVersion.Minor -eq 0)) -or # Server 2008
			   (($OSVersion.Major -eq 6) -and ($OSVersion.Minor -eq 1))) #Win 7/Server 2008 R2
{	
	$manufacturer="Dell Inc."
	$systemModelList=@("PowerEdge R910","PowerEdge R810","PowerEdge M910")
	$computerInfo=Get-CimInstance -Namespace root\CIMV2 -Class Win32_ComputerSystem
	if(($null -ne $computerInfo) -and 
	(($null -ne $computerInfo.Manufacturer) -and ($computerInfo.Manufacturer -eq $manufacturer)) -and
	($systemModelList -contains $computerInfo.Model))
	{
		$RuleApplicable=$true
	}
}

#Check the Bios version,
#If the BIOS Version is 2.2.3 return true
#else return false
Function CheckBIOSVersion()
{
	$redBIOS='2.2.3'
	$biosInfo=Get-CimInstance -Namespace root\CIMV2 -Class Win32_BIOS
	if(($null -ne $biosInfo) -and ($null -ne $biosInfo.BIOSVersion) -and ($biosInfo.BIOSVersion.count -ge 1)) {
		$biosVersion=$biosInfo.BIOSVersion[0];
	}
	if(($null -ne $biosInfo) -and ($null -eq $biosVersion)) {
		$biosVersion = $biosInfo.SMBIOSBIOSVersion
	}
	if(($null -ne $biosVersion) -and ($biosVersion.Contains($redBIOS)))
	{
		add-member -inputobject $InformationCollected -membertype noteproperty -name "System Manufacturer" -value $computerInfo.Manufacturer
		add-member -inputobject $InformationCollected -membertype noteproperty -name "System Model" -value $computerInfo.Model
		add-member -inputobject $InformationCollected -membertype noteproperty -name "BIOS Version" -value $biosVersion
		add-member -inputobject $InformationCollected -membertype noteproperty -name "SMBIOS Version" -value ($biosInfo.SMBIOSMajorVersion.ToString()+'.'+$biosInfo.SMBIOSMinorVersion.ToString())
		return $true
	}
	return $false
}
	
# *********************
# Root Cause processing
# *********************
if ($RuleApplicable)
{
	$RootCauseDetected=CheckBIOSVersion
	if ($RootCauseDetected)
	{
		# Red/ Yellow Light
		Update-DiagRootCause -id $RootCauseName -Detected $true
		Write-GenericMessage -RootCauseId $RootCauseName -InternalContentURL $InternalContent -InformationCollected $InformationCollected -Verbosity $Verbosity -Visibility $Visibility -SupportTopicsID $SupportTopicsID -SolutionTitle $ScriptStrings.ID_DellPowerEdgeBiosCheck_SD
	}
	else
	{
		# Green Light
		Update-DiagRootCause -id $RootCauseName -Detected $false
	}
}


# SIG # Begin signature block
# MIInlwYJKoZIhvcNAQcCoIIniDCCJ4QCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB6D+fezdA2Qowl
# yejXbzEDt9CRUAbX+wdMZMBgktwuM6CCDXYwggX0MIID3KADAgECAhMzAAACy7d1
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
# /Xmfwb1tbWrJUnMTDXpQzTGCGXcwghlzAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAALLt3U5+wJxQjYAAAAAAsswDQYJYIZIAWUDBAIB
# BQCggbAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEILtjqBRvXRUR7pJPkmXMODTu
# 8Ketfjp492RiIPmD8rZ3MEQGCisGAQQBgjcCAQwxNjA0oBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEcgBpodHRwczovL3d3dy5taWNyb3NvZnQuY29tIDANBgkqhkiG9w0B
# AQEFAASCAQBkcoI7wvnVCnaokR94LB12JBd2/UmTgsggLEOdRKCX/nodNoiI03W3
# R+GoXJOoZe+GFeMyHkJnzpuX4qs2HIMz8QIPuWwrSMsN/5mqkDbB9LK3qbgJk6gM
# sjjN1w82mp+NjCL1ABHhpOo+WAEA2mxnisqKBU8kiVqyDjCMDM60DcXiNcUxY8VP
# 0L8Hkb3iLwT+exGu4UpCs7w7cKDdVsHlImITsNvXftGd8qDnTlpDdM5yVl34hh8R
# R91/EnHQYx3yT+nOaaLwLJhM2mQaWnYdDlX9IlvmG5efvt5CsfEgy/l/CzkIexoD
# 5FQvp4SWhugvyCamLPRCNrt3l9B0NPnRoYIW/zCCFvsGCisGAQQBgjcDAwExghbr
# MIIW5wYJKoZIhvcNAQcCoIIW2DCCFtQCAQMxDzANBglghkgBZQMEAgEFADCCAVAG
# CyqGSIb3DQEJEAEEoIIBPwSCATswggE3AgEBBgorBgEEAYRZCgMBMDEwDQYJYIZI
# AWUDBAIBBQAEID6d2yxqUYbA08BClnfUT9TnrTjeK7CD5QbNv7rxbW27AgZi0AB1
# OYgYEjIwMjIwODAxMDgwMDUwLjgyWjAEgAIB9KCB0KSBzTCByjELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFt
# ZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046M0JCRC1F
# MzM4LUU5QTExJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wg
# ghFXMIIHDDCCBPSgAwIBAgITMwAAAZ3+ieX5e7tMwAABAAABnTANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yMTEyMDIxOTA1
# MTlaFw0yMzAyMjgxOTA1MTlaMIHKMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25z
# MSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjozQkJELUUzMzgtRTlBMTElMCMGA1UE
# AxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBAOARaHrQHEkW5H6aUW4UK0beZHZcc0J88xNdynTph7AC
# 1LVtsbMruEMLUlEx62FyaIoz95t0Jwbq/qTiVDIuVJoeYeQhQLmk0S2W63OmxU36
# Oj41t3K73DQEyHgrN924t3Ft1rVXO0oNJeMTd4SXk5/7mFjekeglf02H/mvi1zg2
# +q3229Vxh4jGlyFnzUArf5TOkD6FxHodLrtcDz5xBQHV8bJGhWHWwK7T6h91UNxY
# 4b+1xIq0lyH55EBUN7shGbzh8+w9MXPZ0glEkD89RplH7fFbgV3Vlss1r/Axure9
# pi0qiBpJmKILJTFTubCgDfaLJNwYcLuEfwyBlZU4QG7sJ828zKuxHxC6+7eb3UOq
# xzmBkczG+B4A70suJppT6SViYVZC8temKVLWINdv/zb5OPAa3ESdzzH8S8uSTtSS
# Pi4pnonzKeWA+E9Gp6NygqUewqDFaYPfDMRdbVrT13UvYijTTjDTWLfVAAwH8YuG
# CaYwgTlnhUjYmWH2xfaeTKHlA6dg7OcQKTjNr1wh0wo/6x17aeG+9xJ2sZdDx9Y7
# /43WaNPRIiRfjVdmOb5AwZHTe1rrel+yPeDcTlrWvSj1oeBy6mFbSXCtsED9MYyj
# nMLxnlYj5HCmvQwCINkbLmHb64zH/b78XhmLIpq4pep3usiXWx4BhBjEpDhJ6YHR
# AgMBAAGjggE2MIIBMjAdBgNVHQ4EFgQU1t8QjeEq6MycXhGB29rLitkbVeQwHwYD
# VR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYDVR0fBFgwVjBUoFKgUIZO
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIw
# VGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwGCCsGAQUFBwEBBGAwXjBc
# BggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0
# cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcnQwDAYD
# VR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDCDANBgkqhkiG9w0BAQsFAAOC
# AgEAhsdynEu3aHQs0nffiII1liy1rYRqe30lR6KnB5sUjBAyKPtIhDzeInhjg4vl
# jCWmnC8XnXoCFwd69gxJxjo0BdIAaGnnFi2QRyR5XqA1tyncLgjfKi1a8N30pAKH
# st0iGmJgJ17RIXg3klFlQdcgxzO82F7z50S6IKdLWxaIY9QXM0l+wBw2zVoGQci1
# pLEzQBUeBl+ArxHaKFWS2KvHBgbRP2jWHQGREnc9+4kX6c6O3X54VhiCr5s4tCz9
# J2BjgNtRV+u0t0SDZNtL6yJnDh2rMz60t3J7lcbImUoFftoizjF/UeHXKYxfbhgm
# Wby/Jf5bjHzLK0+bOI0e2yHF/uUp3U+bu37tRTOLxAGFvLS9it+uehbUrCz7Pfi6
# hzb4PZUXGsff3Gr/wpt54Gm4vn74KKmhlCx3lA7k2LzWcGXCL/vUmxkMSiayj+Tg
# mKjK9UAzbzXwKCew0mcxllLEzmTJ5F1iH0huMZ09109Vy/SQ8qs1qU+1E7iKHQZW
# Qv9rgF8QG1cN4RQiwzgDTRB6EP4RJXcjRRtb5vg1OZtFyOdUWTm3qe4r8WgVBzk3
# he55gA7DaYwOECgUT7bG1MeTZ7B33EaRsUOXZvq78VuGxRvn5eg/Q90ncVM0/ob/
# tWviwg7Fqvg+ljrvhpAKIxLLDC0hY6ipFL84/+tKMX0T/F8wggdxMIIFWaADAgEC
# AhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQg
# Um9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0yMTA5MzAxODIyMjVa
# Fw0zMDA5MzAxODMyMjVaMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA5OGmTOe0ciELeaLL1yR5vQ7V
# gtP97pwHB9KpbE51yMo1V/YBf2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64NmeF
# RiMMtY0Tz3cywBAY6GB9alKDRLemjkZrBxTzxXb1hlDcwUTIcVxRMTegCjhuje3X
# D9gmU3w5YQJ6xKr9cmmvHaus9ja+NSZk2pg7uhp7M62AW36MEBydUv626GIl3GoP
# z130/o5Tz9bshVZN7928jaTjkY+yOSxRnOlwaQ3KNi1wjjHINSi947SHJMPgyY9+
# tVSP3PoFVZhtaDuaRr3tpK56KTesy+uDRedGbsoy1cCGMFxPLOJiss254o2I5Jas
# AUq7vnGpF1tnYN74kpEeHT39IM9zfUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2ci/b
# fV+AutuqfjbsNkz2K26oElHovwUDo9Fzpk03dJQcNIIP8BDyt0cY7afomXw/TNuv
# XsLz1dhzPUNOwTM5TI4CvEJoLhDqhFFG4tG9ahhaYQFzymeiXtcodgLiMxhy16cg
# 8ML6EgrXY28MyTZki1ugpoMhXV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y1BzF
# a/ZcUlFdEtsluq9QBXpsxREdcu+N+VLEhReTwDwV2xo3xwgVGD94q0W29R6HXtqP
# nhZyacaue7e3PmriLq0CAwEAAaOCAd0wggHZMBIGCSsGAQQBgjcVAQQFAgMBAAEw
# IwYJKwYBBAGCNxUCBBYEFCqnUv5kxJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQWBBSf
# pxVdAF5iXYP05dJlpxtTNRnpcjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdMg30BATBB
# MD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0Rv
# Y3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYBBAGC
# NxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8w
# HwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmg
# R4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWlj
# Um9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEF
# BQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29D
# ZXJBdXRfMjAxMC0wNi0yMy5jcnQwDQYJKoZIhvcNAQELBQADggIBAJ1VffwqreEs
# H2cBMSRb4Z5yS/ypb+pcFLY+TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27DzHk
# wo/7bNGhlBgi7ulmZzpTTd2YurYeeNg2LpypglYAA7AFvonoaeC6Ce5732pvvinL
# btg/SHUB2RjebYIM9W0jVOR4U3UkV7ndn/OOPcbzaN9l9qRWqveVtihVJ9AkvUCg
# vxm2EhIRXT0n4ECWOKz3+SmJw7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWKNsId
# w2FzLixre24/LAl4FOmRsqlb30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2kQH2
# zsZ0/fZMcm8Qq3UwxTSwethQ/gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+c23K
# jgm9swFXSVRk2XPXfx5bRAGOWhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep8beu
# yOiJXk+d0tBMdrVXVAmxaQFEfnyhYWxz/gq77EFmPWn9y8FBSX5+k77L+DvktxW/
# tM4+pTFRhLy/AsGConsXHRWJjXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1ZyvgDbjm
# jJnW4SLq8CdCPSWU5nR0W2rRnj7tfqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/2XBj
# U02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYICzjCCAjcCAQEwgfihgdCkgc0wgcox
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBUU1Mg
# RVNOOjNCQkQtRTMzOC1FOUExMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQC36UNJFf3YoXKKPvUmfbQKhLLK4KCB
# gzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAk
# BgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEB
# BQUAAgUA5pGQsDAiGA8yMDIyMDgwMTA3MzcyMFoYDzIwMjIwODAyMDczNzIwWjB3
# MD0GCisGAQQBhFkKBAExLzAtMAoCBQDmkZCwAgEAMAoCAQACAiIUAgH/MAcCAQAC
# AhHDMAoCBQDmkuIwAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKg
# CjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQEFBQADgYEAbR+ULmje
# d9t441g3rZ5UWGhpA9GqeBv2MjmeZFwNuzZ/RCgMzVzH7x0WCO7sNs3oEhsnABx/
# wBEVRMoex0m6A9WC3QBK18r4mHbj7Q9afHJHKYhkCc39R+blJUIWpLn6wlR/i48F
# mICfHDhsRQI81fjiYqzWgzX9ukymW+SeGuIxggQNMIIECQIBATCBkzB8MQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3Nv
# ZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAZ3+ieX5e7tMwAABAAABnTANBglg
# hkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqG
# SIb3DQEJBDEiBCA0Ljw81k6p2c6G13x64GcLodlQfEvD3zRGvkJ1C1CFrjCB+gYL
# KoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIPUeY63giqBPgDSfgluVf9/MUvIS7g4E
# M5v6akyVh0WhMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAC
# EzMAAAGd/onl+Xu7TMAAAQAAAZ0wIgQg8LqThdytNFw57yMiGp5CVeiihbVyve/U
# Dalpio1VY10wDQYJKoZIhvcNAQELBQAEggIAUXgGWiBBQ/2Flhpz4VdVCPT+xtut
# MRTTcej2ZhngrenbIY2QMuTHjPU34BlbAPJkN7RohWa5gO4nO04wKZetlfDcpueq
# NzvKM+/g5wpdLiljaywe6uB//UCNmD2TSJJcv7uDJ0CLutioNgSM/Osxbx8BiRms
# 9xmNeAtse3F/ulJPgJT8ZkUF2Qo5HkzPsGLjW7sL0VecHGIz/ee+MdmaOF44Czfi
# lEe2juAZ6y5jBih486yGE07tV3E4VbKpNbydOaRnCJ6r6v0Y/D343r0/s38TfNKr
# Gi3C5/8b6L6H6uPRluR1DEfW4wncN1QovB/TMw0DH1c2o+yIDsl0Sbu/2hwcvZYm
# OA2wgb86VvVoLxHtjULvEwRErrDe8wc/mR+zAhbOUViXIMlfMhoz40abpCMbrHVC
# 9V3rR1FxEy93Qbp4MmIx5BNn0yIFRuLtGo5BJ1B+w2m6RQXR00nxRUeGyEP/LZli
# AvPsTGTQ0BFZBCCIyDpj0zuartDv0osAZu4XI/3qHj33FSh/WxMqvQFmC4oby3au
# E0RgxlBjESCmKfsEHve2l7JzKpx+SxcBw78AVx7cRKfIUcrKZF3GF+c2xMK3Pp8R
# 5dfdutK7GUymcuY24jV8INbURoWiIxL2N07NXFyFFdabQUHhaRiAE3tNVIe79cmX
# SdRFOCukL0XeDB0=
# SIG # End signature block
