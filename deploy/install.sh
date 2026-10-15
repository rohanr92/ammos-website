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
CRON_LINE="30 3 * * * bash ${APP_DIR}/deploy/backup.sh >> /var/log/ammos-backup.log 2>&1"
{ crontab -l 2>/dev/null | grep -v 'deploy/backup.sh' || true; echo "$CRON_LINE"; } | crontab -
echo "  ✔ backups run every night at 03:30 → /var/backups/ammos"

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
