"use server";

import { redirect } from "next/navigation";
import { apiAction } from "@/lib/server/api";
import type { ActionResult } from "@/lib/server/api";
import ROUTES from "@/lib/routes";

/** Accepts an org invite (the emailed token), then lets the user pick the org. */
export async function joinOrgAction(token: string): Promise<ActionResult> {
  const result = await apiAction("POST", "/api/orgs/join", { token });
  if (result.error) return result;
  redirect(ROUTES.ORG_SELECT);
}
