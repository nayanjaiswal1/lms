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

`useQuery` infers its type from the fetcher's return type, so type the fetcher, not the hook call:

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
// data is Policy[] | undefined; TS knows it before the request resolves
```

Why reach for it over Context API for server data: Context re-renders every consumer on any update and gives you nothing for caching, retries, or staleness, so you'd have to hand-roll all of that yourself. React Query dedupes identical in-flight requests across components, caches by `queryKey`, retries failed requests, and refetches on window focus or reconnect out of the box. Context is still the right tool for low-frequency global state like theme or current user, just not for data that came from an API.

## List virtualization + infinite scroll (500+ item lists)

Rendering all 500 rows on every poll or update is the actual bug, not the polling itself: every item mounts to the DOM even though only 10-15 are visible at once. Two techniques usually get paired to fix this:

- **Virtualization**, via `react-window` or `react-virtualized`, only renders the DOM nodes currently in or near the viewport. As the user scrolls, rows are recycled rather than the full list re-rendering.
- **Infinite scroll** places a sentinel element at the bottom of the list and watches it with an `IntersectionObserver`, a browser API that fires a callback when an element crosses into or out of the viewport without the cost of a scroll-event listener. When the sentinel enters the viewport, the callback fires and triggers a fetch of the next page.

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

`FixedSizeList` never renders all of `items`. It measures its own 600px height against the fixed 48px `itemSize`, works out that roughly 12-13 rows fit, and calls the render function only for those indices plus a small overscan buffer. Scroll it and the same handful of DOM nodes get reused with updated `style` (mostly `transform`) and updated `index`, rather than mounting new nodes for every row, which is what keeps a 500-item list fast.

For a polled list specifically, virtualize the rendering, but also avoid replacing the entire array reference on every poll if only a few rows changed. Diff and patch just the changed rows so `react-window` doesn't have to re-measure everything, and pair that with request de-duplication, which React Query's `queryKey` cache already handles for you.

## Micro-frontend integration (Module Federation)

Webpack 5's **Module Federation** lets a host app load a remote app's exposed component at runtime as a separately built, separately deployed bundle. The two apps don't need to be built or deployed together.

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

The critical detail interviewers listen for is `shared: { react: { singleton: true } }`. Without marking `react`/`react-dom` as singletons, the host and remote each ship their own React copy, which breaks hooks and Context: two React instances means `useContext` in the remote can't see a Provider rendered by the host, since each copy tracks its own internal context state. The simpler alternative, an iframe per micro-app, sidesteps this entirely, but costs worse cross-app UX: no shared routing, no shared state, and slower loads.
