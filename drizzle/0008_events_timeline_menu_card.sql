-- Update 18: real past events from the Ammos posters, timeline photos, one hero slide, "Find our menu"
-- 1) remove the old example / past events — keep RETROΛΑ and any event that is still to come
DELETE FROM "events" WHERE "starts_at" < '2026-10-16 00:00:00+00' AND "slug" NOT IN ('retroaa-dj-anagiotos', 'beats-and-fire-african-stevenson', 'feel-good-friday-dj-petros-pavlou', 'bring-back-the-90s-whitney-houston', 'nuevo-disco-summer-sunday-sessions', 'rnb-afro-reggaeton-dj-mg', 'levant-night-dj-foulides-k');--> statement-breakpoint
-- 2) the real past events (Cyprus summer time = UTC+3)
INSERT INTO "events" ("title", "slug", "category", "venue", "starts_at", "ends_at", "summary", "description", "image", "gallery", "price_info", "booking_enabled", "featured", "published") VALUES
(
  'Beats & Fire with African Stevenson & Friends', 'beats-and-fire-african-stevenson', 'Live music', 'Ammos',
  '2026-06-28 14:00:00+00', NULL,
  'Ammos presents Beats & Fire — a Sunday sunset session with African Stevenson and friends.',
  E'Ammos presents **Beats & Fire** — a Sunday session of rhythm and fire on Makenzy Beach with African Stevenson and friends.\n\n## Good to know\n- Sunday 28 June, from 17:00\n- Info & reservations: 24 82 88 44',
  '/images/ig/event-beats-and-fire.webp', '[]'::jsonb, '', false, true, true
),
(
  'Feel Good Friday with DJ Petros Pavlou', 'feel-good-friday-dj-petros-pavlou', 'Live DJ', 'Ammos',
  '2026-07-03 15:00:00+00', '2026-07-03 22:30:00+00',
  'Friday vibes, Friday mood — mainstream music to kick-start the weekend with DJ Petros Pavlou.',
  E'Friday vibes. Friday mood. Mainstream music to kick-start the weekend with **DJ Petros Pavlou**.\n\n## Good to know\n- Friday 3 July, 18:00 – 01:30\n- Info & reservations: 24 82 88 44',
  '/images/ig/event-feel-good-friday.webp', '[]'::jsonb, '', false, true, true
),
(
  'Bring Back the 90''s — dedicated to Whitney Houston', 'bring-back-the-90s-whitney-houston', 'Party', 'Ammos',
  '2026-07-17 18:30:00+00', NULL,
  'A 90''s night dedicated to Whitney Houston, with Anthony 642 on the decks.',
  E'**Bring Back the 90''s** — a night of the biggest 90''s hits, dedicated to Whitney Houston, with **Anthony 642**.\n\n## Good to know\n- Friday 17 July, starts at 21:30\n- Info & reservations: 24 82 88 44',
  '/images/ig/event-bring-back-the-90s.webp', '[]'::jsonb, '', false, true, true
),
(
  'RnB · Afro · Reggaeton with DJ MG', 'rnb-afro-reggaeton-dj-mg', 'Live DJ', 'Ammos',
  '2026-08-14 18:30:00+00', NULL,
  'DJ MG takes over Ammos with RnB, Afro and Reggaeton.',
  E'**RnB · Afro · Reggaeton** — DJ MG takes over the Ammos terrace for a tropical Friday night.\n\n## Good to know\n- Friday 14 August, take-over starts at 21:30\n- Info & reservations: 24 82 88 44',
  '/images/ig/event-rnb-afro-reggaeton.webp', '[]'::jsonb, '', false, true, true
),
(
  'Nuevo Disco — Summer Sunday Sessions', 'nuevo-disco-summer-sunday-sessions', 'Live DJ', 'Ammos',
  '2026-08-23 16:00:00+00', '2026-08-23 20:00:00+00',
  'Summer Sunday Sessions with a live set by Anthony 642 — burgers, sushi and short rib tacos.',
  E'**Nuevo Disco — Summer Sunday Sessions.** Live set by **Anthony 642**, from beats to bites and beachside rhythms.\n\n## Good to know\n- Sunday, 19:00 – 23:00\n- Burgers, sushi & short rib tacos\n- Info & reservations: 24 82 88 44',
  '/images/ig/event-nuevo-disco.webp', '[]'::jsonb, '', false, true, true
),
(
  'Levant Night with DJ Foulides.K', 'levant-night-dj-foulides-k', 'Live DJ', 'Ammos',
  '2026-10-02 18:00:00+00', NULL,
  '“East meets West” — Middle Eastern, Arabic, Greek & international music with DJ Foulides.K.',
  E'**Levant Night** — “East meets West”. A live set by **DJ Foulides.K** with Middle Eastern, Arabic, Greek & international music.\n\n## Good to know\n- Friday 2 October, starts at 21:00\n- Info & reservations: 24 82 88 44\n- Or book directly via [Klisto](https://www.klisto.com.cy/Profile/ammos)',
  '/images/ig/event-levant-night.webp', '[]'::jsonb, '', false, true, true
)
ON CONFLICT ("slug") DO NOTHING;--> statement-breakpoint
-- 3) hero: only the bar photo for now
UPDATE "site_content" SET "data" = "data" || '{"mediaType": "slideshow", "slides": [{"image": "/images/ig/hero-bar.webp", "mobileImage": "/images/ig/hero-bar-phone.webp", "position": "center 60%"}]}'::jsonb WHERE "key" = 'home.hero';--> statement-breakpoint
-- 4) homepage story: first fanned photo back to the interior, timeline 2005 = entrance, 2011 = sushi
UPDATE "site_content" SET "data" = jsonb_set("data", '{fan}', (SELECT jsonb_agg(CASE WHEN e->>'image' = '/images/ig/fan-swing.webp' THEN e || '{"image": "/images/ig/fan-interior.webp", "alt": "Inside Ammos"}'::jsonb ELSE e END ORDER BY o) FROM jsonb_array_elements("data"->'fan') WITH ORDINALITY AS t(e, o))) WHERE "key" = 'home.story' AND jsonb_typeof("data"->'fan') = 'array' AND jsonb_array_length("data"->'fan') > 0;--> statement-breakpoint
UPDATE "site_content" SET "data" = jsonb_set("data", '{timeline}', (SELECT jsonb_agg(CASE e->>'year' WHEN '2005' THEN e || '{"image": "/images/ig/fan-entrance.webp"}'::jsonb WHEN '2011' THEN e || '{"image": "/images/ig/timeline-2011-sushi.webp"}'::jsonb ELSE e END ORDER BY o) FROM jsonb_array_elements("data"->'timeline') WITH ORDINALITY AS t(e, o))) WHERE "key" = 'home.story' AND jsonb_typeof("data"->'timeline') = 'array' AND jsonb_array_length("data"->'timeline') > 0;--> statement-breakpoint
-- 5) menu block button text
UPDATE "site_content" SET "data" = "data" || '{"buttonLabel": "Find our menu"}'::jsonb WHERE "key" = 'home.menu';
