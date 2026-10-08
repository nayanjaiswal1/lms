import "server-only";
import { cookies, headers } from "next/headers";
import { redirect } from "next/navigation";
import { cache } from "react";
import { forwardSetCookies } from "@/lib/server/set-cookie";

export interface ActionResult<T = undefined> {
  ok?: boolean;
  data?: T;
  error?: string;
  fieldErrors?: Record<string, string>;
  // Set on 409 when the backend returns the current row alongside the error
  // (optimistic-lock conflicts), so the UI can show "yours vs current".
  conflict?: T;
  // HTTP status of a failed backend response, so callers can branch on
  // 429/503 without parsing the message (absent on success/network errors).
  status?: number;
  // Machine-readable error code from the backend envelope ({"error","code"}),
  // when the emitting handler set one.
  code?: string;
  // Seconds from a failed response's Retry-After header (429 windows), when
  // the backend sent one — lets callers show an exact countdown.
  retryAfter?: number;
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

// Deduped per request by path: generateMetadata + layout + page (and the
// permission/org/auth helpers they share) routinely GET the same resource in
// one render. cache() is request-scoped, so nothing leaks across users, and it
// is a no-op inside server actions, so post-mutation reads stay fresh.
export const apiGet = cache(<T,>(path: string) => fetchData<T>("GET", path)) as <T>(path: string) => Promise<T>;

export function apiPost<T>(path: string, payload?: unknown): Promise<T> {
  return fetchData<T>("POST", path, payload);
}

async function fetchData<T>(method: "GET" | "POST", path: string, payload?: unknown): Promise<T> {
  const res = await fetch(`${baseURL()}${path}`, {
    method,
    headers: await authHeaders(),
    body: jsonBody(payload),
    cache: "no-store",
  });
  if (res.status === 401) redirect("/login");
  await assertOk(res, method, path);
  const body = await res.json() as { data: T };
  return body.data;
}

// Throws the same message shape for every throw-on-error read (apiGet, apiPost,
// apiGetPublic). 429 keeps the wait time so the user knows when to retry.
async function assertOk(res: Response, method: string, path: string): Promise<void> {
  if (res.status === 429) throw new Error(tooManyRequests(res, "and refresh."));
  if (!res.ok) {
    const body = await res.json().catch(() => ({})) as { error?: string };
    throw new Error(body.error ?? `${method} ${path} failed: ${res.status}`);
  }
}

export function jsonBody(payload: unknown): string | undefined {
  return payload !== undefined ? JSON.stringify(payload) : undefined;
}

export function tryBaseURL(): string | null {
  try {
    return baseURL();
  } catch {
    return null;
  }
}

function tooManyRequests(res: Response, tail: "and refresh." | "before trying again."): string {
  const wait = retryAfterSeconds(res);
  return `Too many requests. Please wait ${wait} second${wait === 1 ? "" : "s"} ${tail}`;
}

// Shape of a backend response body: {data} on success, {error, code?, fields?}
// on failure. `code` is the machine-readable error code (snake_case, owned by
// the emitting domain package) — branch on it, never on `error` text.
interface ErrorEnvelope<T> {
  data?: T;
  error?: string;
  code?: string;
  fields?: Record<string, string>;
}

// The backend wraps every field-validation response in the same literal
// "validation failed" placeholder (see httputil.WriteFieldErrors) — the real
// reason lives in `fields`. Surfacing the placeholder verbatim as the action's
// error message shows the user nothing actionable, so fall back to the first
// field message whenever the top-level error is just that wrapper.
export function actionErrorMessage(json: { error?: string; fields?: Record<string, string> }, fallback: string): string {
  if (json.error && json.error !== "validation failed") return json.error;
  const firstFieldMessage = json.fields ? Object.values(json.fields)[0] : undefined;
  return firstFieldMessage ?? json.error ?? fallback;
}

// ── Unauthenticated reads — no cookies forwarded ───────────────────────────
// For anonymous surfaces (marketplace catalog, public certificates, pricing,
// payments config, public profiles). Same throw-on-error contract as apiGet so
// callers that must never crash can wrap in try/catch and fall back to []/null.
// Responses ride the Data Cache via `next.revalidate` instead of no-store.
export async function apiGetPublic<T>(
  path: string,
  opts?: { revalidate?: number; headers?: Record<string, string> },
): Promise<T> {
  const revalidate = opts?.revalidate ?? 60;
  const res = await fetch(`${baseURL()}${path}`, {
    headers: opts?.headers,
    next: { revalidate },
  });
  await assertOk(res, "GET", path);
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
  const url = tryBaseURL();
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
    return await actionResponse<T>(res, "Upload failed.");
  } catch {
    return { error: "Upload failed. Please try again." };
  }
}

