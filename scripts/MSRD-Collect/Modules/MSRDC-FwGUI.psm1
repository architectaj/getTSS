<#
.SYNOPSIS
   MSRD-Collect graphical user interface

.DESCRIPTION
   Module for the MSRD-Collect graphical user interface

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
$global:msrdLiveDiag = $false

$msrdUserProfilesDir = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" -Name ProfilesDirectory).ProfilesDirectory

#region GUI

#prepare icons
$iconCount = 43
$icons = @()

for ($i = 0; $i -lt $iconCount; $i++) {
    $icons += [System.IconExtractor]::Extract("$global:msrdScriptpath\Config\MSRDC-Icons.dll", $i, $true)
}

$abouticon = $icons[0]; $alwaysontopicon = $icons[1]; $azureicon = $icons[2]; $configicon = $icons[3]
$consoleicon = $icons[4]; $diagreporticon = $icons[5]; $docsicon = $icons[6]; $downloadicon = $icons[7]
$exiticon = $icons[8]; $feedbackicon = $icons[9]; $foldericon = $icons[10]; $litemodeicon = $icons[12]
$machineavdicon = $icons[13]; $machinerdsicon = $icons[14]; $machinew365icon = $icons[15]; $maximizedicon = $icons[16]
$msrdcicon = $icons[17]; $readmeicon = $icons[18]; $rolesourceicon = $icons[19]; $roletargeticon = $icons[20]
$scenarioactivationicon = $icons[21]; $scenariocoreicon = $icons[22]; $scenariohciicon = $icons[23]; $scenarioimeicon = $icons[24]
$scenariolivediagicon = $icons[25]; $scenariomsixaaicon = $icons[26]; $scenariomsraicon = $icons[27]; $scenarionettraceicon = $icons[28]
$scenarioprocdumpicon = $icons[29]; $scenarioprofilesicon = $icons[30]; $scenariodiagonlyicon = $icons[31]; $scenarioscardicon = $icons[32]
$scenarioteamsicon = $icons[33]; $scheduledtaskicon = $icons[34]; $searchicon = $icons[35]; $soundassisticon = $icons[36]
$soundsystemicon = $icons[37]; $starticon = $icons[38]; $uilanguageicon = $icons[39]; $updateicon = $icons[40]
$usercontexticon = $icons[41]; $whatsnewicon = $icons[42]

#create menu items
function msrdCreateMenu([string]$Text) {

    $Menu = New-Object System.Windows.Forms.ToolStripMenuItem
    $Menu.Text = $Text
    $Menu.Add_MouseEnter({ $this.Owner.Cursor = [System.Windows.Forms.Cursors]::Hand })
    $Menu.Add_MouseLeave({ $this.Owner.Cursor = [System.Windows.Forms.Cursors]::Default })

    return $Menu
}

#create menu buttons (panel, button area, buttons)
$buttonRibbon = New-Object Windows.Forms.Panel
$buttonRibbon.Location = New-Object Drawing.Point(0, 25)
$buttonRibbon.Size = New-Object System.Drawing.Size(1366, 82)
$buttonRibbon.BackColor = "#C0C0C0"
if ($global:msrdLangID -eq "AR") {
    $buttonRibbon.RightToLeft = "Yes"
    $buttonRibbon.Anchor = [Windows.Forms.AnchorStyles]::Top, [Windows.Forms.AnchorStyles]::Right, [Windows.Forms.AnchorStyles]::Left
} else {
    $buttonRibbon.RightToLeft = "No"
    $buttonRibbon.Anchor = [Windows.Forms.AnchorStyles]::Top, [Windows.Forms.AnchorStyles]::Left, [Windows.Forms.AnchorStyles]::Right
}

function msrdCreateButtons {
    param (
        [string]$name,
        $elements,
        $xPosStart,
        [switch]$addSeparator,
        $xOffsetAR
    )

    # Define the dictionary for storing buttons
    $ButtonDictionary = @{}

    $xPos = 0
    $buttonHeight = 65
    $buttonVerticalOffset = 22  # Vertical offset for buttons

    $buttonArea = New-Object Windows.Forms.Panel

    if ($global:msrdLangID -eq "AR") {
        $arlocx = $global:msrdForm.ClientSize.Width - $xPosStart - $xOffsetAR
        $buttonArea.Location = New-Object Drawing.Point($arlocx, 0)
        $buttonArea.Anchor = 'Top,Right'
    } else {
        $buttonArea.Location = New-Object Drawing.Point($xPosStart, 0)
    }

    $buttonArea.BackColor = "Transparent"
    $buttonRibbon.Controls.Add($buttonArea)

    $elements.GetEnumerator() | ForEach-Object -Process {
        $elementName = $_.Key
        $elementIcon = $_.Value

        $button = New-Object Windows.Forms.Button
        $button.Width = 65
        $button.Height = $buttonHeight
        $button.FlatStyle = 'Flat'
        $button.Font = New-Object System.Drawing.Font($button.Font.FontFamily, 8)
        $button.FlatAppearance.BorderSize = 0
        $button.ImageAlign = [System.Drawing.ContentAlignment]::TopCenter  # Align image to the top center
        $button.TextAlign = [System.Drawing.ContentAlignment]::BottomCenter  # Align text to the bottom center
        $button.Location = New-Object Drawing.Point($xPos, 0)
        $xPos += $button.Width

        $button.Image = $elementIcon.ToBitmap() # Load the icon from the file
        $button.Text = $elementName
        $button.TextImageRelation = "ImageAboveText"  # Display the image above the text
        $button.BackColor = "Transparent"

        # Attach the MouseEnter event handler
        $button.add_MouseEnter({
            $this.Cursor = [System.Windows.Forms.Cursors]::Hand
        })

        # Attach the MouseLeave event handler
        $button.add_MouseLeave({
            $this.Cursor = [System.Windows.Forms.Cursors]::Default
        })

        # Add the button to the dictionary
        $ButtonDictionary[$elementName] = $button

        $buttonArea.Controls.Add($button)
    }

    $buttonArea.Width = $xPos + 2
    $buttonArea.Height = $buttonHeight + $buttonVerticalOffset  # Include offset in height

    # Calculate the label position to center it within the buttonArea below the buttons
    $label = New-Object Windows.Forms.Label
    $label.Text = $name
    $label.TextAlign = [System.Drawing.ContentAlignment]::TopCenter
    $label.Width = $buttonArea.Width - 4
    $label.Height = $label.PreferredHeight
    $labelLocationX = ($buttonArea.Width - $label.Width) / 2
    $labelLocationY = $buttonHeight # Adjust vertical position to be just below the buttons
    $label.Location = New-Object Drawing.Point($labelLocationX, $labelLocationY)
    $buttonArea.Controls.Add($label)  # Add the label to the buttonArea
    $label.BackColor = "Transparent"

    if ($AddSeparator) {
        # Add a separator (vertical line) after the last button
        $separator = New-Object Windows.Forms.Label
        $separator.BackColor = "Gray"
        $separator.Width = 1  # Width of the separator
        $separator.Height = $buttonHeight + $labelLocationY
        $separator.Location = New-Object Drawing.Point($xPos, 0)  # Position the separator after the last button
        $buttonArea.Controls.Add($separator)
    }

    # Return the dictionary of buttons
    return $ButtonDictionary, $label
}

#initialize machine settings
function msrdSetMachine {
    param (
		[string]$Machine
	)

    $msrdComputerBox.Enabled = $true

    #AVD
    if ($Machine -eq "AVD") {
        if (-not $global:msrdAVD) {
            $global:msrdAVD = $true; $global:msrdRDS = $False; $global:msrdW365 = $False
            $MachineDictionary["AVD"].BackColor = "LightBlue"
            $MachineDictionary["RDS"].BackColor = "Transparent"
            $MachineDictionary["W365"].BackColor = "Transparent"
            msrdInitButtons -ButtonDictionary $RoleDictionary -status $true
            $MachineDictionary["RDS"].Enabled = $False
            $MachineDictionary["W365"].Enabled = $False
        } else {
            $global:msrdAVD = $false; $global:msrdRDS = $false; $global:msrdW365 = $False
            if ($script:pidProc) {
                msrdAddOutputBoxLine "Previous PID selection reset - no process dump will be generated`n" "Yellow"
                $dumppidBox.SelectedValue = ""
                $script:pidProc = ""
            }

            $MachineDictionary["AVD"].BackColor = "Transparent"
            $MachineDictionary["RDS"].BackColor = "Transparent"
            $MachineDictionary["W365"].BackColor = "Transparent"
            msrdInitButtons -ButtonDictionary $MachineDictionary -status $true
            $global:msrdSource = $false; $global:msrdTarget = $false
            msrdInitButtons -ButtonDictionary $RoleDictionary -status $false
            msrdInitButtons -ButtonDictionary $ScenarioDictionary -status $false
            msrdInitButtons -ButtonDictionary $LiveDictionary -status $false
            msrdResetScenarioVariables
            $ActionDictionary["Start"].Enabled = $false
            $global:liveDiagTab.Visible = $false
            $msrdPsBox.Visible = $true
            $global:msrdLiveDiag = $False
        }

    #RDS
    } elseif ($Machine -eq "RDS") {
        if (-not $global:msrdRDS) {
            $global:msrdAVD = $False; $global:msrdRDS = $true; $global:msrdW365 = $False
            $MachineDictionary["AVD"].BackColor = "Transparent"
            $MachineDictionary["RDS"].BackColor = "LightBlue"
            $MachineDictionary["W365"].BackColor = "Transparent"
            msrdInitButtons -ButtonDictionary $RoleDictionary -status $true
            $MachineDictionary["AVD"].Enabled = $False
            $MachineDictionary["W365"].Enabled = $False

            $msrdComputerBox.Enabled = $false
            $msrdComputerBox.Text = $env:computerName
        } else {
            $global:msrdAVD = $false; $global:msrdRDS = $false; $global:msrdW365 = $False
            if ($script:pidProc) {
                msrdAddOutputBoxLine "Previous PID selection reset - no process dump will be generated`n" "Yellow"
                $dumppidBox.SelectedValue = ""
                $script:pidProc = ""
            }

            $MachineDictionary["AVD"].BackColor = "Transparent"
            $MachineDictionary["RDS"].BackColor = "Transparent"
            $MachineDictionary["W365"].BackColor = "Transparent"
            msrdInitButtons -ButtonDictionary $MachineDictionary -status $true
            $global:msrdSource = $false; $global:msrdTarget = $false
            msrdInitButtons -ButtonDictionary $RoleDictionary -status $false
            msrdInitButtons -ButtonDictionary $ScenarioDictionary -status $false
            msrdInitButtons -ButtonDictionary $LiveDictionary -status $false
            msrdResetScenarioVariables
            $ActionDictionary["Start"].Enabled = $false
            $global:liveDiagTab.Visible = $false
            $msrdPsBox.Visible = $true
            $global:msrdLiveDiag = $False

            $msrdComputerBox.Enabled = $true
            $msrdComputerBox.Text = $env:computerName
        }

    #W365
    } elseif ($Machine -eq "W365") {
        if (-not $global:msrdW365) {
            $global:msrdAVD = $False; $global:msrdRDS = $False; $global:msrdW365 = $true
            $MachineDictionary["AVD"].BackColor = "Transparent"
            $MachineDictionary["RDS"].BackColor = "Transparent"
            $MachineDictionary["W365"].BackColor = "LightBlue"
            msrdInitButtons -ButtonDictionary $RoleDictionary -status $true
            $MachineDictionary["AVD"].Enabled = $False
            $MachineDictionary["RDS"].Enabled = $False
        } else {
            $global:msrdAVD = $false; $global:msrdRDS = $false; $global:msrdW365 = $False
            if ($script:pidProc) {
                msrdAddOutputBoxLine "Previous PID selection reset - no process dump will be generated`n" "Yellow"
                $dumppidBox.SelectedValue = ""
                $script:pidProc = ""
            }

            $MachineDictionary["AVD"].BackColor = "Transparent"
            $MachineDictionary["RDS"].BackColor = "Transparent"
            $MachineDictionary["W365"].BackColor = "Transparent"
            msrdInitButtons -ButtonDictionary $MachineDictionary -status $true
            $global:msrdSource = $false; $global:msrdTarget = $false
            msrdInitButtons -ButtonDictionary $RoleDictionary -status $false
            msrdInitButtons -ButtonDictionary $ScenarioDictionary -status $false
            msrdInitButtons -ButtonDictionary $LiveDictionary -status $false
            msrdResetScenarioVariables
            $ActionDictionary["Start"].Enabled = $false
            $global:liveDiagTab.Visible = $false
            $msrdPsBox.Visible = $true
            $global:msrdLiveDiag = $False
        }
    }
}

#initialize role settings
function msrdSetRole {
    param (
		[string]$Role
	)

    if (-not $global:msrdRDS) { $msrdComputerBox.Enabled = $true }

    #source
    if ($Role -eq "Source") {
        msrdResetScenarioVariables
        if (-not $global:msrdSource) {
            $global:msrdSource = $true; $global:msrdTarget = $False
            $RoleDictionary["Source"].BackColor = "LightBlue"
            $RoleDictionary["Target"].BackColor = "Transparent"
            $RoleDictionary["Target"].Enabled = $false
            $ScenarioDictionary["Core"].BackColor = "LightBlue"
            $ScenarioDictionary["MSRA"].Enabled = $true
            $ScenarioDictionary["SCard"].Enabled = $true
            $ScenarioDictionary["ProcDump"].Enabled = $true
            $ScenarioDictionary["NetTrace"].Enabled = $true
            $ScenarioDictionary["DiagOnly"].Enabled = $true
            $LiveDictionary["LiveDiag"].Enabled = $true
            $ActionDictionary["Start"].Enabled = $true
            $RunMenuItem.Enabled = $true
        } else {
            $global:msrdSource = $false; $global:msrdTarget = $false
            $RoleDictionary["Source"].BackColor = "Transparent"
            $RoleDictionary["Target"].BackColor = "Transparent"
            $RoleDictionary["Target"].Enabled = $true
            $ScenarioDictionary["Core"].BackColor = "Transparent"
            $ScenarioDictionary["MSRA"].Enabled = $false
            $ScenarioDictionary["SCard"].Enabled = $false
            $ScenarioDictionary["ProcDump"].Enabled = $false
            $ScenarioDictionary["NetTrace"].Enabled = $false
            $ScenarioDictionary["DiagOnly"].Enabled = $false
            $LiveDictionary["LiveDiag"].Enabled = $false
            $LiveDictionary["LiveDiag"].BackColor = "Transparent"
            $ActionDictionary["Start"].Enabled = $false
            $RunMenuItem.Enabled = $false
            $global:liveDiagTab.Visible = $false
            $msrdPsBox.Visible = $true
            $global:msrdLiveDiag = $False
        }
        $ScenarioDictionary["DiagOnly"].BackColor = "Transparent"

    #target
    } elseif ($Role -eq "Target") {
        msrdResetScenarioVariables
        if (-not $global:msrdTarget) {
            $global:msrdSource = $False; $global:msrdTarget = $true
            $RoleDictionary["Source"].BackColor = "Transparent"
            $RoleDictionary["Target"].BackColor = "LightBlue"
            $RoleDictionary["Source"].Enabled = $false
            msrdInitButtons -ButtonDictionary $ScenarioDictionary -status $true
            msrdInitButtons -ButtonDictionary $LiveDictionary -status $true
            $ScenarioDictionary["Core"].BackColor = "LightBlue"
            $ScenarioDictionary["Core"].Enabled = $false
            $ActionDictionary["Start"].Enabled = $true
            $RunMenuItem.Enabled = $true

            if ($global:msrdRDS) {
                $ScenarioDictionary["Teams"].Enabled = $false
                $ScenarioDictionary["AppAttach"].Enabled = $false
                $ScenarioDictionary["HCI"].Enabled = $false
            } elseif ($global:msrdW365) {
                $ScenarioDictionary["AppAttach"].Enabled = $false
                $ScenarioDictionary["HCI"].Enabled = $false
            }
        } else {
            $global:msrdSource = $false; $global:msrdTarget = $false
            $RoleDictionary["Source"].BackColor = "Transparent"
            $RoleDictionary["Target"].BackColor = "Transparent"
            $RoleDictionary["Source"].Enabled = $true
            msrdInitButtons -ButtonDictionary $ScenarioDictionary -status $false
            msrdInitButtons -ButtonDictionary $LiveDictionary -status $false
            $ScenarioDictionary["Core"].BackColor = "Transparent"
            $ScenarioDictionary["Core"].Enabled = $false
            $ActionDictionary["Start"].Enabled = $false
            $RunMenuItem.Enabled = $false
            $global:liveDiagTab.Visible = $false
            $msrdPsBox.Visible = $true
            $global:msrdLiveDiag = $False
        }
    }
}


#initialize scenario settings
function msrdSetScenario {
    param ( [array]$Scenario, $Status )

    foreach ($scen in $scenario) {
        $variableName = "v$scen"
        if ($Status) {
            $ScenarioDictionary["$scen"].BackColor = "LightBlue"
        } else {
            $ScenarioDictionary["$scen"].BackColor = "Transparent"
        }
        Set-Variable -Name $variableName -Value $Status -Scope Script
    }
}

#initialize button status
function msrdInitButtons {
    param ($ButtonDictionary, $status)

    $ButtonDictionary.Values | ForEach-Object {
        $_.BackColor = "Transparent"
        $_.Enabled = $status
    }

    $global:msrdPsBox.Visible = $true
}

#reset all
function msrdResetAll {
    $global:msrdAVD = $false; $global:msrdRDS = $false; $global:msrdW365 = $False
    if ($script:pidProc) {
        msrdAddOutputBoxLine "Previous PID selection reset - no process dump will be generated`n" "Yellow"
        $dumppidBox.SelectedValue = ""
        $script:pidProc = ""
    }

    $MachineDictionary["AVD"].BackColor = "Transparent"
    $MachineDictionary["RDS"].BackColor = "Transparent"
    $MachineDictionary["W365"].BackColor = "Transparent"
    msrdInitButtons -ButtonDictionary $MachineDictionary -status $true
    $global:msrdSource = $false; $global:msrdTarget = $false
    msrdInitButtons -ButtonDictionary $RoleDictionary -status $false
    msrdInitButtons -ButtonDictionary $ScenarioDictionary -status $false
    msrdInitButtons -ButtonDictionary $LiveDictionary -status $false
    msrdResetScenarioVariables
    $ActionDictionary["Start"].Enabled = $false
    $global:liveDiagTab.Visible = $false
    $msrdPsBox.Visible = $true
    $global:msrdLiveDiag = $False
}

#reset scenario variables
function msrdResetScenarioVariables {
    $script:vCore = $script:varsCore
    $script:vProfiles = $script:varsNO
    $script:vActivation = $script:varsNO
    $script:vMSRA = $script:varsNO
    $script:vSCard = $script:varsNO
    $script:vIME = $script:varsNO
    $script:vTeams = $script:varsNO
    $script:vMSIXAA = $script:varsNO
    $script:vHCI = $script:varsNO
    $script:dumpProc = $False
    $script:traceNet = $False
    $global:onlyDiag = $False
}

#write to output box only
function SwitchLiveDiagToPsBox {

    if ($global:msrdLiveDiag) {
        $global:msrdLiveDiag = $False
        if ($global:msrdTarget) {
            msrdInitButtons -ButtonDictionary $ScenarioDictionary -status $true
            msrdInitButtons -ButtonDictionary $LiveDictionary -status $true
            $ScenarioDictionary["Core"].Enabled = $false
        } else {
            $ScenarioDictionary["DiagOnly"].Enabled = $true
        }
		$LiveDictionary["LiveDiag"].BackColor = "Transparent"
        $ScenarioDictionary["Core"].BackColor = "LightBlue"
        $ActionDictionary["Start"].Enabled = $true
        $msrdPsBox.Visible = $true
        $global:liveDiagTab.Visible = $false
        Remove-Module MSRDC-Diagnostics
    }
}

Function msrdAddOutputBoxLine {
    param ([string[]]$Message, $Color, $switchColor, [switch]$noNewLine, $outputFile, $addAssist)

    if ($Color) { $txtColor = $Color } else { $txtColor = "White" }
    if ($switchColor) { $swColor = $switchColor } else { $swColor = "Yellow" }

    if ($global:msrdLiveDiag) {
        if ($global:msrdLiveDiagSystem) {
            $psBoxMain = $psBoxLiveDiagSystem
        } elseif ($global:msrdLiveDiagAVDRDS) {
            $psBoxMain = $psBoxLiveDiagAVDRDS
        } elseif ($global:msrdLiveDiagAVDInfra) {
            $psBoxMain = $psBoxLiveDiagAVDInfra
        } elseif ($global:msrdLiveDiagAD) {
            $psBoxMain = $psBoxLiveDiagAD
        } elseif ($global:msrdLiveDiagNet) {
            $psBoxMain = $psBoxLiveDiagNet
        } elseif ($global:msrdLiveDiagLogonSec) {
            $psBoxMain = $psBoxLiveDiagLogonSec
        } elseif ($global:msrdLiveDiagIssues) {
            $psBoxMain = $psBoxLiveDiagIssues
        } elseif ($global:msrdLiveDiagOther) {
            $psBoxMain = $psBoxLiveDiagOther
        }
    } else {
        $psBoxMain = $msrdPsBox
        if ($global:msrdLangID -eq "AR") { $psBoxMain.RightToLeft = "Yes" } else { $psBoxMain.RightToLeft = "No" }
    }

    foreach ($msg in $Message) {
        if ($noNewLine) { $line = "$msg" } else { $line = "$msg`r`n" }

        if ($switchColor) {
            $patterns = @("Step \d:", "Step \d+[a-zA-Z]:", #EN
                "Schritt \d:", "Schritt \d+[a-zA-Z]:", #DE
                "Étape \d:", "Étape \d+[a-zA-Z]:", #FR
                "Lépés \d:", "Lépés \d+[a-zA-Z]:", #HU
                "Stap \d:", "Stap \d+[a-zA-Z]:", #NL
                "Passo \d:", "Passo \d+[a-zA-Z]:", #IT
                "Pasul \d:", "Pasul \d+[a-zA-Z]:", #RO
                "ステップ \d:", "ステップ \d+[a-zA-Z]:", #JA
                "الخطوة \d:", "الخطوة \d+[\u0600-\u06FF]:", #AR
                "Adım \d:", "Adım \d+[a-zA-Z]:", #TR
                "步骤 \d:", "步骤 \d+[a-zA-Z]:") #CN

            # Find matches of the pattern in the line
            $linematches = foreach ($pattern in $patterns) {
                [regex]::Matches($line, $pattern)
            }

            # Set the default color for the entire line
            $psBoxMain.SelectionStart = $psBoxMain.TextLength
            $psBoxMain.SelectionLength = 0
            $psBoxMain.SelectionColor = $txtColor
            $psBoxMain.AppendText($line)

            # Set the color for each matched pattern
            foreach ($linematch in $linematches) {
                $startIndex = $linematch.Index
                $length = $linematch.Length
                $psBoxMain.Select($psBoxMain.TextLength - $line.Length + $startIndex, $length)
                $psBoxMain.SelectionColor = $swColor
                $psBoxMain.SelectionLength = 0
            }
        } else {
            $psBoxMain.SelectionStart = $psBoxMain.TextLength
            $psBoxMain.SelectionLength = 0
            $psBoxMain.SelectionColor = $txtColor
            $psBoxMain.AppendText($line)
        }

        if ($addAssist) {
            msrdLogMessageAssistMode $line
        }

        $psBoxMain.SelectionStart = $psBoxMain.TextLength
        $psBoxMain.ScrollToCaret()
        $psBoxMain.Refresh()
    }
}

#display the initial how to steps
function msrdInitHowTo {

    # How To Steps
    msrdAddOutputBoxLine -Message ("$(msrdGetLocalizedText 'howtouse')`n") -switchColor "Cyan"
    $global:msrdPsBox.ReadOnly = $true
}

#reset the output box
function msrdResetOutputBox {
    $global:msrdPsBox.Clear()
    msrdInitScript -Type GUI
    msrdInitHowTo
    $global:msrdPsBox.Refresh()
    $global:msrdPsBox.ScrollToCaret()
}

