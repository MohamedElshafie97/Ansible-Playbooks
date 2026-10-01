#!/usr/bin/env bash
#
# port-check.sh - check TCP reachability of host:port pairs in parallel.
# Handy after firewall changes or a DR failover.
#
# Usage: port-check.sh [-t TIMEOUT] host:port [host:port ...]
#        port-check.sh -f targets.txt
#
# Exit code is the number of unreachable targets (capped at 255).

set -uo pipefail

TIMEOUT=3
FILE=""
while getopts ":t:f:h" opt; do
    case "$opt" in
        t) TIMEOUT="$OPTARG" ;;
        f) FILE="$OPTARG" ;;
        h) sed -n '3,9p' "$0"; exit 0 ;;
        *) echo "Unknown option -$OPTARG" >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))

targets=("$@")
[[ -n "$FILE" ]] && mapfile -t -O "${#targets[@]}" targets < <(grep -Ev '^\s*(#|$)' "$FILE")
(( ${#targets[@]} > 0 )) || { sed -n '3,9p' "$0"; exit 2; }

check() {
    local host=${1%:*} port=${1##*:} start end
    start=$(date +%s%N)
    if timeout "$TIMEOUT" bash -c "exec 3<>/dev/tcp/$host/$port" 2>/dev/null; then
        end=$(date +%s%N)
        printf '%-35s OPEN    %4d ms\n' "$1" $(( (end - start) / 1000000 ))
    else
        printf '%-35s CLOSED\n' "$1"
        return 1
    fi
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

i=0
for t in "${targets[@]}"; do
    ( check "$t" > "$tmp/$i" || echo fail > "$tmp/$i.fail" ) &
    i=$((i + 1))
done
wait

for ((n = 0; n < i; n++)); do cat "$tmp/$n"; done
failed=$(find "$tmp" -name '*.fail' | wc -l)
exit $(( failed > 255 ? 255 : failed ))
