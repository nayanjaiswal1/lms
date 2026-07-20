---
kind: lesson
id_key: interview-prep-45/day-05-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Day 5 — React Performance Optimization"
position: 8
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
"How would you optimize a slow React app?" is a near-guaranteed senior-level question, and the wrong answer is "wrap everything in `useMemo`." Today covers `React.memo`, `useMemo`, and `useCallback` correctly — including the real cost of memoization, which is the part most candidates skip — plus how to actually measure before you optimize.

## When to use memoization

Building on Day 1: a parent re-rendering re-renders every child by default, and re-rendering a function component means calling the function again to produce a new VDOM subtree, which reconciliation then diffs. For cheap components, that's fine — diffing a `<span>` is nanoseconds. Memoization only pays off when re-rendering is measurably expensive: large lists, heavy computation in the render body, or a component with an expensive subtree that has stable props most of the time.

**`React.memo`** — skips re-rendering a component if its props are shallowly equal to last time:

```tsx
type RowProps = { id: string; label: string; onSelect: (id: string) => void };

const ExpensiveRow = React.memo(function ExpensiveRow({ id, label, onSelect }: RowProps) {
  console.log('rendering row', id);
  return <div onClick={() => onSelect(id)}>{label}</div>;
});
```

`React.memo` does a shallow comparison (`Object.is` on each prop). This is exactly why it fails silently in the most common real case: an inline arrow function or object literal passed as a prop is a *new reference every render*, so the shallow comparison always reports "changed" and `memo` never actually skips anything.

```tsx
function ParentBroken() {
  const [count, setCount] = useState(0);
  // New function reference every render -> ExpensiveRow's memo check always fails
  return <ExpensiveRow id="1" label="Row" onSelect={(id) => console.log(id)} />;
}
```

**`useMemo`** — caches the *result* of an expensive computation between renders, recomputing only when its dependency array changes:

```tsx
function ProductList({ products, filterText }: { products: Product[]; filterText: string }) {
  const filtered = useMemo(
    () => products.filter(p => p.name.toLowerCase().includes(filterText.toLowerCase())),
    [products, filterText], // only recompute when these change
  );
  return <ul>{filtered.map(p => <li key={p.id}>{p.name}</li>)}</ul>;
}
```

**`useCallback`** — caches a *function reference* between renders, so passing it as a prop doesn't break a child's `React.memo`. It's `useMemo` specialized for functions: `useCallback(fn, deps)` === `useMemo(() => fn, deps)`.

```tsx
function ParentFixed() {
  const [count, setCount] = useState(0);

  const handleSelect = useCallback((id: string) => {
    console.log('selected', id);
  }, []); // stable reference across renders — empty deps because it captures nothing that changes

  return <ExpensiveRow id="1" label="Row" onSelect={handleSelect} />;
  // Now ExpensiveRow's React.memo check actually passes when count changes elsewhere
}
```

The rule of thumb: `useMemo`/`useCallback` on a prop is only useful if the receiving component is *also* wrapped in `React.memo` (or the value feeds into another hook's dependency array). Memoizing a callback passed to a plain, non-memoized child does nothing — that child re-renders regardless.

## Cost of memoization

This is the part interviews actually probe for at senior level: memoization is not free.

- **Memory**: every memoized value/function is kept alive between renders, holding references to its closure's captured variables. At scale (thousands of memoized rows), this is real memory pressure.
- **Comparison cost**: `useMemo`/`useCallback`/`React.memo` all pay a comparison cost every render (dependency array diffing, or shallow prop comparison). For a cheap computation, the comparison can cost more than just redoing the work.
- **Cognitive/maintenance cost**: a wrong or incomplete dependency array is a correctness bug (stale closures), not just a missed optimization. `useMemo(() => expensive(a, b), [a])` silently uses a stale `b` forever if `b` changes without `a` changing.

```tsx
// Don't do this — memoizing a cheap string concat costs more than it saves
const fullName = useMemo(() => `${firstName} ${lastName}`, [firstName, lastName]);

// Just do this
const fullName = `${firstName} ${lastName}`;
```

**Interview question: "Should you wrap every component in React.memo by default?"**
No. `React.memo` on a component whose props change on almost every render (or that's cheap to render anyway) adds a wasted comparison on top of the render you were trying to avoid. Reach for it when profiling shows a specific component re-rendering expensively with stable props — not preemptively.

## DevTools performance tab and Profiler API

Don't guess — measure. Two tools, same underlying idea (record renders, see what's slow):

**React DevTools Profiler tab** (browser extension): record a session, interact with the app, stop recording. It shows a flamegraph per commit — each bar is a component, width is render time, and you can click "why did this render?" to see exactly which prop/state/context changed. This is the fastest way to confirm a suspected unnecessary re-render before reaching for `memo`.

**`React.Profiler` component** (programmatic, works in production too):

```tsx
import { Profiler, type ProfilerOnRenderCallback } from 'react';

const onRender: ProfilerOnRenderCallback = (
  id,             // the Profiler tree's id prop
  phase,          // "mount" | "update" | "nested-update"
  actualDuration, // time spent rendering this commit
  baseDuration,   // estimated time to render the WHOLE subtree without memoization
  startTime,
  commitTime,
) => {
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

**Chrome DevTools Performance tab**: records everything — JS execution, layout, paint, GC — across the whole page, not just React. Use it when the bottleneck might not be React at all (e.g., a synchronous `JSON.parse` of a huge payload, or layout thrashing from Day 3). Look for long yellow (scripting) or purple (rendering) bars, and check the "Bottom-Up" tab to find which function actually consumed the time, not just which one was on top of the call stack when it happened.

The workflow that answers "how would you optimize a slow app" well in an interview: **profile first, identify the specific expensive component/computation, apply the narrowest targeted fix (memo/useMemo/useCallback/virtualization/code-splitting), then profile again to confirm the fix actually helped.** Optimizing without measuring first is the wrong answer even when the fix happens to work.

## Key takeaways

- Re-render (calling the function, cheap for small components) and reconciliation cost are not the enemy by default — only optimize where profiling shows real cost.
- `React.memo` shallow-compares props; inline functions/objects as props defeat it because they're new references every render — pair with `useCallback`/`useMemo` on the parent side.
- `useCallback(fn, deps)` is `useMemo(() => fn, deps)` — memoizing a reference, not a value.
- Memoization has real costs: memory retention, per-render comparison cost, and dependency-array correctness risk (stale closures) — don't apply it by default.
- React DevTools Profiler tab shows per-commit flamegraphs and "why did this render"; `React.Profiler` gives programmatic timing that works in production.
- The correct optimization workflow is profile → identify → targeted fix → profile again, never "wrap it in memo and hope."

## Today's checklist

- [ ] Read the React Profiler API documentation
- [ ] Add `React.memo` to a component and verify it actually skips renders
- [ ] Use `useMemo` and `useCallback` correctly, paired with a memoized child
- [ ] Be able to explain: when to use memoization
- [ ] Be able to explain: the cost of memoization
- [ ] Practice using the DevTools Performance/Profiler tab on a real component