#find folder for output location
function msrdFindFolder {
    Param ([ValidateScript({Test-Path $_ -PathType Container})][string]$DefaultFolder = 'C:\MS_DATA\', $AppliesTo)

    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

    $browse = New-Object System.Windows.Forms.FolderBrowserDialog
    $browse.SelectedPath = $DefaultFolder
    $browse.ShowNewFolderButton = $true
    $browse.Description = msrdGetLocalizedText "location1"

    $result = $browse.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        if ($AppliesTo -eq "Script") {
            $global:msrdLogRoot = $browse.SelectedPath
            msrdAddOutputBoxLine "$(msrdGetLocalizedText "location2") $global:msrdLogRoot`n" -Color Yellow
        } elseif ($AppliesTo -eq "ScheduledTask") {
            $outputLocationTextBox.Text = $browse.SelectedPath
        }
    }
    else {
        if ($AppliesTo -eq "Script") {
            msrdAddOutputBoxLine "$(msrdGetLocalizedText "location2") $global:msrdLogRoot`n" -Color Yellow
        }
        return
    }

    $browse.SelectedPath
    $browse.Dispose()
}

#create the main menu entries
function msrdCreateMenu([string]$Text) {

    $Menu = New-Object System.Windows.Forms.ToolStripMenuItem
    $Menu.Text = msrdGetLocalizedText $Text
    $Menu.Add_MouseEnter({ $this.Owner.Cursor = [System.Windows.Forms.Cursors]::Hand })
    $Menu.Add_MouseLeave({ $this.Owner.Cursor = [System.Windows.Forms.Cursors]::Default })

    return $Menu
}

#create the items under the main menu entries
function msrdCreateMenuItem([System.Windows.Forms.ToolStripMenuItem]$Menu, [string]$Text, $Icon, [switch]$SkipLocalizedText) {

    if ($Text -eq "---") {
        $MenuItem = New-Object System.Windows.Forms.ToolStripSeparator
    } else {
        $MenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
        if (!($SkipLocalizedText)) {
            $MenuItem.Text = msrdGetLocalizedText $Text
        } else {
            $MenuItem.Text = $Text
        }
        $MenuItem.Add_MouseEnter({ $this.Owner.Cursor = [System.Windows.Forms.Cursors]::Hand })
        $MenuItem.Add_MouseLeave({ $this.Owner.Cursor = [System.Windows.Forms.Cursors]::Default })
        if ($Icon) {
            $MenuItem.Image = $Icon.ToBitmap()
        }
    }

    [void]$Menu.DropDownItems.Add($MenuItem)

    return $menuItem
}

#remote data collection
function msrdRunRemoteScript {
    param (
        [string]$RemoteComputer
    )

    try {
        # Create a PSSession to the remote computer
        $PSSession = try {
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'remotePSinitLocalCred') $RemoteComputer" -Color Yellow
            New-PSSession -ComputerName $RemoteComputer -ErrorAction Stop -EnableNetworkAccess
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'remotePSinitLocalCredSuccess') $RemoteComputer" -Color Lightgreen

        } catch [System.Management.Automation.RuntimeException] {
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'remotePSinitLocalCredFail') $RemoteComputer" -Color Yellow
                if ($global:msrdPlaySounds -eq 1) { msrdPlaySystemSound "Windows Exclamation" }

                try {
                    New-PSSession -ComputerName $RemoteComputer -Credential (Get-Credential -Message "$(msrdGetLocalizedText 'remotePSenterCred') $RemoteComputer" -Verbose $null) -ErrorAction Stop
                    msrdAddOutputBoxLine "$(msrdGetLocalizedText 'remotePSinitProvCredSuccess') $RemoteComputer" -Color Lightgreen
                } catch {
                    $failedCommand = $_.InvocationInfo.Line.TrimStart()
			        $errorMessage = $_.Exception.Message.TrimStart()
			        msrdAddOutputBoxLine -Message "Error in $failedCommand $errorMessage`n" -Color Magenta
                    if ($global:msrdPlaySounds -eq 1) { msrdPlaySystemSound "Windows Exclamation" }
			        return
                }
		} catch {
            $failedCommand = $_.InvocationInfo.Line.TrimStart()
			$errorMessage = $_.Exception.Message.TrimStart()
			msrdAddOutputBoxLine -Message "Error in $failedCommand $errorMessage`n" -Color Magenta
            if ($global:msrdPlaySounds -eq 1) { msrdPlaySystemSound "Windows Exclamation" }
			return
        }

        #copying script files to remote computer
        msrdAddOutputBoxLine "$(msrdGetLocalizedText "remotePScopy") $RemoteComputer" -Color Yellow

        $sourcePath = $global:msrdScriptpath
        $destinationPath = "\\$RemoteComputer\C`$\MS_DATA\MSRD-Collect"

        # Check if the destination directory exists, and create it if necessary
        if (-not (Test-Path -Path $destinationPath -PathType Container)) {
            New-Item -ItemType Directory -Path $destinationPath -Force
        } else {
            msrdAddOutputBoxLine "'$destinationPath' $(msrdGetLocalizedText 'remotePScopyExists') $RemoteComputer" -Color Yellow
        }

        # Get all files and subdirectories in the source path
        $items = Get-ChildItem -Path $sourcePath -Recurse

        foreach ($item in $items) {
            $relativePath = $item.FullName.Substring($sourcePath.Length + 1)
            $destinationItemPath = Join-Path -Path $destinationPath -ChildPath $relativePath

            # Get the file objects
            $sourceItem = Get-Item $item.FullName
            $destinationItem = Get-Item $destinationItemPath -ErrorAction SilentlyContinue

            # Compare file size and last write time
            if (($sourceItem.Length -ne $destinationItem.Length) -or ($sourceItem.LastWriteTime -gt $destinationItem.LastWriteTime)) {
                # Copy the file because it's different or newer
                Copy-Item -Path $item.FullName -Destination $destinationItemPath -Force
            }
        }

        # Run MSRD-Collect.ps1 on the remote machine
        $ScriptPath = "C:\MS_DATA\MSRD-Collect\MSRD-Collect.ps1"
        if ($global:msrdAVD) { $remoteMachine = "isAVD" } elseif ($global:msrdRDS) { $remoteMachine = "isRDS" } elseif ($global:msrdW365) { $remoteMachine = "isW365" }
        if ($global:msrdSource) { $remoteRole = "isSource" } elseif ($global:msrdTarget) { $remoteRole = "isTarget" }

        $dynamicParameters = [Ordered]@{
            AcceptEula = $true
            AcceptNotice = $true
            SkipAutoUpdate = $true
        }

        switch ($true) {
            { $global:msrdAVD } { $dynamicParameters += @{ Machine = 'isAVD' } }
            { $global:msrdRDS } { $dynamicParameters += @{ Machine = 'isRDS' } }
            { $global:msrdW365 } { $dynamicParameters += @{ Machine = 'isW365' } }
            { $global:msrdSource } { $dynamicParameters += @{ Role = 'isSource' } }
            { $global:msrdTarget } { $dynamicParameters += @{ Role = 'isTarget' } }
            { $script:vCore -ne $script:varsNO }       { $dynamicParameters += @{ Core = $true } }
            { $script:vProfiles -ne $script:varsNO }   { $dynamicParameters += @{ Profiles = $true } }
            { $script:vActivation -ne $script:varsNO } { $dynamicParameters += @{ Activation = $true } }
            { $script:vMSRA -ne $script:varsNO }       { $dynamicParameters += @{ MSRA = $true } }
            { $script:vSCard -ne $script:varsNO }      { $dynamicParameters += @{ SCard = $true } }
            { $script:vIME -ne $script:varsNO }        { $dynamicParameters += @{ IME = $true } }
            { $script:vTeams -ne $script:varsNO }      { $dynamicParameters += @{ Teams = $true } }
            { $script:vMSIXAA -ne $script:varsNO }     { $dynamicParameters += @{ MSIXAA = $true } }
            { $script:vHCI -ne $script:varsNO }        { $dynamicParameters += @{ HCI = $true } }
            { $script:dumpProc -and $script:pidProc -ne "" } { $dynamicParameters += @{ DumpPID = $script:pidProc } }
            { $script:traceNet }                { $dynamicParameters += @{ NetTrace = $true } }
            { $global:onlyDiag }                { $dynamicParameters += @{ DiagOnly = $true } }
        }

        $parametersString = $dynamicParameters | ConvertTo-Json

        # Run the script remotely and capture the output
        msrdAddOutputBoxLine "`n$(msrdGetLocalizedText 'remotePSlaunch1')`n$(msrdGetLocalizedText 'initvalues1c') $ScriptPath $parametersString`n" -Color Yellow
        Invoke-Command -Session $PSSession -ScriptBlock {
            param($ScriptPath, $dynamicParameters)

            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force -Scope Process
            & $ScriptPath @dynamicParameters

        } -ArgumentList $ScriptPath, $dynamicParameters | ForEach-Object {
            $global:msrdPsBox.AppendText("[$RemoteComputer] $_`r`n")
            $global:msrdPsBox.ScrollToCaret()
            $global:msrdPsBox.Refresh()
        }

        # Close the PSSession
        msrdAddOutputBoxLine "`n$(msrdGetLocalizedText 'remotePScomplete') $RemoteComputer`n" -Color Yellow
        Remove-PSSession -Session $PSSession

        # Open File Explorer on the remote machine
        Invoke-Command -ScriptBlock {
            Start-Process explorer.exe -ArgumentList "\\$RemoteComputer\C`$\MS_DATA\"
        }

    } catch {
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        $errorMessage = $_.Exception.Message.TrimStart()
        msrdAddOutputBoxLine -Message "`nError in $failedCommand $errorMessage`n" -Color Magenta
        if ($global:msrdPlaySounds -eq 1) { msrdPlaySystemSound "Windows Exclamation" }
    }

}

