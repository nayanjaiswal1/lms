---
kind: lesson
id_key: interview-prep-45/day-27-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "React Patterns"
position: 30
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---

"Explain compound components" and "when would you use a render prop instead of a custom hook" are recurring senior-level interview questions — they test whether you understand React's composition model beyond writing individual components. Today covers compound components, render props, HOCs, and custom hooks: what each buys you, and which of them modern React has mostly superseded.

## Compound components

A compound component splits one logical UI unit into multiple components that share implicit state through context, letting the caller compose the internal structure freely while the components coordinate behavior behind the scenes — the same relationship as native `<select>` and `<option>`.

```tsx
import { createContext, useContext, useState, type ReactNode } from "react";

interface TabsContextValue {
  activeTab: string;
  setActiveTab: (id: string) => void;
}

const TabsContext = createContext<TabsContextValue | null>(null);

function useTabsContext() {
  const ctx = useContext(TabsContext);
  if (!ctx) throw new Error("Tabs.* components must be used inside <Tabs>");
  return ctx;
}

function Tabs({ defaultTab, children }: { defaultTab: string; children: ReactNode }) {
  const [activeTab, setActiveTab] = useState(defaultTab);
  return (
    <TabsContext.Provider value={{ activeTab, setActiveTab }}>
      <div className="tabs">{children}</div>
    </TabsContext.Provider>
  );
}

function TabList({ children }: { children: ReactNode }) {
  return <div role="tablist">{children}</div>;
}

function Tab({ id, children }: { id: string; children: ReactNode }) {
  const { activeTab, setActiveTab } = useTabsContext();
  return (
    <button
      role="tab"
      aria-selected={activeTab === id}
      onClick={() => setActiveTab(id)}
    >
      {children}
    </button>
  );
}

function TabPanel({ id, children }: { id: string; children: ReactNode }) {
  const { activeTab } = useTabsContext();
  if (activeTab !== id) return null;
  return <div role="tabpanel">{children}</div>;
}

Tabs.List = TabList;
Tabs.Tab = Tab;
Tabs.Panel = TabPanel;

export { Tabs };
```

```tsx
// Usage — the caller controls composition and order freely,
// Tabs doesn't need to know how many tabs exist or accept a `tabs` prop array
<Tabs defaultTab="profile">
  <Tabs.List>
    <Tabs.Tab id="profile">Profile</Tabs.Tab>
    <Tabs.Tab id="settings">Settings</Tabs.Tab>
  </Tabs.List>
  <Tabs.Panel id="profile">Profile content</Tabs.Panel>
  <Tabs.Panel id="settings">Settings content</Tabs.Panel>
</Tabs>
```

**When to use it:** when a component's children need to share implicit state and the caller benefits from controlling structure/order/spacing directly in JSX, rather than passing a config array through a single `tabs` prop. Radix UI, React Aria, and Reach UI are all built almost entirely on this pattern — naming them is a strong signal you've read real library source, not just tutorials.

**Trade-off:** the child components are coupled to the parent's context — `Tabs.Tab` used outside `<Tabs>` throws (by design, via the `useTabsContext` guard above), which is a real constraint on reuse compared to a fully standalone component.

## Render props

A render prop is a prop whose value is a function that returns JSX — it lets a component share stateful logic while leaving the actual rendering entirely to the caller.

```tsx
interface MousePositionProps {
  render: (position: { x: number; y: number }) => ReactNode;
}

function MousePosition({ render }: MousePositionProps) {
  const [position, setPosition] = useState({ x: 0, y: 0 });

  useEffect(() => {
    function handleMove(e: MouseEvent) {
      setPosition({ x: e.clientX, y: e.clientY });
    }
    window.addEventListener("mousemove", handleMove);
    return () => window.removeEventListener("mousemove", handleMove);
  }, []);

  return <>{render(position)}</>;
}

// Usage
<MousePosition render={({ x, y }) => <p>Mouse at {x}, {y}</p>} />
```

**This pattern predates hooks and is largely superseded by them.** The same logic as a custom hook:

```tsx
function useMousePosition() {
  const [position, setPosition] = useState({ x: 0, y: 0 });
  useEffect(() => {
    function handleMove(e: MouseEvent) {
      setPosition({ x: e.clientX, y: e.clientY });
    }
    window.addEventListener("mousemove", handleMove);
    return () => window.removeEventListener("mousemove", handleMove);
  }, []);
  return position;
}

// Usage — no wrapper component, no extra nesting, no children-as-function
function Cursor() {
  const { x, y } = useMousePosition();
  return <p>Mouse at {x}, {y}</p>;
}
```

**Interview-important distinction:** render props still earn their place today specifically when a library needs to expose behavior to consumers who might not be using hooks-compatible setups, or when the shared logic needs to control *where in the tree* something renders (not just provide data) — React Router's `<Route render={...}>` (legacy API) and headless UI libraries sometimes still use this for exactly that reason. But for the common case of "share some stateful logic across components," a custom hook is strictly less nesting, easier to read, and the answer most interviewers are looking for today.

