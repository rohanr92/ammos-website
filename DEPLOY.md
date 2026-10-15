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
