---
kind: lesson
id_key: interview-prep-45/day-05-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "React Performance"
position: 15
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
"How would you optimize a slow React app?" is a near-guaranteed senior-level question, and "wrap everything in `useMemo`" is the wrong answer. React performance questions have also shifted in recent years, from just "when do you use `useMemo`" to "what does automatic batching change" and "when do you reach for `useTransition` versus `useDeferredValue`." This lesson covers `React.memo`, `useMemo`, and `useCallback` correctly, including the real cost of memoization that most candidates skip entirely, how to measure before you optimize anything, and the concurrent-rendering APIs that make modern React feel fast under load.

## When memoization is worth reaching for

From the rendering-fundamentals lesson: a parent re-rendering re-renders every child by default, and re-rendering a function component just means calling the function again to produce a new VDOM subtree, which reconciliation then diffs. For cheap components that's essentially free, diffing a `<span>` costs nanoseconds. Memoization only pays off when re-rendering is measurably expensive: large lists, heavy computation inside the render body, or a component with an expensive subtree whose props are stable most of the time.

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

> **Remember:** `React.memo` compares props by reference. A fresh inline function or object literal every render defeats it silently, unless the parent also memoizes that value.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-memo-q1", "type": "mcq",
      "prompt": "A component is wrapped in `React.memo`, but it still re-renders every time its parent does, even though its own logical props haven't changed. What's the most likely cause?",
      "options": [
        {"id":"a","text":"React.memo doesn't actually work in modern React"},
        {"id":"b","text":"The parent is passing an inline arrow function or object literal as a prop, which is a new reference every render, so the shallow prop comparison always reports a change"},
        {"id":"c","text":"The component has too many DOM nodes"},
        {"id":"d","text":"React.memo only works on class components"}
      ],
      "correct": "b",
      "explanation": "React.memo does a shallow, per-prop reference comparison. An inline function or object literal is a brand-new reference every render, which always fails that comparison regardless of whether the 'logical' value is the same." }
] }
```

## Memoization isn't free

This is what senior-level interviews are actually probing for. Every memoized value or function stays alive between renders, holding references to whatever its closure captured, real memory pressure at scale across thousands of memoized rows. `useMemo`/`useCallback`/`React.memo` all pay a comparison cost on every render too, dependency-array diffing or shallow prop comparison, and for a genuinely cheap computation, that comparison can cost more than just redoing the work would have. There's a maintenance cost as well: a wrong or incomplete dependency array is a correctness bug, a stale closure, not just a missed optimization. `useMemo(() => expensive(a, b), [a])` silently keeps using a stale `b` forever the moment `b` changes without `a` changing alongside it.

```tsx
// Don't: memoizing a cheap string concat costs more than it saves
const fullName = useMemo(() => `${firstName} ${lastName}`, [firstName, lastName]);
// Just do this
const fullName = `${firstName} ${lastName}`;
```

Should every component be wrapped in `React.memo` by default? No. `React.memo` on a component whose props change on nearly every render, or that's cheap to render regardless, adds a wasted comparison on top of the render you were trying to avoid. Reach for it when profiling shows a specific component re-rendering expensively with otherwise-stable props, not as a preemptive habit.

> **Remember:** every memoization hook costs a comparison on every render. For a cheap computation, that comparison can cost more than just redoing the work.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-memocost-q1", "type": "mcq",
      "prompt": "`const fullName = useMemo(() => firstName + \" \" + lastName, [firstName, lastName]);` What's wrong with reaching for useMemo here?",
      "options": [
        {"id":"a","text":"Nothing, this is the correct pattern for any derived value"},
        {"id":"b","text":"String concatenation is so cheap that the dependency-array comparison useMemo performs every render likely costs more than just redoing the concatenation directly"},
        {"id":"c","text":"useMemo can't be used with string values"},
        {"id":"d","text":"This will cause a stale closure bug"}
      ],
      "correct": "b",
      "explanation": "useMemo isn't free: it pays a dependency comparison on every render. For a computation this cheap, the comparison itself is likely more expensive than simply recomputing the value." }
] }
```

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

The **Chrome DevTools Performance tab** records everything on the page, JS execution, layout, paint, garbage collection, not just React, which is where to look when the bottleneck might not be React at all, a synchronous `JSON.parse` of a huge payload, or the layout-thrashing pattern from the CSS and rendering-performance lessons. Look for long yellow (scripting) or purple (rendering) bars, and check the "Bottom-Up" tab to find which function actually consumed the time, not just which one happened to be on top of the call stack when the recording captured it.

The workflow that reads as a strong answer to "how would you optimize a slow app": profile first, identify the specific expensive component or computation, apply the narrowest targeted fix, `memo`, `useMemo`, `useCallback`, virtualization, code splitting, then profile again to confirm the fix actually helped. Optimizing without measuring first is the wrong answer even in the cases where the fix happens to work anyway.

> **Remember:** profile first, apply the narrowest fix, profile again. Optimizing without measuring is the wrong answer even when the fix happens to work.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-profiling-q1", "type": "mcq",
      "prompt": "The React DevTools Profiler flamegraph shows a component rendering slowly, but the actual cause turns out to be a synchronous JSON.parse of a large payload inside that component. What tool would have caught this fastest?",
      "options": [
        {"id":"a","text":"The React DevTools Profiler alone, since it measures all render time"},
        {"id":"b","text":"The Chrome DevTools Performance tab, since it records everything on the page, not just React, including raw JS execution time"},
        {"id":"c","text":"React.memo"},
        {"id":"d","text":"useCallback"}
      ],
      "correct": "b",
      "explanation": "The React Profiler only measures React's own render work. A slow synchronous JS operation inside a render shows up there as 'this component is slow,' but the Chrome Performance tab breaks down actual JS execution time and would point straight at the JSON.parse call." }
] }
```

