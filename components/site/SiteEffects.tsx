"use client";

import { useEffect, useRef } from "react";
import { usePathname } from "next/navigation";
import Lenis from "lenis";

/**
 * Site-wide motion from the design:
 *  - smooth scrolling (Lenis)
 *  - thin cyan reading-progress bar
 *  - fade/slide-in of every element marked data-reveal
 */
export function SiteEffects() {
  const pathname = usePathname();
  const barRef = useRef<HTMLDivElement>(null);

  // smooth scroll + progress
  useEffect(() => {
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const setProgress = (p: number) => {
      if (barRef.current) barRef.current.style.width = `${(p * 100).toFixed(2)}%`;
    };
    if (reduce) {
      const onScroll = () => {
        const h = document.documentElement;
        setProgress(h.scrollTop / Math.max(1, h.scrollHeight - h.clientHeight));
      };
      window.addEventListener("scroll", onScroll, { passive: true });
      return () => window.removeEventListener("scroll", onScroll);
    }
    const lenis = new Lenis({ lerp: 0.085, wheelMultiplier: 0.9, smoothWheel: true, anchors: { offset: -80 } });
    (window as unknown as { __lenis?: Lenis }).__lenis = lenis;
    lenis.on("scroll", ({ progress }: { progress: number }) => setProgress(progress || 0));
    let raf = 0;
    const loop = (t: number) => {
      lenis.raf(t);
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => {
      cancelAnimationFrame(raf);
      lenis.destroy();
      delete (window as unknown as { __lenis?: Lenis }).__lenis;
    };
  }, []);

  // scroll to top on page change
  useEffect(() => {
    const lenis = (window as unknown as { __lenis?: Lenis }).__lenis;
    if (!window.location.hash) lenis?.scrollTo(0, { immediate: true });
  }, [pathname]);

  // reveal-on-scroll
  useEffect(() => {
    document.documentElement.classList.remove("no-js");
    const io = new IntersectionObserver(
      (entries) => entries.forEach((e) => e.isIntersecting && e.target.classList.add("is-in")),
      { threshold: 0.12, rootMargin: "0px 0px -6% 0px" },
    );
    const observe = () => document.querySelectorAll("[data-reveal]:not(.is-in)").forEach((el) => io.observe(el));
    observe();
    // content that appears later (tabs, filters) is picked up too
    const mo = new MutationObserver(observe);
    mo.observe(document.body, { childList: true, subtree: true });
    return () => {
      io.disconnect();
      mo.disconnect();
    };
  }, [pathname]);

  return <div ref={barRef} className="progress-bar" aria-hidden="true" />;
}
