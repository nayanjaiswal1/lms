---
kind: lesson
id_key: interview-prep-45/day-28-frontend
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "Animation"
position: 36
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---
Animation questions put the rendering-pipeline knowledge from earlier in this course to a concrete test: build something that moves smoothly, explain why it's smooth, and know exactly when JavaScript is actually needed versus CSS alone.

## CSS versus JS: which thread does the work

CSS transitions and animations run mostly on the browser's compositor thread when they're limited to `transform`/`opacity`, separate from the main JavaScript thread, so they keep running smoothly even while JS is busy doing something else, a heavy computation, a slow re-render. JS-driven animation, through `requestAnimationFrame` or a library, runs on the main thread instead, and is vulnerable to exactly that kind of stutter.

```css
/* Compositor-friendly, no JS needed */
.card { transform: scale(1); transition: transform 0.2s ease-out; }
.card:hover { transform: scale(1.05); }

@keyframes slideIn { from { transform: translateY(20px); opacity: 0; } to { transform: translateY(0); opacity: 1; } }
.toast { animation: slideIn 0.3s ease-out; }
```

CSS alone is enough for hover and focus states, simple enter and exit transitions, loading spinners, anything with a fixed, known start and end that doesn't need to respond to input mid-animation. JavaScript becomes necessary the moment an animation must interrupt or reverse based on input mid-flight (a drag gesture), needs sequencing across several elements with dynamic timing, needs physics-based motion that reacts to velocity, or needs to read live layout measurements, covered further down.

> **Remember:** `transform`/`opacity` can run on the compositor thread and stay smooth even when the main thread is busy. Nearly every other animatable property can't.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-animation-thread-q1", "type": "mcq",
      "prompt": "Why do CSS animations limited to transform and opacity stay smooth even while a heavy JavaScript computation is running on the main thread?",
      "options": [
        {"id":"a","text":"CSS animations pause automatically during heavy computation"},
        {"id":"b","text":"transform and opacity can be handled entirely by the browser's compositor thread, separate from the main thread the JavaScript is running on"},
        {"id":"c","text":"CSS always runs faster than JavaScript"},
        {"id":"d","text":"They don't actually stay smooth, this is a myth"}
      ],
      "correct": "b",
      "explanation": "The compositor thread is independent of the main thread. An animation restricted to transform/opacity can run there without ever waiting on whatever the main thread is busy doing." }
] }
```

## Framer Motion basics

Framer Motion, now branded Motion for React, is the standard JavaScript animation library in the React ecosystem. It wraps DOM elements in a declarative API while still animating `transform`/`opacity` under the hood wherever it can, giving you JS-level control without giving up compositor performance for the properties that support it.

```tsx
import { motion } from "framer-motion";
function FadeInCard({ children }: { children: React.ReactNode }) {
  return <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.3, ease: "easeOut" }}>{children}</motion.div>;
}
```

`initial` is the starting state, `animate` is the target Motion tweens toward on mount and whenever the values change, `transition` controls timing and easing. Swapping duration-based easing for a spring is one prop change: `transition={{ type: "spring", stiffness: 300, damping: 20 }}`.

**Exit animations** need `AnimatePresence`, since React normally removes a component from the DOM immediately, leaving no window for an exit animation to play unless something explicitly delays that removal.

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

Trace what happens the instant `message` becomes `null`: React would normally remove the `motion.div` on the very next render. `AnimatePresence` intercepts that, keeps the element mounted just long enough to run the `exit` animation, and only lets React actually remove it once that finishes, a "delay the unmount" mechanism worth being able to explain precisely, since it's a common follow-up question.

> **Remember:** `AnimatePresence` delays React's own unmount just long enough for the exit animation to actually play.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-animation-presence-q1", "type": "mcq",
      "prompt": "A component is conditionally rendered with {show && <Toast />}, and show flips to false. Without AnimatePresence, what happens to any exit animation?",
      "options": [
        {"id":"a","text":"It plays normally, React always waits for animations to finish"},
        {"id":"b","text":"React removes the component from the DOM on the very next render, before an exit animation gets any chance to play at all"},
        {"id":"c","text":"The component stays mounted forever"},
        {"id":"d","text":"React automatically detects the exit prop and delays removal"}
      ],
      "correct": "b",
      "explanation": "React's default behavior is immediate removal on the next render. AnimatePresence is specifically what intercepts that and delays the actual unmount until the exit animation completes." }
] }
```

## Gesture animations

Drag, pan, and hover gestures are where hand-rolling raw `pointermove`/`pointerup` listeners gets tedious fast, and it's Motion's strongest advantage over plain CSS.

```tsx
function DraggableCard() {
  const x = useMotionValue(0);
  const rotate = useTransform(x, [-200, 200], [-15, 15]); // derived without triggering a re-render
  return (
    <motion.div drag="x" dragConstraints={{ left: -200, right: 200 }} dragElastic={0.2} style={{ x, rotate }}
      onDragEnd={(_, info) => { if (Math.abs(info.offset.x) > 150) console.log(info.offset.x > 0 ? "swiped right" : "swiped left"); }}>
      Swipe me
    </motion.div>
  );
}
```

`useMotionValue`/`useTransform` are the key performance detail here: values driven through them update the DOM directly, through the compositor-friendly `transform`, without going through React's render cycle at all. Dragging this card doesn't re-render the component on every pixel of movement, only plain React state would do that.

