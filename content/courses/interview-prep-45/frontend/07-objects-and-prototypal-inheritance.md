---
kind: lesson
id_key: interview-prep-45/day-00-frontend-prototype-chain
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Objects and Prototypal Inheritance"
position: 7
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---
Before React internals make any sense, you need the mechanism React itself is built on. Class components, `this` binding, and even how `class`/`extends` behave under the hood all rest on prototypal inheritance, which works nothing like the classical, class-based inheritance in Java or C#. "Explain the prototype chain" and "what does `new` actually do" are two of the most reliable frontend-fundamentals questions there are, and they test whether you understand how JavaScript looks things up, not whether you've memorized syntax.

## Property lookup is a walk, not a lookup table

Every JavaScript object carries an internal link, `[[Prototype]]`, to another object, or to `null`. When you read a property, the engine doesn't stop at the object itself if it's not there: it walks up the `[[Prototype]]` link and checks that object, then its own `[[Prototype]]`, and so on, until it finds the property or hits `null`.

```tsx
const grandparent = { surname: 'Sharma' };
const parent = Object.create(grandparent);
parent.car = 'Swift';
const child = Object.create(parent);
child.name = 'Nayan';

child.name;     // "Nayan" — found on child itself
child.car;      // "Swift" — one link up
child.surname;  // "Sharma" — two links up
child.toString; // function — found at the top, Object.prototype
```

That walk is the **prototype chain**, and the mechanism behind it is called **delegation**: an object doesn't copy its parent's properties in, it defers the lookup upward whenever it doesn't have something itself. Every chain eventually reaches `Object.prototype`, the source of `.toString()` and `.hasOwnProperty()`, whose own `[[Prototype]]` is `null`. That's where every chain ends. JavaScript's inheritance is prototypal, not class-based: objects link directly to other objects, and `class` syntax, covered further down, is sugar layered on top of that same mechanism, not a separate runtime concept.

## __proto__ versus .prototype: two different questions

These two names get confused constantly because they look related, but they answer different questions and live on different kinds of things.

| | `__proto__` | `.prototype` |
|---|---|---|
| What it is | An accessor exposing an object's `[[Prototype]]` link | A plain data property |
| Exists on | Every object | Only on regular functions (constructors) |
| Answers | "What is this object's parent?" | "What should the parent of objects built by `new` on this function be?" |

```tsx
function Person(name) { this.name = name; }
Person.prototype.greet = function () { return `${this.name} says hi`; };

const p = new Person('Nayan');
p.greet();
p.__proto__ === Person.prototype; // true
```

`new` is what connects them: an object built with `new Person()` gets its `__proto__` set to `Person.prototype`, and that link is exactly what gives every instance access to `greet` without each one carrying its own copy.

## What new actually does, in four steps

`new Person('Nayan')` isn't one atomic operation. It's four:

1. A new, empty object is created.
2. That object's `[[Prototype]]` is set to `Person.prototype`.
3. `Person` runs with `this` bound to the new object, and the arguments passed through.
4. If `Person` doesn't explicitly return an object of its own, the object from step 1 is returned automatically.

Every one of those steps is skippable by hand, using `Object.create` and a plain function call instead; `new` is just a convenient bundling of the same four steps. `Object.create(proto)` in particular makes the "link to a parent object" idea explicit, with no constructor function and no `new` involved at all:

```tsx
const animal = { eats: true };
const rabbit = Object.create(animal);
rabbit.jumps = true;

rabbit.eats;  // true — delegated from animal
rabbit.jumps; // true — own property
```

`Object.create(proto)` creates a brand-new object with its parent already wired up; `Object.setPrototypeOf(obj, proto)` mutates an *existing* object's parent link after the fact. They can land on the same end state, but changing a prototype after creation deoptimizes property lookups in every major engine, since they can no longer speculate confidently on that object's shape. Prefer `Object.create`, or set the parent at construction time, and avoid `setPrototypeOf` anywhere performance-sensitive.

## hasOwnProperty, in, and the two ways to iterate

`hasOwnProperty()` only checks the object itself, it never walks the chain. `in` checks the whole chain.

