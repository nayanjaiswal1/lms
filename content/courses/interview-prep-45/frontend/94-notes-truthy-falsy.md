---
kind: lesson
id_key: interview-prep-45/note-js-truthy-falsy
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: JavaScript Truthy & Falsy Values"
position: 94
estimated_minutes: 10
source:
    - interview-prep-notes.md
---

## Falsy Values (only 8, everything else is truthy)

```js
false
0
-0
0n          // BigInt zero
""          // empty string
null
undefined
NaN
```

## Truthy Values (some common gotchas)

```js
"0"          // non-empty string, truthy
"false"      // non-empty string, truthy
[]           // empty array, truthy!
{}           // empty object, truthy!
function(){} // truthy
-1           // any non-zero number
Infinity
" "          // space string, truthy
```

## Interview Gotchas

```js
if ([]) console.log("runs");          // runs, [] is truthy
if ({}) console.log("runs");          // runs, {} is truthy
if ([] == false) console.log("runs"); // runs, see below

Boolean([]);   // true
Boolean({});   // true
Boolean("0");  // true
Boolean(0);    // false
```

The `[] == false` case trips people up because it looks like it contradicts `if ([])` being truthy. It doesn't: `if ([])` never converts the array via `==`, it just calls `Boolean([])`, which is `true` for any object. But `[] == false` uses the loose equality algorithm, which coerces both sides to numbers before comparing. `false` becomes `0`. `[]` first converts to a primitive string, `""`, then that string converts to a number, `0`. So the comparison actually being run is `0 == 0`, which is true. The array itself was never "falsy" here, it just coerced down to a value that happened to equal `false`'s coerced value.

## Quick Trick: Double Negation

```js
!!value   // converts value to an actual boolean
!![]      // true
!!""      // false
```

## Real-World Pattern: `||` vs `??`

```js
function greet(name) {
  name = name || "Guest";  // falls back on ANY falsy value (0, "", null, undefined)
}

function greet(name) {
  name = name ?? "Guest";  // falls back ONLY on null/undefined
}
```

**Key difference:** `||` treats every falsy value as "missing." `??` (nullish coalescing) only treats `null`/`undefined` as missing, so with `??`, `""` or `0` are kept as valid values instead of being replaced.
