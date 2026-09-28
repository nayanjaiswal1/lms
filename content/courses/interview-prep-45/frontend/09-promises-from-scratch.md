---
kind: lesson
id_key: interview-prep-45/day-00b-frontend-promise-polyfill
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "Promises From Scratch"
position: 9
estimated_minutes: 35
source:
    - interview-prep-notes.md
---
"Implement Promise from scratch" is the natural next step after `call`/`apply`/`bind`: the same "prove you understand the primitive, not just the API" question, one level up. This lesson builds a working Promise, `then`, `catch`, `finally`, `resolve`, `reject`, `all`, `race`, `allSettled`, `any`, using only closures, no `class`, no `this`.

## One fact that explains a lot of confusing behavior later: the executor runs synchronously

The function you pass to `new Promise((resolve, reject) => {...})` runs **immediately**, the instant the constructor is called, not later, not on a microtask. If that executor calls `resolve` synchronously, the promise is already fulfilled before `new Promise(...)` even finishes returning. Hold onto this fact; it is what makes the trace at the end of this lesson make sense.

> **Remember:** the executor function runs the moment `new Promise(...)` is called, synchronously, before the line even finishes evaluating.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-promiseexecutor-q1", "type": "mcq",
      "prompt": "`console.log('a'); new Promise((resolve) => { console.log('b'); resolve(); }); console.log('c');` What order do 'a', 'b', 'c' print in?",
      "options": [
        {"id":"a","text":"a, c, b — the executor is always deferred"},
        {"id":"b","text":"a, b, c — the executor function runs synchronously the instant new Promise() is called"},
        {"id":"c","text":"b, a, c"},
        {"id":"d","text":"It's non-deterministic"}
      ],
      "correct": "b",
      "explanation": "The executor runs immediately and synchronously when the Promise constructor is called, not deferred to a microtask. Only .then() callbacks are deferred." }
] }
```

## Why closures, not a class

A `class`-based Promise would store `state`/`value`/`callbacks` as `this.state`, immediately reopening every `this`-binding footgun from the functions and binding lessons: a detached method loses its `this`. A closure-based implementation sidesteps that entirely. The state lives in the enclosing function's own scope, captured by every inner function regardless of how those functions later get called or passed around. This is the same closure-versus-`this` trade-off interviewers are probing for when they ask you to build this without `class`.

> **Remember:** a closure-based implementation shares state through the enclosing function's scope. A class-based one would reopen every `this`-binding footgun a detached method call can hit.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-promiseclosures-q1", "type": "mcq",
      "prompt": "Why does a closure-based Promise implementation avoid the `this`-binding bugs a `class`-based one would reintroduce?",
      "options": [
        {"id":"a","text":"Closures are faster than classes"},
        {"id":"b","text":"State lives in the enclosing function's own scope and is captured directly by every inner function, with no this involved anywhere, so passing a method around detached from its object causes no binding issue"},
        {"id":"c","text":"JavaScript classes cannot hold private state"},
        {"id":"d","text":"There's no real difference, both approaches are equally safe"}
      ],
      "correct": "b",
      "explanation": "A class-based implementation would store state as this.state, which breaks the moment a method is called detached from its instance (passed as a callback, for example). A closure captures its variables directly, with no this dependency to break." }
] }
```

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

Walking the pieces: state lives in closure scope, so every inner function shares it by reference with no `this` involved anywhere. `resolve` unwraps thenables: if you resolve with another promise, or anything with a `.then` method, it chains into that instead of treating it as a final value, a simplified version of the spec's actual Promise Resolution Procedure. Callbacks queue while the promise is pending. `then` always returns a *new* `myPromise`, which is what makes `.then().then().then()` chaining possible: each call hands back a fresh promise that settles based on whatever the previous handler returned or threw. `queueMicrotask` schedules the async part: real Promise callbacks never run synchronously, even if the promise was already settled when `.then()` was called, and the implementation above deliberately still wraps that already-settled path in `queueMicrotask` rather than calling `handleCallback` immediately. Skip that and `.then()` would sometimes run synchronously and sometimes not, depending purely on timing, exactly the class of bug this guarantee exists to prevent.

