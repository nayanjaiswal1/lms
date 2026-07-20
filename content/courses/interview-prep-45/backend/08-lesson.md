---
kind: lesson
id_key: interview-prep-45/day-08-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Day 8 — Celery and Task Queues"
position: 8
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
Week 2 starts with the piece that turns "call an API" into "run a real distributed system": task queues. Celery interview questions cluster around two things — idempotency and worker failure — because those are exactly the two things that break in production and never break in a demo. Today you set up Celery with a Redis broker, add retry with backoff, schedule periodic work, and answer both classic questions with actual mechanisms, not hand-waving.

## Celery architecture

Celery is a distributed task queue with three moving pieces:

- **Broker** (Redis or RabbitMQ) — a message queue that holds tasks waiting to run. The Celery client pushes a task message here; it doesn't run the task itself.
- **Worker(s)** — separate processes that pull messages off the broker and execute the task function. You can run many workers, on many machines, consuming from the same queue.
- **Result backend** (optional — Redis, a DB) — stores the return value/state of a task if you need to check on it later (`task.get()`, `task.status`).

```python
# celery_app.py
from celery import Celery

app = Celery(
    "myproject",
    broker="redis://localhost:6379/0",
    backend="redis://localhost:6379/1",  # separate DB index from the broker, good practice
)

app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone="UTC",
    enable_utc=True,
)
```

The client (your Django/FastAPI app) never talks directly to a worker — it serializes the task name and arguments into a message and publishes it to the broker. A worker somewhere, possibly on a different machine, picks it up whenever it's free. That decoupling is the entire point: the web request returns immediately, the actual work happens asynchronously and can be scaled independently of your web tier.

## Retry logic with exponential backoff

```python
from celery_app import app
from celery.exceptions import MaxRetriesExceededError
import requests

@app.task(
    bind=True,               # gives access to `self` — needed to call self.retry()
    max_retries=5,
    autoretry_for=(requests.RequestException,),  # auto-retry on these exceptions
    retry_backoff=True,      # exponential backoff: 1s, 2s, 4s, 8s...
    retry_backoff_max=60,    # cap the backoff delay
    retry_jitter=True,       # add randomness so retries from many failed tasks don't all fire at once
)
def send_webhook(self, url: str, payload: dict):
    response = requests.post(url, json=payload, timeout=5)
    response.raise_for_status()  # non-2xx raises requests.RequestException -> triggers autoretry
    return response.status_code
```

`retry_jitter` is the detail interviewers listen for: without jitter, if 1000 tasks fail at the same moment (e.g. a downstream service blip), they all retry at exactly the same backed-off intervals — a synchronized retry storm that can re-crash the service they're retrying against. Jitter spreads that storm out.

For cases needing custom retry logic instead of `autoretry_for`:

```python
@app.task(bind=True, max_retries=5)
def process_payment(self, payment_id: int):
    try:
        _charge_provider(payment_id)
    except TransientProviderError as exc:
        # exponential backoff computed manually: 2^retries seconds
        raise self.retry(exc=exc, countdown=2 ** self.request.retries)
    except PermanentProviderError:
        # don't retry — this will never succeed, fail loudly instead
        raise
```

## Idempotency — the #1 Celery interview question

**"How do you ensure idempotency?"** — because at-least-once delivery is Celery's default guarantee, not exactly-once. A task can run more than once: the worker might execute a task, crash before acknowledging it to the broker, and the broker redelivers it to another worker — now it's run twice.

The fix is making the task's *effect* idempotent, not trying to prevent redelivery (you can't, reliably):

```python
@app.task(bind=True, max_retries=3)
def charge_customer(self, order_id: int, idempotency_key: str):
    # Use a unique constraint or a Redis SETNX as a dedup guard BEFORE doing the side effect
    was_processed = redis_client.set(
        f"processed:{idempotency_key}", "1", nx=True, ex=86400
    )
    if not was_processed:
        return  # already handled this exact request — no-op, not an error

    order = Order.objects.get(id=order_id)
    payment_provider.charge(order.total, reference=idempotency_key)
    order.status = "paid"
    order.save()
```

Two standard mechanisms for this:

1. **Idempotency key + dedup store** (shown above) — the caller generates a unique key per logical operation (not per Celery retry), and the task checks a fast store (Redis `SETNX`, or a unique DB constraint) before performing the side effect.
2. **Natural idempotency** — design the operation so running it twice has the same result as running it once: `UPDATE orders SET status = 'shipped' WHERE id = %s` is naturally idempotent; `INSERT INTO shipments ...` is not, unless you add a unique constraint on `order_id` and catch the conflict.

## What happens when a worker dies

The second classic question. It depends on **acknowledgment mode**:

- **Late acknowledgment (`task_acks_late=True`)** — the worker acknowledges the message *after* the task finishes, not when it starts. If the worker crashes mid-task, the broker never received an ack, so it redelivers the message to another worker. Safer for critical work, but means a task that crashes the worker itself (OOM, segfault) will be retried — which is exactly why the task body must be idempotent.
- **Early acknowledgment (default)** — the worker acks as soon as it *starts* the task. If the worker dies mid-task, the message is gone — the task is silently lost. Fine for non-critical, best-effort work; wrong for anything that must complete.

```python
app.conf.task_acks_late = True
app.conf.worker_prefetch_multiplier = 1  # don't let one worker grab many tasks and hoard them if it's slow/crashing
```

`worker_prefetch_multiplier = 1` matters alongside late-ack: with the default prefetch, a worker can reserve several tasks at once, and if it crashes, *all* of those reserved-but-unstarted tasks are redelivered together, potentially all to another already-busy worker.

## Periodic tasks with Celery Beat

```python
# celery_app.py
from celery.schedules import crontab

app.conf.beat_schedule = {
    "cleanup-expired-sessions-every-hour": {
        "task": "myapp.tasks.cleanup_expired_sessions",
        "schedule": crontab(minute=0),  # top of every hour
    },
    "send-daily-digest": {
        "task": "myapp.tasks.send_daily_digest",
        "schedule": crontab(hour=8, minute=0),  # 08:00 UTC daily
    },
}
```

`celery beat` is a separate process from the workers — it's a scheduler that pushes tasks onto the broker at the configured times; the actual execution still goes through normal workers. Run exactly one `beat` process (or use a lock/leader-election if running it redundantly) — two `beat` processes will double-schedule everything.

## Setting up the broker and running it

```bash
# Redis as broker (docker-compose service, or local install)
docker run -d -p 6379:6379 redis:7

# Start a worker
celery -A celery_app worker --loglevel=info --concurrency=4

# Start beat for periodic tasks (separate process)
celery -A celery_app beat --loglevel=info
```

## Key takeaways

- Celery gives at-least-once delivery, not exactly-once — every task must be written to be safely re-runnable.
- Idempotency comes from a dedup key checked before the side effect, or from designing the operation itself to be naturally idempotent (UPDATE-style, unique constraints).
- `task_acks_late=True` protects against losing work when a worker crashes mid-task, but requires idempotent tasks since it also causes more retries.
- `retry_jitter=True` prevents synchronized retry storms when many tasks fail at once.
- `celery beat` schedules, workers execute — they're separate processes, and only one `beat` should run at a time.

## Today's checklist

- [ ] Read: Celery architecture documentation
- [ ] Set up Celery with a Redis broker
- [ ] Implement: task with retry logic
- [ ] Implement: task with exponential backoff
- [ ] Implement: schedule a periodic task with Celery Beat
- [ ] Be ready to answer: how do you ensure idempotency? What happens when a worker dies?
