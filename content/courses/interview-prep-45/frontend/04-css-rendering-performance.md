---
kind: lesson
id_key: interview-prep-45/day-11-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "CSS and Rendering Performance"
position: 4
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
JavaScript takes most of the blame for a janky page, but a large share of real-world jank actually traces back to CSS and what the browser has to do in response to it. This lesson is about what happens between a style change and pixels landing on screen, and the small set of properties and APIs that let you control that on purpose.

## Four stages, and which ones a given change skips

Every frame the browser paints goes through some or all of four stages: **Style** (which CSS rules apply to which elements), **Layout** (the size and position of every affected element, also called reflow), **Paint** (filling in pixels: text, colors, shadows), and **Composite** (combining painted layers into the final image, on the GPU).

| Change | Layout | Paint | Composite |
|---|---|---|---|
| `width`, `height`, `top`, `left`, `margin` | yes | yes | yes |
| `color`, `background`, `box-shadow` | no | yes | yes |
| `transform`, `opacity` | no | no | yes |

The expensive path is the top row. A layout-affecting property forces the browser to redo geometry for that element, sometimes its ancestors and siblings too, then repaint, then recomposite. `transform` and `opacity` are the outlier: they can be handled entirely on the GPU's compositor thread, skipping Layout and Paint completely. That is not a small footnote. It is the whole reason those two properties are the default choice for animating anything on screen.

```css
/* Forces reflow every frame */
.card { transition: top 0.3s, left 0.3s; }
.card.moved { top: 100px; left: 50px; }

/* Same visual result, compositor-only */
.card { transition: transform 0.3s; }
.card.moved { transform: translate(50px, 100px); }
```

> **Remember:** `transform` and `opacity` are the only two properties that can skip layout and paint entirely and go straight to the GPU.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-css-perf-stages-q1", "type": "mcq",
      "prompt": "Animating `top` and `left` costs more than animating `transform: translate(...)` for the same visual movement. Why?",
      "options": [
        {"id":"a","text":"top/left are deprecated properties"},
        {"id":"b","text":"top/left force a layout recalculation on every frame, then paint, then composite; transform can be handled purely on the GPU's compositor thread, skipping layout and paint"},
        {"id":"c","text":"transform only works in Chrome"},
        {"id":"d","text":"There's no real difference, it's a common myth"}
      ],
      "correct": "b",
      "explanation": "top/left change an element's geometry, which forces the full layout-paint-composite pipeline every frame. transform and opacity can be applied entirely on the compositor, which is why they're the default choice for animation." }
] }
```

## will-change is a promise, and promises aren't free

`will-change` tells the browser to promote an element onto its own compositor layer *before* the change happens, so the layer does not have to be created mid-animation.

```css
.card { will-change: transform; }
```

The trap is treating this as a blanket performance boost instead of a targeted one. Every promoted layer eats GPU memory, and leaving `will-change` on permanently, instead of toggling it on right before an animation and off right after, can split the page into so many layers that it slows things down instead of speeding them up.

```ts
element.style.willChange = "transform";
element.addEventListener("transitionend", () => {
  element.style.willChange = "auto";
}, { once: true });
```

> **Remember:** `will-change` is a promise you make to the browser ahead of time, not a permanent setting. Turn it off once the animation ends.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-css-willchange-q1", "type": "mcq",
      "prompt": "A developer adds `will-change: transform` to every card in a 500-item list, permanently, to make scrolling feel smoother. What actually happens?",
      "options": [
        {"id":"a","text":"Scrolling gets faster with no downside"},
        {"id":"b","text":"The page splits into hundreds of GPU-backed layers, which can consume enough GPU memory to make things slower, not faster"},
        {"id":"c","text":"will-change only affects hover states, so nothing changes"},
        {"id":"d","text":"The browser ignores will-change on more than 10 elements"}
      ],
      "correct": "b",
      "explanation": "will-change is meant to be toggled on right before a change and off right after. Applying it permanently to hundreds of elements fragments the page into that many compositor layers, which costs real GPU memory." }
] }
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

`offsetWidth`, `offsetHeight`, `getBoundingClientRect()`, `scrollTop`, and `getComputedStyle()` are the usual culprits on the read side, since each one forces the browser to guarantee an up-to-date layout before it can answer. Open Chrome DevTools' Performance tab, record the interaction, and look for a tight, repeated sequence of purple "Layout" blocks, or check the summary for a "Forced reflow" warning, DevTools flags this pattern by name.

> **Remember:** batch every read before any write. Interleaving them forces one layout recalculation per loop iteration instead of one for the whole loop.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-css-thrashing-q1", "type": "mcq",
      "prompt": "A loop reads `box.offsetWidth`, then immediately writes `box.style.width`, for each of 100 boxes, in that interleaved order. What's the fix?",
      "options": [
        {"id":"a","text":"Use a for loop instead of forEach"},
        {"id":"b","text":"Batch all the reads into an array first, then do all the writes in a second pass"},
        {"id":"c","text":"Add a setTimeout between each iteration"},
        {"id":"d","text":"There's no fix, this is unavoidable"}
      ],
      "correct": "b",
      "explanation": "Interleaving forces a synchronous layout recalculation on every iteration, since each write invalidates the layout the very next read has to rebuild. Reading everything first, then writing everything, collapses that into one recalculation total." }
] }
```

