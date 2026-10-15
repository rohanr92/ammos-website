ALTER TABLE "events" ADD COLUMN IF NOT EXISTS "gallery" jsonb DEFAULT '[]'::jsonb NOT NULL;--> statement-breakpoint
-- remove the placeholder dish photos that the first install put on menu items (real photos uploaded in the admin are kept)
UPDATE "menu_items" SET "image" = '' WHERE "image" IN ('/images/chef-plate.jpg','/images/flowers.jpg','/images/awards-interior.jpg','/images/hero-kitchen.jpg','/images/party.jpg','/images/bartender.jpg','/images/bar-interior.jpg');--> statement-breakpoint
-- example photos for the example events (replace them in Admin → Events)
UPDATE "events" SET "gallery" = '["/images/party.jpg","/images/bartender.jpg","/images/bar-interior.jpg","/images/awards-interior.jpg","/images/chef-plate.jpg"]'::jsonb WHERE "gallery" = '[]'::jsonb AND "image" LIKE '/images/%';