> **Remember:** `.then()` always returns a new promise, and it is always deferred to a microtask, even if the original promise already settled.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-promiseimpl-q1", "type": "mcq",
      "prompt": "In the `myPromise` implementation, why does `then()` still call `queueMicrotask` even when the promise has already settled before `.then()` is called?",
      "options": [
        {"id":"a","text":"To make the code simpler, it has no real effect"},
        {"id":"b","text":"To guarantee .then() callbacks always run asynchronously, so behavior doesn't depend on timing — real Promises never call a .then() handler synchronously, settled or not"},
        {"id":"c","text":"Because queueMicrotask is required by JavaScript syntax rules"},
        {"id":"d","text":"To make the promise reject if it takes too long"}
      ],
      "correct": "b",
      "explanation": "If the already-settled path ran the callback synchronously, then a promise's timing behavior would differ depending purely on when .then() happened to be called, which is exactly the inconsistency the microtask guarantee exists to remove." }
] }
```

## Chaining: why then always needs to return a new promise

`.then()` can be called before a promise settles, the async case, waiting inside a `setTimeout`, or after it already has, the sync case. Both need handling: an already-settled call runs the callback right away; a still-pending call pushes it onto a queue that `resolve`/`reject` will drain once the state changes. For chaining specifically, the callback's return value has to become the *next* promise's resolved value if it returns a plain value, or the next promise's rejection if it throws, mirroring exactly how a synchronous `try`/`catch` propagates. That is what lets an error thrown three `.then()` calls deep still land in a single `.catch()` at the very end of the chain.

> **Remember:** a handler's return value becomes the next promise's resolved value; a thrown error becomes the next promise's rejection. That's what lets one `.catch()` at the end catch an error from several `.then()` calls back.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-promisechaining-q1", "type": "mcq",
      "prompt": "An error is thrown inside the second `.then()` callback in a chain of four `.then()` calls followed by one `.catch()`. What happens?",
      "options": [
        {"id":"a","text":"The chain stops immediately and nothing after the throw ever runs"},
        {"id":"b","text":"The thrown error becomes that promise's rejection, which skips the remaining .then() handlers (since they have no onRejected) and lands directly in the final .catch()"},
        {"id":"c","text":"The error is silently swallowed"},
        {"id":"d","text":"Only the immediately next .then() call is skipped, then normal .then() handlers resume"}
      ],
      "correct": "b",
      "explanation": "A throw inside a .then() handler becomes the returned promise's rejection. Each subsequent .then() without an onRejected handler just passes that rejection through unchanged, until a .catch() (or a .then() with an onRejected) finally handles it." }
] }
```

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

`all` rejects the instant any one promise rejects, because `.then(val => {...}, reject)` wires every individual promise's rejection straight to the outer promise's `reject`, and the first rejection to fire wins: `resolve`/`reject` are no-ops after the first call, thanks to the `state !== 'pending'` guard earlier. The other promises in the array keep running, they are still `.then()`-ed, `all` just stops caring about their eventual results once it has already settled.

> **Remember:** `Promise.all` rejects on the very first rejection, but the other promises keep running in the background regardless.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-promiseall-q1", "type": "mcq",
      "prompt": "`Promise.all([p1, p2, p3])` where p2 rejects immediately and p1/p3 are still pending. What happens?",
      "options": [
        {"id":"a","text":"The returned promise waits for p1 and p3 to finish before settling"},
        {"id":"b","text":"The returned promise rejects immediately with p2's reason, while p1 and p3 keep running in the background, unobserved by all"},
        {"id":"c","text":"An error is thrown synchronously"},
        {"id":"d","text":"all silently ignores the rejection and resolves with whatever p1 and p3 return"}
      ],
      "correct": "b",
      "explanation": "all wires every promise's rejection straight to the combined promise's own reject, and the first one to fire wins. The still-pending promises are not cancelled, they simply become irrelevant to the already-settled all() result." }
] }
```

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

`allSettled` never fails fast: it waits for every promise no matter the outcome, recording a `fulfilled` or `rejected` entry for each. `.finally()` does the real work here, incrementing the shared counter on both the resolve and reject branches, so that bookkeeping does not need to be duplicated in each `.then()`/`.catch()` separately.

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

The key fact that makes this implementation safe: once a promise settles, calling `resolve` or `reject` on it again is a silent no-op. If one promise resolves early, `resolve(value)` fires once and wins; even if `count` later reaches `promises.length` and the code tries to `reject`, that second call does nothing at all, because the promise already settled. `race` answers "whoever finishes first, win or lose." `any` answers "give me the first success, and only give up once nothing succeeded."

> **Remember:** `race` cares who finishes first, win or lose. `any` cares only about the first success, and only gives up once everything has failed.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-combinators-q1", "type": "mcq",
      "prompt": "You need one thing to happen the instant the FIRST of several promises succeeds, but only give up if every single one fails. Which combinator, and why not `Promise.race`?",
      "options": [
        {"id":"a","text":"Promise.race, since it settles on whoever finishes first"},
        {"id":"b","text":"Promise.any, because race settles on the first promise to settle at all — win or lose — while any specifically waits for the first success and only rejects once everything has failed"},
        {"id":"c","text":"Promise.all, since it waits for everyone"},
        {"id":"d","text":"Promise.allSettled, since it never rejects"}
      ],
      "correct": "b",
      "explanation": "race would incorrectly settle on an early rejection even if a later promise would have succeeded. any is built exactly for 'first success wins, give up only if all fail.'" }
] }
```

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

Everything in `asyncOrder` before the `await` runs synchronously, the instant the function is called, exactly like the executor fact this lesson opened with. The code after `await` is scheduled as a microtask continuation, equivalent to `Promise.resolve().then(() => { ...rest of function... })`, which is why `end`, still on the synchronous call stack, prints before `B: after await`, deferred to the microtask queue, even though `asyncOrder()` was called before the final `console.log('end')` in the source.

> **Remember:** everything before an `await` runs synchronously. Everything after it is a microtask, scheduled to run once the current synchronous code finishes.
