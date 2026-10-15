import type { NextRequest } from "next/server";
import { db, schema } from "@/lib/db";
import { clientIp, errorJson, handleError, json, rateLimit, sameOrigin } from "@/lib/http";
import { contactSchema, looksLikeSpam } from "@/lib/validation";
import { adminRecipients, button, detailsTable, emailLayout, paragraph, sendMail } from "@/lib/mailer";
import { siteUrl } from "@/lib/utils";

export async function POST(req: NextRequest) {
  try {
    if (!sameOrigin(req)) return errorJson("Please send the form from the website.", 403);
    const ip = clientIp(req);
    const limit = rateLimit(`contact:${ip}`, 5, 10 * 60 * 1000);
    if (!limit.ok) return errorJson("Too many messages. Please try again in a few minutes or call us.", 429);

    const data = contactSchema.parse(await req.json());
    if (looksLikeSpam(data)) return json({ ok: true }); // pretend success for bots

    const [saved] = await db
      .insert(schema.messages)
      .values({
        firstName: data.firstName,
        lastName: data.lastName,
        email: data.email.toLowerCase(),
        phone: data.phone,
        subject: data.subject || "General enquiry",
        visitDate: data.visitDate,
        guests: data.guests,
        message: data.message,
        source: data.source || "contact",
        ip,
      })
      .returning({ id: schema.messages.id });

    const name = `${data.firstName} ${data.lastName}`.trim();
    // 1) notification to Ammos (reply goes straight to the guest)
    await sendMail({
      to: await adminRecipients(),
      replyTo: data.email,
      subject: `New message: ${data.subject || "Website enquiry"} — ${name}`,
      text: `${name} <${data.email}> ${data.phone}\nDate: ${data.visitDate} Guests: ${data.guests ?? ""}\n\n${data.message}`,
      html: emailLayout(
        "New website message",
        detailsTable([
          ["Name", name],
          ["Email", data.email],
          ["Phone", data.phone],
          ["Subject", data.subject],
          ["Date", data.visitDate],
          ["Guests", data.guests],
          ["Form", data.source],
          ["Message", data.message],
        ]) + button(siteUrl(`/admin/messages?open=${saved.id}`), "Open in admin"),
      ),
    });
    // 2) confirmation to the guest
    await sendMail({
      to: data.email,
      subject: "We received your message — Ammos Makenzy Beach",
      text: `Hi ${data.firstName}, thank you for contacting Ammos. We'll reply as soon as possible.\n\nYour message:\n${data.message}`,
      html: emailLayout(
        `Thank you, ${data.firstName}!`,
        paragraph("We've received your message and will get back to you as soon as possible. For anything urgent, call us on +357 24 828844.") +
          detailsTable([["Your message", data.message]]),
      ),
    });

    return json({ ok: true });
  } catch (err) {
    return handleError(err);
  }
}
