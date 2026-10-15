"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/components/admin/api";
import { BulkBar } from "@/components/admin/BulkBar";

type Row = {
  id: string;
  reference: string;
  eventTitle: string;
  eventLabel: string;
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  guests: number;
  seating: string;
  occasion: string;
  message: string;
  status: string;
  adminNotes: string;
  marketingOptIn: boolean;
  createdLabel: string;
};

const pill = (s: string) => <span className={s === "confirmed" ? "pill-ok" : s === "cancelled" ? "pill-bad" : "pill-warn"}>{s}</span>;

export function BookingsTable({ rows, openId }: { rows: Row[]; openId?: string }) {
  const router = useRouter();
  const [open, setOpen] = useState<string | null>(openId && rows.some((r) => r.id === openId) ? openId : null);
  const current = rows.find((r) => r.id === open) ?? null;

  if (!rows.length) return <div className="a-table-wrap"><p className="a-empty">No bookings found.</p></div>;

  return (
    <>
      <BulkBar
        group="bookings"
        endpoint="/api/admin/bookings/bulk"
        noun="booking"
        actions={[
          { key: "confirmed", label: "Mark confirmed" },
          { key: "cancelled", label: "Mark cancelled" },
          { key: "delete", label: "Delete", danger: true },
        ]}
      />
      <div className="a-table-wrap">
        <table className="a-table">
          <thead>
            <tr>
              <th className="a-col-check">
                <input type="checkbox" data-bulk-all="bookings" aria-label="Select all" />
              </th>
              <th>Guest</th>
              <th>Event</th>
              <th>Guests</th>
              <th>Contact</th>
              <th>Status</th>
              <th>Received</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {rows.map((b) => (
              <tr key={b.id}>
                <td className="a-col-check">
                  <input type="checkbox" data-bulk="bookings" value={b.id} aria-label="Select" />
                </td>
                <td>
                  <button type="button" onClick={() => setOpen(b.id)} className="title" style={{ background: "none", border: 0, padding: 0, color: "var(--a-text)", font: "inherit", fontWeight: 500, cursor: "pointer" }}>
                    {b.firstName} {b.lastName}
                  </button>
                  <div className="a-help">{b.reference}</div>
                </td>
                <td>
                  {b.eventTitle}
                  <div className="a-help">{b.eventLabel}</div>
                </td>
                <td>
                  <b>{b.guests}</b>
                </td>
                <td>
                  <a href={`tel:${b.phone.replace(/\s/g, "")}`}>{b.phone}</a>
                  <div className="a-help">
                    <a href={`mailto:${b.email}`}>{b.email}</a>
                  </div>
                </td>
                <td>{pill(b.status)}</td>
                <td className="a-help">{b.createdLabel}</td>
                <td>
                  <button type="button" className="a-btn sm" onClick={() => setOpen(b.id)}>
                    Open
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {current && <BookingDrawer key={current.id} booking={current} onClose={() => setOpen(null)} onChanged={() => router.refresh()} />}
    </>
  );
}

function BookingDrawer({ booking, onClose, onChanged }: { booking: Row; onClose: () => void; onChanged: () => void }) {
  const [status, setStatus] = useState(booking.status);
  const [notes, setNotes] = useState(booking.adminNotes);
  const [guests, setGuests] = useState(String(booking.guests));
  const [notify, setNotify] = useState(true);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [busy, setBusy] = useState(false);

  async function save() {
    setBusy(true);
    setMsg(null);
    try {
      const res = await api<{ emailed: boolean }>(`/api/admin/bookings/${booking.id}`, { method: "PATCH", json: { status, adminNotes: notes, guests: Number(guests), notifyGuest: notify } });
      setMsg({ ok: true, text: `Saved.${res.emailed ? " The guest was emailed." : ""}` });
      onChanged();
    } catch (e) {
      setMsg({ ok: false, text: (e as Error).message });
    } finally {
      setBusy(false);
    }
  }
  async function remove() {
    if (!confirm("Delete this booking permanently?")) return;
    await api(`/api/admin/bookings/${booking.id}`, { method: "DELETE" });
    onClose();
    onChanged();
  }

  return (
    <>
      <div className="a-drawer-bg" onClick={onClose} />
      <aside className="a-drawer" role="dialog" aria-label="Booking details">
        <div className="a-spread">
          <h2 style={{ fontSize: 18 }}>
            {booking.firstName} {booking.lastName}
          </h2>
          <button type="button" className="a-btn sm ghost" onClick={onClose}>
            Close ✕
          </button>
        </div>
        <dl className="a-kv">
          <dt>Reference</dt>
          <dd>{booking.reference}</dd>
          <dt>Event</dt>
          <dd>
            {booking.eventTitle}
            <br />
            <span className="a-help">{booking.eventLabel}</span>
          </dd>
          <dt>Phone</dt>
          <dd>
            <a href={`tel:${booking.phone.replace(/\s/g, "")}`}>{booking.phone}</a> ·{" "}
            <a href={`https://wa.me/${booking.phone.replace(/[^\d]/g, "")}`} target="_blank" rel="noopener noreferrer">
              WhatsApp
            </a>
          </dd>
          <dt>Email</dt>
          <dd>
            <a href={`mailto:${booking.email}?subject=${encodeURIComponent(`Your booking ${booking.reference} — Ammos`)}`}>{booking.email}</a>
          </dd>
          <dt>Seating</dt>
          <dd>{booking.seating || "—"}</dd>
          <dt>Occasion</dt>
          <dd>{booking.occasion || "—"}</dd>
          <dt>Newsletter</dt>
          <dd>{booking.marketingOptIn ? "Yes, wants news" : "No"}</dd>
          <dt>Received</dt>
          <dd>{booking.createdLabel}</dd>
        </dl>
        {booking.message && (
          <div>
            <span className="a-label">Guest notes</span>
            <div className="a-detail">{booking.message}</div>
          </div>
        )}
        <div className="a-form">
          <div className="a-field half">
            <label htmlFor="bk-status">Status</label>
            <select id="bk-status" className="a-input" value={status} onChange={(e) => setStatus(e.target.value)}>
              <option value="pending">Pending</option>
              <option value="confirmed">Confirmed</option>
              <option value="cancelled">Cancelled</option>
            </select>
          </div>
          <div className="a-field half">
            <label htmlFor="bk-guests">Guests</label>
            <input id="bk-guests" type="number" min={1} className="a-input" value={guests} onChange={(e) => setGuests(e.target.value)} />
          </div>
          <div className="a-field">
            <label htmlFor="bk-notes">Internal notes (only staff see these)</label>
            <textarea id="bk-notes" className="a-input" value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Table number, deposit paid…" />
          </div>
          {status !== booking.status && status !== "pending" && (
            <label className="a-check a-field">
              <input type="checkbox" checked={notify} onChange={(e) => setNotify(e.target.checked)} />
              <span>Email the guest that the booking is {status}</span>
            </label>
          )}
        </div>
        <div className="a-row">
          <button type="button" className="a-btn primary" onClick={save} disabled={busy}>
            {busy ? "Saving…" : "Save"}
          </button>
          <span style={{ flex: 1 }} />
          <button type="button" className="a-btn danger sm" onClick={remove}>
            Delete booking
          </button>
        </div>
        {msg && <p className={`a-msg ${msg.ok ? "ok" : "err"}`}>{msg.text}</p>}
      </aside>
    </>
  );
}
