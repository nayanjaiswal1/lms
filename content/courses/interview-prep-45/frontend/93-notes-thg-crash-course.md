---
kind: lesson
id_key: interview-prep-45/note-thg-crash-course
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: THG Ingenuity Interview — 12-Hour Crash Course"
position: 93
estimated_minutes: 30
source:
    - interview-prep-notes.md
---

**Role:** Frontend Engineer, Logistics & Finance. **R1:** Live Coding (Joshua). **R2:** Architecture (Simon).

---

## 1. JS Fundamentals (write from scratch, no reference)

**MyPromise**
```js
class MyPromise {
  constructor(executor) {
    this.state = "pending";
    this.value = undefined;
    this.callbacks = [];
    const resolve = (val) => {
      if (this.state !== "pending") return;
      this.state = "fulfilled";
      this.value = val;
      this.callbacks.forEach(cb => cb.onFulfilled(val));
    };
    const reject = (err) => {
      if (this.state !== "pending") return;
      this.state = "rejected";
      this.value = err;
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
Trace what happens on `new MyPromise(executor).then(f)`: the constructor runs `executor` immediately and synchronously, so if the executor calls `resolve` right away, `state` flips to `"fulfilled"` before `.then` is even called. When `.then(f)` runs afterward, it sees `state === "pending"` is false, so it calls `handle()` immediately, which calls `resolve(f(this.value))` on the new promise it returns. If instead the executor is async (say it resolves inside a `setTimeout`), `.then(f)` runs first, finds `state === "pending"`, and just pushes `{ onFulfilled: handle }` onto `callbacks` to wait. When `resolve` eventually fires, it loops over `callbacks` and invokes each `handle`, which is what finally calls `f`.

**bind / call / apply**
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
`myBind` doesn't call the function at all: it captures `this` (the original function) in a closure and returns a brand-new function that, whenever it's eventually called, applies the original with `ctx` as `this` and both argument lists merged. `myCall` calls immediately instead: it temporarily attaches the function as a property of `ctx` so that calling it as `ctx.fn(...)` makes `this` inside the function equal `ctx`, then deletes that temporary property so it doesn't leak.

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
Call the debounced function five times in quick succession and only the last call's timer survives, since every new call clears the previous timer before starting a new one; `fn` only ever runs once, `delay` ms after the last call. Call the throttled function five times in quick succession and only the first call runs `fn` immediately; the rest are dropped until `limit` ms passes and `inThrottle` resets to false.

**Race condition fix (React)**
```js
useEffect(() => {
  const controller = new AbortController();
  fetch(url, { signal: controller.signal }).then(setData);
  return () => controller.abort();
}, [query]);
```
If `query` changes again before the first fetch resolves, React runs the cleanup function for the old effect before running the new one, which calls `controller.abort()` on the stale request. That aborted fetch's promise rejects instead of resolving, so its `setData` call never fires, and only the response for the latest `query` ever reaches state.

---

## 2. Live Coding: Practice These 2 Problems (timed, 25 min each)
1. **Typeahead/autocomplete**: debounce the input, cancel stale requests, handle loading/error/empty states, support keyboard navigation.
2. **Infinite scroll list**: use IntersectionObserver, avoid duplicate fetches, and be ready to mention virtualization for large data sets.

**Behavior rules:** think out loud, ask clarifying questions first, brute-force then optimize, and narrate edge cases you'd otherwise miss, like money formatting and timezones, since those are directly relevant to a Finance/Logistics domain.

---

## 3. React Performance & State: Talking Points
- `useMemo`/`useCallback` are only worth it for expensive computation or for referential stability (stable dependency arrays, stable props into a `React.memo` child). They aren't free, so don't reach for them by default.
- `React.memo` does a shallow prop compare, so it breaks if you pass a new object or array literal on every render.
- Reconciliation uses fiber diffing plus keys to match elements between renders, and applies the resulting updates in a batch.
- **React Query vs Redux Toolkit**: React Query owns server state, meaning cache, refetch, and stale-while-revalidate behavior. Redux Toolkit owns client/UI state. Have one real example ready where you split these two apart.

---

## 4. Architecture Round: Structure Every Answer As
**Requirements, then data flow, then component breakdown, then state management, then performance, then edge cases.**

Prep this ONE in full: *"Design a real-time shipment tracking dashboard."*
- Data: decide between polling and WebSocket/SSE for live updates.
- State: React Query for server cache, Redux Toolkit or local state for UI-only concerns.
- Large lists: virtualization plus server-side pagination/filtering.
- Optimistic updates for status-change actions, with rollback on failure.
- Errors, loading, and empty states handled consistently across the app.

**Know briefly (2-min explanations):**
- Module Federation: sharing components across independently deployed micro-frontends.
- Code splitting: route-based splitting plus `React.lazy`/`Suspense`.
- Money handling: avoid floats, use integers/cents or a decimal library.
- API collaboration: contract-first via OpenAPI, with standardized error shapes agreed between frontend and backend.

---

## 5. Your Stories (rehearse out loud, under 90 sec each)
1. **Coriolis**: a frontend/backend collaboration moment, either shaping an API contract or landing a performance fix.
2. **IntelliFinance AI**: an OpenAI integration story covering latency/loading UX, retries, and error handling for third-party API failures, built as a React frontend against a Django REST Framework backend, with Docker/AWS deployment reasoning.

---

## 6. Questions to Ask Simon Harris
- How is frontend structured across Logistics/Finance: shared library, monorepo, or separate deployables?
- What does the real-time data pipeline look like for logistics tracking?
- What's the biggest current frontend scaling/performance challenge?
- Is there a spec-first process for FE/BE API contracts?

---

## Cheat Sheet

| Topic | One-liner |
|---|---|
| Closures | A function plus its captured scope. `let` in a loop gives each iteration its own binding. |
| bind/call/apply | `call`/`apply` invoke the function right away, differing only in args-as-list vs args-as-array. `bind` returns a new function instead of invoking anything. |
| Promises | States are pending, fulfilled, rejected. `.then` callbacks run via the microtask queue. |
| Race conditions | Fix with an `AbortController` created inside `useEffect` and aborted in its cleanup. |
| Reconciliation | Fiber diffing plus keys, with updates applied in a batch. |
| useMemo/useCallback | Worth it only for expensive computation or referential stability, not by default. |
| React.memo | Shallow prop compare. Breaks if you pass a new literal on every render. |
| React Query vs RTK | Server cache vs client/UI state. |
| Module Federation | Share code across independently deployed micro-frontends. |
| Optimistic UI | Update the UI immediately, roll back on failure. |
| Money | Integers/cents or a decimal library, never raw floats. |
| Virtualization | Render only visible rows (e.g. react-window). |

## 12-Hour Time Allocation
Hours 1-2: JS rebuild. Hours 3-5: live coding practice. Hours 6-7: perf/state talking points. Hours 8-9: architecture answer. Hours 10-11: stories. Hour 12: cheat sheet skim and rest.
