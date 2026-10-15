"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { api, uploadFile } from "@/components/admin/api";

/** Upload many gallery photos at once. Each becomes a gallery entry you can edit afterwards. */
export function GalleryBulkUpload() {
  const router = useRouter();
  const ref = useRef<HTMLInputElement>(null);
  const [status, setStatus] = useState("");
  const [album, setAlbum] = useState("The Beach");

  async function onFiles(files: FileList | null) {
    if (!files?.length) return;
    let done = 0;
    let failed = 0;
    for (const file of Array.from(files)) {
      setStatus(`Uploading ${done + failed + 1} of ${files.length}…`);
      try {
        const url = await uploadFile(file);
        const alt = file.name.replace(/\.[^.]+$/, "").replace(/[-_]+/g, " ");
        await api("/api/admin/gallery", { method: "POST", json: { image: url, alt, album, sortOrder: 100, showOnHome: false, published: true } });
        done++;
      } catch {
        failed++;
      }
    }
    setStatus(`${done} photo${done === 1 ? "" : "s"} added${failed ? `, ${failed} failed` : ""}. Edit each photo to add a description.`);
    if (ref.current) ref.current.value = "";
    router.refresh();
  }

  return (
    <div className="a-card" style={{ marginBottom: 16 }}>
      <div className="a-spread">
        <div>
          <b>Add many photos at once</b>
          <div className="a-help">Select several images — they are optimised and added to the album you choose.</div>
        </div>
        <div className="a-row">
          <input className="a-input" value={album} onChange={(e) => setAlbum(e.target.value)} list="albums" style={{ width: 160 }} aria-label="Album" />
          <datalist id="albums">
            {["The Beach", "Food", "The Bar", "Events"].map((a) => (
              <option key={a} value={a} />
            ))}
          </datalist>
          <button type="button" className="a-btn primary" onClick={() => ref.current?.click()}>
            Choose photos
          </button>
          <input ref={ref} type="file" multiple hidden accept="image/*" onChange={(e) => onFiles(e.target.files)} />
        </div>
      </div>
      {status && <p className="a-msg ok" style={{ marginTop: 12 }}>{status}</p>}
    </div>
  );
}
