<#
.SYNOPSIS
    Simplify data collection and diagnostics for troubleshooting Microsoft Remote Desktop (RDP/RDS/AVD/W365) related issues and a convenient method for submitting and following quick & easy action plans.

.DESCRIPTION
    This script is designed to collect information that will help Microsoft Customer Support Services (CSS) troubleshoot an issue you may be experiencing with Microsoft Remote Desktop solutions.
    The collected data may contain Personally Identifiable Information (PII) and/or sensitive data, such as (but not limited to) IP addresses; PC names; and user names.
    The script will save the collected data in a folder (default C:\MS_DATA) and also compress the results into a ZIP file.
    This folder and its contents or the ZIP file are not automatically sent to Microsoft.
    You can send the ZIP file to Microsoft CSS using a secure file transfer tool - Please discuss this with your support professional and also any concerns you may have.
    Find our privacy statement here: https://privacy.microsoft.com/en-US/privacystatement

    Run 'Get-Help .\MSRD-Collect.ps1 -Full' for more details.

    USAGE SUMMARY:
    The script must be run with elevated permissions in order to collect all required data.
    Run the script on session host VMs and/or on Windows based devices from where you connect to the hosts, as needed.

    The script has multiple module (.psm1) files located in a "Modules" folder. This folder (with its underlying .psm1 files) must stay in the same folder as the main MSRD-Collect.ps1
    file for the script to work properly.
    The script will import the required module(s) on the fly when specific data is being invoked. You do not need to manually import the modules.

    When launched without any command line parameters, the script will start in GUI mode where you can select one or more data collection or diagnostics scenarios.
    If you prefer to run the script without a GUI or to automate data collection/diagnostics, use command line parameters.
    Diagnostics will run regardless if other data collection scenarios have been selected.

.NOTES
    Author           : Robert Klemencz
    Requires         : At least PowerShell version 5.1 and to be run elevated
    Version          : See: $global:msrdVersion

.LINK
    Download: https://aka.ms/MSRD-Collect
    Feedback: https://aka.ms/MSRD-Collect-Feedback

.PARAMETER Machine
    Indicates the remote desktop solution involved when using the machine from where data is collected. This is a mandatory parameter when not using the GUI
    Based on the provided value, only data specific to that solution will be collected
    Available values are:
        isAVD      : Azure Virtual Desktop
        isRDS      : Remote Desktop Services or direct (non-AVD/non-W365) RDP connection
        isW365     : Windows 365 Cloud PC

.PARAMETER Role
    Indicates the role of the machine in the selected remote desktop solution. This is a mandatory parameter when not using the GUI
    Based on the provided value, only data specific to that role will be collected
    Available values are:
        isSource   : Source machine from where you connect to other machines using a Remote Desktop client
        isTarget   : Target machine to which you connect to or any RDS server in a RDS deployment

.PARAMETER Core
    Collect basic AVD/RDS troubleshooting data (without Profiles/Teams/MSIX App Attach/MSRA/Smart Card/IME/Azure Stack HCI related data). Diagnostics will run at the end.

.PARAMETER Profiles
    Collect Core + Profiles troubleshooting data. Diagnostics will run at the end.

.PARAMETER Activation
    Collect Core + OS Licensing/Activation troubleshooting data. Diagnostics will run at the end.

.PARAMETER MSRA
    Collect Core + Remote Assistance troubleshooting data. Diagnostics will run at the end.

.PARAMETER SCard
    Collect Core + Smart Card troubleshooting data. Diagnostics will run at the end.

.PARAMETER IME
    Collect Core + input method troubleshooting data. Diagnostics will run at the end.

.PARAMETER Teams
    Collect Core + Microsoft Teams troubleshooting data. Diagnostics will run at the end. (AVD specific)

.PARAMETER MSIXAA
    [Deprecated] Collect Core + App Attach troubleshooting data. Diagnostics will run at the end. (AVD specific)

.PARAMETER AppAttach
    [Replaces MSIXAA] Collect Core + App Attach troubleshooting data. Diagnostics will run at the end. (AVD specific)

.PARAMETER HCI
    Collect Core + Azure Stack HCI troubleshooting data. Diagnostics will run at the end. (AVD specific)

.PARAMETER DumpPID
    Collect Core troubleshooting data + Collect a process dump based on the provided PID. Diagnostics will run at the end.

.PARAMETER NetTrace
    Collect a netsh network trace (netsh trace start scenario=netconnection maxsize=2048 filemode=circular overwrite=yes report=yes)

.PARAMETER DiagOnly
    Skip collecting troubleshooting data (even if any other parameters are specificed) and will only perform diagnostics. The results of the diagnostics will be stored in the 'MSRD-Diag.txt' and 'MSRD-Diag.html' files.
    Depending on the issues found during the diagnostic, additional files may be generated with exported event log entries coresponding to those identified issues.

.PARAMETER AcceptEula
    Silently accepts the Microsoft Diagnostic Tools End User License Agreement.

.PARAMETER AcceptNotice
    Silently accepts the Important Notice message displayed when the script is launched.

.PARAMETER OutputDir
    ​​​​​​Specify a custom directory where to store the collected files. By default, if this parameter is not specified, the script will store the collected data under "C:\MS_DATA". If the path specified does not exit, the script will attempt to create it.

.PARAMETER UserContext
    Define the user in whose context some of the data (e.g. RDClientAutoTrace, Teams settings) will be collected.

.PARAMETER SkipAutoUpdate
    Skips the automatic update check on launch for the current instance of the script (can be used for both GUI and command line mode).

.PARAMETER LiteMode
    The script will open with a GUI in "Lite Mode" regardless of the Config\MSRDC-Config.cfg settings.

.PARAMETER AssistMode
    The script will read out loud some of the key information and steps performed during data collection/diagnostics.

.OUTPUTS
    By default, all collected data are stored in a subfolder under C:\MS_DATA. You can change this location by using the "-OutputDir" command line parameter.
#>

param ([ValidateSet('isAVD', 'isRDS', 'isW365')][string]$Machine, [ValidateSet('isSource', 'isTarget')][string]$Role,
    [switch]$Core = $false, [switch]$Profiles = $false, [switch]$Activation = $false, [switch]$MSRA = $false, [switch]$SCard = $false, [switch]$IME = $false,
    [switch]$Teams = $false, [switch]$MSIXAA = $false, [switch]$AppAttach = $false, [switch]$HCI = $false, [int]$DumpPID, [switch]$DiagOnly = $false, [switch]$NetTrace = $false,
    [switch]$AcceptEula, [switch]$AcceptNotice = $false, [switch]$SkipAutoUpdate = $false, [switch]$LiteMode = $false, [switch]$AssistMode = $false,
    [ValidateScript({
        if (Test-Path $_ -PathType Container) { $true } else { throw "Invalid folder path. '$_' does not exist or is not a valid folder." }
    })][string]$OutputDir,
    [ValidateScript({
        $profilePath = Join-Path (Split-Path $env:USERPROFILE) $_
        if (Test-Path -Path $profilePath -PathType Container) { $true } else { throw "Invalid username. A local profile folder for user '$_' does not exist or could not be accessed." }
    })][string]$UserContext)