// For anonymous mutation surfaces (Project Workspace public interest form).
// No cookies/CSRF — there is no session — but the browser's IP is still
// forwarded so the backend's per-IP interest rate limit keys on the real
// client, not this server's own egress address. Same ActionResult contract
// and 429 handling as apiAction so callers don't need a second error shape.
export async function apiActionPublic<T = undefined>(
  method: string,
  path: string,
  payload?: unknown,
  extraHeaders?: Record<string, string>,
): Promise<ActionResult<T>> {
  const url = tryBaseURL();
  if (!url) return { error: "Service unavailable." };
  try {
    const res = await fetch(`${url}${path}`, {
      method,
      headers: { "Content-Type": "application/json", ...extraHeaders, ...(await clientIpHeaders()) },
      body: jsonBody(payload),
      cache: "no-store",
    });
    return await actionResponse<T>(res, "Request failed.");
  } catch {
    return { error: "Network error. Please try again." };
  }
}

/** extraHeaders for a POST the backend runs at most once per key
 *  (middleware.Idempotency) — the key comes from hooks/use-idempotency-key. */
export function idempotencyHeader(key: string): Record<string, string> {
  return { "Idempotency-Key": key };
}

export async function apiAction<T = undefined>(
  method: string,
  path: string,
  payload?: unknown,
  extraHeaders?: Record<string, string>,
): Promise<ActionResult<T>> {
  const url = tryBaseURL();
  if (!url) return { error: "Service unavailable." };
  try {
    const res = await fetch(`${url}${path}`, {
      method,
      headers: { ...(await authHeaders()), ...extraHeaders },
      body: jsonBody(payload),
      cache: "no-store",
    });
    const json = await res.json().catch(() => ({})) as ErrorEnvelope<T>;
    if (res.status === 429) {
      // A plain rate limit gets the generic wait message; a 429 with its own
      // code (max hints, review limit, ...) keeps the backend's explanation.
      const generic = !json.code || json.code === "rate_limited";
      return {
        error: generic
          ? tooManyRequests(res, "before trying again.")
          : actionErrorMessage(json, "Too many requests."),
        code: json.code,
        status: 429,
        retryAfter: parseRetryAfter(res),
      };
    }
    if (!res.ok) {
      return {
        error: actionErrorMessage(json, "Request failed."),
        code: json.code,
        fieldErrors: json.fields,
        conflict: res.status === 409 ? json.data : undefined,
        status: res.status,
        retryAfter: parseRetryAfter(res),
      };
    }
    // Actions that rotate the session (change password) answer with fresh
    // auth cookies; a no-op for every other response.
    await forwardSetCookies(res.headers).catch(() => undefined);
    return { ok: true, data: json.data };
  } catch {
    return { error: "Network error. Please try again." };
  }
}

// Shared response mapping for the non-throwing multipart/anonymous helpers
// (apiUpload, apiActionPublic). apiAction keeps its own mapping because it also
// surfaces status and retryAfter.
async function actionResponse<T>(res: Response, fallback: string): Promise<ActionResult<T>> {
  if (res.status === 429) return { error: tooManyRequests(res, "before trying again.") };
  const json = await res.json().catch(() => ({})) as ErrorEnvelope<T>;
  if (!res.ok) {
    return {
      error: actionErrorMessage(json, fallback),
      code: json.code,
      fieldErrors: json.fields,
      conflict: res.status === 409 ? json.data : undefined,
    };
  }
  return { ok: true, data: json.data };
}

function parseRetryAfter(res: Response): number | undefined {
  const raw = res.headers.get("Retry-After");
  const parsed = raw ? parseInt(raw, 10) : NaN;
  return isNaN(parsed) ? undefined : parsed;
}

function retryAfterSeconds(res: Response): number {
  return parseRetryAfter(res) ?? 60;
}
