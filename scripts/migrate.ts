/**
 * Creates / updates the database tables.
 * Run:  npm run db:migrate
 * Safe to run many times — only new changes are applied.
 */
import { migrate } from "drizzle-orm/node-postgres/migrator";
import { db, pool } from "./db";

async function main() {
  console.log("→ Applying database migrations…");
  await migrate(db, { migrationsFolder: "./drizzle" });
  console.log("✔ Database is up to date.");
}

main()
  .catch((err) => {
    console.error("✖ Migration failed:", err.message || err);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
