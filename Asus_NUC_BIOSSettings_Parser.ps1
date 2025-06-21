param(
[switch]$Grid,
[string]$CSV,
[string]$TXT
)

If($TXT -ne $null)
	{

	}
	
If($CSV -ne $null)
	{

	}	

<#
If you want to use iSetupCfgWin64.exe and amigendrv64.sys from a blob storage:
1. Upload both files iSetupCfgWin64.exe and amigendrv64.sys on a blob storage or somewhere
2. Set path of iSetupCfgWin64.exe in variable iSetupCfg_URL
3. Set path of amigendrv64.sys in variable amigendrv64_URL
#>

$iSetupCfg_URL = ""
$amigendrv64_URL = ""

$iSetupCfg_URL = "https://stagrtdwpprddevices.blob.core.windows.net/nuc-asus/iSetupCfgWin64.exe"
$amigendrv64_URL = "https://stagrtdwpprddevices.blob.core.windows.net/nuc-asus/amigendrv64.sys"	

If($iSetupCfg_URL -eq "")
	{
		$iSetupCfg_URL = $iSetupCfg_URL_FromGitHub
	}
	
If($amigendrv64_URL -eq "")
	{
		$amigendrv64_URL = $amigendrv64_URL_FromGitHub
	}	

$ComputerName = $env:computername			
If($TXT -ne "")
	{
		$Exported_Config_BIOS = $TXT
	}	
Else
	{
		$Config_BIOS_folder = "C:\Windows\temp\Config_BIOS"
		If(!(test-path $Config_BIOS_folder)){new-item $Config_BIOS_folder -Type Directory -Force}		
		$iSetupCfg_OutFile = "$Config_BIOS_folder\iSetupCfgWin64.exe"
		If(!(test-path $iSetupCfg_OutFile))
			{
				Invoke-WebRequest -Uri $iSetupCfg_URL -OutFile $iSetupCfg_OutFile -UseBasicParsing
			}
				
		$amigendrv64_OutFile = "$Config_BIOS_folder\amigendrv64.sys"
		If(!(test-path $amigendrv64_OutFile))
			{
				Invoke-WebRequest -Uri $amigendrv64_URL -OutFile $amigendrv64_OutFile -UseBasicParsing
			}			
				
		Get-ChildItem -Recurse $Config_BIOS_folder | Unblock-File		
		$Exported_Config_BIOS = "C:\Windows\Temp\Config_BIOS\Config_BIOS_$ComputerName.txt"		
		& "C:\Windows\Temp\Config_BIOS\iSetupCfgWin64.exe" /o /s $Exported_Config_BIOS /b /q				
	}

# Read the BIOS configuration file 
$BIOS_Content = gc $Exported_Config_BIOS | Where {
    ($_ -notlike "*HIICrc32*") -and 
    ($_ -notlike "*Width*") -and 
    ($_ -notlike "*Token*") -and 
    ($_ -notlike "*Offset*=*") -and 
    ($_ -notlike "*BIOS Default*") -and 
    ($_ -notlike "*Help String*")
}

# Clean up the content
$BIOS_Content = $BIOS_Content.replace('// Move "*" to the desired Option', "")
$BIOS_Content = $BIOS_Content.replace('// Enabled = 1, Disabled = 0', "")
$BIOS_Content = $BIOS_Content.replace('<', "").replace('>', "")

# Initialize arrays
$blocks = @()
$currentBlock = @()
$BIOS_Settings = @()

# Parse the content
ForEach($line in $BIOS_Content) {
    If ($line.Trim() -eq "") {
        If ($currentBlock.Count -gt 0) {
            $blocks += ,@($currentBlock)
            $currentBlock = @()
        }
    } Else {
        $currentBlock += $line
    }
}

# Add the last block
If ($currentBlock.Count -gt 0) {
    $blocks += ,@($currentBlock)
}

# Process each block to extract BIOS settings
$BIOS_Settings = ForEach($block in $blocks) {
    $parameter = $null
    $map = $null
    $value = $null

    # Extract the "Setup Question" and "Map String" if present
    ForEach($line in $block) {
        If ($line -match "^Setup Question\s*=\s*(.+)$") {
            $parameter = $matches[1].Trim()
        }
        ElseIf ($line -match "^Map String\s*=\s*(.+)$") {
            $map = $matches[1].Trim()
        }
    }

    # Look for "Options=" line to find the value
    $optionsLine = $block | Where-Object { $_ -match "^Options\s*=" }
    If ($optionsLine) {
        # Extract selected option with a "*"
        If ($optionsLine -match "^Options\s*=\s*\*\[.+\](.+)$") {
            $value = $matches[1].Trim()
        } Else {
            # Get parameters for the selected option
            $selectedOptionLine = $block | Where-Object { $_ -match "^\s*\*" }
            If ($selectedOptionLine -match "\*\s*\[(.+?)\](.+)$") {
                $value = $matches[2].Trim()
            }
        }
    } Else {
		# Get options with "Value=" line 
        ForEach ($line in $block) {
            If ($line -match "^Value\s*=\s*(.+)$") {
                $value = $matches[1].Trim()
            }
        }
    }

    # Create an object with extracted information
    [PSCustomObject]@{
        Parameter = $parameter
        Map       = $map
        Value     = $value
    }
}


If(($Grid) -or (($CSV -eq "") -and (!($Grid))))
	{
		$BIOS_Settings | out-gridview		
	}
	
If($CSV -ne "")
	{
		$CSV_FileName = "Config_BIOS_$ComputerName.csv"
		$BIOS_Settings | export-csv "$CSV\$CSV_FileName" -NoTypeInformation
	}	