<#
.SYNOPSIS
   MSRD-Collect graphical user interface (Lite version)

.DESCRIPTION
   Module for the MSRD-Collect graphical user interface (Lite version)

.NOTES
   Author     : Robert Klemencz
   Requires   : At least PowerShell 5.1 (This module is not for stand-alone use. It is used automatically from within the main MSRD-Collect.ps1 script)
   Version    : See MSRD-Collect.ps1 version
   Feedback   : Send an e-mail to MSRDCollectTalk@microsoft.com
#>

#region config variables
$varsCore = @(,$true * 10)
$vCore = $varsCore

$varsProfiles = @(,$true * 4)
$varsActivation = @(,$true * 3)
$varsMSRA = @(,$true * 5)
$varsSCard = @(,$true * 3)
$varsIME = @(,$true * 2)
$varsTeams = @(,$true * 2)
$varsMSIXAA = @(,$true * 1)
$varsHCI = @(,$true * 1)

$varsNO = $false

$varsSystem = @(,$true * 11)
$varsAVDRDS = @(,$true * 10)
$varsInfra = @(,$true * 7)
$varsAD = @(,$true * 2)
$varsNET = @(,$true * 7)
$varsLogSec = @(,$true * 2)
$varsIssues = @(,$true * 2)
$varsOther = @(,$true * 4)

$dumpProc = $False; $pidProc = ""
$traceNet = $False; $global:onlyDiag = $false
#endregion config variables


#region code
#Load dlls into context of the current console session
 Add-Type -Name Window -Namespace Console -MemberDefinition '
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
#endregion code

#region languages

# Create a dropdown menu
$dropdown = New-Object System.Windows.Forms.ComboBox
$dropdown.Location = New-Object System.Drawing.Point(20, 150)
$dropdown.Width = 50

# Add items to the dropdown
$items = "DE", "EN", "FR", "HU", "IT", "PT", "RO"
foreach ($item in $items) {
    $dropdown.Items.Add($item)
}

# Add the dropdown to the form
#$global:msrdGUIformLite.Controls.Add($dropdown)

#endregion languages

#region GUI functions
Add-Type -AssemblyName System.Windows.Forms

function msrdStartShowConsole {
    param ($nocfg)

    try {
        $PSConsole = [Console.Window]::GetConsoleWindow()
        [Console.Window]::ShowWindow($PSConsole, 5) | Out-Null
        Write-Output "$(msrdGetLocalizedText "conVisible")`n"
        if (!($nocfg)) {
            msrdUpdateConfigFile -configFile "MSRD-Collect.cfg" -key "ShowConsoleWindow" -value 1
        }
    } catch {
        Write-Warning "Error showing console window: $($_.Exception.Message)"
    }
}

