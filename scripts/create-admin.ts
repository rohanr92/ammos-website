/**
 * Create an admin account, or reset the password of an existing one.
 * Run:  npm run admin:create
 * (You will be asked for email, name and password in the terminal.)
 */
import { createInterface } from "node:readline/promises";
import { stdin as input, stdout as output } from "node:process";
import bcrypt from "bcryptjs";
import { eq, sql } from "drizzle-orm";
import { db, pool, schema } from "./db";

async function main() {
  const rl = createInterface({ input, output });
  const email = (await rl.question("Admin email: ")).trim().toLowerCase();
  const name = (await rl.question("Name (optional): ")).trim();
  const password = await rl.question("Password (min 12 characters, letters + numbers): ");
  rl.close();

  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) throw new Error("That email does not look valid.");
  if (password.length < 12 || !/[a-z]/i.test(password) || !/\d/.test(password)) {
    throw new Error("Password must be at least 12 characters and contain letters and numbers.");
  }

  const hash = await bcrypt.hash(password, 12);
  const existing = await db.query.adminUsers.findFirst({ where: eq(schema.adminUsers.email, email) });
  if (existing) {
    await db
      .update(schema.adminUsers)
      .set({ passwordHash: hash, tokenVersion: sql`${schema.adminUsers.tokenVersion} + 1`, failedLogins: 0, lockedUntil: null, ...(name ? { name } : {}) })
      .where(eq(schema.adminUsers.id, existing.id));
    console.log(`✔ Password reset for ${email}. All old logins were signed out.`);
  } else {
    const count = await db.$count(schema.adminUsers);
    await db.insert(schema.adminUsers).values({ email, name: name || email, passwordHash: hash, role: count === 0 ? "owner" : "editor" });
    console.log(`✔ Admin created: ${email} (${count === 0 ? "owner" : "editor"})`);
  }
}

main()
  .catch((err) => {
    console.error("✖", err.message || err);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
