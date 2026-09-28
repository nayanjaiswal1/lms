---
kind: lesson
id_key: interview-prep-45/fe-css-box-model-layout
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "CSS Box Model, Flexbox and Grid"
position: 2
estimated_minutes: 25
source:
    - interview-prep-notes.md
---
Every element on a page is a rectangle, whether you asked for one or not. This lesson is about what is actually inside that rectangle, why `width: 200px` sometimes does not mean 200px, and the two layout systems, Flexbox and Grid, you will reach for constantly once you leave the browser's default document flow.

## The box model: four layers, from the inside out

Picture a framed photo on a wall. The photo itself is the content. The mat around it is padding. The frame is the border. The gap of wall between this frame and the next one is the margin. Content is what `width`/`height` size by default. Padding is breathing room inside the border, and it shares the element's background. Border wraps around the padding. Margin is transparent space outside the border, and it is the one layer that can collapse with a neighbor's margin instead of adding to it.

```css
.card {
  width: 200px;
  padding: 20px;
  border: 5px solid black;
}
/* Rendered width = 200 + 40 (padding, both sides) + 10 (border, both sides) = 250px */
```

That 250px is the trap. You asked for 200px and got 250px, because by default (`box-sizing: content-box`), `width` only ever describes the content box. Padding and border get added on top of it, they are never absorbed into it.

```css
.card {
  box-sizing: border-box;
  width: 200px;
  padding: 20px;
  border: 5px solid black;
}
/* Rendered width stays 200px — the content area shrinks to 150px to make room */
```

`border-box` flips what `width` means: now it is the *final* size, and the browser works backward, shrinking the content area to make room for padding and border inside it. That is why almost every production stylesheet opens with:

```css
*, *::before, *::after {
  box-sizing: border-box;
}
```

Set that once, globally, and a declared width is always the actual rendered width everywhere. That is one less thing to calculate by hand when you are building anything with percentage widths or a grid.

Two facts worth having ready cold, since they come up as quick follow-ups: margins on adjacent block elements collapse into whichever one is bigger, instead of stacking. A 20px `margin-bottom` next to a 30px `margin-top` produces a 30px gap, not 50px. And only `margin` accepts negative values; `padding` and `border-width` never do.

> **Remember:** `border-box` makes `width` mean the final rendered size. Without it, padding and border always add on top of what you asked for.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-css-boxmodel-q1", "type": "mcq",
      "prompt": "A `.card` has `width: 200px`, `padding: 10px`, and `border: 2px solid black`, with the default `box-sizing`. What is its actual rendered width?",
      "options": [
        {"id":"a","text":"200px"},
        {"id":"b","text":"224px — padding and border are added on top of the content width"},
        {"id":"c","text":"180px"},
        {"id":"d","text":"It depends on the browser"}
      ],
      "correct": "b",
      "explanation": "By default, box-sizing is content-box: width sets only the content area. Add 10px padding on both sides (20px) and 2px border on both sides (4px), and 200 + 20 + 4 = 224px." }
] }
```

## Block, inline, and the display value that sits between them

Every element has a default `display` value, and it answers two questions: does it start a new line, and does it respect `width`/`height` at all.

| | Block | Inline | Inline-block |
|---|---|---|---|
| Starts a new line | Yes | No | No |
| Respects width/height | Yes | No, sized by content | Yes |
| Vertical margin/padding | Respected | Ignored visually | Respected |
| Examples | `div`, `p`, `h1`–`h6`, `ul`/`li` | `span`, `a`, `strong`, `em` | `img`, `button`, `input` |

`inline-block` solves one specific problem: you want something to sit inside a line of text, the way `inline` does, but you also need to give it a fixed width or vertical padding, which plain `inline` refuses to honor. Style a `<span>` with `display: inline-block` and `width: 100px` now actually applies, while the span still flows next to text instead of forcing a line break.

> **Remember:** `inline-block` is the one display value that both sits inline with text and respects a fixed width.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-css-display-q1", "type": "mcq",
      "prompt": "You set `width: 100px` on a `<span>`, but it has no visible effect. Why?",
      "options": [
        {"id":"a","text":"span elements can never be resized"},
        {"id":"b","text":"span defaults to display: inline, and inline elements ignore width/height, sizing to their content instead"},
        {"id":"c","text":"The CSS file wasn't loaded"},
        {"id":"d","text":"width only works on elements with a border"}
      ],
      "correct": "b",
      "explanation": "Inline elements size to their content and ignore width/height. Switching to display: inline-block (or block) makes width take effect." }
] }
```

