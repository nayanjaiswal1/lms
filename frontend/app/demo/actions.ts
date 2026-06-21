"use server";

import { redirect } from "next/navigation";
import { forwardSetCookies } from "@/lib/server/set-cookie";
import ROUTES from "@/lib/routes";

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

  const apiUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!apiUrl) {
    redirect(`${ROUTES.DEMO}?error=1`);
  }

  let response: Response;
  try {
    response = await fetch(`${apiUrl}/api/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
      cache: "no-store",
    });
  } catch {
    redirect(`${ROUTES.DEMO}?error=1`);
  }

  if (!response.ok) {
    redirect(`${ROUTES.DEMO}?error=1`);
  }

  const body: unknown = await response.json().catch(() => null);

  await forwardSetCookies(response.headers);

  const onboardingCompleted = getField(getField(body, "data"), "onboarding_completed");
  if (onboardingCompleted === false) {
    redirect(ROUTES.ONBOARDING);
  }

  redirect(orgCount(body) > 1 ? ROUTES.ORG_SELECT : ROUTES.DASHBOARD);
}
