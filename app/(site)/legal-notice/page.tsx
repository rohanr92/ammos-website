import type { Metadata } from "next";
import { pageMeta } from "@/lib/seo";
import { TextPage } from "@/components/site/TextPage";

export const revalidate = 300;

export const metadata: Metadata = pageMeta({ title: "Legal notice", description: "Website operator and legal information for ammos.eu.", path: "/legal-notice" });

export default function Page() {
  return <TextPage contentKey="page.legal" path="/legal-notice" name="Legal notice" />;
}
