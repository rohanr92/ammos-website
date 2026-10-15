"use client";

import { useState } from "react";

export function LoginForm({ next }: { next: string }) {
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setBusy(true);
    setError("");
    const fd = new FormData(e.currentTarget);
    try {
      const res = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: fd.get("email"), password: fd.get("password") }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.ok) throw new Error(data.error || "Login failed");
      window.location.href = next;
    } catch (err) {
      setError((err as Error).message);
      setBusy(false);
    }
  }

  return (
    <form onSubmit={onSubmit} style={{ display: "grid", gap: 14 }}>
      <div className="a-field">
        <label htmlFor="email">Email</label>
        <input id="email" name="email" type="email" className="a-input" required autoComplete="username" autoFocus />
      </div>
      <div className="a-field">
        <label htmlFor="password">Password</label>
        <input id="password" name="password" type="password" className="a-input" required autoComplete="current-password" />
      </div>
      {error && <div className="a-msg err">{error}</div>}
      <button className="a-btn primary" type="submit" disabled={busy} style={{ padding: "12px 16px" }}>
        {busy ? "Checking…" : "Log in"}
      </button>
    </form>
  );
}
