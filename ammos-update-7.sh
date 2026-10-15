#!/bin/bash
# Ammos website — update 7: hero photo slideshow, overlay event cards (switchable), real dish photos,
# email notifications per admin user, bulk select/delete in the admin.
set -e
if [ ! -f drizzle/0004_instagram_event_photos.sql ]; then echo "✖ Run this inside ammos-website after update 6."; exit 1; fi
if [ ! -f public/images/ig/hero-sunset.webp ]; then echo "✖ The new photos in public/images/ig are missing."; exit 1; fi
echo "→ Updating files…"

mkdir -p "lib"
cat > "lib/content-schema.ts" << 'AMMOS_EOF'
/**
 * EDITABLE CONTENT
 * ----------------
 * Every text and image the admin can change from "Admin → Page content" is
 * described here: which fields a section has, and its default values
 * (taken from the approved design). The admin form is generated from these
 * definitions, so adding a new field here makes it editable automatically.
 *
 * This file has no server-only code, so the admin form can import it too.
 */

export type FieldDef =
  | {
      name: string;
      label: string;
      type: "text" | "textarea" | "richtext" | "url" | "email" | "number" | "checkbox" | "image" | "video";
      help?: string;
    }
  | { name: string; label: string; type: "select"; options: { value: string; label: string }[]; help?: string }
  | { name: string; label: string; type: "list"; itemLabel: string; fields: FieldDef[]; help?: string };

export type SectionDef = {
  key: string;
  title: string;
  group: "Settings" | "Homepage" | "Pages";
  description: string;
  fields: FieldDef[];
  defaults: Record<string, unknown>;
};

export const ICON_OPTIONS = [
  { value: "umbrella", label: "Beach umbrella" },
  { value: "fork-knife", label: "Fork & knife" },
  { value: "martini", label: "Cocktail" },
  { value: "vinyl-record", label: "Vinyl / DJ" },
  { value: "confetti", label: "Confetti / party" },
  { value: "coffee", label: "Coffee" },
  { value: "sun", label: "Sun" },
  { value: "wine", label: "Wine" },
  { value: "fish", label: "Fish" },
  { value: "music-notes", label: "Music" },
  { value: "champagne", label: "Champagne" },
];

const t = (name: string, label: string, help?: string): FieldDef => ({ name, label, type: "text", help });
const ta = (name: string, label: string, help?: string): FieldDef => ({ name, label, type: "textarea", help });
const img = (name: string, label: string, help?: string): FieldDef => ({ name, label, type: "image", help });

const KICKER_HELP = "Small coloured line above the title";
const TITLE_HELP = "Use a new line to break the title onto two lines";

export const SECTIONS: SectionDef[] = [
  /* ═════════════════════ SETTINGS ═════════════════════ */
  {
    key: "settings",
    title: "Business details & SEO",
    group: "Settings",
    description: "Contact details, opening hours, social links, reservation link and default SEO text. Used in the header, footer, contact page and Google data.",
    fields: [
      t("siteName", "Business name"),
      t("tagline", "Tagline"),
      { name: "email", label: "Email", type: "email" },
      t("phone", "Phone number"),
      t("address", "Address (street / area)"),
      t("city", "City"),
      t("postcode", "Postcode"),
      t("country", "Country"),
      t("mapQuery", "Google Maps search text", "What Google Maps should search for on the contact page map"),
      t("latitude", "Latitude (for Google)", "Right-click the place in Google Maps to copy it, e.g. 34.8873"),
      t("longitude", "Longitude (for Google)", "e.g. 33.6396"),
      { name: "reservationUrl", label: "Table reservation link (Klisto)", type: "url" },
      { name: "facebook", label: "Facebook", type: "url" },
      { name: "instagram", label: "Instagram", type: "url" },
      t("instagramHandle", "Instagram handle (shown as @…)"),
      { name: "tiktok", label: "TikTok", type: "url" },
      { name: "youtube", label: "YouTube", type: "url" },
      { name: "linktree", label: "Linktree", type: "url" },
      {
        name: "hours",
        label: "Opening hours",
        type: "list",
        itemLabel: "Day",
        fields: [t("day", "Day"), t("open", "Opens (HH:MM)"), t("close", "Closes (HH:MM)")],
      },
      t("hoursNote", "Short opening hours line", "Shown in the footer, e.g. “Open daily 10:00 – 22:30”"),
      t("googleRating", "Google rating", "e.g. 4.4 — shown under the hero buttons and in the reviews block"),
      t("reviewCount", "Number of reviews text", "e.g. 1,700+"),
      { name: "googleReviewsUrl", label: "Google reviews link", type: "url", help: "Where the rating links to (your Google Maps page)" },
      { name: "hiring", label: "We are currently hiring", type: "checkbox", help: "Turn on to show open positions text on the Careers page" },
      t("seoTitle", "Default SEO title"),
      ta("seoDescription", "Default SEO description", "About 150 characters. Shown in Google results."),
    ],
    defaults: {
      siteName: "Ammos Makenzy Beach",
      tagline: "Beach bar & restaurant in Larnaca",
      email: "info@ammos.eu",
      phone: "+357 24 828844",
      address: "Makenzy Beach",
      city: "Larnaca",
      postcode: "6028",
      country: "Cyprus",
      mapQuery: "Ammos Beach Bar, Makenzy Beach, Larnaca, Cyprus",
      latitude: "34.8882654",
      longitude: "33.6367274",
      reservationUrl: "https://www.klisto.com.cy/Profile/ammos",
      facebook: "https://www.facebook.com/ammos.eu/",
      instagram: "https://www.instagram.com/ammosbeachbar/",
      instagramHandle: "ammosbeachbar",
      tiktok: "https://www.tiktok.com/@ammosbeachbar",
      youtube: "https://www.youtube.com/@ammosbeachbar?sub_confirmation=1",
      linktree: "https://linktr.ee/ammosbeachbar",
      hours: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].map((day) => ({
        day,
        open: "10:00",
        close: "22:30",
      })),
      hoursNote: "Open daily 10:00 – 22:30",
      googleRating: "4.4",
      reviewCount: "1,700+",
      googleReviewsUrl: "https://www.google.com/maps/place/?q=place_id:ChIJXS1cUdyC4BQR57zhqvcoh1Y",
      hiring: false,
      seoTitle: "Ammos Makenzy Beach — Beach Bar & Restaurant in Larnaca, Cyprus",
      seoDescription:
        "Beach bar, restaurant and terrace on Makenzy Beach, Larnaca since 2005. Fresh seafood, sushi, cocktails, live DJs and events. Book your table.",
    },
  },

  /* ═════════════════════ HOMEPAGE ═════════════════════ */
  {
    key: "home.hero",
    title: "Hero (top of homepage)",
    group: "Homepage",
    description: "The big first screen with title and buttons. Choose if the background shows the photo or the video.",
    fields: [
      t("kicker", "Kicker", KICKER_HELP),
      ta("title", "Title", TITLE_HELP),
      ta("subtitle", "Subtitle"),
      t("primaryLabel", "Main button text", "Opens the table reservation link"),
      t("secondaryLabel", "Second button text", "Goes to the events page"),
      ta("addressLine", "Address text (bottom right)", "New line = line break"),
      { name: "showRating", label: "Show Google rating under the buttons", type: "checkbox", help: "The rating and review count are set in Business details & SEO" },
      {
        name: "mediaType",
        label: "Background shows",
        type: "select",
        options: [
          { value: "slideshow", label: "Photo slideshow (slow fade between the photos below)" },
          { value: "image", label: "One photo" },
          { value: "video", label: "Video (photo shows while it loads)" },
        ],
        help: "Switch any time — the photos and the video are all kept.",
      },
      { name: "slides", label: "Slideshow photos", type: "list", itemLabel: "Photo", fields: [img("image", "Photo"), t("position", "Focus point (optional)", "e.g. center 40% — which part of the photo stays visible on phones")] },
      img("image", "Background photo", "Shown when “One photo” is selected, and while the video loads"),
      { name: "video", label: "Background video", type: "video", help: "Used when “Video” is selected. MP4, short and small (under 15 MB)." },
    ],
    defaults: {
      kicker: "Makenzy Beach",
      title: "your home\nfor 21 years.",
      subtitle: "Beach bar, restaurant and late-night terrace on the Makenzy strip. Sunrise coffee to last-call cocktails.",
      primaryLabel: "Make reservation",
      secondaryLabel: "View events",
      addressLine: "Makenzy Beach\nLarnaca, Cyprus",
      showRating: true,
      mediaType: "slideshow",
      slides: [
        { image: "/images/ig/hero-sunset.webp", position: "center 55%" },
        { image: "/images/ig/hero-terrace-night.webp", position: "center 45%" },
        { image: "/images/ig/hero-sashimi.webp", position: "center 60%" },
        { image: "/images/ig/hero-dining-sea.webp", position: "70% 40%" },
      ],
      image: "/images/ig/hero-sunset.webp",
      video: "https://assets.mixkit.co/videos/4043/4043-720.mp4",
    },
  },
  {
    key: "home.events",
    title: "Upcoming events block",
    group: "Homepage",
    description: "Heading of the events slider and the look of the event cards. The cards come from Admin → Events (marked “Show on homepage”).",
    fields: [
      t("kicker", "Kicker", KICKER_HELP),
      t("title", "Title"),
      t("buttonLabel", "Button text"),
      {
        name: "cardStyle",
        label: "Event card style",
        type: "select",
        options: [
          { value: "overlay", label: "Overlay — text on the photo, date badge, arrow button" },
          { value: "editorial", label: "Editorial — photo with the text underneath" },
        ],
        help: "Used on the homepage slider and the Events page.",
      },
    ],
    defaults: { kicker: "What's on", title: "upcoming events", buttonLabel: "View all events", cardStyle: "overlay" },
  },
  {
    key: "home.story",
    title: "The Ammos story (timeline)",
    group: "Homepage",
    description: "Timeline with years and the fanned photos below it.",
    fields: [
      t("kicker", "Kicker", KICKER_HELP),
      t("title", "Title"),
      ta("text", "Intro text"),
      {
        name: "timeline",
        label: "Timeline",
        type: "list",
        itemLabel: "Milestone",
        fields: [t("year", "Year"), t("title", "Title"), ta("text", "Text"), img("image", "Photo")],
      },
      { name: "fan", label: "Fanned photos (5 work best)", type: "list", itemLabel: "Photo", fields: [img("image", "Photo"), t("alt", "Description (for Google)")] },
    ],
    defaults: {
      kicker: "Since 2005",
      title: "the ammos story",
      text: "We might be the pioneers of the 'Makenzy Strip', but at Ammos we never stand still for too long. From our ever-changing menu, to a full makeover, Ammos is always evolving, progressing, and staying ahead of the trends.",
      timeline: [
        { year: "2005", title: "First on the strip", text: "Ammos opens its doors on Makenzy Beach, before there was a strip to speak of.", image: "/images/ig/story-2005-van.webp" },
        { year: "2011", title: "The kitchen grows", text: "A full restaurant menu joins the bar. Sunday brunch becomes a Larnaca ritual.", image: "/images/ig/story-2011-sushi.webp" },
        { year: "2015", title: "A Larnaca favourite", text: "Word spreads along the coast, and the regulars keep coming back.", image: "/images/ig/story-2015-friends.webp" },
        { year: "2026", title: "The full makeover", text: "New look, same beach. Still evolving, still ahead of the trends.", image: "/images/ig/story-2026-terrace.webp" },
      ],
      fan: [
        { image: "/images/ig/fan-interior.webp", alt: "Inside Ammos" },
        { image: "/images/ig/fan-sushi.webp", alt: "Sushi at Ammos" },
        { image: "/images/ig/fan-entrance.webp", alt: "The Ammos entrance on Makenzy Beach" },
        { image: "/images/ig/fan-aperol.webp", alt: "Spritz on the Ammos terrace" },
        { image: "/images/ig/fan-sunset.webp", alt: "Sunset over Makenzy Beach" },
      ],
    },
  },
  {
    key: "home.activities",
    title: "Our activities (polaroids)",
    group: "Homepage",
    description: "The polaroid photos and the moving words strip.",
    fields: [
      t("kicker", "Kicker", KICKER_HELP),
      ta("title", "Title", TITLE_HELP),
      ta("text", "Text"),
      {
        name: "polaroids",
        label: "Polaroids (5 work best)",
        type: "list",
        itemLabel: "Polaroid",
        fields: [t("label", "Label"), { name: "icon", label: "Icon", type: "select", options: ICON_OPTIONS }, img("image", "Photo")],
      },
      { name: "marquee", label: "Moving words strip", type: "list", itemLabel: "Word", fields: [t("word", "Word or phrase")] },
    ],
    defaults: {
      kicker: "All day, every day",
      title: "our\nactivities",
      text: "One address, a whole day of it. Sunbeds and coffee in the morning, long lunches, sunset cocktails at the bar and resident DJs on the terrace until late.",
      polaroids: [
        { label: "Beach club", icon: "umbrella", image: "/images/ig/beach-club.webp" },
        { label: "Lunch", icon: "fork-knife", image: "/images/ig/lunch-octopus.webp" },
        { label: "Cocktails", icon: "martini", image: "/images/ig/cocktail-passion.webp" },
        { label: "Live DJ", icon: "vinyl-record", image: "/images/ig/live-dj.webp" },
        { label: "Private events", icon: "confetti", image: "/images/ig/private-dinner.webp" },
      ],
      marquee: [{ word: "beach club" }, { word: "sunset cocktails" }, { word: "brunch" }, { word: "private events" }, { word: "fresh seafood" }],
    },
  },
  {
    key: "home.video",
    title: "Discover video",
    group: "Homepage",
    description: "The blurred photo with the play button. Clicking plays the video.",
    fields: [
      t("label", "Text under the play button"),
      img("poster", "Background photo"),
      { name: "video", label: "Video", type: "video", help: "MP4 upload, or paste a link to an .mp4 file" },
      { name: "youtubeUrl", label: "…or a YouTube link instead", type: "url", help: "If filled, the YouTube video plays instead of the MP4" },
    ],
    defaults: {
      label: "Discover Ammos",
      poster: "/images/bar-interior.jpg",
      video: "https://assets.mixkit.co/videos/4295/4295-720.mp4",
      youtubeUrl: "",
    },
  },
  {
    key: "home.chefs",
    title: "Passionate foodies (chefs)",
    group: "Homepage",
    description: "Two photos and the chefs text.",
    fields: [
      t("kicker", "Kicker", KICKER_HELP),
      ta("title", "Title", TITLE_HELP),
      ta("text", "Text"),
      t("quote", "Quote"),
      t("primaryLabel", "Button text", "Goes to the Our Story page"),
      img("image1", "Large photo"),
      img("image2", "Small photo"),
    ],
    defaults: {
      kicker: "Our Chefs Story",
      title: "passionate\nfoodies",
      text: "Ammos is not only about great food. But it's a good place to start. And with our incredible team of passionate foodies, we're bringing a holistic experience to the table; served up in a fusion of mouth-watering flavours, aromas and tastes.",
      quote: "“Fresh, local, and never the same twice.”",
      primaryLabel: "Discover more",
      image1: "/images/ig/chef-sauce.webp",
      image2: "/images/ig/chef-plating.webp",
    },
  },
  {
    key: "home.menu",
    title: "Menu block",
    group: "Homepage",
    description: "Heading and text of the menu block. The dishes are the menu items marked “Show on homepage” (add a photo to a dish to show it on hover).",
    fields: [
      t("kicker", "Kicker", KICKER_HELP),
      ta("title", "Title", TITLE_HELP),
      ta("text", "Text"),
      t("buttonLabel", "Button text"),
      { name: "buttonUrl", label: "Button link", type: "url", help: "Where the button goes, e.g. the live menu or /menu" },
      t("hint", "Small hint text (optional)"),
    ],
    defaults: {
      kicker: "Salivating yet?",
      title: "ammos\nmenu",
      text: "At Ammos, we don't follow trends. We create them. Just check out our exciting menu for proof – fresh, local ingredients, passionately assembled by talented chefs, to create an explosion of tastes that will take you on an epicurean adventure around the world.",
      buttonLabel: "View all menu",
      buttonUrl: "https://ammos-beach-bar.nina.cy/?step=menu",
      hint: "",
    },
  },
  {
    key: "home.news",
    title: "News & stories block",
    group: "Homepage",
    description: "Heading of the news block. Articles come from Admin → News.",
    fields: [t("kicker", "Kicker", KICKER_HELP), t("title", "Title"), ta("text", "Text"), t("buttonLabel", "Button text")],
    defaults: {
      kicker: "Beyond the bar",
      title: "news & stories",
      text: "Ammos is always evolving, progressing, and staying ahead of the trends. Check our latest news and blogs here.",
      buttonLabel: "View all news",
    },
  },
  {
    key: "home.reviews",
    title: "Reviews block",
    group: "Homepage",
    description: "Heading of the reviews block. Reviews come from Admin → Reviews.",
    fields: [t("kicker", "Kicker", KICKER_HELP), t("title", "Title")],
    defaults: { kicker: "Reviews", title: "you said it" },
  },
  {
    key: "home.gallery",
    title: "Gallery block",
    group: "Homepage",
    description: "Photo grid. Photos come from Admin → Gallery (marked “Show on homepage”).",
    fields: [t("kicker", "Kicker", KICKER_HELP), t("title", "Title"), ta("centerTitle", "Title in the middle of the grid", TITLE_HELP), t("buttonLabel", "Button text"), t("instagramLabel", "Instagram button text")],
    defaults: {
      kicker: "@ammosbeachbar",
      title: "straight from the strip",
      centerTitle: "welcome\nto your place.",
      buttonLabel: "Book a table",
      instagramLabel: "Follow on Instagram",
    },
  },
  {
    key: "home.contact",
    title: "Contact form block",
    group: "Homepage",
    description: "The enquiry form at the bottom of the homepage.",
    fields: [t("title", "Title"), img("image", "Background photo"), t("buttonLabel", "Send button text")],
    defaults: { title: "have an amazing experience!", image: "/images/party.jpg", buttonLabel: "Send" },
  },

  /* ═════════════════════ PAGES ═════════════════════ */
  {
    key: "page.story",
    title: "Our Story page",
    group: "Pages",
    description: "The About us page (/our-story).",
    fields: [
      t("kicker", "Kicker", KICKER_HELP),
      ta("title", "Title", TITLE_HELP),
      img("heroImage", "Top photo"),
      { name: "intro", label: "Intro text", type: "richtext", help: "Empty line = new paragraph" },
      {
        name: "chapters",
        label: "Story chapters",
        type: "list",
        itemLabel: "Chapter",
        fields: [t("kicker", "Small line"), t("title", "Title"), { name: "text", label: "Text", type: "richtext" }, img("image", "Photo")],
      },
      t("quote", "Big quote"),
    ],
    defaults: {
      kicker: "Since 2005",
      title: "the ammos\nstory",
      heroImage: "/images/awards-interior.jpg",
      intro:
        "Ammos Beach Bar started out as the first beach bar on a quiet seaside strip called Mackenzie Beach in Larnaca.\n\nIn 2005, the management of Ammos took a major risk by setting up a chilled-out lounge bar on a very under-developed part of Larnaca. As the beach transformed into one of the most popular going-out destinations in Cyprus, Ammos remained the frontrunner of the island's bar scene — with a combination of fine cuisine, top-quality drinks and the very best in entertainment.",
      chapters: [
        {
          kicker: "The strip",
          title: "From sleepy seaside to Makenzy Beach",
          text: "What was once a sleepy seaside area for eating fresh fish has evolved, thanks to Ammos, into an exciting entertainment centre with easy access to good food, the tastiest drinks and events to remember.",
          image: "/images/party.jpg",
        },
        {
          kicker: "The table",
          title: "High-quality dining along the beach",
          text: "Another idea born at Ammos: combining a night out with a real restaurant experience. Perfectly prepared, simply served and finished the Ammos way — from sushi and seafood to steaks and Sunday brunch.",
          image: "/images/chef-plate.jpg",
        },
        {
          kicker: "The people",
          title: "Regulars who became friends",
          text: "We might be the pioneers of the Makenzy Strip, but we never stand still. From our ever-changing menu to a full makeover, Ammos is always evolving — and the people who come back year after year are the reason why.",
          image: "/images/bartender.jpg",
        },
      ],
      quote: "“We might be the pioneers of the Makenzy Strip, but we never stand still for too long.”",
    },
  },
  {
    key: "page.headers",
    title: "Page headers",
    group: "Pages",
    description: "Title, intro text and photo at the top of the listing pages.",
    fields: [
      t("eventsTitle", "Events — title"),
      ta("eventsText", "Events — intro"),
      img("eventsImage", "Events — photo"),
      t("calendarTitle", "Events calendar — title"),
      ta("calendarText", "Events calendar — intro"),
      t("menuTitle", "Menu — title"),
      ta("menuText", "Menu — intro"),
      img("menuImage", "Menu — photo"),
      t("galleryTitle", "Gallery — title"),
      ta("galleryText", "Gallery — intro"),
      img("galleryImage", "Gallery — photo"),
      t("newsTitle", "News — title"),
      ta("newsText", "News — intro"),
      img("newsImage", "News — photo"),
      t("contactTitle", "Contact — title"),
      ta("contactText", "Contact — intro"),
      img("contactImage", "Contact — photo"),
    ],
    defaults: {
      eventsTitle: "events",
      eventsText: "Live DJs, full-moon parties, long Sunday brunches and acoustic nights on the terrace. Pick a night and save your table.",
      eventsImage: "/images/party.jpg",
      calendarTitle: "events calendar",
      calendarText: "Every night that's planned on the strip, month by month.",
      menuTitle: "our menu",
      menuText: "Fresh, local ingredients, sushi rolled to order, seafood from the josper grill, and a cocktail list built for sunsets.",
      menuImage: "/images/chef-plate.jpg",
      galleryTitle: "gallery",
      galleryText: "Sunbeds, sunsets, plates and parties — straight from the strip.",
      galleryImage: "/images/bar-interior.jpg",
      newsTitle: "news & stories",
      newsText: "What's been happening at Ammos, and what's coming next.",
      newsImage: "/images/news-2.jpg",
      contactTitle: "contact us",
      contactText: "Questions, group bookings, birthdays or just saying hello — we'd love to hear from you.",
      contactImage: "/images/party.jpg",
    },
  },
  {
    key: "page.privateEvents",
    title: "Private events page",
    group: "Pages",
    description: "Birthdays, weddings, corporate nights (/private-events).",
    fields: [
      ta("title", "Title", TITLE_HELP),
      { name: "intro", label: "Intro", type: "richtext" },
      img("image", "Photo"),
      { name: "options", label: "Options", type: "list", itemLabel: "Option", fields: [t("title", "Title"), ta("text", "Text")] },
    ],
    defaults: {
      title: "private\nevents",
      intro: "From a birthday table for twelve to taking over the whole terrace — our team plans, cooks and pours so you can enjoy the night.\n\nTell us the date, the number of guests and the mood, and we'll come back to you with a proposal.",
      image: "/images/flowers.jpg",
      options: [
        { title: "Birthdays & celebrations", text: "Reserved tables, set menus, a cake moment and bottles on ice." },
        { title: "Corporate events", text: "Team dinners, product launches and end-of-year parties by the sea." },
        { title: "Weddings & engagements", text: "Sunset ceremonies, beach receptions and after-parties on the terrace." },
        { title: "Full venue buyout", text: "The whole of Ammos, your guest list, your music." },
      ],
    },
  },
  {
    key: "page.careers",
    title: "Careers page",
    group: "Pages",
    description: "Shown at /careers. Switch “We are currently hiring” in Business details to change which text shows.",
    fields: [
      ta("title", "Title", TITLE_HELP),
      { name: "notHiringText", label: "Text when NOT hiring", type: "richtext" },
      { name: "hiringText", label: "Text when hiring (list positions here)", type: "richtext" },
    ],
    defaults: {
      title: "join the\nammos team",
      notHiringText:
        "We're not hiring at the moment — our team is complete for now.\n\nWe still love meeting people who care about great food, drinks and hospitality. Send your CV to info@ammos.eu and we'll keep it on file for the next season.",
      hiringText:
        "We're looking for people who love hospitality.\n\n## Open positions\n- Waiters & waitresses\n- Bartenders\n- Kitchen staff\n\nSend your CV and a short message to info@ammos.eu.",
    },
  },
  {
    key: "page.houseRules",
    title: "House rules page",
    group: "Pages",
    description: "Shown at /house-rules.",
    fields: [t("title", "Title"), { name: "body", label: "Text", type: "richtext" }],
    defaults: {
      title: "house rules",
      body:
        "We want everyone to have a great time at Ammos. A few simple rules help us keep it that way.\n\n## Reservations\n- Tables are held for 15 minutes after the booking time.\n- For groups of 10 or more please contact us in advance.\n\n## On the beach\n- Sunbeds are available on a first-come basis unless reserved.\n- Please respect the lifeguard's instructions and flags.\n\n## In the evening\n- Smart-casual dress code after 20:00.\n- Management reserves the right of admission.\n- Guests must be 18+ to be served alcohol. ID may be requested.\n\n## Please\n- No outside food or drinks.\n- Keep the beach clean — use the bins provided.",
    },
  },
  {
    key: "page.privacy",
    title: "Privacy policy page",
    group: "Pages",
    description: "Shown at /privacy-policy. Have this checked by your legal adviser.",
    fields: [t("title", "Title"), { name: "body", label: "Text", type: "richtext" }],
    defaults: {
      title: "privacy policy",
      body:
        "This policy explains how Ammos Makenzy Beach (\"we\") collects and uses personal data through this website, in line with the EU General Data Protection Regulation (GDPR).\n\n## What we collect\n- Contact form: your name, email, phone number, preferred date, number of guests and message.\n- Event bookings: your name, email, phone number, number of guests and any notes you add.\n\n## Why we use it\n- To answer your enquiry and manage your booking.\n- To send you news and offers, only if you have ticked the box to receive them.\n\n## How long we keep it\nWe keep enquiries and bookings for up to 24 months, then delete them.\n\n## Who we share it with\nWe do not sell your data. It is stored on our own server and sent through our email provider only to answer you.\n\n## Your rights\nYou can ask to see, correct or delete your data at any time by emailing info@ammos.eu.\n\n## Cookies\nThis website only uses the cookies needed for it to work (for example the admin login). We do not use advertising cookies.",
    },
  },
  {
    key: "page.legal",
    title: "Legal notice page",
    group: "Pages",
    description: "Shown at /legal-notice.",
    fields: [t("title", "Title"), { name: "body", label: "Text", type: "richtext" }],
    defaults: {
      title: "legal notice",
      body:
        "## Website operator\nAmmos Makenzy Beach\nMakenzy Beach, Larnaca 6028, Cyprus\nPhone: +357 24 828844\nEmail: info@ammos.eu\n\n## Content\nAll texts, photos and logos on this website belong to Ammos Makenzy Beach unless stated otherwise and may not be copied without permission.\n\n## Liability\nWe take care to keep the information on this website correct and up to date, but menus, prices, opening hours and events may change without notice.",
    },
  },
];

