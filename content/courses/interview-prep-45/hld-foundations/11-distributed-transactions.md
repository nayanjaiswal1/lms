---
kind: lesson
id_key: interview-prep-45/hld-11-distributed-transactions
course: interview-prep-45
section: hld-foundations
section_title: "Foundations"
section_position: 3
section_group: "System Design"
title: "Distributed Transactions and Data Integrity"
position: 11
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

The moment your design has two services with two separate databases, or even just one database split into shards, the simple "begin, then commit" transaction you've relied on your whole career stops working. A flow like "reserve the inventory, charge the card, create the shipment" now stretches across three separate systems, and any one of them can fail after the others have already succeeded. This lesson covers the four honest answers to that problem, and how to pick between them.

## Why you cannot just use a transaction

A transaction on a single database gives you atomicity because that one database owns its own log, its own locks, and the single decision of whether to commit or not. Once you spread that same work across separate services, none of that exists anymore.

- Service A finishes and confirms its work, then service B fails. Now the system is left in a **half-finished state** a user could actually see.
- Service B is slow, and service A is still holding locks while it waits on a network call to B. That creates contention, and a chain of timeouts spreading outward.
- Either service can crash in the gap between actually doing the work and recording that it did the work.

Say these three principles out loud before proposing any specific mechanism.

**The best distributed transaction is the one you never needed in the first place.** If two pieces of data absolutely must change together, that's a strong hint they actually belong in the same service and the same database. Proposing to redraw the service boundary is a legitimate, senior-level answer, not a dodge.

**Real business processes are already eventually consistent, and that's fine.** A hotel takes your booking now, charges your card a little later, and cancels the booking if that payment fails. Real workflows already work by compensating for failure afterward, not by being perfectly atomic. Designing it that way is simply matching reality, not settling for less.

**Choose your mechanism based on how long the work takes and how long you can afford to hold a lock.** A process that finishes in milliseconds, inside one data center, where atomicity really is non-negotiable, points toward one kind of solution. A workflow spanning several seconds and several services points toward a very different one.

> **Remember:** the best distributed transaction is the one you avoid needing. If two pieces of data must always change together, that's a sign they belong in the same database.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-11-why-q1", "type": "mcq",
      "prompt": "Two microservices must update their data atomically on every single request, and this is the dominant workflow in the system. What is the strongest first response in a design interview?",
      "options": [
        {"id":"a","text":"Implement two-phase commit between the two services"},
        {"id":"b","text":"Question the service boundary itself; data that must change atomically on every request probably belongs together in one service and one database, and a distributed transaction is a fallback, not the goal"},
        {"id":"c","text":"Rely on eventual consistency and hope it works out"},
        {"id":"d","text":"Put both databases behind a single shared connection pool"}
      ],
      "correct": "b",
      "explanation": "A hard atomicity requirement across a service boundary is a strong sign that boundary is in the wrong place. Proposing to move it, before reaching for two-phase commit or sagas, is the stronger move; those mechanisms are for when splitting the data really is unavoidable." }
] }
```

## Two-phase commit (2PC)

Picture a wedding officiant asking three witnesses, one after another, "do you agree this marriage should happen?" Each witness who says yes has made a binding promise; once everyone has agreed, none of them can take it back. Only after all three say yes does the officiant announce "married." If the officiant collapses right after hearing the last yes but before making the announcement, all three witnesses are stuck: they've each promised, but nobody has told them whether it's actually final. Two-phase commit works exactly like that officiant, steering every participant toward one single shared decision.

```
Phase 1 — PREPARE
  Coordinator → all participants: "can you commit?"
  Each participant does the work, writes it durably, takes locks, replies YES or NO
  A YES is a PROMISE: it must be able to commit later, no matter what

Phase 2 — COMMIT / ABORT
  All YES → coordinator writes "commit" to its own log → tells everyone to commit
  Any NO  → coordinator tells everyone to abort
