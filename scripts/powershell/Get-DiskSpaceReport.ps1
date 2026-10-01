<#
.SYNOPSIS
    Disk space report across servers, with optional email when anything is low.

.EXAMPLE
    .\Get-DiskSpaceReport.ps1 -ComputerName (Get-Content servers.txt) -WarnPercent 85 |
        Export-Csv disks.csv -NoTypeInformation

.EXAMPLE
    .\Get-DiskSpaceReport.ps1 -ComputerName APP01, FS01 -SmtpServer mail.lab.local -To it@lab.local
#>
[CmdletBinding()]
param(
    [string[]]$ComputerName = $env:COMPUTERNAME,
    [ValidateRange(1, 100)]
    [int]$WarnPercent = 85,
    [string]$SmtpServer,
    [string]$To,
    [string]$From = "disk-report@$env:USERDNSDOMAIN"
)

$results = foreach ($computer in $ComputerName) {
    try {
        Get-CimInstance Win32_LogicalDisk -ComputerName $computer -Filter 'DriveType=3' -ErrorAction Stop |
            ForEach-Object {
                $usedPct = [math]::Round((1 - $_.FreeSpace / $_.Size) * 100, 1)
                [pscustomobject]@{
                    Computer = $computer
                    Drive    = $_.DeviceID
                    Label    = $_.VolumeName
                    SizeGB   = [math]::Round($_.Size / 1GB, 1)
                    FreeGB   = [math]::Round($_.FreeSpace / 1GB, 1)
                    UsedPct  = $usedPct
                    Status   = if ($usedPct -ge $WarnPercent) { 'LOW' } else { 'OK' }
                }
            }
    }
    catch {
        [pscustomobject]@{ Computer = $computer; Drive = '-'; Status = "ERROR: $($_.Exception.Message)" }
    }
}

$results | Sort-Object UsedPct -Descending

$problems = $results | Where-Object Status -ne 'OK'
if ($problems -and $SmtpServer -and $To) {
    $body = $problems | ConvertTo-Html -Property Computer, Drive, Label, SizeGB, FreeGB, UsedPct, Status `
        -PreContent "<p>Drives above $WarnPercent% or unreachable servers:</p>" | Out-String
    Send-MailMessage -SmtpServer $SmtpServer -To $To -From $From `
        -Subject "Disk space warning: $(@($problems).Count) drive(s)" -Body $body -BodyAsHtml
}
