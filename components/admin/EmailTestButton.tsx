"use client";

import { useState } from "react";
import { api } from "@/components/admin/api";

/** Sends a test email so you can check that booking & contact emails really arrive. */
export function EmailTestButton({ disabled }: { disabled?: boolean }) {
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  async function run() {
    setBusy(true);
    setMsg(null);
    try {
      const r = await api<{ to: string[] }>("/api/admin/email-test", { method: "POST" });
      setMsg({ ok: true, text: `Test email sent to ${r.to.join(", ")} — check the inbox (and spam folder).` });
    } catch (e) {
      setMsg({ ok: false, text: (e as Error).message });
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="a-row" style={{ flexWrap: "wrap" }}>
      <button type="button" className="a-btn" onClick={run} disabled={busy || disabled}>
        {busy ? "Sending…" : "Send test email"}
      </button>
      {msg && <span className={`a-msg ${msg.ok ? "ok" : "err"}`}>{msg.text}</span>}
    </div>
  );
}
