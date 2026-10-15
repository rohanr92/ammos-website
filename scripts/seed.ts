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
import { eq, inArray } from "drizzle-orm";
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

// real Ammos dish photos (from Instagram) shown when hovering the dish in the homepage menu block
const DISH_PHOTOS: Record<string, string> = {
  "Salmon Tiratido": "/images/ig/dish-salmon-tiratido.webp",
  "Mussels Nero": "/images/ig/dish-mussels-nero.webp",
  "Tataki Tuna": "/images/ig/dish-tataki-tuna.webp",
  "Oktapodi Kythira": "/images/ig/dish-oktapodi-kythira.webp",
  "Seabass Fricassee": "/images/ig/dish-seabass.webp",
  "Seaside Orzotto": "/images/ig/dish-seaside-orzotto.webp",
  "Rib Eye Uruguay Angus": "/images/ig/dish-rib-eye.webp",
  "Ammos Roll": "/images/ig/dish-ammos-roll.webp",
  "Caldera Roll": "/images/ig/dish-caldera-roll.webp",
  "Peruvian Rainbow Roll": "/images/ig/dish-rainbow-roll.webp",
  "Geisha Sashimi Mix": "/images/ig/dish-geisha-sashimi.webp",
};

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
  for (const [name, image] of Object.entries(DISH_PHOTOS)) await db.update(schema.menuItems).set({ image }).where(eq(schema.menuItems.name, name));
  console.log(`✔ Menu imported: ${r.categories} categories, ${r.total} items`);
}

/* ───────── events ───────── */
const SAMPLE_GALLERY = ["/images/ig/event-night-party.webp", "/images/ig/event-dj-crowd.webp", "/images/ig/event-hug.webp", "/images/ig/story-2015-friends.webp", "/images/ig/fan-aperol.webp", "/images/ig/story-2026-terrace.webp"];
async function seedEvents() {
  if ((await db.$count(schema.events)) > 0) return console.log("• Events exist — skipped");
  const fri = nextWeekday(5);
  const upcoming = [
    { title: "Sunset sessions w/ Nikos K", category: "Live DJ", venue: "Terrace", day: fri, h: 19, image: "/images/ig/event-sunset.webp", price: "Free entry", cap: 180,
      summary: "Golden-hour house and disco on the terrace as the sun drops into the bay.",
      description: "Our resident Nikos K takes over the decks from sunset until late with a set of deep house, nu-disco and Balearic grooves.\n\nArrive early for the best seats on the terrace and the first round of signature cocktails.\n\n## Good to know\n- Smart-casual dress code after 20:00\n- Tables for 4+ are best booked in advance" },
    { title: "Full moon beach party", category: "Party", venue: "Beach", day: fri + 1, h: 21, image: "/images/ig/event-night-party.webp", price: "€15 entry incl. welcome drink", cap: 400,
      summary: "Barefoot on the sand under the full moon — fire shows, guest DJs and the bar open till late.",
      description: "Once a month we light up the beach for our full moon party.\n\nExpect guest DJs, fire performers and a beach bar serving our signature cocktails until the early hours.\n\n## Good to know\n- 18+ only, ID may be requested\n- Entry includes one welcome drink" },
    { title: "Long table Sunday brunch", category: "Dining", venue: "Restaurant", day: fri + 2, h: 11, m: 30, image: "/images/ig/event-brunch.webp", price: "€35 per person", cap: 60,
      summary: "One long table, sharing plates, bottomless coffee and a live acoustic duo.",
      description: "Our Sunday ritual: a long table set by the sea, sharing plates from the kitchen, fresh juices and a live acoustic duo.\n\nVegetarian and vegan options available — tell us about allergies in your booking." },
    { title: "Acoustic nights: Elena & band", category: "Live music", venue: "Terrace", day: fri + 6, h: 20, image: "/images/ig/event-terrace-night.webp", price: "Free entry", cap: 150,
      summary: "Elena and her band play soul, bossa and Greek classics under the stars.",
      description: "An easy evening of live soul, bossa nova and Greek classics. Book a table for dinner and stay for the music." },
    { title: "Cypriot wine & meze evening", category: "Tasting", venue: "Bar", day: fri + 7, h: 19, m: 30, image: "/images/ig/event-wine-steak.webp", price: "€45 per person", cap: 40,
      summary: "Five Cypriot wines paired with five meze plates, hosted by our sommelier.",
      description: "Discover the island's best producers — Kyperounda, Zambartas and more — paired with five meze plates from our kitchen.\n\nLimited to 40 guests." },
    { title: "Ammos summer closing party", category: "Live DJ", venue: "Terrace", day: fri + 8, h: 21, image: "/images/ig/event-dj-crowd.webp", price: "Free entry", cap: 400,
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
