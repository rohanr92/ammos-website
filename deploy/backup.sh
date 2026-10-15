#!/usr/bin/env bash
# Daily backup of the database + uploaded photos. Keeps the last 14 days.
# Install once (runs every night at 03:30):
#   (crontab -l 2>/dev/null; echo "30 3 * * * bash /var/www/ammos/deploy/backup.sh >> /var/log/ammos-backup.log 2>&1") | crontab -
set -euo pipefail
BACKUP_DIR="/var/backups/ammos"
STAMP="$(date +%Y-%m-%d)"
mkdir -p "$BACKUP_DIR"

# read DATABASE_URL from the app's .env
DATABASE_URL="$(grep -E '^DATABASE_URL=' /var/www/ammos/.env | cut -d= -f2- | tr -d '"')"
pg_dump "$DATABASE_URL" | gzip > "$BACKUP_DIR/db-$STAMP.sql.gz"
tar -czf "$BACKUP_DIR/uploads-$STAMP.tar.gz" -C /var/www/ammos uploads

find "$BACKUP_DIR" -type f -mtime +14 -delete
echo "$(date) backup ok"
