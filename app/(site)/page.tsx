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
                <Link href={hero.secondaryUrl || "/menu"} className="btn btn-ghost-light">
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
                <EventCard key={e.id} event={e} variant={evCopy.cardStyle === "editorial" ? "editorial" : "overlay"} showPastDates={evCopy.showPastDates === true} />
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
        {/* on phones the button sits under the photos */}
        <div className="gallery-mobile-cta">
          <a href={settings.reservationUrl} target="_blank" rel="noopener noreferrer" className="btn btn-brand">
            {galCopy.buttonLabel}
          </a>
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
