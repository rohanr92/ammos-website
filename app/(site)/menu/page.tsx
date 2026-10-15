import type { Metadata } from "next";
import { getContent, getSettings } from "@/lib/content";
import { getFullMenu } from "@/lib/data";
import { pageMeta } from "@/lib/seo";
import { formatPrice, siteUrl, slugify } from "@/lib/utils";
import { PageHero } from "@/components/site/PageHero";
import { JsonLd } from "@/components/site/JsonLd";

export const revalidate = 300;

export async function generateMetadata(): Promise<Metadata> {
  const h = await getContent("page.headers");
  return pageMeta({
    title: "Menu — sushi, seafood, cocktails & more",
    description: `${h.menuText} See prices for food, cocktails, wines and spirits at Ammos Makenzy Beach, Larnaca.`,
    path: "/menu",
    image: h.menuImage,
  });
}

export default async function MenuPage() {
  const [h, settings, menu] = await Promise.all([getContent("page.headers"), getSettings(), getFullMenu()]);

  // group categories into their big sections (Food, Cocktails, Wines…) keeping the admin order
  const sections: { name: string; id: string; cats: typeof menu }[] = [];
  for (const c of menu) {
    let s = sections.find((x) => x.name === c.section);
    if (!s) {
      s = { name: c.section, id: slugify(c.section), cats: [] };
      sections.push(s);
    }
    s.cats.push(c);
  }

  const menuLd = {
    "@context": "https://schema.org",
    "@type": "Menu",
    name: "Ammos Makenzy Beach menu",
    url: siteUrl("/menu"),
    inLanguage: "en",
    hasMenuSection: sections.map((s) => ({
      "@type": "MenuSection",
      name: s.name,
      hasMenuSection: s.cats.map((c) => ({
        "@type": "MenuSection",
        name: c.name,
        hasMenuItem: c.items.map((i) => ({
          "@type": "MenuItem",
          name: i.name,
          ...(i.description ? { description: i.description.slice(0, 200) } : {}),
          offers: { "@type": "Offer", price: Number(i.price).toFixed(2), priceCurrency: "EUR" },
        })),
      })),
    })),
  };

  return (
    <>
      <PageHero kicker="Salivating yet?" title={h.menuTitle} text={h.menuText} image={h.menuImage} crumbs={[{ name: "Menu", path: "/menu" }]}>
        <div className="btn-row" style={{ marginTop: 28 }}>
          <a href={settings.reservationUrl} target="_blank" rel="noopener noreferrer" className="btn btn-brand">
            Book a table
          </a>
        </div>
      </PageHero>

      {sections.length > 1 && (
        <nav className="menu-page-nav" aria-label="Menu sections">
          <div className="row">
            {sections.map((s) => (
              <a key={s.id} href={`#${s.id}`} className="pill">
                {s.name}
              </a>
            ))}
          </div>
        </nav>
      )}

      {sections.map((s, si) => (
        <section key={s.id} id={s.id} className={`menu-section${si % 2 ? " section-alt" : ""}`} aria-labelledby={`${s.id}-title`}>
          <div className="container">
            <h2 id={`${s.id}-title`} className="display display-md">
              {s.name}
            </h2>
            {s.cats.map((c) => (
              <div key={c.id} id={`cat-${c.slug}`} className="menu-cat">
                <h3>{c.name}</h3>
                {c.description && <p className="muted" style={{ margin: "10px 0 0" }}>{c.description}</p>}
                <div className="menu-items">
                  {c.items.map((i) => {
                    const tags = i.tags.split(",").map((t) => t.trim()).filter(Boolean);
                    const allergens = i.allergens.split(",").map((t) => t.trim()).filter(Boolean);
                    return (
                      <div key={i.id} className="menu-item">
                        <h4>{i.name}</h4>
                        <span className="price">{formatPrice(i.price)}</span>
                        {i.description && <p>{i.description}</p>}
                        {(tags.length > 0 || allergens.length > 0) && (
                          <div className="menu-tags">
                            {tags.map((t) => (
                              <span key={t} className="chip green">
                                {t}
                              </span>
                            ))}
                            {allergens.map((a) => (
                              <span key={a} className="chip" title="Allergen">
                                {a}
                              </span>
                            ))}
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>
        </section>
      ))}

      <section className="container" style={{ paddingBottom: 100 }}>
        <p className="allergen-note">
          Prices are in euro and include VAT. Grey tags show allergens. If you have a food allergy or intolerance, please tell your waiter before ordering — our team will be happy to help.
        </p>
      </section>
      <JsonLd data={menuLd} />
    </>
  );
}
