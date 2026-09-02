---
kind: lesson
id_key: interview-prep-45/fe-dom-nodes-events-traversal
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "The DOM: Nodes, Events, and Traversal"
position: 12
estimated_minutes: 30
source:
    - interview-prep-notes.md
---
Before React, before any framework, there's the DOM: the browser's live, in-memory object tree built from your parsed HTML. It is not the HTML itself, and `document` is its root. Everything a framework does, eventually, is a more convenient way of mutating this tree. This lesson covers it directly: node types, traversal, events, and the one browser API, Intersection Observer, that replaced a genuinely bad older pattern for watching scroll position.

## Node types, and the whitespace gotcha

Every node in the DOM has a numeric `nodeType`: `1` for an element, `3` for text (and yes, the whitespace between your tags counts as a text node too), `8` for a comment, `9` for the document itself, `11` for a document fragment. That whitespace detail matters the moment you start writing raw DOM traversal code, `firstChild` on an element with any leading whitespace in the source often hands you a text node, not the element you expected.

## Two traversal vocabularies

There's an "all nodes" set of properties, `parentNode`, `childNodes`, `firstChild`, `nextSibling`, which includes text and comment nodes, and an "elements only" set, `parentElement`, `children`, `firstElementChild`, `nextElementSibling`, which skips them. `closest(selector)` walks *up* from an element until it finds a match, or returns `null` if it never does, the inverse of `querySelector`, which only ever looks downward.

| Method | Returns |
|---|---|
| `getElementById` | a single element |
| `getElementsByClassName` / `TagName` | a **live** `HTMLCollection` |
| `querySelector` / `querySelectorAll` | a single element / a **static** `NodeList` |

The word "live" there isn't decoration. A live collection auto-updates as the DOM changes, which means mutating it while looping over it skips elements, since the collection is shrinking or growing under you mid-iteration. A `querySelectorAll` result is a frozen snapshot instead; if you need to safely mutate while iterating a live collection, convert it first with `Array.from()`.

## Creating and mutating

`createElement`, `appendChild`/`append` (which, unlike `appendChild`, accepts multiple nodes or plain strings at once), `prepend`, `insertBefore`, `replaceChild`, and `.remove()` cover most of what you'll write by hand. `cloneNode(deep)` copies markup but never copies attached event listeners, a common source of "why did my clicks stop working" bugs. `createDocumentFragment()` exists specifically so you can build a batch of nodes off-screen and insert them all at once, one reflow instead of one reflow per insertion, which matters a lot once you're inserting dozens of rows in a loop.

## Attribute versus property: two different snapshots in time

An **attribute** is the string that came from your HTML source, and it's frozen at load time, `getAttribute`/`setAttribute` read and write it directly. A **property** is the live current state, `el.value`, `el.checked`, and it changes as the user interacts with the page. These diverge the moment a user does anything:

```js
// <input value="hi">
el.value;               // whatever the user has typed now
el.getAttribute('value'); // still "hi", forever, regardless of what el.value says
```

Boolean attributes, `checked`, `disabled`, `required`, `readonly`, `selected`, work on presence, not on a string value: their mere existence in the markup means `true`, and their absence means `false`. When present, `getAttribute` returns `""`, not `"true"`; when absent, it returns `null`, never `"false"`. To disable a button in JavaScript, set the property directly: `button.disabled = true`.

## innerHTML, textContent, and innerText aren't interchangeable

