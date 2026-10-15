"use client";

import { useState, useRef } from "react";

const SUBJECTS = ["General enquiry", "Table / group booking", "Private event", "Feedback", "Careers", "Press & partnerships"];

/**
 * Enquiry form. Sends to /api/contact → saved in Admin → Messages and emailed to info@ammos.eu.
 * source: "home" | "contact" | "private-events"
 */
export function ContactForm({
  source = "contact",
  defaultSubject = "General enquiry",
  showSubject = false,
  buttonLabel = "Send",
}: {
  source?: string;
  defaultSubject?: string;
  showSubject?: boolean;
  buttonLabel?: string;
}) {
  const [state, setState] = useState<{ status: "idle" | "sending" | "ok" | "error"; message?: string }>({ status: "idle" });
  const startedAt = useRef(Date.now());
  const today = new Date().toISOString().slice(0, 10);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    const data = Object.fromEntries(new FormData(form).entries());
    setState({ status: "sending" });
    try {
      const res = await fetch("/api/contact", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ ...data, source, startedAt: startedAt.current }),
      });
      const json = await res.json().catch(() => ({}));
      if (!res.ok || !json.ok) throw new Error(json.error || "Could not send your message.");
      form.reset();
      setState({ status: "ok", message: "Thank you! Your message has been sent — we'll get back to you very soon." });
    } catch (err) {
      setState({ status: "error", message: (err as Error).message || "Could not send your message. Please call us instead." });
    }
  }

  return (
    <form className="form-grid" onSubmit={onSubmit} noValidate={false}>
      <label className="field">
        First name
        <input className="input" name="firstName" type="text" required maxLength={80} autoComplete="given-name" />
      </label>
      <label className="field">
        Last name
        <input className="input" name="lastName" type="text" maxLength={80} autoComplete="family-name" />
      </label>
      <label className="field">
        E-mail
        <input className="input" name="email" type="email" required maxLength={160} autoComplete="email" />
      </label>
      <label className="field">
        Phone
        <input className="input" name="phone" type="tel" maxLength={40} autoComplete="tel" placeholder="+357 …" />
      </label>
      {showSubject && (
        <label className="field full">
          Subject
          <select className="input" name="subject" defaultValue={defaultSubject}>
            {SUBJECTS.map((s) => (
              <option key={s}>{s}</option>
            ))}
          </select>
        </label>
      )}
      {!showSubject && <input type="hidden" name="subject" value={defaultSubject} />}
      <label className="field">
        <span className="field-label">Date <span className="opt">(optional)</span></span>
        <input className="input" name="visitDate" type="date" min={today} />
      </label>
      <label className="field">
        <span className="field-label">Guests <span className="opt">(optional)</span></span>
        <input className="input" name="guests" type="number" min={1} max={500} placeholder="2" />
      </label>
      <label className="field full">
        Message
        <textarea className="input" name="message" rows={5} required maxLength={4000} />
      </label>
      {/* spam trap — real visitors never see or fill this */}
      <div className="hp" aria-hidden="true">
        <label>
          Website
          <input name="website" type="text" tabIndex={-1} autoComplete="off" />
        </label>
      </div>
      <label className="check full">
        <input type="checkbox" name="consent" value="yes" required />
        <span>
          I agree that Ammos stores my details to answer this enquiry (<a href="/privacy-policy">privacy policy</a>).
        </span>
      </label>
      {state.status === "ok" || state.status === "error" ? (
        <div className={`form-alert full ${state.status === "ok" ? "ok" : "err"}`} role="status">
          {state.message}
        </div>
      ) : null}
      <div>
        <button type="submit" className="btn btn-brand" disabled={state.status === "sending"}>
          {state.status === "sending" ? "Sending…" : `${buttonLabel} ➤`}
        </button>
      </div>
    </form>
  );
}
