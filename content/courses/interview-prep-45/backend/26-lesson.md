---
kind: lesson
id_key: interview-prep-45/day-26-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Async Pipelines"
position: 26
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Today is about moving work out of the request/response cycle and doing it reliably: multi-stage async processing, dead letter queues, partial failure handling, and the outbox pattern. This is the material that separates "I used Celery to send an email" from "I understand distributed system failure modes" — a favorite senior-level interview area.

## Async processing patterns

Three shapes come up repeatedly:

**Fire-and-forget task.** Request triggers work, doesn't wait for it. Simplest case — a Celery task or FastAPI `BackgroundTasks` call.

**Fan-out / fan-in.** One input splits into many parallel subtasks, then results are aggregated. Example: resize an uploaded image into 5 sizes in parallel, mark the upload "processed" once all 5 finish.

**Pipeline (multi-stage).** Output of stage N is the input of stage N+1, each stage independently scalable and retryable. Example: upload → virus scan → transcode → thumbnail → notify. This is the one today's tasks focus on.

```python
from celery import Celery, chain

app = Celery("pipeline", broker="redis://localhost:6379/0")


@app.task(bind=True, max_retries=3, default_retry_delay=10)
def scan_upload(self, file_id: str) -> str:
    if not virus_scan(file_id):
        raise ValueError(f"file {file_id} failed virus scan")
    return file_id


@app.task(bind=True, max_retries=3, default_retry_delay=10)
def transcode(self, file_id: str) -> str:
    try:
        run_transcode(file_id)
        return file_id
    except TranscodeError as exc:
        raise self.retry(exc=exc)


@app.task
def generate_thumbnail(file_id: str) -> str:
    make_thumbnail(file_id)
    return file_id


@app.task
def notify_owner(file_id: str) -> None:
    send_notification(file_id, "Your upload is ready")


def start_pipeline(file_id: str):
    # chain() links tasks so each stage's return value feeds the next
    pipeline = chain(
        scan_upload.s(file_id),
        transcode.s(),
        generate_thumbnail.s(),
        notify_owner.s(),
    )
    pipeline.apply_async()
```

Each stage is its own Celery task with its own retry policy — a transient transcode failure retries independently without re-running the (expensive) virus scan. That independence is the entire reason to build a pipeline instead of one giant function: **isolate failure domains and retry policy per stage.**

## Pipeline with multiple stages — handling partial failures

The interview question "how do you handle partial failures in a pipeline" is really asking: what happens when stage 3 of 5 fails, and what state is left behind?

Rules to follow:

1. **Each stage must be idempotent.** Retries will re-run a stage; running `generate_thumbnail` twice for the same file must not create two thumbnails or corrupt state. Use upserts (`ON CONFLICT DO UPDATE` in Postgres) rather than blind inserts.
2. **Track stage status explicitly**, don't infer it from task queue state (which disappears once a task completes/fails). A status row lets you query "what's stuck" and lets a stage resume from the last completed step instead of from scratch.

```python
import enum
from sqlalchemy import Column, String, Enum, DateTime, Integer
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class StageStatus(str, enum.Enum):
    PENDING = "pending"
    RUNNING = "running"
    DONE = "done"
    FAILED = "failed"


class PipelineRun(Base):
    __tablename__ = "pipeline_runs"
    id = Column(Integer, primary_key=True)
    file_id = Column(String, index=True)
    stage = Column(String)  # "scan" | "transcode" | "thumbnail" | "notify"
    status = Column(Enum(StageStatus), default=StageStatus.PENDING)
    attempts = Column(Integer, default=0)
    error = Column(String, nullable=True)
    updated_at = Column(DateTime)
```

3. **Decide per-stage: retry, skip, or fail the whole pipeline.** Not every failure deserves the same response — a transcode timeout retries; a corrupt/unsupported file format should fail fast and not retry 3 times uselessly.

```python
@app.task(bind=True, max_retries=3)
def transcode(self, file_id: str) -> str:
    run = get_or_create_run(file_id, stage="transcode")
    run.status = StageStatus.RUNNING
    run.attempts += 1
    db.commit()

    try:
        run_transcode(file_id)
    except UnsupportedFormatError as exc:
        # Not transient — retrying won't help, fail permanently
        run.status = StageStatus.FAILED
        run.error = str(exc)
        db.commit()
        raise  # let it hit the dead letter queue, don't retry
    except TranscodeTimeoutError as exc:
        # Transient — worth retrying with backoff
        db.commit()
        raise self.retry(exc=exc, countdown=2 ** self.request.retries)
    else:
        run.status = StageStatus.DONE
        db.commit()
        return file_id
```

