---
kind: lesson
id_key: interview-prep-45/day-09-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Code Splitting and Bundle Optimization"
position: 23
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Bundle size is one of the few frontend metrics that shows up directly in Lighthouse scores, Core Web Vitals, and real user complaints, which is exactly why it's a favorite interview topic. This lesson covers how bundlers decide what ships, how to split that output into chunks React can load on demand, and how to prove the improvement with real measurements instead of a feeling that it got faster.

## The actual cost of a kilobyte of JavaScript

Every kilobyte costs three times over: download, parse and compile, then execute. On a throttled mobile connection, a 500KB bundle can add seconds to Time to Interactive even when the network transfer itself is fast, because the main thread stays busy parsing and running code before it can respond to input at all. Interviewers ask about this because it separates people who've shipped to production from people who've only run a starter template locally, and the signal they're after is whether you understand there's a real cost model with specific levers, not vague "make it faster" instincts.

## Tree shaking, and what quietly breaks it

Tree shaking is dead-code elimination based on static analysis of ES module `import`/`export` statements. Bundlers can only shake code that's statically analyzable, which is exactly why ES modules, not CommonJS `require`, are required for it to work reliably at all.

```ts
// utils.ts
export function formatDate(d: Date) { /* ... */ }
export function heavyPdfGenerator() { /* ... */ } // never imported anywhere

// app.ts
import { formatDate } from "./utils";
// The bundler can see heavyPdfGenerator is unreachable from any entry point and drops it —
// IF utils.ts has no side effects.
```

Two things defeat this in practice. CommonJS imports can't be statically resolved, since `require` calls can be conditional or dynamic. And side effects at module scope, code that runs the moment a module is imported, like `library.registerPlugin()` at the top level, mean the bundler can't safely remove that module even if none of its exports are used. Mark a package side-effect-free explicitly:

```json
{ "sideEffects": false }
```

or list exactly which files have real side effects if some genuinely do:

```json
{ "sideEffects": ["*.css", "./src/polyfills.ts"] }
```

The classic trap is importing a whole library for one function:

```ts
// Bad: pulls in the entire lodash bundle unless deep tree shaking is specifically configured
import _ from "lodash";
_.debounce(fn, 300);

// Good: only pulls in the debounce module
import debounce from "lodash/debounce";
```

`import * as _ from "lodash"` defeats tree shaking for the same underlying reason CommonJS does: every property access on `_` becomes a dynamic lookup from the bundler's point of view, and it can't prove which of hundreds of exports are actually used just by watching `_.foo()` calls. Named imports, `import { debounce } from "lodash-es"`, are what actually enable dead-code elimination, because the bundler sees the exact symbol right at the import statement.

## Dynamic imports and React.lazy

A dynamic `import()` returns a promise and tells the bundler "this is its own chunk, load it on demand." React wraps that pattern with `React.lazy` and `Suspense`:

```tsx
import { lazy, Suspense } from "react";
const SettingsPanel = lazy(() => import("./SettingsPanel")); // its own chunk, fetched only when rendered

export function App() {
  const [showSettings, setShowSettings] = useState(false);
  return (
    <div>
      <button onClick={() => setShowSettings(true)}>Open settings</button>
      {showSettings && <Suspense fallback={<Spinner />}><SettingsPanel /></Suspense>}
    </div>
  );
}
```

Three details interviewers probe. `React.lazy` only works with default exports, if the module has a named export, re-export it as default inline: `lazy(() => import("./Chart").then(mod => ({ default: mod.Chart })))`. `Suspense` must wrap the lazy component, or an ancestor of it, without it React throws, since the promise has nothing to suspend against. And a rejected dynamic import, a network failure mid-download, needs an error boundary around the `Suspense`, since `Suspense` only handles the pending state, never the error state.

Route-level splitting is the highest-leverage place to do this: someone visiting `/dashboard` shouldn't download the `/settings` bundle at all.

```tsx
const Dashboard = lazy(() => import("./routes/Dashboard"));
const Settings = lazy(() => import("./routes/Settings"));

export function AppRoutes() {
  return (
    <Suspense fallback={<PageSkeleton />}>
      <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
      </Routes>
    </Suspense>
  );
}
```

Next.js does this automatically via file-based routing, every page under `app/` is already its own chunk with no manual `lazy()` call needed.

## Hiding the split's cost with prefetching

Splitting introduces its own waterfall: click, fetch the chunk, parse, render. Prefetching on intent, hover or viewport visibility, hides that latency instead of waiting for the click:

```tsx
function NavLink({ to, children }: { to: string; children: React.ReactNode }) {
  const prefetch = () => import(`./routes/${to}.tsx`);
  return <Link to={to} onMouseEnter={prefetch} onFocus={prefetch}>{children}</Link>;
}
```

```ts
const Reports = lazy(() => import(/* webpackPrefetch: true */ "./routes/Reports"));
```

## Never optimize a bundle you haven't measured

```bash
npm install --save-dev webpack-bundle-analyzer  # visual treemap of what's in each chunk
npm install --save-dev source-map-explorer      # attributes bundle bytes back to source files
```

Vite's equivalent is `rollup-plugin-visualizer`:

```ts
import { visualizer } from "rollup-plugin-visualizer";
export default { plugins: [visualizer({ open: true, gzipSize: true })] };
```

What to actually look for once the treemap opens: a single dependency dominating a chunk, `moment.js`, an icon library imported in full, swap it for something lighter or import just the piece used; duplicate versions of the same library scattered across chunks, usually a dependency mismatch, check with `npm ls <package>`; and vendor code that never changes bundled together with app code that changes every deploy, split them so the vendor chunk stays cached across releases instead of getting invalidated by every unrelated app change.

## Bundle budgets

A bundle budget is a CI-enforced ceiling on chunk size that fails the build the moment it's exceeded, which is what turns "we should keep an eye on bundle size" into something that actually can't silently regress. `bundlesize` declares it right in `package.json`:

```json
{
  "bundlesize": [
    { "path": "./build/static/js/main.*.js", "maxSize": "150 kB" }
  ]
}
```

Webpack's built-in `performance` hints do the same thing natively, no extra package needed:

```js
// webpack.config.js
module.exports = {
  performance: { maxAssetSize: 250000, maxEntrypointSize: 250000, hints: "error" }, // fail the build, don't just warn
};
```

The point worth making explicitly: budgets belong in CI, checked automatically on every PR, not something someone remembers to eyeball manually before a release. A budget nobody enforces is a suggestion, not a budget.
