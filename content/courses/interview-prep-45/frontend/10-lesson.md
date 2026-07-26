---
kind: lesson
id_key: interview-prep-45/day-10-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Virtualization"
position: 13
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---

Render a 10,000-row table the naive way and you'll create 10,000 DOM nodes, most of which the user never sees. Virtualization is the technique that keeps the DOM small regardless of data size, and it's a near-guaranteed interview question for anyone claiming React performance experience — either "how would you render a huge list?" or "implement a virtualized list from scratch."

## Windowing vs. virtualization

The terms are used almost interchangeably, but there's a useful distinction:

- **Windowing** is the general idea: only render the "window" of items currently visible (plus a buffer), and reuse/recycle DOM nodes as the window moves.
- **Virtualization** is the broader concept applied beyond lists — virtual scrolling for grids, virtualized tables with sticky columns, virtualized trees. Windowing is virtualization applied specifically to a scrollable list.

In practice, when someone says "virtualize this list," they mean: keep the number of rendered DOM nodes roughly constant no matter how many items are in the underlying data.

## The core idea, built from scratch

Before reaching for a library, understand the mechanism — this is what interviewers actually want to see.

```tsx
import { useState, useRef, useMemo, type CSSProperties } from "react";

interface VirtualListProps<T> {
  items: T[];
  itemHeight: number; // fixed row height in px
  containerHeight: number; // visible viewport height in px
  overscan?: number;
  renderItem: (item: T, index: number) => React.ReactNode;
}

function FixedHeightVirtualList<T>({
  items,
  itemHeight,
  containerHeight,
  overscan = 3,
  renderItem,
}: VirtualListProps<T>) {
  const [scrollTop, setScrollTop] = useState(0);
  const containerRef = useRef<HTMLDivElement>(null);

  const totalHeight = items.length * itemHeight;

  // Which rows are visible right now, based on scroll position
  const startIndex = Math.max(
    0,
    Math.floor(scrollTop / itemHeight) - overscan
  );
  const visibleCount = Math.ceil(containerHeight / itemHeight) + overscan * 2;
  const endIndex = Math.min(items.length - 1, startIndex + visibleCount);

  const visibleItems = useMemo(
    () => items.slice(startIndex, endIndex + 1),
    [items, startIndex, endIndex]
  );

  return (
    <div
      ref={containerRef}
      onScroll={(e) => setScrollTop(e.currentTarget.scrollTop)}
      style={{ height: containerHeight, overflowY: "auto", position: "relative" }}
    >
      {/* Spacer div gives the scrollbar the correct total height */}
      <div style={{ height: totalHeight, position: "relative" }}>
        {visibleItems.map((item, i) => {
          const index = startIndex + i;
          const style: CSSProperties = {
            position: "absolute",
            top: index * itemHeight,
            left: 0,
            right: 0,
            height: itemHeight,
          };
          return (
            <div key={index} style={style}>
              {renderItem(item, index)}
            </div>
          );
        })}
      </div>
    </div>
  );
}
```

The mechanism, in three parts:

1. **Outer scroll container** with a fixed height and `overflow: auto` — this is what actually scrolls.
2. **Inner spacer** sized to `items.length * itemHeight` so the scrollbar behaves as if all rows were rendered.
3. **Absolutely positioned rows**, only for the visible slice, positioned with `top: index * itemHeight` so they land in the correct spot inside the spacer.

This is exactly what `react-window`'s `FixedSizeList` does internally, minus edge-case handling.

## Using react-window

For production code, don't hand-roll this — use a maintained library. `react-window` is the lightweight, modern choice (successor to `react-virtualized`).

```bash
npm install react-window
```

```tsx
import { FixedSizeList } from "react-window";

interface Row {
  id: string;
  name: string;
}

function RowRenderer({ index, style, data }: {
  index: number;
  style: React.CSSProperties;
  data: Row[];
}) {
  const item = data[index];
  return (
    <div style={style} className="row">
      {item.name}
    </div>
  );
}

function BigList({ rows }: { rows: Row[] }) {
  return (
    <FixedSizeList
      height={600}
      width="100%"
      itemCount={rows.length}
      itemSize={48}
      itemData={rows}
      overscanCount={5}
    >
      {RowRenderer}
    </FixedSizeList>
  );
}
```

`react-window` gives you the `style` prop already computed (absolute position + height) — you just apply it to your row's outer element. Passing data via `itemData` (rather than closing over `rows` in the render function) avoids recreating the row renderer on every render, which matters because `react-window` uses `React.memo` internally on rows.

