﻿#************************************************
# Rule ID 29 from http://sharepoint/sites/diag/Rules/_layouts/listform.aspx?PageType=4&ListId=%7b1F944AAF-10B3-4442-8AA8-4A1EF2B0F5F8%7d&ID=29&ContentTypeID=0x0100969570CC59987E4BADAD7118A311DB4D
#************************************************
# TS_ClusterCNOCheck.ps1
# 2023-02-20 WalterE mod Trap #we#
trap [Exception]{
	WriteTo-StdOut "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $_" -shortformat; continue
	Write-Host "$($_.InvocationInfo.ScriptName)($($_.InvocationInfo.ScriptLineNumber)): $_"
}

Import-LocalizedData -BindingVariable ScriptVariable
Write-DiagProgress -Activity $ScriptVariable.ID_FailoverClusterCNO -Status $ScriptVariable.ID_FailoverClusterCNODesc
$RootCauseDetected = $false

# ***********
# Script Logic
# ***********
#Check if machine is a Failover Cluster Node, and if so, we determine the Cluster Name Object (CNO) computer object name
#

$RootCauseName = "RC_ClusterCNOCheck"

if (($OSVersion.Build -gt 6000) -and (Test-Path "HKLM:\Cluster")){
	"Cluster Detected" | WriteTo-StdOut -ShortFormat
	$CNODisabled = $false
	$CNODoesNotExist = $false
	$ACCOUNTDISABLE = 2 #http://support.microsoft.com/kb/305144
	$CNO = (Get-ItemProperty "HKLM:\Cluster").ClusterName
	#
	# If the machine is a node in a Failover Cluster, we check to see if the CNO is present in AD
	#
	"CNO: $CNO" | WriteTo-StdOut -ShortFormat
	If ($Null -ne $CNO)	{
		$Return_Object = new-object PSObject
		#		
		# First run a query against the local computer name to make sure this machine can connect to a DC and run queries to look for computer objects
		#
		$LocalComputerName = $Env:COMPUTERNAME
		$LDAPQueryResults = Run-LDAPSearch -Filter "(&(objectCategory=computer)(name=$LocalComputerName))"
		if ($null -ne $LDAPQueryResults){
			$LDAPQueryResults = Run-LDAPSearch -Filter "(&(objectCategory=computer)(name=$CNO))"
			#		
			# If the CNO is missing, we pop up these alert messages	
			#
			If ($Null -ne $LDAPQueryResults){
				$UserAccountControl = $Results.Properties.Item("UserAccountControl")[0]
				"UserAccountControl current value: $UserAccountControl" | WriteTo-StdOut -ShortFormat
				If (($UserAccountControl -bor $ACCOUNTDISABLE) -eq $UserAccountControl){
					$CNODisabled = $true
				}
			}else{
				$CNODoesNotExist = $true
			}
			"CNODoesNotExist: $CNODoesNotExist" | WriteTo-StdOut -ShortFormat
			"CNODisabled: $CNODisabled" | WriteTo-StdOut -ShortFormat
			if (($CNODoesNotExist) -or ($CNODisabled)){
				$RootCauseDetected = $true
				add-member -inputobject $Return_Object -membertype noteproperty -name "Cluster Name Object" -value $CNO
				add-member -inputobject $Return_Object -membertype noteproperty -name "Exist in Active Directory" -value (-not $CNODoesNotExist)
				add-member -inputobject $Return_Object -membertype noteproperty -name "Computer Account Disabled" -value $CNODisabled
			}else{
				Update-DiagRootCause -id $RootCauseName -Detected $false
			}
		}else{
			"ERROR: Domain Controller could not be contacted"  | WriteTo-StdOut -ShortFormat
		}
	}

	# *********************
	# Root Cause processing
	# *********************
	if ($RootCauseDetected){
		Update-DiagRootCause -id $RootCauseName -Detected $true
		Write-GenericMessage -RootCauseId $RootCauseName -PublicContentURL "http://support.microsoft.com/kb/950805" -Verbosity "Error" -InformationCollected $Return_Object -Visibility 4 -Component "FailoverCluster" -SupportTopicsID 8008 -MessageVersion 2
	}else{
		Update-DiagRootCause -id $RootCauseName -Detected $false
	}
}


