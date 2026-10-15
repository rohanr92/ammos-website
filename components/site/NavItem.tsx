import Link from "next/link";
import { isExternal, type NavLink } from "@/lib/nav";

type Props = {
  link: NavLink;
  className?: string;
  style?: React.CSSProperties;
  tabIndex?: number;
  current?: boolean;
  /** custom inside (default: the link text) */
  children?: React.ReactNode;
  onMouseEnter?: () => void;
  onFocus?: () => void;
};

/** A menu link: internal pages use Next.js <Link>, outside links a normal <a> (new tab if wanted). */
export function NavItem({ link, className, style, tabIndex, current, children, onMouseEnter, onFocus }: Props) {
  const blank = link.newTab ? { target: "_blank", rel: "noopener noreferrer" } : {};
  const common = { className, style, tabIndex, onMouseEnter, onFocus };
  if (isExternal(link.url) || link.newTab) {
    return (
      <a href={link.url} {...common} {...blank}>
        {children ?? link.label}
      </a>
    );
  }
  return (
    <Link href={link.url} {...common} aria-current={current ? "page" : undefined}>
      {children ?? link.label}
    </Link>
  );
}
