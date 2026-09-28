---
kind: lesson
type: system_design
id_key: interview-prep-45/day-03-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design a Notification Service"
position: 3
estimated_minutes: 70
source:
    - 45-day-interview-roadmap.md
---

A notification service takes one event ("order shipped") and delivers it to a user across email, SMS, and push, while respecting what that user actually wants to receive. It's one of the most common real-world backend problems, so interviewers reach for it often: it tests whether you reach for a queue instead of a blocking call, whether you understand at-least-once delivery, and whether your retry logic protects a struggling downstream provider instead of hammering it.

## Requirements

**Functional requirements**
- Send notifications through multiple channels: email, SMS, push.
- Support templated messages, e.g. "Your order {{order_id}} has shipped."
- Track delivery status per notification: queued, sent, delivered, failed.
- Let other internal services trigger a notification through an API or event.
- Respect per-user, per-channel preferences (opted out of SMS, quiet hours) and let users unsubscribe from a category or from everything.

**Non-functional requirements**
- Reliability: a notification must never be silently lost.
- Ordering: for one user, notifications should generally land in the order they were triggered. A "payment failed" alert shouldn't arrive after a "payment succeeded" one that fired later.
- Retry logic: transient failures (a timeout, a 500 from the SMS gateway) must retry with backoff, not just get dropped.
- Unsubscribes must take effect immediately, checked at the moment of sending, not just flipped in a settings screen. This is a legal requirement (CAN-SPAM, TCPA, GDPR), not just good UX.
- Scale to millions of sends a day, each channel bound by its own provider rate limit.

> **Remember:** unsubscribe enforcement is one of the few places in system design where "eventually consistent" is the wrong answer. The cost of getting it wrong is regulatory, not just a bad user experience.

```knowledge-check
{ "questions": [
    { "id": "system-design-notifications-requirements-q1", "type": "mcq", "prompt": "Why must an unsubscribe be checked at the moment a notification is sent, rather than only when a user toggles a setting?", "options": [
        {"id": "a", "text": "Because checking earlier is technically impossible"},
        {"id": "b", "text": "Because a notification already queued before the unsubscribe could otherwise still go out, which is a compliance failure"},
        {"id": "c", "text": "Because users never actually mean to unsubscribe"},
        {"id": "d", "text": "Because it makes the API simpler"}
    ], "correct": "b", "explanation": "A batch send can be mid-flight when a user unsubscribes. Checking at send time, not just at enqueue time, is what actually stops that message from going out." }
] }
```

## Estimates

Assume 100 million users, each getting about 3 notifications a day across all channels: 300 million sends/day.

- **Average rate:** 300,000,000 / 86,400 ≈ 3,500/sec, with bursts 10-50x higher during a mass event like an incident alert or a marketing campaign.
- **Channel split (illustrative):** about 70% push (cheap, high volume), 25% email (moderate cost), 5% SMS (expensive per message, tightly capped by carriers). This spread is exactly why you throttle each channel independently instead of treating "notifications" as one undifferentiated stream.
- **Provider limits are usually the real bottleneck.** An SMS gateway might cap you at a few hundred messages/sec per account. That external ceiling, not your own servers, decides your SMS throughput.
- **Storage:** a notification record is about 1 KB. At 300M/day, that's 300 GB/day. Archive records older than a few months to cheap cold storage rather than keeping everything in the hot database forever.

## API

```
POST /notifications/send    { user_id, category, template_id, data, channels?: ["push","email"] }
  -> { notification_id, status: "queued" }

GET  /notifications/{id}/status                -> { status, per_channel: {push: "delivered", email: "sent"} }

POST /preferences/{user_id}     { category, channel, enabled: bool }
GET  /preferences/{user_id}                      -> { preferences[] }
POST /unsubscribe                { user_id, category? }   -- category omitted = unsubscribe all
```

Callers send a logical `category` (`security_alert`, `order_update`, `marketing`), not a specific channel. The notification service resolves the actual channel(s) from the user's own preferences, so the triggering service never has to know what that user wants.

Every request also carries an `idempotency_key` (for example `order-123-shipped`). If a caller retries the trigger call, the service upserts on that key instead of creating a duplicate notification.

## Data model

```
notifications        id, user_id, category, template_id, data, created_at, status
notification_deliveries  notification_id, channel, status (queued|sent|delivered|failed|
                      suppressed), provider_ref, attempted_at, delivered_at
templates             id, category, channel, subject_template, body_template
preferences           user_id, category, channel, enabled (bool)
unsubscribes          user_id, category (NULL = all), unsubscribed_at
```

