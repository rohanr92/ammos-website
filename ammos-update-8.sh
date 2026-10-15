#!/bin/bash
# Ammos website — update 8: Files (media library) in the admin + "Choose from library" in every photo/video field
set -e
if [ ! -f components/admin/BulkBar.tsx ]; then echo "✖ Run this inside ammos-website after update 7 (bash ammos-update-7.sh)."; exit 1; fi
echo "→ Updating files…"

mkdir -p "lib"
cat > "lib/media.ts" << 'AMMOS_EOF'
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
AMMOS_EOF
echo "  ✔ lib/media.ts"

mkdir -p "app/api/admin/media"
cat > "app/api/admin/media/route.ts" << 'AMMOS_EOF'
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
AMMOS_EOF
echo "  ✔ app/api/admin/media/route.ts"

mkdir -p "app/api/admin/upload"
cat > "app/api/admin/upload/route.ts" << 'AMMOS_EOF'
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
AMMOS_EOF
echo "  ✔ app/api/admin/upload/route.ts"

mkdir -p "components/admin"
cat > "components/admin/MediaBrowser.tsx" << 'AMMOS_EOF'
"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { api, uploadFile } from "@/components/admin/api";

export type MediaFile = {
  url: string;
  name: string;
  folder: string;
  kind: "image" | "video" | "other";
  size: number;
  modified: string;
  source: "upload" | "site";
  used: boolean;
};

type Filter = "all" | "image" | "video" | "unused" | "site";
const PAGE = 60;

export function formatBytes(n: number) {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${Math.round(n / 1024)} KB`;
  return `${(n / 1024 / 1024).toFixed(1)} MB`;
}

/** Small preview: optimised thumbnail for images, first frame for videos. */
export function MediaThumb({ file }: { file: Pick<MediaFile, "url" | "kind" | "name"> }) {
  if (file.kind === "video") return <video src={`${file.url}#t=0.5`} muted playsInline preload="metadata" />;
  const thumb = /\.svg$/i.test(file.url) ? file.url : `/_next/image?url=${encodeURIComponent(file.url)}&w=384&q=75`;
  // eslint-disable-next-line @next/next/no-img-element
  return <img src={thumb} alt={file.name} loading="lazy" decoding="async" />;
}

/**
 * The media library ("Files"): every image and video on the website.
 *  - mode "manage": the Admin → Files page (upload, search, details, delete)
 *  - mode "pick":   the "Choose from library" window inside photo/video fields
 */
