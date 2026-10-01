<#
.SYNOPSIS
    Starts automatic services that are stopped, with a retry limit.

.DESCRIPTION
    Intended for a scheduled task every few minutes. Writes to the
    Application event log under source "ServiceWatchdog" so the actions
    show up in whatever already collects event logs.

.PARAMETER Name
    Services to watch. If omitted, every service with StartMode Auto is
    checked except a known list of ones that stop on their own.

.EXAMPLE
    .\Start-StoppedServices.ps1 -Name W3SVC, MSSQLSERVER, SQLSERVERAGENT
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string[]]$Name,
    [int]$Retries = 2,
    [int]$WaitSeconds = 15
)

$source = 'ServiceWatchdog'
if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
    New-EventLog -LogName Application -Source $source
}

$ignore = 'gupdate|edgeupdate|sppsvc|RemoteRegistry|MapsBroker|CDPSvc|tiledatamodelsvc|WbioSrvc|TrustedInstaller'

$services = if ($Name) {
    Get-Service -Name $Name
} else {
    Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State<>'Running'" |
        Where-Object Name -notmatch $ignore |
        ForEach-Object { Get-Service -Name $_.Name }
}

foreach ($svc in $services | Where-Object Status -ne 'Running') {
    if (-not $PSCmdlet.ShouldProcess($svc.Name, 'Start service')) { continue }

    $ok = $false
    for ($i = 1; $i -le $Retries -and -not $ok; $i++) {
        try {
            Start-Service -Name $svc.Name -ErrorAction Stop
            $svc.WaitForStatus('Running', [timespan]::FromSeconds($WaitSeconds))
            $ok = $true
        }
        catch {
            Start-Sleep -Seconds 5
        }
    }

    if ($ok) {
        Write-EventLog -LogName Application -Source $source -EventId 1000 -EntryType Warning `
            -Message "$($svc.Name) was stopped and has been started."
        Write-Output "$($svc.Name): started"
    } else {
        Write-EventLog -LogName Application -Source $source -EventId 1001 -EntryType Error `
            -Message "$($svc.Name) is stopped and could not be started after $Retries attempt(s)."
        Write-Output "$($svc.Name): FAILED"
    }
}
