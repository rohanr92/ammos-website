#!/bin/bash
# Ammos website — update 6: real Instagram photos in the chefs, activities, story and events sections
set -e
if [ ! -f scripts/import-instagram.ts ]; then echo "✖ Run this inside ammos-website after update 4/5."; exit 1; fi
if [ ! -f public/images/ig/chef-sauce.webp ]; then echo "✖ The photos in public/images/ig are missing."; exit 1; fi
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
          { value: "image", label: "Photo" },
          { value: "video", label: "Video (photo shows while it loads)" },
        ],
        help: "Switch between the photo and the video below. Both are kept, so you can switch back any time.",
      },
      img("image", "Background photo", "Shown when “Photo” is selected, and while the video loads"),
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
      mediaType: "image",
      image: "/images/hero-kitchen.jpg",
      video: "https://assets.mixkit.co/videos/4043/4043-720.mp4",
    },
  },
  {
    key: "home.events",
    title: "Upcoming events block",
    group: "Homepage",
    description: "Heading of the events slider. The cards come from Admin → Events (marked “Show on homepage”).",
    fields: [t("kicker", "Kicker", KICKER_HELP), t("title", "Title"), t("buttonLabel", "Button text")],
    defaults: { kicker: "What's on", title: "upcoming events", buttonLabel: "View all events" },
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
import { inArray } from "drizzle-orm";
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

mkdir -p "drizzle"
cat > "drizzle/0004_instagram_event_photos.sql" << 'AMMOS_EOF'
-- swap the example event photos for real Ammos photos from Instagram (only where the example photo is still used)
UPDATE "events" SET "image" = '/images/ig/event-sunset.webp' WHERE "slug" = 'sunset-sessions-w-nikos-k' AND "image" LIKE '/images/%.jpg';--> statement-breakpoint
UPDATE "events" SET "image" = '/images/ig/event-night-party.webp' WHERE "slug" = 'full-moon-beach-party' AND "image" LIKE '/images/%.jpg';--> statement-breakpoint
UPDATE "events" SET "image" = '/images/ig/event-brunch.webp' WHERE "slug" = 'long-table-sunday-brunch' AND "image" LIKE '/images/%.jpg';--> statement-breakpoint
UPDATE "events" SET "image" = '/images/ig/event-terrace-night.webp' WHERE "slug" = 'acoustic-nights-elena-and-band' AND "image" LIKE '/images/%.jpg';--> statement-breakpoint
UPDATE "events" SET "image" = '/images/ig/event-wine-steak.webp' WHERE "slug" = 'cypriot-wine-and-meze-evening' AND "image" LIKE '/images/%.jpg';--> statement-breakpoint
UPDATE "events" SET "image" = '/images/ig/event-dj-crowd.webp' WHERE "slug" = 'ammos-summer-closing-party' AND "image" LIKE '/images/%.jpg';--> statement-breakpoint
UPDATE "events" SET "gallery" = '["/images/ig/event-night-party.webp","/images/ig/event-dj-crowd.webp","/images/ig/event-hug.webp","/images/ig/story-2015-friends.webp","/images/ig/fan-aperol.webp"]'::jsonb WHERE "gallery"::text LIKE '%/images/%.jpg%' AND "gallery"::text NOT LIKE '%/uploads/%';
AMMOS_EOF
echo "  ✔ drizzle/0004_instagram_event_photos.sql"

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
    }
  ]
}
AMMOS_EOF
echo "  ✔ drizzle/meta/_journal.json"

mkdir -p "drizzle/meta"
cat > "drizzle/meta/0004_snapshot.json" << 'AMMOS_EOF'
{
  "id": "c4a6fec4-d919-40f8-a116-27f47b83d980",
  "prevId": "14d144b1-e763-435f-b380-943db6b85a38",
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
          "with": {},
          "method": "btree",
          "concurrently": false
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
          "with": {},
          "method": "btree",
          "concurrently": false
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
          "with": {},
          "method": "btree",
          "concurrently": false
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
          "with": {},
          "method": "btree",
          "concurrently": false
        }
      },
      "foreignKeys": {
        "bookings_event_id_events_id_fk": {
          "name": "bookings_event_id_events_id_fk",
          "tableFrom": "bookings",
          "columnsFrom": [
            "event_id"
          ],
          "tableTo": "events",
          "columnsTo": [
            "id"
          ],
          "onUpdate": "no action",
          "onDelete": "set null"
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
          "with": {},
          "method": "btree",
          "concurrently": false
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
          "with": {},
          "method": "btree",
          "concurrently": false
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
          "with": {},
          "method": "btree",
          "concurrently": false
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
          "with": {},
          "method": "btree",
          "concurrently": false
        }
      },
      "foreignKeys": {
        "menu_items_category_id_menu_categories_id_fk": {
          "name": "menu_items_category_id_menu_categories_id_fk",
          "tableFrom": "menu_items",
          "columnsFrom": [
            "category_id"
          ],
          "tableTo": "menu_categories",
          "columnsTo": [
            "id"
          ],
          "onUpdate": "no action",
          "onDelete": "cascade"
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
          "with": {},
          "method": "btree",
          "concurrently": false
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
          "with": {},
          "method": "btree",
          "concurrently": false
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
          "with": {},
          "method": "btree",
          "concurrently": false
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
  "views": {},
  "sequences": {},
  "roles": {},
  "policies": {},
  "_meta": {
    "columns": {},
    "schemas": {},
    "tables": {}
  }
}
AMMOS_EOF
echo "  ✔ drizzle/meta/0004_snapshot.json"

npm run db:migrate
echo ""
echo "✔ Update 6 done. Start the site:  npm run dev"
