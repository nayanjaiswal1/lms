---
kind: lesson
type: system_design
id_key: interview-prep-45/day-20-system-design
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Design Ticketmaster/Eventbrite"
position: 20
estimated_minutes: 60
source:
    - 45-day-interview-roadmap.md
---
Ticketmaster is asked because it's a concurrency problem wearing a CRUD costume: thousands of people trying to buy the same 20 seats in the same second. Interviewers use it to test whether you know how to prevent double-booking under real contention (not just "use a transaction"), and whether you can design fairness (queueing) into a system without tanking throughput.

## Requirements

**Functional**
- Browse events, view seat maps and availability.
- Select seats and complete a purchase within a time-limited hold.
- Handle high-demand on-sale events (thousands of concurrent buyers for one show).
- Support waiting rooms/virtual queues for extreme-demand events.

**Non-functional**
- Zero double-booking. This is the one correctness property that cannot be relaxed.
- High concurrency: tens of thousands of simultaneous requests for the same small inventory (a few thousand seats) at on-sale time.
- Fairness: no one should be able to bypass the queue via bots/refreshing (anti-scalping).
- Reasonable latency even under peak load. A slow but correct queue beats a fast but broken one.

## Capacity estimates

Assume a major on-sale event: 5,000 seats, 500,000 people trying to buy in the first 10 minutes (a realistic "arena tour on-sale" scenario).
- Peak request rate: 500,000 users hitting refresh/queue-join in a 10-minute window ≈ 830 requests/sec sustained, with bursts far higher at the exact on-sale second.
- Contention ratio: 500,000 buyers for 5,000 seats is 100:1. That ratio is why a naive "SELECT then UPDATE" approach collapses; the vast majority of requests are guaranteed to fail and need to fail fast and fairly, not thrash the DB.
- Seat hold duration: typically 5-10 minutes to complete checkout before the hold expires and the seat releases back to the pool.
- Waiting room throughput: if seats sell out in ~2 minutes at 5,000 seats, checkout throughput needs to sustain roughly 40+ completed purchases/sec at peak to drain the queue into the small available inventory before it looks stalled.

## API sketch

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

-- concurrency control lives in seats.status + a version/lock, not in application logic alone
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

## High-level architecture

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

## Component deep dives

**Preventing double-booking.** The core mechanism is an atomic conditional update, not a read-then-write from application code: `UPDATE seats SET status='held', held_by=$user, hold_expires=now()+interval '10 min', version=version+1 WHERE id=$seat_id AND status='available' AND version=$expected_version`. If zero rows are affected, someone else got there first, and the client is told immediately to pick a different seat. This is optimistic concurrency control: no long-held lock, just a compare-and-swap at the DB row level, which scales far better than pessimistic locking under high contention on a small set of hot rows. An equivalent, often faster-under-load approach is to use Redis `SET seat:{id} {user_id} NX EX 600` (set-if-not-exists with a TTL) as the hold mechanism, with the DB as the durable record synced asynchronously. That trades a small window of eventual consistency for much higher throughput on the hottest path.

**The hold-then-checkout pattern.** Never sell atomically in one step from "browse" straight to "sold." Always go through an explicit, time-boxed hold. This gives the user a fair window to complete payment without another buyer racing them for the same seat, while guaranteeing the hold expires (via the DB `hold_expires` field plus a background reaper, or the Redis TTL doing it automatically) so seats don't get permanently stuck if a user abandons checkout. The reaper existing independently of any client action is critical: never rely on the client calling `/seats/release` to free inventory, since clients disappear (closed tab, crashed app, lost connection) constantly.

**Waiting room / virtual queue.** For extreme-demand on-sale events, admitting all 500,000 simultaneous requests straight into seat selection would overwhelm the seat-locking path with near-100% contention and wasted work (most requests are guaranteed to lose). Instead, a waiting room admits users into seat selection at a controlled rate matched to actual checkout throughput capacity (e.g., admit a few thousand at a time, admit more as holds expire or orders complete). This is implemented as a queue, either a FIFO token issued on join and admitted in order, or a randomized entry order to avoid rewarding fastest-clicking bots. The key property is that it moves contention out of the database and into a much cheaper "am I admitted yet" polling loop.

