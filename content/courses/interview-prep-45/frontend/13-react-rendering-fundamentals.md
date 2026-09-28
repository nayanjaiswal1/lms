---
kind: lesson
id_key: interview-prep-45/day-01-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "React Rendering Fundamentals"
position: 13
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
With JavaScript's core mechanics covered, it's time for what actually happens between `setState` and pixels on screen. Nearly every "why did my component re-render twice" or "explain reconciliation" question traces back to what's in this lesson. Get the mental model right here and the rest of the React material builds on it cleanly.

## Virtual DOM versus real DOM

Picture the real DOM as a filing cabinet full of physical folders: opening one, reading it, and refiling it all take real, physical time. The virtual DOM is a photocopy of the filing plan on paper: cheap to sketch, cheap to compare against the previous sketch, and it tells you exactly which physical folders need to change before you touch the cabinet at all.

The real DOM is a tree of live browser objects. Every read (`offsetHeight`, `getComputedStyle`) can force a synchronous layout recalculation, and every write can trigger layout, paint, and composite, the exact pipeline from the rendering-performance lessons. It is expensive to touch a lot.

The virtual DOM is a plain JavaScript object tree mirroring what the UI *should* look like. It is cheap to build and diff because it is just objects, no browser work involved.

```tsx
// This JSX...
const element = <h1 className="title">Hello</h1>;

// ...compiles to roughly this plain object:
const element = { type: 'h1', props: { className: 'title', children: 'Hello' } };
```

React keeps the VDOM tree from the previous render and builds a new one on the current render, diffs the two, and computes the minimal set of real DOM mutations needed. That diff-then-patch step is the whole point: it turns "re-render everything" into "mutate the three nodes that actually changed." Is the virtual DOM always faster than hand-tuned direct DOM manipulation? No, a surgical DOM update can always win a synthetic benchmark against a diff-and-patch cycle. What the VDOM actually buys you is ergonomics at scale: you write declarative "what the UI looks like now" code, and React works out the efficient mutation path, instead of hand-rolling DOM diffing for every feature yourself.

> **Remember:** the virtual DOM is not about raw speed. It is about writing "what the UI should look like" and letting React work out the minimal real change.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-vdom-q1", "type": "mcq",
      "prompt": "Is the virtual DOM always faster than a hand-tuned, direct DOM update for the same change?",
      "options": [
        {"id":"a","text":"Yes, the virtual DOM is always the fastest possible approach"},
        {"id":"b","text":"No — a surgical, hand-written DOM mutation can always win a synthetic benchmark; the VDOM's real win is ergonomics at scale, letting you write declarative code instead of hand-rolling diffing"},
        {"id":"c","text":"No, the virtual DOM is always slower than direct DOM manipulation"},
        {"id":"d","text":"Speed is not something the virtual DOM affects at all"}
      ],
      "correct": "b",
      "explanation": "The VDOM's value isn't winning raw speed benchmarks against a hand-tuned update, it's letting you write declarative code at scale while React works out an efficient mutation path automatically." }
] }
```

## Why React re-renders at all

A component re-renders when its own state changes (a `useState` setter fires), when its parent re-renders (by default this cascades to every child regardless of whether that child's own props changed), when a context it consumes changes (any component calling `useContext(SomeContext)` re-renders on that context's value changing), or when a hook forces an update (`useReducer` dispatch, `useSyncExternalStore` emitting a new snapshot).

Critically, a re-render is not the same thing as the DOM changing. A re-render calls your component function again to produce a new VDOM tree; reconciliation then diffs it against the previous tree and only touches the real DOM where something actually differs. This split, "render phase" (call component functions, build VDOM) versus "commit phase" (apply the diff to the real DOM), is the backbone of the whole model, and it is the entire reason `React.memo`/`useMemo`/`useCallback` exist at all, covered in the React Performance lesson.

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

> **Remember:** a re-render calls your function again to build a new VDOM tree. It does not mean the real DOM changed; that only happens if the diff finds a difference.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-rerender-q1", "type": "mcq",
      "prompt": "`<ExpensiveChild />` takes no props at all, yet it re-renders every time its parent's state changes. Why?",
      "options": [
        {"id":"a","text":"React only skips re-rendering components that receive props"},
        {"id":"b","text":"By default, a parent re-rendering cascades to every child regardless of whether that child's own props changed"},
        {"id":"c","text":"This is a bug, ExpensiveChild should never re-render"},
        {"id":"d","text":"ExpensiveChild must have hidden internal state causing this"}
      ],
      "correct": "b",
      "explanation": "React re-renders every descendant of a re-rendering component by default. Skipping a child that genuinely didn't need to change requires an explicit opt-in like React.memo." }
] }
```

