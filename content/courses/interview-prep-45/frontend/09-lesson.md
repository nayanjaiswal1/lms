---
kind: lesson
id_key: interview-prep-45/day-09-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Code Splitting and Bundle Optimization"
position: 12
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---

Bundle size is one of the few frontend metrics that shows up directly in Lighthouse scores, Core Web Vitals, and real user complaints — which makes it a favorite interview topic. Today you'll learn how bundlers decide what ships, how to split that output into smaller chunks React can load on demand, and how to prove the improvement with real measurements instead of vibes.

## Why bundle size matters

Every kilobyte of JavaScript costs three times: download, parse/compile, and execute. On a throttled mobile connection, a 500KB bundle can add seconds to Time to Interactive even if the network transfer is fast, because the main thread is busy parsing and running code before it can respond to input.

Interviewers ask about this because it separates people who've shipped to production from people who've only run `create-react-app` locally. The signal they want: you understand there's a cost model, and you know the levers to pull.

## Tree shaking

Tree shaking is dead-code elimination based on ES module `import`/`export` static analysis. Bundlers (webpack, Rollup, esbuild, Vite) can only shake code that is statically analyzable — this is why ES modules (not CommonJS `require`) are required for it to work reliably.

```ts
// utils.ts — a library with multiple named exports
export function formatDate(d: Date) { /* ... */ }
export function debounce(fn: Function, ms: number) { /* ... */ }
export function heavyPdfGenerator() { /* ... */ } // never used

// app.ts
import { formatDate } from "./utils";
// A bundler can see `heavyPdfGenerator` is never imported anywhere
// and drop it from the final bundle — IF utils.ts has no side effects.
```

Two things break tree shaking in practice:

1. **CommonJS imports** (`const { formatDate } = require("./utils")`) — the bundler can't statically prove which exports are used.
2. **Side effects at module scope.** If a module runs code when imported (e.g., `library.registerPlugin()` at the top level), the bundler can't safely remove it even if you don't use its exports. Mark your package as side-effect-free:

```json
// package.json
{
  "sideEffects": false
}
```

If some files genuinely have side effects (CSS imports, polyfills), list them explicitly:

```json
{
  "sideEffects": ["*.css", "./src/polyfills.ts"]
}
```

**Common interview trap:** importing a whole library for one function.

```ts
// Bad: pulls in the entire lodash bundle unless the bundler
// is specifically configured for deep tree shaking
import _ from "lodash";
_.debounce(fn, 300);

// Good: only pulls in the debounce module
import debounce from "lodash/debounce";
// Better: use lodash-es, which is built for tree shaking
import { debounce } from "lodash-es";
```

## Dynamic imports and `React.lazy`

A dynamic `import()` returns a promise and tells the bundler "this is a separate chunk, load it on demand." React wraps this pattern with `React.lazy` and `Suspense` for components.

```tsx
import { lazy, Suspense } from "react";

// This creates a separate JS chunk that is only fetched
// when SettingsPanel is actually rendered.
const SettingsPanel = lazy(() => import("./SettingsPanel"));

export function App() {
  const [showSettings, setShowSettings] = useState(false);

  return (
    <div>
      <button onClick={() => setShowSettings(true)}>Open settings</button>
      {showSettings && (
        <Suspense fallback={<Spinner />}>
          <SettingsPanel />
        </Suspense>
      )}
    </div>
  );
}
```

Key details interviewers probe:

- `React.lazy` only works with **default exports**. If your module has a named export, re-export it as default in the lazy import or wrap it:
  ```ts
  const Chart = lazy(() =>
    import("./Chart").then((mod) => ({ default: mod.Chart }))
  );
  ```
- `Suspense` must wrap the lazy component (or an ancestor); without it, React throws because the promise has nothing to suspend against.
- If the dynamic import rejects (network failure), you need an error boundary around the `Suspense` — `Suspense` handles the pending state, not the error state.
- In React 19, `lazy` works the same way but composes cleanly with Server Components — a lazy client component still needs `Suspense` on the client render path.

