---
kind: lesson
id_key: production-debugging/lesson-event-loop-and-races
course: production-debugging
section: fastapi-async
section_title: "Async and concurrency"
section_position: 9
section_group: "FastAPI"
title: "Debugging async code: the loop and the races between awaits"
position: 1
estimated_minutes: 20
source:
    - docs/debug-labs.md
---

Async bugs look like load problems: everything is fine for one user and strange for many. The skill this section trains is asking, for every `await` and every blocking call, who else gets to run at that point.

## One event loop, many requests

An `async def` handler runs on the event loop thread, which serves every request of the process. Any call that does not yield (CPU-bound work, `time.sleep`, a blocking library) stops the whole loop until it returns, so unrelated requests, even the health check, wait. Plain `def` endpoints and `run_in_threadpool` move work to worker threads. Reproduce it by timing a cheap endpoint while the suspect endpoint runs.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-async-loop-q1",
      "type": "mcq",
      "prompt": "A login endpoint calls bcrypt directly inside an async def. What is the effect on other requests?",
      "options": [
        {
          "id": "a",
          "text": "None, async handlers run in parallel automatically"
        },
        {
          "id": "b",
          "text": "Each login freezes the event loop, so every other request in the process waits"
        },
        {
          "id": "c",
          "text": "Only other logins are affected"
        },
        {
          "id": "d",
          "text": "The database connection is closed"
        }
      ],
      "correct": "b",
      "explanation": "bcrypt is CPU-bound and synchronous. On the event loop thread it blocks all coroutines until it finishes; run it in the thread pool instead."
    }
  ]
}
```

## Await is a scheduling point

A single-threaded loop does not make code atomic. Between two awaits other requests run, and the database sees interleaved statements from many sessions. "Read the value, compute in Python, write it back" across awaits loses updates exactly like threads do. Push the arithmetic into one statement (`UPDATE ... SET x = x + :n`), or lock the row (`SELECT ... FOR UPDATE`); an in-process lock does not survive a second worker.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-async-race-q1",
      "type": "mcq",
      "prompt": "Two concurrent credits read the same balance, add their amount in Python and write it back. What happens?",
      "options": [
        {
          "id": "a",
          "text": "Both are applied, asyncio serialises them"
        },
        {
          "id": "b",
          "text": "One credit is lost, because both wrote balance plus their own amount"
        },
        {
          "id": "c",
          "text": "The second request fails with an error"
        },
        {
          "id": "d",
          "text": "PostgreSQL merges the two writes"
        }
      ],
      "correct": "b",
      "explanation": "The read and the write are separate round trips with awaits in between. Both requests saw the old balance, so the later write overwrites the earlier one."
    }
  ]
}
```
