# Script: tss_GetFarmData.ps1
# from https://microsoft.sharepoint.com/teams/css-rds/SitePages/getfarmdata.aspx?xsdata=MDN8MDF8fDRhNGUxOTM4NmE3ZTQ0ODliNWJlMWQ2MDdmYjgwMjU2fDcyZjk4OGJmODZmMTQxYWY5MWFiMmQ3Y2QwMTFkYjQ3fDF8MHw2Mzc3NzU4NTEyODY0MjIxMDZ8R29vZHxWR1ZoYlhOVFpXTjFjbWwwZVZObGNuWnBZMlY4ZXlKV0lqb2lNQzR3TGpBd01EQWlMQ0pRSWpvaVYybHVNeklpTENKQlRpSTZJazkwYUdWeUlpd2lWMVFpT2pFeGZRPT0%3D&sdata=ZzVWUFZRZXQvWUMwa3VWbzZpeStmNHhRN2VDMTlVd1NjdkthNUNIWkYyUT0%3D&ovuser=72f988bf-86f1-41af-91ab-2d7cd011db47%2Cwaltere%40microsoft.com&OR=Teams-HL&CT=1642008472926
# addon to tss RDSsrv

#region ::::: Script Input PARAMETERS :::::
[CmdletBinding()]param(
 [Parameter(Mandatory=$False, Position=0)] [String] $DataPath
)
$ScriptVer="1.00"	#Date: 2022-01-12


Import-Module remotedesktop


#Get Servers of the farm:
$servers = Get-RDServer

$BrokerServers = @()
$WebAccessServers = @()
$RDSHostServers = @()
$GatewayServers = @()

foreach ($server in $servers)
{
	switch ($server.Roles)
	{
	"RDS-CONNECTION-BROKER" {$BrokerServers += $server.Server}
	"RDS-WEB-ACCESS" {$WebAccessServers += $server.Server}
	"RDS-RD-SERVER" {$RDSHostServers += $server.Server}
	"RDS-GATEWAY" {$GatewayServers += $server.Server}
	}
}
"Machines involved in the deployment : " + $servers.Count
"	-Broker(s) : " + $BrokerServers.Count
foreach ($BrokerServer in $BrokerServers)
		{
		"		" +	$BrokerServer
$ServicesStatus = Get-WmiObject -ComputerName $BrokerServer -Query "Select * from Win32_Service where Name='rdms' or Name='tssdis' or Name='tscpubrpc'"
        foreach ($stat in $ServicesStatus)
        {
        "		      - " + $stat.Name + " service is " + $stat.State
        }

		}
" "	
"	-RDS Host(s) : " + $RDSHostServers.Count
foreach ($RDSHostServer in $RDSHostServers)
		{
		"		" +	$RDSHostServer
$ServicesStatus = Get-WmiObject -ComputerName $RDSHostServer -Query "Select * from Win32_Service where Name='TermService'"
        foreach ($stat in $ServicesStatus)
        {
        "		      - " + $stat.Name +  "service is " + $stat.State
        }
		}
" " 
"	-Web Access Server(s) : " + $WebAccessServers.Count
foreach ($WebAccessServer in $WebAccessServers)
		{
		"		" +	$WebAccessServer
		}
" " 	
"	-Gateway server(s) : " + $GatewayServers.Count
foreach ($GatewayServer in $GatewayServers)
		{
		"		" +	$GatewayServer

$ServicesStatus = Get-WmiObject -ComputerName $GatewayServer -Query "Select * from Win32_Service where Name='TSGateway'"
        foreach ($stat in $ServicesStatus)
        {
        "		      - " + $stat.Name + " service is " + $stat.State
        }
		}
" "

#Get active broker server.
$ActiveBroker = Invoke-WmiMethod -Path ROOT\cimv2\rdms:Win32_RDMSEnvironment -Name GetActiveServer
$ConnectionBroker = $ActiveBroker.ServerName
"ActiveManagementServer (broker) : " +	$ActiveBroker.ServerName
" "

# Deployment Properties  TODO ##############
##########
"Deployment details : "
# Is Broker configured in High Availability?
$HighAvailabilityBroker = Get-RDConnectionBrokerHighAvailability
$BoolHighAvail = $false
If ($null -eq $HighAvailabilityBroker)
{
	$BoolHighAvail = $false
	"	Is Connection Broker configured for High Availability : " + $BoolHighAvail
}
else
{
	$BoolHighAvail = $true
	"	Is Connection Broker configured for High Availability : " + $BoolHighAvail
	"		- Client Access Name (Round Robin DNS) : " + $HighAvailabilityBroker.ClientAccessName
	"		- DatabaseConnectionString : " + $HighAvailabilityBroker.DatabaseConnectionString
    "		- DatabaseSecondaryConnectionString : " + $HighAvailabilityBroker.DatabaseSecondaryConnectionString
	"		- DatabaseFilePath : " + $HighAvailabilityBroker.DatabaseFilePath
}

