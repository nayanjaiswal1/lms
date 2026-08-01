"use server";

import { redirect } from "next/navigation";
import { AUTH_COPY, loginSchema } from "@/lib/validation/auth";
import { forwardSetCookies } from "@/lib/server/set-cookie";
import { apiAction, type ActionResult, clientIpHeaders } from "@/lib/server/api";
import type { WebAuthnRequestOptions } from "@/lib/webauthn";
import ROUTES from "@/lib/routes";
import { safeNextPath } from "@/lib/utils";

// Result surfaced back to the form via useActionState.
//   error       — top-level failure (bad credentials, rate limit, network…)
//   fieldErrors — per-field messages (only hit if a request bypasses client validation)
export interface LoginState {
  error?: string;
  fieldErrors?: { email?: string; password?: string };
}

// ── Narrowing helpers for the untyped JSON body ──────────────────────────────
function getField(source: unknown, key: string): unknown {
  return source && typeof source === "object"
    ? (source as Record<string, unknown>)[key]
    : undefined;
}

function asString(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

function resolveError(status: number, body: unknown): string {
  const apiMessage = asString(getField(body, "error"));
  switch (status) {
    case 400:
    case 401:
      return apiMessage ?? AUTH_COPY.invalidCredentials;
    case 403:
      return apiMessage ?? AUTH_COPY.ssoRequired;
    case 429:
      return AUTH_COPY.rateLimited;
    default:
      return apiMessage ?? AUTH_COPY.unexpected;
  }
}

// A user belonging to more than one org picks one before landing in the app.
function orgCount(body: unknown): number {
  const orgs = getField(getField(body, "data"), "orgs");
  return Array.isArray(orgs) ? orgs.length : 0;
}

export async function loginAction(
  _prev: LoginState,
  formData: FormData,
): Promise<LoginState> {
  // 1. Validate at the boundary — same schema the client used.
  const parsed = loginSchema.safeParse({
    email: (formData.get("email") ?? "").toString(),
    password: (formData.get("password") ?? "").toString(),
  });

  if (!parsed.success) {
    const fields = parsed.error.flatten().fieldErrors;
    return {
      fieldErrors: { email: fields.email?.[0], password: fields.password?.[0] },
    };
  }

  // BACKEND_URL is the private server-to-server URL (never sent to the browser).
  // Falls back to NEXT_PUBLIC_API_URL for simple single-host setups.
  const apiUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!apiUrl) {
    console.error("[login] BACKEND_URL is not set");
    return { error: AUTH_COPY.configMissing };
  }

  // 2. Exchange credentials with the Go API.
  let response: Response;
  try {
    response = await fetch(`${apiUrl}/api/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json", ...(await clientIpHeaders()) },
      body: JSON.stringify(parsed.data),
      cache: "no-store",
    });
  } catch {
    return { error: AUTH_COPY.network };
  }

  const body: unknown = await response.json().catch(() => null);

  if (!response.ok) {
    return { error: resolveError(response.status, body) };
  }

  // 3. Re-emit the auth cookies the API set, then route into the app.
  //    redirect() throws NEXT_REDIRECT, so it must run outside any try/catch.
  const next = safeNextPath(formData.get("next")?.toString());
  const dest = await resolveLoginDestination(apiUrl, response, body, next);
  redirect(dest);
}

// ── Passkey (WebAuthn) sign-in ────────────────────────────────────────────────
//
// begin uses the normal authenticated-fetch helper — the endpoint is public
// and mints no cookies. finish DOES mint cookies (same as loginAction step 2
// above), so it needs the same raw-fetch + forwardSetCookies treatment;
// apiAction swallows response headers and can't carry Set-Cookie through.
//
// Unlike loginAction, finish is invoked directly from a client component
// (not dispatched through useActionState's form action), so it returns the
// destination instead of calling redirect() itself — relying on a bare
// server-action call to propagate a thrown redirect back through a manual
// try/catch in the caller is fragile. The button navigates on success.

interface WebAuthnLoginBeginResult {
  handle: string;
  options: WebAuthnRequestOptions;
}

export async function loginPasskeyBeginAction(
  email?: string,
): Promise<ActionResult<WebAuthnLoginBeginResult>> {
  return apiAction<WebAuthnLoginBeginResult>(
    "POST",
    "/api/auth/webauthn/login/begin",
    { email: email ?? "" },
  );
}

export interface PasskeyLoginResult {
  error?: string;
  redirectTo?: string;
}

export async function loginPasskeyFinishAction(
  handle: string,
  credentialResponse: unknown,
  next?: string,
): Promise<PasskeyLoginResult> {
  const apiUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!apiUrl) {
    console.error("[login] BACKEND_URL is not set");
    return { error: AUTH_COPY.configMissing };
  }

  let response: Response;
  try {
    response = await fetch(`${apiUrl}/api/auth/webauthn/login/finish`, {
      method: "POST",
      headers: { "Content-Type": "application/json", ...(await clientIpHeaders()) },
      body: JSON.stringify({ handle, response: credentialResponse }),
      cache: "no-store",
    });
  } catch {
    return { error: AUTH_COPY.network };
  }

  const body: unknown = await response.json().catch(() => null);

  if (!response.ok) {
    return { error: resolveError(response.status, body) };
  }

  const redirectTo = await resolveLoginDestination(apiUrl, response, body, safeNextPath(next));
  return { redirectTo };
}

// Shared cookie-mint + destination logic for every flow that ends in a fresh
// session (password login, passkey login). Forwards the Set-Cookie headers
// from the login response, auto-switches into a user's only org, and returns
// where the caller should navigate next.
async function resolveLoginDestination(
  apiUrl: string,
  response: Response,
  body: unknown,
  next: string | null,
): Promise<string> {
  await forwardSetCookies(response.headers);

  const onboardingCompleted = getField(getField(body, "data"), "onboarding_completed");
  if (onboardingCompleted === false) {
    return ROUTES.ONBOARDING;
  }

  const count = orgCount(body);
  if (count > 1) {
    return ROUTES.ORG_SELECT;
  }

  // Single org: auto-switch so the access token carries an org_id and
  // permission queries work immediately without a manual org-select step.
  if (count === 1) {
    const orgs = getField(getField(body, "data"), "orgs");
    const orgId = asString(getField(Array.isArray(orgs) ? orgs[0] : undefined, "id"));
    if (orgId) {
      const switchRes = await fetch(`${apiUrl}/api/orgs/switch`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          // Forward the new access token the login response just set.
          // eslint-disable-next-line no-restricted-syntax -- can't use authHeaders()/apiAction here, the token being forwarded isn't in the cookie store yet (this response set it, next/headers cookies() hasn't seen it).
          Cookie: response.headers.getSetCookie?.()
            .filter((c) => c.startsWith("access_token="))
            .join("; ") ?? "",
        },
        body: JSON.stringify({ org_id: orgId }),
        cache: "no-store",
      }).catch(() => null);
      if (switchRes?.ok) await forwardSetCookies(switchRes.headers);
    }
  }

  return next ?? ROUTES.DASHBOARD;
}
