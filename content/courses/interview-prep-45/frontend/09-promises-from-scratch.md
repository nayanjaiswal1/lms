---
kind: lesson
id_key: interview-prep-45/day-00b-frontend-promise-polyfill
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Promises From Scratch"
position: 9
estimated_minutes: 35
source:
    - interview-prep-notes.md
---
"Implement Promise from scratch" is the natural next step after `call`/`apply`/`bind`: the same "prove you understand the primitive, not just the API" question, one level up. This lesson builds a working Promise, `then`, `catch`, `finally`, `resolve`, `reject`, `all`, `race`, `allSettled`, `any`, using only closures, no `class`, no `this`.

## One fact that explains a lot of confusing behavior later: the executor runs synchronously

The function you pass to `new Promise((resolve, reject) => {...})` runs **immediately**, the instant the constructor is called, not later, not on a microtask. If that executor calls `resolve` synchronously, the promise is already fulfilled before `new Promise(...)` even finishes returning. This single fact is what makes the trace at the end of this lesson make sense, so hold onto it.

## Why closures, not a class

A `class`-based Promise would store `state`/`value`/`callbacks` as `this.state`, immediately reopening every `this`-binding footgun from the last two lessons, a detached method loses its `this`. A closure-based implementation sidesteps that entirely: the state lives in the enclosing function's own scope, captured by every inner function regardless of how those functions later get called or passed around. This is the same closure-versus-`this` tradeoff interviewers are probing for when they ask you to build this without `class`.

## The core implementation

```javascript
function myPromise(executor) {
  let state = 'pending'; // pending | fulfilled | rejected
  let value = undefined;
  let callbacks = []; // queued { onFulfilled, onRejected, resolveNext, rejectNext }

  function resolve(val) {
    if (val && typeof val.then === 'function') {
      val.then(resolve, reject); // resolved with a thenable — chain into it instead
      return;
    }
    if (state !== 'pending') return; // settling is permanent: a second call is a silent no-op
    state = 'fulfilled';
    value = val;
    flush();
  }

  function reject(reason) {
    if (state !== 'pending') return;
    state = 'rejected';
    value = reason;
    flush();
  }

  function flush() {
    queueMicrotask(() => {
      callbacks.forEach(cb => handleCallback(cb));
      callbacks = [];
    });
  }

  function handleCallback(cb) {
    const { onFulfilled, onRejected, resolveNext, rejectNext } = cb;
    try {
      if (state === 'fulfilled') {
        resolveNext(typeof onFulfilled === 'function' ? onFulfilled(value) : value);
      } else if (state === 'rejected') {
        if (typeof onRejected === 'function') resolveNext(onRejected(value));
        else rejectNext(value);
      }
    } catch (err) {
      rejectNext(err);
    }
  }

  function then(onFulfilled, onRejected) {
    return myPromise((resolveNext, rejectNext) => {
      const cb = { onFulfilled, onRejected, resolveNext, rejectNext };
      if (state === 'pending') callbacks.push(cb);
      else queueMicrotask(() => handleCallback(cb));
    });
  }

  function catchFn(onRejected) { return then(null, onRejected); }
  function finallyFn(onFinally) {
    return then(
      val => { onFinally(); return val; },
      err => { onFinally(); throw err; },
    );
  }

  try {
    executor(resolve, reject);
  } catch (err) {
    reject(err); // a synchronous throw in the executor auto-converts to a rejection
  }

  return { then, catch: catchFn, finally: finallyFn };
}
```

Walking the pieces: state lives in closure scope, so every inner function shares it by reference with no `this` involved anywhere. `resolve` unwraps thenables, if you resolve with another promise (or anything with a `.then` method), it chains into that instead of treating it as a final value, a simplified version of the spec's actual Promise Resolution Procedure. Callbacks queue while the promise is pending; `then` always returns a *new* `myPromise`, which is what makes `.then().then().then()` chaining possible, each call hands back a fresh promise that settles based on whatever the previous handler returned or threw. `queueMicrotask` schedules the async part: real Promise callbacks never run synchronously, even if the promise was already settled when `.then()` was called, and the reference implementation above deliberately still wraps that already-settled path in `queueMicrotask` rather than calling `handleCallback` immediately. Skipping that would make `.then()` sometimes synchronous and sometimes not, depending purely on timing, exactly the class of bug the guarantee exists to prevent.

## Chaining: why then always needs to return a new promise

