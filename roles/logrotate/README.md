# logrotate

One file per application in `/etc/logrotate.d/`, generated from a list.

```yaml
logrotate_policies:
  - name: myapp
    paths: [/var/log/myapp/*.log]
    frequency: daily
    rotate: 14
    maxsize: 200M        # rotate early if a file gets this big
    postrotate: "systemctl reload myapp"

  - name: legacy-java
    paths: [/opt/legacy/logs/catalina.out]
    rotate: 7
    copytruncate: true   # app keeps the file open and can't be told to reopen it
```

Every policy gets `compress`, `delaycompress`, `dateext`, `missingok` and `notifempty`. If `copytruncate` isn't set, a `create` line is added with `mode`/`owner`/`group` (defaults `0640 root root`).

After deploying, each policy is run through `logrotate --debug`, which parses it without rotating anything. A typo in a path or a bad directive fails the play instead of silently doing nothing at 3 AM.
