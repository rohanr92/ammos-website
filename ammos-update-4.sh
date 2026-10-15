#!/bin/bash
# Ammos website — update 4: Instagram photos & reels in the gallery
# Run inside the ammos-website folder:  bash ammos-update-4.sh
set -e
if [ ! -f package.json ] || ! grep -q "\"ammos-website\"" package.json; then
  echo "✖ Run this inside the ammos-website folder (cd into it first)."; exit 1
fi
if [ ! -f components/admin/MenuPhotosUpload.tsx ]; then
  echo "✖ Run ammos-update-3.sh first:  bash ammos-update-3.sh"; exit 1
fi
echo "→ Updating files…"

cat > "package.json" << 'AMMOS_EOF'
{
  "name": "ammos-website",
  "version": "1.0.0",
  "private": true,
  "description": "Ammos Makenzy Beach — website, events booking and admin panel",
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start -p ${PORT:-3000}",
    "typecheck": "tsc --noEmit",
    "db:create": "tsx scripts/create-db.ts",
    "db:generate": "drizzle-kit generate",
    "db:migrate": "tsx scripts/migrate.ts",
    "db:seed": "tsx scripts/seed.ts",
    "db:studio": "drizzle-kit studio",
    "admin:create": "tsx scripts/create-admin.ts",
    "menu:sync": "tsx scripts/sync-menu.ts",
    "gallery:instagram": "tsx scripts/import-instagram.ts",
    "setup": "npm run db:create && npm run db:migrate && npm run db:seed"
  },
  "engines": {
    "node": ">=20.9.0"
  },
  "dependencies": {
    "@phosphor-icons/react": "2.1.10",
    "bcryptjs": "3.0.3",
    "drizzle-orm": "0.45.4",
    "jose": "6.2.12",
    "lenis": "1.3.26",
    "next": "16.4.1",
    "nodemailer": "10.1.1",
    "pg": "8.23.1",
    "react": "19.3.1",
    "react-dom": "19.3.1",
    "server-only": "0.0.1",
    "sharp": "0.35.5",
    "zod": "4.6.7"
  },
  "devDependencies": {
    "@types/node": "22.20.5",
    "@types/nodemailer": "8.0.2",
    "@types/pg": "8.23.1",
    "@types/react": "19.3.0",
    "@types/react-dom": "19.3.0",
    "dotenv": "18.0.8",
    "drizzle-kit": "0.31.11",
    "tsx": "4.23.15",
    "typescript": "5.9.3"
  }
}
AMMOS_EOF
echo "  ✔ package.json"

mkdir -p "lib/db"
cat > "lib/db/schema.ts" << 'AMMOS_EOF'
import {
  pgTable,
  uuid,
  text,
  integer,
  boolean,
  timestamp,
  jsonb,
  index,
  uniqueIndex,
  numeric,
} from "drizzle-orm/pg-core";

const createdAt = () => timestamp("created_at", { withTimezone: true }).notNull().defaultNow();
const updatedAt = () =>
  timestamp("updated_at", { withTimezone: true })
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date());

/* ───────────── Admin users ───────────── */
export const adminUsers = pgTable(
  "admin_users",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    email: text("email").notNull(),
    name: text("name").notNull().default(""),
    passwordHash: text("password_hash").notNull(),
    role: text("role").notNull().default("editor"), // "owner" | "editor"
    // bumped on logout-all / password change → invalidates every issued JWT
    tokenVersion: integer("token_version").notNull().default(1),
    failedLogins: integer("failed_logins").notNull().default(0),
    lockedUntil: timestamp("locked_until", { withTimezone: true }),
    lastLoginAt: timestamp("last_login_at", { withTimezone: true }),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [uniqueIndex("admin_users_email_idx").on(t.email)],
);

/* ───────────── Events ───────────── */
export const events = pgTable(
  "events",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    title: text("title").notNull(),
    slug: text("slug").notNull(),
    category: text("category").notNull().default("Party"), // tag shown on cards, e.g. "Live DJ"
    venue: text("venue").notNull().default("Terrace"), // e.g. Terrace / Beach / Restaurant
    startsAt: timestamp("starts_at", { withTimezone: true }).notNull(),
    endsAt: timestamp("ends_at", { withTimezone: true }),
    summary: text("summary").notNull().default(""),
    description: text("description").notNull().default(""),
    image: text("image").notNull().default(""),
    gallery: jsonb("gallery").$type<string[]>().notNull().default([]), // extra photos shown on the event page
    priceInfo: text("price_info").notNull().default(""), // e.g. "Free entry" / "€25 incl. welcome drink"
    capacity: integer("capacity"), // max guests that can book online (empty = unlimited)
    bookingEnabled: boolean("booking_enabled").notNull().default(true),
    featured: boolean("featured").notNull().default(true), // show on homepage
    published: boolean("published").notNull().default(true),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [uniqueIndex("events_slug_idx").on(t.slug), index("events_starts_idx").on(t.startsAt)],
);

/* ───────────── Event bookings ───────────── */
export const bookings = pgTable(
  "bookings",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    reference: text("reference").notNull(), // short code shown to the guest, e.g. AM-7K3Q9
    eventId: uuid("event_id").references(() => events.id, { onDelete: "set null" }),
    eventTitle: text("event_title").notNull().default(""), // snapshot, kept even if the event is deleted
    eventDate: timestamp("event_date", { withTimezone: true }),
    firstName: text("first_name").notNull(),
    lastName: text("last_name").notNull().default(""),
    email: text("email").notNull(),
    phone: text("phone").notNull(),
    guests: integer("guests").notNull().default(2),
    seating: text("seating").notNull().default(""), // preference: Terrace / Beach / Bar / Any
    occasion: text("occasion").notNull().default(""),
    message: text("message").notNull().default(""),
    status: text("status").notNull().default("pending"), // pending | confirmed | cancelled
    adminNotes: text("admin_notes").notNull().default(""),
    marketingOptIn: boolean("marketing_opt_in").notNull().default(false),
    ip: text("ip").notNull().default(""),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [
    uniqueIndex("bookings_reference_idx").on(t.reference),
    index("bookings_event_idx").on(t.eventId),
    index("bookings_created_idx").on(t.createdAt),
  ],
);

/* ───────────── Contact form messages ───────────── */
export const messages = pgTable(
  "messages",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    firstName: text("first_name").notNull(),
    lastName: text("last_name").notNull().default(""),
    email: text("email").notNull(),
    phone: text("phone").notNull().default(""),
    subject: text("subject").notNull().default("General enquiry"),
    visitDate: text("visit_date").notNull().default(""),
    guests: integer("guests"),
    message: text("message").notNull(),
    source: text("source").notNull().default("contact"), // contact | home | private-events
    isRead: boolean("is_read").notNull().default(false),
    ip: text("ip").notNull().default(""),
    createdAt: createdAt(),
  },
  (t) => [index("messages_created_idx").on(t.createdAt)],
);

/* ───────────── Menu ───────────── */
export const menuCategories = pgTable(
  "menu_categories",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    name: text("name").notNull(),
    slug: text("slug").notNull(),
    section: text("section").notNull().default("Food"), // big group: Food, Cocktails, Wines, …
    description: text("description").notNull().default(""),
    sortOrder: integer("sort_order").notNull().default(0),
    published: boolean("published").notNull().default(true),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [uniqueIndex("menu_categories_slug_idx").on(t.slug)],
);

export const menuItems = pgTable(
  "menu_items",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    categoryId: uuid("category_id")
      .notNull()
      .references(() => menuCategories.id, { onDelete: "cascade" }),
    name: text("name").notNull(),
    description: text("description").notNull().default(""),
    price: numeric("price", { precision: 8, scale: 2 }).notNull().default("0"),
    image: text("image").notNull().default(""),
    allergens: text("allergens").notNull().default(""), // comma separated
    tags: text("tags").notNull().default(""), // e.g. Vegan, Healthy
    featured: boolean("featured").notNull().default(false), // show on homepage menu block
    sortOrder: integer("sort_order").notNull().default(0),
    published: boolean("published").notNull().default(true),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [index("menu_items_category_idx").on(t.categoryId)],
);

/* ───────────── Gallery ───────────── */
export const galleryImages = pgTable("gallery_images", {
  id: uuid("id").primaryKey().defaultRandom(),
  image: text("image").notNull(),
  alt: text("alt").notNull().default(""),
  album: text("album").notNull().default("The Beach"),
  video: text("video").notNull().default(""), // optional: Instagram reel/post link or an uploaded .mp4 — the photo is then the video cover
  showOnHome: boolean("show_on_home").notNull().default(true),
  sortOrder: integer("sort_order").notNull().default(0),
  published: boolean("published").notNull().default(true),
  createdAt: createdAt(),
  updatedAt: updatedAt(),
});

/* ───────────── News & stories ───────────── */
export const posts = pgTable(
  "posts",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    title: text("title").notNull(),
    slug: text("slug").notNull(),
    kicker: text("kicker").notNull().default("News"),
    excerpt: text("excerpt").notNull().default(""),
    content: text("content").notNull().default(""),
    image: text("image").notNull().default(""),
    publishedAt: timestamp("published_at", { withTimezone: true }).notNull().defaultNow(),
    published: boolean("published").notNull().default(true),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [uniqueIndex("posts_slug_idx").on(t.slug)],
);

/* ───────────── Reviews ───────────── */
export const reviews = pgTable("reviews", {
  id: uuid("id").primaryKey().defaultRandom(),
  name: text("name").notNull(),
  meta: text("meta").notNull().default("Google"),
  text: text("text").notNull(),
  rating: integer("rating").notNull().default(5),
  sortOrder: integer("sort_order").notNull().default(0),
  published: boolean("published").notNull().default(true),
  createdAt: createdAt(),
  updatedAt: updatedAt(),
});

/* ───────────── Short links / redirects (e.g. /ourmenu → /menu) ───────────── */
export const redirects = pgTable(
  "redirects",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    fromPath: text("from_path").notNull(),
    toPath: text("to_path").notNull(),
    permanent: boolean("permanent").notNull().default(true),
    hits: integer("hits").notNull().default(0),
    createdAt: createdAt(),
    updatedAt: updatedAt(),
  },
  (t) => [uniqueIndex("redirects_from_idx").on(t.fromPath)],
);

/* ───────────── Editable page content (texts & images per section) ───────────── */
export const siteContent = pgTable("site_content", {
  key: text("key").primaryKey(),
  data: jsonb("data").notNull().$type<Record<string, unknown>>(),
  updatedAt: updatedAt(),
});

export type Event = typeof events.$inferSelect;
export type Booking = typeof bookings.$inferSelect;
export type Message = typeof messages.$inferSelect;
export type MenuCategory = typeof menuCategories.$inferSelect;
export type MenuItem = typeof menuItems.$inferSelect;
export type GalleryImage = typeof galleryImages.$inferSelect;
export type Post = typeof posts.$inferSelect;
export type Review = typeof reviews.$inferSelect;
export type Redirect = typeof redirects.$inferSelect;
export type AdminUser = typeof adminUsers.$inferSelect;
AMMOS_EOF
echo "  ✔ lib/db/schema.ts"

mkdir -p "drizzle"
cat > "drizzle/0002_gallery_video.sql" << 'AMMOS_EOF'
ALTER TABLE "gallery_images" ADD COLUMN IF NOT EXISTS "video" text DEFAULT '' NOT NULL;
AMMOS_EOF
echo "  ✔ drizzle/0002_gallery_video.sql"

mkdir -p "drizzle/meta"
cat > "drizzle/meta/_journal.json" << 'AMMOS_EOF'
{
  "version": "7",
  "dialect": "postgresql",
  "entries": [
    {
      "idx": 0,
      "version": "7",
      "when": 1792052067838,
      "tag": "0000_init",
      "breakpoints": true
    },
    {
      "idx": 1,
      "version": "7",
      "when": 1792060864108,
      "tag": "0001_event_gallery",
      "breakpoints": true
    },
    {
      "idx": 2,
      "version": "7",
      "when": 1792063196474,
      "tag": "0002_gallery_video",
      "breakpoints": true
    }
  ]
}
AMMOS_EOF
echo "  ✔ drizzle/meta/_journal.json"

