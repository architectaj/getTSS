<#
.SYNOPSIS
   MSRD-Collect framework functions

.DESCRIPTION
   Module for the MSRD-Collect framework functions

.NOTES
   Author     : Robert Klemencz
   Requires   : At least PowerShell 5.1 (This module is not for stand-alone use. It is used automatically from within the main MSRD-Collect.ps1 script)
   Version    : See MSRD-Collect.ps1 version
   Feedback   : https://aka.ms/MSRD-Collect-Feedback
#>

if (!($global:msrdTSSinUse)) {
    $global:LogLevel = @{
	    'Normal' = 0
	    'Info' = 1
	    'Warning' = 2
	    'Error' = 3
        #'Debug' = 4
	    'ErrorLogFileOnly' = 5
	    'WarnLogFileOnly' = 6
        'InfoLogFileOnly' = 7
        'DiagFileOnly' = 9
    }
}

#region initialization
if (($global:msrdOSVer -like "*Server*2008*") -or ($global:msrdOSVer -like "*Server*2012*") -or ($global:msrdOSVer -like "*Windows 7*")) {
    [string]$global:WinVerMajor = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion' CurrentVersion).CurrentVersion
} else {
    [string]$global:WinVerMajor = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion' CurrentMajorVersionNumber).CurrentMajorVersionNumber
    [string]$global:WinVerMinor = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion' CurrentMinorVersionNumber).CurrentMinorVersionNumber
}

[int]$global:WinVerBuild = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion' CurrentBuild).CurrentBuild
[string]$global:WinVerRevision = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion' UBR).UBR

function msrdInitScript {
    param ([string]$Type, $isTSS)

    if (!($isTSS)) {

        $initValues = @("$(msrdGetLocalizedText initvalues1a) $global:msrdVersion $(msrdGetLocalizedText initvalues1b) $global:msrdScriptpath ($global:msrdAdminlevel)",
            "$(msrdGetLocalizedText initvalues1c) $global:msrdCmdLine",
            "$(msrdGetLocalizedText initvalues2)",
            "$(msrdGetLocalizedText initvalues3) $global:msrdLogRoot",
            "$(msrdGetLocalizedText initvalues4) $global:msrdUserprof`n"
        )
        $initValues | ForEach-Object { if ($type -eq 'GUI') { msrdAddOutputBoxLine $_ } else { msrdLogMessage $LogLevel.Info $_ } }
    }

    $unsupportedOSMessage = "This Windows release is no longer supported. Please upgrade the machine to a more current, in-service, and supported Windows release."

    if ((($global:WinVerMajor -like "*10*") -and (@("10240", "10586", "14393", "15063", "16299", "17134", "17763", "18362", "18363", "19041", "19042", "19043") -contains $global:WinVerBuild) -and !($global:msrdOSVer -like "*Server*")) -or ($global:msrdOSVer -like "*Windows 8*") -or ($global:msrdOSVer -like "*Windows 7*") -or ($global:msrdOSVer -like "*Server 2008 R2*") -or ($global:msrdOSVer -like "*Server 2012 R2*")) {
        if ($type -eq 'GUI') {
            msrdAddOutputBoxLine $unsupportedOSMessage -Color "Yellow"
        } else {
            Write-Warning $unsupportedOSMessage
        }
    }
}

# initialize scenario variables
function msrdInitScenarioVars {

    $vars = "vProfiles", "vActivation", "vMSRA", "vSCard", "vIME", "vTeams", "vMSIXAA", "vHCI"
    foreach ($var in $vars) { $var = $script:varsNO }

    $script:dumpProc = $False; $script:pidProc = ""
    $script:traceNet = $False; $global:onlyDiag = $false
}

