#!/usr/bin/env bash
#
# service-watchdog.sh - restart critical services that have stopped.
#
# Gives up on a service after MAX_RESTARTS attempts within the state
# window so a crash-looping service gets escalated instead of hammered.
#
# Usage: service-watchdog.sh [-n MAX_RESTARTS] service [service ...]
#
# Cron example:
#   */5 * * * * /usr/local/bin/service-watchdog.sh nginx mariadb chronyd

set -euo pipefail

MAX_RESTARTS=3
STATE_DIR=/var/lib/service-watchdog
WINDOW_MIN=60

while getopts ":n:h" opt; do
    case "$opt" in
        n) MAX_RESTARTS="$OPTARG" ;;
        h) sed -n '3,11p' "$0"; exit 0 ;;
        *) echo "Unknown option -$OPTARG" >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
(( $# > 0 )) || { sed -n '3,11p' "$0"; exit 2; }

mkdir -p "$STATE_DIR"
rc=0

for svc in "$@"; do
    if systemctl is-active --quiet "$svc"; then
        continue
    fi

    state="$STATE_DIR/$svc"
    # Reset the counter when the window has passed
    if [[ -f "$state" ]] && [[ -n "$(find "$state" -mmin +"$WINDOW_MIN")" ]]; then
        rm -f "$state"
    fi
    count=$(cat "$state" 2>/dev/null || echo 0)

    if (( count >= MAX_RESTARTS )); then
        logger -t service-watchdog -p user.crit "$svc still down after $count restarts in ${WINDOW_MIN}m - not retrying"
        rc=1
        continue
    fi

    logger -t service-watchdog -p user.warning "$svc is $(systemctl is-active "$svc" || true), restarting (attempt $((count + 1)))"
    if systemctl restart "$svc" && sleep 5 && systemctl is-active --quiet "$svc"; then
        logger -t service-watchdog "$svc back up"
    else
        logger -t service-watchdog -p user.err "$svc failed to start: $(journalctl -u "$svc" -n 3 --no-pager -o cat | paste -sd' ' -)"
        rc=1
    fi
    echo $((count + 1)) > "$state"
done

exit $rc
