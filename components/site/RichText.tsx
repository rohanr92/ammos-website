import { Fragment, type ReactNode } from "react";

/**
 * Very small, safe formatter for texts written in the admin panel.
 *   empty line      → new paragraph
 *   ## Heading      → heading
 *   ### Sub heading → smaller heading
 *   - item          → bullet list
 *   **bold**        → bold
 *   [text](https://link) → link
 * No HTML is ever injected, so it is safe from script injection.
 */
export function RichText({ text, className = "prose" }: { text?: string | null; className?: string }) {
  const blocks = String(text ?? "")
    .replace(/\r\n/g, "\n")
    .split(/\n{2,}/)
    .map((b) => b.trim())
    .filter(Boolean);

  const out: ReactNode[] = [];
  blocks.forEach((block, bi) => {
    const rows = block.split("\n");
    let para: string[] = [];
    let list: string[] = [];
    const flushPara = (k: string) => {
      if (para.length) {
        out.push(
          <p key={k}>
            {para.map((l, i) => (
              <Fragment key={i}>
                {inline(l)}
                {i < para.length - 1 && <br />}
              </Fragment>
            ))}
          </p>,
        );
        para = [];
      }
    };
    const flushList = (k: string) => {
      if (list.length) {
        out.push(
          <ul key={k}>
            {list.map((l, i) => (
              <li key={i}>{inline(l)}</li>
            ))}
          </ul>,
        );
        list = [];
      }
    };
    rows.forEach((row, ri) => {
      const key = `${bi}-${ri}`;
      if (row.startsWith("### ")) {
        flushPara(`p${key}`);
        flushList(`l${key}`);
        out.push(<h3 key={`h${key}`}>{inline(row.slice(4))}</h3>);
      } else if (row.startsWith("## ")) {
        flushPara(`p${key}`);
        flushList(`l${key}`);
        out.push(<h2 key={`h${key}`}>{inline(row.slice(3))}</h2>);
      } else if (/^[-*•] /.test(row)) {
        flushPara(`p${key}`);
        list.push(row.slice(2));
      } else {
        flushList(`l${key}`);
        para.push(row);
      }
    });
    flushPara(`pe${bi}`);
    flushList(`le${bi}`);
  });

  return <div className={className}>{out}</div>;
}

function inline(text: string): ReactNode[] {
  const nodes: ReactNode[] = [];
  const re = /\*\*(.+?)\*\*|\[([^\]]+)\]\(((?:https?:\/\/|mailto:|tel:|\/)[^\s)]+)\)|((?:https?:\/\/)[^\s)]+)|([\w.+-]+@[\w-]+\.[\w.]+)/g;
  let last = 0;
  let m: RegExpExecArray | null;
  let i = 0;
  while ((m = re.exec(text))) {
    if (m.index > last) nodes.push(text.slice(last, m.index));
    if (m[1]) nodes.push(<strong key={i++}>{m[1]}</strong>);
    else if (m[2]) {
      const external = /^https?:/.test(m[3]);
      nodes.push(
        <a key={i++} href={m[3]} {...(external ? { target: "_blank", rel: "noopener noreferrer" } : {})}>
          {m[2]}
        </a>,
      );
    } else if (m[4]) {
      nodes.push(
        <a key={i++} href={m[4]} target="_blank" rel="noopener noreferrer">
          {m[4]}
        </a>,
      );
    } else if (m[5]) {
      nodes.push(
        <a key={i++} href={`mailto:${m[5]}`}>
          {m[5]}
        </a>,
      );
    }
    last = m.index + m[0].length;
  }
  if (last < text.length) nodes.push(text.slice(last));
  return nodes;
}
