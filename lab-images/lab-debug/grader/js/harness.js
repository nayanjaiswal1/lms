// @mf/harness: test helpers for React debug labs (root-owned, part of the
// lab-debug image; resolved through the "@mf/harness" alias in the grader's and
// the workspace's vitest config). Students may use it in their own tests.
//
//   installFetch()      scripted / held fetch with call counting and a runaway guard
//   json()              a JSON Response
//   deferred()          a promise with resolve / reject handles
//   trackListeners()    counts live DOM event listeners (leak detection)
//   createRenderProbe() a component that counts its own renders
//   renderProfiled()    render inside <Profiler> and collect commits
//   flush()             let pending promises and effects settle inside act()
import { Profiler, createElement } from "react";
import { act, render } from "@testing-library/react";
import { vi } from "vitest";

export function json(status, body) {
  return new Response(body === undefined ? null : JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

export async function flush() {
  await act(async () => {
    await Promise.resolve();
    await new Promise((resolve) => setTimeout(resolve, 0));
  });
}

function matches(matcher, url) {
  if (matcher instanceof RegExp) return matcher.test(url);
  return url === matcher || url.startsWith(`${matcher}?`);
}

function abortError() {
  return new DOMException("The operation was aborted.", "AbortError");
}

function parseBody(body) {
  if (typeof body !== "string") return body;
  try {
    return JSON.parse(body);
  } catch {
    return body;
  }
}

/**
 * Replaces globalThis.fetch. Unmatched requests answer 404.
 *
 *   const net = installFetch({ maxCalls: 50 });
 *   net.on("GET", "/api/orders", () => json(200, { items: [] }));   // scripted
 *   const held = net.hold("GET", /^\/api\/customers\?q=/);          // manual
 *   held.requests[1].respond(200, [...]);                           // answer in any order
 *
 * Past `maxCalls` requests every further fetch never settles (so a runaway
 * request loop ends instead of hanging the test); assert on net.count().
 */
export function installFetch({ maxCalls = 100 } = {}) {
  const routes = [];
  const holds = [];
  const calls = [];
  const unmatched = [];

  const fetchMock = vi.fn((input, init = {}) => {
    const url = typeof input === "string" ? input : input.url;
    const method = String(init.method ?? "GET").toUpperCase();
    const call = { method, url, body: parseBody(init.body), signal: init.signal ?? null };
    calls.push(call);
    if (calls.length > maxCalls) return new Promise(() => {});

    const hold = holds.find((h) => h.method === method && matches(h.matcher, url));
    if (hold) {
      return new Promise((resolve, reject) => {
        const request = {
          ...call,
          settled: false,
          respond(status, body) {
            if (request.settled) return;
            request.settled = true;
            resolve(json(status, body));
          },
          fail(error) {
            if (request.settled) return;
            request.settled = true;
            reject(error);
          },
        };
        if (call.signal) {
          const abort = () => request.fail(abortError());
          if (call.signal.aborted) abort();
          else call.signal.addEventListener("abort", abort, { once: true });
        }
        hold.requests.push(request);
      });
    }

    const route = routes.find((r) => r.method === method && matches(r.matcher, url));
    if (!route) {
      unmatched.push(call);
      return Promise.resolve(json(404, { error: "no route" }));
    }
    if (call.signal?.aborted) return Promise.reject(abortError());
    // A handler that throws behaves like a network failure: fetch rejects.
    return new Promise((resolve) => resolve(route.handler(call))).then((out) =>
      out instanceof Response ? out : json(200, out),
    );
  });
  vi.stubGlobal("fetch", fetchMock);

  return {
    fetch: fetchMock,
    calls,
    unmatched,
    on(method, matcher, handler) {
      routes.unshift({ method: method.toUpperCase(), matcher, handler });
    },
    hold(method, matcher) {
      const entry = { method: method.toUpperCase(), matcher, requests: [] };
      holds.unshift(entry);
      return entry;
    },
    count(method, matcher) {
      return calls.filter(
        (c) => (!method || c.method === method.toUpperCase()) && (matcher === undefined || matches(matcher, c.url)),
      ).length;
    },
  };
}

/**
 * Counts live DOM event listeners added after this call. A listener is live
 * until removeEventListener is called with the same target, type, callback and
 * capture flag (an add of an identical triple is a no-op, as in browsers).
 */
export function trackListeners() {
  const proto = window.EventTarget.prototype;
  const originalAdd = proto.addEventListener;
  const originalRemove = proto.removeEventListener;
  const live = new Map();

  const key = (type, options) => `${type}|${typeof options === "boolean" ? options : Boolean(options?.capture)}`;

  proto.addEventListener = function (type, callback, options) {
    if (callback) {
      let perTarget = live.get(this);
      if (!perTarget) live.set(this, (perTarget = new Map()));
      let callbacks = perTarget.get(key(type, options));
      if (!callbacks) perTarget.set(key(type, options), (callbacks = new Set()));
      callbacks.add(callback);
    }
    return originalAdd.call(this, type, callback, options);
  };
  proto.removeEventListener = function (type, callback, options) {
    live.get(this)?.get(key(type, options))?.delete(callback);
    return originalRemove.call(this, type, callback, options);
  };

  const count = (type) => {
    let total = 0;
    for (const perTarget of live.values()) {
      for (const [k, callbacks] of perTarget) {
        if (type === undefined || k.startsWith(`${type}|`)) total += callbacks.size;
      }
    }
    return total;
  };
  return {
    /** Live listeners, optionally only of one event type. */
    count,
    restore() {
      proto.addEventListener = originalAdd;
      proto.removeEventListener = originalRemove;
    },
  };
}

/**
 * A component that counts its renders. `useValue` is called on every render,
 * so a hook or context read there re-renders the probe whenever it changes.
 *
 *   const probe = createRenderProbe(() => useSettings());
 *   const element = <probe.Probe />;   // keep this element reference stable
 */
export function createRenderProbe(useValue = () => undefined) {
  const state = { renders: 0, lastValue: undefined };
  function Probe() {
    state.lastValue = useValue();
    state.renders += 1;
    return null;
  }
  return {
    Probe,
    get renders() {
      return state.renders;
    },
    get lastValue() {
      return state.lastValue;
    },
    reset() {
      state.renders = 0;
    },
  };
}

/** Render inside a <Profiler>; `commits` collects one entry per committed render. */
export function renderProfiled(ui, options) {
  const commits = [];
  const wrap = (node) =>
    createElement(Profiler, { id: "mf", onRender: (id, phase, actualDuration) => commits.push({ phase, actualDuration }) }, node);
  const result = render(wrap(ui), options);
  return { ...result, commits, rerender: (next) => result.rerender(wrap(next)) };
}
