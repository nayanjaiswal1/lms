---
kind: lesson
id_key: interview-prep-45/day-00a-frontend-call-apply-bind
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "Functions, this, and Binding"
position: 6
estimated_minutes: 30
source:
    - interview-prep-notes.md
---
"Implement `bind` from scratch" is one of the most reliable whiteboard questions there is, because it forces you to actually understand `this`-binding mechanics instead of just knowing which method to reach for. This lesson builds `call`, `apply`, and `bind` by hand, then covers three smaller patterns, the `in` operator, currying, and method chaining, that all lean on the same idea: a function call is just an expression, and what it returns is entirely up to you.

## call, apply, bind: three ways to control this

All three answer one question: what should `this` be inside a function call? `call` and `apply` answer it immediately, invoking the function right away with a chosen `this`. `bind` answers it lazily: it hands back a new function with `this` permanently fixed, to be called whenever you're ready.

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

Two details in that implementation are exactly what an interviewer probes for. First, `myBind` is written in terms of `apply`, not the other way around, because `bind`'s whole job is deferring a call, and once it is finally time to make that call, it needs the same "invoke with this and args" mechanism `apply` already provides. Second, `myCall`/`myApply` attach the function to `context` under a `Symbol` key rather than a plain string like `"fn"`, because a string could collide with a real property already on `context` and silently overwrite it for the duration of the call. A `Symbol()` can never collide with anything.

The trap worth knowing before it costs you in an interview: none of the three work on arrow functions the way you would expect. Arrow functions have no `this` of their own; they close over `this` from whatever scope they were defined in, permanently, at definition time. Calling `.call()`/`.apply()`/`.bind()` on one still runs it, but the `context` argument is silently ignored. And if `bind` is called twice, `fn.bind(a).bind(b)`, the *first* bind wins: `fn.bind(a)` already hard-locks `this` to `a`, so a second `.bind(b)` on that result can only prepend more arguments; it can never override a `this` that is already locked in.

> **Remember:** `call`/`apply` run the function now. `bind` hands you a new function to run later. None of the three can override an arrow function's `this`.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-callapplybind-q1", "type": "mcq",
      "prompt": "`const fn = () => this.value; fn.call({ value: 42 });` What does this return?",
      "options": [
        {"id":"a","text":"42"},
        {"id":"b","text":"Whatever this.value resolves to in the scope where fn was defined, since call cannot override an arrow function's this"},
        {"id":"c","text":"undefined, always, for any arrow function"},
        {"id":"d","text":"A TypeError, arrow functions can't be called with .call()"}
      ],
      "correct": "b",
      "explanation": "Arrow functions close over this lexically at definition time and never bind their own. Calling .call()/.apply()/.bind() on one still invokes it, but the context argument is silently ignored." }
] }
```

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

`config.retries` is `undefined`, which is falsy, so a naive truthiness check reads that as "missing." But the key genuinely exists; it was just deliberately set to `undefined`. Any falsy-but-present value, `0`, `""`, `false`, `null`, `undefined`, breaks a truthiness check used as an existence check, and `in` is the one of the three common options (`in`, `hasOwnProperty`, truthiness) that answers "does this key exist" and nothing else.

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

> **Remember:** `in` answers "does this key exist," even if its value is falsy or `undefined`. Truthiness answers a different question entirely.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-inoperator-q1", "type": "mcq",
      "prompt": "`const config = { retries: 0 }; if (config.retries) { ... }`. Why does this silently treat a valid setting of 0 retries as \"not configured\"?",
      "options": [
        {"id":"a","text":"It doesn't, this works correctly for 0"},
        {"id":"b","text":"0 is falsy, so the truthiness check can't distinguish 'explicitly set to 0' from 'never set at all'; 'retries' in config would answer that correctly"},
        {"id":"c","text":"Object properties can never be numbers"},
        {"id":"d","text":"config.retries throws when the value is 0"}
      ],
      "correct": "b",
      "explanation": "Any falsy-but-present value breaks a truthiness-based existence check. The in operator answers 'does this key exist' regardless of its value, which is the question actually being asked here." }
] }
```

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

