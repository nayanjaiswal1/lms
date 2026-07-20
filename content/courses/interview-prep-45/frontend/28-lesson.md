---
kind: lesson
id_key: interview-prep-45/day-28-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Day 28 — Animation"
position: 31
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---

Animation questions test the same rendering-pipeline knowledge from earlier in this course applied to a concrete deliverable: build something that moves smoothly, explain why it's smooth, and know when JavaScript is actually necessary versus CSS alone. Today covers CSS vs. JS animation, Framer Motion, gesture animations, and the performance/accessibility rules that separate a working demo from production-ready motion.

## CSS animations vs. JS animations

CSS transitions/animations run largely on the browser's compositor thread when restricted to `transform`/`opacity`, independent of the main JS thread — which means they keep running smoothly even while JavaScript is busy elsewhere (a heavy computation, a slow re-render). JS-driven animation (via `requestAnimationFrame` or a library) runs on the main thread and is therefore vulnerable to jank from anything else competing for that thread.

```css
/* CSS transition — declarative, compositor-friendly, no JS needed */
.card {
  transform: scale(1);
  transition: transform 0.2s ease-out;
}
.card:hover {
  transform: scale(1.05);
}

/* CSS keyframe animation — for anything beyond a two-state transition */
@keyframes slideIn {
  from { transform: translateY(20px); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}
.toast {
  animation: slideIn 0.3s ease-out;
}
```

**When CSS alone is enough:** hover/focus states, simple enter/exit transitions, loading spinners, anything with a fixed, predetermined start and end state that doesn't need to respond to user input mid-animation or coordinate with application state.

**When you need JavaScript:** animations that must interrupt/reverse based on user input mid-flight (drag gestures), animations sequenced or orchestrated across multiple elements with dynamic timing, physics-based motion (spring easing that reacts to velocity), or anything that needs to read live layout measurements (FLIP-style shared element transitions).

## Framer Motion basics

Framer Motion (now branded **Motion** for React) is the standard JS animation library in the React ecosystem — it wraps DOM elements with a declarative API while still animating `transform`/`opacity` under the hood wherever possible, giving you JS-level control without giving up compositor performance for the properties that support it.

```bash
npm install framer-motion
```

```tsx
import { motion } from "framer-motion";

function FadeInCard({ children }: { children: React.ReactNode }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.3, ease: "easeOut" }}
    >
      {children}
    </motion.div>
  );
}
```

`initial` is the starting state, `animate` is the target state Motion tweens toward on mount (and whenever the values change), `transition` controls timing/easing. Swapping `duration`-based easing for a spring is one prop change:

```tsx
<motion.div
  initial={{ scale: 0.8, opacity: 0 }}
  animate={{ scale: 1, opacity: 1 }}
  transition={{ type: "spring", stiffness: 300, damping: 20 }}
>
  Content
</motion.div>
```

**Exit animations** need `AnimatePresence`, because React normally unmounts a component immediately — there's no window for an exit animation to play unless something delays the actual removal from the DOM until the animation finishes.

```tsx
import { AnimatePresence, motion } from "framer-motion";

function Toast({ message, onDismiss }: { message: string | null; onDismiss: () => void }) {
  return (
    <AnimatePresence>
      {message && (
        <motion.div
          key={message} // AnimatePresence needs a stable key to detect add/remove
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -10 }}
          transition={{ duration: 0.2 }}
        >
          {message}
          <button onClick={onDismiss}>Dismiss</button>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
```

`AnimatePresence` intercepts the unmount, keeps the element in the DOM just long enough to run the `exit` animation, and only removes it once that animation completes — this "delay the unmount" mechanism is worth being able to explain precisely, it's a common interview follow-up.

## Complex gesture animations

Drag, pan, and hover gestures are where hand-rolling with raw `pointermove`/`pointerup` listeners gets tedious fast — this is Motion's strongest differentiator over plain CSS.

```tsx
import { motion, useMotionValue, useTransform } from "framer-motion";

function DraggableCard() {
  const x = useMotionValue(0);
  // Derive rotation and opacity from drag distance without triggering re-renders —
  // useTransform subscribes to x's changes and updates the DOM directly.
  const rotate = useTransform(x, [-200, 200], [-15, 15]);
  const opacity = useTransform(x, [-200, 0, 200], [0.5, 1, 0.5]);

  return (
    <motion.div
      drag="x"
      dragConstraints={{ left: -200, right: 200 }}
      dragElastic={0.2}
      style={{ x, rotate, opacity }}
      onDragEnd={(_, info) => {
        if (Math.abs(info.offset.x) > 150) {
          console.log(info.offset.x > 0 ? "swiped right" : "swiped left");
        }
      }}
    >
      Swipe me
    </motion.div>
  );
}
```

`useMotionValue`/`useTransform` are the key performance detail: values driven through them update the DOM directly (via the compositor-friendly `transform`) without going through React's render cycle at all — dragging a card doesn't re-render the component on every pixel of movement, only regular React state would.

```tsx
// Layout animations — Motion automatically computes a FLIP transition
// (First-Last-Invert-Play) when an element's layout position/size changes,
// e.g. a reordering list, without you calculating transforms manually
<motion.div layout transition={{ type: "spring" }}>
  {content}
</motion.div>
```

