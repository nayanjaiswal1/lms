---
kind: lesson
id_key: interview-prep-45/fe-js-utility-patterns-memory
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "JavaScript Utility Patterns: Cloning, Caching, and Memory"
position: 8
estimated_minutes: 35
source:
    - interview-prep-notes.md
---
This lesson is a grab bag on purpose, the kind of thing that comes up as a rapid warm-up round before the "real" interview questions start: cloning an object correctly, why `0.1 + 0.2` isn't `0.3`, building a cache that evicts the right entry, and knowing when a `Map` isn't the tool you want. None of these need much setup. All of them are either instant recall or an embarrassing pause.

## Why 0.1 + 0.2 isn't 0.3

```js
0.1 + 0.2;          // 0.30000000000000004
0.1 + 0.2 === 0.3;  // false
```

Picture trying to write `1/3` exactly in decimal: `0.3333...` never ends, so any fixed number of digits is an approximation. Computers hit the same wall in binary, just for different fractions. `0.1` and `0.2` have no exact binary representation, so each gets stored as the closest double-precision float the format can represent. Adding those two approximations does not land exactly on `0.3`'s own stored approximation.

Never compare floats for exact equality; compare within a tolerance instead:

```js
Math.abs((0.1 + 0.2) - 0.3) < Number.EPSILON; // true
```

For money specifically, skip floats entirely: store cents as integers, or reach for a decimal library. This is not a style preference, it is the difference between a price that's occasionally off by a fraction of a cent and one that never is.

> **Remember:** `0.1` and `0.2` can't be stored exactly in binary. Never compare floats with `===`; compare within a tolerance, or use integer cents for money.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-floats-q1", "type": "mcq",
      "prompt": "Why does `0.1 + 0.2 === 0.3` return `false` in JavaScript?",
      "options": [
        {"id":"a","text":"It's a bug specific to the V8 engine"},
        {"id":"b","text":"0.1 and 0.2 have no exact binary floating-point representation, so each is stored as the closest approximation, and their sum doesn't land exactly on 0.3's own approximation"},
        {"id":"c","text":"JavaScript rounds all decimals to 2 places"},
        {"id":"d","text":"+ always converts numbers to strings first"}
      ],
      "correct": "b",
      "explanation": "This is standard IEEE 754 double-precision floating point behavior, shared by nearly every mainstream language, not a JavaScript-specific bug. Some decimal fractions simply have no exact binary form." }
] }
```

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

Run both on the same object and they diverge immediately: `structuredClone` walks the graph and rebuilds a real `Date` and a real `Set` on the clone, so `clone.date.getFullYear()` still works. `JSON.stringify` has no representation for either, so it serializes the `Date` through its `toJSON` method into a plain string, and the `Set` becomes `{}`, since `JSON.stringify` only sees enumerable own properties, and a `Set`'s entries aren't stored that way.

`structuredClone` isn't the final word, though. It throws on functions, and it loses the prototype chain of class instances entirely: a cloned instance comes back as a plain object, not an instance of that class. That is the one gap Lodash's `cloneDeep` still fills:

```js
import cloneDeep from 'lodash/cloneDeep';
const clone = cloneDeep(original); // preserves class instances and functions, at the cost of a dependency
```

Default to `structuredClone` for plain data. Reach for `cloneDeep` specifically when the object graph contains functions or class instances that need to survive the clone. For a shallow copy, spread (`{ ...original }`) and `Object.assign({}, original)` do the same thing: top-level keys only, any nested object or array is still the *same reference* in the copy, so mutating a nested field mutates the original too.

> **Remember:** `structuredClone` is the default. Reach for `cloneDeep` only when the object graph has functions or class instances to preserve.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-cloning-q1", "type": "mcq",
      "prompt": "An object contains a `Map` and a `Date`. You clone it with `JSON.parse(JSON.stringify(obj))`. What happens to those two fields?",
      "options": [
        {"id":"a","text":"Both survive perfectly intact"},
        {"id":"b","text":"The Map becomes {}, and the Date becomes a plain string that has lost its Date methods"},
        {"id":"c","text":"The clone throws a TypeError immediately"},
        {"id":"d","text":"Both fields are dropped entirely"}
      ],
      "correct": "b",
      "explanation": "JSON has no representation for a Map (JSON.stringify only sees enumerable own properties, which a Map doesn't store its entries as) or a live Date object (it serializes through toJSON into a plain string). structuredClone handles both correctly." }
] }
```

