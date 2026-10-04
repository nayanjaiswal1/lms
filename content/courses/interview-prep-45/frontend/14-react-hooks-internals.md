---
kind: lesson
id_key: interview-prep-45/day-02-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "React Hooks Internals"
position: 14
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Anyone can call `useState`. What separates a mid-level candidate from a senior one is being able to explain *how* it works, where the state actually lives, why the Rules of Hooks exist, and why breaking them corrupts state silently instead of throwing a helpful error. This lesson builds simplified versions of `useState` and `useEffect` so the internals stop being magic.

## Where state actually lives

State does not live "in" your component function. Your function gets called fresh on every render, so any local variable inside it is discarded and recreated each time. State actually lives on the **Fiber node**, React's internal per-component data structure, as a linked list of hook entries. Picture a numbered coat check: your component hands over its state each render and gets a numbered ticket back, always the same ticket for the same hook call, so it always retrieves the same coat.

The sequence: React calls your component function, reads the next hook slot in the fiber's hook list, in call order, and returns whatever's stored there. You call the setter with a new value; React stores the pending update and schedules a re-render for that fiber. On the scheduled render, React calls your function again, and `useState` reads the *same* hook slot, now updated, and hands back the new value.

```tsx
// A teaching approximation, not real React source.
let hooks: any[] = [];
let currentHookIndex = 0;

function useStateSimplified<T>(initialValue: T): [T, (v: T | ((prev: T) => T)) => void] {
  const hookIndex = currentHookIndex;
  hooks[hookIndex] = hooks[hookIndex] ?? initialValue;

  const setState = (newValue: T | ((prev: T) => T)) => {
    hooks[hookIndex] = typeof newValue === 'function' ? (newValue as (prev: T) => T)(hooks[hookIndex]) : newValue;
    scheduleRerender();
  };

  currentHookIndex++;
  return [hooks[hookIndex], setState];
}

function scheduleRerender() {
  queueMicrotask(() => {
    currentHookIndex = 0; // reset so the next render reads hooks back in the same order
    renderApp();
  });
}
```

The key insight is that `hooks[hookIndex]` persists across calls, because it lives outside the function that gets re-invoked each time. Real React stores this per-fiber rather than in one global array, but "index into a persistent list" is exactly the right model. Does calling the setter with the same value still trigger a re-render? In React 18+, function-component `useState` bails out of re-rendering when the new value is `Object.is`-equal to the current one; it still calls the function once to check, then skips the commit if nothing changed. Note it's `Object.is`, not `===`, which matters for `NaN` and `-0`.

