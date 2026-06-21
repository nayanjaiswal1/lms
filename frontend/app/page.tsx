import { cookies } from "next/headers";
import { redirect } from "next/navigation";

import ROUTES from "@/lib/routes";

export default async function RootPage() {
  const cookieStore = await cookies();
  const accessToken = cookieStore.get("access_token")?.value;

  if (accessToken) {
    redirect(ROUTES.DASHBOARD);
  }

  redirect(ROUTES.LOGIN);
}
