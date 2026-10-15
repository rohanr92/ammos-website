-- Only real upcoming event: RETROΛΑ with DJ Anagiotos, Fri 16 Oct 2026, 21:00 Cyprus time (= 18:00 UTC)
INSERT INTO "events" ("title", "slug", "category", "venue", "starts_at", "summary", "description", "image", "gallery", "price_info", "booking_enabled", "featured", "published")
VALUES (
  'RETROΛΑ with DJ Anagiotos',
  'retroaa-dj-anagiotos',
  'Live DJ',
  'Ammos',
  '2026-10-16 18:00:00+00',
  'RETROΛΑ is back — Greek & English retro hits with DJ Anagiotos, featuring live percussion.',
  E'RETROΛΑ is back! DJ Anagiotos plays the best Greek & English retro hits all night, featuring live percussion.\n\n## Good to know\n- Friday 16 October, starts at 21:00\n- Info & reservations: 24 82 88 44\n- Or book your table directly via [Klisto](https://www.klisto.com.cy/Profile/ammos)\n\n[Watch the video on Instagram](https://www.instagram.com/reel/DeYujcco2rM/)',
  '/images/ig/event-retroaa.webp',
  '[]'::jsonb,
  '',
  true, true, true
)
ON CONFLICT ("slug") DO NOTHING;--> statement-breakpoint
-- the example events become past events (they show with the "Event passed" tag)
UPDATE "events" SET "starts_at" = '2026-09-18 16:00:00+00', "ends_at" = NULL WHERE "slug" = 'sunset-sessions-w-nikos-k' AND "starts_at" > '2026-10-12';--> statement-breakpoint
UPDATE "events" SET "starts_at" = '2026-09-26 18:00:00+00', "ends_at" = NULL WHERE "slug" = 'full-moon-beach-party' AND "starts_at" > '2026-10-12';--> statement-breakpoint
UPDATE "events" SET "starts_at" = '2026-10-04 08:30:00+00', "ends_at" = NULL WHERE "slug" = 'long-table-sunday-brunch' AND "starts_at" > '2026-10-12';--> statement-breakpoint
UPDATE "events" SET "starts_at" = '2026-10-08 17:00:00+00', "ends_at" = NULL WHERE "slug" = 'acoustic-nights-elena-and-band' AND "starts_at" > '2026-10-12';--> statement-breakpoint
UPDATE "events" SET "starts_at" = '2026-10-10 16:30:00+00', "ends_at" = NULL WHERE "slug" = 'cypriot-wine-and-meze-evening' AND "starts_at" > '2026-10-12';--> statement-breakpoint
UPDATE "events" SET "starts_at" = '2026-10-11 18:00:00+00', "ends_at" = NULL WHERE "slug" = 'ammos-summer-closing-party' AND "starts_at" > '2026-10-12';--> statement-breakpoint
-- hero second button → "View menu", events block title → "our events" (only if still the old default text)
UPDATE "site_content" SET "data" = "data" || '{"secondaryLabel": "View menu", "secondaryUrl": "/menu"}'::jsonb WHERE "key" = 'home.hero' AND COALESCE("data"->>'secondaryLabel', 'View events') = 'View events';--> statement-breakpoint
UPDATE "site_content" SET "data" = "data" || '{"title": "our events"}'::jsonb WHERE "key" = 'home.events' AND COALESCE("data"->>'title', 'upcoming events') = 'upcoming events';
