"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";

type Counts = { messages: number; bookings: number };

const NAV: { title: string; links: { href: string; label: string; badge?: keyof Counts }[] }[] = [
  { title: "Overview", links: [{ href: "/admin", label: "Dashboard" }] },
  {
    title: "Guests",
    links: [
      { href: "/admin/bookings", label: "Event bookings", badge: "bookings" },
      { href: "/admin/messages", label: "Messages", badge: "messages" },
    ],
  },
  {
    title: "Website",
    links: [
      { href: "/admin/events", label: "Events" },
      { href: "/admin/menu-items", label: "Menu items" },
      { href: "/admin/menu-categories", label: "Menu categories" },
      { href: "/admin/gallery", label: "Gallery" },
      { href: "/admin/news", label: "News & stories" },
      { href: "/admin/reviews", label: "Reviews" },
      { href: "/admin/content", label: "Page content" },
      { href: "/admin/content/navigation", label: "Navigation (menus)" },
      { href: "/admin/files", label: "Files (images & videos)" },
      { href: "/admin/redirects", label: "Redirects" },
    ],
  },
  { title: "Account", links: [{ href: "/admin/account", label: "My account & users" }] },
];

export function AdminShell({ user, counts, children }: { user: { name: string; email: string }; counts: Counts; children: React.ReactNode }) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  useEffect(() => setOpen(false), [pathname]);

  const allHrefs = NAV.flatMap((g) => g.links.map((l) => l.href));
  const matches = (href: string) => (href === "/admin" ? pathname === "/admin" : pathname === href || pathname.startsWith(`${href}/`));
  // the most specific link wins (e.g. "Navigation" instead of "Page content")
  const active = (href: string) => matches(href) && !allHrefs.some((h) => h !== href && h.startsWith(`${href}/`) && matches(h));

  async function logout() {
    await fetch("/api/auth/logout", { method: "POST" });
    window.location.href = "/admin/login";
  }

  return (
    <div className="a-shell">
      <aside className={`a-side${open ? " is-open" : ""}`}>
        <Link href="/admin" className="brand">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/images/logo.svg" alt="ammos" width={130} height={34} />
          <span>Admin</span>
        </Link>
        {NAV.map((g) => (
          <nav key={g.title} className="a-nav-group" aria-label={g.title}>
            <span className="a-nav-title">{g.title}</span>
            {g.links.map((l) => (
              <Link key={l.href} href={l.href} className={`a-nav-link${active(l.href) ? " is-active" : ""}`}>
                {l.label}
                {l.badge && counts[l.badge] > 0 && <span className="a-badge">{counts[l.badge]}</span>}
              </Link>
            ))}
          </nav>
        ))}
        <div className="a-side-foot">
          <span className="who">
            {user.name}
            <br />
            <small>{user.email}</small>
          </span>
          <a className="a-nav-link" href="/" target="_blank" rel="noopener noreferrer">
            View website ↗
          </a>
          <button type="button" className="a-nav-link" style={{ background: "none", border: 0, cursor: "pointer", textAlign: "left", font: "inherit" }} onClick={logout}>
            Log out
          </button>
        </div>
      </aside>
      <div className="a-main">
        <button type="button" className="a-btn a-menu-toggle" style={{ position: "fixed", right: 14, bottom: 14, zIndex: 60 }} onClick={() => setOpen((o) => !o)}>
          ☰ Menu
        </button>
        {children}
      </div>
    </div>
  );
}