mkdir -p "drizzle/meta"
cat > "drizzle/meta/0002_snapshot.json" << 'AMMOS_EOF'
{
  "id": "420ee43d-445e-4141-814a-d9edc4241e24",
  "prevId": "6fe722f4-c209-4240-ba9b-11411671c10c",
  "version": "7",
  "dialect": "postgresql",
  "tables": {
    "public.admin_users": {
      "name": "admin_users",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "email": {
          "name": "email",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "name": {
          "name": "name",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "password_hash": {
          "name": "password_hash",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "role": {
          "name": "role",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'editor'"
        },
        "token_version": {
          "name": "token_version",
          "type": "integer",
          "primaryKey": false,
          "notNull": true,
          "default": 1
        },
        "failed_logins": {
          "name": "failed_logins",
          "type": "integer",
          "primaryKey": false,
          "notNull": true,
          "default": 0
        },
        "locked_until": {
          "name": "locked_until",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": false
        },
        "last_login_at": {
          "name": "last_login_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": false
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {
        "admin_users_email_idx": {
          "name": "admin_users_email_idx",
          "columns": [
            {
              "expression": "email",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": true,
          "concurrently": false,
          "method": "btree",
          "with": {}
        }
      },
      "foreignKeys": {},
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.bookings": {
      "name": "bookings",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "reference": {
          "name": "reference",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "event_id": {
          "name": "event_id",
          "type": "uuid",
          "primaryKey": false,
          "notNull": false
        },
        "event_title": {
          "name": "event_title",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "event_date": {
          "name": "event_date",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": false
        },
        "first_name": {
          "name": "first_name",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "last_name": {
          "name": "last_name",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "email": {
          "name": "email",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "phone": {
          "name": "phone",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "guests": {
          "name": "guests",
          "type": "integer",
          "primaryKey": false,
          "notNull": true,
          "default": 2
        },
        "seating": {
          "name": "seating",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "occasion": {
          "name": "occasion",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "message": {
          "name": "message",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "status": {
          "name": "status",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'pending'"
        },
        "admin_notes": {
          "name": "admin_notes",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "marketing_opt_in": {
          "name": "marketing_opt_in",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": false
        },
        "ip": {
          "name": "ip",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {
        "bookings_reference_idx": {
          "name": "bookings_reference_idx",
          "columns": [
            {
              "expression": "reference",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": true,
          "concurrently": false,
          "method": "btree",
          "with": {}
        },
        "bookings_event_idx": {
          "name": "bookings_event_idx",
          "columns": [
            {
              "expression": "event_id",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": false,
          "concurrently": false,
          "method": "btree",
          "with": {}
        },
        "bookings_created_idx": {
          "name": "bookings_created_idx",
          "columns": [
            {
              "expression": "created_at",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": false,
          "concurrently": false,
          "method": "btree",
          "with": {}
        }
      },
      "foreignKeys": {
        "bookings_event_id_events_id_fk": {
          "name": "bookings_event_id_events_id_fk",
          "tableFrom": "bookings",
          "tableTo": "events",
          "columnsFrom": [
            "event_id"
          ],
          "columnsTo": [
            "id"
          ],
          "onDelete": "set null",
          "onUpdate": "no action"
        }
      },
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.events": {
      "name": "events",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "title": {
          "name": "title",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "slug": {
          "name": "slug",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "category": {
          "name": "category",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'Party'"
        },
        "venue": {
          "name": "venue",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'Terrace'"
        },
        "starts_at": {
          "name": "starts_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true
        },
        "ends_at": {
          "name": "ends_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": false
        },
        "summary": {
          "name": "summary",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "description": {
          "name": "description",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "image": {
          "name": "image",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "gallery": {
          "name": "gallery",
          "type": "jsonb",
          "primaryKey": false,
          "notNull": true,
          "default": "'[]'::jsonb"
        },
        "price_info": {
          "name": "price_info",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "capacity": {
          "name": "capacity",
          "type": "integer",
          "primaryKey": false,
          "notNull": false
        },
        "booking_enabled": {
          "name": "booking_enabled",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "featured": {
          "name": "featured",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "published": {
          "name": "published",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {
        "events_slug_idx": {
          "name": "events_slug_idx",
          "columns": [
            {
              "expression": "slug",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": true,
          "concurrently": false,
          "method": "btree",
          "with": {}
        },
        "events_starts_idx": {
          "name": "events_starts_idx",
          "columns": [
            {
              "expression": "starts_at",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": false,
          "concurrently": false,
          "method": "btree",
          "with": {}
        }
      },
      "foreignKeys": {},
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.gallery_images": {
      "name": "gallery_images",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "image": {
          "name": "image",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "alt": {
          "name": "alt",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "album": {
          "name": "album",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'The Beach'"
        },
        "video": {
          "name": "video",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "show_on_home": {
          "name": "show_on_home",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "sort_order": {
          "name": "sort_order",
          "type": "integer",
          "primaryKey": false,
          "notNull": true,
          "default": 0
        },
        "published": {
          "name": "published",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {},
      "foreignKeys": {},
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.menu_categories": {
      "name": "menu_categories",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "name": {
          "name": "name",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "slug": {
          "name": "slug",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "section": {
          "name": "section",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'Food'"
        },
        "description": {
          "name": "description",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "sort_order": {
          "name": "sort_order",
          "type": "integer",
          "primaryKey": false,
          "notNull": true,
          "default": 0
        },
        "published": {
          "name": "published",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {
        "menu_categories_slug_idx": {
          "name": "menu_categories_slug_idx",
          "columns": [
            {
              "expression": "slug",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": true,
          "concurrently": false,
          "method": "btree",
          "with": {}
        }
      },
      "foreignKeys": {},
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.menu_items": {
      "name": "menu_items",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "category_id": {
          "name": "category_id",
          "type": "uuid",
          "primaryKey": false,
          "notNull": true
        },
        "name": {
          "name": "name",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "description": {
          "name": "description",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "price": {
          "name": "price",
          "type": "numeric(8, 2)",
          "primaryKey": false,
          "notNull": true,
          "default": "'0'"
        },
        "image": {
          "name": "image",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "allergens": {
          "name": "allergens",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "tags": {
          "name": "tags",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "featured": {
          "name": "featured",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": false
        },
        "sort_order": {
          "name": "sort_order",
          "type": "integer",
          "primaryKey": false,
          "notNull": true,
          "default": 0
        },
        "published": {
          "name": "published",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {
        "menu_items_category_idx": {
          "name": "menu_items_category_idx",
          "columns": [
            {
              "expression": "category_id",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": false,
          "concurrently": false,
          "method": "btree",
          "with": {}
        }
      },
      "foreignKeys": {
        "menu_items_category_id_menu_categories_id_fk": {
          "name": "menu_items_category_id_menu_categories_id_fk",
          "tableFrom": "menu_items",
          "tableTo": "menu_categories",
          "columnsFrom": [
            "category_id"
          ],
          "columnsTo": [
            "id"
          ],
          "onDelete": "cascade",
          "onUpdate": "no action"
        }
      },
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.messages": {
      "name": "messages",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "first_name": {
          "name": "first_name",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "last_name": {
          "name": "last_name",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "email": {
          "name": "email",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "phone": {
          "name": "phone",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "subject": {
          "name": "subject",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'General enquiry'"
        },
        "visit_date": {
          "name": "visit_date",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "guests": {
          "name": "guests",
          "type": "integer",
          "primaryKey": false,
          "notNull": false
        },
        "message": {
          "name": "message",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "source": {
          "name": "source",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'contact'"
        },
        "is_read": {
          "name": "is_read",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": false
        },
        "ip": {
          "name": "ip",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {
        "messages_created_idx": {
          "name": "messages_created_idx",
          "columns": [
            {
              "expression": "created_at",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": false,
          "concurrently": false,
          "method": "btree",
          "with": {}
        }
      },
      "foreignKeys": {},
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.posts": {
      "name": "posts",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "title": {
          "name": "title",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "slug": {
          "name": "slug",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "kicker": {
          "name": "kicker",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'News'"
        },
        "excerpt": {
          "name": "excerpt",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "content": {
          "name": "content",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "image": {
          "name": "image",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "''"
        },
        "published_at": {
          "name": "published_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "published": {
          "name": "published",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {
        "posts_slug_idx": {
          "name": "posts_slug_idx",
          "columns": [
            {
              "expression": "slug",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": true,
          "concurrently": false,
          "method": "btree",
          "with": {}
        }
      },
      "foreignKeys": {},
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.redirects": {
      "name": "redirects",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "from_path": {
          "name": "from_path",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "to_path": {
          "name": "to_path",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "permanent": {
          "name": "permanent",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "hits": {
          "name": "hits",
          "type": "integer",
          "primaryKey": false,
          "notNull": true,
          "default": 0
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {
        "redirects_from_idx": {
          "name": "redirects_from_idx",
          "columns": [
            {
              "expression": "from_path",
              "isExpression": false,
              "asc": true,
              "nulls": "last"
            }
          ],
          "isUnique": true,
          "concurrently": false,
          "method": "btree",
          "with": {}
        }
      },
      "foreignKeys": {},
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.reviews": {
      "name": "reviews",
      "schema": "",
      "columns": {
        "id": {
          "name": "id",
          "type": "uuid",
          "primaryKey": true,
          "notNull": true,
          "default": "gen_random_uuid()"
        },
        "name": {
          "name": "name",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "meta": {
          "name": "meta",
          "type": "text",
          "primaryKey": false,
          "notNull": true,
          "default": "'Google'"
        },
        "text": {
          "name": "text",
          "type": "text",
          "primaryKey": false,
          "notNull": true
        },
        "rating": {
          "name": "rating",
          "type": "integer",
          "primaryKey": false,
          "notNull": true,
          "default": 5
        },
        "sort_order": {
          "name": "sort_order",
          "type": "integer",
          "primaryKey": false,
          "notNull": true,
          "default": 0
        },
        "published": {
          "name": "published",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
        },
        "created_at": {
          "name": "created_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {},
      "foreignKeys": {},
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    },
    "public.site_content": {
      "name": "site_content",
      "schema": "",
      "columns": {
        "key": {
          "name": "key",
          "type": "text",
          "primaryKey": true,
          "notNull": true
        },
        "data": {
          "name": "data",
          "type": "jsonb",
          "primaryKey": false,
          "notNull": true
        },
        "updated_at": {
          "name": "updated_at",
          "type": "timestamp with time zone",
          "primaryKey": false,
          "notNull": true,
          "default": "now()"
        }
      },
      "indexes": {},
      "foreignKeys": {},
      "compositePrimaryKeys": {},
      "uniqueConstraints": {},
      "policies": {},
      "checkConstraints": {},
      "isRLSEnabled": false
    }
  },
  "enums": {},
  "schemas": {},
  "sequences": {},
  "roles": {},
  "policies": {},
  "views": {},
  "_meta": {
    "columns": {},
    "schemas": {},
    "tables": {}
  }
}
AMMOS_EOF
echo "  ✔ drizzle/meta/0002_snapshot.json"

mkdir -p "lib/admin"
cat > "lib/admin/resources.ts" << 'AMMOS_EOF'
/**
 * ADMIN RESOURCES
 * Everything the admin can list / create / edit / delete, with the form fields.
 * (Client-safe: no database code here. The server side lives in resources.server.ts.)
 */

export type AdminField = {
  name: string;
  label: string;
  type:
    | "text"
    | "slug"
    | "textarea"
    | "richtext"
    | "url"
    | "email"
    | "image"
    | "images"
    | "video"
    | "number"
    | "price"
    | "checkbox"
    | "datetime"
    | "select"
    | "relation";
  required?: boolean;
  help?: string;
  half?: boolean;
  options?: { value: string; label: string }[];
  suggestions?: string[];
  relation?: "menuCategories";
  max?: number;
};

export type Column = { key: string; label: string; kind?: "image" | "date" | "datetime" | "bool" | "price" | "text" | "count" };

export type ResourceDef = {
  key: string; // used in the URL: /admin/<key>
  title: string;
  singular: string;
  description: string;
  fields: AdminField[];
  columns: Column[];
  searchable: string[];
  defaults: Record<string, unknown>;
  /** public page to open from the editor (":slug" is replaced) */
  viewPath?: string;
};

const opt = (...vals: string[]) => vals.map((v) => ({ value: v, label: v }));

export const RESOURCES: ResourceDef[] = [
  {
    key: "events",
    title: "Events",
    singular: "event",
    description: "Parties, live music, brunches… Upcoming events show on the website automatically and move to “Past events” after the date.",
    viewPath: "/events/:slug",
    fields: [
      { name: "title", label: "Title", type: "text", required: true, max: 160 },
      { name: "slug", label: "Web address", type: "slug", help: "Leave empty to create it from the title, e.g. full-moon-beach-party" },
      { name: "startsAt", label: "Starts (Cyprus time)", type: "datetime", required: true, half: true },
      { name: "endsAt", label: "Ends (optional)", type: "datetime", half: true },
      { name: "category", label: "Type / tag", type: "text", required: true, half: true, suggestions: ["Live DJ", "Party", "Live music", "Dining", "Brunch", "Tasting", "Community", "Special"] },
      { name: "venue", label: "Where", type: "text", required: true, half: true, suggestions: ["Terrace", "Beach", "Restaurant", "Bar", "Whole venue"] },
      { name: "summary", label: "Short summary", type: "textarea", help: "1–2 sentences. Shown under the title and in Google.", max: 400 },
      { name: "description", label: "Full description", type: "richtext", max: 20000 },
      { name: "image", label: "Main photo", type: "image", required: true, help: "Used on the event card and at the top of the event page. Portrait or square photos look best (at least 1000px)." },
      { name: "gallery", label: "Event photos", type: "images", help: "Extra photos shown on the event page next to the booking form. Select several at once; drag to change the order." },
      { name: "priceInfo", label: "Entry / price info", type: "text", half: true, help: "e.g. Free entry, €25 incl. welcome drink" },
      { name: "capacity", label: "Online booking limit (guests)", type: "number", half: true, help: "Empty = no limit" },
      { name: "bookingEnabled", label: "Allow online booking", type: "checkbox", half: true },
      { name: "featured", label: "Show on homepage slider", type: "checkbox", half: true },
      { name: "published", label: "Published (visible on website)", type: "checkbox" },
    ],
    columns: [
      { key: "image", label: "", kind: "image" },
      { key: "title", label: "Event" },
      { key: "startsAt", label: "Date", kind: "datetime" },
      { key: "category", label: "Type" },
      { key: "bookingCount", label: "Booked guests", kind: "count" },
      { key: "published", label: "Live", kind: "bool" },
    ],
    searchable: ["title", "category", "venue"],
    defaults: { category: "Party", venue: "Terrace", gallery: [], bookingEnabled: true, featured: true, published: true },
  },
  {
    key: "menu-items",
    title: "Menu items",
    singular: "menu item",
    description: "Dishes and drinks. Tick “Show on homepage” for the dishes in the homepage menu block (max 6 per category, 4 categories).",
    viewPath: "/menu",
    fields: [
      { name: "categoryId", label: "Category", type: "relation", relation: "menuCategories", required: true, half: true },
      { name: "price", label: "Price (€)", type: "price", required: true, half: true },
      { name: "name", label: "Name", type: "text", required: true, max: 160 },
      { name: "description", label: "Description", type: "textarea", max: 2000 },
      { name: "allergens", label: "Allergens", type: "text", half: true, help: "Comma separated, e.g. fish, milk, sesame" },
      { name: "tags", label: "Tags", type: "text", half: true, help: "e.g. Vegan, Healthy, Spicy" },
      { name: "image", label: "Photo (optional)", type: "image", help: "Shown when hovering the dish on the homepage and as a thumbnail on the menu page." },
      { name: "sortOrder", label: "Order", type: "number", half: true, help: "Lower numbers show first" },
      { name: "featured", label: "Show on homepage", type: "checkbox", half: true },
      { name: "published", label: "Visible on menu", type: "checkbox" },
    ],
    columns: [
      { key: "image", label: "", kind: "image" },
      { key: "name", label: "Item" },
      { key: "categoryName", label: "Category" },
      { key: "price", label: "Price", kind: "price" },
      { key: "featured", label: "Home", kind: "bool" },
      { key: "published", label: "Live", kind: "bool" },
    ],
    searchable: ["name", "description"],
    defaults: { price: "0", sortOrder: 100, featured: false, published: true },
  },
  {
    key: "menu-categories",
    title: "Menu categories",
    singular: "menu category",
    description: "Groups like Starters, Sushi, Cocktails. “Section” is the big heading on the menu page (Food, Wines, Spirits…).",
    viewPath: "/menu",
    fields: [
      { name: "name", label: "Name", type: "text", required: true, half: true },
      { name: "section", label: "Section", type: "text", required: true, half: true, suggestions: ["Food", "Early Bites", "Cocktails", "Beverages", "Wines", "Beers", "Spirits", "Whisky", "Other"] },
      { name: "slug", label: "Web address", type: "slug", help: "Leave empty to create it from the name" },
      { name: "description", label: "Short note (optional)", type: "textarea", max: 500 },
      { name: "sortOrder", label: "Order", type: "number", half: true, help: "Lower numbers show first" },
      { name: "published", label: "Visible on menu", type: "checkbox", half: true },
    ],
    columns: [
      { key: "name", label: "Category" },
      { key: "section", label: "Section" },
      { key: "itemCount", label: "Items", kind: "count" },
      { key: "sortOrder", label: "Order" },
      { key: "published", label: "Live", kind: "bool" },
    ],
    searchable: ["name", "section"],
    defaults: { section: "Food", sortOrder: 100, published: true },
  },
  {
    key: "gallery",
    title: "Gallery",
    singular: "photo",
    description: "Photos for the Gallery page. Tick “Show on homepage” for the photo grid on the homepage (the first 12 are used).",
    viewPath: "/gallery",
    fields: [
      { name: "image", label: "Photo", type: "image", required: true, help: "For a video, this is the cover picture." },
      { name: "video", label: "Video (optional)", type: "url", help: "Paste an Instagram reel/post link (https://www.instagram.com/reel/…) or an .mp4 link. Guests see a play button and the video plays in the gallery." },
      { name: "alt", label: "Description (for Google & accessibility)", type: "text", help: "e.g. Sunset cocktails on the Ammos terrace" },
      { name: "album", label: "Album", type: "text", half: true, suggestions: ["The Beach", "Food", "The Bar", "Events", "Videos"] },
      { name: "sortOrder", label: "Order", type: "number", half: true },
      { name: "showOnHome", label: "Show on homepage", type: "checkbox", half: true },
      { name: "published", label: "Visible", type: "checkbox", half: true },
    ],
    columns: [
      { key: "image", label: "", kind: "image" },
      { key: "alt", label: "Description" },
      { key: "album", label: "Album" },
      { key: "showOnHome", label: "Home", kind: "bool" },
      { key: "published", label: "Live", kind: "bool" },
    ],
    searchable: ["alt", "album"],
    defaults: { album: "The Beach", video: "", sortOrder: 100, showOnHome: true, published: true },
  },
  {
    key: "news",
    title: "News & stories",
    singular: "story",
    description: "Blog posts and news. The newest 3 appear on the homepage.",
    viewPath: "/news/:slug",
    fields: [
      { name: "title", label: "Title", type: "text", required: true, max: 160 },
      { name: "slug", label: "Web address", type: "slug", help: "Leave empty to create it from the title" },
      { name: "kicker", label: "Label", type: "text", half: true, suggestions: ["News", "Party", "Community", "Food", "Reunion"] },
      { name: "publishedAt", label: "Publish date", type: "datetime", half: true, required: true },
      { name: "excerpt", label: "Short intro", type: "textarea", max: 400 },
      { name: "content", label: "Story", type: "richtext", max: 50000 },
      { name: "image", label: "Cover photo", type: "image", required: true },
      { name: "published", label: "Published", type: "checkbox" },
    ],
    columns: [
      { key: "image", label: "", kind: "image" },
      { key: "title", label: "Title" },
      { key: "kicker", label: "Label" },
      { key: "publishedAt", label: "Date", kind: "date" },
      { key: "published", label: "Live", kind: "bool" },
    ],
    searchable: ["title", "excerpt"],
    defaults: { kicker: "News", published: true },
  },
  {
    key: "reviews",
    title: "Reviews",
    singular: "review",
    description: "Guest reviews shown in the moving “You said it” block. Copy your best Google reviews here.",
    fields: [
      { name: "name", label: "Guest name", type: "text", required: true, half: true },
      { name: "meta", label: "Source / place", type: "text", half: true, help: "e.g. Google · London" },
      { name: "text", label: "Review", type: "textarea", required: true, max: 600 },
      { name: "rating", label: "Stars (1–5)", type: "number", half: true },
      { name: "sortOrder", label: "Order", type: "number", half: true },
      { name: "published", label: "Visible", type: "checkbox" },
    ],
    columns: [
      { key: "name", label: "Guest" },
      { key: "text", label: "Review" },
      { key: "rating", label: "Stars" },
      { key: "published", label: "Live", kind: "bool" },
    ],
    searchable: ["name", "text"],
    defaults: { meta: "Google", rating: 5, sortOrder: 100, published: true },
  },
  {
    key: "redirects",
    title: "Redirects",
    singular: "redirect",
    description: "Short links. Example: “/ourmenu” → “/menu” sends anyone typing ammos.eu/ourmenu to the menu page. Changes apply within 1 minute.",
    fields: [
      { name: "fromPath", label: "From (path on ammos.eu)", type: "text", required: true, half: true, help: "Starts with /, e.g. /ourmenu" },
      { name: "toPath", label: "To (page or full link)", type: "text", required: true, half: true, help: "e.g. /menu or https://…" },
      { name: "permanent", label: "Permanent (recommended for SEO)", type: "checkbox" },
    ],
    columns: [
      { key: "fromPath", label: "From" },
      { key: "toPath", label: "To" },
      { key: "hits", label: "Visits", kind: "count" },
      { key: "permanent", label: "Permanent", kind: "bool" },
    ],
    searchable: ["fromPath", "toPath"],
    defaults: { permanent: true },
  },
];

export const RESOURCE_MAP: Record<string, ResourceDef> = Object.fromEntries(RESOURCES.map((r) => [r.key, r]));
AMMOS_EOF
echo "  ✔ lib/admin/resources.ts"

mkdir -p "components/site"
cat > "components/site/GalleryMasonry.tsx" << 'AMMOS_EOF'
"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Image from "next/image";

type Photo = { id: string; image: string; alt: string; album: string; video?: string };

/** Instagram post/reel link → embeddable player URL (null if it isn't one). */
function instagramEmbed(url: string) {
  const m = /instagram\.com\/(?:[\w.]+\/)?(p|reel|tv)\/([\w-]+)/i.exec(url);
  return m ? `https://www.instagram.com/${m[1] === "tv" ? "reel" : m[1]}/${m[2]}/embed/` : null;
}

/** Gallery page: album filter, masonry grid and a full-screen viewer (← → keys, ESC). Videos play inside the viewer. */
export function GalleryMasonry({ photos }: { photos: Photo[] }) {
  const albums = useMemo(() => {
    const list = Array.from(new Set(photos.map((p) => p.album).filter(Boolean)));
    // keep "Videos" last
    return [...list.filter((a) => a !== "Videos"), ...list.filter((a) => a === "Videos")];
  }, [photos]);
  const [album, setAlbum] = useState<string>("All");
  const [open, setOpen] = useState<number | null>(null);
  const [limit, setLimit] = useState(40);
  const list = album === "All" ? photos : photos.filter((p) => p.album === album);
  const shown = list.slice(0, limit);

  const close = useCallback(() => setOpen(null), []);
  const step = useCallback((d: number) => setOpen((i) => (i === null ? i : (i + d + list.length) % list.length)), [list.length]);

  useEffect(() => {
    if (open === null) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") close();
      if (e.key === "ArrowRight") step(1);
      if (e.key === "ArrowLeft") step(-1);
    };
    window.addEventListener("keydown", onKey);
    document.documentElement.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.documentElement.style.overflow = "";
    };
  }, [open, close, step]);

  const current = open !== null ? list[open] : null;
  const embed = current?.video ? instagramEmbed(current.video) : null;

  return (
    <>
      {albums.length > 1 && (
        <div className="filter-bar">
          <div className="group" role="group" aria-label="Albums">
            {["All", ...albums].map((a) => (
              <button
                key={a}
                type="button"
                className={`pill${album === a ? " is-active" : ""}`}
                onClick={() => {
                  setAlbum(a);
                  setLimit(40);
                }}
              >
                {a}
              </button>
            ))}
          </div>
        </div>
      )}
      <div className="masonry">
        {shown.map((p, i) => (
          <button
            key={p.id}
            type="button"
            className={`masonry-item${p.video ? " is-video" : ""}`}
            onClick={() => setOpen(i)}
            aria-label={`${p.video ? "Play video" : "Open photo"}: ${p.alt || "Ammos"}`}
          >
            {/^https?:/.test(p.image) ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={p.image} alt={p.alt} loading="lazy" />
            ) : (
              <Image src={p.image} alt={p.alt} width={600} height={600} sizes="(max-width: 600px) 50vw, 25vw" style={{ height: "auto" }} />
            )}
            {p.video && (
              <span className="play-badge" aria-hidden="true">
                <svg viewBox="0 0 24 24" width="22" height="22">
                  <path d="M8 5v14l11-7z" fill="currentColor" />
                </svg>
              </span>
            )}
          </button>
        ))}
      </div>
      {list.length > shown.length && (
        <div className="center-row">
          <button type="button" className="btn btn-outline" onClick={() => setLimit((l) => l + 40)}>
            Show more ({list.length - shown.length})
          </button>
        </div>
      )}
      {current && (
        <div className="lightbox" role="dialog" aria-modal="true" aria-label={current.video ? "Video player" : "Photo viewer"} onClick={close}>
          {current.video ? (
            embed ? (
              <iframe
                key={embed}
                className="lb-embed"
                src={embed}
                title={current.alt || "Ammos video"}
                allow="autoplay; encrypted-media; picture-in-picture"
                allowFullScreen
                onClick={(e) => e.stopPropagation()}
              />
            ) : (
              <video key={current.video} className="lb-video" src={current.video} poster={current.image} controls autoPlay playsInline onClick={(e) => e.stopPropagation()} />
            )
          ) : (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={current.image} alt={current.alt} onClick={(e) => e.stopPropagation()} />
          )}
          <button type="button" className="round-btn on-dark lb-btn lb-prev" aria-label="Previous" onClick={(e) => (e.stopPropagation(), step(-1))}>
            ←
          </button>
          <button type="button" className="round-btn on-dark lb-btn lb-next" aria-label="Next" onClick={(e) => (e.stopPropagation(), step(1))}>
            →
          </button>
          <button type="button" className="round-btn on-dark lb-close" aria-label="Close" onClick={close}>
            ×
          </button>
          {current.alt && !current.video && <p className="lb-cap">{current.alt}</p>}
        </div>
      )}
    </>
  );
}
AMMOS_EOF
echo "  ✔ components/site/GalleryMasonry.tsx"

mkdir -p "app/(site)/gallery"
cat > "app/(site)/gallery/page.tsx" << 'AMMOS_EOF'
import type { Metadata } from "next";
import { getContent, getSettings } from "@/lib/content";
import { getGallery } from "@/lib/data";
import { pageMeta } from "@/lib/seo";
import { PageHero } from "@/components/site/PageHero";
import { GalleryMasonry } from "@/components/site/GalleryMasonry";
import { Icon } from "@/components/site/Icon";

export const revalidate = 300;

export async function generateMetadata(): Promise<Metadata> {
  const h = await getContent("page.headers");
  return pageMeta({ title: "Gallery — photos from Ammos Makenzy Beach", description: h.galleryText, path: "/gallery", image: h.galleryImage });
}

export default async function GalleryPage() {
  const [h, settings, photos] = await Promise.all([getContent("page.headers"), getSettings(), getGallery()]);
  return (
    <>
      <PageHero kicker={`@${settings.instagramHandle}`} title={h.galleryTitle} text={h.galleryText} image={h.galleryImage} crumbs={[{ name: "Gallery", path: "/gallery" }]}>
        <div className="btn-row" style={{ marginTop: 28 }}>
          <a href={settings.instagram} target="_blank" rel="noopener noreferrer" className="btn btn-ghost-light btn-sm">
            <Icon name="instagram" size={16} /> Follow on Instagram
          </a>
        </div>
      </PageHero>
      <section className="section">
        <div className="container">
          <GalleryMasonry photos={photos.map((p) => ({ id: p.id, image: p.image, alt: p.alt, album: p.album, video: p.video }))} />
        </div>
      </section>
    </>
  );
}
AMMOS_EOF
echo "  ✔ app/(site)/gallery/page.tsx"

mkdir -p "scripts"
cat > "scripts/import-instagram.ts" << 'AMMOS_EOF'
/**
 * Imports the Ammos Instagram photos & reels into the website gallery.
 * Run:  npm run gallery:instagram
 *
 * - reads scripts/seed-data/instagram.json (made from instagram.com/ammosbeachbar);
 *   if that file doesn't exist yet, it takes the list from the clipboard (pbpaste on Mac)
 * - downloads every photo, optimises it to WebP and stores it in uploads/instagram/
 * - adds it to Admin → Gallery (albums: The Beach, Food, The Bar, Events, Videos)
 * - reels get a play button and play inside the gallery
 * - food photos whose caption names a dish are also used as that dish's menu photo
 * - the example photos from the first install are hidden (add --keep-samples to keep them)
 * Safe to run again: photos already imported are skipped.
 */
import { execSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import sharp from "sharp";
import { and, eq, like } from "drizzle-orm";
import { db, pool, schema } from "./db";

type Post = { c: string; t: "p" | "reel"; al: string; a: string; s: string };

const LIST = join(process.cwd(), "scripts/seed-data/instagram.json");
const OUT_DIR = join(resolve(process.cwd(), process.env.UPLOAD_DIR || "./uploads"), "instagram");

function loadList(): Post[] {
  let raw = "";
  if (existsSync(LIST)) raw = readFileSync(LIST, "utf8");
  else {
    try {
      raw = execSync("pbpaste", { encoding: "utf8", maxBuffer: 50 * 1024 * 1024 });
    } catch {
      /* not a Mac */
    }
  }
  let list: Post[] = [];
  try {
    list = JSON.parse(raw.trim());
  } catch {
    /* handled below */
  }
  if (!Array.isArray(list) || !list.length || !list[0]?.c || !list[0]?.s) {
    console.error(
      "\n✖ No Instagram list found.\n  In the Claude browser pane (Instagram page) click the blue “COPY AMMOS LIST” button,\n  then run this command again WITHOUT copying anything else in between.\n",
    );
    process.exit(1);
  }
  if (!existsSync(LIST)) {
    writeFileSync(LIST, JSON.stringify(list));
    console.log(`• Saved the list to scripts/seed-data/instagram.json (${list.length} posts)`);
  }
  return list;
}

/** caption words → menu item name, for photos that show a specific dish */
const DISH_HINTS: [RegExp, string][] = [
  [/octopus|oktapodi/i, "Oktapodi Kythira"],
  [/rib ?eye/i, "Rib Eye Uruguay Angus"],
  [/ravioli/i, "Ravioli Pastitsio"],
  [/tataki/i, "Tataki Tuna"],
  [/tiratido|tiradito/i, "Salmon Tiratido"],
  [/mussels/i, "Mussels Nero"],
  [/sea ?bass/i, "Seabass Fricassee"],
  [/orzotto/i, "Seaside Orzotto"],
];

async function download(url: string) {
  const res = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0 (Macintosh) ammos.eu gallery import" }, signal: AbortSignal.timeout(30000) });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return Buffer.from(await res.arrayBuffer());
}

async function main() {
  const list = loadList();
  mkdirSync(OUT_DIR, { recursive: true });
  const menu = await db.select({ id: schema.menuItems.id, name: schema.menuItems.name, image: schema.menuItems.image }).from(schema.menuItems);

  let added = 0;
  let skipped = 0;
  let failed = 0;
  let expired = 0;
  let homeCount = 0;
  const dishSet = new Set<string>();

  const queue = list.map((p, i) => ({ p, i }));
  async function worker() {
    for (let job = queue.shift(); job; job = queue.shift()) {
      const { p, i } = job;
      const path = `/uploads/instagram/${p.c}.webp`;
      const exists = await db.select({ id: schema.galleryImages.id }).from(schema.galleryImages).where(eq(schema.galleryImages.image, path)).limit(1);
      if (exists.length) {
        skipped++;
        continue;
      }
      try {
        const buf = await download(p.s);
        const out = await sharp(buf).rotate().resize({ width: 1600, height: 1600, fit: "inside", withoutEnlargement: true }).webp({ quality: 82 }).toBuffer();
        writeFileSync(join(OUT_DIR, `${p.c}.webp`), out);
        const isVideo = p.t === "reel" || p.al === "Videos";
        const onHome = !isVideo && p.al !== "Events" && homeCount < 12;
        if (onHome) homeCount++;
        await db.insert(schema.galleryImages).values({
          image: path,
          alt: p.a || "Ammos Makenzy Beach, Larnaca",
          album: p.al || "The Beach",
          video: isVideo ? `https://www.instagram.com/${p.t === "p" ? "p" : "reel"}/${p.c}/` : "",
          showOnHome: onHome,
          sortOrder: (i + 1) * 10,
          published: true,
        });
        added++;
        if (!isVideo && p.al === "Food") {
          for (const [re, dish] of DISH_HINTS) {
            const item = menu.find((m) => m.name.toLowerCase() === dish.toLowerCase());
            if (re.test(p.a) && item && !item.image && !dishSet.has(item.id)) {
              await db.update(schema.menuItems).set({ image: path, updatedAt: new Date() }).where(eq(schema.menuItems.id, item.id));
              dishSet.add(item.id);
              console.log(`  🍽  ${item.name} ← ${p.c}`);
            }
          }
        }
        if (added % 20 === 0) console.log(`  … ${added} imported`);
      } catch (err) {
        const msg = (err as Error).message;
        if (/HTTP 403|HTTP 410/.test(msg)) expired++;
        else failed++;
        console.log(`  ! ${p.c}: ${msg}`);
      }
    }
  }
  await Promise.all([worker(), worker(), worker(), worker()]);

  if (added > 0 && !process.argv.includes("--keep-samples")) {
    const hidden = await db
      .update(schema.galleryImages)
      .set({ published: false, showOnHome: false })
      .where(and(like(schema.galleryImages.image, "/images/%"), eq(schema.galleryImages.published, true)))
      .returning({ id: schema.galleryImages.id });
    if (hidden.length) console.log(`• Hid ${hidden.length} example photos from the first install`);
  }

  console.log(`\n✔ Instagram import: ${added} added, ${skipped} already there, ${failed + expired} failed. ${dishSet.size} dish photos set.`);
  if (expired) console.log("  Some Instagram links have expired — ask Claude to refresh the list, then delete scripts/seed-data/instagram.json and run again.");
  console.log("  Restart `npm run dev` (or wait 5 minutes on the live site) to see them on /gallery.");
}

main()
  .catch((err) => {
    console.error("✖ Import failed:", err.message || err);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
AMMOS_EOF
echo "  ✔ scripts/import-instagram.ts"

mkdir -p "app"
cat > "app/globals.css" << 'AMMOS_EOF'
/* ════════════════════════════════════════════════════════════════
   AMMOS MAKENZY BEACH — website styles
   Brand: cyan #3ec6d8 · lime #b7d44a · midnight #0f1119
   Titles: Marcellus (uppercase) · Body: Jost
   ════════════════════════════════════════════════════════════════ */

:root {
  --brand: #3ec6d8;
  --brand-hover: #7fdce8;
  --lime: #b7d44a;
  --ink: #0f1119;
  --teal: #157f8f;
  --bg: #0f1119;
  --bg2: #141726;
  --surface: #1c1f2c;
  --text: #e9e9ed;
  --muted: #cfd3e5;
  --muted2: #9397ab;
  --border: #3f424d;
  --border2: #292b31;
  --title: #b8cdd1;
  --ghost: #292b31;
  --overlay: rgba(15, 17, 25, 0.82);
  --paper: #f3f5fe;
  --img-shadow: 0 30px 60px rgba(0, 0, 0, 0.45);
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 14px;
  --ease: cubic-bezier(0.22, 0.61, 0.36, 1);
  --ease-out: cubic-bezier(0.2, 0.7, 0.2, 1);
  --display: var(--font-marcellus), "Marcellus", Georgia, serif;
  --body: var(--font-jost), "Jost", system-ui, sans-serif;
  --gutter: 32px;
  color-scheme: dark;
}

*,
*::before,
*::after { box-sizing: border-box; }

html { -webkit-text-size-adjust: 100%; }
html.lenis, html.lenis body { height: auto; }
.lenis.lenis-smooth { scroll-behavior: auto !important; }
.lenis.lenis-stopped { overflow: hidden; }

body {
  margin: 0;
  background: var(--bg);
  color: var(--text);
  font-family: var(--body);
  font-weight: 400;
  font-size: 15px;
  line-height: 1.55;
  overflow-x: hidden;
  -webkit-font-smoothing: antialiased;
}

a { color: var(--brand); text-decoration: none; transition: color 0.25s; }
a:hover { color: var(--brand-hover); }
img, video { display: block; max-width: 100%; }
h1, h2, h3, h4, p, figure, blockquote { margin: 0; }
button { font: inherit; }
:focus { outline: none; }
:focus-visible { outline: 2px solid var(--brand); outline-offset: 3px; }
::selection { background: rgba(62, 198, 216, 0.3); }

.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }
.skip-link { position: absolute; left: 16px; top: -60px; z-index: 200; background: var(--brand); color: var(--ink); padding: 10px 16px; border-radius: 999px; font-weight: 600; }
.skip-link:focus { top: 16px; color: var(--ink); }

/* ── layout ── */
.container { max-width: 1360px; margin: 0 auto; padding: 0 var(--gutter); width: 100%; }
.container-narrow { max-width: 900px; margin: 0 auto; padding: 0 var(--gutter); }
.section { padding: 110px 0; }
.section-alt { background: var(--bg2); border-top: 1px solid var(--border2); }
.section-white { background: #fff; color: var(--ink); }

/* ── type ── */
.display {
  font-family: var(--display);
  font-weight: 400;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  line-height: 1.08;
  text-wrap: balance;
}
.display-xl { font-size: clamp(40px, 6.4vw, 88px); }
.display-lg { font-size: clamp(38px, 5.4vw, 72px); color: var(--title); }
.display-md { font-size: clamp(34px, 4.6vw, 60px); color: var(--title); }
.display-sm { font-size: clamp(26px, 2.6vw, 36px); }
.title-brand { color: var(--brand); }
.kicker { margin: 0 0 14px; font-size: 12px; letter-spacing: 0.28em; text-transform: uppercase; color: var(--lime); font-weight: 500; }
.kicker-teal { color: var(--teal); }
.lead { font-size: 17px; line-height: 1.65; color: var(--muted); font-weight: 300; text-wrap: pretty; }
.muted { color: var(--muted2); }
.eyebrow { font-size: 11px; letter-spacing: 0.22em; text-transform: uppercase; font-weight: 500; }

.section-head { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 32px 48px; align-items: end; margin-bottom: 48px; }
.section-head > p { justify-self: end; max-width: 500px; }

/* ── buttons ── */
.btn {
  display: inline-flex; align-items: center; justify-content: center; gap: 8px;
  padding: 15px 30px; border-radius: 999px; border: 1px solid transparent;
  font-family: var(--body); font-size: 13px; font-weight: 500; letter-spacing: 0.16em; text-transform: uppercase;
  line-height: 1.2; cursor: pointer; text-decoration: none; white-space: nowrap;
  transition: background 0.25s, color 0.25s, border-color 0.25s, transform 0.25s;
}
.btn:disabled { opacity: 0.55; cursor: not-allowed; }
.btn-brand { background: var(--brand); border-color: var(--brand); color: var(--ink); }
.btn-brand:hover { background: var(--brand-hover); border-color: var(--brand-hover); color: var(--ink); }
.btn-outline { border-color: var(--brand); color: var(--brand); background: transparent; }
.btn-outline:hover { background: rgba(62, 198, 216, 0.12); color: var(--brand); }
.btn-ghost-light { border-color: rgba(233, 233, 237, 0.6); color: #e9e9ed; background: transparent; }
.btn-ghost-light:hover { background: #e9e9ed; color: var(--ink); }
.btn-muted { border-color: var(--border); color: var(--text); }
.btn-muted:hover { border-color: var(--brand); color: var(--brand); }
.btn-ink { border-color: var(--ink); color: var(--ink); }
.btn-ink:hover { background: var(--ink); color: #fff; }
.btn-sm { padding: 11px 20px; font-size: 12px; }
.btn-row { display: flex; flex-wrap: wrap; gap: 14px; }

.round-btn {
  width: 46px; height: 46px; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center;
  border: 1px solid currentColor; background: transparent; color: inherit; cursor: pointer; font-size: 18px; transition: all 0.25s;
}
.round-btn.on-white { color: var(--ink); border-color: var(--ink); }
.round-btn.on-white:hover { background: var(--ink); color: var(--brand); }
.round-btn.on-dark { color: var(--brand); border-color: var(--brand); }
.round-btn.on-dark:hover { background: var(--brand); color: var(--ink); }

.link-underline { font-size: 12px; letter-spacing: 0.2em; text-transform: uppercase; color: var(--ink); font-weight: 500; padding-bottom: 5px; border-bottom: 1px solid currentColor; transition: all 0.3s; }
.link-underline:hover { color: var(--teal); }

/* ── reveal on scroll ── */
[data-reveal] {
  opacity: 0;
  transform: var(--from, translate3d(0, 64px, 0));
  transition: opacity 1s var(--ease), transform 1s var(--ease);
}
[data-reveal].is-in { opacity: 1; transform: none; }
@media (prefers-reduced-motion: reduce) {
  [data-reveal] { opacity: 1; transform: none; transition: none; }
  .marquee-track, .reviews-track { animation: none !important; }
}
.no-js [data-reveal] { opacity: 1; transform: none; }

@keyframes marquee { from { transform: translateX(0); } to { transform: translateX(-50%); } }
@keyframes pulse { 0%, 100% { box-shadow: 0 0 0 0 rgba(62, 198, 216, 0.55); } 70% { box-shadow: 0 0 0 22px rgba(62, 198, 216, 0); } }
@keyframes fadeUp { from { opacity: 0; transform: translateY(24px); } to { opacity: 1; transform: none; } }

.progress-bar { position: fixed; left: 0; top: 0; height: 2px; width: 0; background: var(--brand); z-index: 90; pointer-events: none; }

/* ════════════ HEADER ════════════ */
.site-header {
  position: absolute; left: 0; right: 0; top: 0; z-index: 30;
  display: grid; grid-template-columns: 1fr auto 1fr; align-items: center;
  padding: 20px var(--gutter); max-width: 1360px; margin: 0 auto; color: #e9e9ed;
}
.site-header nav { display: flex; gap: 28px; font-size: 13px; letter-spacing: 0.16em; text-transform: uppercase; font-weight: 500; }
.site-header nav a, .header-right a { color: #e9e9ed; }
.site-header nav a:hover, .header-right a:hover, .site-header nav a[aria-current="page"] { color: var(--brand); }
.header-logo img { height: 62px; width: auto; }
.header-right { display: flex; justify-content: flex-end; align-items: center; gap: 16px; font-size: 13px; letter-spacing: 0.16em; text-transform: uppercase; font-weight: 500; }
.burger {
  width: 44px; height: 44px; border: 0; background: var(--brand); display: flex; flex-direction: column;
  align-items: center; justify-content: center; gap: 5px; cursor: pointer; border-radius: var(--radius-sm); transition: background 0.25s;
}
.burger:hover { background: var(--brand-hover); }
.burger span { width: 20px; height: 2px; background: var(--ink); display: block; }

.sticky-header {
  position: fixed; left: 0; right: 0; top: 0; z-index: 65;
  transform: translateY(-110%); transition: transform 0.5s var(--ease);
  background: rgba(255, 255, 255, 0.92); color: var(--ink);
  border-bottom: 1px solid rgba(15, 17, 25, 0.1);
  backdrop-filter: blur(14px); -webkit-backdrop-filter: blur(14px);
  box-shadow: 0 10px 30px rgba(15, 17, 25, 0.12);
}
.sticky-header.is-visible { transform: translateY(0); }
.sticky-inner { display: grid; grid-template-columns: 1fr auto 1fr; align-items: center; padding: 12px var(--gutter); max-width: 1360px; margin: 0 auto; }
.sticky-inner nav { display: flex; gap: 26px; font-size: 12px; letter-spacing: 0.16em; text-transform: uppercase; font-weight: 500; }
.sticky-inner nav a { color: var(--ink); }
.sticky-inner nav a:hover { color: var(--teal); }
.sticky-inner .logo-img { height: 42px; width: auto; }
.sticky-right { display: flex; justify-content: flex-end; align-items: center; gap: 14px; }
.sticky-burger {
  width: 40px; height: 40px; border: 1px solid rgba(15, 17, 25, 0.15); background: transparent; color: var(--ink);
  display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px; cursor: pointer; border-radius: var(--radius-sm);
}
.sticky-burger span { width: 18px; height: 2px; background: currentColor; display: block; }
.btn-reserve { padding: 10px 20px; border-radius: 999px; background: var(--brand); color: var(--ink); font-size: 12px; font-weight: 600; letter-spacing: 0.14em; text-transform: uppercase; }
.btn-reserve:hover { background: var(--brand-hover); color: var(--ink); }

/* full-screen menu */
.menu-overlay {
  position: fixed; inset: 0; z-index: 100; background: var(--ink); color: var(--text);
  display: grid; grid-template-rows: auto 1fr auto; overflow-y: auto;
  opacity: 0; visibility: hidden; transition: opacity 0.45s var(--ease), visibility 0.45s;
}
.menu-overlay.is-open { opacity: 1; visibility: visible; }
.menu-overlay::before {
  content: ""; position: absolute; inset: 0; pointer-events: none;
  background: radial-gradient(60% 50% at 85% 10%, rgba(62, 198, 216, 0.14), transparent 70%), radial-gradient(40% 40% at 10% 90%, rgba(183, 212, 74, 0.08), transparent 70%);
}
.menu-top { position: relative; display: flex; justify-content: space-between; align-items: center; padding: 20px var(--gutter); max-width: 1360px; width: 100%; margin: 0 auto; }
.menu-top img { height: 52px; width: auto; }
.menu-close { width: 48px; height: 48px; border-radius: 50%; border: 1px solid rgba(233, 233, 237, 0.4); background: transparent; color: var(--text); font-size: 26px; cursor: pointer; transition: all 0.25s; }
.menu-close:hover { background: var(--brand); color: var(--ink); border-color: var(--brand); }
.menu-body { position: relative; display: grid; grid-template-columns: minmax(0, 1.4fr) minmax(0, 1fr); gap: 48px; padding: 24px var(--gutter) 48px; max-width: 1360px; width: 100%; margin: 0 auto; align-items: center; }
.menu-links { list-style: none; margin: 0; padding: 0; display: grid; gap: 4px; counter-reset: m; }
.menu-links li { overflow: hidden; }
.menu-links a {
  display: flex; align-items: baseline; gap: 18px; color: var(--text);
  font-family: var(--display); text-transform: uppercase; letter-spacing: 0.06em; font-size: clamp(28px, 4.2vw, 56px); line-height: 1.12;
  transform: translateY(100%); transition: transform 0.7s var(--ease-out), color 0.25s;
}
.menu-overlay.is-open .menu-links a { transform: none; }
.menu-links a::before { counter-increment: m; content: counter(m, decimal-leading-zero); font-family: var(--body); font-size: 12px; letter-spacing: 0.2em; color: var(--lime); }
.menu-links a:hover, .menu-links a[aria-current="page"] { color: var(--brand); }
.menu-aside { display: grid; gap: 28px; align-content: start; font-size: 15px; color: var(--muted); }
.menu-aside h3 { font-size: 11px; letter-spacing: 0.22em; text-transform: uppercase; color: var(--lime); font-weight: 500; margin-bottom: 10px; font-family: var(--body); }
.menu-aside a { color: var(--text); }
.menu-aside a:hover { color: var(--brand); }
.menu-bottom { position: relative; border-top: 1px solid var(--border2); padding: 18px var(--gutter); display: flex; justify-content: space-between; gap: 16px; flex-wrap: wrap; max-width: 1360px; width: 100%; margin: 0 auto; font-size: 13px; color: var(--muted2); }

.socials { display: flex; gap: 10px; flex-wrap: wrap; }
.social-btn {
  width: 44px; height: 44px; border-radius: 50%; border: 1px solid currentColor; display: flex; align-items: center; justify-content: center; font-size: 20px; transition: all 0.25s;
}
.socials.on-dark .social-btn { color: var(--text); border-color: var(--border); }
.socials.on-dark .social-btn:hover { background: var(--brand); color: var(--ink); border-color: var(--brand); }
.socials.on-brand .social-btn { color: var(--ink); border-color: var(--ink); }
.socials.on-brand .social-btn:hover { background: var(--ink); color: var(--brand); }

/* ════════════ HERO (home) ════════════ */
.hero { position: relative; min-height: 92vh; min-height: 92svh; display: flex; flex-direction: column; overflow: hidden; color: #e9e9ed; background: var(--ink); }
.hero-media { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; object-position: center 55%; }
.hero-shade { position: absolute; inset: 0; background: linear-gradient(180deg, rgba(15,17,25,0.72) 0%, rgba(15,17,25,0.28) 35%, rgba(15,17,25,0.55) 75%, rgba(15,17,25,0.85) 100%); }
.hero-body { position: relative; z-index: 2; flex: 1; display: flex; align-items: flex-end; padding-top: 140px; padding-bottom: 72px; }
.hero-grid { display: grid; grid-template-columns: minmax(0, 1.3fr) minmax(0, 1fr); gap: 48px; width: 100%; align-items: end; }
.hero h1 { animation: fadeUp 1.1s var(--ease) both; }
.hero-sub { margin: 22px 0 0; max-width: 520px; font-size: 18px; line-height: 1.5; color: var(--muted); font-weight: 300; animation: fadeUp 1.1s 0.15s var(--ease) both; }
.hero .btn-row { margin-top: 32px; animation: fadeUp 1.1s 0.3s var(--ease) both; }
.hero-address { justify-self: end; text-align: right; font-size: 12px; letter-spacing: 0.22em; text-transform: uppercase; line-height: 1.9; color: var(--muted); }

/* page hero (inner pages) */
.page-hero { position: relative; min-height: 62vh; min-height: 62svh; display: flex; align-items: flex-end; overflow: hidden; color: #e9e9ed; background: var(--ink); }
.page-hero.compact { min-height: 46vh; min-height: 46svh; }
.page-hero .hero-shade { background: linear-gradient(180deg, rgba(15,17,25,0.78) 0%, rgba(15,17,25,0.35) 40%, rgba(15,17,25,0.92) 100%); }
.page-hero-body { position: relative; z-index: 2; width: 100%; padding-top: 150px; padding-bottom: 64px; }
.page-hero h1 { animation: fadeUp 1s var(--ease) both; }
.page-hero .lead { max-width: 620px; margin-top: 20px; animation: fadeUp 1s 0.12s var(--ease) both; }
.breadcrumbs { display: flex; flex-wrap: wrap; gap: 8px; list-style: none; margin: 0 0 18px; padding: 0; font-size: 11px; letter-spacing: 0.22em; text-transform: uppercase; color: var(--muted2); }
.breadcrumbs a { color: var(--muted); }
.breadcrumbs a:hover { color: var(--brand); }
.breadcrumbs li + li::before { content: "/"; margin-right: 8px; opacity: 0.5; }

/* ════════════ EVENTS (home slider, white) ════════════ */
.events-home { background: #fff; color: var(--ink); padding: 96px 0 104px; }
.events-head { display: flex; flex-wrap: wrap; align-items: flex-end; justify-content: space-between; gap: 20px; margin-bottom: 40px; }
.events-home .events-head h2 { color: var(--ink); }
.events-nav { display: flex; gap: 14px; }
.events-track {
  display: grid; grid-auto-flow: column; grid-auto-columns: minmax(280px, 340px); gap: 40px;
  overflow-x: auto; scroll-snap-type: x mandatory; scrollbar-width: none; padding: 4px 0 12px;
}
.events-track::-webkit-scrollbar { display: none; }
.event-card { scroll-snap-align: start; display: flex; flex-direction: column; color: var(--ink); }
.event-card-media { aspect-ratio: 4 / 5; overflow: hidden; position: relative; background: #eef1f3; display: block; }
.event-card-media img { transition: transform 1s var(--ease-out); }
.event-card:hover .event-card-media img { transform: scale(1.04); }
.event-card-meta { display: flex; justify-content: space-between; align-items: baseline; gap: 12px; margin-top: 22px; padding-bottom: 14px; border-bottom: 1px solid #d8dfe2; font-size: 11px; letter-spacing: 0.24em; text-transform: uppercase; color: #6f8289; }
.event-card-meta .tag { color: var(--teal); }
.event-card h3 { margin: 18px 0 8px; font-size: clamp(22px, 2vw, 28px); line-height: 1.15; color: var(--ink); }
.event-card h3 a { color: inherit; }
.event-card h3 a:hover { color: var(--teal); }
.event-card .where { font-size: 14px; color: #6f8289; }
.event-card .link-underline { margin-top: 22px; align-self: flex-start; }
.event-badge { position: absolute; left: 14px; top: 14px; display: flex; flex-direction: column; align-items: center; background: var(--paper); color: var(--ink); border-radius: 10px; padding: 8px 12px; line-height: 1; z-index: 1; }
.event-badge b { font-family: var(--display); font-weight: 400; font-size: 24px; }
.event-badge span { font-size: 10px; letter-spacing: 0.2em; text-transform: uppercase; margin-top: 4px; font-weight: 600; }
.past-flag { position: absolute; right: 14px; top: 14px; z-index: 1; background: var(--ink); color: var(--muted); padding: 6px 10px; font-size: 10px; letter-spacing: 0.2em; text-transform: uppercase; border-radius: 999px; }
.center-row { display: flex; justify-content: center; margin-top: 48px; }

/* ════════════ STORY TIMELINE ════════════ */
.story { padding: 120px 0 110px; background: var(--bg); overflow: hidden; }
.story-head { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 48px; align-items: end; margin-bottom: 64px; }
.story-head .lead { justify-self: end; max-width: 520px; }
.timeline { position: relative; display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 28px; }
.timeline::before { content: ""; position: absolute; left: 0; right: 0; top: 7px; height: 1px; background: linear-gradient(90deg, transparent, var(--border) 10%, var(--border) 90%, transparent); }
.timeline-dot { display: block; width: 15px; height: 15px; border-radius: 50%; background: var(--brand); box-shadow: 0 0 0 5px var(--bg); margin-bottom: 22px; position: relative; }
.timeline-year { display: block; font-family: var(--display); font-size: clamp(34px, 3.6vw, 52px); line-height: 1.08; color: var(--brand); margin-bottom: 14px; }
.timeline-img { aspect-ratio: 4 / 3; border-radius: var(--radius-md); overflow: hidden; margin-bottom: 16px; position: relative; }
.timeline h3 { font-size: 18px; margin-bottom: 8px; color: var(--text); }
.timeline p { font-size: 15px; line-height: 1.55; color: var(--muted); font-weight: 300; }
.fan { position: relative; display: flex; justify-content: center; align-items: center; margin-top: 110px; padding: 0 var(--gutter); }
.fan-item { margin: 0 -2.2%; }
.fan-card { aspect-ratio: 3 / 4; border-radius: 8px; overflow: hidden; border: 4px solid var(--brand); box-shadow: var(--img-shadow); background: var(--surface); transition: transform 0.4s; position: relative; }
.fan-card:hover { transform: rotate(0deg) scale(1.03) !important; }

/* ════════════ ACTIVITIES ════════════ */
.activities { background: var(--bg2); padding: 110px 0 0; overflow: hidden; border-top: 1px solid var(--border2); }
.activities-grid { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1.2fr); gap: 48px; align-items: center; }
.activities h2 { color: var(--brand); margin-bottom: 28px; }
.polaroids { position: relative; height: clamp(440px, 46vw, 620px); }
.polaroid-wrap { position: absolute; width: clamp(140px, 16vw, 220px); }
.polaroid { background: var(--paper); padding: 10px 10px 14px; border-radius: 4px; box-shadow: var(--img-shadow); transition: transform 0.35s var(--ease-out); }
.polaroid:hover { transform: rotate(0deg) scale(1.05) !important; }
.polaroid-img { aspect-ratio: 1; overflow: hidden; background: var(--ink); position: relative; }
.polaroid-cap { display: flex; align-items: center; justify-content: space-between; gap: 8px; margin-top: 12px; color: var(--ink); }
.polaroid-cap span { font-family: var(--display); text-transform: uppercase; letter-spacing: 0.06em; font-size: clamp(13px, 1.3vw, 17px); line-height: 1.1; }
.polaroid-cap svg { color: var(--teal); flex: none; }
.marquee { margin-top: 90px; border-top: 1px solid var(--border); border-bottom: 1px solid var(--border); padding: 26px 0; overflow: hidden; white-space: nowrap; }
.marquee-track { display: inline-flex; align-items: center; gap: 56px; animation: marquee 40s linear infinite; font-family: var(--display); text-transform: uppercase; font-size: clamp(22px, 2.6vw, 38px); letter-spacing: 0.18em; line-height: 1; color: var(--title); }
.marquee-dot { width: 6px; height: 6px; border-radius: 50%; background: var(--brand); display: inline-block; }

/* ════════════ DISCOVER VIDEO ════════════ */
.discover { position: relative; height: clamp(420px, 56vw, 720px); overflow: hidden; background: var(--ink); }
.discover-bg { position: absolute; inset: -4%; width: 108%; height: 108%; object-fit: cover; filter: blur(14px) saturate(1.1); transform: scale(1.05); }
.discover-shade { position: absolute; inset: 0; background: rgba(15, 17, 25, 0.45); }
.discover-center { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 26px; }
.discover-center img { height: 54px; width: auto; }
.play-btn { width: 96px; height: 96px; border-radius: 50%; border: 0; background: var(--brand); display: flex; align-items: center; justify-content: center; cursor: pointer; animation: pulse 2.4s ease-out infinite; transition: transform 0.3s; }
.play-btn:hover { transform: scale(1.08); }
.play-btn span { display: block; width: 0; height: 0; border-left: 26px solid var(--ink); border-top: 16px solid transparent; border-bottom: 16px solid transparent; margin-left: 6px; }
.discover-label { font-size: 13px; letter-spacing: 0.3em; text-transform: uppercase; color: #e9e9ed; font-weight: 500; }
.discover video, .discover iframe { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; background: var(--ink); border: 0; }
.video-close { position: absolute; right: 24px; top: 24px; width: 44px; height: 44px; border-radius: 50%; border: 1px solid rgba(233, 233, 237, 0.5); background: rgba(15, 17, 25, 0.6); color: #e9e9ed; cursor: pointer; font-size: 20px; z-index: 2; }

/* ════════════ CHEFS ════════════ */
.chefs { background: var(--bg); padding: 120px 0; overflow: hidden; }
.chefs-grid { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 72px; align-items: center; }
.chefs-media { position: relative; min-height: 520px; }
.chefs-img1 { position: absolute; left: 0; top: 0; width: 72%; }
.chefs-img2 { position: absolute; right: 0; bottom: 0; width: 48%; }
.img-frame { border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--img-shadow); position: relative; }
.chefs-badge-wrap { position: absolute; left: 58%; top: 6%; }
.chefs-badge { width: 112px; height: 112px; border-radius: 50%; background: var(--lime); color: var(--ink); display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; font-size: 10px; letter-spacing: 0.18em; text-transform: uppercase; font-weight: 600; line-height: 1.4; transform: rotate(-10deg); box-shadow: var(--img-shadow); }
.chefs-badge b { font-family: var(--display); font-weight: 400; font-size: 28px; letter-spacing: 0; line-height: 1; }
.chefs blockquote { margin: 0 0 32px; padding-left: 20px; border-left: 2px solid var(--brand); font-family: var(--display); text-transform: uppercase; letter-spacing: 0.04em; font-size: 20px; line-height: 1.4; color: var(--text); }

/* ════════════ HOME MENU ════════════ */
.menu-home-grid { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1.3fr); gap: 64px; align-items: start; }
.menu-home-intro { position: sticky; top: 90px; }
.pill-tabs { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 32px; }
.pill { padding: 9px 16px; border-radius: 999px; border: 1px solid var(--border); background: transparent; color: var(--muted); font-size: 12px; font-weight: 500; letter-spacing: 0.14em; text-transform: uppercase; cursor: pointer; transition: all 0.25s; white-space: nowrap; }
.pill:hover { border-color: var(--brand); color: var(--brand); }
.pill.is-active { background: var(--brand); border-color: var(--brand); color: var(--ink); }
.dish { display: grid; grid-template-columns: 1fr auto; gap: 24px; padding: 24px 12px; border-bottom: 1px solid var(--border); align-items: baseline; cursor: default; transition: background 0.25s, padding 0.25s; border-radius: var(--radius-sm); }
.dish:hover { background: var(--surface); padding-left: 20px; }
.dish h3 { font-family: var(--display); text-transform: uppercase; letter-spacing: 0.06em; font-size: 20px; margin: 0 0 6px; color: var(--text); font-weight: 400; }
.dish p { font-size: 15px; line-height: 1.5; color: var(--muted2); font-weight: 300; }
.dish-price { font-size: 18px; color: var(--brand); white-space: nowrap; font-weight: 500; }
.hover-image {
  position: fixed; left: 0; top: 0; width: 250px; aspect-ratio: 4 / 5; border-radius: var(--radius-lg); overflow: hidden; pointer-events: none;
  opacity: 0; transform: translate(-50%, -56%) rotate(-7deg) scale(0.88); transition: opacity 0.22s ease, transform 0.35s var(--ease-out);
  z-index: 60; border: 2px solid var(--brand); box-shadow: 0 24px 60px rgba(0, 0, 0, 0.45); background: var(--ink);
}
.hover-image.is-on { opacity: 1; transform: translate(-50%, -56%) rotate(-4deg) scale(1); }
.hover-image img { width: 100%; height: 100%; object-fit: cover; }

/* ════════════ NEWS ════════════ */
.news-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 300px), 1fr)); gap: 28px; }
.news-grid > :only-child { max-width: 440px; }
.news-card { position: relative; aspect-ratio: 3 / 4; border-radius: var(--radius-md); overflow: hidden; background: var(--surface); display: flex; flex-direction: column; justify-content: flex-end; padding: 28px; color: #e9e9ed; }
.news-card > img { transition: transform 0.7s var(--ease-out); }
.news-card:hover > img { transform: scale(1.05); }
.news-card-shade { position: absolute; inset: 0; background: linear-gradient(180deg, rgba(15,17,25,0.1) 30%, rgba(15,17,25,0.88) 100%); }
.news-kicker { position: absolute; left: 20px; top: 20px; padding: 9px 14px; background: var(--ink); color: #e9e9ed; font-size: 11px; letter-spacing: 0.22em; text-transform: uppercase; font-weight: 500; z-index: 1; }
.news-card h3 { position: relative; margin: 0 0 10px; font-size: clamp(24px, 2.4vw, 34px); line-height: 1.1; }
.news-card p { position: relative; margin: 0 0 20px; font-size: 15px; line-height: 1.5; color: var(--muted); }
.news-card .btn { position: relative; align-self: flex-start; }
.news-card .stretched::after { content: ""; position: absolute; inset: 0; z-index: 1; }

/* ════════════ REVIEWS ════════════ */
.reviews { overflow: hidden; }
.reviews-rows { display: flex; flex-direction: column; gap: 24px; -webkit-mask-image: linear-gradient(90deg, transparent, #000 8%, #000 92%, transparent); mask-image: linear-gradient(90deg, transparent, #000 8%, #000 92%, transparent); }
.reviews-row { overflow: hidden; }
.reviews-track { display: flex; gap: 24px; width: max-content; animation: marquee 55s linear infinite; }
.reviews-track.reverse { animation-duration: 62s; animation-direction: reverse; }
.reviews-track:hover { animation-play-state: paused; }
.review { width: 380px; padding: 28px; background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-md); display: flex; flex-direction: column; gap: 16px; }
.stars { color: var(--lime); letter-spacing: 2px; font-size: 14px; }
.review blockquote { font-size: 16px; line-height: 1.6; color: var(--text); font-weight: 300; text-wrap: pretty; }
.review figcaption { margin-top: auto; display: flex; align-items: center; gap: 12px; }
.avatar { width: 38px; height: 38px; border-radius: 50%; background: var(--brand); color: var(--ink); display: flex; align-items: center; justify-content: center; font-size: 14px; font-weight: 600; flex: none; }
.review-name { font-size: 14px; font-weight: 500; }
.review-meta { font-size: 12px; color: var(--muted2); }
.rating-line { display: flex; align-items: center; gap: 12px; font-size: 15px; color: var(--muted); }

/* ════════════ GALLERY GRID (home) ════════════ */
.gallery-home { background: var(--bg); padding: 110px 0 120px; overflow: hidden; }
.gallery-grid-home { position: relative; width: 124%; margin-left: -12%; display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); grid-auto-rows: clamp(140px, 17vw, 300px); gap: clamp(12px, 1.6vw, 28px); margin-top: 20px; }
.gallery-tile { border-radius: var(--radius-lg); overflow: hidden; position: relative; width: 100%; height: 100%; }
.gallery-tile img { transition: transform 0.7s var(--ease-out); }
.gallery-tile:hover img { transform: scale(1.06); }
.gallery-center { grid-column: 2 / 5; grid-row: 2; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; gap: 28px; padding: 0 24px; }

/* ════════════ CONTACT BLOCK ════════════ */
.contact-band { position: relative; padding: 100px 0; overflow: hidden; }
.contact-band .bg { position: absolute; inset: 0; }
.contact-band .shade { position: absolute; inset: 0; background: var(--overlay); }
.contact-band .inner { position: relative; max-width: 1000px; margin: 0 auto; padding: 0 var(--gutter); color: #e9e9ed; }
.contact-band h2 { text-align: center; margin-bottom: 40px; font-size: clamp(28px, 3.6vw, 44px); color: var(--brand); }

/* ── forms ── */
.form-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 20px 28px; }
.form-grid .full { grid-column: 1 / -1; }
.field { display: flex; flex-direction: column; gap: 8px; font-size: 12px; letter-spacing: 0.16em; text-transform: uppercase; font-weight: 500; color: #e9e9ed; }
.field .opt { color: var(--muted2); letter-spacing: 0.08em; text-transform: none; font-weight: 400; margin-left: 4px; }
.field-label { display: block; }
.input {
  width: 100%; padding: 14px; border-radius: var(--radius-md); border: 1px solid rgba(233, 233, 237, 0.25);
  background: rgba(15, 17, 25, 0.55); color: #e9e9ed; font-size: 15px; font-family: var(--body); letter-spacing: 0; text-transform: none; font-weight: 400;
  transition: border-color 0.2s, background 0.2s;
}
.input:hover { border-color: rgba(233, 233, 237, 0.5); }
.input:focus { border-color: var(--brand); outline: none; background: rgba(15, 17, 25, 0.75); }
.input::placeholder { color: var(--muted2); }
textarea.input { resize: vertical; min-height: 130px; }
select.input { appearance: none; background-image: linear-gradient(45deg, transparent 50%, var(--brand) 50%), linear-gradient(135deg, var(--brand) 50%, transparent 50%); background-position: calc(100% - 20px) 50%, calc(100% - 14px) 50%; background-size: 6px 6px; background-repeat: no-repeat; padding-right: 40px; }
input[type="date"].input, input[type="time"].input { color-scheme: dark; }
.check { display: flex; gap: 12px; align-items: flex-start; font-size: 14px; letter-spacing: 0; text-transform: none; font-weight: 300; color: var(--muted); cursor: pointer; }
.check input { margin-top: 3px; width: 18px; height: 18px; accent-color: var(--brand); flex: none; }
.hp { position: absolute; left: -9999px; width: 1px; height: 1px; overflow: hidden; }
.form-note { font-size: 13px; color: var(--muted2); }
.form-alert { padding: 16px 18px; border-radius: var(--radius-md); font-size: 15px; line-height: 1.5; }
.form-alert.ok { background: rgba(183, 212, 74, 0.14); border: 1px solid rgba(183, 212, 74, 0.5); color: #e5f2b8; }
.form-alert.err { background: rgba(240, 98, 98, 0.12); border: 1px solid rgba(240, 98, 98, 0.45); color: #ffc9c9; }
.form-card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg); padding: clamp(24px, 4vw, 44px); }

/* ════════════ FOOTER ════════════ */
.footer-main { background: var(--brand); color: var(--ink); }
.footer-grid { padding-top: 80px; padding-bottom: 72px; display: grid; grid-template-columns: 1.1fr repeat(3, minmax(0, 1fr)) 1.3fr; gap: 40px; align-items: start; }
.footer-grid img { height: 60px; width: auto; opacity: 0.9; }
.footer-grid nav { display: flex; flex-direction: column; gap: 12px; font-size: 15px; }
.footer-grid a { color: var(--ink); }
.footer-grid a:hover { color: var(--ink); text-decoration: underline; text-underline-offset: 4px; }
.footer-contact { display: flex; flex-direction: column; gap: 12px; font-size: 15px; }
.footer-contact small { font-size: 13px; color: rgba(15, 17, 25, 0.65); }
.footer-bar { background: var(--lime); color: var(--ink); text-align: center; padding: 18px var(--gutter); font-size: 13px; letter-spacing: 0.04em; }
.footer-bar a { color: var(--ink); }
.footer-bar a:hover { text-decoration: underline; }
.footer-tagline { margin-top: 18px; font-size: 14px; max-width: 220px; color: rgba(15, 17, 25, 0.75); }

/* ════════════ INNER PAGES ════════════ */
.filter-bar { display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 16px 24px; margin-bottom: 44px; }
.filter-bar .group { display: flex; gap: 8px; flex-wrap: wrap; align-items: center; }
.events-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 280px), 1fr)); gap: 48px 32px; }
.events-page { background: #fff; color: var(--ink); }
.events-page .pill { border-color: #d8dfe2; color: #45585f; }
.events-page .pill:hover { border-color: var(--teal); color: var(--teal); }
.events-page .pill.is-active { background: var(--ink); border-color: var(--ink); color: var(--brand); }
.empty-state { text-align: center; padding: 64px 24px; border: 1px dashed currentColor; border-radius: var(--radius-lg); opacity: 0.85; }
.empty-state h2 { font-size: 26px; margin-bottom: 12px; }

/* event detail */
.event-detail-grid { display: grid; grid-template-columns: minmax(0, 1.25fr) minmax(0, 1fr); gap: 64px; align-items: start; }
.event-facts { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 16px; padding: 24px 0; border-top: 1px solid var(--border); border-bottom: 1px solid var(--border); margin: 32px 0; }
.event-facts dt { font-size: 11px; letter-spacing: 0.2em; text-transform: uppercase; color: var(--muted2); margin-bottom: 6px; }
.event-facts dd { margin: 0; font-family: var(--display); text-transform: uppercase; letter-spacing: 0.04em; font-size: 19px; color: var(--text); }
.booking-panel { position: sticky; top: 90px; }
.booking-panel h2 { font-size: 26px; margin-bottom: 6px; color: var(--brand); }
.spots { display: inline-flex; gap: 8px; align-items: center; font-size: 12px; letter-spacing: 0.16em; text-transform: uppercase; color: var(--lime); margin-bottom: 20px; }
.spots::before { content: ""; width: 8px; height: 8px; border-radius: 50%; background: var(--lime); }

/* calendar */
.cal-head { display: flex; align-items: center; justify-content: space-between; gap: 16px; margin-bottom: 28px; flex-wrap: wrap; }
.cal-head h2 { font-size: clamp(28px, 3vw, 40px); color: var(--title); }
.calendar { display: grid; grid-template-columns: repeat(7, minmax(0, 1fr)); border-top: 1px solid var(--border); border-left: 1px solid var(--border); }
.cal-dow { padding: 12px 10px; font-size: 11px; letter-spacing: 0.2em; text-transform: uppercase; color: var(--muted2); border-right: 1px solid var(--border); border-bottom: 1px solid var(--border); background: var(--bg2); }
.cal-day { min-height: 128px; padding: 10px; border-right: 1px solid var(--border); border-bottom: 1px solid var(--border); display: flex; flex-direction: column; gap: 6px; }
.cal-day.out { background: rgba(255, 255, 255, 0.015); color: var(--muted2); }
.cal-day.today { box-shadow: inset 0 0 0 2px var(--brand); }
.cal-num { font-family: var(--display); font-size: 20px; }
.cal-event { display: block; padding: 6px 8px; border-radius: 6px; background: rgba(62, 198, 216, 0.14); border-left: 3px solid var(--brand); color: var(--text); font-size: 12px; line-height: 1.3; }
.cal-event:hover { background: var(--brand); color: var(--ink); }
.cal-event time { display: block; font-size: 10px; letter-spacing: 0.14em; color: var(--lime); }
.cal-event:hover time { color: var(--ink); }
.cal-list { display: none; }

/* full menu page */
.menu-page-nav { position: sticky; top: 66px; z-index: 20; background: rgba(15, 17, 25, 0.92); backdrop-filter: blur(12px); -webkit-backdrop-filter: blur(12px); border-bottom: 1px solid var(--border2); }
.menu-page-nav .row { display: flex; gap: 8px; overflow-x: auto; padding: 14px var(--gutter); scrollbar-width: none; max-width: 1360px; margin: 0 auto; }
.menu-page-nav .row::-webkit-scrollbar { display: none; }
.menu-section { padding: 72px 0 24px; scroll-margin-top: 140px; }
.menu-section > .container > h2 { margin-bottom: 8px; }
.menu-cat { margin-top: 48px; scroll-margin-top: 140px; }
.menu-cat h3 { font-family: var(--display); text-transform: uppercase; letter-spacing: 0.08em; font-size: 22px; color: var(--brand); padding-bottom: 14px; border-bottom: 1px solid var(--border); margin-bottom: 4px; font-weight: 400; }
.menu-items { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); column-gap: 56px; }
.menu-item { display: grid; grid-template-columns: 1fr auto; gap: 6px 20px; padding: 20px 4px; border-bottom: 1px solid var(--border2); align-items: baseline; }
.menu-item.has-img { grid-template-columns: 64px 1fr auto; align-items: start; }
.menu-item-thumb { width: 64px; height: 64px; border-radius: 10px; overflow: hidden; position: relative; grid-row: span 2; }
.menu-item h4 { font-family: var(--display); text-transform: uppercase; letter-spacing: 0.05em; font-size: 17px; font-weight: 400; color: var(--text); margin: 0; }
.menu-item .price { color: var(--brand); font-weight: 500; white-space: nowrap; }
.menu-item p { grid-column: 1 / -1; font-size: 14px; line-height: 1.55; color: var(--muted2); font-weight: 300; white-space: pre-line; }
.menu-item.has-img p { grid-column: 2 / -1; }
.menu-tags { grid-column: 1 / -1; display: flex; flex-wrap: wrap; gap: 6px; }
.menu-item.has-img .menu-tags { grid-column: 2 / -1; }
.chip { font-size: 10px; letter-spacing: 0.14em; text-transform: uppercase; padding: 3px 8px; border-radius: 999px; border: 1px solid var(--border); color: var(--muted2); }
.chip.green { border-color: rgba(183, 212, 74, 0.6); color: var(--lime); }
.allergen-note { margin-top: 64px; padding: 24px; border: 1px solid var(--border); border-radius: var(--radius-md); font-size: 14px; color: var(--muted2); }

/* story page */
.chapter { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 72px; align-items: center; padding: 64px 0; }
.chapter:nth-child(even) .chapter-media { order: 2; }
.stats { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 24px; padding: 40px 0; border-top: 1px solid var(--border); border-bottom: 1px solid var(--border); }
.stat b { display: block; font-family: var(--display); font-weight: 400; font-size: clamp(40px, 4.6vw, 64px); line-height: 1; color: var(--brand); }
.stat span { display: block; margin-top: 10px; font-size: 12px; letter-spacing: 0.18em; text-transform: uppercase; color: var(--muted2); }
.big-quote { font-family: var(--display); text-transform: uppercase; letter-spacing: 0.04em; font-size: clamp(26px, 3.4vw, 48px); line-height: 1.2; color: var(--title); text-align: center; max-width: 1000px; margin: 0 auto; text-wrap: balance; }

/* gallery page (masonry) */
.masonry { columns: 4 260px; column-gap: 20px; }
.masonry-item { break-inside: avoid; margin-bottom: 20px; border-radius: var(--radius-md); overflow: hidden; position: relative; display: block; cursor: zoom-in; background: var(--surface); border: 0; padding: 0; width: 100%; }
.masonry-item img { width: 100%; height: auto; transition: transform 0.7s var(--ease-out); }
.masonry-item:hover img { transform: scale(1.04); }
.lightbox { position: fixed; inset: 0; z-index: 120; background: rgba(8, 9, 14, 0.95); display: flex; align-items: center; justify-content: center; padding: 64px 72px; }
.lightbox img { max-width: 100%; max-height: 100%; object-fit: contain; border-radius: var(--radius-md); }
.lightbox .lb-btn { position: absolute; top: 50%; transform: translateY(-50%); }
.lightbox .lb-prev { left: 16px; }
.lightbox .lb-next { right: 16px; }
.lightbox .lb-close { position: absolute; top: 16px; right: 16px; }
.lightbox .lb-cap { position: absolute; bottom: 18px; left: 0; right: 0; text-align: center; color: var(--muted); font-size: 14px; }

/* article / rich text */
.prose { font-size: 17px; line-height: 1.75; color: var(--muted); font-weight: 300; }
.prose > * + * { margin-top: 1.1em; }
.prose h2 { font-family: var(--display); text-transform: uppercase; letter-spacing: 0.06em; font-weight: 400; font-size: 24px; color: var(--title); margin-top: 1.8em; line-height: 1.2; }
.prose h3 { font-family: var(--display); text-transform: uppercase; letter-spacing: 0.06em; font-weight: 400; font-size: 19px; color: var(--text); margin-top: 1.5em; }
.prose ul { padding-left: 1.2em; }
.prose li + li { margin-top: 0.4em; }
.prose li::marker { color: var(--brand); }
.prose strong { color: var(--text); font-weight: 500; }
.prose a { text-decoration: underline; text-underline-offset: 3px; }
.article-cover { aspect-ratio: 16 / 9; border-radius: var(--radius-lg); overflow: hidden; position: relative; margin: -120px 0 56px; box-shadow: var(--img-shadow); z-index: 3; }

/* contact page */
.contact-grid { display: grid; grid-template-columns: minmax(0, 0.9fr) minmax(0, 1.1fr); gap: 64px; align-items: start; }
.info-list { display: grid; gap: 28px; }
.info-item h3 { font-size: 11px; letter-spacing: 0.22em; text-transform: uppercase; color: var(--lime); font-weight: 500; margin-bottom: 8px; font-family: var(--body); }
.info-item p, .info-item a { font-size: 17px; color: var(--text); font-weight: 300; }
.info-item a:hover { color: var(--brand); }
.hours-table { width: 100%; border-collapse: collapse; font-size: 15px; }
.hours-table td { padding: 8px 0; border-bottom: 1px solid var(--border2); font-weight: 300; }
.hours-table td:last-child { text-align: right; color: var(--text); }
.hours-table tr.is-today td { color: var(--brand); font-weight: 500; }
.map-frame { width: 100%; aspect-ratio: 16 / 7; border: 0; border-radius: var(--radius-lg); filter: grayscale(0.35) contrast(1.05); display: block; }

.cards-2 { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 24px; }
.text-card { padding: 32px; border: 1px solid var(--border); border-radius: var(--radius-lg); background: var(--surface); }
.text-card h3 { font-family: var(--display); text-transform: uppercase; letter-spacing: 0.06em; font-weight: 400; font-size: 22px; color: var(--text); margin-bottom: 10px; }
.text-card p { color: var(--muted); font-weight: 300; }

/* 404 */
.notfound { min-height: 100vh; display: flex; align-items: center; justify-content: center; text-align: center; padding: 120px var(--gutter); }

/* ── image helper ── */
.cover { object-fit: cover; }
.fill-img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }

/* ════════════ RESPONSIVE ════════════ */
@media (max-width: 1100px) {
  .footer-grid { grid-template-columns: repeat(3, minmax(0, 1fr)); }
  .footer-grid > :first-child { grid-column: 1 / -1; }
  .menu-items { grid-template-columns: 1fr; }
}

@media (max-width: 900px) {
  :root { --gutter: 20px; }
  .section, .story, .chefs { padding: 80px 0; }
  .activities { padding-top: 80px; }
  .events-home { padding: 72px 0 80px; }
  .gallery-home { padding: 80px 0; }

  .site-header { grid-template-columns: auto 1fr; padding: 16px var(--gutter); }
  .site-header nav, .header-right .hide-sm, .sticky-inner nav { display: none; }
  .header-logo img { height: 46px; }
  .sticky-inner { grid-template-columns: auto 1fr; padding: 10px var(--gutter); }
  .sticky-inner .logo-img { height: 34px; }

  .hero-grid, .story-head, .section-head, .activities-grid, .chefs-grid, .menu-home-grid,
  .event-detail-grid, .contact-grid, .chapter, .menu-body { grid-template-columns: 1fr; }
  .hero-address { justify-self: start; text-align: left; }
  .story-head .lead, .section-head > p { justify-self: start; }
  .timeline { grid-template-columns: repeat(2, minmax(0, 1fr)); row-gap: 48px; }
  .timeline::before { display: none; }
  .fan { margin-top: 64px; }
  .fan-item { margin: 0 -4%; }

  .polaroids { height: auto; display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 24px 16px; padding: 12px 4px; }
  .polaroid-wrap { position: static; width: auto; }
  .polaroid-wrap:last-child:nth-child(odd) { grid-column: 1 / -1; justify-self: center; width: 60%; }

  .chefs-media { min-height: 0; aspect-ratio: 1 / 1.05; }
  .menu-home-intro { position: static; }
  .gallery-grid-home { width: 100%; margin-left: 0; grid-template-columns: repeat(3, minmax(0, 1fr)); grid-auto-rows: 34vw; }
  .gallery-grid-home .gallery-tile-wrap { grid-column: auto !important; grid-row: auto !important; }
  .gallery-grid-home .gallery-tile-wrap:nth-child(n + 10) { display: none; }
  .gallery-center { grid-column: 1 / -1; grid-row: auto; padding: 32px 0; order: -1; }
  .booking-panel { position: static; }
  .chapter:nth-child(even) .chapter-media { order: 0; }
  .chapter { gap: 32px; padding: 40px 0; }
  .stats { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .menu-page-nav { top: 56px; }
  .hover-image { display: none; }
  .review { width: 300px; }
  .menu-aside { order: 2; }
  .cards-2 { grid-template-columns: 1fr; }

  .calendar { display: none; }
  .cal-list { display: grid; gap: 12px; }
}

@media (max-width: 600px) {
  .form-grid { grid-template-columns: 1fr; }
  .timeline { grid-template-columns: 1fr; }
  .event-facts { grid-template-columns: 1fr 1fr; }
  .footer-grid { grid-template-columns: 1fr 1fr; padding-top: 56px; padding-bottom: 48px; }
  .btn { padding: 14px 24px; }
  .hero-body { padding-bottom: 48px; }
  .events-track { gap: 24px; grid-auto-columns: 78vw; }
  .lightbox { padding: 64px 12px; }
  .lightbox .lb-btn { top: auto; bottom: 16px; transform: none; }
  .article-cover { margin-top: -60px; }
}

/* ════════════ UPDATE 2 — event photos, smaller story fan, news carousel ════════════ */

/* story: fanned photos — smaller & centred */
.fan { max-width: 1040px; margin: 96px auto 0; }
@media (max-width: 900px) { .fan { max-width: 640px; margin-top: 56px; } }

/* event page: photo mosaic under the description */
.event-photos-wrap { margin-top: 48px; padding-top: 36px; border-top: 1px solid var(--border); }
.event-photos { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); grid-auto-rows: minmax(0, 1fr); gap: 12px; aspect-ratio: 16 / 10; }
.event-photo { position: relative; display: block; padding: 0; border: 0; border-radius: var(--radius-md); overflow: hidden; background: var(--surface); cursor: zoom-in; box-shadow: var(--img-shadow); }
.event-photo img { transition: transform 0.7s var(--ease-out); }
.event-photo:hover img { transform: scale(1.05); }
.event-photo:focus-visible { outline: 2px solid var(--brand); outline-offset: 3px; }
.event-photo:first-child { grid-column: span 2; grid-row: span 2; }
.event-photos.count-1 { grid-template-columns: 1fr; aspect-ratio: 4 / 3; }
.event-photos.count-1 .event-photo:first-child { grid-column: auto; grid-row: auto; }
.event-photos.count-2 { grid-template-columns: repeat(2, minmax(0, 1fr)); aspect-ratio: 16 / 9; }
.event-photos.count-2 .event-photo:first-child { grid-column: auto; grid-row: auto; }
.event-photos.count-3 { grid-template-columns: repeat(3, minmax(0, 1fr)); }
.event-photos.count-3 .event-photo:first-child { grid-column: span 2; grid-row: span 2; }
.event-photos.count-4 .event-photo:nth-child(4) { grid-column: span 2; }
.event-photo-more { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; background: rgba(15, 17, 25, 0.62); color: #fff; font-family: var(--display); font-size: 30px; letter-spacing: 0.04em; }
@media (max-width: 600px) {
  .event-photos, .event-photos.count-3 { grid-template-columns: repeat(2, minmax(0, 1fr)); grid-auto-rows: 34vw; aspect-ratio: auto; gap: 8px; }
  .event-photos .event-photo:first-child { grid-column: 1 / -1; grid-row: span 2; }
  .event-photos.count-4 .event-photo:nth-child(4) { grid-column: 1 / -1; }
  .event-photos.count-1, .event-photos.count-2 { grid-auto-rows: auto; aspect-ratio: auto; }
  .event-photos.count-1 .event-photo, .event-photos.count-2 .event-photo { grid-column: 1 / -1; grid-row: auto; aspect-ratio: 4 / 3; }
}

/* home: news — grid on desktop, swipe carousel on tablet & phone */
.news-dots { display: none; }
@media (max-width: 900px) {
  .news-track {
    display: flex; gap: 16px; overflow-x: auto; overscroll-behavior-x: contain;
    scroll-snap-type: x mandatory; scroll-padding: 0 var(--gutter); scrollbar-width: none;
    margin: 0 calc(var(--gutter) * -1); padding: 4px var(--gutter) 8px;
  }
  .news-track::-webkit-scrollbar { display: none; }
  .news-track > .news-slide { flex: 0 0 min(62%, 400px); scroll-snap-align: center; }
  .news-track > .news-slide[data-reveal] { opacity: 1; transform: none; }
  .news-track .news-card { aspect-ratio: 4 / 5; padding: 24px; }
  .news-track .news-card h3 { font-size: 24px; }
  .news-track .news-card p { font-size: 14px; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; }
  .news-dots { display: flex; justify-content: center; gap: 8px; margin-top: 20px; }
  .news-dots button { width: 8px; height: 8px; padding: 0; border: 0; border-radius: 99px; background: var(--border); cursor: pointer; transition: width 0.3s var(--ease-out), background 0.3s; }
  .news-dots button.is-active { width: 26px; background: var(--brand); }
}
@media (max-width: 600px) {
  .news-track > .news-slide { flex-basis: 84%; }
  .news-track .news-card { aspect-ratio: 4 / 5.2; padding: 22px; }
  .section-head .lead { font-size: 16px; }
}

/* menu page: keep each dish's text at the top of its row */
.menu-item { align-content: start; }

/* ════════════ UPDATE 3 — hero centred + Google rating, event passed tag ════════════ */
.hero-body { align-items: center; padding-top: 150px; padding-bottom: 150px; }
.hero-grid { grid-template-columns: minmax(0, 1fr); }
.hero-address { position: absolute; right: max(var(--gutter), calc((100% - 1360px) / 2 + var(--gutter))); bottom: 48px; }
.hero-rating { display: inline-flex; align-items: center; flex-wrap: wrap; gap: 10px; margin-top: 28px; font-size: 15px; color: var(--muted); animation: fadeUp 1.1s 0.45s var(--ease) both; }
.hero-rating b { color: #fff; font-weight: 500; font-size: 16px; }
.hero-rating:hover span:not(.rating-stars) { color: #fff; }
.rating-stars { position: relative; display: inline-block; font-size: 17px; letter-spacing: 2px; line-height: 1; color: rgba(255, 255, 255, 0.22); }
.rating-stars::before { content: "★★★★★"; position: absolute; inset: 0; width: var(--fill, 100%); overflow: hidden; white-space: nowrap; color: var(--lime); }
@media (max-width: 900px) {
  .hero-body { padding-top: 130px; padding-bottom: 120px; }
  .hero-address { left: var(--gutter); right: auto; bottom: 36px; text-align: left; }
}
@media (max-width: 600px) {
  .hero-body { padding-bottom: 110px; }
  .hero-rating { font-size: 14px; gap: 8px; }
}

/* event cards: "Event passed" tag + dimmed photo */
.past-flag { background: rgba(15, 17, 25, 0.82); color: #fff; backdrop-filter: blur(4px); border: 1px solid rgba(255, 255, 255, 0.18); }
.event-card.is-over .event-card-media img { filter: grayscale(0.6) brightness(0.8); }
.past-flag-inline { position: static; display: inline-block; margin-bottom: 14px; }
.form-alert:not(.ok):not(.err) { background: var(--surface); border: 1px solid var(--border); color: var(--text); }

/* gallery: video tiles + players */
.masonry-item.is-video::after { content: ""; position: absolute; inset: 0; background: linear-gradient(180deg, transparent 55%, rgba(15, 17, 25, 0.55)); pointer-events: none; }
.play-badge { position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%); z-index: 1; width: 58px; height: 58px; border-radius: 50%; display: flex; align-items: center; justify-content: center; background: rgba(15, 17, 25, 0.55); color: #fff; border: 1.5px solid rgba(255, 255, 255, 0.85); backdrop-filter: blur(4px); transition: transform 0.3s var(--ease-out), background 0.3s; }
.play-badge svg { margin-left: 3px; }
.masonry-item.is-video:hover .play-badge { transform: translate(-50%, -50%) scale(1.1); background: var(--brand); color: var(--ink); border-color: var(--brand); }
.lightbox .lb-embed { width: min(440px, 100%); height: min(780px, 100%); border: 0; border-radius: var(--radius-md); background: #fff; }
.lightbox .lb-video { max-width: 100%; max-height: 100%; border-radius: var(--radius-md); background: #000; }
AMMOS_EOF
echo "  ✔ app/globals.css"

echo ""
echo "→ Updating the database…"
npm run db:migrate
echo ""
echo "────────────────────────────────────────────────────────────"
echo " NOW: in the Claude app, open the Browser pane (Instagram page)"
echo "      and click the blue  COPY AMMOS LIST  button (top-left)."
echo "      Then come back here and press Enter."
echo "────────────────────────────────────────────────────────────"
read -r -p "Press Enter after clicking the button… " _
npm run gallery:instagram
echo ""
echo "✔ Update 4 done. Start the site again:  npm run dev   → open http://localhost:3000/gallery"