function msrdStartHideConsole {
    try {
        $PSConsole = [Console.Window]::GetConsoleWindow()
        [Console.Window]::ShowWindow($PSConsole, 0) | Out-Null
        Write-Output "$(msrdGetLocalizedText "conHidden")`n"
        msrdUpdateConfigFile -configFile "MSRD-Collect.cfg" -key "ShowConsoleWindow" -value 0
    } catch {
        Write-Warning "Error hiding console window: $($_.Exception.Message)"
    }
}

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

    if (-not $GetTeamsLogs) {
        $btnStart.Text = msrdGetLocalizedText "Running"
        if (-not $global:onlyDiag) {
            $global:msrdStatusBar.Text = "Starting data collection/diagnostics"
        } else {
			$global:msrdStatusBar.Text = "Starting diagnostics"
		}
        msrdInitFolders

        msrdLogMessage $LogLevel.InfoLogFileOnly "Script version $global:msrdVersion launched from: $global:msrdScriptpath"
        msrdLogMessage $LogLevel.InfoLogFileOnly "Command line: $global:msrdCmdLine"
        msrdLogMessage $LogLevel.InfoLogFileOnly "EULA and Notice accepted"
        msrdLogMessage $LogLevel.InfoLogFileOnly "Output location: $global:msrdLogRoot"
        msrdLogMessage $LogLevel.InfoLogFileOnly "User context: $global:msrdUserprof"
        msrdLogMessage $LogLevel.InfoLogFileOnly "PID selected for process dump: $script:pidProc"

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

        msrdArchiveData -varsCore $script:vCore
        $btnStart.Text = msrdGetLocalizedText "Start"
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
    $global:msrdGUIformLite.Icon = ([System.IconExtractor]::Extract("$global:msrdScriptpath\MSRD-Collect.dll", 12, $true))
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
    $btnRDS.Text = "Remote Desktop Services`n(incl. direct RDP)"
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
    $btnProfilesToolTip.SetToolTip($btnProfiles, "Collect data for troubleshooting 'User Profiles' issues")
    $global:msrdGUIformLite.Controls.Add($btnProfiles)

    $global:btnProfilesClick = $true
    $btnProfiles.Add_Click({
        if ($global:btnProfilesClick) {
            $script:vProfiles = $varsProfiles; $btnProfiles.BackColor = $global:btnColor;
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
    $btnActivationToolTip.SetToolTip($btnActivation, "Collect data for troubleshooting 'OS Licensing/Activation' issues")
    $global:msrdGUIformLite.Controls.Add($btnActivation)

    $global:btnActivationClick = $true
    $btnActivation.Add_Click({
        if ($global:btnActivationClick) {
            $script:vActivation = $varsActivation; $btnActivation.BackColor = $global:btnColor;
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
    $btnMSRAToolTip.SetToolTip($btnMSRA, "Collect data for troubleshooting 'Remote Assistance' issues")
    $global:msrdGUIformLite.Controls.Add($btnMSRA)

    $global:btnMSRAClick = $true
    $btnMSRA.Add_Click({
        if ($global:btnMSRAClick) {
            $script:vMSRA = $varsMSRA; $btnMSRA.BackColor = $global:btnColor;
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
    $btnSCardToolTip.SetToolTip($btnSCard, "Collect data for troubleshooting 'Smart Card' issues")
    $global:msrdGUIformLite.Controls.Add($btnSCard)

    $global:btnSCardClick = $true
    $btnSCard.Add_Click({
        if ($global:btnSCardClick) {
            $script:vSCard = $varsSCard; $btnSCard.BackColor = $global:btnColor;
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
    $btnIMEToolTip.SetToolTip($btnIME, "Collect data for troubleshooting 'Input Method' issues")
    $global:msrdGUIformLite.Controls.Add($btnIME)

    $global:btnIMEClick = $true
    $btnIME.Add_Click({
        if ($global:btnIMEClick) {
            $script:vIME = $varsIME; $btnIME.BackColor = $global:btnColor;
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
    $btnTeamsToolTip.SetToolTip($btnTeams, "Collect data for troubleshooting 'Teams on AVD/W365' issues")
    $global:msrdGUIformLite.Controls.Add($btnTeams)

    $global:btnTeamsClick = $true
    $btnTeams.Add_Click({
        if ($global:btnTeamsClick) {
            $script:vTeams = $varsTeams; $btnTeams.BackColor = $global:btnColor;
        } else {
            $script:vTeams = $varsNO; $btnTeams.ResetBackColor();
        }
        $global:btnTeamsClick = (-not $global:btnTeamsClick)
    })

    $btnMSIXAA = New-Object System.Windows.Forms.Button
    $btnMSIXAA.Size = New-Object System.Drawing.Size(100, 40)
    $btnMSIXAA.Location = New-Object System.Drawing.Point(255, 250)
    $btnMSIXAA.Text = "MSIX App Attach"
    $btnMSIXAAToolTip = New-Object System.Windows.Forms.ToolTip
    $btnMSIXAAToolTip.SetToolTip($btnMSIXAA, "Collect data for troubleshooting 'MSIX App Attach' issues")
    $global:msrdGUIformLite.Controls.Add($btnMSIXAA)

    $global:btnMSIXAAClick = $true
    $btnMSIXAA.Add_Click({
        if ($global:btnMSIXAAClick) {
            $script:vMSIXAA = $varsMSIXAA; $btnMSIXAA.BackColor = $global:btnColor;
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
    $btnHCIToolTip.SetToolTip($btnHCI, "Collect data for troubleshooting 'AVD on Azure Stack HCI' issues")
    $global:msrdGUIformLite.Controls.Add($btnHCI)

    $global:btnHCIClick = $true
    $btnHCI.Add_Click({
        if ($global:btnHCIClick) {
            $script:vHCI = $varsHCI; $btnHCI.BackColor = $global:btnColor;
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
    $btnDiagOnlyToolTip.SetToolTip($btnDiagOnly, "Generate a Diagnostics report only")
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
    $btnStartToolTip.SetToolTip($btnStart, "Start Data Collection/Diagnostics")
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
        } else {
            msrdStartHideConsole
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
                msrdUpdateConfigFile -configFile "MSRD-Collect.cfg" -key "UILiteMode" -value 0
                If (($Null -ne $global:msrdTempCommandErrorFile) -and (Test-Path -Path $global:msrdTempCommandErrorFile)) { Remove-Item $global:msrdTempCommandErrorFile -Force | Out-Null }
                If ($global:fQuickEditCodeExist) { [msrdDisableConsoleQuickEdit]::SetQuickEdit($False) | Out-Null }
                if (($global:msrdGUIformLite -and $global:msrdGUIformLite.Visible)) { $global:msrdGUIformLite.Close() } else { Exit }
            } catch {
                $failedCommand = $_.InvocationInfo.Line.TrimStart()
                $errorMessage = $_.Exception.Message.TrimStart()
                msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_ -fErrorLogFileOnly
                if ($global:msrdGUI) {
                    msrdAdd-OutputBoxLine -Message "Error in $failedCommand $errorMessage" -Color Magenta
                } else {
                    msrdLogMessage $LogLevel.Warning ("Error in $failedCommand $errorMessage")
                }
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
    $global:msrdStatusBarLabel.Text = "Ready"
    $global:msrdStatusBar.Items.Add($global:msrdStatusBarLabel) | Out-Null
    $global:msrdGUIformLite.Controls.Add($global:msrdStatusBar)

    $global:msrdProgbar = New-Object System.Windows.Forms.ProgressBar
    $global:msrdProgbar.Location  = New-Object System.Drawing.Point(10,415)
    $global:msrdProgbar.Size = New-Object System.Drawing.Size(595,15)
    $global:msrdProgbar.Anchor = 'Left,Bottom'
    $global:msrdProgbar.DataBindings.DefaultDataSourceUpdateMode = 0
    $global:msrdProgbar.Step = 1
    $global:msrdGUIformLite.Controls.Add($global:msrdProgbar)

    $surveyLinkLite = New-Object System.Windows.Forms.LinkLabel
    $surveyLinkLite.Location = [System.Drawing.Point]::new(195, 385)
    $surveyLinkLite.Size = [System.Drawing.Point]::new(180, 20)
    $surveyLinkLite.LinkColor = [System.Drawing.Color]::Blue
    $surveyLinkLite.ActiveLinkColor = [System.Drawing.Color]::Red
    $surveyLinkLite.Text = msrdGetLocalizedText "surveyLink"
    $surveyLinkLite.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
    $surveyLinkLite.Add_Click({ [System.Diagnostics.Process]::Start('https://aka.ms/MSRD-Collect-Survey') })
    $surveyLinkLiteToolTip = New-Object System.Windows.Forms.ToolTip
    $surveyLinkLiteToolTip.SetToolTip($surveyLinkLite, "How do you like this script?")
    $global:msrdGUIformLite.Controls.Add($surveyLinkLite)

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
        $global:msrdCollectcount = 0
        If (($Null -ne $global:msrdTempCommandErrorFile) -and (Test-Path -Path $global:msrdTempCommandErrorFile)) { Remove-Item $global:msrdTempCommandErrorFile -Force | Out-Null }
        If ($global:fQuickEditCodeExist) { [msrdDisableConsoleQuickEdit]::SetQuickEdit($False) | Out-Null }
    })

    $global:msrdGUIformLite.ShowDialog() | Out-Null
    msrdStartShowConsole -nocfg $true
}


Export-ModuleMember -Function msrdAVDCollectGUILite
# SIG # Begin signature block
# MIInvgYJKoZIhvcNAQcCoIInrzCCJ6sCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAc/X8SVtl/YiQU
# iMfDO6AcvVWhANmOQKPvrsX2FTeo86CCDXYwggX0MIID3KADAgECAhMzAAADrzBA
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
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIIclZgnrr5raIncyfleDLdz+
# 3YxivIVu1tYRIPIklTCTMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAmoha8+8dkKXtKAIHtV4ScBDAGQE333ORA4ttk/t6jTFD6ane3kpzxmtj
# MLWO6gtQQvSAWVyh6oVBryuY4jBawAdGcDn24UvryjDUf9HuFFeQmXhTvpLRnT3e
# vhou5JncWm4rH40TEKRz5lHMvO0jS/xDV76eplKUyZARjbdG0gEIeNTeCpjDdEGa
# 4BjqXnYtM52Qg/TCmEm0nnsU7YQmKZzBtG24Xm3Hk7zmZf+hVxTqGtM0pEDnG881
# 3/IFnW5at+5bWuTi5yo1rf2EmJHJgZILsXSMs6LwchasDP3E4rnR7cvVHiL5agOn
# VbS9h+7E1gg0jnmoHZRehQBe210ew6GCFygwghckBgorBgEEAYI3AwMBMYIXFDCC
# FxAGCSqGSIb3DQEHAqCCFwEwghb9AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFYBgsq
# hkiG9w0BCRABBKCCAUcEggFDMIIBPwIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCDpsvNLhHs3fpbAcqkrJBEoNX/mcJDwBgBnJpu2qy8I9wIGZbqiEEH0
# GBIyMDI0MDIyMDEyMTY1OC43N1owBIACAfSggdikgdUwgdIxCzAJBgNVBAYTAlVT
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
# BCByuBo1VPe5hbKGBns3tLPOQ5qgQQGPudGPrchVXKiS2zCB+gYLKoZIhvcNAQkQ
# Ai8xgeowgecwgeQwgb0EIGH/Di2aZaxPeJmce0fRWTftQI3TaVHFj5GI43rAMWNm
# MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEm
# MCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAHdXVcd
# ldStqhsAAQAAAd0wIgQgD/HnIWMN/YRMoADZ2halkeeXdew6oPfVzAx8q/Ws09kw
# DQYJKoZIhvcNAQELBQAEggIAZ7sE4By0qcoRSG9cvN+sVeB/XkdgJpmsxJL7UvLa
# mD5uPn+GKwm6/W9tUZSt4+Lv4rKaeHuFyf6NyblLYds+HEj6jEVVN90MmaI7+o9j
# uNgPwlGf+BkN9KJzuWenxXYLV3UXsz0Tx+E8X30PYY2ttOlZSNbKfPuzsZOcalOc
# nLigb3vToQpHrjxBRfCSQ7Yxcwg5PEMGQiCaQcUsNuuY4XzR0dSWO6zii14LxyBQ
# QzRI1CoEBQsaDcguBtnpPDNK6ZHQlFhKoTRmTLhAbRgDOPCt2/Pzs9/030VAnhtC
# qjO46eqOnetSnzu72cqbJfHBqJQsvatnJ1BiVuh9WgbR08mr78kO0YbZ0cyLo2vB
# W+7wWf8mMF+D+KrIOXVIHrejXOd405Y3QumMT+9IpRBEz3G/fHz66BUVG3LFQNJ5
# 9mO143G5nYg46B/xSLmCpeLPIa5BNJYT0GjvgghplLVaqfl4/tLTrQPBD9wQFdZB
# 9zfl75vkFYK4DWrp+wPo8JxiXtTSlHjb++TD5e80oCbX3eZPgpgoCsosogbzvX1U
# 4tRO+bhsvUp4m24LWpuSh1zZkwmf7vPHyJwXrtviurMN2BZtt6JCi/BktmZnS/aW
# mXysf36p1HAf/1hcBDTyVP8v0fsdW6CnxroGI5H8Z+lvklxYjzpwUj8K/BCLJpgF
# DLs=
# SIG # End signature block
