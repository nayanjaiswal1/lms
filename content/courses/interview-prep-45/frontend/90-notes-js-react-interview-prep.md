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

These are personal notes from an interview-prep session, not a single guided lesson. It's a reference document bundling a grab-bag of unrelated topics: Promise internals, custom React hooks, a couple of classic bug patterns, common polyfills, two data-structure implementations, and a dense JS/React/CSS/TypeScript theory reference. Use the table of contents to jump to the section you need rather than reading it start to finish.

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
Trace: for `promiseAll([p1, p2])`, both promises start immediately. Whichever settles first writes its result into `results` at its own index and bumps `completedCount`, so the results array ends up in the original order even if `p2` finishes before `p1`. Once `completedCount` reaches `promises.length`, the outer promise resolves with `results`. If either promise rejects at any point, `.catch(reject)` rejects the outer promise right away, regardless of what's still pending.

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
An empty array leaves the returned promise pending forever, which you can verify by running `Promise.race([])` in devtools and watching it never settle.

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
This never fails fast. It waits for every promise to settle regardless of outcome, recording either a `fulfilled` or `rejected` entry for each one. `.finally()` is the convenient part here: it increments the shared counter on both the resolve and reject branches, so there's no need to duplicate that logic in each `.then()`/`.catch()`.

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
Key insight: once a promise settles, calling `resolve` or `reject` on it again is a silent no-op in JS. Settling is permanent, and that's exactly what makes the code above safe: if one promise resolves early, `resolve(value)` fires once, and even if `count` later reaches `promises.length` and triggers `reject(result)`, that second call does nothing because the promise already settled.

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
`.then()` can be called before the promise settles (the async case, for example inside a `setTimeout`) or after it already settled (the sync case). Both need handling:
- Already settled: call the callback immediately.
- Still pending: store the callback in an array; `resolve`/`reject` will drain that array once the promise settles.
- Multiple `.then()` calls on the same promise need an array, not a single variable, since every one of them must eventually fire.

### Chaining (`.then().then()`)
For `.then()` to be chainable, it must return a new `MyPromise`. Two behaviors need handling inside that new promise:
- If the callback returns a plain value, resolve the new promise with it.
- If the callback throws, reject the new promise with the error, mirroring how a synchronous `try/catch` propagates.
- Advanced case, not fully implemented in this session: if the callback returns another promise, the new promise should wait on that inner promise instead of resolving with the promise object itself ("flattening").

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
Trace: calling `.then(fn)` on an already-fulfilled promise runs `handleFulfilled` inside the executor of the freshly created `MyPromise`. It calls `fn(this.value)` synchronously; if `fn` returns a plain value, that value resolves the new promise, which is what lets the next `.then()` in the chain pick it up. If `fn` throws instead, the `catch` block here rejects the new promise, which is how an error thrown three `.then()` calls deep can still be caught by a single `.catch()` at the end of the chain.

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
The input updates instantly with no typing lag, since `value` is a normal controlled state. The "API call" only fires once typing pauses for 200ms, because every keystroke cancels the previous timer via the cleanup function before a new one is set.

### useFetch (with race-condition handling)
**Problem it solves:** if `url` changes quickly (for example, a user switches a dropdown from option A to option B), a slow response for A could resolve after B's response arrives and incorrectly overwrite the UI with stale data. That's a race condition.

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
Without `AbortController`, whichever request resolves last wins, even if it wasn't the last one started, which is how the UI ends up corrupted with outdated data.

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
- `localStorage` only stores strings, so writes need `JSON.stringify` and reads need `JSON.parse`.
- Falsy-value bug: checking truthiness *after* parsing breaks for legitimate falsy values like `0` or `false` (for example, `JSON.parse("0")` evaluates to `0`, which is falsy). Checking the raw string for truthiness first avoids this, since `JSON.stringify` never produces an empty string for any valid value.
- The lazy `useState(() => ...)` initializer ensures `localStorage` is read only once, on mount, rather than on every render.

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
This increments once (0 to 1) and then freezes. The closure inside `setInterval` captured `count` as it was when the effect first ran, which is `0`, and because the effect has an empty dependency array it never re-runs to capture a fresh value. Every tick after the first is still adding `1` to that original `0`.

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
1. Stale closure: use the functional update form `setState(prev => ...)` instead of referencing the closed-over variable directly, so each tick reads whatever the current state actually is.
2. Memory leak: always clear intervals, timeouts, and subscriptions in the `useEffect` cleanup function.

