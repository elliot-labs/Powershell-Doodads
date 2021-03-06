<#
.SYNOPSIS
    Copies a column to another CSV file.
.DESCRIPTION
    Copies a column from a source CSV file to a destination CSV file.
    The script check the source and destination for compatibility before copying the column to the destination.
    The script will return $true for success and $false for failure.
    If there is a failure, the system will write an error to the console and return $false.
.PARAMETER SourceCSVPath
    The path to the source CSV file. Wild cards are not permitted.
.PARAMETER DestinationCSVPath
    The path to the destination CSV file. Wild cards are not permitted.
.PARAMETER ColumnName
    Name of the column in the source file to copy to the destination file.
.EXAMPLE
    PS C:\> Copy-CSVColumn.ps1 -SourceCSVPath .\Source.csv -DestinationCSVPath .\Destination.csv -ColumnName "Foo Bar"
    Copies the column named "Foo Bar" from the source.csv file and makes a new column in the file named Destination.csv with the same values and column name that were present in the source file.
.INPUTS
    System.String
    You can pipe all parameters. On the back end the system looks for Source, Destination and Name parameters in addition to the parameters that are documented.
.OUTPUTS
    Copy-CSVColumn returns $true if execution is successful, and $false if it is unsuccessful.
.NOTES
    You must ensure that the destination file has an equal amount or more rows than the source file.
    The script also checks if the column name in the source exists. If it doesn't it will write an error and return false.
    If the column already exists in the destination, it will write an error and return false.
    Otherwise the script will halt and return $false.
.LINK
    https://github.com/elliot-labs/PowerShell-Doodads
#>

# Accept command line parameters.
[OutputType([String])]
param(
    # Specifies a path to a location.
    [Parameter(Mandatory = $true,
        Position = 0,
        ParameterSetName = "CLI",
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = "Path to source CSV file.")]
    [Alias("PSPath","Source")]
    [ValidateNotNullOrEmpty()]
    [string]$SourceCSVPath,
    # Specifies a path to one or more locations.
    [Parameter(Mandatory = $true,
        Position = 1,
        ParameterSetName = "CLI",
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = "Path to destination CSV file.")]
    [Alias("Destination")]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationCSVPath,
    # Column name to copy to destination CSV file.
    [Parameter(Mandatory = $true,
        Position = 3,
        ParameterSetName = "CLI",
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = "Name of the column that will be copied over")]
    [Alias("Property","Name")]
    [ValidateNotNullOrEmpty()]
    [string]$ColumnName
)

# If the source or destination path is not valid, write an error and return false.
if (!(Test-Path -Path $SourceCSVPath)) {
    Write-Error -Message "A valid path must be specified for the source file!"
    return $false
} elseif (!(Test-Path -Path $DestinationCSVPath)) {
    Write-Error -Message "A valid path must be specified for the destination file!"
    return $false
}

# Import the CSV files into memory.
$SourceCSV = Import-Csv -Path $SourceCSVPath
$DestinationCSV = Import-Csv -Path $DestinationCSVPath

# If the source doesn't have the specified column or the destination already has it, write an error and return.
if ($SourceCSV.$ColumnName -eq $null) {
    Write-Error -Message "The source column does not exist!"
    return $false
} elseif ($DestinationCSV.$ColumnName -ne $null) {
    Write-Error -Message "The column already exists in the destination!"
    return $false
} 

# Add the column to be populated with data.
$DestinationCSV | Add-Member -MemberType NoteProperty -Name $ColumnName -Value $null

# Export the destination CSV with the new column name.
$DestinationCSV | Export-Csv -Path $DestinationCSVPath

# Re-import the Destination CSV with the new column name for easy manipulation.
$DestinationCSV = Import-Csv -Path $DestinationCSVPath

<#
For the future: Build a system that can make new rows to support a source that is larger than the destination.
Below is header isolation for a potential row generator. Header isolation is successful. Row creation is currently unsuccessful.

# Create a definition of the destination schema.
$DestinationCSVDefinition = (Get-Content -Path $DestinationCSVPath)[0,1]
if ($DestinationCSVDefinition[0] -cMatch "^#TYPE") {
    $DestinationCSVDefinition = $DestinationCSVDefinition[1]
} else {
    $DestinationCSVDefinition = $DestinationCSVDefinition[0]
}
$DestinationCSVDefinition = $DestinationCSVDefinition -split ","

#>

# Check to see if the destination can handle all of the rows of the source CSV and throw and error if it can't.
if ($SourceCSV.Count -gt $DestinationCSV.Count) {
    # Write an error to the console.
    Write-Error -Message "Cannot have a source file that has more rows than the destination file!"
    
    # Stop execution and return that execution was not successful.
    return $false
} else {
    # Loop through the source CSV file.
    for ($i = 0; $i -lt $SourceCSV.Count; $i++) {
        # Check if data exists, and if it doesn't set it to an empty string.
        if ($null -eq $SourceCSV[$i].$ColumnName) {
            $DestinationCSV[$i].$ColumnName = ""
        } else {
            # If there is data, set it to the data that is found.
            $DestinationCSV[$i].$ColumnName = $SourceCSV[$i].$ColumnName
        }
    }
    # Save in memory work to disk.
    $DestinationCSV | Export-Csv -Path $DestinationCSVPath

    # Stop execution and return that efforts were successful.
    return $true
}
