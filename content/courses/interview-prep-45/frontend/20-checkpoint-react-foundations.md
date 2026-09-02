---
kind: lesson
id_key: interview-prep-45/day-07-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Checkpoint: React Foundations"
position: 20
estimated_minutes: 18
source:
    - 45-day-interview-roadmap.md
---
No new material today: a consolidation pass over React's core model, rendering, hooks, performance, state, state machines, and composition patterns. Interviewers rarely ask about one of these in isolation; they chain them ("your list re-renders on every keystroke, walk me through why, then fix it"). Use this review to move between them without losing the thread before the course turns to networking and tooling next.

## Rendering and reconciliation

React keeps a virtual DOM, a cheap plain-object tree, and diffs it against the previous render to compute the minimal real-DOM mutation. A component re-renders when its own state changes, its parent re-renders, a context it reads changes, or a hook forces an update. Re-render (calling the function, render phase) is not the same as the DOM changing (commit phase). Reconciliation matches elements by type and by `key`; a changed type tears the subtree down and rebuilds it, a missing `key` falls back to matching by index, which misattributes state the moment a list reorders.

**Say this out loud, unprompted, if asked "why did this re-render":** check in order, did props change by reference, did local state change, did a consumed context change, did the parent re-render unconditionally and cascade down.

## Hooks internals

Hook state lives on the fiber, addressed by call-order index, not by name, which is exactly why hooks can't be conditional: skip a call on some renders and every hook after it reads the wrong slot. `useState`'s setter bails out of re-rendering on an `Object.is`-equal value. `useEffect` diffs its dependency array with `Object.is` per element after commit; no array means every render, an empty array means once, and cleanup runs before the next effect and on unmount.

**Say this out loud, unprompted, if asked "why is my effect stuck in a loop":** check the dependency array first, an object, array, or function literal recreated every render as a dependency is never `Object.is`-equal to itself, which produces an infinite effect loop; a missing dependency produces a stale closure instead.

## Performance

`React.memo` skips a re-render on shallow-equal props, and does nothing at all if a parent passes a new object, array, or function literal every render, pair it with `useMemo`/`useCallback` on the parent for exactly those values. Memoization isn't free: it costs memory to hold onto and a comparison on every render to check, profile before reaching for it rather than applying it by default. The workflow that reads well in an interview: profile, identify the specific expensive component, apply the narrowest fix, profile again to confirm it helped.

**Say this out loud, unprompted, if asked "should you wrap every component in memo":** no, only when profiling shows a specific component re-rendering expensively with otherwise-stable props; a blanket habit adds a wasted comparison on top of renders that were already cheap.

## State management and state machines

Default to the narrowest scope: local `useState`/`useReducer`, then lift to a common parent, then Context for rarely-changing cross-cutting values like theme or auth, then an external store for frequent, complex, cross-cutting state, because it gives selective subscriptions Context structurally can't. A store is state, a pure reducer, a subscriber set, and a dispatch that runs the reducer and notifies subscribers; `useSyncExternalStore` is the React-correct way to subscribe to one. Always produce new object or array references on update. For state with a genuinely finite set of valid combinations, loading/success/error, a multi-step form, model it as an explicit transition table instead of independent booleans, so invalid combinations are unrepresentable rather than merely avoided by convention.

**Say this out loud, unprompted, if asked "when would you NOT use Redux":** small or medium app, state is mostly local or server-cached (reach for a query library instead of hand-rolling that), or the only cross-cutting need is a rarely-changing value, Context is enough and Redux's ceremony isn't worth paying for.

## Composition patterns

Custom hooks are the default way to share stateful logic, no wrapping component, no change to the tree shape. Compound components share implicit state through context for a fixed family of children (tabs, accordion); render props and HOCs mostly predate hooks and survive today for specific cases, a library exposing behavior to non-hook consumers, or wrapping a third-party component you can't add a hook to.

**Say this out loud, unprompted, if asked to fix a stale closure inside setInterval:** switch to the functional update form of the setter, `setState(prev => ...)`, so every tick reads current state instead of whatever was captured when the effect first ran, and confirm the interval is cleared in the effect's cleanup function.

## Self-test — answer without looking back

1. A parent component re-renders. Does its memoized child (`React.memo`) definitely skip re-rendering? Why or why not?
2. You call `useState`'s setter with the exact same object reference it already holds. Does the component re-render?
3. A `<Toggle>` shows or hides a `<Sidebar>` used by exactly one parent. Local state, Context, or Redux, and why?
4. A `useFetch(url)` hook re-fetches every time `url` changes. What specifically prevents a slow response for an old `url` from overwriting a faster response for a newer one?
5. Design the state shape for a checkout flow with shipping, payment, and review steps, where a failed submission must return the user to review, not a dead end.
6. A component built with `withAuth(withTheme(withLogging(Component)))` is hard to debug in DevTools. What's the underlying problem, and what's the modern replacement?
