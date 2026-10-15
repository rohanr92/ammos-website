import { z } from "zod";
import { asc } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { hashPassword, passwordProblem } from "@/lib/auth";
import { errorJson, json, withAdmin } from "@/lib/http";

const createSchema = z.object({
  email: z.string().trim().toLowerCase().email("Please enter a valid email"),
  name: z.string().trim().max(100).default(""),
  password: z.string().max(200),
  role: z.enum(["owner", "editor"]).default("editor"),
  notify: z.boolean().default(true),
});

export const GET = withAdmin(
  async () => {
    const users = await db
      .select({ id: schema.adminUsers.id, email: schema.adminUsers.email, name: schema.adminUsers.name, role: schema.adminUsers.role, notify: schema.adminUsers.notify, lastLoginAt: schema.adminUsers.lastLoginAt })
      .from(schema.adminUsers)
      .orderBy(asc(schema.adminUsers.createdAt));
    return json({ ok: true, users });
  },
  { ownerOnly: true },
);

export const POST = withAdmin(
  async (req) => {
    const data = createSchema.parse(await req.json());
    const problem = passwordProblem(data.password);
    if (problem) return errorJson(problem, 422);
    const [user] = await db
      .insert(schema.adminUsers)
      .values({ email: data.email, name: data.name || data.email, role: data.role, notify: data.notify, passwordHash: await hashPassword(data.password) })
      .returning({ id: schema.adminUsers.id });
    return json({ ok: true, id: user.id }, 201);
  },
  { ownerOnly: true },
);
