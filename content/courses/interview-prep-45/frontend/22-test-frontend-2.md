---
kind: quiz
id_key: interview-prep-45/test-frontend-2
course: interview-prep-45
section: frontend
section_title: "Frontend"
section_position: 12
title: "Practice Test: React"
position: 22
estimated_minutes: 30
pass_percentage: 70
duration_minutes: 30
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
questions:
    - id_key: interview-prep-45/quiz-week-5/q8
      type: mcq
      difficulty: advanced
      points: 10
      prompt: "In a full-stack interview asking for a Todo app, which answer demonstrates senior judgment?"
      options:
        - text: "Start with the data model and API contract, then build UI state on top, mentioning optimistic updates and error rollback"
          correct: true
        - text: "Install as many libraries as possible to show ecosystem knowledge"
        - text: "Build the CSS animations first for visual impact"
        - text: "Refuse to discuss the frontend because backend matters more"
      explanation: "Schema and API contract are the load-bearing decisions — UI follows from them. Mentioning optimistic updates with rollback shows you've handled real client-server state, which is what the question probes."
    - id_key: interview-prep-45/test-frontend-2/memo-doesnt-guarantee
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "A parent component re-renders. Does its `React.memo`-wrapped child definitely skip re-rendering?"
      options:
        - text: "Not necessarily — memo only skips the render if every prop is shallowly equal to last time; a new inline function or object literal passed as a prop still forces a re-render"
          correct: true
        - text: "Yes, wrapping a component in React.memo always skips a re-render when the parent re-renders"
        - text: "No, React.memo has no effect unless combined with useReducer"
        - text: "Yes, but only for class components"
      explanation: "React.memo does a shallow comparison of props. If the parent passes any new reference, an inline arrow function or object literal recreated every render, the comparison reports a change and the child re-renders anyway."
    - id_key: interview-prep-45/test-frontend-2/setstate-same-reference
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "You call `useState`'s setter with the exact same object reference it already holds. Does the component re-render?"
      options:
        - text: "No — React 18+ bails out of re-rendering when the new value is Object.is-equal to the current one"
          correct: true
        - text: "Yes, every setter call always triggers a re-render"
        - text: "Only if the object has more than one property"
        - text: "It throws an error"
      explanation: "React compares the new value to the current one with Object.is. Passing back the identical reference is a no-op: React still calls the component once to check, then skips the commit since nothing changed."
    - id_key: interview-prep-45/test-frontend-2/toggle-scope
      type: mcq
      difficulty: beginner
      points: 5
      prompt: "A `<Toggle>` shows or hides a `<Sidebar>` used by exactly one parent component. What's the right scope for that state?"
      options:
        - text: "Local state in the parent, since only one component and its direct child need the value"
          correct: true
        - text: "React Context, since any shared UI state belongs in Context"
        - text: "Redux, to keep all state centralized"
        - text: "A URL query parameter"
      explanation: "The scope-picking rule is: default to the narrowest scope that works. A value needed by exactly one parent and its direct child has no reason to be lifted into Context or a global store."
    - id_key: interview-prep-45/test-frontend-2/usefetch-race
      type: mcq
      difficulty: advanced
      points: 10
      prompt: "A `useFetch(url)` hook re-fetches every time `url` changes. What specifically prevents a slow response for an old `url` from overwriting a faster response for a newer one?"
      options:
        - text: "An AbortController created in the effect, aborted in the cleanup function, so a superseded request's response never reaches setState"
          correct: true
        - text: "React automatically drops any fetch response that arrives out of order"
        - text: "Nothing — this is a real bug unless a debounce is added"
        - text: "Using useMemo around the fetch call"
      explanation: "The effect's cleanup function runs when url changes again, calling controller.abort() on the previous request. An aborted request's promise rejects with AbortError, which is deliberately not treated as a state-setting error, so the stale response can never overwrite the current one."
    - id_key: interview-prep-45/test-frontend-2/hoc-wrapper-hell
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "A component built with `withAuth(withTheme(withLogging(Component)))` is hard to debug in React DevTools. What's the underlying problem, and what's the modern replacement?"
      options:
        - text: "Each HOC adds a real wrapping component, producing deeply nested 'wrapper hell' that obscures prop flow, and HOCs can silently clobber each other's injected props; hooks replace this with no wrapping components at all"
          correct: true
        - text: "The problem is a memory leak, fixed by removing withLogging"
        - text: "HOCs are deprecated and will not run in React 18"
        - text: "The fix is to always order HOCs alphabetically"
      explanation: "Every HOC in the chain wraps the component in another real component, which is what makes DevTools hard to trace and lets two HOCs injecting the same prop name silently collide. Calling the equivalent hooks directly inside the component removes both problems."
    - id_key: interview-prep-45/test-frontend-2/key-index-reorder
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "Why does `key={index}` break when a list can be reordered, but work fine for a list that never reorders or has items removed from the middle?"
      options: 
        - text: "React matches siblings by key across renders; when items reorder, an index-based key shifts identity, so local state (like a focused input) attaches to the wrong row"
          correct: true
        - text: "index keys are always invalid syntax in JSX"
        - text: "index keys cause a memory leak regardless of reordering"
        - text: "It doesn't break, index keys are always safe to use"
      explanation: "A key only needs to be stable across renders for the elements it's attached to. If the list order or membership never changes, an index-based key happens to stay stable too. Reordering breaks that assumption immediately."
    - id_key: interview-prep-45/test-frontend-2/usememo-when-it-helps
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "When does `useMemo` actually help, as opposed to adding overhead for no real benefit?"
      options:
        - text: "Only when the computed value is genuinely expensive, or its reference identity feeds a React.memo-wrapped child or another hook's dependency array"
          correct: true
        - text: "Any time a value is derived from props or state"
        - text: "Only inside class components"
        - text: "Only when the value is a primitive, like a number or string"
      explanation: "useMemo pays a dependency-comparison cost on every render. It only pays off when the computation itself is expensive, or when a stable reference is specifically needed downstream, not as a reflexive habit applied to every derived value."
    - id_key: interview-prep-45/test-frontend-2/unknown-vs-any
      type: mcq
      difficulty: beginner
      points: 5
      prompt: "What's the practical difference between `unknown` and `any` in TypeScript?"
      options:
        - text: "any disables type checking entirely; unknown still requires a narrowing check before use, so mistakes surface at compile time instead of at runtime"
          correct: true
        - text: "They are interchangeable in every context"
        - text: "unknown can only be used for numbers"
        - text: "any is stricter than unknown"
      explanation: "any opts a value out of type checking completely. unknown is the type-safe counterpart: you can assign anything to it, but you must narrow its type (with a type guard, assertion, or check) before doing anything with it."
    - id_key: interview-prep-45/test-frontend-2/lazy-suspense-bundle
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "What problem does `React.lazy` combined with `Suspense` actually solve?"
      options:
        - text: "It reduces the initial JavaScript bundle size by deferring the code for routes or components not needed on first paint until they're actually rendered"
          correct: true
        - text: "It makes every component render faster once loaded"
        - text: "It eliminates the need for a build step entirely"
        - text: "It replaces the need for a key prop on lists"
      explanation: "React.lazy splits a component into its own chunk, loaded on demand, and Suspense shows a fallback while that chunk downloads. The win is a smaller initial bundle, not faster rendering once the code is loaded."
    - id_key: interview-prep-45/test-frontend-2/dependency-array-correctness
      type: mcq
      difficulty: advanced
      points: 10
      prompt: "Is the dependency array on `useEffect` primarily a performance mechanism or a correctness mechanism?"
      options:
        - text: "Correctness — a missing dependency means the closure captured a stale value, a real bug, not just a missed optimization"
          correct: true
        - text: "Performance — it exists purely to reduce the number of renders"
        - text: "Neither, it has no real functional effect"
        - text: "It's a security mechanism preventing unauthorized state updates"
      explanation: "The dependency array tells React when a closure's captured values have gone stale and the effect needs to re-run with fresh ones. Treating a missing dependency as 'just one extra render avoided' misses that it's actually a correctness bug."
    - id_key: interview-prep-45/test-frontend-2/reconciliation-type-change
      type: mcq
      difficulty: advanced
      points: 10
      prompt: "A subtree's root element changes from `<div>` to `<span>` between renders. What does React do?"
      options:
        - text: "It tears down the entire old subtree, running cleanup effects, and mounts a brand-new one, without trying to reconcile the children at all"
          correct: true
        - text: "It patches only the tag name, keeping all child state intact"
        - text: "It throws a runtime error, since element types can't change"
        - text: "It ignores the change entirely and keeps rendering the old element"
      explanation: "A changed element type is one of reconciliation's two core heuristics: matching type is a precondition for diffing children at all. A type change forces a full unmount (with cleanup) and a full fresh mount, discarding any local state the old subtree held."
    - id_key: interview-prep-45/test-frontend-2/lifecycle-cleanup-trap
      type: mcq
      difficulty: intermediate
      points: 10
      prompt: "What's the most common trap when mapping a class component's lifecycle onto `useEffect` in a function component?"
      options:
        - text: "Forgetting the cleanup function — listeners, subscriptions, and timers that were torn down automatically in componentWillUnmount now need an explicit returned cleanup function, or they leak"
          correct: true
        - text: "useEffect cannot run any asynchronous code"
        - text: "useEffect runs before the render instead of after"
        - text: "Function components can't subscribe to external events at all"
      explanation: "componentWillUnmount was a dedicated, unmissable lifecycle method for cleanup. useEffect folds that into an optional returned function, which is easy to simply forget to write, silently leaving subscriptions and timers running after unmount."
---

Covers React rendering and reconciliation, hooks internals, performance and concurrent APIs, state management and state machines, composition patterns, TypeScript for React, and testing.
