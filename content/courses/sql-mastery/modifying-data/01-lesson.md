---
kind: lesson
id_key: sql-mastery/modifying-data/lesson
course: sql-mastery
section: modifying-data
section_title: "Modifying Data"
section_position: 5
title: "INSERT, UPDATE, DELETE — Changing the Data"
position: 0
estimated_minutes: 30
source: [sql-mastery-curriculum.md]
---
Every lesson so far has only *read* data with `SELECT`. Real applications also need to write it — adding new rows, correcting existing ones, and removing rows that shouldn't be there anymore. That's `INSERT`, `UPDATE`, and `DELETE`, together known as **DML** (Data Manipulation Language).

These statements change the actual data, so every example below pairs the mutation with a `SELECT` right after it, so you can see the effect immediately. Remember: this is a sandboxed copy of the library database, and the **Reset** button on any query box restores the original seed data — so experiment freely.

## INSERT: adding rows

The safest and clearest form names the columns you're providing, in any order you like:

```sql-try
INSERT INTO books (id, title, author_id, genre_id, price, published_year, stock)
VALUES (101, 'The Glass Orchard', 1, 1, 14.50, 2024, 3);

SELECT * FROM books WHERE id = 101;
```

`author_id` 1 is Isabel March and `genre_id` 1 is Fiction, both of which already exist in their tables — a new book row just points at them by id. The `SELECT` confirms the row landed exactly as written.

There's also a full-row form that skips the column list entirely — but it only works if you supply a value for *every* column, in the exact order the table was created with:

```sql-try
INSERT INTO genres VALUES (101, 'Poetry');

SELECT * FROM genres;
```

`genres` has exactly two columns (`id`, `name`), so `VALUES (101, 'Poetry')` lines up perfectly. The moment a table has more columns, or you want to skip one and let it default, the full-row form becomes fragile — one column added to the table later and every unqualified `INSERT` in your codebase breaks. That's why the explicit column list from the first example is the form you should reach for by default.

## UPDATE: changing existing rows

`UPDATE` rewrites values in rows that already exist. It's almost always paired with `WHERE` to target specific rows:

```sql-try
UPDATE books
SET stock = stock + 5
WHERE id = 9;

SELECT id, title, stock FROM books WHERE id = 9;
```

*Cold Case: Reykjavik* started at 0 in stock; the `SELECT` now shows 5. `SET stock = stock + 5` reads the current value and adds to it — the right-hand side can reference the row's own columns.

**Now the important part: what if you leave out `WHERE`?** `UPDATE` doesn't ask for confirmation — without a `WHERE` clause, it applies to *every single row* in the table. This is one of the most common, and most costly, mistakes in SQL. See it for yourself:

```sql-try
UPDATE books SET stock = 0;

SELECT id, title, stock FROM books;
```

Every book's stock is now 0, not just one. In production, this is the kind of statement that takes a system down — always write your `WHERE` clause *before* you write your `SET` values, and double-check it against a `SELECT` first if you're unsure which rows it'll match. Hit **Reset** now to restore the seed data before continuing.

## DELETE: removing rows

`DELETE` follows the same shape, and the same rule:

```sql-try
DELETE FROM loans WHERE id = 4;

SELECT * FROM loans WHERE id = 4;
```

