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

Method chaining means calling multiple methods on the same object one after another in a single expression, as in `str.trim().toLowerCase().replace(...)`, instead of reassigning a variable at each step.

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

The mechanism: each method **returns the same object** (or an object of the same interface) instead of `undefined` or void. That return value is exactly what the next `.method()` call in the chain operates on. There's no special language feature involved, just a return-value convention.

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

Trace the call: `new QueryBuilder()` creates an instance with `parts: []`. `.where("age > 18")` pushes `"WHERE age > 18"` into `parts` and returns `this`, the same instance, so the next call has something to land on. `.orderBy("name")` pushes `"ORDER BY name"` and again returns `this`. `.build()` finally returns `this.parts.join(" ")`, giving `"WHERE age > 18 ORDER BY name"`. Miss a `return this` on any of the middle methods and the chain breaks right there: the next call in the chain tries to call a method on `undefined` and throws.

This is the Builder pattern's core mechanic, and it's exactly how jQuery (`$("#btn").css(...).fadeIn(300).addClass(...)`) and array methods (`.filter().map()`) work.

## Where it shows up

- Arrays: `.filter().map().reduce()`, where each call returns a new array or value for the next method to operate on.
- Promises: `.then().then().catch()`, where each `.then()` returns a new Promise.
- Fluent builder APIs: query builders, jQuery, test assertion libraries such as `expect(x).to.be.a("string")`.

A missing `return this` (or returning `undefined` instead of the object) is the one bug that silently breaks a chain, and it's worth checking first whenever a chained call throws on "cannot read properties of undefined."