#action on pressing the start button
function msrdStartBtnCollect {
    param (
        $RemoteComputer
    )

    # Split the string into an array of computer names and trim spaces
    $computerArray = $RemoteComputer -split ';' | ForEach-Object { $_.Trim() }

    foreach ($target in $computerArray) {
        if ($target -ne $env:computerName) {

            if (($target.Trim() -eq "") -or ($target.Trim() -like "* *") -or ($target -like "*,*")) {
                msrdAddOutputBoxLine -Message "`n$(msrdGetLocalizedText 'remoteInvalidComp') $target`n" -Color Magenta
                if ($global:msrdPlaySounds -eq 1) { msrdPlaySystemSound "Windows Exclamation" }
                continue
            }

            # Check if the computer is reachable
            if (Test-Connection -ComputerName $target -Count 1 -Quiet) {
                msrdAddOutputBoxLine -Message "`n$(msrdGetLocalizedText 'remoteReach1') ($target) $(msrdGetLocalizedText 'remoteReach2')`n" -Color Lightgreen

                msrdRunRemoteScript -RemoteComputer $target

            } else {
                msrdAddOutputBoxLine -Message "`n$(msrdGetLocalizedText 'remoteReach1') ($target) $(msrdGetLocalizedText 'remoteReach3')`n" -Color Magenta
                if ($global:msrdPlaySounds -eq 1) { msrdPlaySystemSound "Windows Exclamation" }
            }

        } else {
            if ($script:vTeams -eq $script:varsTeams) {
                $TeamsLogs = msrdGetLocalizedText "teamsnote"
                $wshell = New-Object -ComObject Wscript.Shell
                $teamstitle = msrdGetLocalizedText "teamstitle"
                $answer = $wshell.Popup("$TeamsLogs",0,"$teamstitle",5+48)
                if ($answer -eq 4) { $GetTeamsLogs = $false } else { $GetTeamsLogs = $true }
            } else {
                $GetTeamsLogs = $false
            }

            msrdInitFolders

            if (($true -in $script:varsCore) -and (-not $global:msrdRDS) -and (-not $global:onlyDiag)) { msrdCloseMSRDC }

            if (-not $GetTeamsLogs) {
                $ActionDictionary["Start"].Text = msrdGetLocalizedText "Running"
                $ActionDictionary["Start"].BackColor = "LightBlue"

                $global:msrdProgbar.Visible = $true

                msrdLogMessage $LogLevel.InfoLogFileOnly "$(msrdGetLocalizedText initvalues1a) $global:msrdVersion $(msrdGetLocalizedText initvalues1b) $global:msrdScriptpath ($global:msrdAdminlevel)"
                msrdLogMessage $LogLevel.InfoLogFileOnly "$(msrdGetLocalizedText initvalues1c) $global:msrdCmdLine"
                msrdLogMessage $LogLevel.InfoLogFileOnly "$(msrdGetLocalizedText initvalues2)"
                msrdLogMessage $LogLevel.InfoLogFileOnly "$(msrdGetLocalizedText initvalues3) $global:msrdLogRoot"
                msrdLogMessage $LogLevel.InfoLogFileOnly "$(msrdGetLocalizedText initvalues4) $global:msrdUserprof`n"
                msrdLogMessage $LogLevel.InfoLogFileOnly "$(msrdGetLocalizedText dpidtext3) $script:pidProc"

                $selectedOptions = @()

                $options = @(
                    $machineDictionary["AVD"], $machineDictionary["RDS"], $machineDictionary["W365"],
                    $RoleDictionary["Source"], $RoleDictionary["Target"],
                    $ScenarioDictionary["Core"], $ScenarioDictionary["Profiles"], $ScenarioDictionary["Activation"], $ScenarioDictionary["MSRA"], $ScenarioDictionary["SCard"],
                    $ScenarioDictionary["IME"], $ScenarioDictionary["Teams"], $ScenarioDictionary["AppAttach"], $ScenarioDictionary["HCI"], $ScenarioDictionary["ProcDump"],
                    $ScenarioDictionary["NetTrace"], $ScenarioDictionary["DiagOnly"]
                )

                $selectedOptions = $options |
                    Where-Object { $_.BackColor -eq "LightBlue" } |
                    ForEach-Object { $_.Text }

                $selectedOptionsString = $selectedOptions -join ", "

                msrdLogMessage $LogLevel.InfoLogFileOnly "$(msrdGetLocalizedText 'selectedParam') $selectedOptionsString`n"

                [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::WaitCursor

                if (-not $global:onlyDiag) {
                    if ($script:vProfiles -eq $true) { $script:vProfiles = $script:varsProfiles }
                    if ($script:vActivation -eq $true) { $script:vActivation = $script:varsActivation }
                    if ($script:vMSRA -eq $true) { $script:vMSRA = $script:varsMSRA }
                    if ($script:vSCard -eq $true) { $script:vSCard = $script:varsSCard }
                    if ($script:vIME -eq $true) { $script:vIME = $script:varsIME }
                    if ($script:vTeams -eq $true) { $script:vTeams = $script:varsTeams }
                    if ($script:vMSIXAA -eq $true) { $script:vMSIXAA = $script:varsMSIXAA }
                    if ($script:vHCI -eq $true) { $script:vHCI = $script:varsHCI }

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
                $allVars = $script:varsSystem + $script:varsAVDRDS + $script:varsInfra + $script:varsAD + $script:varsNET + $script:varsLogSec + $script:varsIssues + $script:varsOther
                $allAreFalse = $allVars -notcontains $true
                if ($allAreFalse) {
                    msrdLogMessage $LogLevel.Info -Message "$(msrdGetLocalizedText 'noDiagmsg')`n" -Color "Cyan"
                } else {
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
                }

                msrdArchiveData -varsCore $script:vCore
                $ActionDictionary["Start"].Text = msrdGetLocalizedText "Start"
                $ActionDictionary["Start"].BackColor = "Transparent"

                [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::Default

                $global:msrdProgbar.Visible = $false
            }
        }
    }
}


#main GUI function for easier external reference
Function msrdAVDCollectGUI {

    $global:msrdForm = New-Object Windows.Forms.Form
    $global:msrdForm.Width = 1366
    $global:msrdForm.Height = 768
    $global:msrdForm.StartPosition = "CenterScreen"
    $global:msrdForm.BackColor = "#eeeeee"
    $global:msrdForm.Icon = $msrdcicon
    if ($global:msrdDevLevel -eq "Insider") {
        $global:msrdForm.Text = 'MSRD-Collect (v' + $global:msrdVersion + ') INSIDER Build - For Testing Purposes Only !'
    } else {
        $global:msrdForm.Text = 'MSRD-Collect (v' + $global:msrdVersion + ')'
    }
    $global:msrdForm.TopLevel = $true
    $global:msrdForm.TopMost = $false

    $global:msrdFormMenu = new-object System.Windows.Forms.MenuStrip
    $global:msrdFormMenu.Location = new-object System.Drawing.Point(0, 0)
    $global:msrdFormMenu.Size = new-object System.Drawing.Size(200, 24)
    $global:msrdFormMenu.BackColor = [System.Drawing.Color]::White

    if ($global:msrdLangID -eq "AR") { $global:msrdFormMenu.RightToLeft = "Yes" } else { $global:msrdFormMenu.RightToLeft = "No" }

    #region File menu
    $FileMenu = msrdCreateMenu -Text "FileMenu"

    $RunMenuItem = msrdCreateMenuItem -Menu $FileMenu -Text "RunMenu" -Icon $starticon
    $RunMenuItem.Enabled = $false
    $RunMenuItem.Add_Click({
        if ($env:computerName -eq $msrdComputerBox.Text) {
            msrdStartBtnCollect -RemoteComputer $msrdComputerBox.Text
        } else {
            $msg = "$(msrdGetLocalizedText 'remoteModeNotice1')`n`n$(msrdGetLocalizedText 'remoteModeNotice2')`n`n$(msrdGetLocalizedText 'remoteModeNotice3')`n`n$(msrdGetLocalizedText 'remoteModeNotice4')`n`n$(msrdGetLocalizedText 'remoteModeNotice5')"
			$result = [Windows.Forms.MessageBox]::Show($msg, "$(msrdGetLocalizedText 'popupWarning')", [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Warning)
			if ($result -eq "Yes") {
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'remoteMode')" -Color "Yellow"
                $global:msrdPsBox.BackColor = "black"
                $global:msrdStatusBarLabel.Text = "$(msrdGetLocalizedText 'remoteModeRunning')"
				msrdStartBtnCollect -RemoteComputer $msrdComputerBox.Text
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'localMode')`n" -Color "Yellow"
                $global:msrdPsBox.BackColor = "#012456"
                $global:msrdStatusBarLabel.Text = msrdGetLocalizedText "Ready"
			}
        }
    })

    msrdCreateMenuItem -Menu $FileMenu -Text "---" | Out-Null

    $CheckUpdMenuItem = msrdCreateMenuItem -Menu $FileMenu -Text "UpdateMenu" -Icon $searchicon
    $CheckUpdMenuItem.Add_Click({
        SwitchLiveDiagToPsBox
        if ($global:msrdScriptSelfUpdate -eq 1) {
            msrdCheckVersion($msrdVersion) -selfUpdate
        } else {
            msrdCheckVersion($msrdVersion)
        }
    })

    $LiteModeMenuItem = msrdCreateMenuItem -Menu $FileMenu -Text "LiteMode" -Icon $litemodeicon
    $LiteModeMenuItem.Add_Click({
        try {
            $ScriptFile = $global:msrdScriptpath + "\MSRD-Collect.ps1"
            Start-Process PowerShell.exe -ArgumentList "$ScriptFile -LiteMode" -NoNewWindow
            msrdUpdateConfigFile -configFile "Config\MSRDC-Config.cfg" -key "UILiteMode" -value 1
            If (($Null -ne $global:msrdTempCommandErrorFile) -and (Test-Path -Path $global:msrdTempCommandErrorFile)) { Remove-Item $global:msrdTempCommandErrorFile -Force | Out-Null }
            If ($global:fQuickEditCodeExist) { [msrdDisableConsoleQuickEdit]::SetQuickEdit($False) | Out-Null }
            if ($global:msrdGUI) { $global:msrdForm.Close() } else { Exit }
        } catch {
            $failedCommand = $_.InvocationInfo.Line.TrimStart()
            msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
        }
    })

    msrdCreateMenuItem -Menu $FileMenu -Text "---" | Out-Null

    $ExitMenuItem = msrdCreateMenuItem -Menu $FileMenu -Text "ExitMenu" -Icon $exiticon
    $ExitMenuItem.Add_Click({
        If (($Null -ne $global:msrdTempCommandErrorFile) -and (Test-Path -Path $global:msrdTempCommandErrorFile)) { Remove-Item $global:msrdTempCommandErrorFile -Force | Out-Null }
        If ($global:fQuickEditCodeExist) { [msrdDisableConsoleQuickEdit]::SetQuickEdit($False) | Out-Null }
        $global:msrdForm.Close()
    })
    #endregion File menu

    #region View menu
    $ViewMenu = msrdCreateMenu -Text "ViewMenu"

    $ConsoleMenuItem = msrdCreateMenuItem -Menu $ViewMenu -Text "HideConsole" -Icon $consoleicon
    $ConsoleMenuItem.CheckOnClick = $True
    $ConsoleMenuItem.Add_Click({
        SwitchLiveDiagToPsBox
        if ($ConsoleMenuItem.Checked) { msrdStartShowConsole; $ConsoleMenuItem.Checked = $true } else { msrdStartHideConsole; $ConsoleMenuItem.Checked = $false }
    })

    $MaximizeMenuItem = msrdCreateMenuItem -Menu $ViewMenu -Text "MaximizeWindow" -Icon $maximizedicon
    $MaximizeMenuItem.CheckOnClick = $True
    $MaximizeMenuItem.Add_Click({
        SwitchLiveDiagToPsBox
        if ($MaximizeMenuItem.Checked) {
            $global:msrdForm.WindowState = [System.Windows.Forms.FormWindowState]::Maximized
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'openMaximized')`n"
            $MaximizeMenuItem.Checked = $true
            if (!($nocfg)) {
                msrdUpdateConfigFile -configFile "Config\MSRDC-Config.cfg" -key "MaximizeWindow" -value 1
            }
        } else {
            $global:msrdForm.WindowState = [System.Windows.Forms.FormWindowState]::Normal
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'openWindowed')`n"
            $MaximizeMenuItem.Checked = $false
            if (!($nocfg)) {
                msrdUpdateConfigFile -configFile "Config\MSRDC-Config.cfg" -key "MaximizeWindow" -value 0
            }
        }
    })

    $OnTopMenuItem = msrdCreateMenuItem -Menu $ViewMenu -Text "AlwaysOnTop" -Icon $alwaysontopicon
    $OnTopMenuItem.CheckOnClick = $True
    $OnTopMenuItem.Checked = $false
    $OnTopMenuItem.Add_Click({
        SwitchLiveDiagToPsBox
        if ($OnTopMenuItem.Checked) {
            $global:msrdForm.TopMost = $true
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'ontop')`n"
        } else {
            $global:msrdForm.TopMost = $false
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'ontopNot')`n"
        }
    })

    $ResultsMenuItem = msrdCreateMenuItem -Menu $ViewMenu -Text "OutputLocation" -Icon $foldericon
    $ResultsMenuItem.Add_Click({
        If (Test-Path $global:msrdLogRoot) {
            explorer $global:msrdLogRoot
        } else {
            msrdAddOutputBoxLine "`n$(msrdGetLocalizedText 'outputNotFound')" "Yellow"
        }
    })

    #update text on menu items based on selected language
    Function msrdRefreshUILang {
        Param ($id, [switch]$restart)

        SwitchLiveDiagToPsBox
        $global:msrdOldLangID = $global:msrdLangID
        $global:msrdLangID = $id
        msrdUpdateConfigFile -configFile "Config\MSRDC-Config.cfg" -key "UILanguage" -value $id

        $langName = "UILanguage$id"
        $lang = Get-Variable -Name $langName -ValueOnly
        $lang.Checked = $true

        if ($restart) { msrdRestart }
    }

    $UILanguageMenuItem = msrdCreateMenuItem -Menu $ViewMenu -Text "UILang" -Icon $uilanguageicon

    $UILanguageAR = msrdCreateMenuItem -Menu $UILanguageMenuItem -Text "ara" -Icon $uilanguageicon
    $UILanguageAR.CheckOnClick = $True
    $UILanguageAR.Add_Click({ msrdRefreshUILang -id "AR" -restart $true })

    $UILanguageCN = msrdCreateMenuItem -Menu $UILanguageMenuItem -Text "chi" -Icon $uilanguageicon
    $UILanguageCN.CheckOnClick = $True
    $UILanguageCN.Add_Click({ msrdRefreshUILang -id "CN" -restart $true })

    $UILanguageCS = msrdCreateMenuItem -Menu $UILanguageMenuItem -Text "cze" -Icon $uilanguageicon
    $UILanguageCS.CheckOnClick = $True
    $UILanguageCS.Add_Click({ msrdRefreshUILang -id "CS" -restart $true })

    $UILanguageNL = msrdCreateMenuItem -Menu $UILanguageMenuItem -Text "dut" -Icon $uilanguageicon
    $UILanguageNL.CheckOnClick = $True
    $UILanguageNL.Add_Click({ msrdRefreshUILang -id "NL" -restart $true })

    $UILanguageEN = msrdCreateMenuItem -Menu $UILanguageMenuItem -Text "eng" -Icon $uilanguageicon
    $UILanguageEN.CheckOnClick = $True
    $UILanguageEN.Add_Click({ msrdRefreshUILang -id "EN" -restart $true })

    $UILanguageFR = msrdCreateMenuItem -Menu $UILanguageMenuItem -Text "fre" -Icon $uilanguageicon
    $UILanguageFR.CheckOnClick = $True
    $UILanguageFR.Add_Click({ msrdRefreshUILang -id "FR" -restart $true })

    $UILanguageDE = msrdCreateMenuItem -Menu $UILanguageMenuItem -Text "ger" -Icon $uilanguageicon
    $UILanguageDE.CheckOnClick = $True
    $UILanguageDE.Add_Click({ msrdRefreshUILang -id "DE" -restart $true })

    $UILanguageHU = msrdCreateMenuItem -Menu $UILanguageMenuItem -Text "hun" -Icon $uilanguageicon
    $UILanguageHU.CheckOnClick = $True
    $UILanguageHU.Add_Click({ msrdRefreshUILang -id "HU" -restart $true })

    $UILanguageIT = msrdCreateMenuItem -Menu $UILanguageMenuItem -Text "ita" -Icon $uilanguageicon
    $UILanguageIT.CheckOnClick = $True
    $UILanguageIT.Add_Click({ msrdRefreshUILang -id "IT" -restart $true })

    $UILanguageJP = msrdCreateMenuItem -Menu $UILanguageMenuItem -Text "jpn" -Icon $uilanguageicon
    $UILanguageJP.CheckOnClick = $True
    $UILanguageJP.Add_Click({ msrdRefreshUILang -id "JP" -restart $true })

    $UILanguagePT = msrdCreateMenuItem -Menu $UILanguageMenuItem -Text "por" -Icon $uilanguageicon
    $UILanguagePT.CheckOnClick = $True
    $UILanguagePT.Add_Click({ msrdRefreshUILang -id "PT" -restart $true })

    $UILanguageRO = msrdCreateMenuItem -Menu $UILanguageMenuItem -Text "rom" -Icon $uilanguageicon
    $UILanguageRO.CheckOnClick = $True
    $UILanguageRO.Add_Click({ msrdRefreshUILang -id "RO" -restart $true })

    $UILanguageES = msrdCreateMenuItem -Menu $UILanguageMenuItem -Text "spa" -Icon $uilanguageicon
    $UILanguageES.CheckOnClick = $True
    $UILanguageES.Add_Click({ msrdRefreshUILang -id "ES" -restart $true })

    $UILanguageTR = msrdCreateMenuItem -Menu $UILanguageMenuItem -Text "tur" -Icon $uilanguageicon
    $UILanguageTR.CheckOnClick = $True
    $UILanguageTR.Add_Click({ msrdRefreshUILang -id "TR" -restart $true })

    msrdCreateMenuItem -Menu $ViewMenu -Text "---" | Out-Null

    #diagnostic reports
    $ReportsMenuItem = msrdCreateMenuItem -Menu $ViewMenu -Text "DiagReports" -Icon $diagreporticon

    function addReportItems {

        msrdAddOutputBoxLine "$(msrdGetLocalizedText 'outputLoc1') ($global:msrdLogRoot)." -Color "Yellow"
        if (Test-Path $global:msrdLogRoot -PathType Container) {
            $RepFiles = Get-ChildItem $global:msrdLogRoot -Recurse -Include *MSRD-Diag.html* | ForEach-Object { $_.FullName }
            # add file names to menu
            if ($RepFiles) {
                $RepMenuItems = @()
                foreach ($RepFile in $RepFiles) {
                    $RepFolderName = Split-Path $RepFile -Parent | Split-Path -Leaf
                    if ($RepFolderName -match "^MSRD-Results-(.+)$") {
                        $RepMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
                        $RepMenuItem.Text = $Matches[1]
                        $RepMenuItem.Tag = $RepFile
                        $Icon = $diagreporticon
                        $RepMenuItem.Image = $Icon.ToBitmap()
                        $RepMenuItem.Add_Click({
                            if (Test-Path -Path $this.Tag) {
                                Invoke-Item $this.Tag
                            } else {
                                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'outputLoc2')`n" -Color "Red"
                            }
                        })
                        $RepMenuItems += $RepMenuItem
                        $RepMenuItems | Sort-Object -Descending Text | ForEach-Object { [void] $ReportsMenuItem.DropDownItems.Add($_) }
                    }
                }

                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'outputLoc3')`n" -Color "Lightgreen"
            } else {
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'outputLoc4') ($global:msrdLogRoot).`n$(msrdGetLocalizedText 'outputLoc5')`n" -Color "Yellow"
            }
        } else {
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'outputLoc6') ($global:msrdLogRoot).`n$(msrdGetLocalizedText 'outputLoc5')`n" -Color "Yellow"
        }
    }

    $ReportsMenuItem.Add_MouseEnter({
        $ReportsMenuItem.DropDownItems.Clear()
        addReportItems
    })

    #endregion View menu

    #region Tools menu
    $ToolsMenu = msrdCreateMenu -Text "ToolsMenu"

    $OutputMenuItem = msrdCreateMenuItem -Menu $ToolsMenu -Text "SetOutputLocation" -Icon $foldericon
    $OutputMenuItem.Add_Click({
        SwitchLiveDiagToPsBox
        msrdFindFolder -DefaultFolder "C:\" -AppliesTo "Script"
    })

    $UserContextMenuItem = msrdCreateMenuItem -Menu $ToolsMenu -Text "SetUserContext" -Icon $usercontexticon
    $UserContextMenuItem.Add_Click({
        SwitchLiveDiagToPsBox
        $userContextForm.ShowDialog() | Out-Null
    })

    msrdCreateMenuItem -Menu $ToolsMenu -Text "---" | Out-Null

    $ConfigCollectMenuItem = msrdCreateMenuItem -Menu $ToolsMenu -Text "ConfigDataCollection" -Icon $configicon
    $ConfigCollectMenuItem.Add_Click({
        SwitchLiveDiagToPsBox
        $selectCollectForm.ShowDialog() | Out-Null
    })

    $ConfigDiagMenuItem = msrdCreateMenuItem -Menu $ToolsMenu -Text "ConfigDiag" -Icon $configicon
    $ConfigDiagMenuItem.Add_Click({
        SwitchLiveDiagToPsBox
        $selectDiagForm.ShowDialog() | Out-Null
    })

    msrdCreateMenuItem -Menu $ToolsMenu -Text "---" | Out-Null

    $ConfigSchedTaskMenuItem = msrdCreateMenuItem -Menu $ToolsMenu -Text "ConfigSchedTask" -Icon $scheduledtaskicon
    $ConfigSchedTaskMenuItem.Add_Click({
        SwitchLiveDiagToPsBox
        $staskForm.ShowDialog() | Out-Null
    })

    $OpenTaskSchedMenuItem = msrdCreateMenuItem -Menu $ToolsMenu -Text "OpenTaskSched" -Icon $scheduledtaskicon
    $OpenTaskSchedMenuItem.Add_Click({
        Start-Process -FilePath "taskschd.msc"
    })

    msrdCreateMenuItem -Menu $ToolsMenu -Text "---" | Out-Null

    $global:AutoVerCheckMenuItem = msrdCreateMenuItem -Menu $ToolsMenu -Text "AutoVerCheck" -Icon $updateicon
    $global:AutoVerCheckMenuItem.CheckOnClick = $True
    if ($global:msrdAutoVerCheck -eq 1) {
        $global:AutoVerCheckMenuItem.Checked = $True
    }
    $global:AutoVerCheckMenuItem.Add_Click({
        SwitchLiveDiagToPsBox
        if ($global:AutoVerCheckMenuItem.Checked) {
            msrdUpdateConfigFile -configFile "Config\MSRDC-Config.cfg" -key "AutomaticVersionCheck" -value 1
            $global:msrdAutoVerCheck = 1
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'autoUpdate') $(msrdGetLocalizedText 'enabled')`n"
        } else {
            msrdUpdateConfigFile -configFile "Config\MSRDC-Config.cfg" -key "AutomaticVersionCheck" -value 0
            $global:msrdAutoVerCheck = 0
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'autoUpdate') $(msrdGetLocalizedText 'disabled')`n"
        }
    })

    $PlaySoundsMenuItem = msrdCreateMenuItem -Menu $ToolsMenu -Text "PlaySounds" -Icon $soundsystemicon
    $PlaySoundsMenuItem.CheckOnClick = $True
    if ($global:msrdPlaySounds -eq 1) {
        $PlaySoundsMenuItem.Checked = $True
    }
    $PlaySoundsMenuItem.Add_Click({
        SwitchLiveDiagToPsBox
        if ($PlaySoundsMenuItem.Checked) {
            msrdUpdateConfigFile -configFile "Config\MSRDC-Config.cfg" -key "PlaySounds" -value 1
            $global:msrdPlaySounds = 1
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'playSnd') $(msrdGetLocalizedText 'enabled')`n"
        } else {
            msrdUpdateConfigFile -configFile "Config\MSRDC-Config.cfg" -key "PlaySounds" -value 0
            $global:msrdPlaySounds = 0
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'playSnd') $(msrdGetLocalizedText 'disabled')`n"
        }
    })

    $AssistModeMenuItem = msrdCreateMenuItem -Menu $ToolsMenu -Text "AssistMode" -Icon $soundassisticon
    $AssistModeMenuItem.CheckOnClick = $True
    if ($global:msrdAssistMode -eq 1) {
        $AssistModeMenuItem.Checked = $True
    }
    $AssistModeMenuItem.Add_Click({
        SwitchLiveDiagToPsBox
        if ($AssistModeMenuItem.Checked) {
            msrdUpdateConfigFile -configFile "Config\MSRDC-Config.cfg" -key "AssistMode" -value 1
            $global:msrdAssistMode = 1
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'aaMode') $(msrdGetLocalizedText 'enabled')`n"
        } else {
            msrdUpdateConfigFile -configFile "Config\MSRDC-Config.cfg" -key "AssistMode" -value 0
            $global:msrdAssistMode = 0
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'aaMode') $(msrdGetLocalizedText 'disabled')`n"
        }
    })
    #endregion Tools menu

    #region Help menu
    $HelpMenu = msrdCreateMenu -Text "HelpMenu"

    $ReadMeMenuItem = msrdCreateMenuItem -Menu $HelpMenu -Text "ReadMe" -Icon $readmeicon
    $ReadMeMenuItem.Add_Click({
        $readmepath = (Get-Item .).FullName + "\MSRD-Collect-ReadMe.txt"
        notepad $readmepath
    })

    $WhatsNewMenuItem = msrdCreateMenuItem -Menu $HelpMenu -Text "WhatsNew" -Icon $whatsnewicon
    $WhatsNewMenuItem.Add_Click({
        $readmepath = (Get-Item .).FullName + "\MSRD-Collect-ReleaseNotes.txt"
        notepad $readmepath
    })

    #download menu
    $downloadicon = ([System.IconExtractor]::Extract("$global:msrdScriptpath\Config\MSRDC-Icons.dll", 7, $true))

    $DownloadMenuItem = msrdCreateMenuItem -Menu $HelpMenu -Text "Download" -Icon $downloadicon
    $DownloadMenuItemMSRDC = msrdCreateMenuItem -Menu $DownloadMenuItem -Text "DownloadMSRDC" -Icon $downloadicon
    $DownloadMenuItemMSRDC.Add_Click({ [System.Diagnostics.Process]::start("https://aka.ms/MSRD-Collect") })
    $DownloadMenuItemRDSTr = msrdCreateMenuItem -Menu $DownloadMenuItem -Text "DownloadRDSTracing" -Icon $downloadicon
    $DownloadMenuItemRDSTr.Add_Click({ [System.Diagnostics.Process]::start("http://aka.ms/RDSTracing") })
    $DownloadMenuItemRDSTr = msrdCreateMenuItem -Menu $DownloadMenuItem -Text "DownloadSaRA" -Icon $downloadicon
    $DownloadMenuItemRDSTr.Add_Click({ [System.Diagnostics.Process]::start("https://diagnostics.outlook.com/") })
    $DownloadMenuItemTSS = msrdCreateMenuItem -Menu $DownloadMenuItem -Text "DownloadTSS" -Icon $downloadicon
    $DownloadMenuItemTSS.Add_Click({ [System.Diagnostics.Process]::start("https://aka.ms/getTSS") })

    msrdCreateMenuItem -Menu $HelpMenu -Text "---" | Out-Null

    #azure submenu
    $AzureMenuItem = msrdCreateMenuItem -Menu $HelpMenu -Text "AzureMenu" -Icon $azureicon

    $AzureMenuItemOutageNote = msrdCreateMenuItem -Menu $AzureMenuItem -Text "AzOutageNotification" -Icon $azureicon
    $AzureMenuItemOutageNote.Add_Click({ Start-Process https://docs.microsoft.com/azure/azure-monitor/platform/alerts-activity-log-service-notifications })

    $AzureMenuItemStatus = msrdCreateMenuItem -Menu $AzureMenuItem -Text "AzStatus" -Icon $azureicon
    $AzureMenuItemStatus.Add_Click({ Start-Process https://status.azure.com })

    $AzureMenuItemStatusHist = msrdCreateMenuItem -Menu $AzureMenuItem -Text "AzStatusHist" -Icon $azureicon
    $AzureMenuItemStatusHist.Add_Click({ Start-Process https://azure.status.microsoft/en-us/status/history/ })

    $AzureMenuItemServHealth = msrdCreateMenuItem -Menu $AzureMenuItem -Text "AzServHealth" -Icon $azureicon
    $AzureMenuItemServHealth.Add_Click({ Start-Process https://portal.azure.com/#blade/Microsoft_Azure_Health/AzureHealthBrowseBlade })

    $AzureMenuItemAVDExpEstimator = msrdCreateMenuItem -Menu $AzureMenuItem -Text "AVDExpEstimator" -Icon $azureicon
    $AzureMenuItemAVDExpEstimator.Add_Click({ Start-Process https://azure.microsoft.com/en-gb/products/virtual-desktop/assessment })

    msrdCreateMenuItem -Menu $HelpMenu -Text "---" | Out-Null

    #docs submenu
    $docsicon = ([System.IconExtractor]::Extract("$global:msrdScriptpath\Config\MSRDC-Icons.dll", 6, $true))

    $DocsMenuItem = msrdCreateMenuItem -Menu $HelpMenu -Text "MSDocs" -Icon $docsicon
    $DocsMenuItemAVD = msrdCreateMenuItem -Menu $DocsMenuItem -Text "AVD" -Icon $docsicon
    $DocsMenuItemAVD.Add_Click({ Start-Process https://aka.ms/avddocs })

    $DocsMenuItemFSLogix = msrdCreateMenuItem -Menu $DocsMenuItem -Text "FSLogix" -Icon $docsicon
    $DocsMenuItemFSLogix.Add_Click({ Start-Process https://aka.ms/fslogix })

    $DocsMenuItemRDS = msrdCreateMenuItem -Menu $DocsMenuItem -Text "RDS" -Icon $docsicon
    $DocsMenuItemRDS.Add_Click({ Start-Process https://aka.ms/rds })

    $DocsMenuItemW365 = msrdCreateMenuItem -Menu $DocsMenuItem -Text "365" -Icon $docsicon
    $DocsMenuItemW365.Add_Click({ Start-Process https://aka.ms/w365docs })

    #techcommunity submenu
    $TCMenuItem = msrdCreateMenuItem -Menu $HelpMenu -Text "TechCommunity" -Icon $docsicon
    $TCMenuItemAVD = msrdCreateMenuItem -Menu $TCMenuItem -Text "TCAVD" -Icon $docsicon
    $TCMenuItemAVD.Add_Click({ Start-Process https://aka.ms/avdtechcommunity })

    $TCMenuItemFSLogix = msrdCreateMenuItem -Menu $TCMenuItem -Text "TCFSLogix" -Icon $docsicon
    $TCMenuItemFSLogix.Add_Click({ Start-Process https://techcommunity.microsoft.com/t5/fslogix/bd-p/FSLogix })

    $TCMenuItemW365 = msrdCreateMenuItem -Menu $TCMenuItem -Text "TC365" -Icon $docsicon
    $TCMenuItemW365.Add_Click({ Start-Process https://aka.ms/Community/Windows365 })

    msrdCreateMenuItem -Menu $HelpMenu -Text "---" | Out-Null

    $FeedbackMenuItem = msrdCreateMenuItem -Menu $HelpMenu -Text "FeedbackForm" -Icon $feedbackicon
    $FeedbackMenuItem.Add_Click({ [System.Diagnostics.Process]::start("https://aka.ms/MSRD-Collect-Feedback") })

    msrdCreateMenuItem -Menu $HelpMenu -Text "---" | Out-Null

    $AboutMenuItem = msrdCreateMenuItem -Menu $HelpMenu -Text "About" -Icon $abouticon
    $AboutMenuItem.Add_Click({
    [Windows.Forms.MessageBox]::Show("Microsoft CSS
Remote Desktop Data Collection and Diagnostics Script`n
Version:
        $msrdVersion`n
Author:
        Robert Klemencz (Microsoft CSS)`n
Contact:
        https://aka.ms/MSRD-Collect-Feedback
        MSRDCollectTalk@microsoft.com", "About", [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Information)
    })
    #endregion Help menu



    #region Presets menu
    function msrdSetPreset {
        param ( $Machine, $Role, [array]$Scenario, $Text )

        msrdResetAll
        msrdSetMachine -Machine $Machine
        msrdSetRole -Role $Role
        msrdSetScenario -Scenario $Scenario -Status $true
        $txt = msrdGetLocalizedText "$Text"
        msrdAddOutputBoxLine "$(msrdGetLocalizedText 'presetLoaded1'): " -Color Cyan -noNewLine
        msrdAddOutputBoxLine "$txt"
        msrdAddOutputBoxLine "$(msrdGetLocalizedText 'contextLabel'): " -Color Cyan -noNewLine
        msrdAddOutputBoxLine "$Machine"
        msrdAddOutputBoxLine "$(msrdGetLocalizedText 'roleLabel'): " -Color Cyan -noNewLine
        msrdAddOutputBoxLine "$Role"
        msrdAddOutputBoxLine "$(msrdGetLocalizedText 'scenarioLabel'): " -Color Cyan -noNewLine
        msrdAddOutputBoxLine "$Scenario"
        msrdAddOutputBoxLine "$(msrdGetLocalizedText 'presetLoaded2')`n" -Color Yellow
    }

    $PresetsMenu = msrdCreateMenu -Text "PresetsMenu"

    #avd
    $avdPresetMenuItem = msrdCreateMenuItem -Menu $PresetsMenu -Text "AVD" -Icon $machineavdicon

    $avdPresetErrcon1MenuItem = msrdCreateMenuItem -Menu $avdPresetMenuItem -Text "presetErrcon1" -Icon $machineavdicon #cannot connect source
    $avdPresetErrcon1MenuItem.Add_Click({ msrdSetPreset -Machine AVD -Role Source -Scenario @("Core") -Text "presetErrcon1" })

    $avdPresetErrcon2MenuItem = msrdCreateMenuItem -Menu $avdPresetMenuItem -Text "presetErrcon2" -Icon $machineavdicon #cannot connect target
    $avdPresetErrcon2MenuItem.Add_Click({ msrdSetPreset -Machine AVD -Role Target -Scenario @("Core") -Text "presetErrcon2" })

    $avdPresetLogon1MenuItem = msrdCreateMenuItem -Menu $avdPresetMenuItem -Text "presetLogon1" -Icon $machineavdicon #logon source
    $avdPresetLogon1MenuItem.Add_Click({ msrdSetPreset -Machine AVD -Role Source -Scenario @("Core") -Text "presetLogon1" })

    $avdPresetLogon2MenuItem = msrdCreateMenuItem -Menu $avdPresetMenuItem -Text "presetLogon2" -Icon $machineavdicon #logon target
    $avdPresetLogon2MenuItem.Add_Click({ msrdSetPreset -Machine AVD -Role Target -Scenario @("Core", "Profiles") -Text "presetLogon2" })

    $avdPresetScard1MenuItem = msrdCreateMenuItem -Menu $avdPresetMenuItem -Text "presetScard1" -Icon $machineavdicon #scard source
    $avdPresetScard1MenuItem.Add_Click({ msrdSetPreset -Machine AVD -Role Source -Scenario @("Core", "SCard") -Text "presetScard1" })

    $avdPresetScard2MenuItem = msrdCreateMenuItem -Menu $avdPresetMenuItem -Text "presetScard2" -Icon $machineavdicon #scard target
    $avdPresetScard2MenuItem.Add_Click({ msrdSetPreset -Machine AVD -Role Target -Scenario @("Core", "Profiles", "SCard") -Text "presetScard2" })

    $avdPresetMsixaaMenuItem = msrdCreateMenuItem -Menu $avdPresetMenuItem -Text "presetMsixaa" -Icon $machineavdicon #msixaa target
    $avdPresetMsixaaMenuItem.Add_Click({ msrdSetPreset -Machine AVD -Role Target -Scenario @("Core", "Profiles", "AppAttach") -Text "presetMsixaa" })

    $avdPresetLic3MenuItem = msrdCreateMenuItem -Menu $avdPresetMenuItem -Text "presetLic3" -Icon $machineavdicon #rd licensing target
    $avdPresetLic3MenuItem.Add_Click({ msrdSetPreset -Machine AVD -Role Target -Scenario @("Core") -Text "presetLic3" })

    $avdPresetMSRA1MenuItem = msrdCreateMenuItem -Menu $avdPresetMenuItem -Text "presetMSRA1" -Icon $machineavdicon #MSRA, QA or RH issues / source
    $avdPresetMSRA1MenuItem.Add_Click({ msrdSetPreset -Machine AVD -Role Source -Scenario @("Core", "MSRA") -Text "presetMSRA1" })

    $avdPresetMSRA2MenuItem = msrdCreateMenuItem -Menu $avdPresetMenuItem -Text "presetMSRA2" -Icon $machineavdicon #MSRA, QA or RH issues / target
    $avdPresetMSRA2MenuItem.Add_Click({ msrdSetPreset -Machine AVD -Role Target -Scenario @("Core", "MSRA") -Text "presetMSRA2" })

    $avdPresetDiscon1MenuItem = msrdCreateMenuItem -Menu $avdPresetMenuItem -Text "presetDiscon1" -Icon $machineavdicon #unexpected disconnect source
    $avdPresetDiscon1MenuItem.Add_Click({ msrdSetPreset -Machine AVD -Role Source -Scenario @("Core") -Text "presetDiscon1" })

    $avdPresetDiscon2MenuItem = msrdCreateMenuItem -Menu $avdPresetMenuItem -Text "presetDiscon2" -Icon $machineavdicon #unexpected disconnect target
    $avdPresetDiscon2MenuItem.Add_Click({ msrdSetPreset -Machine AVD -Role Target -Scenario @("Core") -Text "presetDiscon2" })

    #rds
    $rdsPresetMenuItem = msrdCreateMenuItem -Menu $PresetsMenu -Text "RDS" -Icon $machinerdsicon

    $rdsPresetErrcon1MenuItem = msrdCreateMenuItem -Menu $rdsPresetMenuItem -Text "presetErrcon1" -Icon $machinerdsicon #cannot connect source
    $rdsPresetErrcon1MenuItem.Add_Click({ msrdSetPreset -Machine RDS -Role Source -Scenario @("Core") -Text "presetErrcon1" })

    $rdsPresetErrcon2MenuItem = msrdCreateMenuItem -Menu $rdsPresetMenuItem -Text "presetErrcon2" -Icon $machinerdsicon #cannot connect target
    $rdsPresetErrcon2MenuItem.Add_Click({ msrdSetPreset -Machine RDS -Role Target -Scenario @("Core") -Text "presetErrcon2" })

    $rdsPresetLogon1MenuItem = msrdCreateMenuItem -Menu $rdsPresetMenuItem -Text "presetLogon1" -Icon $machinerdsicon #logon source
    $rdsPresetLogon1MenuItem.Add_Click({ msrdSetPreset -Machine RDS -Role Source -Scenario @("Core") -Text "presetLogon1" })

    $rdsPresetLogon2MenuItem = msrdCreateMenuItem -Menu $rdsPresetMenuItem -Text "presetLogon2" -Icon $machinerdsicon #logon target
    $rdsPresetLogon2MenuItem.Add_Click({ msrdSetPreset -Machine RDS -Role Target -Scenario @("Core", "Profiles") -Text "presetLogon2" })

    $rdsPresetScard1MenuItem = msrdCreateMenuItem -Menu $rdsPresetMenuItem -Text "presetScard1" -Icon $machinerdsicon #scard source
    $rdsPresetScard1MenuItem.Add_Click({ msrdSetPreset -Machine RDS -Role Source -Scenario @("Core", "SCard") -Text "presetScard1" })

    $rdsPresetScard2MenuItem = msrdCreateMenuItem -Menu $rdsPresetMenuItem -Text "presetScard2" -Icon $machinerdsicon #scard target
    $rdsPresetScard2MenuItem.Add_Click({ msrdSetPreset -Machine RDS -Role Target -Scenario @("Core", "Profiles", "SCard") -Text "presetScard2" })

    $rdsPresetLic1MenuItem = msrdCreateMenuItem -Menu $rdsPresetMenuItem -Text "presetLic1" -Icon $machinerdsicon #rd licensing source
    $rdsPresetLic1MenuItem.Add_Click({ msrdSetPreset -Machine RDS -Role Source -Scenario @("Core") -Text "presetLic1" })

    $rdsPresetLic2MenuItem = msrdCreateMenuItem -Menu $rdsPresetMenuItem -Text "presetLic2" -Icon $machinerdsicon #rd licensing target
    $rdsPresetLic2MenuItem.Add_Click({ msrdSetPreset -Machine RDS -Role Target -Scenario @("Core") -Text "presetLic2" })

    $rdsPresetMSRA1MenuItem = msrdCreateMenuItem -Menu $rdsPresetMenuItem -Text "presetMSRA1" -Icon $machinerdsicon #MSRA, QA or RH issues / source
    $rdsPresetMSRA1MenuItem.Add_Click({ msrdSetPreset -Machine RDS -Role Source -Scenario @("Core", "MSRA") -Text "presetMSRA1" })

    $rdsPresetMSRA2MenuItem = msrdCreateMenuItem -Menu $rdsPresetMenuItem -Text "presetMSRA2" -Icon $machinerdsicon #MSRA, QA or RH issues / target
    $rdsPresetMSRA2MenuItem.Add_Click({ msrdSetPreset -Machine RDS -Role Target -Scenario @("Core", "MSRA") -Text "presetMSRA2" })

    $rdsPresetDiscon1MenuItem = msrdCreateMenuItem -Menu $rdsPresetMenuItem -Text "presetDiscon1" -Icon $machinerdsicon #unexpected disconnect source
    $rdsPresetDiscon1MenuItem.Add_Click({ msrdSetPreset -Machine RDS -Role Source -Scenario @("Core") -Text "presetDiscon1" })

    $rdsPresetDiscon2MenuItem = msrdCreateMenuItem -Menu $rdsPresetMenuItem -Text "presetDiscon2" -Icon $machinerdsicon #unexpected disconnect target
    $rdsPresetDiscon2MenuItem.Add_Click({ msrdSetPreset -Machine RDS -Role Target -Scenario @("Core") -Text "presetDiscon2" })

    #w365
    $w365PresetMenuItem = msrdCreateMenuItem -Menu $PresetsMenu -Text "365" -Icon $machinew365icon

    $w365PresetErrcon1MenuItem = msrdCreateMenuItem -Menu $w365PresetMenuItem -Text "presetErrcon1" -Icon $machinew365icon #cannot connect source
    $w365PresetErrcon1MenuItem.Add_Click({ msrdSetPreset -Machine W365 -Role Source -Scenario @("Core") -Text "presetErrcon1" })

    $w365PresetErrcon2MenuItem = msrdCreateMenuItem -Menu $w365PresetMenuItem -Text "presetErrcon2" -Icon $machinew365icon #cannot connect target
    $w365PresetErrcon2MenuItem.Add_Click({ msrdSetPreset -Machine W365 -Role Target -Scenario @("Core") -Text "presetErrcon2" })

    $w365PresetLogon1MenuItem = msrdCreateMenuItem -Menu $w365PresetMenuItem -Text "presetLogon1" -Icon $machinew365icon #logon source
    $w365PresetLogon1MenuItem.Add_Click({ msrdSetPreset -Machine W365 -Role Source -Scenario @("Core") -Text "presetLogon1" })

    $w365PresetLogon2MenuItem = msrdCreateMenuItem -Menu $w365PresetMenuItem -Text "presetLogon2" -Icon $machinew365icon #logon target
    $w365PresetLogon2MenuItem.Add_Click({ msrdSetPreset -Machine W365 -Role Target -Scenario @("Core", "Profiles") -Text "presetLogon2" })

    $w365PresetScard1MenuItem = msrdCreateMenuItem -Menu $w365PresetMenuItem -Text "presetScard1" -Icon $machinew365icon #scard source
    $w365PresetScard1MenuItem.Add_Click({ msrdSetPreset -Machine W365 -Role Source -Scenario @("Core", "SCard") -Text "presetScard1" })

    $w365PresetScard2MenuItem = msrdCreateMenuItem -Menu $w365PresetMenuItem -Text "presetScard2" -Icon $machinew365icon #scard target
    $w365PresetScard2MenuItem.Add_Click({ msrdSetPreset -Machine W365 -Role Target -Scenario @("Core", "Profiles", "SCard") -Text "presetScard2" })

    $w365PresetMSRA1MenuItem = msrdCreateMenuItem -Menu $w365PresetMenuItem -Text "presetMSRA1" -Icon $machinew365icon #MSRA, QA or RH issues / source
    $w365PresetMSRA1MenuItem.Add_Click({ msrdSetPreset -Machine W365 -Role Source -Scenario @("Core", "MSRA") -Text "presetMSRA1" })

    $w365PresetMSRA2MenuItem = msrdCreateMenuItem -Menu $w365PresetMenuItem -Text "presetMSRA2" -Icon $machinew365icon #MSRA, QA or RH issues / target
    $w365PresetMSRA2MenuItem.Add_Click({ msrdSetPreset -Machine W365 -Role Target -Scenario @("Core", "MSRA") -Text "presetMSRA2" })

    $w365PresetDiscon1MenuItem = msrdCreateMenuItem -Menu $w365PresetMenuItem -Text "presetDiscon1" -Icon $machinew365icon #unexpected disconnect source
    $w365PresetDiscon1MenuItem.Add_Click({ msrdSetPreset -Machine W365 -Role Source -Scenario @("Core") -Text "presetDiscon1" })

    $w365PresetDiscon2MenuItem = msrdCreateMenuItem -Menu $w365PresetMenuItem -Text "presetDiscon2" -Icon $machinew365icon #unexpected disconnect target
    $w365PresetDiscon2MenuItem.Add_Click({ msrdSetPreset -Machine W365 -Role Target -Scenario @("Core") -Text "presetDiscon2" })

    msrdCreateMenuItem -Menu $PresetsMenu -Text "---" | Out-Null

    $PresetResetMenuItem = msrdCreateMenuItem -Menu $PresetsMenu -Text "presetReset"
    $PresetResetMenuItem.Add_Click({ msrdResetAll })
    #endregion Presets menu

    $global:msrdFormMenu.Items.AddRange(@($FileMenu, $ViewMenu, $ToolsMenu, $PresetsMenu, $HelpMenu))

    if ($global:msrdMaximizeWindow -eq 1) {
        $global:msrdForm.WindowState = [System.Windows.Forms.FormWindowState]::Maximized
        $MaximizeMenuItem.Checked = $true
    } else {
        $global:msrdForm.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        $MaximizeMenuItem.Checked = $false
    }

    #computerbox
    $msrdComputerLabel = New-Object System.Windows.Forms.Label
    if ($global:msrdLangID -eq "AR") {
        $locx = $global:msrdForm.ClientSize.Width - 95
        $msrdComputerLabel.Location = New-Object System.Drawing.Point($locx, 117)
        $msrdComputerLabel.RightToLeft = "Yes"
        $msrdComputerLabel.Anchor = 'Top,Right'
    } else {
        $msrdComputerLabel.Location = New-Object System.Drawing.Point(5, 117)
        $msrdComputerLabel.Anchor = 'Top,Left'
    }

    $msrdComputerLabel.Size = New-Object System.Drawing.Size(90, 20)
    $msrdComputerLabel.Text = msrdGetLocalizedText "CompLabel"

    $global:msrdForm.Controls.Add($msrdComputerLabel)

    $msrdComputerBox = New-Object System.Windows.Forms.TextBox
    if ($global:msrdLangID -eq "AR") {
        $msrdComputerBox.RightToLeft = "Yes"
        $msrdComputerBox.Location = New-Object System.Drawing.Point(5, 114)
    } else {
        $msrdComputerBox.Location = New-Object System.Drawing.Point(95, 114)
    }

    $msrdComputerBox.Width = $global:msrdForm.ClientSize.Width - 105
    $msrdComputerBox.Anchor = 'Top,Left,Bottom,Right'
    $msrdComputerBox.Text = $env:computerName

    $msrdComputerBox.Add_MouseEnter({
        $btnTooltip.SetToolTip($msrdComputerBox, "$(msrdGetLocalizedText 'btnTooltipComputer')")
    })
    $global:msrdForm.Controls.Add($msrdComputerBox)

    #psbox
    $global:msrdPsBox = New-Object System.Windows.Forms.RichTextBox
    $global:msrdPsBox.Location = New-Object System.Drawing.Point(0, 140)

    if ($global:msrdLangID -eq "JP") {
        $global:msrdPsBox.Font = New-Object System.Drawing.Font("MS Gothic", 10)
    } else {
        $global:msrdPsBox.Font = New-Object System.Drawing.Font("Consolas", 10)
    }

    if ($global:msrdLangID -eq "AR") { $global:msrdPsBox.RightToLeft = "Yes" } else { $global:msrdPsBox.RightToLeft = "No" }

    $global:msrdPsBox.Height = $global:msrdForm.ClientSize.Height - 162
    $global:msrdPsBox.Width = $global:msrdForm.ClientSize.Width
    $global:msrdPsBox.Multiline = $True
    $global:msrdPsBox.ScrollBars = "Vertical"
    $global:msrdPsBox.BackColor = "#012456"
    $global:msrdPsBox.ForeColor = "White"
    $global:msrdPsBox.Anchor = 'Top,Left,Bottom,Right'
    $global:msrdPsBox.SelectionIndent = 10
    $global:msrdPsBox.SelectionRightIndent = 10

    $global:msrdForm.Controls.Add($global:msrdPsBox)

    # Create elements
    if ($global:msrdLangID -eq "AR") {
        $MachineElements = [Ordered]@{ "W365" = $machinew365icon; "RDS" = $machinerdsicon; "AVD" = $machineavdicon }
        $RoleElements = [Ordered]@{ "Target" = $roletargeticon; "Source" = $rolesourceicon }
        $ScenarioElements = [Ordered]@{
            "DiagOnly" = $scenariodiagonlyicon; "NetTrace" = $scenarionettraceicon; "ProcDump" = $scenarioprocdumpicon; "HCI" = $scenariohciicon
            "AppAttach" = $scenariomsixaaicon; "Teams" = $scenarioteamsicon; "IME" = $scenarioimeicon; "SCard" = $scenarioscardicon
            "MSRA" = $scenariomsraicon; "Activation" = $scenarioactivationicon; "Profiles" = $scenarioprofilesicon; "Core" = $scenariocoreicon
        }
        $ActionElements = [Ordered]@{ "$(msrdGetLocalizedText 'Feedback')" = $feedbackicon; "Start" = $starticon }

    } else {
        $MachineElements = [Ordered]@{ "AVD" = $machineavdicon; "RDS" = $machinerdsicon; "W365" = $machinew365icon }
        $RoleElements = [Ordered]@{ "Source" = $rolesourceicon; "Target" = $roletargeticon }
        $ScenarioElements = [Ordered]@{
            "Core" = $scenariocoreicon; "Profiles" = $scenarioprofilesicon; "Activation" = $scenarioactivationicon; "MSRA" = $scenariomsraicon
            "SCard" = $scenarioscardicon; "IME" = $scenarioimeicon; "Teams" = $scenarioteamsicon; "AppAttach" = $scenariomsixaaicon
            "HCI" = $scenariohciicon; "ProcDump" = $scenarioprocdumpicon; "NetTrace" = $scenarionettraceicon; "DiagOnly" = $scenariodiagonlyicon
        }
        $ActionElements = [Ordered]@{ "Start" = $starticon; "$(msrdGetLocalizedText 'Feedback')" = $feedbackicon }
    }

    $LiveElements = [Ordered]@{ "LiveDiag" = $scenariolivediagicon }

    if ($global:msrdLangID -eq "AR") {
        $MachineDictionary, $MachineLabel = msrdCreateButtons -name "$(msrdGetLocalizedText 'contextLabel')" -elements $MachineElements -xPosStart 0 -xOffsetAR 197
        $RoleDictionary, $RoleLabel = msrdCreateButtons -name "$(msrdGetLocalizedText 'roleLabel')" -elements $RoleElements -xPosStart 198 -addSeparator -xOffsetAR 132
        $ScenarioDictionary, $ScenarioLabel = msrdCreateButtons -name "$(msrdGetLocalizedText 'scenarioLabel')" -elements $ScenarioElements -xPosStart 331 -addSeparator -xOffsetAR 782
        $LiveDictionary, $LiveLabel = msrdCreateButtons -elements $LiveElements -xPosStart 1114 -addSeparator -xOffsetAR 67
        $ActionDictionary, $ActionLabel = msrdCreateButtons -elements $ActionElements -xPosStart 1182 -addSeparator -xOffsetAR 132
    } else {
        $MachineDictionary, $MachineLabel = msrdCreateButtons -name "$(msrdGetLocalizedText 'contextLabel')" -elements $MachineElements -xPosStart 0 -addSeparator
        $RoleDictionary, $RoleLabel = msrdCreateButtons -name "$(msrdGetLocalizedText 'roleLabel')" -elements $RoleElements -xPosStart 198 -addSeparator
        $ScenarioDictionary, $ScenarioLabel = msrdCreateButtons -name "$(msrdGetLocalizedText 'scenarioLabel')" -elements $ScenarioElements -xPosStart 331 -addSeparator
        $LiveDictionary, $LiveLabel = msrdCreateButtons -elements $LiveElements -xPosStart 1114 -addSeparator
        $ActionDictionary, $ActionLabel = msrdCreateButtons -elements $ActionElements -xPosStart 1182
    }

    $btnTooltip = New-Object Windows.Forms.ToolTip

    #Machine type events
    $machineDictionary["AVD"].Add_Click({ msrdSetMachine -Machine AVD })
    $btnTooltip.SetToolTip($machineDictionary["AVD"], "$(msrdGetLocalizedText 'btnTooltipAVD')")

    $machineDictionary["RDS"].Add_Click({ msrdSetMachine -Machine RDS })
    $btnTooltip.SetToolTip($machineDictionary["RDS"], "$(msrdGetLocalizedText 'btnTooltipRDS')")

    $machineDictionary["W365"].Add_Click({ msrdSetMachine -Machine W365 })
    $btnTooltip.SetToolTip($machineDictionary["W365"], "$(msrdGetLocalizedText 'btnTooltipW365')")


    #Role type events
    $RoleDictionary["Source"].Add_Click({ msrdSetRole -Role Source })
    $btnTooltip.SetToolTip($RoleDictionary["Source"], "$(msrdGetLocalizedText 'btnTooltipSource')")

    $RoleDictionary["Target"].Add_Click({ msrdSetRole -Role Target })
    $btnTooltip.SetToolTip($RoleDictionary["Target"], "$(msrdGetLocalizedText 'btnTooltipTarget')")

    #Scenario type events
    $ScenarioDictionary["Profiles"].Add_Click({
        if ($script:vProfiles -ne $script:varsProfiles) {
            msrdSetScenario -Scenario @("Profiles") -Status $true
        } else {
            msrdSetScenario -Scenario @("Profiles") -Status $false
        }
    })
    $btnTooltip.SetToolTip($ScenarioDictionary["Profiles"], "$(msrdGetLocalizedText 'btnTooltipProfiles')")

    $ScenarioDictionary["Activation"].Add_Click({
	    if ($script:vActivation -ne $script:varsActivation) {
            msrdSetScenario -Scenario @("Activation") -Status $true
	    } else {
		    msrdSetScenario -Scenario @("Activation") -Status $false
	    }
    })
    $btnTooltip.SetToolTip($ScenarioDictionary["Activation"], "$(msrdGetLocalizedText 'btnTooltipActivation')")

    $ScenarioDictionary["MSRA"].Add_Click({
	    if ($script:vMSRA -ne $script:varsMSRA) {
		    msrdSetScenario -Scenario @("MSRA") -Status $true
	    } else {
		    $script:vMSRA = $script:varsNO
		    msrdSetScenario -Scenario @("MSRA") -Status $false
	    }
    })
    $btnTooltip.SetToolTip($ScenarioDictionary["MSRA"], "$(msrdGetLocalizedText 'btnTooltipMSRA')")

    $ScenarioDictionary["SCard"].Add_Click({
	    if ($script:vSCard -ne $script:varsSCard) {
		    msrdSetScenario -Scenario @("SCard") -Status $true
	    } else {
		    msrdSetScenario -Scenario @("SCard") -Status $false
	    }
    })
    $btnTooltip.SetToolTip($ScenarioDictionary["SCard"], "$(msrdGetLocalizedText 'btnTooltipSCard')")

    $ScenarioDictionary["IME"].Add_Click({
	    if ($script:vIME -ne $script:varsIME) {
		    msrdSetScenario -Scenario @("IME") -Status $true
	    } else {
		    msrdSetScenario -Scenario @("IME") -Status $false
	    }
    })
    $btnTooltip.SetToolTip($ScenarioDictionary["IME"], "$(msrdGetLocalizedText 'btnTooltipIME')")

    $ScenarioDictionary["Teams"].Add_Click({
	    if ($script:vTeams -ne $script:varsTeams) {
		    msrdSetScenario -Scenario @("Teams") -Status $true
	    } else {
		    msrdSetScenario -Scenario @("Teams") -Status $false
	    }
    })
    $btnTooltip.SetToolTip($ScenarioDictionary["Teams"], "$(msrdGetLocalizedText 'btnTooltipTeams')")

    $ScenarioDictionary["AppAttach"].Add_Click({
	    if ($script:vMSIXAA -ne $script:varsMSIXAA) {
		    msrdSetScenario -Scenario @("AppAttach") -Status $true
	    } else {
		    msrdSetScenario -Scenario @("AppAttach") -Status $false
	    }
    })
    $btnTooltip.SetToolTip($ScenarioDictionary["AppAttach"], "$(msrdGetLocalizedText 'btnTooltipMSIXAA')")

    $ScenarioDictionary["HCI"].Add_Click({
	    if ($script:vHCI -ne $script:varsHCI) {
		    msrdSetScenario -Scenario @("HCI") -Status $true
	    } else {
		    msrdSetScenario -Scenario @("HCI") -Status $false
	    }
    })
    $btnTooltip.SetToolTip($ScenarioDictionary["HCI"], "$(msrdGetLocalizedText 'btnTooltipHCI')")

    $ScenarioDictionary["ProcDump"].Add_Click({
	    if ($script:dumpProc -ne $True) {
            GetProcDumpPID
            $dumppidForm.ShowDialog() | Out-Null
		    $script:dumpProc = $True
		    $ScenarioDictionary["ProcDump"].BackColor = "LightBlue"
	    } else {
		    $script:dumpProc = $False
		    $ScenarioDictionary["ProcDump"].BackColor = "Transparent"
	    }
    })
    $btnTooltip.SetToolTip($ScenarioDictionary["ProcDump"], "$(msrdGetLocalizedText 'btnTooltipProcDump')")

    $ScenarioDictionary["NetTrace"].Add_Click({
	    if ($script:traceNet -ne $True) {
		    $script:traceNet = $True
		    $ScenarioDictionary["NetTrace"].BackColor = "LightBlue"
	    } else {
		    $script:traceNet = $False
		    $ScenarioDictionary["NetTrace"].BackColor = "Transparent"
	    }
    })
    $btnTooltip.SetToolTip($ScenarioDictionary["NetTrace"], "$(msrdGetLocalizedText 'btnTooltipNetTrace')")

    $ScenarioDictionary["DiagOnly"].Add_Click({
	    if ($global:onlyDiag -ne $True) {
		    $global:onlyDiag = $true
		    $ScenarioDictionary["DiagOnly"].BackColor = "LightBlue"
            msrdSetScenario -Scenario @("Core") -Status $false
	    } else {
		    $global:onlyDiag = $false
		    $ScenarioDictionary["DiagOnly"].BackColor = "Transparent"
            msrdSetScenario -Scenario @("Core") -Status $True
	    }
    })
    $btnTooltip.SetToolTip($ScenarioDictionary["DiagOnly"], "$(msrdGetLocalizedText 'btnTooltipDiagOnly')")

    $LiveDictionary["LiveDiag"].Add_Click({
        if ($global:msrdRDS) {
            $global:liveDiagTab.TabPages.Clear()
            $global:liveDiagTab.TabPages.AddRange(@($liveDiagTabSystem, $liveDiagTabAVDRDS, $liveDiagTabAD, $liveDiagTabNet, $liveDiagTabLogonSec, $liveDiagTabIssues, $liveDiagTabOther))
        } else {
            $global:liveDiagTab.TabPages.Clear()
            $global:liveDiagTab.TabPages.AddRange(@($liveDiagTabSystem, $liveDiagTabAVDRDS, $liveDiagTabAVDInfra, $liveDiagTabAD, $liveDiagTabNet, $liveDiagTabLogonSec, $liveDiagTabIssues, $liveDiagTabOther))
        }

        if ($global:msrdAVD) {
            $msg = "AVD/RDS"
        } elseif ($global:msrdRDS) {
            $msg = "RDS"
	    } elseif ($global:msrdW365) {
            $msg = "AVD/RDS/W365"
        }
        $liveDiagTabAVDRDS.Text = $msg

	    if ($global:msrdLiveDiag -ne $True) {
		    $global:msrdLiveDiag = $True
            msrdInitButtons -ButtonDictionary $ScenarioDictionary -status $false
            msrdInitButtons -ButtonDictionary $LiveDictionary -status $false
            $LiveDictionary["LiveDiag"].Enabled = $true
		    $LiveDictionary["LiveDiag"].BackColor = "LightBlue"
            $ScenarioDictionary["Core"].BackColor = "Transparent"
            $ActionDictionary["Start"].Enabled = $false
            $msrdPsBox.Visible = $false
            $global:liveDiagTab.Visible = $true

            $msrdComputerBox.Enabled = $false
            $msrdComputerBox.Text = $env:computerName
            Import-Module -Name "$PSScriptRoot\MSRDC-Diagnostics" -DisableNameChecking -Force

	    } else {
		    $global:msrdLiveDiag = $False
            if ($global:msrdTarget) {
                msrdInitButtons -ButtonDictionary $ScenarioDictionary -status $true
                msrdInitButtons -ButtonDictionary $LiveDictionary -status $true
                $ScenarioDictionary["Core"].Enabled = $false
            } else {
                $ScenarioDictionary["DiagOnly"].Enabled = $true
            }
		    $LiveDictionary["LiveDiag"].BackColor = "Transparent"
            $ScenarioDictionary["Core"].BackColor = "LightBlue"
            $ActionDictionary["Start"].Enabled = $true
            $msrdPsBox.Visible = $true
            $global:liveDiagTab.Visible = $false

            if ($global:msrdRDS) {
                $msrdComputerBox.Enabled = $false
                $msrdComputerBox.Text = $env:computerName
            } else {
                $msrdComputerBox.Enabled = $true
                $msrdComputerBox.Text = $env:computerName
            }

            Remove-Module MSRDC-Diagnostics
	    }
    })
    $btnTooltip.SetToolTip($LiveDictionary["LiveDiag"], "$(msrdGetLocalizedText 'btnTooltipLiveDiag')")

    msrdInitButtons -ButtonDictionary $RoleDictionary -status $false
    msrdInitButtons -ButtonDictionary $ScenarioDictionary -status $false
    msrdInitButtons -ButtonDictionary $LiveDictionary -status $false

    $ActionDictionary["Start"].Enabled = $false
    $ActionDictionary["Start"].Add_Click({

        if ($env:computerName -eq $msrdComputerBox.Text) {
            msrdStartBtnCollect -RemoteComputer $msrdComputerBox.Text
        } else {
            $msg = "$(msrdGetLocalizedText 'remoteModeNotice1')`n`n$(msrdGetLocalizedText 'remoteModeNotice2')`n`n$(msrdGetLocalizedText 'remoteModeNotice3')`n`n$(msrdGetLocalizedText 'remoteModeNotice4')`n`n$(msrdGetLocalizedText 'remoteModeNotice5')"
			$result = [Windows.Forms.MessageBox]::Show($msg, "$(msrdGetLocalizedText 'popupWarning')", [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Warning)
			if ($result -eq "Yes") {
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'remoteMode')" -Color "Yellow"
                $global:msrdPsBox.BackColor = "black"
                $global:msrdStatusBarLabel.Text = "$(msrdGetLocalizedText 'remoteModeRunning')"
				msrdStartBtnCollect -RemoteComputer $msrdComputerBox.Text
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'localMode')`n" -Color "Yellow"
                $global:msrdPsBox.BackColor = "#012456"
                $global:msrdStatusBarLabel.Text = msrdGetLocalizedText "Ready"
			}
        }
    })
    $btnTooltip.SetToolTip($ActionDictionary["Start"], "$(msrdGetLocalizedText 'RunMenu')")

    $ActionDictionary["$(msrdGetLocalizedText 'Feedback')"].Add_Click({ [System.Diagnostics.Process]::start("https://aka.ms/MSRD-Collect-Feedback") })
    $ActionDictionary["$(msrdGetLocalizedText 'Feedback')"].BackColor = "LightYellow"
    $btnTooltip.SetToolTip($ActionDictionary["$(msrdGetLocalizedText 'Feedback')"], "$(msrdGetLocalizedText 'btnTooltipFeedback')")

    #region BottomOptions
    $global:msrdStatusBar = New-Object System.Windows.Forms.StatusStrip
    $global:msrdStatusBarLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $global:msrdStatusBarLabel.Text = "Ready"
    $global:msrdStatusBarLabel.Spring = $true
    $global:msrdStatusBarLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $global:msrdForm.Controls.Add($global:msrdStatusBar)

    $global:msrdProgbar = New-Object System.Windows.Forms.ToolStripProgressBar
    $global:msrdProgbar.Style = [Windows.Forms.ProgressBarStyle]::Continuous
    $global:msrdProgbar.Visible = $false  # Initially not visible
    $global:msrdProgbar.Step = 1
    $global:msrdProgbar.Size = New-Object System.Drawing.Size(300, 10)

    if ($global:msrdLangID -eq "AR") { $global:msrdStatusBar.RightToLeft = "Yes" } else { $global:msrdStatusBar.RightToLeft = "No" }
    $global:msrdStatusBar.Items.AddRange(@($global:msrdStatusBarLabel, $global:msrdProgbar)) | Out-Null
    #endregion BottomOptions


    #region dump
    function GetProcDumpPID {
        $script:datatable = New-Object system.Data.DataTable

        $col1 = New-Object system.Data.DataColumn "ProcPid",([string])
        $col2 = New-Object system.Data.DataColumn "ProcName",([string])
        $script:datatable.columns.add($col1)
        $script:datatable.columns.add($col2)
        $ddlist = Get-Process
        $excludedNames = @("Idle", "System", "Secure System", "csrss", "smss", "Registry")
        foreach ($dditem in $ddlist) {
            if ($dditem.Name -notin $excludedNames) {
                $datarow = $script:datatable.NewRow()
                $test = $dditem.Name + " (" + $dditem.Id + ")"
                $datarow.ProcPid = $dditem.Id
                $datarow.ProcName = $test
                $script:datatable.Rows.Add($datarow)
            }
        }

        $datarow0 = $script:datatable.NewRow()
        $datarow0.ProcPid = ""
        $defaultProc = msrdGetLocalizedText "dpidtext2"
        $datarow0.ProcName = $script:defaultProc
        $script:datatable.Rows.InsertAt($datarow0,0)

        $dumppidBox.Datasource = $script:datatable
        $dumppidBox.ValueMember = "ProcPid"
        $dumppidBox.DisplayMember = "ProcName"
    }

    #region DumpPID
    $dumppidForm = New-Object System.Windows.Forms.Form
    $dumppidForm.Width = 480
    $dumppidForm.Height = 110
    $dumppidForm.StartPosition = "CenterScreen"
    $dumppidForm.ControlBox = $False
    $dumppidForm.BackColor = "#eeeeee"
    $dumppidForm.Text = msrdGetLocalizedText "dpidtext1" #Select the running process to dump

    $dumppidBox = New-Object System.Windows.Forms.ComboBox
    $dumppidBox.Location  = New-Object System.Drawing.Point(25,25)
    $dumppidBox.Size  = New-Object System.Drawing.Point(250,30)
    $dumppidBox.DropDownWidth = 250
    $dumppidBox.DropDownStyle = "DropDownList"
    $dumppidBox.Items.Clear()
    $dumppidBox.Cursor = [System.Windows.Forms.Cursors]::Hand
    $dumppidBoxToolTip = New-Object System.Windows.Forms.ToolTip
    $dumppidBoxToolTip.SetToolTip($dumppidBox, "$(msrdGetLocalizedText "dpidtext1")")
    $dumppidForm.Controls.Add($dumppidBox)

    $dumppidOK = New-Object System.Windows.Forms.Button
    $dumppidOK.Location = New-Object System.Drawing.Size(300,21)
    $dumppidOK.Size = New-Object System.Drawing.Size(60,30)
    $dumppidOK.Text = "OK"
    $dumppidOK.BackColor = "#e6e6e6"
    $dumppidOK.Cursor = [System.Windows.Forms.Cursors]::Hand
    $dumppidForm.Controls.Add($dumppidOK)
    $dumppidOK.Add_Click({
        $dumppidForm.Close()
        if ($dumppidBox.SelectedValue -ne "") {
            $ScenarioDictionary["ProcDump"].BackColor = "LightBlue"
            $script:pidProc = $dumppidBox.SelectedValue
            $selectedIndex = $dumppidBox.SelectedIndex
            $nameProc = $script:datatable.Rows[$selectedIndex][1]
            msrdAddOutputBoxLine "$(msrdGetLocalizedText "dpidtext3") $nameProc`n" "Yellow"
        } else {
            $ScenarioDictionary["ProcDump"].BackColor = "Transparent"
            $script:pidProc = ""
            msrdAddOutputBoxLine "$(msrdGetLocalizedText "dpidtext4")`n" "Yellow"
            $script:dumpProc = $False
        }
    })

    $dumppidCancel = New-Object System.Windows.Forms.Button
    $dumppidCancel.Location = New-Object System.Drawing.Size(370,21)
    $dumppidCancel.Size = New-Object System.Drawing.Size(60,30)
    $dumppidCancel.Text = "Cancel"
    $dumppidCancel.BackColor = "#e6e6e6"
    $dumppidCancel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $dumppidForm.Controls.Add($dumppidCancel)
    $dumppidCancel.Add_Click({
        $dumppidForm.Close()
        if ($script:pidProc -ne "") {
            $ScenarioDictionary["ProcDump"].BackColor = "LightBlue"
            $dumppidBox.SelectedValue = $script:pidProc
            $selectedIndex = $dumppidBox.SelectedIndex
            $nameProc = $script:datatable.Rows[$selectedIndex][1]
            msrdAddOutputBoxLine "$(msrdGetLocalizedText "dpidtext3") $nameProc`n" "Yellow"
        } else {
            $ScenarioDictionary["ProcDump"].BackColor = "Transparent"
            $script:pidProc = ""
            $dumppidBox.SelectedValue = $script:pidProc
            msrdAddOutputBoxLine "$(msrdGetLocalizedText "dpidtext4")`n" "Yellow"
            $script:dumpProc = $False
        }
    })
    #endregion DumpPID


    #region data collection configuration form
    $selectCollectForm = New-Object System.Windows.Forms.Form
    $selectCollectForm.Width = 660
    $selectCollectForm.Height = 430
    $selectCollectForm.StartPosition = "CenterScreen"
    $selectCollectForm.MinimizeBox = $False
    $selectCollectForm.MaximizeBox = $False
    $selectCollectForm.BackColor = "#eeeeee"
    $selectCollectForm.Text = msrdGetLocalizedText "selectCollect1"
    $selectCollectForm.Icon = ([System.IconExtractor]::Extract("$global:msrdScriptpath\Config\MSRDC-Icons.dll", 3, $true))
    $selectCollectForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle

    $selectCollectLabel = New-Object System.Windows.Forms.Label
    $selectCollectLabel.Location  = New-Object System.Drawing.Point(10,10)
    $selectCollectLabel.Size  = New-Object System.Drawing.Point(620,50)
    $selectCollectLabel.Text = msrdGetLocalizedText "selectCollect2"
    if ($global:msrdLangID -eq "AR") { $selectCollectLabel.RightToLeft = "Yes" } else { $selectCollectLabel.RightToLeft = "No" }
    $selectCollectForm.Controls.Add($selectCollectLabel)

    # Label above the left box
    $lblIncludedC = New-Object System.Windows.Forms.Label
    $lblIncludedC.Location = New-Object System.Drawing.Point(20, 60)
    $lblIncludedC.Size = New-Object System.Drawing.Size(260, 20)
    $lblIncludedC.Text = msrdGetLocalizedText "selectCollect3"
    if ($global:msrdLangID -eq "AR") { $lblIncludedC.RightToLeft = "Yes" } else { $lblIncludedC.RightToLeft = "No" }
    $selectCollectForm.Controls.Add($lblIncludedC)

    # Create and populate left list with a hashtable
    $leftListC = New-Object System.Windows.Forms.ListBox
    $leftListC.Location = New-Object System.Drawing.Point(20,80)
    $leftListC.Size = New-Object System.Drawing.Size(250,300)
    $leftListC.SelectionMode = "MultiExtended"

    $leftItemsC = @(
        @("Activation", "Activation > 'licensingdiag' Information", 0),
        @("Activation", "Activation > 'slmgr /dlv' Information", 1),
        @("Activation", "Activation > List of domain KMS servers", 2),
        @("Core", "Core > Core AVD/RDS Information", 0),
        @("Core", "Core > Event Logs", 1),
        @("Core", "Core > Security Event Logs", 2),
        @("Core", "Core > Registry Keys", 3),
        @("Core", "Core > RDP, Network and AD Information", 4),
        @("Core", "Core > 'dsregcmd /status' Information", 5),
        @("Core", "Core > Scheduled Tasks Information", 6),
        @("Core", "Core > System Information", 7),
        @("Core", "Core > Windows Update history", 8),
        @("Core", "Core > MDM Information", 9),
        @("Core", "Core > RDS Roles Information", 10),
        @("Core", "Core > RDP Listener granular permissions", 11)
        @("HCI", "HCI > HCI Logs", 0),
        @("IME", "IME > Registry Keys", 0),
        @("IME", "IME > Tree Output of IME Folders", 1),
        @("MSIXAA", "AppAttach > Event Logs", 0),
        @("MSRA", "MSRA > Event Logs", 0),
        @("MSRA", "MSRA > Registry Keys", 1),
        @("MSRA", "MSRA > Groups Membership Information", 2),
        @("MSRA", "MSRA > Permissions", 3),
        @("MSRA", "MSRA > Scheduled Task Information", 4),
        @("MSRA", "MSRA > Remote Help Logs", 5),
        @("Profiles", "Profiles > Event Logs", 0),
        @("Profiles", "Profiles > Registry Keys", 1),
        @("Profiles", "Profiles > WhoAmI Information", 2),
        @("Profiles", "Profiles > FSLogix Information", 3),
        @("SCard", "SCard > Event Logs", 0),
        @("SCard", "SCard > 'certutil' Information", 1),
        @("SCard", "SCard > KDCProxy / RD Gateway Information", 2),
        @("Teams", "Teams > Registry Keys", 0),
        @("Teams", "Teams > Event Logs", 1),
        @("Teams", "Teams > Teams Logs", 2)
    )

    foreach ($pairC in $leftItemsC) {
        $leftListC.Items.Add($pairC[1]) | Out-Null
    }

    # Label above the right box
    $lblExcludedC = New-Object System.Windows.Forms.Label
    $lblExcludedC.Location = New-Object System.Drawing.Point(370, 60)
    $lblExcludedC.Size = New-Object System.Drawing.Size(260, 20)
    $lblExcludedC.Text = msrdGetLocalizedText "selectCollect4"
    if ($global:msrdLangID -eq "AR") { $lblExcludedC.RightToLeft = "Yes" } else { $lblExcludedC.RightToLeft = "No" }
    $selectCollectForm.Controls.Add($lblExcludedC)

    $rightListC = New-Object System.Windows.Forms.ListBox
    $rightListC.Location = New-Object System.Drawing.Point(370,80)
    $rightListC.Size = New-Object System.Drawing.Size(250,300)
    $rightListC.SelectionMode = "MultiExtended"

    $categoriesToVarsC = @{
        "Activation"  = $script:varsActivation
        "Core"        = $script:varsCore
        "IME"         = $script:varsIME
        "HCI"         = $script:varsHCI
        "MSIXAA"      = $script:varsMSIXAA
        "MSRA"        = $script:varsMSRA
        "Profiles"    = $script:varsProfiles
        "SCard"       = $script:varsSCard
        "Teams"       = $script:varsTeams
    }

    # Create buttons
    $btnAddC = New-Object System.Windows.Forms.Button
    $btnAddC.Location = New-Object System.Drawing.Point(290,120)
    $btnAddC.Size = New-Object System.Drawing.Size(60,23)
    $btnAddC.Text = ">"
    $btnAddC.Add_Click({
        $selectedItemsC = $leftListC.SelectedItems
        $itemsToAddC = @()

        foreach ($selectedItemC in $selectedItemsC) {
            $optionC = $leftItemsC | Where-Object { $_[1] -eq $selectedItemC }
            $categoryC = $optionC[0]
            $selectedVarsC = $categoriesToVarsC[$categoryC]
            if ($null -ne $selectedVarsC) {
                $selectedVarsC[$optionC[2]] = $false
            }

            $itemsToAddC += $selectedItemC
        }

        $rightListC.Items.AddRange($itemsToAddC)
        foreach ($itemC in $itemsToAddC) {
            $leftListC.Items.Remove($itemC)
        }

        $rightListC.Sorted = $true
    })

    $btnRemoveC = New-Object System.Windows.Forms.Button
    $btnRemoveC.Location = New-Object System.Drawing.Point(290,160)
    $btnRemoveC.Size = New-Object System.Drawing.Size(60,23)
    $btnRemoveC.Text = "<"
    $btnRemoveC.Add_Click({
        $selectedItemsC = $rightListC.SelectedItems
        $itemsToAddBackC = @()

        foreach ($selectedItemC in $selectedItemsC) {
            $optionC = $leftItemsC | Where-Object { $_[1] -eq $selectedItemC }
            $categoryC = $optionC[0]
            $selectedVarsC = $categoriesToVarsC[$categoryC]
            if ($null -ne $selectedVarsC) {
                $selectedVarsC[$optionC[2]] = $true
            }

            $itemsToAddBackC += $selectedItemC
        }

        $leftListC.Items.AddRange($itemsToAddBackC)
        foreach ($itemC in $itemsToAddBackC) {
            $rightListC.Items.Remove($itemC)
        }

        $leftListC.Sorted = $true
    })

    # Add controls to form
    $selectCollectForm.Controls.Add($leftListC)
    $selectCollectForm.Controls.Add($rightListC)
    $selectCollectForm.Controls.Add($btnAddC)
    $selectCollectForm.Controls.Add($btnRemoveC)

    #endregion data collection configuration form

    #region diagnostics configuration form
    $selectDiagForm = New-Object System.Windows.Forms.Form
    $selectDiagForm.Width = 660
    $selectDiagForm.Height = 430
    $selectDiagForm.StartPosition = "CenterScreen"
    $selectDiagForm.MinimizeBox = $False
    $selectDiagForm.MaximizeBox = $False
    $selectDiagForm.BackColor = "#eeeeee"
    $selectDiagForm.Text = msrdGetLocalizedText "selectDiag1"
    $selectDiagForm.Icon = ([System.IconExtractor]::Extract("$global:msrdScriptpath\Config\MSRDC-Icons.dll", 3, $true))
    $selectDiagForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle

    $selectDiagLabel = New-Object System.Windows.Forms.Label
    $selectDiagLabel.Location  = New-Object System.Drawing.Point(10,10)
    $selectDiagLabel.Size  = New-Object System.Drawing.Point(620,50)
    $selectDiagLabel.Text = msrdGetLocalizedText "selectDiag2"
    if ($global:msrdLangID -eq "AR") { $selectDiagLabel.RightToLeft = "Yes" } else { $selectDiagLabel.RightToLeft = "No" }
    $selectDiagForm.Controls.Add($selectDiagLabel)

    # Label above the left box
    $lblIncludedD = New-Object System.Windows.Forms.Label
    $lblIncludedD.Location = New-Object System.Drawing.Point(20, 60)
    $lblIncludedD.Size = New-Object System.Drawing.Size(260, 20)
    $lblIncludedD.Text = msrdGetLocalizedText "selectDiag3"
    if ($global:msrdLangID -eq "AR") { $lblIncludedD.RightToLeft = "Yes" } else { $lblIncludedD.RightToLeft = "No" }
    $selectDiagForm.Controls.Add($lblIncludedD)

    # Create and populate left list with a hashtable
    $leftListD = New-Object System.Windows.Forms.ListBox
    $leftListD.Location = New-Object System.Drawing.Point(20,80)
    $leftListD.Size = New-Object System.Drawing.Size(250,300)
    $leftListD.SelectionMode = "MultiExtended"

    $leftItemsD = @(
        @("Active Directory", "Active Directory > Microsoft Entra Join", 0),
        @("Active Directory", "Active Directory > Domain Controller", 1),
        @("AVD Infra", "AVD Infra > AVD Host Pool", 0),
        @("AVD Infra", "AVD Infra > AVD Agents/SxS Stack", 1),
        @("AVD Infra", "AVD Infra > AVD Health Check", 2),
        @("AVD Infra", "AVD Infra > AVD Required Endpoints", 3),
        @("AVD Infra", "AVD Infra > AVD Service URI Health", 4),
        @("AVD Infra", "AVD Infra > Azure Stack HCI", 5),
        @("AVD Infra", "AVD Infra > RDP Shortpath", 6),
        @("AVD Infra", "AVD Infra > Windows 365 Required Endpoints", 7),
        @("AVD/RDS/W365", "AVD/RDS/W365 > Redirection", 0),
        @("AVD/RDS/W365", "AVD/RDS/W365 > FSLogix", 1),
        @("AVD/RDS/W365", "AVD/RDS/W365 > Multimedia", 2),
        @("AVD/RDS/W365", "AVD/RDS/W365 > Quick Assist / Remote Help", 3),
        @("AVD/RDS/W365", "AVD/RDS/W365 > RDP / Listener", 4),
        @("AVD/RDS/W365", "AVD/RDS/W365 > RDS Roles", 5),
        @("AVD/RDS/W365", "AVD/RDS/W365 > Remote Desktop Clients", 6),
        @("AVD/RDS/W365", "AVD/RDS/W365 > Remote Desktop Licensing", 7),
        @("AVD/RDS/W365", "AVD/RDS/W365 > Session Time Limits", 8),
        @("AVD/RDS/W365", "AVD/RDS/W365 > Teams media optimization", 9),
        @("AVD/RDS/W365", "AVD/RDS/W365 > Windows 365 Boot", 10),
        @("Known Issues", "Known Issues > Event Logs", 0),
        @("Known Issues", "Known Issues > Logon/Logoff", 1),
        @("Logon/Security", "Logon/Security > Authentication / Logon", 0),
        @("Logon/Security", "Logon/Security > Security", 1),
        @("Networking", "Networking > Core NET", 0),
        @("Networking", "Networking > DNS", 1),
        @("Networking", "Networking > Firewall", 2),
        @("Networking", "Networking > IP Addresses", 3),
        @("Networking", "Networking > Port Usage", 4),
        @("Networking", "Networking > Proxy", 5),
        @("Networking", "Networking > Routing", 6),
        @("Networking", "Networking > VPN", 7),
        @("Other", "Other > Microsoft Office", 0),
        @("Other", "Other > Microsoft OneDrive", 1),
        @("Other", "Other > Printing", 2),
        @("Other", "Other > Third Party", 3),
        @("System", "System > Core", 0),
        @("System", "System > CPU Utilization", 1),
        @("System", "System > Drives", 2),
        @("System", "System > Graphics", 3),
        @("System", "System > OS Activation / Licensing", 4),
        @("System", "System > SSL / TLS", 5),
        @("System", "System > User Access Control (UAC)", 6)
        @("System", "System > Windows Installer", 7),
        @("System", "System > Windows Search", 8),
        @("System", "System > Windows Updates", 9),
        @("System", "System > WinRM / PowerShell", 10)
    )

    foreach ($pairD in $leftItemsD) {
        $leftListD.Items.Add($pairD[1]) | Out-Null
    }

    # Label above the right box
    $lblExcludedD = New-Object System.Windows.Forms.Label
    $lblExcludedD.Location = New-Object System.Drawing.Point(370, 60)
    $lblExcludedD.Size = New-Object System.Drawing.Size(260, 20)
    $lblExcludedD.Text = msrdGetLocalizedText "selectDiag4"
    if ($global:msrdLangID -eq "AR") { $lblExcludedD.RightToLeft = "Yes" } else { $lblExcludedD.RightToLeft = "No" }
    $selectDiagForm.Controls.Add($lblExcludedD)

    $rightListD = New-Object System.Windows.Forms.ListBox
    $rightListD.Location = New-Object System.Drawing.Point(370,80)
    $rightListD.Size = New-Object System.Drawing.Size(250,300)
    $rightListD.SelectionMode = "MultiExtended"

    $categoriesToVarsD = @{
        "System"           = $script:varsSystem
        "AVD/RDS/W365"     = $script:varsAVDRDS
        "AVD Infra"        = $script:varsInfra
        "Active Directory" = $script:varsAD
        "Networking"       = $script:varsNET
        "Logon/Security"   = $script:varsLogSec
        "Known Issues"     = $script:varsIssues
        "Other"            = $script:varsOther
    }

    # Create buttons
    $btnAddD = New-Object System.Windows.Forms.Button
    $btnAddD.Location = New-Object System.Drawing.Point(290,120)
    $btnAddD.Size = New-Object System.Drawing.Size(60,23)
    $btnAddD.Text = ">"
    $btnAddD.Add_Click({
        $selectedItemsD = $leftListD.SelectedItems
        $itemsToAddD = @()

        foreach ($selectedItemD in $selectedItemsD) {
            $optionD = $leftItemsD | Where-Object { $_[1] -eq $selectedItemD }
            $categoryD = $optionD[0]
            $selectedVarsD = $categoriesToVarsD[$categoryD]
            if ($null -ne $selectedVarsD) {
                $selectedVarsD[$optionD[2]] = $false
            }

            $itemsToAddD += $selectedItemD
        }

        $rightListD.Items.AddRange($itemsToAddD)
        foreach ($itemD in $itemsToAddD) {
            $leftListD.Items.Remove($itemD)
        }

        $rightListD.Sorted = $true
    })

    $btnRemoveD = New-Object System.Windows.Forms.Button
    $btnRemoveD.Location = New-Object System.Drawing.Point(290,160)
    $btnRemoveD.Size = New-Object System.Drawing.Size(60,23)
    $btnRemoveD.Text = "<"
    $btnRemoveD.Add_Click({
        $selectedItemsD = $rightListD.SelectedItems
        $itemsToAddBackD = @()

        foreach ($selectedItemD in $selectedItemsD) {
            $optionD = $leftItemsD | Where-Object { $_[1] -eq $selectedItemD }
            $categoryD = $optionD[0]
            $selectedVarsD = $categoriesToVarsD[$categoryD]
            if ($null -ne $selectedVarsD) {
                $selectedVarsD[$optionD[2]] = $true
            }

            $itemsToAddBackD += $selectedItemD
        }

        $leftListD.Items.AddRange($itemsToAddBackD)
        foreach ($itemD in $itemsToAddBackD) {
            $rightListD.Items.Remove($itemD)
        }

        $leftListD.Sorted = $true
    })

    $selectDiagForm.Controls.Add($leftListD)
    $selectDiagForm.Controls.Add($rightListD)
    $selectDiagForm.Controls.Add($btnAddD)
    $selectDiagForm.Controls.Add($btnRemoveD)

    #endregion diagnostics configuration form


    #region scheduled task configuration form

    $staskForm = New-Object System.Windows.Forms.Form
    $staskForm.Text = msrdGetLocalizedText "schedTaskCreate"
    $staskForm.Icon = $scheduledtaskicon
    $staskForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $staskForm.MinimizeBox = $false
    $staskForm.MaximizeBox = $false
    $staskForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $staskForm.Width = 500
    $staskForm.Height = 400
    if ($global:msrdLangID -eq "AR") { $staskForm.RightToLeft = "Yes" } else { $staskForm.RightToLeft = "No" }

    # controls
    $startDatePickerLabel = New-Object System.Windows.Forms.Label
    $startDatePickerLabel.Location  = New-Object System.Drawing.Point(10,10)
    $startDatePickerLabel.Size = New-Object System.Drawing.Size(100,20)
    $startDatePickerLabel.Text = msrdGetLocalizedText "schedTaskInfo2"
    $staskForm.Controls.Add($startDatePickerLabel)

    $startDatePicker = New-Object System.Windows.Forms.DateTimePicker
    $startDatePicker.Location  = New-Object System.Drawing.Point(120,10)
    $staskForm.Controls.Add($startDatePicker)


    $startTimePickerLabel = New-Object System.Windows.Forms.Label
    $startTimePickerLabel.Location  = New-Object System.Drawing.Point(10,40)
    $startTimePickerLabel.Size = New-Object System.Drawing.Size(100,20)
    $startTimePickerLabel.Text = msrdGetLocalizedText "schedTaskInfo3"
    $staskForm.Controls.Add($startTimePickerLabel)

    $startTimePicker = New-Object System.Windows.Forms.DateTimePicker
    $startTimePicker.Location  = New-Object System.Drawing.Point(120,40)
    $startTimePicker.Size = New-Object System.Drawing.Size(120,20)
    $startTimePicker.Format = [System.Windows.Forms.DateTimePickerFormat]::Custom
    $startTimePicker.CustomFormat = "HH:mm"
    $startTimePicker.ShowUpDown = $true
    $staskForm.Controls.Add($startTimePicker)


    $frequencyComboBoxLabel = New-Object System.Windows.Forms.Label
    $frequencyComboBoxLabel.Location  = New-Object System.Drawing.Point(10,70)
    $frequencyComboBoxLabel.Size = New-Object System.Drawing.Size(100,20)
    $frequencyComboBoxLabel.Text = msrdGetLocalizedText "schedTaskInfo4"
    $staskForm.Controls.Add($frequencyComboBoxLabel)

    $frequencyComboBox = New-Object System.Windows.Forms.ComboBox
    $frequencyComboBox.Location  = New-Object System.Drawing.Point(120,70)
    $frequencyComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $frequencyComboBox.Items.AddRange(@("Once", "Daily", "Weekly", "Monthly"))
    $staskForm.Controls.Add($frequencyComboBox)
    $frequencyComboBox.Add_SelectedIndexChanged({ UpdateFields })


    $dayOfWeekComboBoxLabel = New-Object System.Windows.Forms.Label
    $dayOfWeekComboBoxLabel.Location  = New-Object System.Drawing.Point(10,100)
    $dayOfWeekComboBoxLabel.Size = New-Object System.Drawing.Size(100,20)
    $dayOfWeekComboBoxLabel.Text = msrdGetLocalizedText "schedTaskInfo5"
    $staskForm.Controls.Add($dayOfWeekComboBoxLabel)

    $dayOfWeekComboBox = New-Object System.Windows.Forms.ComboBox
    $dayOfWeekComboBox.Location  = New-Object System.Drawing.Point(120,100)
    $dayOfWeekComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $dayOfWeekComboBox.Items.AddRange(@("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"))
    $staskForm.Controls.Add($dayOfWeekComboBox)
    $dayOfWeekComboBox.Add_SelectedIndexChanged({ UpdateFields })


    $weekOfMonthComboBoxLabel = New-Object System.Windows.Forms.Label
    $weekOfMonthComboBoxLabel.Location  = New-Object System.Drawing.Point(10,130)
    $weekOfMonthComboBoxLabel.Size = New-Object System.Drawing.Size(100,20)
    $weekOfMonthComboBoxLabel.Text = msrdGetLocalizedText "schedTaskInfo12"
    $staskForm.Controls.Add($weekOfMonthComboBoxLabel)

    $weekOfMonthComboBox = New-Object System.Windows.Forms.ComboBox
    $weekOfMonthComboBox.Location  = New-Object System.Drawing.Point(120,130)
    $weekOfMonthComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $weekOfMonthComboBox.Items.AddRange(@("First", "Second", "Third", "Fourth", "Last"))
    $staskForm.Controls.Add($weekOfMonthComboBox)
    $weekOfMonthComboBox.Add_SelectedIndexChanged({ UpdateFields })


    $machineTypeComboBoxLabel = New-Object System.Windows.Forms.Label
    $machineTypeComboBoxLabel.Location  = New-Object System.Drawing.Point(10,170)
    $machineTypeComboBoxLabel.Size = New-Object System.Drawing.Size(100,20)
    $machineTypeComboBoxLabel.Text = msrdGetLocalizedText "schedTaskInfo6"
    $staskForm.Controls.Add($machineTypeComboBoxLabel)

    $machineTypeComboBox = New-Object System.Windows.Forms.ComboBox
    $machineTypeComboBox.Location  = New-Object System.Drawing.Point(120,170)
    $machineTypeComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $machineTypeComboBox.Items.AddRange(@("AVD", "RDS", "W365"))
    $staskForm.Controls.Add($machineTypeComboBox)
    $machineTypeComboBox.Add_SelectedIndexChanged({ UpdateFields })


    $roleComboBoxLabel = New-Object System.Windows.Forms.Label
    $roleComboBoxLabel.Location  = New-Object System.Drawing.Point(10,200)
    $roleComboBoxLabel.Size = New-Object System.Drawing.Size(100,20)
    $roleComboBoxLabel.Text = msrdGetLocalizedText "schedTaskInfo7"
    $staskForm.Controls.Add($roleComboBoxLabel)

    $roleComboBox = New-Object System.Windows.Forms.ComboBox
    $roleComboBox.Location  = New-Object System.Drawing.Point(120,200)
    $roleComboBox.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $roleComboBox.Items.AddRange(@("Source", "Target"))
    $staskForm.Controls.Add($roleComboBox)
    $roleComboBox.Add_SelectedIndexChanged({ UpdateFields })


    $scriptLocationTextBoxLabel = New-Object System.Windows.Forms.Label
    $scriptLocationTextBoxLabel.Location  = New-Object System.Drawing.Point(10,230)
    $scriptLocationTextBoxLabel.Size = New-Object System.Drawing.Size(100,20)
    $scriptLocationTextBoxLabel.Text = msrdGetLocalizedText "schedTaskInfo8"
    $staskForm.Controls.Add($scriptLocationTextBoxLabel)

    $scriptLocationTextBox = New-Object System.Windows.Forms.TextBox
    $scriptLocationTextBox.Location  = New-Object System.Drawing.Point(120,230)
    $scriptLocationTextBox.Size = New-Object System.Drawing.Size(200,20)
    $scriptLocationTextBox.Text = "$global:msrdScriptpath\MSRD-Collect.ps1"
    $staskForm.Controls.Add($scriptLocationTextBox)

    $scriptLocationBrowseButton = New-Object System.Windows.Forms.Button
    $scriptLocationBrowseButton.Location  = New-Object System.Drawing.Point(330,230)
    $scriptLocationBrowseButton.Text = "Browse"
    $scriptLocationBrowseButton.Add_Click({
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "PowerShell Scripts (MSRD-Collect.ps1)|MSRD-Collect.ps1"
        $openFileDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')

        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $scriptLocationTextBox.Text = $openFileDialog.FileName
        }
    })
    $staskForm.Controls.Add($scriptLocationBrowseButton)


    $outputLocationTextBoxLabel = New-Object System.Windows.Forms.Label
    $outputLocationTextBoxLabel.Location  = New-Object System.Drawing.Point(10,270)
    $outputLocationTextBoxLabel.Size = New-Object System.Drawing.Size(100,20)
    $outputLocationTextBoxLabel.Text = msrdGetLocalizedText "schedTaskInfo9"
    $staskForm.Controls.Add($outputLocationTextBoxLabel)

    $outputLocationTextBox = New-Object System.Windows.Forms.TextBox
    $outputLocationTextBox.Location  = New-Object System.Drawing.Point(120,270)
    $outputLocationTextBox.Size = New-Object System.Drawing.Size(200,20)
    $outputLocationTextBox.Text = "C:\MS_DATA"
    $staskForm.Controls.Add($outputLocationTextBox)

    $outputLocationBrowseButton = New-Object System.Windows.Forms.Button
    $outputLocationBrowseButton.Location  = New-Object System.Drawing.Point(330,270)
    $outputLocationBrowseButton.Text = "Browse"
    $outputLocationBrowseButton.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $outputLocationTextBox.Text = $folderBrowser.SelectedPath
        }
    })
    $staskForm.Controls.Add($outputLocationBrowseButton)


    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location  = New-Object System.Drawing.Point(320,320)
    $okButton.Text = "OK"
    $okButton.Enabled = $false
    $staskForm.Controls.Add($okButton)

    function Show-ErrorMessage {
        param([string]$message)

        $caption = "Error"
        $buttons = [System.Windows.Forms.MessageBoxButtons]::OK
        $icon = [System.Windows.Forms.MessageBoxIcon]::Error

        [System.Windows.Forms.MessageBox]::Show($message, $caption, $buttons, $icon)
    }

    $okButton.Add_Click({
        $outputLocation = $outputLocationTextBox.Text
        $scriptLocation = $scriptLocationTextBox.Text

        if ([string]::IsNullOrWhiteSpace($outputLocation)) {
            $message = msrdGetLocalizedText "schedTaskEmpty1"
            Show-ErrorMessage -message $message

        } elseif ([string]::IsNullOrWhiteSpace($scriptLocation)) {
            $message = msrdGetLocalizedText "schedTaskEmpty2"
            Show-ErrorMessage -message $message

        } else {
            $isOutputLocationValid = Test-Path -Path $outputLocation
            $isScriptLocationValid = Test-Path -Path $scriptLocation

            if ($isOutputLocationValid -and $isScriptLocationValid) {
                $confirmed = Show-ConfirmationDialog
                if ($confirmed) {
                    CreateScheduledTask
                }
            } else {
                if (-not $isOutputLocationValid) {
                    $message = msrdGetLocalizedText "schedTaskNotFound1"
                    Show-ErrorMessage -message $message
                }

                if (-not $isScriptLocationValid) {
                    $message = msrdGetLocalizedText "schedTaskNotFound2"
                    Show-ErrorMessage -message $message
                }
            }
        }
    })

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location  = New-Object System.Drawing.Point(400,320)
    $cancelButton.Text = "Cancel"
    $staskForm.Controls.Add($cancelButton)

    $cancelButton.Add_Click({ $staskForm.Close() })


    # Function to update the enabled state of fields based on selected frequency
    function UpdateFields() {
        $frequency = if ($frequencyComboBox.SelectedItem) { $frequencyComboBox.SelectedItem.ToString() }

        switch ($frequency) {
            'Once' {
                    $dayOfWeekComboBox.Enabled = $false; $dayOfWeekComboBox.SelectedIndex = -1; $dayOfWeekComboBox.Text = "";
                    $weekOfMonthComboBox.Enabled = $false; $weekOfMonthComboBox.SelectedIndex = -1; $weekOfMonthComboBox.Text = "";
                    if ($startDatePicker.Text -ne "" -and $startTimePicker.Text -ne "" -and $frequencyComboBox.Text -ne "" -and
                        $machineTypeComboBox.Text -ne "" -and $roleComboBox.Text -ne "" -and $scriptLocationTextBox.Text -ne "" -and $outputLocationTextBox.Text -ne "") {
                        $okButton.Enabled = $true;
                    } else {
                        $okButton.Enabled = $false;
                    }
                }
            'Daily' {
                    $dayOfWeekComboBox.Enabled = $false; $dayOfWeekComboBox.SelectedIndex = -1; $dayOfWeekComboBox.Text = "";
                    $weekOfMonthComboBox.Enabled = $false; $weekOfMonthComboBox.SelectedIndex = -1; $weekOfMonthComboBox.Text = "";
                    if ($startDatePicker.Text -ne "" -and $startTimePicker.Text -ne "" -and $frequencyComboBox.Text -ne "" -and
                        $machineTypeComboBox.Text -ne "" -and $roleComboBox.Text -ne "" -and $scriptLocationTextBox.Text -ne "" -and $outputLocationTextBox.Text -ne "") {
                        $okButton.Enabled = $true;
                    } else {
                        $okButton.Enabled = $false;
                    }
                }
            'Weekly' {
                    $dayOfWeekComboBox.Enabled = $true;
                    $weekOfMonthComboBox.Enabled = $false; $weekOfMonthComboBox.SelectedIndex = -1; $weekOfMonthComboBox.Text = "";
                    if ($startDatePicker.Text -ne "" -and $startTimePicker.Text -ne "" -and $frequencyComboBox.Text -ne "" -and $dayOfWeekComboBox.Text -ne "" -and
                        $machineTypeComboBox.Text -ne "" -and $roleComboBox.Text -ne "" -and $scriptLocationTextBox.Text -ne "" -and $outputLocationTextBox.Text -ne "") {
                        $okButton.Enabled = $true;
                    } else {
                        $okButton.Enabled = $false;
                    }
                }
            'Monthly' {
                    $dayOfWeekComboBox.Enabled = $true;
                    $weekOfMonthComboBox.Enabled = $true;
                    if ($startDatePicker.Text -ne "" -and $startTimePicker.Text -ne "" -and $frequencyComboBox.Text -ne "" -and $dayOfWeekComboBox.Text -ne "" -and $weekOfMonthComboBox.Text -ne "" -and
                        $machineTypeComboBox.Text -ne "" -and $roleComboBox.Text -ne "" -and $scriptLocationTextBox.Text -ne "" -and $outputLocationTextBox.Text -ne "") {
                        $okButton.Enabled = $true;
                    } else {
                        $okButton.Enabled = $false;
                    }
                }
        }
    }


    function Get-ShortFileName {
        param (
            [Parameter(Mandatory = $true, ValueFromPipeline = $true)][Alias("FullName")][string]$Path
        )

        Add-Type -TypeDefinition @'
        using System;
        using System.Runtime.InteropServices;
        public class Win32Utils {
            [DllImport("kernel32.dll", CharSet = CharSet.Auto)]
            public static extern uint GetShortPathName(
                [MarshalAs(UnmanagedType.LPTStr)] string lpszLongPath,
                [MarshalAs(UnmanagedType.LPTStr)] System.Text.StringBuilder lpszShortPath,
                uint cchBuffer);
        }
'@

        $shortPath = New-Object System.Text.StringBuilder 256
        $result = [Win32Utils]::GetShortPathName($Path, $shortPath, $shortPath.Capacity)
        if ($result -gt 0) {
            return $shortPath.ToString().TrimEnd("`0")
        } else {
            throw "Failed to retrieve the short file name for '$Path'"
        }
    }

    function Show-ConfirmationDialog {
        $message = msrdGetLocalizedText "schedTaskNote"
        $caption = "Confirmation"
        $buttons = [System.Windows.Forms.MessageBoxButtons]::YesNo
        $icon = [System.Windows.Forms.MessageBoxIcon]::Warning

        $result = [System.Windows.Forms.MessageBox]::Show($message, $caption, $buttons, $icon)
        return ($result -eq [System.Windows.Forms.DialogResult]::Yes)
    }

    Function CreateScheduledTask {
        $trigger = $null
        $frequency = $frequencyComboBox.SelectedItem.ToString()
        $taskName = "MSRD-Collect Diagnostics Report ($frequency)"
        $selectedDate = $startDatePicker.Value.Date
        $selectedTime = $startTimePicker.Value.ToString("HH:mm")

        $machineType = $machineTypeComboBox.SelectedItem.ToString()
        $machineRole = $roleComboBox.SelectedItem.ToString()
        $outputLocation = $outputLocationTextBox.Text
        $scriptLocation = $scriptLocationTextBox.Text

        if (($frequency -eq "Weekly") -or ($frequency -eq "Monthly")) {
            $daysOfWeek = $dayOfWeekComboBox.SelectedItem.ToString()
        }
        if ($frequency -eq "Monthly") {
            $daysOfWeek = $daysOfWeek.Substring(0,3)
        }

        $selectedWeekOfMonth = $weekOfMonthComboBox.SelectedItem

        switch ($frequency) {
            "Once" {
                $trigger = New-ScheduledTaskTrigger -Once -At $selectedDate.Add($selectedTime)
            }
            "Daily" {
                $trigger = New-ScheduledTaskTrigger -Daily -At $selectedDate.Add($selectedTime)
            }
            "Weekly" {
                $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $daysOfWeek -At $selectedDate.Add($selectedTime)
            }
        }

        $scriptParameters = "-Machine is$machineType -Role is$machineRole -DiagOnly -AcceptEula -AcceptNotice -SkipAutoUpdate -OutputDir `"$outputLocation`""

        if ($trigger) {
            $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy RemoteSigned -File `"$scriptLocation`" $scriptParameters"
            $action2 = "PowerShell.exe -ExecutionPolicy RemoteSigned -File `"$scriptLocation`" $scriptParameters"
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -DontStopOnIdleEnd -RunOnlyIfNetworkAvailable -StartWhenAvailable
            Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -Settings $settings -User "NT AUTHORITY\SYSTEM" -Force
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo1')" -Color Yellow
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo2') " -Color Cyan -noNewLine
            $selectedDate = $selectedDate.ToString("yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
            msrdAddOutputBoxLine "$selectedDate"
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo3') " -Color Cyan -noNewLine
            msrdAddOutputBoxLine "$selectedTime"
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo4') " -Color Cyan -noNewLine
            msrdAddOutputBoxLine "$frequency"
            if ($frequency -eq "Weekly") {
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo5') " -Color Cyan -noNewLine
                msrdAddOutputBoxLine "$daysOfWeek"
            }
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo6') " -Color Cyan -noNewLine
            msrdAddOutputBoxLine "$machineType"
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo7') " -Color Cyan -noNewLine
            msrdAddOutputBoxLine "$machineRole"
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo8') " -Color Cyan -noNewLine
            msrdAddOutputBoxLine "$scriptLocation"
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo9') " -Color Cyan -noNewLine
            msrdAddOutputBoxLine "$outputLocation"
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo10') " -Color Cyan -noNewLine
            msrdAddOutputBoxLine "NT AUTHORITY\SYSTEM"
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo14') " -Color Cyan -noNewLine
            msrdAddOutputBoxLine "$action2`n`n"

        } else {
            if ($frequency -eq "Monthly") {

                # Generate the 8.3 short file name for the script location
                $shortScriptLocation = Get-ShortFileName -Path $scriptLocation
                $shortOutputLocation = Get-ShortFileName -Path $outputLocation

                $scriptParameters2 = "-Machine is$machineType -Role is$machineRole -DiagOnly -AcceptEula -AcceptNotice -SkipAutoUpdate -OutputDir $shortOutputLocation"
                $action2 = "PowerShell.exe -ExecutionPolicy Bypass -File $shortScriptLocation $scriptParameters2"

                $command = "schtasks.exe /Create /TN '" + $taskName + "' /SC MONTHLY /D " + $daysOfWeek + " /F /ST " + $selectedTime + " /MO " + $selectedWeekOfMonth + " /TR '" + $action2 + "' /RU 'NT AUTHORITY\SYSTEM'"
                Invoke-Expression "cmd /c $command"
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo11')" -Color Yellow
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo2') " -Color Cyan -noNewLine
                $selectedDate = $selectedDate.ToString("yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
                msrdAddOutputBoxLine "$selectedDate"
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo3') " -Color Cyan -noNewLine
                msrdAddOutputBoxLine "$selectedTime"
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo4') " -Color Cyan -noNewLine
                msrdAddOutputBoxLine "$frequency"
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo5') " -Color Cyan -noNewLine
                msrdAddOutputBoxLine "$daysOfWeek"
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo12') " -Color Cyan -noNewLine
                msrdAddOutputBoxLine "$selectedWeekOfMonth"
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo6') " -Color Cyan -noNewLine
                msrdAddOutputBoxLine "$machineType"
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo7') " -Color Cyan -noNewLine
                msrdAddOutputBoxLine "$machineRole"
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo8') " -Color Cyan -noNewLine
                msrdAddOutputBoxLine "$scriptLocation"
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo9') " -Color Cyan -noNewLine
                msrdAddOutputBoxLine "$outputLocation"
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo10') " -Color Cyan -noNewLine
                msrdAddOutputBoxLine "NT AUTHORITY\SYSTEM"
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo14') " -Color Cyan -noNewLine
                msrdAddOutputBoxLine "$action2`n`n"
            } else {
                msrdAddOutputBoxLine "$(msrdGetLocalizedText 'schedTaskInfo13')" -Color Red
            }
        }

        # Clean up
        $staskForm.Close()
    }

    # Add event handler to update the enabled state of fields on form load
    $staskForm.Add_Load({ UpdateFields })

    #endregion scheduled task configuration form


    #region UserContext
    $userContextForm = New-Object System.Windows.Forms.Form
    $userContextForm.Width = 400
    $userContextForm.Height = 150
    $userContextForm.StartPosition = "CenterScreen"
    $userContextForm.MinimizeBox = $False
    $userContextForm.MaximizeBox = $False
    $userContextForm.BackColor = "#eeeeee"
    $userContextForm.Text = msrdGetLocalizedText "context1"
    $userContextForm.Icon = $usercontexticon

    $userContextLabel = New-Object System.Windows.Forms.Label
    $userContextLabel.Location  = New-Object System.Drawing.Point(20,20)
    $userContextLabel.Size  = New-Object System.Drawing.Point(350,30)
    $userContextLabel.Text = msrdGetLocalizedText "context2"
    if ($global:msrdLangID -eq "AR") { $userContextLabel.RightToLeft = "Yes" } else { $userContextLabel.RightToLeft = "No" }
    $userContextForm.Controls.Add($userContextLabel)

    $userContextBox = New-Object System.Windows.Forms.TextBox
    $userContextBox.Location  = New-Object System.Drawing.Point(20,60)
    $userContextBox.Size  = New-Object System.Drawing.Point(170,30)
    $userContextBox.Cursor = [System.Windows.Forms.Cursors]::Hand
    if ($global:msrdUserprof) {
        $userContextBox.Text = $global:msrdUserprof
    } else {
        $userContextBox.Text = [System.Environment]::UserName; $global:msrdUserprof = [System.Environment]::UserName
    }
    if ($global:msrdLangID -eq "AR") { $userContextBox.RightToLeft = "Yes" } else { $userContextBox.RightToLeft = "No" }

    $userContextForm.Controls.Add($userContextBox)

    $userContextOK = New-Object System.Windows.Forms.Button
    $userContextOK.Location = New-Object System.Drawing.Size(230,58)
    $userContextOK.Size = New-Object System.Drawing.Size(60,25)
    $userContextOK.Text = "OK"
    $userContextOK.BackColor = "white"
    $userContextOK.Cursor = [System.Windows.Forms.Cursors]::Hand
    $userContextForm.Controls.Add($userContextOK)
    $userContextOK.Add_Click({
        if ($userContextBox.Text) {
            $tempUserprof = $userContextBox.Text
            if (Test-Path -Path "$msrdUserProfilesDir\$tempUserprof") {
                $global:msrdUserprof = $userContextBox.Text
            } else {
                if ($global:msrdUserprof) {
                    $userContextBox.Text = $global:msrdUserprof
                } else {
                    $userContextBox.Text = [System.Environment]::UserName; $global:msrdUserprof = [System.Environment]::UserName
                }
                [System.Windows.Forms.MessageBox]::Show("$(msrdGetLocalizedText 'userCon1')`n$msrdUserProfilesDir\$tempUserprof`n`n$(msrdGetLocalizedText 'userCon2') $($userContextBox.Text)", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }
        } else {
            $userContextBox.Text = [System.Environment]::UserName; $global:msrdUserprof = [System.Environment]::UserName
        }
        $userContextForm.Close()
        msrdAddOutputBoxLine "$(msrdGetLocalizedText "context3") $($userContextBox.Text)`n" "Yellow"
    })

    $userContextCancel = New-Object System.Windows.Forms.Button
    $userContextCancel.Location = New-Object System.Drawing.Size(300,58)
    $userContextCancel.Size = New-Object System.Drawing.Size(60,25)
    $userContextCancel.Text = "Cancel"
    $userContextCancel.BackColor = "white"
    $userContextCancel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $userContextForm.Controls.Add($userContextCancel)
    $userContextCancel.Add_Click({
        if ($global:msrdUserprof) {
            $userContextBox.Text = $global:msrdUserprof
        } else {
            $userContextBox.Text = [System.Environment]::UserName; $global:msrdUserprof = [System.Environment]::UserName
        }
        $userContextForm.Close()
        msrdAddOutputBoxLine "$(msrdGetLocalizedText "context3") $($userContextBox.Text)`n" "Yellow"
    })
    #endregion UserContext


    #region LiveDiag

    $global:liveDiagTab = New-Object System.Windows.Forms.TabControl
    $global:liveDiagTab.Location = New-Object System.Drawing.Point(0, 140)
    $global:liveDiagTab.Height = $global:msrdForm.ClientSize.Height - 162
    $global:liveDiagTab.Width = $global:msrdForm.ClientSize.Width
    $global:liveDiagTab.Multiline = $true
    $global:liveDiagTab.AutoSize = $true
    $global:liveDiagTab.Appearance = "FlatButtons"

    if ($global:msrdLangID -eq "AR") {
        $global:liveDiagTab.Anchor = 'Top,Right,Left,Bottom'
        $global:liveDiagTab.RightToLeft = "Yes"
        $global:liveDiagTab.RightToLeftLayout = $true
    } else {
        $global:liveDiagTab.Anchor = 'Top,Left,Right,Bottom'
        $global:liveDiagTab.RightToLeft = "No"
        $global:liveDiagTab.RightToLeftLayout = $false
    }

    $liveDiagTabSystem = New-Object System.Windows.Forms.TabPage
    $liveDiagTabSystem.Text = 'System'
    $liveDiagTabSystem.RightToLeft = "No"

    $liveDiagTabAVDRDS = New-Object System.Windows.Forms.TabPage
    $liveDiagTabAVDRDS.RightToLeft = "No"

    $liveDiagTabAVDInfra = New-Object System.Windows.Forms.TabPage
    $liveDiagTabAVDInfra.Text = 'AVD Infra'
    $liveDiagTabAVDInfra.RightToLeft = "No"

    $liveDiagTabAD = New-Object System.Windows.Forms.TabPage
    $liveDiagTabAD.Text = 'Active Directory'
    $liveDiagTabAD.RightToLeft = "No"

    $liveDiagTabNet = New-Object System.Windows.Forms.TabPage
    $liveDiagTabNet.Text = 'Networking'
    $liveDiagTabNet.RightToLeft = "No"

    $liveDiagTabLogonSec = New-Object System.Windows.Forms.TabPage
    $liveDiagTabLogonSec.Text = 'Logon/Security'
    $liveDiagTabLogonSec.RightToLeft = "No"

    $liveDiagTabIssues = New-Object System.Windows.Forms.TabPage
    $liveDiagTabIssues.Text = 'Known Issues'
    $liveDiagTabIssues.RightToLeft = "No"

    $liveDiagTabOther = New-Object System.Windows.Forms.TabPage
    $liveDiagTabOther.Text = 'Other'
    $liveDiagTabOther.RightToLeft = "No"

    $global:liveDiagTab.Visible = $false


    function CreateRichTextBox {
        param (
            [string]$Name,
            [System.Windows.Forms.Control]$Container
        )

        $richTextbox = New-Object System.Windows.Forms.RichTextBox
        $richTextbox.Name = $Name
        $richTextbox.Location = [System.Drawing.Point]::new(0, 30)
        $richTextbox.Font = [System.Drawing.Font]::new("Consolas", 10)
        $richTextbox.Height = $Container.ClientSize.Height - 30
        $richTextbox.Width = $Container.ClientSize.Width
        $richTextbox.Multiline = $true
        $richTextbox.ScrollBars = "Vertical"
        $richTextbox.BackColor = "White"
        $richTextbox.Anchor = 'Top,Left,Bottom,Right'
        $richTextbox.SelectionIndent = 10
        $richTextbox.SelectionRightIndent = 10
        $richTextbox.ReadOnly = $true

        $Container.Controls.Add($richTextbox)

        return $richTextbox
    }

    $global:psBoxLiveDiagSystem = CreateRichTextBox -Name "psBoxLiveDiagSystem" -Container $liveDiagTabSystem
    $global:psBoxLiveDiagAVDRDS = CreateRichTextBox -Name "psBoxLiveDiagAVDRDS" -Container $liveDiagTabAVDRDS
    $global:psBoxLiveDiagAVDInfra = CreateRichTextBox -Name "psBoxLiveDiagAVDInfra" -Container $liveDiagTabAVDInfra
    $global:psBoxLiveDiagAD = CreateRichTextBox -Name "psBoxLiveDiagAD" -Container $liveDiagTabAD
    $global:psBoxLiveDiagNet = CreateRichTextBox -Name "psBoxLiveDiagNet" -Container $liveDiagTabNet
    $global:psBoxLiveDiagLogonSec = CreateRichTextBox -Name "psBoxLiveDiagLogonSec" -Container $liveDiagTabLogonSec
    $global:psBoxLiveDiagIssues = CreateRichTextBox -Name "psBoxLiveDiagIssues" -Container $liveDiagTabIssues
    $global:psBoxLiveDiagOther = CreateRichTextBox -Name "psBoxLiveDiagOther" -Container $liveDiagTabOther

    $global:msrdForm.Controls.Add($liveDiagTab)

    function CreateTabButton {
        param (
            [string]$Name,
            [System.Windows.Forms.Control]$Container,
            $XPosition
        )

        $tabButton = New-Object System.Windows.Forms.Button
        $tabButton.Width = 70
        $tabButton.Text = "$Name"

        if ($global:msrdLangID -eq "AR") {
            $xlocbtn = 840 - $XPosition - $tabButton.Width
            $tabButton.Location = [System.Drawing.Point]::new($xlocbtn, 5)
		} else {
            $tabButton.Location = [System.Drawing.Point]::new($XPosition, 5)
		}
        $Container.Controls.Add($tabButton)

        return $tabButton
    }

    function msrdLiveDiagSection {
        param (
            [System.Windows.Forms.Control]$psBox,
            $section,
            [string]$action
        )

        if ($global:msrdLangID -eq "AR") {
            $lddate = Get-Date
            $ldday = $lddate.Day.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
            $ldmonth = $lddate.Month.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
            $ldyear = $lddate.Year.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
            $ldhour = $lddate.Hour.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
            $ldminute = $lddate.Minute.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
            $ldsecond = $lddate.Second.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
            $ldmillisecond = $lddate.Millisecond.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
        }

        if ($action -eq "Start") {
            [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::WaitCursor
            $global:msrdDiagnosing = $true
            Set-Variable -Name $section -Value $true -Scope Global

		    $psBox.Clear()
            $psBox.SelectionBackColor = "LightBlue"

            if ($global:msrdLangID -eq "AR") {
                $liveDiagText1a = "$(msrdGetLocalizedText 'liveDiag1') "
                $liveDiagText1b = "${ldhour}:${ldminute}:${ldsecond}.${ldmillisecond} ${ldyear}/${ldmonth}/${ldday}" + "`r`n"

                $currentLength1 = $psBox.TextLength
                $psBox.AppendText($liveDiagText1a)
                $psBox.AppendText($liveDiagText1b)
                $psBox.Select($currentLength1, 0)
                $psBox.SelectionAlignment = "Right"
            } else {
                $liveDiagText1 = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss.fff") + " $(msrdGetLocalizedText 'liveDiag1')`r`n"
                $psBox.AppendText($liveDiagText1)
                $psBox.SelectionAlignment = "Left"
            }

            if ($global:msrdAssistMode -eq 1) { msrdLogMessageAssistMode "$(msrdGetLocalizedText 'liveDiag1')" }

            $psBox.SelectionBackColor = "Transparent"
		    $psBox.Refresh()

        } elseif ($action -eq "Stop") {
            $global:msrdDiagnosing = $false
            $psBox.AppendText("`n`n`n")
            $psBox.SelectionBackColor = "LightBlue"

            if ($global:msrdLangID -eq "AR") {
                $liveDiagText2a = "$(msrdGetLocalizedText 'liveDiag2') "
                $liveDiagText2b = "${ldhour}:${ldminute}:${ldsecond}.${ldmillisecond} ${ldyear}/${ldmonth}/${ldday}"

                $currentLength2 = $psBox.TextLength
                $psBox.AppendText($liveDiagText2a)
                $psBox.AppendText($liveDiagText2b)
                $psBox.Select($currentLength2, 0)
                $psBox.SelectionAlignment = "Right"
            } else {
                $liveDiagText2 = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss.fff") + " $(msrdGetLocalizedText 'liveDiag2')"
                $psBox.AppendText($liveDiagText2)
                $psBox.SelectionAlignment = "Left"
            }

            if ($global:msrdAssistMode -eq 1) { msrdLogMessageAssistMode "$(msrdGetLocalizedText 'liveDiag2')" }

            $psBox.SelectionBackColor = "Transparent"
            $psBox.ScrollToCaret()
            $psBox.Refresh()
            $global:msrdStatusBarLabel.Text = msrdGetLocalizedText "Ready"
            Set-Variable -Name $section -Value $false -Scope Global

            [System.Windows.Forms.Cursor]::Current = [System.Windows.Forms.Cursors]::Default
		}
    }

    #region System tab
    $systemBtnPanel = New-Object System.Windows.Forms.Panel
    $systemBtnPanel.Height = 30
    $systemBtnPanel.Width = 850
    if ($global:msrdLangID -eq "AR") {
        $xloc = $global:msrdForm.ClientSize.Width - 1990
        $systemBtnPanel.Location = New-Object System.Drawing.Point($xloc, 0)
        $systemBtnPanel.Anchor = 'Top,Right'
	} else {
        $systemBtnPanel.Location = New-Object System.Drawing.Point(0, 0)
        $systemBtnPanel.Anchor = 'Top,Left'
	}
    $liveDiagTabSystem.Controls.Add($systemBtnPanel)

    $liveDiagSystemBtn = CreateTabButton -Name "Run all" -container $systemBtnPanel -XPosition 0
    $liveDiagSystemBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Start"

        msrdDiagDeployment
        msrdDiagCPU
        msrdDiagDrives
        msrdDiagGraphics
        if (!($global:msrdSource)) { msrdDiagActivation }
        msrdDiagSSLTLS
        msrdDiagUAC
        msrdDiagInstaller
        if (!($global:msrdSource)) { msrdDiagSearch }
        msrdDiagWU
        msrdDiagWinRMPS

        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Stop"
	})

    $liveDiagSystemCoreBtn = CreateTabButton -Name "Core" -container $systemBtnPanel -XPosition 70
    $liveDiagSystemCoreBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Start"
        msrdDiagDeployment
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Stop"
	})

    $liveDiagSystemCPUBtn = CreateTabButton -Name "CPU/Hndl" -container $systemBtnPanel -XPosition 140
    $liveDiagSystemCPUBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Start"
        msrdDiagCPU
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Stop"
	})

    $liveDiagSystemDrivesBtn = CreateTabButton -Name "Drives" -container $systemBtnPanel -XPosition 210
    $liveDiagSystemDrivesBtn.Add_Click({
        msrdLiveDition -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Start"
        msrdDiagDrives
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Stop"
	})

    $liveDiagSystemGfxBtn = CreateTabButton -Name "Graphics" -container $systemBtnPanel -XPosition 280
    $liveDiagSystemGfxBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Start"
        msrdDiagGraphics
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Stop"
	})

    $liveDiagSystemActivationBtn = CreateTabButton -Name "Activation" -container $systemBtnPanel -XPosition 350
    $liveDiagSystemActivationBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Start"
        msrdDiagActivation
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Stop"
	})

    $liveDiagSystemSSLTLSBtn = CreateTabButton -Name "SSL/TLS" -container $systemBtnPanel -XPosition 420
    $liveDiagSystemSSLTLSBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Start"
        msrdDiagSSLTLS
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Stop"
	})

    $liveDiagSystemUACBtn = CreateTabButton -Name "UAC" -container $systemBtnPanel -XPosition 490
    $liveDiagSystemUACBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Start"
        msrdDiagUAC
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Stop"
	})

    $liveDiagSystemWInstallerBtn = CreateTabButton -Name "Installer" -container $systemBtnPanel -XPosition 560
    $liveDiagSystemWInstallerBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Start"
        msrdDiagInstaller
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Stop"
	})

    $liveDiagSystemWSearchBtn = CreateTabButton -Name "Search" -container $systemBtnPanel -XPosition 630
    $liveDiagSystemWSearchBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Start"
        msrdDiagSearch
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Stop"
	})

    $liveDiagSystemWUpdateBtn = CreateTabButton -Name "Update" -container $systemBtnPanel -XPosition 700
    $liveDiagSystemWUpdateBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Start"
        msrdDiagWU
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Stop"
	})

    $liveDiagSystemWinRMPSBtn = CreateTabButton -Name "WinRM/PS" -container $systemBtnPanel -XPosition 770
    $liveDiagSystemWinRMPSBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Start"
        msrdDiagWinRMPS
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagSystem -section msrdLiveDiagSystem -action "Stop"
	})
    #endregion System tab

    #region AVD/RDS tab
    function InitLiveDiagAVDRDS {
        if ($global:msrdAVD) { $script:AVDRDSmsg = "AVD/RDS" } elseif ($global:msrdRDS) { $script:AVDRDSmsg = "RDS" } elseif ($global:msrdW365) { $script:AVDRDSmsg = "AVD/RDS/W365" }

        return $AVDRDSmsg
    }

    $avdrdsBtnPanel = New-Object System.Windows.Forms.Panel
    $avdrdsBtnPanel.Height = 30
    $avdrdsBtnPanel.Width = 850
    if ($global:msrdLangID -eq "AR") {
        $xloc = $global:msrdForm.ClientSize.Width - 1990
        $avdrdsBtnPanel.Location = New-Object System.Drawing.Point($xloc, 0)
        $avdrdsBtnPanel.Anchor = 'Top,Right'
	} else {
        $avdrdsBtnPanel.Location = New-Object System.Drawing.Point(0, 0)
        $avdrdsBtnPanel.Anchor = 'Top,Left'
	}
    $liveDiagTabAVDRDS.Controls.Add($avdrdsBtnPanel)

    $liveDiagAVDRDSBtn = CreateTabButton -Name "Run all" -container $avdrdsBtnPanel -XPosition 0
    $liveDiagAVDRDSBtn.Add_Click({
        InitLiveDiagAVDRDS
        $global:msrdLiveDiagAVDRDS = $true
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -action "Start"

        msrdDiagRedirection
        if (!($global:msrdSource)) { msrdDiagFSLogix }
        msrdDiagMultimedia
        msrdDiagQA
        if (!($global:msrdSource)) {
            msrdDiagRDPListener
            if ($global:msrdOSVer -like "*Windows Server*") { msrdDiagRDSRoles }
        }
        msrdDiagRDClient
        if (!($global:msrdSource)) {
            msrdDiagLicensing
            msrdDiagTimeLimits
        }
        if (!($global:msrdRDS)) { msrdDiagTeams }

        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -action "Stop"
        $global:msrdLiveDiagAVDRDS = $false
	})

    $liveDiagAVDRDSRedirectionBtn = CreateTabButton -Name "Redirection" -container $avdrdsBtnPanel -XPosition 70
    $liveDiagAVDRDSRedirectionBtn.Add_Click({
        InitLiveDiagAVDRDS
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Start"
        msrdDiagRedirection
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Stop"
	})

    $liveDiagAVDRDSFSLogixBtn = CreateTabButton -Name "FSLogix" -container $avdrdsBtnPanel -XPosition 140
    $liveDiagAVDRDSFSLogixBtn.Add_Click({
        InitLiveDiagAVDRDS
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Start"
        msrdDiagFSLogix
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Stop"
	})

    $liveDiagAVDRDSMultimediaBtn = CreateTabButton -Name "Multimedia" -container $avdrdsBtnPanel -XPosition 210
    $liveDiagAVDRDSMultimediaBtn.Add_Click({
        InitLiveDiagAVDRDS
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Start"
        msrdDiagMultimedia
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Stop"
	})

    $liveDiagAVDRDSQABtn = CreateTabButton -Name "QA/RH" -container $avdrdsBtnPanel -XPosition 280
    $liveDiagAVDRDSQABtn.Add_Click({
        InitLiveDiagAVDRDS
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Start"
        msrdDiagQA
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Stop"
	})

    $liveDiagAVDRDSRDPListenerBtn = CreateTabButton -Name "Listener" -container $avdrdsBtnPanel -XPosition 350
    $liveDiagAVDRDSRDPListenerBtn.Add_Click({
        InitLiveDiagAVDRDS
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Start"
        msrdDiagRDPListener
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Stop"
	})

    $liveDiagAVDRDSRDSRolesBtn = CreateTabButton -Name "RDS Roles" -container $avdrdsBtnPanel -XPosition 420
    $liveDiagAVDRDSRDSRolesBtn.Add_Click({
        InitLiveDiagAVDRDS
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Start"
        if ($global:msrdOSVer -like "*Windows Server*") {
            msrdDiagRDSRoles
        } else {
            $msg = "`nThis machine is not running a Server OS. Skipping RDS Roles check (not applicable)."
            $psBoxLiveDiagAVDRDS.AppendText($msg)
		    $psBoxLiveDiagAVDRDS.Refresh()
        }
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Stop"
	})

    $liveDiagAVDRDSRDClientBtn = CreateTabButton -Name "RD Client" -container $avdrdsBtnPanel -XPosition 490
    $liveDiagAVDRDSRDClientBtn.Add_Click({
        InitLiveDiagAVDRDS
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Start"
        msrdDiagRDClient
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Stop"
	})

    $liveDiagAVDRDSLicensingBtn = CreateTabButton -Name "Licensing" -container $avdrdsBtnPanel -XPosition 560
    $liveDiagAVDRDSLicensingBtn.Add_Click({
        InitLiveDiagAVDRDS
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Start"
        msrdDiagLicensing
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Stop"
	})

    $liveDiagAVDRDSTimeLimitsBtn = CreateTabButton -Name "Time Limits" -container $avdrdsBtnPanel -XPosition 630
    $liveDiagAVDRDSTimeLimitsBtn.Add_Click({
        InitLiveDiagAVDRDS
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Start"
        msrdDiagTimeLimits
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Stop"
	})

    $liveDiagAVDRDSTeamsBtn = CreateTabButton -Name "Teams" -container $avdrdsBtnPanel -XPosition 700
    $liveDiagAVDRDSTeamsBtn.Add_Click({
        InitLiveDiagAVDRDS
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Start"
        msrdDiagTeams
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Stop"
	})

    $liveDiagAVDRDSTeamsBtn = CreateTabButton -Name "W365 Boot" -container $avdrdsBtnPanel -XPosition 770
    $liveDiagAVDRDSTeamsBtn.Add_Click({
        InitLiveDiagAVDRDS
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Start"
        msrdDiagW365
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDRDS -section msrdLiveDiagAVDRDS -action "Stop"
	})
    #endregion AVD/RDS tab

    #region AVD Infra tab
    $avdinfraBtnPanel = New-Object System.Windows.Forms.Panel
    $avdinfraBtnPanel.Height = 30
    $avdinfraBtnPanel.Width = 850
    if ($global:msrdLangID -eq "AR") {
        $xloc = $global:msrdForm.ClientSize.Width - 1990
        $avdinfraBtnPanel.Location = New-Object System.Drawing.Point($xloc, 0)
        $avdinfraBtnPanel.Anchor = 'Top,Right'
	} else {
        $avdinfraBtnPanel.Location = New-Object System.Drawing.Point(0, 0)
        $avdinfraBtnPanel.Anchor = 'Top,Left'
	}
    $liveDiagTabAVDInfra.Controls.Add($avdinfraBtnPanel)

    $liveDiagAVDInfraBtn = CreateTabButton -Name "Run all" -container $avdinfraBtnPanel -XPosition 0
    $liveDiagAVDInfraBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDInfra -section msrdLiveDiagAVDInfra -action "Start"
        if ($global:msrdAVD -or $global:msrdW365) {
            if (!($global:msrdSource)) {
                msrdDiagHP
                msrdDiagAgentStack
                msrdDiagHealthCheck
            }
        }
        if (!($global:msrdRDS)) { msrdDiagURL }
        if (!($global:msrdSource)) {
            if ($global:msrdAVD -or $global:msrdW365) { msrdDiagURIHealth }
            if ($global:msrdAVD) { msrdDiagHCI }
        }
        if (!($global:msrdRDS)) { msrdDiagShortpath }
        if ($global:msrdW365) { msrdDiagW365 }
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDInfra -section msrdLiveDiagAVDInfra -action "Stop"
	})

    $liveDiagAVDInfraHPBtn = CreateTabButton -Name "Host Pool" -container $avdinfraBtnPanel -XPosition 70
    $liveDiagAVDInfraHPBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDInfra -section msrdLiveDiagAVDInfra -action "Start"
        msrdDiagHP
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDInfra -section msrdLiveDiagAVDInfra -action "Stop"
	})

    $liveDiagAVDInfraAgentStackBtn = CreateTabButton -Name "Agents" -container $avdinfraBtnPanel -XPosition 140
    $liveDiagAVDInfraAgentStackBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDInfra -section msrdLiveDiagAVDInfra -action "Start"
        msrdDiagAgentStack
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDInfra -section msrdLiveDiagAVDInfra -action "Stop"
	})

    $liveDiagAVDInfraAgentStackBtn = CreateTabButton -Name "Health Ck" -container $avdinfraBtnPanel -XPosition 210
    $liveDiagAVDInfraAgentStackBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDInfra -section msrdLiveDiagAVDInfra -action "Start"
        msrdDiagHealthCheck
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDInfra -section msrdLiveDiagAVDInfra -action "Stop"
	})

    $liveDiagAVDInfraReqURLBtn = CreateTabButton -Name "AVD EPs" -container $avdinfraBtnPanel -XPosition 280
    $liveDiagAVDInfraReqURLBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDInfra -section msrdLiveDiagAVDInfra -action "Start"
        msrdDiagURL
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDInfra -section msrdLiveDiagAVDInfra -action "Stop"
	})

    $liveDiagAVDInfraURIBtn = CreateTabButton -Name "URI Health" -container $avdinfraBtnPanel -XPosition 350
    $liveDiagAVDInfraURIBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDInfra -section msrdLiveDiagAVDInfra -action "Start"
        msrdDiagURIHealth
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDInfra -section msrdLiveDiagAVDInfra -action "Stop"
	})

    $liveDiagAVDInfraHCIBtn = CreateTabButton -Name "HCI" -container $avdinfraBtnPanel -XPosition 420
    $liveDiagAVDInfraHCIBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDInfra -section msrdLiveDiagAVDInfra -action "Start"
        msrdDiagHCI
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDInfra -section msrdLiveDiagAVDInfra -action "Stop"
	})

    $liveDiagAVDInfraShortpathBtn = CreateTabButton -Name "Shortpath" -container $avdinfraBtnPanel -XPosition 490
    $liveDiagAVDInfraShortpathBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDInfra -section msrdLiveDiagAVDInfra -action "Start"
        msrdDiagShortpath
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDInfra -section msrdLiveDiagAVDInfra -action "Stop"
	})

    $liveDiagAVDInfraW365Btn = CreateTabButton -Name "W365 EPs" -container $avdinfraBtnPanel -XPosition 560
    $liveDiagAVDInfraW365Btn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDInfra -section msrdLiveDiagAVDInfra -action "Start"
        msrdDiagW365reqUrls
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAVDInfra -section msrdLiveDiagAVDInfra -action "Stop"
	})
    #endregion AVD Infra tab

    #region AD tab
    $adBtnPanel = New-Object System.Windows.Forms.Panel
    $adBtnPanel.Height = 30
    $adBtnPanel.Width = 850
    if ($global:msrdLangID -eq "AR") {
        $xloc = $global:msrdForm.ClientSize.Width - 1990
        $adBtnPanel.Location = New-Object System.Drawing.Point($xloc, 0)
        $adBtnPanel.Anchor = 'Top,Right'
	} else {
        $adBtnPanel.Location = New-Object System.Drawing.Point(0, 0)
        $adBtnPanel.Anchor = 'Top,Left'
	}
    $liveDiagTabAD.Controls.Add($adBtnPanel)

    $liveDiagADBtn = CreateTabButton -Name "Run all" -container $adBtnPanel -XPosition 0
    $liveDiagADBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAD -section msrdLiveDiagAD -action "Start"
        msrdDiagEntraJoin
        msrdDiagDC
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAD -section msrdLiveDiagAD -action "Stop"
	})

    $liveDiagADAADJBtn = CreateTabButton -Name "Entra Join" -container $adBtnPanel -XPosition 70
    $liveDiagADAADJBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAD -section msrdLiveDiagAD -action "Start"
        msrdDiagEntraJoin
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAD -section msrdLiveDiagAD -action "Stop"
	})

    $liveDiagADDCBtn = CreateTabButton -Name "DC" -container $adBtnPanel -XPosition 140
    $liveDiagADDCBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAD -section msrdLiveDiagAD -action "Start"
        msrdDiagDC
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagAD -section msrdLiveDiagAD -action "Stop"
	})
    #endregion AD tab

    #region Networking tab
    $netBtnPanel = New-Object System.Windows.Forms.Panel
    $netBtnPanel.Height = 30
    $netBtnPanel.Width = 850
    if ($global:msrdLangID -eq "AR") {
        $xloc = $global:msrdForm.ClientSize.Width - 1990
        $netBtnPanel.Location = New-Object System.Drawing.Point($xloc, 0)
        $netBtnPanel.Anchor = 'Top,Right'
    } else {
        $netBtnPanel.Location = New-Object System.Drawing.Point(0, 0)
        $netBtnPanel.Anchor = 'Top,Left'
    }
    $liveDiagTabNet.Controls.Add($netBtnPanel)

    $liveDiagNetBtn = CreateTabButton -Name "Run all" -container $netBtnPanel -XPosition 0
    $liveDiagNetBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagNet -section msrdLiveDiagNet -action "Start"
        msrdDiagNWCore
        msrdDiagDNS
        msrdDiagFirewall
        msrdDiagIPAddresses
        msrdDiagPortUsage
        msrdDiagProxy
        msrdDiagRouting
        msrdDiagVPN
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagNet -section msrdLiveDiagNet -action "Stop"
	})

    $liveDiagNetNWCoreBtn = CreateTabButton -Name "Core NET" -container $netBtnPanel -XPosition 70
    $liveDiagNetNWCoreBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagNet -section msrdLiveDiagNet -action "Start"
        msrdDiagNWCore
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagNet -section msrdLiveDiagNet -action "Stop"
	})

    $liveDiagNetDNSBtn = CreateTabButton -Name "DNS" -container $netBtnPanel -XPosition 140
    $liveDiagNetDNSBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagNet -section msrdLiveDiagNet -action "Start"
        msrdDiagDNS
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagNet -section msrdLiveDiagNet -action "Stop"
	})

    $liveDiagNetFirewallBtn = CreateTabButton -Name "Firewall" -container $netBtnPanel -XPosition 210
    $liveDiagNetFirewallBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagNet -section msrdLiveDiagNet -action "Start"
        msrdDiagFirewall
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagNet -section msrdLiveDiagNet -action "Stop"
	})

    $liveDiagNetIPBtn = CreateTabButton -Name "IPs" -container $netBtnPanel -XPosition 280
    $liveDiagNetIPBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagNet -section msrdLiveDiagNet -action "Start"
        msrdDiagIPAddresses
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagNet -section msrdLiveDiagNet -action "Stop"
	})

    $liveDiagNetPortBtn = CreateTabButton -Name "Port Usage" -container $netBtnPanel -XPosition 350
    $liveDiagNetPortBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagNet -section msrdLiveDiagNet -action "Start"
        msrdDiagPortUsage
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagNet -section msrdLiveDiagNet -action "Stop"
	})

    $liveDiagNetProxyBtn = CreateTabButton -Name "Proxy" -container $netBtnPanel -XPosition 420
    $liveDiagNetProxyBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagNet -section msrdLiveDiagNet -action "Start"
        msrdDiagProxy
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagNet -section msrdLiveDiagNet -action "Stop"
	})

    $liveDiagNetRoutingBtn = CreateTabButton -Name "Routing" -container $netBtnPanel -XPosition 490
    $liveDiagNetRoutingBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagNet -section msrdLiveDiagNet -action "Start"
        msrdDiagRouting
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagNet -section msrdLiveDiagNet -action "Stop"
	})

    $liveDiagNetVPNBtn = CreateTabButton -Name "VPN" -container $netBtnPanel -XPosition 560
    $liveDiagNetVPNBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagNet -section msrdLiveDiagNet -action "Start"
        msrdDiagVPN
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagNet -section msrdLiveDiagNet -action "Stop"
	})
    #endregion Networking tab

    #region Logon/Security tab
    $logonSecBtnPanel = New-Object System.Windows.Forms.Panel
    $logonSecBtnPanel.Height = 30
    $logonSecBtnPanel.Width = 850
    if ($global:msrdLangID -eq "AR") {
        $xloc = $global:msrdForm.ClientSize.Width - 1990
        $logonSecBtnPanel.Location = New-Object System.Drawing.Point($xloc, 0)
        $logonSecBtnPanel.Anchor = 'Top,Right'
    } else {
        $logonSecBtnPanel.Location = New-Object System.Drawing.Point(0, 0)
        $logonSecBtnPanel.Anchor = 'Top,Left'
    }
    $liveDiagTabLogonSec.Controls.Add($logonSecBtnPanel)

    $liveDiagLogonSecBtn = CreateTabButton -Name "Run all" -container $logonSecBtnPanel -XPosition 0
    $liveDiagLogonSecBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagLogonSec -section msrdLiveDiagLogonSec -action "Start"
        msrdDiagAuth
        msrdDiagSecurity
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagLogonSec -section msrdLiveDiagLogonSec -action "Stop"
	})

    $liveDiagLogonSecAuthBtn = CreateTabButton -Name "Auth" -container $logonSecBtnPanel -XPosition 70
    $liveDiagLogonSecAuthBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagLogonSec -section msrdLiveDiagLogonSec -action "Start"
        msrdDiagAuth
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagLogonSec -section msrdLiveDiagLogonSec -action "Stop"
	})

    $liveDiagLogonSecSecurityBtn = CreateTabButton -Name "Security" -container $logonSecBtnPanel -XPosition 140
    $liveDiagLogonSecSecurityBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagLogonSec -section msrdLiveDiagLogonSec -action "Start"
        msrdDiagSecurity
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagLogonSec -section msrdLiveDiagLogonSec -action "Stop"
	})
    #endregion Logon/Security tab

    #region Known Issues tab
    $issuesBtnPanel = New-Object System.Windows.Forms.Panel
    $issuesBtnPanel.Height = 30
    $issuesBtnPanel.Width = 850
    if ($global:msrdLangID -eq "AR") {
        $xloc = $global:msrdForm.ClientSize.Width - 1990
        $issuesBtnPanel.Location = New-Object System.Drawing.Point($xloc, 0)
        $issuesBtnPanel.Anchor = 'Top,Right'
    } else {
        $issuesBtnPanel.Location = New-Object System.Drawing.Point(0, 0)
        $issuesBtnPanel.Anchor = 'Top,Left'
    }
    $liveDiagTabIssues.Controls.Add($issuesBtnPanel)

    $liveDiagLogonIssuesBtn = CreateTabButton -Name "Run all" -container $issuesBtnPanel -XPosition 0
    $liveDiagLogonIssuesBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagIssues -section msrdLiveDiagIssues -action "Start"
        msrdLogDiag $LogLevel.Normal -Message "Issues identified in Event Logs over the past 5 days" -DiagTag "IssuesCheck"
        if (!($global:msrdSource)) {
            if ($global:msrdAVD -or $global:msrdW365) {
                msrdDiagAVDIssueEvents
                msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
            }

            $needHR = $false
            if ($script:foundRDS.Name -eq "RDS-Licensing") { msrdDiagRDLicensingIssueEvents; $needHR = $true }
            if ($script:foundRDS.Name -eq "RDS-GATEWAY") { msrdDiagRDGatewayIssueEvents; $needHR = $true }
            if ($needHR) { msrdLogDiag $LogLevel.DiagFileOnly -Type "HR" }
            msrdDiagRDIssueEvents
            msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        }

        msrdDiagCommonIssueEvents
        if (!($global:msrdSource)) { msrdDiagLogonIssues }
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagIssues -section msrdLiveDiagIssues -action "Stop"
	})

    $liveDiagLogonIssuesIdentifiedBtn = CreateTabButton -Name "Last 5 days" -container $issuesBtnPanel -XPosition 70
    $liveDiagLogonIssuesIdentifiedBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagIssues -section msrdLiveDiagIssues -action "Start"
        msrdLogDiag $LogLevel.Normal -Message "Issues identified in Event Logs over the past 5 days" -DiagTag "IssuesCheck"
        if (!($global:msrdSource)) {
            if ($global:msrdAVD -or $global:msrdW365) {
                msrdDiagAVDIssueEvents
                msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
            }

            $needHR = $false
            if ($script:foundRDS.Name -eq "RDS-Licensing") { msrdDiagRDLicensingIssueEvents; $needHR = $true }
            if ($script:foundRDS.Name -eq "RDS-GATEWAY") { msrdDiagRDGatewayIssueEvents; $needHR = $true }
            if ($needHR) { msrdLogDiag $LogLevel.DiagFileOnly -Type "HR" }
            msrdDiagRDIssueEvents
            msrdLogDiag $LogLevel.DiagFileOnly -Type "HR"
        }

        msrdDiagCommonIssueEvents
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagIssues -section msrdLiveDiagIssues -action "Stop"
	})

    $liveDiagLogonIssuesLogonBtn = CreateTabButton -Name "Logon" -container $issuesBtnPanel -XPosition 140
    $liveDiagLogonIssuesLogonBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagIssues -section msrdLiveDiagIssues -action "Start"
        msrdDiagLogonIssues
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagIssues -section msrdLiveDiagIssues -action "Stop"
	})
    #endregion Known Issues tab

    #region Other tab
    $otherBtnPanel = New-Object System.Windows.Forms.Panel
    $otherBtnPanel.Height = 30
    $otherBtnPanel.Width = 850
    if ($global:msrdLangID -eq "AR") {
        $xloc = $global:msrdForm.ClientSize.Width - 1990
        $otherBtnPanel.Location = New-Object System.Drawing.Point($xloc, 0)
        $otherBtnPanel.Anchor = 'Top,Right'
    } else {
        $otherBtnPanel.Location = New-Object System.Drawing.Point(0, 0)
        $otherBtnPanel.Anchor = 'Top,Left'
    }
    $liveDiagTabOther.Controls.Add($otherBtnPanel)

    $liveDiagOtherBtn = CreateTabButton -Name "Run all" -container $otherBtnPanel -XPosition 0
    $liveDiagOtherBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagOther -section msrdLiveDiagOther -action "Start"
        if (!($global:msrdSource)) {
            msrdDiagOffice
            msrdDiagOD
        }
        msrdDiagPrinting
        msrdDiagCitrix3P
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagOther -section msrdLiveDiagOther -action "Stop"
	})

    $liveDiagOtherOfficeBtn = CreateTabButton -Name "Office" -container $otherBtnPanel -XPosition 70
    $liveDiagOtherOfficeBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagOther -section msrdLiveDiagOther -action "Start"
        msrdDiagOffice
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagOther -section msrdLiveDiagOther -action "Stop"
	})

    $liveDiagOtherODBtn = CreateTabButton -Name "OneDrive" -container $otherBtnPanel -XPosition 140
    $liveDiagOtherODBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagOther -section msrdLiveDiagOther -action "Start"
        msrdDiagOD
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagOther -section msrdLiveDiagOther -action "Stop"
	})

    $liveDiagOtherPrintingBtn = CreateTabButton -Name "Printing" -container $otherBtnPanel -XPosition 210
    $liveDiagOtherPrintingBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagOther -section msrdLiveDiagOther -action "Start"
        msrdDiagPrinting
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagOther -section msrdLiveDiagOther -action "Stop"
	})

    $liveDiagOtherCitrix3PBtn = CreateTabButton -Name "Citrix/3P" -container $otherBtnPanel -XPosition 280
    $liveDiagOtherCitrix3PBtn.Add_Click({
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagOther -section msrdLiveDiagOther -action "Start"
        msrdDiagCitrix3P
        msrdLiveDiagSection -psBox $global:psBoxLiveDiagOther -section msrdLiveDiagOther -action "Stop"
	})
    #endregion LiveDiag

    $global:msrdForm.Controls.Add($global:msrdFormMenu)
    $global:msrdForm.MainMenuStrip = $global:msrdFormMenu
    $global:msrdForm.Controls.Add($buttonRibbon)

    $global:msrdForm.Add_Shown({

        $global:msrdPsBox.Focus()

        #check tools
        if ($global:avdnettestpath -eq "") {
            msrdAddOutputBoxLine ("$(msrdGetLocalizedText 'avdnettestNotFound')`n") -Color "Yellow"
        }

        if ($global:msrdForm -and $global:msrdForm.Visible) {
            $global:msrdGUI = $true
        } else {
            $global:msrdGUI = $false
        }

        if ($global:msrdAutoVerCheck -eq 1) {
            if ($global:msrdScriptSelfUpdate -eq 1) {
                msrdCheckVersion($msrdVersion) -selfUpdate
            } else {
                msrdCheckVersion($msrdVersion)
            }
        } else {
            msrdAddOutputBoxLine "$(msrdGetLocalizedText 'autoUpdate') $(msrdGetLocalizedText 'disabled')"
        }

        msrdInitScript -Type GUI
        msrdInitHowTo
    })

    if ($global:msrdShowConsole -eq 1) { msrdStartShowConsole; $ConsoleMenuItem.Checked = $true } else { msrdStartHideConsole; $ConsoleMenuItem.Checked = $false }
    msrdRefreshUILang $global:msrdLangID

    $global:msrdForm.Add_Closing({
        $global:msrdLiveDiag = $false
        If (($Null -ne $global:msrdTempCommandErrorFile) -and (Test-Path -Path $global:msrdTempCommandErrorFile)) { Remove-Item $global:msrdTempCommandErrorFile -Force | Out-Null }
        If ($global:fQuickEditCodeExist) { [msrdDisableConsoleQuickEdit]::SetQuickEdit($False) | Out-Null }
    })

    $global:msrdForm.ShowDialog() | Out-Null
    msrdStartShowConsole -nocfg $true
}

