---
kind: lesson
id_key: interview-prep-45/day-00a-frontend-call-apply-bind
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Functions, this, and Binding"
position: 6
estimated_minutes: 30
source:
    - interview-prep-notes.md
---
"Implement `bind` from scratch" is one of the most reliable whiteboard questions there is, precisely because it forces you to actually understand `this`-binding mechanics instead of just knowing which method to reach for. This lesson builds `call`, `apply`, and `bind` by hand, then covers three smaller patterns, the `in` operator, currying, and method chaining, that all lean on the same idea: a function call is just an expression, and what it returns is entirely up to you.

## call, apply, bind: three ways to control this

All three exist to answer one question: what should `this` be inside a function call? `call` and `apply` answer it immediately, invoking the function right away with a chosen `this`. `bind` answers it lazily, returning a new function with `this` permanently fixed, to be called whenever you're ready.

```javascript
Function.prototype.myCall = function (context, ...args) {
  context = context || globalThis;
  const fnKey = Symbol('fn'); // a unique key so no existing property gets clobbered
  context[fnKey] = this;
  const result = context[fnKey](...args);
  delete context[fnKey];
  return result;
};

Function.prototype.myApply = function (context, argsArray) {
  context = context || globalThis;
  const fnKey = Symbol('fn');
  context[fnKey] = this;
  const result = argsArray ? context[fnKey](...argsArray) : context[fnKey]();
  delete context[fnKey];
  return result;
};

Function.prototype.myBind = function (context, ...boundArgs) {
  const fn = this;
  return function (...callArgs) {
    if (this instanceof fn) return fn.apply(this, [...boundArgs, ...callArgs]); // called with `new`
    return fn.apply(context, [...boundArgs, ...callArgs]);
  };
};

const obj = { name: 'Nayan' };
function greet(greeting, punctuation) {
  console.log(greeting + ', ' + this.name + punctuation);
}
greet.myCall(obj, 'Hi', '!');        // Hi, Nayan!
greet.myApply(obj, ['Hello', '.']);  // Hello, Nayan.
greet.myBind(obj, 'Hey')('?');       // Hey, Nayan?
```

Two details worth noticing in that implementation, because they're exactly what an interviewer probes for. First, `myBind` is written in terms of `apply`, not the other way around, because `bind`'s whole job is deferring a call, and once it's finally time to make that call, it needs the same "invoke with this and args" mechanism `apply` already provides. Second, `myCall`/`myApply` attach the function to `context` under a `Symbol` key rather than a plain string like `"fn"`, because a string could collide with a real property already on `context` and silently overwrite it for the duration of the call. A `Symbol()` can never collide with anything.

The trap worth knowing before it costs you in an interview: none of the three work on arrow functions the way you'd expect. Arrow functions don't have their own `this`, they close over `this` from whatever scope they were defined in, permanently, at definition time. Calling `.call()`/`.apply()`/`.bind()` on one still runs it, but the `context` argument is silently ignored. And if `bind` gets called twice, `fn.bind(a).bind(b)`, the *first* bind wins: `fn.bind(a)` already hard-locks `this` to `a`, so a second `.bind(b)` on that result can only prepend more arguments, it can never override a `this` that's already locked in.

## The in operator: existence, not truthiness

`in` checks whether a property exists on an object at all, even if its value is `undefined`, which is a different question than whether the value is truthy.

```javascript
const config = { retries: undefined };

if (config.retries) {
  // never runs — undefined is falsy, so this looks like "no retries configured"
}
if ('retries' in config) {
  // runs — the key IS there, it's just explicitly set to undefined
}
```

`config.retries` is `undefined`, which is falsy, so a naive truthiness check reads that as "missing." But the key is genuinely present; it was just deliberately set to `undefined`. Any falsy-but-present value, `0`, `""`, `false`, `null`, `undefined`, breaks a truthiness check used as an existence check, and `in` is the one option of the three common ones (`in`, `hasOwnProperty`, truthiness) that answers "does this key exist" and nothing else.

`in` also walks the prototype chain, the same delegation mechanism the next lesson covers in depth, which is the practical difference between `in` and `hasOwnProperty`:

