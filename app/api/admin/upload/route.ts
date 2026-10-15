import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { randomUUID } from "node:crypto";
import sharp from "sharp";
import { errorJson, json, withAdmin } from "@/lib/http";
import { IMAGE_TYPES, MAX_IMAGE_BYTES, MAX_VIDEO_BYTES, VIDEO_TYPES, uploadRoot } from "@/lib/uploads";

export const runtime = "nodejs";

/** Checks the first bytes of a video so a renamed file can't sneak in. */
function looksLikeVideo(buf: Buffer) {
  const isMp4 = buf.subarray(4, 8).toString("ascii") === "ftyp";
  const isWebm = buf[0] === 0x1a && buf[1] === 0x45 && buf[2] === 0xdf && buf[3] === 0xa3;
  return isMp4 || isWebm;
}

/**
 * POST /api/admin/upload  (multipart form, field "file")
 * Images are checked, auto-rotated, resized to max 2400px and saved as WebP.
 * Returns { url: "/uploads/2026/10/…" }
 */
export const POST = withAdmin(async (req) => {
  const form = await req.formData().catch(() => null);
  const file = form?.get("file");
  if (!file || typeof file === "string") return errorJson("No file received.", 400);

  const now = new Date();
  const sub = path.join(String(now.getUTCFullYear()), String(now.getUTCMonth() + 1).padStart(2, "0"));
  const dir = path.join(uploadRoot(), sub);
  await mkdir(dir, { recursive: true });
  // keep a readable name, e.g. "Sunset Terrace.JPG" → sunset-terrace-1a2b3c.webp
  const base =
    file.name
      .replace(/\.[^.]+$/, "")
      .normalize("NFKD")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 48) || "file";
  const id = `${base}-${randomUUID().replace(/-/g, "").slice(0, 6)}`;

  if (IMAGE_TYPES[file.type]) {
    if (file.size > MAX_IMAGE_BYTES) return errorJson("Image is too big (max 15 MB).", 413);
    const input = Buffer.from(await file.arrayBuffer());
    let out: Buffer;
    let width = 0;
    let height = 0;
    try {
      const img = sharp(input, { failOn: "error", animated: file.type === "image/gif" }).rotate();
      const { data, info } = await img
        .resize({ width: 2400, height: 2400, fit: "inside", withoutEnlargement: true })
        .webp({ quality: 82 })
        .toBuffer({ resolveWithObject: true });
      out = data;
      width = info.width;
      height = info.height;
    } catch {
      return errorJson("This file is not a valid image.", 415);
    }
    const name = `${id}.webp`;
    await writeFile(path.join(/* turbopackIgnore: true */ dir, name), out);
    return json({ ok: true, url: `/uploads/${sub.split(path.sep).join("/")}/${name}`, width, height });
  }

  if (VIDEO_TYPES[file.type]) {
    if (file.size > MAX_VIDEO_BYTES) return errorJson("Video is too big (max 80 MB). Please compress it first.", 413);
    const buf = Buffer.from(await file.arrayBuffer());
    if (!looksLikeVideo(buf)) return errorJson("This file is not a valid MP4/WebM video.", 415);
    const name = `${id}.${VIDEO_TYPES[file.type]}`;
    await writeFile(path.join(/* turbopackIgnore: true */ dir, name), buf);
    return json({ ok: true, url: `/uploads/${sub.split(path.sep).join("/")}/${name}` });
  }

  return errorJson("Only JPG, PNG, WebP, AVIF, GIF images or MP4/WebM videos are allowed.", 415);
});
