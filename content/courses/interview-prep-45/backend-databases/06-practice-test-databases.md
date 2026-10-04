---
kind: quiz
id_key: interview-prep-45/test-backend-databases
course: interview-prep-45
section: backend-databases
section_title: "Databases (PostgreSQL)"
section_position: 9
section_group: "Backend"
title: "Practice Test: Databases"
position: 6
estimated_minutes: 20
pass_percentage: 70
duration_minutes: 20
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
    - checkpoints/01-quiz-week-1.md
    - checkpoints/04-quiz-week-4.md
questions:
  - id_key: interview-prep-45/quiz-week-1/q7
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "When would adding a B-tree index to a PostgreSQL column likely NOT help?"
    options:
      - text: "When the column has very low selectivity (few distinct values)"
        correct: true
      - text: "When the table has millions of rows"
      - text: "When queries filter on that column with equality"
      - text: "When queries sort by that column"
    explanation: "If a filter matches a large fraction of rows (low selectivity), the planner prefers a sequential scan -- the index adds write cost without read benefit."

  - id_key: interview-prep-45/quiz-week-4/q6
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A table is in third normal form (3NF) when..."
    options:
      - text: "Every non-key column depends on the key, the whole key, and nothing but the key"
        correct: true
      - text: "It has no more than three foreign keys"
      - text: "All columns are indexed"
      - text: "Every query touches at most three tables"
    explanation: "3NF removes transitive dependencies: non-key attributes may not depend on other non-key attributes. The mnemonic 'the key, the whole key, and nothing but the key' covers 1NF through 3NF."

  - id_key: interview-prep-45/quiz-week-4/q7
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "When would you deliberately denormalize a schema?"
    options:
      - text: "When read-heavy access patterns make join cost dominate and duplicated data can be kept consistent"
        correct: true
      - text: "Whenever a table exceeds one million rows"
      - text: "Never -- normalization is always superior"
      - text: "When you need more foreign keys"
    explanation: "Denormalization trades write complexity (keeping copies in sync) for read speed (no joins). It's a measured response to real read patterns, feed timelines, counters, reporting tables, not a row-count rule."

  - id_key: interview-prep-45/test-backend-databases/leftmost-prefix
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "A composite index exists on (customer_id, status). Which query can it actually speed up?"
    options:
      - text: "WHERE status = 'paid'"
      - text: "WHERE customer_id = 42"
        correct: true
      - text: "Neither query"
      - text: "Both equally"
    explanation: "The leftmost prefix rule: a composite index is sorted by its first column, so only a query filtering on customer_id (alone, or together with status) can use it."

  - id_key: interview-prep-45/test-backend-databases/where-vs-having
    type: mcq
    difficulty: beginner
    points: 10
    prompt: "Why does WHERE SUM(total) > 1000 fail with a syntax error?"
    options:
      - text: "WHERE runs before rows are grouped, so there is nothing yet to sum"
        correct: true
      - text: "SUM cannot be used anywhere in a SELECT statement"
      - text: "WHERE only works with text columns"
      - text: "This is actually valid SQL"
    explanation: "WHERE filters individual rows before GROUP BY runs. An aggregate like SUM only makes sense after grouping, which is why that check belongs in HAVING."

  - id_key: interview-prep-45/test-backend-databases/n-plus-one
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "500 customers are fetched, then one extra query runs per customer for their orders. What actually makes this slow?"
    options:
      - text: "The per-query execution time, which usually dominates"
      - text: "The network round trip repeated 500 times, which usually dwarfs each query's own execution time"
        correct: true
      - text: "Databases cannot run more than 100 queries per second"
      - text: "Nothing; this pattern performs the same as a single JOIN"
    explanation: "A single JOIN pays the network round-trip cost once. Paying it 500 times, even if each query is individually fast, adds up to far more wall-clock time."

  - id_key: interview-prep-45/test-backend-databases/dirty-read
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "Why does Postgres never produce a dirty read, at any isolation level?"
    options:
      - text: "MVCC keeps an uncommitted row version invisible to every transaction except the one that wrote it"
        correct: true
      - text: "Postgres locks the whole table on every write"
      - text: "Dirty reads are only possible in MySQL, not Postgres"
      - text: "READ UNCOMMITTED is disabled by default and cannot be enabled"
    explanation: "Every row keeps multiple versions under MVCC, each tagged with its writing transaction. A reader only ever sees versions committed before its own snapshot began, so an uncommitted write is never visible to anyone else."

  - id_key: interview-prep-45/test-backend-databases/migration-not-valid
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "Why add a NOT NULL constraint as NOT VALID first, then run VALIDATE CONSTRAINT separately, instead of adding it directly?"
    options:
      - text: "Adding it directly requires a full-table scan under a blocking lock; NOT VALID is instant and VALIDATE CONSTRAINT scans under a lock that doesn't block reads or writes"
        correct: true
      - text: "NOT VALID constraints are not actually enforced on new rows"
      - text: "This split only matters for foreign keys, never CHECK constraints"
      - text: "VALIDATE CONSTRAINT skips checking existing rows entirely"
    explanation: "Splitting the operation turns one long blocking lock into an instant step plus a scan under a much lighter lock, which is the standard way to add a required constraint to a huge, live table."

  - id_key: interview-prep-45/test-backend-databases/partial-index-now
    type: mcq
    difficulty: advanced
    points: 10
    prompt: "Why does Postgres reject a partial index with the condition WHERE expires_at > now()?"
    options:
      - text: "A partial index's condition is fixed at definition time, but now() returns a different value on every call, so it isn't immutable"
        correct: true
      - text: "Partial indexes cannot reference timestamp columns"
      - text: "expires_at must always be NOT NULL to be indexed"
      - text: "Postgres actually allows this without restriction"
    explanation: "A partial index needs a condition that's permanently true or false once built. now() changes on every evaluation, so Postgres can't rely on it staying correct -- only a condition on fixed columns works."

  - id_key: interview-prep-45/test-backend-databases/advisory-vs-trigger
    type: mcq
    difficulty: intermediate
    points: 10
    prompt: "Two concurrent requests each run a Python check for a cycle before saving a hierarchy update. Why can a cycle still get created?"
    options:
      - text: "Both requests can pass the check before either commits, so each sees no cycle, and together they create one that neither check caught alone"
        correct: true
      - text: "Python cannot detect cycles under any circumstances"
      - text: "This scenario is impossible in a single-threaded web server"
      - text: "Cycle detection only works with ltree columns"
    explanation: "An application-level check-then-write has a race window unless something serializes it. Only a database trigger, running inside the same transaction as the write, closes that window completely."
---
This test covers indexing and selectivity, query optimization and the N+1 pattern, ACID and isolation levels, safe migrations on a live table, and hierarchical data with concurrency-safe design. Pass 70% to complete the section.
