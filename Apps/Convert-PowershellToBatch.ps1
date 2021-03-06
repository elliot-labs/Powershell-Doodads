<#
.SYNOPSIS
This script converts PowerShell scripts to batch scripts to execute directly on systems.
.DESCRIPTION
This script takes the input PowerShell script and exports it as a batch script that can be directly run on the system.
This script can be run on the CLI mode or as a GUI mode.
.PARAMETER LegacyVisuals
When this flag is specified, the user interface will render with the Windows 98 reminiscent visual styles of the classic theme.
This parameter is only useable when the UI is used.
This flag does nothing if used with the CLIMode flag.
.PARAMETER CLIMode
When this flag is set, the GUI will not be displayed and the other CLI arguments will be used for the required information.
.PARAMETER InputFile
The path to the file that will be used as the source for the outputted batch script.
Only used with the CLIMode flag. This parameter is required.
.PARAMETER OutputFile
The destination and file name that will be used when the source file has finished processing.
If this parameter is not specified, the same file path to the input file is used and the ".bat" file extension is added to the file.
This parameter is only used with the CLIMode flag.
.PARAMETER AdminMode
When this flag is specified a header will be added to the batch boot-strapper that checks to see fi the script is being run as admin.
This parameter is only used with the CLIMode flag.
.PARAMETER SelfDelete
When this flag is specified a line of code will be added to the end of the boot-strapper that will self delete the batch script.
This parameter is only used with the CLIMode flag.
.PARAMETER HideTerminal
When this flag is specified The launch parameter fo the PowerShell script is modified to include a parameter that disabled the terminal from being displayed.
This parameter is only used with the CLIMode flag.
.PARAMETER CLIArgument
Arguments to be included in the execution of the PowerShell code.
This parameter is only used with the CLIMode flag.
.EXAMPLE
Convert-PowerShellToBatch.ps1
This will run the converter in full GUI mode.

OUTPUT:
User interface with graphical options to configure the operation of this script.
.EXAMPLE
Convert-PowerShellToBatch.ps1 -CLIMode -InputFile "C:\Get-UserNAP.ps1"
This will disable GUI mode and take the inputted file and export it as a batch script with the same path and file name with ".bat" appended to it.
.EXAMPLE
Convert-PowerShellToBatch.ps1 -CLIMode -InputFile "C:\Get-UserNAP.ps1" -OutputFile "C:\Get-UserNAP.bat" -SelfDelete
This will disable GUI mode and take the inputted file and export it as a batch script that will self delete after execution has completed.
.NOTES
This tool is not needed for general use and should only be used when you know you need to change a PowerShell file into a self contained batch script.
.LINK
https://github.com/elliot-labs/PowerShell-Doodads
#>

# Add command line switch/flag support.
# Each parameter is detailed in the above help documentation.
param(
    # Parameters for GUI.
    [Parameter(ParameterSetName='GUI', Mandatory=$false)] [switch]$LegacyVisuals = $False,

    # Parameters for CLI.
    [Parameter(ParameterSetName='CLI', Position = 0, Mandatory=$true)] [switch]$CLIMode = $False,
    [Parameter(ParameterSetName='CLI', Position = 1, Mandatory=$true)] [string]$InputFile,
    [Parameter(ParameterSetName='CLI', Mandatory=$false)] [string]$OutputFile,
    [Parameter(ParameterSetName='CLI', Mandatory=$false)] [switch]$AdminMode = $False,
    [Parameter(ParameterSetName='CLI', Mandatory=$false)] [switch]$SelfDelete = $False,
    [Parameter(ParameterSetName='CLI', Mandatory=$false)] [switch]$HideTerminal = $False,
    [Parameter(ParameterSetName='CLI', Mandatory=$false)] [string]$CLIArgument = ""
)

# Import required libraries
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Enable pretty interface controls (by default)
# Windows 98 styles are ugly compared to today's standards
if (!$LegacyVisuals) {[System.Windows.Forms.Application]::EnableVisualStyles()}

