import "server-only";
import { readdir, stat, unlink } from "node:fs/promises";
import path from "node:path";
import { db, schema } from "@/lib/db";
import { uploadRoot } from "@/lib/uploads";

export type MediaFile = {
  url: string; // what you paste into the website, e.g. /uploads/2026/10/sunset-a1b2c3.webp
  name: string;
  folder: string;
  kind: "image" | "video" | "other";
  size: number;
  modified: string; // ISO date
  source: "upload" | "site"; // "site" = built into the website files (public/images), can't be deleted here
  used: boolean;
};

const IMAGE = /\.(jpe?g|png|webp|avif|gif|svg)$/i;
const VIDEO = /\.(mp4|webm|mov)$/i;

async function walk(dir: string, base = dir): Promise<{ rel: string; full: string }[]> {
  let entries;
  try {
    entries = await readdir(/* turbopackIgnore: true */ dir, { withFileTypes: true });
  } catch {
    return [];
  }
  const out: { rel: string; full: string }[] = [];
  for (const e of entries) {
    if (e.name.startsWith(".")) continue;
    const full = path.join(/* turbopackIgnore: true */ dir, e.name);
    if (e.isDirectory()) out.push(...(await walk(full, base)));
    else if (e.isFile()) out.push({ rel: path.relative(base, full).split(path.sep).join("/"), full });
  }
  return out;
}

/** Every image/video path that is used somewhere on the website (content, events, menu, gallery, news, reviews). */
export async function usedMediaPaths(): Promise<Set<string>> {
  const [content, events, items, gallery, posts] = await Promise.all([
    db.select({ data: schema.siteContent.data }).from(schema.siteContent),
    db.select({ image: schema.events.image, gallery: schema.events.gallery }).from(schema.events),
    db.select({ image: schema.menuItems.image }).from(schema.menuItems),
    db.select({ image: schema.galleryImages.image, video: schema.galleryImages.video }).from(schema.galleryImages),
    db.select({ image: schema.posts.image, content: schema.posts.content }).from(schema.posts),
  ]);
  const text = JSON.stringify([content, events, items, gallery, posts]);
  // defaults written in the code (lib/content-schema.ts) count as used too
  const { SECTIONS } = await import("@/lib/content-schema");
  const all = text + JSON.stringify(SECTIONS.map((s) => s.defaults));
  const set = new Set<string>();
  for (const m of all.matchAll(/\/(?:uploads|images)\/[\w\-./%]+?\.(?:jpe?g|png|webp|avif|gif|svg|mp4|webm|mov)/gi)) set.add(m[0]);
  return set;
}

/** All files in uploads/ (deletable) and public/images/ (built in). Newest first. */
export async function listMedia(): Promise<MediaFile[]> {
  const used = await usedMediaPaths();
  const publicImages = path.join(/* turbopackIgnore: true */ process.cwd(), "public", "images");
  const [uploads, site] = await Promise.all([walk(uploadRoot()), walk(publicImages)]);
  const files: MediaFile[] = [];
  for (const [list, source, prefix] of [
    [uploads, "upload", "/uploads/"],
    [site, "site", "/images/"],
  ] as const) {
    for (const f of list) {
      const kind = IMAGE.test(f.rel) ? "image" : VIDEO.test(f.rel) ? "video" : "other";
      if (kind === "other") continue;
      const s = await stat(/* turbopackIgnore: true */ f.full).catch(() => null);
      if (!s) continue;
      const url = prefix + f.rel;
      const parts = f.rel.split("/");
      files.push({
        url,
        name: parts[parts.length - 1],
        folder: parts.slice(0, -1).join("/") || (source === "site" ? "website" : "uploads"),
        kind,
        size: s.size,
        modified: s.mtime.toISOString(),
        source,
        used: used.has(url),
      });
    }
  }
  return files.sort((a, b) => b.modified.localeCompare(a.modified));
}

/** Deletes uploaded files (never the built-in website images). Returns the URLs that were removed. */
export async function deleteUploads(urls: string[]) {
  const root = uploadRoot();
  const removed: string[] = [];
  for (const url of urls) {
    if (!url.startsWith("/uploads/")) continue;
    const full = path.resolve(/* turbopackIgnore: true */ root, decodeURIComponent(url.slice("/uploads/".length)));
    if (!full.startsWith(root + path.sep)) continue; // safety: stay inside the uploads folder
    try {
      await unlink(/* turbopackIgnore: true */ full);
      removed.push(url);
    } catch {
      /* already gone */
    }
  }
  return removed;
}
