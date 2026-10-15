ALTER TABLE "admin_users" ADD COLUMN IF NOT EXISTS "notify" boolean DEFAULT true NOT NULL;--> statement-breakpoint
-- real Ammos dish photos (from Instagram) for the homepage menu hover — only where no own photo was uploaded
UPDATE "menu_items" SET "image" = '/images/ig/dish-salmon-tiratido.webp' WHERE "name" = 'Salmon Tiratido' AND ("image" = '' OR "image" LIKE '/uploads/instagram/%');--> statement-breakpoint
UPDATE "menu_items" SET "image" = '/images/ig/dish-mussels-nero.webp' WHERE "name" = 'Mussels Nero' AND ("image" = '' OR "image" LIKE '/uploads/instagram/%');--> statement-breakpoint
UPDATE "menu_items" SET "image" = '/images/ig/dish-tataki-tuna.webp' WHERE "name" = 'Tataki Tuna' AND ("image" = '' OR "image" LIKE '/uploads/instagram/%');--> statement-breakpoint
UPDATE "menu_items" SET "image" = '/images/ig/dish-oktapodi-kythira.webp' WHERE "name" = 'Oktapodi Kythira' AND ("image" = '' OR "image" LIKE '/uploads/instagram/%');--> statement-breakpoint
UPDATE "menu_items" SET "image" = '/images/ig/dish-seabass.webp' WHERE "name" = 'Seabass Fricassee' AND ("image" = '' OR "image" LIKE '/uploads/instagram/%');--> statement-breakpoint
UPDATE "menu_items" SET "image" = '/images/ig/dish-seaside-orzotto.webp' WHERE "name" = 'Seaside Orzotto' AND ("image" = '' OR "image" LIKE '/uploads/instagram/%');--> statement-breakpoint
UPDATE "menu_items" SET "image" = '/images/ig/dish-rib-eye.webp' WHERE "name" = 'Rib Eye Uruguay Angus' AND ("image" = '' OR "image" LIKE '/uploads/instagram/%');--> statement-breakpoint
UPDATE "menu_items" SET "image" = '/images/ig/dish-ammos-roll.webp' WHERE "name" = 'Ammos Roll' AND ("image" = '' OR "image" LIKE '/uploads/instagram/%');--> statement-breakpoint
UPDATE "menu_items" SET "image" = '/images/ig/dish-caldera-roll.webp' WHERE "name" = 'Caldera Roll' AND ("image" = '' OR "image" LIKE '/uploads/instagram/%');--> statement-breakpoint
UPDATE "menu_items" SET "image" = '/images/ig/dish-rainbow-roll.webp' WHERE "name" = 'Peruvian Rainbow Roll' AND ("image" = '' OR "image" LIKE '/uploads/instagram/%');--> statement-breakpoint
UPDATE "menu_items" SET "image" = '/images/ig/dish-geisha-sashimi.webp' WHERE "name" = 'Geisha Sashimi Mix' AND ("image" = '' OR "image" LIKE '/uploads/instagram/%');
