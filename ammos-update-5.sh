#!/bin/bash
# Ammos website — update 5: mobile gallery grid, menu button under dishes, no cocktails on homepage, story cards hidden on phones
set -e
if [ ! -f scripts/import-instagram.ts ]; then echo "✖ Run this inside ammos-website after update 4."; exit 1; fi
echo "→ Updating files…"

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
        {after && <div className="menu-after menu-after-top">{after}</div>}
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
        {/* on phones the button sits under the dishes */}
        {after && <div className="menu-after menu-after-bottom">{after}</div>}
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
cat > "drizzle/0003_home_menu_no_cocktails.sql" << 'AMMOS_EOF'
-- the homepage menu block shows food only: take cocktails/drinks off the homepage (they stay on the menu page)
UPDATE "menu_items" SET "featured" = false WHERE "featured" = true AND "category_id" IN (SELECT "id" FROM "menu_categories" WHERE "section" <> 'Food');
AMMOS_EOF
echo "  ✔ drizzle/0003_home_menu_no_cocktails.sql"

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
    },
    {
      "idx": 2,
      "version": "7",
      "when": 1792063196474,
      "tag": "0002_gallery_video",
      "breakpoints": true
    },
    {
      "idx": 3,
      "version": "7",
      "when": 1792063739128,
      "tag": "0003_home_menu_no_cocktails",
      "breakpoints": true
    }
  ]
}
AMMOS_EOF
echo "  ✔ drizzle/meta/_journal.json"