---

## 5. Compound Component Pattern

**Idea:** like the native `<select><option>` pair, child components only make sense inside a specific parent, and implicitly share state with it through React Context instead of prop drilling.

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
An `Accordion.Item` nested anywhere inside reads `activeIndex`/`setActiveIndex` via `useContext(AccordionContext)`, with no manual prop passing needed even through several levels of nesting.

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

**Why Intersection Observer over scroll-event listeners:** scroll events fire extremely often and hurt performance, while Intersection Observer only fires when an element's visibility actually changes.

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
**How to explain it verbally:** an invisible sentinel div sits at the end of the list. Intersection Observer watches it, and when it becomes visible the user has scrolled to the bottom, so the code fetches the next page and appends it to the existing items array.

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
- `typeof null` returns `"object"`, a well-known JS quirk, so `null` needs an explicit check or the function crashes trying to run `Object.entries(null)`.
- The condition must use `||`, not `&&`: return early if either "not an object" or "is null" is true.

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
- `cb(args)` would pass the whole array as one argument, so the call must spread it: `cb(...args)`.
- `if (cache[key])` fails for falsy cached values like a result of `0`, so the lookup uses `key in cache` instead.

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
The bug to avoid: forgetting to pass `result` into the recursive call causes each call to create its own fresh `[]` via the default parameter, so nothing ever accumulates into the outer array.

Trace: `flatten([1, [2, [3, 4]], 5])` starts with `result = []`. Hitting `1` pushes it straight into `result`. Hitting the nested array `[2, [3, 4]]` recurses with that *same* `result` array rather than a new one, so those recursive pushes land in the outer array too. By the time the recursion unwinds, `result` is `[1, 2, 3, 4, 5]`.

`deepClone` builds a new return value at every level, an immutable style, while `flatten` mutates one shared accumulator, a mutable style. Knowing the difference between these two recursion patterns is worth calling out in an interview.

---

## 8. LRU Cache

**Concept:** a fixed-capacity cache that, once full, evicts the least recently used item to make room for a new one.

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
`Map` is ideal here because it preserves insertion order, and re-inserting a key via delete-then-set moves it to the end. That gives an O(1) way to track recency without maintaining a separate linked list.

Trace: with capacity 3 and keys inserted in order `a, b, c`, calling `get('a')` deletes and re-inserts `a`, so the Map's iteration order becomes `b, c, a`. A subsequent `put('d', ...)` sees `cache.size >= capacity`, reads `cache.keys().next().value`, which is now `b`, and evicts it, correctly preserving `a` because it was accessed more recently than `b`.

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
Trace: after `obj = null`, nothing in the program still holds a strong reference to that object literal, since the `WeakMap` only ever held a weak one. The garbage collector is now free to reclaim it, and its entry in `wm` disappears at some unspecified future point. There's no way to observe this happening directly, which is exactly why `WeakMap` doesn't expose iteration or a `size` property.

**Use case:** associating extra data with a DOM element (or other object) without causing a memory leak if that object is later removed or discarded.

**Interview soundbite:** "Weak" is the memory-safe version of `Map`/`Set`, for when you need to associate data with an object temporarily without risking a leak.

---

## 10. Theory Quick Reference

A rapid-fire recall list across JavaScript, React, browser APIs, CSS, and TypeScript. Each entry is meant as a memory jog, not a full explanation, cross-referencing the worked examples earlier in this document where relevant.

### JavaScript