```

This genuinely gives you real atomicity. Here's what it costs you in return.

**The coordinator becomes a single point of failure at the exact worst possible moment.** If it crashes after everyone voted yes, but before telling anyone the final decision, every single participant is now **stuck**, still holding its locks, unable to decide on its own what to do. This is exactly why two-phase commit is often called a blocking protocol.

**Locks are held across network round trips**, so under real contention, throughput collapses, and one slow participant can stall every other one.

**Availability multiplies downward.** The whole transaction needs every single participant to be up and reachable at once.

Support for it is also uneven; most modern databases and message brokers simply don't implement the standard needed for it at all.

Use two-phase commit for a small number of participants, inside a single data center, where atomicity truly is non-negotiable and the volume is modest, such as some financial systems or inside certain distributed databases themselves. Do not use it for anything long-running, anything a user is actively waiting on, or anything crossing organizational boundaries.

**Three-phase commit** adds an extra step before committing, to make the protocol non-blocking in some failure cases. It's rarely used in practice, because it adds an extra network round trip and can still get stuck during a genuine network partition. Modern systems that need this kind of guarantee instead reach for a **consensus protocol**, like Raft or Paxos, covered in the next lesson, which is built from the ground up to survive failures. Google's Spanner, for instance, actually runs two-phase commit *on top of* groups running Paxos, so no single coordinator's failure can ever block anything.

> **Remember:** in 2PC, a YES vote is a promise, not a suggestion. If the coordinator dies right after collecting the votes, every participant is stuck holding its lock until the coordinator comes back.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-11-2pc-q1", "type": "mcq",
      "prompt": "In two-phase commit, the coordinator crashes after every participant has voted YES, but before it sends out the final decision. What happens?",
      "options": [
        {"id":"a","text":"Participants time out and abort on their own, so the system stays safe"},
        {"id":"b","text":"Participants are stuck holding their locks; they've already promised they can commit and are not allowed to abort on their own, so they must wait for the coordinator to come back"},
        {"id":"c","text":"The transaction commits automatically once a timeout passes"},
        {"id":"d","text":"Each participant asks the original client what to do"}
      ],
      "correct": "b",
      "explanation": "A YES vote is a binding promise, so aborting on its own could leave one participant disagreeing with another that already committed. This blocked, lock-holding window is two-phase commit's defining weakness, and exactly why production systems tend to prefer sagas or a consensus-backed commit instead." }
] }
```

## Sagas: compensating transactions

Picture booking a flight, then a hotel, then a rental car, all as one trip. If the car booking fails at the end, there's no magic "undo the whole trip" button. You cancel the hotel and refund the flight yourself, one step at a time, in reverse order. A saga replaces one single atomic transaction with exactly this idea: a **sequence of separate local transactions**, each paired with its own **compensating action** that undoes its effect in spirit, if not literally. There's no global lock and no global rollback here, just a forward path and a backward path.

```
T1 reserve inventory      C1 release inventory
T2 charge payment         C2 refund payment
T3 create shipment        C3 cancel shipment

Failure at T3 → run C2, then C1, in reverse order.
```

**There are two ways to coordinate the steps of a saga:**

| | Choreography | Orchestration |
|---|---|---|
| How it works | Each service listens for events and emits the next one itself | One central coordinator calls each step in turn and decides what happens next |
| Coupling between services | Loose | Individual services stay simple; the coordinator alone knows the full flow |
| Can you see the whole workflow anywhere | No, it doesn't exist as one readable thing | Yes, it's one clear, readable state machine |
| Debugging it | Hard once you're past 3 or 4 steps; you piece it together from scattered logs | Easy; just query the coordinator's own current state |
| Best suited for | 2 to 3 steps | 4 or more steps, or anything with complicated compensation logic |

For anything beyond the simplest case, **orchestration**, using a durable workflow engine like Temporal, AWS Step Functions, or even your own state-machine table, is the stronger answer. Saying "I'd model this as an explicit state machine with the state saved for every single order" is a strong, concrete thing to say in an interview.

**Here's what building a saga actually demands of you.**

**Compensations undo the meaning of an action, not the action itself.** You can't literally un-send an email, but you can send an apology. You can't literally un-charge a card, but you can issue a refund, and the customer's statement will show both entries.

**Some steps simply cannot be compensated at all.** Order those steps last if you can, or define a **pivot point**: everything before it can still be undone, but everything after it must be retried until it eventually succeeds, since there's no going back once you pass it.

**Every single step, and every compensating action, must itself be safe to repeat**, because retries are guaranteed to happen sooner or later.

**The in-between states are real and visible to others.** Money can already be captured while the shipment is still pending. Give those in-between moments explicit names, like "payment pending" or "paid, waiting on stock," rather than pretending the whole operation happens instantly.

**You lose isolation entirely.** Some other part of the system can read this half-finished state while it's in progress. The usual countermeasures are a status flag that other operations respect, like `status = 'processing'`, keeping a separate reserved balance apart from the truly available balance, or re-checking everything again right before the final commit step.

