---
kind: lesson
id_key: interview-prep-45/day-18-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Micro-frontends"
position: 21
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Micro-frontends come up in senior/staff interviews as an architecture discussion, not a coding exercise — the interviewer wants to know if you can reason about the trade-offs of splitting a large frontend across teams, not whether you've memorized Module Federation's config syntax. Today covers the architecture patterns, a working Module Federation setup, shared component libraries, and the honest trade-offs (this is not a free lunch).

## Micro-frontend architecture patterns

A micro-frontend architecture splits a single web application into independently buildable, independently deployable pieces owned by separate teams, composed together at runtime (or build time) into one experience for the user.

**Build-time integration** — each micro-frontend is published as an npm package; a shell app imports and bundles them together at build time.
```tsx
// shell app package.json
"dependencies": {
  "@company/checkout-mfe": "^2.4.0",
  "@company/product-catalog-mfe": "^1.9.0"
}
```
Simple, but you lose independent *deployment* — shipping a checkout fix requires rebuilding and redeploying the shell.

**Run-time integration via iframes** — each micro-frontend is a fully isolated page embedded via `<iframe>`. Maximum isolation (separate JS realms, separate CSS, a crash in one can't take down another) but painful communication (postMessage only), duplicated framework/runtime cost per iframe, and layout/routing feel bolted-on rather than native.

**Run-time integration via Module Federation** (the modern default) — each micro-frontend is a separately built and deployed JS bundle that exposes modules; a shell app loads them dynamically at runtime, and they can share dependencies like React instead of each bundling their own copy.

**Server-side composition** (e.g. Zalando's original micro-frontend approach, or edge-side includes) — each team's HTML fragment is stitched together server-side or at the CDN edge before reaching the browser. Good for SEO and no client-side framework mismatch cost, but harder to do rich cross-fragment interactivity.

**Interview question: "When would you NOT use micro-frontends?"**
When you have a single team, or a small-to-medium app. Micro-frontends solve an organizational scaling problem (multiple teams shipping independently without blocking each other) at the cost of real complexity: duplicated tooling, shared-dependency version conflicts, harder cross-cutting changes (a design system update now touches N repos), and a more complex build/deploy pipeline. If nothing is blocking on a monolith frontend's release cadence, don't pay this tax.

## Module federation config

Webpack 5's Module Federation lets independently built bundles expose and consume modules from each other at runtime, resolving shared dependencies (like `react`) to a single copy instead of each remote shipping its own.

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
      shared: {
        react: { singleton: true, requiredVersion: "^19.0.0" },
        "react-dom": { singleton: true, requiredVersion: "^19.0.0" },
      },
    }),
  ],
};

// remote (checkout app) — webpack.config.js
module.exports = {
  plugins: [
    new ModuleFederationPlugin({
      name: "checkout",
      filename: "remoteEntry.js",
      exposes: {
        "./CheckoutFlow": "./src/CheckoutFlow",
      },
      shared: {
        react: { singleton: true, requiredVersion: "^19.0.0" },
        "react-dom": { singleton: true, requiredVersion: "^19.0.0" },
      },
    }),
  ],
};
```

```tsx
// shell app — lazy-load a remote module like any other code-split chunk
import { lazy, Suspense } from "react";

const CheckoutFlow = lazy(() => import("checkout/CheckoutFlow"));

function App() {
  return (
    <Suspense fallback={<div>Loading checkout...</div>}>
      <CheckoutFlow />
    </Suspense>
  );
}
```

`singleton: true` is the detail interviewers probe hardest: without it, if the shell and the remote both bundle their own React, you get "Invalid hook call" errors from two React instances managing the same tree. With `singleton: true`, Module Federation resolves to a single shared copy at runtime and warns (or errors, if `strictVersion: true`) on an incompatible version instead of silently duplicating the runtime.

## Shared component library

A shared design system consumed by every micro-frontend keeps the UI consistent without each team reimplementing buttons and inputs. Publish it as a versioned package (or as another federated remote) rather than copy-pasting components across repos.

```tsx
// @company/ui-kit/Button.tsx
import type { ButtonHTMLAttributes } from "react";

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "primary" | "secondary" | "danger";
}

export function Button({ variant = "primary", className, ...props }: ButtonProps) {
  return <button className={`btn btn-${variant} ${className ?? ""}`} {...props} />;
}
```

```tsx
// checkout-mfe consumes it exactly like any other dependency
import { Button } from "@company/ui-kit";

