---
kind: lesson
id_key: interview-prep-45/day-12-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Day 12 — TypeScript for React"
position: 15
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---

Most production React codebases are TypeScript now, and interviewers routinely ask you to type a component, a hook, or an API response live. Today is about the patterns that come up constantly: typing props and generics, the utility types you'll reach for weekly, event handler types, and building type-safe API boundaries.

## Typing props: the basics

```tsx
interface ButtonProps {
  label: string;
  onClick: () => void;
  variant?: "primary" | "secondary" | "danger"; // union, not string
  disabled?: boolean;
  children?: React.ReactNode;
}

function Button({ label, onClick, variant = "primary", disabled, children }: ButtonProps) {
  return (
    <button className={`btn btn-${variant}`} onClick={onClick} disabled={disabled}>
      {children ?? label}
    </button>
  );
}
```

Prefer `interface` for props (extendable, better error messages) over `type`, though both work — this is a style convention, not a hard rule, and interviewers care more that you're consistent than which one you pick.

`React.ReactNode` vs `React.ReactElement` is a common trip-up:
- `ReactNode` — anything renderable: elements, strings, numbers, arrays, `null`, `undefined`, booleans. Use for `children`.
- `ReactElement` — specifically the result of `<Foo />` or `React.createElement`. Use when you need to clone or inspect an element (e.g., `React.cloneElement`), not for general children.

## Generic components

A generic component lets the caller determine a type parameter, so the component stays reusable without falling back to `any`.

```tsx
interface SelectProps<T> {
  items: T[];
  value: T;
  onChange: (value: T) => void;
  getLabel: (item: T) => string;
  getKey: (item: T) => string | number;
}

function Select<T>({ items, value, onChange, getLabel, getKey }: SelectProps<T>) {
  return (
    <select
      value={getKey(value)}
      onChange={(e) => {
        const selected = items.find((item) => String(getKey(item)) === e.target.value);
        if (selected) onChange(selected);
      }}
    >
      {items.map((item) => (
        <option key={getKey(item)} value={getKey(item)}>
          {getLabel(item)}
        </option>
      ))}
    </select>
  );
}

// Usage — T is inferred as User, no explicit type argument needed
interface User {
  id: number;
  name: string;
}

function UserPicker({ users, selected, onSelect }: {
  users: User[];
  selected: User;
  onSelect: (u: User) => void;
}) {
  return (
    <Select
      items={users}
      value={selected}
      onChange={onSelect}
      getLabel={(u) => u.name}
      getKey={(u) => u.id}
    />
  );
}
```

**Interview detail:** generic component syntax in `.tsx` files needs a trailing comma (`<T,>`) or a `extends unknown` constraint in arrow-function form to disambiguate from JSX:

```tsx
// Arrow function generic component — needs the comma or constraint
const List = <T,>({ items }: { items: T[] }) => (
  <ul>{items.map((i, idx) => <li key={idx}>{String(i)}</li>)}</ul>
);

// Function declaration form doesn't have this ambiguity
function List2<T>({ items }: { items: T[] }) {
  return <ul>{items.map((i, idx) => <li key={idx}>{String(i)}</li>)}</ul>;
}
```

## Utility types you'll actually use

```ts
interface Product {
  id: string;
  name: string;
  price: number;
  description: string;
  inStock: boolean;
}

// Partial — every field optional. Useful for update/patch payloads.
function updateProduct(id: string, changes: Partial<Product>) { /* ... */ }
updateProduct("p1", { price: 29.99 }); // no need to pass every field

// Required — every field mandatory, even ones declared optional on the source type.
interface DraftProduct extends Partial<Product> {}
function publishProduct(draft: Required<DraftProduct>) { /* all fields must be present */ }

// Pick — a subset of fields, useful for narrow view models.
type ProductSummary = Pick<Product, "id" | "name" | "price">;

// Omit — everything except the listed fields.
type ProductWithoutDescription = Omit<Product, "description">;

// Record — a typed dictionary/map.
type ProductsById = Record<string, Product>;

// Readonly — immutable view, useful for props you never want mutated.
function renderProduct(p: Readonly<Product>) { /* p.price = 0; // error */ }
```

| Utility | What it does | Typical use |
|---|---|---|
| `Partial<T>` | All props optional | Patch/update payloads, form state before submit |
| `Required<T>` | All props mandatory | Validating a fully-filled form |
| `Pick<T, K>` | Keep only listed keys | Narrow view models, list-row data |
| `Omit<T, K>` | Drop listed keys | Removing sensitive/internal fields |
| `Record<K, V>` | Typed key-value map | Lookup tables, `Record<UserId, User>` |
| `Readonly<T>` | All props immutable | Props that must not be mutated in place |

## Event handler types

React's synthetic event types are specific to the element and event kind — using plain `Event` loses the properties you actually need (`target.value`, etc.).

