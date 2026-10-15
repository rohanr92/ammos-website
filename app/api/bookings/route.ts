import type { NextRequest } from "next/server";
import { randomInt } from "node:crypto";
import { eq } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { getBookedGuests } from "@/lib/data";
import { clientIp, errorJson, handleError, json, rateLimit, sameOrigin } from "@/lib/http";
import { bookingSchema, looksLikeSpam } from "@/lib/validation";
import { adminRecipients, button, detailsTable, emailLayout, paragraph, sendMail } from "@/lib/mailer";
import { formatDateTime, isEventOver, siteUrl } from "@/lib/utils";

const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no 0/O/1/I
function makeReference() {
  let s = "";
  for (let i = 0; i < 6; i++) s += ALPHABET[randomInt(ALPHABET.length)];
  return `AM-${s}`;
}

export async function POST(req: NextRequest) {
  try {
    if (!sameOrigin(req)) return errorJson("Please book from the website.", 403);
    const ip = clientIp(req);
    const limit = rateLimit(`booking:${ip}`, 6, 10 * 60 * 1000);
    if (!limit.ok) return errorJson("Too many booking attempts. Please try again later or call us.", 429);

    const data = bookingSchema.parse(await req.json());
    if (looksLikeSpam(data)) return json({ ok: true, reference: makeReference() });

    const event = await db.query.events.findFirst({ where: eq(schema.events.id, data.eventId) });
    if (!event || !event.published) return errorJson("This event is no longer available.", 404);
    if (!event.bookingEnabled) return errorJson("Online booking is closed for this event. Please call us.", 400);
    if (isEventOver(event.startsAt)) return errorJson("This event has already started or passed, so online booking is closed. Please call us.", 400);

    if (event.capacity) {
      const booked = await getBookedGuests(event.id);
      const left = event.capacity - booked;
      if (left <= 0) return errorJson("Sorry — this event is fully booked. Call us to join the waiting list.", 409);
      if (data.guests > left) return errorJson(`Only ${left} place${left === 1 ? "" : "s"} left for this event.`, 409);
    }

    let reference = makeReference();
    for (let i = 0; i < 3; i++) {
      const exists = await db.query.bookings.findFirst({ where: eq(schema.bookings.reference, reference) });
      if (!exists) break;
      reference = makeReference();
    }

    const [saved] = await db
      .insert(schema.bookings)
      .values({
        reference,
        eventId: event.id,
        eventTitle: event.title,
        eventDate: event.startsAt,
        firstName: data.firstName,
        lastName: data.lastName,
        email: data.email.toLowerCase(),
        phone: data.phone,
        guests: data.guests,
        seating: data.seating,
        occasion: data.occasion,
        message: data.message,
        marketingOptIn: data.marketingOptIn,
        ip,
      })
      .returning({ id: schema.bookings.id });

    const when = formatDateTime(event.startsAt);
    const name = `${data.firstName} ${data.lastName}`;
    const rows: [string, unknown][] = [
      ["Reference", reference],
      ["Event", event.title],
      ["When", when],
      ["Name", name],
      ["Email", data.email],
      ["Phone", data.phone],
      ["Guests", data.guests],
      ["Seating", data.seating],
      ["Occasion", data.occasion],
      ["Notes", data.message],
    ];

    await sendMail({
      to: await adminRecipients(),
      replyTo: data.email,
      subject: `New booking ${reference}: ${event.title} — ${data.guests} guests`,
      text: rows.map(([k, v]) => `${k}: ${v ?? ""}`).join("\n"),
      html: emailLayout("New event booking", detailsTable(rows) + button(siteUrl(`/admin/bookings?open=${saved.id}`), "Open in admin")),
    });
    await sendMail({
      to: data.email,
      subject: `Booking request received — ${event.title} (${reference})`,
      text: `Hi ${data.firstName},\n\nThank you for your booking request for ${event.title} on ${when} for ${data.guests} guests.\nReference: ${reference}\n\nWe'll confirm your table shortly.\nAmmos Makenzy Beach · +357 24 828844`,
      html: emailLayout(
        `See you soon, ${data.firstName}!`,
        paragraph(`Thank you for your booking request. We'll confirm your table by email or phone shortly.`) +
          detailsTable([
            ["Reference", reference],
            ["Event", event.title],
            ["When", when],
            ["Guests", data.guests],
          ]) +
          paragraph("Need to change something? Just reply to this email or call +357 24 828844.") +
          button(siteUrl(`/events/${event.slug}`), "View event"),
      ),
    });

    return json({ ok: true, reference });
  } catch (err) {
    return handleError(err);
  }
}
