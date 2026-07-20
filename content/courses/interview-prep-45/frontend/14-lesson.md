---
kind: lesson
id_key: interview-prep-45/day-14-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Day 14 — Weekly Review"
position: 17
estimated_minutes: 18
source:
    - 45-day-interview-roadmap.md
---

This is a consolidation day, not a new-material day. Spend it drilling the interview questions from this week until the answers come out fast and precise — an interviewer expects a senior candidate to explain these without warm-up.

## Network Performance

Core idea: minimize what has to travel over the wire and how long the user waits for it. Be ready to explain, in one or two sentences each:

- The difference between preload, prefetch, and preconnect, and when each applies.
- How HTTP/2 multiplexing changed the "domain sharding" advice from HTTP/1.1.
- How you'd diagnose a slow page load using the Network tab's waterfall (DNS, TCP/TLS, TTFB, download).
- What Core Web Vitals measure (LCP, INP, CLS) and one concrete fix for each.

## Code Splitting

Core idea: ship only the JavaScript the current view needs, defer the rest.

- Tree shaking requires ES modules and a `sideEffects: false` package boundary — CommonJS or unmarked side effects silently defeat it.
- `React.lazy(() => import(...))` needs a default export and a `Suspense` boundary; an error boundary handles the chunk-load failure case.
- Route-level splitting is the highest-leverage split point; prefetch on hover/focus to hide the loading waterfall.
- Never optimize a bundle you haven't measured — `source-map-explorer` or a visualizer, then a CI-enforced budget so regressions can't ship silently.

## Virtualization

Core idea: keep the DOM node count constant regardless of data size by rendering only the visible window.

- The mechanism: a spacer div sized to `totalItems × itemHeight` for correct scrollbar behavior, absolutely-positioned rows for only the visible slice.
- Fixed height → simple index math (`react-window`'s `FixedSizeList`). Unknown/variable height → measure after render (`@tanstack/react-virtual` + `ResizeObserver`).
- Overscan trades extra rendered nodes for a smoother fast-scroll (no blank flash) — too much defeats the point of virtualizing.
- Name the trade-offs unprompted: breaks native find-in-page, breaks select-all-copy, complicates anchor scrolling and accessibility semantics.

## Rendering Performance

Core idea: control which pipeline stages (Style → Layout → Paint → Composite) a change triggers.

- `transform`/`opacity` can skip layout and paint entirely and go straight to the compositor — this is why they're the default choice for animation.
- `will-change` should be set right before an animation and removed right after — permanent use fragments the page into too many GPU layers.
- Layout thrashing = interleaved DOM reads/writes in a loop forcing synchronous layout on every iteration; fix by batching all reads, then all writes.
- `contain` and `content-visibility: auto` let the browser skip layout/paint for isolated or off-screen content with zero JavaScript.

## TypeScript for React

Core idea: catch shape mismatches at compile time, especially at trust boundaries like API responses.

- Generic components need `<T,>` or an `extends` clause in arrow-function form to avoid JSX-tag ambiguity.
- `Partial`, `Pick`, `Omit`, `Record` cover most day-to-day prop-shape reuse.
- Type event handlers with the specific synthetic event generic (`React.ChangeEvent<HTMLInputElement>`) to get a correctly-typed target.
- `as T` after `.json()` is an assertion, not runtime validation — real trust boundaries need a schema library (Zod) so the type can't drift from the actual response shape.
- Discriminated unions (`{ status: "loading" } | { status: "success"; data: T }`) make impossible state combinations unrepresentable.

## React Testing

Core idea: test what the user experiences, not component internals.

- Query priority: `getByRole` > `getByLabelText` > `getByText` > `getByTestId`. `getBy*` throws (assert presence), `queryBy*` returns null (assert absence), `findBy*` is async (wait for appearance).
- `userEvent` over `fireEvent` — it simulates the full realistic interaction sequence, not a single raw event.
- Mock at the network boundary (MSW) rather than mocking `fetch` directly, so tests don't couple to *how* data is fetched.
- Coverage percentage is a floor for finding untested branches, not a quality target — a render-only test with no assertion inflates coverage and catches nothing.

## Self-check

Before moving on, you should be able to answer each of these out loud, in under 90 seconds, without notes:

1. Walk through what happens from `import("./Component")` being called to the component appearing on screen.
2. Design a virtualized list for chat messages where each message's height depends on its content.
3. A user reports the page "feels janky" while scrolling — what do you check first, and in what order?
4. Type a `useFetch<T>` hook end to end, including the loading/error/success states.
5. Given a component with a "Submit" button and a validation error message, write the two RTL tests that matter most.

## Today's checklist

- [ ] Network Performance: Completed
- [ ] Code Splitting: Completed
- [ ] Virtualization: Completed
- [ ] Rendering Performance: Completed
- [ ] TypeScript: Completed
- [ ] Testing: Completed
