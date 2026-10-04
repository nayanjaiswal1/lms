---
kind: lesson
id_key: interview-prep-45/day-11-backend
course: interview-prep-45
section: backend-fastapi
section_title: "FastAPI"
section_position: 8
section_group: "Backend"
title: "FastAPI Background Tasks"
position: 3
estimated_minutes: 35
source:
    - 45-day-interview-roadmap.md
---

The ASGI and Async lesson introduced `BackgroundTasks` in passing. This lesson goes deep on when it's the right tool versus when you actually need a real task queue like Celery, and builds the pattern every "process this upload and show progress" interview question is really testing: offloading work and giving the client a way to poll for status.

## BackgroundTasks vs a real task queue

This distinction is a direct, frequent interview question.

| | `BackgroundTasks` | Celery / RQ / durable queue |
|---|---|---|
| Runs where | Same process, after the response is sent | Separate worker process(es), possibly separate machines |
| Survives a crash | No -- in-memory, lost if the process dies | Yes -- the task sits in the broker until a worker picks it up |
| Scales independently of the web tier | No | Yes -- add workers without touching web servers |
| Retry / scheduling | None built in | Built in |
| Best for | Fire-and-forget, sub-second, non-critical work (a log line, a metric, warming a cache) | Anything that must complete, is slow, or needs retry/scheduling |

The interview trap is using `BackgroundTasks` for something that must not be lost: sending a password-reset email, charging a card, processing an uploaded file a user is actively waiting on. If the worker process restarts, a deploy, a crash, an autoscaler killing an instance, mid-task, that work simply disappears with no error surfaced anywhere. `BackgroundTasks` is appropriate for genuinely disposable work only.

> **Remember:** `BackgroundTasks` runs in the same process and vanishes if that process dies. If the work must not be lost, it belongs in a durable queue, not `BackgroundTasks`.

```knowledge-check
{ "questions": [
    { "id": "backend-fastapi-bgtasks-tradeoff-q1", "type": "mcq",
      "prompt": "A route uses BackgroundTasks to send a password-reset email. The server crashes 2 seconds after responding, before the task ran. What happens to the email?",
      "options": [
        {"id":"a","text":"It's queued and will send once the server restarts"},
        {"id":"b","text":"It's lost entirely, since BackgroundTasks holds the task only in memory in that same process"},
        {"id":"c","text":"FastAPI automatically retries it on the next request"},
        {"id":"d","text":"It was already sent before the crash, since BackgroundTasks runs before the response"}
      ],
      "correct": "b",
      "explanation": "BackgroundTasks runs in-process, after the response is sent. Nothing persists it anywhere else, so a crash before it runs means the work is gone with no record it was ever attempted." }
] }
```

## Offloading heavy computation, with a status endpoint

```python
from fastapi import FastAPI, BackgroundTasks, UploadFile, HTTPException
import uuid

app = FastAPI()

# In-memory here for illustration; use Redis in any real deployment so state
# survives a worker restart and is visible across multiple app instances.
job_store: dict[str, dict] = {}


def process_file(job_id: str, contents: bytes) -> None:
    job_store[job_id]["status"] = "processing"
    try:
        total_lines = contents.count(b"\n")
        processed = 0
        for _ in range(total_lines):
            # simulate per-line work
            processed += 1
            if processed % 100 == 0:
                job_store[job_id]["progress"] = processed / total_lines

        job_store[job_id]["status"] = "completed"
        job_store[job_id]["result"] = {"lines_processed": processed}
    except Exception as exc:
        job_store[job_id]["status"] = "failed"
        job_store[job_id]["error"] = str(exc)


@app.post("/files/process")
async def start_processing(file: UploadFile, background_tasks: BackgroundTasks):
    contents = await file.read()
    job_id = str(uuid.uuid4())
    job_store[job_id] = {"status": "queued", "progress": 0.0}

    background_tasks.add_task(process_file, job_id, contents)

    return {"job_id": job_id, "status_url": f"/files/process/{job_id}"}


@app.get("/files/process/{job_id}")
async def get_job_status(job_id: str):
    job = job_store.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Job not found")
    return job
```

The shape here, return a job ID right away and let the client poll a status endpoint, is the standard answer for any "long-running work behind an HTTP API" question, independent of whether the actual execution is `BackgroundTasks`, Celery, or a cloud job service. Interviewers care more about this shape than the specific execution mechanism.

> **Remember:** return a job ID immediately and let the client poll a status endpoint. That shape is what interviewers are checking for, regardless of what actually runs the work behind it.

```knowledge-check
{ "questions": [
    { "id": "backend-fastapi-bgtasks-shape-q1", "type": "mcq",
      "prompt": "What is the standard response shape for a 'start this long-running job' endpoint?",
      "options": [
        {"id":"a","text":"Block the request until the job finishes, then return the full result"},
        {"id":"b","text":"Return a job ID and a status URL immediately, and let the client poll that URL for progress"},
        {"id":"c","text":"Return a 202 with no body and no way to check progress"},
        {"id":"d","text":"Redirect the client to a separate job-tracking service"}
      ],
      "correct": "b",
      "explanation": "Returning a job id immediately and exposing a status endpoint to poll is the standard pattern for long-running work behind an HTTP API, regardless of whether BackgroundTasks, Celery, or something else actually does the work." }
] }
```