#Gateway Configuration
$GatewayConfig = Get-RDDeploymentGatewayConfiguration -ConnectionBroker $ConnectionBroker
"	Gateway Mode : " + $GatewayConfig.GatewayMode
if ($GatewayConfig.GatewayMode -eq "custom")
{
"		- LogonMethod : " + $GatewayConfig.LogonMethod   
"		- GatewayExternalFQDN : " + $GatewayConfig.GatewayExternalFQDN
"		- GatewayBypassLocal : " + $GatewayConfig.BypassLocal
"		- GatewayUseCachedCredentials : " + $GatewayConfig.UseCachedCredentials

}

# RD Licencing
$LicencingConfig = Get-RDLicenseConfiguration -ConnectionBroker $ConnectionBroker
"	Licencing Mode : " + $LicencingConfig.Mode
if ($LicencingConfig.Mode -ne "NotConfigured")
{
"		- Licencing Server(s) : " + $LicencingConfig.LicenseServer.Count
foreach ($licserver in $LicencingConfig.LicenseServer)
{
"		       - Licencing Server : " + $licserver
}

}
# RD Web Access
"	Web Access Server(s) : " + $WebAccessServers.Count
foreach ($WebAccessServer in $WebAccessServers)
{
"	     - Name : " + $WebAccessServer
"	     - Url : " + "https://" + $WebAccessServer + "/rdweb"
}

# Certificates
#Get-ChildItem -Path cert:\LocalMachine\my -Recurse | Format-Table -Property DnsNameList, EnhancedKeyUsageList, NotAfter, SendAsTrustedIssuer
"	Certificates "
$certificates = Get-RDCertificate -ConnectionBroker $ConnectionBroker
foreach ($certificate in $certificates)
{
"		- Role : " + $certificate.Role
"			- Level : " + $certificate.Level
"			- Expires on : " + $certificate.ExpiresOn
"			- Issued To : " + $certificate.IssuedTo
"			- Issued By : " + $certificate.IssuedBy
"			- Thumbprint : " + $certificate.Thumbprint
"			- Subject : " + $certificate.Subject
"			- Subject Alternate Name : " + $certificate.SubjectAlternateName

}
" "

#RDS Collections
$collectionnames = Get-RDSessionCollection 
$client = $null
$connection = $null
$loadbalancing = $null 
$Security = $null
$UserGroup = $null
$UserProfileDisks = $null

