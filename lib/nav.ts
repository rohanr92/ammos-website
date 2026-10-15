/**
 * Website navigation.
 * The links are edited in Admin → Navigation (content section "navigation");
 * the defaults live in lib/content-schema.ts. This file only has the shared types/helpers.
 */
export type NavLink = { label: string; url: string; newTab?: boolean; hidden?: boolean };

export type Navigation = {
  headerLinks: NavLink[];
  headerRightLabel: string;
  headerRightUrl: string;
  reserveLabel: string;
  menuLinks: NavLink[];
  menuBottomLinks: NavLink[];
  footerColumns: NavLink[][];
  footerBarLinks: NavLink[];
};

/** Keeps only links that have text + a link and aren't hidden. */
export function visibleLinks(list: unknown): NavLink[] {
  if (!Array.isArray(list)) return [];
  return list
    .filter((l): l is NavLink => Boolean(l && typeof l === "object" && (l as NavLink).label && (l as NavLink).url && !(l as NavLink).hidden))
    .map((l) => ({ label: String(l.label).trim(), url: String(l.url).trim(), newTab: Boolean(l.newTab) }));
}

/** true for links that leave the website (https://…, mailto:, tel:) */
export function isExternal(url: string) {
  return /^(https?:)?\/\//i.test(url) || /^(mailto|tel):/i.test(url);
}
