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
This assumes you already know the basics of the prototype chain: every object has an internal link to another object it delegates property lookups to, and that chain of links is how `obj.someMethod()` can find a method defined on a shared prototype instead of on `obj` itself. This note covers two things that basic picture doesn't: how `instanceof` actually resolves, and the manual, pre-`extends` way of chaining constructors together.

## How instanceof actually works

`obj instanceof Fn` walks `obj`'s prototype chain checking whether `Fn.prototype` appears anywhere in it. It does **not** check the constructor's name or any type tag, only the object identity of `Fn.prototype`.

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

**Gotcha:** reassigning `Fn.prototype` to a brand-new object *after* instances were already created breaks `instanceof` for those existing instances. They still hold a live link to the *old* prototype object, not the new one.

```js
function Foo() {}
const f = new Foo();

Foo.prototype = {}; // new object, unrelated to what f links to

f instanceof Foo; // false: f.__proto__ still points to the original Foo.prototype
```
Walking through `isInstance(f, Foo)` after that reassignment: `proto` starts as `f`'s original prototype object, the one `Foo.prototype` used to point to. The loop compares it against `Foo.prototype`, but that now refers to the new `{}` object instead, so the check fails. `proto` moves up to `Object.prototype`, fails again, then hits `null` and the loop returns `false`. Nothing about `f` changed; only what `Foo.prototype` points to did.

## Legacy prototype chaining: before extends existed

Modern `class`/`extends` syntax auto-wires the constructor reference for you. The manual pattern it replaced does not, and forgetting to fix it by hand is a classic whiteboard trap:

```js
function Animal() {}
Animal.prototype.eat = function () { return "eating"; };

function Dog() {}
Dog.prototype = Object.create(Animal.prototype); // link the chain
Dog.prototype.constructor = Dog;                  // MUST fix manually

const d = new Dog();
d.constructor === Dog; // true, only because of the line above
```

Skip that fix and `d.constructor` silently points to `Animal` instead of `Dog`, which breaks any code relying on `obj.constructor` for cloning or factory patterns like `new obj.constructor()`. `class extends` sidesteps this whole problem by setting up the constructor link correctly on its own.
