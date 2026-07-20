---
kind: lesson
id_key: interview-prep-45/day-06-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Day 6 — HTTP and Caching"
position: 9
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Caching questions ("how would you cache this API response," "what's stale-while-revalidate," "explain ETag") test whether you understand the network, not just React. This is also the day system-design-adjacent frontend interviews lean on hardest — get comfortable with HTTP cache headers and service workers and you can speak to both the browser cache and the CDN layer.

## HTTP caching headers

Three headers do almost all the work, and they answer two different questions: "can I skip the network entirely?" and "if I do hit the network, can the server tell me nothing changed?"

**`Cache-Control`** — the primary directive, replacing the older `Expires`/`Pragma`:

```
Cache-Control: max-age=3600              # fresh for 1 hour, no request needed
Cache-Control: no-cache                  # ALWAYS revalidate with the server (misleading name — it doesn't mean "don't cache")
Cache-Control: no-store                  # never cache at all, anywhere
Cache-Control: private, max-age=0        # only cache in the user's browser, not shared caches/CDNs
Cache-Control: public, max-age=31536000, immutable  # cache forever — for hashed asset filenames (app.a1b2c3.js)
```

`no-cache` vs `no-store` is a classic interview trap: `no-cache` means "store it, but revalidate with the server before using it" (a conditional request still happens); `no-store` means "don't persist this response anywhere, full stop" — correct for anything containing auth tokens or personal data.

**`ETag`** — a hash/version identifier for a specific resource version. The client sends it back on the next request via `If-None-Match`; if it matches, the server returns `304 Not Modified` with no body, saving the bandwidth of re-sending unchanged content:

```
# First request
GET /api/user/42
→ 200 OK
  ETag: "33a64df551"
  Cache-Control: no-cache

# Later, browser revalidates automatically
GET /api/user/42
  If-None-Match: "33a64df551"
→ 304 Not Modified   (no body sent — the browser reuses its cached copy)
```

