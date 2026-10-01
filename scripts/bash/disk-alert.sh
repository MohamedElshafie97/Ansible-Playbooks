#!/usr/bin/env bash
#
# disk-alert.sh - warn when any filesystem passes a usage threshold.
#
# Meant for cron. Silent when everything is fine. When something is over
# the limit it logs to syslog and, if configured, posts to a webhook
# (Teams, Slack, Google Chat - anything that accepts a JSON "text" field)
# and/or sends mail.
#
# Usage: disk-alert.sh [-t PCT] [-w WEBHOOK_URL] [-e EMAIL]
#
# Cron example (every 15 minutes):
#   */15 * * * * /usr/local/bin/disk-alert.sh -t 85 -w https://chat.example.com/hooks/xyz

set -euo pipefail

THRESHOLD=85
WEBHOOK=""
EMAIL=""

while getopts ":t:w:e:h" opt; do
    case "$opt" in
        t) THRESHOLD="$OPTARG" ;;
        w) WEBHOOK="$OPTARG" ;;
        e) EMAIL="$OPTARG" ;;
        h) sed -n '3,14p' "$0"; exit 0 ;;
        *) echo "Unknown option -$OPTARG" >&2; exit 2 ;;
    esac
done

HOST=$(hostname -s)
alerts=()

while read -r pct mount; do
    used=${pct%\%}
    if (( used >= THRESHOLD )); then
        biggest=$(du -xh --max-depth=1 "$mount" 2>/dev/null | sort -rh | sed -n '2,4p' | awk '{printf "%s %s, ", $2, $1}')
        alerts+=("$mount at ${pct} (largest: ${biggest%, })")
    fi
done < <(df -P -x tmpfs -x devtmpfs -x squashfs -x overlay | awk 'NR>1 {print $5, $6}')

(( ${#alerts[@]} == 0 )) && exit 0

msg="[$HOST] disk usage above ${THRESHOLD}%: $(printf '%s; ' "${alerts[@]}")"
logger -t disk-alert -p user.warning "$msg"
echo "$msg"

if [[ -n "$WEBHOOK" ]]; then
    payload=$(printf '{"text": "%s"}' "${msg//\"/\\\"}")
    curl -fsS -m 10 -H 'Content-Type: application/json' -d "$payload" "$WEBHOOK" >/dev/null \
        || logger -t disk-alert "webhook post failed"
fi

if [[ -n "$EMAIL" ]] && command -v mail >/dev/null; then
    echo "$msg" | mail -s "Disk alert: $HOST" "$EMAIL"
fi

exit 1
