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
| Width/height | Respected, defaults to full width | Ignored — sized by content | Respected |
| Starts new line | Yes | No | No |
| Vertical margin/padding | Respected | Ignored (only affects line-height visually) | Respected |
| Examples | `div`, `p`, `section`, `h1-h6`, `ul`/`li` | `span`, `a`, `strong`, `em`, `label` | `img`, `button`, `input` |

Interview framing: inline-block is the "I want it to sit on the same line as text, but I still need to set width/height/margin on it" escape hatch — that's the entire reason it exists.

## Flex vs Grid

- **Flex** — one-dimensional (a single row *or* a single column). Sizing is content-driven: items grow/shrink to fill the available space along that one axis. Best for: nav bars, toolbars, button groups, anything where alignment along one axis is the whole problem.
- **Grid** — two-dimensional (rows *and* columns at once). Sizing is layout-driven: you define the structure first (`grid-template-columns`/`rows`), then place items into it. Best for: page layouts, dashboards, card grids — anything with an actual 2D structure.

Rule of thumb worth saying out loud in an interview: if you find yourself fighting `flex-wrap` plus fixed widths to fake rows and columns, that's the signal you actually wanted Grid.

```css
/* Flex — one axis */
.navbar { display: flex; justify-content: space-between; align-items: center; }

/* Grid — two axes */
.dashboard {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  grid-template-rows: auto 1fr;
  gap: 16px;
}
```

## Key takeaways

- Inline-block exists to let an element flow inline with text while still accepting width/height/margin — block and inline can't do both.
- Flex = one dimension, content-sized. Grid = two dimensions, layout-defined upfront.
- Reach for Grid the moment you need row *and* column alignment simultaneously — Flex will fight you past that point.
