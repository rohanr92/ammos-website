import { Icon } from "@/components/site/Icon";
import type { Settings } from "@/lib/content-schema";

export function Socials({ settings, tone = "on-dark" }: { settings: Partial<Settings>; tone?: "on-dark" | "on-brand" }) {
  const links = [
    { key: "facebook", label: "Facebook", href: settings.facebook },
    { key: "instagram", label: "Instagram", href: settings.instagram },
    { key: "tiktok", label: "TikTok", href: settings.tiktok },
    { key: "youtube", label: "YouTube", href: settings.youtube },
    { key: "linktree", label: "Linktree", href: settings.linktree },
  ].filter((l) => l.href);
  return (
    <div className={`socials ${tone}`}>
      {links.map((l) => (
        <a key={l.key} href={l.href} target="_blank" rel="noopener noreferrer" aria-label={`Ammos on ${l.label}`} className="social-btn">
          <Icon name={l.key} size={20} />
        </a>
      ))}
    </div>
  );
}
