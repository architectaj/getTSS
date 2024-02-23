<#
.SYNOPSIS
Detects known issues and helps resolve them.

.DESCRIPTION
xray aims to automate detection of known issues and help resolve them with minimal time and effort.
It consists of multiple diagnostic functions each looking for a known issue.

.PARAMETER Area
Which technology area xray should run diagnostics for. 
Specify either Area or Component to check or Diagnostic to run (they are mutually exclusive), multiple items can be specified (comma-separated).
When area(s) specified, all components within the specified area(s) are checked
"-Area all" or "-Area *" checks all areas

.PARAMETER Conponent
Which conponent xray should run diagnostics for. 
Specify either Area or Component to check or Diagnostic to run (they are mutually exclusive), multiple items can be specified (comma-separated).
When component(s) specified, all diagnostics within the specified component(s) are run
No wildcards allowed, to run diagnostics for all components, use -Area parameter instead.

.PARAMETER Diagnostic
Which conponent xray should run diagnostics for. 
Specify either Area or Component to check or Diagnostic to run (they are mutually exclusive), multiple items can be specified (comma-separated).
When diagnostic(s) specified, only the specified diagnostics are run
No wildcards allowed, to run all diagnostics, consider using -Area or -Component parameter instead.

.PARAMETER DataPath
Path for input/output files

.PARAMETER Offline
Indicates xray is not running on the actual machine being examined (some -not all- diagnostics can use data files to search for issues)

.PARAMETER WaitBeforeClose
If any known issues are detected, pauses just before script terminates/window closes
Used to ensure detected issues shown on screen are not missed (they are always saved to report file)

.PARAMETER SkipDiags
Do not run diagnostics, only do the minimum essential work, like checking Windows update status etc.
Use carefully, any known issues present will go undetected when this switch is specified.

.PARAMETER DevMode
For diagnostic developers, to be used only whilst developing a diagnostic function. 
When specified, error messages for diagnostics are not suppressed.

.PARAMETER AcceptEULA
Do not display EULA at start

.EXAMPLE
PS> xray.ps1 -Component dhcpsrv,dnssrv -DataPath c:\xray -WaitBeforeClose

This command runs all diagnostics for both dhcpsrv and dnssrv components, saves results to specified path c:\xray and waits for user before terminating if any issues found.

.EXAMPLE
PS> .\xray.ps1 -Area * -DataPath c:\MS_DATA

This command runs all diagnostics for all components in all technology areas and saves results to data path specified.
#>

Param(
    [Parameter(Mandatory=$false,
    ParameterSetName="Areas")]
    [ValidateSet("All", "*", "ADS", "DND", "NET", "PRF", "SHA", "UEX")]
    [String[]]
    $Area,

    [Parameter(Mandatory=$true,
    ParameterSetName="Components")]
    [String[]]
    $Component,

    [Parameter(Mandatory=$true,
    ParameterSetName="Diagnostics")]
    [String[]]
    $Diagnostic,

    [Parameter(Mandatory=$false,
    ParameterSetName="Areas")]
    [Parameter(Mandatory=$false,
    ParameterSetName="Components")]
    [Parameter(Mandatory=$false,
    ParameterSetName="Diagnostics")]
    [String]
    $DataPath,

    [Parameter(Mandatory=$false,
    ParameterSetName="Areas")]
    [Parameter(Mandatory=$false,
    ParameterSetName="Components")]
    [Parameter(Mandatory=$false,
    ParameterSetName="Diagnostics")]
    [switch]
    $Offline,

    [Parameter(Mandatory=$false,
    ParameterSetName="Areas")]
    [Parameter(Mandatory=$false,
    ParameterSetName="Components")]
    [Parameter(Mandatory=$false,
    ParameterSetName="Diagnostics")]
    [switch]
    $WaitBeforeClose,

    [Parameter(Mandatory=$false,
    ParameterSetName="Areas")]
    [Parameter(Mandatory=$false,
    ParameterSetName="Components")]
    [Parameter(Mandatory=$false,
    ParameterSetName="Diagnostics")]
    [switch]
    $SkipDiags,

    [Parameter(Mandatory=$false,
    ParameterSetName="Areas")]
    [Parameter(Mandatory=$false,
    ParameterSetName="Components")]
    [Parameter(Mandatory=$false,
    ParameterSetName="Diagnostics")]
    [switch]
    $DevMode,

    [Parameter(Mandatory=$false,
    ParameterSetName="Areas")]
    [Parameter(Mandatory=$false,
    ParameterSetName="Components")]
    [Parameter(Mandatory=$false,
    ParameterSetName="Diagnostics")]
    [switch]
    $AcceptEULA
)

