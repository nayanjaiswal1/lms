---
kind: lesson
id_key: interview-prep-45/day-01-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "React Rendering Fundamentals"
position: 4
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Today is about what actually happens between `setState` and pixels on screen. Nearly every "why did my component re-render twice" or "explain reconciliation" interview question traces back to the concepts here — get the mental model right now and the rest of the React track builds on it cleanly.

## Virtual DOM vs Real DOM

The real DOM is a tree of live browser objects. Every read (`offsetHeight`, `getComputedStyle`) can force a synchronous layout recalculation, and every write can trigger layout, paint, and composite. It's expensive to touch a lot.

The virtual DOM (VDOM) is a plain JavaScript object tree that mirrors what the UI *should* look like. It's cheap to create and diff because it's just objects — no browser work involved.

```tsx
// This JSX...
const element = <h1 className="title">Hello</h1>;

// ...compiles to something like this plain object:
const element = {
  type: 'h1',
  props: {
    className: 'title',
    children: 'Hello',
  },
};
```

React keeps a VDOM tree from the previous render and a new one from the current render, diffs them, and computes the minimal set of real DOM mutations needed. That diff-then-patch step is the whole point: it turns "re-render everything" into "mutate the three nodes that actually changed."

**Interview question: "Is the virtual DOM always faster than direct DOM manipulation?"**
No. A hand-tuned, surgical DOM update can always beat a diff + patch cycle in a synthetic benchmark. The VDOM's real win is developer ergonomics at scale: you write declarative "what the UI looks like now" code, and React figures out the efficient mutation path, so you don't hand-roll DOM diffing for every feature.

## Why React re-renders

A component re-renders when:

1. **Its own state changes** — `setState`/`useState` setter is called with a new value.
2. **Its parent re-renders** — by default, a re-render cascades to every child, regardless of whether that child's props changed.
3. **Context it consumes changes** — any component calling `useContext(SomeContext)` re-renders when that context's value changes.
4. **Hooks it uses force an update** — `useReducer` dispatch, `useSyncExternalStore` emitting a new snapshot, etc.

Critically: **re-render does not mean the DOM changes**. A re-render calls your component function again to produce a new VDOM tree; reconciliation then diffs it against the last tree and only touches the DOM where something actually differs. This distinction — "render phase" (call component functions, build VDOM) vs "commit phase" (apply the diff to the real DOM) — is the backbone of the whole rendering model and of why `React.memo`/`useMemo`/`useCallback` exist (Day 5).

```tsx
function Parent() {
  const [count, setCount] = useState(0);
  return (
    <div>
      <button onClick={() => setCount(c => c + 1)}>{count}</button>
      <ExpensiveChild /> {/* re-renders every time Parent does, even though it takes no props */}
    </div>
  );
}
```

## Reconciliation: how the diff actually works

Reconciliation is the algorithm behind the diff step from the last section — how React decides which minimal DOM mutations to make when it compares the old VDOM tree to the new one. Walking through it precisely is the actual answer to "explain reconciliation," not just naming that it happens.

Full tree diffing (compare every node against every other node) is O(n³) for n elements — too slow to run on every render. React makes the diff tractable with two heuristics that trade some theoretical correctness for speed:

1. **Different element type → tear down and rebuild.** If the root of a subtree changes type (`<div>` becomes `<span>`, or `<Foo>` becomes `<Bar>`), React doesn't try to reconcile the children at all — it unmounts the old subtree (running cleanup effects, `componentWillUnmount`) and mounts a brand new one from scratch. Matching type is a precondition to even start diffing children.
2. **Keys identify stable elements across renders.** For a list of siblings, React needs to know "is this the same logical item, just reordered/updated, or is it new?" Without a `key`, React falls back to matching children by *index* — insert an item at the front of a list and every remaining item is now "at the wrong index," so React diffs (and can throw away local state for) every sibling instead of just the one that actually changed.

```tsx
// Without keys: inserting at the front makes React think
// every row changed, because it matches by position.
{items.map(item => <Row data={item} />)}

// With keys: React matches by identity, so it recognizes
// existing rows and only mounts the genuinely new one.
{items.map(item => <Row key={item.id} data={item} />)}
```

**Fiber (React 16+).** Before Fiber, reconciliation walked the tree recursively and synchronously — once it started, it couldn't stop until the whole tree was diffed, even if that blocked the main thread long enough to drop frames. Fiber restructured each element into a "fiber" object — a unit of work with pointers to its child, sibling, and parent — so the render phase can be paused, resumed, or abandoned mid-tree. This is *why* the render phase is interruptible while the commit phase isn't (the distinction from the section above): once React starts flushing DOM mutations it can't leave the UI half-updated, but the diffing that happens before that can yield to the browser and resume later. That interruptibility is the mechanism underneath `useTransition` and `Suspense` — they mark work as lower priority so Fiber can pause it when something more urgent (a keystroke, a click) comes in.

**Interview question: "What does changing a key on an element actually do?"**
It forces React to treat the old and new elements as unrelated — full unmount of the old instance (losing all local state, running its cleanup effects) followed by a full mount of a "new" one, even though it's the same component function at the same position in the tree. This is a deliberate technique, not just a list requirement: `<Form key={userId} />` resets a form's entire internal state when `userId` changes, in one line, instead of a `useEffect` that manually resets every piece of state.

