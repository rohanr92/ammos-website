import "server-only";
import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import * as schema from "./schema";

/**
 * One shared connection pool for the whole app.
 * In development Next.js reloads modules often, so we keep the pool on globalThis.
 */
const globalForDb = globalThis as unknown as { __ammosPool?: Pool };

function createPool() {
  if (!process.env.DATABASE_URL) {
    throw new Error("DATABASE_URL is not set. Copy .env.example to .env and fill it in.");
  }
  return new Pool({ connectionString: process.env.DATABASE_URL, max: 10 });
}

export const pool = globalForDb.__ammosPool ?? createPool();
if (process.env.NODE_ENV !== "production") globalForDb.__ammosPool = pool;

export const db = drizzle(pool, { schema });
export { schema };