Import-Module -Name .\xray_WU.psm1 -Force
Import-Module -Name .\diag_api.psm1 -Force

Import-Module -Name .\diag_ads.psm1 -Force
Import-Module -Name .\diag_dnd.psm1 -Force
Import-Module -Name .\diag_net.psm1 -Force
Import-Module -Name .\diag_prf.psm1 -Force
Import-Module -Name .\diag_sha.psm1 -Force
Import-Module -Name .\diag_uex.psm1 -Force

# used for diagnostic development only
if ($DevMode) {
    Import-Module -Name .\diag_test.psm1 -Force
}

# version
$version = "1.0.240214.0"

# Area and Area/Component arrays
$TechAreas = @("ADS", "DND", "NET", "PRF", "SHA", "UEX")
#endregion globals

#region helpers

# Processes provided area(s) with all its components & checks
function RunDiagForArea($areas)
{
    foreach ($area in $areas) {
        LogWrite "Processing area:$area"

        try {
            $components = (Get-Variable -Name $area -ErrorVariable ErrorMsg -ErrorAction SilentlyContinue).Value
        }
        catch {
            LogWrite $Error[0].Exception
        }

        if($ErrorMsg) {
            LogWrite $ErrorMsg
        }
        else {
            RunDiagForComponent $components
        }
    }
}

# Processes provided components and runs corresponding diags
function RunDiagForComponent($components)
{
    if($components.Count -eq 0){
        LogWrite "No components!"
        return
    }

    foreach ($component in $components) {
        LogWrite "Processing component: $component"

        try {
            $diags = (Get-Variable -Name $component -ErrorVariable ErrorMsg -ErrorAction SilentlyContinue).Value
        }
        catch {
            LogWrite $Error[0].Exception
        }

        if($ErrorMsg) {
            LogWrite $ErrorMsg
        }
        else {
            RunDiag $diags
        }
    }
}

# Runs specified diagnostics
function RunDiag($diagnostics)
{
    if($diagnostics.Count -eq 0){
        LogWrite "No diagnostics!"
        return
    }

    foreach ($diag in $diagnostics) {
        if($executedDiags.Contains($diag)) {
            LogWrite "Skipping duplicate instance: $diag"
            continue
        }
        $Global:currDiagFn = $diag
        $executedDiags.Add($diag)
        LogWrite "Running diagnostic: $diag"
        XmlAddDiagnostic $diag
        Write-Host "." -NoNewline
        $time1 = (Get-Date).ToUniversalTime()

        $Global:numDiagsRun++
        if ($DevMode) {
            # no error/exception protection
            $result = & $diag $Offline
        }
        else {
            # to prevent failure messages from diag functions
            $ErrorActionPreference = "Stop"
            try {
                $result = & $diag $Offline
            }
            catch {
                $result = $RETURNCODE_EXCEPTION
                LogWrite $Error[0].Exception.Message
            }
            # revert to normal error handling 
            $ErrorActionPreference = "Continue"
        }

        LogWrite "$diag returned: $result"
        $time2 = (Get-Date).ToUniversalTime()
        [UInt64] $timeTaken = ($time2 - $time1).TotalMilliseconds
        XmlDiagnosticComplete $diag $result $timeTaken

        if($result -eq $RETURNCODE_SUCCESS){
            $Global:numDiagsSuccess++
        }
        elseif($result -eq $RETURNCODE_SKIPPED){
            $Global:numDiagsSkipped++
        }
        else {
            $Global:numDiagsFailed++
        }
        $Global:currDiagFn = $null
    }
}

