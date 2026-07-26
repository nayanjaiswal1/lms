---
kind: lesson
id_key: interview-prep-45/day-11-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "CSS and Rendering Performance"
position: 14
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---

JavaScript performance gets most of the interview attention, but a huge share of real jank comes from CSS and the browser's rendering pipeline. Today covers what actually happens between a style change and pixels on screen, and the handful of CSS properties and APIs that let you control it deliberately instead of accidentally.

## The rendering pipeline

Every frame the browser wants to paint goes through some or all of these stages:

1. **Style** — compute which CSS rules apply to each element (recalculate style).
2. **Layout (reflow)** — compute the geometry: position and size of every element affected by the change.
3. **Paint** — fill in pixels: text, colors, borders, shadows, images, for every layer.
4. **Composite** — combine painted layers into the final image, applying transforms/opacity on the GPU.

The expensive part is that a change to a layout-affecting property (`width`, `top`, `margin`, `display`) forces the browser to redo layout for that element and potentially its ancestors/siblings, then repaint, then recomposite. A change to a composite-only property (`transform`, `opacity`) can skip layout and paint entirely and go straight to the compositor thread — which is why those two properties are the backbone of performant animation.

| Change | Layout | Paint | Composite |
|---|---|---|---|
| `width`, `height`, `top`, `left`, `margin`, `font-size` | yes | yes | yes |
| `color`, `background`, `box-shadow`, `border-radius` | no | yes | yes |
| `transform`, `opacity` | no | no | yes |

## Composite-only properties and GPU acceleration

Because `transform` and `opacity` can be handled entirely on the compositor thread, they're the two properties you should default to for animation instead of animating `top`/`left`/`width`/`height`.

```css
/* Bad: animates layout-affecting properties, forces reflow every frame */
.card {
  transition: top 0.3s, left 0.3s;
}
.card.moved {
  top: 100px;
  left: 50px;
}

/* Good: same visual result, compositor-only */
.card {
  transition: transform 0.3s;
}
.card.moved {
  transform: translate(50px, 100px);
}
```

`will-change` is a hint to the browser to promote an element to its own compositor layer *before* the change happens, avoiding a layer-creation cost mid-animation:

```css
.card {
  will-change: transform;
}
```

Interview trap: `will-change` is not free. Every layer it creates consumes GPU memory, and overusing it (e.g., applying it globally, or leaving it on permanently instead of toggling it on right before an animation and removing it after) can make performance *worse* by fragmenting the page into too many layers. The correct pattern is to set it just before the animation starts and remove it once it ends:

```ts
element.style.willChange = "transform";
// ...run animation...
element.addEventListener("transitionend", () => {
  element.style.willChange = "auto";
}, { once: true });
```

## Layout thrashing

Layout thrashing (also called "forced synchronous layout") happens when JavaScript interleaves reads and writes of layout-dependent properties in a loop, forcing the browser to recompute layout synchronously on every read instead of batching it once per frame.

```ts
// Bad: read-write-read-write forces layout recalculation on every iteration
function resizeAllBoxes(boxes: HTMLElement[]) {
  boxes.forEach((box) => {
    const width = box.offsetWidth; // READ — forces layout flush
    box.style.width = `${width * 2}px`; // WRITE — invalidates layout
  });
  // Next iteration's offsetWidth read forces the browser to recompute
  // layout synchronously *right now* instead of waiting for the next frame,
  // because the previous write invalidated the cached layout.
}
```

```ts
// Good: batch all reads, then all writes
function resizeAllBoxes(boxes: HTMLElement[]) {
  const widths = boxes.map((box) => box.offsetWidth); // all reads first
  boxes.forEach((box, i) => {
    box.style.width = `${widths[i] * 2}px`; // all writes after
  });
}
```

This read/write batching pattern is sometimes called "FastDOM." Properties that trigger a forced synchronous layout on read include `offsetWidth`, `offsetHeight`, `getBoundingClientRect()`, `scrollTop`, and `getComputedStyle()`.

**Measuring layout thrashing:** open Chrome DevTools → Performance tab → record an interaction → look for purple "Layout" blocks that repeat many times in a tight sequence, and DevTools explicitly flags repeated forced layouts as "Forced reflow" warnings in the summary.

