import { z } from "zod";
import { eq } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { json, withAdmin } from "@/lib/http";

type Ctx = { params: Promise<{ id: string }> };

export const PATCH = withAdmin<Ctx>(async (req, ctx) => {
  const { id } = await ctx.params;
  const { isRead } = z.object({ isRead: z.boolean() }).parse(await req.json());
  await db.update(schema.messages).set({ isRead }).where(eq(schema.messages.id, id));
  return json({ ok: true });
});

export const DELETE = withAdmin<Ctx>(async (_req, ctx) => {
  const { id } = await ctx.params;
  await db.delete(schema.messages).where(eq(schema.messages.id, id));
  return json({ ok: true });
});
