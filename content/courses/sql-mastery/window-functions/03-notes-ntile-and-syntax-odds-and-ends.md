---
kind: lesson
id_key: sql-mastery/window-functions/note-ntile-syntax
course: sql-mastery
section: window-functions
section_title: "Window Functions"
section_position: 10
title: "Notes: NTILE, Multi-Column Partitions, and Tie-Breaking"
position: 2
estimated_minutes: 10
source:
    - interview-prep-notes.md
---

The main lesson covered `ROW_NUMBER`/`RANK`/`DENSE_RANK`, `PARTITION BY`, running totals, and `LAG`/`LEAD`. A few syntax pieces from that same family didn't come up there.

## NTILE: splitting a partition into N equal buckets

`NTILE(n)` divides the (partitioned, ordered) rows into `n` roughly-equal groups and labels each row with its bucket number — the classic use is splitting data into quartiles/percentiles:

```sql-try
SELECT title, price,
  NTILE(4) OVER (ORDER BY price) AS price_quartile
FROM books
ORDER BY price;
```

With 15 books split into 4 buckets, the first ~4 (cheapest) books get bucket 1, the next ~4 get bucket 2, and so on — the last bucket absorbs any remainder. This is how "top 25% by revenue" or "which salary quartile is this employee in" questions get answered without hardcoding cutoff values.

## PARTITION BY with more than one column

`PARTITION BY` isn't limited to a single column — partitioning by `genre_id, author_id` together resets the window for every unique *combination* of the two, not just each genre:

```sql-try
SELECT title, genre_id, author_id, price,
  RANK() OVER (PARTITION BY genre_id, author_id ORDER BY price DESC) AS rank_in_group
FROM books;
```

## Tie-breaking with a second ORDER BY column

`ROW_NUMBER()` breaks ties arbitrarily unless you tell it what to fall back on. Adding a second column to `ORDER BY` inside `OVER (...)` makes the numbering deterministic instead of leaving equal-price rows in whatever order the engine happens to return them:

```sql-try
SELECT title, price,
  ROW_NUMBER() OVER (ORDER BY price DESC, title ASC) AS row_num
FROM books;
```

Now the two $18.00 books are always ordered alphabetically by title relative to each other, run after run — worth mentioning in an interview whenever the question involves ties and the interviewer asks "but which one comes first?"

## LAG/LEAD's third argument: a default instead of NULL

Both `LAG` and `LEAD` take an optional third argument — the value to return instead of `NULL` when there's no row to look at (e.g. the very first row has no "previous" row):

```sql-try
SELECT id, member_id, loan_date,
  LAG(loan_date, 1, 'none') OVER (PARTITION BY member_id ORDER BY loan_date) AS previous_loan_date
FROM loans;
```

A member's first loan now shows the literal string `'none'` instead of `NULL` in that column — useful when downstream code (or a report) can't cleanly handle `NULL` and needs a real placeholder value instead.

## Key takeaways

- `NTILE(n) OVER (ORDER BY ...)` buckets rows into `n` roughly-equal groups — the tool for quartiles/percentile splits.
- `PARTITION BY` accepts multiple columns — the window resets per unique combination, not per single column.
- A second `ORDER BY` column inside `OVER (...)` makes ranking/numbering deterministic when the first column has ties.
- `LAG(col, n, default)` / `LEAD(col, n, default)` — the third argument replaces the edge-row `NULL` with a value you choose.
