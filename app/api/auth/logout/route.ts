import { SESSION_COOKIE, sessionCookieOptions } from "@/lib/jwt";
import { json } from "@/lib/http";

export async function POST() {
  const res = json({ ok: true });
  res.cookies.set(SESSION_COOKIE, "", sessionCookieOptions(0));
  return res;
}