# 'Translates' TSS scenarios to xray components 
function ValidateTssComponents
{
    param(
        [Parameter(Mandatory=$true)]
        [String[]]
        $TssComponents
    )

    $tssComps  = @("802Dot1x", "WLAN",     "Auth", "BITS", "BranchCache", "Container", "CSC", "DAcli", "DAsrv", "DFScli", "DFSsrv", "DHCPcli", "DhcpSrv", "DNScli", "DNSsrv", "Firewall", "General", "HypHost", "HypVM", "IIS", "IPAM", "MsCluster", "MBAM", "MBN", "Miracast", "NCSI", "NetIO", "NFScli", "NFSsrv", "NLB", "NPS", "Proxy", "RAS", "RDMA", "RDScli", "RDSsrv", "SDN", "SdnNC", "SQLtrace", "SBSL", "UNChard", "VPN", "WFP", "Winsock", "WIP", "WNV", "Workfolders")
    $xrayComps = @("802Dot1x", "802Dot1x", "Auth", "BITS", "BranchCache", "Container", "CSC", "DAcli", "DAsrv", "DFScli", "DFSsrv", "DHCPcli", "DhcpSrv", "DNScli", "DNSsrv", "Firewall", "General", "HypHost", "HypVM", "IIS", "IPAM", "MsCluster", "MBAM", "MBN", "Miracast", "NCSI", "NetIO", "NFScli", "NFSsrv", "NLB", "NPS", "Proxy", "RAS", "RDMA", "RDScli", "RDSsrv", "SDN", "SdnNC", "SQLtrace", "SBSL", "UNChard", "VPN", "WFP", "Winsock", "WIP", "WNV", "Workfolders")

    for ($i = 0; $i -lt $tssComps.Count; $i++) {
        $tssComps[$i] = $tssComps[$i].ToLower()
        $xrayComps[$i] = $xrayComps[$i].ToLower()
    }
    for ($i = 0; $i -lt $TssComponents.Count; $i++) {
        $TssComponents[$i] = $TssComponents[$i].ToLower()
    }
    [System.Collections.Generic.List[String]] $newComps = $TssComponents

    for ($i = 0; $i -lt $TssComponents.Count; $i++) {
        $index = -1
        for ($j = 0; $j -lt $tssComps.Count; $j++) {
            if ($tssComps[$j] -eq $TssComponents[$i]) {
                $index = $j
                break
            }
        }
        if($index -lt 0) {
            continue
        }
        if($TssComponents[$i] -ne $xrayComps[$index]) {
            # remove
            $newComps.RemoveAt($i)
            if(!$newComps.Contains($xrayComps[$index])) {
                # replace
                $newComps.Insert($i, $xrayComps[$index])
            }
        }
    }
    return [String[]] $newComps
}

# Displays help/usage info
function ShowHelp
{
    "
No parameters specified, nothing do. 

For usage info, run:
    Get-Help .\xray.ps1

List of available diagnostic areas/components to scan for issues:

Area (version):  `tComponents:
=================`t==========="

    foreach ($techarea in $TechAreas) {
        $version_name = $techarea + "_version"
        $techarea_version = (Get-Variable -Name $version_name).Value
        $components = (Get-Variable -Name $techarea).Value
        "$techarea ($techarea_version)`t$components"
    }
    ""
}
#endregion helpers

#region EULA
[void][System.Reflection.Assembly]::Load('System.Drawing, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a')
[void][System.Reflection.Assembly]::Load('System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089')

function ShowEULAPopup($mode)
{
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

function ShowEULAIfNeeded($toolName, $mode)
{
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
			$eulaAccepted = ShowEULAPopup($mode)
			if($eulaAccepted -eq [System.Windows.Forms.DialogResult]::Yes)
			{
	        		$eulaAccepted = "Yes"
	        		$ignore = New-ItemProperty -Path $eulaRegPath -Name $eulaValue -Value $eulaAccepted -PropertyType String -Force
			}
		}
	}
	return $eulaAccepted
}
#endregion EULA

#region main
# main script

