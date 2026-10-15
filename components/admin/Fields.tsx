"use client";

import { MediaInput } from "@/components/admin/MediaInput";
import { MultiImageInput } from "@/components/admin/MultiImageInput";

/** One field description — works for both resource forms and page-content forms. */
export type AnyField = {
  name: string;
  label: string;
  type: string;
  required?: boolean;
  help?: string;
  half?: boolean;
  options?: { value: string; label: string }[];
  suggestions?: string[];
  fields?: AnyField[];
  itemLabel?: string;
};

type Values = Record<string, any>;

export function FieldInput({ field, value, onChange, idPrefix = "f" }: { field: AnyField; value: any; onChange: (v: any) => void; idPrefix?: string }) {
  const id = `${idPrefix}-${field.name}`;
  const label = (
    <label htmlFor={id}>
      {field.label}
      {field.required && <span className="req"> *</span>}
    </label>
  );
  const help = field.help ? <span className="a-help">{field.help}</span> : null;
  const cls = `a-field${field.half ? " half" : ""}`;
  const str = value === null || value === undefined ? "" : String(value);

  switch (field.type) {
    case "checkbox":
      return (
        <div className={cls}>
          <label className="a-check">
            <input id={id} type="checkbox" checked={Boolean(value)} onChange={(e) => onChange(e.target.checked)} />
            <span>{field.label}</span>
          </label>
          {help}
        </div>
      );
    case "textarea":
    case "richtext":
      return (
        <div className={cls}>
          {label}
          <textarea id={id} className={`a-input${field.type === "richtext" ? " rich" : ""}`} value={str} required={field.required} onChange={(e) => onChange(e.target.value)} />
          {field.type === "richtext" ? (
            <span className="a-help">
              {field.help ? `${field.help} · ` : ""}Empty line = new paragraph · <code>## Heading</code> · <code>- bullet</code> · <code>**bold**</code> · <code>[link text](https://…)</code>
            </span>
          ) : (
            help
          )}
        </div>
      );
    case "image":
    case "video":
      return (
        <div className={cls}>
          {label}
          <MediaInput id={id} value={str} onChange={onChange} kind={field.type as "image" | "video"} />
          {help}
        </div>
      );
    case "select":
    case "relation":
      return (
        <div className={cls}>
          {label}
          <select id={id} className="a-input" value={str} required={field.required} onChange={(e) => onChange(e.target.value)}>
            {!field.required || !str ? <option value="">— choose —</option> : null}
            {(field.options ?? []).map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
          {help}
        </div>
      );
    case "datetime":
      return (
        <div className={cls}>
          {label}
          <input id={id} type="datetime-local" className="a-input" value={str} required={field.required} onChange={(e) => onChange(e.target.value)} />
          {help}
        </div>
      );
    case "number":
    case "price":
      return (
        <div className={cls}>
          {label}
          <input id={id} type="number" inputMode="decimal" step={field.type === "price" ? "0.01" : "1"} min={0} className="a-input" value={str} required={field.required} onChange={(e) => onChange(e.target.value)} />
          {help}
        </div>
      );
    case "images":
      return (
        <div className={cls}>
          <span className="a-label">{field.label}</span>
          {help}
          <MultiImageInput value={Array.isArray(value) ? value : []} onChange={onChange} />
        </div>
      );
    case "list":
      return <ListInput field={field} value={Array.isArray(value) ? value : []} onChange={onChange} idPrefix={id} />;
    default: {
      const listId = field.suggestions?.length ? `${id}-list` : undefined;
      return (
        <div className={cls}>
          {label}
          <input
            id={id}
            type={field.type === "email" ? "email" : field.type === "url" ? "url" : "text"}
            className="a-input"
            value={str}
            required={field.required}
            list={listId}
            placeholder={field.type === "slug" ? "created automatically" : undefined}
            onChange={(e) => onChange(e.target.value)}
          />
          {listId && (
            <datalist id={listId}>
              {field.suggestions!.map((s) => (
                <option key={s} value={s} />
              ))}
            </datalist>
          )}
          {help}
        </div>
      );
    }
  }
}

/** Repeatable group of fields (timeline items, opening hours, polaroids…). */
function ListInput({ field, value, onChange, idPrefix }: { field: AnyField; value: Values[]; onChange: (v: Values[]) => void; idPrefix: string }) {
  const empty = () => Object.fromEntries((field.fields ?? []).map((f) => [f.name, f.type === "checkbox" ? false : ""]));
  const update = (i: number, key: string, v: unknown) => onChange(value.map((item, j) => (j === i ? { ...item, [key]: v } : item)));
  const move = (i: number, d: number) => {
    const j = i + d;
    if (j < 0 || j >= value.length) return;
    const next = [...value];
    [next[i], next[j]] = [next[j], next[i]];
    onChange(next);
  };
  return (
    <div className="a-field">
      <span className="a-label">{field.label}</span>
      {field.help && <span className="a-help">{field.help}</span>}
      <div className="a-list">
        {value.map((item, i) => (
          <div key={i} className="a-list-item">
            <div className="a-list-head">
              <span>
                {field.itemLabel ?? "Item"} {i + 1}
              </span>
              <span className="a-row">
                <button type="button" className="a-btn sm ghost" onClick={() => move(i, -1)} disabled={i === 0} aria-label="Move up">
                  ↑
                </button>
                <button type="button" className="a-btn sm ghost" onClick={() => move(i, 1)} disabled={i === value.length - 1} aria-label="Move down">
                  ↓
                </button>
                <button type="button" className="a-btn sm danger" onClick={() => onChange(value.filter((_, j) => j !== i))}>
                  Remove
                </button>
              </span>
            </div>
            <div className="a-form">
              {(field.fields ?? []).map((sub) => (
                <FieldInput
                  key={sub.name}
                  field={{ ...sub, half: (field.fields?.length ?? 0) > 2 && sub.type !== "textarea" && sub.type !== "richtext" && sub.type !== "image" }}
                  value={item[sub.name]}
                  onChange={(v) => update(i, sub.name, v)}
                  idPrefix={`${idPrefix}-${i}`}
                />
              ))}
            </div>
          </div>
        ))}
      </div>
      <div>
        <button type="button" className="a-btn" onClick={() => onChange([...value, empty()])}>
          + Add {(field.itemLabel ?? "item").toLowerCase()}
        </button>
      </div>
    </div>
  );
}
