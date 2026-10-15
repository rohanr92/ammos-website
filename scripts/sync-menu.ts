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