## Automatic batching

Before React 18, updates only batched inside React's own event handlers. The same two `setState` calls inside a `setTimeout`, a promise callback, or a raw `addEventListener` would each trigger a separate render. React 18+ batches everywhere, automatically.

```tsx
function Example() {
  const [count, setCount] = useState(0);
  const [flag, setFlag] = useState(false);
  function handleClick() {
    fetch("/api/data").then(() => {
      // React 18+: these batch into ONE re-render, even inside a promise callback
      setCount((c) => c + 1);
      setFlag((f) => !f);
    });
  }
  return <button onClick={handleClick}>{count}</button>;
}
```

What changed between React 17 and 18's batching, specifically? In 17, only updates inside React's synthetic event handlers batched; the same pair of `setState` calls inside a `setTimeout` or `fetch().then()` would fire two separate renders. React 18's `createRoot` makes batching automatic regardless of where the updates originate. The opt-out is `flushSync`, needed rarely, mostly when you genuinely need a synchronous, unbatched update, forcing a DOM measurement between two state changes being the usual case.

> **Remember:** React 17 only batched inside its own event handlers. React 18 batches everywhere, including inside a `setTimeout` or a promise callback.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-batching-q1", "type": "mcq",
      "prompt": "Two `setState` calls happen back to back inside a `fetch().then()` callback in a React 18 app. How many re-renders does this trigger?",
      "options": [
        {"id":"a","text":"Two, since promise callbacks don't batch"},
        {"id":"b","text":"One, since React 18's automatic batching applies everywhere, not just inside React's own event handlers"},
        {"id":"c","text":"Zero, promise callbacks can't trigger re-renders"},
        {"id":"d","text":"It depends on the browser"}
      ],
      "correct": "b",
      "explanation": "React 17 only batched updates inside React's synthetic event handlers. React 18's createRoot makes batching automatic everywhere, including timeouts and promise callbacks, collapsing both setState calls into one render." }
] }
```

## useTransition versus useDeferredValue

Both mark work as low-priority so the browser stays responsive to typing and clicking, but they solve different shapes of problem.

**`useTransition`**: you own the state *setter*, and want to mark the update it triggers as non-urgent, so React can interrupt it if something more urgent, another keystroke, arrives.

```tsx
function TabContainer() {
  const [tab, setTab] = useState<"home" | "analytics">("home");
  const [isPending, startTransition] = useTransition();
  function selectTab(next: "home" | "analytics") {
    startTransition(() => { setTab(next); }); // low priority: React abandons it if the user clicks again first
  }
  return (
    <div>
      <button onClick={() => selectTab("home")}>Home</button>
      <button onClick={() => selectTab("analytics")}>Analytics</button>
      {isPending && <Spinner />}
      {tab === "home" ? <HomeTab /> : <AnalyticsTab />}
    </div>
  );
}
```

**`useDeferredValue`**: you don't control the setter, a value arrives from a parent or a fast-changing input, and you want a "lagging" copy of it that updates at low priority instead.

```tsx
function SearchResults({ query }: { query: string }) {
  const deferredQuery = useDeferredValue(query); // lags behind `query` under load
  const isStale = query !== deferredQuery;
  const results = useMemo(() => expensiveSearch(deferredQuery), [deferredQuery]);
  return <ul style={{ opacity: isStale ? 0.5 : 1 }}>{results.map((r) => <li key={r.id}>{r.title}</li>)}</ul>;
}
```

When would you pick one over the other? Use `useTransition` when you own the state update, calling `setState` yourself in response to a click, and want to mark that specific update as interruptible. Use `useDeferredValue` when you're just consuming a value you don't control the setter for, most commonly a fast-changing controlled input passed down to an expensive child, and want the expensive derived work computed at lower priority without touching where the value originates at all.

> **Remember:** `useTransition` is for when you own the setter. `useDeferredValue` is for when you only own a value someone else is setting.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-transition-q1", "type": "mcq",
      "prompt": "A component receives a `query` prop from its parent, which updates on every keystroke of a search box the component doesn't own. The component needs to run an expensive search on that query without blocking typing. Which hook fits?",
      "options": [
        {"id":"a","text":"useTransition, wrapped around the parent's setState call"},
        {"id":"b","text":"useDeferredValue, since the component only consumes the value and doesn't control the setter that produces it"},
        {"id":"c","text":"useCallback"},
        {"id":"d","text":"useReducer"}
      ],
      "correct": "b",
      "explanation": "useTransition requires owning the setState call that triggers the update. Since this component only receives query as a prop, useDeferredValue is the fit: it lags behind the prop's value at low priority without touching where it originates." }
] }
```

