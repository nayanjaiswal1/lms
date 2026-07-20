---
kind: lesson
id_key: sql-mastery/joins/lesson
course: sql-mastery
section: joins
section_title: "Joining Tables"
section_position: 4
title: "Joining Tables: INNER, LEFT, RIGHT, FULL OUTER, and Self Joins"
position: 0
estimated_minutes: 30
source: [sql-mastery-curriculum.md]
---
Everything so far has queried one table at a time. But `books.author_id` only makes sense next to `authors.id`, and `loans.book_id` only makes sense next to `books.id` — the useful questions live *across* tables. A `JOIN` combines rows from two tables based on a matching condition, usually a foreign key.

## INNER JOIN: only the matches

`INNER JOIN` returns rows where the join condition matches in **both** tables — if a book's author doesn't match any row in `authors`, that book is left out entirely (though in this schema, every book has a valid author, so that never actually happens here).

```sql-try
SELECT b.title, a.name AS author, a.country
FROM books b
INNER JOIN authors a ON b.author_id = a.id
WHERE a.country = 'Japan';
```

Kenji Watanabe is the only author from Japan, and he wrote two books — *Neon Tide* and *Signals From Rhea* — so that's what comes back. Notice the table aliases (`b`, `a`): once a query touches more than one table, aliasing keeps `title` and `name` from being ambiguous about which table they came from.

## LEFT JOIN: keep everything on the left, even without a match

`LEFT JOIN` keeps **every** row from the left (first) table, whether or not it finds a match on the right. Unmatched rows get `NULL` in every column that came from the right table. That makes `LEFT JOIN` the tool for "find things that have no related row" — pair it with `WHERE ... IS NULL`:

```sql-try
SELECT b.title, l.id AS loan_id
FROM books b
LEFT JOIN loans l ON b.id = l.book_id
WHERE l.id IS NULL;
```

Five books have never been loaned out: *Kingdom of Ash Roses*, *The Last Alchemist*, *Watanabe: A Life*, *Diallo Speaks*, and *Ash Roses: The Sequel* — each shows up with `loan_id` as `NULL`, because `LEFT JOIN` kept the book row even though no loan matched it. An `INNER JOIN` here would have silently dropped all five.

## RIGHT JOIN: the mirror image

`RIGHT JOIN` is `LEFT JOIN` flipped — it keeps every row from the right (second) table instead. You can always rewrite a `RIGHT JOIN` as a `LEFT JOIN` by swapping which table you list first:

```sql-try
SELECT b.title, l.id AS loan_id
FROM loans l
RIGHT JOIN books b ON l.book_id = b.id
WHERE l.id IS NULL;
```

Same five books, same result as the `LEFT JOIN` above — just written the other way around, with `books` now on the right instead of the left. Because `RIGHT JOIN` is just `LEFT JOIN` with the tables reversed, most developers standardize on writing everything as `LEFT JOIN` and never use `RIGHT JOIN` at all — it's worth recognizing, but rarely necessary.

## FULL OUTER JOIN: keep everything, on both sides

`FULL OUTER JOIN` keeps every row from **both** tables — matched rows are combined normally, and anything unmatched on either side still shows up, with `NULL` filling in for the missing side:

```sql-try
SELECT b.title, l.id AS loan_id, l.loan_date
FROM books b
FULL OUTER JOIN loans l ON b.id = l.book_id
WHERE b.id IN (1, 7, 14)
ORDER BY b.id, l.id;
```

*The Silent Harbor* (book 1) has been loaned three separate times, so it produces three rows. *The Last Alchemist* (book 7) and *Ash Roses: The Sequel* (book 14) have never been loaned, so `FULL OUTER JOIN` still includes them — with `loan_id` and `loan_date` as `NULL` — exactly like `LEFT JOIN` would. In this particular dataset every loan does reference a real book, so you'll never see a row with a `NULL` book side here; but if a loan ever pointed at a book that no longer existed, `FULL OUTER JOIN` is the only join type that would surface it, since `LEFT JOIN books ... loans` would still drop it.

Worth knowing for interviews: MySQL has never supported `FULL OUTER JOIN` directly. The standard workaround is a `LEFT JOIN` combined with a `RIGHT JOIN` (or a second `LEFT JOIN` with tables swapped) via `UNION`, which de-duplicates the rows both queries have in common. SQLite (3.39+) and PostgreSQL support `FULL OUTER JOIN` natively, so you can write it directly like the query above.

## Self join: a table joined to itself

Nothing stops a table from joining to *itself* — you just need two aliases to tell the two "copies" apart. `members.referred_by` points back to another row in `members`, so finding "who referred whom" means joining `members` to `members`:

```sql-try
SELECT m.name AS member, r.name AS referred_by
FROM members m
LEFT JOIN members r ON m.referred_by = r.id
ORDER BY m.id;
```

