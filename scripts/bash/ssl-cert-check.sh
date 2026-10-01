#!/usr/bin/env bash
#
# ssl-cert-check.sh - days until expiry for a list of TLS endpoints.
#
# Usage: ssl-cert-check.sh [-w DAYS] host[:port] [host[:port] ...]
#        ssl-cert-check.sh [-w DAYS] -f endpoints.txt
#
# endpoints.txt: one host or host:port per line, # for comments.
# Exit code: 0 all fine, 1 at least one cert expires within DAYS, 2 errors.

set -uo pipefail

WARN_DAYS=30
FILE=""

while getopts ":w:f:h" opt; do
    case "$opt" in
        w) WARN_DAYS="$OPTARG" ;;
        f) FILE="$OPTARG" ;;
        h) sed -n '3,10p' "$0"; exit 0 ;;
        *) echo "Unknown option -$OPTARG" >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))

endpoints=("$@")
if [[ -n "$FILE" ]]; then
    mapfile -t -O "${#endpoints[@]}" endpoints < <(grep -Ev '^\s*(#|$)' "$FILE")
fi
(( ${#endpoints[@]} > 0 )) || { sed -n '3,10p' "$0"; exit 2; }

status=0
now=$(date +%s)
printf '%-40s %6s  %-12s %s\n' ENDPOINT DAYS EXPIRES ISSUER

for ep in "${endpoints[@]}"; do
    host=${ep%%:*}
    port=${ep##*:}
    [[ "$port" == "$ep" ]] && port=443

    cert=$(echo | timeout 10 openssl s_client -servername "$host" -connect "$host:$port" 2>/dev/null \
           | openssl x509 -noout -enddate -issuer 2>/dev/null)
    if [[ -z "$cert" ]]; then
        printf '%-40s %6s  %s\n' "$host:$port" "ERR" "could not read certificate"
        status=2
        continue
    fi

    end=$(sed -n 's/^notAfter=//p' <<<"$cert")
    issuer=$(sed -n 's/^issuer=.*O *= *\([^,]*\).*/\1/p' <<<"$cert")
    days=$(( ($(date -d "$end" +%s) - now) / 86400 ))

    flag=""
    if (( days < WARN_DAYS )); then
        flag="  <-- renew"
        (( status == 0 )) && status=1
    fi
    printf '%-40s %6d  %-12s %s%s\n' "$host:$port" "$days" "$(date -d "$end" +%F)" "${issuer:-?}" "$flag"
done

exit $status
