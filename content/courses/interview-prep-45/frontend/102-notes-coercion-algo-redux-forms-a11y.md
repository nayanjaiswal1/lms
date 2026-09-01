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

NaN is a special value of the Number type (IEEE 754), not a separate type of its own. Check for it with `Number.isNaN(x)`, never `x === NaN`, since `NaN !== NaN` by spec: NaN is defined as unequal to itself, so an equality check against it always fails.

## Semantic tags: why bother

Using `<header>`, `<nav>`, `<main>`, `<article>`, `<section>`, and `<footer>` instead of generic `<div>` pays off in three places:

- **SEO.** Crawlers weight semantic structure when parsing page content, so a page built from real landmarks is easier for them to summarize correctly.
- **Accessibility.** Screen readers navigate by landmark region. A user can jump straight to "navigation" or "main content" instead of the reader guessing at div nesting.
- **Maintainability.** The DOM documents its own structure, so a future reader doesn't need to grep class names to find "the nav."

## Responsive images

- `srcset` plus `sizes` lets the browser pick the right resolution image for the current viewport and device pixel ratio, instead of shipping one oversized file to every device regardless of screen size.
- `<picture>` is for art direction: swapping to a genuinely different crop per breakpoint, not just a different resolution of the same crop. Use it when a mobile layout needs a tighter crop of the same photo, not just a smaller version of the wide one.
- `loading="lazy"` defers below-the-fold images until they're near the viewport, so the browser doesn't spend bandwidth on images the user may never scroll to.

## `[1,2] + [3,4]` → `"1,23,4"`

`+` on two objects triggers `ToPrimitive`, which for arrays falls back to `.toString()`. `[1,2].toString()` produces `"1,2"` and `[3,4].toString()` produces `"3,4"`, and from there `+` does plain string concatenation: `"1,2" + "3,4"` gives `"1,23,4"`.

## Promise.any vs Promise.race

Both settle on the first promise to do something, but they differ on what that something is.

| | Settles when | All-reject / empty behavior |
|---|---|---|
| `Promise.race` | first promise **settles**, resolve or reject | empty array: stays pending forever |
| `Promise.any` | first promise **resolves** | rejects only if every promise rejects, with an `AggregateError`; empty array: rejects immediately |

`race` answers "whoever finishes first, win or lose." `any` answers "give me the first success, and only give up if nothing succeeds."

## Top-K frequency (algorithm pattern)

Start by building a frequency map, which is `O(n)`. Then pick an approach for extracting the top K:

- Sort by count: `O(n log n)`, the simplest to write under interview pressure.
- Min-heap of size K: `O(n log k)`, worth it when `k` is small relative to `n`, since you never hold more than K elements at once.
- Bucket sort by frequency, where the bucket index is the count and the max bucket size is `n`: `O(n)` and optimal, but more code to get right. Mention it to show you know it exists, and reach for actually writing it only if the interviewer pushes on complexity.

## Large array operations: avoiding accidental O(n²)

- `.includes()` or `.indexOf()` called inside a loop over another array is a hidden nested loop. Swap the array being searched into for a `Set` or `Map` so each lookup is O(1) instead of O(n).
- A `.map().filter().reduce()` chain builds a new intermediate array at every step. That's fine for readability at normal sizes, but for very large arrays a single `for` loop, or one `reduce` doing all the work, avoids the extra allocations.
- CPU-heavy work that blocks the main thread, as opposed to I/O-bound work, should be offloaded to a **Web Worker** rather than artificially chunked with `setTimeout` calls.

## Redux: reducer basics

A reducer is a pure function with the signature `(state, action) => newState`.

- Never mutate `state` directly. Always return a new object or array reference, because React and Redux detect changes with a reference-equality check, and a mutated-in-place object still has the same reference.
- `dispatch(action)` is the only way to trigger a reducer. `action` is a plain object with a `type` field and usually a `payload`.
- `combineReducers` lets each reducer own one slice of state, which keeps individual reducers small and independently testable.

## Reusable form component with validation

- Use controlled inputs, meaning value and onChange are both wired to state, so the component always reflects the current form state exactly.
- Centralize validation in one place, either a schema library like Zod or Yup, or a single plain validation function, rather than scattering `if` checks across each field's `onChange` handler.
- Watch re-render cost. Re-validating and re-rendering the whole form on every keystroke gets slow past a handful of fields. **React Hook Form** avoids this by keeping inputs uncontrolled internally and only re-rendering on submit or blur, and it's worth naming as the answer to "how would you make this scale to a big form."

## Accessibility (a11y)

- Reach for semantic HTML first. A `<button>` is keyboard-operable and screen-reader-announced for free; a `<div onClick>` gets neither behavior unless you build it yourself.
- Use `aria-*` attributes only to fill gaps semantics can't cover, such as `aria-live` for a toast notification or `aria-expanded` on a custom disclosure widget. Don't reach for ARIA before reaching for the right tag.
- Every interactive element must be reachable and operable via `Tab`, `Enter`, and `Space`, with a visible focus state. Never use `outline: none` without providing a replacement focus style.
- For an automated baseline, lint with `eslint-plugin-jsx-a11y` and run `axe-core` in tests. Both catch missing labels, missing alt text, and contrast issues before a human reviewer has to.
