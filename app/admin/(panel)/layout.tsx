import { eq } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { requireAdminPage } from "@/lib/auth";
import { AdminShell } from "@/components/admin/AdminShell";

export const dynamic = "force-dynamic";

export default async function PanelLayout({ children }: { children: React.ReactNode }) {
  const user = await requireAdminPage();
  const [messages, bookings] = await Promise.all([
    db.$count(schema.messages, eq(schema.messages.isRead, false)),
    db.$count(schema.bookings, eq(schema.bookings.status, "pending")),
  ]);
  return (
    <AdminShell user={{ name: user.name, email: user.email }} counts={{ messages, bookings }}>
      {children}
    </AdminShell>
  );
}
