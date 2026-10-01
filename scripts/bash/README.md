# Bash scripts

Written for RHEL/Rocky and Ubuntu/Debian. Each one prints its usage with `-h`. Install them all with:

```bash
sudo install -m 0755 scripts/bash/*.sh /usr/local/bin/
```

## server-health.sh

The first thing to run when someone says "the server is slow". Shows host info, load against core count, memory and swap, every real filesystem with usage, inode usage, failed systemd units, top five processes by CPU and by memory, and listening TCP ports. At the end it lists anything that crossed a threshold and exits 1, so it also works as a Nagios/cron-style check.

```bash
server-health.sh            # full output
server-health.sh -q -d 80   # only warnings, disk threshold 80%
```

## mariadb-backup.sh

Nightly MariaDB/MySQL backup from cron.

- One `.sql.gz` per database, dumped with `--single-transaction --quick --routines --triggers --events`.
- Grants exported separately into `_grants.sql.gz`, since per-database dumps don't include users.
- Every file: `gzip -t` plus a check for the `Dump completed` footer, so a dump that died half-way is caught.
- `SHA256SUMS` written and re-checked.
- Optional `rsync` of the whole run to a NAS (`-n user@host:/path/`).
- Retention by days (`-r`).
- `flock` stops two runs overlapping if one is slow.
- Credentials only from a defaults file (`~/.my.cnf` or `-c`), so the password never shows in `ps`.

```bash
mariadb-backup.sh -d /backup/mariadb -r 14 -n backup@nas01:/volume1/db/
```

Restore one database:

```bash
zcat /backup/mariadb/20261001-013000/appdb.sql.gz | mariadb
```

## disk-alert.sh

Runs every few minutes and stays quiet until something goes over the limit. Then it logs to syslog (tag `disk-alert`), shows the three biggest directories on that filesystem so you know where to start, and optionally posts to a chat webhook and/or sends mail.

```bash
*/15 * * * * /usr/local/bin/disk-alert.sh -t 85 -w https://chat.example.com/hooks/abc
```

## ssl-cert-check.sh

Days remaining on TLS certificates. Takes endpoints as arguments or from a file; port defaults to 443. Exit code 1 if anything is inside the warning window, 2 if an endpoint couldn't be read.

```bash
ssl-cert-check.sh -w 30 portal.example.com mail.example.com:993 10.10.10.50:8443
ssl-cert-check.sh -f /etc/cert-endpoints.txt
```

## user-audit.sh

Read-only review of local accounts, needs root because it reads `/etc/shadow`. Flags:

- any UID 0 account other than root
- empty password fields
- interactive accounts whose password never expires
- `NOPASSWD` sudo rules
- `authorized_keys` files that aren't `600`/`640`/`644`

Also lists every regular user with shell, lock status and last login, accounts unused for 90+ days (`-i` to change), and who has sudo through which rule or group. Useful before an audit or when inheriting a server nobody documented.

## service-watchdog.sh

Restarts services that have died, from cron. Every restart is logged. After three restarts within an hour it stops trying and logs at `crit` level. A service crash-looping every five minutes is a problem someone needs to look at, and endless silent restarts would hide it.

```bash
*/5 * * * * /usr/local/bin/service-watchdog.sh nginx mariadb
```

## port-check.sh

Checks many `host:port` pairs at once using bash's built-in `/dev/tcp`, so it works on minimal servers without `nc` or `telnet`. Prints response time for open ports. Exit code is the number of closed ones.

```bash
port-check.sh db01:3306 db02:3306 nas01:445 dc01:389 dc01:636
```
