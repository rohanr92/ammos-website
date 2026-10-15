import type { Metadata } from "next";
import { pageMeta } from "@/lib/seo";
import { TextPage } from "@/components/site/TextPage";

export const revalidate = 300;

export const metadata: Metadata = pageMeta({ title: "Privacy policy", description: "How Ammos Makenzy Beach collects and uses personal data (GDPR).", path: "/privacy-policy" });

export default function Page() {
  return <TextPage contentKey="page.privacy" path="/privacy-policy" name="Privacy policy" />;
}
