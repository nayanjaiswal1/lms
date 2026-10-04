---
kind: lesson
id_key: interview-prep-45/fe-crash-course-rapid-recall
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "Rapid Recall and Mock Frontend Rounds"
position: 37
estimated_minutes: 60
source:
    - interview-prep-notes.md
    - 45-day-interview-roadmap.md
---
This is the last lesson in the frontend track, and it's a different kind of lesson on purpose. Everything before it taught a concept in depth. This one is a fast recall pass across the whole subject, followed by real mock rounds: two coding prompts, a rapid Q&A round, an architecture question, and the personal stories worth rehearsing out loud before a real interview.

Use the recall sections to find gaps, not to learn something for the first time. If a line doesn't make sense, that's the sign to go back and re-read the lesson it belongs to.

## Quick recall: JavaScript

`var` is function-scoped and hoisted to `undefined`. `let` and `const` are block-scoped and sit in the "temporal dead zone" until their line runs, so touching them early throws an error instead of quietly returning `undefined`. A function declaration hoists whole, body included, so it's callable before its own line in the file.

A closure is a function that keeps access to its outer scope's variables even after that outer function has already returned. That's exactly what makes a debounce timer still "remember" the value from the render that created it.

`this` depends on how a function is called, not where it's written. `call(thisArg, a, b)` runs a function immediately with a chosen `this` and listed arguments. `apply(thisArg, [a, b])` does the same with an array of arguments. `bind(thisArg)` doesn't run anything, it returns a new function with `this` locked in for later. Arrow functions ignore all three, they always use the `this` from where they were defined, which is why they're the default choice for callbacks.

The event loop runs every synchronous line first, then drains the *entire* microtask queue, promise callbacks, before running even one task off the macrotask queue, `setTimeout` callbacks. That ordering is why `Promise.resolve().then()` always fires before `setTimeout(fn, 0)`, no matter how short the timeout.

`==` converts both sides before comparing, which is how `"0" == false` ends up `true`. `===` never converts anything. A shallow copy only duplicates the top level, an object nested one level down is still the same shared reference in both copies. A missing property lookup on an object walks up its prototype chain until it finds a match or hits `null`, that chain is a live reference, so reassigning a shared method later changes what every existing instance sees.

Debounce waits for activity to stop before firing. Throttle fires on a fixed schedule no matter how often the activity happens. `async`/`await` is sugar over promises: `await` pauses the function until the awaited promise settles, and a rejection is caught with a plain `try`/`catch`. `undefined` means a variable was declared but never given a value. `null` means someone deliberately set it to "nothing here." `typeof null` returning `"object"` is a permanent quirk of the language, not a bug you're expected to fix.

> **Remember:** the entire microtask queue always drains before the next macrotask runs, that single rule explains almost every "what logs first" question.

## Quick recall: HTML and CSS

Reach for the semantic element first: `<button>` over `<div onClick>`, `<nav>`/`<main>`/`<article>` over a `<div className="...">`. A native element gives you keyboard support, a screen-reader-visible role, and correct behavior for free, a `<div>` gets none of it until you rebuild it by hand.

`box-sizing: border-box` makes a declared width the actual rendered width, padding and border are absorbed inside it instead of added on top. Flexbox lays out along one axis. Grid lays out along two, if you're fighting `flex-wrap` and fixed widths to fake rows and columns, that's the sign you actually wanted Grid.

`transform` and `opacity` are the two properties that can skip layout and paint entirely and go straight to the GPU compositor, which is why they're the default choice for anything animated. Only eight values in JavaScript are falsy, everything else, including `[]` and `{}`, is truthy, which is exactly why `if ([])` runs its body even though `[] == false` is also `true`, the two checks use completely different rules. `??` only falls back on `null`/`undefined`. `||` falls back on any falsy value at all, which silently breaks the moment `0` or `""` is a value you actually meant to keep.

## Quick recall: React

React keeps a lightweight, in-memory tree, then diffs the new one against the last one and applies only the minimal real change to the actual DOM. A component re-renders when its own state changes, when its parent re-renders, when a context it reads changes, or when a hook forces an update. Re-rendering the function is not the same thing as the DOM actually changing, reconciliation decides that part separately.

Hook state lives on the underlying fiber, addressed by call order, not by name, which is the reason hooks can never be called conditionally: skip a call on some renders and every hook after it reads the wrong slot. `useState`'s setter skips a re-render if the new value is reference-equal to the current one. `useEffect` runs after the DOM commits; an empty dependency array means once, listed values mean "re-run when any of these change," and its cleanup runs before the next run and on unmount.

