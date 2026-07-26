---
kind: lesson
id_key: interview-prep-45/day-15-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "PostgreSQL Transactions"
position: 15
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
Transactions are the single most-tested backend topic after "explain a database index." Every interviewer wants to know you understand ACID beyond the acronym, and can reason about what actually breaks when two requests hit the same row at once. Today you'll reproduce the classic anomalies yourself, then write the transaction logic a bank transfer needs to survive a crash mid-flight.

## ACID, precisely

- **Atomicity** — a transaction is all-or-nothing. If any statement fails, every prior statement in the transaction is rolled back.
- **Consistency** — a transaction moves the database from one valid state to another; constraints (foreign keys, checks, uniqueness) are never violated at commit.
- **Isolation** — concurrent transactions behave as if they ran one after another, to a degree controlled by the isolation level (see below — this is the part interviewers actually probe).
- **Durability** — once committed, the write survives a crash (Postgres achieves this via WAL — write-ahead logging — fsynced to disk before the commit returns).

Interview trap: candidates recite the acronym but can't say which letter Postgres' isolation levels actually govern. It's **I** — atomicity and durability are unconditional, consistency is enforced by constraints, isolation is the only one that's *tunable*.

## Isolation levels and the anomalies they permit

Postgres supports four levels, but only implements three distinct behaviors (`READ UNCOMMITTED` is treated as `READ COMMITTED`):

| Level | Dirty read | Non-repeatable read | Phantom read | Serialization anomaly |
|---|---|---|---|---|
| Read Committed (default) | No | Yes | Yes | Yes |
| Repeatable Read | No | No | No | Yes |
| Serializable | No | No | No | No |

- **Dirty read** — reading a row another transaction wrote but hasn't committed. Postgres never allows this, at any level.
- **Non-repeatable read** — you read a row twice in the same transaction and get different values because another transaction committed a change in between.
- **Phantom read** — you re-run the same `WHERE` query and get a different *set of rows* because another transaction inserted/deleted matching rows.
- **Serialization anomaly** — the overall effect of concurrently committed transactions couldn't be produced by *any* serial ordering of them, even though no individual anomaly above occurred.

### Reproducing a non-repeatable read

Open two `psql` sessions.

```sql
-- Session A
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT balance FROM accounts WHERE id = 1;  -- returns 100

-- Session B (commits in between)
BEGIN;
UPDATE accounts SET balance = 50 WHERE id = 1;
COMMIT;

-- Session A, same transaction
SELECT balance FROM accounts WHERE id = 1;  -- now returns 50 — non-repeatable read
COMMIT;
```

Bump session A to `REPEATABLE READ` and rerun: the second `SELECT` still returns `100`, because Repeatable Read takes a consistent snapshot at the start of the transaction. Session B's `UPDATE` will actually block if it tries to write a row A's snapshot has "seen" changed elsewhere — Postgres uses snapshot isolation via MVCC (multi-version concurrency control), not locking reads.

### Why "dirty read" never happens in Postgres

Postgres' MVCC keeps multiple versions of each row (tuples), each tagged with the transaction ID that created it. A reader only ever sees versions committed before its snapshot was taken — an uncommitted version is invisible to everyone but the transaction that wrote it. This is why Postgres can skip `READ UNCOMMITTED` entirely: there's no cheap "read whatever's there" mode to offer, MVCC makes dirty reads structurally impossible.

## Savepoints — partial rollback inside a transaction

A savepoint lets you undo part of a transaction without abandoning the whole thing — useful for "try this operation, and if it fails, continue without it."

```sql
BEGIN;

INSERT INTO orders (id, customer_id, total) VALUES (501, 7, 250.00);

SAVEPOINT before_discount;

-- attempt an operation that might violate a constraint
UPDATE promotions SET uses_remaining = uses_remaining - 1
WHERE code = 'SAVE10' AND uses_remaining > 0;

-- if 0 rows updated, the promo was exhausted — roll back just this part
ROLLBACK TO SAVEPOINT before_discount;

-- transaction continues, order insert is still intact
COMMIT;
```

In Django, savepoints are the mechanism behind nested `atomic()` blocks:

