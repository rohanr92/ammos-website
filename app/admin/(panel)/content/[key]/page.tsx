import Link from "next/link";
import { notFound } from "next/navigation";
import { SECTION_MAP } from "@/lib/content-schema";
import { getContent } from "@/lib/content";
import { PageTop } from "@/components/admin/PageTop";
import { ContentForm } from "@/components/admin/ContentForm";

export const dynamic = "force-dynamic";

const PREVIEW: Record<string, string> = {
  settings: "/contact",
  "page.story": "/our-story",
  "page.headers": "/events",
  "page.privateEvents": "/private-events",
  "page.careers": "/careers",
  "page.houseRules": "/house-rules",
  "page.privacy": "/privacy-policy",
  "page.legal": "/legal-notice",
};

export default async function ContentEdit({ params }: { params: Promise<{ key: string }> }) {
  const { key } = await params;
  const def = SECTION_MAP[key];
  if (!def) notFound();
  const values = await getContent(key);
  return (
    <>
      <PageTop
        title={def.title}
        actions={
          <Link href="/admin/content" className="a-btn ghost">
            ← All sections
          </Link>
        }
      />
      <div className="a-content" style={{ maxWidth: 980 }}>
        <p className="a-desc">{def.description}</p>
        <ContentForm sectionKey={key} fields={def.fields} initial={values} previewUrl={PREVIEW[key] ?? "/"} />
      </div>
    </>
  );
}
