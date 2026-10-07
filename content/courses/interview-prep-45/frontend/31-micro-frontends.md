---
kind: lesson
id_key: interview-prep-45/day-18-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "Micro-frontends"
position: 31
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Micro-frontends come up in senior and staff interviews as an architecture discussion, not a coding exercise. The interviewer wants to know whether you can reason about the trade-offs of splitting a large frontend across teams, not whether you've memorized a config file's syntax.

## Four ways to compose an app from pieces

A micro-frontend architecture splits one web application into pieces that separate teams build and deploy independently, then composes them into one experience for the user, either at build time or at runtime.

**Build-time integration**: each micro-frontend ships as an npm package, and a shell app imports and bundles them together at build time. Simple, but it gives up independent *deployment*, shipping a checkout fix still means rebuilding and redeploying the whole shell.

**Runtime integration via iframes**: each piece is a fully isolated page inside an `<iframe>`. Maximum isolation, a crash in one can't take down another, but communication is painful (`postMessage` only), the framework runtime gets duplicated inside every iframe, and layout and routing feel bolted on rather than native.

**Runtime integration via Module Federation** (the modern default): each piece is a separately built and deployed JavaScript bundle exposing modules, and a shell loads them dynamically at runtime, sharing dependencies like React instead of each one bundling its own copy.

**Server-side composition**: each team's HTML fragment gets stitched together on the server or at the CDN edge before it reaches the browser. Good for SEO and avoids any client-side framework mismatch, but makes rich interaction across fragments harder.

When would you *not* use this? With a single team, or a small-to-medium app. This pattern solves an organizational problem, multiple teams shipping independently without blocking each other, at the cost of real complexity: duplicated tooling, shared-dependency version conflicts, harder cross-cutting changes (a design-system update now touches N repos), and a heavier build and deploy pipeline. If nothing is actually blocking on one monolith frontend's release cadence, this cost isn't worth paying.

> **Remember:** micro-frontends solve an organizational scaling problem, not a technical one. Without multiple teams genuinely blocking each other, the added complexity isn't worth it.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-microfe-when-q1", "type": "mcq",
      "prompt": "A five-person team owns one small-to-medium web app. Should they adopt a micro-frontend architecture?",
      "options": [
        {"id":"a","text":"Yes, it's always the more scalable, future-proof choice"},
        {"id":"b","text":"No — micro-frontends solve the problem of multiple independent teams blocking each other's releases, which doesn't apply here; the added complexity would be pure cost"},
        {"id":"c","text":"Yes, but only if they use Module Federation"},
        {"id":"d","text":"It makes no difference either way"}
      ],
      "correct": "b",
      "explanation": "This architecture trades real complexity, duplicated tooling, version conflicts, a heavier pipeline, for independent team releases. A single small team gets none of that benefit and pays the full cost." }
] }
```

## Module Federation configuration

Webpack 5's Module Federation lets independently built bundles expose and consume modules from each other at runtime, resolving a shared dependency like `react` to one single copy instead of every remote shipping its own.

```js
// host (shell) — webpack.config.js
const { ModuleFederationPlugin } = require("webpack").container;
module.exports = {
  plugins: [
    new ModuleFederationPlugin({
      name: "shell",
      remotes: {
        checkout: "checkout@https://checkout.mindforge.test/remoteEntry.js",
        catalog: "catalog@https://catalog.mindforge.test/remoteEntry.js",
      },
      shared: { react: { singleton: true, requiredVersion: "^19.0.0" }, "react-dom": { singleton: true, requiredVersion: "^19.0.0" } },
    }),
  ],
};

// remote (checkout app) — webpack.config.js
module.exports = {
  plugins: [
    new ModuleFederationPlugin({
      name: "checkout",
      filename: "remoteEntry.js",
      exposes: { "./CheckoutFlow": "./src/CheckoutFlow" },
      shared: { react: { singleton: true, requiredVersion: "^19.0.0" }, "react-dom": { singleton: true, requiredVersion: "^19.0.0" } },
    }),
  ],
};
```

```tsx
// shell app — a federated remote loads exactly like any other code-split chunk
const CheckoutFlow = lazy(() => import("checkout/CheckoutFlow"));
function App() {
  return <Suspense fallback={<div>Loading checkout...</div>}><CheckoutFlow /></Suspense>;
}
```

`singleton: true` is the detail interviewers probe hardest, and it's worth being precise about why. Without it, if the shell and the remote each bundle their own React, you get "Invalid hook call" errors, since two separate React instances are managing what's supposed to be one tree. With `singleton: true`, Module Federation resolves to one shared copy at runtime, and warns, or errors under `strictVersion: true`, on an incompatible version instead of silently duplicating the runtime underneath you.

> **Remember:** without `singleton: true` on React, the shell and each remote quietly ship their own separate copy of React, which breaks hooks outright.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-microfe-singleton-q1", "type": "mcq",
      "prompt": "A shell app and a remote app both bundle React independently, without marking it as a Module Federation singleton. What breaks?",
      "options": [
        {"id":"a","text":"Nothing, this is the normal setup"},
        {"id":"b","text":"Invalid hook call errors, since two separate React instances are each trying to manage what's supposed to be one shared component tree"},
        {"id":"c","text":"Only CSS styling breaks"},
        {"id":"d","text":"The build simply fails to compile"}
      ],
      "correct": "b",
      "explanation": "Without singleton: true, each side ships its own React copy. Hooks depend on a single React instance tracking state correctly across the tree, and two separate instances break that outright." }
] }
```

