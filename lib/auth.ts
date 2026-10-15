import "server-only";
import bcrypt from "bcryptjs";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { eq } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { SESSION_COOKIE, verifySession } from "@/lib/jwt";
import type { AdminUser } from "@/lib/db/schema";

export type SessionUser = Pick<AdminUser, "id" | "email" | "name" | "role">;

const BCRYPT_ROUNDS = 12;
// Used when the email does not exist, so a wrong email takes as long as a wrong password.
const DUMMY_HASH = "$2b$12$j9m3gNEezmwI12FFfm1YxuASWL1mbyhsCoWleQr1T1cBjj0cUL9rW";

export function hashPassword(password: string) {
  return bcrypt.hash(password, BCRYPT_ROUNDS);
}

export async function checkPassword(password: string, hash: string | null | undefined) {
  return bcrypt.compare(password, hash || DUMMY_HASH);
}

/** Password rules for admin accounts. Returns an error message or null. */
export function passwordProblem(password: string): string | null {
  if (password.length < 12) return "Password must be at least 12 characters.";
  if (!/[a-z]/i.test(password) || !/\d/.test(password)) return "Password must contain letters and numbers.";
  if (password.length > 200) return "Password is too long.";
  return null;
}

/**
 * Reads the login cookie, verifies the JWT signature and expiry, then checks
 * the user still exists and the token was not revoked (tokenVersion).
 */
export async function getSessionUser(): Promise<SessionUser | null> {
  const store = await cookies();
  const claims = await verifySession(store.get(SESSION_COOKIE)?.value);
  if (!claims) return null;
  const user = await db.query.adminUsers.findFirst({ where: eq(schema.adminUsers.id, claims.sub) });
  if (!user || user.tokenVersion !== claims.ver) return null;
  return { id: user.id, email: user.email, name: user.name, role: user.role };
}

/** For admin pages: sends visitors without a valid session to the login page. */
export async function requireAdminPage(): Promise<SessionUser> {
  const user = await getSessionUser();
  if (!user) redirect("/admin/login");
  return user;
}
