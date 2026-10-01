# chrony

Time sync with chrony and the system timezone.

Logs from two servers are useless for troubleshooting if their clocks disagree, and replication and Kerberos both break on drift. So this role doesn't just install chrony and hope: after the config is applied it forces a step, waits until chrony has picked a source (stratum > 0, up to a minute), and **fails the host** if the offset is still larger than `chrony_max_offset`.

Handles the path difference between distros (`/etc/chrony.conf` on RHEL, `/etc/chrony/chrony.conf` on Debian/Ubuntu) and the service name (`chronyd` vs `chrony`). Removes `ntp` if it's installed so the two don't fight.

| Variable | Default |
|----------|---------|
| `chrony_timezone` | `timezone` from group_vars, else `UTC` |
| `chrony_servers` | `ntp_servers` from group_vars, else two pool servers |
| `chrony_allow_networks` | `[]` (client only). Add e.g. `10.10.0.0/16` to make the host an NTP server for that range |
| `chrony_max_offset` | `0.5` seconds |

Inside a company network you'd normally point `chrony_servers` at your domain controllers or an internal NTP host instead of the public pool.
