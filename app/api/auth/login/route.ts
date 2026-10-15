import type { NextRequest } from "next/server";
import { z } from "zod";
import { eq } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { checkPassword } from "@/lib/auth";
import { SESSION_COOKIE, sessionCookieOptions, signSession } from "@/lib/jwt";
import { clientIp, errorJson, handleError, json, rateLimit, sameOrigin } from "@/lib/http";

const MAX_FAILED = 5; // wrong passwords before the account is locked
const LOCK_MINUTES = 15;
const GENERIC = "Wrong email or password.";

const loginSchema = z.object({
  email: z.string().trim().toLowerCase().max(200),
  password: z.string().min(1).max(200),
});

export async function POST(req: NextRequest) {
  try {
    if (!sameOrigin(req)) return errorJson("Request blocked.", 403);
    const ip = clientIp(req);
    const limit = rateLimit(`login:${ip}`, 10, 15 * 60 * 1000);
    if (!limit.ok) return errorJson(`Too many attempts. Try again in ${Math.ceil(limit.retryAfter / 60)} minutes.`, 429);

    const { email, password } = loginSchema.parse(await req.json());
    const user = await db.query.adminUsers.findFirst({ where: eq(schema.adminUsers.email, email) });

    if (user?.lockedUntil && user.lockedUntil > new Date()) {
      await checkPassword(password, null); // same timing as a normal attempt
      const mins = Math.ceil((user.lockedUntil.getTime() - Date.now()) / 60000);
      return errorJson(`This account is locked after too many wrong passwords. Try again in ${mins} minute${mins === 1 ? "" : "s"}.`, 423);
    }

    const valid = await checkPassword(password, user?.passwordHash);
    if (!user || !valid) {
      if (user) {
        const failed = user.failedLogins + 1;
        await db
          .update(schema.adminUsers)
          .set({ failedLogins: failed >= MAX_FAILED ? 0 : failed, lockedUntil: failed >= MAX_FAILED ? new Date(Date.now() + LOCK_MINUTES * 60000) : null })
          .where(eq(schema.adminUsers.id, user.id));
      }
      return errorJson(GENERIC, 401);
    }

    await db.update(schema.adminUsers).set({ failedLogins: 0, lockedUntil: null, lastLoginAt: new Date() }).where(eq(schema.adminUsers.id, user.id));
    const token = await signSession(user);
    const res = json({ ok: true, name: user.name });
    res.cookies.set(SESSION_COOKIE, token, sessionCookieOptions());
    return res;
  } catch (err) {
    return handleError(err);
  }
}