## Suspense for data, and the promise-creation rule

Suspense lets a component "pause" rendering while it waits for data, showing a fallback instead of the component manually managing an `isLoading` flag. In React 19, this is what `use()` runs on for reading a promise during render.

```tsx
function UserProfile({ userPromise }: { userPromise: Promise<User> }) {
  const user = use(userPromise); // suspends the component until the promise resolves
  return <h1>{user.name}</h1>;
}
function ProfilePage({ userPromise }: { userPromise: Promise<User> }) {
  return <Suspense fallback={<Skeleton />}><UserProfile userPromise={userPromise} /></Suspense>;
}
```

The promise has to be created *outside* the render that reads it, in a parent, a route loader, or a cache. Calling `fetch()` directly inside the component would create a fresh promise on every single render and suspend forever, the exact same rule as `useEffect`'s dependency array: don't create an unstable reference inside the render you're trying to stabilize.

> **Remember:** a promise read by `use()` has to be created outside the component that reads it, or it recreates and resuspends on every render.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-suspense-q1", "type": "mcq",
      "prompt": "`function UserProfile({ userId }) { const user = use(fetch(\\`/api/users/${userId}\\`)); ... }`. What's wrong with calling fetch directly inside the component here?",
      "options": [
        {"id":"a","text":"Nothing, this is the correct pattern for use()"},
        {"id":"b","text":"It creates a fresh promise on every single render, so the component suspends forever instead of ever resolving to a stable value"},
        {"id":"c","text":"fetch can't be called inside a component under any circumstances"},
        {"id":"d","text":"use() only works with promises created by useState"}
      ],
      "correct": "b",
      "explanation": "The promise a component reads with use() must be created outside that render, in a parent, loader, or cache. Creating a fresh promise every render never gives Suspense a stable promise to actually resolve against." }
] }
```

## Building an optimistic-update component

Optimistic updates apply the expected result immediately, before the server confirms it, and roll back on failure, which makes the UI feel instant for actions that almost always succeed: likes, toggles, adding an item.

```tsx
function TodoList({ initialTodos }: { initialTodos: Todo[] }) {
  const [todos, setTodos] = useState(initialTodos);
  const [isPending, startTransition] = useTransition();

  // useOptimistic layers a temporary, hopeful value on top of `todos` that
  // automatically reverts once the real state update lands, or on error, below.
  const [optimisticTodos, setOptimisticTodo] = useOptimistic(todos, (state, toggledId: string) =>
    state.map((t) => (t.id === toggledId ? { ...t, completed: !t.completed } : t)));

  function toggle(id: string) {
    startTransition(async () => {
      setOptimisticTodo(id); // instant UI update
      try {
        await toggleTodoOnServer(id);
        setTodos((prev) => prev.map((t) => (t.id === id ? { ...t, completed: !t.completed } : t))); // confirm: commit the real state
      } catch {
        // no-op — not updating `todos` means optimisticTodos reverts automatically once the transition settles
      }
    });
  }

  return (
    <ul>
      {optimisticTodos.map((todo) => (
        <li key={todo.id} style={{ opacity: isPending ? 0.6 : 1 }}>
          <input type="checkbox" checked={todo.completed} onChange={() => toggle(todo.id)} /> {todo.text}
        </li>
      ))}
    </ul>
  );
}
```

`useOptimistic` has to be called inside a `useTransition` or a form action, it needs an async boundary to know when to revert. On success, commit the real state; on failure, deliberately do nothing, and React reverts the optimistic overlay for you once the transition finishes settling.

> **Remember:** `useOptimistic` reverts automatically once its transition settles, unless you commit a matching real state update to make the optimistic change permanent.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-optimistic-q1", "type": "mcq",
      "prompt": "In the TodoList example, the catch block for a failed toggle does nothing at all, no `setTodos` call, no error UI. Why does the optimistic checkbox still revert correctly?",
      "options": [
        {"id":"a","text":"It doesn't, this is a bug and the UI stays wrong"},
        {"id":"b","text":"useOptimistic's overlay is temporary by design: since the real todos state was never updated to match, the optimistic value reverts automatically once the transition settles"},
        {"id":"c","text":"React automatically retries the request three times before giving up"},
        {"id":"d","text":"The checkbox reverts because of the isPending flag"}
      ],
      "correct": "b",
      "explanation": "useOptimistic layers a temporary value on top of the real state. If the real state (todos) is never updated to match the optimistic guess, once the transition finishes, the overlay reverts back to whatever the real state actually is." }
] }
```

