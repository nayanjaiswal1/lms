// @mf/fullstack: test helpers for fullstack debug labs (a React frontend and a Python backend in one workspace;
// root-owned, part of the lab-debug image, resolved through the "@mf/fullstack" alias next to "@mf/harness").
//
//   useBackend()            start the workspace's real backend (uvicorn on a free port) around a test file / each test
//   createBrowser(backend)  replace fetch with a small browser model in front of that backend
//   SEED_USER               the demo account every backend seeds
//
// The browser model is what makes cross-stack bugs reproducible without a real browser. It keeps a cookie jar
// (Domain, Path, HttpOnly, Max-Age; HttpOnly cookies never reach document.cookie), sends Origin, and enforces CORS for
// cross-origin requests the way browsers do: a preflight for non-simple requests, Access-Control-Allow-Origin must name
// the page origin (a wildcard is refused for credentialed requests), Access-Control-Allow-Credentials must be "true".
// A relative URL such as /api/orders is "same origin" and goes through the same proxy the Vite dev server uses; an
// absolute URL to the backend (VITE_API_URL) is cross-origin.
import { spawn } from "node:child_process";
import net from "node:net";
import { afterAll, afterEach, beforeAll, beforeEach, vi } from "vitest";

export const SEED_USER = { email: "alice@shop.test", password: "correct-horse-battery", name: "Alice Nguyen" };

// The real network fetch, captured before any test stubs the global.
const realFetch = globalThis.fetch.bind(globalThis);

const READY_TIMEOUT_MS = 20000;
const POLL_MS = 120;
const STARTUP_HOOK_TIMEOUT_MS = 30000;
const SIMPLE_METHODS = new Set(["GET", "HEAD", "POST"]);
const SAFELISTED_HEADERS = new Set(["accept", "accept-language", "content-language", "content-type", "origin"]);
const SIMPLE_CONTENT_TYPES = ["application/x-www-form-urlencoded", "multipart/form-data", "text/plain"];

/**
 * Node's fetch rejects the AbortSignal of the jsdom window (a different class), so the signal is not forwarded:
 * the returned promise settles with the signal's own abort reason as soon as it fires, like a browser's fetch.
 */
function abortable(signal, promise) {
  if (!signal) return promise;
  if (signal.aborted) return Promise.reject(signal.reason);
  return new Promise((resolve, reject) => {
    const onAbort = () => reject(signal.reason);
    signal.addEventListener("abort", onAbort, { once: true });
    promise.then(resolve, reject).finally(() => signal.removeEventListener("abort", onAbort));
  });
}

function freePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      server.close(() => resolve(port));
    });
  });
}

/** Start the workspace backend. `env` adds environment variables (SHOP_ALLOWED_ORIGINS defaults to the page origin). */
export async function startBackend({ env = {} } = {}) {
  const workdir = process.env.MF_WORKDIR || process.cwd();
  const port = await freePort();
  const url = `http://127.0.0.1:${port}`;
  const child = spawn(
    process.env.MF_PYTHON || "python3",
    ["-m", "uvicorn", "--app-dir", workdir, "--factory", "backend.app.main:create_app", "--host", "127.0.0.1", "--port", String(port), "--log-level", "warning"],
    {
      cwd: workdir,
      env: { ...process.env, PYTHONDONTWRITEBYTECODE: "1", SHOP_ALLOWED_ORIGINS: window.location.origin, ...env },
      stdio: ["ignore", "ignore", "pipe"],
    },
  );
  let log = "";
  let exited = false;
  child.stderr.on("data", (chunk) => (log += chunk));
  child.once("exit", () => (exited = true));

  const deadline = Date.now() + READY_TIMEOUT_MS;
  for (;;) {
    if (exited) throw new Error(`the backend exited during startup:\n${log.slice(-1500)}`);
    try {
      if ((await realFetch(`${url}/api/health`)).ok) break;
    } catch {
      // not listening yet
    }
    if (Date.now() > deadline) {
      child.kill();
      throw new Error(`the backend did not become ready:\n${log.slice(-1500)}`);
    }
    await new Promise((resolve) => setTimeout(resolve, POLL_MS));
  }
  return {
    url,
    stop: () =>
      new Promise((resolve) => {
        if (exited) return resolve();
        child.once("exit", () => resolve());
        child.kill();
      }),
  };
}

