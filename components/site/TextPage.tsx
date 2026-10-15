import { getContent } from "@/lib/content";
import { PageHero } from "@/components/site/PageHero";
import { RichText } from "@/components/site/RichText";

/** Simple text page (house rules, privacy, legal) — all editable in Admin → Page content. */
export async function TextPage({ contentKey, path, name }: { contentKey: string; path: string; name: string }) {
  const p = await getContent(contentKey);
  return (
    <>
      <PageHero compact title={p.title} image="/images/awards-interior.jpg" crumbs={[{ name, path }]} />
      <section className="section">
        <div className="container-narrow">
          <RichText text={p.body} />
        </div>
      </section>
    </>
  );
}