`.then()` can be called before a promise settles (the async case, waiting inside a `setTimeout`) or after it already has (the sync case). Both need handling: already-settled calls the callback right away; still-pending pushes it onto a queue that `resolve`/`reject` will drain once the state changes. For chaining specifically, the callback's return value has to become the *next* promise's resolved value if it returns a plain value, or the next promise's rejection if it throws, mirroring exactly how a synchronous `try`/`catch` propagates. That's what lets an error thrown three `.then()` calls deep still land in a single `.catch()` at the very end of the chain.

## Static methods: resolve, reject, all, race

```javascript
myPromise.resolve = function (val) { return myPromise(resolve => resolve(val)); };
myPromise.reject = function (reason) { return myPromise((_, reject) => reject(reason)); };

myPromise.all = function (promises) {
  return myPromise((resolve, reject) => {
    const results = [];
    let completed = 0;
    if (promises.length === 0) return resolve([]);
    promises.forEach((p, i) => {
      myPromise.resolve(p).then(val => {
        results[i] = val;
        completed++;
        if (completed === promises.length) resolve(results);
      }, reject);
    });
  });
};

myPromise.race = function (promises) {
  return myPromise((resolve, reject) => {
    promises.forEach(p => myPromise.resolve(p).then(resolve, reject));
  });
};
```

`all` rejects the instant any one promise rejects, because `.then(val => {...}, reject)` wires every individual promise's rejection straight to the outer promise's `reject`, and the first rejection to fire wins, `resolve`/`reject` are no-ops after the first call by the `state !== 'pending'` guard earlier. The other promises in the array keep running, they're still `.then()`-ed, `all` just stops caring about their eventual results once it has already settled.

## The other two combinators, and where each one actually settles

`Promise.all`, `.race`, `.allSettled`, and `.any` all sound similar and get mixed up constantly. The difference is exactly what condition ends the wait:

| Combinator | Settles when | Empty array |
|---|---|---|
| `all` | any one rejects, or every one resolves | resolves `[]` |
| `race` | the very first promise settles, win or lose | stays pending forever |
| `allSettled` | always waits for every promise, regardless of outcome | resolves `[]` |
| `any` | the first promise resolves | rejects with an `AggregateError` |

```javascript
function allSettled(promises) {
  const result = [];
  let count = 0;
  return new Promise((resolve) => {
    if (promises.length === 0) return resolve([]);
    promises.forEach((promise, index) => {
      promise
        .then(value => { result[index] = { status: "fulfilled", value }; })
        .catch(reason => { result[index] = { status: "rejected", reason }; })
        .finally(() => { count++; if (count === promises.length) resolve(result); });
    });
  });
}
```

`allSettled` never fails fast: it waits for every promise no matter the outcome, recording a `fulfilled` or `rejected` entry for each. `.finally()` is doing the real work here, incrementing the shared counter on both the resolve and reject branches so that logic doesn't need to be duplicated in each `.then()`/`.catch()` separately.

```javascript
function any(promises) {
  const errors = [];
  let count = 0;
  return new Promise((resolve, reject) => {
    if (promises.length === 0) return reject(new AggregateError([], "All promises were rejected"));
    promises.forEach((promise, index) => {
      promise
        .then(value => resolve(value))
        .catch(reason => { errors[index] = reason; })
        .finally(() => { count++; if (count === promises.length) reject(new AggregateError(errors)); });
    });
  });
}
```

The key fact that makes this implementation safe: once a promise settles, calling `resolve` or `reject` on it again is a silent no-op. If one promise resolves early, `resolve(value)` fires once and wins; even if `count` later reaches `promises.length` and the code tries to `reject`, that second call does nothing at all, because the promise already settled. `race` answers "whoever finishes first, win or lose"; `any` answers "give me the first success, and only give up once nothing succeeded."

## Tracing the output order

```tsx
async function asyncOrder() {
  console.log('A: start');
  await Promise.resolve();
  console.log('B: after await');
}

console.log('start');
asyncOrder();
console.log('end');

// Output: start, A: start, end, B: after await
```

Everything in `asyncOrder` before the `await` runs synchronously, the instant the function is called, exactly like the executor fact this lesson opened with. The code after `await` is scheduled as a microtask continuation, equivalent to `Promise.resolve().then(() => { ...rest of function... })`, which is why `end` (still on the synchronous call stack) prints before `B: after await` (deferred to the microtask queue), even though `asyncOrder()` was called before the final `console.log('end')` in the source.