## Higher-order components (HOCs)

An HOC is a function that takes a component and returns a new component with added behavior/props — composition by wrapping, rather than by nesting JSX.

```tsx
function withAuth<P extends object>(Wrapped: React.ComponentType<P>) {
  return function WithAuthComponent(props: P) {
    const { user, isLoading } = useAuth();

    if (isLoading) return <Spinner />;
    if (!user) return <Navigate to="/login" />;

    return <Wrapped {...props} />;
  };
}

// Usage
const ProtectedDashboard = withAuth(Dashboard);
```

**Known problems this pattern has, which is why hooks largely replaced it:**

- **Wrapper hell** — stacking several HOCs (`withAuth(withTheme(withLogging(Component)))`) produces deeply nested component trees that are hard to read in DevTools and hard to trace prop flow through.
- **Prop name collisions** — two HOCs both injecting a prop called `data` silently overwrite each other with no compile-time warning.
- **Static type inference gets awkward** — correctly typing the props an HOC adds/consumes/passes through in TypeScript is meaningfully harder than typing a hook's return value.

```tsx
// The equivalent as a hook — no wrapping component, no prop injection,
// the consuming component stays explicit about what it uses
function ProtectedDashboard() {
  const { user, isLoading } = useAuth();
  if (isLoading) return <Spinner />;
  if (!user) return <Navigate to="/login" />;
  return <Dashboard />;
}
```

**When HOCs still make sense:** wrapping a *third-party* component you can't modify (can't add a hook call inside someone else's component), or genuinely cross-cutting concerns applied uniformly across many unrelated components at the routing/composition layer (e.g., `connect()` from older Redux, still seen in legacy codebases). For new code you control, a hook covers the same need with less indirection.

## Custom hooks

A custom hook is just a function that starts with `use` and calls other hooks — it extracts stateful logic so it can be reused across components without changing the component tree shape at all, which is the core advantage over both render props and HOCs.

```tsx
function useDebouncedValue<T>(value: T, delayMs: number): T {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timeout = setTimeout(() => setDebounced(value), delayMs);
    return () => clearTimeout(timeout);
  }, [value, delayMs]);

  return debounced;
}

// Usage
function SearchBox() {
  const [query, setQuery] = useState("");
  const debouncedQuery = useDebouncedValue(query, 300);

  useEffect(() => {
    if (debouncedQuery) searchApi(debouncedQuery);
  }, [debouncedQuery]);

  return <input value={query} onChange={(e) => setQuery(e.target.value)} />;
}
```

Custom hooks compose cleanly with each other (a hook can call other hooks) and don't add any nesting to the render tree, which is precisely what makes them the default answer to "how do I share this stateful logic" over both older patterns.

## When to use each — a decision table

| Need | Pattern |
|---|---|
| Share stateful logic across components, no rendering control needed | Custom hook — default choice |
| Consumer needs implicit shared state across a fixed set of composed children (tabs, accordion, select) | Compound components |
| A library needs to hand rendering control to the consumer, or must support non-hook consumers | Render props |
| Wrapping a third-party component you can't add hooks to, or a legacy codebase already using the pattern | HOC |

## Patterns in popular libraries

- **Compound components:** Radix UI (`Accordion.Item`, `Accordion.Trigger`), React Aria, Reach UI, native `<select>`/`<option>`.
- **Render props (legacy/still-alive cases):** React Router v5's `<Route render={...}>`, Formik's `<Field>` render-prop mode, Downshift's headless combobox API.
- **HOCs:** Redux's `connect()`, `React.memo` and `React.forwardRef` are themselves technically HOC-shaped utilities built into React.
- **Custom hooks:** virtually every modern library now ships a hooks-first API — React Query/TanStack Query (`useQuery`), React Hook Form (`useForm`), Zustand (`useStore`) — this is the dominant pattern in 2026-era React libraries.

## Key takeaways

- Compound components share implicit state via context across a fixed family of subcomponents, letting the caller freely control JSX structure — used throughout headless UI libraries like Radix.
- Render props predate hooks and are largely superseded by them for the common "share stateful logic" case; they still matter when a library must hand rendering control to the consumer.
- HOCs cause wrapper hell and silent prop-name collisions; hooks solve the same problem without adding nesting — HOCs remain useful mainly for wrapping third-party components you can't modify.
- Custom hooks are the default modern answer for sharing stateful logic — no tree nesting, clean composition, straightforward TypeScript inference.
- The "when to use each" answer an interviewer wants: hooks by default, compound components for fixed-family shared-state UI, render props/HOCs only for the specific legacy or third-party-wrapping cases they still solve better.
- Naming real libraries (Radix, TanStack Query, React Hook Form) as examples of each pattern is a stronger signal than describing the pattern in the abstract.
