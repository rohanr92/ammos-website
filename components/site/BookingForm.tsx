"use client";

import { useEffect, useRef, useState } from "react";

/** Event booking form → /api/bookings → Admin → Bookings + emails to Ammos and the guest. */
export function BookingForm({ eventId, eventTitle, maxGuests, startsAt }: { eventId: string; eventTitle: string; maxGuests: number; startsAt?: string }) {
  const [state, setState] = useState<{ status: "idle" | "sending" | "ok" | "error"; message?: string; reference?: string }>({ status: "idle" });
  const startedAt = useRef(Date.now());
  const limit = Math.max(1, Math.min(maxGuests, 30));
  // if the page was cached before the event started, close the form in the browser too
  const [closed, setClosed] = useState(false);
  useEffect(() => {
    if (!startsAt) return;
    const ms = new Date(startsAt).getTime() - Date.now();
    if (ms <= 0) return setClosed(true);
    if (ms < 2 ** 31 - 1) {
      const t = setTimeout(() => setClosed(true), ms);
      return () => clearTimeout(t);
    }
  }, [startsAt]);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    const data = Object.fromEntries(new FormData(form).entries());
    setState({ status: "sending" });
    try {
      const res = await fetch("/api/bookings", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ...data, eventId, startedAt: startedAt.current }),
      });
      const json = await res.json().catch(() => ({}));
      if (!res.ok || !json.ok) throw new Error(json.error || "We couldn't save your booking.");
      form.reset();
      setState({ status: "ok", reference: json.reference });
    } catch (err) {
      setState({ status: "error", message: (err as Error).message });
    }
  }

  if (closed && state.status !== "ok") {
    return (
      <div className="form-alert" role="status">
        <strong>Online booking is closed.</strong>
        <br />
        This event has already started. Call us on +357 24 828844 and we&apos;ll do our best to fit you in.
      </div>
    );
  }

  if (state.status === "ok") {
    return (
      <div className="form-alert ok" role="status">
        <strong>Booking request received!</strong>
        <br />
        Your reference is <strong>{state.reference}</strong>. We've emailed you a copy for <em>{eventTitle}</em> and will confirm your table shortly.
      </div>
    );
  }

  return (
    <form className="form-grid" onSubmit={onSubmit}>
      <label className="field">
        First name
        <input className="input" name="firstName" required maxLength={80} autoComplete="given-name" />
      </label>
      <label className="field">
        Last name
        <input className="input" name="lastName" required maxLength={80} autoComplete="family-name" />
      </label>
      <label className="field">
        E-mail
        <input className="input" name="email" type="email" required maxLength={160} autoComplete="email" />
      </label>
      <label className="field">
        Phone
        <input className="input" name="phone" type="tel" required maxLength={40} autoComplete="tel" placeholder="+357 …" />
      </label>
      <label className="field">
        Guests
        <select className="input" name="guests" defaultValue="2">
          {Array.from({ length: limit }, (_, i) => i + 1).map((n) => (
            <option key={n} value={n}>
              {n} {n === 1 ? "guest" : "guests"}
            </option>
          ))}
        </select>
      </label>
      <label className="field">
        Seating preference
        <select className="input" name="seating" defaultValue="Any">
          {["Any", "Terrace", "Beach", "Bar", "Inside"].map((s) => (
            <option key={s}>{s}</option>
          ))}
        </select>
      </label>
      <label className="field full">
        <span className="field-label">Occasion <span className="opt">(optional)</span></span>
        <input className="input" name="occasion" maxLength={120} placeholder="Birthday, anniversary…" />
      </label>
      <label className="field full">
        <span className="field-label">Notes <span className="opt">(optional)</span></span>
        <textarea className="input" name="message" rows={3} maxLength={2000} placeholder="Allergies, arrival time, special requests…" />
      </label>
      <div className="hp" aria-hidden="true">
        <label>
          Website
          <input name="website" tabIndex={-1} autoComplete="off" />
        </label>
      </div>
      <label className="check full">
        <input type="checkbox" name="consent" value="yes" required />
        <span>
          I agree that Ammos stores my details to manage this booking (<a href="/privacy-policy">privacy policy</a>).
        </span>
      </label>
      <label className="check full">
        <input type="checkbox" name="marketingOptIn" value="yes" />
        <span>Send me news about upcoming events (optional).</span>
      </label>
      {state.status === "error" && (
        <div className="form-alert err full" role="alert">
          {state.message}
        </div>
      )}
      <div className="full">
        <button type="submit" className="btn btn-brand" disabled={state.status === "sending"} style={{ width: "100%" }}>
          {state.status === "sending" ? "Sending…" : "Request booking"}
        </button>
        <p className="form-note" style={{ marginTop: 12 }}>
          Your table is confirmed once we reply by email or phone.
        </p>
      </div>
    </form>
  );
}
