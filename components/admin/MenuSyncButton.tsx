"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/components/admin/api";

/** Pulls the latest prices & dishes from the live menu (ammos-beach-bar.nina.cy). */
export function MenuSyncButton() {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  async function sync() {
    if (!confirm("Update the website menu from the live menu (ammos-beach-bar.nina.cy)?\n\nNew items are added and prices/descriptions updated. Your photos and homepage ticks are kept. Items no longer on the live menu are hidden.")) return;
    setBusy(true);
    setMsg(null);
    try {
      const r = await api<{ total: number; added: number; updated: number; hidden: number; categories: number }>("/api/admin/menu-sync", { method: "POST" });
      setMsg({ ok: true, text: `Done — ${r.total} items in ${r.categories} categories (${r.added} new, ${r.updated} updated, ${r.hidden} hidden).` });
      router.refresh();
    } catch (e) {
      setMsg({ ok: false, text: (e as Error).message });
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <button type="button" className="a-btn" onClick={sync} disabled={busy}>
        {busy ? "Syncing…" : "↻ Sync from live menu"}
      </button>
      {msg && (
        <span className={`a-msg ${msg.ok ? "ok" : "err"}`} style={{ maxWidth: 420 }}>
          {msg.text}
        </span>
      )}
    </>
  );
}
