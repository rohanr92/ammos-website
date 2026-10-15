-- swap the example event photos for real Ammos photos from Instagram (only where the example photo is still used)
UPDATE "events" SET "image" = '/images/ig/event-sunset.webp' WHERE "slug" = 'sunset-sessions-w-nikos-k' AND "image" LIKE '/images/%.jpg';--> statement-breakpoint
UPDATE "events" SET "image" = '/images/ig/event-night-party.webp' WHERE "slug" = 'full-moon-beach-party' AND "image" LIKE '/images/%.jpg';--> statement-breakpoint
UPDATE "events" SET "image" = '/images/ig/event-brunch.webp' WHERE "slug" = 'long-table-sunday-brunch' AND "image" LIKE '/images/%.jpg';--> statement-breakpoint
UPDATE "events" SET "image" = '/images/ig/event-terrace-night.webp' WHERE "slug" = 'acoustic-nights-elena-and-band' AND "image" LIKE '/images/%.jpg';--> statement-breakpoint
UPDATE "events" SET "image" = '/images/ig/event-wine-steak.webp' WHERE "slug" = 'cypriot-wine-and-meze-evening' AND "image" LIKE '/images/%.jpg';--> statement-breakpoint
UPDATE "events" SET "image" = '/images/ig/event-dj-crowd.webp' WHERE "slug" = 'ammos-summer-closing-party' AND "image" LIKE '/images/%.jpg';--> statement-breakpoint
UPDATE "events" SET "gallery" = '["/images/ig/event-night-party.webp","/images/ig/event-dj-crowd.webp","/images/ig/event-hug.webp","/images/ig/story-2015-friends.webp","/images/ig/fan-aperol.webp"]'::jsonb WHERE "gallery"::text LIKE '%/images/%.jpg%' AND "gallery"::text NOT LIKE '%/uploads/%';
