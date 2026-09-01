---
kind: lesson
id_key: interview-prep-45/note-temporal-vs-celery-vs-custom-worker
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: Temporal vs Celery vs a Custom DB-Polling Worker"
position: 105
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

Celery is covered in depth elsewhere in this course, and the DB-backed queue pattern (a `jobs` table, with workers claiming rows via `SELECT ... FOR UPDATE SKIP LOCKED` for safe concurrent polling) is covered in this course's system-design material, along with a DB-vs-Redis-vs-SQS-vs-Kafka trade-off table. What's new here: Temporal as a third option, and the decision framework for picking between all three when the workload is multi-step AI/document processing (parse, chunk, run AI calls, generate output) rather than a simple fire-and-forget task.

## Temporal, in one paragraph

Temporal is a workflow orchestration engine. You write a "workflow" function in a normal-looking language (Python, Go, and others) that calls "activities," which are the actual side-effecting units of work, and Temporal's server persists the workflow's execution state durably at every step. If a worker crashes mid-workflow, a new worker resumes from the last completed activity, not from the start. This is the specific thing Celery or a plain task queue doesn't give you: durable, resumable *multi-step* state, plus a UI showing exactly which step a given execution is on.

## Resource footprint: the honest trade-off

| | Celery | Temporal |
|---|---|---|
| Components | Redis + worker process | Temporal server + Postgres + UI + worker |
| Idle RAM | ~150MB | ~1GB |
| Setup | `pip install`, write tasks, run worker | Deploy the Temporal server stack first, then write workflows |

Temporal is roughly 6-7x heavier idle, and has real setup cost before any application code runs. This matters concretely on a small cluster, say under 4GB of total RAM, where Temporal can eat a large fraction of the box before the actual application even starts.

## Decision framework

- **Simple, independent tasks** (send an email, generate a thumbnail): use Celery. A standard task-queue pattern is the right level of complexity here, and reaching for Temporal would be over-engineering.
- **Small cluster or limited resources**: use Celery, for the resource-footprint reasons above.
- **Multi-step pipeline with fan-out, needing step-by-step visibility and resumability**: use Temporal. This is exactly what it's built for.
- **Tasks complete in seconds**: use Celery. There's no need for durable per-step state when a task either finishes or fails within seconds anyway.
- **Tasks run for minutes and must survive a worker crash mid-way**: use Temporal, since state persistence across a crash is the actual point of the tool.
- **Team wants low ops overhead now, but may grow into complex workflows later**: start with Celery, and migrate the specific workflow that later needs Temporal's guarantees rather than moving the whole system upfront.

A pipeline like "get document, parse, chunk, run AI calls, generate output, generate questions" is exactly the multi-step, fan-out shape Temporal is designed for. But if the cluster is resource-constrained, that resource cost is a real argument against reaching for it immediately, even for a workload that's otherwise a good conceptual fit.

**Lightweight middle ground:** if you're on Celery already and just want task history without adding Redis-as-result-store weight, point the result backend at your existing Postgres instead:

```python
# settings.py
CELERY_RESULT_BACKEND = "django-db"   # reuses your existing Postgres, not Redis
CELERY_BROKER_URL = "redis://redis:6379/0"
```

You still need Redis as the broker, since something has to hold the pending-task queue, but results and history ride on infrastructure you already run instead of adding Redis-as-result-store on top.

## The "build your own worker" option

The core mechanic, a `jobs` table where workers claim rows via `SELECT ... FOR UPDATE SKIP LOCKED` so multiple worker processes never double-process the same row, is covered in this course's system-design material. The concrete shape of that as a Django+asyncio worker, useful to have ready for a live-coding round, looks like this:

```python
async def run_worker(concurrency=5):
    semaphore = asyncio.Semaphore(concurrency)

    async def handle(task):
        async with semaphore:
            try:
                await Task.objects.filter(id=task.id).aupdate(status="running")
                result = await TASK_HANDLERS[task.task_type](task.payload)
                await Task.objects.filter(id=task.id).aupdate(status="completed", result=result)
            except Exception:
                retries = task.retries + 1
                await Task.objects.filter(id=task.id).aupdate(
                    status="failed" if retries >= 3 else "pending",
                    retries=retries,
                )

    while True:
        with transaction.atomic():
            tasks = list(
                Task.objects.select_for_update(skip_locked=True)
                .filter(status="pending").order_by("created_at")[:concurrency]
            )
        if tasks:
            await asyncio.gather(*[handle(t) for t in tasks])
        else:
            await asyncio.sleep(2)
```

Walking through the loop: each iteration opens a transaction, claims up to `concurrency` pending rows with `select_for_update(skip_locked=True)` (so a second worker process running the same loop skips rows this one already locked instead of blocking on them), and releases the transaction as soon as the row list is read. It then runs `handle()` on each claimed task concurrently via `asyncio.gather`, bounded by the semaphore so at most `concurrency` tasks run at once. Inside `handle`, a task is marked `running`, then `completed` with its result, or on any exception, bumped to `failed` once it's been retried 3 times and left `pending` (to be picked up again) otherwise. If no rows were pending, the worker sleeps 2 seconds before polling again rather than hammering the database in a tight loop.

When this is the right call: you already run Django and Postgres, the workload doesn't need Temporal's durability guarantees, and you want zero new infrastructure. This is the same "DB-backed queue" trade-off covered in the system-design material, simple to operate and transactional with your business data, but with a throughput ceiling in the low thousands of jobs per second. The custom-worker version above is that same trade-off with hand-rolled retry logic instead of Celery's built-in version.

## Three-way summary

| | Custom DB worker | Celery | Temporal |
|---|---|---|---|
| Extra infra | None (reuses Postgres) | Redis | Temporal server + Postgres |
| Retry logic | Manual (a few lines) | Built in | Built in |
| Multi-step workflows | Manual orchestration | `chain`/`chord` | Native, durable, resumable |
| Visibility | Query the table directly | Flower UI | Temporal UI, per-step |
| Setup time | Fast, no new service | Fast | Slow, deploy the server stack first |
