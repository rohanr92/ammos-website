import { z } from "zod";
import { inArray } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { json, withAdmin } from "@/lib/http";
import { refreshSite } from "@/lib/revalidate";

const body = z.object({ ids: z.array(z.string().uuid()).min(1).max(1000), action: z.enum(["delete", "confirmed", "cancelled", "pending"]) });

/** POST /api/admin/bookings/bulk  { ids, action } — delete, or set the status of many bookings (no emails are sent). */
export const POST = withAdmin(async (req) => {
  const { ids, action } = body.parse(await req.json());
  const where = inArray(schema.bookings.id, ids);
  const rows =
    action === "delete"
      ? await db.delete(schema.bookings).where(where).returning({ id: schema.bookings.id })
      : await db.update(schema.bookings).set({ status: action, updatedAt: new Date() }).where(where).returning({ id: schema.bookings.id });
  refreshSite();
  return json({ ok: true, count: rows.length });
});
