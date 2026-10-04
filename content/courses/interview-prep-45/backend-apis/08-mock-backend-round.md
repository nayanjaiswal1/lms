---
kind: lesson
id_key: interview-prep-45/backend-mock-round
course: interview-prep-45
section: backend-apis
section_title: "APIs, Security & Deployment"
section_position: 11
section_group: "Backend"
title: "Mock Backend Round"
position: 8
estimated_minutes: 60
source:
    - mock-interviews/32-lesson.md
    - mock-interviews/33-lesson.md
    - final-prep/39-lesson.md
    - final-prep/42-lesson.md
    - interview-days/45-lesson.md
---

You've now studied REST design, security, real-time systems, containers, storage, and testing one lesson at a time, with room to think. A real backend round gives you none of that: rapid questions, a live coding prompt, and someone watching how you reason under pressure. This lesson runs that round: a rapid Q&A drill covering this whole course, a live coding prompt with a full solution and rubric, and a scoring guide for grading yourself afterward.

## How the round runs

A typical backend interview round mixes two formats, often in the same 45-60 minutes: a rapid-fire depth pass, and one live coding prompt.

**The rapid-fire pass** is not coding. The interviewer asks a question, you answer out loud in one to five minutes as if explaining to a teammate, and a good interviewer chains the next question off your own answer: "how does a database index work" leads to "when would an index actually *hurt* write performance," which leads to "how would you go find a slow query in production." If you can't answer any single one of these in under 90 seconds without an "um, let me think," that specific topic is your revision target, not the whole course.

**The coding portion** is usually a small, self-contained API: create a resource, list it, update it, delete it, handle the obvious errors. Forty-five minutes is not enough time for a large system. It is enough time to show clean route design, sensible status codes, and server-side validation you can justify out loud.

