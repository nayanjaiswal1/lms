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

## Falsy Values (only 8 — everything else is truthy)

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
"0"          // non-empty string → truthy
"false"      // non-empty string → truthy
[]           // empty array → truthy!
{}           // empty object → truthy!
function(){} // truthy
-1           // any non-zero number
Infinity
" "          // space string → truthy
```

## Interview Gotchas

```js
if ([]) console.log("runs");          // ✅ runs — [] is truthy
if ({}) console.log("runs");          // ✅ runs — {} is truthy
if ([] == false) console.log("runs"); // ✅ runs — [] coerces to "" then 0

Boolean([]);   // true
Boolean({});   // true
Boolean("0");  // true
Boolean(0);    // false
```

## Quick Trick — Double Negation

```js
!!value   // converts value to actual boolean
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

**Key difference:** `||` treats all falsy values as "missing." `??` (nullish coalescing) only treats `null`/`undefined` as missing — so `""` or `0` are considered valid values with `??`.
