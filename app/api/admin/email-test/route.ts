import { errorJson, json, rateLimit, withAdmin } from "@/lib/http";
import { mailStatus, sendTestMail } from "@/lib/mailer";

export const runtime = "nodejs";

/** POST /api/admin/email-test → checks the SMTP settings and sends a test email to MAIL_TO. */
export const POST = withAdmin(async (_req, _ctx, user) => {
  if (!rateLimit(`email-test:${user.id}`, 5, 10 * 60_000).ok) return errorJson("Please wait a few minutes before testing again.", 429);
  const status = await mailStatus();
  const result = await sendTestMail(status.to);
  if (!result.ok) return errorJson(result.error || "Email test failed.", 400);
  return json({ ok: true, to: status.to });
});
