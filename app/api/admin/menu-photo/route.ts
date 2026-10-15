import { z } from "zod";
import { eq, inArray } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { errorJson, json, withAdmin } from "@/lib/http";
import { refreshSite } from "@/lib/revalidate";
import { slugify } from "@/lib/utils";

export const runtime = "nodejs";

const body = z.object({
  fileName: z.string().trim().min(1).max(200),
  url: z.string().trim().regex(/^\/uploads\/[\w\-./]+$/, "Invalid upload"),
});

/**
 * POST /api/admin/menu-photo  { fileName: "tataki-tuna.jpg", url: "/uploads/…" }
 * Puts the photo on every menu item whose name matches the file name
 * ("Tataki Tuna.jpg", "tataki_tuna-2.png" → "Tataki Tuna").
 */
export const POST = withAdmin(async (req) => {
  const { fileName, url } = body.parse(await req.json());
  const key = slugify(fileName.replace(/\.[a-z0-9]+$/i, "").replace(/[-_ ]\d{1,2}$/, ""));
  if (!key) return errorJson("File name is empty.", 422);

  const items = await db.select({ id: schema.menuItems.id, name: schema.menuItems.name }).from(schema.menuItems).where(eq(schema.menuItems.published, true));
  const withSlug = items.map((i) => ({ ...i, slug: slugify(i.name) })).filter((i) => i.slug);

  // 1) exact match, 2) otherwise the longest dish name contained in the file name
  let matches = withSlug.filter((i) => i.slug === key);
  if (!matches.length) {
    const contained = withSlug.filter((i) => i.slug.length >= 4 && `-${key}-`.includes(`-${i.slug}-`)).sort((a, b) => b.slug.length - a.slug.length);
    if (contained.length) matches = contained.filter((i) => i.slug === contained[0].slug);
  }
  if (!matches.length) return json({ ok: true, matched: [] });

  await db.update(schema.menuItems).set({ image: url, updatedAt: new Date() }).where(inArray(schema.menuItems.id, matches.map((m) => m.id)));
  refreshSite();
  return json({ ok: true, matched: Array.from(new Set(matches.map((m) => m.name))) });
});
