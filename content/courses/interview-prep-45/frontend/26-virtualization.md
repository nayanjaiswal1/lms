---
kind: lesson
id_key: interview-prep-45/day-10-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "Virtualization"
position: 26
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---
Render a 10,000-row table the ordinary way and you've built 10,000 DOM nodes, and the user can only ever see about 20 of them at once. Virtualization keeps the number of DOM nodes small no matter how much data there is. It's a near-guaranteed interview question for anyone claiming React performance experience: "how would you render a huge list?"

## The idea: only build what's on screen

Picture a movie reel. Only one frame is ever in front of the lens at a time, even though the reel holds thousands of them. Virtualization treats a long list the same way: only render the items currently visible, plus a small buffer, and reuse the same handful of DOM nodes as the user scrolls, instead of keeping a node alive for every single row forever.

In practice, when someone says "virtualize this list," they mean: keep the number of rendered DOM nodes roughly constant, no matter how many rows the actual data has.

> **Remember:** virtualization doesn't make each row cheaper. It just stops rendering rows nobody can see yet.

## Building it by hand once

Understanding the mechanism is what an interviewer actually wants, whether you end up hand-writing it or reaching for a library.

```tsx
function FixedHeightVirtualList<T>({ items, itemHeight, containerHeight, overscan = 3, renderItem }: {
  items: T[]; itemHeight: number; containerHeight: number; overscan?: number; renderItem: (item: T, index: number) => React.ReactNode;
}) {
  const [scrollTop, setScrollTop] = useState(0);
  const totalHeight = items.length * itemHeight;

  const startIndex = Math.max(0, Math.floor(scrollTop / itemHeight) - overscan);
  const visibleCount = Math.ceil(containerHeight / itemHeight) + overscan * 2;
  const endIndex = Math.min(items.length - 1, startIndex + visibleCount);
  const visibleItems = useMemo(() => items.slice(startIndex, endIndex + 1), [items, startIndex, endIndex]);

  return (
    <div onScroll={(e) => setScrollTop(e.currentTarget.scrollTop)} style={{ height: containerHeight, overflowY: "auto", position: "relative" }}>
      <div style={{ height: totalHeight, position: "relative" }}>
        {visibleItems.map((item, i) => {
          const index = startIndex + i;
          return <div key={index} style={{ position: "absolute", top: index * itemHeight, left: 0, right: 0, height: itemHeight }}>{renderItem(item, index)}</div>;
        })}
      </div>
    </div>
  );
}
```

Three pieces make this work together. An outer scroll box with a fixed height, this is the only thing that actually scrolls. An inner spacer sized to `items.length * itemHeight`, so the scrollbar behaves exactly as if every row were real, even though almost none of them are. And rows placed with `position: absolute` and `top: index * itemHeight`, only for the visible slice, so each one lands exactly where it would sit if the whole list existed. Minus a lot of edge-case handling, this is what `react-window`'s `FixedSizeList` does under the hood.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-virt-mechanism-q1", "type": "mcq",
      "prompt": "In a hand-rolled virtual list, why does the inner container need a spacer sized to items.length * itemHeight, even though most of that space holds no actual rendered rows?",
      "options": [
        {"id":"a","text":"To make the code easier to read"},
        {"id":"b","text":"So the scrollbar behaves exactly as if every row were rendered, giving the user a correct sense of total list length and scroll position"},
        {"id":"c","text":"It's required by React and has no functional purpose"},
        {"id":"d","text":"To prevent a memory leak"}
      ],
      "correct": "b",
      "explanation": "Without the full-height spacer, the scroll container would only be as tall as the few rendered rows, making the scrollbar wildly wrong about how much content actually exists." }
] }
```

## Using react-window in production code

```tsx
import { FixedSizeList } from "react-window";

function RowRenderer({ index, style, data }: { index: number; style: React.CSSProperties; data: Row[] }) {
  return <div style={style} className="row">{data[index].name}</div>;
}

function BigList({ rows }: { rows: Row[] }) {
  return (
    <FixedSizeList height={600} width="100%" itemCount={rows.length} itemSize={48} itemData={rows} overscanCount={5}>
      {RowRenderer}
    </FixedSizeList>
  );
}
```

`react-window` computes the `style` prop for you, position and height already worked out, you just apply it to your row. Passing data through `itemData`, instead of just closing over `rows` from an outer scope, matters because `react-window` wraps each row in `React.memo` internally, and a closure would give the row renderer a fresh identity on every render, the exact mistake that quietly defeats `React.memo`.

> **Remember:** pass shared data through `itemData`, not a closure, or you silently break `react-window`'s own memoization.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-virt-reactwindow-q1", "type": "mcq",
      "prompt": "Why does react-window's FixedSizeList take an itemData prop instead of letting the row renderer just close over the array from an outer scope?",
      "options": [
        {"id":"a","text":"itemData is required syntax with no real effect"},
        {"id":"b","text":"react-window wraps rows in React.memo internally; a closure creates a new row-renderer identity every render, which defeats that memoization, itemData avoids it"},
        {"id":"c","text":"Closures don't work inside react-window at all"},
        {"id":"d","text":"itemData makes the list scroll faster"}
      ],
      "correct": "b",
      "explanation": "This is the same React.memo-defeating mistake covered in the performance lesson, applied specifically to a virtualized list's row renderer." }
] }
```

## Variable-height items: the harder real case

