---
kind: lesson
id_key: production-debugging/lesson-async-orm-measure-first
course: production-debugging
section: fastapi-performance
section_title: "Performance (SQLAlchemy)"
section_position: 8
section_group: "FastAPI"
title: "Measure first: counting statements in async SQLAlchemy"
position: 1
estimated_minutes: 20
source:
    - docs/debug-labs.md
---

A slow endpoint is a claim about time; a cause is a claim about work. The skill this section trains is turning "it is slow" into a number you can reproduce: how many SQL statements does one request run, and does that number grow with the data?

## Count statements, not milliseconds

Wall-clock time depends on the machine, the cache and the network. The number of statements a request runs does not. Turn on statement logging (`echo=True` on the engine or the `sqlalchemy.engine` logger at INFO), call the endpoint for a small and a large customer, and compare. A count that grows with the number of rows is an N+1: one query for the list and one more for every row.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-sa-count-q1",
      "type": "mcq",
      "prompt": "An endpoint returns in 40 ms for a customer with 2 orders and 8 s for one with 400 orders. What do you measure first?",
      "options": [
        {
          "id": "a",
          "text": "CPU frequency of the server"
        },
        {
          "id": "b",
          "text": "How many SQL statements each request runs for the small and the large customer"
        },
        {
          "id": "c",
          "text": "The size of the JSON response in bytes"
        },
        {
          "id": "d",
          "text": "The Python version"
        }
      ],
      "correct": "b",
      "explanation": "A statement count that grows with the number of rows is the signature of an N+1 and is independent of machine speed."
    }
  ]
}
```

## Relationships here never load implicitly

In this service relationships are declared with `lazy="raise"`: touching an unloaded relationship raises instead of silently issuing SQL, because a lazy load inside async code cannot work. That protects you from hidden queries, but it also means the data is loaded wherever the query is written. Eager loading (`selectinload` for collections, `joinedload` for single parents) loads the related rows for all returned objects at once, in a constant number of statements.

Fix the query, then prove it: a test that records the statements of one request for a small and a large dataset and asserts that the count is equal.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-sa-eager-q1",
      "type": "mcq",
      "prompt": "What does selectinload(Order.items) do for a list of 50 orders?",
      "options": [
        {
          "id": "a",
          "text": "Runs one extra statement per order"
        },
        {
          "id": "b",
          "text": "Loads the items of all 50 orders with one extra statement"
        },
        {
          "id": "c",
          "text": "Caches the items in the process"
        },
        {
          "id": "d",
          "text": "Defers loading until the attribute is accessed"
        }
      ],
      "correct": "b",
      "explanation": "selectinload issues one additional SELECT ... WHERE order_id IN (...) for all returned parents, so the number of statements does not grow with the rows."
    }
  ]
}
```
