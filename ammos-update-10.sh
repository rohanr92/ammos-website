#!/bin/bash
# Ammos website — update 10: one-command deploy to the Hostinger VPS
set -e
if [ ! -f components/admin/MediaBrowser.tsx ]; then echo "✖ Run this inside ammos-website."; exit 1; fi

mkdir -p "deploy"
cat > "deploy/install.sh" << 'AMMOS_EOF'
#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  AMMOS — FIRST INSTALL ON THE SERVER (Hostinger VPS, Ubuntu 24.04 / 26.04)
#  You normally don't run this by hand: "bash deploy/push.sh first" on your Mac
#  uploads the website and then runs this script on the server.
#
#  It installs Node.js, PostgreSQL, Nginx, PM2 and a free SSL certificate,
#  creates the database (or restores the one from your Mac), builds and starts
#  the website, and sets up daily backups. Safe to run again.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

DOMAIN="ammos.eu"
APP_DIR="/var/www/ammos"
DB_NAME="ammos"
DB_USER="ammos"
DUMP="${APP_DIR}/deploy-data/ammos.sql"
cd "$APP_DIR"

step() { echo ""; echo "━━━ $* ━━━"; }

step "1/9  Updating the server and installing tools"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y curl ca-certificates gnupg ufw nginx postgresql postgresql-contrib certbot python3-certbot-nginx rsync openssl

step "2/9  Installing Node.js 22"
if ! command -v node >/dev/null || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 20 ]; then
  if curl -fsSL https://deb.nodesource.com/setup_22.x | bash -; then
    apt-get install -y nodejs
  else
    echo "  NodeSource not available — using Ubuntu's Node.js"
    apt-get install -y nodejs npm
  fi
fi
echo "  Node $(node -v), npm $(npm -v)"
command -v pm2 >/dev/null || npm install -g pm2

step "3/9  Memory swap (makes the build safe)"
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

step "4/9  Database"
systemctl enable --now postgresql
if [ -f .env ] && grep -q '^DATABASE_URL=' .env; then
  echo "  .env already exists — keeping its database settings"
else
  DB_PASS="$(openssl rand -hex 24)"
  if sudo -u postgres psql -tAc "select 1 from pg_roles where rolname='${DB_USER}'" | grep -q 1; then
    sudo -u postgres psql -qc "alter user ${DB_USER} with password '${DB_PASS}';"
  else
    sudo -u postgres psql -qc "create user ${DB_USER} with password '${DB_PASS}';"
  fi
  sudo -u postgres psql -tAc "select 1 from pg_database where datname='${DB_NAME}'" | grep -q 1 || sudo -u postgres psql -qc "create database ${DB_NAME} owner ${DB_USER};"
  ADMIN_PASS="Ammos-$(openssl rand -hex 6)"
  cat > .env << ENV
SITE_URL=https://${DOMAIN}
DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}
JWT_SECRET=$(openssl rand -hex 48)
ADMIN_EMAIL=info@ammos.eu
ADMIN_PASSWORD=${ADMIN_PASS}
ADMIN_NAME=Ammos Admin
UPLOAD_DIR=${APP_DIR}/uploads
SMTP_HOST=
SMTP_PORT=465
SMTP_SECURE=true
SMTP_USER=info@ammos.eu
SMTP_PASS=
MAIL_FROM="Ammos Makenzy Beach <info@ammos.eu>"
MAIL_TO=info@ammos.eu
ENV
  chmod 600 .env
  echo "  ✔ .env created (new random database password and login secret)"
fi
DATABASE_URL="$(grep -E '^DATABASE_URL=' .env | cut -d= -f2- | tr -d '"')"
TABLES="$(psql "$DATABASE_URL" -tAc "select count(*) from information_schema.tables where table_schema='public'")"
FRESH=0
if [ "$TABLES" = "0" ] && [ -f "$DUMP" ]; then
  echo "  Restoring your database from the Mac (content, events, menu, gallery, admin users)…"
  psql "$DATABASE_URL" -q -v ON_ERROR_STOP=1 -f "$DUMP" > /dev/null
  echo "  ✔ Database restored"
elif [ "$TABLES" = "0" ]; then
  FRESH=1
fi
mkdir -p "${APP_DIR}/uploads"

step "5/9  Installing packages & building the website (2–4 minutes)"
npm ci --no-audit --no-fund
npm run db:migrate
if [ "$FRESH" = "1" ]; then npm run db:seed; fi
npm run build

step "6/9  Starting the website (PM2 keeps it running 24/7)"
if pm2 describe ammos >/dev/null 2>&1; then pm2 reload ammos; else pm2 start deploy/ecosystem.config.cjs; fi
pm2 save
pm2 startup systemd -u root --hp /root >/dev/null || true
systemctl enable pm2-root >/dev/null 2>&1 || true