## What a hand-rolled deep clone actually looks like

Worth knowing as the "explain the mechanism" answer, not as something to ship over `structuredClone`:

```js
function deepClone(value) {
  if (typeof value !== "object" || value === null) return value; // primitives AND null
  if (Array.isArray(value)) return value.map(deepClone);
  return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, deepClone(v)]));
}
```

`typeof null` returns `"object"`, so the null check has to be explicit, or the function crashes trying to enumerate `null`'s entries. Trace it on `{ a: 1, b: { c: 2 } }`: `a` hits the primitive base case and returns unchanged; `b` recurses into the object branch and builds a brand-new `{ c: 2 }`, not the original reference. Every level of nesting ends up with its own new object or array instead of a shared one, which is exactly the property `JSON.stringify` and `structuredClone` both give you natively, minus `Date`, `Map`, `Set`, or circular-reference handling, which is exactly why the native primitive exists instead of everyone hand-rolling this.

> **Remember:** `typeof null === "object"`, so a recursive clone must check for `null` explicitly before trying to recurse into it.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-deepclone-q1", "type": "mcq",
      "prompt": "The hand-rolled `deepClone` function checks `if (typeof value !== \"object\" || value === null) return value;` at the top. Why is the explicit `null` check needed?",
      "options": [
        {"id":"a","text":"It's unnecessary, typeof null already returns 'null'"},
        {"id":"b","text":"typeof null returns 'object', so without the explicit check the function would try to call Object.entries(null) and crash"},
        {"id":"c","text":"null values should always throw an error"},
        {"id":"d","text":"JavaScript treats null and undefined identically here"}
      ],
      "correct": "b",
      "explanation": "typeof null is a decades-old quirk that returns 'object'. Without checking for null explicitly, the object branch would run and Object.entries(null) would throw." }
] }
```

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

Two bugs this version avoids on purpose: `cb(args)` would pass the whole array as a single argument, so the call has to spread it; and `if (cache[key])` would fail for a legitimately falsy cached result like `0`, so the lookup uses `key in cache` instead of a truthiness check, the same `in`-versus-truthiness distinction from the functions lesson.

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

The bug to avoid here: forgetting to pass `result` through the recursive call means each call creates its own fresh `[]` from the default parameter, and nothing ever accumulates. Trace `flatten([1, [2, [3, 4]], 5])`: hitting `1` pushes it into the shared `result`; hitting the nested `[2, [3, 4]]` recurses with that *same* array rather than a new one, so those pushes land in the outer array too. By the time recursion unwinds, `result` is `[1, 2, 3, 4, 5]`. Notice `deepClone` builds a new value at every level, an immutable style, while `flatten` mutates one shared accumulator, a mutable style; knowing the difference between the two recursion patterns is worth naming if it comes up.

> **Remember:** a naive cache lookup with `if (cache[key])` fails the moment the cached, correct answer happens to be `0`. Use `key in cache`.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-memoize-q1", "type": "mcq",
      "prompt": "A memoize function checks `if (cache[key]) return cache[key];` instead of `if (key in cache)`. What bug does this introduce?",
      "options": [
        {"id":"a","text":"None, both checks behave identically"},
        {"id":"b","text":"If a function legitimately returns a falsy value like 0 for some input, the cache is treated as a miss every time, so the function reruns unnecessarily"},
        {"id":"c","text":"The cache grows without bound"},
        {"id":"d","text":"It throws an error on the second call"}
      ],
      "correct": "b",
      "explanation": "Truthiness checks can't tell 'cached value is 0' apart from 'nothing is cached'. key in cache checks existence directly, regardless of what the stored value actually is." }
] }
```

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

