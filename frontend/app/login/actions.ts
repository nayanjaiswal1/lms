"use server";

import { redirect } from "next/navigation";
import { AUTH_COPY, loginSchema } from "@/lib/validation/auth";
import { asString, getField, resolveLoginDestination } from "@/lib/server/login-destination";
import { startMfaStep } from "@/lib/server/mfa-challenge";
import { apiAction, type ActionResult, baseURL } from "@/lib/server/api";
import { captchaHeaders } from "@/lib/server/captcha";
import { authFetchWithCookies } from "@/lib/server/auth-fetch";
import type { WebAuthnRequestOptions } from "@/lib/webauthn";
import { safeNextPath } from "@/lib/utils";

// Result surfaced back to the form via useActionState.
//   error       — top-level failure (bad credentials, rate limit, network…)
//   fieldErrors — per-field messages (only hit if a request bypasses client validation)
export interface LoginState {
  error?: string;
  fieldErrors?: { email?: string; password?: string };
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
  let apiUrl: string;
  try {
    apiUrl = baseURL();
  } catch {
    console.error("[login] BACKEND_URL is not set");
    return { error: AUTH_COPY.configMissing };
  }

  // 2. Exchange credentials with the Go API.
  let response: Response;
  let body: unknown;
  try {
    const result = await authFetchWithCookies("/api/auth/login", parsed.data, {
      headers: captchaHeaders(formData),
    });
    response = result.response;
    body = result.body;
  } catch {
    return { error: AUTH_COPY.network };
  }

  if (!response.ok) {
    return { error: resolveError(response.status, body) };
  }

  // 3. Re-emit the auth cookies the API set, then route into the app.
  //    redirect() throws NEXT_REDIRECT, so it must run outside any try/catch.
  const next = safeNextPath(formData.get("next")?.toString());
  // Accounts with MFA (and privileged roles, which must have it) get a
  // challenge instead of a session — no cookies were minted yet.
  const mfaStep = await startMfaStep(body, next);
  if (mfaStep) redirect(mfaStep);
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

interface PasskeyLoginResult {
  error?: string;
  redirectTo?: string;
}

export async function loginPasskeyFinishAction(
  handle: string,
  credentialResponse: unknown,
  next?: string,
): Promise<PasskeyLoginResult> {
  let apiUrl: string;
  try {
    apiUrl = baseURL();
  } catch {
    console.error("[login] BACKEND_URL is not set");
    return { error: AUTH_COPY.configMissing };
  }

  let response: Response;
  let body: unknown;
  try {
    const result = await authFetchWithCookies("/api/auth/webauthn/login/finish", {
      handle,
      response: credentialResponse,
    });
    response = result.response;
    body = result.body;
  } catch {
    return { error: AUTH_COPY.network };
  }

  if (!response.ok) {
    return { error: resolveError(response.status, body) };
  }

  const redirectTo = await resolveLoginDestination(apiUrl, response, body, safeNextPath(next));
  return { redirectTo };
}

