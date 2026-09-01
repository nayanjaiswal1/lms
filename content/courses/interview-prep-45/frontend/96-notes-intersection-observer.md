---
kind: lesson
id_key: interview-prep-45/note-intersection-observer-api
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Notes: Intersection Observer API"
position: 96
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

A browser API to detect when an element enters or exits the viewport (or some other container), without expensive scroll listeners.

## Why it exists
The old way combined a `scroll` event with `getBoundingClientRect()`. That fires constantly, forces a layout reflow on every call, and causes jank. Intersection Observer instead runs asynchronously, off the main thread's critical path, which makes it cheaper.

## Basic Syntax

```js
const observer = new IntersectionObserver((entries, observer) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      console.log('Element visible:', entry.target);
    }
  });
}, {
  root: null,        // viewport by default
  rootMargin: '0px',  // grow/shrink root box
  threshold: 0.5       // % visible to trigger callback
});

observer.observe(document.querySelector('.box'));
```

## Key Options
| Option | Meaning |
|---|---|
| `root` | The ancestor used as the viewport. `null` means the browser viewport itself. |
| `rootMargin` | A CSS-like margin around the root. For example, `'100px'` triggers the callback before the element is actually visible, which is useful for preloading. |
| `threshold` | How much of the target must be visible to fire the callback. Either a single number or an array like `[0, 0.5, 1]` to fire at multiple visibility steps. |

## Entry Object
- `isIntersecting`: boolean, whether the target currently intersects the root.
- `intersectionRatio`: what percentage of the target is visible.
- `target`: the observed element.
- `boundingClientRect` / `rootBounds`: rect info for the target and the root.

## Common Use Cases
1. **Infinite scroll**: observe a sentinel div at the bottom of the list, and fetch the next page when it intersects.
2. **Lazy load images**: swap in the real `src` when the image nears the viewport, e.g. with `rootMargin: '200px'` to start loading before it's actually on screen.
3. **Scroll-triggered animations**: add a CSS class when an element enters view.
4. **Ad viewability tracking**: measure real visibility, e.g. 50% visible for 1 second, which is the industry standard for a "viewable" impression.
5. **Active nav highlighting**: detect which section is currently visible and highlight the matching nav item.

## Cleanup
```js
observer.unobserve(target); // stop watching one element
observer.disconnect();      // stop watching everything
```

## React Pattern

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
      { threshold: 0.1 }
    );
    if (imgRef.current) observer.observe(imgRef.current);
    return () => observer.disconnect();
  }, []);

  return <img ref={imgRef} src={isVisible ? src : undefined} alt={alt} />;
}
```
On mount, the `<img>` renders with no `src` at all, since `isVisible` starts `false`. The effect then creates an observer and attaches it to the actual DOM node via `imgRef.current`. Nothing loads until the user scrolls the image within 10% visibility (`threshold: 0.1`), at which point the callback fires, `setIsVisible(true)` triggers a re-render that finally sets `src`, and `observer.disconnect()` stops watching since a one-time lazy load doesn't need to keep firing. If the component unmounts before that ever happens, the cleanup function disconnects the observer anyway, so it doesn't leak.

## Interview Follow-ups

**Q: How would you implement infinite scroll with this?**
A: The sentinel div pattern: place an empty div at the bottom of the list, observe it, and fetch the next page when it intersects.

**Q: How does this compare to scroll plus `getBoundingClientRect`?**
A: It's asynchronous and doesn't force a layout reflow, so it performs better, especially with many observed elements.

**Q: What's the `threshold` array used for?**
A: Firing the callback at multiple visibility steps instead of just one, for example to track scroll-depth analytics at 25%, 50%, and 75% visible.

**Q: Can one observer watch multiple elements?**
A: Yes. The `entries` array passed to the callback tells you which element triggered it, via `entry.target`.
