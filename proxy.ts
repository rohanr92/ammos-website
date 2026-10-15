import { NextResponse, type NextRequest } from "next/server";
import { Pool } from "pg";
import { SESSION_COOKIE, verifySession } from "@/lib/jwt";

/**
 * Runs before every page request:
 *  1. Admin area: visitors without a valid login token are sent to /admin/login
 *  2. Short links / redirects managed in Admin → Redirects (e.g. /ourmenu → /menu)
 * (API routes check the login themselves, so they are not handled here.)
 */

type Rule = { to: string; permanent: boolean };
let rules: Map<string, Rule> = new Map();
let loadedAt = 0;
let pool: Pool | null = null;

async function getRules() {
  if (Date.now() - loadedAt < 60_000) return rules; // refresh every minute
  loadedAt = Date.now();
  try {
    pool ??= new Pool({ connectionString: process.env.DATABASE_URL, max: 1 });
    const { rows } = await pool.query<{ from_path: string; to_path: string; permanent: boolean }>(
      "select from_path, to_path, permanent from redirects",
    );
    rules = new Map(rows.map((r) => [normalise(r.from_path), { to: r.to_path, permanent: r.permanent }]));
  } catch (err) {
    console.error("[proxy] could not load redirects", err);
  }
  return rules;
}

function normalise(path: string) {
  const p = path.trim().toLowerCase().replace(/\/+$/, "");
  return p.startsWith("/") ? p : `/${p}`;
}

export async function proxy(req: NextRequest) {
  const { pathname } = req.nextUrl;

  // www.ammos.eu → ammos.eu (one address is better for Google)
  const host = req.headers.get("host") || "";
  if (host.startsWith("www.") && process.env.NODE_ENV === "production") {
    const url = req.nextUrl.clone();
    url.host = host.slice(4);
    url.port = "";
    url.protocol = "https:";
    return NextResponse.redirect(url, 308);
  }

  if (pathname.startsWith("/admin")) {
    const res = NextResponse.next();
    res.headers.set("X-Robots-Tag", "noindex, nofollow");
    res.headers.set("Cache-Control", "no-store");
    if (pathname === "/admin/login") return res;
    const session = await verifySession(req.cookies.get(SESSION_COOKIE)?.value);
    if (!session) {
      const url = req.nextUrl.clone();
      url.pathname = "/admin/login";
      url.search = pathname !== "/admin" ? `?next=${encodeURIComponent(pathname)}` : "";
      return NextResponse.redirect(url);
    }
    return res;
  }

  const map = await getRules();
  const rule = map.get(normalise(pathname) || "/");
  if (rule) {
    const target = /^https?:\/\//.test(rule.to) ? new URL(rule.to) : new URL(rule.to, req.url);
    // count the visit (fire and forget)
    pool?.query("update redirects set hits = hits + 1 where lower(from_path) = $1", [normalise(pathname)]).catch(() => {});
    return NextResponse.redirect(target, rule.permanent ? 308 : 307);
  }
  return NextResponse.next();
}

export const config = {
  // skip Next.js internals, API routes, uploaded files and static files (anything with a dot)
  matcher: ["/((?!_next/|api/|uploads/|images/|.*\\..*).*)"],
};
