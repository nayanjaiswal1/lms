---
kind: lesson
id_key: interview-prep-45/day-35
course: interview-prep-45
section: mock-interviews
section_title: "Mock Interviews"
section_position: 7
title: "Day 35 — Mock Interviews 16–17 + Weakness Identification"
position: 35
estimated_minutes: 240
source:
    - 45-day-interview-roadmap.md
---

Two mocks today, then something different: instead of a third mock, you spend real time turning six mock interviews' worth of debrief notes into a targeted plan for the days you have left. Run the two mocks exactly like every other day — hard timer, out loud, no peeking. The weakness identification block is not a timer exercise; it's the most consequential 45 minutes of the week, so don't rush it to get to the buffer.

## Run of show

| Time | Segment |
|---|---|
| 0:00–0:30 | Mock 16: Behavioral + Resume Walkthrough (30 min) |
| 0:30–0:40 | Break — write down what went wrong while it's fresh |
| 0:40–1:20 | Mock 17: System Design — Design a Notification System (40 min) |
| 1:20–1:30 | Break |
| 1:30–1:55 | Score both mocks against the rubric, write debrief |
| 1:55–2:40 | Weakness Identification — review all mocks so far, build the plan |
| 2:40–4:00 | Buffer — re-drill whatever the weakness plan flags as most urgent |

## Mock Interview 16: Behavioral + Resume Walkthrough (30 minutes)

**Instructions:** set a 30-minute timer. This isn't a Q&A round with prompts handed to you — it's a full resume walkthrough followed by two project deep dives, structured the way a real onsite behavioral round runs. Budget: 5 min resume walkthrough, 10 min project deep dive #1, 10 min project deep dive #2, 5 min asking for feedback.

**Clarifying hints an interviewer would give if you don't ask:**
- "How much detail on the resume walkthrough?" — Enough to orient them, not a re-read; 5 minutes is a hard ceiling, practice hitting it.
- "Can the two deep-dive projects overlap in tech stack?" — They can share a stack, but the *kind* of contribution (systems vs product, solo vs cross-team, build vs debug/optimize) should differ.
- "Should I quantify results even if I don't remember exact numbers?" — Yes, with a caveat stated honestly ("roughly," "on the order of") — a defensible estimate beats no number at all, and beats a number you can't back up if pressed.

**Part 1 — Resume walkthrough (5 minutes).** Walk through your resume top to bottom as if the interviewer has it open and hasn't read it closely yet. This is not reading it aloud — it's adding the context the bullet points can't carry: why you took each role, what you actually owned versus what the team owned, and a one-line honest note on what each role taught you or where it fell short. A weak walkthrough recites job titles and dates; a strong one tells the interviewer what to pay attention to before the deep dive starts.

**Part 2 — Project deep dive #1 (10 minutes).** Pick the project on your resume you're most likely to be asked about — usually the most recent or most technically substantial one. Use STAR, but weight it toward Action: 1 min Situation, 1 min Task, 6–7 min Action, 1–2 min Result. Be ready to defend every technical claim two levels deep — "you said you optimized it" should have a real "optimized what, specifically, and what was the before/after number" answer ready.

**Part 3 — Project deep dive #2 (10 minutes).** Pick a *different* project that shows a different skill than #1 — if #1 was a backend/systems story, make #2 a product/frontend/cross-team story, or vice versa. Reusing the same project or the same kind of story for both is a red flag interviewers notice; it suggests a thin bench.

**Part 4 — Ask for feedback (5 minutes).** In a real interview this is your closing window to ask the interviewer questions. Running solo, do the honest version: write down the three questions you'd actually ask an interviewer about your own performance today (e.g. "was the Action section of my second story concrete enough?", "did the resume walkthrough run long?"), and answer them yourself as bluntly as you'd want a real interviewer to. If you have a mentor, peer, or recording available, use this slot to get real feedback instead.

### Reference approach

**Resume walkthrough, structurally:**

