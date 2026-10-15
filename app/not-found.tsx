import Link from "next/link";

export const metadata = { title: "Page not found", robots: { index: false } };

export default function NotFound() {
  return (
    <main className="notfound" style={{ background: "var(--bg)" }}>
      <div>
        <Link href="/" aria-label="Home">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/images/logo.svg" alt="ammos" width={220} height={57} style={{ margin: "0 auto 48px" }} />
        </Link>
        <p className="kicker">Error 404</p>
        <h1 className="display display-lg">lost on the beach?</h1>
        <p className="lead" style={{ margin: "20px auto 36px", maxWidth: 480 }}>
          This page washed away. Let's get you back to the good stuff.
        </p>
        <div className="btn-row" style={{ justifyContent: "center" }}>
          <Link href="/" className="btn btn-brand">
            Home
          </Link>
          <Link href="/menu" className="btn btn-outline">
            Menu
          </Link>
          <Link href="/events" className="btn btn-muted">
            Events
          </Link>
        </div>
      </div>
    </main>
  );
}
