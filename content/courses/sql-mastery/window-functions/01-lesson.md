---
kind: lesson
id_key: sql-mastery/window-functions/lesson
course: sql-mastery
section: window-functions
section_title: "Window Functions"
section_position: 10
title: "Window Functions: OVER, PARTITION BY, RANK, and Running Totals"
position: 0
estimated_minutes: 30
source: [sql-mastery-curriculum.md]
---
Every aggregate function you've used so far — `COUNT`, `SUM`, `AVG` — collapses many rows into one, via `GROUP BY`. Window functions do something different: they compute an aggregate-like value **per row**, while still showing every row individually, by looking at a "window" of related rows around it. This is the tool for running totals, rankings, and "compare this row to the next/previous row" questions — genuinely common in reporting, dashboards, and interviews alike.

## OVER(): what makes a window function different from GROUP BY

```sql-try
SELECT title, price, genre_id,
  AVG(price) OVER (PARTITION BY genre_id) AS avg_genre_price
FROM books
ORDER BY genre_id, title;
```

Every book still appears as its own row — nothing gets collapsed — but `avg_genre_price` shows the average price of *that book's genre*, recomputed as a window rather than a single merged row. `GROUP BY` would have to drop `title` to compute this (since it isn't part of the grouping key); `OVER (PARTITION BY genre_id)` keeps every row intact while still giving each one access to a genre-wide aggregate. Any aggregate function you already know — `SUM`, `AVG`, `COUNT`, `MIN`, `MAX` — becomes a window function just by adding `OVER (...)` after it.

## ROW_NUMBER, RANK, and DENSE_RANK

These three assign a position to each row within an ordering, and differ only in how they handle ties:

```sql-try
SELECT title, price,
  ROW_NUMBER() OVER (ORDER BY price DESC) AS row_num,
  RANK() OVER (ORDER BY price DESC) AS rank_num,
  DENSE_RANK() OVER (ORDER BY price DESC) AS dense_rank_num
FROM books
ORDER BY price DESC;
```

Two books tie at $18.00 (*Kingdom of Ash Roses* and *Ash Roses: The Sequel*). `ROW_NUMBER()` still hands out distinct numbers to the tied rows (breaking the tie arbitrarily) — it never repeats a number. `RANK()` gives both tied rows the same rank, then **skips** the next number (if two books tie for rank 5, the next distinct book is rank 7, not 6). `DENSE_RANK()` also gives tied rows the same rank, but never skips — the next distinct book is rank 6. Interviewers ask about this distinction constantly; the mnemonic is "RANK leaves gaps, DENSE_RANK doesn't, ROW_NUMBER never ties."

## PARTITION BY: resetting the window per group

Add `PARTITION BY` to any of the above and the ranking (or running aggregate) restarts at the beginning of each partition, instead of running across the whole result:

```sql-try
SELECT title, genre_id, price,
  RANK() OVER (PARTITION BY genre_id ORDER BY price DESC) AS rank_in_genre
FROM books
ORDER BY genre_id, rank_in_genre;
```