The `layout` prop is Framer Motion's implementation of the FLIP technique: it measures the element's position **F**irst, lets React re-render to the **L**ast position, **I**nverts the visual jump with a transform back to the original spot, then **P**lays a transition to zero, making a genuine layout change (e.g., an item removed from a list, causing others to shift up) animate smoothly using only compositor-friendly transforms instead of animating the actual `top`/`left` layout properties.

## Performance considerations

- **Animate `transform`/`opacity`, never `top`/`left`/`width`/`height`/`margin`.** This is the same rule from rendering-performance day, applied here: layout-affecting properties force Style → Layout → Paint → Composite on every frame; `transform`/`opacity` can skip straight to Composite.
- **`will-change` before, remove after** — same rule as before: set it immediately before the animation starts, remove it once it ends, don't leave it on permanently or you fragment the page into unnecessary GPU layers. Framer Motion manages this internally for elements it's actively animating.
- **Avoid animating too many elements simultaneously** — even compositor-only animations have a per-layer memory/GPU cost; staggering large numbers of simultaneous animations (Motion's `staggerChildren`) both looks better and costs less than triggering hundreds of elements at once.
- **Debounce/throttle scroll-linked animations.** `useScroll`-driven parallax effects that read scroll position on every frame should be paired with `useTransform`/`useSpring` (which Motion optimizes internally) rather than a naive `onScroll` handler calling `setState`, which would trigger a full React re-render per scroll event.

```tsx
// Stagger children — visually clearer and cheaper than animating
// all list items at the exact same instant
const container = {
  animate: { transition: { staggerChildren: 0.05 } },
};
const item = {
  initial: { opacity: 0, y: 10 },
  animate: { opacity: 1, y: 0 },
};

function StaggeredList({ items }: { items: string[] }) {
  return (
    <motion.ul variants={container} initial="initial" animate="animate">
      {items.map((text) => (
        <motion.li key={text} variants={item}>{text}</motion.li>
      ))}
    </motion.ul>
  );
}
```

## Accessibility concerns

Motion is not accessibility-neutral — vestibular disorders can make large, fast animations genuinely nauseating or disorienting for some users, and the platform gives you a documented way to respect that preference.

```css
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

```tsx
import { useReducedMotion } from "framer-motion";

function FadeInCard({ children }: { children: React.ReactNode }) {
  const shouldReduceMotion = useReducedMotion();

  return (
    <motion.div
      initial={{ opacity: 0, y: shouldReduceMotion ? 0 : 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: shouldReduceMotion ? 0 : 0.3 }}
    >
      {children}
    </motion.div>
  );
}
```

`useReducedMotion` reads the OS-level `prefers-reduced-motion` setting so you can conditionally shrink or remove motion (typically keeping opacity fades but dropping translation/scale/parallax) rather than blanket-disabling all animation, which can make an interface feel broken rather than considerate. The correct default: opacity-only transitions survive reduced-motion mode; movement, scale, and parallax should not.

A second accessibility detail: **animations that auto-play and loop indefinitely** (background video, an infinite carousel) need a visible pause control per WCAG 2.2.2 — motion the user can't stop is a genuine accessibility failure, not just a preference.

## Library comparison

| Library | Best for | Trade-off |
|---|---|---|
| CSS transitions/animations | Simple, fixed-state transitions (hover, fade, spinner) | No mid-animation interruption, no physics, no gesture support |
| Framer Motion (Motion) | Gesture-driven UI, layout transitions, orchestrated sequences, React-idiomatic API | Adds a dependency and bundle weight; overkill for simple hover effects |
| React Spring | Physics-based spring animation with a lower-level, more flexible API | Steeper learning curve than Motion's declarative props |
| GSAP | Complex timeline-based sequencing, SVG morphing, scroll-triggered animation, framework-agnostic | Imperative API doesn't compose as naturally with React's declarative model; commercial license for some plugins |
| Web Animations API (native) | Direct browser API, no dependency, good for one-off imperative animations | Verbose for anything beyond a single element's simple animation, no gesture/layout helpers |

The interview-ready framing: reach for CSS first (cheapest, most performant, zero JS), reach for Motion when you need gesture handling, layout animations, or state-driven orchestration that CSS structurally can't express, and know GSAP/React Spring exist as the alternatives you'd consider for timeline-heavy or physics-heavy special cases.

## Key takeaways

- CSS animations restricted to `transform`/`opacity` run on the compositor thread and stay smooth even when the main JS thread is busy — use CSS for any animation with fixed start/end states.
- Reach for JavaScript (Framer Motion) specifically when you need mid-flight interruption, gesture handling, physics, or layout-change orchestration — not as a default over CSS.
- `AnimatePresence` delays React's unmount just long enough to run an `exit` animation — components normally have no window to animate out otherwise.
- `useMotionValue`/`useTransform` update the DOM directly without going through React's render cycle, which is why drag interactions don't re-render on every pixel of movement.
- The `layout` prop implements FLIP (First-Last-Invert-Play) automatically, animating real layout changes using only compositor-friendly transforms.
- Respect `prefers-reduced-motion` via `useReducedMotion`/the media query — keep opacity fades, drop translation/scale/parallax; auto-playing looped animations need a pause control per WCAG.

## Today's checklist

- [ ] Read: CSS animations vs JS animations
- [ ] Implement: Framer Motion animations
- [ ] Implement: Complex gesture animations
- [ ] Understand performance considerations (transform/opacity, will-change, FLIP)
- [ ] Understand accessibility concerns (`prefers-reduced-motion`, pause controls)
- [ ] Compare CSS, Framer Motion, React Spring, and GSAP trade-offs
