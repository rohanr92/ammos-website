import Link from "next/link";
import type { Metadata } from "next";
import { getContent, getSettings } from "@/lib/content";
import { LIVE_MENU_PAGE } from "@/lib/menu-import";
import { pageMeta } from "@/lib/seo";
import { PageHero } from "@/components/site/PageHero";
import { Img } from "@/components/site/Img";
import { RichText } from "@/components/site/RichText";

export const revalidate = 300;

export async function generateMetadata(): Promise<Metadata> {
  const p = await getContent("page.story");
  return pageMeta({
    title: "The Ammos story — first beach bar on Makenzy Beach since 2005",
    description: String(p.intro).split("\n")[0],
    path: "/our-story",
    image: p.heroImage,
  });
}

export default async function StoryPage() {
  const [p, home, settings] = await Promise.all([getContent("page.story"), getContent("home.story"), getSettings()]);
  return (
    <>
      <PageHero kicker={p.kicker} title={p.title} image={p.heroImage} crumbs={[{ name: "Our story", path: "/our-story" }]} />

      <section className="section">
        <div className="container-narrow" data-reveal>
          <RichText text={p.intro} className="prose" />
        </div>
      </section>



      <section className="section">
        <div className="container">
          {(p.chapters as Record<string, string>[]).map((c, i) => (
            <article key={i} className="chapter">
              <div className="chapter-media" data-reveal style={{ ["--from" as string]: i % 2 ? "translate3d(60px,0,0)" : "translate3d(-60px,0,0)" }}>
                <div className="img-frame" style={{ aspectRatio: "4/5" }}>
                  <Img src={c.image} alt={c.title} sizes="(max-width: 900px) 100vw, 45vw" />
                </div>
              </div>
              <div data-reveal style={{ transitionDelay: ".12s" }}>
                {c.kicker && <p className="kicker">{c.kicker}</p>}
                <h2 className="display display-md" style={{ marginBottom: 24 }}>
                  {c.title}
                </h2>
                <RichText text={c.text} />
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className="section section-alt">
        <div className="container">
          <div className="story-head" data-reveal>
            <div>
              <p className="kicker">{home.kicker}</p>
              <h2 className="display display-lg">{home.title}</h2>
            </div>
            <p className="lead">{home.text}</p>
          </div>
          <div className="timeline">
            {(home.timeline as Record<string, string>[]).map((t, i) => (
              <div key={i} data-reveal style={{ transitionDelay: `${i * 0.12}s` }}>
                <span className="timeline-dot" style={{ boxShadow: "0 0 0 5px var(--bg2)" }} />
                <span className="timeline-year">{t.year}</span>
                <div className="timeline-img">
                  <Img src={t.image} alt={t.title} sizes="(max-width: 900px) 50vw, 25vw" />
                </div>
                <h3 className="display">{t.title}</h3>
                <p>{t.text}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {p.quote && (
        <section className="section">
          <div className="container" data-reveal>
            <p className="big-quote">{p.quote}</p>
            <div className="center-row">
              <a href={settings.reservationUrl} target="_blank" rel="noopener noreferrer" className="btn btn-brand">
                Book a table
              </a>
              <span style={{ width: 14 }} />
              <a href={LIVE_MENU_PAGE} target="_blank" rel="noopener noreferrer" className="btn btn-outline">
                See the menu
              </a>
            </div>
          </div>
        </section>
      )}
    </>
  );
}
