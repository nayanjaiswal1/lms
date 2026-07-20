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

Frontend/90's theory reference reduces `var`/`let`/`const` and hoisting to a single summary line, and primitive vs non-primitive types don't appear anywhere in the course — both are assumed background for the React/hooks/TypeScript lessons but never taught directly. This note fills that in, since it's exactly the kind of foundational question that opens a frontend round before the conversation moves to React specifics.

## var vs let vs const: scope, hoisting, and the temporal dead zone

```js
console.log(a); // undefined — declaration hoisted, not the assignment
var a = 1;

console.log(b); // ReferenceError: Cannot access 'b' before initialization
let b = 2;
```

- **`var`** — function-scoped (not block-scoped): a `var` declared inside an `if` or `for` block is visible throughout the entire enclosing function. Can be redeclared and reassigned freely. Hoisted to the top of its scope with the value `undefined` — so reading it before the declaration line gives `undefined`, not an error.
- **`let`** — block-scoped: only visible within the nearest enclosing `{}`. Cannot be redeclared in the same scope; can be reassigned. Hoisted like `var`, but *not* initialized to `undefined` — accessing it before its declaration line throws a `ReferenceError`.
- **`const`** — block-scoped like `let`, cannot be redeclared *or* reassigned. Must be initialized at declaration (`const x;` alone is a syntax error). Note this only prevents *rebinding the variable* — `const obj = {}` still allows `obj.key = 1` (mutating the object's contents), it just forbids `obj = {}` (pointing the variable at a different object).

**The Temporal Dead Zone (TDZ)** is the gap between the top of the scope (where `let`/`const` are hoisted to, same as `var`) and the actual declaration line. Accessing the variable anywhere in that gap throws, rather than silently returning `undefined` — this is a deliberate design choice that turns a whole class of "used before declared" bugs into an immediate, loud error instead of a silent `undefined` that fails mysteriously somewhere else.

**Why this matters practically:**
- **Block scope prevents loop-variable leakage** — the classic interview gotcha:
```js
for (var i = 0; i < 3; i++) {
  setTimeout(() => console.log(i), 0); // 3, 3, 3 — one shared `i`, all closures see its final value
}
for (let j = 0; j < 3; j++) {
  setTimeout(() => console.log(j), 0); // 0, 1, 2 — each iteration gets its own `j` binding
}
```
`let` in a `for` loop creates a *new binding per iteration*, which is exactly why the second loop's closures each capture a different value — this single example is the fastest way to demonstrate the practical difference between function scope and block scope.
- **Prefer `const` by default, `let` when reassignment is actually needed, and avoid `var` in new code entirely** — this is the accepted modern convention specifically because `const`'s inability to rebind makes code easier to reason about (you know the variable never points somewhere else later), and block scoping avoids the loop-leakage class of bugs above.

## Primitive vs non-primitive (reference) types

JavaScript has exactly **7 primitive types**: `string`, `number`, `boolean`, `null`, `undefined`, `BigInt`, and `Symbol`. Everything else — `Object`, `Array`, `Function` — is a **non-primitive (reference) type**.

| | Primitives | Non-primitives |
|---|---|---|
| Storage | Stored directly, typically on the stack | Variable holds a *reference* (pointer) to data on the heap |
| Mutability | Immutable — you can't change a string in place, only create a new one | Mutable — array/object contents can change in place |
| Copy behavior | Assigning copies the **value** — two independent copies | Assigning copies the **reference** — both variables point at the same object |
| Equality (`===`) | Compares value | Compares reference identity, not contents |

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

**Stack vs heap, briefly:** primitives live on the stack (fixed-size, LIFO, automatic cleanup when a function returns) because their fixed, small size makes that cheap; objects live on the heap (dynamically sized, garbage-collected) because their size can grow and they need to outlive a single function call if referenced elsewhere. This is engine-implementation detail rather than a language guarantee, but it's the standard mental model interviewers expect.

**Why this matters for React specifically** (connecting back to frontend/02's `useState` lesson): React's `useState`/`useEffect` dependency comparisons use `Object.is` (reference equality) under the hood. Mutating an object or array in place (`state.items.push(x)`) doesn't change its reference, so React won't detect the change and won't re-render — this is exactly why the course's hook examples always spread/reconstruct (`setState([...items, x])`) instead of mutating: a new reference is required to signal "this changed."

One classic gotcha worth knowing: `typeof null === "object"` — a long-standing bug in the language (null was originally represented with a type tag that collided with objects) that's now permanent for backwards compatibility. `null` is still a primitive despite `typeof` reporting otherwise; use `value === null` to actually check for it.

## Key takeaways

- `var` is function-scoped and hoisted to `undefined`; `let`/`const` are block-scoped and hoisted into a Temporal Dead Zone that throws if accessed before declaration — prefer `const`, then `let`, avoid `var`.
- `let` in a `for` loop creates a fresh binding per iteration (fixing the classic `setTimeout` closure bug); `var` shares one binding across the whole loop.
- 7 primitives (`string`, `number`, `boolean`, `null`, `undefined`, `BigInt`, `Symbol`) are copied by value and immutable; objects/arrays/functions are copied by reference and mutable.
- React's change detection relies on reference equality — mutating state in place doesn't produce a new reference, so the component won't re-render; always create a new object/array to trigger updates.
- `typeof null === "object"` is a known language bug, not a reflection of `null`'s actual (primitive) type.