> **Remember:** a `Map` keeps keys in insertion order. Delete-then-set a key to move it to the "most recently used" end for free.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-lru-q1", "type": "mcq",
      "prompt": "In the LRUCache above, why does `get(key)` delete the key and then immediately set it again, instead of just returning `this.cache.get(key)`?",
      "options": [
        {"id":"a","text":"It doesn't need to, this is unnecessary overhead"},
        {"id":"b","text":"Delete-then-set moves the key to the end of the Map's insertion order, marking it as most recently used, so eviction (which reads the first/oldest key) stays correct"},
        {"id":"c","text":"Map.get() has a bug that requires this workaround"},
        {"id":"d","text":"It clears the cache's memory usage"}
      ],
      "correct": "b",
      "explanation": "A Map's iteration order follows insertion order. Re-inserting a key on every access is what keeps that order doubling as a recency order, which is exactly what an LRU eviction policy needs." }
] }
```

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

Once `obj = null` runs, nothing in the program still holds a strong reference to that object, since the `WeakMap` only ever held a weak one. The garbage collector is now free to reclaim it, and its entry in `wm` disappears at some unspecified future point, with no way to observe exactly when. That unobservability is exactly why `WeakMap` exposes no iteration and no `size`: the contents can change out from under you at any time the garbage collector decides to run. The use case worth having ready: attaching extra data to a DOM element or other object without risking a memory leak if that object is later removed from the page.

> **Remember:** a `WeakMap` holds its keys weakly. If nothing else references a key, it, and its entry, can be garbage collected.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-weakmap-q1", "type": "mcq",
      "prompt": "Why can't you call `.size` or iterate over a `WeakMap`, unlike a regular `Map`?",
      "options": [
        {"id":"a","text":"It's an arbitrary API limitation with no real reason"},
        {"id":"b","text":"WeakMap entries can be garbage collected at any unpredictable time, so its contents could change mid-iteration or mid-count with no way to observe when"},
        {"id":"c","text":"WeakMap can only ever hold one entry"},
        {"id":"d","text":"WeakMap is deprecated"}
      ],
      "correct": "b",
      "explanation": "A WeakMap's whole purpose is holding keys weakly enough that the garbage collector can reclaim them silently. Exposing iteration or a size count would require pinning down contents that are deliberately allowed to disappear at any time." }
] }
```

## Avoiding accidental O(n²) on large arrays

Two patterns that quietly turn a linear operation quadratic, worth catching in a code review as much as in an interview:

- `.includes()` or `.indexOf()` called inside a loop over another array is a hidden nested loop. Swap the array being searched into a `Set` or `Map` so each lookup becomes O(1) instead of O(n).
- CPU-heavy work that blocks the main thread, as distinct from I/O-bound work, belongs in a **Web Worker**, not artificially chunked with `setTimeout` calls to fake non-blocking behavior.

A `.map().filter().reduce()` chain is fine for readability at normal sizes, since each step just allocates one intermediate array, but for genuinely large arrays a single `for` loop, or one `reduce` doing everything, avoids the repeated allocation.

**Top-K frequency**, the algorithmic pattern this shows up as most often: build a frequency map first, `O(n)`, then pick an approach for extracting the top K. Sorting by count is `O(n log n)` and the simplest to write correctly under interview pressure. A min-heap of size K is `O(n log k)`, worth it specifically when `k` is small relative to `n`, since you never hold more than K elements at once. Bucket sort by frequency, where the bucket index is the count itself, is `O(n)` and optimal, but more code to get exactly right; naming it shows you know it exists, and reaching for actually writing it is worth doing only if the interviewer pushes on complexity.

> **Remember:** `.includes()` inside a loop is a hidden nested loop. Swap the searched array into a `Set` to turn O(n²) into O(n).

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-onsquared-q1", "type": "mcq",
      "prompt": "A function loops over array A and calls `B.includes(item)` on each element, where B is another large array. What's the fix for the hidden O(n*m) cost?",
      "options": [
        {"id":"a","text":"Use a for loop instead of forEach"},
        {"id":"b","text":"Convert B into a Set once before the loop, so each .has() lookup is O(1) instead of O(m)"},
        {"id":"c","text":"Sort array A first"},
        {"id":"d","text":"There's no fix, this is the best possible approach"}
      ],
      "correct": "b",
      "explanation": "Array.includes() is a linear scan, so calling it inside another loop multiplies the costs. Converting the searched array into a Set turns each lookup into O(1), collapsing the whole operation to O(n+m)." }
] }
```

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

`bus.on(...)` pushes onto `listeners.greet`, creating that array on first use via `??=`, and returns `bus` itself so calls can chain, the same method-chaining convention from the functions lesson. `bus.emit(...)` calls every listener synchronously, on the same call stack as the `emit` call, not deferred to a microtask or macrotask the way a Promise callback would be. `bus.off(...)` replaces the array with a filtered copy, so a later `emit` calls no one that was removed.

> **Remember:** `emit` runs every listener synchronously, right there on the call stack. It is not deferred like a Promise callback.
