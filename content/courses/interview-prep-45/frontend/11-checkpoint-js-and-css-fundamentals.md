---
kind: lesson
id_key: interview-prep-45/fe-checkpoint-js-fundamentals
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Checkpoint: HTML, CSS, and JavaScript Fundamentals"
position: 11
estimated_minutes: 18
source:
    - 45-day-interview-roadmap.md
---
No new material today. This is a consolidation pass over everything from HTML and CSS through JavaScript's core mechanics, scope, prototypes, promises, and the event loop. Interviewers rarely test one of these in isolation; they chain them ("your list re-renders on every keystroke, walk me through why, starting from the DOM up"). Use this review to move between topics without losing the thread, before React enters the picture next.

## HTML and CSS: the one-paragraph version

Reach for the semantic element first: `<button>` over `<div onClick>`, `<nav>`/`<main>`/`<article>` over `<div className="...">`. Native elements give you keyboard operability, screen-reader announcement, and correct accessibility-tree role and name for free; a `<div>` gets none of it until you rebuild it by hand. `box-sizing: border-box` makes a declared width the actual rendered width; without it, padding and border add on top of what you asked for. Flexbox is one axis, Grid is two; if you're fighting `flex-wrap` and fixed widths to fake rows and columns, that's the sign you wanted Grid. `transform` and `opacity` are the only two properties that can skip layout and paint entirely and go straight to the GPU compositor, which is why they're the default choice for anything animated.

**Say this out loud, unprompted, if asked to review a component for accessibility:** check for a native element first, then a label/name for every interactive control, then whether the whole thing is operable with just a keyboard.

## Scope, hoisting, and types: the one-paragraph version

`var` is function-scoped and hoisted to `undefined`; `let`/`const` are block-scoped and sit in the temporal dead zone until their declaration line, so touching them early throws instead of silently returning `undefined`. Primitives copy by value; objects and arrays copy by reference, which is the entire reason React and Redux detect change with reference equality rather than deep comparison, mutating in place never produces a new reference. Only eight values are falsy; everything else, including `[]` and `{}`, is truthy. `??` falls back only on `null`/`undefined`; `||` falls back on any falsy value, which silently breaks the moment `0` or `""` is a value you meant to keep.

**Say this out loud, unprompted, if asked why a loop of `setTimeout` callbacks all log the same final value:** `var` gives the whole loop one shared binding, so every closure captures the same variable; `let` gives each iteration its own binding instead.

## Functions, prototypes, and this: the one-paragraph version

`call`/`apply` invoke a function immediately with a chosen `this`; `bind` returns a new function with `this` locked in, to be called later, and none of the three can override an arrow function's `this`, since arrow functions close over `this` lexically at definition time. Every object links to a parent via `[[Prototype]]`, and property lookup walks that chain until it finds a match or hits `null`; `class`/`extends` is sugar over exactly that same link, not a separate inheritance model. `instanceof` checks whether a constructor's `.prototype` appears anywhere in that chain, by object identity, which is why reassigning `.prototype` after instances already exist breaks `instanceof` for those existing instances.

**Say this out loud, unprompted, if asked to build bind from scratch:** it doesn't call the function immediately, it captures it in a closure and returns a new function that applies the original with the bound `this` and merged arguments whenever it's eventually invoked.

## Promises and the event loop: the one-paragraph version

The executor passed to `new Promise(...)` runs synchronously, the instant the constructor is called. Once settled, a promise stays settled forever; a second `resolve`/`reject` call is a silent no-op, which is exactly what makes `Promise.any`'s implementation safe. `all` rejects on the first rejection but keeps running the rest; `allSettled` always waits for everyone regardless of outcome; `race` settles on whoever finishes first, win or lose; `any` settles on the first success and only gives up once everyone has failed. After the call stack empties, the *entire* microtask queue drains, including microtasks queued by other microtasks during that drain, before the next macrotask runs, which is why `Promise.resolve().then()` always fires before `setTimeout(fn, 0)` no matter what delay you give the timeout.

**Say this out loud, unprompted, if asked to predict a console.log order involving both:** identify synchronous code first, then every microtask in queue order, then macrotasks last, and never let a `setTimeout` delay value change that ordering.

## Self-test — answer without looking back

1. Why does `[] == false` evaluate to `true` even though `if ([])` is truthy?
2. A loop mutates `Person.prototype.greet` after several `Person` instances already exist. Do those instances see the new method? Why?
3. Write the console.log output order for: a sync log, then `setTimeout(fn, 0)`, then `Promise.resolve().then(fn)`, then another sync log.
4. Why does animating `top`/`left` cost more than animating `transform`, in terms of the render pipeline?
5. A cache lookup uses `if (cache[key])` instead of `key in cache`. What specific input breaks it, and why?
6. You need one thing to happen the instant the *first* of several promises succeeds, and to only give up if every one of them fails. Which combinator, and why not `Promise.race`?
