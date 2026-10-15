"use client";

import { useRef } from "react";

/** Horizontal scroll-snap row with ← → buttons (used for the events slider). */
export function HorizontalSlider({
  children,
  header,
  trackClass = "events-track",
  buttonTone = "on-white",
  label,
}: {
  children: React.ReactNode;
  header: React.ReactNode;
  trackClass?: string;
  buttonTone?: "on-white" | "on-dark";
  label: string;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const scroll = (dir: number) => {
    const el = ref.current;
    if (el) el.scrollBy({ left: dir * Math.round(el.clientWidth * 0.8), behavior: "smooth" });
  };
  return (
    <>
      <div className="events-head">
        {header}
        <div className="events-nav">
          <button type="button" className={`round-btn ${buttonTone}`} aria-label={`Previous ${label}`} onClick={() => scroll(-1)}>
            ←
          </button>
          <button type="button" className={`round-btn ${buttonTone}`} aria-label={`Next ${label}`} onClick={() => scroll(1)}>
            →
          </button>
        </div>
      </div>
      <div ref={ref} className={trackClass} role="region" aria-label={label} tabIndex={0}>
        {children}
      </div>
    </>
  );
}
