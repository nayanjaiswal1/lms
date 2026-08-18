import { fileURLToPath } from "url";
import type { NextConfig } from "next";
import type { RemotePattern } from "next/dist/shared/lib/image-config";

const projectRoot = fileURLToPath(new URL(".", import.meta.url));

function buildSecurityHeaders() {
  const apiUrl = process.env.NEXT_PUBLIC_API_URL;
  const mediaUrl = process.env.NEXT_PUBLIC_MEDIA_URL;
  return [
    // Prevent DNS prefetching leaking visited URLs
    { key: "X-DNS-Prefetch-Control", value: "on" },
    // Force HTTPS for 2 years, include subdomains
    { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains; preload" },
    // Block iframe embedding (clickjacking)
    { key: "X-Frame-Options", value: "DENY" },
    // Prevent MIME-type sniffing
    { key: "X-Content-Type-Options", value: "nosniff" },
    // Limit referrer info sent cross-origin
    { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
    // Disable unused browser APIs
    { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=()" },
    {
      key: "Content-Security-Policy",
      value: [
        "default-src 'self'",
        // unsafe-inline + unsafe-eval required by Next.js/Turbopack dev mode; eval stripped in production build
        `script-src 'self' 'unsafe-inline'${process.env.NODE_ENV === "development" ? " 'unsafe-eval'" : ""}`,
        // unsafe-inline required by Tailwind CSS-in-JS + shadcn
        "style-src 'self' 'unsafe-inline'",
        // Allow avatars from OAuth providers + data URIs + blob URLs (canvas export) + user-uploaded media (MinIO/S3) + CNCF brand assets for seeded dev course covers + GitHub-hosted lesson screenshots (markdown-authored course content)
        ["img-src 'self' data: blob: https://avatars.githubusercontent.com https://lh3.googleusercontent.com https://graph.microsoft.com https://raw.githubusercontent.com https://user-images.githubusercontent.com", mediaUrl].filter(Boolean).join(" "),
        "font-src 'self'",
        // ws/wss for Yjs WebSocket (interview real-time sync)
        ["connect-src 'self'", apiUrl, "ws: wss:"].filter(Boolean).join(" "),
        // Worker required by Monaco Editor
        "worker-src 'self' blob:",
        // YouTube block embeds (course content + wizard preview) — youtube-nocookie only
        "frame-src https://www.youtube-nocookie.com",
        "object-src 'none'",
        "base-uri 'self'",
      ].join("; "),
    },
  ];
}

function buildMediaRemotePattern(): RemotePattern[] {
  const mediaUrl = process.env.NEXT_PUBLIC_MEDIA_URL;
  if (!mediaUrl) return [];
  const url = new URL(mediaUrl);
  return [{
    protocol: url.protocol.replace(":", "") as "http" | "https",
    hostname: url.hostname,
    port: url.port || undefined,
    pathname: "/**",
  }];
}

const nextConfig: NextConfig = {
  // Bundles a minimal `.next/standalone` server — required by frontend/Dockerfile's
  // production runtime stage. No effect on `next dev`.
  output: "standalone",

  // Pins the workspace root explicitly. Without this, Turbopack's own root-inference
  // (walking up from this directory looking for a lockfile) can pick the wrong
  // ancestor when more than one lockfile is present (this repo has both
  // package-lock.json and pnpm-lock.yaml in this same directory) and then fail with
  // "Next.js package not found" because it's resolving node_modules relative to the
  // wrong root.
  turbopack: { root: projectRoot },

  async headers() {
    return [{ source: "/(.*)", headers: buildSecurityHeaders() }];
  },

  // Mirrors Caddyfile.dev's routing table so backend routes also resolve
  // when Next.js is hit directly (e.g. `pnpm dev` on :3000), not just through
  // Caddy on :80. Same BACKEND_URL every server action already uses.
  async rewrites() {
    const backendUrl = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
    if (!backendUrl) return [];
    return [
      { source: "/api/:path*", destination: `${backendUrl}/api/:path*` },
      { source: "/oauth/:path*", destination: `${backendUrl}/oauth/:path*` },
      { source: "/.well-known/:path*", destination: `${backendUrl}/.well-known/:path*` },
      { source: "/mcp", destination: `${backendUrl}/mcp` },
    ];
  },

  images: {
    remotePatterns: [
      { protocol: "https", hostname: "avatars.githubusercontent.com" },
      { protocol: "https", hostname: "lh3.googleusercontent.com" },
      { protocol: "https", hostname: "graph.microsoft.com" },
      { protocol: "https", hostname: "raw.githubusercontent.com" },
      { protocol: "https", hostname: "user-images.githubusercontent.com" },
      ...buildMediaRemotePattern(),
    ],
  },

  // Catch TypeScript errors at build time
  typescript: { ignoreBuildErrors: false },

  // Opt into React 19 strict mode
  reactStrictMode: true,
};

export default nextConfig;