# create folders
Function msrdCreateLogFolder {
    Param ($Path,$TimeStamp)

    If (!(Test-Path -Path $Path)) {
        $p = $Path.TrimEnd('\')
        Try {
            if ($TimeStamp -eq "No") {
                $LogMessage = "$(msrdGetLocalizedText "logfoldermsg") $p"
            } else {

                if ($global:msrdLangID -eq "AR") {
                    $date = Get-Date
                    $day = $date.Day.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $month = $date.Month.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $year = $date.Year.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $hour = $date.Hour.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $minute = $date.Minute.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $second = $date.Second.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $millisecond = $date.Millisecond.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                    $datemsg = "${hour}:${minute}:${second}.${millisecond} ${year}/${month}/${day}"
                } else {
			        $datemsg = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss.fff")
		        }

                $LogMessage = $datemsg + " $(msrdGetLocalizedText "logfoldermsg") $p"
            }

            if ($global:msrdGUI) {
                msrdAddOutputBoxLine $LogMessage "Yellow"
            } else {
                $host.ui.RawUI.ForegroundColor = "Yellow"
                Write-Output $LogMessage
                $host.ui.RawUI.ForegroundColor = $global:msrdConsoleColor
            }

            if ($global:msrdCollecting -or $global:msrdDiagnosing) {
                $LogMessage | Out-File -Append $global:msrdOutputLogFile
            }

            New-Item -Path $Path -ItemType Directory | Out-Null
        } Catch {
            $failedCommand = $_.InvocationInfo.Line.TrimStart()
            msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
            return
        }
    } else {
        msrdLogMessage $LogLevel.InfoLogFileOnly "$Path $(msrdGetLocalizedText "logfolderexistmsg")"
    }
}

# initialize folders
Function msrdInitFolders {

    if ($global:msrdTSSinUse) {
        $global:msrdLogFolder = "MSRD-Results-" + $env:computername
    } else {
        $global:msrdLogFolder = "MSRD-Results-" + $env:computername +"-" + $(get-date -f yyyyMMdd_HHmmss)
    }

    $global:msrdLogDir = "$global:msrdLogRoot\$global:msrdLogFolder\"
    $global:msrdLogFilePrefix = $env:computername + "_"
    $global:msrdBasicLogFolder = $global:msrdLogDir + $global:msrdLogFilePrefix
    $global:msrdWarningLogFile = $global:msrdBasicLogFolder + "MSRD-Collect-Warning.txt"
    $global:msrdErrorLogFile = $global:msrdBasicLogFolder + "MSRD-Collect-Error.txt"
    $global:msrdTempCommandErrorFile = $global:msrdBasicLogFolder + "MSRD-Collect-CommandError.txt"
    $global:msrdOutputLogFile = $global:msrdBasicLogFolder + "MSRD-Collect-Log.txt"
    $global:msrdEventLogFolder = $global:msrdBasicLogFolder + "EventLogs\"
    $global:msrdNetLogFolder = $global:msrdBasicLogFolder + "Networking\"
    $global:msrdRDSLogFolder = $global:msrdBasicLogFolder + "RDS\"
    $global:msrdAVDLogFolder = $global:msrdBasicLogFolder + "AVD\"
    $global:msrdRegLogFolder = $global:msrdBasicLogFolder + "RegistryKeys\"
    $global:msrdSchtaskFolder = $global:msrdBasicLogFolder + "ScheduledTasks\"
    $global:msrdSysInfoLogFolder = $global:msrdBasicLogFolder + "SystemInfo\"
    $global:msrdGenevaLogFolder = $global:msrdBasicLogFolder + "AVD\Monitoring\"

    if ($global:msrdAVD -or $global:msrdW365) { $global:msrdTechFolder = $global:msrdAVDLogFolder } else { $global:msrdTechFolder = $global:msrdRDSLogFolder }

    try {
        New-Item -itemtype directory -path $global:msrdLogDir -ErrorAction Stop | Out-null
    } catch {
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
    }
}

# get localized UI text
function msrdGetLocalizedText ($textID) {

    $textIDlang = $textID + $global:msrdLangID

    # Check if the text ID is present in the hashtable
    if ($global:msrdTextHashtable.ContainsKey($textIDlang)) {
        return $global:msrdTextHashtable[$textIDlang]
    } else {
        # If not found, fallback to English
        $textIDlang = $textID + "EN"
        if ($global:msrdTextHashtable.ContainsKey($textIDlang)) {
            return $global:msrdTextHashtable[$textIDlang]
        } else {
            # Return null if not found
            return $null
        }
    }
}

# update config file
function msrdUpdateConfigFile {
    Param([string]$configFile,[string]$key,[string]$value)

    $configpath = "$global:msrdScriptpath\$configFile"

    (Get-Content $configpath) | ForEach-Object {
        if ($_ -like "$key=*") {
            $_ = "$key=" + $value
        }
        $_
    } | Set-Content $configFile
}

# Play a system sound
function msrdPlaySystemSound([string]$soundName) {
    $SoundPath = "$env:windir\Media\" + $soundName + ".wav"

    $player = New-Object System.Media.SoundPlayer
    $player.SoundLocation = $SoundPath
    $player.Load()
    $player.Play()
}

# Restart script on language change
function msrdRestart {
    $global:msrdLangID = $global:msrdOldLangID
    $host.ui.RawUI.ForegroundColor = "Yellow"
    Write-Output (msrdGetLocalizedText "langChanged")
    $host.ui.RawUI.ForegroundColor = $global:msrdConsoleColor

    try {
        Start-Process PowerShell.exe -ArgumentList "$global:msrdCmdLine" -NoNewWindow
        If (($Null -ne $global:msrdTempCommandErrorFile) -and (Test-Path -Path $global:msrdTempCommandErrorFile)) { Remove-Item $global:msrdTempCommandErrorFile -Force | Out-Null }
        If ($global:fQuickEditCodeExist) { [msrdDisableConsoleQuickEdit]::SetQuickEdit($False) | Out-Null }
        if ($global:msrdGUI) { $global:msrdForm.Close() } else { Exit }

    } catch {
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
    }
}

#endregion initialization


#region messages
Function msrdLogMessage {
    param(
        [ValidateNotNullOrEmpty()][Int]$Level = $LogLevel.Normal,
        [string]$Message,
        [string]$Color,
		[Switch]$noDate,
        [Switch]$addAssist,
        [string]$LogPrefix
    )

    If (!(Test-Path -Path $global:msrdLogDir)) { msrdCreateLogFolder $global:msrdLogDir }

    $global:msrdPerc = "{0:P}" -f ($global:msrdProgress/100)

    $LogConsole = $True

    if ($LogPrefix) {
        if ($global:msrdLangID -eq "AR") {
            $Message = "$Message [$LogPrefix]"
        } else {
            $Message = "[$LogPrefix] $Message"
        }
    }

    switch ($Level) {
        '0' { $MessageColor = 'White' } # Normal
        '1' { $MessageColor = 'Yellow' } # Info
        '2' { $MessageColor = 'Magenta'; $Levelstr = 'WARNING' } # Warning
        '3' { $MessageColor = 'Red'; $Levelstr = 'ERROR' } # Error
        '5' { $LogConsole = $False; $Levelstr = 'ERROR' } # ErrorLogFileOnly
        '6' { $LogConsole = $False; $Levelstr = 'WARNING' } # WarnLogFileOnly
        '7' { $LogConsole = $False; $Levelstr = 'INFO' } # InfoLogFileOnly
    }

    if ($Color) { $MessageColor = $Color }

    if ($global:msrdLiveDiag) {
        if ($global:msrdLiveDiagSystem) {
            $liveDiagBox = $psBoxLiveDiagSystem
        } elseif ($global:msrdLiveDiagAVDRDS) {
            $liveDiagBox = $psBoxLiveDiagAVDRDS
        } elseif ($global:msrdLiveDiagAVDInfra) {
            $liveDiagBox = $psBoxLiveDiagAVDInfra
        } elseif ($global:msrdLiveDiagAD) {
            $liveDiagBox = $psBoxLiveDiagAD
        } elseif ($global:msrdLiveDiagNet) {
            $liveDiagBox = $psBoxLiveDiagNet
        } elseif ($global:msrdLiveDiagLogonSec) {
            $liveDiagBox = $psBoxLiveDiagLogonSec
        } elseif ($global:msrdLiveDiagIssues) {
            $liveDiagBox = $psBoxLiveDiagIssues
        } elseif ($global:msrdLiveDiagOther) {
            $liveDiagBox = $psBoxLiveDiagOther
        }
    }

    $Index = 1
    # In case of Warning/Error/Debug, add line and function name to message.
    If ($Level -eq $LogLevel.Error -or $Level -eq $LogLevel.ErrorLogFileOnly -or $Level -eq $LogLevel.Warning -or $Level -eq $LogLevel.WarnLogFileOnly) {
        $CallStack = Get-PSCallStack
        $CallerInfo = $CallStack[$Index]
		$2ndCallerInfo = $CallStack[$Index+1]
		$3rdCallerInfo = $CallStack[$Index+2]

        if ($CallerInfo.FunctionName -like "*msrdLogMessage") { $CallerInfo = $2ndCallerInfo }
        if ($CallerInfo.FunctionName -like "*msrdLogException") { $CallerInfo = $3rdCallerInfo }
        $FuncName = $CallerInfo.FunctionName
        If ($FuncName -eq "<ScriptBlock>") { $FuncName = "Main" }

        if ($global:msrdLangID -eq "AR") {
            $date = Get-Date
            $day = $date.Day.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
            $month = $date.Month.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
            $year = $date.Year.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
            $hour = $date.Hour.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
            $minute = $date.Minute.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
            $second = $date.Second.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
            $millisecond = $date.Millisecond.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
            $datemsg = "${hour}:${minute}:${second}.${millisecond} ${year}/${month}/${day}"
        } else {
			$datemsg = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss.fff")
		}

        $LogMessage = ($datemsg + ' [' + $FuncName + '(' + $CallerInfo.ScriptLineNumber + ')] ' + $Levelstr + ": " + $Message)

        # log to warning or error file
        if ($Level -eq $LogLevel.WarnLogFileOnly -or $Level -eq $LogLevel.Warning) {
            $LogMessage | Out-File -Append $global:msrdWarningLogFile
        } else {
            $LogMessage | Out-File -Append $global:msrdErrorLogFile
        }

    } elseif ($Level -eq $LogLevel.InfoLogFileOnly) {

            if ($global:msrdLangID -eq "AR") {
                $date = Get-Date
                $day = $date.Day.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $month = $date.Month.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $year = $date.Year.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $hour = $date.Hour.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $minute = $date.Minute.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $second = $date.Second.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $millisecond = $date.Millisecond.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $datemsg = "${year}/${month}/${day} ${hour}:${minute}:${second}.${millisecond}"
            } else {
			    $datemsg = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss.fff")
		    }

            $LogMessage = ($datemsg + ' ' + $Levelstr + ": " + $Message)
            $LogMessage | Out-File -Append $global:msrdOutputLogFile
    } else {
        if($noDate){
			$LogMessage = $Message
		} else {

            if ($global:msrdLangID -eq "AR") {
                $date = Get-Date
                $day = $date.Day.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $month = $date.Month.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $year = $date.Year.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $hour = $date.Hour.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $minute = $date.Minute.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $second = $date.Second.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $millisecond = $date.Millisecond.ToString().Replace('1', '١').Replace('2', '٢').Replace('3', '٣').Replace('4', '٤').Replace('5', '٥').Replace('6', '٦').Replace('7', '٧').Replace('8', '٨').Replace('9', '٩').Replace('0', '٠')
                $datemsg = "${year}/${month}/${day} ${hour}:${minute}:${second}.${millisecond}"
            } else {
			    $datemsg = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss.fff")
		    }

            $LogMessage = $datemsg + " " + $Message
        }
    }

    # percent progress
    if (($Level -eq $LogLevel.Normal) -or ($Level -eq $LogLevel.Info)) {
        [decimal]$global:msrdProgress = $global:msrdProgress + $global:msrdProgstep

        if (!$global:msrdGUI -and !($global:msrdGUIformLite -and $global:msrdGUIformLite.Visible) -and ($global:msrdCollecting -or $global:msrdDiagnosing)) {
            Write-Progress -Activity "$(msrdGetLocalizedText "collecting1") $global:msrdProgScenario $(msrdGetLocalizedText "collecting2")" -Status "$global:msrdPerc complete:" -PercentComplete $global:msrdProgress
        } elseif ($global:msrdGUI -or ($global:msrdGUIformLite -and $global:msrdGUIformLite.Visible)) {
            if (($global:msrdCollecting) -and !($global:msrdDiagnosing)) {
                $global:msrdProgbar.PerformStep()
                $global:msrdStatusBarLabel.Text = "$(msrdGetLocalizedText "collecting1") $global:msrdProgScenario $(msrdGetLocalizedText "collecting2")"
            } elseif ($global:msrdVersioncheck) {
                $global:msrdStatusBarLabel.Text = msrdGetLocalizedText "checkupd"
            }

            if (!($global:msrdCollecting) -and !($global:msrdDiagnosing) -and !($global:msrdVersioncheck)) {
                $global:msrdStatusBarLabel.Text = msrdGetLocalizedText "Ready"
            }
        }
    }

    if ($LogConsole) {
        If ($global:msrdGUI) {
            if ($global:msrdLiveDiag) {
                $liveDiagBox.SelectionStart = $liveDiagBox.TextLength
                $liveDiagBox.SelectionLength = 0
                $liveDiagBox.AppendText("$LogMessage`r`n")
                $liveDiagBox.SelectionStart = $liveDiagBox.TextLength
                $liveDiagBox.ScrollToCaret()
                $liveDiagBox.Refresh()
            } else {
                $msrdPsBox.SelectionStart = $msrdPsBox.TextLength
                $msrdPsBox.SelectionLength = 0
                $msrdPsBox.SelectionColor = $MessageColor
                $msrdPsBox.AppendText("$LogMessage`r`n")
                $msrdPsBox.SelectionStart = $msrdPsBox.TextLength
                $msrdPsBox.SelectionColor = $MessageColor
                $msrdPsBox.ScrollToCaret()
                $msrdPsBox.Refresh()
            }
        } else {
            $host.ui.RawUI.ForegroundColor = $MessageColor
            Write-Output $LogMessage
            $host.ui.RawUI.ForegroundColor = $global:msrdConsoleColor
        }

        If ($Level -ne $LogLevel.Error -and $Level -ne $LogLevel.ErrorLogFileOnly -and $Level -ne $LogLevel.Warning -and $Level -ne $LogLevel.WarnLogFileOnly) {
            $LogMessage | Out-File -Append $global:msrdOutputLogFile
        }
    }

    if (($global:msrdAssistMode -eq 1) -and (($Level -eq $LogLevel.Info) -or $addAssist)) {
        msrdLogMessageAssistMode $Message
    }
}

Function msrdLogMessageAssistMode {
    param( [ValidateNotNullOrEmpty()][string] $Message )

    if ($global:msrdAssistMode -eq 1) {
        Add-Type -AssemblyName System.Speech; (New-Object System.Speech.Synthesis.SpeechSynthesizer).Speak("$Message")
    }
}

Function msrdLogException {
    param([parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$Message, [parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][System.Management.Automation.ErrorRecord]$ErrObj)

    $ErrorCode = "0x" + [Convert]::ToString($ErrObj.Exception.HResult,16)
    $ExternalException = [System.ComponentModel.Win32Exception]$ErrObj.Exception.HResult
    $ErrorMessage = $Message `
        + "Command/Function: " + $ErrObj.CategoryInfo.Activity + " failed with $ErrorCode => " + $ExternalException.Message + "`n" `
        + $ErrObj.CategoryInfo.Reason + ": " + $ErrObj.Exception.Message + "`n" `
        + "ScriptStack:" + "`n" `
        + $ErrObj.ScriptStackTrace `
        + "`n"

    $ShortMessage = "$Message (" + $ErrObj.CategoryInfo.Reason + ": " + $ErrObj.Exception.Message + ")`n"

    if (-not $global:msrdLiveDiag) {
        if ($global:msrdGUI) {
            msrdAddOutputBoxLine $ShortMessage -Color Magenta
            if ($global:msrdCollecting -or $global:msrdDiagnosing) {
                msrdLogMessage $LogLevel.ErrorLogFileOnly $ErrorMessage
            }
        } else {
            $host.ui.RawUI.ForegroundColor = "Red"
            Write-Output $ShortMessage
            $host.ui.RawUI.ForegroundColor = $global:msrdConsoleColor
            if ($global:msrdCollecting -or $global:msrdDiagnosing) {
                msrdLogMessage $LogLevel.ErrorLogFileOnly $ErrorMessage
            }
        }
    } else {
        msrdAddOutputBoxLine $ShortMessage -Color Magenta
    }
}
#endregion messages


#region version checks
Function msrdVersionInt($verString) {
    $verSplit = $verString -split '\.'
    $vFull = 0
    for ($i = 0; $i -lt $verSplit.Count; $i++) {
        $vFull = ($vFull * 256) + [int]$verSplit[$i]
    }
    return $vFull
}

Function msrdCheckVersion($verCurrent, [switch]$selfUpdate) {
    $global:aucfail = $false

    if ($global:msrdGUI) {
        $global:msrdStatusBarLabel.Text = msrdGetLocalizedText "wait"
        msrdAddOutputBoxLine "$(msrdGetLocalizedText "vercheck1")"
    } else {
        msrdLogMessage $LogLevel.Normal "$(msrdGetLocalizedText "vercheck1")"
    }
    try {
        $global:msrdVersioncheck = $true
        $WebClient = New-Object System.Net.WebClient
        $verNew = $WebClient.DownloadString('https://cesdiagtools.blob.core.windows.net/windows/MSRD-Collect.ver')
        $verNew = $verNew.TrimEnd([char]0x0a, [char]0x0d)
        [long] $lNew = msrdVersionInt($verNew)
        [long] $lCur = msrdVersionInt($verCurrent)
        if($lNew -gt $lCur) {
            if ($global:msrdGUI) {
                $global:msrdForm.Text = 'MSRD-Collect (v' + $verCurrent + ') - $(msrdGetLocalizedText "vercheck2")'
            }

            if ($selfUpdate) {
                $updnotice = "$(msrdGetLocalizedText "vercheck3") v"+$verNew+" ($(msrdGetLocalizedText "vercheck4") v"+$verCurrent+").`n`n$(msrdGetLocalizedText "vercheck5")`n`n$(msrdGetLocalizedText "selfupdate1")"
            } else {
                $updnotice = "$(msrdGetLocalizedText "vercheck3") v"+$verNew+" ($(msrdGetLocalizedText "vercheck4") v"+$verCurrent+").`n`n$(msrdGetLocalizedText "vercheck5")`n`n$(msrdGetLocalizedText "vercheck5b")"
            }

            $wshell = New-Object -ComObject Wscript.Shell
            $answer = $wshell.Popup("$updnotice",0,"$(msrdGetLocalizedText "vercheck6")",4+32)
            if ($answer -eq 6) {

                if ($selfUpdate) {
                    $UpdLogFile = $global:msrdScriptpath + "\MSRD-Collect-UpdateLog.txt"

                    $msrdZipFile = Join-Path $env:TEMP 'MSRD-Collect_download.zip'
		            $msrdDownloadUrl = 'https://cesdiagtools.blob.core.windows.net/windows/MSRD-Collect.zip'

                    (Get-Date).ToString("yyyy/MM/dd HH:mm:ss.fff") + " " + "$(msrdGetLocalizedText "selfupdate2") (v$verCurrent -> v$verNew) $(msrdGetLocalizedText "selfupdate3") $env:username`n" | Out-File -Append $UpdLogFile

                    $selfUpdateMsg = "$(msrdGetLocalizedText "selfupdate4")"
                    if ($global:msrdGUI) {
		                msrdAddOutputBoxLine $selfUpdateMsg -Color Yellow
                    } else {
                        msrdLogMessage $LogLevel.Info ("$selfUpdateMsg")
                    }
		            (Get-Date).ToString("yyyy/MM/dd HH:mm:ss.fff") + " " + $selfUpdateMsg | Out-File -Append $UpdLogFile
                    Start-BitsTransfer $msrdDownloadUrl -Destination $msrdZipFile -ErrorAction SilentlyContinue | Out-File -Append $UpdLogFile

		            #save current config and update
                    $selfUpdateMsg = "$(msrdGetLocalizedText "selfupdate5") $global:msrdScriptpath\Config\MSRDC-Config.cfg_backup"
                    if ($global:msrdGUI) {
		                msrdAddOutputBoxLine $selfUpdateMsg -Color Yellow
                    } else {
                        msrdLogMessage $LogLevel.Info ("$selfUpdateMsg")
                    }
                    (Get-Date).ToString("yyyy/MM/dd HH:mm:ss.fff") + " " + $selfUpdateMsg | Out-File -Append $UpdLogFile
		            Copy-Item ($global:msrdScriptpath + "\Config\MSRDC-Config.cfg") ($global:msrdScriptpath + "\Config\MSRDC-Config.cfg_backup") -Force -ErrorAction SilentlyContinue | Out-File -Append $UpdLogFile

                    $selfUpdateMsg = "$(msrdGetLocalizedText "selfupdate6") $ENV:temp\MSRD-Collect_download.zip"
                    if ($global:msrdGUI) {
                        msrdAddOutputBoxLine $selfUpdateMsg -Color Yellow
                    } else {
                        msrdLogMessage $LogLevel.Info ("$selfUpdateMsg")
                    }
                    (Get-Date).ToString("yyyy/MM/dd HH:mm:ss.fff") + " " + $selfUpdateMsg | Out-File -Append $UpdLogFile
                    Expand-archive -LiteralPath $msrdZipFile -DestinationPath $global:msrdScriptpath -Force

                    $selfUpdateMsg = "$(msrdGetLocalizedText "selfupdate7")"
                    if ($global:msrdGUI) {
		                msrdAddOutputBoxLine $selfUpdateMsg -Color Yellow
                    } else {
                        msrdLogMessage $LogLevel.Info ("$selfUpdateMsg")
                    }
		            (Get-Date).ToString("yyyy/MM/dd HH:mm:ss.fff") + " " + $selfUpdateMsg | Out-File -Append $UpdLogFile
                    Move-Item ($global:msrdScriptpath + "\Config\MSRDC-Config.cfg_backup") ($global:msrdScriptpath + "\Config\MSRDC-Config.cfg") -Force -ErrorAction SilentlyContinue | Out-File -Append $UpdLogFile

                    $selfUpdateMsg = "$(msrdGetLocalizedText "selfupdate8")"
                    if ($global:msrdGUI) {
                        msrdAddOutputBoxLine $selfUpdateMsg -Color Yellow
                    } else {
                        msrdLogMessage $LogLevel.Info ("$selfUpdateMsg")
                    }
                    (Get-Date).ToString("yyyy/MM/dd HH:mm:ss.fff") + " " + $selfUpdateMsg | Out-File -Append $UpdLogFile
		            Remove-Item $msrdZipFile -ErrorAction SilentlyContinue | Out-File -Append $UpdLogFile

                    # Restart the script
                    $selfUpdateMsg = "$(msrdGetLocalizedText "selfupdate9")`n"
                    if ($global:msrdGUI) {
                        msrdAddOutputBoxLine $selfUpdateMsg -Color Lightgreen
                    } else {
                        msrdLogMessage $LogLevel.Info ("$selfUpdateMsg") -Color Green
                    }
                    (Get-Date).ToString("yyyy/MM/dd HH:mm:ss.fff") + " " + $selfUpdateMsg + "`n" | Out-File -Append $UpdLogFile

                    try {
                        Start-Process PowerShell.exe -ArgumentList "$global:msrdCmdLine" -NoNewWindow
                        If (($Null -ne $global:msrdTempCommandErrorFile) -and (Test-Path -Path $global:msrdTempCommandErrorFile)) { Remove-Item $global:msrdTempCommandErrorFile -Force | Out-Null }
                        If ($global:fQuickEditCodeExist) { [msrdDisableConsoleQuickEdit]::SetQuickEdit($False) | Out-Null }
                        if ($global:msrdGUI) { $global:msrdForm.Close() } else { Exit }

                    } catch {
                        $failedCommand = $_.InvocationInfo.Line.TrimStart()
                        msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
                    }

                } else {
                    Write-Output "$(msrdGetLocalizedText "vercheck7")"
                    Start-Process https://aka.ms/MSRD-Collect
                    if (($global:msrdTempCommandErrorFile -ne $null) -and (Test-Path -Path $global:msrdTempCommandErrorFile)) {
                        Remove-Item -Path $global:msrdTempCommandErrorFile -Force -ErrorAction SilentlyContinue
                    }

                    if ($global:fQuickEditCodeExist) { [msrdDisableConsoleQuickEdit]::SetQuickEdit($false) | Out-Null }
                    if ($global:msrdGUI) { $global:msrdForm.Close() } else { Exit }
                }

            } else {
                if ($global:msrdGUI) {
                    msrdAddOutputBoxLine ("$(msrdGetLocalizedText "vercheck8")") -Color Yellow
                } else {
                    msrdLogMessage $LogLevel.Info ("$(msrdGetLocalizedText "vercheck8")")
                }
            }

        } else {
            if ($global:msrdGUI) {
                msrdAddOutputBoxLine ("$(msrdGetLocalizedText "vercheck9") (v"+$verCurrent+")") -Color Lightgreen
            } else {
                msrdLogMessage $LogLevel.Info ("$(msrdGetLocalizedText "vercheck9") (v"+$verCurrent+")") -Color Green
            }
        }

    } catch {
        $global:aucfail = $true
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        $errorMessage = $_.Exception.Message.TrimStart()
        if ($global:msrdGUI) {
            msrdAddOutputBoxLine ("Error in $failedCommand $errorMessage") "Magenta"
        } else {
            msrdLogMessage $LogLevel.Error ("Error in $failedCommand $errorMessage")
        }
    }

    msrdProcDumpVerCheck
    msrdPsPingVerCheck

    if ($global:aucfail) {
        $disupd = "Automatic update check failed, possibily due to limited or no internet access.`n`nWould you like to disable automatic update check?`n`nYou can always enabled it again from the Tools menu (Check for Update on launch)."
        $dushell = New-Object -ComObject Wscript.Shell
        $duanswer = $dushell.Popup("$disupd",0,"Disable automatic update check",4+48)
        if ($duanswer -eq 6) {
            msrdUpdateConfigFile -configFile "Config\MSRDC-Config.cfg" -key "AutomaticVersionCheck" -value 0
            $global:msrdAutoVerCheck = 0
            if ($global:msrdGUI) {
                msrdAddOutputBoxLine "Automatic update check on script launch is Disabled`n"
                $global:AutoVerCheckMenuItem.Checked = $false
            } else {
                msrdLogMessage $LogLevel.Info ("Automatic update check on script launch is Disabled`n")
            }
        } else {
            msrdUpdateConfigFile -configFile "Config\MSRDC-Config.cfg" -key "AutomaticVersionCheck" -value 1
            $global:msrdAutoVerCheck = 1
            if ($global:msrdGUI) {
                msrdAddOutputBoxLine "Automatic update check on script launch is Enabled`n"
                $global:AutoVerCheckMenuItem.Checked = $true
            } else {
                msrdLogMessage $LogLevel.Info ("Automatic update check on script launch is Enabled`n")
            }
        }
    }

    if ($global:msrdGUI) {
        $global:msrdStatusBarLabel.Text = msrdGetLocalizedText "Ready"
    }

    $global:msrdVersioncheck = $false
}

Function msrdGetSysInternalsProcDump {

    try {
        $PDurl = 'https://github.com/MicrosoftDocs/sysinternals/blob/main/sysinternals/downloads/procdump.md'

        $PDWSProxy = New-Object System.Net.WebProxy
        $PDWSWebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $PDWSWebSession.Proxy = $PDWSProxy
        $PDWSWebSession.Credentials = [System.Net.CredentialCache]::DefaultCredentials
        $PDresponse = Invoke-WebRequest -Uri $PDurl -WebSession $PDWSWebSession -UseBasicParsing -TimeoutSec 30

        if ($PDresponse) {
            # Use the regular expression to extract the Procdump version
            $regexPattern = 'ProcDump v([\d\.]+)'
            $PDmatches = [regex]::Matches($PDresponse.Content, $regexPattern)

            if ($PDmatches.Count -gt 0) {
                # The version number should be in the first capturing group of the first match
                $PDonlineVersion = $PDmatches[0].Groups[1].Value
            }

            if ($PDonlineVersion -and ([version]$PDonlineVersion -gt [version]$global:msrdProcDumpVer)) {

                if ($global:msrdProcDumpVer -eq "1.0") {
                    $PDnotice = "This MSRD-Collect version is missing ProcDump.exe.`nIt is recommended to redownload the full MSRD-Collect (or TSS) package or download the latest version of ProcDump ($PDonlineVersion) from SysInternals.`nDo you want to download ProcDump from SysInternals now?"
                } else {
                    $PDnotice = "This MSRD-Collect version comes with ProcDump version $global:msrdProcDumpVer.`nA newer version of ProcDump ($PDonlineVersion) from SysInternals is available for download.`nDo you want to update the local ProcDump version now?"
                }

                $PDresult = [System.Windows.Forms.MessageBox]::Show($PDnotice, "New ProcDump version available", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)

                if ($PDresult -eq [System.Windows.Forms.DialogResult]::Yes) {
                    $PDzipFile = Join-Path $env:TEMP 'Procdump.zip'
                    $PDdownloadUrl = 'https://download.sysinternals.com/files/Procdump.zip'
                    Invoke-WebRequest -Uri $PDdownloadUrl -OutFile $PDzipFile
                    $PDunzippedFolder = Join-Path $env:TEMP 'Procdump'
                    Expand-Archive -Path $PDzipFile -DestinationPath $PDunzippedFolder -Force
                    msrdCreateLogFolder -Path "$global:msrdScriptpath\Tools" -TimeStamp No

                    Copy-Item -Path (Join-Path $PDunzippedFolder "procdump.exe") -Destination $global:msrdToolsFolder -Force
                    $global:msrdProcDumpExe = "$global:msrdScriptpath\Tools\procdump.exe"
                    Remove-Item $PDzipFile
                    Remove-Item $PDunzippedFolder -Recurse -Force

                    #update procdump version in .cfg file
                    msrdUpdateConfigFile -configFile "Config\MSRDC-Config.cfg" -key "ProcDumpVersion" -value $PDonlineVersion
                    $global:msrdProcDumpVer = $PDonlineVersion

                    $PDdownloadmsg = "ProcDump version $PDonlineVersion has been downloaded and extracted to $global:msrdToolsFolder`nConfig file has been updated"
                    if ($global:msrdGUI) {
                        msrdAddOutputBoxLine $PDdownloadmsg -Color Yellow
                    } else {
                        msrdLogMessage $LogLevel.Info $PDdownloadmsg
                    }
                } else {
                    if ($global:msrdProcDumpVer -eq "1.0") {
                        $noPDdownloadmsg = "You have chosen not to download the latest available ProcDump version ($PDonlineVersion) from SysInternals. It will not be possible to collect process dumps using MSRD-Collect"
                    } else {
                        $noPDdownloadmsg = "You have chosen not to download the latest available ProcDump version ($PDonlineVersion) from SysInternals. The current, local version $global:msrdProcDumpVer will be used when needed"
                    }
                    if ($global:msrdGUI) {
                        msrdAddOutputBoxLine $noPDdownloadmsg -Color Yellow
                    } else {
                        msrdLogMessage $LogLevel.Info $noPDdownloadmsg
                    }
                }

            } else {
                if ($global:msrdGUI) {
                    msrdAddOutputBoxLine ("$(msrdGetLocalizedText "PDvercheck1") ($global:msrdProcDumpVer)") -Color Lightgreen
                } else {
                    msrdLogMessage $LogLevel.Info ("$(msrdGetLocalizedText "PDvercheck1") ($global:msrdProcDumpVer)") -Color Green
                }
            }

            $PDWSProxy = $null

        } else {
            $global:msrdSetWarning = $true
            msrdLogMessage DiagFileOnly -Type "Text" -col 3 -Message "ProcDump version information could not be retrieved." -circle "red"
        }
    } catch {
        $global:aucfail = $true
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        $errorMessage = $_.Exception.Message.TrimStart()
        if ($global:msrdGUI) {
            msrdAddOutputBoxLine ("Error in $failedCommand $errorMessage") "Magenta"
        } else {
            msrdLogMessage $LogLevel.Error ("Error in $failedCommand $errorMessage")
        }
    }
}

Function msrdGetSysInternalsPsPing {

    try {
        $PsPurl = 'https://github.com/MicrosoftDocs/sysinternals/blob/main/sysinternals/downloads/psping.md'

        $PsPWSProxy = New-Object System.Net.WebProxy
        $PsPWSWebSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $PsPWSWebSession.Proxy = $PsPWSProxy
        $PsPWSWebSession.Credentials = [System.Net.CredentialCache]::DefaultCredentials
        $PsPresponse = Invoke-WebRequest -Uri $PsPurl -WebSession $PsPWSWebSession -UseBasicParsing -TimeoutSec 30

        if ($PsPresponse) {
            # Use the regular expression to extract the Procdump version
            $regexPattern = 'PsPing v([\d\.]+)'
            $PsPmatches = [regex]::Matches($PsPresponse.Content, $regexPattern)

            if ($PsPmatches.Count -gt 0) {
                # The version number should be in the first capturing group of the first match
                $PsPonlineVersion = $PsPmatches[0].Groups[1].Value
            }

            if ($PsPonlineVersion -and ([version]$PsPonlineVersion -gt [version]$global:msrdPsPingVer)) {

                if ($global:msrdPsPingVer -eq "1.0") {
                    $PsPnotice = "This MSRD-Collect version is missing PsPing.exe.`nIt is recommended to redownload the full MSRD-Collect (or TSS) package or download the latest version of PsPing ($PsPonlineVersion) from SysInternals.`nDo you want to download PsPing from SysInternals now?"
                } else {
                    $PsPnotice = "This MSRD-Collect version comes with PsPing version $global:msrdPsPingVer.`nA newer version of PsPing ($PsPonlineVersion) from SysInternals is available for download.`nDo you want to update the local PsPing version now?"
                }

                $PsPresult = [System.Windows.Forms.MessageBox]::Show($PsPnotice, "New PsPing version available", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)

                if ($PsPresult -eq [System.Windows.Forms.DialogResult]::Yes) {
                    $PsPzipFile = Join-Path $env:TEMP 'PsTools.zip'
                    $PsPdownloadUrl = 'https://download.sysinternals.com/files/PSTools.zip'
                    Invoke-WebRequest -Uri $PsPdownloadUrl -OutFile $PsPzipFile
                    $PsPunzippedFolder = Join-Path $env:TEMP 'PsPing'
                    Expand-Archive -Path $PsPzipFile -DestinationPath $PsPunzippedFolder -Force
                    msrdCreateLogFolder -Path "$global:msrdScriptpath\Tools" -TimeStamp No

                    Copy-Item -Path (Join-Path $PsPunzippedFolder "psping.exe") -Destination $global:msrdToolsFolder -Force
                    $global:msrdPsPingExe = "$global:msrdScriptpath\Tools\psping.exe"
                    Remove-Item $PsPzipFile
                    Remove-Item $PsPunzippedFolder -Recurse -Force

                    #update procdump version in .cfg file
                    msrdUpdateConfigFile -configFile "Config\MSRDC-Config.cfg" -key "PsPingVersion" -value $PsPonlineVersion
                    $global:msrdPsPingVer = $PsPonlineVersion

                    $PsPdownloadmsg = "PsPing version $PsPonlineVersion has been downloaded and extracted to $global:msrdToolsFolder`nConfig file has been updated"
                    if ($global:msrdGUI) {
                        msrdAddOutputBoxLine $PsPdownloadmsg -Color Yellow
                    } else {
                        msrdLogMessage $LogLevel.Info $PsPdownloadmsg
                    }
                } else {
                    if ($global:msrdPsPingVer -eq "1.0") {
                        $noPsPdownloadmsg = "You have chosen not to download the latest available PsPing version ($PsPonlineVersion) from SysInternals. It will not be possible to collect process dumps using MSRD-Collect"
                    } else {
                        $noPsPdownloadmsg = "You have chosen not to download the latest available PsPing version ($PsPonlineVersion) from SysInternals. The current, local version $global:msrdPsPingVer will be used when needed"
                    }
                    if ($global:msrdGUI) {
                        msrdAddOutputBoxLine $noPsPdownloadmsg -Color Yellow
                    } else {
                        msrdLogMessage $LogLevel.Info $noPsPdownloadmsg
                    }
                }

            } else {
                if ($global:msrdGUI) {
                    msrdAddOutputBoxLine ("$(msrdGetLocalizedText "PsPvercheck1") ($global:msrdPsPingVer)") -Color Lightgreen
                } else {
                    msrdLogMessage $LogLevel.Info ("$(msrdGetLocalizedText "PsPvercheck1") ($global:msrdPsPingVer)") -Color Green
                }
            }

            $PsPWSProxy = $null

        } else {
            $global:msrdSetWarning = $true
            msrdLogMessage DiagFileOnly -Type "Text" -col 3 -Message "PsPing version information could not be retrieved." -circle "red"
        }
    } catch {
        $global:aucfail = $true
        $failedCommand = $_.InvocationInfo.Line.TrimStart()
        $errorMessage = $_.Exception.Message.TrimStart()
        if ($global:msrdGUI) {
            msrdAddOutputBoxLine ("Error in $failedCommand $errorMessage") "Magenta"
        } else {
            msrdLogMessage $LogLevel.Error ("Error in $failedCommand $errorMessage")
        }
    }
}


Function msrdProcDumpVerCheck {

    if ($global:msrdProcDumpExe -eq "") {
        $noPDmsg = "ProcDump.exe could not be found. It will not be possible to collect a Process Dump through MSRD-Collect unless ProcDump.exe is available."
        if ($global:msrdGUI) {
            msrdAddOutputBoxLine $noPDmsg -Color Yellow
        } else {
            msrdLogMessage $LogLevel.Info $noPDmsg
        }
    }

    msrdGetSysInternalsProcDump

    #if ($global:msrdGUI) { msrdAddOutputBoxLine ("") } else { msrdLogMessage $LogLevel.Info "`n" -NoDate }
}

Function msrdPsPingVerCheck {

    if ($global:msrdPsPingExe -eq "") {
        $noPsPmsg = "PsPing.exe could not be found. It will not be possible to ping test specific endpoints through MSRD-Collect unless PsPing.exe is available."
        if ($global:msrdGUI) {
            msrdAddOutputBoxLine $noPsPmsg -Color Yellow
        } else {
            msrdLogMessage $LogLevel.Info $noPsPmsg
        }
    }

    msrdGetSysInternalsPsPing

    if ($global:msrdGUI) { msrdAddOutputBoxLine ("") } else { msrdLogMessage $LogLevel.Info "`n" -NoDate }
}

#endregion versioncheck


#region progress bar
Function msrdProgressStatusInit {
    Param(
        [ValidateNotNullOrEmpty()][int]$divider
    )

    $global:msrdProgress = 1
    $global:msrdProgstep = 100/$divider
    $global:msrdPerc = 1
    if ($global:msrdGUI -or ($global:msrdGUIformLite -and $global:msrdGUIformLite.Visible)) {
        $global:msrdProgbar.Value = 1
        $global:msrdProgbar.Minimum = 1
        $global:msrdProgbar.Maximum = $divider
    }
}

Function msrdProgressStatusEnd {

    $global:msrdProgress = 100
    $global:msrdPerc = 100
}
#endregion progress bar


#region collecting and archiving data
function msrdCloseMSRDC {

    $msrdc = Get-Process msrdc -ErrorAction SilentlyContinue     # Get the MSRDC process if it is running

    if ($msrdc) {
        $rdcnotice = msrdGetLocalizedText "msrdcNotice"
        $msrdcMsgClosed = "$(msrdGetLocalizedText 'msrdcClosed')`n"
        $msrdcMsgNotClosed = "$(msrdGetLocalizedText 'msrdcNotClosed')`n"
        $title = msrdGetLocalizedText "msrdcTitle"

        if (-not $global:msrdTSSinUse) {
            $msrdcResult = [System.Windows.Forms.MessageBox]::Show($rdcnotice, $title, [System.Windows.Forms.MessageBoxButtons]::YesNoCancel, [System.Windows.Forms.MessageBoxIcon]::Warning)

            if ($msrdcResult -eq [System.Windows.Forms.DialogResult]::Yes) {
                msrdLogMessage $LogLevel.Info "Closing MSRDC.exe ..."
                # Try to close the MSRDC window gracefully
                $msrdc.CloseMainWindow() | Out-Null
                Start-Sleep -Seconds 5

                # If the process is still running, kill it forcefully
                if (!$msrdc.HasExited) { $msrdc | Stop-Process -Force }

                msrdLogMessage $LogLevel.Info $msrdcMsgClosed
                Start-Sleep -Seconds 20
            } elseif ($msrdcResult -eq [System.Windows.Forms.DialogResult]::No) {
                msrdLogMessage $LogLevel.Info $msrdcMsgNotClosed
            } else {
                msrdLogMessage $LogLevel.Info "Data collection has been canceled."
                Break
            }
        } else {
            $UserConsent = Read-Host -Prompt ($rdcnotice + '`nAre you sure you want to continue? [Y/N]')

            if ($UserConsent.ToLower() -ne "y") {
                Write-Output "Closing MSRDC.exe ..."
                # Try to close the MSRDC window gracefully
                $msrdc.CloseMainWindow() | Out-Null
                Start-Sleep -Seconds 5

                # If the process is still running, kill it forcefully
                if (!$msrdc.HasExited) { $msrdc | Stop-Process -Force }
                Write-Output $msrdcMsgClosed
                Start-Sleep -Seconds 20
            } else {
                Write-Warning $msrdcMsgNotClosed
            }
        }
    }
}

Function msrdTestRegistryValue {
    param ([parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$Path, [parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$Value)

    try {
        return (Get-ItemProperty -Path $Path -ErrorAction Stop).$Value -ne $null
    }
    catch {
        return $false
    }
}

Function msrdGetRegKeys {
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()][string]$LogPrefix,
        [ValidateNotNullOrEmpty()]$RegHashtable
    )

    $RegHashtable.GetEnumerator() | ForEach-Object -Process {
        $RegPath = $_.Key
        $RegFile = $_.Value
        $RegExport = $RegPath.Replace(":", "")

        if (Test-Path $RegPath) {
            $RegRoot = (Split-Path -Path $RegPath -Qualifier).Replace(":", "")
            $RegOut = "$msrdRegLogFolder$global:msrdLogFilePrefix$RegRoot-$RegFile.txt"

            $Commands =@(
                "reg export '$RegExport' '$RegOut' /y 2>&1 | Out-Null"
            )
            msrdRunCommands -LogPrefix $LogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly "[$LogPrefix] Reg key '$RegExport' not found"
        }
    }
}

Function msrdGetEventLogs {
    Param(
        [ValidateNotNullOrEmpty()]$LogPrefix,
        [ValidateNotNullOrEmpty()]$EventHashtable
    )

    $EventHashtable.GetEnumerator() | ForEach-Object -Process {
        $EventSource = $_.Key
        $EventFile = $_.Value

        if (Get-WinEvent -ListLog $EventSource -ErrorAction Ignore) {
            $EventOut = Join-Path $global:msrdEventLogFolder "$global:msrdLogFilePrefix$EventFile.evtx"

            if (!(Test-Path $EventOut)) {
                $Commands =@(
                    "wevtutil epl '$EventSource' '$EventOut' 2>&1 | Out-Null"
                    "wevtutil al '$EventOut' /l:en-us 2>&1 | Out-Null"
                )
                msrdRunCommands -LogPrefix $LogPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
            } else {
				msrdLogMessage $LogLevel.InfoLogFileOnly -LogPrefix $LogPrefix -Message "Event log '$EventSource' has already been collected"
            }
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $LogPrefix -Message "Event log '$EventSource' not found"
        }
    }
}

Function msrdGetLogFiles {
    Param(
        [ValidateNotNullOrEmpty()][string]$LogPrefix,
        [ValidateNotNullOrEmpty()][string]$LogFilePath,
        [ValidateNotNullOrEmpty()][string]$LogFileID,
        [ValidateNotNullOrEmpty()][ValidateSet("Files","Packages")][string]$Type,
        [ValidateNotNullOrEmpty()][string]$OutputFolder
    )

    msrdLogMessage $LogLevel.Normal -LogPrefix $LogPrefix -Message "Copy-Item '$LogFilePath'"

    if (-not (Test-Path -Path $LogFilePath)) {
        msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $LogPrefix -Message "'$LogFilePath' not found"
        return
    } else {
        switch ($Type) {
            "Files" {
                $LogFile = Join-Path $OutputFolder "$env:computername`_$LogFileID"
                Try {
                    Copy-Item -Path $LogFilePath -Destination $LogFile -ErrorAction Continue -Force 2>&1 | Out-Null
                } Catch {
                    $failedCommand = $_.InvocationInfo.Line.TrimStart()
                    msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
                }
            }

            "Packages" {
                # to be redesigned (msrdGetCoreRDSAVDInfo)
            }
        }
    }
}

function msrdGetRDRoleInfo {
    param ($Class, $Namespace, $ComputerName = "localhost")

    Get-CimInstance -Class $Class -Namespace $Namespace -ComputerName $ComputerName -ErrorAction Continue 2>>$global:msrdErrorLogFile

}

function msrdGetLocalGroupMembership {
    param($logPrefix, [string]$groupName, [string]$outputFile, [switch]$isDomain)

    if ([ADSI]::Exists("WinNT://localhost/$groupName")) {
        $Commands = @(
            "net localgroup '$groupName' 2>&1 | Out-File -Append '$outputFile'"
        )
        msrdRunCommands -LogPrefix $logPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
    } elseif ($isDomain) {
        $domaincheck = (get-ciminstance -Class Win32_ComputerSystem).PartOfDomain
        if ($domaincheck) {
            $Commands = @(
                "net localgroup '$groupName' /domain 2>&1 | Out-File -Append '$outputFile'"
            )
            msrdRunCommands -LogPrefix $logPrefix -CmdletArray $Commands -ThrowException:$False -ShowMessage:$True -ShowError:$True
        } else {
            msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $logPrefix -Message "Machine is not part of a domain. '$groupName' group not found"
        }
    } else {
        msrdLogMessage $LogLevel.WarnLogFileOnly -LogPrefix $logPrefix -Message "'$groupName' group not found"
    }
}

Function msrdRunCommands {
    param(
        [parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$LogPrefix,
        [parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]$CmdletArray,
        [parameter(Mandatory=$true)][Bool]$ThrowException,
        [parameter(Mandatory=$true)][Bool]$ShowMessage,
        [parameter(Mandatory=$true)][Bool]$ShowError
    )

    ForEach($CommandLine in $CmdletArray){
        # Get file name of output file. This is used later to add command header line.
		$HasOutFile = $CommandLine -like "*Out-File*"
		If($HasOutFile){
			$OutputFile = $Null
			$Token = $CommandLine -split ' '
			$OutputFileCandidate = $Token[$Token.count-1] # Last token should be output file.
			If($OutputFileCandidate -match '\.txt' -or $OutputFileCandidate -match '\.log'){
				$OutputFile = $OutputFileCandidate
                $OutputFile = $OutputFile -replace "'",""
			}
		}

        $tmpMsg = $CommandLine -replace " \| Out-File.*$","" -replace " \| Out-Null.*$","" -replace "\-ErrorAction Stop","" -replace "\-ErrorAction SilentlyContinue","" -replace "\-ErrorAction Ignore",""
        $CmdlineForDisplayMessage = $tmpMsg -replace "' '(.*?)' /y","'" -replace "' '(.*?)' 2>&1","'" -replace " 2>&1","" -replace " --log-file.*$","" -replace " -zip.*$",""

        Try {
            If ($ShowMessage) { msrdLogMessage $LogLevel.Normal -LogPrefix $LogPrefix -Message $CmdlineForDisplayMessage }

            # There are some cases where Invoke-Expression does not reset $global:LASTEXITCODE and $global:LASTEXITCODE has old error value.
			# Hence we initialize the $global:LASTEXITCODE(PowerShell managed value) if it has error before running command.
			If($Null -ne $global:LASTEXITCODE -and $global:LASTEXITCODE -ne 0){
				$global:LASTEXITCODE = 0
			}

            # Add a header if there is an output file.
			If ($Null -ne $OutputFile){
				"======================================" | Out-File -Append $OutputFile
				"$((Get-Date).ToString("yyyy/MM/dd HH:mm:ss.fff")) : $CmdlineForDisplayMessage" | Out-File -Append $OutputFile
				"======================================`n" | Out-File -Append $OutputFile
			}

            # Run actual command here.
			# We redirect all streams to temporary error file as some commands output an error to warning stream(3) and others are to error stream(2).
            Invoke-Expression $CommandLine -ErrorAction Stop *> $global:msrdTempCommandErrorFile

            # It is possible $global:LASTEXITCODE becomes null in some sucessful case, so perform null check and examine error code.
            If ($Null -ne $global:LASTEXITCODE -and $global:LASTEXITCODE -ne 0 -and $global:LASTEXITCODE -ne -2){ # procdump may exit with 0xfffffffe = -2
                $Message = "An error occurred while running $CommandLine (Error=0x" + [Convert]::ToString($global:LASTEXITCODE,16) + ")"
                msrdLogMessage $LogLevel.ErrorLogFileOnly "$Message`n"
                If (Test-Path -Path $global:msrdTempCommandErrorFile) {
                    # Always log error to error file.
                    Get-Content $global:msrdTempCommandErrorFile -ErrorAction Ignore | Out-File -Append $global:msrdErrorLogFile
                    # If -ShowError:$True, show the error to console.
                    If ($ShowError) {
                        $host.ui.RawUI.ForegroundColor = "Red"
                        Write-Output "$Message"
                        Write-Output ('---------- ERROR MESSAGE ----------')
                        Get-Content $global:msrdTempCommandErrorFile -ErrorAction Ignore
                        Write-Output ('-----------------------------------')
                        $host.ui.RawUI.ForegroundColor = $global:msrdConsoleColor
                    }
                }
                Remove-Item $global:msrdTempCommandErrorFile -Force -ErrorAction Ignore | Out-Null
                If ($ThrowException) { Throw($Message) }
            } else {
                Remove-Item $global:msrdTempCommandErrorFile -Force -ErrorAction Ignore | Out-Null
            }

            If ($Null -ne $OutputFile){ "`n" | Out-File -Append $OutputFile }

        } Catch {
            If ($ThrowException) {
                Throw $_   # Leave the error handling to upper function.
            } Else {
                $Message = "An error occurred in Invoke-Expression with $CommandLine"
                msrdLogException ($Message) -ErrObj $_
                If ($ShowError){
                    $host.ui.RawUI.ForegroundColor = "Red"
                    Write-Output ("ERROR: $Message")
                    Write-Output ('---------- ERROR MESSAGE ----------')
                    Write-Output $_
                    Write-Output ('-----------------------------------')
                    $host.ui.RawUI.ForegroundColor = $global:msrdConsoleColor
                }
                Continue
            }
        }
    }
}

function msrdCollectData {
    param([bool[]]$varsCore, [bool[]]$varsProfiles, [bool[]]$varsActivation, [bool[]]$varsMSRA, [bool[]]$varsSCard, [bool[]]$varsIME, [bool[]]$varsTeams, [bool[]]$varsMSIXAA, [bool[]]$varsHCI, [bool]$traceNet, [bool]$dumpProc, [int]$pidProc, [switch]$skipDiagCounter = $false)

    $global:msrdCollecting = $True
    $global:msrdDiagnosing = $False

    # init progress indicator
    $msrdDivider = 1
    if ($traceNet) { $msrdDivider++ }
    if ($true -in $varsCore) { $msrdDivider += 262 }
    if ($true -in $varsProfiles) { $msrdDivider += 55 }
    if ($true -in $varsActivation) { $msrdDivider += 3 }
    if ($true -in $varsMSRA) { $msrdDivider += 10 }
    if ($true -in $varsSCard) { $msrdDivider += 10 }
    if ($true -in $varsIME) { $msrdDivider += 36 }
    if ($true -in $varsTeams) { $msrdDivider += 4 }
    if ($true -in $varsMSIXAA) { $msrdDivider += 3 }
    if ($true -in $varsHCI) { $msrdDivider += 6 }
    if ((-not $global:onlyDiag) -and (-not $skipDiagCounter)) { $msrdDivider += 81 } #diagnostics

    msrdProgressStatusInit $msrdDivider

    if ($traceNet) {
        $global:msrdProgScenario = "Tracing"
        Import-Module -Name "$global:msrdScriptpath\Modules\MSRDC-Tracing" -DisableNameChecking -Force
        msrdRunUEX_NetTracing
        Remove-Module MSRDC-Tracing
    }

    if ($true -in $varsCore) {
        $global:msrdProgScenario = "Core"
        Import-Module -Name "$global:msrdScriptpath\Modules\MSRDC-FwHtml" -DisableNameChecking -Force -Scope Global
        Import-Module -Name "$global:msrdScriptpath\Modules\MSRDC-Core" -DisableNameChecking -Force
        msrdCollectUEX_AVDCoreLog -varsCore $varsCore -dumpProc $dumpProc -pidProc $pidProc
        Remove-Module MSRDC-Core
    }

    if ($true -in $varsProfiles) {
        $global:msrdProgScenario = "Profiles"
        Import-Module -Name "$global:msrdScriptpath\Modules\MSRDC-Profiles" -DisableNameChecking -Force
        msrdCollectUEX_AVDProfilesLog -varsProfiles $varsProfiles
        Remove-Module MSRDC-Profiles
    }

    if ($true -in $varsActivation) {
        $global:msrdProgScenario = "Activation"
        Import-Module -Name "$global:msrdScriptpath\Modules\MSRDC-Activation" -DisableNameChecking -Force
        msrdCollectUEX_AVDActivationLog -varsActivation $varsActivation
        Remove-Module MSRDC-Activation
    }

    if ($true -in $varsMSRA) {
        $global:msrdProgScenario = "Remote Assistance"
        Import-Module -Name "$global:msrdScriptpath\Modules\MSRDC-MSRA" -DisableNameChecking -Force
        msrdCollectUEX_AVDMSRALog -varsMSRA $varsMSRA
        Remove-Module MSRDC-MSRA
    }

    if ($true -in $varsSCard) {
        $global:msrdProgScenario = "Smart Card"
        Import-Module -Name "$global:msrdScriptpath\Modules\MSRDC-SCard" -DisableNameChecking -Force
        msrdCollectUEX_AVDSCardLog -varsSCard $varsSCard
        Remove-Module MSRDC-SCard
    }

    if ($true -in $varsIME) {
        $global:msrdProgScenario = "IME"
        Import-Module -Name "$global:msrdScriptpath\Modules\MSRDC-IME" -DisableNameChecking -Force
        msrdCollectUEX_AVDIMELog -varsIME $varsIME
        Remove-Module MSRDC-IME
    }

    if ($true -in $varsTeams) {
        $global:msrdProgScenario = "Teams"
        Import-Module -Name "$global:msrdScriptpath\Modules\MSRDC-Teams" -DisableNameChecking -Force
        msrdCollectUEX_AVDTeamsLog -varsTeams $varsTeams
        Remove-Module MSRDC-Teams
    }

    if ($true -in $varsMSIXAA) {
        $global:msrdProgScenario = "App Attach"
        Import-Module -Name "$global:msrdScriptpath\Modules\MSRDC-AppAttach" -DisableNameChecking -Force
        msrdCollectUEX_AVDMSIXAALog -varsMSIXAA $varsMSIXAA
        Remove-Module MSRDC-AppAttach
    }

    if ($true -in $varsHCI) {
        $global:msrdProgScenario = "Azure Stack HCI"
        Import-Module -Name "$global:msrdScriptpath\Modules\MSRDC-HCI" -DisableNameChecking -Force
        msrdCollectUEX_AVDHCILog -varsHCI $varsHCI
        Remove-Module MSRDC-HCI
    }

    $global:msrdCollecting = $False
    msrdLogMessage $LogLevel.Info -Message "$(msrdGetLocalizedText "fdcmsg")`n" -Color "Cyan"

    if ($skipDiagCounter) { msrdProgressStatusEnd }

    [System.GC]::Collect()
}

Function msrdCollectDataDiag {
    param ([bool[]]$varsSystem, [bool[]]$varsAVDRDS, [bool[]]$varsInfra, [bool[]]$varsAD, [bool[]]$varsNET, [bool[]]$varsLogSec, [bool[]]$varsIssues, [bool[]]$varsOther)

    if ($global:onlyDiag) {
        msrdProgressStatusInit 81
    }

    if (-not (Get-Module -Name MSRDC-FwHtml)) {
        Import-Module -Name "$global:msrdScriptpath\Modules\MSRDC-FwHtml" -DisableNameChecking -Force -Scope Global
    }

    $global:msrdDiagnosing = $True
    $global:msrdProgScenario = "Diagnostics"

    Import-Module -Name "$global:msrdScriptpath\Modules\MSRDC-Diagnostics" -DisableNameChecking -Force
    $parameters = @{
        varsSystem = $varsSystem
        varsAVDRDS = $varsAVDRDS
        varsInfra = $varsInfra
        varsAD = $varsAD
        varsNET = $varsNET
        varsLogSec = $varsLogSec
        varsIssues = $varsIssues
        varsOther = $varsOther
    }
    msrdRunUEX_RDDiag @parameters

    "`n`n" | Out-File -Append $global:msrdOutputLogFile

    msrdLogMessage $LogLevel.Info "$(msrdGetLocalizedText "fdiagmsg")`n" -Color "Cyan"

    $global:msrdDiagnosing = $False
    if ($global:msrdGUI -or ($global:msrdGUIformLite -and $global:msrdGUIformLite.Visible)) {
        $global:msrdProgbar.Value = $global:msrdProgbar.Maximum;
        $global:msrdStatusBarLabel.Text = "$(msrdGetLocalizedText "wait")"
    }

    Remove-Module MSRDC-FwHtml

    msrdProgressStatusEnd
}

Function msrdArchiveData {
    param( [bool[]]$varsCore )

    $mspathnfo = $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "Msinfo32.nfo"
    $dllpath = $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "System32_DLL.txt"
    $gpresultpath = $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "Gpresult.html"
    $powercfgpath = $global:msrdSysInfoLogFolder + $global:msrdLogFilePrefix + "PowerReport.html"
    $acttime = 0
    $waittime = 20000
    $maxtime = 180000
    $nfoproc = Get-Process msinfo32 -ErrorAction SilentlyContinue

    if ($global:msrdGUI -or ($global:msrdGUIformLite -and $global:msrdGUIformLite.Visible)) {
        $global:msrdProgbar.Visible = $false
        $global:msrdStatusBarLabel.Text = msrdGetLocalizedText "arcmsg"
    }

    if (($global:WinVerMajor -eq "10") -and ($global:msrdOSVer -notlike "*Windows Server*")) {
        $testpowercfgpath = Test-Path $powercfgpath
    } else {
        $testpowercfgpath = $true
    }

    if (!($global:onlyDiag)) {
        while ($varsCore[7] -and (!(Test-Path $mspathnfo) -or !(Test-Path $dllpath) -or !(Test-Path $gpresultpath) -or !($testpowercfgpath) -or ($nfoproc))) {
            if ($acttime -lt $maxtime) {
                msrdLogMessage $LogLevel.Normal -Message "$(msrdGetLocalizedText "bgjob1msg")" -Color "White"
                Start-Sleep -m $waittime
                $acttime += $waittime
                $nfoproc = Get-Process msinfo32 -ErrorAction SilentlyContinue
            } else {
                msrdLogMessage $LogLevel.Warning -Message "$(msrdGetLocalizedText "bgjob2msg")`n"
                $nfoproc = Get-Process msinfo32 -ErrorAction SilentlyContinue
                if ($nfoproc) {
                    $nfoproc.CloseMainWindow() | Out-Null
                }
                Start-Sleep 5
                if (!$nfoproc.HasExited) { $nfoproc | Stop-Process -Force }
                Break
            }
        }
        Get-Job | Wait-Job | Remove-Job
    }

    $destination = "$global:msrdLogRoot\$msrdLogFolder.zip"

    msrdLogMessage $LogLevel.Info "$(msrdGetLocalizedText "archmsg")" -Color "Cyan"

    Try {
        Add-Type -Assembly 'System.IO.Compression.FileSystem'
		[System.IO.Compression.ZipFile]::CreateFromDirectory($global:msrdLogDir, $destination)
    } Catch {
		$ErrorMessage = "An exception occurred during log folder compression`n" + $_.Exception.Message
		msrdLogException $ErrorMessage $_
		Return
	}

    if ($global:msrdGUI -or ($global:msrdGUIformLite -and $global:msrdGUIformLite.Visible)) {
        $global:msrdStatusBarLabel.Text = msrdGetLocalizedText "Ready"
    }

    if (Test-path -path $destination) {
        if ($global:msrdGUI) {
            msrdLogMessage $LogLevel.Normal "$(msrdGetLocalizedText "zipmsg") $destination`n" -Color "#00ff00" -addAssist
        } else {
            msrdLogMessage $LogLevel.Normal "$(msrdGetLocalizedText "zipmsg") $destination`n" -Color "Green" -addAssist
        }
        if ($global:msrdPlaySounds -eq 1) { msrdPlaySystemSound "Windows Logon" }
    } else {
        msrdLogMessage $LogLevel.Warning "$(msrdGetLocalizedText "ziperrormsg") $global:msrdLogRoot\$msrdLogFolder`n" -addAssist
        if ($global:msrdPlaySounds -eq 1) { msrdPlaySystemSound "Windows Exclamation" }
    }
    msrdLogMessage $LogLevel.Normal "$(msrdGetLocalizedText "dtmmsg")`n" -Color "White" -addAssist

    Remove-Module MSRDC-Diagnostics -ErrorAction SilentlyContinue

    explorer $global:msrdLogRoot

    if ($global:msrdGUI) {
        $global:msrdStatusBarLabel.Text = msrdGetLocalizedText "Ready"
    }

    [System.GC]::Collect()
}


function msrdStartShowConsole {
    param ($nocfg)

    try {
        $PSConsole = [Console.Window]::GetConsoleWindow()
        [Console.Window]::ShowWindow($PSConsole, 5) | Out-Null
        if ($global:msrdGUI) { msrdAddOutputBoxLine "$(msrdGetLocalizedText "conVisible")`n" }
        if (!($nocfg)) {
            msrdUpdateConfigFile -configFile "Config\MSRDC-Config.cfg" -key "ShowConsoleWindow" -value 1
        }
    } catch {
        if ($global:msrdGUI) { msrdAddOutputBoxLine "Error showing console window: $($_.Exception.Message)" }
        else { msrdLogMessage $LogLevel.Warning "Error showing console window: $($_.Exception.Message)" }
    }
}

#hide the console window
function msrdStartHideConsole {
    try {
        $PSConsole = [Console.Window]::GetConsoleWindow()
        [Console.Window]::ShowWindow($PSConsole, 0) | Out-Null
        if ($global:msrdGUI) { msrdAddOutputBoxLine "$(msrdGetLocalizedText "conHidden")`n" }
        msrdUpdateConfigFile -configFile "Config\MSRDC-Config.cfg" -key "ShowConsoleWindow" -value 0
    } catch {
        if ($global:msrdGUI) { msrdAddOutputBoxLine "Error hiding console window: $($_.Exception.Message)" }
        else { msrdLogMessage $LogLevel.Warning "Error hiding console window: $($_.Exception.Message)" }
    }
}

#endregion collecting and archiving data

Export-ModuleMember -Function *
# SIG # Begin signature block
# MIIoOQYJKoZIhvcNAQcCoIIoKjCCKCYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBTCuCr6I8rbBPM
# oqslRpw+7vpi2ICRHKgh5lXg+soz3KCCDYUwggYDMIID66ADAgECAhMzAAADri01
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
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIB0a
# 39xVCdD5PnjYZv4qUcq7SBGng4cuZLV08sCnb3KiMEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEAFGEwrEumPNxqaAeGzj+7jCI+oC3K59ZQu4zE
# hvY/qJub22saOk79UsTSGFU1D7rh0Vypr1wqzUeTuWH4jUdHYRT0kM1/X2nx2jhw
# 1Y4jvQp3ILFj6KATpjj3aPO47K/DrL3+zf4DT+i21P2Hp/8mrpoWHM22oLgKPsaT
# N5lUPAKiNaiUWlgDzj2XACG1BDptcy2A7Tmho6zLCkaTD5VENB17qmCvRIk4adlX
# sEFxVGycAMEpXkkYb5gpVCDb8q39njRZoXZYcmAlOQLobWewZO3SqAyW6fXzmeCR
# YgMSbaDODL1iCxnJF5azMndfDq6eqaT4IEtLD1xJmq0KDHYWOKGCF5QwgheQBgor
# BgEEAYI3AwMBMYIXgDCCF3wGCSqGSIb3DQEHAqCCF20wghdpAgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCDMQAAhbH5hgF01iSPgBsuZL+8u/MoI0WFE
# OCIIQL1KkQIGZc3/hhnoGBMyMDI0MDIyMDEyMTcwMi4zMjJaMASAAgH0oIHRpIHO
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
# CyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCB7/2eQWxGhqqNAcJn8SAswRrcb
# uJYYilx6tK5EbEN9TTCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIOU2XQ12
# aob9DeDFXM9UFHeEX74Fv0ABvQMG7qC51nOtMIGYMIGApH4wfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAHnLo8vkwtPG+kAAQAAAecwIgQg5strNsYb
# AJScKAE5aG3Lom5LvoS5tFxoBQ4e8fINHe0wDQYJKoZIhvcNAQELBQAEggIAhKk6
# ONqBMlNAPbqNLU1hr/4OB06jSpiqyX4/n6IY68wPwxaci6pY7pKfnqU7b8EgVoJ1
# tuQrkym+uovIQhnn7TuJe6Sd4P5fiGHVZVUJQgcdaQaJZ6JXLgH4HxcgjUUJKv+f
# Ek0mFCEHySZDB5otNMQsOTzgiVPlNi3loaL75RzJ+dDSpRnn0zxjIBY9NiAU/0eC
# 8JwsPJupI7hbAgdVwBLHFdFRY+26m40TjhAtSemp7TMRRcUSphaWX/cFWZ6Onvef
# Jm19Lva7FUDi4ytsMb7fHd72PH1Hm1HFNT+zjGR2ZyVLeq2D24gEx2F6p7e9IKEo
# EMFDfXBx1tekSwRrXtH1H0+L2uYQcpxkLaTXSKdH0KH26zTjxbmW8tZntDcyzCI9
# iCqpUUvTgv0NU+LkI4y3utcJeUeciTF6MBBhL67yBJSxS8mCNXqwxqcDVXZQ416y
# /RwUwwN97VygO/cA6/TiUXLBA6q4zBnIfDUF70QS1eyj034xVzQgbq4AYkO3wmyw
# iKhM+j4u3R1Zkef0GsaJCruStkpcYNqS5nIe33CCrSmn7CZuPfr3H9b1jpmoxMiS
# aPQnteBVAIuWeJxpqqqseqEMvk8+a04HiUAn2czsvMt8QnLuRzuOv9aAkGnJ7k66
# EPOjXz7D440K3wQH81gA9bHntTwyjssKoqoQtU8=
# SIG # End signature block