$global:msrdVersion = "240215.10"
$global:msrdDevLevel = "Prod"

$global:msrdScriptpath = $PSScriptRoot
$global:msrdConsoleColor = $host.ui.RawUI.ForegroundColor
$global:msrdVersioncheck = $false
$global:msrdGUI = $false
$global:msrdLiveDiag = $false
$global:msrdProgress = 0


# Store command line parameters for selfupdate restart
if ($PSSenderInfo) { $global:msrdCmdLine = "n/a" } else { $global:msrdCmdLine = $MyInvocation.Line }


# Check if the script is used from TSS
if ($MyInvocation.PSCommandPath -like "*TSS_UEX.psm1") { $global:msrdTSSinUse = $true } else { $global:msrdTSSinUse = $false }


# Limiting scenarios for command line
if (($Role -eq "isSource") -and ($Profiles -or $Activation -or $IME -or $Teams -or $MSIXAA -or $AppAttach -or $HCI)) {
        Write-Warning "Machine role 'isSource' only supports the following scenarios: -Core, -MSRA, -SCard, -DumpPID, -DiagOnly, -NetTrace. Adjust the command line and try again."
        Exit 1
}

if ($MSIXAA) {
    Write-Warning "The command line parameter '-MSIXAA' is deprecated and has been replaced by '-AppAttach'. This time the script will continue using it, but start using '-AppAttach' going forward when troubleshooting issues with either the legacy AVD 'MSIX App Attach' or the new AVD 'App Attach'. The '-MSIXAA' command line parameter will be removed in a future script version."
}


# Check if the current user is an administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    Write-Warning "This script needs to be run as Administrator"
    Exit 1
}


# Check PS Version
$OSVersion = [environment]::OSVersion.Version
If($PSVersionTable.PSVersion.Major -le 4) {
	Write-Warning "MSRD-Collect requires at least PowerShell version 5.1."
	Write-Warning "... running on OS version: $OSVersion with PowerShell version: $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
	Write-Warning "Please update your PowerShell version to version 5.1 or higher!"
    $host.ui.RawUI.ForegroundColor = "Cyan"
	Write-Output "`nSee: https://learn.microsoft.com/en-us/powershell/scripting/windows-powershell/install/installing-windows-powershell?view=powershell-5.1`n`n"
    $host.ui.RawUI.ForegroundColor = $global:msrdConsoleColor
    Exit 1
}


# Check if the 'Modules' folder exists in the script folder
if (-not (Test-Path -Path "$PSScriptRoot\Modules" -PathType Container)) {
    Write-Warning "The 'Modules' folder is missing from the script folder. Please make sure that you have extracted all the files from the ZIP archive and that you launch MSRD-Collect.ps1 from within the same folder that contains the script's 'Modules' subfolder. See MSRD-Collect-ReadMe.txt for more details."
    Exit 1
}


# Check if the script is running in PowerShell ISE
if ($host.Name -eq "Windows PowerShell ISE Host") {
	Write-Warning "Running MSRD-Collect in PowerShell ISE is not supported. Please run it from a regular elevated PowerShell console."
	Exit 1
}


# Check if the included tools are available and valid
if ($global:msrdTSSinUse) {
    $global:msrdToolsFolder = "$global:ScriptFolder\BIN"

    if (Test-Path -Path "$global:msrdToolsFolder\avdnettest.exe") {
        $global:avdnettestpath = "$global:msrdToolsFolder\avdnettest.exe"
    } else {
        $global:avdnettestpath = ""
    }

    if (Test-Path -Path "$global:msrdToolsFolder\procdump.exe") {
        $global:msrdProcDumpExe = "$global:msrdToolsFolder\procdump.exe"
    } else {
        $global:msrdProcDumpExe = ""
    }

    if (Test-Path -Path "$global:msrdToolsFolder\psping.exe") {
        $global:msrdPsPingExe = "$global:msrdToolsFolder\psping.exe"
    } else {
        $global:msrdPsPingExe = ""
    }

} else {
    $global:msrdToolsFolder = "$global:msrdScriptpath\Tools"
    if (Test-Path -Path "$global:msrdToolsFolder\avdnettest.exe") {
        $global:avdnettestpath = "$global:msrdToolsFolder\avdnettest.exe"
    } else {
        $tssToolsFolder = $global:msrdScriptpath -ireplace [regex]::Escape("\scripts\MSRD-Collect"), "\BIN"
        if (Test-Path -Path "$tssToolsFolder\avdnettest.exe") {
            $global:msrdToolsFolder = "$tssToolsFolder\"
            $global:avdnettestpath = "$tssToolsFolder\avdnettest.exe"
        } else {
            $global:avdnettestpath = ""
        }
    }

    $global:msrdToolsFolder = "$global:msrdScriptpath\Tools"
    if (Test-Path -Path "$global:msrdToolsFolder\procdump.exe") {
        $global:msrdProcDumpExe = "$global:msrdToolsFolder\procdump.exe"
    } else {
        $tssToolsFolder = $global:msrdScriptpath -ireplace [regex]::Escape("\scripts\MSRD-Collect"), "\BIN"
        if (Test-Path -Path "$tssToolsFolder\procdump.exe") {
            $global:msrdToolsFolder = "$tssToolsFolder\"
            $global:msrdProcDumpExe = "$tssToolsFolder\procdump.exe"
        } else {
            $global:msrdProcDumpExe = ""
        }
    }

    $global:msrdToolsFolder = "$global:msrdScriptpath\Tools"
    if (Test-Path -Path "$global:msrdToolsFolder\psping.exe") {
        $global:msrdPsPingExe = "$global:msrdToolsFolder\psping.exe"
    } else {
        $tssToolsFolder = $global:msrdScriptpath -ireplace [regex]::Escape("\scripts\MSRD-Collect"), "\BIN"
        if (Test-Path -Path "$tssToolsFolder\psping.exe") {
            $global:msrdToolsFolder = "$tssToolsFolder\"
            $global:msrdPsPingExe = "$tssToolsFolder\psping.exe"
        } else {
            $global:msrdPsPingExe = ""
        }
    }
}

