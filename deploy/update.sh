#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
#  Deploy / update the website on the server.
#  Run after uploading new code:   bash deploy/update.sh
# ─────────────────────────────────────────────────────────────
set -euo pipefail
cd /var/www/ammos

echo "→ Installing packages…"
npm ci --no-audit --no-fund

echo "→ Updating the database…"
npm run db:migrate

echo "→ Building the website (takes 1–3 minutes)…"
npm run build

echo "→ Restarting…"
if pm2 describe ammos >/dev/null 2>&1; then
  pm2 reload ammos
else
  pm2 start deploy/ecosystem.config.cjs
  pm2 save
fi
echo "✔ Live!"
