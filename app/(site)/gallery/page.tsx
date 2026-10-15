import type { Metadata } from "next";
import { getContent, getSettings } from "@/lib/content";
import { getGallery } from "@/lib/data";
import { pageMeta } from "@/lib/seo";
import { PageHero } from "@/components/site/PageHero";
import { GalleryMasonry } from "@/components/site/GalleryMasonry";
import { Icon } from "@/components/site/Icon";

export const revalidate = 300;

export async function generateMetadata(): Promise<Metadata> {
  const h = await getContent("page.headers");
  return pageMeta({ title: "Gallery — photos from Ammos Makenzy Beach", description: h.galleryText, path: "/gallery", image: h.galleryImage });
}

export default async function GalleryPage() {
  const [h, settings, photos] = await Promise.all([getContent("page.headers"), getSettings(), getGallery()]);
  return (
    <>
      <PageHero kicker={`@${settings.instagramHandle}`} title={h.galleryTitle} text={h.galleryText} image={h.galleryImage} crumbs={[{ name: "Gallery", path: "/gallery" }]}>
        <div className="btn-row" style={{ marginTop: 28 }}>
          <a href={settings.instagram} target="_blank" rel="noopener noreferrer" className="btn btn-ghost-light btn-sm">
            <Icon name="instagram" size={16} /> Follow on Instagram
          </a>
        </div>
      </PageHero>
      <section className="section">
        <div className="container">
          <GalleryMasonry photos={photos.map((p) => ({ id: p.id, image: p.image, alt: p.alt, album: p.album, video: p.video }))} />
        </div>
      </section>
    </>
  );
}
