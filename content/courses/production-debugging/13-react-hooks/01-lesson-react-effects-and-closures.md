---
kind: lesson
id_key: production-debugging/lesson-react-effects-and-closures
course: production-debugging
section: react-hooks
section_title: "React hooks"
section_position: 13
section_group: "React"
title: "Debugging hooks: dependencies, closures and identity"
position: 1
estimated_minutes: 15
source:
    - docs/debug-labs.md
---

## An effect is a closure over one render

Every render creates new functions that see that render's props and state. A timer or listener created in one render keeps reading that render's values until it is replaced, which is why a counter freezes or a filter is ignored. Debug it by asking which render a callback was created in, and what its dependency array promises about when it is recreated.

The fixes are small and specific: read the latest value through a functional update, list every value the effect reads, and keep dependencies stable.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-re-hooks-q1",
      "type": "mcq",
      "prompt": "An interval callback does setSeconds(seconds + 1) and the badge stops at 1. Why?",
      "options": [
        {
          "id": "a",
          "text": "setState is asynchronous"
        },
        {
          "id": "b",
          "text": "The callback closes over the seconds value of the render that created the interval"
        },
        {
          "id": "c",
          "text": "React batches interval updates"
        },
        {
          "id": "d",
          "text": "The interval is cleared on each render"
        }
      ],
      "correct": "b",
      "explanation": "The callback was created once and always sees the first render's value. A functional update (current => current + 1) reads the latest state instead."
    }
  ]
}
```

## Objects are new on every render

An object or array created in a component body is a new reference each render. Put it in an effect's dependency array and the effect re-runs every render; if the effect sets state or fetches, that is an endless loop visible in the network tab. Depend on the primitive fields the effect actually reads.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-re-hooks-q2",
      "type": "mcq",
      "prompt": "An effect lists an options object built in the parent's body in its dependencies, and requests repeat forever. What is the fix?",
      "options": [
        {
          "id": "a",
          "text": "Remove the dependency array"
        },
        {
          "id": "b",
          "text": "Depend on the primitive values the effect reads, such as options.days"
        },
        {
          "id": "c",
          "text": "Wrap the fetch in setTimeout"
        },
        {
          "id": "d",
          "text": "Call the effect from a click handler"
        }
      ],
      "correct": "b",
      "explanation": "Primitives compare by value, so the effect only re-runs when the data it uses changes."
    }
  ]
}
```
