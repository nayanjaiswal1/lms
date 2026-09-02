---
kind: lesson
id_key: interview-prep-45/day-12-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "TypeScript for React"
position: 26
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Most production React codebases are TypeScript now, and interviewers routinely ask you to type a component, a hook, or an API response live. This lesson covers the patterns that come up constantly: typing props and generics, the utility types you'll reach for weekly, event handler types, and building a type-safe boundary around whatever `fetch` actually hands you.

## Typing props

```tsx
interface ButtonProps {
  label: string;
  onClick: () => void;
  variant?: "primary" | "secondary" | "danger"; // a union, not a bare string
  children?: React.ReactNode;
}

function Button({ label, onClick, variant = "primary", children }: ButtonProps) {
  return <button className={`btn btn-${variant}`} onClick={onClick}>{children ?? label}</button>;
}
```

`interface` versus `type` for props is a style convention more than a hard rule, `interface` is extendable and gives slightly better error messages, both work fine, and interviewers care more that you're consistent than which one you pick. `React.ReactNode` versus `React.ReactElement` is a genuine trip-up: `ReactNode` covers anything renderable, elements, strings, numbers, arrays, `null`, `booleans`, use it for `children`. `ReactElement` is specifically the result of `<Foo />` or `React.createElement`, reach for it only when you need to clone or inspect an actual element via `React.cloneElement`, not for general children.

## Generic components

A generic component lets the caller determine a type parameter, staying reusable without falling back to `any`.

```tsx
interface SelectProps<T> {
  items: T[]; value: T; onChange: (value: T) => void; getLabel: (item: T) => string; getKey: (item: T) => string | number;
}
function Select<T>({ items, value, onChange, getLabel, getKey }: SelectProps<T>) {
  return (
    <select value={getKey(value)} onChange={(e) => { const selected = items.find(i => String(getKey(i)) === e.target.value); if (selected) onChange(selected); }}>
      {items.map(item => <option key={getKey(item)} value={getKey(item)}>{getLabel(item)}</option>)}
    </select>
  );
}

// Usage — T is inferred as User, no explicit type argument needed
function UserPicker({ users, selected, onSelect }: { users: User[]; selected: User; onSelect: (u: User) => void }) {
  return <Select items={users} value={selected} onChange={onSelect} getLabel={u => u.name} getKey={u => u.id} />;
}
```

One syntax detail worth knowing cold: a generic *arrow-function* component in a `.tsx` file needs a trailing comma, `<T,>`, or an `extends unknown` constraint, so the parser doesn't mistake the type parameter for the start of a JSX tag. A `function` declaration doesn't have that ambiguity:

```tsx
const List = <T,>({ items }: { items: T[] }) => <ul>{items.map((i, idx) => <li key={idx}>{String(i)}</li>)}</ul>;
function List2<T>({ items }: { items: T[] }) { return <ul>{items.map((i, idx) => <li key={idx}>{String(i)}</li>)}</ul>; }
```

## Utility types worth having ready

```ts
interface Product { id: string; name: string; price: number; description: string; inStock: boolean; }

function updateProduct(id: string, changes: Partial<Product>) {} // every field optional — patch payloads
updateProduct("p1", { price: 29.99 }); // no need to pass every field

interface DraftProduct extends Partial<Product> {}
function publishProduct(draft: Required<DraftProduct>) {} // every field mandatory, even ones declared optional on the source type

type ProductSummary = Pick<Product, "id" | "name" | "price">;    // a narrow subset
type ProductWithoutDescription = Omit<Product, "description">;    // everything except listed fields
type ProductsById = Record<string, Product>;                      // a typed dictionary

function renderProduct(p: Readonly<Product>) { /* p.price = 0; // error */ } // an immutable view
```

| Utility | What it does | Typical use |
|---|---|---|
| `Partial<T>` | All props optional | Patch/update payloads, form state before submit |
| `Required<T>` | All props mandatory | Validating a fully-filled form |
| `Pick<T, K>` | Keep only listed keys | Narrow view models, list-row data |
| `Omit<T, K>` | Drop listed keys | Removing sensitive or internal fields |
| `Record<K, V>` | Typed key-value map | Lookup tables, `Record<UserId, User>` |
| `Readonly<T>` | All props immutable | Props that must never be mutated in place |

