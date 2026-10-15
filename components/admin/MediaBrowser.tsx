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
  // built-in images get a small optimised thumbnail; uploads are already optimised
  const thumb = /\.svg$/i.test(file.url) || file.url.startsWith("/uploads/") ? file.url : `/_next/image?url=${encodeURIComponent(file.url)}&w=384&q=75`;
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