> **Remember:** the rapid-fire pass rewards a confident answer in under 90 seconds. The coding pass rewards a clean, small, fully working API over a half-finished ambitious one.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-mockround-structure-q1", "type": "mcq",
      "prompt": "In a 45-minute backend interview with both a coding prompt and rapid-fire questions, what should you prioritize if time runs short?",
      "options": [
        {"id":"a","text":"A large, ambitious system design that stays incomplete"},
        {"id":"b","text":"A small, fully working API with sane routes, status codes, and validation, since a complete simple solution beats an incomplete complex one"},
        {"id":"c","text":"Skipping validation entirely to save time"},
        {"id":"d","text":"Writing extensive comments instead of working code"}
      ],
      "correct": "b",
      "explanation": "Forty-five minutes rewards a small, complete, well-reasoned solution far more than an ambitious one left half-finished. Clean route design, correct status codes, and real validation are what a rapid coding round is actually grading." }
] }
```

## Rapid Q&A: fundamentals across the backend

Answer each of these out loud, in under two minutes, before reading the model answer.

**Q: Explain the Django request lifecycle.** A request hits the WSGI or ASGI server, which hands it to Django's handler. Django runs it through the middleware stack top-down, each layer able to short-circuit and return early. The URL resolver matches the path to a view. The view runs, usually parsing the request, querying the ORM, and building a response. The response flows back up through the middleware stack in reverse order. Middleware order matters: authentication middleware has to run before anything that reads the logged-in user. See the Request Lifecycle lesson for the full walkthrough.

**Q: How does async work in FastAPI?** FastAPI supports both `async def` and plain `def` route handlers. An `async def` handler runs directly on the event loop, which is ideal for I/O-bound work like an async database call, since the loop can serve other requests while one is waiting. A plain `def` handler automatically runs in a thread pool instead, so it doesn't block the loop. The trap: calling a *blocking* library inside an `async def` handler blocks the entire event loop for every concurrent request, which is worse than just using `def` and letting FastAPI put it on a thread. See the ASGI and Async lesson.

**Q: How would you optimize a slow query?** Start with `EXPLAIN ANALYZE` to see the real query plan: sequential scan versus index scan, nested loop versus hash join, estimated rows versus actual rows. Then, in likely order: add an index on the filtered or joined column, and verify the planner actually uses it; fix an N+1 pattern; stop selecting every column when you only need a few; paginate instead of loading everything; consider a covering index for a read-heavy query. Verify the fix against the plan afterward, not just against a faster stopwatch. See the Indexing and Query Optimization lessons.

**Q: Explain database transactions.** A transaction groups several statements into one atomic unit: either all of them commit, or none do. ACID names the guarantee: atomicity (all or nothing), consistency (every commit leaves the database in a state that respects its constraints), isolation (concurrent transactions don't see each other's uncommitted changes, with an isolation level controlling exactly how much they're shielded from each other), durability (once committed, it survives a crash). Name a concrete failure this prevents: debiting one account and crediting another without a transaction can leave the money gone from one side and never added to the other if the process dies in between. See the Transactions and Isolation lesson.

**Q: Explain the N+1 query problem and how you'd catch it before it ships.** Loading a list of objects, then querying once per object for a related field, turns one page load into N+1 database round trips instead of one or two. Catch it with `select_related` (for a forward foreign key or one-to-one, a SQL join) and `prefetch_related` (for a reverse foreign key or many-to-many, a second query joined in Python), and by asserting an expected query count in tests so a regression fails CI instead of showing up as a slow page in production.

**Q: Explain optimistic versus pessimistic locking, and when you'd choose each.** Pessimistic locking takes a lock up front (`SELECT ... FOR UPDATE`) and makes every other writer wait, which is safe under heavy contention but costs throughput. Optimistic locking checks a version number or timestamp at write time and rejects the write if it's stale, which scales better when conflicts are rare, at the cost of a rejected write occasionally needing a retry.

**Q: What happens when two transactions try to update the same row at the same time in Postgres?** The second transaction blocks on a row-level lock until the first commits or rolls back. If two transactions each hold a lock the other one needs, the database detects the cycle and kills one of them with a deadlock error, which the application has to catch and retry.

**Q: Explain Redis eviction policies, and why picking the wrong one silently breaks a cache-as-source-of-truth setup.** `allkeys-*` policies can evict any key, which is fine for a pure cache but dangerous the moment something in that same Redis instance, like session state, isn't actually rebuildable from a database. A `volatile-*` policy only evicts keys that were explicitly given a TTL, so untimed data survives memory pressure untouched. See the Redis Caching lesson.

**Q: How would you add rate limiting to an API without a shared datastore, versus with one?** Without a shared store, each process can only track its own in-memory counters, so a client gets N times the intended limit across N processes, and every counter resets on deploy. With a shared store like Redis, `INCR` plus `EXPIRE` gives every process the same view of the count, which is the only version that actually works correctly across more than one server. See the API Versioning and Error Handling lesson.

**Q: WSGI versus ASGI?** WSGI is synchronous: one thread handles one request at a time and blocks until it's done. ASGI supports `async`/`await` and long-lived connections like WebSockets, letting one process serve many concurrent requests that are mostly waiting on I/O.

**Q: Why does FastAPI's dependency injection matter?** `Depends()` makes auth, database sessions, and pagination testable and swappable: a test can override a dependency with a fake without touching the route's own code, and the route handler itself stays thin, focused on the actual request instead of setup.

> **Remember:** most of these questions chain from one root idea, correctness under concurrency and at scale, phrased ten different ways. Learn the idea once, not ten separate facts.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-mockround-rapidfire-q1", "type": "mcq",
      "prompt": "An interviewer asks: \"your rate limiter uses an in-memory counter, and you run 4 server processes behind a load balancer. What's wrong?\" What's the strongest answer?",
      "options": [
        {"id":"a","text":"Nothing is wrong; in-memory counters work fine at any scale"},
        {"id":"b","text":"Each process has its own separate counter, so a client effectively gets 4x the intended limit, and every counter resets to zero on every deploy"},
        {"id":"c","text":"In-memory counters are slower than a database query"},
        {"id":"d","text":"The load balancer would reject this setup automatically"}
      ],
      "correct": "b",
      "explanation": "An in-memory counter is local to one process. Across 4 processes with no shared state, a client can rack up 4 times the intended limit by hitting different processes, and a deploy silently resets every counter. A shared store like Redis is what fixes this." }
] }
```

## A live coding prompt: a small task API

**Prompt:** "Build a small task list API: create, list, toggle-done, and delete tasks. Handle errors gracefully." A realistic 45-minute scope: no database, in-memory storage is fine, and you should say out loud what you'd change for production.

