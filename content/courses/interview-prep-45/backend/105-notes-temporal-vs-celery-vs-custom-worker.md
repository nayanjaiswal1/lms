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

Day 8/19 cover Celery in depth, and `system-design/08-lesson.md` (Job Queue System) already covers the DB-backed queue pattern — `SELECT ... FOR UPDATE SKIP LOCKED` for safe concurrent polling, the jobs table schema, and the DB-vs-Redis-vs-SQS-vs-Kafka trade-off table. What's new here: Temporal as a third option, and the decision framework for picking between all three when the workload is multi-step AI/document processing (parse → chunk → AI calls → generate) rather than a simple fire-and-forget task.

## Temporal, in one paragraph

Temporal is a workflow orchestration engine: you write a "workflow" function in a normal-looking language (Python, Go, ...) that calls "activities" (the actual side-effecting work), and Temporal's server persists the workflow's execution state durably at every step. If a worker crashes mid-workflow, a new worker resumes from the last completed activity — not from the start. This is the specific thing Celery/a plain task queue doesn't give you: durable, resumable *multi-step* state, plus a UI showing exactly which step a given execution is on.

## Resource footprint — the honest trade-off

| | Celery | Temporal |
|---|---|---|
| Components | Redis + worker process | Temporal server + Postgres + UI + worker |
| Idle RAM | ~150MB | ~1GB |
| Setup | `pip install`, write tasks, run worker | Deploy the Temporal server stack first, then write workflows |

Temporal is roughly 6-7x heavier idle, and has real setup cost before any application code runs. This matters concretely on a small cluster (say, under 4GB total RAM) — Temporal can eat a large fraction of the box before the actual app starts.

## Decision framework

| Situation | Use |
|---|---|
| Simple, independent tasks (send an email, generate a thumbnail) | Celery — Day 8/19's pattern is the right level of complexity |
| Small cluster / limited resources | Celery |
| Multi-step pipeline with fan-out and a need for step-by-step visibility/resumability | Temporal — this is what it's built for |
| Tasks complete in seconds | Celery — no need for durable per-step state |
| Tasks run for minutes and must survive a worker crash mid-way | Temporal — state persistence is the actual point |
| Team wants low ops overhead now, may grow into complex workflows | Start Celery, migrate the specific workflow that needs it later — not the whole system upfront |

A pipeline like "get document → parse → chunk → AI calls → generate output → generate questions" is exactly the multi-step, fan-out shape Temporal is designed for — but if the cluster is resource-constrained, that's a real cost against reaching for it immediately.

**Lightweight middle ground:** if you're on Celery already and just want task history without adding Redis-as-result-store weight, point the result backend at your existing Postgres instead:

```python
# settings.py
CELERY_RESULT_BACKEND = "django-db"   # reuses your existing Postgres, not Redis
CELERY_BROKER_URL = "redis://redis:6379/0"
```

You still need Redis as the broker (something has to hold the pending-task queue), but results/history ride on infrastructure you already run.

## The "build your own worker" option

`system-design/08-lesson.md` already covers the core mechanic (a `jobs` table, workers claiming rows via `SELECT ... FOR UPDATE SKIP LOCKED` so multiple worker processes never double-process the same row). The concrete shape of that as a Django+asyncio worker, useful to have ready for a live-coding round:

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

When this is the right call: you already run Django + Postgres, the workload doesn't need Temporal's durability guarantees, and you want zero new infrastructure. `system-design/08`'s trade-off table already frames this as "DB-backed queue: simple ops, transactional with business data, but a throughput ceiling in the low thousands/sec" — the custom-worker version above is that same trade-off with hand-rolled retry logic instead of Celery's built-in version.

## Three-way summary

| | Custom DB worker | Celery | Temporal |
|---|---|---|---|
| Extra infra | None (reuses Postgres) | Redis | Temporal server + Postgres |
| Retry logic | Manual (a few lines) | Built in | Built in |
| Multi-step workflows | Manual orchestration | `chain`/`chord` | Native, durable, resumable |
| Visibility | Query the table directly | Flower UI | Temporal UI, per-step |
| Setup time | Fast — no new service | Fast | Slow — deploy the server stack first |

## Key takeaways

- Temporal's value is durable, resumable *multi-step* execution state with per-step visibility — that's what neither Celery nor a custom DB-polling worker gives you out of the box.
- Temporal costs roughly 6-7x the idle resources of Celery, plus real setup complexity — a real trade-off on a small cluster, not a strictly-better choice.
- A custom DB-polling worker (`SELECT ... FOR UPDATE SKIP LOCKED`, already covered in `system-design/08`) is a legitimate production choice when you already run Postgres and don't need Temporal-grade durability — zero new infrastructure, manual retry logic.
- `CELERY_RESULT_BACKEND = "django-db"` gets task history without adding Redis-as-result-store weight, while still needing Redis as the broker itself.