```javascript
const arr = [1, 2, 3];
console.log('length' in arr);   // true — own property
console.log('push' in arr);     // true — inherited from Array.prototype
console.log(5 in arr);          // false — out of bounds

const user = { name: 'Nayan' };
console.log(user.hasOwnProperty('toString')); // false — inherited, not own
console.log('toString' in user);              // true — in counts inherited too
```

`Object.keys(obj).includes(key)` agrees with `hasOwnProperty` for a normal object literal, since both only look at own, enumerable keys, but the two can diverge for a property explicitly defined with `enumerable: false` via `Object.defineProperty`.

## Currying: one argument at a time

Currying turns a function that takes several arguments into a chain of functions that each take one, returning a new function until every argument has finally arrived.

```javascript
// Normal
function add(a, b) { return a + b; }
add(2, 3); // 5

// Curried
const add = a => b => a + b;
add(2)(3); // 5
```

The immediate payoff is partial application, baking in the first argument to get a specialized function back:

```javascript
const add10 = add(10);
add10(5);  // 15
add10(20); // 30
```

which makes curried functions natural to chain through `.map` or a `pipe` helper:

```javascript
const multiply = a => b => a * b;
[1, 2, 3].map(multiply(2)); // [2, 4, 6]

const pipe = (...fns) => x => fns.reduce((v, f) => f(v), x);
const process = pipe(add(1), multiply(2), add(10));
process(5); // ((5+1)*2)+10 = 22
```

Real code rarely hand-writes the nested-arrow form for every function; a generic `curry` helper auto-curries based on how many arguments the original function declared:

```javascript
function curry(fn) {
  return function curried(...args) {
    if (args.length >= fn.length) return fn(...args);
    return (...more) => curried(...args, ...more);
  };
}

const add3 = curry((a, b, c) => a + b + c);
add3(1)(2)(3);  // 6
add3(1, 2)(3);  // 6 — same destination, arguments just supplied in different-sized groups
```

Trace `add3(1)(2)(3)` through the helper: the first call is `curried(1)`. Since `fn.length` is 3 and only one argument arrived, it returns a new function still waiting. Calling that with `(2)` runs `curried(1, 2)`, still short, returns another waiting function. Calling that with `(3)` finally runs `curried(1, 2, 3)`, which meets `fn.length`, so it calls the original `fn(1, 2, 3)` and returns `6`. This is exactly what `_.curry` does under the hood in Lodash. Across languages, the default varies: Haskell curries every function automatically; Scala and F# curry natively too, via `=>` chaining; Python has no automatic equivalent and reaches for `functools.partial` instead, or nested lambdas by hand; JavaScript sits in between, manual by default, with libraries filling the gap.

## Method chaining: return this, or the chain breaks

Chaining, `str.trim().toLowerCase().replace(...)`, isn't a language feature. It's a return-value convention: each method returns the same object (or one with a compatible interface) instead of `undefined`, and that return value is exactly what the next `.method()` call in line operates on.

```javascript
class QueryBuilder {
  constructor() { this.parts = []; }
  where(cond)  { this.parts.push(`WHERE ${cond}`); return this; }
  orderBy(col) { this.parts.push(`ORDER BY ${col}`); return this; }
  build()      { return this.parts.join(" "); }
}

new QueryBuilder().where("age > 18").orderBy("name").build();
// "WHERE age > 18 ORDER BY name"
```

Walk it through: `new QueryBuilder()` starts with `parts: []`. `.where(...)` pushes onto `parts` and returns `this`, the same instance, giving the next call something to land on. `.orderBy(...)` does the same. `.build()` finally returns a plain string instead of `this`, which is fine, because it's the last call in the chain and nothing needs to call a method on its result. Miss a `return this` on any of the middle methods and the chain breaks exactly there, the next call in line tries to call a method on `undefined` and throws. That's the one bug worth checking first whenever a chained call throws "cannot read properties of undefined": this is the Builder pattern's entire mechanism, and it's how jQuery, `expect(x).to.be.a("string")`-style assertion libraries, and array methods like `.filter().map()` all work.
