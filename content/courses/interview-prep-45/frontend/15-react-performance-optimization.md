---
kind: lesson
id_key: interview-prep-45/day-05-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "React Performance Optimization"
position: 15
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
"How would you optimize a slow React app?" is a near-guaranteed senior-level question, and "wrap everything in `useMemo`" is the wrong answer. This lesson covers `React.memo`, `useMemo`, and `useCallback` correctly, including the real cost of memoization, the part most candidates skip entirely, plus how to actually measure before you optimize anything at all.

## When memoization is worth reaching for

From the rendering lesson: a parent re-rendering re-renders every child by default, and re-rendering a function component just means calling the function again to produce a new VDOM subtree, which reconciliation then diffs. For cheap components that's essentially free, diffing a `<span>` costs nanoseconds. Memoization only pays off when re-rendering is measurably expensive: large lists, heavy computation inside the render body, or a component with an expensive subtree whose props are stable most of the time.

`React.memo` skips re-rendering a component if its props are shallowly equal to last time:

```tsx
type RowProps = { id: string; label: string; onSelect: (id: string) => void };
const ExpensiveRow = React.memo(function ExpensiveRow({ id, label, onSelect }: RowProps) {
  console.log('rendering row', id);
  return <div onClick={() => onSelect(id)}>{label}</div>;
});
```

`React.memo` does a shallow `Object.is` comparison per prop, which is exactly why it silently does nothing in the most common real scenario: an inline arrow function or object literal passed as a prop is a *new reference every render*, so the shallow comparison reports "changed" every single time and `memo` never actually skips anything.

```tsx
function ParentBroken() {
  const [count, setCount] = useState(0);
  // New function reference every render → ExpensiveRow's memo check always fails
  return <ExpensiveRow id="1" label="Row" onSelect={(id) => console.log(id)} />;
}
```

`useMemo` caches the *result* of a computation between renders, recomputing only when its dependency array changes:

```tsx
function ProductList({ products, filterText }: { products: Product[]; filterText: string }) {
  const filtered = useMemo(
    () => products.filter(p => p.name.toLowerCase().includes(filterText.toLowerCase())),
    [products, filterText],
  );
  return <ul>{filtered.map(p => <li key={p.id}>{p.name}</li>)}</ul>;
}
```

`useCallback` caches a *function reference* between renders, so passing it as a prop doesn't defeat a child's `React.memo`. It's `useMemo` specialized for functions: `useCallback(fn, deps)` is exactly `useMemo(() => fn, deps)`.

```tsx
function ParentFixed() {
  const handleSelect = useCallback((id: string) => { console.log('selected', id); }, []);
  return <ExpensiveRow id="1" label="Row" onSelect={handleSelect} />;
  // Now ExpensiveRow's React.memo check actually passes when unrelated state changes elsewhere
}
```

The rule of thumb worth internalizing: `useMemo`/`useCallback` on a value only pays off if the component receiving it is *also* wrapped in `React.memo`, or the value feeds into another hook's dependency array. Memoizing a callback passed to a plain, non-memoized child changes nothing, that child re-renders regardless of whether the reference is stable.

## Memoization isn't free

This is what senior-level interviews are actually probing for. Every memoized value or function stays alive between renders, holding references to whatever its closure captured, real memory pressure at scale across thousands of memoized rows. `useMemo`/`useCallback`/`React.memo` all pay a comparison cost on every render too, dependency-array diffing or shallow prop comparison, and for a genuinely cheap computation, that comparison can cost more than just redoing the work would have. There's a maintenance cost as well: a wrong or incomplete dependency array is a correctness bug, a stale closure, not just a missed optimization. `useMemo(() => expensive(a, b), [a])` silently keeps using a stale `b` forever the moment `b` changes without `a` changing alongside it.

```tsx
// Don't: memoizing a cheap string concat costs more than it saves
const fullName = useMemo(() => `${firstName} ${lastName}`, [firstName, lastName]);
// Just do this
const fullName = `${firstName} ${lastName}`;
```

Should every component be wrapped in `React.memo` by default? No. `React.memo` on a component whose props change on nearly every render, or that's cheap to render regardless, adds a wasted comparison on top of the render you were trying to avoid. Reach for it when profiling shows a specific component re-rendering expensively with otherwise-stable props, not as a preemptive habit.

## Measuring before you touch anything

Don't guess. Two tools, the same underlying idea: record renders, see what's actually slow.

The **React DevTools Profiler tab** records a session as you interact with the app, and shows a flamegraph per commit, each bar a component, width equal to render time, with a "why did this render?" breakdown of exactly which prop, state, or context changed. It's the fastest way to confirm a suspected unnecessary re-render before you reach for `memo` at all.

The **`React.Profiler` component** does the same thing programmatically, and works in production too:

```tsx
import { Profiler, type ProfilerOnRenderCallback } from 'react';

const onRender: ProfilerOnRenderCallback = (id, phase, actualDuration) => {
  if (actualDuration > 16) { // longer than one 60fps frame budget
    console.warn(`${id} took ${actualDuration.toFixed(2)}ms during ${phase}`);
  }
};

function App() {
  return (
    <Profiler id="ProductList" onRender={onRender}>
      <ProductList products={products} filterText={filterText} />
    </Profiler>
  );
}
```

The **Chrome DevTools Performance tab** records everything on the page, JS execution, layout, paint, garbage collection, not just React, which is where to look when the bottleneck might not be React at all, a synchronous `JSON.parse` of a huge payload, or the layout-thrashing pattern from earlier in this course. Look for long yellow (scripting) or purple (rendering) bars, and check the "Bottom-Up" tab to find which function actually consumed the time, not just which one happened to be on top of the call stack when the recording captured it.

The workflow that reads as a strong answer to "how would you optimize a slow app": profile first, identify the specific expensive component or computation, apply the narrowest targeted fix, `memo`, `useMemo`, `useCallback`, virtualization, code splitting, then profile again to confirm the fix actually helped. Optimizing without measuring first is the wrong answer even in the cases where the fix happens to work anyway.