> "I'll go roughly reverse-chronological. At [current role], I've been the primary owner of [specific system/area] for about a year — the thing worth knowing going in is that I inherited it mid-migration, so a lot of my early work was stabilization, not greenfield build. Before that, at [previous role], I was on a smaller team where I ended up doing more full-stack work than my title suggests, which is relevant if we get into the frontend project I'll walk through next. My concentration in school/prior training was [X], which is why I gravitate toward [Y] problems."

Notice: no bullet-point recitation, every sentence adds context the resume itself can't show, and it explicitly signals what's coming ("relevant if we get into...") so the interviewer can steer.

**Project deep dive, structurally (a different domain than the Day 30 checkout-API example — use a data pipeline story here to force practicing a second kind of narrative):**

> "At [company], our nightly ETL job that fed the analytics dashboard was taking six hours and regularly missed its SLA before the morning stand-up (Situation). I was asked to get it under two hours without changing the output schema, since three other teams depended on it (Task). I profiled the job and found two things: it was processing partitions sequentially when they had no dependency on each other, and a join against a slowly-changing dimension table was re-scanning the full table every run instead of using the table's existing update timestamp to only pull deltas (Action — name the specific tools: I used the job scheduler's DAG view to confirm partition independence, and `EXPLAIN` on the join to see the full scan). I parallelized the partition processing across workers and added an incremental-load path for the dimension join. Runtime dropped from six hours to ninety minutes, and we haven't missed the SLA since (Result). What I'd do differently: I found the sequential-partition issue by accident while investigating something else — in hindsight, a runtime profile broken down by pipeline stage should have been a standing dashboard from day one, not something I built reactively."

Notice again: specific numbers, specific tools named, and an honest "what I'd do differently" that shows growth rather than just closing the story on a win. That closing self-critique is what separates a rehearsed-sounding answer from a credible one — interviewers listen for it specifically.

## Mock Interview 17: System Design — Notification System (40 minutes)

**Prompt as the interviewer would give it:** "Design a system that sends notifications to users across email, push, and SMS, triggered by events elsewhere in the product. Focus on reliability — a notification should never silently vanish, and a transient failure in one channel shouldn't affect the others."

Time budget: 5 min requirements, 10 min high-level architecture, 17 min deep dive on reliability, 8 min scaling and trade-offs.

**Clarifying questions to ask out loud:**
- Which channels are truly latency-critical (an OTP SMS needs to arrive in seconds) versus tolerant of delay (a weekly digest email)?
- Do users have per-channel opt-in/opt-out preferences?
- Templated content, or freeform per-event?
- Rough scale — events/sec that can trigger a notification, peak fan-out (e.g. one event notifying millions of users)?

### Reference solution

**Functional requirements:** accept a notification request from internal services, render it against a template, respect per-user per-channel preferences, deliver via email/push/SMS through third-party providers (SendGrid/Twilio/FCM-APNs style), track delivery status.
**Non-functional requirements:** at-least-once delivery (a notification must never be silently dropped), no duplicate sends beyond what idempotency allows for, one channel's provider outage must not back up or block the others, and latency-critical channels (OTP) must not queue behind bulk/marketing traffic.

**High-level architecture:**
```
Event producers (internal services) -> Notification API -> Preference check -> Template render -> Queue (partitioned by channel)
                                                                                                  -> Email workers   -> SendGrid-style provider
                                                                                                  -> SMS workers     -> Twilio-style provider
                                                                                                  -> Push workers    -> FCM/APNs
                                                                                     Delivery webhooks -> Status tracking DB
```

**Why queue-per-channel, not one shared queue — this is the deep dive's central point:** if email, SMS, and push all share one queue, a burst of bulk marketing email can sit in front of a time-critical OTP SMS, or a slow/degraded email provider can back up the whole queue and delay push notifications that have nothing to do with email. Partitioning the queue by channel (separate Kafka topics or SQS queues per channel) means each channel scales and degrades independently — an email provider outage fills up only the email queue, SMS and push keep flowing. Within a channel, a priority sub-queue (or separate high-priority topic) keeps OTP/security-critical SMS from queuing behind bulk sends.

