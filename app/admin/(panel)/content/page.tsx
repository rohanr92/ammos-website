import Link from "next/link";
import { SECTIONS } from "@/lib/content-schema";
import { PageTop } from "@/components/admin/PageTop";

export const metadata = { title: "Page content" };

export default function ContentIndex() {
  const groups = ["Settings", "Homepage", "Pages"] as const;
  return (
    <>
      <PageTop title="Page content" />
      <div className="a-content">
        <p className="a-desc">Change any text or photo on the website. Pick a section, edit, and press Save — the website updates straight away.</p>
        {groups.map((g) => (
          <section key={g} style={{ marginBottom: 28 }}>
            <h2 style={{ fontSize: 13, letterSpacing: "0.16em", textTransform: "uppercase", color: "var(--a-muted)", marginBottom: 12 }}>{g}</h2>
            <div className="a-sections">
              {SECTIONS.filter((s) => s.group === g).map((s) => (
                <Link key={s.key} href={`/admin/content/${s.key}`} className="a-section-card">
                  <b>{s.title}</b>
                  <span>{s.description}</span>
                </Link>
              ))}
            </div>
          </section>
        ))}
      </div>
    </>
  );
}