`React.memo` skips a re-render on shallow-equal props, and does nothing at all if a parent passes a brand-new object, array, or function literal every render, pair it with `useMemo`/`useCallback` on the parent for exactly those values. Memoization isn't free, it costs a comparison every render to check, so profile first and apply it to the actual hot path, not by reflex.

Default to the narrowest state scope that works: local `useState`, then lift to a shared parent, then Context for slow-changing global values like theme, then an external store only once state is genuinely frequent, complex, and cross-cutting. A custom hook is the default way to share stateful logic, no wrapper component, no change to the tree shape. Compound components share state through context for a fixed family of children, tabs, an accordion. An HOC wraps a component and returns a new one; a custom hook only reuses logic and renders nothing on its own, which is why hooks replaced most HOC use.

The `key` prop tells React which array item maps to which rendered element across renders. An index key breaks the moment the list reorders or an item is removed from the middle, because the index no longer identifies the same logical item.

> **Remember:** a missing or wrong `key` doesn't just cause a warning, it makes React attach the wrong local state to the wrong row the moment a list changes shape.

## Quick recall: async and the browser

Fix a fetch race condition with `AbortController`: cancel the previous in-flight request the moment a new one starts, otherwise a slower earlier response can resolve after a faster later one and overwrite the screen with stale data. `fetch` is built in and needs a manual `.json()` call and an `response.ok` check; `axios` parses JSON automatically and throws on a non-2xx response by default. CORS is a browser rule blocking a cross-origin read unless the server's response headers explicitly allow it, it does nothing to stop a direct server-to-server request. `localStorage` persists until it's explicitly cleared. `sessionStorage` clears the moment the tab closes. Cookies, unlike either of those, get sent to the server automatically with every matching request. `IntersectionObserver` detects an element entering or leaving the viewport, the standard tool for infinite scroll and lazy-loaded images. The render pipeline runs in one fixed order: parse HTML into a DOM tree, compute styles, calculate layout, then paint pixels.

## Quick recall: TypeScript

`interface` supports declaration merging and reads naturally with `extends`. `type` handles unions and intersections more flexibly and can alias any type, not just an object shape, the two are largely interchangeable otherwise. Generics (`<T>`) are reusable type placeholders that let a function or component work across many types while staying fully checked, instead of falling back to `any`. `any` turns off type checking completely. `unknown` also accepts anything, but forces a check or a cast before it can be used, which is why it's the safer choice at a boundary where the real shape isn't known yet, an API response, the result of `JSON.parse`. `?.` short-circuits to `undefined` instead of throwing on a `null`/`undefined` access. `??` falls back only on `null`/`undefined`, unlike `||`.

## One-line recall for the rest of the course

These topics already have a full lesson each. One line to jog your memory, and the lesson title to go back to if it doesn't.

- **HTTP and Caching**: `no-cache` still saves the response but always re-checks first; `no-store` saves nothing. A `304` carries no body at all.
- **Network Performance and Web Vitals**: LCP is load speed, INP is responsiveness, CLS is visual shifting, field data from real users is what actually gets scored, not lab data from Lighthouse.
- **Code Splitting and Bundles**: `React.lazy` needs a default export and a `Suspense` boundary; an error boundary is what catches a failed chunk download, `Suspense` alone can't.
- **Virtualization**: keep the DOM node count roughly constant no matter how much data exists, by rendering only the currently visible window plus a small buffer.
- **GraphQL and Data Fetching**: the N+1 problem is one query for the parents plus one query per child; DataLoader batches every load call in the same tick into a single query.
- **Web Security**: React escapes `{value}` automatically; it never escapes `dangerouslySetInnerHTML`. CSRF exploits automatic cookies, a manually-attached `Authorization` header isn't exposed to it.
- **WebSockets and Real-time**: close code `1000` means "on purpose, don't reconnect." Any other code means "something broke, try again" with exponential backoff.
- **SSR and Nextjs**: a hydration mismatch means the server's HTML and the client's first render disagree, usually because of `Date.now()`, `Math.random()`, or a browser-only API read during render.
- **Micro-frontends**: this solves an organizational problem, independent teams shipping independently, not a technical one; without `singleton: true` on React, host and remote silently ship two separate React copies.
- **Build Tools and Bundling**: Vite serves native ES modules unbundled in dev and only bundles for production, which is why its dev server starts instantly regardless of app size.
- **Accessibility**: ARIA's own first rule is not to use ARIA if a native element already does the job, a `<div role="button">` still owes you all the keyboard behavior a real `<button>` gives for free.
- **Error Handling**: an error boundary only catches errors thrown while rendering, never one from an event handler, a promise, or a timer.
- **Internationalization**: a manual `count === 1 ? ... : ...` check only ever handles English; ICU MessageFormat and `Intl.PluralRules` handle languages with more than two plural forms.
- **Animation**: `transform`/`opacity` can run on the compositor thread and stay smooth even while the main thread is busy; almost nothing else animatable can.
- **TypeScript for React**: type the fetcher, not the hook call, and model impossible state combinations away with a discriminated union instead of four separate booleans.
- **React Testing**: query priority is `getByRole` > `getByLabelText` > `getByText` > `getByTestId`, and mock at the network boundary with MSW, not by mocking `fetch` directly.
- **React Performance**: automatic batching in React 18+ collapses multiple `setState` calls anywhere into one render; `useTransition` marks an update as low priority so React can interrupt it for something more urgent.

