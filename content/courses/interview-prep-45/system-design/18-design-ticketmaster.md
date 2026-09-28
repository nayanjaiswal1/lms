---
kind: lesson
type: system_design
id_key: interview-prep-45/day-20-system-design
course: interview-prep-45
section: system-design
section_title: "Case Studies"
section_position: 4
section_group: "System Design"
title: "Design Ticketmaster (Eventbrite)"
position: 18
estimated_minutes: 65
source:
    - 45-day-interview-roadmap.md
---

Ticketmaster is a concurrency problem wearing a CRUD costume: thousands of people trying to buy the same 20 seats in the same second. This question tests whether you know how to actually prevent double-booking under real contention, not just say "use a transaction," and whether you can build fairness into a system without collapsing its throughput.

## Requirements

**Functional requirements**
- Browse events, view seat maps and availability.
- Select seats and complete a purchase within a time-limited hold.
- Handle a high-demand on-sale event with thousands of concurrent buyers for one show.
- Support a waiting room or virtual queue for extreme-demand events.

**Non-functional requirements**
- Zero double-booking. This is the one correctness property that can never be relaxed.
- High concurrency: tens of thousands of simultaneous requests for a few thousand seats at the exact moment tickets go on sale.
- Fairness: no one should be able to skip the queue with bots or aggressive refreshing.
- Reasonable latency even under peak load. A slow but correct queue beats a fast but broken one.

> **Remember:** most requests in this system are supposed to fail. The job isn't to serve everyone, it's to fail the losing requests fast and fairly instead of letting them thrash the database.

```knowledge-check
{ "questions": [
    { "id": "system-design-ticketmaster-requirements-q1", "type": "mcq", "prompt": "In a major on-sale event with 500,000 buyers for 5,000 seats, what is the actual design goal for the 495,000 requests that will fail?", "options": [
        {"id": "a", "text": "To somehow let everyone succeed by adding more servers"},
        {"id": "b", "text": "To fail them fast and fairly, without letting them overwhelm the database with wasted contention"},
        {"id": "c", "text": "To ignore them entirely and let requests time out"},
        {"id": "d", "text": "To randomly select which requests get processed at all"}
    ], "correct": "b", "explanation": "With 100:1 contention, most requests are mathematically guaranteed to fail. The design goal is to make that failure fast, fair, and cheap, rather than letting every request hammer the same contended rows." }
] }
```

## Estimates

Assume a major on-sale event: 5,000 seats, with 500,000 people trying to buy in the first 10 minutes, a realistic arena-tour scenario.

- **Peak request rate:** 500,000 users hitting refresh or joining the queue over 10 minutes is about 830 requests/sec sustained, with a much sharper burst right at the on-sale second.
- **Contention ratio:** 500,000 buyers for 5,000 seats is 100:1. That ratio is exactly why a naive "select, then update" approach collapses: the vast majority of requests are guaranteed to fail and need to fail fast, not thrash the database trying.
- **Seat hold duration:** typically 5-10 minutes to complete checkout before a hold expires and the seat returns to the pool.
- **Waiting room throughput:** if 5,000 seats sell out in about 2 minutes, checkout needs to sustain roughly 40+ completed purchases/sec at peak to drain the queue into that small inventory before it looks stalled.

## API

```
POST /queue/join           { event_id }                    -> { queue_token, position_estimate }
GET  /queue/status?token=                                    -> { status: "waiting"|"admitted", position }

GET  /events/{id}/seats                                       -> { seat_map, availability }
POST /seats/hold            { event_id, seat_ids[] }          -> { hold_id, expires_at }   -- requires admitted queue_token
POST /checkout               { hold_id, payment_info }        -> { order_id, status }
POST /seats/release          { hold_id }                       -- explicit release or auto on expiry
```

## Data model

```
events            id, venue_id, name, starts_at
seats             id, event_id, section, row, seat_number, status (available|held|sold)
seat_holds        id, seat_id, user_id, expires_at, status (active|completed|expired)
orders            id, user_id, event_id, seat_ids[], total, status, created_at
```

```
seats
  id            UUID PK
  event_id      UUID
  status        TEXT       -- available | held | sold
  held_by       UUID NULL
  hold_expires  TIMESTAMPTZ NULL
  version       INT        -- optimistic concurrency token

UNIQUE constraint on (event_id, section, row, seat_number)
```

Concurrency control lives in `seats.status` plus a version column, not in application logic alone. That's the detail the rest of this lesson builds on.

## High-level design

```
Client --> Waiting Room service (admits users at a controlled rate) --> issues queue_token
                                                                              |
                                                    Admitted client --> Seat Selection service
                                                                              |
                                                          POST /seats/hold --> atomic seat lock
                                                          (DB row-level lock / Redis SETNX with TTL)
                                                                              |
                                                          Checkout service --> payment --> on success:
                                                          seat.status = sold; on failure/timeout:
                                                          seat auto-released back to available
                                                                              |
                                              Hold-expiry reaper (background) sweeps expired holds
                                              back to available, independent of client behavior
```

## Deep dives

### How do you actually prevent double-booking, not just "use a transaction"?

The mechanism is an atomic conditional update, never a read-then-write from application code:

```
UPDATE seats SET status='held', held_by=$user, hold_expires=now()+interval '10 min', version=version+1
WHERE id=$seat_id AND status='available' AND version=$expected_version
```

If zero rows are affected, someone else already got there first, and the client is told immediately to pick a different seat. This is optimistic concurrency control: no long-held lock, just a compare-and-swap at the row level, which scales far better than a pessimistic lock under heavy contention on a small set of hot rows. An often faster-under-load alternative is Redis `SET seat:{id} {user_id} NX EX 600`, set-if-not-exists with a TTL, as the actual hold mechanism, with the database as the durable record synced asynchronously behind it. That trades a small window of eventual consistency for much higher throughput on the hottest path.

