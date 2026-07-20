---
kind: lesson
id_key: interview-prep-45/day-11-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Day 11 — FastAPI Background Tasks"
position: 11
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
Day 3 introduced `BackgroundTasks` in passing; today you go deep on when it's the right tool versus when you actually need Celery, and you build the pattern every "process this upload and show progress" interview question is really testing: offloading work and giving the client a way to poll for status.

## BackgroundTasks vs a real task queue

This distinction is the core of today's material and a direct, frequent interview question.

| | `BackgroundTasks` | Celery / RQ / durable queue |
|---|---|---|
| Runs where | Same process, after the response is sent | Separate worker process(es), possibly separate machines |
| Survives a crash | No — in-memory, lost if the process dies | Yes — task sits in the broker until a worker picks it up |
| Scales independently of web tier | No | Yes — add workers without touching web servers |
| Retry / scheduling | None built in | Built in (Day 8) |
| Best for | Fire-and-forget, sub-second, non-critical (send a log line, fire a metric, warm a cache) | Anything that must complete, is slow, or needs retry/scheduling |

**The interview trap:** using `BackgroundTasks` for something that must not be lost — sending a password-reset email, charging a card, processing an uploaded file the user is waiting on. If the worker process restarts (a deploy, a crash, an autoscaler killing an instance) mid-task, that work simply vanishes with no error surfaced anywhere. `BackgroundTasks` is appropriate for genuinely disposable work only.

## Offloading heavy computation

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

The shape here — return a job ID immediately, let the client poll a status endpoint — is the standard pattern for any "long-running work behind an HTTP API" question, independent of whether the actual execution is `BackgroundTasks`, Celery, or a cloud job service. Interviewers care more about this shape than the specific execution mechanism.

## Making it production-real: swap in Redis for job state

The in-memory `job_store` above breaks the moment you run more than one app instance (a status check can land on a different instance than the one processing the job) or the process restarts. Redis fixes both:

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

This still runs in-process via `BackgroundTasks` (so it's still lost on a crash mid-task) — the fix for *that* is routing `process_file_durable`'s work through a Celery task instead, which is the natural next step once "must survive a crash" becomes a real requirement. Know both layers: Redis fixes the *state visibility* problem, Celery fixes the *durability* problem, and they're often used together (Celery task writes progress into Redis, FastAPI reads it back for the status endpoint).

## Progress tracking with Celery (the durable version)

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

`self.update_state` with a custom `"PROGRESS"` state is Celery's built-in mechanism for exactly this — no need to hand-roll a Redis progress key when you're already on Celery, since the result backend already gives you this for free.

## Key takeaways

- `BackgroundTasks` is in-process and non-durable — use it only for genuinely disposable work; anything that must survive a crash belongs in a real task queue.
- The "return a job ID, poll a status endpoint" shape is the interview-relevant pattern, independent of the execution mechanism behind it.
- In-memory job state breaks under multiple app instances or a restart — move it to Redis (or the DB) the moment you need it visible across processes.
- Celery's `self.update_state(state="PROGRESS", meta={...})` plus `AsyncResult` gives you progress tracking and durability in one mechanism, without hand-rolling a separate store.
- Know when to reach for which layer: `BackgroundTasks` for fire-and-forget, Redis for shared state visibility, Celery for durability, retry, and scheduling.

## Today's checklist

- [ ] Read: FastAPI background tasks documentation
- [ ] Offload heavy computation to a background task
- [ ] Implement progress tracking for long-running tasks
- [ ] Implement a file-processing endpoint with progress updates
- [ ] Be ready to answer: how do you handle long-running tasks? What is the difference between sync and async tasks?
