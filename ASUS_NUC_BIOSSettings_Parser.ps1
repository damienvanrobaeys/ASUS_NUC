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

$iSetupCfg_URL_FromGitHub = "https://github.com/damienvanrobaeys/Intel_NUC/blob/main/iSetupCfgWin64.exe"
$amigendrv64_URL_FromGitHub = "https://github.com/damienvanrobaeys/Intel_NUC/blob/main/amigendrv64.sys"

<#
If you want to use iSetupCfgWin64.exe and amigendrv64.sys from a blob storage:
1. Upload both files iSetupCfgWin64.exe and amigendrv64.sys on a blob storage or somewhere
2. Set path of iSetupCfgWin64.exe in variable iSetupCfg_URL
3. Set path of amigendrv64.sys in variable amigendrv64_URL
#>

$iSetupCfg_URL = ""
$amigendrv64_URL = ""

If($iSetupCfg_URL -eq "")
	{
		$iSetupCfg_URL = $iSetupCfg_URL_FromGitHub
	}
	
If($amigendrv64_URL -eq "")
	{
		$amigendrv64_URL = $amigendrv64_URL_FromGitHub
	}	

$ComputerName = $env:computername			
If($TXT -ne $null)
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

$BIOS_Content = gc $Exported_Config_BIOS| Where {(($_ -like "*=*") -and ($_ -notlike "*Help String*")`
-and ($_ -notlike "*Token*") -and ($_ -notlike "*Offset*=*")`
-and ($_ -notlike "*Width*") -and ($_ -notlike "*BIOS Default*")`
-and ($_ -notlike "*HIICrc32*"))} 
$BIOS_Content = $BIOS_Content.replace('// Move "*" to the desired Option',"").replace('// Enabled = 1, Disabled = 0',"").replace('*',"").replace('<',"").replace('>',"")    

$BIOS_Settings = @()
For($i = 0; $i -lt $BIOS_Content.Count; $i += 3){
    $question = $BIOS_Content[$i] -replace 'Question : ', ''
    $map = $BIOS_Content[$i + 1] -replace 'Map : ', ''
    $value = $BIOS_Content[$i + 2] -replace 'Value : ', ''

	$question = ($question.split("="))[1]
	$map = ($map.split("="))[1]
	$value = ($value.split("="))[1]

    $item = [PSCustomObject]@{
        Setting = $question
        Map = $map
        Value = $value
    }
    $BIOS_Settings += $item
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