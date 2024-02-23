# diag_api.psm1
# by tdimli
# March 2020
# API/helper functions

# errors reported by these diagnostics won't be shown on screen to user
# only saved to xray_ISSUES-FOUND_*.txt report file
$Global:BETA_DIAGS = "
net_802dot1x_KB4556307,
net_firewall_KB4561854,
net_wlan_KB4557342,
net_dnscli_KB4562541,
net_dasrv_KB4504598,
net_netio_KB4563820,
net_srv_KB4562940,
net_hyphost_KB4562593,
net_vpn_KB4553295,
net_vpn_KB4550202,
net_proxy_KB4569506,
net_branchcache_KB4565457,
net_dnssrv_KB4561750,
net_dnssrv_KB4569509,
net_dnscli_KB4617560,
net_ncsi_KB4648334,
net_srv_KB4612362,
net_rpc_KB2506972,
uex_wmi_KB2020286
"

# constants
# return codes
$Global:RETURNCODE_SUCCESS = 0
$Global:RETURNCODE_SKIPPED = 1
$Global:RETURNCODE_FAILED = 2
$Global:RETURNCODE_EXCEPTION = 3

# issue types
$Global:ISSUETYPE_INFO = 0
$Global:ISSUETYPE_WARNING = 1
$Global:ISSUETYPE_ERROR = 2

# value could not be retrieved
$Global:VALUE_NA = "<error!>"

# time format
$Global:TIME_FORMAT = "yyMMdd-HHmmss"

# xray registry path
$xrayRegistryPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\xray"

# wmi data
$Global:wmi_Win32_ComputerSystem
$Global:wmi_Win32_OperatingSystem

# poolmon data
$Global:poolmonData

# globals
$version

$xrayStartTime
$timestamp

$dataPath
$logFile
$infoFile
$issuesFile
$xmlRptFile

$currDiagFn

$xmlReport
$xmlNsMgr
$nodeXray
$xmlTechAreas
$xmlParameters
$xmlSystemInfo
$xmlDiagnostics

# counters
$Global:numDiagsRun = 0
$Global:numDiagsSuccess = 0
$Global:numDiagsSkipped = 0
$Global:numDiagsFailed = 0
$Global:numIssues = 0

$Global:issueShown = $false