`notification_deliveries` holds one row per (notification, channel). One logical notification can fan out into several delivery attempts, each tracked and retried on its own, so a failed SMS send doesn't affect the email send for the same event.

## High-level design

```
Triggering service --> POST /notifications/send
                              |
        Notification service: resolve preferences + unsubscribes
        --> determine eligible channels --> render template with data
                              |
        write notification_deliveries row(s), status=queued
                              |
     push to per-channel job queues (one queue per channel, so a slow
     or rate-limited channel never blocks the others)
                              |
    +-------------------------+-------------------------+
    v                         v                         v
Push worker pool       Email worker pool           SMS worker pool
(calls APNs/FCM)       (calls SES/SendGrid)        (calls Twilio-style)
    v                         v                         v
        delivery receipt / webhook --> update notification_deliveries.status
```

Picture three separate conveyor belts, one per channel, instead of one shared belt. If SMS is slow because a carrier is rate-limiting you, that belt backs up on its own, while push and email keep moving. That's the single most important structural decision in this design: **per-channel queues, not one shared queue.**

## Deep dives

### Why does each channel need its own queue and worker pool?

If every channel shared one queue, a burst of bulk marketing email could sit in front of a time-sensitive OTP SMS, or a slow email provider could back up push notifications that have nothing to do with email. Splitting the queue by channel means each one scales and degrades independently, matched to that channel's own provider limits. Inside a channel, a priority sub-queue keeps security-critical sends (a login code) ahead of bulk sends (a newsletter).

> **Remember:** isolate queues at the same boundary where your external rate limits live. If SMS has its own cap, SMS needs its own queue.

```knowledge-check
{ "questions": [
    { "id": "system-design-notifications-queues-q1", "type": "mcq", "prompt": "Why split notification queues by channel instead of using one shared queue for push, email, and SMS?", "options": [
        {"id": "a", "text": "Separate queues are always faster no matter the traffic pattern"},
        {"id": "b", "text": "So a rate-limited or slow channel, like SMS, can't back up unrelated channels like push"},
        {"id": "c", "text": "Because a single queue cannot hold more than one message type"},
        {"id": "d", "text": "To save on storage costs"}
    ], "correct": "b", "explanation": "Each channel has its own external rate limit and failure pattern. A shared queue lets the worst-behaved channel slow down every other channel too." }
] }
```

### How does retry with backoff actually work?

Distinguish two kinds of failure. A **transient** error (timeout, a 5xx, a rate limit) is worth retrying. A **permanent** error (invalid phone number, malformed payload) is not, retrying it five times just wastes time before the message reaches the dead-letter queue anyway.

```python
import random
import time

MAX_ATTEMPTS = 5
BASE_DELAY_SECONDS = 1.0


class ProviderTransientError(Exception):
    """Retryable: timeout, 5xx, rate limit."""


class ProviderPermanentError(Exception):
    """Not retryable: invalid recipient, malformed payload."""


def send_with_retry(notification: dict, send_fn) -> str:
    """Returns 'sent' or raises after exhausting retries, so the caller can
    route to a dead-letter queue instead of losing the message."""
    last_err: Exception | None = None
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            send_fn(notification)  # idempotency_key passed through to the provider
            return "sent"
        except ProviderPermanentError:
            raise  # no point retrying a malformed request
        except ProviderTransientError as err:
            last_err = err
            if attempt == MAX_ATTEMPTS:
                break
            # exponential backoff with jitter, so a fleet of workers retrying
            # the same failing provider doesn't hammer it in lockstep
            delay = BASE_DELAY_SECONDS * (2 ** (attempt - 1))
            delay += random.uniform(0, delay * 0.1)
            time.sleep(delay)
    raise RuntimeError(f"exhausted retries, routing to dead-letter: {last_err}")


if __name__ == "__main__":
    calls = {"n": 0}

    def flaky_send(notification: dict) -> None:
        calls["n"] += 1
        if calls["n"] < 3:
            raise ProviderTransientError("simulated timeout")

    assert send_with_retry({"id": "abc"}, flaky_send) == "sent"
    assert calls["n"] == 3

    def always_permanent(notification: dict) -> None:
        raise ProviderPermanentError("invalid phone number")

    try:
        send_with_retry({"id": "def"}, always_permanent)
        assert False, "expected raise"
    except ProviderPermanentError:
        pass
    print("ok")
```

