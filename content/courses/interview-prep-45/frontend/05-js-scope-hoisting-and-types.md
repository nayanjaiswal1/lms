---
kind: lesson
id_key: interview-prep-45/fe-js-scope-hoisting-types
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "Variables, Scope, Hoisting, and Truthiness"
position: 5
estimated_minutes: 25
source:
    - interview-prep-notes.md
---
Most React and TypeScript material assumes you already have this settled, and jumps straight past it. It shows up anyway, usually as the very first question in an interview, before the conversation even reaches a framework. Closures, hooks, and async code all quietly depend on the rules in this lesson.

## var, let, const: three different promises

```js
console.log(a); // undefined — the declaration was hoisted, not the assignment
var a = 1;

console.log(b); // ReferenceError: Cannot access 'b' before initialization
let b = 2;
```

`var` is **function-scoped**, not block-scoped. Declare one inside an `if` or a `for` loop and it is visible across the whole enclosing function regardless. It can be redeclared and reassigned freely, and it is hoisted to the top of its scope already set to `undefined`, which is why reading it early gives you `undefined` instead of an error.

`let` is **block-scoped**, visible only inside the nearest `{}`. It cannot be redeclared in the same scope, but can be reassigned. It is hoisted in the sense that the engine knows about it early, but it is not initialized: touching it before its own declaration line throws instead of quietly returning `undefined`.

`const` is block-scoped like `let`, and can be neither redeclared nor reassigned. It has to be given a value at the point of declaration; `const x;` alone is a syntax error. What it locks down is the *binding*, not the value: `const obj = {}` still lets you write `obj.key = 1`, it only forbids `obj = {}` later.

The gap between the top of a `let`/`const` variable's scope and its actual declaration line has a name: the **temporal dead zone**. Touching the variable anywhere in that gap throws a `ReferenceError` instead of handing back a silent `undefined`. That is deliberate: it turns "used the variable before it existed" from a bug that fails somewhere else, mysteriously, into an error at the exact line that caused it.

> **Remember:** `var` hoists to `undefined`, `let`/`const` hoist into a dead zone that throws if you touch them early.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-varletconst-q1", "type": "mcq",
      "prompt": "What happens when you read a `let` variable on a line before its own declaration, inside the same block?",
      "options": [
        {"id":"a","text":"You get undefined, same as var"},
        {"id":"b","text":"A ReferenceError is thrown, because the variable is in the temporal dead zone until its declaration line runs"},
        {"id":"c","text":"You get the value from the nearest outer scope instead"},
        {"id":"d","text":"Nothing happens, the line is silently skipped"}
      ],
      "correct": "b",
      "explanation": "let and const are hoisted in the sense that the engine knows about them, but they aren't initialized until their declaration line runs. Touching them before that throws instead of returning undefined." }
] }
```

## Where the difference actually bites

```js
for (var i = 0; i < 3; i++) {
  setTimeout(() => console.log(i), 0); // 3, 3, 3
}
for (let j = 0; j < 3; j++) {
  setTimeout(() => console.log(j), 0); // 0, 1, 2
}
```

Picture three sticky notes, all pointing at the same drawer. Every callback in the first loop closes over the *same* `i`, because `var` gives the whole loop one shared binding, one drawer. By the time any callback actually runs, the loop has already finished and `i` is `3`, so all three print `3`. The second loop gives every iteration its *own* `j`, its own fresh drawer each time around, so each callback closes over its own copy holding whatever value it saw when it was created. This is the fastest way to demonstrate function scope versus block scope out loud, and it turns out to be the same bug shape as a `useEffect` closure that captures a stale value.

The convention worth defaulting to: `const` unless you specifically need to reassign, `let` when you do, and no `var` in new code at all. `const`'s refusal to rebind means you can trust a variable never points somewhere else later, and block scoping sidesteps the loop-leakage bug above entirely.

> **Remember:** `var` gives a whole loop one shared binding. `let` gives every iteration its own. That's the entire bug, and the entire fix.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-loopclosure-q1", "type": "mcq",
      "prompt": "Why does `for (var i = 0; i < 3; i++) setTimeout(() => console.log(i), 0)` print `3, 3, 3` instead of `0, 1, 2`?",
      "options": [
        {"id":"a","text":"setTimeout always runs after the value 3 is reached, regardless of the loop variable type"},
        {"id":"b","text":"var is function-scoped, so all three callbacks close over the exact same variable, which is 3 by the time any callback runs"},
        {"id":"c","text":"console.log only prints the final value of any variable"},
        {"id":"d","text":"This is a bug in the JavaScript engine"}
      ],
      "correct": "b",
      "explanation": "var creates one shared binding for the whole loop. Every closure captures that same variable, not a snapshot of its value, so by the time the timeouts fire, they all read the loop's final value." }
] }
```

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

