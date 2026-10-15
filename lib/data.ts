import "server-only";
import { cache } from "react";
import { and, asc, desc, eq, gte, lt, ne, sql, inArray } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { cyprusDayKey, cyprusLocalToDate } from "@/lib/utils";

const { events, bookings, menuCategories, menuItems, galleryImages, posts, reviews } = schema;

/** Midnight today in Cyprus — events from today onwards count as "upcoming". */
export function startOfTodayCyprus() {
  return cyprusLocalToDate(`${cyprusDayKey(new Date())}T00:00`) ?? new Date();
}

/* ───────────── Events ───────────── */

/**
 * Homepage "our events" slider: events marked "Show on homepage" —
 * upcoming ones first (soonest first), then the most recent past ones (with an "Event passed" tag).
 */
export async function getHomeEvents(limit = 8) {
  const today = startOfTodayCyprus();
  const base = and(eq(events.published, true), eq(events.featured, true));
  const upcoming = await db.select().from(events).where(and(base, gte(events.startsAt, today))).orderBy(asc(events.startsAt)).limit(limit);
  if (upcoming.length >= limit) return upcoming;
  const past = await db
    .select()
    .from(events)
    .where(and(base, lt(events.startsAt, today)))
    .orderBy(desc(events.startsAt))
    .limit(limit - upcoming.length);
  return [...upcoming, ...past];
}

export async function listEvents(opts: { show: "upcoming" | "past"; category?: string }) {
  const today = startOfTodayCyprus();
  const where = [eq(events.published, true), opts.show === "past" ? lt(events.startsAt, today) : gte(events.startsAt, today)];
  if (opts.category) where.push(eq(events.category, opts.category));
  return db
    .select()
    .from(events)
    .where(and(...where))
    .orderBy(opts.show === "past" ? desc(events.startsAt) : asc(events.startsAt))
    .limit(120);
}

export async function getEventCategories() {
  const rows = await db
    .selectDistinct({ category: events.category })
    .from(events)
    .where(eq(events.published, true))
    .orderBy(asc(events.category));
  return rows.map((r) => r.category).filter(Boolean);
}

export const getEventBySlug = cache(async (slug: string) => {
  return db.query.events.findFirst({ where: and(eq(events.slug, slug), eq(events.published, true)) });
});

export async function getEventsBetween(from: Date, to: Date) {
  return db
    .select()
    .from(events)
    .where(and(eq(events.published, true), gte(events.startsAt, from), lt(events.startsAt, to)))
    .orderBy(asc(events.startsAt));
}

export async function getOtherUpcomingEvents(excludeId: string, limit = 3) {
  return db
    .select()
    .from(events)
    .where(and(eq(events.published, true), ne(events.id, excludeId), gte(events.startsAt, startOfTodayCyprus())))
    .orderBy(asc(events.startsAt))
    .limit(limit);
}

/** Guests already booked (pending + confirmed) for an event. */
export async function getBookedGuests(eventId: string) {
  const [row] = await db
    .select({ total: sql<number>`coalesce(sum(${bookings.guests}), 0)::int` })
    .from(bookings)
    .where(and(eq(bookings.eventId, eventId), ne(bookings.status, "cancelled")));
  return row?.total ?? 0;
}

/* ───────────── Menu ───────────── */

export type MenuCategoryWithItems = typeof menuCategories.$inferSelect & { items: (typeof menuItems.$inferSelect)[] };

export async function getFullMenu(): Promise<MenuCategoryWithItems[]> {
  const cats = await db
    .select()
    .from(menuCategories)
    .where(eq(menuCategories.published, true))
    .orderBy(asc(menuCategories.sortOrder), asc(menuCategories.name));
  if (!cats.length) return [];
  const items = await db
    .select()
    .from(menuItems)
    .where(and(eq(menuItems.published, true), inArray(menuItems.categoryId, cats.map((c) => c.id))))
    .orderBy(asc(menuItems.sortOrder), asc(menuItems.name));
  return cats
    .map((c) => ({ ...c, items: items.filter((i) => i.categoryId === c.id) }))
    .filter((c) => c.items.length > 0);
}

/** Categories that have dishes marked "show on homepage" (max 4 tabs). */
export async function getHomeMenu() {
  const rows = await db
    .select({ item: menuItems, category: menuCategories })
    .from(menuItems)
    .innerJoin(menuCategories, eq(menuItems.categoryId, menuCategories.id))
    .where(and(eq(menuItems.featured, true), eq(menuItems.published, true), eq(menuCategories.published, true)))
    .orderBy(asc(menuCategories.sortOrder), asc(menuItems.sortOrder));
  const tabs: { name: string; slug: string; items: (typeof menuItems.$inferSelect)[] }[] = [];
  for (const { item, category } of rows) {
    let tab = tabs.find((t) => t.slug === category.slug);
    if (!tab) {
      if (tabs.length >= 4) continue;
      tab = { name: category.name, slug: category.slug, items: [] };
      tabs.push(tab);
    }
    if (tab.items.length < 6) tab.items.push(item);
  }
  return tabs;
}

/* ───────────── Gallery, news, reviews ───────────── */

export async function getGallery(opts: { homeOnly?: boolean } = {}) {
  const where = [eq(galleryImages.published, true)];
  if (opts.homeOnly) where.push(eq(galleryImages.showOnHome, true));
  return db
    .select()
    .from(galleryImages)
    .where(and(...where))
    .orderBy(asc(galleryImages.sortOrder), desc(galleryImages.createdAt))
    .limit(opts.homeOnly ? 12 : 500);
}

export async function listPosts(limit = 60) {
  return db
    .select()
    .from(posts)
    .where(and(eq(posts.published, true), lt(posts.publishedAt, new Date(Date.now() + 60_000))))
    .orderBy(desc(posts.publishedAt))
    .limit(limit);
}

export const getPostBySlug = cache(async (slug: string) => {
  return db.query.posts.findFirst({ where: and(eq(posts.slug, slug), eq(posts.published, true)) });
});

export async function getReviews() {
  return db
    .select()
    .from(reviews)
    .where(eq(reviews.published, true))
    .orderBy(asc(reviews.sortOrder), desc(reviews.createdAt))
    .limit(24);
}
