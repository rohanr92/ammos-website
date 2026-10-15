/**
 * Creates the database named in DATABASE_URL if it does not exist yet.
 * Run:  npm run db:create
 */
import "dotenv/config";
import { Client } from "pg";

async function main() {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error("DATABASE_URL is not set in .env");
  const target = new URL(url);
  const dbName = decodeURIComponent(target.pathname.replace(/^\//, ""));
  if (!/^[\w-]+$/.test(dbName)) throw new Error(`Database name "${dbName}" should only contain letters, numbers, - and _`);

  const admin = new URL(url);
  admin.pathname = "/postgres";
  const client = new Client({ connectionString: admin.toString() });
  await client.connect();
  const { rowCount } = await client.query("select 1 from pg_database where datname = $1", [dbName]);
  if (rowCount) console.log(`• Database "${dbName}" already exists`);
  else {
    await client.query(`create database "${dbName}"`);
    console.log(`✔ Database "${dbName}" created`);
  }
  await client.end();
}

main().catch((err) => {
  console.error("✖", err.message || err);
  console.error("  Is PostgreSQL running, and are the user/password in DATABASE_URL correct?");
  process.exitCode = 1;
});
