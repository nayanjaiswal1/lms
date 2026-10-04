// mf:slot lib.api.base-url
const BASE_URL = import.meta.env.VITE_API_URL ?? '';
// mf:endslot

export class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
  }
}

/** One JSON request. Resolves with the parsed body (null for 204) or rejects with an ApiError. */
export async function request(path, { method = 'GET', body, signal } = {}) {
  const response = await fetch(`${BASE_URL}${path}`, {
    method,
    signal,
    headers: body === undefined ? undefined : { 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  // mf:slot lib.api.check-status
  if (!response.ok) {
    throw new ApiError(response.status, `${method} ${path} failed with ${response.status}`);
  }
  // mf:endslot
  return response.status === 204 ? null : response.json();
}

export const get = (path, options) => request(path, options);
export const post = (path, body, options) => request(path, { ...options, method: 'POST', body });
export const put = (path, body, options) => request(path, { ...options, method: 'PUT', body });
export const del = (path, options) => request(path, { ...options, method: 'DELETE' });
