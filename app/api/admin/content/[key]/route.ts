import { z } from "zod";
import { db, schema } from "@/lib/db";
import { errorJson, json, withAdmin } from "@/lib/http";
import { SECTION_MAP, type FieldDef } from "@/lib/content-schema";
import { refreshSite } from "@/lib/revalidate";

type Ctx = { params: Promise<{ key: string }> };

const media = /^(\/[\w\-./%]*|https?:\/\/\S+)?$/;

/** Validates a content field (lists are validated item by item). */
function fieldSchema(f: FieldDef): z.ZodTypeAny {
  switch (f.type) {
    case "list": {
      const item: Record<string, z.ZodTypeAny> = {};
      for (const sub of f.fields) item[sub.name] = fieldSchema(sub);
      return z.array(z.object(item)).max(60).default([]);
    }
    case "checkbox":
      return z.boolean().default(false);
    case "number":
      return z.union([z.number(), z.string()]).transform((v) => (v === "" ? "" : String(v)));
    case "image":
    case "video":
      return z.string().trim().max(1000).refine((v) => media.test(v), `${f.label}: not a valid file link`).default("");
    case "url":
      return z.string().trim().max(1000).refine((v) => !v || /^(https?:\/\/|\/|mailto:|tel:)/.test(v), `${f.label} must start with https://`).default("");
    case "richtext":
      return z.string().max(50000).default("");
    case "textarea":
      return z.string().max(5000).default("");
    default:
      return z.string().trim().max(1000).default("");
  }
}

/** PUT /api/admin/content/<section>  → save texts & images of one section */
export const PUT = withAdmin<Ctx>(async (req, ctx) => {
  const { key } = await ctx.params;
  const def = SECTION_MAP[key];
  if (!def) return errorJson("Unknown section", 404);
  const shape: Record<string, z.ZodTypeAny> = {};
  for (const f of def.fields) shape[f.name] = fieldSchema(f);
  const data = z.object(shape).parse(await req.json());
  await db
    .insert(schema.siteContent)
    .values({ key, data })
    .onConflictDoUpdate({ target: schema.siteContent.key, set: { data, updatedAt: new Date() } });
  refreshSite();
  return json({ ok: true });
});

/** DELETE → reset this section to the original design texts */
export const DELETE = withAdmin<Ctx>(async (_req, ctx) => {
  const { key } = await ctx.params;
  if (!SECTION_MAP[key]) return errorJson("Unknown section", 404);
  const { eq } = await import("drizzle-orm");
  await db.delete(schema.siteContent).where(eq(schema.siteContent.key, key));
  refreshSite();
  return json({ ok: true });
});
