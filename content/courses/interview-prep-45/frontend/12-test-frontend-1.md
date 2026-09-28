---
kind: quiz
id_key: interview-prep-45/test-frontend-1
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "Practice Test: HTML, CSS and JavaScript"
position: 12
estimated_minutes: 25
pass_percentage: 70
duration_minutes: 25
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
questions:
    - id_key: interview-prep-45/test-frontend-1/div-button
      type: mcq
      difficulty: beginner
      points: 5
      prompt: "Why is a native `<button>` a better choice than a `<div onClick>` for a clickable control?"
      options:
        - text: "<button> is keyboard-focusable, fires on both Enter and Space, and has a button role for a screen reader, all for free"
          correct: true
        - text: "<button> renders faster than a div"
        - text: "There's no real difference once you add an onClick handler"
        - text: "<button> only matters for search engine ranking"
      explanation: "A <div onClick> gets none of the keyboard operability, activation keys, or accessible role a <button> gets automatically, unless you manually rebuild all of it with tabIndex, a role, and keydown handlers."
    - id_key: interview-prep-45/test-frontend-1/box-sizing
      type: mcq
      difficulty: beginner
      points: 5
      prompt: "A `.card` has `width: 200px`, `padding: 20px`, and `border: 5px solid black`, with `box-sizing: border-box`. What is its rendered width?"
      options:
        - text: "200px — border-box makes the declared width the final rendered size"
          correct: true
        - text: "250px"
        - text: "230px"
        - text: "180px"
      explanation: "border-box flips what width means: it becomes the final size, and the browser shrinks the content area to make room for padding and border inside it, instead of adding them on top."
    - id_key: interview-prep-45/test-frontend-1/css-modules-scoping
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "What actually prevents two CSS Modules files from both defining `.card` and colliding?"
      options:
        - text: "The build step compiles each class into a unique, hashed name per file"
          correct: true
        - text: "Developer discipline, the same as BEM"
        - text: "CSS Modules disallow common class names"
        - text: "Browsers automatically namespace class names"
      explanation: "CSS Modules enforce scoping at build time by compiling each class to a hashed, file-unique name, which is the concrete difference from a pure naming convention like BEM."
    - id_key: interview-prep-45/test-frontend-1/transform-vs-top
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "Why does animating `top`/`left` cost more than animating `transform` for the same visual movement?"
      options:
        - text: "top/left force layout, then paint, then composite on every frame; transform can be handled entirely on the GPU's compositor thread, skipping layout and paint"
          correct: true
        - text: "top/left are deprecated CSS properties"
        - text: "transform only works with CSS animations, not transitions"
        - text: "There's no real performance difference"
      explanation: "top/left change an element's geometry, forcing the full layout-paint-composite pipeline. transform and opacity are the two properties that can skip straight to compositing."
    - id_key: interview-prep-45/test-frontend-1/contain-property
      type: mcq
      difficulty: advanced
      points: 10
      prompt: "A dashboard with 20 independent widgets re-checks layout for all 20 whenever one widget's DOM updates. What single CSS property isolates each widget so this stops happening?"
      options:
        - text: "contain: content, which declares a widget's internals isolated from the rest of the page"
          correct: true
        - text: "position: absolute"
        - text: "will-change: transform"
        - text: "overflow: hidden"
      explanation: "contain tells the browser that layout, paint, and style changes inside an element can't ripple outward, so updating one widget never forces a layout re-check on its siblings."
    - id_key: interview-prep-45/test-frontend-1/loose-equality
      type: mcq
      difficulty: advanced
      points: 10
      prompt: "Why does `[] == false` evaluate to `true`, even though `if ([])` runs its body (an empty array is truthy)?"
      options:
        - text: "== coerces both sides to numbers before comparing: false becomes 0, and [] converts to \"\" and then to 0, so the actual comparison running is 0 == 0"
          correct: true
        - text: "Empty arrays are secretly falsy in JavaScript"
        - text: "This is a bug in the language with no real explanation"
        - text: "if() and == use different definitions of true in every case"
      explanation: "if() only calls Boolean() on its condition, and Boolean() on any object is always true. == does something entirely different: it coerces both operands toward numbers, and [] happens to coerce down to 0, same as false does."
    - id_key: interview-prep-45/test-frontend-1/prototype-live-reference
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "`Person.prototype.greet` is reassigned to a new function after several `Person` instances already exist. Do those existing instances see the new method?"
      options:
        - text: "Yes — an instance never stores its own copy of a prototype method; every call walks the chain and reads whatever the prototype currently holds"
          correct: true
        - text: "No, each instance snapshotted the original method at construction time"
        - text: "Only if the instances are re-created with new Person()"
        - text: "It depends on whether the instance called greet() before the reassignment"
      explanation: "The prototype chain is a live reference, not a snapshot. Every property lookup that misses on the instance walks up to the prototype and reads whatever is currently there, at call time."
    - id_key: interview-prep-45/test-frontend-1/eventloop-order
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "What is the output order for: a synchronous log, then `setTimeout(fn, 0)`, then `Promise.resolve().then(fn)`, then another synchronous log?"
      options:
        - text: "sync log 1, sync log 2, the promise's .then callback, the setTimeout callback"
          correct: true
        - text: "sync log 1, the setTimeout callback, sync log 2, the promise's .then callback"
        - text: "sync log 1, sync log 2, the setTimeout callback, the promise's .then callback"
        - text: "The setTimeout callback always runs first since it was scheduled first"
      explanation: "Both synchronous logs run first, in order. Once the call stack is empty, the entire microtask queue drains (the .then callback) before the event loop even looks at the macrotask queue (the setTimeout callback), regardless of the 0ms delay."
    - id_key: interview-prep-45/test-frontend-1/cache-lookup-falsy
      type: mcq
      difficulty: advanced
      points: 10
      prompt: "A memoized cache checks `if (cache[key])` to decide whether a value is already cached. What specific cached value breaks this check?"
      options:
        - text: "A legitimately cached falsy result, like 0 or an empty string, since the check can't tell 'cached as 0' apart from 'nothing cached at all'"
          correct: true
        - text: "A cached object"
        - text: "A cached string longer than 100 characters"
        - text: "Nothing breaks it, this check is always correct"
      explanation: "Truthiness-based existence checks fail the moment the correct, already-cached answer happens to be falsy. `key in cache` checks existence directly, independent of what value is stored."
    - id_key: interview-prep-45/test-frontend-1/promise-any-vs-race
      type: mcq
      difficulty: advanced
      points: 10
      prompt: "You need something to happen the instant the first of several promises succeeds, and to only give up once every one of them has failed. Which combinator fits, and why not `Promise.race`?"
      options:
        - text: "Promise.any, because race settles on whoever finishes first, win or lose, while any specifically waits for the first success and only rejects once everything has failed"
          correct: true
        - text: "Promise.race, since it already means 'first one wins'"
        - text: "Promise.all, since it waits for every promise"
        - text: "Promise.allSettled, since it never rejects"
      explanation: "race would incorrectly settle the moment any promise rejects, even if a slower one would have succeeded. any is purpose-built for 'first success wins, give up only once all have failed.'"
    - id_key: interview-prep-45/test-frontend-1/attribute-vs-property
      type: mcq
      difficulty: beginner
      points: 5
      prompt: "A user types into `<input value=\"hi\">`. What does `input.getAttribute('value')` return afterward?"
      options:
        - text: "\"hi\" — the attribute is frozen at load time and never reflects what the user typed"
          correct: true
        - text: "Whatever the user just typed"
        - text: "An empty string"
        - text: "null"
      explanation: "An attribute is the string from the HTML source, frozen at load time. The live, current value only ever shows up through the property, input.value."
    - id_key: interview-prep-45/test-frontend-1/event-delegation-stoppropagation
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "A list uses event delegation: one click listener on the container, using `closest('.row')` to find which row was clicked. A row's own child element has a listener that calls `stopPropagation()`. What happens when that child is clicked?"
      options:
        - text: "The event never reaches the delegated container listener, since stopPropagation halts bubbling before it gets there"
          correct: true
        - text: "The container listener still fires normally"
        - text: "Both listeners fire at the same time"
        - text: "stopPropagation only affects capturing, not bubbling"
      explanation: "stopPropagation halts the event from continuing to bubble up the tree. A delegated listener relies on bubbling to ever see the event, so a child that stops propagation silently breaks delegation for that click."
---

Covers HTML semantics, the CSS box model, Flexbox/Grid, CSS architecture, rendering performance, JavaScript scope and types, prototypes, promises, the event loop, and the DOM.
