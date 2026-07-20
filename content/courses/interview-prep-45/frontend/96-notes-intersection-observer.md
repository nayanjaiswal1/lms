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

Browser API to detect when an element enters/exits the viewport (or a container) — without expensive scroll listeners.

## Why it exists
- Old way: `scroll` event + `getBoundingClientRect()` → fires constantly, forces layout reflow, causes jank.
- Intersection Observer runs async, off the main thread's critical path → cheaper.

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
| `root` | ancestor used as viewport (`null` = browser viewport) |
| `rootMargin` | CSS-like margin around root (e.g. `'100px'` = trigger early, good for preloading) |
| `threshold` | % visibility needed to fire callback — number or array `[0, 0.5, 1]` |

## Entry Object
- `isIntersecting` — boolean
- `intersectionRatio` — % visible
- `target` — observed element
- `boundingClientRect` / `rootBounds` — rect info

## Common Use Cases
1. **Infinite scroll** — observe sentinel div at list bottom, fetch next page on intersect
2. **Lazy load images** — swap `src` when near viewport (`rootMargin: '200px'`)
3. **Scroll-triggered animations** — add class when element enters view
4. **Ad viewability tracking** — measure real visibility (e.g. 50% for 1s)
5. **Active nav highlighting** — detect visible section, highlight matching nav item

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

## Interview Follow-ups
- How would you implement infinite scroll with this? → sentinel div pattern
- Vs scroll + getBoundingClientRect? → perf, async, no reflow
- What's `threshold` array used for? → firing at multiple visibility steps (e.g. scroll-depth analytics)
- Can one observer watch multiple elements? → yes, `entries` array tells you which one triggered
