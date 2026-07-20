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

Day 8 covered what LCP/INP/CLS measure and how to observe them with raw `PerformanceObserver`. This note adds the two pieces interviewers ask about next: the exact numeric thresholds, and how real production apps ship RUM data (the `web-vitals` library + `sendBeacon`) instead of hand-rolling `PerformanceObserver` calls.

## Exact thresholds

| Metric | Good | Needs Improvement | Poor |
|---|---|---|---|
| LCP | ≤ 2.5s | ≤ 4.0s | > 4.0s |
| INP | ≤ 200ms | ≤ 500ms | > 500ms |
| CLS | ≤ 0.1 | ≤ 0.25 | > 0.25 |

Field data (CrUX, PageSpeed Insights, Search Console) is what Google uses for search ranking. Lab data (Lighthouse, WebPageTest) is diagnostic only — it doesn't reflect real device/network variability, so a page can pass Lighthouse and still fail field CWV on a mid-range Android over 4G.

## The `web-vitals` library, in practice

Raw `PerformanceObserver` (Day 8) is how the metrics work under the hood, but production RUM code uses Google's `web-vitals` npm package instead of re-implementing the LCP/INP/CLS calculation rules (which have edge cases — e.g. LCP candidate changes on dynamic content, CLS session windowing):

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

## Why `sendBeacon`, not `fetch`

CLS and LCP often finalize right as the user is *leaving* the page — a normal `fetch()` call made during `visibilitychange`/`pagehide` can be killed mid-flight when the tab closes, silently dropping the analytics payload.

`navigator.sendBeacon(url, data)` is built for exactly this: the browser guarantees the request is queued and sent even if the page unloads immediately after the call. It's fire-and-forget (no response to read), always a POST, and capped at ~64KB — fine for a small metrics JSON blob. `fetch(url, { keepalive: true })` is the fallback for environments without `sendBeacon` support — same intent, slightly less guaranteed, and has its own payload cap.

Rule of thumb: `sendBeacon` for anything fired on unload/visibility-change; `fetch` for everything else where you need the response.

## Fixing INP in React — where the tools already live in this course

INP fixes are mostly React patterns already covered elsewhere in this course, not new API surface:
- Memoization (`React.memo`, `useMemo`, `useCallback`) — Day 1/5/7/10/16/19/21/26/27 and `90-notes-js-react-interview-prep.md`.
- `startTransition` to deprioritize expensive derived state while keeping input responsive — Day 19 and `mock-interviews/34-lesson.md`.
- List virtualization for large DOM (`react-window`/`react-virtual`) — Day 5/10/11/14 and `101-notes-react-query-virtualization-microfrontend.md`.

The one INP lever not covered elsewhere: breaking up a genuinely long synchronous task (parsing, sorting large arrays) with `scheduler.yield()` (or chunked `setTimeout`/`requestIdleCallback` as a fallback for browsers without scheduler support) so the main thread can respond to input between chunks.

## Key takeaways

- Numeric thresholds: LCP ≤2.5s/≤4.0s, INP ≤200ms/≤500ms, CLS ≤0.1/≤0.25 (good/needs-improvement boundaries).
- Field data (CrUX/PSI/Search Console) drives ranking; lab data (Lighthouse) is diagnostic only.
- Use the `web-vitals` library for RUM instead of hand-rolled `PerformanceObserver` — it correctly implements each metric's edge-case rules.
- `sendBeacon` survives page unload where `fetch` can get killed; `fetch({ keepalive: true })` is the fallback.
- INP fixes are the memoization/`startTransition`/virtualization patterns already in this course, plus `scheduler.yield()` for long synchronous tasks.