> **Remember:** state lives on the fiber, addressed by call-order index, not inside your function. Your function is discarded and rebuilt every render.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-hookstate-q1", "type": "mcq",
      "prompt": "You call `useState`'s setter with the exact same object reference it already holds. Does the component re-render?",
      "options": [
        {"id":"a","text":"Yes, calling any setter always re-renders"},
        {"id":"b","text":"No — React 18+ bails out of re-rendering when the new value is Object.is-equal to the current one"},
        {"id":"c","text":"Only if the component has no other state"},
        {"id":"d","text":"It throws an error"}
      ],
      "correct": "b",
      "explanation": "React still calls the function once to check, then skips the commit if the new value is Object.is-equal to the stored one. Passing back the identical reference is exactly that case." }
] }
```

## How useEffect tracks its dependency array

`useEffect` also claims a slot in the fiber's hook list, storing both the effect function and the last dependency array. After every commit, React compares the new array to the stored one, element by element, with `Object.is`. If any element differs, or there was no previous array at all, the old cleanup runs first, then the new effect runs.

```tsx
function useEffectSimplified(effect: () => void | (() => void), deps?: unknown[]) {
  const hookIndex = currentHookIndex;
  const prevDeps = hooks[hookIndex]?.deps;
  const hasChanged = !prevDeps || !deps || deps.some((dep, i) => !Object.is(dep, prevDeps[i]));

  if (hasChanged) {
    scheduleEffect(() => {
      hooks[hookIndex]?.cleanup?.();
      const cleanup = effect();
      hooks[hookIndex] = { deps, cleanup };
    });
  }
  currentHookIndex++;
}
```

The three shapes of dependency array mean three different things: no array at all runs the effect after *every* render; an empty array runs it once, after the first commit; a populated array runs it whenever any listed value changes, by `Object.is`.

```tsx
useEffect(() => { /* ... */ });           // every render
useEffect(() => { /* ... */ }, []);        // once, after first commit
useEffect(() => { /* ... */ }, [userId]);  // whenever userId changes
```

> **Remember:** `useEffect` compares its dependency array element by element with `Object.is` after every commit. Any difference reruns the effect.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-effectdeps-q1", "type": "mcq",
      "prompt": "`useEffect(() => { subscribe(); }, [config])` where `config` is a new object literal created on every render, `{ retries: 3 }`. What happens?",
      "options": [
        {"id":"a","text":"The effect runs once, since the object's contents never change"},
        {"id":"b","text":"The effect reruns on every render, since a new object literal is never Object.is-equal to the previous render's object, even with identical contents"},
        {"id":"c","text":"React throws an error for object dependencies"},
        {"id":"d","text":"The effect never runs at all"}
      ],
      "correct": "b",
      "explanation": "Object.is compares by reference for objects, not by contents. A fresh object literal every render is a fresh reference every render, so the dependency always looks 'changed,' even if nothing meaningful actually did." }
] }
```

## The dependency array is about correctness, not performance

The array's real job is telling React when the closure's captured values have gone stale, not tuning how often something runs.

```tsx
// WRONG: missing dependency, stale closure over `userId`
useEffect(() => {
  fetchUser(userId).then(setUser);
}, []); // eslint would flag this

// RIGHT: effect re-runs whenever userId changes, no stale data
useEffect(() => {
  let cancelled = false;
  fetchUser(userId).then((u) => { if (!cancelled) setUser(u); });
  return () => { cancelled = true; }; // cleanup avoids setting state after unmount
}, [userId]);
```

The wrong version keeps calling `fetchUser` with whatever `userId` was on the very first render, forever, because the closure captured that value once and the empty array tells React never to re-run and capture a fresh one. The fix is not "add a comment explaining the omission," it is including `userId` in the array so the effect actually sees the current value. The `cancelled` flag in the fixed version solves a separate, related problem: if `userId` changes again before the first fetch resolves, or the component unmounts, that stale response is not allowed to call `setUser` after the fact.

> **Remember:** a missing dependency is a stale-data bug, not a missed performance tweak. The array tells React when a closure has gone stale.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-effectcorrectness-q1", "type": "mcq",
      "prompt": "`useEffect(() => { fetchUser(userId).then(setUser); }, [])`, where `userId` is a prop that can change. What's the bug?",
      "options": [
        {"id":"a","text":"There is no bug, this is a valid performance optimization"},
        {"id":"b","text":"The effect only runs once and its closure permanently captures the first render's userId, so it keeps fetching the original user even after userId changes"},
        {"id":"c","text":"useEffect requires at least one dependency or it throws"},
        {"id":"d","text":"fetchUser needs to be memoized with useCallback"}
      ],
      "correct": "b",
      "explanation": "An empty dependency array means the effect runs once and never again, so its closure is frozen at that first render's values. Any later change to userId is invisible to it. Adding userId to the array is the fix, not a memoization trick." }
] }
```

## A version you can actually run

```tsx
type EffectRecord = { deps?: unknown[]; cleanup?: (() => void) | void };

