import { z } from "zod";
import { eq } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { errorJson, json, withAdmin } from "@/lib/http";
import { button, detailsTable, emailLayout, paragraph, sendMail } from "@/lib/mailer";
import { formatDateTime, siteUrl } from "@/lib/utils";
import { refreshSite } from "@/lib/revalidate";

type Ctx = { params: Promise<{ id: string }> };

const patchSchema = z.object({
  status: z.enum(["pending", "confirmed", "cancelled"]).optional(),
  adminNotes: z.string().max(5000).optional(),
  guests: z.coerce.number().int().min(1).max(500).optional(),
  notifyGuest: z.boolean().optional(),
});

/** PATCH → change status / notes / guests (optionally email the guest) */
export const PATCH = withAdmin<Ctx>(async (req, ctx) => {
  const { id } = await ctx.params;
  const data = patchSchema.parse(await req.json());
  const booking = await db.query.bookings.findFirst({ where: eq(schema.bookings.id, id) });
  if (!booking) return errorJson("Booking not found", 404);

  const { notifyGuest, ...changes } = data;
  const [row] = await db.update(schema.bookings).set(changes).where(eq(schema.bookings.id, id)).returning();
  refreshSite(); // spots left on the event page

  let emailed = false;
  if (notifyGuest && data.status && data.status !== booking.status && data.status !== "pending") {
    const confirmed = data.status === "confirmed";
    const event = booking.eventId ? await db.query.events.findFirst({ where: eq(schema.events.id, booking.eventId) }) : null;
    emailed = await sendMail({
      to: booking.email,
      subject: confirmed ? `Your table is confirmed — ${booking.eventTitle} (${booking.reference})` : `Booking update — ${booking.eventTitle} (${booking.reference})`,
      text: confirmed
        ? `Hi ${booking.firstName}, your booking ${booking.reference} for ${booking.eventTitle} is confirmed. See you soon!`
        : `Hi ${booking.firstName}, unfortunately we could not confirm booking ${booking.reference} for ${booking.eventTitle}. Please call +357 24 828844.`,
      html: emailLayout(
        confirmed ? `You're confirmed, ${booking.firstName}!` : "About your booking",
        paragraph(
          confirmed
            ? "Great news — your table is confirmed. We look forward to welcoming you at Ammos."
            : "Unfortunately we couldn't confirm this booking. Please call us on +357 24 828844 and we'll do our best to find you a spot.",
        ) +
          detailsTable([
            ["Reference", booking.reference],
            ["Event", booking.eventTitle],
            ["When", booking.eventDate ? formatDateTime(booking.eventDate) : ""],
            ["Guests", row.guests],
          ]) +
          (event ? button(siteUrl(`/events/${event.slug}`), "Event details") : ""),
      ),
    });
  }
  return json({ ok: true, row, emailed });
});

export const DELETE = withAdmin<Ctx>(async (_req, ctx) => {
  const { id } = await ctx.params;
  await db.delete(schema.bookings).where(eq(schema.bookings.id, id));
  refreshSite();
  return json({ ok: true });
});