## Making job state durable with Redis

The in-memory `job_store` above breaks the moment you run more than one app instance, a status check can land on a different instance than the one processing the job, or the process restarts. Redis fixes both:

```python
import json
import redis

r = redis.Redis(host="localhost", port=6379, decode_responses=True)


def set_job(job_id: str, data: dict) -> None:
    r.set(f"job:{job_id}", json.dumps(data), ex=3600)  # expire stale job records after an hour


def get_job(job_id: str) -> dict | None:
    raw = r.get(f"job:{job_id}")
    return json.loads(raw) if raw else None


def process_file_durable(job_id: str, contents: bytes) -> None:
    set_job(job_id, {"status": "processing", "progress": 0.0})
    try:
        total_lines = contents.count(b"\n") or 1
        processed = 0
        for _ in range(total_lines):
            processed += 1
            if processed % 100 == 0:
                set_job(job_id, {"status": "processing", "progress": processed / total_lines})

        set_job(job_id, {"status": "completed", "progress": 1.0, "result": {"lines_processed": processed}})
    except Exception as exc:
        set_job(job_id, {"status": "failed", "error": str(exc)})
```

This still runs in-process via `BackgroundTasks`, so it's still lost entirely if the process dies mid-task. The fix for *that* is routing `process_file_durable`'s work through a real task queue instead, the natural next step once "must survive a crash" becomes a real requirement. Keep both layers straight: Redis fixes the *state visibility* problem (any instance can answer the status check), a durable queue fixes the *durability* problem (the work itself survives a crash), and in practice they're often used together, a queued task writes progress into Redis, and the API reads that progress back for the status endpoint.

> **Remember:** Redis fixes state *visibility* across instances. A durable queue fixes work *surviving a crash*. They solve different problems and are often used together.

```knowledge-check
{ "questions": [
    { "id": "backend-fastapi-bgtasks-redis-q1", "type": "mcq",
      "prompt": "Job state is moved from an in-process dict to Redis, but the actual work still runs via BackgroundTasks. Is the durability problem (surviving a crash mid-task) now solved?",
      "options": [
        {"id":"a","text":"Yes, Redis makes the whole job durable"},
        {"id":"b","text":"No, the job's progress is now visible across instances, but the work itself still runs in-process and is lost if that process crashes mid-task"},
        {"id":"c","text":"Yes, but only for jobs under a certain size"},
        {"id":"d","text":"No, Redis actually makes things worse here"}
      ],
      "correct": "b",
      "explanation": "Redis solves visibility: any instance can now read a job's current status. It does nothing for durability of the work itself, since BackgroundTasks still executes in-process and has no way to resume or replay a task lost to a crash." }
] }
```

## The durable version: progress tracking with a real task queue

```python
from celery_app import app as celery_app
from celery import states

@celery_app.task(bind=True)
def process_file_task(self, contents_b64: str):
    contents = base64.b64decode(contents_b64)
    total_lines = contents.count(b"\n") or 1
    processed = 0
    for _ in range(total_lines):
        processed += 1
        if processed % 100 == 0:
            self.update_state(state="PROGRESS", meta={"progress": processed / total_lines})
    return {"lines_processed": processed}
```

```python
@app.post("/files/process-durable")
async def start_processing_durable(file: UploadFile):
    contents = await file.read()
    task = process_file_task.delay(base64.b64encode(contents).decode())
    return {"job_id": task.id, "status_url": f"/files/process-durable/{task.id}"}


@app.get("/files/process-durable/{job_id}")
async def get_durable_job_status(job_id: str):
    result = celery_app.AsyncResult(job_id)
    if result.state == "PROGRESS":
        return {"status": "processing", "progress": result.info.get("progress")}
    if result.state == "SUCCESS":
        return {"status": "completed", "result": result.result}
    if result.state == "FAILURE":
        return {"status": "failed", "error": str(result.info)}
    return {"status": result.state.lower()}
```

`self.update_state` with a custom `"PROGRESS"` state is a task queue's built-in mechanism for exactly this. There's no need to hand-roll a Redis progress key once you're already on a real queue, since its own result backend gives you this for free.

> **Remember:** once a job genuinely must survive a crash, route it through a real task queue instead of BackgroundTasks. The queue's own result backend already tracks progress; you don't need to hand-roll it.

```knowledge-check
{ "questions": [
    { "id": "backend-fastapi-bgtasks-celery-q1", "type": "mcq",
      "prompt": "Why doesn't the Celery version above need a separate Redis progress key like the BackgroundTasks version did?",
      "options": [
        {"id":"a","text":"Celery tasks run instantly, so progress tracking isn't needed"},
        {"id":"b","text":"self.update_state writes progress into the task's own result backend, which the status endpoint reads back through AsyncResult, so a hand-rolled Redis key would be redundant"},
        {"id":"c","text":"Celery cannot report progress at all"},
        {"id":"d","text":"Redis is required by Celery internally, so it's already being written to anyway"}
      ],
      "correct": "b",
      "explanation": "update_state with a custom PROGRESS state is Celery's built-in progress-reporting mechanism, backed by its own result backend. The status endpoint reads that back via AsyncResult, so a separate hand-rolled progress key is unnecessary." }
] }
```
