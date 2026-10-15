import type { Metadata } from "next";
import { getContent, getSettings } from "@/lib/content";
import { pageMeta } from "@/lib/seo";
import { PageHero } from "@/components/site/PageHero";
import { ContactForm } from "@/components/site/ContactForm";
import { Socials } from "@/components/site/Socials";

export const revalidate = 300;

export async function generateMetadata(): Promise<Metadata> {
  const [h, s] = await Promise.all([getContent("page.headers"), getSettings()]);
  return pageMeta({
    title: "Contact & opening hours",
    description: `${h.contactText} ${s.address}, ${s.city}. Call ${s.phone} or email ${s.email}.`,
    path: "/contact",
    image: h.contactImage,
  });
}

export default async function ContactPage() {
  const [h, s] = await Promise.all([getContent("page.headers"), getSettings()]);
  const todayName = new Intl.DateTimeFormat("en-GB", { weekday: "long", timeZone: "Europe/Nicosia" }).format(new Date());
  const mapSrc = `https://www.google.com/maps?q=${encodeURIComponent(s.mapQuery)}&output=embed`;
  return (
    <>
      <PageHero kicker="Say hello" title={h.contactTitle} text={h.contactText} image={h.contactImage} crumbs={[{ name: "Contact", path: "/contact" }]} />
      <section className="section">
        <div className="container contact-grid">
          <div className="info-list" data-reveal>
            <div className="info-item">
              <h3>Find us</h3>
              <p>
                {s.siteName}
                <br />
                {s.address}, {s.city} {s.postcode}
                <br />
                {s.country}
              </p>
              <a href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(s.mapQuery)}`} target="_blank" rel="noopener noreferrer" style={{ fontSize: 13, letterSpacing: "0.14em", textTransform: "uppercase", color: "var(--brand)" }}>
                Get directions ↗
              </a>
            </div>
            <div className="info-item">
              <h3>Call or write</h3>
              <p>
                <a href={`tel:${s.phone.replace(/\s/g, "")}`}>{s.phone}</a>
                <br />
                <a href={`mailto:${s.email}`}>{s.email}</a>
              </p>
            </div>
            <div className="info-item">
              <h3>Book a table</h3>
              <a href={s.reservationUrl} target="_blank" rel="noopener noreferrer" className="btn btn-brand btn-sm" style={{ color: "var(--ink)", fontSize: 12 }}>
                Reserve online
              </a>
            </div>
            <div className="info-item">
              <h3>Opening hours</h3>
              <table className="hours-table">
                <tbody>
                  {s.hours.map((row) => (
                    <tr key={row.day} className={row.day === todayName ? "is-today" : undefined}>
                      <td>{row.day}</td>
                      <td>{row.open && row.close ? `${row.open} – ${row.close}` : "Closed"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="info-item">
              <h3>Follow</h3>
              <Socials settings={s} />
            </div>
          </div>

          <div className="form-card" data-reveal style={{ transitionDelay: ".12s" }}>
            <h2 className="display" style={{ fontSize: 28, color: "var(--brand)", marginBottom: 24 }}>
              send us a message
            </h2>
            <ContactForm source="contact" showSubject />
          </div>
        </div>
      </section>
      <section className="container" style={{ paddingBottom: 110 }}>
        <iframe className="map-frame" src={mapSrc} title={`Map: ${s.siteName}`} loading="lazy" referrerPolicy="no-referrer-when-downgrade" allowFullScreen />
      </section>
    </>
  );
}