## Building a debounced search input, with two layers of cancellation

```tsx
function useDebouncedValue<T>(value: T, delayMs: number): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delayMs);
    return () => clearTimeout(timer); // cancel the pending update if value changes again
  }, [value, delayMs]);
  return debounced;
}

function SearchBox() {
  const [query, setQuery] = useState("");
  const debouncedQuery = useDebouncedValue(query, 300);
  const [results, setResults] = useState<SearchResult[]>([]);

  useEffect(() => {
    if (!debouncedQuery) { setResults([]); return; }
    const controller = new AbortController();
    fetch(`/api/search?q=${encodeURIComponent(debouncedQuery)}`, { signal: controller.signal })
      .then((res) => res.json()).then(setResults)
      .catch((err) => { if (err.name !== "AbortError") throw err; });
    return () => controller.abort(); // cancel an in-flight request if the query changes again
  }, [debouncedQuery]);

  return (
    <div>
      <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search..." />
      <ul>{results.map((r) => <li key={r.id}>{r.title}</li>)}</ul>
    </div>
  );
}
```

Two distinct layers of cancellation are doing work here, and interviewers check for both. The `setTimeout`/`clearTimeout` pair debounces the *state update*; the `AbortController` cancels an *in-flight request* if a newer debounced query supersedes an older one still in flight. Without the abort, a slow response to an old query could arrive after a fast response to a newer one and silently overwrite correct results with stale ones, a request-waterfall race condition.

Would `useDeferredValue` work instead of a manual debounce here? Only partially. `useDeferredValue` defers *rendering* work, not the timing of a network request, so it's the right tool for expensive client-side filtering or rendering of results you already have in hand. It won't reduce the number of API calls fired at all, since it introduces no time delay, only a lower render priority. For actually cutting request volume, a time-based debounce is still the tool.

> **Remember:** debouncing delays the state update; aborting cancels an in-flight request. A search box that only debounces can still show stale results from a slower, older request.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-react-debounce-q1", "type": "mcq",
      "prompt": "A debounced search input fires a request for each debounced query, but doesn't use `AbortController`. A user types \"cat\", then quickly \"dog\". The response for \"cat\" is slow and arrives after the response for \"dog\". What happens?",
      "options": [
        {"id":"a","text":"Nothing wrong, debouncing alone already prevents this"},
        {"id":"b","text":"The late-arriving \"cat\" results overwrite the correct, already-displayed \"dog\" results, since nothing cancelled or ignored the outdated in-flight request"},
        {"id":"c","text":"The browser automatically discards out-of-order responses"},
        {"id":"d","text":"The second request never fires until the first completes"}
      ],
      "correct": "b",
      "explanation": "Debouncing only controls when a request fires, not which response wins if requests race. Without an AbortController (or an equivalent staleness check), a slower older response can still arrive last and overwrite correct newer results." }
] }
```

## The common thread

The optimistic-update component and the debounced search both lean on the same underlying idea `useTransition` embodies directly: mark work as interruptible or delayed so the UI thread stays responsive to whatever the user does next. Carry that framing into an interview more than any single hook's exact signature. Concurrent React is fundamentally about scheduling priority, and batching, transitions, deferred values, and optimistic state are each a different lever on that same knob.