## Architecture talking points

Organize folders by feature, components, hooks, and services grouped together, rather than by file type. Keep API access separate from UI components, usually through custom hooks wrapping `fetch` or a query library. Be ready to explain the boundary between a query library and a client state store, not just name both. Centralize error handling by combining error boundaries, per-request `try`/`catch`, and messaging the user can actually act on. For performance at scale, name the three real levers: list virtualization, lazy loading, code splitting. An interviewer asking any architecture question is usually testing the reasoning behind a choice more than the choice itself, be ready to explain a trade-off, not just recite an answer.

## Presenting a personal project with confidence

A worked example: a small side project, described the way it should actually come out in an interview, problem, solution, architecture, then one interesting design decision.

**Problem**: managing expenses across several bank accounts is tedious, and existing budgeting apps track spending but don't automatically reconcile invoices or receipts against bank transactions across accounts.

**Solution flow**: the user uploads bank statements or invoices as PDFs, they're sent to an LLM for parsing, the LLM returns structured JSON, date, amount, category, the backend auto-matches that against existing transactions by date and amount, a match links the invoice to that transaction, and the user sees a dashboard with a category-wise spending breakdown.

**Stack**: React and Redux Toolkit on the frontend, Django REST Framework on the backend, an LLM integration for document parsing, Docker and AWS for deployment.

> **Remember:** never call your own project "very simple" in an interview. Problem, solution, architecture, one interesting decision, that structure reads as senior no matter the project's actual size.

## Rebuilding JavaScript fundamentals from scratch

Practice writing each of these from memory, with no reference. This is exactly what a live-coding round asks for.

**A minimal Promise**

```js
class MyPromise {
  constructor(executor) {
    this.state = "pending";
    this.value = undefined;
    this.callbacks = [];
    const resolve = (val) => {
      if (this.state !== "pending") return;
      this.state = "fulfilled"; this.value = val;
      this.callbacks.forEach(cb => cb.onFulfilled(val));
    };
    const reject = (err) => {
      if (this.state !== "pending") return;
      this.state = "rejected"; this.value = err;
      this.callbacks.forEach(cb => cb.onRejected(err));
    };
    executor(resolve, reject);
  }
  then(onFulfilled, onRejected) {
    return new MyPromise((resolve, reject) => {
      const handle = () => {
        if (this.state === "fulfilled") resolve(onFulfilled(this.value));
        if (this.state === "rejected") reject(onRejected ? onRejected(this.value) : this.value);
      };
      if (this.state === "pending") this.callbacks.push({ onFulfilled: handle, onRejected: handle });
      else handle();
    });
  }
}
```

Trace `new MyPromise(executor).then(f)`: the constructor runs `executor` right away, so if it calls `resolve` immediately, `state` is already `"fulfilled"` before `.then` even runs. `.then(f)` then sees `state !== "pending"` is false, calls `handle()` immediately, and resolves the new promise with `f(this.value)`. If the executor is asynchronous instead, `.then(f)` runs first, sees `"pending"`, and pushes onto `callbacks` to wait, `resolve` eventually drains that array and calls `f` later.

**bind and call, from scratch**

