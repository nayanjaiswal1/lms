---
kind: lesson
id_key: interview-prep-45/day-11-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "CSS and Rendering Performance"
position: 4
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
JavaScript gets most of the blame for a janky page, but a large share of real-world jank traces back to CSS and what the browser has to do in response to it. This lesson is about what actually happens between a style change and pixels landing on screen, and the small set of properties and APIs that let you control that deliberately.

## Four stages, and which ones a given change skips

Every frame the browser paints goes through some or all of: **Style** (which CSS rules apply to which elements), **Layout** (the size and position of every affected element, also called reflow), **Paint** (filling in pixels: text, colors, shadows), and **Composite** (combining painted layers into the final image, on the GPU).

| Change | Layout | Paint | Composite |
|---|---|---|---|
| `width`, `height`, `top`, `left`, `margin` | yes | yes | yes |
| `color`, `background`, `box-shadow` | no | yes | yes |
| `transform`, `opacity` | no | no | yes |

The expensive path is the top row: a layout-affecting property forces the browser to redo geometry for that element, potentially its ancestors and siblings too, then repaint, then recomposite. `transform` and `opacity` are the outlier, they can be handled entirely on the GPU's compositor thread, skipping Layout and Paint completely. That's not a minor optimization footnote; it's the entire reason those two properties are the default choice for animation, covered in more depth later in this course.

```css
/* Forces reflow every frame */
.card { transition: top 0.3s, left 0.3s; }
.card.moved { top: 100px; left: 50px; }

/* Same visual result, compositor-only */
.card { transition: transform 0.3s; }
.card.moved { transform: translate(50px, 100px); }
```

## will-change is a promise, and promises aren't free

`will-change` tells the browser to promote an element onto its own compositor layer *before* the change happens, so the layer doesn't have to be created mid-animation.

```css
.card { will-change: transform; }
```

The trap is treating it as a blanket performance boost instead of a targeted one. Every promoted layer consumes GPU memory, and leaving `will-change` on permanently, rather than toggling it on right before an animation and off right after, can fragment the page into so many layers that it makes things slower, not faster.

```ts
element.style.willChange = "transform";
element.addEventListener("transitionend", () => {
  element.style.willChange = "auto";
}, { once: true });
```

## Layout thrashing: reading and writing in the wrong order

This happens when JavaScript interleaves reads and writes of layout-dependent properties inside a loop, forcing the browser to synchronously recompute layout on every single iteration instead of batching the whole thing into one recalculation per frame.

```ts
// Bad: read, write, read, write — forces a synchronous layout flush every time
boxes.forEach((box) => {
  const width = box.offsetWidth; // read
  box.style.width = `${width * 2}px`; // write invalidates the layout cache
});

// Good: batch all reads first, then all writes
const widths = boxes.map((box) => box.offsetWidth);
boxes.forEach((box, i) => { box.style.width = `${widths[i] * 2}px`; });
```

`offsetWidth`, `offsetHeight`, `getBoundingClientRect()`, `scrollTop`, and `getComputedStyle()` are the usual culprits on the read side, since each one forces the browser to guarantee an up-to-date layout before it can answer. Open Chrome DevTools' Performance tab, record the interaction, and look for a tight, repeated sequence of purple "Layout" blocks, or check the summary for a "Forced reflow" warning, DevTools flags this pattern explicitly.

## contain and content-visibility: telling the browser what it can skip

`contain` declares that an element's internals are isolated from the rest of the page, so a change inside it can't ripple outward, and the browser doesn't need to recheck anything outside its boundary.

```css
.list-item { contain: content; }   /* layout + paint + style */
.chart-widget { contain: strict; } /* content + a fixed size, the strongest guarantee */
```

For a dashboard built from many independent widgets, wrapping each in `contain: content` means updating one widget's DOM never forces the browser to re-check layout for its siblings.

`content-visibility: auto` builds on the same idea for anything currently off-screen:

```css
.long-article section {
  content-visibility: auto;
  contain-intrinsic-size: 0 500px; /* a placeholder size, used before first real render */
}
```

Sections outside the viewport skip rendering work entirely until they scroll into view, no JavaScript required. It's the same underlying goal as list virtualization, do the least work possible for content the user can't currently see, just handled natively by the browser instead of hand-rolled.

## Getting out of the way of first paint

By default, `<link rel="stylesheet">` blocks rendering: nothing paints until every linked stylesheet has downloaded and parsed, even if the HTML itself was ready instantly.

**Critical CSS** inlines just enough CSS for the above-the-fold view directly in `<head>`, and defers the rest:

```html
<head>
  <style>
    .header { ... }
    .hero { ... }
  </style>
  <link rel="preload" href="/styles/main.css" as="style" onload="this.onload=null;this.rel='stylesheet'" />
  <noscript><link rel="stylesheet" href="/styles/main.css" /></noscript>
</head>
```

Tools like `critical` or `critters` automate extracting that above-the-fold slice at build time; Next.js does the equivalent automatically for CSS Modules in production. Two other render-blocking culprits worth naming in the same breath: a synchronous `<script>` in `<head>` blocks HTML parsing entirely until it downloads and runs, `defer` and `async` both fix that for non-critical scripts, and unstyled web fonts either flash invisible text or shift the layout when the real font swaps in, which `font-display: swap` mitigates by showing the fallback immediately.

```css
@font-face {
  font-family: "Inter";
  src: url("/fonts/inter.woff2") format("woff2");
  font-display: swap;
}
```

## The habit worth building

The pattern an interviewer is actually checking for, more than any individual fact above, is whether you connect a specific property to a specific pipeline stage to a specific fix. "This animates `top`, which forces layout on every frame, so switch it to `transform` and it becomes compositor-only" is the shape of a senior answer. Reciting the four stage names without wiring them to an actual property isn't.
