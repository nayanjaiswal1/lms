import { cookies } from "next/headers";

// ─────────────────────────────────────────────
// Forward Set-Cookie headers from a backend response onto the browser.
//
// Server actions fetch the Go API server-to-server, so the Set-Cookie headers
// the API issues (access_token, refresh_token) never reach the browser on their
// own. We parse them here and re-emit them through Next's cookie store so the
// httpOnly auth cookies land on the user's browser with their original
// attributes (Path, Max-Age, HttpOnly, Secure, SameSite) intact.
// ─────────────────────────────────────────────

type SameSite = "lax" | "strict" | "none";

interface ParsedCookie {
  name: string;
  value: string;
  options: {
    path?: string;
    maxAge?: number;
    expires?: Date;
    httpOnly?: boolean;
    secure?: boolean;
    sameSite?: SameSite;
  };
}

function parseSameSite(value: string | undefined): SameSite | undefined {
  switch (value?.trim().toLowerCase()) {
    case "lax":
      return "lax";
    case "strict":
      return "strict";
    case "none":
      return "none";
    default:
      return undefined;
  }
}

function parseSetCookie(raw: string): ParsedCookie | null {
  const segments = raw.split(";");
  const pair = segments.shift();
  if (!pair) return null;

  const eq = pair.indexOf("=");
  if (eq < 0) return null;

  const name = pair.slice(0, eq).trim();
  const value = pair.slice(eq + 1).trim();
  if (!name) return null;

  const options: ParsedCookie["options"] = {};
  for (const segment of segments) {
    const idx = segment.indexOf("=");
    const key = (idx < 0 ? segment : segment.slice(0, idx)).trim().toLowerCase();
    const attr = idx < 0 ? undefined : segment.slice(idx + 1).trim();

    switch (key) {
      case "path":
        options.path = attr;
        break;
      // Domain intentionally omitted — strip it so cookies land on the
      // frontend's origin (first-party), not the backend's domain.
      case "max-age": {
        const seconds = Number(attr);
        if (!Number.isNaN(seconds)) options.maxAge = seconds;
        break;
      }
      case "expires": {
        const date = attr ? new Date(attr) : undefined;
        if (date && !Number.isNaN(date.getTime())) options.expires = date;
        break;
      }
      case "samesite":
        options.sameSite = parseSameSite(attr);
        break;
      case "httponly":
        options.httpOnly = true;
        break;
      case "secure":
        options.secure = true;
        break;
    }
  }

  return { name, value, options };
}

export async function forwardSetCookies(headers: Headers): Promise<void> {
  // getSetCookie() is the only API that returns multiple Set-Cookie headers
  // unfolded. It exists on undici's Headers (Node runtime) — guard for safety.
  const accessor = (headers as Headers & { getSetCookie?: () => string[] })
    .getSetCookie;
  const rawCookies = typeof accessor === "function" ? accessor.call(headers) : [];
  if (rawCookies.length === 0) return;

  const store = await cookies();
  for (const raw of rawCookies) {
    const parsed = parseSetCookie(raw);
    if (parsed) store.set(parsed.name, parsed.value, parsed.options);
  }
}
