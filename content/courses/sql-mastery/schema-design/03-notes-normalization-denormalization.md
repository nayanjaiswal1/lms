---
kind: lesson
id_key: sql-mastery/schema-design/note-normalization-denormalization
course: sql-mastery
section: schema-design
section_title: "Database & Table Design"
section_position: 7
title: "Notes: Normal Forms, and Why You'd Break Them"
position: 2
estimated_minutes: 20
source:
    - interview-prep-notes.md
---

The main lesson in this section covered constraints, indexes, and views — the tools you use to design a schema. This note names the formal target those tools are usually aimed at: **normalization**, the process of structuring tables to reduce redundancy, and its deliberate opposite, **denormalization**.

## Why the library schema is already normalized

You've been querying a normalized schema all course without it being named as such: `books.author_id` and `books.genre_id` point at `authors` and `genres` instead of repeating an author's name and country on every one of their books. That's normalization's core idea — each fact lives in exactly one place.

```sql-try
SELECT b.title, a.name, a.country
FROM books b
JOIN authors a ON a.id = b.author_id
WHERE a.name = 'Amara Diallo';
```

If `books` instead stored `author_name` and `author_country` directly on every row, correcting a typo in an author's country would mean updating every one of their books individually — and it would be possible for two rows by the same author to disagree. Keeping author data in its own table, referenced by `author_id`, makes that impossible: fix it once, in one row of `authors`.

## The normal forms, applied to this schema

**1NF — atomic columns.** Every column holds one indivisible value. If `books` had a `genres` column storing `"Fiction, Fantasy"` as one comma-separated string, that would violate 1NF — which is exactly why genre is its own table with a foreign key, not a text list.

**2NF — no partial dependency on part of a composite key.** Only relevant for tables with a multi-column primary key. If `loans` had a composite key of `(book_id, member_id)` and stored `book_title` directly on the row, `book_title` would depend only on `book_id` — half the key — not the whole key. That's a 2NF violation; the fix is the same one already in place: `books.title` lives in `books`, and `loans` only holds the foreign key.

**3NF — no transitive dependency between non-key columns.** If `books` stored both `author_id` and `author_country`, then `author_country` would depend on `author_id`, not directly on `books.id` — a transitive dependency. The schema avoids this: `country` lives only in `authors`, reached through the `author_id` foreign key.

**BCNF and beyond (4NF, 5NF)** tighten edge cases around functional and join dependencies that rarely come up outside academic examples. Worth naming if an interviewer asks "how far did you normalize," but 3NF is where real-world schemas — including this one — typically stop.

| Form | Eliminates | Library schema example |
|---|---|---|
| 1NF | Non-atomic columns | Genre is its own table, not a comma list on `books` |
| 2NF | Partial key dependency | `books.title` isn't duplicated onto `loans` |
| 3NF | Transitive dependency | `authors.country` isn't duplicated onto `books` |

## Denormalization: breaking these rules on purpose

Normalization optimizes for **write safety** — update one row, the fact is corrected everywhere. Denormalization trades that away for **read speed**, by deliberately storing redundant or precomputed data so a query doesn't have to `JOIN` or aggregate to get an answer.

A concrete case in this schema: counting how many books each author has written currently means a `JOIN` plus `GROUP BY` every time:

```sql-try
SELECT a.name, COUNT(*) AS book_count
FROM authors a
JOIN books b ON b.author_id = a.id
GROUP BY a.id;
```

A denormalized design might add a `book_count` column directly onto `authors`, updated whenever a book is inserted or deleted, so reading it back is a single-table lookup with no `JOIN` or aggregation at all. That's the trade: every `INSERT INTO books` now also has to update `authors.book_count` (more write work, and a risk the two drift out of sync if you forget), in exchange for reads that no longer need to compute anything.

**When it's worth it:**
- Read-heavy workloads where the same aggregate is queried far more often than the underlying rows change (a dashboard showing author book counts to thousands of readers, updated by only a handful of writers)
- Reporting/analytics tables, where a nightly job can rebuild denormalized summary columns and staleness for a few hours is acceptable
- Avoiding an expensive `JOIN` across tables that have grown too large for it to stay cheap

**When it's not:** anywhere correctness matters more than read speed, or writes are frequent enough that keeping the redundant copy in sync becomes its own source of bugs — which is why you normalize by default and denormalize deliberately, only once a specific read pattern proves it's worth the trade.

## Key takeaways

- Normalization (1NF → 2NF → 3NF) is the formal name for what `author_id`/`genre_id` foreign keys already do in this schema: each fact stored once, referenced everywhere it's needed.
- BCNF/4NF/5NF exist but rarely matter outside interview trivia — most real schemas stop at 3NF.
- Denormalization is the deliberate reverse: duplicate or precompute data to skip `JOIN`s/aggregation on read, at the cost of extra write work and a risk of the copies drifting apart.
- Default to normalized; denormalize only a specific, measured hot path — not the whole schema.
