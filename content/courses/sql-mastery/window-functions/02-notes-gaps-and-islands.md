---
kind: lesson
id_key: sql-mastery/window-functions/note-gaps-and-islands
course: sql-mastery
section: window-functions
section_title: "Window Functions"
section_position: 10
title: "Notes: Gaps and Islands — Streaks and Missing IDs"
position: 1
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

The main lesson's `LAG`/`LEAD` example finds the date of a member's *previous* loan. Two closely related interview shapes build on that same idea: finding a **run of consecutive rows** (an "island"), and finding a **missing value in a sequence** (a "gap").

## Finding a streak (the island half)

"Which members borrowed a book on 3+ consecutive days?" The trick: subtract a `ROW_NUMBER()` from the actual date. Within a real streak, the date advances by 1 each row while the row number also advances by 1 — so `date - row_number` stays **constant** for every row in that streak, and changes the moment the streak breaks:

```sql-try
WITH numbered AS (
  SELECT member_id, loan_date,
    ROW_NUMBER() OVER (PARTITION BY member_id ORDER BY loan_date) AS rn,
    date(loan_date, '-' || ROW_NUMBER() OVER (PARTITION BY member_id ORDER BY loan_date) || ' days') AS grp
  FROM (SELECT DISTINCT member_id, loan_date FROM loans)
)
SELECT member_id, MIN(loan_date) AS streak_start, COUNT(*) AS streak_len
FROM numbered
GROUP BY member_id, grp
HAVING COUNT(*) >= 3;
```

`grp` is identical for every row inside one unbroken run of days, so grouping by it collapses each streak into a single row. `HAVING COUNT(*) >= 3` keeps only streaks of 3+ days. This is the general "gaps and islands" technique — it works for any "N consecutive units" question (days, order numbers, log-in dates), not just this one.

## Finding a gap (the other half)

"Which book ids are missing from the sequence?" — i.e. ids that should exist between the min and max but don't:

```sql-try
SELECT id + 1 AS gap_starts_after
FROM books b
WHERE NOT EXISTS (SELECT 1 FROM books WHERE id = b.id + 1)
AND id < (SELECT MAX(id) FROM books);
```

For each row, check whether `id + 1` exists anywhere in the table; if it doesn't (and this isn't the last row), there's a gap right after it. This is the same anti-join shape from the interview-ready lesson, just applied to a self-comparison instead of a second table.

## Key takeaways

- **Islands** (consecutive runs): `ROW_NUMBER() - the ordered value` (a date, or an integer) is constant within one run — group by that difference to collapse each run into one row.
- **Gaps** (missing values): for each row, check whether `value + 1` exists in the same table — `NOT EXISTS` flags where the sequence breaks.
- Both are "known shape, not known trick" interview questions — recognizing which one applies matters more than memorizing the exact SQL.