# To report an issue if one was identified by a diagnostic function
# Diagnostic functions use this function to report the issue they have identified 
# $issueType: 0 (Info), 1 (Warning) or 2 (Error)
function ReportIssue 
{
    param(
            [Parameter(Mandatory=$true,
            Position=0)]
            [string]
            $issueMsg,

            [Parameter(Mandatory=$true,
            Position=1)]
            [Int]
            $issueType
        )

    $Global:numIssues++
    $onScreenMsg = $true

    # get caller/diagnostic details
    $loc = $VALUE_NA
    $diagFn = $VALUE_NA
    $callStack = Get-PSCallStack
    if ($callStack.Count -gt 1) {
        $loc = (Split-Path -Path $callStack[1].ScriptName -Leaf).ToString() + ":" +  $callStack[1].ScriptLineNumber
        $diagFn = $callStack[1].FunctionName
        if (($loc -eq "") -or ($loc -eq $null)) {
            $loc = $VALUE_NA
        }
        if (($diagFn -eq "") -or ($diagFn -eq $null)) {
            if ($Global:currDiagFn -ne $null) {
                $diagFn = $Global:currDiagFn
            }
            else {
                $diagFn = $loc
            }
            LogWrite "Diagnostic name uncertainty: No on screen message"
            $onScreenMsg = $false
        }
    }

    XmlDiagnosticUpdateIssue $diagFn $IssueType
    LogWrite "Issue (type:$issueType) reported by diagnostic $diagFn [$loc]"

    $outFile = $issuesFile

    # reported issue not an error
    if ($issueType -lt $ISSUETYPE_ERROR) {
        LogWrite "Issue type is not error: No on screen message, saving to info file instead"
        $outFile = $infoFile
        $onScreenMsg = $false
    }

    # diagnostic in beta, no on-screen message
    if ($BETA_DIAGS.Contains($diagFn)) {
        LogWrite "Diagnostic in beta: No on screen message"
        $onScreenMsg = $false
    }

    if(!(Test-Path -Path $outFile)){
        "xray by tdimli, v$version">$outFile
        "Diagnostic check run on $timestamp UTC`r`n">>$outFile
    }
    else {
        # add separator
        "`r`n* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *`r`n">>$outFile
    }
        
    "**">>$outFile
    "** Issue $numIssues`tFound a potential issue (reported by $diagFn):">>$outFile
    "**">>$outFile
    $issueMsg>>$outFile
    
    # show message on screen
    if ($onScreenMsg) {
        $Global:issueShown = $true
        Write-Host ("
**
** Issue $numIssues`tFound a potential issue (reported by $diagFn):
**") -ForegroundColor red
        IndentMsg $issueMsg
    }
}

# Wraps a filename with "xray_" prefix and timestamp & computername suffix for consistency
# Ensures all files created have the same name format, same run of xray script uses the same timestamp-suffix
# Also prepends $dataPath to ensure all files are created in the designated folder
function MakeFilename
{
    param(
            [Parameter(Mandatory=$true,
            Position=0)]
            [string]
            $name,

            [Parameter(Mandatory=$true,
            Position=1)]
            [string]
            $extension
        )

    $computer = hostname
    $filename = "xray_" + $name + "_" + $timestamp + "_" + $computer + "." + $extension
    return Join-Path -Path $dataPath -ChildPath $filename
}

# Logs to activity log with timestamp
function LogWrite
{
    param(
            [Parameter(Mandatory=$true,
            Position=0)]
            [string]
            $msg
        )

    $callStack = Get-PSCallStack
    $caller = $VALUE_NA
    if ($callStack.Count -gt 1) {
        $caller = $callStack[1].FunctionName + " " + (Split-Path -Path $callStack[1].ScriptName -Leaf).ToString() + ":" +  $callStack[1].ScriptLineNumber
    }
    $time = (Get-Date).ToUniversalTime().ToString("yyMMdd-HHmmss.fffffff")
    "$time [$caller] $msg" >> $logFile
}

# returns summary data from poolmon
# if multiple poolmon data sets are available one set for each will be returned
# each returned set will contain two list items with a string[7] in following format
# Example:
# For sample summary:
#  Memory:33356024K Avail:19399488K  PageFlts:400263915   InRam Krnl:12672K P:935188K
#  Commit:15680004K Limit:40433912K Peak:15917968K            Pool N:629240K P:1004712K
# it will return string array(s) containing:
#  Summary1,22/05/2020 22:35:55.53,33356024,19399488,400263915,12672,935188
#  Summary2,22/05/2020 22:35:55.53,15680004,40433912,15917968,629240,1004712
function GetPoolUsageSummary
{
    [System.Collections.Generic.List[string[]]] $poolmonInfo = New-Object "System.Collections.Generic.List[string[]]"

    foreach ($entry in $poolmonData) {
        if ($entry.Contains("Summary")) {
            $poolmonInfo.Add($entry -split ',')
        }
    }

    return $poolmonInfo
}

# returns pool usage info from poolmon for specified pool tag and type
# pooltag has to be 4 characters (case-sensitive), pooltype can be "Nonp" or "Paged" (case-sensitive)
# if multiple poolmon data sets are available all matching entries will be returned
# returns $null if no entry for specified item
# return data type is list of Int64 arrays
# Example:
# For sample entry:
#  Ntfx Nonp    1127072   1037111     89961 26955808        299        
# it will return an Int64 array containing:
#  1127072, 1037111, 89961, 26955808, 299
function GetPoolUsageByTag
{
    param(
            [Parameter(Mandatory=$true,
            Position=0)]
            [ValidatePattern(“.{4}”)]
            [string]
            $poolTag,

            [Parameter(Mandatory=$true,
            Position=1)]
            [ValidatePattern(“(Nonp|Paged)")]
            [string]
            $poolType
        )

    [System.Collections.Generic.List[Int64[]]] $poolmonInfo = New-Object "System.Collections.Generic.List[Int64[]]"

    foreach ($entry in $poolmonData) {
        if ($entry.Contains("$poolTag,$poolType")) {
            $pmEntry = $entry -split ','
            [Int[]] $intArr = New-Object Int[] 5
            for ($i =0; $i -lt 5; $i++) {
                $intArr[$i] = [Convert]::ToInt64($pmEntry[$i + 2])
            }

            $poolmonInfo.Add($intArr)
        }
    }

    return ,$poolmonInfo # unary operator comma is to force the output type to array
}

<#
 Checks if one of the required updates ($reqUpdates) or a later update is present
 Returns 
  true if a required update or later is installed (or if none of the required updates do 
  not apply to current OS version)
   or
  false if a required update is not present (and one of the required updates applies to 
  current OS version)
 $required has a list of updates that specifies the minimum required update for any OS versions 
 to be checked
#>
function HasRequiredUpdate
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [string[]]
        $reqUpdates
    )

    $unknownUpdates = $true
    $knownUpdateSeen = $false

    foreach ($minReqUpd in $reqUpdates) {
        foreach($name in $updateLists) {
            $updateList = (Get-Variable -Name $name -ErrorVariable ErrorMsg -ErrorAction SilentlyContinue).Value
            $minReqIdx = $updateList.id.IndexOf($minReqUpd)
            if ($minReqIdx -ge 0) {
                $unknownUpdates = $false
                foreach($installedUpdate in $installedUpdates) {
                    # look for $minReqUpd or later update
                    $instIdx = $updateList.id.IndexOf($installedUpdate.HotFixID)
                    if ($instIdx -ge 0) {
                        $knownUpdateSeen = $true
                        if ($instIdx -le $minReqIdx) { # updates in $updateList are in reverse chronological order, with most recent at idx=0
                            return $true
                        }
                    }
                }
            }
        }
    }

    if ($unknownUpdates) {
        LogWrite "Required update(s) not known"
        throw
    }

    if ($knownUpdateSeen) {
        return $false
    }

    return $true
}

<#
 Checks if all available Windows updates are installed
 Returns n where
  n=0 latest available update is installed, system up-to-date
  n>0 number of missing updates, i.e. updates that are available but not installed
  n<0 update status cannot be determined
#>
function CheckUpdateStatus
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [Boolean]
        $offline
    )

    $errMsg = @"
This system is missing many important updates. 

The last update installed on this system was:
  {0}

Following {1} update(s) have been released since then:
{2}
Resolution
Please install below update as a matter of urgency:
  {3}
"@
    $Global:NumMissingUpdates = -1
    Clear-Variable -Name MissingUpdates -Scope Global -ErrorVariable ErrorMsg -ErrorAction Ignore
    
    if($offline) {
        LogWrite "Cannot run offline, skipping"
        return $RETURNCODE_SKIPPED
    }

    # Look for missing updates
	try	{
        if ($installedUpdates.Count -eq 0) {
            LogWrite "installedUpdates empty!"
            return $RETURNCODE_FAILED
        }
        
        # identify updateList
        $updateFound = $false
        foreach ($installedUpdate in $installedUpdates) {
            LogWrite $installedUpdate.HotfixId
            foreach ($name in $updateLists) {
                $updateList = (Get-Variable -Name $name -ErrorVariable ErrorMsg -ErrorAction SilentlyContinue).Value
                $idxMRUI = $updateList.id.IndexOf($installedUpdate.HotfixId)
                if ($idxMRUI -ge 0) {
                    $updateFound = $true
                    LogWrite "Relevant update list is $name"
                    break
                }
            }
            if ($updateFound) {
                break
            }
        }

        # identify latest update installed
        if ($updateFound -eq $true) {
            foreach ($update in $updateList) {
                $idxIU = $installedUpdates.HotfixId.IndexOf($update.id)
                if ($idxIU -ge 0) {
                    $idxMRUI = $updateList.id.IndexOf($update.id)
                    $Global:NumMissingUpdates = $idxMRUI
                    $Global:MissingUpdates = $updateList[0..($idxMRUI - 1)]
                    LogWrite "$($updateList[$idxMRUI].id): installedUpdates[$idxIU] is a match for $name[$idxMRUI]"
                    break
                }
            }
        }

        # check results and report
        if ($NumMissingUpdates -lt 0) {
            # failure
            LogWrite "Error: None of the installed updates match update data, update status could not be determined."
            return $RETURNCODE_FAILED
        }
        elseif ($NumMissingUpdates -gt 2) {
            # missing too many updates
            foreach ($upd in $MissingUpdates.heading) {
                $mUpd += "  $upd`r`n"
            }
            $issueType = $ISSUETYPE_ERROR
            $issueMsg = [string]::Format($errMsg, $updateList[$NumMissingUpdates].heading, $NumMissingUpdates, $mUpd, $MissingUpdates[0].heading)
            ReportIssue $issueMsg $issueType
        }
	}
	catch {
		LogWrite "Failed - exiting! (Error: $_)"
        return $RETURNCODE_FAILED
    }

    return $RETURNCODE_SUCCESS
}

# Shows message on screen indented for readability
function IndentMsg
{
    param(
            [Parameter(Mandatory=$true,
            Position=0)]
            [string]
            $msg
        )

    $newMsg = $msg -split "`n"
    foreach ($line in $newMsg) {
        Write-Host "   $line"
    }
}

function InitGlobals
{
    param(
            [Parameter(Mandatory=$true,
            Position=0)]
            [string]
            $ver,

            [Parameter(Mandatory=$true,
            Position=1)]
            [string]
            $path
        )

    $Global:version = $ver
    $Global:dataPath = $path
    $Global:xrayStartTime = (Get-Date).ToUniversalTime()
    $Global:timestamp = $xrayStartTime.ToString($TIME_FORMAT)
    $Global:logFile = MakeFilename "log" "txt"
    $Global:infoFile = MakeFilename "INFO" "txt"
    $Global:issuesFile = MakeFilename "ISSUES-FOUND" "txt"
    $Global:xmlRptFile = MakeFilename "report" "xml"
    $Global:issueShown = $false

    # add and populate root node: nodeXray
    $Global:xmlReport = New-Object System.XML.XMLDocument
    $Global:nodeXray = $xmlReport.CreateElement("xray")
    [void] $xmlReport.appendChild($nodeXray)
    $nodeXray.SetAttribute("Version", $version)
    $nodeXray.SetAttribute("Complete", $false)
    $nodeXray.SetAttribute("StartTime", $timestamp)
    $nodeXray.SetAttribute("Complete", $false)
        
    # add nodes
    $Global:xmlTechAreas = $nodeXray.AppendChild($xmlReport.CreateElement("TechAreas"))
    $Global:xmlParameters = $nodeXray.AppendChild($xmlReport.CreateElement("Parameters"))
    $Global:xmlSystemInfo = $nodeXray.AppendChild($xmlReport.CreateElement("SystemInfo"))
    $Global:xmlDiagnostics = $nodeXray.AppendChild($xmlReport.CreateElement("Diagnostics"))

    # namespace manager
    $Global:xmlNsMgr = New-Object System.Xml.XmlNamespaceManager($xmlReport.NameTable)
    $xmlNsMgr.AddNamespace("xrayNS", $xmlReport.DocumentElement.NamespaceURI)
}

function AddSysInfo
{
    param(
            [Parameter(Mandatory=$true,
            Position=0)]
            [bool]
            $offline
        )

    if ($offline) {
        # if offline retrieve from data
        LogWrite "Offline system info collection not yet implemented"
        return
    }

    # PSVersionTable
    $PSVer = ($PSVersionTable)
    if ($PSVer -ne $null) {
        XmlAddSysInfo "PSVersionTable" "PSVersion" $PSVer.PSVersion
        XmlAddSysInfo "PSVersionTable" "WSManStackVersion" $PSVer.WSManStackVersion
        XmlAddSysInfo "PSVersionTable" "SerializationVersion" $PSVer.SerializationVersion
        XmlAddSysInfo "PSVersionTable" "CLRVersion" $PSVer.CLRVersion
        XmlAddSysInfo "PSVersionTable" "BuildVersion" $PSVer.BuildVersion
    }

    # installedUpdates
    $Global:installedUpdates = Get-HotFix | Sort-Object -Property InstalledOn -Descending -ErrorAction SilentlyContinue

    # Win32_ComputerSystem
    $Global:wmi_Win32_ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
    if ($wmi_Win32_ComputerSystem -ne $null) {
        XmlAddSysInfo "Win32_ComputerSystem" "BootupState" $wmi_Win32_ComputerSystem.BootupState
        XmlAddSysInfo "Win32_ComputerSystem" "PowerState" $wmi_Win32_ComputerSystem.PowerState
        XmlAddSysInfo "Win32_ComputerSystem" "DomainRole" $wmi_Win32_ComputerSystem.DomainRole
        XmlAddSysInfo "Win32_ComputerSystem" "Manufacturer" $wmi_Win32_ComputerSystem.Manufacturer
        XmlAddSysInfo "Win32_ComputerSystem" "Model" $wmi_Win32_ComputerSystem.Model
        XmlAddSysInfo "Win32_ComputerSystem" "NumberOfLogicalProcessors" $wmi_Win32_ComputerSystem.NumberOfLogicalProcessors
        XmlAddSysInfo "Win32_ComputerSystem" "NumberOfProcessors" $wmi_Win32_ComputerSystem.NumberOfProcessors
        XmlAddSysInfo "Win32_ComputerSystem" "OEMStringArray" $wmi_Win32_ComputerSystem.OEMStringArray
        XmlAddSysInfo "Win32_ComputerSystem" "PartOfDomain" $wmi_Win32_ComputerSystem.PartOfDomain
        XmlAddSysInfo "Win32_ComputerSystem" "PCSystemType" $wmi_Win32_ComputerSystem.PCSystemType
        XmlAddSysInfo "Win32_ComputerSystem" "SystemType" $wmi_Win32_ComputerSystem.SystemType
        XmlAddSysInfo "Win32_ComputerSystem" "TotalPhysicalMemory" $wmi_Win32_ComputerSystem.TotalPhysicalMemory
        XmlAddSysInfo "Win32_ComputerSystem" "HypervisorPresent" $wmi_Win32_ComputerSystem.HypervisorPresent
    }

    # Win32_OperatingSystem
    $Global:wmi_Win32_OperatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($wmi_Win32_OperatingSystem -ne $null) {
        XmlAddSysInfo "Win32_OperatingSystem" "Caption" $wmi_Win32_OperatingSystem.Caption
        XmlAddSysInfo "Win32_OperatingSystem" "Version" $wmi_Win32_OperatingSystem.Version
        XmlAddSysInfo "Win32_OperatingSystem" "BuildType" $wmi_Win32_OperatingSystem.BuildType
        XmlAddSysInfo "Win32_OperatingSystem" "BuildNumber" $wmi_Win32_OperatingSystem.BuildNumber
        XmlAddSysInfo "Win32_OperatingSystem" "ProductType" $wmi_Win32_OperatingSystem.ProductType
        XmlAddSysInfo "Win32_OperatingSystem" "OperatingSystemSKU" $wmi_Win32_OperatingSystem.OperatingSystemSKU
        XmlAddSysInfo "Win32_OperatingSystem" "OSArchitecture" $wmi_Win32_OperatingSystem.OSArchitecture
        XmlAddSysInfo "Win32_OperatingSystem" "OSType" $wmi_Win32_OperatingSystem.OSType
        XmlAddSysInfo "Win32_OperatingSystem" "InstallDate" $wmi_Win32_OperatingSystem.InstallDate
        XmlAddSysInfo "Win32_OperatingSystem" "LocalDateTime" $wmi_Win32_OperatingSystem.LocalDateTime
        XmlAddSysInfo "Win32_OperatingSystem" "LastBootUpTime" $wmi_Win32_OperatingSystem.LastBootUpTime
    }
    
    XmlSave
} 

function XmlAddTechArea
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [string]
        $name,

        [Parameter(Mandatory=$true,
        Position=1)]
        [string]
        $ver
    )

    [System.XML.XMLElement]$xmlTechArea = $xmlTechAreas.AppendChild($xmlReport.CreateElement("TechArea"))
    $xmlTechArea.SetAttribute("Name", $name)
    $xmlTechArea.SetAttribute("Version", $ver)
}

