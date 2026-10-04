---
kind: lesson
id_key: interview-prep-45/day-06-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "HTTP and Caching"
position: 23
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Picture a librarian who, before handing you a book, checks a sticky note on the cover that says "last changed: Tuesday." If you already have Tuesday's copy at home, she just says "yours is still good" instead of handing you the whole book again. That sticky note is what HTTP caching headers do for a browser: they let it skip downloading something it already has, or at least skip downloading the parts that haven't changed.

Interviewers ask about this because it proves you understand the network, not just React. Get comfortable with a handful of headers and you can speak to the browser's own cache and to the CDN sitting in front of your server.

## Cache-Control: the main instruction

`Cache-Control` is the header that answers one question: can the browser skip the network call entirely?

```
Cache-Control: max-age=3600              # good for 1 hour, no request needed at all
Cache-Control: no-cache                  # store it, but always check with the server first (confusing name)
Cache-Control: no-store                  # never save this anywhere
Cache-Control: public, max-age=31536000, immutable  # cache for a year — for files named like app.a1b2c3.js
```

`no-cache` and `no-store` sound alike but mean opposite things. `no-cache` means: keep a copy, but ask the server "is this still good?" before using it, every single time. `no-store` means: don't keep a copy anywhere, ever. Use `no-store` for anything with a password or personal data in it.

> **Remember:** `no-cache` still saves the file, it just re-checks first. `no-store` saves nothing at all.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-http-cachecontrol-q1", "type": "mcq",
      "prompt": "What's the difference between Cache-Control: no-cache and Cache-Control: no-store?",
      "options": [
        {"id":"a","text":"They mean the same thing"},
        {"id":"b","text":"no-cache stores the response but always revalidates with the server before using it; no-store never saves the response anywhere"},
        {"id":"c","text":"no-store is slower than no-cache but otherwise identical"},
        {"id":"d","text":"no-cache disables caching for images only"}
      ],
      "correct": "b",
      "explanation": "no-cache keeps a copy but forces a check with the server every time. no-store keeps nothing at all, the right setting for anything holding auth tokens or personal data." }
] }
```

## ETag: a fingerprint, not the whole file

An `ETag` is a short fingerprint of one specific version of a resource. The browser sends it back on the next request. If nothing changed, the server replies with an empty `304 Not Modified` instead of resending the whole thing.

```
GET /api/user/42 → 200 OK, ETag: "33a64df551", Cache-Control: no-cache
GET /api/user/42, If-None-Match: "33a64df551" → 304 Not Modified (no body at all)
```

`Last-Modified` does almost the same job with a timestamp instead of a fingerprint. It's coarser, it only tracks to the second, so two changes in the same second look identical, but it's cheap for the server to produce, often just a file's own save time. Use both when you can; the server should prefer `ETag` if it has one.

> **Remember:** a `304` means "you already have the right answer," and it carries no body at all, so it's nearly free.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-http-etag-q1", "type": "mcq",
      "prompt": "The browser sends If-None-Match with an ETag, and the server replies 304 Not Modified. What did the browser actually download?",
      "options": [
        {"id":"a","text":"The full response body again, just faster"},
        {"id":"b","text":"Nothing — a 304 has no body, the browser reuses the copy it already has"},
        {"id":"c","text":"Only the HTTP headers, discarding the old body"},
        {"id":"d","text":"A compressed version of the same file"}
      ],
      "correct": "b",
      "explanation": "A 304 response carries no body at all. It only confirms the browser's existing copy is still correct, which is what makes it nearly free compared to a full download." }
] }
```

## The CDN layer: a cache in front of your server

A CDN, short for Content Delivery Network, is a cache that sits between the user and your own server, usually running on servers spread around the world. Two things decide how well it works.

The **cache key** is whatever makes two requests count as "the same" for caching purposes. It's normally the URL, plus a few headers listed under `Vary` (`Vary: Accept-Encoding` for compressed vs. uncompressed, `Vary: Accept-Language` for translated pages). Make the key too narrow and some users get the wrong content; too wide, say you `Vary` on the raw `User-Agent` string, and the CDN ends up storing a nearly separate copy per visitor, which quietly wrecks how often it actually has what it needs.

**Purging** matters because a CDN can hold onto a file far longer than a browser does. The standard fix, used everywhere in production, is to give the file a new name whenever it changes: HTML ships with `Cache-Control: no-cache` so it's always re-checked and stays cheap and small, while it links to hashed asset URLs, `app.4f2b9c.js`, served with `Cache-Control: public, max-age=31536000, immutable`. A new build makes a new hash, so there is no "old file to clear" in the first place.