Fixed-height virtualization is the easy version. Real lists, chat messages, comments, feed items, have heights that vary, which breaks the simple `index × itemHeight` math completely.

If the height is knowable from the data itself, before rendering, `VariableSizeList` handles it directly:

```tsx
import { VariableSizeList } from "react-window";
function getItemSize(index: number) { return items[index].isLong ? 120 : 60; }
```

If the height is only knowable after the row actually renders, the common real case, since text wraps differently depending on content and container width, `@tanstack/react-virtual` is built for exactly this, using a `ResizeObserver` under the hood.

```tsx
import { useVirtualizer } from "@tanstack/react-virtual";

function DynamicList({ items }: { items: string[] }) {
  const parentRef = useRef<HTMLDivElement>(null);
  const virtualizer = useVirtualizer({ count: items.length, getScrollElement: () => parentRef.current, estimateSize: () => 60, overscan: 5 });

  return (
    <div ref={parentRef} style={{ height: 600, overflow: "auto" }}>
      <div style={{ height: virtualizer.getTotalSize(), position: "relative" }}>
        {virtualizer.getVirtualItems().map((row) => (
          <div key={row.key} data-index={row.index} ref={virtualizer.measureElement}
            style={{ position: "absolute", top: 0, left: 0, width: "100%", transform: `translateY(${row.start}px)` }}>
            {items[row.index]}
          </div>
        ))}
      </div>
    </div>
  );
}
```

`estimateSize` is just a starting guess. `measureElement` corrects it the moment the real row renders, and the virtualizer recalculates everything below it. This is the exact answer to "how would you virtualize a list where row height genuinely isn't known ahead of time."

> **Remember:** known height ahead of time -> `VariableSizeList`. Height only known after render -> measure it and correct.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-virt-variable-q1", "type": "mcq",
      "prompt": "A chat app needs to virtualize a message list where each message's height depends on how much its text wraps, unknown until the message actually renders. What's the right tool?",
      "options": [
        {"id":"a","text":"FixedSizeList with an average height guess"},
        {"id":"b","text":"@tanstack/react-virtual, which uses ResizeObserver to measure each row after it renders and corrects the estimated positions from there"},
        {"id":"c","text":"VariableSizeList, since the heights vary"},
        {"id":"d","text":"Rendering the entire list without virtualization"}
      ],
      "correct": "b",
      "explanation": "VariableSizeList still needs the height known ahead of render. When height is only knowable after the row paints, a measure-and-correct approach like react-virtual's is the right tool." }
] }
```

## Overscan: trading extra nodes for a smoother scroll

Overscan is how many extra rows get rendered just outside the visible area, in the direction of scrolling. Without it, scrolling fast can outrun the render and flash a blank frame before new rows paint. It's a direct multiplier on node count, `overscan={5}` on both edges means `visibleCount + 10` nodes instead of just `visibleCount`. Too low and fast scrolling flashes blank; too high and you've quietly defeated the whole point of virtualizing. Typical values run from 3 to 10, depending on how heavy each row is and how fast users tend to scroll.

> **Remember:** overscan trades a few extra rendered nodes for hiding the "blank flash" on a fast scroll.

## What virtualization costs, and when to skip it

Virtualizing a list breaks a few things browsers normally give you for free: `Ctrl+F` can't find text in a row that isn't currently rendered, `Cmd+A` only copies what's mounted right now, and jumping to an item by its anchor link fails silently if that item isn't rendered yet. There's an accessibility cost too: a screen reader relying on the full DOM tree only sees the current window, which usually means adding `aria-setsize`/`aria-posinset` on each row to communicate its true position in the full list. And variable-height virtualization with dynamic content, sticky headers, and grouped sections is genuinely hard to get exactly right, bugs show up as a jumpy scroll position or rows painting at the wrong spot.

A list under a few hundred items rarely needs any of this, the plain DOM handles it fine. Measure first, and only virtualize once the row count is genuinely unbounded or already in the thousands.

## Combining it with a live-updating list

A frequently-polled or real-time list adds a second problem on top of raw row count: swapping the entire items array on every poll re-renders the whole visible window, even if only one or two rows actually changed. Two fixes work together here. Diff and patch just the changed rows instead of replacing the array wholesale, so the list doesn't have to re-measure everything on every tick. And avoid firing duplicate requests for overlapping data in the first place, a query library's cache, keyed by something like a `queryKey`, already dedupes identical in-flight requests coming from separate components.

> **Remember:** for a live list, fix duplicate re-renders by diffing rows, and fix duplicate network calls by deduping requests, they're separate problems with separate fixes.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-virt-costs-q1", "type": "mcq",
      "prompt": "Under a few hundred rows, is virtualizing a list generally worth the added complexity?",
      "options": [
        {"id":"a","text":"Yes, always virtualize any list, no matter the size"},
        {"id":"b","text":"No — the plain DOM handles a few hundred nodes fine on its own; virtualization is worth its cost once the row count is genuinely unbounded or in the thousands"},
        {"id":"c","text":"Only if the list contains images"},
        {"id":"d","text":"Virtualization has no real cost, so it should always be used"}
      ],
      "correct": "b",
      "explanation": "Virtualization breaks native find-in-page, select-all-copy, and anchor scrolling, and adds real implementation complexity. Below a few hundred items, none of that cost buys you anything a plain rendered list wasn't already handling fine." }
] }
```
