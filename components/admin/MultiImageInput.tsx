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
