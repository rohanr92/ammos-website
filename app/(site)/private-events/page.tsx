import type { Metadata } from "next";
import { getContent } from "@/lib/content";
import { pageMeta } from "@/lib/seo";
import { PageHero } from "@/components/site/PageHero";
import { RichText } from "@/components/site/RichText";
import { ContactForm } from "@/components/site/ContactForm";

export const revalidate = 300;

export async function generateMetadata(): Promise<Metadata> {
  const p = await getContent("page.privateEvents");
  return pageMeta({
    title: "Private events, birthdays & weddings on the beach",
    description: String(p.intro).split("\n")[0],
    path: "/private-events",
    image: p.image,
  });
}

export default async function PrivateEventsPage() {
  const p = await getContent("page.privateEvents");
  return (
    <>
      <PageHero kicker="Celebrate at Ammos" title={p.title} image={p.image} crumbs={[{ name: "Private events", path: "/private-events" }]} />
      <section className="section">
        <div className="container contact-grid">
          <div data-reveal>
            <RichText text={p.intro} />
            <div className="cards-2" style={{ marginTop: 40 }}>
              {(p.options as Record<string, string>[]).map((o, i) => (
                <div key={i} className="text-card">
                  <h3>{o.title}</h3>
                  <p>{o.text}</p>
                </div>
              ))}
            </div>
          </div>
          <div className="form-card" data-reveal style={{ transitionDelay: ".12s" }}>
            <h2 className="display" style={{ fontSize: 28, color: "var(--brand)", marginBottom: 24 }}>
              plan your event
            </h2>
            <ContactForm source="private-events" defaultSubject="Private event" buttonLabel="Send request" />
          </div>
        </div>
      </section>
    </>
  );
}
