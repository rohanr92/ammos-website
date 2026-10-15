import type { MetadataRoute } from "next";
import { siteUrl } from "@/lib/utils";

export default function robots(): MetadataRoute.Robots {
  const isLive = (process.env.SITE_URL || "").startsWith("https://");
  return {
    // while testing on localhost / a temporary address, keep Google out
    rules: isLive ? [{ userAgent: "*", allow: "/", disallow: ["/admin", "/api/"] }] : [{ userAgent: "*", disallow: "/" }],
    sitemap: siteUrl("/sitemap.xml"),
    host: siteUrl(),
  };
}
