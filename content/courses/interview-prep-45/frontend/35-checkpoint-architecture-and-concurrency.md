---
kind: lesson
id_key: interview-prep-45/day-21-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Checkpoint: Architecture and Concurrency"
position: 35
estimated_minutes: 18
source:
    - 45-day-interview-roadmap.md
---
Third consolidation checkpoint. This stretch covered security, real-time communication, server rendering, architectural scale, concurrent React, and build tooling, a wide spread that interviewers love to mix into a single system-design-adjacent conversation. Drill the connections between these topics, not just each one in isolation.

## Web security

Core idea: never trust data that crossed a trust boundary, user input, a third-party response, a URL parameter, without validating or encoding it. React escapes text content by default; the danger zone is `dangerouslySetInnerHTML` and any place raw HTML from an untrusted source gets injected without sanitization. CSRF defense is same-site cookies plus a token on state-changing requests, and it's still relevant with JWTs the moment the token lives in a cookie rather than a manually-attached header. CSP is the last line of defense, turning a successful injection into a no-op because the injected script violates policy. Where the token lives is the near-guaranteed question: `localStorage` is readable by any injected script, `httpOnly` cookies aren't readable by JS at all but need CSRF protection instead.

## WebSockets

Core idea: a persistent, full-duplex connection for real-time, bidirectional communication, distinct from HTTP's request/response model. The handshake starts as an HTTP request with an `Upgrade: websocket` header, and the server responds `101 Switching Protocols`. Reconnection strategy matters in production: exponential backoff with a cap, plus a heartbeat to detect a dead connection before the OS notices on its own. Compare against the alternatives by direction and overhead: SSE is one-way and simple, works over plain HTTP, and auto-reconnects; long polling works everywhere but costs more latency and overhead; WebSockets are full duplex, more setup, and needed for anything requiring client-to-server push at low latency.

## SSR and Next.js

Core idea: move rendering work earlier, to build time or the server, to improve perceived load time and SEO, at the cost of server compute and more moving parts. SSR renders per request, SSG renders once at build time, ISR serves a static page but revalidates it on a schedule. React Server Components run only on the server, never ship their JS to the client, and can touch backend resources directly, at the cost of no hooks and no browser APIs, exactly what `"use client"` opts back into. Hydration is the step where client-side React attaches listeners to server-rendered HTML; a mismatch, server HTML differing from what the client would render, usually traces back to `Date.now()`, `Math.random()`, or a browser-only API read during render.

## Micro-frontends

Core idea: split a large frontend into independently deployable pieces owned by different teams, an organizational scaling solution more than a technical one. Composition strategies: build-time integration via npm packages, server-side composition at the edge, runtime composition via Module Federation or iframes. Costs worth naming unprompted: duplicated dependencies across bundles unless carefully shared, harder cross-team design consistency, more complex versioning and deployment coordination. The interview-safe framing: reach for this when multiple independent teams genuinely need separate release cadences, not by default.

## React performance and concurrent features

Core idea: avoid unnecessary re-renders, and avoid unnecessary work inside the renders that do happen. `React.memo` skips a re-render on shallow-equal props and does nothing if a parent passes a new object, array, or function literal every render, pair it with `useMemo`/`useCallback` on the parent for exactly those values. Automatic batching in React 18+ means multiple `setState` calls anywhere, not just inside React event handlers, collapse into one render. `useTransition` marks an update as non-urgent so React can interrupt it for something more urgent, like a keystroke; `useDeferredValue` gives a lagging copy of a value you don't control the setter for, the same underlying goal reached from the consumer side instead.

## Build tools

Core idea: know what a bundler and dev server actually do, not just the CLI commands. Vite's dev-server speed comes from serving native ES modules over the network unbundled, using esbuild, written in Go, for transpilation, and only bundling for production via Rollup. Webpack's loader/plugin model: loaders transform individual files, plugins hook into the broader build lifecycle. HMR swaps a changed module in the running app without a full reload, preserving component state, and React's Fast Refresh extends that specifically by confirming a component's hook order is unchanged before it decides state can safely survive the edit.

## Self-check

Answer each in under 90 seconds, without notes:

1. A user's auth token needs to survive a page refresh. Where do you store it, and what attack does that specific choice expose you to?
2. Design the reconnection behavior for a WebSocket-based live chat that should survive a brief network drop without losing messages.
3. Explain hydration mismatch to someone who's never heard the term, with a concrete example that causes one.
4. Your team wants to split a monolith frontend across three teams. What's the actual problem you're solving, and what does it cost?
5. A list re-renders on every keystroke in an unrelated search box. Walk through the diagnosis and fix, naming which concurrent API, if any, applies.
6. Why does `import * as _ from "lodash"` defeat tree shaking when `import { debounce } from "lodash-es"` doesn't?