## Reconciliation: how the diff is actually computed

Reconciliation is the algorithm behind that diff step: how React decides which minimal DOM mutations to make, comparing old VDOM to new. Walking through it precisely is the real answer to "explain reconciliation," not just naming that it happens.

Full tree diffing, comparing every node against every other node, is O(n³) for n elements, far too slow to run on every render. React makes it tractable with two heuristics that trade a little theoretical correctness for a lot of speed.

First, **a different element type means React tears the subtree down and rebuilds it.** If the root of a subtree changes type, `<div>` becomes `<span>`, or `<Foo>` becomes `<Bar>`, React does not try to reconcile the children at all. It unmounts the old subtree entirely, running cleanup effects, and mounts a fresh one. Matching type is a precondition to even start diffing children.

Second, **keys identify stable elements across renders.** For a list of siblings, React needs to know whether a given item is the same logical thing, just reordered or updated, or genuinely new. Without a `key`, it falls back to matching children by index, and inserting an item at the front of a list makes every remaining item "at the wrong index," so React diffs, and can discard local state for, every sibling instead of just the one that actually changed.

```tsx
// Without keys: inserting at the front makes React think every row changed
{items.map(item => <Row data={item} />)}

// With keys: React matches by identity and only mounts the genuinely new one
{items.map(item => <Row key={item.id} data={item} />)}
```

**Fiber**, React 16 and later. Before Fiber, reconciliation walked the tree recursively and synchronously, and once it started, it could not stop until the whole tree was diffed, even if that meant blocking the main thread long enough to drop frames. Fiber restructures each element into a "fiber" object, a unit of work with pointers to its child, sibling, and parent, so the render phase can be paused, resumed, or abandoned mid-tree. That is precisely why the render phase is interruptible while the commit phase is not, from the split above: once React starts flushing DOM mutations it cannot leave the UI half-updated, but the diffing that happens before that can yield to the browser and pick back up later. That interruptibility is the mechanism underneath `useTransition` and `Suspense`, both of which mark work as lower priority so Fiber can pause it when something more urgent, a keystroke, a click, comes in.

Changing a `key` on an element does something specific and deliberate: it forces React to treat the old and new elements as unrelated, a full unmount of the old instance, losing all local state and running its cleanup effects, followed by a full mount of what looks like a "new" one, even though it is the same component function at the same tree position. `<Form key={userId} />` resets a form's entire internal state the instant `userId` changes, in one line, instead of a `useEffect` manually clearing every field.

Two practical gotchas fall directly out of the two heuristics above. Changing a key forces a remount, useful when intentional, a real bug when it happens by accident, like using an array index as a key while the array reorders. And defining a component function *inside* another component's render body changes its type identity on every single render: `type` is compared by reference, and a function declared inside `Parent`'s body is a genuinely new function, and therefore a new type, every time `Parent` re-renders, even though it "looks like" the same component to a human reader.

```tsx
function Parent() {
  // New function identity every render → React unmounts/remounts this
  // entire subtree on every Parent re-render.
  function ChildComponent() {
    return <input />; // loses focus and local state on every keystroke in Parent
  }
  return <ChildComponent />;
}

// Fix: declare it once, outside Parent, so its type identity stays stable
function ChildComponent() {
  return <input />;
}
function Parent() {
  return <ChildComponent />;
}
```

Reducing *how often* a matched element re-renders, via `React.memo`, `useMemo`, `useCallback`, is a separate concern covered in the React Performance lesson. What's here is reconciliation correctly identifying *which* elements are the same across renders in the first place, which has to happen before "should it re-render" is even a meaningful question.