```tsx
// Motion computes a FLIP transition (First-Last-Invert-Play) automatically
// whenever an element's layout position or size changes, e.g. a reordering list
<motion.div layout transition={{ type: "spring" }}>{content}</motion.div>
```

The `layout` prop is Framer Motion's implementation of FLIP. It measures the element's position **F**irst, lets React re-render to the **L**ast position, **I**nverts the visual jump with a transform back to the original spot, then **P**lays a transition to zero. That's what lets a genuine layout change, an item removed causing others to shift up, animate smoothly using only compositor-friendly transforms, instead of animating actual `top`/`left` layout properties.

> **Remember:** dragging a card driven by `useMotionValue` never triggers a React re-render. Only plain `useState` would.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-animation-motionvalue-q1", "type": "mcq",
      "prompt": "A draggable card updates its position via useMotionValue instead of useState. Does dragging it re-render the component on every pixel of movement?",
      "options": [
        {"id":"a","text":"Yes, every value change always re-renders"},
        {"id":"b","text":"No — values driven through useMotionValue update the DOM directly through the compositor, bypassing React's render cycle entirely"},
        {"id":"c","text":"Only on the final drop, never during the drag"},
        {"id":"d","text":"Only if dragConstraints is also set"}
      ],
      "correct": "b",
      "explanation": "This is the specific performance win useMotionValue buys over useState: the DOM updates directly through the compositor without going through a React render at all." }
] }
```

## Performance rules, the same ones from earlier in this course

Animate `transform`/`opacity`, never `top`/`left`/`width`/`height`/`margin`, the exact rule from the CSS rendering-performance lesson, applied here directly: a layout-affecting property forces Style, Layout, Paint, and Composite every single frame, while `transform`/`opacity` can skip straight to Composite. Set `will-change` right before an animation starts and remove it once it ends, leaving it on permanently splits the page into unnecessary GPU layers, and Motion already manages this internally for whatever it's actively animating. Avoid animating too many elements at once, even compositor-only animations carry a per-layer memory and GPU cost, so staggering (`staggerChildren`) both looks better and costs less than triggering hundreds of elements at the same instant.

```tsx
const container = { animate: { transition: { staggerChildren: 0.05 } } };
const item = { initial: { opacity: 0, y: 10 }, animate: { opacity: 1, y: 0 } };
function StaggeredList({ items }: { items: string[] }) {
  return <motion.ul variants={container} initial="initial" animate="animate">{items.map((text) => <motion.li key={text} variants={item}>{text}</motion.li>)}</motion.ul>;
}
```

Scroll-linked animations specifically need `useTransform`/`useSpring`, which Motion optimizes internally, rather than a plain `onScroll` handler calling `setState` on every scroll event, which would trigger a full React re-render per scroll tick.

> **Remember:** animate `transform`/`opacity`, never `top`/`left`. The first can skip straight to Composite; the second forces the whole rendering pipeline on every frame.

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

`useReducedMotion` reads the operating system's `prefers-reduced-motion` setting, so motion can be shrunk conditionally, typically keeping an opacity fade while dropping translation, scale, and parallax, rather than blanket-disabling every animation, which can make an interface feel broken instead of considerate. A second accessibility detail worth naming: anything that auto-plays and loops forever, background video, an infinite carousel, needs a visible pause control under WCAG 2.2.2. Motion the user can't stop is a genuine accessibility failure, not merely a preference.

> **Remember:** respecting `prefers-reduced-motion` usually means dropping movement and scale while keeping a simple opacity fade, not disabling animation entirely.

```knowledge-check
{ "questions": [
    { "id": "ip45-fe-animation-reduced-q1", "type": "mcq",
      "prompt": "A user has prefers-reduced-motion enabled at the OS level. What's the recommended way to respond, rather than disabling all animation outright?",
      "options": [
        {"id":"a","text":"Ignore the setting, it's just a suggestion"},
        {"id":"b","text":"Drop movement, scale, and parallax effects, but keep a simple opacity fade, since fully disabling animation can make an interface feel broken"},
        {"id":"c","text":"Replace all animations with a loading spinner"},
        {"id":"d","text":"Only apply reduced motion to mobile devices"}
      ],
      "correct": "b",
      "explanation": "Blanket-disabling every animation is a common overcorrection. The considerate response keeps a minimal opacity transition for feedback while removing the movement-heavy effects that actually cause discomfort." }
] }
```

## Picking a tool

| Library | Best for | Trade-off |
|---|---|---|
| CSS transitions/animations | Simple, fixed-state transitions | No mid-animation interruption, no physics, no gestures |
| Framer Motion (Motion) | Gesture-driven UI, layout transitions, orchestrated sequences | Adds bundle weight, overkill for a simple hover effect |
| React Spring | Physics-based, lower-level, more flexible API | Steeper learning curve than Motion's declarative props |
| GSAP | Timeline sequencing, SVG morphing, scroll-triggered animation | Imperative API composes less naturally with React |
| Web Animations API (native) | One-off imperative animations, no dependency | Verbose past a single element's simple animation |

The interview-ready framing: reach for CSS first, it's the cheapest, most performant, and needs zero JavaScript. Reach for Motion when gesture handling, layout animations, or state-driven sequencing are things CSS structurally can't express. Know that GSAP and React Spring exist as the alternatives worth naming for timeline-heavy or physics-heavy special cases, even if you wouldn't reach for them by default.
