import ROUTES from "@/lib/routes";

function getField(source: unknown, key: string): unknown {
  return source && typeof source === "object"
    ? (source as Record<string, unknown>)[key]
    : undefined;
}

// Terms/Privacy acceptance is a platform-level gate checked right after a
// session is minted, before onboarding or org-select — this way a
// policy-version bump catches every sign-in path (password, passkey, social)
// in one place instead of each auth flow duplicating the check.
export async function resolveLegalGateRedirect(
  apiUrl: string,
  mintedCookies: Headers,
  next?: string | null,
): Promise<string | null> {
  const accessTokenCookie = mintedCookies.getSetCookie?.()
    .find((c) => c.startsWith("access_token="));
  if (!accessTokenCookie) return null;

  const statusRes = await fetch(`${apiUrl}/api/legal/status`, {
    headers: {
      // eslint-disable-next-line no-restricted-syntax -- the token being forwarded isn't in the cookie store yet (the login/exchange response just set it), so next/headers cookies() can't see it.
      Cookie: accessTokenCookie.split(";")[0],
    },
    cache: "no-store",
  }).catch(() => null);
  if (!statusRes?.ok) return null;

  const statusBody: unknown = await statusRes.json().catch(() => null);
  const needsAcceptance = getField(getField(statusBody, "data"), "needs_acceptance");
  if (!Array.isArray(needsAcceptance) || needsAcceptance.length === 0) return null;

  const target = new URLSearchParams();
  if (next) target.set("next", next);
  return `${ROUTES.LEGAL_ACCEPT}${target.size > 0 ? `?${target}` : ""}`;
}
