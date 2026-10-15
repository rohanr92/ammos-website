import "server-only";
import { NextResponse, type NextRequest } from "next/server";
import { ZodError } from "zod";
import { getSessionUser, type SessionUser } from "@/lib/auth";

export function json(data: unknown, status = 200) {
  return NextResponse.json(data, { status, headers: { "Cache-Control": "no-store" } });
}

export function errorJson(message: string, status = 400, extra: Record<string, unknown> = {}) {
  return json({ ok: false, error: message, ...extra }, status);
}

export function clientIp(req: NextRequest | Request) {
  const h = req.headers;
  return (h.get("x-real-ip") || h.get("x-forwarded-for")?.split(",")[0] || "").trim().slice(0, 64);
}

/**
 * CSRF protection for state-changing requests: the browser must send an
 * Origin header that matches this site. (The session cookie is also
 * SameSite=Strict, so this is a second layer.)
 */
export function sameOrigin(req: NextRequest | Request) {
  const origin = req.headers.get("origin");
  if (!origin) return false;
  const host = req.headers.get("x-forwarded-host") || req.headers.get("host");
  try {
    return new URL(origin).host === host;
  } catch {
    return false;
  }
}

/* ── simple in-memory rate limiter (fine for one server process) ── */
const buckets = new Map<string, number[]>();
export function rateLimit(key: string, limit: number, windowMs: number) {
  const now = Date.now();
  const hits = (buckets.get(key) ?? []).filter((t) => now - t < windowMs);
  if (hits.length >= limit) {
    buckets.set(key, hits);
    return { ok: false, retryAfter: Math.ceil((windowMs - (now - hits[0])) / 1000) };
  }
  hits.push(now);
  buckets.set(key, hits);
  if (buckets.size > 5000) {
    for (const [k, v] of buckets) if (!v.some((t) => now - t < windowMs)) buckets.delete(k);
  }
  return { ok: true, retryAfter: 0 };
}

type AdminHandler<C> = (req: NextRequest, ctx: C, user: SessionUser) => Promise<Response>;

/**
 * Wraps every admin API route:
 *  1. valid JWT session (signature, expiry, not revoked)
 *  2. same-origin check for POST/PUT/PATCH/DELETE
 *  3. optional owner-only access
 *  4. friendly JSON errors
 */
export function withAdmin<C = unknown>(handler: AdminHandler<C>, opts: { ownerOnly?: boolean } = {}) {
  return async (req: NextRequest, ctx: C) => {
    try {
      if (req.method !== "GET" && req.method !== "HEAD" && !sameOrigin(req)) {
        return errorJson("Request blocked (origin check failed).", 403);
      }
      const user = await getSessionUser();
      if (!user) return errorJson("Your session has expired. Please log in again.", 401);
      if (opts.ownerOnly && user.role !== "owner") return errorJson("Only the owner account can do this.", 403);
      return await handler(req, ctx, user);
    } catch (err) {
      return handleError(err);
    }
  };
}

export function handleError(err: unknown) {
  if (err instanceof ZodError) {
    const first = err.issues[0];
    const field = first?.path?.join(".");
    const friendly = first?.message && !first.message.startsWith("Invalid input") ? first.message : `Please check the field "${field || "form"}"`;
    return errorJson(friendly, 422, { field });
  }
  const pgCode = (err as { code?: string; cause?: { code?: string } })?.code ?? (err as { cause?: { code?: string } })?.cause?.code;
  if (pgCode === "23505") return errorJson("This already exists (duplicate slug, email or link). Please change it.", 409);
  console.error("[api]", err);
  return errorJson("Something went wrong on the server.", 500);
}
