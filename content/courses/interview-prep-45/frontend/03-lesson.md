---
kind: lesson
id_key: interview-prep-45/day-03-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Event Loop and Browser Rendering"
position: 6
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
"What's the output order?" questions involving `setTimeout`, `Promise.then`, and `async/await` show up in nearly every frontend interview loop, and they're really testing whether you understand the event loop, not JavaScript syntax. Pair that with how the browser turns JS + CSS into pixels, and you can answer both "explain the event loop" and "why is my animation janky" questions confidently.

## Task queue vs microtask queue

JavaScript is single-threaded: one call stack, one thing executing at a time. The event loop's job is deciding what runs next once the call stack empties.

There are two queues that matter most for interviews:

- **Microtask queue**: `Promise.then/catch/finally` callbacks, `queueMicrotask`, `async/await` continuations, `MutationObserver` callbacks.
- **Macrotask queue** (a.k.a. "task queue"): `setTimeout`, `setInterval`, I/O callbacks, UI events, `postMessage`.

The rule that answers 90% of ordering questions: **after each single macrotask finishes, the event loop drains the ENTIRE microtask queue before running the next macrotask**, including microtasks that were queued by other microtasks during that drain.

```tsx
console.log('1: sync');

setTimeout(() => console.log('2: macrotask (setTimeout)'), 0);

Promise.resolve().then(() => console.log('3: microtask (promise)'));

queueMicrotask(() => console.log('4: microtask (queueMicrotask)'));

console.log('5: sync');

// Output order: 1, 5, 3, 4, 2
// Sync code runs first (1, 5). Then the stack is empty, so ALL microtasks
// drain (3, 4) before the event loop even looks at the macrotask queue (2),
// regardless of the setTimeout delay being 0.
```

```tsx
async function asyncOrder() {
  console.log('A: start');
  await Promise.resolve();
  console.log('B: after await'); // this line is a microtask continuation
}

console.log('start');
asyncOrder();
console.log('end');

// Output: start, A: start, end, B: after await
// Everything before "await" in an async function runs SYNCHRONOUSLY.
// The code after "await" is scheduled as a microtask continuation —
// equivalent to Promise.resolve().then(() => { ...rest of function... }).
```

**Interview trap: nested `setTimeout(fn, 0)` chains never "catch up" to microtasks.** If a macrotask queues a new microtask, that microtask still drains completely before the *next* macrotask, even if the macrotask queue already had other items waiting. Microtasks always win the race against the next macrotask.

## requestAnimationFrame

`requestAnimationFrame` (rAF) is a third scheduling mechanism, separate from both queues above. Its callback runs **before the browser paints the next frame**, synced to the display's refresh rate (typically 60Hz → ~16.6ms per frame). It is the correct primitive for anything that changes the screen every frame (animations, canvas drawing, scroll-linked effects) because it never schedules work faster than the browser can actually paint, unlike `setInterval`.

```tsx
function animate(element: HTMLElement) {
  let start: number | null = null;

  function step(timestamp: number) {
    if (start === null) start = timestamp;
    const elapsed = timestamp - start;
    const progress = Math.min(elapsed / 1000, 1); // 1 second animation

    element.style.transform = `translateX(${progress * 200}px)`;

    if (progress < 1) {
      requestAnimationFrame(step); // schedule next frame; browser paints between calls
    }
  }

  requestAnimationFrame(step);
}
```

Ordering relative to the other queues, per frame: macrotask/microtasks drain first (whatever triggered this frame), then `requestAnimationFrame` callbacks run, then the browser recalculates style/layout/paint/composite, then it presents the frame. `requestIdleCallback` runs after all of that, only if there's leftover time before the next frame, good for genuinely low-priority work like analytics beacons.

## Layout and paint phases

This is the "browser rendering pipeline," and it directly explains why some CSS properties are cheap to animate and others tank frame rate.

```
JavaScript → Style → Layout → Paint → Composite
```

1. **JavaScript**: your code runs, may mutate the DOM or `style` properties.
2. **Style (recalculate style)**: browser figures out which CSS rules apply to which elements ("computed style").
3. **Layout (a.k.a. reflow)**: browser computes the geometry, the exact size and position of every element. Expensive, and it cascades: changing one element's size can shift everything after it.
4. **Paint**: browser fills in pixels (text, colors, borders, shadows) onto layers (rasterization).
5. **Composite**: browser combines the painted layers into the final image shown on screen, applying transforms.

The cost model: changing `width`, `height`, `top`, `left`, `margin`, or adding/removing DOM nodes triggers **layout → paint → composite** (the expensive full pipeline). Changing `color` or `background` (without a shape change) skips layout but still triggers **paint → composite**. Changing `transform` or `opacity` only triggers **composite**, with no layout and no paint, because those properties can be applied purely on the GPU compositor thread. This is why Day 11's "composite-only properties" advice (animate `transform`, not `top`/`left`) exists.

```tsx
// Cheap: composite-only, handled by the GPU compositor thread
element.style.transform = 'translateX(100px)';
element.style.opacity = '0.5';

// Expensive: forces full layout recalculation, then paint, then composite
element.style.left = '100px';
element.style.width = '300px';
```

**Layout thrashing** happens when you interleave reads and writes to layout-dependent properties in a loop, forcing the browser to synchronously recompute layout on every read because a prior write invalidated its cache:

```tsx
// BAD: forces a synchronous layout recalculation on every iteration
elements.forEach(el => {
  el.style.width = el.offsetWidth + 10 + 'px'; // read (offsetWidth) then write (width), repeated
});

// GOOD: batch all reads, then all writes — one layout recalculation total
const widths = elements.map(el => el.offsetWidth); // all reads first
elements.forEach((el, i) => {
  el.style.width = widths[i] + 10 + 'px'; // all writes after
});
```