# SIG # Begin signature block
# MIInlwYJKoZIhvcNAQcCoIIniDCCJ4QCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDUXZsmZDDMtucE
# Zp9dpRzmQWGoL0iF23CCOIVr0jqkg6CCDXYwggX0MIID3KADAgECAhMzAAACy7d1
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
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIIt8A8c6Dey90YqrpShs7FE1
# LDjLFunj0uCbjSEdaGQRMEQGCisGAQQBgjcCAQwxNjA0oBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEcgBpodHRwczovL3d3dy5taWNyb3NvZnQuY29tIDANBgkqhkiG9w0B
# AQEFAASCAQCi/SQY5ZmU+3AUHwsXa0Dkcy2FE2obnBP0P9++plkrXJmvlVRPJLyb
# QAxs2a43NOfVEZF08MJv2u7DytTBA1nQP7FS1jgerg6Rp7S5ECu/6VtKQtAWCMDx
# BfJ9bwVHGskcEkAq8e5XA8iFy8Gjwy4JXSDi0H6s/y7Lk5Yj+/RDyqA/Qgq5Yhrx
# 70t8PoQL1c1nya/7CRgaZmdqJHgMPa0Fn1EOO17oBkGyuj2rcOwGheg8e2/nFB/f
# dZENw/1AY5+qDZpNrC7Swv2UeYOuwox2tEnk+BmVIcbBnrAim5TPfYQpgOLy99p3
# y2tlPt6HyFTHp9vdkim9FMwu4wDRaSKJoYIW/zCCFvsGCisGAQQBgjcDAwExghbr
# MIIW5wYJKoZIhvcNAQcCoIIW2DCCFtQCAQMxDzANBglghkgBZQMEAgEFADCCAVAG
# CyqGSIb3DQEJEAEEoIIBPwSCATswggE3AgEBBgorBgEEAYRZCgMBMDEwDQYJYIZI
# AWUDBAIBBQAEILhrMv1+4ltkmi56NHBqALQ2Ab3Nf6ZXSsXKywaxw6hkAgZj7pDG
# YLEYEjIwMjMwMjIwMTUwNjExLjE3WjAEgAIB9KCB0KSBzTCByjELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFt
# ZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046OEE4Mi1F
# MzRGLTlEREExJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wg
# ghFXMIIHDDCCBPSgAwIBAgITMwAAAcL6fYcOVFNHJAABAAABwjANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yMjExMDQxOTAx
# MjhaFw0yNDAyMDIxOTAxMjhaMIHKMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25z
# MSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjo4QTgyLUUzNEYtOUREQTElMCMGA1UE
# AxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBALXxCbzyjkhZ96XrafcHKNvf1KCZgw8h6ZpqUa7kVVgR
# d+wctJ767M0nDlfyvi7x1llguEvXJnuD+txJjYcUzf5NgoD5yLf7A3qcgAkpMmuL
# pKnNbE9iPtFKHdMY8vStvoyx/FDW/bzN8h/7wmJ2iUlKoLamVJcvNqYGEgerQ3mS
# GHEKDoUyPjNR4UcZsbfEWgCmZw514C3ZIZyGAya0ZEAaSIGobRMbU7jpJladsvGA
# qBT2lIVA9iU+oT4gw+6g+wO+zy6Rcw9kBZjXs0/Ghx4SrFQbiTCz12TtZNeI9P5O
# vA2RrbNWAbRnoFzZMr5F0oAgsbd0PFhfJWgV2w54R2gywYQjgWmUPI6nBVMfGSUl
# 0PLG7xJ5lhWZoDPdwfT/yUxUxeqgVRTA3f1dDwW0UAtk3LWR+G37/o8lr2Tnhc+c
# pbTy0cVKgY7+ChyGiYAYVNp7TMOB9IaZuAe7Oiy8ZE7Iy7Go4wiSPD4iov5jymBE
# XZkcrxS/P2APz3apCMFloNk4+bcrrRhbX1Ufuhm3AlYYo48u5e6LcWv8GFUl+ui6
# NGpWk4Y3PrqI1cB+KbC/gNar21gwfbMKCpWttHmbm8O38wqRXuqrPvhtNbLLdUmg
# NBhps7kAndOFHtXh9wxUQ2T7DfmlrwOOeUJnfWSSxl7qpwaOAV8FcXVmTY+vm+D/
# AgMBAAGjggE2MIIBMjAdBgNVHQ4EFgQURrGIe+leNWlAkVxPVrw/vrCHxmowHwYD
# VR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYDVR0fBFgwVjBUoFKgUIZO
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWljcm9zb2Z0JTIw
# VGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwGCCsGAQUFBwEBBGAwXjBc
# BggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jZXJ0
# cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcnQwDAYD
# VR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDCDANBgkqhkiG9w0BAQsFAAOC
# AgEAEXbt3QpHCyz32id60dTOw/Y1h753n35Jl7xSCbasRxljNaKgIfm6saSOx2c9
# jHjYYdQqPhPQGmzoI/eEqdbHl8XViEifZURmgAFswPO92kwd/0o8Lhqm6kLgL1Mw
# RQjuNFCfWp6Wr5Kav9Jw6i2+1yOR/p7JoxcrvMql9TzJp2+LNX23Pxd9Io2gEs6i
# fqea64GFsA6DIoTOWxdGNK4l4ocBO3k0oWpPxMHMUZht4fjk/jsfCji7i6sBRZdb
# Ik3kAqfmEreCdbVl2qahiQ5Qm2K90c/Pq8k0vAqGQFNL0hwjkHKtdk4fNae0JR2b
# /XE0Q4WYNk1coPBsd1+ppKTTl2+ekFKISN0p9/VkCcIw5++CdGlWDGovJmOv1jrq
# yjChLkjYQonotEyuvLzmO7B9FxAVp0Um1Xn3krQ6PeFCFFU8Hdh5gRH2PJH68qd0
# ZQPQOBb31LwxzGhfQbb1P6SundQnShtvVdFjd7lc32BEyaEaYy2BRqtDLyukFTJr
# jcZN2wkX49WnElnnteFBo4JcVsL8jnzSXt6cXDRTnfB4cqfXeAJUBlSzaLWhb6KY
# Dy3icFE93ZeVWgAITMLyBZqsLH30Mvd5qK66a3J7++K+YN3owt/TWKRRKMvqpsy1
# tYxWtWlxNl2/ymcNsmsKpXUqdB7uFRJIxsRTXPgM7SFFsJkwggdxMIIFWaADAgEC
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
# RVNOOjhBODItRTM0Ri05RERBMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQDKdTdVS4TzL1lxKGX5heGqWZZ0VKCB
# gzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAk
# BgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEB
# BQUAAgUA552sfDAiGA8yMDIzMDIyMDE2MjMyNFoYDzIwMjMwMjIxMTYyMzI0WjB3
# MD0GCisGAQQBhFkKBAExLzAtMAoCBQDnnax8AgEAMAoCAQACAhdkAgH/MAcCAQAC
# AhHJMAoCBQDnnv38AgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKg
# CjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQEFBQADgYEABnVfvIEq
# 7CNTC8NUTCPccVLbX5vgg80iqqpxCJfQUqJLUkdARGWPlD61MppqcMet28rxZ+Kf
# 6/SxixQYRYflEDra77Du3F0qq4MpjXzZSw3cpZw2co7GNl+n3ROj1fUpsJs3xEVZ
# 9Q4/6y71ekEXk+2fHgnOm/KculvQZnf5X4gxggQNMIIECQIBATCBkzB8MQswCQYD
# VQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEe
# MBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3Nv
# ZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAcL6fYcOVFNHJAABAAABwjANBglg
# hkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqG
# SIb3DQEJBDEiBCDIcj9WV/+BhtPUx4VQVAzjT0CUUfi/pvM3Y6VLBzwx8TCB+gYL
# KoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIMqTYFvH6bDFee69BeW3lLohFTlXuAXZ
# mjvntvJhg1AWMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAC
# EzMAAAHC+n2HDlRTRyQAAQAAAcIwIgQgVtODepmcC3DdnHqX+8spKop20Qsuc00c
# T253kZt/wygwDQYJKoZIhvcNAQELBQAEggIAYSVfqG/juCNYco+JBP2PAPjKtPD9
# HOg0Q38nWGVdB+oxnO6gepjOcJ3LOYdzdgEN9QGfUrPsIGd0cLQgfFmqHK8ypmrI
# gsDYIPGZH/SNd3GsNbV1M3tqt6P8lJkFMClNESXcByKkjduxu/ZffsCEmIR67FPK
# ZCcRC3WbF09zUmo6xNRplAqZyB5UueOX6/e4GlTu4x4DtbkNb3WTkLxQvwYOyfWP
# ekAHBCLhmAEW1pwWIlcIJVswJmZpTYKOb2A4E9VJFeTc9UUQmjFSLHXKIkAaWq7C
# cGVuroNHN3620NcLxoO00hus7nAp9OnpOZHiVpI4WbsA5xyrefP2Z+yb20/8tBiu
# fAxdPaozlrtoYu01rELKi2lu/aaX+vocBD/eNsRGVRI0weVkJjS/0HBW7Eaq7aQZ
# xM+lIXste4vnrUoKm/5C0WZIES2g8wflwMvrfCHrt2+Azl/V+bNjeQQ0TcFmm69p
# mt7cV3bCFdZslU2o21jgRfD8UiBs8Sae1KVRLKvo9BvE9B0UHZ9lmOjetcKk3vUa
# JCDckQWpFn+kHyo032uwlA1dlUyBEQJRxnO0qRYCgC6WopjxNc3hbNcoIOj/BY8L
# mW/Ne+QL/s1v6pyDNcsGkZ6fbG9ut88IEVgUBORKQFXKmqoyR45OBslcAAPBrmAD
# y3Ssx6iuEbZW0YI=
# SIG # End signature block
