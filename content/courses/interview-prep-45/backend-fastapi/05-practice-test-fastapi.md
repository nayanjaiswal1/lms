---
kind: quiz
id_key: interview-prep-45/test-backend-fastapi
course: interview-prep-45
section: backend-fastapi
section_title: "FastAPI"
section_position: 8
section_group: "Backend"
title: "Practice Test: FastAPI"
position: 5
estimated_minutes: 20
pass_percentage: 70
duration_minutes: 20
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
questions:
  - id_key: interview-prep-45/test-backend-fastapi/blocking-event-loop
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "An async def route calls a blocking synchronous function (e.g. a sync DB driver). What actually breaks?"
    options:
      - text: "Only that one request is slow; other requests are unaffected"
      - text: "The entire event loop is blocked, so every other concurrent request on that worker stalls until the blocking call returns"
        correct: true
      - text: "FastAPI automatically detects and thread-pools it, exactly like a plain def route"
      - text: "Nothing; async def and def behave identically for blocking calls"
    explanation: "A single-threaded event loop drives every coroutine on that worker by yielding at await points. A blocking call never yields, so it holds the whole loop hostage, stalling every other request being served by that worker."

  - id_key: interview-prep-45/test-backend-fastapi/gather-vs-sequential
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "Three independent upstream calls each take 200 ms. What is the approximate total time using asyncio.gather versus awaiting them one after another?"
    options:
      - text: "About 200 ms with gather (the max), versus about 600 ms sequentially (the sum)"
        correct: true
      - text: "Both take about 600 ms"
      - text: "gather takes longer due to scheduling overhead"
      - text: "About 67 ms with gather"
    explanation: "asyncio.gather starts all three coroutines at once, so total latency tracks the slowest single call. Sequential awaits pay for each call's latency one after another."

  - id_key: interview-prep-45/test-backend-fastapi/coroutine-call
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "`coro = fetch_user(1)` where fetch_user is `async def`. Has the function body run yet?"
    options:
      - text: "Yes, calling an async function runs it immediately"
      - text: "No, it only creates a coroutine object; the body runs once coro is awaited"
        correct: true
      - text: "It depends on whether the event loop is currently running"
      - text: "It raises an error unless immediately awaited on the same line"
    explanation: "Calling a coroutine function just builds a coroutine object. Nothing inside the function body executes until that object is awaited."

  - id_key: interview-prep-45/test-backend-fastapi/framework-choice
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A team needs an API-first service with heavy concurrent I/O and wants validation/docs generated automatically from type hints. Which framework fits, and why?"
    options:
      - text: "FastAPI, since ASGI concurrency suits I/O-bound work and Pydantic generates validation/OpenAPI docs from type hints"
        correct: true
      - text: "Django, for its built-in admin panel"
      - text: "Flask, since it has the least code to learn"
      - text: "All three are equally suited to this use case"
    explanation: "FastAPI's async-first ASGI model targets exactly this workload, and its Pydantic integration gives automatic validation and OpenAPI docs from the same type hints, with no separate documentation effort."

  - id_key: interview-prep-45/test-backend-fastapi/depends-cache-scope
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Without @lru_cache, does FastAPI's default dependency caching make get_settings run only once across the whole app's lifetime?"
    options:
      - text: "Yes, FastAPI caches every dependency for the life of the process"
      - text: "No, the cache only lasts one request; get_settings runs again on each new request unless wrapped in something like @lru_cache"
        correct: true
      - text: "No, FastAPI never caches dependencies at all"
      - text: "Yes, but only for class-based dependencies"
    explanation: "FastAPI's built-in dependency cache is scoped to a single request, so two dependencies sharing get_settings within one request only trigger it once, but a new request runs it again from scratch."

  - id_key: interview-prep-45/test-backend-fastapi/yield-teardown
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "In a `yield`-based dependency like `def get_db(): db = SessionLocal(); yield db; db.close()`, when does db.close() run?"
    options:
      - text: "Before the endpoint body executes"
      - text: "After the endpoint has finished and the response has been sent"
        correct: true
      - text: "Only if an exception is raised"
      - text: "It never runs automatically"
    explanation: "Everything before yield is setup, injected into the endpoint. Everything after yield is teardown, which FastAPI runs once the request/response cycle completes."

  - id_key: interview-prep-45/test-backend-fastapi/oauth2-scheme-role
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Does OAuth2PasswordBearer(tokenUrl=\"token\") validate a JWT's signature by itself?"
    options:
      - text: "Yes, it fully validates the token"
      - text: "No, it only extracts the bearer token from the Authorization header and documents the scheme for OpenAPI; validation is separate code"
        correct: true
      - text: "It validates the signature but ignores expiry"
      - text: "It only supports cookies, not bearer tokens"
    explanation: "OAuth2PasswordBearer's job is pulling the raw token out of the header (401ing if missing) and wiring up the OpenAPI 'Authorize' button. Decoding and checking the token is separate application code, like get_current_user."

  - id_key: interview-prep-45/test-backend-fastapi/backgroundtasks-durability
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A route uses BackgroundTasks for a task that must not be lost, like charging a card. The process crashes right after responding. What happens?"
    options:
      - text: "The task resumes automatically once the process restarts"
      - text: "The task is lost entirely, since BackgroundTasks holds it only in memory in that process"
        correct: true
      - text: "FastAPI retries it up to three times by default"
      - text: "Nothing changes; BackgroundTasks is always durable"
    explanation: "BackgroundTasks runs in-process after the response is sent, with no persistence anywhere else. A crash before it runs means the work vanishes with no record it was ever attempted -- exactly why it's the wrong tool for anything that must not be lost."

  - id_key: interview-prep-45/test-backend-fastapi/redis-vs-queue-durability
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "Job progress is now stored in Redis, but the work itself still runs through BackgroundTasks. Is the crash-durability problem solved?"
    options:
      - text: "Yes, storing progress in Redis makes the whole job durable"
      - text: "No; Redis solves visibility of status across instances, but the work itself still runs in-process and is lost if that process crashes mid-task"
        correct: true
      - text: "Yes, but only if Redis persistence (AOF) is enabled"
      - text: "No, and Redis makes the situation strictly worse"
    explanation: "Redis fixes the problem of a status check landing on a different instance than the one processing the job. It does nothing for the work itself, which still needs a durable queue to survive a crash mid-task."

  - id_key: interview-prep-45/test-backend-fastapi/job-status-shape
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "What is the standard response shape for an endpoint that starts long-running work?"
    options:
      - text: "Block until the work finishes, then return the full result"
      - text: "Return a job id and a status URL immediately, and let the client poll that URL"
        correct: true
      - text: "Return only a 202 status code with no body"
      - text: "Redirect to a separate tracking service"
    explanation: "Returning a job id immediately and exposing a status endpoint to poll is the standard pattern for long-running work behind an HTTP API, regardless of what actually executes the work underneath."
---
This test covers ASGI's concurrency model and the blocking-call trap, precise async/await semantics, choosing between Django, FastAPI, and Flask, FastAPI's dependency injection and its caching/teardown rules, and when BackgroundTasks is enough versus when the work needs a durable queue. Pass 70% to complete the section.
