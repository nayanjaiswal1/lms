---
kind: lesson
id_key: interview-prep-45/day-06-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "HTTP and Caching"
position: 21
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
"How would you cache this API response," "what's stale-while-revalidate," "explain ETag": these test whether you understand the network, not just React. It's also the territory system-design-adjacent frontend interviews lean on hardest, get comfortable with HTTP cache headers and service workers and you can speak to both the browser's cache and the CDN sitting in front of it.

## Three headers doing most of the work

They answer two different questions: can the client skip the network entirely, and if it does hit the network, can the server say "nothing changed" cheaply.

**`Cache-Control`** is the primary directive, replacing the older `Expires`/`Pragma` pair:

```
Cache-Control: max-age=3600              # fresh for 1 hour, no request needed
Cache-Control: no-cache                  # ALWAYS revalidate with the server (the name is misleading — it isn't "don't cache")
Cache-Control: no-store                  # never cache at all, anywhere
Cache-Control: public, max-age=31536000, immutable  # cache forever — for hashed asset filenames like app.a1b2c3.js
```

`no-cache` versus `no-store` is the classic trap: `no-cache` means store it, but revalidate with the server before using it, a conditional request still happens on every use. `no-store` means don't persist this response anywhere at all, the right call for anything carrying auth tokens or personal data.

**`ETag`** is a hash or version identifier for a specific resource version. The client sends it back via `If-None-Match` on the next request; a match gets a `304 Not Modified` with no body, saving the bandwidth of re-sending content that hasn't changed.

```
GET /api/user/42 → 200 OK, ETag: "33a64df551", Cache-Control: no-cache
GET /api/user/42, If-None-Match: "33a64df551" → 304 Not Modified (no body — the browser reuses its cached copy)
```

**`Last-Modified`** is a timestamp-based alternative, paired with `If-Modified-Since`, coarser than `ETag` (second-level precision, so it misses a change within the same second) but cheaper for the server, often just a file's mtime. Use both when you can; `ETag` wins if both are present, `Last-Modified` is the fallback.

## The CDN layer

A CDN is a cache geographically close to the user, sitting in front of the origin server. Two levers matter here. The **cache key**, what makes two requests "the same" for caching purposes, is typically URL plus relevant headers (`Vary: Accept-Encoding` for gzip vs. brotli, `Vary: Accept-Language` for localized responses); get it too narrow and you serve the wrong content to some users, too wide (an `Authorization` header, a random cache-busting query param) and the hit rate collapses toward zero. **Purge and invalidation** matter because a CDN holds content longer than the browser does, so deploying new content needs either a new URL, content-hashed filenames being the standard for JS/CSS bundles, or an explicit purge call.

The standard production pattern for a modern build: HTML ships with `Cache-Control: no-cache`, always revalidate, cheap request, tiny payload, so users always get the newest markup, while it references hashed asset URLs served with `Cache-Control: public, max-age=31536000, immutable`, since a content change produces a new hash and therefore a new URL, there's never a staleness problem to invalidate in the first place.

## Stale-while-revalidate

`stale-while-revalidate` is both a `Cache-Control` directive and, separately, a general caching pattern (SWR, TanStack Query, and service workers all implement it) that serves the cached response instantly, then fetches a fresh one in the background to update the cache for next time.

```
Cache-Control: max-age=60, stale-while-revalidate=3600
```

Fresh for 60 seconds. After that, for up to 3600 more seconds, the cache still serves the stale response instantly *and* kicks off a background revalidation. The user never waits on the network for this; they might briefly see one-render-old data. This is precisely why the SWR library is named after the pattern:

```tsx
async function staleWhileRevalidate<T>(cacheKey: string, fetcher: () => Promise<T>): Promise<T> {
  const cached = readCache<T>(cacheKey);
  if (cached) {
    fetcher().then(fresh => writeCache(cacheKey, fresh)); // fire the revalidation, don't await it
    return cached; // return stale data immediately, zero network wait
  }
  const fresh = await fetcher(); // no cache yet — must wait this one time
  writeCache(cacheKey, fresh);
  return fresh;
}
```

## Three ways to invalidate, in order of reliability

**Content-addressed URLs**: the filename encodes a hash of the content, `app.a1b2c3.js`. A change produces a different URL, so old entries just become unreferenced and expire naturally, the strongest guarantee, standard for static assets. **TTL-based expiration**: set `max-age` to whatever staleness window you can tolerate, simple, but there's always a window of serving stale data, fine for a homepage banner, not for an account balance. **Explicit invalidation**: actively tell the cache it's wrong, a CDN purge call, or bumping a service worker's cache name and deleting the old one, necessary when data changes unpredictably and staleness is unacceptable, but it requires the invalidation call to actually fire reliably, which is the genuinely hard part.

## A service worker as a programmable cache

Service workers sit between your app and the network as a proxy you write, letting you implement any strategy above, plus offline support.

```tsx
const CACHE_NAME = 'app-cache-v3'; // bump this string to invalidate everything below
const STATIC_ASSETS = ['/', '/app.js', '/app.css'];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(STATIC_ASSETS)));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(caches.keys().then(keys =>
    Promise.all(keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))), // this IS the invalidation step
  ));
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.url.includes('/api/')) {
    event.respondWith(
      caches.open(CACHE_NAME).then(async (cache) => {
        const cached = await cache.match(request);
        const networkFetch = fetch(request).then(response => {
          cache.put(request, response.clone()); // clone: a Response body can only be read once
          return response;
        });
        return cached || networkFetch; // return cache immediately if available
      }),
    );
    return;
  }
  event.respondWith(caches.match(request).then(cached => cached || fetch(request)));
});
```

To actually see this in DevTools: open the Network tab, load a page, reload it, and check the `Size` column. Anything showing `(disk cache)` or `(memory cache)` never touched the network at all; anything showing `304` hit the network but the server confirmed nothing changed, and a `304`'s response time is typically far faster than a full `200`.
