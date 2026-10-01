# Ansible-Playbooks

Ansible playbooks, roles and helper scripts for routine Linux and Windows server administration: baseline builds, SSH hardening, patching, backups that are actually verified, time sync, monitoring agents, and health reports.

Everything targets a mixed RHEL/Rocky + Ubuntu/Debian fleet with some Windows Server, and is written to be re-run safely.

[![lint](https://github.com/MohamedElshafie97/Ansible-Playbooks/actions/workflows/lint.yml/badge.svg)](https://github.com/MohamedElshafie97/Ansible-Playbooks/actions/workflows/lint.yml)

## Layout

```
.
├── ansible.cfg
├── requirements.yml              # collections used by the playbooks
├── inventories/
│   └── lab/                      # example inventory + group_vars
├── roles/
│   ├── common/                   # base packages, sysctl, journald, motd
│   ├── ssh_hardening/            # sshd drop-in, lockout protection
│   ├── chrony/                   # NTP + timezone, fails on bad offset
│   ├── logrotate/                # per-app policies, dry-run validated
│   ├── node_exporter/            # Prometheus exporter as a systemd service
│   └── fail2ban/
├── playbooks/
│   ├── linux/
│   └── windows/
├── scripts/
│   ├── bash/
│   └── powershell/
└── reports/                      # generated reports land here (git-ignored)
```

## Playbooks

Each folder has its own README with the details: [linux](playbooks/linux/README.md), [windows](playbooks/windows/README.md). Every role under `roles/` has one too.

### Linux

| Playbook | Purpose |
|----------|---------|
| `site-baseline.yml` | Full baseline for a new server: `common`, `chrony`, `ssh_hardening`, `fail2ban`. Use tags to run one part. |
| `ssh-hardening.yml` | SSH hardening through `/etc/ssh/sshd_config.d/00-hardening.conf`. Checks that the Ansible user has a key before disabling passwords, validates with `sshd -t`, handles SELinux and the firewall for non-default ports. Runs 25% of hosts at a time. |
| `patch-rolling.yml` | Rolling updates (`dnf` / `apt`) one host at a time by default. Checks free space first, reboots only when the OS says it's needed, verifies services afterwards, and stops the run if a host fails. `-e patch_security_only=true` for security fixes only. |
| `backup-verify.yml` | Config archive plus per-database MariaDB dumps on `db` hosts. Each file is gzip-tested, dumps are checked for the completion footer, a SHA-256 manifest is written and re-verified, and a copy of the manifest is pulled back to the control node. Old runs are pruned. |
| `mariadb-replication-check.yml` | Fails any replica whose IO/SQL thread is down or whose lag is above `mariadb_max_lag_seconds`. Prints GTID position and last error. |
| `time-sync.yml` | chrony + timezone. Fails if a host can't sync or its offset is too large. |
| `users.yml` | Admin accounts from `group_vars`: exclusive `authorized_keys`, sudo via validated drop-ins, locking and removal of leavers. |
| `firewall.yml` | Default-deny inbound with `firewalld` or `ufw`; SSH is always kept open. |
| `fail2ban.yml` | fail2ban for sshd using the right ban action per distro. |
| `log-rotation.yml` | logrotate policies per application, each one dry-run after deployment. |
| `node-exporter.yml` | node_exporter binary, hardened systemd unit, firewall rule limited to the Prometheus server. |
| `docker.yml` | Docker Engine from the official repo with container log rotation in `daemon.json`. |
| `disk-cleanup.yml` | Package cache, journal vacuum, old kernels, expired rotated logs, stale `/tmp`. Shows before/after. |
| `health-report.yml` | Read-only. Writes `reports/linux-health-<date>.md` with uptime, load, memory, disks, pending updates and failed units for every host. |
| `cert-expiry-check.yml` | Checks TLS endpoints from the control node and fails if any expire within 30 days. |

### Windows

| Playbook | Purpose |
|----------|---------|
| `win-updates.yml` | Windows Update in rolling batches with reboot handling and a failure check. |
| `win-baseline.yml` | Time zone and NTP, RDP with NLA, firewall profiles on, SMBv1 and PowerShell 2.0 removed, bigger Security log, common tools via Chocolatey. |
| `win-health-report.yml` | Read-only. Writes `reports/windows-health-<date>.csv`. |
| `win-local-admin-audit.yml` | Lists unexpected members of local Administrators; `-e win_admins_enforce=true` removes them. |

## Getting started

```bash
python3 -m pip install ansible
ansible-galaxy collection install -r requirements.yml

# copy the example inventory and edit hosts and group_vars
cp -r inventories/lab inventories/prod

# always look first
ansible-playbook -i inventories/prod playbooks/linux/ssh-hardening.yml --check --diff

ansible-playbook -i inventories/prod playbooks/linux/site-baseline.yml --limit web01
ansible-playbook -i inventories/prod playbooks/linux/patch-rolling.yml --limit web -e patch_batch=2
ansible-playbook -i inventories/prod playbooks/linux/health-report.yml
```

Windows hosts need WinRM over HTTPS and `pywinrm` on the control node (`pip install pywinrm`). Keep the password in a vault file:

```bash
ansible-vault create inventories/prod/group_vars/windows_vault.yml
ansible-playbook -i inventories/prod playbooks/windows/win-health-report.yml --ask-vault-pass
```

## Things worth knowing

- **Run with `--check --diff` first**, especially `ssh-hardening.yml`, `firewall.yml` and `users.yml`. Those are the ones that can lock you out.
- `ssh_hardening` sets `AllowTcpForwarding no`. If you rely on SSH tunnels, override it in `group_vars`.
- `users.yml` manages `authorized_keys` exclusively: any key not in `admin_users` is removed for those users.
- The example inventory uses placeholder addresses. Don't commit a real inventory with production IPs to a public repo.

## Scripts

Standalone Bash and PowerShell scripts live in [`scripts/`](scripts/README.md): server health, MariaDB backup with verification, disk alerts, certificate checks, account audits, AD clean-up, GPO backup and more.

## Linting

Every push runs `yamllint`, `ansible-lint` (production profile), a syntax check of every playbook, `shellcheck` and PSScriptAnalyzer. Run the same locally:

```bash
yamllint . && ansible-lint && shellcheck scripts/bash/*.sh
```
