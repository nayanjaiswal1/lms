---
kind: lesson
id_key: interview-prep-45/day-08-backend
course: interview-prep-45
section: backend-systems
section_title: "Caching, Queues & Distributed Systems"
section_position: 10
section_group: "Backend"
title: "Celery and Background Workers"
position: 3
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---

Picture a waiter who takes your order, then stands at your table while the kitchen cooks it, blocking every other customer from being served. That is a web server that does slow work inside the request itself: sending an email, generating a report, running a model. Once one request takes 10 seconds, everything behind it queues up too. A background worker is the fix: the waiter drops your order in the kitchen and immediately moves to the next table.

Celery is the standard Python answer to this problem, and interviews push past "I used `@shared_task`" into the two things that actually break in production: a task running twice, and a worker dying mid-task. This lesson builds both answers with real mechanisms, then covers routing, chains, and how Celery compares to a couple of common alternatives.

## Celery's moving pieces

Celery has three parts:

- **Broker** (Redis or RabbitMQ): a message queue holding tasks waiting to run. Your app pushes a task message here; it never runs the task itself.
- **Worker(s)**: separate processes that pull messages off the broker and execute the task function. You can run many workers, on many machines, all consuming from the same queue.
- **Result backend** (optional: Redis, a database): stores a task's return value and state, if something later needs to check on it.

```python
from celery import Celery

app = Celery(
    "myproject",
    broker="redis://localhost:6379/0",
    backend="redis://localhost:6379/1",   # a separate Redis DB index from the broker
)
```

The web app never talks to a worker directly. It serializes the task's name and arguments into a message and publishes it to the broker. Some worker, possibly on a different machine, picks it up whenever it's free. That decoupling is the entire point: the request returns immediately, and the real work scales independently of your web tier.

> **Remember:** the broker holds pending work, the worker runs it, and the result backend (if configured) remembers what happened. The web app only ever talks to the broker.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-celery-architecture-q1", "type": "mcq",
      "prompt": "In a Celery setup, what does the web application actually do when it calls a task?",
      "options": [
        {"id":"a","text":"It runs the task function directly in the request thread"},
        {"id":"b","text":"It serializes the task name and arguments into a message and publishes it to the broker, then returns immediately without waiting for the work to finish"},
        {"id":"c","text":"It opens a direct network connection to a specific worker process"},
        {"id":"d","text":"It writes the task's code to disk for a worker to compile later"}
      ],
      "correct": "b",
      "explanation": "The web app is decoupled from execution entirely. It hands a message to the broker and moves on; whichever worker is free picks the message up later." }
] }
```

## Retry with backoff, and why jitter matters

```python
@app.task(
    bind=True,
    max_retries=5,
    autoretry_for=(requests.RequestException,),
    retry_backoff=True,        # 1s, 2s, 4s, 8s...
    retry_backoff_max=60,
    retry_jitter=True,         # randomize so many failed tasks don't retry in lockstep
)
def send_webhook(self, url: str, payload: dict):
    response = requests.post(url, json=payload, timeout=5)
    response.raise_for_status()
    return response.status_code
```

`retry_jitter` is the detail interviewers listen for. Without it, if 1,000 tasks fail at the same moment, say a downstream service blips, they all retry at exactly the same backed-off intervals, producing a synchronized retry storm that can re-crash the very service they're retrying against. Jitter spreads that storm out over time instead.

For cases needing custom logic instead of `autoretry_for`:

```python
@app.task(bind=True, max_retries=5)
def process_payment(self, payment_id: int):
    try:
        _charge_provider(payment_id)
    except TransientProviderError as exc:
        raise self.retry(exc=exc, countdown=2 ** self.request.retries)
    except PermanentProviderError:
        raise  # this will never succeed no matter how many times you retry — fail loudly
```

> **Remember:** add jitter to every backoff. Without it, a thousand tasks failing together retry together, turning a blip into a second, synchronized outage.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-celery-retry-q1", "type": "mcq",
      "prompt": "1,000 Celery tasks fail at the same instant because a downstream service is briefly overloaded. Why does retry_jitter matter here?",
      "options": [
        {"id":"a","text":"Without jitter, all 1,000 tasks retry at the exact same backed-off intervals, creating a synchronized retry storm that can re-crash the recovering service"},
        {"id":"b","text":"Jitter makes each individual retry succeed"},
        {"id":"c","text":"Jitter is only relevant for tasks that never fail"},
        {"id":"d","text":"Without jitter, Celery refuses to retry at all"}
      ],
      "correct": "a",
      "explanation": "Backoff alone spaces out one task's own retries, but if every task computes the same delay from the same failure moment, all of them still retry together. Jitter breaks that synchronization." }
] }
```

