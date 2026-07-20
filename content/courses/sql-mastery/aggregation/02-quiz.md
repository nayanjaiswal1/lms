---
kind: quiz
id_key: sql-mastery/aggregation/quiz
course: sql-mastery
section: aggregation
section_title: "Aggregation"
section_position: 3
title: "Quiz: Aggregation"
position: 1
estimated_minutes: 10
source: [sql-mastery-curriculum.md]
pass_percentage: 70
duration_minutes: 10
questions:
  - id_key: count-star-trace
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "What does `SELECT COUNT(*) FROM books;` return, given the library has 15 books?"
    multiple: false
    options:
      - { text: "15 rows, each with the value 1" }
      - { text: "One row with the single value 15", correct: true }
      - { text: "The value 15 repeated for every column" }
      - { text: "An error, because COUNT requires a column name" }
    explanation: "COUNT(*) collapses the whole table into a single summary row containing the row count."
  - id_key: where-vs-having
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Why can't `WHERE COUNT(*) > 2` be used to keep only genres with more than 2 books, while `HAVING COUNT(*) > 2` works?"
    multiple: false
    options:
      - { text: "WHERE runs before grouping happens, so the aggregate COUNT(*) doesn't exist yet at that point — HAVING runs after grouping and can reference it", correct: true }
      - { text: "WHERE and HAVING are just two different names for the exact same clause", correct: false }
      - { text: "COUNT(*) can only ever be used in a SELECT list, never in a filter", correct: false }
      - { text: "WHERE only works on TEXT columns, not on aggregate results", correct: false }
    explanation: "WHERE filters individual rows before GROUP BY runs. HAVING filters the groups that GROUP BY produces, so it's the only clause that can test an aggregate's result."
  - id_key: group-by-having-trace
    type: mcq
    difficulty: advanced
    points: 3
    prompt: "Given `SELECT genre_id, COUNT(*) AS num_books FROM books GROUP BY genre_id HAVING COUNT(*) > 2;` — the library has 4 Fiction books, 2 Science Fiction, 3 Fantasy, 2 Mystery, 2 Non-Fiction, and 2 Biography — how many rows does this return?"
    multiple: false
    options:
      - { text: "6 — one for every genre" }
      - { text: "2 — Fiction (4 books) and Fantasy (3 books)", correct: true }
      - { text: "1 — only Fiction, the largest genre" }
      - { text: "0 — no genre has more than 2 books" }
    explanation: "Only Fiction (4) and Fantasy (3) have more than 2 books; the other four genres, each with exactly 2, are filtered out by HAVING."
  - id_key: min-max-trace
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Which book does `SELECT title FROM books ORDER BY price DESC LIMIT 1;` return, and how does that relate to MAX(price)?"
    multiple: false
    options:
      - { text: "Nobody's Almanac — it returns the cheapest book, same as MIN(price)", correct: false }
      - { text: "Watanabe: A Life — it returns the book at the highest price, the same value MAX(price) would compute", correct: true }
      - { text: "The Last Alchemist — a random book with no relation to price", correct: false }
      - { text: "It returns all 15 books sorted by price", correct: false }
    explanation: "Watanabe: A Life is priced at $22.50, the highest in the table — sorting descending and taking the top row is one way to find the same book MAX(price) would identify by value alone."
  - id_key: as-alias-purpose
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "Why use `AS` on an aggregate like `COUNT(*) AS total_books` instead of leaving it unnamed?"
    multiple: false
    options:
      - { text: "AS is required by SQLite syntax — an unnamed aggregate causes an error", correct: false }
      - { text: "Without it, the output column has an unreadable default name like COUNT(*) instead of a clear label", correct: true }
      - { text: "AS changes the aggregate's calculation, not just its label", correct: false }
      - { text: "AS is only valid on TEXT columns, not on numeric aggregate results", correct: false }
    explanation: "AS just renames the output column. It's optional, but without it you're stuck reading raw expressions like COUNT(*) or AVG(price) as column headers."
---
