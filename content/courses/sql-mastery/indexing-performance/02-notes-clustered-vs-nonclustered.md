---
kind: lesson
id_key: sql-mastery/indexing-performance/note-clustered-vs-nonclustered
course: sql-mastery
section: indexing-performance
section_title: "Indexing & Query Performance"
section_position: 11
title: "Notes: Clustered vs Non-Clustered Indexes"
position: 1
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

The main lesson described an index as "a separate, sorted B-tree that maps column values to rows" — that's true of a **non-clustered** index. There's a second kind, and the distinction between the two is one of the most common database interview questions there is.

## Clustered index: the table data itself, in sorted order

A clustered index isn't a separate structure — the table's rows are physically stored on disk sorted by the index key. There's nothing to "look up and then jump to"; the data already is the sorted order. Think of a dictionary: the words themselves are printed in alphabetical order on the page, not listed separately in an index at the back.

Because rows can only be physically sorted one way at a time, **a table can have only one clustered index** — usually the primary key, by default, in engines that support this (SQL Server, MySQL/InnoDB).

## Non-clustered index: a separate lookup structure

A non-clustered index is the B-tree structure from the main lesson: a separate list of (indexed column value → pointer back to the row), while the table's own row order is untouched. Think of a textbook's index page: "Dragon — page 45, 112" is a separate list; the book's pages haven't been reordered around it. A table can have **many** non-clustered indexes, since each one is just an extra lookup structure sitting alongside the data.

## How a non-clustered lookup actually resolves (InnoDB)

In MySQL/InnoDB specifically, a non-clustered index (called a "secondary index" there) doesn't store a raw disk pointer — it stores the row's **primary key value**. So looking up a row by a secondary-indexed column is a two-step process:

1. Search the secondary index for the matching value → get back the primary key.
2. Use that primary key to look the row up in the clustered index (the actual table).

This is sometimes called a "bookmark lookup." The direct consequence: **every secondary index carries an internal copy of the primary key**, for every row. A large primary key (e.g. a 36-character UUID string) doesn't just bloat the primary key itself — it bloats every other index on the table too, since each one silently repeats it.

## Random primary keys cause fragmentation

Because a clustered index keeps rows in sorted key order, inserting a row means placing it in the *correct sorted position* — not just appending it. A sequential key (auto-increment integer, or a time-ordered UUIDv7) always inserts at the end, which is cheap. A random key (UUIDv4) inserts somewhere in the middle of existing sorted data almost every time.

When the data page that new row belongs to is full, the engine performs a **page split** — the full page divides into two so the row has somewhere to go. Repeated over many random inserts, this leaves pages half-empty and scattered instead of tightly packed and contiguous — **fragmentation**, which slows down both writes (more splits) and range scans (more pages to read for the same number of rows). This is the practical reason many teams prefer sequential IDs or UUIDv7 over UUIDv4 for primary keys on tables with heavy insert traffic.

## Engine caveat: this isn't universal

Not every engine implements "true" clustered indexes the way SQL Server and MySQL/InnoDB do:

- **PostgreSQL** has no maintained clustered index — its `CLUSTER` command physically reorders a table once, based on an index, but new inserts don't preserve that order afterward. Postgres tables are fundamentally heap-organized.
- **SQLite** (what this course runs on) stores ordinary tables in a B-tree keyed by an internal `rowid` — conceptually similar to a clustered index on that rowid — unless the table is declared `WITHOUT ROWID`, in which case the primary key itself becomes the clustering key.

Worth naming explicitly in an interview if the conversation is Postgres- or SQLite-specific — the clustered/non-clustered distinction is real, but "which engines actually maintain one automatically" varies.

## Key takeaways

- Clustered index = the table rows themselves, physically sorted by the key. Only one per table.
- Non-clustered index = a separate B-tree pointing back to the row. Many per table.
- InnoDB secondary indexes store the primary key internally, not a raw pointer — so a bloated primary key bloats every secondary index too.
- Random primary keys (UUIDv4) cause page splits and fragmentation because inserts land mid-sort, not at the end; sequential keys avoid this.
- Postgres and SQLite don't maintain a clustered index the same automatic way SQL Server/InnoDB do — check the engine before assuming.
