---
kind: lesson
id_key: interview-prep-45/day-00-frontend-prototype-chain
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "JavaScript Prototype Chain and Inheritance"
position: 1
estimated_minutes: 25
source:
    - 45-day-interview-roadmap.md
---
Before touching React internals, you need the JS mechanism React itself is built on. Class components, `this` binding, and even how `class`/`extends` behave under the hood all rest on prototypal inheritance — not classical, class-based inheritance like Java or C#. "Explain the prototype chain" and "what does `new` actually do" are two of the most common frontend-fundamentals questions, and they're really testing whether you understand how JavaScript looks up properties, not whether you've memorized syntax.

## Property lookup and the prototype chain

Every JavaScript object has an internal link — `[[Prototype]]` — to another object (or to `null`). When you access a property, the engine doesn't just check the object itself: if the property isn't found there, it walks up the `[[Prototype]]` link and checks that object, then its `[[Prototype]]`, and so on, until it finds the property or hits `null`.

This walk is the **prototype chain**, and the mechanism is called **delegation**: an object doesn't copy its parent's properties, it delegates the lookup upward when it doesn't have something itself.

```tsx
const grandparent = { surname: 'Sharma' };
const parent = Object.create(grandparent);
parent.car = 'Swift';

const child = Object.create(parent);
child.name = 'Nayan';

console.log(child.name);     // "Nayan" — found on child itself
console.log(child.car);      // "Swift" — not on child, found one link up
console.log(child.surname);  // "Sharma" — not on child or parent, found two links up
console.log(child.toString); // function — found at the top of the chain, Object.prototype
```

`child` doesn't own `car` or `surname` — the engine finds them by walking `[[Prototype]]` links each time you ask. Every object's chain eventually reaches `Object.prototype` (the source of `.toString()`, `.hasOwnProperty()`, etc.), whose own `[[Prototype]]` is `null` — the end of every chain.

**Interview question: "Is JavaScript inheritance class-based like Java?"**
No — it's prototypal. Objects link to and delegate to other objects directly. `class` syntax (covered below) is sugar over this same mechanism; there's no separate "class" runtime concept underneath it.

## `__proto__` vs `.prototype`

These names look related and get confused constantly, but they answer different questions and live on different kinds of things.

| | `__proto__` | `.prototype` |
|---|---|---|
| What it is | An accessor property exposing an object's `[[Prototype]]` link | A plain data property |
| Exists on | Every object | Only on regular functions (constructors) |
| Exists on arrow functions? | Yes (arrow functions are objects too) | No |
| Answers | "What is this object's parent?" | "What should the parent of objects built by `new` on this function be?" |
| Enumerable | No — won't show up in `for...in` or `Object.keys()` | — |

```tsx
function Person(name) {
  this.name = name;
}
Person.prototype.greet = function () {
  return `${this.name} says hi`;
};

const p = new Person('Nayan');
p.greet();
console.log(p.__proto__ === Person.prototype); // true
```

The two connect through `new`: an object created with `new Person()` gets its `__proto__` set to `Person.prototype`, which is exactly what gives every instance access to `greet` without each instance carrying its own copy.

## What `new` actually does

`new Person('Nayan')` is four steps, not one:

1. A new, empty object is created.
2. That object's `[[Prototype]]` (`__proto__`) is set to `Person.prototype`.
3. `Person` is called with `this` bound to the new object, and the arguments passed through.
4. If `Person` doesn't explicitly return an object of its own, the new object from step 1 is returned automatically.

Every one of those steps is skippable if you reach for `Object.create` and a plain function call instead — `new` is just a convenient bundling of them.

## `Object.create()`

`Object.create(proto)` builds a new object whose `[[Prototype]]` is set directly to `proto` — no constructor function, no `new`, just an explicit parent link.

```tsx
const animal = { eats: true };
const rabbit = Object.create(animal);
rabbit.jumps = true;

console.log(rabbit.eats);  // true — delegated from animal
console.log(rabbit.jumps); // true — own property
```

This is the most direct way to demonstrate that prototypal inheritance is fundamentally "link to a parent object," independent of `class`/`new` syntax.

## Checking where a property actually lives