function CheckoutFlow() {
  return <Button variant="primary">Place order</Button>;
}
```

Two viable distribution strategies: **npm package** (versioned, teams pin/upgrade independently, but a breaking change requires every consumer to bump) or **exposed via Module Federation** (always the latest shared version at runtime, zero version-pinning overhead, but a bad deploy of the shared library breaks every consumer immediately). Most orgs use npm packages for the component library and Module Federation only for the composable page-level modules, because instant-everywhere breakage from a shared runtime dependency is a bigger operational risk than a slightly stale button style.

## Independent deployment

The entire point of the architecture: team Checkout ships a fix to `checkout.example.com/remoteEntry.js` and it's live in the shell on the next page load — no shell rebuild, no coordinated release train with other teams.

```
shell.example.com/          → loads remoteEntry.js from each remote at runtime
checkout.example.com/       → deployed independently by the checkout team
catalog.example.com/        → deployed independently by the catalog team
```

This requires the shell to treat remotes as a runtime contract, not a build-time dependency — the shell doesn't know or care what version of checkout is live, only that it exposes `./CheckoutFlow` with a compatible interface. That contract (props, exposed module names) becomes the thing that needs versioning discipline instead of the whole bundle.

## Communication patterns

Micro-frontends can't just call each other's functions directly (different bundles, potentially different frameworks) — communication has to go through explicit channels:

- **Custom events** on `window` — simple, framework-agnostic, but no type safety and easy to lose track of who's listening.
- **A shared event bus / pub-sub singleton** — same idea, typed, usually exposed from the shell as a federated shared module.
- **URL/query params** — stateless, survives full page reloads, good for cross-microfrontend navigation state.
- **A shared state store** (federated Redux/Zustand instance) — powerful but reintroduces tight coupling between remotes, which undermines the independence the architecture is meant to provide.

```tsx
// simplest viable pattern: typed custom events on window
interface CartUpdatedEvent extends CustomEvent<{ itemCount: number }> {}

function notifyCartUpdated(itemCount: number) {
  window.dispatchEvent(new CustomEvent("cart:updated", { detail: { itemCount } }));
}

function useCartBadge() {
  const [count, setCount] = useState(0);
  useEffect(() => {
    const handler = (e: Event) => setCount((e as CartUpdatedEvent).detail.itemCount);
    window.addEventListener("cart:updated", handler);
    return () => window.removeEventListener("cart:updated", handler);
  }, []);
  return count;
}
```

## Testing challenges

Unit testing each micro-frontend in isolation is no different from testing any React app. The hard part is **integration** — verifying the composed shell actually works when checkout v2.4 meets catalog v1.9 in production, since they're never built together.

- **Contract tests** on exposed modules (props shape, event names) catch breaking changes before deploy, independent of what version the other side is on.
- **Consumer-driven contracts** (Pact-style) let the shell assert "checkout must expose `CheckoutFlow(props: {...})`" and CI fails in the checkout repo if that contract breaks.
- **A staging composition environment** that runs the latest deployed version of every remote together is the only reliable way to catch cross-remote runtime issues (version mismatches, CSS collisions, duplicate global state) before they hit production.

**Interview question: "How do you catch a breaking change in a shared remote before it reaches production?"**
Contract tests in CI on the exposed module's public interface, run against the remote's own pipeline (fails fast, close to the source), plus a staging environment that continuously composes the latest deployed version of every remote so cross-team integration issues are caught before the shell serves real users — because unit tests inside one micro-frontend's repo can never catch "this breaks when composed with catalog v1.9."

## Key takeaways

- Micro-frontends solve an organizational problem (independent team deployment), not a technical one — don't reach for them without multiple teams shipping into the same product.
- Module Federation's `shared: { react: { singleton: true } }` is the detail that prevents duplicate-React "Invalid hook call" bugs across remotes.
- A shared component library is usually distributed as a versioned npm package, not a federated remote, because instant-everywhere breakage is a bigger risk than version drift.
- Independent deployment means the shell treats remotes as a runtime contract (exposed module + props shape), not a build-time dependency.
- Cross-microfrontend communication should go through explicit channels (custom events, a typed event bus) — never direct function calls or a shared framework-level store, which reintroduces coupling.
- Integration testing across independently-deployed remotes requires contract tests and a staging composition environment — unit tests alone can't catch it.