export function MediaBrowser({
  mode = "manage",
  kind,
  multiple = false,
  onPick,
}: {
  mode?: "manage" | "pick";
  kind?: "image" | "video";
  multiple?: boolean;
  onPick?: (urls: string[]) => void;
}) {
  const [files, setFiles] = useState<MediaFile[] | null>(null);
  const [error, setError] = useState("");
  const [filter, setFilter] = useState<Filter>(kind ?? "all");
  const [q, setQ] = useState("");
  const [sort, setSort] = useState<"new" | "name" | "size">("new");
  const [limit, setLimit] = useState(PAGE);
  const [selected, setSelected] = useState<string[]>([]);
  const [open, setOpen] = useState<MediaFile | null>(null);
  const [status, setStatus] = useState<{ ok: boolean; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [over, setOver] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  const load = useCallback(async () => {
    try {
      const r = await api<{ files: MediaFile[] }>(`/api/admin/media${kind ? `?kind=${kind}` : ""}`);
      setFiles(r.files);
    } catch (e) {
      setError((e as Error).message);
    }
  }, [kind]);
  useEffect(() => {
    load();
  }, [load]);

  const list = useMemo(() => {
    let l = files ?? [];
    if (filter === "image" || filter === "video") l = l.filter((f) => f.kind === filter);
    if (filter === "unused") l = l.filter((f) => !f.used && f.source === "upload");
    if (filter === "site") l = l.filter((f) => f.source === "site");
    const term = q.trim().toLowerCase();
    if (term) l = l.filter((f) => f.name.toLowerCase().includes(term) || f.folder.toLowerCase().includes(term));
    if (sort === "name") l = [...l].sort((a, b) => a.name.localeCompare(b.name));
    if (sort === "size") l = [...l].sort((a, b) => b.size - a.size);
    return l;
  }, [files, filter, q, sort]);

  const counts = useMemo(() => {
    const f = files ?? [];
    return {
      all: f.length,
      image: f.filter((x) => x.kind === "image").length,
      video: f.filter((x) => x.kind === "video").length,
      unused: f.filter((x) => !x.used && x.source === "upload").length,
      site: f.filter((x) => x.source === "site").length,
    };
  }, [files]);

  async function upload(fl: FileList | File[] | null) {
    const items = Array.from(fl ?? []).filter((f) => f.type.startsWith("image/") || f.type.startsWith("video/"));
    if (!items.length) return;
    setBusy(true);
    let ok = 0;
    const failed: string[] = [];
    const added: string[] = [];
    for (const [i, f] of items.entries()) {
      setStatus({ ok: true, text: `Uploading ${i + 1} of ${items.length}: ${f.name}` });
      try {
        added.push(await uploadFile(f));
        ok++;
      } catch (e) {
        failed.push(`${f.name} (${(e as Error).message})`);
      }
    }
    setStatus(failed.length ? { ok: false, text: `${ok} uploaded. Failed: ${failed.join(", ")}` } : { ok: true, text: `${ok} file${ok === 1 ? "" : "s"} uploaded.` });
    setBusy(false);
    if (fileRef.current) fileRef.current.value = "";
    setFilter(kind ?? "all");
    await load();
    if (mode === "pick" && added.length) setSelected(multiple ? added : added.slice(-1));
  }

  async function remove(urls: string[]) {
    const deletable = urls.filter((u) => u.startsWith("/uploads/"));
    if (!deletable.length) return setStatus({ ok: false, text: "Built-in website images can't be deleted here." });
    if (!confirm(`Delete ${deletable.length} file${deletable.length === 1 ? "" : "s"}? This cannot be undone.`)) return;
    setBusy(true);
    try {
      let r: { count: number };
      try {
        r = await api<{ count: number }>("/api/admin/media", { method: "DELETE", json: { urls: deletable } });
      } catch (e) {
        const msg = (e as Error).message;
        if (!/still used/.test(msg)) throw e;
        if (!confirm(`${msg}\n\nThose pages will show an empty picture until you choose a new one. Delete anyway?`)) return;
        r = await api<{ count: number }>("/api/admin/media", { method: "DELETE", json: { urls: deletable, force: true } });
      }
      setStatus({ ok: true, text: `${r.count} file${r.count === 1 ? "" : "s"} deleted.` });
      setSelected([]);
      setOpen(null);
      await load();
    } catch (e) {
      setStatus({ ok: false, text: (e as Error).message });
    } finally {
      setBusy(false);
    }
  }

  function toggle(url: string) {
    setSelected((s) => (s.includes(url) ? s.filter((x) => x !== url) : multiple || mode === "manage" ? [...s, url] : [url]));
  }

  async function copy(text: string) {
    try {
      await navigator.clipboard.writeText(text);
      setStatus({ ok: true, text: "Link copied." });
    } catch {
      prompt("Copy this link:", text);
    }
  }

  const tabs: [Filter, string][] = kind
    ? [[kind, kind === "image" ? "Images" : "Videos"]]
    : [
        ["all", "All"],
        ["image", "Images"],
        ["video", "Videos"],
        ["unused", "Not used"],
        ["site", "Built-in"],
      ];

  return (
    <div
      className={`m-lib${over ? " is-over" : ""}`}
      onDragOver={(e) => {
        if (e.dataTransfer.types.includes("Files")) {
          e.preventDefault();
          setOver(true);
        }
      }}
      onDragLeave={(e) => {
        if (e.currentTarget === e.target) setOver(false);
      }}
      onDrop={(e) => {
        if (!e.dataTransfer.files?.length) return;
        e.preventDefault();
        setOver(false);
        upload(e.dataTransfer.files);
      }}
    >
      <div className="m-upload">
        <div>
          <b>Upload {kind === "video" ? "videos" : kind === "image" ? "photos" : "photos & videos"}</b>
          <div className="a-help">
            Drag files anywhere here, or choose them. Photos are optimised automatically (max 15 MB); videos MP4/WebM up to 80 MB.
          </div>
        </div>
        <button type="button" className="a-btn primary" onClick={() => fileRef.current?.click()} disabled={busy}>
          {busy ? "Working…" : "+ Upload files"}
        </button>
        <input
          ref={fileRef}
          type="file"
          multiple
          hidden
          accept={kind === "video" ? "video/mp4,video/webm" : kind === "image" ? "image/*" : "image/*,video/mp4,video/webm"}
          onChange={(e) => upload(e.target.files)}
        />
      </div>

      <div className="m-toolbar">
        <div className="a-tabs">
          {tabs.map(([key, label]) => (
            <button
              key={key}
              type="button"
              className={filter === key ? "is-active" : ""}
              onClick={() => {
                setFilter(key);
                setLimit(PAGE);
              }}
            >
              {label} <span className="m-count">{counts[key]}</span>
            </button>
          ))}
        </div>
        <input className="a-input" placeholder="Search file name…" value={q} onChange={(e) => setQ(e.target.value)} style={{ width: 220 }} aria-label="Search files" />
        <select className="a-input" value={sort} onChange={(e) => setSort(e.target.value as typeof sort)} style={{ width: 150 }} aria-label="Sort">
          <option value="new">Newest first</option>
          <option value="name">Name A–Z</option>
          <option value="size">Largest first</option>
        </select>
        <span className="a-help" style={{ marginLeft: "auto" }}>
          {list.length} file{list.length === 1 ? "" : "s"}
        </span>
      </div>

      {status && <p className={`a-msg ${status.ok ? "ok" : "err"}`}>{status.text}</p>}
      {error && <p className="a-msg err">{error}</p>}

      {mode === "manage" && selected.length > 0 && (
        <div className="a-bulk">
          <b>{selected.length} selected</b>
          <button type="button" className="a-btn sm" onClick={() => copy(selected.join("\n"))}>
            Copy links
          </button>
          <button type="button" className="a-btn sm danger" onClick={() => remove(selected)} disabled={busy}>
            Delete
          </button>
          <button type="button" className="a-btn sm ghost" onClick={() => setSelected(list.map((f) => f.url))}>
            Select all {list.length}
          </button>
          <button type="button" className="a-btn sm ghost" onClick={() => setSelected([])}>
            Clear
          </button>
        </div>
      )}

      {files === null ? (
        <p className="a-empty">Loading files…</p>
      ) : list.length === 0 ? (
        <p className="a-empty">No files here yet. Upload some above.</p>
      ) : (
        <div className="m-grid">
          {list.slice(0, limit).map((f) => {
            const isSel = selected.includes(f.url);
            return (
              <div key={f.url} className={`m-tile${isSel ? " is-selected" : ""}`}>
                <button
                  type="button"
                  className="m-thumb"
                  onClick={() => (mode === "pick" ? toggle(f.url) : setOpen(f))}
                  onDoubleClick={() => mode === "pick" && onPick?.([f.url])}
                  title={f.name}
                >
                  <MediaThumb file={f} />
                  {f.kind === "video" && <span className="m-play">▶</span>}
                </button>
                <label className="m-check" onClick={(e) => e.stopPropagation()}>
                  <input type="checkbox" checked={isSel} onChange={() => toggle(f.url)} aria-label={`Select ${f.name}`} />
                </label>
                <div className="m-meta">
                  <span className="m-name" title={f.name}>
                    {f.name}
                  </span>
                  <span className="m-sub">
                    {formatBytes(f.size)}
                    {f.source === "site" ? <span className="m-tag">built-in</span> : f.used ? <span className="m-tag ok">in use</span> : <span className="m-tag">not used</span>}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      )}
      {list.length > limit && (
        <div style={{ textAlign: "center", marginTop: 16 }}>
          <button type="button" className="a-btn" onClick={() => setLimit((l) => l + PAGE)}>
            Show more ({list.length - limit})
          </button>
        </div>
      )}

      {mode === "pick" && (
        <div className="m-pickbar">
          <span className="a-help">{selected.length ? `${selected.length} selected` : multiple ? "Click photos to select them" : "Click a file to select it (double-click to use it right away)"}</span>
          <button type="button" className="a-btn primary" disabled={!selected.length} onClick={() => onPick?.(selected)}>
            Use {selected.length > 1 ? `${selected.length} files` : "this file"}
          </button>
        </div>
      )}

      {open && mode === "manage" && (
        <>
          <div className="a-drawer-bg" onClick={() => setOpen(null)} />
          <aside className="a-drawer" role="dialog" aria-label="File details">
            <div className="a-spread">
              <h2 style={{ fontSize: 17, wordBreak: "break-all" }}>{open.name}</h2>
              <button type="button" className="a-btn sm ghost" onClick={() => setOpen(null)}>
                Close ✕
              </button>
            </div>
            <div className="m-preview">
              {open.kind === "video" ? (
                <video src={open.url} controls playsInline preload="metadata" />
              ) : (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={open.url} alt={open.name} />
              )}
            </div>
            <dl className="a-kv">
              <dt>Link</dt>
              <dd style={{ wordBreak: "break-all" }}>
                <code>{open.url}</code>
              </dd>
              <dt>Type</dt>
              <dd>{open.kind === "video" ? "Video" : "Image"}</dd>
              <dt>Size</dt>
              <dd>{formatBytes(open.size)}</dd>
              <dt>Folder</dt>
              <dd>{open.folder}</dd>
              <dt>Date</dt>
              <dd>{new Date(open.modified).toLocaleString("en-GB", { dateStyle: "medium", timeStyle: "short" })}</dd>
              <dt>Status</dt>
              <dd>
                {open.source === "site"
                  ? "Built into the website (part of the code — can't be deleted here)"
                  : open.used
                    ? "In use on the website"
                    : "Not used anywhere yet"}
              </dd>
            </dl>
            <div className="a-row" style={{ flexWrap: "wrap" }}>
              <button type="button" className="a-btn primary" onClick={() => copy(open.url)}>
                Copy link
              </button>
              <a className="a-btn" href={open.url} target="_blank" rel="noopener noreferrer">
                Open ↗
              </a>
              <a className="a-btn" href={open.url} download={open.name}>
                Download
              </a>
              <span style={{ flex: 1 }} />
              {open.source === "upload" && (
                <button type="button" className="a-btn danger" onClick={() => remove([open.url])} disabled={busy}>
                  Delete
                </button>
              )}
            </div>
            <p className="a-help">
              To use this file, open any photo or video field in the admin and press <b>Choose from library</b> — or paste the link.
            </p>
          </aside>
        </>
      )}
    </div>
  );
}

/** Modal window with the library, used by photo/video fields ("Choose from library"). */
export function MediaPickerModal({
  kind,
  multiple,
  onClose,
  onPick,
}: {
  kind: "image" | "video";
  multiple?: boolean;
  onClose: () => void;
  onPick: (urls: string[]) => void;
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    document.documentElement.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.documentElement.style.overflow = "";
    };
  }, [onClose]);
  return (
    <div className="m-modal-bg" onClick={onClose}>
      <div className="m-modal" role="dialog" aria-modal="true" aria-label="Choose from library" onClick={(e) => e.stopPropagation()}>
        <div className="a-spread" style={{ marginBottom: 12 }}>
          <h2 style={{ margin: 0, fontSize: 18 }}>Choose {kind === "video" ? "a video" : multiple ? "photos" : "a photo"} from the library</h2>
          <button type="button" className="a-btn sm ghost" onClick={onClose}>
            Close ✕
          </button>
        </div>
        <MediaBrowser
          mode="pick"
          kind={kind}
          multiple={multiple}
          onPick={(urls) => {
            onPick(urls);
            onClose();
          }}
        />
      </div>
    </div>
  );
}
AMMOS_EOF
echo "  ✔ components/admin/MediaBrowser.tsx"

mkdir -p "app/admin/(panel)/files"
cat > "app/admin/(panel)/files/page.tsx" << 'AMMOS_EOF'
import { PageTop } from "@/components/admin/PageTop";
import { MediaBrowser } from "@/components/admin/MediaBrowser";

export const metadata = { title: "Files" };
export const dynamic = "force-dynamic";

export default function FilesPage() {
  return (
    <>
      <PageTop title="Files" />
      <div className="a-content">
        <p className="a-desc">
          All photos and videos of the website in one place. Upload new files, copy a file&apos;s link, or delete files you don&apos;t need. Anywhere in the admin you can pick
          these files with <b>Choose from library</b>. “In use” means the file is shown somewhere on the website; “built-in” files are part of the website design.
        </p>
        <MediaBrowser mode="manage" />
      </div>
    </>
  );
}
AMMOS_EOF
echo "  ✔ app/admin/(panel)/files/page.tsx"

mkdir -p "components/admin"
cat > "components/admin/AdminShell.tsx" << 'AMMOS_EOF'
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";

type Counts = { messages: number; bookings: number };

const NAV: { title: string; links: { href: string; label: string; badge?: keyof Counts }[] }[] = [
  { title: "Overview", links: [{ href: "/admin", label: "Dashboard" }] },
  {
    title: "Guests",
    links: [
      { href: "/admin/bookings", label: "Event bookings", badge: "bookings" },
      { href: "/admin/messages", label: "Messages", badge: "messages" },
    ],
  },
  {
    title: "Website",
    links: [
      { href: "/admin/events", label: "Events" },
      { href: "/admin/menu-items", label: "Menu items" },
      { href: "/admin/menu-categories", label: "Menu categories" },
      { href: "/admin/gallery", label: "Gallery" },
      { href: "/admin/news", label: "News & stories" },
      { href: "/admin/reviews", label: "Reviews" },
      { href: "/admin/content", label: "Page content" },
      { href: "/admin/files", label: "Files (images & videos)" },
      { href: "/admin/redirects", label: "Redirects" },
    ],
  },
  { title: "Account", links: [{ href: "/admin/account", label: "My account & users" }] },
];

export function AdminShell({ user, counts, children }: { user: { name: string; email: string }; counts: Counts; children: React.ReactNode }) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  useEffect(() => setOpen(false), [pathname]);

  const active = (href: string) => (href === "/admin" ? pathname === "/admin" : pathname === href || pathname.startsWith(`${href}/`));

  async function logout() {
    await fetch("/api/auth/logout", { method: "POST" });
    window.location.href = "/admin/login";
  }

  return (
    <div className="a-shell">
      <aside className={`a-side${open ? " is-open" : ""}`}>
        <Link href="/admin" className="brand">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/images/logo.svg" alt="ammos" width={130} height={34} />
          <span>Admin</span>
        </Link>
        {NAV.map((g) => (
          <nav key={g.title} className="a-nav-group" aria-label={g.title}>
            <span className="a-nav-title">{g.title}</span>
            {g.links.map((l) => (
              <Link key={l.href} href={l.href} className={`a-nav-link${active(l.href) ? " is-active" : ""}`}>
                {l.label}
                {l.badge && counts[l.badge] > 0 && <span className="a-badge">{counts[l.badge]}</span>}
              </Link>
            ))}
          </nav>
        ))}
        <div className="a-side-foot">
          <span className="who">
            {user.name}
            <br />
            <small>{user.email}</small>
          </span>
          <a className="a-nav-link" href="/" target="_blank" rel="noopener noreferrer">
            View website ↗
          </a>
          <button type="button" className="a-nav-link" style={{ background: "none", border: 0, cursor: "pointer", textAlign: "left", font: "inherit" }} onClick={logout}>
            Log out
          </button>
        </div>
      </aside>
      <div className="a-main">
        <button type="button" className="a-btn a-menu-toggle" style={{ position: "fixed", right: 14, bottom: 14, zIndex: 60 }} onClick={() => setOpen((o) => !o)}>
          ☰ Menu
        </button>
        {children}
      </div>
    </div>
  );
}
AMMOS_EOF
echo "  ✔ components/admin/AdminShell.tsx"

mkdir -p "components/admin"
cat > "components/admin/MediaInput.tsx" << 'AMMOS_EOF'
"use client";

import { useRef, useState } from "react";
import { uploadFile } from "@/components/admin/api";
import { MediaPickerModal } from "@/components/admin/MediaBrowser";

/** Upload / replace / remove an image or video, or paste a link. */
export function MediaInput({ value, onChange, kind = "image", id }: { value: string; onChange: (v: string) => void; kind?: "image" | "video"; id?: string }) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [over, setOver] = useState(false);
  const [picking, setPicking] = useState(false);

  async function handle(file?: File | null) {
    if (!file) return;
    setBusy(true);
    setError("");
    try {
      onChange(await uploadFile(file));
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
      if (fileRef.current) fileRef.current.value = "";
    }
  }

  return (
    <div className="a-media">
      <div
        className={`a-media-preview a-drop${over ? " is-over" : ""}`}
        onDragOver={(e) => (e.preventDefault(), setOver(true))}
        onDragLeave={() => setOver(false)}
        onDrop={(e) => {
          e.preventDefault();
          setOver(false);
          handle(e.dataTransfer.files?.[0]);
        }}
      >
        {busy ? (
          "Uploading…"
        ) : value ? (
          kind === "video" ? (
            <video src={value} muted playsInline preload="metadata" />
          ) : (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={value} alt="" />
          )
        ) : (
          <span>
            Drop {kind === "video" ? "a video" : "a photo"} here
          </span>
        )}
      </div>
      <div className="a-media-controls">
        <div className="a-row">
          <button type="button" className="a-btn" onClick={() => fileRef.current?.click()} disabled={busy}>
            {value ? "Replace" : "Upload"} {kind}
          </button>
          <button type="button" className="a-btn" onClick={() => setPicking(true)} disabled={busy}>
            Choose from library
          </button>
          {value && (
            <button type="button" className="a-btn danger sm" onClick={() => onChange("")}>
              Remove
            </button>
          )}
        </div>
        <input
          ref={fileRef}
          type="file"
          hidden
          accept={kind === "video" ? "video/mp4,video/webm" : "image/jpeg,image/png,image/webp,image/avif,image/gif"}
          onChange={(e) => handle(e.target.files?.[0])}
        />
        <input id={id} className="a-input" value={value} onChange={(e) => onChange(e.target.value)} placeholder={kind === "video" ? "…or paste a link to an .mp4" : "…or paste an image link"} />
        <span className="a-help">{kind === "video" ? "MP4 or WebM, max 80 MB." : "JPG, PNG or WebP, max 15 MB — it's resized and optimised automatically."}</span>
        {error && <span className="a-msg err">{error}</span>}
      </div>
      {picking && <MediaPickerModal kind={kind} onClose={() => setPicking(false)} onPick={(urls) => urls[0] && onChange(urls[0])} />}
    </div>
  );
}
AMMOS_EOF
echo "  ✔ components/admin/MediaInput.tsx"

mkdir -p "components/admin"
cat > "components/admin/MultiImageInput.tsx" << 'AMMOS_EOF'
"use client";

import { useRef, useState } from "react";
import { uploadFile } from "@/components/admin/api";
import { MediaPickerModal } from "@/components/admin/MediaBrowser";

/** Several photos: upload many at once, drag (or ← →) to reorder, remove. */
export function MultiImageInput({ value, onChange }: { value: string[]; onChange: (v: string[]) => void }) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [status, setStatus] = useState("");
  const [error, setError] = useState("");
  const [drag, setDrag] = useState<number | null>(null);
  const [over, setOver] = useState(false);
  const [picking, setPicking] = useState(false);

  async function addFiles(files: FileList | File[] | null) {
    const list = Array.from(files ?? []).filter((f) => f.type.startsWith("image/"));
    if (!list.length) return;
    setError("");
    const added: string[] = [];
    for (const [i, file] of list.entries()) {
      setStatus(`Uploading ${i + 1} of ${list.length}…`);
      try {
        added.push(await uploadFile(file));
      } catch (e) {
        setError(`${file.name}: ${(e as Error).message}`);
      }
    }
    onChange([...value, ...added]);
    setStatus(added.length ? `${added.length} photo${added.length === 1 ? "" : "s"} added — click Save.` : "");
    if (fileRef.current) fileRef.current.value = "";
  }

  const move = (from: number, to: number) => {
    if (to < 0 || to >= value.length || from === to) return;
    const next = [...value];
    const [x] = next.splice(from, 1);
    next.splice(to, 0, x);
    onChange(next);
  };

  return (
    <div
      className={`a-multi${over ? " is-over" : ""}`}
      onDragOver={(e) => {
        if (e.dataTransfer.types.includes("Files")) {
          e.preventDefault();
          setOver(true);
        }
      }}
      onDragLeave={() => setOver(false)}
      onDrop={(e) => {
        if (!e.dataTransfer.files?.length) return;
        e.preventDefault();
        setOver(false);
        addFiles(e.dataTransfer.files);
      }}
    >
      {value.length > 0 && (
        <div className="a-multi-grid">
          {value.map((src, i) => (
            <div
              key={`${src}-${i}`}
              className={`a-multi-item${drag === i ? " is-drag" : ""}`}
              draggable
              onDragStart={() => setDrag(i)}
              onDragEnd={() => setDrag(null)}
              onDragOver={(e) => {
                if (drag !== null) e.preventDefault();
              }}
              onDrop={(e) => {
                if (drag === null) return;
                e.preventDefault();
                e.stopPropagation();
                move(drag, i);
                setDrag(null);
              }}
            >
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={src} alt="" loading="lazy" />
              <span className="a-multi-num">{i + 1}</span>
              <div className="a-multi-actions">
                <button type="button" onClick={() => move(i, i - 1)} disabled={i === 0} aria-label="Move left">
                  ←
                </button>
                <button type="button" onClick={() => move(i, i + 1)} disabled={i === value.length - 1} aria-label="Move right">
                  →
                </button>
                <button type="button" className="del" onClick={() => onChange(value.filter((_, j) => j !== i))} aria-label="Remove photo">
                  ✕
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
      <div className="a-row">
        <button type="button" className="a-btn" onClick={() => fileRef.current?.click()} disabled={status.startsWith("Uploading")}>
          + Add photos
        </button>
        <button type="button" className="a-btn" onClick={() => setPicking(true)}>
          Choose from library
        </button>
        <span className="a-help">{status || (value.length ? `${value.length} photo${value.length === 1 ? "" : "s"}` : "No photos yet — or drop images here")}</span>
      </div>
      <input ref={fileRef} type="file" multiple hidden accept="image/jpeg,image/png,image/webp,image/avif,image/gif" onChange={(e) => addFiles(e.target.files)} />
      {error && <span className="a-msg err">{error}</span>}
      {picking && (
        <MediaPickerModal kind="image" multiple onClose={() => setPicking(false)} onPick={(urls) => onChange([...value, ...urls.filter((u) => !value.includes(u))])} />
      )}
    </div>
  );
}
AMMOS_EOF
echo "  ✔ components/admin/MultiImageInput.tsx"

mkdir -p "app/admin"
cat > "app/admin/admin.css" << 'AMMOS_EOF'
/* ═══════════ AMMOS ADMIN PANEL ═══════════ */
.admin {
  --a-bg: #0c0e15;
  --a-panel: #141726;
  --a-card: #1a1d2b;
  --a-line: #2a2e3d;
  --a-text: #e9e9ed;
  --a-muted: #9397ab;
  --a-ok: #b7d44a;
  --a-warn: #f2b84b;
  --a-bad: #f06262;
  min-height: 100vh;
  background: var(--a-bg);
  color: var(--a-text);
  font-family: var(--body);
  font-size: 14px;
  line-height: 1.5;
}
.admin a { color: var(--brand); }
.admin h1, .admin h2, .admin h3 { font-family: var(--body); font-weight: 600; letter-spacing: 0; text-transform: none; margin: 0; }

/* layout */
.a-shell { display: grid; grid-template-columns: 248px minmax(0, 1fr); min-height: 100vh; }
.a-side { background: var(--a-panel); border-right: 1px solid var(--a-line); padding: 22px 14px; position: sticky; top: 0; height: 100vh; overflow-y: auto; display: flex; flex-direction: column; gap: 18px; }
.a-side .brand { display: flex; align-items: center; gap: 10px; padding: 4px 10px 10px; }
.a-side .brand img { height: 34px; width: auto; }
.a-side .brand span { font-size: 10px; letter-spacing: 0.2em; text-transform: uppercase; color: var(--a-muted); }
.a-nav-group { display: grid; gap: 2px; }
.a-nav-title { font-size: 10px; letter-spacing: 0.22em; text-transform: uppercase; color: var(--a-muted); padding: 6px 10px; }
.a-nav-link { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 9px 12px; border-radius: 8px; color: var(--a-text) !important; font-size: 14px; }
.a-nav-link:hover { background: rgba(255, 255, 255, 0.05); }
.a-nav-link.is-active { background: rgba(62, 198, 216, 0.14); color: var(--brand) !important; }
.a-badge { min-width: 20px; height: 20px; padding: 0 6px; border-radius: 999px; background: var(--brand); color: var(--ink); font-size: 11px; font-weight: 700; display: inline-flex; align-items: center; justify-content: center; }
.a-side-foot { margin-top: auto; border-top: 1px solid var(--a-line); padding-top: 14px; display: grid; gap: 6px; font-size: 13px; }
.a-side-foot .who { padding: 0 12px; color: var(--a-muted); }
.a-main { min-width: 0; }
.a-top { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 16px 32px; border-bottom: 1px solid var(--a-line); background: rgba(12, 14, 21, 0.9); backdrop-filter: blur(10px); position: sticky; top: 0; z-index: 10; }
.a-top h1 { font-size: 20px; }
.a-content { padding: 28px 32px 80px; max-width: 1280px; }
.a-btn.a-menu-toggle { display: none; }

/* buttons */
.a-btn { display: inline-flex; align-items: center; justify-content: center; gap: 6px; padding: 9px 16px; border-radius: 8px; border: 1px solid var(--a-line); background: var(--a-card); color: var(--a-text) !important; font: inherit; font-size: 13px; font-weight: 500; cursor: pointer; white-space: nowrap; text-decoration: none; transition: background 0.2s, border-color 0.2s; }
.a-btn:hover { border-color: var(--brand); }
.a-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.a-btn.primary { background: var(--brand); border-color: var(--brand); color: var(--ink) !important; }
.a-btn.primary:hover { background: var(--brand-hover); }
.a-btn.danger { color: var(--a-bad) !important; border-color: rgba(240, 98, 98, 0.4); background: transparent; }
.a-btn.danger:hover { background: rgba(240, 98, 98, 0.1); }
.a-btn.ghost { background: transparent; }
.a-btn.sm { padding: 6px 10px; font-size: 12px; }
.a-row { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
.a-spread { display: flex; gap: 12px; align-items: center; justify-content: space-between; flex-wrap: wrap; }

/* cards & stats */
.a-card { background: var(--a-card); border: 1px solid var(--a-line); border-radius: 12px; padding: 20px; }
.a-card + .a-card { margin-top: 16px; }
.a-grid-2 > .a-card { margin-top: 0; }
.a-card h2 { font-size: 16px; margin-bottom: 14px; }
.a-desc { color: var(--a-muted); margin: 0 0 20px; max-width: 760px; }
.a-stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 14px; margin-bottom: 20px; }
.a-stat { background: var(--a-card); border: 1px solid var(--a-line); border-radius: 12px; padding: 18px 20px; color: var(--a-text) !important; display: block; transition: border-color 0.2s; }
.a-stat:hover { border-color: var(--brand); }
.a-stat b { display: block; font-size: 30px; font-weight: 600; color: var(--brand); line-height: 1.1; }
.a-stat span { color: var(--a-muted); font-size: 13px; }
.a-grid-2 { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px; }

/* tables */
.a-table-wrap { overflow-x: auto; border: 1px solid var(--a-line); border-radius: 12px; background: var(--a-card); }
.a-table { width: 100%; border-collapse: collapse; }
.a-table th { text-align: left; font-size: 11px; letter-spacing: 0.12em; text-transform: uppercase; color: var(--a-muted); font-weight: 500; padding: 12px 14px; border-bottom: 1px solid var(--a-line); white-space: nowrap; }
.a-table td { padding: 10px 14px; border-bottom: 1px solid var(--a-line); vertical-align: middle; }
.a-table tr:last-child td { border-bottom: 0; }
.a-table tbody tr:hover { background: rgba(255, 255, 255, 0.025); }
.a-table .thumb { width: 52px; height: 52px; border-radius: 8px; object-fit: cover; background: var(--a-panel); display: block; }
.a-table .clip { max-width: 360px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.a-table a.title { color: var(--a-text) !important; font-weight: 500; }
.a-table a.title:hover { color: var(--brand) !important; }
.a-empty { padding: 48px; text-align: center; color: var(--a-muted); }
.pill-ok, .pill-off, .pill-warn, .pill-bad { display: inline-block; padding: 2px 9px; border-radius: 999px; font-size: 11px; font-weight: 600; }
.pill-ok { background: rgba(183, 212, 74, 0.16); color: var(--a-ok); }
.pill-off { background: rgba(255, 255, 255, 0.07); color: var(--a-muted); }
.pill-warn { background: rgba(242, 184, 75, 0.16); color: var(--a-warn); }
.pill-bad { background: rgba(240, 98, 98, 0.16); color: var(--a-bad); }

/* toolbar */
.a-toolbar { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; justify-content: space-between; margin-bottom: 16px; }
.a-search { display: flex; gap: 8px; }
.a-tabs { display: inline-flex; border: 1px solid var(--a-line); border-radius: 8px; overflow: hidden; }
.a-tabs a { padding: 8px 14px; color: var(--a-muted) !important; font-size: 13px; }
.a-tabs a + a { border-left: 1px solid var(--a-line); }
.a-tabs a.is-active { background: rgba(62, 198, 216, 0.14); color: var(--brand) !important; }

/* forms */
.a-form { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 18px 20px; }
.a-field { grid-column: 1 / -1; display: flex; flex-direction: column; gap: 6px; }
.a-field.half { grid-column: auto; }
.a-field > label, .a-label { font-size: 13px; font-weight: 500; color: var(--a-text); }
.a-field .req { color: var(--brand); }
.a-help { font-size: 12px; color: var(--a-muted); }
.a-input { width: 100%; padding: 10px 12px; border-radius: 8px; border: 1px solid var(--a-line); background: var(--a-panel); color: var(--a-text); font: inherit; font-size: 14px; }
.a-input:focus { outline: none; border-color: var(--brand); box-shadow: 0 0 0 3px rgba(62, 198, 216, 0.15); }
textarea.a-input { min-height: 96px; resize: vertical; line-height: 1.55; }
textarea.a-input.rich { min-height: 220px; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 13px; }
select.a-input { cursor: pointer; }
input[type="datetime-local"].a-input, input[type="date"].a-input { color-scheme: dark; }
.a-check { display: flex; align-items: center; gap: 10px; cursor: pointer; padding: 10px 12px; border: 1px solid var(--a-line); border-radius: 8px; background: var(--a-panel); }
.a-check input { width: 18px; height: 18px; accent-color: var(--brand); }
.a-form-actions { grid-column: 1 / -1; display: flex; gap: 10px; align-items: center; flex-wrap: wrap; padding-top: 8px; border-top: 1px solid var(--a-line); margin-top: 6px; position: sticky; bottom: 0; background: var(--a-card); padding-bottom: 4px; }
.a-msg { padding: 10px 14px; border-radius: 8px; font-size: 13px; }
.a-msg.ok { background: rgba(183, 212, 74, 0.14); color: var(--a-ok); }
.a-msg.err { background: rgba(240, 98, 98, 0.14); color: #ffb3b3; }

/* media input */
.a-media { display: grid; grid-template-columns: 160px minmax(0, 1fr); gap: 14px; align-items: start; }
.a-media-preview { width: 160px; aspect-ratio: 4 / 3; border-radius: 10px; overflow: hidden; background: var(--a-panel); border: 1px dashed var(--a-line); display: flex; align-items: center; justify-content: center; color: var(--a-muted); font-size: 12px; text-align: center; }
.a-media-preview img, .a-media-preview video { width: 100%; height: 100%; object-fit: cover; }
.a-media-controls { display: grid; gap: 8px; }
.a-drop.is-over { border-color: var(--brand); background: rgba(62, 198, 216, 0.08); }

/* list fields (content editor) */
.a-list { display: grid; gap: 12px; }
.a-list-item { border: 1px solid var(--a-line); border-radius: 10px; padding: 14px; background: rgba(255, 255, 255, 0.015); }
.a-list-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; font-size: 12px; color: var(--a-muted); letter-spacing: 0.1em; text-transform: uppercase; }
.a-list-item .a-form { gap: 12px 14px; }

/* message / booking detail */
.a-detail { white-space: pre-wrap; background: var(--a-panel); border-radius: 8px; padding: 12px 14px; margin: 8px 0; }
.a-kv { display: grid; grid-template-columns: 140px 1fr; gap: 6px 14px; font-size: 13px; }
.a-kv dt { color: var(--a-muted); }
.a-kv dd { margin: 0; }
.unread td { font-weight: 600; }
.unread td:first-child { box-shadow: inset 3px 0 0 var(--brand); }
.a-drawer-bg { position: fixed; inset: 0; background: rgba(0, 0, 0, 0.55); z-index: 40; }
.a-drawer { position: fixed; top: 0; right: 0; bottom: 0; width: min(560px, 100%); background: var(--a-card); border-left: 1px solid var(--a-line); z-index: 41; padding: 24px; overflow-y: auto; display: grid; gap: 16px; align-content: start; }

/* content sections list */
.a-sections { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 12px; }
.a-section-card { display: block; padding: 16px 18px; border: 1px solid var(--a-line); border-radius: 12px; background: var(--a-card); color: var(--a-text) !important; }
.a-section-card:hover { border-color: var(--brand); }
.a-section-card b { display: block; margin-bottom: 4px; }
.a-section-card span { color: var(--a-muted); font-size: 13px; }

/* login */
.a-login { min-height: 100vh; display: grid; place-items: center; padding: 24px; background: radial-gradient(60% 50% at 80% 0%, rgba(62, 198, 216, 0.16), transparent 70%), var(--a-bg); }
.a-login-card { width: min(420px, 100%); background: var(--a-card); border: 1px solid var(--a-line); border-radius: 16px; padding: 36px 32px; display: grid; gap: 16px; }
.a-login-card img { height: 46px; width: auto; margin: 0 auto 8px; }
.a-login-card h1 { text-align: center; font-size: 18px; }

@media (max-width: 900px) {
  .a-shell { grid-template-columns: 1fr; }
  .a-side { position: fixed; z-index: 50; left: 0; top: 0; width: 260px; transform: translateX(-100%); transition: transform 0.3s; }
  .a-side.is-open { transform: none; box-shadow: 0 0 0 100vmax rgba(0, 0, 0, 0.5); }
  .a-btn.a-menu-toggle { display: inline-flex; }
  .a-top { padding: 12px 16px; }
  .a-content { padding: 20px 16px 80px; }
  .a-form { grid-template-columns: 1fr; }
  .a-field.half { grid-column: 1 / -1; }
  .a-grid-2 { grid-template-columns: 1fr; }
  .a-media { grid-template-columns: 1fr; }
  .a-kv { grid-template-columns: 1fr; }
}

/* ── multiple photos field (event photos) ── */
.a-multi { display: grid; gap: 12px; padding: 12px; border: 1px dashed var(--a-line); border-radius: 12px; }
.a-multi.is-over { border-color: var(--a-accent, #00b8c8); background: rgba(0, 184, 200, 0.06); }
.a-multi-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: 10px; }
.a-multi-item { position: relative; aspect-ratio: 1; border-radius: 10px; overflow: hidden; background: var(--a-panel); cursor: grab; }
.a-multi-item.is-drag { opacity: 0.4; }
.a-multi-item img { width: 100%; height: 100%; object-fit: cover; display: block; pointer-events: none; }
.a-multi-num { position: absolute; top: 6px; left: 6px; min-width: 22px; height: 22px; padding: 0 6px; border-radius: 11px; background: rgba(0, 0, 0, 0.65); color: #fff; font-size: 11px; display: flex; align-items: center; justify-content: center; }
.a-multi-actions { position: absolute; left: 0; right: 0; bottom: 0; display: flex; justify-content: space-between; gap: 4px; padding: 6px; background: linear-gradient(transparent, rgba(0, 0, 0, 0.7)); }
.a-multi-actions button { width: 28px; height: 28px; border: 0; border-radius: 8px; background: rgba(255, 255, 255, 0.92); color: #111; cursor: pointer; font-size: 13px; }
.a-multi-actions button:disabled { opacity: 0.35; cursor: default; }
.a-multi-actions button.del { margin-left: auto; background: #e5484d; color: #fff; }

/* bulk select & actions */
.a-col-check { width: 36px; padding-right: 0 !important; }
.a-col-check input { width: 17px; height: 17px; accent-color: var(--brand, #00b8c8); cursor: pointer; vertical-align: middle; }
.a-bulk { position: sticky; top: 64px; z-index: 5; display: flex; flex-wrap: wrap; align-items: center; gap: 10px; margin-bottom: 12px; padding: 10px 14px; border-radius: 12px; background: var(--a-card); border: 1px solid var(--brand, #00b8c8); box-shadow: 0 10px 30px rgba(0, 0, 0, 0.35); }
.a-bulk b { margin-right: 6px; }

/* ── Files (media library) ── */
.m-lib { position: relative; display: grid; gap: 14px; }
.m-lib.is-over::after { content: "Drop files to upload"; position: absolute; inset: 0; z-index: 6; display: flex; align-items: center; justify-content: center; border: 2px dashed var(--brand, #00b8c8); border-radius: 14px; background: rgba(12, 14, 21, 0.85); font-size: 18px; color: #fff; }
.m-upload { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 16px 18px; border: 1px dashed var(--a-line); border-radius: 14px; background: var(--a-panel); }
.m-toolbar { display: flex; flex-wrap: wrap; align-items: center; gap: 10px; }
.m-toolbar .a-tabs button { background: none; border: 0; color: inherit; font: inherit; cursor: pointer; }
.m-count { opacity: 0.55; font-size: 11px; margin-left: 2px; }
.m-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: 14px; }
.m-tile { position: relative; border-radius: 12px; overflow: hidden; background: var(--a-panel); border: 1px solid var(--a-line); transition: border-color 0.2s, transform 0.2s; }
.m-tile:hover { border-color: #3a3f52; }
.m-tile.is-selected { border-color: var(--brand, #00b8c8); box-shadow: 0 0 0 2px var(--brand, #00b8c8); }
.m-thumb { display: block; width: 100%; aspect-ratio: 1; padding: 0; border: 0; background: repeating-conic-gradient(#1d2030 0 25%, #171a26 0 50%) 50% / 16px 16px; cursor: pointer; position: relative; }
.m-thumb img, .m-thumb video { width: 100%; height: 100%; object-fit: cover; display: block; }
.m-play { position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%); width: 40px; height: 40px; border-radius: 50%; background: rgba(0, 0, 0, 0.55); color: #fff; display: flex; align-items: center; justify-content: center; font-size: 14px; padding-left: 3px; }
.m-check { position: absolute; top: 8px; left: 8px; z-index: 2; width: 26px; height: 26px; border-radius: 7px; background: rgba(12, 14, 21, 0.7); display: flex; align-items: center; justify-content: center; opacity: 0; transition: opacity 0.2s; }
.m-tile:hover .m-check, .m-tile.is-selected .m-check, .m-check:focus-within { opacity: 1; }
.m-check input { width: 16px; height: 16px; accent-color: var(--brand, #00b8c8); cursor: pointer; }
.m-meta { display: grid; gap: 3px; padding: 8px 10px 10px; }
.m-name { font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.m-sub { display: flex; align-items: center; justify-content: space-between; gap: 6px; font-size: 11px; color: var(--a-muted); }
.m-tag { font-size: 10px; padding: 2px 7px; border-radius: 99px; background: #262a3a; color: var(--a-muted); white-space: nowrap; }
.m-tag.ok { background: rgba(183, 212, 74, 0.15); color: var(--a-ok); }
.m-preview { border-radius: 12px; overflow: hidden; background: repeating-conic-gradient(#1d2030 0 25%, #171a26 0 50%) 50% / 16px 16px; }
.m-preview img, .m-preview video { display: block; width: 100%; max-height: 52vh; object-fit: contain; }
.m-modal-bg { position: fixed; inset: 0; z-index: 60; background: rgba(0, 0, 0, 0.65); display: flex; align-items: center; justify-content: center; padding: 24px; }
.m-modal { width: min(1100px, 100%); max-height: calc(100vh - 48px); overflow-y: auto; background: var(--a-card); border: 1px solid var(--a-line); border-radius: 16px; padding: 22px; }
.m-pickbar { position: sticky; bottom: -22px; z-index: 3; display: flex; align-items: center; justify-content: space-between; gap: 12px; margin: 6px -22px -22px; padding: 14px 22px; background: var(--a-card); border-top: 1px solid var(--a-line); }
@media (max-width: 700px) {
  .m-grid { grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: 10px; }
  .m-upload { flex-direction: column; align-items: stretch; }
  .m-modal { padding: 16px; }
  .m-check { opacity: 1; }
}
.m-toolbar .a-tabs button { padding: 8px 14px; color: var(--a-muted); font-size: 13px; }
.m-toolbar .a-tabs button + button { border-left: 1px solid var(--a-line); }
.m-toolbar .a-tabs button.is-active { background: rgba(0, 184, 200, 0.12); color: var(--brand, #00b8c8); }
AMMOS_EOF
echo "  ✔ app/admin/admin.css"

echo ""
echo "✔ Update 8 done. Start the site:  npm run dev   → Admin → Files (images & videos)"
