---
kind: lesson
id_key: production-debugging/lesson-react-measure-renders
course: production-debugging
section: react-performance
section_title: "Performance"
section_position: 16
section_group: "React"
title: "Debugging React performance: measure renders and leaks"
position: 1
estimated_minutes: 15
source:
    - docs/debug-labs.md
---

## Count renders and listeners before changing code

Use the Profiler or a render counter to prove who re-renders and why. A context provider that builds a new value object each render re-renders every consumer, and a listener added without cleanup leaves a copy per visit. Fix the identity or the cleanup, then show the count dropped.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-re-perf-q1",
      "type": "mcq",
      "prompt": "Every consumer of a context re-renders when the provider's parent does. What is the likely cause?",
      "options": [
        {
          "id": "a",
          "text": "Consumers are not wrapped in memo"
        },
        {
          "id": "b",
          "text": "The provider passes a new value object each render"
        },
        {
          "id": "c",
          "text": "The context has too many fields"
        },
        {
          "id": "d",
          "text": "React.StrictMode is on"
        }
      ],
      "correct": "b",
      "explanation": "A new object identity counts as a change for every consumer. useMemo keeps it stable."
    }
  ]
}
```