`hasOwnProperty()` only checks the object itself — it never walks the chain. The `in` operator checks the whole chain.

```tsx
const base = Object.create({ inherited: true });
base.own = true;

base.hasOwnProperty('own');       // true
base.hasOwnProperty('inherited'); // false — it's up the chain, not on base
'inherited' in base;              // true — in walks the whole chain
```

The same distinction shows up in iteration. `for...in` walks the whole chain and yields every *enumerable* property, own or inherited — which is almost never what you want. `Object.keys()` (and `Object.entries()`) return only the object's own enumerable keys, which is why it's the safer default for iterating "the properties I actually put on this object."

```tsx
for (const key in base) {
  if (!base.hasOwnProperty(key)) continue; // filter out inherited keys
  console.log(key);
}

Object.keys(base); // ['own'] — inherited keys never show up here at all
```

## `Object.setPrototypeOf` vs `Object.create`

`Object.create(proto)` creates a **new** object with the given parent already wired up. `Object.setPrototypeOf(obj, proto)` **mutates** an existing object's parent link after the fact. They can produce the same end state, but changing an object's prototype after creation deoptimizes property lookups in every engine that tries to speculate on object shape — prefer `Object.create` (or set the parent at construction time) and avoid `setPrototypeOf` on hot paths.

## `class`/`extends` is prototype wiring with better syntax

ES6 `class` doesn't introduce a new inheritance model — it's syntactic sugar over exactly the mechanism above. `extends` wires up the prototype chain for you instead of you doing it by hand.

```tsx
class Animal {
  speak() {
    return 'some sound';
  }
}
class Dog extends Animal {}

const d = new Dog();
d.__proto__ === Dog.prototype;                // true
Dog.prototype.__proto__ === Animal.prototype; // true
```

`extends` is doing the equivalent of `Dog.prototype.__proto__ = Animal.prototype` — that single line is the entire inheritance relationship. Everything else `class` gives you (constructor calling order, `super`, method syntax) is ergonomics layered on top of that one link.

## Chain depth is a real cost, not just theory

Every property lookup that misses walks one more link. A two- or three-level chain is free in practice, but deep inheritance hierarchies make every miss more expensive, and they couple every level to the ones above it. This is the standard case for **composition over inheritance**: build objects out of smaller pieces they own directly instead of stacking `extends` chains five levels deep. It's a performance argument and a maintainability argument at once.

## The gotcha: prototype methods are shared, not copied

This is the example that trips people up in interviews, because the output looks wrong until you remember delegation is live, not a snapshot.

```tsx
function Person() {}
Person.prototype.greet = function () {
  return 'hi';
};

const p1 = new Person();

Person.prototype.greet = function () {
  return 'hello';
};

console.log(p1.greet()); // "hello"
```

`p1` never stored its own copy of `greet` — it doesn't have one. Every call to `p1.greet()` walks the chain and reads whatever `Person.prototype.greet` currently is, at call time. Reassigning the prototype method changes what every existing *and future* instance sees, because the chain is a live reference, not a copy taken at construction time.

**Interview question: "If I add a method to a constructor's `.prototype` after instances already exist, do those instances get it?"**
Yes — because they don't own a copy, they delegate to the prototype object every time, and that lookup happens at call time, not at construction time.

## Key takeaways

- Inheritance in JS is a live *link* between objects (`[[Prototype]]`), not a copy — property lookup walks that link until it finds the property or hits `null`.
- `__proto__` exists on every object and points to its parent; `.prototype` exists only on functions and is the object `new` wires new instances' `__proto__` to.
- `new` is four explicit steps: create an object, link its `[[Prototype]]` to the constructor's `.prototype`, call the constructor with `this` bound to it, return that object unless the constructor returns its own.
- `hasOwnProperty()` checks only the object itself; `in` and `for...in` walk the whole chain — `Object.keys()` is the safe default for "just this object's own keys."
- `class`/`extends` is sugar over the same prototype wiring — `extends` sets `Child.prototype.__proto__ = Parent.prototype`.
- Prototype methods are shared live references, not per-instance copies — reassigning `Constructor.prototype.method` changes behavior for every instance immediately, including ones already constructed.
