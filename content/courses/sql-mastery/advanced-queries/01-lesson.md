---
kind: lesson
id_key: sql-mastery/advanced-queries/lesson
course: sql-mastery
section: advanced-queries
section_title: "Advanced Queries"
section_position: 6
title: "Subqueries, EXISTS, and CASE Expressions"
position: 0
estimated_minutes: 30
source: [sql-mastery-curriculum.md]
---
So far every `WHERE` clause has compared a column to a literal value or another column in the same row. SQL lets you go further: a `WHERE` clause can compare against the *result of another query* — a **subquery**. This lesson covers subqueries, the `EXISTS` alternative to them, conditional logic with `CASE`, and a quick recap of `LIMIT` and aliasing tying back to lesson one.

## Subqueries in WHERE

Suppose you want every book that has never been loaned out. You don't have a `never_loaned` flag anywhere — but you can ask for it by nesting a query inside another:

```sql-try
SELECT title FROM books
WHERE id NOT IN (SELECT book_id FROM loans);
```

The inner query `SELECT book_id FROM loans` produces the list of every book id that has ever appeared in a loan. The outer query then keeps only the books whose `id` is *not* in that list. Against the seed data that's five titles: *Kingdom of Ash Roses*, *The Last Alchemist*, *Watanabe: A Life*, *Diallo Speaks*, and *Ash Roses: The Sequel* — books that exist in the catalog but have sat on the shelf the whole time.

## EXISTS and NOT EXISTS

`NOT IN` works fine here, but there's another way to ask the same question — `NOT EXISTS`, which checks whether a subquery returns *any* rows at all, without caring what those rows contain:

```sql-try
SELECT title FROM books b
WHERE NOT EXISTS (
  SELECT 1 FROM loans l WHERE l.book_id = b.id
);
```

Same five titles, same result — but a different mechanism. The inner query is **correlated**: it references `b.id` from the outer query, so it effectively runs once per book, asking "does any loan row point at this book?" `SELECT 1` is a common convention here — `EXISTS` only cares whether a row comes back, not its contents, so the selected value is irrelevant.

`EXISTS`/`NOT EXISTS` is generally the safer default over `IN`/`NOT IN` for one sharp reason: **NULLs**. If the subquery inside a `NOT IN` ever returns even one `NULL`, the whole `NOT IN` comparison silently stops matching anything, and your query returns zero rows with no error. `NOT EXISTS` isn't affected by NULLs inside the subquery at all, because it only asks "did any row come back?" `EXISTS` can also be faster on large tables, since the database can stop scanning the instant it finds one matching row instead of building the full list `IN` needs.

## ANY and ALL — the SQLite gap

Some databases (PostgreSQL, SQL Server) let you write comparisons like `price > ALL (subquery)` or `price = ANY (subquery)` directly. **SQLite doesn't support this `ANY`/`ALL` syntax** — writing it will error. The good news is you don't lose any expressive power, because `> ALL (subquery)` is just a longer way of saying "greater than the maximum value the subquery produces," and SQLite handles that fine with `MAX()`/`MIN()`:

```sql-try
SELECT title, price FROM books
WHERE genre_id != 3
  AND price > (SELECT MAX(price) FROM books WHERE genre_id = 3);
```

Fantasy (`genre_id` 3) tops out at $18.00, so this returns every non-Fantasy book priced above that: *How Rivers Remember* ($19.99), *Watanabe: A Life* ($22.50), and *Diallo Speaks* ($21.00). That's the `> ALL` idea, expressed with `MAX()`. The `= ANY` idea works the same way in reverse — `price = ANY (subquery)` is equivalent to `price IN (subquery)`, which SQLite supports natively.

## CASE: conditional values in a query

`CASE` lets a query return different values depending on a condition — it behaves like if/else, evaluated per row:

```sql-try
SELECT title, price,
  CASE
    WHEN price < 10 THEN 'Budget'
    WHEN price <= 18 THEN 'Standard'
    ELSE 'Premium'
  END AS price_tier
FROM books
ORDER BY price;
```

Each `WHEN` is checked top to bottom, and the first one that matches wins — so a $18.00 book hits the `price <= 18` branch and lands in `'Standard'`, never reaching `ELSE`. Anything above $18.00 falls through to `'Premium'`. `CASE` is an expression, not a statement — you can use it anywhere a column is allowed, including inside `ORDER BY` or another expression.

## LIMIT and aliasing, together

A quick recap tying earlier lessons back in: `AS` names computed columns, and `LIMIT` caps how many rows come back — both work fine alongside `CASE`:

```sql-try
SELECT title AS book_title, price,
  CASE WHEN price > 18 THEN 'Premium' ELSE 'Standard or Budget' END AS tier
FROM books
ORDER BY price DESC
LIMIT 3;
```

The three priciest books in the library — *Watanabe: A Life*, *Diallo Speaks*, and *How Rivers Remember* — all clear $18.00, so all three land in `'Premium'`.

## Correlated scalar subqueries in SELECT

A subquery doesn't have to live only in `WHERE` — it can sit directly in the `SELECT` list too, computing one value per outer row. This is still a **correlated** subquery when it references a column from the outer query, and SQLite re-runs it once per row:

