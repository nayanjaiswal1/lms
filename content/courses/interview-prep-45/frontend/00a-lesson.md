---
kind: lesson
id_key: interview-prep-45/day-00a-frontend-call-apply-bind
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "JavaScript Internals — call, apply, bind & the in Operator"
position: 2
estimated_minutes: 25
source:
    - interview-prep-notes.md
---
"Implement `bind` from scratch" is one of the most reliable senior-frontend whiteboard questions, precisely because it forces you to demonstrate the prototype-chain and `this`-binding mechanics from the last lesson instead of just reciting them. This lesson builds `call`, `apply`, and `bind` yourself, then covers the `in` operator, a small piece of syntax that leans on the exact same delegation mechanism.

## Polyfills: call, apply, bind

All three exist to control what `this` is inside a function call. `call` and `apply` invoke the function immediately with a chosen `this`; `bind` returns a new function with `this` permanently fixed, to be called later.

```javascript
// call() - arguments comma-separated, function invoked immediately
Function.prototype.myCall = function (context, ...args) {
  context = context || globalThis;
  const fnKey = Symbol('fn'); // unique key so no existing property is overwritten
  context[fnKey] = this; // 'this' = the function myCall was invoked on

  const result = context[fnKey](...args);
  delete context[fnKey]; // cleanup
  return result;
};

// apply() - same as call, but arguments passed as an array/array-like
Function.prototype.myApply = function (context, argsArray) {
  context = context || globalThis;
  const fnKey = Symbol('fn');
  context[fnKey] = this;

  const result = argsArray ? context[fnKey](...argsArray) : context[fnKey]();
  delete context[fnKey];
  return result;
};

// bind() - returns a new function, does NOT invoke immediately
Function.prototype.myBind = function (context, ...boundArgs) {
  const fn = this; // original function

  return function (...callArgs) {
    // handle usage with 'new'
    if (this instanceof fn) {
      return fn.apply(this, [...boundArgs, ...callArgs]);
    }
    return fn.apply(context, [...boundArgs, ...callArgs]);
  };
};

// Quick test
const obj = { name: 'Nayan' };
function greet(greeting, punctuation) {
  console.log(greeting + ', ' + this.name + punctuation);
}

greet.myCall(obj, 'Hi', '!');         // Hi, Nayan!
greet.myApply(obj, ['Hello', '.']);   // Hello, Nayan.
const bound = greet.myBind(obj, 'Hey');
bound('?');                           // Hey, Nayan?
```

Notice `myBind` is implemented in terms of `apply`, not the other way around. `bind`'s whole job is to defer a call, and once it's time to actually call, it needs the exact same "invoke with this args" mechanism `apply` already provides. Also notice `myCall`/`myApply` use a `Symbol` key rather than a plain string property name: a string like `"fn"` could collide with a real property already on `context`, silently clobbering it for the duration of the call. `Symbol()` always produces a value that can't collide with anything.

**Interview trap: `call`/`apply`/`bind` don't work on arrow functions the way you'd expect.** Arrow functions don't have their own `this` binding: they close over `this` from their enclosing scope at definition time, and nothing can override that afterward. Calling `.call()`/`.apply()`/`.bind()` on an arrow function still runs it, but the `context` argument is silently ignored.

### Follow-up questions to test understanding

- Exact difference between `call` and `apply`? Identical behavior, different argument shape: `call` takes args comma-separated, `apply` takes a single array.
- What happens if `bind` is called twice (`fn.bind(a).bind(b)`)? The `this` from the *first* bind wins. `fn.bind(a)` returns a new function with `this` already hard-locked to `a`; calling `.bind(b)` on that function can prepend more arguments, but it cannot override a `this` that's already bound.
- Do `call`/`apply`/`bind` work on arrow functions? They run the function, but can't change its `this` (see the trap above).

## The in Operator

`in` checks whether a **property exists on an object** (even if its value is `undefined`), returning `true` or `false`.

```javascript
const user = { name: 'Nayan', age: undefined };

console.log('name' in user);    // true
console.log('age' in user);     // true  -> property exists, value is undefined
console.log('salary' in user);  // false -> property doesn't exist

console.log(user.age === undefined); // true (doesn't tell you if the property exists)
console.log('age' in user);           // true (this is the correct existence check)
```

### Key points

**`in` walks the prototype chain**, the same delegation mechanism from the previous lesson. It checks own properties first, and if it doesn't find the key, keeps walking `[[Prototype]]` links exactly like a normal property read does:

```javascript
const arr = [1, 2, 3];
console.log('length' in arr);   // true — own property
console.log('push' in arr);     // true — inherited from Array.prototype
console.log('toString' in arr); // true — inherited from Object.prototype
console.log(0 in arr);          // true — an array index is just a string key
console.log(5 in arr);          // false — out of bounds
```

**`in` vs `hasOwnProperty`**: this is the same own-vs-inherited distinction the prototype-chain lesson covered with `hasOwnProperty()`. `in` counts inherited properties; `hasOwnProperty` only counts properties the object itself carries.

```javascript
const user = { name: 'Nayan' };

console.log(user.hasOwnProperty('name'));     // true
console.log(user.hasOwnProperty('toString')); // false -> inherited, not own
console.log('toString' in user);              // true -> in counts inherited too
```

**Interview trap: checking existence with a truthiness check instead of `in`.**

```javascript
const config = { retries: undefined };

if (config.retries) {
  console.log('has retries — this branch is WRONG, never runs');
}
if ('retries' in config) {
  console.log('key exists — this is the correct check'); // runs
}
```

`config.retries` is `undefined`, which is falsy, so `if (config.retries)` says "no retries configured." But the key is very much there, just explicitly set to `undefined`. Any falsy-but-present value (`0`, `""`, `false`, `null`, `undefined`) breaks a truthiness check used as an existence check. `in` is the only one of the three common options that answers "does this key exist" and nothing else.

### Follow-up question

Difference between `in`, `hasOwnProperty`, and `Object.keys().includes()`? `in` walks the whole prototype chain. `hasOwnProperty` checks only the object's own properties. `Object.keys(obj).includes(key)` also checks only own *enumerable* properties, so it agrees with `hasOwnProperty` for normal object literals, but disagrees if a property was defined with `enumerable: false` via `Object.defineProperty`.
