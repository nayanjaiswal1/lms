---
kind: lesson
id_key: sql-mastery/joins/note-except-intersect
course: sql-mastery
section: joins
section_title: "Joining Tables"
section_position: 4
title: "Notes: EXCEPT and INTERSECT — the Set Operators UNION Left Out"
position: 3
estimated_minutes: 10
source:
    - interview-prep-notes.md
---

The main lesson covered `UNION` and `UNION ALL` for stacking result sets. Two more set operators follow the exact same rule (same column count, compatible types) but ask a different question than "combine everything."

## INTERSECT: rows in both queries

```sql-try
SELECT member_id FROM loans WHERE loan_date < '2024-06-01'
INTERSECT
SELECT member_id FROM loans WHERE loan_date >= '2024-06-01';
```

Returns only the member ids that appear in **both** halves — members who borrowed something before June 2024 *and* borrowed something after. Not a `JOIN`: there's no row-pairing, just two independent row sets reduced to their overlap.

## EXCEPT: rows in the first query but not the second

```sql-try
SELECT member_id FROM members
EXCEPT
SELECT member_id FROM loans;
```

Returns member ids from `members` that never show up in `loans` at all — members who have never borrowed a book. This is a set-operator alternative to the `NOT EXISTS`/anti-join pattern from the advanced-queries and interview-ready lessons; same answer, different mechanism. `EXCEPT` is order-sensitive: `A EXCEPT B` (rows in A missing from B) is not the same as `B EXCEPT A`.

(MySQL doesn't support `EXCEPT`/`INTERSECT` before 8.0.31 — `NOT EXISTS`/`EXISTS` is the portable version interviewers usually want anyway. SQLite and PostgreSQL support both directly, as used here.)

## Key takeaways

- `INTERSECT` = rows returned by both queries. `EXCEPT` = rows in the first query with no match in the second.
- Both dedupe automatically, like `UNION` (no `ALL` variant needed for the common case).
- `EXCEPT` for "never happened" questions is equivalent to `NOT EXISTS`/anti-join — know both, since `EXCEPT` support varies more across engines.