- **var, let, const**: three ways to declare a variable, differing in scope and mutability.
  - `var` is function-scoped and can be redeclared.
  - `let` is block-scoped and can be reassigned but not redeclared in the same scope.
  - `const` is block-scoped and cannot be reassigned after initialization.
- **Hoisting**: declarations are lifted to the top of their scope before the code runs, but different kinds of declarations are lifted differently.
  - `var` is hoisted and initialized to `undefined`.
  - `let`/`const` are hoisted but stay in the "temporal dead zone" until their line executes, so touching them earlier throws a `ReferenceError`.
  - Function declarations are hoisted in full, body included, so they can be called before the line where they're written.
- **Closures**: a function keeps access to variables from its outer scope even after that outer function has already returned. This is what makes `useDebounce` above work: the timer callback still "remembers" the `state` value from the render that created it.
- **`this`**: its value depends on how a function is called, the call site, not where the function is defined. Arrow functions don't get their own `this`; they inherit it lexically from the surrounding scope, which is why they're preferred for callbacks inside class methods or components.
- **call / apply / bind**: three ways to control what `this` refers to inside a function.
  - `call(thisArg, a, b)` invokes the function immediately with arguments listed individually.
  - `apply(thisArg, [a, b])` invokes the function immediately with arguments passed as an array.
  - `bind(thisArg)` doesn't invoke the function; it returns a new function permanently bound to `thisArg`, to be called later.
- **Event loop**: synchronous code runs first, then the microtask queue drains (Promise callbacks), then one macrotask runs (like a `setTimeout` callback), and the cycle repeats. That ordering is why `Promise.resolve().then()` always fires before `setTimeout(fn, 0)`, even though both are scheduled for "later."
- **`==` vs `===`**: `==` coerces both sides to a common type before comparing, which can produce surprises like `"0" == false` being `true`. `===` compares value and type with no coercion, which is why it's the safer default.
- **Deep vs shallow copy**: a shallow copy duplicates only the top level of an object; nested objects and arrays are still shared references between the original and the copy. A deep copy, like the `deepClone` polyfill above, recursively duplicates every level so nothing is shared.
- **Prototypal inheritance**: when a property isn't found directly on an object, JavaScript looks up the object's prototype chain until it finds the property or reaches `null`.
- **Currying**: transforming a function that takes multiple arguments into a sequence of functions that each take one argument, returning a new function until every argument has been supplied.
- **Debounce vs throttle**: both limit how often a function runs, but on different triggers. Debounce waits for activity to stop for a set delay before firing, as in `useDebounce` above. Throttle fires at a fixed interval regardless of how much activity happens in between.
- **async/await**: syntactic sugar over Promises. An `async` function always returns a Promise, and `await` pauses execution inside that function until the awaited Promise settles. Errors from a rejected awaited Promise are handled with a normal `try/catch`.
- **Pure function**: given the same input, it always returns the same output, and it doesn't read or modify anything outside itself.
- **null vs undefined**: `undefined` means a variable was declared but never assigned a value. `null` means a value was deliberately set to represent "no value."
- **`typeof null`**: returns `"object"`, the long-standing quirk that the `deepClone` bug note above explains the practical impact of.
- **Higher-order function**: a function that takes another function as an argument, returns a function, or both.

### React

