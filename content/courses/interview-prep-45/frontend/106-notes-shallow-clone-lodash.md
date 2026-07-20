---
kind: lesson
id_key: interview-prep-45/note-shallow-clone-lodash
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: Shallow Cloning and Lodash cloneDeep"
position: 106
estimated_minutes: 10
source:
    - interview-prep-notes.md
---

`100-notes-float-precision-clone-eventemitter.md` already covers deep cloning — `JSON.parse(JSON.stringify(x))` vs `structuredClone`, and exactly what each one silently drops. This note covers the two pieces that one doesn't: shallow-copy methods, and where Lodash's `cloneDeep` still beats `structuredClone`.

## Shallow copy: spread and `Object.assign`

```javascript
const clone1 = { ...original };
const clone2 = Object.assign({}, original);
```

Both copy only the top-level keys — any nested object or array is still the *same reference* in the clone as in the original, so mutating `clone.nested.x` also mutates `original.nested.x`. `Object.assign` additionally merges multiple sources left-to-right: `Object.assign({}, a, b)` — later sources overwrite earlier keys on conflict, which the spread form can also do (`{ ...a, ...b }`) with identical semantics.

## Where Lodash `cloneDeep` beats `structuredClone`

`100-notes...md` already covers what `structuredClone` handles correctly (`Date`, `Map`, `Set`, circular refs) that `JSON.stringify` doesn't. The gap `structuredClone` itself still has: it throws on functions and loses the prototype chain of class instances (a cloned class instance comes back as a plain object, not an instance of that class).

```javascript
import cloneDeep from 'lodash/cloneDeep';
const clone = cloneDeep(original); // preserves class instances and functions; costs a dependency
```

Rule of thumb: default to `structuredClone` for plain data; reach for `cloneDeep` specifically when the object graph contains functions or class instances you need to survive the clone.

## Manual recursive clone

Worth knowing as the "explain what's happening under the hood" answer, not as something to actually ship over `structuredClone`:

```javascript
function deepClone(obj) {
  if (obj === null || typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) return obj.map(deepClone);
  return Object.fromEntries(
    Object.entries(obj).map(([k, v]) => [k, deepClone(v)])
  );
}
```

Handles plain objects/arrays only — no `Date`/`Map`/`Set`/circular-reference handling, which is exactly why `structuredClone` exists as a native primitive instead of everyone hand-rolling this.

## Key takeaways

- Spread and `Object.assign` are shallow — nested objects/arrays remain shared references between original and clone.
- `structuredClone` doesn't clone functions and drops the prototype of class instances (comes back as a plain object); `Lodash cloneDeep` handles both, at the cost of a dependency.
- A hand-written recursive `deepClone` only covers plain objects/arrays — no `Date`/`Map`/`Set`/circular-ref support, which is what native `structuredClone` gives you for free.
