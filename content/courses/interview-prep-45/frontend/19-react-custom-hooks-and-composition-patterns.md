---
kind: lesson
id_key: interview-prep-45/day-27-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "React Custom Hooks and Composition Patterns"
position: 19
estimated_minutes: 40
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---
"Explain compound components" and "when would you reach for a render prop instead of a custom hook" are recurring senior-level questions, and they're testing React's composition model beyond writing individual components. This lesson covers compound components, render props, HOCs, and custom hooks, what each buys you and which of them modern React has mostly superseded, then puts custom hooks to work on the patterns you'll actually reach for day to day: debouncing, fetching with cancellation, and form state.

## Compound components: implicit shared state, explicit structure

A compound component splits one logical UI unit into several components that share state through context, letting the caller compose the internal structure freely while the pieces coordinate behind the scenes. It's the same relationship native `<select>` and `<option>` already have.

```tsx
const TabsContext = createContext<{ activeTab: string; setActiveTab: (id: string) => void } | null>(null);
function useTabsContext() {
  const ctx = useContext(TabsContext);
  if (!ctx) throw new Error("Tabs.* components must be used inside <Tabs>");
  return ctx;
}

function Tabs({ defaultTab, children }: { defaultTab: string; children: ReactNode }) {
  const [activeTab, setActiveTab] = useState(defaultTab);
  return <TabsContext.Provider value={{ activeTab, setActiveTab }}><div className="tabs">{children}</div></TabsContext.Provider>;
}
function TabList({ children }: { children: ReactNode }) {
  return <div role="tablist">{children}</div>;
}
function Tab({ id, children }: { id: string; children: ReactNode }) {
  const { activeTab, setActiveTab } = useTabsContext();
  return <button role="tab" aria-selected={activeTab === id} onClick={() => setActiveTab(id)}>{children}</button>;
}
function TabPanel({ id, children }: { id: string; children: ReactNode }) {
  const { activeTab } = useTabsContext();
  return activeTab === id ? <div role="tabpanel">{children}</div> : null;
}
Tabs.List = TabList;
Tabs.Tab = Tab;
Tabs.Panel = TabPanel;
```

```tsx
// the caller controls composition and order freely — Tabs doesn't need to
// know how many tabs exist or accept a `tabs` prop array
<Tabs defaultTab="profile">
  <Tabs.List>
    <Tabs.Tab id="profile">Profile</Tabs.Tab>
    <Tabs.Tab id="settings">Settings</Tabs.Tab>
  </Tabs.List>
  <Tabs.Panel id="profile">Profile content</Tabs.Panel>
  <Tabs.Panel id="settings">Settings content</Tabs.Panel>
</Tabs>
```

Reach for this when children need to share implicit state and the caller benefits from controlling structure and order directly in JSX, rather than a config array passed through a single `tabs` prop. Radix UI, React Aria, and Reach UI are built almost entirely on this pattern, naming them is a stronger signal than describing the pattern in the abstract. The trade-off: `Tabs.Tab` used outside `<Tabs>` throws by design, via the `useTabsContext` guard, which is a real constraint on reuse compared to a fully standalone component.

The same context-sharing idea generalizes past tabs, any parent/child pair with implicit shared state, an accordion and its items, a theme provider and its consumers, follows the identical shape: a context created once, a `Provider` at the top holding the state, and children reading from `useContext` instead of receiving props threaded down by hand.

## Render props: mostly superseded, still alive at the edges

A render prop is a prop whose value is a function returning JSX, letting a component share stateful logic while leaving the actual rendering to the caller.

```tsx
function MousePosition({ render }: { render: (pos: { x: number; y: number }) => ReactNode }) {
  const [position, setPosition] = useState({ x: 0, y: 0 });
  useEffect(() => {
    const handleMove = (e: MouseEvent) => setPosition({ x: e.clientX, y: e.clientY });
    window.addEventListener("mousemove", handleMove);
    return () => window.removeEventListener("mousemove", handleMove);
  }, []);
  return <>{render(position)}</>;
}
```

