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
