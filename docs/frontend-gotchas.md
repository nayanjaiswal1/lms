# Frontend Gotchas

Non-obvious frontend bugs that cost real debugging time, recorded so they aren't
reintroduced elsewhere in the codebase. Each entry: what broke, why, the fix,
and the check that would have caught it sooner.

---

## Radix Popover content inside a Dialog silently can't be wheel-scrolled

**What broke:** `MultiSelectDropdown`'s dropdown list (opened from inside
`ManageRolesDialog`) had perfect scroll CSS (`overflow-y-auto`, `scrollHeight`
> `clientHeight`) but mouse-wheel scrolling did nothing.

**Root cause:** Radix `Dialog`'s scroll lock (`react-remove-scroll`) only
shards its own `contentRef`. Radix `Popover` only installs a competing lock
when `modal={true}` (default `false`). Our Popover portals to `document.body`
as a **sibling** of the Dialog's content, so it's invisible to the Dialog's
shard list — every wheel event on it gets `preventDefault()`'d as "outside"
traffic, regardless of its own scrollability.

`modal={true}` is **not** the fix: it also enables focus-trap + `aria-hidden`
+ pointer-lock on everything outside `PopoverContent`, which breaks any layout
(like this one) where the trigger/input lives in the anchor, not the content.

**Fix:** wrap just the scrollable region in `RemoveScroll` (`react-remove-scroll`
— added as a direct dep; already transitive via Radix):

```tsx
import { RemoveScroll } from "react-remove-scroll";
<RemoveScroll allowPinchZoom><CommandList>...</CommandList></RemoveScroll>
```

This pushes onto `react-remove-scroll`'s shared lock stack, making it the
active lock while open, without Popover's `modal` side effects.

**Rule:** any scrollable Popover/DropdownMenu/HoverCard content that can open
inside a Dialog/Sheet/AlertDialog needs this wrap. Verify with a real event,
not CSS inspection and not an automation tool's synthetic scroll (CDP's wheel
dispatch can move `scrollTop` directly, bypassing `preventDefault` — false pass):

```js
const el = document.querySelector('[cmdk-list]');
const before = el.scrollTop;
const ev = new WheelEvent('wheel', { deltaY: 150, bubbles: true, cancelable: true });
el.dispatchEvent(ev);
// pass requires BOTH: el.scrollTop > before AND ev.defaultPrevented === false
```

Only `MultiSelectDropdown` had this pattern as of this writing (checked via
`grep -r CommandList\|PopoverContent`) — re-check when adding a new searchable
dropdown inside a modal.

---

## Popper components (Select/Dropdown/Tooltip) render behind an open Dialog

**What broke:** a `<Select>` opened from inside a `<Dialog>` rendered its
options underneath the dialog's own backdrop/content instead of on top.

**Root cause:** Select/DropdownMenu/ContextMenu/Tooltip render their content
via a Radix Portal to `document.body` — a DOM **sibling** of `DialogContent`,
not a descendant. Nesting one inside a `<Dialog>` does not inherit the
dialog's stacking context; only the raw z-index number decides who's on top.

**Rule:** `z-dropdown` (450) is deliberately *above* `z-modal` (400) in the
named layer scale (`z-raised` 10 < `z-sticky` 200 < `z-overlay` 300 <
`z-modal` 400 < `z-dropdown` 450 < `z-toast` 500). Any popper-based component
must out-rank `z-modal` or it silently renders behind an open dialog/sheet/
alert-dialog the first time it's used inside one. Never hardcode `z-[400]` or
`z-50` — use the named classes so this ordering stays auditable.

---

## A code/slug/UUID/email in a flex or grid cell overflows into the next column

**What broke:** a permission code (`assessments.manage_batches`) or long UUID
rendered inside a grid/flex cell visually spilled into the next card/column —
looked like a spacing bug, but no amount of padding or gap fixed it.

**Root cause:** flex and grid items default to `min-width: auto` — they will
not shrink below the intrinsic width of their content. A long token with no
spaces has a large intrinsic width, forcing the item wider than its
column/track.

**Fix:** add `min-w-0` to the flex/grid item (or its direct text wrapper),
plus `truncate` (single-line ellipsis) or `break-all` (wraps mid-token) on the
text itself. Reach for `whitespace-nowrap` + `.table-responsive` scrolling
only inside an actual `<table>` — inside a card/grid layout there's no scroll
container, so the text must wrap or truncate in place.

---

## `page-container`/`page-container-sm` with `py-*` triples a page's top padding

**What broke:** flagged on `/users` — visibly more dead space above the page
title than the sidebar logo's own padding. Turned out to affect ~63 pages
across the whole `(app)/` and `platform/` route groups, not just `/users`.

**Root cause:** `.page-container` (`globals.css` ~line 339) is horizontal-only
by design: `mx-auto max-w-7xl px-6 sm:px-8 lg:px-12`. Vertical spacing is meant
to come from two other layers: `.app-content` (`(app)/layout.tsx` and
`platform/layout.tsx`, both render `<main className="app-content">`, defined
as `p-4 sm:p-6 lg:p-8` — ALL four sides, not just horizontal) and `.page-header`
(`py-6`, for the title itself). Many pages additionally bolted a `py-*`
straight onto their outer `page-container` div anyway (`<div
className="page-container py-8">`), stacking THREE layers of top padding —
on `/users` that was `.app-content`'s 32px + the bolted-on 32px + `.page-header`'s
24px = 88px before the heading's own line-height even started.

**Fix:** stripped the redundant `py-*`/`sm:py-*`/`lg:py-*` token from all 63
files, keeping every other class on that element untouched (`flex`, `gap-*`,
`min-h-dvh`, `space-y-*`, etc. all stay — `space-y-*` is child spacing, not the
container's own padding, and was never part of the bug).

One legitimate exception: `app/(app)/courses/[slug]/learn/[moduleId]/page.tsx`
— its `page-container` is a nested content column three levels deep inside a
custom sidebar/article split (`flex ... lg:flex-row` > `<main>` >
`page-container`), not the page's top-level shell. There's no `.page-header`
in that tree, so `py-6 lg:py-8` there is the column's *only* vertical spacing,
not a redundant stack. Marked with `eslint-disable-next-line` and a reason
comment rather than silently left unfixed, so it doesn't look like a missed
case on the next audit.

**The check that would have caught it sooner:** an ESLint `no-restricted-syntax`
rule in `frontend/eslint.config.mjs` (grouped with the other `[Design]`-tagged
rules, right after the `h-screen` ban) now errors on any `className` containing
both `page-container`/`page-container-sm` and a `py-\d` token:

```js
{
  selector: `JSXAttribute[name.name="className"] Literal[value=/(?=.*\\bpage-container(-sm)?\\b)(?=.*\\bpy-\\d)/]`,
  message: '[Design] Do not add py-* to page-container/page-container-sm. ' +
    '.app-content already provides page-level vertical padding and .page-header provides title spacing — ' +
    'stacking py-* here triples the top/bottom whitespace. ' +
    'If this is a nested content column (no .page-header), disable this line with a reason.',
}
```

If a future page genuinely needs `page-container` as a nested column with no
`.page-header` (like the courses/learn case above), disable that one line with
a comment explaining why — don't weaken or remove the rule itself.
