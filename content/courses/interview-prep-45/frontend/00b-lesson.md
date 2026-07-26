---
kind: lesson
id_key: interview-prep-45/day-00b-frontend-promise-polyfill
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "JavaScript Internals — Promise Polyfill from Scratch"
position: 3
estimated_minutes: 30
source:
    - interview-prep-notes.md
---
"Implement Promise from scratch" is the natural next step after `call`/`apply`/`bind`: it's the same "prove you understand the primitive, not just the API" question, one level up. This lesson builds a working Promise — `then`, `catch`, `finally`, `resolve`, `reject`, `all`, `race` — using only closures, no `class`, no `this`. The microtask scheduling it leans on (`queueMicrotask`) is exactly what Day 3 covers in depth; this lesson uses that mechanism rather than re-explaining it.

## Why closures, not a class

A `class`-based Promise would store `state`/`value`/`callbacks` as `this.state`, etc. — and immediately reopen every `this`-binding footgun from the last two lessons (a detached method loses its `this`). A closure-based implementation sidesteps that entirely: `state`, `value`, and `callbacks` live in the enclosing function's scope, captured by every inner function (`resolve`, `reject`, `then`, ...) regardless of how those functions are later called or passed around. This is the same "prototype chain vs closure" tradeoff interviewers are probing when they ask you to build this without `class`.

## Core implementation

```javascript
function myPromise(executor) {
  let state = 'pending'; // pending | fulfilled | rejected
  let value = undefined;
  let callbacks = []; // queued { onFulfilled, onRejected, resolveNext, rejectNext }

  function resolve(val) {
    if (val && typeof val.then === 'function') {
      val.then(resolve, reject);
      return;
    }
    if (state !== 'pending') return;
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
        if (typeof onRejected === 'function') {
          resolveNext(onRejected(value));
        } else {
          rejectNext(value);
        }
      }
    } catch (err) {
      rejectNext(err);
    }
  }

  function then(onFulfilled, onRejected) {
    return myPromise((resolveNext, rejectNext) => {
      const cb = { onFulfilled, onRejected, resolveNext, rejectNext };
      if (state === 'pending') {
        callbacks.push(cb);
      } else {
        queueMicrotask(() => handleCallback(cb));
      }
    });
  }

  function catchFn(onRejected) {
    return then(null, onRejected);
  }

  function finallyFn(onFinally) {
    return then(
      val => { onFinally(); return val; },
      err => { onFinally(); throw err; }
    );
  }

  try {
    executor(resolve, reject);
  } catch (err) {
    reject(err);
  }

  return { then, catch: catchFn, finally: finallyFn };
}

// Quick test
const p = myPromise((resolve) => {
  setTimeout(() => resolve('done'), 10);
});
p.then(v => console.log('resolved with', v));
```

Walking the pieces:

- **State lives in closure scope.** `state`, `value`, `callbacks` are plain local variables — every inner function shares them by reference, no `this` involved anywhere.
- **`resolve` unwraps thenables.** If you resolve a `myPromise` with another promise (or anything with a `.then` method), it chains into that promise instead of treating it as a final value. This is a simplified version of the real spec's Promise Resolution Procedure.
- **Callbacks queue while pending.** If `then` is called before the promise settles, its callback goes into `callbacks` and waits for `flush()`.
- **`then` always returns a new `myPromise`.** This is what makes `.then().then().then()` chaining possible — each `then` call hands back a fresh promise that settles based on what the previous handler returned or threw.
- **`queueMicrotask` schedules the async part.** Real Promise callbacks never run synchronously, even if the promise is already settled when `.then()` is called — Day 3 covers exactly why that consistency matters (it's what prevents "sometimes sync, sometimes async" bugs).

**Interview trap: forgetting to make `then` itself asynchronous when the promise is already settled.** If `then` is called on an already-fulfilled promise, it's tempting to just call `handleCallback` immediately, synchronously. The reference implementation above still wraps that path in `queueMicrotask` — real Promises guarantee `.then()` callbacks are *always* asynchronous, never synchronous, so behavior doesn't depend on timing.

## Static methods: resolve, reject, all, race

```javascript
myPromise.resolve = function (val) {
  return myPromise(resolve => resolve(val));
};

myPromise.reject = function (reason) {
  return myPromise((_, reject) => reject(reason));
};

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
    promises.forEach(p => {
      myPromise.resolve(p).then(resolve, reject);
    });
  });
};

// Quick test
myPromise.all([
  myPromise.resolve(1),
  myPromise.resolve(2),
  myPromise.resolve(3),
]).then(values => console.log('all resolved:', values));
```

**Interview question: "Why does `all` reject as soon as any one promise rejects, but keep waiting for the rest anyway?"**
Because `.then(val => {...}, reject)` wires every individual promise's rejection straight to the outer promise's `reject` — the first rejection to fire wins and settles the outer promise immediately (`resolve`/`reject` are no-ops after the first call, enforced by the `state !== 'pending'` guard). The other promises in the array are still `.then()`-ed and will still run their side effects; `all` just stops caring about their results once it has already settled.

## Key takeaways

- Closures replace `this` entirely: `state`/`value`/`callbacks` are captured lexically, so none of these functions can lose their binding no matter how they're called or passed around.
- `resolve` recursively unwraps thenables (`val.then(resolve, reject)`) — this is what lets you resolve one promise with another.
- Every `.then()` call returns a brand new `myPromise`, which is the entire mechanism behind chaining.
- Pending callbacks queue in an array and get replayed by `flush()` once the promise settles; already-settled promises still schedule their callback via `queueMicrotask` rather than calling it synchronously.
- `all` and `race` are both built from `then`, not reimplemented from scratch — `all` resolves once every wrapped promise resolves, `race` and `all`'s rejection path both settle on the first promise to finish (reject for both, resolve only for `race`).
