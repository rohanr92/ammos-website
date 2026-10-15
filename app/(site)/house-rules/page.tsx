import type { Metadata } from "next";
import { pageMeta } from "@/lib/seo";
import { TextPage } from "@/components/site/TextPage";

export const revalidate = 300;

export const metadata: Metadata = pageMeta({ title: "House rules", description: "House rules at Ammos Makenzy Beach — reservations, beach and evening rules.", path: "/house-rules" });

export default function Page() {
  return <TextPage contentKey="page.houseRules" path="/house-rules" name="House rules" />;
}
