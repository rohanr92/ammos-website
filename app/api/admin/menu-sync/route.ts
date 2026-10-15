import { db } from "@/lib/db";
import { errorJson, json, rateLimit, withAdmin } from "@/lib/http";
import { fetchLiveMenu, parseMenu, syncMenu } from "@/lib/menu-import";
import { refreshSite } from "@/lib/revalidate";

export const runtime = "nodejs";

/** POST /api/admin/menu-sync → copy the live menu (ammos-beach-bar.nina.cy) into the website. */
export const POST = withAdmin(async (_req, _ctx, user) => {
  if (!rateLimit(`menu-sync:${user.id}`, 6, 10 * 60_000).ok) return errorJson("Please wait a few minutes before syncing again.", 429);
  let md: string;
  try {
    md = await fetchLiveMenu();
  } catch (err) {
    return errorJson(`Could not download the live menu: ${(err as Error).message}`, 502);
  }
  const result = await syncMenu(db, parseMenu(md));
  refreshSite();
  return json({ ok: true, ...result });
});