- **Virtual DOM**: a lightweight in-memory representation of the real DOM. React diffs the new virtual tree against the previous one and applies only the minimal set of real DOM updates needed, instead of re-rendering the page from scratch.
- **useState vs useRef**: both persist a value across renders, but only one triggers a re-render. `useState` re-renders whenever its setter is called. `useRef` persists a value across renders without causing a re-render when it changes, which is why it's used for something like the `observerTarget` sentinel in the infinite-scroll example above.
- **useEffect**: runs after the component renders and the DOM updates. The dependency array controls when it re-runs: an empty array means "once, after the first render"; listing values means "re-run whenever any of these change." Its optional cleanup function runs before the next run and again on unmount, which is why the stale-closure fix above clears its interval there.
- **useEffect vs useLayoutEffect**: `useEffect` runs asynchronously after the browser paints, so it doesn't block visual updates. `useLayoutEffect` runs synchronously before the browser paints, blocking it, which matters when the DOM needs to be measured or mutated before the user sees it.
- **useMemo vs useCallback**: both skip recomputation when dependencies haven't changed, for different kinds of value. `useMemo` memoizes the result of a computation. `useCallback` memoizes the function reference itself, so a child wrapped in `React.memo` doesn't see a "new" function prop on every render.
- **React.memo**: wraps a component so React skips re-rendering it when its props are shallow-equal to the previous render's props.
- **Controlled vs uncontrolled**: describes where an input's value lives. Controlled means the value lives in React state and the input's `value` prop reflects it. Uncontrolled means the value lives in the DOM itself, read out via a `ref` only when needed.
- **key prop**: tells React which array item corresponds to which rendered element across re-renders, so it can correctly reuse, reorder, or discard DOM nodes. Using the array index as the key breaks this when items are reordered, inserted, or removed, since the index no longer maps to the same logical item.
- **Context API**: lets data flow deeply through the component tree without passing props down manually at every level, as shown in the compound-component and `ThemeContext` examples above.
- **Custom hooks**: reusable stateful logic pulled into a function whose name starts with `use`, so React's linter can apply the rules of hooks to it, like `useDebounce`, `useFetch`, and `useLocalStorage` above.
- **Compound components**: parent and child components that implicitly share state through Context rather than explicit props, mirroring how the native `<select><option>` pair works.
- **HOC vs custom hook**: both reuse logic across components. A Higher-Order Component wraps a component and returns a new one, adding UI or behavior around it. A custom hook only reuses stateful logic and renders nothing itself.
- **Error boundaries**: class components that catch JavaScript errors thrown during rendering in their child tree and render a fallback UI instead of crashing the whole app.
- **State management split**: a common convention is Redux Toolkit for client/UI state (things like "is this modal open") and React Query for server state (data fetched from an API, including its caching and refetching).
- **Code splitting**: `React.lazy` combined with `Suspense` loads component bundles on demand instead of shipping one large upfront bundle, reducing initial load time.
- **Portals**: render a component's output into a DOM node outside its normal parent hierarchy, commonly used for modals and tooltips that need to escape a parent's `overflow: hidden` or stacking context.
- **Forward ref**: lets a parent component obtain a reference to a DOM node that lives inside a child component, which the child wouldn't otherwise expose.

### Async / Browser

- **Race condition fix (fetch)**: cancel the previous in-flight request with `AbortController` whenever a new one starts, exactly as `useFetch` does above. Without this, a slower earlier response can resolve after a faster later one and overwrite the UI with stale data.
- **fetch vs axios**: `fetch` is built into the browser and requires manually calling `.json()` and manually checking `response.ok` for HTTP errors. `axios` is a library that parses JSON automatically and throws on non-2xx responses by default, with richer error objects.
- **CORS**: a browser security mechanism that blocks a page from making cross-origin requests unless the server explicitly allows it via response headers.
- **localStorage / sessionStorage / cookies**: three ways to persist data in the browser. `localStorage` persists indefinitely until explicitly cleared. `sessionStorage` clears when the tab closes. Cookies are small, and unlike the other two, get sent to the server automatically with every matching request.
- **Intersection Observer**: detects when an element enters or exits the viewport, used above for infinite scroll and commonly used for lazy-loading images.
- **Rendering pipeline**: the browser parses HTML into a DOM tree, computes styles for each node, calculates layout, then paints pixels to the screen, in that order.

### CSS

