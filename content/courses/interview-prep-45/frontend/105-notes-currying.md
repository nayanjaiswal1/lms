---
kind: lesson
id_key: interview-prep-45/note-currying
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: Currying"
position: 105
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

The JS glossary (`90-notes-js-react-interview-prep.md`) defines currying in one line — "a function that takes arguments one at a time, returning a new function each time until all are supplied." This note is the code behind that definition: why it's useful, not just what it is.

## The core idea

Instead of calling `f(a, b, c)`, currying lets you call `f(a)(b)(c)` — each call takes one argument and returns a new function waiting for the next one.

```javascript
// Normal
function add(a, b) { return a + b; }
add(2, 3); // 5

// Curried
const add = a => b => a + b;
add(2)(3); // 5
```

## Why it's useful

**Partial application** — bake in the first argument(s) to create a specialized function:

```javascript
const add = a => b => a + b;
const add10 = add(10);
add10(5);  // 15
add10(20); // 30
```

**Composable pipelines** — small curried functions chain cleanly through `.map`/`reduce`/a `pipe` helper:

```javascript
const multiply = a => b => a * b;
const double = multiply(2);
[1, 2, 3].map(double); // [2, 4, 6]

const pipe = (...fns) => x => fns.reduce((v, f) => f(v), x);
const process = pipe(add(1), multiply(2), add(10));
process(5); // ((5+1)*2)+10 = 22
```

## A generic curry helper

Real code rarely hand-writes the nested-arrow form for every function — a `curry` helper auto-curries based on the function's declared arity (`fn.length`):

```javascript
function curry(fn) {
  return function curried(...args) {
    if (args.length >= fn.length) return fn(...args);
    return (...more) => curried(...args, ...more);
  };
}

const add3 = curry((a, b, c) => a + b + c);
add3(1)(2)(3);  // 6
add3(1, 2)(3);  // 6
add3(1, 2, 3);  // 6
```

This is what libraries like Lodash's `_.curry(fn)` do under the hood.

## Across languages

| Language | Style |
|---|---|
| Haskell | All functions curried by default |
| Python | `functools.partial` or manual nested lambdas — not automatic like JS/Haskell |
| Scala / F# | Built-in via `=>` chaining |
| JavaScript | Manual (nested arrows) or via a library (`_.curry`) |

## Key takeaways

- Currying transforms `f(a, b, c)` into `f(a)(b)(c)` — one argument per call, returning a new function until all arguments are supplied.
- Its practical value is partial application (pre-filling arguments to specialize a function) and composability (small single-purpose functions chained through `pipe`/`.map`).
- A generic `curry(fn)` helper auto-curries based on `fn.length`, and accepts arguments one at a time or in groups.
- JS/Haskell/Scala support it naturally via closures or built-in currying; Python needs `functools.partial` since functions aren't curried by default.
