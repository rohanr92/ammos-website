/** Database connection for command-line scripts (migrate, seed, create-admin). */
import "dotenv/config";
import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import * as schema from "../lib/db/schema";

if (!process.env.DATABASE_URL) {
  console.error("\n✖ DATABASE_URL is not set. Copy .env.example to .env and fill it in.\n");
  process.exit(1);
}

export const pool = new Pool({ connectionString: process.env.DATABASE_URL, max: 2 });
export const db = drizzle(pool, { schema });
export { schema };