function createHookSystem() {
  let state: unknown[] = [];
  let effects: EffectRecord[] = [];
  let stateIndex = 0;
  let effectIndex = 0;
  let renderFn: () => void = () => {};

  function useState<T>(initial: T): [T, (v: T | ((p: T) => T)) => void] {
    const i = stateIndex++;
    if (state[i] === undefined) state[i] = initial;
    const setValue = (v: T | ((p: T) => T)) => {
      const next = typeof v === 'function' ? (v as (p: T) => T)(state[i] as T) : v;
      if (!Object.is(state[i], next)) { state[i] = next; rerender(); }
    };
    return [state[i] as T, setValue];
  }

  function useEffect(effect: () => void | (() => void), deps?: unknown[]) {
    const i = effectIndex++;
    const prev = effects[i];
    const changed = !prev || !deps || deps.some((d, idx) => !Object.is(d, prev.deps?.[idx]));
    if (changed) {
      queueMicrotask(() => {
        if (typeof prev?.cleanup === 'function') prev.cleanup();
        const cleanup = effect();
        effects[i] = { deps, cleanup };
      });
    } else {
      effects[i] = prev;
    }
  }

  function rerender() { stateIndex = 0; effectIndex = 0; renderFn(); }
  function mount(fn: () => void) { renderFn = fn; rerender(); }
  return { useState, useEffect, mount };
}

const { useState, useEffect, mount } = createHookSystem();
function App() {
  const [seconds, setSeconds] = useState(0);
  useEffect(() => {
    const id = setInterval(() => setSeconds(s => s + 1), 1000);
    return () => clearInterval(id); // runs before the next effect, and on unmount
  }, []); // empty deps: subscribe once
  console.log('seconds:', seconds);
}
mount(App);
```

## Why hooks can't be conditional

Hooks are read by **positional index**, never by name. React has no idea your third `useState` call is "the username state," it only knows "slot 3 in this fiber's hook list." If a hook call gets skipped on some renders, inside an `if`, a loop, or after an early `return`, every hook after it shifts down one slot, and React reads the wrong stored value into the wrong hook.

```tsx
// BROKEN — do not do this
function Broken({ showExtra }: { showExtra: boolean }) {
  const [name, setName] = useState('a');
  if (showExtra) {
    const [extra, setExtra] = useState('b'); // hook 2 only exists sometimes
  }
  const [age, setAge] = useState(0); // this is hook slot 2 OR 3 depending on showExtra!
}
```

When `showExtra` flips between renders, `age`'s slot index shifts with it, so React hands it whatever value `extra` had stored instead. This is exactly why the ESLint rule `react-hooks/rules-of-hooks` exists and should never be disabled: the bug it prevents is silent state corruption, not a crash you'd catch in normal testing. The fix is always to keep every hook call unconditional and push the condition *inside* the hook instead:

```tsx
function Fixed({ showExtra }: { showExtra: boolean }) {
  const [name, setName] = useState('a');
  const [extra, setExtra] = useState('b'); // always called
  const [age, setAge] = useState(0);
  const displayExtra = showExtra ? extra : null; // condition applied to the VALUE, not the call
}
```

> **Remember:** hooks are read by call-order index, never by name. Skip a call on some renders, and every hook after it silently shifts to the wrong slot.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-hooksrules-q1", "type": "mcq",
      "prompt": "Why does putting a `useState` call inside an `if` block cause silent state corruption instead of a clear error?",
      "options": [
        {"id":"a","text":"React always throws a clear error for this, it never fails silently"},
        {"id":"b","text":"Hooks are addressed by call-order index on the fiber, not by name, so skipping a call on some renders shifts every subsequent hook's slot index, causing them to read each other's stored values"},
        {"id":"c","text":"if statements are not allowed anywhere in a component function"},
        {"id":"d","text":"useState can only be called once per component, regardless of placement"}
      ],
      "correct": "b",
      "explanation": "Since hooks have no names to React, only slot positions, a conditionally-skipped hook shifts the index of every hook that follows it, so they silently read whatever value happens to sit in the wrong slot." }
] }
```
