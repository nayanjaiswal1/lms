---
kind: lesson
id_key: interview-prep-45/day-03-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "The Event Loop and Browser Rendering Pipeline"
position: 10
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
"What's the output order?" questions involving `setTimeout`, `Promise.then`, and `async/await` show up in nearly every frontend interview loop, and they are really testing whether you understand the event loop, not JavaScript syntax. The Promises lesson traced one example of this; this lesson generalizes the rule, then covers how the browser turns JS and CSS into actual pixels, so you can answer both "explain the event loop" and "why is my animation janky" with the same underlying model.

## Two queues, and one rule that resolves almost everything

JavaScript is single-threaded: one call stack, one thing executing at a time. The event loop's job is deciding what runs next once that stack empties.

- **Microtask queue**: `Promise.then/catch/finally` callbacks, `queueMicrotask`, `async/await` continuations, `MutationObserver` callbacks.
- **Macrotask queue**: `setTimeout`, `setInterval`, I/O callbacks, UI events, `postMessage`.

The rule that answers almost every ordering question you will be asked: **after each single macrotask finishes, the event loop drains the entire microtask queue before running the next macrotask**, including microtasks that were queued by other microtasks during that same drain.

```tsx
console.log('1: sync');
setTimeout(() => console.log('2: macrotask'), 0);
Promise.resolve().then(() => console.log('3: microtask'));
queueMicrotask(() => console.log('4: microtask'));
console.log('5: sync');

// Output: 1, 5, 3, 4, 2
```

Sync code runs first, in order (`1`, `5`). Once the stack is empty, *every* queued microtask drains (`3`, `4`) before the event loop even looks at the macrotask queue (`2`), regardless of the `setTimeout` delay being `0`. A nested `setTimeout(fn, 0)` chain never "catches up" to microtasks for the same reason: if a macrotask queues a new microtask, that microtask still drains completely before the *next* macrotask runs, even if the macrotask queue already had other work waiting. Microtasks always win the race against whatever macrotask comes next.

> **Remember:** microtasks always fully drain between one macrotask and the next. A `setTimeout` delay of `0` never changes that order.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-eventloop-q1", "type": "mcq",
      "prompt": "`setTimeout(() => console.log('timeout'), 0); Promise.resolve().then(() => console.log('promise'));` Which logs first?",
      "options": [
        {"id":"a","text":"'timeout', since it was scheduled first"},
        {"id":"b","text":"'promise', because the entire microtask queue drains before the event loop runs the next macrotask, regardless of the timeout's delay"},
        {"id":"c","text":"They log at the same time"},
        {"id":"d","text":"It depends on which browser is running the code"}
      ],
      "correct": "b",
      "explanation": "Promise callbacks are microtasks; setTimeout callbacks are macrotasks. The full microtask queue always drains before the next macrotask runs, no matter what delay the timeout was given." }
] }
```

## requestAnimationFrame is a third lane

`requestAnimationFrame` (rAF) is not part of either queue above. Its callback runs right before the browser paints the next frame, synced to the display's refresh rate, typically 60Hz, about 16.6ms per frame. It is the right primitive for anything that changes the screen every frame, animation, canvas drawing, scroll-linked effects, because it never schedules work faster than the browser can actually paint, which `setInterval` has no way to guarantee.

```tsx
function animate(element: HTMLElement) {
  let start: number | null = null;
  function step(timestamp: number) {
    if (start === null) start = timestamp;
    const progress = Math.min((timestamp - start) / 1000, 1);
    element.style.transform = `translateX(${progress * 200}px)`;
    if (progress < 1) requestAnimationFrame(step);
  }
  requestAnimationFrame(step);
}
```

Per frame, the order is: whatever macrotask or microtasks triggered this frame drain first, then `requestAnimationFrame` callbacks run, then the browser recalculates style, layout, paint, and composite, then it presents the frame. `requestIdleCallback` runs after all of that, and only if there is leftover time before the next frame is due, the right spot for genuinely low-priority work like an analytics beacon.

> **Remember:** `requestAnimationFrame` runs right before the next paint. It is the correct tool for anything that must change every frame, never `setInterval`.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-raf-q1", "type": "mcq",
      "prompt": "Why is `requestAnimationFrame` a better choice than `setInterval(fn, 16)` for a smooth animation?",
      "options": [
        {"id":"a","text":"setInterval doesn't exist in modern browsers"},
        {"id":"b","text":"requestAnimationFrame is synced to the display's actual refresh rate and runs right before a real paint, while setInterval fires on a fixed clock that can drift out of sync with painting"},
        {"id":"c","text":"requestAnimationFrame runs on a separate thread"},
        {"id":"d","text":"There's no meaningful difference"}
      ],
      "correct": "b",
      "explanation": "requestAnimationFrame callbacks are scheduled to run right before the browser's next paint, matching the display refresh rate. setInterval has no awareness of painting at all and can easily schedule work the browser can't use in time." }
] }
```

