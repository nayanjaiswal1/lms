---
kind: lesson
id_key: interview-prep-45/note-web-vitals-rum-sendbeacon
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: Web Vitals Thresholds, the web-vitals Library, and sendBeacon"
position: 103
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

Core Web Vitals (LCP, INP, CLS) measure loading speed, responsiveness, and visual stability, and can be observed directly with the browser's `PerformanceObserver` API. This note covers the two pieces interviewers ask about next: the exact numeric thresholds, and how real production apps ship RUM (real user monitoring) data using the `web-vitals` library plus `sendBeacon`, instead of hand-rolling `PerformanceObserver` calls.

## Exact thresholds

| Metric | Good | Needs Improvement | Poor |
|---|---|---|---|
| LCP | ≤ 2.5s | ≤ 4.0s | > 4.0s |
| INP | ≤ 200ms | ≤ 500ms | > 500ms |
| CLS | ≤ 0.1 | ≤ 0.25 | > 0.25 |

Field data, meaning real measurements collected from actual visitors (CrUX, PageSpeed Insights, Search Console), is what Google uses for search ranking. Lab data, from tools like Lighthouse or WebPageTest run against a single simulated device and network, is diagnostic only. It doesn't reflect real device and network variability, so a page can pass Lighthouse and still fail field CWV on a mid-range Android phone over 4G.

## The `web-vitals` library, in practice

Calling `PerformanceObserver` directly is how these metrics work under the hood, but production RUM code uses Google's `web-vitals` npm package instead of re-implementing each metric's calculation rules by hand. Those rules have real edge cases, like LCP's candidate element changing as dynamic content loads in, or CLS's session windowing that groups nearby layout shifts together.

```javascript
import { onCLS, onINP, onLCP, onFCP, onTTFB } from 'web-vitals';

function sendToAnalytics(metric) {
  const body = JSON.stringify({
    name: metric.name,       // 'LCP' | 'INP' | 'CLS' | ...
    value: metric.value,
    id: metric.id,           // unique per page load, for de-duping
    rating: metric.rating,   // 'good' | 'needs-improvement' | 'poor'
  });

  if (navigator.sendBeacon) {
    navigator.sendBeacon('/analytics', body);
  } else {
    fetch('/analytics', { body, method: 'POST', keepalive: true });
  }
}

onCLS(sendToAnalytics);
onINP(sendToAnalytics);
onLCP(sendToAnalytics);
```

Each `on*` call registers a callback that the library invokes once it has a final value for that metric, which for LCP and CLS can happen well after the initial page load since both can keep changing as the page evolves. When the callback fires, `sendToAnalytics` serializes the handful of fields analytics actually needs and ships them off. Because `navigator.sendBeacon` is checked first, the happy path never touches `fetch` at all in a modern browser.

## Why `sendBeacon`, not `fetch`

CLS and LCP often finalize right as the user is leaving the page. A normal `fetch()` call made during `visibilitychange` or `pagehide` can be killed mid-flight when the tab closes, silently dropping the analytics payload.

`navigator.sendBeacon(url, data)` is built for exactly this: the browser guarantees the request is queued and sent even if the page unloads immediately after the call. It's fire-and-forget, meaning there's no response to read, it's always a POST, and it's capped at roughly 64KB, which is plenty for a small metrics JSON blob. `fetch(url, { keepalive: true })` is the fallback for environments without `sendBeacon` support: same intent, slightly less guaranteed, and it has its own payload cap.

Rule of thumb: reach for `sendBeacon` for anything fired on unload or visibility-change, and `fetch` for everything else where you actually need to read the response.

## Fixing INP in React

INP problems are usually fixed with React patterns you'd already reach for elsewhere, not new API surface:

- **Memoization**, via `React.memo`, `useMemo`, and `useCallback`, prevents expensive components from re-rendering or recomputing when their inputs haven't actually changed.
- **`startTransition`** deprioritizes expensive derived-state updates so the browser can keep handling input (typing, clicking) responsively while that lower-priority work finishes in the background.
- **List virtualization**, via libraries like `react-window` or `react-virtual`, keeps a large list from mounting hundreds of DOM nodes at once by only rendering what's currently visible.

The one INP lever that isn't just a React pattern: breaking up a genuinely long synchronous task, like parsing a large payload or sorting a big array, with `scheduler.yield()`. That API hands control back to the browser between chunks of work so it can respond to input, and falls back to chunked `setTimeout` or `requestIdleCallback` calls in browsers that don't support `scheduler.yield()` yet.
