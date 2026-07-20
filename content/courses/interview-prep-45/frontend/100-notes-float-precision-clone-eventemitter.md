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

JS numbers are IEEE 754 double-precision floats — binary fractions. `0.1` and `0.2` have no exact binary representation (same reason `1/3` has no exact decimal representation), so each is stored as the closest approximate double, and adding the approximations doesn't land exactly on `0.3`'s own approximation.

Fix: never compare floats for exact equality.

```js
Math.abs((0.1 + 0.2) - 0.3) < Number.EPSILON; // true — tolerance-based comparison
```

For money specifically: don't use floats at all — store cents as integers, or use a decimal library.

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

`structuredClone(obj)` (native, no import needed) handles `Date`, `Map`, `Set`, circular references, and typed arrays correctly — it's the structured clone algorithm browsers already use for `postMessage`. Default to `structuredClone` unless you specifically need JSON's "strip anything non-serializable" behavior (e.g., sanitizing an object before sending it somewhere JSON-only).

```js
const original = { date: new Date(), tags: new Set(['a']) };
structuredClone(original); // Date and Set survive intact
JSON.parse(JSON.stringify(original)); // date -> string, tags -> {}
```

## EventEmitter pattern

The core of Node's `events` module (and conceptually, how React's synthetic event system dispatches) — a plain object holding a map of event name → array of listeners:

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

`emit` is synchronous — listeners run in registration order, on the same call stack as the `emit` call itself, not deferred to a microtask/macrotask.

## Key takeaways

- Float equality must be tolerance-based (`Number.EPSILON`), never `===` — binary floats can't represent most decimal fractions exactly.
- `structuredClone` is the correct default for deep-cloning; `JSON.parse(JSON.stringify())` silently loses functions, `undefined`, `Date` fidelity, `Map`/`Set`, and throws on cycles.
- An EventEmitter is just a `Map`/object of arrays plus `on`/`off`/`emit` — `emit` calls listeners synchronously in registration order.
