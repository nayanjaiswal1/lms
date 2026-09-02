---
kind: lesson
id_key: interview-prep-45/fe-js-scope-hoisting-types
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Variables, Scope, Hoisting, and Truthiness"
position: 5
estimated_minutes: 25
source:
    - interview-prep-notes.md
---
Most React and TypeScript material assumes you already have this settled and jumps straight past it. It shows up anyway, usually as the very first question in an interview, before the conversation ever gets to a framework. This lesson is the foundation everything after it, closures, hooks, async code, quietly depends on.

## var, let, const: three different promises

```js
console.log(a); // undefined — the declaration was hoisted, not the assignment
var a = 1;

console.log(b); // ReferenceError: Cannot access 'b' before initialization
let b = 2;
```

`var` is **function-scoped**, not block-scoped. Declare one inside an `if` or a `for` loop and it's visible across the whole enclosing function regardless. It can be redeclared and reassigned freely, and it's hoisted to the top of its scope already initialized to `undefined`, which is why reading it early gives you `undefined` instead of an error.

`let` is **block-scoped**, visible only inside the nearest `{}`. It can't be redeclared in the same scope but can be reassigned. It's hoisted the same way `var` is, in the sense that the engine knows about it early, but it isn't initialized: touching it before its own declaration line throws instead of quietly returning `undefined`.

`const` is block-scoped like `let`, and can be neither redeclared nor reassigned. It has to be initialized at the point of declaration; `const x;` alone is a syntax error. What it actually locks down is the *binding*, not the value: `const obj = {}` still lets you write `obj.key = 1`, it only forbids `obj = {}` later.

The gap between the top of a `let`/`const` variable's scope and its actual declaration line is called the **temporal dead zone**. Touching the variable anywhere in that gap throws a `ReferenceError` rather than handing back a silent `undefined`. That's deliberate: it turns "used the variable before it existed" from a bug that fails somewhere else, mysteriously, into an error at the exact line that caused it.

## Where the difference actually bites

```js
for (var i = 0; i < 3; i++) {
  setTimeout(() => console.log(i), 0); // 3, 3, 3
}
for (let j = 0; j < 3; j++) {
  setTimeout(() => console.log(j), 0); // 0, 1, 2
}
```

Every callback in the first loop closes over the *same* `i`, because `var` gives the whole loop one shared binding. By the time any callback actually runs, the loop already finished and `i` is `3`, so all three print `3`. The second loop gives every iteration its *own* `j`, a fresh binding each time around, so each callback closes over its own copy holding whatever value it saw. This is the fastest way to demonstrate function scope versus block scope out loud, and it's exactly the kind of thing a `useEffect` closure bug (covered later in this course) turns out to be a variant of.

The convention worth defaulting to: `const` unless you specifically need to reassign, `let` when you do, and no `var` in new code at all. `const`'s refusal to rebind means you can trust a variable never points somewhere else later, and block scoping sidesteps the loop-leakage bug above entirely.

## Primitive versus reference: what a variable actually holds

JavaScript has exactly seven primitive types: `string`, `number`, `boolean`, `null`, `undefined`, `BigInt`, `Symbol`. Everything else, objects, arrays, functions, is a reference type.

```js
let a = 5;
let b = a;   // b gets a COPY of the value
b = 10;
console.log(a); // 5 — untouched

let obj1 = { count: 5 };
let obj2 = obj1;   // obj2 gets a COPY of the REFERENCE, not a new object
obj2.count = 10;
console.log(obj1.count); // 10 — same object, both variables point at it

console.log({ x: 1 } === { x: 1 }); // false — different objects, same shape
console.log(obj1 === obj2);          // true — same reference
```

`b = a` copies a value, so reassigning `b` never touches `a`. `obj2 = obj1` copies a reference, not an object, so both variables point at the exact same thing in memory, and a mutation through either one is visible through both. This is the whole reason idiomatic React code writes `setState([...items, x])` instead of `state.items.push(x)`: React and useState detect change with reference equality, and mutating in place never produces a new reference for that check to notice.

Briefly, on where these actually live: primitives sit on the **stack**, fixed-size, last-in-first-out, and automatically cleaned up the instant a function returns, which is cheap precisely because their size is small and fixed. Objects live on the **heap**, dynamically sized and garbage-collected, because their size can grow and they often need to outlive the single function call that created them, referenced elsewhere after that call is long gone. This is an engine-implementation detail rather than something the language spec guarantees, but it's the standard mental model interviewers expect when they ask where a value "lives."

`typeof null` famously returns `"object"`, a decades-old bug in the language's original type-tagging scheme that's now permanent for backwards compatibility. `null` is still a primitive despite what `typeof` claims; use `value === null` to actually test for it, and remember that `typeof NaN` returns `"number"`, since `NaN` is a special value *of* the Number type, not a type of its own. Testing for it needs `Number.isNaN(x)`, never `x === NaN`, because by spec `NaN` is unequal to itself, so an equality check against it always fails no matter what `x` is.

## The eight falsy values, and where truthiness lies to you

```js
false, 0, -0, 0n, "", null, undefined, NaN
```

That's the complete list. Everything else is truthy, including a few values people reliably get wrong:

```js
Boolean([]);   // true — an empty array is still an object
Boolean({});   // true — same reason
Boolean("0");  // true — a non-empty string, regardless of what's inside it
```

`if ([]) console.log("runs")` runs, because `if` only calls `Boolean()` on its condition, and `Boolean()` on any object is always `true`. But `[] == false` is also `true`, and it looks like a contradiction until you notice `==` isn't doing the same thing at all. Loose equality coerces both sides to numbers before comparing: `false` becomes `0`, and `[]` first converts to the primitive string `""`, which then converts to the number `0`. The comparison that actually runs is `0 == 0`. The array itself was never "falsy" in that expression; it just coerced down to a value that happened to equal the other side's coerced value. The same coercion machinery explains `[1, 2] + [3, 4]`: `+` on two objects triggers `ToPrimitive`, which for an array means `.toString()`, giving `"1,2"` and `"3,4"`, and from there `+` is plain string concatenation, landing on `"1,23,4"`.

The practical payoff is the `||` versus `??` decision:

```js
function greet(name) {
  name = name || "Guest";  // falls back on ANY falsy value: 0, "", null, undefined
}
function greet(name) {
  name = name ?? "Guest";  // falls back ONLY on null or undefined
}
```

`||` treats every falsy value as "missing," which quietly breaks the moment `0` or `""` is a legitimate value you meant to keep. `??` (nullish coalescing) only treats `null`/`undefined` as missing, which is almost always what you actually mean when you write a fallback. This exact gap is what makes a naive `localStorage.getItem(key) || initialValue` pattern wrong the moment a stored value is legitimately `0` or `false`; reach for `??`, or an explicit `!== null` check, instead.