Write-Host "xray by tdimli, v$version"

# validate cmdline
if (($Area -eq $null) -and ($Component -eq $null) -and ($Diagnostic -eq $null) -and ($SkipDiags -eq $false)) {
    ShowHelp
    return
}

# EULA
if ($AcceptEULA -eq $false) {
    $eulaAccepted = ShowEULAIfNeeded "xray" 0
    if($eulaAccepted -ne "Yes") {
        "EULA Declined"
        exit
    }
}

# validate DataPath, do it here before any file operations
$origDataPath = $DataPath
if(($DataPath.Length -eq 0) -or -not(Test-Path -Path $DataPath)) {
    $DataPath = (Get-Location).Path
}
else {
    $DataPath = Convert-Path $DataPath
}

InitGlobals $version $DataPath

LogWrite "xray by tdimli, v$version"

Write-Host "`r`nInitialising..."
foreach ($techarea in $TechAreas) {
    $version_name = $techarea + "_version"
    $techarea_version = (Get-Variable -Name $version_name).Value
    LogWrite " $techarea $techarea_version"
    XmlAddTechArea $techarea $techarea_version
}

# these splits are needed for TSS interoperability
if ($Area -ne $null) {
    $Area = $Area -split ","
    if (($Area -eq "all") -or ($Area -eq "*")) {
        $Area = $TechAreas
    }
}
if ($Component -ne $null) {
    $Component = $Component -split ","
    for ($i = 0; $i -lt $Component.Count; $i++) {
        $Component[$i] = $Component[$i].Replace(' ', '')
    }
}
if ($Diagnostic -ne $null) {
    $Diagnostic = $Diagnostic -split ","
}

# log parameters
LogWrite "Parameters:"
LogWrite " Area(s): $Area"
LogWrite " Component(s): $Component"
if(($Component -ne $null) -and ($Component.Count -gt 0)) {
    $ConvertedComponent = ValidateTssComponents $Component
    LogWrite "  after conversion: $ConvertedComponent"
    $Component = $ConvertedComponent
}
# handle "-component general"
for ($i = 0; $i -lt $Component.Count; $i++) {
    $Component[$i] = $Component[$i].Replace(' ', '')
    if ($Component[$i].ToLower() -eq "general") {
        $Area = $TechAreas
        $Components = $null
        LogWrite "  general specified, running with -Area All instead"
    }
}
LogWrite " Diagnostic(s): $Diagnostic"
LogWrite " Datapath: $DataPath"
if (!$DataPath.Equals($origDataPath)) {
    LogWrite "  Original Datapath: $origDataPath"
}
LogWrite " Offline: $Offline"
LogWrite " WaitBeforeClose: $WaitBeforeClose"
LogWrite " SkipDiags: $SkipDiags"
LogWrite " DevMode: $DevMode"
XmlAddParameters $Area $Component $Diagnostic $Offline $WaitBeforeClose $SkipDiags $DevMode

LogWrite "Log file: $logFile"
LogWrite "XML report: $xmlRptFile"

# collect basic system info
LogWrite "Collecting system info..."
AddSysInfo $Offline

# collect poolmon info
LogWrite "Collecting poolmon info..."
InitPoolmonData $Offline

# diagnostics
[System.Collections.Generic.List[String]] $executedDiags = New-Object "System.Collections.Generic.List[string]"