```js
Function.prototype.myBind = function (ctx, ...args1) {
  const fn = this;
  return (...args2) => fn.apply(ctx, [...args1, ...args2]);
};
Function.prototype.myCall = function (ctx, ...args) {
  ctx.fn = this;
  const result = ctx.fn(...args);
  delete ctx.fn;
  return result;
};
```

`myBind` never calls the function at all, it captures it in a closure and returns a new function that applies the original with `ctx` and the merged arguments whenever it's eventually called. `myCall` calls right away: it temporarily attaches the function to `ctx` so calling it as `ctx.fn(...)` makes `this` equal `ctx` inside it, then deletes that temporary property so it doesn't leak.

**Debounce and throttle**

```js
function debounce(fn, delay) {
  let timer;
  return (...args) => { clearTimeout(timer); timer = setTimeout(() => fn(...args), delay); };
}
function throttle(fn, limit) {
  let inThrottle;
  return (...args) => {
    if (!inThrottle) { fn(...args); inThrottle = true; setTimeout(() => inThrottle = false, limit); }
  };
}
```

**Fixing a fetch race condition in React**

```js
useEffect(() => {
  const controller = new AbortController();
  fetch(url, { signal: controller.signal }).then(setData);
  return () => controller.abort();
}, [query]);
```

If `query` changes again before the first fetch resolves, React runs the old effect's cleanup before the new one, aborting the stale request. That aborted fetch rejects instead of resolving, so its `setData` never fires, and only the response for the latest `query` ever reaches state.

> **Remember:** an aborted fetch rejects, it doesn't resolve with old data, that's the entire mechanism that keeps a stale response from ever overwriting a fresher one.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-recall-rebuild-q1", "type": "mcq",
      "prompt": "In the hand-written MyPromise class, what happens if the executor calls resolve() synchronously, before .then() is ever called?",
      "options": [
        {"id":"a","text":"The callback is lost forever since nothing was listening yet"},
        {"id":"b","text":"state is already \"fulfilled\" by the time .then() runs, so .then() sees state !== \"pending\" is false and calls handle() immediately instead of queuing it"},
        {"id":"c","text":"The constructor throws an error"},
        {"id":"d","text":"resolve() has no effect until .then() is called"}
      ],
      "correct": "b",
      "explanation": "The executor runs synchronously inside the constructor. If it resolves immediately, the promise is already settled before .then() is ever attached, so .then() takes the immediate-handle path instead of pushing onto the pending callbacks array." }
] }
```

## Live coding practice

Two prompts worth practicing timed, about 25 minutes each.

1. **Typeahead/autocomplete**: debounce the input, cancel stale requests, handle loading, error, and empty states, support keyboard navigation.
2. **Infinite scroll list**: use `IntersectionObserver`, avoid firing duplicate fetches, and be ready to mention virtualization once the data set gets large.

While practicing: think out loud, ask clarifying questions before writing code, get a brute-force version working before optimizing it, and narrate the edge cases you'd otherwise miss, money formatting and timezones especially, since those come up constantly in real products.

## Mock round: autocomplete search

Prompt: build a search input that fetches suggestions as the user types, shows a dropdown, and lets them pick a result with the mouse or the keyboard.

Clarifying questions worth asking first: should calls be debounced or throttled? Debounced, since only the final pause in typing actually matters. What happens if a slow response arrives late, after a faster, newer one? It must never overwrite the fresher result. Is keyboard navigation required? Yes: arrow keys, Enter to select, Escape to close. Does it need to be accessible? Yes, the ARIA combobox pattern plus screen-reader announcements.

```tsx
import { useState, useEffect, useMemo, useRef, useCallback } from "react";

interface Suggestion {
  id: string;
  label: string;
}

async function fetchSuggestions(query: string, signal: AbortSignal): Promise<Suggestion[]> {
  const res = await fetch(`/api/search?q=${encodeURIComponent(query)}`, { signal });
  if (!res.ok) throw new Error(`search failed: ${res.status}`);
  return res.json();
}

function useDebouncedValue<T>(value: T, delayMs: number): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delayMs);
    return () => clearTimeout(timer);
  }, [value, delayMs]);
  return debounced;
}

