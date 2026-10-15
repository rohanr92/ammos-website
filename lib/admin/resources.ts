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
