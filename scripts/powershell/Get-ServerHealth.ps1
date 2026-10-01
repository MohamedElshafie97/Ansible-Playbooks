<#
.SYNOPSIS
    Health snapshot for one or more Windows servers.

.DESCRIPTION
    Collects uptime, CPU, memory, disk usage, stopped automatic services,
    pending reboot state and the last installed update over CIM (WinRM).
    Returns objects, so the output can be piped to Format-Table,
    Export-Csv or ConvertTo-Html.

.PARAMETER ComputerName
    Servers to check. Defaults to the local machine.

.PARAMETER DiskWarnPercent
    Disk usage that marks a server as Warning. Default 85.

.EXAMPLE
    .\Get-ServerHealth.ps1 -ComputerName APP01, FS01 | Format-Table -AutoSize

.EXAMPLE
    Get-Content .\servers.txt | .\Get-ServerHealth.ps1 | Export-Csv health.csv -NoTypeInformation
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline)]
    [string[]]$ComputerName = $env:COMPUTERNAME,

    [ValidateRange(1, 100)]
    [int]$DiskWarnPercent = 85
)

begin {
    $ignoredServices = 'gupdate|edgeupdate|sppsvc|RemoteRegistry|MapsBroker|CDPSvc|tiledatamodelsvc|WbioSrvc'
}

process {
    foreach ($computer in $ComputerName) {
        $session = $null
        try {
            $session = New-CimSession -ComputerName $computer -ErrorAction Stop

            $os   = Get-CimInstance -CimSession $session Win32_OperatingSystem
            $cpu  = (Get-CimInstance -CimSession $session Win32_Processor |
                     Measure-Object -Property LoadPercentage -Average).Average
            $disks = Get-CimInstance -CimSession $session Win32_LogicalDisk -Filter 'DriveType=3' |
                     ForEach-Object {
                         [pscustomobject]@{
                             Drive   = $_.DeviceID
                             UsedPct = [math]::Round((1 - $_.FreeSpace / $_.Size) * 100)
                             FreeGB  = [math]::Round($_.FreeSpace / 1GB, 1)
                         }
                     }
            $stopped = Get-CimInstance -CimSession $session Win32_Service -Filter "StartMode='Auto' AND State<>'Running'" |
                       Where-Object Name -notmatch $ignoredServices |
                       Select-Object -ExpandProperty Name

            $pendingReboot = Invoke-Command -ComputerName $computer -ScriptBlock {
                (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
                (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or
                ($null -ne (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue))
            }

            $lastUpdate = Get-CimInstance -CimSession $session Win32_QuickFixEngineering |
                          Where-Object InstalledOn |
                          Sort-Object InstalledOn -Descending |
                          Select-Object -First 1

            $memPct = [math]::Round((1 - $os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100)
            $fullDisks = $disks | Where-Object UsedPct -ge $DiskWarnPercent

            $status = 'OK'
            if ($fullDisks -or $stopped -or $memPct -ge 90) { $status = 'Warning' }

            [pscustomobject]@{
                Computer        = $computer
                Status          = $status
                OS              = $os.Caption -replace 'Microsoft ', ''
                UptimeDays      = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalDays, 1)
                CpuPct          = [int]$cpu
                MemPct          = $memPct
                Disks           = ($disks | ForEach-Object { "$($_.Drive) $($_.UsedPct)%" }) -join ', '
                StoppedServices = $stopped -join ', '
                PendingReboot   = [bool]$pendingReboot
                LastUpdate      = if ($lastUpdate) { $lastUpdate.InstalledOn.ToString('yyyy-MM-dd') } else { 'unknown' }
            }
        }
        catch {
            [pscustomobject]@{
                Computer = $computer
                Status   = 'Unreachable'
                OS       = $_.Exception.Message
            }
        }
        finally {
            if ($session) { Remove-CimSession $session }
        }
    }
}