```tsx
function SearchForm() {
  const [query, setQuery] = useState("");

  // Change event on an <input>
  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setQuery(e.target.value);
  };

  // Submit event on a <form>
  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    console.log("searching for", query);
  };

  // Click event on a <button>
  const handleClick = (e: React.MouseEvent<HTMLButtonElement>) => {
    console.log("clicked at", e.clientX, e.clientY);
  };

  // Keyboard event, common for "submit on Enter"
  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Enter") console.log("enter pressed");
  };

  return (
    <form onSubmit={handleSubmit}>
      <input value={query} onChange={handleChange} onKeyDown={handleKeyDown} />
      <button type="submit" onClick={handleClick}>Search</button>
    </form>
  );
}
```

The generic parameter (`HTMLInputElement`, `HTMLFormElement`, `HTMLButtonElement`) matters — it types `e.currentTarget` correctly. A common mistake is typing every handler as `React.ChangeEvent<HTMLElement>`, which loses `.value` on non-input elements and produces confusing errors down the line.

## Type-safe API response handling

The goal: never let `any` leak in from `fetch`, and fail loudly (with a typed error) rather than silently passing malformed data downstream.

```ts
interface ApiSuccess<T> {
  ok: true;
  data: T;
}

interface ApiError {
  ok: false;
  error: string;
  status: number;
}

type ApiResult<T> = ApiSuccess<T> | ApiError;

async function apiGet<T>(path: string): Promise<ApiResult<T>> {
  try {
    const res = await fetch(path);
    if (!res.ok) {
      return { ok: false, error: await res.text(), status: res.status };
    }
    const data = (await res.json()) as T; // trust boundary — see note below
    return { ok: true, data };
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : "Unknown error", status: 0 };
  }
}

// Usage — the discriminated union forces you to handle both branches
interface User {
  id: string;
  name: string;
}

async function loadUser(id: string) {
  const result = await apiGet<User>(`/api/users/${id}`);
  if (!result.ok) {
    console.error(result.error, result.status);
    return null;
  }
  return result.data; // narrowed to User here, ok: true branch
}
```

**Interview-important caveat:** `as T` after `res.json()` is a type assertion, not runtime validation — TypeScript trusts you, but the network can send anything. For real trust boundaries (user input, third-party APIs), validate at runtime with a schema library like Zod, and derive the TypeScript type from the schema so they can't drift apart:

```ts
import { z } from "zod";

const UserSchema = z.object({
  id: z.string(),
  name: z.string(),
});
type User = z.infer<typeof UserSchema>;

async function loadUser(id: string): Promise<User> {
  const res = await fetch(`/api/users/${id}`);
  const json = await res.json();
  return UserSchema.parse(json); // throws if shape doesn't match — no silent `any`
}
```

## Discriminated unions for component state

A pattern worth knowing cold: model mutually-exclusive states as a discriminated union instead of several independent booleans, so impossible states (`loading: true, error: "x"` at the same time) can't be represented.

```tsx
type FetchState<T> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: T }
  | { status: "error"; error: string };

function useFetch<T>(url: string) {
  const [state, setState] = useState<FetchState<T>>({ status: "idle" });

  useEffect(() => {
    setState({ status: "loading" });
    fetch(url)
      .then((res) => res.json())
      .then((data: T) => setState({ status: "success", data }))
      .catch((err) => setState({ status: "error", error: String(err) }));
  }, [url]);

  return state;
}

function UserProfile({ url }: { url: string }) {
  const state = useFetch<User>(url);

  switch (state.status) {
    case "idle":
    case "loading":
      return <Spinner />;
    case "error":
      return <ErrorMessage text={state.error} />; // state.error only exists here
    case "success":
      return <div>{state.data.name}</div>; // state.data only exists here
  }
}
```

TypeScript narrows `state` inside each `case` based on the `status` literal — this is why you get autocomplete for `.error` only in the error branch and `.data` only in the success branch.

## Key takeaways

- Type props with `interface`, use `ReactNode` for children and `ReactElement` only when you need to inspect/clone an actual element.
- Generic components need the trailing-comma (`<T,>`) or `extends` trick in arrow-function form to avoid JSX ambiguity.
- `Partial`, `Pick`, `Omit`, `Record` cover the vast majority of real prop-shape reuse — know when each applies before reaching for a custom type.
- Type event handlers with the specific React synthetic event generic (`React.ChangeEvent<HTMLInputElement>`, etc.) to get correctly-typed `target`/`currentTarget`.
- `as T` after `.json()` is an assertion, not validation — use a schema library like Zod at real trust boundaries so the TypeScript type and runtime shape can't drift apart.
- Model mutually-exclusive UI state as a discriminated union so impossible combinations (loading + error simultaneously) can't be constructed.

## Today's checklist

- [ ] Read: React TypeScript cheatsheet
- [ ] Implement: Generic component with proper types
- [ ] Implement: Type-safe API response handling
- [ ] Practice utility types (`Partial`, `Required`, `Pick`, `Omit`, `Record`)
- [ ] Practice typing React event handlers
- [ ] Model at least one piece of state as a discriminated union