```ts
// You can also instrument manually with the Performance API
performance.mark("resize-start");
resizeAllBoxes(boxes);
performance.mark("resize-end");
performance.measure("resize", "resize-start", "resize-end");
console.log(performance.getEntriesByName("resize")[0].duration);
```

## CSS containment

`contain` tells the browser that an element's internals are isolated from the rest of the page, so a change inside it can't affect layout/paint outside its boundary — the browser can skip recalculating the rest of the tree.

```css
.list-item {
  contain: content; /* shorthand for layout + paint + style */
}

.chart-widget {
  contain: strict; /* layout + paint + style + size — strongest guarantee */
}
```

| Value | Meaning |
|---|---|
| `contain: layout` | Element's layout doesn't affect/depend on anything outside it |
| `contain: paint` | Descendants can't paint outside the element's bounds (like implicit `overflow: hidden` for painting) |
| `contain: size` | Element's size doesn't depend on its children — you must give it explicit dimensions |
| `contain: content` | `layout` + `paint` + `style` combined |
| `contain: strict` | `content` + `size` combined — the strongest isolation |

Practical use: a dashboard with many independent widgets — wrapping each widget in `contain: content` means updating one widget's DOM doesn't force the browser to re-check layout for sibling widgets.

`content-visibility: auto` builds on containment for off-screen content:

```css
.long-article section {
  content-visibility: auto;
  contain-intrinsic-size: 0 500px; /* placeholder size before first render */
}
```

This skips rendering work entirely for sections currently off-screen, only doing it when they scroll into view — a huge win for long pages with many sections, similar in spirit to virtualization but handled natively by the browser.

## Critical CSS and render-blocking resources

By default, `<link rel="stylesheet">` is render-blocking: the browser won't paint anything until all linked stylesheets are downloaded and parsed. On a slow connection this delays First Contentful Paint even if the HTML is ready.

**Critical CSS** is the technique of inlining the minimal CSS needed for above-the-fold content directly in `<head>`, and loading the rest asynchronously:

```html
<head>
  <style>
    /* Inlined: only the CSS needed for the initial viewport */
    .header { ... }
    .hero { ... }
  </style>

  <!-- Non-critical CSS loaded without blocking render -->
  <link
    rel="preload"
    href="/styles/main.css"
    as="style"
    onload="this.onload=null;this.rel='stylesheet'"
  />
  <noscript><link rel="stylesheet" href="/styles/main.css" /></noscript>
</head>
```

Tools like `critical` or `critters` automate extracting above-the-fold CSS at build time. Next.js does this automatically for CSS Modules and styled-jsx in production builds.

Other render-blocking resources to know:

- **Synchronous `<script>` tags in `<head>`** block HTML parsing entirely. Use `defer` (executes after parsing, in order) or `async` (executes as soon as loaded, out of order) for non-critical scripts.
- **Web fonts** cause either a flash of invisible text (`font-display: swap` avoids this) or layout shift when the fallback font swaps to the loaded font — mitigate with `size-adjust` or matching fallback metrics.

```css
@font-face {
  font-family: "Inter";
  src: url("/fonts/inter.woff2") format("woff2");
  font-display: swap; /* show fallback immediately, swap when loaded */
}
```

## Key takeaways

- The rendering pipeline is Style → Layout → Paint → Composite; layout-affecting properties are expensive, `transform`/`opacity` can skip straight to the compositor.
- Use `will-change` sparingly and temporarily — set it right before an animation, remove it after, never leave it on by default.
- Layout thrashing comes from interleaving DOM reads and writes in a loop; fix it by batching all reads before all writes.
- `contain` and `content-visibility: auto` let the browser skip layout/paint work for isolated or off-screen content without you writing any JavaScript.
- Critical CSS (inline above-the-fold styles, async-load the rest) reduces render-blocking delay on first paint; `defer`/`async` do the same for non-critical scripts.
- DevTools Performance tab is where you prove any of this — "Forced reflow" warnings and repeated purple Layout blocks are the evidence, not intuition.
