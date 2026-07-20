---
kind: quiz
id_key: sql-mastery/filtering/quiz
course: sql-mastery
section: filtering
section_title: "Filtering & Sorting"
section_position: 2
title: "Quiz: Filtering & Sorting"
position: 1
estimated_minutes: 10
source: [sql-mastery-curriculum.md]
pass_percentage: 70
duration_minutes: 10
questions:
  - id_key: where-purpose
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "What does a WHERE clause do?"
    multiple: false
    options:
      - { text: "Sorts the result set", correct: false }
      - { text: "Keeps only the rows where the condition evaluates to true", correct: true }
      - { text: "Removes duplicate rows", correct: false }
      - { text: "Renames a column in the output", correct: false }
    explanation: "WHERE filters rows before they're returned — only rows matching the condition make it into the result."
  - id_key: and-vs-or-trace
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Given `SELECT title FROM books WHERE genre_id = 3 AND stock > 0;`, how many rows does this return? (Genre 3 has three books: Kingdom of Ash Roses with stock 0, The Last Alchemist with stock 1, and Ash Roses: The Sequel with stock 0.)"
    multiple: false
    options:
      - { text: "0" }
      - { text: "1", correct: true }
      - { text: "2" }
      - { text: "3" }
    explanation: "AND requires both conditions to hold. Only The Last Alchemist is genre 3 AND has stock greater than 0 — the other two Fantasy titles are out of stock."
  - id_key: null-equals-gotcha
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Why does `WHERE referred_by = NULL` always return zero rows, even though several members have a NULL referred_by?"
    multiple: false
    options:
      - { text: "NULL comparisons always evaluate to unknown, not true, so WHERE never keeps the row — you need IS NULL instead", correct: true }
      - { text: "referred_by is never actually NULL in the members table", correct: false }
      - { text: "= NULL is invalid SQL syntax and the query fails to run", correct: false }
      - { text: "NULL only works with the IN operator", correct: false }
      - { text: "SQLite treats NULL as the number 0, which never matches an explicit NULL", correct: false }
    explanation: "NULL represents an unknown value, so any = comparison involving it is also unknown — never true. IS NULL / IS NOT NULL are the only correct way to test for it."
  - id_key: like-underscore-trace
    type: mcq
    difficulty: advanced
    points: 3
    prompt: "Given `SELECT name, city FROM members WHERE city LIKE 'P_r%';`, which members are returned? (Cities in the data: Lisbon, Lagos, Paris, Mumbai, Stockholm, Kabul, Seoul, Osaka, Porto, Berlin.)"
    multiple: false
    options:
      - { text: "Only the member from Paris", correct: false }
      - { text: "Only the member from Porto", correct: false }
      - { text: "The members from Paris and Porto", correct: true }
      - { text: "No members — the pattern doesn't match any city", correct: false }
    explanation: "'P_r%' means P, then exactly one character, then r, then anything. Both Paris (P-a-r-is) and Porto (P-o-r-to) fit — the underscore doesn't care what that middle letter is."
  - id_key: between-inclusive
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "Is BETWEEN inclusive or exclusive of its two boundary values?"
    multiple: false
    options:
      - { text: "Inclusive — both boundary values are included in the match", correct: true }
      - { text: "Exclusive — only values strictly between the boundaries match", correct: false }
      - { text: "Inclusive of the lower bound only", correct: false }
      - { text: "Inclusive of the upper bound only", correct: false }
    explanation: "BETWEEN 2018 AND 2020 matches 2018, 2019, and 2020 — both endpoints are included."
  - id_key: order-by-multicolumn
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "In `ORDER BY genre_id ASC, price DESC`, what determines the final row order?"
    multiple: false
    options:
      - { text: "Only price DESC matters — genre_id is ignored", correct: false }
      - { text: "Rows are sorted by genre_id ascending first; within each matching genre_id, price DESC breaks the tie", correct: true }
      - { text: "The two columns are averaged together to produce a single sort key", correct: false }
      - { text: "SQLite raises an error — ORDER BY only accepts one column", correct: false }
    explanation: "Multi-column ORDER BY sorts by the first column, then uses the next column(s) to break ties among rows that share the same value in the first."
---
