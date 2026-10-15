import { z } from "zod";
import { inArray } from "drizzle-orm";
import type { PgColumn } from "drizzle-orm/pg-core";
import { db } from "@/lib/db";
import { errorJson, json, withAdmin } from "@/lib/http";
import { getResource } from "@/lib/admin/resources.server";
import { refreshSite } from "@/lib/revalidate";

type Ctx = { params: Promise<{ resource: string }> };
const body = z.object({ ids: z.array(z.string().uuid()).min(1).max(1000), action: z.enum(["delete", "show", "hide"]) });

/** POST /api/admin/<resource>/bulk  { ids, action: "delete" | "show" | "hide" } */
export const POST = withAdmin<Ctx>(async (req, ctx) => {
  const { resource } = await ctx.params;
  const res = getResource(resource);
  if (!res) return errorJson("Unknown section", 404);
  const { ids, action } = body.parse(await req.json());
  const t = res.table as unknown as Record<string, PgColumn>;
  let count = 0;
  if (action === "delete") {
    count = (await db.delete(res.table).where(inArray(res.table.id, ids)).returning({ id: res.table.id })).length;
  } else {
    if (!t.published) return errorJson("This list has no show/hide option.", 400);
    count = (await db.update(res.table).set({ published: action === "show" } as never).where(inArray(res.table.id, ids)).returning({ id: res.table.id })).length;
  }
  refreshSite();
  return json({ ok: true, count });
});
