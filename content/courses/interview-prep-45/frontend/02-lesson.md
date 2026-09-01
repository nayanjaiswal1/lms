---
kind: lesson
id_key: interview-prep-45/day-02-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "React Hooks Internals"
position: 5
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Anyone can call `useState`. What separates a mid-level candidate from a senior one is being able to explain *how* it works, where the state actually lives, why the Rules of Hooks exist, and why breaking them corrupts state silently instead of throwing. Today builds simplified versions of `useState` and `useEffect` so the internals stop being magic.

## How useState updates trigger re-renders

State does not live "in" your component function. Your component function is called fresh on every render, so any local variable in it is discarded and recreated each time. State actually lives in the **Fiber node**, React's internal per-component data structure, as a linked list of hook entries.

The sequence:

1. React calls your component function. It reads the next hook slot in the fiber's hook list, in call order, and returns its stored value.
2. You call the setter with a new value. React stores the pending update and schedules a re-render for that fiber (and marks it dirty up to the root, but reconciliation confines actual DOM writes to what changed).
3. On the scheduled render, React calls your function again. `useState` reads the *same* hook slot, now updated, and returns the new value.

```tsx
// Simplified mental model of what React does internally.
// This is NOT real React source — it's a teaching approximation.

let hooks: any[] = [];
let currentHookIndex = 0;
let rerenderScheduled = false;

function useStateSimplified<T>(initialValue: T): [T, (newValue: T | ((prev: T) => T)) => void] {
  const hookIndex = currentHookIndex;
  hooks[hookIndex] = hooks[hookIndex] ?? initialValue;

  const setState = (newValue: T | ((prev: T) => T)) => {
    hooks[hookIndex] =
      typeof newValue === 'function'
        ? (newValue as (prev: T) => T)(hooks[hookIndex])
        : newValue;
    scheduleRerender(); // tells React "this fiber is dirty, re-render it"
  };

  currentHookIndex++;
  return [hooks[hookIndex], setState];
}

function scheduleRerender() {
  if (rerenderScheduled) return;
  rerenderScheduled = true;
  queueMicrotask(() => {
    rerenderScheduled = false;
    currentHookIndex = 0; // reset so the next render reads hooks in the same order
    renderApp();
  });
}
```

The key insight: `hooks[hookIndex]` persists across calls because it lives outside the function that gets re-invoked. Real React stores this per-fiber, not in one global array, but the "index into a persistent list" model is exactly right.

**Interview question: "Does calling the setter with the same value still re-render?"**
In React 18, yes for class-style comparisons in some paths, but function-component `useState` with `Object.is`-equal values bails out of re-rendering that component (it still runs the function once to check, then skips the commit). Know that `Object.is` is the comparison, not `===` (this matters for `NaN` and `-0`).

## How useEffect handles dependencies

`useEffect` also gets a slot in the fiber's hook list, storing two things: the effect function and the last dependency array. After every commit, React compares the new dependency array to the stored one, element by element with `Object.is`. If any element differs (or there was no previous array), the old cleanup runs, then the new effect runs.

```tsx
function useEffectSimplified(effect: () => void | (() => void), deps?: unknown[]) {
  const hookIndex = currentHookIndex;
  const prevDeps = hooks[hookIndex]?.deps;
  const hasChanged =
    !prevDeps || !deps || deps.some((dep, i) => !Object.is(dep, prevDeps[i]));

  if (hasChanged) {
    // schedule effect to run after this commit, not synchronously
    scheduleEffect(() => {
      hooks[hookIndex]?.cleanup?.();
      const cleanup = effect();
      hooks[hookIndex] = { deps, cleanup };
    });
  }

  currentHookIndex++;
}
```

The three dependency-array shapes and what they mean:

```tsx
useEffect(() => { /* ... */ });           // no array: runs after EVERY render
useEffect(() => { /* ... */ }, []);        // empty array: runs once, after first commit
useEffect(() => { /* ... */ }, [userId]);  // runs when userId changes (Object.is)
```

## Build: useState from scratch (runnable version)

A self-contained version you can actually execute outside React to see the mechanism, with a real cleanup-capable `useEffect` alongside it:

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
      if (!Object.is(state[i], next)) {
        state[i] = next;
        rerender();
      }
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

  function rerender() {
    stateIndex = 0;
    effectIndex = 0;
    renderFn();
  }

  function mount(fn: () => void) {
    renderFn = fn;
    rerender();
  }

  return { useState, useEffect, mount };
}

// Usage:
const { useState, useEffect, mount } = createHookSystem();

function App() {
  const [seconds, setSeconds] = useState(0);

  useEffect(() => {
    const id = setInterval(() => setSeconds(s => s + 1), 1000);
    return () => clearInterval(id); // cleanup — runs before the next effect and on unmount
  }, []); // empty deps: subscribe once

  console.log('seconds:', seconds);
}

mount(App);
```

## Why hooks can't be conditional

Hooks are read by **positional index**, not by name. React has no idea your third `useState` call is "the username state"; it only knows "slot 3 in this fiber's hook list." If a hook call is skipped on some renders (inside an `if`, a loop, or after an early `return`), every hook after it shifts down one slot, and React reads the wrong stored value into the wrong hook.

```tsx
// BROKEN — do not do this
function Broken({ showExtra }: { showExtra: boolean }) {
  const [name, setName] = useState('a');
  if (showExtra) {
    const [extra, setExtra] = useState('b'); // hook 2 only exists sometimes
  }
  const [age, setAge] = useState(0); // this is hook slot 2 OR 3 depending on showExtra!
  // ...
}
```

When `showExtra` flips between renders, `age`'s slot index changes, so React hands it `extra`'s stored value instead. This is exactly why the ESLint rule `react-hooks/rules-of-hooks` exists and should never be disabled: the bug it prevents is silent state corruption, not a crash you'd catch in testing.

The fix is always to keep the hook call unconditional and push the condition *inside* the hook:

```tsx
function Fixed({ showExtra }: { showExtra: boolean }) {
  const [name, setName] = useState('a');
  const [extra, setExtra] = useState('b'); // always called
  const [age, setAge] = useState(0);

  const displayExtra = showExtra ? extra : null; // condition applied to the VALUE, not the call
  // ...
}
```
