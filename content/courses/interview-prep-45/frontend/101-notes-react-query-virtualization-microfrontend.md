---
kind: lesson
id_key: interview-prep-45/note-react-query-virtualization-microfrontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: React Query, List Virtualization & Micro-Frontends"
position: 101
estimated_minutes: 20
source:
    - interview-prep-notes.md
---
## React Query with TypeScript

`useQuery` infers its type from the fetcher's return type — type the fetcher, not the hook call:

```ts
type Policy = { id: number; title: string; version: number };

async function fetchPolicies(): Promise<Policy[]> {
  const res = await fetch('/api/policies');
  return res.json();
}

const { data, isLoading, error } = useQuery<Policy[]>({
  queryKey: ['policies'],
  queryFn: fetchPolicies,
});
// data is Policy[] | undefined — TS knows it before the request resolves
```

Why reach for it over Context API for server data: Context re-renders every consumer on any update and gives you nothing for caching, retries, or staleness — you'd hand-roll all of that. React Query dedupes identical in-flight requests across components, caches by `queryKey`, retries failed requests, and refetches on window focus/reconnect out of the box. Context is the right tool for low-frequency global state (theme, current user) — not for data that came from an API.

## List virtualization + infinite scroll (500+ item lists)

Rendering all 500 rows on every poll/update is the actual bug, not the polling itself — every item mounts to the DOM even though only ~10-15 are visible. Two techniques, usually paired:

- **Virtualization** (`react-window` / `react-virtualized`) — only renders the DOM nodes currently in (or near) the viewport; as the user scrolls, rows are recycled rather than the full list re-rendering.
- **Infinite scroll** — an `IntersectionObserver` on a sentinel element at the bottom of the list triggers fetching the next page when it enters the viewport (see Day 96 notes on `IntersectionObserver` for the observer mechanics itself).

```jsx
import { FixedSizeList } from 'react-window';

function PolicyList({ items }) {
  return (
    <FixedSizeList height={600} width="100%" itemCount={items.length} itemSize={48}>
      {({ index, style }) => <div style={style}>{items[index].title}</div>}
    </FixedSizeList>
  );
}
```

For a polled list specifically: virtualize the rendering, but also avoid replacing the entire array reference on every poll if only a few rows changed — diff and patch the changed rows so `react-window` doesn't have to re-measure everything, and pair with request de-duplication (React Query's `queryKey` cache handles this for you).

## Micro-frontend integration (Module Federation)

Webpack 5's **Module Federation** lets a host app load a remote app's exposed component at runtime as a separately-built, separately-deployed bundle — the two apps don't need to be built or deployed together.

```js
// remote app's webpack config
new ModuleFederationPlugin({
  name: 'policyApp',
  filename: 'remoteEntry.js',
  exposes: { './PolicyEditor': './src/PolicyEditor' },
  shared: { react: { singleton: true }, 'react-dom': { singleton: true } },
});

// host app
const PolicyEditor = React.lazy(() => import('policyApp/PolicyEditor'));
```

The critical detail interviewers listen for: `shared: { react: { singleton: true } }`. Without marking `react`/`react-dom` as singletons, the host and remote each ship their own React copy — that breaks hooks and Context (two React instances means `useContext` in the remote can't see a Provider rendered by the host). The simpler alternative, an iframe per micro-app, sidesteps this entirely at the cost of worse cross-app UX (no shared routing, no shared state, slower).

## Key takeaways

- Type the fetcher's return, let `useQuery<T>` infer — Context API is for low-frequency global state, not server data with caching/retry needs.
- Virtualize (`react-window`) + paginate/infinite-scroll together for large lists; diff-and-patch on poll instead of replacing the whole array reference.
- Module Federation loads independently-deployed remote bundles at runtime; `shared: { react: { singleton: true } }` is mandatory or hooks/Context break across the host/remote boundary.
