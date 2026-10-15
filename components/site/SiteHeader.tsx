"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import type { Navigation } from "@/lib/nav";
import { NavItem } from "@/components/site/NavItem";
import type { Settings } from "@/lib/content-schema";

type HeaderSettings = Pick<
  Settings,
  "reservationUrl" | "phone" | "email" | "address" | "city" | "hoursNote" | "facebook" | "instagram" | "tiktok" | "youtube"
>;

export function SiteHeader({ settings, socials, nav }: { settings: HeaderSettings; socials: React.ReactNode; nav: Navigation }) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const [stuck, setStuck] = useState(false);
  const closeRef = useRef<HTMLButtonElement>(null);
  const lastFocus = useRef<HTMLElement | null>(null);

  // sticky white header slides in after the first screen
  useEffect(() => {
    const onScroll = () => setStuck(window.scrollY > Math.min(window.innerHeight * 0.55, 520));
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, [pathname]);

  // close the menu when the page changes
  useEffect(() => setOpen(false), [pathname]);

  // lock scrolling, ESC to close, keep focus inside
  useEffect(() => {
    const root = document.documentElement;
    if (open) {
      lastFocus.current = document.activeElement as HTMLElement;
      root.style.overflow = "hidden";
      (window as unknown as { __lenis?: { stop(): void } }).__lenis?.stop();
      setTimeout(() => closeRef.current?.focus(), 50);
    } else {
      root.style.overflow = "";
      (window as unknown as { __lenis?: { start(): void } }).__lenis?.start();
      lastFocus.current?.focus?.();
    }
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open]);

  const isActive = (href: string) => (href === "/" ? pathname === "/" : pathname === href || pathname.startsWith(`${href}/`));
  const reserve = settings.reservationUrl;

  return (
    <>
      <header className="site-header">
        <nav aria-label="Main">
          {nav.headerLinks.map((l, i) => (
            <NavItem key={`${l.url}-${i}`} link={l} current={isActive(l.url)} />
          ))}
        </nav>
        <Link href="/" className="header-logo" aria-label="Ammos Makenzy Beach — home">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/images/logo.svg" alt="ammos — Makenzy Beach" width={240} height={62} />
        </Link>
        <div className="header-right">
          {nav.headerRightLabel && nav.headerRightUrl && <NavItem link={{ label: nav.headerRightLabel, url: nav.headerRightUrl }} className="hide-sm" />}
          <button className="burger" aria-label="Open menu" aria-expanded={open} aria-controls="site-menu" onClick={() => setOpen(true)}>
            <span />
            <span />
            <span />
          </button>
        </div>
      </header>

      <div className={`sticky-header${stuck && !open ? " is-visible" : ""}`} aria-hidden={!stuck}>
        <div className="sticky-inner">
          <nav aria-label="Main (compact)">
            {nav.headerLinks.map((l, i) => (
              <NavItem key={`${l.url}-${i}`} link={l} tabIndex={stuck ? 0 : -1} />
            ))}
          </nav>
          <Link href="/" aria-label="Ammos — home" tabIndex={stuck ? 0 : -1}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img className="logo-img" src="/images/logo-dark.svg" alt="ammos" width={160} height={42} />
          </Link>
          <div className="sticky-right">
            <a href={reserve} target="_blank" rel="noopener noreferrer" className="btn-reserve" tabIndex={stuck ? 0 : -1}>
              {nav.reserveLabel}
            </a>
            <button className="sticky-burger" aria-label="Open menu" onClick={() => setOpen(true)} tabIndex={stuck ? 0 : -1}>
              <span />
              <span />
              <span />
            </button>
          </div>
        </div>
      </div>

      <div id="site-menu" className={`menu-overlay${open ? " is-open" : ""}`} role="dialog" aria-modal="true" aria-label="Site menu" aria-hidden={!open} inert={!open}>
        <div className="menu-top">
          <Link href="/" aria-label="Home">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/images/logo.svg" alt="ammos" width={200} height={52} />
          </Link>
          <button ref={closeRef} className="menu-close" aria-label="Close menu" onClick={() => setOpen(false)}>
            ×
          </button>
        </div>
        <div className="menu-body">
          <ul className="menu-links">
            {nav.menuLinks.map((l, i) => (
              <li key={`${l.url}-${i}`}>
                <NavItem link={l} current={isActive(l.url)} style={{ transitionDelay: open ? `${0.05 + i * 0.04}s` : "0s" }} />
              </li>
            ))}
          </ul>
          <aside className="menu-aside">
            <div>
              <h3>Book a table</h3>
              <a href={reserve} target="_blank" rel="noopener noreferrer" className="btn btn-brand">
                Make reservation
              </a>
            </div>
            <div>
              <h3>Visit</h3>
              <p>
                {settings.address}, {settings.city}
                <br />
                {settings.hoursNote}
              </p>
            </div>
            <div>
              <h3>Talk to us</h3>
              <p>
                <a href={`tel:${settings.phone.replace(/\s/g, "")}`}>{settings.phone}</a>
                <br />
                <a href={`mailto:${settings.email}`}>{settings.email}</a>
              </p>
            </div>
            <div>
              <h3>Follow</h3>
              {socials}
            </div>
          </aside>
        </div>
        <div className="menu-bottom">
          <span>© {new Date().getFullYear()} Ammos Makenzy Beach</span>
          <span>
            {nav.menuBottomLinks.map((l, i) => (
              <span key={`${l.url}-${i}`}>
                {i > 0 && " · "}
                <NavItem link={l} />
              </span>
            ))}
          </span>
        </div>
      </div>
    </>
  );
}
