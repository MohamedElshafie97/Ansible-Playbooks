#!/usr/bin/env bash
#
# server-health.sh - quick health snapshot of a Linux server.
#
# Prints CPU, memory, disk, failed units, top processes and listening
# ports. Exits 1 if anything crosses a threshold, so it can be used from
# cron or a monitoring check as well as interactively.
#
# Usage: server-health.sh [-d DISK_PCT] [-m MEM_PCT] [-q]
#   -d  disk usage warning threshold (default 85)
#   -m  memory usage warning threshold (default 90)
#   -q  quiet: only print warnings

set -euo pipefail

DISK_WARN=85
MEM_WARN=90
QUIET=0
WARNINGS=()

while getopts ":d:m:qh" opt; do
    case "$opt" in
        d) DISK_WARN="$OPTARG" ;;
        m) MEM_WARN="$OPTARG" ;;
        q) QUIET=1 ;;
        h) sed -n '3,14p' "$0"; exit 0 ;;
        *) echo "Unknown option -$OPTARG" >&2; exit 2 ;;
    esac
done

say()     { [[ $QUIET -eq 1 ]] || echo -e "$*"; }
section() { say "\n== $* =="; }
warn()    { WARNINGS+=("$*"); }

section "Host"
say "$(hostname -f 2>/dev/null || hostname) | $(. /etc/os-release && echo "$PRETTY_NAME") | kernel $(uname -r)"
say "Up since $(uptime -s) ($(uptime -p))"

section "CPU"
cores=$(nproc)
read -r load1 load5 load15 _ < /proc/loadavg
say "Cores: $cores   Load: $load1 $load5 $load15"
if awk -v l="$load5" -v c="$cores" 'BEGIN{exit !(l > c)}'; then
    warn "5-minute load ($load5) is above core count ($cores)"
fi

section "Memory"
read -r mem_total mem_avail < <(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{print t, a}' /proc/meminfo)
mem_pct=$(( (mem_total - mem_avail) * 100 / mem_total ))
say "Used: ${mem_pct}% of $(( mem_total / 1024 )) MB"
(( mem_pct >= MEM_WARN )) && warn "Memory at ${mem_pct}%"
swap_used=$(free -m | awk '/^Swap/{print $3}')
(( swap_used > 0 )) && say "Swap in use: ${swap_used} MB"

section "Disks"
while read -r fs pct mount; do
    p=${pct%\%}
    say "$(printf '%-25s %4s  %s' "$mount" "$pct" "$fs")"
    (( p >= DISK_WARN )) && warn "Disk $mount at $pct"
done < <(df -P -x tmpfs -x devtmpfs -x squashfs -x overlay | awk 'NR>1 {print $1, $5, $6}')

while read -r mount ipct; do
    p=${ipct%\%}
    [[ "$p" =~ ^[0-9]+$ ]] && (( p >= DISK_WARN )) && warn "Inodes on $mount at $ipct"
done < <(df -Pi -x tmpfs -x devtmpfs -x squashfs -x overlay | awk 'NR>1 {print $6, $5}')

section "Failed systemd units"
if [[ -d /run/systemd/system ]]; then
    failed=$(systemctl list-units --state=failed --no-legend --plain 2>/dev/null | awk '{print $1}')
    if [[ -n "$failed" ]]; then
        say "$failed"
        warn "Failed units: $(echo "$failed" | paste -sd, -)"
    else
        say "none"
    fi
else
    say "systemd not running, skipped"
fi

section "Top 5 by CPU"
say "$(ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head -6)"

section "Top 5 by memory"
say "$(ps -eo pid,user,%cpu,%mem,comm --sort=-%mem | head -6)"

section "Listening TCP ports"
if command -v ss >/dev/null; then
    say "$(ss -Hltn | awk '{print $4}' | sort -u | paste -sd' ' -)"
elif command -v netstat >/dev/null; then
    say "$(netstat -ltn | awk 'NR>2 {print $4}' | sort -u | paste -sd' ' -)"
else
    say "ss/netstat not installed"
fi

section "Summary"
if (( ${#WARNINGS[@]} > 0 )); then
    for w in "${WARNINGS[@]}"; do echo "WARN: $w"; done
    exit 1
fi
say "OK"