function XmlAddParameters
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string[]]
        $areas,

        [Parameter(Mandatory=$true,
        Position=1)]
        [AllowEmptyString()]
        [AllowNull()]
        [string[]]
        $components,

        [Parameter(Mandatory=$true,
        Position=2)]
        [AllowEmptyString()]
        [AllowNull()]
        [string[]]
        $diagnostics,

        [Parameter(Mandatory=$true,
        Position=3)]
        [bool]
        $offline,

        [Parameter(Mandatory=$true,
        Position=4)]
        [bool]
        $waitBeforeClose,

        [Parameter(Mandatory=$true,
        Position=5)]
        [bool]
        $skipDiags,

        [Parameter(Mandatory=$true,
        Position=6)]
        [bool]
        $DevMode
    )

    foreach ($area in $areas) {
        [System.XML.XMLElement] $xmlArea = $xmlParameters.AppendChild($xmlReport.CreateElement("Area"))
        $xmlArea.SetAttribute("Name", $area)
    }
    foreach ($component in $components) {
        [System.XML.XMLElement] $xmlComponent = $xmlParameters.AppendChild($xmlReport.CreateElement("Component"))
        $xmlComponent.SetAttribute("Name", $component)
    }
    foreach ($diagnostic in $diagnostics) {
        [System.XML.XMLElement] $xmlComponent = $xmlParameters.AppendChild($xmlReport.CreateElement("Diagnostic"))
        $xmlComponent.SetAttribute("Name", $diagnostic)
    }
    [System.XML.XMLElement] $xmlOffline = $xmlParameters.AppendChild($xmlReport.CreateElement("Offline"))
    $xmlOffline.SetAttribute("Value", $offline)
    [System.XML.XMLElement] $xmlOffline = $xmlParameters.AppendChild($xmlReport.CreateElement("WaitBeforeClose"))
    $xmlOffline.SetAttribute("Value", $waitBeforeClose)
    [System.XML.XMLElement] $xmlOffline = $xmlParameters.AppendChild($xmlReport.CreateElement("SkipDiags"))
    $xmlOffline.SetAttribute("Value", $skipDiags)
    [System.XML.XMLElement] $xmlOffline = $xmlParameters.AppendChild($xmlReport.CreateElement("DevMode"))
    $xmlOffline.SetAttribute("Value", $DevMode)

    # save
    XmlSave
}