```sql-try
SELECT b.title,
  (SELECT COUNT(*) FROM loans l WHERE l.book_id = b.id) AS times_loaned
FROM books b
ORDER BY times_loaned DESC
LIMIT 5;
```

For every book, the subquery counts how many `loans` rows point back at `l.book_id = b.id` — a different count for each row of `books`, computed fresh each time. *The Silent Harbor* comes out on top with 3 loans. A scalar subquery like this must return exactly one column and at most one row per invocation, or SQLite raises an error — `COUNT(*)` is a safe choice here because an aggregate always collapses to a single number, even when zero rows match.

## Common Table Expressions with WITH

A CTE (`WITH name AS (subquery)`) lets you name a subquery once at the top of a statement and reference it — even more than once — later in the same query, instead of repeating or nesting the same subquery inline:

```sql-try
WITH genre_totals AS (
  SELECT genre_id, COUNT(*) AS num_books, ROUND(AVG(price), 2) AS avg_price
  FROM books
  GROUP BY genre_id
)
SELECT g.name, gt.num_books, gt.avg_price
FROM genre_totals gt
JOIN genres g ON g.id = gt.genre_id
WHERE gt.num_books > 1
ORDER BY gt.avg_price DESC;
```

`genre_totals` is computed once, then queried like any other table — joined to `genres` for a readable name, and filtered with an ordinary `WHERE`. The main advantage over a nested subquery is readability: complex logic reads top-to-bottom as named steps instead of parentheses nested three deep.

## WITH RECURSIVE: iterating within a query

A regular CTE runs once. `WITH RECURSIVE` lets a CTE reference *itself*, building up rows step by step until some condition stops it — the mechanism behind two classic interview shapes: walking a hierarchy (an org chart via `manager_id`, a category tree), and generating a series that doesn't exist as rows in any table. The library schema has no hierarchy column, so here's the series case — a full calendar of every day between the first and last loan, including days with zero loans:

```sql-try
WITH RECURSIVE dates(day) AS (
  SELECT MIN(loan_date) FROM loans
  UNION ALL
  SELECT date(day, '+1 day') FROM dates WHERE day < (SELECT MAX(loan_date) FROM loans)
)
SELECT day, (SELECT COUNT(*) FROM loans WHERE loan_date = day) AS loans_that_day
FROM dates
ORDER BY day;
```

The first `SELECT` is the **anchor** — it seeds `dates` with one row, the earliest loan date. The `UNION ALL` branch is the **recursive step**: it takes the previous `day`, adds one with `date(day, '+1 day')`, and keeps going as long as that's still before the latest loan date — each pass feeds off the row the pass before it produced. `UNION ALL` (not plain `UNION`) matters here, since `UNION` would try to deduplicate against every prior row on each step and quietly changes the performance characteristics. The result includes calendar days that have zero loans at all — something a plain `GROUP BY loan_date` could never surface, since grouping only ever shows dates that already have at least one row. The hierarchy version follows the identical shape: anchor on the root row (`WHERE manager_id IS NULL`), recursive step joins the table to itself one level down, `UNION ALL` accumulates every level.

## Knowledge check

Answer all three questions correctly to unlock **Mark as Complete** for this lesson. Every attempt is recorded.

```knowledge-check
{
  "questions": [
    {
      "id": "advanced-queries-q1",
      "type": "mcq",
      "prompt": "Why is EXISTS/NOT EXISTS generally considered safer than IN/NOT IN when the subquery's column could contain NULL?",
      "options": [
        { "id": "a", "text": "EXISTS only checks whether any row comes back, so a NULL inside the subquery doesn't affect it; NOT IN can silently return zero rows if the subquery contains a NULL" },
        { "id": "b", "text": "IN cannot be used with a subquery at all, only with a literal list" },
        { "id": "c", "text": "EXISTS is always faster, regardless of NULLs" },
        { "id": "d", "text": "NOT IN throws an error whenever a NULL is present" }
      ],
      "correct": "a",
      "explanation": "If a NOT IN subquery ever returns a NULL, the whole NOT IN comparison evaluates to UNKNOWN for every row, silently returning zero results. NOT EXISTS has no such trap."
    },
    {
      "id": "advanced-queries-q2",
      "type": "mcq",
      "prompt": "What does a WITH clause introduce at the start of a SQL statement?",
      "options": [
        { "id": "a", "text": "A named, reusable subquery — a Common Table Expression" },
        { "id": "b", "text": "A permanent new table stored on disk" },
        { "id": "c", "text": "A shortcut for GROUP BY" },
        { "id": "d", "text": "A way to disable NULL checking for the rest of the query" }
      ],
      "correct": "a",
      "explanation": "WITH defines a Common Table Expression — a subquery given a name that can be referenced later in the same statement, improving readability over deeply nested subqueries."
    },
    {
      "id": "advanced-queries-q3",
      "type": "sql",
      "prompt": "Write a query using EXISTS that lists every author's name who has written at least one book priced over 20.",
      "starter": "SELECT",
      "solution": "SELECT name FROM authors a WHERE EXISTS (SELECT 1 FROM books b WHERE b.author_id = a.id AND b.price > 20);"
    }
  ]
}
```

## What's next

You can now ask questions that depend on other questions. The next lesson, **Database & Table Design**, moves from querying data to defining it — creating tables, constraints, indexes, and views of your own.
