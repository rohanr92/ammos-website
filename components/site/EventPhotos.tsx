"use client";

import { useCallback, useEffect, useState } from "react";
import { Img } from "@/components/site/Img";

const SHOWN = 5;

/** Event page photo mosaic (1 big + 4 small) with a full-screen viewer. */
export function EventPhotos({ photos, title }: { photos: string[]; title: string }) {
  const [open, setOpen] = useState<number | null>(null);
  const close = useCallback(() => setOpen(null), []);
  const step = useCallback((d: number) => setOpen((i) => (i === null ? i : (i + d + photos.length) % photos.length)), [photos.length]);

  useEffect(() => {
    if (open === null) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") close();
      if (e.key === "ArrowRight") step(1);
      if (e.key === "ArrowLeft") step(-1);
    };
    window.addEventListener("keydown", onKey);
    document.documentElement.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.documentElement.style.overflow = "";
    };
  }, [open, close, step]);

  if (!photos.length) return null;
  const shown = photos.slice(0, SHOWN);
  const more = photos.length - shown.length;

  return (
    <>
      <div className={`event-photos count-${shown.length}`}>
        {shown.map((src, i) => (
          <button
            key={`${src}-${i}`}
            type="button"
            className="event-photo"
            data-reveal
            style={{ transitionDelay: `${i * 0.08}s` }}
            onClick={() => setOpen(i)}
            aria-label={`Open photo ${i + 1} of ${photos.length}`}
          >
            <Img src={src} alt={`${title} at Ammos Makenzy Beach — photo ${i + 1}`} sizes={i === 0 ? "(max-width: 900px) 100vw, 40vw" : "(max-width: 900px) 50vw, 20vw"} />
            {i === shown.length - 1 && more > 0 && <span className="event-photo-more">+{more}</span>}
          </button>
        ))}
      </div>
      {open !== null && (
        <div className="lightbox" role="dialog" aria-modal="true" aria-label="Photo viewer" onClick={close}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={photos[open]} alt={`${title} — photo ${open + 1}`} onClick={(e) => e.stopPropagation()} />
          {photos.length > 1 && (
            <>
              <button type="button" className="round-btn on-dark lb-btn lb-prev" aria-label="Previous photo" onClick={(e) => (e.stopPropagation(), step(-1))}>
                ←
              </button>
              <button type="button" className="round-btn on-dark lb-btn lb-next" aria-label="Next photo" onClick={(e) => (e.stopPropagation(), step(1))}>
                →
              </button>
            </>
          )}
          <button type="button" className="round-btn on-dark lb-close" aria-label="Close" onClick={close}>
            ×
          </button>
          <p className="lb-cap">
            {open + 1} / {photos.length}
          </p>
        </div>
      )}
    </>
  );
}
