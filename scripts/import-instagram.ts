/**
 * Imports the Ammos Instagram photos & reels into the website gallery.
 * Run:  npm run gallery:instagram
 *
 * - reads scripts/seed-data/instagram.json (made from instagram.com/ammosbeachbar);
 *   if that file doesn't exist yet, it takes the list from the clipboard (pbpaste on Mac)
 * - downloads every photo, optimises it to WebP and stores it in uploads/instagram/
 * - adds it to Admin → Gallery (albums: The Beach, Food, The Bar, Events, Videos)
 * - reels get a play button and play inside the gallery
 * - food photos whose caption names a dish are also used as that dish's menu photo
 * - the example photos from the first install are hidden (add --keep-samples to keep them)
 * Safe to run again: photos already imported are skipped.
 */
import { execSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import sharp from "sharp";
import { and, eq, like } from "drizzle-orm";
import { db, pool, schema } from "./db";

type Post = { c: string; t: "p" | "reel"; al: string; a: string; s: string };

const LIST = join(process.cwd(), "scripts/seed-data/instagram.json");
const OUT_DIR = join(resolve(process.cwd(), process.env.UPLOAD_DIR || "./uploads"), "instagram");

function loadList(): Post[] {
  let raw = "";
  if (existsSync(LIST)) raw = readFileSync(LIST, "utf8");
  else {
    try {
      raw = execSync("pbpaste", { encoding: "utf8", maxBuffer: 50 * 1024 * 1024 });
    } catch {
      /* not a Mac */
    }
  }
  let list: Post[] = [];
  try {
    list = JSON.parse(raw.trim());
  } catch {
    /* handled below */
  }
  if (!Array.isArray(list) || !list.length || !list[0]?.c || !list[0]?.s) {
    console.error(
      "\n✖ No Instagram list found.\n  In the Claude browser pane (Instagram page) click the blue “COPY AMMOS LIST” button,\n  then run this command again WITHOUT copying anything else in between.\n",
    );
    process.exit(1);
  }
  if (!existsSync(LIST)) {
    writeFileSync(LIST, JSON.stringify(list));
    console.log(`• Saved the list to scripts/seed-data/instagram.json (${list.length} posts)`);
  }
  return list;
}

/** caption words → menu item name, for photos that show a specific dish */
const DISH_HINTS: [RegExp, string][] = [
  [/octopus|oktapodi/i, "Oktapodi Kythira"],
  [/rib ?eye/i, "Rib Eye Uruguay Angus"],
  [/ravioli/i, "Ravioli Pastitsio"],
  [/tataki/i, "Tataki Tuna"],
  [/tiratido|tiradito/i, "Salmon Tiratido"],
  [/mussels/i, "Mussels Nero"],
  [/sea ?bass/i, "Seabass Fricassee"],
  [/orzotto/i, "Seaside Orzotto"],
];

async function download(url: string) {
  const res = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0 (Macintosh) ammos.eu gallery import" }, signal: AbortSignal.timeout(30000) });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return Buffer.from(await res.arrayBuffer());
}

async function main() {
  const list = loadList();
  mkdirSync(OUT_DIR, { recursive: true });
  const menu = await db.select({ id: schema.menuItems.id, name: schema.menuItems.name, image: schema.menuItems.image }).from(schema.menuItems);

  let added = 0;
  let skipped = 0;
  let failed = 0;
  let expired = 0;
  let homeCount = 0;
  const dishSet = new Set<string>();

  const queue = list.map((p, i) => ({ p, i }));
  async function worker() {
    for (let job = queue.shift(); job; job = queue.shift()) {
      const { p, i } = job;
      const path = `/uploads/instagram/${p.c}.webp`;
      const exists = await db.select({ id: schema.galleryImages.id }).from(schema.galleryImages).where(eq(schema.galleryImages.image, path)).limit(1);
      if (exists.length) {
        skipped++;
        continue;
      }
      try {
        const buf = await download(p.s);
        const out = await sharp(buf).rotate().resize({ width: 1600, height: 1600, fit: "inside", withoutEnlargement: true }).webp({ quality: 82 }).toBuffer();
        writeFileSync(join(OUT_DIR, `${p.c}.webp`), out);
        const isVideo = p.t === "reel" || p.al === "Videos";
        const onHome = !isVideo && p.al !== "Events" && homeCount < 12;
        if (onHome) homeCount++;
        await db.insert(schema.galleryImages).values({
          image: path,
          alt: p.a || "Ammos Makenzy Beach, Larnaca",
          album: p.al || "The Beach",
          video: isVideo ? `https://www.instagram.com/${p.t === "p" ? "p" : "reel"}/${p.c}/` : "",
          showOnHome: onHome,
          sortOrder: (i + 1) * 10,
          published: true,
        });
        added++;
        if (!isVideo && p.al === "Food") {
          for (const [re, dish] of DISH_HINTS) {
            const item = menu.find((m) => m.name.toLowerCase() === dish.toLowerCase());
            if (re.test(p.a) && item && !item.image && !dishSet.has(item.id)) {
              await db.update(schema.menuItems).set({ image: path, updatedAt: new Date() }).where(eq(schema.menuItems.id, item.id));
              dishSet.add(item.id);
              console.log(`  🍽  ${item.name} ← ${p.c}`);
            }
          }
        }
        if (added % 20 === 0) console.log(`  … ${added} imported`);
      } catch (err) {
        const msg = (err as Error).message;
        if (/HTTP 403|HTTP 410/.test(msg)) expired++;
        else failed++;
        console.log(`  ! ${p.c}: ${msg}`);
      }
    }
  }
  await Promise.all([worker(), worker(), worker(), worker()]);

  if (added > 0 && !process.argv.includes("--keep-samples")) {
    const hidden = await db
      .update(schema.galleryImages)
      .set({ published: false, showOnHome: false })
      .where(and(like(schema.galleryImages.image, "/images/%"), eq(schema.galleryImages.published, true)))
      .returning({ id: schema.galleryImages.id });
    if (hidden.length) console.log(`• Hid ${hidden.length} example photos from the first install`);
  }

  console.log(`\n✔ Instagram import: ${added} added, ${skipped} already there, ${failed + expired} failed. ${dishSet.size} dish photos set.`);
  if (expired) console.log("  Some Instagram links have expired — ask Claude to refresh the list, then delete scripts/seed-data/instagram.json and run again.");
  console.log("  Restart `npm run dev` (or wait 5 minutes on the live site) to see them on /gallery.");
}

main()
  .catch((err) => {
    console.error("✖ Import failed:", err.message || err);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