"RDS Collections : "
foreach ($Collection in $collectionnames)
{
	$CollectionName = $Collection.CollectionName
	"	Collection : " +  $CollectionName	
	"		Resource Type : " + $Collection.ResourceType
	if ($Collection.ResourceType -eq "RemoteApp programs")
	{
		"			Remote Apps : "
		$remoteapps = Get-RDRemoteApp -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName
		foreach ($remoteapp in $remoteapps)
		{
			"			- DisplayName : " + $remoteapp.DisplayName
			"				- Alias : " + $remoteapp.Alias
			"				- FilePath : " + $remoteapp.FilePath
			"				- Show In WebAccess : " + $remoteapp.ShowInWebAccess
			"				- CommandLineSetting : " + $remoteapp.CommandLineSetting
			"				- RequiredCommandLine : " + $remoteapp.RequiredCommandLine
			"				- UserGroups : " + $remoteapp.UserGroups
		}		
	}

#       $rdshServers		
		$rdshservers = Get-RDSessionHost -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName
		"		Servers in that collection : "
		foreach ($rdshServer in $rdshservers)
		{		
			"			- SessionHost : " + $rdshServer.SessionHost			
			"				- NewConnectionAllowed : " + $rdshServer.NewConnectionAllowed			
		}		
		
		$client = Get-RDSessionCollectionConfiguration -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -Client 
		"		Client Settings : " 
		"			- MaxRedirectedMonitors : " + $client.MaxRedirectedMonitors
		"			- RDEasyPrintDriverEnabled : " + $client.RDEasyPrintDriverEnabled
		"			- ClientPrinterRedirected : " + $client.ClientPrinterRedirected
		"			- ClientPrinterAsDefault : " + $client.ClientPrinterAsDefault
		"			- ClientDeviceRedirectionOptions : " + $client.ClientDeviceRedirectionOptions
		" "
		
		$connection = Get-RDSessionCollectionConfiguration -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -Connection
		"		Connection Settings : " 
		"			- DisconnectedSessionLimitMin : " + $connection.DisconnectedSessionLimitMin
		"			- BrokenConnectionAction : " + $connection.BrokenConnectionAction
		"			- TemporaryFoldersDeletedOnExit : " + $connection.TemporaryFoldersDeletedOnExit
		"			- AutomaticReconnectionEnabled : " + $connection.AutomaticReconnectionEnabled
		"			- ActiveSessionLimitMin : " + $connection.ActiveSessionLimitMin
		"			- IdleSessionLimitMin : " + $connection.IdleSessionLimitMin
		" "
		
		$loadbalancing = Get-RDSessionCollectionConfiguration -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -LoadBalancing
		"		Load Balancing Settings : " 
		foreach ($SessHost in $loadbalancing)
		{
		"			- SessionHost : " + $SessHost.SessionHost
		"				- RelativeWeight : " + $SessHost.RelativeWeight
		"				- SessionLimit : " + $SessHost.SessionLimit
		}
		" "
		
		$Security = Get-RDSessionCollectionConfiguration -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -Security
		"		Security Settings : " 
		"			- AuthenticateUsingNLA : " + $Security.AuthenticateUsingNLA
		"			- EncryptionLevel : " + $Security.EncryptionLevel
		"			- SecurityLayer : " + $Security.SecurityLayer
		" "
		
		$UserGroup = Get-RDSessionCollectionConfiguration -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -UserGroup 
		"		User Group Settings : "
		"			- UserGroup  : " + $UserGroup.UserGroup 
		" "
		
		$UserProfileDisks = Get-RDSessionCollectionConfiguration -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -UserProfileDisk
		"		User Profile Disk Settings : "
		"			- EnableUserProfileDisk : " + $UserProfileDisks.EnableUserProfileDisk
		"			- MaxUserProfileDiskSizeGB : " + $UserProfileDisks.MaxUserProfileDiskSizeGB
		"			- DiskPath : " + $UserProfileDisks.DiskPath                 
		"			- ExcludeFilePath : " + $UserProfileDisks.ExcludeFilePath
		"			- ExcludeFolderPath : " + $UserProfileDisks.ExcludeFolderPath
		"			- IncludeFilePath : " + $UserProfileDisks.IncludeFilePath
		"			- IncludeFolderPath : " + $UserProfileDisks.IncludeFolderPath
		" "
				
		$usersConnected = Get-RDUserSession -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName
		"		Users connected to this collection : " 
		foreach ($userconnected in $usersConnected)
		{
		"			User : " + $userConnected.DomainName + "\" + $userConnected.UserName
		"				- HostServer : " + $userConnected.HostServer
		"				- UnifiedSessionID : " + $userConnected.UnifiedSessionID
		}
		" "	 	
    }


