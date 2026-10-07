---
kind: lesson
id_key: production-debugging/lesson-fullstack-data-state
course: production-debugging
section: fullstack-data-state
section_title: "Data and state"
section_position: 20
section_group: "Fullstack"
title: "Values that change meaning on the way: time zones, money and stale writes"
position: 1
estimated_minutes: 15
source:
    - docs/debug-labs.md
---

## Data and state

A value crosses the wire as text and means different things on each side: a timestamp without an offset is read as local time, an amount in dollars is formatted as cents, and a save based on an old version overwrites newer data. Agree on one representation (UTC with an offset, integer cents, an explicit version check) and enforce it at the API boundary.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fullstack-data-state-q1",
      "type": "mcq",
      "prompt": "Why does a timestamp like 2025-03-06T02:30:00 (no offset) show the wrong day in some browsers?",
      "options": [
        {
          "id": "a",
          "text": "JavaScript parses it as local time, not UTC"
        },
        {
          "id": "b",
          "text": "Browsers cannot parse ISO dates"
        },
        {
          "id": "c",
          "text": "The server clock is wrong"
        },
        {
          "id": "d",
          "text": "Daylight saving is off"
        }
      ],
      "correct": "a",
      "explanation": "Without an offset the string is interpreted in the viewer's local time zone."
    }
  ]
}
```
