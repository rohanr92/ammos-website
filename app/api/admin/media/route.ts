import { z } from "zod";
import { errorJson, json, withAdmin } from "@/lib/http";
import { deleteUploads, listMedia, usedMediaPaths } from "@/lib/media";

export const runtime = "nodejs";

/** GET /api/admin/media?kind=image|video → every file (for the Files page and the "Choose from library" picker) */
export const GET = withAdmin(async (req) => {
  const kind = new URL(req.url).searchParams.get("kind");
  const files = await listMedia();
  return json({ ok: true, files: kind === "image" || kind === "video" ? files.filter((f) => f.kind === kind) : files });
});

const delBody = z.object({ urls: z.array(z.string().max(500)).min(1).max(500), force: z.boolean().default(false) });

/** DELETE { urls, force } → removes uploaded files. Files still used on the website need force:true. */
export const DELETE = withAdmin(async (req) => {
  const { urls, force } = delBody.parse(await req.json());
  const builtIn = urls.filter((u) => !u.startsWith("/uploads/"));
  if (builtIn.length === urls.length) return errorJson("Built-in website images can't be deleted here (they are part of the website code).", 400);
  if (!force) {
    const used = await usedMediaPaths();
    const inUse = urls.filter((u) => used.has(u));
    if (inUse.length) return errorJson(`${inUse.length} of these files are still used on the website.`, 409, { inUse });
  }
  const removed = await deleteUploads(urls);
  return json({ ok: true, count: removed.length, skipped: builtIn.length });
});