# to add a single attribute from a WMI class
function XmlAddSysInfo
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [string]
        $valueName,

        [Parameter(Mandatory=$true,
        Position=1)]
        [string]
        $attribName,

        [Parameter(Mandatory=$true,
        Position=2)]
        [AllowNull()]
        [System.Object]
        $propertyValue
    )

    if ($propertyValue -ne $null) {

        [System.XML.XMLElement] $wmidata = $nodeXray.SelectSingleNode("/xray/SystemInfo/$valueName")
        if ((!$xmlSystemInfo.HasChildNodes) -or ($wmidata -eq $null)) {
            # doesn't exist, need to add
            $wmidata = $xmlSystemInfo.AppendChild($xmlReport.CreateElement($valueName))
        }
        $wmidata.SetAttribute($attribName, $propertyValue)
    }
}

# to add multiple/all attributes of a WMI class
function XmlAddSysInfoMulti
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [string]
        $valueName,

        [Parameter(Mandatory=$true,
        Position=1)]
        [System.Object[]]
        $attributes
    )

    [System.XML.XMLElement] $wmidata = $nodeXray.SelectSingleNode("/xray/SystemInfo/$valueName")
    if ((!$xmlSystemInfo.HasChildNodes) -or ($wmidata -eq $null)) {
        # doesn't exist, need to add
        $wmidata = $xmlSystemInfo.AppendChild($xmlReport.CreateElement($valueName))
    }
    foreach($attribute in $attributes) {
        $wmidata.SetAttribute($attribute.Name, $attribute.Value)
    }
    XmlSave
}

