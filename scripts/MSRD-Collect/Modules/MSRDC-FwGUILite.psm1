<#
.SYNOPSIS
   MSRD-Collect graphical user interface (Lite version)

.DESCRIPTION
   Module for the MSRD-Collect graphical user interface (Lite version)

.NOTES
   Author     : Robert Klemencz
   Requires   : At least PowerShell 5.1 (This module is not for stand-alone use. It is used automatically from within the main MSRD-Collect.ps1 script)
   Version    : See MSRD-Collect.ps1 version
   Feedback   : https://aka.ms/MSRD-Collect-Feedback
#>

#region config variables
$script:varsCore = @(,$true * 12)
$script:vCore = $script:varsCore

$script:varsProfiles = @(,$true * 4)
$script:varsActivation = @(,$true * 3)
$script:varsMSRA = @(,$true * 6)
$script:varsSCard = @(,$true * 3)
$script:varsIME = @(,$true * 2)
$script:varsTeams = @(,$true * 3)
$script:varsMSIXAA = @(,$true * 1)
$script:varsHCI = @(,$true * 1)

$script:varsNO = $false

$script:varsSystem = @(,$true * 11)
$script:varsAVDRDS = @(,$true * 11)
$script:varsInfra = @(,$true * 8)
$script:varsAD = @(,$true * 2)
$script:varsNET = @(,$true * 8)
$script:varsLogSec = @(,$true * 2)
$script:varsIssues = @(,$true * 2)
$script:varsOther = @(,$true * 4)

$script:dumpProc = $False; $script:pidProc = ""
$script:traceNet = $False; $global:onlyDiag = $false
#endregion config variables


#region GUI functions

function msrdStartBtnCollect {
    if (-not $global:btnTeamsClick) {
        $TeamsLogs = msrdGetLocalizedText "teamsnote"
        $wshell = New-Object -ComObject Wscript.Shell
        $teamstitle = msrdGetLocalizedText "teamstitle"
        $answer = $wshell.Popup("$TeamsLogs",0,"$teamstitle",5+48)
        if ($answer -eq 4) { $GetTeamsLogs = $false } else { $GetTeamsLogs = $true }
    } else {
        $GetTeamsLogs = $false
    }

    if (($true -in $script:varsCore) -and (-not $global:msrdRDS)) { msrdCloseMSRDC }

    if (-not $GetTeamsLogs) {
        msrdInitFolders

        $btnStart.Text = msrdGetLocalizedText "Running"
        if (-not $global:onlyDiag) {
            $global:msrdStatusBarLabel.Text = msrdGetLocalizedText "rdcmsg"
        } else {
			$global:msrdStatusBarLabel.Text = msrdGetLocalizedText "rdiagmsg"
		}

        msrdLogMessage $LogLevel.InfoLogFileOnly "$(msrdGetLocalizedText initvalues1a) $global:msrdVersion $(msrdGetLocalizedText initvalues1b) $global:msrdScriptpath ($global:msrdAdminlevel)"
        msrdLogMessage $LogLevel.InfoLogFileOnly "$(msrdGetLocalizedText initvalues1c) $global:msrdCmdLine"
        msrdLogMessage $LogLevel.InfoLogFileOnly "$(msrdGetLocalizedText initvalues2)"
        msrdLogMessage $LogLevel.InfoLogFileOnly "$(msrdGetLocalizedText initvalues3) $global:msrdLogRoot"
        msrdLogMessage $LogLevel.InfoLogFileOnly "$(msrdGetLocalizedText initvalues4) $global:msrdUserprof`n"
        msrdLogMessage $LogLevel.InfoLogFileOnly "$(msrdGetLocalizedText dpidtext3) $script:pidProc"

        $selectedScenarios = @()

        $checkboxes = @(
            $TbAVD, $TbRDS, $TbW365,
            $TbSource, $TbTarget,
            $TbCore, $TbProfiles, $TbActivation, $TbMSRA, $TbSCard, $TbIME, $TbTeams, $TbMSIXAA, $TbHCI, $TbProcDump, $TbNetTrace, $TbDiagOnly
        )

        foreach ($checkbox in $checkboxes) {
            if ($checkbox.Checked) {
                $selectedScenarios += $checkbox.Text
            }
        }

        $selectedScenariosString = $selectedScenarios -join ", "

        msrdLogMessage $LogLevel.InfoLogFileOnly "Selected parameters for data collection/diagnostics: $selectedScenariosString`n"

        if (-not $global:onlyDiag) {
            #data collection
            $parameters = @{
                varsCore = $script:vCore
                varsProfiles = $script:vProfiles
                varsActivation = $script:vActivation
                varsMSRA = $script:vMSRA
                varsSCard = $script:vSCard
                varsIME = $script:vIME
                varsTeams = $script:vTeams
                varsMSIXAA = $script:vMSIXAA
                varsHCI = $script:vHCI
                traceNet = $script:traceNet
                dumpProc = $script:dumpProc
                pidProc = $script:pidProc
            }
            msrdCollectData @parameters
        }

        #diagnostics
        $parameters = @{
            varsSystem = $script:varsSystem
            varsAVDRDS = $script:varsAVDRDS
            varsInfra = $script:varsInfra
            varsAD = $script:varsAD
            varsNET = $script:varsNET
            varsLogSec = $script:varsLogSec
            varsIssues = $script:varsIssues
            varsOther = $script:varsOther
        }
        msrdCollectDataDiag @parameters

        $global:msrdStatusBarLabel.Text = msrdGetLocalizedText "archmsg"
        msrdArchiveData -varsCore $script:vCore
        $btnStart.Text = msrdGetLocalizedText "Start"
        $global:msrdStatusBarLabel.Text = msrdGetLocalizedText "Ready"
    }
}

Function msrdInitMachines {
    param ([bool[]]$Machine = @($false, $false, $false))

    if ($Machine[0]) { $global:msrdAVD = $true; $global:msrdRDS = $False; $global:msrdW365 = $False }
    elseif ($Machine[1]) { $global:msrdAVD = $False; $global:msrdRDS = $true; $global:msrdW365 = $False }
    elseif ($Machine[2]) { $global:msrdAVD = $False; $global:msrdRDS = $False; $global:msrdW365 = $true }
    else { $global:msrdAVD = $false; $global:msrdRDS = $false; $global:msrdW365 = $False }
}

