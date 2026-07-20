---
kind: quiz
id_key: sql-mastery/schema-design/quiz
course: sql-mastery
section: schema-design
section_title: "Database & Table Design"
section_position: 7
title: "Quiz: Database & Table Design"
position: 1
estimated_minutes: 10
source: [sql-mastery-curriculum.md]
pass_percentage: 70
duration_minutes: 10
questions:
  - id_key: integer-primary-key-autoincrement
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "In SQLite, what happens when you INSERT into a table without providing a value for a column declared exactly INTEGER PRIMARY KEY?"
    multiple: false
    options:
      - { text: "The insert fails, because a value must always be provided", correct: false }
      - { text: "SQLite stores NULL for that column", correct: false }
      - { text: "SQLite automatically assigns the next available integer, since that column is the table's row identifier", correct: true }
      - { text: "SQLite always reuses id 1", correct: false }
    explanation: "INTEGER PRIMARY KEY in SQLite is the table's actual rowid. Omitting it lets SQLite auto-assign the next integer — the same idea as MySQL's AUTO_INCREMENT or Postgres's SERIAL/IDENTITY, just spelled differently."
  - id_key: drop-vs-delete-table
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "What's the difference between DELETE FROM reviews; and DROP TABLE reviews;?"
    multiple: false
    options:
      - { text: "There is no difference — they do the same thing", correct: false }
      - { text: "DELETE removes all rows but keeps the table structure; DROP TABLE removes the table itself entirely", correct: true }
      - { text: "DROP TABLE only removes rows; DELETE removes the table structure", correct: false }
      - { text: "DELETE requires a WHERE clause but DROP TABLE does not", correct: false }
    explanation: "DELETE FROM empties a table's rows while the table (and its columns, constraints, and indexes) still exists. DROP TABLE removes the table definition entirely — querying it afterward errors with 'no such table.'"
  - id_key: check-constraint-rejection
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Given `rating INTEGER CHECK (rating BETWEEN 1 AND 5)`, what happens when you try to INSERT a review with rating = 9?"
    multiple: false
    options:
      - { text: "The row is inserted with rating silently capped at 5", correct: false }
      - { text: "The row is inserted with rating set to NULL", correct: false }
      - { text: "The INSERT fails — the CHECK constraint rejects the row", correct: true }
      - { text: "The row is inserted, and a warning is logged", correct: false }
    explanation: "CHECK constraints are enforced at the database level. A rating of 9 violates BETWEEN 1 AND 5, so SQLite refuses the INSERT outright rather than storing invalid data."
  - id_key: unique-constraint-email
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "members.email is declared TEXT NOT NULL UNIQUE. What happens if you try to insert a new member using an email address that already belongs to another member?"
    multiple: false
    options:
      - { text: "The new row overwrites the existing member's email", correct: false }
      - { text: "The INSERT fails with a UNIQUE constraint violation", correct: true }
      - { text: "Both rows are inserted, since NOT NULL only blocks empty values", correct: false }
      - { text: "SQLite appends a number to make the email unique automatically", correct: false }
    explanation: "UNIQUE means no two rows can share that column's value. Inserting a duplicate email fails outright — the database, not the application, enforces this rule."
  - id_key: index-purpose
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "What does `CREATE INDEX idx_books_genre ON books(genre_id);` primarily do?"
    multiple: false
    options:
      - { text: "It changes what SELECT * FROM books returns", correct: false }
      - { text: "It lets SQLite find rows matching a given genre_id without scanning the whole table, at the cost of extra work on writes", correct: true }
      - { text: "It enforces that genre_id must be unique", correct: false }
      - { text: "It automatically sorts the books table by genre_id on disk permanently", correct: false }
    explanation: "An index is a separate structure the database maintains so it can jump straight to matching rows instead of scanning every one — it speeds up lookups and joins on that column, but every write to the column now also has to update the index."
  - id_key: view-definition
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "What is a SQL view?"
    multiple: false
    options:
      - { text: "A saved SELECT query that you can query like a table, recomputed from its underlying tables each time", correct: true }
      - { text: "A physical copy of a table's data, refreshed on a schedule", correct: false }
      - { text: "A type of index used for full-text search", correct: false }
      - { text: "A backup snapshot of the entire database", correct: false }
    explanation: "A view doesn't store its own data — it wraps a SELECT (often a join) under a name, and running that name re-executes the underlying query against the current data every time."
---