## Variable-height items

Fixed-height virtualization is the easy case. Real lists (chat messages, comment threads, feed items) have unpredictable heights, which breaks the "index × itemHeight" math.

Two approaches:

**1. Known-but-varying heights** — if you can compute height ahead of render (e.g., from data), use `VariableSizeList`:

```tsx
import { VariableSizeList } from "react-window";

function getItemSize(index: number) {
  return items[index].isLong ? 120 : 60;
}

<VariableSizeList
  height={600}
  width="100%"
  itemCount={items.length}
  itemSize={getItemSize}
>
  {RowRenderer}
</VariableSizeList>;
```

**2. Unknown heights until rendered** — the common real case: text wraps differently depending on content and container width. Here you need to measure after render and cache the result. `@tanstack/react-virtual` is built for exactly this, using `ResizeObserver` under the hood:

```bash
npm install @tanstack/react-virtual
```

```tsx
import { useRef } from "react";
import { useVirtualizer } from "@tanstack/react-virtual";

function DynamicList({ items }: { items: string[] }) {
  const parentRef = useRef<HTMLDivElement>(null);

  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 60, // initial guess before measurement
    overscan: 5,
  });

  return (
    <div ref={parentRef} style={{ height: 600, overflow: "auto" }}>
      <div style={{ height: virtualizer.getTotalSize(), position: "relative" }}>
        {virtualizer.getVirtualItems().map((virtualRow) => (
          <div
            key={virtualRow.key}
            data-index={virtualRow.index}
            ref={virtualizer.measureElement}
            style={{
              position: "absolute",
              top: 0,
              left: 0,
              width: "100%",
              transform: `translateY(${virtualRow.start}px)`,
            }}
          >
            {items[virtualRow.index]}
          </div>
        ))}
      </div>
    </div>
  );
}
```

The `estimateSize` is a starting guess; `measureElement` (via `ResizeObserver`) corrects it after the real DOM node renders, and the virtualizer recalculates offsets for items below it. This is the mechanism to describe when an interviewer asks "how do you virtualize a list where you don't know the row height in advance?"

## Overscan

Overscan is the number of extra items rendered outside the visible viewport, in the scroll direction. It exists to hide the "blank flash" that happens when a fast scroll outruns the render — without overscan, scrolling quickly reveals a frame of empty space before new rows paint.

Trade-off: overscan is a direct multiplier on DOM node count. `overscan={5}` on both edges means you're rendering `visibleCount + 10` nodes instead of `visibleCount`. Too low → visible flashing on fast scroll. Too high → you're back to rendering most of the list, defeating the point of virtualizing. Typical values are 3–10 depending on row complexity and expected scroll speed.

## Performance trade-offs

Virtualization isn't free — know the costs an interviewer expects you to name:

- **Broken native browser behaviors.** `Ctrl+F` / in-page find won't find text in unrendered rows. `Cmd+A` select-all-and-copy only copies what's mounted. Anchor-link scrolling to an item by ID doesn't work if that item isn't rendered yet.
- **SEO/accessibility cost.** Screen readers relying on the full DOM tree see only the rendered window; you often need `aria-setsize` / `aria-posinset` on rows to communicate true list position.
- **Complexity cost.** Variable-height virtualization with dynamic content, sticky headers, and grouped sections is genuinely hard to get right — bugs show up as jumpy scroll position or items rendering at the wrong offset.
- **When it's not worth it.** Lists under a few hundred items rarely need virtualization — the DOM can handle that fine, and the added complexity isn't justified. Profile first; virtualize when the row count is unbounded or in the thousands.

## Key takeaways

- Virtualization keeps rendered DOM node count roughly constant by rendering only the visible "window" plus overscan, using an absolutely-positioned spacer to preserve correct scrollbar size and item offsets.
- Fixed-height lists are simple math (`index × itemHeight`); variable-height lists need either precomputed sizes (`VariableSizeList`) or post-render measurement (`@tanstack/react-virtual` + `ResizeObserver`).
- `react-window` is the standard lightweight library; reach for `@tanstack/react-virtual` when row heights are unknown until content renders.
- Overscan trades DOM node count for scroll smoothness — too little flashes blank space, too much defeats the purpose.
- Virtualization breaks native find-in-page, select-all, and anchor scrolling — call this out unprompted, it's the kind of trade-off senior interviewers want to hear you volunteer.
- Don't virtualize lists that don't need it — a few hundred simple rows is fine unvirtualized; measure before adding the complexity.
