---
kind: lesson
id_key: interview-prep-45/day-28-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Animation"
position: 31
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---

Animation questions test the same rendering-pipeline knowledge from earlier in this course applied to a concrete deliverable: build something that moves smoothly, explain why it's smooth, and know when JavaScript is actually necessary versus CSS alone. Today covers CSS vs. JS animation, Framer Motion, gesture animations, and the performance and accessibility rules that separate a working demo from production-ready motion.

## CSS animations vs. JS animations

CSS transitions and animations run largely on the browser's compositor thread when restricted to `transform`/`opacity`, independent of the main JS thread. That means they keep running smoothly even while JavaScript is busy elsewhere, such as during a heavy computation or a slow re-render. JS-driven animation (via `requestAnimationFrame` or a library) runs on the main thread instead, and is therefore vulnerable to jank from anything else competing for that thread.

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

**When you need JavaScript:** animations that must interrupt or reverse based on user input mid-flight (drag gestures), animations sequenced or orchestrated across multiple elements with dynamic timing, physics-based motion (spring easing that reacts to velocity), or anything that needs to read live layout measurements (FLIP-style shared element transitions).

## Framer Motion basics

Framer Motion (now branded **Motion** for React) is the standard JS animation library in the React ecosystem. It wraps DOM elements with a declarative API while still animating `transform`/`opacity` under the hood wherever possible, giving you JS-level control without giving up compositor performance for the properties that support it.

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

`initial` is the starting state, `animate` is the target state Motion tweens toward on mount (and whenever the values change), and `transition` controls timing and easing. Swapping `duration`-based easing for a spring is one prop change:

```tsx
<motion.div
  initial={{ scale: 0.8, opacity: 0 }}
  animate={{ scale: 1, opacity: 1 }}
  transition={{ type: "spring", stiffness: 300, damping: 20 }}
>
  Content
</motion.div>
```

**Exit animations** need `AnimatePresence`, because React normally unmounts a component immediately. There's no window for an exit animation to play unless something delays the actual removal from the DOM until the animation finishes.

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

Trace what happens when `message` becomes `null`: React would normally remove the `motion.div` from the tree on the very next render. `AnimatePresence` intercepts that, keeps the element mounted just long enough to run the `exit` animation, and only lets React actually remove it once that animation completes. This "delay the unmount" mechanism is worth being able to explain precisely; it's a common interview follow-up.

## Complex gesture animations

Drag, pan, and hover gestures are where hand-rolling with raw `pointermove`/`pointerup` listeners gets tedious fast. This is Motion's strongest differentiator over plain CSS.

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

`useMotionValue`/`useTransform` are the key performance detail. Values driven through them update the DOM directly, via the compositor-friendly `transform`, without going through React's render cycle at all. Dragging this card doesn't re-render the component on every pixel of movement; only regular React state would do that.

```tsx
// Layout animations — Motion automatically computes a FLIP transition
// (First-Last-Invert-Play) when an element's layout position/size changes,
// e.g. a reordering list, without you calculating transforms manually
<motion.div layout transition={{ type: "spring" }}>
  {content}
</motion.div>
```

The `layout` prop is Framer Motion's implementation of the FLIP technique. It measures the element's position **F**irst, lets React re-render to the **L**ast position, **I**nverts the visual jump with a transform back to the original spot, then **P**lays a transition to zero. That makes a genuine layout change, like an item removed from a list causing others to shift up, animate smoothly using only compositor-friendly transforms instead of animating the actual `top`/`left` layout properties.

## Performance considerations

Animate `transform`/`opacity`, never `top`/`left`/`width`/`height`/`margin`. This is the same rule from rendering-performance day, applied here: layout-affecting properties force Style, Layout, Paint, and Composite on every frame, while `transform`/`opacity` can skip straight to Composite.

Set `will-change` immediately before the animation starts and remove it once it ends. Leaving it on permanently fragments the page into unnecessary GPU layers. Framer Motion manages this internally for elements it's actively animating.

Avoid animating too many elements simultaneously. Even compositor-only animations have a per-layer memory and GPU cost, so staggering large numbers of simultaneous animations (Motion's `staggerChildren`) both looks better and costs less than triggering hundreds of elements at once.

Debounce or throttle scroll-linked animations. `useScroll`-driven parallax effects that read scroll position on every frame should be paired with `useTransform`/`useSpring` (which Motion optimizes internally) rather than a naive `onScroll` handler calling `setState`, which would trigger a full React re-render per scroll event.

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

Motion is not accessibility-neutral. Vestibular disorders can make large, fast animations genuinely nauseating or disorienting for some users, and the platform gives you a documented way to respect that preference.

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

`useReducedMotion` reads the OS-level `prefers-reduced-motion` setting so you can conditionally shrink or remove motion, typically keeping opacity fades but dropping translation, scale, and parallax, rather than blanket-disabling all animation, which can make an interface feel broken rather than considerate. The correct default is that opacity-only transitions survive reduced-motion mode, while movement, scale, and parallax should not.

A second accessibility detail: animations that auto-play and loop indefinitely, such as background video or an infinite carousel, need a visible pause control per WCAG 2.2.2. Motion the user can't stop is a genuine accessibility failure, not just a preference.

## Library comparison

| Library | Best for | Trade-off |
|---|---|---|
| CSS transitions/animations | Simple, fixed-state transitions (hover, fade, spinner) | No mid-animation interruption, no physics, no gesture support |
| Framer Motion (Motion) | Gesture-driven UI, layout transitions, orchestrated sequences, React-idiomatic API | Adds a dependency and bundle weight; overkill for simple hover effects |
| React Spring | Physics-based spring animation with a lower-level, more flexible API | Steeper learning curve than Motion's declarative props |
| GSAP | Complex timeline-based sequencing, SVG morphing, scroll-triggered animation, framework-agnostic | Imperative API doesn't compose as naturally with React's declarative model; commercial license for some plugins |
| Web Animations API (native) | Direct browser API, no dependency, good for one-off imperative animations | Verbose for anything beyond a single element's simple animation, no gesture/layout helpers |

The interview-ready framing: reach for CSS first, since it's the cheapest, most performant, and needs zero JS. Reach for Motion when you need gesture handling, layout animations, or state-driven orchestration that CSS structurally can't express. Know that GSAP and React Spring exist as the alternatives you'd consider for timeline-heavy or physics-heavy special cases.
