#!/bin/bash
# Ammos website — update 2
# Event photos, live menu sync, hero photo/video switch, chefs badge removed,
# smaller story photos, About page numbers removed, news carousel on mobile.
# Run from inside the ammos-website folder:  bash ammos-update-2.sh
set -e
if [ ! -f package.json ] || ! grep -q "\"ammos-website\"" package.json; then
  echo "✖ Run this inside the ammos-website folder (cd into it first)."; exit 1
fi
echo "→ Updating files…"

cat > "package.json" << 'AMMOS_EOF'
{
  "name": "ammos-website",
  "version": "1.0.0",
  "private": true,
  "description": "Ammos Makenzy Beach — website, events booking and admin panel",
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start -p ${PORT:-3000}",
    "typecheck": "tsc --noEmit",
    "db:create": "tsx scripts/create-db.ts",
    "db:generate": "drizzle-kit generate",
    "db:migrate": "tsx scripts/migrate.ts",
    "db:seed": "tsx scripts/seed.ts",
    "db:studio": "drizzle-kit studio",
    "admin:create": "tsx scripts/create-admin.ts",
    "menu:sync": "tsx scripts/sync-menu.ts",
    "setup": "npm run db:create && npm run db:migrate && npm run db:seed"
  },
  "engines": {
    "node": ">=20.9.0"
  },
  "dependencies": {
    "@phosphor-icons/react": "2.1.10",
    "bcryptjs": "3.0.3",
    "drizzle-orm": "0.45.4",
    "jose": "6.2.12",
    "lenis": "1.3.26",
    "next": "16.4.1",
    "nodemailer": "10.1.1",
    "pg": "8.23.1",
    "react": "19.3.1",
    "react-dom": "19.3.1",
    "server-only": "0.0.1",
    "sharp": "0.35.5",
    "zod": "4.6.7"
  },
  "devDependencies": {
    "@types/node": "22.20.5",
    "@types/nodemailer": "8.0.2",
    "@types/pg": "8.23.1",
    "@types/react": "19.3.0",
    "@types/react-dom": "19.3.0",
    "dotenv": "18.0.8",
    "drizzle-kit": "0.31.11",
    "tsx": "4.23.15",
    "typescript": "5.9.3"
  }
}
AMMOS_EOF
echo "  ✔ package.json"

mkdir -p "lib"
cat > "lib/menu-import.ts" << 'AMMOS_EOF'
/**
 * MENU IMPORT
 * Reads the live Ammos menu (https://ammos-beach-bar.nina.cy/menu.md) and
 * copies it into the website database.
 *
 * Sync rules (safe to run as often as you like):
 *  - new dishes / drinks are added
 *  - prices, descriptions, allergens and tags are updated
 *  - your own photos, "show on homepage" ticks and categories are kept
 *  - items that disappeared from the live menu are hidden (not deleted)
 *
 * Used by: npm run db:seed, npm run menu:sync and Admin → Menu items → "Sync from live menu".
 */
import { and, eq, notInArray } from "drizzle-orm";
import type { NodePgDatabase } from "drizzle-orm/node-postgres";
import * as schema from "./db/schema";

export const LIVE_MENU_URL = "https://ammos-beach-bar.nina.cy/menu.md";
export const LIVE_MENU_PAGE = "https://ammos-beach-bar.nina.cy/?step=menu";

type Db = NodePgDatabase<typeof schema>;

export type ParsedItem = { name: string; price: string; description: string; allergens: string; tags: string };
export type ParsedCat = { section: string; name: string; items: ParsedItem[] };

/** Live category name → name shown on the website (keeps the names the admin already knows). */
const CATEGORY_NAMES: Record<string, string> = {
  "Food/Appetisers": "Starters",
  "Food/Main": "Mains",
  "Early Bites/": "Breakfast & Brunch",
  "Cocktails/": "Cocktails",
  "Cocktails/Signature Cocktails": "Cocktails",
  "Cocktails/Non-Alcoholic": "Non-Alcoholic Cocktails",
  "Beverages/Tea Flavors": "Tea",
  "Wines/White": "White Wine",
  "Wines/Rose": "Rosé Wine",
  "Wines/Rosé": "Rosé Wine",
  "Wines/Red": "Red Wine",
  "Beers/Bottles": "Bottled Beer",
  "Spirits/Cognac": "Cognac & Brandy",
  "Whisky/Blended Malt": "Blended Whisky",
  "Other/": "Beach & Extras",
};

export function displayCategoryName(section: string, liveName: string) {
  const key = `${section}/${liveName}`;
  return CATEGORY_NAMES[key] ?? (liveName || section);
}