> **Remember:** a saga has no rollback. If a later step fails, you run compensating actions for the earlier steps in reverse order; a refund, not an undo.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-11-saga-q1", "type": "mcq",
      "prompt": "In a saga, payment succeeds, but creating the shipment fails permanently afterward. What happens?",
      "options": [
        {"id":"a","text":"The database automatically rolls back the payment transaction"},
        {"id":"b","text":"A compensating action runs: issue a refund and release the reserved inventory, because there is no global rollback, only explicit, deliberate undo steps"},
        {"id":"c","text":"The coordinator blocks and waits until shipment recovers on its own"},
        {"id":"d","text":"The saga simply retries creating the shipment forever"}
      ],
      "correct": "b",
      "explanation": "The earlier local transactions have already fully committed and are already visible elsewhere. The only way back is a forward-moving compensation, like a refund that shows up as its own separate entry, run in the reverse order of the original steps. Retrying forever is only the right call once you're past a pivot point where compensating is no longer even possible." }
] }
```

## Idempotency, exactly-once effects, and reconciliation

Distributed systems retry things constantly. That means **every effect visible outside the system must be safe to attempt more than once.** This is the practical guarantee that actually replaces true atomicity here.

The mechanisms for this, from weakest to strongest:

1. **Operations that are naturally safe to repeat.** Setting `status='shipped'` directly is safe to repeat; incrementing a counter with something like `status = next(status)` is not. Setting an absolute value beats adding or subtracting a delta.
2. **Conditional writes.** A statement like `UPDATE orders SET status='paid' WHERE id=? AND status='pending'` has no effect if run a second time, and the number of rows it actually changed tells you whether this particular attempt was the one that won.
3. **Idempotency keys backed by a unique constraint**, covered in the earlier API lesson: the general-purpose mechanism for answering "have I already done this?"
4. **A ledger, instead of a single mutable value.** For anything involving money, never store just a single, changeable balance column. Store immutable rows recording every individual change instead, and calculate the balance by adding them up:

```sql
CREATE TABLE ledger_entries (
    id            uuid PRIMARY KEY,
    account_id    uuid NOT NULL,
    amount_paise  bigint NOT NULL,      -- signed; debits negative, credits positive
    txn_id        uuid NOT NULL,        -- the transfer this entry belongs to
    created_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (txn_id, account_id)         -- retry-safe: a repeat insert violates this
);
-- Every transfer writes two rows summing to zero, in one local transaction.
-- Balance = SUM(amount_paise); a running-total column is a cache, never the truth.
```

Rows that are only ever added, never changed, give you safety against retries, a complete, auditable trail of everything that happened, and the ability to prove exactly where any number came from. This is genuinely how real payment systems are built, and proposing it in a payments design is a strong signal that you understand the domain.

**Reconciliation is the safety net you should always mention, no matter how good your code is.** Even with flawless code, distributed systems drift apart over time: a webhook gets missed, a message gets dropped, a compensating action itself fails. Real production systems run a periodic job comparing the two sides against each other, like your own ledger against a payment provider's settlement report, or your inventory count against the warehouse's own count, and either fix small differences automatically or flag them for a person to look at. Saying "I'd add a daily job comparing our ledger to the payment provider's settlement report and alert on any mismatch" is exactly the sentence that shows you've operated a system like this for real.

A few related ideas worth one sentence each. **The outbox pattern**, the fix for committing to a database and publishing an event as one atomic step, is covered under messaging and queues. **Change data capture** is how you feed other, derived stores without needing two separate writes at all. **TCC**, short for Try-Confirm-Cancel, is a variant of a saga where the first step only *reserves* something rather than committing to it outright; it's the model behind holding a seat, or reserving inventory, for a limited time before it expires.

> **Remember:** never store just a mutable balance for money. Store immutable rows of every change, and compute the balance by summing them; that's what makes retries safe and history provable.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-11-ledger-q1", "type": "mcq",
      "prompt": "Why do payment systems store immutable, append-only ledger rows instead of a single mutable balance column?",
      "options": [
        {"id":"a","text":"Because adding up many rows is faster than reading one single column"},
        {"id":"b","text":"Because append-only entries with a unique key per transaction and account make retries safe, give a complete, auditable history of how the balance was reached, and never suffer a lost update"},
        {"id":"c","text":"Because databases cannot update a whole number column atomically"},
        {"id":"d","text":"Because ledgers remove the need for any consistency guarantees at all"}
      ],
      "correct": "b",
      "explanation": "A single mutable balance loses all history and is vulnerable to a lost update, plus being applied twice on a retry. Immutable entries make every single change attributable to a specific event, and safe to repeat; a stored balance kept for speed is really just a cache derived from those entries." }
] }
```

## Quick recap

| Situation | Mechanism |
|---|---|
| Data must change atomically and is in one database | **Local transaction** — and consider keeping it that way |
| Commit + publish an event | **Transactional outbox** (or CDC) |
| Multi-step business workflow across services | **Saga**, orchestrated if 4+ steps |
| Reserve now, confirm or cancel shortly after | **TCC / reservation with a TTL** |
| Small number of participants, one datacenter, atomicity non-negotiable | **2PC**, knowing it blocks on coordinator failure |
| Replicated state that must never diverge | **Consensus (Raft/Paxos)** |
| Any of the above | **Idempotent steps + reconciliation job** |
