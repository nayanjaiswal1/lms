---
kind: lesson
id_key: interview-prep-45/day-18-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Micro-frontends"
position: 32
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Micro-frontends come up in senior and staff interviews as an architecture discussion, not a coding exercise. The interviewer wants to know whether you can reason about the trade-offs of splitting a large frontend across teams, not whether you've memorized Module Federation's config syntax. This lesson covers the composition patterns, a working Module Federation setup, shared component libraries, and the honest trade-offs, this is not a free lunch.

## Four ways to compose

A micro-frontend architecture splits one web application into independently buildable, independently deployable pieces owned by separate teams, composed together into one experience for the user, either at build time or at runtime.

**Build-time integration**: each micro-frontend ships as an npm package, and a shell app imports and bundles them together at build time. Simple, but it gives up independent *deployment*, shipping a checkout fix means rebuilding and redeploying the shell regardless.

**Runtime integration via iframes**: each piece is a fully isolated page embedded in an `<iframe>`, maximum isolation, separate JS realms, separate CSS, a crash in one can't take down another, but communication is painful (`postMessage` only), the framework runtime is duplicated per iframe, and layout and routing feel bolted-on rather than native.

**Runtime integration via Module Federation** (the modern default): each piece is a separately built and deployed JS bundle exposing modules, and a shell loads them dynamically at runtime, sharing dependencies like React instead of each bundling its own copy.

**Server-side composition**: each team's HTML fragment gets stitched together server-side or at the CDN edge before reaching the browser. Good for SEO and avoids any client-side framework mismatch cost, but makes rich cross-fragment interactivity harder.

When would you *not* use micro-frontends? With a single team, or a small-to-medium app. They solve an organizational scaling problem, multiple teams shipping independently without blocking each other, at the cost of real complexity: duplicated tooling, shared-dependency version conflicts, harder cross-cutting changes (a design-system update now touches N repos), and a more complex build and deploy pipeline. If nothing is actually blocking on a monolith frontend's release cadence, this tax isn't worth paying.

## Module Federation configuration

Webpack 5's Module Federation lets independently built bundles expose and consume modules from each other at runtime, resolving shared dependencies like `react` to a single copy instead of every remote shipping its own.

```js
// host (shell) — webpack.config.js
const { ModuleFederationPlugin } = require("webpack").container;
module.exports = {
  plugins: [
    new ModuleFederationPlugin({
      name: "shell",
      remotes: {
        checkout: "checkout@https://checkout.example.com/remoteEntry.js",
        catalog: "catalog@https://catalog.example.com/remoteEntry.js",
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

`singleton: true` is the detail interviewers probe hardest, and it's worth being precise about why: without it, if the shell and the remote each bundle their own React, you get "Invalid hook call" errors from two React instances managing what's supposed to be the same tree. With `singleton: true`, Module Federation resolves to one shared copy at runtime and warns, or errors under `strictVersion: true`, on an incompatible version instead of silently duplicating the runtime underneath you.

## A shared component library, and how to ship it

A design system consumed by every micro-frontend keeps the UI consistent without each team reimplementing buttons and inputs from scratch. Publish it as a versioned package, or as another federated remote, rather than copy-pasting components across repos.

```tsx
// @company/ui-kit/Button.tsx
interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> { variant?: "primary" | "secondary" | "danger"; }
export function Button({ variant = "primary", className, ...props }: ButtonProps) {
  return <button className={`btn btn-${variant} ${className ?? ""}`} {...props} />;
}
```

Two viable distribution strategies. An **npm package**: versioned, each team pins and upgrades independently, but a breaking change requires every consumer to bump on its own schedule. **Exposed via Module Federation**: always the latest shared version at runtime, zero version-pinning overhead, but a bad deploy of the shared library breaks every consumer immediately, everywhere, at once. Most organizations use npm packages for the component library specifically and reserve Module Federation for the composable page-level modules, since instant-everywhere breakage from a shared runtime dependency is a bigger operational risk than a slightly stale button style.

## Independent deployment: the entire point of the exercise

Team Checkout ships a fix to `checkout.example.com/remoteEntry.js` and it's live in the shell on the very next page load, no shell rebuild, no coordinated release train with other teams.

```
shell.example.com/          → loads remoteEntry.js from each remote at runtime
checkout.example.com/       → deployed independently by the checkout team
catalog.example.com/        → deployed independently by the catalog team
```

This requires the shell to treat each remote as a runtime contract, not a build-time dependency: it doesn't know or care what version of checkout is currently live, only that it exposes `./CheckoutFlow` with a compatible interface. That contract, the props shape and the exposed module names, becomes the thing that actually needs versioning discipline, not the whole bundle.

## Cross-remote communication, without recoupling everything

Micro-frontends can't just call each other's functions directly, different bundles, potentially different frameworks entirely, so communication has to go through explicit channels. **Custom events on `window`**: simple and framework-agnostic, but no type safety and easy to lose track of who's actually listening. **A shared event bus**, typed, usually exposed from the shell as a federated shared module, same idea with better guarantees. **URL or query params**: stateless, survives a full page reload, good for cross-microfrontend navigation state. **A shared state store** (a federated Redux or Zustand instance): powerful, but it reintroduces the exact tight coupling this architecture exists to avoid.

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

## Testing across a boundary that's never built together

Unit testing each micro-frontend in isolation is no different from testing any other React app. The hard part is integration: verifying the composed shell actually works when checkout v2.4 meets catalog v1.9 in production, since the two are never built together at all. **Contract tests** on exposed modules, props shape, event names, catch a breaking change before deploy, independent of which version the other side happens to be running. **Consumer-driven contracts** (Pact-style) let the shell assert "checkout must expose `CheckoutFlow(props: {...})`" and fail CI in the checkout repo the moment that contract breaks. **A staging composition environment** running the latest deployed version of every remote together is the only reliable way to catch cross-remote issues, version mismatches, CSS collisions, duplicate global state, before they hit production users.

How do you catch a breaking change in a shared remote before it reaches production? Contract tests in CI on the exposed module's public interface, run against the remote's own pipeline so they fail fast and close to the source, plus a staging environment that continuously composes the latest deployed version of every remote so cross-team integration issues surface before real users ever see them. Unit tests inside one micro-frontend's own repo can never catch "this breaks when composed with catalog v1.9," because that composition never happens until it's live.

## The thread running through all of it

Every decision here, composition strategy, shared-library distribution, communication channel, testing approach, is really a decision about how much coupling you're willing to reintroduce between teams that are supposed to be independent. The architecture only pays off while that coupling stays low; the moment two teams need a shared runtime store or a synchronized release, you've quietly rebuilt the monolith, just with extra deployment steps on top of it.