`innerHTML` parses whatever you assign it as HTML, which is a genuine XSS risk the moment the string could contain user input, and it re-renders the entire subtree. `textContent` is plain text, safe by construction, includes hidden text, and needs no reflow to read. `innerText` respects CSS visibility (it won't include text hidden with `display: none`) but forces a reflow to compute that, making it the slowest of the three. One more trap worth knowing: `innerHTML +=` destroys and rebuilds every child node from scratch, which silently kills any event listeners already attached to them, even ones on children you didn't intend to touch.

## Events: capturing, target, bubbling

The event flow has three phases: capturing (top of the tree down to the target), then the target itself, then bubbling (target back up to the top). Regular listeners run during the bubbling phase by default; pass `{ capture: true }` to run during capturing instead. `e.target` is the actual element that was clicked; `e.currentTarget` is the element the listener is attached to, and they're often different once you're delegating.

`stopPropagation()` halts further bubbling or capturing. `stopImmediatePropagation()` does that *and* stops any other listeners on the same element from firing at all. `preventDefault()` cancels the browser's default action only, form submission, link navigation, and has nothing to do with propagation; the two are commonly confused but entirely unrelated. `{ once: true }` auto-removes a listener after it fires once. `removeEventListener` only works when passed the exact same function reference given to `addEventListener`, an anonymous inline arrow function can never be removed later. `{ passive: true }` is a promise to the browser that the listener won't call `preventDefault()`, which lets it start scrolling immediately instead of waiting to find out; calling `preventDefault()` anyway inside a passive listener is silently ignored.

### Event delegation

Put one listener on a parent instead of one on every child, and use `e.target.closest(selector)` inside it to find whichever descendant actually triggered the event:

```js
document.querySelectorAll('.box').forEach(box => {
  box.addEventListener('click', (e) => {
    console.log(e.currentTarget.dataset.id);
  });
});
```

That specific example attaches a listener per box up front. Delegation's real advantage shows up for elements that don't exist yet at setup time: attach one listener to a stable ancestor, use `closest()` inside it, and it works for children added to the DOM later, since bubbling doesn't care when an element was created, only that it exists in the tree when the click happens. The one trap: if a child's own listener calls `stopPropagation()`, the event never reaches a delegated parent listener at all, and the parent's logic silently never runs.

You aren't limited to built-in event types. `new CustomEvent('name', { detail, bubbles: true })` plus `dispatchEvent()` lets any part of the app announce something happened, with its own payload in `detail`, and, with `bubbles: true`, lets it be caught via delegation exactly like a native click.

## Shadow DOM: a subtree the rest of the page can't see into

A Shadow DOM is an encapsulated subtree attached to an element, with its own scoped styles and markup, the mechanism behind Web Components (and behind native elements like `<video>`'s built-in controls, which are themselves shadow trees). Styles defined inside a shadow root don't leak out to the rest of the page, and page-level styles don't leak in, which is what makes a Web Component genuinely drop-in safe to reuse: no class-name collision is possible, because the shadow boundary isn't just a naming convention, it's an actual DOM isolation barrier.

## DOMContentLoaded versus window.onload

`DOMContentLoaded` fires once the HTML has been parsed and the DOM tree is ready, before images, stylesheets, and other subresources have necessarily finished loading. `window.onload` (or `window.addEventListener('load', ...)`) waits for everything on the page, images and CSS included, to finish loading too. Reach for `DOMContentLoaded` when a script only needs to query or manipulate the DOM structure itself; reach for `load` when it genuinely depends on a resource, measuring a loaded image's natural dimensions, for instance.

## Watching visibility without a scroll listener

The old way to detect "has this element entered the viewport" combined a `scroll` event listener with `getBoundingClientRect()`. Scroll events fire constantly, and `getBoundingClientRect()` forces a layout reflow every time it's called, a direct instance of the layout-thrashing pattern from the rendering-performance lesson, just triggered by a library instead of a hand-written loop.

**Intersection Observer** replaces that entirely. It runs asynchronously, off the main thread's critical path, and only fires when an element's visibility actually changes.

```js
const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) console.log('Element visible:', entry.target);
  });
}, {
  root: null,        // the viewport, by default
  rootMargin: '0px',  // grows or shrinks the root's box for triggering purposes
  threshold: 0.5,      // fraction of the target that must be visible to fire
});

observer.observe(document.querySelector('.box'));
```

`rootMargin: '100px'` triggers the callback *before* an element is actually visible, useful for preloading a little ahead of the scroll position. `threshold` can be a single number or an array like `[0, 0.5, 1]` to fire at several visibility steps, handy for scroll-depth analytics. One observer instance can watch multiple elements at once; `entries` in the callback tells you which one fired, via `entry.target`. Beyond `isIntersecting` and `target`, each entry also carries `intersectionRatio` (exactly what percentage of the target is currently visible) and `boundingClientRect`/`rootBounds` (the raw geometry of the target and the root, for anything needing the actual pixel rect rather than just a boolean or a ratio).

Beyond infinite scroll and lazy-loaded images, the same primitive covers scroll-triggered animations (add a CSS class the instant an element enters view), ad viewability tracking (the industry-standard definition of a "viewable" impression is 50% visible for at least one continuous second, which `threshold` plus a bit of timing logic measures directly), and active nav highlighting (observe every section on the page and highlight whichever one's entry currently reports the highest `isIntersecting`/`intersectionRatio`).

```jsx
function LazyImage({ src, alt }) {
  const imgRef = useRef(null);
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true);
          observer.disconnect();
        }
      },
      { threshold: 0.1 },
    );
    if (imgRef.current) observer.observe(imgRef.current);
    return () => observer.disconnect();
  }, []);

  return <img ref={imgRef} src={isVisible ? src : undefined} alt={alt} />;
}
```

Trace it: the `<img>` renders with no `src` at all on mount, since `isVisible` starts `false`. The effect attaches an observer to the real DOM node via `imgRef.current`, and nothing loads until the image scrolls within 10% visibility, at which point `setIsVisible(true)` triggers a re-render that finally sets `src`, and `observer.disconnect()` stops watching, since a one-time lazy load has no reason to keep firing. If the component unmounts before that ever happens, the cleanup function disconnects the observer anyway, so nothing leaks.

## The pattern this API makes possible: infinite scroll

An invisible "sentinel" element sits at the very end of a list. An observer watches it, and when it becomes visible, the user has scrolled to the bottom, so the code fetches the next page and appends it.

```jsx
function InfiniteList() {
  const [items, setItems] = useState([]);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const sentinelRef = useRef(null);

  const fetchMore = useCallback(async () => {
    if (loading || !hasMore) return; // guard against double-fetch or fetching past the end
    setLoading(true);
    const res = await fetch(`/api/items?page=${page}`);
    const newItems = await res.json();
    if (newItems.length === 0) setHasMore(false);
    else {
      setItems(prev => [...prev, ...newItems]);
      setPage(prev => prev + 1);
    }
    setLoading(false);
  }, [page, loading, hasMore]);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => { if (entries[0].isIntersecting) fetchMore(); },
      { threshold: 1.0 },
    );
    const current = sentinelRef.current;
    if (current) observer.observe(current);
    return () => { if (current) observer.unobserve(current); };
  }, [fetchMore]);

  return (
    <div>
      {items.map(item => <div key={item.id}>{item.name}</div>)}
      <div ref={sentinelRef}>{loading && "Loading more..."}</div>
    </div>
  );
}
```

The `loading`/`hasMore` guard at the top of `fetchMore` matters as much as the observer itself: without it, a sentinel that's still visible while a request is in flight would fire the fetch again immediately on the next intersection check, and a sentinel for a list that's already exhausted would keep trying forever. For a genuinely large list on top of infinite scroll, pair this with virtualization, covered later in this course, since fetching more pages is a separate problem from rendering all of them at once.

## Performance and cleanup, in one place

Cost ranking, most to least expensive: **Reflow** (a full layout recalculation), **Repaint** (pixels only, no layout change), **Composite** (GPU only, `transform`/`opacity`), the same hierarchy from the rendering-pipeline lesson, now grounded in DOM APIs specifically. Debounce fires once after activity pauses, good for a search input; throttle fires at fixed intervals during continuous activity, good for scroll tracking, both covered in depth later in this course. `observer.unobserve(target)` stops watching one element; `observer.disconnect()` stops watching everything, and forgetting either inside a `useEffect` cleanup function is how an Intersection Observer quietly leaks.
