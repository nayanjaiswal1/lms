---
kind: lesson
id_key: interview-prep-45/day-08-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "Network Performance and Web Vitals"
position: 24
estimated_minutes: 35
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---
"Why is this page slow to load?" is a question you answer by reading data, not by guessing. This lesson covers the waterfall chart, the numbers you can pull in code, the exact thresholds Google checks, and the fixes, resource hints and image techniques, that turn a diagnosis into a real improvement.

## Reading a waterfall

Picture a relay race where each runner has to wait for the one before them to finish, even on legs that could have run side by side. DevTools' Network tab draws exactly that: every request as a horizontal bar, split into phases, `Queued → Stalled → DNS Lookup → Initial Connection → SSL → Request Sent → Waiting (TTFB) → Content Download`.

Three patterns to look for, in order of how often they're the real problem.

A long `Stalled` bar across many requests at once usually means the browser is holding requests back because it already has too many open connections to the same server. HTTP/2 mostly fixes this by letting many requests share one connection, check the `Protocol` column to confirm.

A long `TTFB`, time to first byte, on the very first document request points at the server: a cold start, a slow backend, or missing caching. This is not a frontend problem, and nothing on the page can render until this finishes.

A "staircase," where request B doesn't start until request A finishes even though nothing forced that, usually means one thing was only discovered after reading another: the HTML finds the CSS, the CSS finds a font, the JS then goes and fetches data. Every step like this costs one full round trip.

> **Remember:** a long TTFB is a server problem. A "staircase" shape is a discovery-order problem. Different symptoms, different fixes.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-vitals-waterfall-q1", "type": "mcq",
      "prompt": "A page's very first request, the HTML document itself, has a long Waiting (TTFB) time. Where's the problem?",
      "options": [
        {"id":"a","text":"The frontend's JavaScript bundle is too large"},
        {"id":"b","text":"The server: a slow backend, a cold start, or missing server-side caching, since nothing can render until this first byte arrives"},
        {"id":"c","text":"The user's browser cache is full"},
        {"id":"d","text":"The CSS is render-blocking"}
      ],
      "correct": "b",
      "explanation": "TTFB on the document request measures how long the server took before sending anything back. It has nothing to do with frontend code, since the browser hasn't received any HTML to parse yet." }
] }
```

## Measuring it in code with the Performance API

The `Performance` API gives you the exact same numbers the waterfall draws, but as data you can read in code and send to your own monitoring.

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

The three Core Web Vitals get watched with a `PerformanceObserver`:

```tsx
new PerformanceObserver((list) => {
  for (const entry of list.getEntries()) console.log('LCP:', entry.startTime);
}).observe({ type: 'largest-contentful-paint', buffered: true });
```

Each of the three measures a different thing. LCP (Largest Contentful Paint) is how fast the page *feels* like it loaded. INP (Interaction to Next Paint) is how quickly the page responds when you click or type. CLS (Cumulative Layout Shift) is how much content jumps around while loading. They matter to your job for a concrete reason: Google uses all three as a search-ranking signal, and they're the closest thing we have to a number for "did this feel good to use."

> **Remember:** LCP is load speed, INP is responsiveness, CLS is visual stability. Three different questions, three different fixes.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-vitals-metrics-q1", "type": "mcq",
      "prompt": "A page loads its content quickly, but a banner ad shifts the whole layout down half a second later, pushing a button the user was about to tap. Which Core Web Vital catches this?",
      "options": [
        {"id":"a","text":"LCP"},
        {"id":"b","text":"INP"},
        {"id":"c","text":"CLS — Cumulative Layout Shift measures exactly this kind of unexpected content movement"},
        {"id":"d","text":"TTFB"}
      ],
      "correct": "c",
      "explanation": "CLS specifically tracks visible content shifting position after it's already been painted. A late-loading ad pushing everything down is the textbook cause." }
] }
```

## The exact thresholds, and why two tools can disagree

| Metric | Good | Needs Improvement | Poor |
|---|---|---|---|
| LCP | 2.5s or less | up to 4.0s | over 4.0s |
| INP | 200ms or less | up to 500ms | over 500ms |
| CLS | 0.1 or less | up to 0.25 | over 0.25 |

**Field data** comes from real visitors' actual devices and networks (via CrUX, PageSpeed Insights, Search Console), and it's what Google actually uses for ranking. **Lab data** comes from a tool like Lighthouse or WebPageTest, running against one simulated device and network. Lab data is useful for diagnosing a problem, but it's not the real thing, it can't capture how a real mid-range phone on patchy 4G actually experiences your page. That's exactly how a page passes Lighthouse cleanly and still fails its real Core Web Vitals in the field.

