import Link from "next/link";
import { isExternal, type NavLink } from "@/lib/nav";

/** A menu link: internal pages use Next.js <Link>, outside links a normal <a> (new tab if wanted). */
export function NavItem({ link, className, style, tabIndex, current }: { link: NavLink; className?: string; style?: React.CSSProperties; tabIndex?: number; current?: boolean }) {
  const blank = link.newTab ? { target: "_blank", rel: "noopener noreferrer" } : {};
  if (isExternal(link.url) || link.newTab) {
    return (
      <a href={link.url} className={className} style={style} tabIndex={tabIndex} {...blank}>
        {link.label}
      </a>
    );
  }
  return (
    <Link href={link.url} className={className} style={style} tabIndex={tabIndex} aria-current={current ? "page" : undefined}>
      {link.label}
    </Link>
  );
}
