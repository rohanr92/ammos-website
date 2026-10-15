import type { Metadata } from "next";
import { getContent, getSettings } from "@/lib/content";
import { pageMeta } from "@/lib/seo";
import { PageHero } from "@/components/site/PageHero";
import { RichText } from "@/components/site/RichText";

export const revalidate = 300;

export async function generateMetadata(): Promise<Metadata> {
  return pageMeta({ title: "Careers", description: "Work at Ammos Makenzy Beach, Larnaca — hospitality jobs at our beach bar and restaurant.", path: "/careers", image: "/images/bartender.jpg" });
}

export default async function CareersPage() {
  const [p, s] = await Promise.all([getContent("page.careers"), getSettings()]);
  return (
    <>
      <PageHero compact kicker={s.hiring ? "We're hiring" : "Careers"} title={p.title} image="/images/bartender.jpg" crumbs={[{ name: "Careers", path: "/careers" }]} />
      <section className="section">
        <div className="container-narrow" data-reveal>
          {!s.hiring && (
            <p className="spots" style={{ color: "var(--muted)" }}>
              Not hiring right now
            </p>
          )}
          <RichText text={s.hiring ? p.hiringText : p.notHiringText} />
          <div className="btn-row" style={{ marginTop: 40 }}>
            <a href={`mailto:${s.email}?subject=${encodeURIComponent(s.hiring ? "Job application" : "CV for future openings")}`} className="btn btn-brand">
              Email your CV
            </a>
          </div>
        </div>
      </section>
    </>
  );
}
