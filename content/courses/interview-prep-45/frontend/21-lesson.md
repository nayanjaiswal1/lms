---
kind: lesson
id_key: interview-prep-45/day-21-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Checkpoint 3"
position: 24
estimated_minutes: 18
source:
    - 45-day-interview-roadmap.md
---

Second consolidation checkpoint. This week covered security, real-time communication, server rendering, architectural scale, React performance internals, and build tooling: a wide spread that interviewers love to mix into a single system-design-adjacent conversation. Drill the connections between these topics, not just each one in isolation.

## Web Security

Core idea: never trust data that crossed a trust boundary (user input, third-party responses, URL params) without validating or encoding it.

- **XSS**: React escapes text content by default; the danger zone is `dangerouslySetInnerHTML` and any place raw HTML from an untrusted source gets injected. Sanitize with a library (DOMPurify) if you must render HTML at all.
- **CSRF**: same-site cookies (`SameSite=Strict`/`Lax`) plus a CSRF token on state-changing requests; relevant even with JWTs if the token is stored in a cookie.
- **CSP (Content-Security-Policy)**: a response header restricting which script/style/image sources the browser will execute or load, the last line of defense if an XSS payload does get injected.
- Where tokens live: `localStorage` is readable by any injected script (XSS risk); `httpOnly` cookies aren't readable by JavaScript at all (but need CSRF protection). This trade-off is a near-guaranteed interview question.

## WebSockets

Core idea: a persistent, full-duplex connection for real-time, bidirectional communication, distinct from HTTP's request/response model.

- Handshake starts as an HTTP request with an `Upgrade: websocket` header; the server responds `101 Switching Protocols` and the connection stays open.
- Reconnection strategy matters in production: exponential backoff with jitter, plus a heartbeat/ping-pong to detect a dead connection before the OS notices.
- Compare with alternatives: Server-Sent Events (one-way, simpler, auto-reconnect built in, works over plain HTTP) vs. long polling (works everywhere, higher latency and overhead) vs. WebSockets (full duplex, more setup, needed for things like collaborative editing or chat).

## SSR / Next.js

Core idea: move rendering work to the server to improve perceived load time and SEO, at the cost of server compute and more moving parts.

- **SSR** renders HTML per-request on the server; **SSG** renders once at build time; **ISR** (Incremental Static Regeneration) serves a static page but revalidates it on a schedule. Know when each applies.
- React Server Components (Next.js App Router) run only on the server, never ship their JS to the client, and can access backend resources (DB, filesystem) directly. The trade-off is they can't use hooks or browser APIs; that's what `"use client"` opts back into.
- Hydration is the step where client-side React attaches event listeners to server-rendered HTML. A hydration mismatch (server HTML differs from what the client would render) is a classic bug source, usually from `Date.now()`, `Math.random()`, or browser-only APIs used during server render.

## Micro-frontends

Core idea: split a large frontend into independently deployable pieces owned by different teams. It's an organizational scaling solution more than a technical one.

- Composition strategies: build-time integration (npm packages), server-side composition (edge includes), runtime composition (Module Federation, iframes, web components).
- Costs to name unprompted: duplicated dependencies across bundles unless carefully shared, harder cross-team design consistency, more complex versioning and deployment coordination.
- The interview-safe framing: micro-frontends solve a team-scaling problem, not a technical performance problem. Reach for them when multiple independent teams need to ship on separate cadences, not by default.

## React Performance

Core idea: avoid unnecessary re-renders and unnecessary work inside renders that do happen.

- `React.memo` skips a re-render if props are shallow-equal; it does nothing if you pass a new object/array/function literal each render, so pair it with `useMemo`/`useCallback` on the parent for those values.
- `useMemo` caches a computed value, `useCallback` caches a function reference. Both trade memory and a comparison cost for avoiding recomputation; profile before reaching for them, they're not free.
- The React Compiler (React 19) automates much of this memoization at build time, but understanding manual memoization is still expected. The interviewer wants to know you understand *why* it works, not just that a tool does it now.
- Concurrent features: `useTransition` marks an update as non-urgent so React can interrupt it for higher-priority updates (like typing); `useDeferredValue` gives you a lagging copy of a value for the same purpose without wrapping the state setter itself.

## Build Tools

Core idea: know what a bundler/dev-server actually does, not just the CLI commands.

- Vite's dev-server speed comes from serving native ES modules over the network unbundled, using esbuild (Go, not JS) for transpilation, and only bundling for production builds via Rollup.
- Webpack's loader/plugin model: loaders transform individual files (e.g., `babel-loader` for JSX/TS), plugins hook into the broader build lifecycle (e.g., generating `index.html`, extracting CSS).
- HMR (Hot Module Replacement) swaps a changed module in the running app without a full reload, preserving component state. This is what makes Vite/webpack-dev-server "instant" for local development.

## Self-check

Answer each in under 90 seconds, without notes:

1. A user's auth token needs to survive a page refresh. Where do you store it, and what attack does that choice expose you to?
2. Design the reconnection behavior for a WebSocket-based live chat that should survive a brief network drop without losing messages.
3. Explain hydration mismatch to someone who's never heard the term, with a concrete example that causes one.
4. Your team wants to split a monolith frontend across three teams. What's the actual problem you're solving, and what does it cost?
5. A list re-renders every keystroke in an unrelated search box. Walk through the diagnosis and fix.
