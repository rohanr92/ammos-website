import { z } from "zod";
import { eq, sql } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { checkPassword, hashPassword, passwordProblem } from "@/lib/auth";
import { SESSION_COOKIE, sessionCookieOptions, signSession } from "@/lib/jwt";
import { errorJson, json, rateLimit, withAdmin } from "@/lib/http";

const schemaBody = z.discriminatedUnion("action", [
  z.object({ action: z.literal("password"), currentPassword: z.string().max(200), newPassword: z.string().max(200) }),
  z.object({ action: z.literal("profile"), name: z.string().trim().min(1).max(100) }),
  z.object({ action: z.literal("logoutAll") }),
]);

/** POST /api/admin/account — change password, change name, or sign out all devices */
export const POST = withAdmin(async (req, _ctx, me) => {
  const body = schemaBody.parse(await req.json());
  const user = await db.query.adminUsers.findFirst({ where: eq(schema.adminUsers.id, me.id) });
  if (!user) return errorJson("Account not found", 404);

  if (body.action === "profile") {
    await db.update(schema.adminUsers).set({ name: body.name }).where(eq(schema.adminUsers.id, me.id));
    return json({ ok: true });
  }

  if (body.action === "password") {
    if (!rateLimit(`pw:${me.id}`, 5, 15 * 60 * 1000).ok) return errorJson("Too many attempts, try later.", 429);
    if (!(await checkPassword(body.currentPassword, user.passwordHash))) return errorJson("Your current password is wrong.", 400);
    const problem = passwordProblem(body.newPassword);
    if (problem) return errorJson(problem, 422);
    if (body.newPassword === body.currentPassword) return errorJson("The new password must be different.", 422);
    await db
      .update(schema.adminUsers)
      .set({ passwordHash: await hashPassword(body.newPassword), tokenVersion: sql`${schema.adminUsers.tokenVersion} + 1` })
      .where(eq(schema.adminUsers.id, me.id));
  } else {
    await db.update(schema.adminUsers).set({ tokenVersion: sql`${schema.adminUsers.tokenVersion} + 1` }).where(eq(schema.adminUsers.id, me.id));
  }

  // every other device is now signed out — give this browser a fresh token
  const fresh = await db.query.adminUsers.findFirst({ where: eq(schema.adminUsers.id, me.id) });
  const res = json({ ok: true });
  if (fresh) res.cookies.set(SESSION_COOKIE, await signSession(fresh), sessionCookieOptions());
  return res;
});