# Command Line interface mode logic starts here.
Function Convert-File () {
    # Process the input path and update it to be the output path with modifications.
    if ($Script:OutputFile -eq "") {$Script:OutputFile = $Script:InputFile + ".bat"}

    # Set the Administrative permission header of the batch script.
    if ($AdminMode) {
        $AdminSubHeader = 'net session >nul 2>&1
if NOT %errorLevel% == 0 (
    echo Please run this script as an administrator.
    pause
    exit
)'
    } else {$AdminSubHeader = ''}

    # If the hide terminal option is specified, append the hide terminal option.
    if ($Script:HideTerminal) {$DisplayTerminalCLI = ' -WindowStyle Hidden'}

    # Code that will be added to the top of the converted script.
    $BatchHeader = "@echo off
color 0A
cls
cd /d %~dp0
set Script=`"%Temp%\%RANDOM%-%RANDOM%-%RANDOM%-%RANDOM%.ps1`"
$($AdminSubHeader)
("

    # Code that will be added at the bottom of the converted script.
    $BatchFooter = ") > %Script%
PowerShell -ExecutionPolicy Unrestricted$DisplayTerminalCLI -File %Script% $Script:CLIArgument
del %Script%"

    # Code that will be added for admin permissions checker.
    $AdminSubHeader = ':CheckAdmin
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Success: Administrative permissions confirmed.
) else (
    echo Please run script as administrator.
    pause
    exit
)
'

    # Create the top of the outputted script.
    $BatchHeader | Out-File -FilePath $Script:OutputFile -Encoding ASCII
    
    # Open the script to be converted and run a sequence of commands upon each line in order from top to bottom.
    Get-Content -Path $Script:InputFile | ForEach-Object {

        # Automatically comments out pipe characters in the current line.
        $fileLine = $_ -replace "\^", "^^"
        $fileLine = $fileLine -replace "\|", "^|"
        $fileLine = $fileLine -replace ">", "^>"
        $fileLine = $fileLine -replace "<", "^<"
        $fileLine = $fileLine -replace "%", "%%"
        $fileLine = $fileLine -replace "&", "^&"
        $fileLine = $fileLine -replace "\(", "^("
        $fileLine = $fileLine -replace "\)", "^)"
        $fileLine = $fileLine -replace '"', '^"'
        
        # If the line is blank then a blank line is generated for the batch file.
        if ($fileLine -match "^\s*$") {
            "echo." | Out-File -FilePath $Script:OutputFile -Append -Encoding ASCII

        # If the line is not blank then the below applies.
        } else {

            # Otherwise just convert the string to a batch export.
            "echo $fileLine" | Out-File -FilePath $Script:OutputFile -Append -Encoding ASCII            
        }
    }

    # Add the footer to the outputted batch file.
    $BatchFooter | Out-File -FilePath $Script:OutputFile -Append -Encoding ASCII

    # Add the self deleting module to the batch script.
    if ($Script:SelfDelete) {Out-File -FilePath $Script:OutputFile -InputObject "(goto) 2>nul & del `"%~f0`"" -Append -Encoding ASCII}

    # Only show the completed dialog if the script is not in CLI mode.
    if (!$Script:CLIMode) {[System.Windows.Forms.MessageBox]::Show("Recompile completed!", "Finished!")}
}

# Create a open file dialog that only accepts powershell scripts and set the script level variable to the results.
Function Show-ChangeInput {
    $InputFileGUI = New-Object System.Windows.Forms.OpenFileDialog
    $InputFileGUI.Filter = "PowerShell Script (*.ps1)|*.ps1"
    $GUIResult = $InputFileGUI.ShowDialog()
    if ($GUIResult -eq "OK") {
        $Script:InputFile = $InputFileGUI.FileName
    } else {
        $Script:InputFile = "Canceled"
    }
}

Function Show-ChangeOutput {
    $OutputFileGUI = New-Object System.Windows.Forms.SaveFileDialog
    $OutputFileGUI.Filter = "Batch Script (*.bat)|*.bat"
    $GUIResult = $OutputFileGUI.ShowDialog()
    if ($GUIResult -eq "OK") {
        $Script:OutputFile = $OutputFileGUI.FileName
    } else {
        $Script:OutputFile = "Canceled"
    }
}

# Starts the main interface
Function Show-MainUI () {
    # Initialize font setting
    $Label_Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
    $Argument_Label_Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Regular)
    $Form_Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Regular)

    # Create main form (window)
    $Form = New-Object System.Windows.Forms.Form 
    $Form.Text = "PowerShell 2 Batch"
    $Form.MaximizeBox = $false
    $Form.MinimizeBox = $false
    $Form.FormBorderStyle = "FixedSingle"
    $Form.Icon = [System.Drawing.SystemIcons]::Information
    $Form.Size = New-Object System.Drawing.Size(300, 380)
    $Form.StartPosition = "CenterScreen"
    $Form.Font = $Form_Font
    $Form.Topmost = $True

    # Input file current settings.
    $InputFile_Label = New-Object System.Windows.Forms.Label
    $InputFile_Label.Location = New-Object System.Drawing.Point(100, 0)
    $InputFile_Label.Size = New-Object System.Drawing.Size(184, 100)
    $InputFile_Label.BorderStyle = "FixedSingle"
    $InputFile_Label.TextAlign = "MiddleCenter"
    $InputFile_Label.Font = $Label_Font
    $InputFile_Label.Text = "Input File"

    # Output file current settings.
    $OutputFile_Label = New-Object System.Windows.Forms.Label
    $OutputFile_Label.Location = New-Object System.Drawing.Point(100, 101)
    $OutputFile_Label.Size = New-Object System.Drawing.Size(184, 100)
    $OutputFile_Label.BorderStyle = "FixedSingle"
    $OutputFile_Label.TextAlign = "MiddleCenter"
    $OutputFile_Label.Font = $Label_Font
    $OutputFile_Label.Text = "Output File"

    # Argument label.
    $Argument_Label = New-Object System.Windows.Forms.Label
    $Argument_Label.Location = New-Object System.Drawing.Point(0, 160)
    $Argument_Label.Size = New-Object System.Drawing.Size(100, 40)
    $Argument_Label.BorderStyle = "None"
    $Argument_Label.TextAlign = "BottomCenter"
    $Argument_Label.Font = $Argument_Label_Font
    $Argument_Label.Text = "CLI Arg(s):"

    # Add Input File Button
    $Input_Button = New-Object System.Windows.Forms.Button
    $Input_Button.Location = New-Object System.Drawing.Point(0, 0)
    $Input_Button.Size = New-Object System.Drawing.Size(100, 60)
    $Input_Button.Text = "Input File"

    # Add Output File Button
    $Output_Button = New-Object System.Windows.Forms.Button
    $Output_Button.Location = New-Object System.Drawing.Point(0, 100)
    $Output_Button.Size = New-Object System.Drawing.Size(100, 60)
    $Output_Button.Text = "Output File"

    # Argument TextBox
    $Argument_TextBox = New-Object System.Windows.Forms.TextBox
    $Argument_TextBox.Location = New-Object System.Drawing.Point(0, 200)
    $Argument_TextBox.Size = New-Object System.Drawing.Size(284, 10)

    # Yes Radio Button, checked by default
    $Admin_CheckBox = New-Object System.Windows.Forms.CheckBox
    $Admin_CheckBox.Location = New-Object System.Drawing.Point(5, 235)
    $Admin_CheckBox.size = New-Object System.Drawing.Size(140, 20)
    $Admin_CheckBox.Checked = $false 
    $Admin_CheckBox.Text = "Run as admin"

    # No Radio Button, not checked by default
    $HideWindow_CheckBox = New-Object System.Windows.Forms.CheckBox
    $HideWindow_CheckBox.Location = New-Object System.Drawing.Point(150, 235)
    $HideWindow_CheckBox.size = New-Object System.Drawing.Size(160, 20)
    $HideWindow_CheckBox.Checked = $false
    $HideWindow_CheckBox.Text = "Hide Console"

    # Yes Radio Button, checked by default
    $SelfDelete_CheckBox = New-Object System.Windows.Forms.CheckBox
    $SelfDelete_CheckBox.Location = New-Object System.Drawing.Point(5, 258)
    $SelfDelete_CheckBox.size = New-Object System.Drawing.Size(140, 20)
    $SelfDelete_CheckBox.Checked = $false 
    $SelfDelete_CheckBox.Text = "Self Delete"
    
    # Add Convert Button
    $Convert_Button = New-Object System.Windows.Forms.Button
    $Convert_Button.Location = New-Object System.Drawing.Point(0, 281)
    $Convert_Button.Size = New-Object System.Drawing.Size(284, 60)
    $Convert_Button.Text = "Convert PowerShell 2 Batch"

    # Add Button onClick event listener and logic
    $Convert_Button.Add_Click({
        $Script:CLIArgument = $Argument_TextBox.Text
        $Script:AdminMode = $Admin_CheckBox.Checked
        $Script:HideTerminal = $HideWindow_CheckBox.Checked
        $Script:SelfDelete = $SelfDelete_CheckBox.Checked
        Convert-File
    })
    $Input_Button.Add_Click({
        Show-ChangeInput
        $InputFile_Label.Text = "$Script:InputFile"
    })
    $Output_Button.Add_Click({
        Show-ChangeOutput
        $OutputFile_Label.Text = "$Script:OutputFile"
    })

    # Add the controls to the form for rendering
    $Form.Controls.Add($Input_Button)
    $Form.Controls.Add($Output_Button)
    $Form.Controls.Add($Argument_TextBox)
    $Form.Controls.Add($Admin_CheckBox)
    $Form.Controls.Add($SelfDelete_CheckBox)
    $Form.Controls.Add($HideWindow_CheckBox)
    $Form.Controls.Add($Convert_Button)
    $Form.Controls.Add($InputFile_Label)
    $Form.Controls.Add($OutputFile_Label)
    $Form.Controls.Add($Argument_Label)

    # Starts the visual rendering of the form
    $Form.ShowDialog() | Out-Null
}

if ($CLIMode) {
    Convert-File
} else {
    Show-MainUI
}
