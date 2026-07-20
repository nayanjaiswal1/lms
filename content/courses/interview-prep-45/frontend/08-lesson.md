---
kind: lesson
id_key: interview-prep-45/day-08-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Day 8 — Network Performance"
position: 11
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
"How would you find out why this page is slow to load?" is a diagnostic question, and the answer starts with reading a network waterfall, not guessing. Today is about measuring — the Performance API, waterfall charts, and the resource hints (`preload`/`prefetch`) and image techniques that turn a diagnosis into a fix. Day 9 builds on this with the bundling side (code splitting).

## Network waterfall visualization

The waterfall (DevTools Network tab, or Lighthouse/WebPageTest) shows every resource request as a horizontal bar over time, and each bar breaks into phases:

```
Queued → Stalled → DNS Lookup → Initial Connection → SSL → Request Sent → Waiting (TTFB) → Content Download
```

What to look for, in priority order:

- **Long "Stalled" bars on many requests at once** — the browser caps parallel connections per origin (historically 6 for HTTP/1.1); requests queue behind each other. HTTP/2 multiplexing (multiple requests over one connection) fixes this — check the `Protocol` column.
- **A long TTFB (Time to First Byte) on the document request** — server-side problem (slow backend, cold start, no caching), not a frontend problem. Nothing renders until this returns.
- **A "waterfall staircase"** — request B doesn't start until request A finishes, when they could have started in parallel. Usually caused by a synchronous chain: HTML → discover CSS → discover font referenced in CSS → discover JS that fetches data. Each hop costs a full round trip.
- **Render-blocking resources at the top** — `<script>` tags without `defer`/`async` in `<head>`, and `<link rel="stylesheet">`, both block the parser/first paint until downloaded and (for scripts) executed.

## Measure request performance with the Performance API

The `Performance` API gives you programmatic, precise timing — the same data the waterfall visualizes, but queryable in code (and shippable to real-user-monitoring/analytics):

```tsx
// Navigation timing: how the initial document load broke down
const [nav] = performance.getEntriesByType('navigation') as PerformanceNavigationTiming[];
console.log('TTFB:', nav.responseStart - nav.requestStart);
console.log('DOM interactive:', nav.domInteractive - nav.startTime);
console.log('DOM content loaded:', nav.domContentLoadedEventEnd - nav.startTime);
console.log('Full load:', nav.loadEventEnd - nav.startTime);

// Resource timing: every fetch/script/image/stylesheet the page loaded
const resources = performance.getEntriesByType('resource') as PerformanceResourceTiming[];
const slowest = resources
  .sort((a, b) => b.duration - a.duration)
  .slice(0, 5);
slowest.forEach(r => console.log(r.name, `${r.duration.toFixed(0)}ms`, r.initiatorType));

// Custom app-level measurements — mark two points, measure the gap
performance.mark('data-fetch-start');
await fetchProducts();
performance.mark('data-fetch-end');
performance.measure('data-fetch', 'data-fetch-start', 'data-fetch-end');
const [measurement] = performance.getEntriesByName('data-fetch');
console.log(`Fetching products took ${measurement.duration.toFixed(0)}ms`);
```

```tsx
// Core Web Vitals via PerformanceObserver — how real user monitoring is built
new PerformanceObserver((list) => {
  for (const entry of list.getEntries()) {
    console.log('LCP:', entry.startTime); // Largest Contentful Paint
  }
}).observe({ type: 'largest-contentful-paint', buffered: true });

new PerformanceObserver((list) => {
  for (const entry of list.getEntries() as any[]) {
    console.log('CLS shift:', entry.value); // Cumulative Layout Shift
  }
}).observe({ type: 'layout-shift', buffered: true });
```

**Interview question: "What are the Core Web Vitals and why do they matter?"** LCP (Largest Contentful Paint — perceived load speed), INP (Interaction to Next Paint, replaced FID in 2024 — responsiveness), and CLS (Cumulative Layout Shift — visual stability). They matter because Google uses them as a search ranking signal and because they're the closest proxy metrics have to actual user-perceived quality.

## Preload vs prefetch

Both are `<link rel="...">` resource hints that tell the browser about a resource before it would normally discover it — but they signal different priority and timing:

```html
<!-- preload: fetch NOW, high priority — for a resource THIS page needs soon
     (e.g., a font referenced only inside CSS, which the browser can't discover
     until it parses the CSS, by which point it's already late) -->
<link rel="preload" href="/fonts/inter.woff2" as="font" type="font/woff2" crossorigin>

<!-- prefetch: fetch when idle, low priority — for a resource the NEXT page
     will likely need (e.g., the JS chunk for a route the user is likely to visit) -->
<link rel="prefetch" href="/dashboard-chunk.js" as="script">
```

`preload` competes with the current page's critical resources for bandwidth — overusing it (preloading everything) can slow down the actual critical path, which is a common mistake candidates make when asked to "optimize" a page. `prefetch` is opportunistic and low-priority by design, so it's safe to be more liberal with it, but it's still wasted bandwidth if the guess about "next page" is wrong.

## Image optimization techniques

Images are usually the largest payload on a page, so this is high-leverage:

```html
<!-- Responsive images: let the browser pick the right size for the viewport/DPR -->
<img
  src="/photo-800.jpg"
  srcset="/photo-400.jpg 400w, /photo-800.jpg 800w, /photo-1200.jpg 1200w"
  sizes="(max-width: 600px) 400px, 800px"
  alt="Product photo"
  loading="lazy"
  decoding="async"
  width="800" height="600"
/>

<!-- Modern formats with fallback -->
<picture>
  <source srcset="/photo.avif" type="image/avif" />
  <source srcset="/photo.webp" type="image/webp" />
  <img src="/photo.jpg" alt="Product photo" />
</picture>
```

Key levers: `loading="lazy"` defers offscreen images until they near the viewport (native, no JS needed); always set explicit `width`/`height` (or `aspect-ratio` in CSS) so the browser reserves the right space before the image loads, preventing layout shift (CLS); AVIF/WebP are 25-50% smaller than JPEG/PNG at equivalent visual quality; `srcset`/`sizes` avoid shipping a 2000px image to a 400px mobile viewport.

## Key takeaways

- Read the waterfall for stalled/queued requests (connection limits or HTTP/1.1), staircase patterns (unnecessary sequential dependency chains), and render-blocking resources at the top.
- The `Performance` API (`getEntriesByType('navigation'/'resource')`, `mark`/`measure`, `PerformanceObserver`) gives programmatic timing for both diagnosis and real-user-monitoring.
- Core Web Vitals — LCP (load speed), INP (responsiveness), CLS (visual stability) — are the standard proxy metrics for perceived performance and a search ranking factor.
- `preload` = fetch now, high priority, for this page's late-discovered critical resources; `prefetch` = fetch when idle, low priority, for the next page's likely resources — don't over-preload, it competes with the current critical path.
- `loading="lazy"`, explicit `width`/`height`, and modern formats (AVIF/WebP via `<picture>`) are the highest-leverage image optimizations.

## Today's checklist

- [ ] Read and interpret a network waterfall visualization
- [ ] Measure request performance with the Performance API (navigation, resource, custom marks)
- [ ] Run a bundle size analysis
- [ ] Be able to explain: preload vs prefetch
- [ ] Be able to explain: image optimization techniques
- [ ] Be able to explain: code splitting strategies (previewed here, deep dive Day 9)
