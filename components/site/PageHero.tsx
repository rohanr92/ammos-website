import Link from "next/link";
import { Img } from "@/components/site/Img";
import { MultiLine } from "@/components/site/MultiLine";
import { JsonLd } from "@/components/site/JsonLd";
import { breadcrumbJsonLd } from "@/lib/seo";

/** Dark photo banner used at the top of every inner page. */
export function PageHero({
  kicker,
  title,
  text,
  image,
  crumbs,
  compact = false,
  children,
}: {
  kicker?: string;
  title: string;
  text?: string;
  image?: string;
  crumbs: { name: string; path: string }[];
  compact?: boolean;
  children?: React.ReactNode;
}) {
  const all = [{ name: "Home", path: "/" }, ...crumbs];
  return (
    <section className={`page-hero${compact ? " compact" : ""}`}>
      <Img src={image} alt="" preload sizes="100vw" />
      <div className="hero-shade" />
      <div className="container page-hero-body">
        <nav aria-label="Breadcrumb">
          <ol className="breadcrumbs">
            {all.map((c, i) => (
              <li key={c.path}>{i < all.length - 1 ? <Link href={c.path}>{c.name}</Link> : <span aria-current="page">{c.name}</span>}</li>
            ))}
          </ol>
        </nav>
        {kicker && <p className="kicker">{kicker}</p>}
        <h1 className="display display-xl">
          <MultiLine text={title} />
        </h1>
        {text && <p className="lead">{text}</p>}
        {children}
      </div>
      <JsonLd data={breadcrumbJsonLd(all)} />
    </section>
  );
}
