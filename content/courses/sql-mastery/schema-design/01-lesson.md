---
kind: lesson
id_key: sql-mastery/schema-design/lesson
course: sql-mastery
section: schema-design
section_title: "Database & Table Design"
section_position: 7
title: "Creating Tables, Constraints, Indexes, and Views"
position: 0
estimated_minutes: 35
source: [sql-mastery-curriculum.md]
---
Every lesson up to now has queried and modified tables that were already there. This lesson is about defining the tables yourself — the **DDL** (Data Definition Language) side of SQL: `CREATE TABLE`, constraints, `ALTER TABLE`, `DROP TABLE`, indexes, and views. Because every query box here starts from a fresh copy of the seeded database, it's completely safe to create a new table in one of these boxes — it won't collide with anything, and it won't linger into the next box either.

## CREATE TABLE

Let's design a small `reviews` table — one row per reader review of a book:

```sql-try
CREATE TABLE reviews (
  id      INTEGER PRIMARY KEY,
  book_id INTEGER REFERENCES books(id),
  rating  INTEGER CHECK (rating BETWEEN 1 AND 5),
  comment TEXT
);

INSERT INTO reviews (book_id, rating, comment) VALUES (1, 5, 'Beautifully written.');
INSERT INTO reviews (book_id, rating, comment) VALUES (4, 4, 'Solid twist ending.');

SELECT * FROM reviews;
```

Notice neither `INSERT` specified an `id` — yet the `SELECT` shows `id` values of `1` and `2`. That's `INTEGER PRIMARY KEY` at work: in SQLite, a column declared exactly `INTEGER PRIMARY KEY` *is* the table's internal row identifier, and when you omit it, SQLite assigns the next available integer automatically. This is SQLite's version of auto-increment — no `AUTO_INCREMENT` keyword needed like MySQL, and no `SERIAL`/`IDENTITY` column type needed like PostgreSQL or SQL Server. Same idea, three different spellings — a common interview trivia question.

## Data types: SQLite is dynamically typed

The column types above — `INTEGER`, `TEXT` — look like the strict types you'd see in Postgres or MySQL, but SQLite treats them differently. Postgres and MySQL are **statically typed**: a column declared `INTEGER` will reject a text string outright. SQLite is **dynamically typed** — column types are more like a *suggestion* (SQLite calls this "type affinity"). A column declared `TEXT` will happily store a number if you hand it one, and vice versa. In practice, well-behaved schemas (like this one) still stick to consistent types per column, but it's worth knowing SQLite won't stop you the way a stricter database would — a useful callout for interview breadth, since it's a genuine, frequently-asked difference between SQLite and "real" production databases.

## Constraints

The four columns above already used three different constraints, and the library schema you've been querying all course is full of real examples:

- **`PRIMARY KEY`** — uniquely identifies each row. Every table in this course has one (`books.id`, `members.id`, and so on).
- **`FOREIGN KEY`** (`REFERENCES`) — points a column at another table's primary key, like `reviews.book_id REFERENCES books(id)`, or `loans.book_id` and `loans.member_id` in the original schema.
- **`UNIQUE`** — no two rows can share a value. `members.email TEXT NOT NULL UNIQUE` is why every member in the seed data has a distinct email address.
- **`CHECK`** — a boolean condition every row must satisfy. `reviews.rating` uses `CHECK (rating BETWEEN 1 AND 5)` to reject nonsense ratings.
- **`NOT NULL`** — the column can't be left empty. `books.title NOT NULL` and `authors.name NOT NULL` are both examples already in the schema.
- **`DEFAULT`** — a fallback value used when an `INSERT` doesn't provide one. `books.stock INTEGER NOT NULL DEFAULT 0` means a new book with no `stock` specified starts at zero, not `NULL`.

See a `CHECK` constraint actually reject a bad row:

```sql-try
CREATE TABLE reviews (
  id      INTEGER PRIMARY KEY,
  book_id INTEGER REFERENCES books(id),
  rating  INTEGER CHECK (rating BETWEEN 1 AND 5),
  comment TEXT
);

INSERT INTO reviews (book_id, rating, comment) VALUES (1, 9, 'Too high!');
```

That `INSERT` fails — `rating = 9` violates `CHECK (rating BETWEEN 1 AND 5)`, so SQLite refuses to write the row at all. This is the database enforcing data integrity itself, rather than relying on every piece of application code to remember to validate ratings.

## ALTER TABLE: changing a table after creation

Tables don't have to be perfect on the first try — `ALTER TABLE` lets you add a column later:

```sql-try
CREATE TABLE reviews (
  id      INTEGER PRIMARY KEY,
  book_id INTEGER REFERENCES books(id),
  rating  INTEGER CHECK (rating BETWEEN 1 AND 5),
  comment TEXT
);

ALTER TABLE reviews ADD COLUMN created_at TEXT;

INSERT INTO reviews (id, book_id, rating, comment, created_at)
VALUES (1, 4, 4, 'Solid twist ending.', '2024-05-01');

SELECT * FROM reviews;
```

The new `created_at` column shows up immediately, ready to use — any rows that already existed before the `ALTER TABLE` would simply get `NULL` there, since there's no way to retroactively know a value that was never provided.

## DROP TABLE: removing a table entirely

`DELETE FROM reviews` would empty the table but leave its structure intact. `DROP TABLE` goes further — it removes the table itself, columns and all:

```sql-try
CREATE TABLE reviews (
  id      INTEGER PRIMARY KEY,
  book_id INTEGER REFERENCES books(id),
  rating  INTEGER CHECK (rating BETWEEN 1 AND 5),
  comment TEXT
);

DROP TABLE reviews;

SELECT name FROM sqlite_master WHERE type = 'table';
```