Two practical gotchas that fall directly out of the heuristics above:

- **Changing a key forces a remount** (see above) — useful intentionally, a bug if it happens by accident (e.g. using array index as a key while reordering the array).
- **Defining a component function inside another component's render body changes its type identity every render.** `type` is compared by reference, and a function declared inside `Parent`'s body is a *new function* — and therefore a *new type* — on every render of `Parent`, even though it "looks like" the same component. Heuristic #1 then applies: React tears down and rebuilds that entire subtree every time, instead of just updating it.

```tsx
function Parent() {
  // New function identity every render -> React unmounts/remounts
  // ChildComponent's entire subtree on every Parent re-render.
  function ChildComponent() {
    return <input />; // loses focus and any local state on every keystroke in Parent
  }
  return <ChildComponent />;
}

// Fix: declare it once, outside Parent, so its type identity is stable.
function ChildComponent() {
  return <input />;
}
function Parent() {
  return <ChildComponent />;
}
```

(Reducing *how often* a matched element re-renders — `React.memo`, `useMemo`, `useCallback` — is Day 5's territory. What's above is reconciliation correctly identifying *which* elements are the same across renders in the first place, a separate concern from whether a matched element bothers re-rendering.)

## Component lifecycle phases

Class components expose lifecycle explicitly; function components achieve the same phases through hooks. Know both — interviewers still ask about class lifecycle because a lot of production code (and every "explain the old API" question) still uses it.

| Phase | Class component | Function component |
|---|---|---|
| Mount | `constructor` → `render` → `componentDidMount` | render body runs → `useEffect(fn, [])` runs after paint |
| Update | `render` → `componentDidUpdate` | render body runs → `useEffect(fn, [deps])` runs if deps changed |
| Unmount | `componentWillUnmount` | cleanup function returned from `useEffect` |
| Error | `componentDidCatch` / `getDerivedStateFromError` | no hook equivalent — still requires a class-based Error Boundary |

```tsx
class Timer extends React.Component<{}, { seconds: number }> {
  interval: number | undefined;
  state = { seconds: 0 };

  componentDidMount() {
    // runs once, after the first render is committed to the DOM
    this.interval = window.setInterval(() => {
      this.setState(prev => ({ seconds: prev.seconds + 1 }));
    }, 1000);
  }

  componentDidUpdate(prevProps: {}, prevState: { seconds: number }) {
    // runs after every re-render caused by a state/prop change
    if (prevState.seconds !== this.state.seconds && this.state.seconds % 10 === 0) {
      console.log('checkpoint:', this.state.seconds);
    }
  }

  componentWillUnmount() {
    // runs once, right before the component is removed from the DOM
    window.clearInterval(this.interval);
  }

  render() {
    return <p>{this.state.seconds}s elapsed</p>;
  }
}
```

Note the render cycle: `constructor` runs once, then `render()` produces the VDOM (no side effects allowed here — it can run multiple times per commit in Strict Mode), then React commits to the DOM, then `componentDidMount` fires. Every subsequent state or prop change re-enters at `render()` and, after commit, calls `componentDidUpdate`.

## Build: a counter that shows its render count

This is the fastest way to *see* re-renders happening instead of reasoning about them abstractly. `useRef` is the right tool here because incrementing it does not itself trigger a re-render (unlike `useState`), so it purely observes without interfering.

```tsx
import { useRef, useState } from 'react';

function RenderCounter() {
  const [count, setCount] = useState(0);
  const renderCount = useRef(0);

  // This line runs on every single call to the component function —
  // i.e. every render, whether or not the DOM ends up changing.
  renderCount.current += 1;
  console.log(`RenderCounter rendered ${renderCount.current} times`);

  return (
    <div>
      <p>Count: {count}</p>
      <p>Renders: {renderCount.current}</p>
      <button onClick={() => setCount(c => c + 1)}>Increment</button>
      <button onClick={() => setCount(c => c)}>
        Set to same value (still re-renders in React 18, bails out of commit in React 19)
      </button>
    </div>
  );
}
```

Click "Increment" and watch the console: each click bumps `renderCount.current` by exactly one, proving each `setCount` call schedules exactly one render for this component (React batches multiple `setState` calls within the same event handler into a single render — try calling `setCount` twice in one handler and confirm the render count still only goes up by one).

## Key takeaways

- The VDOM's value is a cheap-to-diff intermediate representation, not raw speed over hand-written DOM code.
- "Re-render" (calling the component function, render phase) and "DOM update" (commit phase) are different things — a component can re-render with zero DOM changes.
- A parent re-rendering re-renders all its children by default; this is why `React.memo` exists (Day 5).
- Class lifecycle maps onto hooks: mount/update `useEffect(fn, [])`/`useEffect(fn, [deps])`, unmount → cleanup function, but `componentDidCatch` still has no hook equivalent.
- `useRef` is the tool for tracking values (like a render counter) without causing extra renders.
- Reconciliation uses two heuristics — different element type tears down the subtree, keys match list items by identity instead of position — and Fiber (React 16+) makes that diffing interruptible, which is what powers `useTransition`/`Suspense`.
