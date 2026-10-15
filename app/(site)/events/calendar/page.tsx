import Link from "next/link";
import type { Metadata } from "next";
import { getContent } from "@/lib/content";
import { getEventsBetween } from "@/lib/data";
import { pageMeta } from "@/lib/seo";
import { cyprusDayKey, cyprusLocalToDate, eventDateParts } from "@/lib/utils";
import { PageHero } from "@/components/site/PageHero";

export async function generateMetadata(): Promise<Metadata> {
  const h = await getContent("page.headers");
  return pageMeta({ title: "Events calendar", description: h.calendarText, path: "/events/calendar", image: h.eventsImage });
}

const DOW = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
const pad = (n: number) => String(n).padStart(2, "0");

export default async function CalendarPage({ searchParams }: { searchParams: Promise<{ month?: string }> }) {
  const sp = await searchParams;
  const todayKey = cyprusDayKey(new Date());
  const m = /^(\d{4})-(\d{2})$/.exec(sp.month ?? "");
  const year = m ? Number(m[1]) : Number(todayKey.slice(0, 4));
  const month = m ? Math.min(12, Math.max(1, Number(m[2]))) : Number(todayKey.slice(5, 7));

  const first = cyprusLocalToDate(`${year}-${pad(month)}-01T00:00`)!;
  const nextY = month === 12 ? year + 1 : year;
  const nextM = month === 12 ? 1 : month + 1;
  const prevY = month === 1 ? year - 1 : year;
  const prevM = month === 1 ? 12 : month - 1;
  const after = cyprusLocalToDate(`${nextY}-${pad(nextM)}-01T00:00`)!;

  const [h, events] = await Promise.all([getContent("page.headers"), getEventsBetween(first, after)]);

  // build the grid (weeks start on Monday)
  const daysInMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
  const firstDow = (new Date(Date.UTC(year, month - 1, 1)).getUTCDay() + 6) % 7;
  const cells: { key: string; day: number; inMonth: boolean }[] = [];
  for (let i = 0; i < firstDow; i++) {
    const d = new Date(Date.UTC(year, month - 1, 1 - (firstDow - i)));
    cells.push({ key: d.toISOString().slice(0, 10), day: d.getUTCDate(), inMonth: false });
  }
  for (let d = 1; d <= daysInMonth; d++) cells.push({ key: `${year}-${pad(month)}-${pad(d)}`, day: d, inMonth: true });
  while (cells.length % 7) {
    const d = new Date(Date.UTC(year, month - 1, cells.length - firstDow + 1));
    cells.push({ key: d.toISOString().slice(0, 10), day: d.getUTCDate(), inMonth: false });
  }
  const byDay = new Map<string, typeof events>();
  for (const e of events) {
    const k = cyprusDayKey(e.startsAt);
    byDay.set(k, [...(byDay.get(k) ?? []), e]);
  }
  const monthName = new Intl.DateTimeFormat("en-GB", { month: "long", year: "numeric", timeZone: "UTC" }).format(new Date(Date.UTC(year, month - 1, 15)));

  return (
    <>
      <PageHero
        compact
        kicker="What's on"
        title={h.calendarTitle}
        text={h.calendarText}
        image={h.eventsImage}
        crumbs={[
          { name: "Events", path: "/events" },
          { name: "Calendar", path: "/events/calendar" },
        ]}
      />
      <section className="section">
        <div className="container">
          <div className="cal-head">
            <Link href={`/events/calendar?month=${prevY}-${pad(prevM)}`} className="round-btn on-dark" aria-label="Previous month" rel="nofollow">
              ←
            </Link>
            <h2 className="display">{monthName}</h2>
            <Link href={`/events/calendar?month=${nextY}-${pad(nextM)}`} className="round-btn on-dark" aria-label="Next month" rel="nofollow">
              →
            </Link>
          </div>

          <div className="calendar" role="grid" aria-label={`Events in ${monthName}`}>
            {DOW.map((d) => (
              <div key={d} className="cal-dow" role="columnheader">
                {d}
              </div>
            ))}
            {cells.map((c) => (
              <div key={c.key} className={`cal-day${c.inMonth ? "" : " out"}${c.key === todayKey ? " today" : ""}`} role="gridcell">
                <span className="cal-num">{c.day}</span>
                {(byDay.get(c.key) ?? []).map((e) => (
                  <Link key={e.id} href={`/events/${e.slug}`} className="cal-event">
                    <time dateTime={e.startsAt.toISOString()}>{eventDateParts(e.startsAt).time}</time>
                    {e.title}
                  </Link>
                ))}
              </div>
            ))}
          </div>

          {/* mobile: simple list */}
          <div className="cal-list">
            {events.length ? (
              events.map((e) => {
                const d = eventDateParts(e.startsAt);
                return (
                  <Link key={e.id} href={`/events/${e.slug}`} className="cal-event" style={{ padding: 14 }}>
                    <time dateTime={e.startsAt.toISOString()}>
                      {d.weekday} {d.dayNum} {d.month} · {d.time}
                    </time>
                    <span style={{ fontSize: 16 }}>{e.title}</span>
                  </Link>
                );
              })
            ) : (
              <p className="muted">No events this month yet.</p>
            )}
          </div>
          {!events.length && (
            <p className="muted" style={{ marginTop: 24 }}>
              No events planned for {monthName} yet. <Link href="/events">See all upcoming events</Link>.
            </p>
          )}
        </div>
      </section>
    </>
  );
}