## From a style change to pixels: the render pipeline

```
JavaScript → Style → Layout → Paint → Composite
```

Your code runs and mutates the DOM or `style` properties. The browser recalculates which CSS rules apply to which elements (**Style**). It computes exact geometry, size and position, for every affected element (**Layout**, also called reflow, and it cascades: one element's size changing can shift everything after it). It fills in pixels onto layers (**Paint**). Then it combines those painted layers into the final image, applying transforms on the GPU (**Composite**).

The cost model that follows directly from this: changing `width`, `height`, `top`, `left`, or `margin` forces layout, then paint, then composite, the full expensive pipeline. Changing `color` or `background` skips layout but still triggers paint and composite. Changing `transform` or `opacity` triggers composite only, no layout, no paint, because both can be applied purely on the GPU's compositor thread.

```tsx
// Cheap: composite-only
element.style.transform = 'translateX(100px)';
element.style.opacity = '0.5';

// Expensive: forces the full layout → paint → composite pipeline
element.style.left = '100px';
element.style.width = '300px';
```

> **Remember:** layout cascades. One element resizing can shift the geometry of everything positioned after it, which is exactly why layout is the expensive stage to trigger repeatedly.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-js-pipeline-q1", "type": "mcq",
      "prompt": "Setting `element.style.background = 'red'` triggers which pipeline stages?",
      "options": [
        {"id":"a","text":"Layout, Paint, and Composite, the full pipeline"},
        {"id":"b","text":"Paint and Composite only, since background doesn't affect geometry"},
        {"id":"c","text":"Composite only, like transform"},
        {"id":"d","text":"None, background changes are free"}
      ],
      "correct": "b",
      "explanation": "background changes what gets drawn, not where anything sits, so layout is skipped, but the browser still has to repaint the affected pixels and recomposite the layers." }
] }
```

## Layout thrashing, one more time, from the JS side

Interleaving reads and writes of layout-dependent properties inside a loop forces the browser to synchronously recompute layout on every single iteration, because each write invalidates the layout cache the very next read has to rebuild.

```tsx
// Bad: forces a synchronous layout recalculation on every iteration
elements.forEach(el => {
  el.style.width = el.offsetWidth + 10 + 'px'; // read, then write, repeated
});

// Good: batch all reads, then all writes — one layout recalculation total
const widths = elements.map(el => el.offsetWidth);
elements.forEach((el, i) => { el.style.width = widths[i] + 10 + 'px'; });
```

The fix, batch every read before any write, is sometimes called the "FastDOM" pattern, worth being able to name specifically because it is the same underlying discipline the CSS rendering-performance lesson covers from the stylesheet side: know which properties force layout, and don't ask for that answer more often than the frame budget can afford.

> **Remember:** batch reads, then batch writes. Interleaving them is what turns one cheap layout pass into one per loop iteration.
