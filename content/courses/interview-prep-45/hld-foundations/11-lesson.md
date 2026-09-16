---
kind: lesson
id_key: interview-prep-45/hld-11-distributed-transactions
course: interview-prep-45
section: hld-foundations
section_title: "System Design Foundations (HLD)"
section_position: 2
title: "Distributed Transactions and Data Integrity"
position: 11
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

The moment your design has two services with two databases — or one sharded database — the single `BEGIN … COMMIT` you have relied on your whole career stops working. "Reserve inventory, charge the card, create the shipment" now spans three systems, any of which can fail after the others succeeded. This lesson covers the four honest answers to that problem and how to choose between them.

## Why you cannot just use a transaction

A local transaction gives atomicity because one database owns the log, the locks, and the commit decision. Across services none of that exists:

- Service A commits, service B fails → **partial state** the user can see.
- Service B is slow → A holds locks across a network call → contention and cascading timeouts.
- Either can crash between "did the work" and "recorded that it did the work".

Three principles to state before you propose a mechanism:

1. **The best distributed transaction is the one you don't have.** If two pieces of data must change atomically, that is strong evidence they belong in the same service and the same database. Redrawing the service boundary is a legitimate and senior answer.
2. **Business processes are already eventually consistent.** A hotel takes your booking, charges you later, and cancels if the payment fails. Real-world workflows are compensating, not atomic — modelling them that way is not a compromise.
3. **Choose based on how long the operation takes and how much you can hold locks.** Milliseconds within one datacenter and a hard atomicity requirement point one way; a multi-second, multi-service workflow points the other.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-11-why-q1", "type": "mcq",
      "prompt": "Two microservices must update their data atomically on every request, and this is the dominant workflow. What is the strongest first response in a design interview?",
      "options": [
        {"id":"a","text":"Implement two-phase commit between them"},
        {"id":"b","text":"Question the service boundary — data that must change atomically on every request probably belongs in one service and one database; distributed transactions are the fallback, not the goal"},
        {"id":"c","text":"Use eventual consistency and hope for the best"},
        {"id":"d","text":"Put both databases behind one connection pool"}
      ],
      "correct": "b",
      "explanation": "A hard atomicity requirement across a boundary is evidence the boundary is in the wrong place. Proposing to move it before reaching for 2PC or sagas is the senior move; the mechanisms are what you use when the split is genuinely necessary." }
] }
```

## Two-phase commit (2PC)

A coordinator drives all participants to a single decision.

```
Phase 1 — PREPARE
  Coordinator → all participants: "can you commit?"
  Each participant does the work, writes it durably, takes locks, replies YES or NO
  A YES is a PROMISE: it must be able to commit later, no matter what

Phase 2 — COMMIT / ABORT
  All YES → coordinator writes "commit" to its own log → tells everyone to commit
  Any NO  → coordinator tells everyone to abort
```

It gives real atomicity. What it costs:

- **The coordinator is a single point of failure at the worst moment.** If it crashes after participants voted YES but before broadcasting the decision, every participant is **blocked**, holding locks, unable to decide alone. This is why 2PC is often called a blocking protocol.
- **Locks are held across network round trips**, so throughput collapses under contention and one slow participant stalls everyone.
- **Availability multiplies downward**: the transaction needs every participant up.
- Support is uneven — most modern datastores and message brokers do not implement XA at all.

Use it for: a small number of participants, inside one datacenter, where atomicity is non-negotiable and volume is modest (some financial systems, some distributed databases internally). Do not use it for: long-running, user-facing, or cross-organisation workflows.

**Three-phase commit** adds a pre-commit phase to make the protocol non-blocking in some failure cases; it is rarely used in practice because it adds a round trip and still fails under network partitions. Modern systems that need this reach for a **consensus protocol** (Raft/Paxos) instead, which is fault-tolerant by design — Spanner runs 2PC *over* Paxos groups, so no single coordinator failure can block anything.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-11-2pc-q1", "type": "mcq",
      "prompt": "In 2PC, the coordinator crashes after every participant voted YES but before sending the decision. What happens?",
      "options": [
        {"id":"a","text":"Participants time out and abort independently, so the system is safe"},
        {"id":"b","text":"Participants are blocked holding their locks — they promised they can commit and may not unilaterally abort, so they must wait for the coordinator to recover"},
        {"id":"c","text":"The transaction commits automatically after a timeout"},
        {"id":"d","text":"Each participant asks the client what to do"}
      ],
      "correct": "b",
      "explanation": "A YES vote is a binding promise, so aborting alone could diverge from a peer that committed. This blocking window with locks held is 2PC's defining weakness, and the reason production systems prefer sagas or consensus-backed commit." }
] }
```

## Sagas: compensating transactions

A saga replaces one atomic transaction with a **sequence of local transactions**, each with a **compensating action** that semantically undoes it. There is no global lock and no global rollback — there is a forward path and a backward path.

```
T1 reserve inventory      C1 release inventory
T2 charge payment         C2 refund payment
T3 create shipment        C3 cancel shipment

Failure at T3 → run C2, then C1, in reverse order.
```

**Two coordination styles:**

| | Choreography | Orchestration |
|---|---|---|
| How | Each service listens for events and emits the next one | A central orchestrator calls each step and decides what's next |
| Coupling | Loose | Services are simple; the orchestrator knows the flow |
| Visibility | The workflow exists nowhere explicitly | The workflow is one readable state machine |
| Debugging | Hard past ~4 steps — you reconstruct it from logs | Easy: query the orchestrator's state |
| Best for | 2–3 steps | 4+ steps, or anything with complex compensation |

