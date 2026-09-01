---
kind: lesson
id_key: interview-prep-45/note-scoping-hoisting-primitive-types
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: var/let/const Scoping & Hoisting, Primitive vs Reference Types"
position: 108
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

`var`/`let`/`const` scoping and hoisting, and primitive vs non-primitive types, are foundational background that most React and TypeScript material assumes you already know rather than teaching directly. This note fills that gap, since it's exactly the kind of question that opens a frontend interview before the conversation moves to React specifics.

## var vs let vs const: scope, hoisting, and the temporal dead zone

```js
console.log(a); // undefined — declaration hoisted, not the assignment
var a = 1;

console.log(b); // ReferenceError: Cannot access 'b' before initialization
let b = 2;
```

**`var` is function-scoped, not block-scoped.** A `var` declared inside an `if` or `for` block is visible throughout the entire enclosing function. It can be redeclared and reassigned freely, and it's hoisted to the top of its scope with the value `undefined`, so reading it before the declaration line gives `undefined` rather than an error.

**`let` is block-scoped**, visible only within the nearest enclosing `{}`. It cannot be redeclared in the same scope, but it can be reassigned. It's hoisted the same way `var` is, but it isn't initialized to `undefined`: accessing it before its declaration line throws a `ReferenceError`.

**`const` is block-scoped like `let`**, and it cannot be redeclared or reassigned. It must be initialized at declaration; `const x;` alone is a syntax error. This restriction only prevents rebinding the variable, not mutating what it points to: `const obj = {}` still allows `obj.key = 1`, but forbids `obj = {}`.

**The Temporal Dead Zone (TDZ)** is the gap between the top of the scope, where `let`/`const` are hoisted to just like `var`, and the actual declaration line. Accessing the variable anywhere in that gap throws instead of silently returning `undefined`. This is a deliberate design choice: it turns a whole class of "used before declared" bugs into an immediate, loud error instead of a silent `undefined` that fails mysteriously somewhere else.

### Why this matters practically

Block scope prevents loop-variable leakage, the classic interview gotcha:

```js
for (var i = 0; i < 3; i++) {
  setTimeout(() => console.log(i), 0); // 3, 3, 3 — one shared `i`, all closures see its final value
}
for (let j = 0; j < 3; j++) {
  setTimeout(() => console.log(j), 0); // 0, 1, 2 — each iteration gets its own `j` binding
}
```

In the first loop, all three `setTimeout` callbacks close over the *same* `i`. By the time any of them runs, the loop has already finished and `i` is `3`, so all three print `3`. In the second loop, `let` creates a fresh binding of `j` for each iteration, so each callback closes over its own copy holding `0`, `1`, or `2` respectively. That's the fastest way to demonstrate the practical difference between function scope and block scope.

The accepted modern convention is to prefer `const` by default, use `let` only when reassignment is actually needed, and avoid `var` in new code entirely. `const`'s inability to rebind makes code easier to reason about, since you know the variable never points somewhere else later, and block scoping avoids the loop-leakage bug above.

## Primitive vs non-primitive (reference) types

JavaScript has exactly 7 primitive types: `string`, `number`, `boolean`, `null`, `undefined`, `BigInt`, and `Symbol`. Everything else, including `Object`, `Array`, and `Function`, is a non-primitive (reference) type.

| | Primitives | Non-primitives |
|---|---|---|
| Storage | Stored directly, typically on the stack. | The variable holds a *reference* (pointer) to data on the heap. |
| Mutability | Immutable. You can't change a string in place, only create a new one. | Mutable. Array and object contents can change in place. |
| Copy behavior | Assigning copies the **value**, giving two independent copies. | Assigning copies the **reference**, so both variables point at the same object. |
| Equality (`===`) | Compares value. | Compares reference identity, not contents. |

```js
let a = 5;
let b = a;   // b gets a COPY of the value 5
b = 10;
console.log(a); // 5 — a is untouched

let obj1 = { count: 5 };
let obj2 = obj1;   // obj2 gets a COPY of the REFERENCE, not a new object
obj2.count = 10;
console.log(obj1.count); // 10 — same underlying object, both variables point at it

console.log({ x: 1 } === { x: 1 }); // false — different objects, same shape
console.log(obj1 === obj2);          // true — same reference
```

In the first block, `b = a` copies the value `5`, so reassigning `b` to `10` has no effect on `a`. In the second block, `obj2 = obj1` copies the reference, not the object, so `obj1` and `obj2` point at the exact same object in memory; mutating `count` through `obj2` is visible through `obj1` too, because there's only one object to begin with.

**Stack vs heap, briefly.** Primitives live on the stack, which is fixed-size, LIFO, and automatically cleaned up when a function returns, because their fixed, small size makes that cheap. Objects live on the heap, which is dynamically sized and garbage-collected, because their size can grow and they need to outlive a single function call if referenced elsewhere. This is an engine-implementation detail rather than a language guarantee, but it's the standard mental model interviewers expect.

**Why this matters for React specifically.** React's `useState`/`useEffect` dependency comparisons use `Object.is` (reference equality) under the hood. Mutating an object or array in place, such as `state.items.push(x)`, doesn't change its reference, so React won't detect the change and won't re-render. This is exactly why idiomatic React code spreads or reconstructs state (`setState([...items, x])`) instead of mutating it: a new reference is required to signal "this changed."

One classic gotcha worth knowing: `typeof null === "object"`. This is a long-standing bug in the language, where `null` was originally represented with a type tag that collided with objects, and it's now permanent for backwards compatibility. `null` is still a primitive despite `typeof` reporting otherwise; use `value === null` to actually check for it.
