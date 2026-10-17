"use client";

import { useEffect, useState } from "react";
import Image from "next/image";

type Slide = { image: string; mobileImage?: string; position?: string };

/** Full-screen hero photos that slowly zoom and cross-fade (pauses for visitors who prefer less motion). */
export function HeroSlideshow({ slides, interval = 6500 }: { slides: Slide[]; interval?: number }) {
  const list = slides.filter((s) => s?.image);
  const [active, setActive] = useState(0);

  useEffect(() => {
    if (list.length < 2) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const t = setInterval(() => setActive((i) => (i + 1) % list.length), interval);
    return () => clearInterval(t);
  }, [list.length, interval]);

  return (
    <div className="hero-slides" aria-hidden="true">
      {list.map((s, i) => (
        <div key={`${s.image}-${i}`} className={`hero-slide${i === active ? " is-active" : ""}`}>
          {s.mobileImage ? (
            // separate portrait photo for phones (both files are already web-sized)
            <picture>
              <source media="(max-width: 700px)" srcSet={s.mobileImage} />
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={s.image} alt="" className="fill-img" fetchPriority={i === 0 ? "high" : "auto"} style={{ objectPosition: s.position || "center" }} />
            </picture>
          ) : /^https?:/.test(s.image) ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={s.image} alt="" className="fill-img" style={{ objectPosition: s.position || "center" }} />
          ) : (
            <Image src={s.image} alt="" fill sizes="100vw" quality={85} preload={i === 0} unoptimized={s.image.startsWith("/uploads/")} className="cover" style={{ objectPosition: s.position || "center" }} />
          )}
        </div>
      ))}
      {list.length > 1 && (
        <div className="hero-dots">
          {list.map((_, i) => (
            <span key={i} className={i === active ? "is-active" : ""} />
          ))}
        </div>
      )}
    </div>
  );
}