Export-ModuleMember -Function msrdAddOutputBoxLine, msrdFindFolder, msrdAVDCollectGUI
# SIG # Begin signature block
# MIIoOQYJKoZIhvcNAQcCoIIoKjCCKCYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDGtp0guToYjt/T
# wYBe1ZeAPP21wxkbUgQZsidzOF7oyaCCDYUwggYDMIID66ADAgECAhMzAAADri01
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
# cVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCGgowghoGAgEBMIGVMH4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01p
# Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAAOuLTVRyFOPVR0AAAAA
# A64wDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEID72
# WLqI+kBJFrEiGYugr6RyHBzmzCh2lM5xubS8Kd9WMEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEAQ00nu00OWGxwVOw068f4CSE4ougPp1Lkh004
# WGXX03XZ6eIA/QeIMbdFmm3ZlwA2VFOKlRNQURfsK9rdCuf4WleF008QBCZxc3TN
# U/XjNF8Pvv3ObWwReAdbprcR4Ld5Spsci9myTr4Lp0ZqFDQEk71s93Sfojj/TFM1
# vkDIjMyejwdDWJrDVSq7mxrdPDYyxfJ0wyjFKMO9Kt1zFoEqnPIcj7N7xoiHYOBk
# ef+zwNcWGRfooIro0UBsIUCn5GZ7cLmzRvgwiI6UlxGFcKZWp1fEflC+KchQWvz3
# zXWsfsG/5Sa2KWE+ubPp/2qVW+sdIRJapaU5lHZrffRbL2CpeKGCF5QwgheQBgor
# BgEEAYI3AwMBMYIXgDCCF3wGCSqGSIb3DQEHAqCCF20wghdpAgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCDXdWg5t60KpAMnQLPcisLBhdBj5cRjy0Md
# oF9ZX9p8zAIGZc3/hhnwGBMyMDI0MDIyMDEyMTcwMi4zNjJaMASAAgH0oIHRpIHO
# MIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQL
# ExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxk
# IFRTUyBFU046OTIwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFNlcnZpY2WgghHqMIIHIDCCBQigAwIBAgITMwAAAecujy+TC08b6QAB
# AAAB5zANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAx
# MDAeFw0yMzEyMDYxODQ1MTlaFw0yNTAzMDUxODQ1MTlaMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046OTIwMC0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Uw
# ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDCV58v4IuQ659XPM1DtaWM
# v9/HRUC5kdiEF89YBP6/Rn7kjqMkZ5ESemf5Eli4CLtQVSefRpF1j7S5LLKisMWO
# GRaLcaVbGTfcmI1vMRJ1tzMwCNIoCq/vy8WH8QdV1B/Ab5sK+Q9yIvzGw47TfXPE
# 8RlrauwK/e+nWnwMt060akEZiJJz1Vh1LhSYKaiP9Z23EZmGETCWigkKbcuAnhvh
# 3yrMa89uBfaeHQZEHGQqdskM48EBcWSWdpiSSBiAxyhHUkbknl9PPztB/SUxzRZj
# UzWHg9bf1mqZ0cIiAWC0EjK7ONhlQfKSRHVLKLNPpl3/+UL4Xjc0Yvdqc88gOLUr
# /84T9/xK5r82ulvRp2A8/ar9cG4W7650uKaAxRAmgL4hKgIX5/0aIAsbyqJOa6OI
# GSF9a+DfXl1LpQPNKR792scF7tjD5WqwIuifS9YUiHMvRLjjKk0SSCV/mpXC0BoP
# kk5asfxrrJbCsJePHSOEblpJzRmzaP6OMXwRcrb7TXFQOsTkKuqkWvvYIPvVzC68
# UM+MskLPld1eqdOOMK7Sbbf2tGSZf3+iOwWQMcWXB9gw5gK3AIYK08WkJJuyzPqf
# itgubdRCmYr9CVsNOuW+wHDYGhciJDF2LkrjkFUjUcXSIJd9f2ssYitZ9CurGV74
# BQcfrxjvk1L8jvtN7mulIwIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFM/+4JiAnzY4
# dpEf/Zlrh1K73o9YMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8G
# A1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMv
# Y3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBs
# BggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUy
# MDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUH
# AwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4ICAQB0ofDbk+llWi1c
# C6nsfie5Jtp09o6b6ARCpvtDPq2KFP+hi+UNNP7LGciKuckqXCmBTFIhfBeGSxvk
# 6ycokdQr3815pEOaYWTnHvQ0+8hKy86r1F4rfBu4oHB5cTy08T4ohrG/OYG/B/gN
# nz0Ol6v7u/qEjz48zXZ6ZlxKGyZwKmKZWaBd2DYEwzKpdLkBxs6A6enWZR0jY+q5
# FdbV45ghGTKgSr5ECAOnLD4njJwfjIq0mRZWwDZQoXtJSaVHSu2lHQL3YHEFikun
# bUTJfNfBDLL7Gv+sTmRiDZky5OAxoLG2gaTfuiFbfpmSfPcgl5COUzfMQnzpKfX6
# +FkI0QQNvuPpWsDU8sR+uni2VmDo7rmqJrom4ihgVNdLaMfNUqvBL5ZiSK1zmaEL
# BJ9a+YOjE5pmSarW5sGbn7iVkF2W9JQIOH6tGWLFJS5Hs36zahkoHh8iD963LeGj
# ZqkFusKaUW72yMj/yxTeGEDOoIr35kwXxr1Uu+zkur2y+FuNY0oZjppzp95AW1le
# hP0xaO+oBV1XfvaCur/B5PVAp2xzrosMEUcAwpJpio+VYfIufGj7meXcGQYWA8Um
# r8K6Auo+Jlj8IeFS6lSvKhqQpmdBzAMGqPOQKt1Ow3ZXxehK7vAiim3ZiALlM0K5
# 46k0sZrxdZPgpmz7O8w9gHLuyZAQezCCB3EwggVZoAMCAQICEzMAAAAVxedrngKb
# SZkAAAAAABUwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmlj
# YXRlIEF1dGhvcml0eSAyMDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIy
# NVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcT
# B1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UE
# AxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXI
# yjVX9gF/bErg4r25PhdgM/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjo
# YH1qUoNEt6aORmsHFPPFdvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1y
# aa8dq6z2Nr41JmTamDu6GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v
# 3byNpOORj7I5LFGc6XBpDco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pG
# ve2krnopN6zL64NF50ZuyjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viS
# kR4dPf0gz3N9QZpGdc3EXzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYr
# bqgSUei/BQOj0XOmTTd0lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlM
# jgK8QmguEOqEUUbi0b1qGFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSL
# W6CmgyFdXzB0kZSU2LlQ+QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AF
# emzFER1y7435UsSFF5PAPBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIu
# rQIDAQABo4IB3TCCAdkwEgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIE
# FgQUKqdS/mTEmr6CkTxGNSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWn
# G1M1GelyMFwGA1UdIARVMFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEW
# M2h0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5
# Lmh0bTATBgNVHSUEDDAKBggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBi
# AEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV
# 9lbLj+iiXGJo0T2UkFvXzpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3Js
# Lm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAx
# MC0wNi0yMy5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8v
# d3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2
# LTIzLmNydDANBgkqhkiG9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv
# 6lwUtj5OR2R4sQaTlz0xM7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZn
# OlNN3Zi6th542DYunKmCVgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1
# bSNU5HhTdSRXud2f8449xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4
# rPf5KYnDvBewVIVCs/wMnosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU
# 6ZGyqVvfSaN0DLzskYDSPeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDF
# NLB62FD+CljdQDzHVG2dY3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/
# HltEAY5aGZFrDZ+kKNxnGSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdU
# CbFpAUR+fKFhbHP+CrvsQWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKi
# excdFYmNcP7ntdAoGokLjzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTm
# dHRbatGePu1+oDEzfbzL6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZq
# ELQdVTNYs6FwZvKhggNNMIICNQIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJp
# Y2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjkyMDAtMDVF
# MC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMK
# AQEwBwYFKw4DAhoDFQCzcgTnGasSwe/dru+cPe1NF/vwQ6CBgzCBgKR+MHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA6X5sAjAi
# GA8yMDI0MDIyMDAwMDgzNFoYDzIwMjQwMjIxMDAwODM0WjB0MDoGCisGAQQBhFkK
# BAExLDAqMAoCBQDpfmwCAgEAMAcCAQACAh4kMAcCAQACAhOuMAoCBQDpf72CAgEA
# MDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAI
# AgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAEjBdhxc2Dy1IiI/abmk2E8Is2Yg
# KjvpKrgHVxrmR6uToVLP+UTfGUj2Wdk6mOU9tYSo2+fynkECZN0DoKjTEGh4Crnk
# ehLBVuWNgWLsCZc4U+fPnNmgZ2qAoDCCXREnJR9JIJm5UtNXteuMozC7q8xxg/do
# s4gse4eoUCHByHFAsQF2yQH4lw0AL5Ue8QK/wBmQWo0hdzZhEo/AGIWBJd5X4190
# yduqpmJpj4buYrRtrFQzbAVLlTIHmz8KofO3bdLsozBU9WK9+/+8a1AXn1SyEt5h
# LUX4UrzcmTMmM9UIFyLGwG1hDOrZI6UOtwP+SPLuYv5fTIvLKjn62cj88bgxggQN
# MIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAecu
# jy+TC08b6QABAAAB5zANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0G
# CyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCB/ajkGTuvoJnvqZyTEw81oBbiy
# 1wW9rxFLkxqCktdIXjCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIOU2XQ12
# aob9DeDFXM9UFHeEX74Fv0ABvQMG7qC51nOtMIGYMIGApH4wfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAHnLo8vkwtPG+kAAQAAAecwIgQg5strNsYb
# AJScKAE5aG3Lom5LvoS5tFxoBQ4e8fINHe0wDQYJKoZIhvcNAQELBQAEggIAN8Jq
# ahpUBKeVH52rLcWmO/aGMCsTnpth8lbz0JSYIclfSoTFpPqdoyo2cXN/sYgOcz++
# Y0CyfDCM+kUO4U+0/LY5jTTpvIPM8S7cbKKpf95Px+c1W2gDFEUOzIxRydYXA2ji
# Nar6MhYjPtpn/QPDYl3AjSx/dqU2ZE00YAcQYKLQXyRh7Me1ffjGkhQZyePFu3lP
# B2yvarFFlQBoCeV7g2hZHWzwntlMfcbxWhfAUV5WaVOW/ypUYHrk/+CIuYNSnSYH
# W2q8ui8W85wdhb5SdM2rcocMnPneOkSDVX/EWV/xgLXSoXBoJz2Robi8gb3bU/j9
# Ctms2rmc0sxl2VZzYsVLSB6ZpQR8wdkzEmfww52wVe3bIql3fijYPIlFJ1NSdQ1S
# UZ3aky7Vc63g5aJYxrdnrtEM2y6Ty4Wjq1lBUzacFBKmHsDc9ySEcIx8V9ds0s0p
# 0n7CKmFse6tNhWYcNcUrwyJarl7cYLW7DXqzAvthc1IPI7hI3u4OHVT3e1gT8MrY
# 1dOETT+OOiJDmI25alqz9QVLLw/bOxeuqicXkSP5feKJog+tGZM0UMUoB/xF0zTX
# IfReOJJFO7cOQGxKhtXcJ5HkhTh6HQeIOpKgPCFyekobmcNsUh/Df68Pq0vTe/A3
# 9uRt2yQ4pK35lETNq7gDNXGPG/rrfJMpH2ldHEQ=
# SIG # End signature block
