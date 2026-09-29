/**
 * Builds a labproxy entry URL: /preview/{token}/[{port}/][{path}]. labproxy
 * validates the token, then redirects to the per-port preview origin where
 * the token becomes a host-only cookie (backend/cmd/labproxy/preview.go).
 */
export function buildLabPreviewUrl(token: string, port?: number, path = ""): string {
  const wsUrl = process.env.NEXT_PUBLIC_LAB_PROXY_URL ?? "ws://localhost:18081/ws"
  const httpUrl = wsUrl.replace(/^ws/, "http")
  const portSegment = port && port > 0 ? `${port}/` : ""
  return `${httpUrl}/preview/${token}/${portSegment}${path}`
}
