---
kind: lesson
id_key: sql-mastery/indexing-performance/lesson
course: sql-mastery
section: indexing-performance
section_title: "Indexing & Query Performance"
section_position: 11
title: "Indexing & Query Performance: CREATE INDEX and EXPLAIN QUERY PLAN"
position: 0
estimated_minutes: 30
source: [sql-mastery-curriculum.md]
---
You met `CREATE INDEX` briefly back in Database & Table Design. This lesson goes deeper: what an index actually is under the hood, when SQLite can and can't use one, how to check its query plan instead of guessing, and the tradeoff every index makes against write performance.

## What an index actually is

Without an index, finding rows that match a condition means SQLite reads every row in the table in order — a **full table scan** — checking each one against the condition. An index is a separate, sorted data structure (a B-tree, in SQLite) that maps column values to the rows that have them, so the database can jump straight to matching rows instead of checking all of them:

```sql-try
EXPLAIN QUERY PLAN
SELECT title FROM books WHERE genre_id = 3;
```

`EXPLAIN QUERY PLAN` doesn't run the query — it shows *how* SQLite intends to run it. Against a table with no index on `genre_id`, the plan shows `SCAN books` — a full scan of all 15 rows. That's invisible at 15 rows; it's the reason a database with millions of rows and no index can feel instantaneous on `SELECT * FROM t LIMIT 10` and grind to a halt on `WHERE some_unindexed_column = x`.

## Creating an index and watching the plan change

```sql-try
CREATE INDEX idx_books_genre ON books(genre_id);

EXPLAIN QUERY PLAN
SELECT title FROM books WHERE genre_id = 3;
```

Run this in the same query box as the `CREATE INDEX` (each `sql-try` box is a fresh database, so the index needs to exist before the `EXPLAIN` can see it), and the plan now reads `SEARCH books USING INDEX idx_books_genre (genre_id=?)` instead of `SCAN books` — SQLite is using the index to jump directly to genre 3's rows rather than checking all 15. The query returns the identical three titles either way; only the *path* to them changed.

## Sargable predicates: what lets SQLite actually use an index

An index only helps if the `WHERE` clause is written in a way SQLite can match against it directly — commonly called a **sargable** predicate (Search ARGument ABLE). Wrapping the indexed column in a function or expression usually defeats the index:

```sql-try
CREATE INDEX idx_books_price ON books(price);

EXPLAIN QUERY PLAN
SELECT title FROM books WHERE price * 1.1 > 20;
```

`price * 1.1 > 20` puts `price` inside an expression, so SQLite can't use `idx_books_price` to jump to the answer — it has to compute `price * 1.1` for every row first, meaning a full scan regardless of the index. Rewritten sargably — `WHERE price > 20 / 1.1` — the bare column is back on one side of the comparison and the index becomes usable again. The same trap applies to functions: `WHERE strftime('%Y', loan_date) = '2024'` can't use an index on `loan_date`, even though a plain `WHERE loan_date >= '2024-01-01' AND loan_date < '2025-01-01'` can.

## Composite indexes need their leading column

As covered briefly in Database & Table Design, a composite index `CREATE INDEX idx ON t(a, b)` is only usable starting from its leftmost column. Confirm it with the query plan:

```sql-try
CREATE INDEX idx_loans_member_date ON loans(member_id, loan_date);

EXPLAIN QUERY PLAN
SELECT * FROM loans WHERE loan_date > '2024-02-01';
```

Filtering on `loan_date` alone — the *second* column of the composite index — gets no benefit from `idx_loans_member_date` at all; the plan still shows a full scan. Filter on `member_id` instead (the leading column), and the index kicks in immediately.

## The write-cost tradeoff

Every index is a second structure the database must keep in sync — any `INSERT`, `UPDATE`, or `DELETE` that touches an indexed column has to update the index too, not just the table row itself. That means indexes speed up reads at the direct cost of slowing down writes, and take up extra disk space besides. The practical rule: index columns you filter, join, or sort on frequently, on tables large enough for a scan to actually hurt; don't index every column reflexively, and be especially cautious about adding indexes to tables with heavy write traffic — a logging table that's mostly `INSERT`s rarely benefits from many indexes at all.

## Knowledge check

Answer all three questions correctly to unlock **Mark as Complete** for this lesson. Every attempt is recorded.

```knowledge-check
{
  "questions": [
    {
      "id": "indexing-performance-q1",
      "type": "mcq",
      "prompt": "What does EXPLAIN QUERY PLAN show you?",
      "options": [
        { "id": "a", "text": "The actual result rows the query would return" },
        { "id": "b", "text": "How SQLite intends to execute the query — e.g. a full scan versus an index search — without running it for real results" },
        { "id": "c", "text": "How long the query took to run, in milliseconds" },
        { "id": "d", "text": "A list of every index that exists in the database" }
      ],
      "correct": "b",
      "explanation": "EXPLAIN QUERY PLAN reveals the execution strategy (SCAN vs SEARCH USING INDEX) rather than the query's actual data results."
    },
    {
      "id": "indexing-performance-q2",
      "type": "mcq",
      "prompt": "Given CREATE INDEX idx ON loans(member_id, loan_date), which WHERE clause can make use of this index?",
      "options": [
        { "id": "a", "text": "WHERE loan_date > '2024-01-01'" },
        { "id": "b", "text": "WHERE member_id = 3" },
        { "id": "c", "text": "WHERE return_date IS NULL" },
        { "id": "d", "text": "WHERE book_id = 5" }
      ],
      "correct": "b",
      "explanation": "A composite index is only usable starting from its leftmost column — member_id here. Filtering on loan_date alone, without member_id, can't take advantage of this index."
    },
    {
      "id": "indexing-performance-q3",
      "type": "sql",
      "prompt": "Write a query that creates an index on books(author_id), then selects every book title for author_id 3.",
      "starter": "CREATE INDEX",
      "solution": "CREATE INDEX idx_books_author ON books(author_id); SELECT title FROM books WHERE author_id = 3;"
    }
  ]
}
```

## What's next

You now know how the database finds your rows efficiently, and how to check its plan rather than guess. The next lesson, **Transactions & Concurrency**, covers what happens when multiple statements — or multiple users — touch the database at the same time.
