import type { MetadataRoute } from "next";
import { desc, eq } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { siteUrl } from "@/lib/utils";

export const revalidate = 3600;

/** sitemap.xml for Google — lists every public page, event and story. */
export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const now = new Date();
  const pages: MetadataRoute.Sitemap = [
    { url: siteUrl("/"), changeFrequency: "daily", priority: 1, lastModified: now },
    { url: siteUrl("/events"), changeFrequency: "daily", priority: 0.9, lastModified: now },
    { url: siteUrl("/events/calendar"), changeFrequency: "daily", priority: 0.6 },
    { url: siteUrl("/menu"), changeFrequency: "weekly", priority: 0.9 },
    { url: siteUrl("/our-story"), changeFrequency: "monthly", priority: 0.7 },
    { url: siteUrl("/gallery"), changeFrequency: "weekly", priority: 0.6 },
    { url: siteUrl("/news"), changeFrequency: "weekly", priority: 0.6 },
    { url: siteUrl("/private-events"), changeFrequency: "monthly", priority: 0.7 },
    { url: siteUrl("/contact"), changeFrequency: "monthly", priority: 0.8 },
    { url: siteUrl("/careers"), changeFrequency: "monthly", priority: 0.3 },
    { url: siteUrl("/house-rules"), changeFrequency: "yearly", priority: 0.2 },
    { url: siteUrl("/privacy-policy"), changeFrequency: "yearly", priority: 0.1 },
    { url: siteUrl("/legal-notice"), changeFrequency: "yearly", priority: 0.1 },
  ];
  try {
    const [events, posts] = await Promise.all([
      db.select({ slug: schema.events.slug, updatedAt: schema.events.updatedAt, image: schema.events.image }).from(schema.events).where(eq(schema.events.published, true)).orderBy(desc(schema.events.startsAt)).limit(1000),
      db.select({ slug: schema.posts.slug, updatedAt: schema.posts.updatedAt, image: schema.posts.image }).from(schema.posts).where(eq(schema.posts.published, true)).limit(1000),
    ]);
    const img = (src: string) => (src ? [/^https?:/.test(src) ? src : siteUrl(src)] : undefined);
    return [
      ...pages,
      ...events.map((e) => ({ url: siteUrl(`/events/${e.slug}`), lastModified: e.updatedAt, changeFrequency: "weekly" as const, priority: 0.7, images: img(e.image) })),
      ...posts.map((p) => ({ url: siteUrl(`/news/${p.slug}`), lastModified: p.updatedAt, changeFrequency: "monthly" as const, priority: 0.5, images: img(p.image) })),
    ];
  } catch {
    return pages;
  }
}
