#!/usr/bin/env bash
# Nightly dump of the HisaabChat database, kept for 14 days.
# Installed on the server as /usr/local/bin/hisaabchat-backup, run from
# /etc/cron.d/hisaabchat-backup. Dumps hold personal financial data: keep them private.
set -euo pipefail

DIR=/var/backups/hisaabchat
KEEP_DAYS=14
DB=hisaabchat

umask 077
mkdir -p "$DIR"

FILE="$DIR/$DB-$(date -u +%Y%m%dT%H%M%SZ).sql.gz"
# Written under a temporary name, so a failed dump never looks like a good backup.
mysqldump --single-transaction --routines --triggers --hex-blob --default-character-set=utf8mb4 "$DB" \
  | gzip >"$FILE.partial"
mv "$FILE.partial" "$FILE"

find "$DIR" -name "$DB-*.sql.gz" -mtime +"$KEEP_DAYS" -delete
find "$DIR" -name '*.partial' -mtime +1 -delete

echo "$FILE"