export function slugify(s: string) {
  return s
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

/** Turns the menu.md text into sections → categories → items. */
export function parseMenu(md: string): ParsedCat[] {
  const cats: ParsedCat[] = [];
  let section = "Food";
  let cat: ParsedCat | null = null;
  let item: ParsedItem | null = null;
  let pendingCatName: string | null = null; // "### X" seen, created when the first item arrives

  const ensureCat = () => {
    if (cat) return cat;
    const name = displayCategoryName(section, pendingCatName ?? "");
    cat = cats.find((c) => c.section === section && c.name === name) ?? null;
    if (!cat) {
      cat = { section, name, items: [] };
      cats.push(cat);
    }
    return cat;
  };

  for (const raw of md.replace(/\r/g, "").split("\n")) {
    const line = raw.trim();
    if (!line || line === "---" || /^# /.test(line)) continue;

    if (line.startsWith("#### ")) {
      const head = line.slice(5).trim();
      const m = /^(.+?)\s+[—–-]\s+€\s?([\d.,]+)\s*$/.exec(head);
      const name = (m ? m[1] : head).trim();
      const price = m ? String(Number(m[2].replace(/,/g, "")) || 0) : "0";
      item = { name, price: Number(price).toFixed(2), description: "", allergens: "", tags: "" };
      ensureCat().items.push(item);
    } else if (line.startsWith("### ")) {
      const n = line.slice(4).trim();
      pendingCatName = /^none$/i.test(n) ? "" : n;
      cat = null;
      item = null;
    } else if (line.startsWith("## ")) {
      section = line.slice(3).trim();
      pendingCatName = null;
      cat = null;
      item = null;
    } else if (item) {
      if (/\*\*(Allergens|Tags):\*\*/i.test(line)) {
        for (const part of line.replace(/^-\s*/, "").split("|")) {
          const p = /\*\*(Allergens|Tags):\*\*\s*(.*)$/i.exec(part.trim());
          if (!p) continue;
          const val = p[2].trim().replace(/_/g, " ");
          const nice = (v: string) => v.toLowerCase().replace(/\b\w/g, (c) => c.toUpperCase());
          if (p[1].toLowerCase() === "allergens") {
            // "vegan" / "vegetarian" are diet labels, not allergens → show them as green tags
            const list = val.split(",").map((v) => v.trim()).filter(Boolean);
            const diet = list.filter((v) => /^(vegan|vegetarian|gluten[ -]free)$/i.test(v));
            item.allergens = list.filter((v) => !diet.includes(v)).join(", ");
            if (diet.length) item.tags = [item.tags, ...diet.map(nice)].filter(Boolean).join(", ");
          } else item.tags = [item.tags, nice(val)].filter(Boolean).join(", ");
        }
      } else {
        item.description = item.description ? `${item.description}\n${line}` : line;
      }
    }
  }
  return cats.filter((c) => c.items.length > 0);
}

/** Downloads the live menu text. Throws if the menu site can't be reached. */
export async function fetchLiveMenu(): Promise<string> {
  const res = await fetch(LIVE_MENU_URL, { headers: { "User-Agent": "ammos.eu menu sync" }, cache: "no-store", signal: AbortSignal.timeout(20000) });
  if (!res.ok) throw new Error(`The live menu returned ${res.status}`);
  const text = await res.text();
  if (!text.includes("#### ")) throw new Error("The live menu file looks empty or changed format");
  return text;
}

export type SyncResult = { categories: number; added: number; updated: number; hidden: number; total: number };

/** Copies the parsed menu into the database (see rules at the top of this file). */
export async function syncMenu(db: Db, cats: ParsedCat[]): Promise<SyncResult> {
  if (!cats.length) throw new Error("No menu items found — nothing was changed.");
  const result: SyncResult = { categories: cats.length, added: 0, updated: 0, hidden: 0, total: 0 };
  const keepIds: string[] = [];

  const existingCats = await db.select().from(schema.menuCategories);
  const usedSlugs = new Set(existingCats.map((c) => c.slug));

  for (const [ci, c] of cats.entries()) {
    // 1. category: reuse by name (case-insensitive), otherwise create
    let cat = existingCats.find((x) => x.name.toLowerCase() === c.name.toLowerCase());
    if (cat) {
      await db.update(schema.menuCategories).set({ section: c.section, sortOrder: (ci + 1) * 10, updatedAt: new Date() }).where(eq(schema.menuCategories.id, cat.id));
    } else {
      let s = slugify(c.name) || `category-${ci + 1}`;
      for (let i = 2; usedSlugs.has(s); i++) s = `${slugify(c.name)}-${i}`;
      usedSlugs.add(s);
      [cat] = await db.insert(schema.menuCategories).values({ name: c.name, slug: s, section: c.section, sortOrder: (ci + 1) * 10 }).returning();
      existingCats.push(cat);
    }

    // 2. items: match by name inside the category (2nd "Black Sheep Rose" matches the 2nd one, etc.)
    const existing = await db.select().from(schema.menuItems).where(eq(schema.menuItems.categoryId, cat.id));
    const pool = new Map<string, typeof existing>();
    for (const row of existing.sort((a, b) => a.sortOrder - b.sortOrder)) {
      const k = row.name.trim().toLowerCase();
      pool.set(k, [...(pool.get(k) ?? []), row]);
    }

    for (const [ii, it] of c.items.entries()) {
      const k = it.name.toLowerCase();
      const match = pool.get(k)?.shift();
      const data = {
        name: it.name,
        price: it.price,
        description: it.description,
        allergens: it.allergens,
        tags: it.tags,
        sortOrder: (ii + 1) * 10,
        published: true,
      };
      if (match) {
        await db.update(schema.menuItems).set({ ...data, updatedAt: new Date() }).where(eq(schema.menuItems.id, match.id));
        keepIds.push(match.id);
        result.updated++;
      } else {
        const [row] = await db.insert(schema.menuItems).values({ ...data, categoryId: cat.id }).returning({ id: schema.menuItems.id });
        keepIds.push(row.id);
        result.added++;
      }
      result.total++;
    }
  }

  // 3. hide everything that is no longer on the live menu
  if (keepIds.length) {
    const hidden = await db
      .update(schema.menuItems)
      .set({ published: false, updatedAt: new Date() })
      .where(and(eq(schema.menuItems.published, true), notInArray(schema.menuItems.id, keepIds)))
      .returning({ id: schema.menuItems.id });
    result.hidden = hidden.length;
  }
  return result;
}
AMMOS_EOF
echo "  ✔ lib/menu-import.ts"

mkdir -p "scripts"
cat > "scripts/sync-menu.ts" << 'AMMOS_EOF'
/**
 * Updates the website menu from the live Ammos menu (ammos-beach-bar.nina.cy).
 * Run:  npm run menu:sync
 * Keeps your photos and "show on homepage" ticks. Items removed from the live menu are hidden.
 */
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fetchLiveMenu, parseMenu, syncMenu, LIVE_MENU_URL } from "../lib/menu-import";
import { db, pool } from "./db";

async function main() {
  let md: string;
  try {
    console.log(`→ Downloading ${LIVE_MENU_URL} …`);
    md = await fetchLiveMenu();
  } catch (err) {
    if (!process.argv.includes("--offline")) throw err;
    console.log(`! Could not download (${(err as Error).message}) — using scripts/seed-data/menu.md`);
    md = readFileSync(join(process.cwd(), "scripts/seed-data/menu.md"), "utf8");
  }
  const cats = parseMenu(md);
  const r = await syncMenu(db, cats);
  console.log(`✔ Menu synced: ${r.categories} categories, ${r.total} items (${r.added} new, ${r.updated} updated, ${r.hidden} hidden)`);
}

main()
  .catch((err) => {
    console.error("✖ Menu sync failed:", err.message || err);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
AMMOS_EOF
echo "  ✔ scripts/sync-menu.ts"

mkdir -p "scripts"
cat > "scripts/seed.ts" << 'AMMOS_EOF'
/**
 * Fills an empty database with the starting content:
 *  - first admin account (from ADMIN_EMAIL / ADMIN_PASSWORD in .env)
 *  - the full Ammos menu (scripts/seed-data/menu.md)
 *  - example events, news, reviews, gallery photos, and the /ourmenu redirect
 *
 * Run:  npm run db:seed
 * Safe to run again: each part is only added if that table is still empty.
 */
import { readFileSync } from "node:fs";
import { join } from "node:path";
import bcrypt from "bcryptjs";
import { inArray } from "drizzle-orm";
import { fetchLiveMenu, parseMenu, syncMenu } from "../lib/menu-import";
import { db, pool, schema } from "./db";

const slug = (s: string) =>
  s
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

/* ───────── helpers for dates in Cyprus time ───────── */
function cyprusDate(daysFromToday: number, hh: number, mm = 0) {
  const now = new Date();
  const local = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + daysFromToday, hh, mm));
  // Cyprus is UTC+2 in winter, UTC+3 in summer — work out the real offset for that day
  const fmt = new Intl.DateTimeFormat("en-US", { timeZone: "Europe/Nicosia", hour: "2-digit", hourCycle: "h23" });
  const offset = Number(fmt.format(local)) - hh;
  return new Date(local.getTime() - ((offset + 24) % 24) * 3600_000);
}
function nextWeekday(target: number, minDays = 1) {
  const today = new Date().getUTCDay();
  let d = (target - today + 7) % 7;
  if (d < minDays) d += 7;
  return d;
}

async function seedAdmin() {
  if ((await db.$count(schema.adminUsers)) > 0) return console.log("• Admin users exist — skipped");
  const email = (process.env.ADMIN_EMAIL || "").trim().toLowerCase();
  const password = process.env.ADMIN_PASSWORD || "";
  if (!email || password.length < 12) {
    console.log("! ADMIN_EMAIL / ADMIN_PASSWORD (12+ chars) not set in .env — run `npm run admin:create` later.");
    return;
  }
  await db.insert(schema.adminUsers).values({
    email,
    name: process.env.ADMIN_NAME || "Ammos Admin",
    passwordHash: await bcrypt.hash(password, 12),
    role: "owner",
  });
  console.log(`✔ Admin created: ${email}  (change the password after your first login)`);
}

/* ───────── menu ───────── */
// dishes shown in the homepage menu block (you can change these in Admin → Menu items → "Show on homepage")
const FEATURED = [
  "Salmon Tiratido", "Mussels Nero", "Tataki Tuna", "Oktapodi Kythira",
  "Seabass Fricassee", "Seaside Orzotto", "Rib Eye Uruguay Angus", "Pyraclea Chicken",
  "Ammos Roll", "Caldera Roll", "Peruvian Rainbow Roll", "Geisha Sashimi Mix",
  "Ammos Star", "Cyprus Strawberries", "Girl Code", "Spicy Mangorita",
];

async function seedMenu() {
  if ((await db.$count(schema.menuCategories)) > 0) return console.log("• Menu exists — skipped (run `npm run menu:sync` to update it)");
  let md: string;
  try {
    md = await fetchLiveMenu();
    console.log("• Live menu downloaded from ammos-beach-bar.nina.cy");
  } catch (err) {
    console.log(`! Live menu not reachable (${(err as Error).message}) — using scripts/seed-data/menu.md`);
    md = readFileSync(join(process.cwd(), "scripts/seed-data/menu.md"), "utf8");
  }
  const r = await syncMenu(db, parseMenu(md));
  await db.update(schema.menuItems).set({ featured: true }).where(inArray(schema.menuItems.name, FEATURED));
  console.log(`✔ Menu imported: ${r.categories} categories, ${r.total} items`);
}

/* ───────── events ───────── */
const SAMPLE_GALLERY = ["/images/party.jpg", "/images/bartender.jpg", "/images/bar-interior.jpg", "/images/awards-interior.jpg", "/images/chef-plate.jpg", "/images/flowers.jpg"];
async function seedEvents() {
  if ((await db.$count(schema.events)) > 0) return console.log("• Events exist — skipped");
  const fri = nextWeekday(5);
  const upcoming = [
    { title: "Sunset sessions w/ Nikos K", category: "Live DJ", venue: "Terrace", day: fri, h: 19, image: "/images/bartender.jpg", price: "Free entry", cap: 180,
      summary: "Golden-hour house and disco on the terrace as the sun drops into the bay.",
      description: "Our resident Nikos K takes over the decks from sunset until late with a set of deep house, nu-disco and Balearic grooves.\n\nArrive early for the best seats on the terrace and the first round of signature cocktails.\n\n## Good to know\n- Smart-casual dress code after 20:00\n- Tables for 4+ are best booked in advance" },
    { title: "Full moon beach party", category: "Party", venue: "Beach", day: fri + 1, h: 21, image: "/images/party.jpg", price: "€15 entry incl. welcome drink", cap: 400,
      summary: "Barefoot on the sand under the full moon — fire shows, guest DJs and the bar open till late.",
      description: "Once a month we light up the beach for our full moon party.\n\nExpect guest DJs, fire performers and a beach bar serving our signature cocktails until the early hours.\n\n## Good to know\n- 18+ only, ID may be requested\n- Entry includes one welcome drink" },
    { title: "Long table Sunday brunch", category: "Dining", venue: "Restaurant", day: fri + 2, h: 11, m: 30, image: "/images/chef-plate.jpg", price: "€35 per person", cap: 60,
      summary: "One long table, sharing plates, bottomless coffee and a live acoustic duo.",
      description: "Our Sunday ritual: a long table set by the sea, sharing plates from the kitchen, fresh juices and a live acoustic duo.\n\nVegetarian and vegan options available — tell us about allergies in your booking." },
    { title: "Acoustic nights: Elena & band", category: "Live music", venue: "Terrace", day: fri + 6, h: 20, image: "/images/flowers.jpg", price: "Free entry", cap: 150,
      summary: "Elena and her band play soul, bossa and Greek classics under the stars.",
      description: "An easy evening of live soul, bossa nova and Greek classics. Book a table for dinner and stay for the music." },
    { title: "Cypriot wine & meze evening", category: "Tasting", venue: "Bar", day: fri + 7, h: 19, m: 30, image: "/images/awards-interior.jpg", price: "€45 per person", cap: 40,
      summary: "Five Cypriot wines paired with five meze plates, hosted by our sommelier.",
      description: "Discover the island's best producers — Kyperounda, Zambartas and more — paired with five meze plates from our kitchen.\n\nLimited to 40 guests." },
    { title: "Ammos summer closing party", category: "Live DJ", venue: "Terrace", day: fri + 8, h: 21, image: "/images/bar-interior.jpg", price: "Free entry", cap: 400,
      summary: "Our resident DJs close the season in style.",
      description: "Join us to celebrate another unforgettable summer on Makenzy Beach with our resident DJs and special guests." },
  ];
  const past = [
    { title: "Charity dinner 2021", category: "Community", venue: "Restaurant", at: "2021-11-20T18:00:00Z", image: "/images/news-1.jpg", summary: "A night of giving back on the strip, with every cover donated.", description: "A night of giving back on the strip, with every cover donated to local charities." },
    { title: "New Year's Eve 2022", category: "Party", venue: "Terrace", at: "2021-12-31T20:00:00Z", image: "/images/news-2.jpg", summary: "Counting down with 400 of our closest friends on the terrace.", description: "Counting down with 400 of our closest friends on the terrace." },
    { title: "Ammos veterans reunion", category: "Party", venue: "Bar", at: "2021-08-14T18:00:00Z", image: "/images/news-3.jpg", summary: "Eight years of regulars, back in one room for one long night.", description: "Eight years of regulars, back in one room for one long night." },
  ];
  await db.insert(schema.events).values([
    ...upcoming.map((e) => ({
      title: e.title,
      slug: slug(e.title),
      category: e.category,
      venue: e.venue,
      startsAt: cyprusDate(e.day, e.h, e.m ?? 0),
      summary: e.summary,
      description: e.description,
      image: e.image,
      gallery: SAMPLE_GALLERY.filter((g) => g !== e.image).slice(0, 5),
      priceInfo: e.price,
      capacity: e.cap,
      featured: true,
    })),
    ...past.map((e) => ({
      title: e.title,
      slug: slug(e.title),
      category: e.category,
      venue: e.venue,
      startsAt: new Date(e.at),
      summary: e.summary,
      description: e.description,
      image: e.image,
      bookingEnabled: false,
      featured: false,
    })),
  ]);
  console.log(`✔ Events added: ${upcoming.length} upcoming, ${past.length} past (edit or delete them in Admin → Events)`);
}

async function seedPosts() {
  if ((await db.$count(schema.posts)) > 0) return console.log("• News exists — skipped");
  const posts = [
    { title: "Charity dinner 2021", kicker: "Community", image: "/images/news-1.jpg", date: "2021-11-20", excerpt: "A night of giving back on the strip, with every cover donated.",
      content: "In November we opened our doors for a very special evening: every cover from our charity dinner went straight to local causes in Larnaca.\n\nThank you to everyone who joined us, to our team who gave their time, and to the partners who made it possible.\n\n## What we raised\nTogether we raised funds for children's charities in the Larnaca district — and had a beautiful night doing it." },
    { title: "NYE 2022", kicker: "Party", image: "/images/news-2.jpg", date: "2022-01-01", excerpt: "Counting down with 400 of our closest friends on the terrace.",
      content: "What a way to welcome the new year! 400 friends, a packed terrace, fireworks over the bay and our DJs playing until sunrise.\n\nSee you this year — keep an eye on our **events page** for New Year's Eve tickets." },
    { title: "Ammos veterans reunion", kicker: "Reunion", image: "/images/news-3.jpg", date: "2021-08-14", excerpt: "Eight years of regulars, back in one room for one long night.",
      content: "Some of you have been with us since the very first summer. This August we brought our regulars — and former team members — back together for one long night of stories, music and plenty of cocktails.\n\nHere's to the next twenty years on the strip." },
  ];
  await db.insert(schema.posts).values(
    posts.map((p) => ({ title: p.title, slug: slug(p.title), kicker: p.kicker, image: p.image, excerpt: p.excerpt, content: p.content, publishedAt: new Date(`${p.date}T12:00:00Z`) })),
  );
  console.log(`✔ News added: ${posts.length} stories`);
}

async function seedReviews() {
  if ((await db.$count(schema.reviews)) > 0) return console.log("• Reviews exist — skipped");
  const reviews = [
    { name: "Maria P.", meta: "Google · Larnaca", text: "Best spot on the Makenzy strip. The octopus is unreal and the sunset from the terrace is worth the trip alone." },
    { name: "James R.", meta: "Google · London", text: "Came for brunch, stayed for the DJ. Staff know the menu inside out and genuinely care. We came back three nights in a row." },
    { name: "Andreas C.", meta: "Google · Nicosia", text: "Booked a birthday table for 12. Everything was handled, the food came out together and the cocktails kept coming." },
    { name: "Sofia K.", meta: "Google · Limassol", text: "Sunbeds in the morning, lunch by the water, cocktails at sunset. You never need to leave." },
    { name: "Daniel W.", meta: "Google · Berlin", text: "The Ammos Star cocktail alone is worth the flight. Great music, zero attitude, lovely people." },
    { name: "Elena M.", meta: "Google · Athens", text: "Twenty-one years and still the best beach bar in Larnaca. The new look is gorgeous." },
  ];
  await db.insert(schema.reviews).values(reviews.map((r, i) => ({ ...r, sortOrder: (i + 1) * 10 })));
  console.log(`✔ Reviews added: ${reviews.length} (replace them with your real Google reviews in Admin → Reviews)`);
}

async function seedGallery() {
  if ((await db.$count(schema.galleryImages)) > 0) return console.log("• Gallery exists — skipped");
  const imgs = [
    ["bar-interior", "The Ammos bar", "The Bar"],
    ["bartender", "Cocktails being made at the bar", "The Bar"],
    ["party", "Party night at Ammos", "Events"],
    ["chef-plate", "Signature dish from the Ammos kitchen", "Food"],
    ["flowers", "Table details at Ammos", "The Beach"],
    ["awards-interior", "Inside Ammos Makenzy Beach", "The Beach"],
    ["hero-kitchen", "The Ammos kitchen", "Food"],
    ["news-1", "Charity dinner at Ammos", "Events"],
    ["news-2", "New Year's Eve at Ammos", "Events"],
    ["news-3", "Ammos veterans reunion", "Events"],
  ];
  await db.insert(schema.galleryImages).values(imgs.map(([f, alt, album], i) => ({ image: `/images/${f}.jpg`, alt, album, sortOrder: (i + 1) * 10 })));
  console.log(`✔ Gallery added: ${imgs.length} photos`);
}

async function seedRedirects() {
  if ((await db.$count(schema.redirects)) > 0) return console.log("• Redirects exist — skipped");
  await db.insert(schema.redirects).values([
    { fromPath: "/ourmenu", toPath: "/menu" },
    { fromPath: "/our-menu", toPath: "/menu" },
    { fromPath: "/food-menu", toPath: "/menu" },
    { fromPath: "/about", toPath: "/our-story" },
    { fromPath: "/about-us", toPath: "/our-story" },
    { fromPath: "/book", toPath: "/events" },
  ]);
  console.log("✔ Redirects added (e.g. ammos.eu/ourmenu → /menu)");
}

async function main() {
  console.log("→ Seeding database…");
  await seedAdmin();
  await seedMenu();
  await seedEvents();
  await seedPosts();
  await seedReviews();
  await seedGallery();
  await seedRedirects();
  console.log("✔ Done.");
}

main()
  .catch((err) => {
    console.error("✖ Seed failed:", err);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
AMMOS_EOF
echo "  ✔ scripts/seed.ts"

mkdir -p "drizzle"
cat > "drizzle/0001_event_gallery.sql" << 'AMMOS_EOF'
ALTER TABLE "events" ADD COLUMN IF NOT EXISTS "gallery" jsonb DEFAULT '[]'::jsonb NOT NULL;--> statement-breakpoint
-- remove the placeholder dish photos that the first install put on menu items (real photos uploaded in the admin are kept)
UPDATE "menu_items" SET "image" = '' WHERE "image" IN ('/images/chef-plate.jpg','/images/flowers.jpg','/images/awards-interior.jpg','/images/hero-kitchen.jpg','/images/party.jpg','/images/bartender.jpg','/images/bar-interior.jpg');--> statement-breakpoint
-- example photos for the example events (replace them in Admin → Events)
UPDATE "events" SET "gallery" = '["/images/party.jpg","/images/bartender.jpg","/images/bar-interior.jpg","/images/awards-interior.jpg","/images/chef-plate.jpg"]'::jsonb WHERE "gallery" = '[]'::jsonb AND "image" LIKE '/images/%';
AMMOS_EOF
echo "  ✔ drizzle/0001_event_gallery.sql"

mkdir -p "drizzle/meta"
cat > "drizzle/meta/_journal.json" << 'AMMOS_EOF'
{
  "version": "7",
  "dialect": "postgresql",
  "entries": [
    {
      "idx": 0,
      "version": "7",
      "when": 1792052067838,
      "tag": "0000_init",
      "breakpoints": true
    },
    {
      "idx": 1,
      "version": "7",
      "when": 1792060864108,
      "tag": "0001_event_gallery",
      "breakpoints": true
    }
  ]
}
AMMOS_EOF
echo "  ✔ drizzle/meta/_journal.json"

mkdir -p "drizzle/meta"
cat > "drizzle/meta/0001_snapshot.json" << 'AMMOS_EOF'
{
  "id": "6fe722f4-c209-4240-ba9b-11411671c10c",
  "prevId": "2c32bf74-5769-4262-9fc5-c6eb5209a1c4",
  "version": "7",
  "dialect": "postgresql",
  "tables": {
    "public.admin_users": {
      "name": "admin_users",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "email": {
          "name": "email",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "name": {
          "name": "name",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "password_hash": {
          "name": "password_hash",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "role": {
          "name": "role",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'editor'"
        },
        "token_version": {
          "name": "token_version",
          "type": "integer",
          "primaryKey": false,
          "notNull": true,
          "default": 1
        },
        "failed_logins": {
          "name": "failed_logins",
          "type": "integer",
          "primaryKey": false,
          "notNull": true,
          "default": 0
        },
        "locked_until": {
          "name": "locked_until",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": false
        },
        "last_login_at": {
          "name": "last_login_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": false
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {
        "admin_users_email_idx": {
          "name": "admin_users_email_idx",
          "columns": [
            {
              "expression": "email",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": true,
          "concurrently": false,
          "method": "btree",
          "with": {}
        }
      },
      "foreignKeys": {},
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.bookings": {
      "name": "bookings",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "reference": {
          "name": "reference",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "event_id": {
          "name": "event_id",
          "type": "uuid",
          "primaryKey": false,
          "notNull": false
        },
        "event_title": {
          "name": "event_title",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "event_date": {
          "name": "event_date",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": false
        },
        "first_name": {
          "name": "first_name",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "last_name": {
          "name": "last_name",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "email": {
          "name": "email",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "phone": {
          "name": "phone",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "guests": {
          "name": "guests",
          "type": "integer",
          "primaryKey": false,
          "notNull": true,
          "default": 2
        },
        "seating": {
          "name": "seating",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "occasion": {
          "name": "occasion",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "message": {
          "name": "message",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "status": {
          "name": "status",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'pending'"
        },
        "admin_notes": {
          "name": "admin_notes",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "marketing_opt_in": {
          "name": "marketing_opt_in",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": false
        },
        "ip": {
          "name": "ip",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {
        "bookings_reference_idx": {
          "name": "bookings_reference_idx",
          "columns": [
            {
              "expression": "reference",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": true,
          "concurrently": false,
          "method": "btree",
          "with": {}
        },
        "bookings_event_idx": {
          "name": "bookings_event_idx",
          "columns": [
            {
              "expression": "event_id",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": false,
          "concurrently": false,
          "method": "btree",
          "with": {}
        },
        "bookings_created_idx": {
          "name": "bookings_created_idx",
          "columns": [
            {
              "expression": "created_at",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": false,
          "concurrently": false,
          "method": "btree",
          "with": {}
        }
      },
      "foreignKeys": {
        "bookings_event_id_events_id_fk": {
          "name": "bookings_event_id_events_id_fk",
          "tableFrom": "bookings",
          "tableTo": "events",
          "columnsFrom": [
            "event_id"
          ],
          "columnsTo": [
            "id"
          ],
          "onDelete": "set null",
          "onUpdate": "no action"
        }
      },
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.events": {
      "name": "events",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "title": {
          "name": "title",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "slug": {
          "name": "slug",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "category": {
          "name": "category",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'Party'"
        },
        "venue": {
          "name": "venue",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'Terrace'"
        },
        "starts_at": {
          "name": "starts_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true
        },
        "ends_at": {
          "name": "ends_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": false
        },
        "summary": {
          "name": "summary",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "description": {
          "name": "description",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "image": {
          "name": "image",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "gallery": {
          "name": "gallery",
          "type": "jsonb",
          "primaryKey": false,
          "notNull": true,
          "default": "'[]'::jsonb"
        },
        "price_info": {
          "name": "price_info",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "capacity": {
          "name": "capacity",
          "type": "integer",
          "primaryKey": false,
          "notNull": false
        },
        "booking_enabled": {
          "name": "booking_enabled",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "featured": {
          "name": "featured",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "published": {
          "name": "published",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {
        "events_slug_idx": {
          "name": "events_slug_idx",
          "columns": [
            {
              "expression": "slug",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": true,
          "concurrently": false,
          "method": "btree",
          "with": {}
        },
        "events_starts_idx": {
          "name": "events_starts_idx",
          "columns": [
            {
              "expression": "starts_at",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": false,
          "concurrently": false,
          "method": "btree",
          "with": {}
        }
      },
      "foreignKeys": {},
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.gallery_images": {
      "name": "gallery_images",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "image": {
          "name": "image",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "alt": {
          "name": "alt",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "album": {
          "name": "album",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'The Beach'"
        },
        "show_on_home": {
          "name": "show_on_home",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "sort_order": {
          "name": "sort_order",
          "type": "integer",
          "primaryKey": false,
          "notNull": true,
          "default": 0
        },
        "published": {
          "name": "published",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {},
      "foreignKeys": {},
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.menu_categories": {
      "name": "menu_categories",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "name": {
          "name": "name",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "slug": {
          "name": "slug",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "section": {
          "name": "section",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'Food'"
        },
        "description": {
          "name": "description",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "sort_order": {
          "name": "sort_order",
          "type": "integer",
          "primaryKey": false,
          "notNull": true,
          "default": 0
        },
        "published": {
          "name": "published",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {
        "menu_categories_slug_idx": {
          "name": "menu_categories_slug_idx",
          "columns": [
            {
              "expression": "slug",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": true,
          "concurrently": false,
          "method": "btree",
          "with": {}
        }
      },
      "foreignKeys": {},
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.menu_items": {
      "name": "menu_items",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "category_id": {
          "name": "category_id",
          "type": "uuid",
          "primaryKey": false,
          "notNull": true
        },
        "name": {
          "name": "name",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "description": {
          "name": "description",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "price": {
          "name": "price",
          "type": "numeric(8, 2)",
          "primaryKey": false,
          "notNull": true,
          "default": "'0'"
        },
        "image": {
          "name": "image",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "allergens": {
          "name": "allergens",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "tags": {
          "name": "tags",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "featured": {
          "name": "featured",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": false
        },
        "sort_order": {
          "name": "sort_order",
          "type": "integer",
          "primaryKey": false,
          "notNull": true,
          "default": 0
        },
        "published": {
          "name": "published",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {
        "menu_items_category_idx": {
          "name": "menu_items_category_idx",
          "columns": [
            {
              "expression": "category_id",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": false,
          "concurrently": false,
          "method": "btree",
          "with": {}
        }
      },
      "foreignKeys": {
        "menu_items_category_id_menu_categories_id_fk": {
          "name": "menu_items_category_id_menu_categories_id_fk",
          "tableFrom": "menu_items",
          "tableTo": "menu_categories",
          "columnsFrom": [
            "category_id"
          ],
          "columnsTo": [
            "id"
          ],
          "onDelete": "cascade",
          "onUpdate": "no action"
        }
      },
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.messages": {
      "name": "messages",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "first_name": {
          "name": "first_name",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "last_name": {
          "name": "last_name",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "email": {
          "name": "email",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "phone": {
          "name": "phone",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "subject": {
          "name": "subject",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'General enquiry'"
        },
        "visit_date": {
          "name": "visit_date",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "guests": {
          "name": "guests",
          "type": "integer",
          "primaryKey": false,
          "notNull": false
        },
        "message": {
          "name": "message",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "source": {
          "name": "source",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'contact'"
        },
        "is_read": {
          "name": "is_read",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": false
        },
        "ip": {
          "name": "ip",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {
        "messages_created_idx": {
          "name": "messages_created_idx",
          "columns": [
            {
              "expression": "created_at",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": false,
          "concurrently": false,
          "method": "btree",
          "with": {}
        }
      },
      "foreignKeys": {},
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.posts": {
      "name": "posts",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "title": {
          "name": "title",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "slug": {
          "name": "slug",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "kicker": {
          "name": "kicker",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'News'"
        },
        "excerpt": {
          "name": "excerpt",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "content": {
          "name": "content",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "image": {
          "name": "image",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "published_at": {
          "name": "published_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "published": {
          "name": "published",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {
        "posts_slug_idx": {
          "name": "posts_slug_idx",
          "columns": [
            {
              "expression": "slug",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": true,
          "concurrently": false,
          "method": "btree",
          "with": {}
        }
      },
      "foreignKeys": {},
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.redirects": {
      "name": "redirects",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "from_path": {
          "name": "from_path",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "to_path": {
          "name": "to_path",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "permanent": {
          "name": "permanent",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "hits": {
          "name": "hits",
          "type": "integer",
          "primaryKey": false,
          "notNull": true,
          "default": 0
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {
        "redirects_from_idx": {
          "name": "redirects_from_idx",
          "columns": [
            {
              "expression": "from_path",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": true,
          "concurrently": false,
          "method": "btree",
          "with": {}
        }
      },
      "foreignKeys": {},
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.reviews": {
      "name": "reviews",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "name": {
          "name": "name",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "meta": {
          "name": "meta",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'Google'"
        },
        "text": {
          "name": "text",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "rating": {
          "name": "rating",
          "type": "integer",
          "primaryKey": false,
          "notNull": true,
          "default": 5
        },
        "sort_order": {
          "name": "sort_order",
          "type": "integer",
          "primaryKey": false,
          "notNull": true,
          "default": 0
        },
        "published": {
          "name": "published",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {},
      "foreignKeys": {},
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.site_content": {
      "name": "site_content",
      "schema": "",
      "columns": {
        "key": {
          "name": "key",
          "type": "text",
          "primaryKey": true,
          "notNull": true
        },
        "data": {
          "name": "data",
          "type": "jsonb",
          "primaryKey": false,
          "notNull": true
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {},
      "foreignKeys": {},
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    }
  },
  "enums": {},
  "schemas": {},
  "sequences": {},
  "roles": {},
  "policies": {},
  "views": {},
  "_meta": {
    "columns": {},
    "schemas": {},
    "tables": {}
  }
}
AMMOS_EOF
echo "  ✔ drizzle/meta/0001_snapshot.json"

mkdir -p "lib/db"
cat > "lib/db/schema.ts" << 'AMMOS_EOF'
import {
  pgTable,
  uuid,
  text,
  integer,
  boolean,
  timestamp,
  jsonb,
  index,
  uniqueIndex,
  numeric,
} from "drizzle-orm/pg-core";

const createdAt = () => timestamp("created_at", { withTimezone: true }).notNull().defaultNow();
const updatedAt = () =>
  timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date());

/* ───────────── Admin users ───────────── */
export const adminUsers = pgTable(
  "admin_users",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    email: text("email").notNull(),
    name: text("name").notNull().default(""),
    passwordHash: text("password_hash").notNull(),
    role: text("role").notNull().default("editor"), // "owner" | "editor"
    // bumped on logout-all / password change → invalidates every issued JWT
    tokenVersion: integer("token_version").notNull().default(1),
    failedLogins: integer("failed_logins").notNull().default(0),
    lockedUntil: timestamp("locked_until", { withTimezone: true }),
    lastLoginAt: timestamp("last_login_at", { withTimezone: true }),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [uniqueIndex("admin_users_email_idx").on(t.email)],
);

/* ───────────── Events ───────────── */
export const events = pgTable(
  "events",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    title: text("title").notNull(),
    slug: text("slug").notNull(),
    category: text("category").notNull().default("Party"), // tag shown on cards, e.g. "Live DJ"
    venue: text("venue").notNull().default("Terrace"), // e.g. Terrace / Beach / Restaurant
    startsAt: timestamp("starts_at", { withTimezone: true }).notNull(),
    endsAt: timestamp("ends_at", { withTimezone: true }),
    summary: text("summary").notNull().default(""),
    description: text("description").notNull().default(""),
    image: text("image").notNull().default(""),
    gallery: jsonb("gallery").$type<string[]>().notNull().default([]), // extra photos shown on the event page
    priceInfo: text("price_info").notNull().default(""), // e.g. "Free entry" / "€25 incl. welcome drink"
    capacity: integer("capacity"), // max guests that can book online (empty = unlimited)
    bookingEnabled: boolean("booking_enabled").notNull().default(true),
    featured: boolean("featured").notNull().default(true), // show on homepage
    published: boolean("published").notNull().default(true),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [uniqueIndex("events_slug_idx").on(t.slug), index("events_starts_idx").on(t.startsAt)],
);

/* ───────────── Event bookings ───────────── */
export const bookings = pgTable(
  "bookings",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    reference: text("reference").notNull(), // short code shown to the guest, e.g. AM-7K3Q9
    eventId: uuid("event_id").references(() => events.id, { onDelete: "set null" }),
    eventTitle: text("event_title").notNull().default(""), // snapshot, kept even if the event is deleted
    eventDate: timestamp("event_date", { withTimezone: true }),
    firstName: text("first_name").notNull(),
    lastName: text("last_name").notNull().default(""),
    email: text("email").notNull(),
    phone: text("phone").notNull(),
    guests: integer("guests").notNull().default(2),
    seating: text("seating").notNull().default(""), // preference: Terrace / Beach / Bar / Any
    occasion: text("occasion").notNull().default(""),
    message: text("message").notNull().default(""),
    status: text("status").notNull().default("pending"), // pending | confirmed | cancelled
    adminNotes: text("admin_notes").notNull().default(""),
    marketingOptIn: boolean("marketing_opt_in").notNull().default(false),
    ip: text("ip").notNull().default(""),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [
    uniqueIndex("bookings_reference_idx").on(t.reference),
    index("bookings_event_idx").on(t.eventId),
    index("bookings_created_idx").on(t.createdAt),
  ],
);

/* ───────────── Contact form messages ───────────── */
export const messages = pgTable(
  "messages",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    firstName: text("first_name").notNull(),
    lastName: text("last_name").notNull().default(""),
    email: text("email").notNull(),
    phone: text("phone").notNull().default(""),
    subject: text("subject").notNull().default("General enquiry"),
    visitDate: text("visit_date").notNull().default(""),
    guests: integer("guests"),
    message: text("message").notNull(),
    source: text("source").notNull().default("contact"), // contact | home | private-events
    isRead: boolean("is_read").notNull().default(false),
    ip: text("ip").notNull().default(""),
    createdAt: createdAt(),
  },
  (t) => [index("messages_created_idx").on(t.createdAt)],
);

/* ───────────── Menu ───────────── */
export const menuCategories = pgTable(
  "menu_categories",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    name: text("name").notNull(),
    slug: text("slug").notNull(),
    section: text("section").notNull().default("Food"), // big group: Food, Cocktails, Wines, …
    description: text("description").notNull().default(""),
    sortOrder: integer("sort_order").notNull().default(0),
    published: boolean("published").notNull().default(true),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [uniqueIndex("menu_categories_slug_idx").on(t.slug)],
);

export const menuItems = pgTable(
  "menu_items",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    categoryId: uuid("category_id")
      .notNull()
      .references(() => menuCategories.id, { onDelete: "cascade" }),
    name: text("name").notNull(),
    description: text("description").notNull().default(""),
    price: numeric("price", { precision: 8, scale: 2 }).notNull().default("0"),
    image: text("image").notNull().default(""),
    allergens: text("allergens").notNull().default(""), // comma separated
    tags: text("tags").notNull().default(""), // e.g. Vegan, Healthy
    featured: boolean("featured").notNull().default(false), // show on homepage menu block
    sortOrder: integer("sort_order").notNull().default(0),
    published: boolean("published").notNull().default(true),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [index("menu_items_category_idx").on(t.categoryId)],
);

/* ───────────── Gallery ───────────── */
export const galleryImages = pgTable("gallery_images", {
  id: uuid("id").primaryKey().defaultRandom(),
  image: text("image").notNull(),
  alt: text("alt").notNull().default(""),
  album: text("album").notNull().default("The Beach"),
  showOnHome: boolean("show_on_home").notNull().default(true),
  sortOrder: integer("sort_order").notNull().default(0),
  published: boolean("published").notNull().default(true),
  createdAt: createdAt(),
  updatedAt: updatedAt(),
});

/* ───────────── News & stories ───────────── */
export const posts = pgTable(
  "posts",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    title: text("title").notNull(),
    slug: text("slug").notNull(),
    kicker: text("kicker").notNull().default("News"),
    excerpt: text("excerpt").notNull().default(""),
    content: text("content").notNull().default(""),
    image: text("image").notNull().default(""),
    publishedAt: timestamp("published_at", { withTimezone: true }).notNull().defaultNow(),
    published: boolean("published").notNull().default(true),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [uniqueIndex("posts_slug_idx").on(t.slug)],
);

/* ───────────── Reviews ───────────── */
export const reviews = pgTable("reviews", {
  id: uuid("id").primaryKey().defaultRandom(),
  name: text("name").notNull(),
  meta: text("meta").notNull().default("Google"),
  text: text("text").notNull(),
  rating: integer("rating").notNull().default(5),
  sortOrder: integer("sort_order").notNull().default(0),
  published: boolean("published").notNull().default(true),
  createdAt: createdAt(),
  updatedAt: updatedAt(),
});

/* ───────────── Short links / redirects (e.g. /ourmenu → /menu) ───────────── */
export const redirects = pgTable(
  "redirects",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    fromPath: text("from_path").notNull(),
    toPath: text("to_path").notNull(),
    permanent: boolean("permanent").notNull().default(true),
    hits: integer("hits").notNull().default(0),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [uniqueIndex("redirects_from_idx").on(t.fromPath)],
);

/* ───────────── Editable page content (texts & images per section) ───────────── */
export const siteContent = pgTable("site_content", {
  key: text("key").primaryKey(),
  data: jsonb("data").notNull().$type<Record<string, unknown>>(),
  updatedAt: updatedAt(),
});

export type Event = typeof events.$inferSelect;
export type Booking = typeof bookings.$inferSelect;
export type Message = typeof messages.$inferSelect;
export type MenuCategory = typeof menuCategories.$inferSelect;
export type MenuItem = typeof menuItems.$inferSelect;
export type GalleryImage = typeof galleryImages.$inferSelect;
export type Post = typeof posts.$inferSelect;
export type Review = typeof reviews.$inferSelect;
export type Redirect = typeof redirects.$inferSelect;
export type AdminUser = typeof adminUsers.$inferSelect;
AMMOS_EOF
echo "  ✔ lib/db/schema.ts"

mkdir -p "lib/admin"
cat > "lib/admin/resources.ts" << 'AMMOS_EOF'
/**
 * ADMIN RESOURCES
 * Everything the admin can list / create / edit / delete, with the form fields.
 * (Client-safe: no database code here. The server side lives in resources.server.ts.)
 */

export type AdminField = {
  name: string;
  label: string;
  type:
    | "text"
    | "slug"
    | "textarea"
    | "richtext"
    | "url"
    | "email"
    | "image"
    | "images"
    | "video"
    | "number"
    | "price"
    | "checkbox"
    | "datetime"
    | "select"
    | "relation";
  required?: boolean;
  help?: string;
  half?: boolean;
  options?: { value: string; label: string }[];
  suggestions?: string[];
  relation?: "menuCategories";
  max?: number;
};

export type Column = { key: string; label: string; kind?: "image" | "date" | "datetime" | "bool" | "price" | "text" | "count" };

export type ResourceDef = {
  key: string; // used in the URL: /admin/<key>
  title: string;
  singular: string;
  description: string;
  fields: AdminField[];
  columns: Column[];
  searchable: string[];
  defaults: Record<string, unknown>;
  /** public page to open from the editor (":slug" is replaced) */
  viewPath?: string;
};

const opt = (...vals: string[]) => vals.map((v) => ({ value: v, label: v }));

export const RESOURCES: ResourceDef[] = [
  {
    key: "events",
    title: "Events",
    singular: "event",
    description: "Parties, live music, brunches… Upcoming events show on the website automatically and move to “Past events” after the date.",
    viewPath: "/events/:slug",
    fields: [
      { name: "title", label: "Title", type: "text", required: true, max: 160 },
      { name: "slug", label: "Web address", type: "slug", help: "Leave empty to create it from the title, e.g. full-moon-beach-party" },
      { name: "startsAt", label: "Starts (Cyprus time)", type: "datetime", required: true, half: true },
      { name: "endsAt", label: "Ends (optional)", type: "datetime", half: true },
      { name: "category", label: "Type / tag", type: "text", required: true, half: true, suggestions: ["Live DJ", "Party", "Live music", "Dining", "Brunch", "Tasting", "Community", "Special"] },
      { name: "venue", label: "Where", type: "text", required: true, half: true, suggestions: ["Terrace", "Beach", "Restaurant", "Bar", "Whole venue"] },
      { name: "summary", label: "Short summary", type: "textarea", help: "1–2 sentences. Shown under the title and in Google.", max: 400 },
      { name: "description", label: "Full description", type: "richtext", max: 20000 },
      { name: "image", label: "Main photo", type: "image", required: true, help: "Used on the event card and at the top of the event page. Portrait or square photos look best (at least 1000px)." },
      { name: "gallery", label: "Event photos", type: "images", help: "Extra photos shown on the event page next to the booking form. Select several at once; drag to change the order." },
      { name: "priceInfo", label: "Entry / price info", type: "text", half: true, help: "e.g. Free entry, €25 incl. welcome drink" },
      { name: "capacity", label: "Online booking limit (guests)", type: "number", half: true, help: "Empty = no limit" },
      { name: "bookingEnabled", label: "Allow online booking", type: "checkbox", half: true },
      { name: "featured", label: "Show on homepage slider", type: "checkbox", half: true },
      { name: "published", label: "Published (visible on website)", type: "checkbox" },
    ],
    columns: [
      { key: "image", label: "", kind: "image" },
      { key: "title", label: "Event" },
      { key: "startsAt", label: "Date", kind: "datetime" },
      { key: "category", label: "Type" },
      { key: "bookingCount", label: "Booked guests", kind: "count" },
      { key: "published", label: "Live", kind: "bool" },
    ],
    searchable: ["title", "category", "venue"],
    defaults: { category: "Party", venue: "Terrace", gallery: [], bookingEnabled: true, featured: true, published: true },
  },
  {
    key: "menu-items",
    title: "Menu items",
    singular: "menu item",
    description: "Dishes and drinks. Tick “Show on homepage” for the dishes in the homepage menu block (max 6 per category, 4 categories).",
    viewPath: "/menu",
    fields: [
      { name: "categoryId", label: "Category", type: "relation", relation: "menuCategories", required: true, half: true },
      { name: "price", label: "Price (€)", type: "price", required: true, half: true },
      { name: "name", label: "Name", type: "text", required: true, max: 160 },
      { name: "description", label: "Description", type: "textarea", max: 2000 },
      { name: "allergens", label: "Allergens", type: "text", half: true, help: "Comma separated, e.g. fish, milk, sesame" },
      { name: "tags", label: "Tags", type: "text", half: true, help: "e.g. Vegan, Healthy, Spicy" },
      { name: "image", label: "Photo (optional)", type: "image", help: "Shown when hovering the dish on the homepage and as a thumbnail on the menu page." },
      { name: "sortOrder", label: "Order", type: "number", half: true, help: "Lower numbers show first" },
      { name: "featured", label: "Show on homepage", type: "checkbox", half: true },
      { name: "published", label: "Visible on menu", type: "checkbox" },
    ],
    columns: [
      { key: "image", label: "", kind: "image" },
      { key: "name", label: "Item" },
      { key: "categoryName", label: "Category" },
      { key: "price", label: "Price", kind: "price" },
      { key: "featured", label: "Home", kind: "bool" },
      { key: "published", label: "Live", kind: "bool" },
    ],
    searchable: ["name", "description"],
    defaults: { price: "0", sortOrder: 100, featured: false, published: true },
  },
  {
    key: "menu-categories",
    title: "Menu categories",
    singular: "menu category",
    description: "Groups like Starters, Sushi, Cocktails. “Section” is the big heading on the menu page (Food, Wines, Spirits…).",
    viewPath: "/menu",
    fields: [
      { name: "name", label: "Name", type: "text", required: true, half: true },
      { name: "section", label: "Section", type: "text", required: true, half: true, suggestions: ["Food", "Early Bites", "Cocktails", "Beverages", "Wines", "Beers", "Spirits", "Whisky", "Other"] },
      { name: "slug", label: "Web address", type: "slug", help: "Leave empty to create it from the name" },
      { name: "description", label: "Short note (optional)", type: "textarea", max: 500 },
      { name: "sortOrder", label: "Order", type: "number", half: true, help: "Lower numbers show first" },
      { name: "published", label: "Visible on menu", type: "checkbox", half: true },
    ],
    columns: [
      { key: "name", label: "Category" },
      { key: "section", label: "Section" },
      { key: "itemCount", label: "Items", kind: "count" },
      { key: "sortOrder", label: "Order" },
      { key: "published", label: "Live", kind: "bool" },
    ],
    searchable: ["name", "section"],
    defaults: { section: "Food", sortOrder: 100, published: true },
  },
  {
    key: "gallery",
    title: "Gallery",
    singular: "photo",
    description: "Photos for the Gallery page. Tick “Show on homepage” for the photo grid on the homepage (the first 12 are used).",
    viewPath: "/gallery",
    fields: [
      { name: "image", label: "Photo", type: "image", required: true },
      { name: "alt", label: "Description (for Google & accessibility)", type: "text", help: "e.g. Sunset cocktails on the Ammos terrace" },
      { name: "album", label: "Album", type: "text", half: true, suggestions: ["The Beach", "Food", "The Bar", "Events"] },
      { name: "sortOrder", label: "Order", type: "number", half: true },
      { name: "showOnHome", label: "Show on homepage", type: "checkbox", half: true },
      { name: "published", label: "Visible", type: "checkbox", half: true },
    ],
    columns: [
      { key: "image", label: "", kind: "image" },
      { key: "alt", label: "Description" },
      { key: "album", label: "Album" },
      { key: "showOnHome", label: "Home", kind: "bool" },
      { key: "published", label: "Live", kind: "bool" },
    ],
    searchable: ["alt", "album"],
    defaults: { album: "The Beach", sortOrder: 100, showOnHome: true, published: true },
  },
  {
    key: "news",
    title: "News & stories",
    singular: "story",
    description: "Blog posts and news. The newest 3 appear on the homepage.",
    viewPath: "/news/:slug",
    fields: [
      { name: "title", label: "Title", type: "text", required: true, max: 160 },
      { name: "slug", label: "Web address", type: "slug", help: "Leave empty to create it from the title" },
      { name: "kicker", label: "Label", type: "text", half: true, suggestions: ["News", "Party", "Community", "Food", "Reunion"] },
      { name: "publishedAt", label: "Publish date", type: "datetime", half: true, required: true },
      { name: "excerpt", label: "Short intro", type: "textarea", max: 400 },
      { name: "content", label: "Story", type: "richtext", max: 50000 },
      { name: "image", label: "Cover photo", type: "image", required: true },
      { name: "published", label: "Published", type: "checkbox" },
    ],
    columns: [
      { key: "image", label: "", kind: "image" },
      { key: "title", label: "Title" },
      { key: "kicker", label: "Label" },
      { key: "publishedAt", label: "Date", kind: "date" },
      { key: "published", label: "Live", kind: "bool" },
    ],
    searchable: ["title", "excerpt"],
    defaults: { kicker: "News", published: true },
  },
  {
    key: "reviews",
    title: "Reviews",
    singular: "review",
    description: "Guest reviews shown in the moving “You said it” block. Copy your best Google reviews here.",
    fields: [
      { name: "name", label: "Guest name", type: "text", required: true, half: true },
      { name: "meta", label: "Source / place", type: "text", half: true, help: "e.g. Google · London" },
      { name: "text", label: "Review", type: "textarea", required: true, max: 600 },
      { name: "rating", label: "Stars (1–5)", type: "number", half: true },
      { name: "sortOrder", label: "Order", type: "number", half: true },
      { name: "published", label: "Visible", type: "checkbox" },
    ],
    columns: [
      { key: "name", label: "Guest" },
      { key: "text", label: "Review" },
      { key: "rating", label: "Stars" },
      { key: "published", label: "Live", kind: "bool" },
    ],
    searchable: ["name", "text"],
    defaults: { meta: "Google", rating: 5, sortOrder: 100, published: true },
  },
  {
    key: "redirects",
    title: "Redirects",
    singular: "redirect",
    description: "Short links. Example: “/ourmenu” → “/menu” sends anyone typing ammos.eu/ourmenu to the menu page. Changes apply within 1 minute.",
    fields: [
      { name: "fromPath", label: "From (path on ammos.eu)", type: "text", required: true, half: true, help: "Starts with /, e.g. /ourmenu" },
      { name: "toPath", label: "To (page or full link)", type: "text", required: true, half: true, help: "e.g. /menu or https://…" },
      { name: "permanent", label: "Permanent (recommended for SEO)", type: "checkbox" },
    ],
    columns: [
      { key: "fromPath", label: "From" },
      { key: "toPath", label: "To" },
      { key: "hits", label: "Visits", kind: "count" },
      { key: "permanent", label: "Permanent", kind: "bool" },
    ],
    searchable: ["fromPath", "toPath"],
    defaults: { permanent: true },
  },
];

export const RESOURCE_MAP: Record<string, ResourceDef> = Object.fromEntries(RESOURCES.map((r) => [r.key, r]));
AMMOS_EOF
echo "  ✔ lib/admin/resources.ts"

mkdir -p "lib/admin"
cat > "lib/admin/resources.server.ts" << 'AMMOS_EOF'
import "server-only";
import { z } from "zod";
import { and, asc, desc, eq, ilike, ne, or, sql, type SQL } from "drizzle-orm";
import type { PgColumn, PgTable } from "drizzle-orm/pg-core";
import { db, schema } from "@/lib/db";
import { cyprusLocalToDate, dateToCyprusLocal, slugify } from "@/lib/utils";
import { RESOURCE_MAP, type AdminField, type ResourceDef } from "@/lib/admin/resources";

type AnyTable = PgTable & { id: PgColumn };

export const TABLES: Record<string, AnyTable> = {
  events: schema.events,
  "menu-items": schema.menuItems,
  "menu-categories": schema.menuCategories,
  gallery: schema.galleryImages,
  news: schema.posts,
  reviews: schema.reviews,
  redirects: schema.redirects,
};

export function getResource(key: string) {
  const def = RESOURCE_MAP[key];
  const table = TABLES[key];
  if (!def || !table) return null;
  return { def, table };
}

/* ───────────── validation: form values → database values ───────────── */

const mediaPath = /^(\/[\w\-./%]*|https?:\/\/\S+)$/;

function fieldSchema(f: AdminField): z.ZodTypeAny {
  const req = (msg = `${f.label} is required`) => (s: z.ZodString) => (f.required ? s.min(1, msg) : s);
  switch (f.type) {
    case "text":
    case "textarea":
    case "richtext":
    case "slug": {
      const max = f.max ?? (f.type === "richtext" ? 50000 : f.type === "textarea" ? 5000 : 300);
      return req()(z.string().trim().max(max, `${f.label} is too long`)).default("");
    }
    case "email":
      return z
        .string()
        .trim()
        .max(200)
        .refine((v) => !v || /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(v), `${f.label} is not a valid email`)
        .default("");
    case "url":
      return z
        .string()
        .trim()
        .max(1000)
        .refine((v) => !v || /^(https?:\/\/|\/)/.test(v), `${f.label} must start with https:// or /`)
        .default("");
    case "image":
    case "video":
      return req(`Please add a ${f.type === "image" ? "photo" : "video"}`)(z.string().trim().max(1000))
        .refine((v) => !v || mediaPath.test(v), `${f.label}: not a valid file link`)
        .default("");
    case "images":
      return z
        .array(z.string().trim().max(1000).refine((v) => mediaPath.test(v), `${f.label}: not a valid file link`))
        .max(40, `${f.label}: 40 photos maximum`)
        .optional()
        .transform((v) => (v ?? []).filter(Boolean));
    case "number":
      return z
        .union([z.string(), z.number(), z.null()])
        .optional()
        .transform((v, ctx) => {
          if (v === "" || v === null || v === undefined) {
            if (f.required) ctx.addIssue({ code: "custom", message: `${f.label} is required` });
            return null;
          }
          const n = Number(v);
          if (!Number.isFinite(n)) {
            ctx.addIssue({ code: "custom", message: `${f.label} must be a number` });
            return null;
          }
          return Math.round(n);
        });
    case "price":
      return z
        .union([z.string(), z.number()])
        .transform((v, ctx) => {
          const n = Number(String(v).replace(",", ".").replace(/[^\d.]/g, ""));
          if (!Number.isFinite(n) || n < 0) {
            ctx.addIssue({ code: "custom", message: `${f.label} must be a positive number` });
            return "0";
          }
          return n.toFixed(2);
        });
    case "checkbox":
      return z
        .union([z.boolean(), z.string()])
        .optional()
        .transform((v) => v === true || v === "true" || v === "on" || v === "yes");
    case "datetime":
      return z
        .string()
        .optional()
        .transform((v, ctx) => {
          if (!v) {
            if (f.required) ctx.addIssue({ code: "custom", message: `${f.label} is required` });
            return null;
          }
          const d = cyprusLocalToDate(v);
          if (!d) ctx.addIssue({ code: "custom", message: `${f.label} is not a valid date` });
          return d;
        });
    case "relation":
      return z.string().uuid(`Please choose a ${f.label.toLowerCase()}`);
    case "select":
      return z.string().refine((v) => !f.options || f.options.some((o) => o.value === v), `${f.label}: invalid choice`);
    default:
      return z.any();
  }
}

export function parseInput(def: ResourceDef, input: unknown) {
  const shape: Record<string, z.ZodTypeAny> = {};
  for (const f of def.fields) shape[f.name] = fieldSchema(f);
  const values = z.object(shape).parse(input) as Record<string, any>;

  // tidy-ups per resource
  if ("slug" in values) {
    const base = values.slug || values.title || values.name || "";
    values.slug = slugify(String(base)) || `item-${Date.now()}`;
  }
  if (def.key === "events" && values.endsAt && values.startsAt && values.endsAt < values.startsAt) {
    throw new z.ZodError([{ code: "custom", path: ["endsAt"], message: "End time must be after the start time", input: values.endsAt }]);
  }
  if (def.key === "reviews") values.rating = Math.min(5, Math.max(1, values.rating ?? 5));
  if (def.key === "redirects") {
    const from = String(values.fromPath).trim().toLowerCase().replace(/\/+$/, "");
    values.fromPath = from.startsWith("/") ? from : `/${from}`;
    if (values.fromPath === "/" || values.fromPath.startsWith("/admin") || values.fromPath.startsWith("/api")) {
      throw new z.ZodError([{ code: "custom", path: ["fromPath"], message: "This path cannot be redirected", input: from }]);
    }
    const to = String(values.toPath).trim();
    values.toPath = /^https?:\/\//.test(to) || to.startsWith("/") ? to : `/${to}`;
  }
  for (const k of ["sortOrder"]) if (k in values && values[k] === null) values[k] = 0;
  return values;
}

/** Database row → values for the edit form (dates as Cyprus local time, etc). */
export function toFormValues(def: ResourceDef, row: Record<string, any> | null) {
  const out: Record<string, unknown> = { ...def.defaults };
  if (!row) {
    for (const f of def.fields) {
      if (f.type === "datetime" && f.required && !out[f.name]) out[f.name] = "";
    }
    return out;
  }
  for (const f of def.fields) {
    const v = row[f.name];
    if (f.type === "datetime") out[f.name] = v ? dateToCyprusLocal(v) : "";
    else if (f.type === "number") out[f.name] = v === null || v === undefined ? "" : String(v);
    else if (f.type === "checkbox") out[f.name] = Boolean(v);
    else if (f.type === "images") out[f.name] = Array.isArray(v) ? v : [];
    else out[f.name] = v ?? "";
  }
  return out;
}

/* ───────────── list queries ───────────── */

export async function listRows(key: string, opts: { q?: string; filter?: string } = {}) {
  const res = getResource(key);
  if (!res) return [];
  const { def, table } = res;
  const t = table as unknown as Record<string, PgColumn>;
  const where: SQL[] = [];
  if (opts.q) {
    const term = `%${opts.q.replace(/[%_]/g, "\\$&")}%`;
    const conds = def.searchable.map((c) => ilike(t[c], term));
    if (conds.length) where.push(or(...conds)!);
  }

  if (key === "events") {
    const booked = sql<number>`(select coalesce(sum(${schema.bookings.guests}),0)::int from ${schema.bookings} where ${schema.bookings.eventId} = ${schema.events.id} and ${schema.bookings.status} <> 'cancelled')`;
    if (opts.filter === "upcoming") where.push(sql`${schema.events.startsAt} >= now() - interval '12 hours'`);
    if (opts.filter === "past") where.push(sql`${schema.events.startsAt} < now() - interval '12 hours'`);
    return db
      .select({ row: schema.events, bookingCount: booked })
      .from(schema.events)
      .where(where.length ? and(...where) : undefined)
      .orderBy(opts.filter === "upcoming" ? asc(schema.events.startsAt) : desc(schema.events.startsAt))
      .then((r) => r.map((x) => ({ ...x.row, bookingCount: x.bookingCount })));
  }
  if (key === "menu-items") {
    if (opts.filter) where.push(eq(schema.menuItems.categoryId, opts.filter));
    return db
      .select({ row: schema.menuItems, categoryName: schema.menuCategories.name })
      .from(schema.menuItems)
      .innerJoin(schema.menuCategories, eq(schema.menuItems.categoryId, schema.menuCategories.id))
      .where(where.length ? and(...where) : undefined)
      .orderBy(asc(schema.menuCategories.sortOrder), asc(schema.menuItems.sortOrder), asc(schema.menuItems.name))
      .then((r) => r.map((x) => ({ ...x.row, categoryName: x.categoryName })));
  }
  if (key === "menu-categories") {
    const count = sql<number>`(select count(*)::int from ${schema.menuItems} where ${schema.menuItems.categoryId} = ${schema.menuCategories.id})`;
    return db
      .select({ row: schema.menuCategories, itemCount: count })
      .from(schema.menuCategories)
      .where(where.length ? and(...where) : undefined)
      .orderBy(asc(schema.menuCategories.sortOrder), asc(schema.menuCategories.name))
      .then((r) => r.map((x) => ({ ...x.row, itemCount: x.itemCount })));
  }
  const order =
    key === "news"
      ? [desc(schema.posts.publishedAt)]
      : key === "redirects"
        ? [asc(schema.redirects.fromPath)]
        : [asc(t.sortOrder), desc(t.createdAt)];
  return db
    .select()
    .from(table)
    .where(where.length ? and(...where) : undefined)
    .orderBy(...order)
    .limit(1000) as Promise<Record<string, any>[]>;
}

export async function getRow(key: string, id: string) {
  const res = getResource(key);
  if (!res || !/^[0-9a-f-]{36}$/i.test(id)) return null;
  const [row] = await db.select().from(res.table).where(eq(res.table.id, id)).limit(1);
  return (row as Record<string, any>) ?? null;
}

export async function menuCategoryOptions() {
  const cats = await db
    .select({ id: schema.menuCategories.id, name: schema.menuCategories.name, section: schema.menuCategories.section })
    .from(schema.menuCategories)
    .orderBy(asc(schema.menuCategories.sortOrder));
  return cats.map((c) => ({ value: c.id, label: `${c.section} › ${c.name}` }));
}

/** Makes sure a slug is unique by adding -2, -3… */
export async function uniqueSlug(key: string, slug: string, exceptId?: string) {
  const res = getResource(key);
  if (!res) return slug;
  const t = res.table as unknown as Record<string, PgColumn>;
  if (!t.slug) return slug;
  let candidate = slug;
  for (let i = 2; i < 200; i++) {
    const conds = [eq(t.slug, candidate)];
    if (exceptId) conds.push(ne(res.table.id, exceptId));
    const [hit] = await db.select({ id: res.table.id }).from(res.table).where(and(...conds)).limit(1);
    if (!hit) return candidate;
    candidate = `${slug}-${i}`;
  }
  return `${slug}-${Date.now()}`;
}
AMMOS_EOF
echo "  ✔ lib/admin/resources.server.ts"

mkdir -p "lib"
cat > "lib/content-schema.ts" << 'AMMOS_EOF'
/**
 * EDITABLE CONTENT
 * ----------------
 * Every text and image the admin can change from "Admin → Page content" is
 * described here: which fields a section has, and its default values
 * (taken from the approved design). The admin form is generated from these
 * definitions, so adding a new field here makes it editable automatically.
 *
 * This file has no server-only code, so the admin form can import it too.
 */

export type FieldDef =
  | {
      name: string;
      label: string;
      type: "text" | "textarea" | "richtext" | "url" | "email" | "number" | "checkbox" | "image" | "video";
      help?: string;
    }
  | { name: string; label: string; type: "select"; options: { value: string; label: string }[]; help?: string }
  | { name: string; label: string; type: "list"; itemLabel: string; fields: FieldDef[]; help?: string };

export type SectionDef = {
  key: string;
  title: string;
  group: "Settings" | "Homepage" | "Pages";
  description: string;
  fields: FieldDef[];
  defaults: Record<string, unknown>;
};

export const ICON_OPTIONS = [
  { value: "umbrella", label: "Beach umbrella" },
  { value: "fork-knife", label: "Fork & knife" },
  { value: "martini", label: "Cocktail" },
  { value: "vinyl-record", label: "Vinyl / DJ" },
  { value: "confetti", label: "Confetti / party" },
  { value: "coffee", label: "Coffee" },
  { value: "sun", label: "Sun" },
  { value: "wine", label: "Wine" },
  { value: "fish", label: "Fish" },
  { value: "music-notes", label: "Music" },
  { value: "champagne", label: "Champagne" },
];

const t = (name: string, label: string, help?: string): FieldDef => ({ name, label, type: "text", help });
const ta = (name: string, label: string, help?: string): FieldDef => ({ name, label, type: "textarea", help });
const img = (name: string, label: string, help?: string): FieldDef => ({ name, label, type: "image", help });

const KICKER_HELP = "Small coloured line above the title";
const TITLE_HELP = "Use a new line to break the title onto two lines";

export const SECTIONS: SectionDef[] = [
  /* ═════════════════════ SETTINGS ═════════════════════ */
  {
    key: "settings",
    title: "Business details & SEO",
    group: "Settings",
    description: "Contact details, opening hours, social links, reservation link and default SEO text. Used in the header, footer, contact page and Google data.",
    fields: [
      t("siteName", "Business name"),
      t("tagline", "Tagline"),
      { name: "email", label: "Email", type: "email" },
      t("phone", "Phone number"),
      t("address", "Address (street / area)"),
      t("city", "City"),
      t("postcode", "Postcode"),
      t("country", "Country"),
      t("mapQuery", "Google Maps search text", "What Google Maps should search for on the contact page map"),
      t("latitude", "Latitude (for Google)", "Right-click the place in Google Maps to copy it, e.g. 34.8873"),
      t("longitude", "Longitude (for Google)", "e.g. 33.6396"),
      { name: "reservationUrl", label: "Table reservation link (Klisto)", type: "url" },
      { name: "facebook", label: "Facebook", type: "url" },
      { name: "instagram", label: "Instagram", type: "url" },
      t("instagramHandle", "Instagram handle (shown as @…)"),
      { name: "tiktok", label: "TikTok", type: "url" },
      { name: "youtube", label: "YouTube", type: "url" },
      { name: "linktree", label: "Linktree", type: "url" },
      {
        name: "hours",
        label: "Opening hours",
        type: "list",
        itemLabel: "Day",
        fields: [t("day", "Day"), t("open", "Opens (HH:MM)"), t("close", "Closes (HH:MM)")],
      },
      t("hoursNote", "Short opening hours line", "Shown in the footer, e.g. “Open daily 10:00 – 22:30”"),
      t("googleRating", "Google rating", "e.g. 4.8"),
      t("reviewCount", "Number of reviews text", "e.g. 2,300+"),
      { name: "hiring", label: "We are currently hiring", type: "checkbox", help: "Turn on to show open positions text on the Careers page" },
      t("seoTitle", "Default SEO title"),
      ta("seoDescription", "Default SEO description", "About 150 characters. Shown in Google results."),
    ],
    defaults: {
      siteName: "Ammos Makenzy Beach",
      tagline: "Beach bar & restaurant in Larnaca",
      email: "info@ammos.eu",
      phone: "+357 24 828844",
      address: "Makenzy Beach",
      city: "Larnaca",
      postcode: "6028",
      country: "Cyprus",
      mapQuery: "Ammos Beach Bar, Makenzy Beach, Larnaca, Cyprus",
      latitude: "34.8873",
      longitude: "33.6396",
      reservationUrl: "https://www.klisto.com.cy/Profile/ammos",
      facebook: "https://www.facebook.com/ammos.eu/",
      instagram: "https://www.instagram.com/ammosbeachbar/",
      instagramHandle: "ammosbeachbar",
      tiktok: "https://www.tiktok.com/@ammosbeachbar",
      youtube: "https://www.youtube.com/@ammosbeachbar?sub_confirmation=1",
      linktree: "https://linktr.ee/ammosbeachbar",
      hours: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].map((day) => ({
        day,
        open: "10:00",
        close: "22:30",
      })),
      hoursNote: "Open daily 10:00 – 22:30",
      googleRating: "4.8",
      reviewCount: "2,300+",
      hiring: false,
      seoTitle: "Ammos Makenzy Beach — Beach Bar & Restaurant in Larnaca, Cyprus",
      seoDescription:
        "Beach bar, restaurant and terrace on Makenzy Beach, Larnaca since 2005. Fresh seafood, sushi, cocktails, live DJs and events. Book your table.",
    },
  },

  /* ═════════════════════ HOMEPAGE ═════════════════════ */
  {
    key: "home.hero",
    title: "Hero (top of homepage)",
    group: "Homepage",
    description: "The big first screen with title and buttons. Choose if the background shows the photo or the video.",
    fields: [
      t("kicker", "Kicker", KICKER_HELP),
      ta("title", "Title", TITLE_HELP),
      ta("subtitle", "Subtitle"),
      t("primaryLabel", "Main button text", "Opens the table reservation link"),
      t("secondaryLabel", "Second button text", "Goes to the events page"),
      ta("addressLine", "Address text (bottom right)", "New line = line break"),
      {
        name: "mediaType",
        label: "Background shows",
        type: "select",
        options: [
          { value: "image", label: "Photo" },
          { value: "video", label: "Video (photo shows while it loads)" },
        ],
        help: "Switch between the photo and the video below. Both are kept, so you can switch back any time.",
      },
      img("image", "Background photo", "Shown when “Photo” is selected, and while the video loads"),
      { name: "video", label: "Background video", type: "video", help: "Used when “Video” is selected. MP4, short and small (under 15 MB)." },
    ],
    defaults: {
      kicker: "Makenzy Beach",
      title: "your home\nfor 21 years.",
      subtitle: "Beach bar, restaurant and late-night terrace on the Makenzy strip. Sunrise coffee to last-call cocktails.",
      primaryLabel: "Make reservation",
      secondaryLabel: "View events",
      addressLine: "Makenzy Beach\nLarnaca, Cyprus",
      mediaType: "image",
      image: "/images/hero-kitchen.jpg",
      video: "https://assets.mixkit.co/videos/4043/4043-720.mp4",
    },
  },
  {
    key: "home.events",
    title: "Upcoming events block",
    group: "Homepage",
    description: "Heading of the events slider. The cards come from Admin → Events (marked “Show on homepage”).",
    fields: [t("kicker", "Kicker", KICKER_HELP), t("title", "Title"), t("buttonLabel", "Button text")],
    defaults: { kicker: "What's on", title: "upcoming events", buttonLabel: "View all events" },
  },
  {
    key: "home.story",
    title: "The Ammos story (timeline)",
    group: "Homepage",
    description: "Timeline with years and the fanned photos below it.",
    fields: [
      t("kicker", "Kicker", KICKER_HELP),
      t("title", "Title"),
      ta("text", "Intro text"),
      {
        name: "timeline",
        label: "Timeline",
        type: "list",
        itemLabel: "Milestone",
        fields: [t("year", "Year"), t("title", "Title"), ta("text", "Text"), img("image", "Photo")],
      },
      { name: "fan", label: "Fanned photos (5 work best)", type: "list", itemLabel: "Photo", fields: [img("image", "Photo"), t("alt", "Description (for Google)")] },
    ],
    defaults: {
      kicker: "Since 2005",
      title: "the ammos story",
      text: "We might be the pioneers of the 'Makenzy Strip', but at Ammos we never stand still for too long. From our ever-changing menu, to a full makeover, Ammos is always evolving, progressing, and staying ahead of the trends.",
      timeline: [
        { year: "2005", title: "First on the strip", text: "Ammos opens its doors on Makenzy Beach, before there was a strip to speak of.", image: "/images/awards-interior.jpg" },
        { year: "2011", title: "The kitchen grows", text: "A full restaurant menu joins the bar. Sunday brunch becomes a Larnaca ritual.", image: "/images/chef-plate.jpg" },
        { year: "2015", title: "A Larnaca favourite", text: "Word spreads along the coast, and the regulars keep coming back.", image: "/images/flowers.jpg" },
        { year: "2026", title: "The full makeover", text: "New look, same beach. Still evolving, still ahead of the trends.", image: "/images/bar-interior.jpg" },
      ],
      fan: [
        { image: "/images/awards-interior.jpg", alt: "Inside Ammos" },
        { image: "/images/bartender.jpg", alt: "Bartender at Ammos" },
        { image: "/images/bar-interior.jpg", alt: "The Ammos bar" },
        { image: "/images/party.jpg", alt: "Party night at Ammos" },
        { image: "/images/flowers.jpg", alt: "Table flowers at Ammos" },
      ],
    },
  },
  {
    key: "home.activities",
    title: "Our activities (polaroids)",
    group: "Homepage",
    description: "The polaroid photos and the moving words strip.",
    fields: [
      t("kicker", "Kicker", KICKER_HELP),
      ta("title", "Title", TITLE_HELP),
      ta("text", "Text"),
      {
        name: "polaroids",
        label: "Polaroids (5 work best)",
        type: "list",
        itemLabel: "Polaroid",
        fields: [t("label", "Label"), { name: "icon", label: "Icon", type: "select", options: ICON_OPTIONS }, img("image", "Photo")],
      },
      { name: "marquee", label: "Moving words strip", type: "list", itemLabel: "Word", fields: [t("word", "Word or phrase")] },
    ],
    defaults: {
      kicker: "All day, every day",
      title: "our\nactivities",
      text: "One address, a whole day of it. Sunbeds and coffee in the morning, long lunches, sunset cocktails at the bar and resident DJs on the terrace until late.",
      polaroids: [
        { label: "Beach club", icon: "umbrella", image: "/images/awards-interior.jpg" },
        { label: "Lunch", icon: "fork-knife", image: "/images/chef-plate.jpg" },
        { label: "Cocktails", icon: "martini", image: "/images/bartender.jpg" },
        { label: "Live DJ", icon: "vinyl-record", image: "/images/party.jpg" },
        { label: "Private events", icon: "confetti", image: "/images/flowers.jpg" },
      ],
      marquee: [{ word: "beach club" }, { word: "sunset cocktails" }, { word: "brunch" }, { word: "private events" }, { word: "fresh seafood" }],
    },
  },
  {
    key: "home.video",
    title: "Discover video",
    group: "Homepage",
    description: "The blurred photo with the play button. Clicking plays the video.",
    fields: [
      t("label", "Text under the play button"),
      img("poster", "Background photo"),
      { name: "video", label: "Video", type: "video", help: "MP4 upload, or paste a link to an .mp4 file" },
      { name: "youtubeUrl", label: "…or a YouTube link instead", type: "url", help: "If filled, the YouTube video plays instead of the MP4" },
    ],
    defaults: {
      label: "Discover Ammos",
      poster: "/images/bar-interior.jpg",
      video: "https://assets.mixkit.co/videos/4295/4295-720.mp4",
      youtubeUrl: "",
    },
  },
  {
    key: "home.chefs",
    title: "Passionate foodies (chefs)",
    group: "Homepage",
    description: "Two photos and the chefs text.",
    fields: [
      t("kicker", "Kicker", KICKER_HELP),
      ta("title", "Title", TITLE_HELP),
      ta("text", "Text"),
      t("quote", "Quote"),
      t("primaryLabel", "Button text", "Goes to the Our Story page"),
      img("image1", "Large photo"),
      img("image2", "Small photo"),
    ],
    defaults: {
      kicker: "Our Chefs Story",
      title: "passionate\nfoodies",
      text: "Ammos is not only about great food. But it's a good place to start. And with our incredible team of passionate foodies, we're bringing a holistic experience to the table; served up in a fusion of mouth-watering flavours, aromas and tastes.",
      quote: "“Fresh, local, and never the same twice.”",
      primaryLabel: "Discover more",
      image1: "/images/chef-plate.jpg",
      image2: "/images/hero-kitchen.jpg",
    },
  },
  {
    key: "home.menu",
    title: "Menu block",
    group: "Homepage",
    description: "Heading and text of the menu block. The dishes are the menu items marked “Show on homepage” (add a photo to a dish to show it on hover).",
    fields: [
      t("kicker", "Kicker", KICKER_HELP),
      ta("title", "Title", TITLE_HELP),
      ta("text", "Text"),
      t("buttonLabel", "Button text"),
      { name: "buttonUrl", label: "Button link", type: "url", help: "Where the button goes, e.g. the live menu or /menu" },
      t("hint", "Small hint text (optional)"),
    ],
    defaults: {
      kicker: "Salivating yet?",
      title: "ammos\nmenu",
      text: "At Ammos, we don't follow trends. We create them. Just check out our exciting menu for proof – fresh, local ingredients, passionately assembled by talented chefs, to create an explosion of tastes that will take you on an epicurean adventure around the world.",
      buttonLabel: "View all menu",
      buttonUrl: "https://ammos-beach-bar.nina.cy/?step=menu",
      hint: "",
    },
  },
  {
    key: "home.news",
    title: "News & stories block",
    group: "Homepage",
    description: "Heading of the news block. Articles come from Admin → News.",
    fields: [t("kicker", "Kicker", KICKER_HELP), t("title", "Title"), ta("text", "Text"), t("buttonLabel", "Button text")],
    defaults: {
      kicker: "Beyond the bar",
      title: "news & stories",
      text: "Ammos is always evolving, progressing, and staying ahead of the trends. Check our latest news and blogs here.",
      buttonLabel: "View all news",
    },
  },
  {
    key: "home.reviews",
    title: "Reviews block",
    group: "Homepage",
    description: "Heading of the reviews block. Reviews come from Admin → Reviews.",
    fields: [t("kicker", "Kicker", KICKER_HELP), t("title", "Title")],
    defaults: { kicker: "Reviews", title: "you said it" },
  },
  {
    key: "home.gallery",
    title: "Gallery block",
    group: "Homepage",
    description: "Photo grid. Photos come from Admin → Gallery (marked “Show on homepage”).",
    fields: [t("kicker", "Kicker", KICKER_HELP), t("title", "Title"), ta("centerTitle", "Title in the middle of the grid", TITLE_HELP), t("buttonLabel", "Button text"), t("instagramLabel", "Instagram button text")],
    defaults: {
      kicker: "@ammosbeachbar",
      title: "straight from the strip",
      centerTitle: "welcome\nto your place.",
      buttonLabel: "Book a table",
      instagramLabel: "Follow on Instagram",
    },
  },
  {
    key: "home.contact",
    title: "Contact form block",
    group: "Homepage",
    description: "The enquiry form at the bottom of the homepage.",
    fields: [t("title", "Title"), img("image", "Background photo"), t("buttonLabel", "Send button text")],
    defaults: { title: "have an amazing experience!", image: "/images/party.jpg", buttonLabel: "Send" },
  },

  /* ═════════════════════ PAGES ═════════════════════ */
  {
    key: "page.story",
    title: "Our Story page",
    group: "Pages",
    description: "The About us page (/our-story).",
    fields: [
      t("kicker", "Kicker", KICKER_HELP),
      ta("title", "Title", TITLE_HELP),
      img("heroImage", "Top photo"),
      { name: "intro", label: "Intro text", type: "richtext", help: "Empty line = new paragraph" },
      {
        name: "chapters",
        label: "Story chapters",
        type: "list",
        itemLabel: "Chapter",
        fields: [t("kicker", "Small line"), t("title", "Title"), { name: "text", label: "Text", type: "richtext" }, img("image", "Photo")],
      },
      t("quote", "Big quote"),
    ],
    defaults: {
      kicker: "Since 2005",
      title: "the ammos\nstory",
      heroImage: "/images/awards-interior.jpg",
      intro:
        "Ammos Beach Bar started out as the first beach bar on a quiet seaside strip called Mackenzie Beach in Larnaca.\n\nIn 2005, the management of Ammos took a major risk by setting up a chilled-out lounge bar on a very under-developed part of Larnaca. As the beach transformed into one of the most popular going-out destinations in Cyprus, Ammos remained the frontrunner of the island's bar scene — with a combination of fine cuisine, top-quality drinks and the very best in entertainment.",
      chapters: [
        {
          kicker: "The strip",
          title: "From sleepy seaside to Makenzy Beach",
          text: "What was once a sleepy seaside area for eating fresh fish has evolved, thanks to Ammos, into an exciting entertainment centre with easy access to good food, the tastiest drinks and events to remember.",
          image: "/images/party.jpg",
        },
        {
          kicker: "The table",
          title: "High-quality dining along the beach",
          text: "Another idea born at Ammos: combining a night out with a real restaurant experience. Perfectly prepared, simply served and finished the Ammos way — from sushi and seafood to steaks and Sunday brunch.",
          image: "/images/chef-plate.jpg",
        },
        {
          kicker: "The people",
          title: "Regulars who became friends",
          text: "We might be the pioneers of the Makenzy Strip, but we never stand still. From our ever-changing menu to a full makeover, Ammos is always evolving — and the people who come back year after year are the reason why.",
          image: "/images/bartender.jpg",
        },
      ],
      quote: "“We might be the pioneers of the Makenzy Strip, but we never stand still for too long.”",
    },
  },
  {
    key: "page.headers",
    title: "Page headers",
    group: "Pages",
    description: "Title, intro text and photo at the top of the listing pages.",
    fields: [
      t("eventsTitle", "Events — title"),
      ta("eventsText", "Events — intro"),
      img("eventsImage", "Events — photo"),
      t("calendarTitle", "Events calendar — title"),
      ta("calendarText", "Events calendar — intro"),
      t("menuTitle", "Menu — title"),
      ta("menuText", "Menu — intro"),
      img("menuImage", "Menu — photo"),
      t("galleryTitle", "Gallery — title"),
      ta("galleryText", "Gallery — intro"),
      img("galleryImage", "Gallery — photo"),
      t("newsTitle", "News — title"),
      ta("newsText", "News — intro"),
      img("newsImage", "News — photo"),
      t("contactTitle", "Contact — title"),
      ta("contactText", "Contact — intro"),
      img("contactImage", "Contact — photo"),
    ],
    defaults: {
      eventsTitle: "events",
      eventsText: "Live DJs, full-moon parties, long Sunday brunches and acoustic nights on the terrace. Pick a night and save your table.",
      eventsImage: "/images/party.jpg",
      calendarTitle: "events calendar",
      calendarText: "Every night that's planned on the strip, month by month.",
      menuTitle: "our menu",
      menuText: "Fresh, local ingredients, sushi rolled to order, seafood from the josper grill, and a cocktail list built for sunsets.",
      menuImage: "/images/chef-plate.jpg",
      galleryTitle: "gallery",
      galleryText: "Sunbeds, sunsets, plates and parties — straight from the strip.",
      galleryImage: "/images/bar-interior.jpg",
      newsTitle: "news & stories",
      newsText: "What's been happening at Ammos, and what's coming next.",
      newsImage: "/images/news-2.jpg",
      contactTitle: "contact us",
      contactText: "Questions, group bookings, birthdays or just saying hello — we'd love to hear from you.",
      contactImage: "/images/party.jpg",
    },
  },
  {
    key: "page.privateEvents",
    title: "Private events page",
    group: "Pages",
    description: "Birthdays, weddings, corporate nights (/private-events).",
    fields: [
      ta("title", "Title", TITLE_HELP),
      { name: "intro", label: "Intro", type: "richtext" },
      img("image", "Photo"),
      { name: "options", label: "Options", type: "list", itemLabel: "Option", fields: [t("title", "Title"), ta("text", "Text")] },
    ],
    defaults: {
      title: "private\nevents",
      intro: "From a birthday table for twelve to taking over the whole terrace — our team plans, cooks and pours so you can enjoy the night.\n\nTell us the date, the number of guests and the mood, and we'll come back to you with a proposal.",
      image: "/images/flowers.jpg",
      options: [
        { title: "Birthdays & celebrations", text: "Reserved tables, set menus, a cake moment and bottles on ice." },
        { title: "Corporate events", text: "Team dinners, product launches and end-of-year parties by the sea." },
        { title: "Weddings & engagements", text: "Sunset ceremonies, beach receptions and after-parties on the terrace." },
        { title: "Full venue buyout", text: "The whole of Ammos, your guest list, your music." },
      ],
    },
  },
  {
    key: "page.careers",
    title: "Careers page",
    group: "Pages",
    description: "Shown at /careers. Switch “We are currently hiring” in Business details to change which text shows.",
    fields: [
      ta("title", "Title", TITLE_HELP),
      { name: "notHiringText", label: "Text when NOT hiring", type: "richtext" },
      { name: "hiringText", label: "Text when hiring (list positions here)", type: "richtext" },
    ],
    defaults: {
      title: "join the\nammos team",
      notHiringText:
        "We're not hiring at the moment — our team is complete for now.\n\nWe still love meeting people who care about great food, drinks and hospitality. Send your CV to info@ammos.eu and we'll keep it on file for the next season.",
      hiringText:
        "We're looking for people who love hospitality.\n\n## Open positions\n- Waiters & waitresses\n- Bartenders\n- Kitchen staff\n\nSend your CV and a short message to info@ammos.eu.",
    },
  },
  {
    key: "page.houseRules",
    title: "House rules page",
    group: "Pages",
    description: "Shown at /house-rules.",
    fields: [t("title", "Title"), { name: "body", label: "Text", type: "richtext" }],
    defaults: {
      title: "house rules",
      body:
        "We want everyone to have a great time at Ammos. A few simple rules help us keep it that way.\n\n## Reservations\n- Tables are held for 15 minutes after the booking time.\n- For groups of 10 or more please contact us in advance.\n\n## On the beach\n- Sunbeds are available on a first-come basis unless reserved.\n- Please respect the lifeguard's instructions and flags.\n\n## In the evening\n- Smart-casual dress code after 20:00.\n- Management reserves the right of admission.\n- Guests must be 18+ to be served alcohol. ID may be requested.\n\n## Please\n- No outside food or drinks.\n- Keep the beach clean — use the bins provided.",
    },
  },
  {
    key: "page.privacy",
    title: "Privacy policy page",
    group: "Pages",
    description: "Shown at /privacy-policy. Have this checked by your legal adviser.",
    fields: [t("title", "Title"), { name: "body", label: "Text", type: "richtext" }],
    defaults: {
      title: "privacy policy",
      body:
        "This policy explains how Ammos Makenzy Beach (\"we\") collects and uses personal data through this website, in line with the EU General Data Protection Regulation (GDPR).\n\n## What we collect\n- Contact form: your name, email, phone number, preferred date, number of guests and message.\n- Event bookings: your name, email, phone number, number of guests and any notes you add.\n\n## Why we use it\n- To answer your enquiry and manage your booking.\n- To send you news and offers, only if you have ticked the box to receive them.\n\n## How long we keep it\nWe keep enquiries and bookings for up to 24 months, then delete them.\n\n## Who we share it with\nWe do not sell your data. It is stored on our own server and sent through our email provider only to answer you.\n\n## Your rights\nYou can ask to see, correct or delete your data at any time by emailing info@ammos.eu.\n\n## Cookies\nThis website only uses the cookies needed for it to work (for example the admin login). We do not use advertising cookies.",
    },
  },
  {
    key: "page.legal",
    title: "Legal notice page",
    group: "Pages",
    description: "Shown at /legal-notice.",
    fields: [t("title", "Title"), { name: "body", label: "Text", type: "richtext" }],
    defaults: {
      title: "legal notice",
      body:
        "## Website operator\nAmmos Makenzy Beach\nMakenzy Beach, Larnaca 6028, Cyprus\nPhone: +357 24 828844\nEmail: info@ammos.eu\n\n## Content\nAll texts, photos and logos on this website belong to Ammos Makenzy Beach unless stated otherwise and may not be copied without permission.\n\n## Liability\nWe take care to keep the information on this website correct and up to date, but menus, prices, opening hours and events may change without notice.",
    },
  },
];

export const SECTION_MAP: Record<string, SectionDef> = Object.fromEntries(SECTIONS.map((s) => [s.key, s]));

/** Types of the settings block (handy for components). */
export type Settings = {
  siteName: string;
  tagline: string;
  email: string;
  phone: string;
  address: string;
  city: string;
  postcode: string;
  country: string;
  mapQuery: string;
  latitude: string;
  longitude: string;
  reservationUrl: string;
  facebook: string;
  instagram: string;
  instagramHandle: string;
  tiktok: string;
  youtube: string;
  linktree: string;
  hours: { day: string; open: string; close: string }[];
  hoursNote: string;
  googleRating: string;
  reviewCount: string;
  hiring: boolean;
  seoTitle: string;
  seoDescription: string;
};
AMMOS_EOF
echo "  ✔ lib/content-schema.ts"

mkdir -p "lib"
cat > "lib/seo.ts" << 'AMMOS_EOF'
import type { Metadata } from "next";
import type { Settings } from "@/lib/content-schema";
import type { Event, Post } from "@/lib/db/schema";
import { absoluteImage, siteUrl, truncate } from "@/lib/utils";

/** Builds page metadata with canonical URL, Open Graph and Twitter cards. */
export function pageMeta(opts: { title: string; description: string; path: string; image?: string | null; type?: "website" | "article" }): Metadata {
  const url = siteUrl(opts.path);
  const image = absoluteImage(opts.image);
  return {
    title: opts.title,
    description: truncate(opts.description, 160),
    alternates: { canonical: url },
    openGraph: {
      type: opts.type ?? "website",
      url,
      title: opts.title,
      description: truncate(opts.description, 200),
      siteName: "Ammos Makenzy Beach",
      locale: "en_GB",
      images: [{ url: image, width: 1200, height: 630, alt: opts.title }],
    },
    twitter: { card: "summary_large_image", title: opts.title, description: truncate(opts.description, 200), images: [image] },
  };
}

const DAY_MAP: Record<string, string> = {
  monday: "Monday",
  tuesday: "Tuesday",
  wednesday: "Wednesday",
  thursday: "Thursday",
  friday: "Friday",
  saturday: "Saturday",
  sunday: "Sunday",
};

/** Restaurant + bar business data for Google. */
export function businessJsonLd(s: Settings) {
  return {
    "@context": "https://schema.org",
    "@type": ["Restaurant", "BarOrPub"],
    "@id": siteUrl("/#business"),
    name: s.siteName,
    description: s.seoDescription,
    url: siteUrl("/"),
    logo: siteUrl("/images/logo.png"),
    image: [siteUrl("/opengraph-image.jpg")],
    telephone: s.phone,
    email: s.email,
    priceRange: "€€",
    servesCuisine: ["Mediterranean", "Seafood", "Sushi", "Cocktails"],
    acceptsReservations: s.reservationUrl || true,
    hasMenu: siteUrl("/menu"),
    address: {
      "@type": "PostalAddress",
      streetAddress: s.address,
      addressLocality: s.city,
      postalCode: s.postcode,
      addressCountry: "CY",
    },
    ...(Number(s.latitude) && Number(s.longitude)
      ? { geo: { "@type": "GeoCoordinates", latitude: Number(s.latitude), longitude: Number(s.longitude) } }
      : {}),
    openingHoursSpecification: (s.hours || [])
      .filter((h) => DAY_MAP[h.day?.toLowerCase?.()] && h.open && h.close)
      .map((h) => ({
        "@type": "OpeningHoursSpecification",
        dayOfWeek: `https://schema.org/${DAY_MAP[h.day.toLowerCase()]}`,
        opens: h.open,
        closes: h.close,
      })),
    sameAs: [s.facebook, s.instagram, s.tiktok, s.youtube, s.linktree].filter(Boolean),
    ...(s.googleRating && Number(s.googleRating)
      ? {
          aggregateRating: {
            "@type": "AggregateRating",
            ratingValue: s.googleRating,
            bestRating: "5",
            ratingCount: String(s.reviewCount || "").replace(/[^\d]/g, "") || "100",
          },
        }
      : {}),
  };
}

export function eventJsonLd(e: Event, s: Settings) {
  return {
    "@context": "https://schema.org",
    "@type": "Event",
    name: e.title,
    description: truncate(e.summary || e.description, 300),
    startDate: e.startsAt.toISOString(),
    ...(e.endsAt ? { endDate: e.endsAt.toISOString() } : {}),
    eventStatus: "https://schema.org/EventScheduled",
    eventAttendanceMode: "https://schema.org/OfflineEventAttendanceMode",
    image: [e.image, ...(Array.isArray(e.gallery) ? e.gallery : [])].filter(Boolean).slice(0, 6).map((src) => absoluteImage(src)),
    url: siteUrl(`/events/${e.slug}`),
    location: {
      "@type": "Place",
      name: `${s.siteName} — ${e.venue}`,
      address: { "@type": "PostalAddress", streetAddress: s.address, addressLocality: s.city, postalCode: s.postcode, addressCountry: "CY" },
    },
    organizer: { "@type": "Organization", name: s.siteName, url: siteUrl("/") },
    ...(e.bookingEnabled
      ? {
          offers: {
            "@type": "Offer",
            url: siteUrl(`/events/${e.slug}#book`),
            availability: "https://schema.org/InStock",
            price: "0",
            priceCurrency: "EUR",
            validFrom: e.createdAt.toISOString(),
          },
        }
      : {}),
  };
}

export function articleJsonLd(p: Post, s: Settings) {
  return {
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    headline: p.title,
    description: truncate(p.excerpt || p.content, 200),
    image: [absoluteImage(p.image)],
    datePublished: p.publishedAt.toISOString(),
    dateModified: p.updatedAt.toISOString(),
    mainEntityOfPage: siteUrl(`/news/${p.slug}`),
    author: { "@type": "Organization", name: s.siteName },
    publisher: { "@type": "Organization", name: s.siteName, logo: { "@type": "ImageObject", url: siteUrl("/images/logo.png") } },
  };
}

export function breadcrumbJsonLd(items: { name: string; path: string }[]) {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: items.map((it, i) => ({ "@type": "ListItem", position: i + 1, name: it.name, item: siteUrl(it.path) })),
  };
}
AMMOS_EOF
echo "  ✔ lib/seo.ts"

mkdir -p "components/admin"
cat > "components/admin/Fields.tsx" << 'AMMOS_EOF'
"use client";

import { MediaInput } from "@/components/admin/MediaInput";
import { MultiImageInput } from "@/components/admin/MultiImageInput";

/** One field description — works for both resource forms and page-content forms. */
export type AnyField = {
  name: string;
  label: string;
  type: string;
  required?: boolean;
  help?: string;
  half?: boolean;
  options?: { value: string; label: string }[];
  suggestions?: string[];
  fields?: AnyField[];
  itemLabel?: string;
};

type Values = Record<string, any>;

export function FieldInput({ field, value, onChange, idPrefix = "f" }: { field: AnyField; value: any; onChange: (v: any) => void; idPrefix?: string }) {
  const id = `${idPrefix}-${field.name}`;
  const label = (
    <label htmlFor={id}>
      {field.label}
      {field.required && <span className="req"> *</span>}
    </label>
  );
  const help = field.help ? <span className="a-help">{field.help}</span> : null;
  const cls = `a-field${field.half ? " half" : ""}`;
  const str = value === null || value === undefined ? "" : String(value);

  switch (field.type) {
    case "checkbox":
      return (
        <div className={cls}>
          <label className="a-check">
            <input id={id} type="checkbox" checked={Boolean(value)} onChange={(e) => onChange(e.target.checked)} />
            <span>{field.label}</span>
          </label>
          {help}
        </div>
      );
    case "textarea":
    case "richtext":
      return (
        <div className={cls}>
          {label}
          <textarea id={id} className={`a-input${field.type === "richtext" ? " rich" : ""}`} value={str} required={field.required} onChange={(e) => onChange(e.target.value)} />
          {field.type === "richtext" ? (
            <span className="a-help">
              {field.help ? `${field.help} · ` : ""}Empty line = new paragraph · <code>## Heading</code> · <code>- bullet</code> · <code>**bold**</code> · <code>[link text](https://…)</code>
            </span>
          ) : (
            help
          )}
        </div>
      );
    case "image":
    case "video":
      return (
        <div className={cls}>
          {label}
          <MediaInput id={id} value={str} onChange={onChange} kind={field.type as "image" | "video"} />
          {help}
        </div>
      );
    case "select":
    case "relation":
      return (
        <div className={cls}>
          {label}
          <select id={id} className="a-input" value={str} required={field.required} onChange={(e) => onChange(e.target.value)}>
            {!field.required || !str ? <option value="">— choose —</option> : null}
            {(field.options ?? []).map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
          {help}
        </div>
      );
    case "datetime":
      return (
        <div className={cls}>
          {label}
          <input id={id} type="datetime-local" className="a-input" value={str} required={field.required} onChange={(e) => onChange(e.target.value)} />
          {help}
        </div>
      );
    case "number":
    case "price":
      return (
        <div className={cls}>
          {label}
          <input id={id} type="number" inputMode="decimal" step={field.type === "price" ? "0.01" : "1"} min={0} className="a-input" value={str} required={field.required} onChange={(e) => onChange(e.target.value)} />
          {help}
        </div>
      );
    case "images":
      return (
        <div className={cls}>
          <span className="a-label">{field.label}</span>
          {help}
          <MultiImageInput value={Array.isArray(value) ? value : []} onChange={onChange} />
        </div>
      );
    case "list":
      return <ListInput field={field} value={Array.isArray(value) ? value : []} onChange={onChange} idPrefix={id} />;
    default: {
      const listId = field.suggestions?.length ? `${id}-list` : undefined;
      return (
        <div className={cls}>
          {label}
          <input
            id={id}
            type={field.type === "email" ? "email" : field.type === "url" ? "url" : "text"}
            className="a-input"
            value={str}
            required={field.required}
            list={listId}
            placeholder={field.type === "slug" ? "created automatically" : undefined}
            onChange={(e) => onChange(e.target.value)}
          />
          {listId && (
            <datalist id={listId}>
              {field.suggestions!.map((s) => (
                <option key={s} value={s} />
              ))}
            </datalist>
          )}
          {help}
        </div>
      );
    }
  }
}

/** Repeatable group of fields (timeline items, opening hours, polaroids…). */
function ListInput({ field, value, onChange, idPrefix }: { field: AnyField; value: Values[]; onChange: (v: Values[]) => void; idPrefix: string }) {
  const empty = () => Object.fromEntries((field.fields ?? []).map((f) => [f.name, f.type === "checkbox" ? false : ""]));
  const update = (i: number, key: string, v: unknown) => onChange(value.map((item, j) => (j === i ? { ...item, [key]: v } : item)));
  const move = (i: number, d: number) => {
    const j = i + d;
    if (j < 0 || j >= value.length) return;
    const next = [...value];
    [next[i], next[j]] = [next[j], next[i]];
    onChange(next);
  };
  return (
    <div className="a-field">
      <span className="a-label">{field.label}</span>
      {field.help && <span className="a-help">{field.help}</span>}
      <div className="a-list">
        {value.map((item, i) => (
          <div key={i} className="a-list-item">
            <div className="a-list-head">
              <span>
                {field.itemLabel ?? "Item"} {i + 1}
              </span>
              <span className="a-row">
                <button type="button" className="a-btn sm ghost" onClick={() => move(i, -1)} disabled={i === 0} aria-label="Move up">
                  ↑
                </button>
                <button type="button" className="a-btn sm ghost" onClick={() => move(i, 1)} disabled={i === value.length - 1} aria-label="Move down">
                  ↓
                </button>
                <button type="button" className="a-btn sm danger" onClick={() => onChange(value.filter((_, j) => j !== i))}>
                  Remove
                </button>
              </span>
            </div>
            <div className="a-form">
              {(field.fields ?? []).map((sub) => (
                <FieldInput
                  key={sub.name}
                  field={{ ...sub, half: (field.fields?.length ?? 0) > 2 && sub.type !== "textarea" && sub.type !== "richtext" && sub.type !== "image" }}
                  value={item[sub.name]}
                  onChange={(v) => update(i, sub.name, v)}
                  idPrefix={`${idPrefix}-${i}`}
                />
              ))}
            </div>
          </div>
        ))}
      </div>
      <div>
        <button type="button" className="a-btn" onClick={() => onChange([...value, empty()])}>
          + Add {(field.itemLabel ?? "item").toLowerCase()}
        </button>
      </div>
    </div>
  );
}
AMMOS_EOF
echo "  ✔ components/admin/Fields.tsx"

mkdir -p "components/admin"
cat > "components/admin/MultiImageInput.tsx" << 'AMMOS_EOF'
"use client";

import { useRef, useState } from "react";
import { uploadFile } from "@/components/admin/api";

/** Several photos: upload many at once, drag (or ← →) to reorder, remove. */
export function MultiImageInput({ value, onChange }: { value: string[]; onChange: (v: string[]) => void }) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [status, setStatus] = useState("");
  const [error, setError] = useState("");
  const [drag, setDrag] = useState<number | null>(null);
  const [over, setOver] = useState(false);

  async function addFiles(files: FileList | File[] | null) {
    const list = Array.from(files ?? []).filter((f) => f.type.startsWith("image/"));
    if (!list.length) return;
    setError("");
    const added: string[] = [];
    for (const [i, file] of list.entries()) {
      setStatus(`Uploading ${i + 1} of ${list.length}…`);
      try {
        added.push(await uploadFile(file));
      } catch (e) {
        setError(`${file.name}: ${(e as Error).message}`);
      }
    }
    onChange([...value, ...added]);
    setStatus(added.length ? `${added.length} photo${added.length === 1 ? "" : "s"} added — click Save.` : "");
    if (fileRef.current) fileRef.current.value = "";
  }

  const move = (from: number, to: number) => {
    if (to < 0 || to >= value.length || from === to) return;
    const next = [...value];
    const [x] = next.splice(from, 1);
    next.splice(to, 0, x);
    onChange(next);
  };

  return (
    <div
      className={`a-multi${over ? " is-over" : ""}`}
      onDragOver={(e) => {
        if (e.dataTransfer.types.includes("Files")) {
          e.preventDefault();
          setOver(true);
        }
      }}
      onDragLeave={() => setOver(false)}
      onDrop={(e) => {
        if (!e.dataTransfer.files?.length) return;
        e.preventDefault();
        setOver(false);
        addFiles(e.dataTransfer.files);
      }}
    >
      {value.length > 0 && (
        <div className="a-multi-grid">
          {value.map((src, i) => (
            <div
              key={`${src}-${i}`}
              className={`a-multi-item${drag === i ? " is-drag" : ""}`}
              draggable
              onDragStart={() => setDrag(i)}
              onDragEnd={() => setDrag(null)}
              onDragOver={(e) => {
                if (drag !== null) e.preventDefault();
              }}
              onDrop={(e) => {
                if (drag === null) return;
                e.preventDefault();
                e.stopPropagation();
                move(drag, i);
                setDrag(null);
              }}
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={src} alt="" loading="lazy" />
              <span className="a-multi-num">{i + 1}</span>
              <div className="a-multi-actions">
                <button type="button" onClick={() => move(i, i - 1)} disabled={i === 0} aria-label="Move left">
                  ←
                </button>
                <button type="button" onClick={() => move(i, i + 1)} disabled={i === value.length - 1} aria-label="Move right">
                  →
                </button>
                <button type="button" className="del" onClick={() => onChange(value.filter((_, j) => j !== i))} aria-label="Remove photo">
                  ✕
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
      <div className="a-row">
        <button type="button" className="a-btn" onClick={() => fileRef.current?.click()} disabled={status.startsWith("Uploading")}>
          + Add photos
        </button>
        <span className="a-help">{status || (value.length ? `${value.length} photo${value.length === 1 ? "" : "s"}` : "No photos yet — or drop images here")}</span>
      </div>
      <input ref={fileRef} type="file" multiple hidden accept="image/jpeg,image/png,image/webp,image/avif,image/gif" onChange={(e) => addFiles(e.target.files)} />
      {error && <span className="a-msg err">{error}</span>}
    </div>
  );
}
AMMOS_EOF
echo "  ✔ components/admin/MultiImageInput.tsx"

mkdir -p "components/admin"
cat > "components/admin/MenuSyncButton.tsx" << 'AMMOS_EOF'
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/components/admin/api";

/** Pulls the latest prices & dishes from the live menu (ammos-beach-bar.nina.cy). */
export function MenuSyncButton() {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  async function sync() {
    if (!confirm("Update the website menu from the live menu (ammos-beach-bar.nina.cy)?\n\nNew items are added and prices/descriptions updated. Your photos and homepage ticks are kept. Items no longer on the live menu are hidden.")) return;
    setBusy(true);
    setMsg(null);
    try {
      const r = await api<{ total: number; added: number; updated: number; hidden: number; categories: number }>("/api/admin/menu-sync", { method: "POST" });
      setMsg({ ok: true, text: `Done — ${r.total} items in ${r.categories} categories (${r.added} new, ${r.updated} updated, ${r.hidden} hidden).` });
      router.refresh();
    } catch (e) {
      setMsg({ ok: false, text: (e as Error).message });
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <button type="button" className="a-btn" onClick={sync} disabled={busy}>
        {busy ? "Syncing…" : "↻ Sync from live menu"}
      </button>
      {msg && (
        <span className={`a-msg ${msg.ok ? "ok" : "err"}`} style={{ maxWidth: 420 }}>
          {msg.text}
        </span>
      )}
    </>
  );
}
AMMOS_EOF
echo "  ✔ components/admin/MenuSyncButton.tsx"

mkdir -p "app/api/admin/menu-sync"
cat > "app/api/admin/menu-sync/route.ts" << 'AMMOS_EOF'
import { db } from "@/lib/db";
import { errorJson, json, rateLimit, withAdmin } from "@/lib/http";
import { fetchLiveMenu, parseMenu, syncMenu } from "@/lib/menu-import";
import { refreshSite } from "@/lib/revalidate";

export const runtime = "nodejs";

/** POST /api/admin/menu-sync → copy the live menu (ammos-beach-bar.nina.cy) into the website. */
export const POST = withAdmin(async (_req, _ctx, user) => {
  if (!rateLimit(`menu-sync:${user.id}`, 6, 10 * 60_000).ok) return errorJson("Please wait a few minutes before syncing again.", 429);
  let md: string;
  try {
    md = await fetchLiveMenu();
  } catch (err) {
    return errorJson(`Could not download the live menu: ${(err as Error).message}`, 502);
  }
  const result = await syncMenu(db, parseMenu(md));
  refreshSite();
  return json({ ok: true, ...result });
});
AMMOS_EOF
echo "  ✔ app/api/admin/menu-sync/route.ts"

mkdir -p "app/admin/(panel)/[resource]"
cat > "app/admin/(panel)/[resource]/page.tsx" << 'AMMOS_EOF'
import Link from "next/link";
import { notFound } from "next/navigation";
import { RESOURCE_MAP, type Column } from "@/lib/admin/resources";
import { listRows, menuCategoryOptions } from "@/lib/admin/resources.server";
import { formatDate, formatDateTime, formatPrice } from "@/lib/utils";
import { PageTop } from "@/components/admin/PageTop";
import { GalleryBulkUpload } from "@/components/admin/GalleryBulkUpload";
import { MenuSyncButton } from "@/components/admin/MenuSyncButton";

type Props = { params: Promise<{ resource: string }>; searchParams: Promise<{ q?: string; filter?: string }> };

export async function generateMetadata({ params }: Props) {
  const { resource } = await params;
  return { title: RESOURCE_MAP[resource]?.title ?? "Admin" };
}

function cell(col: Column, row: Record<string, any>) {
  const v = row[col.key];
  switch (col.kind) {
    case "image":
      // eslint-disable-next-line @next/next/no-img-element
      return v ? <img className="thumb" src={v} alt="" loading="lazy" /> : <span className="thumb" />;
    case "bool":
      return v ? <span className="pill-ok">yes</span> : <span className="pill-off">no</span>;
    case "date":
      return v ? formatDate(v, { day: "numeric", month: "short", year: "numeric" }) : "—";
    case "datetime":
      return v ? formatDateTime(v) : "—";
    case "price":
      return formatPrice(v) || "—";
    case "count":
      return <b>{v ?? 0}</b>;
    default:
      return <span className="clip" style={{ display: "block" }}>{String(v ?? "")}</span>;
  }
}

export default async function ResourceList({ params, searchParams }: Props) {
  const { resource } = await params;
  const def = RESOURCE_MAP[resource];
  if (!def) notFound();
  const { q = "", filter = "" } = await searchParams;
  const rows = await listRows(resource, { q: q.slice(0, 100), filter });
  const cats = resource === "menu-items" ? await menuCategoryOptions() : [];
  const titleKey = def.columns.find((c) => !c.kind || c.kind === "text")?.key;

  return (
    <>
      <PageTop
        title={def.title}
        actions={
          <>
            {(resource === "menu-items" || resource === "menu-categories") && <MenuSyncButton />}
            <Link href={`/admin/${resource}/new`} className="a-btn primary">
              + Add {def.singular}
            </Link>
          </>
        }
      />
      <div className="a-content">
        <p className="a-desc">{def.description}</p>
        <div className="a-toolbar">
          <form className="a-search" action={`/admin/${resource}`}>
            {resource === "events" && (
              <div className="a-tabs" style={{ marginRight: 8 }}>
                {[
                  ["", "All"],
                  ["upcoming", "Upcoming"],
                  ["past", "Past"],
                ].map(([val, label]) => (
                  <Link key={val} href={`/admin/events${val ? `?filter=${val}` : ""}`} className={filter === val ? "is-active" : ""}>
                    {label}
                  </Link>
                ))}
              </div>
            )}
            {resource === "menu-items" && (
              <select name="filter" defaultValue={filter} className="a-input" style={{ width: 240 }}>
                <option value="">All categories</option>
                {cats.map((c) => (
                  <option key={c.value} value={c.value}>
                    {c.label}
                  </option>
                ))}
              </select>
            )}
            <input name="q" defaultValue={q} className="a-input" placeholder="Search…" style={{ width: 220 }} />
            {resource === "events" && filter && <input type="hidden" name="filter" value={filter} />}
            <button className="a-btn" type="submit">
              Search
            </button>
            {(q || filter) && (
              <Link className="a-btn ghost" href={`/admin/${resource}`}>
                Clear
              </Link>
            )}
          </form>
          <span className="a-help">{rows.length} shown</span>
        </div>

        {resource === "gallery" && <GalleryBulkUpload />}

        <div className="a-table-wrap">
          {rows.length ? (
            <table className="a-table">
              <thead>
                <tr>
                  {def.columns.map((c) => (
                    <th key={c.key}>{c.label}</th>
                  ))}
                  <th />
                </tr>
              </thead>
              <tbody>
                {rows.map((row: Record<string, any>) => (
                  <tr key={row.id}>
                    {def.columns.map((c) => (
                      <td key={c.key}>
                        {c.key === titleKey ? (
                          <Link href={`/admin/${resource}/${row.id}`} className="title">
                            {String(row[c.key] || "(untitled)")}
                          </Link>
                        ) : c.key === "bookingCount" ? (
                          <Link href={`/admin/bookings?event=${row.id}`}>
                            <b>{row.bookingCount ?? 0}</b>
                            {row.capacity ? ` / ${row.capacity}` : ""}
                          </Link>
                        ) : (
                          cell(c, row)
                        )}
                      </td>
                    ))}
                    <td style={{ textAlign: "right" }}>
                      <Link href={`/admin/${resource}/${row.id}`} className="a-btn sm">
                        Edit
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <p className="a-empty">
              Nothing here yet. <Link href={`/admin/${resource}/new`}>Add the first {def.singular}</Link>.
            </p>
          )}
        </div>
      </div>
    </>
  );
}
AMMOS_EOF
echo "  ✔ app/admin/(panel)/[resource]/page.tsx"

mkdir -p "app/admin"
cat > "app/admin/admin.css" << 'AMMOS_EOF'
/* ═══════════ AMMOS ADMIN PANEL ═══════════ */
.admin {
  --a-bg: #0c0e15;
  --a-panel: #141726;
  --a-card: #1a1d2b;
  --a-line: #2a2e3d;
  --a-text: #e9e9ed;
  --a-muted: #9397ab;
  --a-ok: #b7d44a;
  --a-warn: #f2b84b;
  --a-bad: #f06262;
  min-height: 100vh;
  background: var(--a-bg);
  color: var(--a-text);
  font-family: var(--body);
  font-size: 14px;
  line-height: 1.5;
}
.admin a { color: var(--brand); }
.admin h1, .admin h2, .admin h3 { font-family: var(--body); font-weight: 600; letter-spacing: 0; text-transform: none; margin: 0; }

/* layout */
.a-shell { display: grid; grid-template-columns: 248px minmax(0, 1fr); min-height: 100vh; }
.a-side { background: var(--a-panel); border-right: 1px solid var(--a-line); padding: 22px 14px; position: sticky; top: 0; height: 100vh; overflow-y: auto; display: flex; flex-direction: column; gap: 18px; }
.a-side .brand { display: flex; align-items: center; gap: 10px; padding: 4px 10px 10px; }
.a-side .brand img { height: 34px; width: auto; }
.a-side .brand span { font-size: 10px; letter-spacing: 0.2em; text-transform: uppercase; color: var(--a-muted); }
.a-nav-group { display: grid; gap: 2px; }
.a-nav-title { font-size: 10px; letter-spacing: 0.22em; text-transform: uppercase; color: var(--a-muted); padding: 6px 10px; }
.a-nav-link { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 9px 12px; border-radius: 8px; color: var(--a-text) !important; font-size: 14px; }
.a-nav-link:hover { background: rgba(255, 255, 255, 0.05); }
.a-nav-link.is-active { background: rgba(62, 198, 216, 0.14); color: var(--brand) !important; }
.a-badge { min-width: 20px; height: 20px; padding: 0 6px; border-radius: 999px; background: var(--brand); color: var(--ink); font-size: 11px; font-weight: 700; display: inline-flex; align-items: center; justify-content: center; }
.a-side-foot { margin-top: auto; border-top: 1px solid var(--a-line); padding-top: 14px; display: grid; gap: 6px; font-size: 13px; }
.a-side-foot .who { padding: 0 12px; color: var(--a-muted); }
.a-main { min-width: 0; }
.a-top { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 16px 32px; border-bottom: 1px solid var(--a-line); background: rgba(12, 14, 21, 0.9); backdrop-filter: blur(10px); position: sticky; top: 0; z-index: 10; }
.a-top h1 { font-size: 20px; }
.a-content { padding: 28px 32px 80px; max-width: 1280px; }
.a-btn.a-menu-toggle { display: none; }

/* buttons */
.a-btn { display: inline-flex; align-items: center; justify-content: center; gap: 6px; padding: 9px 16px; border-radius: 8px; border: 1px solid var(--a-line); background: var(--a-card); color: var(--a-text) !important; font: inherit; font-size: 13px; font-weight: 500; cursor: pointer; white-space: nowrap; text-decoration: none; transition: background 0.2s, border-color 0.2s; }
.a-btn:hover { border-color: var(--brand); }
.a-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.a-btn.primary { background: var(--brand); border-color: var(--brand); color: var(--ink) !important; }
.a-btn.primary:hover { background: var(--brand-hover); }
.a-btn.danger { color: var(--a-bad) !important; border-color: rgba(240, 98, 98, 0.4); background: transparent; }
.a-btn.danger:hover { background: rgba(240, 98, 98, 0.1); }
.a-btn.ghost { background: transparent; }
.a-btn.sm { padding: 6px 10px; font-size: 12px; }
.a-row { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
.a-spread { display: flex; gap: 12px; align-items: center; justify-content: space-between; flex-wrap: wrap; }

/* cards & stats */
.a-card { background: var(--a-card); border: 1px solid var(--a-line); border-radius: 12px; padding: 20px; }
.a-card + .a-card { margin-top: 16px; }
.a-grid-2 > .a-card { margin-top: 0; }
.a-card h2 { font-size: 16px; margin-bottom: 14px; }
.a-desc { color: var(--a-muted); margin: 0 0 20px; max-width: 760px; }
.a-stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 14px; margin-bottom: 20px; }
.a-stat { background: var(--a-card); border: 1px solid var(--a-line); border-radius: 12px; padding: 18px 20px; color: var(--a-text) !important; display: block; transition: border-color 0.2s; }
.a-stat:hover { border-color: var(--brand); }
.a-stat b { display: block; font-size: 30px; font-weight: 600; color: var(--brand); line-height: 1.1; }
.a-stat span { color: var(--a-muted); font-size: 13px; }
.a-grid-2 { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px; }

/* tables */
.a-table-wrap { overflow-x: auto; border: 1px solid var(--a-line); border-radius: 12px; background: var(--a-card); }
.a-table { width: 100%; border-collapse: collapse; }
.a-table th { text-align: left; font-size: 11px; letter-spacing: 0.12em; text-transform: uppercase; color: var(--a-muted); font-weight: 500; padding: 12px 14px; border-bottom: 1px solid var(--a-line); white-space: nowrap; }
.a-table td { padding: 10px 14px; border-bottom: 1px solid var(--a-line); vertical-align: middle; }
.a-table tr:last-child td { border-bottom: 0; }
.a-table tbody tr:hover { background: rgba(255, 255, 255, 0.025); }
.a-table .thumb { width: 52px; height: 52px; border-radius: 8px; object-fit: cover; background: var(--a-panel); display: block; }
.a-table .clip { max-width: 360px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.a-table a.title { color: var(--a-text) !important; font-weight: 500; }
.a-table a.title:hover { color: var(--brand) !important; }
.a-empty { padding: 48px; text-align: center; color: var(--a-muted); }
.pill-ok, .pill-off, .pill-warn, .pill-bad { display: inline-block; padding: 2px 9px; border-radius: 999px; font-size: 11px; font-weight: 600; }
.pill-ok { background: rgba(183, 212, 74, 0.16); color: var(--a-ok); }
.pill-off { background: rgba(255, 255, 255, 0.07); color: var(--a-muted); }
.pill-warn { background: rgba(242, 184, 75, 0.16); color: var(--a-warn); }
.pill-bad { background: rgba(240, 98, 98, 0.16); color: var(--a-bad); }

/* toolbar */
.a-toolbar { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; justify-content: space-between; margin-bottom: 16px; }
.a-search { display: flex; gap: 8px; }
.a-tabs { display: inline-flex; border: 1px solid var(--a-line); border-radius: 8px; overflow: hidden; }
.a-tabs a { padding: 8px 14px; color: var(--a-muted) !important; font-size: 13px; }
.a-tabs a + a { border-left: 1px solid var(--a-line); }
.a-tabs a.is-active { background: rgba(62, 198, 216, 0.14); color: var(--brand) !important; }

/* forms */
.a-form { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 18px 20px; }
.a-field { grid-column: 1 / -1; display: flex; flex-direction: column; gap: 6px; }
.a-field.half { grid-column: auto; }
.a-field > label, .a-label { font-size: 13px; font-weight: 500; color: var(--a-text); }
.a-field .req { color: var(--brand); }
.a-help { font-size: 12px; color: var(--a-muted); }
.a-input { width: 100%; padding: 10px 12px; border-radius: 8px; border: 1px solid var(--a-line); background: var(--a-panel); color: var(--a-text); font: inherit; font-size: 14px; }
.a-input:focus { outline: none; border-color: var(--brand); box-shadow: 0 0 0 3px rgba(62, 198, 216, 0.15); }
textarea.a-input { min-height: 96px; resize: vertical; line-height: 1.55; }
textarea.a-input.rich { min-height: 220px; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 13px; }
select.a-input { cursor: pointer; }
input[type="datetime-local"].a-input, input[type="date"].a-input { color-scheme: dark; }
.a-check { display: flex; align-items: center; gap: 10px; cursor: pointer; padding: 10px 12px; border: 1px solid var(--a-line); border-radius: 8px; background: var(--a-panel); }
.a-check input { width: 18px; height: 18px; accent-color: var(--brand); }
.a-form-actions { grid-column: 1 / -1; display: flex; gap: 10px; align-items: center; flex-wrap: wrap; padding-top: 8px; border-top: 1px solid var(--a-line); margin-top: 6px; position: sticky; bottom: 0; background: var(--a-card); padding-bottom: 4px; }
.a-msg { padding: 10px 14px; border-radius: 8px; font-size: 13px; }
.a-msg.ok { background: rgba(183, 212, 74, 0.14); color: var(--a-ok); }
.a-msg.err { background: rgba(240, 98, 98, 0.14); color: #ffb3b3; }

/* media input */
.a-media { display: grid; grid-template-columns: 160px minmax(0, 1fr); gap: 14px; align-items: start; }
.a-media-preview { width: 160px; aspect-ratio: 4 / 3; border-radius: 10px; overflow: hidden; background: var(--a-panel); border: 1px dashed var(--a-line); display: flex; align-items: center; justify-content: center; color: var(--a-muted); font-size: 12px; text-align: center; }
.a-media-preview img, .a-media-preview video { width: 100%; height: 100%; object-fit: cover; }
.a-media-controls { display: grid; gap: 8px; }
.a-drop.is-over { border-color: var(--brand); background: rgba(62, 198, 216, 0.08); }

/* list fields (content editor) */
.a-list { display: grid; gap: 12px; }
.a-list-item { border: 1px solid var(--a-line); border-radius: 10px; padding: 14px; background: rgba(255, 255, 255, 0.015); }
.a-list-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; font-size: 12px; color: var(--a-muted); letter-spacing: 0.1em; text-transform: uppercase; }
.a-list-item .a-form { gap: 12px 14px; }

/* message / booking detail */
.a-detail { white-space: pre-wrap; background: var(--a-panel); border-radius: 8px; padding: 12px 14px; margin: 8px 0; }
.a-kv { display: grid; grid-template-columns: 140px 1fr; gap: 6px 14px; font-size: 13px; }
.a-kv dt { color: var(--a-muted); }
.a-kv dd { margin: 0; }
.unread td { font-weight: 600; }
.unread td:first-child { box-shadow: inset 3px 0 0 var(--brand); }
.a-drawer-bg { position: fixed; inset: 0; background: rgba(0, 0, 0, 0.55); z-index: 40; }
.a-drawer { position: fixed; top: 0; right: 0; bottom: 0; width: min(560px, 100%); background: var(--a-card); border-left: 1px solid var(--a-line); z-index: 41; padding: 24px; overflow-y: auto; display: grid; gap: 16px; align-content: start; }

/* content sections list */
.a-sections { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 12px; }
.a-section-card { display: block; padding: 16px 18px; border: 1px solid var(--a-line); border-radius: 12px; background: var(--a-card); color: var(--a-text) !important; }
.a-section-card:hover { border-color: var(--brand); }
.a-section-card b { display: block; margin-bottom: 4px; }
.a-section-card span { color: var(--a-muted); font-size: 13px; }

/* login */
.a-login { min-height: 100vh; display: grid; place-items: center; padding: 24px; background: radial-gradient(60% 50% at 80% 0%, rgba(62, 198, 216, 0.16), transparent 70%), var(--a-bg); }
.a-login-card { width: min(420px, 100%); background: var(--a-card); border: 1px solid var(--a-line); border-radius: 16px; padding: 36px 32px; display: grid; gap: 16px; }
.a-login-card img { height: 46px; width: auto; margin: 0 auto 8px; }
.a-login-card h1 { text-align: center; font-size: 18px; }

@media (max-width: 900px) {
  .a-shell { grid-template-columns: 1fr; }
  .a-side { position: fixed; z-index: 50; left: 0; top: 0; width: 260px; transform: translateX(-100%); transition: transform 0.3s; }
  .a-side.is-open { transform: none; box-shadow: 0 0 0 100vmax rgba(0, 0, 0, 0.5); }
  .a-btn.a-menu-toggle { display: inline-flex; }
  .a-top { padding: 12px 16px; }
  .a-content { padding: 20px 16px 80px; }
  .a-form { grid-template-columns: 1fr; }
  .a-field.half { grid-column: 1 / -1; }
  .a-grid-2 { grid-template-columns: 1fr; }
  .a-media { grid-template-columns: 1fr; }
  .a-kv { grid-template-columns: 1fr; }
}

/* ── multiple photos field (event photos) ── */
.a-multi { display: grid; gap: 12px; padding: 12px; border: 1px dashed var(--a-line); border-radius: 12px; }
.a-multi.is-over { border-color: var(--a-accent, #00b8c8); background: rgba(0, 184, 200, 0.06); }
.a-multi-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: 10px; }
.a-multi-item { position: relative; aspect-ratio: 1; border-radius: 10px; overflow: hidden; background: var(--a-panel); cursor: grab; }
.a-multi-item.is-drag { opacity: 0.4; }
.a-multi-item img { width: 100%; height: 100%; object-fit: cover; display: block; pointer-events: none; }
.a-multi-num { position: absolute; top: 6px; left: 6px; min-width: 22px; height: 22px; padding: 0 6px; border-radius: 11px; background: rgba(0, 0, 0, 0.65); color: #fff; font-size: 11px; display: flex; align-items: center; justify-content: center; }
.a-multi-actions { position: absolute; left: 0; right: 0; bottom: 0; display: flex; justify-content: space-between; gap: 4px; padding: 6px; background: linear-gradient(transparent, rgba(0, 0, 0, 0.7)); }
.a-multi-actions button { width: 28px; height: 28px; border: 0; border-radius: 8px; background: rgba(255, 255, 255, 0.92); color: #111; cursor: pointer; font-size: 13px; }
.a-multi-actions button:disabled { opacity: 0.35; cursor: default; }
.a-multi-actions button.del { margin-left: auto; background: #e5484d; color: #fff; }
AMMOS_EOF
echo "  ✔ app/admin/admin.css"

mkdir -p "components/site"
cat > "components/site/EventPhotos.tsx" << 'AMMOS_EOF'
"use client";

import { useCallback, useEffect, useState } from "react";
import { Img } from "@/components/site/Img";

const SHOWN = 5;

/** Event page photo mosaic (1 big + 4 small) with a full-screen viewer. */
export function EventPhotos({ photos, title }: { photos: string[]; title: string }) {
  const [open, setOpen] = useState<number | null>(null);
  const close = useCallback(() => setOpen(null), []);
  const step = useCallback((d: number) => setOpen((i) => (i === null ? i : (i + d + photos.length) % photos.length)), [photos.length]);

  useEffect(() => {
    if (open === null) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") close();
      if (e.key === "ArrowRight") step(1);
      if (e.key === "ArrowLeft") step(-1);
    };
    window.addEventListener("keydown", onKey);
    document.documentElement.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.documentElement.style.overflow = "";
    };
  }, [open, close, step]);

  if (!photos.length) return null;
  const shown = photos.slice(0, SHOWN);
  const more = photos.length - shown.length;

  return (
    <>
      <div className={`event-photos count-${shown.length}`}>
        {shown.map((src, i) => (
          <button
            key={`${src}-${i}`}
            type="button"
            className="event-photo"
            data-reveal
            style={{ transitionDelay: `${i * 0.08}s` }}
            onClick={() => setOpen(i)}
            aria-label={`Open photo ${i + 1} of ${photos.length}`}
          >
            <Img src={src} alt={`${title} at Ammos Makenzy Beach — photo ${i + 1}`} sizes={i === 0 ? "(max-width: 900px) 100vw, 40vw" : "(max-width: 900px) 50vw, 20vw"} />
            {i === shown.length - 1 && more > 0 && <span className="event-photo-more">+{more}</span>}
          </button>
        ))}
      </div>
      {open !== null && (
        <div className="lightbox" role="dialog" aria-modal="true" aria-label="Photo viewer" onClick={close}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={photos[open]} alt={`${title} — photo ${open + 1}`} onClick={(e) => e.stopPropagation()} />
          {photos.length > 1 && (
            <>
              <button type="button" className="round-btn on-dark lb-btn lb-prev" aria-label="Previous photo" onClick={(e) => (e.stopPropagation(), step(-1))}>
                ←
              </button>
              <button type="button" className="round-btn on-dark lb-btn lb-next" aria-label="Next photo" onClick={(e) => (e.stopPropagation(), step(1))}>
                →
              </button>
            </>
          )}
          <button type="button" className="round-btn on-dark lb-close" aria-label="Close" onClick={close}>
            ×
          </button>
          <p className="lb-cap">
            {open + 1} / {photos.length}
          </p>
        </div>
      )}
    </>
  );
}
AMMOS_EOF
echo "  ✔ components/site/EventPhotos.tsx"

mkdir -p "components/site"
cat > "components/site/NewsCarousel.tsx" << 'AMMOS_EOF'
"use client";

import { Children, useEffect, useRef, useState } from "react";

/** News cards: 3-column grid on desktop, swipeable carousel with dots on phones & tablets. */
export function NewsCarousel({ children }: { children: React.ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  const count = Children.count(children);
  const [active, setActive] = useState(0);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const onScroll = () => {
      const slides = Array.from(el.children) as HTMLElement[];
      if (!slides.length) return;
      const center = el.scrollLeft + el.clientWidth / 2;
      let best = 0;
      let dist = Infinity;
      slides.forEach((s, i) => {
        const d = Math.abs(s.offsetLeft - el.offsetLeft + s.offsetWidth / 2 - center);
        if (d < dist) {
          dist = d;
          best = i;
        }
      });
      setActive(best);
    };
    el.addEventListener("scroll", onScroll, { passive: true });
    return () => el.removeEventListener("scroll", onScroll);
  }, []);

  const go = (i: number) => {
    const el = ref.current;
    const slide = el?.children[i] as HTMLElement | undefined;
    if (el && slide) el.scrollTo({ left: slide.offsetLeft - el.offsetLeft - (el.clientWidth - slide.offsetWidth) / 2, behavior: "smooth" });
  };

  return (
    <div className="news-carousel">
      <div ref={ref} className="news-grid news-track" role="region" aria-label="Latest news" tabIndex={0}>
        {children}
      </div>
      {count > 1 && (
        <div className="news-dots" role="tablist" aria-label="Choose article">
          {Array.from({ length: count }, (_, i) => (
            <button key={i} type="button" role="tab" aria-selected={i === active} aria-label={`Article ${i + 1}`} className={i === active ? "is-active" : ""} onClick={() => go(i)} />
          ))}
        </div>
      )}
    </div>
  );
}
AMMOS_EOF
echo "  ✔ components/site/NewsCarousel.tsx"

mkdir -p "components/site"
cat > "components/site/HomeMenu.tsx" << 'AMMOS_EOF'
"use client";

import { useRef, useState } from "react";
import { formatPrice } from "@/lib/utils";

type Tab = { name: string; slug: string; items: { id: string; name: string; description: string; price: string; image: string }[] };

/**
 * Menu tabs + dish list. If a dish has its own photo (Admin → Menu items),
 * the photo floats next to the mouse on hover. Dishes without a photo show no image.
 */
export function HomeMenu({ tabs, intro, after }: { tabs: Tab[]; intro: React.ReactNode; after?: React.ReactNode }) {
  const [active, setActive] = useState(tabs[0]?.slug ?? "");
  const hoverRef = useRef<HTMLDivElement>(null);
  const imgRef = useRef<HTMLImageElement>(null);
  const tab = tabs.find((t) => t.slug === active) ?? tabs[0];

  const move = (e: React.MouseEvent) => {
    const el = hoverRef.current;
    if (el) {
      el.style.left = `${e.clientX}px`;
      el.style.top = `${e.clientY}px`;
    }
  };
  const show = (src: string) => {
    if (!src) return hide();
    if (imgRef.current && imgRef.current.getAttribute("src") !== src) imgRef.current.src = src;
    hoverRef.current?.classList.add("is-on");
  };
  const hide = () => hoverRef.current?.classList.remove("is-on");

  return (
    <div className="menu-home-grid">
      <div className="menu-home-intro" data-reveal>
        {intro}
        {tabs.length > 1 && (
          <div className="pill-tabs" role="tablist" aria-label="Menu categories">
            {tabs.map((t) => (
              <button
                key={t.slug}
                type="button"
                role="tab"
                aria-selected={t.slug === tab?.slug}
                className={`pill${t.slug === tab?.slug ? " is-active" : ""}`}
                onClick={() => (hide(), setActive(t.slug))}
              >
                {t.name}
              </button>
            ))}
          </div>
        )}
        {after}
      </div>
      <div onMouseMove={move} onMouseLeave={hide} role="tabpanel" aria-label={tab?.name}>
        {tab?.items.map((m) => (
          <div key={m.id} className="dish" onMouseEnter={() => show(m.image)}>
            <div>
              <h3>{m.name}</h3>
              {m.description && <p>{m.description}</p>}
            </div>
            <span className="dish-price">{formatPrice(m.price)}</span>
          </div>
        ))}
      </div>
      <div ref={hoverRef} className="hover-image" aria-hidden="true">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img ref={imgRef} alt="" decoding="async" />
      </div>
    </div>
  );
}
AMMOS_EOF
echo "  ✔ components/site/HomeMenu.tsx"

mkdir -p "app/(site)/events/[slug]"
cat > "app/(site)/events/[slug]/page.tsx" << 'AMMOS_EOF'
import Link from "next/link";
import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { getSettings } from "@/lib/content";
import { getBookedGuests, getEventBySlug, getOtherUpcomingEvents, startOfTodayCyprus } from "@/lib/data";
import { eventJsonLd, pageMeta } from "@/lib/seo";
import { eventDateParts, formatDate, truncate } from "@/lib/utils";
import { PageHero } from "@/components/site/PageHero";
import { RichText } from "@/components/site/RichText";
import { BookingForm } from "@/components/site/BookingForm";
import { EventCard } from "@/components/site/EventCard";
import { JsonLd } from "@/components/site/JsonLd";
import { EventPhotos } from "@/components/site/EventPhotos";

export const revalidate = 300;
export const dynamicParams = true;
export function generateStaticParams() {
  return []; // pages are built on first visit, then cached
}

type Params = Promise<{ slug: string }>;

export async function generateMetadata({ params }: { params: Params }): Promise<Metadata> {
  const { slug } = await params;
  const e = await getEventBySlug(slug);
  if (!e) return { title: "Event not found", robots: { index: false } };
  const d = eventDateParts(e.startsAt);
  return pageMeta({
    title: `${e.title} — ${d.weekday} ${d.dayNum} ${d.monthLong} ${d.year}`,
    description: truncate(e.summary || e.description, 160) || `${e.category} at Ammos Makenzy Beach, Larnaca.`,
    path: `/events/${e.slug}`,
    image: e.image,
  });
}

export default async function EventPage({ params }: { params: Params }) {
  const { slug } = await params;
  const event = await getEventBySlug(slug);
  if (!event) notFound();

  const [settings, booked, others] = await Promise.all([getSettings(), getBookedGuests(event.id), getOtherUpcomingEvents(event.id, 3)]);
  const d = eventDateParts(event.startsAt);
  const isPast = event.startsAt < startOfTodayCyprus();
  const left = event.capacity ? Math.max(0, event.capacity - booked) : null;
  const canBook = !isPast && event.bookingEnabled && (left === null || left > 0);
  // event photos from the admin; if none were added, show the main photo so the page never looks empty
  const photos = (Array.isArray(event.gallery) ? event.gallery : []).filter(Boolean);
  const gallery = photos.length ? photos : event.image ? [event.image] : [];

  return (
    <>
      <PageHero
        kicker={`${event.category} · ${event.venue}`}
        title={event.title}
        text={event.summary}
        image={event.image}
        crumbs={[
          { name: "Events", path: "/events" },
          { name: event.title, path: `/events/${event.slug}` },
        ]}
      >
        <div className="btn-row" style={{ marginTop: 28 }}>
          {canBook && (
            <a href="#book" className="btn btn-brand">
              Book this event
            </a>
          )}
          <a href={settings.reservationUrl} target="_blank" rel="noopener noreferrer" className="btn btn-ghost-light">
            Reserve a table
          </a>
        </div>
      </PageHero>

      <section className="section">
        <div className="container event-detail-grid">
          <div>
            <dl className="event-facts" style={{ marginTop: 0 }}>
              <div>
                <dt>Date</dt>
                <dd>
                  <time dateTime={event.startsAt.toISOString()}>
                    {d.weekday}, {d.dayNum} {d.month} {d.year}
                  </time>
                </dd>
              </div>
              <div>
                <dt>Time</dt>
                <dd>
                  {d.time}
                  {event.endsAt ? ` – ${eventDateParts(event.endsAt).time}` : ""}
                </dd>
              </div>
              <div>
                <dt>Where</dt>
                <dd>{event.venue}</dd>
              </div>
              {event.priceInfo && (
                <div>
                  <dt>Entry</dt>
                  <dd>{event.priceInfo}</dd>
                </div>
              )}
            </dl>
            <RichText text={event.description} />
            <p className="muted" style={{ marginTop: 32, fontSize: 14 }}>
              Ammos Makenzy Beach · {settings.address}, {settings.city} · <a href={`tel:${settings.phone.replace(/\s/g, "")}`}>{settings.phone}</a>
            </p>
            {gallery.length > 0 && (
              <div className="event-photos-wrap">
                <p className="kicker kicker-teal">{isPast ? "From the night" : "The vibe"}</p>
                <EventPhotos photos={gallery} title={event.title} />
              </div>
            )}
          </div>

          <aside id="book" className="booking-panel form-card" style={{ scrollMarginTop: 100 }}>
            {isPast ? (
              <>
                <h2 className="display">This event has passed</h2>
                <p className="lead" style={{ marginTop: 10 }}>
                  It took place on {formatDate(event.startsAt)}. Have a look at what's coming up next.
                </p>
                <Link href="/events" className="btn btn-outline" style={{ marginTop: 20 }}>
                  Upcoming events
                </Link>
              </>
            ) : canBook ? (
              <>
                <h2 className="display">Book your spot</h2>
                {left !== null && left <= 30 && <p className="spots">Only {left} places left</p>}
                {left === null || left > 30 ? <p className="form-note" style={{ marginBottom: 20 }}>Fill in your details and we'll confirm your table.</p> : null}
                <BookingForm eventId={event.id} eventTitle={event.title} maxGuests={left ?? 30} />
              </>
            ) : (
              <>
                <h2 className="display">{left === 0 ? "Fully booked" : "Booking by phone"}</h2>
                <p className="lead" style={{ marginTop: 10 }}>
                  {left === 0 ? "This night is fully booked online. Call us to join the waiting list." : "Call or message us to reserve for this event."}
                </p>
                <div className="btn-row" style={{ marginTop: 20 }}>
                  <a href={`tel:${settings.phone.replace(/\s/g, "")}`} className="btn btn-brand">
                    Call {settings.phone}
                  </a>
                </div>
              </>
            )}
          </aside>
        </div>
      </section>

      {others.length > 0 && (
        <section className="section events-page">
          <div className="container">
            <p className="kicker kicker-teal">More nights</p>
            <h2 className="display display-md" style={{ color: "var(--ink)", marginBottom: 40 }}>
              also coming up
            </h2>
            <div className="events-grid">
              {others.map((e) => (
                <EventCard key={e.id} event={e} showBadge />
              ))}
            </div>
          </div>
        </section>
      )}
      <JsonLd data={eventJsonLd(event, settings)} />
    </>
  );
}
AMMOS_EOF
echo "  ✔ app/(site)/events/[slug]/page.tsx"

mkdir -p "app/(site)"
cat > "app/(site)/page.tsx" << 'AMMOS_EOF'
import Link from "next/link";
import type { Metadata } from "next";
import { getContent, getSettings } from "@/lib/content";
import { getGallery, getHomeEvents, getHomeMenu, getReviews, listPosts } from "@/lib/data";
import { pageMeta } from "@/lib/seo";
import { initials } from "@/lib/utils";
import { Img } from "@/components/site/Img";
import { Icon } from "@/components/site/Icon";
import { MultiLine } from "@/components/site/MultiLine";
import { EventCard } from "@/components/site/EventCard";
import { HorizontalSlider } from "@/components/site/HorizontalSlider";
import { HeroVideo } from "@/components/site/HeroVideo";
import { DiscoverVideo } from "@/components/site/DiscoverVideo";
import { HomeMenu } from "@/components/site/HomeMenu";
import { ContactForm } from "@/components/site/ContactForm";
import { NewsCarousel } from "@/components/site/NewsCarousel";

// Page is pre-built and refreshed every 5 minutes, and instantly when you save in the admin.
export const revalidate = 300;

export async function generateMetadata(): Promise<Metadata> {
  const s = await getSettings();
  const hero = await getContent("home.hero");
  return { ...pageMeta({ title: s.seoTitle, description: s.seoDescription, path: "/", image: hero.image }), title: { absolute: s.seoTitle } };
}

const FAN = [
  { w: "18%", rot: -14, z: 1, delay: ".5s", from: "translate3d(-120px,80px,0) rotate(-10deg)" },
  { w: "20%", rot: -7, z: 2, delay: ".25s", from: "translate3d(-60px,80px,0) rotate(-6deg)" },
  { w: "24%", rot: 0, z: 3, delay: "0s", from: "translate3d(0,120px,0) scale(0.92)" },
  { w: "20%", rot: 7, z: 2, delay: ".25s", from: "translate3d(60px,80px,0) rotate(6deg)" },
  { w: "18%", rot: 14, z: 1, delay: ".5s", from: "translate3d(120px,80px,0) rotate(10deg)" },
];
const POLAROID_POS = [
  { x: "0%", y: "2%", rot: -8, z: 1 },
  { x: "34%", y: "0%", rot: 5, z: 2 },
  { x: "66%", y: "6%", rot: -4, z: 1 },
  { x: "16%", y: "48%", rot: 6, z: 3 },
  { x: "52%", y: "50%", rot: -6, z: 2 },
  { x: "78%", y: "52%", rot: 4, z: 1 },
];
// 5-column photo grid with the title in the middle (row 2, columns 2–4)
const GRID_SLOTS = [
  [1, 1], [2, 1], [3, 1], [4, 1], [5, 1],
  [1, 2], [5, 2],
  [1, 3], [2, 3], [3, 3], [4, 3], [5, 3],
];

export default async function HomePage() {
  const [settings, hero, evCopy, story, act, video, chefs, menuCopy, newsCopy, revCopy, galCopy, contact] = await Promise.all([
    getSettings(),
    getContent("home.hero"),
    getContent("home.events"),
    getContent("home.story"),
    getContent("home.activities"),
    getContent("home.video"),
    getContent("home.chefs"),
    getContent("home.menu"),
    getContent("home.news"),
    getContent("home.reviews"),
    getContent("home.gallery"),
    getContent("home.contact"),
  ]);
  const [events, menuTabs, posts, reviews, gallery] = await Promise.all([getHomeEvents(), getHomeMenu(), listPosts(3), getReviews(), getGallery({ homeOnly: true })]);

  const half = Math.ceil(reviews.length / 2);
  const rowA = [...reviews.slice(0, half), ...reviews.slice(half)];
  const rowB = [...reviews.slice(half), ...reviews.slice(0, half)];
  const marquee: { word: string }[] = act.marquee ?? [];
  const tiles = gallery.length ? GRID_SLOTS.map((slot, i) => ({ slot, img: gallery[i % gallery.length] })) : [];
  // hero background: the admin chooses "Photo" or "Video" (falls back to the photo if no video is set)
  const showHeroVideo = hero.mediaType === "video" && Boolean(hero.video);
  const menuUrl: string = menuCopy.buttonUrl || "/menu";
  const menuUrlExternal = /^https?:\/\//.test(menuUrl);

  return (
    <>
      {/* ═════ HERO ═════ */}
      <section className="hero" aria-label="Welcome">
        <Img src={hero.image} alt="" preload sizes="100vw" className="hero-media" style={{ objectPosition: "center 55%" }} />
        {showHeroVideo && <HeroVideo key={hero.video} src={hero.video} poster={hero.image} />}
        <div className="hero-shade" />
        <div className="container hero-body">
          <div className="hero-grid">
            <div>
              {hero.kicker && <p className="kicker">{hero.kicker}</p>}
              <h1 className="display display-xl">
                <MultiLine text={hero.title} />
                <span className="sr-only"> — Ammos beach bar &amp; restaurant, Makenzy Beach, Larnaca</span>
              </h1>
              <p className="hero-sub">{hero.subtitle}</p>
              <div className="btn-row">
                <a href={settings.reservationUrl} target="_blank" rel="noopener noreferrer" className="btn btn-brand">
                  {hero.primaryLabel}
                </a>
                <Link href="/events" className="btn btn-ghost-light">
                  {hero.secondaryLabel}
                </Link>
              </div>
            </div>
            <address className="hero-address" style={{ fontStyle: "normal" }}>
              <MultiLine text={hero.addressLine} />
            </address>
          </div>
        </div>
      </section>

      {/* ═════ UPCOMING EVENTS ═════ */}
      {events.length > 0 && (
        <section id="events" className="events-home" aria-labelledby="events-title">
          <div className="container">
            <HorizontalSlider
              label="events"
              header={
                <div>
                  <p className="kicker kicker-teal">{evCopy.kicker}</p>
                  <h2 id="events-title" className="display display-md">
                    {evCopy.title}
                  </h2>
                </div>
              }
            >
              {events.map((e) => (
                <EventCard key={e.id} event={e} />
              ))}
            </HorizontalSlider>
            <div className="center-row">
              <Link href="/events" className="btn btn-ink">
                {evCopy.buttonLabel}
              </Link>
            </div>
          </div>
        </section>
      )}

      {/* ═════ THE AMMOS STORY ═════ */}
      <section id="story" className="story" aria-labelledby="story-title">
        <div className="container">
          <div className="story-head" data-reveal>
            <div>
              <p className="kicker">{story.kicker}</p>
              <h2 id="story-title" className="display display-lg">
                {story.title}
              </h2>
            </div>
            <p className="lead">{story.text}</p>
          </div>
          <div className="timeline">
            {(story.timeline ?? []).slice(0, 4).map((t: Record<string, string>, i: number) => (
              <div key={i} data-reveal style={{ transitionDelay: `${i * 0.12}s` }}>
                <span className="timeline-dot" />
                <span className="timeline-year">{t.year}</span>
                <div className="timeline-img">
                  <Img src={t.image} alt={t.title} sizes="(max-width: 900px) 50vw, 25vw" />
                </div>
                <h3 className="display">{t.title}</h3>
                <p>{t.text}</p>
              </div>
            ))}
          </div>
        </div>
        {(story.fan ?? []).length > 0 && (
          <div className="fan" aria-hidden="true">
            {(story.fan as Record<string, string>[]).slice(0, 5).map((f, i) => {
              const p = FAN[i] ?? FAN[2];
              return (
                <div key={i} className="fan-item" data-reveal style={{ flex: `0 0 ${p.w}`, zIndex: p.z, transitionDelay: p.delay, ["--from" as string]: p.from }}>
                  <div className="fan-card" style={{ transform: `rotate(${p.rot}deg)` }}>
                    <Img src={f.image} alt={f.alt} sizes="(max-width: 900px) 30vw, 280px" />
                  </div>
                </div>
              );
            })}
          </div>
        )}
        <div className="center-row container">
          <Link href="/our-story" className="btn btn-outline">
            Read our story
          </Link>
        </div>
      </section>

      {/* ═════ ACTIVITIES ═════ */}
      <section className="activities" aria-labelledby="activities-title">
        <div className="container activities-grid">
          <div data-reveal>
            <p className="kicker">{act.kicker}</p>
            <h2 id="activities-title" className="display display-lg" style={{ color: "var(--brand)" }}>
              <MultiLine text={act.title} />
            </h2>
            <p className="lead" style={{ maxWidth: 480 }}>
              {act.text}
            </p>
          </div>
          <div className="polaroids">
            {(act.polaroids ?? []).slice(0, 6).map((p: Record<string, string>, i: number) => {
              const pos = POLAROID_POS[i];
              return (
                <div key={i} className="polaroid-wrap" data-reveal style={{ left: pos.x, top: pos.y, zIndex: pos.z, transitionDelay: `${i * 0.1}s` }}>
                  <div className="polaroid" style={{ transform: `rotate(${pos.rot}deg)` }}>
                    <div className="polaroid-img">
                      <Img src={p.image} alt={p.label} sizes="220px" />
                    </div>
                    <div className="polaroid-cap">
                      <span>{p.label}</span>
                      <Icon name={p.icon} size={20} />
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
        {marquee.length > 0 && (
          <div className="marquee" aria-hidden="true">
            <div className="marquee-track">
              {[...marquee, ...marquee].map((m, i) => (
                <span key={i} style={{ display: "inline-flex", alignItems: "center", gap: 56 }}>
                  <span>{m.word}</span>
                  <span className="marquee-dot" />
                </span>
              ))}
            </div>
          </div>
        )}
      </section>

      {/* ═════ DISCOVER VIDEO ═════ */}
      <DiscoverVideo poster={video.poster} video={video.video} youtubeUrl={video.youtubeUrl} label={video.label} />

      {/* ═════ CHEFS ═════ */}
      <section className="chefs" aria-labelledby="chefs-title">
        <div className="container chefs-grid">
          <div className="chefs-media">
            <div className="chefs-img1" data-reveal style={{ ["--from" as string]: "translate3d(0,80px,0)" }}>
              <div className="img-frame" style={{ aspectRatio: "4/5" }}>
                <Img src={chefs.image1} alt="Dish from the Ammos kitchen" sizes="(max-width: 900px) 70vw, 34vw" />
              </div>
            </div>
            <div className="chefs-img2" data-reveal style={{ transitionDelay: ".2s", ["--from" as string]: "translate3d(60px,0,0)" }}>
              <div className="img-frame" style={{ aspectRatio: "1", border: "4px solid var(--bg)" }}>
                <Img src={chefs.image2} alt="The Ammos kitchen" sizes="(max-width: 900px) 48vw, 24vw" />
              </div>
            </div>
          </div>
          <div data-reveal style={{ transitionDelay: ".1s" }}>
            <p className="kicker">{chefs.kicker}</p>
            <h2 id="chefs-title" className="display display-lg" style={{ marginBottom: 28 }}>
              <MultiLine text={chefs.title} />
            </h2>
            <p className="lead" style={{ marginBottom: 20 }}>
              {chefs.text}
            </p>
            {chefs.quote && <blockquote>{chefs.quote}</blockquote>}
            <div className="btn-row">
              <Link href="/our-story" className="btn btn-outline">
                {chefs.primaryLabel}
              </Link>
              <Link href="/menu" className="btn btn-muted">
                See the menu
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* ═════ MENU ═════ */}
      {menuTabs.length > 0 && (
        <section id="menu" className="section section-alt" aria-labelledby="menu-title">
          <div className="container">
            <HomeMenu
              tabs={menuTabs.map((t) => ({ ...t, items: t.items.map((i) => ({ id: i.id, name: i.name, description: i.description, price: i.price, image: i.image })) }))}
              intro={
                <>
                  <p className="kicker">{menuCopy.kicker}</p>
                  <h2 id="menu-title" className="display display-lg" style={{ marginBottom: 24 }}>
                    <MultiLine text={menuCopy.title} />
                  </h2>
                  <p className="lead" style={{ marginBottom: 32, maxWidth: 440 }}>
                    {menuCopy.text}
                  </p>
                </>
              }
              after={
                <>
                  {menuUrlExternal ? (
                    <a href={menuUrl} target="_blank" rel="noopener noreferrer" className="btn btn-outline">
                      {menuCopy.buttonLabel}
                    </a>
                  ) : (
                    <Link href={menuUrl} className="btn btn-outline">
                      {menuCopy.buttonLabel}
                    </Link>
                  )}
                  {menuCopy.hint && (
                    <p className="muted" style={{ fontSize: 12, letterSpacing: "0.08em", marginTop: 20 }}>
                      {menuCopy.hint}
                    </p>
                  )}
                </>
              }
            />
          </div>
        </section>
      )}

      {/* ═════ NEWS ═════ */}
      {posts.length > 0 && (
        <section className="section" aria-labelledby="news-title">
          <div className="container">
            <div className="section-head" data-reveal>
              <div>
                <p className="kicker">{newsCopy.kicker}</p>
                <h2 id="news-title" className="display display-lg">
                  {newsCopy.title}
                </h2>
              </div>
              <p className="lead">{newsCopy.text}</p>
            </div>
            <NewsCarousel>
              {posts.map((p, i) => (
                <article key={p.id} className="news-slide" data-reveal style={{ transitionDelay: `${i * 0.12}s` }}>
                  <div className="news-card">
                    <Img src={p.image} alt={p.title} sizes="(max-width: 900px) 100vw, 33vw" />
                    <div className="news-card-shade" />
                    <span className="news-kicker">{p.kicker}</span>
                    <h3 className="display">{p.title}</h3>
                    <p>{p.excerpt}</p>
                    <Link href={`/news/${p.slug}`} className="btn btn-ghost-light btn-sm stretched">
                      Read more ↗
                    </Link>
                  </div>
                </article>
              ))}
            </NewsCarousel>
            <div className="center-row">
              <Link href="/news" className="btn btn-outline">
                {newsCopy.buttonLabel}
              </Link>
            </div>
          </div>
        </section>
      )}

      {/* ═════ REVIEWS ═════ */}
      {reviews.length > 0 && (
        <section className="section section-alt reviews" aria-labelledby="reviews-title">
          <div className="container events-head" data-reveal style={{ marginBottom: 48 }}>
            <div>
              <p className="kicker">{revCopy.kicker}</p>
              <h2 id="reviews-title" className="display display-lg">
                {revCopy.title}
              </h2>
            </div>
            {settings.googleRating && (
              <div className="rating-line">
                <span className="stars" aria-hidden="true">
                  ★★★★★
                </span>
                {settings.googleRating} on Google · {settings.reviewCount} reviews
              </div>
            )}
          </div>
          <div className="reviews-rows">
            {[rowA, rowB].map((row, ri) => (
              <div className="reviews-row" key={ri}>
                <div className={`reviews-track${ri === 1 ? " reverse" : ""}`}>
                  {[...row, ...row].map((r, i) => (
                    <figure key={`${r.id}-${i}`} className="review" aria-hidden={i >= row.length}>
                      <span className="stars" aria-label={`${r.rating} out of 5 stars`}>
                        {"★".repeat(Math.max(1, Math.min(5, r.rating)))}
                      </span>
                      <blockquote>{r.text}</blockquote>
                      <figcaption>
                        <span className="avatar">{initials(r.name)}</span>
                        <span style={{ display: "flex", flexDirection: "column" }}>
                          <span className="review-name">{r.name}</span>
                          <span className="review-meta">{r.meta}</span>
                        </span>
                      </figcaption>
                    </figure>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* ═════ GALLERY ═════ */}
      <section className="gallery-home" aria-labelledby="gallery-title">
        <div className="container events-head" style={{ marginBottom: 40 }}>
          <div data-reveal>
            <p className="kicker">{galCopy.kicker}</p>
            <h2 id="gallery-title" className="display display-md">
              {galCopy.title}
            </h2>
          </div>
          <div className="btn-row">
            <a href={settings.instagram} target="_blank" rel="noopener noreferrer" className="btn btn-outline btn-sm">
              <Icon name="instagram" size={16} /> {galCopy.instagramLabel}
            </a>
            <Link href="/gallery" className="btn btn-muted btn-sm">
              Full gallery
            </Link>
          </div>
        </div>
        <div className="gallery-grid-home">
          {tiles.map(({ slot, img }, i) => (
            <div key={i} className="gallery-tile-wrap" data-reveal style={{ gridColumn: slot[0], gridRow: slot[1], transitionDelay: `${(i % 5) * 0.05}s` }}>
              <div className="gallery-tile">
                <Img src={img.image} alt={img.alt || "Ammos Makenzy Beach"} sizes="(max-width: 900px) 33vw, 25vw" />
              </div>
            </div>
          ))}
          <div className="gallery-center" data-reveal style={{ transitionDelay: ".35s" }}>
            <h3 className="display display-md">
              <MultiLine text={galCopy.centerTitle} />
            </h3>
            <a href={settings.reservationUrl} target="_blank" rel="noopener noreferrer" className="btn btn-brand">
              {galCopy.buttonLabel}
            </a>
          </div>
        </div>
      </section>

      {/* ═════ CONTACT ═════ */}
      <section id="contact" className="contact-band" aria-labelledby="contact-title">
        <div className="bg">
          <Img src={contact.image} alt="" sizes="100vw" />
        </div>
        <div className="shade" />
        <div className="inner" data-reveal>
          <h2 id="contact-title" className="display">
            {contact.title}
          </h2>
          <ContactForm source="home" buttonLabel={contact.buttonLabel} />
        </div>
      </section>
    </>
  );
}
AMMOS_EOF
echo "  ✔ app/(site)/page.tsx"

mkdir -p "app/(site)/menu"
cat > "app/(site)/menu/page.tsx" << 'AMMOS_EOF'
import type { Metadata } from "next";
import { getContent, getSettings } from "@/lib/content";
import { getFullMenu } from "@/lib/data";
import { pageMeta } from "@/lib/seo";
import { formatPrice, siteUrl, slugify } from "@/lib/utils";
import { PageHero } from "@/components/site/PageHero";
import { JsonLd } from "@/components/site/JsonLd";

export const revalidate = 300;

export async function generateMetadata(): Promise<Metadata> {
  const h = await getContent("page.headers");
  return pageMeta({
    title: "Menu — sushi, seafood, cocktails & more",
    description: `${h.menuText} See prices for food, cocktails, wines and spirits at Ammos Makenzy Beach, Larnaca.`,
    path: "/menu",
    image: h.menuImage,
  });
}

export default async function MenuPage() {
  const [h, settings, menu] = await Promise.all([getContent("page.headers"), getSettings(), getFullMenu()]);

  // group categories into their big sections (Food, Cocktails, Wines…) keeping the admin order
  const sections: { name: string; id: string; cats: typeof menu }[] = [];
  for (const c of menu) {
    let s = sections.find((x) => x.name === c.section);
    if (!s) {
      s = { name: c.section, id: slugify(c.section), cats: [] };
      sections.push(s);
    }
    s.cats.push(c);
  }

  const menuLd = {
    "@context": "https://schema.org",
    "@type": "Menu",
    name: "Ammos Makenzy Beach menu",
    url: siteUrl("/menu"),
    inLanguage: "en",
    hasMenuSection: sections.map((s) => ({
      "@type": "MenuSection",
      name: s.name,
      hasMenuSection: s.cats.map((c) => ({
        "@type": "MenuSection",
        name: c.name,
        hasMenuItem: c.items.map((i) => ({
          "@type": "MenuItem",
          name: i.name,
          ...(i.description ? { description: i.description.slice(0, 200) } : {}),
          offers: { "@type": "Offer", price: Number(i.price).toFixed(2), priceCurrency: "EUR" },
        })),
      })),
    })),
  };

  return (
    <>
      <PageHero kicker="Salivating yet?" title={h.menuTitle} text={h.menuText} image={h.menuImage} crumbs={[{ name: "Menu", path: "/menu" }]}>
        <div className="btn-row" style={{ marginTop: 28 }}>
          <a href={settings.reservationUrl} target="_blank" rel="noopener noreferrer" className="btn btn-brand">
            Book a table
          </a>
        </div>
      </PageHero>

      {sections.length > 1 && (
        <nav className="menu-page-nav" aria-label="Menu sections">
          <div className="row">
            {sections.map((s) => (
              <a key={s.id} href={`#${s.id}`} className="pill">
                {s.name}
              </a>
            ))}
          </div>
        </nav>
      )}

      {sections.map((s, si) => (
        <section key={s.id} id={s.id} className={`menu-section${si % 2 ? " section-alt" : ""}`} aria-labelledby={`${s.id}-title`}>
          <div className="container">
            <h2 id={`${s.id}-title`} className="display display-md">
              {s.name}
            </h2>
            {s.cats.map((c) => (
              <div key={c.id} id={`cat-${c.slug}`} className="menu-cat">
                <h3>{c.name}</h3>
                {c.description && <p className="muted" style={{ margin: "10px 0 0" }}>{c.description}</p>}
                <div className="menu-items">
                  {c.items.map((i) => {
                    const tags = i.tags.split(",").map((t) => t.trim()).filter(Boolean);
                    const allergens = i.allergens.split(",").map((t) => t.trim()).filter(Boolean);
                    return (
                      <div key={i.id} className="menu-item">
                        <h4>{i.name}</h4>
                        <span className="price">{formatPrice(i.price)}</span>
                        {i.description && <p>{i.description}</p>}
                        {(tags.length > 0 || allergens.length > 0) && (
                          <div className="menu-tags">
                            {tags.map((t) => (
                              <span key={t} className="chip green">
                                {t}
                              </span>
                            ))}
                            {allergens.map((a) => (
                              <span key={a} className="chip" title="Allergen">
                                {a}
                              </span>
                            ))}
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>
        </section>
      ))}

      <section className="container" style={{ paddingBottom: 100 }}>
        <p className="allergen-note">
          Prices are in euro and include VAT. Grey tags show allergens. If you have a food allergy or intolerance, please tell your waiter before ordering — our team will be happy to help.
        </p>
      </section>
      <JsonLd data={menuLd} />
    </>
  );
}
AMMOS_EOF
echo "  ✔ app/(site)/menu/page.tsx"

mkdir -p "app/(site)/our-story"
cat > "app/(site)/our-story/page.tsx" << 'AMMOS_EOF'
import Link from "next/link";
import type { Metadata } from "next";
import { getContent, getSettings } from "@/lib/content";
import { pageMeta } from "@/lib/seo";
import { PageHero } from "@/components/site/PageHero";
import { Img } from "@/components/site/Img";
import { RichText } from "@/components/site/RichText";

export const revalidate = 300;

export async function generateMetadata(): Promise<Metadata> {
  const p = await getContent("page.story");
  return pageMeta({
    title: "The Ammos story — first beach bar on Makenzy Beach since 2005",
    description: String(p.intro).split("\n")[0],
    path: "/our-story",
    image: p.heroImage,
  });
}

export default async function StoryPage() {
  const [p, home, settings] = await Promise.all([getContent("page.story"), getContent("home.story"), getSettings()]);
  return (
    <>
      <PageHero kicker={p.kicker} title={p.title} image={p.heroImage} crumbs={[{ name: "Our story", path: "/our-story" }]} />

      <section className="section">
        <div className="container-narrow" data-reveal>
          <RichText text={p.intro} className="prose" />
        </div>
      </section>



      <section className="section">
        <div className="container">
          {(p.chapters as Record<string, string>[]).map((c, i) => (
            <article key={i} className="chapter">
              <div className="chapter-media" data-reveal style={{ ["--from" as string]: i % 2 ? "translate3d(60px,0,0)" : "translate3d(-60px,0,0)" }}>
                <div className="img-frame" style={{ aspectRatio: "4/5" }}>
                  <Img src={c.image} alt={c.title} sizes="(max-width: 900px) 100vw, 45vw" />
                </div>
              </div>
              <div data-reveal style={{ transitionDelay: ".12s" }}>
                {c.kicker && <p className="kicker">{c.kicker}</p>}
                <h2 className="display display-md" style={{ marginBottom: 24 }}>
                  {c.title}
                </h2>
                <RichText text={c.text} />
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="section section-alt">
        <div className="container">
          <div className="story-head" data-reveal>
            <div>
              <p className="kicker">{home.kicker}</p>
              <h2 className="display display-lg">{home.title}</h2>
            </div>
            <p className="lead">{home.text}</p>
          </div>
          <div className="timeline">
            {(home.timeline as Record<string, string>[]).map((t, i) => (
              <div key={i} data-reveal style={{ transitionDelay: `${i * 0.12}s` }}>
                <span className="timeline-dot" style={{ boxShadow: "0 0 0 5px var(--bg2)" }} />
                <span className="timeline-year">{t.year}</span>
                <div className="timeline-img">
                  <Img src={t.image} alt={t.title} sizes="(max-width: 900px) 50vw, 25vw" />
                </div>
                <h3 className="display">{t.title}</h3>
                <p>{t.text}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {p.quote && (
        <section className="section">
          <div className="container" data-reveal>
            <p className="big-quote">{p.quote}</p>
            <div className="center-row">
              <a href={settings.reservationUrl} target="_blank" rel="noopener noreferrer" className="btn btn-brand">
                Book a table
              </a>
              <span style={{ width: 14 }} />
              <Link href="/menu" className="btn btn-outline">
                See the menu
              </Link>
            </div>
          </div>
        </section>
      )}
    </>
  );
}
AMMOS_EOF
echo "  ✔ app/(site)/our-story/page.tsx"

mkdir -p "app"
cat > "app/globals.css" << 'AMMOS_EOF'
/* ════════════════════════════════════════════════════════════════
   AMMOS MAKENZY BEACH — website styles
   Brand: cyan #3ec6d8 · lime #b7d44a · midnight #0f1119
   Titles: Marcellus (uppercase) · Body: Jost
   ════════════════════════════════════════════════════════════════ */

:root {
  --brand: #3ec6d8;
  --brand-hover: #7fdce8;
  --lime: #b7d44a;
  --ink: #0f1119;
  --teal: #157f8f;
  --bg: #0f1119;
  --bg2: #141726;
  --surface: #1c1f2c;
  --text: #e9e9ed;
  --muted: #cfd3e5;
  --muted2: #9397ab;
  --border: #3f424d;
  --border2: #292b31;
  --title: #b8cdd1;
  --ghost: #292b31;
  --overlay: rgba(15, 17, 25, 0.82);
  --paper: #f3f5fe;
  --img-shadow: 0 30px 60px rgba(0, 0, 0, 0.45);
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 14px;
  --ease: cubic-bezier(0.22, 0.61, 0.36, 1);
  --ease-out: cubic-bezier(0.2, 0.7, 0.2, 1);
  --display: var(--font-marcellus), "Marcellus", Georgia, serif;
  --body: var(--font-jost), "Jost", system-ui, sans-serif;
  --gutter: 32px;
  color-scheme: dark;
}

*,
*::before,
*::after { box-sizing: border-box; }

html { -webkit-text-size-adjust: 100%; }
html.lenis, html.lenis body { height: auto; }
.lenis.lenis-smooth { scroll-behavior: auto !important; }
.lenis.lenis-stopped { overflow: hidden; }

body {
  margin: 0;
  background: var(--bg);
  color: var(--text);
  font-family: var(--body);
  font-weight: 400;
  font-size: 15px;
  line-height: 1.55;
  overflow-x: hidden;
  -webkit-font-smoothing: antialiased;
}

a { color: var(--brand); text-decoration: none; transition: color 0.25s; }
a:hover { color: var(--brand-hover); }
img, video { display: block; max-width: 100%; }
h1, h2, h3, h4, p, figure, blockquote { margin: 0; }
button { font: inherit; }
:focus { outline: none; }
:focus-visible { outline: 2px solid var(--brand); outline-offset: 3px; }
::selection { background: rgba(62, 198, 216, 0.3); }

.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
.skip-link { position: absolute; left: 16px; top: -60px; z-index: 200; background: var(--brand); color: var(--ink); padding: 10px 16px; border-radius: 999px; font-weight: 600; }
.skip-link:focus { top: 16px; color: var(--ink); }

/* ── layout ── */
.container { max-width: 1360px; margin: 0 auto; padding: 0 var(--gutter); width: 100%; }
.container-narrow { max-width: 900px; margin: 0 auto; padding: 0 var(--gutter); }
.section { padding: 110px 0; }
.section-alt { background: var(--bg2); border-top: 1px solid var(--border2); }
.section-white { background: #fff; color: var(--ink); }

/* ── type ── */
.display {
  font-family: var(--display);
  font-weight: 400;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  line-height: 1.08;
  text-wrap: balance;
}
.display-xl { font-size: clamp(40px, 6.4vw, 88px); }
.display-lg { font-size: clamp(38px, 5.4vw, 72px); color: var(--title); }
.display-md { font-size: clamp(34px, 4.6vw, 60px); color: var(--title); }
.display-sm { font-size: clamp(26px, 2.6vw, 36px); }
.title-brand { color: var(--brand); }
.kicker { margin: 0 0 14px; font-size: 12px; letter-spacing: 0.28em; text-transform: uppercase; color: var(--lime); font-weight: 500; }
.kicker-teal { color: var(--teal); }
.lead { font-size: 17px; line-height: 1.65; color: var(--muted); font-weight: 300; text-wrap: pretty; }
.muted { color: var(--muted2); }
.eyebrow { font-size: 11px; letter-spacing: 0.22em; text-transform: uppercase; font-weight: 500; }

.section-head { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 32px 48px; align-items: end; margin-bottom: 48px; }
.section-head > p { justify-self: end; max-width: 500px; }

/* ── buttons ── */
.btn {
  display: inline-flex; align-items: center; justify-content: center; gap: 8px;
  padding: 15px 30px; border-radius: 999px; border: 1px solid transparent;
  font-family: var(--body); font-size: 13px; font-weight: 500; letter-spacing: 0.16em; text-transform: uppercase;
  line-height: 1.2; cursor: pointer; text-decoration: none; white-space: nowrap;
  transition: background 0.25s, color 0.25s, border-color 0.25s, transform 0.25s;
}
.btn:disabled { opacity: 0.55; cursor: not-allowed; }
.btn-brand { background: var(--brand); border-color: var(--brand); color: var(--ink); }
.btn-brand:hover { background: var(--brand-hover); border-color: var(--brand-hover); color: var(--ink); }
.btn-outline { border-color: var(--brand); color: var(--brand); background: transparent; }
.btn-outline:hover { background: rgba(62, 198, 216, 0.12); color: var(--brand); }
.btn-ghost-light { border-color: rgba(233, 233, 237, 0.6); color: #e9e9ed; background: transparent; }
.btn-ghost-light:hover { background: #e9e9ed; color: var(--ink); }
.btn-muted { border-color: var(--border); color: var(--text); }
.btn-muted:hover { border-color: var(--brand); color: var(--brand); }
.btn-ink { border-color: var(--ink); color: var(--ink); }
.btn-ink:hover { background: var(--ink); color: #fff; }
.btn-sm { padding: 11px 20px; font-size: 12px; }
.btn-row { display: flex; flex-wrap: wrap; gap: 14px; }

.round-btn {
  width: 46px; height: 46px; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center;
  border: 1px solid currentColor; background: transparent; color: inherit; cursor: pointer; font-size: 18px; transition: all 0.25s;
}
.round-btn.on-white { color: var(--ink); border-color: var(--ink); }
.round-btn.on-white:hover { background: var(--ink); color: var(--brand); }
.round-btn.on-dark { color: var(--brand); border-color: var(--brand); }
.round-btn.on-dark:hover { background: var(--brand); color: var(--ink); }

.link-underline { font-size: 12px; letter-spacing: 0.2em; text-transform: uppercase; color: var(--ink); font-weight: 500; padding-bottom: 5px; border-bottom: 1px solid currentColor; transition: all 0.3s; }
.link-underline:hover { color: var(--teal); }

/* ── reveal on scroll ── */
[data-reveal] {
  opacity: 0;
  transform: var(--from, translate3d(0, 64px, 0));
  transition: opacity 1s var(--ease), transform 1s var(--ease);
}
[data-reveal].is-in { opacity: 1; transform: none; }
@media (prefers-reduced-motion: reduce) {
  [data-reveal] { opacity: 1; transform: none; transition: none; }
  .marquee-track, .reviews-track { animation: none !important; }
}
.no-js [data-reveal] { opacity: 1; transform: none; }

@keyframes marquee { from { transform: translateX(0); } to { transform: translateX(-50%); } }
@keyframes pulse { 0%, 100% { box-shadow: 0 0 0 0 rgba(62, 198, 216, 0.55); } 70% { box-shadow: 0 0 0 22px rgba(62, 198, 216, 0); } }
@keyframes fadeUp { from { opacity: 0; transform: translateY(24px); } to { opacity: 1; transform: none; } }

.progress-bar { position: fixed; left: 0; top: 0; height: 2px; width: 0; background: var(--brand); z-index: 90; pointer-events: none; }

/* ════════════ HEADER ════════════ */
.site-header {
  position: absolute; left: 0; right: 0; top: 0; z-index: 30;
  display: grid; grid-template-columns: 1fr auto 1fr; align-items: center;
  padding: 20px var(--gutter); max-width: 1360px; margin: 0 auto; color: #e9e9ed;
}
.site-header nav { display: flex; gap: 28px; font-size: 13px; letter-spacing: 0.16em; text-transform: uppercase; font-weight: 500; }
.site-header nav a, .header-right a { color: #e9e9ed; }
.site-header nav a:hover, .header-right a:hover, .site-header nav a[aria-current="page"] { color: var(--brand); }
.header-logo img { height: 62px; width: auto; }
.header-right { display: flex; justify-content: flex-end; align-items: center; gap: 16px; font-size: 13px; letter-spacing: 0.16em; text-transform: uppercase; font-weight: 500; }
.burger {
  width: 44px; height: 44px; border: 0; background: var(--brand); display: flex; flex-direction: column;
  align-items: center; justify-content: center; gap: 5px; cursor: pointer; border-radius: var(--radius-sm); transition: background 0.25s;
}
.burger:hover { background: var(--brand-hover); }
.burger span { width: 20px; height: 2px; background: var(--ink); display: block; }

.sticky-header {
  position: fixed; left: 0; right: 0; top: 0; z-index: 65;
  transform: translateY(-110%); transition: transform 0.5s var(--ease);
  background: rgba(255, 255, 255, 0.92); color: var(--ink);
  border-bottom: 1px solid rgba(15, 17, 25, 0.1);
  backdrop-filter: blur(14px); -webkit-backdrop-filter: blur(14px);
  box-shadow: 0 10px 30px rgba(15, 17, 25, 0.12);
}
.sticky-header.is-visible { transform: translateY(0); }
.sticky-inner { display: grid; grid-template-columns: 1fr auto 1fr; align-items: center; padding: 12px var(--gutter); max-width: 1360px; margin: 0 auto; }
.sticky-inner nav { display: flex; gap: 26px; font-size: 12px; letter-spacing: 0.16em; text-transform: uppercase; font-weight: 500; }
.sticky-inner nav a { color: var(--ink); }
.sticky-inner nav a:hover { color: var(--teal); }
.sticky-inner .logo-img { height: 42px; width: auto; }
.sticky-right { display: flex; justify-content: flex-end; align-items: center; gap: 14px; }
.sticky-burger {
  width: 40px; height: 40px; border: 1px solid rgba(15, 17, 25, 0.15); background: transparent; color: var(--ink);
  display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px; cursor: pointer; border-radius: var(--radius-sm);
}
.sticky-burger span { width: 18px; height: 2px; background: currentColor; display: block; }
.btn-reserve { padding: 10px 20px; border-radius: 999px; background: var(--brand); color: var(--ink); font-size: 12px; font-weight: 600; letter-spacing: 0.14em; text-transform: uppercase; }
.btn-reserve:hover { background: var(--brand-hover); color: var(--ink); }

/* full-screen menu */
.menu-overlay {
  position: fixed; inset: 0; z-index: 100; background: var(--ink); color: var(--text);
  display: grid; grid-template-rows: auto 1fr auto; overflow-y: auto;
  opacity: 0; visibility: hidden; transition: opacity 0.45s var(--ease), visibility 0.45s;
}
.menu-overlay.is-open { opacity: 1; visibility: visible; }
.menu-overlay::before {
  content: ""; position: absolute; inset: 0; pointer-events: none;
  background: radial-gradient(60% 50% at 85% 10%, rgba(62, 198, 216, 0.14), transparent 70%), radial-gradient(40% 40% at 10% 90%, rgba(183, 212, 74, 0.08), transparent 70%);
}
.menu-top { position: relative; display: flex; justify-content: space-between; align-items: center; padding: 20px var(--gutter); max-width: 1360px; width: 100%; margin: 0 auto; }
.menu-top img { height: 52px; width: auto; }
.menu-close { width: 48px; height: 48px; border-radius: 50%; border: 1px solid rgba(233, 233, 237, 0.4); background: transparent; color: var(--text); font-size: 26px; cursor: pointer; transition: all 0.25s; }
.menu-close:hover { background: var(--brand); color: var(--ink); border-color: var(--brand); }
.menu-body { position: relative; display: grid; grid-template-columns: minmax(0, 1.4fr) minmax(0, 1fr); gap: 48px; padding: 24px var(--gutter) 48px; max-width: 1360px; width: 100%; margin: 0 auto; align-items: center; }
.menu-links { list-style: none; margin: 0; padding: 0; display: grid; gap: 4px; counter-reset: m; }
.menu-links li { overflow: hidden; }
.menu-links a {
  display: flex; align-items: baseline; gap: 18px; color: var(--text);
  font-family: var(--display); text-transform: uppercase; letter-spacing: 0.06em; font-size: clamp(28px, 4.2vw, 56px); line-height: 1.12;
  transform: translateY(100%); transition: transform 0.7s var(--ease-out), color 0.25s;
}
.menu-overlay.is-open .menu-links a { transform: none; }
.menu-links a::before { counter-increment: m; content: counter(m, decimal-leading-zero); font-family: var(--body); font-size: 12px; letter-spacing: 0.2em; color: var(--lime); }
.menu-links a:hover, .menu-links a[aria-current="page"] { color: var(--brand); }
.menu-aside { display: grid; gap: 28px; align-content: start; font-size: 15px; color: var(--muted); }
.menu-aside h3 { font-size: 11px; letter-spacing: 0.22em; text-transform: uppercase; color: var(--lime); font-weight: 500; margin-bottom: 10px; font-family: var(--body); }
.menu-aside a { color: var(--text); }
.menu-aside a:hover { color: var(--brand); }
.menu-bottom { position: relative; border-top: 1px solid var(--border2); padding: 18px var(--gutter); display: flex; justify-content: space-between; gap: 16px; flex-wrap: wrap; max-width: 1360px; width: 100%; margin: 0 auto; font-size: 13px; color: var(--muted2); }

.socials { display: flex; gap: 10px; flex-wrap: wrap; }
.social-btn {
  width: 44px; height: 44px; border-radius: 50%; border: 1px solid currentColor; display: flex; align-items: center; justify-content: center; font-size: 20px; transition: all 0.25s;
}
.socials.on-dark .social-btn { color: var(--text); border-color: var(--border); }
.socials.on-dark .social-btn:hover { background: var(--brand); color: var(--ink); border-color: var(--brand); }
.socials.on-brand .social-btn { color: var(--ink); border-color: var(--ink); }
.socials.on-brand .social-btn:hover { background: var(--ink); color: var(--brand); }

/* ════════════ HERO (home) ════════════ */
.hero { position: relative; min-height: 92vh; min-height: 92svh; display: flex; flex-direction: column; overflow: hidden; color: #e9e9ed; background: var(--ink); }
.hero-media { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; object-position: center 55%; }
.hero-shade { position: absolute; inset: 0; background: linear-gradient(180deg, rgba(15,17,25,0.72) 0%, rgba(15,17,25,0.28) 35%, rgba(15,17,25,0.55) 75%, rgba(15,17,25,0.85) 100%); }
.hero-body { position: relative; z-index: 2; flex: 1; display: flex; align-items: flex-end; padding-top: 140px; padding-bottom: 72px; }
.hero-grid { display: grid; grid-template-columns: minmax(0, 1.3fr) minmax(0, 1fr); gap: 48px; width: 100%; align-items: end; }
.hero h1 { animation: fadeUp 1.1s var(--ease) both; }
.hero-sub { margin: 22px 0 0; max-width: 520px; font-size: 18px; line-height: 1.5; color: var(--muted); font-weight: 300; animation: fadeUp 1.1s 0.15s var(--ease) both; }
.hero .btn-row { margin-top: 32px; animation: fadeUp 1.1s 0.3s var(--ease) both; }
.hero-address { justify-self: end; text-align: right; font-size: 12px; letter-spacing: 0.22em; text-transform: uppercase; line-height: 1.9; color: var(--muted); }

/* page hero (inner pages) */
.page-hero { position: relative; min-height: 62vh; min-height: 62svh; display: flex; align-items: flex-end; overflow: hidden; color: #e9e9ed; background: var(--ink); }
.page-hero.compact { min-height: 46vh; min-height: 46svh; }
.page-hero .hero-shade { background: linear-gradient(180deg, rgba(15,17,25,0.78) 0%, rgba(15,17,25,0.35) 40%, rgba(15,17,25,0.92) 100%); }
.page-hero-body { position: relative; z-index: 2; width: 100%; padding-top: 150px; padding-bottom: 64px; }
.page-hero h1 { animation: fadeUp 1s var(--ease) both; }
.page-hero .lead { max-width: 620px; margin-top: 20px; animation: fadeUp 1s 0.12s var(--ease) both; }
.breadcrumbs { display: flex; flex-wrap: wrap; gap: 8px; list-style: none; margin: 0 0 18px; padding: 0; font-size: 11px; letter-spacing: 0.22em; text-transform: uppercase; color: var(--muted2); }
.breadcrumbs a { color: var(--muted); }
.breadcrumbs a:hover { color: var(--brand); }
.breadcrumbs li + li::before { content: "/"; margin-right: 8px; opacity: 0.5; }

/* ════════════ EVENTS (home slider, white) ════════════ */
.events-home { background: #fff; color: var(--ink); padding: 96px 0 104px; }
.events-head { display: flex; flex-wrap: wrap; align-items: flex-end; justify-content: space-between; gap: 20px; margin-bottom: 40px; }
.events-home .events-head h2 { color: var(--ink); }
.events-nav { display: flex; gap: 14px; }
.events-track {
  display: grid; grid-auto-flow: column; grid-auto-columns: minmax(280px, 340px); gap: 40px;
  overflow-x: auto; scroll-snap-type: x mandatory; scrollbar-width: none; padding: 4px 0 12px;
}
.events-track::-webkit-scrollbar { display: none; }
.event-card { scroll-snap-align: start; display: flex; flex-direction: column; color: var(--ink); }
.event-card-media { aspect-ratio: 4 / 5; overflow: hidden; position: relative; background: #eef1f3; display: block; }
.event-card-media img { transition: transform 1s var(--ease-out); }
.event-card:hover .event-card-media img { transform: scale(1.04); }
.event-card-meta { display: flex; justify-content: space-between; align-items: baseline; gap: 12px; margin-top: 22px; padding-bottom: 14px; border-bottom: 1px solid #d8dfe2; font-size: 11px; letter-spacing: 0.24em; text-transform: uppercase; color: #6f8289; }
.event-card-meta .tag { color: var(--teal); }
.event-card h3 { margin: 18px 0 8px; font-size: clamp(22px, 2vw, 28px); line-height: 1.15; color: var(--ink); }
.event-card h3 a { color: inherit; }
.event-card h3 a:hover { color: var(--teal); }
.event-card .where { font-size: 14px; color: #6f8289; }
.event-card .link-underline { margin-top: 22px; align-self: flex-start; }
.event-badge { position: absolute; left: 14px; top: 14px; display: flex; flex-direction: column; align-items: center; background: var(--paper); color: var(--ink); border-radius: 10px; padding: 8px 12px; line-height: 1; z-index: 1; }
.event-badge b { font-family: var(--display); font-weight: 400; font-size: 24px; }
.event-badge span { font-size: 10px; letter-spacing: 0.2em; text-transform: uppercase; margin-top: 4px; font-weight: 600; }
.past-flag { position: absolute; right: 14px; top: 14px; z-index: 1; background: var(--ink); color: var(--muted); padding: 6px 10px; font-size: 10px; letter-spacing: 0.2em; text-transform: uppercase; border-radius: 999px; }
.center-row { display: flex; justify-content: center; margin-top: 48px; }

/* ════════════ STORY TIMELINE ════════════ */
.story { padding: 120px 0 110px; background: var(--bg); overflow: hidden; }
.story-head { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 48px; align-items: end; margin-bottom: 64px; }
.story-head .lead { justify-self: end; max-width: 520px; }
.timeline { position: relative; display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 28px; }
.timeline::before { content: ""; position: absolute; left: 0; right: 0; top: 7px; height: 1px; background: linear-gradient(90deg, transparent, var(--border) 10%, var(--border) 90%, transparent); }
.timeline-dot { display: block; width: 15px; height: 15px; border-radius: 50%; background: var(--brand); box-shadow: 0 0 0 5px var(--bg); margin-bottom: 22px; position: relative; }
.timeline-year { display: block; font-family: var(--display); font-size: clamp(34px, 3.6vw, 52px); line-height: 1.08; color: var(--brand); margin-bottom: 14px; }
.timeline-img { aspect-ratio: 4 / 3; border-radius: var(--radius-md); overflow: hidden; margin-bottom: 16px; position: relative; }
.timeline h3 { font-size: 18px; margin-bottom: 8px; color: var(--text); }
.timeline p { font-size: 15px; line-height: 1.55; color: var(--muted); font-weight: 300; }
.fan { position: relative; display: flex; justify-content: center; align-items: center; margin-top: 110px; padding: 0 var(--gutter); }
.fan-item { margin: 0 -2.2%; }
.fan-card { aspect-ratio: 3 / 4; border-radius: 8px; overflow: hidden; border: 4px solid var(--brand); box-shadow: var(--img-shadow); background: var(--surface); transition: transform 0.4s; position: relative; }
.fan-card:hover { transform: rotate(0deg) scale(1.03) !important; }

/* ════════════ ACTIVITIES ════════════ */
.activities { background: var(--bg2); padding: 110px 0 0; overflow: hidden; border-top: 1px solid var(--border2); }
.activities-grid { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1.2fr); gap: 48px; align-items: center; }
.activities h2 { color: var(--brand); margin-bottom: 28px; }
.polaroids { position: relative; height: clamp(440px, 46vw, 620px); }
.polaroid-wrap { position: absolute; width: clamp(140px, 16vw, 220px); }
.polaroid { background: var(--paper); padding: 10px 10px 14px; border-radius: 4px; box-shadow: var(--img-shadow); transition: transform 0.35s var(--ease-out); }
.polaroid:hover { transform: rotate(0deg) scale(1.05) !important; }
.polaroid-img { aspect-ratio: 1; overflow: hidden; background: var(--ink); position: relative; }
.polaroid-cap { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-top: 12px; color: var(--ink); }
.polaroid-cap span { font-family: var(--display); text-transform: uppercase; letter-spacing: 0.06em; font-size: clamp(13px, 1.3vw, 17px); line-height: 1.1; }
.polaroid-cap svg { color: var(--teal); flex: none; }
.marquee { margin-top: 90px; border-top: 1px solid var(--border); border-bottom: 1px solid var(--border); padding: 26px 0; overflow: hidden; white-space: nowrap; }
.marquee-track { display: inline-flex; align-items: center; gap: 56px; animation: marquee 40s linear infinite; font-family: var(--display); text-transform: uppercase; font-size: clamp(22px, 2.6vw, 38px); letter-spacing: 0.18em; line-height: 1; color: var(--title); }
.marquee-dot { width: 6px; height: 6px; border-radius: 50%; background: var(--brand); display: inline-block; }

/* ════════════ DISCOVER VIDEO ════════════ */
.discover { position: relative; height: clamp(420px, 56vw, 720px); overflow: hidden; background: var(--ink); }
.discover-bg { position: absolute; inset: -4%; width: 108%; height: 108%; object-fit: cover; filter: blur(14px) saturate(1.1); transform: scale(1.05); }
.discover-shade { position: absolute; inset: 0; background: rgba(15, 17, 25, 0.45); }
.discover-center { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 26px; }
.discover-center img { height: 54px; width: auto; }
.play-btn { width: 96px; height: 96px; border-radius: 50%; border: 0; background: var(--brand); display: flex; align-items: center; justify-content: center; cursor: pointer; animation: pulse 2.4s ease-out infinite; transition: transform 0.3s; }
.play-btn:hover { transform: scale(1.08); }
.play-btn span { display: block; width: 0; height: 0; border-left: 26px solid var(--ink); border-top: 16px solid transparent; border-bottom: 16px solid transparent; margin-left: 6px; }
.discover-label { font-size: 13px; letter-spacing: 0.3em; text-transform: uppercase; color: #e9e9ed; font-weight: 500; }
.discover video, .discover iframe { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; background: var(--ink); border: 0; }
.video-close { position: absolute; right: 24px; top: 24px; width: 44px; height: 44px; border-radius: 50%; border: 1px solid rgba(233, 233, 237, 0.5); background: rgba(15, 17, 25, 0.6); color: #e9e9ed; cursor: pointer; font-size: 20px; z-index: 2; }

/* ════════════ CHEFS ════════════ */
.chefs { background: var(--bg); padding: 120px 0; overflow: hidden; }
.chefs-grid { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 72px; align-items: center; }
.chefs-media { position: relative; min-height: 520px; }
.chefs-img1 { position: absolute; left: 0; top: 0; width: 72%; }
.chefs-img2 { position: absolute; right: 0; bottom: 0; width: 48%; }
.img-frame { border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--img-shadow); position: relative; }
.chefs-badge-wrap { position: absolute; left: 58%; top: 6%; }
.chefs-badge { width: 112px; height: 112px; border-radius: 50%; background: var(--lime); color: var(--ink); display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; font-size: 10px; letter-spacing: 0.18em; text-transform: uppercase; font-weight: 600; line-height: 1.4; transform: rotate(-10deg); box-shadow: var(--img-shadow); }
.chefs-badge b { font-family: var(--display); font-weight: 400; font-size: 28px; letter-spacing: 0; line-height: 1; }
.chefs blockquote { margin: 0 0 32px; padding-left: 20px; border-left: 2px solid var(--brand); font-family: var(--display); text-transform: uppercase; letter-spacing: 0.04em; font-size: 20px; line-height: 1.4; color: var(--text); }

/* ════════════ HOME MENU ════════════ */
.menu-home-grid { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1.3fr); gap: 64px; align-items: start; }
.menu-home-intro { position: sticky; top: 90px; }
.pill-tabs { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 32px; }
.pill { padding: 9px 16px; border-radius: 999px; border: 1px solid var(--border); background: transparent; color: var(--muted); font-size: 12px; font-weight: 500; letter-spacing: 0.14em; text-transform: uppercase; cursor: pointer; transition: all 0.25s; white-space: nowrap; }
.pill:hover { border-color: var(--brand); color: var(--brand); }
.pill.is-active { background: var(--brand); border-color: var(--brand); color: var(--ink); }
.dish { display: grid; grid-template-columns: 1fr auto; gap: 24px; padding: 24px 12px; border-bottom: 1px solid var(--border); align-items: baseline; cursor: default; transition: background 0.25s, padding 0.25s; border-radius: var(--radius-sm); }
.dish:hover { background: var(--surface); padding-left: 20px; }
.dish h3 { font-family: var(--display); text-transform: uppercase; letter-spacing: 0.06em; font-size: 20px; margin: 0 0 6px; color: var(--text); font-weight: 400; }
.dish p { font-size: 15px; line-height: 1.5; color: var(--muted2); font-weight: 300; }
.dish-price { font-size: 18px; color: var(--brand); white-space: nowrap; font-weight: 500; }
.hover-image {
  position: fixed; left: 0; top: 0; width: 250px; aspect-ratio: 4 / 5; border-radius: var(--radius-lg); overflow: hidden; pointer-events: none;
  opacity: 0; transform: translate(-50%, -56%) rotate(-7deg) scale(0.88); transition: opacity 0.22s ease, transform 0.35s var(--ease-out);
  z-index: 60; border: 2px solid var(--brand); box-shadow: 0 24px 60px rgba(0, 0, 0, 0.45); background: var(--ink);
}
.hover-image.is-on { opacity: 1; transform: translate(-50%, -56%) rotate(-4deg) scale(1); }
.hover-image img { width: 100%; height: 100%; object-fit: cover; }

/* ════════════ NEWS ════════════ */
.news-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 300px), 1fr)); gap: 28px; }
.news-grid > :only-child { max-width: 440px; }
.news-card { position: relative; aspect-ratio: 3 / 4; border-radius: var(--radius-md); overflow: hidden; background: var(--surface); display: flex; flex-direction: column; justify-content: flex-end; padding: 28px; color: #e9e9ed; }
.news-card > img { transition: transform 0.7s var(--ease-out); }
.news-card:hover > img { transform: scale(1.05); }
.news-card-shade { position: absolute; inset: 0; background: linear-gradient(180deg, rgba(15,17,25,0.1) 30%, rgba(15,17,25,0.88) 100%); }
.news-kicker { position: absolute; left: 20px; top: 20px; padding: 9px 14px; background: var(--ink); color: #e9e9ed; font-size: 11px; letter-spacing: 0.22em; text-transform: uppercase; font-weight: 500; z-index: 1; }
.news-card h3 { position: relative; margin: 0 0 10px; font-size: clamp(24px, 2.4vw, 34px); line-height: 1.1; }
.news-card p { position: relative; margin: 0 0 20px; font-size: 15px; line-height: 1.5; color: var(--muted); }
.news-card .btn { position: relative; align-self: flex-start; }
.news-card .stretched::after { content: ""; position: absolute; inset: 0; z-index: 1; }

/* ════════════ REVIEWS ════════════ */
.reviews { overflow: hidden; }
.reviews-rows { display: flex; flex-direction: column; gap: 24px; -webkit-mask-image: linear-gradient(90deg, transparent, #000 8%, #000 92%, transparent); mask-image: linear-gradient(90deg, transparent, #000 8%, #000 92%, transparent); }
.reviews-row { overflow: hidden; }
.reviews-track { display: flex; gap: 24px; width: max-content; animation: marquee 55s linear infinite; }
.reviews-track.reverse { animation-duration: 62s; animation-direction: reverse; }
.reviews-track:hover { animation-play-state: paused; }
.review { width: 380px; padding: 28px; background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-md); display: flex; flex-direction: column; gap: 16px; }
.stars { color: var(--lime); letter-spacing: 2px; font-size: 14px; }
.review blockquote { font-size: 16px; line-height: 1.6; color: var(--text); font-weight: 300; text-wrap: pretty; }
.review figcaption { margin-top: auto; display: flex; align-items: center; gap: 12px; }
.avatar { width: 38px; height: 38px; border-radius: 50%; background: var(--brand); color: var(--ink); display: flex; align-items: center; justify-content: center; font-size: 14px; font-weight: 600; flex: none; }
.review-name { font-size: 14px; font-weight: 500; }
.review-meta { font-size: 12px; color: var(--muted2); }
.rating-line { display: flex; align-items: center; gap: 12px; font-size: 15px; color: var(--muted); }

/* ════════════ GALLERY GRID (home) ════════════ */
.gallery-home { background: var(--bg); padding: 110px 0 120px; overflow: hidden; }
.gallery-grid-home { position: relative; width: 124%; margin-left: -12%; display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); grid-auto-rows: clamp(140px, 17vw, 300px); gap: clamp(12px, 1.6vw, 28px); margin-top: 20px; }
.gallery-tile { border-radius: var(--radius-lg); overflow: hidden; position: relative; width: 100%; height: 100%; }
.gallery-tile img { transition: transform 0.7s var(--ease-out); }
.gallery-tile:hover img { transform: scale(1.06); }
.gallery-center { grid-column: 2 / 5; grid-row: 2; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; gap: 28px; padding: 0 24px; }

/* ════════════ CONTACT BLOCK ════════════ */
.contact-band { position: relative; padding: 100px 0; overflow: hidden; }
.contact-band .bg { position: absolute; inset: 0; }
.contact-band .shade { position: absolute; inset: 0; background: var(--overlay); }
.contact-band .inner { position: relative; max-width: 1000px; margin: 0 auto; padding: 0 var(--gutter); color: #e9e9ed; }
.contact-band h2 { text-align: center; margin-bottom: 40px; font-size: clamp(28px, 3.6vw, 44px); color: var(--brand); }

/* ── forms ── */
.form-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 20px 28px; }
.form-grid .full { grid-column: 1 / -1; }
.field { display: flex; flex-direction: column; gap: 8px; font-size: 12px; letter-spacing: 0.16em; text-transform: uppercase; font-weight: 500; color: #e9e9ed; }
.field .opt { color: var(--muted2); letter-spacing: 0.08em; text-transform: none; font-weight: 400; margin-left: 4px; }
.field-label { display: block; }
.input {
  width: 100%; padding: 14px; border-radius: var(--radius-md); border: 1px solid rgba(233, 233, 237, 0.25);
  background: rgba(15, 17, 25, 0.55); color: #e9e9ed; font-size: 15px; font-family: var(--body); letter-spacing: 0; text-transform: none; font-weight: 400;
  transition: border-color 0.2s, background 0.2s;
}
.input:hover { border-color: rgba(233, 233, 237, 0.5); }
.input:focus { border-color: var(--brand); outline: none; background: rgba(15, 17, 25, 0.75); }
.input::placeholder { color: var(--muted2); }
textarea.input { resize: vertical; min-height: 130px; }
select.input { appearance: none; background-image: linear-gradient(45deg, transparent 50%, var(--brand) 50%), linear-gradient(135deg, var(--brand) 50%, transparent 50%); background-position: calc(100% - 20px) 50%, calc(100% - 14px) 50%; background-size: 6px 6px; background-repeat: no-repeat; padding-right: 40px; }
input[type="date"].input, input[type="time"].input { color-scheme: dark; }
.check { display: flex; gap: 12px; align-items: flex-start; font-size: 14px; letter-spacing: 0; text-transform: none; font-weight: 300; color: var(--muted); cursor: pointer; }
.check input { margin-top: 3px; width: 18px; height: 18px; accent-color: var(--brand); flex: none; }
.hp { position: absolute; left: -9999px; width: 1px; height: 1px; overflow: hidden; }
.form-note { font-size: 13px; color: var(--muted2); }
.form-alert { padding: 16px 18px; border-radius: var(--radius-md); font-size: 15px; line-height: 1.5; }
.form-alert.ok { background: rgba(183, 212, 74, 0.14); border: 1px solid rgba(183, 212, 74, 0.5); color: #e5f2b8; }
.form-alert.err { background: rgba(240, 98, 98, 0.12); border: 1px solid rgba(240, 98, 98, 0.45); color: #ffc9c9; }
.form-card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg); padding: clamp(24px, 4vw, 44px); }

/* ════════════ FOOTER ════════════ */
.footer-main { background: var(--brand); color: var(--ink); }
.footer-grid { padding-top: 80px; padding-bottom: 72px; display: grid; grid-template-columns: 1.1fr repeat(3, minmax(0, 1fr)) 1.3fr; gap: 40px; align-items: start; }
.footer-grid img { height: 60px; width: auto; opacity: 0.9; }
.footer-grid nav { display: flex; flex-direction: column; gap: 12px; font-size: 15px; }
.footer-grid a { color: var(--ink); }
.footer-grid a:hover { color: var(--ink); text-decoration: underline; text-underline-offset: 4px; }
.footer-contact { display: flex; flex-direction: column; gap: 12px; font-size: 15px; }
.footer-contact small { font-size: 13px; color: rgba(15, 17, 25, 0.65); }
.footer-bar { background: var(--lime); color: var(--ink); text-align: center; padding: 18px var(--gutter); font-size: 13px; letter-spacing: 0.04em; }
.footer-bar a { color: var(--ink); }
.footer-bar a:hover { text-decoration: underline; }
.footer-tagline { margin-top: 18px; font-size: 14px; max-width: 220px; color: rgba(15, 17, 25, 0.75); }

/* ════════════ INNER PAGES ════════════ */
.filter-bar { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 16px 24px; margin-bottom: 44px; }
.filter-bar .group { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }
.events-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 280px), 1fr)); gap: 48px 32px; }
.events-page { background: #fff; color: var(--ink); }
.events-page .pill { border-color: #d8dfe2; color: #45585f; }
.events-page .pill:hover { border-color: var(--teal); color: var(--teal); }
.events-page .pill.is-active { background: var(--ink); border-color: var(--ink); color: var(--brand); }
.empty-state { text-align: center; padding: 64px 24px; border: 1px dashed currentColor; border-radius: var(--radius-lg); opacity: 0.85; }
.empty-state h2 { font-size: 26px; margin-bottom: 12px; }

/* event detail */
.event-detail-grid { display: grid; grid-template-columns: minmax(0, 1.25fr) minmax(0, 1fr); gap: 64px; align-items: start; }
.event-facts { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 16px; padding: 24px 0; border-top: 1px solid var(--border); border-bottom: 1px solid var(--border); margin: 32px 0; }
.event-facts dt { font-size: 11px; letter-spacing: 0.2em; text-transform: uppercase; color: var(--muted2); margin-bottom: 6px; }
.event-facts dd { margin: 0; font-family: var(--display); text-transform: uppercase; letter-spacing: 0.04em; font-size: 19px; color: var(--text); }
.booking-panel { position: sticky; top: 90px; }
.booking-panel h2 { font-size: 26px; margin-bottom: 6px; color: var(--brand); }
.spots { display: inline-flex; gap: 8px; align-items: center; font-size: 12px; letter-spacing: 0.16em; text-transform: uppercase; color: var(--lime); margin-bottom: 20px; }
.spots::before { content: ""; width: 8px; height: 8px; border-radius: 50%; background: var(--lime); }

/* calendar */
.cal-head { display: flex; align-items: center; justify-content: space-between; gap: 16px; margin-bottom: 28px; flex-wrap: wrap; }
.cal-head h2 { font-size: clamp(28px, 3vw, 40px); color: var(--title); }
.calendar { display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); border-top: 1px solid var(--border); border-left: 1px solid var(--border); }
.cal-dow { padding: 12px 10px; font-size: 11px; letter-spacing: 0.2em; text-transform: uppercase; color: var(--muted2); border-right: 1px solid var(--border); border-bottom: 1px solid var(--border); background: var(--bg2); }
.cal-day { min-height: 128px; padding: 10px; border-right: 1px solid var(--border); border-bottom: 1px solid var(--border); display: flex; flex-direction: column; gap: 6px; }
.cal-day.out { background: rgba(255, 255, 255, 0.015); color: var(--muted2); }
.cal-day.today { box-shadow: inset 0 0 0 2px var(--brand); }
.cal-num { font-family: var(--display); font-size: 20px; }
.cal-event { display: block; padding: 6px 8px; border-radius: 6px; background: rgba(62, 198, 216, 0.14); border-left: 3px solid var(--brand); color: var(--text); font-size: 12px; line-height: 1.3; }
.cal-event:hover { background: var(--brand); color: var(--ink); }
.cal-event time { display: block; font-size: 10px; letter-spacing: 0.14em; color: var(--lime); }
.cal-event:hover time { color: var(--ink); }
.cal-list { display: none; }

/* full menu page */
.menu-page-nav { position: sticky; top: 66px; z-index: 20; background: rgba(15, 17, 25, 0.92); backdrop-filter: blur(12px); -webkit-backdrop-filter: blur(12px); border-bottom: 1px solid var(--border2); }
.menu-page-nav .row { display: flex; gap: 8px; overflow-x: auto; padding: 14px var(--gutter); scrollbar-width: none; max-width: 1360px; margin: 0 auto; }
.menu-page-nav .row::-webkit-scrollbar { display: none; }
.menu-section { padding: 72px 0 24px; scroll-margin-top: 140px; }
.menu-section > .container > h2 { margin-bottom: 8px; }
.menu-cat { margin-top: 48px; scroll-margin-top: 140px; }
.menu-cat h3 { font-family: var(--display); text-transform: uppercase; letter-spacing: 0.08em; font-size: 22px; color: var(--brand); padding-bottom: 14px; border-bottom: 1px solid var(--border); margin-bottom: 4px; font-weight: 400; }
.menu-items { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); column-gap: 56px; }
.menu-item { display: grid; grid-template-columns: 1fr auto; gap: 6px 20px; padding: 20px 4px; border-bottom: 1px solid var(--border2); align-items: baseline; }
.menu-item.has-img { grid-template-columns: 64px 1fr auto; align-items: start; }
.menu-item-thumb { width: 64px; height: 64px; border-radius: 10px; overflow: hidden; position: relative; grid-row: span 2; }
.menu-item h4 { font-family: var(--display); text-transform: uppercase; letter-spacing: 0.05em; font-size: 17px; font-weight: 400; color: var(--text); margin: 0; }
.menu-item .price { color: var(--brand); font-weight: 500; white-space: nowrap; }
.menu-item p { grid-column: 1 / -1; font-size: 14px; line-height: 1.55; color: var(--muted2); font-weight: 300; white-space: pre-line; }
.menu-item.has-img p { grid-column: 2 / -1; }
.menu-tags { grid-column: 1 / -1; display: flex; flex-wrap: wrap; gap: 6px; }
.menu-item.has-img .menu-tags { grid-column: 2 / -1; }
.chip { font-size: 10px; letter-spacing: 0.14em; text-transform: uppercase; padding: 3px 8px; border-radius: 999px; border: 1px solid var(--border); color: var(--muted2); }
.chip.green { border-color: rgba(183, 212, 74, 0.6); color: var(--lime); }
.allergen-note { margin-top: 64px; padding: 24px; border: 1px solid var(--border); border-radius: var(--radius-md); font-size: 14px; color: var(--muted2); }

/* story page */
.chapter { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 72px; align-items: center; padding: 64px 0; }
.chapter:nth-child(even) .chapter-media { order: 2; }
.stats { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 24px; padding: 40px 0; border-top: 1px solid var(--border); border-bottom: 1px solid var(--border); }
.stat b { display: block; font-family: var(--display); font-weight: 400; font-size: clamp(40px, 4.6vw, 64px); line-height: 1; color: var(--brand); }
.stat span { display: block; margin-top: 10px; font-size: 12px; letter-spacing: 0.18em; text-transform: uppercase; color: var(--muted2); }
.big-quote { font-family: var(--display); text-transform: uppercase; letter-spacing: 0.04em; font-size: clamp(26px, 3.4vw, 48px); line-height: 1.2; color: var(--title); text-align: center; max-width: 1000px; margin: 0 auto; text-wrap: balance; }

/* gallery page (masonry) */
.masonry { columns: 4 260px; column-gap: 20px; }
.masonry-item { break-inside: avoid; margin-bottom: 20px; border-radius: var(--radius-md); overflow: hidden; position: relative; display: block; cursor: zoom-in; background: var(--surface); border: 0; padding: 0; width: 100%; }
.masonry-item img { width: 100%; height: auto; transition: transform 0.7s var(--ease-out); }
.masonry-item:hover img { transform: scale(1.04); }
.lightbox { position: fixed; inset: 0; z-index: 120; background: rgba(8, 9, 14, 0.95); display: flex; align-items: center; justify-content: center; padding: 64px 72px; }
.lightbox img { max-width: 100%; max-height: 100%; object-fit: contain; border-radius: var(--radius-md); }
.lightbox .lb-btn { position: absolute; top: 50%; transform: translateY(-50%); }
.lightbox .lb-prev { left: 16px; }
.lightbox .lb-next { right: 16px; }
.lightbox .lb-close { position: absolute; top: 16px; right: 16px; }
.lightbox .lb-cap { position: absolute; bottom: 18px; left: 0; right: 0; text-align: center; color: var(--muted); font-size: 14px; }

/* article / rich text */
.prose { font-size: 17px; line-height: 1.75; color: var(--muted); font-weight: 300; }
.prose > * + * { margin-top: 1.1em; }
.prose h2 { font-family: var(--display); text-transform: uppercase; letter-spacing: 0.06em; font-weight: 400; font-size: 24px; color: var(--title); margin-top: 1.8em; line-height: 1.2; }
.prose h3 { font-family: var(--display); text-transform: uppercase; letter-spacing: 0.06em; font-weight: 400; font-size: 19px; color: var(--text); margin-top: 1.5em; }
.prose ul { padding-left: 1.2em; }
.prose li + li { margin-top: 0.4em; }
.prose li::marker { color: var(--brand); }
.prose strong { color: var(--text); font-weight: 500; }
.prose a { text-decoration: underline; text-underline-offset: 3px; }
.article-cover { aspect-ratio: 16 / 9; border-radius: var(--radius-lg); overflow: hidden; position: relative; margin: -120px 0 56px; box-shadow: var(--img-shadow); z-index: 3; }

/* contact page */
.contact-grid { display: grid; grid-template-columns: minmax(0, 0.9fr) minmax(0, 1.1fr); gap: 64px; align-items: start; }
.info-list { display: grid; gap: 28px; }
.info-item h3 { font-size: 11px; letter-spacing: 0.22em; text-transform: uppercase; color: var(--lime); font-weight: 500; margin-bottom: 8px; font-family: var(--body); }
.info-item p, .info-item a { font-size: 17px; color: var(--text); font-weight: 300; }
.info-item a:hover { color: var(--brand); }
.hours-table { width: 100%; border-collapse: collapse; font-size: 15px; }
.hours-table td { padding: 8px 0; border-bottom: 1px solid var(--border2); font-weight: 300; }
.hours-table td:last-child { text-align: right; color: var(--text); }
.hours-table tr.is-today td { color: var(--brand); font-weight: 500; }
.map-frame { width: 100%; aspect-ratio: 16 / 7; border: 0; border-radius: var(--radius-lg); filter: grayscale(0.35) contrast(1.05); display: block; }

.cards-2 { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 24px; }
.text-card { padding: 32px; border: 1px solid var(--border); border-radius: var(--radius-lg); background: var(--surface); }
.text-card h3 { font-family: var(--display); text-transform: uppercase; letter-spacing: 0.06em; font-weight: 400; font-size: 22px; color: var(--text); margin-bottom: 10px; }
.text-card p { color: var(--muted); font-weight: 300; }

/* 404 */
.notfound { min-height: 100vh; display: flex; align-items: center; justify-content: center; text-align: center; padding: 120px var(--gutter); }

/* ── image helper ── */
.cover { object-fit: cover; }
.fill-img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }

/* ════════════ RESPONSIVE ════════════ */
@media (max-width: 1100px) {
  .footer-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); }
  .footer-grid > :first-child { grid-column: 1 / -1; }
  .menu-items { grid-template-columns: 1fr; }
}

@media (max-width: 900px) {
  :root { --gutter: 20px; }
  .section, .story, .chefs { padding: 80px 0; }
  .activities { padding-top: 80px; }
  .events-home { padding: 72px 0 80px; }
  .gallery-home { padding: 80px 0; }

  .site-header { grid-template-columns: auto 1fr; padding: 16px var(--gutter); }
  .site-header nav, .header-right .hide-sm, .sticky-inner nav { display: none; }
  .header-logo img { height: 46px; }
  .sticky-inner { grid-template-columns: auto 1fr; padding: 10px var(--gutter); }
  .sticky-inner .logo-img { height: 34px; }

  .hero-grid, .story-head, .section-head, .activities-grid, .chefs-grid, .menu-home-grid,
  .event-detail-grid, .contact-grid, .chapter, .menu-body { grid-template-columns: 1fr; }
  .hero-address { justify-self: start; text-align: left; }
  .story-head .lead, .section-head > p { justify-self: start; }
  .timeline { grid-template-columns: repeat(2, minmax(0, 1fr)); row-gap: 48px; }
  .timeline::before { display: none; }
  .fan { margin-top: 64px; }
  .fan-item { margin: 0 -4%; }

  .polaroids { height: auto; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 24px 16px; padding: 12px 4px; }
  .polaroid-wrap { position: static; width: auto; }
  .polaroid-wrap:last-child:nth-child(odd) { grid-column: 1 / -1; justify-self: center; width: 60%; }

  .chefs-media { min-height: 0; aspect-ratio: 1 / 1.05; }
  .menu-home-intro { position: static; }
  .gallery-grid-home { width: 100%; margin-left: 0; grid-template-columns: repeat(3, minmax(0, 1fr)); grid-auto-rows: 34vw; }
  .gallery-grid-home .gallery-tile-wrap { grid-column: auto !important; grid-row: auto !important; }
  .gallery-grid-home .gallery-tile-wrap:nth-child(n + 10) { display: none; }
  .gallery-center { grid-column: 1 / -1; grid-row: auto; padding: 32px 0; order: -1; }
  .booking-panel { position: static; }
  .chapter:nth-child(even) .chapter-media { order: 0; }
  .chapter { gap: 32px; padding: 40px 0; }
  .stats { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .menu-page-nav { top: 56px; }
  .hover-image { display: none; }
  .review { width: 300px; }
  .menu-aside { order: 2; }
  .cards-2 { grid-template-columns: 1fr; }

  .calendar { display: none; }
  .cal-list { display: grid; gap: 12px; }
}

@media (max-width: 600px) {
  .form-grid { grid-template-columns: 1fr; }
  .timeline { grid-template-columns: 1fr; }
  .event-facts { grid-template-columns: 1fr 1fr; }
  .footer-grid { grid-template-columns: 1fr 1fr; padding-top: 56px; padding-bottom: 48px; }
  .btn { padding: 14px 24px; }
  .hero-body { padding-bottom: 48px; }
  .events-track { gap: 24px; grid-auto-columns: 78vw; }
  .lightbox { padding: 64px 12px; }
  .lightbox .lb-btn { top: auto; bottom: 16px; transform: none; }
  .article-cover { margin-top: -60px; }
}

/* ════════════ UPDATE 2 — event photos, smaller story fan, news carousel ════════════ */

/* story: fanned photos — smaller & centred */
.fan { max-width: 1040px; margin: 96px auto 0; }
@media (max-width: 900px) { .fan { max-width: 640px; margin-top: 56px; } }

/* event page: photo mosaic under the description */
.event-photos-wrap { margin-top: 48px; padding-top: 36px; border-top: 1px solid var(--border); }
.event-photos { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); grid-auto-rows: minmax(0, 1fr); gap: 12px; aspect-ratio: 16 / 10; }
.event-photo { position: relative; display: block; padding: 0; border: 0; border-radius: var(--radius-md); overflow: hidden; background: var(--surface); cursor: zoom-in; box-shadow: var(--img-shadow); }
.event-photo img { transition: transform 0.7s var(--ease-out); }
.event-photo:hover img { transform: scale(1.05); }
.event-photo:focus-visible { outline: 2px solid var(--brand); outline-offset: 3px; }
.event-photo:first-child { grid-column: span 2; grid-row: span 2; }
.event-photos.count-1 { grid-template-columns: 1fr; aspect-ratio: 4 / 3; }
.event-photos.count-1 .event-photo:first-child { grid-column: auto; grid-row: auto; }
.event-photos.count-2 { grid-template-columns: repeat(2, minmax(0, 1fr)); aspect-ratio: 16 / 9; }
.event-photos.count-2 .event-photo:first-child { grid-column: auto; grid-row: auto; }
.event-photos.count-3 { grid-template-columns: repeat(3, minmax(0, 1fr)); }
.event-photos.count-3 .event-photo:first-child { grid-column: span 2; grid-row: span 2; }
.event-photos.count-4 .event-photo:nth-child(4) { grid-column: span 2; }
.event-photo-more { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; background: rgba(15, 17, 25, 0.62); color: #fff; font-family: var(--display); font-size: 30px; letter-spacing: 0.04em; }
@media (max-width: 600px) {
  .event-photos, .event-photos.count-3 { grid-template-columns: repeat(2, minmax(0, 1fr)); grid-auto-rows: 34vw; aspect-ratio: auto; gap: 8px; }
  .event-photos .event-photo:first-child { grid-column: 1 / -1; grid-row: span 2; }
  .event-photos.count-4 .event-photo:nth-child(4) { grid-column: 1 / -1; }
  .event-photos.count-1, .event-photos.count-2 { grid-auto-rows: auto; aspect-ratio: auto; }
  .event-photos.count-1 .event-photo, .event-photos.count-2 .event-photo { grid-column: 1 / -1; grid-row: auto; aspect-ratio: 4 / 3; }
}

/* home: news — grid on desktop, swipe carousel on tablet & phone */
.news-dots { display: none; }
@media (max-width: 900px) {
  .news-track {
    display: flex; gap: 16px; overflow-x: auto; overscroll-behavior-x: contain;
    scroll-snap-type: x mandatory; scroll-padding: 0 var(--gutter); scrollbar-width: none;
    margin: 0 calc(var(--gutter) * -1); padding: 4px var(--gutter) 8px;
  }
  .news-track::-webkit-scrollbar { display: none; }
  .news-track > .news-slide { flex: 0 0 min(62%, 400px); scroll-snap-align: center; }
  .news-track > .news-slide[data-reveal] { opacity: 1; transform: none; }
  .news-track .news-card { aspect-ratio: 4 / 5; padding: 24px; }
  .news-track .news-card h3 { font-size: 24px; }
  .news-track .news-card p { font-size: 14px; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; }
  .news-dots { display: flex; justify-content: center; gap: 8px; margin-top: 20px; }
  .news-dots button { width: 8px; height: 8px; padding: 0; border: 0; border-radius: 99px; background: var(--border); cursor: pointer; transition: width 0.3s var(--ease-out), background 0.3s; }
  .news-dots button.is-active { width: 26px; background: var(--brand); }
}
@media (max-width: 600px) {
  .news-track > .news-slide { flex-basis: 84%; }
  .news-track .news-card { aspect-ratio: 4 / 5.2; padding: 22px; }
  .section-head .lead { font-size: 16px; }
}

/* menu page: keep each dish's text at the top of its row */
.menu-item { align-content: start; }
AMMOS_EOF
echo "  ✔ app/globals.css"

echo ""
echo "✔ All files updated. Now run:  npm run db:migrate  &&  npm run menu:sync  &&  npm run dev"