Picture two people holding index cards. `b = a` hands the second person a fresh card with the same number written on it; changing one card never touches the other. `obj2 = obj1` instead hands the second person a copy of the *address* of the same house. Walk into that house and repaint a wall, and both people are now looking at the same repainted house. This is the whole reason idiomatic React code writes `setState([...items, x])` instead of `state.items.push(x)`: React and `useState` detect change by comparing references, and mutating in place never produces a new reference for that check to notice.

Briefly, on where these actually live: primitives sit on the **stack**, fixed-size and cleaned up the instant a function returns, cheap precisely because their size is small and fixed. Objects live on the **heap**, sized dynamically and garbage-collected, because they can grow and often need to outlive the single function call that created them. This is an engine detail rather than something the language spec guarantees, but it is the standard mental model interviewers expect when they ask where a value "lives."

`typeof null` famously returns `"object"`, a decades-old bug in the language's original type-tagging scheme that is now permanent for backward compatibility. `null` is still a primitive despite what `typeof` claims; use `value === null` to actually test for it. And `typeof NaN` returns `"number"`, since `NaN` is a special value *of* the Number type, not a type of its own. Testing for it needs `Number.isNaN(x)`, never `x === NaN`, because by spec `NaN` is unequal to itself, so an equality check against it always fails no matter what `x` is.

> **Remember:** a primitive copies its value. An object copies its address. Two variables pointing at the same address see each other's changes.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-primitiveref-q1", "type": "mcq",
      "prompt": "`let obj1 = { count: 5 }; let obj2 = obj1; obj2.count = 10;` What is `obj1.count` now?",
      "options": [
        {"id":"a","text":"5, since obj2 is a separate copy"},
        {"id":"b","text":"10, because obj2 = obj1 copies the reference, not the object, so both variables point at the same object"},
        {"id":"c","text":"undefined"},
        {"id":"d","text":"A TypeError is thrown"}
      ],
      "correct": "b",
      "explanation": "Assigning an object to another variable copies the reference, not the underlying object. Both variables point at the same object in memory, so a mutation through either one is visible through both." }
] }
```

## The eight falsy values, and where truthiness lies to you

```js
false, 0, -0, 0n, "", null, undefined, NaN
```

That is the complete list. Everything else is truthy, including a few values people reliably get wrong:

```js
Boolean([]);   // true — an empty array is still an object
Boolean({});   // true — same reason
Boolean("0");  // true — a non-empty string, regardless of what's inside it
```

`if ([]) console.log("runs")` runs, because `if` only calls `Boolean()` on its condition, and `Boolean()` on any object is always `true`. But `[] == false` is also `true`, and it looks like a contradiction until you notice `==` is not doing the same thing at all. Loose equality coerces both sides to numbers before comparing: `false` becomes `0`, and `[]` first converts to the primitive string `""`, which then converts to the number `0`. The comparison that actually runs is `0 == 0`. The array itself was never "falsy" in that expression; it just coerced down to a value that happened to equal the other side's coerced value. The same coercion machinery explains `[1, 2] + [3, 4]`: `+` on two objects triggers `ToPrimitive`, which for an array means `.toString()`, giving `"1,2"` and `"3,4"`, and from there `+` is plain string concatenation, landing on `"1,23,4"`.

The practical payoff is the `||` versus `??` decision:

```js
function greet(name) {
  name = name || "Guest";  // falls back on ANY falsy value: 0, "", null, undefined
}
function greet(name) {
  name = name ?? "Guest";  // falls back ONLY on null or undefined
}
```

`||` treats every falsy value as "missing," which quietly breaks the moment `0` or `""` is a value you meant to keep. `??` (nullish coalescing) only treats `null`/`undefined` as missing, which is almost always what you actually mean when writing a fallback. This exact gap is what makes `localStorage.getItem(key) || initialValue` wrong the moment a stored value is legitimately `0` or `false`. Reach for `??`, or an explicit `!== null` check, instead.

> **Remember:** `||` gives up on any falsy value. `??` only gives up on `null` or `undefined`. That difference breaks the moment `0` is a real answer.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-truthiness-q1", "type": "mcq",
      "prompt": "A shopping cart quantity field uses `const qty = input || 1;`. What bug does this introduce?",
      "options": [
        {"id":"a","text":"None, this is the correct pattern"},
        {"id":"b","text":"If input is legitimately 0, || treats it as falsy and silently replaces it with 1 instead of keeping the real value"},
        {"id":"c","text":"It throws an error when input is a number"},
        {"id":"d","text":"|| only works with booleans"}
      ],
      "correct": "b",
      "explanation": "|| falls back on every falsy value, including a legitimate 0. ?? only falls back on null/undefined, which is almost always what a default-value check actually means." }
] }
```
