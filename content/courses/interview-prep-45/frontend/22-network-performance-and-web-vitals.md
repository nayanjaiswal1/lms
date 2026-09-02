---
kind: lesson
id_key: interview-prep-45/day-08-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Network Performance and Web Vitals"
position: 22
estimated_minutes: 35
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---
"How would you find out why this page is slow to load?" is a diagnostic question, and the answer starts with reading a network waterfall, not guessing. This lesson covers measuring: the waterfall itself, the Performance API, the exact Core Web Vitals thresholds, how production apps actually ship that data, and the resource hints and image techniques that turn a diagnosis into a fix. Bundle-side performance, code splitting, is next.

## Reading a waterfall

DevTools' Network tab, or Lighthouse, or WebPageTest, shows every request as a horizontal bar over time, broken into phases: `Queued → Stalled → DNS Lookup → Initial Connection → SSL → Request Sent → Waiting (TTFB) → Content Download`.

What to look for, in priority order. Long "Stalled" bars across many requests at once usually means the browser's per-origin connection cap is queuing requests behind each other, HTTP/2 multiplexing largely fixes this, check the `Protocol` column to confirm which is in play. A long TTFB (Time to First Byte) on the document request itself points at the server, a cold start, a slow backend, missing caching, not the frontend; nothing renders until this returns. A "waterfall staircase," where request B doesn't start until request A finishes even though they could have run in parallel, is usually a synchronous discovery chain: HTML discovers CSS, CSS references a font, JS then fetches data, each hop costing a full round trip. And render-blocking resources at the top of the waterfall, a `<script>` without `defer`/`async` in `<head>`, or a `<link rel="stylesheet">`, block the parser or first paint until they finish downloading and, for scripts, executing.

## Measuring precisely with the Performance API

The `Performance` API gives you the same data the waterfall visualizes, but queryable in code and shippable to real-user monitoring.

```tsx
const [nav] = performance.getEntriesByType('navigation') as PerformanceNavigationTiming[];
console.log('TTFB:', nav.responseStart - nav.requestStart);
console.log('Full load:', nav.loadEventEnd - nav.startTime);

const resources = performance.getEntriesByType('resource') as PerformanceResourceTiming[];
const slowest = resources.sort((a, b) => b.duration - a.duration).slice(0, 5);
slowest.forEach(r => console.log(r.name, `${r.duration.toFixed(0)}ms`, r.initiatorType));

performance.mark('data-fetch-start');
await fetchProducts();
performance.mark('data-fetch-end');
performance.measure('data-fetch', 'data-fetch-start', 'data-fetch-end');
```

Core Web Vitals specifically get observed via `PerformanceObserver`:

```tsx
new PerformanceObserver((list) => {
  for (const entry of list.getEntries()) console.log('LCP:', entry.startTime);
}).observe({ type: 'largest-contentful-paint', buffered: true });
```

Three metrics matter, and they measure three different things: LCP (Largest Contentful Paint) is perceived load speed, INP (Interaction to Next Paint, replaced FID in 2024) is responsiveness, CLS (Cumulative Layout Shift) is visual stability. They matter to your job specifically because Google uses them as a search ranking signal, and because they're the closest proxy metrics get to actual user-perceived quality.

## The exact thresholds, and field data versus lab data

| Metric | Good | Needs Improvement | Poor |
|---|---|---|---|
| LCP | ≤ 2.5s | ≤ 4.0s | > 4.0s |
| INP | ≤ 200ms | ≤ 500ms | > 500ms |
| CLS | ≤ 0.1 | ≤ 0.25 | > 0.25 |

Field data, real measurements from actual visitors, via CrUX, PageSpeed Insights, Search Console, is what Google uses for ranking. Lab data, from Lighthouse or WebPageTest run against one simulated device and network, is diagnostic only, it doesn't capture real device and network variability, which is exactly how a page can pass Lighthouse cleanly and still fail field CWV on a mid-range Android phone over 4G.

## How production RUM actually ships this data

