# Name tss_GetLockoutEvents.ps1

<# 
.SYNOPSIS
 Script to find Account Lockout: PowerShell script collects Security events from all DCs related with Bad Password attempts

.DESCRIPTION
 PowerShell script sample to assist in troubleshooting account lockout issues. It can be used to collect Security Events from all DCs in a given forest or domain.
 It collects events like 4625, 4771, 4776 with error codes 0x18 and c000006a respectively.
 You do not have to run the script elevated. However you have to run it with *domain admin* privileges.
 It can be run against any domain in the forest you logon to run the script. Running against a different domain may need you to run the script with other domain admin privileges or Enterprise Admin.
 Script can also detect trusted domains and collect events from remote DCs. Make sure that the domain admin running the script has the permission to collect events remotely from trusted domains.

.PARAMETER UserName
 Please enter the UserName (sAMAccountName)
 
.PARAMETER DomainName
 Please enter the NetBIOS or FQDN of any domain in the forest
 
.PARAMETER DataPath
 This switch determines the path for output files
 
.EXAMPLE
 .\tss_GetLockoutEvents.ps1 -UserName "User1" -DomainName "Contoso" -DataPath "C:\MS_DATA" 
 Example 1:  for User1 in domain Contoso
 
.LINK
 https://internal.evergreen.microsoft.com/en-us/help/4498703
 https://microsoft.sharepoint.com/teams/HybridIdentityPOD/_layouts/15/Doc.aspx?sourcedoc={5bec59af-bf31-4073-9111-a63486fcdf0c}&action=view&wd=target%28Account%20Lockouts.one%7C9a46c4f5-38af-4648-93f2-8a976a91c463%2FWorkflow%20Account%20Lockout%20Data%20Collection%20-%20Reactive%7Cdc03d719-fff5-4bdf-b46e-15456c2521f1%2F%29
 
 Author: Ahmed Fouad (v-ahfoua@microsoft.com)
#>


# Version 1.4 - 2020.03.25 WalterE

[CmdletBinding()]
PARAM (
    [Parameter(Mandatory=$True,Position=0,HelpMessage='Enter user sAMAccountName')]
	[string]$UserName
	,
	[Parameter(Mandatory=$True,Position=1,HelpMessage='Enter DomainName')]
	[string]$DomainName
	,
	[string]$DataPath = (Split-Path $MyInvocation.MyCommand.Path -Parent)
)

#region helper functions
function CheckDomain
{	# Check domain and user variables
	try 
	{
	  Write-Host "..Checking whether domain $DomainName exists" 
	  if (Get-ADDomain $DomainName) 
	   {
		Write-Host "Domain '$DomainName' exists" -fore Green
	   }

	}
	catch 
	{
		 Write-Host $_.Exception.Message -fore Red
		 break 
	}
}

function CheckUser
{	# Check whether the user exist or not
	try
	{
	   Write-Host "..Checking whether AD user $UserName exists" 
	   if (Get-ADUser -Identity $UserName -Server $DomainName) 
		{
		 Write-Host "AD user '$UserName' exists in '$DomainName' domain" -fore Green
		}
	}
	catch 
	{
		Write-Host  $_.Exception.Message -fore Red
		break 
	}
}