## Idempotency: the number one Celery interview question

The premise behind "how do you ensure idempotency" is that Celery's default guarantee is at-least-once delivery, not exactly-once. A worker can execute a task, crash before acknowledging it to the broker, and the broker redelivers it to another worker: now it has run twice.

The fix is making the task's *effect* idempotent, not trying to prevent redelivery, which you can't reliably do:

```python
@app.task(bind=True, max_retries=3)
def charge_customer(self, order_id: int, idempotency_key: str):
    # dedup guard BEFORE the side effect, not after
    was_processed = redis_client.set(f"processed:{idempotency_key}", "1", nx=True, ex=86400)
    if not was_processed:
        return  # already handled this exact request — no-op, not an error

    order = Order.objects.get(id=order_id)
    payment_provider.charge(order.total, reference=idempotency_key)
    order.status = "paid"
    order.save()
```

Two standard mechanisms: an **idempotency key plus a dedup store** (shown above, checked before the side effect happens), or **natural idempotency**, designing the operation so running it twice has the same result as running it once. `UPDATE orders SET status = 'shipped' WHERE id = %s` is naturally idempotent. `INSERT INTO shipments ...` is not, unless you add a unique constraint on `order_id` and catch the conflict.

> **Remember:** you can't reliably stop a redelivery, so the dedup check happens before the side effect, using a key generated once by the caller, not once per retry.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-celery-idempotency-q1", "type": "mcq",
      "prompt": "Why does the dedup check in charge_customer() happen before payment_provider.charge(), rather than after?",
      "options": [
        {"id":"a","text":"Order doesn't matter, since Redis is always fast enough"},
        {"id":"b","text":"If the check ran after the charge, a redelivered task would charge the customer again before the dedup key ever got set, defeating the whole purpose of the guard"},
        {"id":"c","text":"Checking after would make the function run faster"},
        {"id":"d","text":"Celery requires all Redis calls to happen at the start of a task"}
      ],
      "correct": "b",
      "explanation": "The guard has to block the side effect itself. Checking or setting the dedup key after the charge already happened would let a redelivered task charge the customer a second time before the guard ever takes effect." }
] }
```

## What happens when a worker dies

This depends entirely on **acknowledgment mode**.

- **Early ack (the default)**: the worker acks the message as soon as it *starts* the task. If the worker dies mid-task, the message is already gone from the broker: the task is silently lost. Fine for best-effort, non-critical work.
- **Late ack (`task_acks_late=True`)**: the worker acks only *after* the task finishes. If the worker crashes mid-task, the broker never got an ack, so it redelivers the message to another worker. Safer for critical work, but it means a task that crashes the worker itself will be retried, which is exactly why the task body must be idempotent.

```python
app.conf.task_acks_late = True
app.conf.worker_prefetch_multiplier = 1   # don't let a slow/crashing worker hoard several tasks at once
```

`worker_prefetch_multiplier = 1` matters alongside late-ack: with the default prefetch, a worker reserves several tasks at once, and if it crashes, *all* of those reserved-but-unstarted tasks get redelivered together, potentially all landing on one already-busy worker.

> **Remember:** early ack can silently lose a task on worker crash; late ack redelivers it but requires the task to be idempotent. Pick late ack plus `prefetch_multiplier=1` for anything that must actually complete.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-celery-ack-q1", "type": "mcq",
      "prompt": "task_acks_late=True is set, and a worker crashes halfway through a task. What happens?",
      "options": [
        {"id":"a","text":"The task is lost permanently, since the ack already happened"},
        {"id":"b","text":"The broker never received an ack, so it redelivers the task to another worker, meaning the task body must be safe to run again"},
        {"id":"c","text":"Celery automatically pauses all other tasks until the crash is investigated"},
        {"id":"d","text":"The task result backend deletes the task record"}
      ],
      "correct": "b",
      "explanation": "Late ack only confirms completion after the task finishes. A crash mid-task means no ack was ever sent, so the broker treats the message as undelivered and hands it to another worker, which can re-run a task that already did partial work." }
] }
```

## Task routing and priority queues

By default every task goes to one queue and any worker can pick it up. Routing sends different tasks to different queues, so a dedicated pool of workers can handle slow tasks (video processing) separately from fast ones (sending an email). Otherwise, one slow task blocks a worker that could have cleared ten fast ones in the meantime.

```python
task_routes = {
    "orders.tasks.send_receipt_email": {"queue": "fast"},
    "orders.tasks.generate_invoice_pdf": {"queue": "slow"},
}
```

```bash
celery -A myproject worker -Q fast --concurrency=8 -n fast@%h
celery -A myproject worker -Q slow --concurrency=2 -n slow@%h
```

