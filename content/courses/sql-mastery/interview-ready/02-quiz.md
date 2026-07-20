---
kind: quiz
id_key: sql-mastery/interview-ready/quiz
course: sql-mastery
section: interview-ready
section_title: "SQL for Interviews"
section_position: 13
title: "Final Assessment: SQL Mastery"
position: 1
estimated_minutes: 20
source: [sql-mastery-curriculum.md]
pass_percentage: 70
duration_minutes: 25
questions:
  - id_key: nth-highest-offset-meaning
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "In `SELECT title, price FROM books ORDER BY price DESC LIMIT 1 OFFSET 1;`, what does `OFFSET 1` do?"
    multiple: false
    options:
      - { text: "Skips the first row of the ordered result before LIMIT starts counting", correct: true }
      - { text: "Limits the query to return only 1 column" }
      - { text: "Adds 1 to every price value in the result" }
      - { text: "Returns only rows where price = 1" }
    explanation: "ORDER BY price DESC puts the highest price first; OFFSET 1 then skips that single row before LIMIT 1 takes the next one — giving the 2nd-highest price ($21.00, Diallo Speaks), not the highest."
  - id_key: having-vs-where-aggregates
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Why must `HAVING COUNT(*) > 1` be used instead of `WHERE COUNT(*) > 1` when finding books that share the same price?"
    multiple: false
    options:
      - { text: "WHERE filters rows before GROUP BY runs and can't reference an aggregate like COUNT(*); HAVING filters after grouping", correct: true }
      - { text: "WHERE and HAVING are fully interchangeable in SQLite" }
      - { text: "COUNT(*) can only appear in a SELECT list, never in any filter" }
      - { text: "HAVING is only required when ORDER BY is also present" }
    explanation: "WHERE filters individual rows before grouping/aggregation happens, so aggregate results aren't available to it yet. HAVING runs after GROUP BY and can filter on the aggregated value."
  - id_key: anti-join-null-trap
    type: mcq
    difficulty: advanced
    points: 3
    prompt: "Both `WHERE id NOT IN (SELECT book_id FROM loans)` and `LEFT JOIN loans ON ... WHERE loans.id IS NULL` find books that were never loaned. Why do many engineers treat the LEFT JOIN version as the 'safer' pattern?"
    multiple: false
    options:
      - { text: "If the NOT IN subquery's column ever contains a NULL, the whole NOT IN comparison silently returns zero rows; LEFT JOIN/IS NULL has no such failure mode", correct: true }
      - { text: "LEFT JOIN is always faster than NOT IN, regardless of table size" }
      - { text: "NOT IN cannot be combined with a subquery, only with a literal list" }
      - { text: "LEFT JOIN works in more database engines than NOT IN does" }
    explanation: "If any row returned by the NOT IN subquery is NULL, every NOT IN comparison evaluates to UNKNOWN and the outer query returns nothing at all — a classic, easy-to-miss bug. The LEFT JOIN / IS NULL pattern doesn't have this trap."
  - id_key: above-average-borrowers-result
    type: mcq
    difficulty: advanced
    points: 3
    prompt: "`SELECT member_id, COUNT(*) FROM loans GROUP BY member_id HAVING COUNT(*) > (SELECT AVG(cnt) FROM (SELECT COUNT(*) AS cnt FROM loans GROUP BY member_id));` — against the seed data, who ends up in the result?"
    multiple: false
    options:
      - { text: "All 10 members, since everyone has borrowed at least once" }
      - { text: "Only member_id 3 (Chloe Martin), whose 3 loans exceed the 2.0 average loans-per-member", correct: true }
      - { text: "No members — COUNT(*) can't be compared against AVG() in a HAVING clause" }
      - { text: "The member with the fewest loans, since HAVING inverts the comparison" }
    explanation: "Every member's loan count is 1, 2, or 3, averaging to 2.0 across all 10 members. Only Chloe Martin has 3 loans, clearing that average — everyone else sits at or below it."
  - id_key: self-join-left-join-reason
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "In `SELECT m.name, r.name FROM members m LEFT JOIN members r ON m.referred_by = r.id;`, why is LEFT JOIN required instead of INNER JOIN?"
    multiple: false
    options:
      - { text: "A table cannot legally INNER JOIN to itself in SQLite" }
      - { text: "INNER JOIN would silently drop every member whose referred_by is NULL; LEFT JOIN keeps them with a NULL referrer name", correct: true }
      - { text: "LEFT JOIN is required any time two aliases of the same table are used" }
      - { text: "referred_by must have a UNIQUE constraint before INNER JOIN can be used" }
    explanation: "5 of the 10 members have no referrer (referred_by IS NULL). INNER JOIN only keeps rows with a match on both sides, so it would drop those 5 members entirely; LEFT JOIN preserves every member row."
  - id_key: coalesce-non-null-passthrough
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "For loan 5, return_date is '2024-01-24' (not NULL). What does `COALESCE(return_date, 'still out')` evaluate to for that row?"
    multiple: false
    options:
      - { text: "'still out'" }
      - { text: "NULL" }
      - { text: "'2024-01-24'", correct: true }
      - { text: "'2024-01-24, still out'" }
    explanation: "COALESCE returns the first non-NULL argument in its list. Since return_date already has a value, that value passes through unchanged — the fallback only applies when the first argument is NULL."
  - id_key: julianday-loan3-duration
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Loan 3 has loan_date '2023-11-20' and return_date '2023-12-01'. What does `julianday(return_date) - julianday(loan_date)` evaluate to?"
    multiple: false
    options:
      - { text: "9" }
      - { text: "10" }
      - { text: "11", correct: true }
      - { text: "14" }
    explanation: "November 20 to December 1 spans 11 days. This is one of only two closed loans shorter than the library's usual 14-day loan period (the other is loan 1, at 13 days)."
  - id_key: sqlite-fk-enforcement
    type: mcq
    difficulty: advanced
    points: 3
    prompt: "books.author_id is declared `INTEGER REFERENCES authors(id)`. By default in SQLite, is inserting a books row with an author_id that doesn't exist in authors actually rejected?"
    multiple: false
    options:
      - { text: "Yes — foreign keys are enforced by default in SQLite" }
      - { text: "No — SQLite parses the REFERENCES syntax but does not enforce it unless PRAGMA foreign_keys = ON is set for that connection", correct: true }
      - { text: "No — SQLite doesn't support foreign key syntax at all" }
      - { text: "Yes, but only for columns that are also INTEGER PRIMARY KEY" }
    explanation: "This is a well-known SQLite gotcha: REFERENCES is accepted and stored as metadata, but constraint enforcement is off by default and must be turned on per-connection with PRAGMA foreign_keys = ON."
  - id_key: inner-vs-left-join-row-counts
    type: mcq
    difficulty: advanced
    points: 3
    prompt: "How do the row counts compare between `books INNER JOIN loans ON loans.book_id = books.id` and the same query with LEFT JOIN, given the seed data?"
    multiple: false
    options:
      - { text: "Both return 20 rows — every book has been loaned at least once" }
      - { text: "INNER JOIN returns 20 rows (one per loan); LEFT JOIN returns 25 rows, adding one row per never-loaned book with loan columns as NULL", correct: true }
      - { text: "INNER JOIN returns 15 rows (one per book); LEFT JOIN returns 20" }
      - { text: "Both return exactly 15 rows, one per book" }
    explanation: "There are 20 loan rows total, so INNER JOIN produces 20 matched rows. 5 books (ids 3, 7, 12, 13, 14) were never loaned; LEFT JOIN still includes them, one row each with NULL loan columns, for 25 rows total."
  - id_key: and-or-precedence-bug
    type: mcq
    difficulty: advanced
    points: 3
    prompt: "Which WHERE clause has a bug caused by AND/OR operator precedence, incorrectly including every Fantasy book (genre_id = 3) regardless of price?"
    multiple: false
    options:
      - { text: "WHERE price < 15 AND genre_id = 1 OR genre_id = 3", correct: true }
      - { text: "WHERE price < 15 AND (genre_id = 1 OR genre_id = 3)" }
      - { text: "WHERE price < 15 AND genre_id IN (1, 3)" }
      - { text: "WHERE genre_id IN (1, 3) AND price < 15" }
    explanation: "AND binds more tightly than OR, so without parentheses `price < 15 AND genre_id = 1 OR genre_id = 3` parses as `(price < 15 AND genre_id = 1) OR genre_id = 3` — every Fantasy book is included no matter its price. Parenthesizing the OR, or using IN, avoids the bug."
---
