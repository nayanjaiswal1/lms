---
kind: lesson
id_key: interview-prep-45/day-19-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Celery Deep Dive"
position: 19
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
Every Python backend interview eventually asks "how do you handle work that shouldn't block the request." Celery is the standard answer, and interviewers push past "I used `@shared_task`" into routing, chaining, and what happens when a task hangs. Today covers task routing and priority queues, chains/chords, custom task states, and building a real multi-stage pipeline.

## Task routing and priority queues

By default every Celery task goes to one queue and any worker can pick it up. Routing lets you send different tasks to different queues, so you can dedicate workers to slow tasks (video processing) separately from fast ones (sending an email). Otherwise one slow task blocks a worker that could've cleared ten fast ones.

```python
# celeryconfig.py
task_routes = {
    "orders.tasks.send_receipt_email": {"queue": "fast"},
    "orders.tasks.generate_invoice_pdf": {"queue": "slow"},
    "orders.tasks.sync_to_warehouse": {"queue": "slow"},
}

task_default_queue = "fast"
```

```bash
# separate worker pools per queue — a stuck PDF job never starves email sends
celery -A myproject worker -Q fast --concurrency=8 -n fast@%h
celery -A myproject worker -Q slow --concurrency=2 -n slow@%h
```

Celery doesn't have true priority *within* a queue by default on Redis (it's FIFO); to get priority you either run separate queues per priority tier (as above — "high", "default", "low", each with its own worker allocation) or use RabbitMQ as the broker, which supports native per-message priority (`task_queue_max_priority`, `priority=` on `apply_async`). The interview answer: "priority" in Celery is almost always implemented as queue separation, not a priority field, because the default broker (Redis) doesn't support message priority.

## Chains and chords

- **`chain`**: run tasks sequentially, each receiving the previous task's return value as its first argument.
- **`chord`**: run a group of tasks in parallel, then run a callback once *all* of them finish, with their results collected as a list.

```python
from celery import shared_task, chain, chord

@shared_task
def fetch_data(source_id):
    return download(source_id)

@shared_task
def transform(raw_data):
    return clean_and_normalize(raw_data)

@shared_task
def save_result(cleaned_data):
    return Record.objects.create(payload=cleaned_data).id

# sequential: fetch -> transform -> save, each step feeding the next
pipeline = chain(fetch_data.s(source_id=1), transform.s(), save_result.s())
pipeline.apply_async()

@shared_task
def resize_image(image_id, size):
    return generate_thumbnail(image_id, size)

@shared_task
def notify_all_sizes_ready(results, upload_id):
    Upload.objects.filter(id=upload_id).update(status="ready", thumbnails=results)

# parallel: resize to 3 sizes at once, callback fires only after all 3 finish
job = chord(
    [resize_image.s(image_id=99, size=s) for s in ("small", "medium", "large")],
    notify_all_sizes_ready.s(upload_id=42),
)
job.apply_async()
```

A `chord`'s callback is itself just another task. Celery tracks completion via a counter in the result backend, decrementing as each group member finishes and firing the callback when it hits zero. This is why **a chord requires a result backend** (Redis or an RDBMS): without one there's no way to know when the group is done.

## Custom task states

Beyond Celery's built-in states (`PENDING`, `STARTED`, `SUCCESS`, `FAILURE`, `RETRY`), you can report custom progress via `update_state`. This is essential for long tasks a frontend needs to show progress for.

```python
from celery import shared_task, states

@shared_task(bind=True)
def generate_report(self, report_id):
    rows = fetch_rows(report_id)
    total = len(rows)
    for i, row in enumerate(rows):
        process_row(row)
        if i % 100 == 0:
            self.update_state(
                state="PROGRESS",
                meta={"current": i, "total": total, "percent": round(i / total * 100, 1)},
            )
    return {"report_id": report_id, "rows_processed": total}
```

```python
# polling from the API layer
from celery.result import AsyncResult

def task_status(request, task_id):
    result = AsyncResult(task_id)
    if result.state == "PROGRESS":
        return JsonResponse(result.info)          # the meta dict above
    if result.state == "SUCCESS":
        return JsonResponse({"status": "done", "result": result.result})
    return JsonResponse({"status": result.state})
```

`bind=True` gives the task access to `self`, needed to call `self.update_state`.

## Handling tasks that take too long

**How do you handle tasks that take too long?** Layered defenses:

1. **Time limits**: `task_time_limit` (hard, SIGKILL) and `task_soft_time_limit` (raises `SoftTimeLimitExceeded` inside the task, so it can clean up) prevent one runaway task from occupying a worker slot forever.
2. **`acks_late` + `reject_on_worker_lost`**: by default Celery acks a task as soon as a worker *starts* it, so a worker crash mid-task loses the task silently. `task_acks_late=True` acks only after completion, so a crashed worker's in-flight task gets redelivered to another worker.
3. **Chunking**: break a task that processes 100k rows into a chord of 100 tasks each processing 1k rows, so no single task runs long enough to hit limits, and partial progress survives a worker restart.

```python
@shared_task(bind=True, time_limit=300, soft_time_limit=270, acks_late=True)
def export_large_dataset(self, dataset_id):
    try:
        return run_export(dataset_id)
    except SoftTimeLimitExceeded:
        mark_export_failed(dataset_id, reason="timeout")
        raise
```

## Result backend

**What is result backend?** The store Celery writes task state and return values to (commonly Redis or Postgres), separate from the broker (which only queues the task *messages*, not results). Without a result backend configured, `task.delay()` still runs the task, but `AsyncResult` can't tell you anything: `.status` stays `PENDING` forever and `.get()` hangs.

```python
app.conf.broker_url = "redis://localhost:6379/0"          # queues pending work
app.conf.result_backend = "redis://localhost:6379/1"      # stores results/state — separate DB index
app.conf.result_expires = 3600                              # auto-clean old results after 1 hour
```

Broker and result backend are conceptually separate even when both point at Redis. The broker is a queue Celery consumes destructively (a task message is gone once delivered), while the result backend is a key-value store Celery writes to and the caller polls, unrelated to task delivery.

## Implementation: fetch → process → save → notify pipeline

```python
from celery import shared_task, chain

@shared_task(bind=True, max_retries=3, default_retry_delay=10)
def fetch_data(self, source_url):
    try:
        return requests.get(source_url, timeout=10).json()
    except requests.RequestException as exc:
        raise self.retry(exc=exc)

@shared_task
def process_data(raw):
    return {"normalized": normalize(raw), "row_count": len(raw)}

@shared_task
def save_data(processed):
    record = ImportedDataset.objects.create(
        payload=processed["normalized"],
        row_count=processed["row_count"],
    )
    return record.id

@shared_task
def notify_completion(dataset_id):
    send_notification(
        channel="#data-imports",
        message=f"Dataset {dataset_id} imported successfully.",
    )
    return dataset_id

def run_import_pipeline(source_url: str):
    pipeline = chain(
        fetch_data.s(source_url),
        process_data.s(),
        save_data.s(),
        notify_completion.s(),
    )
    return pipeline.apply_async()
```

Each stage is independently retryable (`fetch_data` retries on network failure) and independently observable via the result backend. You can inspect `pipeline.parent.parent...` or just track the final `AsyncResult` id and let each stage log its own state.

The pattern to remember across all four sections: routing, chords, custom states, and the result backend are all ways of answering "what is this task doing right now, and can I trust that it will finish." A production Celery setup is really a small distributed system, and the interview questions above are testing whether you've internalized that, not whether you can recite decorator syntax.
