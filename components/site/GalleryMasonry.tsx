"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Image from "next/image";

type Photo = { id: string; image: string; alt: string; album: string; video?: string };

/** Instagram post/reel link → embeddable player URL (null if it isn't one). */
function instagramEmbed(url: string) {
  const m = /instagram\.com\/(?:[\w.]+\/)?(p|reel|tv)\/([\w-]+)/i.exec(url);
  return m ? `https://www.instagram.com/${m[1] === "tv" ? "reel" : m[1]}/${m[2]}/embed/` : null;
}

/** Gallery page: album filter, masonry grid and a full-screen viewer (← → keys, ESC). Videos play inside the viewer. */
export function GalleryMasonry({ photos }: { photos: Photo[] }) {
  const albums = useMemo(() => {
    const list = Array.from(new Set(photos.map((p) => p.album).filter(Boolean)));
    // keep "Videos" last
    return [...list.filter((a) => a !== "Videos"), ...list.filter((a) => a === "Videos")];
  }, [photos]);
  const [album, setAlbum] = useState<string>("All");
  const [open, setOpen] = useState<number | null>(null);
  const [limit, setLimit] = useState(40);
  const list = album === "All" ? photos : photos.filter((p) => p.album === album);
  const shown = list.slice(0, limit);

  const close = useCallback(() => setOpen(null), []);
  const step = useCallback((d: number) => setOpen((i) => (i === null ? i : (i + d + list.length) % list.length)), [list.length]);

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

  const current = open !== null ? list[open] : null;
  const embed = current?.video ? instagramEmbed(current.video) : null;

  return (
    <>
      {albums.length > 1 && (
        <div className="filter-bar">
          <div className="group" role="group" aria-label="Albums">
            {["All", ...albums].map((a) => (
              <button
                key={a}
                type="button"
                className={`pill${album === a ? " is-active" : ""}`}
                onClick={() => {
                  setAlbum(a);
                  setLimit(40);
                }}
              >
                {a}
              </button>
            ))}
          </div>
        </div>
      )}
      <div className="masonry">
        {shown.map((p, i) => (
          <button
            key={p.id}
            type="button"
            className={`masonry-item${p.video ? " is-video" : ""}`}
            onClick={() => setOpen(i)}
            aria-label={`${p.video ? "Play video" : "Open photo"}: ${p.alt || "Ammos"}`}
          >
            {/^https?:/.test(p.image) ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={p.image} alt={p.alt} loading="lazy" />
            ) : (
              <Image src={p.image} alt={p.alt} width={600} height={600} sizes="(max-width: 600px) 50vw, 25vw" style={{ height: "auto" }} />
            )}
            {p.video && (
              <span className="play-badge" aria-hidden="true">
                <svg viewBox="0 0 24 24" width="22" height="22">
                  <path d="M8 5v14l11-7z" fill="currentColor" />
                </svg>
              </span>
            )}
          </button>
        ))}
      </div>
      {list.length > shown.length && (
        <div className="center-row">
          <button type="button" className="btn btn-outline" onClick={() => setLimit((l) => l + 40)}>
            Show more ({list.length - shown.length})
          </button>
        </div>
      )}
      {current && (
        <div className="lightbox" role="dialog" aria-modal="true" aria-label={current.video ? "Video player" : "Photo viewer"} onClick={close}>
          {current.video ? (
            embed ? (
              <iframe
                key={embed}
                className="lb-embed"
                src={embed}
                title={current.alt || "Ammos video"}
                allow="autoplay; encrypted-media; picture-in-picture"
                allowFullScreen
                onClick={(e) => e.stopPropagation()}
              />
            ) : (
              <video key={current.video} className="lb-video" src={current.video} poster={current.image} controls autoPlay playsInline onClick={(e) => e.stopPropagation()} />
            )
          ) : (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={current.image} alt={current.alt} onClick={(e) => e.stopPropagation()} />
          )}
          <button type="button" className="round-btn on-dark lb-btn lb-prev" aria-label="Previous" onClick={(e) => (e.stopPropagation(), step(-1))}>
            ←
          </button>
          <button type="button" className="round-btn on-dark lb-btn lb-next" aria-label="Next" onClick={(e) => (e.stopPropagation(), step(1))}>
            →
          </button>
          <button type="button" className="round-btn on-dark lb-close" aria-label="Close" onClick={close}>
            ×
          </button>
          {current.alt && !current.video && <p className="lb-cap">{current.alt}</p>}
        </div>
      )}
    </>
  );
}
