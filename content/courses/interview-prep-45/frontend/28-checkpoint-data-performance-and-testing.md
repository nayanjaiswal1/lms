---
kind: lesson
id_key: interview-prep-45/day-14-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Checkpoint: Data, Performance, and Testing"
position: 28
estimated_minutes: 18
source:
    - 45-day-interview-roadmap.md
---
Another consolidation day, not a new-material one. Spend it drilling the material from HTTP caching through testing until the answers come out fast and precise. A senior candidate is expected to explain all of this without a warm-up lap.

## HTTP, caching, and the network

Core idea: minimize what has to travel over the wire, and how long the user waits for it. `no-cache` means always revalidate before using a stored response; `no-store` means never persist it anywhere. `ETag`/`If-None-Match` lets the server answer "nothing changed" with a bodyless `304` instead of resending content. `stale-while-revalidate` serves the cached response instantly while quietly fetching a fresh one for next time, the pattern SWR and TanStack Query are both named after. Content-hashed asset URLs are the strongest cache-invalidation strategy that exists, because there's nothing to invalidate, a change just produces a different URL.

**Say this out loud, unprompted, if asked to diagnose a slow page load:** read the waterfall first, TTFB points at the server, a staircase pattern points at a synchronous discovery chain, then check whether Core Web Vitals field data (real users) or lab data (Lighthouse) is what's actually being discussed, since they can disagree.

## Code splitting and bundling

Core idea: ship only the JavaScript the current view needs, and defer the rest until it's actually required. Tree shaking needs ES modules and a `sideEffects: false` boundary; CommonJS or an unmarked side effect defeats it silently. `React.lazy(() => import(...))` needs a default export and a `Suspense` boundary; an error boundary handles the chunk-load-failure case that `Suspense` alone can't. Route-level splitting is the highest-leverage place to split, and prefetching on hover or focus hides the loading waterfall it introduces. Never optimize a bundle you haven't measured, and enforce the result with a CI budget so a regression can't ship silently.

**Say this out loud, unprompted, if asked why `import * as _ from "lodash"` doesn't tree-shake:** namespace imports make every property access a dynamic lookup the bundler can't statically resolve; named imports expose the exact symbol at the import statement, which is what dead-code elimination actually needs.

## Virtualization

Core idea: keep the DOM node count roughly constant regardless of how much data there is, by rendering only the currently visible window. The mechanism is a spacer sized to `totalItems × itemHeight` for correct scrollbar behavior, with absolutely-positioned rows for only the visible slice. Fixed height means simple index math; unknown or variable height means measuring after render with a `ResizeObserver`. Overscan trades extra rendered nodes for a smoother fast scroll; too much of it defeats the entire point.

**Say this out loud, unprompted, if asked what virtualization costs:** it breaks native find-in-page and select-all-copy, complicates anchor scrolling and accessibility semantics, and isn't worth the complexity below a few hundred rows.

## GraphQL and data fetching

Core idea: GraphQL trades HTTP-level caching and server simplicity for a client that can ask for exactly the fields it needs in one round trip, worth it specifically when the frontend genuinely composes data from many related resources. The N+1 problem, one query per parent times N children, is the most common GraphQL performance trap, and DataLoader fixes it by batching every `.load(id)` call within one event-loop tick into a single query. A query library like React Query dedupes in-flight requests and caches by key, which Context structurally cannot do, since every Context consumer re-renders on any change to the value regardless of whether that consumer cares about it.

**Say this out loud, unprompted, if asked when you'd reach for GraphQL over REST:** when the frontend needs to compose deeply nested or related data in one request and the team is willing to give up free HTTP caching for it, not as a default choice.

## TypeScript for React

Core idea: catch shape mismatches at compile time, especially at trust boundaries like API responses. Generic components need `<T,>` or an `extends` clause in arrow-function form to avoid JSX-tag ambiguity. `Partial`, `Pick`, `Omit`, and `Record` cover most day-to-day prop-shape reuse. Type event handlers with the specific synthetic event generic to get a correctly-typed target. `as T` after `.json()` is an assertion, not runtime validation, a real trust boundary needs a schema library so the type can never drift from the actual response shape. Discriminated unions make impossible state combinations unrepresentable in the type itself.

**Say this out loud, unprompted, if asked to type a fetch hook live:** reach for a discriminated union over `{ status: "idle" | "loading" | "success" | "error" }` with per-branch payload fields, not four separate booleans.

## React Testing

Core idea: test what the user experiences, not a component's internals. Query priority runs `getByRole` > `getByLabelText` > `getByText` > `getByTestId`. `getBy*` throws (assert presence), `queryBy*` returns `null` (assert absence), `findBy*` is async (wait for appearance). Mock at the network boundary with MSW rather than mocking `fetch` directly, so a test never gets coupled to how data is fetched. Coverage is a floor for finding untested branches, never a quality target, a render-only test with no assertion inflates the number and catches nothing.

**Say this out loud, unprompted, if asked to write the two most important tests for a form with a submit button and a validation error:** one confirming a valid submission calls the handler with the right values, one confirming an invalid submission shows the error and never calls the handler.

## Self-check

1. Walk through what happens from `import("./Component")` being called to the component appearing on screen, including where the loading state and any chunk-load failure get handled.
2. Design a virtualized list for chat messages where each message's height depends on its content.
3. A dashboard polls five widgets independently, and three of them request overlapping data. What fixes the duplicate requests, and what fixes the re-render cost?
4. Type a `useFetch<T>` hook end to end, including the loading, error, and success states, and explain why a discriminated union is the right shape for it.
5. Given a component with a "Submit" button and a validation error message, write the two RTL tests that matter most, and explain why a third test asserting `render()` doesn't throw wouldn't add real confidence.
