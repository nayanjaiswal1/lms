---
kind: lesson
type: system_design
id_key: interview-prep-45/day-26-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Design Notification System (Advanced)"
position: 26
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
Today's system fans a single event out across push, email, and SMS, each with different delivery guarantees, rate limits, and provider quirks — while respecting per-user preferences and unsubscribes. It's "advanced" because the real difficulty isn't sending one notification, it's routing millions of heterogeneous notification requests through the right channel, at the right rate, without violating a user's opt-out or a provider's rate limit. This lesson builds directly on Day 8's job queue.

## Requirements

**Functional**
- Send notifications via push, email, and SMS, chosen per notification type and user preference.
- Users manage granular preferences (e.g., "email me for security alerts, never SMS me for marketing").
- Users can unsubscribe from specific categories or all notifications.
- Notifications are built from templates, populated with dynamic data per recipient.

**Non-functional**
- Delivery guarantee: at-least-once send attempt, with visibility into actual delivery status where the channel supports it (push/email delivery receipts; SMS is more opaque).
- Ordering: within a single user/channel, notifications should generally arrive in the order they were triggered (a "payment failed" alert shouldn't arrive after a "payment succeeded" one that was triggered later).
- Unsubscribes must take effect immediately and be enforced at send time, not just at a UI toggle — this is a compliance requirement (CAN-SPAM, TCPA, GDPR), not just a UX nicety.
- Throughput: must absorb bursty sending (e.g., an incident affecting many users at once) without falling arbitrarily far behind.

## Capacity estimates

Assume 100M users, average 3 notifications/user/day across all channels = 300M notification sends/day.
- Average rate: 300M / 86,400 ≈ 3,500/sec average, with sharp bursts during mass events (a marketing campaign, an outage alert) that can spike 10-50x above average for short windows.
- Channel split (illustrative): 70% push (cheap, high volume), 25% email (moderate cost, higher deliverability scrutiny), 5% SMS (expensive per-message, tightly rate-limited by carriers) — cost and rate limits differ by orders of magnitude per channel, which is why routing/throttling per channel is a first-class design concern, not an afterthought.
- Provider rate limits: SMS providers commonly cap throughput per account/number (e.g., low hundreds of messages/sec); email providers enforce sending reputation limits; push providers (APNs/FCM) have per-app and per-device rate considerations. These external constraints, not your own infrastructure, are frequently the actual bottleneck.

## API sketch

```
POST /notifications/send    { user_id, category, template_id, data, channels?: ["push","email"] }
  -> { notification_id, status: "queued" }

GET  /notifications/{id}/status                -> { status, per_channel: {push: "delivered", email: "sent"} }

POST /preferences/{user_id}     { category, channel, enabled: bool }
GET  /preferences/{user_id}                      -> { preferences[] }
POST /unsubscribe                { user_id, category? }   -- category omitted = unsubscribe all
```

Internal services call `POST /notifications/send` with a logical `category` (e.g., `security_alert`, `order_update`, `marketing`) and let the notification system resolve actual channel(s) from user preferences — callers should not need to know a given user's channel preferences themselves.

## Data model

```
notifications        id, user_id, category, template_id, data, created_at, status
notification_deliveries  notification_id, channel, status (queued|sent|delivered|failed|
                      suppressed), provider_ref, attempted_at, delivered_at
templates             id, category, channel, subject_template, body_template
preferences           user_id, category, channel, enabled (bool)
unsubscribes          user_id, category (NULL = all), unsubscribed_at
```

`notification_deliveries` is one row per (notification, channel) — a single logical notification (`notification_id`) can fan out into multiple delivery attempts, each independently tracked, retried, and status-reported. This split is what makes per-channel delivery status and per-channel retry logic possible without conflating them into one row.

## High-level architecture

```
Triggering service (order service, security service, etc.) --> POST /notifications/send
                                                                        |
                                          Notification service: resolve preferences + unsubscribes
                                          --> determine eligible channels --> render template with data
                                                                        |
                                          write notification_deliveries row(s), status=queued
                                                                        |
                          push to per-channel job queues (Day 8's job queue pattern, one queue
                          per channel so a slow/rate-limited channel never blocks another)
                                                                        |
              +---------------------------+---------------------------+
              |                           |                           |
        Push worker pool            Email worker pool            SMS worker pool
        (calls APNs/FCM,             (calls SES/SendGrid,          (calls Twilio/similar,
         respects per-app             respects sending              respects per-account
         rate limits)                 reputation limits)             carrier rate limits)
              |                           |                           |
        delivery receipt / webhook --> update notification_deliveries.status
```

## Component deep dives

**Per-channel queues, not one shared queue.** Reuse Day 8's job queue design directly, but with a critical structural choice: separate queues per channel (push, email, SMS), each with its own worker pool sized and rate-limited to that channel's specific provider constraints. If all channels shared one queue, a rate-limited or temporarily degraded SMS provider (the tightest-constrained channel) would back up notifications for push and email too, even though those channels have no reason to be slow. This is the same "don't let one noisy queue starve others" principle from Day 8, applied concretely: the isolation boundary is the external provider's own rate limit.

**Preference resolution and unsubscribe enforcement, at send time.** Every `POST /notifications/send` call resolves eligible channels by checking `preferences` (does this user want this category on this channel) and `unsubscribes` (has this user opted out of this category, or everything) *before* enqueueing anything — never enqueue a send and check preferences later in the worker, since a race between an unsubscribe and an in-flight send could otherwise slip through. For legally-mandated compliance (CAN-SPAM's unsubscribe-must-be-immediate requirement, TCPA for SMS), this check must be synchronous and authoritative at the moment of sending, not eventually-consistent — this is one of the rare places in this course where "eventual consistency is fine" does not apply, because the cost of a mistake is regulatory, not just UX.

**Template rendering.** Templates are versioned per category+channel (`templates` table), parameterized with per-recipient `data` supplied by the triggering service. Rendering happens once, at send time, producing the final subject/body stored (or at least logged) alongside the delivery record — this matters for both debugging ("what exactly did we send this user") and for channels like email where the rendered content itself may need to pass spam-filtering/compliance checks before dispatch.

**Ordering within a channel.** Full global ordering across all notifications isn't meaningful (a marketing email and a security alert to two different users have no ordering relationship), but ordering *within a single user+channel* often matters (see the "payment failed" arriving after a stale "payment succeeded" example). The practical fix: partition the per-channel queue by user_id (same partition-key pattern as Day 8's ordering discussion) so all of one user's push notifications, say, are processed by the same worker/partition in enqueue order, while different users' notifications parallelize freely across other partitions.

**Delivery guarantees differ meaningfully by channel, and the design should say so explicitly.** Push notifications have provider-level delivery receipts (APNs/FCM report delivery/failure) letting you close the loop with real confirmation. Email has deliverability signals (bounce, complaint, open — though opens are increasingly unreliable due to privacy features) but "delivered" often just means "accepted by the recipient's mail server," not "read." SMS is the most opaque — carriers frequently don't report final delivery status back reliably, so "sent to provider" is often the practical ceiling of what you can confirm. A senior answer names this asymmetry rather than treating all three channels as equally observable.

**Handling a mass-notification burst (e.g., an incident affecting 5M users).** This stresses the per-channel queues directly — the fix is the same elastic-worker-pool pattern from Day 8/Day 22 (scale worker count with queue depth) combined with respecting the hard external rate limit per provider (you cannot out-scale a carrier's fixed SMS throughput cap by adding more workers — the limit is external, not internal). For genuinely rate-capped channels, the honest answer is prioritization: not every notification can go out immediately, so critical categories (security, outage) should be prioritized ahead of lower-priority categories (marketing) using the same priority-queue pattern from Day 8, rather than pretending the system can send everything instantly.

## Scaling & trade-offs

| Decision | Benefit | Cost |
|---|---|---|
| Separate queue + worker pool per channel | Isolates one channel's rate limits/outages from the others | More infrastructure to run and monitor than one shared queue |
| Synchronous preference/unsubscribe check at send time | Correctly enforces compliance requirements, no race window | Adds a lookup on the hot send path (mitigated by caching preferences, invalidated on change) |
| Partition per-channel queues by user_id | Preserves per-user, per-channel ordering | Slightly more complex than a flat queue; requires consistent partition routing |
| Priority queues within each channel | Critical notifications (security, outage) aren't delayed behind bulk marketing sends | Marketing/bulk sends may lag further behind during high-priority bursts |

## Likely follow-up questions — with answers

**Q: A user unsubscribes from marketing emails while a batch marketing send to 5M users (including them) is already partway through processing. How do you make sure they don't get it?**
A: Because the preference/unsubscribe check happens at the moment each individual send is dequeued and processed by a worker — not once, upfront, when the whole batch was enqueued — a worker that hasn't yet reached this user's entry will see the updated unsubscribe status and suppress the send (recorded as `notification_deliveries.status = suppressed`, for audit purposes, rather than silently dropped). This is why the check belongs in the worker's send-time path, not only in whatever service originally decided to enqueue the batch.

**Q: SMS delivery status is unreliable from the carrier. How do you know if a critical SMS alert actually reached the user?**
A: Accept the limitation explicitly rather than pretending certainty — track whatever confirmation signal the provider does offer (e.g., "accepted by carrier" webhooks from Twilio-like providers), and for genuinely critical alerts, layer a secondary channel as a fallback (e.g., if no delivery confirmation arrives within N minutes and the category is high-priority, also fire a push notification or email) rather than relying on SMS's opaque guarantees alone. This is a product/reliability decision as much as a technical one, and naming the trade-off is the strong interview answer.

**Q: How would you prevent a bug in the triggering service from spamming a user with the same notification hundreds of times?**
A: Add a dedup key to `POST /notifications/send` (e.g., derived from user_id + category + a business-meaningful identifier like order_id), checked against recently-sent notifications before enqueueing — the same idempotency-key pattern used throughout this course (Day 8's job dedup, Day 25's payment idempotency) applied here to prevent notification storms from a retrying or buggy caller, with a reasonable dedup window (minutes to hours, category-dependent) rather than permanent storage.

## Key takeaways

- Per-channel queues and worker pools (not one shared queue) isolate each channel's distinct, externally-imposed rate limits — this is Day 8's job queue design applied with channel-specific isolation boundaries.
- Preference and unsubscribe checks must happen synchronously at send time, not eventually — this is one of the few places in this course where "eventual consistency is fine" is the wrong answer, because the cost is regulatory/legal, not just UX.
- Delivery guarantees are genuinely different per channel (push has real receipts, email has deliverability signals, SMS is largely opaque) — say this asymmetry explicitly rather than treating all channels as equally observable.
- Ordering only matters within a single user+channel, not globally — solve it with partition-key routing (by user_id) into the per-channel queue, same pattern as Day 8's ordering discussion.
- Mass-notification bursts are bounded by external provider rate limits, not just your own infrastructure — the honest fix is prioritization (critical categories first) plus elastic worker scaling, not a promise to send everything instantly.
- Dedup/idempotency keys prevent notification storms from retrying or buggy callers — the same pattern reused from job queues and payments, applied to a new domain.
