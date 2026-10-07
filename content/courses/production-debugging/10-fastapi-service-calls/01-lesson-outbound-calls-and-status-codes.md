---
kind: lesson
id_key: production-debugging/lesson-outbound-calls-and-status-codes
course: production-debugging
section: fastapi-service-calls
section_title: "Service calls and errors"
section_position: 10
section_group: "FastAPI"
title: "Debugging outbound calls and the errors you report"
position: 1
estimated_minutes: 20
source:
    - docs/debug-labs.md
---

Every outbound call is a promise about a machine you do not control, and every error response is a promise to the callers of your own API. The skill this section trains is making the dependency misbehave on purpose and checking what your service says about it.

## Every call needs a timeout

httpx lets you set `timeout=None`, which waits forever. A waiting request holds a database connection and often a row lock, so a slow provider starves unrelated endpoints until the pool is empty. Decide the longest you will wait (connect and read), turn that into a clear error for the caller (a 504), and take the value from configuration. The lab environment ships a payments stand-in with a fault switch so you can reproduce the slow provider.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-svc-timeout-q1",
      "type": "mcq",
      "prompt": "The payments provider stops answering and the httpx client was created with timeout=None. What happens to pay requests?",
      "options": [
        {
          "id": "a",
          "text": "httpx gives up after 5 seconds by default"
        },
        {
          "id": "b",
          "text": "They wait indefinitely while holding a database connection, and the pool eventually runs dry"
        },
        {
          "id": "c",
          "text": "FastAPI cancels them after 30 seconds"
        },
        {
          "id": "d",
          "text": "The database aborts them"
        }
      ],
      "correct": "b",
      "explanation": "timeout=None disables every httpx timeout. Stuck requests keep their sessions, so unrelated endpoints that need a connection start failing too."
    }
  ]
}
```

## Status codes are the contract

Load balancers, retry logic, SDKs, dashboards and alerts decide success from the status code, not from the body. A handler that turns a failure into `200 {"status": "error"}` is invisible to all of them: zero errors on the dashboard while customers cannot pay. Map each failure to the status that matches it (402 for a decline, 504 for a provider timeout, 502 for an unreachable provider) and keep the human-readable message in the body. Then test the mapping with a fake client that fails in each way.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-svc-status-q1",
      "type": "mcq",
      "prompt": "A pay endpoint answers 200 with an error message in the body when the provider is down. Which part of the system is blind to the failure?",
      "options": [
        {
          "id": "a",
          "text": "Only the database"
        },
        {
          "id": "b",
          "text": "Clients, monitoring and alerts that decide success from the status code"
        },
        {
          "id": "c",
          "text": "Nothing, the body carries the error"
        },
        {
          "id": "d",
          "text": "Only the browser"
        }
      ],
      "correct": "b",
      "explanation": "Anything keyed to the HTTP status sees a success. Failures must be reported with an error status so the surrounding tooling can react."
    }
  ]
}
```
