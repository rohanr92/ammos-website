import Link from "next/link";
import { and, desc, eq, ilike, or, type SQL } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { formatDateTime } from "@/lib/utils";
import { PageTop } from "@/components/admin/PageTop";
import { BookingsTable } from "@/components/admin/BookingsTable";

export const metadata = { title: "Bookings" };
export const dynamic = "force-dynamic";

type Props = { searchParams: Promise<{ status?: string; event?: string; q?: string; open?: string }> };

export default async function BookingsPage({ searchParams }: Props) {
  const { status = "", event = "", q = "", open = "" } = await searchParams;
  const { bookings, events } = schema;
  const where: SQL[] = [];
  if (["pending", "confirmed", "cancelled"].includes(status)) where.push(eq(bookings.status, status));
  if (/^[0-9a-f-]{36}$/i.test(event)) where.push(eq(bookings.eventId, event));
  if (q) {
    const term = `%${q.slice(0, 80).replace(/[%_]/g, "\\$&")}%`;
    where.push(or(ilike(bookings.firstName, term), ilike(bookings.lastName, term), ilike(bookings.email, term), ilike(bookings.phone, term), ilike(bookings.reference, term))!);
  }
  const [rows, eventOptions] = await Promise.all([
    db.select().from(bookings).where(where.length ? and(...where) : undefined).orderBy(desc(bookings.createdAt)).limit(500),
    db.select({ id: events.id, title: events.title, startsAt: events.startsAt }).from(events).orderBy(desc(events.startsAt)).limit(200),
  ]);
  const guests = rows.filter((r) => r.status !== "cancelled").reduce((n, r) => n + r.guests, 0);
  const exportQs = new URLSearchParams({ ...(status ? { status } : {}), ...(event ? { event } : {}) }).toString();
  const tab = (val: string, label: string) => {
    const p = new URLSearchParams({ ...(val ? { status: val } : {}), ...(event ? { event } : {}) }).toString();
    return (
      <Link key={val} href={`/admin/bookings${p ? `?${p}` : ""}`} className={status === val ? "is-active" : ""}>
        {label}
      </Link>
    );
  };

  return (
    <>
      <PageTop
        title="Event bookings"
        actions={
          <a className="a-btn" href={`/api/admin/bookings/export${exportQs ? `?${exportQs}` : ""}`}>
            ⬇ Export to Excel (CSV)
          </a>
        }
      />
      <div className="a-content">
        <p className="a-desc">
          Every booking from the event pages lands here (and in your inbox). Change the status to <b>confirmed</b> and tick “email guest” to send the confirmation automatically.
        </p>
        <div className="a-toolbar">
          <form className="a-search" action="/admin/bookings">
            <div className="a-tabs" style={{ marginRight: 8 }}>
              {tab("", "All")}
              {tab("pending", "Pending")}
              {tab("confirmed", "Confirmed")}
              {tab("cancelled", "Cancelled")}
            </div>
            {status && <input type="hidden" name="status" value={status} />}
            <select name="event" defaultValue={event} className="a-input" style={{ width: 260 }}>
              <option value="">All events</option>
              {eventOptions.map((e) => (
                <option key={e.id} value={e.id}>
                  {e.title} — {formatDateTime(e.startsAt).split(",").slice(0, 2).join(",")}
                </option>
              ))}
            </select>
            <input name="q" defaultValue={q} className="a-input" placeholder="Name, email, phone, ref…" style={{ width: 220 }} />
            <button className="a-btn" type="submit">
              Filter
            </button>
            {(q || event || status) && (
              <Link className="a-btn ghost" href="/admin/bookings">
                Clear
              </Link>
            )}
          </form>
          <span className="a-help">
            {rows.length} bookings · {guests} guests
          </span>
        </div>
        <BookingsTable
          openId={open}
          rows={rows.map((b) => ({ ...b, createdAt: b.createdAt.toISOString(), eventDate: b.eventDate?.toISOString() ?? null, updatedAt: b.updatedAt.toISOString(), createdLabel: formatDateTime(b.createdAt), eventLabel: b.eventDate ? formatDateTime(b.eventDate) : "" }))}
        />
      </div>
    </>
  );
}