Celery has no true priority *within* a queue on Redis by default; it's FIFO. To get priority, either run separate queues per priority tier, as shown above, or switch to RabbitMQ as the broker, which supports a real per-message priority field. The interview answer: "priority" in Celery is almost always implemented as queue separation, not a priority field, because the default broker doesn't support message priority at all.

**Chains** run tasks sequentially, each one receiving the previous task's return value. **Chords** run a group of tasks in parallel, then fire a callback once every one of them finishes, with their results collected as a list.

```python
from celery import chain, chord

pipeline = chain(fetch_data.s(source_id=1), transform.s(), save_result.s())
pipeline.apply_async()

job = chord(
    [resize_image.s(image_id=99, size=s) for s in ("small", "medium", "large")],
    notify_all_sizes_ready.s(upload_id=42),
)
job.apply_async()
```

A chord's callback is itself just another task. Celery tracks completion with a counter in the result backend, decrementing it as each group member finishes and firing the callback at zero. **This is why a chord requires a result backend**: without one, there is no way to know when the group is actually done.

> **Remember:** "priority" in Celery usually means separate queues, not a priority field, because the default broker (Redis) doesn't support one. A chord needs a result backend to know when its group is finished.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-celery-routing-q1", "type": "mcq",
      "prompt": "Why does a Celery chord require a result backend, while a simple fire-and-forget task does not?",
      "options": [
        {"id":"a","text":"Chords must know when every task in the group has finished, which Celery tracks with a counter stored in the result backend"},
        {"id":"b","text":"Result backends are required for every Celery task, chord or not"},
        {"id":"c","text":"Chords cannot use Redis as a broker without a result backend"},
        {"id":"d","text":"A chord's callback runs before the group tasks, so it needs a place to store their future arguments"}
      ],
      "correct": "a",
      "explanation": "The callback only fires once every task in the group is done. Celery has no other way to detect group-wide completion except tracking a countdown in the result backend as each member finishes." }
] }
```

## Custom task states, periodic tasks, and the result backend

Beyond Celery's built-in states, `update_state` reports custom progress, essential for a long task a frontend needs to show progress for.

```python
@app.task(bind=True)
def generate_report(self, report_id):
    rows = fetch_rows(report_id)
    for i, row in enumerate(rows):
        process_row(row)
        if i % 100 == 0:
            self.update_state(state="PROGRESS", meta={"current": i, "total": len(rows)})
    return {"report_id": report_id, "rows_processed": len(rows)}
```

The **result backend** (commonly Redis or Postgres) is where Celery writes task state and return values, separate from the **broker**, which only queues the task messages themselves. Without a result backend, `task.delay()` still runs the task, but `AsyncResult.status` stays `PENDING` forever and `.get()` hangs, because there's nowhere for the answer to be written.

Periodic tasks run through `celery beat`, a separate scheduler process that pushes tasks onto the broker at configured times; actual execution still goes through normal workers.

```python
from celery.schedules import crontab

app.conf.beat_schedule = {
    "cleanup-expired-sessions-every-hour": {
        "task": "myapp.tasks.cleanup_expired_sessions",
        "schedule": crontab(minute=0),
    },
}
```

Run exactly one `beat` process. Two of them will double-schedule everything.

> **Remember:** the broker queues messages; the result backend stores outcomes. They're conceptually separate even when both point at the same Redis instance, and only one of them tells you whether a task is done.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-celery-resultbackend-q1", "type": "mcq",
      "prompt": "No result backend is configured. A task is sent with task.delay(). What happens?",
      "options": [
        {"id":"a","text":"The task never runs at all"},
        {"id":"b","text":"The task runs normally, but AsyncResult has nowhere to read status or return value from, so .status stays PENDING and .get() hangs"},
        {"id":"c","text":"Celery raises a configuration error at startup"},
        {"id":"d","text":"The broker itself stores and returns the result automatically"}
      ],
      "correct": "b",
      "explanation": "The broker only delivers the task message; it is not built to store outcomes. Without a result backend configured, there's no destination for status or return value, so checking on the task from the caller side never resolves." }
] }
```

## Choosing between Celery, Temporal, and a custom worker

Celery is not the only option, and knowing when to reach for something else is itself an interview-worthy answer.

**Temporal** is a workflow orchestration engine. You write a workflow function that calls "activities," the actual side-effecting steps, and Temporal's server durably persists execution state after every step. If a worker crashes mid-workflow, a new worker resumes from the last completed activity, not from the start. That's the specific thing Celery doesn't give you: durable, resumable, *multi-step* state, plus a UI showing exactly which step a given execution is on. The cost is real: Temporal needs its own server plus Postgres plus a UI, roughly 6-7x heavier at idle than a Redis-plus-worker Celery setup, which matters on a small cluster.

