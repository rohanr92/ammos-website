import {
  Umbrella,
  ForkKnife,
  Martini,
  VinylRecord,
  Confetti,
  Coffee,
  Sun,
  Wine,
  Fish,
  MusicNotes,
  Champagne,
  InstagramLogo,
  FacebookLogo,
  TiktokLogo,
  YoutubeLogo,
  LinktreeLogo,
  Phone,
  EnvelopeSimple,
  MapPin,
  Clock,
  CalendarBlank,
  Users,
  ArrowUpRight,
} from "@phosphor-icons/react/dist/ssr";

const ICONS = {
  umbrella: Umbrella,
  "fork-knife": ForkKnife,
  martini: Martini,
  "vinyl-record": VinylRecord,
  confetti: Confetti,
  coffee: Coffee,
  sun: Sun,
  wine: Wine,
  fish: Fish,
  "music-notes": MusicNotes,
  champagne: Champagne,
  instagram: InstagramLogo,
  facebook: FacebookLogo,
  tiktok: TiktokLogo,
  youtube: YoutubeLogo,
  linktree: LinktreeLogo,
  phone: Phone,
  mail: EnvelopeSimple,
  pin: MapPin,
  clock: Clock,
  calendar: CalendarBlank,
  users: Users,
  external: ArrowUpRight,
} as const;

export type IconName = keyof typeof ICONS;

export function Icon({ name, size = 20, className }: { name: string; size?: number; className?: string }) {
  const C = ICONS[name as IconName] ?? Confetti;
  return <C size={size} weight="fill" className={className} aria-hidden="true" />;
}