function XmlAddDiagnostic
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [string]
        $name)

    [System.XML.XMLElement] $xmlDiagnostic = $xmlDiagnostics.AppendChild($xmlReport.CreateElement("Diagnostic"))
    $xmlDiagnostic.SetAttribute("Name", $name)
    $xmlDiagnostic.SetAttribute("Result", -1)
    $xmlDiagnostic.SetAttribute("Duration", -1)
    XmlSave 
}

function XmlDiagnosticComplete
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [string]
        $name,

        [Parameter(Mandatory=$true,
        Position=1)]
        [Int]
        $result,

        [Parameter(Mandatory=$true,
        Position=2)]
        [UInt64]
        $duration
    )

    $xmlDiagnostic = $xmlReport.SelectSingleNode("//xrayNS:Diagnostics/Diagnostic[@Name='$name']", $xmlNsMgr)

    if ($xmlDiagnostic -ne $null) {
        $xmlDiagnostic.SetAttribute("Result", $result)
        $xmlDiagnostic.SetAttribute("Duration", $duration)
        XmlSave 
    }
}

function XmlDiagnosticUpdateIssue
{
    param(
        [Parameter(Mandatory=$true,
        Position=0)]
        [string]
        $name,

        [Parameter(Mandatory=$true,
        Position=1)]
        [Int]
        $issueType
    )

    $xmlDiagnostic = $xmlReport.SelectSingleNode("//xrayNS:Diagnostic[@Name='$name']", $xmlNsMgr)

    if ($xmlDiagnostic -ne $null) {
        $xmlDiagnostic.SetAttribute("Reported", $issueType)
        XmlSave 
    }
}