The distinction between a **permanent** failure (bad input, don't retry) and a **transient** one (network blip, timeout, do retry with backoff) is the single most important design decision in any pipeline. Retrying a permanent failure just burns queue capacity and delays the DLQ signal that something needs a human.

## Dead letter queue (DLQ) handling

A DLQ is where messages/tasks go after they've exhausted retries or hit a permanent failure — instead of vanishing or retrying forever, they land somewhere a human or a monitor can inspect and act on.

```python
from celery import Celery
from celery.signals import task_failure

app = Celery("pipeline", broker="redis://localhost:6379/0")


@task_failure.connect
def handle_task_failure(sender=None, task_id=None, exception=None, args=None, kwargs=None, **extra):
    # Fires once a task has exhausted its retries (or raised without retrying)
    send_to_dead_letter_queue(
        task_name=sender.name,
        task_id=task_id,
        args=args,
        kwargs=kwargs,
        error=str(exception),
    )


def send_to_dead_letter_queue(task_name, task_id, args, kwargs, error):
    db.dead_letters.insert(
        task_name=task_name,
        task_id=task_id,
        payload={"args": args, "kwargs": kwargs},
        error=error,
        status="unresolved",
    )
    alert_on_call(f"Task {task_name} ({task_id}) dead-lettered: {error}")
```

With RabbitMQ/SQS-style brokers, DLQ is often a first-class feature — you configure a queue's max-retry count and a target DLQ, and the broker moves the message automatically. With Redis/Celery it's usually rolled by hand as above, or via `acks_late` + a max-retries exception handler.

What matters for the interview: **DLQ entries need a replay path.** A DLQ that's write-only is just a failure graveyard. Build (or at least describe) a way to inspect a dead-lettered task, fix the underlying issue, and re-enqueue it — often as an admin endpoint or CLI command that reads the stored `args`/`kwargs` and calls `task.apply_async(args=..., kwargs=...)` again.

## The outbox pattern

The problem: you often need to "update the database AND publish an event" atomically — e.g., create an order row and publish `OrderCreated` to Kafka/RabbitMQ. If you do these as two separate operations, there's a window where one succeeds and the other fails (DB commits, then the process crashes before the publish; or the publish succeeds but the DB transaction rolls back). Either way, consumers and your database disagree about reality.

The outbox pattern fixes this by writing the event to an **outbox table in the same database transaction** as the business data. A separate relay process reads unpublished outbox rows and publishes them, retrying until it succeeds — because the write to the DB is transactional, the event is guaranteed to exist if and only if the business data was committed.

```sql
CREATE TABLE outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type TEXT NOT NULL,
    aggregate_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    published_at TIMESTAMPTZ
);

CREATE INDEX idx_outbox_unpublished ON outbox (created_at) WHERE published_at IS NULL;
```

```python
def create_order(db_session, order_data: dict):
    with db_session.begin():  # single DB transaction
        order = Order(**order_data)
        db_session.add(order)
        db_session.flush()  # get order.id without committing

        db_session.add(Outbox(
            aggregate_type="order",
            aggregate_id=str(order.id),
            event_type="OrderCreated",
            payload={"order_id": str(order.id), "total": order.total},
        ))
    # Both rows commit together, or neither does.
    return order
```

```python
# Relay process — runs continuously, separate from the request path
def relay_outbox_events(db_session, publisher):
    unpublished = db_session.query(Outbox).filter(
        Outbox.published_at.is_(None)
    ).order_by(Outbox.created_at).limit(100)

    for event in unpublished:
        try:
            publisher.publish(event.event_type, event.payload)
            event.published_at = datetime.now(UTC)
            db_session.commit()
        except PublishError:
            db_session.rollback()
            break  # stop and retry this batch next tick; preserves ordering
```

This is sometimes paired with **Change Data Capture** (Debezium reading the DB's write-ahead log) instead of a polling relay, which avoids polling overhead and catches the outbox insert the moment it's committed — worth mentioning as the "at scale" version if asked.

## Reliable event publishing — putting it together

Combine outbox (atomicity with the DB write) with idempotent consumers (safety against duplicate delivery, since "at least once" is the best guarantee outbox + retry can offer — a crash between publish and marking `published_at` can cause a duplicate publish):

```python
def handle_order_created(event: dict, db_session):
    event_id = event["event_id"]

    # Idempotency: consumer-side dedupe table, unique constraint does the work
    already_processed = db_session.query(ProcessedEvent).filter_by(
        event_id=event_id
    ).first()
    if already_processed:
        return  # duplicate delivery, safely ignored

    with db_session.begin():
        fulfill_order(event["order_id"])
        db_session.add(ProcessedEvent(event_id=event_id, processed_at=datetime.now(UTC)))
```

The combination — transactional outbox on the producer, idempotent handling keyed on event ID on the consumer — is what "reliable event publishing" means in practice: not zero duplicates, but zero *lost* events and safe handling of the duplicates that do occur.

## Key takeaways

- Multi-stage pipelines isolate failure domains: each stage gets its own retry policy, and a transient failure in stage 3 shouldn't force stage 1 to re-run.
- Distinguish permanent failures (bad input — fail fast, don't retry) from transient ones (timeout/network — retry with backoff). Conflating them wastes queue capacity or drops real errors.
- Every stage must be idempotent, because retries and DLQ replays will re-run it.
- A DLQ without a replay path is just a graveyard — the interview-relevant part is how a dead-lettered task gets fixed and re-enqueued.
- The outbox pattern solves "DB write + event publish must be atomic" by writing the event in the same transaction as the business data, then relaying it out-of-band.
- Outbox delivery is "at least once," never "exactly once" — pair it with idempotent, event-ID-keyed consumers for true reliability.
