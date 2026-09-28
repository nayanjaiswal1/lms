---
kind: lesson
id_key: interview-prep-45/day-09-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "Code Splitting and Bundles"
position: 25
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Imagine handing someone a phone book to find one number. Most of it is dead weight for what they actually need. A JavaScript bundle can do the same thing to your users: ship code for ten features when the page in front of them only uses one. Bundle size shows up directly in Lighthouse scores, in Core Web Vitals, and in real complaints, which is exactly why it's a favorite interview topic.

## What a kilobyte of JavaScript actually costs

Every kilobyte is paid for three times: it has to download, then get parsed and compiled, then run. On a throttled phone connection, a 500KB bundle can add whole seconds before the page responds to a tap, even if the download itself was fast, because the main thread stays busy parsing and running code the whole time. This is the difference between someone who's shipped to real users and someone who's only run a starter template on their own laptop.

> **Remember:** a kilobyte of JS costs download, then parse, then execute. It isn't free just because the network is fast.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-splitting-cost-q1", "type": "mcq",
      "prompt": "A 500KB JavaScript bundle downloads quickly on a fast connection, but the page still feels slow to respond to taps on a mid-range phone. Why?",
      "options": [
        {"id":"a","text":"Download speed is the only cost of JavaScript, so this shouldn't happen"},
        {"id":"b","text":"After downloading, the browser still has to parse and execute that code, and a slower CPU can keep the main thread busy with that work long after the download finished"},
        {"id":"c","text":"The phone's screen is too small"},
        {"id":"d","text":"JavaScript never affects responsiveness, only images do"}
      ],
      "correct": "b",
      "explanation": "Download is only the first of three costs. Parsing and executing a large bundle can keep a slower CPU's main thread busy well after the network transfer is done, which is exactly why bundle size still matters on a fast connection." }
] }
```

## Tree shaking, and what quietly breaks it

Tree shaking is a bundler noticing which exported code is never actually used anywhere, and cutting it out. It works by reading `import`/`export` statements without running any code, which is exactly why it needs real ES modules, not the older `require()` style, to work reliably at all.

```ts
// utils.ts
export function formatDate(d: Date) { /* ... */ }
export function heavyPdfGenerator() { /* ... */ } // never imported anywhere

// app.ts
import { formatDate } from "./utils";
// The bundler can see heavyPdfGenerator is unreachable from any entry point and drops it —
// as long as utils.ts has no side effects.
```

Two things break this in practice. `require()` calls can be conditional or built dynamically, so a bundler can't reliably prove what's used. And code that runs the instant a file is imported, like `library.registerPlugin()` sitting outside any function, means the bundler can't safely delete that file even if none of its exports are ever used. You can mark a package as side-effect-free by hand:

```json
{ "sideEffects": false }
```

or list exactly which files genuinely do have side effects:

```json
{ "sideEffects": ["*.css", "./src/polyfills.ts"] }
```

The classic mistake is importing a whole library for one small piece of it:

```ts
// Bad: pulls in the entire lodash library unless deep tree shaking is specially configured
import _ from "lodash";
_.debounce(fn, 300);

// Good: only pulls in the debounce function
import debounce from "lodash/debounce";
```

`import * as _ from "lodash"` breaks tree shaking for the same reason `require()` does: every use of `_.something` becomes a lookup the bundler can't predict ahead of time, so it can't prove which of hundreds of exports actually got used. Named imports (`import { debounce } from "lodash-es"`) work because the bundler sees the exact piece you want right there in the import line.

> **Remember:** tree shaking needs to see the exact name you're using at the import line. A whole-module import (`import * as _`) hides that from it.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-splitting-treeshake-q1", "type": "mcq",
      "prompt": "Why does import * as _ from \"lodash\" defeat tree shaking, while import { debounce } from \"lodash-es\" doesn't?",
      "options": [
        {"id":"a","text":"lodash-es is a smaller library overall"},
        {"id":"b","text":"Every property access on the namespace import becomes a dynamic lookup the bundler can't predict, so it can't prove which exports are unused; a named import states the exact symbol used, right at the import line"},
        {"id":"c","text":"import * always fails silently at build time"},
        {"id":"d","text":"There's no real difference"}
      ],
      "correct": "b",
      "explanation": "Tree shaking depends on the bundler being able to statically see which exports are actually referenced. A namespace import hides that behind a runtime property lookup; a named import states it directly." }
] }
```

## Dynamic imports and React.lazy

A dynamic `import()` returns a promise and tells the bundler: "this is its own separate chunk, load it only when asked." React wraps this pattern with `React.lazy` plus `Suspense`.