## A shared component library, and how to ship it

A design system used by every micro-frontend keeps the UI consistent without each team rebuilding buttons and inputs from scratch. Publish it as a versioned package, or as another federated remote, never by copy-pasting components across repos.

```tsx
// @company/ui-kit/Button.tsx
interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> { variant?: "primary" | "secondary" | "danger"; }
export function Button({ variant = "primary", className, ...props }: ButtonProps) {
  return <button className={`btn btn-${variant} ${className ?? ""}`} {...props} />;
}
```

Two real options for shipping it. An **npm package**: versioned, each team upgrades on its own schedule, but a breaking change needs every consumer to bump it independently. **Exposed via Module Federation**: always the latest shared version at runtime, zero version-pinning overhead, but a bad deploy of the shared library breaks every consumer at once, everywhere, immediately. Most teams use an npm package for the component library specifically and save Module Federation for the composable page-level features, since instant-everywhere breakage is a bigger operational risk than a slightly stale button style.

> **Remember:** an npm package fails one team at a time on upgrade. A federated shared library fails every team at once on a bad deploy.

## Independent deployment: the whole point of doing this

Team Checkout ships a fix to `checkout.mindforge.test/remoteEntry.js`, and it's live in the shell on the very next page load, no shell rebuild, no coordinated release with other teams.

```
shell.mindforge.test/          → loads remoteEntry.js from each remote at runtime
checkout.mindforge.test/       → deployed independently by the checkout team
catalog.mindforge.test/        → deployed independently by the catalog team
```

This requires the shell to treat each remote as a runtime contract, not a build-time dependency: it doesn't know or care what version of checkout is currently live, only that it exposes `./CheckoutFlow` with a compatible interface. That contract, the props shape and the exposed module names, is the thing that actually needs versioning discipline, not the whole bundle.

## Cross-remote communication, without recoupling everything

Micro-frontends can't just call each other's functions directly, they're separate bundles, potentially separate frameworks, so communication has to go through an explicit channel. **Custom events on `window`**: simple, works regardless of framework, but no type safety and easy to lose track of who's listening. **A shared event bus**, typed, usually exposed from the shell as a federated shared module, same idea with better guarantees. **URL or query params**: stateless, survives a full page reload, good for navigation state between micro-frontends. **A shared state store** (a federated Redux or Zustand instance): powerful, but it reintroduces exactly the tight coupling this whole architecture exists to avoid.

```tsx
// simplest viable pattern: typed custom events on window
function notifyCartUpdated(itemCount: number) {
  window.dispatchEvent(new CustomEvent("cart:updated", { detail: { itemCount } }));
}
function useCartBadge() {
  const [count, setCount] = useState(0);
  useEffect(() => {
    const handler = (e: Event) => setCount((e as CustomEvent).detail.itemCount);
    window.addEventListener("cart:updated", handler);
    return () => window.removeEventListener("cart:updated", handler);
  }, []);
  return count;
}
```

> **Remember:** a shared Redux store across micro-frontends looks convenient, but it quietly rebuilds the exact coupling this architecture was chosen to avoid.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-microfe-comms-q1", "type": "mcq",
      "prompt": "Why is a shared Redux store across independently-deployed micro-frontends generally discouraged, even though it's technically possible?",
      "options": [
        {"id":"a","text":"Redux doesn't work with Module Federation at all"},
        {"id":"b","text":"It reintroduces the tight coupling between teams that the micro-frontend architecture exists specifically to avoid"},
        {"id":"c","text":"It's slower than a REST API"},
        {"id":"d","text":"It requires each team to use the same CSS framework"}
      ],
      "correct": "b",
      "explanation": "The whole point of splitting into micro-frontends is independent teams shipping independently. A shared runtime store forces every consumer to agree on its shape and timing, quietly rebuilding the monolith's coupling." }
] }
```

## Testing across a boundary that's never built together

Testing one micro-frontend in isolation is no different from testing any other app. The hard part is integration: proving the composed shell actually works when checkout v2.4 meets catalog v1.9 in production, since the two are never built together at all. **Contract tests** on exposed modules, props shape, event names, catch a breaking change before deploy, independent of which version the other side happens to be running. **Consumer-driven contracts** (Pact-style) let the shell assert "checkout must expose `CheckoutFlow(props: {...})`" and fail CI in the checkout repo the moment that contract breaks. **A staging composition environment**, running the latest deployed version of every remote together, is the only reliable way to catch cross-remote issues before real users do.

> **Remember:** a unit test inside one micro-frontend's own repo can never catch "this breaks when composed with catalog v1.9," because that composition never actually happens until production.

## The thread running through all of it

Every decision here, composition strategy, shared-library distribution, communication channel, testing approach, is really a decision about how much coupling you're willing to reintroduce between teams that are supposed to be independent. The architecture only pays off while that coupling stays low. The moment two teams need a shared runtime store or a synchronized release, the monolith is quietly back, just with extra deployment steps layered on top.