function global:msrdVerifyToolsSignature {
	Param ($filepath)

    try {
	    $signature = Get-AuthenticodeSignature -FilePath $filepath -ErrorAction SilentlyContinue
	    $cert = $signature.SignerCertificate
	    $issuer = $cert.Issuer

	    if ($signature.Status -ne "Valid") {
		    Write-Warning "'$filepath' does not have a valid signature. Stopping script execution. Make sure you download and unpack the full package of MSRD-Collect or TSS only from the official download locations."
		    Exit 1
	    }

	    if (($issuer -ne "CN=Microsoft Code Signing PCA 2011, O=Microsoft Corporation, L=Redmond, S=Washington, C=US") -and ($issuer -ne "CN=Microsoft Windows Production PCA 2011, O=Microsoft Corporation, L=Redmond, S=Washington, C=US") -and ($issuer -ne "CN=Microsoft Code Signing PCA, O=Microsoft Corporation, L=Redmond, S=Washington, C=US") -and ($issuer -ne "CN=Microsoft Code Signing PCA 2010, O=Microsoft Corporation, L=Redmond, S=Washington, C=US") -and ($issuer -ne "CN=Microsoft Development PCA 2014, O=Microsoft Corporation, L=Redmond, S=Washington, C=US")) {
		    Write-Warning "'$filepath' does not have a valid signature. Stopping script execution. Make sure you download and unpack the full package of MSRD-Collect or TSS only from the official download locations."
		    Exit 1
	    }
    } catch {
		Write-Warning "Failed to verify the signature of '$filepath'. Stopping script execution. Make sure you download and unpack the full package of MSRD-Collect or TSS only from the official download locations."
		Exit 1
    }
}

if ($global:avdnettestpath -ne "") { msrdVerifyToolsSignature $global:avdnettestpath }
if ($global:msrdProcDumpExe -ne "") { msrdVerifyToolsSignature $global:msrdProcDumpExe }
if ($global:msrdPsPingExe -ne "") { msrdVerifyToolsSignature $global:msrdPsPingExe }


# Unlock module files if valid
$fileNamesToUnblock = @(
    "MSRDC-Activation.psm1", "MSRDC-Core.psm1", "MSRDC-Diagnostics.psm1", "MSRDC-FwFunctions.psm1", "MSRDC-FwGUI.psm1",
    "MSRDC-FwGUILite.psm1", "MSRDC-FwHtml.psm1", "MSRDC-HCI.psm1", "MSRDC-IME.psm1", "MSRDC-AppAttach.psm1", "MSRDC-MSRA.psm1", "MSRDC-Profiles.psm1",
    "MSRDC-SCard.psm1", "MSRDC-Teams.psm1", "MSRDC-Tracing.psm1", "MSRDC-WU.psm1"
)
Get-ChildItem -Recurse -Path $global:msrdScriptpath\Modules\MSRDC*.psm1 | ForEach-Object {
    if ($_.Name -in $fileNamesToUnblock) {
        Try {
            Unblock-File $_.FullName -Confirm:$false -ErrorAction Stop
        } Catch {
            Write-Warning "Failed to unblock file: $($_.FullName) - $($_.Exception.Message)"
        }
    }
}


# Read config file
$msrdConfigFile = "$global:msrdScriptpath\Config\MSRDC-Config.cfg"
if (Test-Path -Path $msrdConfigFile) {
	try {
		$msrdConfigData = Get-Content $msrdConfigFile | Out-String
        $msrdConfig = ConvertFrom-StringData $msrdConfigData
	} catch {
		Write-Warning "[Error]: Could not read the Config\MSRDC-Config.cfg config file. Please make sure that the file exists and that it is not corrupted. Exiting."
		Exit 1
	}
} else {
	Write-Warning "[Error]: Could not find the Config\MSRDC-Config.cfg config file. Please make sure that the file exists and that it is not corrupted. Exiting."
	Exit 1
}

if ($global:msrdProcDumpExe -eq "") {
    $global:msrdProcDumpVer = "1.0"
} else {
    if ($msrdConfig.ProcDumpVersion -match "\d{2}\.\d{1}$") {
        $global:msrdProcDumpVer = $msrdConfig.ProcDumpVersion
    } else {
		Write-Warning "[Error]: Unsupported value found for 'ProcDumpVersion' in Config\MSRDC-Config.cfg. The value has to be of format XY.Z, where X, Y and Z are numbers (e.g. 11.0). Exiting."
		Exit 1
	}
}

if ($global:msrdPsPingExe -eq "") {
    $global:msrdPsPingVer = "1.0"
} else {
    if ($msrdConfig.PsPingVersion -match "\d{1}\.\d{2}$") {
        $global:msrdPsPingVer = $msrdConfig.PsPingVersion
    } else {
		Write-Warning "[Error]: Unsupported value found for 'PsPingVersion' in Config\MSRDC-Config.cfg. The value has to be of format X.YZ, where X, Y and Z are numbers (e.g. 2.12). Exiting."
		Exit 1
	}
}

if (@(0, 1) -contains $msrdConfig.ShowConsoleWindow) {
    $global:msrdShowConsole = $msrdConfig.ShowConsoleWindow
} else {
    Write-Warning "[Error]: Unsupported value found for 'ShowConsoleWindow' in Config\MSRDC-Config.cfg. Supported values are 0 or 1. Exiting."
	Exit 1
}

if (@(0, 1) -contains $msrdConfig.MaximizeWindow) {
    $global:msrdMaximizeWindow = $msrdConfig.MaximizeWindow
} else {
    Write-Warning "[Error]: Unsupported value found for 'MaximizeWindow' in Config\MSRDC-Config.cfg. Supported values are 0 or 1. Exiting."
	Exit 1
}

if (@("AR","CN","CS","DE","EN","ES","FR","HU","NL","IT","JP","PT","RO","TR") -contains $msrdConfig.UILanguage) {
    $global:msrdLangID = $msrdConfig.UILanguage
} else {
    Write-Warning "[Error]: Unsupported value found for 'UILanguage' in Config\MSRDC-Config.cfg. Supported values are AR, CN, CS, DE, EN, ES, FR, HU, NL, IT, JP, PT, RO or TR. Exiting."
	Exit 1
}

if (@(0, 1) -contains $msrdConfig.PlaySounds) {
    $global:msrdPlaySounds = $msrdConfig.PlaySounds
} else {
	Write-Warning "[Error]: Unsupported value found for 'PlaySounds' in Config\MSRDC-Config.cfg. Supported values are 0 or 1. Exiting."
	Exit 1
}

if ($LiteMode) {
    $msrdGUILite = 1
} else {
    if (@(0, 1) -contains $msrdConfig.UILiteMode) {
        $msrdGUILite = $msrdConfig.UILiteMode
    } else {
        Write-Warning "[Error]: Unsupported value found for 'UILiteMode' in Config\MSRDC-Config.cfg. Supported values are 0 or 1. Exiting."
	    Exit 1
    }
}

