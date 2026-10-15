"use client";

import { Children, useEffect, useRef, useState } from "react";

/** News cards: 3-column grid on desktop, swipeable carousel with dots on phones & tablets. */
export function NewsCarousel({ children }: { children: React.ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  const count = Children.count(children);
  const [active, setActive] = useState(0);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const onScroll = () => {
      const slides = Array.from(el.children) as HTMLElement[];
      if (!slides.length) return;
      const center = el.scrollLeft + el.clientWidth / 2;
      let best = 0;
      let dist = Infinity;
      slides.forEach((s, i) => {
        const d = Math.abs(s.offsetLeft - el.offsetLeft + s.offsetWidth / 2 - center);
        if (d < dist) {
          dist = d;
          best = i;
        }
      });
      setActive(best);
    };
    el.addEventListener("scroll", onScroll, { passive: true });
    return () => el.removeEventListener("scroll", onScroll);
  }, []);

  const go = (i: number) => {
    const el = ref.current;
    const slide = el?.children[i] as HTMLElement | undefined;
    if (el && slide) el.scrollTo({ left: slide.offsetLeft - el.offsetLeft - (el.clientWidth - slide.offsetWidth) / 2, behavior: "smooth" });
  };

  return (
    <div className="news-carousel">
      <div ref={ref} className="news-grid news-track" role="region" aria-label="Latest news" tabIndex={0}>
        {children}
      </div>
      {count > 1 && (
        <div className="news-dots" role="tablist" aria-label="Choose article">
          {Array.from({ length: count }, (_, i) => (
            <button key={i} type="button" role="tab" aria-selected={i === active} aria-label={`Article ${i + 1}`} className={i === active ? "is-active" : ""} onClick={() => go(i)} />
          ))}
        </div>
      )}
    </div>
  );
}