Loan 4 (Chloe's still-open loan on *Signals From Rhea*) is gone — the second query returns no rows at all.

Omit `WHERE` here and the result is just as drastic — every row disappears, not one:

```sql-try
DELETE FROM loans;

SELECT COUNT(*) AS remaining_loans FROM loans;
```

`remaining_loans` comes back as `0` — the entire `loans` table is now empty. `DELETE` without `WHERE` is the row-removal twin of `UPDATE` without `WHERE`: syntactically valid, and almost never what you meant to type. Hit **Reset** again before moving on.

## INSERT INTO ... SELECT: inserting computed rows

You're not limited to typing out literal values — `INSERT` can also take its rows from a `SELECT` query, letting you copy or transform existing data into new rows in a single statement. Here's a realistic use: generate "reprint" entries for every book that's currently out of stock, restocked at 10 copies each:

```sql-try
INSERT INTO books (id, title, author_id, genre_id, price, published_year, stock)
SELECT id + 200, title || ' (Reprint)', author_id, genre_id, price, published_year, 10
FROM books
WHERE stock = 0;

SELECT id, title, stock FROM books WHERE id > 200;
```

Three books are sitting at 0 stock in the seed data (*Kingdom of Ash Roses*, *Cold Case: Reykjavik*, *Ash Roses: The Sequel*), so the `SELECT` half produces three rows — the `INSERT` half writes each of them in as a brand-new book, with `id + 200` guaranteeing fresh primary keys and `|| ' (Reprint)'` tagging the title. Instead of a fixed `VALUES (...)` list, the columns come from whatever the `SELECT` computes, row by row.

## Multi-row INSERT: adding several rows at once

A single `INSERT` statement can write more than one row — list additional `(...)` groups after `VALUES`, separated by commas:

```sql-try
INSERT INTO genres (id, name) VALUES
  (201, 'Horror'),
  (202, 'Poetry'),
  (203, 'Travel');

SELECT * FROM genres WHERE id >= 201;
```

All three rows land in one round trip to the database, instead of three separate `INSERT` statements. For anything beyond a handful of rows, this single-statement form is also meaningfully faster than looping one `INSERT` at a time in application code, since the database only has to parse and plan the statement once.

## UPDATE targeting rows found by a subquery

A `WHERE` clause on `UPDATE` (or `DELETE`) can use a subquery, exactly like `SELECT` can — useful when "which rows to change" depends on a lookup rather than a literal value you already know:

```sql-try
UPDATE books
SET stock = stock + 3
WHERE author_id = (SELECT id FROM authors WHERE name = 'Kenji Watanabe');

SELECT title, stock FROM books WHERE author_id = (SELECT id FROM authors WHERE name = 'Kenji Watanabe');
```

The subquery `(SELECT id FROM authors WHERE name = 'Kenji Watanabe')` resolves to that author's id before the `UPDATE` ever touches a row, so both of Kenji Watanabe's books (*Neon Tide* and *Signals From Rhea*) get restocked by 3 — without you needing to already know his `author_id` was `2`. Hit **Reset** afterward to restore the seed data.

## Upsert: INSERT ... ON CONFLICT DO UPDATE

Sometimes you don't know in advance whether a row already exists — you want to insert it if it's new, or update it if it isn't, in one statement. Inserting a `books.id` that already exists normally just fails outright, since `id` is the primary key. `ON CONFLICT` catches that failure and runs an `UPDATE` instead:

```sql-try
INSERT INTO books (id, title, author_id, genre_id, price, published_year, stock)
VALUES (9, 'Cold Case: Reykjavik', 6, 5, 12.00, 2022, 1)
ON CONFLICT (id) DO UPDATE SET stock = books.stock + 1;

SELECT id, title, stock FROM books WHERE id = 9;
```

`id = 9` already exists, so the plain `INSERT` half never actually lands — `ON CONFLICT (id)` catches the primary-key collision and runs `DO UPDATE SET stock = books.stock + 1` against the existing row instead, incrementing its stock by 1 rather than overwriting it with the `VALUES` row. (`books.stock` needs the table name qualifying it inside `DO UPDATE` — unqualified `stock` there is ambiguous between the existing row and the rejected new one.) This single statement replaces the "check if it exists, then decide whether to `INSERT` or `UPDATE`" pattern application code often reaches for, and does it atomically — no gap between the check and the write for a second request to race into. MySQL spells the same idea `INSERT ... ON DUPLICATE KEY UPDATE`; PostgreSQL uses the identical `ON CONFLICT` syntax shown here. Hit **Reset** afterward to restore the seed data.

## Knowledge check

Answer all three questions correctly to unlock **Mark as Complete** for this lesson. Every attempt is recorded.

```knowledge-check
{
  "questions": [
    {
      "id": "modifying-data-q1",
      "type": "mcq",
      "prompt": "What happens if you run UPDATE books SET stock = 0; with no WHERE clause?",
      "options": [
        { "id": "a", "text": "Nothing — SQLite requires a WHERE clause on every UPDATE" },
        { "id": "b", "text": "Only the first row is updated" },
        { "id": "c", "text": "Every single row in the table gets stock set to 0" },
        { "id": "d", "text": "It errors out unless a LIMIT clause is added" }
      ],
      "correct": "c",
      "explanation": "UPDATE without a WHERE clause applies to every row in the table — one of the most common and costly mistakes in SQL."
    },
    {
      "id": "modifying-data-q2",
      "type": "mcq",
      "prompt": "Which statement can take its new row values from a SELECT query instead of a literal VALUES list?",
      "options": [
        { "id": "a", "text": "DELETE FROM ... SELECT" },
        { "id": "b", "text": "INSERT INTO ... SELECT" },
        { "id": "c", "text": "CREATE TABLE ... SELECT VALUES" },
        { "id": "d", "text": "UPDATE ... SELECT ... SET" }
      ],
      "correct": "b",
      "explanation": "INSERT INTO ... SELECT lets you copy or transform existing rows into new rows in one statement, computing values instead of typing a fixed VALUES list."
    },
    {
      "id": "modifying-data-q3",
      "type": "sql",
      "prompt": "Write a query that deletes every loan row where return_date is NULL (still on loan), then selects the remaining row count as remaining.",
      "starter": "DELETE FROM loans WHERE",
      "solution": "DELETE FROM loans WHERE return_date IS NULL; SELECT COUNT(*) AS remaining FROM loans;"
    }
  ]
}
```

## What's next

You can now shape the data itself, not just read it. The next lesson, **Advanced Queries**, builds on `SELECT` in the other direction — subqueries, `EXISTS`, and `CASE` expressions that let you ask sharper, more conditional questions of the data you've got.
