---
kind: lesson
id_key: interview-prep-45/day-10-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Virtualization"
position: 24
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---
Render a 10,000-row table the naive way and you've created 10,000 DOM nodes, most of which the user never sees. Virtualization keeps the DOM small regardless of how much data there is, and it's a near-guaranteed question for anyone claiming React performance experience, either "how would you render a huge list?" or "implement a virtualized list from scratch."

## Windowing versus virtualization

The two terms get used almost interchangeably, but there's a useful distinction. Windowing is the general idea: only render the "window" of items currently visible plus a small buffer, and reuse or recycle DOM nodes as that window moves. Virtualization is the broader concept applied beyond simple lists, virtual scrolling for grids, tables with sticky columns, trees, windowing is virtualization applied specifically to a scrollable list. In practice, when someone says "virtualize this list," they mean keep the rendered DOM node count roughly constant no matter how many items the underlying data actually has.

## The mechanism, built by hand first

Before reaching for a library, understand what it's actually doing, which is what an interviewer wants to see regardless of whether you end up writing the library version or the hand-rolled one.

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

Three parts make this work. An outer scroll container with a fixed height and `overflow: auto`, this is what actually scrolls. An inner spacer sized to `items.length * itemHeight`, so the scrollbar behaves exactly as if every row were rendered even though almost none of them are. And absolutely positioned rows, only for the currently visible slice, positioned with `top: index * itemHeight` so each lands exactly where it would have if the whole list were real. This is, minus edge-case handling, exactly what `react-window`'s `FixedSizeList` does internally.

## Using react-window for production code

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

`react-window` hands you the `style` prop already computed, absolute position plus height, you just apply it to your row's outer element. Passing data via `itemData` rather than closing over `rows` matters because `react-window` wraps rows in `React.memo` internally, and a closure would recreate the row renderer's identity on every render, the exact `React.memo`-defeating mistake from the performance lesson earlier in this course.

## Variable-height items, the harder real case

Fixed-height virtualization is the easy version. Real lists, chat messages, comment threads, feed items, have unpredictable heights, which breaks the simple `index × itemHeight` math entirely.

If height is knowable ahead of render, from the data itself, `VariableSizeList` handles it:

```tsx
import { VariableSizeList } from "react-window";
function getItemSize(index: number) { return items[index].isLong ? 120 : 60; }
```

If height is only knowable after render, the common real case, text wraps differently depending on content and container width, `@tanstack/react-virtual` is built for exactly this, using `ResizeObserver` under the hood:

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

`estimateSize` is a starting guess; `measureElement` corrects it once the real DOM node renders, via `ResizeObserver`, and the virtualizer recalculates offsets for everything below it. This is the exact mechanism to describe when an interviewer asks how you'd virtualize a list where the row height genuinely isn't known in advance.

## Overscan: trading nodes for smoothness

Overscan is the number of extra items rendered outside the visible viewport, in the scroll direction, and it exists to hide the "blank flash" from a fast scroll outrunning the render, without it, a quick scroll reveals a frame of empty space before new rows paint. It's a direct multiplier on DOM node count: `overscan={5}` on both edges means rendering `visibleCount + 10` nodes instead of `visibleCount`. Too low flashes on fast scroll; too high defeats the point of virtualizing at all. Typical values run 3-10, depending on row complexity and expected scroll speed.

## What it costs, and when it isn't worth paying

Virtualization breaks a handful of native browser behaviors: `Ctrl+F`/in-page find won't find text in unrendered rows, `Cmd+A` select-all-and-copy only copies what's currently mounted, and anchor-link scrolling to an item by ID silently fails if that item isn't rendered yet. There's an accessibility cost too, a screen reader relying on the full DOM tree only sees the rendered window, which often means `aria-setsize`/`aria-posinset` on rows to communicate a row's true position in the full list. And there's a genuine complexity cost, variable-height virtualization with dynamic content, sticky headers, and grouped sections is hard to get exactly right; bugs show up as jumpy scroll position or rows painting at the wrong offset. Lists under a few hundred items rarely need any of this, the DOM handles that fine on its own, profile first, and virtualize once the row count is genuinely unbounded or in the thousands.

## Combining it with a live-updating list

A frequently polled or real-time list adds a second problem on top of raw row count: naively replacing the entire items array on every poll re-renders the whole visible window even when only one or two rows actually changed underneath it. Two things fix this together. Diff and patch just the changed rows, rather than swapping the array reference wholesale, so `react-window` doesn't have to re-measure everything on every tick. And avoid duplicate in-flight requests for the same data in the first place, a query library's cache, keyed by something like TanStack Query's `queryKey`, already deduplicates identical requests fired from multiple components, which matters more than it sounds like the moment several parts of a dashboard poll overlapping data independently.
