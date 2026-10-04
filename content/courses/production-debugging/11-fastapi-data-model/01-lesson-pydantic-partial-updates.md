---
kind: lesson
id_key: production-debugging/lesson-pydantic-partial-updates
course: production-debugging
section: fastapi-data-model
section_title: "Data model and validation"
section_position: 11
section_group: "FastAPI"
title: "Debugging validation models: absent is not the same as null"
position: 1
estimated_minutes: 20
source:
    - docs/debug-labs.md
---

Pydantic models are the boundary between the outside world and your data. A bug here rarely raises: it quietly writes the wrong thing. The skill this section trains is asking, for every field, what the model does when the client sends it, omits it, or sends null.

## Three states, two representations

A PATCH body can contain a value, an explicit null (clear this field) or nothing at all (leave it alone). A model field with a default of `None` collapses the last two. Pydantic remembers which fields were actually provided: `model_dump(exclude_unset=True)` returns exactly those. `model_dump()` returns everything, defaults included, so applying it overwrites the fields the client never mentioned. Reproduce it by sending a single field and reading the whole resource back.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-pyd-unset-q1",
      "type": "mcq",
      "prompt": "A PATCH model has phone: str | None = None and company: str | None = None. The client sends only {\"phone\": \"123\"}. What does payload.model_dump() contain?",
      "options": [
        {
          "id": "a",
          "text": "Only phone"
        },
        {
          "id": "b",
          "text": "phone and company (company as None)"
        },
        {
          "id": "c",
          "text": "Nothing"
        },
        {
          "id": "d",
          "text": "An error"
        }
      ],
      "correct": "b",
      "explanation": "model_dump() includes every field with its default. Use exclude_unset=True to get only the fields the client sent."
    }
  ]
}
```
