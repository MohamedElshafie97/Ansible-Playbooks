<#
.SYNOPSIS
    Reports whether servers are waiting for a reboot, and why.

.EXAMPLE
    .\Test-PendingReboot.ps1 -ComputerName (Get-ADComputer -Filter 'OperatingSystem -like "*Server*"').Name |
        Where-Object PendingReboot
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline)]
    [string[]]$ComputerName = $env:COMPUTERNAME
)

process {
    foreach ($computer in $ComputerName) {
        try {
            Invoke-Command -ComputerName $computer -ErrorAction Stop -ScriptBlock {
                $reasons = @()
                if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
                    $reasons += 'CBS'
                }
                if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
                    $reasons += 'WindowsUpdate'
                }
                $pfr = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
                if ($pfr.PendingFileRenameOperations) { $reasons += 'FileRename' }

                $active  = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName').ComputerName
                $pending = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName').ComputerName
                if ($active -ne $pending) { $reasons += 'ComputerRename' }

                try {
                    $ccm = Invoke-CimMethod -Namespace root\ccm\ClientSDK -ClassName CCM_ClientUtilities -MethodName DetermineIfRebootPending -ErrorAction Stop
                    if ($ccm.RebootPending -or $ccm.IsHardRebootPending) { $reasons += 'ConfigMgr' }
                } catch { }

                [pscustomobject]@{
                    LastBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
                    Reasons  = $reasons
                }
            } | ForEach-Object {
                [pscustomobject]@{
                    Computer      = $computer
                    PendingReboot = $_.Reasons.Count -gt 0
                    Reasons       = $_.Reasons -join ', '
                    LastBoot      = $_.LastBoot
                }
            }
        }
        catch {
            [pscustomobject]@{ Computer = $computer; PendingReboot = $null; Reasons = "ERROR: $($_.Exception.Message)" }
        }
    }
}
