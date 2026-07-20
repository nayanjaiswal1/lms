---
kind: lesson
id_key: interview-prep-45/note-coercion-algo-redux-forms-a11y
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: Type Coercion, Algorithms, Redux, Forms & Accessibility"
position: 102
estimated_minutes: 25
source:
    - interview-prep-notes.md
---

## typeof NaN

```js
typeof NaN; // "number"
```

NaN is a special value *of* the Number type (IEEE 754), not a separate type. Check for it with `Number.isNaN(x)` — never `x === NaN`, since `NaN !== NaN` by spec.

## Semantic tags — why bother

`<header>`, `<nav>`, `<main>`, `<article>`, `<section>`, `<footer>` instead of generic `<div>`:
- **SEO** — crawlers weight semantic structure when parsing page content.
- **Accessibility** — screen readers navigate by landmark region, not by guessing div nesting.
- **Maintainability** — the DOM documents its own structure; no need to grep class names to find "the nav".

## Responsive images

- `srcset` + `sizes` — lets the browser pick the right resolution image for the viewport/DPR, instead of shipping one oversized file to every device.
- `<picture>` — for *art direction*: swapping to a genuinely different crop per breakpoint, not just a different resolution of the same crop.
- `loading="lazy"` — defers below-the-fold images until they're near the viewport.

## `[1,2] + [3,4]` → `"1,23,4"`

`+` on two objects triggers `ToPrimitive`, which for arrays falls back to `.toString()`. `[1,2].toString()` is `"1,2"`, `[3,4].toString()` is `"3,4"` — then `+` does plain string concatenation: `"1,2" + "3,4"` → `"1,23,4"`.

## Promise.any vs Promise.race

Both settle on the *first* promise to do something, but differ on what:

| | Settles when | All-reject/empty behavior |
|---|---|---|
| `Promise.race` | first promise **settles** (resolve OR reject) | empty → pending forever |
| `Promise.any` | first promise **resolves** | rejects only if *all* reject, with `AggregateError`; empty → rejects immediately |

`race` cares about "whoever finishes first, win or lose." `any` cares about "give me the first success, and only give up if nothing succeeds."

## Top-K frequency (algorithm pattern)

1. Build a frequency map — `O(n)`.
2. Then pick one:
   - Sort by count — `O(n log n)`, simplest to write under pressure.
   - Min-heap of size K — `O(n log k)`, better when `k` is small relative to `n`.
   - Bucket sort by frequency (bucket index = count, max bucket size = n) — `O(n)`, optimal, but more code — mention it, reach for it only if the interviewer pushes on complexity.

## Large array operations — avoiding accidental O(n²)

- `.includes()`/`.indexOf()` inside a loop over another array is a hidden nested loop — swap the searched-into array for a `Set`/`Map` for O(1) lookup.
- A `.map().filter().reduce()` chain builds an intermediate array at every step. Fine for readability at normal sizes; for very large arrays, a single `for` loop or one `reduce` doing all the work avoids the extra allocations.
- CPU-heavy work (not I/O) that would block the main thread → offload to a **Web Worker** instead of chunking with `setTimeout`.

## Redux — reducer basics

A reducer is a pure function: `(state, action) => newState`.
- Never mutate `state` directly — always return a new object/array reference, or React/Redux won't detect the change (reference-equality check).
- `dispatch(action)` is the only way to trigger a reducer; `action` is a plain object with a `type` (and usually a `payload`).
- Combine multiple reducers (`combineReducers`) so each owns one slice of state — keeps individual reducers small and testable.

## Reusable form component with validation

- Controlled inputs (value + onChange wired to state) so the component always reflects current form state.
- Centralize validation — either a schema library (Zod/Yup) or a plain validation function — rather than scattering `if` checks across each field's `onChange`.
- Watch re-render cost: re-validating and re-rendering the *whole form* on every keystroke gets slow past a handful of fields. **React Hook Form** avoids this by keeping inputs uncontrolled internally and only re-rendering on submit/blur — worth naming as the answer to "how would you make this scale to a big form."

## Accessibility (a11y)

- Semantic HTML first — a `<button>` is keyboard-operable and screen-reader-announced for free; a `<div onClick>` is not.
- `aria-*` attributes only to fill gaps semantics can't cover (e.g. `aria-live` for a toast, `aria-expanded` on a custom disclosure) — don't reach for ARIA before reaching for the right tag.
- Keyboard navigation — every interactive element must be reachable and operable via `Tab`/`Enter`/`Space`, with a visible focus state (never `outline: none` without a replacement).
- Automated baseline: lint with `eslint-plugin-jsx-a11y` and/or run `axe-core` in tests — catches missing labels/alt text/contrast issues before a human review does.
