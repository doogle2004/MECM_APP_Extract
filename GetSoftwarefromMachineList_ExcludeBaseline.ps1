<#
.SYNOPSIS
    Detect non-standard applications across devices using
    MECM hardware inventory only (no client connection required).

.DESCRIPTION
    Queries:
        SMS_G_System_ADD_REMOVE_PROGRAMS
        SMS_G_System_ADD_REMOVE_PROGRAMS_64
#>

# -----------------------------
# User Variables
# -----------------------------
$CsvPath = "C:\Users\C4-PAM-CNFG-Project\Desktop\Hardware_ReFresh.csv"     # Path to machine list
$SiteCode = "CP2"                        # SCCM Site Code
$ProviderMachineName = "VMC-P-MECM01,"    # SCCM Site Server
$OutputPath = "C:\Users\C4-PAM-CNFG-Project\Desktop\AppAudit"         # Output folder

If (!(Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath | Out-Null }

# Load ConfigMgr module
Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
Set-Location "$SiteCode`:"

# Import devices
$Devices = Import-Csv $CsvPath
$BaselineDevice = $Devices[0].ComputerName

# -----------------------------
# Function: Get apps from MECM inventory (NO CLIENT CONNECT)
# -----------------------------
function Get-MECMApps {
    param([string]$ComputerName)

    $Device = Get-CMDevice -Name $ComputerName -Fast
    if (-not $Device) { return @() }

    $RID = $Device.ResourceID

    # Query hardware inventory classes from MECM database
    $Apps32 = Get-WmiObject -Namespace "root\SMS\site_$SiteCode" `
              -Class SMS_G_System_ADD_REMOVE_PROGRAMS `
              -Filter "ResourceID = $RID"

    $Apps64 = Get-WmiObject -Namespace "root\SMS\site_$SiteCode" `
              -Class SMS_G_System_ADD_REMOVE_PROGRAMS_64 `
              -Filter "ResourceID = $RID"

    # Merge + clean
    $All = @($Apps32.DisplayName + $Apps64.DisplayName) |
           Where-Object { $_ -and $_.Trim() -ne "" } |
           Sort-Object -Unique

    return $All
}

# -----------------------------
# Baseline applications
# -----------------------------
Write-Host "Building baseline from $BaselineDevice" -ForegroundColor Cyan
$BaselineApps = Get-MECMApps $BaselineDevice

# -----------------------------
# Compare remaining devices
# -----------------------------
$Detailed = @()
$Summary = @{}

foreach ($Entry in $Devices[1..$Devices.Count]) {

    $Name = $Entry.ComputerName
    Write-Host "Comparing $Name..." -ForegroundColor Yellow

    $Apps = Get-MECMApps $Name

    # Differences only
    $Diff = Compare-Object -ReferenceObject $BaselineApps -DifferenceObject $Apps -PassThru |
            Where-Object { $_ -notin $BaselineApps }

    foreach ($App in $Diff) {

        $Detailed += [PSCustomObject]@{
            ComputerName = $Name
            Application  = $App
        }

        # Update summary
        if ($Summary.ContainsKey($App)) { $Summary[$App]++ }
        else { $Summary[$App] = 1 }
    }
}

# -----------------------------
# Export reports
# -----------------------------
$Detailed | Export-Csv "$OutputPath\DetailedApps.csv" -NoTypeInformation

$Summary.GetEnumerator() |
    Sort-Object Value -Descending |
    ForEach-Object {
        [PSCustomObject]@{
            Application = $_.Key
            Count       = $_.Value
        }
    } |
    Export-Csv "$OutputPath\SummaryApps.csv" -NoTypeInformation

Write-Host "Done. Reports saved to $OutputPath" -ForegroundColor Green