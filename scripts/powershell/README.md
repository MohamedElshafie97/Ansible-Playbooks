# PowerShell scripts

Work on Windows PowerShell 5.1 and PowerShell 7. The AD and GPO ones need RSAT (`ActiveDirectory` / `GroupPolicy` modules). Full help for any of them:

```powershell
Get-Help .\Get-ServerHealth.ps1 -Full
```

If execution policy blocks them after download: `Unblock-File .\*.ps1`

## Get-ServerHealth.ps1

One line per server: status, OS, uptime, CPU and memory %, usage per disk, automatic services that are stopped, pending reboot, and the date of the latest installed update. Unreachable servers still appear with status `Unreachable` and the error, so nothing drops out of the list unnoticed. Takes names from the pipeline.

```powershell
Get-Content .\servers.txt | .\Get-ServerHealth.ps1 | Where-Object Status -ne 'OK'
.\Get-ServerHealth.ps1 -ComputerName FS01, APP01 | Export-Csv .\health.csv -NoTypeInformation
```

## Get-DiskSpaceReport.ps1

Every fixed drive on every server, sorted fullest first. Give it `-SmtpServer` and `-To` and it mails an HTML table of anything above `-WarnPercent`. Good as a daily scheduled task.

## Test-PendingReboot.ps1

Tells you not just whether a reboot is pending but why: `CBS` (component servicing), `WindowsUpdate`, `FileRename` (usually an installer), `ComputerRename`, or `ConfigMgr` if the SCCM client is installed. Useful before a maintenance window to know which servers will actually reboot.

## Get-StaleADAccounts.ps1

Enabled users and computers that haven't logged on in `-Days` (default 90). Uses `lastLogonTimestamp`, which is replicated between DCs (accurate to about two weeks, fine for this purpose). Accounts created inside the window are skipped so new hires who haven't logged in yet don't show up.

Report only:

```powershell
.\Get-StaleADAccounts.ps1 -Days 120 | Export-Csv .\stale.csv -NoTypeInformation
```

Clean up. Always run with `-WhatIf` first:

```powershell
.\Get-StaleADAccounts.ps1 -Days 180 -Disable -QuarantineOU 'OU=Disabled,DC=lab,DC=local' -WhatIf
```

With `-Disable`, each account is disabled, moved to the quarantine OU, and gets the date and reason added to its description, so in six months someone can tell why it's there.

## New-ADUsersFromCsv.ps1

Bulk-creates users from a CSV (see [examples/new-hires.csv](examples/new-hires.csv)). Each user gets a random 16-character password from a cryptographic RNG, must change it at first logon, and is added to the groups in the `Groups` column. Existing usernames are skipped, never overwritten. Initial passwords go to a separate CSV; hand them over and delete that file.

```powershell
.\New-ADUsersFromCsv.ps1 -Path .\new-hires.csv -UpnSuffix lab.local -WhatIf
```

## Backup-GPOs.ps1

Backs up every GPO into a dated folder, with an HTML settings report for each one and an `index.csv` mapping the GUID folders back to GPO names. Keeps the newest `-Keep` runs. The HTML reports are the useful part when something changed and nobody remembers what. Open last week's and this week's side by side.

```powershell
.\Backup-GPOs.ps1 -Destination \\nas01\backup\gpo -Keep 30
```

## Get-CertificateExpiry.ps1

Certificates in `LocalMachine\My` and `WebHosting` expiring within `-Days`, already-expired ones included, sorted by days left. On IIS servers it also shows which site bindings use each certificate. Run it across servers with `Invoke-Command -FilePath`.

## Start-StoppedServices.ps1

Starts automatic services that are stopped, with retries, and writes what it did to the Application event log (source `ServiceWatchdog`, event 1000 = started, 1001 = failed). Pass `-Name` to watch specific services; without it, it checks all automatic services except the ones that normally stop on their own.

```powershell
.\Start-StoppedServices.ps1 -Name W3SVC, MSSQLSERVER, SQLSERVERAGENT
```
