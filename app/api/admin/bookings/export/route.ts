import { and, desc, eq, type SQL } from "drizzle-orm";
import { db, schema } from "@/lib/db";
import { withAdmin } from "@/lib/http";
import { formatDateTime } from "@/lib/utils";

/** Download bookings as a CSV file (opens in Excel / Google Sheets). */
export const GET = withAdmin(async (req) => {
  const sp = req.nextUrl.searchParams;
  const where: SQL[] = [];
  if (sp.get("event")) where.push(eq(schema.bookings.eventId, sp.get("event")!));
  if (sp.get("status")) where.push(eq(schema.bookings.status, sp.get("status")!));
  const rows = await db
    .select()
    .from(schema.bookings)
    .where(where.length ? and(...where) : undefined)
    .orderBy(desc(schema.bookings.createdAt));

  // prefix formulas so spreadsheet apps never execute them
  const cell = (v: unknown) => {
    let s = String(v ?? "");
    if (/^[=@\t\r]/.test(s) || /^[+\-](?![\d\s()]+$)/.test(s)) s = `'${s}`;
    return `"${s.replace(/"/g, '""')}"`;
  };
  const header = ["Reference", "Status", "Event", "Event date", "First name", "Last name", "Email", "Phone", "Guests", "Seating", "Occasion", "Notes", "Admin notes", "Newsletter", "Booked at"];
  const lines = rows.map((b) =>
    [
      b.reference,
      b.status,
      b.eventTitle,
      b.eventDate ? formatDateTime(b.eventDate) : "",
      b.firstName,
      b.lastName,
      b.email,
      b.phone,
      b.guests,
      b.seating,
      b.occasion,
      b.message,
      b.adminNotes,
      b.marketingOptIn ? "yes" : "no",
      formatDateTime(b.createdAt),
    ]
      .map(cell)
      .join(","),
  );
  const csv = "﻿" + [header.map(cell).join(","), ...lines].join("\r\n");
  return new Response(csv, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="ammos-bookings-${new Date().toISOString().slice(0, 10)}.csv"`,
      "Cache-Control": "no-store",
    },
  });
});