## contain and content-visibility: telling the browser what it can skip

`contain` declares that an element's internals are isolated from the rest of the page, so a change inside it cannot ripple outward, and the browser does not need to recheck anything outside its boundary.

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

Sections outside the viewport skip rendering work entirely until they scroll into view, no JavaScript required. It is the same underlying goal as list virtualization: do the least work possible for content the user cannot currently see, just handled natively by the browser instead of hand-rolled.

> **Remember:** `contain` tells the browser "nothing in here affects anything out there," so it can stop checking.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-css-contain-q1", "type": "mcq",
      "prompt": "A dashboard has 20 independent widgets. Updating one widget's DOM currently forces the browser to re-check layout for all 20. What single CSS property fixes this?",
      "options": [
        {"id":"a","text":"display: grid on the dashboard container"},
        {"id":"b","text":"contain: content on each widget, isolating its internals from the rest of the page"},
        {"id":"c","text":"position: absolute on each widget"},
        {"id":"d","text":"overflow: hidden on the dashboard container"}
      ],
      "correct": "b",
      "explanation": "contain tells the browser a subtree's layout, paint, and style are isolated, so a change inside it can't affect anything outside its boundary, and the browser doesn't need to re-check the siblings." }
] }
```

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

Tools like `critical` or `critters` automate pulling out that above-the-fold slice at build time. Next.js does the equivalent automatically for CSS Modules in production. Two other render-blocking culprits worth naming in the same breath: a synchronous `<script>` in `<head>` blocks HTML parsing entirely until it downloads and runs (`defer` and `async` both fix that for non-critical scripts), and an unstyled web font either flashes invisible text or shifts the layout when the real font swaps in, which `font-display: swap` fixes by showing the fallback font immediately.

```css
@font-face {
  font-family: "Inter";
  src: url("/fonts/inter.woff2") format("woff2");
  font-display: swap;
}
```

> **Remember:** a stylesheet blocks rendering by default. Inline the above-the-fold CSS and defer the rest to get pixels on screen sooner.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-css-criticalcss-q1", "type": "mcq",
      "prompt": "Why does inlining the above-the-fold CSS directly in `<head>`, instead of a single linked stylesheet, speed up first paint?",
      "options": [
        {"id":"a","text":"Inline CSS is parsed faster by the browser's CSS engine"},
        {"id":"b","text":"A linked stylesheet blocks rendering until it fully downloads and parses; inlined critical CSS is available immediately, so the visible part of the page can paint without waiting for the rest"},
        {"id":"c","text":"Inline CSS doesn't need to be valid CSS"},
        {"id":"d","text":"It has no real effect, this is a myth"}
      ],
      "correct": "b",
      "explanation": "External stylesheets are render-blocking by default. Inlining just the CSS needed for the initial view removes that wait for the part of the page the user sees first; the rest loads in the background." }
] }
```

## The habit worth building

What an interviewer is actually checking for, more than any individual fact above, is whether you connect a specific property to a specific pipeline stage to a specific fix. "This animates `top`, which forces layout on every frame, so switch it to `transform` and it becomes compositor-only" is the shape of a senior answer. Reciting the four stage names without wiring them to an actual property is not.