The jitter matters as much as the backoff itself. Without it, every worker retrying against the same degraded provider backs off in lockstep and re-hammers it at the exact same instant it starts to recover. Pair this with a **circuit breaker** per provider: after N consecutive failures, stop sending to that provider for a while and fail fast to the dead-letter queue or a fallback provider, instead of letting worker threads pile up waiting on a service you already know is down.

After `max_attempts` is exceeded, move the notification to a dead-letter queue for a human or automated process to inspect, fix, and requeue. Never retry forever: a permanently broken payload retried endlessly wastes capacity and hides real outages in your dashboards.

### Why do templates get rendered at send time, not trigger time?

Store templates with versioned placeholders (`{{order_id}}`) and render them right before sending, not when the event first fires. If a message sits in the queue for a while, this guarantees the latest template and branding get used, not a stale version. Support per-locale variants (`shipped_en`, `shipped_es`) keyed by the user's locale.

### Why is delivery confirmation different per channel?

This is worth naming out loud, because treating all three channels as equally observable is a common mistake:
- **Push** has real delivery receipts. APNs and FCM report back whether the device actually got the message.
- **Email** has deliverability signals (bounce, complaint) but "delivered" usually just means "accepted by the recipient's mail server," not "the person read it."
- **SMS** is the most opaque. Many carriers never reliably report final delivery, so "accepted by the provider" is often the practical ceiling of what you can confirm.

For a genuinely critical alert, don't rely on one channel's guarantee alone: if no delivery confirmation arrives within a few minutes for a high-priority category, fire a second channel (push, then email) as a fallback.

```knowledge-check
{ "questions": [
    { "id": "system-design-notifications-delivery-q1", "type": "mcq", "prompt": "Why can't you treat push, email, and SMS as equally reliable at confirming delivery?", "options": [
        {"id": "a", "text": "They all use the exact same confirmation mechanism, so there's no difference"},
        {"id": "b", "text": "Push has real device-level receipts, email only confirms the mail server accepted it, and SMS delivery confirmation from carriers is often unreliable"},
        {"id": "c", "text": "SMS is always more reliable than push"},
        {"id": "d", "text": "Delivery confirmation is not possible on any channel"}
    ], "correct": "b", "explanation": "Each channel gives you a different level of proof that the message actually reached the person, and a strong design states that difference instead of assuming uniform reliability." }
] }
```

## Trade-offs and follow-up questions

**At-least-once delivery is the realistic guarantee.** True exactly-once delivery across a third-party provider isn't achievable. The `idempotency_key`, checked both at the API layer and again by the worker before sending, is what turns retries (ours or the caller's) into safe no-ops instead of duplicate sends.

**Ordering vs. throughput.** Partitioning a channel's queue by `user_id` keeps one user's notifications in order without limiting overall throughput, since per-user volume is naturally low.

**Provider fan-out for reliability.** Support a primary and fallback provider per channel (SendGrid primary, SES fallback), and fail over automatically when the primary's error rate spikes, using the same circuit breaker from the retry deep dive.

**Q: How do you guarantee a user never gets the same notification twice?**
A: An idempotency key at the API layer dedupes on insert, and the worker checks the notification's current status before sending. If it's already `sent` or `delivered`, it skips. That makes both queue redelivery and caller retries safe.

**Q: A batch marketing send to 5 million users is mid-flight when a user unsubscribes. How do you make sure they don't get it?**
A: The preference and unsubscribe check runs when each individual send is dequeued and processed, not once upfront when the whole batch was enqueued. A worker that hasn't reached that user yet sees the updated status and suppresses the send, recorded as `suppressed` for audit purposes rather than silently dropped.

**Q: How would you prevent a bug in a calling service from spamming a user with the same alert hundreds of times?**
A: A dedup key derived from `user_id + category + a business identifier` (like `order_id`), checked against recently sent notifications before enqueueing, with a reasonable dedup window measured in minutes to hours depending on the category.

```knowledge-check
{ "questions": [
    { "id": "system-design-notifications-tradeoffs-q1", "type": "mcq", "prompt": "Why is checking preferences and unsubscribes at dequeue time better than checking once when a batch is first enqueued?", "options": [
        {"id": "a", "text": "It's not better, checking once upfront is sufficient"},
        {"id": "b", "text": "It closes the race where a user unsubscribes after enqueueing but before their specific send is processed"},
        {"id": "c", "text": "It reduces the total number of database queries"},
        {"id": "d", "text": "It makes the API faster"}
    ], "correct": "b", "explanation": "A large batch can take minutes to fully process. Checking at the moment each message is actually about to send catches an unsubscribe that happened after the batch started." }
] }
```
