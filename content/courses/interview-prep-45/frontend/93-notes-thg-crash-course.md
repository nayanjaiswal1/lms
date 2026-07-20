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

**Role:** Frontend Engineer — Logistics & Finance | **R1:** Live Coding (Joshua) | **R2:** Architecture (Simon)

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

---

## 2. Live Coding — Practice These 2 Problems (timed, 25 min each)
1. **Typeahead/autocomplete**: debounce input → cancel stale requests → loading/error/empty states → keyboard nav
2. **Infinite scroll list**: IntersectionObserver → avoid duplicate fetches → mention virtualization for large data

**Behavior rules:** think out loud, ask clarifying questions first, brute-force then optimize, narrate uncovered edge cases (money formatting, timezones — relevant for Finance/Logistics domain).

---

## 3. React Performance & State — Talking Points
- `useMemo`/`useCallback`: only worth it for expensive computation or referential stability (deps arrays, `React.memo` children) — not free.
- `React.memo`: shallow prop compare; breaks if you pass new object/array literals each render.
- Reconciliation: fiber diffing + keys match elements between renders; updates are batched.
- **React Query vs Redux Toolkit**: React Query = server state (cache/refetch/stale-while-revalidate); Redux Toolkit = client/UI state. Have one real example ready of splitting these.

---

## 4. Architecture Round — Structure Every Answer As:
**Requirements → Data flow → Component breakdown → State management → Performance → Edge cases**

Prep this ONE in full: *"Design a real-time shipment tracking dashboard."*
- Data: polling vs WebSocket/SSE for live updates
- State: React Query for server cache, Redux Toolkit/local state for UI-only
- Large lists: virtualization, server-side pagination/filtering
- Optimistic updates for status-change actions, rollback on failure
- Errors/loading/empty states handled consistently across app

**Know briefly (2-min explanations):**
- Module Federation — sharing components across independently deployed micro-frontends
- Code splitting: route-based + `React.lazy`/`Suspense`
- Money handling: avoid floats, use integers/cents or decimal libs
- API collaboration: contract-first (OpenAPI), standardized error shapes between FE/BE

---

## 5. Your Stories (rehearse out loud, <90 sec each)
1. **Coriolis**: a frontend/backend collaboration moment — shaping an API contract or performance fix.
2. **IntelliFinance AI**: OpenAI integration — handling latency/loading UX, retries, error handling for third-party API failures; React frontend against Django REST Framework; Docker/AWS deployment reasoning.

---

## 6. Questions to Ask Simon Harris
- How is frontend structured across Logistics/Finance — shared library, monorepo, separate deployables?
- What does the real-time data pipeline look like for logistics tracking?
- Biggest current frontend scaling/performance challenge?
- Spec-first process for FE/BE API contracts?

---

## Cheat Sheet

| Topic | One-liner |
|---|---|
| Closures | Function + captured scope; `let` in loops = per-iteration binding |
| bind/call/apply | call/apply invoke now (args list vs array), bind returns new fn |
| Promises | pending/fulfilled/rejected, `.then` via microtask queue |
| Race conditions | AbortController in useEffect cleanup |
| Reconciliation | Fiber diff + keys, batched updates |
| useMemo/useCallback | Only for expensive compute / referential stability |
| React.memo | Shallow compare, breaks with new literals per render |
| React Query vs RTK | Server cache vs client/UI state |
| Module Federation | Share code across independently deployed micro-frontends |
| Optimistic UI | Update now, rollback on failure |
| Money | Integers/cents or decimal lib, never raw floats |
| Virtualization | Render only visible rows (react-window) |

## 12-Hour Time Allocation
1–2h: JS rebuild | 3–5h: live coding practice | 6–7h: perf/state talking points | 8–9h: architecture answer | 10–11h: stories | 12h: cheat sheet skim + rest
