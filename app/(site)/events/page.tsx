import Link from "next/link";
import type { Metadata } from "next";
import { getContent } from "@/lib/content";
import { getEventCategories, listEvents } from "@/lib/data";
import { pageMeta } from "@/lib/seo";
import { PageHero } from "@/components/site/PageHero";
import { EventCard } from "@/components/site/EventCard";

export async function generateMetadata(): Promise<Metadata> {
  const h = await getContent("page.headers");
  return pageMeta({ title: "Events at Ammos — DJs, parties & live music in Larnaca", description: h.eventsText, path: "/events", image: h.eventsImage });
}

type Search = Promise<{ show?: string; category?: string }>;

export default async function EventsPage({ searchParams }: { searchParams: Search }) {
  const sp = await searchParams;
  const show = sp.show === "past" ? "past" : "upcoming";
  const category = typeof sp.category === "string" && sp.category ? sp.category.slice(0, 60) : undefined;
  const [h, events, categories, evCopy] = await Promise.all([getContent("page.headers"), listEvents({ show, category }), getEventCategories(), getContent("home.events")]);
  const variant = evCopy.cardStyle === "editorial" ? "editorial" : "overlay";

  const href = (s: string, c?: string) => {
    const q = new URLSearchParams();
    if (s === "past") q.set("show", "past");
    if (c) q.set("category", c);
    const qs = q.toString();
    return `/events${qs ? `?${qs}` : ""}`;
  };

  return (
    <>
      <PageHero kicker="What's on" title={h.eventsTitle} text={h.eventsText} image={h.eventsImage} crumbs={[{ name: "Events", path: "/events" }]}>
        <div className="btn-row" style={{ marginTop: 28 }}>
          <Link href="/events/calendar" className="btn btn-ghost-light btn-sm">
            Calendar view
          </Link>
        </div>
      </PageHero>

      <section className="section events-page" aria-label="Event list">
        <div className="container">
          <div className="filter-bar">
            <div className="group" role="group" aria-label="When">
              <Link href={href("upcoming", category)} className={`pill${show === "upcoming" ? " is-active" : ""}`} aria-current={show === "upcoming" ? "true" : undefined}>
                Upcoming events
              </Link>
              <Link href={href("past", category)} className={`pill${show === "past" ? " is-active" : ""}`} aria-current={show === "past" ? "true" : undefined}>
                Past events
              </Link>
            </div>
            {categories.length > 1 && (
              <div className="group" role="group" aria-label="Type of event">
                <Link href={href(show)} className={`pill${!category ? " is-active" : ""}`}>
                  All
                </Link>
                {categories.map((c) => (
                  <Link key={c} href={href(show, c)} className={`pill${category === c ? " is-active" : ""}`}>
                    {c}
                  </Link>
                ))}
              </div>
            )}
          </div>

          {events.length ? (
            <div className="events-grid">
              {events.map((e) => (
                <EventCard key={e.id} event={e} past={show === "past"} showBadge variant={variant} />
              ))}
            </div>
          ) : (
            <div className="empty-state">
              <h2 className="display">{show === "past" ? "No past events yet" : "New dates coming soon"}</h2>
              <p>
                {show === "past" ? "Check our upcoming events instead." : "Follow us on Instagram to be the first to know, or "}
                {show !== "past" && <Link href="/contact" style={{ color: "var(--teal)" }}>ask us about private events</Link>}.
              </p>
            </div>
          )}
        </div>
      </section>
    </>
  );
}
