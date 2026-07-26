---
kind: lesson
id_key: interview-prep-45/day-19-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "React Performance Patterns"
position: 22
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
React 19 performance questions have shifted from "when do you use `useMemo`" to "what does automatic batching change" and "when do you reach for `useTransition` vs `useDeferredValue`" — the newer concurrent-rendering APIs are now a standard part of the frontend interview loop. Today builds two common interview exercises (optimistic updates, debounced search) and explains the concurrent APIs that make modern React feel fast under load.

## Automatic batching

Before React 18, React only batched state updates inside React event handlers — updates inside a `setTimeout`, a promise callback, or a native event listener each triggered a separate re-render. React 18+ batches *everywhere* automatically.

```tsx
function Example() {
  const [count, setCount] = useState(0);
  const [flag, setFlag] = useState(false);

  function handleClick() {
    fetch("/api/data").then(() => {
      // React 18+: these two setState calls batch into ONE re-render,
      // even though they're inside a promise callback, not a React event handler.
      setCount((c) => c + 1);
      setFlag((f) => !f);
    });
  }

  return <button onClick={handleClick}>{count}</button>;
}
```

**Interview question: "What broke (or changed) between React 17 and React 18 batching?"**
In React 17, only updates inside React's own synthetic event handlers were batched; the same two `setState` calls inside a `setTimeout`, `fetch().then()`, or a raw `addEventListener` callback would trigger two separate renders. React 18's `createRoot` makes batching automatic everywhere, so you get one re-render regardless of where the updates originate. The opt-out is `flushSync` when you genuinely need a synchronous, unbatched update (rare — e.g. forcing a DOM measurement between two state changes).

## useTransition vs useDeferredValue

Both are concurrent-rendering APIs for marking work as low-priority so the browser stays responsive to typing/clicking, but they solve different shapes of problem.

**`useTransition`** — you have a state *setter* you control, and you want to mark the update it triggers as non-urgent, so React can interrupt it if a more urgent update (another keystroke) comes in.

```tsx
import { useState, useTransition } from "react";

function TabContainer() {
  const [tab, setTab] = useState<"home" | "analytics">("home");
  const [isPending, startTransition] = useTransition();

  function selectTab(next: "home" | "analytics") {
    startTransition(() => {
      setTab(next); // marked low-priority: if the user clicks again before this
    });               // finishes rendering, React abandons it and starts the new one
  }

  return (
    <div>
      <button onClick={() => selectTab("home")}>Home</button>
      <button onClick={() => selectTab("analytics")}>Analytics</button>
      {isPending && <Spinner />}
      {tab === "home" ? <HomeTab /> : <AnalyticsTab /* expensive render */ />}
    </div>
  );
}
```

**`useDeferredValue`** — you don't control the setter (a value comes from a parent, or from a fast-changing input), and you want a "lagging" copy of it that updates at low priority.

```tsx
import { useDeferredValue, useState, useMemo } from "react";

function SearchResults({ query }: { query: string }) {
  const deferredQuery = useDeferredValue(query); // lags behind `query` under load
  const isStale = query !== deferredQuery;

  const results = useMemo(() => expensiveSearch(deferredQuery), [deferredQuery]);

  return (
    <ul style={{ opacity: isStale ? 0.5 : 1 }}>
      {results.map((r) => <li key={r.id}>{r.title}</li>)}
    </ul>
  );
}
```

