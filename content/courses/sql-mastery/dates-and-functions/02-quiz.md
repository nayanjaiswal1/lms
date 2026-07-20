---
kind: quiz
id_key: sql-mastery/dates-and-functions/quiz
course: sql-mastery
section: dates-and-functions
section_title: "Dates & Useful Functions"
section_position: 8
title: "Quiz: Dates & Useful Functions"
position: 1
estimated_minutes: 10
source: [sql-mastery-curriculum.md]
pass_percentage: 70
duration_minutes: 10
questions:
  - id_key: sqlite-date-storage
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "How does SQLite store a value like `loans.loan_date`?"
    multiple: false
    options:
      - { text: "As a native DATE type with its own binary format", correct: false }
      - { text: "As plain TEXT in YYYY-MM-DD format", correct: true }
      - { text: "As a UNIX timestamp integer", correct: false }
      - { text: "SQLite refuses to store dates without an extension", correct: false }
      - { text: "As a floating-point Julian day number by default", correct: false }
    explanation: "SQLite has no dedicated DATE/DATETIME column type — dates are stored as ordinary TEXT in ISO-8601 format, unlike PostgreSQL, MySQL, or SQL Server which have real date types."
  - id_key: iso-date-comparison
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Why does `WHERE loan_date BETWEEN '2024-01-01' AND '2024-01-31'` correctly filter to January 2024, even though loan_date is just TEXT?"
    multiple: false
    options:
      - { text: "SQLite silently converts the column to a DATE type at query time", correct: false }
      - { text: "YYYY-MM-DD is zero-padded and big-endian, so plain string comparison happens to sort chronologically", correct: true }
      - { text: "BETWEEN has special built-in awareness of calendar dates", correct: false }
      - { text: "It doesn't — the query only works by coincidence for this specific dataset", correct: false }
      - { text: "SQLite always compares numerically first", correct: false }
    explanation: "Because the year comes first and every field is zero-padded to a fixed width, ordinary lexicographic string comparison produces correct chronological ordering — this trick breaks if the format isn't zero-padded (e.g. '2024-1-3')."
  - id_key: julianday-subtraction
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "What does `julianday(return_date) - julianday(loan_date)` compute?"
    multiple: false
    options:
      - { text: "The number of days between loan_date and return_date", correct: true }
      - { text: "A boolean indicating whether the loan is overdue", correct: false }
      - { text: "The current date minus the loan date", correct: false }
      - { text: "It always returns NULL if return_date is a string", correct: false }
      - { text: "The year difference between the two dates", correct: false }
    explanation: "julianday() converts a date string to a Julian day number (a continuous count of days); subtracting two of them gives the elapsed day count between the dates — most loans in this library last exactly 14 days."
  - id_key: coalesce-open-loan
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "For a loan where return_date IS NULL, what does `COALESCE(return_date, 'still out')` return?"
    multiple: false
    options:
      - { text: "NULL" }
      - { text: "'still out'", correct: true }
      - { text: "An empty string" }
      - { text: "It raises an error because return_date is NULL" }
    explanation: "COALESCE returns the first non-NULL argument in its list — since return_date is NULL, it falls through to the literal 'still out'."
  - id_key: strftime-year-grouping
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Given `SELECT strftime('%Y', loan_date) AS loan_year, COUNT(*) FROM loans GROUP BY loan_year;` against the seed data, how many loans fall in 2023 vs 2024?"
    multiple: false
    options:
      - { text: "10 in 2023, 10 in 2024" }
      - { text: "3 in 2023, 17 in 2024", correct: true }
      - { text: "0 in 2023, 20 in 2024" }
      - { text: "All 20 loans are in 2024 since strftime only reads the current year" }
    explanation: "Only loans 1, 2, and 3 were opened in 2023 (loan_date starting with '2023-'); the remaining 17 loans all have a 2024 loan_date."
  - id_key: coalesce-sql-server-equivalent
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "SQL Server doesn't support IFNULL/COALESCE-style substitution the same way as SQLite's IFNULL — what's its equivalent single-purpose function?"
    multiple: false
    options:
      - { text: "NVL" }
      - { text: "ISNULL", correct: true }
      - { text: "NULLIF" }
      - { text: "SQL Server has no equivalent function" }
    explanation: "SQL Server uses ISNULL(expr, value) for the two-argument case. (COALESCE itself is standard SQL and also works in SQL Server for the general multi-argument case — ISNULL is its SQL-Server-specific, two-argument-only cousin, mirroring SQLite's IFNULL.)"
---
