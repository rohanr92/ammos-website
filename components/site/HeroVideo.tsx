"use client";

import { useEffect, useRef, useState } from "react";

/** Muted looping background video. Skipped for visitors who prefer less motion or save data. */
export function HeroVideo({ src, poster }: { src: string; poster?: string }) {
  const ref = useRef<HTMLVideoElement>(null);
  const [enabled, setEnabled] = useState(false);

  useEffect(() => {
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const saveData = (navigator as unknown as { connection?: { saveData?: boolean } }).connection?.saveData;
    setEnabled(!reduce && !saveData);
  }, []);

  useEffect(() => {
    const v = ref.current;
    if (enabled && v) {
      v.muted = true;
      v.play().catch(() => {});
    }
  }, [enabled]);

  if (!enabled || !src) return null;
  return <video ref={ref} className="hero-media" src={src} poster={poster} autoPlay muted loop playsInline preload="metadata" aria-hidden="true" />;
}
