---
kind: quiz
id_key: sql-mastery/modifying-data/quiz
course: sql-mastery
section: modifying-data
section_title: "Modifying Data"
section_position: 5
title: "Quiz: Modifying Data"
position: 1
estimated_minutes: 10
source: [sql-mastery-curriculum.md]
pass_percentage: 70
duration_minutes: 10
questions:
  - id_key: insert-full-row-requirement
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "What must be true for `INSERT INTO genres VALUES (101, 'Poetry');` (no column list) to work?"
    multiple: false
    options:
      - { text: "Nothing extra — INSERT always works without a column list", correct: false }
      - { text: "The values must be supplied for every column, in the exact order the table was created with", correct: true }
      - { text: "The table must have exactly one column", correct: false }
      - { text: "You must run CREATE TABLE again first", correct: false }
    explanation: "The full-row form skips naming columns, but that only works if you provide a value for every column in the table's declared order — otherwise SQLite either errors or misassigns values."
  - id_key: update-missing-where
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "What happens if you run `UPDATE books SET stock = 0;` with no WHERE clause?"
    multiple: false
    options:
      - { text: "SQLite rejects the statement because WHERE is required", correct: false }
      - { text: "Only the first row is updated", correct: false }
      - { text: "Every row in the books table gets stock set to 0", correct: true }
      - { text: "Nothing happens until you add a WHERE clause afterward", correct: false }
    explanation: "UPDATE without WHERE applies to every row in the table — one of the most common and costly mistakes in SQL. Always double-check your WHERE clause before running an UPDATE."
  - id_key: update-stock-trace
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Starting from the original seed data, what is book id 9's stock after running `UPDATE books SET stock = stock + 5 WHERE id = 9;`?"
    multiple: false
    options:
      - { text: "0" }
      - { text: "5", correct: true }
      - { text: "9" }
      - { text: "NULL" }
    explanation: "Book id 9 (Cold Case: Reykjavik) starts at stock = 0 in the seed data. stock + 5 evaluates against the current value, so the new stock is 5."
  - id_key: delete-missing-where
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "What does `DELETE FROM loans;` (no WHERE clause) do?"
    multiple: false
    options:
      - { text: "Deletes only loans with a NULL return_date", correct: false }
      - { text: "Deletes every row in the loans table", correct: true }
      - { text: "Deletes the loans table itself, including its structure", correct: false }
      - { text: "Fails with a syntax error", correct: false }
    explanation: "DELETE without WHERE removes every row in the table — but unlike DROP TABLE, the table itself and its structure still exist afterward, just empty."
  - id_key: insert-select-purpose
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "What does `INSERT INTO ... SELECT ...` let you do that a plain `INSERT INTO ... VALUES ...` can't?"
    multiple: false
    options:
      - { text: "Insert rows whose values are computed from an existing query, row by row, instead of being typed as literals", correct: true }
      - { text: "Insert into more than one table at once", correct: false }
      - { text: "Skip the CHECK constraints on the target table", correct: false }
      - { text: "Insert rows without specifying a table name", correct: false }
    explanation: "INSERT INTO ... SELECT takes each row produced by the SELECT and inserts it — letting you copy, filter, and transform existing data into new rows in a single statement."
  - id_key: insert-select-reprint-trace
    type: mcq
    difficulty: advanced
    points: 3
    prompt: "How many rows does this insert against the original seed data?\n\n```sql\nINSERT INTO books (id, title, author_id, genre_id, price, published_year, stock)\nSELECT id + 200, title || ' (Reprint)', author_id, genre_id, price, published_year, 10\nFROM books\nWHERE stock = 0;\n```"
    multiple: false
    options:
      - { text: "0" }
      - { text: "1" }
      - { text: "3", correct: true }
      - { text: "15" }
    explanation: "Three books in the seed data have stock = 0 (Kingdom of Ash Roses, Cold Case: Reykjavik, and Ash Roses: The Sequel), so the SELECT produces three rows and three new books get inserted."
---