```tsx
const base = Object.create({ inherited: true });
base.own = true;

base.hasOwnProperty('own');       // true
base.hasOwnProperty('inherited'); // false — up the chain, not on base
'inherited' in base;              // true — in walks the whole chain
```

The same own-versus-inherited split shows up in iteration. `for...in` walks the whole chain and yields every *enumerable* property, own or inherited, which is almost never what you actually want. `Object.keys()`/`Object.entries()` return only an object's own enumerable keys, which is why they're the safer default:

```tsx
for (const key in base) {
  if (!base.hasOwnProperty(key)) continue; // filter out inherited keys
  console.log(key);
}
Object.keys(base); // ['own'] — inherited keys never appear here at all
```

## class/extends is the same wiring, better syntax

ES6 `class` introduces no new inheritance model. `extends` wires up the prototype chain for you instead of you doing it by hand:

```tsx
class Animal { speak() { return 'some sound'; } }
class Dog extends Animal {}

const d = new Dog();
d.__proto__ === Dog.prototype;                // true
Dog.prototype.__proto__ === Animal.prototype; // true
```

`extends` is doing the equivalent of `Dog.prototype.__proto__ = Animal.prototype`, and that single link is the entire inheritance relationship. Everything else `class` gives you, constructor call order, `super`, method syntax, is ergonomics stacked on top of that one line.

Before `extends` existed, that wiring was manual, and it's a classic whiteboard trap because one step is easy to forget:

```js
function Animal() {}
Animal.prototype.eat = function () { return "eating"; };

function Dog() {}
Dog.prototype = Object.create(Animal.prototype); // link the chain
Dog.prototype.constructor = Dog;                  // MUST fix by hand

const d = new Dog();
d.constructor === Dog; // true, only because of the line above
```

Skip that last line and `d.constructor` silently points at `Animal` instead of `Dog`, which breaks anything relying on `obj.constructor` for cloning or a factory pattern like `new obj.constructor()`. `class extends` sidesteps the whole problem by wiring the constructor link correctly on its own, which is a real part of why it replaced the manual pattern rather than just being nicer to read.

## Chain depth is a real cost, and instanceof depends on identity, not names

Every property lookup that misses walks one more link. A two- or three-level chain is free in practice, but a genuinely deep hierarchy makes every miss more expensive and couples every level to the ones above it, the standard argument for **composition over inheritance**: build objects out of pieces they own directly rather than stacking `extends` five levels deep.

`obj instanceof Fn` is built directly on this walk. It checks whether `Fn.prototype` appears anywhere in `obj`'s prototype chain, by object identity, not by checking a constructor's name or any stored type tag:

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

That identity check is exactly what makes this gotcha possible: reassigning `Fn.prototype` to a brand-new object *after* instances already exist breaks `instanceof` for those existing instances, because they still hold a live link to the *original* prototype object, not the new one.

```js
function Foo() {}
const f = new Foo();
Foo.prototype = {}; // a new object, unrelated to what f links to
f instanceof Foo; // false — f still links to the ORIGINAL Foo.prototype
```

Nothing about `f` itself changed here; only what `Foo.prototype` currently points to did. `isInstance(f, Foo)` walks `f`'s original prototype, compares it against the new `Foo.prototype`, fails, climbs to `Object.prototype`, fails again, and returns `false` at `null`. That's the mechanical reason "reassigning `.prototype` breaks existing instances" is true, not just a rule to memorize.

## The gotcha that trips people up live

```tsx
function Person() {}
Person.prototype.greet = function () { return 'hi'; };
const p1 = new Person();
Person.prototype.greet = function () { return 'hello'; };
p1.greet(); // "hello"
```

`p1` never stored its own copy of `greet`, it doesn't have one. Every call walks the chain and reads whatever `Person.prototype.greet` currently is, at call time, not at construction time. Reassigning the prototype method changes what every existing *and future* instance sees, because the chain is a live reference, not a snapshot taken when the instance was created. If a hook can add a method to a constructor's `.prototype` after instances already exist, those instances get it too, for exactly the same reason: they were never going to see anything but whatever's currently there.