Every genre now has its own rank 1 — the most expensive book *in that genre* — instead of one single ranking across all 15 books. This is the pattern behind "find the top N per category" questions: rank within a partition, then filter (typically inside a `WITH` CTE, since `WHERE`/`HAVING` can't reference a window function directly) for `rank_in_genre <= N`.

## Running totals with SUM() OVER

Ordering the window turns `SUM() OVER` into a running total — each row's sum includes every row before it (and itself) in the chosen order:

```sql-try
SELECT id, loan_date,
  SUM(1) OVER (ORDER BY loan_date, id) AS running_loan_count
FROM loans
ORDER BY loan_date, id;
```

Each row shows how many loans had happened *up to and including* that row, in date order — a running count. Swap `SUM(1)` for `SUM(b.price)` (joined against `books`) and the identical shape gives you cumulative revenue over time, one of the most common window-function interview questions there is.

## Naming the frame explicitly: ROWS BETWEEN

The running total above never named a frame — just `ORDER BY` — and SQLite defaulted that to "everything from the start up to this row," which is why it behaved like a running total. `ROWS BETWEEN` lets you say exactly which rows count, instead of accepting that default:

```sql-try
SELECT id, loan_date,
  SUM(1) OVER (
    ORDER BY loan_date, id
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  ) AS loans_last_3
FROM loans
ORDER BY loan_date, id;
```

`ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` is a sliding window of exactly three rows — the current one plus the two immediately before it in the chosen order — instead of every row since the beginning. Once a fourth row exists, the first row drops back out of the window. Swap `SUM(1)` for `AVG(b.price)` (joined against `books`) and this becomes a 3-loan moving average of sale price — the shape behind "moving average" interview questions, distinct from a running total in that old rows eventually age out.

## LAG and LEAD: looking at neighboring rows

`LAG(column, n)` reaches back `n` rows behind the current one (within the same ordering/partition); `LEAD(column, n)` reaches forward. Both default to `n = 1` and return `NULL` when there's no such neighboring row:

```sql-try
SELECT id, member_id, loan_date,
  LAG(loan_date) OVER (PARTITION BY member_id ORDER BY loan_date) AS previous_loan_date
FROM loans
ORDER BY member_id, loan_date;
```

For each member, `previous_loan_date` shows the date of *that same member's* previous loan — `NULL` for their first loan, since there's nothing before it. This is exactly the shape you'd reach for to compute "days between a member's consecutive loans," by subtracting `previous_loan_date` from `loan_date` with `julianday()`.

## Knowledge check

Answer all three questions correctly to unlock **Mark as Complete** for this lesson. Every attempt is recorded.

```knowledge-check
{
  "questions": [
    {
      "id": "window-functions-q1",
      "type": "mcq",
      "prompt": "Two books are tied for the highest price within a genre. What's the key difference between RANK() and DENSE_RANK() for the row immediately after the tie?",
      "options": [
        { "id": "a", "text": "RANK() skips a number after the tie; DENSE_RANK() does not skip any number" },
        { "id": "b", "text": "DENSE_RANK() skips a number after the tie; RANK() does not" },
        { "id": "c", "text": "Both skip a number after any tie" },
        { "id": "d", "text": "Neither ever skips a number, regardless of ties" }
      ],
      "correct": "a",
      "explanation": "RANK() leaves a gap equal to the number of tied rows (e.g. two rows tied for rank 5 means the next rank is 7). DENSE_RANK() never leaves gaps."
    },
    {
      "id": "window-functions-q2",
      "type": "mcq",
      "prompt": "What does PARTITION BY do inside a window function?",
      "options": [
        { "id": "a", "text": "Removes duplicate rows from the result" },
        { "id": "b", "text": "Restarts the window computation independently for each group, without collapsing rows the way GROUP BY does" },
        { "id": "c", "text": "Sorts the entire result set by the partition column" },
        { "id": "d", "text": "Filters out rows that don't match the partition value" }
      ],
      "correct": "b",
      "explanation": "PARTITION BY splits the window into independent groups — each partition gets its own running rank/aggregate — while every row still appears individually in the output, unlike GROUP BY."
    },
    {
      "id": "window-functions-q3",
      "type": "sql",
      "prompt": "Write a query that shows each book's title, genre_id, and price, along with its rank by price within its own genre_id (highest price = rank 1).",
      "starter": "SELECT",
      "solution": "SELECT title, genre_id, price, RANK() OVER (PARTITION BY genre_id ORDER BY price DESC) AS rank_in_genre FROM books;"
    }
  ]
}
```

## What's next

Window functions round out how you can look at data per-row while still seeing the bigger picture. Next: **Indexing & Query Performance** — how the database actually finds the rows you ask for, fast, and when an index helps versus when it just slows writes down.
