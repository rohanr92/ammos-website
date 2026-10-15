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
