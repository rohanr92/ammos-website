import { getNavigation, getSettings } from "@/lib/content";
import { businessJsonLd } from "@/lib/seo";
import { SiteHeader } from "@/components/site/SiteHeader";
import { SiteFooter } from "@/components/site/SiteFooter";
import { SiteEffects } from "@/components/site/SiteEffects";
import { Socials } from "@/components/site/Socials";
import { JsonLd } from "@/components/site/JsonLd";

export default async function SiteLayout({ children }: { children: React.ReactNode }) {
  const [settings, nav] = await Promise.all([getSettings(), getNavigation()]);
  return (
    <>
      <a href="#main" className="skip-link">
        Skip to content
      </a>
      <SiteEffects />
      <SiteHeader settings={settings} socials={<Socials settings={settings} />} nav={nav} />
      <main id="main">{children}</main>
      <SiteFooter settings={settings} nav={nav} />
      <JsonLd data={businessJsonLd(settings)} />
    </>
  );
}
