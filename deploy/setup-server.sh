#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  ONE-TIME SETUP for a fresh Hostinger VPS running Ubuntu 24.04
#  Installs: Node.js 22, PostgreSQL 16, Nginx, PM2, Certbot (free SSL), firewall
#
#  Run on the server as root:
#     bash /var/www/ammos/deploy/setup-server.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

DB_NAME="ammos"
DB_USER="ammos"
APP_DIR="/var/www/ammos"

echo "→ Updating the system…"
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
apt-get install -y curl ca-certificates gnupg ufw nginx postgresql postgresql-contrib certbot python3-certbot-nginx unzip rsync

echo "→ Installing Node.js 22 LTS…"
if ! command -v node >/dev/null || [[ "$(node -v)" != v22* ]]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi
node -v
npm install -g pm2

echo "→ Adding 2 GB swap (helps the build on small servers)…"
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "→ Creating the PostgreSQL database…"
DB_PASS="$(openssl rand -base64 30 | tr -dc 'A-Za-z0-9' | head -c 32)"
if sudo -u postgres psql -tAc "select 1 from pg_roles where rolname='${DB_USER}'" | grep -q 1; then
  echo "  user ${DB_USER} already exists — setting a new password"
  sudo -u postgres psql -c "alter user ${DB_USER} with password '${DB_PASS}';"
else
  sudo -u postgres psql -c "create user ${DB_USER} with password '${DB_PASS}';"
fi
sudo -u postgres psql -tAc "select 1 from pg_database where datname='${DB_NAME}'" | grep -q 1 || sudo -u postgres psql -c "create database ${DB_NAME} owner ${DB_USER};"

echo "→ Firewall: allow SSH + web only (PostgreSQL stays private)…"
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

mkdir -p "${APP_DIR}/uploads"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo " ✔ Server ready."
echo ""
echo " Put this line in ${APP_DIR}/.env  (copy it now!):"
echo ""
echo "   DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}"
echo ""
echo " A random JWT secret you can use:"
echo ""
echo "   JWT_SECRET=$(openssl rand -base64 48 | tr -d '\n=+/' | head -c 64)"
echo "════════════════════════════════════════════════════════════════"