This pattern predates hooks, and the identical logic as a hook needs no wrapper component, no extra nesting, no children-as-function ceremony:

```tsx
function useMousePosition() {
  const [position, setPosition] = useState({ x: 0, y: 0 });
  useEffect(() => {
    const handleMove = (e: MouseEvent) => setPosition({ x: e.clientX, y: e.clientY });
    window.addEventListener("mousemove", handleMove);
    return () => window.removeEventListener("mousemove", handleMove);
  }, []);
  return position;
}
```

Render props still earn their place specifically when a library needs to expose behavior to consumers who might not be in a hooks-compatible setup, or when the shared logic needs to control *where* in the tree something renders, not just supply data. For the common case of sharing stateful logic across components, a custom hook is less nesting and the answer most interviews are actually looking for today.

## HOCs: composition by wrapping

A higher-order component takes a component and returns a new one with added behavior.

```tsx
function withAuth<P extends object>(Wrapped: React.ComponentType<P>) {
  return function WithAuthComponent(props: P) {
    const { user, isLoading } = useAuth();
    if (isLoading) return <Spinner />;
    if (!user) return <Navigate to="/login" />;
    return <Wrapped {...props} />;
  };
}
const ProtectedDashboard = withAuth(Dashboard);
```

Hooks mostly replaced this for three concrete reasons: stacking several HOCs produces deeply nested trees that are hard to trace prop flow through in DevTools, often called wrapper hell; two HOCs both injecting a prop called `data` silently clobber each other with no compile-time warning; and correctly typing what an HOC adds, consumes, and passes through is meaningfully harder in TypeScript than typing a hook's return value. The equivalent as a hook has no wrapping component and no prop injection at all:

```tsx
function ProtectedDashboard() {
  const { user, isLoading } = useAuth();
  if (isLoading) return <Spinner />;
  if (!user) return <Navigate to="/login" />;
  return <Dashboard />;
}
```

HOCs still make sense wrapping a third-party component you can't modify, since you can't add a hook call inside someone else's component, or for a genuinely cross-cutting concern applied uniformly at a routing or composition layer, `connect()` from older Redux is the standard example still seen in legacy code. For new code you control, a hook covers the same need with less indirection.

## Custom hooks: the default answer

A custom hook is just a function that starts with `use` and calls other hooks, extracting stateful logic so it's reusable without changing the shape of the component tree at all, the core advantage over both patterns above. The rest of this lesson is worked examples.

### useDebounce: waiting for quiet

```js
function useDebounce(state, delay) {
  const [debounce, setDebounce] = useState(state); // seed with the initial value, not undefined
  useEffect(() => {
    const timer = setTimeout(() => setDebounce(state), delay);
    return () => clearTimeout(timer); // cancel the stale timer on every re-run or unmount
  }, [state, delay]);
  return debounce;
}
```

The input updates instantly, `value` is a normal controlled state, but the debounced value, and whatever effect depends on it, only fires once activity pauses for the full delay, because every keystroke cancels the previous timer via the cleanup function before a new one starts.

That's the trailing case, and it's the default, but it's worth being precise about the other two, since "what's the difference between debounce and throttle" is often a two-part question in disguise. **Leading** fires the *first* event in a burst immediately, then swallows everything else in that window, good for ignoring rapid double-clicks: the first click registers, the rest don't. **Leading + trailing** fires immediately *and* fires one final call with the latest arguments if more events arrived during the window, rare, but useful when you want instant feedback and a guaranteed final sync.

```ts
function debounce(fn: (...a: any[]) => void, ms: number, opts: { leading?: boolean; trailing?: boolean } = { trailing: true }) {
  let timer: ReturnType<typeof setTimeout> | null = null;
  return (...args: any[]) => {
    const callNow = opts.leading && !timer;
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => { timer = null; if (opts.trailing) fn(...args); }, ms);
    if (callNow) fn(...args);
  };
}
```

