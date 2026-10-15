/** Small helpers shared by the website and the admin panel. */

export const TIMEZONE = "Europe/Nicosia"; // Cyprus time

export function slugify(input: string) {
  return input
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

/** "Line one\nLine two" → ["Line one", "Line two"] */
export function lines(text: string | undefined | null) {
  return String(text ?? "").split(/\r?\n/);
}

function parts(date: Date, opts: Intl.DateTimeFormatOptions) {
  return new Intl.DateTimeFormat("en-GB", { timeZone: TIMEZONE, ...opts }).formatToParts(date);
}
function part(date: Date, type: Intl.DateTimeFormatPartTypes, opts: Intl.DateTimeFormatOptions) {
  return parts(date, opts).find((p) => p.type === type)?.value ?? "";
}

/** Event card pieces in Cyprus time. */
/** True once the event's start time has passed — booking closes and cards show "Event passed". */
export function isEventOver(startsAt: Date | string) {
  return new Date(startsAt).getTime() <= Date.now();
}

export function eventDateParts(d: Date | string) {
  const date = new Date(d);
  return {
    weekday: part(date, "weekday", { weekday: "long" }),
    dayNum: part(date, "day", { day: "numeric" }),
    month: part(date, "month", { month: "short" }),
    monthLong: part(date, "month", { month: "long" }),
    year: part(date, "year", { year: "numeric" }),
    time: new Intl.DateTimeFormat("en-GB", { timeZone: TIMEZONE, hour: "2-digit", minute: "2-digit", hour12: false }).format(date),
  };
}

export function formatDate(d: Date | string, opts: Intl.DateTimeFormatOptions = { day: "numeric", month: "long", year: "numeric" }) {
  return new Intl.DateTimeFormat("en-GB", { timeZone: TIMEZONE, ...opts }).format(new Date(d));
}

export function formatDateTime(d: Date | string) {
  return new Intl.DateTimeFormat("en-GB", {
    timeZone: TIMEZONE,
    weekday: "short",
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(new Date(d));
}

/** Offset (in minutes) of Cyprus time vs UTC for a given instant. */
function tzOffsetMinutes(date: Date, timeZone = TIMEZONE) {
  const p = new Intl.DateTimeFormat("en-US", {
    timeZone,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).formatToParts(date);
  const get = (t: string) => Number(p.find((x) => x.type === t)?.value);
  const asUtc = Date.UTC(get("year"), get("month") - 1, get("day"), get("hour"), get("minute"), get("second"));
  return (asUtc - date.getTime()) / 60000;
}

/** "2026-10-17T21:00" typed in the admin (Cyprus time) → real Date (UTC). */
export function cyprusLocalToDate(local: string): Date | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(local);
  if (!m) return null;
  const guess = Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5]);
  let offset = tzOffsetMinutes(new Date(guess));
  let result = guess - offset * 60000;
  offset = tzOffsetMinutes(new Date(result)); // second pass handles DST edges
  result = guess - offset * 60000;
  return new Date(result);
}

/** Date → "2026-10-17T21:00" in Cyprus time, for <input type="datetime-local">. */
export function dateToCyprusLocal(d: Date | string | null | undefined) {
  if (!d) return "";
  const date = new Date(d);
  const p = new Intl.DateTimeFormat("en-CA", {
    timeZone: TIMEZONE,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).formatToParts(date);
  const get = (t: string) => p.find((x) => x.type === t)?.value ?? "00";
  return `${get("year")}-${get("month")}-${get("day")}T${get("hour")}:${get("minute")}`;
}

/** Year-month-day of an instant in Cyprus time, e.g. "2026-10-17". */
export function cyprusDayKey(d: Date | string) {
  return dateToCyprusLocal(d).slice(0, 10);
}

export function formatPrice(value: string | number) {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) return "";
  return `€${n % 1 === 0 ? n.toFixed(0) : n.toFixed(2)}`;
}

export function initials(name: string) {
  return (name.trim()[0] ?? "A").toUpperCase();
}

export function truncate(text: string, max = 160) {
  const clean = text.replace(/\s+/g, " ").trim();
  return clean.length > max ? `${clean.slice(0, max - 1).trimEnd()}…` : clean;
}

/** Turns a YouTube URL into an embeddable URL (or null). */
export function youtubeEmbed(url: string) {
  const m = /(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/)|youtu\.be\/)([\w-]{6,})/.exec(url || "");
  return m ? `https://www.youtube-nocookie.com/embed/${m[1]}?autoplay=1&rel=0` : null;
}

export function siteUrl(path = "") {
  const base = (process.env.SITE_URL || "http://localhost:3000").replace(/\/+$/, "");
  return `${base}${path.startsWith("/") || path === "" ? path : `/${path}`}`;
}

/** Absolute URL for images used in SEO tags. */
export function absoluteImage(src: string | undefined | null) {
  if (!src) return siteUrl("/opengraph-image.jpg");
  return /^https?:\/\//.test(src) ? src : siteUrl(src);
}

export function isExternal(href: string) {
  return /^https?:\/\//.test(href);
}