`LEFT JOIN` (rather than `INNER JOIN`) matters here — Ana Torres, Chloe Martin, Elin Karlsson, Grace Kim, and Jonas Weber all joined with no referrer, so `referred_by` is `NULL` for them. The rest resolve to a real name: Ben Okafor and Dev Patel were both referred by Ana Torres, Farid Haidari by Chloe Martin, Hiro Tanaka by Grace Kim, and Ines Costa by Ana Torres.

## UNION and UNION ALL: stacking result sets

A `JOIN` combines tables side by side (more columns). `UNION` stacks two `SELECT`s on top of each other (more rows) — both queries need the same number of columns, in compatible types. `UNION` removes duplicate rows that appear in both results; `UNION ALL` keeps every row, duplicates included, and is faster because it skips the de-duplication work.

```sql-try
SELECT title FROM books WHERE author_id = 3
UNION
SELECT title FROM books WHERE genre_id = 3;
```

Amara Diallo (author 3) happens to have written exactly the three Fantasy (genre 3) books in this library, so both halves of the `UNION` return the identical three titles. `UNION` collapses the overlap and gives you exactly 3 rows.

Swap in `UNION ALL` and nothing about the data changes — only how the results are combined:

```sql-try
SELECT title FROM books WHERE author_id = 3
UNION ALL
SELECT title FROM books WHERE genre_id = 3;
```

This time you get 6 rows — the same three titles, each appearing twice, once from each `SELECT`. `UNION ALL` never checks for duplicates, so overlapping rows show up as many times as they were produced.

## Joining three or more tables

Nothing limits a query to two tables — chain additional `JOIN` clauses to pull in as many related tables as the question needs. To show every loan with the borrower's name, the book's title, and the book's genre name in one row, you need `loans` joined to `members`, and `books` joined to `genres`, all in a single query:

```sql-try
SELECT m.name AS member, b.title, g.name AS genre, l.loan_date
FROM loans l
JOIN books b ON b.id = l.book_id
JOIN genres g ON g.id = b.genre_id
JOIN members m ON m.id = l.member_id
ORDER BY l.id
LIMIT 5;
```

Each `JOIN` adds one more related table's columns to the row: `books` for the title, `genres` for a readable genre name (instead of a bare `genre_id`), and `members` for who borrowed it. SQLite resolves the joins left to right, but the order you list them in doesn't change the result — only readability. The one rule that doesn't change as you add tables: every join still needs its own `ON` condition, matching a foreign key to the primary key it points at.

## Join conditions with more than one predicate

An `ON` clause isn't limited to a single equality — you can `AND` together multiple conditions, useful when a match should depend on more than one column lining up:

```sql-try
SELECT b.title, l.loan_date
FROM books b
JOIN loans l ON l.book_id = b.id AND l.return_date IS NULL
WHERE b.genre_id = 1;
```

This joins a book only to loan rows that are **both** for that book **and** still open — equivalent to joining normally and then filtering with `WHERE l.return_date IS NULL` afterward. With a plain `INNER JOIN` the two approaches give the same result either way; the distinction starts to matter once you switch to a `LEFT JOIN`, where folding the condition into `ON` (rather than `WHERE`) changes whether unmatched books get dropped or kept with `NULL` loan columns.

## Knowledge check

Answer all three questions correctly to unlock **Mark as Complete** for this lesson. Every attempt is recorded.

```knowledge-check
{
  "questions": [
    {
      "id": "joins-q1",
      "type": "mcq",
      "prompt": "Which join type keeps every row from the left (first) table even when there's no match in the right table?",
      "options": [
        { "id": "a", "text": "INNER JOIN" },
        { "id": "b", "text": "LEFT JOIN" },
        { "id": "c", "text": "A join with no ON clause" },
        { "id": "d", "text": "UNION ALL" }
      ],
      "correct": "b",
      "explanation": "LEFT JOIN keeps every row from the left table, filling unmatched right-side columns with NULL. INNER JOIN would drop unmatched rows entirely."
    },
    {
      "id": "joins-q2",
      "type": "mcq",
      "prompt": "What must a self-join use to tell the two 'copies' of the same table apart?",
      "options": [
        { "id": "a", "text": "Two different table aliases" },
        { "id": "b", "text": "A UNION between two separate queries" },
        { "id": "c", "text": "A CHECK constraint on the table" },
        { "id": "d", "text": "Self-joins are not possible in SQLite" }
      ],
      "correct": "a",
      "explanation": "Joining a table to itself requires two aliases (e.g. m and r for members) so columns from each 'side' can be referenced unambiguously."
    },
    {
      "id": "joins-q3",
      "type": "sql",
      "prompt": "Write a query listing each book's title alongside its author's name and genre name, joining all three tables (books, authors, genres).",
      "starter": "SELECT",
      "solution": "SELECT b.title, a.name AS author, g.name AS genre FROM books b JOIN authors a ON a.id = b.author_id JOIN genres g ON g.id = b.genre_id;"
    }
  ]
}
```

## What's next

You can now pull related data together across every table in the schema, and stack result sets on top of each other. From here, the rest of the course builds on these fundamentals — modifying data, subqueries, schema design, and the classic interview query patterns that combine everything you've learned so far.