Debounce's timer resets on every new event, each call clears the previous `setTimeout` and starts fresh, which is exactly why a steady stream of events under trailing debounce never fires at all until the stream stops for one full, uninterrupted window. **Throttle** is the opposite discipline: no matter how many events arrive, act at most once every N ms, and the clock doesn't reset. Leading (lodash's default) fires immediately at the start of the interval, then ignores calls until it ends, good for scroll-position tracking where you want the first update instantly. **Trailing** throttle fires nothing until the interval ends, then fires once with whatever the latest call's arguments were, more initial delay, but guaranteed freshest state at each tick. **Leading + trailing** fires at the start of the interval, and if calls kept arriving during it, fires once more at the end with the latest arguments, the combination a window-resize handler usually wants: instant feedback, plus a final accurate value once resizing settles.

```ts
function throttle(fn: (...a: any[]) => void, ms: number, opts: { leading?: boolean; trailing?: boolean } = { leading: true, trailing: true }) {
  let last = 0;
  let timer: ReturnType<typeof setTimeout> | null = null;
  let lastArgs: any[] | null = null;
  return (...args: any[]) => {
    const now = Date.now();
    if (!last && !opts.leading) last = now;
    const remaining = ms - (now - last);
    if (remaining <= 0) {
      if (timer) { clearTimeout(timer); timer = null; }
      last = now;
      fn(...args);
    } else if (opts.trailing) {
      lastArgs = args;
      if (!timer) {
        timer = setTimeout(() => {
          last = opts.leading ? Date.now() : 0;
          timer = null;
          if (lastArgs) fn(...lastArgs);
        }, remaining);
      }
    }
  };
}
```

Trace a burst of calls arriving faster than `ms`: the first call sees `remaining <= 0` (nothing has run yet), so it calls `fn` immediately and sets `last` to now. The next few calls land while `remaining` is still positive, so instead of calling `fn` they update `lastArgs` and schedule one `setTimeout` for whatever time is left in the window. When that timeout fires, it calls `fn` once with the most recent `lastArgs`, then resets `last`. A whole burst collapses into exactly one leading call and, if `trailing` is on, one trailing call at the end. Throttle's clock runs on a fixed schedule, independent of how many events arrive; it doesn't reset per event the way debounce's timer does.

The one-line way to keep the two straight for an interview: debounce waits for inactivity because its timer resets on every event; throttle waits for a fixed clock tick because its timer never resets mid-interval. Knowing the actual flag names, `_.debounce(fn, ms, { leading, trailing })` and `_.throttle(fn, ms, { leading, trailing })`, is usually what separates a confident answer from a hand-wavy one.

### useFetch: the race condition a naive version misses

If `url` changes quickly, a dropdown flipping from option A to option B, a slow response for A can resolve *after* B's response arrives and incorrectly overwrite the UI with stale data. That's a race condition, and `AbortController` is the fix.

```js
function useFetch(url) {
  const [apiData, setData] = useState([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const control = new AbortController();
    (async () => {
      setLoading(true);
      try {
        const response = await fetch(url, { signal: control.signal });
        setData(await response.json());
      } catch (err) {
        if (err.name !== "AbortError") setError(err); // don't surface a cancelled request as a real error
      } finally {
        setLoading(false);
      }
    })();
    return () => control.abort(); // cancels the in-flight request when url changes or the component unmounts
  }, [url]);

  return { apiData, error, loading };
}
```

Without the `AbortController`, whichever request happens to resolve last wins, even if it wasn't the last one started, which is exactly how the UI ends up showing outdated data for the option the user isn't even looking at anymore.

### useLocalStorage: the falsy-value trap hiding in plain sight

```js
function useLocalStorage(key, initialValue) {
  const [data, setData] = useState(() => {
    const stored = localStorage.getItem(key); // check the raw STRING before parsing
    return stored ? JSON.parse(stored) : initialValue;
  });
  useEffect(() => { localStorage.setItem(key, JSON.stringify(data)); }, [data]);
  return [data, setData];
}
```

Three bugs this version avoids on purpose. `localStorage` only stores strings, so writes need `JSON.stringify` and reads need `JSON.parse`. Checking truthiness *after* parsing breaks for a legitimately falsy stored value, `JSON.parse("0")` is `0`, which is falsy, so checking the raw string first sidesteps it, since `JSON.stringify` never produces an empty string for any valid value. And the lazy `useState(() => ...)` initializer form ensures `localStorage` is read exactly once, on mount, rather than on every single render.

## The stale closure bug, and why it's not really about React

```jsx
function Counter() {
  const [count, setCount] = useState(0);
  useEffect(() => {
    setInterval(() => {
      setCount(count + 1); // `count` is captured at the effect's FIRST run — always 0
    }, 1000);
  }, []);
  return <div>{count}</div>;
}
```

This increments once and then freezes forever. The closure inside `setInterval` captured `count` as it was when the effect first ran, `0`, and because the dependency array is empty, the effect never re-runs to capture a fresh value. Every tick after the first is still adding `1` to that original `0`.

```jsx
useEffect(() => {
  const timer = setInterval(() => {
    setCount((q) => q + 1); // functional update — always reads the CURRENT state
  }, 1000);
  return () => clearInterval(timer); // cleanup prevents a leak on unmount
}, []);
```

Two things get fixed at once here. The stale closure is fixed by using the functional update form, `setState(prev => ...)`, instead of referencing the closed-over variable directly, so every tick reads whatever state is actually current rather than whatever it was when the effect first ran. The memory leak is fixed separately, always clear intervals, timeouts, and subscriptions in the effect's cleanup function.

## A form hook, validated once, not scattered per field

Centralizing validation is the other place custom hooks pull their weight. Instead of an `if` check duplicated in every field's `onChange`, one hook (or one schema) owns the rules:

```tsx
function useValidatedForm<T extends Record<string, string>>(initial: T, rules: { [K in keyof T]?: (v: string) => string | undefined }) {
  const [values, setValues] = useState(initial);
  const [errors, setErrors] = useState<Partial<Record<keyof T, string>>>({});

  const setField = (field: keyof T, value: string) => {
    setValues(prev => ({ ...prev, [field]: value }));
    setErrors(prev => ({ ...prev, [field]: undefined })); // clear that field's error on edit
  };

  const validate = () => {
    const next: typeof errors = {};
    for (const key in rules) {
      const message = rules[key]?.(values[key]);
      if (message) next[key] = message;
    }
    setErrors(next);
    return Object.keys(next).length === 0;
  };

  return { values, errors, setField, validate };
}
```

Controlled inputs, value and `onChange` both wired to state, keep the component always reflecting the current form state exactly, and re-validating on every keystroke rather than on blur or submit is the thing that starts to feel slow past a handful of fields. **React Hook Form** is the production answer to that specific cost: it keeps inputs uncontrolled internally and only re-renders on submit or blur, worth naming directly as the answer to "how would you make this scale to a big form."

## Deciding which pattern fits

| Need | Pattern |
|---|---|
| Share stateful logic across components, no rendering control needed | Custom hook, the default choice |
| Consumer needs implicit shared state across a fixed set of composed children (tabs, accordion, select) | Compound components |
| A library needs to hand rendering control to the consumer, or must support non-hook consumers | Render props |
| Wrapping a third-party component you can't add hooks to, or a legacy codebase already using the pattern | HOC |

Compound components: Radix UI, React Aria, native `<select>`/`<option>`. Render props, mostly legacy: React Router v5's `<Route render={...}>`, Downshift's headless combobox API. HOCs: Redux's `connect()`; `React.memo` and `React.forwardRef` are themselves technically HOC-shaped utilities built into React. Custom hooks: virtually every modern library ships a hooks-first API now, TanStack Query's `useQuery`, React Hook Form's `useForm`, Zustand's `useStore`. Naming real libraries as examples of each pattern reads as stronger than describing the pattern purely in the abstract.
