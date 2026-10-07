---
kind: lesson
id_key: production-debugging/lesson-react-state-identity
course: production-debugging
section: react-state
section_title: "State and identity"
section_position: 15
section_group: "React"
title: "Debugging state: who owns it and which component it belongs to"
position: 1
estimated_minutes: 15
source:
    - docs/debug-labs.md
---

## State belongs to a position in the tree

React keeps state by component type and position, or by key. An index key gives the state of a deleted row to the row that moved up, and a form that copies a prop into state once keeps the old values when the prop changes. Use a stable id as the key, and a key on the form to reset it when the entity changes.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-re-state-q1",
      "type": "mcq",
      "prompt": "After deleting a list item the next item shows the deleted item's draft text. Why?",
      "options": [
        {
          "id": "a",
          "text": "The list is not memoized"
        },
        {
          "id": "b",
          "text": "Rows are keyed by index, so row state follows the position"
        },
        {
          "id": "c",
          "text": "The delete request was slow"
        },
        {
          "id": "d",
          "text": "The draft is stored in localStorage"
        }
      ],
      "correct": "b",
      "explanation": "With index keys the surviving row reuses the removed row's component instance and its state."
    }
  ]
}
```
