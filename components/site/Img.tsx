import Image from "next/image";
import { isExternal } from "@/lib/utils";

/**
 * Image that fills its (position: relative) parent.
 * Local images (/images, /uploads) are optimised by Next.js (WebP/AVIF, right size);
 * external links are shown as a normal <img>.
 */
export function Img({
  src,
  alt = "",
  sizes = "100vw",
  className = "",
  preload = false,
  quality,
  style,
}: {
  src?: string | null;
  alt?: string;
  sizes?: string;
  className?: string;
  preload?: boolean;
  quality?: 75 | 85;
  style?: React.CSSProperties;
}) {
  if (!src) return null;
  if (isExternal(src)) {
    // eslint-disable-next-line @next/next/no-img-element
    return <img src={src} alt={alt} className={`fill-img ${className}`} loading={preload ? "eager" : "lazy"} decoding="async" style={style} />;
  }
  return <Image src={src} alt={alt} fill sizes={sizes} quality={quality} className={`cover ${className}`} preload={preload} style={style} />;
}
