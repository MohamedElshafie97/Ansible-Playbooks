#!/usr/bin/env bash
#
# user-audit.sh - local account security review. Read-only.
#
# Checks for: extra UID 0 accounts, accounts with empty passwords,
# interactive accounts that never expire, sudo rights, authorized_keys
# files, and accounts not used in N days.
#
# Usage: sudo user-audit.sh [-i INACTIVE_DAYS]

set -euo pipefail

INACTIVE_DAYS=90
while getopts ":i:h" opt; do
    case "$opt" in
        i) INACTIVE_DAYS="$OPTARG" ;;
        h) sed -n '3,10p' "$0"; exit 0 ;;
        *) echo "Unknown option -$OPTARG" >&2; exit 2 ;;
    esac
done

[[ $EUID -eq 0 ]] || { echo "Run as root (needs /etc/shadow)" >&2; exit 2; }

findings=0
hdr()  { echo; echo "== $* =="; }
flag() { echo "  ! $*"; findings=$((findings + 1)); }

UID_MIN=$(awk '/^UID_MIN/{print $2}' /etc/login.defs 2>/dev/null || echo 1000)
mapfile -t HUMANS < <(awk -F: -v min="$UID_MIN" '$3 >= min && $3 < 65534 {print $1}' /etc/passwd)

hdr "UID 0 accounts"
awk -F: '$3 == 0 {print "  " $1}' /etc/passwd
while read -r u; do flag "$u has UID 0"; done < <(awk -F: '$3 == 0 && $1 != "root" {print $1}' /etc/passwd)

hdr "Empty passwords"
while read -r u; do flag "$u has an empty password"; done < <(awk -F: '$2 == "" {print $1}' /etc/shadow)

hdr "Regular accounts (UID >= $UID_MIN)"
for u in "${HUMANS[@]}"; do
    shell=$(getent passwd "$u" | cut -d: -f7)
    maxdays=$(getent shadow "$u" | cut -d: -f5)
    locked=$(passwd -S "$u" 2>/dev/null | awk '{print $2}')
    last=$(lastlog -u "$u" 2>/dev/null | awk 'NR==2 {if ($0 ~ /Never logged in/) print "never"; else print $4, $5, $6, $9}')
    printf '  %-16s shell=%-18s status=%-3s maxdays=%-6s last=%s\n' "$u" "$shell" "${locked:-?}" "${maxdays:-none}" "${last:-?}"

    if [[ "$shell" != */nologin && "$shell" != */false && "$locked" != "L" ]]; then
        [[ -z "$maxdays" || "$maxdays" == "99999" ]] && flag "$u: password never expires"
    fi
done

hdr "Not logged in for $INACTIVE_DAYS+ days"
lastlog -b "$INACTIVE_DAYS" 2>/dev/null | awk 'NR>1 && $0 !~ /Never logged in/ {print "  " $1}' | while read -r u; do
    for h in "${HUMANS[@]}"; do [[ "$u" == "$h" ]] && echo "  $u"; done
done

hdr "Sudo rights"
grep -rhEv '^\s*(#|Defaults|$)' /etc/sudoers /etc/sudoers.d/ 2>/dev/null | sed 's/^/  /'
grep -rhE 'NOPASSWD' /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -v '^\s*#' | while read -r line; do
    flag "NOPASSWD rule: $line"
done
for g in sudo wheel; do
    members=$(getent group "$g" | cut -d: -f4)
    [[ -n "$members" ]] && echo "  group $g: $members"
done

hdr "authorized_keys"
while IFS=: read -r u _ _ _ _ home _; do
    f="$home/.ssh/authorized_keys"
    if [[ -f "$f" ]]; then
        n=$(grep -cEv '^\s*(#|$)' "$f" || true)
        perms=$(stat -c '%a' "$f")
        echo "  $u: $n key(s), mode $perms"
        [[ "$perms" =~ ^6[04]0$ ]] || flag "$f has loose permissions ($perms)"
    fi
done < /etc/passwd

echo
if (( findings > 0 )); then
    echo "$findings finding(s)"
    exit 1
fi
echo "No findings"
