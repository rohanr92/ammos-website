import Link from "next/link";
import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { getSettings } from "@/lib/content";
import { getPostBySlug, listPosts } from "@/lib/data";
import { articleJsonLd, pageMeta } from "@/lib/seo";
import { formatDate, truncate } from "@/lib/utils";
import { PageHero } from "@/components/site/PageHero";
import { RichText } from "@/components/site/RichText";
import { Img } from "@/components/site/Img";
import { JsonLd } from "@/components/site/JsonLd";

export const revalidate = 300;
export const dynamicParams = true;
export function generateStaticParams() {
  return [];
}

type Params = Promise<{ slug: string }>;

export async function generateMetadata({ params }: { params: Params }): Promise<Metadata> {
  const { slug } = await params;
  const p = await getPostBySlug(slug);
  if (!p) return { title: "Story not found", robots: { index: false } };
  return pageMeta({ title: p.title, description: truncate(p.excerpt || p.content, 160), path: `/news/${p.slug}`, image: p.image, type: "article" });
}

export default async function PostPage({ params }: { params: Params }) {
  const { slug } = await params;
  const post = await getPostBySlug(slug);
  if (!post) notFound();
  const [settings, more] = await Promise.all([getSettings(), listPosts(4)]);
  const others = more.filter((p) => p.id !== post.id).slice(0, 3);

  return (
    <article>
      <PageHero
        kicker={`${post.kicker} · ${formatDate(post.publishedAt)}`}
        title={post.title}
        text={post.excerpt}
        image={post.image}
        crumbs={[
          { name: "News", path: "/news" },
          { name: post.title, path: `/news/${post.slug}` },
        ]}
      />
      <section className="section" style={{ paddingTop: 72 }}>
        <div className="container-narrow">
          <RichText text={post.content} />
          <div className="btn-row" style={{ marginTop: 48 }}>
            <Link href="/news" className="btn btn-outline">
              ← All stories
            </Link>
            <Link href="/events" className="btn btn-muted">
              Upcoming events
            </Link>
          </div>
        </div>
      </section>
      {others.length > 0 && (
        <section className="section section-alt">
          <div className="container">
            <h2 className="display display-md" style={{ marginBottom: 32 }}>
              more stories
            </h2>
            <div className="news-grid">
              {others.map((p) => (
                <div key={p.id} className="news-card" style={{ aspectRatio: "4/3" }}>
                  <Img src={p.image} alt={p.title} sizes="33vw" />
                  <div className="news-card-shade" />
                  <span className="news-kicker">{p.kicker}</span>
                  <h3 className="display" style={{ fontSize: 24 }}>
                    {p.title}
                  </h3>
                  <Link href={`/news/${p.slug}`} className="btn btn-ghost-light btn-sm stretched">
                    Read ↗
                  </Link>
                </div>
              ))}
            </div>
          </div>
        </section>
      )}
      <JsonLd data={articleJsonLd(post, settings)} />
    </article>
  );
}
