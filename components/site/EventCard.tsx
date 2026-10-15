import Link from "next/link";
import { Img } from "@/components/site/Img";
import { eventDateParts, isEventOver } from "@/lib/utils";
import type { Event } from "@/lib/db/schema";

type Props = { event: Event; past?: boolean; showBadge?: boolean; variant?: "editorial" | "overlay" };

/**
 * Event card. Two looks (Admin → Page content → Upcoming events block → Event card style):
 *  - "overlay": text on the photo, date badge, arrow button
 *  - "editorial": photo with the date line, title and link underneath
 * Once the start time has passed it shows an "Event passed" tag and no booking link.
 */
export function EventCard({ event, past = false, showBadge = false, variant = "editorial" }: Props) {
  const d = eventDateParts(event.startsAt);
  const href = `/events/${event.slug}`;
  const over = past || isEventOver(event.startsAt);

  if (variant === "overlay") {
    return (
      <article className={`event-ov${over ? " is-over" : ""}`}>
        <Link href={href} className="event-ov-link" aria-label={`${event.title} — ${d.weekday} ${d.dayNum} ${d.month}${over ? " (event passed)" : ""}`}>
          <Img src={event.image} alt={event.title} sizes="(max-width: 600px) 80vw, 340px" />
          <span className="event-ov-shade" />
          <span className="event-ov-date" aria-hidden="true">
            <b>{d.dayNum}</b>
            <span>{d.month}</span>
          </span>
          {over && <span className="past-flag">Event passed</span>}
          <span className="event-ov-body">
            <span className="event-ov-tag">
              {event.category} · {event.venue}
            </span>
            <span className="event-ov-title">{event.title}</span>
            <span className="event-ov-foot">
              <time dateTime={new Date(event.startsAt).toISOString()}>
                {d.weekday}, {d.month} {d.dayNum}
                {over ? ` ${d.year}` : ` · ${d.time}`}
              </time>
              <span className="event-ov-arrow" aria-hidden="true">
                →
              </span>
            </span>
          </span>
        </Link>
      </article>
    );
  }

  return (
    <article className={`event-card${over ? " is-over" : ""}`}>
      <Link href={href} className="event-card-media" aria-label={event.title} tabIndex={-1}>
        <Img src={event.image} alt={event.title} sizes="(max-width: 600px) 80vw, 340px" />
        {showBadge && (
          <span className="event-badge" aria-hidden="true">
            <b>{d.dayNum}</b>
            <span>{d.month}</span>
          </span>
        )}
        {over && <span className="past-flag">Event passed</span>}
      </Link>
      <div className="event-card-meta">
        <time dateTime={new Date(event.startsAt).toISOString()}>
          {d.weekday}, {d.month} {d.dayNum}
          {past ? ` ${d.year}` : ""}
        </time>
        <span className="tag">{event.category}</span>
      </div>
      <h3 className="display">
        <Link href={href}>{event.title}</Link>
      </h3>
      <span className="where">
        {event.venue} · {over ? "was" : "from"} {d.time}
      </span>
      <Link href={over ? href : `${href}#book`} className="link-underline">
        {over ? "See the night" : event.bookingEnabled ? "Reserve a table" : "Event details"}
      </Link>
    </article>
  );
}