```tsx
import { lazy, Suspense } from "react";
const SettingsPanel = lazy(() => import("./SettingsPanel")); // its own chunk, fetched only when it's actually rendered

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

Three details worth knowing cold. `React.lazy` only works with default exports; for a named export, re-export it inline: `lazy(() => import("./Chart").then(mod => ({ default: mod.Chart })))`. `Suspense` must wrap the lazy component, or React throws, since there's nothing to suspend against otherwise. And a failed download, a network drop mid-fetch, needs an error boundary around the `Suspense`, since `Suspense` only knows how to handle "still loading," never "failed."

Splitting by route is the highest-value place to do this: someone on `/dashboard` shouldn't download the `/settings` code at all.

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

Next.js does this automatically through its file-based routing: every page under `app/` is already its own chunk, no manual `lazy()` needed.

> **Remember:** a rejected dynamic import needs an error boundary. Suspense alone only covers "still loading," never "failed to load."

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-splitting-lazy-q1", "type": "mcq",
      "prompt": "A user's network drops mid-download while a React.lazy component's chunk is loading. What handles that failure?",
      "options": [
        {"id":"a","text":"Suspense's fallback automatically shows an error message"},
        {"id":"b","text":"An error boundary wrapped around the Suspense, since Suspense only handles the pending state, not a rejected promise"},
        {"id":"c","text":"React.lazy retries automatically and silently"},
        {"id":"d","text":"Nothing — the app crashes with no way to recover"}
      ],
      "correct": "b",
      "explanation": "Suspense shows its fallback while the import() promise is pending, but has no idea what to do if that promise rejects. An error boundary is what catches the failure and lets you show a real error state." }
] }
```

## Prefetching hides the cost of splitting

Splitting introduces its own small delay: click, fetch the chunk, parse it, then render. Prefetching on hover or focus hides that delay instead of making the user wait for it after the click.

```tsx
function NavLink({ to, children }: { to: string; children: React.ReactNode }) {
  const prefetch = () => import(`./routes/${to}.tsx`);
  return <Link to={to} onMouseEnter={prefetch} onFocus={prefetch}>{children}</Link>;
}
```

```ts
const Reports = lazy(() => import(/* webpackPrefetch: true */ "./routes/Reports"));
```

> **Remember:** prefetch on hover turns "wait after the click" into "already loaded by the time you click."

## Never optimize a bundle you haven't measured

```bash
npm install --save-dev webpack-bundle-analyzer  # a visual map of what's inside each chunk
npm install --save-dev source-map-explorer      # traces bundle bytes back to the source files that produced them
```

Vite's version is `rollup-plugin-visualizer`:

```ts
import { visualizer } from "rollup-plugin-visualizer";
export default { plugins: [visualizer({ open: true, gzipSize: true })] };
```

What to actually look for once that map is open: one dependency taking up most of a chunk (a full icon library imported for three icons, swap it for something smaller or import only what's used); the same library duplicated across several chunks (usually a version mismatch, check with `npm ls <package>`); and vendor code, which barely ever changes, bundled together with app code that changes on every deploy, split them apart so the vendor chunk stays cached across releases instead of getting invalidated by every unrelated change.

## Bundle budgets: making a number a build failure

A bundle budget is a ceiling on chunk size, enforced in CI, that fails the build the moment it's crossed. That's what turns "we should keep an eye on this" into something that genuinely can't slip through unnoticed.

```json
{
  "bundlesize": [
    { "path": "./build/static/js/main.*.js", "maxSize": "150 kB" }
  ]
}
```

Webpack has the same idea built in, no extra package needed:

```js
// webpack.config.js
module.exports = {
  performance: { maxAssetSize: 250000, maxEntrypointSize: 250000, hints: "error" }, // fail the build, don't just warn
};
```

> **Remember:** a budget that isn't enforced automatically in CI is a suggestion, not a budget. Someone eventually forgets to check it.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-splitting-budget-q1", "type": "mcq",
      "prompt": "What makes a bundle size budget actually effective at preventing regressions, rather than just a nice idea?",
      "options": [
        {"id":"a","text":"Writing the size limit down in a team wiki page"},
        {"id":"b","text":"Enforcing it automatically in CI so the build fails the moment the limit is crossed, instead of relying on someone remembering to check manually"},
        {"id":"c","text":"Asking developers to check bundle size before every commit"},
        {"id":"d","text":"Nothing can reliably prevent bundle size regressions"}
      ],
      "correct": "b",
      "explanation": "A limit nobody enforces automatically is a suggestion. Wiring it into CI, so a PR simply can't merge past the ceiling, is what makes it actually hold." }
] }
```