**Reliability mechanics, in order of how a message actually flows:**
1. **Ingestion is idempotent.** Every notification request carries an idempotency key (generated by the producing service, e.g. `event_id + user_id + channel`). If the same event gets published twice (a producer retry after a network blip), the notification service dedupes on that key before it ever reaches a queue — this is the cheapest place to prevent a duplicate send, before any provider is even involved.
2. **At-least-once through the queue.** A worker only acknowledges a queue message after the third-party provider confirms acceptance (not "sent," just "accepted for delivery" — providers are async themselves). If the worker crashes before acking, the message redelivers. This means a worker's provider-call logic must itself be safe to run twice — which is exactly what the idempotency key from step 1 protects against downstream too, since most providers (Twilio, SendGrid) accept a client-supplied idempotency/dedupe key on their own send API.
3. **Retry with backoff, then dead-letter.** A transient provider error (5xx, timeout) retries with exponential backoff a bounded number of times; after that, the message moves to a dead-letter queue for manual/automatic reprocessing rather than being dropped or retried forever and starving the queue.
4. **Circuit breaker per provider.** If a provider's error rate crosses a threshold, stop sending to it temporarily (fail fast, queue backs up safely) instead of every worker thread hanging on timeouts against a provider that's clearly down — this protects the rest of the system's throughput.
5. **Delivery status via webhook, not polling.** Providers push delivery/bounce/failure events back to a webhook endpoint; the status is written to a notifications table for auditing and for any "did this actually arrive" debugging later. This is also how you'd detect and alert on a channel silently failing at the provider side rather than at your own queue.

**Data model:**
```sql
CREATE TABLE notifications (
    id BIGSERIAL PRIMARY KEY,
    idempotency_key VARCHAR(200) UNIQUE NOT NULL,
    user_id BIGINT NOT NULL,
    channel VARCHAR(10) NOT NULL, -- email | sms | push
    template_id VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'queued', -- queued | sent | delivered | failed | bounced
    created_at TIMESTAMPTZ DEFAULT now(),
    sent_at TIMESTAMPTZ
);
CREATE TABLE user_preferences (
    user_id BIGINT NOT NULL,
    channel VARCHAR(10) NOT NULL,
    opted_in BOOLEAN NOT NULL DEFAULT true,
    PRIMARY KEY (user_id, channel)
);
```

**Scaling and trade-offs:**
- Channel throughput differs wildly (push can fan out to millions of devices for one event; SMS is comparatively low-volume and expensive per message) — scale worker pools per channel independently rather than treating "notification workers" as one undifferentiated pool.
- Preference checks and template rendering happen before the queue, not in the worker, so a bad template doesn't get discovered a hundred retries deep in a channel-specific worker; fail fast at ingestion.
- State plainly: **true exactly-once delivery to the end user is not achievable** across a third-party boundary you don't control (a push notification can be delivered by FCM but the confirmation never makes it back to you, or a user has two devices and both fire). What you can guarantee is at-least-once with an idempotent producer and provider-level dedupe — say this is the actual guarantee being built, not exactly-once, since claiming exactly-once here is the kind of overclaim a strong interviewer will immediately probe.

**Failure modes to name:** a producer service retries an event publish after a timeout that actually succeeded (idempotency key at ingestion catches this), a provider accepts a message but never delivers it and never webhooks back (needs a timeout-based reconciliation job that flags notifications stuck in "sent" past a threshold), and a bad template deployed to production that silently fails to render for a subset of users (render-time validation and alerting, not just a try/catch that swallows the error and drops the notification).

**Retry-with-backoff-then-dead-letter, made concrete.** If pushed to show the mechanism rather than just describe it, this is the shape of a worker's send loop — the part worth having runnable in your head, not just as a sentence:

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

