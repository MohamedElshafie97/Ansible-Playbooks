# ssh_hardening

Locks down `sshd` without touching the distro's own `sshd_config` beyond one `Include` line. All settings go into `/etc/ssh/sshd_config.d/00-hardening.conf`, so package updates don't fight with Ansible and it's obvious what was changed.

## What it does

1. Installs `openssh-server` if missing.
2. Checks that the user Ansible connects as has a non-empty `authorized_keys`. If not, and you're about to disable passwords, the role stops. This is the step that saves you from a locked-out server.
3. Keeps a one-time copy of the original config as `sshd_config.orig`.
4. Deploys the drop-in and validates it with `sshd -t` before it's written.
5. Adds a pre-login banner.
6. If you move SSH off port 22: labels the port for SELinux on RHEL and opens it in `firewalld` / `ufw`.
7. Reloads (not restarts) sshd, so existing sessions stay up.

## Variables

| Variable | Default | Notes |
|----------|---------|-------|
| `ssh_port` | `22` | |
| `ssh_permit_root_login` | `"no"` | quote it, otherwise YAML turns it into `false` |
| `ssh_password_authentication` | `"no"` | |
| `ssh_max_auth_tries` | `3` | |
| `ssh_login_grace_time` | `30` | seconds |
| `ssh_client_alive_interval` / `_count_max` | `300` / `2` | idle sessions drop after ~10 min |
| `ssh_allow_groups` | `[]` | empty = no `AllowGroups` line |
| `ssh_check_keys_before_disabling_passwords` | `true` | turn off only if you know why |

The template also sets `AllowTcpForwarding no` and `AllowAgentForwarding no`, and restricts ciphers/MACs/KEX to modern ones. Very old clients (PuTTY from years ago, some network gear) may not connect afterwards.

## Rolling back

```bash
rm /etc/ssh/sshd_config.d/00-hardening.conf && systemctl reload sshd
```
