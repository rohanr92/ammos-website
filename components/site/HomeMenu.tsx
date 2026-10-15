"use client";

import { useRef, useState } from "react";
import { formatPrice } from "@/lib/utils";

type Tab = { name: string; slug: string; items: { id: string; name: string; description: string; price: string; image: string }[] };

/**
 * Menu tabs + dish list. If a dish has its own photo (Admin → Menu items),
 * the photo floats next to the mouse on hover. Dishes without a photo show no image.
 */
export function HomeMenu({ tabs, intro, after }: { tabs: Tab[]; intro: React.ReactNode; after?: React.ReactNode }) {
  const [active, setActive] = useState(tabs[0]?.slug ?? "");
  const hoverRef = useRef<HTMLDivElement>(null);
  const imgRef = useRef<HTMLImageElement>(null);
  const tab = tabs.find((t) => t.slug === active) ?? tabs[0];

  const move = (e: React.MouseEvent) => {
    const el = hoverRef.current;
    if (el) {
      el.style.left = `${e.clientX}px`;
      el.style.top = `${e.clientY}px`;
    }
  };
  const show = (src: string) => {
    if (!src) return hide();
    if (imgRef.current && imgRef.current.getAttribute("src") !== src) imgRef.current.src = src;
    hoverRef.current?.classList.add("is-on");
  };
  const hide = () => hoverRef.current?.classList.remove("is-on");

  return (
    <div className="menu-home-grid">
      <div className="menu-home-intro" data-reveal>
        {intro}
        {tabs.length > 1 && (
          <div className="pill-tabs" role="tablist" aria-label="Menu categories">
            {tabs.map((t) => (
              <button
                key={t.slug}
                type="button"
                role="tab"
                aria-selected={t.slug === tab?.slug}
                className={`pill${t.slug === tab?.slug ? " is-active" : ""}`}
                onClick={() => (hide(), setActive(t.slug))}
              >
                {t.name}
              </button>
            ))}
          </div>
        )}
        {after && <div className="menu-after menu-after-top">{after}</div>}
      </div>
      <div onMouseMove={move} onMouseLeave={hide} role="tabpanel" aria-label={tab?.name}>
        {tab?.items.map((m) => (
          <div key={m.id} className="dish" onMouseEnter={() => show(m.image)}>
            <div>
              <h3>{m.name}</h3>
              {m.description && <p>{m.description}</p>}
            </div>
            <span className="dish-price">{formatPrice(m.price)}</span>
          </div>
        ))}
        {/* on phones the button sits under the dishes */}
        {after && <div className="menu-after menu-after-bottom">{after}</div>}
      </div>
      <div ref={hoverRef} className="hover-image" aria-hidden="true">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img ref={imgRef} alt="" decoding="async" />
      </div>
    </div>
  );
}
