import Link from "next/link";
import type { Metadata } from "next";
import { getContent } from "@/lib/content";
import { listPosts } from "@/lib/data";
import { pageMeta } from "@/lib/seo";
import { formatDate } from "@/lib/utils";
import { PageHero } from "@/components/site/PageHero";
import { Img } from "@/components/site/Img";

export const revalidate = 300;

export async function generateMetadata(): Promise<Metadata> {
  const h = await getContent("page.headers");
  return pageMeta({ title: "News & stories", description: h.newsText, path: "/news", image: h.newsImage });
}

export default async function NewsPage() {
  const [h, posts] = await Promise.all([getContent("page.headers"), listPosts()]);
  return (
    <>
      <PageHero kicker="Beyond the bar" title={h.newsTitle} text={h.newsText} image={h.newsImage} crumbs={[{ name: "News", path: "/news" }]} />
      <section className="section">
        <div className="container">
          {posts.length ? (
            <div className="news-grid">
              {posts.map((p, i) => (
                <article key={p.id} data-reveal style={{ transitionDelay: `${(i % 3) * 0.12}s` }}>
                  <div className="news-card">
                    <Img src={p.image} alt={p.title} sizes="(max-width: 900px) 100vw, 33vw" />
                    <div className="news-card-shade" />
                    <span className="news-kicker">{p.kicker}</span>
                    <time className="eyebrow" style={{ position: "relative", color: "var(--lime)", marginBottom: 10 }} dateTime={p.publishedAt.toISOString()}>
                      {formatDate(p.publishedAt, { month: "long", year: "numeric" })}
                    </time>
                    <h2 className="display" style={{ position: "relative", fontSize: "clamp(24px, 2.4vw, 34px)", lineHeight: 1.1, marginBottom: 10 }}>
                      {p.title}
                    </h2>
                    <p>{p.excerpt}</p>
                    <Link href={`/news/${p.slug}`} className="btn btn-ghost-light btn-sm stretched">
                      Read more ↗
                    </Link>
                  </div>
                </article>
              ))}
            </div>
          ) : (
            <div className="empty-state">
              <h2 className="display">Stories coming soon</h2>
            </div>
          )}
        </div>
      </section>
    </>
  );
}
