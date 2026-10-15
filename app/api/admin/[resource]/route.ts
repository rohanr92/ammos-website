import type { NextRequest } from "next/server";
import { db } from "@/lib/db";
import { errorJson, json, withAdmin } from "@/lib/http";
import { getResource, listRows, parseInput, uniqueSlug } from "@/lib/admin/resources.server";
import { refreshSite } from "@/lib/revalidate";

type Ctx = { params: Promise<{ resource: string }> };

/** GET /api/admin/<resource>?q=search  → list */
export const GET = withAdmin<Ctx>(async (req, ctx) => {
  const { resource } = await ctx.params;
  if (!getResource(resource)) return errorJson("Unknown section", 404);
  const q = req.nextUrl.searchParams.get("q") || undefined;
  return json({ ok: true, rows: await listRows(resource, { q }) });
});

/** POST /api/admin/<resource>  → create */
export const POST = withAdmin<Ctx>(async (req: NextRequest, ctx) => {
  const { resource } = await ctx.params;
  const res = getResource(resource);
  if (!res) return errorJson("Unknown section", 404);
  const values = parseInput(res.def, await req.json());
  if ("slug" in values) values.slug = await uniqueSlug(resource, values.slug);
  const [row] = await db.insert(res.table).values(values as never).returning();
  refreshSite();
  return json({ ok: true, row }, 201);
});