function CheckDomainAdmin
{
	Write-Host "..Checking whether the current user $env:Username has domain admin privilege" 

	if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("$DomainName\Domain Admins") -and  (-not  ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Enterprise Admins") ) ) 
	  {
		Write-Host "Sorry you '$env:Username' don't have domain admin privilege to run this script" -fore Red
		Break
	  }
	Else 
	  {
		Write-Host "User '$UserName' is member of '$DomainName\Domain Admins'" -fore Green 
	  }
}
#endregion helper functions


#region variables

[xml]$xmlfilter = "<QueryList> 
           <Query Id='0'> 
              <Select Path='Security'> 
                 *[EventData[Data[@Name='TargetUserName'] and (Data='$username')]] 
                  and 
                 *[EventData[Data[@Name='status'] and (Data='0x18')]] 
                 and
                 *[System[(EventID='4771' or EventID='4768' or EventID='4769' )]]
              </Select> 
           </Query> 
<Query Id='1'> 
              <Select Path='Security'> 
               *[EventData[Data[@Name='TargetUserName'] and (Data='$username')]] 
               and  
               *[EventData[Data[@Name='substatus'] and (Data='0xc000006a')]] 
                  and
               *[System[(EventID='4625' )]] 
               </Select> 
           </Query> 
<Query Id='2'> 
              <Select Path='Security'> 
               *[EventData[Data[@Name='TargetUserName'] and (Data='$username')]] 
                  and
               *[System[(EventID='4740' or EventID='4767' )]] 
               </Select> 
           </Query> 
<Query Id='3'> 
              <Select Path='Security'> 
               *[EventData[Data[@Name='TargetUserName'] and (Data='$username')]] 
               and  
               *[EventData[Data[@Name='Status'] and (Data='0xc000006a')]] 
                  and
               *[System[(EventID='4776' )]] 
               </Select> 
           </Query> 

</QueryList>"

#_# $DataPath = read-host "Please enter the path of the report (leave it blank to use the default path)"

if ($DataPath)
    {
      $fullpath = $DataPath
      New-Item -ItemType Directory -Path $fullpath\LockoutLogs -ErrorAction SilentlyContinue -InformationAction SilentlyContinue | Out-Null
    }
Else 
    {
     $fullpath = (get-location).path
     New-Item -ItemType Directory -Path $fullpath\LockoutLogs -ErrorAction SilentlyContinue -InformationAction SilentlyContinue | Out-Null
    
    }

$CSVPath = $fullpath + "\LockoutLogs\Report.csv" 


$AllEvents = @()
$SourceMachines = @()
$ExchangeServersIPv4 = @()

foreach ($ExchangeServer in $ExchangeServers ) 
{
   $ExchangeServersIPv4 += (Resolve-DnsName $ExchangeServer.name).IPAddress

}

#endregion variables

function GetEventsFromAllDCs
{
	$Dcs = Get-ADDomainController -Filter * -Server $DomainName
	#get events from all domain controllers
	foreach ($dc in $Dcs)
	{
	$serverName = $dc.HostName
	Write-Host "Checking connectivity to DC:" $serverName 
	$PingStatus = Get-WmiObject win32_pingStatus -Filter "Address = '$serverName'"

	if ($PingStatus.StatusCode -eq 0)
		{  
		  Write-Host $serverName  " is Online" -fore Green
		  Write-Host "Collecting logs from:" $serverName
		  $Events = get-winevent -FilterXml $xmlfilter -ComputerName $serverName -ErrorAction SilentlyContinue  
		  foreach ($event in $events)
		  {
		   $eventxml = [xml]$event.ToXml()

		   if ($event.Id -eq "4771")
			 {
			  $ipv4 = ($eventxml.Event.EventData.Data[6].'#text').Split(":")
			  $myObject = New-Object System.Object
			  $myObject | Add-Member -type NoteProperty -name "Source Machine" -Value $ipv4[($ipv4.length -1 )]
			  $myObject | Add-Member -type NoteProperty -name "Event ID" -Value "4771"
			  $SourceMachines += $myObject
			 } 
		   if ($event.Id -eq "4776")
			 {
			  $ipv4 = Resolve-DnsName ($eventxml.Event.EventData.Data[2].'#text')
			  $myObject = New-Object System.Object
			  $myObject | Add-Member -type NoteProperty -name "Source Machine" -Value $ipv4.IPAddress
			  $myObject | Add-Member -type NoteProperty -name "Event ID" -Value "4776"
			  $SourceMachines += $myObject
			   
			 }
		   if ($event.Id -eq "4625")
			 {
			  $ipv4 = Resolve-DnsName ($eventxml.Event.EventData.Data[2].'#text')
			  $myObject = New-Object System.Object
			  $myObject | Add-Member -type NoteProperty -name "Source Machine" -Value $ipv4.IPAddress
			  $myObject | Add-Member -type NoteProperty -name "Event ID" -Value "4625"
			  $SourceMachines += $myObject
			 }
		  }
		  if ($($Events.count) -eq 0) {
			Write-Host "[Info] Found $($Events.count) Events on $serverName for $UserName" -ForegroundColor Cyan
		  } else { Write-Host "[Warning] Found $($Events.count) Events on $serverName for $UserName" -BackgroundColor Red}
 		  
		  $AllEvents += $Events
		}
	Else 
	   {
		 Write-Host "$serverName is offline" -fore Red
	   }
	}

	# save the report 
	if ($AllEvents -ne 0)
	   { 
		 $AllEvents | Select-Object MachineName,TimeCreated,ProviderName,Id,@{n='Message';e={$_.Message -replace '\s+', " "}} | Export-Csv -Path  $CSVPath -NoTypeInformation
	   }
	if ($($AllEvents.count) -eq 0) {
		Write-Host "[Info] $($AllEvents.count) events found on all domain controllers `n" -ForegroundColor green
	} else { Write-Host "[Warning] $($AllEvents.count) events found on all domain controllers `n" -BackgroundColor Red}
	Write-Verbose "$AllEvents"

	if ($SourceMachines.Count -gt 0 )
	  {
		Write-Host "Summary of source machines for the bad password `n" -BackgroundColor Green -ForegroundColor Red
		$SourceMachines | Group-Object "Source Machine","Event ID"  -NoElement   | Sort-Object -Property Count -Descending
		$ExchangeServersIncluded = Compare-Object -ReferenceObject $SourceMachines."Source Machine"  -DifferenceObject $ExchangeServersIPv4  -IncludeEqual -ExcludeDifferent
		if ($ExchangeServersIncluded.InputObject.Length -gt 0 ) 
		   { 
			 Write-Host "`n Below Exchange Servers included in bad password source machines list `n" -BackgroundColor Green -ForegroundColor Red
			 $ExchangeServersIncluded.InputObject

			 $ExportExchangeLogs = read-host "`nDo you want to export IIS logs from mentioned Exchange servers (Yes/No)" 
			 if ($ExportExchangeLogs = "yes ")
				{
				  foreach ($ip in $ExchangeServersIncluded.InputObject)
					{
					  New-Item -ItemType Directory -Path "$fullpath\Exchange_$ip" -InformationAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null
					  Copy-Item -Path \\$ip\c$\inetpub\logs\LogFiles -Destination "$fullpath\LockoutLogs\Exchange_$ip" -Recurse -Force
					}
				}
		   }
	  }
} # end GetEventsFromAllDCs

# MAIN 
CheckDomainAdmin
CheckDomain
CheckUser
GetEventsFromAllDCs

# SIG # Begin signature block
# MIInvgYJKoZIhvcNAQcCoIInrzCCJ6sCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCV9X7iY0J1Ljw6
# a6UMQsQUWFOX9OJvc0StkGsCFp6826CCDXYwggX0MIID3KADAgECAhMzAAADrzBA
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
# /Xmfwb1tbWrJUnMTDXpQzTGCGZ4wghmaAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAOvMEAOTKNNBUEAAAAAA68wDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEILKNZaCdNULfheYi0zLz0pWU
# 9fWoYnKFq4Oow6vCB3GfMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAdxnTgU1XVWobcBL9z/bvgoLS2umH9nw+ZN564m+tfivA/FXKFoUDq6qe
# 4rnNaxmuQFB1UeQL2mgVXcbFH9hsc1kDoH2h57vdptxxvgsexPx0uNv5GgNyH3Z0
# BO6yM8e3F3O3qt2hvLbq/I7i/tZTHmkcMOG53KxI/1uOVtjuyjk0lVEMdp2Jf13j
# 8UKEQK370OALtnqTAMrnShXqP1KAvcjrrHW7uZ3YkcCfA1zJ/kWXqJbHPs7Mz5vp
# 58SbmmLW6I74lnI3c14ELV0z2YustuVYhWRlUAjWe8F53ebytE+l9ZePIIk+cOgY
# nFsoc1+1mClgLbe+TTBXDfxmS+i6/qGCFygwghckBgorBgEEAYI3AwMBMYIXFDCC
# FxAGCSqGSIb3DQEHAqCCFwEwghb9AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFYBgsq
# hkiG9w0BCRABBKCCAUcEggFDMIIBPwIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCBxtIZgzFm68hFUomkiDVRxga3o5OsI5zB0zx4r03wdsgIGZbqiEEG9
# GBIyMDI0MDIyMDEyMTY1OC4wN1owBIACAfSggdikgdUwgdIxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xLTArBgNVBAsTJE1pY3Jvc29mdCBJcmVs
# YW5kIE9wZXJhdGlvbnMgTGltaXRlZDEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046
# ODZERi00QkJDLTkzMzUxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNl
# cnZpY2WgghF4MIIHJzCCBQ+gAwIBAgITMwAAAd1dVx2V1K2qGwABAAAB3TANBgkq
# hkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yMzEw
# MTIxOTA3MDlaFw0yNTAxMTAxOTA3MDlaMIHSMQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFuZCBPcGVy
# YXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOjg2REYtNEJC
# Qy05MzM1MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNlMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAqE4DlETqLnecdREfiWd8oun7
# 0m+Km5O1y1qKsLExRKs9LLkJYrYO2uJA/5PnYdds3aDsCS1DWlBltMMYXMrp3Te9
# hg2sI+4kr49Gw/YU9UOMFfLmastEXMgcctqIBqhsTm8Um6jFnRlZ0owKzxpyOEdS
# Z9pj7v38JHu434Hj7GMmrC92lT+anSYCrd5qvIf4Aqa/qWStA3zOCtxsKAfCyq++
# pPqUQWpimLu4qfswBhtJ4t7Skx1q1XkRbo1Wdcxg5NEq4Y9/J8Ep1KG5qUujzyQb
# upraZsDmXvv5fTokB6wySjJivj/0KAMWMdSlwdI4O6OUUEoyLXrzNF0t6t2lbRsF
# f0QO7HbMEwxoQrw3LFrAIS4Crv77uS0UBuXeFQq27NgLUVRm5SXYGrpTXtLgIqyp
# HeK0tP2o1xvakAniOsgN2WXlOCip5/mCm/5hy8EzzfhtcU3DK13e6MMPbg/0N3zF
# 9Um+6aOwFBCQrlP+rLcetAny53WcdK+0VWLlJr+5sa5gSlLyAXoYNY3n8pu94WR2
# yhNUg+jymRaGM+zRDucDn64HFAHjOWMSMrPlZbsEDjCmYWbbh+EGZGNXg1un6fvx
# yACO8NJ9OUDoNgFy/aTHUkfZ0iFpGdJ45d49PqEwXQiXn3wsy7SvDflWJRZwBCRQ
# 1RPFGeoYXHPnD5m6wwMCAwEAAaOCAUkwggFFMB0GA1UdDgQWBBRuovW2jI9R2kXL
# IdIMpaPQjiXD8TAfBgNVHSMEGDAWgBSfpxVdAF5iXYP05dJlpxtTNRnpcjBfBgNV
# HR8EWDBWMFSgUqBQhk5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2Ny
# bC9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgxKS5jcmwwbAYI
# KwYBBQUHAQEEYDBeMFwGCCsGAQUFBzAChlBodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpb3BzL2NlcnRzL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAy
# MDEwKDEpLmNydDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMI
# MA4GA1UdDwEB/wQEAwIHgDANBgkqhkiG9w0BAQsFAAOCAgEALlTZsg0uBcgdZsxy
# pW5/2ORRP8rzPIsG+7mHwmuphHbP95o7bKjU6hz1KHK/Ft70ZkO7uSRTPFLInUhm
# SxlnDoUOrrJk1Pc8SMASdESlEEvxL6ZteD47hUtLQtKZvxchmIuxqpnR8MRy/cd4
# D7/L+oqcJBaReCGloQzAYxDNGSEbBwZ1evXMalDsdPG9+7nvEXFlfUyQqdYUQ0nq
# 6t37i15SBePSeAg7H/+Xdcwrce3xPb7O8Yk0AX7n/moGTuevTv3MgJsVe/G2J003
# l6hd1b72sAiRL5QYPX0Bl0Gu23p1n450Cq4GIORhDmRV9QwpLfXIdA4aCYXG4I7N
# OlYdqWuql0iWWzLwo2yPlT2w42JYB3082XIQcdtBkOaL38E2U5jJO3Rh6EtsOi+Z
# lQ1rOTv0538D3XuaoJ1OqsTHAEZQ9sw/7+91hSpomym6kGdS2M5//voMCFXLx797
# rNH3w+SmWaWI7ZusvdDesPr5kJV2sYz1GbqFQMEGS9iH5iOYZ1xDkcHpZP1F5zz6
# oMeZuEuFfhl1pqt3n85d4tuDHZ/svhBBCPcqCqOoM5YidWE0TWBi1NYsd7jzzZ3+
# Tsu6LQrWDwRmsoPuZo6uwkso8qV6Bx4n0UKpjWwNQpSFFrQQdRb5mQouWiEqtLsX
# CN2sg1aQ8GBtDOcKN0TabjtCNNswggdxMIIFWaADAgECAhMzAAAAFcXna54Cm0mZ
# AAAAAAAVMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMDAeFw0yMTA5MzAxODIyMjVaFw0zMDA5MzAxODMyMjVa
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMIICIjANBgkqhkiG9w0BAQEF
# AAOCAg8AMIICCgKCAgEA5OGmTOe0ciELeaLL1yR5vQ7VgtP97pwHB9KpbE51yMo1
# V/YBf2xK4OK9uT4XYDP/XE/HZveVU3Fa4n5KWv64NmeFRiMMtY0Tz3cywBAY6GB9
# alKDRLemjkZrBxTzxXb1hlDcwUTIcVxRMTegCjhuje3XD9gmU3w5YQJ6xKr9cmmv
# Haus9ja+NSZk2pg7uhp7M62AW36MEBydUv626GIl3GoPz130/o5Tz9bshVZN7928
# jaTjkY+yOSxRnOlwaQ3KNi1wjjHINSi947SHJMPgyY9+tVSP3PoFVZhtaDuaRr3t
# pK56KTesy+uDRedGbsoy1cCGMFxPLOJiss254o2I5JasAUq7vnGpF1tnYN74kpEe
# HT39IM9zfUGaRnXNxF803RKJ1v2lIH1+/NmeRd+2ci/bfV+AutuqfjbsNkz2K26o
# ElHovwUDo9Fzpk03dJQcNIIP8BDyt0cY7afomXw/TNuvXsLz1dhzPUNOwTM5TI4C
# vEJoLhDqhFFG4tG9ahhaYQFzymeiXtcodgLiMxhy16cg8ML6EgrXY28MyTZki1ug
# poMhXV8wdJGUlNi5UPkLiWHzNgY1GIRH29wb0f2y1BzFa/ZcUlFdEtsluq9QBXps
# xREdcu+N+VLEhReTwDwV2xo3xwgVGD94q0W29R6HXtqPnhZyacaue7e3PmriLq0C
# AwEAAaOCAd0wggHZMBIGCSsGAQQBgjcVAQQFAgMBAAEwIwYJKwYBBAGCNxUCBBYE
# FCqnUv5kxJq+gpE8RjUpzxD/LwTuMB0GA1UdDgQWBBSfpxVdAF5iXYP05dJlpxtT
# NRnpcjBcBgNVHSAEVTBTMFEGDCsGAQQBgjdMg30BATBBMD8GCCsGAQUFBwIBFjNo
# dHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5o
# dG0wEwYDVR0lBAwwCgYIKwYBBQUHAwgwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBD
# AEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZW
# y4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5t
# aWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAt
# MDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0y
# My5jcnQwDQYJKoZIhvcNAQELBQADggIBAJ1VffwqreEsH2cBMSRb4Z5yS/ypb+pc
# FLY+TkdkeLEGk5c9MTO1OdfCcTY/2mRsfNB1OW27DzHkwo/7bNGhlBgi7ulmZzpT
# Td2YurYeeNg2LpypglYAA7AFvonoaeC6Ce5732pvvinLbtg/SHUB2RjebYIM9W0j
# VOR4U3UkV7ndn/OOPcbzaN9l9qRWqveVtihVJ9AkvUCgvxm2EhIRXT0n4ECWOKz3
# +SmJw7wXsFSFQrP8DJ6LGYnn8AtqgcKBGUIZUnWKNsIdw2FzLixre24/LAl4FOmR
# sqlb30mjdAy87JGA0j3mSj5mO0+7hvoyGtmW9I/2kQH2zsZ0/fZMcm8Qq3UwxTSw
# ethQ/gpY3UA8x1RtnWN0SCyxTkctwRQEcb9k+SS+c23Kjgm9swFXSVRk2XPXfx5b
# RAGOWhmRaw2fpCjcZxkoJLo4S5pu+yFUa2pFEUep8beuyOiJXk+d0tBMdrVXVAmx
# aQFEfnyhYWxz/gq77EFmPWn9y8FBSX5+k77L+DvktxW/tM4+pTFRhLy/AsGConsX
# HRWJjXD+57XQKBqJC4822rpM+Zv/Cuk0+CQ1ZyvgDbjmjJnW4SLq8CdCPSWU5nR0
# W2rRnj7tfqAxM328y+l7vzhwRNGQ8cirOoo6CGJ/2XBjU02N7oJtpQUQwXEGahC0
# HVUzWLOhcGbyoYIC1DCCAj0CAQEwggEAoYHYpIHVMIHSMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMS0wKwYDVQQLEyRNaWNyb3NvZnQgSXJlbGFu
# ZCBPcGVyYXRpb25zIExpbWl0ZWQxJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOjg2
# REYtNEJCQy05MzM1MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2
# aWNloiMKAQEwBwYFKw4DAhoDFQA2I0cZZds1oM/GfKINsQ5yJKMWEKCBgzCBgKR+
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBBQUAAgUA
# 6X7UzjAiGA8yMDI0MDIyMDE1MzU0MloYDzIwMjQwMjIxMTUzNTQyWjB0MDoGCisG
# AQQBhFkKBAExLDAqMAoCBQDpftTOAgEAMAcCAQACAhE7MAcCAQACAhTrMAoCBQDp
# gCZOAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMH
# oSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQEFBQADgYEAXBcL6FihodtRLtVxHb12
# Z0sqBLFd7KGzXe+aQ4tBPFQPMe6ERA5x9zAhiUA9olx3VHoxz9aQJkZevRkHflfD
# YeqcNIPB7WZm4hNoLMW4/FFOooCAjsv0v+SPe5rkY21z80FGuU8zLHeoVGwohMWL
# vVflNPNpgAzbrVtoXO1sOEIxggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1T
# dGFtcCBQQ0EgMjAxMAITMwAAAd1dVx2V1K2qGwABAAAB3TANBglghkgBZQMEAgEF
# AKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEi
# BCDEZVMUoF5ZYgDCdZsD0fYVHv65a+TCnY4QfjyrCh5kkzCB+gYLKoZIhvcNAQkQ
# Ai8xgeowgecwgeQwgb0EIGH/Di2aZaxPeJmce0fRWTftQI3TaVHFj5GI43rAMWNm
# MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEm
# MCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAHdXVcd
# ldStqhsAAQAAAd0wIgQgD/HnIWMN/YRMoADZ2halkeeXdew6oPfVzAx8q/Ws09kw
# DQYJKoZIhvcNAQELBQAEggIAVlZhNr2TlmBShFCr3uLHZ4PVjCXM0797eEde6GIv
# Zh1NBXms1lwIAHvtw19UXq3UQYcST1bsfwYdrogcj23S4uuWevkzxYOxviwGEcZM
# 2jkSiZfHQvfYJEPBDzPLVuHjpzeyZLicYohcAKAhwjEc5bTWM8Xq22J4HowObulf
# 4li3toJd9cODGL9rEZqbW+z9bwe+6L0GQIn8TtL3DFzIEGWT8fFNYQ6J+l87kyaw
# I+/N01oaUSXpWV3EPN17SVeDRHdXbvekcOEVrUR9st6k7r2Ig3p2fIaLeS/Qpr7C
# apQLpwl5etrrpEuaXDVW10V6nSHpI86C/JcKv2z7rv60XCntLVpVCE+u66b4eSxJ
# yy+NQQ+2vy4MuXn7lGfQiusVtsenZvjsHofolH9oS0n3/4Tv9BprAjkQOqin9oru
# uRYueRVs7W7WOTV9e4useH+LOfNjSH2pxty+f+05VPRKXEGv1XTdb/nJhlMbmPmk
# fg4InETmmG8ifW5usI7imJ15FUaMYib+Xmr9APDUOC8F0jLNHGRnhPiymjhvZyWT
# zbCkQknr0poBTRUAk6o2y0sSBuZK8ykkLf5oMCGjdXdpy2N0toBAwQyA5j5kmo1g
# 5drfKJx0VLNEQX9D2LShkJSVtJYK4Fw6+zi/oeLEw0CIy9NfM4QjEx39p8mlI9hH
# 0WQ=
# SIG # End signature block
