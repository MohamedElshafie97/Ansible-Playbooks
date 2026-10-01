# Linux playbooks

All of these run against the `linux` group unless noted. Narrow them with `--limit`. Anything that changes config should be tried with `--check --diff` first.

---

### site-baseline.yml

What a new server gets on day one: the `common`, `chrony`, `ssh_hardening` and `fail2ban` roles in that order. Each role is tagged, so you can re-apply a single piece:

```bash
ansible-playbook playbooks/linux/site-baseline.yml --limit web03
ansible-playbook playbooks/linux/site-baseline.yml --tags time
```

### ssh-hardening.yml

Just the `ssh_hardening` role, run on 25% of hosts at a time. If a batch fails the run stops, which means one bad setting doesn't take SSH away from the whole fleet. See [roles/ssh_hardening](../../roles/ssh_hardening/README.md).

### patch-rolling.yml

OS updates without taking a whole service down.

- One host at a time by default (`-e patch_batch=2` for two, `25%` also works).
- `max_fail_percentage: 0`: if a host fails, nothing after it gets patched.
- Before patching: checks there's at least 1 GB free on `/`.
- Reboots only if `needs-restarting -r` (RHEL) or `/var/run/reboot-required` (Debian) says so. `-e patch_allow_reboot=false` to patch now and reboot in a window later.
- After reboot: makes sure everything in `patch_check_services` is running again and prints the old and new kernel.

```bash
ansible-playbook playbooks/linux/patch-rolling.yml --limit db -e '{"patch_check_services": ["mariadb"]}'
ansible-playbook playbooks/linux/patch-rolling.yml -e patch_security_only=true
```

For a replicated database, patch the replica first, check replication, then fail over or patch the primary.

### backup-verify.yml

A backup you never tested is a guess. This one:

1. Refuses to start if the backup filesystem has less than 2 GB free.
2. Archives config files (a base list plus `backup_extra_paths` per group; only paths that exist).
3. On `db` hosts, dumps each MariaDB database to its own `.sql.gz` with `--single-transaction`, so InnoDB tables aren't locked.
4. Checks every dump ends with the `-- Dump completed` line. A dump killed half-way still produces a valid gzip, so `gzip -t` alone doesn't catch it.
5. Runs `gzip -t` on every file, writes `SHA256SUMS`, then re-verifies it.
6. Copies the checksum file back to `reports/backups/` on the control node, so you have an off-box record of what the backup looked like.
7. Deletes runs older than `backup_retention_days` and appends a line to `backup.log`.

Credentials come from root's `~/.my.cnf` on the DB host.

### mariadb-replication-check.yml

Runs on the `db` group, skips anything with `mariadb_role: primary`, and fails a replica if the IO or SQL thread isn't running or `Seconds_Behind_Master` is above `mariadb_max_lag_seconds`. The output includes the source host, GTID position and the last error, which is usually enough to know where to look. Good to run after maintenance or from a scheduled job.

### time-sync.yml

The `chrony` role on its own. Fails hosts whose clock won't sync.

### users.yml

Admin accounts as code, from `admin_users` in group_vars:

```yaml
admin_users:
  - name: mohamed
    groups: [sshusers]
    sudo: true
    pubkey: "ssh-ed25519 AAAA..."
    state: present
  - name: old.contractor
    state: absent
```

Keys are managed **exclusively**: keys not listed here are removed from that user. Sudo rights go into `/etc/sudoers.d/<user>` and are checked with `visudo -cf` before saving. Leavers are locked first, then removed with their home and sudoers file.

### firewall.yml

Default-deny inbound. Ports come from `firewall_allowed_tcp_ports` and `firewall_allowed_udp_ports`. The SSH port is always added, whatever the list says. On Debian SSH uses `ufw limit` (rate-limited) instead of plain allow.

### fail2ban.yml

The `fail2ban` role on its own.

### log-rotation.yml

The `logrotate` role. Define the policies in group_vars or host_vars.

### node-exporter.yml

The `node_exporter` role.

### docker.yml

Docker Engine from `download.docker.com`, not the older distro packages. Removes `docker.io`, `podman-docker` and friends first because they conflict. Sets container log rotation (`50m` x 3 files) in `daemon.json`; without it one chatty container can fill `/var/lib/docker`. Enables `live-restore` so containers survive a daemon restart. Ends with `docker run hello-world`.

### disk-cleanup.yml

For when `/` is at 95% and you need space now. Vacuums the journal to two weeks, cleans the package cache, keeps only the two newest kernels on RHEL (`apt autoremove` on Debian), deletes rotated logs older than 30 days and files in `/tmp` older than 10 days. Prints `df` before and after.

```bash
ansible-playbook playbooks/linux/disk-cleanup.yml --limit web02 --check
```

### health-report.yml

Read-only. Collects OS, kernel, uptime, load, memory, usage for every real filesystem (flagging any over 80%), pending updates and failed systemd units from every host, then writes one markdown table to `reports/linux-health-YYYY-MM-DD.md` on the control node. Unreachable hosts are listed separately so they don't silently disappear from the report.

### cert-expiry-check.yml

Runs on the control node. Connects to each endpoint in `cert_endpoints`, works out days until expiry, and fails if any are under `cert_warn_days` (30).