**`Last-Modified`** — a timestamp-based alternative to `ETag`, paired with `If-Modified-Since` on the follow-up request. Coarser than `ETag` (second-level precision, and doesn't catch a change that happens within the same second), but cheaper for the server to compute — it's often just a file's mtime.

```
Last-Modified: Wed, 21 Oct 2025 07:28:00 GMT
# next request sends: If-Modified-Since: Wed, 21 Oct 2025 07:28:00 GMT
```

Use both when you can — `ETag` takes priority if both are present, `Last-Modified` is the fallback.

## CDN caching strategies

A CDN is a cache layer geographically close to the user, sitting in front of your origin server. Two levers matter for frontend interviews:

- **Cache key**: what makes two requests "the same" for caching purposes — typically URL + relevant headers (e.g., `Vary: Accept-Encoding` for gzip vs brotli, `Vary: Accept-Language` for localized responses). Get this wrong and you either serve the wrong content to some users (cache key too narrow) or get near-zero cache hit rate (cache key too wide, e.g. including a `Authorization` header or a cache-busting query param that's actually random per request).
- **Purge/invalidation**: CDNs hold content longer than the browser, so deploying new content requires either a new URL (content-hashed filenames — the standard approach for JS/CSS bundles) or an explicit purge API call.

The standard production pattern for a modern build (Vite/webpack/Next.js): HTML is served with `Cache-Control: no-cache` (always revalidate, cheap request, tiny payload) so users always get the latest HTML, while it references hashed asset URLs (`/app.a1b2c3.js`) served with `Cache-Control: public, max-age=31536000, immutable` (cache forever — a content change produces a new hash, hence a new URL, so there's never a staleness problem to invalidate).

## Stale-while-revalidate

`stale-while-revalidate` is a `Cache-Control` directive (and, independently, a general caching *pattern* implemented by libraries like SWR/React Query and service workers) that serves the cached response immediately, then fetches a fresh one in the background to update the cache for *next* time.

```
Cache-Control: max-age=60, stale-while-revalidate=3600
```

Reading: fresh for 60 seconds. After that, for up to 3600 more seconds, the cache still serves the stale response instantly *and* kicks off a background revalidation request. The user never waits on the network for this request; they might just briefly see one-render-old data. This is exactly why the "SWR" library (and TanStack Query's default behavior) is named after this pattern — it's the "show cached data instantly, update quietly" UX.

```tsx
// Conceptually what a library like SWR does under the hood:
async function staleWhileRevalidate<T>(cacheKey: string, fetcher: () => Promise<T>): Promise<T> {
  const cached = readCache<T>(cacheKey);

  if (cached) {
    // Fire the revalidation in the background — don't await it before returning
    fetcher().then(fresh => writeCache(cacheKey, fresh));
    return cached; // return stale data immediately, zero network wait
  }

  // No cache yet — must wait on the network this one time
  const fresh = await fetcher();
  writeCache(cacheKey, fresh);
  return fresh;
}
```

## Cache invalidation strategies

"There are only two hard things in Computer Science: cache invalidation and naming things." Three practical strategies, in order of reliability:

1. **Content-addressed URLs (cache-busting via hashing)**: the filename encodes a hash of the content (`app.a1b2c3.js`). A change produces a different URL, so there's nothing to invalidate — old cached entries just become unreferenced and expire naturally. This is the strategy for static assets and the strongest guarantee.
2. **TTL-based expiration**: set `max-age` to how long you're willing to tolerate staleness. Simple, but there's always a window where stale data is served — acceptable for things like a homepage banner, not for account balances.
3. **Explicit invalidation (purge)**: actively tell the cache "this is now wrong" — call the CDN's purge API, or in a service worker, bump a cache version name and delete the old one. Necessary when data changes unpredictably and staleness is unacceptable (e.g., a price change), but it requires the invalidation call to actually fire reliably, which is the hard part.

## Build: a service worker for caching

Service workers sit between your app and the network as a programmable proxy, letting you implement any of the strategies above (and enable offline support):

```tsx
// sw.js — registered from your app with navigator.serviceWorker.register('/sw.js')
const CACHE_NAME = 'app-cache-v3'; // bump this string to invalidate everything below
const STATIC_ASSETS = ['/', '/app.js', '/app.css'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(STATIC_ASSETS)),
  );
});

self.addEventListener('activate', (event) => {
  // Delete old cache versions — this IS the invalidation step
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))),
    ),
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;

  if (request.url.includes('/api/')) {
    // Stale-while-revalidate for API calls: serve cache instantly, update in background
    event.respondWith(
      caches.open(CACHE_NAME).then(async (cache) => {
        const cached = await cache.match(request);
        const networkFetch = fetch(request).then(response => {
          cache.put(request, response.clone()); // clone: a Response body can only be read once
          return response;
        });
        return cached || networkFetch; // return cache immediately if we have it
      }),
    );
    return;
  }

  // Cache-first for static assets, fall back to network
  event.respondWith(
    caches.match(request).then(cached => cached || fetch(request)),
  );
});
```

Demonstrating browser caching behavior for the checklist item below: open DevTools → Network tab, load a page, reload it, and inspect the `Size` column — entries showing `(disk cache)` or `(memory cache)` never hit the network at all; entries showing `304` hit the network but the server confirmed no change (compare response time: a 304 is typically much faster than a full 200).

## Key takeaways

- `Cache-Control: no-cache` means "revalidate every time"; `no-store` means "never persist" — they are not synonyms despite the similar names.
- `ETag`/`If-None-Match` and `Last-Modified`/`If-Modified-Since` enable `304 Not Modified` responses — the request still happens, but the body doesn't.
- Content-hashed filenames + `immutable` cache headers eliminate the invalidation problem entirely for static assets; HTML itself should stay `no-cache` so it always points at the latest hashes.
- `stale-while-revalidate` serves cached data instantly and refreshes in the background — the pattern behind SWR/React Query's default UX.
- Cache invalidation strategies rank by reliability: content-addressed URLs (best) > TTL expiration (simple, has a staleness window) > explicit purge (necessary for unpredictable changes, but must fire reliably).
- Service workers let you implement any caching strategy per-route by intercepting `fetch` events; bump the cache name string to invalidate old entries on `activate`.

## Today's checklist

- [ ] Read: HTTP caching headers (`Cache-Control`, `ETag`, `Last-Modified`)
- [ ] Implement a service worker for caching
- [ ] Demonstrate browser caching behavior in DevTools Network tab
- [ ] Be able to explain: CDN caching strategies
- [ ] Be able to explain: stale-while-revalidate
- [ ] Be able to explain: cache invalidation strategies