> **Remember:** lab data diagnoses. Field data is what actually gets scored.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-vitals-fielddata-q1", "type": "mcq",
      "prompt": "A page scores perfectly in Lighthouse but fails its real Core Web Vitals for actual users. What's the most likely explanation?",
      "options": [
        {"id":"a","text":"Lighthouse is broken"},
        {"id":"b","text":"Lighthouse runs lab data against one simulated device and network; real users on slower phones and networks experience something Lighthouse's single simulation didn't capture"},
        {"id":"c","text":"Google ignores Lighthouse scores entirely"},
        {"id":"d","text":"This can never happen"}
      ],
      "correct": "b",
      "explanation": "Lab data is diagnostic, from one simulated setup. Field data reflects the actual mix of devices and networks real visitors use, which is what ranking is based on, and the two can disagree." }
] }
```

## How real apps actually ship this data

Calling `PerformanceObserver` yourself is what these metrics run on underneath, but production monitoring code uses Google's `web-vitals` npm package instead of reimplementing each metric's rules by hand, because those rules have real edge cases: LCP's "biggest element so far" can change as content keeps loading in, and CLS groups nearby shifts together into windows.

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

Why check `sendBeacon` first, not `fetch`? CLS and LCP often only finalize the instant a user navigates away. A normal `fetch()` call fired during that moment can get killed mid-flight the second the tab closes, silently losing the data. `navigator.sendBeacon(url, data)` exists specifically for this: the browser promises to send it even if the page is already gone. It's fire-and-forget, always a POST, and capped around 64KB, plenty for a small metrics message. `fetch(..., { keepalive: true })` is the backup for browsers without `sendBeacon`.

Fixing a slow INP in React usually means reaching for patterns you already know: `React.memo`/`useMemo`/`useCallback` to stop unnecessary re-renders, `startTransition` to let React deprioritize an expensive update so typing and clicking still feel instant, and list virtualization (a later lesson) to avoid mounting hundreds of DOM nodes at once. For one genuinely long, unavoidable synchronous task, parsing a huge payload, sorting a massive array, `scheduler.yield()` hands control back to the browser between chunks so it can still respond to a click mid-task.

> **Remember:** `sendBeacon` for data fired on unload, `fetch` for everything else where you need to read the response.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-vitals-beacon-q1", "type": "mcq",
      "prompt": "Why is navigator.sendBeacon() used instead of fetch() for sending final Web Vitals data when a user closes the tab?",
      "options": [
        {"id":"a","text":"sendBeacon is faster to execute"},
        {"id":"b","text":"A normal fetch() call can be killed mid-flight the instant the tab closes; sendBeacon is guaranteed by the browser to still be sent"},
        {"id":"c","text":"fetch() cannot send JSON data"},
        {"id":"d","text":"sendBeacon works over HTTP but fetch requires HTTPS"}
      ],
      "correct": "b",
      "explanation": "CLS and LCP frequently finalize right as a user navigates away. sendBeacon exists precisely to guarantee delivery of small final payloads in that moment, which a regular fetch() cannot promise." }
] }
```

## preload versus prefetch

Both tell the browser about a resource before it would normally find it on its own, but they carry different urgency.

```html
<!-- preload: fetch it NOW, high priority — this page needs it soon, e.g. a font
     only referenced inside CSS, which the browser can't discover until it parses that CSS -->
<link rel="preload" href="/fonts/inter.woff2" as="font" type="font/woff2" crossorigin>

<!-- prefetch: fetch it when idle, low priority — the NEXT page will likely need it -->
<link rel="prefetch" href="/dashboard-chunk.js" as="script">
```

`preload` competes with this page's own critical resources for bandwidth, which is exactly how candidates accidentally slow a page down by preloading too much of it. `prefetch` is low-priority and safe to use more freely, though it's wasted bandwidth the moment the guess about the "next page" turns out wrong.

> **Remember:** preload says "I need this now." Prefetch says "I might need this soon, whenever there's time to spare."

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-vitals-preload-q1", "type": "mcq",
      "prompt": "A font is referenced only inside a CSS file, so the browser can't discover it until the CSS finishes parsing, by which point it's already late. What fixes this?",
      "options": [
        {"id":"a","text":"rel=\"prefetch\" on the font, since fonts should load lazily"},
        {"id":"b","text":"rel=\"preload\" on the font, telling the browser to fetch it right away instead of waiting to discover it through the CSS"},
        {"id":"c","text":"Removing the font from CSS entirely"},
        {"id":"d","text":"Nothing can fix this"}
      ],
      "correct": "b",
      "explanation": "preload is exactly for resources the current page needs soon but that the browser would otherwise discover too late through normal parsing order." }
] }
```

## Images: still the biggest payload on most pages

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

`loading="lazy"` skips downloading offscreen images until they're close to the viewport, natively, with no JavaScript needed. Setting `width`/`height` (or `aspect-ratio` in CSS) lets the browser reserve the right amount of space before the image even loads, which directly fixes the layout-shift bug CLS measures. AVIF and WebP run 25 to 50 percent smaller than JPEG or PNG at the same visual quality. `srcset`/`sizes` stop a 2000px image from being sent to a 400px-wide phone screen.

> **Remember:** setting width and height on an image is a CLS fix, not just a layout nicety, it lets the browser reserve the image's space before it's even downloaded.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-vitals-images-q1", "type": "mcq",
      "prompt": "Why does adding explicit width and height attributes to an <img> tag reduce Cumulative Layout Shift?",
      "options": [
        {"id":"a","text":"It makes the image download faster"},
        {"id":"b","text":"It lets the browser reserve the correct amount of space for the image before it finishes downloading, so nothing else jumps once it appears"},
        {"id":"c","text":"It disables lazy loading"},
        {"id":"d","text":"It has no effect on CLS"}
      ],
      "correct": "b",
      "explanation": "Without known dimensions, the browser doesn't know how much space to leave, so surrounding content shifts the moment the image loads and its real size becomes known. Declared dimensions remove that guesswork." }
] }
```
