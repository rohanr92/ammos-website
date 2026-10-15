import { Fragment } from "react";
import { lines } from "@/lib/utils";

/** Renders text where each new line becomes a <br>. */
export function MultiLine({ text }: { text?: string | null }) {
  const parts = lines(text);
  return (
    <>
      {parts.map((p, i) => (
        <Fragment key={i}>
          {p}
          {i < parts.length - 1 && <br />}
        </Fragment>
      ))}
    </>
  );
}
