# Windows playbooks

These connect over WinRM (port 5986, NTLM). Connection settings are in `inventories/<env>/group_vars/windows.yml`; the password goes in a vault file, never in plain text.

Quick test that WinRM works before running anything else:

```bash
ansible windows -m ansible.windows.win_ping
```

## win-updates.yml

Installs Critical, Security, Rollup and Defender definition updates, one server at a time by default, and reboots when needed (up to 30 minutes allowed for the reboot, because some cumulative updates are slow). Stops before starting if `C:` has less than 5 GB free, and fails the host if any update failed to install. The full log stays on the server in `C:\Windows\Temp\ansible-win-updates.log`.

Skip a known bad KB:

```bash
ansible-playbook playbooks/windows/win-updates.yml -e '{"win_update_reject": ["KB5034441"]}'
```

## win-baseline.yml

- Time zone (default `Egypt Standard Time`). NTP peers are only set on machines **not** joined to a domain; domain members should keep syncing from the DC hierarchy.
- RDP on, with Network Level Authentication required.
- Windows Firewall on for Domain, Private and Public profiles, with the RDP rule enabled.
- SMBv1 and PowerShell 2.0 removed. Both are old and abused by malware; nothing modern needs them.
- Security event log raised to 1 GB so it doesn't roll over in a few hours on a busy DC or file server.
- `7zip`, `notepadplusplus` and Sysinternals through Chocolatey (empty the list if you don't use Chocolatey).
- Reboots only if removing a feature needs it.

## win-health-report.yml

Read-only. One PowerShell call per host collects OS, uptime, memory, disk usage per drive, automatic services that aren't running (minus the ones that stop by design, like `gupdate`), pending reboot, and the date of the newest hotfix. Everything is written to `reports/windows-health-YYYY-MM-DD.csv`, which opens directly in Excel.

## win-local-admin-audit.yml

Who's in the local Administrators group, compared with `win_admins_approved`. By default it only reports. With `-e win_admins_enforce=true` it removes the extra members. Run it in report mode first; an app service account in that group is a common finding, and removing it can break the app.
