import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";
import { getSettings } from "@/lib/content";
import { siteUrl } from "@/lib/utils";
import "./globals.css";

// Fonts are stored inside the project (no Google request at runtime → faster + GDPR friendly)
const jost = localFont({ src: "./fonts/jost-latin.woff2", variable: "--font-jost", weight: "300 700", display: "swap" });
const marcellus = localFont({ src: "./fonts/marcellus-latin.woff2", variable: "--font-marcellus", weight: "400", display: "swap" });

export async function generateMetadata(): Promise<Metadata> {
  const s = await getSettings();
  return {
    metadataBase: new URL(siteUrl()),
    title: { default: s.seoTitle, template: "%s | Ammos Makenzy Beach" },
    description: s.seoDescription,
    applicationName: s.siteName,
    keywords: [
      "Ammos",
      "Ammos Beach Bar",
      "Makenzy Beach",
      "Mackenzie Beach",
      "Larnaca",
      "Cyprus",
      "beach bar",
      "restaurant Larnaca",
      "sushi Larnaca",
      "cocktails",
      "events Larnaca",
    ],
    alternates: { canonical: siteUrl("/") },
    openGraph: {
      type: "website",
      siteName: s.siteName,
      locale: "en_GB",
      url: siteUrl("/"),
      title: s.seoTitle,
      description: s.seoDescription,
      images: [{ url: "/opengraph-image.jpg", width: 1200, height: 630, alt: s.siteName }],
    },
    twitter: { card: "summary_large_image", title: s.seoTitle, description: s.seoDescription, images: ["/opengraph-image.jpg"] },
    robots: { index: true, follow: true, googleBot: { index: true, follow: true, "max-image-preview": "large" } },
    formatDetection: { telephone: true, email: true, address: true },
  };
}

export const viewport: Viewport = {
  themeColor: "#0f1119",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${jost.variable} ${marcellus.variable} no-js`} suppressHydrationWarning>
      <body>{children}</body>
    </html>
  );
}
