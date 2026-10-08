import { TURNSTILE_ORIGIN } from "@/lib/captcha"
import { LAB_PROXY_WS_URL } from "@/lib/labs/preview-url"

// The lab IDE and app preview are iframes served by labproxy: its own origin plus the
// per-session preview subdomains (p<port>-<session>.<preview domain>), hence the wildcard.
function buildLabFrameSources(): string[] {
  const proxyUrl = process.env.NEXT_PUBLIC_LAB_PROXY_URL
  if (!proxyUrl) return []
  const { protocol, host } = new URL(proxyUrl.replace(/^ws/, "http"))
  return [`${protocol}//${host}`, `${protocol}//*.${host}`]
}

// The lab terminal opens a WebSocket straight to labproxy (hooks/use-lab-terminal.ts),
// so connect-src needs that one origin rather than every ws:/wss: host.
function buildLabConnectSource(): string {
  const { protocol, host } = new URL(LAB_PROXY_WS_URL)
  return `${protocol}//${host}`
}

export function generateNonce(): string {
  return btoa(crypto.randomUUID())
}

// Per-request Content-Security-Policy. Scripts run only with this request's nonce
// ('strict-dynamic' extends trust to scripts those load), so no 'unsafe-inline'.
export function buildCsp(nonce: string): string {
  const apiUrl = process.env.NEXT_PUBLIC_API_URL
  const mediaUrl = process.env.NEXT_PUBLIC_MEDIA_URL
  return [
    "default-src 'self'",
    // 'wasm-unsafe-eval' allows WebAssembly.instantiate only (in-browser runtimes), not JS eval;
    // unsafe-eval is dev-only (React/Turbopack debugging).
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic' 'wasm-unsafe-eval' ${TURNSTILE_ORIGIN}${process.env.NODE_ENV === "development" ? " 'unsafe-eval'" : ""}`,
    // unsafe-inline required by Tailwind CSS-in-JS + shadcn
    "style-src 'self' 'unsafe-inline'",
    // Allow avatars from OAuth providers + data URIs + blob URLs (canvas export) + user-uploaded media (MinIO/S3) + CNCF brand assets for seeded dev course covers + GitHub-hosted lesson screenshots (markdown-authored course content)
    ["img-src 'self' data: blob: https://avatars.githubusercontent.com https://lh3.googleusercontent.com https://graph.microsoft.com https://raw.githubusercontent.com https://user-images.githubusercontent.com", mediaUrl].filter(Boolean).join(" "),
    "font-src 'self'",
    // labproxy WebSocket for the lab terminal
    ["connect-src 'self'", TURNSTILE_ORIGIN, apiUrl, buildLabConnectSource()].filter(Boolean).join(" "),
    // Worker required by Monaco Editor
    "worker-src 'self' blob:",
    // YouTube block embeds (course content + wizard preview) — youtube-nocookie only
    [`frame-src https://www.youtube-nocookie.com ${TURNSTILE_ORIGIN}`, ...buildLabFrameSources()].join(" "),
    "object-src 'none'",
    "base-uri 'self'",
  ].join("; ")
}