> **Remember:** a single-row atomic compare-and-swap is enough here because the entire contested resource, one seat, lives on one row. No distributed lock, no two-phase commit needed.

```knowledge-check
{ "questions": [
    { "id": "system-design-ticketmaster-cas-q1", "type": "mcq", "prompt": "Why does an atomic conditional update (WHERE status='available') scale better under heavy contention than a pessimistic row lock held for the duration of the transaction?", "options": [
        {"id": "a", "text": "They perform identically under any load"},
        {"id": "b", "text": "The conditional update never holds a lock while waiting; it either succeeds instantly or fails instantly, so losing requests don't queue up waiting on each other"},
        {"id": "c", "text": "Pessimistic locks are not supported by relational databases"},
        {"id": "d", "text": "Conditional updates only work for reads, not writes"}
    ], "correct": "b", "explanation": "Optimistic concurrency avoids making 499,999 losing requests wait in line behind a lock; each one gets an immediate, cheap failure instead of contending for a held lock." }
] }
```

### Why does a hold-then-checkout flow matter, and who cleans up an abandoned hold?

Never sell in one atomic step straight from browsing to sold. Always route through an explicit, time-boxed hold. This gives a buyer a fair window to complete payment without another buyer racing them for the same seat, while guaranteeing the hold expires, via the `hold_expires` field plus a background reaper, or the Redis TTL doing it automatically, so a seat never gets permanently stuck when someone abandons checkout.

That reaper existing independently of any client action is critical. Never rely on a client calling `/seats/release` to free inventory, since clients disappear constantly: a closed tab, a crashed app, a lost connection. If payment fails or times out after a hold was granted, the seat has to return to available promptly, either because checkout explicitly releases it on failure, or, more safely, because the expiry reaper reclaims it regardless of whether checkout cleaned up after itself.

### How does the waiting room actually help, and how big should it be?

For an extreme-demand on-sale, admitting all 500,000 simultaneous requests straight into seat selection would overwhelm the seat-locking path with near-total contention and wasted work, since most requests are guaranteed to lose anyway. Instead, a waiting room admits users into seat selection at a controlled rate matched to actual checkout throughput, a few thousand at a time, admitting more as holds expire or orders complete. This is implemented as a queue, either FIFO by join order or randomized to avoid rewarding the fastest-clicking bots. Its real contribution is moving contention out of the database and into a much cheaper "am I admitted yet" polling loop.

Size the admission rate against observed checkout completion throughput, not raw incoming demand. If checkout reliably completes in an average of T seconds and you want, say, 10,000 users actively in the funnel at once, admit new users at roughly 10,000/T per second, adjusting dynamically based on real-time completion and hold-expiry rates so the admitted pool neither starves nor overwhelms the seat-locking layer.

### How do you stop bots from scalping past the queue?

Layer several imperfect measures together, since no single one solves it alone: rate-limit queue-join per IP or account, require authentication before entering the queue to raise the cost of running many bot accounts, add a CAPTCHA or proof-of-work at the join step, and cap tickets per account per event. Naming the layered approach, rather than claiming any single measure "solves" scalping, is the strong interview answer.

## Trade-offs and follow-up questions

| Decision | Benefit | Cost |
|---|---|---|
| Optimistic concurrency (compare-and-swap on the seat row) | No long-held locks, scales under contention | The client must handle "someone else got it" and retry seat selection |
| Redis-based holds with a TTL | Very high throughput, automatic expiry | A second system that must stay consistent with the database's source of truth |
| Waiting room before seat selection | Keeps database contention bounded regardless of demand spike size | Adds latency and complexity for the common case where a queue isn't even needed |
| Explicit hold-then-checkout | Fair, prevents an accidental double-sell during payment processing | Seats sit "held but unsold" during the hold window, temporarily reducing visible availability |

**Q: Two users click "buy" on the same seat within milliseconds of each other. Walk through exactly what happens.**
A: Both requests race to the same atomic conditional update, or the same Redis `SETNX`. The underlying store guarantees only one succeeds. The losing request gets zero rows affected, or a `false`, and is immediately told the seat is unavailable, prompting reselection. No distributed lock or two-phase coordination is needed, since the entire contested resource lives on a single row.

**Q: How do you decide the waiting room's admission rate?**
A: Match it to observed checkout completion throughput, not to raw incoming demand, adjusting dynamically based on real-time completion and hold-expiry rates so the admitted pool neither starves nor overwhelms seat locking.

**Q: What happens if the waiting room service itself goes down during a major on-sale?**
A: The waiting room should be a thin, horizontally scalable, mostly stateless layer, with queue state in a distributed store rather than in process memory, so it's the easiest component to scale out and recover. It should fail toward "hold everyone in queue" rather than "let everyone through," since the seat-locking layer's correctness matters more than the waiting room's availability. An outage should degrade to slower admission, never bypass the queue into the contested path.

```knowledge-check
{ "questions": [
    { "id": "system-design-ticketmaster-tradeoffs-q1", "type": "mcq", "prompt": "If the waiting room service fails during a major on-sale, what should it fail toward?", "options": [
        {"id": "a", "text": "Letting everyone through immediately, bypassing the queue"},
        {"id": "b", "text": "Holding everyone in queue rather than letting the seat-locking layer face unmoderated contention"},
        {"id": "c", "text": "Shutting down the entire ticketing system"},
        {"id": "d", "text": "Randomly admitting half of waiting users"}
    ], "correct": "b", "explanation": "The waiting room's job is to protect the seat-locking layer from unmoderated contention. Failing open (letting everyone through) would defeat that purpose exactly when it matters most." }
] }
```