if ($AssistMode) {
    $global:msrdAssistMode = 1
} else {
    if (@(0, 1) -contains $msrdConfig.AssistMode) {
        $global:msrdAssistMode = $msrdConfig.AssistMode
    } else {
		Write-Warning "[Error]: Unsupported value found for 'AssistMode' in Config\MSRDC-Config.cfg. Supported values are 0 or 1. Exiting."
	    Exit 1
	}
}


# Initialize localization
$localizationFilePath = Join-Path $global:msrdScriptpath "Config\Localization\MSRDC-Fw$($global:msrdLangID).xml"

if (Test-Path -Path $localizationFilePath) {
	try {
		[xml] $global:msrdLangText = Get-Content -Path $localizationFilePath -Encoding UTF8 -ErrorAction Stop

        # Create a hashtable to store the mappings
        $global:msrdTextHashtable = @{}

        # Populate the hashtable
        foreach ($langNode in $global:msrdLangText.LangV1.lang) {
            $textID = $langNode.id
            $message = $langNode."#text"
            if ($message -like "*&amp;*") {
                $message = $message.replace("&amp;", "&")
            }
            $global:msrdTextHashtable[$textID] = $message
        }
	}
	catch {
		Write-Error "Could not read the Config\Localization\MSRDC-Fw$($global:msrdLangID).xml file: $_. Please make sure that the file exists and that it is not corrupted."
		Exit 1
	}
} else {
	Write-Error "Could not find the Config\Localization\MSRDC-Fw$($global:msrdLangID).xml file. Please make sure that the file exists and that it is not corrupted."
	Exit 1
}


# Set initial output folder
If ($OutputDir) {
    $global:msrdLogRoot = $OutputDir
} else {
    if ($global:msrdTSSinUse) {
        $global:msrdLogRoot = $global:LogFolder
    } else {
        $global:msrdLogRoot = "C:\MS_DATA"
    }
}


# Set user context
if ($UserContext) { $global:msrdUserprof = $UserContext } else { $global:msrdUserprof = $env:USERNAME }

$global:msrdOSVer = (Get-CimInstance Win32_OperatingSystem).Caption
$global:msrdFQDN = [System.Net.Dns]::GetHostByName(($env:computerName)).HostName

$global:msrdCollecting = $False
$global:msrdDiagnosing = $False

