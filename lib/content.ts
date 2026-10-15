import "server-only";
import { cache } from "react";
import { eq } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { SECTION_MAP, type Settings } from "@/lib/content-schema";
import { menuStyle, visibleLinks, type Navigation } from "@/lib/nav";

/**
 * Loads one editable section: the saved values from the database
 * merged over the defaults defined in content-schema.ts.
 */
export const getContent = cache(async <T = Record<string, any>>(key: string): Promise<T> => {
  const def = SECTION_MAP[key];
  const defaults = def?.defaults ?? {};
  try {
    const row = await db.query.siteContent.findFirst({ where: eq(schema.siteContent.key, key) });
    const saved = (row?.data ?? {}) as Record<string, unknown>;
    const merged: Record<string, unknown> = { ...defaults };
    for (const [k, v] of Object.entries(saved)) {
      // keep the default when the admin left a field empty
      if (v === null || v === undefined) continue;
      if (typeof v === "string" && v.trim() === "" && typeof defaults[k] === "string" && isRequiredText(k)) continue;
      merged[k] = v;
    }
    return merged as T;
  } catch (err) {
    console.error(`[content] could not load "${key}", using defaults`, err);
    return defaults as T;
  }
});

// Titles fall back to the default text if someone empties them by accident.
function isRequiredText(field: string) {
  return field === "title" || field === "siteName";
}

export const getSettings = () => getContent<Settings>("settings");

/** Header, full-screen menu and footer links (Admin → Navigation). */
export async function getNavigation(): Promise<Navigation> {
  const n = await getContent("navigation");
  return {
    headerLinks: visibleLinks(n.headerLinks),
    headerRightLabel: String(n.headerRightLabel || ""),
    headerRightUrl: String(n.headerRightUrl || ""),
    reserveLabel: String(n.reserveLabel || "Reserve"),
    menuStyleMobile: menuStyle(n.menuStyleMobile),
    menuStyleDesktop: menuStyle(n.menuStyleDesktop),
    menuLinks: visibleLinks(n.menuLinks),
    menuBottomLinks: visibleLinks(n.menuBottomLinks),
    footerColumns: [visibleLinks(n.footerCol1), visibleLinks(n.footerCol2), visibleLinks(n.footerCol3)].filter((c) => c.length > 0),
    footerBarLinks: visibleLinks(n.footerBarLinks),
  };
}
