import type { NextConfig } from "next";

function buildSecurityHeaders() {
  const apiUrl = process.env.NEXT_PUBLIC_API_URL;
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
        // Allow avatars from OAuth providers + data URIs + blob URLs (canvas export)
        "img-src 'self' data: blob: https://avatars.githubusercontent.com https://lh3.googleusercontent.com https://graph.microsoft.com",
        "font-src 'self'",
        // ws/wss for Yjs WebSocket (interview real-time sync)
        ["connect-src 'self'", apiUrl, "ws: wss:"].filter(Boolean).join(" "),
        // Worker required by Monaco Editor
        "worker-src 'self' blob:",
        "frame-src 'none'",
        "object-src 'none'",
        "base-uri 'self'",
      ].join("; "),
    },
  ];
}

const nextConfig: NextConfig = {
  async headers() {
    return [{ source: "/(.*)", headers: buildSecurityHeaders() }];
  },

  images: {
    remotePatterns: [
      { protocol: "https", hostname: "avatars.githubusercontent.com" },
      { protocol: "https", hostname: "lh3.googleusercontent.com" },
      { protocol: "https", hostname: "graph.microsoft.com" },
    ],
  },

  // Catch TypeScript errors at build time
  typescript: { ignoreBuildErrors: false },

  // Opt into React 19 strict mode
  reactStrictMode: true,
};

export default nextConfig;