[void][System.Reflection.Assembly]::Load('System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
[void][System.Reflection.Assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')


# Init main functions
Import-Module -Name "$PSScriptRoot\Modules\MSRDC-FwFunctions" -DisableNameChecking -Force -Scope Global


# check if the current user is domain admin vs local admin
try {
    if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Domain Admins')) {
        $global:msrdAdminlevel = "Domain Admin" 
    } else { 
        $global:msrdAdminlevel = "Local Admin" 
    }
} catch {
    $global:msrdAdminlevel = "Local Admin"
    $failedCommand = $_.InvocationInfo.Line.TrimStart()
    msrdLogException ("$(msrdGetLocalizedText "errormsg") $failedCommand") -ErrObj $_
}


# Check if auto update check should be performed
if ($SkipAutoUpdate) {
    $global:msrdAutoVerCheck = 0
    Write-Output "SkipAutoUpdate switch specified, automatic update check on script launch will be skipped"
} else {

    if (@(0, 1) -contains $msrdConfig.AutomaticVersionCheck) {
        $global:msrdAutoVerCheck = $msrdConfig.AutomaticVersionCheck
    } else {
		Write-Warning "[Error]: Unsupported value found for 'AutomaticVersionCheck' in Config\MSRDC-Config.cfg. Supported values are 0 or 1. Exiting."
	    Exit 1
	}

    if (@(0, 1) -contains $msrdConfig.ScriptSelfUpdate) {
        $global:msrdScriptSelfUpdate = $msrdConfig.ScriptSelfUpdate
    } else {
        Write-Warning "[Error]: Unsupported value found for 'ScriptSelfUpdate' in Config\MSRDC-Config.cfg. Supported values are 0 or 1. Exiting."
	    Exit 1
    }
}


# EULA
function msrdShowEULAPopup($mode) {
    $EULA = New-Object -TypeName System.Windows.Forms.Form
    $richTextBox1 = New-Object System.Windows.Forms.RichTextBox
    $btnAcknowledge = New-Object System.Windows.Forms.Button
    $btnCancel = New-Object System.Windows.Forms.Button

    $EULA.SuspendLayout()
    $EULA.Name = "EULA"
    $EULA.Text = "Microsoft Diagnostic Tools End User License Agreement"

    $richTextBox1.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $richTextBox1.Location = New-Object System.Drawing.Point(12,12)
    $richTextBox1.Name = "richTextBox1"
    $richTextBox1.ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
    $richTextBox1.Size = New-Object System.Drawing.Size(776, 397)
    $richTextBox1.TabIndex = 0
    $richTextBox1.ReadOnly=$True
    $richTextBox1.Add_LinkClicked({Start-Process -FilePath $_.LinkText})
    $richTextBox1.Rtf = @"
{\rtf1\ansi\ansicpg1252\deff0\nouicompat{\fonttbl{\f0\fswiss\fprq2\fcharset0 Segoe UI;}{\f1\fnil\fcharset0 Calibri;}{\f2\fnil\fcharset0 Microsoft Sans Serif;}}
{\colortbl ;\red0\green0\blue255;}
{\*\generator Riched20 10.0.19041}{\*\mmathPr\mdispDef1\mwrapIndent1440 }\viewkind4\uc1
\pard\widctlpar\f0\fs19\lang1033 MICROSOFT SOFTWARE LICENSE TERMS\par
Microsoft Diagnostic Scripts and Utilities\par
\par
{\pict{\*\picprop}\wmetafile8\picw26\pich26\picwgoal32000\pichgoal15
0100090000035000000000002700000000000400000003010800050000000b0200000000050000
000c0202000200030000001e000400000007010400040000000701040027000000410b2000cc00
010001000000000001000100000000002800000001000000010000000100010000000000000000
000000000000000000000000000000000000000000ffffff00000000ff040000002701ffff0300
00000000
}These license terms are an agreement between you and Microsoft Corporation (or one of its affiliates). IF YOU COMPLY WITH THESE LICENSE TERMS, YOU HAVE THE RIGHTS BELOW. BY USING THE SOFTWARE, YOU ACCEPT THESE TERMS.\par
{\pict{\*\picprop}\wmetafile8\picw26\pich26\picwgoal32000\pichgoal15
0100090000035000000000002700000000000400000003010800050000000b0200000000050000
000c0202000200030000001e000400000007010400040000000701040027000000410b2000cc00
010001000000000001000100000000002800000001000000010000000100010000000000000000
000000000000000000000000000000000000000000ffffff00000000ff040000002701ffff0300
00000000
}\par
\pard
{\pntext\f0 1.\tab}{\*\pn\pnlvlbody\pnf0\pnindent0\pnstart1\pndec{\pntxta.}}
\fi-360\li360 INSTALLATION AND USE RIGHTS. Subject to the terms and restrictions set forth in this license, Microsoft Corporation (\ldblquote Microsoft\rdblquote ) grants you (\ldblquote Customer\rdblquote  or \ldblquote you\rdblquote ) a non-exclusive, non-assignable, fully paid-up license to use and reproduce the script or utility provided under this license (the "Software"), solely for Customer\rquote s internal business purposes, to help Microsoft troubleshoot issues with one or more Microsoft products, provided that such license to the Software does not include any rights to other Microsoft technologies (such as products or services). \ldblquote Use\rdblquote  means to copy, install, execute, access, display, run or otherwise interact with the Software. \par
\pard\widctlpar\par
\pard\widctlpar\li360 You may not sublicense the Software or any use of it through distribution, network access, or otherwise. Microsoft reserves all other rights not expressly granted herein, whether by implication, estoppel or otherwise. You may not reverse engineer, decompile or disassemble the Software, or otherwise attempt to derive the source code for the Software, except and to the extent required by third party licensing terms governing use of certain open source components that may be included in the Software, or remove, minimize, block, or modify any notices of Microsoft or its suppliers in the Software. Neither you nor your representatives may use the Software provided hereunder: (i) in a way prohibited by law, regulation, governmental order or decree; (ii) to violate the rights of others; (iii) to try to gain unauthorized access to or disrupt any service, device, data, account or network; (iv) to distribute spam or malware; (v) in a way that could harm Microsoft\rquote s IT systems or impair anyone else\rquote s use of them; (vi) in any application or situation where use of the Software could lead to the death or serious bodily injury of any person, or to physical or environmental damage; or (vii) to assist, encourage or enable anyone to do any of the above.\par
\par
\pard\widctlpar\fi-360\li360 2.\tab DATA. Customer owns all rights to data that it may elect to share with Microsoft through using the Software. You can learn more about data collection and use in the help documentation and the privacy statement at {{\field{\*\fldinst{HYPERLINK https://aka.ms/privacy }}{\fldrslt{https://aka.ms/privacy\ul0\cf0}}}}\f0\fs19 . Your use of the Software operates as your consent to these practices.\par
\pard\widctlpar\par
\pard\widctlpar\fi-360\li360 3.\tab FEEDBACK. If you give feedback about the Software to Microsoft, you grant to Microsoft, without charge, the right to use, share and commercialize your feedback in any way and for any purpose.\~ You will not provide any feedback that is subject to a license that would require Microsoft to license its software or documentation to third parties due to Microsoft including your feedback in such software or documentation. \par
\pard\widctlpar\par
\pard\widctlpar\fi-360\li360 4.\tab EXPORT RESTRICTIONS. Customer must comply with all domestic and international export laws and regulations that apply to the Software, which include restrictions on destinations, end users, and end use. For further information on export restrictions, visit {{\field{\*\fldinst{HYPERLINK https://aka.ms/exporting }}{\fldrslt{https://aka.ms/exporting\ul0\cf0}}}}\f0\fs19 .\par
\pard\widctlpar\par
\pard\widctlpar\fi-360\li360\qj 5.\tab REPRESENTATIONS AND WARRANTIES. Customer will comply with all applicable laws under this agreement, including in the delivery and use of all data. Customer or a designee agreeing to these terms on behalf of an entity represents and warrants that it (i) has the full power and authority to enter into and perform its obligations under this agreement, (ii) has full power and authority to bind its affiliates or organization to the terms of this agreement, and (iii) will secure the permission of the other party prior to providing any source code in a manner that would subject the other party\rquote s intellectual property to any other license terms or require the other party to distribute source code to any of its technologies.\par
\pard\widctlpar\par
\pard\widctlpar\fi-360\li360\qj 6.\tab DISCLAIMER OF WARRANTY. THE SOFTWARE IS PROVIDED \ldblquote AS IS,\rdblquote  WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL MICROSOFT OR ITS LICENSORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.\par
\pard\widctlpar\qj\par
\pard\widctlpar\fi-360\li360\qj 7.\tab LIMITATION ON AND EXCLUSION OF DAMAGES. IF YOU HAVE ANY BASIS FOR RECOVERING DAMAGES DESPITE THE PRECEDING DISCLAIMER OF WARRANTY, YOU CAN RECOVER FROM MICROSOFT AND ITS SUPPLIERS ONLY DIRECT DAMAGES UP TO U.S. $5.00. YOU CANNOT RECOVER ANY OTHER DAMAGES, INCLUDING CONSEQUENTIAL, LOST PROFITS, SPECIAL, INDIRECT, OR INCIDENTAL DAMAGES. This limitation applies to (i) anything related to the Software, services, content (including code) on third party Internet sites, or third party applications; and (ii) claims for breach of contract, warranty, guarantee, or condition; strict liability, negligence, or other tort; or any other claim; in each case to the extent permitted by applicable law. It also applies even if Microsoft knew or should have known about the possibility of the damages. The above limitation or exclusion may not apply to you because your state, province, or country may not allow the exclusion or limitation of incidental, consequential, or other damages.\par
\pard\widctlpar\par
\pard\widctlpar\fi-360\li360 8.\tab BINDING ARBITRATION AND CLASS ACTION WAIVER. This section applies if you live in (or, if a business, your principal place of business is in) the United States.  If you and Microsoft have a dispute, you and Microsoft agree to try for 60 days to resolve it informally. If you and Microsoft can\rquote t, you and Microsoft agree to binding individual arbitration before the American Arbitration Association under the Federal Arbitration Act (\ldblquote FAA\rdblquote ), and not to sue in court in front of a judge or jury. Instead, a neutral arbitrator will decide. Class action lawsuits, class-wide arbitrations, private attorney-general actions, and any other proceeding where someone acts in a representative capacity are not allowed; nor is combining individual proceedings without the consent of all parties. The complete Arbitration Agreement contains more terms and is at {{\field{\*\fldinst{HYPERLINK https://aka.ms/arb-agreement-4 }}{\fldrslt{https://aka.ms/arb-agreement-4\ul0\cf0}}}}\f0\fs19 . You and Microsoft agree to these terms. \par
\pard\widctlpar\par
\pard\widctlpar\fi-360\li360 9.\tab LAW AND VENUE. If U.S. federal jurisdiction exists, you and Microsoft consent to exclusive jurisdiction and venue in the federal court in King County, Washington for all disputes heard in court (excluding arbitration). If not, you and Microsoft consent to exclusive jurisdiction and venue in the Superior Court of King County, Washington for all disputes heard in court (excluding arbitration).\par
\pard\widctlpar\par
\pard\widctlpar\fi-360\li360 10.\tab ENTIRE AGREEMENT. This agreement, and any other terms Microsoft may provide for supplements, updates, or third-party applications, is the entire agreement for the software.\par
\pard\sa200\sl276\slmult1\f1\fs22\lang9\par
\pard\f2\fs17\lang2057\par
}
"@
    $richTextBox1.BackColor = [System.Drawing.Color]::White
    $btnAcknowledge.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $btnAcknowledge.Location = New-Object System.Drawing.Point(544, 415)
    $btnAcknowledge.Name = "btnAcknowledge";
    $btnAcknowledge.Size = New-Object System.Drawing.Size(119, 23)
    $btnAcknowledge.TabIndex = 1
    $btnAcknowledge.Text = "Accept"
    $btnAcknowledge.UseVisualStyleBackColor = $True
    $btnAcknowledge.Add_Click({$EULA.DialogResult=[System.Windows.Forms.DialogResult]::Yes})

    $btnCancel.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $btnCancel.Location = New-Object System.Drawing.Point(669, 415)
    $btnCancel.Name = "btnCancel"
    $btnCancel.Size = New-Object System.Drawing.Size(119, 23)
    $btnCancel.TabIndex = 2
    if($mode -ne 0)
    {
	    $btnCancel.Text = "Close"
    }
    else
    {
	    $btnCancel.Text = "Decline"
    }
    $btnCancel.UseVisualStyleBackColor = $True
    $btnCancel.Add_Click({$EULA.DialogResult=[System.Windows.Forms.DialogResult]::No})

    $EULA.AutoScaleDimensions = New-Object System.Drawing.SizeF(6.0, 13.0)
    $EULA.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font
    $EULA.ClientSize = New-Object System.Drawing.Size(800, 450)
    $EULA.Controls.Add($btnCancel)
    $EULA.Controls.Add($richTextBox1)
    if($mode -ne 0)
    {
	    $EULA.AcceptButton=$btnCancel
    }
    else
    {
        $EULA.Controls.Add($btnAcknowledge)
	    $EULA.AcceptButton=$btnAcknowledge
        $EULA.CancelButton=$btnCancel
    }
    $EULA.ResumeLayout($false)
    $EULA.Size = New-Object System.Drawing.Size(800, 650)

    Return ($EULA.ShowDialog())
}

function msrdShowEULAIfNeeded($toolName, $mode) {
	$eulaRegPath = "HKCU:Software\Microsoft\CESDiagnosticTools"
	$eulaAccepted = "No"
	$eulaValue = $toolName + " EULA Accepted"
	if(Test-Path $eulaRegPath)
	{
		$eulaRegKey = Get-Item $eulaRegPath
		$eulaAccepted = $eulaRegKey.GetValue($eulaValue, "No")
	}
	else
	{
		$eulaRegKey = New-Item $eulaRegPath
	}
	if($mode -eq 2) # silent accept
	{
		$eulaAccepted = "Yes"
       		$ignore = New-ItemProperty -Path $eulaRegPath -Name $eulaValue -Value $eulaAccepted -PropertyType String -Force
	}
	else
	{
		if($eulaAccepted -eq "No")
		{
			$eulaAccepted = msrdShowEULAPopup($mode)
			if($eulaAccepted -eq [System.Windows.Forms.DialogResult]::Yes)
			{
	        		$eulaAccepted = "Yes"
	        		$ignore = New-ItemProperty -Path $eulaRegPath -Name $eulaValue -Value $eulaAccepted -PropertyType String -Force
			}
		}
	}
	return $eulaAccepted
}

function msrdCleanUpandExit {
    if (($null -ne $global:msrdTempCommandErrorFile) -and (Test-Path -Path $global:msrdTempCommandErrorFile)) {
        Remove-Item -Path $global:msrdTempCommandErrorFile -Force -ErrorAction SilentlyContinue
    }

    if ($global:fQuickEditCodeExist) { [msrdDisableConsoleQuickEdit]::SetQuickEdit($false) | Out-Null }
    if ($global:msrdForm) { $global:msrdForm.Close() }
    Exit
}


# This function disable quick edit mode. If the mode is enabled, console output will hang when key input or strings are selected.
# So disable the quick edit mode during running script and re-enable it after script is finished.
$QuickEditCode=@"
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using System.Runtime.InteropServices;


public static class msrdDisableConsoleQuickEdit
{

    const uint ENABLE_QUICK_EDIT = 0x0040;

    // STD_INPUT_HANDLE (DWORD): -10 is the standard input device.
    const int STD_INPUT_HANDLE = -10;

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll")]
    static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

    [DllImport("kernel32.dll")]
    static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);

    public static bool SetQuickEdit(bool SetEnabled)
    {

        IntPtr consoleHandle = GetStdHandle(STD_INPUT_HANDLE);

        // get current console mode
        uint consoleMode;
        if (!GetConsoleMode(consoleHandle, out consoleMode))
        {
            // ERROR: Unable to get console mode.
            return false;
        }

        // Clear the quick edit bit in the mode flags
        if (SetEnabled)
        {
            consoleMode &= ~ENABLE_QUICK_EDIT;
        }
        else
        {
            consoleMode |= ENABLE_QUICK_EDIT;
        }

        // set the new mode
        if (!SetConsoleMode(consoleHandle, consoleMode))
        {
            // ERROR: Unable to set console mode
            return false;
        }

        return true;
    }
}
"@

Try {
    Add-Type -TypeDefinition $QuickEditCode -Language CSharp -ErrorAction Stop | Out-Null
    $global:fQuickEditCodeExist = $True
} Catch {
    $global:fQuickEditCodeExist = $False
}


#region ##### MAIN #####

[System.Windows.Forms.Application]::EnableVisualStyles()

# Disabling quick edit mode as somethimes this causes the script stop working until enter key is pressed.
If ($global:fQuickEditCodeExist) { [msrdDisableConsoleQuickEdit]::SetQuickEdit($True) | Out-Null }

$notice = "========= Microsoft CSS Diagnostics Script =========`n
This Data Collection is for troubleshooting reported issues for the given scenarios.
Once you have started this script please wait until all data has been collected.`n`n
============= IMPORTANT NOTICE =============`n
This script is designed to collect information that will help Microsoft Customer Support Services (CSS) troubleshoot an issue you may be experiencing with Microsoft Remote Desktop solutions.`n
The collected data may contain Personally Identifiable Information (PII) and/or sensitive data, such as (but not limited to) IP addresses; PC names; and user names.`n
The script will save the collected data in a folder (default C:\MS_DATA) and also compress the results into a ZIP file.
This folder and its contents or the ZIP file are not automatically sent to Microsoft.`n
You can send the ZIP file to Microsoft CSS using a secure file transfer tool - Please discuss this with your support professional and also any concerns you may have.`n
Find our privacy statement at: https://privacy.microsoft.com/en-US/privacystatement`n
"

if (!($global:msrdTSSinUse)) {
    if ($AcceptEula) {
        Write-Output "$(msrdGetLocalizedText "eulaSilentOK")"
        $eulaAccepted = msrdShowEULAIfNeeded "MSRD-Collect" 2
    } else {
        $eulaAccepted = msrdShowEULAIfNeeded "MSRD-Collect" 0
        if ($eulaAccepted -ne "Yes") {
            Write-Output "$(msrdGetLocalizedText "eulaNotOK")"
            msrdCleanUpandExit
        }
        Write-Output "$(msrdGetLocalizedText "eulaOK")"
    }

    if ($AcceptNotice) {
        Write-Output "$(msrdGetLocalizedText "noticeSilentOK")`n"
    } else {
        $wshell = New-Object -ComObject Wscript.Shell
        $answer = $wshell.Popup("$notice",0,"Are you sure you want to continue?",4+32)
        if ($answer -eq 7) {
            Write-Warning "$(msrdGetLocalizedText "notApproved")`n"
            msrdCleanUpandExit
        }
        Write-Output "$(msrdGetLocalizedText "noticeOK")`n"
    }
}

if ($Core -or $Profiles -or $Activation -or $MSIXAA -or $AppAttach -or $MSRA -or $IME -or $HCI -or $Teams -or $SCard -or $DiagOnly -or $NetTrace -or $DumpPID) {
    if ($Machine) {
        if ($Role) {
            switch($Machine) {
                'isRDS' { $global:msrdRDS = $true; $global:msrdAVD = $false; $global:msrdW365 = $false }
                'isAVD' { $global:msrdRDS = $false; $global:msrdAVD = $true; $global:msrdW365 = $false }
                'isW365' { $global:msrdRDS = $false; $global:msrdAVD = $false; $global:msrdW365 = $true }
            }

            switch($Role) {
                'isSource' { $global:msrdSource = $true; $global:msrdTarget = $false }
                'isTarget' { $global:msrdSource = $false; $global:msrdTarget = $true }
            }

            msrdInitFolders

            if ($global:avdnettestpath -eq "") {
                msrdLogMessage $LogLevel.Warning "$(msrdGetLocalizedText 'avdnettestNotFound')`n"
            }

            if (!($global:msrdTSSinUse)) {
                if ($global:msrdDevLevel -eq "Insider") {
                    msrdLogMessage $LogLevel.Info "$(msrdGetLocalizedText "starting") - v$msrdVersion (INSIDER Build - For Testing Purposes Only !)`n" -Color "Cyan"
                } else {
                    msrdLogMessage $LogLevel.Info "$(msrdGetLocalizedText "starting") - v$msrdVersion`n" -Color "Cyan"
                }

                if ($global:msrdAutoVerCheck -eq 1) {
                    if ($global:msrdScriptSelfUpdate -eq 1) {
                        msrdCheckVersion ($msrdVersion) -selfUpdate
                    } else {
                        msrdCheckVersion ($msrdVersion)
                    }
                } else {
                    msrdLogMessage $LogLevel.Normal "INFO: Automatic update check on script launch is Disabled"
                }
            }

            if ($UserContext) { msrdLogMessage $LogLevel.Info "INFO: UserContext switch has been specified with value: $UserContext`n" }

            if ($PSSenderInfo) {
                msrdLogMessage $LogLevel.Info "INFO: The script is running in a remote PowerShell session" -Color "Yellow"
                msrdLogMessage $LogLevel.Info "INFO: ConnectedUser: $($PSSenderInfo.ConnectedUser)" -Color "Yellow"
                msrdLogMessage $LogLevel.Info "INFO: RunAsUser: $($PSSenderInfo.RunAsUser)" -Color "Yellow"
            }

            if ($global:msrdTSSinUse) { msrdInitScript -isTSS Yes } else { msrdInitScript }

            $varsNO = @(,$false * 1)

            msrdInitScenarioVars
            $dumpProc = $false
            $pidProc = ""
            $global:onlyDiag = $false

            $vCore = @(,$true * 12)

            if ($Profiles) { $vProfiles = @(,$true * 4) }
            if ($Activation) { $vActivation = @(,$true * 3) }
            if ($MSRA) { $vMSRA = @(,$true * 6) }
            if ($SCard) { $vSCard = @(,$true * 3) }
            if ($IME) { $vIME = @(,$true * 2) }
            if ($Teams) { $vTeams = @(,$true * 3) }
            if ($MSIXAA) { $vMSIXAA = @(,$true * 1) }
            if ($AppAttach) { $vMSIXAA = @(,$true * 1) }
            if ($HCI) { $vHCI = @(,$true * 1) }
            if ($DumpPID) { $pidProc = $DumpPID; $dumpProc = $true }
            if ($DiagOnly) {
                $vCore = $varsNO; $global:onlyDiag = $true;
                if ($Core -or $Profiles -or $Activation -or $MSIXAA -or $AppAttach -or $MSRA -or $IME -or $HCI -or $Teams -or $SCard -or $NetTrace -or $DumpPID) {
                    msrdLogMessage $LogLevel.Warning "Scenario 'DiagOnly' has been specified together with other scenarios. All scenarios will be ignored and only Diagnostics will run.`n"
                }
            }

            if (-not $DiagOnly) {

                if (($true -in $vCore) -and (-not $global:msrdRDS)) { msrdCloseMSRDC }

                #data collection
                $parameters = @{
                    varsCore = $vCore
                    varsProfiles = $vProfiles
                    varsActivation = $vActivation
                    varsMSRA = $vMSRA
                    varsSCard = $vSCard
                    varsIME = $vIME
                    varsTeams = $vTeams
                    varsMSIXAA = $vMSIXAA
                    varsHCI = $vHCI
                    traceNet = $NetTrace
                    dumpProc = $dumpProc
                    pidProc = $pidProc
                }
                msrdCollectData @parameters

            }

            $varsSystem = @(,$true * 11)
            $varsAVDRDS = @(,$true * 11)
            $varsInfra = @(,$true * 8)
            $varsAD = @(,$true * 2)
            $varsNET = @(,$true * 8)
            $varsLogSec = @(,$true * 2)
            $varsIssues = @(,$true * 2)
            $varsOther = @(,$true * 4)

            #diagnostics
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
            msrdCollectDataDiag @parameters

            msrdArchiveData -varsCore $vCore

        } else {
            Write-Warning "Please include the '-Role' parameter to indicate the role of the machine in the selected remote desktop solution, or run the script without any parameters (= GUI mode).`nSupported values for the '-Role' parameter: 'isSource', 'isTarget'.`nSee MSRD-Collect-ReadMe.txt for more details.`nExiting..."
            Exit
        }
    } else {
        Write-Warning "Please include the '-Machine' parameter to indicate the type of environment from where data should be collected, or run the script without any parameters (= GUI mode).`nSupported values for the '-Machine' parameter: 'isAVD', 'isRDS', 'isW365'.`nSee MSRD-Collect-ReadMe.txt for more details.`nExiting..."
        Exit
    }

} else {
    if (-not $global:msrdTSSinUse) {

$code = @"
using System;
using System.Runtime.InteropServices;

namespace System
{
    public class IconExtractor
    {
        public static System.Drawing.Icon Extract(string file, int number, bool largeIcon)
        {
            IntPtr large;
            IntPtr small;
            ExtractIconEx(file, number, out large, out small, 1);
            try
            {
                // Create a copy of the icon to avoid handle ownership issues
                var extractedIcon = (System.Drawing.Icon)System.Drawing.Icon.FromHandle(largeIcon ? large : small).Clone();

                // Release the handles obtained from ExtractIconEx
                DestroyIcon(large);
                DestroyIcon(small);

                return extractedIcon;
            }
            catch
            {
                return null;
            }
        }

        [DllImport("Shell32.dll", EntryPoint = "ExtractIconExW", CharSet = CharSet.Unicode, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
        private static extern int ExtractIconEx(string sFile, int iIndex, out IntPtr piLargeVersion, out IntPtr piSmallVersion, int amountIcons);

        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        private static extern bool DestroyIcon(IntPtr handle);
    }
}
"@

        if ($PSVersionTable.PSVersion.Major -eq 5) {
            Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing
        } else {
            Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing.Common,System.Drawing
        }

        Add-Type -AssemblyName System.Windows.Forms

        $global:msrdRDS = $false; $global:msrdAVD = $false; $global:msrdW365 = $false
        $global:msrdSource = $false; $global:msrdTarget = $false


#Load dlls into context of the current console session
 Add-Type -Name Window -Namespace Console -MemberDefinition '
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'

        if ($msrdGUILite -eq 1) {
            Import-Module -Name "$PSScriptRoot\Modules\MSRDC-FwGUILite" -DisableNameChecking -Force
            msrdAVDCollectGUILite
        } else {
            Import-Module -Name "$PSScriptRoot\Modules\MSRDC-FwGUI" -DisableNameChecking -Force
            msrdAVDCollectGUI
        }
    }
}
#endregion ##### MAIN #####
# SIG # Begin signature block
# MIInvwYJKoZIhvcNAQcCoIInsDCCJ6wCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCiwNar9qEWeTNb
# 8U/ywf3OxDFDsjBuBw/bvTfbD+xl9KCCDXYwggX0MIID3KADAgECAhMzAAADrzBA
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
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIOS6c6/43o+gNMZXfkvuuYXB
# IU0ptKssfCjEwCTEzlVZMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAZNiAdKEvY+K6Ftj80anJ+QeuwnBQis3iQj7Vyf+WOHWumclyPd19dTXJ
# rdLlN0K0yUzu8h361aoVDQysa9E27RFP9ct0eaLN6GD+a2FhTWjDnbhsPfu+Xm09
# Cbs1W8cPQN+gODE0HG7WdJf4wWKvhVd7/kR3tKZ5YyBCUF8NbarZ36TWg2zeCcMV
# fVxVnfKljrJT8x2UclHL4MTFqgHHYRj9Ug/4K4wYngL+RflrOaIb+QGRueeLnDFY
# U5FOBUpf57vyZe9dm8KajJ/pdpuImk291O0rgk2KGw2S1N50TiHe1ij6PVzkbz4E
# ansJ/yjHT/KnNrTugRrJS071VBPFwKGCFykwghclBgorBgEEAYI3AwMBMYIXFTCC
# FxEGCSqGSIb3DQEHAqCCFwIwghb+AgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFZBgsq
# hkiG9w0BCRABBKCCAUgEggFEMIIBQAIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCAyQNbKF7z3z7qds3BTXefMlqS4khnnX7SyUC1qMdYW1AIGZbqlXieu
# GBMyMDI0MDIyMDEyMTY1OS4zMjRaMASAAgH0oIHYpIHVMIHSMQswCQYDVQQGEwJV
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
# IgQgzMgKNMvuYTfNcSkqEgZiEhrN/oSisLlBO6a9wlb350AwgfoGCyqGSIb3DQEJ
# EAIvMYHqMIHnMIHkMIG9BCBTpxeKatlEP4y8qZzjuWL0Ou0IqxELDhX2TLylxIIN
# NzCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# JjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB3MHg
# jMJfWF6OAAEAAAHcMCIEIMq+2CFXJYA28rws+5gL9LlWmreOOAJUqesR6p1SI0xw
# MA0GCSqGSIb3DQEBCwUABIICAH1NoI8G9I6vWdFAOXgT2AFDM1ZNe8nsILWxieDZ
# jBFSUZUh48oE5PCsFGnqqn+NjIAR0jtVF8+Cq3LLHlr24jriERSEtNDjRNwCzrd9
# YK9fPfjGeerjkkM9cRidUAMcFzNJPu0q4BcBllxvZFASY7AQMujCh5szhMFC2ReQ
# ZnbWwmyQoFESvzKu6i2pBllxLo5JT4v1iYKYJMspSdWqLiZSGl/FXbOE8Xpxy/UL
# Cm8F50vj5yeVUWTJB9trgFa2obSiCS5Odwh6PDRq9vnZ6HC4bhIfu6nx5Q+XuuuC
# 7leeuP68esPr2JOPnWiO6hvrVovdHXkxaPiYbT48U4xgyFHz0XUVeeL1iyyyWRLy
# Ve/oOY10fG2Pj+nfntvX+NbVv4XUAUuhs7bbOqNYEyBL0TPRBTUcrSJn0poXoAdE
# 3VoJKhog9GfaXfM9gu12Hhlc6zt2VLjQhYByl4N35SF938/t3cd41mSZs4XW9Smm
# ajT8sZuMiS98ojshJ/FsUC+p+m2nb3iUQjSvUcxrhe+ttlr3W5AXRAdnv7y7yv05
# hP04ytKKDatxJ8zhwm1EbKRckZ0694X03dAz6SEZ3VwXmZ1ZbnyftkUAj77A/jsU
# WoYphdir6Idk8zTtH/ibMK0TL+F2d/Jd4vjLbppZ/8a5V7FxZwruBap4L+X1IF4G
# F05p
# SIG # End signature block