**Interview question: "When would you pick `useDeferredValue` over `useTransition`, or vice versa?"**
Use `useTransition` when you own the state update (you're calling `setState` yourself, e.g. in response to a click) and want to mark *that specific update* as interruptible. Use `useDeferredValue` when you're just consuming a value you don't control the setter for — most commonly, a fast-changing controlled input's value passed down to an expensive child — and want React to compute the expensive derived work at lower priority without you touching where the value originates.

## Suspense for data fetching

Suspense lets a component "pause" rendering while it waits for data, showing a fallback, instead of the component managing `isLoading` state manually. In React 19, this is what powers `use()` for reading promises during render.

```tsx
import { Suspense, use } from "react";

interface User {
  id: string;
  name: string;
}

function UserProfile({ userPromise }: { userPromise: Promise<User> }) {
  const user = use(userPromise); // suspends the component until the promise resolves
  return <h1>{user.name}</h1>;
}

function ProfilePage({ userPromise }: { userPromise: Promise<User> }) {
  return (
    <Suspense fallback={<Skeleton />}>
      <UserProfile userPromise={userPromise} />
    </Suspense>
  );
}
```

The promise must be created *outside* the render that reads it (in a parent, a route loader, or a cache) — calling `fetch()` directly inside the component on every render would create a new promise each time and suspend forever. This is the same rule as `useEffect` dependency arrays: don't create fresh unstable references inside the render you're trying to stabilize.

## Building an optimistic-update component

Optimistic updates apply the expected result immediately, before the server confirms it, and roll back on failure — this makes UI feel instant for actions that almost always succeed (likes, toggles, adding items).

```tsx
import { useOptimistic, useState, useTransition } from "react";

interface Todo {
  id: string;
  text: string;
  completed: boolean;
}

async function toggleTodoOnServer(id: string): Promise<void> {
  const res = await fetch(`/api/todos/${id}/toggle`, { method: "PATCH" });
  if (!res.ok) throw new Error("Failed to update todo");
}

function TodoList({ initialTodos }: { initialTodos: Todo[] }) {
  const [todos, setTodos] = useState(initialTodos);
  const [isPending, startTransition] = useTransition();

  // useOptimistic layers a temporary, hopeful value on top of `todos`
  // that automatically reverts once the real state update lands (or on error, below).
  const [optimisticTodos, setOptimisticTodo] = useOptimistic(
    todos,
    (state, toggledId: string) =>
      state.map((t) => (t.id === toggledId ? { ...t, completed: !t.completed } : t)),
  );

  function toggle(id: string) {
    startTransition(async () => {
      setOptimisticTodo(id); // instant UI update
      try {
        await toggleTodoOnServer(id);
        setTodos((prev) =>
          prev.map((t) => (t.id === id ? { ...t, completed: !t.completed } : t)),
        ); // confirm: commit the real state so it matches the optimistic one
      } catch {
        // no-op: not updating `todos` means optimisticTodos reverts to the last
        // real state automatically once the transition settles — this is the rollback.
      }
    });
  }

  return (
    <ul>
      {optimisticTodos.map((todo) => (
        <li key={todo.id} style={{ opacity: isPending ? 0.6 : 1 }}>
          <label>
            <input type="checkbox" checked={todo.completed} onChange={() => toggle(todo.id)} />
            {todo.text}
          </label>
        </li>
      ))}
    </ul>
  );
}
```

`useOptimistic` must be called inside a `useTransition` (or a form action) — it needs an async boundary to know when to revert. On success you commit real state; on failure you deliberately do nothing to `todos`, and React reverts the optimistic overlay for you once the transition completes.

## Building a debounced search input

Debouncing delays firing an expensive operation (an API call, a heavy filter) until the user has stopped typing for a set interval, instead of firing on every keystroke.

```tsx
import { useEffect, useState } from "react";

function useDebouncedValue<T>(value: T, delayMs: number): T {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delayMs);
    return () => clearTimeout(timer); // cancel the pending update if `value` changes again
  }, [value, delayMs]);

  return debounced;
}

interface SearchResult {
  id: string;
  title: string;
}

function SearchBox() {
  const [query, setQuery] = useState("");
  const debouncedQuery = useDebouncedValue(query, 300);
  const [results, setResults] = useState<SearchResult[]>([]);

  useEffect(() => {
    if (!debouncedQuery) {
      setResults([]);
      return;
    }
    const controller = new AbortController();
    fetch(`/api/search?q=${encodeURIComponent(debouncedQuery)}`, { signal: controller.signal })
      .then((res) => res.json())
      .then(setResults)
      .catch((err) => {
        if (err.name !== "AbortError") throw err;
      });
    return () => controller.abort(); // cancel an in-flight request if the query changes again
  }, [debouncedQuery]);

  return (
    <div>
      <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search..." />
      <ul>
        {results.map((r) => <li key={r.id}>{r.title}</li>)}
      </ul>
    </div>
  );
}
```

Two layers of cancellation here, and interviewers check for both: the `setTimeout`/`clearTimeout` pair debounces the *state update*, and the `AbortController` cancels an *in-flight request* if a newer debounced query supersedes it — without the abort, a slow response to an old query could arrive after a fast response to a newer one and overwrite the correct results ("request waterfall race condition").

**Interview question: "Would `useDeferredValue` work instead of a manual debounce here?"**
Partially — `useDeferredValue` defers *rendering* work, not the timing of a network request. It's the right tool for expensive client-side filtering/rendering of results you already have. It won't reduce the number of API calls fired, because it doesn't introduce a time delay — it just deprioritizes the render. For reducing request volume, you still need a time-based debounce.

## Key takeaways

- React 18+ batches all state updates by default, regardless of where they originate (promises, timeouts, native listeners) — not just inside React event handlers.
- `useTransition` marks an update you trigger as interruptible/low-priority; `useDeferredValue` gives you a lagging copy of a value you don't control the setter for.
- `use()` + `Suspense` requires the promise to be created outside the render reading it, or it suspends forever on every render.
- `useOptimistic` needs an async boundary (`useTransition` or a form action) to know when to commit or revert the optimistic value.
- Debounced search needs two separate cancellations: a timer for the input delay, and an `AbortController` for in-flight requests, to avoid stale-response race conditions.