function XmlMarkComplete
{
    $nodeXray.SetAttribute("Complete", $true)
    XmlSave 
}

function XmlSave
{
    $finishTime = (Get-Date).ToUniversalTime()
    $nodeXray.SetAttribute("EndTime", $finishTime.ToString($TIME_FORMAT))
    [UInt64] $timeTaken = ($finishTime - $xrayStartTime).TotalMilliseconds
    $nodeXray.SetAttribute("Duration", $timeTaken)
    $xmlReport.Save($xmlRptFile)
}

function InitPoolmonData
{
    param(
            [Parameter(Mandatory=$true,
            Position=0)]
            [bool]
            $offline
        )

    $file = Get-ChildItem -Path "$dataPath\*_poolmon.txt" -Name
    if ($file.Count -gt 1) {
        $file = $file[0]
    }

    if ($file -ne $null) {

        $Global:poolmonData = New-Object "System.Collections.Generic.List[string]"
        $pmTimestamp = $VALUE_NA

        $summary1 = "^\s+Memory:\s*(?<memory>[-0-9]+)K Avail:\s*(?<avail>[-0-9]+)K  PageFlts:\s*(?<pageflts>[-0-9]+)   InRam Krnl:\s*(?<inRamKrnl>[-0-9]+)K P:\s*(?<inRamP>[-0-9]+)K"
        $summary2 = "^\s+Commit:\s*(?<commit>[-0-9]+)K Limit:\s*(?<limit>[-0-9]+)K Peak:\s*(?<peak>[-0-9]+)K            Pool N:\s*(?<poolN>[-0-9]+)K P:\s*(?<poolP>[-0-9]+)K"
        $tagentry = "^\s+(?<tag>.{4})\s+(?<type>\w+)\s+(?<allocs>[-0-9]+)\s+(?<frees>[-0-9]+)\s+(?<diff>[-0-9]+)\s+(?<bytes>[-0-9]+)\s+(?<perAlloc>[-0-9]+)\s+$"
        $markerDT = "^\s*===== (?<datetime>(.){22}) ====="
        
        Get-Content "$dataPath\$file" |
        Select-String -Pattern $summary1, $summary2, $tagentry, $markerDT |
        Foreach-Object {

            if ($_.Matches[0].Groups['datetime'].Value -ne "") {
                $pmTimestamp =  $_.Matches[0].Groups['datetime'].Value
            }

            if ($_.Matches[0].Groups['memory'].Value -ne "") {
                #$memory, $avail, $pageflts, $inRamKrnl, $inRamP = $_.Matches[0].Groups['memory', 'avail', 'pageflts', 'inRamKrnl', 'inRamP'].Value
                $memory = $_.Matches[0].Groups['memory'].Value
                $avail = $_.Matches[0].Groups['avail'].Value
                $pageflts = $_.Matches[0].Groups['pageflts'].Value
                $inRamKrnl = $_.Matches[0].Groups['inRamKrnl'].Value
                $inRamP = $_.Matches[0].Groups['inRamP'].Value

                $poolmonData.Add("Summary1,$pmTimestamp,$memory,$avail,$pageflts,$inRamKrnl,$inRamP")
            }

            if ($_.Matches[0].Groups['commit'].Value -ne "") {
                #$commit, $limit, $peak, $poolN, $poolP = $_.Matches[0].Groups['commit', 'limit', 'peak', 'poolN', 'poolP'].Value
                $commit = $_.Matches[0].Groups['commit'].Value
                $limit = $_.Matches[0].Groups['limit'].Value
                $peak = $_.Matches[0].Groups['peak'].Value
                $poolN = $_.Matches[0].Groups['poolN'].Value
                $poolP = $_.Matches[0].Groups['poolP'].Value

                $poolmonData.Add("Summary2,$pmTimestamp,$commit,$limit,$peak,$poolN,$poolP")
                $pmTimestamp = $VALUE_NA
            }

            if ($_.Matches[0].Groups['tag'].Value -ne "") {
                #$tag, $type, $allocs, $frees, $diff, $bytes, $perAlloc = $_.Matches[0].Groups['tag', 'type', 'allocs', 'frees', 'diff', 'bytes', 'perAlloc'].Value
                $tag = $_.Matches[0].Groups['tag'].Value
                $type = $_.Matches[0].Groups['type'].Value
                $allocs = $_.Matches[0].Groups['allocs'].Value
                $frees = $_.Matches[0].Groups['frees'].Value
                $diff = $_.Matches[0].Groups['diff'].Value
                $bytes = $_.Matches[0].Groups['bytes'].Value
                $perAlloc = $_.Matches[0].Groups['perAlloc'].Value 

                $poolmonData.Add("$tag,$type,$allocs,$frees,$diff,$bytes,$perAlloc")
            }
        }
    }
    else {
        LogWrite "Poolmon data not found: $dataPath\*_poolmon.txt"
    }
}

