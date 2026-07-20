---
kind: lesson
id_key: sql-mastery/transactions-concurrency/lesson
course: sql-mastery
section: transactions-concurrency
section_title: "Transactions & Concurrency"
section_position: 12
title: "Transactions & Concurrency: BEGIN, COMMIT, ROLLBACK"
position: 0
estimated_minutes: 25
source: [sql-mastery-curriculum.md]
---
Every `INSERT`/`UPDATE`/`DELETE` in this course so far has run as its own standalone statement. Real applications frequently need several statements to succeed or fail *together* — moving stock from one book to another, or registering a new member and their first loan in one action. That's what a transaction gives you.

## BEGIN, COMMIT, and ROLLBACK

A transaction groups multiple statements into one all-or-nothing unit: `BEGIN` starts it, `COMMIT` makes every change inside it permanent, and `ROLLBACK` discards every change inside it as if none of it ever happened:

```sql-try
BEGIN;

UPDATE books SET stock = stock - 1 WHERE id = 1;
UPDATE books SET stock = stock + 1 WHERE id = 4;

COMMIT;

SELECT id, title, stock FROM books WHERE id IN (1, 4);
```

Both `UPDATE`s ran, then `COMMIT` made them permanent together. Now watch `ROLLBACK` undo an in-progress transaction instead:

```sql-try
BEGIN;

UPDATE books SET stock = 0 WHERE id = 1;

ROLLBACK;

SELECT id, title, stock FROM books WHERE id = 1;
```

Even though the `UPDATE` ran without error, `ROLLBACK` discards it entirely — the `SELECT` afterward shows book 1's original stock, untouched. Outside of an explicit transaction, SQLite (like most databases) treats every single statement as its own implicit transaction, auto-committed the instant it succeeds — which is why every earlier lesson's `UPDATE`/`DELETE` examples took effect immediately with no `BEGIN`/`COMMIT` of their own.

## Atomicity: why multi-statement updates need a transaction

**Atomicity** — the "A" in the classic ACID guarantees — means a transaction's statements succeed or fail as one indivisible unit; there's no such thing as "half-committed." This matters most when one statement depends on another leaving the data in a particular state. Imagine moving a book between two "locations" by decrementing stock in one row and incrementing it in another — without a transaction wrapping both `UPDATE`s, a crash or error between the two statements leaves the data inconsistent (stock removed from the first book, never added to the second, with no record of where it went). Wrapping both in `BEGIN ... COMMIT` guarantees that either both happen or neither does.

## Isolation levels: what one transaction can see of another

**Isolation** governs what one in-progress transaction can see of another transaction running at the same time — a real concern the moment more than one connection can write to the database concurrently. Two classic problems isolation levels are named after:

- **Dirty read** — reading a row that another transaction has changed but not yet committed. If that other transaction then rolls back, you've read data that never actually existed.
- **Non-repeatable read** — reading the same row twice within one transaction and getting two different answers, because another transaction committed a change to it in between your two reads.

Stricter isolation levels prevent more of these at the cost of more locking/blocking between concurrent transactions; looser levels allow more concurrency but open the door to these anomalies. SQLite's default locking behavior is actually stricter than the default in PostgreSQL or MySQL (`READ COMMITTED`) — worth knowing for interviews, since "what's the default isolation level" is a common follow-up question, and the honest answer is "it depends on the database," not a universal constant.

## A note on row locking

When one transaction is in the middle of writing to a row, most databases block a second transaction from writing to the same data until the first one finishes with `COMMIT` or `ROLLBACK` — this is what actually enforces isolation in practice. SQLite locks at a coarser grain than Postgres or MySQL (closer to whole-database-file than per-row for writers), which is part of why SQLite is a great fit for a single-application embedded database but not the first choice for a system with many concurrent writers.

## Knowledge check

Answer all three questions correctly to unlock **Mark as Complete** for this lesson. Every attempt is recorded.

```knowledge-check
{
  "questions": [
    {
      "id": "transactions-concurrency-q1",
      "type": "mcq",
      "prompt": "What does COMMIT do?",
      "options": [
        { "id": "a", "text": "Starts a new transaction" },
        { "id": "b", "text": "Makes every change made since BEGIN permanent" },
        { "id": "c", "text": "Undoes every change made since BEGIN" },
        { "id": "d", "text": "Locks the table so no one else can read it" }
      ],
      "correct": "b",
      "explanation": "COMMIT permanently applies all changes made within the transaction. ROLLBACK is what undoes them instead."
    },
    {
      "id": "transactions-concurrency-q2",
      "type": "mcq",
      "prompt": "What is a 'dirty read'?",
      "options": [
        { "id": "a", "text": "A query that returns duplicate rows" },
        { "id": "b", "text": "Reading a row that another transaction has changed but not yet committed" },
        { "id": "c", "text": "A read that ignores an available index" },
        { "id": "d", "text": "Reading a NULL value instead of the expected data" }
      ],
      "correct": "b",
      "explanation": "A dirty read means seeing another transaction's uncommitted change — if that transaction rolls back, you've read data that never actually existed."
    },
    {
      "id": "transactions-concurrency-q3",
      "type": "sql",
      "prompt": "Write a transaction that increases the stock of book id 2 by 2 and decreases the stock of book id 5 by 2, commits, then selects both books' id and stock.",
      "starter": "BEGIN;",
      "solution": "BEGIN; UPDATE books SET stock = stock + 2 WHERE id = 2; UPDATE books SET stock = stock - 2 WHERE id = 5; COMMIT; SELECT id, stock FROM books WHERE id IN (2, 5);"
    }
  ]
}
```

## What's next

That's every fundamental this course set out to teach — querying, filtering, aggregating, joining, modifying data safely inside transactions, subqueries, schema design, indexing, dates, and window functions. **SQL for Interviews** closes the course by walking through the classic problem shapes that combine everything you've learned.
