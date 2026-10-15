import { SignJWT, jwtVerify, type JWTPayload } from "jose";

/**
 * JWT helpers (no database access, so they can also run in proxy.ts).
 * Tokens are signed with HS256 using JWT_SECRET and live in an
 * httpOnly + SameSite=Strict cookie — JavaScript in the browser can never read them.
 */

export const SESSION_COOKIE = "ammos_session";
export const SESSION_MAX_AGE = 60 * 60 * 8; // 8 hours
const ISSUER = "ammos.eu";
const AUDIENCE = "ammos-admin";

export type SessionClaims = JWTPayload & { sub: string; ver: number; role: string };

function key() {
  const secret = process.env.JWT_SECRET;
  if (!secret || secret.length < 32) {
    throw new Error("JWT_SECRET is missing or shorter than 32 characters. Set it in your .env file.");
  }
  return new TextEncoder().encode(secret);
}

export async function signSession(user: { id: string; tokenVersion: number; role: string }) {
  return new SignJWT({ ver: user.tokenVersion, role: user.role })
    .setProtectedHeader({ alg: "HS256", typ: "JWT" })
    .setSubject(user.id)
    .setIssuer(ISSUER)
    .setAudience(AUDIENCE)
    .setIssuedAt()
    .setExpirationTime(`${SESSION_MAX_AGE}s`)
    .sign(key());
}

export async function verifySession(token: string | undefined | null): Promise<SessionClaims | null> {
  if (!token) return null;
  try {
    const { payload } = await jwtVerify(token, key(), {
      issuer: ISSUER,
      audience: AUDIENCE,
      algorithms: ["HS256"],
    });
    if (typeof payload.sub !== "string" || typeof payload.ver !== "number") return null;
    return payload as SessionClaims;
  } catch {
    return null;
  }
}

export function sessionCookieOptions(maxAge = SESSION_MAX_AGE) {
  return {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "strict" as const,
    path: "/",
    maxAge,
  };
}
