#!/usr/bin/env bash
set -euo pipefail

: "${CRON:=0 2 * * *}"
: "${BACKUP_DIR:=/backups}"
: "${TZ:=UTC}"

mkdir -p "${BACKUP_DIR}"

cat >/etc/crontabs/root <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
TZ=${TZ}
${CRON} /app/backup.sh >> /proc/1/fd/1 2>> /proc/1/fd/2
EOF

echo "Starting folder_simple_backup"
echo "CRON=${CRON}"
echo "BACKUP_DIR=${BACKUP_DIR}"
echo "SOURCE_DIR=${SOURCE_DIR:-<unset>}"

exec crond -f -l 2
