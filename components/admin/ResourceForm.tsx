"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { FieldInput, type AnyField } from "@/components/admin/Fields";
import { api } from "@/components/admin/api";

/** Create / edit form for any admin resource (events, menu items, news…). */
export function ResourceForm({
  resource,
  singular,
  id,
  fields,
  initial,
  viewUrl,
}: {
  resource: string;
  singular: string;
  id: string | null;
  fields: AnyField[];
  initial: Record<string, unknown>;
  viewUrl?: string | null;
}) {
  const router = useRouter();
  const [values, setValues] = useState<Record<string, unknown>>(initial);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  async function save(e: React.FormEvent, andClose = false) {
    e.preventDefault();
    setSaving(true);
    setMsg(null);
    try {
      const data = await api<{ row: { id: string } }>(id ? `/api/admin/${resource}/${id}` : `/api/admin/${resource}`, {
        method: id ? "PUT" : "POST",
        json: values,
      });
      if (andClose) {
        router.push(`/admin/${resource}`);
        router.refresh();
        return;
      }
      if (!id) {
        router.replace(`/admin/${resource}/${data.row.id}?saved=1`);
        router.refresh();
        return;
      }
      setMsg({ ok: true, text: "Saved — the website is updated." });
      router.refresh();
    } catch (err) {
      setMsg({ ok: false, text: (err as Error).message });
    } finally {
      setSaving(false);
    }
  }

  async function remove() {
    if (!id) return;
    const extra = resource === "menu-categories" ? "\n\nAll menu items in this category will be deleted too." : resource === "events" ? "\n\nBookings for this event are kept." : "";
    if (!confirm(`Delete this ${singular}? This cannot be undone.${extra}`)) return;
    try {
      await api(`/api/admin/${resource}/${id}`, { method: "DELETE" });
      router.push(`/admin/${resource}`);
      router.refresh();
    } catch (err) {
      setMsg({ ok: false, text: (err as Error).message });
    }
  }

  return (
    <form className="a-card a-form" onSubmit={(e) => save(e)}>
      {fields.map((f) => (
        <FieldInput key={f.name} field={f} value={values[f.name]} onChange={(v) => setValues((s) => ({ ...s, [f.name]: v }))} />
      ))}
      <div className="a-form-actions">
        <button type="submit" className="a-btn primary" disabled={saving}>
          {saving ? "Saving…" : id ? "Save changes" : `Create ${singular}`}
        </button>
        <button type="button" className="a-btn" disabled={saving} onClick={(e) => save(e, true)}>
          Save & close
        </button>
        {viewUrl && (
          <a className="a-btn ghost" href={viewUrl} target="_blank" rel="noopener noreferrer">
            View on website ↗
          </a>
        )}
        <span style={{ flex: 1 }} />
        {id && (
          <button type="button" className="a-btn danger" onClick={remove}>
            Delete
          </button>
        )}
        {msg && <span className={`a-msg ${msg.ok ? "ok" : "err"}`} style={{ width: "100%" }}>{msg.text}</span>}
      </div>
    </form>
  );
}
