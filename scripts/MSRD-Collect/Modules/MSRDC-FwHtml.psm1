<#
.SYNOPSIS
   MSRD-Collect HTML functions

.DESCRIPTION
   Module for the MSRD-Collect html functions

.NOTES
   Author     : Robert Klemencz
   Requires   : At least PowerShell 5.1 (This module is not for stand-alone use. It is used automatically from within the main MSRD-Collect.ps1 script)
   Version    : See MSRD-Collect.ps1 version
   Feedback   : https://aka.ms/MSRD-Collect-Feedback
#>


#region HTML functions

Function msrdHtmlInit {
    param ($htmloutfile)

    #html report initialization
    msrdCreateLogFolder $global:msrdLogDir

    New-Item -Path $htmloutfile -ItemType File | Out-Null

    Set-Content $htmloutfile "<!DOCTYPE html>
<html>"
}

Function msrdHtmlHeader {
    param ($htmloutfile, $title, $fontsize)

    #html report header
Add-Content $htmloutfile "<head>
    <title>$title</title>
</head>
<style>
    .table-container { position: fixed; width: 100%; top: 0; left: 0; z-index: 1; background-color: white; }
    .WUtable-container { position: relative; display: inline-block; width: 100%; }
    BODY { font-family: Arial, Helvetica, sans-serif; font-size: $fontsize; }
    table { background-color: white; border: none; width: 100%; padding-left: 5px; padding-right: 5px; padding-bottom: 5px; }
    td { word-break: break-all; border: none; }
    th { border-bottom: solid 1px #CCCCCC; }

    .tduo { border: 1px solid #BBBBBB; background-color: white; vertical-align:top; border-radius: 5px; box-shadow: 1px 1px 2px 3px rgba(12,12,12,0.2); }
    .tduo tr:hover { background-color: #BBC3C6; }

    details > summary { background-color: #7D7E8C; color: white; cursor: pointer; padding: 5px; border:1px solid #BBBBBB; text-align: left; font-size: 13px; border-radius: 5px; }
    .detailsP { padding: 5px 5px 10px 15px; }

    .scroll { padding-top: 140px; box-sizing: border-box; }

    .cText { padding-left: 5px; }
    .cTable1-2 { padding-left: 5px; width: 12%; }
    .cTable1-3 { padding-left: 5px; width: 12%; }
    .cTable1-3b { width: 53%; }
    .cTable2-1 { padding-left: 5px; width: 65%; }
    .b2top a { color:white; float:right; text-decoration: none; }
    .menubutton { width: 150px; cursor: pointer; filter: drop-shadow(3px 3px 1px rgba(0, 0, 0, 0.25)) }

    .circle_green { vertical-align:top; padding-left: 5px; border: 1px solid #a1a1a1; padding: 5px 3px; background: #009933; border-radius: 100%; width: 5px; heigth: 5px }
    .circle_red { vertical-align:top; padding-left: 5px; border: 1px solid #a1a1a1; padding: 5px 3px; background: red; border-radius: 100%; width: 5px; heigth: 5px }
    .circle_blue { vertical-align:top; padding-left: 5px; border: 1px solid #a1a1a1; padding: 5px 3px; background: blue; border-radius: 100%; width: 5px; heigth: 5px }
    .circle_white { vertical-align:top; padding-left: 5px; border: 1px solid #a1a1a1; padding: 5px 3px; background: white; border-radius: 100%; width: 5px; heigth: 5px }
    .circle_no { vertical-align:top; padding-left: 5px; border: 1px solid white; padding: 5px 3px; background: white; border-radius: 100%; width: 5px; heigth: 5px }

    .circle_redCounter { display: inline-block; vertical-align: middle; width: 10px; height: 10px; border-radius: 50%; background-color: red; border: 1px solid #a1a1a1; margin-bottom: 2px; }

    .dropdown-wrapper { background-color: white; position: fixed; cursor: pointer; display: flex; align-items: center; flex-direction: column; left: 50%; transform: translateX(-50%); width: 100%; margin: 0 auto; padding-bottom: 10px; padding-top: 5px;}
    .dropdown { position: relative; margin-right: 5px; }
	.dropdown button { background-color: #7D7E8C; color: #fff; border: none; border-radius: 5px; padding: 8px 14px; line-height: 14px; cursor: pointer; transition: background-color 0.3s; }
	.dropdown-content { display: none; position: absolute; background-color: #fff; min-width: 160px; box-shadow: 0px 8px 16px 0px rgba(0,0,0,0.2); z-index: 1; white-space: nowrap; }
	.dropdown-content a { padding: 10px; text-decoration: none; display: block; color: #000; }
    .dropdown:hover button { background-color: #5b5b5b; }
    .dropdown:hover .dropdown-content { display: block; }
    .dropdown:hover .dropdown-content a:hover { background-color: #BBC3C6; color: #000; }
    .dropdown:last-child { margin-right: 0; }

    .buttons-container { display: flex; justify-content: center; flex-wrap: wrap; }
    .text-container { text-align: center; margin-top: 5px; }
    .right-aligned-text { text-align: right; width: 100%; margin-right: 50px; }

    .legend-item { margin-bottom: 5px; }
    .circle { width: 10px; height: 10px; display: inline-block; margin-right: 5px; border-radius: 100%; }
    .green { background-color: green; border: 1px solid #a1a1a1; }
    .blue { background-color: blue; border: 1px solid #a1a1a1; }
    .red { background-color: red; border: 1px solid #a1a1a1; }
    .white { background-color: white; border: 1px solid #a1a1a1; }
    .info { background-color: transparent; }

    .circle-with-content { width: 10px; height: 10px; display: inline-block; margin-right: 5px; border-radius: 100%; position: relative; border: 1px solid #a1a1a1; }
    .circle-with-content::before { content: 'i'; font-size: 10px; color: #a1a1a1; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); }

    .legend-container { position: fixed; z-index: 1; display: none; width: 450px; padding: 10px; background-color: #fff; border: 1px solid #ccc; text-align: left; }
    .hide-show-all { display: inline-block; }
</style>"
}

Function msrdHtmlMenu {
    Param ($htmloutfile, [string]$CatText, [System.Collections.Generic.Dictionary[String,String]]$BtnTextAndId)

    Add-Content $htmloutfile "<div class='dropdown'><button>$CatText</button><div class='dropdown-content'>"

    foreach ($txt in $BtnTextAndId.GetEnumerator()) {
        $btnLink = $txt.Value
        $btnText = $txt.Key
        Add-Content $htmloutfile "<a href='$btnLink'>$btnText</a>"
    }

    Add-Content $htmloutfile "</div></div>"

}

Function msrdHtmlBodyDiag {
    Param ($htmloutfile, $title, [bool[]]$varsSystem, [bool[]]$varsAVDRDS, [bool[]]$varsInfra, [bool[]]$varsAD, [bool[]]$varsNET, [bool[]]$varsLogSec, [bool[]]$varsIssues, [bool[]]$varsOther)

    #html report body
    Add-Content $htmloutfile "
<body>
    <div class='table-container'>
        <div style='text-align:center;'><a name='TopDiag'></a><b><h3>$title</h3></b></div>
        <div class='dropdown-wrapper'>
            <div class='buttons-container'>
"

#region menu
    #system

    if ($true -in $varsSystem) {
        $BtnsSystem = [System.Collections.Generic.Dictionary[String,String]]@{}

        if ($varsSystem[0]) { $BtnsSystem.Add("Core", "#DeploymentCheck") }
        if ($varsSystem[1]) { $BtnsSystem.Add("CPU Utilization and Handles", "#CPUCheck") }
        if ($varsSystem[2]) { $BtnsSystem.Add("Drives", "#DiskCheck") }
        if ($varsSystem[3]) { $BtnsSystem.Add("Graphics", "#GPUCheck") }
        if (!($global:msrdSource)) { if ($varsSystem[4]) { $BtnsSystem.Add("OS Activation / Licensing", "#KMSCheck") } }
        if ($varsSystem[5]) { $BtnsSystem.Add("SSL / TLS", "#SSLCheck") }
        if ($varsSystem[6]) { $BtnsSystem.Add("User Account Control", "#UACCheck") }
        if ($varsSystem[7]) { $BtnsSystem.Add("Windows Installer", "#InstallerCheck") }
        if (!($global:msrdSource)) { if ($varsSystem[8]) { $BtnsSystem.Add("Windows Search", "#SearchCheck") } }
        if ($varsSystem[9]) { $BtnsSystem.Add("Windows Update", "#WUCheck") }
        if ($varsSystem[10]) { $BtnsSystem.Add("WinRM / PowerShell", "#WinRMPSCheck") }

        msrdHtmlMenu -htmloutfile $htmloutfile -CatText "System" -BtnTextAndId $BtnsSystem
    }

    #avd/rds/w365
    if ($true -in $varsAVDRDS) {
        $BtnsAVDRDS = [System.Collections.Generic.Dictionary[String,String]]@{}

        if ($varsAVDRDS[0]) { $BtnsAVDRDS.Add("Device and Resource Redirection", "#RedirCheck") }
        if (!($global:msrdSource)) { if ($varsAVDRDS[1]) { $BtnsAVDRDS.Add("FSLogix", "#ProfileCheck") } }
        if ($varsAVDRDS[2]) { $BtnsAVDRDS.Add("Multimedia", "#MultiMedCheck") }
        if ($varsAVDRDS[3]) { $BtnsAVDRDS.Add("Quick Assist / Remote Help", "#QACheck") }
        if (!($global:msrdSource)) {
            if ($varsAVDRDS[4]) { $BtnsAVDRDS.Add("RDP / Listener", "#ListenerCheck") }
            if ($global:msrdOSVer -like "*Windows Server*") {
                if ($varsAVDRDS[5]) { $BtnsAVDRDS.Add("RDS Roles", "#RolesCheck") }
            }
        }
        if ($varsAVDRDS[6]) { $BtnsAVDRDS.Add("Remote Desktop Clients", "#RDCCheck") }
        if (!($global:msrdSource)) {
            if (!($global:msrdW365)) {
                if ($varsAVDRDS[7]) { $BtnsAVDRDS.Add("Remote Desktop Licensing", "#LicCheck") }
            }
            if ($varsAVDRDS[8]) { $BtnsAVDRDS.Add("Session Time Limits", "#STLCheck") }
        }
        if (!($global:msrdRDS)) {
            if ($varsAVDRDS[9]) { $BtnsAVDRDS.Add("Teams Media Optimization", "#TeamsCheck") }
        }
        if ($global:msrdW365) {
            if ($varsAVDRDS[10]) { $BtnsAVDRDS.Add("Windows 365 Boot", "#CPCCheck") }
        }

        if ($global:msrdRDS) {
            msrdHtmlMenu -htmloutfile $htmloutfile -CatText "RDS" -BtnTextAndId $BtnsAVDRDS
        } elseif ($global:msrdAVD) {
            msrdHtmlMenu -htmloutfile $htmloutfile -CatText "AVD/RDS" -BtnTextAndId $BtnsAVDRDS
        } elseif ($global:msrdW365) {
            msrdHtmlMenu -htmloutfile $htmloutfile -CatText "AVD/RDS/W365" -BtnTextAndId $BtnsAVDRDS
        }
    }

    #avd infra
    if (!($global:msrdRDS)) {
        if ($true -in $varsInfra) {
            $BtnsAVDInfra = [System.Collections.Generic.Dictionary[String,String]]@{}

            if (!($global:msrdSource)) {
                if ($varsInfra[0]) { $BtnsAVDInfra.Add("AVD Host Pool", "#HPCheck") }
                if ($varsInfra[1]) { $BtnsAVDInfra.Add("AVD Agents / SxS Stack", "#AgentStackCheck") }
                if ($varsInfra[2]) { $BtnsAVDInfra.Add("AVD Health Check", "#AVDHealthCheck") }
            }
            if ($varsInfra[3]) { $BtnsAVDInfra.Add("AVD Required Endpoints", "#URLCheck") }

            if (!($global:msrdSource)) {
                if ($varsInfra[4]) { $BtnsAVDInfra.Add("AVD Services URI Health", "#BrokerURICheck") }
            }
            if ($global:msrdAVD -and !($global:msrdSource)) {
                if ($varsInfra[5]) { $BtnsAVDInfra.Add("Azure Stack HCI", "#HCICheck") }
            }
            if ($varsInfra[6]) { $BtnsAVDInfra.Add("RDP Shortpath", "#UDPCheck") }
            if ($global:msrdW365) {
                if ($varsInfra[7]) { $BtnsAVDInfra.Add("Windows 365 Required Endpoints", "#CPCreqUrlsCheck") }
            }

            if ($global:msrdW365) {
                msrdHtmlMenu -htmloutfile $htmloutfile -CatText "AVD/W365 Infra" -BtnTextAndId $BtnsAVDInfra
            } else {
                msrdHtmlMenu -htmloutfile $htmloutfile -CatText "AVD Infra" -BtnTextAndId $BtnsAVDInfra
            }
        }
    }

    #ad
    if ($true -in $varsAD) {
        $BtnsAD = [System.Collections.Generic.Dictionary[String,String]]@{}

        if ($varsAD[0]) { $BtnsAD.Add("Microsoft Entra Join", "#AADJCheck") }
        if ($varsAD[1]) { $BtnsAD.Add("Domain", "#DCCheck") }

        msrdHtmlMenu -htmloutfile $htmloutfile -CatText "Active Directory" -BtnTextAndId $BtnsAD
    }

    #networking
    if ($true -in $varsNET) {
        $BtnsNet = [System.Collections.Generic.Dictionary[String,String]]@{}

        if ($varsNET[0]) { $BtnsNet.Add("Core NET", "#NWCCheck") }
        if ($varsNET[1]) { $BtnsNet.Add("DNS", "#DNSCheck") }
        if ($varsNET[2]) { $BtnsNet.Add("Firewall", "#FWCheck") }
        if ($varsNET[3]) { $BtnsNet.Add("IP Addresses", "#PublicIPCheck") }
        if ($varsNET[4]) { $BtnsNet.Add("Port Usage", "#PortUsageCheck") }
        if ($varsNET[5]) { $BtnsNet.Add("Proxy", "#ProxCheck") }
        if ($varsNET[6]) { $BtnsNet.Add("Routing", "#RoutingCheck") }
        if ($varsNET[7]) { $BtnsNet.Add("VPN", "#VPNCheck") }

        msrdHtmlMenu -htmloutfile $htmloutfile -CatText "Networking" -BtnTextAndId $BtnsNet
    }

    #logon/security
    if ($true -in $varsLogSec) {
        $BtnsLogSec = [System.Collections.Generic.Dictionary[String,String]]@{}

        if ($varsLogSec[0]) { $BtnsLogSec.Add("Authentication / Logon", "#AuthCheck") }
        if ($varsLogSec[1]) { $BtnsLogSec.Add("Security", "#SecCheck") }

        msrdHtmlMenu -htmloutfile $htmloutfile -CatText "Logon / Security" -BtnTextAndId $BtnsLogSec
    }

    #known issues
    if ($true -in $varsIssues) {
        $BtnsIssues = [System.Collections.Generic.Dictionary[String,String]]@{}

        if ($varsIssues[0]) { $BtnsIssues.Add("Issues found in Event Logs over the past 5 days", "#IssuesCheck") }
        if (!($global:msrdSource)) { if ($varsIssues[1]) { $BtnsIssues.Add("Potential Logon/Logoff Issue Generators", "#BlackCheck") } }

        msrdHtmlMenu -htmloutfile $htmloutfile -CatText "Known Issues" -BtnTextAndId $BtnsIssues
    }

    #other
    if ($true -in $varsOther) {
        $BtnsOther = [System.Collections.Generic.Dictionary[String,String]]@{}

        if (!($global:msrdSource)) {
            if ($varsOther[0]) { $BtnsOther.Add("Office", "#MSOCheck") }
            if ($varsOther[1]) { $BtnsOther.Add("OneDrive", "#MSODCheck") }
        }
        if ($varsOther[2]) { $BtnsOther.Add("Printing", "#PrintCheck") }
        if ($varsOther[3]) { $BtnsOther.Add("Third Party Software", "#3pCheck") }

        msrdHtmlMenu -htmloutfile $htmloutfile -CatText "Other" -BtnTextAndId $BtnsOther
    }
#endregion menu

Add-Content $htmloutfile "
            </div>

            <div class='right-aligned-text'>
                <span class='legend-label' id='legend-label'>Legend</span> | <div class='hide-show-all'><a href='#/' id='expAll' class='col' title='Hide/Show all categories'>Hide/Show All</a></div>
                <div class='legend-container' id='legend-container'>
                    <div class='legend-item'><span class='circle green'></span> Expected value/status</div>
                    <div class='legend-item'><span class='circle blue'></span> Value/status should be evaluated for relevance</div>
                    <div class='legend-item'><span class='circle red'></span> Value/status is unexpected, problematic or might cause problems in certain circumstances</div>
                    <div class='legend-item'><span class='circle white'></span> Value/status not found or generic information</div>
                    <div class='legend-item'><span class='circle-with-content info'></span> Hover over the icon with the mouse cursor for additional information</div>
                </div>
            </div>
        </div>
    </div>
    <div class='scroll'>
        <table>
            <tr><td>"
}

Function msrdHtmlBodyWU {
    Param ($htmloutfile, $title)

	Add-Content $htmloutfile "<body>
	<div class='WUtable-container'>
	<table>
		<tr><td style='text-align:center; padding-bottom: 10px;' colspan='6'><a name='TopDiag'></a><b><h2>$title</h2></b>

			<table>
				<tr>
					<td style='text-align:center;'><a href='#COM'><button class='menubutton'>Updates (COM)</button></a>&nbsp;
					<a href='#QFE'><button class='menubutton'>Other (QFE)</button></a>&nbsp;
					<a href='#REG'><button class='menubutton'>Other (Registry)</button></a></td>
				</tr>
			</table>
		</td></tr>

	<tr><td style='text-align:left; font-size: 13px; padding-bottom: 5px'><b>Operating System: $global:msrdGetos</b></td><td align='right' style='height:5px;'><a href='#/' id='expAll' class='col'>Hide/Show All</a></td></tr>
	<tr><td colspan='2'>
	<details open>
		<summary>
			<a name='COM'></a><b>Microsoft.Update.Session</b><span class='b2top'><a href='#'>^top</a></span>
		</summary>
		<div class='detailsP'>
			<table class='tduo'>
				<tr style='text-align: left;'>
					<th width='10px'><div class='circle_no'></div></th><th style='padding-left: 5px;'>Category</th><th>Date/Time</th><th>Operation</th><th>Result</th><th>KB</th><th>Description</th>
				</tr>
	"
}

Function msrdHtmlEnd {
    Param ($htmloutfile)

    $dateTime = Get-Date
    $dateOnly = $dateTime.ToString("MMMM d, yyyy")
    $timeOnly = $dateTime.ToString("h:mm:ss tt")

    #html report footer
    Add-Content $htmloutfile "</tbody></table></div></details>
        </td></tr>
    </table>
    </div>

    <script type='text/javascript'>
        const xa = document.getElementById('expAll');

        xa.addEventListener('click', function(e) {
            e.currentTarget.classList.toggle('exp');
            e.currentTarget.classList.toggle('col');

            const details = document.querySelectorAll('details');

            Array.from(details).forEach(function(obj, idx) {
                if (e.currentTarget.classList.contains('exp')) {
                    obj.removeAttribute('open');
                } else {
                    obj.open = true;
                }
            });
        }, false);
    </script>

  <script>
    // Get elements
    var legendLabel = document.getElementById('legend-label');
    var legendContainer = document.getElementById('legend-container');

    // Show the legend container on hover and update its position
    legendLabel.addEventListener('mouseover', function(event) {
      legendContainer.style.display = 'block';
      updateLegendPosition(event);
    });

    // Hide the legend container on mouseout
    legendLabel.addEventListener('mouseout', function() {
      legendContainer.style.display = 'none';
    });

    // Update legend container position based on mouse coordinates
    function updateLegendPosition(event) {
      var x = event.clientX + 10; // Add an offset to prevent the popup from overlapping with the cursor
      var y = event.clientY + 10;

      // Adjust x position to ensure the popup stays within the visible area
      var maxX = window.innerWidth - legendContainer.clientWidth;
      x = Math.min(x, maxX);

      legendContainer.style.left = x + 'px';
      legendContainer.style.top = y + 'px';
    }

    // Update legend position on mousemove
    legendLabel.addEventListener('mousemove', function(event) {
      updateLegendPosition(event);
    });
  </script>

    <footer style='padding: 10px; font-size: 11px;'><i>Report finished on $dateOnly at $timeOnly - Script version $msrdVersion (Get the latest version from <a href='https://aka.ms/MSRD-Collect' target='_blank'>https://aka.ms/MSRD-Collect</a> - For any feedback use <a href='https://aka.ms/MSRD-Collect-Survey' target='_blank'>https://aka.ms/MSRD-Collect-Survey</a> or email <a href='mailto:MSRDCollectTalk@microsoft.com?subject=MSRD-Collect%20Feedback'>MSRDCollectTalk@microsoft.com</a>)</i><br>
    </footer>
    </body>
</html>"
}

Function msrdHtmlSetMenuWarning {
    param ($MenuCat, $MenuItem, $htmloutfile)

    #html report menu item warning
    if (Test-Path -path $htmloutfile) {

        $msrdDiagFileContent = Get-Content -Path $htmloutfile
        $msrdDiagFileReplace = foreach ($diagItem in $msrdDiagFileContent) {
            if ($diagItem -match "(.*>$MenuItem</a>)$") {
                $diagItem -replace $MenuItem, "$MenuItem <span style='color: red;'>&#9888;</span>"
            } elseif ($diagItem -match "(.*<button>$MenuCat</button>.*)") {
                $diagItem -replace $MenuCat, "$MenuCat <span style='color: red;'>&#9888;</span>"
            } else {
                $diagItem
            }
        }
        $msrdDiagFileReplace | Set-Content -Path $htmloutfile
    }
}

Function msrdHtmlSetIssueCounter {
    param ($htmloutfile)

    if (Test-Path -path $htmloutfile) {

        if ($global:msrdIssueCounter -gt 0) {
            if ($global:msrdIssueCounter -eq 1) {
                $info = "<div class='text-container'><span style='color: red;'>$global:msrdIssueCounter</span> source of potential problems has been identified.<br>See the menu item with a red exclamation mark [<span style='color: red;'>&#9888;</span>] and the corresponding line marked with a red circle [<span class='circle_redCounter'></span>]</div>"
            } elseif ($global:msrdIssueCounter -gt 1) {
                $info = "<div class='text-container'><span style='color: red;'>$global:msrdIssueCounter</span> sources of potential problems have been identified.<br>See the menu items with a red exclamation mark [<span style='color: red;'>&#9888;</span>] and the corresponding lines marked with a red circle [<span class='circle_redCounter'></span>]</div>"
            }

            $msrdDiagFileContent = Get-Content -Path $htmloutfile
            $msrdDiagFileReplace = foreach ($diagItem in $msrdDiagFileContent) {
                if ($diagItem -match "<div class='right-aligned-text'>") {
                    $diagItem -replace $diagItem, "$info $diagItem"
                } else {
                    $diagItem
                }
            }
            $msrdDiagFileReplace | Set-Content -Path $htmloutfile
        }
    }
}

#endregion HTML functions

Export-ModuleMember -Function *

# SIG # Begin signature block
# MIInvwYJKoZIhvcNAQcCoIInsDCCJ6wCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAN57tbGrFCoVNj
# /tmxYG6c48EXaR65/nodKPevC0OOCaCCDXYwggX0MIID3KADAgECAhMzAAADrzBA
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
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEICdXJekXBh3RtPMY2p3MpB0L
# TTY9Uq6kdd1WYQe21RKVMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAQHj7dXq8YBDP6SUikuQxg/bDOGyhb6xd2TPoOlvf+DjrDX4mJG8XEjAg
# vEJGVk35gHcA3TZQtEvfmKWPK4rCqmXeqbKB1pWD8/uhkX+1H+7dLO6NUBzf8yld
# XTcHjA8Pxfj3CJfKmUUnM0DX4UL6wE1C6KmsF6W4ozwSWiBAMPuaRmyS761Rbf+z
# zf7+UYAOumZSI5qL6mBpvGBXz2s9/624Ti5X65rAFAc8ODCN6xM4vJMELQKvgzV/
# dueXEl0JHz2W0Nb34/NJZmMMSIK8aJkyGPJDiHP5eHXvq3MS4eu0g5FbEHfyQMXc
# 2HfeAfpdUc7P4uxYGzqbAsN0YIyxuKGCFykwghclBgorBgEEAYI3AwMBMYIXFTCC
# FxEGCSqGSIb3DQEHAqCCFwIwghb+AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsq
# hkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCD96MdJZe1/V7k7EOwV/zOh3iAr8Qj0kiQTdSKbDnUbMwIGZbql3kaE
# GBMyMDI0MDIyMDEyMTY1OC44MTVaMASAAgH0oIHYpIHVMIHSMQswCQYDVQQGEwJV
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
# IgQg34Deslcm0LBTdEXZ0EPpjUz1+gd4q1Mjsd22na3+ZSEwgfoGCyqGSIb3DQEJ
# EAIvMYHqMIHnMIHkMIG9BCAriSpKEP0muMbBUETODoL4d5LU6I/bjucIZkOJCI9/
# /zCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB4pmZ
# lfHc4yDrAAEAAAHiMCIEINj9jjwk1TLFNQu7Sl1tdDvaw/Ukh0QzLxJqZLRW9zR8
# MA0GCSqGSIb3DQEBCwUABIICAITW2winuSx5bx6v57ghcctfR3qpcKCnbe7zPsj2
# XLYcCChr+tEhggLlRhD8cGAww0bTKJDSPRgRKBZxPgOqNJWwlAZSemJQV5OxCvRW
# NP0FZbRAW1bs3rX6YgAiqCQUwWSapPc7DzahBKpAIPfV53blOs4p9z6nZJ/EKaCx
# rpOCSlPSX49vGbyO3tW5w0tPrZCHJs8GdA1HMDvKefB62WeXAloyfTQ5V/bY6Bzk
# PDEwnOQZw2z51nQSfTAhYEyFMjmLcdUC4K+OqzsKPfBr5VW2r6JBk77tyQ/d5Jlo
# d8py96ENYXOBXXO1YSySzIV9M2+cFOOnjriDMuIR5eGds+Pmy53pBjg6xD56wGYc
# u3gzuSRVt7NrhSeYWZM1OnzMjKTHvJo9u6irBDFdMZlWp/rxTlrfUOX5tkO/5Qe4
# 9vNLp3djsTW7JVQLKys+tOSabIVOHf2TSNw7356CWJqiOnn+D/pfOyjRCiwVeMd5
# 3nqa9flhhsJ4DrmxLMzJrGZBSqZYtB59OXmMycaxaBrnt1XUPcSFHZYsYukvS649
# R8GvEeCdv817xcheRfSL6kOpS21o3IbHTdf12jTUqmLsovC+abfJt7y/coXfgae9
# tHFNQi8s4j9ecTNOuZ85FcRk19XJuBm+2Gl4wYO6wItXSmQXTeCn4Nz3lbFOEYk0
# IhIb
# SIG # End signature block
