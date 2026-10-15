"use client";

import { useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { api, uploadFile } from "@/components/admin/api";

/** Upload many dish photos at once — each file is matched to a dish by its file name. */
export function MenuPhotosUpload() {
  const router = useRouter();
  const ref = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState("");
  const [missed, setMissed] = useState<string[]>([]);

  async function onFiles(files: FileList | null) {
    const list = Array.from(files ?? []).filter((f) => f.type.startsWith("image/"));
    if (!list.length) return;
    setBusy(true);
    setMissed([]);
    let ok = 0;
    const notFound: string[] = [];
    for (const [i, file] of list.entries()) {
      setStatus(`Uploading ${i + 1} of ${list.length}: ${file.name}`);
      try {
        const url = await uploadFile(file);
        const r = await api<{ matched: string[] }>("/api/admin/menu-photo", { method: "POST", json: { fileName: file.name, url } });
        if (r.matched.length) ok++;
        else notFound.push(file.name);
      } catch {
        notFound.push(file.name);
      }
    }
    setStatus(`${ok} of ${list.length} photo${list.length === 1 ? "" : "s"} matched to dishes.`);
    setMissed(notFound);
    setBusy(false);
    if (ref.current) ref.current.value = "";
    router.refresh();
  }

  return (
    <div className="a-card" style={{ marginBottom: 16 }}>
      <div className="a-spread">
        <div>
          <b>Add dish photos in bulk</b>
          <div className="a-help">
            Name each photo like the dish, e.g. <code>Tataki Tuna.jpg</code> or <code>oktapodi-kythira.jpg</code>. Photos appear when guests hover the dish in the homepage menu block.
          </div>
        </div>
        <button type="button" className="a-btn primary" onClick={() => ref.current?.click()} disabled={busy}>
          {busy ? "Uploading…" : "Choose photos"}
        </button>
        <input ref={ref} type="file" multiple hidden accept="image/jpeg,image/png,image/webp,image/avif" onChange={(e) => onFiles(e.target.files)} />
      </div>
      {status && <p className="a-msg ok" style={{ marginTop: 12 }}>{status}</p>}
      {missed.length > 0 && (
        <p className="a-msg err" style={{ marginTop: 8 }}>
          No dish found for: {missed.join(", ")} — rename the file to the exact dish name, or open the dish and upload its photo there.
        </p>
      )}
    </div>
  );
}
