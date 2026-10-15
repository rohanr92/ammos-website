import Link from "next/link";
import { notFound } from "next/navigation";
import { RESOURCE_MAP } from "@/lib/admin/resources";
import { getRow, menuCategoryOptions, toFormValues } from "@/lib/admin/resources.server";
import { PageTop } from "@/components/admin/PageTop";
import { ResourceForm } from "@/components/admin/ResourceForm";

type Props = { params: Promise<{ resource: string; id: string }>; searchParams: Promise<{ saved?: string }> };

export async function generateMetadata({ params }: Props) {
  const { resource, id } = await params;
  const def = RESOURCE_MAP[resource];
  return { title: def ? `${id === "new" ? "New" : "Edit"} ${def.singular}` : "Admin" };
}

export default async function ResourceEdit({ params, searchParams }: Props) {
  const { resource, id } = await params;
  const { saved } = await searchParams;
  const def = RESOURCE_MAP[resource];
  if (!def) notFound();

  const isNew = id === "new";
  const row = isNew ? null : await getRow(resource, id);
  if (!isNew && !row) notFound();

  const fields = await Promise.all(
    def.fields.map(async (f) => (f.type === "relation" && f.relation === "menuCategories" ? { ...f, options: await menuCategoryOptions() } : f)),
  );
  const initial = toFormValues(def, row);
  if (isNew && resource === "news") initial.publishedAt = toFormValues(def, { publishedAt: new Date() }).publishedAt;

  const viewUrl = row && def.viewPath ? def.viewPath.replace(":slug", String(row.slug ?? "")) : null;
  const title = isNew ? `New ${def.singular}` : String(row?.title ?? row?.name ?? row?.fromPath ?? row?.alt ?? `Edit ${def.singular}`);

  return (
    <>
      <PageTop
        title={title}
        actions={
          <Link href={`/admin/${resource}`} className="a-btn ghost">
            ← Back to {def.title.toLowerCase()}
          </Link>
        }
      />
      <div className="a-content" style={{ maxWidth: 980 }}>
        {saved && <p className="a-msg ok" style={{ marginBottom: 16 }}>Created and published. You can keep editing below.</p>}
        {resource === "events" && row && (
          <p className="a-desc">
            <Link href={`/admin/bookings?event=${row.id}`}>See bookings for this event →</Link>
          </p>
        )}
        <ResourceForm resource={resource} singular={def.singular} id={isNew ? null : id} fields={fields} initial={initial} viewUrl={viewUrl} />
      </div>
    </>
  );
}