The immediate payoff is partial application: baking in the first argument to get a specialized function back.

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

Trace `add3(1)(2)(3)` through the helper: the first call is `curried(1)`. Since `fn.length` is 3 and only one argument has arrived, it returns a new function still waiting. Calling that with `(2)` runs `curried(1, 2)`, still short, and returns another waiting function. Calling that with `(3)` finally runs `curried(1, 2, 3)`, which meets `fn.length`, so it calls the original `fn(1, 2, 3)` and returns `6`. This is exactly what `_.curry` does under the hood in Lodash. Across languages, the default varies: Haskell curries every function automatically; Scala and F# curry natively too, via `=>` chaining; Python has no automatic equivalent and reaches for `functools.partial` instead, or nested lambdas by hand; JavaScript sits in between, manual by default, with libraries filling the gap.

> **Remember:** currying doesn't change what a function computes, only how many calls it takes to hand over the arguments.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-currying-q1", "type": "mcq",
      "prompt": "Given `function curry(fn) { return function curried(...args) { if (args.length >= fn.length) return fn(...args); return (...more) => curried(...args, ...more); }; }` and `const add3 = curry((a, b, c) => a + b + c);`, what does `add3(1, 2)(3)` return?",
      "options": [
        {"id":"a","text":"A function, since only two arguments were given in the first call"},
        {"id":"b","text":"6, because curried keeps accumulating arguments across calls of any size until the total reaches fn.length, then calls fn"},
        {"id":"c","text":"undefined"},
        {"id":"d","text":"A TypeError, since curry requires exactly one argument per call"}
      ],
      "correct": "b",
      "explanation": "curried doesn't care how arguments are grouped across calls, only that the running total eventually reaches fn.length. (1, 2) then (3) reaches 3 arguments total, so fn(1, 2, 3) runs and returns 6." }
] }
```

## Method chaining: return this, or the chain breaks

Chaining, `str.trim().toLowerCase().replace(...)`, is not a language feature. It is a return-value convention: each method returns the same object, or one with a compatible interface, instead of `undefined`, and that return value is exactly what the next `.method()` call in line operates on.

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

Walk it through: `new QueryBuilder()` starts with `parts: []`. `.where(...)` pushes onto `parts` and returns `this`, the same instance, giving the next call something to land on. `.orderBy(...)` does the same. `.build()` finally returns a plain string instead of `this`, which is fine, since it is the last call in the chain and nothing needs to call a method on its result. Miss a `return this` on any of the middle methods and the chain breaks exactly there: the next call in line tries to call a method on `undefined` and throws. That is the first thing worth checking whenever a chained call throws "cannot read properties of undefined." This is the Builder pattern's entire mechanism, and it is how jQuery, assertion libraries like `expect(x).to.be.a("string")`, and array methods like `.filter().map()` all work.

> **Remember:** a chain is just a convention where every method returns something the next `.method()` call can land on. Forget `return this` and the chain breaks at exactly that call.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-chaining-q1", "type": "mcq",
      "prompt": "`builder.where(\"x\").orderBy(\"y\").build()` throws \"Cannot read properties of undefined (reading 'orderBy')\". What's the most likely cause?",
      "options": [
        {"id":"a","text":"build() has a bug"},
        {"id":"b","text":"where() forgot to return this, so it returned undefined, and .orderBy() is being called on that undefined"},
        {"id":"c","text":"JavaScript doesn't support method chaining"},
        {"id":"d","text":"orderBy needs to be called before where"}
      ],
      "correct": "b",
      "explanation": "The error names the exact call after the break: orderBy is being called on whatever where() returned, which must have been undefined. That means where() is missing its return this." }
] }
```
