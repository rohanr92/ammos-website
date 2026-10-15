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

/** One menu link: text, where it goes, new tab, hide. */
const NAV_FIELDS: FieldDef[] = [
  { name: "label", label: "Text", type: "text" },
  { name: "url", label: "Link", type: "url", help: "A page like /events or /menu#food, or a full link https://…" },
  { name: "newTab", label: "Open in a new tab", type: "checkbox" },
  { name: "hidden", label: "Hide this link", type: "checkbox" },
];

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

  /* ═════════════════════ NAVIGATION ═════════════════════ */
  {
    key: "navigation",
    title: "Navigation (header & footer menus)",
    group: "Settings",
    description: "Every menu link on the website: the top bar, the full-screen menu, the footer columns and the footer bottom bar. Rename, re-link, reorder or hide links.",
    fields: [
      { name: "headerLinks", label: "Header — links on the left", type: "list", itemLabel: "Link", help: "Shown at the top of every page and in the white bar when scrolling. 3–4 links fit best.", fields: NAV_FIELDS },
      t("headerRightLabel", "Header — link on the right (text)", "e.g. Contact us"),
      { name: "headerRightUrl", label: "Header — link on the right (link)", type: "url" },
      t("reserveLabel", "“Reserve” button text (white bar)", "The button opens the table reservation link from Business details"),
      { name: "menuLinks", label: "Full-screen menu — big links", type: "list", itemLabel: "Link", help: "The menu that opens with the ☰ button.", fields: NAV_FIELDS },
      { name: "menuBottomLinks", label: "Full-screen menu — small links at the bottom", type: "list", itemLabel: "Link", fields: NAV_FIELDS },
      { name: "footerCol1", label: "Footer — column 1", type: "list", itemLabel: "Link", fields: NAV_FIELDS },
      { name: "footerCol2", label: "Footer — column 2", type: "list", itemLabel: "Link", fields: NAV_FIELDS },
      { name: "footerCol3", label: "Footer — column 3", type: "list", itemLabel: "Link", fields: NAV_FIELDS },
      { name: "footerBarLinks", label: "Footer — bottom bar (small links next to ©)", type: "list", itemLabel: "Link", fields: NAV_FIELDS },
    ],
    defaults: {
      headerLinks: [
        { label: "Events", url: "/events" },
        { label: "Menu", url: "/menu" },
        { label: "Story", url: "/our-story" },
      ],
      headerRightLabel: "Contact us",
      headerRightUrl: "/contact",
      reserveLabel: "Reserve",
      menuLinks: [
        { label: "Welcome", url: "/" },
        { label: "Events", url: "/events" },
        { label: "Events calendar", url: "/events/calendar" },
        { label: "Our menu", url: "/menu" },
        { label: "The Ammos story", url: "/our-story" },
        { label: "Gallery", url: "/gallery" },
        { label: "News & stories", url: "/news" },
        { label: "Private events", url: "/private-events" },
        { label: "Contact", url: "/contact" },
      ],
      menuBottomLinks: [
        { label: "Careers", url: "/careers" },
        { label: "House rules", url: "/house-rules" },
        { label: "Privacy", url: "/privacy-policy" },
      ],
      footerCol1: [
        { label: "Welcome", url: "/" },
        { label: "The Ammos Story", url: "/our-story" },
        { label: "Events Calendar", url: "/events/calendar" },
        { label: "Gallery", url: "/gallery" },
      ],
      footerCol2: [
        { label: "Private Events", url: "/private-events" },
        { label: "Blog", url: "/news" },
        { label: "House Rules", url: "/house-rules" },
        { label: "Careers", url: "/careers" },
      ],
      footerCol3: [
        { label: "Food Menu", url: "/menu#food" },
        { label: "Cocktails", url: "/menu#cocktails" },
        { label: "Brunch", url: "/menu#early-bites" },
        { label: "Contact", url: "/contact" },
      ],
      footerBarLinks: [
        { label: "Privacy Policy", url: "/privacy-policy" },
        { label: "Legal Notice", url: "/legal-notice" },
        { label: "House Rules", url: "/house-rules" },
      ],
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
      t("secondaryLabel", "Second button text"),
      { name: "secondaryUrl", label: "Second button link", type: "url", help: "e.g. /menu, /events or a full link" },
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
      secondaryLabel: "View menu",
      secondaryUrl: "/menu",
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
      { name: "showPastDates", label: "Show the date on past event cards", type: "checkbox", help: "Off = past events show only “Event passed” (no date). The calendar always shows dates." },
    ],
    defaults: { kicker: "What's on", title: "our events", buttonLabel: "View all events", cardStyle: "overlay", showPastDates: false },
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