```python
from django.db import transaction, IntegrityError

def place_order(customer_id, items, promo_code=None):
    with transaction.atomic():                      # outer transaction / BEGIN
        order = Order.objects.create(customer_id=customer_id, total=0)
        for item in items:
            OrderLine.objects.create(order=order, **item)

        if promo_code:
            try:
                with transaction.atomic():           # SAVEPOINT
                    apply_promo(order, promo_code)
            except IntegrityError:
                pass                                  # ROLLBACK TO SAVEPOINT — order still commits

        order.total = order.compute_total()
        order.save()
    return order
```

The inner `atomic()` maps to a savepoint, not a new top-level transaction — Django only opens one real `BEGIN`/`COMMIT` at the outermost `atomic()` block.

## Implementation: bank transfer that survives a crash

The textbook transaction example, and interviewers will push on the failure modes: what if the process dies between the debit and the credit? What if two transfers race on the same account?

```python
from django.db import transaction
from django.db.models import F
from decimal import Decimal

class InsufficientFundsError(Exception):
    pass

@transaction.atomic
def transfer_funds(from_account_id: int, to_account_id: int, amount: Decimal):
    if amount <= 0:
        raise ValueError("amount must be positive")

    # order lock acquisition by primary key to avoid deadlocks between
    # concurrent transfers going in opposite directions (A->B and B->A)
    ids = sorted([from_account_id, to_account_id])
    accounts = {
        a.id: a
        for a in Account.objects.select_for_update().filter(id__in=ids)
    }

    from_account = accounts[from_account_id]
    to_account = accounts[to_account_id]

    if from_account.balance < amount:
        raise InsufficientFundsError(
            f"account {from_account_id} has {from_account.balance}, needs {amount}"
        )

    # F() expressions push the arithmetic into the SQL UPDATE itself,
    # avoiding a read-modify-write race even without select_for_update
    Account.objects.filter(id=from_account_id).update(balance=F("balance") - amount)
    Account.objects.filter(id=to_account_id).update(balance=F("balance") + amount)

    Transfer.objects.create(
        from_account_id=from_account_id,
        to_account_id=to_account_id,
        amount=amount,
        status="completed",
    )
```

What makes this crash-safe:

1. **`@transaction.atomic`** wraps everything in one `BEGIN`/`COMMIT`. If the process dies after the debit `UPDATE` but before the credit, Postgres rolls the whole transaction back on connection loss — nothing is left half-applied.
2. **`select_for_update()`** takes row-level locks on both accounts for the duration of the transaction, so a concurrent transfer touching the same account blocks until this one commits or rolls back.
3. **Sorting the IDs before locking** guarantees every transaction acquires locks in the same global order, which is how you avoid deadlocks — two transfers A→B and B→A both lock the lower ID first instead of each holding one lock and waiting on the other's.
4. **`F("balance") - amount`** is an atomic SQL-level update, immune to lost updates even for callers that skip the explicit lock.

## Common interview questions, answered

**What is ACID?** — see the definitions above; be ready to say *which* guarantee handles which failure (crash → durability, concurrent writers → isolation, constraint violation → consistency, partial failure → atomicity).

**Difference between READ COMMITTED and SERIALIZABLE?**
Read Committed re-takes a snapshot before every statement, so it can see other transactions' commits between statements within the same transaction (non-repeatable reads, phantoms). Serializable takes a snapshot once at the start of the transaction and additionally tracks read/write dependencies between concurrent transactions; if committing would produce a result no serial execution order could produce, Postgres aborts one of the transactions with a serialization failure (`40001`) that the application must retry. Read Committed is Postgres' default because it never blocks on other readers and rarely aborts; Serializable trades throughput and added retry logic for the strongest guarantee.

## Key takeaways

- MVCC is why Postgres never produces dirty reads — readers see only committed row versions as of their snapshot.
- Isolation level choice is a trade-off between anomaly protection and either blocking or retry-on-conflict overhead — default to Read Committed, escalate deliberately.
- Savepoints (`SAVEPOINT` / `ROLLBACK TO`) give partial rollback inside one transaction; Django's nested `atomic()` uses them automatically.
- `select_for_update()` plus a consistent lock-acquisition order is the standard defense against deadlocks in multi-row transactions.
- `F()` expressions push read-modify-write arithmetic into the database, closing races that a Python-side `balance += amount` would leave open.
- Serializable isolation doesn't prevent conflicts — it detects them and forces a retry; your app code must handle `OperationalError`/serialization failures.
