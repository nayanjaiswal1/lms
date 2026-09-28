---
kind: lesson
id_key: interview-prep-45/day-15-backend
course: interview-prep-45
section: backend-databases
section_title: "Databases (PostgreSQL)"
section_position: 9
section_group: "Backend"
title: "Transactions and Isolation"
position: 3
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Transactions are the second most-asked backend database topic, right after indexes. Every interviewer wants to know you understand ACID as more than an acronym, and can say exactly what breaks when two requests touch the same row at once. This lesson reproduces the classic bugs yourself, then writes a bank transfer that survives a crash mid-flight.

## ACID, and which letter Postgres actually tunes

- **Atomicity**: a transaction is all-or-nothing. If one statement fails, every earlier statement in that transaction rolls back too.
- **Consistency**: a transaction moves the database from one valid state to another. Constraints (foreign keys, checks, uniqueness) are never violated at commit.
- **Isolation**: concurrent transactions behave as if they ran one after another, to a degree you control. This is the part interviewers actually probe, covered below.
- **Durability**: once a transaction commits, it survives a crash. Postgres guarantees this with a write-ahead log (WAL), flushed to disk before the commit returns to you.

Here's the trap: candidates recite ACID but can't say which letter is actually adjustable. Atomicity and durability are unconditional. Consistency comes from your constraints. Isolation is the only one with a dial you can turn.

> **Remember:** atomicity and durability are unconditional guarantees. Isolation is the one knob Postgres actually lets you tune.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-transactions-acid-q1", "type": "mcq",
      "prompt": "Which ACID property is Postgres's isolation level actually controlling?",
      "options": [
        {"id":"a","text":"Isolation, since atomicity and durability are unconditional and consistency comes from your own constraints"},
        {"id":"b","text":"Atomicity"},
        {"id":"c","text":"Durability"},
        {"id":"d","text":"All four equally"}
      ],
      "correct": "a",
      "explanation": "Postgres always guarantees atomicity and durability, and consistency is whatever your constraints define. Isolation level is the one setting you actively choose, trading strictness for concurrency." }
] }
```

## Isolation levels and the bugs each one allows

Postgres has four isolation level names but only three distinct behaviors (`READ UNCOMMITTED` behaves exactly like `READ COMMITTED`).

| Level | Dirty read | Non-repeatable read | Phantom read | Serialization anomaly |
|---|---|---|---|---|
| Read Committed (default) | No | Yes | Yes | Yes |
| Repeatable Read | No | No | No | Yes |
| Serializable | No | No | No | No |

- **Dirty read**: reading a row another transaction wrote but hasn't committed yet. Postgres never allows this, at any level.
- **Non-repeatable read**: you read the same row twice in one transaction and get two different values, because something else committed a change in between.
- **Phantom read**: you re-run the same `WHERE` query and get a different *set* of rows, because another transaction inserted or deleted matching rows in between.
- **Serialization anomaly**: the combined effect of several committed transactions could not have come from *any* one-at-a-time ordering of them, even though none of the three bugs above happened individually.

Reproduce a non-repeatable read across two `psql` sessions:

```sql
-- Session A
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT balance FROM accounts WHERE id = 1;  -- returns 100

-- Session B, commits in between
BEGIN;
UPDATE accounts SET balance = 50 WHERE id = 1;
COMMIT;

-- Session A, same transaction, same query
SELECT balance FROM accounts WHERE id = 1;  -- now returns 50
COMMIT;
```

Switch session A to `REPEATABLE READ` and rerun: the second `SELECT` still returns `100`. Repeatable Read takes one consistent snapshot at the start of the transaction and reads from it for the whole transaction. Postgres does this with MVCC (multi-version concurrency control): every row keeps multiple versions, each tagged with the transaction that created it, and a reader only ever sees versions that were committed before its own snapshot began. An uncommitted version is invisible to everyone except the transaction that wrote it, which is exactly why a dirty read is structurally impossible in Postgres.

> **Remember:** Postgres never allows a dirty read at any level, because MVCC keeps an uncommitted row version invisible to everyone but its own writer. Repeatable Read fixes non-repeatable reads by freezing a snapshot at the start of the transaction.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-transactions-isolation-q1", "type": "mcq",
      "prompt": "Why can Postgres skip READ UNCOMMITTED entirely and just treat it as READ COMMITTED?",
      "options": [
        {"id":"a","text":"Because MVCC makes an uncommitted row version invisible to every transaction except the one that wrote it, so there is no cheap 'read whatever is there' mode to offer"},
        {"id":"b","text":"Because dirty reads are actually allowed at every level in Postgres"},
        {"id":"c","text":"Because Postgres does not support multiple isolation levels"},
        {"id":"d","text":"Because READ UNCOMMITTED is faster and Postgres always picks the fastest option"}
      ],
      "correct": "a",
      "explanation": "MVCC keeps every uncommitted row version hidden from other transactions. There is no lower mode that could expose it, so READ UNCOMMITTED has nothing extra to offer and simply behaves like READ COMMITTED." }
] }
```

## Savepoints: undoing part of a transaction

A savepoint marks a point inside a transaction you can roll back to, without throwing away the whole transaction.

```sql
BEGIN;
INSERT INTO orders (id, customer_id, total) VALUES (501, 7, 250.00);

SAVEPOINT before_discount;
UPDATE promotions SET uses_remaining = uses_remaining - 1
WHERE code = 'SAVE10' AND uses_remaining > 0;

-- if 0 rows updated, the promo was already exhausted: undo just that part
ROLLBACK TO SAVEPOINT before_discount;

-- the order insert is still intact
COMMIT;
```

Django's nested `atomic()` blocks are built on savepoints:

```python
from django.db import transaction, IntegrityError

def place_order(customer_id, items, promo_code=None):
    with transaction.atomic():                      # outer transaction
        order = Order.objects.create(customer_id=customer_id, total=0)
        for item in items:
            OrderLine.objects.create(order=order, **item)

        if promo_code:
            try:
                with transaction.atomic():           # this becomes a SAVEPOINT
                    apply_promo(order, promo_code)
            except IntegrityError:
                pass                                  # rolls back to the savepoint; the order still commits

        order.total = order.compute_total()
        order.save()
    return order
```

The inner `atomic()` is a savepoint, not a second real transaction. Django only opens one actual `BEGIN`/`COMMIT` pair, at the outermost `atomic()` block.

> **Remember:** a nested `atomic()` in Django is a savepoint, not a new transaction. Only the outermost block opens the real `BEGIN`/`COMMIT`.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-transactions-savepoint-q1", "type": "mcq",
      "prompt": "An inner transaction.atomic() block in Django raises IntegrityError, which is caught. What happens to the outer transaction?",
      "options": [
        {"id":"a","text":"The whole outer transaction rolls back, including work done before the inner block"},
        {"id":"b","text":"Only the inner block's work rolls back, since it was a savepoint; the outer transaction continues and can still commit"},
        {"id":"c","text":"Django raises a second exception and crashes"},
        {"id":"d","text":"Nothing rolls back; the failed inner block's changes are kept anyway"}
      ],
      "correct": "b",
      "explanation": "A nested atomic() maps to a SAVEPOINT. Catching the exception and letting execution continue rolls back only to that savepoint, leaving everything before it in the outer transaction intact." }
] }
```

## A bank transfer that survives a crash

The textbook transaction example, and interviewers push on the failure modes: what if the process dies between the debit and the credit? What if two transfers race on the same account?

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

    # lock both accounts in a fixed order (sorted by id) so two transfers
    # going in opposite directions can never deadlock on each other
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

    # F() pushes the arithmetic into the SQL UPDATE itself, so there's no
    # read-modify-write race even without the explicit lock above
    Account.objects.filter(id=from_account_id).update(balance=F("balance") - amount)
    Account.objects.filter(id=to_account_id).update(balance=F("balance") + amount)

    Transfer.objects.create(
        from_account_id=from_account_id,
        to_account_id=to_account_id,
        amount=amount,
        status="completed",
    )
```

Four things make this crash-safe:

1. **`@transaction.atomic`** wraps everything in one `BEGIN`/`COMMIT`. If the process dies after the debit but before the credit, Postgres rolls the whole thing back on connection loss. Nothing is left half-done.
2. **`select_for_update()`** takes row-level locks on both accounts, so a concurrent transfer touching either one waits until this transaction commits or rolls back.
3. **Sorting the account IDs before locking** guarantees every transaction acquires locks in the same order. A transfer A to B and a transfer B to A both lock the lower ID first, so neither one ever holds a lock the other one needs while waiting for the one it holds, which is exactly how a deadlock forms.
4. **`F("balance") - amount`** pushes the read-and-write into one atomic SQL statement, immune to a lost update even for code that skips the explicit lock.

> **Remember:** sort the IDs before locking. A fixed lock order across all transactions is what actually prevents deadlocks between transfers going in opposite directions.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-transactions-transfer-q1", "type": "mcq",
      "prompt": "Two concurrent transfers run: A pays B, and B pays A, at the same time. Why does sorting the account IDs before calling select_for_update() prevent a deadlock?",
      "options": [
        {"id":"a","text":"It makes the transfers run one after another automatically"},
        {"id":"b","text":"Every transaction locks accounts in the same fixed order, so neither transaction can be left holding one lock while waiting forever on a lock the other transaction already holds"},
        {"id":"c","text":"Sorting has no effect on deadlocks; only serializable isolation prevents them"},
        {"id":"d","text":"It only matters for accounts with the same balance"}
      ],
      "correct": "b",
      "explanation": "A deadlock needs two transactions each waiting on a lock the other holds. If every transaction locks the lower ID first, that circular wait can never form, because both transactions compete for the same first lock instead of each grabbing a different one." }
] }
```

## Read Committed vs Serializable, in one interview answer

Read Committed re-takes its snapshot before every statement, so within one transaction it can see other transactions' commits happen in between statements: that's where non-repeatable reads and phantoms come from. Serializable takes one snapshot at the start and also tracks read/write dependencies between concurrently running transactions. If committing would produce a result no one-at-a-time ordering could have produced, Postgres aborts one of the transactions with a serialization failure (error code `40001`), and the application has to retry it.

Read Committed is Postgres's default because it never blocks on other readers and almost never aborts. Serializable trades some of that throughput, plus added retry logic in your application, for the strongest guarantee Postgres offers.

> **Remember:** Read Committed never aborts you but allows more anomalies. Serializable allows none, at the cost of occasionally aborting a transaction that your code then has to retry.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-transactions-serializable-q1", "type": "mcq",
      "prompt": "What must application code do that plain Read Committed code does not need to do, when using Serializable isolation?",
      "options": [
        {"id":"a","text":"Nothing different; Serializable is a drop-in replacement with no other changes needed"},
        {"id":"b","text":"Catch a serialization failure (error 40001) and retry the transaction, since Postgres can abort one of two conflicting transactions rather than let an anomaly through"},
        {"id":"c","text":"Manually call select_for_update on every table"},
        {"id":"d","text":"Disable foreign key constraints"}
      ],
      "correct": "b",
      "explanation": "Serializable's guarantee comes from aborting a transaction when committing it would create an anomaly no serial ordering could produce. The application must be ready to catch that error and retry, which Read Committed code never has to do." }
] }
```
