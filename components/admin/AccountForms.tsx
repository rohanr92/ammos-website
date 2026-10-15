"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/components/admin/api";

type Msg = { ok: boolean; text: string } | null;

export function AccountForms({ name, email }: { name: string; email: string }) {
  const router = useRouter();
  const [msg, setMsg] = useState<Msg>(null);
  const [pwMsg, setPwMsg] = useState<Msg>(null);

  async function saveName(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    try {
      await api("/api/admin/account", { method: "POST", json: { action: "profile", name: fd.get("name") } });
      setMsg({ ok: true, text: "Name saved." });
      router.refresh();
    } catch (err) {
      setMsg({ ok: false, text: (err as Error).message });
    }
  }

  async function changePassword(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    const fd = new FormData(form);
    if (fd.get("newPassword") !== fd.get("confirm")) return setPwMsg({ ok: false, text: "The two new passwords are not the same." });
    try {
      await api("/api/admin/account", { method: "POST", json: { action: "password", currentPassword: fd.get("currentPassword"), newPassword: fd.get("newPassword") } });
      form.reset();
      setPwMsg({ ok: true, text: "Password changed. Other devices have been signed out." });
    } catch (err) {
      setPwMsg({ ok: false, text: (err as Error).message });
    }
  }

  async function logoutAll() {
    if (!confirm("Sign out on all other phones and computers?")) return;
    await api("/api/admin/account", { method: "POST", json: { action: "logoutAll" } });
    setMsg({ ok: true, text: "All other devices are signed out." });
  }

  return (
    <div className="a-grid-2">
      <form className="a-card a-form" onSubmit={saveName}>
        <h2 className="a-field">Profile</h2>
        <div className="a-field">
          <label>Email (login)</label>
          <input className="a-input" value={email} disabled />
        </div>
        <div className="a-field">
          <label htmlFor="acc-name">Name</label>
          <input id="acc-name" name="name" className="a-input" defaultValue={name} required maxLength={100} />
        </div>
        <div className="a-field a-row">
          <button className="a-btn primary" type="submit">
            Save
          </button>
          <button className="a-btn" type="button" onClick={logoutAll}>
            Sign out other devices
          </button>
        </div>
        {msg && <p className={`a-field a-msg ${msg.ok ? "ok" : "err"}`}>{msg.text}</p>}
      </form>

      <form className="a-card a-form" onSubmit={changePassword}>
        <h2 className="a-field">Change password</h2>
        <div className="a-field">
          <label htmlFor="pw-cur">Current password</label>
          <input id="pw-cur" name="currentPassword" type="password" className="a-input" required autoComplete="current-password" />
        </div>
        <div className="a-field">
          <label htmlFor="pw-new">New password</label>
          <input id="pw-new" name="newPassword" type="password" className="a-input" required minLength={12} autoComplete="new-password" />
          <span className="a-help">At least 12 characters with letters and numbers.</span>
        </div>
        <div className="a-field">
          <label htmlFor="pw-conf">Repeat new password</label>
          <input id="pw-conf" name="confirm" type="password" className="a-input" required minLength={12} autoComplete="new-password" />
        </div>
        <div className="a-field">
          <button className="a-btn primary" type="submit">
            Change password
          </button>
        </div>
        {pwMsg && <p className={`a-field a-msg ${pwMsg.ok ? "ok" : "err"}`}>{pwMsg.text}</p>}
      </form>
    </div>
  );
}

/** "Email me new bookings & messages" switch for one user. */
export function NotifyToggle({ id, on }: { id: string; on: boolean }) {
  const router = useRouter();
  const [value, setValue] = useState(on);
  const [busy, setBusy] = useState(false);
  async function toggle() {
    setBusy(true);
    try {
      await api(`/api/admin/users/${id}`, { method: "PATCH", json: { notify: !value } });
      setValue(!value);
      router.refresh();
    } catch (err) {
      alert((err as Error).message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <button type="button" className={`a-btn sm ${value ? "" : "ghost"}`} onClick={toggle} disabled={busy} title="Email this person every new booking and message">
      {value ? "🔔 On" : "🔕 Off"}
    </button>
  );
}

export function UsersManager({ users, meId }: { users: { id: string; email: string; name: string; role: string; lastLogin: string; notify: boolean }[]; meId: string }) {
  const router = useRouter();
  const [msg, setMsg] = useState<Msg>(null);

  async function add(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    const fd = new FormData(form);
    try {
      await api("/api/admin/users", { method: "POST", json: { ...Object.fromEntries(fd.entries()), notify: fd.get("notify") === "on" } });
      form.reset();
      setMsg({ ok: true, text: "User added. They'll get an email for every new booking and message (if notifications are on). Send them the password privately — they should change it after logging in." });
      router.refresh();
    } catch (err) {
      setMsg({ ok: false, text: (err as Error).message });
    }
  }
  async function remove(id: string, email: string) {
    if (!confirm(`Remove admin access for ${email}?`)) return;
    try {
      await api(`/api/admin/users/${id}`, { method: "DELETE" });
      router.refresh();
    } catch (err) {
      setMsg({ ok: false, text: (err as Error).message });
    }
  }

  return (
    <section className="a-card" style={{ marginTop: 16 }}>
      <h2>Admin users</h2>
      <div className="a-table-wrap" style={{ marginBottom: 18 }}>
        <table className="a-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Role</th>
              <th>Notifications</th>
              <th>Last login</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {users.map((u) => (
              <tr key={u.id}>
                <td>{u.name}</td>
                <td>{u.email}</td>
                <td>{u.role === "owner" ? <span className="pill-ok">owner</span> : <span className="pill-off">editor</span>}</td>
                <td>
                  <NotifyToggle id={u.id} on={u.notify} />
                </td>
                <td className="a-help">{u.lastLogin}</td>
                <td style={{ textAlign: "right" }}>
                  {u.id !== meId && (
                    <button type="button" className="a-btn danger sm" onClick={() => remove(u.id, u.email)}>
                      Remove
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <form className="a-form" onSubmit={add}>
        <div className="a-field half">
          <label htmlFor="u-name">Name</label>
          <input id="u-name" name="name" className="a-input" maxLength={100} />
        </div>
        <div className="a-field half">
          <label htmlFor="u-email">Email</label>
          <input id="u-email" name="email" type="email" className="a-input" required />
        </div>
        <div className="a-field half">
          <label htmlFor="u-pass">Temporary password</label>
          <input id="u-pass" name="password" type="text" className="a-input" required minLength={12} autoComplete="off" />
        </div>
        <div className="a-field half">
          <label htmlFor="u-role">Role</label>
          <select id="u-role" name="role" className="a-input" defaultValue="editor">
            <option value="editor">Editor — manages content, events & bookings</option>
            <option value="owner">Owner — also manages users</option>
          </select>
        </div>
        <div className="a-field">
          <label className="a-check">
            <input type="checkbox" name="notify" defaultChecked /> Email this person every new booking &amp; contact message
          </label>
        </div>
        <div className="a-field">
          <button className="a-btn primary" type="submit" style={{ justifySelf: "start" }}>
            + Add admin user
          </button>
        </div>
        {msg && <p className={`a-field a-msg ${msg.ok ? "ok" : "err"}`}>{msg.text}</p>}
      </form>
    </section>
  );
}