export const SECTION_MAP: Record<string, SectionDef> = Object.fromEntries(SECTIONS.map((s) => [s.key, s]));

/** Types of the settings block (handy for components). */
export type Settings = {
  siteName: string;
  tagline: string;
  email: string;
  phone: string;
  address: string;
  city: string;
  postcode: string;
  country: string;
  mapQuery: string;
  latitude: string;
  longitude: string;
  reservationUrl: string;
  facebook: string;
  instagram: string;
  instagramHandle: string;
  tiktok: string;
  youtube: string;
  linktree: string;
  hours: { day: string; open: string; close: string }[];
  hoursNote: string;
  googleRating: string;
  reviewCount: string;
  googleReviewsUrl: string;
  hiring: boolean;
  seoTitle: string;
  seoDescription: string;
};
AMMOS_EOF
echo "  ✔ lib/content-schema.ts"

mkdir -p "components/site"
cat > "components/site/HeroSlideshow.tsx" << 'AMMOS_EOF'
"use client";

import { useEffect, useState } from "react";
import Image from "next/image";

type Slide = { image: string; position?: string };

/** Full-screen hero photos that slowly zoom and cross-fade (pauses for visitors who prefer less motion). */
export function HeroSlideshow({ slides, interval = 6500 }: { slides: Slide[]; interval?: number }) {
  const list = slides.filter((s) => s?.image);
  const [active, setActive] = useState(0);

  useEffect(() => {
    if (list.length < 2) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const t = setInterval(() => setActive((i) => (i + 1) % list.length), interval);
    return () => clearInterval(t);
  }, [list.length, interval]);

  return (
    <div className="hero-slides" aria-hidden="true">
      {list.map((s, i) => (
        <div key={`${s.image}-${i}`} className={`hero-slide${i === active ? " is-active" : ""}`}>
          {/^https?:/.test(s.image) ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={s.image} alt="" className="fill-img" style={{ objectPosition: s.position || "center" }} />
          ) : (
            <Image src={s.image} alt="" fill sizes="100vw" quality={85} preload={i === 0} className="cover" style={{ objectPosition: s.position || "center" }} />
          )}
        </div>
      ))}
      {list.length > 1 && (
        <div className="hero-dots">
          {list.map((_, i) => (
            <span key={i} className={i === active ? "is-active" : ""} />
          ))}
        </div>
      )}
    </div>
  );
}
AMMOS_EOF
echo "  ✔ components/site/HeroSlideshow.tsx"

mkdir -p "app/(site)"
cat > "app/(site)/page.tsx" << 'AMMOS_EOF'
import Link from "next/link";
import type { Metadata } from "next";
import { getContent, getSettings } from "@/lib/content";
import { getGallery, getHomeEvents, getHomeMenu, getReviews, listPosts } from "@/lib/data";
import { pageMeta } from "@/lib/seo";
import { initials } from "@/lib/utils";
import { Img } from "@/components/site/Img";
import { Icon } from "@/components/site/Icon";
import { MultiLine } from "@/components/site/MultiLine";
import { EventCard } from "@/components/site/EventCard";
import { HorizontalSlider } from "@/components/site/HorizontalSlider";
import { HeroVideo } from "@/components/site/HeroVideo";
import { HeroSlideshow } from "@/components/site/HeroSlideshow";
import { DiscoverVideo } from "@/components/site/DiscoverVideo";
import { HomeMenu } from "@/components/site/HomeMenu";
import { ContactForm } from "@/components/site/ContactForm";
import { NewsCarousel } from "@/components/site/NewsCarousel";

// Page is pre-built and refreshed every 5 minutes, and instantly when you save in the admin.
export const revalidate = 300;

export async function generateMetadata(): Promise<Metadata> {
  const s = await getSettings();
  const hero = await getContent("home.hero");
  return { ...pageMeta({ title: s.seoTitle, description: s.seoDescription, path: "/", image: hero.image }), title: { absolute: s.seoTitle } };
}

const FAN = [
  { w: "18%", rot: -14, z: 1, delay: ".5s", from: "translate3d(-120px,80px,0) rotate(-10deg)" },
  { w: "20%", rot: -7, z: 2, delay: ".25s", from: "translate3d(-60px,80px,0) rotate(-6deg)" },
  { w: "24%", rot: 0, z: 3, delay: "0s", from: "translate3d(0,120px,0) scale(0.92)" },
  { w: "20%", rot: 7, z: 2, delay: ".25s", from: "translate3d(60px,80px,0) rotate(6deg)" },
  { w: "18%", rot: 14, z: 1, delay: ".5s", from: "translate3d(120px,80px,0) rotate(10deg)" },
];
const POLAROID_POS = [
  { x: "0%", y: "2%", rot: -8, z: 1 },
  { x: "34%", y: "0%", rot: 5, z: 2 },
  { x: "66%", y: "6%", rot: -4, z: 1 },
  { x: "16%", y: "48%", rot: 6, z: 3 },
  { x: "52%", y: "50%", rot: -6, z: 2 },
  { x: "78%", y: "52%", rot: 4, z: 1 },
];
// 5-column photo grid with the title in the middle (row 2, columns 2–4)
const GRID_SLOTS = [
  [1, 1], [2, 1], [3, 1], [4, 1], [5, 1],
  [1, 2], [5, 2],
  [1, 3], [2, 3], [3, 3], [4, 3], [5, 3],
];

