---
kind: lesson
id_key: production-debugging/lesson-react-async-ordering
course: production-debugging
section: react-async-races
section_title: "Async and races"
section_position: 14
section_group: "React"
title: "Debugging async UI: ordering and failure paths"
position: 1
estimated_minutes: 15
source:
    - docs/debug-labs.md
---

## Responses do not arrive in the order requests were sent

A typeahead that applies every response will show the answer to an older query whenever that request is slower. Reproduce it by delaying the first response in a test, then make the effect ignore stale results or abort the previous request in its cleanup.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-re-async-q1",
      "type": "mcq",
      "prompt": "A search box shows results for an earlier query after typing quickly. What is the usual cause?",
      "options": [
        {
          "id": "a",
          "text": "The server caches responses"
        },
        {
          "id": "b",
          "text": "Every response is applied, including slower answers to older queries"
        },
        {
          "id": "c",
          "text": "React renders effects out of order"
        },
        {
          "id": "d",
          "text": "The input is uncontrolled"
        }
      ],
      "correct": "b",
      "explanation": "Nothing ties a response to the current query. Cleanup that cancels or ignores the previous request fixes it."
    }
  ]
}
```

## Optimistic updates need a rollback

Updating the UI before the server confirms is fine, but the failure branch must restore the previous state as well as show a message. Read the catch block and ask what state the screen is left in.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-re-async-q2",
      "type": "mcq",
      "prompt": "An optimistic flag toggle shows an error but the flag stays on. What is missing?",
      "options": [
        {
          "id": "a",
          "text": "A loading spinner"
        },
        {
          "id": "b",
          "text": "Restoring the previous state in the failure path"
        },
        {
          "id": "c",
          "text": "A longer timeout"
        },
        {
          "id": "d",
          "text": "A second request"
        }
      ],
      "correct": "b",
      "explanation": "The optimistic change was never undone, so the screen disagrees with the server."
    }
  ]
}
```
