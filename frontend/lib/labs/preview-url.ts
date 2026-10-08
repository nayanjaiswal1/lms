// Single source for the labproxy WebSocket origin (csp.ts, the lab terminal, and
// preview URLs all read it). NEXT_PUBLIC_* is inlined at build time.
export const LAB_PROXY_WS_URL = process.env.NEXT_PUBLIC_LAB_PROXY_URL ?? "ws://localhost:18081"

/**
 * Builds a labproxy entry URL: /preview/{token}/[{port}/][{path}]. labproxy
 * validates the token, then redirects to the per-port preview origin where
 * the token becomes a host-only cookie (backend/cmd/labproxy/preview.go).
 */
export function buildLabPreviewUrl(token: string, port?: number, path = ""): string {
  const httpUrl = LAB_PROXY_WS_URL.replace(/^ws/, "http")
  const portSegment = port && port > 0 ? `${port}/` : ""
  return `${httpUrl}/preview/${token}/${portSegment}${path}`
}
