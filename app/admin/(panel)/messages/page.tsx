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
