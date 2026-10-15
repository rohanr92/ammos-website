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
    notify: boolean("notify").notNull().default(true), // gets an email for every new booking & message
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
