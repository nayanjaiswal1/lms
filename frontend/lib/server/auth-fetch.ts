import "server-only";

import { baseURL, clientIpHeaders } from "@/lib/server/api";
import { forwardSetCookies } from "@/lib/server/set-cookie";

// Shared unauthenticated backend fetch for flows that mint or rotate session
// cookies (login, passkey finish, register, verify-email, demo, org switch,
// org create, calendar-invite accept, OAuth exchange). apiAction/apiGet can't
// be reused here — they only read existing cookies and never capture
// Set-Cookie from the response, so every one of these flows needs the raw
// Response for forwardSetCookies() plus status-code branching the
// ActionResult shape can't express.
//
// Always POSTs JSON with the client-IP headers and forwards any Set-Cookie
// the backend issued (no-op when there is none). Returns the raw Response
// plus the parsed body so callers keep their own error mapping
// (resolveError/getError/actionErrorMessage). Throws on missing config or
// network failure — callers translate those into their own copy.
export interface AuthFetchResult {
  response: Response;
  body: unknown;
}

export async function authFetchWithCookies(
  path: string,
  payload?: unknown,
  init?: { method?: string; headers?: Record<string, string> },
): Promise<AuthFetchResult> {
  const res = await fetch(`${baseURL()}${path}`, {
    method: init?.method ?? "POST",
    headers: {
      "Content-Type": "application/json",
      ...(await clientIpHeaders()),
      ...init?.headers,
    },
    body: payload !== undefined ? JSON.stringify(payload) : undefined,
    cache: "no-store",
  });
  await forwardSetCookies(res.headers).catch(() => undefined);
  const body: unknown = await res.json().catch(() => null);
  return { response: res, body };
}