Calling `PerformanceObserver` directly is what these metrics run on under the hood, but production real-user-monitoring code uses Google's `web-vitals` npm package rather than reimplementing each metric's rules by hand, and those rules have genuine edge cases: LCP's "candidate element" can change as dynamic content loads in, CLS uses session windowing to group nearby layout shifts together.

```javascript
import { onCLS, onINP, onLCP } from 'web-vitals';

function sendToAnalytics(metric) {
  const body = JSON.stringify({ name: metric.name, value: metric.value, id: metric.id, rating: metric.rating });
  if (navigator.sendBeacon) navigator.sendBeacon('/analytics', body);
  else fetch('/analytics', { body, method: 'POST', keepalive: true });
}
onCLS(sendToAnalytics);
onINP(sendToAnalytics);
onLCP(sendToAnalytics);
```

Why `sendBeacon` gets checked first, not `fetch`: CLS and LCP frequently finalize right as the user is navigating away, and a normal `fetch()` call made during `visibilitychange` or `pagehide` can be killed mid-flight the instant the tab closes, silently dropping the payload. `navigator.sendBeacon(url, data)` exists for exactly this, the browser guarantees the request is queued and sent even if the page unloads immediately after the call. It's fire-and-forget, always a POST, capped around 64KB, plenty for a small metrics blob. `fetch(url, { keepalive: true })` is the fallback where `sendBeacon` isn't available, same intent, slightly weaker guarantee. The rule of thumb: `sendBeacon` for anything fired on unload or visibility-change, `fetch` for everything else where you actually need to read the response.

Fixing INP in React is usually not new API surface, it's the patterns you'd already reach for elsewhere: memoization (`React.memo`, `useMemo`, `useCallback`) to stop expensive re-renders and recomputation; `startTransition` to deprioritize expensive derived-state updates so the browser stays responsive to typing and clicking while that work finishes in the background; list virtualization, covered later in this course, to avoid mounting hundreds of DOM nodes at once. The one lever that isn't just a React pattern: breaking up a genuinely long synchronous task, parsing a large payload, sorting a big array, with `scheduler.yield()`, which hands control back to the browser between chunks so it can respond to input, falling back to chunked `setTimeout` or `requestIdleCallback` in browsers that don't support it yet.

## preload versus prefetch

Both are `<link rel="...">` resource hints telling the browser about a resource before it would normally discover it, but they signal different priority and timing.

```html
<!-- preload: fetch NOW, high priority — a resource THIS page needs soon,
     like a font only referenced inside CSS, which the browser can't discover
     until it parses the CSS, by which point it's already late -->
<link rel="preload" href="/fonts/inter.woff2" as="font" type="font/woff2" crossorigin>

<!-- prefetch: fetch when idle, low priority — a resource the NEXT page will likely need -->
<link rel="prefetch" href="/dashboard-chunk.js" as="script">
```

`preload` competes with the current page's own critical resources for bandwidth, so preloading everything is a common way candidates accidentally slow down the actual critical path when asked to "optimize" a page. `prefetch` is opportunistic and low-priority by design, safer to use liberally, though still wasted bandwidth the moment the "next page" guess turns out wrong.

## Images, still the largest payload on most pages

```html
<img
  src="/photo-800.jpg"
  srcset="/photo-400.jpg 400w, /photo-800.jpg 800w, /photo-1200.jpg 1200w"
  sizes="(max-width: 600px) 400px, 800px"
  alt="Product photo"
  loading="lazy"
  decoding="async"
  width="800" height="600"
/>
<picture>
  <source srcset="/photo.avif" type="image/avif" />
  <source srcset="/photo.webp" type="image/webp" />
  <img src="/photo.jpg" alt="Product photo" />
</picture>
```

`loading="lazy"` defers offscreen images until they're near the viewport, natively, no JS required. Explicit `width`/`height` (or `aspect-ratio` in CSS) lets the browser reserve the right space before the image loads, which is the direct fix for image-caused CLS. AVIF and WebP run 25-50% smaller than JPEG or PNG at equivalent visual quality. `srcset`/`sizes` stop you from shipping a 2000px image to a 400px mobile viewport, exactly the pairing covered in the CSS lesson earlier in this course, now tied to the metric it actually moves.
