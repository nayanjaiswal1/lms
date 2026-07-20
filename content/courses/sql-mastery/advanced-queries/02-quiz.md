---
kind: quiz
id_key: sql-mastery/advanced-queries/quiz
course: sql-mastery
section: advanced-queries
section_title: "Advanced Queries"
section_position: 6
title: "Quiz: Advanced Queries"
position: 1
estimated_minutes: 10
source: [sql-mastery-curriculum.md]
pass_percentage: 70
duration_minutes: 10
questions:
  - id_key: never-loaned-count
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "How many rows does `SELECT title FROM books WHERE id NOT IN (SELECT book_id FROM loans);` return against the library data?"
    multiple: false
    options:
      - { text: "3" }
      - { text: "4" }
      - { text: "5", correct: true }
      - { text: "10" }
    explanation: "10 distinct books appear in the loans table across its 20 rows. The library has 15 books total, so 5 have never been loaned: Kingdom of Ash Roses, The Last Alchemist, Watanabe: A Life, Diallo Speaks, and Ash Roses: The Sequel."
  - id_key: not-in-null-trap
    type: mcq
    difficulty: advanced
    points: 3
    prompt: "If the subquery inside a NOT IN clause returns even one NULL value, what happens to the outer query?"
    multiple: false
    options:
      - { text: "SQLite raises a syntax error", correct: false }
      - { text: "The NULL is ignored and NOT IN works normally", correct: false }
      - { text: "NOT IN silently stops matching anything, so the outer query returns zero rows", correct: true }
      - { text: "The NULL is treated as matching every row", correct: false }
    explanation: "Comparing against a NULL produces UNKNOWN rather than TRUE or FALSE, and NOT IN requires the value to be provably unequal to every item in the list. One NULL in the subquery poisons the whole comparison, silently zeroing out the results — this is exactly the failure mode NOT EXISTS avoids."
  - id_key: sqlite-any-all-support
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Does SQLite support writing `price > ALL (subquery)` the way PostgreSQL or SQL Server do?"
    multiple: false
    options:
      - { text: "Yes, with identical syntax", correct: false }
      - { text: "No — the same comparison has to be written using MAX()/MIN() subqueries instead", correct: true }
      - { text: "Yes, but only inside a CHECK constraint", correct: false }
      - { text: "No — SQLite has no way to express this comparison at all", correct: false }
    explanation: "SQLite doesn't implement the ANY/ALL comparison syntax. The same logic is fully expressible with MAX()/MIN() subqueries — price > ALL(subquery) becomes price > (SELECT MAX(...) FROM ...)."
  - id_key: exists-select-1
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "In `WHERE NOT EXISTS (SELECT 1 FROM loans l WHERE l.book_id = b.id)`, why is `1` selected instead of an actual column?"
    multiple: false
    options:
      - { text: "EXISTS only checks whether any row comes back, not what values it contains, so the selected value doesn't matter", correct: true }
      - { text: "SQLite requires a numeric literal inside every subquery", correct: false }
      - { text: "It limits the subquery to returning exactly 1 row", correct: false }
      - { text: "It's a typo — it should select book_id", correct: false }
    explanation: "EXISTS evaluates to true or false based purely on whether the subquery returns any rows at all. Selecting 1 (or * or any column) is a convention that signals 'we don't care about the value.'"
  - id_key: case-boundary-trace
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Using `CASE WHEN price < 10 THEN 'Budget' WHEN price <= 18 THEN 'Standard' ELSE 'Premium' END`, which tier does Kingdom of Ash Roses ($18.00) fall into?"
    multiple: false
    options:
      - { text: "Budget" }
      - { text: "Standard", correct: true }
      - { text: "Premium" }
      - { text: "NULL, because $18.00 matches no branch" }
    explanation: "WHEN branches are checked in order and the first match wins. $18.00 fails price < 10 but satisfies price <= 18, so it lands in 'Standard' — it never reaches the ELSE branch."
  - id_key: limit-caps-rows
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "What does adding `LIMIT 3` to a query do?"
    multiple: false
    options:
      - { text: "Restricts the query to only the first 3 columns" }
      - { text: "Caps the result set to at most 3 rows", correct: true }
      - { text: "Requires the query to run in under 3 seconds" }
      - { text: "Skips the first 3 rows of the result" }
    explanation: "LIMIT caps how many rows the query returns — combined with ORDER BY, it's how you get a top-N result like the 3 priciest books."
---