Function msrdInitRoles {
    param ([bool[]]$Role = @($false, $false))

    if ($Role[0]) { $global:msrdSource = $true; $global:msrdTarget = $False }
    elseif ($Role[1]) { $global:msrdSource = $False; $global:msrdTarget = $true }
    else {
        $global:msrdSource = $false; $global:msrdTarget = $false
    }
}

Function msrdShowHideItems {
    param ($category, $show=$false)

    if ($category -eq "Role") {
        if ($show) {
			$roleLabel.Visible = $true; $btnSource.Visible = $true; $btnTarget.Visible = $true
            $scenarioLabel.Visible = $false; $btnCore.Visible = $false; $btnDiagOnly.Visible = $false
            $btnProfiles.Visible = $false; $btnActivation.Visible = $false; $btnMSRA.Visible = $false; $btnSCard.Visible = $false; $btnIME.Visible = $false; $btnTeams.Visible = $false; $btnMSIXAA.Visible = $false; $btnHCI.Visible = $false
            $btnStart.Visible = $false
		} else {
			$roleLabel.Visible = $false; $btnSource.Visible = $false; $btnTarget.Visible = $false
            $scenarioLabel.Visible = $false; $btnCore.Visible = $false; $btnDiagOnly.Visible = $false
            $btnProfiles.Visible = $false; $btnActivation.Visible = $false; $btnMSRA.Visible = $false; $btnSCard.Visible = $false; $btnIME.Visible = $false; $btnTeams.Visible = $false; $btnMSIXAA.Visible = $false; $btnHCI.Visible = $false
            $btnStart.Visible = $false
		}
    } elseif ($category -eq "Scenario") {
		if ($show) {
            $scenarioLabel.Visible = $true; $btnCore.Visible = $true; $btnDiagOnly.Visible = $true
            $btnProfiles.Visible = $true; $btnActivation.Visible = $true; $btnMSRA.Visible = $true; $btnSCard.Visible = $true; $btnIME.Visible = $true; $btnTeams.Visible = $true; $btnMSIXAA.Visible = $true; $btnHCI.Visible = $true
            $btnStart.Visible = $true
        } else {
            $scenarioLabel.Visible = $false; $btnCore.Visible = $false; $btnDiagOnly.Visible = $false
            $btnProfiles.Visible = $false; $btnActivation.Visible = $false; $btnMSRA.Visible = $false; $btnSCard.Visible = $false; $btnIME.Visible = $false; $btnTeams.Visible = $false; $btnMSIXAA.Visible = $false; $btnHCI.Visible = $false
            $btnStart.Visible = $false
        }
    } elseif ($category -eq "Start") {
        if ($show) {
			$startLabel.Visible = $true
		} else {
			$startLabel.Visible = $false
		}
	}

}

#endregion GUI functions

