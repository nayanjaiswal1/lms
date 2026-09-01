---
kind: lesson
id_key: interview-prep-45/day-07-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Checkpoint 1"
position: 10
estimated_minutes: 18
source:
    - 45-day-interview-roadmap.md
---
No new material today: this is a consolidation pass over Days 1-4 (React rendering, hooks internals, the event loop, and state management). Interviewers rarely ask about one topic in isolation; they chain them ("your list re-renders on every keystroke, walk me through why, then fix it"). Use this review to make sure you can move between these four topics without losing the thread.

## React rendering: the one-paragraph version

React keeps a virtual DOM (cheap plain-object tree) and diffs it against the previous render to compute the minimal real-DOM mutation. A component re-renders when its own state changes, its parent re-renders, a context it reads changes, or a hook forces an update. "Re-render" (calling the function, render phase) is not the same as "DOM changes" (commit phase). Class lifecycle (`componentDidMount`/`Update`/`WillUnmount`) maps onto `useEffect` with empty/populated/cleanup semantics, except `componentDidCatch` has no hook equivalent.

**Say this out loud, unprompted, if asked "why did this re-render":** check in order: did props change (reference equality), did local state change, did a consumed context change, did the parent re-render unconditionally cascading down.

## React hooks: the one-paragraph version

Hook state lives on the fiber, addressed by call-order index, not by name. That's exactly why hooks can't be conditional: skip a hook call on some renders and every subsequent hook reads the wrong slot. `useState`'s setter bails out of re-rendering on an `Object.is`-equal value. `useEffect` diffs its dependency array with `Object.is` per element after commit; no array means every render, empty array means once, cleanup runs before the next effect and on unmount.

**Say this out loud, unprompted, if asked "why is my effect running twice" or "stuck in a loop":** check the dependency array first: an object/array/function literal recreated every render as a dependency will never be `Object.is`-equal to itself, causing an infinite effect loop; missing a dependency causes a stale closure instead.

## Event loop: the one-paragraph version

One call stack. After it empties, the event loop drains the *entire* microtask queue (Promises, `queueMicrotask`, async/await continuations) before running the next macrotask (`setTimeout`, UI events), regardless of `setTimeout`'s delay value. `requestAnimationFrame` runs right before paint, synced to refresh rate; the render pipeline is Style → Layout → Paint → Composite, and `transform`/`opacity` are composite-only (GPU, skip layout+paint), which is why they're the only properties safe to animate at 60fps.

**Say this out loud, unprompted, if asked to predict console.log order:** identify sync code first (runs immediately, in order), then all microtasks (in queue order, including ones queued by other microtasks during the drain), then macrotasks last.

## State management: the one-paragraph version

Default to the narrowest scope: local `useState`/`useReducer` → lift to common parent → Context (for rarely-changing, cross-cutting values like theme/auth) → external store (Redux/Zustand, for frequent/complex/cross-cutting state, because it gives selective subscriptions Context can't). A store is just: state + pure reducer + subscriber set + dispatch that runs the reducer and notifies subscribers. `useSyncExternalStore` is the React-correct way to subscribe to one. Always produce new object/array references on update (React/Redux use reference equality), and normalize deeply nested duplicated entities into flat `byId`/`allIds` tables.

**Say this out loud, unprompted, if asked "when would you NOT use Redux":** small/medium app, state is mostly local or server-cached (reach for React Query/SWR instead of hand-rolling), or the only cross-cutting need is a rarely-changing value: Context is enough and Redux's ceremony isn't worth it.

## Self-test — answer without looking back

Work through these as if in a live interview, out loud, before checking your notes:

1. A parent component re-renders. Does its memoized child (`React.memo`) definitely skip re-rendering? Why or why not?
2. You call `useState`'s setter with the exact same object reference it already holds. Does the component re-render?
3. Write the console.log output order for: a sync `console.log`, then `setTimeout(fn, 0)`, then `Promise.resolve().then(fn)`, then another sync `console.log`.
4. Why does animating `top`/`left` cost more than animating `transform`, in terms of the render pipeline?
5. You have a `<Toggle>` component whose visibility should show/hide a `<Sidebar>` used by exactly one parent. Local state, Context, or Redux, and why?
6. A reducer does `state.items.push(newItem); return state;` instead of returning a new array. What breaks, and why does React/Redux not catch it as an error?