## Route-based code splitting

The highest-leverage place to split is at the route level — a user visiting `/dashboard` shouldn't download the `/settings` bundle.

```tsx
import { lazy, Suspense } from "react";
import { Routes, Route } from "react-router-dom";

const Dashboard = lazy(() => import("./routes/Dashboard"));
const Settings = lazy(() => import("./routes/Settings"));
const Reports = lazy(() => import("./routes/Reports"));

export function AppRoutes() {
  return (
    <Suspense fallback={<PageSkeleton />}>
      <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="/reports" element={<Reports />} />
      </Routes>
    </Suspense>
  );
}
```

Frameworks like Next.js do this automatically per-page via file-based routing — every page under `app/` is already its own chunk without a manual `lazy()` call.

## Prefetching to hide the loading cost

Splitting adds a network waterfall: click → fetch chunk → parse → render. You can hide that latency by prefetching on intent (hover, viewport visibility) rather than waiting for the click.

```tsx
function NavLink({ to, children }: { to: string; children: React.ReactNode }) {
  const prefetch = () => import(`./routes/${to}.tsx`);
  return (
    <Link to={to} onMouseEnter={prefetch} onFocus={prefetch}>
      {children}
    </Link>
  );
}
```

Webpack magic comments give you the same idea declaratively:

```ts
const Reports = lazy(() => import(/* webpackPrefetch: true */ "./routes/Reports"));
```

## Measuring the bundle

Never optimize a bundle you haven't measured. Two standard tools:

```bash
# webpack-bundle-analyzer — visual treemap of what's in each chunk
npm install --save-dev webpack-bundle-analyzer

# source-map-explorer — attributes bundle bytes back to source files
# using the build's source maps
npm install --save-dev source-map-explorer
npx source-map-explorer 'build/static/js/*.js'
```

Vite equivalent:

```bash
npm install --save-dev rollup-plugin-visualizer
```

```ts
// vite.config.ts
import { visualizer } from "rollup-plugin-visualizer";

export default {
  plugins: [visualizer({ open: true, gzipSize: true })],
};
```

What to look for in the output:

- A single dependency (e.g., `moment.js`, an icon library imported in full) dominating a chunk — swap for a lighter alternative or import only what's used.
- Duplicate versions of the same library across chunks (usually a dependency mismatch) — check with `npm ls <package>`.
- Vendor code that never changes bundled together with app code that changes every deploy — split them so vendor chunks stay cached across deploys.

## Bundle budgets

A bundle budget is a CI-enforced ceiling on chunk size that fails the build if exceeded — it turns "we should keep an eye on bundle size" into something that can't silently regress.

```json
// package.json (Create React App / craco) or a CI step
{
  "bundlesize": [
    {
      "path": "./build/static/js/main.*.js",
      "maxSize": "150 kB"
    }
  ]
}
```

Webpack's built-in `performance` hints do the same thing natively:

```js
// webpack.config.js
module.exports = {
  performance: {
    maxAssetSize: 250000,
    maxEntrypointSize: 250000,
    hints: "error", // fail the build, don't just warn
  },
};
```

The interview point: budgets should be enforced in CI, not checked manually before a release. A budget nobody enforces is a suggestion, not a budget.

## Key takeaways

- Tree shaking requires ES modules and side-effect-free code; CommonJS and top-level side effects defeat it silently.
- `React.lazy` + `Suspense` split code at the component level; it needs a default export and an error boundary for failure cases.
- Route-level splitting is the highest-leverage split point — frameworks like Next.js do it automatically per page.
- Prefetch on hover/focus/viewport intent to hide the chunk-loading waterfall behind user hesitation time.
- Never optimize what you haven't measured — `source-map-explorer` or a bundle visualizer tells you exactly what's taking up space.
- Enforce bundle budgets in CI so regressions fail the build instead of shipping unnoticed.