/**
 * Registers the lifecycle hooks and returns a handle whose `url` is valid inside tests.
 * `{ each: true }` gives every test a fresh backend (use it when a test changes data).
 */
export function useBackend({ each = false, env } = {}) {
  const handle = { url: "", stop: async () => {} };
  const start = async () => Object.assign(handle, await startBackend({ env }));
  if (each) {
    beforeEach(start, STARTUP_HOOK_TIMEOUT_MS);
    afterEach(() => handle.stop());
  } else {
    beforeAll(start, STARTUP_HOOK_TIMEOUT_MS);
    afterAll(() => handle.stop());
  }
  return handle;
}

function defaultPath(pathname) {
  const i = pathname.lastIndexOf("/");
  return i <= 0 ? "/" : pathname.slice(0, i);
}

function parseSetCookie(line, url) {
  const [pair, ...attrs] = line.split(";").map((part) => part.trim());
  const eq = pair.indexOf("=");
  if (eq <= 0) return null;
  const cookie = { name: pair.slice(0, eq), value: pair.slice(eq + 1), path: defaultPath(url.pathname), httpOnly: false, domain: url.hostname, hostOnly: true, expired: false };
  for (const attr of attrs) {
    const [key, ...rest] = attr.split("=");
    const value = rest.join("=");
    switch (key.toLowerCase()) {
      case "path":
        if (value.startsWith("/")) cookie.path = value;
        break;
      case "domain": {
        const domain = value.replace(/^\./, "").toLowerCase();
        // A host may only set cookies for itself or a parent domain; the browser drops anything else.
        if (!(url.hostname === domain || url.hostname.endsWith(`.${domain}`))) return null;
        cookie.domain = domain;
        cookie.hostOnly = false;
        break;
      }
      case "httponly":
        cookie.httpOnly = true;
        break;
      case "max-age":
        if (Number(value) <= 0) cookie.expired = true;
        break;
      case "expires":
        if (Date.parse(value) < Date.now()) cookie.expired = true;
        break;
      default:
    }
  }
  return cookie;
}

function hostMatches(cookie, host) {
  return cookie.hostOnly ? host === cookie.domain : host === cookie.domain || host.endsWith(`.${cookie.domain}`);
}

function pathMatches(cookiePath, requestPath) {
  if (requestPath === cookiePath) return true;
  return requestPath.startsWith(cookiePath.endsWith("/") ? cookiePath : `${cookiePath}/`);
}

function refused() {
  return new TypeError("Failed to fetch");
}

