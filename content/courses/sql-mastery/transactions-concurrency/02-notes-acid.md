---
kind: lesson
id_key: sql-mastery/transactions-concurrency/note-acid
course: sql-mastery
section: transactions-concurrency
section_title: "Transactions & Concurrency"
section_position: 12
title: "Notes: The Full ACID Acronym"
position: 2
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

The main lesson in this section already covered two of the four ACID letters in depth: **Atomicity** (the `BEGIN`/`COMMIT`/`ROLLBACK` all-or-nothing guarantee) and **Isolation** (dirty reads, non-repeatable reads, and how SQLite's locking compares to Postgres/MySQL). This note completes the picture with **Consistency** and **Durability**, and gives you the acronym as a single interview-ready answer.

## A quick recap of the two you already know

- **Atomicity** — a transaction's statements succeed or fail as one unit. No such thing as half-committed.
- **Isolation** — what one in-progress transaction can see of another one running concurrently.

## C — Consistency

Consistency means a transaction can only move the database from one **valid state** to another valid state — every constraint, `CHECK`, `NOT NULL`, `UNIQUE`, and foreign key rule you defined in the schema design lesson must still hold true after the transaction commits.

```sql-try
BEGIN;

INSERT INTO reviews (book_id, rating, comment) VALUES (1, 9, 'Too high!');

COMMIT;
```

This never reaches a "committed" state at all — the `CHECK (rating BETWEEN 1 AND 5)` constraint from the schema design lesson rejects the row before the transaction can commit, so the database is never left in an invalid state. That's Consistency in action: it isn't a separate mechanism you write code for, it's the database refusing to let a transaction complete if the result would violate a rule you already declared.

## D — Durability

Durability means once a transaction commits, the result survives — even a crash or power loss immediately afterward can't undo it. Databases achieve this with a **write-ahead log (WAL)**: before data pages on disk are actually modified, the change is first written to an append-only log file. If the database crashes mid-write, it replays the WAL on restart to redo any committed-but-not-yet-applied changes, and discards anything that never reached `COMMIT`.

```sql-try
PRAGMA journal_mode;
```

SQLite defaults to a rollback-journal mode, but can run in `WAL` mode explicitly (`PRAGMA journal_mode = WAL;`) — the same write-ahead-log idea PostgreSQL and MySQL use by default for durability. The mechanism differs in the details across databases, but the guarantee is identical: a `COMMIT` that returned successfully is permanent, full stop.

## The full acronym, as one interview answer

| Letter | Guarantee | What breaks without it |
|---|---|---|
| **A**tomicity | All statements in a transaction succeed or none do | Partial updates left half-applied |
| **C**onsistency | Every commit leaves the database satisfying its constraints | Invalid data (broken `CHECK`/`FK`/`UNIQUE` rules) slips through |
| **I**solation | Concurrent transactions don't see each other's uncommitted work | Dirty reads, non-repeatable reads |
| **D**urability | A committed transaction survives a crash | Data loss right after a successful commit |

**One-liner:** "ACID is the set of guarantees a transaction gives you: it's all-or-nothing (Atomicity), it never leaves the data in a state that violates a constraint (Consistency), concurrent transactions can't see each other's half-finished work (Isolation), and once it commits, it's permanent even through a crash (Durability)."

## Key takeaways

- Atomicity and Isolation were covered hands-on in the main lesson — Consistency and Durability complete the acronym here.
- Consistency isn't a separate feature to configure — it's the natural result of the constraints you already declare with `CHECK`, `NOT NULL`, `UNIQUE`, and foreign keys.
- Durability is implemented via a write-ahead log in every major database, SQLite included (`PRAGMA journal_mode = WAL`).
