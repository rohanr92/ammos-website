import { z } from "zod";
import { inArray } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { json, withAdmin } from "@/lib/http";

const body = z.object({ ids: z.array(z.string().uuid()).min(1).max(1000), action: z.enum(["delete", "read", "unread"]) });

/** POST /api/admin/messages/bulk  { ids, action: "delete" | "read" | "unread" } */
export const POST = withAdmin(async (req) => {
  const { ids, action } = body.parse(await req.json());
  const where = inArray(schema.messages.id, ids);
  const rows =
    action === "delete"
      ? await db.delete(schema.messages).where(where).returning({ id: schema.messages.id })
      : await db.update(schema.messages).set({ isRead: action === "read" }).where(where).returning({ id: schema.messages.id });
  return json({ ok: true, count: rows.length });
});
