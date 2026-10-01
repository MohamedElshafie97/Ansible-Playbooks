# common

Baseline every Linux box gets before anything else.

- **Packages**: the usual troubleshooting set (`vim`, `htop`, `tmux`, `lsof`, `tcpdump`, `rsync`, `sysstat`...), plus `bind-utils` on RHEL or `dnsutils` on Debian so `dig` exists everywhere.
- **sysctl**: written to `/etc/sysctl.d/90-baseline.conf`. Turns on SYN cookies, ignores ICMP redirects and source routing, logs martian packets, restricts `dmesg` to root, disables core dumps of setuid binaries, and lowers swappiness to 10.
- **journald**: persistent storage (survives reboots, so you can read logs from before a crash) capped at `common_journald_max_use` (1G).
- **motd**: hostname, OS version and a short warning banner.
- **sysstat**: enabled, so `sar` has history when someone asks "what was the load last night?".

Override `common_sysctl` in group_vars for database or high-traffic hosts; it's a plain dict, so you can add keys like `net.core.somaxconn`.
