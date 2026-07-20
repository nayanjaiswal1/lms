---
kind: lesson
id_key: sql-mastery/joins/note-cross-join
course: sql-mastery
section: joins
section_title: "Joining Tables"
section_position: 4
title: "Notes: CROSS JOIN — the One Join Type the Main Lesson Skipped"
position: 2
estimated_minutes: 10
source:
    - interview-prep-notes.md
---

The main lesson covered `INNER`, `LEFT`, `RIGHT`, `FULL OUTER`, and self joins — every join that matches rows by a condition. `CROSS JOIN` is different: it has no matching condition at all.

## What CROSS JOIN returns

`CROSS JOIN` pairs **every row of the left table with every row of the right table** — the full Cartesian product, with no `ON` clause needed or allowed:

```sql-try
SELECT g.name AS genre, m.name AS member
FROM genres g
CROSS JOIN members m
LIMIT 10;
```

With 5 genres and 10 members, the full (unlimited) result would be 50 rows — every genre paired with every member, regardless of whether that member has ever borrowed a book in that genre. Compare that to an `INNER JOIN`, which only returns rows where a condition actually matches: `CROSS JOIN` returns rows where *nothing* has to match, because there's nothing to check.

## Why it's rarely what you want by accident

`CROSS JOIN` is the join you get from `FROM a, b` with no `WHERE` linking them — a classic bug, not a classic query. Forgetting a join condition doesn't error out; it silently multiplies your row count (rows in `a` × rows in `b`), which is why an unexpectedly huge result set is a common symptom of a missing `ON`/`WHERE` clause rather than a real `CROSS JOIN`.

## Where it's genuinely useful

`CROSS JOIN` earns its place when you deliberately want every combination — generating a full grid rather than matching existing relationships. A common real case: building a report template that should show every genre for every month, even genre/month pairs with zero loans, rather than only the combinations that happen to appear in the data:

```sql-try
SELECT g.name AS genre, m.city
FROM genres g
CROSS JOIN (SELECT DISTINCT city FROM members) m
ORDER BY g.name, m.city;
```

This produces one row per genre/city combination that exists in the data — a complete grid, ready to be left-joined against actual loan counts so combinations with zero activity still show up as `0` instead of being missing from the report entirely.

## Key takeaways

- `CROSS JOIN` has no `ON` clause — it returns the Cartesian product, every left row paired with every right row.
- Row count multiplies: N rows × M rows = N×M rows, which is why an accidental `CROSS JOIN` (a missing join condition) is a common source of exploded result sets.
- Deliberate use case: generating a complete combination grid (every category × every period) to left-join real data against, so empty combinations still appear instead of being silently absent.
