import type { Metadata } from "next";
import type { Settings } from "@/lib/content-schema";
import type { Event, Post } from "@/lib/db/schema";
import { absoluteImage, siteUrl, truncate } from "@/lib/utils";

/** Builds page metadata with canonical URL, Open Graph and Twitter cards. */
export function pageMeta(opts: { title: string; description: string; path: string; image?: string | null; type?: "website" | "article" }): Metadata {
  const url = siteUrl(opts.path);
  const image = absoluteImage(opts.image);
  return {
    title: opts.title,
    description: truncate(opts.description, 160),
    alternates: { canonical: url },
    openGraph: {
      type: opts.type ?? "website",
      url,
      title: opts.title,
      description: truncate(opts.description, 200),
      siteName: "Ammos Makenzy Beach",
      locale: "en_GB",
      images: [{ url: image, width: 1200, height: 630, alt: opts.title }],
    },
    twitter: { card: "summary_large_image", title: opts.title, description: truncate(opts.description, 200), images: [image] },
  };
}

const DAY_MAP: Record<string, string> = {
  monday: "Monday",
  tuesday: "Tuesday",
  wednesday: "Wednesday",
  thursday: "Thursday",
  friday: "Friday",
  saturday: "Saturday",
  sunday: "Sunday",
};

/** Restaurant + bar business data for Google. */
export function businessJsonLd(s: Settings) {
  return {
    "@context": "https://schema.org",
    "@type": ["Restaurant", "BarOrPub"],
    "@id": siteUrl("/#business"),
    name: s.siteName,
    description: s.seoDescription,
    url: siteUrl("/"),
    logo: siteUrl("/images/logo.png"),
    image: [siteUrl("/opengraph-image.jpg")],
    telephone: s.phone,
    email: s.email,
    priceRange: "€€",
    servesCuisine: ["Mediterranean", "Seafood", "Sushi", "Cocktails"],
    acceptsReservations: s.reservationUrl || true,
    hasMenu: siteUrl("/menu"),
    address: {
      "@type": "PostalAddress",
      streetAddress: s.address,
      addressLocality: s.city,
      postalCode: s.postcode,
      addressCountry: "CY",
    },
    ...(Number(s.latitude) && Number(s.longitude)
      ? { geo: { "@type": "GeoCoordinates", latitude: Number(s.latitude), longitude: Number(s.longitude) } }
      : {}),
    openingHoursSpecification: (s.hours || [])
      .filter((h) => DAY_MAP[h.day?.toLowerCase?.()] && h.open && h.close)
      .map((h) => ({
        "@type": "OpeningHoursSpecification",
        dayOfWeek: `https://schema.org/${DAY_MAP[h.day.toLowerCase()]}`,
        opens: h.open,
        closes: h.close,
      })),
    sameAs: [s.facebook, s.instagram, s.tiktok, s.youtube, s.linktree].filter(Boolean),
    ...(s.googleRating && Number(s.googleRating)
      ? {
          aggregateRating: {
            "@type": "AggregateRating",
            ratingValue: s.googleRating,
            bestRating: "5",
            ratingCount: String(s.reviewCount || "").replace(/[^\d]/g, "") || "100",
          },
        }
      : {}),
  };
}

export function eventJsonLd(e: Event, s: Settings) {
  return {
    "@context": "https://schema.org",
    "@type": "Event",
    name: e.title,
    description: truncate(e.summary || e.description, 300),
    startDate: e.startsAt.toISOString(),
    ...(e.endsAt ? { endDate: e.endsAt.toISOString() } : {}),
    eventStatus: "https://schema.org/EventScheduled",
    eventAttendanceMode: "https://schema.org/OfflineEventAttendanceMode",
    image: [e.image, ...(Array.isArray(e.gallery) ? e.gallery : [])].filter(Boolean).slice(0, 6).map((src) => absoluteImage(src)),
    url: siteUrl(`/events/${e.slug}`),
    location: {
      "@type": "Place",
      name: `${s.siteName} — ${e.venue}`,
      address: { "@type": "PostalAddress", streetAddress: s.address, addressLocality: s.city, postalCode: s.postcode, addressCountry: "CY" },
    },
    organizer: { "@type": "Organization", name: s.siteName, url: siteUrl("/") },
    ...(e.bookingEnabled
      ? {
          offers: {
            "@type": "Offer",
            url: siteUrl(`/events/${e.slug}#book`),
            availability: "https://schema.org/InStock",
            price: "0",
            priceCurrency: "EUR",
            validFrom: e.createdAt.toISOString(),
          },
        }
      : {}),
  };
}

export function articleJsonLd(p: Post, s: Settings) {
  return {
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    headline: p.title,
    description: truncate(p.excerpt || p.content, 200),
    image: [absoluteImage(p.image)],
    datePublished: p.publishedAt.toISOString(),
    dateModified: p.updatedAt.toISOString(),
    mainEntityOfPage: siteUrl(`/news/${p.slug}`),
    author: { "@type": "Organization", name: s.siteName },
    publisher: { "@type": "Organization", name: s.siteName, logo: { "@type": "ImageObject", url: siteUrl("/images/logo.png") } },
  };
}

export function breadcrumbJsonLd(items: { name: string; path: string }[]) {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: items.map((it, i) => ({ "@type": "ListItem", position: i + 1, name: it.name, item: siteUrl(it.path) })),
  };
}
