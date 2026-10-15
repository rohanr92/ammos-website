import { z } from "zod";
import { eq } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { errorJson, json, withAdmin } from "@/lib/http";

type Ctx = { params: Promise<{ id: string }> };

/** PATCH { notify: boolean } → switch email notifications for a user (owners can change anyone, editors only themselves) */
export const PATCH = withAdmin<Ctx>(async (req, ctx, me) => {
  const { id } = await ctx.params;
  if (id !== me.id && me.role !== "owner") return errorJson("Only the owner account can do this.", 403);
  const { notify } = z.object({ notify: z.boolean() }).parse(await req.json());
  const updated = await db.update(schema.adminUsers).set({ notify, updatedAt: new Date() }).where(eq(schema.adminUsers.id, id)).returning({ id: schema.adminUsers.id });
  if (!updated.length) return errorJson("User not found", 404);
  return json({ ok: true });
});

export const DELETE = withAdmin<Ctx>(
  async (_req, ctx, me) => {
    const { id } = await ctx.params;
    if (id === me.id) return errorJson("You cannot delete your own account.", 400);
    const target = await db.query.adminUsers.findFirst({ where: eq(schema.adminUsers.id, id) });
    if (!target) return errorJson("User not found", 404);
    if (target.role === "owner") {
      const owners = await db.$count(schema.adminUsers, eq(schema.adminUsers.role, "owner"));
      if (owners <= 1) return errorJson("You cannot delete the last owner account.", 400);
    }
    await db.delete(schema.adminUsers).where(eq(schema.adminUsers.id, id));
    return json({ ok: true });
  },
  { ownerOnly: true },
);