Export-ModuleMember -Function * -Variable *
# SIG # Begin signature block
# MIIoKgYJKoZIhvcNAQcCoIIoGzCCKBcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCnodrVEZFLXCk9
# cJO2/nnTLsBbB8w04yPxU2fzj7f2gaCCDXYwggX0MIID3KADAgECAhMzAAADrzBA
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
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIHl4KHeFasLWoT7l6IxKfz35
# +NNmyZS74y8zelmaLwPbMEIGCisGAQQBgjcCAQwxNDAyoBSAEgBNAGkAYwByAG8A
# cwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20wDQYJKoZIhvcNAQEB
# BQAEggEAoLHZJRJTIXJqL+KNFqAgS3+jarJR9ewjyN7IhB8Vru6za6ZXSDlLuBlP
# fELdJlX7o61Y7D2yy7fsEGT2w7m8kphu5tdG6exjl+A4KKDmV/VszkZxEy4FT+B/
# dGH3lARNZ9TR6pIjWTIIdZZm1I1PPxqx+eGHX2zALpUYvmKLuwJayZEgJXzsNjPW
# 38dHT+0OYdvxk1drizb+sFNtW3DkRFSbM2f6KiXZmcg/ThQmd3R31IjBbCo3np18
# CbDPFV0wg/7lcX2B1mu7f4+LTs7W2LAL1qWhU+/p9D1zMyjgVWZdN1jk5iExSvut
# hbrGBldHri1t1rkD4kP3G6DgDcfHt6GCF5QwgheQBgorBgEEAYI3AwMBMYIXgDCC
# F3wGCSqGSIb3DQEHAqCCF20wghdpAgEDMQ8wDQYJYIZIAWUDBAIBBQAwggFSBgsq
# hkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGEWQoDATAxMA0GCWCGSAFl
# AwQCAQUABCCC4dUXEQ7z7QLZCpqPZljMnIah3DA6mCpA8a4uy0PiyAIGZc4yGh0P
# GBMyMDI0MDIyMDEyMTU1NC4wMjlaMASAAgH0oIHRpIHOMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046MzcwMy0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Wg
# ghHqMIIHIDCCBQigAwIBAgITMwAAAeqaJHLVWT9hYwABAAAB6jANBgkqhkiG9w0B
# AQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0yMzEyMDYxODQ1
# MzBaFw0yNTAzMDUxODQ1MzBaMIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25z
# MScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046MzcwMy0wNUUwLUQ5NDcxJTAjBgNV
# BAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQC1C1/xSD8gB9X7Ludoo2rWb2ksqaF65QtJkbQpmsc6
# G4bg5MOv6WP/uJ4XOJvKX/c1t0ej4oWBqdGD6VbjXX4T0KfylTulrzKtgxnxZh7q
# 1uD0Dy/w5G0DJDPb6oxQrz6vMV2Z3y9ZxjfZqBnDfqGon/4VDHnZhdas22svSC5G
# HywsQ2J90MM7L4ecY8TnLI85kXXTVESb09txL2tHMYrB+KHCy08ds36an7IcOGfR
# mhHbFoPa5om9YGpVKS8xeT7EAwW7WbXL/lo5p9KRRIjAlsBBHD1TdGBucrGC3TQX
# STp9s7DjkvvNFuUa0BKsz6UiCLxJGQSZhd2iOJTEfJ1fxYk2nY6SCKsV+VmtV5ai
# PzY/sWoFY542+zzrAPr4elrvr9uB6ci/Kci//EOERZEUTBPXME/ia+t8jrT2y3ug
# 15MSCVuhOsNrmuZFwaRCrRED0yz4V9wlMTGHIJW55iNM3HPVJJ19vOSvrCP9lsEc
# EwWZIQ1FCyPOnkM1fs7880dahAa5UmPqMk5WEKxzDPVp081X5RQ6HGVUz6ZdgQ0j
# cT59EG+CKDPRD6mx8ovzIpS/r/wEHPKt5kOhYrjyQHXc9KHKTWfXpAVj1Syqt5X4
# nr+Mpeubv+N/PjQEPr0iYJDjSzJrqILhBs5pytb6vyR8HUVMp+mAA4rXjOw42vkH
# fQIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFCuBRSWiUebpF0BU1MTIcosFblleMB8G
# A1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRYMFYwVKBSoFCG
# Tmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY3Jvc29mdCUy
# MFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEFBQcBAQRgMF4w
# XAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY2Vy
# dHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3J0MAwG
# A1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQD
# AgeAMA0GCSqGSIb3DQEBCwUAA4ICAQAog61WXj9+/nxVbX3G37KgvyoNAnuu2w3H
# oWZj3H0YCeQ3b9KSZThVThW4iFcHrKnhFMBbXJX4uQI53kOWSaWCaV3xCznpRt3c
# 4/gSn3dvO/1GP3MJkpJfgo56CgS9zLOiP31kfmpUdPqekZb4ivMR6LoPb5HNlq0W
# bBpzFbtsTjNrTyfqqcqAwc6r99Df2UQTqDa0vzwpA8CxiAg2KlbPyMwBOPcr9hJT
# 8sGpX/ZhLDh11dZcbUAzXHo1RJorSSftVa9hLWnzxGzEGafPUwLmoETihOGLqIQl
# Cpvr94Hiak0Gq0wY6lduUQjk/lxZ4EzAw/cGMek8J3QdiNS8u9ujYh1B7NLr6t3I
# glfScDV3bdVWet1itTUoKVRLIivRDwAT7dRH13Cq32j2JG5BYu/XitRE8cdzaJmD
# VBzYhlPl9QXvC+6qR8I6NIN/9914bTq/S4g6FF4f1dixUxE4qlfUPMixGr0Ft4/S
# 0P4fwmhs+WHRn62PB4j3zCHixKJCsRn9IR3ExBQKQdMi5auiqB6xQBADUf+F7hSK
# ZfbA8sFSFreLSqhvj+qUQF84NcxuaxpbJWVpsO18IL4Qbt45Cz/QMa7EmMGNn7a8
# MM3uTQOlQy0u6c/jq111i1JqMjayTceQZNMBMM5EMc5Dr5m3T4bDj9WTNLgP8SFe
# 3EqTaWVMOTCCB3EwggVZoAMCAQICEzMAAAAVxedrngKbSZkAAAAAABUwDQYJKoZI
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
# MCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOjM3MDMtMDVFMC1EOTQ3MSUwIwYDVQQD
# ExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQCJ
# 2x7cQfjpRskJ8UGIctOCkmEkj6CBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA6X6fQDAiGA8yMDI0MDIyMDAzNDcx
# MloYDzIwMjQwMjIxMDM0NzEyWjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDpfp9A
# AgEAMAcCAQACAgK4MAcCAQACAhLrMAoCBQDpf/DAAgEAMDYGCisGAQQBhFkKBAIx
# KDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZI
# hvcNAQELBQADggEBAC8Z33lrpkjdh/9OZYrHdy+XyJLMQlmcFlB2/+WKbf0DsRik
# Q1KdJFxUklVYhW+4lRlduFt06+SR4NC2NvRVXmlsfhuj/Iup8jFduIWHOB9k/Fpb
# 30Sq57/dtJ3QfuYwjKcOCiGse7g4F63hbxikUe0qUXggxKnhcCaDzGnKBve1DxUR
# lJvnwY0xzjvHvR6l6S7S/a2DWxzXkunAh1XVI0Btp7miOABu2SnjgPRe2pip9dXg
# RFFlDL/oqoCyNdWseV7tFKumou/XuzxlOXKe1yfwRR0W9kuVI7c3SlEWtPT82Yt8
# uGGFtMesZbNz4c3sDfhNoDSiXaah1yNRLbH/pKYxggQNMIIECQIBATCBkzB8MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNy
# b3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAeqaJHLVWT9hYwABAAAB6jAN
# BglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8G
# CSqGSIb3DQEJBDEiBCDGXekvLcWo4TtBWC1PQBYegmIzUzp8ZyCwcoT8gy+gzTCB
# +gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EICmPodXjZDR4iwg0ltLANXBh5G1u
# KqKIvq8sjKekuGZ4MIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTACEzMAAAHqmiRy1Vk/YWMAAQAAAeowIgQgKecIqv2BR+ysCc/UL/YEWflOkbyq
# 3B21NE75O92mCZ4wDQYJKoZIhvcNAQELBQAEggIAJhueJXPxxiwmr36I15p7NMqE
# Wpys0Uy658JPox1Z3W97E3/dA/fDzlEjXpTiDmYDowhzggcgsE2vERlbhO7v3K93
# rPeY6SmDunkNXAeLTY6oUPSfqztuLs2Ob6hKGGpWlOgEd5ZRG82gwyP8KWEWEBrP
# ww7OdnfeBovI/4ZW/JkOq6hzsdas4hlt6ErjomnIyCEJxOduLjfcJhMUrDtrMQ1K
# qz6jmm/RJl73QvENqF1r04whM1IM8GtRk/ja0d6Wq6/CzIhPQZyVUdGL+aJ+RSAF
# mABH/8SL48ae/umdeyuBpCEIHLeJuZq84iag9/aCniMgMM5n1RoNKPYIos+aZxw1
# qMmy3qBgSd6NrANmI12cY1El7AKJjWXm+/il/gsmmkib9i6+k3NlTuqimN32SJ7t
# 2sCM2hdHVhzipF533jn6u2NK5ux243VOyBOpddT3UTlG3mDzzX2Ab0HQ6ijyfj8O
# 5dOAJyyIm9wOV7j8K5kvrwpsAHTZD17vfdocWqZiqUSWt27P5d6RIr7yLF4sLQ2Y
# ojHecyNChhDvefsLOXUoOzurmhGc6DthWi4ti2eHxvHJczW7VsAVUOJMJ2ToyyH2
# b5ELb/Q4PpL/SDlihaITP9oAwO+CiDuRKH6n3PH4hh+WYgqt5SsOpXIBKc3SJ/dO
# 1x8m7M45cTKR0K0n+VU=
# SIG # End signature block
