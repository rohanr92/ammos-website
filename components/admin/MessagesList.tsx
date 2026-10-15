"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/components/admin/api";
import { BulkBar } from "@/components/admin/BulkBar";

type Row = {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  subject: string;
  visitDate: string;
  guests: number | null;
  message: string;
  source: string;
  isRead: boolean;
  createdLabel: string;
};

export function MessagesList({ rows, openId }: { rows: Row[]; openId?: string }) {
  const router = useRouter();
  const [open, setOpen] = useState<string | null>(openId && rows.some((r) => r.id === openId) ? openId : null);
  const current = rows.find((r) => r.id === open) ?? null;

  // opening a message marks it as read
  useEffect(() => {
    if (current && !current.isRead) api(`/api/admin/messages/${current.id}`, { method: "PATCH", json: { isRead: true } }).then(() => router.refresh()).catch(() => {});
  }, [current, router]);

  if (!rows.length) return <div className="a-table-wrap"><p className="a-empty">No messages.</p></div>;

  async function setRead(id: string, isRead: boolean) {
    await api(`/api/admin/messages/${id}`, { method: "PATCH", json: { isRead } });
    router.refresh();
  }
  async function remove(id: string) {
    if (!confirm("Delete this message?")) return;
    await api(`/api/admin/messages/${id}`, { method: "DELETE" });
    setOpen(null);
    router.refresh();
  }

  return (
    <>
      <BulkBar
        group="messages"
        endpoint="/api/admin/messages/bulk"
        noun="message"
        actions={[
          { key: "read", label: "Mark read" },
          { key: "unread", label: "Mark unread" },
          { key: "delete", label: "Delete", danger: true },
        ]}
      />
      <div className="a-table-wrap">
        <table className="a-table">
          <thead>
            <tr>
              <th className="a-col-check">
                <input type="checkbox" data-bulk-all="messages" aria-label="Select all" />
              </th>
              <th>From</th>
              <th>Subject</th>
              <th>Message</th>
              <th>Received</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((m) => (
              <tr key={m.id} className={m.isRead ? "" : "unread"} onClick={() => setOpen(m.id)} style={{ cursor: "pointer" }}>
                <td className="a-col-check" onClick={(e) => e.stopPropagation()}>
                  <input type="checkbox" data-bulk="messages" value={m.id} aria-label="Select" />
                </td>
                <td>
                  {m.firstName} {m.lastName}
                  <div className="a-help">{m.email}</div>
                </td>
                <td>
                  {m.subject}
                  <div className="a-help">via {m.source}</div>
                </td>
                <td>
                  <span className="clip" style={{ display: "block" }}>
                    {m.message}
                  </span>
                </td>
                <td className="a-help" style={{ whiteSpace: "nowrap" }}>
                  {m.createdLabel}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {current && (
        <>
          <div className="a-drawer-bg" onClick={() => setOpen(null)} />
          <aside className="a-drawer" role="dialog" aria-label="Message">
            <div className="a-spread">
              <h2 style={{ fontSize: 18 }}>
                {current.firstName} {current.lastName}
              </h2>
              <button type="button" className="a-btn sm ghost" onClick={() => setOpen(null)}>
                Close ✕
              </button>
            </div>
            <dl className="a-kv">
              <dt>Email</dt>
              <dd>
                <a href={`mailto:${current.email}`}>{current.email}</a>
              </dd>
              {current.phone && (
                <>
                  <dt>Phone</dt>
                  <dd>
                    <a href={`tel:${current.phone.replace(/\s/g, "")}`}>{current.phone}</a> ·{" "}
                    <a href={`https://wa.me/${current.phone.replace(/[^\d]/g, "")}`} target="_blank" rel="noopener noreferrer">
                      WhatsApp
                    </a>
                  </dd>
                </>
              )}
              <dt>Subject</dt>
              <dd>{current.subject}</dd>
              {current.visitDate && (
                <>
                  <dt>Date wanted</dt>
                  <dd>{current.visitDate}</dd>
                </>
              )}
              {current.guests && (
                <>
                  <dt>Guests</dt>
                  <dd>{current.guests}</dd>
                </>
              )}
              <dt>Form</dt>
              <dd>{current.source}</dd>
              <dt>Received</dt>
              <dd>{current.createdLabel}</dd>
            </dl>
            <div className="a-detail">{current.message}</div>
            <div className="a-row">
              <a className="a-btn primary" href={`mailto:${current.email}?subject=${encodeURIComponent(`Re: ${current.subject} — Ammos Makenzy Beach`)}`}>
                Reply by email
              </a>
              <button type="button" className="a-btn" onClick={() => setRead(current.id, false)}>
                Mark unread
              </button>
              <span style={{ flex: 1 }} />
              <button type="button" className="a-btn danger sm" onClick={() => remove(current.id)}>
                Delete
              </button>
            </div>
          </aside>
        </>
      )}
    </>
  );
}
