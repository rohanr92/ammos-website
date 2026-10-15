/** Sticky title bar at the top of each admin page. */
export function PageTop({ title, actions }: { title: string; actions?: React.ReactNode }) {
  return (
    <header className="a-top">
      <h1>{title}</h1>
      <div className="a-row">{actions}</div>
    </header>
  );
}