export function AutocompleteSearch({ onSelect }: { onSelect: (s: Suggestion) => void }) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<Suggestion[]>([]);
  const [activeIndex, setActiveIndex] = useState(-1);
  const [isOpen, setIsOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const debouncedQuery = useDebouncedValue(query, 250);
  const abortRef = useRef<AbortController | null>(null);

  useEffect(() => {
    if (!debouncedQuery.trim()) {
      setResults([]);
      setIsOpen(false);
      return;
    }
    abortRef.current?.abort();
    const controller = new AbortController();
    abortRef.current = controller;
    setLoading(true);
    fetchSuggestions(debouncedQuery, controller.signal)
      .then((data) => {
        setResults(data);
        setIsOpen(true);
        setActiveIndex(-1);
      })
      .catch((err) => {
        if (err.name !== "AbortError") console.error(err);
      })
      .finally(() => setLoading(false));
    return () => controller.abort();
  }, [debouncedQuery]);

  const listId = "autocomplete-listbox";

  const handleSelect = useCallback(
    (item: Suggestion) => {
      onSelect(item);
      setQuery(item.label);
      setIsOpen(false);
      setActiveIndex(-1);
    },
    [onSelect]
  );

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (!isOpen || results.length === 0) return;
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setActiveIndex((i) => Math.min(i + 1, results.length - 1));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setActiveIndex((i) => Math.max(i - 1, 0));
    } else if (e.key === "Enter" && activeIndex >= 0) {
      e.preventDefault();
      handleSelect(results[activeIndex]);
    } else if (e.key === "Escape") {
      setIsOpen(false);
    }
  };

  const visibleResults = useMemo(() => results.slice(0, 10), [results]);

  return (
    <div role="combobox" aria-expanded={isOpen} aria-owns={listId} aria-haspopup="listbox">
      <input
        type="text"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        onKeyDown={handleKeyDown}
        aria-autocomplete="list"
        aria-controls={listId}
        aria-activedescendant={activeIndex >= 0 ? `opt-${activeIndex}` : undefined}
        placeholder="Search..."
      />
      {loading && <span aria-live="polite">Loading…</span>}
      {isOpen && (
        <ul id={listId} role="listbox">
          {visibleResults.map((item, i) => (
            <li
              key={item.id}
              id={`opt-${i}`}
              role="option"
              aria-selected={i === activeIndex}
              onMouseDown={() => handleSelect(item)}
              style={{ background: i === activeIndex ? "#eee" : undefined }}
            >
              {item.label}
            </li>
          ))}
          {visibleResults.length === 0 && <li>No results</li>}
        </ul>
      )}
    </div>
  );
}
```

Why these choices: debounce, not throttle, because only the final pause in typing matters. `AbortController` cancels an in-flight request so a slow earlier response can never overwrite a faster later one, the exact out-of-order bug interviewers probe for. `useMemo` caps the rendered list at 10 items so a huge result set doesn't flood the DOM. `onMouseDown` instead of `onClick` on each option avoids the input's `onBlur` firing before the click actually registers. The ARIA combobox roles make it usable with a screen reader, not only with a mouse.

Rubric: did you sketch the state variables and data flow before writing code? Did you explicitly handle the abort/race condition, not just the empty-query case? Did you bring up accessibility unprompted, correct ARIA roles and keyboard support, rather than needing to be asked?

## Mock round: todo app

Prompt: build a Todo app, add, edit, delete, and toggle-complete tasks, with data that survives a page refresh.

Clarifying questions worth asking first: is `localStorage` an acceptable stand-in for persistence in a short round? Yes, just say you'd swap it for a REST API with optimistic updates given more time. Should completed todos look different? Yes, visually and filterable.

```tsx
import { useState, useEffect, useCallback } from "react";

interface Todo {
  id: string;
  text: string;
  completed: boolean;
}

const STORAGE_KEY = "todos";

function loadTodos(): Todo[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as Todo[]) : [];
  } catch {
    return [];
  }
}

