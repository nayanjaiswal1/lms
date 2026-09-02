---
kind: lesson
id_key: interview-prep-45/fe-js-utility-patterns-memory
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "JavaScript Utility Patterns: Cloning, Caching, and Memory"
position: 8
estimated_minutes: 35
source:
    - interview-prep-notes.md
---
This lesson is a grab bag on purpose, the kind of thing that comes up as a rapid-fire warm-up round before the "real" interview questions start: cloning an object correctly, why `0.1 + 0.2` isn't `0.3`, building a cache that evicts the right entry, and knowing when a `Map` isn't the tool you want. None of these need much setup. All of them are the sort of thing that's either instant recall or an embarrassing pause.

## Why 0.1 + 0.2 isn't 0.3

```js
0.1 + 0.2;          // 0.30000000000000004
0.1 + 0.2 === 0.3;  // false
```

JS numbers are IEEE 754 double-precision floats, binary fractions under the hood. `0.1` and `0.2` have no exact binary representation, the same reason `1/3` has no exact decimal one, so each gets stored as the closest double the format can represent. Adding those two approximations doesn't land exactly on `0.3`'s own stored approximation.

Never compare floats for exact equality; compare within a tolerance instead:

```js
Math.abs((0.1 + 0.2) - 0.3) < Number.EPSILON; // true
```

For money specifically, skip floats entirely: store cents as integers, or reach for a decimal library. This isn't a style preference, it's the difference between a price that's occasionally off by a fraction of a cent and one that never is.

## Cloning: three tools with three different gaps

`JSON.parse(JSON.stringify(obj))` deep-clones plain data, but it silently mangles or drops anything JSON has no representation for:

| Type | What happens |
|---|---|
| `undefined` | key dropped entirely |
| Functions | dropped entirely |
| `Symbol` | dropped entirely |
| `Date` | becomes a string, loses its methods |
| `Map` / `Set` | becomes `{}` |
| Circular reference | throws `TypeError` |

`structuredClone(obj)` is native, needs no import, and correctly handles `Date`, `Map`, `Set`, circular references, and typed arrays, the same algorithm browsers already use internally for `postMessage`.

```js
const original = { date: new Date(), tags: new Set(['a']) };
structuredClone(original);           // Date and Set survive intact
JSON.parse(JSON.stringify(original)); // date -> string, tags -> {}
```

Run both on the same object and they diverge immediately: `structuredClone` walks the graph and rebuilds a real `Date` and a real `Set` on the clone, so `clone.date.getFullYear()` still works. `JSON.stringify` has no representation for either, so it serializes the `Date` through its `toJSON` method into a plain string, and the `Set` becomes `{}`, since `JSON.stringify` only sees enumerable own properties and a `Set`'s entries aren't stored that way.

`structuredClone` isn't the final word, though. It throws on functions, and it loses the prototype chain of class instances entirely, a cloned instance comes back as a plain object, not an instance of that class. That's the one gap Lodash's `cloneDeep` still fills:

```js
import cloneDeep from 'lodash/cloneDeep';
const clone = cloneDeep(original); // preserves class instances and functions, at the cost of a dependency
```

Default to `structuredClone` for plain data. Reach for `cloneDeep` specifically when the object graph contains functions or class instances that need to survive the clone. For a shallow copy, spread (`{ ...original }`) and `Object.assign({}, original)` do the same thing, top-level keys only, any nested object or array is still the *same reference* in the copy, so mutating a nested field mutates the original too.

## What a hand-rolled deep clone actually looks like

Worth knowing as the "explain the mechanism" answer, not as something to ship over `structuredClone`:

```js
function deepClone(value) {
  if (typeof value !== "object" || value === null) return value; // primitives AND null
  if (Array.isArray(value)) return value.map(deepClone);
  return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, deepClone(v)]));
}
```

`typeof null` returns `"object"`, so the null check has to be explicit, or the function crashes trying to enumerate `null`'s entries. Trace it on `{ a: 1, b: { c: 2 } }`: `a` hits the primitive base case and returns unchanged; `b` recurses into the object branch and builds a brand-new `{ c: 2 }`, not the original reference. Every level of nesting ends up with its own new object or array instead of a shared one, which is exactly the property `JSON.stringify` and `structuredClone` both give you natively, and this function doesn't: no `Date`, `Map`, `Set`, or circular-reference handling, which is exactly why the native primitive exists instead of everyone hand-rolling this.

## Two more classic polyfills, and the bugs that hide in them

```js
function memoize(cb) {
  const cache = {};
  return function (...args) {
    const key = JSON.stringify(args);
    if (key in cache) return cache[key]; // `in`, not truthiness — handles a cached 0 correctly
    const result = cb(...args); // spread, not the raw array
    cache[key] = result;
    return result;
  };
}
```

Two bugs this version avoids on purpose: `cb(args)` would pass the whole array as a single argument, so the call has to spread it; and `if (cache[key])` would fail for a legitimately falsy cached result like `0`, so the lookup uses `key in cache` instead of a truthiness check, the same `in`-versus-truthiness distinction from the previous lesson.

```js
function flatten(val, result = []) {
  if (Array.isArray(val)) {
    val.forEach((entry) => flatten(entry, result)); // must pass the SAME result array through
  } else {
    result.push(val);
  }
  return result;
}
```