> **Remember:** a missing `key` makes React match list items by index. Insert one item at the front, and every remaining item now looks like it changed.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-reconciliation-q1", "type": "mcq",
      "prompt": "A form loses focus on every keystroke in its parent. The parent's render body contains `function ChildInput() { return <input />; }` declared inside the parent function, and renders `<ChildInput />`. What's the bug?",
      "options": [
        {"id":"a","text":"React can't handle nested function declarations"},
        {"id":"b","text":"Declaring ChildInput inside the parent's body creates a new function, and therefore a new type by reference, on every render, so React unmounts and remounts the whole subtree each time"},
        {"id":"c","text":"input elements can never hold focus in React"},
        {"id":"d","text":"The parent needs a key prop"}
      ],
      "correct": "b",
      "explanation": "React compares element type by reference. A component function declared inside another component's body is a brand-new function object every render, which reconciliation treats as an entirely different component type, forcing a full unmount and remount." }
] }
```

## Component lifecycle, class and function side by side

Class components expose lifecycle explicitly; function components reach the same phases through hooks. Interviewers still ask about the class version because plenty of production code, and every "explain the old API" question, still touches it.

| Phase | Class component | Function component |
|---|---|---|
| Mount | `constructor` → `render` → `componentDidMount` | render body runs → `useEffect(fn, [])` runs after paint |
| Update | `render` → `componentDidUpdate` | render body runs → `useEffect(fn, [deps])` runs if deps changed |
| Unmount | `componentWillUnmount` | cleanup function returned from `useEffect` |
| Error | `componentDidCatch` / `getDerivedStateFromError` | no hook equivalent, still needs a class-based Error Boundary |

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
    if (prevState.seconds !== this.state.seconds && this.state.seconds % 10 === 0) {
      console.log('checkpoint:', this.state.seconds);
    }
  }
  componentWillUnmount() {
    window.clearInterval(this.interval);
  }
  render() {
    return <p>{this.state.seconds}s elapsed</p>;
  }
}
```

Note the order: `constructor` runs once, then `render()` produces the VDOM, with no side effects allowed there (it can even run more than once per commit under Strict Mode), then React commits to the real DOM, then `componentDidMount` fires. Every later state or prop change re-enters at `render()` and, after commit, calls `componentDidUpdate`.

> **Remember:** `componentDidMount`/`useEffect(fn, [])` both run after the first commit, never before. `render()`/the function body must stay free of side effects.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-lifecycle-q1", "type": "mcq",
      "prompt": "Which hook is the function-component equivalent of `componentWillUnmount`?",
      "options": [
        {"id":"a","text":"useEffect(fn, []) itself"},
        {"id":"b","text":"The cleanup function returned from useEffect"},
        {"id":"c","text":"useState's setter"},
        {"id":"d","text":"There is no equivalent"}
      ],
      "correct": "b",
      "explanation": "useEffect's returned function runs before the next effect invocation and on unmount, which is exactly the role componentWillUnmount plays in a class component." }
] }
```

## Watching it happen: a render counter

The fastest way to *see* re-renders instead of reasoning about them abstractly. `useRef` is the right tool here because incrementing it does not itself trigger a re-render, unlike `useState`, so it purely observes without interfering with what it's measuring.

```tsx
function RenderCounter() {
  const [count, setCount] = useState(0);
  const renderCount = useRef(0);
  renderCount.current += 1; // runs on every call to the component function, i.e. every render

  return (
    <div>
      <p>Count: {count}</p>
      <p>Renders: {renderCount.current}</p>
      <button onClick={() => setCount(c => c + 1)}>Increment</button>
    </div>
  );
}
```

Click "Increment" and watch `renderCount.current` climb by exactly one per click, proving each `setCount` call schedules exactly one render. Call `setCount` twice inside the same handler, and the count still only climbs by one, since React batches multiple `setState` calls within the same event handler into a single render.

> **Remember:** `useRef` doesn't trigger a re-render when it changes, which is exactly why it's the right tool for silently counting renders.
