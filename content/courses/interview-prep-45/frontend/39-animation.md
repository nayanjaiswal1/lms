---
kind: lesson
id_key: interview-prep-45/day-28-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend Engineering"
section_position: 4
title: "Animation"
position: 39
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Animation questions apply the rendering-pipeline knowledge from earlier in this course to a concrete deliverable: build something that moves smoothly, explain why it's smooth, and know when JavaScript is actually necessary versus CSS alone. This lesson covers CSS versus JS animation, Framer Motion, gesture animations, and the performance and accessibility rules that separate a working demo from something production-ready.

## CSS versus JS: which thread does the work

CSS transitions and animations run largely on the browser's compositor thread when restricted to `transform`/`opacity`, independent of the main JS thread, so they keep running smoothly even while JavaScript is busy elsewhere, a heavy computation, a slow re-render. JS-driven animation, via `requestAnimationFrame` or a library, runs on the main thread instead, and is therefore vulnerable to exactly that kind of jank.

```css
/* Compositor-friendly, no JS needed */
.card { transform: scale(1); transition: transform 0.2s ease-out; }
.card:hover { transform: scale(1.05); }

@keyframes slideIn { from { transform: translateY(20px); opacity: 0; } to { transform: translateY(0); opacity: 1; } }
.toast { animation: slideIn 0.3s ease-out; }
```

CSS alone is enough for hover and focus states, simple enter/exit transitions, loading spinners, anything with a fixed, predetermined start and end state that doesn't need to respond to input mid-animation or coordinate with application state. JavaScript becomes necessary the moment an animation must interrupt or reverse based on user input mid-flight (a drag gesture), needs to be sequenced or orchestrated across multiple elements with dynamic timing, needs physics-based motion reacting to velocity, or needs to read live layout measurements, the FLIP technique covered further down.

## Framer Motion basics

Framer Motion, now branded Motion for React, is the standard JS animation library in the React ecosystem. It wraps DOM elements with a declarative API while still animating `transform`/`opacity` under the hood wherever it can, giving JS-level control without giving up compositor performance for the properties that support it.

```tsx
import { motion } from "framer-motion";
function FadeInCard({ children }: { children: React.ReactNode }) {
  return <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3, ease: "easeOut" }}>{children}</motion.div>;
}
```

`initial` is the starting state, `animate` is the target state Motion tweens toward on mount and on subsequent value changes, `transition` controls timing and easing. Swapping duration-based easing for a spring is one prop change: `transition={{ type: "spring", stiffness: 300, damping: 20 }}`.

**Exit animations** need `AnimatePresence`, since React normally unmounts a component immediately, leaving no window for an exit animation to play unless something explicitly delays the actual DOM removal.

```tsx
function Toast({ message, onDismiss }: { message: string | null; onDismiss: () => void }) {
  return (
    <AnimatePresence>
      {message && (
        <motion.div key={message} initial={{ opacity: 0, y: -10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -10 }} transition={{ duration: 0.2 }}>
          {message}<button onClick={onDismiss}>Dismiss</button>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
```

Trace what happens the instant `message` becomes `null`: React would normally remove the `motion.div` on the very next render. `AnimatePresence` intercepts that, keeps the element mounted just long enough to run the `exit` animation, and only lets React actually remove it once that animation finishes, a "delay the unmount" mechanism worth being able to explain precisely, it's a common follow-up question.

## Gesture animations

Drag, pan, and hover gestures are where hand-rolling with raw `pointermove`/`pointerup` listeners gets tedious fast, and it's Motion's strongest differentiator over plain CSS.

```tsx
function DraggableCard() {
  const x = useMotionValue(0);
  const rotate = useTransform(x, [-200, 200], [-15, 15]); // derived without triggering re-renders
  return (
    <motion.div drag="x" dragConstraints={{ left: -200, right: 200 }} dragElastic={0.2} style={{ x, rotate }}
      onDragEnd={(_, info) => { if (Math.abs(info.offset.x) > 150) console.log(info.offset.x > 0 ? "swiped right" : "swiped left"); }}>
      Swipe me
    </motion.div>
  );
}
```

`useMotionValue`/`useTransform` are the key performance detail here: values driven through them update the DOM directly, via the compositor-friendly `transform`, without going through React's render cycle at all. Dragging this card doesn't re-render the component on every pixel of movement, only regular React state would do that.

