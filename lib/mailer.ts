import "server-only";
import nodemailer, { type Transporter } from "nodemailer";
import { eq } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { siteUrl } from "@/lib/utils";

/**
 * Sends email through your SMTP account (e.g. Hostinger email for info@ammos.eu).
 * If SMTP_HOST is empty (local testing), emails are printed in the terminal instead.
 */

let transporter: Transporter | null = null;
function getTransporter() {
  if (!process.env.SMTP_HOST) return null;
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT || 465),
      secure: String(process.env.SMTP_SECURE ?? "true") !== "false",
      auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
    });
  }
  return transporter;
}

function envRecipients() {
  return (process.env.MAIL_TO || "info@ammos.eu")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

/**
 * Who gets "new booking" / "new message" emails:
 * MAIL_TO from .env + every admin user with "Email notifications" switched on (Admin → My account & users).
 */
export async function adminRecipients(): Promise<string[]> {
  const list = new Set(envRecipients().map((e) => e.toLowerCase()));
  try {
    const users = await db.select({ email: schema.adminUsers.email }).from(schema.adminUsers).where(eq(schema.adminUsers.notify, true));
    for (const u of users) if (u.email) list.add(u.email.toLowerCase());
  } catch (err) {
    console.error("[email] could not load admin users for notifications", err);
  }
  return Array.from(list);
}

type Mail = { to: string | string[]; subject: string; html: string; text: string; replyTo?: string };

export async function sendMail(mail: Mail): Promise<boolean> {
  const t = getTransporter();
  const from = process.env.MAIL_FROM || "Ammos Makenzy Beach <info@ammos.eu>";
  if (!t) {
    console.log(`\n[email — SMTP not configured, not sent]\nTo: ${mail.to}\nSubject: ${mail.subject}\n${mail.text}\n`);
    return false;
  }
  try {
    await t.sendMail({ from, ...mail });
    return true;
  } catch (err) {
    console.error("[email] failed to send:", err);
    return false;
  }
}

/** What the admin dashboard shows about email (no passwords). */
export async function mailStatus() {
  return {
    configured: Boolean(process.env.SMTP_HOST),
    host: process.env.SMTP_HOST || "",
    user: process.env.SMTP_USER || "",
    from: process.env.MAIL_FROM || "Ammos Makenzy Beach <info@ammos.eu>",
    to: await adminRecipients(),
  };
}

/** Checks the SMTP login and sends a test email. Returns the real error so the admin can fix settings. */
export async function sendTestMail(to: string[]): Promise<{ ok: boolean; error?: string }> {
  const t = getTransporter();
  if (!t) return { ok: false, error: "Email is not set up yet: SMTP_HOST is empty in the .env file." };
  try {
    await t.verify();
    await t.sendMail({
      from: process.env.MAIL_FROM || "Ammos Makenzy Beach <info@ammos.eu>",
      to,
      subject: "Test email from the Ammos website",
      text: "It works! Booking and contact form emails from ammos.eu will arrive like this one.",
      html: emailLayout("It works!", paragraph("Booking and contact form emails from the website will arrive like this one.")),
    });
    return { ok: true };
  } catch (err) {
    const e = err as { code?: string; response?: string; message?: string };
    const hint =
      e.code === "EAUTH"
        ? "Login failed — check SMTP_USER and SMTP_PASS (for Gmail use an App Password)."
        : e.code === "ESOCKET" || e.code === "ECONNECTION" || e.code === "ETIMEDOUT"
          ? "Could not connect — check SMTP_HOST, SMTP_PORT and SMTP_SECURE (465 = true, 587 = false)."
          : "";
    return { ok: false, error: [hint, e.response || e.message].filter(Boolean).join(" ") };
  }
}

/* ───────────── templates ───────────── */

export function escapeHtml(s: unknown) {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/** Branded HTML email (cyan + midnight, works in all mail apps). */
export function emailLayout(title: string, bodyHtml: string) {
  const logo = siteUrl("/images/logo.png");
  return `<!doctype html><html><body style="margin:0;background:#f3f5fe;font-family:Arial,Helvetica,sans-serif;color:#0f1119;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f3f5fe;padding:24px 0;"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:12px;overflow:hidden;">
      <tr><td style="background:#0f1119;padding:28px;text-align:center;"><img src="${logo}" alt="ammos" width="180" style="display:inline-block;"></td></tr>
      <tr><td style="padding:32px 32px 8px;"><h1 style="margin:0 0 16px;font-size:22px;letter-spacing:1px;text-transform:uppercase;color:#0f1119;">${escapeHtml(title)}</h1>${bodyHtml}</td></tr>
      <tr><td style="padding:24px 32px 32px;font-size:12px;color:#6f8289;border-top:1px solid #e6ebed;">Ammos Makenzy Beach · Makenzy Beach, Larnaca, Cyprus · +357 24 828844 · <a href="${siteUrl()}" style="color:#157f8f;">ammos.eu</a></td></tr>
    </table>
    <div style="height:6px;max-width:600px;background:#b7d44a;"></div>
  </td></tr></table></body></html>`;
}

/** Key/value table for notification emails. */
export function detailsTable(rows: [string, unknown][]) {
  const tr = rows
    .filter(([, v]) => v !== "" && v !== null && v !== undefined)
    .map(
      ([k, v]) =>
        `<tr><td style="padding:8px 12px 8px 0;font-size:13px;color:#6f8289;vertical-align:top;white-space:nowrap;">${escapeHtml(k)}</td><td style="padding:8px 0;font-size:15px;color:#0f1119;">${escapeHtml(v).replace(/\n/g, "<br>")}</td></tr>`,
    )
    .join("");
  return `<table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;border-collapse:collapse;margin:8px 0 16px;">${tr}</table>`;
}

export function paragraph(text: string) {
  return `<p style="margin:0 0 14px;font-size:15px;line-height:1.6;color:#45585f;">${escapeHtml(text)}</p>`;
}

export function button(href: string, label: string) {
  return `<p style="margin:20px 0;"><a href="${escapeHtml(href)}" style="display:inline-block;background:#3ec6d8;color:#0f1119;text-decoration:none;padding:12px 24px;border-radius:999px;font-size:13px;letter-spacing:1px;text-transform:uppercase;font-weight:bold;">${escapeHtml(label)}</a></p>`;
}
