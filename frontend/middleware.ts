import { NextResponse } from "next/server"
import type { NextRequest } from "next/server"

const PROTECTED_PREFIXES = [
  "/dashboard",
  "/courses",
  "/practice",
  "/assessments",
  "/mentor",
  "/settings",
  "/instructor",
  "/admin",
]

export function middleware(request: NextRequest): NextResponse {
  const { pathname } = request.nextUrl

  const isProtected = PROTECTED_PREFIXES.some((prefix) => pathname.startsWith(prefix))
  if (!isProtected) return NextResponse.next()

  const hasToken = request.cookies.has("access_token")
  if (hasToken) return NextResponse.next()

  const loginUrl = request.nextUrl.clone()
  loginUrl.pathname = "/login"
  loginUrl.searchParams.set("next", pathname)
  return NextResponse.redirect(loginUrl)
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|icons|apple-icon).*)"],
}
