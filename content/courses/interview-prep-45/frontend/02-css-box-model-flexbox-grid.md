---
kind: lesson
id_key: interview-prep-45/fe-css-box-model-layout
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "CSS Box Model, Flexbox and Grid"
position: 2
estimated_minutes: 25
source:
    - interview-prep-notes.md
---
Every element on a page is a rectangle, whether you asked for one or not. This lesson is about what's actually inside that rectangle, why `width: 200px` sometimes doesn't mean 200px, and the two layout systems, Flexbox and Grid, you'll reach for constantly once you leave the default document flow.

## The box model: four layers, from the inside out

Content, then padding, then border, then margin. Content is what `width`/`height` size by default. Padding is breathing room inside the border, and it shares the element's background. Border wraps around the padding. Margin is transparent space outside the border, and it's the one layer that can collapse with a neighbor's margin instead of adding to it.

```css
.card {
  width: 200px;
  padding: 20px;
  border: 5px solid black;
}
/* Rendered width = 200 + 40 (padding, both sides) + 10 (border, both sides) = 250px */
```

That 250px is the trap. You asked for 200px and got 250px, because by default (`box-sizing: content-box`), `width` only ever describes the content box. Padding and border get added on top of it, not absorbed into it.

```css
.card {
  box-sizing: border-box;
  width: 200px;
  padding: 20px;
  border: 5px solid black;
}
/* Rendered width stays 200px — the content area shrinks to 150px to make room */
```

`border-box` flips the meaning of `width`: now it's the *final* size, and the browser works backward, shrinking the content area to fit padding and border inside it. This is why almost every production codebase opens its stylesheet with:

```css
*, *::before, *::after {
  box-sizing: border-box;
}
```

Once that's set globally, a declared width is always the actual rendered width, everywhere, which is one less thing to do math on when you're building anything with percentage widths or a grid.

Two things worth being able to say cold, since they come up as quick follow-ups: margins on adjacent block elements collapse into whichever one is bigger rather than stacking (a 20px margin-bottom next to a 30px margin-top produces 30px of gap, not 50px), and only `margin` accepts negative values, never `padding` or `border-width`.

## Block, inline, and the display value that sits between them

Every element has a default `display` that determines two things: does it start a new line, and does it respect `width`/`height` at all.

| | Block | Inline | Inline-block |
|---|---|---|---|
| Starts a new line | Yes | No | No |
| Respects width/height | Yes | No, sized by content | Yes |
| Vertical margin/padding | Respected | Ignored visually | Respected |
| Examples | `div`, `p`, `h1`–`h6`, `ul`/`li` | `span`, `a`, `strong`, `em` | `img`, `button`, `input` |

`inline-block` exists to solve one specific problem: you want something to sit in the middle of a line of text, the way `inline` does, but you also need to give it a fixed width or vertical padding, which plain `inline` refuses to honor. A `<span>` you've styled with `display: inline-block` can now take `width: 100px` and have it actually apply, while still flowing next to text instead of forcing a line break.

## Flexbox: one axis

Flexbox lays out children along a single line, a row or a column, and lets them grow or shrink to fill the space along that line.

```css
.navbar {
  display: flex;
  justify-content: space-between; /* main axis: spreads children apart */
  align-items: center;             /* cross axis: centers them vertically */
}
```

`justify-content` controls spacing along the direction items flow (the main axis); `align-items` controls alignment perpendicular to that (the cross axis). Reach for Flexbox anywhere the layout problem is genuinely one-dimensional: a nav bar, a toolbar, a row of buttons, centering one thing inside another.

## Grid: two axes at once

Grid is the tool for when you have both rows and columns to think about simultaneously, not one line of items but an actual 2D structure.

```css
.dashboard {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  grid-template-rows: auto 1fr;
  gap: 16px;
}
```

That declaration builds the structure before a single child exists: three equal-width columns, a first row sized to its own content (typically a header, `auto`), a second row that consumes whatever space is left (`1fr`), all separated by a 16px gutter. Drop any element into `.dashboard` and it lands in the next open cell automatically, no per-item positioning required unless you want to override where something sits.

The rule of thumb that settles the "Flex or Grid" question fast: if you catch yourself fighting `flex-wrap` and a pile of fixed widths trying to fake rows and columns, that's Grid's job, not Flexbox's. One axis, Flexbox. Two axes, Grid.

## Responsive images: letting the browser choose

Sizing a layout is only half of "responsive." The other half is not shipping a 2000px photo to a 400px phone screen.

```html
<img
  src="/photo-800.jpg"
  srcset="/photo-400.jpg 400w, /photo-800.jpg 800w, /photo-1200.jpg 1200w"
  sizes="(max-width: 600px) 400px, 800px"
  alt="Product photo"
  loading="lazy"
/>
```

`srcset` lists the same image at several resolutions; `sizes` tells the browser how wide the image will actually be rendered at different viewport widths. The browser combines those two facts with the device's own pixel density and picks whichever candidate wastes the least bandwidth, entirely on its own, no JavaScript involved. `loading="lazy"` is the other half of the win: it defers offscreen images until they're about to enter the viewport, so a long product listing doesn't pay the download cost for images the user never scrolls to.

`<picture>` solves a different problem, art direction rather than resolution: swapping to a genuinely different crop of the same photo at different breakpoints, not just a smaller version of the same crop. Reach for `srcset` when it's the same image at different sizes; reach for `<picture>` when the mobile version needs a tighter crop than the desktop one.