step "7/9  Web server (Nginx) + firewall"
systemctl disable --now apache2 >/dev/null 2>&1 || true
cp deploy/nginx-ammos.conf /etc/nginx/sites-available/ammos
ln -sf /etc/nginx/sites-available/ammos /etc/nginx/sites-enabled/ammos
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx
systemctl reload nginx
ufw allow OpenSSH >/dev/null
ufw allow 'Nginx Full' >/dev/null
ufw --force enable >/dev/null

step "8/9  Free SSL certificate (https://)"
if [ -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
  echo "  SSL already installed"
else
  read -r -p "  Your email for SSL renewal notices (e.g. your Gmail): " SSL_EMAIL
  if certbot --nginx -d "${DOMAIN}" -d "www.${DOMAIN}" --redirect --agree-tos -m "${SSL_EMAIL}" -n; then
    echo "  ✔ https://${DOMAIN} is secured (renews automatically)"
  else
    echo "  ! SSL failed — usually the domain does not point to this server yet."
    echo "    Fix the DNS A records, wait 10 minutes, then run:  certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} --redirect"
  fi
fi

step "9/9  Nightly backups (database + photos, kept 14 days)"
( crontab -l 2>/dev/null | grep -v 'deploy/backup.sh' ; echo "30 3 * * * bash ${APP_DIR}/deploy/backup.sh >> /var/log/ammos-backup.log 2>&1" ) | crontab -

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  ✔ DONE — https://${DOMAIN} is live"
echo ""
echo "  Admin:  https://${DOMAIN}/admin"
if [ -f "$DUMP" ] && [ "$FRESH" = "0" ]; then
  echo "  Login with the SAME email & password you use on your Mac."
else
  echo "  Email:    $(grep -E '^ADMIN_EMAIL=' .env | cut -d= -f2-)"
  echo "  Password: $(grep -E '^ADMIN_PASSWORD=' .env | cut -d= -f2-)"
fi
echo "  → Change your password after the first login (My account & users)."
echo "════════════════════════════════════════════════════════════════"
AMMOS_EOF
echo "  ✔ deploy/install.sh"

mkdir -p "deploy"
cat > "deploy/push.sh" << 'AMMOS_EOF'
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
AMMOS_EOF
echo "  ✔ deploy/push.sh"

cat > "DEPLOY.md" << 'AMMOS_EOF'
# Deploying ammos.eu (Hostinger VPS + GoDaddy domain)

Server: Hostinger VPS `2.24.162.235` (Ubuntu) · Domain: `ammos.eu` at GoDaddy

## 0. Domain (GoDaddy → DNS Records) — already done ✔
| Type | Name | Data |
|------|------|------|
| A | @ | 2.24.162.235 |
| A | www | 2.24.162.235 |

## 1. One-time: log in to the server without typing the password every time (on your Mac)
```bash
ls ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
ssh-copy-id root@2.24.162.235        # type the VPS root password once
ssh root@2.24.162.235 "echo connected"
```
Root password: Hostinger → VPS → Settings → Change root password.

## 2. First deploy (on your Mac, inside the ammos-website folder)
```bash
bash deploy/push.sh first
```
Uploads the website, your photos and your database, then installs everything on the
server (Node, PostgreSQL, Nginx, free SSL, auto-restart, nightly backups).
When asked, type your email for SSL notices. At the end: https://ammos.eu is live.

## 3. Every later update
```bash
bash deploy/push.sh
```
Uploads new code + new photos and rebuilds. Bookings, messages and admin changes
made on the live site are kept (the database is NOT overwritten).

## Useful server commands (`ssh root@2.24.162.235`)
| What | Command |
|------|---------|
| Website logs | `pm2 logs ammos` |
| Restart | `pm2 reload ammos` |
| Status | `pm2 status` |
| Edit settings (email etc.) | `nano /var/www/ammos/.env` then `pm2 reload ammos` |
| Backups | `ls /var/backups/ammos` |

## Email (bookings & contact messages)
ammos.eu has **no email (MX) records yet**, so info@ammos.eu cannot receive mail.
Create a mailbox (Hostinger Email, Google Workspace or Zoho), add the MX/TXT records it
gives you in GoDaddy DNS, then put its SMTP details in `/var/www/ammos/.env`:
```
SMTP_HOST=smtp.hostinger.com   (Zoho: smtp.zoho.eu · Google: smtp.gmail.com)
SMTP_PORT=465
SMTP_SECURE=true
SMTP_USER=info@ammos.eu
SMTP_PASS=the-mailbox-password
```
`pm2 reload ammos`, then Admin → Dashboard → **Send test email**.
AMMOS_EOF
echo "  ✔ DEPLOY.md"

cat > ".gitignore" << 'AMMOS_EOF'
node_modules
.next
out
.env
.env.local
.env.production
uploads/
*.log
.DS_Store
next-env.d.ts
*.tsbuildinfo
deploy-data/
AMMOS_EOF
echo "  ✔ .gitignore"

chmod +x deploy/install.sh deploy/push.sh
echo ""
echo "✔ Deploy scripts ready. Next:  bash deploy/push.sh first"
