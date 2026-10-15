# Ammos Makenzy Beach — website + admin panel

Next.js 16 (React 19) · PostgreSQL · Drizzle ORM · JWT login · Nodemailer

```
Public website                     Admin panel (/admin)
──────────────                     ────────────────────
/                Homepage          Dashboard (bookings, messages, next events)
/events          Upcoming / past   Events          add, edit, delete
/events/[slug]   Detail + booking  Event bookings  confirm / cancel, email guest, CSV export
/events/calendar Month calendar    Messages        contact-form messages
/menu            Full menu         Menu items + categories
/our-story       About us          Gallery         bulk photo upload
/gallery         Photos            News & stories
/news            Blog              Reviews
/contact         Form + map        Page content    every text & photo on the site
/private-events  Enquiry form      Redirects       e.g. /ourmenu → /menu
/careers         "Not hiring"      My account      password, users
/house-rules, /privacy-policy, /legal-notice
```

---

## 1. Run it on your Mac (first time)

You need two free programs:

1. **Node.js 22 LTS** — download from <https://nodejs.org> and install.
   Check in the VS Code terminal: `node -v` → should print `v22…`
2. **Postgres.app** (the database) — download from <https://postgresapp.com>, drag it to Applications,
   open it and click **Initialize**. Leave it running (elephant icon in the menu bar).

Then:

1. Unzip `ammos-website.zip`, open VS Code → **File → Open Folder…** → choose the `ammos-website` folder.
2. Open the terminal in VS Code: **Terminal → New Terminal** and run the commands below one by one.

```bash
# 1) create your settings file
cp .env.example .env
```

3. Open the new `.env` file in VS Code and change these lines:

```bash
# Postgres.app uses your Mac username, no password:
DATABASE_URL=postgresql://YOUR_MAC_USERNAME@localhost:5432/ammos

# paste a random secret (generate one with the command below)
JWT_SECRET=paste-the-random-text-here

# your first admin login
ADMIN_EMAIL=info@ammos.eu
ADMIN_PASSWORD=choose-a-strong-password-123
```

Find your Mac username with `whoami`. Generate a JWT secret with:

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
```

4. Install and start:

```bash
npm install        # downloads the libraries (2–3 min the first time)
npm run setup      # creates the database, tables, and fills in menu/events/etc.
npm run dev        # starts the site
```

5. Open in your browser:
   - Website → <http://localhost:3000>
   - Admin → <http://localhost:3000/admin> (log in with ADMIN_EMAIL / ADMIN_PASSWORD)

Stop the site with **Ctrl + C** in the terminal. Next time you only need `npm run dev`.

> While `SMTP_HOST` is empty, emails from the forms are **printed in the terminal** instead of being sent — handy for testing.

---

## 2. Everyday commands

| Command | What it does |
|---|---|
| `npm run dev` | Start the site locally with live reload |
| `npm run build` then `npm start` | Run the fast production version locally |
| `npm run admin:create` | Add an admin, or reset a forgotten password |
| `npm run db:studio` | Browse the database in your browser |
| `npm run db:generate` | After changing `lib/db/schema.ts`: create a migration file |
| `npm run db:migrate` | Apply new migrations to the database |

---

## 3. Where things are

```
app/(site)/          public pages (one folder per page)
app/admin/           admin pages
app/api/             backend (forms, login, admin API, uploads)
components/site/     website building blocks (header, footer, cards, forms…)
components/admin/    admin building blocks
lib/content-schema.ts   ← all editable texts/photos and their default values
lib/admin/resources.ts  ← admin forms for events, menu, gallery, news…
lib/db/schema.ts        ← database tables
app/globals.css         ← website design (colours, fonts, animations, mobile)
app/admin/admin.css     ← admin design
scripts/seed-data/menu.md ← the menu imported on first setup
public/images/       design photos and logos
deploy/              server setup, Nginx, PM2, backups
```

**Brand:** cyan `#3ec6d8` · lime `#b7d44a` · midnight `#0f1119` · titles **Marcellus** · body **Jost**
(fonts are stored in `app/fonts`, so no Google Fonts request — faster and GDPR friendly).

---

## 4. How the pages are rendered (SEO)

- **Public pages are Server Components**, rendered on the server and cached as static HTML
  (Incremental Static Regeneration, refreshed every 5 minutes **and instantly when you save in the admin**).
  Google gets complete HTML on the first request → best for SEO and speed.
- Only small interactive parts run in the browser: header menu, sliders, menu hover photo, forms, gallery lightbox.
- The admin panel is dynamic (never cached) and hidden from Google (`noindex`, blocked in robots.txt).

SEO included: unique title/description per page, canonical URLs, Open Graph + Twitter cards (share image),
`sitemap.xml`, `robots.txt`, Google structured data (Restaurant/BarOrPub with opening hours, Event,
Menu, BlogPosting, Breadcrumbs), semantic HTML, alt texts, optimised images (AVIF/WebP), fast fonts.
`robots.txt` only allows Google once `SITE_URL` starts with `https://` (so test servers aren't indexed).

---

## 5. Security

- Admin passwords hashed with **bcrypt** (12 rounds), minimum 12 characters.
- Login creates a **JWT** (HS256, 8 hours) stored in an **HttpOnly, Secure, SameSite=Strict** cookie —
  JavaScript can't read it, other websites can't use it.
- Every admin API call re-checks the token **and** the user in the database (tokens can be revoked:
  changing the password or "Sign out other devices" logs out every old token).
- Brute-force protection: 10 login attempts / 15 min per IP, and an account locks for 15 min after 5 wrong passwords.
- CSRF protection (Origin check) on every form and admin action.
- All input validated with **zod**; database queries are parameterised (no SQL injection).
- Uploads: real image check + re-encoding with sharp (strips hidden content), video signature check, size limits.
- Spam protection on public forms: honeypot field, timing check, rate limits.
- Security headers (nosniff, frame protection, referrer policy); admin can never be framed.

---

## 6. Going live

See **DEPLOY.md** — step-by-step for your Hostinger VPS.
