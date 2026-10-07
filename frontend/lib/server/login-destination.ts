import "server-only";

import { forwardSetCookies } from "@/lib/server/set-cookie";
import { resolveLegalGateRedirect } from "@/lib/server/legal";
import { authFetchWithCookies } from "@/lib/server/auth-fetch";
import ROUTES from "@/lib/routes";

// ── Narrowing helpers for the untyped JSON body ──────────────────────────────
export function getField(source: unknown, key: string): unknown {
  return source && typeof source === "object"
    ? (source as Record<string, unknown>)[key]
    : undefined;
}

export function asString(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

// A user belonging to more than one org picks one before landing in the app.
function orgCount(body: unknown): number {
  const orgs = getField(getField(body, "data"), "orgs");
  return Array.isArray(orgs) ? orgs.length : 0;
}

// Shared cookie-mint + destination logic for every flow that ends in a fresh
// session (password login, passkey login). Forwards the Set-Cookie headers
// from the login response, auto-switches into a user's only org, and returns
// where the caller should navigate next.
export async function resolveLoginDestination(
  apiUrl: string,
  response: Response,
  body: unknown,
  next: string | null,
): Promise<string> {
  await forwardSetCookies(response.headers);

  const legalRedirect = await resolveLegalGateRedirect(apiUrl, response.headers, next);
  if (legalRedirect) return legalRedirect;

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
      // Forward the new access token the login response just set.
      // Can't use authHeaders()/apiAction here — the token being forwarded
      // isn't in the cookie store yet (this response set it, next/headers
      // cookies() hasn't seen it).
      const accessCookie =
        response.headers.getSetCookie?.()
          .filter((c) => c.startsWith("access_token="))
          .join("; ") ?? "";
      const switchRes = await authFetchWithCookies(
        "/api/orgs/switch",
        { org_id: orgId },
        // eslint-disable-next-line no-restricted-syntax -- see comment above; raw token forward required for forwardSetCookies.
        { headers: accessCookie ? { Cookie: accessCookie } : {} },
      ).catch(() => null);
      void switchRes;
    }
  }

  // The root page redirects authenticated users to their chosen landing page.
  return next ?? ROUTES.HOME;
}
