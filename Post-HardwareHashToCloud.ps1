#------------------------
# Author: C Doyle
# Date Created: 2023, June 07
# Description: Create a hardware hash for device and send to cloud storage. This is used to enroll device to Windows AutoPilot.
#
# Version 2 - 2023 Jun 08 - Added -Force to download commands so script doesn't get stopped by user prompt.
# Version 3.0 - 2023 Jun 09 - Added hostname collection to easily identify the device quickly.
# Version 3.1 - 2023 Jun 09 - Added comments to script to better describe the functions of the code blocks.
# Version 3.2 - 2023 Jun 20 - Added -UseBasicParsing perameter to http request to avoid using IE as a dependency. (Which was creating an error when running from OOBE)
#------------------------

#Insert URL for PowerAutomate Flow here:
$url = "https://prod-152.westeurope.logic.azure.com:443/workflows/965ff1adefbc45cab48ba4abec495fee/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=TxMvCAasUR8pT8KjPgkDyb0JGnisykz6qQ73tLcQtfk"

#Microsoft script to create csv file with hardware hash in it.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  # Included an if statement to create the HWID directory if it doesn't already exist.
if(-not(Test-Path -Path "C:\HWID")) {
    New-Item -Type Directory -Path "C:\HWID"
}
Set-Location -Path "C:\HWID"
$env:Path += ";C:\Program Files\WindowsPowerShell\Scripts"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force
Install-Script -Name Get-WindowsAutopilotInfo -Force
Get-WindowsAutopilotInfo -OutputFile AutopilotHWID.csv

#Insert csv file path.
$csvFilePath = 'C:\HWID\AutopilotHWID.csv'

# Creates function to CSV file contents
function Read-CSVFile {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType 'Leaf'})]
        [string]$FilePath
    )

    $lines = Get-Content -Path $FilePath
    return $lines
}

# Calls Read-CSVFile instruction
$lines = Read-CSVFile -FilePath $csvFilePath

# Skip the header line in the CSV
$devinfo = $lines[1]

# Print 2nd line of file
#Write-Host $devinfo

# Split the 2nd line into fields
$fields = @()
$fields += $devinfo.Split(',')

# Print fields from line 2
#Write-Host $fields[0]
#Write-Host $fields[1]
#Write-Host $fields[2]

# Define Variables
$deviceSerialNumber = $fields[0]
$windowsProductID = $fields[1]
$hardwareHash = $fields[2]

$devHostname = hostname


# Define the body of the POST request
$body = @{
    "serialNumber" = $deviceSerialNumber
    "productKey" = $windowsProductID
    "hardwareHash" = $hardwareHash
    "devHostname" = $devHostname
    "other" = "Intune test"
} | ConvertTo-Json


# Send the POST request
$response = Invoke-WebRequest -UseBasicParsing -Uri $url -Method Post -Body $body -ContentType "application/json"

# Check the status code
if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
    Write-Output "Request was successful, status code: $($response.StatusCode)"
    Write-Output "Everything worked! You're good to go."
} else {
    Write-Output "Request failed, status code: $($response.StatusCode)"
    Write-Output "Error sending information to cloud."
}

# Change directory back to where this script was run from
Set-Location $PSScriptRoot