# check for Windows updates
$updateListsLastUpdatedDate = [datetime]::ParseExact($updateListsLastUpdated, "yyyyMMdd", $null)
Write-Host "Checking Windows Update status using update data v$updateListsLastUpdated "
LogWrite "Checking Windows Update status using update data v$updateListsLastUpdated"
$updateListsGracePeriod = 14 # days
if ((New-TimeSpan -Start $updateListsLastUpdatedDate -End $xrayStartTime).Days -gt $updateListsGracePeriod) {
    Write-Host "The update data is more than $updateListsGracePeriod days old, update status report may not be accurate." -ForegroundColor yellow
    LogWrite "The update data is more than $updateListsGracePeriod days old, update status report may not be accurate."
}
Write-Host "Looking for missing updates... " -NoNewline
LogWrite "Looking for missing updates..."
RunDiag CheckUpdateStatus
Write-Host ""
if ($NumMissingUpdates -eq 0) {
    Write-Host "System up-to-date (last installed update: $($installedUpdates[0].HotfixId))`r`n"
    LogWrite "System up-to-date (last installed update: $($installedUpdates[0].HotfixId))"
}
elseif ($NumMissingUpdates -lt 0) {
    Write-Host "Update status cannot be determined, please check that you have latest updates installed.`r`n" -ForegroundColor yellow
    LogWrite "Update status cannot be determined, please check that you have latest updates installed."
}
elseif ($numIssues -eq 0) {
    Write-Host "This system is missing $NumMissingUpdates update(s), please install below Windows update to resolve:" -ForegroundColor yellow
    Write-Host "  $($MissingUpdates[0].heading)`r`n"
    LogWrite "This system is missing $NumMissingUpdates update(s), please install Windows update $($MissingUpdates[0].id) to resolve."
}

if ($SkipDiags) {
    LogWrite "Diagnostics skipped on user request"
}
else {
    # run diagnostics
    Write-Host "Starting diagnostics, checking for known issues..."
    LogWrite "Starting diagnostics, checking for known issues..."
    if ($Area) {
        RunDiagForArea $Area
    } elseif ($Component) {
        RunDiagForComponent $Component
    } elseif ($Diagnostic) {
        RunDiag $Diagnostic
    }
}

XmlMarkComplete

# log/show summary
$stats1 = "$numDiagsRun diagnostic check(s) run (R:$numDiagsSuccess S:$numDiagsSkipped F:$numDiagsFailed)"
$stats2 = "$numIssues issue(s) found"
if(Test-Path -Path $issuesFile){
    $stats2 += ", details saved to $issuesFile"
}
elseif(Test-Path -Path $infoFile) {
    $stats2 += ", details saved to $infoFile"
}

LogWrite $stats1
LogWrite $stats2
LogWrite "Diagnostics completed."

Write-Host
Write-Host $stats1
Write-Host $stats2
Write-Host "Diagnostics completed.`r`n"

if($WaitBeforeClose -and $issueShown) {
    # wait for user
    pause
}
#endregion main

