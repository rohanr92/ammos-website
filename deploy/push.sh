#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Run this ON YOUR MAC, inside the ammos-website folder.
#
#   bash deploy/push.sh first   → first time: uploads the website, your photos
#                                  and your database, then installs everything
#                                  on the server
#   bash deploy/push.sh         → every update after that: uploads the code and
#                                  new photos and rebuilds (live data is kept)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
SERVER="${SERVER:-root@2.24.162.235}"
APP="/var/www/ammos"
MODE="${1:-update}"
SSH="ssh -o StrictHostKeyChecking=accept-new"
cd "$(dirname "$0")/.."

if [ ! -f package.json ] || ! grep -q '"ammos-website"' package.json; then
  echo "✖ Run this inside the ammos-website folder."; exit 1
fi

echo "→ Connecting to $SERVER …"
$SSH "$SERVER" "mkdir -p $APP/uploads $APP/deploy-data && (command -v rsync >/dev/null || (apt-get update -qq && apt-get install -y -qq rsync >/dev/null))"

EXCLUDES=(--exclude node_modules --exclude .next --exclude .env --exclude .env.local --exclude uploads --exclude deploy-data --exclude '.DS_Store' --exclude 'ammos-update-*.sh' --exclude .git)

if [ "$MODE" = "first" ]; then
  echo "→ Exporting your database from the Mac…"
  PGD="$(command -v pg_dump || true)"
  for p in /opt/homebrew/opt/postgresql@16/bin/pg_dump /usr/local/opt/postgresql@16/bin/pg_dump /Applications/Postgres.app/Contents/Versions/latest/bin/pg_dump; do
    [ -z "$PGD" ] && [ -x "$p" ] && PGD="$p"
  done
  if [ -z "$PGD" ]; then echo "✖ pg_dump not found (is PostgreSQL installed on the Mac?)"; exit 1; fi
  DBURL="$(grep -E '^DATABASE_URL=' .env | cut -d= -f2- | tr -d '"')"
  mkdir -p deploy-data
  "$PGD" --no-owner --no-privileges "$DBURL" > deploy-data/ammos.sql
  echo "  ✔ database exported ($(du -h deploy-data/ammos.sql | cut -f1))"
  rsync -az deploy-data/ammos.sql "$SERVER:$APP/deploy-data/ammos.sql"
fi

echo "→ Uploading the website code…"
rsync -az --delete "${EXCLUDES[@]}" ./ "$SERVER:$APP/"
echo "→ Uploading photos & videos (only new ones)…"
rsync -az --ignore-existing ./uploads/ "$SERVER:$APP/uploads/"

if [ "$MODE" = "first" ]; then
  echo "→ Installing on the server (5–10 minutes)…"
  $SSH -t "$SERVER" "bash $APP/deploy/install.sh"
else
  echo "→ Rebuilding on the server…"
  $SSH -t "$SERVER" "bash $APP/deploy/update.sh"
fi