mkdir -p "drizzle/meta"
cat > "drizzle/meta/0003_snapshot.json" << 'AMMOS_EOF'
{
  "id": "14d144b1-e763-435f-b380-943db6b85a38",
  "prevId": "420ee43d-445e-4141-814a-d9edc4241e24",
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
          "with": {},
          "method": "btree",
          "concurrently": false
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
          "with": {},
          "method": "btree",
          "concurrently": false
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
          "with": {},
          "method": "btree",
          "concurrently": false
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
          "with": {},
          "method": "btree",
          "concurrently": false
        }
      },
      "foreignKeys": {
        "bookings_event_id_events_id_fk": {
          "name": "bookings_event_id_events_id_fk",
          "tableFrom": "bookings",
          "columnsFrom": [
            "event_id"
          ],
          "tableTo": "events",
          "columnsTo": [
            "id"
          ],
          "onUpdate": "no action",
          "onDelete": "set null"
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
          "with": {},
          "method": "btree",
          "concurrently": false
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
          "with": {},
          "method": "btree",
          "concurrently": false
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
        "video": {
          "name": "video",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
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
          "with": {},
          "method": "btree",
          "concurrently": false
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
          "with": {},
          "method": "btree",
          "concurrently": false
        }
      },
      "foreignKeys": {
        "menu_items_category_id_menu_categories_id_fk": {
          "name": "menu_items_category_id_menu_categories_id_fk",
          "tableFrom": "menu_items",
          "columnsFrom": [
            "category_id"
          ],
          "tableTo": "menu_categories",
          "columnsTo": [
            "id"
          ],
          "onUpdate": "no action",
          "onDelete": "cascade"
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
          "with": {},
          "method": "btree",
          "concurrently": false
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
          "with": {},
          "method": "btree",
          "concurrently": false
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
          "with": {},
          "method": "btree",
          "concurrently": false
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
  "views": {},
  "sequences": {},
  "roles": {},
  "policies": {},
  "_meta": {
    "columns": {},
    "schemas": {},
    "tables": {}
  }
}
AMMOS_EOF
echo "  ✔ drizzle/meta/0003_snapshot.json"

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

/* ════════════ UPDATE 3 — hero centred + Google rating, event passed tag ════════════ */
.hero-body { align-items: center; padding-top: 150px; padding-bottom: 150px; }
.hero-grid { grid-template-columns: minmax(0, 1fr); }
.hero-address { position: absolute; right: max(var(--gutter), calc((100% - 1360px) / 2 + var(--gutter))); bottom: 48px; }
.hero-rating { display: inline-flex; align-items: center; flex-wrap: wrap; gap: 10px; margin-top: 28px; font-size: 15px; color: var(--muted); animation: fadeUp 1.1s 0.45s var(--ease) both; }
.hero-rating b { color: #fff; font-weight: 500; font-size: 16px; }
.hero-rating:hover span:not(.rating-stars) { color: #fff; }
.rating-stars { position: relative; display: inline-block; font-size: 17px; letter-spacing: 2px; line-height: 1; color: rgba(255, 255, 255, 0.22); }
.rating-stars::before { content: "★★★★★"; position: absolute; inset: 0; width: var(--fill, 100%); overflow: hidden; white-space: nowrap; color: var(--lime); }
@media (max-width: 900px) {
  .hero-body { padding-top: 130px; padding-bottom: 120px; }
  .hero-address { left: var(--gutter); right: auto; bottom: 36px; text-align: left; }
}
@media (max-width: 600px) {
  .hero-body { padding-bottom: 110px; }
  .hero-rating { font-size: 14px; gap: 8px; }
}

/* event cards: "Event passed" tag + dimmed photo */
.past-flag { background: rgba(15, 17, 25, 0.82); color: #fff; backdrop-filter: blur(4px); border: 1px solid rgba(255, 255, 255, 0.18); }
.event-card.is-over .event-card-media img { filter: grayscale(0.6) brightness(0.8); }
.past-flag-inline { position: static; display: inline-block; margin-bottom: 14px; }
.form-alert:not(.ok):not(.err) { background: var(--surface); border: 1px solid var(--border); color: var(--text); }

/* gallery: video tiles + players */
.masonry-item.is-video::after { content: ""; position: absolute; inset: 0; background: linear-gradient(180deg, transparent 55%, rgba(15, 17, 25, 0.55)); pointer-events: none; }
.play-badge { position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%); z-index: 1; width: 58px; height: 58px; border-radius: 50%; display: flex; align-items: center; justify-content: center; background: rgba(15, 17, 25, 0.55); color: #fff; border: 1.5px solid rgba(255, 255, 255, 0.85); backdrop-filter: blur(4px); transition: transform 0.3s var(--ease-out), background 0.3s; }
.play-badge svg { margin-left: 3px; }
.masonry-item.is-video:hover .play-badge { transform: translate(-50%, -50%) scale(1.1); background: var(--brand); color: var(--ink); border-color: var(--brand); }
.lightbox .lb-embed { width: min(440px, 100%); height: min(780px, 100%); border: 0; border-radius: var(--radius-md); background: #fff; }
.lightbox .lb-video { max-width: 100%; max-height: 100%; border-radius: var(--radius-md); background: #000; }

/* ════════════ UPDATE 5 — mobile polish ════════════ */
.menu-after-bottom { display: none; }
@media (max-width: 900px) {
  /* menu block: button under the dishes */
  .menu-after-top { display: none; }
  .menu-after-bottom { display: flex; flex-direction: column; align-items: center; text-align: center; margin-top: 36px; }
  .menu-home-intro .pill-tabs { margin-bottom: 8px; }

  /* story: hide the fanned photo cards on phones */
  .fan { display: none; }

  /* homepage gallery: tidy bento grid with side margins */
  .gallery-grid-home {
    width: auto; margin: 12px var(--gutter) 0; padding: 0;
    grid-template-columns: repeat(2, minmax(0, 1fr)); grid-auto-rows: 44vw; gap: 10px;
  }
  .gallery-grid-home .gallery-tile-wrap:nth-child(3n + 1) { grid-column: 1 / -1 !important; }
  .gallery-grid-home .gallery-tile-wrap:nth-child(n + 8) { display: none; }
  .gallery-grid-home .gallery-tile { border-radius: 14px; }
  .gallery-center { padding: 8px 0 28px; gap: 22px; }
  .gallery-center h3 { font-size: clamp(30px, 9vw, 40px); }
  .gallery-home .events-head { flex-direction: column; align-items: flex-start; gap: 20px; }
}
@media (min-width: 601px) and (max-width: 900px) {
  .gallery-grid-home { grid-template-columns: repeat(3, minmax(0, 1fr)); grid-auto-rows: 30vw; }
  .gallery-grid-home .gallery-tile-wrap:nth-child(3n + 1) { grid-column: auto !important; }
  .gallery-grid-home .gallery-tile-wrap:nth-child(n + 7) { display: none; }
}
AMMOS_EOF
echo "  ✔ app/globals.css"

npm run db:migrate
echo ""
echo "✔ Update 5 done."