The two exception types are the detail worth naming out loud: a permanent error (bad recipient, malformed payload) retrying five times with backoff is pure wasted time and delayed dead-lettering — it should fail fast on attempt one. Only transient errors (timeout, 5xx, rate limit) earn the backoff loop. Jitter on the delay is a small detail interviewers notice — without it, every worker retrying against the same degraded provider backs off in lockstep and re-hammers it at the same instant.

## Scoring rubric

**Mock 16 — Behavioral + Resume Walkthrough**
- Resume walkthrough added context beyond what's on the page, in under 5 minutes: 5 = every sentence added something the resume itself couldn't show; 1 = read bullet points aloud with no added color, or ran long.
- Project deep dive #1 followed STAR with Action as the majority of the time, survived a hypothetical "go deeper" follow-up: 5 = specific tools/numbers named, could go two levels deeper if pushed; 1 = vague ("we improved it a lot"), no specifics.
- Project deep dive #2 demonstrated a genuinely different skill/domain than #1: 5 = clearly distinct story (different technical area or different kind of contribution); 1 = essentially the same story restated.
- Self-feedback in part 4 was honest and specific, not generic: 5 = identified a real, specific weak point from today's own performance; 1 = "I think it went fine" with no substance.

**Mock 17 — System Design (Notification System)**
- Identified per-channel queue partitioning as the core reliability mechanism, not just "use a message queue": 5 = explained why shared queuing causes cross-channel blocking, unprompted; 1 = proposed one undifferentiated queue for all channels.
- Correctly distinguished idempotency (preventing duplicate sends) from at-least-once delivery (preventing lost sends) as two separate concerns: 5 = explained both clearly with where each is enforced; 1 = conflated the two or only addressed one.
- Named a concrete retry/dead-letter/circuit-breaker strategy for provider failures: 5 = covered all three with reasoning; 1 = "just retry" with no bound or escalation path.
- Explicitly stated the real delivery guarantee (at-least-once, not exactly-once) rather than overclaiming: 5 = stated this unprompted and explained why exactly-once isn't achievable across a third-party boundary; 1 = claimed exactly-once without qualification.

## Debrief

Score both mocks immediately, same as every day — but today the debrief for Mock 16 and Mock 17 feeds directly into the weakness identification block next, so be more precise than usual about *why* something scored low, not just that it did. For Mock 16, was the resume walkthrough weak because of content (nothing but job titles) or delivery (good content, rambled)? Those need different fixes. For Mock 17, was per-channel partitioning something you reached unprompted, or only after a nudge — this is a pattern (isolate blast radius per failure domain) that recurs across almost every reliability-focused system design prompt, so it's worth flagging even if you scored well everywhere else.

## Weakness Identification (45 minutes)

This is not a mock — it's the point of running seven mocks (Days 29 through today) instead of just one. Do this with your actual debrief notes open, not from memory.

