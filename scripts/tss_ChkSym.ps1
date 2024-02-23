#***************************************************
# modified version of tss_ChkSym.ps1 for usage in TSS
# Version 1.0.1cmd.exe /c
# Date: 7/15/2019
# Author: +waltere 2019.07.15, sabieler 2024.01.29 (TSS version)
# Description:  This file will use Checksym.exe to list all file versions on the local machine
#***************************************************

PARAM($ChkSymRange="All", $ChkSymPrefix="_sym", $FolderName=$null, $FileMask=$null, $ChkSymSuffix=$null, $FileDescription = $null, $ChkSymOutFolder=$null, [switch] $Recursive, [switch] $SkipCheckSymExe)

$ComputerName = $env:COMPUTERNAME
$LogPrefix = "ChkSym"
$ChkSymExe = $global:ChecksymExe
$IsSkipChecksymExe = ($SkipCheckSymExe.IsPresent)
if ($ChkSymOutFolder -and $ChkSymOutFolder[-1] -ne '\') { $ChkSymOutFolder += '\' }

if (($Env:PROCESSOR_ARCHITECTURE -eq 'ARM') -and (-not($IsSkipChecksymExe))){
	Logwarn 'Skipping running chksym executable since it is not supported in ' + $Env:PROCESSOR_ARCHITECTURE + ' architecture.'
	$IsSkipChecksymExe=$true
}
if($IsSkipChecksymExe){
	Logwarn "External chksym executable not be used since $ChkSymExe does not exist"
}

$Error.Clear() | Out-Null

# Import-LocalizedData -BindingVariable LocalsCheckSym -FileName DC_ChkSym
# using psobject instead
$LocalsCheckSym = New-Object PSObject
Add-Member -InputObject $LocalsCheckSym -MemberType NoteProperty -Name 'ID_FileVersionInfo' -Value "File Version Information (ChkSym)"

Trap [Exception]
{
	$errorMessage = $_.Exception.Message
	$errorCode = $_.Exception.ErrorRecord.FullyQualifiedErrorId
	$line = $_.InvocationInfo.PositionMessage
	#"[DC_ChkSym] Error " + $errorCode + " on line " + $line + ": $errorMessage running dc_chksym.ps1" | WriteTo-StdOut -ShortFormat
	LogWarn "Error $errorCode on line $($line): $errorMessage running $global:ScriptsFolder\tss_ChkSym.ps1"
	$Error.Clear() | Out-Null
}

function GetExchangeInstallFolder{
	If ((Test-Path "HKLM:SOFTWARE\Microsoft\ExchangeServer\v14") -eq $true){
		[System.IO.Path]::GetDirectoryName((get-itemproperty HKLM:\SOFTWARE\Microsoft\ExchangeServer\v14\Setup).MsiInstallPath)
	} ElseIf ((Test-Path "HKLM:SOFTWARE\Microsoft\Exchange\v8.0") -eq $true) {
		[System.IO.Path]::GetDirectoryName((get-itemproperty HKLM:\SOFTWARE\Microsoft\Exchange\Setup).MsiInstallPath)
	} Else {
		$null
	}
}

function GetDPMInstallFolder{
	if ((Test-Path "HKLM:SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup") -eq $true)
	{
		return [System.IO.Path]::GetDirectoryName((get-itemproperty HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup).InstallPath)
	}
	else
	{
		return $null
	}
}


Function FileExistOnFolder($PathToScan, $FileMask, [switch] $Recursive){
	Trap [Exception] {
		$ErrorStd = "[FileExistOnFolder] The following error ocurred when checking if a file exists on a folder:`n"
		$errorMessage = $_.Exception.Message
		$errorCode = $_.Exception.ErrorRecord.FullyQualifiedErrorId
		$line = $_.InvocationInfo.PositionMessage
		# "$ErrorStd Error " + $errorCode + " on line " + $line + ": $errorMessage`n   Path: $PathToScan`n   FileMask: $FileMask"
		LogWarnFile "$ErrorStd Error $errorCode on line $($line): $errorMessage`n Path: $PathToScan`n FileMask: $FileMask"
		$error.Clear
		continue
	}

	$AFileExist = $false

	if (Test-Path $PathToScan)
	{
		foreach ($mask in $FileMask) {
			if ($AFileExist -eq $false) {
				if ([System.IO.Directory]::Exists($PathToScan)) {
					if ($Recursive.IsPresent)
					{
						$Files = [System.IO.Directory]::GetFiles($PathToScan, $mask,[System.IO.SearchOption]::AllDirectories)
					} else {
						$Files = [System.IO.Directory]::GetFiles($PathToScan, $mask,[System.IO.SearchOption]::TopDirectoryOnly)
					}
					$AFileExist = ($Files.Count -ne 0)
				}
			}
		}
	}
	return $AFileExist
}

Function GetAllRunningDriverFilePath([string] $DriverName){
	$driversPath = "HKLM:System\currentcontrolset\services\"+$DriverName
	if(Test-Path $driversPath){
		$ImagePath = (Get-ItemProperty ("HKLM:System\currentcontrolset\services\"+$DriverName)).ImagePath
	}
	if($null -eq $ImagePath){
		$driversPath = "system32\drivers\"+$DriverName+".sys"
		$ImagePath = join-path $env:windir $driversPath
		if(-not(Test-Path $ImagePath))
		{
			Loginfo "$($Driver.Name) not exist in the system32\drivers\" Red
		}
	}
	else{
		if($ImagePath.StartsWith("\SystemRoot\")){
			$ImagePath = $ImagePath.Remove(0,12)
		}
		elseif($ImagePath.StartsWith("\??\")){
			$ImagePath = $ImagePath.Remove(0,14)
		}
		$ImagePath = join-path $env:windir $ImagePath
	}
	return $ImagePath
}

Function PrintTXTCheckSymInfo([PSObject]$OutPut, $StringBuilder, [switch]$S, [switch]$R){
	if($null -ne $OutPut.Processes)
	{
		[void]$StringBuilder.Append("*******************************************************************************`r`n")
		[void]$StringBuilder.Append("[PROCESSES] - Printing Process Information for "+$OutPut.Processes.Count +" Processes.`r`n")
		[void]$StringBuilder.Append("[PROCESSES] - Context: System Process(es)`r`n")
		[void]$StringBuilder.Append("*******************************************************************************`r`n")

		Foreach($Process in $OutPut.Processes)
		{
			$Index = 1
			[void]$StringBuilder.Append("-----------------------------------------------------------`r`n")
			[void]$StringBuilder.Append("Process Name ["+$Process.ProcessName.ToUpper()+".EXE] - PID="+$Process.Id +" - "+ $Process.Modules.Count +" modules recorded`r`n")
			[void]$StringBuilder.Append("-----------------------------------------------------------`r`n")
			foreach($mod in $Process.Modules)
			{
				if($null -ne $mod.FileName)
				{
					[void]$StringBuilder.Append("Module[  "+$Index+"] [" + $mod.FileName+"]`r`n")
					if($R.IsPresent)
					{
						$FileItem = Get-ItemProperty $mod.FileName
						[void]$StringBuilder.Append("  Company Name:      " + $FileItem.VersionInfo.CompanyName	+"`r`n")
						[void]$StringBuilder.Append("  File Description:  " + $FileItem.VersionInfo.FileDescription +"`r`n")
						[void]$StringBuilder.Append("  Product Version:   " + $FileItem.VersionInfo.ProductVersion+"`r`n")
						[void]$StringBuilder.Append("  File Version:      " + $FileItem.VersionInfo.FileVersion+"`r`n")
						[void]$StringBuilder.Append("  File Size (bytes): " + $FileItem.Length+"`r`n")
						[void]$StringBuilder.Append("  File Date:         " + $FileItem.LastWriteTime+"`r`n")

					}

					if($S.IsPresent)
					{

					}
					[void]$StringBuilder.Append("`r`n")
					$Index+=1
				}
			}
		}
	}

	if($null -ne $OutPut.Drivers)
	{
		[void]$StringBuilder.Append("*******************************************************************************`r`n")
		[void]$StringBuilder.Append( "[KERNEL-MODE DRIVERS] - Printing Module Information for "+$OutPut.Drivers.Count +" Modules.`r`n")
		[void]$StringBuilder.Append( "[KERNEL-MODE DRIVERS] - Context: Kernel-Mode Driver(s)`r`n")
		[void]$StringBuilder.Append( "*******************************************************************************`r`n")
		$Index = 1
		Foreach($Driver in $OutPut.Drivers)
		{
			$DriverFilePath = GetAllRunningDriverFilePath $Driver.Name
			[void]$StringBuilder.Append("Module[  "+$Index+"] [" + $DriverFilePath+"]`r`n")

			if($R.IsPresent)
			{
				$FileItem = Get-ItemProperty $DriverFilePath
				if(($null -ne $FileItem.VersionInfo.CompanyName) -and ($FileItem.VersionInfo.CompanyName -ne ""))
				{
					[void]$StringBuilder.Append("  Company Name:      " + $FileItem.VersionInfo.CompanyName	+"`r`n")
				}

				if(($null -ne $FileItem.VersionInfo.FileDescription) -and ($FileItem.VersionInfo.FileDescription.trim() -ne ""))
				{
					[void]$StringBuilder.Append("  File Description:  " + $FileItem.VersionInfo.FileDescription +"`r`n")
				}

				if(($null -ne $FileItem.VersionInfo.ProductVersion) -and ($FileItem.VersionInfo.ProductVersion -ne ""))
				{
					[void]$StringBuilder.Append("  Product Version:   " + $FileItem.VersionInfo.ProductVersion+"`r`n")
				}

				if(($null -ne $FileItem.VersionInfo.FileVersion) -and ($FileItem.VersionInfo.FileVersion -ne ""))
				{
					[void]$StringBuilder.Append("  File Version:      " + $FileItem.VersionInfo.FileVersion+"`r`n"	)
				}
				[void]$StringBuilder.Append("  File Size (bytes): " + $FileItem.Length+"`r`n")
				[void]$StringBuilder.Append("  File Date:         " + $FileItem.LastWriteTime+"`r`n")
			}

			if($S.IsPresent)
			{

			}

			[void]$StringBuilder.Append("`r`n")
			$Index+=1
		}
	}

	if($null -ne $OutPut.Files)
	{
		[void]$StringBuilder.Append("*******************************************************************************`r`n")
		[void]$StringBuilder.Append("[FILESYSTEM MODULES] - Printing Module Information for "+$OutPut.Files.Count +" Modules.`r`n")
		[void]$StringBuilder.Append("[FILESYSTEM MODULES] - Context: Filesystem Modules`r`n")
		[void]$StringBuilder.Append("*******************************************************************************`r`n")
		$Index = 1
		Foreach($File in $OutPut.Files)
		{
			[void]$StringBuilder.Append("Module[  "+$Index+"] [" + $File+"]`r`n")
			if($R.IsPresent)
			{
				$FileItem = Get-ItemProperty $File
				if(($null -ne $FileItem.VersionInfo.CompanyName) -and ($FileItem.VersionInfo.CompanyName -ne ""))
				{
					[void]$StringBuilder.Append("  Company Name:      " + $FileItem.VersionInfo.CompanyName	+"`r`n")
				}

				if(($null -ne $FileItem.VersionInfo.FileDescription) -and ($FileItem.VersionInfo.FileDescription.trim() -ne ""))
				{
					[void]$StringBuilder.Append("  File Description:  " + $FileItem.VersionInfo.FileDescription +"`r`n")
				}

				if(($null -ne $FileItem.VersionInfo.ProductVersion) -and ($FileItem.VersionInfo.ProductVersion -ne ""))
				{
					[void]$StringBuilder.Append("  Product Version:   " + $FileItem.VersionInfo.ProductVersion+"`r`n")
				}

				if(($null -ne $FileItem.VersionInfo.FileVersion) -and ($FileItem.VersionInfo.FileVersion -ne ""))
				{
					[void]$StringBuilder.Append("  File Version:      " + $FileItem.VersionInfo.FileVersion+"`r`n"	)
				}
				[void]$StringBuilder.Append("  File Size (bytes): " + $FileItem.Length+"`r`n")
				[void]$StringBuilder.Append("  File Date:         " + $FileItem.LastWriteTime+"`r`n")
			}

			if($S.IsPresent)
			{

			}
			[void]$StringBuilder.Append("`r`n")
			$Index+=1
		}
	}
}

Function PrintCSVCheckSymInfo([PSObject]$OutPut, $StringBuilder, [switch]$S, [switch]$R){
	[void]$StringBuilder.Append("Create:,"+[DateTime]::Now+"`r`n")
	[void]$StringBuilder.Append("Computer:,"+ $ComputerName+"`r`n`r`n")

	if($null -ne $OutPut.Processes)
	{
		[void]$StringBuilder.Append("[PROCESSES]`r`n")
		[void]$StringBuilder.Append(",Process Name,Process ID,Module Path,Symbol Status,Checksum,Time/Date Stamp,Time/Date String,Size Of Image,DBG Pointer,PDB Pointer,PDB Signature,PDB Age,Product Version,File Version,Company Name,File Description,File Size,File Time/Date Stamp (High),File Time/Date Stamp (Low),File Time/Date String,Local DBG Status,Local DBG,Local PDB Status,Local PDB`r`n")
		Foreach($Process in $OutPut.Processes)
		{
			if($null -ne $Process.Modules)
			{
				foreach($mod in $Process.Modules)
				{
					if($null -ne $mod.FileName)
					{
						[void]$StringBuilder.Append("," +$Process.Name+".EXE,"+$Process.Id+",")
						[void]$StringBuilder.Append( $mod.FileName+",")
						if($S.IsPresent)
						{
							[void]$StringBuilder.Append("SYMBOLS_PDB,,,,,,,,,")
						}
						else
						{
							[void]$StringBuilder.Append("SYMBOLS_No,,,,,,,,,")
						}

						if($R.IsPresent)
						{
							$FileItem = Get-ItemProperty $mod.FileName
							[void]$StringBuilder.Append( "("+$FileItem.VersionInfo.ProductVersion.Replace(",",".")+"	),("+$FileItem.VersionInfo.FileVersion.Replace(",",".")+"	),"+$FileItem.VersionInfo.CompanyName.Replace(",",".")+","+$FileItem.VersionInfo.FileDescription.Replace(",",".")+","+$FileItem.Length+",,,"+$FileItem.LastWriteTime+",,,,,`r`n")
						}
						else
						{
							[void]$StringBuilder.Append( ",,,,,,,,,,,,`r`n")
						}
					}
				}
			}
		}
	}

	if($null -ne $OutPut.Drivers)
	{
		[void]$StringBuilder.Append("[KERNEL-MODE DRIVERS]`r`n")
		[void]$StringBuilder.Append(",,,Module Path,Symbol Status,Checksum,Time/Date Stamp,Time/Date String,Size Of Image,DBG Pointer,PDB Pointer,PDB Signature,PDB Age,Product Version,File Version,Company Name,File Description,File Size,File Time/Date Stamp (High),File Time/Date Stamp (Low),File Time/Date String,Local DBG Status,Local DBG,Local PDB Status,Local PDB`r`n")
		Foreach($Driver in $OutPut.Drivers)
		{
			$DriverFilePath = GetAllRunningDriverFilePath $Driver.Name
			[void]$StringBuilder.Append(",,," +$DriverFilePath+",")
			if($S.IsPresent)
			{
				[void]$StringBuilder.Append("SYMBOLS_PDB,,,,,,,,,")
			}
			else
			{
				[void]$StringBuilder.Append("SYMBOLS_NO,,,,,,,,,")
			}

			if($R.IsPresent)
			{
				$DriverItem = Get-ItemProperty $DriverFilePath
				if($null -ne $DriverItem.VersionInfo.ProductVersion)
				{
					[void]$StringBuilder.Append("("+$DriverItem.VersionInfo.ProductVersion.Replace(",",".")+"),("+$DriverItem.VersionInfo.FileVersion.Replace(",",".")+"),"+$DriverItem.VersionInfo.CompanyName.Replace(",",".")+","+$DriverItem.VersionInfo.FileDescription.Replace(",",".")+","+$DriverItem.Length+",,,"+$DriverItem.LastWriteTime+",,,,,`r`n")
				}
				else
				{
					[void]$StringBuilder.Append(",,,,"+$DriverItem.Length+",,,"+$DriverItem.LastWriteTime+",,,,,`r`n")
				}
			}
			else
			{
				[void]$StringBuilder.Append(",,,,,,,,,,,,`r`n")
			}
		}
	}

	if($null -ne $OutPut.Files)
	{
		[void]$StringBuilder.Append("[FILESYSTEM MODULES]`r`n")
		[void]$StringBuilder.Append(",,,Module Path,Symbol Status,Checksum,Time/Date Stamp,Time/Date String,Size Of Image,DBG Pointer,PDB Pointer,PDB Signature,PDB Age,Product Version,File Version,Company Name,File Description,File Size,File Time/Date Stamp (High),File Time/Date Stamp (Low),File Time/Date String,Local DBG Status,Local DBG,Local PDB Status,Local PDB`r`n")
		Foreach($File in $OutPut.Files)
		{
			[void]$StringBuilder.Append(",,," +$File+",")
			if($S.IsPresent)
			{
				[void]$StringBuilder.Append("SYMBOLS_PDB,,,,,,,,,")
			}
			else
			{
				[void]$StringBuilder.Append("SYMBOLS_NO,,,,,,,,,")
			}

			if($R.IsPresent)
			{
				$FileItem = Get-ItemProperty $File
				if($null -ne $FileItem.VersionInfo.ProductVersion)
				{
					[void]$StringBuilder.Append("("+$FileItem.VersionInfo.ProductVersion.Replace(",",".")+"	),("+$FileItem.VersionInfo.FileVersion.Replace(",",".")+"	),"+$FileItem.VersionInfo.CompanyName.Replace(",",".")+","+$FileItem.VersionInfo.FileDescription.Replace(",",".")+","+$FileItem.Length+",,,"+$FileItem.LastWriteTime+",,,,,`r`n")
				}
				else
				{
					[void]$StringBuilder.Append(",,,,"+$FileItem.Length+",,,"+$FileItem.LastWriteTime+",,,,,`r`n")
				}
			}
			else
			{
				[void]$StringBuilder.Append(",,,,,,,,,,,,`r`n")
			}
		}
	}
}

Function PSChkSym ([string]$PathToScan="", [array]$FileMask = "*.*", [string]$O2="", [String]$P ="", [switch]$D, [switch]$F, [switch]$F2, [switch]$S, [switch]$R){
	# Check the system information
	#  P ----- get the process information, can give a * get all process info or give a process name get the specific process
	#  D ----- get the all local running drivers infor
	#  F ----- search the top level folder to get the files
	#  F2 ---- search the all level from folder, Recursive
	#  S ----- get Symbol Information
	#  R ----- get the Version and File-System Information
	#  O2 ---- Out the result to the file
	Trap [Exception] {

		$ErrorStd = "[PSChkSym] The following error ocurred when getting the file from a folder:`n"
		$errorMessage = $_.Exception.Message
		$errorCode = $_.Exception.ErrorRecord.FullyQualifiedErrorId
		$line = $_.InvocationInfo.PositionMessage
		#"$ErrorStd Error " + $errorCode + " on line " + $line + ": $errorMessage`n   Path: $PathToScan`n   FileMask: $FileMask" | WriteTo-StdOut -ShortFormat
		LogWarnFile "$ErrorStd Error $errorCode on line  $($line): $errorMessage`n Path: $PathToScan`n FileMask: $FileMask"
		$error.Clear
		continue
	}

	$OutPutObject = New-Object PSObject
	$SbCSVFormat = New-Object -TypeName System.Text.StringBuilder
	$SbTXTFormat = New-Object -TypeName System.Text.StringBuilder
	[void]$SbTXTFormat.Append("***** COLLECTION OPTIONS *****`r`n")

	if($P -ne "")
	{
		[void]$SbTXTFormat.Append("Collect Information From Running Processes`r`n")
		if($P -eq "*")
		{
			[void]$SbTXTFormat.Append("    -P *     (Query all local processes) `r`n")

			$Processes = [System.Diagnostics.Process]::GetProcesses()
		}
		else
		{
			[void]$SbTXTFormat.Append("    -P $P     (Query for specific process by name) `r`n" )

			$Processes = [System.Diagnostics.Process]::GetProcessesByName($P)
		}
	}

	if($D.IsPresent)
	{
		[void]$SbTXTFormat.Append("    -D     (Query all local device drivers) `r`n")
		Add-Type -assemblyname System.ServiceProcess
		$DeviceDrivers = [System.ServiceProcess.ServiceController]::GetDevices() | where-object {$_.Status -eq "Running"}
		# $DeviceDrivers = GetAllRunningDriverFileName
	}

	if($F.IsPresent -or $F2.IsPresent)
	{
		[void]$SbTXTFormat.Append("Collect Information From File(s) Specified by the User`r`n")
		[void]$SbTXTFormat.Append("   -F $PathToScan\$FileMask`r`n")
		if($F.IsPresent)
		{
			Foreach($Mask in $FileMask)
			{
				$Files += [System.IO.Directory]::GetFiles($PathToScan, $Mask,[System.IO.SearchOption]::TopDirectoryOnly)
			}
		}
		else
		{
			Foreach($Mask in $FileMask)
			{
				$Files += [System.IO.Directory]::GetFiles($PathToScan, $Mask,[System.IO.SearchOption]::AllDirectories)
			}
		}
	}

	[void]$SbTXTFormat.Append("***** INFORMATION CHECKING OPTIONS *****`r`n")
	if($S.IsPresent -or $R.IsPresent)
	{
		if($S.IsPresent)
		{

			[void]$SbTXTFormat.Append("Output Symbol Information From Modules`r`n")
			[void]$SbTXTFormat.Append("   -S `r`n")
		}

		if($R.IsPresent)
		{
			[void]$SbTXTFormat.Append("Collect Version and File-System Information From Modules`r`n")
			[void]$SbTXTFormat.Append("   -R `r`n")
		}
	}
	else
	{
		[void]$SbTXTFormat.Append("Output Symbol Information From Modules`r`n")
		[void]$SbTXTFormat.Append("   -S `r`n")
		[void]$SbTXTFormat.Append("Collect Version and File-System Information From Modules`r`n")
		[void]$SbTXTFormat.Append("   -R `r`n")
	}

	[void]$SbTXTFormat.Append("***** OUTPUT OPTIONS *****`r`n")
	[void]$SbTXTFormat.Append("Output Results to STDOUT`r`n")
	[void]$SbTXTFormat.Append("Output Collected Module Information To a CSV File`r`n")

	if($O2 -ne "")
	{
		$OutFiles = $O2.Split('>')
		[void]$SbTXTFormat.Append("   -O "+$OutFiles[0]+" `r`n")
	}

	## Add-Member -inputobject $OutPutObject -membertype noteproperty -name "Processes" -value $Processes
	## Add-Member -inputobject $OutPutObject -membertype noteproperty -name "Drivers" -value $DeviceDrivers
	## Add-Member -inputobject $OutPutObject -membertype noteproperty -name "Files" -value $Files

	if(($S.IsPresent -and $R.IsPresent) -or (-not$S.IsPresent -and -not$R.IsPresent))
	{
		PrintTXTCheckSymInfo -OutPut $OutPutObject $SbTXTFormat -S -R
		PrintCSVCheckSymInfo -OutPut $OutPutObject $SbCSVFormat -S -R
	}
	elseif($S.IsPresent -and -not$R.IsPresent)
	{
		PrintTXTCheckSymInfo -OutPut $OutPutObject $SbTXTFormat -S
		PrintCSVCheckSymInfo -OutPut $OutPutObject $SbCSVFormat -S
	}
	else
	{
		PrintTXTCheckSymInfo -OutPut $OutPutObject $SbTXTFormat -R
		PrintCSVCheckSymInfo -OutPut $OutPutObject $SbCSVFormat -R
	}

	foreach($out in $OutFiles)
	{
		if($out.EndsWith("CSV",[StringComparison]::InvariantCultureIgnoreCase))
		{
			$SbCSVFormat.ToString() | Out-File $out -Encoding "utf8"
		}
		else
		{
			if(Test-Path $out)
			{
				$SbTXTFormat.ToString() | Out-File $out -Encoding "UTF8" -Append
			}
			else
			{
				$SbTXTFormat.ToString() | Out-File $out -Encoding "UTF8"
			}
		}
	}
}

Function RunChkSym ([string]$PathToScan="", [array]$FileMask = "*.*", [string]$Output="", [boolean]$Recursive=$false, [string]$Arguments="", [string]$Description="", [boolean]$SkipChksymExe=$false){
	if (($Arguments -ne "") -or (Test-Path ($PathToScan)))
	{
		if ($PathToScan -ne "")
		{
			$eOutput = $Output
			ForEach ($scFileMask in $FileMask){ #
				$eFileMask = ($scFileMask.replace("*.*","")).toupper()
				$eFileMask = ($eFileMask.replace("*.",""))
				$eFileMask = ($eFileMask.replace(".*",""))
				if (($eFileMask -ne "") -and (Test-Path ("$eOutput.*") )) {$eOutput += ("_" + $eFileMask)}
				$symScanPath += ((Join-Path -Path $PathToScan -ChildPath $scFileMask) + ";")
			}
		}

		if ($Description -ne "")
		{
			$FileDescription = $Description
		} else {
			$fdFileMask = [string]::join(";",$FileMask)
			if ($fdFileMask -contains ";") {
				$FileDescription = $PathToScan + " [" + $fdFileMask + "]"
			} else {
				$FileDescription = (Join-Path $PathToScan $fdFileMask)
			}
		}

		if ($Arguments -ne "")
		{
			$eOutput = $Output
			# Write-DiagProgress -Activity $LocalsCheckSym.ID_FileVersionInfo -Status $Description
			Loginfo "Activity: $($LocalsCheckSym.ID_FileVersionInfo), Status: $Description" White
			if(-not($SkipChksymExe))
			{
				$CommandToExecute = "cmd.exe /c $ChkSymExe $Arguments"
			}
			else
			{
				# Calling the method to implement the functionalities
				$Arguments = $Arguments.Substring(0,$Arguments.IndexOf("-O2")+4) +"$Output.CSV>$Output.TXT"
				Invoke-Expression "PSChkSym  $Arguments"
			}
		}
		else {
			# Write-DiagProgress -Activity $LocalsCheckSym.ID_FileVersionInfo -Status ($FileDescription)# + " Recursive: " + $Recursive)
			Loginfo "Activity: $($LocalsCheckSym.ID_FileVersionInfo), Status: $FileDescription" White
			if ($Recursive -eq $true) {
				$F = "-F2"
				$AFileExistOnFolder = (FileExistOnFolder -PathToScan $PathToScan -FileMask $scFileMask -Recursive)
			} else {
				$F = "-F"
				$AFileExistOnFolder = (FileExistOnFolder -PathToScan $PathToScan -FileMask $scFileMask)

			}
			if ($AFileExistOnFolder)
			{
				if(-not($SkipChksymExe))
				{
					$CommandToExecute = "cmd.exe /c $ChkSymExe $F `"$symScanPath`" -R -S -O2 `"$eOutput.CSV`" > `"$eOutput.TXT`""
				}
				else
				{
					# Calling the method to implement the functionalities
					if($F -eq "-F2")
					{
						PSChkSym -PathToScan $PathToScan -FileMask $FileMask -F2 -S -R -O2 "$eOutput.CSV>$eOutput.TXT"
					}
					else
					{
						PSChkSym -PathToScan $PathToScan -FileMask $FileMask -F -S -R -O2 "$eOutput.CSV>$eOutput.TXT"
					}
				}
			}
			else
			{
				Logwarn "Chksym did not run against path '$PathToScan' since there are no files with mask ($scFileMask) on system"
				$CommandToExecute = ""
			}
		}
		if ($CommandToExecute -ne "") {
			#RunCmD -commandToRun $CommandToExecute -sectionDescription "File Version Information (ChkSym)" -filesToCollect ("$eOutput.*") -fileDescription $FileDescription -BackgroundExecution
			$Commands = @(
				$CommandToExecute
			)
			RunCommands "$LogPrefix" $Commands -ThrowException:$False -ShowMessage:$True
		}
	}
	else {
		LogWarn "Chksym did not run against path '$PathToScan', because path does not exist"
	}
}

### Main ###
# Check if using $FolderName or $ChkSymRangeString
if (($null -ne $FolderName) -and ($null -ne $FileMask) -and ($null -ne $ChkSymSuffix)) {
	$OutputBase = $ChkSymOutFolder + $ComputerName + $ChkSymPrefix + $ChkSymSuffix
	$IsRecursive = ($Recursive.IsPresent)
	RunChkSym -PathToScan $FolderName -FileMask $FileMask -Output $OutputBase -Description $FileDescription -Recursive $IsRecursive -CallChksymExe $IsSkipChecksymExe
} else {
	[array] $RunChkSym = $null
	Foreach ($ChkSymRangeString in $ChkSymRange)
	{
		if ($ChkSymRangeString -eq "All")
		{
			$RunChkSym += "ProgramFilesSys", "Drivers", "System32DLL", "System32Exe", "System32SYS", "Spool", "iSCSI", "Process", "RunningDrivers", "Cluster"
		} else {
			$RunChkSym += $ChkSymRangeString
		}
	}

	switch ($RunChkSym)	{
		"ProgramFilesSys" {
			$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_ProgramFiles_SYS"
			RunChkSym -PathToScan "$Env:ProgramFiles" -FileMask "*.sys" -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			if (($Env:PROCESSOR_ARCHITECTURE -eq "AMD64") -or $Env:PROCESSOR_ARCHITECTURE -eq "IA64")  {
				$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_ProgramFilesx86_SYS"
				RunChkSym -PathToScan (${Env:ProgramFiles(x86)}) -FileMask "*.sys" -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			}
			}
		"Drivers" {
			$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_Drivers"
			RunChkSym -PathToScan "$Env:SystemRoot\System32\drivers" -FileMask "*.*" -Output $OutputBase -Recursive $false -SkipChksymExe $IsSkipChecksymExe
			}
		"System32DLL" {
			$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_System32_DLL"
			RunChkSym -PathToScan "$Env:SystemRoot\System32" -FileMask "*.DLL" -Output $OutputBase -Recursive $false -SkipChksymExe $IsSkipChecksymExe
			if (($Env:PROCESSOR_ARCHITECTURE -eq "AMD64") -or $Env:PROCESSOR_ARCHITECTURE -eq "IA64")  {
				$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_SysWOW64_DLL"
				RunChkSym -PathToScan "$Env:SystemRoot\SysWOW64" -FileMask "*.dll" -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			}
			}
		"System32Exe" {
			$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_System32_EXE"
			RunChkSym -PathToScan "$Env:SystemRoot\System32" -FileMask "*.EXE" -Output $OutputBase -Recursive $false -SkipChksymExe $IsSkipChecksymExe
			if (($Env:PROCESSOR_ARCHITECTURE -eq "AMD64") -or $Env:PROCESSOR_ARCHITECTURE -eq "IA64")  {
				$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_SysWOW64_EXE"
				RunChkSym -PathToScan "$Env:SystemRoot\SysWOW64" -FileMask "*.exe" -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			}
			}
		"System32SYS" {
			$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_System32_SYS"
			RunChkSym -PathToScan "$Env:SystemRoot\System32" -FileMask "*.SYS" -Output $OutputBase -Recursive $false -SkipChksymExe $IsSkipChecksymExe
			if (($Env:PROCESSOR_ARCHITECTURE -eq "AMD64") -or $Env:PROCESSOR_ARCHITECTURE -eq "IA64")  {
				$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_SysWOW64_SYS"
				RunChkSym -PathToScan "$Env:SystemRoot\SysWOW64" -FileMask "*.sys" -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			}
			}
		"Spool" {
			$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_PrintSpool"
			RunChkSym -PathToScan "$Env:SystemRoot\System32\Spool" -FileMask "*.*" -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
		}
		"Cluster" {
			$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_Cluster"
			RunChkSym -PathToScan "$Env:SystemRoot\Cluster" -FileMask "*.*" -Output $OutputBase -Recursive $false -SkipChksymExe $IsSkipChecksymExe
		}
		"iSCSI" {
			if(Test-Path "$Env:ProgramFiles\Microsoft iSNS Server" ) {
				$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_MS_iSNS"
				RunChkSym -PathToScan "$Env:ProgramFiles\Microsoft iSNS Server" -FileMask "*.*" -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			}
			$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_MS_iSCSI"
			RunChkSym -PathToScan "$Env:SystemRoot\System32" -FileMask "iscsi*.*" -Output $OutputBase -Recursive $false -SkipChksymExe $IsSkipChecksymExe
		}
		"Process" {
			$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_Process"
#we#		Get-Process |                                             Format-Table -Property "Handles","NPM","PM","WS","VM","CPU","Id","ProcessName","StartTime",@{ Label = "Running Time";Expression={(GetAgeDescription -TimeSpan (new-TimeSpan $_.StartTime))}} -AutoSize | Out-File "$OutputBase.txt" -Encoding "UTF8" -Width 200
			Get-Process | where-object  {$_.ProcessName -ne "idle"} | Format-Table -Property "Handles","NPM","PM","WS","VM","CPU","Id","ProcessName","StartTime",@{ Label = "Running Time";Expression={(GetAgeDescription -TimeSpan (new-TimeSpan $($_).StartTime))}} -AutoSize | Out-File "$OutputBase.txt" -Encoding "UTF8" -Width 200

			"--------------------------------" | Out-File "$OutputBase.txt" -Encoding "UTF8" -append
			tasklist -svc | Out-File "$OutputBase.txt" -Encoding "UTF8" -append -EA SilentlyContinue
			"--------------------------------" | Out-File "$OutputBase.txt" -Encoding "UTF8" -append
			RunChkSym -Output $OutputBase -Arguments "-P * -R -O2 `"$OutputBase.CSV`" >> `"$OutputBase.TXT`"" -Description "Running Processes" -SkipChksymExe $IsSkipChecksymExe
		}
		"RunningDrivers" {
			$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_RunningDrivers"
			RunChkSym -Output $OutputBase -Arguments "-D -R -S -O2 `"$OutputBase.CSV`" > `"$OutputBase.TXT`"" -Description "Running Drivers" -SkipChksymExe $IsSkipChecksymExe
		}
		"InetSrv" {
			$inetSrvPath = (join-path $env:systemroot "system32\inetsrv")
			$OutputBase = "$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_InetSrv"
			RunChkSym -PathToScan $inetSrvPath -FileMask ("*.exe","*.dll") -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
		}
		"Exchange" {
			$ExchangeFolder = GetExchangeInstallFolder
			if ($null -ne $ExchangeFolder){
				$OutputBase = "$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_Exchange"
				RunChkSym -PathToScan $ExchangeFolder -FileMask ("*.exe","*.dll") -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			} else {
				"Chksym did not run against Exchange since it could not find Exchange server installation folder" | WriteTo-StdOut -ShortFormat
			}
		}
		"DPM" {
			$DPMFolder = GetDPMInstallFolder
			If ($null -ne $DPMFolder)
			{
				$DPMFolder = Join-Path $DPMFolder "bin"
				$OutputBase= "$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_DPM"
				RunChkSym -PathToScan $DPMFolder -FileMask("*.exe","*.dll") -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			} else {
				"Chksym did not run against DPM since it could not find the DPM installation folder" | WriteTo-StdOut -ShortFormat
			}
		}
		"WinSxsDLL" {
			$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_WinSxS_DLL"
			RunChkSym -PathToScan "$Env:SystemRoot\WinSxS" -FileMask "*.DLL" -Output $OutputBase -Recursive $True -SkipChksymExe $IsSkipChecksymExe
			}
		"WinSxsEXE" {
			$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_WinSxS_EXE"
			RunChkSym -PathToScan "$Env:SystemRoot\WinSxS" -FileMask "*.EXE" -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			}
		"WinSxsSYS" {
			$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_WinSxS_SYS"
			RunChkSym -PathToScan "$Env:SystemRoot\WinSxS" -FileMask "*.SYS" -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			}
		"RefAssmDLL" {
			$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_RefAssm_DLL"
			RunChkSym -PathToScan "$Env:programfiles\Reference Assemblies" -FileMask "*.DLL" -Output $OutputBase -Recursive $true -SkipChksymExe $IsSkipChecksymExe
			}
		"DotNETDLL" {
			$OutputBase="$ChkSymOutFolder$ComputerName$ChkSymPrefix" + "_DotNET_DLL"
			RunChkSym -PathToScan "$Env:SystemRoot\Microsoft.NET" -FileMask "*.DLL" -Output $OutputBase -Recursive $True -SkipChksymExe $IsSkipChecksymExe
			}
	}
}
# SIG # Begin signature block
# MIIoPAYJKoZIhvcNAQcCoIIoLTCCKCkCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAvR8CbVVsoXIhG
# rqjW6/EjCnmJT9mzSuJyT0BvFI4pGKCCDYUwggYDMIID66ADAgECAhMzAAADri01
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
# cVZOSEXAQsmbdlsKgEhr/Xmfwb1tbWrJUnMTDXpQzTGCGg0wghoJAgEBMIGVMH4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01p
# Y3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTECEzMAAAOuLTVRyFOPVR0AAAAA
# A64wDQYJYIZIAWUDBAIBBQCgga4wGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQw
# HAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIA3P
# PMtKuePL/WcJHUTtXiJpeuBq5Ou0VpHQvm3QXZWnMEIGCisGAQQBgjcCAQwxNDAy
# oBSAEgBNAGkAYwByAG8AcwBvAGYAdKEagBhodHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20wDQYJKoZIhvcNAQEBBQAEggEARTUB4VBXumXCyCUr28Uk3DXXJ2+Czaupiz8g
# Iewr8w3gWp3A5bWM7xJnDn98lxSgNeY0EevQrqN0KmAJ9HOT8vk5IsbQazV/4VSl
# ZPffsbg5+lTcuM+nxYQsTGWKH/k9bpMLllVdlQyMCZohXhn7Ds5owmT0m9Racz9G
# trkfPdvj4r8hzCfmCHetCVDAxGLGQxRQyzSNo3edXtHqzD4yLh49BbQQ4ToywA6y
# 2+ldylfx7OSSIqIEygFVxPKS/knX2wUH73LWYyp5ETUQnLhBkKIV3eYmJBEYuClZ
# gmkYMordKKNmMuifT4YQSXJhjKSTU7KHUNHkmqWpMrxGsthW06GCF5cwgheTBgor
# BgEEAYI3AwMBMYIXgzCCF38GCSqGSIb3DQEHAqCCF3AwghdsAgEDMQ8wDQYJYIZI
# AWUDBAIBBQAwggFSBgsqhkiG9w0BCRABBKCCAUEEggE9MIIBOQIBAQYKKwYBBAGE
# WQoDATAxMA0GCWCGSAFlAwQCAQUABCDvsFbYwDAT8AQiqG9ao2SmSMiokkdEF1HA
# rCeK3qMuBQIGZc4Fup2XGBMyMDI0MDIyMDEyMTcwMi4zNzVaMASAAgH0oIHRpIHO
# MIHLMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQL
# ExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxk
# IFRTUyBFU046QTAwMC0wNUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFNlcnZpY2WgghHtMIIHIDCCBQigAwIBAgITMwAAAevgGGy1tu847QAB
# AAAB6zANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAx
# MDAeFw0yMzEyMDYxODQ1MzRaFw0yNTAzMDUxODQ1MzRaMIHLMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1l
# cmljYSBPcGVyYXRpb25zMScwJQYDVQQLEx5uU2hpZWxkIFRTUyBFU046QTAwMC0w
# NUUwLUQ5NDcxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Uw
# ggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDBFWgh2lbgV3eJp01oqiaF
# BuYbNc7hSKmktvJ15NrB/DBboUow8WPOTPxbn7gcmIOGmwJkd+TyFx7KOnzrxnoB
# 3huvv91fZuUugIsKTnAvg2BU/nfN7Zzn9Kk1mpuJ27S6xUDH4odFiX51ICcKl6EG
# 4cxKgcDAinihT8xroJWVATL7p8bbfnwsc1pihZmcvIuYGnb1TY9tnpdChWr9EARu
# Co3TiRGjM2Lp4piT2lD5hnd3VaGTepNqyakpkCGV0+cK8Vu/HkIZdvy+z5EL3ojT
# dFLL5vJ9IAogWf3XAu3d7SpFaaoeix0e1q55AD94ZwDP+izqLadsBR3tzjq2RfrC
# NL+Tmi/jalRto/J6bh4fPhHETnDC78T1yfXUQdGtmJ/utI/ANxi7HV8gAPzid9TY
# jMPbYqG8y5xz+gI/SFyj+aKtHHWmKzEXPttXzAcexJ1EH7wbuiVk3sErPK9MLg1X
# b6hM5HIWA0jEAZhKEyd5hH2XMibzakbp2s2EJQWasQc4DMaF1EsQ1CzgClDYIYG6
# rUhudfI7k8L9KKCEufRbK5ldRYNAqddr/ySJfuZv3PS3+vtD6X6q1H4UOmjDKdjo
# W3qs7JRMZmH9fkFkMzb6YSzr6eX1LoYm3PrO1Jea43SYzlB3Tz84OvuVSV7NcidV
# tNqiZeWWpVjfavR+Jj/JOQIDAQABo4IBSTCCAUUwHQYDVR0OBBYEFHSeBazWVcxu
# 4qT9O5jT2B+qAerhMB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8G
# A1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMv
# Y3JsL01pY3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBs
# BggrBgEFBQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0
# LmNvbS9wa2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUy
# MDIwMTAoMSkuY3J0MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUH
# AwgwDgYDVR0PAQH/BAQDAgeAMA0GCSqGSIb3DQEBCwUAA4ICAQCDdN8voPd8C+VW
# ZP3+W87c/QbdbWK0sOt9Z4kEOWng7Kmh+WD2LnPJTJKIEaxniOct9wMgJ8yQywR8
# WHgDOvbwqdqsLUaM4NrertI6FI9rhjheaKxNNnBZzHZLDwlkL9vCEDe9Rc0dGSVd
# 5Bg3CWknV3uvVau14F55ESTWIBNaQS9Cpo2Opz3cRgAYVfaLFGbArNcRvSWvSUbe
# I2IDqRxC4xBbRiNQ+1qHXDCPn0hGsXfL+ynDZncCfszNrlgZT24XghvTzYMHcXio
# LVYo/2Hkyow6dI7uULJbKxLX8wHhsiwriXIDCnjLVsG0E5bR82QgcseEhxbU2d1R
# VHcQtkUE7W9zxZqZ6/jPmaojZgXQO33XjxOHYYVa/BXcIuu8SMzPjjAAbujwTawp
# azLBv997LRB0ZObNckJYyQQpETSflN36jW+z7R/nGyJqRZ3HtZ1lXW1f6zECAeP+
# 9dy6nmcCrVcOqbQHX7Zr8WPcghHJAADlm5ExPh5xi1tNRk+i6F2a9SpTeQnZXP50
# w+JoTxISQq7vBij2nitAsSLaVeMqoPi+NXlTUNZ2NdtbFr6Iir9ZK9ufaz3FxfvD
# Zo365vLOozmQOe/Z+pu4vY5zPmtNiVIcQnFy7JZOiZVDI5bIdwQRai2quHKJ6ltU
# dsi3HjNnieuE72fT4eWhxtmnN5HYCDCCB3EwggVZoAMCAQICEzMAAAAVxedrngKb
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
# ELQdVTNYs6FwZvKhggNQMIICOAIBATCB+aGB0aSBzjCByzELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJp
# Y2EgT3BlcmF0aW9uczEnMCUGA1UECxMeblNoaWVsZCBUU1MgRVNOOkEwMDAtMDVF
# MC1EOTQ3MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNloiMK
# AQEwBwYFKw4DAhoDFQCABol1u1wwwYgUtUowMnqYvbul3qCBgzCBgKR+MHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBCwUAAgUA6X5ypjAi
# GA8yMDI0MDIyMDAwMzY1NFoYDzIwMjQwMjIxMDAzNjU0WjB3MD0GCisGAQQBhFkK
# BAExLzAtMAoCBQDpfnKmAgEAMAoCAQACAhuPAgH/MAcCAQACAhLTMAoCBQDpf8Qm
# AgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEAAgMHoSCh
# CjAIAgEAAgMBhqAwDQYJKoZIhvcNAQELBQADggEBAJdEwt4I+Zb1EWFtkSN3d6aU
# jw8PZwdXP8kP1PZ/k+4B/q59gq6i989T+xrszxWaBdvXHmFuJs1jse/3Lisai4vL
# GotBQ6aHR7HGw+EkJtxKf1sFzH9OPc7Ag+8enJ4mmgmvQ4tw9hsgtnZz9h0dMj8g
# w4/E19o4iAaXsVIOmMWeS9ujlgeFZxqPpDrjs40CKx/7RgjxXErHs898wYrFNOOI
# c9CT1iyr+DDADPTCI/fK1c1NXG5YRC9Z1a32BJeFEB+tVQ8cPWHINl7ZpLmQAdJq
# w7/X1lacq8yf4WLJ6wiqeHoRQsshXHUfe7HmvUbSq79+4MB9QikBmkkNU6FPsIsx
# ggQNMIIECQIBATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAA
# AevgGGy1tu847QABAAAB6zANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkD
# MQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCAVeaexsJ191dBkITr1xTCp
# 0dU7RC9OuFodTZIIq7o9qDCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EIM63
# a75faQPhf8SBDTtk2DSUgIbdizXsz76h1JdhLCz4MIGYMIGApH4wfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAHr4BhstbbvOO0AAQAAAeswIgQgYzLP
# B6A03xqlxyuMg5gDUI5tlYUbwgT0+N2Mwbrer08wDQYJKoZIhvcNAQELBQAEggIA
# pos4qCeAwDupvBwNP8EOmy1JN2itZZPqDX/Sxjaq6iI81nuNIFKQ3CdFsxDavpIr
# yG3hbaAeH+piIDo0rqr8O5j7E0k4p/ny/ye4G0pnqfMKHxjYG0mYZSYODfGhzhVM
# sVm7fHL5FypglJq31fTd5Mx0HauJ4LEphz/3EGt9MWPLcrxbY28N3TFZ9RlnzoQL
# PmkrmdJUkCfFNrXhNxxOYmLRdtUIHUp/TwrK5wmjXXwYIOtfT9GFJo7sxDsahea6
# YN/KvK819PNOgx2/6fmSl1fUWrrk8NhhzS1+jzYNeXV5svZYeOrBzm5+O5S2lmqF
# WJD91SdPAfPCIfDxzwiFMsJ0ij0fFM+QghW2/7SPcMvcozv0ITfXVQW08Odqwkdn
# 2k9nTTEYvP1TiRH8Y36f0jUm4FN2lm5GnRliC+LqDIcnKZshYEY8UBh3rEBTCy/P
# B0UCIuCrLZkN8VCwEVHM6+Z02Zdn+FyH+qEq+g0kLnycuQTcI4h8xAnmLnDtY8ve
# UzRhmFXHKfmHcrkShR3uetdenLqKobdU3pMHFwAw1QsU0Zck79cj6AJB7YW7OnqY
# 1ZxWTUeqFpQr93maaLRYKMwDB2t8TDawDqQh11plYEXVS7CDQ9HoQjxNWoRe2Ptm
# 6yluV6YwVkQSLEpUfbpXH/9L/nXylwUNma+MkP4kL54=
# SIG # End signature block
