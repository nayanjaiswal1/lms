---
kind: lesson
id_key: interview-prep-45/note-js-react-interview-prep
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: JavaScript + React Interview Prep"
position: 90
estimated_minutes: 60
source:
    - interview-prep-notes.md
---

A self-built course from interview prep session — covers Promise internals, custom React hooks, JS polyfills, and core theory (JS, React, CSS, TypeScript).

---

## Table of Contents
1. [Promise Combinators](#1-promise-combinators)
2. [Building Promise from Scratch (MyPromise)](#2-building-promise-from-scratch-mypromise)
3. [Custom React Hooks](#3-custom-react-hooks)
4. [Stale Closure Bug Pattern](#4-stale-closure-bug-pattern)
5. [Compound Component Pattern](#5-compound-component-pattern)
6. [Infinite Scroll (Intersection Observer)](#6-infinite-scroll-intersection-observer)
7. [Classic JS Polyfills](#7-classic-js-polyfills)
8. [LRU Cache](#8-lru-cache)
9. [WeakMap / WeakSet](#9-weakmap--weakset)
10. [Theory Quick Reference](#10-theory-quick-reference)

---

## 1. Promise Combinators

### Core rules

| Combinator | Settles when | On all-fail/empty |
|---|---|---|
| `all` | any reject OR all resolve | empty → resolve `[]` |
| `race` | first settle (resolve/reject) | empty → pending forever |
| `allSettled` | always waits for all | empty → resolve `[]` |
| `any` | first resolve OR all reject | empty → reject |

### Promise.all
```js
function promiseAll(promises) {
  return new Promise((resolve, reject) => {
    const results = [];
    let completedCount = 0;

    if (promises.length === 0) { resolve([]); }

    promises.forEach((promise, index) => {
      promise.then(
        (result) => {
          results[index] = result;
          completedCount++;
          if (completedCount === promises.length) resolve(results);
        }
      ).catch(reject); // fail-fast
    });
  });
}
```

### Promise.race
```js
function promiseRace(promises) {
  return new Promise((resolve, reject) => {
    promises.forEach((promise) => {
      promise.then(resolve).catch(reject);
    });
  });
}
```
> Empty array → stays pending forever (verified via `Promise.race([])` in devtools).

### Promise.allSettled
```js
function allSettled(promises) {
  let result = [];
  let count = 0;

  return new Promise((resolve) => {
    if (promises.length === 0) resolve([]);

    promises.forEach((promise, index) => {
      promise.then(
        (value) => { result[index] = { status: "fulfilled", value }; }
      ).catch(
        (reason) => { result[index] = { status: "rejected", reason }; }
      ).finally(() => {
        count++;
        if (count === promises.length) resolve(result);
      });
    });
  });
}
```
> Never fail-fast — waits for all settles regardless of outcome. `.finally()` is the elegant way to increment the counter for both branches at once.

### Promise.any
```js
function any(promises) {
  let result = [];
  let count = 0;

  return new Promise((resolve, reject) => {
    if (promises.length === 0) {
      reject(new AggregateError([], "All promises were rejected"));
    }

    promises.forEach((promise, index) => {
      promise.then(
        (value) => { resolve(value); }
      ).catch(
        (reason) => { result[index] = reason; }
      ).finally(() => {
        count++;
        if (count === promises.length) reject(result);
      });
    });
  });
}
```
> Key insight: once a promise settles (resolve/reject), calling resolve/reject again is a **silent no-op** in JS — settling is permanent. This makes the "double call" safe here.

---

## 2. Building Promise from Scratch (MyPromise)

### Key facts
- Executor runs **synchronously** the moment `new Promise()` is called.
- A settled promise (fulfilled/rejected) can **never** change state again ("immutable settling").
- If the executor throws synchronously (no try/catch inside), it should auto-convert to a rejection.

### Base state machine
```js
class MyPromise {
  constructor(executor) {
    this.state = "pending";
    this.value = undefined;
    this.onFulfilledCallbacks = [];
    this.onRejectedCallbacks = [];

    const resolve = (value) => {
      if (this.state === "pending") {
        this.state = "fulfilled";
        this.value = value;
        this.onFulfilledCallbacks.forEach((cb) => cb(this.value));
      }
    };

    const reject = (reason) => {
      if (this.state === "pending") {
        this.state = "rejected";
        this.value = reason;
        this.onRejectedCallbacks.forEach((cb) => cb(this.value));
      }
    };

    try {
      executor(resolve, reject);
    } catch (error) {
      reject(error);
    }
  }

  then(onFulfilled, onRejected) {
    if (this.state === "fulfilled") {
      onFulfilled && onFulfilled(this.value);
    } else if (this.state === "rejected") {
      onRejected && onRejected(this.value);
    } else {
      if (onFulfilled) this.onFulfilledCallbacks.push(onFulfilled);
      if (onRejected) this.onRejectedCallbacks.push(onRejected);
    }
  }

  catch(onRejected) {
    return this.then(null, onRejected);
  }
}
```

### Why two callback arrays?
`.then()` can be called **before** the promise settles (async case, e.g. inside `setTimeout`) or **after** it already settled (sync case). Both must be handled:
- Already settled → call callback immediately.
- Still pending → store callback in an array; `resolve`/`reject` will drain the array later.
- Multiple `.then()` calls on the same promise → need an **array**, not a single variable, since all of them must fire.

### Chaining (`.then().then()`)
For `.then()` to be chainable, it must **return a new `MyPromise`**. Two behaviors to handle inside the new promise:
- If the callback returns a **plain value** → resolve the new promise with it.
- If the callback **throws** → reject the new promise with the error (mirrors sync `try/catch` propagation).
- (Advanced, not fully implemented in this session): if the callback returns **another promise**, the new promise should wait on that inner promise ("flattening").

```js
then(onFulfilled, onRejected) {
  return new MyPromise((resolve, reject) => {
    const handleFulfilled = () => {
      try {
        const result = onFulfilled ? onFulfilled(this.value) : this.value;
        resolve(result);
      } catch (error) {
        reject(error);
      }
    };
    // handleRejected follows the same pattern using onRejected
    // ...
  });
}
```

---

## 3. Custom React Hooks

### useDebounce
**Use case:** delay reacting to a fast-changing value (search input, resize, auto-save, slider) until it stabilizes.

```js
import { useEffect, useState } from "react";

const useDebounce = (state, delay) => {
  const [debounce, setDebounce] = useState(state); // seed with initial value, not undefined

  useEffect(() => {
    const timer = setTimeout(() => {
      setDebounce(state);
    }, delay);

    return () => clearTimeout(timer); // cancel stale timer on re-run/unmount
  }, [state, delay]);

  return { debounce };
};
```

Usage:
```jsx
export const DebounceDemo = () => {
  const [value, setValue] = useState("");
  const { debounce } = useDebounce(value, 200);

  useEffect(() => {
    console.log("API call for:", debounce);
  }, [debounce]);

  return <input value={value} onChange={(e) => setValue(e.target.value)} />;
};
```
> Input updates instantly (no typing lag); the "API call" only fires once typing pauses for 200ms.

### useFetch (with race-condition handling)
**Problem it solves:** if `url` changes quickly (e.g. user switches dropdown option A → B), a slow response for A could resolve *after* B and incorrectly overwrite the UI with stale data — a race condition.

```js
import { useEffect, useState } from "react";

const useFetch = (url) => {
  const [apiData, setData] = useState([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function fetchData(signal) {
    setLoading(true);
    try {
      const response = await fetch(url, { signal });
      const data = await response.json();
      setData(data);
    } catch (err) {
      if (err.name !== "AbortError") {
        setError(err); // don't surface a cancelled request as a real error
      }
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    const control = new AbortController();
    fetchData(control.signal);
    return () => control.abort(); // cancels the in-flight request when url changes/unmounts
  }, [url]);

  return { apiData, error, loading };
};
```
> Without `AbortController`, the *last request to resolve* wins — not the last request *started* — corrupting the UI with outdated data.

### useLocalStorage
```js
import { useEffect, useState } from "react";

function useLocalStorage(key, initialValue) {
  const [data, setData] = useState(() => {
    const stored = localStorage.getItem(key); // check raw string BEFORE parsing
    return stored ? JSON.parse(stored) : initialValue;
  });

  useEffect(() => {
    localStorage.setItem(key, JSON.stringify(data));
  }, [data]);

  return [data, setData];
}
```
**Bugs avoided here:**
- `localStorage` only stores strings → must `JSON.stringify` on write, `JSON.parse` on read.
- **Falsy-value bug:** checking truthiness *after* parsing breaks for legit falsy values like `0`/`false` (e.g. `JSON.parse("0")` → `0`, which is falsy). Checking the **raw string** for truthiness first avoids this, since `JSON.stringify` never produces an empty string for any valid value.
- Lazy `useState(() => ...)` initializer ensures localStorage is only read once, not every render.

---

## 4. Stale Closure Bug Pattern

**Buggy version:**
```jsx
function Counter() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    setInterval(() => {
      setCount(count + 1); // `count` is captured at effect's first run — always 0
    }, 1000);
  }, []);

  return <div>{count}</div>;
}
```
Bug: increments once (0→1) then freezes, because the closure inside `setInterval` captured `count` as it was when the effect first ran (`0`), and never updates.

**Fixed version:**
```jsx
function Counter() {
  const [count, setCount] = useState(0);

  useEffect(() => {
    const timer = setInterval(() => {
      setCount((q) => q + 1); // functional update — always gets latest state
    }, 1000);
    return () => clearInterval(timer); // cleanup prevents leak on unmount
  }, []);

  return <div>{count}</div>;
}
```

**Two things fixed simultaneously:**
1. **Stale closure** → use the functional update form `setState(prev => ...)` instead of referencing the closed-over variable directly.
2. **Memory leak** → always clear intervals/timeouts/subscriptions in the `useEffect` cleanup function.

---

## 5. Compound Component Pattern

**Idea:** like native `<select><option>` — child components only make sense inside a specific parent, and implicitly share state with it via React Context (no prop drilling).

```jsx
import { createContext, useContext, useState } from "react";

const AccordionContext = createContext();

function Accordion({ children }) {
  const [activeIndex, setActiveIndex] = useState(null);

  return (
    <AccordionContext.Provider value={{ activeIndex, setActiveIndex }}>
      <div>{children}</div>
    </AccordionContext.Provider>
  );
}
```
`Accordion.Item` (nested anywhere inside) reads `activeIndex`/`setActiveIndex` via `useContext(AccordionContext)` — no manual prop passing needed, even through multiple levels of nesting.

### Context API — general pattern
```jsx
const ThemeContext = createContext();

function App() {
  const [theme, setTheme] = useState("light");
  return (
    <ThemeContext.Provider value={{ theme, setTheme }}>
      <Header />
    </ThemeContext.Provider>
  );
}

function Header() {
  const { theme, setTheme } = useContext(ThemeContext); // no props from App needed
  return <button onClick={() => setTheme(theme === "light" ? "dark" : "light")}>{theme}</button>;
}
```

---

## 6. Infinite Scroll (Intersection Observer)

**Why Intersection Observer over scroll-event listeners:** scroll events fire extremely often and hurt performance; Intersection Observer only fires when visibility actually changes.

```jsx
import { useState, useEffect, useRef, useCallback } from "react";

function InfiniteList() {
  const [items, setItems] = useState([]);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const observerTarget = useRef(null); // invisible "sentinel" element at list end

  const fetchMoreItems = useCallback(async () => {
    if (loading || !hasMore) return; // guard against double-fetch / fetching past the end

    setLoading(true);
    const response = await fetch(`https://api.example.com/items?page=${page}`);
    const newItems = await response.json();

    if (newItems.length === 0) {
      setHasMore(false);
    } else {
      setItems((prev) => [...prev, ...newItems]);
      setPage((prev) => prev + 1);
    }
    setLoading(false);
  }, [page, loading, hasMore]);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) fetchMoreItems();
      },
      { threshold: 1.0 }
    );

    const currentTarget = observerTarget.current;
    if (currentTarget) observer.observe(currentTarget);

    return () => {
      if (currentTarget) observer.unobserve(currentTarget);
    };
  }, [fetchMoreItems]);

  return (
    <div>
      {items.map((item) => <div key={item.id}>{item.name}</div>)}
      <div ref={observerTarget} style={{ height: "20px" }}>
        {loading && "Loading more..."}
      </div>
    </div>
  );
}
```
**How to explain it verbally:** "An invisible sentinel div sits at the end of the list. Intersection Observer watches it — when it becomes visible, the user has scrolled to the bottom, so we fetch the next page and append it to the existing items array."

---

## 7. Classic JS Polyfills

### deepClone
```js
function deepClone(value) {
  if (typeof value !== "object" || value === null) {
    return value; // primitives AND null both handled here
  }

  if (Array.isArray(value)) {
    const temp = [];
    value.forEach((i) => temp.push(deepClone(i)));
    return temp;
  }

  if (typeof value === "object") {
    const temp = {};
    Object.entries(value).forEach(([k, v]) => {
      temp[k] = deepClone(v);
    });
    return temp;
  }
}
```
**Bugs to avoid:**
- `typeof null === "object"` — a JS quirk — so `null` must be checked explicitly, or it'll crash on `Object.entries(null)`.
- Condition must use `||` not `&&`: return early if *either* "not an object" *or* "is null".

### memoize
```js
function memoize(cb) {
  const cache = {};
  return function (...args) {
    const key = JSON.stringify(args);
    if (key in cache) { // `in` check, not truthiness — handles falsy cached results like 0
      return cache[key];
    }
    const result = cb(...args); // spread, not passing the array directly
    cache[key] = result;
    return result;
  };
}
```
**Bugs to avoid:**
- `cb(args)` passes the whole array as one argument — must spread: `cb(...args)`.
- `if (cache[key])` fails for falsy cached values (e.g. result `0`) — use `key in cache` instead.

### flatten
```js
function flatten(val, result = []) {
  if (Array.isArray(val)) {
    val.forEach((entry) => flatten(entry, result)); // must pass the SAME result array through recursion
  } else {
    result.push(val);
  }
  return result;
}
```
**Bug to avoid:** forgetting to pass `result` into the recursive call causes each recursive call to create its own fresh `[]` (via the default parameter) — nothing ever accumulates into the outer array.
> Contrast with `deepClone`, which builds a *new* return value at every level (immutable style) — `flatten` here uses one *shared, mutated* accumulator (mutable style). Knowing the difference between these two recursion patterns is a good thing to call out in an interview.

---

## 8. LRU Cache

**Concept:** fixed-capacity cache; when full, evict the **least recently used** item.

```js
class LRUCache {
  constructor(capacity) {
    this.capacity = capacity;
    this.cache = new Map(); // Map preserves insertion order
  }

  get(key) {
    if (!this.cache.has(key)) return -1;

    // delete + re-set moves this key to the "end" (= most recently used)
    const value = this.cache.get(key);
    this.cache.delete(key);
    this.cache.set(key, value);
    return value;
  }

  put(key, value) {
    if (this.cache.has(key)) {
      this.cache.delete(key);
    } else if (this.cache.size >= this.capacity) {
      // Map's first key (via iterator) is always the least-recently-used one
      const oldestKey = this.cache.keys().next().value;
      this.cache.delete(oldestKey);
    }
    this.cache.set(key, value);
  }
}
```
**Why `Map` is ideal here:** it preserves insertion order, and re-inserting a key (delete + set) moves it to the end — giving an O(1) way to track recency without a separate linked list.

---

## 9. WeakMap / WeakSet

| | `Map`/`Set` | `WeakMap`/`WeakSet` |
|---|---|---|
| Keys/values | Any type | Objects only |
| Iteration | `.forEach`, `.keys()`, `.size` available | Not available (GC timing unpredictable) |
| Memory | Strong reference — prevents GC | Weak reference — entry auto-removed when object is GC'd |

```js
let obj = { name: "Nayan" };
const wm = new WeakMap();
wm.set(obj, "metadata");

obj = null; // no other references left → WeakMap entry becomes eligible for GC automatically
```

**Use case:** associating extra data with a DOM element (or other object) without causing a memory leak if that object is later removed/discarded.

**Interview soundbite:** "Weak = memory-safe version of Map/Set, for when you need to associate data with an object temporarily without risking a leak."

---

## 10. Theory Quick Reference

### JavaScript
- **var/let/const** — var: function-scoped, redeclarable; let: block-scoped, reassignable; const: block-scoped, not reassignable
- **Hoisting** — declarations lifted before execution; `var` → undefined; `let/const` → TDZ error; function declarations fully hoisted
- **Closures** — a function remembers variables from its outer scope even after the outer function has returned
- **`this`** — determined by call site; arrow functions inherit `this` lexically from the enclosing scope
- **call/apply/bind** — call: comma args, invokes immediately; apply: array args, invokes immediately; bind: returns a new function, invoked later
- **Event loop** — sync code → microtasks (Promises) → macrotasks (setTimeout)
- **`==` vs `===`** — `==` coerces types before comparing; `===` does not
- **Deep vs shallow copy** — shallow copies only top-level; nested references are shared; deep copies every level independently
- **Prototypal inheritance** — missing properties are looked up the prototype chain
- **Currying** — a function that takes arguments one at a time, returning a new function each time until all are supplied
- **Debounce vs throttle** — debounce fires after activity stops; throttle fires at a fixed interval regardless of activity
- **async/await** — syntactic sugar over Promises; errors handled via `try/catch`
- **Pure function** — same input always produces same output, no external side effects
- **null vs undefined** — undefined: no value assigned; null: intentionally set to "no value"
- **`typeof null`** — returns `"object"` (long-standing JS quirk)
- **Higher-order function** — a function that accepts and/or returns another function

### React
- **Virtual DOM** — lightweight in-memory representation of the DOM; diffed before minimal real DOM updates are applied
- **useState vs useRef** — useState triggers re-render on change; useRef persists a value across renders without triggering one
- **useEffect** — runs after render; dependency array controls when it re-runs; cleanup function runs before the next run / on unmount
- **useEffect vs useLayoutEffect** — useEffect runs after paint (async); useLayoutEffect runs before paint (sync, blocking)
- **useMemo vs useCallback** — useMemo memoizes a computed value; useCallback memoizes a function reference
- **React.memo** — skips re-rendering a component if its props haven't changed
- **Controlled vs uncontrolled** — controlled: value lives in React state; uncontrolled: value lives in the DOM, read via ref
- **key prop** — tells React which item is which across re-renders; using array index breaks on reordering/insertion/deletion
- **Context API** — shares data deeply through the tree without manual prop passing at every level
- **Custom hooks** — reusable stateful logic, named starting with `use`
- **Compound components** — parent/child components that implicitly share state via Context (e.g. `<select><option>`)
- **HOC vs custom hook** — HOC wraps a component and returns a new component; a hook only reuses logic, no wrapping UI
- **Error boundaries** — class components that catch render errors in their child tree and show a fallback UI
- **State management split** — Redux Toolkit for client/UI state; React Query for server state and caching
- **Code splitting** — `React.lazy` + `Suspense` load bundles in smaller chunks on demand
- **Portals** — render a component's output into a different part of the DOM tree (modals, tooltips)
- **Forward ref** — lets a parent access a DOM node inside a child component

### Async / Browser
- **Race condition fix (fetch)** — cancel the previous in-flight request with `AbortController` when a new one starts
- **fetch vs axios** — fetch is built-in with manual JSON parsing; axios is a library with automatic JSON handling and richer error handling
- **CORS** — browser security mechanism blocking cross-origin requests unless explicitly permitted
- **localStorage/sessionStorage/cookies** — localStorage persists indefinitely; sessionStorage clears per tab session; cookies are small and sent to the server with every request
- **Intersection Observer** — detects when an element enters/exits the viewport (used for infinite scroll, lazy-loading images)
- **Rendering pipeline** — parse HTML → compute styles → layout → paint

### CSS
- **Box model** — content-box: width excludes padding/border; border-box: width includes them
- **Flexbox vs Grid** — flexbox is 1-dimensional (row or column); grid is 2-dimensional (rows and columns together)
- **Position types** — relative: offsets from self, space reserved; absolute: positioned relative to nearest positioned ancestor, removed from flow; fixed: pinned to viewport; sticky: normal until a scroll threshold, then behaves like fixed
- **Specificity** — ID > class > element; higher specificity wins regardless of source order
- **em vs rem** — em is relative to the parent's font-size; rem is relative to the root (`html`) font-size
- **BFC (Block Formatting Context)** — an independent layout area that contains floats and prevents margin collapse; triggered by properties like `overflow: hidden`, `display: flex/grid`
- **display:none vs visibility:hidden vs opacity:0** — none: no space, no events; hidden: space reserved, no events; opacity 0: space reserved, events still fire
- **Media queries** — mobile-first approach: base styles for mobile, `min-width` queries to scale up
- **z-index** — only affects elements with a non-static `position`

### TypeScript
- **interface vs type** — both similar; interfaces support declaration merging/extends more naturally; type aliases support unions/intersections more flexibly
- **Generics** — reusable type placeholders (`<T>`) for functions/components
- **any vs unknown** — `any` bypasses type checking entirely; `unknown` requires a type check before use (safer)
- **Union vs Intersection** — union (`|`): value is one of several types; intersection (`&`): value combines multiple types at once
- **Optional chaining / nullish coalescing** — `?.` avoids crashing on null/undefined access; `??` falls back to a default only when the left side is null/undefined (unlike `||`, which also falls back on other falsy values)

### Architecture talking points
- Folder structure: feature-based organization (components/hooks/services)
- API layer separated from UI components (custom hooks wrapping fetch/React Query)
- Redux Toolkit for client/UI state, React Query for server state — explain the boundary and why
- Centralized error handling: error boundaries + per-request try/catch + user-facing messaging
- Performance at scale: list virtualization, lazy loading, code splitting
- Always explain trade-offs, not just choices — interviewers probe "why", not just "what"

---

## Personal Project Talking Point: IntelliFinance AI

**Problem:** Managing expenses across multiple bank accounts is tedious — existing budgeting apps track spending but don't automatically reconcile invoices/receipts against bank transactions across accounts.

**Solution flow:** User uploads bank statements/invoices as PDFs → sent to an LLM for parsing → LLM returns structured JSON (date, amount, category) → backend auto-matches this against existing transactions by date/amount → on match, the invoice is linked to that transaction → user gets a dashboard showing category-wise spending breakdown.

**Stack:** React + Redux Toolkit (frontend), Django REST Framework (backend), LLM integration for document parsing, Docker/AWS for deployment.

> Framing tip: never call your own project "very simple" in an interview — present it confidently with problem → solution → architecture → one interesting design decision, regardless of project size.
