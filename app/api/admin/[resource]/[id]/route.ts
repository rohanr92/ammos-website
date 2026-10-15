import { eq } from "drizzle-orm";
import { db } from "@/lib/db";
import { errorJson, json, withAdmin } from "@/lib/http";
import { getResource, getRow, parseInput, uniqueSlug } from "@/lib/admin/resources.server";
import { refreshSite } from "@/lib/revalidate";

type Ctx = { params: Promise<{ resource: string; id: string }> };

export const GET = withAdmin<Ctx>(async (_req, ctx) => {
  const { resource, id } = await ctx.params;
  const row = await getRow(resource, id);
  if (!row) return errorJson("Not found", 404);
  return json({ ok: true, row });
});

/** PUT → save changes */
export const PUT = withAdmin<Ctx>(async (req, ctx) => {
  const { resource, id } = await ctx.params;
  const res = getResource(resource);
  if (!res) return errorJson("Unknown section", 404);
  if (!(await getRow(resource, id))) return errorJson("Not found", 404);
  const values = parseInput(res.def, await req.json());
  if ("slug" in values) values.slug = await uniqueSlug(resource, values.slug, id);
  const [row] = await db.update(res.table).set(values as never).where(eq(res.table.id, id)).returning();
  refreshSite();
  return json({ ok: true, row });
});

/** DELETE → remove */
export const DELETE = withAdmin<Ctx>(async (_req, ctx) => {
  const { resource, id } = await ctx.params;
  const res = getResource(resource);
  if (!res) return errorJson("Unknown section", 404);
  const deleted = await db.delete(res.table).where(eq(res.table.id, id)).returning({ id: res.table.id });
  if (!deleted.length) return errorJson("Not found", 404);
  refreshSite();
  return json({ ok: true });
});
