---
kind: lesson
id_key: interview-prep-45/note-float-precision-clone-eventemitter
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: Floating-Point Precision, Deep Clone & EventEmitter"
position: 100
estimated_minutes: 15
source:
    - interview-prep-notes.md
---
## Why 0.1 + 0.2 === 0.3 is false

```js
0.1 + 0.2; // 0.30000000000000004
0.1 + 0.2 === 0.3; // false
```

JS numbers are IEEE 754 double-precision floats: binary fractions under the hood. `0.1` and `0.2` have no exact binary representation, for the same reason `1/3` has no exact decimal representation, so each is stored as the closest approximate double. Adding those two approximations doesn't land exactly on `0.3`'s own stored approximation.

Fix: never compare floats for exact equality, compare within a tolerance instead.

```js
Math.abs((0.1 + 0.2) - 0.3) < Number.EPSILON; // true, tolerance-based comparison
```

For money specifically, don't use floats at all: store cents as integers, or use a decimal library.

## Deep clone: JSON.parse(JSON.stringify(x)) vs structuredClone

`JSON.parse(JSON.stringify(obj))` deep-clones plain data but silently drops or mangles anything JSON can't represent:

| Type | Result |
|---|---|
| `undefined` | key dropped entirely |
| Functions | dropped entirely |
| `Symbol` | dropped entirely |
| `Date` | becomes a string (loses `Date` methods) |
| `Map` / `Set` | becomes `{}` |
| Circular reference | throws `TypeError` |

`structuredClone(obj)` is native, no import needed, and handles `Date`, `Map`, `Set`, circular references, and typed arrays correctly. It's the same structured clone algorithm browsers already use for `postMessage`. Default to `structuredClone` unless you specifically need JSON's "strip anything non-serializable" behavior, such as sanitizing an object before sending it somewhere JSON-only.

```js
const original = { date: new Date(), tags: new Set(['a']) };
structuredClone(original); // Date and Set survive intact
JSON.parse(JSON.stringify(original)); // date -> string, tags -> {}
```

Run both on the same `original` and they diverge immediately: `structuredClone` walks the object graph and reconstructs a real `Date` instance and a real `Set` instance on the clone, so `clone.date.getFullYear()` still works. `JSON.stringify` has no representation for either type, so it serializes the `Date` via its `toJSON` method into a plain string and serializes the `Set` as `{}` since `JSON.stringify` only sees enumerable own properties, and a `Set`'s entries aren't stored that way.

## EventEmitter pattern

This is the core of Node's `events` module, and conceptually close to how React's synthetic event system dispatches: a plain object holding a map from event name to an array of listeners.

```js
class EventEmitter {
  constructor() {
    this.listeners = {}; // { eventName: [callbacks] }
  }
  on(event, cb) {
    (this.listeners[event] ??= []).push(cb);
    return this; // chainable
  }
  off(event, cb) {
    this.listeners[event] = (this.listeners[event] || []).filter(fn => fn !== cb);
  }
  emit(event, ...args) {
    (this.listeners[event] || []).forEach(cb => cb(...args));
  }
}

const bus = new EventEmitter();
const onGreet = (name) => console.log(`hi ${name}`);
bus.on('greet', onGreet);
bus.emit('greet', 'Nayan'); // "hi Nayan"
bus.off('greet', onGreet);
```

Tracing the calls above: `bus.on('greet', onGreet)` pushes `onGreet` onto `listeners.greet` (creating that array on first use via `??=`) and returns `bus` itself so calls can chain. `bus.emit('greet', 'Nayan')` then looks up `listeners.greet` and calls every function in it with `'Nayan'` as the argument, synchronously, on the same call stack as the `emit` call itself, not deferred to a microtask or macrotask. `bus.off('greet', onGreet)` replaces the array with a filtered copy that excludes `onGreet`, so a later `emit` would call no one.