> **Remember:** giving a changed file a new name is more reliable than asking every CDN location to clear the old one.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-http-cdn-q1", "type": "mcq",
      "prompt": "Why do production builds name their JavaScript files like app.4f2b9c.js instead of just app.js?",
      "options": [
        {"id":"a","text":"It looks more professional"},
        {"id":"b","text":"The hash changes whenever the file's content changes, so a new build produces a brand-new URL with nothing old left to clear from any cache"},
        {"id":"c","text":"Browsers require hashed filenames for JavaScript"},
        {"id":"d","text":"It makes the file download faster"}
      ],
      "correct": "b",
      "explanation": "A content-hashed filename turns cache clearing into a non-problem: the old URL simply stops being referenced, so it can sit cached for a year with nobody needing to purge it." }
] }
```

## Stale-while-revalidate: answer now, fix it a moment later

`stale-while-revalidate` is a `Cache-Control` option, and also a general pattern (SWR and TanStack Query are named after it), that hands back the old, cached answer immediately, then quietly fetches a fresh one in the background for the next request.

```
Cache-Control: max-age=60, stale-while-revalidate=3600
```

Good for 60 seconds. For up to 3600 seconds after that, a request still gets the stale answer instantly, and a fresh fetch starts in the background at the same time. The user never waits; they might see data that's a few seconds old.

```tsx
async function staleWhileRevalidate<T>(cacheKey: string, fetcher: () => Promise<T>): Promise<T> {
  const cached = readCache<T>(cacheKey);
  if (cached) {
    fetcher().then(fresh => writeCache(cacheKey, fresh)); // fire it, don't wait on it
    return cached; // hand back the old value with zero delay
  }
  const fresh = await fetcher(); // first time ever — nothing to serve yet, so wait
  writeCache(cacheKey, fresh);
  return fresh;
}
```

> **Remember:** stale-while-revalidate trades "always exactly correct" for "always instant, and correct within a few seconds."

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-http-swr-q1", "type": "mcq",
      "prompt": "What does a stale-while-revalidate cache actually return while it's refreshing in the background?",
      "options": [
        {"id":"a","text":"An error, until the refresh finishes"},
        {"id":"b","text":"The old, cached value, immediately, while a fresh value is fetched in the background for next time"},
        {"id":"c","text":"It blocks and waits for the fresh value every time"},
        {"id":"d","text":"Nothing — the request is dropped"}
      ],
      "correct": "b",
      "explanation": "The whole point of the pattern is zero wait: hand back what's already cached, and only use the fresh fetch to update the cache for whoever asks next." }
] }
```

## A service worker: a cache you program yourself

A service worker sits between your app and the network like a small proxy you write the rules for. It can implement any of the strategies above, plus keep the app usable with no network at all.

```tsx
const CACHE_NAME = 'app-cache-v3'; // change this string to throw away everything below and start clean
const STATIC_ASSETS = ['/', '/app.js', '/app.css'];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(STATIC_ASSETS)));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(caches.keys().then(keys =>
    Promise.all(keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))), // this line IS the cleanup step
  ));
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.url.includes('/api/')) {
    event.respondWith(
      caches.open(CACHE_NAME).then(async (cache) => {
        const cached = await cache.match(request);
        const networkFetch = fetch(request).then(response => {
          cache.put(request, response.clone()); // clone, because a body can only be read once
          return response;
        });
        return cached || networkFetch; // serve the cached copy instantly if there is one
      }),
    );
    return;
  }
  event.respondWith(caches.match(request).then(cached => cached || fetch(request)));
});
```

To see this for real: open DevTools' Network tab, load a page, then reload it. A `Size` column showing `(disk cache)` or `(memory cache)` means the browser never touched the network at all. A `304` means it did reach the network, but the server just confirmed nothing changed, and that reply comes back far faster than a full `200`.

> **Remember:** a service worker is a cache with rules you write yourself, which is also why bumping its cache name is the deliberate step that clears out the old rules.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-http-sw-q1", "type": "mcq",
      "prompt": "In the service worker above, what actually deletes the previous version's cached files?",
      "options": [
        {"id":"a","text":"The browser deletes old caches automatically after 24 hours"},
        {"id":"b","text":"The activate handler compares every existing cache name against the current CACHE_NAME and deletes any that don't match"},
        {"id":"c","text":"Reloading the page clears all caches by default"},
        {"id":"d","text":"Nothing — old caches are never removed"}
      ],
      "correct": "b",
      "explanation": "Bumping the CACHE_NAME string is only half the job. The activate handler's cleanup loop is what actually removes every cache that doesn't match the new name, freeing the old files." }
] }
```