## Flexbox: one axis

Picture arranging books along a single shelf: they sit in one row, and you can spread them out or squeeze them together, but there is only one direction to think about. Flexbox lays out children along a single line, a row or a column, and lets them grow or shrink to fill the space along it.

```css
.navbar {
  display: flex;
  justify-content: space-between; /* main axis: spreads children apart */
  align-items: center;             /* cross axis: centers them vertically */
}
```

`justify-content` controls spacing along the direction items flow, the main axis. `align-items` controls alignment perpendicular to that, the cross axis. Reach for Flexbox anywhere the layout problem is genuinely one-dimensional: a nav bar, a toolbar, a row of buttons, centering one thing inside another.

## Grid: two axes at once

Grid is for when you have rows and columns to think about at the same time, an actual 2D structure, not one line of items.

```css
.dashboard {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  grid-template-rows: auto 1fr;
  gap: 16px;
}
```

That single declaration builds the structure before a single child exists: three equal-width columns, a first row sized to its own content (typically a header, `auto`), a second row that takes up whatever space is left (`1fr`), all separated by a 16px gap. Drop any element into `.dashboard` and it lands in the next open cell automatically, no per-item positioning needed unless you want to override where something sits.

The rule of thumb that settles "Flex or Grid" fast: if you are fighting `flex-wrap` and a pile of fixed widths trying to fake rows and columns, that is Grid's job, not Flexbox's. One axis, Flexbox. Two axes, Grid.

> **Remember:** one direction to arrange things in, Flexbox. Rows and columns at once, Grid.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-css-flexgrid-q1", "type": "mcq",
      "prompt": "You need a photo gallery laid out in a fixed number of rows and columns, where items can be placed in specific cells. What is the better fit?",
      "options": [
        {"id":"a","text":"Flexbox with flex-wrap, since it can also wrap onto multiple lines"},
        {"id":"b","text":"Grid, since it natively handles rows and columns as one structure"},
        {"id":"c","text":"Neither, this needs absolute positioning"},
        {"id":"d","text":"Flexbox, because it's newer"}
      ],
      "correct": "b",
      "explanation": "Flexbox wrapping fakes a 2D layout by wrapping a 1D line; it doesn't know about rows and columns as a real structure. Grid was built specifically for two-axis layout and cell placement." }
] }
```

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

`srcset` lists the same image at several resolutions. `sizes` tells the browser how wide the image will actually render at different screen widths. The browser combines those two facts with the device's own pixel density and picks whichever candidate wastes the least bandwidth, entirely on its own, no JavaScript involved. `loading="lazy"` is the other half of the win: it puts off loading offscreen images until they are about to enter the viewport, so a long product listing does not pay the download cost for images nobody ever scrolls to.

`<picture>` solves a different problem: swapping to a genuinely different crop of the same photo at different screen sizes, not just a smaller version of the same crop. Reach for `srcset` when it is the same image at different sizes. Reach for `<picture>` when the phone version needs a tighter crop than the desktop one.

> **Remember:** `srcset` picks a size; `<picture>` picks a crop. They solve different problems.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-css-images-q1", "type": "mcq",
      "prompt": "What actually decides which image in a `srcset` list the browser downloads?",
      "options": [
        {"id":"a","text":"The order the images are listed in"},
        {"id":"b","text":"The browser, weighing the `sizes` hint for rendered width against the device's pixel density, to waste the least bandwidth"},
        {"id":"c","text":"A JavaScript function you must write yourself"},
        {"id":"d","text":"Whichever image loads fastest from the server"}
      ],
      "correct": "b",
      "explanation": "srcset plus sizes hands the browser the facts it needs (candidate widths and expected render width); it makes the final call using the device's own pixel density, with no JavaScript involved." }
] }
```
