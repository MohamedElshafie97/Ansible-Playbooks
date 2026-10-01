#!/usr/bin/env bash
#
# mariadb-backup.sh - per-database MariaDB/MySQL backups with verification.
#
# Each database is dumped to its own gzip file using --single-transaction
# (no table locks for InnoDB). Every file is integrity-tested, a SHA-256
# manifest is written, old runs are pruned, and the run can optionally be
# copied to a NAS with rsync.
#
# Credentials come from ~/.my.cnf or the file given with -c, never from
# the command line.
#
# Usage: mariadb-backup.sh [-d DEST] [-r DAYS] [-c DEFAULTS_FILE] [-n RSYNC_TARGET]
#   -d  backup root (default /backup/mariadb)
#   -r  retention in days (default 7)
#   -c  MySQL defaults file with [client] user/password (default ~/.my.cnf)
#   -n  rsync destination, e.g. backup@nas01:/mnt/pool/db/
#
# Cron example:
#   30 1 * * * /usr/local/bin/mariadb-backup.sh -n backup@nas01:/mnt/pool/db/ >> /var/log/mariadb-backup.log 2>&1

set -euo pipefail
umask 077

DEST=/backup/mariadb
RETENTION=7
DEFAULTS_FILE="${HOME}/.my.cnf"
RSYNC_TARGET=""

while getopts ":d:r:c:n:h" opt; do
    case "$opt" in
        d) DEST="$OPTARG" ;;
        r) RETENTION="$OPTARG" ;;
        c) DEFAULTS_FILE="$OPTARG" ;;
        n) RSYNC_TARGET="$OPTARG" ;;
        h) sed -n '3,22p' "$0"; exit 0 ;;
        *) echo "Unknown option -$OPTARG" >&2; exit 2 ;;
    esac
done

log() { echo "$(date '+%F %T') [$$] $*"; }
die() { log "ERROR: $*"; exit 1; }

DUMP=$(command -v mariadb-dump || command -v mysqldump) || die "mariadb-dump/mysqldump not found"
CLIENT=$(command -v mariadb || command -v mysql) || die "mariadb/mysql client not found"
[[ -r "$DEFAULTS_FILE" ]] || die "Cannot read $DEFAULTS_FILE"

LOCK=/var/lock/mariadb-backup.lock
exec 9>"$LOCK"
flock -n 9 || die "Another backup is already running"

STAMP=$(date +%Y%m%d-%H%M%S)
RUN_DIR="$DEST/$STAMP"
mkdir -p "$RUN_DIR"

trap 'log "Backup failed - partial run left in $RUN_DIR"' ERR

log "Starting backup into $RUN_DIR"

mapfile -t DATABASES < <("$CLIENT" --defaults-extra-file="$DEFAULTS_FILE" -N -B -e \
    "SELECT schema_name FROM information_schema.schemata
     WHERE schema_name NOT IN ('information_schema','performance_schema','sys')")

(( ${#DATABASES[@]} > 0 )) || die "No databases found"

for db in "${DATABASES[@]}"; do
    out="$RUN_DIR/${db}.sql.gz"
    start=$SECONDS
    "$DUMP" --defaults-extra-file="$DEFAULTS_FILE" \
        --single-transaction --quick --routines --triggers --events \
        --databases "$db" | gzip -6 > "$out"

    gzip -t "$out" || die "gzip test failed for $db"
    zcat "$out" | tail -n 1 | grep -q 'Dump completed' || die "Dump of $db looks truncated"

    log "  $db  $(du -h "$out" | cut -f1)  $((SECONDS - start))s"
done

# Grants are not inside the per-database dumps
"$CLIENT" --defaults-extra-file="$DEFAULTS_FILE" -N -B -e \
    "SELECT CONCAT('SHOW GRANTS FOR ''', user, '''@''', host, ''';') FROM mysql.user" \
    | "$CLIENT" --defaults-extra-file="$DEFAULTS_FILE" -N -B 2>/dev/null \
    | sed 's/$/;/' | gzip > "$RUN_DIR/_grants.sql.gz"

( cd "$RUN_DIR" && sha256sum ./*.gz > SHA256SUMS && sha256sum -c --quiet SHA256SUMS )
log "Manifest verified"

if [[ -n "$RSYNC_TARGET" ]]; then
    log "Copying to $RSYNC_TARGET"
    rsync -a --partial "$RUN_DIR" "$RSYNC_TARGET"
fi

pruned=$(find "$DEST" -mindepth 1 -maxdepth 1 -type d -mtime +"$RETENTION" -print -exec rm -rf {} + | wc -l)
log "Pruned $pruned run(s) older than $RETENTION days"
log "Done: ${#DATABASES[@]} database(s), total $(du -sh "$RUN_DIR" | cut -f1)"