For anything non-trivial, **orchestration** (a durable workflow engine — Temporal, Step Functions, or your own state machine table) is the better answer, and saying "I'd model this as an explicit state machine with a persisted state per order" is a strong, concrete design statement.

**What sagas demand of you:**

- **Compensations are semantic, not literal.** You cannot un-send an email; you send an apology. You cannot un-charge a card; you refund it, and the statement shows both.
- **Some steps are not compensatable.** Order them last, or add a **pivot point**: everything before it can be undone, everything after it must be retried until it succeeds.
- **Every step and every compensation must be idempotent**, because retries are guaranteed.
- **Intermediate states are visible.** Money is captured while the shipment is still pending. Model those states explicitly (`PENDING_PAYMENT`, `PAID_AWAITING_STOCK`) rather than pretending the operation is instantaneous.
- **Isolation is gone.** Another transaction can read the half-finished state. Countermeasures: a semantic lock (`status = 'processing'` that other operations respect), a reserved/pending balance separate from the available balance, or re-reading and re-validating at the commit step.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-11-saga-q1", "type": "mcq",
      "prompt": "In a saga, payment succeeds but shipment creation fails permanently. What happens?",
      "options": [
        {"id":"a","text":"The payment transaction is rolled back by the database"},
        {"id":"b","text":"A compensating transaction runs — issue a refund and release the inventory — because there is no global rollback, only explicit semantic undo steps"},
        {"id":"c","text":"The coordinator blocks until shipment recovers"},
        {"id":"d","text":"The saga retries shipment forever"}
      ],
      "correct": "b",
      "explanation": "Local transactions have already committed and are visible; the only way back is a forward-moving compensation (a refund, which appears as its own entry) executed in reverse step order. Indefinite retry is only appropriate past a pivot point where compensation is impossible." }
] }
```

## Idempotency, exactly-once effects, and reconciliation

Distributed systems retry. Therefore **every externally-visible effect must be safe to attempt more than once** — this is the practical guarantee that replaces atomicity.

The mechanisms, in ascending order of strength:

1. **Naturally idempotent operations.** `SET status='shipped'` beats `status = next(status)`; absolute values beat deltas.
2. **Conditional writes.** `UPDATE orders SET status='paid' WHERE id=? AND status='pending'` — applying twice is a no-op, and the affected-row count tells you which attempt won.
3. **Idempotency keys with a unique constraint** (covered in the API lesson) — the general mechanism for "did I already do this?".
4. **Ledger, not mutation.** For anything financial, never store a mutable balance. Store immutable double-entry rows and derive the balance:

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

Immutable append-only entries give you replay safety, a complete audit trail, and the ability to prove where a number came from. This is how real payment systems work, and proposing it in a payments design is a strong signal.

**Reconciliation is the safety net you should always mention.** Even with perfect code, distributed systems drift: a webhook is missed, a message is dropped, a compensation fails. Production systems run periodic jobs that compare the two sides — your ledger against the payment provider's settlement file, your inventory against the warehouse count — and either auto-correct or raise an exception for a human. "I'd add a daily reconciliation job comparing our ledger to the PSP's settlement report and alert on any mismatch" is the sentence that says you have operated one of these systems.

Related, and worth one line each: **the outbox pattern** (previous lesson) is what makes "commit and publish" atomic; **CDC** is how you feed derived stores without dual writes; and **TCC (Try–Confirm–Cancel)** is a saga variant where the first step *reserves* rather than commits — the model behind seat holds and inventory reservations with a TTL.

```knowledge-check
{ "questions": [
    { "id": "ip45-hld-11-ledger-q1", "type": "mcq",
      "prompt": "Why do payment systems store immutable double-entry ledger rows instead of a mutable `balance` column?",
      "options": [
        {"id":"a","text":"Because summing rows is faster than reading one column"},
        {"id":"b","text":"Because append-only entries with a unique key per (transaction, account) make retries safe, give a complete auditable history of how the balance was reached, and never suffer lost updates"},
        {"id":"c","text":"Because databases cannot update integer columns atomically"},
        {"id":"d","text":"Because ledgers avoid the need for any consistency guarantees"}
      ],
      "correct": "b",
      "explanation": "A mutable balance loses history and is vulnerable to lost updates and double-application on retry. Immutable entries make every change attributable and idempotent; a stored balance, when needed for speed, is treated as a cache derived from the entries." }
] }
```

## Key takeaways

**The decision table:**

| Situation | Mechanism |
|---|---|
| Data must change atomically and is in one database | **Local transaction** — and consider keeping it that way |
| Commit + publish an event | **Transactional outbox** (or CDC) |
| Multi-step business workflow across services | **Saga**, orchestrated if 4+ steps |
| Reserve now, confirm or cancel shortly after | **TCC / reservation with a TTL** |
| Small number of participants, one datacenter, atomicity non-negotiable | **2PC**, knowing it blocks on coordinator failure |
| Replicated state that must never diverge | **Consensus (Raft/Paxos)** — next lesson |
| Any of the above | **Idempotent steps + reconciliation job** |

- **The strongest opening move is to question the boundary.** Distributed transactions are what you use when the split is genuinely required.
- **2PC's fatal property is blocking**: a coordinator crash after the votes leaves participants stuck holding locks.
- **Sagas trade atomicity for availability** and hand you three obligations: compensations, idempotency, and explicit intermediate states that other readers will see.
- **Idempotency plus reconciliation is what production actually relies on.** Mentioning the reconciliation job unprompted is one of the clearest "has shipped this" signals available in a design interview.
