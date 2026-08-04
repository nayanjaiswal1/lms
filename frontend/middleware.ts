import { NextResponse } from "next/server"
import type { NextRequest } from "next/server"

// Deny-by-default: every route requires a session unless it's listed here.
// Getting this list wrong in the "too short" direction just makes an
// unauthenticated visit to that one page bounce to /login when it shouldn't —
// annoying but obvious and easy to fix. Getting it wrong the other way (an
// entry too broad) is the direction that actually matters, so keep entries as
// narrow/exact as the route allows. Real authorization is still enforced by
// the Go backend regardless of this list; this middleware only decides
// whether the friendly silent-refresh-then-redirect flow applies before a
// server component would otherwise hit a raw 401.
const PUBLIC_EXACT_PATHS = new Set([
  "/",
  "/login",
  "/register",
  "/forgot-password",
  "/reset-password",
  "/verify-email",
  "/demo",
  "/demo/tour",
  "/legal/terms",
  "/legal/privacy",
  "/legal/refund-policy",
])

// Prefix matches — for route segments with dynamic children ([token], [uuid],
// [code], [...path]) or where nested auth is out of scope for this gate.
const PUBLIC_PREFIXES = [
  "/auth/callback", // OAuth redirect target — fires before any session cookie exists
  "/calendar/invite/", // (public) route group — public calendar-invite acceptance link
  "/certificates/", // (public) route group — public certificate verification link
  "/hire/", // (public) route group — public hiring-code landing link
  "/api/", // Route handlers do their own auth + return JSON 401s; a redirect here would break fetch() callers expecting JSON
]

function isPublicPath(pathname: string): boolean {
  if (PUBLIC_EXACT_PATHS.has(pathname)) return true
  return PUBLIC_PREFIXES.some((p) => pathname.startsWith(p))
}

// Decode JWT expiry from the payload without verifying the signature.
// Returns true if the token is expired or unparseable.
function jwtExpired(token: string): boolean {
  try {
    const parts = token.split(".")
    if (parts.length !== 3) return true
    const pad = parts[1].length % 4
    const b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/") + "=".repeat(pad ? 4 - pad : 0)
    const payload = JSON.parse(atob(b64)) as { exp?: number }
    if (!payload.exp) return true
    return Date.now() / 1000 >= payload.exp - 15   // 15s early margin
  } catch {
    return true
  }
}

// Builds a /login redirect that preserves the original path + query in `next`,
// instead of leaking the original search params onto the /login URL itself.
function loginRedirect(request: NextRequest): NextResponse {
  const next = request.nextUrl.pathname + request.nextUrl.search
  const url = request.nextUrl.clone()
  url.pathname = "/login"
  url.search = ""
  url.searchParams.set("next", next)
  return NextResponse.redirect(url)
}

export async function middleware(request: NextRequest): Promise<NextResponse> {
  const { pathname } = request.nextUrl

  if (isPublicPath(pathname)) return NextResponse.next()

  const accessToken  = request.cookies.get("access_token")?.value
  const refreshToken = request.cookies.get("refresh_token")?.value
  const csrfToken    = request.cookies.get("csrf_token")?.value

  // Token present and not expired — let through immediately.
  if (accessToken && !jwtExpired(accessToken)) return NextResponse.next()

  // No refresh token — redirect to login.
  if (!refreshToken) {
    return loginRedirect(request)
  }

  // Access token missing or expired — attempt a silent refresh.
  const backendUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL
  if (!backendUrl) {
    // Misconfiguration must not open the gate. Letting the request through
    // rendered a protected page for a caller whose session could not be
    // established — the server components behind it re-check, but this gate
    // should not be the thing relying on that.
    return loginRedirect(request)
  }

  try {
    const refreshRes = await fetch(`${backendUrl}/api/auth/refresh`, {
      method: "POST",
      headers: {
        // eslint-disable-next-line no-restricted-syntax -- middleware runs on the Edge runtime; lib/server/api.ts is server-only and can't be imported here. Both cookies are needed: refresh_token authenticates the rotation, csrf_token satisfies the CSRF guard now applied to /api/auth/refresh.
        Cookie: `refresh_token=${refreshToken}; csrf_token=${csrfToken ?? ""}`,
        "X-CSRF-Token": csrfToken ?? "",
        // Preserve the browser's address so the backend's auth rate limiter
        // does not bucket every user behind this server's own IP.
        ...(request.headers.get("x-forwarded-for")
          ? { "X-Forwarded-For": request.headers.get("x-forwarded-for") as string }
          : {}),
      },
      cache: "no-store",
    })

    if (!refreshRes.ok) {
      return loginRedirect(request)
    }

    // Refresh succeeded — redirect to the same URL so the browser stores the
    // new cookies before the page renders (server components read cookies from
    // the incoming request; we can't update them mid-render).
    const response = NextResponse.redirect(request.url)
    for (const value of refreshRes.headers.getSetCookie()) {
      response.headers.append("Set-Cookie", value)
    }
    return response
  } catch {
    // Backend unreachable. Send the user to /login rather than through: the
    // session could not be refreshed, so there is nothing to let through, and
    // an auth gate that opens when its dependency is down is not a gate.
    return loginRedirect(request)
  }
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|icons|apple-icon).*)"],
}