Function msrdAVDCollectGUILite {

    $global:msrdGUIformLite = New-Object System.Windows.Forms.Form

    $global:msrdGUIformLite.Size = New-Object System.Drawing.Size(630, 500)
    $global:msrdGUIformLite.StartPosition = "CenterScreen"
    $global:msrdGUIformLite.BackColor = "#eeeeee"
    $global:msrdGUIformLite.MaximizeBox = $false
    $global:msrdGUIformLite.Icon = ([System.IconExtractor]::Extract("$global:msrdScriptpath\Config\MSRDC-Icons.dll", 12, $true))
    if ($global:msrdDevLevel -eq "Insider") {
        $global:msrdGUIformLite.Text = 'MSRD-Collect Lite (v' + $global:msrdVersion + ') INSIDER Build - For Testing Purposes Only !'
    } else {
        $global:msrdGUIformLite.Text = 'MSRD-Collect Lite (v' + $global:msrdVersion + ')'
    }
    $global:msrdGUIformLite.TopLevel = $true
    $global:msrdGUIformLite.TopMost = $false
    $global:msrdGUIformLite.FormBorderStyle = "FixedDialog"

    #region GUI elements
    $machineLabel = New-Object System.Windows.Forms.Label
    $machineLabel.Size = New-Object System.Drawing.Size(610, 20)
    $machineLabel.Location = New-Object System.Drawing.Point(0, 20)
    $machineLabel.Text = msrdGetLocalizedText "LiteModeMachine" # Machine type
    $machineLabel.TextAlign = "MiddleCenter"
    $machineLabel.Font = New-Object Drawing.Font($machineLabel.Font, [Drawing.FontStyle]::Bold)
    $global:msrdGUIformLite.Controls.Add($machineLabel)

    $global:btnColor = ""
    $global:btnIdleColor = "Lightgray"

    $btnAVD = New-Object System.Windows.Forms.Button
    $btnAVD.Size = New-Object System.Drawing.Size(150, 40)
    $btnAVD.Location = New-Object System.Drawing.Point(70, 40)
    $btnAVD.BackColor = "Lightblue"
    $btnAVD.Text = "Azure Virtual Desktop"
    $btnAVDToolTip = New-Object System.Windows.Forms.ToolTip
    $btnAVDToolTip.SetToolTip($btnAVD, $(msrdGetLocalizedText "btnTooltipAVD"))
    $global:msrdGUIformLite.Controls.Add($btnAVD)

    $global:btnAVDclick = $true
    $btnAVD.Add_Click({
        $global:btnColor = "Lightblue"
        msrdInitScenarioVars

        if ($global:btnAVDclick) {
            msrdShowHideItems -category "Role" -show $true
            msrdInitMachines -Machine @($true, $false, $false)

            $btnRDS.Enabled = $false; $btnW365.Enabled = $false
            $btnRDS.ResetBackColor(); $btnW365.ResetBackColor()
            $btnSource.Enabled = $true; $btnTarget.Enabled = $true
            $btnSource.BackColor = $global:btnColor; $btnTarget.BackColor = $global:btnColor

            $btnTarget.Text = msrdGetLocalizedText "LiteModeTarget"
            $btnTargetToolTip.SetToolTip($btnTarget, $(msrdGetLocalizedText "LiteModeTargetTooltip"))
        } else {
            msrdInitMachines
            msrdInitRoles

            $btnRDS.Enabled = $true; $btnW365.Enabled = $true
            $btnRDS.BackColor = "Pink"; $btnW365.BackColor = "Lightyellow"
            $btnSource.Enabled = $false; $btnTarget.Enabled = $false
            $btnSource.ResetBackColor(); $btnTarget.ResetBackColor()

            $global:btnSourceClick = $true; $global:btnTargetClick = $true;
            $global:btnProfilesClick = $true; $global:btnActivationClick = $true; $global:btnMSRAClick = $true; $global:btnSCardClick = $true;
            $global:btnIMEClick = $true; $global:btnTeamsClick = $true; $global:btnMSIXAAClick = $true; $global:btnHCIClick = $true;
            $global:btnDiagOnlyClick = $true
            $btnProfiles.Enabled = $false; $btnActivation.Enabled = $false; $btnMSRA.Enabled = $false; $btnSCard.Enabled = $false;
            $btnIME.Enabled = $false; $btnTeams.Enabled = $false; $btnMSIXAA.Enabled = $false; $btnHCI.Enabled = $false;
            $btnProfiles.ResetBackColor(); $btnActivation.ResetBackColor(); $btnMSRA.ResetBackColor(); $btnSCard.ResetBackColor();
            $btnIME.ResetBackColor(); $btnTeams.ResetBackColor(); $btnMSIXAA.ResetBackColor(); $btnHCI.ResetBackColor(); $btnDiagOnly.ResetBackColor(); $btnCore.ResetBackColor();

            $btnStart.Enabled = $false; $btnStart.ResetBackColor();

            $global:onlyDiag = $false
            $script:vCore = $script:varsCore
            msrdShowHideItems -category "Role" -show $false
        }
        $global:btnAVDclick = (-not $global:btnAVDclick)
    })

    $btnRDS = New-Object System.Windows.Forms.Button
    $btnRDS.Size = New-Object System.Drawing.Size(150, 40)
    $btnRDS.Location = New-Object System.Drawing.Point(230, 40)
    $btnRDS.BackColor = "Pink"
    $btnRDS.Text = "Remote Desktop Services"
    $btnRDSToolTip = New-Object System.Windows.Forms.ToolTip
    $btnRDSToolTip.SetToolTip($btnRDS, $(msrdGetLocalizedText "btnTooltipRDS"))
    $global:msrdGUIformLite.Controls.Add($btnRDS)

    $global:btnRDSclick = $true
    $btnRDS.Add_Click({
        $global:btnColor = "Pink"
        msrdInitScenarioVars

        if ($global:btnRDSclick) {
            msrdShowHideItems -category "Role" -show $true
            msrdInitMachines -Machine @($false, $true, $false)

            $btnAVD.Enabled = $false; $btnW365.Enabled = $false
            $btnAVD.ResetBackColor(); $btnW365.ResetBackColor()
            $btnSource.Enabled = $true; $btnTarget.Enabled = $true
            $btnSource.BackColor = $global:btnColor; $btnTarget.BackColor = $global:btnColor

            $btnTarget.Text = msrdGetLocalizedText "LiteModeTarget2"
            $btnTargetToolTip.SetToolTip($btnTarget, $(msrdGetLocalizedText "LiteModeTargetTooltip2"))
        } else {
            msrdInitMachines
            msrdInitRoles

            $btnAVD.Enabled = $true; $btnW365.Enabled = $true
            $btnAVD.BackColor = "Lightblue"; $btnW365.BackColor = "Lightyellow"
            $btnSource.Enabled = $false; $btnTarget.Enabled = $false
            $btnSource.ResetBackColor(); $btnTarget.ResetBackColor()

            $global:btnSourceClick = $true; $global:btnTargetClick = $true;
            $global:btnProfilesClick = $true; $global:btnActivationClick = $true; $global:btnMSRAClick = $true; $global:btnSCardClick = $true;
            $global:btnIMEClick = $true; $global:btnTeamsClick = $true; $global:btnMSIXAAClick = $true; $global:btnHCIClick = $true;
            $global:btnDiagOnlyClick = $true
            $btnProfiles.Enabled = $false; $btnActivation.Enabled = $false; $btnMSRA.Enabled = $false; $btnSCard.Enabled = $false;
            $btnIME.Enabled = $false; $btnTeams.Enabled = $false; $btnMSIXAA.Enabled = $false; $btnHCI.Enabled = $false; $btnDiagOnly.Enabled = $false;
            $btnProfiles.ResetBackColor(); $btnActivation.ResetBackColor(); $btnMSRA.ResetBackColor(); $btnSCard.ResetBackColor();
            $btnIME.ResetBackColor(); $btnTeams.ResetBackColor(); $btnMSIXAA.ResetBackColor(); $btnHCI.ResetBackColor(); $btnDiagOnly.ResetBackColor(); $btnCore.ResetBackColor();

            $btnStart.Enabled = $false; $btnStart.ResetBackColor();

            $global:onlyDiag = $false
            $script:vCore = $script:varsCore
            $btnTarget.Text = "Target machine / Host"
            msrdShowHideItems -category "Role" -show $false
        }
        $global:btnRDSclick = (-not $global:btnRDSclick)
    })

    $btnW365 = New-Object System.Windows.Forms.Button
    $btnW365.Size = New-Object System.Drawing.Size(150, 40)
    $btnW365.Location = New-Object System.Drawing.Point(390, 40)
    $btnW365.BackColor = "Lightyellow"
    $btnW365.Text = "Windows 365 Cloud PC"
    $btnW365ToolTip = New-Object System.Windows.Forms.ToolTip
    $btnW365ToolTip.SetToolTip($btnW365, $(msrdGetLocalizedText "btnTooltipW365"))
    $global:msrdGUIformLite.Controls.Add($btnW365)

    $global:btnW365click = $true
    $btnW365.Add_Click({
        $global:btnColor = "Lightyellow"
        msrdInitScenarioVars

        if ($global:btnW365click) {
            msrdShowHideItems -category "Role" -show $true
            msrdInitMachines -Machine @($false, $false, $true)

            $btnAVD.Enabled = $false; $btnRDS.Enabled = $false
            $btnAVD.ResetBackColor(); $btnRDS.ResetBackColor()
            $btnSource.Enabled = $true; $btnTarget.Enabled = $true
            $btnSource.BackColor = $global:btnColor; $btnTarget.BackColor = $global:btnColor

            $btnTarget.Text = msrdGetLocalizedText "LiteModeTarget"
            $btnTargetToolTip.SetToolTip($btnTarget, $(msrdGetLocalizedText "LiteModeTargetTooltip"))
        } else {
            msrdInitMachines
            msrdInitRoles

            $btnAVD.Enabled = $true; $btnRDS.Enabled = $true
            $btnAVD.BackColor = "Lightblue"; $btnRDS.BackColor = "Pink"
            $btnSource.Enabled = $false; $btnTarget.Enabled = $false
            $btnSource.ResetBackColor(); $btnTarget.ResetBackColor()

            $global:btnSourceClick = $true; $global:btnTargetClick = $true;
            $global:btnProfilesClick = $true; $global:btnActivationClick = $true; $global:btnMSRAClick = $true; $global:btnSCardClick = $true;
            $global:btnIMEClick = $true; $global:btnTeamsClick = $true; $global:btnMSIXAAClick = $true; $global:btnHCIClick = $true;
            $global:btnDiagOnlyClick = $true
            $btnProfiles.Enabled = $false; $btnActivation.Enabled = $false; $btnMSRA.Enabled = $false; $btnSCard.Enabled = $false;
            $btnIME.Enabled = $false; $btnTeams.Enabled = $false; $btnMSIXAA.Enabled = $false; $btnHCI.Enabled = $false; $btnDiagOnly.Enabled = $false;
            $btnProfiles.ResetBackColor(); $btnActivation.ResetBackColor(); $btnMSRA.ResetBackColor(); $btnSCard.ResetBackColor();
            $btnIME.ResetBackColor(); $btnTeams.ResetBackColor(); $btnMSIXAA.ResetBackColor(); $btnHCI.ResetBackColor(); $btnDiagOnly.ResetBackColor(); $btnCore.ResetBackColor();

            $btnStart.Enabled = $false; $btnStart.ResetBackColor();

            $global:onlyDiag = $false
            $script:vCore = $script:varsCore
            msrdShowHideItems -category "Role" -show $false
        }
        $global:btnW365click = (-not $global:btnW365click)
    })

    $roleLabel = New-Object System.Windows.Forms.Label
    $roleLabel.Size = New-Object System.Drawing.Size(610, 20)
    $roleLabel.Location = New-Object System.Drawing.Point(0, 100)
    $roleLabel.Text = msrdGetLocalizedText "LiteModeRole" # "Role"
    $roleLabel.Textalign = "MiddleCenter"
    $roleLabel.Font = New-Object Drawing.Font($roleLabel.Font, [Drawing.FontStyle]::Bold)
    $global:msrdGUIformLite.Controls.Add($roleLabel)

    $btnSource = New-Object System.Windows.Forms.Button
    $btnSource.Size = New-Object System.Drawing.Size(150, 40)
    $btnSource.Location = New-Object System.Drawing.Point(150, 120)
    $btnSource.Text = msrdGetLocalizedText "LiteModeSource"
    $btnSourceToolTip = New-Object System.Windows.Forms.ToolTip
    $btnSourceToolTip.SetToolTip($btnSource, $(msrdGetLocalizedText "LiteModeSourceTooltip"))
    $global:msrdGUIformLite.Controls.Add($btnSource)

    $global:btnSourceClick = $true
    $btnSource.Add_Click({
        msrdInitScenarioVars

        if ($global:btnSourceClick) {
            msrdShowHideItems -category "Scenario" -show $true
            msrdShowHideItems -category "Start" -show $true
            msrdInitRoles -Role @($true, $false)

            $btnTarget.Enabled = $false
            $btnTarget.ResetBackColor()

            $btnCore.BackColor = $global:btnColor;
            $btnProfiles.Enabled = $false; $btnActivation.Enabled = $false; $btnMSRA.Enabled = $false; $btnSCard.Enabled = $false;
            $btnIME.Enabled = $false; $btnTeams.Enabled = $false; $btnMSIXAA.Enabled = $false; $btnHCI.Enabled = $false; $btnDiagOnly.Enabled = $false;
            $btnProfiles.ResetBackColor(); $btnActivation.ResetBackColor(); $btnMSRA.ResetBackColor(); $btnSCard.ResetBackColor();
            $btnIME.ResetBackColor(); $btnTeams.ResetBackColor(); $btnMSIXAA.ResetBackColor(); $btnHCI.ResetBackColor();
            $btnDiagOnly.Enabled = $true; $btnDiagOnly.BackColor = $global:btnIdleColor;
            $btnStart.Enabled = $true; $btnStart.BackColor = $global:btnColor;
        } else {
            msrdInitRoles

            $btnTarget.Enabled = $true
            $btnTarget.BackColor = $global:btnColor
            $global:btnDiagOnlyClick = $true

            $btnCore.ResetBackColor();
            $btnProfiles.Enabled = $false; $btnActivation.Enabled = $false; $btnMSRA.Enabled = $false; $btnSCard.Enabled = $false;
            $btnIME.Enabled = $false; $btnTeams.Enabled = $false; $btnMSIXAA.Enabled = $false; $btnHCI.Enabled = $false;
            $btnProfiles.ResetBackColor(); $btnActivation.ResetBackColor(); $btnMSRA.ResetBackColor(); $btnSCard.ResetBackColor();
            $btnIME.ResetBackColor(); $btnTeams.ResetBackColor(); $btnMSIXAA.ResetBackColor(); $btnHCI.ResetBackColor();
            $btnDiagOnly.Enabled = $false; $btnDiagOnly.ResetBackColor();
            $btnStart.Enabled = $false; $btnStart.ResetBackColor();

            $global:onlyDiag = $false
            $script:vCore = $script:varsCore
            msrdShowHideItems -category "Scenario" -show $false
            msrdShowHideItems -category "Start" -show $false
        }
        $global:btnSourceClick = (-not $global:btnSourceClick)
    })

    $btnTarget = New-Object System.Windows.Forms.Button
    $btnTarget.Size = New-Object System.Drawing.Size(150, 40)
    $btnTarget.Location = New-Object System.Drawing.Point(310, 120)
    $btnTarget.Text = msrdGetLocalizedText "LiteModeTarget"
    $btnTargetToolTip = New-Object System.Windows.Forms.ToolTip
    $global:msrdGUIformLite.Controls.Add($btnTarget)

    $global:btnTargetClick = $true
    $btnTarget.Add_Click({
        msrdInitScenarioVars

        if ($global:btnTargetClick) {
            msrdShowHideItems -category "Scenario" -show $true
            msrdShowHideItems -category "Start" -show $true
            msrdInitRoles -Role @($false, $true)

            $btnSource.Enabled = $false
            $btnSource.ResetBackColor()

            if (-not $global:btnAVDClick) {
                $btnMSRA.Enabled = $true; $btnTeams.Enabled = $true;  $btnMSIXAA.Enabled = $true; $btnHCI.Enabled = $true;
                $btnMSRA.BackColor = $global:btnIdleColor; $btnTeams.BackColor = $global:btnIdleColor; $btnMSIXAA.BackColor = $global:btnIdleColor; $btnHCI.BackColor = $global:btnIdleColor;
            } elseif (-not $global:btnRDSClick) {
                $btnMSRA.Enabled = $true;
                $btnMSRA.BackColor = $global:btnIdleColor;
            } elseif (-not $global:btnW365Click) {
                $btnTeams.Enabled = $true;
                $btnTeams.BackColor = $global:btnIdleColor;
            }

            $btnCore.BackColor = $global:btnColor;
            $btnProfiles.Enabled = $true; $btnActivation.Enabled = $true; $btnSCard.Enabled = $true; $btnIME.Enabled = $true;
            $btnProfiles.BackColor = $global:btnIdleColor; $btnActivation.BackColor = $global:btnIdleColor; $btnSCard.BackColor = $global:btnIdleColor; $btnIME.BackColor = $global:btnIdleColor;
            $btnDiagOnly.Enabled = $true; $btnDiagOnly.BackColor = $global:btnIdleColor;
            $btnStart.Enabled = $true; $btnStart.BackColor = $global:btnColor;

        } else {
            msrdInitRoles

            $btnSource.Enabled = $true
            $btnSource.BackColor = $global:btnColor
            $global:btnDiagOnlyClick = $true

            $btnCore.ResetBackColor();
            $btnProfiles.Enabled = $false; $btnActivation.Enabled = $false; $btnMSRA.Enabled = $false; $btnSCard.Enabled = $false;
            $btnIME.Enabled = $false; $btnTeams.Enabled = $false; $btnMSIXAA.Enabled = $false; $btnHCI.Enabled = $false;
            $btnProfiles.ResetBackColor(); $btnActivation.ResetBackColor(); $btnMSRA.ResetBackColor(); $btnSCard.ResetBackColor();
            $btnIME.ResetBackColor(); $btnTeams.ResetBackColor(); $btnMSIXAA.ResetBackColor(); $btnHCI.ResetBackColor();
            $btnDiagOnly.Enabled = $false; $btnDiagOnly.ResetBackColor();
            $btnStart.Enabled = $false; $btnStart.ResetBackColor();

            $global:onlyDiag = $false
            $script:vCore = $script:varsCore
            msrdShowHideItems -category "Scenario" -show $false
            msrdShowHideItems -category "Start" -show $false
        }
        $global:btnTargetClick = (-not $global:btnTargetClick)
    })

    $scenarioLabel = New-Object System.Windows.Forms.Label
    $scenarioLabel.Size = New-Object System.Drawing.Size(610, 20)
    $scenarioLabel.Location = New-Object System.Drawing.Point(0, 180)
    $scenarioLabel.Text = msrdGetLocalizedText "LiteModeScenarios" # "Scenarios"
    $scenarioLabel.TextAlign = "MiddleCenter"
    $scenarioLabel.Font = New-Object Drawing.Font($scenarioLabel.Font, [Drawing.FontStyle]::Bold)
    $global:msrdGUIformLite.Controls.Add($scenarioLabel)

    $btnCore = New-Object System.Windows.Forms.Button
    $btnCore.Size = New-Object System.Drawing.Size(100, 40)
    $btnCore.Location = New-Object System.Drawing.Point(35, 200)
    $btnCore.Text = "Core"
    $btnCore.Enabled = $false
    $global:msrdGUIformLite.Controls.Add($btnCore)

    $btnProfiles = New-Object System.Windows.Forms.Button
    $btnProfiles.Size = New-Object System.Drawing.Size(100, 40)
    $btnProfiles.Location = New-Object System.Drawing.Point(145, 200)
    $btnProfiles.Text = "Profiles"
    $btnProfilesToolTip = New-Object System.Windows.Forms.ToolTip
    $btnProfilesToolTip.SetToolTip($btnProfiles, "$(msrdGetLocalizedText 'btnTooltipProfiles')")
    $global:msrdGUIformLite.Controls.Add($btnProfiles)

    $global:btnProfilesClick = $true
    $btnProfiles.Add_Click({
        if ($global:btnProfilesClick) {
            $script:vProfiles = $script:varsProfiles; $btnProfiles.BackColor = $global:btnColor;
        } else {
            $script:vProfiles = $varsNO; $btnProfiles.ResetBackColor();
        }
        $global:btnProfilesClick = (-not $global:btnProfilesClick)
    })

    $btnActivation = New-Object System.Windows.Forms.Button
    $btnActivation.Size = New-Object System.Drawing.Size(100, 40)
    $btnActivation.Location = New-Object System.Drawing.Point(255, 200)
    $btnActivation.Text = "Activation"
    $btnActivationToolTip = New-Object System.Windows.Forms.ToolTip
    $btnActivationToolTip.SetToolTip($btnActivation, "$(msrdGetLocalizedText 'btnTooltipActivation')")
    $global:msrdGUIformLite.Controls.Add($btnActivation)

    $global:btnActivationClick = $true
    $btnActivation.Add_Click({
        if ($global:btnActivationClick) {
            $script:vActivation = $script:varsActivation; $btnActivation.BackColor = $global:btnColor;
        } else {
            $script:vActivation = $varsNO; $btnActivation.ResetBackColor();
        }
        $global:btnActivationClick = (-not $global:btnActivationClick)
    })

    $btnMSRA = New-Object System.Windows.Forms.Button
    $btnMSRA.Size = New-Object System.Drawing.Size(100, 40)
    $btnMSRA.Location = New-Object System.Drawing.Point(365, 200)
    $btnMSRA.Text = "Remote Assistance"
    $btnMSRAToolTip = New-Object System.Windows.Forms.ToolTip
    $btnMSRAToolTip.SetToolTip($btnMSRA, "$(msrdGetLocalizedText 'btnTooltipMSRA')")
    $global:msrdGUIformLite.Controls.Add($btnMSRA)

    $global:btnMSRAClick = $true
    $btnMSRA.Add_Click({
        if ($global:btnMSRAClick) {
            $script:vMSRA = $script:varsMSRA; $btnMSRA.BackColor = $global:btnColor;
        } else {
            $script:vMSRA = $varsNO; $btnMSRA.ResetBackColor();
        }
        $global:btnMSRAClick = (-not $global:btnMSRAClick)
    })

    $btnSCard = New-Object System.Windows.Forms.Button
    $btnSCard.Size = New-Object System.Drawing.Size(100, 40)
    $btnSCard.Location = New-Object System.Drawing.Point(475, 200)
    $btnSCard.Text = "Smart Card"
    $btnSCardToolTip = New-Object System.Windows.Forms.ToolTip
    $btnSCardToolTip.SetToolTip($btnSCard, "$(msrdGetLocalizedText 'btnTooltipSCard')")
    $global:msrdGUIformLite.Controls.Add($btnSCard)

    $global:btnSCardClick = $true
    $btnSCard.Add_Click({
        if ($global:btnSCardClick) {
            $script:vSCard = $script:varsSCard; $btnSCard.BackColor = $global:btnColor;
        } else {
            $script:vSCard = $varsNO; $btnSCard.ResetBackColor();
        }
        $global:btnSCardClick = (-not $global:btnSCardClick)
    })

    $btnIME = New-Object System.Windows.Forms.Button
    $btnIME.Size = New-Object System.Drawing.Size(100, 40)
    $btnIME.Location = New-Object System.Drawing.Point(35, 250)
    $btnIME.Text = "IME"
    $btnIMEToolTip = New-Object System.Windows.Forms.ToolTip
    $btnIMEToolTip.SetToolTip($btnIME, "$(msrdGetLocalizedText 'btnTooltipIME')")
    $global:msrdGUIformLite.Controls.Add($btnIME)

    $global:btnIMEClick = $true
    $btnIME.Add_Click({
        if ($global:btnIMEClick) {
            $script:vIME = $script:varsIME; $btnIME.BackColor = $global:btnColor;
        } else {
            $script:vIME = $varsNO; $btnIME.ResetBackColor();
        }
        $global:btnIMEClick = (-not $global:btnIMEClick)
    })

    $btnTeams = New-Object System.Windows.Forms.Button
    $btnTeams.Size = New-Object System.Drawing.Size(100, 40)
    $btnTeams.Location = New-Object System.Drawing.Point(145, 250)
    $btnTeams.Text = "Teams"
    $btnTeamsToolTip = New-Object System.Windows.Forms.ToolTip
    $btnTeamsToolTip.SetToolTip($btnTeams, "$(msrdGetLocalizedText 'btnTooltipTeams')")
    $global:msrdGUIformLite.Controls.Add($btnTeams)

    $global:btnTeamsClick = $true
    $btnTeams.Add_Click({
        if ($global:btnTeamsClick) {
            $script:vTeams = $script:varsTeams; $btnTeams.BackColor = $global:btnColor;
        } else {
            $script:vTeams = $varsNO; $btnTeams.ResetBackColor();
        }
        $global:btnTeamsClick = (-not $global:btnTeamsClick)
    })

    $btnMSIXAA = New-Object System.Windows.Forms.Button
    $btnMSIXAA.Size = New-Object System.Drawing.Size(100, 40)
    $btnMSIXAA.Location = New-Object System.Drawing.Point(255, 250)
    $btnMSIXAA.Text = "App Attach"
    $btnMSIXAAToolTip = New-Object System.Windows.Forms.ToolTip
    $btnMSIXAAToolTip.SetToolTip($btnMSIXAA, "$(msrdGetLocalizedText 'btnTooltipMSIXAA')")
    $global:msrdGUIformLite.Controls.Add($btnMSIXAA)

    $global:btnMSIXAAClick = $true
    $btnMSIXAA.Add_Click({
        if ($global:btnMSIXAAClick) {
            $script:vMSIXAA = $script:varsMSIXAA; $btnMSIXAA.BackColor = $global:btnColor;
        } else {
            $script:vMSIXAA = $varsNO; $btnMSIXAA.ResetBackColor();
        }
        $global:btnMSIXAAClick = (-not $global:btnMSIXAAClick)
    })

    $btnHCI = New-Object System.Windows.Forms.Button
    $btnHCI.Size = New-Object System.Drawing.Size(100, 40)
    $btnHCI.Location = New-Object System.Drawing.Point(365, 250)
    $btnHCI.Text = "Azure Stack HCI"
    $btnHCIToolTip = New-Object System.Windows.Forms.ToolTip
    $btnHCIToolTip.SetToolTip($btnHCI, "$(msrdGetLocalizedText 'btnTooltipHCI')")
    $global:msrdGUIformLite.Controls.Add($btnHCI)

    $global:btnHCIClick = $true
    $btnHCI.Add_Click({
        if ($global:btnHCIClick) {
            $script:vHCI = $script:varsHCI; $btnHCI.BackColor = $global:btnColor;
        } else {
            $script:vHCI = $varsNO; $btnHCI.ResetBackColor();
        }
        $global:btnHCIClick = (-not $global:btnHCIClick)
    })

    $btnDiagOnly = New-Object System.Windows.Forms.Button
    $btnDiagOnly.Size = New-Object System.Drawing.Size(100, 40)
    $btnDiagOnly.Location = New-Object System.Drawing.Point(475, 250)
    $btnDiagOnly.Text = "Diagnostics Only"
    $btnDiagOnlyToolTip = New-Object System.Windows.Forms.ToolTip
    $btnDiagOnlyToolTip.SetToolTip($btnDiagOnly, "$(msrdGetLocalizedText 'btnTooltipDiagOnly')")
    $global:msrdGUIformLite.Controls.Add($btnDiagOnly)

    $global:btnDiagOnlyClick = $true
    $btnDiagOnly.Add_Click({
        if ($global:btnDiagOnlyClick) {
            $global:onlyDiag = $true
            $script:vCore = $script:varsNO

            $btnDiagOnly.BackColor = $global:btnColor; $btnCore.ResetBackColor();
            $btnProfiles.Enabled = $false; $btnActivation.Enabled = $false; $btnMSRA.Enabled = $false; $btnSCard.Enabled = $false;
            $btnIME.Enabled = $false; $btnTeams.Enabled = $false; $btnMSIXAA.Enabled = $false; $btnHCI.Enabled = $false;
            $btnProfiles.ResetBackColor(); $btnActivation.ResetBackColor(); $btnMSRA.ResetBackColor(); $btnSCard.ResetBackColor();
            $btnIME.ResetBackColor(); $btnTeams.ResetBackColor(); $btnMSIXAA.ResetBackColor(); $btnHCI.ResetBackColor();
        } else {
            $global:onlyDiag = $false
            $script:vCore = $script:varsCore

            if (-not $btnTargetClick) {
                if (-not $global:btnAVDClick) {
                    $btnMSRA.Enabled = $true; $btnTeams.Enabled = $true;  $btnMSIXAA.Enabled = $true; $btnHCI.Enabled = $true;
                    $btnMSRA.BackColor = $global:btnIdleColor; $btnTeams.BackColor = $global:btnIdleColor; $btnMSIXAA.BackColor = $global:btnIdleColor; $btnHCI.BackColor = $global:btnIdleColor;
                } elseif (-not $global:btnRDSClick) {
                    $btnMSRA.Enabled = $true;
                    $btnMSRA.BackColor = $global:btnIdleColor;
                } elseif (-not $global:btnW365Click) {
                    $btnTeams.Enabled = $true;
                    $btnTeams.BackColor = $global:btnIdleColor;
                }
                $btnProfiles.Enabled = $true; $btnActivation.Enabled = $true; $btnSCard.Enabled = $true; $btnIME.Enabled = $true;
                $btnProfiles.BackColor = $global:btnIdleColor; $btnActivation.BackColor = $global:btnIdleColor; $btnSCard.BackColor = $global:btnIdleColor; $btnIME.BackColor = $global:btnIdleColor;
            }

            $global:btnProfilesClick = $true; $global:btnActivationClick = $true; $global:btnMSRAClick = $true; $global:btnSCardClick = $true;
            $global:btnIMEClick = $true; $global:btnTeamsClick = $true; $global:btnMSIXAAClick = $true; $global:btnHCIClick = $true;
            $btnDiagOnly.BackColor = $global:btnIdleColor; $btnCore.BackColor = $global:btnColor;
        }
        $global:btnDiagOnlyClick = (-not $global:btnDiagOnlyClick)
    })

    $startLabel = New-Object System.Windows.Forms.Label
    $startLabel.Size = New-Object System.Drawing.Size(610, 20)
    $startLabel.Location = New-Object System.Drawing.Point(0, 310)
    $startLabel.Text = msrdGetLocalizedText "LiteModeStart" # "Start"
    $startLabel.TextAlign = "MiddleCenter"
    $startLabel.Font = New-Object Drawing.Font($startLabel.Font, [Drawing.FontStyle]::Bold)
    $global:msrdGUIformLite.Controls.Add($startLabel)

    $btnStart = New-Object System.Windows.Forms.Button
    $btnStart.Size = New-Object System.Drawing.Size(120, 40)
    $btnStart.Location = New-Object System.Drawing.Point(245, 330)
    $btnStart.Text = msrdGetLocalizedText "Start"
    $btnStartToolTip = New-Object System.Windows.Forms.ToolTip
    $btnStartToolTip.SetToolTip($btnStart, "$(msrdGetLocalizedText 'RunMenu')")
    $global:msrdGUIformLite.Controls.Add($btnStart)

    $btnStart.Add_Click({ msrdStartBtnCollect })

    msrdShowHideItems -category "Role" -show $false
    msrdShowHideItems -category "Scenario" -show $false
    msrdShowHideItems -category "Start" -show $false

    # Create the "Show console" checkbox and label
    $checkBoxShowConsole = New-Object System.Windows.Forms.CheckBox
    $checkBoxShowConsole.Text = msrdGetLocalizedText "LiteModeHideConsole"
    $checkBoxShowConsole.Location = New-Object System.Drawing.Point(20, 385)
    $checkBoxShowConsole.Size = New-Object System.Drawing.Size(150, 20)
    $global:msrdGUIformLite.Controls.Add($checkBoxShowConsole)
    $checkBoxShowConsole.Add_Click({
        if ($checkBoxShowConsole.Checked) {
            msrdStartShowConsole
            $checkBoxShowConsole.Checked = $true
        } else {
            msrdStartHideConsole
            $checkBoxShowConsole.Checked = $false
        }
    })

    # Create the "Advanced Mode" checkbox and label
    $checkBoxAdvancedMode = New-Object System.Windows.Forms.CheckBox
    $checkBoxAdvancedMode.Text = msrdGetLocalizedText "LiteModeAdvanced" # Advanced Mode
    $checkBoxAdvancedMode.Location = New-Object System.Drawing.Point(495, 385)
    $checkBoxAdvancedMode.Size = New-Object System.Drawing.Size(150, 20)
    $global:msrdGUIformLite.Controls.Add($checkBoxAdvancedMode)
    $checkBoxAdvancedMode.Add_Click({
        if ($checkBoxAdvancedMode.Checked) {
            try {
                $ScriptFile = $global:msrdScriptpath + "\MSRD-Collect.ps1"
                Start-Process PowerShell.exe -ArgumentList "$ScriptFile" -NoNewWindow
                msrdUpdateConfigFile -configFile "Config\MSRDC-Config.cfg" -key "UILiteMode" -value 0
                If (($Null -ne $global:msrdTempCommandErrorFile) -and (Test-Path -Path $global:msrdTempCommandErrorFile)) { Remove-Item $global:msrdTempCommandErrorFile -Force | Out-Null }
                If ($global:fQuickEditCodeExist) { [msrdDisableConsoleQuickEdit]::SetQuickEdit($False) | Out-Null }
                if (($global:msrdGUIformLite -and $global:msrdGUIformLite.Visible)) { $global:msrdGUIformLite.Close() } else { Exit }
            } catch {
                $failedCommand = $_.InvocationInfo.Line.TrimStart()
                msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
            }
        }
    })


    # Iterate through all controls on the form
    foreach ($control in $global:msrdGUIformLite.Controls) {
        # Check if the control is a Button
        if (($control -is [System.Windows.Forms.Button]) -or ($control -is [System.Windows.Forms.CheckBox])) {
            $control.Add_MouseEnter({ $this.Cursor = [System.Windows.Forms.Cursors]::Hand })
            $control.Add_MouseLeave({ $this.Cursor = [System.Windows.Forms.Cursors]::Default })
        }
    }
    #endregion GUI elements


    #region BottomOptions

    $global:msrdStatusBar = New-Object System.Windows.Forms.StatusStrip
    $global:msrdStatusBarLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $global:msrdStatusBarLabel.Text = msrdGetLocalizedText "Ready"
    $global:msrdStatusBar.Items.Add($global:msrdStatusBarLabel) | Out-Null
    $global:msrdGUIformLite.Controls.Add($global:msrdStatusBar)

    $global:msrdProgbar = New-Object System.Windows.Forms.ProgressBar
    $global:msrdProgbar.Location  = New-Object System.Drawing.Point(10,415)
    $global:msrdProgbar.Size = New-Object System.Drawing.Size(595,15)
    $global:msrdProgbar.Anchor = 'Left,Bottom'
    $global:msrdProgbar.DataBindings.DefaultDataSourceUpdateMode = 0
    $global:msrdProgbar.Step = 1
    $global:msrdGUIformLite.Controls.Add($global:msrdProgbar)

    $feedbackLinkLite = New-Object System.Windows.Forms.LinkLabel
    $feedbackLinkLite.Location = [System.Drawing.Point]::new(195, 385)
    $feedbackLinkLite.Size = [System.Drawing.Point]::new(180, 20)
    $feedbackLinkLite.LinkColor = [System.Drawing.Color]::Blue
    $feedbackLinkLite.ActiveLinkColor = [System.Drawing.Color]::Red
    $feedbackLinkLite.Text = msrdGetLocalizedText "feedbackLink"
    $feedbackLinkLite.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $feedbackLinkLite.Add_Click({ [System.Diagnostics.Process]::Start('https://aka.ms/MSRD-Collect-Feedback') })
    $feedbackLinkLiteToolTip = New-Object System.Windows.Forms.ToolTip
    $feedbackLinkLiteToolTip.SetToolTip($feedbackLinkLite, "$(msrdGetLocalizedText 'feedbackLink')")
    $global:msrdGUIformLite.Controls.Add($feedbackLinkLite)

    #endregion BottomOptions

    if ($global:msrdShowConsole -eq 1) {
        msrdStartShowConsole
        $checkBoxShowConsole.Checked = $true
    } else {
        msrdStartHideConsole
        $checkBoxShowConsole.Checked = $false
    }

    $global:msrdGUIformLite.Add_Shown({
        $btnSource.Enabled = $false
        $btnTarget.Enabled = $false
        $btnProfiles.Enabled = $false
        $btnActivation.Enabled = $false
        $btnMSRA.Enabled = $false
        $btnSCard.Enabled = $false
        $btnIME.Enabled = $false
        $btnTeams.Enabled = $false
        $btnMSIXAA.Enabled = $false
        $btnHCI.Enabled = $false
        $btnStart.Enabled = $false
    })

    $global:msrdGUIformLite.Add_Closing({
        If (($Null -ne $global:msrdTempCommandErrorFile) -and (Test-Path -Path $global:msrdTempCommandErrorFile)) { Remove-Item $global:msrdTempCommandErrorFile -Force | Out-Null }
        If ($global:fQuickEditCodeExist) { [msrdDisableConsoleQuickEdit]::SetQuickEdit($False) | Out-Null }
    })

    $global:msrdGUIformLite.ShowDialog() | Out-Null
    msrdStartShowConsole -nocfg $true
}


