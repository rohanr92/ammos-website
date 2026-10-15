"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { FieldInput, type AnyField } from "@/components/admin/Fields";
import { api } from "@/components/admin/api";

/** Edits the texts & images of one website section (Admin → Page content). */
export function ContentForm({ sectionKey, fields, initial, previewUrl }: { sectionKey: string; fields: AnyField[]; initial: Record<string, unknown>; previewUrl: string }) {
  const router = useRouter();
  const [values, setValues] = useState(initial);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setMsg(null);
    try {
      await api(`/api/admin/content/${sectionKey}`, { method: "PUT", json: values });
      setMsg({ ok: true, text: "Saved — the website is updated." });
      router.refresh();
    } catch (err) {
      setMsg({ ok: false, text: (err as Error).message });
    } finally {
      setSaving(false);
    }
  }

  async function reset() {
    if (!confirm("Reset this section to the original design texts and photos?")) return;
    try {
      await api(`/api/admin/content/${sectionKey}`, { method: "DELETE" });
      window.location.reload();
    } catch (err) {
      setMsg({ ok: false, text: (err as Error).message });
    }
  }

  return (
    <form className="a-card a-form" onSubmit={save}>
      {fields.map((f) => (
        <FieldInput key={f.name} field={f} value={values[f.name]} onChange={(v) => setValues((s) => ({ ...s, [f.name]: v }))} />
      ))}
      <div className="a-form-actions">
        <button type="submit" className="a-btn primary" disabled={saving}>
          {saving ? "Saving…" : "Save changes"}
        </button>
        <a className="a-btn ghost" href={previewUrl} target="_blank" rel="noopener noreferrer">
          View on website ↗
        </a>
        <span style={{ flex: 1 }} />
        <button type="button" className="a-btn danger sm" onClick={reset}>
          Reset to original
        </button>
        {msg && <span className={`a-msg ${msg.ok ? "ok" : "err"}`} style={{ width: "100%" }}>{msg.text}</span>}
      </div>
    </form>
  );
}