**Anti-scalping / anti-bot.** Rate-limit queue-join per IP/account, require authentication before queue entry (raises the cost of running thousands of bot accounts), add CAPTCHA or proof-of-work at the join step, and cap tickets per account per event. None of these are perfect individually, but layered together they raise the cost of automated scalping meaningfully. A system design interview answer should name the layered approach rather than claim any single measure "solves" scalping.

**Handling payment failure mid-checkout.** If payment fails or times out after a seat hold was granted, the seat must return to `available` promptly, either because the checkout service explicitly releases it on failure, or, safer, because the hold's TTL/expiry reaper reclaims it regardless of whether checkout explicitly cleaned up (checkout services can also crash). Never let a failed payment leave a seat permanently held.

## Scaling & trade-offs

| Decision | Benefit | Cost |
|---|---|---|
| Optimistic concurrency (compare-and-swap on seat row) | No long-held locks, scales under contention | Client must handle "someone else got it" and retry seat selection |
| Redis-based holds with TTL | Very high throughput, automatic expiry | Adds a second system that must stay consistent with the DB source of truth |
| Waiting room before seat selection | Keeps DB contention bounded regardless of demand spike size | Adds latency/complexity for the (common) non-peak case where a queue isn't even needed |
| Explicit hold-then-checkout | Fair, prevents accidental double-sell during payment processing | Seats sit "held-but-unsold" for the hold window, temporarily reducing visible availability |

## Likely follow-up questions (with answers)

**Q: Two users click "buy" on the same seat within milliseconds of each other. Walk me through exactly what happens.**
A: Both requests race to the same atomic conditional update (`UPDATE ... WHERE status='available'` or Redis `SETNX`). The underlying store guarantees only one of the two concurrent operations succeeds. That's what "atomic" means here, enforced by the database/Redis, not by application-level coordination. The losing request gets zero rows affected (or a `false` from `SETNX`) and is immediately told the seat is unavailable, prompting seat reselection. No distributed lock, no two-phase coordination needed: a single-row atomic operation is sufficient because the entire contested resource (one seat) lives on one row.

**Q: How do you decide the size of the waiting room's admission rate?**
A: Match it to observed/estimated checkout completion throughput, not to raw incoming demand. If checkout (seat selection through payment) reliably completes in an average of T seconds and you want to keep, say, 10,000 users actively in the seat-selection/checkout funnel at once, admit new users at roughly (10,000 / T) per second, adjusting dynamically based on real-time completion rate and hold-expiry rate so the admitted pool neither starves (too slow) nor overwhelms the seat-locking path (too fast).

**Q: What happens if the waiting room service itself goes down during a major on-sale?**
A: This is why the waiting room should be a thin, horizontally-scalable, stateless-as-possible layer (queue state in Redis/a distributed queue, not in-process). It should be the easiest component to scale out and recover, since it does far less work per request than seat selection or payment. Design it to fail toward "hold everyone in queue" rather than "let everyone through," since the seat-locking layer's correctness (no double-booking) is independent of and more important than the waiting room's availability. A queue outage should degrade to slower admission, never to bypassing the queue into the contested path.

## Key takeaways

- The double-booking mechanism (atomic conditional update on the seat row) and the overselling mechanism you'll see in Day 23's inventory design are the same pattern applied to a discrete resource versus a quantity. Once you've internalized one, the other is a five-second variation, not a fresh problem.
- A waiting room's real contribution isn't fairness for its own sake. It's converting "500,000 requests racing for 5,000 rows" into a controlled admission rate matched to actual checkout throughput, which is what keeps the database from falling over in the first place.
