import Link from "next/link";
import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { getContent, getSettings } from "@/lib/content";
import { getBookedGuests, getEventBySlug, getOtherUpcomingEvents } from "@/lib/data";
import { eventJsonLd, pageMeta } from "@/lib/seo";
import { eventDateParts, formatDate, isEventOver, truncate } from "@/lib/utils";
import { PageHero } from "@/components/site/PageHero";
import { RichText } from "@/components/site/RichText";
import { BookingForm } from "@/components/site/BookingForm";
import { EventCard } from "@/components/site/EventCard";
import { JsonLd } from "@/components/site/JsonLd";
import { EventPhotos } from "@/components/site/EventPhotos";

export const revalidate = 300;
export const dynamicParams = true;
export function generateStaticParams() {
  return []; // pages are built on first visit, then cached
}

type Params = Promise<{ slug: string }>;

export async function generateMetadata({ params }: { params: Params }): Promise<Metadata> {
  const { slug } = await params;
  const e = await getEventBySlug(slug);
  if (!e) return { title: "Event not found", robots: { index: false } };
  const d = eventDateParts(e.startsAt);
  return pageMeta({
    title: `${e.title} — ${d.weekday} ${d.dayNum} ${d.monthLong} ${d.year}`,
    description: truncate(e.summary || e.description, 160) || `${e.category} at Ammos Makenzy Beach, Larnaca.`,
    path: `/events/${e.slug}`,
    image: e.image,
  });
}

export default async function EventPage({ params }: { params: Params }) {
  const { slug } = await params;
  const event = await getEventBySlug(slug);
  if (!event) notFound();

  const [settings, booked, others, evCopy] = await Promise.all([getSettings(), getBookedGuests(event.id), getOtherUpcomingEvents(event.id, 3), getContent("home.events")]);
  const d = eventDateParts(event.startsAt);
  const isPast = isEventOver(event.startsAt);
  const left = event.capacity ? Math.max(0, event.capacity - booked) : null;
  const canBook = !isPast && event.bookingEnabled && (left === null || left > 0);
  // event photos from the admin; if none were added, show the main photo so the page never looks empty
  const photos = (Array.isArray(event.gallery) ? event.gallery : []).filter(Boolean);
  const gallery = photos.length ? photos : event.image ? [event.image] : [];

  return (
    <>
      <PageHero
        kicker={isPast ? `Event passed · ${event.category}` : `${event.category} · ${event.venue}`}
        title={event.title}
        text={event.summary}
        image={event.image}
        crumbs={[
          { name: "Events", path: "/events" },
          { name: event.title, path: `/events/${event.slug}` },
        ]}
      >
        <div className="btn-row" style={{ marginTop: 28 }}>
          {canBook && (
            <a href="#book" className="btn btn-brand">
              Book this event
            </a>
          )}
          <a href={settings.reservationUrl} target="_blank" rel="noopener noreferrer" className="btn btn-ghost-light">
            Reserve a table
          </a>
        </div>
      </PageHero>

      <section className="section">
        <div className="container event-detail-grid">
          <div>
            <dl className="event-facts" style={{ marginTop: 0 }}>
              <div>
                <dt>Date</dt>
                <dd>
                  <time dateTime={event.startsAt.toISOString()}>
                    {d.weekday}, {d.dayNum} {d.month} {d.year}
                  </time>
                </dd>
              </div>
              <div>
                <dt>Time</dt>
                <dd>
                  {d.time}
                  {event.endsAt ? ` – ${eventDateParts(event.endsAt).time}` : ""}
                </dd>
              </div>
              <div>
                <dt>Where</dt>
                <dd>{event.venue}</dd>
              </div>
              {event.priceInfo && (
                <div>
                  <dt>Entry</dt>
                  <dd>{event.priceInfo}</dd>
                </div>
              )}
            </dl>
            <RichText text={event.description} />
            <p className="muted" style={{ marginTop: 32, fontSize: 14 }}>
              Ammos Makenzy Beach · {settings.address}, {settings.city} · <a href={`tel:${settings.phone.replace(/\s/g, "")}`}>{settings.phone}</a>
            </p>
            {gallery.length > 0 && (
              <div className="event-photos-wrap">
                <p className="kicker kicker-teal">{isPast ? "From the night" : "The vibe"}</p>
                <EventPhotos photos={gallery} title={event.title} />
              </div>
            )}
          </div>

          <aside id="book" className="booking-panel form-card" style={{ scrollMarginTop: 100 }}>
            {isPast ? (
              <>
                <span className="past-flag past-flag-inline">Event passed</span>
                <h2 className="display">Bookings are closed</h2>
                <p className="lead" style={{ marginTop: 10 }}>
                  This event took place on {formatDate(event.startsAt)}, so we no longer take bookings for it. Have a look at what's coming up next, or reserve a table for another day.
                </p>
                <div className="btn-row" style={{ marginTop: 20 }}>
                  <Link href="/events" className="btn btn-outline">
                    Upcoming events
                  </Link>
                  <a href={settings.reservationUrl} target="_blank" rel="noopener noreferrer" className="btn btn-muted">
                    Reserve a table
                  </a>
                </div>
              </>
            ) : canBook ? (
              <>
                <h2 className="display">Book your spot</h2>
                {left !== null && left <= 30 && <p className="spots">Only {left} places left</p>}
                {left === null || left > 30 ? <p className="form-note" style={{ marginBottom: 20 }}>Fill in your details and we'll confirm your table.</p> : null}
                <BookingForm eventId={event.id} eventTitle={event.title} maxGuests={left ?? 30} startsAt={event.startsAt.toISOString()} />
              </>
            ) : (
              <>
                <h2 className="display">{left === 0 ? "Fully booked" : "Booking by phone"}</h2>
                <p className="lead" style={{ marginTop: 10 }}>
                  {left === 0 ? "This night is fully booked online. Call us to join the waiting list." : "Call or message us to reserve for this event."}
                </p>
                <div className="btn-row" style={{ marginTop: 20 }}>
                  <a href={`tel:${settings.phone.replace(/\s/g, "")}`} className="btn btn-brand">
                    Call {settings.phone}
                  </a>
                </div>
              </>
            )}
          </aside>
        </div>
      </section>

      {others.length > 0 && (
        <section className="section events-page">
          <div className="container">
            <p className="kicker kicker-teal">More nights</p>
            <h2 className="display display-md" style={{ color: "var(--ink)", marginBottom: 40 }}>
              also coming up
            </h2>
            <div className="events-grid">
              {others.map((e) => (
                <EventCard key={e.id} event={e} showBadge variant={evCopy.cardStyle === "editorial" ? "editorial" : "overlay"} />
              ))}
            </div>
          </div>
        </section>
      )}
      <JsonLd data={eventJsonLd(event, settings)} />
    </>
  );
}
