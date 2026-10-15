import "server-only";
import { revalidatePath } from "next/cache";

/** After any change in the admin, refresh every cached public page so visitors see it immediately. */
export function refreshSite() {
  revalidatePath("/", "layout");
}
