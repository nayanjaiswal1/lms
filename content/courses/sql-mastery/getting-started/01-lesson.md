---
kind: lesson
id_key: sql-mastery/getting-started/lesson
course: sql-mastery
section: getting-started
section_title: "Getting Started"
section_position: 1
title: "What SQL Is, and Your First Queries"
position: 0
estimated_minutes: 25
source: [sql-mastery-curriculum.md]
---
SQL (Structured Query Language) is how you talk to a relational database — a database that stores data in **tables**, where each table is a grid of **rows** (records) and **columns** (fields). Every example in this course runs against the same small database: a library with five tables — `genres`, `authors`, `books`, `members`, and `loans` — so once you understand the shape of that data, every new SQL concept just becomes a new way of asking questions about it.

Every query box in this course is live. Edit the SQL, hit **Run SQL**, and you'll see real results instantly — there's no server round-trip, it's running in your browser against a real (tiny) SQLite database seeded just for these examples.

## The library schema

| Table | What it holds |
|---|---|
| `genres` | `id`, `name` |
| `authors` | `id`, `name`, `country` |
| `books` | `id`, `title`, `author_id`, `genre_id`, `price`, `published_year`, `stock` |
| `members` | `id`, `name`, `email`, `joined_date`, `city`, `referred_by` |
| `loans` | `id`, `book_id`, `member_id`, `loan_date`, `return_date` |

A book belongs to one author and one genre (`author_id`, `genre_id` point back to those tables). A loan links one book to one member on the date it was borrowed — `return_date` is empty (`NULL`) until the book comes back. You'll use this same schema in every lesson from here on.

## SELECT: asking for data

Every query that reads data starts with `SELECT`. You tell it which columns you want, and `FROM` which table:

```sql-try
SELECT title, price, published_year
FROM books;
```

Run it — you'll get every book's title, price, and publication year, in whatever order SQLite happens to store them (more on controlling that in the next lesson).

To get every column without typing them all out, use `*`:

```sql-try
SELECT * FROM authors;
```

`*` is convenient for exploring, but in real applications you almost always name the exact columns you need — it's more explicit, and it means your query doesn't silently change shape if someone adds a column to the table later.

## Renaming columns with AS

You can give a column (or an expression) a friendlier name in the output using `AS`:

```sql-try
SELECT title AS book_title, price AS list_price
FROM books
LIMIT 5;
```

`LIMIT 5` caps the result to the first 5 rows — useful while you're exploring a table you don't know yet. (SQL Server uses `TOP 5` for the same thing; SQLite, MySQL, and PostgreSQL all use `LIMIT`.)

## SELECT DISTINCT: removing duplicates

Plain `SELECT` returns every matching row, even if two rows have the same value in the column you asked for. `SELECT DISTINCT` collapses duplicates:

```sql-try
SELECT genre_id FROM books;
```

Notice genre IDs repeat — lots of books share a genre. Add `DISTINCT` and you get each one exactly once:

```sql-try
SELECT DISTINCT genre_id FROM books;
```

`DISTINCT` applies to the whole row you selected, not to a single column in isolation — `SELECT DISTINCT author_id, genre_id FROM books` would only collapse rows where *both* columns match.

## Data types in SQLite

Every column has a declared type — `TEXT` for strings, `INTEGER` for whole numbers, `REAL` for decimals like `price`. SQLite is more relaxed about this than PostgreSQL or MySQL (it uses "type affinity" rather than strictly rejecting mismatched values), but the concepts map directly: `books.price` is a `REAL`, `books.stock` is an `INTEGER`, `authors.name` is `TEXT`. Getting the type right matters once you start comparing or sorting columns — comparing a number stored as text won't sort the way you expect.

## Comments

Two authors' hands touch most real queries eventually, so leaving a note in the SQL itself is normal. `--` comments out the rest of a line; `/* ... */` comments out a block:

```sql-try
-- only paperback-priced books, roughly
SELECT title, price FROM books WHERE price < 12; /* threshold picked by the marketing team */
```

(This lesson hasn't covered `WHERE` yet — that's next — but the comment syntax works the same everywhere.)

## Knowledge check

Answer all three questions correctly to unlock **Mark as Complete** for this lesson. Every attempt is recorded.

```knowledge-check
{
  "questions": [
    {
      "id": "getting-started-q1",
      "type": "mcq",
      "prompt": "Which query returns every column from the authors table without naming them individually?",
      "options": [
        { "id": "a", "text": "SELECT * FROM authors;" },
        { "id": "b", "text": "SELECT ALL FROM authors;" },
        { "id": "c", "text": "SELECT COLUMNS FROM authors;" },
        { "id": "d", "text": "FROM authors SELECT *;" }
      ],
      "correct": "a",
      "explanation": "* is the wildcard for \"every column\" in a SELECT list — the only valid syntax of the four."
    },
    {
      "id": "getting-started-q2",
      "type": "mcq",
      "prompt": "Which clause collapses duplicate rows out of a result set?",
      "options": [
        { "id": "a", "text": "LIMIT" },
        { "id": "b", "text": "DISTINCT" },
        { "id": "c", "text": "UNIQUE" },
        { "id": "d", "text": "GROUP" }
      ],
      "correct": "b",
      "explanation": "DISTINCT applies to the whole selected row. UNIQUE is a table constraint, not a SELECT modifier."
    },
    {
      "id": "getting-started-q3",
      "type": "sql",
      "prompt": "Write a query that lists every book's title and price (renamed to list_price), showing only the first 5 rows.",
      "starter": "SELECT",
      "solution": "SELECT title, price AS list_price FROM books LIMIT 5;"
    }
  ]
}
```

## What's next

You can already read any column from any table. The next lesson covers **filtering** — `WHERE`, comparisons, `LIKE`, and sorting with `ORDER BY` — so you can ask for exactly the rows you want instead of all of them.