- **Box model**: controls what an element's `width`/`height` include. `content-box` (the default) applies width/height only to the content, with padding and border added on top. `border-box` includes padding and border inside the stated width/height, so the rendered size matches what's set.
- **Flexbox vs Grid**: Flexbox lays out items along a single axis, a row or a column. Grid lays out items along two axes, rows and columns together, which suits full page or section layouts better.
- **Position types**: `relative` offsets an element from its own normal position while the original space stays reserved. `absolute` positions it relative to the nearest ancestor with a non-static position and removes it from normal flow. `fixed` pins it to the viewport regardless of scrolling. `sticky` behaves like `relative` until a scroll threshold is crossed, then switches to behaving like `fixed`.
- **Specificity**: determines which CSS rule wins when multiple rules target the same element. ID selectors beat class selectors, which beat element selectors, regardless of the order the rules appear in the stylesheet.
- **em vs rem**: `em` is relative to the parent element's font-size and compounds when nested. `rem` is always relative to the root `html` element's font-size, which makes sizing easier to reason about in deeply nested markup.
- **BFC (Block Formatting Context)**: an independent layout region that contains floated children and prevents margin collapse with elements outside it. Properties like `overflow: hidden` or `display: flex`/`grid` create a new BFC as a side effect.
- **display:none vs visibility:hidden vs opacity:0**: all hide an element visually but differ in layout and interactivity. `display: none` removes it from layout entirely, with no space reserved, and it can't receive events. `visibility: hidden` keeps its space reserved but hides it and blocks events. `opacity: 0` keeps its space reserved and hides it visually, but events like clicks still fire since it's technically still there.
- **Media queries**: the common approach is mobile-first, writing base styles for mobile and then using `min-width` queries to add or override styles as the viewport grows.
- **z-index**: only has an effect on elements whose `position` is not `static`.

### TypeScript

- **interface vs type**: largely interchangeable for describing object shapes but diverge in specific cases. `interface` supports declaration merging (redeclaring the same interface adds to it) and reads more naturally with `extends`. `type` aliases handle unions and intersections more flexibly and can alias any type, not just object shapes.
- **Generics**: reusable type placeholders, written as `<T>`, that let a function or component work across a range of types while staying fully type-checked, instead of resorting to `any`.
- **any vs unknown**: `any` disables type checking entirely for that value, forfeiting safety. `unknown` also accepts any value but requires a type check or a cast before it can be used, making it the safer choice when a type genuinely isn't known yet.
- **Union vs Intersection**: a union type (`A | B`) means a value can be either `A` or `B`. An intersection type (`A & B`) means a value must satisfy both `A` and `B` at once.
- **Optional chaining / nullish coalescing**: `?.` short-circuits to `undefined` instead of throwing when accessing a property on `null`/`undefined`. `??` provides a fallback only when the left side is specifically `null` or `undefined`, unlike `||`, which also falls back on other falsy values like `0` or `""`, the same falsy-value trap the `useLocalStorage` bug note above covers.

### Architecture talking points
- Folder structure organized by feature (components, hooks, and services grouped together) rather than by file type.
- API access kept separate from UI components, usually through custom hooks that wrap `fetch` or React Query.
- Redux Toolkit for client/UI state, React Query for server state: be ready to explain that boundary and why it exists.
- Centralized error handling combining error boundaries, per-request `try/catch`, and user-facing messaging.
- Performance at scale: list virtualization, lazy loading, code splitting.
- Be ready to explain the trade-offs behind each choice; interviewers are usually testing the reasoning more than the specific answer.

---

## Personal Project Talking Point: IntelliFinance AI

**Problem:** managing expenses across multiple bank accounts is tedious. Existing budgeting apps track spending but don't automatically reconcile invoices or receipts against bank transactions across accounts.

**Solution flow:** user uploads bank statements/invoices as PDFs → sent to an LLM for parsing → LLM returns structured JSON (date, amount, category) → backend auto-matches this against existing transactions by date/amount → on match, the invoice is linked to that transaction → user gets a dashboard showing category-wise spending breakdown.

**Stack:** React + Redux Toolkit (frontend), Django REST Framework (backend), LLM integration for document parsing, Docker/AWS for deployment.

Framing tip: never call your own project "very simple" in an interview. Present it confidently: problem, solution, architecture, then one interesting design decision, regardless of the project's size.
