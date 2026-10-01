# fail2ban

Bans IPs that keep failing SSH logins.

Pulls in EPEL on RHEL-family hosts (fail2ban isn't in the base repos), reads auth failures from the systemd journal, and bans through `firewallcmd-rich-rules` or `ufw` depending on the distro, so bans show up in the same firewall you already manage.

Defaults: 5 failures within 10 minutes = 1 hour ban. Your own management subnet should go in `fail2ban_ignoreip` so a fat-fingered password from the jump host doesn't ban the whole team:

```yaml
fail2ban_ignoreip:
  - 127.0.0.1/8
  - 10.10.0.0/24
```

Check what's banned: `fail2ban-client status sshd`
Unban: `fail2ban-client set sshd unbanip 1.2.3.4`
