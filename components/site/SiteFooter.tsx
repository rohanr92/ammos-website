import Link from "next/link";
import type { Navigation } from "@/lib/nav";
import { NavItem } from "@/components/site/NavItem";
import { Socials } from "@/components/site/Socials";
import type { Settings } from "@/lib/content-schema";

export function SiteFooter({ settings, nav }: { settings: Settings; nav: Navigation }) {
  return (
    <footer>
      <div className="footer-main">
        <div className="container footer-grid">
          <div>
            <Link href="/" aria-label="Ammos — home">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src="/images/logo-dark.svg" alt="ammos — Makenzy Beach" width={230} height={60} />
            </Link>
            <p className="footer-tagline">{settings.tagline}</p>
          </div>
          {nav.footerColumns.map((col, i) => (
            <nav key={i} aria-label={`Footer links ${i + 1}`}>
              {col.map((l, j) => (
                <NavItem key={`${l.url}-${j}`} link={l} />
              ))}
            </nav>
          ))}
          <div className="footer-contact">
            <span>
              {settings.address}
              <br />
              {settings.city} {settings.postcode}, {settings.country}
            </span>
            <a href={`tel:${settings.phone.replace(/\s/g, "")}`}>{settings.phone}</a>
            <a href={`mailto:${settings.email}`}>{settings.email}</a>
            <small>{settings.hoursNote}</small>
            <div style={{ marginTop: 10 }}>
              <Socials settings={settings} tone="on-brand" />
            </div>
          </div>
        </div>
      </div>
      <div className="footer-bar">
        © {new Date().getFullYear()} Ammos Makenzy Beach
        {nav.footerBarLinks.map((l, i) => (
          <span key={`${l.url}-${i}`}>
            {" "}
            &nbsp;|&nbsp; <NavItem link={l} />
          </span>
        ))}
      </div>
    </footer>
  );
}