`sqlite_master` is SQLite's internal catalog of every table (and index, and view) in the database. `reviews` doesn't appear in the list — only the five original library tables do — confirming `DROP TABLE` erased it completely, not just its rows.

## Indexes: speeding up lookups

An index is a separate, sorted structure the database maintains alongside a table, so it can jump straight to matching rows instead of scanning every one:

```sql-try
CREATE INDEX idx_books_genre ON books(genre_id);

SELECT title FROM books WHERE genre_id = 3;
```

The query itself returns the same three Fantasy titles it would without the index. What changes is *how* SQLite finds them: without `idx_books_genre`, it has to check `genre_id` on all 15 rows one by one; with it, it can look up `genre_id = 3` directly. On a table with 15 rows the difference is invisible, but on a table with 15 million it's the difference between milliseconds and minutes. Indexes aren't free, though — every `INSERT`/`UPDATE`/`DELETE` on an indexed column has to update the index too, so they're worth adding on columns you filter or join on often, not on every column reflexively.

## Views: saving a query as a virtual table

A view wraps a `SELECT` — often a join — under a name you can query like a table. It doesn't store its own copy of the data; it recomputes the underlying query every time you select from it:

```sql-try
CREATE VIEW book_catalog AS
SELECT b.title, a.name AS author_name, g.name AS genre_name, b.price
FROM books b
JOIN authors a ON a.id = b.author_id
JOIN genres g ON g.id = b.genre_id;

SELECT * FROM book_catalog
ORDER BY title
LIMIT 5;
```

`book_catalog` hides the three-table join behind a single name — anyone querying it just sees `title`, `author_name`, `genre_name`, and `price`, without needing to know (or repeat) the join logic underneath. The first five titles alphabetically are *A Quiet Kind of Fire*, *Ash Roses: The Sequel*, *Cold Case: Reykjavik*, *Diallo Speaks*, and *How Rivers Remember*.

## PRAGMA foreign_keys: enforcement isn't automatic

Declaring `author_id INTEGER REFERENCES authors(id)` describes the relationship, but SQLite does **not** enforce it by default — you can insert a `books` row with an `author_id` that doesn't exist in `authors` at all, and SQLite won't complain unless foreign key checking has been turned on for that connection:

```sql-try
PRAGMA foreign_keys;
```

That returns `0` on a fresh connection — foreign key checking is off. Turn it on with `PRAGMA foreign_keys = ON;`, and only then does SQLite start rejecting inserts/updates that would violate a `REFERENCES` constraint. This is a genuine, frequently-tested difference from PostgreSQL and MySQL (with InnoDB), where foreign keys are enforced unconditionally — SQLite's `REFERENCES` clause is really just documentation unless you opt in.

## Composite indexes: column order matters

An index isn't limited to one column — a **composite index** covers several columns together, and SQLite can only use it efficiently starting from its *leftmost* column:

```sql-try
CREATE INDEX idx_loans_member_date ON loans(member_id, loan_date);

SELECT * FROM loans WHERE member_id = 3 AND loan_date > '2024-01-01';
```

`idx_loans_member_date` speeds up this query because the filter starts with `member_id` — the index's leading column. A query that filters on `loan_date` alone, without `member_id`, can't make efficient use of this particular index at all, the same way you can't jump to the middle of a phone book sorted by last-name-then-first-name using only a first name. When deciding which column goes first in a composite index, put whichever one your queries most often filter on by itself.

## Knowledge check

Answer all three questions correctly to unlock **Mark as Complete** for this lesson. Every attempt is recorded.

```knowledge-check
{
  "questions": [
    {
      "id": "schema-design-q1",
      "type": "mcq",
      "prompt": "Which SQLite setting must be turned on for FOREIGN KEY / REFERENCES constraints to actually be enforced?",
      "options": [
        { "id": "a", "text": "PRAGMA foreign_keys = ON" },
        { "id": "b", "text": "CHECK (foreign_keys = 1)" },
        { "id": "c", "text": "Foreign keys are always enforced in SQLite by default" },
        { "id": "d", "text": "ALTER TABLE ... ENABLE FOREIGN KEYS" }
      ],
      "correct": "a",
      "explanation": "SQLite parses REFERENCES as metadata but does not enforce it unless PRAGMA foreign_keys = ON is set for that connection."
    },
    {
      "id": "schema-design-q2",
      "type": "mcq",
      "prompt": "Given CREATE INDEX idx ON loans(member_id, loan_date), which column must a query filter on for this index to be usable?",
      "options": [
        { "id": "a", "text": "loan_date alone is enough" },
        { "id": "b", "text": "member_id, the leading (leftmost) column of the index" },
        { "id": "c", "text": "Either column works equally well on its own" },
        { "id": "d", "text": "Neither — composite indexes are never usable in SQLite" }
      ],
      "correct": "b",
      "explanation": "A composite index can only be used efficiently starting from its leftmost column — here, member_id. Filtering on loan_date alone can't take advantage of it."
    },
    {
      "id": "schema-design-q3",
      "type": "sql",
      "prompt": "Create a view named cheap_books showing the title and price of every book priced under 10, then select all rows from it ordered by price.",
      "starter": "CREATE VIEW",
      "solution": "CREATE VIEW cheap_books AS SELECT title, price FROM books WHERE price < 10; SELECT * FROM cheap_books ORDER BY price;"
    }
  ]
}
```

## What's next

You can now design a schema, not just query one. The next lesson turns to dates and time — the `loan_date`/`return_date` columns you've been reading past this whole course, and the functions SQLite gives you to work with them.