Clarifying questions worth asking before writing a line of code: does persistence need to survive a restart (say what you'd swap in for production even if in-memory is fine for the round)? What should a client do while a request is in flight, or if it fails? Where does validation belong (both client and server; the client is for immediate feedback, the server is the one that actually protects the data, since the client can never be trusted).

```python
from uuid import uuid4

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI()


class TaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)


class Task(BaseModel):
    id: str
    title: str
    done: bool = False


tasks: dict[str, Task] = {}


@app.get("/tasks", response_model=list[Task])
def list_tasks() -> list[Task]:
    return list(tasks.values())


@app.post("/tasks", response_model=Task, status_code=201)
def create_task(payload: TaskCreate) -> Task:
    task = Task(id=str(uuid4()), title=payload.title)
    tasks[task.id] = task
    return task


@app.patch("/tasks/{task_id}", response_model=Task)
def toggle_task(task_id: str) -> Task:
    task = tasks.get(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="task not found")
    task.done = not task.done
    return task


@app.delete("/tasks/{task_id}", status_code=204)
def delete_task(task_id: str) -> None:
    if task_id not in tasks:
        raise HTTPException(status_code=404, detail="task not found")
    del tasks[task_id]
```

Notice what's doing the error handling here, and why. Pydantic rejects an empty title, or one over 200 characters, before the handler body even runs, returning a `422` automatically. The `404`s are written explicitly, because "delete or toggle something that doesn't exist" is a real case a client will actually hit, not an edge case safe to ignore.

**Scoring rubric for this prompt:**
- The API's shape, routes, status codes, request and response bodies, was sketched out loud before any code was written.
- Validation happens server-side, not only in a client the interviewer never sees.
- The candidate can explain the idempotency of each route: is a second identical `DELETE` a problem? A second identical `POST`?
- The candidate names what changes for production (a real database, authentication, pagination on the list endpoint) without being asked, and without over-engineering the actual 45-minute answer to include all of it.

> **Remember:** Pydantic's own validation is doing real work here, rejecting bad input before your handler ever runs. Write the explicit 404s yourself; "not found" is a real case your interviewer expects handled, not an oversight to skip.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-mockround-coding-q1", "type": "mcq",
      "prompt": "In the task API above, what actually returns a 422 status code for an empty title, and why does that matter for the interview answer?",
      "options": [
        {"id":"a","text":"The developer wrote an explicit if not title: raise HTTPException(422) check"},
        {"id":"b","text":"Pydantic's own field validation (min_length=1) rejects the request automatically before the handler body runs, which is worth naming out loud as validation happening at the boundary, not buried in business logic"},
        {"id":"c","text":"FastAPI rejects all empty strings globally by default"},
        {"id":"d","text":"The database rejects the insert and FastAPI translates that into a 422"}
      ],
      "correct": "b",
      "explanation": "TaskCreate's Field(min_length=1, max_length=200) makes Pydantic reject an invalid payload automatically, returning a 422 before create_task's body ever executes. Naming this out loud shows you understand where FastAPI's validation actually happens." }
] }
```

## The scoring rubric for the rapid-fire round

Use this to grade yourself, or a study partner, after running the Q&A section above out loud from start to finish.

- Every answer landed in under 90 seconds, with no long pause to remember the shape of the idea.
- The answer named a concrete mechanism (`select_related`, `EXPLAIN ANALYZE`, a row-level lock), not just a buzzword with nothing underneath it.
- Where two options exist (optimistic versus pessimistic locking, cache-aside versus write-through), the answer stated a real trade-off and a default choice, not just a definition of both.
- A follow-up question ("what if traffic goes up 10x," "what if the worker crashes mid-task") got a specific answer building on what was already said, not a restart from scratch.
- Weak spots got named honestly instead of talked around. Knowing which of your answers are shaky is more useful than pretending they're all equally solid.

> **Remember:** an interviewer isn't grading whether you memorized a glossary. They're grading whether you can name a real mechanism and a real trade-off, fast, and adapt it when the question shifts under you.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-mockround-rubric-q1", "type": "mcq",
      "prompt": "During a rapid-fire round, an interviewer asks a follow-up that changes an assumption (\"what if there are 10x more workers running this task\"). What's the strongest response?",
      "options": [
        {"id":"a","text":"Repeat the original answer unchanged, since the core idea still applies"},
        {"id":"b","text":"Adapt the specific part of the original answer the new assumption actually affects, and say out loud what changes and why"},
        {"id":"c","text":"Say the question is out of scope for this round"},
        {"id":"d","text":"Ask to skip to the next question instead"}
      ],
      "correct": "b",
      "explanation": "A follow-up that shifts an assumption is testing whether you can adapt your reasoning live, not whether you memorized a fixed answer. Naming exactly what changes under the new assumption is the strongest signal you can give." }
] }
```
