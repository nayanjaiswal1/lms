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

Deep cloning options like `JSON.parse(JSON.stringify(x))` and `structuredClone` copy an entire object graph, including nested objects, and each has gaps in what it can represent. This note covers a different layer: shallow-copy methods, and the one case where Lodash's `cloneDeep` still beats the native `structuredClone`.

## Shallow copy: spread and `Object.assign`

```javascript
const clone1 = { ...original };
const clone2 = Object.assign({}, original);
```

Both copy only the top-level keys. Any nested object or array is still the *same reference* in the clone as in the original, so mutating `clone.nested.x` also mutates `original.nested.x`. `Object.assign` can also merge multiple sources left to right, as in `Object.assign({}, a, b)`, where later sources overwrite earlier keys on conflict. The spread form does the same thing with identical semantics: `{ ...a, ...b }`.

## Where Lodash `cloneDeep` beats `structuredClone`

`structuredClone` correctly clones `Date`, `Map`, `Set`, and circular references, which `JSON.stringify` cannot. But it still has two gaps of its own: it throws on functions, and it loses the prototype chain of class instances, so a cloned class instance comes back as a plain object rather than an instance of that class.

```javascript
import cloneDeep from 'lodash/cloneDeep';
const clone = cloneDeep(original); // preserves class instances and functions; costs a dependency
```

Rule of thumb: default to `structuredClone` for plain data. Reach for `cloneDeep` specifically when the object graph contains functions or class instances that need to survive the clone.

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

Trace it on `{ a: 1, b: { c: 2 } }`: the outer call sees an object, so it maps over its entries. For `a`, `deepClone(1)` hits the base case and returns `1` unchanged. For `b`, `deepClone({ c: 2 })` recurses, hits the object branch again, and returns a brand-new object `{ c: 2 }` built from freshly cloned entries, not the original reference. `Object.fromEntries` reassembles both results into a new top-level object, so every level of nesting gets its own new object or array instead of a shared reference.

This function handles plain objects and arrays only. It has no special handling for `Date`, `Map`, `Set`, or circular references, which is exactly why `structuredClone` exists as a native primitive instead of everyone hand-rolling this.