The bug to avoid here: forgetting to pass `result` through the recursive call means each call creates its own fresh `[]` from the default parameter, and nothing ever accumulates. Trace `flatten([1, [2, [3, 4]], 5])`: hitting `1` pushes it into the shared `result`; hitting the nested `[2, [3, 4]]` recurses with that *same* array rather than a new one, so those pushes land in the outer array too. By the time recursion unwinds, `result` is `[1, 2, 3, 4, 5]`. Notice `deepClone` builds a new value at every level, an immutable style, while `flatten` mutates one shared accumulator, a mutable style; knowing the difference between the two recursion patterns is worth naming explicitly if it comes up.

## LRU cache: Map's insertion order does the work for you

An LRU cache has a fixed capacity, and once full, it evicts whichever entry hasn't been touched the longest to make room for a new one.

```js
class LRUCache {
  constructor(capacity) {
    this.capacity = capacity;
    this.cache = new Map(); // Map preserves insertion order
  }
  get(key) {
    if (!this.cache.has(key)) return -1;
    const value = this.cache.get(key);
    this.cache.delete(key);
    this.cache.set(key, value); // delete + re-set moves this key to the "end" = most recently used
    return value;
  }
  put(key, value) {
    if (this.cache.has(key)) {
      this.cache.delete(key);
    } else if (this.cache.size >= this.capacity) {
      const oldestKey = this.cache.keys().next().value; // Map's first key is always least-recently-used
      this.cache.delete(oldestKey);
    }
    this.cache.set(key, value);
  }
}
```

`Map` is the right tool here specifically because it preserves insertion order, and re-inserting a key via delete-then-set moves it to the end, an O(1) way to track recency with no separate linked list to maintain. Trace it with capacity 3 and keys inserted `a, b, c`: calling `get('a')` deletes and re-inserts `a`, so iteration order becomes `b, c, a`. A subsequent `put('d', ...)` sees the cache is full, reads the first key via the iterator, now `b`, and evicts it, correctly keeping `a` around because it was touched more recently.

## WeakMap and WeakSet: when you don't want to be the reason something can't be garbage collected

| | `Map`/`Set` | `WeakMap`/`WeakSet` |
|---|---|---|
| Keys/values | Any type | Objects only |
| Iteration | `.forEach`, `.keys()`, `.size` | Not available, GC timing is unpredictable |
| Memory | Strong reference, prevents GC | Weak reference, entry is auto-removed once GC'd |

```js
let obj = { name: "Nayan" };
const wm = new WeakMap();
wm.set(obj, "metadata");
obj = null; // no other references left → the WeakMap entry becomes eligible for GC automatically
```

Once `obj = null` runs, nothing in the program still holds a strong reference to that object, since the `WeakMap` only ever held a weak one. The garbage collector is now free to reclaim it, and its entry in `wm` disappears at some unspecified future point, with no way to observe exactly when. That unobservability is exactly why `WeakMap` exposes no iteration and no `size`: the contents can change out from under you at any time the GC decides to run. The use case worth having ready: associating extra data with a DOM element or other object without risking a memory leak if that object is later removed from the page.

## Avoiding accidental O(n²) on large arrays

Two patterns that quietly turn a linear operation quadratic, worth catching in a code review as much as in an interview:

- `.includes()` or `.indexOf()` called inside a loop over another array is a hidden nested loop. Swap the array being searched into a `Set` or `Map` so each lookup becomes O(1) instead of O(n).
- CPU-heavy work that blocks the main thread, as distinct from I/O-bound work, belongs in a **Web Worker**, not artificially chunked with `setTimeout` calls to fake non-blocking behavior.

A `.map().filter().reduce()` chain is fine for readability at normal sizes, since each step just allocates one intermediate array, but for genuinely large arrays a single `for` loop, or one `reduce` doing everything, avoids the repeated allocation.

**Top-K frequency**, the algorithmic pattern this shows up as most often: build a frequency map first, `O(n)`, then pick an approach for extracting the top K. Sorting by count is `O(n log n)` and the simplest to write correctly under interview pressure. A min-heap of size K is `O(n log k)`, worth it specifically when `k` is small relative to `n`, since you never hold more than K elements at once. Bucket sort by frequency, where the bucket index is the count itself, is `O(n)` and optimal, but more code to get exactly right; naming it shows you know it exists, and reaching for actually writing it is worth doing only if the interviewer pushes on complexity.

## EventEmitter: the pattern under pub/sub

This is the core of Node's `events` module, and conceptually the same shape React's own synthetic event system dispatches through: a plain object mapping event names to arrays of listeners.

```js
class EventEmitter {
  constructor() { this.listeners = {}; }
  on(event, cb) { (this.listeners[event] ??= []).push(cb); return this; } // chainable
  off(event, cb) { this.listeners[event] = (this.listeners[event] || []).filter(fn => fn !== cb); }
  emit(event, ...args) { (this.listeners[event] || []).forEach(cb => cb(...args)); }
}

const bus = new EventEmitter();
const onGreet = (name) => console.log(`hi ${name}`);
bus.on('greet', onGreet);
bus.emit('greet', 'Nayan'); // "hi Nayan"
bus.off('greet', onGreet);
```

`bus.on(...)` pushes onto `listeners.greet`, creating that array on first use via `??=`, and returns `bus` itself so calls can chain, the exact method-chaining convention from the previous lesson. `bus.emit(...)` calls every listener synchronously, on the same call stack as the `emit` call, not deferred to a microtask or macrotask the way a Promise callback would be. `bus.off(...)` replaces the array with a filtered copy, so a later `emit` calls no one that was removed.
