// Empty means same origin: the dev server proxies /api to the backend.
const BASE_URL = import.meta.env.VITE_API_URL ?? '';
const CSRF_COOKIE = 'csrf_token';
const SAFE_METHODS = new Set(['GET', 'HEAD']);

export class ApiError extends Error {
  constructor(status, message, code) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
  }
}

function readCookie(name) {
  const entry = document.cookie.split('; ').find((part) => part.startsWith(`${name}=`));
  return entry ? decodeURIComponent(entry.slice(name.length + 1)) : '';
}

/** One JSON request. Resolves with the parsed body (null for 204) or rejects with an ApiError. */
export async function request(path, { method = 'GET', body, signal } = {}) {
  const headers = {};
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  if (!SAFE_METHODS.has(method)) {
    // mf:slot lib.api.csrf-header
    headers['X-CSRF-Token'] = readCookie(CSRF_COOKIE);
    // mf:endslot
  }
  const response = await fetch(`${BASE_URL}${path}`, {
    method,
    signal,
    headers,
    credentials: 'include',
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const payload = response.status === 204 ? null : await response.json().catch(() => null);
  if (!response.ok) {
    throw new ApiError(
      response.status,
      payload?.error?.message ?? `Request failed (${response.status})`,
      payload?.error?.code,
    );
  }
  return payload;
}

export const get = (path, options) => request(path, options);
export const post = (path, body, options) => request(path, { ...options, method: 'POST', body });
export const put = (path, body, options) => request(path, { ...options, method: 'PUT', body });