## Typing event handlers correctly

React's synthetic events are specific to the element and event kind. Typing a handler as plain `Event` loses everything you actually need, like `target.value`.

```tsx
function SearchForm() {
  const [query, setQuery] = useState("");
  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => setQuery(e.target.value);
  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => { e.preventDefault(); };
  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => { if (e.key === "Enter") {} };
  const handleClick = (e: React.MouseEvent<HTMLButtonElement>) => { console.log("clicked at", e.clientX, e.clientY); };
  return <form onSubmit={handleSubmit}><input value={query} onChange={handleChange} onKeyDown={handleKeyDown} /><button type="submit" onClick={handleClick}>Search</button></form>;
}
```

The generic parameter, `HTMLInputElement`, `HTMLFormElement`, matters because it's what correctly types `e.currentTarget`. Typing every handler as `React.ChangeEvent<HTMLElement>` loses `.value` on non-input elements and produces confusing errors further down the line, the specific type argument is what makes the whole thing worth doing at all.

## A type-safe boundary around fetch

The goal is to never let `any` leak in from the network, and to fail loudly with a typed error instead of silently passing malformed data downstream.

```ts
type ApiResult<T> = { ok: true; data: T } | { ok: false; error: string; status: number };

async function apiGet<T>(path: string): Promise<ApiResult<T>> {
  try {
    const res = await fetch(path);
    if (!res.ok) return { ok: false, error: await res.text(), status: res.status };
    return { ok: true, data: (await res.json()) as T }; // trust boundary — see below
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : "Unknown error", status: 0 };
  }
}

async function loadUser(id: string) {
  const result = await apiGet<User>(`/api/users/${id}`);
  if (!result.ok) { console.error(result.error, result.status); return null; }
  return result.data; // narrowed to User here, the ok: true branch
}
```

`as T` after `res.json()` is a type assertion, not runtime validation, TypeScript trusts you, but the network can send anything at all. For a real trust boundary, user input, a third-party API, validate at runtime with a schema library and derive the TypeScript type from the schema itself, so the two can never drift apart:

```ts
import { z } from "zod";
const UserSchema = z.object({ id: z.string(), name: z.string() });
type User = z.infer<typeof UserSchema>;

async function loadUser(id: string): Promise<User> {
  const res = await fetch(`/api/users/${id}`);
  return UserSchema.parse(await res.json()); // throws on a shape mismatch — no silent `any` slipping through
}
```

## Discriminated unions: the pattern worth remembering above everything else here

Model mutually exclusive states as a union rather than several independent booleans, so impossible states, `loading: true` and `error: "x"` at once, simply can't be represented in the type at all.

```tsx
type FetchState<T> = { status: "idle" } | { status: "loading" } | { status: "success"; data: T } | { status: "error"; error: string };

function useFetch<T>(url: string) {
  const [state, setState] = useState<FetchState<T>>({ status: "idle" });
  useEffect(() => {
    setState({ status: "loading" });
    fetch(url).then(res => res.json()).then((data: T) => setState({ status: "success", data })).catch(err => setState({ status: "error", error: String(err) }));
  }, [url]);
  return state;
}

function UserProfile({ url }: { url: string }) {
  const state = useFetch<User>(url);
  switch (state.status) {
    case "idle": case "loading": return <Spinner />;
    case "error": return <ErrorMessage text={state.error} />; // state.error only exists in this branch
    case "success": return <div>{state.data.name}</div>;       // state.data only exists in this branch
  }
}
```

TypeScript narrows `state` inside each `case` based on the `status` literal, which is exactly why autocomplete offers `.error` only in the error branch and `.data` only in the success branch, and why the compiler refuses to let you read `state.data` anywhere it might not exist. If one pattern from this lesson is worth carrying forward above the rest, it's this one, it shows up constantly in live-coding rounds because it's a compact, precise way to prove you think about state shape before you think about JSX.
