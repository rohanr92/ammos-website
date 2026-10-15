import "server-only";
import { z } from "zod";
import { and, asc, desc, eq, ilike, ne, or, sql, type SQL } from "drizzle-orm";
import type { PgColumn, PgTable } from "drizzle-orm/pg-core";
import { db, schema } from "@/lib/db";
import { cyprusLocalToDate, dateToCyprusLocal, slugify } from "@/lib/utils";
import { RESOURCE_MAP, type AdminField, type ResourceDef } from "@/lib/admin/resources";

type AnyTable = PgTable & { id: PgColumn };

export const TABLES: Record<string, AnyTable> = {
  events: schema.events,
  "menu-items": schema.menuItems,
  "menu-categories": schema.menuCategories,
  gallery: schema.galleryImages,
  news: schema.posts,
  reviews: schema.reviews,
  redirects: schema.redirects,
};

export function getResource(key: string) {
  const def = RESOURCE_MAP[key];
  const table = TABLES[key];
  if (!def || !table) return null;
  return { def, table };
}

/* ───────────── validation: form values → database values ───────────── */

const mediaPath = /^(\/[\w\-./%]*|https?:\/\/\S+)$/;

function fieldSchema(f: AdminField): z.ZodTypeAny {
  const req = (msg = `${f.label} is required`) => (s: z.ZodString) => (f.required ? s.min(1, msg) : s);
  switch (f.type) {
    case "text":
    case "textarea":
    case "richtext":
    case "slug": {
      const max = f.max ?? (f.type === "richtext" ? 50000 : f.type === "textarea" ? 5000 : 300);
      return req()(z.string().trim().max(max, `${f.label} is too long`)).default("");
    }
    case "email":
      return z
        .string()
        .trim()
        .max(200)
        .refine((v) => !v || /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(v), `${f.label} is not a valid email`)
        .default("");
    case "url":
      return z
        .string()
        .trim()
        .max(1000)
        .refine((v) => !v || /^(https?:\/\/|\/)/.test(v), `${f.label} must start with https:// or /`)
        .default("");
    case "image":
    case "video":
      return req(`Please add a ${f.type === "image" ? "photo" : "video"}`)(z.string().trim().max(1000))
        .refine((v) => !v || mediaPath.test(v), `${f.label}: not a valid file link`)
        .default("");
    case "images":
      return z
        .array(z.string().trim().max(1000).refine((v) => mediaPath.test(v), `${f.label}: not a valid file link`))
        .max(40, `${f.label}: 40 photos maximum`)
        .optional()
        .transform((v) => (v ?? []).filter(Boolean));
    case "number":
      return z
        .union([z.string(), z.number(), z.null()])
        .optional()
        .transform((v, ctx) => {
          if (v === "" || v === null || v === undefined) {
            if (f.required) ctx.addIssue({ code: "custom", message: `${f.label} is required` });
            return null;
          }
          const n = Number(v);
          if (!Number.isFinite(n)) {
            ctx.addIssue({ code: "custom", message: `${f.label} must be a number` });
            return null;
          }
          return Math.round(n);
        });
    case "price":
      return z
        .union([z.string(), z.number()])
        .transform((v, ctx) => {
          const n = Number(String(v).replace(",", ".").replace(/[^\d.]/g, ""));
          if (!Number.isFinite(n) || n < 0) {
            ctx.addIssue({ code: "custom", message: `${f.label} must be a positive number` });
            return "0";
          }
          return n.toFixed(2);
        });
    case "checkbox":
      return z
        .union([z.boolean(), z.string()])
        .optional()
        .transform((v) => v === true || v === "true" || v === "on" || v === "yes");
    case "datetime":
      return z
        .string()
        .optional()
        .transform((v, ctx) => {
          if (!v) {
            if (f.required) ctx.addIssue({ code: "custom", message: `${f.label} is required` });
            return null;
          }
          const d = cyprusLocalToDate(v);
          if (!d) ctx.addIssue({ code: "custom", message: `${f.label} is not a valid date` });
          return d;
        });
    case "relation":
      return z.string().uuid(`Please choose a ${f.label.toLowerCase()}`);
    case "select":
      return z.string().refine((v) => !f.options || f.options.some((o) => o.value === v), `${f.label}: invalid choice`);
    default:
      return z.any();
  }
}

export function parseInput(def: ResourceDef, input: unknown) {
  const shape: Record<string, z.ZodTypeAny> = {};
  for (const f of def.fields) shape[f.name] = fieldSchema(f);
  const values = z.object(shape).parse(input) as Record<string, any>;

  // tidy-ups per resource
  if ("slug" in values) {
    const base = values.slug || values.title || values.name || "";
    values.slug = slugify(String(base)) || `item-${Date.now()}`;
  }
  if (def.key === "events" && values.endsAt && values.startsAt && values.endsAt < values.startsAt) {
    throw new z.ZodError([{ code: "custom", path: ["endsAt"], message: "End time must be after the start time", input: values.endsAt }]);
  }
  if (def.key === "reviews") values.rating = Math.min(5, Math.max(1, values.rating ?? 5));
  if (def.key === "redirects") {
    const from = String(values.fromPath).trim().toLowerCase().replace(/\/+$/, "");
    values.fromPath = from.startsWith("/") ? from : `/${from}`;
    if (values.fromPath === "/" || values.fromPath.startsWith("/admin") || values.fromPath.startsWith("/api")) {
      throw new z.ZodError([{ code: "custom", path: ["fromPath"], message: "This path cannot be redirected", input: from }]);
    }
    const to = String(values.toPath).trim();
    values.toPath = /^https?:\/\//.test(to) || to.startsWith("/") ? to : `/${to}`;
  }
  for (const k of ["sortOrder"]) if (k in values && values[k] === null) values[k] = 0;
  return values;
}

