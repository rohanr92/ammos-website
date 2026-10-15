"use client";

export default function Error({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <main className="notfound" style={{ background: "var(--bg)" }}>
      <div>
        <p className="kicker">Something went wrong</p>
        <h1 className="display display-lg">we spilled the drink</h1>
        <p className="lead" style={{ margin: "20px auto 36px", maxWidth: 480 }}>
          Please try again in a moment. If it keeps happening, call us on +357 24 828844.
        </p>
        <button className="btn btn-brand" onClick={() => reset()}>
          Try again
        </button>
      </div>
    </main>
  );
}