Export-ModuleMember -Function msrdAVDCollectGUILite
# SIG # Begin signature block
# MIInvwYJKoZIhvcNAQcCoIInsDCCJ6wCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD8jQtylK+JUEMg
# 4krp4WlgmcvjAGr2BWb9bnHsMtrcXqCCDXYwggX0MIID3KADAgECAhMzAAADrzBA
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
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIJAvwAOQA17sYa2NDqaHBkCn
# GbouLM1v0MfV0jP8ixYjMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAT16aljowsMyK1Cz8XCIMZcBXU1/+mzOevX19QBu36i4MmRBJf3z/Jnz9
# EC62RkJYoAGrVfbjj3UwlB6BCCVtDwY5dBWp9kKs+jh5aRkgg42q73c8Gaf7cC9P
# E8M1rvAEMuj3YK/ghKhxx9gHW64c8ZILlnt4bFScxcfMdOtfIB3SJpYeKaAdv2m0
# CBOsTYqETGenloAomcAwEZhmhnoBwovnQd2ejd8OIhf1SR6dDU9fjGrKXLepZZjM
# 2RT+ZRkrE8O9Uoho5zBFvBZq69i1tMz+O9ZBszajfewt1PcghNZQA2gSXl2cSN8K
# cosXNacvIM10M17yakyVvN+caV07DKGCFykwghclBgorBgEEAYI3AwMBMYIXFTCC
# FxEGCSqGSIb3DQEHAqCCFwIwghb+AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsq
# hkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCBMW6s14EDhQtzO963/8aMP1N6PHkj0nv704YDoVzns/wIGZbqlXidn
# GBMyMDI0MDIyMDEyMTY1OC4zOTlaMASAAgH0oIHYpIHVMIHSMQswCQYDVQQGEwJV
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
# IgQg9oGiQTq91Ipt2CH5rydm6j7ELNIzQcS/ySXxdt3BaPcwgfoGCyqGSIb3DQEJ
# EAIvMYHqMIHnMIHkMIG9BCBTpxeKatlEP4y8qZzjuWL0Ou0IqxELDhX2TLylxIIN
# NzCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB3MHg
# jMJfWF6OAAEAAAHcMCIEIMq+2CFXJYA28rws+5gL9LlWmreOOAJUqesR6p1SI0xw
# MA0GCSqGSIb3DQEBCwUABIICAAI17M8CMO7znzEQcTFyeGs/AdJhnxauLHon/7Za
# VwBedbGsrB60yJMGALODdK3Enwr41+ABUMOYQkzTPJZF73eQKpmw5Wf0cfuJQ9jh
# GlQghnes5dzl4raIKqOowGYuWjjPvkZibAY6HG1Yi+CMR1GLKyHnTDqr4wu0/+BM
# lxR1TcHg7RtlUdb4VRSuc9Ef8EtxdY5i19LP1xULJvBfU5D+9eTMJch6xDJENs63
# gL/61Nsp1m3xhglvPmOiKTnAp02UY8ZKbP/7Z4CkybrgGtqGY2V/KIjy6DvY9jzY
# Eo5Ohm/v3ph+qIfFjrwg0lHuAkWrpnZCJnHp6iULbXbKfi6otfs7OCO5zGPbnaRO
# HBlEgWymKfIjLzyHKGwM9Y7GY9UbGRWLqHnvTN0LyE0sSqGoicT/fTtuN4aKl1ms
# WMIYlBHpySeRnhBWJMXbZywPjhCla9JnUmWkul2Zjfl+8LGwJn7J6P9xWNCLusly
# egf0GB0zea5nK5SYA+SM16qUjy5DjY6wdhwR7gOB791Fpab8+JE8Wkm/qz5JzOle
# z+xijPbNtlQEb1xBivwchrTin41EIId2lRQ1aNGXQw2NBa5NdILonjbYcQLTHhuQ
# MC1701BBfp95pqqK/YWGcrJ1G/GYzJ1Kr2tHPEVTm+2jZlVg84AHj5mXC/Ym1mrX
# dcb+
# SIG # End signature block