**Step 1 — Tally (15 minutes).** Go back through every debrief note from Mock 1 through Mock 17. For each mock, list every rubric criterion scored 3/5 or below. Group them into buckets — not by which mock they came from, but by what kind of gap they represent: *knowledge gap* (didn't know a concept/pattern), *mechanics gap* (knew the idea, fumbled the implementation/syntax), *communication gap* (right answer, poor delivery/structure), *time management* (ran out of time, rushed the end), *nerves/pacing* (froze, went silent, panicked under a follow-up).

**Step 2 — Identify the 3 biggest weaknesses (10 minutes).** Don't pick the 3 most recent — pick the 3 that recur most across different mocks. A single bad DP problem is noise; forgetting to state complexity unprompted in four different coding rounds is a pattern. A weakness that shows up once is bad luck; one that shows up three times is a habit, and habits are what a real interview loop will expose.

**Worked example of what Steps 1–2 should produce** — a sample tally after seven mocks, so you know what "done" looks like before building your own:

| Gap bucket | Where it showed up | Count |
|---|---|---|
| Didn't state Big-O unprompted | Two Sum (Day 29), LIS (Day 32), Merge K Sorted Lists (Day 33) | 3 |
| Didn't name a concurrency/race-condition risk unprompted | URL Shortener (Day 29), Chat App (Day 30) | 2 |
| Vague behavioral Result section (no numbers) | Failure prompt (Day 32), project deep dive #1 (Day 35) | 2 |
| Missed an edge case only when it was the first thing tested | Merge Intervals (Day 30), Binary Tree Level Order (Day 34) | 2 |

Reading this tally: "didn't state Big-O unprompted" is the clear top pattern — three separate coding rounds, not one bad day. "Didn't name a concurrency risk unprompted" is second, and worth flagging even though Airbnb (Day 34) actually scored well on it — that's evidence the gap is closing, not evidence to ignore it, since it still cost points twice before that. The other two buckets have two hits each; whichever is more damaging in a real loop (a shaky behavioral Result section is worse in a behavioral-only round than a missed edge case is in a coding round with time to recover) breaks the tie for the third slot.

**Step 3 — Build the targeted practice plan (15 minutes).** For each of the 3 weaknesses, write down: the specific gap, one concrete drill to close it (a problem to redo cold, a concept to re-read and then explain out loud without notes, a story to rewrite with real numbers), and which remaining day(s) it goes into. Be specific enough that future-you doesn't have to re-derive the plan — "get better at system design" is not a plan, "explicitly state a consistency trade-off unprompted in every remaining system design mock, and re-read the CAP theorem section before Day 36" is.

**Step 4 — Adjust remaining days (5 minutes).** Look at what's left on the calendar. If a weakness is severe enough, it's worth trading part of a buffer block on a future day to re-drill it rather than treating every remaining day's buffer as free choice. Write that adjustment down now, while you have the full picture, not on the day itself when you'll default to whatever's easiest.

Using the worked example above, a real Step 3–4 output looks like this — three lines, each specific enough to execute without re-thinking it later:

1. **Gap:** Big-O not stated unprompted in coding rounds. **Drill:** for every remaining coding mock, state time and space complexity for both the brute-force and optimized approach before writing a line of code — not after. **Target:** every remaining coding round, starting immediately, not a single future day.
2. **Gap:** vague behavioral Result sections. **Drill:** rewrite the Day 32 failure story and the Day 35 project deep dive #1 with real, specific numbers pulled from actual project artifacts (tickets, dashboards, commit history) — not from memory. **Target:** before the next behavioral-heavy mock day.
3. **Gap:** edge cases only get tested after being prompted. **Drill:** before running any test in a coding round, say the edge case list out loud first (empty input, single element, all-duplicate, already-sorted/reverse-sorted) — commit to testing at least two before declaring done. **Target:** every remaining coding round.

Notice none of these say "practice more" — each names the exact trigger (before writing code, before declaring done, which specific stories to rewrite) that makes the fix checkable rather than aspirational.

## Today's checklist

- [ ] Mock 16: completed the resume walkthrough in 5 minutes with real added context
- [ ] Mock 16: completed two distinct project deep dives using STAR
- [ ] Mock 16: wrote honest self-feedback on today's performance
- [ ] Mock 17: designed the notification system with per-channel queue isolation
- [ ] Mock 17: covered idempotency, retries, dead-lettering, and circuit breaking
- [ ] Mock 17: stated the real delivery guarantee (at-least-once) explicitly
- [ ] Scored both mocks against the rubric and logged debrief notes
- [ ] Weakness Identification: tallied every sub-3 score from Mocks 1–17
- [ ] Weakness Identification: identified the 3 most-recurring weaknesses
- [ ] Weakness Identification: wrote a concrete drill and target day for each
- [ ] Weakness Identification: adjusted remaining days' buffer blocks accordingly