export function TodoApp() {
  const [todos, setTodos] = useState<Todo[]>(loadTodos);
  const [draft, setDraft] = useState("");
  const [filter, setFilter] = useState<"all" | "active" | "completed">("all");

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(todos));
  }, [todos]);

  const addTodo = useCallback(() => {
    const text = draft.trim();
    if (!text) return;
    setTodos((prev) => [...prev, { id: crypto.randomUUID(), text, completed: false }]);
    setDraft("");
  }, [draft]);

  const toggleTodo = useCallback((id: string) => {
    setTodos((prev) => prev.map((t) => (t.id === id ? { ...t, completed: !t.completed } : t)));
  }, []);

  const deleteTodo = useCallback((id: string) => {
    setTodos((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const editTodo = useCallback((id: string, text: string) => {
    setTodos((prev) => prev.map((t) => (t.id === id ? { ...t, text } : t)));
  }, []);

  const visible = todos.filter((t) =>
    filter === "all" ? true : filter === "active" ? !t.completed : t.completed
  );

  return (
    <div className="todo-app">
      <h1>Todos</h1>
      <div className="todo-input-row">
        <input
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && addTodo()}
          placeholder="What needs doing?"
          aria-label="New todo"
        />
        <button onClick={addTodo}>Add</button>
      </div>

      <div className="todo-filters" role="tablist">
        {(["all", "active", "completed"] as const).map((f) => (
          <button
            key={f}
            role="tab"
            aria-selected={filter === f}
            onClick={() => setFilter(f)}
            className={filter === f ? "active" : ""}
          >
            {f}
          </button>
        ))}
      </div>

      <ul className="todo-list">
        {visible.map((todo) => (
          <TodoRow
            key={todo.id}
            todo={todo}
            onToggle={() => toggleTodo(todo.id)}
            onDelete={() => deleteTodo(todo.id)}
            onEdit={(text) => editTodo(todo.id, text)}
          />
        ))}
        {visible.length === 0 && <li className="empty">Nothing here.</li>}
      </ul>
    </div>
  );
}

function TodoRow({
  todo,
  onToggle,
  onDelete,
  onEdit,
}: {
  todo: Todo;
  onToggle: () => void;
  onDelete: () => void;
  onEdit: (text: string) => void;
}) {
  const [editing, setEditing] = useState(false);
  const [text, setText] = useState(todo.text);

  const commit = () => {
    const trimmed = text.trim();
    if (trimmed) onEdit(trimmed);
    setEditing(false);
  };

  return (
    <li className={todo.completed ? "completed" : ""}>
      <input type="checkbox" checked={todo.completed} onChange={onToggle} aria-label={`Mark ${todo.text} complete`} />
      {editing ? (
        <input
          value={text}
          autoFocus
          onChange={(e) => setText(e.target.value)}
          onBlur={commit}
          onKeyDown={(e) => e.key === "Enter" && commit()}
        />
      ) : (
        <span onDoubleClick={() => setEditing(true)}>{todo.text}</span>
      )}
      <button onClick={onDelete} aria-label={`Delete ${todo.text}`}>
        ×
      </button>
    </li>
  );
}
```

```css
.todo-app { max-width: 480px; margin: 2rem auto; font-family: system-ui, sans-serif; }
.todo-input-row { display: flex; gap: 0.5rem; margin-bottom: 1rem; }
.todo-input-row input { flex: 1; padding: 0.5rem; border: 1px solid #ccc; border-radius: 4px; }
.todo-filters { display: flex; gap: 0.5rem; margin-bottom: 1rem; }
.todo-filters button.active { font-weight: 600; text-decoration: underline; }
.todo-list { list-style: none; padding: 0; }
.todo-list li { display: flex; align-items: center; gap: 0.5rem; padding: 0.5rem 0; border-bottom: 1px solid #eee; }
.todo-list li.completed span { text-decoration: line-through; color: #999; }
.empty { color: #999; font-style: italic; }
```

Why these choices: all state lives in one `todos` array, a single source of truth, which is what makes persistence trivial, one `useEffect` on `todos` syncing to `localStorage` covers every mutation automatically. `crypto.randomUUID()` avoids array-index keys, which break identity the moment items get deleted or reordered. Inline editing toggles a local `editing` flag per row instead of lifting edit mode into the parent. This is a demo, not a production app, given more time, the real next step is a REST API with optimistic updates and rollback on error, plus debounced autosave instead of committing only on blur or Enter.

Rubric: are all four CRUD operations implemented and working? Does the data survive a refresh? Is it actually styled, not bare unstyled HTML? Are the React patterns correct, one source of truth, stable keys, no state duplicated unnecessarily?

## Mock round: rapid React theory Q&A

This round is pure question-and-answer, no coding.

**How does reconciliation actually work?** Reconciliation decides what really needs to change in the DOM when state updates. It diffs the new element tree against the previous one using two heuristics instead of a full generic tree comparison: if the element type at a position changes (`<div>` becomes `<span>`), React tears the whole subtree down and rebuilds it; if the type stays the same, React keeps the existing DOM node and patches only what changed, then recurses into the children. For a list, `key` is what tells React which child maps to which item across renders, without a stable key, React falls back to matching by position, which breaks badly the moment the list reorders or something is inserted, since state then attaches to the wrong item. Since React 16, this all runs on the Fiber architecture, work is broken into units that can be paused, resumed, or dropped by priority, which is exactly what makes `startTransition` possible.

```tsx
// Buggy: index as key. Deleting the first todo makes every remaining
// row's key shift by one, so React matches stale DOM (and any local
// state like an uncontrolled input's cursor position) to the wrong item.
{todos.map((todo, index) => (
  <TodoRow key={index} todo={todo} />
))}

// Correct: a stable identity that survives reordering and deletion.
{todos.map((todo) => (
  <TodoRow key={todo.id} todo={todo} />
))}
```

**When should you actually reach for `useMemo`?** It caches the result of an expensive computation between renders, recomputing only when a listed dependency changes. Two legitimate reasons to use it: a genuinely heavy synchronous computation, filtering, sorting, or transforming a large array, or preserving the identity of an object or array passed as a prop into a `React.memo`-wrapped child, or used as a dependency in another hook, since a fresh object literal on every render breaks that shallow-equality check. The trap: wrapping cheap computations in `useMemo` "just in case." The memoization itself costs a dependency comparison and a cache slot on every render. Profile first, and memoize the measured hot path, not everything by reflex.

**Walk through the component lifecycle.** Class components go through mounting (`constructor` then `render` then `componentDidMount`), updating (`render` then `componentDidUpdate`), and unmounting (`componentWillUnmount`, for cleanup). Function components map the same three phases onto `useEffect`, the effect body runs after render commits, and its returned function is the cleanup, running before the next effect and on unmount. The dependency array decides which phase applies: `[]` means mount-once and unmount-once, no array means every render, `[x]` means mount plus whenever `x` changes. The most common trap: forgetting the cleanup function, listeners, subscriptions, and timers that never get torn down, a leak that was harder to accidentally skip in the class-based version.

Rubric: did the reconciliation answer cover type-change teardown, key-based matching, and Fiber's interruptibility, with a concrete example? Did the `useMemo` answer name both legitimate use cases and the overuse trap? Did the lifecycle answer correctly map every class method to its hook equivalent, including the cleanup-forgetting trap?

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-recall-theory-q1", "type": "mcq",
      "prompt": "A list uses key={index}, and deleting the first item causes every remaining row to lose its local input state. What's the actual mechanism behind this bug?",
      "options": [
        {"id":"a","text":"React deletes all DOM nodes whenever any array changes"},
        {"id":"b","text":"Deleting the first item shifts every remaining item's index down by one; since the key is the index, React matches each row to the wrong prior element, misattributing local state along with it"},
        {"id":"c","text":"Arrays can't be mapped to JSX elements at all"},
        {"id":"d","text":"This only happens if the list has more than 100 items"}
      ],
      "correct": "b",
      "explanation": "React's reconciliation matches elements by key across renders. When the key is just the position, deleting an early item shifts every later item's key, so React thinks each remaining row is a different logical item than it actually is." }
] }
```

## Mock round: task list, frontend half

The backend half of this prompt builds a small task list API. This is the frontend consuming it: React, TSX, optimistic updates with rollback on failure.

```tsx
import { useState, useEffect, useCallback, FormEvent } from "react";

interface Task {
  id: string;
  title: string;
  done: boolean;
}

async function apiFetch<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`/api${path}`, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.detail ?? `request failed: ${res.status}`);
  }
  if (res.status === 204) return undefined as T;
  return res.json();
}

export function TaskList() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [title, setTitle] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setTasks(await apiFetch<Task[]>("/tasks"));
    } catch (err) {
      setError(err instanceof Error ? err.message : "failed to load tasks");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;
    setSubmitting(true);
    setError(null);
    try {
      const created = await apiFetch<Task>("/tasks", {
        method: "POST",
        body: JSON.stringify({ title }),
      });
      setTasks((prev) => [...prev, created]);
      setTitle("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "failed to create task");
    } finally {
      setSubmitting(false);
    }
  };

  const toggleTask = async (id: string) => {
    const snapshot = tasks;
    setTasks((cur) => cur.map((t) => (t.id === id ? { ...t, done: !t.done } : t)));
    try {
      await apiFetch<Task>(`/tasks/${id}`, { method: "PATCH" });
    } catch (err) {
      setTasks(snapshot); // roll back the optimistic flip
      setError(err instanceof Error ? err.message : "failed to update task");
    }
  };

  const deleteTask = async (id: string) => {
    const snapshot = tasks;
    setTasks((cur) => cur.filter((t) => t.id !== id));
    try {
      await apiFetch<void>(`/tasks/${id}`, { method: "DELETE" });
    } catch (err) {
      setTasks(snapshot); // roll back the optimistic removal
      setError(err instanceof Error ? err.message : "failed to delete task");
    }
  };

  if (loading) return <p>Loading tasks…</p>;

  return (
    <div>
      {error && (
        <p role="alert" style={{ color: "red" }}>
          {error}
        </p>
      )}
      <form onSubmit={handleSubmit}>
        <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="New task" />
        <button type="submit" disabled={submitting}>
          Add
        </button>
      </form>
      <ul>
        {tasks.map((t) => (
          <li key={t.id}>
            <label>
              <input type="checkbox" checked={t.done} onChange={() => toggleTask(t.id)} />
              <span style={{ textDecoration: t.done ? "line-through" : undefined }}>{t.title}</span>
            </label>
            <button onClick={() => deleteTask(t.id)}>Delete</button>
          </li>
        ))}
      </ul>
      {tasks.length === 0 && <p>No tasks yet.</p>}
    </div>
  );
}
```

Why these choices: toggling and deleting update local state immediately, an optimistic update, but keep a snapshot of the prior state so a server rejection rolls the UI back exactly. `load` and `handleSubmit` are not optimistic, there's nothing to show before the first fetch, and a created item's real ID only exists once the server assigns it. Every network call goes through one `apiFetch` helper, so error handling isn't reinvented five separate times with five separate bugs. `disabled={submitting}` stops a double-click from firing a duplicate submit.

Rubric: did the frontend handle loading and error states explicitly, not just the happy path, and did the rollback on a failed mutation actually work?

## An architecture round, worked through in full

Structure every architecture answer the same way: **requirements, then data flow, then component breakdown, then state management, then performance, then edge cases.**

Prep this one all the way through: *"Design a real-time shipment tracking dashboard."* Data: decide between polling and a WebSocket or SSE for live updates, and be ready to say why. State: a query library for server-side cache, a lighter local or client store for UI-only state. Large lists: virtualization plus server-side pagination and filtering. Optimistic updates for status-change actions, with rollback on failure. Errors, loading, and empty states handled consistently everywhere, not invented fresh per screen.

Know these at a two-minute depth: Module Federation for sharing components across independently deployed frontends; route-based code splitting with `React.lazy`/`Suspense`; money handling, avoid floats, use integers or a decimal library; and a contract-first process (OpenAPI) with error shapes agreed on between frontend and backend ahead of time.

## Personal stories worth rehearsing out loud

Practice each of these under 90 seconds, spoken, not just thought through silently.

1. A frontend/backend collaboration moment, shaping an API contract together, or landing a performance fix that needed both sides.
2. A story involving a third-party API integration, covering the loading and latency UX, retries, and error handling for when that external service fails.

## Questions worth asking back

How is the frontend structured across teams, a shared library, one monorepo, or separate deployables? What does the real-time data pipeline actually look like in production? What's the team's biggest current frontend scaling or performance challenge? Is there a spec-first process for the frontend and backend to agree on an API contract before either side builds it?

## Cheat sheet

| Topic | One-liner |
|---|---|
| Closures | A function plus its captured scope. `let` in a loop gives each iteration its own binding. |
| bind/call/apply | `call`/`apply` invoke right away, differing only in args-as-list versus args-as-array. `bind` returns a new function instead of invoking anything. |
| Promises | States: pending, fulfilled, rejected. `.then` callbacks run through the microtask queue. |
| Race conditions | Fix with an `AbortController` created inside `useEffect` and aborted in its cleanup. |
| Reconciliation | Type-then-key matching, updates applied in a batch. |
| useMemo/useCallback | Worth it only for expensive computation or referential stability, not by reflex. |
| React.memo | Shallow prop comparison. Breaks the moment a new literal is passed every render. |
| Query library vs. client store | Server cache versus client/UI state, two different jobs. |
| Module Federation | Share code across independently deployed frontends. |
| Optimistic UI | Update immediately, roll back on failure. |
| Money | Integers/cents, or a decimal library, never raw floats. |
| Virtualization | Render only the visible rows. |
