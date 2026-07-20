import { NextResponse } from "next/server"
import type { NextRequest } from "next/server"

const PROTECTED_PREFIXES = [
  "/dashboard",
  "/now",
  "/courses",
  // Lab pages mint short-lived terminal/preview tokens continuously — without
  // the silent refresh here, every lab dies 15 minutes in (ACCESS_TOKEN_TTL)
  // with "connection lost" / "session expired" while the refresh token is
  // still perfectly valid.
  "/labs",
  "/assessments",
  "/question-bank",
  "/batches",
  "/mentoring",
  "/practice",
  "/settings",
  "/admin",
  "/sheets",
  "/platform",
  "/plan",
]

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

  const isProtected = PROTECTED_PREFIXES.some((p) => pathname.startsWith(p))
  if (!isProtected) return NextResponse.next()

  const accessToken  = request.cookies.get("access_token")?.value
  const refreshToken = request.cookies.get("refresh_token")?.value

  // Token present and not expired — let through immediately.
  if (accessToken && !jwtExpired(accessToken)) return NextResponse.next()

  // No refresh token — redirect to login.
  if (!refreshToken) {
    return loginRedirect(request)
  }

  // Access token missing or expired — attempt a silent refresh.
  try {
    const backendUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL
    if (!backendUrl) return NextResponse.next()

    const refreshRes = await fetch(`${backendUrl}/api/auth/refresh`, {
      method: "POST",
      // eslint-disable-next-line no-restricted-syntax -- middleware runs on the Edge runtime; lib/server/api.ts is server-only and can't be imported here, and this refreshes off refresh_token, not access_token.
      headers: { Cookie: `refresh_token=${refreshToken}` },
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
    // Backend unreachable — let the request through and let error.tsx handle it.
    return NextResponse.next()
  }
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|icons|apple-icon).*)"],
}