# SIG # Begin signature block
# MIIoOAYJKoZIhvcNAQcCoIIoKTCCKCUCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCWEhKoBksWIeEl
# jSvC9xPcH4cRlhpSa8aO9dzLXKkBAaCCDYUwggYDMIID66ADAgECAhMzAAADri01
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
# cVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCGgkwghoFAgEBMIGVMH4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01p
# Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAAOuLTVRyFOPVR0AAAAA
# A64wDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIFuQ
# Jn46t80mO6mimNmZ4aPuWz9U9sLk7meHk1IeknX5MEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEAEWR2tR6C6FMJ6SpT6rkLbRmpAIP/qIBFUEa2
# F5AcXxyHjTzxi8/spClc6e7nsqlXjYFs7vAPFc+nbF7SWHQHTaE0roiemroF9xOg
# DN+WD4IuqyqC8AFkzyTw5XjSnKtFjwCh+Yd7LGmChsuLTNN5tybNGt2/3Efp8McM
# JeTtFhQKf+kl0HV4E0owrq0zGwWQaiTEZOX0PO3VZT5TDfEzgS1xpWhNO58NPBJz
# BAwvhhU4izmpgS2vxoWLFigEg/KZs2uMiEoFTNuBPON2wX51iDxCXBct6ByK+lfw
# S6hnON2XRePaeSKr7tVbVG+gN44N0EdWt/XwQBsumlAItjc+xqGCF5MwghePBgor
# BgEEAYI3AwMBMYIXfzCCF3sGCSqGSIb3DQEHAqCCF2wwghdoAgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFRBgsqhkiG9w0BCRABBKCCAUAEggE8MIIBOAIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCBmlDBkylwTdVfezzaKfpA6k5h0wLXmYzbk
# G5cNiOnUOQIGZc3/hho0GBIyMDI0MDIyMDEyMTcwMy4wM1owBIACAfSggdGkgc4w
# gcsxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsT
# HE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQg
# VFNTIEVTTjo5MjAwLTA1RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZaCCEeowggcgMIIFCKADAgECAhMzAAAB5y6PL5MLTxvpAAEA
# AAHnMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MB4XDTIzMTIwNjE4NDUxOVoXDTI1MDMwNTE4NDUxOVowgcsxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1pY3Jvc29mdCBBbWVy
# aWNhIE9wZXJhdGlvbnMxJzAlBgNVBAsTHm5TaGllbGQgVFNTIEVTTjo5MjAwLTA1
# RTAtRDk0NzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMJXny/gi5Drn1c8zUO1pYy/
# 38dFQLmR2IQXz1gE/r9GfuSOoyRnkRJ6Z/kSWLgIu1BVJ59GkXWPtLkssqKwxY4Z
# FotxpVsZN9yYjW8xEnW3MzAI0igKr+/LxYfxB1XUH8Bvmwr5D3Ii/MbDjtN9c8Tx
# GWtq7Ar976dafAy3TrRqQRmIknPVWHUuFJgpqI/1nbcRmYYRMJaKCQpty4CeG+Hf
# Ksxrz24F9p4dBkQcZCp2yQzjwQFxZJZ2mJJIGIDHKEdSRuSeX08/O0H9JTHNFmNT
# NYeD1t/WapnRwiIBYLQSMrs42GVB8pJEdUsos0+mXf/5QvheNzRi92pzzyA4tSv/
# zhP3/Ermvza6W9GnYDz9qv1wbhbvrnS4poDFECaAviEqAhfn/RogCxvKok5ro4gZ
# IX1r4N9eXUulA80pHv3axwXu2MPlarAi6J9L1hSIcy9EuOMqTRJIJX+alcLQGg+S
# Tlqx/GuslsKwl48dI4RuWknNGbNo/o4xfBFytvtNcVA6xOQq6qRa+9gg+9XMLrxQ
# z4yyQs+V3V6p044wrtJtt/a0ZJl/f6I7BZAxxZcH2DDmArcAhgrTxaQkm7LM+p+K
# 2C5t1EKZiv0JWw065b7AcNgaFyIkMXYuSuOQVSNRxdIgl31/ayxiK1n0K6sZXvgF
# Bx+vGO+TUvyO+03ua6UjAgMBAAGjggFJMIIBRTAdBgNVHQ4EFgQUz/7gmICfNjh2
# kR/9mWuHUrvej1gwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYD
# VR0fBFgwVjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9j
# cmwvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwG
# CCsGAQUFBwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQu
# Y29tL3BraW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIw
# MjAxMCgxKS5jcnQwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcD
# CDAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAHSh8NuT6WVaLVwL
# qex+J7km2nT2jpvoBEKm+0M+rYoU/6GL5Q00/ssZyIq5ySpcKYFMUiF8F4ZLG+Tr
# JyiR1CvfzXmkQ5phZOce9DT7yErLzqvUXit8G7igcHlxPLTxPiiGsb85gb8H+A2f
# PQ6Xq/u7+oSPPjzNdnpmXEobJnAqYplZoF3YNgTDMql0uQHGzoDp6dZlHSNj6rkV
# 1tXjmCEZMqBKvkQIA6csPieMnB+MirSZFlbANlChe0lJpUdK7aUdAvdgcQWKS6dt
# RMl818EMsvsa/6xOZGINmTLk4DGgsbaBpN+6IVt+mZJ89yCXkI5TN8xCfOkp9fr4
# WQjRBA2+4+lawNTyxH66eLZWYOjuuaomuibiKGBU10tox81Sq8EvlmJIrXOZoQsE
# n1r5g6MTmmZJqtbmwZufuJWQXZb0lAg4fq0ZYsUlLkezfrNqGSgeHyIP3rct4aNm
# qQW6wppRbvbIyP/LFN4YQM6givfmTBfGvVS77OS6vbL4W41jShmOmnOn3kBbWV6E
# /TFo76gFXVd+9oK6v8Hk9UCnbHOuiwwRRwDCkmmKj5Vh8i58aPuZ5dwZBhYDxSav
# wroC6j4mWPwh4VLqVK8qGpCmZ0HMAwao85Aq3U7DdlfF6Eru8CKKbdmIAuUzQrnj
# qTSxmvF1k+CmbPs7zD2Acu7JkBB7MIIHcTCCBVmgAwIBAgITMwAAABXF52ueAptJ
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
# tB1VM1izoXBm8qGCA00wggI1AgEBMIH5oYHRpIHOMIHLMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmlj
# YSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046OTIwMC0wNUUw
# LUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2WiIwoB
# ATAHBgUrDgMCGgMVALNyBOcZqxLB792u75w97U0X+/BDoIGDMIGApH4wfDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9z
# b2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQELBQACBQDpfmwCMCIY
# DzIwMjQwMjIwMDAwODM0WhgPMjAyNDAyMjEwMDA4MzRaMHQwOgYKKwYBBAGEWQoE
# ATEsMCowCgIFAOl+bAICAQAwBwIBAAICHiQwBwIBAAICE64wCgIFAOl/vYICAQAw
# NgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQACAwehIKEKMAgC
# AQACAwGGoDANBgkqhkiG9w0BAQsFAAOCAQEASMF2HFzYPLUiIj9puaTYTwizZiAq
# O+kquAdXGuZHq5OhUs/5RN8ZSPZZ2TqY5T21hKjb5/KeQQJk3QOgqNMQaHgKueR6
# EsFW5Y2BYuwJlzhT58+c2aBnaoCgMIJdESclH0kgmblS01e164yjMLurzHGD92iz
# iCx7h6hQIcHIcUCxAXbJAfiXDQAvlR7xAr/AGZBajSF3NmESj8AYhYEl3lfjX3TJ
# 26qmYmmPhu5itG2sVDNsBUuVMgebPwqh87dt0uyjMFT1Yr37/7xrUBefVLIS3mEt
# RfhSvNyZMyYz1QgXIsbAbWEM6tkjpQ63A/5I8u5i/l9Mi8sqOfrZyPzxuDGCBA0w
# ggQJAgEBMIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB5y6P
# L5MLTxvpAAEAAAHnMA0GCWCGSAFlAwQCAQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYL
# KoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkEMSIEIAAlqJfE5YjCKYG7SGZKO8ye1bRd
# /44H2JCm1w66qgdYMIH6BgsqhkiG9w0BCRACLzGB6jCB5zCB5DCBvQQg5TZdDXZq
# hv0N4MVcz1QUd4RfvgW/QAG9AwbuoLnWc60wgZgwgYCkfjB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMAITMwAAAecujy+TC08b6QABAAAB5zAiBCDmy2s2xhsA
# lJwoATlobcuibku+hLm0XGgFDh7x8g0d7TANBgkqhkiG9w0BAQsFAASCAgA7umL5
# iy9f6dNFLV+CGeJE5JyH3ZSw/WMxjSKcsDss6On+iwKDHbbOyEv74LoXlQGG5uio
# fY9aUsGsWXr28VXPQO3ODhK0z6zs6PjQJ4hy4wr7P4W0TTKxMfM41oQnZ52QxunP
# MIRlRipiDq0U666VXTwsc9l8URPRzlZhA1Qs6FlGGpqv6il8j0cL5WwPmDwgQobA
# 3fABYbthc5KP8CsAxO5gbVCiCQ3Fce1wav/Sgt6sJXmzFmHeE0f24pOkk/iJZEI5
# uGHLlUVe8FQesQ/74ZrhtmtUfM7jpXQzDSW4UJJb+nwcYPvjnNWwXC+DqOM4ykTV
# myWXmZxWaFNNyDl4AeYBWOtqlJO39qYlhmD3iFT0Z5eWIvCu1E6FDHGaLM5zQnWL
# 4Anwkjwr/QIYJuiCTev3RKYDOYng6WT0uOQcmSsKBJ314xJlUMVdiLGKS+CYWvF2
# 97fHW8xoYK69iDZdNcq41i4kQ8h3GO3OVfyrFzviLHCtMHexZsC323j/R1hANw0U
# EA8dorJHEK0kkmsxxjbkmruAB/nde85Sm64QXRW0vC/iyxpekbxSvLH9UTxOB5aq
# MLKYANIetYIsv34pDSy0hmrxhhXP93/YCLSlUH7A9df8AsiYnee9qJYVTCs4Mt31
# nxSxXu6hxnQrwIwcLRcLARNMRFfW8C4EsfoIIg==
# SIG # End signature block
