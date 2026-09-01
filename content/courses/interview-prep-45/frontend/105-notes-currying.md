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

Currying is a function that takes arguments one at a time, returning a new function each time until all are supplied. This note walks through why that's useful, not just what it is.

## The core idea

Instead of calling `f(a, b, c)`, currying lets you call `f(a)(b)(c)`. Each call takes one argument and returns a new function waiting for the next one.

```javascript
// Normal
function add(a, b) { return a + b; }
add(2, 3); // 5

// Curried
const add = a => b => a + b;
add(2)(3); // 5
```

## Why it's useful

**Partial application.** Bake in the first argument(s) to create a specialized function:

```javascript
const add = a => b => a + b;
const add10 = add(10);
add10(5);  // 15
add10(20); // 30
```

**Composable pipelines.** Small curried functions chain cleanly through `.map`, `reduce`, or a `pipe` helper:

```javascript
const multiply = a => b => a * b;
const double = multiply(2);
[1, 2, 3].map(double); // [2, 4, 6]

const pipe = (...fns) => x => fns.reduce((v, f) => f(v), x);
const process = pipe(add(1), multiply(2), add(10));
process(5); // ((5+1)*2)+10 = 22
```

## A generic curry helper

Real code rarely hand-writes the nested-arrow form for every function. A `curry` helper auto-curries based on the function's declared arity (`fn.length`):

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

Trace `add3(1)(2)(3)`: the first call runs `curried(1)`. Since `fn.length` is 3 and `args.length` is 1, it returns a new function waiting for more arguments instead of calling `fn`. Calling that with `(2)` runs `curried(1, 2)`, still short of 3, so it returns another waiting function. Calling that with `(3)` runs `curried(1, 2, 3)`, which now meets `fn.length`, so it finally calls `fn(1, 2, 3)` and returns `6`. `add3(1, 2)(3)` and `add3(1, 2, 3)` reach the same final call, just by supplying arguments in different-sized groups. This is what libraries like Lodash's `_.curry(fn)` do under the hood.

## Across languages

| Language | Style |
|---|---|
| Haskell | All functions curried by default. |
| Python | Not curried automatically. Use `functools.partial` to pre-fill arguments, or write nested lambdas by hand. |
| Scala / F# | Curried natively via `=>` chaining. |
| JavaScript | Manual (nested arrows), or via a library like `_.curry`. |