**A custom DB-backed worker** claims rows from a `jobs` table using `SELECT ... FOR UPDATE SKIP LOCKED`, so multiple worker processes never double-process the same row:

```python
async def run_worker(concurrency=5):
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

`skip_locked=True` is the key detail: a second worker running the same loop skips rows this one already locked, instead of blocking on them. This option needs zero new infrastructure if you already run Postgres, at the cost of hand-rolled retry logic and a throughput ceiling in the low thousands of jobs per second.

| | Custom DB worker | Celery | Temporal |
|---|---|---|---|
| Extra infra | None (reuses Postgres) | Redis | Temporal server + Postgres |
| Retry logic | Manual | Built in | Built in |
| Multi-step workflows | Manual orchestration | `chain` / `chord` | Native, durable, resumable |
| Setup time | Fast | Fast | Slow: deploy the server stack first |

The decision framework: simple, independent tasks (send an email, resize an image) or a small, resource-constrained cluster both point at Celery. A multi-step pipeline needing step-by-step visibility and resumability across a crash, parse, chunk, run AI calls, generate output, points at Temporal. A team that wants low overhead now but may grow into complex workflows later should start with Celery and migrate only the specific workflow that outgrows it, rather than moving the whole system upfront.

> **Remember:** Celery for simple or independent tasks; Temporal for multi-step workflows that must resume from the last completed step after a crash. Start simple and migrate the one workflow that outgrows it, not the whole system.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-celery-temporal-q1", "type": "mcq",
      "prompt": "A pipeline parses a document, chunks it, runs several AI calls, and generates output, and it must resume from the last completed step if a worker crashes mid-way. Which tool is actually built for this?",
      "options": [
        {"id":"a","text":"Celery, since chain() already covers this case identically"},
        {"id":"b","text":"Temporal, since it durably persists state after every step and resumes a crashed workflow from the last completed activity, not from the start"},
        {"id":"c","text":"A custom DB-backed worker, since SELECT FOR UPDATE SKIP LOCKED provides the same durability guarantee"},
        {"id":"d","text":"None of these tools can express a multi-step pipeline"}
      ],
      "correct": "b",
      "explanation": "Celery's chain restarts a whole chain from scratch on worker loss unless you build resumability yourself. Temporal's entire design is durable, step-by-step state that survives a crash, which is exactly this scenario." }
] }
```

## BullMQ: the same idea in Node

BullMQ is a Redis-backed job queue for Node.js, the JavaScript-ecosystem equivalent of Celery. The core idea is identical: move slow work out of the request/response cycle onto workers pulling from a shared queue.

```js
import { Queue, Worker } from 'bullmq';

const connection = { host: 'localhost', port: 6379 };
const emailQueue = new Queue('emails', { connection });

await emailQueue.add('welcome-email', { userId: 42 }, {
  attempts: 3,
  backoff: { type: 'exponential', delay: 1000 },
});

new Worker('emails', async (job) => {
  await sendWelcomeEmail(job.data.userId);
}, { connection });
```

`emailQueue.add` pushes the job onto a Redis-backed structure and returns immediately, without waiting for the email to send. A separate `Worker` process, possibly on a different machine, picks it up, runs the callback, and if it throws, BullMQ retries automatically using the configured exponential backoff, up to the `attempts` limit. What BullMQ adds over a plain Redis list: delayed jobs, automatic retries with backoff, priority queues, and per-queue rate limiting, the same category of feature Celery gives Python. A candidate coming from Python can map BullMQ concepts onto Celery concepts almost one to one: `Queue.add` is `task.delay()`, `attempts`/`backoff` is `autoretry_for`/`retry_backoff`, and a `Worker` is a Celery worker process.

> **Remember:** BullMQ is Celery's Node equivalent: a Redis-backed queue, a worker pool, and built-in retries with backoff. The concepts transfer almost directly between the two ecosystems.

```knowledge-check
{ "questions": [
    { "id": "backend-systems-celery-bullmq-q1", "type": "mcq",
      "prompt": "A Python engineer new to Node sees BullMQ's { attempts: 3, backoff: { type: 'exponential' } } option. What is the closest Celery equivalent?",
      "options": [
        {"id":"a","text":"task_routes"},
        {"id":"b","text":"max_retries plus retry_backoff=True, since both configure automatic retry count and exponential spacing"},
        {"id":"c","text":"beat_schedule"},
        {"id":"d","text":"There is no equivalent concept in Celery"}
      ],
      "correct": "b",
      "explanation": "Both BullMQ's attempts/backoff and Celery's max_retries/retry_backoff configure the same thing: how many times to retry a failed job, and how to space those retries out." }
] }
```
