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
