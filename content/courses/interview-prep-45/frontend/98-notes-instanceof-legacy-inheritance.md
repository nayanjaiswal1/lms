---
kind: lesson
id_key: interview-prep-45/note-instanceof-legacy-inheritance
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: instanceof Internals & Legacy Prototype Chaining"
position: 98
estimated_minutes: 15
source:
    - interview-prep-notes.md
---
This builds on the prototype-chain lesson (Day 0) — two mechanisms that lesson doesn't cover: how `instanceof` actually resolves, and the manual (pre-`extends`) way of chaining constructors.

## How instanceof actually works

`obj instanceof Fn` walks `obj`'s prototype chain checking whether `Fn.prototype` appears anywhere in it — it does **not** check the constructor name or any tag, only object identity of `Fn.prototype`.

```js
function isInstance(obj, Fn) {
  let proto = Object.getPrototypeOf(obj);
  while (proto !== null) {
    if (proto === Fn.prototype) return true;
    proto = Object.getPrototypeOf(proto);
  }
  return false;
}
```

**Gotcha:** reassigning `Fn.prototype` to a brand-new object *after* instances were already created breaks `instanceof` for those existing instances — they still hold a live link to the *old* prototype object, not the new one.

```js
function Foo() {}
const f = new Foo();

Foo.prototype = {}; // new object, unrelated to what f links to

f instanceof Foo; // false — f.__proto__ still points to the original Foo.prototype
```

## Legacy prototype chaining — before extends existed

`class`/`extends` (Day 0) auto-wires the constructor reference. The manual pattern it replaced does not, and forgetting the fix is the classic whiteboard trap:

```js
function Animal() {}
Animal.prototype.eat = function () { return "eating"; };

function Dog() {}
Dog.prototype = Object.create(Animal.prototype); // link the chain
Dog.prototype.constructor = Dog;                  // MUST fix manually

const d = new Dog();
d.constructor === Dog; // true, only because of the line above
```

Skip that fix and `d.constructor` silently points to `Animal` instead of `Dog` — breaks any code relying on `obj.constructor` for cloning or factory patterns (`new obj.constructor()`).

## Key takeaways

- `instanceof` checks object identity of `Fn.prototype` in the chain — not a name, not a type tag.
- Reassigning `Fn.prototype` after instances exist orphans those instances from `instanceof` checks against the new prototype.
- `Object.create(Parent.prototype)` does not preserve `.constructor` — set it back manually, or use `class extends`, which does this for you.
