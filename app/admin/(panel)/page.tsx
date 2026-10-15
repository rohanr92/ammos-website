import Link from "next/link";
import { and, asc, desc, eq, gte, ne, sql } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { startOfTodayCyprus } from "@/lib/data";
import { formatDateTime } from "@/lib/utils";
import { PageTop } from "@/components/admin/PageTop";
import { EmailTestButton } from "@/components/admin/EmailTestButton";
import { mailStatus } from "@/lib/mailer";

export const metadata = { title: "Dashboard" };

export default async function Dashboard() {
  const today = startOfTodayCyprus();
  const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
  const { bookings, events, messages } = schema;

  const [upcomingEvents, pending, monthBookings, unread, guestsAhead, latestBookings, latestMessages, nextEvents] = await Promise.all([
    db.$count(events, and(eq(events.published, true), gte(events.startsAt, today))),
    db.$count(bookings, eq(bookings.status, "pending")),
    db.$count(bookings, gte(bookings.createdAt, monthStart)),
    db.$count(messages, eq(messages.isRead, false)),
    db
      .select({ n: sql<number>`coalesce(sum(${bookings.guests}),0)::int` })
      .from(bookings)
      .where(and(ne(bookings.status, "cancelled"), gte(bookings.eventDate, today)))
      .then((r) => r[0]?.n ?? 0),
    db.select().from(bookings).orderBy(desc(bookings.createdAt)).limit(6),
    db.select().from(messages).orderBy(desc(messages.createdAt)).limit(6),
    db
      .select({
        id: events.id,
        title: events.title,
        startsAt: events.startsAt,
        capacity: events.capacity,
        booked: sql<number>`(select coalesce(sum(${bookings.guests}),0)::int from ${bookings} where ${bookings.eventId} = ${events.id} and ${bookings.status} <> 'cancelled')`,
      })
      .from(events)
      .where(and(eq(events.published, true), gte(events.startsAt, today)))
      .orderBy(asc(events.startsAt))
      .limit(6),
  ]);

  const mail = await mailStatus();
  const status = (s: string) => <span className={s === "confirmed" ? "pill-ok" : s === "cancelled" ? "pill-bad" : "pill-warn"}>{s}</span>;

  return (
    <>
      <PageTop
        title="Dashboard"
        actions={
          <>
            <Link href="/admin/events/new" className="a-btn primary">
              + New event
            </Link>
            <Link href="/admin/content" className="a-btn">
              Edit page texts
            </Link>
          </>
        }
      />
      <div className="a-content">
        <div className="a-stats">
          <Link href="/admin/bookings?status=pending" className="a-stat">
            <b>{pending}</b>
            <span>Bookings waiting for confirmation</span>
          </Link>
          <Link href="/admin/messages" className="a-stat">
            <b>{unread}</b>
            <span>Unread messages</span>
          </Link>
          <Link href="/admin/events" className="a-stat">
            <b>{upcomingEvents}</b>
            <span>Upcoming events</span>
          </Link>
          <Link href="/admin/bookings" className="a-stat">
            <b>{guestsAhead}</b>
            <span>Guests booked for upcoming events</span>
          </Link>
          <Link href="/admin/bookings" className="a-stat">
            <b>{monthBookings}</b>
            <span>Bookings this month</span>
          </Link>
        </div>

        <div className="a-grid-2">
          <section className="a-card">
            <div className="a-spread" style={{ marginBottom: 12 }}>
              <h2 style={{ margin: 0 }}>Latest bookings</h2>
              <Link href="/admin/bookings">All bookings →</Link>
            </div>
            {latestBookings.length ? (
              <table className="a-table">
                <tbody>
                  {latestBookings.map((b) => (
                    <tr key={b.id}>
                      <td>
                        <Link href={`/admin/bookings?open=${b.id}`} className="title">
                          {b.firstName} {b.lastName}
                        </Link>
                        <div className="a-help">
                          {b.guests} guests · {b.eventTitle}
                        </div>
                      </td>
                      <td style={{ textAlign: "right" }}>{status(b.status)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <p className="a-empty">No bookings yet.</p>
            )}
          </section>

          <section className="a-card">
            <div className="a-spread" style={{ marginBottom: 12 }}>
              <h2 style={{ margin: 0 }}>Latest messages</h2>
              <Link href="/admin/messages">All messages →</Link>
            </div>
            {latestMessages.length ? (
              <table className="a-table">
                <tbody>
                  {latestMessages.map((m) => (
                    <tr key={m.id} className={m.isRead ? "" : "unread"}>
                      <td>
                        <Link href={`/admin/messages?open=${m.id}`} className="title">
                          {m.firstName} {m.lastName}
                        </Link>
                        <div className="a-help clip" style={{ maxWidth: 320, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                          {m.subject} — {m.message}
                        </div>
                      </td>
                      <td className="a-help" style={{ textAlign: "right", whiteSpace: "nowrap" }}>
                        {formatDateTime(m.createdAt)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <p className="a-empty">No messages yet.</p>
            )}
          </section>
        </div>

        <section className="a-card" style={{ marginTop: 16 }}>
          <div className="a-spread" style={{ marginBottom: 8 }}>
            <h2 style={{ margin: 0 }}>Email</h2>
            {mail.configured ? <span className="pill-ok">connected to {mail.host}</span> : <span className="pill-warn">not set up</span>}
          </div>
          <p className="a-help" style={{ marginBottom: 12 }}>
            {mail.configured
              ? `Booking & contact form emails are sent from ${mail.user || mail.from} to ${mail.to.join(", ")}. Guests also get a confirmation email.`
              : "Bookings and messages are saved here in the admin, but no emails are sent yet. Add your SMTP details to the .env file (see DEPLOY.md → Email), restart the site, then press the button below."}
          </p>
          <EmailTestButton disabled={!mail.configured} />
        </section>

        <section className="a-card" style={{ marginTop: 16 }}>
          <div className="a-spread" style={{ marginBottom: 12 }}>
            <h2 style={{ margin: 0 }}>Next events</h2>
            <Link href="/admin/events">Manage events →</Link>
          </div>
          {nextEvents.length ? (
            <table className="a-table">
              <thead>
                <tr>
                  <th>Event</th>
                  <th>When</th>
                  <th>Booked</th>
                </tr>
              </thead>
              <tbody>
                {nextEvents.map((e) => (
                  <tr key={e.id}>
                    <td>
                      <Link href={`/admin/events/${e.id}`} className="title">
                        {e.title}
                      </Link>
                    </td>
                    <td>{formatDateTime(e.startsAt)}</td>
                    <td>
                      <Link href={`/admin/bookings?event=${e.id}`}>
                        {e.booked}
                        {e.capacity ? ` / ${e.capacity}` : ""} guests
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <p className="a-empty">
              No upcoming events. <Link href="/admin/events/new">Create one</Link>
            </p>
          )}
        </section>
      </div>
    </>
  );
}
