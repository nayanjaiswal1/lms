---
kind: lesson
id_key: interview-prep-45/note-thg-crash-course
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Crash-Course: A Real Interview Prep Session"
position: 41
estimated_minutes: 30
source:
    - interview-prep-notes.md
---
Everything else in this course is structured, ordered material. This is the opposite: an actual 12-hour cram session written the night before a real onsite, kept close to its original form because that's what makes it useful, it shows what preparing for a specific interview actually looks like once the studying is mostly done and it's time to compress everything down to what you'll say out loud.

**Role:** Frontend Engineer, Logistics & Finance. **R1:** Live Coding. **R2:** Architecture.

---

## 1. JS fundamentals, written from scratch, no reference

**MyPromise**
```js
class MyPromise {
  constructor(executor) {
    this.state = "pending";
    this.value = undefined;
    this.callbacks = [];
    const resolve = (val) => {
      if (this.state !== "pending") return;
      this.state = "fulfilled"; this.value = val;
      this.callbacks.forEach(cb => cb.onFulfilled(val));
    };
    const reject = (err) => {
      if (this.state !== "pending") return;
      this.state = "rejected"; this.value = err;
      this.callbacks.forEach(cb => cb.onRejected(err));
    };
    executor(resolve, reject);
  }
  then(onFulfilled, onRejected) {
    return new MyPromise((resolve, reject) => {
      const handle = () => {
        if (this.state === "fulfilled") resolve(onFulfilled(this.value));
        if (this.state === "rejected") reject(onRejected ? onRejected(this.value) : this.value);
      };
      if (this.state === "pending") this.callbacks.push({ onFulfilled: handle, onRejected: handle });
      else handle();
    });
  }
}
```
Trace `new MyPromise(executor).then(f)`: the constructor runs `executor` immediately, so if it calls `resolve` right away, `state` is already `"fulfilled"` before `.then` is even called. `.then(f)` then sees `state !== "pending"` is false, so it calls `handle()` immediately, which resolves the new promise with `f(this.value)`. If the executor is async instead, `.then(f)` runs first, sees `"pending"`, and pushes onto `callbacks` to wait, `resolve` eventually drains that array and finally calls `f`.

**bind / call**
```js
Function.prototype.myBind = function (ctx, ...args1) {
  const fn = this;
  return (...args2) => fn.apply(ctx, [...args1, ...args2]);
};
Function.prototype.myCall = function (ctx, ...args) {
  ctx.fn = this;
  const result = ctx.fn(...args);
  delete ctx.fn;
  return result;
};
```
`myBind` never calls the function at all, it captures it in a closure and returns a new function that applies the original with `ctx` and merged arguments whenever it's eventually called. `myCall` calls immediately: it temporarily attaches the function to `ctx` so calling it as `ctx.fn(...)` makes `this` inside it equal `ctx`, then deletes the temporary property so it doesn't leak.

**debounce / throttle**
```js
function debounce(fn, delay) {
  let timer;
  return (...args) => { clearTimeout(timer); timer = setTimeout(() => fn(...args), delay); };
}
function throttle(fn, limit) {
  let inThrottle;
  return (...args) => {
    if (!inThrottle) { fn(...args); inThrottle = true; setTimeout(() => inThrottle = false, limit); }
  };
}
```

**Race condition fix (React)**
```js
useEffect(() => {
  const controller = new AbortController();
  fetch(url, { signal: controller.signal }).then(setData);
  return () => controller.abort();
}, [query]);
```
If `query` changes again before the first fetch resolves, React runs the old effect's cleanup before the new one, aborting the stale request. That aborted fetch rejects instead of resolving, so its `setData` never fires, and only the response for the latest `query` ever reaches state.

---

## 2. Live coding: practice these two, timed, 25 minutes each

1. **Typeahead/autocomplete**: debounce the input, cancel stale requests, handle loading/error/empty states, support keyboard navigation.
2. **Infinite scroll list**: use IntersectionObserver, avoid duplicate fetches, and be ready to mention virtualization for large data sets.

**Behavior rules**: think out loud, ask clarifying questions first, brute-force then optimize, and narrate edge cases you'd otherwise miss, money formatting and timezones especially, since those are directly relevant to a Finance/Logistics domain.

---

## 3. React performance and state: talking points

`useMemo`/`useCallback` are only worth it for expensive computation or referential stability, don't reach for them by default. `React.memo` does a shallow prop compare, and breaks the moment you pass a new object or array literal on every render. Reconciliation uses fiber diffing plus keys to match elements between renders, and applies the resulting updates in a batch. React Query versus Redux Toolkit: React Query owns server state, cache, refetch, stale-while-revalidate; Redux Toolkit owns client/UI state. Have one real example ready where you actually split these two apart in a project.

---

## 4. Architecture round: structure every answer as

**Requirements, then data flow, then component breakdown, then state management, then performance, then edge cases.**

Prep this one in full: *"Design a real-time shipment tracking dashboard."* Data: decide between polling and WebSocket/SSE for live updates. State: a query library for server cache, Redux Toolkit or local state for UI-only concerns. Large lists: virtualization plus server-side pagination and filtering. Optimistic updates for status-change actions, with rollback on failure. Errors, loading, and empty states handled consistently across the app.

Know briefly, two-minute explanations: Module Federation for sharing components across independently deployed micro-frontends; route-based code splitting plus `React.lazy`/`Suspense`; money handling, avoid floats, use integers or a decimal library; API collaboration via a contract-first process (OpenAPI), with standardized error shapes agreed between frontend and backend.

---

## 5. Personal stories, rehearse out loud, under 90 seconds each

1. A frontend/backend collaboration moment, shaping an API contract or landing a performance fix.
2. An OpenAI integration story covering latency/loading UX, retries, and error handling for a third-party API's failures, built as a React frontend against a Django REST Framework backend, with Docker/AWS deployment reasoning to explain.

---

## 6. Questions worth asking back

How is frontend structured across the Logistics and Finance teams, shared library, monorepo, or separate deployables? What does the real-time data pipeline actually look like for logistics tracking? What's the biggest current frontend scaling or performance challenge? Is there a spec-first process for frontend/backend API contracts?

---

## Cheat sheet

| Topic | One-liner |
|---|---|
| Closures | A function plus its captured scope. `let` in a loop gives each iteration its own binding. |
| bind/call/apply | `call`/`apply` invoke right away, differing only in args-as-list vs args-as-array. `bind` returns a new function instead of invoking anything. |
| Promises | States: pending, fulfilled, rejected. `.then` callbacks run via the microtask queue. |
| Race conditions | Fix with an `AbortController` created inside `useEffect` and aborted in its cleanup. |
| Reconciliation | Fiber diffing plus keys, updates applied in a batch. |
| useMemo/useCallback | Worth it only for expensive computation or referential stability, not by default. |
| React.memo | Shallow prop compare. Breaks if you pass a new literal on every render. |
| React Query vs RTK | Server cache vs client/UI state. |
| Module Federation | Share code across independently deployed micro-frontends. |
| Optimistic UI | Update immediately, roll back on failure. |
| Money | Integers/cents or a decimal library, never raw floats. |
| Virtualization | Render only visible rows. |

## 12-hour time allocation

Hours 1-2: JS rebuild. Hours 3-5: live coding practice. Hours 6-7: perf/state talking points. Hours 8-9: architecture answer. Hours 10-11: stories. Hour 12: cheat sheet skim and rest.
