---
kind: lesson
id_key: interview-prep-45/day-19-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "React Performance Patterns and Concurrent Features"
position: 33
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
React performance questions have shifted from "when do you use `useMemo`" to "what does automatic batching change" and "when do you reach for `useTransition` versus `useDeferredValue`." The concurrent-rendering APIs are now a standard part of the interview loop. This lesson builds two common exercises, optimistic updates and a debounced search, and explains the concurrent APIs that make modern React feel fast under load.

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

## The common thread

The optimistic-update component and the debounced search both lean on the same underlying idea `useTransition` embodies directly: mark work as interruptible or delayed so the UI thread stays responsive to whatever the user does next. Carry that framing into an interview more than any single hook's exact signature, concurrent React is fundamentally about scheduling priority, and batching, transitions, deferred values, and optimistic state are each a different lever on that same knob.