# SIG # Begin signature block
# MIIoKgYJKoZIhvcNAQcCoIIoGzCCKBcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBE0xG19dKosnf/
# EfF62y9RRQT68MutoBxNzqg/BhaL26CCDXYwggX0MIID3KADAgECAhMzAAADrzBA
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
# /Xmfwb1tbWrJUnMTDXpQzTGCGgowghoGAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBIDIwMTECEzMAAAOvMEAOTKNNBUEAAAAAA68wDQYJYIZIAWUDBAIB
# BQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIIdkJ70e2PJyQZxHmI0jqGGV
# gULTbacYkME+H+quIQ+tMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAoNOX7nz2M5Amu+Xxn4ddAx+uSUD0nOmGLu68Vz6Og2WMXHwqMHpLDQ7f
# thp7G3LcH9qO9r6YdBlzd1ihi6afqw5aZKMIeJnbsEL5bs6vULcrO7sWsaBKorRI
# +xeDP3y8fpsfO510pYFNGy2iGPgDzhUnd1pTG8Tu5FYAEaHhBRCPtI18KQ66p/aL
# CJ74OqjXkoOq90NmAvvxungfVXtU62jhSVVB0rCOpGR4TJrZLqkinOqVWFYKt7cD
# 2e5MJs/e8oisiuYigtWo8HMdR7lCqSZ5DDL7s84w8M9nYVNuGsdJIcjEJI3aMHr/
# ilANA2P/uwpGRdkm6vu3BJJl9whWYaGCF5QwgheQBgorBgEEAYI3AwMBMYIXgDCC
# F3wGCSqGSIb3DQEHAqCCF20wghdpAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsq
# hkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCD+5SNTgt38nCTs0GxEh5rkUP8/nF8eY6rtNzrjgXc0LgIGZc4U80IR
# GBMyMDI0MDIyMDEyMTU1Mi40NzhaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046ODYwMy0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wg
# ghHqMIIHIDCCBQigAwIBAgITMwAAAfGzRfUn6MAW1gABAAAB8TANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yMzEyMDYxODQ1
# NTVaFw0yNTAzMDUxODQ1NTVaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25z
# MScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046ODYwMy0wNUUwLUQ5NDcxJTAjBgNV
# BAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCxulCZttIf8X97rW9/J+Q4Vg9PiugB1ya1/DRxxLW2
# hwy4QgtU3j5fV75ZKa6XTTQhW5ClkGl6gp1nd5VBsx4Jb+oU4PsMA2foe8gP9bQN
# PVxIHMJu6TYcrrn39Hddet2xkdqUhzzySXaPFqFMk2VifEfj+HR6JheNs2LLzm8F
# DJm+pBddPDLag/R+APIWHyftq9itwM0WP5Z0dfQyI4WlVeUS+votsPbWm+RKsH4F
# QNhzb0t/D4iutcfCK3/LK+xLmS6dmAh7AMKuEUl8i2kdWBDRcc+JWa21SCefx5SP
# hJEFgYhdGPAop3G1l8T33cqrbLtcFJqww4TQiYiCkdysCcnIF0ZqSNAHcfI9SAv3
# gfkyxqQNJJ3sTsg5GPRF95mqgbfQbkFnU17iYbRIPJqwgSLhyB833ZDgmzxbKmJm
# dDabbzS0yGhngHa6+gwVaOUqcHf9w6kwxMo+OqG3QZIcwd5wHECs5rAJZ6PIyFM7
# Ad2hRUFHRTi353I7V4xEgYGuZb6qFx6Pf44i7AjXbptUolDcVzYEdgLQSWiuFajS
# 6Xg3k7Cy8TiM5HPUK9LZInloTxuULSxJmJ7nTjUjOj5xwRmC7x2S/mxql8nvHSCN
# 1OED2/wECOot6MEe9bL3nzoKwO8TNlEStq5scd25GA0gMQO+qNXV/xTDOBTJ8zBc
# GQIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFLy2xe59sCE0SjycqE5Erb4YrS1gMB8G
# A1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCG
# Tmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUy
# MFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4w
# XAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwG
# A1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQD
# AgeAMA0GCSqGSIb3DQEBCwUAA4ICAQDhSEjSBFSCbJyl3U/QmFMW2eLPBknnlsfI
# D/7gTMvANEnhq08I9HHbbqiwqDEHSvARvKtL7j0znICYBbMrVSmvgDxU8jAGqMyi
# LoM80788So3+T6IZV//UZRJqBl4oM3bCIQgFGo0VTeQ6RzYL+t1zCUXmmpPmM4xc
# ScVFATXj5Tx7By4ShWUC7Vhm7picDiU5igGjuivRhxPvbpflbh/bsiE5tx5cuOJE
# JSG+uWcqByR7TC4cGvuavHSjk1iRXT/QjaOEeJoOnfesbOdvJrJdbm+leYLRI67N
# 3cd8B/suU21tRdgwOnTk2hOuZKs/kLwaX6NsAbUy9pKsDmTyoWnGmyTWBPiTb2rp
# 5ogo8Y8hMU1YQs7rHR5hqilEq88jF+9H8Kccb/1ismJTGnBnRMv68Ud2l5LFhOZ4
# nRtl4lHri+N1L8EBg7aE8EvPe8Ca9gz8sh2F4COTYd1PHce1ugLvvWW1+aOSpd8N
# nwEid4zgD79ZQxisJqyO4lMWMzAgEeFhUm40FshtzXudAsX5LoCil4rLbHfwYtGO
# pw9DVX3jXAV90tG9iRbcqjtt3vhW9T+L3fAZlMeraWfh7eUmPltMU8lEQOMelo/1
# ehkIGO7YZOHxUqeKpmF9QaW8LXTT090AHZ4k6g+tdpZFfCMotyG+E4XqN6ZWtKEB
# QiE3xL27BDCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZI
# hvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# MjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAy
# MDEwMB4XDTIxMDkzMDE4MjIyNVoXDTMwMDkzMDE4MzIyNVowfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTAwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
# AQDk4aZM57RyIQt5osvXJHm9DtWC0/3unAcH0qlsTnXIyjVX9gF/bErg4r25Phdg
# M/9cT8dm95VTcVrifkpa/rg2Z4VGIwy1jRPPdzLAEBjoYH1qUoNEt6aORmsHFPPF
# dvWGUNzBRMhxXFExN6AKOG6N7dcP2CZTfDlhAnrEqv1yaa8dq6z2Nr41JmTamDu6
# GnszrYBbfowQHJ1S/rboYiXcag/PXfT+jlPP1uyFVk3v3byNpOORj7I5LFGc6XBp
# Dco2LXCOMcg1KL3jtIckw+DJj361VI/c+gVVmG1oO5pGve2krnopN6zL64NF50Zu
# yjLVwIYwXE8s4mKyzbnijYjklqwBSru+cakXW2dg3viSkR4dPf0gz3N9QZpGdc3E
# XzTdEonW/aUgfX782Z5F37ZyL9t9X4C626p+Nuw2TPYrbqgSUei/BQOj0XOmTTd0
# lBw0gg/wEPK3Rxjtp+iZfD9M269ewvPV2HM9Q07BMzlMjgK8QmguEOqEUUbi0b1q
# GFphAXPKZ6Je1yh2AuIzGHLXpyDwwvoSCtdjbwzJNmSLW6CmgyFdXzB0kZSU2LlQ
# +QuJYfM2BjUYhEfb3BvR/bLUHMVr9lxSUV0S2yW6r1AFemzFER1y7435UsSFF5PA
# PBXbGjfHCBUYP3irRbb1Hode2o+eFnJpxq57t7c+auIurQIDAQABo4IB3TCCAdkw
# EgYJKwYBBAGCNxUBBAUCAwEAATAjBgkrBgEEAYI3FQIEFgQUKqdS/mTEmr6CkTxG
# NSnPEP8vBO4wHQYDVR0OBBYEFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMFwGA1UdIARV
# MFMwUQYMKwYBBAGCN0yDfQEBMEEwPwYIKwYBBQUHAgEWM2h0dHA6Ly93d3cubWlj
# cm9zb2Z0LmNvbS9wa2lvcHMvRG9jcy9SZXBvc2l0b3J5Lmh0bTATBgNVHSUEDDAK
# BggrBgEFBQcDCDAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMC
# AYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvX
# zpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20v
# cGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYI
# KwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDANBgkqhkiG
# 9w0BAQsFAAOCAgEAnVV9/Cqt4SwfZwExJFvhnnJL/Klv6lwUtj5OR2R4sQaTlz0x
# M7U518JxNj/aZGx80HU5bbsPMeTCj/ts0aGUGCLu6WZnOlNN3Zi6th542DYunKmC
# VgADsAW+iehp4LoJ7nvfam++Kctu2D9IdQHZGN5tggz1bSNU5HhTdSRXud2f8449
# xvNo32X2pFaq95W2KFUn0CS9QKC/GbYSEhFdPSfgQJY4rPf5KYnDvBewVIVCs/wM
# nosZiefwC2qBwoEZQhlSdYo2wh3DYXMuLGt7bj8sCXgU6ZGyqVvfSaN0DLzskYDS
# PeZKPmY7T7uG+jIa2Zb0j/aRAfbOxnT99kxybxCrdTDFNLB62FD+CljdQDzHVG2d
# Y3RILLFORy3BFARxv2T5JL5zbcqOCb2zAVdJVGTZc9d/HltEAY5aGZFrDZ+kKNxn
# GSgkujhLmm77IVRrakURR6nxt67I6IleT53S0Ex2tVdUCbFpAUR+fKFhbHP+Crvs
# QWY9af3LwUFJfn6Tvsv4O+S3Fb+0zj6lMVGEvL8CwYKiexcdFYmNcP7ntdAoGokL
# jzbaukz5m/8K6TT4JDVnK+ANuOaMmdbhIurwJ0I9JZTmdHRbatGePu1+oDEzfbzL
# 6Xu/OHBE0ZDxyKs6ijoIYn/ZcGNTTY3ugm2lBRDBcQZqELQdVTNYs6FwZvKhggNN
# MIICNQIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEn
# MCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjg2MDMtMDVFMC1EOTQ3MSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQD7
# n7Bk4gsM2tbU/i+M3BtRnLj096CBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA6X6B2TAiGA8yMDI0MDIyMDAxNDE0
# NVoYDzIwMjQwMjIxMDE0MTQ1WjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDpfoHZ
# AgEAMAcCAQACAguGMAcCAQACAhOAMAoCBQDpf9NZAgEAMDYGCisGAQQBhFkKBAIx
# KDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZI
# hvcNAQELBQADggEBAKU5PsO39woXJ9lBXLywhXYw836Wzbr779Fw6wiSSO7yMCXV
# hebTJUSrvcmVZdyC5EOuFLWq/x4RJ8kjB9Fm2VP7oQHnYyuWq+foWMzHTnmh5Xyk
# zcdQHmVj7UDVAHXnBiR9ZgrZabP61L9+kntdmkUfiZzAwzZ3b4Gv+koBtAC5zMmg
# l4caXbCsj3KVMg9qpsSzP4khHvx3uHTya1SHj5mRKpztUCaRM2wUvKQ0MYW+pHbK
# IoFavk1dWqYQy4lFnMWw24P3XPLqPsk9gYjK7a33YaL820CifZJ9uusibRzVDzCo
# uxpvnUYn4bL9PWVao8u8zRMWnyksysDc9bcRm8oxggQNMIIECQIBATCBkzB8MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNy
# b3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAfGzRfUn6MAW1gABAAAB8TAN
# BglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8G
# CSqGSIb3DQEJBDEiBCA76bc+1kPgDecZsXx6wLRxVDYg0cuRQgg82+JlGRJBkzCB
# +gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EINV3/T5hS7ijwao466RosB7wwEib
# t0a1P5EqIwEj9hF4MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTACEzMAAAHxs0X1J+jAFtYAAQAAAfEwIgQgj0fYXspc7WtE8qNEDtanptdvj09r
# cH66KnOgyfW/LYAwDQYJKoZIhvcNAQELBQAEggIAI2Jfiku1FYTcjZ1L5aQm7X4Z
# rAYF9BE5WEE+U1tJn8Oat1tQ8KK56fqKowTzEeh114fzBcFdBBcaSOBtAbw3NxIQ
# qsqECaGDRfPmHvGPNy57iKyPP68GeuITKm7Ms1Hql2vzJ1h9O8GzXOhMSD89xHBo
# cxH3vqvyIOjvZLxk+InEkkxuIyMLlK4qiAXmrMwgBIBgI9SN0+/Po08VZvyjDX9N
# k99M+le+qf0D9KmumNdVxap2UAXryiolITwyTse+GtTgaoFWQtqUd2JTsyk11PzZ
# bLTZpoAZHm4qMRjp1xc0IZNEnvAbIou8u00xgq/yaTnN9jQw1vwIjyjk2BPaWg4I
# ZpdoZZqdIgOVI0GsxVsuwAM9boyFyepurNLne/2uCjE+ifb5m31m6JR/BvalfnyH
# 9LitnaF3KAVMmKGEH9UjSuchW/ZjJA93Bmzv68Mb0oMzPo+FCZVMTX9A9Y0BQUvA
# Pqxxn90Cxs+TgA98vSpXEMI+9Jo8cBxyjgZau03E4uSVTjiSAS1IumiRDZqNMst+
# 4bZOagCdDAJ8+zUCX1lenyNKSsqdxi/XbnhtcuBDzc0Z/NgMkDjJJbPPn/OYPoWQ
# qDU9SarEVcJWxsziwY43LY4sozKxcBzsTvjngnxC2EMPybPTD6PMgchCBBKV2g2A
# /GnPkLoM8zkW8jxx/Dk=
# SIG # End signature block
