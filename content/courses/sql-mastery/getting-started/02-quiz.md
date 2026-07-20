---
kind: quiz
id_key: sql-mastery/getting-started/quiz
course: sql-mastery
section: getting-started
section_title: "Getting Started"
section_position: 1
title: "Quiz: SQL Basics"
position: 1
estimated_minutes: 10
source: [sql-mastery-curriculum.md]
pass_percentage: 70
duration_minutes: 10
questions:
  - id_key: what-is-sql
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "What does SQL stand for?"
    multiple: false
    options:
      - { text: "Structured Query Language", correct: true }
      - { text: "Sequential Query Logic", correct: false }
      - { text: "System Query List", correct: false }
      - { text: "Standard Query Layer", correct: false }
    explanation: "SQL stands for Structured Query Language — the standard language for interacting with relational databases."
  - id_key: select-star-tradeoff
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Why do real applications usually avoid `SELECT *` in favor of naming exact columns?"
    multiple: false
    options:
      - { text: "SELECT * is invalid SQL syntax", correct: false }
      - { text: "Naming columns explicitly is more explicit and doesn't silently change if the table's columns change later", correct: true }
      - { text: "SELECT * only works on tables with a primary key", correct: false }
      - { text: "SELECT * cannot be combined with WHERE", correct: false }
    explanation: "SELECT * is valid and fine for quick exploration, but naming columns explicitly keeps queries predictable as schemas evolve."
  - id_key: distinct-scope
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "Given `SELECT DISTINCT author_id, genre_id FROM books;`, which rows are collapsed together?"
    multiple: false
    options:
      - { text: "Rows where author_id matches, regardless of genre_id", correct: false }
      - { text: "Rows where genre_id matches, regardless of author_id", correct: false }
      - { text: "Rows where both author_id AND genre_id match", correct: true }
      - { text: "DISTINCT cannot be used with more than one column", correct: false }
    explanation: "DISTINCT applies to the combination of every selected column — two rows are only collapsed if they match on all of them."
  - id_key: limit-vs-top
    type: mcq
    difficulty: beginner
    points: 1
    prompt: "Which keyword limits the number of rows returned in SQLite, MySQL, and PostgreSQL?"
    multiple: false
    options:
      - { text: "TOP" }
      - { text: "LIMIT", correct: true }
      - { text: "FETCH FIRST" }
      - { text: "ROWNUM" }
    explanation: "LIMIT is used by SQLite, MySQL, and PostgreSQL. SQL Server uses TOP instead — same idea, different keyword."
  - id_key: null-return-date
    type: mcq
    difficulty: intermediate
    points: 2
    prompt: "In the loans table, what does a NULL return_date mean?"
    multiple: false
    options:
      - { text: "The loan record is corrupted", correct: false }
      - { text: "The book has never been borrowed", correct: false }
      - { text: "The book was borrowed and hasn't been returned yet", correct: true }
      - { text: "The book was returned on the same day it was borrowed", correct: false }
    explanation: "A NULL return_date represents an open loan — the book is still checked out."
---