export default async function HomePage() {
  const [settings, hero, evCopy, story, act, video, chefs, menuCopy, newsCopy, revCopy, galCopy, contact] = await Promise.all([
    getSettings(),
    getContent("home.hero"),
    getContent("home.events"),
    getContent("home.story"),
    getContent("home.activities"),
    getContent("home.video"),
    getContent("home.chefs"),
    getContent("home.menu"),
    getContent("home.news"),
    getContent("home.reviews"),
    getContent("home.gallery"),
    getContent("home.contact"),
  ]);
  const [events, menuTabs, posts, reviews, gallery] = await Promise.all([getHomeEvents(), getHomeMenu(), listPosts(3), getReviews(), getGallery({ homeOnly: true })]);

  const half = Math.ceil(reviews.length / 2);
  const rowA = [...reviews.slice(0, half), ...reviews.slice(half)];
  const rowB = [...reviews.slice(half), ...reviews.slice(0, half)];
  const marquee: { word: string }[] = act.marquee ?? [];
  const tiles = gallery.length ? GRID_SLOTS.map((slot, i) => ({ slot, img: gallery[i % gallery.length] })) : [];
  // hero background: the admin chooses "Photo" or "Video" (falls back to the photo if no video is set)
  const showHeroVideo = hero.mediaType === "video" && Boolean(hero.video);
  const heroSlides: { image: string; position?: string }[] = (Array.isArray(hero.slides) ? hero.slides : []).filter((x: { image?: string }) => x?.image);
  const showSlideshow = hero.mediaType === "slideshow" && heroSlides.length > 0;
  const menuUrl: string = menuCopy.buttonUrl || "/menu";
  const menuUrlExternal = /^https?:\/\//.test(menuUrl);
  const ratingValue = Number(String(settings.googleRating || "").replace(",", ".")) || 0;

  return (
    <>
      {/* ═════ HERO ═════ */}
      <section className="hero" aria-label="Welcome">
        {showSlideshow ? (
          <HeroSlideshow slides={heroSlides} />
        ) : (
          <Img src={hero.image} alt="" preload quality={85} sizes="100vw" className="hero-media" style={{ objectPosition: "center 55%" }} />
        )}
        {showHeroVideo && <HeroVideo key={hero.video} src={hero.video} poster={hero.image} />}
        <div className="hero-shade" />
        <div className="container hero-body">
          <div className="hero-grid">
            <div>
              {hero.kicker && <p className="kicker">{hero.kicker}</p>}
              <h1 className="display display-xl">
                <MultiLine text={hero.title} />
                <span className="sr-only"> — Ammos beach bar &amp; restaurant, Makenzy Beach, Larnaca</span>
              </h1>
              <p className="hero-sub">{hero.subtitle}</p>
              <div className="btn-row">
                <a href={settings.reservationUrl} target="_blank" rel="noopener noreferrer" className="btn btn-brand">
                  {hero.primaryLabel}
                </a>
                <Link href="/events" className="btn btn-ghost-light">
                  {hero.secondaryLabel}
                </Link>
              </div>
              {hero.showRating !== false && ratingValue > 0 && (
                <a href={settings.googleReviewsUrl || "#reviews-title"} className="hero-rating" {...(settings.googleReviewsUrl ? { target: "_blank", rel: "noopener noreferrer" } : {})}>
                  <span className="rating-stars" style={{ ["--fill" as string]: `${Math.min(100, (ratingValue / 5) * 100)}%` }} aria-hidden="true">
                    ★★★★★
                  </span>
                  <b>{settings.googleRating}</b>
                  <span>· {settings.reviewCount} Google reviews</span>
                  <span className="sr-only"> — rated {settings.googleRating} out of 5 on Google</span>
                </a>
              )}
            </div>
            <address className="hero-address" style={{ fontStyle: "normal" }}>
              <MultiLine text={hero.addressLine} />
            </address>
          </div>
        </div>
      </section>

      {/* ═════ UPCOMING EVENTS ═════ */}
      {events.length > 0 && (
        <section id="events" className="events-home" aria-labelledby="events-title">
          <div className="container">
            <HorizontalSlider
              label="events"
              header={
                <div>
                  <p className="kicker kicker-teal">{evCopy.kicker}</p>
                  <h2 id="events-title" className="display display-md">
                    {evCopy.title}
                  </h2>
                </div>
              }
            >
              {events.map((e) => (
                <EventCard key={e.id} event={e} variant={evCopy.cardStyle === "editorial" ? "editorial" : "overlay"} />
              ))}
            </HorizontalSlider>
            <div className="center-row">
              <Link href="/events" className="btn btn-ink">
                {evCopy.buttonLabel}
              </Link>
            </div>
          </div>
        </section>
      )}

      {/* ═════ THE AMMOS STORY ═════ */}
      <section id="story" className="story" aria-labelledby="story-title">
        <div className="container">
          <div className="story-head" data-reveal>
            <div>
              <p className="kicker">{story.kicker}</p>
              <h2 id="story-title" className="display display-lg">
                {story.title}
              </h2>
            </div>
            <p className="lead">{story.text}</p>
          </div>
          <div className="timeline">
            {(story.timeline ?? []).slice(0, 4).map((t: Record<string, string>, i: number) => (
              <div key={i} data-reveal style={{ transitionDelay: `${i * 0.12}s` }}>
                <span className="timeline-dot" />
                <span className="timeline-year">{t.year}</span>
                <div className="timeline-img">
                  <Img src={t.image} alt={t.title} sizes="(max-width: 900px) 50vw, 25vw" />
                </div>
                <h3 className="display">{t.title}</h3>
                <p>{t.text}</p>
              </div>
            ))}
          </div>
        </div>
        {(story.fan ?? []).length > 0 && (
          <div className="fan" aria-hidden="true">
            {(story.fan as Record<string, string>[]).slice(0, 5).map((f, i) => {
              const p = FAN[i] ?? FAN[2];
              return (
                <div key={i} className="fan-item" data-reveal style={{ flex: `0 0 ${p.w}`, zIndex: p.z, transitionDelay: p.delay, ["--from" as string]: p.from }}>
                  <div className="fan-card" style={{ transform: `rotate(${p.rot}deg)` }}>
                    <Img src={f.image} alt={f.alt} sizes="(max-width: 900px) 30vw, 280px" />
                  </div>
                </div>
              );
            })}
          </div>
        )}
        <div className="center-row container">
          <Link href="/our-story" className="btn btn-outline">
            Read our story
          </Link>
        </div>
      </section>

      {/* ═════ ACTIVITIES ═════ */}
      <section className="activities" aria-labelledby="activities-title">
        <div className="container activities-grid">
          <div data-reveal>
            <p className="kicker">{act.kicker}</p>
            <h2 id="activities-title" className="display display-lg" style={{ color: "var(--brand)" }}>
              <MultiLine text={act.title} />
            </h2>
            <p className="lead" style={{ maxWidth: 480 }}>
              {act.text}
            </p>
          </div>
          <div className="polaroids">
            {(act.polaroids ?? []).slice(0, 6).map((p: Record<string, string>, i: number) => {
              const pos = POLAROID_POS[i];
              return (
                <div key={i} className="polaroid-wrap" data-reveal style={{ left: pos.x, top: pos.y, zIndex: pos.z, transitionDelay: `${i * 0.1}s` }}>
                  <div className="polaroid" style={{ transform: `rotate(${pos.rot}deg)` }}>
                    <div className="polaroid-img">
                      <Img src={p.image} alt={p.label} sizes="220px" />
                    </div>
                    <div className="polaroid-cap">
                      <span>{p.label}</span>
                      <Icon name={p.icon} size={20} />
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
        {marquee.length > 0 && (
          <div className="marquee" aria-hidden="true">
            <div className="marquee-track">
              {[...marquee, ...marquee].map((m, i) => (
                <span key={i} style={{ display: "inline-flex", alignItems: "center", gap: 56 }}>
                  <span>{m.word}</span>
                  <span className="marquee-dot" />
                </span>
              ))}
            </div>
          </div>
        )}
      </section>

      {/* ═════ DISCOVER VIDEO ═════ */}
      <DiscoverVideo poster={video.poster} video={video.video} youtubeUrl={video.youtubeUrl} label={video.label} />

      {/* ═════ CHEFS ═════ */}
      <section className="chefs" aria-labelledby="chefs-title">
        <div className="container chefs-grid">
          <div className="chefs-media">
            <div className="chefs-img1" data-reveal style={{ ["--from" as string]: "translate3d(0,80px,0)" }}>
              <div className="img-frame" style={{ aspectRatio: "4/5" }}>
                <Img src={chefs.image1} alt="Dish from the Ammos kitchen" sizes="(max-width: 900px) 70vw, 34vw" />
              </div>
            </div>
            <div className="chefs-img2" data-reveal style={{ transitionDelay: ".2s", ["--from" as string]: "translate3d(60px,0,0)" }}>
              <div className="img-frame" style={{ aspectRatio: "1", border: "4px solid var(--bg)" }}>
                <Img src={chefs.image2} alt="The Ammos kitchen" sizes="(max-width: 900px) 48vw, 24vw" />
              </div>
            </div>
          </div>
          <div data-reveal style={{ transitionDelay: ".1s" }}>
            <p className="kicker">{chefs.kicker}</p>
            <h2 id="chefs-title" className="display display-lg" style={{ marginBottom: 28 }}>
              <MultiLine text={chefs.title} />
            </h2>
            <p className="lead" style={{ marginBottom: 20 }}>
              {chefs.text}
            </p>
            {chefs.quote && <blockquote>{chefs.quote}</blockquote>}
            <div className="btn-row">
              <Link href="/our-story" className="btn btn-outline">
                {chefs.primaryLabel}
              </Link>
              <Link href="/menu" className="btn btn-muted">
                See the menu
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* ═════ MENU ═════ */}
      {menuTabs.length > 0 && (
        <section id="menu" className="section section-alt" aria-labelledby="menu-title">
          <div className="container">
            <HomeMenu
              tabs={menuTabs.map((t) => ({ ...t, items: t.items.map((i) => ({ id: i.id, name: i.name, description: i.description, price: i.price, image: i.image })) }))}
              intro={
                <>
                  <p className="kicker">{menuCopy.kicker}</p>
                  <h2 id="menu-title" className="display display-lg" style={{ marginBottom: 24 }}>
                    <MultiLine text={menuCopy.title} />
                  </h2>
                  <p className="lead" style={{ marginBottom: 32, maxWidth: 440 }}>
                    {menuCopy.text}
                  </p>
                </>
              }
              after={
                <>
                  {menuUrlExternal ? (
                    <a href={menuUrl} target="_blank" rel="noopener noreferrer" className="btn btn-outline">
                      {menuCopy.buttonLabel}
                    </a>
                  ) : (
                    <Link href={menuUrl} className="btn btn-outline">
                      {menuCopy.buttonLabel}
                    </Link>
                  )}
                  {menuCopy.hint && (
                    <p className="muted" style={{ fontSize: 12, letterSpacing: "0.08em", marginTop: 20 }}>
                      {menuCopy.hint}
                    </p>
                  )}
                </>
              }
            />
          </div>
        </section>
      )}

      {/* ═════ NEWS ═════ */}
      {posts.length > 0 && (
        <section className="section" aria-labelledby="news-title">
          <div className="container">
            <div className="section-head" data-reveal>
              <div>
                <p className="kicker">{newsCopy.kicker}</p>
                <h2 id="news-title" className="display display-lg">
                  {newsCopy.title}
                </h2>
              </div>
              <p className="lead">{newsCopy.text}</p>
            </div>
            <NewsCarousel>
              {posts.map((p, i) => (
                <article key={p.id} className="news-slide" data-reveal style={{ transitionDelay: `${i * 0.12}s` }}>
                  <div className="news-card">
                    <Img src={p.image} alt={p.title} sizes="(max-width: 900px) 100vw, 33vw" />
                    <div className="news-card-shade" />
                    <span className="news-kicker">{p.kicker}</span>
                    <h3 className="display">{p.title}</h3>
                    <p>{p.excerpt}</p>
                    <Link href={`/news/${p.slug}`} className="btn btn-ghost-light btn-sm stretched">
                      Read more ↗
                    </Link>
                  </div>
                </article>
              ))}
            </NewsCarousel>
            <div className="center-row">
              <Link href="/news" className="btn btn-outline">
                {newsCopy.buttonLabel}
              </Link>
            </div>
          </div>
        </section>
      )}

      {/* ═════ REVIEWS ═════ */}
      {reviews.length > 0 && (
        <section className="section section-alt reviews" aria-labelledby="reviews-title">
          <div className="container events-head" data-reveal style={{ marginBottom: 48 }}>
            <div>
              <p className="kicker">{revCopy.kicker}</p>
              <h2 id="reviews-title" className="display display-lg">
                {revCopy.title}
              </h2>
            </div>
            {settings.googleRating && (
              <div className="rating-line">
                <span className="stars" aria-hidden="true">
                  ★★★★★
                </span>
                {settings.googleRating} on Google · {settings.reviewCount} reviews
              </div>
            )}
          </div>
          <div className="reviews-rows">
            {[rowA, rowB].map((row, ri) => (
              <div className="reviews-row" key={ri}>
                <div className={`reviews-track${ri === 1 ? " reverse" : ""}`}>
                  {[...row, ...row].map((r, i) => (
                    <figure key={`${r.id}-${i}`} className="review" aria-hidden={i >= row.length}>
                      <span className="stars" aria-label={`${r.rating} out of 5 stars`}>
                        {"★".repeat(Math.max(1, Math.min(5, r.rating)))}
                      </span>
                      <blockquote>{r.text}</blockquote>
                      <figcaption>
                        <span className="avatar">{initials(r.name)}</span>
                        <span style={{ display: "flex", flexDirection: "column" }}>
                          <span className="review-name">{r.name}</span>
                          <span className="review-meta">{r.meta}</span>
                        </span>
                      </figcaption>
                    </figure>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* ═════ GALLERY ═════ */}
      <section className="gallery-home" aria-labelledby="gallery-title">
        <div className="container events-head" style={{ marginBottom: 40 }}>
          <div data-reveal>
            <p className="kicker">{galCopy.kicker}</p>
            <h2 id="gallery-title" className="display display-md">
              {galCopy.title}
            </h2>
          </div>
          <div className="btn-row">
            <a href={settings.instagram} target="_blank" rel="noopener noreferrer" className="btn btn-outline btn-sm">
              <Icon name="instagram" size={16} /> {galCopy.instagramLabel}
            </a>
            <Link href="/gallery" className="btn btn-muted btn-sm">
              Full gallery
            </Link>
          </div>
        </div>
        <div className="gallery-grid-home">
          {tiles.map(({ slot, img }, i) => (
            <div key={i} className="gallery-tile-wrap" data-reveal style={{ gridColumn: slot[0], gridRow: slot[1], transitionDelay: `${(i % 5) * 0.05}s` }}>
              <div className="gallery-tile">
                <Img src={img.image} alt={img.alt || "Ammos Makenzy Beach"} sizes="(max-width: 900px) 33vw, 25vw" />
              </div>
            </div>
          ))}
          <div className="gallery-center" data-reveal style={{ transitionDelay: ".35s" }}>
            <h3 className="display display-md">
              <MultiLine text={galCopy.centerTitle} />
            </h3>
            <a href={settings.reservationUrl} target="_blank" rel="noopener noreferrer" className="btn btn-brand">
              {galCopy.buttonLabel}
            </a>
          </div>
        </div>
      </section>

      {/* ═════ CONTACT ═════ */}
      <section id="contact" className="contact-band" aria-labelledby="contact-title">
        <div className="bg">
          <Img src={contact.image} alt="" sizes="100vw" />
        </div>
        <div className="shade" />
        <div className="inner" data-reveal>
          <h2 id="contact-title" className="display">
            {contact.title}
          </h2>
          <ContactForm source="home" buttonLabel={contact.buttonLabel} />
        </div>
      </section>
    </>
  );
}
AMMOS_EOF
echo "  ✔ app/(site)/page.tsx"

mkdir -p "components/site"
cat > "components/site/Img.tsx" << 'AMMOS_EOF'
import Image from "next/image";
import { isExternal } from "@/lib/utils";

/**
 * Image that fills its (position: relative) parent.
 * Local images (/images, /uploads) are optimised by Next.js (WebP/AVIF, right size);
 * external links are shown as a normal <img>.
 */
export function Img({
  src,
  alt = "",
  sizes = "100vw",
  className = "",
  preload = false,
  quality,
  style,
}: {
  src?: string | null;
  alt?: string;
  sizes?: string;
  className?: string;
  preload?: boolean;
  quality?: 75 | 85;
  style?: React.CSSProperties;
}) {
  if (!src) return null;
  if (isExternal(src)) {
    // eslint-disable-next-line @next/next/no-img-element
    return <img src={src} alt={alt} className={`fill-img ${className}`} loading={preload ? "eager" : "lazy"} decoding="async" style={style} />;
  }
  return <Image src={src} alt={alt} fill sizes={sizes} quality={quality} className={`cover ${className}`} preload={preload} style={style} />;
}
AMMOS_EOF
echo "  ✔ components/site/Img.tsx"

mkdir -p "app/(site)/events"
cat > "app/(site)/events/page.tsx" << 'AMMOS_EOF'
import Link from "next/link";
import type { Metadata } from "next";
import { getContent } from "@/lib/content";
import { getEventCategories, listEvents } from "@/lib/data";
import { pageMeta } from "@/lib/seo";
import { PageHero } from "@/components/site/PageHero";
import { EventCard } from "@/components/site/EventCard";

export async function generateMetadata(): Promise<Metadata> {
  const h = await getContent("page.headers");
  return pageMeta({ title: "Events at Ammos — DJs, parties & live music in Larnaca", description: h.eventsText, path: "/events", image: h.eventsImage });
}

type Search = Promise<{ show?: string; category?: string }>;

export default async function EventsPage({ searchParams }: { searchParams: Search }) {
  const sp = await searchParams;
  const show = sp.show === "past" ? "past" : "upcoming";
  const category = typeof sp.category === "string" && sp.category ? sp.category.slice(0, 60) : undefined;
  const [h, events, categories, evCopy] = await Promise.all([getContent("page.headers"), listEvents({ show, category }), getEventCategories(), getContent("home.events")]);
  const variant = evCopy.cardStyle === "editorial" ? "editorial" : "overlay";

  const href = (s: string, c?: string) => {
    const q = new URLSearchParams();
    if (s === "past") q.set("show", "past");
    if (c) q.set("category", c);
    const qs = q.toString();
    return `/events${qs ? `?${qs}` : ""}`;
  };

  return (
    <>
      <PageHero kicker="What's on" title={h.eventsTitle} text={h.eventsText} image={h.eventsImage} crumbs={[{ name: "Events", path: "/events" }]}>
        <div className="btn-row" style={{ marginTop: 28 }}>
          <Link href="/events/calendar" className="btn btn-ghost-light btn-sm">
            Calendar view
          </Link>
        </div>
      </PageHero>

      <section className="section events-page" aria-label="Event list">
        <div className="container">
          <div className="filter-bar">
            <div className="group" role="group" aria-label="When">
              <Link href={href("upcoming", category)} className={`pill${show === "upcoming" ? " is-active" : ""}`} aria-current={show === "upcoming" ? "true" : undefined}>
                Upcoming events
              </Link>
              <Link href={href("past", category)} className={`pill${show === "past" ? " is-active" : ""}`} aria-current={show === "past" ? "true" : undefined}>
                Past events
              </Link>
            </div>
            {categories.length > 1 && (
              <div className="group" role="group" aria-label="Type of event">
                <Link href={href(show)} className={`pill${!category ? " is-active" : ""}`}>
                  All
                </Link>
                {categories.map((c) => (
                  <Link key={c} href={href(show, c)} className={`pill${category === c ? " is-active" : ""}`}>
                    {c}
                  </Link>
                ))}
              </div>
            )}
          </div>

          {events.length ? (
            <div className="events-grid">
              {events.map((e) => (
                <EventCard key={e.id} event={e} past={show === "past"} showBadge variant={variant} />
              ))}
            </div>
          ) : (
            <div className="empty-state">
              <h2 className="display">{show === "past" ? "No past events yet" : "New dates coming soon"}</h2>
              <p>
                {show === "past" ? "Check our upcoming events instead." : "Follow us on Instagram to be the first to know, or "}
                {show !== "past" && <Link href="/contact" style={{ color: "var(--teal)" }}>ask us about private events</Link>}.
              </p>
            </div>
          )}
        </div>
      </section>
    </>
  );
}
AMMOS_EOF
echo "  ✔ app/(site)/events/page.tsx"

mkdir -p "app/(site)/events/[slug]"
cat > "app/(site)/events/[slug]/page.tsx" << 'AMMOS_EOF'
import Link from "next/link";
import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { getContent, getSettings } from "@/lib/content";
import { getBookedGuests, getEventBySlug, getOtherUpcomingEvents } from "@/lib/data";
import { eventJsonLd, pageMeta } from "@/lib/seo";
import { eventDateParts, formatDate, isEventOver, truncate } from "@/lib/utils";
import { PageHero } from "@/components/site/PageHero";
import { RichText } from "@/components/site/RichText";
import { BookingForm } from "@/components/site/BookingForm";
import { EventCard } from "@/components/site/EventCard";
import { JsonLd } from "@/components/site/JsonLd";
import { EventPhotos } from "@/components/site/EventPhotos";

export const revalidate = 300;
export const dynamicParams = true;
export function generateStaticParams() {
  return []; // pages are built on first visit, then cached
}

type Params = Promise<{ slug: string }>;

export async function generateMetadata({ params }: { params: Params }): Promise<Metadata> {
  const { slug } = await params;
  const e = await getEventBySlug(slug);
  if (!e) return { title: "Event not found", robots: { index: false } };
  const d = eventDateParts(e.startsAt);
  return pageMeta({
    title: `${e.title} — ${d.weekday} ${d.dayNum} ${d.monthLong} ${d.year}`,
    description: truncate(e.summary || e.description, 160) || `${e.category} at Ammos Makenzy Beach, Larnaca.`,
    path: `/events/${e.slug}`,
    image: e.image,
  });
}

export default async function EventPage({ params }: { params: Params }) {
  const { slug } = await params;
  const event = await getEventBySlug(slug);
  if (!event) notFound();

  const [settings, booked, others, evCopy] = await Promise.all([getSettings(), getBookedGuests(event.id), getOtherUpcomingEvents(event.id, 3), getContent("home.events")]);
  const d = eventDateParts(event.startsAt);
  const isPast = isEventOver(event.startsAt);
  const left = event.capacity ? Math.max(0, event.capacity - booked) : null;
  const canBook = !isPast && event.bookingEnabled && (left === null || left > 0);
  // event photos from the admin; if none were added, show the main photo so the page never looks empty
  const photos = (Array.isArray(event.gallery) ? event.gallery : []).filter(Boolean);
  const gallery = photos.length ? photos : event.image ? [event.image] : [];

  return (
    <>
      <PageHero
        kicker={isPast ? `Event passed · ${event.category}` : `${event.category} · ${event.venue}`}
        title={event.title}
        text={event.summary}
        image={event.image}
        crumbs={[
          { name: "Events", path: "/events" },
          { name: event.title, path: `/events/${event.slug}` },
        ]}
      >
        <div className="btn-row" style={{ marginTop: 28 }}>
          {canBook && (
            <a href="#book" className="btn btn-brand">
              Book this event
            </a>
          )}
          <a href={settings.reservationUrl} target="_blank" rel="noopener noreferrer" className="btn btn-ghost-light">
            Reserve a table
          </a>
        </div>
      </PageHero>

      <section className="section">
        <div className="container event-detail-grid">
          <div>
            <dl className="event-facts" style={{ marginTop: 0 }}>
              <div>
                <dt>Date</dt>
                <dd>
                  <time dateTime={event.startsAt.toISOString()}>
                    {d.weekday}, {d.dayNum} {d.month} {d.year}
                  </time>
                </dd>
              </div>
              <div>
                <dt>Time</dt>
                <dd>
                  {d.time}
                  {event.endsAt ? ` – ${eventDateParts(event.endsAt).time}` : ""}
                </dd>
              </div>
              <div>
                <dt>Where</dt>
                <dd>{event.venue}</dd>
              </div>
              {event.priceInfo && (
                <div>
                  <dt>Entry</dt>
                  <dd>{event.priceInfo}</dd>
                </div>
              )}
            </dl>
            <RichText text={event.description} />
            <p className="muted" style={{ marginTop: 32, fontSize: 14 }}>
              Ammos Makenzy Beach · {settings.address}, {settings.city} · <a href={`tel:${settings.phone.replace(/\s/g, "")}`}>{settings.phone}</a>
            </p>
            {gallery.length > 0 && (
              <div className="event-photos-wrap">
                <p className="kicker kicker-teal">{isPast ? "From the night" : "The vibe"}</p>
                <EventPhotos photos={gallery} title={event.title} />
              </div>
            )}
          </div>

          <aside id="book" className="booking-panel form-card" style={{ scrollMarginTop: 100 }}>
            {isPast ? (
              <>
                <span className="past-flag past-flag-inline">Event passed</span>
                <h2 className="display">Bookings are closed</h2>
                <p className="lead" style={{ marginTop: 10 }}>
                  This event took place on {formatDate(event.startsAt)}, so we no longer take bookings for it. Have a look at what's coming up next, or reserve a table for another day.
                </p>
                <div className="btn-row" style={{ marginTop: 20 }}>
                  <Link href="/events" className="btn btn-outline">
                    Upcoming events
                  </Link>
                  <a href={settings.reservationUrl} target="_blank" rel="noopener noreferrer" className="btn btn-muted">
                    Reserve a table
                  </a>
                </div>
              </>
            ) : canBook ? (
              <>
                <h2 className="display">Book your spot</h2>
                {left !== null && left <= 30 && <p className="spots">Only {left} places left</p>}
                {left === null || left > 30 ? <p className="form-note" style={{ marginBottom: 20 }}>Fill in your details and we'll confirm your table.</p> : null}
                <BookingForm eventId={event.id} eventTitle={event.title} maxGuests={left ?? 30} startsAt={event.startsAt.toISOString()} />
              </>
            ) : (
              <>
                <h2 className="display">{left === 0 ? "Fully booked" : "Booking by phone"}</h2>
                <p className="lead" style={{ marginTop: 10 }}>
                  {left === 0 ? "This night is fully booked online. Call us to join the waiting list." : "Call or message us to reserve for this event."}
                </p>
                <div className="btn-row" style={{ marginTop: 20 }}>
                  <a href={`tel:${settings.phone.replace(/\s/g, "")}`} className="btn btn-brand">
                    Call {settings.phone}
                  </a>
                </div>
              </>
            )}
          </aside>
        </div>
      </section>

      {others.length > 0 && (
        <section className="section events-page">
          <div className="container">
            <p className="kicker kicker-teal">More nights</p>
            <h2 className="display display-md" style={{ color: "var(--ink)", marginBottom: 40 }}>
              also coming up
            </h2>
            <div className="events-grid">
              {others.map((e) => (
                <EventCard key={e.id} event={e} showBadge variant={evCopy.cardStyle === "editorial" ? "editorial" : "overlay"} />
              ))}
            </div>
          </div>
        </section>
      )}
      <JsonLd data={eventJsonLd(event, settings)} />
    </>
  );
}
AMMOS_EOF
echo "  ✔ app/(site)/events/[slug]/page.tsx"

mkdir -p "components/site"
cat > "components/site/EventCard.tsx" << 'AMMOS_EOF'
import Link from "next/link";
import { Img } from "@/components/site/Img";
import { eventDateParts, isEventOver } from "@/lib/utils";
import type { Event } from "@/lib/db/schema";

type Props = { event: Event; past?: boolean; showBadge?: boolean; variant?: "editorial" | "overlay" };

/**
 * Event card. Two looks (Admin → Page content → Upcoming events block → Event card style):
 *  - "overlay": text on the photo, date badge, arrow button
 *  - "editorial": photo with the date line, title and link underneath
 * Once the start time has passed it shows an "Event passed" tag and no booking link.
 */
export function EventCard({ event, past = false, showBadge = false, variant = "editorial" }: Props) {
  const d = eventDateParts(event.startsAt);
  const href = `/events/${event.slug}`;
  const over = past || isEventOver(event.startsAt);

  if (variant === "overlay") {
    return (
      <article className={`event-ov${over ? " is-over" : ""}`}>
        <Link href={href} className="event-ov-link" aria-label={`${event.title} — ${d.weekday} ${d.dayNum} ${d.month}${over ? " (event passed)" : ""}`}>
          <Img src={event.image} alt={event.title} sizes="(max-width: 600px) 80vw, 340px" />
          <span className="event-ov-shade" />
          <span className="event-ov-date" aria-hidden="true">
            <b>{d.dayNum}</b>
            <span>{d.month}</span>
          </span>
          {over && <span className="past-flag">Event passed</span>}
          <span className="event-ov-body">
            <span className="event-ov-tag">
              {event.category} · {event.venue}
            </span>
            <span className="event-ov-title">{event.title}</span>
            <span className="event-ov-foot">
              <time dateTime={new Date(event.startsAt).toISOString()}>
                {d.weekday}, {d.month} {d.dayNum}
                {over ? ` ${d.year}` : ` · ${d.time}`}
              </time>
              <span className="event-ov-arrow" aria-hidden="true">
                →
              </span>
            </span>
          </span>
        </Link>
      </article>
    );
  }

  return (
    <article className={`event-card${over ? " is-over" : ""}`}>
      <Link href={href} className="event-card-media" aria-label={event.title} tabIndex={-1}>
        <Img src={event.image} alt={event.title} sizes="(max-width: 600px) 80vw, 340px" />
        {showBadge && (
          <span className="event-badge" aria-hidden="true">
            <b>{d.dayNum}</b>
            <span>{d.month}</span>
          </span>
        )}
        {over && <span className="past-flag">Event passed</span>}
      </Link>
      <div className="event-card-meta">
        <time dateTime={new Date(event.startsAt).toISOString()}>
          {d.weekday}, {d.month} {d.dayNum}
          {past ? ` ${d.year}` : ""}
        </time>
        <span className="tag">{event.category}</span>
      </div>
      <h3 className="display">
        <Link href={href}>{event.title}</Link>
      </h3>
      <span className="where">
        {event.venue} · {over ? "was" : "from"} {d.time}
      </span>
      <Link href={over ? href : `${href}#book`} className="link-underline">
        {over ? "See the night" : event.bookingEnabled ? "Reserve a table" : "Event details"}
      </Link>
    </article>
  );
}
AMMOS_EOF
echo "  ✔ components/site/EventCard.tsx"

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

/* ════════════ UPDATE 5 — mobile polish ════════════ */
.menu-after-bottom { display: none; }
@media (max-width: 900px) {
  /* menu block: button under the dishes */
  .menu-after-top { display: none; }
  .menu-after-bottom { display: flex; flex-direction: column; align-items: center; text-align: center; margin-top: 36px; }
  .menu-home-intro .pill-tabs { margin-bottom: 8px; }

  /* story: hide the fanned photo cards on phones */
  .fan { display: none; }

  /* homepage gallery: tidy bento grid with side margins */
  .gallery-grid-home {
    width: auto; margin: 12px var(--gutter) 0; padding: 0;
    grid-template-columns: repeat(2, minmax(0, 1fr)); grid-auto-rows: 44vw; gap: 10px;
  }
  .gallery-grid-home .gallery-tile-wrap:nth-child(3n + 1) { grid-column: 1 / -1 !important; }
  .gallery-grid-home .gallery-tile-wrap:nth-child(n + 8) { display: none; }
  .gallery-grid-home .gallery-tile { border-radius: 14px; }
  .gallery-center { padding: 8px 0 28px; gap: 22px; }
  .gallery-center h3 { font-size: clamp(30px, 9vw, 40px); }
  .gallery-home .events-head { flex-direction: column; align-items: flex-start; gap: 20px; }
}
@media (min-width: 601px) and (max-width: 900px) {
  .gallery-grid-home { grid-template-columns: repeat(3, minmax(0, 1fr)); grid-auto-rows: 30vw; }
  .gallery-grid-home .gallery-tile-wrap:nth-child(3n + 1) { grid-column: auto !important; }
  .gallery-grid-home .gallery-tile-wrap:nth-child(n + 7) { display: none; }
}

/* ════════════ UPDATE 7 — hero slideshow, overlay event cards, bulk admin ════════════ */
.hero-slides { position: absolute; inset: 0; overflow: hidden; }
.hero-slide { position: absolute; inset: 0; opacity: 0; transition: opacity 1.8s ease; }
.hero-slide.is-active { opacity: 1; }
.hero-slide img { transform: scale(1.08); transition: transform 9s linear; will-change: transform; }
.hero-slide.is-active img { transform: scale(1); }
.hero-dots { position: absolute; z-index: 3; left: 50%; bottom: 26px; transform: translateX(-50%); display: flex; gap: 8px; }
.hero-dots span { width: 7px; height: 7px; border-radius: 99px; background: rgba(255, 255, 255, 0.4); transition: width 0.4s var(--ease-out), background 0.4s; }
.hero-dots span.is-active { width: 24px; background: var(--brand); }
@media (prefers-reduced-motion: reduce) { .hero-slide img { transform: none !important; transition: none; } }

/* overlay event card */
.event-ov { position: relative; }
.event-ov-link { position: relative; display: flex; flex-direction: column; justify-content: flex-end; aspect-ratio: 3 / 4; border-radius: 16px; overflow: hidden; background: var(--ink); color: #fff; isolation: isolate; box-shadow: 0 10px 22px rgba(15, 17, 25, 0.14); }
.event-ov-link img { transition: transform 0.9s var(--ease-out); }
.event-ov-link:hover img { transform: scale(1.06); }
.event-ov-shade { position: absolute; inset: 0; z-index: 0; background: linear-gradient(180deg, rgba(15, 17, 25, 0.05) 30%, rgba(15, 17, 25, 0.55) 58%, rgba(15, 17, 25, 0.92) 100%); }
.event-ov-date { position: absolute; z-index: 1; top: 16px; left: 16px; min-width: 50px; padding: 8px 8px 6px; border-radius: 10px; background: #fff; color: var(--ink); display: flex; flex-direction: column; align-items: center; line-height: 1; box-shadow: 0 6px 18px rgba(0, 0, 0, 0.18); }
.event-ov-date b { font-family: var(--display); font-weight: 400; font-size: 24px; }
.event-ov-date span { margin-top: 5px; font-size: 10px; font-weight: 600; letter-spacing: 0.18em; text-transform: uppercase; }
.event-ov .past-flag { z-index: 1; }
.event-ov-body { position: relative; z-index: 1; display: flex; flex-direction: column; gap: 10px; padding: 22px; }
.event-ov-tag { font-size: 11px; font-weight: 600; letter-spacing: 0.22em; text-transform: uppercase; color: var(--lime); }
.event-ov-title { font-family: var(--display); text-transform: uppercase; letter-spacing: 0.03em; font-size: clamp(21px, 1.8vw, 25px); line-height: 1.12; color: #fff; }
.event-ov-foot { display: flex; align-items: center; justify-content: space-between; gap: 12px; margin-top: 6px; font-size: 13px; color: rgba(255, 255, 255, 0.82); }
.event-ov-arrow { flex: none; width: 42px; height: 42px; border-radius: 50%; background: var(--brand); color: var(--ink); display: flex; align-items: center; justify-content: center; font-size: 18px; transition: transform 0.35s var(--ease-out); }
.event-ov-link:hover .event-ov-arrow { transform: translateX(4px); }
.event-ov.is-over img { filter: grayscale(0.55) brightness(0.8); }
.event-ov.is-over .event-ov-arrow { background: rgba(255, 255, 255, 0.85); }
.events-grid .event-ov-link { aspect-ratio: 4 / 5; }
.events-track:has(.event-ov) { gap: 24px; grid-auto-columns: minmax(250px, 290px); }
@media (max-width: 600px) { .events-track:has(.event-ov) { grid-auto-columns: 74vw; gap: 16px; } }
/* lighter, directional shade so the hero photos stay vivid (text side stays readable) */
.hero:has(.hero-slides) .hero-shade {
  background:
    linear-gradient(90deg, rgba(10, 12, 18, 0.7) 0%, rgba(10, 12, 18, 0.38) 28%, rgba(10, 12, 18, 0.06) 50%, rgba(10, 12, 18, 0) 60%),
    linear-gradient(180deg, rgba(10, 12, 18, 0.55) 0%, rgba(10, 12, 18, 0) 22%, rgba(10, 12, 18, 0) 70%, rgba(10, 12, 18, 0.6) 100%);
}
.hero:has(.hero-slides) h1, .hero:has(.hero-slides) .hero-sub { text-shadow: 0 2px 24px rgba(0, 0, 0, 0.35); }
@media (max-width: 900px) {
  .hero:has(.hero-slides) .hero-shade { background: linear-gradient(180deg, rgba(10, 12, 18, 0.6) 0%, rgba(10, 12, 18, 0.35) 35%, rgba(10, 12, 18, 0.55) 70%, rgba(10, 12, 18, 0.85) 100%); }
}
/* let the overlay cards' shadow show */
.events-track:has(.event-ov) { padding-bottom: 36px; margin-bottom: -20px; }
AMMOS_EOF
echo "  ✔ app/globals.css"

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
AMMOS_EOF
echo "  ✔ lib/db/schema.ts"

mkdir -p "drizzle"
cat > "drizzle/0005_user_notify_dish_photos.sql" << 'AMMOS_EOF'
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
AMMOS_EOF
echo "  ✔ drizzle/0005_user_notify_dish_photos.sql"

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
    },
    {
      "idx": 3,
      "version": "7",
      "when": 1792063739128,
      "tag": "0003_home_menu_no_cocktails",
      "breakpoints": true
    },
    {
      "idx": 4,
      "version": "7",
      "when": 1792064211960,
      "tag": "0004_instagram_event_photos",
      "breakpoints": true
    },
    {
      "idx": 5,
      "version": "7",
      "when": 1792064731722,
      "tag": "0005_user_notify_dish_photos",
      "breakpoints": true
    }
  ]
}
AMMOS_EOF
echo "  ✔ drizzle/meta/_journal.json"

mkdir -p "drizzle/meta"
cat > "drizzle/meta/0005_snapshot.json" << 'AMMOS_EOF'
{
  "id": "7524dd7d-f2ba-45c6-9cb1-8a5096e51065",
  "prevId": "c4a6fec4-d919-40f8-a116-27f47b83d980",
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
        "notify": {
          "name": "notify",
          "type": "boolean",
          "primaryKey": false,
          "notNull": true,
          "default": true
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
echo "  ✔ drizzle/meta/0005_snapshot.json"

mkdir -p "scripts"
cat > "scripts/seed.ts" << 'AMMOS_EOF'
/**
 * Fills an empty database with the starting content:
 *  - first admin account (from ADMIN_EMAIL / ADMIN_PASSWORD in .env)
 *  - the full Ammos menu (scripts/seed-data/menu.md)
 *  - example events, news, reviews, gallery photos, and the /ourmenu redirect
 *
 * Run:  npm run db:seed
 * Safe to run again: each part is only added if that table is still empty.
 */
import { readFileSync } from "node:fs";
import { join } from "node:path";
import bcrypt from "bcryptjs";
import { eq, inArray } from "drizzle-orm";
import { fetchLiveMenu, parseMenu, syncMenu } from "../lib/menu-import";
import { db, pool, schema } from "./db";

const slug = (s: string) =>
  s
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

/* ───────── helpers for dates in Cyprus time ───────── */
function cyprusDate(daysFromToday: number, hh: number, mm = 0) {
  const now = new Date();
  const local = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + daysFromToday, hh, mm));
  // Cyprus is UTC+2 in winter, UTC+3 in summer — work out the real offset for that day
  const fmt = new Intl.DateTimeFormat("en-US", { timeZone: "Europe/Nicosia", hour: "2-digit", hourCycle: "h23" });
  const offset = Number(fmt.format(local)) - hh;
  return new Date(local.getTime() - ((offset + 24) % 24) * 3600_000);
}
function nextWeekday(target: number, minDays = 1) {
  const today = new Date().getUTCDay();
  let d = (target - today + 7) % 7;
  if (d < minDays) d += 7;
  return d;
}

async function seedAdmin() {
  if ((await db.$count(schema.adminUsers)) > 0) return console.log("• Admin users exist — skipped");
  const email = (process.env.ADMIN_EMAIL || "").trim().toLowerCase();
  const password = process.env.ADMIN_PASSWORD || "";
  if (!email || password.length < 12) {
    console.log("! ADMIN_EMAIL / ADMIN_PASSWORD (12+ chars) not set in .env — run `npm run admin:create` later.");
    return;
  }
  await db.insert(schema.adminUsers).values({
    email,
    name: process.env.ADMIN_NAME || "Ammos Admin",
    passwordHash: await bcrypt.hash(password, 12),
    role: "owner",
  });
  console.log(`✔ Admin created: ${email}  (change the password after your first login)`);
}

/* ───────── menu ───────── */
// dishes shown in the homepage menu block (you can change these in Admin → Menu items → "Show on homepage")
const FEATURED = [
  "Salmon Tiratido", "Mussels Nero", "Tataki Tuna", "Oktapodi Kythira",
  "Seabass Fricassee", "Seaside Orzotto", "Rib Eye Uruguay Angus", "Pyraclea Chicken",
  "Ammos Roll", "Caldera Roll", "Peruvian Rainbow Roll", "Geisha Sashimi Mix",
];

// real Ammos dish photos (from Instagram) shown when hovering the dish in the homepage menu block
const DISH_PHOTOS: Record<string, string> = {
  "Salmon Tiratido": "/images/ig/dish-salmon-tiratido.webp",
  "Mussels Nero": "/images/ig/dish-mussels-nero.webp",
  "Tataki Tuna": "/images/ig/dish-tataki-tuna.webp",
  "Oktapodi Kythira": "/images/ig/dish-oktapodi-kythira.webp",
  "Seabass Fricassee": "/images/ig/dish-seabass.webp",
  "Seaside Orzotto": "/images/ig/dish-seaside-orzotto.webp",
  "Rib Eye Uruguay Angus": "/images/ig/dish-rib-eye.webp",
  "Ammos Roll": "/images/ig/dish-ammos-roll.webp",
  "Caldera Roll": "/images/ig/dish-caldera-roll.webp",
  "Peruvian Rainbow Roll": "/images/ig/dish-rainbow-roll.webp",
  "Geisha Sashimi Mix": "/images/ig/dish-geisha-sashimi.webp",
};

async function seedMenu() {
  if ((await db.$count(schema.menuCategories)) > 0) return console.log("• Menu exists — skipped (run `npm run menu:sync` to update it)");
  let md: string;
  try {
    md = await fetchLiveMenu();
    console.log("• Live menu downloaded from ammos-beach-bar.nina.cy");
  } catch (err) {
    console.log(`! Live menu not reachable (${(err as Error).message}) — using scripts/seed-data/menu.md`);
    md = readFileSync(join(process.cwd(), "scripts/seed-data/menu.md"), "utf8");
  }
  const r = await syncMenu(db, parseMenu(md));
  await db.update(schema.menuItems).set({ featured: true }).where(inArray(schema.menuItems.name, FEATURED));
  for (const [name, image] of Object.entries(DISH_PHOTOS)) await db.update(schema.menuItems).set({ image }).where(eq(schema.menuItems.name, name));
  console.log(`✔ Menu imported: ${r.categories} categories, ${r.total} items`);
}

/* ───────── events ───────── */
const SAMPLE_GALLERY = ["/images/ig/event-night-party.webp", "/images/ig/event-dj-crowd.webp", "/images/ig/event-hug.webp", "/images/ig/story-2015-friends.webp", "/images/ig/fan-aperol.webp", "/images/ig/story-2026-terrace.webp"];
async function seedEvents() {
  if ((await db.$count(schema.events)) > 0) return console.log("• Events exist — skipped");
  const fri = nextWeekday(5);
  const upcoming = [
    { title: "Sunset sessions w/ Nikos K", category: "Live DJ", venue: "Terrace", day: fri, h: 19, image: "/images/ig/event-sunset.webp", price: "Free entry", cap: 180,
      summary: "Golden-hour house and disco on the terrace as the sun drops into the bay.",
      description: "Our resident Nikos K takes over the decks from sunset until late with a set of deep house, nu-disco and Balearic grooves.\n\nArrive early for the best seats on the terrace and the first round of signature cocktails.\n\n## Good to know\n- Smart-casual dress code after 20:00\n- Tables for 4+ are best booked in advance" },
    { title: "Full moon beach party", category: "Party", venue: "Beach", day: fri + 1, h: 21, image: "/images/ig/event-night-party.webp", price: "€15 entry incl. welcome drink", cap: 400,
      summary: "Barefoot on the sand under the full moon — fire shows, guest DJs and the bar open till late.",
      description: "Once a month we light up the beach for our full moon party.\n\nExpect guest DJs, fire performers and a beach bar serving our signature cocktails until the early hours.\n\n## Good to know\n- 18+ only, ID may be requested\n- Entry includes one welcome drink" },
    { title: "Long table Sunday brunch", category: "Dining", venue: "Restaurant", day: fri + 2, h: 11, m: 30, image: "/images/ig/event-brunch.webp", price: "€35 per person", cap: 60,
      summary: "One long table, sharing plates, bottomless coffee and a live acoustic duo.",
      description: "Our Sunday ritual: a long table set by the sea, sharing plates from the kitchen, fresh juices and a live acoustic duo.\n\nVegetarian and vegan options available — tell us about allergies in your booking." },
    { title: "Acoustic nights: Elena & band", category: "Live music", venue: "Terrace", day: fri + 6, h: 20, image: "/images/ig/event-terrace-night.webp", price: "Free entry", cap: 150,
      summary: "Elena and her band play soul, bossa and Greek classics under the stars.",
      description: "An easy evening of live soul, bossa nova and Greek classics. Book a table for dinner and stay for the music." },
    { title: "Cypriot wine & meze evening", category: "Tasting", venue: "Bar", day: fri + 7, h: 19, m: 30, image: "/images/ig/event-wine-steak.webp", price: "€45 per person", cap: 40,
      summary: "Five Cypriot wines paired with five meze plates, hosted by our sommelier.",
      description: "Discover the island's best producers — Kyperounda, Zambartas and more — paired with five meze plates from our kitchen.\n\nLimited to 40 guests." },
    { title: "Ammos summer closing party", category: "Live DJ", venue: "Terrace", day: fri + 8, h: 21, image: "/images/ig/event-dj-crowd.webp", price: "Free entry", cap: 400,
      summary: "Our resident DJs close the season in style.",
      description: "Join us to celebrate another unforgettable summer on Makenzy Beach with our resident DJs and special guests." },
  ];
  const past = [
    { title: "Charity dinner 2021", category: "Community", venue: "Restaurant", at: "2021-11-20T18:00:00Z", image: "/images/news-1.jpg", summary: "A night of giving back on the strip, with every cover donated.", description: "A night of giving back on the strip, with every cover donated to local charities." },
    { title: "New Year's Eve 2022", category: "Party", venue: "Terrace", at: "2021-12-31T20:00:00Z", image: "/images/news-2.jpg", summary: "Counting down with 400 of our closest friends on the terrace.", description: "Counting down with 400 of our closest friends on the terrace." },
    { title: "Ammos veterans reunion", category: "Party", venue: "Bar", at: "2021-08-14T18:00:00Z", image: "/images/news-3.jpg", summary: "Eight years of regulars, back in one room for one long night.", description: "Eight years of regulars, back in one room for one long night." },
  ];
  await db.insert(schema.events).values([
    ...upcoming.map((e) => ({
      title: e.title,
      slug: slug(e.title),
      category: e.category,
      venue: e.venue,
      startsAt: cyprusDate(e.day, e.h, e.m ?? 0),
      summary: e.summary,
      description: e.description,
      image: e.image,
      gallery: SAMPLE_GALLERY.filter((g) => g !== e.image).slice(0, 5),
      priceInfo: e.price,
      capacity: e.cap,
      featured: true,
    })),
    ...past.map((e) => ({
      title: e.title,
      slug: slug(e.title),
      category: e.category,
      venue: e.venue,
      startsAt: new Date(e.at),
      summary: e.summary,
      description: e.description,
      image: e.image,
      bookingEnabled: false,
      featured: false,
    })),
  ]);
  console.log(`✔ Events added: ${upcoming.length} upcoming, ${past.length} past (edit or delete them in Admin → Events)`);
}

async function seedPosts() {
  if ((await db.$count(schema.posts)) > 0) return console.log("• News exists — skipped");
  const posts = [
    { title: "Charity dinner 2021", kicker: "Community", image: "/images/news-1.jpg", date: "2021-11-20", excerpt: "A night of giving back on the strip, with every cover donated.",
      content: "In November we opened our doors for a very special evening: every cover from our charity dinner went straight to local causes in Larnaca.\n\nThank you to everyone who joined us, to our team who gave their time, and to the partners who made it possible.\n\n## What we raised\nTogether we raised funds for children's charities in the Larnaca district — and had a beautiful night doing it." },
    { title: "NYE 2022", kicker: "Party", image: "/images/news-2.jpg", date: "2022-01-01", excerpt: "Counting down with 400 of our closest friends on the terrace.",
      content: "What a way to welcome the new year! 400 friends, a packed terrace, fireworks over the bay and our DJs playing until sunrise.\n\nSee you this year — keep an eye on our **events page** for New Year's Eve tickets." },
    { title: "Ammos veterans reunion", kicker: "Reunion", image: "/images/news-3.jpg", date: "2021-08-14", excerpt: "Eight years of regulars, back in one room for one long night.",
      content: "Some of you have been with us since the very first summer. This August we brought our regulars — and former team members — back together for one long night of stories, music and plenty of cocktails.\n\nHere's to the next twenty years on the strip." },
  ];
  await db.insert(schema.posts).values(
    posts.map((p) => ({ title: p.title, slug: slug(p.title), kicker: p.kicker, image: p.image, excerpt: p.excerpt, content: p.content, publishedAt: new Date(`${p.date}T12:00:00Z`) })),
  );
  console.log(`✔ News added: ${posts.length} stories`);
}

async function seedReviews() {
  if ((await db.$count(schema.reviews)) > 0) return console.log("• Reviews exist — skipped");
  const reviews = [
    { name: "Maria P.", meta: "Google · Larnaca", text: "Best spot on the Makenzy strip. The octopus is unreal and the sunset from the terrace is worth the trip alone." },
    { name: "James R.", meta: "Google · London", text: "Came for brunch, stayed for the DJ. Staff know the menu inside out and genuinely care. We came back three nights in a row." },
    { name: "Andreas C.", meta: "Google · Nicosia", text: "Booked a birthday table for 12. Everything was handled, the food came out together and the cocktails kept coming." },
    { name: "Sofia K.", meta: "Google · Limassol", text: "Sunbeds in the morning, lunch by the water, cocktails at sunset. You never need to leave." },
    { name: "Daniel W.", meta: "Google · Berlin", text: "The Ammos Star cocktail alone is worth the flight. Great music, zero attitude, lovely people." },
    { name: "Elena M.", meta: "Google · Athens", text: "Twenty-one years and still the best beach bar in Larnaca. The new look is gorgeous." },
  ];
  await db.insert(schema.reviews).values(reviews.map((r, i) => ({ ...r, sortOrder: (i + 1) * 10 })));
  console.log(`✔ Reviews added: ${reviews.length} (replace them with your real Google reviews in Admin → Reviews)`);
}

async function seedGallery() {
  if ((await db.$count(schema.galleryImages)) > 0) return console.log("• Gallery exists — skipped");
  const imgs = [
    ["bar-interior", "The Ammos bar", "The Bar"],
    ["bartender", "Cocktails being made at the bar", "The Bar"],
    ["party", "Party night at Ammos", "Events"],
    ["chef-plate", "Signature dish from the Ammos kitchen", "Food"],
    ["flowers", "Table details at Ammos", "The Beach"],
    ["awards-interior", "Inside Ammos Makenzy Beach", "The Beach"],
    ["hero-kitchen", "The Ammos kitchen", "Food"],
    ["news-1", "Charity dinner at Ammos", "Events"],
    ["news-2", "New Year's Eve at Ammos", "Events"],
    ["news-3", "Ammos veterans reunion", "Events"],
  ];
  await db.insert(schema.galleryImages).values(imgs.map(([f, alt, album], i) => ({ image: `/images/${f}.jpg`, alt, album, sortOrder: (i + 1) * 10 })));
  console.log(`✔ Gallery added: ${imgs.length} photos`);
}

async function seedRedirects() {
  if ((await db.$count(schema.redirects)) > 0) return console.log("• Redirects exist — skipped");
  await db.insert(schema.redirects).values([
    { fromPath: "/ourmenu", toPath: "/menu" },
    { fromPath: "/our-menu", toPath: "/menu" },
    { fromPath: "/food-menu", toPath: "/menu" },
    { fromPath: "/about", toPath: "/our-story" },
    { fromPath: "/about-us", toPath: "/our-story" },
    { fromPath: "/book", toPath: "/events" },
  ]);
  console.log("✔ Redirects added (e.g. ammos.eu/ourmenu → /menu)");
}

async function main() {
  console.log("→ Seeding database…");
  await seedAdmin();
  await seedMenu();
  await seedEvents();
  await seedPosts();
  await seedReviews();
  await seedGallery();
  await seedRedirects();
  console.log("✔ Done.");
}

main()
  .catch((err) => {
    console.error("✖ Seed failed:", err);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
AMMOS_EOF
echo "  ✔ scripts/seed.ts"

mkdir -p "lib"
cat > "lib/mailer.ts" << 'AMMOS_EOF'
import "server-only";
import nodemailer, { type Transporter } from "nodemailer";
import { eq } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { siteUrl } from "@/lib/utils";

/**
 * Sends email through your SMTP account (e.g. Hostinger email for info@ammos.eu).
 * If SMTP_HOST is empty (local testing), emails are printed in the terminal instead.
 */

let transporter: Transporter | null = null;
function getTransporter() {
  if (!process.env.SMTP_HOST) return null;
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT || 465),
      secure: String(process.env.SMTP_SECURE ?? "true") !== "false",
      auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
    });
  }
  return transporter;
}

function envRecipients() {
  return (process.env.MAIL_TO || "info@ammos.eu")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

/**
 * Who gets "new booking" / "new message" emails:
 * MAIL_TO from .env + every admin user with "Email notifications" switched on (Admin → My account & users).
 */
export async function adminRecipients(): Promise<string[]> {
  const list = new Set(envRecipients().map((e) => e.toLowerCase()));
  try {
    const users = await db.select({ email: schema.adminUsers.email }).from(schema.adminUsers).where(eq(schema.adminUsers.notify, true));
    for (const u of users) if (u.email) list.add(u.email.toLowerCase());
  } catch (err) {
    console.error("[email] could not load admin users for notifications", err);
  }
  return Array.from(list);
}

type Mail = { to: string | string[]; subject: string; html: string; text: string; replyTo?: string };

export async function sendMail(mail: Mail): Promise<boolean> {
  const t = getTransporter();
  const from = process.env.MAIL_FROM || "Ammos Makenzy Beach <info@ammos.eu>";
  if (!t) {
    console.log(`\n[email — SMTP not configured, not sent]\nTo: ${mail.to}\nSubject: ${mail.subject}\n${mail.text}\n`);
    return false;
  }
  try {
    await t.sendMail({ from, ...mail });
    return true;
  } catch (err) {
    console.error("[email] failed to send:", err);
    return false;
  }
}

/** What the admin dashboard shows about email (no passwords). */
export async function mailStatus() {
  return {
    configured: Boolean(process.env.SMTP_HOST),
    host: process.env.SMTP_HOST || "",
    user: process.env.SMTP_USER || "",
    from: process.env.MAIL_FROM || "Ammos Makenzy Beach <info@ammos.eu>",
    to: await adminRecipients(),
  };
}

/** Checks the SMTP login and sends a test email. Returns the real error so the admin can fix settings. */
export async function sendTestMail(to: string[]): Promise<{ ok: boolean; error?: string }> {
  const t = getTransporter();
  if (!t) return { ok: false, error: "Email is not set up yet: SMTP_HOST is empty in the .env file." };
  try {
    await t.verify();
    await t.sendMail({
      from: process.env.MAIL_FROM || "Ammos Makenzy Beach <info@ammos.eu>",
      to,
      subject: "Test email from the Ammos website",
      text: "It works! Booking and contact form emails from ammos.eu will arrive like this one.",
      html: emailLayout("It works!", paragraph("Booking and contact form emails from the website will arrive like this one.")),
    });
    return { ok: true };
  } catch (err) {
    const e = err as { code?: string; response?: string; message?: string };
    const hint =
      e.code === "EAUTH"
        ? "Login failed — check SMTP_USER and SMTP_PASS (for Gmail use an App Password)."
        : e.code === "ESOCKET" || e.code === "ECONNECTION" || e.code === "ETIMEDOUT"
          ? "Could not connect — check SMTP_HOST, SMTP_PORT and SMTP_SECURE (465 = true, 587 = false)."
          : "";
    return { ok: false, error: [hint, e.response || e.message].filter(Boolean).join(" ") };
  }
}

/* ───────────── templates ───────────── */

export function escapeHtml(s: unknown) {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/** Branded HTML email (cyan + midnight, works in all mail apps). */
export function emailLayout(title: string, bodyHtml: string) {
  const logo = siteUrl("/images/logo.png");
  return `<!doctype html><html><body style="margin:0;background:#f3f5fe;font-family:Arial,Helvetica,sans-serif;color:#0f1119;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f3f5fe;padding:24px 0;"><tr><td align="center">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:12px;overflow:hidden;">
      <tr><td style="background:#0f1119;padding:28px;text-align:center;"><img src="${logo}" alt="ammos" width="180" style="display:inline-block;"></td></tr>
      <tr><td style="padding:32px 32px 8px;"><h1 style="margin:0 0 16px;font-size:22px;letter-spacing:1px;text-transform:uppercase;color:#0f1119;">${escapeHtml(title)}</h1>${bodyHtml}</td></tr>
      <tr><td style="padding:24px 32px 32px;font-size:12px;color:#6f8289;border-top:1px solid #e6ebed;">Ammos Makenzy Beach · Makenzy Beach, Larnaca, Cyprus · +357 24 828844 · <a href="${siteUrl()}" style="color:#157f8f;">ammos.eu</a></td></tr>
    </table>
    <div style="height:6px;max-width:600px;background:#b7d44a;"></div>
  </td></tr></table></body></html>`;
}

/** Key/value table for notification emails. */
export function detailsTable(rows: [string, unknown][]) {
  const tr = rows
    .filter(([, v]) => v !== "" && v !== null && v !== undefined)
    .map(
      ([k, v]) =>
        `<tr><td style="padding:8px 12px 8px 0;font-size:13px;color:#6f8289;vertical-align:top;white-space:nowrap;">${escapeHtml(k)}</td><td style="padding:8px 0;font-size:15px;color:#0f1119;">${escapeHtml(v).replace(/\n/g, "<br>")}</td></tr>`,
    )
    .join("");
  return `<table role="presentation" cellpadding="0" cellspacing="0" style="width:100%;border-collapse:collapse;margin:8px 0 16px;">${tr}</table>`;
}

export function paragraph(text: string) {
  return `<p style="margin:0 0 14px;font-size:15px;line-height:1.6;color:#45585f;">${escapeHtml(text)}</p>`;
}

export function button(href: string, label: string) {
  return `<p style="margin:20px 0;"><a href="${escapeHtml(href)}" style="display:inline-block;background:#3ec6d8;color:#0f1119;text-decoration:none;padding:12px 24px;border-radius:999px;font-size:13px;letter-spacing:1px;text-transform:uppercase;font-weight:bold;">${escapeHtml(label)}</a></p>`;
}
AMMOS_EOF
echo "  ✔ lib/mailer.ts"

mkdir -p "app/api/bookings"
cat > "app/api/bookings/route.ts" << 'AMMOS_EOF'
import type { NextRequest } from "next/server";
import { randomInt } from "node:crypto";
import { eq } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { getBookedGuests } from "@/lib/data";
import { clientIp, errorJson, handleError, json, rateLimit, sameOrigin } from "@/lib/http";
import { bookingSchema, looksLikeSpam } from "@/lib/validation";
import { adminRecipients, button, detailsTable, emailLayout, paragraph, sendMail } from "@/lib/mailer";
import { formatDateTime, isEventOver, siteUrl } from "@/lib/utils";

const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no 0/O/1/I
function makeReference() {
  let s = "";
  for (let i = 0; i < 6; i++) s += ALPHABET[randomInt(ALPHABET.length)];
  return `AM-${s}`;
}

export async function POST(req: NextRequest) {
  try {
    if (!sameOrigin(req)) return errorJson("Please book from the website.", 403);
    const ip = clientIp(req);
    const limit = rateLimit(`booking:${ip}`, 6, 10 * 60 * 1000);
    if (!limit.ok) return errorJson("Too many booking attempts. Please try again later or call us.", 429);

    const data = bookingSchema.parse(await req.json());
    if (looksLikeSpam(data)) return json({ ok: true, reference: makeReference() });

    const event = await db.query.events.findFirst({ where: eq(schema.events.id, data.eventId) });
    if (!event || !event.published) return errorJson("This event is no longer available.", 404);
    if (!event.bookingEnabled) return errorJson("Online booking is closed for this event. Please call us.", 400);
    if (isEventOver(event.startsAt)) return errorJson("This event has already started or passed, so online booking is closed. Please call us.", 400);

    if (event.capacity) {
      const booked = await getBookedGuests(event.id);
      const left = event.capacity - booked;
      if (left <= 0) return errorJson("Sorry — this event is fully booked. Call us to join the waiting list.", 409);
      if (data.guests > left) return errorJson(`Only ${left} place${left === 1 ? "" : "s"} left for this event.`, 409);
    }

    let reference = makeReference();
    for (let i = 0; i < 3; i++) {
      const exists = await db.query.bookings.findFirst({ where: eq(schema.bookings.reference, reference) });
      if (!exists) break;
      reference = makeReference();
    }

    const [saved] = await db
      .insert(schema.bookings)
      .values({
        reference,
        eventId: event.id,
        eventTitle: event.title,
        eventDate: event.startsAt,
        firstName: data.firstName,
        lastName: data.lastName,
        email: data.email.toLowerCase(),
        phone: data.phone,
        guests: data.guests,
        seating: data.seating,
        occasion: data.occasion,
        message: data.message,
        marketingOptIn: data.marketingOptIn,
        ip,
      })
      .returning({ id: schema.bookings.id });

    const when = formatDateTime(event.startsAt);
    const name = `${data.firstName} ${data.lastName}`;
    const rows: [string, unknown][] = [
      ["Reference", reference],
      ["Event", event.title],
      ["When", when],
      ["Name", name],
      ["Email", data.email],
      ["Phone", data.phone],
      ["Guests", data.guests],
      ["Seating", data.seating],
      ["Occasion", data.occasion],
      ["Notes", data.message],
    ];

    await sendMail({
      to: await adminRecipients(),
      replyTo: data.email,
      subject: `New booking ${reference}: ${event.title} — ${data.guests} guests`,
      text: rows.map(([k, v]) => `${k}: ${v ?? ""}`).join("\n"),
      html: emailLayout("New event booking", detailsTable(rows) + button(siteUrl(`/admin/bookings?open=${saved.id}`), "Open in admin")),
    });
    await sendMail({
      to: data.email,
      subject: `Booking request received — ${event.title} (${reference})`,
      text: `Hi ${data.firstName},\n\nThank you for your booking request for ${event.title} on ${when} for ${data.guests} guests.\nReference: ${reference}\n\nWe'll confirm your table shortly.\nAmmos Makenzy Beach · +357 24 828844`,
      html: emailLayout(
        `See you soon, ${data.firstName}!`,
        paragraph(`Thank you for your booking request. We'll confirm your table by email or phone shortly.`) +
          detailsTable([
            ["Reference", reference],
            ["Event", event.title],
            ["When", when],
            ["Guests", data.guests],
          ]) +
          paragraph("Need to change something? Just reply to this email or call +357 24 828844.") +
          button(siteUrl(`/events/${event.slug}`), "View event"),
      ),
    });

    return json({ ok: true, reference });
  } catch (err) {
    return handleError(err);
  }
}
AMMOS_EOF
echo "  ✔ app/api/bookings/route.ts"

mkdir -p "app/api/contact"
cat > "app/api/contact/route.ts" << 'AMMOS_EOF'
import type { NextRequest } from "next/server";
import { db, schema } from "@/lib/db";
import { clientIp, errorJson, handleError, json, rateLimit, sameOrigin } from "@/lib/http";
import { contactSchema, looksLikeSpam } from "@/lib/validation";
import { adminRecipients, button, detailsTable, emailLayout, paragraph, sendMail } from "@/lib/mailer";
import { siteUrl } from "@/lib/utils";

export async function POST(req: NextRequest) {
  try {
    if (!sameOrigin(req)) return errorJson("Please send the form from the website.", 403);
    const ip = clientIp(req);
    const limit = rateLimit(`contact:${ip}`, 5, 10 * 60 * 1000);
    if (!limit.ok) return errorJson("Too many messages. Please try again in a few minutes or call us.", 429);

    const data = contactSchema.parse(await req.json());
    if (looksLikeSpam(data)) return json({ ok: true }); // pretend success for bots

    const [saved] = await db
      .insert(schema.messages)
      .values({
        firstName: data.firstName,
        lastName: data.lastName,
        email: data.email.toLowerCase(),
        phone: data.phone,
        subject: data.subject || "General enquiry",
        visitDate: data.visitDate,
        guests: data.guests,
        message: data.message,
        source: data.source || "contact",
        ip,
      })
      .returning({ id: schema.messages.id });

    const name = `${data.firstName} ${data.lastName}`.trim();
    // 1) notification to Ammos (reply goes straight to the guest)
    await sendMail({
      to: await adminRecipients(),
      replyTo: data.email,
      subject: `New message: ${data.subject || "Website enquiry"} — ${name}`,
      text: `${name} <${data.email}> ${data.phone}\nDate: ${data.visitDate} Guests: ${data.guests ?? ""}\n\n${data.message}`,
      html: emailLayout(
        "New website message",
        detailsTable([
          ["Name", name],
          ["Email", data.email],
          ["Phone", data.phone],
          ["Subject", data.subject],
          ["Date", data.visitDate],
          ["Guests", data.guests],
          ["Form", data.source],
          ["Message", data.message],
        ]) + button(siteUrl(`/admin/messages?open=${saved.id}`), "Open in admin"),
      ),
    });
    // 2) confirmation to the guest
    await sendMail({
      to: data.email,
      subject: "We received your message — Ammos Makenzy Beach",
      text: `Hi ${data.firstName}, thank you for contacting Ammos. We'll reply as soon as possible.\n\nYour message:\n${data.message}`,
      html: emailLayout(
        `Thank you, ${data.firstName}!`,
        paragraph("We've received your message and will get back to you as soon as possible. For anything urgent, call us on +357 24 828844.") +
          detailsTable([["Your message", data.message]]),
      ),
    });

    return json({ ok: true });
  } catch (err) {
    return handleError(err);
  }
}
AMMOS_EOF
echo "  ✔ app/api/contact/route.ts"

mkdir -p "app/api/admin/email-test"
cat > "app/api/admin/email-test/route.ts" << 'AMMOS_EOF'
import { errorJson, json, rateLimit, withAdmin } from "@/lib/http";
import { mailStatus, sendTestMail } from "@/lib/mailer";

export const runtime = "nodejs";

/** POST /api/admin/email-test → checks the SMTP settings and sends a test email to MAIL_TO. */
export const POST = withAdmin(async (_req, _ctx, user) => {
  if (!rateLimit(`email-test:${user.id}`, 5, 10 * 60_000).ok) return errorJson("Please wait a few minutes before testing again.", 429);
  const status = await mailStatus();
  const result = await sendTestMail(status.to);
  if (!result.ok) return errorJson(result.error || "Email test failed.", 400);
  return json({ ok: true, to: status.to });
});
AMMOS_EOF
echo "  ✔ app/api/admin/email-test/route.ts"

mkdir -p "app/admin/(panel)"
cat > "app/admin/(panel)/page.tsx" << 'AMMOS_EOF'
import Link from "next/link";
import { and, asc, desc, eq, gte, ne, sql } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { startOfTodayCyprus } from "@/lib/data";
import { formatDateTime } from "@/lib/utils";
import { PageTop } from "@/components/admin/PageTop";
import { EmailTestButton } from "@/components/admin/EmailTestButton";
import { mailStatus } from "@/lib/mailer";

export const metadata = { title: "Dashboard" };

export default async function Dashboard() {
  const today = startOfTodayCyprus();
  const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
  const { bookings, events, messages } = schema;

  const [upcomingEvents, pending, monthBookings, unread, guestsAhead, latestBookings, latestMessages, nextEvents] = await Promise.all([
    db.$count(events, and(eq(events.published, true), gte(events.startsAt, today))),
    db.$count(bookings, eq(bookings.status, "pending")),
    db.$count(bookings, gte(bookings.createdAt, monthStart)),
    db.$count(messages, eq(messages.isRead, false)),
    db
      .select({ n: sql<number>`coalesce(sum(${bookings.guests}),0)::int` })
      .from(bookings)
      .where(and(ne(bookings.status, "cancelled"), gte(bookings.eventDate, today)))
      .then((r) => r[0]?.n ?? 0),
    db.select().from(bookings).orderBy(desc(bookings.createdAt)).limit(6),
    db.select().from(messages).orderBy(desc(messages.createdAt)).limit(6),
    db
      .select({
        id: events.id,
        title: events.title,
        startsAt: events.startsAt,
        capacity: events.capacity,
        booked: sql<number>`(select coalesce(sum(${bookings.guests}),0)::int from ${bookings} where ${bookings.eventId} = ${events.id} and ${bookings.status} <> 'cancelled')`,
      })
      .from(events)
      .where(and(eq(events.published, true), gte(events.startsAt, today)))
      .orderBy(asc(events.startsAt))
      .limit(6),
  ]);

  const mail = await mailStatus();
  const status = (s: string) => <span className={s === "confirmed" ? "pill-ok" : s === "cancelled" ? "pill-bad" : "pill-warn"}>{s}</span>;

  return (
    <>
      <PageTop
        title="Dashboard"
        actions={
          <>
            <Link href="/admin/events/new" className="a-btn primary">
              + New event
            </Link>
            <Link href="/admin/content" className="a-btn">
              Edit page texts
            </Link>
          </>
        }
      />
      <div className="a-content">
        <div className="a-stats">
          <Link href="/admin/bookings?status=pending" className="a-stat">
            <b>{pending}</b>
            <span>Bookings waiting for confirmation</span>
          </Link>
          <Link href="/admin/messages" className="a-stat">
            <b>{unread}</b>
            <span>Unread messages</span>
          </Link>
          <Link href="/admin/events" className="a-stat">
            <b>{upcomingEvents}</b>
            <span>Upcoming events</span>
          </Link>
          <Link href="/admin/bookings" className="a-stat">
            <b>{guestsAhead}</b>
            <span>Guests booked for upcoming events</span>
          </Link>
          <Link href="/admin/bookings" className="a-stat">
            <b>{monthBookings}</b>
            <span>Bookings this month</span>
          </Link>
        </div>

        <div className="a-grid-2">
          <section className="a-card">
            <div className="a-spread" style={{ marginBottom: 12 }}>
              <h2 style={{ margin: 0 }}>Latest bookings</h2>
              <Link href="/admin/bookings">All bookings →</Link>
            </div>
            {latestBookings.length ? (
              <table className="a-table">
                <tbody>
                  {latestBookings.map((b) => (
                    <tr key={b.id}>
                      <td>
                        <Link href={`/admin/bookings?open=${b.id}`} className="title">
                          {b.firstName} {b.lastName}
                        </Link>
                        <div className="a-help">
                          {b.guests} guests · {b.eventTitle}
                        </div>
                      </td>
                      <td style={{ textAlign: "right" }}>{status(b.status)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <p className="a-empty">No bookings yet.</p>
            )}
          </section>

          <section className="a-card">
            <div className="a-spread" style={{ marginBottom: 12 }}>
              <h2 style={{ margin: 0 }}>Latest messages</h2>
              <Link href="/admin/messages">All messages →</Link>
            </div>
            {latestMessages.length ? (
              <table className="a-table">
                <tbody>
                  {latestMessages.map((m) => (
                    <tr key={m.id} className={m.isRead ? "" : "unread"}>
                      <td>
                        <Link href={`/admin/messages?open=${m.id}`} className="title">
                          {m.firstName} {m.lastName}
                        </Link>
                        <div className="a-help clip" style={{ maxWidth: 320, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                          {m.subject} — {m.message}
                        </div>
                      </td>
                      <td className="a-help" style={{ textAlign: "right", whiteSpace: "nowrap" }}>
                        {formatDateTime(m.createdAt)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <p className="a-empty">No messages yet.</p>
            )}
          </section>
        </div>

        <section className="a-card" style={{ marginTop: 16 }}>
          <div className="a-spread" style={{ marginBottom: 8 }}>
            <h2 style={{ margin: 0 }}>Email</h2>
            {mail.configured ? <span className="pill-ok">connected to {mail.host}</span> : <span className="pill-warn">not set up</span>}
          </div>
          <p className="a-help" style={{ marginBottom: 12 }}>
            {mail.configured
              ? `Booking & contact form emails are sent from ${mail.user || mail.from} to ${mail.to.join(", ")}. Guests also get a confirmation email.`
              : "Bookings and messages are saved here in the admin, but no emails are sent yet. Add your SMTP details to the .env file (see DEPLOY.md → Email), restart the site, then press the button below."}
          </p>
          <EmailTestButton disabled={!mail.configured} />
        </section>

        <section className="a-card" style={{ marginTop: 16 }}>
          <div className="a-spread" style={{ marginBottom: 12 }}>
            <h2 style={{ margin: 0 }}>Next events</h2>
            <Link href="/admin/events">Manage events →</Link>
          </div>
          {nextEvents.length ? (
            <table className="a-table">
              <thead>
                <tr>
                  <th>Event</th>
                  <th>When</th>
                  <th>Booked</th>
                </tr>
              </thead>
              <tbody>
                {nextEvents.map((e) => (
                  <tr key={e.id}>
                    <td>
                      <Link href={`/admin/events/${e.id}`} className="title">
                        {e.title}
                      </Link>
                    </td>
                    <td>{formatDateTime(e.startsAt)}</td>
                    <td>
                      <Link href={`/admin/bookings?event=${e.id}`}>
                        {e.booked}
                        {e.capacity ? ` / ${e.capacity}` : ""} guests
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <p className="a-empty">
              No upcoming events. <Link href="/admin/events/new">Create one</Link>
            </p>
          )}
        </section>
      </div>
    </>
  );
}
AMMOS_EOF
echo "  ✔ app/admin/(panel)/page.tsx"

mkdir -p "app/api/admin/users"
cat > "app/api/admin/users/route.ts" << 'AMMOS_EOF'
import { z } from "zod";
import { asc } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { hashPassword, passwordProblem } from "@/lib/auth";
import { errorJson, json, withAdmin } from "@/lib/http";

const createSchema = z.object({
  email: z.string().trim().toLowerCase().email("Please enter a valid email"),
  name: z.string().trim().max(100).default(""),
  password: z.string().max(200),
  role: z.enum(["owner", "editor"]).default("editor"),
  notify: z.boolean().default(true),
});

export const GET = withAdmin(
  async () => {
    const users = await db
      .select({ id: schema.adminUsers.id, email: schema.adminUsers.email, name: schema.adminUsers.name, role: schema.adminUsers.role, notify: schema.adminUsers.notify, lastLoginAt: schema.adminUsers.lastLoginAt })
      .from(schema.adminUsers)
      .orderBy(asc(schema.adminUsers.createdAt));
    return json({ ok: true, users });
  },
  { ownerOnly: true },
);

export const POST = withAdmin(
  async (req) => {
    const data = createSchema.parse(await req.json());
    const problem = passwordProblem(data.password);
    if (problem) return errorJson(problem, 422);
    const [user] = await db
      .insert(schema.adminUsers)
      .values({ email: data.email, name: data.name || data.email, role: data.role, notify: data.notify, passwordHash: await hashPassword(data.password) })
      .returning({ id: schema.adminUsers.id });
    return json({ ok: true, id: user.id }, 201);
  },
  { ownerOnly: true },
);
AMMOS_EOF
echo "  ✔ app/api/admin/users/route.ts"

mkdir -p "app/api/admin/users/[id]"
cat > "app/api/admin/users/[id]/route.ts" << 'AMMOS_EOF'
import { z } from "zod";
import { eq } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { errorJson, json, withAdmin } from "@/lib/http";

type Ctx = { params: Promise<{ id: string }> };

/** PATCH { notify: boolean } → switch email notifications for a user (owners can change anyone, editors only themselves) */
export const PATCH = withAdmin<Ctx>(async (req, ctx, me) => {
  const { id } = await ctx.params;
  if (id !== me.id && me.role !== "owner") return errorJson("Only the owner account can do this.", 403);
  const { notify } = z.object({ notify: z.boolean() }).parse(await req.json());
  const updated = await db.update(schema.adminUsers).set({ notify, updatedAt: new Date() }).where(eq(schema.adminUsers.id, id)).returning({ id: schema.adminUsers.id });
  if (!updated.length) return errorJson("User not found", 404);
  return json({ ok: true });
});

export const DELETE = withAdmin<Ctx>(
  async (_req, ctx, me) => {
    const { id } = await ctx.params;
    if (id === me.id) return errorJson("You cannot delete your own account.", 400);
    const target = await db.query.adminUsers.findFirst({ where: eq(schema.adminUsers.id, id) });
    if (!target) return errorJson("User not found", 404);
    if (target.role === "owner") {
      const owners = await db.$count(schema.adminUsers, eq(schema.adminUsers.role, "owner"));
      if (owners <= 1) return errorJson("You cannot delete the last owner account.", 400);
    }
    await db.delete(schema.adminUsers).where(eq(schema.adminUsers.id, id));
    return json({ ok: true });
  },
  { ownerOnly: true },
);
AMMOS_EOF
echo "  ✔ app/api/admin/users/[id]/route.ts"

mkdir -p "components/admin"
cat > "components/admin/AccountForms.tsx" << 'AMMOS_EOF'
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/components/admin/api";

type Msg = { ok: boolean; text: string } | null;

export function AccountForms({ name, email }: { name: string; email: string }) {
  const router = useRouter();
  const [msg, setMsg] = useState<Msg>(null);
  const [pwMsg, setPwMsg] = useState<Msg>(null);

  async function saveName(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    try {
      await api("/api/admin/account", { method: "POST", json: { action: "profile", name: fd.get("name") } });
      setMsg({ ok: true, text: "Name saved." });
      router.refresh();
    } catch (err) {
      setMsg({ ok: false, text: (err as Error).message });
    }
  }

  async function changePassword(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    const fd = new FormData(form);
    if (fd.get("newPassword") !== fd.get("confirm")) return setPwMsg({ ok: false, text: "The two new passwords are not the same." });
    try {
      await api("/api/admin/account", { method: "POST", json: { action: "password", currentPassword: fd.get("currentPassword"), newPassword: fd.get("newPassword") } });
      form.reset();
      setPwMsg({ ok: true, text: "Password changed. Other devices have been signed out." });
    } catch (err) {
      setPwMsg({ ok: false, text: (err as Error).message });
    }
  }

  async function logoutAll() {
    if (!confirm("Sign out on all other phones and computers?")) return;
    await api("/api/admin/account", { method: "POST", json: { action: "logoutAll" } });
    setMsg({ ok: true, text: "All other devices are signed out." });
  }

  return (
    <div className="a-grid-2">
      <form className="a-card a-form" onSubmit={saveName}>
        <h2 className="a-field">Profile</h2>
        <div className="a-field">
          <label>Email (login)</label>
          <input className="a-input" value={email} disabled />
        </div>
        <div className="a-field">
          <label htmlFor="acc-name">Name</label>
          <input id="acc-name" name="name" className="a-input" defaultValue={name} required maxLength={100} />
        </div>
        <div className="a-field a-row">
          <button className="a-btn primary" type="submit">
            Save
          </button>
          <button className="a-btn" type="button" onClick={logoutAll}>
            Sign out other devices
          </button>
        </div>
        {msg && <p className={`a-field a-msg ${msg.ok ? "ok" : "err"}`}>{msg.text}</p>}
      </form>

      <form className="a-card a-form" onSubmit={changePassword}>
        <h2 className="a-field">Change password</h2>
        <div className="a-field">
          <label htmlFor="pw-cur">Current password</label>
          <input id="pw-cur" name="currentPassword" type="password" className="a-input" required autoComplete="current-password" />
        </div>
        <div className="a-field">
          <label htmlFor="pw-new">New password</label>
          <input id="pw-new" name="newPassword" type="password" className="a-input" required minLength={12} autoComplete="new-password" />
          <span className="a-help">At least 12 characters with letters and numbers.</span>
        </div>
        <div className="a-field">
          <label htmlFor="pw-conf">Repeat new password</label>
          <input id="pw-conf" name="confirm" type="password" className="a-input" required minLength={12} autoComplete="new-password" />
        </div>
        <div className="a-field">
          <button className="a-btn primary" type="submit">
            Change password
          </button>
        </div>
        {pwMsg && <p className={`a-field a-msg ${pwMsg.ok ? "ok" : "err"}`}>{pwMsg.text}</p>}
      </form>
    </div>
  );
}

/** "Email me new bookings & messages" switch for one user. */
export function NotifyToggle({ id, on }: { id: string; on: boolean }) {
  const router = useRouter();
  const [value, setValue] = useState(on);
  const [busy, setBusy] = useState(false);
  async function toggle() {
    setBusy(true);
    try {
      await api(`/api/admin/users/${id}`, { method: "PATCH", json: { notify: !value } });
      setValue(!value);
      router.refresh();
    } catch (err) {
      alert((err as Error).message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <button type="button" className={`a-btn sm ${value ? "" : "ghost"}`} onClick={toggle} disabled={busy} title="Email this person every new booking and message">
      {value ? "🔔 On" : "🔕 Off"}
    </button>
  );
}

export function UsersManager({ users, meId }: { users: { id: string; email: string; name: string; role: string; lastLogin: string; notify: boolean }[]; meId: string }) {
  const router = useRouter();
  const [msg, setMsg] = useState<Msg>(null);

  async function add(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    const fd = new FormData(form);
    try {
      await api("/api/admin/users", { method: "POST", json: { ...Object.fromEntries(fd.entries()), notify: fd.get("notify") === "on" } });
      form.reset();
      setMsg({ ok: true, text: "User added. They'll get an email for every new booking and message (if notifications are on). Send them the password privately — they should change it after logging in." });
      router.refresh();
    } catch (err) {
      setMsg({ ok: false, text: (err as Error).message });
    }
  }
  async function remove(id: string, email: string) {
    if (!confirm(`Remove admin access for ${email}?`)) return;
    try {
      await api(`/api/admin/users/${id}`, { method: "DELETE" });
      router.refresh();
    } catch (err) {
      setMsg({ ok: false, text: (err as Error).message });
    }
  }

  return (
    <section className="a-card" style={{ marginTop: 16 }}>
      <h2>Admin users</h2>
      <div className="a-table-wrap" style={{ marginBottom: 18 }}>
        <table className="a-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Role</th>
              <th>Notifications</th>
              <th>Last login</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {users.map((u) => (
              <tr key={u.id}>
                <td>{u.name}</td>
                <td>{u.email}</td>
                <td>{u.role === "owner" ? <span className="pill-ok">owner</span> : <span className="pill-off">editor</span>}</td>
                <td>
                  <NotifyToggle id={u.id} on={u.notify} />
                </td>
                <td className="a-help">{u.lastLogin}</td>
                <td style={{ textAlign: "right" }}>
                  {u.id !== meId && (
                    <button type="button" className="a-btn danger sm" onClick={() => remove(u.id, u.email)}>
                      Remove
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <form className="a-form" onSubmit={add}>
        <div className="a-field half">
          <label htmlFor="u-name">Name</label>
          <input id="u-name" name="name" className="a-input" maxLength={100} />
        </div>
        <div className="a-field half">
          <label htmlFor="u-email">Email</label>
          <input id="u-email" name="email" type="email" className="a-input" required />
        </div>
        <div className="a-field half">
          <label htmlFor="u-pass">Temporary password</label>
          <input id="u-pass" name="password" type="text" className="a-input" required minLength={12} autoComplete="off" />
        </div>
        <div className="a-field half">
          <label htmlFor="u-role">Role</label>
          <select id="u-role" name="role" className="a-input" defaultValue="editor">
            <option value="editor">Editor — manages content, events & bookings</option>
            <option value="owner">Owner — also manages users</option>
          </select>
        </div>
        <div className="a-field">
          <label className="a-check">
            <input type="checkbox" name="notify" defaultChecked /> Email this person every new booking &amp; contact message
          </label>
        </div>
        <div className="a-field">
          <button className="a-btn primary" type="submit" style={{ justifySelf: "start" }}>
            + Add admin user
          </button>
        </div>
        {msg && <p className={`a-field a-msg ${msg.ok ? "ok" : "err"}`}>{msg.text}</p>}
      </form>
    </section>
  );
}
AMMOS_EOF
echo "  ✔ components/admin/AccountForms.tsx"

mkdir -p "app/admin/(panel)/account"
cat > "app/admin/(panel)/account/page.tsx" << 'AMMOS_EOF'
import { asc } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { requireAdminPage } from "@/lib/auth";
import { formatDateTime } from "@/lib/utils";
import { PageTop } from "@/components/admin/PageTop";
import { eq } from "drizzle-orm";
import { AccountForms, NotifyToggle, UsersManager } from "@/components/admin/AccountForms";

export const metadata = { title: "My account" };
export const dynamic = "force-dynamic";

export default async function AccountPage() {
  const me = await requireAdminPage();
  const [mine] = await db.select({ notify: schema.adminUsers.notify }).from(schema.adminUsers).where(eq(schema.adminUsers.id, me.id));
  const myNotify = mine?.notify ?? true;
  const users =
    me.role === "owner"
      ? (await db.select().from(schema.adminUsers).orderBy(asc(schema.adminUsers.createdAt))).map((u) => ({
          id: u.id,
          email: u.email,
          name: u.name,
          role: u.role,
          notify: u.notify,
          lastLogin: u.lastLoginAt ? formatDateTime(u.lastLoginAt) : "never",
        }))
      : [];
  return (
    <>
      <PageTop title="My account & users" />
      <div className="a-content" style={{ maxWidth: 980 }}>
        <AccountForms name={me.name} email={me.email} />
        <section className="a-card a-spread" style={{ marginTop: 16 }}>
          <div>
            <h2 style={{ margin: 0 }}>My email notifications</h2>
            <p className="a-help" style={{ margin: "6px 0 0" }}>
              Get an email at {me.email} for every new event booking and contact form message.
            </p>
          </div>
          <NotifyToggle id={me.id} on={myNotify} />
        </section>
        {me.role === "owner" ? (
          <UsersManager users={users} meId={me.id} />
        ) : (
          <p className="a-desc" style={{ marginTop: 20 }}>
            Only the owner account can add or remove admin users.
          </p>
        )}
      </div>
    </>
  );
}
AMMOS_EOF
echo "  ✔ app/admin/(panel)/account/page.tsx"

mkdir -p "components/admin"
cat > "components/admin/BulkBar.tsx" << 'AMMOS_EOF'
"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/components/admin/api";

type Action = { key: string; label: string; danger?: boolean };

/**
 * Bulk actions for an admin table. Rows need <input type="checkbox" data-bulk={group} value={id}>,
 * the header can have <input type="checkbox" data-bulk-all={group}>.
 */
export function BulkBar({ group, endpoint, actions, noun = "item" }: { group: string; endpoint: string; actions: Action[]; noun?: string }) {
  const router = useRouter();
  const [ids, setIds] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  useEffect(() => {
    const boxes = () => Array.from(document.querySelectorAll<HTMLInputElement>(`input[data-bulk="${group}"]`));
    const sync = () => setIds(boxes().filter((b) => b.checked).map((b) => b.value));
    const onChange = (e: Event) => {
      const t = e.target as HTMLInputElement;
      if (t.dataset.bulkAll === group) boxes().forEach((b) => (b.checked = t.checked));
      if (t.dataset.bulk === group || t.dataset.bulkAll === group) sync();
    };
    document.addEventListener("change", onChange);
    sync();
    return () => document.removeEventListener("change", onChange);
  }, [group]);

  const clear = () => {
    document.querySelectorAll<HTMLInputElement>(`input[data-bulk="${group}"], input[data-bulk-all="${group}"]`).forEach((b) => (b.checked = false));
    setIds([]);
  };

  async function run(a: Action) {
    if (!ids.length) return;
    const what = `${ids.length} ${noun}${ids.length === 1 ? "" : "s"}`;
    if (a.danger && !confirm(`${a.label} ${what}? This cannot be undone.`)) return;
    setBusy(true);
    setMsg(null);
    try {
      const r = await api<{ count: number }>(endpoint, { method: "POST", json: { ids, action: a.key } });
      setMsg({ ok: true, text: `Done — ${r.count} ${noun}${r.count === 1 ? "" : "s"} updated.` });
      clear();
      router.refresh();
    } catch (e) {
      setMsg({ ok: false, text: (e as Error).message });
    } finally {
      setBusy(false);
    }
  }

  if (!ids.length && !msg) return null;
  return (
    <div className="a-bulk">
      {ids.length > 0 ? (
        <>
          <b>
            {ids.length} selected
          </b>
          {actions.map((a) => (
            <button key={a.key} type="button" className={`a-btn sm${a.danger ? " danger" : ""}`} disabled={busy} onClick={() => run(a)}>
              {a.label}
            </button>
          ))}
          <button type="button" className="a-btn sm ghost" onClick={clear} disabled={busy}>
            Clear
          </button>
        </>
      ) : null}
      {msg && <span className={`a-msg ${msg.ok ? "ok" : "err"}`}>{msg.text}</span>}
    </div>
  );
}
AMMOS_EOF
echo "  ✔ components/admin/BulkBar.tsx"

mkdir -p "app/api/admin/[resource]/bulk"
cat > "app/api/admin/[resource]/bulk/route.ts" << 'AMMOS_EOF'
import { z } from "zod";
import { inArray } from "drizzle-orm";
import type { PgColumn } from "drizzle-orm/pg-core";
import { db } from "@/lib/db";
import { errorJson, json, withAdmin } from "@/lib/http";
import { getResource } from "@/lib/admin/resources.server";
import { refreshSite } from "@/lib/revalidate";

type Ctx = { params: Promise<{ resource: string }> };
const body = z.object({ ids: z.array(z.string().uuid()).min(1).max(1000), action: z.enum(["delete", "show", "hide"]) });

/** POST /api/admin/<resource>/bulk  { ids, action: "delete" | "show" | "hide" } */
export const POST = withAdmin<Ctx>(async (req, ctx) => {
  const { resource } = await ctx.params;
  const res = getResource(resource);
  if (!res) return errorJson("Unknown section", 404);
  const { ids, action } = body.parse(await req.json());
  const t = res.table as unknown as Record<string, PgColumn>;
  let count = 0;
  if (action === "delete") {
    count = (await db.delete(res.table).where(inArray(res.table.id, ids)).returning({ id: res.table.id })).length;
  } else {
    if (!t.published) return errorJson("This list has no show/hide option.", 400);
    count = (await db.update(res.table).set({ published: action === "show" } as never).where(inArray(res.table.id, ids)).returning({ id: res.table.id })).length;
  }
  refreshSite();
  return json({ ok: true, count });
});
AMMOS_EOF
echo "  ✔ app/api/admin/[resource]/bulk/route.ts"

mkdir -p "app/api/admin/bookings/bulk"
cat > "app/api/admin/bookings/bulk/route.ts" << 'AMMOS_EOF'
import { z } from "zod";
import { inArray } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { json, withAdmin } from "@/lib/http";
import { refreshSite } from "@/lib/revalidate";

const body = z.object({ ids: z.array(z.string().uuid()).min(1).max(1000), action: z.enum(["delete", "confirmed", "cancelled", "pending"]) });

/** POST /api/admin/bookings/bulk  { ids, action } — delete, or set the status of many bookings (no emails are sent). */
export const POST = withAdmin(async (req) => {
  const { ids, action } = body.parse(await req.json());
  const where = inArray(schema.bookings.id, ids);
  const rows =
    action === "delete"
      ? await db.delete(schema.bookings).where(where).returning({ id: schema.bookings.id })
      : await db.update(schema.bookings).set({ status: action, updatedAt: new Date() }).where(where).returning({ id: schema.bookings.id });
  refreshSite();
  return json({ ok: true, count: rows.length });
});
AMMOS_EOF
echo "  ✔ app/api/admin/bookings/bulk/route.ts"

mkdir -p "app/api/admin/messages/bulk"
cat > "app/api/admin/messages/bulk/route.ts" << 'AMMOS_EOF'
import { z } from "zod";
import { inArray } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { json, withAdmin } from "@/lib/http";

const body = z.object({ ids: z.array(z.string().uuid()).min(1).max(1000), action: z.enum(["delete", "read", "unread"]) });

/** POST /api/admin/messages/bulk  { ids, action: "delete" | "read" | "unread" } */
export const POST = withAdmin(async (req) => {
  const { ids, action } = body.parse(await req.json());
  const where = inArray(schema.messages.id, ids);
  const rows =
    action === "delete"
      ? await db.delete(schema.messages).where(where).returning({ id: schema.messages.id })
      : await db.update(schema.messages).set({ isRead: action === "read" }).where(where).returning({ id: schema.messages.id });
  return json({ ok: true, count: rows.length });
});
AMMOS_EOF
echo "  ✔ app/api/admin/messages/bulk/route.ts"

mkdir -p "app/admin/(panel)/[resource]"
cat > "app/admin/(panel)/[resource]/page.tsx" << 'AMMOS_EOF'
import Link from "next/link";
import { notFound } from "next/navigation";
import { RESOURCE_MAP, type Column } from "@/lib/admin/resources";
import { listRows, menuCategoryOptions } from "@/lib/admin/resources.server";
import { formatDate, formatDateTime, formatPrice } from "@/lib/utils";
import { PageTop } from "@/components/admin/PageTop";
import { GalleryBulkUpload } from "@/components/admin/GalleryBulkUpload";
import { MenuSyncButton } from "@/components/admin/MenuSyncButton";
import { MenuPhotosUpload } from "@/components/admin/MenuPhotosUpload";
import { BulkBar } from "@/components/admin/BulkBar";

type Props = { params: Promise<{ resource: string }>; searchParams: Promise<{ q?: string; filter?: string }> };

export async function generateMetadata({ params }: Props) {
  const { resource } = await params;
  return { title: RESOURCE_MAP[resource]?.title ?? "Admin" };
}

function cell(col: Column, row: Record<string, any>) {
  const v = row[col.key];
  switch (col.kind) {
    case "image":
      // eslint-disable-next-line @next/next/no-img-element
      return v ? <img className="thumb" src={v} alt="" loading="lazy" /> : <span className="thumb" />;
    case "bool":
      return v ? <span className="pill-ok">yes</span> : <span className="pill-off">no</span>;
    case "date":
      return v ? formatDate(v, { day: "numeric", month: "short", year: "numeric" }) : "—";
    case "datetime":
      return v ? formatDateTime(v) : "—";
    case "price":
      return formatPrice(v) || "—";
    case "count":
      return <b>{v ?? 0}</b>;
    default:
      return <span className="clip" style={{ display: "block" }}>{String(v ?? "")}</span>;
  }
}

export default async function ResourceList({ params, searchParams }: Props) {
  const { resource } = await params;
  const def = RESOURCE_MAP[resource];
  if (!def) notFound();
  const { q = "", filter = "" } = await searchParams;
  const rows = await listRows(resource, { q: q.slice(0, 100), filter });
  const cats = resource === "menu-items" ? await menuCategoryOptions() : [];
  const titleKey = def.columns.find((c) => !c.kind || c.kind === "text")?.key;

  return (
    <>
      <PageTop
        title={def.title}
        actions={
          <>
            {(resource === "menu-items" || resource === "menu-categories") && <MenuSyncButton />}
            <Link href={`/admin/${resource}/new`} className="a-btn primary">
              + Add {def.singular}
            </Link>
          </>
        }
      />
      <div className="a-content">
        <p className="a-desc">{def.description}</p>
        <div className="a-toolbar">
          <form className="a-search" action={`/admin/${resource}`}>
            {resource === "events" && (
              <div className="a-tabs" style={{ marginRight: 8 }}>
                {[
                  ["", "All"],
                  ["upcoming", "Upcoming"],
                  ["past", "Past"],
                ].map(([val, label]) => (
                  <Link key={val} href={`/admin/events${val ? `?filter=${val}` : ""}`} className={filter === val ? "is-active" : ""}>
                    {label}
                  </Link>
                ))}
              </div>
            )}
            {resource === "menu-items" && (
              <select name="filter" defaultValue={filter} className="a-input" style={{ width: 240 }}>
                <option value="">All categories</option>
                {cats.map((c) => (
                  <option key={c.value} value={c.value}>
                    {c.label}
                  </option>
                ))}
              </select>
            )}
            <input name="q" defaultValue={q} className="a-input" placeholder="Search…" style={{ width: 220 }} />
            {resource === "events" && filter && <input type="hidden" name="filter" value={filter} />}
            <button className="a-btn" type="submit">
              Search
            </button>
            {(q || filter) && (
              <Link className="a-btn ghost" href={`/admin/${resource}`}>
                Clear
              </Link>
            )}
          </form>
          <span className="a-help">{rows.length} shown</span>
        </div>

        {resource === "gallery" && <GalleryBulkUpload />}
        {resource === "menu-items" && <MenuPhotosUpload />}

        <BulkBar
          group={resource}
          endpoint={`/api/admin/${resource}/bulk`}
          noun={def.singular}
          actions={[
            ...(def.fields.some((f) => f.name === "published")
              ? [
                  { key: "show", label: "Show on website" },
                  { key: "hide", label: "Hide" },
                ]
              : []),
            { key: "delete", label: "Delete", danger: true },
          ]}
        />

        <div className="a-table-wrap">
          {rows.length ? (
            <table className="a-table">
              <thead>
                <tr>
                  <th className="a-col-check">
                    <input type="checkbox" data-bulk-all={resource} aria-label="Select all" />
                  </th>
                  {def.columns.map((c) => (
                    <th key={c.key}>{c.label}</th>
                  ))}
                  <th />
                </tr>
              </thead>
              <tbody>
                {rows.map((row: Record<string, any>) => (
                  <tr key={row.id}>
                    <td className="a-col-check">
                      <input type="checkbox" data-bulk={resource} value={row.id} aria-label="Select" />
                    </td>
                    {def.columns.map((c) => (
                      <td key={c.key}>
                        {c.key === titleKey ? (
                          <Link href={`/admin/${resource}/${row.id}`} className="title">
                            {String(row[c.key] || "(untitled)")}
                          </Link>
                        ) : c.key === "bookingCount" ? (
                          <Link href={`/admin/bookings?event=${row.id}`}>
                            <b>{row.bookingCount ?? 0}</b>
                            {row.capacity ? ` / ${row.capacity}` : ""}
                          </Link>
                        ) : (
                          cell(c, row)
                        )}
                      </td>
                    ))}
                    <td style={{ textAlign: "right" }}>
                      <Link href={`/admin/${resource}/${row.id}`} className="a-btn sm">
                        Edit
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <p className="a-empty">
              Nothing here yet. <Link href={`/admin/${resource}/new`}>Add the first {def.singular}</Link>.
            </p>
          )}
        </div>
      </div>
    </>
  );
}
AMMOS_EOF
echo "  ✔ app/admin/(panel)/[resource]/page.tsx"

mkdir -p "components/admin"
cat > "components/admin/BookingsTable.tsx" << 'AMMOS_EOF'
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/components/admin/api";
import { BulkBar } from "@/components/admin/BulkBar";

type Row = {
  id: string;
  reference: string;
  eventTitle: string;
  eventLabel: string;
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  guests: number;
  seating: string;
  occasion: string;
  message: string;
  status: string;
  adminNotes: string;
  marketingOptIn: boolean;
  createdLabel: string;
};

const pill = (s: string) => <span className={s === "confirmed" ? "pill-ok" : s === "cancelled" ? "pill-bad" : "pill-warn"}>{s}</span>;

export function BookingsTable({ rows, openId }: { rows: Row[]; openId?: string }) {
  const router = useRouter();
  const [open, setOpen] = useState<string | null>(openId && rows.some((r) => r.id === openId) ? openId : null);
  const current = rows.find((r) => r.id === open) ?? null;

  if (!rows.length) return <div className="a-table-wrap"><p className="a-empty">No bookings found.</p></div>;

  return (
    <>
      <BulkBar
        group="bookings"
        endpoint="/api/admin/bookings/bulk"
        noun="booking"
        actions={[
          { key: "confirmed", label: "Mark confirmed" },
          { key: "cancelled", label: "Mark cancelled" },
          { key: "delete", label: "Delete", danger: true },
        ]}
      />
      <div className="a-table-wrap">
        <table className="a-table">
          <thead>
            <tr>
              <th className="a-col-check">
                <input type="checkbox" data-bulk-all="bookings" aria-label="Select all" />
              </th>
              <th>Guest</th>
              <th>Event</th>
              <th>Guests</th>
              <th>Contact</th>
              <th>Status</th>
              <th>Received</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {rows.map((b) => (
              <tr key={b.id}>
                <td className="a-col-check">
                  <input type="checkbox" data-bulk="bookings" value={b.id} aria-label="Select" />
                </td>
                <td>
                  <button type="button" onClick={() => setOpen(b.id)} className="title" style={{ background: "none", border: 0, padding: 0, color: "var(--a-text)", font: "inherit", fontWeight: 500, cursor: "pointer" }}>
                    {b.firstName} {b.lastName}
                  </button>
                  <div className="a-help">{b.reference}</div>
                </td>
                <td>
                  {b.eventTitle}
                  <div className="a-help">{b.eventLabel}</div>
                </td>
                <td>
                  <b>{b.guests}</b>
                </td>
                <td>
                  <a href={`tel:${b.phone.replace(/\s/g, "")}`}>{b.phone}</a>
                  <div className="a-help">
                    <a href={`mailto:${b.email}`}>{b.email}</a>
                  </div>
                </td>
                <td>{pill(b.status)}</td>
                <td className="a-help">{b.createdLabel}</td>
                <td>
                  <button type="button" className="a-btn sm" onClick={() => setOpen(b.id)}>
                    Open
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {current && <BookingDrawer key={current.id} booking={current} onClose={() => setOpen(null)} onChanged={() => router.refresh()} />}
    </>
  );
}

function BookingDrawer({ booking, onClose, onChanged }: { booking: Row; onClose: () => void; onChanged: () => void }) {
  const [status, setStatus] = useState(booking.status);
  const [notes, setNotes] = useState(booking.adminNotes);
  const [guests, setGuests] = useState(String(booking.guests));
  const [notify, setNotify] = useState(true);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [busy, setBusy] = useState(false);

  async function save() {
    setBusy(true);
    setMsg(null);
    try {
      const res = await api<{ emailed: boolean }>(`/api/admin/bookings/${booking.id}`, { method: "PATCH", json: { status, adminNotes: notes, guests: Number(guests), notifyGuest: notify } });
      setMsg({ ok: true, text: `Saved.${res.emailed ? " The guest was emailed." : ""}` });
      onChanged();
    } catch (e) {
      setMsg({ ok: false, text: (e as Error).message });
    } finally {
      setBusy(false);
    }
  }
  async function remove() {
    if (!confirm("Delete this booking permanently?")) return;
    await api(`/api/admin/bookings/${booking.id}`, { method: "DELETE" });
    onClose();
    onChanged();
  }

  return (
    <>
      <div className="a-drawer-bg" onClick={onClose} />
      <aside className="a-drawer" role="dialog" aria-label="Booking details">
        <div className="a-spread">
          <h2 style={{ fontSize: 18 }}>
            {booking.firstName} {booking.lastName}
          </h2>
          <button type="button" className="a-btn sm ghost" onClick={onClose}>
            Close ✕
          </button>
        </div>
        <dl className="a-kv">
          <dt>Reference</dt>
          <dd>{booking.reference}</dd>
          <dt>Event</dt>
          <dd>
            {booking.eventTitle}
            <br />
            <span className="a-help">{booking.eventLabel}</span>
          </dd>
          <dt>Phone</dt>
          <dd>
            <a href={`tel:${booking.phone.replace(/\s/g, "")}`}>{booking.phone}</a> ·{" "}
            <a href={`https://wa.me/${booking.phone.replace(/[^\d]/g, "")}`} target="_blank" rel="noopener noreferrer">
              WhatsApp
            </a>
          </dd>
          <dt>Email</dt>
          <dd>
            <a href={`mailto:${booking.email}?subject=${encodeURIComponent(`Your booking ${booking.reference} — Ammos`)}`}>{booking.email}</a>
          </dd>
          <dt>Seating</dt>
          <dd>{booking.seating || "—"}</dd>
          <dt>Occasion</dt>
          <dd>{booking.occasion || "—"}</dd>
          <dt>Newsletter</dt>
          <dd>{booking.marketingOptIn ? "Yes, wants news" : "No"}</dd>
          <dt>Received</dt>
          <dd>{booking.createdLabel}</dd>
        </dl>
        {booking.message && (
          <div>
            <span className="a-label">Guest notes</span>
            <div className="a-detail">{booking.message}</div>
          </div>
        )}
        <div className="a-form">
          <div className="a-field half">
            <label htmlFor="bk-status">Status</label>
            <select id="bk-status" className="a-input" value={status} onChange={(e) => setStatus(e.target.value)}>
              <option value="pending">Pending</option>
              <option value="confirmed">Confirmed</option>
              <option value="cancelled">Cancelled</option>
            </select>
          </div>
          <div className="a-field half">
            <label htmlFor="bk-guests">Guests</label>
            <input id="bk-guests" type="number" min={1} className="a-input" value={guests} onChange={(e) => setGuests(e.target.value)} />
          </div>
          <div className="a-field">
            <label htmlFor="bk-notes">Internal notes (only staff see these)</label>
            <textarea id="bk-notes" className="a-input" value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Table number, deposit paid…" />
          </div>
          {status !== booking.status && status !== "pending" && (
            <label className="a-check a-field">
              <input type="checkbox" checked={notify} onChange={(e) => setNotify(e.target.checked)} />
              <span>Email the guest that the booking is {status}</span>
            </label>
          )}
        </div>
        <div className="a-row">
          <button type="button" className="a-btn primary" onClick={save} disabled={busy}>
            {busy ? "Saving…" : "Save"}
          </button>
          <span style={{ flex: 1 }} />
          <button type="button" className="a-btn danger sm" onClick={remove}>
            Delete booking
          </button>
        </div>
        {msg && <p className={`a-msg ${msg.ok ? "ok" : "err"}`}>{msg.text}</p>}
      </aside>
    </>
  );
}
AMMOS_EOF
echo "  ✔ components/admin/BookingsTable.tsx"

mkdir -p "components/admin"
cat > "components/admin/MessagesList.tsx" << 'AMMOS_EOF'
"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/components/admin/api";
import { BulkBar } from "@/components/admin/BulkBar";

type Row = {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  subject: string;
  visitDate: string;
  guests: number | null;
  message: string;
  source: string;
  isRead: boolean;
  createdLabel: string;
};

export function MessagesList({ rows, openId }: { rows: Row[]; openId?: string }) {
  const router = useRouter();
  const [open, setOpen] = useState<string | null>(openId && rows.some((r) => r.id === openId) ? openId : null);
  const current = rows.find((r) => r.id === open) ?? null;

  // opening a message marks it as read
  useEffect(() => {
    if (current && !current.isRead) api(`/api/admin/messages/${current.id}`, { method: "PATCH", json: { isRead: true } }).then(() => router.refresh()).catch(() => {});
  }, [current, router]);

  if (!rows.length) return <div className="a-table-wrap"><p className="a-empty">No messages.</p></div>;

  async function setRead(id: string, isRead: boolean) {
    await api(`/api/admin/messages/${id}`, { method: "PATCH", json: { isRead } });
    router.refresh();
  }
  async function remove(id: string) {
    if (!confirm("Delete this message?")) return;
    await api(`/api/admin/messages/${id}`, { method: "DELETE" });
    setOpen(null);
    router.refresh();
  }

  return (
    <>
      <BulkBar
        group="messages"
        endpoint="/api/admin/messages/bulk"
        noun="message"
        actions={[
          { key: "read", label: "Mark read" },
          { key: "unread", label: "Mark unread" },
          { key: "delete", label: "Delete", danger: true },
        ]}
      />
      <div className="a-table-wrap">
        <table className="a-table">
          <thead>
            <tr>
              <th className="a-col-check">
                <input type="checkbox" data-bulk-all="messages" aria-label="Select all" />
              </th>
              <th>From</th>
              <th>Subject</th>
              <th>Message</th>
              <th>Received</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((m) => (
              <tr key={m.id} className={m.isRead ? "" : "unread"} onClick={() => setOpen(m.id)} style={{ cursor: "pointer" }}>
                <td className="a-col-check" onClick={(e) => e.stopPropagation()}>
                  <input type="checkbox" data-bulk="messages" value={m.id} aria-label="Select" />
                </td>
                <td>
                  {m.firstName} {m.lastName}
                  <div className="a-help">{m.email}</div>
                </td>
                <td>
                  {m.subject}
                  <div className="a-help">via {m.source}</div>
                </td>
                <td>
                  <span className="clip" style={{ display: "block" }}>
                    {m.message}
                  </span>
                </td>
                <td className="a-help" style={{ whiteSpace: "nowrap" }}>
                  {m.createdLabel}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {current && (
        <>
          <div className="a-drawer-bg" onClick={() => setOpen(null)} />
          <aside className="a-drawer" role="dialog" aria-label="Message">
            <div className="a-spread">
              <h2 style={{ fontSize: 18 }}>
                {current.firstName} {current.lastName}
              </h2>
              <button type="button" className="a-btn sm ghost" onClick={() => setOpen(null)}>
                Close ✕
              </button>
            </div>
            <dl className="a-kv">
              <dt>Email</dt>
              <dd>
                <a href={`mailto:${current.email}`}>{current.email}</a>
              </dd>
              {current.phone && (
                <>
                  <dt>Phone</dt>
                  <dd>
                    <a href={`tel:${current.phone.replace(/\s/g, "")}`}>{current.phone}</a> ·{" "}
                    <a href={`https://wa.me/${current.phone.replace(/[^\d]/g, "")}`} target="_blank" rel="noopener noreferrer">
                      WhatsApp
                    </a>
                  </dd>
                </>
              )}
              <dt>Subject</dt>
              <dd>{current.subject}</dd>
              {current.visitDate && (
                <>
                  <dt>Date wanted</dt>
                  <dd>{current.visitDate}</dd>
                </>
              )}
              {current.guests && (
                <>
                  <dt>Guests</dt>
                  <dd>{current.guests}</dd>
                </>
              )}
              <dt>Form</dt>
              <dd>{current.source}</dd>
              <dt>Received</dt>
              <dd>{current.createdLabel}</dd>
            </dl>
            <div className="a-detail">{current.message}</div>
            <div className="a-row">
              <a className="a-btn primary" href={`mailto:${current.email}?subject=${encodeURIComponent(`Re: ${current.subject} — Ammos Makenzy Beach`)}`}>
                Reply by email
              </a>
              <button type="button" className="a-btn" onClick={() => setRead(current.id, false)}>
                Mark unread
              </button>
              <span style={{ flex: 1 }} />
              <button type="button" className="a-btn danger sm" onClick={() => remove(current.id)}>
                Delete
              </button>
            </div>
          </aside>
        </>
      )}
    </>
  );
}
AMMOS_EOF
echo "  ✔ components/admin/MessagesList.tsx"

mkdir -p "app/admin"
cat > "app/admin/admin.css" << 'AMMOS_EOF'
/* ═══════════ AMMOS ADMIN PANEL ═══════════ */
.admin {
  --a-bg: #0c0e15;
  --a-panel: #141726;
  --a-card: #1a1d2b;
  --a-line: #2a2e3d;
  --a-text: #e9e9ed;
  --a-muted: #9397ab;
  --a-ok: #b7d44a;
  --a-warn: #f2b84b;
  --a-bad: #f06262;
  min-height: 100vh;
  background: var(--a-bg);
  color: var(--a-text);
  font-family: var(--body);
  font-size: 14px;
  line-height: 1.5;
}
.admin a { color: var(--brand); }
.admin h1, .admin h2, .admin h3 { font-family: var(--body); font-weight: 600; letter-spacing: 0; text-transform: none; margin: 0; }

/* layout */
.a-shell { display: grid; grid-template-columns: 248px minmax(0, 1fr); min-height: 100vh; }
.a-side { background: var(--a-panel); border-right: 1px solid var(--a-line); padding: 22px 14px; position: sticky; top: 0; height: 100vh; overflow-y: auto; display: flex; flex-direction: column; gap: 18px; }
.a-side .brand { display: flex; align-items: center; gap: 10px; padding: 4px 10px 10px; }
.a-side .brand img { height: 34px; width: auto; }
.a-side .brand span { font-size: 10px; letter-spacing: 0.2em; text-transform: uppercase; color: var(--a-muted); }
.a-nav-group { display: grid; gap: 2px; }
.a-nav-title { font-size: 10px; letter-spacing: 0.22em; text-transform: uppercase; color: var(--a-muted); padding: 6px 10px; }
.a-nav-link { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 9px 12px; border-radius: 8px; color: var(--a-text) !important; font-size: 14px; }
.a-nav-link:hover { background: rgba(255, 255, 255, 0.05); }
.a-nav-link.is-active { background: rgba(62, 198, 216, 0.14); color: var(--brand) !important; }
.a-badge { min-width: 20px; height: 20px; padding: 0 6px; border-radius: 999px; background: var(--brand); color: var(--ink); font-size: 11px; font-weight: 700; display: inline-flex; align-items: center; justify-content: center; }
.a-side-foot { margin-top: auto; border-top: 1px solid var(--a-line); padding-top: 14px; display: grid; gap: 6px; font-size: 13px; }
.a-side-foot .who { padding: 0 12px; color: var(--a-muted); }
.a-main { min-width: 0; }
.a-top { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding: 16px 32px; border-bottom: 1px solid var(--a-line); background: rgba(12, 14, 21, 0.9); backdrop-filter: blur(10px); position: sticky; top: 0; z-index: 10; }
.a-top h1 { font-size: 20px; }
.a-content { padding: 28px 32px 80px; max-width: 1280px; }
.a-btn.a-menu-toggle { display: none; }

/* buttons */
.a-btn { display: inline-flex; align-items: center; justify-content: center; gap: 6px; padding: 9px 16px; border-radius: 8px; border: 1px solid var(--a-line); background: var(--a-card); color: var(--a-text) !important; font: inherit; font-size: 13px; font-weight: 500; cursor: pointer; white-space: nowrap; text-decoration: none; transition: background 0.2s, border-color 0.2s; }
.a-btn:hover { border-color: var(--brand); }
.a-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.a-btn.primary { background: var(--brand); border-color: var(--brand); color: var(--ink) !important; }
.a-btn.primary:hover { background: var(--brand-hover); }
.a-btn.danger { color: var(--a-bad) !important; border-color: rgba(240, 98, 98, 0.4); background: transparent; }
.a-btn.danger:hover { background: rgba(240, 98, 98, 0.1); }
.a-btn.ghost { background: transparent; }
.a-btn.sm { padding: 6px 10px; font-size: 12px; }
.a-row { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
.a-spread { display: flex; gap: 12px; align-items: center; justify-content: space-between; flex-wrap: wrap; }

/* cards & stats */
.a-card { background: var(--a-card); border: 1px solid var(--a-line); border-radius: 12px; padding: 20px; }
.a-card + .a-card { margin-top: 16px; }
.a-grid-2 > .a-card { margin-top: 0; }
.a-card h2 { font-size: 16px; margin-bottom: 14px; }
.a-desc { color: var(--a-muted); margin: 0 0 20px; max-width: 760px; }
.a-stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 14px; margin-bottom: 20px; }
.a-stat { background: var(--a-card); border: 1px solid var(--a-line); border-radius: 12px; padding: 18px 20px; color: var(--a-text) !important; display: block; transition: border-color 0.2s; }
.a-stat:hover { border-color: var(--brand); }
.a-stat b { display: block; font-size: 30px; font-weight: 600; color: var(--brand); line-height: 1.1; }
.a-stat span { color: var(--a-muted); font-size: 13px; }
.a-grid-2 { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px; }

/* tables */
.a-table-wrap { overflow-x: auto; border: 1px solid var(--a-line); border-radius: 12px; background: var(--a-card); }
.a-table { width: 100%; border-collapse: collapse; }
.a-table th { text-align: left; font-size: 11px; letter-spacing: 0.12em; text-transform: uppercase; color: var(--a-muted); font-weight: 500; padding: 12px 14px; border-bottom: 1px solid var(--a-line); white-space: nowrap; }
.a-table td { padding: 10px 14px; border-bottom: 1px solid var(--a-line); vertical-align: middle; }
.a-table tr:last-child td { border-bottom: 0; }
.a-table tbody tr:hover { background: rgba(255, 255, 255, 0.025); }
.a-table .thumb { width: 52px; height: 52px; border-radius: 8px; object-fit: cover; background: var(--a-panel); display: block; }
.a-table .clip { max-width: 360px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.a-table a.title { color: var(--a-text) !important; font-weight: 500; }
.a-table a.title:hover { color: var(--brand) !important; }
.a-empty { padding: 48px; text-align: center; color: var(--a-muted); }
.pill-ok, .pill-off, .pill-warn, .pill-bad { display: inline-block; padding: 2px 9px; border-radius: 999px; font-size: 11px; font-weight: 600; }
.pill-ok { background: rgba(183, 212, 74, 0.16); color: var(--a-ok); }
.pill-off { background: rgba(255, 255, 255, 0.07); color: var(--a-muted); }
.pill-warn { background: rgba(242, 184, 75, 0.16); color: var(--a-warn); }
.pill-bad { background: rgba(240, 98, 98, 0.16); color: var(--a-bad); }

/* toolbar */
.a-toolbar { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; justify-content: space-between; margin-bottom: 16px; }
.a-search { display: flex; gap: 8px; }
.a-tabs { display: inline-flex; border: 1px solid var(--a-line); border-radius: 8px; overflow: hidden; }
.a-tabs a { padding: 8px 14px; color: var(--a-muted) !important; font-size: 13px; }
.a-tabs a + a { border-left: 1px solid var(--a-line); }
.a-tabs a.is-active { background: rgba(62, 198, 216, 0.14); color: var(--brand) !important; }

/* forms */
.a-form { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 18px 20px; }
.a-field { grid-column: 1 / -1; display: flex; flex-direction: column; gap: 6px; }
.a-field.half { grid-column: auto; }
.a-field > label, .a-label { font-size: 13px; font-weight: 500; color: var(--a-text); }
.a-field .req { color: var(--brand); }
.a-help { font-size: 12px; color: var(--a-muted); }
.a-input { width: 100%; padding: 10px 12px; border-radius: 8px; border: 1px solid var(--a-line); background: var(--a-panel); color: var(--a-text); font: inherit; font-size: 14px; }
.a-input:focus { outline: none; border-color: var(--brand); box-shadow: 0 0 0 3px rgba(62, 198, 216, 0.15); }
textarea.a-input { min-height: 96px; resize: vertical; line-height: 1.55; }
textarea.a-input.rich { min-height: 220px; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 13px; }
select.a-input { cursor: pointer; }
input[type="datetime-local"].a-input, input[type="date"].a-input { color-scheme: dark; }
.a-check { display: flex; align-items: center; gap: 10px; cursor: pointer; padding: 10px 12px; border: 1px solid var(--a-line); border-radius: 8px; background: var(--a-panel); }
.a-check input { width: 18px; height: 18px; accent-color: var(--brand); }
.a-form-actions { grid-column: 1 / -1; display: flex; gap: 10px; align-items: center; flex-wrap: wrap; padding-top: 8px; border-top: 1px solid var(--a-line); margin-top: 6px; position: sticky; bottom: 0; background: var(--a-card); padding-bottom: 4px; }
.a-msg { padding: 10px 14px; border-radius: 8px; font-size: 13px; }
.a-msg.ok { background: rgba(183, 212, 74, 0.14); color: var(--a-ok); }
.a-msg.err { background: rgba(240, 98, 98, 0.14); color: #ffb3b3; }

/* media input */
.a-media { display: grid; grid-template-columns: 160px minmax(0, 1fr); gap: 14px; align-items: start; }
.a-media-preview { width: 160px; aspect-ratio: 4 / 3; border-radius: 10px; overflow: hidden; background: var(--a-panel); border: 1px dashed var(--a-line); display: flex; align-items: center; justify-content: center; color: var(--a-muted); font-size: 12px; text-align: center; }
.a-media-preview img, .a-media-preview video { width: 100%; height: 100%; object-fit: cover; }
.a-media-controls { display: grid; gap: 8px; }
.a-drop.is-over { border-color: var(--brand); background: rgba(62, 198, 216, 0.08); }

/* list fields (content editor) */
.a-list { display: grid; gap: 12px; }
.a-list-item { border: 1px solid var(--a-line); border-radius: 10px; padding: 14px; background: rgba(255, 255, 255, 0.015); }
.a-list-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; font-size: 12px; color: var(--a-muted); letter-spacing: 0.1em; text-transform: uppercase; }
.a-list-item .a-form { gap: 12px 14px; }

/* message / booking detail */
.a-detail { white-space: pre-wrap; background: var(--a-panel); border-radius: 8px; padding: 12px 14px; margin: 8px 0; }
.a-kv { display: grid; grid-template-columns: 140px 1fr; gap: 6px 14px; font-size: 13px; }
.a-kv dt { color: var(--a-muted); }
.a-kv dd { margin: 0; }
.unread td { font-weight: 600; }
.unread td:first-child { box-shadow: inset 3px 0 0 var(--brand); }
.a-drawer-bg { position: fixed; inset: 0; background: rgba(0, 0, 0, 0.55); z-index: 40; }
.a-drawer { position: fixed; top: 0; right: 0; bottom: 0; width: min(560px, 100%); background: var(--a-card); border-left: 1px solid var(--a-line); z-index: 41; padding: 24px; overflow-y: auto; display: grid; gap: 16px; align-content: start; }

/* content sections list */
.a-sections { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 12px; }
.a-section-card { display: block; padding: 16px 18px; border: 1px solid var(--a-line); border-radius: 12px; background: var(--a-card); color: var(--a-text) !important; }
.a-section-card:hover { border-color: var(--brand); }
.a-section-card b { display: block; margin-bottom: 4px; }
.a-section-card span { color: var(--a-muted); font-size: 13px; }

/* login */
.a-login { min-height: 100vh; display: grid; place-items: center; padding: 24px; background: radial-gradient(60% 50% at 80% 0%, rgba(62, 198, 216, 0.16), transparent 70%), var(--a-bg); }
.a-login-card { width: min(420px, 100%); background: var(--a-card); border: 1px solid var(--a-line); border-radius: 16px; padding: 36px 32px; display: grid; gap: 16px; }
.a-login-card img { height: 46px; width: auto; margin: 0 auto 8px; }
.a-login-card h1 { text-align: center; font-size: 18px; }

@media (max-width: 900px) {
  .a-shell { grid-template-columns: 1fr; }
  .a-side { position: fixed; z-index: 50; left: 0; top: 0; width: 260px; transform: translateX(-100%); transition: transform 0.3s; }
  .a-side.is-open { transform: none; box-shadow: 0 0 0 100vmax rgba(0, 0, 0, 0.5); }
  .a-btn.a-menu-toggle { display: inline-flex; }
  .a-top { padding: 12px 16px; }
  .a-content { padding: 20px 16px 80px; }
  .a-form { grid-template-columns: 1fr; }
  .a-field.half { grid-column: 1 / -1; }
  .a-grid-2 { grid-template-columns: 1fr; }
  .a-media { grid-template-columns: 1fr; }
  .a-kv { grid-template-columns: 1fr; }
}

/* ── multiple photos field (event photos) ── */
.a-multi { display: grid; gap: 12px; padding: 12px; border: 1px dashed var(--a-line); border-radius: 12px; }
.a-multi.is-over { border-color: var(--a-accent, #00b8c8); background: rgba(0, 184, 200, 0.06); }
.a-multi-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: 10px; }
.a-multi-item { position: relative; aspect-ratio: 1; border-radius: 10px; overflow: hidden; background: var(--a-panel); cursor: grab; }
.a-multi-item.is-drag { opacity: 0.4; }
.a-multi-item img { width: 100%; height: 100%; object-fit: cover; display: block; pointer-events: none; }
.a-multi-num { position: absolute; top: 6px; left: 6px; min-width: 22px; height: 22px; padding: 0 6px; border-radius: 11px; background: rgba(0, 0, 0, 0.65); color: #fff; font-size: 11px; display: flex; align-items: center; justify-content: center; }
.a-multi-actions { position: absolute; left: 0; right: 0; bottom: 0; display: flex; justify-content: space-between; gap: 4px; padding: 6px; background: linear-gradient(transparent, rgba(0, 0, 0, 0.7)); }
.a-multi-actions button { width: 28px; height: 28px; border: 0; border-radius: 8px; background: rgba(255, 255, 255, 0.92); color: #111; cursor: pointer; font-size: 13px; }
.a-multi-actions button:disabled { opacity: 0.35; cursor: default; }
.a-multi-actions button.del { margin-left: auto; background: #e5484d; color: #fff; }

/* bulk select & actions */
.a-col-check { width: 36px; padding-right: 0 !important; }
.a-col-check input { width: 17px; height: 17px; accent-color: var(--brand, #00b8c8); cursor: pointer; vertical-align: middle; }
.a-bulk { position: sticky; top: 64px; z-index: 5; display: flex; flex-wrap: wrap; align-items: center; gap: 10px; margin-bottom: 12px; padding: 10px 14px; border-radius: 12px; background: var(--a-card); border: 1px solid var(--brand, #00b8c8); box-shadow: 0 10px 30px rgba(0, 0, 0, 0.35); }
.a-bulk b { margin-right: 6px; }
AMMOS_EOF
echo "  ✔ app/admin/admin.css"

mkdir -p "app/admin/(panel)/messages"
cat > "app/admin/(panel)/messages/page.tsx" << 'AMMOS_EOF'
import Link from "next/link";
import { and, desc, eq, ilike, or, type SQL } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { formatDateTime } from "@/lib/utils";
import { PageTop } from "@/components/admin/PageTop";
import { MessagesList } from "@/components/admin/MessagesList";

export const metadata = { title: "Messages" };
export const dynamic = "force-dynamic";

type Props = { searchParams: Promise<{ q?: string; show?: string; open?: string }> };

export default async function MessagesPage({ searchParams }: Props) {
  const { q = "", show = "", open = "" } = await searchParams;
  const m = schema.messages;
  const where: SQL[] = [];
  if (show === "unread") where.push(eq(m.isRead, false));
  if (q) {
    const term = `%${q.slice(0, 80).replace(/[%_]/g, "\\$&")}%`;
    where.push(or(ilike(m.firstName, term), ilike(m.lastName, term), ilike(m.email, term), ilike(m.message, term), ilike(m.subject, term))!);
  }
  const rows = await db.select().from(m).where(where.length ? and(...where) : undefined).orderBy(desc(m.createdAt)).limit(500);

  return (
    <>
      <PageTop title="Messages" />
      <div className="a-content">
        <p className="a-desc">
          <b>What is this?</b> Every message guests send through the website forms — the <b>Contact page</b>, the form at the <b>bottom of the homepage</b> and the{" "}
          <b>Private events</b> enquiry form. (Event bookings are separate, under <Link href="/admin/bookings">Event bookings</Link>.) Each new message is also emailed to everyone with
          notifications switched on in <Link href="/admin/account">My account &amp; users</Link>. Click a message to read it and reply by email or WhatsApp; tick several to mark them read or
          delete them.
        </p>
        <div className="a-toolbar">
          <form className="a-search" action="/admin/messages">
            <div className="a-tabs" style={{ marginRight: 8 }}>
              <Link href="/admin/messages" className={show ? "" : "is-active"}>
                All
              </Link>
              <Link href="/admin/messages?show=unread" className={show === "unread" ? "is-active" : ""}>
                Unread
              </Link>
            </div>
            <input name="q" defaultValue={q} className="a-input" placeholder="Search…" style={{ width: 220 }} />
            <button className="a-btn" type="submit">
              Search
            </button>
          </form>
          <span className="a-help">{rows.length} messages</span>
        </div>
        <MessagesList openId={open} rows={rows.map((r) => ({ ...r, createdAt: r.createdAt.toISOString(), createdLabel: formatDateTime(r.createdAt) }))} />
      </div>
    </>
  );
}
AMMOS_EOF
echo "  ✔ app/admin/(panel)/messages/page.tsx"

npm run db:migrate
echo ""
echo "✔ Update 7 done. Start the site:  npm run dev"