```tsx
// Motion computes a FLIP transition (First-Last-Invert-Play) automatically
// whenever an element's layout position or size changes, e.g. a reordering list
<motion.div layout transition={{ type: "spring" }}>{content}</motion.div>
```

The `layout` prop is Framer Motion's implementation of FLIP. It measures the element's position **F**irst, lets React re-render to the **L**ast position, **I**nverts the visual jump with a transform back to the original spot, then **P**lays a transition to zero. That's what lets a genuine layout change, an item removed causing others to shift up, animate smoothly using only compositor-friendly transforms, instead of animating the actual `top`/`left` layout properties.

## Performance rules, and they're the same ones from earlier in this course

Animate `transform`/`opacity`, never `top`/`left`/`width`/`height`/`margin`, the exact rule from the CSS rendering-performance lesson, applied here directly: a layout-affecting property forces Style, Layout, Paint, and Composite every frame, while `transform`/`opacity` can skip straight to Composite. Set `will-change` immediately before an animation starts and remove it once it ends, leaving it on permanently fragments the page into unnecessary GPU layers, and Motion manages this internally for elements it's actively animating. Avoid animating too many elements at once, even compositor-only animations carry a per-layer memory and GPU cost, so staggering (`staggerChildren`) both looks better and costs less than triggering hundreds of elements simultaneously.

```tsx
const container = { animate: { transition: { staggerChildren: 0.05 } } };
const item = { initial: { opacity: 0, y: 10 }, animate: { opacity: 1, y: 0 } };
function StaggeredList({ items }: { items: string[] }) {
  return <motion.ul variants={container} initial="initial" animate="animate">{items.map((text) => <motion.li key={text} variants={item}>{text}</motion.li>)}</motion.ul>;
}
```

Scroll-linked animations specifically need `useTransform`/`useSpring`, which Motion optimizes internally, rather than a naive `onScroll` handler calling `setState` on every scroll event, which would trigger a full React re-render per scroll tick.

## Motion isn't accessibility-neutral

Vestibular disorders can make large, fast animations genuinely nauseating or disorienting, and the platform gives a documented way to respect that.

```css
@media (prefers-reduced-motion: reduce) {
  * { animation-duration: 0.01ms !important; transition-duration: 0.01ms !important; }
}
```

```tsx
function FadeInCard({ children }: { children: React.ReactNode }) {
  const shouldReduceMotion = useReducedMotion();
  return <motion.div initial={{ opacity: 0, y: shouldReduceMotion ? 0 : 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: shouldReduceMotion ? 0 : 0.3 }}>{children}</motion.div>;
}
```

`useReducedMotion` reads the OS-level `prefers-reduced-motion` setting so motion can be conditionally shrunk, typically keeping opacity fades while dropping translation, scale, and parallax, rather than blanket-disabling all animation, which can make an interface feel broken rather than considerate. Opacity-only transitions are the correct default to preserve; movement, scale, and parallax are what should go. A second accessibility detail worth naming: anything that auto-plays and loops indefinitely, background video, an infinite carousel, needs a visible pause control under WCAG 2.2.2. Motion the user can't stop is a genuine accessibility failure, not merely a preference.

## Picking a tool

| Library | Best for | Trade-off |
|---|---|---|
| CSS transitions/animations | Simple, fixed-state transitions | No mid-animation interruption, no physics, no gestures |
| Framer Motion (Motion) | Gesture-driven UI, layout transitions, orchestrated sequences | Adds bundle weight, overkill for a simple hover effect |
| React Spring | Physics-based, lower-level, more flexible API | Steeper learning curve than Motion's declarative props |
| GSAP | Timeline sequencing, SVG morphing, scroll-triggered animation | Imperative API composes less naturally with React |
| Web Animations API (native) | One-off imperative animations, no dependency | Verbose past a single element's simple animation |

The interview-ready framing: reach for CSS first, it's the cheapest, most performant, and needs zero JS. Reach for Motion when gesture handling, layout animations, or state-driven orchestration are things CSS structurally can't express. Know that GSAP and React Spring exist as the alternatives worth naming for timeline-heavy or physics-heavy special cases, even if you wouldn't reach for them by default.