function clearDocumentCookies() {
  for (const part of document.cookie.split(";")) {
    const name = part.split("=")[0].trim();
    if (name) document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/`;
  }
}

/**
 * A browser in front of `backend`: installs a fetch that behaves like the page's fetch (see the file header).
 * Call it in beforeEach so every test starts with an empty cookie jar.
 *
 * `{ install: false }` makes a second browser (another tab or device of the same customer): it has its own cookie
 * jar and is used through its `.fetch`; it never touches the global fetch or the page's document.cookie.
 */
export function createBrowser(backend, { install = true } = {}) {
  if (install) clearDocumentCookies();
  const page = new URL(window.location.href);
  const jar = [];

  function cookieHeader(url) {
    return jar
      .filter((c) => hostMatches(c, url.hostname) && pathMatches(c.path, url.pathname))
      .map((c) => `${c.name}=${c.value}`)
      .join("; ");
  }

  function storeCookies(response, url) {
    for (const line of response.headers.getSetCookie()) {
      const cookie = parseSetCookie(line, url);
      if (!cookie) continue;
      const at = jar.findIndex((c) => c.name === cookie.name && c.domain === cookie.domain && c.path === cookie.path);
      if (at >= 0) jar.splice(at, 1);
      if (!cookie.expired) jar.push(cookie);
      // Only cookies of the page's own host that are not HttpOnly are visible to scripts.
      if (install && cookie.domain === page.hostname && !cookie.httpOnly) {
        document.cookie = `${cookie.name}=${cookie.expired ? "" : cookie.value}; path=${cookie.path}${cookie.expired ? "; expires=Thu, 01 Jan 1970 00:00:00 GMT" : ""}`;
      }
    }
  }

  function corsAllowed(response, credentials) {
    const allowOrigin = response.headers.get("access-control-allow-origin");
    if (credentials) {
      return allowOrigin === page.origin && response.headers.get("access-control-allow-credentials") === "true";
    }
    return allowOrigin === "*" || allowOrigin === page.origin;
  }

  async function preflight(actual, method, headerNames, credentials) {
    const response = await realFetch(actual, {
      method: "OPTIONS",
      headers: {
        Origin: page.origin,
        "Access-Control-Request-Method": method,
        ...(headerNames.length ? { "Access-Control-Request-Headers": headerNames.join(",") } : {}),
      },
    });
    if (!response.ok || !corsAllowed(response, credentials)) throw refused();
    const list = (name) => (response.headers.get(name) ?? "").split(",").map((s) => s.trim().toLowerCase()).filter(Boolean);
    const methods = list("access-control-allow-methods");
    const allowed = list("access-control-allow-headers");
    if (!SIMPLE_METHODS.has(method) && !methods.includes(method.toLowerCase()) && !(methods.includes("*") && !credentials)) throw refused();
    for (const name of headerNames) {
      if (!allowed.includes(name) && !(allowed.includes("*") && !credentials)) throw refused();
    }
  }

  async function browserFetch(input, init = {}) {
    const raw = typeof input === "string" ? input : input instanceof URL ? input.href : input.url;
    const url = new URL(raw, page.origin);
    const sameOrigin = url.origin === page.origin;
    const actual = sameOrigin ? new URL(url.pathname + url.search, backend.url) : url;
    const method = String(init.method ?? "GET").toUpperCase();
    const credentials = init.credentials ?? "same-origin";
    const sendCookies = credentials === "include" || (credentials === "same-origin" && sameOrigin);

    const headers = new Headers(init.headers ?? {});
    headers.set("Origin", page.origin);
    if (!sameOrigin) {
      const names = [...headers.keys()].filter((name) => !SAFELISTED_HEADERS.has(name));
      const contentType = (headers.get("content-type") ?? "").toLowerCase();
      const simpleType = !contentType || SIMPLE_CONTENT_TYPES.some((t) => contentType.startsWith(t));
      if (!SIMPLE_METHODS.has(method) || names.length > 0 || !simpleType) {
        await preflight(actual, method, [...names, ...(simpleType ? [] : ["content-type"])].sort(), credentials === "include");
      }
    }
    if (sendCookies) {
      const cookie = cookieHeader(url);
      if (cookie) headers.set("Cookie", cookie);
    }
    const response = await abortable(init.signal, realFetch(actual, { method, headers, body: init.body, redirect: "manual" }));
    if (!sameOrigin && !corsAllowed(response, credentials === "include")) throw refused();
    if (sendCookies) storeCookies(response, url);
    return response;
  }

  if (install) vi.stubGlobal("fetch", browserFetch);
  return {
    fetch: browserFetch,
    /** Cookies in the jar (including HttpOnly ones), for assertions. */
    cookies: () => jar.map((c) => ({ ...c })),
    cookie: (name) => jar.find((c) => c.name === name),
  };
}
