import { type NextRequest, NextResponse } from "next/server";
import { forwardSetCookies } from "@/lib/server/set-cookie";
import { resolveLegalGateRedirect } from "@/lib/server/legal";
import ROUTES from "@/lib/routes";

// Receives the one-time exchange token from the Go OAuth callback redirect,
// exchanges it for full session cookies, and sends the browser to the app.
export async function GET(req: NextRequest) {
  const token = req.nextUrl.searchParams.get("token");

  // Anchor redirects to the canonical app origin, not req.url — req.url is
  // whatever host the request actually landed on (e.g. the frontend
  // container's internal 0.0.0.0:3000 dev-server origin if Caddy was
  // bypassed), which would bounce the browser to a URL it can't use again.
  const appUrl = process.env.NEXT_PUBLIC_APP_URL ?? req.url;
  const loginUrl = new URL(ROUTES.LOGIN, appUrl);

  if (!token) {
    loginUrl.searchParams.set("error", "missing_token");
    return NextResponse.redirect(loginUrl);
  }

  const apiUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!apiUrl) {
    loginUrl.searchParams.set("error", "config");
    return NextResponse.redirect(loginUrl);
  }

  let res: Response;
  try {
    res = await fetch(`${apiUrl}/api/auth/social/exchange`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(req.headers.get("x-forwarded-for")
          ? { "X-Forwarded-For": req.headers.get("x-forwarded-for") as string }
          : {}),
      },
      body: JSON.stringify({ token }),
      cache: "no-store",
    });
  } catch {
    loginUrl.searchParams.set("error", "network");
    return NextResponse.redirect(loginUrl);
  }

  if (!res.ok) {
    loginUrl.searchParams.set("error", "exchange_failed");
    return NextResponse.redirect(loginUrl);
  }

  const body: unknown = await res.json().catch(() => null);

  // Forward auth cookies (access_token, refresh_token, csrf_token) from Go to
  // the browser's Next.js origin via the server-side cookie store.
  await forwardSetCookies(res.headers);

  // Same platform-level terms/privacy gate the password and passkey flows
  // apply — without this, social sign-in would skip re-acceptance on a
  // policy-version bump.
  const legalRedirect = await resolveLegalGateRedirect(apiUrl, res.headers);
  if (legalRedirect) {
    return NextResponse.redirect(new URL(legalRedirect, req.url));
  }

  const data =
    body && typeof body === "object"
      ? (body as Record<string, unknown>).data
      : undefined;

  const onboardingCompleted =
    data && typeof data === "object"
      ? (data as Record<string, unknown>).onboarding_completed
      : undefined;

  const redirectTo =
    onboardingCompleted === false ? ROUTES.ONBOARDING : ROUTES.DASHBOARD;

  return NextResponse.redirect(new URL(redirectTo, req.url));
}
