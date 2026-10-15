ALTER TABLE "gallery_images" ADD COLUMN IF NOT EXISTS "video" text DEFAULT '' NOT NULL;
