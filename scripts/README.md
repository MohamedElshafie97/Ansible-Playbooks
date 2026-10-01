# Scripts

Standalone Bash and PowerShell scripts for the jobs that don't need a full Ansible run, or that need to run on a box from cron or Task Scheduler. Every script has its usage at the top (`-h` for the Bash ones, `Get-Help .\Script.ps1 -Full` for PowerShell).

## Bash

Details and examples: [bash/README.md](bash/README.md)

| Script | What it does |
|--------|--------------|
| `server-health.sh` | One-screen snapshot: load, memory, disks, inodes, failed units, top processes, listening ports. Exits 1 on any warning so it doubles as a check. |
| `mariadb-backup.sh` | Per-database dumps with `--single-transaction`, gzip test, "Dump completed" footer check, SHA-256 manifest, grants export, retention, optional rsync to a NAS. Uses `flock` so overlapping cron runs can't collide. |
| `disk-alert.sh` | Silent unless a filesystem is over the threshold; then logs to syslog, shows the largest directories, and posts to a webhook and/or mail. |
| `ssl-cert-check.sh` | Days left on TLS certs for a list of `host:port` endpoints. |
| `user-audit.sh` | Read-only account review: extra UID 0, empty passwords, non-expiring passwords, NOPASSWD sudo, `authorized_keys` permissions, inactive users. |
| `service-watchdog.sh` | Restarts stopped services from cron, but stops retrying after N attempts an hour so a crash loop gets noticed instead of hidden. |
| `port-check.sh` | Parallel TCP reachability check, useful after firewall changes or a DR switchover. No `nc` needed. |

```bash
sudo install -m 0755 scripts/bash/*.sh /usr/local/bin/
server-health.sh -d 80
mariadb-backup.sh -d /backup/mariadb -r 14 -n backup@nas01:/mnt/pool/db/
```

## PowerShell

Details and examples: [powershell/README.md](powershell/README.md)

| Script | What it does |
|--------|--------------|
| `Get-ServerHealth.ps1` | Uptime, CPU, memory, disks, stopped auto services, pending reboot and last patch date for many servers over CIM. Outputs objects. |
| `Get-DiskSpaceReport.ps1` | Disk usage across servers; emails an HTML table when anything is low. |
| `Test-PendingReboot.ps1` | Pending reboot status with the reason (CBS, Windows Update, file rename, computer rename, ConfigMgr). |
| `Get-StaleADAccounts.ps1` | Users and computers inactive for N days. Report-only by default; `-Disable` disables, tags and moves them. Supports `-WhatIf`. |
| `New-ADUsersFromCsv.ps1` | Bulk user creation from CSV with random initial passwords and group membership. See `examples/new-hires.csv`. |
| `Backup-GPOs.ps1` | Backs up every GPO plus an HTML report each, with an index and retention. |
| `Get-CertificateExpiry.ps1` | Expiring certificates in the machine stores and which IIS bindings use them. |
| `Start-StoppedServices.ps1` | Starts stopped automatic services and logs to the Application event log. |

```powershell
.\Get-ServerHealth.ps1 -ComputerName APP01, FS01 | Format-Table -AutoSize
.\Get-StaleADAccounts.ps1 -Days 180 -Disable -QuarantineOU 'OU=Disabled,DC=lab,DC=local' -WhatIf
```

Anything that changes AD supports `-WhatIf`. Run it that way first.
