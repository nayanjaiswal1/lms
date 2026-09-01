---
kind: lesson
id_key: interview-prep-45/note-css-flex-grid-inline-block
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: Block/Inline/Inline-Block & Flex vs Grid"
position: 99
estimated_minutes: 15
source:
    - interview-prep-notes.md
---
## Block vs inline vs inline-block

| | Block | Inline | Inline-block |
|---|---|---|---|
| Width/height | Respected, defaults to full width | Ignored. Sized by content | Respected |
| Starts new line | Yes | No | No |
| Vertical margin/padding | Respected | Ignored (only affects line-height visually) | Respected |
| Examples | `div`, `p`, `section`, `h1-h6`, `ul`/`li` | `span`, `a`, `strong`, `em`, `label` | `img`, `button`, `input` |

Interview framing: inline-block is the escape hatch for when you want an element to sit on the same line as surrounding text but still need to set its width, height, or margin. That's the entire reason it exists, since block can't sit inline and inline can't take width/height.

## Flex vs Grid

- **Flex** is one-dimensional: a single row or a single column. Sizing is content-driven, so items grow or shrink to fill the available space along that one axis. Reach for it for nav bars, toolbars, button groups, or anything where alignment along one axis is the whole problem.
- **Grid** is two-dimensional: rows and columns at once. Sizing is layout-driven, so you define the structure first with `grid-template-columns`/`rows`, then place items into it. Reach for it for page layouts, dashboards, card grids, or anything with an actual 2D structure.

Rule of thumb worth saying out loud in an interview: if you find yourself fighting `flex-wrap` plus fixed widths to fake rows and columns, that's the signal you actually wanted Grid.

```css
/* Flex: one axis */
.navbar { display: flex; justify-content: space-between; align-items: center; }

/* Grid: two axes */
.dashboard {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  grid-template-rows: auto 1fr;
  gap: 16px;
}
```

The `.dashboard` rule lays out a 3-column, 2-row grid before a single child is placed: three equal-width tracks, a first row sized to its content (`auto`, typically a header) and a second row that takes the remaining space (`1fr`), all separated by a 16px gutter. Drop any element into `.dashboard` and it lands in the next open cell of that grid automatically, no per-item positioning needed unless you want to override placement.
