"use server";

import { redirect } from "next/navigation";
import { forwardSetCookies } from "@/lib/server/set-cookie";
import { resolveLegalGateRedirect } from "@/lib/server/legal";
import ROUTES from "@/lib/routes";
import { baseURL } from "@/lib/server/api";
import { authFetchWithCookies } from "@/lib/server/auth-fetch";

function getField(source: unknown, key: string): unknown {
  return source && typeof source === "object"
    ? (source as Record<string, unknown>)[key]
    : undefined;
}

function orgCount(body: unknown): number {
  const orgs = getField(getField(body, "data"), "orgs");
  return Array.isArray(orgs) ? orgs.length : 0;
}

export async function demoLoginAction(formData: FormData): Promise<void> {
  const email = (formData.get("email") ?? "").toString();
  const password = (formData.get("password") ?? "").toString();

  if (!email || !password) {
    redirect(`${ROUTES.DEMO}?error=1`);
  }

  let apiUrl: string;
  try {
    apiUrl = baseURL();
  } catch {
    redirect(`${ROUTES.DEMO}?error=1`);
  }

  let response: Response;
  let body: unknown;
  try {
    const result = await authFetchWithCookies("/api/auth/login", { email, password });
    response = result.response;
    body = result.body;
  } catch {
    redirect(`${ROUTES.DEMO}?error=1`);
  }

  if (!response.ok) {
    redirect(`${ROUTES.DEMO}?error=1`);
  }

  await forwardSetCookies(response.headers);

  const legalRedirect = await resolveLegalGateRedirect(apiUrl, response.headers);
  if (legalRedirect) redirect(legalRedirect);

  const onboardingCompleted = getField(getField(body, "data"), "onboarding_completed");
  if (onboardingCompleted === false) {
    redirect(ROUTES.ONBOARDING);
  }

  redirect(orgCount(body) > 1 ? ROUTES.ORG_SELECT : ROUTES.DASHBOARD);
}
