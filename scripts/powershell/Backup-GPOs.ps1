<#
.SYNOPSIS
    Backs up all Group Policy Objects and keeps the last N backups.

.DESCRIPTION
    Each run goes into its own dated folder with an HTML report per GPO,
    so you can diff settings between runs. Meant to run as a scheduled
    task on a management server.

.EXAMPLE
    .\Backup-GPOs.ps1 -Destination \\nas01\backup\gpo -Keep 30
#>
#Requires -Modules GroupPolicy
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Destination,

    [ValidateRange(1, 365)]
    [int]$Keep = 14
)

$ErrorActionPreference = 'Stop'
$runDir = Join-Path $Destination (Get-Date -Format 'yyyy-MM-dd_HHmm')
$reportDir = Join-Path $runDir 'reports'
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null

$gpos = Get-GPO -All
$failed = 0

foreach ($gpo in $gpos) {
    try {
        Backup-GPO -Guid $gpo.Id -Path $runDir -Comment "Scheduled backup $(Get-Date -Format s)" | Out-Null
        $safeName = $gpo.DisplayName -replace '[\\/:*?"<>|]', '_'
        Get-GPOReport -Guid $gpo.Id -ReportType Html -Path (Join-Path $reportDir "$safeName.html")
    }
    catch {
        $failed++
        Write-Warning "Failed to back up '$($gpo.DisplayName)': $($_.Exception.Message)"
    }
}

# Simple index so a GUID folder can be mapped back to a name
$gpos | Select-Object DisplayName, Id, ModificationTime, GpoStatus |
    Export-Csv (Join-Path $runDir 'index.csv') -NoTypeInformation

Get-ChildItem $Destination -Directory |
    Sort-Object Name -Descending |
    Select-Object -Skip $Keep |
    Remove-Item -Recurse -Force

Write-Output "Backed up $($gpos.Count - $failed) of $($gpos.Count) GPOs to $runDir"
if ($failed) { exit 1 }