/** Database row → values for the edit form (dates as Cyprus local time, etc). */
export function toFormValues(def: ResourceDef, row: Record<string, any> | null) {
  const out: Record<string, unknown> = { ...def.defaults };
  if (!row) {
    for (const f of def.fields) {
      if (f.type === "datetime" && f.required && !out[f.name]) out[f.name] = "";
    }
    return out;
  }
  for (const f of def.fields) {
    const v = row[f.name];
    if (f.type === "datetime") out[f.name] = v ? dateToCyprusLocal(v) : "";
    else if (f.type === "number") out[f.name] = v === null || v === undefined ? "" : String(v);
    else if (f.type === "checkbox") out[f.name] = Boolean(v);
    else if (f.type === "images") out[f.name] = Array.isArray(v) ? v : [];
    else out[f.name] = v ?? "";
  }
  return out;
}

/* ───────────── list queries ───────────── */

export async function listRows(key: string, opts: { q?: string; filter?: string } = {}) {
  const res = getResource(key);
  if (!res) return [];
  const { def, table } = res;
  const t = table as unknown as Record<string, PgColumn>;
  const where: SQL[] = [];
  if (opts.q) {
    const term = `%${opts.q.replace(/[%_]/g, "\\$&")}%`;
    const conds = def.searchable.map((c) => ilike(t[c], term));
    if (conds.length) where.push(or(...conds)!);
  }

  if (key === "events") {
    const booked = sql<number>`(select coalesce(sum(${schema.bookings.guests}),0)::int from ${schema.bookings} where ${schema.bookings.eventId} = ${schema.events.id} and ${schema.bookings.status} <> 'cancelled')`;
    if (opts.filter === "upcoming") where.push(sql`${schema.events.startsAt} >= now() - interval '12 hours'`);
    if (opts.filter === "past") where.push(sql`${schema.events.startsAt} < now() - interval '12 hours'`);
    return db
      .select({ row: schema.events, bookingCount: booked })
      .from(schema.events)
      .where(where.length ? and(...where) : undefined)
      .orderBy(opts.filter === "upcoming" ? asc(schema.events.startsAt) : desc(schema.events.startsAt))
      .then((r) => r.map((x) => ({ ...x.row, bookingCount: x.bookingCount })));
  }
  if (key === "menu-items") {
    if (opts.filter) where.push(eq(schema.menuItems.categoryId, opts.filter));
    return db
      .select({ row: schema.menuItems, categoryName: schema.menuCategories.name })
      .from(schema.menuItems)
      .innerJoin(schema.menuCategories, eq(schema.menuItems.categoryId, schema.menuCategories.id))
      .where(where.length ? and(...where) : undefined)
      .orderBy(asc(schema.menuCategories.sortOrder), asc(schema.menuItems.sortOrder), asc(schema.menuItems.name))
      .then((r) => r.map((x) => ({ ...x.row, categoryName: x.categoryName })));
  }
  if (key === "menu-categories") {
    const count = sql<number>`(select count(*)::int from ${schema.menuItems} where ${schema.menuItems.categoryId} = ${schema.menuCategories.id})`;
    return db
      .select({ row: schema.menuCategories, itemCount: count })
      .from(schema.menuCategories)
      .where(where.length ? and(...where) : undefined)
      .orderBy(asc(schema.menuCategories.sortOrder), asc(schema.menuCategories.name))
      .then((r) => r.map((x) => ({ ...x.row, itemCount: x.itemCount })));
  }
  const order =
    key === "news"
      ? [desc(schema.posts.publishedAt)]
      : key === "redirects"
        ? [asc(schema.redirects.fromPath)]
        : [asc(t.sortOrder), desc(t.createdAt)];
  return db
    .select()
    .from(table)
    .where(where.length ? and(...where) : undefined)
    .orderBy(...order)
    .limit(1000) as Promise<Record<string, any>[]>;
}

export async function getRow(key: string, id: string) {
  const res = getResource(key);
  if (!res || !/^[0-9a-f-]{36}$/i.test(id)) return null;
  const [row] = await db.select().from(res.table).where(eq(res.table.id, id)).limit(1);
  return (row as Record<string, any>) ?? null;
}

export async function menuCategoryOptions() {
  const cats = await db
    .select({ id: schema.menuCategories.id, name: schema.menuCategories.name, section: schema.menuCategories.section })
    .from(schema.menuCategories)
    .orderBy(asc(schema.menuCategories.sortOrder));
  return cats.map((c) => ({ value: c.id, label: `${c.section} › ${c.name}` }));
}

/** Makes sure a slug is unique by adding -2, -3… */
export async function uniqueSlug(key: string, slug: string, exceptId?: string) {
  const res = getResource(key);
  if (!res) return slug;
  const t = res.table as unknown as Record<string, PgColumn>;
  if (!t.slug) return slug;
  let candidate = slug;
  for (let i = 2; i < 200; i++) {
    const conds = [eq(t.slug, candidate)];
    if (exceptId) conds.push(ne(res.table.id, exceptId));
    const [hit] = await db.select({ id: res.table.id }).from(res.table).where(and(...conds)).limit(1);
    if (!hit) return candidate;
    candidate = `${slug}-${i}`;
  }
  return `${slug}-${Date.now()}`;
}
