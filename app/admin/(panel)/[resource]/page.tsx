import Link from "next/link";
import { notFound } from "next/navigation";
import { RESOURCE_MAP, type Column } from "@/lib/admin/resources";
import { listRows, menuCategoryOptions } from "@/lib/admin/resources.server";
import { formatDate, formatDateTime, formatPrice } from "@/lib/utils";
import { PageTop } from "@/components/admin/PageTop";
import { GalleryBulkUpload } from "@/components/admin/GalleryBulkUpload";
import { MenuSyncButton } from "@/components/admin/MenuSyncButton";
import { MenuPhotosUpload } from "@/components/admin/MenuPhotosUpload";
import { BulkBar } from "@/components/admin/BulkBar";

type Props = { params: Promise<{ resource: string }>; searchParams: Promise<{ q?: string; filter?: string }> };

export async function generateMetadata({ params }: Props) {
  const { resource } = await params;
  return { title: RESOURCE_MAP[resource]?.title ?? "Admin" };
}

function cell(col: Column, row: Record<string, any>) {
  const v = row[col.key];
  switch (col.kind) {
    case "image":
      // eslint-disable-next-line @next/next/no-img-element
      return v ? <img className="thumb" src={v} alt="" loading="lazy" /> : <span className="thumb" />;
    case "bool":
      return v ? <span className="pill-ok">yes</span> : <span className="pill-off">no</span>;
    case "date":
      return v ? formatDate(v, { day: "numeric", month: "short", year: "numeric" }) : "—";
    case "datetime":
      return v ? formatDateTime(v) : "—";
    case "price":
      return formatPrice(v) || "—";
    case "count":
      return <b>{v ?? 0}</b>;
    default:
      return <span className="clip" style={{ display: "block" }}>{String(v ?? "")}</span>;
  }
}

export default async function ResourceList({ params, searchParams }: Props) {
  const { resource } = await params;
  const def = RESOURCE_MAP[resource];
  if (!def) notFound();
  const { q = "", filter = "" } = await searchParams;
  const rows = await listRows(resource, { q: q.slice(0, 100), filter });
  const cats = resource === "menu-items" ? await menuCategoryOptions() : [];
  const titleKey = def.columns.find((c) => !c.kind || c.kind === "text")?.key;

  return (
    <>
      <PageTop
        title={def.title}
        actions={
          <>
            {(resource === "menu-items" || resource === "menu-categories") && <MenuSyncButton />}
            <Link href={`/admin/${resource}/new`} className="a-btn primary">
              + Add {def.singular}
            </Link>
          </>
        }
      />
      <div className="a-content">
        <p className="a-desc">{def.description}</p>
        <div className="a-toolbar">
          <form className="a-search" action={`/admin/${resource}`}>
            {resource === "events" && (
              <div className="a-tabs" style={{ marginRight: 8 }}>
                {[
                  ["", "All"],
                  ["upcoming", "Upcoming"],
                  ["past", "Past"],
                ].map(([val, label]) => (
                  <Link key={val} href={`/admin/events${val ? `?filter=${val}` : ""}`} className={filter === val ? "is-active" : ""}>
                    {label}
                  </Link>
                ))}
              </div>
            )}
            {resource === "menu-items" && (
              <select name="filter" defaultValue={filter} className="a-input" style={{ width: 240 }}>
                <option value="">All categories</option>
                {cats.map((c) => (
                  <option key={c.value} value={c.value}>
                    {c.label}
                  </option>
                ))}
              </select>
            )}
            <input name="q" defaultValue={q} className="a-input" placeholder="Search…" style={{ width: 220 }} />
            {resource === "events" && filter && <input type="hidden" name="filter" value={filter} />}
            <button className="a-btn" type="submit">
              Search
            </button>
            {(q || filter) && (
              <Link className="a-btn ghost" href={`/admin/${resource}`}>
                Clear
              </Link>
            )}
          </form>
          <span className="a-help">{rows.length} shown</span>
        </div>

        {resource === "gallery" && <GalleryBulkUpload />}
        {resource === "menu-items" && <MenuPhotosUpload />}

        <BulkBar
          group={resource}
          endpoint={`/api/admin/${resource}/bulk`}
          noun={def.singular}
          actions={[
            ...(def.fields.some((f) => f.name === "published")
              ? [
                  { key: "show", label: "Show on website" },
                  { key: "hide", label: "Hide" },
                ]
              : []),
            { key: "delete", label: "Delete", danger: true },
          ]}
        />

        <div className="a-table-wrap">
          {rows.length ? (
            <table className="a-table">
              <thead>
                <tr>
                  <th className="a-col-check">
                    <input type="checkbox" data-bulk-all={resource} aria-label="Select all" />
                  </th>
                  {def.columns.map((c) => (
                    <th key={c.key}>{c.label}</th>
                  ))}
                  <th />
                </tr>
              </thead>
              <tbody>
                {rows.map((row: Record<string, any>) => (
                  <tr key={row.id}>
                    <td className="a-col-check">
                      <input type="checkbox" data-bulk={resource} value={row.id} aria-label="Select" />
                    </td>
                    {def.columns.map((c) => (
                      <td key={c.key}>
                        {c.key === titleKey ? (
                          <Link href={`/admin/${resource}/${row.id}`} className="title">
                            {String(row[c.key] || "(untitled)")}
                          </Link>
                        ) : c.key === "bookingCount" ? (
                          <Link href={`/admin/bookings?event=${row.id}`}>
                            <b>{row.bookingCount ?? 0}</b>
                            {row.capacity ? ` / ${row.capacity}` : ""}
                          </Link>
                        ) : (
                          cell(c, row)
                        )}
                      </td>
                    ))}
                    <td style={{ textAlign: "right" }}>
                      <Link href={`/admin/${resource}/${row.id}`} className="a-btn sm">
                        Edit
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          ) : (
            <p className="a-empty">
              Nothing here yet. <Link href={`/admin/${resource}/new`}>Add the first {def.singular}</Link>.
            </p>
          )}
        </div>
      </div>
    </>
  );
}
