"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/components/admin/api";

type Action = { key: string; label: string; danger?: boolean };

/**
 * Bulk actions for an admin table. Rows need <input type="checkbox" data-bulk={group} value={id}>,
 * the header can have <input type="checkbox" data-bulk-all={group}>.
 */
export function BulkBar({ group, endpoint, actions, noun = "item" }: { group: string; endpoint: string; actions: Action[]; noun?: string }) {
  const router = useRouter();
  const [ids, setIds] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  useEffect(() => {
    const boxes = () => Array.from(document.querySelectorAll<HTMLInputElement>(`input[data-bulk="${group}"]`));
    const sync = () => setIds(boxes().filter((b) => b.checked).map((b) => b.value));
    const onChange = (e: Event) => {
      const t = e.target as HTMLInputElement;
      if (t.dataset.bulkAll === group) boxes().forEach((b) => (b.checked = t.checked));
      if (t.dataset.bulk === group || t.dataset.bulkAll === group) sync();
    };
    document.addEventListener("change", onChange);
    sync();
    return () => document.removeEventListener("change", onChange);
  }, [group]);

  const clear = () => {
    document.querySelectorAll<HTMLInputElement>(`input[data-bulk="${group}"], input[data-bulk-all="${group}"]`).forEach((b) => (b.checked = false));
    setIds([]);
  };

  async function run(a: Action) {
    if (!ids.length) return;
    const what = `${ids.length} ${noun}${ids.length === 1 ? "" : "s"}`;
    if (a.danger && !confirm(`${a.label} ${what}? This cannot be undone.`)) return;
    setBusy(true);
    setMsg(null);
    try {
      const r = await api<{ count: number }>(endpoint, { method: "POST", json: { ids, action: a.key } });
      setMsg({ ok: true, text: `Done — ${r.count} ${noun}${r.count === 1 ? "" : "s"} updated.` });
      clear();
      router.refresh();
    } catch (e) {
      setMsg({ ok: false, text: (e as Error).message });
    } finally {
      setBusy(false);
    }
  }

  if (!ids.length && !msg) return null;
  return (
    <div className="a-bulk">
      {ids.length > 0 ? (
        <>
          <b>
            {ids.length} selected
          </b>
          {actions.map((a) => (
            <button key={a.key} type="button" className={`a-btn sm${a.danger ? " danger" : ""}`} disabled={busy} onClick={() => run(a)}>
              {a.label}
            </button>
          ))}
          <button type="button" className="a-btn sm ghost" onClick={clear} disabled={busy}>
            Clear
          </button>
        </>
      ) : null}
      {msg && <span className={`a-msg ${msg.ok ? "ok" : "err"}`}>{msg.text}</span>}
    </div>
  );
}
