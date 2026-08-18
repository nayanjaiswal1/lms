import { NextResponse } from "next/server"
import type { NextRequest } from "next/server"

// Deny-by-default: every route requires a session unless it's listed here.
// Getting this list wrong in the "too short" direction just makes an
// unauthenticated visit to that one page bounce to /login when it shouldn't —
// annoying but obvious and easy to fix. Getting it wrong the other way (an
// entry too broad) is the direction that actually matters, so keep entries as
// narrow/exact as the route allows. Real authorization is still enforced by
// the Go backend regardless of this list; this proxy only decides whether
// the friendly silent-refresh flow applies before a server component would
// otherwise hit a raw 401.
const PUBLIC_EXACT_PATHS = new Set([
  "/",
  "/org", // org marketing landing — distinct from the authenticated /org/create, /org/settings, /org/setup routes below
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

export async function proxy(request: NextRequest): Promise<NextResponse> {
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
        // eslint-disable-next-line no-restricted-syntax -- Proxy runs before Server Components render; lib/server/api.ts is server-only (next/headers-backed) and can't be imported here. Both cookies are needed: refresh_token authenticates the rotation, csrf_token satisfies the CSRF guard now applied to /api/auth/refresh.
        Cookie: `refresh_token=${refreshToken}; csrf_token=${csrfToken ?? ""}`,
        "X-CSRF-Token": csrfToken ?? "",
        // Preserve the browser's address so the backend's auth rate limiter
        // does not bucket every user behind this server's own IP.
        ...(request.headers.get("x-forwarded-for")
          ? { "X-Forwarded-For": request.headers.get("x-forwarded-for") as string }
          : {}),
      },
      cache: "no-store",
      // Bound the stall: an unbounded fetch here blocks every navigation on
      // this backend call with nothing on screen (no loading.tsx fires for a
      // redirect). Timing out and sending the user to /login is strictly
      // better than hanging the whole app for an indeterminate time.
      signal: AbortSignal.timeout(5000),
    })

    if (!refreshRes.ok) {
      return loginRedirect(request)
    }

    // Refresh succeeded. Forward the new cookies into *this* request instead
    // of redirecting: request.cookies.set() rewrites the Cookie header that
    // NextResponse.next({ request }) forwards downstream, so the Server
    // Components rendering this same response already see the fresh
    // access_token via cookies() — no second navigation round trip. The
    // browser still gets the real Set-Cookie headers (with their original
    // attributes) so subsequent requests carry the refreshed token too.
    const setCookies = refreshRes.headers.getSetCookie()
    for (const raw of setCookies) {
      const pair = raw.split(";", 1)[0]
      const eq = pair.indexOf("=")
      if (eq === -1) continue
      request.cookies.set(pair.slice(0, eq), pair.slice(eq + 1))
    }

    const response = NextResponse.next({ request })
    for (const raw of setCookies) {
      response.headers.append("Set-Cookie", raw)
    }
    return response
  } catch {
    // Backend unreachable or timed out. Send the user to /login rather than
    // through: the session could not be refreshed, so there is nothing to
    // let through, and an auth gate that opens when its dependency is down
    // is not a gate.
    return loginRedirect(request)
  }
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|icons|apple-icon|manifest.webmanifest).*)"],
}
