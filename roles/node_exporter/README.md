# node_exporter

Installs Prometheus node_exporter straight from the GitHub release, not a distro package, so every host runs the same version.

- Runs as its own system user with no shell.
- systemd unit with `ProtectSystem=strict`, `ProtectHome` and `NoNewPrivileges`.
- Extra collectors: `systemd` (unit states) and `processes`. The textfile collector reads `/var/lib/node_exporter/textfile`, which is handy for pushing your own metrics from cron, for example the age of the last good backup.
- Only re-downloads when `node_exporter_version` changes.
- If `node_exporter_allowed_source` is set, port 9100 is opened only to that address (your Prometheus server).
- Finishes by hitting `http://127.0.0.1:9100/metrics` to make sure it actually answers.

```bash
ansible-playbook playbooks/linux/node-exporter.yml -e node_exporter_allowed_source=10.10.10.31
```

To upgrade, bump `node_exporter_version` and re-run.
