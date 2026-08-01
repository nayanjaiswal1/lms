import "server-only";
import { cookies, headers } from "next/headers";

export interface ActionResult<T = undefined> {
  ok?: boolean;
  data?: T;
  error?: string;
}

/**
 * Forwards the browser's IP to the Go API.
 *
 * Every call in this file is server-to-server, so without this the backend sees
 * the Next.js server's own address on every request and its per-IP auth rate
 * limiter buckets the entire user base together — ten bad passwords from one
 * person would lock everyone out of login, while a password list run against a
 * single account would never stand out. The backend only believes this header
 * from TRUSTED_PROXY_CIDRS, so it cannot be used to forge a bucket from
 * outside.
 *
 * Returns an empty object when there is no request context (build-time
 * rendering) or no upstream address to report, so callers can always spread it.
 */
export async function clientIpHeaders(): Promise<Record<string, string>> {
  try {
    const h = await headers();
    const forwarded = h.get("x-forwarded-for") ?? h.get("x-real-ip");
    return forwarded ? { "X-Forwarded-For": forwarded } : {};
  } catch {
    return {};
  }
}

export function baseURL(): string {
  const url = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!url) throw new Error("BACKEND_URL is not configured");
  return url;
}

export async function authHeaders(): Promise<Record<string, string>> {
  const store = await cookies();
  const accessToken = store.get("access_token")?.value ?? "";
  const csrfToken = store.get("csrf_token")?.value ?? "";
  return {
    "Content-Type": "application/json",
    // eslint-disable-next-line no-restricted-syntax -- this is the one place allowed to build the Cookie header; everyone else must call authHeaders()/apiGet/apiAction.
    Cookie: `access_token=${accessToken}; csrf_token=${csrfToken}`,
    "X-CSRF-Token": csrfToken,
    ...(await clientIpHeaders()),
  };
}

// ── Server component reads — throw on error, propagate to error.tsx ──────────

export async function apiGet<T>(path: string): Promise<T> {
  const res = await fetch(`${baseURL()}${path}`, {
    headers: await authHeaders(),
    cache: "no-store",
  });
  if (res.status === 429) {
    const wait = retryAfterSeconds(res);
    throw new Error(`Too many requests. Please wait ${wait} second${wait === 1 ? "" : "s"} and refresh.`);
  }
  if (!res.ok) {
    const body = await res.json().catch(() => ({})) as { error?: string };
    throw new Error(body.error ?? `GET ${path} failed: ${res.status}`);
  }
  const body = await res.json() as { data: T };
  return body.data;
}

export async function apiPost<T>(path: string, payload?: unknown): Promise<T> {
  const res = await fetch(`${baseURL()}${path}`, {
    method: "POST",
    headers: await authHeaders(),
    body: payload !== undefined ? JSON.stringify(payload) : undefined,
    cache: "no-store",
  });
  if (res.status === 429) {
    const wait = retryAfterSeconds(res);
    throw new Error(`Too many requests. Please wait ${wait} second${wait === 1 ? "" : "s"} and refresh.`);
  }
  if (!res.ok) {
    const body = await res.json().catch(() => ({})) as { error?: string };
    throw new Error(body.error ?? `POST ${path} failed: ${res.status}`);
  }
  const body = await res.json() as { data: T };
  return body.data;
}

// ── Server actions — return ActionResult, never throw ────────────────────────

// For multipart file uploads. Omits Content-Type so the browser sets the
// correct multipart boundary automatically.
export async function apiUpload<T = undefined>(
  path: string,
  formData: FormData,
): Promise<ActionResult<T>> {
  const url = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!url) return { error: "Service unavailable." };
  try {
    // Omit Content-Type from authHeaders() so the browser sets the correct
    // multipart boundary automatically.
    const { "Content-Type": _contentType, ...headers } = await authHeaders();
    const res = await fetch(`${url}${path}`, {
      method:  "POST",
      headers,
      body:  formData,
      cache: "no-store",
    });
    if (res.status === 429) {
      const wait = retryAfterSeconds(res);
      return { error: `Too many requests. Please wait ${wait} second${wait === 1 ? "" : "s"} before trying again.` };
    }
    const json = await res.json().catch(() => ({})) as { data?: T; error?: string };
    if (!res.ok) return { error: json.error ?? "Upload failed." };
    return { ok: true, data: json.data };
  } catch {
    return { error: "Upload failed. Please try again." };
  }
}

export async function apiAction<T = undefined>(
  method: string,
  path: string,
  payload?: unknown,
  extraHeaders?: Record<string, string>,
): Promise<ActionResult<T>> {
  const url = process.env.BACKEND_URL ?? process.env.NEXT_PUBLIC_API_URL;
  if (!url) return { error: "Service unavailable." };
  try {
    const res = await fetch(`${url}${path}`, {
      method,
      headers: { ...(await authHeaders()), ...extraHeaders },
      body: payload !== undefined ? JSON.stringify(payload) : undefined,
      cache: "no-store",
    });
    if (res.status === 429) {
      const wait = retryAfterSeconds(res);
      return { error: `Too many requests. Please wait ${wait} second${wait === 1 ? "" : "s"} before trying again.` };
    }
    const json = await res.json().catch(() => ({})) as { data?: T; error?: string };
    if (!res.ok) return { error: json.error ?? "Request failed." };
    return { ok: true, data: json.data };
  } catch {
    return { error: "Network error. Please try again." };
  }
}

function retryAfterSeconds(res: Response): number {
  const raw = res.headers.get("Retry-After");
  const parsed = raw ? parseInt(raw, 10) : NaN;
  return isNaN(parsed) ? 60 : parsed;
}
