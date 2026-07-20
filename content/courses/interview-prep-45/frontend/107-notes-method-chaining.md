---
kind: lesson
id_key: interview-prep-45/note-method-chaining
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: Method Chaining"
position: 107
estimated_minutes: 10
source:
    - interview-prep-notes.md
---

Calling multiple methods on the same object one after another in a single expression — `str.trim().toLowerCase().replace(...)` instead of reassigning a variable at each step.

## How it works

```javascript
// Without chaining
let str = "  Hello World  ";
str = str.trim();
str = str.toLowerCase();
str = str.replace("world", "john");

// With chaining
let result = "  Hello World  ".trim().toLowerCase().replace("world", "john");
```

The mechanism: each method **returns the same object** (or an object of the same interface) instead of `undefined` or void. That return value is exactly what the next `.method()` call in the chain operates on — there's no special language feature involved, just a return-value convention.

## The requirement: `return this`

Chaining only works if every method in the chain explicitly returns the object:

```javascript
class QueryBuilder {
  constructor() { this.parts = []; }

  where(cond)  { this.parts.push(`WHERE ${cond}`); return this; }
  orderBy(col) { this.parts.push(`ORDER BY ${col}`); return this; }
  build()      { return this.parts.join(" "); }
}

new QueryBuilder().where("age > 18").orderBy("name").build();
```

Miss a `return this` on one method and the chain breaks at that point — the next call fails on `undefined`. This is the Builder pattern's core mechanic, and it's exactly how jQuery (`$("#btn").css(...).fadeIn(300).addClass(...)`) and array methods (`.filter().map()`) work.

## Where it shows up

- Arrays: `.filter().map().reduce()` — each returns a new array/value the next method operates on.
- Promises: `.then().then().catch()` — each `.then()` returns a new Promise.
- Fluent builder APIs: query builders, jQuery, test assertion libraries (`expect(x).to.be.a("string")`).

## Key takeaways

- Chaining requires each method to return the object itself (or an equivalent) — it's a convention, not special syntax.
- It removes intermediate variables and reads as a left-to-right pipeline of transformations.
- A missing `return this` (or returning `undefined` instead of the object) is the one bug that silently breaks a chain.
