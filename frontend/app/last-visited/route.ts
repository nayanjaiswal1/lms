import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { LAST_PAGE_COOKIE } from "@/lib/constants";
import ROUTES from "@/lib/routes";
import { getCurrentUser } from "@/lib/server/auth";
import { safeNextPath } from "@/lib/utils";

// Landing target for users whose default_landing_page is "last visited".
// Cookie first (this browser); the synced DB value covers a fresh device.
export async function GET(): Promise<never> {
  const cookieValue = (await cookies()).get(LAST_PAGE_COOKIE)?.value;
  const last =
    safeNextPath(cookieValue) ??
    safeNextPath((await getCurrentUser().catch(() => null))?.last_page);
  redirect(last ?? ROUTES.DASHBOARD);
}
