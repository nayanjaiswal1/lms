-- ══════════════════════════════════════════════════════════════════════════
-- GENERATED FILE — DO NOT EDIT.
-- Source: canonical markdown content (content/courses/**).
-- Regenerate via: cd backend && go run ./cmd/coursegen generate
-- Generated at: 2026-07-25T19:01:01Z
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Course: SQL Mastery: From Scratch to Interview-Ready ─────────────────────────────────────────────
INSERT INTO courses (id, org_id, creator_id, title, slug, description, cover_url, difficulty, tags, status, is_free, estimated_hours)
VALUES ('a4531b49-7973-5e3f-8659-8fcae686dbdd', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'SQL Mastery: From Scratch to Interview-Ready', 'sql-mastery', 'A comprehensive, hands-on SQL course built around a single running example — a small library database (books, authors, genres, members, loans). Every lesson ships runnable "Try it Yourself" query boxes powered by an in-browser SQLite engine, so you write and execute real SQL with zero setup. Covers querying, filtering, aggregation, every join type, data modification, subqueries, schema design and constraints, dates, and a final section of classic interview query patterns (Nth highest value, duplicates, running counts) with a mixed-topic assessment.', '/course-covers/sql-mastery.svg', 'beginner', ARRAY['sql','databases','interview-prep'], 'published', true, 9.4)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, cover_url=EXCLUDED.cover_url, tags=EXCLUDED.tags, estimated_hours=EXCLUDED.estimated_hours, updated_at=now();

-- Section: Getting Started
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('ec8706bf-ebe9-5b3b-b724-5dd325900479', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'Getting Started', 1)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('2cad97e4-5913-5521-a963-b8500d72e23c', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'ec8706bf-ebe9-5b3b-b724-5dd325900479', 'What SQL Is, and Your First Queries', 'notes', 0, $md$SQL (Structured Query Language) is how you talk to a relational database — a database that stores data in **tables**, where each table is a grid of **rows** (records) and **columns** (fields). Every example in this course runs against the same small database: a library with five tables — `genres`, `authors`, `books`, `members`, and `loans` — so once you understand the shape of that data, every new SQL concept just becomes a new way of asking questions about it.

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
$md$, 25, $json$[{"id":"getting-started-q1","type":"mcq","correct":"a"},{"id":"getting-started-q2","type":"mcq","correct":"b"},{"id":"getting-started-q3","type":"sql"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d4cdd6e0-4a7f-559e-8340-240c611e1372', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does SQL stand for?', 'beginner', 1, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('0be442ce-1038-5ebe-b2d5-886f8b4b2350', 'd4cdd6e0-4a7f-559e-8340-240c611e1372', 1, $json${"prompt":"What does SQL stand for?","multiple":false,"options":[{"id":"a","text":"Structured Query Language","is_correct":true},{"id":"b","text":"Sequential Query Logic","is_correct":false},{"id":"c","text":"System Query List","is_correct":false},{"id":"d","text":"Standard Query Layer","is_correct":false}],"explanation":"SQL stands for Structured Query Language — the standard language for interacting with relational databases."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('aaa99c2b-1bec-5136-9d88-c867a6dd7ca4', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why do real applications usually avoid `SELECT *` in favor of naming exact co...', 'beginner', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f5891ed2-7035-5031-9aab-33508de76057', 'aaa99c2b-1bec-5136-9d88-c867a6dd7ca4', 1, $json${"prompt":"Why do real applications usually avoid `SELECT *` in favor of naming exact columns?","multiple":false,"options":[{"id":"a","text":"SELECT * is invalid SQL syntax","is_correct":false},{"id":"b","text":"Naming columns explicitly is more explicit and doesn't silently change if the table's columns change later","is_correct":true},{"id":"c","text":"SELECT * only works on tables with a primary key","is_correct":false},{"id":"d","text":"SELECT * cannot be combined with WHERE","is_correct":false}],"explanation":"SELECT * is valid and fine for quick exploration, but naming columns explicitly keeps queries predictable as schemas evolve."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c6c8600f-a912-5e47-9c8f-eb629a5cff85', '00000000-0000-0000-0000-000000000001', 'mcq', 'Given `SELECT DISTINCT author_id, genre_id FROM books;`, which rows are colla...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d024dae1-d950-5bc4-97d0-6d6c6df7f461', 'c6c8600f-a912-5e47-9c8f-eb629a5cff85', 1, $json${"prompt":"Given `SELECT DISTINCT author_id, genre_id FROM books;`, which rows are collapsed together?","multiple":false,"options":[{"id":"a","text":"Rows where author_id matches, regardless of genre_id","is_correct":false},{"id":"b","text":"Rows where genre_id matches, regardless of author_id","is_correct":false},{"id":"c","text":"Rows where both author_id AND genre_id match","is_correct":true},{"id":"d","text":"DISTINCT cannot be used with more than one column","is_correct":false}],"explanation":"DISTINCT applies to the combination of every selected column — two rows are only collapsed if they match on all of them."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('754da70f-81fa-59da-9cb8-2572a609a313', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which keyword limits the number of rows returned in SQLite, MySQL, and Postgr...', 'beginner', 1, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('31a6e781-3ea7-5a57-8e1d-8c0adbba1d64', '754da70f-81fa-59da-9cb8-2572a609a313', 1, $json${"prompt":"Which keyword limits the number of rows returned in SQLite, MySQL, and PostgreSQL?","multiple":false,"options":[{"id":"a","text":"TOP","is_correct":false},{"id":"b","text":"LIMIT","is_correct":true},{"id":"c","text":"FETCH FIRST","is_correct":false},{"id":"d","text":"ROWNUM","is_correct":false}],"explanation":"LIMIT is used by SQLite, MySQL, and PostgreSQL. SQL Server uses TOP instead — same idea, different keyword."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('e6386e47-446f-5f73-882a-25e7552e74d1', '00000000-0000-0000-0000-000000000001', 'mcq', 'In the loans table, what does a NULL return_date mean?', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e951b7b8-711d-5c7d-9dbc-c788c6203a98', 'e6386e47-446f-5f73-882a-25e7552e74d1', 1, $json${"prompt":"In the loans table, what does a NULL return_date mean?","multiple":false,"options":[{"id":"a","text":"The loan record is corrupted","is_correct":false},{"id":"b","text":"The book has never been borrowed","is_correct":false},{"id":"c","text":"The book was borrowed and hasn't been returned yet","is_correct":true},{"id":"d","text":"The book was returned on the same day it was borrowed","is_correct":false}],"explanation":"A NULL return_date represents an open loan — the book is still checked out."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('265e7683-4152-5e8e-81a4-d9952197b04a', '00000000-0000-0000-0000-000000000001', 'Quiz: SQL Basics', 'sql-mastery-getting-started-quiz', 'Quiz covering Getting Started.', 'mcq', 'published', 'module', '5f9f9b49-bfb7-5ee4-ada0-1c9e750bf37d', 10, 70, 5, 8, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('7eed4613-3ebc-5658-b8ea-c9a953ff51e0', '265e7683-4152-5e8e-81a4-d9952197b04a', 'd4cdd6e0-4a7f-559e-8340-240c611e1372', '0be442ce-1038-5ebe-b2d5-886f8b4b2350', 0, 1),
('727f0c99-737a-578b-9c34-3d5e683b718b', '265e7683-4152-5e8e-81a4-d9952197b04a', 'aaa99c2b-1bec-5136-9d88-c867a6dd7ca4', 'f5891ed2-7035-5031-9aab-33508de76057', 1, 2),
('aeb88542-7225-59f3-b8a5-f8a5e09a4fad', '265e7683-4152-5e8e-81a4-d9952197b04a', 'c6c8600f-a912-5e47-9c8f-eb629a5cff85', 'd024dae1-d950-5bc4-97d0-6d6c6df7f461', 2, 2),
('8629bdc9-d081-5754-8c1e-a29f15092987', '265e7683-4152-5e8e-81a4-d9952197b04a', '754da70f-81fa-59da-9cb8-2572a609a313', '31a6e781-3ea7-5a57-8e1d-8c0adbba1d64', 3, 1),
('3538e1e7-c249-5742-9f86-bcb232ab7ac6', '265e7683-4152-5e8e-81a4-d9952197b04a', 'e6386e47-446f-5f73-882a-25e7552e74d1', 'e951b7b8-711d-5c7d-9dbc-c788c6203a98', 4, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('5f9f9b49-bfb7-5ee4-ada0-1c9e750bf37d', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'ec8706bf-ebe9-5b3b-b724-5dd325900479', 'Quiz: SQL Basics', 'assessment', 1, 10, '265e7683-4152-5e8e-81a4-d9952197b04a')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Filtering & Sorting
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('0b221161-76a6-53d8-97fe-3b8d48a4d523', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'Filtering & Sorting', 2)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('d643f99a-51b6-5b0c-86ed-a5d19cfe5c37', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '0b221161-76a6-53d8-97fe-3b8d48a4d523', 'Filtering Rows with WHERE and Sorting with ORDER BY', 'notes', 0, $md$So far every query has returned *every* row in a table. Real questions are narrower — "which books cost less than $12," "which members joined from Paris." `WHERE` picks rows; `ORDER BY` decides what order they come back in. Both work on the same library schema from the last lesson.

## WHERE and comparison operators

`WHERE` goes after `FROM` and keeps only the rows where the condition is true. SQLite supports the comparisons you'd expect: `=`, `!=` (or `<>`), `>`, `<`, `>=`, `<=`.

```sql-try
SELECT title, price
FROM books
WHERE price < 12;
```

Four books come back: *The Cartographer's Debt* ($11.25), *A Quiet Kind of Fire* ($9.99), *Murder on Platform Nine* ($10.50), and *Nobody's Almanac* ($8.75) — every book priced under $12, and nothing else.

## Combining conditions: AND, OR, NOT

`AND` requires every condition to be true; `OR` requires at least one. Watch how the same genre filter behaves differently once you add a second condition:

```sql-try
SELECT title, genre_id, stock
FROM books
WHERE genre_id = 3 AND stock > 0;
```

Genre 3 (Fantasy) actually has three books — *Kingdom of Ash Roses*, *The Last Alchemist*, and *Ash Roses: The Sequel* — but two of them are out of stock. `AND` narrows the result down to the one row where **both** conditions hold: *The Last Alchemist*.

```sql-try
SELECT title, genre_id
FROM books
WHERE genre_id = 4 OR genre_id = 6;
```

`OR` widens instead of narrows — this returns every Mystery **and** every Biography, four books in total, even though no single book is both.

`NOT` flips a condition. `WHERE NOT genre_id = 3` means exactly the same thing as `WHERE genre_id != 3` — every book except the three Fantasy titles. It reads naturally in front of more complex conditions, like `WHERE NOT (genre_id = 4 OR genre_id = 6)`, which flips the whole OR and gives you everything *except* the Mystery/Biography books.

## Sorting with ORDER BY

`ORDER BY` sorts the result set. Add `DESC` for highest-to-lowest; the default (no keyword, or `ASC`) is lowest-to-highest. You can also sort by more than one column — SQLite sorts by the first column, and for rows that tie on it, breaks the tie using the next column:

```sql-try
SELECT title, genre_id, price
FROM books
ORDER BY genre_id ASC, price DESC;
```

Because `genre_id ASC` comes first in the sort, the result starts with all of genre 1 (Fiction) — *The Silent Harbor* at $12.99, then *The Empire of Salt* at $12.00, and so on — and only after every genre-1 row is exhausted does genre 2 begin. `price DESC` only controls the order *within* a genre; it doesn't make the single priciest book in the whole library, *Watanabe: A Life* at $22.50, jump to the top — it's genre 6 (Biography), so it doesn't appear until the very last group. One thing to notice along the way: genre 3 has two books tied at exactly $18.00 (*Kingdom of Ash Roses* and *Ash Roses: The Sequel*). SQL doesn't promise which of two tied rows comes first — if you need a guaranteed order, add a third sort column (like `title`) to break the tie explicitly.

## Pattern matching with LIKE

`LIKE` matches text against a pattern using two wildcards: `%` matches zero or more of any character, `_` matches exactly one.

```sql-try
SELECT title
FROM books
WHERE title LIKE 'The %';
```

That matches any title starting with "The " followed by anything — four books: *The Silent Harbor*, *The Cartographer's Debt*, *The Last Alchemist*, and *The Empire of Salt*.

`_` is more precise — useful when you know the shape but not one exact letter:

```sql-try
SELECT name, city
FROM members
WHERE city LIKE 'P_r%';
```

This matches "P", then exactly one character, then "r", then anything. It catches both **Paris** (P-**a**-r-is) and **Porto** (P-**o**-r-to) — two different cities, one pattern, because `_` doesn't care what the middle letter is, only that there's exactly one.

## IN and BETWEEN

`IN` checks a value against a list — shorthand for a chain of `OR`s:

```sql-try
SELECT title, genre_id
FROM books
WHERE genre_id IN (3, 5);
```

Five books come back: the three Fantasy titles plus the two Non-Fiction titles (*How Rivers Remember*, *Nobody's Almanac*) — equivalent to `WHERE genre_id = 3 OR genre_id = 5`, just easier to read with more values.

`BETWEEN` checks a range, and it's **inclusive** on both ends:

```sql-try
SELECT title, published_year
FROM books
WHERE published_year BETWEEN 2018 AND 2020;
```

Five books published in 2018, 2019, or 2020 come back — including books from 2018 and 2020 themselves, not just the years strictly in between.

## NULL: the value that isn't a value

`NULL` means "no value recorded" — in the `members` table, `referred_by` is `NULL` for anyone who joined without a referral. You can't test for it with `=`, because `NULL` isn't equal to anything, not even another `NULL`. You need `IS NULL` / `IS NOT NULL`:

```sql-try
SELECT name, referred_by
FROM members
WHERE referred_by IS NULL;
```

Five members joined with no referrer: Ana Torres, Chloe Martin, Elin Karlsson, Grace Kim, and Jonas Weber.

Now see what happens if you reach for `=` instead:

```sql-try
SELECT name
FROM members
WHERE referred_by = NULL;
```

Zero rows — every time, no matter how many `NULL`s are actually in the column. `= NULL` isn't false, it's *unknown*, and `WHERE` only keeps rows where the condition evaluates to true. This is one of the most common beginner bugs in SQL, and now you know why it happens.

## Case-sensitivity: LIKE vs GLOB

`LIKE` in SQLite is case-insensitive for ASCII letters by default — `WHERE title LIKE 'the %'` matches `'The Silent Harbor'` just as well as `'the silent harbor'` would. That's different from PostgreSQL, where `LIKE` is case-sensitive and you'd need `ILIKE` for case-insensitive matching.

```sql-try
SELECT title FROM books WHERE title LIKE 'the%';
```

SQLite also has a second pattern-matching operator, `GLOB`, which uses Unix shell-style wildcards (`*` for any run of characters, `?` for exactly one) and **is** case-sensitive:

```sql-try
SELECT title FROM books WHERE title GLOB 'The*';
```

Lowercase the `T` in that pattern (`'the*'`) and it matches nothing — `GLOB` cares about case, `LIKE` doesn't. Reach for `LIKE` when case shouldn't matter (the common case), and `GLOB` on the rare occasion you need exact-case matching without a full regular expression.

## NULL and three-valued logic: AND, OR, NOT

SQL doesn't just have `TRUE` and `FALSE` — a condition involving `NULL` evaluates to a third state, `UNKNOWN`, and `WHERE` only keeps rows where the result is `TRUE` (not `UNKNOWN`). That matters the moment `NULL` shows up inside `AND`/`OR`:

```sql-try
SELECT name, referred_by
FROM members
WHERE referred_by = 1 OR referred_by IS NULL;
```

`referred_by = 1` evaluates to `UNKNOWN` (not `FALSE`) for every row where `referred_by` is `NULL`, so without the explicit `OR referred_by IS NULL`, those rows would silently disappear — `UNKNOWN` never satisfies `WHERE` on its own. The rule of thumb: `NULL AND FALSE` is `FALSE` (still provably false, since one side is enough), but `NULL AND TRUE` and `NULL OR FALSE` are both `UNKNOWN`. Any time a column that can be `NULL` shows up in a compound condition, ask explicitly what should happen to the `NULL` rows — SQL won't guess for you.

## Knowledge check

Answer all three questions correctly to unlock **Mark as Complete** for this lesson. Every attempt is recorded.

```knowledge-check
{
  "questions": [
    {
      "id": "filtering-q1",
      "type": "mcq",
      "prompt": "Which values does `WHERE published_year BETWEEN 2018 AND 2020` include?",
      "options": [
        { "id": "a", "text": "2018 and 2020 themselves, plus everything in between" },
        { "id": "b", "text": "Only 2019, since BETWEEN excludes both endpoints" },
        { "id": "c", "text": "Only years strictly greater than 2018 and less than 2020" },
        { "id": "d", "text": "2018 only" }
      ],
      "correct": "a",
      "explanation": "BETWEEN is inclusive on both ends — the years 2018 and 2020 themselves are included, not just the years strictly in between."
    },
    {
      "id": "filtering-q2",
      "type": "mcq",
      "prompt": "Which SQLite pattern-matching operator is case-sensitive by default?",
      "options": [
        { "id": "a", "text": "LIKE" },
        { "id": "b", "text": "GLOB" },
        { "id": "c", "text": "IN" },
        { "id": "d", "text": "BETWEEN" }
      ],
      "correct": "b",
      "explanation": "GLOB uses Unix shell-style wildcards and is case-sensitive; LIKE is case-insensitive for ASCII letters by default in SQLite."
    },
    {
      "id": "filtering-q3",
      "type": "sql",
      "prompt": "Write a query that returns every member's name and city, ordered by city ascending, then name ascending.",
      "starter": "SELECT",
      "solution": "SELECT name, city FROM members ORDER BY city ASC, name ASC;"
    }
  ]
}
```

## What's next

You can now ask for exactly the rows you want, in exactly the order you want. The next lesson covers **aggregation** — `COUNT`, `SUM`, `AVG`, and `GROUP BY` — for turning many rows into summary numbers.
$md$, 30, $json$[{"id":"filtering-q1","type":"mcq","correct":"a"},{"id":"filtering-q2","type":"mcq","correct":"b"},{"id":"filtering-q3","type":"sql"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('93920a9b-269f-5faa-a1db-0f48e98b8b7e', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does a WHERE clause do?', 'beginner', 1, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('1afd500e-fd6c-567c-8d19-b1ce81786e1e', '93920a9b-269f-5faa-a1db-0f48e98b8b7e', 1, $json${"prompt":"What does a WHERE clause do?","multiple":false,"options":[{"id":"a","text":"Sorts the result set","is_correct":false},{"id":"b","text":"Keeps only the rows where the condition evaluates to true","is_correct":true},{"id":"c","text":"Removes duplicate rows","is_correct":false},{"id":"d","text":"Renames a column in the output","is_correct":false}],"explanation":"WHERE filters rows before they're returned — only rows matching the condition make it into the result."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('125b2e31-31de-53e7-8e3a-5ab2fe3c6a80', '00000000-0000-0000-0000-000000000001', 'mcq', 'Given `SELECT title FROM books WHERE genre_id = 3 AND stock > 0;`, how many r...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('80856825-e2b7-5cd2-90f8-b18c13bab3c5', '125b2e31-31de-53e7-8e3a-5ab2fe3c6a80', 1, $json${"prompt":"Given `SELECT title FROM books WHERE genre_id = 3 AND stock \u003e 0;`, how many rows does this return? (Genre 3 has three books: Kingdom of Ash Roses with stock 0, The Last Alchemist with stock 1, and Ash Roses: The Sequel with stock 0.)","multiple":false,"options":[{"id":"a","text":"0","is_correct":false},{"id":"b","text":"1","is_correct":true},{"id":"c","text":"2","is_correct":false},{"id":"d","text":"3","is_correct":false}],"explanation":"AND requires both conditions to hold. Only The Last Alchemist is genre 3 AND has stock greater than 0 — the other two Fantasy titles are out of stock."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('57a9b49e-52da-557f-89e8-fe3053408e36', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why does `WHERE referred_by = NULL` always return zero rows, even though seve...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('02ea0215-9d52-5dec-824f-99e9c170d45f', '57a9b49e-52da-557f-89e8-fe3053408e36', 1, $json${"prompt":"Why does `WHERE referred_by = NULL` always return zero rows, even though several members have a NULL referred_by?","multiple":false,"options":[{"id":"a","text":"NULL comparisons always evaluate to unknown, not true, so WHERE never keeps the row — you need IS NULL instead","is_correct":true},{"id":"b","text":"referred_by is never actually NULL in the members table","is_correct":false},{"id":"c","text":"= NULL is invalid SQL syntax and the query fails to run","is_correct":false},{"id":"d","text":"NULL only works with the IN operator","is_correct":false},{"id":"e","text":"SQLite treats NULL as the number 0, which never matches an explicit NULL","is_correct":false}],"explanation":"NULL represents an unknown value, so any = comparison involving it is also unknown — never true. IS NULL / IS NOT NULL are the only correct way to test for it."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('fdd71073-a42e-58c1-a671-39c55af874ff', '00000000-0000-0000-0000-000000000001', 'mcq', 'Given `SELECT name, city FROM members WHERE city LIKE ''P_r%'';`, which members...', 'advanced', 3, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('12ccf7b6-be1f-50dd-907c-9fdd42ae8847', 'fdd71073-a42e-58c1-a671-39c55af874ff', 1, $json${"prompt":"Given `SELECT name, city FROM members WHERE city LIKE 'P_r%';`, which members are returned? (Cities in the data: Lisbon, Lagos, Paris, Mumbai, Stockholm, Kabul, Seoul, Osaka, Porto, Berlin.)","multiple":false,"options":[{"id":"a","text":"Only the member from Paris","is_correct":false},{"id":"b","text":"Only the member from Porto","is_correct":false},{"id":"c","text":"The members from Paris and Porto","is_correct":true},{"id":"d","text":"No members — the pattern doesn't match any city","is_correct":false}],"explanation":"'P_r%' means P, then exactly one character, then r, then anything. Both Paris (P-a-r-is) and Porto (P-o-r-to) fit — the underscore doesn't care what that middle letter is."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('3398bdf3-fb42-564c-b9a6-01680ee06a6e', '00000000-0000-0000-0000-000000000001', 'mcq', 'Is BETWEEN inclusive or exclusive of its two boundary values?', 'beginner', 1, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('607a10b5-4e99-5c06-a7ea-5a4435aa367b', '3398bdf3-fb42-564c-b9a6-01680ee06a6e', 1, $json${"prompt":"Is BETWEEN inclusive or exclusive of its two boundary values?","multiple":false,"options":[{"id":"a","text":"Inclusive — both boundary values are included in the match","is_correct":true},{"id":"b","text":"Exclusive — only values strictly between the boundaries match","is_correct":false},{"id":"c","text":"Inclusive of the lower bound only","is_correct":false},{"id":"d","text":"Inclusive of the upper bound only","is_correct":false}],"explanation":"BETWEEN 2018 AND 2020 matches 2018, 2019, and 2020 — both endpoints are included."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c98ef282-2ec4-5206-9c9e-5f21fad705e4', '00000000-0000-0000-0000-000000000001', 'mcq', 'In `ORDER BY genre_id ASC, price DESC`, what determines the final row order?', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('56fd8ffd-f7a4-5709-811a-374bde053235', 'c98ef282-2ec4-5206-9c9e-5f21fad705e4', 1, $json${"prompt":"In `ORDER BY genre_id ASC, price DESC`, what determines the final row order?","multiple":false,"options":[{"id":"a","text":"Only price DESC matters — genre_id is ignored","is_correct":false},{"id":"b","text":"Rows are sorted by genre_id ascending first; within each matching genre_id, price DESC breaks the tie","is_correct":true},{"id":"c","text":"The two columns are averaged together to produce a single sort key","is_correct":false},{"id":"d","text":"SQLite raises an error — ORDER BY only accepts one column","is_correct":false}],"explanation":"Multi-column ORDER BY sorts by the first column, then uses the next column(s) to break ties among rows that share the same value in the first."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('8d86744c-4b2d-52e3-93a4-8b26bd426ca9', '00000000-0000-0000-0000-000000000001', 'Quiz: Filtering & Sorting', 'sql-mastery-filtering-quiz', 'Quiz covering Filtering & Sorting.', 'mcq', 'published', 'module', 'd7d96d37-94e8-595d-8f1b-a71051b62112', 10, 70, 5, 11, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('c7058aa1-3c9f-5b39-a346-fae94050b7ae', '8d86744c-4b2d-52e3-93a4-8b26bd426ca9', '93920a9b-269f-5faa-a1db-0f48e98b8b7e', '1afd500e-fd6c-567c-8d19-b1ce81786e1e', 0, 1),
('4c4fee82-745a-58ec-9539-1cf0fe417f43', '8d86744c-4b2d-52e3-93a4-8b26bd426ca9', '125b2e31-31de-53e7-8e3a-5ab2fe3c6a80', '80856825-e2b7-5cd2-90f8-b18c13bab3c5', 1, 2),
('add5323d-5f2c-5633-8fda-e01b0b0fff94', '8d86744c-4b2d-52e3-93a4-8b26bd426ca9', '57a9b49e-52da-557f-89e8-fe3053408e36', '02ea0215-9d52-5dec-824f-99e9c170d45f', 2, 2),
('1773d1f4-062a-541d-a395-edf4482ea9a6', '8d86744c-4b2d-52e3-93a4-8b26bd426ca9', 'fdd71073-a42e-58c1-a671-39c55af874ff', '12ccf7b6-be1f-50dd-907c-9fdd42ae8847', 3, 3),
('ac6820f0-5557-55da-999c-e1dc916d9893', '8d86744c-4b2d-52e3-93a4-8b26bd426ca9', '3398bdf3-fb42-564c-b9a6-01680ee06a6e', '607a10b5-4e99-5c06-a7ea-5a4435aa367b', 4, 1),
('9cc26555-1771-519f-8b65-83a33fbfb89f', '8d86744c-4b2d-52e3-93a4-8b26bd426ca9', 'c98ef282-2ec4-5206-9c9e-5f21fad705e4', '56fd8ffd-f7a4-5709-811a-374bde053235', 5, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('d7d96d37-94e8-595d-8f1b-a71051b62112', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '0b221161-76a6-53d8-97fe-3b8d48a4d523', 'Quiz: Filtering & Sorting', 'assessment', 1, 10, '8d86744c-4b2d-52e3-93a4-8b26bd426ca9')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Aggregation
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('9e77b8f4-1f70-5617-a4bc-37d4711c0a5c', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'Aggregation', 3)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('83058bf6-1aac-56a9-b00b-879371fbe42e', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '9e77b8f4-1f70-5617-a4bc-37d4711c0a5c', 'Aggregate Functions and GROUP BY', 'notes', 0, $md$Filtering picks rows. **Aggregation** turns many rows into a single summary number — "how many books do we have," "what's the average price," "how many books per genre." That last kind of question needs `GROUP BY`, which is where aggregation gets genuinely powerful.

## Aggregate functions: COUNT, MIN, MAX, AVG, SUM

An aggregate function takes a whole column of values and collapses it into one. `COUNT(*)` counts rows:

```sql-try
SELECT COUNT(*) AS total_books
FROM books;
```

`total_books` comes back as `15` — one row, one number, no matter how many rows `books` actually has.

`MIN`, `MAX`, and `AVG` work the same way, just doing something different with the numbers. You can combine several in one query, and — as with any expression — give each result a readable name with `AS`:

```sql-try
SELECT MIN(price) AS cheapest, MAX(price) AS priciest, AVG(price) AS avg_price
FROM books;
```

`cheapest` is `8.75` (*Nobody's Almanac*), `priciest` is `22.50` (*Watanabe: A Life*), and `avg_price` comes out to `14.988` — the 15 prices sum to $224.82, divided by 15 books. Without the `AS` aliases, you'd get unreadable default column names like `MIN(price)`.

## GROUP BY: aggregating per category

`COUNT(*)` over the whole table is useful, but "how many books *per genre*" is a more common real question. `GROUP BY` splits the rows into buckets by a column's value, then runs the aggregate separately on each bucket:

```sql-try
SELECT genre_id, COUNT(*) AS num_books, ROUND(SUM(price), 2) AS total_value
FROM books
GROUP BY genre_id
ORDER BY genre_id;
```

Six rows come back, one per genre — genre 1 (Fiction) has 4 books worth $46.23 combined, genre 2 (Science Fiction) has 2 books worth $30.25, and so on down to genre 6 (Biography) with 2 books worth $43.50. Every row in `SELECT` that isn't wrapped in an aggregate function — here, `genre_id` — has to be the thing you're grouping by; that's what makes each output row unambiguous.

## HAVING: filtering groups, not rows

`WHERE` filters individual rows *before* grouping happens. If you want to filter based on the result of an aggregate — like "only genres with more than 2 books" — `WHERE` can't do that, because `COUNT(*)` doesn't exist yet at the point `WHERE` runs. `HAVING` filters *after* grouping, so it can reference the aggregate directly:

```sql-try
SELECT genre_id, COUNT(*) AS num_books
FROM books
GROUP BY genre_id
HAVING COUNT(*) > 2
ORDER BY genre_id;
```

Only two genres clear the bar: genre 1 (Fiction) with 4 books, and genre 3 (Fantasy) with 3. The other four genres — each with only 2 books — get filtered out, but only *after* `COUNT(*)` was computed for all six.

The rule of thumb: `WHERE` filters rows going *into* the group, `HAVING` filters groups *after* they've been formed. You can use both in the same query — `WHERE` to narrow the rows first, `HAVING` to narrow the resulting groups second.

## COUNT(*) vs COUNT(column): NULLs get skipped

`COUNT(*)` counts rows, full stop — it doesn't look at any particular column, so `NULL` values can't hide from it. `COUNT(column)` is different: it counts only the rows where that column is **not** `NULL`. Nothing in `books` has a `NULL` price, so to see the difference, look at `members.referred_by`, which is `NULL` for five members:

```sql-try
SELECT COUNT(*) AS total_members, COUNT(referred_by) AS members_with_referrer
FROM members;
```

`total_members` comes back as `10` — every row counts. `members_with_referrer` is only `5` — `COUNT(referred_by)` skips the five rows where `referred_by` is `NULL`. This is a common source of confusion when someone writes `COUNT(some_column)` expecting a plain row count and gets a smaller number back, simply because that column happens to have gaps.

## Grouping by multiple columns

`GROUP BY` isn't limited to one column — group by two, and SQLite forms one bucket per unique *combination* of both values:

```sql-try
SELECT author_id, genre_id, COUNT(*) AS num_books
FROM books
GROUP BY author_id, genre_id
ORDER BY author_id, genre_id;
```

Each row in the result is a distinct `(author_id, genre_id)` pair — most authors only wrote in one genre here, so most groups show `num_books = 1`, but grouping this way would immediately surface it if any author had written, say, three Fantasy books and one Mystery book: that would show up as two separate rows for that author, not one merged row. The rule from the single-column case still holds: every non-aggregated column in `SELECT` must appear in `GROUP BY`.

## Knowledge check

Answer all three questions correctly to unlock **Mark as Complete** for this lesson. Every attempt is recorded.

```knowledge-check
{
  "questions": [
    {
      "id": "aggregation-q1",
      "type": "mcq",
      "prompt": "members.referred_by is NULL for 5 of the 10 members. What does COUNT(referred_by) return, versus COUNT(*)?",
      "options": [
        { "id": "a", "text": "COUNT(*) returns 10 (every row); COUNT(referred_by) returns 5 (NULLs skipped)" },
        { "id": "b", "text": "Both return 10, since COUNT never skips NULLs" },
        { "id": "c", "text": "Both return 5, since COUNT always ignores NULL rows entirely" },
        { "id": "d", "text": "COUNT(referred_by) errors out because the column contains NULL" }
      ],
      "correct": "a",
      "explanation": "COUNT(*) counts rows regardless of column contents. COUNT(column) only counts rows where that specific column is not NULL."
    },
    {
      "id": "aggregation-q2",
      "type": "mcq",
      "prompt": "Why does WHERE COUNT(*) > 2 fail, when HAVING COUNT(*) > 2 works, for filtering genres by book count?",
      "options": [
        { "id": "a", "text": "WHERE filters rows before GROUP BY runs, so the aggregate doesn't exist yet; HAVING filters after grouping" },
        { "id": "b", "text": "WHERE and HAVING are fully interchangeable in SQLite" },
        { "id": "c", "text": "COUNT(*) can only appear in a SELECT list, never in any filter clause" },
        { "id": "d", "text": "HAVING is only valid when ORDER BY is also present" }
      ],
      "correct": "a",
      "explanation": "WHERE runs before grouping/aggregation, so it can't reference an aggregate result. HAVING runs after GROUP BY, once aggregates like COUNT(*) have been computed."
    },
    {
      "id": "aggregation-q3",
      "type": "sql",
      "prompt": "Write a query that shows each genre_id with the average price of its books, rounded to 2 decimal places, ordered by genre_id.",
      "starter": "SELECT",
      "solution": "SELECT genre_id, ROUND(AVG(price), 2) AS avg_price FROM books GROUP BY genre_id ORDER BY genre_id;"
    }
  ]
}
```

## What's next

You can now summarize data at any granularity — the whole table, or per category. The next lesson covers **joins** — pulling related rows together from `books`, `authors`, `genres`, `members`, and `loans` in a single query.
$md$, 25, $json$[{"id":"aggregation-q1","type":"mcq","correct":"a"},{"id":"aggregation-q2","type":"mcq","correct":"a"},{"id":"aggregation-q3","type":"sql"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('707522fd-8d79-5f6a-8773-07883ead30b2', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does `SELECT COUNT(*) FROM books;` return, given the library has 15 books?', 'beginner', 1, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('15ca628e-4311-56ef-b5e3-90bd7b24ac82', '707522fd-8d79-5f6a-8773-07883ead30b2', 1, $json${"prompt":"What does `SELECT COUNT(*) FROM books;` return, given the library has 15 books?","multiple":false,"options":[{"id":"a","text":"15 rows, each with the value 1","is_correct":false},{"id":"b","text":"One row with the single value 15","is_correct":true},{"id":"c","text":"The value 15 repeated for every column","is_correct":false},{"id":"d","text":"An error, because COUNT requires a column name","is_correct":false}],"explanation":"COUNT(*) collapses the whole table into a single summary row containing the row count."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('8f1d4599-87ce-5549-abb5-343acedcbd61', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why can''t `WHERE COUNT(*) > 2` be used to keep only genres with more than 2 b...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('1318a667-3c3d-5ba4-a794-64584e59f0aa', '8f1d4599-87ce-5549-abb5-343acedcbd61', 1, $json${"prompt":"Why can't `WHERE COUNT(*) \u003e 2` be used to keep only genres with more than 2 books, while `HAVING COUNT(*) \u003e 2` works?","multiple":false,"options":[{"id":"a","text":"WHERE runs before grouping happens, so the aggregate COUNT(*) doesn't exist yet at that point — HAVING runs after grouping and can reference it","is_correct":true},{"id":"b","text":"WHERE and HAVING are just two different names for the exact same clause","is_correct":false},{"id":"c","text":"COUNT(*) can only ever be used in a SELECT list, never in a filter","is_correct":false},{"id":"d","text":"WHERE only works on TEXT columns, not on aggregate results","is_correct":false}],"explanation":"WHERE filters individual rows before GROUP BY runs. HAVING filters the groups that GROUP BY produces, so it's the only clause that can test an aggregate's result."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('cc457641-c638-55c8-bcd1-c3b0a2d87a1b', '00000000-0000-0000-0000-000000000001', 'mcq', 'Given `SELECT genre_id, COUNT(*) AS num_books FROM books GROUP BY genre_id HA...', 'advanced', 3, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('9db6cfef-f3a4-5dcb-91fe-c178f79aa54d', 'cc457641-c638-55c8-bcd1-c3b0a2d87a1b', 1, $json${"prompt":"Given `SELECT genre_id, COUNT(*) AS num_books FROM books GROUP BY genre_id HAVING COUNT(*) \u003e 2;` — the library has 4 Fiction books, 2 Science Fiction, 3 Fantasy, 2 Mystery, 2 Non-Fiction, and 2 Biography — how many rows does this return?","multiple":false,"options":[{"id":"a","text":"6 — one for every genre","is_correct":false},{"id":"b","text":"2 — Fiction (4 books) and Fantasy (3 books)","is_correct":true},{"id":"c","text":"1 — only Fiction, the largest genre","is_correct":false},{"id":"d","text":"0 — no genre has more than 2 books","is_correct":false}],"explanation":"Only Fiction (4) and Fantasy (3) have more than 2 books; the other four genres, each with exactly 2, are filtered out by HAVING."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b23daebf-fae1-51d1-83af-0c6dd36de1d4', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which book does `SELECT title FROM books ORDER BY price DESC LIMIT 1;` return...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('76b2e127-1289-599b-8ff3-188b7d78383b', 'b23daebf-fae1-51d1-83af-0c6dd36de1d4', 1, $json${"prompt":"Which book does `SELECT title FROM books ORDER BY price DESC LIMIT 1;` return, and how does that relate to MAX(price)?","multiple":false,"options":[{"id":"a","text":"Nobody's Almanac — it returns the cheapest book, same as MIN(price)","is_correct":false},{"id":"b","text":"Watanabe: A Life — it returns the book at the highest price, the same value MAX(price) would compute","is_correct":true},{"id":"c","text":"The Last Alchemist — a random book with no relation to price","is_correct":false},{"id":"d","text":"It returns all 15 books sorted by price","is_correct":false}],"explanation":"Watanabe: A Life is priced at $22.50, the highest in the table — sorting descending and taking the top row is one way to find the same book MAX(price) would identify by value alone."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('886427e1-cde7-527e-81b3-b3169c157ace', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why use `AS` on an aggregate like `COUNT(*) AS total_books` instead of leavin...', 'beginner', 1, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('649e6f93-62a5-54cb-8255-ca40f644b0cd', '886427e1-cde7-527e-81b3-b3169c157ace', 1, $json${"prompt":"Why use `AS` on an aggregate like `COUNT(*) AS total_books` instead of leaving it unnamed?","multiple":false,"options":[{"id":"a","text":"AS is required by SQLite syntax — an unnamed aggregate causes an error","is_correct":false},{"id":"b","text":"Without it, the output column has an unreadable default name like COUNT(*) instead of a clear label","is_correct":true},{"id":"c","text":"AS changes the aggregate's calculation, not just its label","is_correct":false},{"id":"d","text":"AS is only valid on TEXT columns, not on numeric aggregate results","is_correct":false}],"explanation":"AS just renames the output column. It's optional, but without it you're stuck reading raw expressions like COUNT(*) or AVG(price) as column headers."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('de050e4d-ee61-51cb-87cd-f983441df3bf', '00000000-0000-0000-0000-000000000001', 'Quiz: Aggregation', 'sql-mastery-aggregation-quiz', 'Quiz covering Aggregation.', 'mcq', 'published', 'module', 'e7f8c830-99e7-5672-828e-076eeb001c7a', 10, 70, 5, 9, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('49e819ce-9e7a-5571-afe5-69b5571a9cff', 'de050e4d-ee61-51cb-87cd-f983441df3bf', '707522fd-8d79-5f6a-8773-07883ead30b2', '15ca628e-4311-56ef-b5e3-90bd7b24ac82', 0, 1),
('eeef248d-19bc-52ac-bb71-6d5e53bbe037', 'de050e4d-ee61-51cb-87cd-f983441df3bf', '8f1d4599-87ce-5549-abb5-343acedcbd61', '1318a667-3c3d-5ba4-a794-64584e59f0aa', 1, 2),
('71c9cf7c-a586-56ff-a9f1-7b9b3831bb72', 'de050e4d-ee61-51cb-87cd-f983441df3bf', 'cc457641-c638-55c8-bcd1-c3b0a2d87a1b', '9db6cfef-f3a4-5dcb-91fe-c178f79aa54d', 2, 3),
('b07ba06c-6cd4-5fae-bc16-417a12eefe81', 'de050e4d-ee61-51cb-87cd-f983441df3bf', 'b23daebf-fae1-51d1-83af-0c6dd36de1d4', '76b2e127-1289-599b-8ff3-188b7d78383b', 3, 2),
('aa127d93-c5d5-582a-aa5a-59a4baef2cf1', 'de050e4d-ee61-51cb-87cd-f983441df3bf', '886427e1-cde7-527e-81b3-b3169c157ace', '649e6f93-62a5-54cb-8255-ca40f644b0cd', 4, 1)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('e7f8c830-99e7-5672-828e-076eeb001c7a', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '9e77b8f4-1f70-5617-a4bc-37d4711c0a5c', 'Quiz: Aggregation', 'assessment', 1, 10, 'de050e4d-ee61-51cb-87cd-f983441df3bf')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Joining Tables
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('8f22fa33-bfba-53e7-bd87-383159ceb34a', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'Joining Tables', 4)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('66199163-0731-5e44-9f9e-4f489f8fae47', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '8f22fa33-bfba-53e7-bd87-383159ceb34a', 'Joining Tables: INNER, LEFT, RIGHT, FULL OUTER, and Self Joins', 'notes', 0, $md$Everything so far has queried one table at a time. But `books.author_id` only makes sense next to `authors.id`, and `loans.book_id` only makes sense next to `books.id` — the useful questions live *across* tables. A `JOIN` combines rows from two tables based on a matching condition, usually a foreign key.

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
$md$, 30, $json$[{"id":"joins-q1","type":"mcq","correct":"b"},{"id":"joins-q2","type":"mcq","correct":"a"},{"id":"joins-q3","type":"sql"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('30a309b7-4622-57d0-9e0d-66e4e5eb4d6a', '00000000-0000-0000-0000-000000000001', 'mcq', 'What''s the key difference between INNER JOIN and LEFT JOIN?', 'beginner', 1, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c8c7b6f1-b908-5e11-8022-d365e0b96baa', '30a309b7-4622-57d0-9e0d-66e4e5eb4d6a', 1, $json${"prompt":"What's the key difference between INNER JOIN and LEFT JOIN?","multiple":false,"options":[{"id":"a","text":"INNER JOIN only returns rows with a match in both tables; LEFT JOIN keeps every row from the left table even without a match","is_correct":true},{"id":"b","text":"INNER JOIN is faster but returns identical results to LEFT JOIN in every case","is_correct":false},{"id":"c","text":"LEFT JOIN can only be used with two columns of the same name","is_correct":false},{"id":"d","text":"INNER JOIN keeps unmatched rows; LEFT JOIN discards them","is_correct":false}],"explanation":"INNER JOIN drops any row lacking a match on either side. LEFT JOIN always keeps every left-table row, filling unmatched right-side columns with NULL."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('4eb9343b-f8fa-5921-a31f-248221e5e22c', '00000000-0000-0000-0000-000000000001', 'mcq', '`SELECT b.title FROM books b LEFT JOIN loans l ON b.id = l.book_id WHERE l.id...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a6da6233-d53b-5c55-84ee-5695ad33cafc', '4eb9343b-f8fa-5921-a31f-248221e5e22c', 1, $json${"prompt":"`SELECT b.title FROM books b LEFT JOIN loans l ON b.id = l.book_id WHERE l.id IS NULL;` — what does this return?","multiple":false,"options":[{"id":"a","text":"Every book that has been loaned at least once","is_correct":false},{"id":"b","text":"Every book that has never been loaned","is_correct":true},{"id":"c","text":"Every loan that has no matching book","is_correct":false},{"id":"d","text":"An error, because WHERE can't reference a joined column","is_correct":false}],"explanation":"LEFT JOIN keeps every book even without a loan match, producing NULL loan columns for unmatched books. Filtering to l.id IS NULL isolates exactly the books with zero loans."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('0f977804-0849-5834-988b-edb1c573e80f', '00000000-0000-0000-0000-000000000001', 'mcq', 'Using a self join on members (m.referred_by = r.id), who referred Hiro Tanaka...', 'advanced', 3, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('7cb67e64-b8f9-5e43-a6f6-04351e8ac791', '0f977804-0849-5834-988b-edb1c573e80f', 1, $json${"prompt":"Using a self join on members (m.referred_by = r.id), who referred Hiro Tanaka? (Hiro Tanaka's referred_by points at member id 7.)","multiple":false,"options":[{"id":"a","text":"Ana Torres","is_correct":false},{"id":"b","text":"Chloe Martin","is_correct":false},{"id":"c","text":"Grace Kim","is_correct":true},{"id":"d","text":"No one — Hiro Tanaka joined with no referrer","is_correct":false}],"explanation":"Member id 7 is Grace Kim, so Hiro Tanaka's referred_by (7) resolves to Grace Kim in the self join."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('b3bf3b25-1950-5228-baa7-dec1cecf1d08', '00000000-0000-0000-0000-000000000001', 'mcq', 'MySQL has historically had no native FULL OUTER JOIN. What''s the standard wor...', 'advanced', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2674915a-c1e8-55af-8b49-69a3e83df1fa', 'b3bf3b25-1950-5228-baa7-dec1cecf1d08', 1, $json${"prompt":"MySQL has historically had no native FULL OUTER JOIN. What's the standard workaround?","multiple":false,"options":[{"id":"a","text":"A LEFT JOIN combined with a RIGHT JOIN (or a mirrored LEFT JOIN), combined with UNION to de-duplicate overlapping rows","is_correct":true},{"id":"b","text":"MySQL simply cannot express a full outer join under any circumstances","is_correct":false},{"id":"c","text":"Running the query twice and manually merging the results in application code","is_correct":false},{"id":"d","text":"Using INNER JOIN with an extra WHERE clause","is_correct":false}],"explanation":"A LEFT JOIN unions with a RIGHT JOIN (or a second LEFT JOIN with tables swapped) reproduces FULL OUTER JOIN behavior, with UNION removing the rows both sides already agree on."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('1c245756-255e-53a8-a5ff-6fb7683b154d', '00000000-0000-0000-0000-000000000001', 'mcq', 'What''s the difference between UNION and UNION ALL?', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('a7d62366-4276-520c-b26b-642eb9e8df9e', '1c245756-255e-53a8-a5ff-6fb7683b154d', 1, $json${"prompt":"What's the difference between UNION and UNION ALL?","multiple":false,"options":[{"id":"a","text":"UNION requires the two SELECTs to query the same table; UNION ALL does not","is_correct":false},{"id":"b","text":"UNION removes duplicate rows that appear in both result sets; UNION ALL keeps every row, duplicates included","is_correct":true},{"id":"c","text":"UNION ALL is only valid inside a subquery","is_correct":false},{"id":"d","text":"UNION sorts the combined result; UNION ALL does not","is_correct":false}],"explanation":"UNION de-duplicates the combined rows; UNION ALL skips that step entirely, so it's both faster and keeps duplicates."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5b3d1cea-0ab3-58dd-bc87-4d81e95e65d5', '00000000-0000-0000-0000-000000000001', 'mcq', 'Amara Diallo (author_id 3) wrote exactly the three Fantasy (genre_id 3) books...', 'advanced', 3, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('3323ff07-d8cf-5895-8d4c-5138a78f8b1c', '5b3d1cea-0ab3-58dd-bc87-4d81e95e65d5', 1, $json${"prompt":"Amara Diallo (author_id 3) wrote exactly the three Fantasy (genre_id 3) books in the library — no more, no less. How many rows does `SELECT title FROM books WHERE author_id = 3 UNION ALL SELECT title FROM books WHERE genre_id = 3;` return?","multiple":false,"options":[{"id":"a","text":"3 — UNION ALL always de-duplicates","is_correct":false},{"id":"b","text":"6 — each of the three titles appears twice, once from each SELECT","is_correct":true},{"id":"c","text":"0 — the two conditions never overlap","is_correct":false},{"id":"d","text":"9 — because author_id and genre_id together match nine books","is_correct":false}],"explanation":"Since every author-3 book is also a genre-3 book, both SELECTs produce the same three titles. UNION ALL doesn't remove duplicates, so all six rows come back — 3 + 3."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('689c5110-4097-53f8-9d5f-f16a9521636d', '00000000-0000-0000-0000-000000000001', 'Quiz: Joining Tables', 'sql-mastery-joins-quiz', 'Quiz covering Joining Tables.', 'mcq', 'published', 'module', '8da41f22-2066-58f5-aab4-f31f234105d0', 10, 70, 5, 13, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('704382a7-3a6a-5c9d-a8b7-c1d5e9811a91', '689c5110-4097-53f8-9d5f-f16a9521636d', '30a309b7-4622-57d0-9e0d-66e4e5eb4d6a', 'c8c7b6f1-b908-5e11-8022-d365e0b96baa', 0, 1),
('42b3b499-59cd-595c-ac1a-84aea5bb3599', '689c5110-4097-53f8-9d5f-f16a9521636d', '4eb9343b-f8fa-5921-a31f-248221e5e22c', 'a6da6233-d53b-5c55-84ee-5695ad33cafc', 1, 2),
('11ea1abc-ea1a-511e-8eb1-cdb64264cc99', '689c5110-4097-53f8-9d5f-f16a9521636d', '0f977804-0849-5834-988b-edb1c573e80f', '7cb67e64-b8f9-5e43-a6f6-04351e8ac791', 2, 3),
('11415461-695d-5d6a-bfcd-e33e0ac7e83d', '689c5110-4097-53f8-9d5f-f16a9521636d', 'b3bf3b25-1950-5228-baa7-dec1cecf1d08', '2674915a-c1e8-55af-8b49-69a3e83df1fa', 3, 2),
('dc34ca73-84f0-5811-9cea-a97f967ee3e7', '689c5110-4097-53f8-9d5f-f16a9521636d', '1c245756-255e-53a8-a5ff-6fb7683b154d', 'a7d62366-4276-520c-b26b-642eb9e8df9e', 4, 2),
('eb5e654d-4715-5517-9e56-165d02f4468b', '689c5110-4097-53f8-9d5f-f16a9521636d', '5b3d1cea-0ab3-58dd-bc87-4d81e95e65d5', '3323ff07-d8cf-5895-8d4c-5138a78f8b1c', 5, 3)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('8da41f22-2066-58f5-aab4-f31f234105d0', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '8f22fa33-bfba-53e7-bd87-383159ceb34a', 'Quiz: Joining Tables', 'assessment', 1, 10, '689c5110-4097-53f8-9d5f-f16a9521636d')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('fdb6648e-4b12-5338-a474-651f865c550b', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '8f22fa33-bfba-53e7-bd87-383159ceb34a', 'Notes: CROSS JOIN — the One Join Type the Main Lesson Skipped', 'notes', 2, $md$The main lesson covered `INNER`, `LEFT`, `RIGHT`, `FULL OUTER`, and self joins — every join that matches rows by a condition. `CROSS JOIN` is different: it has no matching condition at all.

## What CROSS JOIN returns

`CROSS JOIN` pairs **every row of the left table with every row of the right table** — the full Cartesian product, with no `ON` clause needed or allowed:

```sql-try
SELECT g.name AS genre, m.name AS member
FROM genres g
CROSS JOIN members m
LIMIT 10;
```

With 5 genres and 10 members, the full (unlimited) result would be 50 rows — every genre paired with every member, regardless of whether that member has ever borrowed a book in that genre. Compare that to an `INNER JOIN`, which only returns rows where a condition actually matches: `CROSS JOIN` returns rows where *nothing* has to match, because there's nothing to check.

## Why it's rarely what you want by accident

`CROSS JOIN` is the join you get from `FROM a, b` with no `WHERE` linking them — a classic bug, not a classic query. Forgetting a join condition doesn't error out; it silently multiplies your row count (rows in `a` × rows in `b`), which is why an unexpectedly huge result set is a common symptom of a missing `ON`/`WHERE` clause rather than a real `CROSS JOIN`.

## Where it's genuinely useful

`CROSS JOIN` earns its place when you deliberately want every combination — generating a full grid rather than matching existing relationships. A common real case: building a report template that should show every genre for every month, even genre/month pairs with zero loans, rather than only the combinations that happen to appear in the data:

```sql-try
SELECT g.name AS genre, m.city
FROM genres g
CROSS JOIN (SELECT DISTINCT city FROM members) m
ORDER BY g.name, m.city;
```

This produces one row per genre/city combination that exists in the data — a complete grid, ready to be left-joined against actual loan counts so combinations with zero activity still show up as `0` instead of being missing from the report entirely.

## Key takeaways

- `CROSS JOIN` has no `ON` clause — it returns the Cartesian product, every left row paired with every right row.
- Row count multiplies: N rows × M rows = N×M rows, which is why an accidental `CROSS JOIN` (a missing join condition) is a common source of exploded result sets.
- Deliberate use case: generating a complete combination grid (every category × every period) to left-join real data against, so empty combinations still appear instead of being silently absent.
$md$, 10, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('4269e709-e3fe-59b9-a226-f1b10bb9db0a', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '8f22fa33-bfba-53e7-bd87-383159ceb34a', 'Notes: EXCEPT and INTERSECT — the Set Operators UNION Left Out', 'notes', 3, $md$The main lesson covered `UNION` and `UNION ALL` for stacking result sets. Two more set operators follow the exact same rule (same column count, compatible types) but ask a different question than "combine everything."

## INTERSECT: rows in both queries

```sql-try
SELECT member_id FROM loans WHERE loan_date < '2024-06-01'
INTERSECT
SELECT member_id FROM loans WHERE loan_date >= '2024-06-01';
```

Returns only the member ids that appear in **both** halves — members who borrowed something before June 2024 *and* borrowed something after. Not a `JOIN`: there's no row-pairing, just two independent row sets reduced to their overlap.

## EXCEPT: rows in the first query but not the second

```sql-try
SELECT member_id FROM members
EXCEPT
SELECT member_id FROM loans;
```

Returns member ids from `members` that never show up in `loans` at all — members who have never borrowed a book. This is a set-operator alternative to the `NOT EXISTS`/anti-join pattern from the advanced-queries and interview-ready lessons; same answer, different mechanism. `EXCEPT` is order-sensitive: `A EXCEPT B` (rows in A missing from B) is not the same as `B EXCEPT A`.

(MySQL doesn't support `EXCEPT`/`INTERSECT` before 8.0.31 — `NOT EXISTS`/`EXISTS` is the portable version interviewers usually want anyway. SQLite and PostgreSQL support both directly, as used here.)

## Key takeaways

- `INTERSECT` = rows returned by both queries. `EXCEPT` = rows in the first query with no match in the second.
- Both dedupe automatically, like `UNION` (no `ALL` variant needed for the common case).
- `EXCEPT` for "never happened" questions is equivalent to `NOT EXISTS`/anti-join — know both, since `EXCEPT` support varies more across engines.
$md$, 10, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Modifying Data
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('fad91ed3-1863-541b-98fe-5ebb27565bc7', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'Modifying Data', 5)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('8cb03e01-4ff9-5863-b252-6d60abdd18ee', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'fad91ed3-1863-541b-98fe-5ebb27565bc7', 'INSERT, UPDATE, DELETE — Changing the Data', 'notes', 0, $md$Every lesson so far has only *read* data with `SELECT`. Real applications also need to write it — adding new rows, correcting existing ones, and removing rows that shouldn't be there anymore. That's `INSERT`, `UPDATE`, and `DELETE`, together known as **DML** (Data Manipulation Language).

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
$md$, 30, $json$[{"id":"modifying-data-q1","type":"mcq","correct":"c"},{"id":"modifying-data-q2","type":"mcq","correct":"b"},{"id":"modifying-data-q3","type":"sql"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5cfb48b4-721b-5fb5-980c-25262fb2e4ef', '00000000-0000-0000-0000-000000000001', 'mcq', 'What must be true for `INSERT INTO genres VALUES (101, ''Poetry'');` (no column...', 'beginner', 1, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('7caeedb7-9f83-58f3-aae6-403c97dfc7d1', '5cfb48b4-721b-5fb5-980c-25262fb2e4ef', 1, $json${"prompt":"What must be true for `INSERT INTO genres VALUES (101, 'Poetry');` (no column list) to work?","multiple":false,"options":[{"id":"a","text":"Nothing extra — INSERT always works without a column list","is_correct":false},{"id":"b","text":"The values must be supplied for every column, in the exact order the table was created with","is_correct":true},{"id":"c","text":"The table must have exactly one column","is_correct":false},{"id":"d","text":"You must run CREATE TABLE again first","is_correct":false}],"explanation":"The full-row form skips naming columns, but that only works if you provide a value for every column in the table's declared order — otherwise SQLite either errors or misassigns values."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('562ba116-4b55-5cc7-a41c-c20c2a9340ac', '00000000-0000-0000-0000-000000000001', 'mcq', 'What happens if you run `UPDATE books SET stock = 0;` with no WHERE clause?', 'beginner', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('b366e06b-1f6e-5879-9f2f-aa0be8f9fe4b', '562ba116-4b55-5cc7-a41c-c20c2a9340ac', 1, $json${"prompt":"What happens if you run `UPDATE books SET stock = 0;` with no WHERE clause?","multiple":false,"options":[{"id":"a","text":"SQLite rejects the statement because WHERE is required","is_correct":false},{"id":"b","text":"Only the first row is updated","is_correct":false},{"id":"c","text":"Every row in the books table gets stock set to 0","is_correct":true},{"id":"d","text":"Nothing happens until you add a WHERE clause afterward","is_correct":false}],"explanation":"UPDATE without WHERE applies to every row in the table — one of the most common and costly mistakes in SQL. Always double-check your WHERE clause before running an UPDATE."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('66da2c2b-196e-517b-9b76-adc2db870bd1', '00000000-0000-0000-0000-000000000001', 'mcq', 'Starting from the original seed data, what is book id 9''s stock after running...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('09dcb1ff-d24b-502d-9f5c-e7dc51c4db32', '66da2c2b-196e-517b-9b76-adc2db870bd1', 1, $json${"prompt":"Starting from the original seed data, what is book id 9's stock after running `UPDATE books SET stock = stock + 5 WHERE id = 9;`?","multiple":false,"options":[{"id":"a","text":"0","is_correct":false},{"id":"b","text":"5","is_correct":true},{"id":"c","text":"9","is_correct":false},{"id":"d","text":"NULL","is_correct":false}],"explanation":"Book id 9 (Cold Case: Reykjavik) starts at stock = 0 in the seed data. stock + 5 evaluates against the current value, so the new stock is 5."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('32c6891d-60ee-5a4a-a940-420aedde898d', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does `DELETE FROM loans;` (no WHERE clause) do?', 'beginner', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('2d1e3a7a-88aa-5071-95f8-8ccb7a2d2a52', '32c6891d-60ee-5a4a-a940-420aedde898d', 1, $json${"prompt":"What does `DELETE FROM loans;` (no WHERE clause) do?","multiple":false,"options":[{"id":"a","text":"Deletes only loans with a NULL return_date","is_correct":false},{"id":"b","text":"Deletes every row in the loans table","is_correct":true},{"id":"c","text":"Deletes the loans table itself, including its structure","is_correct":false},{"id":"d","text":"Fails with a syntax error","is_correct":false}],"explanation":"DELETE without WHERE removes every row in the table — but unlike DROP TABLE, the table itself and its structure still exist afterward, just empty."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('015c1153-c111-5e92-b0c8-737377e6827c', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does `INSERT INTO ... SELECT ...` let you do that a plain `INSERT INTO ....', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('68b0ae1a-55ca-5a6c-837c-03fcb9eb3a5d', '015c1153-c111-5e92-b0c8-737377e6827c', 1, $json${"prompt":"What does `INSERT INTO ... SELECT ...` let you do that a plain `INSERT INTO ... VALUES ...` can't?","multiple":false,"options":[{"id":"a","text":"Insert rows whose values are computed from an existing query, row by row, instead of being typed as literals","is_correct":true},{"id":"b","text":"Insert into more than one table at once","is_correct":false},{"id":"c","text":"Skip the CHECK constraints on the target table","is_correct":false},{"id":"d","text":"Insert rows without specifying a table name","is_correct":false}],"explanation":"INSERT INTO ... SELECT takes each row produced by the SELECT and inserts it — letting you copy, filter, and transform existing data into new rows in a single statement."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c9e25ddc-6d0f-5d06-b0c0-31e1499b15ce', '00000000-0000-0000-0000-000000000001', 'mcq', 'How many rows does this insert against the original seed data?

```sql
INSERT...', 'advanced', 3, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5cf22135-c6c8-50d2-9f0b-d9a0f04780fe', 'c9e25ddc-6d0f-5d06-b0c0-31e1499b15ce', 1, $json${"prompt":"How many rows does this insert against the original seed data?\n\n```sql\nINSERT INTO books (id, title, author_id, genre_id, price, published_year, stock)\nSELECT id + 200, title || ' (Reprint)', author_id, genre_id, price, published_year, 10\nFROM books\nWHERE stock = 0;\n```","multiple":false,"options":[{"id":"a","text":"0","is_correct":false},{"id":"b","text":"1","is_correct":false},{"id":"c","text":"3","is_correct":true},{"id":"d","text":"15","is_correct":false}],"explanation":"Three books in the seed data have stock = 0 (Kingdom of Ash Roses, Cold Case: Reykjavik, and Ash Roses: The Sequel), so the SELECT produces three rows and three new books get inserted."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('51d523fe-1a20-5f00-9512-a5dbd0f6c07e', '00000000-0000-0000-0000-000000000001', 'Quiz: Modifying Data', 'sql-mastery-modifying-data-quiz', 'Quiz covering Modifying Data.', 'mcq', 'published', 'module', 'e993e43a-e47e-55ba-8919-e6d1b4201a46', 10, 70, 5, 12, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('d9014cef-44e1-52cc-98b8-07d933659290', '51d523fe-1a20-5f00-9512-a5dbd0f6c07e', '5cfb48b4-721b-5fb5-980c-25262fb2e4ef', '7caeedb7-9f83-58f3-aae6-403c97dfc7d1', 0, 1),
('3937ad02-6343-5562-ba0e-ce764ef04566', '51d523fe-1a20-5f00-9512-a5dbd0f6c07e', '562ba116-4b55-5cc7-a41c-c20c2a9340ac', 'b366e06b-1f6e-5879-9f2f-aa0be8f9fe4b', 1, 2),
('dacc7341-d998-5df7-af70-1f8a33bd9616', '51d523fe-1a20-5f00-9512-a5dbd0f6c07e', '66da2c2b-196e-517b-9b76-adc2db870bd1', '09dcb1ff-d24b-502d-9f5c-e7dc51c4db32', 2, 2),
('d0296a2b-8cae-5351-90a6-7e33e134e1fa', '51d523fe-1a20-5f00-9512-a5dbd0f6c07e', '32c6891d-60ee-5a4a-a940-420aedde898d', '2d1e3a7a-88aa-5071-95f8-8ccb7a2d2a52', 3, 2),
('270df40a-36c0-5879-981d-1110a3b70b67', '51d523fe-1a20-5f00-9512-a5dbd0f6c07e', '015c1153-c111-5e92-b0c8-737377e6827c', '68b0ae1a-55ca-5a6c-837c-03fcb9eb3a5d', 4, 2),
('03ac85dd-f0cd-5c60-b7b9-14a99ce44865', '51d523fe-1a20-5f00-9512-a5dbd0f6c07e', 'c9e25ddc-6d0f-5d06-b0c0-31e1499b15ce', '5cf22135-c6c8-50d2-9f0b-d9a0f04780fe', 5, 3)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('e993e43a-e47e-55ba-8919-e6d1b4201a46', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'fad91ed3-1863-541b-98fe-5ebb27565bc7', 'Quiz: Modifying Data', 'assessment', 1, 10, '51d523fe-1a20-5f00-9512-a5dbd0f6c07e')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Advanced Queries
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('eb95795c-8a47-5888-a951-3748874737f6', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'Advanced Queries', 6)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('7e786747-70f8-588a-af4b-92bdc0b3812b', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'eb95795c-8a47-5888-a951-3748874737f6', 'Subqueries, EXISTS, and CASE Expressions', 'notes', 0, $md$So far every `WHERE` clause has compared a column to a literal value or another column in the same row. SQL lets you go further: a `WHERE` clause can compare against the *result of another query* — a **subquery**. This lesson covers subqueries, the `EXISTS` alternative to them, conditional logic with `CASE`, and a quick recap of `LIMIT` and aliasing tying back to lesson one.

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
$md$, 30, $json$[{"id":"advanced-queries-q1","type":"mcq","correct":"a"},{"id":"advanced-queries-q2","type":"mcq","correct":"a"},{"id":"advanced-queries-q3","type":"sql"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('8246c4e8-508a-52fe-a371-ac29378ea87b', '00000000-0000-0000-0000-000000000001', 'mcq', 'How many rows does `SELECT title FROM books WHERE id NOT IN (SELECT book_id F...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('ff322474-45bd-5ba2-a444-d7319cb2a9d2', '8246c4e8-508a-52fe-a371-ac29378ea87b', 1, $json${"prompt":"How many rows does `SELECT title FROM books WHERE id NOT IN (SELECT book_id FROM loans);` return against the library data?","multiple":false,"options":[{"id":"a","text":"3","is_correct":false},{"id":"b","text":"4","is_correct":false},{"id":"c","text":"5","is_correct":true},{"id":"d","text":"10","is_correct":false}],"explanation":"10 distinct books appear in the loans table across its 20 rows. The library has 15 books total, so 5 have never been loaned: Kingdom of Ash Roses, The Last Alchemist, Watanabe: A Life, Diallo Speaks, and Ash Roses: The Sequel."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('8343bea1-669b-5503-8847-018fff84fa57', '00000000-0000-0000-0000-000000000001', 'mcq', 'If the subquery inside a NOT IN clause returns even one NULL value, what happ...', 'advanced', 3, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('67274e96-a352-5fea-9279-12ce40ce447b', '8343bea1-669b-5503-8847-018fff84fa57', 1, $json${"prompt":"If the subquery inside a NOT IN clause returns even one NULL value, what happens to the outer query?","multiple":false,"options":[{"id":"a","text":"SQLite raises a syntax error","is_correct":false},{"id":"b","text":"The NULL is ignored and NOT IN works normally","is_correct":false},{"id":"c","text":"NOT IN silently stops matching anything, so the outer query returns zero rows","is_correct":true},{"id":"d","text":"The NULL is treated as matching every row","is_correct":false}],"explanation":"Comparing against a NULL produces UNKNOWN rather than TRUE or FALSE, and NOT IN requires the value to be provably unequal to every item in the list. One NULL in the subquery poisons the whole comparison, silently zeroing out the results — this is exactly the failure mode NOT EXISTS avoids."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('df66aa69-e388-5838-b7f3-72c704b3aad4', '00000000-0000-0000-0000-000000000001', 'mcq', 'Does SQLite support writing `price > ALL (subquery)` the way PostgreSQL or SQ...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('669b3c05-5294-5bd8-82cd-192779535f79', 'df66aa69-e388-5838-b7f3-72c704b3aad4', 1, $json${"prompt":"Does SQLite support writing `price \u003e ALL (subquery)` the way PostgreSQL or SQL Server do?","multiple":false,"options":[{"id":"a","text":"Yes, with identical syntax","is_correct":false},{"id":"b","text":"No — the same comparison has to be written using MAX()/MIN() subqueries instead","is_correct":true},{"id":"c","text":"Yes, but only inside a CHECK constraint","is_correct":false},{"id":"d","text":"No — SQLite has no way to express this comparison at all","is_correct":false}],"explanation":"SQLite doesn't implement the ANY/ALL comparison syntax. The same logic is fully expressible with MAX()/MIN() subqueries — price \u003e ALL(subquery) becomes price \u003e (SELECT MAX(...) FROM ...)."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f53468c2-f750-5882-aaee-07ebd480d039', '00000000-0000-0000-0000-000000000001', 'mcq', 'In `WHERE NOT EXISTS (SELECT 1 FROM loans l WHERE l.book_id = b.id)`, why is ...', 'beginner', 1, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('320af2d3-1623-559b-8a37-257394a2f80e', 'f53468c2-f750-5882-aaee-07ebd480d039', 1, $json${"prompt":"In `WHERE NOT EXISTS (SELECT 1 FROM loans l WHERE l.book_id = b.id)`, why is `1` selected instead of an actual column?","multiple":false,"options":[{"id":"a","text":"EXISTS only checks whether any row comes back, not what values it contains, so the selected value doesn't matter","is_correct":true},{"id":"b","text":"SQLite requires a numeric literal inside every subquery","is_correct":false},{"id":"c","text":"It limits the subquery to returning exactly 1 row","is_correct":false},{"id":"d","text":"It's a typo — it should select book_id","is_correct":false}],"explanation":"EXISTS evaluates to true or false based purely on whether the subquery returns any rows at all. Selecting 1 (or * or any column) is a convention that signals 'we don't care about the value.'"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c5321417-36b9-598f-ac2f-2e9711b49b9b', '00000000-0000-0000-0000-000000000001', 'mcq', 'Using `CASE WHEN price < 10 THEN ''Budget'' WHEN price <= 18 THEN ''Standard'' EL...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('29b3e60f-d2f9-5039-84a9-82c2d76a0d4f', 'c5321417-36b9-598f-ac2f-2e9711b49b9b', 1, $json${"prompt":"Using `CASE WHEN price \u003c 10 THEN 'Budget' WHEN price \u003c= 18 THEN 'Standard' ELSE 'Premium' END`, which tier does Kingdom of Ash Roses ($18.00) fall into?","multiple":false,"options":[{"id":"a","text":"Budget","is_correct":false},{"id":"b","text":"Standard","is_correct":true},{"id":"c","text":"Premium","is_correct":false},{"id":"d","text":"NULL, because $18.00 matches no branch","is_correct":false}],"explanation":"WHEN branches are checked in order and the first match wins. $18.00 fails price \u003c 10 but satisfies price \u003c= 18, so it lands in 'Standard' — it never reaches the ELSE branch."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('6ce15575-277a-5579-a3b6-a469f68e6e4b', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does adding `LIMIT 3` to a query do?', 'beginner', 1, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('21548900-8ca7-54da-b103-dfc70453a99b', '6ce15575-277a-5579-a3b6-a469f68e6e4b', 1, $json${"prompt":"What does adding `LIMIT 3` to a query do?","multiple":false,"options":[{"id":"a","text":"Restricts the query to only the first 3 columns","is_correct":false},{"id":"b","text":"Caps the result set to at most 3 rows","is_correct":true},{"id":"c","text":"Requires the query to run in under 3 seconds","is_correct":false},{"id":"d","text":"Skips the first 3 rows of the result","is_correct":false}],"explanation":"LIMIT caps how many rows the query returns — combined with ORDER BY, it's how you get a top-N result like the 3 priciest books."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('64909eca-09f9-566e-9da6-cbe33f6ca9eb', '00000000-0000-0000-0000-000000000001', 'Quiz: Advanced Queries', 'sql-mastery-advanced-queries-quiz', 'Quiz covering Advanced Queries.', 'mcq', 'published', 'module', '770defb5-4faa-5eff-a117-00246076dcad', 10, 70, 5, 11, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('e349061b-36cc-5107-8c1c-bc51f92d44ed', '64909eca-09f9-566e-9da6-cbe33f6ca9eb', '8246c4e8-508a-52fe-a371-ac29378ea87b', 'ff322474-45bd-5ba2-a444-d7319cb2a9d2', 0, 2),
('b5b288e7-8dc7-5f92-8790-359bd6089e8a', '64909eca-09f9-566e-9da6-cbe33f6ca9eb', '8343bea1-669b-5503-8847-018fff84fa57', '67274e96-a352-5fea-9279-12ce40ce447b', 1, 3),
('0cb340b8-4962-5687-895e-68b86af2f793', '64909eca-09f9-566e-9da6-cbe33f6ca9eb', 'df66aa69-e388-5838-b7f3-72c704b3aad4', '669b3c05-5294-5bd8-82cd-192779535f79', 2, 2),
('534f2482-9f44-558d-9551-ca1809732401', '64909eca-09f9-566e-9da6-cbe33f6ca9eb', 'f53468c2-f750-5882-aaee-07ebd480d039', '320af2d3-1623-559b-8a37-257394a2f80e', 3, 1),
('a92dff5b-f449-5669-8474-a3d8e9ac728e', '64909eca-09f9-566e-9da6-cbe33f6ca9eb', 'c5321417-36b9-598f-ac2f-2e9711b49b9b', '29b3e60f-d2f9-5039-84a9-82c2d76a0d4f', 4, 2),
('cee69ac4-2de2-5280-aa4d-bfe584c3c977', '64909eca-09f9-566e-9da6-cbe33f6ca9eb', '6ce15575-277a-5579-a3b6-a469f68e6e4b', '21548900-8ca7-54da-b103-dfc70453a99b', 5, 1)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('770defb5-4faa-5eff-a117-00246076dcad', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'eb95795c-8a47-5888-a951-3748874737f6', 'Quiz: Advanced Queries', 'assessment', 1, 10, '64909eca-09f9-566e-9da6-cbe33f6ca9eb')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Database & Table Design
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('4eb23bfa-1550-5e4a-b344-5cc8599b42d7', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'Database & Table Design', 7)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('20d4754a-e9ca-5f33-8b16-ce2e23ce0f1a', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '4eb23bfa-1550-5e4a-b344-5cc8599b42d7', 'Creating Tables, Constraints, Indexes, and Views', 'notes', 0, $md$Every lesson up to now has queried and modified tables that were already there. This lesson is about defining the tables yourself — the **DDL** (Data Definition Language) side of SQL: `CREATE TABLE`, constraints, `ALTER TABLE`, `DROP TABLE`, indexes, and views. Because every query box here starts from a fresh copy of the seeded database, it's completely safe to create a new table in one of these boxes — it won't collide with anything, and it won't linger into the next box either.

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
$md$, 35, $json$[{"id":"schema-design-q1","type":"mcq","correct":"a"},{"id":"schema-design-q2","type":"mcq","correct":"b"},{"id":"schema-design-q3","type":"sql"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('c7d6aac4-b44b-5358-9c37-10201e959e54', '00000000-0000-0000-0000-000000000001', 'mcq', 'In SQLite, what happens when you INSERT into a table without providing a valu...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('27045e11-5f32-574f-8666-4d5ba3272f26', 'c7d6aac4-b44b-5358-9c37-10201e959e54', 1, $json${"prompt":"In SQLite, what happens when you INSERT into a table without providing a value for a column declared exactly INTEGER PRIMARY KEY?","multiple":false,"options":[{"id":"a","text":"The insert fails, because a value must always be provided","is_correct":false},{"id":"b","text":"SQLite stores NULL for that column","is_correct":false},{"id":"c","text":"SQLite automatically assigns the next available integer, since that column is the table's row identifier","is_correct":true},{"id":"d","text":"SQLite always reuses id 1","is_correct":false}],"explanation":"INTEGER PRIMARY KEY in SQLite is the table's actual rowid. Omitting it lets SQLite auto-assign the next integer — the same idea as MySQL's AUTO_INCREMENT or Postgres's SERIAL/IDENTITY, just spelled differently."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('52809f08-70cb-57b7-8c4d-d5b5742fa783', '00000000-0000-0000-0000-000000000001', 'mcq', 'What''s the difference between DELETE FROM reviews; and DROP TABLE reviews;?', 'beginner', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('295dcfa8-789b-509a-a623-4d970eb8dcd1', '52809f08-70cb-57b7-8c4d-d5b5742fa783', 1, $json${"prompt":"What's the difference between DELETE FROM reviews; and DROP TABLE reviews;?","multiple":false,"options":[{"id":"a","text":"There is no difference — they do the same thing","is_correct":false},{"id":"b","text":"DELETE removes all rows but keeps the table structure; DROP TABLE removes the table itself entirely","is_correct":true},{"id":"c","text":"DROP TABLE only removes rows; DELETE removes the table structure","is_correct":false},{"id":"d","text":"DELETE requires a WHERE clause but DROP TABLE does not","is_correct":false}],"explanation":"DELETE FROM empties a table's rows while the table (and its columns, constraints, and indexes) still exists. DROP TABLE removes the table definition entirely — querying it afterward errors with 'no such table.'"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('1f713792-0148-587e-8b09-66116b6be858', '00000000-0000-0000-0000-000000000001', 'mcq', 'Given `rating INTEGER CHECK (rating BETWEEN 1 AND 5)`, what happens when you ...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('f9b00010-0219-554b-b396-4ce196c1cbde', '1f713792-0148-587e-8b09-66116b6be858', 1, $json${"prompt":"Given `rating INTEGER CHECK (rating BETWEEN 1 AND 5)`, what happens when you try to INSERT a review with rating = 9?","multiple":false,"options":[{"id":"a","text":"The row is inserted with rating silently capped at 5","is_correct":false},{"id":"b","text":"The row is inserted with rating set to NULL","is_correct":false},{"id":"c","text":"The INSERT fails — the CHECK constraint rejects the row","is_correct":true},{"id":"d","text":"The row is inserted, and a warning is logged","is_correct":false}],"explanation":"CHECK constraints are enforced at the database level. A rating of 9 violates BETWEEN 1 AND 5, so SQLite refuses the INSERT outright rather than storing invalid data."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('16f02eb5-f333-5ece-b76f-6579bdd2fe14', '00000000-0000-0000-0000-000000000001', 'mcq', 'members.email is declared TEXT NOT NULL UNIQUE. What happens if you try to in...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('fdcdaaf2-3a7d-5592-a151-e504e2b575fc', '16f02eb5-f333-5ece-b76f-6579bdd2fe14', 1, $json${"prompt":"members.email is declared TEXT NOT NULL UNIQUE. What happens if you try to insert a new member using an email address that already belongs to another member?","multiple":false,"options":[{"id":"a","text":"The new row overwrites the existing member's email","is_correct":false},{"id":"b","text":"The INSERT fails with a UNIQUE constraint violation","is_correct":true},{"id":"c","text":"Both rows are inserted, since NOT NULL only blocks empty values","is_correct":false},{"id":"d","text":"SQLite appends a number to make the email unique automatically","is_correct":false}],"explanation":"UNIQUE means no two rows can share that column's value. Inserting a duplicate email fails outright — the database, not the application, enforces this rule."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00295d4c-82d3-52b1-95f2-a45fd8e76be2', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does `CREATE INDEX idx_books_genre ON books(genre_id);` primarily do?', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('fd21f37e-90aa-59ed-9140-ae1260786a89', '00295d4c-82d3-52b1-95f2-a45fd8e76be2', 1, $json${"prompt":"What does `CREATE INDEX idx_books_genre ON books(genre_id);` primarily do?","multiple":false,"options":[{"id":"a","text":"It changes what SELECT * FROM books returns","is_correct":false},{"id":"b","text":"It lets SQLite find rows matching a given genre_id without scanning the whole table, at the cost of extra work on writes","is_correct":true},{"id":"c","text":"It enforces that genre_id must be unique","is_correct":false},{"id":"d","text":"It automatically sorts the books table by genre_id on disk permanently","is_correct":false}],"explanation":"An index is a separate structure the database maintains so it can jump straight to matching rows instead of scanning every one — it speeds up lookups and joins on that column, but every write to the column now also has to update the index."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('2bb1df26-d5ea-5512-816b-0bbe95e57ac5', '00000000-0000-0000-0000-000000000001', 'mcq', 'What is a SQL view?', 'beginner', 1, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e47cb2d5-8295-5333-a8de-6b4ec41d6f73', '2bb1df26-d5ea-5512-816b-0bbe95e57ac5', 1, $json${"prompt":"What is a SQL view?","multiple":false,"options":[{"id":"a","text":"A saved SELECT query that you can query like a table, recomputed from its underlying tables each time","is_correct":true},{"id":"b","text":"A physical copy of a table's data, refreshed on a schedule","is_correct":false},{"id":"c","text":"A type of index used for full-text search","is_correct":false},{"id":"d","text":"A backup snapshot of the entire database","is_correct":false}],"explanation":"A view doesn't store its own data — it wraps a SELECT (often a join) under a name, and running that name re-executes the underlying query against the current data every time."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('55de8810-6e9a-5261-bce6-04f54d2b782c', '00000000-0000-0000-0000-000000000001', 'Quiz: Database & Table Design', 'sql-mastery-schema-design-quiz', 'Quiz covering Database & Table Design.', 'mcq', 'published', 'module', 'dd9a5489-f523-55c8-a87b-4eb6541c77a9', 10, 70, 5, 11, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('af0a88a7-4309-59ee-a885-63c3d778f531', '55de8810-6e9a-5261-bce6-04f54d2b782c', 'c7d6aac4-b44b-5358-9c37-10201e959e54', '27045e11-5f32-574f-8666-4d5ba3272f26', 0, 2),
('b8ccb7eb-d0ec-5ab9-9e23-ab404ec766b9', '55de8810-6e9a-5261-bce6-04f54d2b782c', '52809f08-70cb-57b7-8c4d-d5b5742fa783', '295dcfa8-789b-509a-a623-4d970eb8dcd1', 1, 2),
('5d5a290d-1f0a-51b7-a908-ea40ee544179', '55de8810-6e9a-5261-bce6-04f54d2b782c', '1f713792-0148-587e-8b09-66116b6be858', 'f9b00010-0219-554b-b396-4ce196c1cbde', 2, 2),
('545226ce-a879-5a4b-85d4-f1c67d343914', '55de8810-6e9a-5261-bce6-04f54d2b782c', '16f02eb5-f333-5ece-b76f-6579bdd2fe14', 'fdcdaaf2-3a7d-5592-a151-e504e2b575fc', 3, 2),
('2692c9e4-57fd-500f-aff1-999a48d6d0e0', '55de8810-6e9a-5261-bce6-04f54d2b782c', '00295d4c-82d3-52b1-95f2-a45fd8e76be2', 'fd21f37e-90aa-59ed-9140-ae1260786a89', 4, 2),
('e338c90f-9772-51f7-bb9c-29c121212e4a', '55de8810-6e9a-5261-bce6-04f54d2b782c', '2bb1df26-d5ea-5512-816b-0bbe95e57ac5', 'e47cb2d5-8295-5333-a8de-6b4ec41d6f73', 5, 1)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('dd9a5489-f523-55c8-a87b-4eb6541c77a9', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '4eb23bfa-1550-5e4a-b344-5cc8599b42d7', 'Quiz: Database & Table Design', 'assessment', 1, 10, '55de8810-6e9a-5261-bce6-04f54d2b782c')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('15247137-f471-5c59-a9a6-2d29bf83776d', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '4eb23bfa-1550-5e4a-b344-5cc8599b42d7', 'Notes: Normal Forms, and Why You''d Break Them', 'notes', 2, $md$The main lesson in this section covered constraints, indexes, and views — the tools you use to design a schema. This note names the formal target those tools are usually aimed at: **normalization**, the process of structuring tables to reduce redundancy, and its deliberate opposite, **denormalization**.

## Why the library schema is already normalized

You've been querying a normalized schema all course without it being named as such: `books.author_id` and `books.genre_id` point at `authors` and `genres` instead of repeating an author's name and country on every one of their books. That's normalization's core idea — each fact lives in exactly one place.

```sql-try
SELECT b.title, a.name, a.country
FROM books b
JOIN authors a ON a.id = b.author_id
WHERE a.name = 'Amara Diallo';
```

If `books` instead stored `author_name` and `author_country` directly on every row, correcting a typo in an author's country would mean updating every one of their books individually — and it would be possible for two rows by the same author to disagree. Keeping author data in its own table, referenced by `author_id`, makes that impossible: fix it once, in one row of `authors`.

## The normal forms, applied to this schema

**1NF — atomic columns.** Every column holds one indivisible value. If `books` had a `genres` column storing `"Fiction, Fantasy"` as one comma-separated string, that would violate 1NF — which is exactly why genre is its own table with a foreign key, not a text list.

**2NF — no partial dependency on part of a composite key.** Only relevant for tables with a multi-column primary key. If `loans` had a composite key of `(book_id, member_id)` and stored `book_title` directly on the row, `book_title` would depend only on `book_id` — half the key — not the whole key. That's a 2NF violation; the fix is the same one already in place: `books.title` lives in `books`, and `loans` only holds the foreign key.

**3NF — no transitive dependency between non-key columns.** If `books` stored both `author_id` and `author_country`, then `author_country` would depend on `author_id`, not directly on `books.id` — a transitive dependency. The schema avoids this: `country` lives only in `authors`, reached through the `author_id` foreign key.

**BCNF and beyond (4NF, 5NF)** tighten edge cases around functional and join dependencies that rarely come up outside academic examples. Worth naming if an interviewer asks "how far did you normalize," but 3NF is where real-world schemas — including this one — typically stop.

| Form | Eliminates | Library schema example |
|---|---|---|
| 1NF | Non-atomic columns | Genre is its own table, not a comma list on `books` |
| 2NF | Partial key dependency | `books.title` isn't duplicated onto `loans` |
| 3NF | Transitive dependency | `authors.country` isn't duplicated onto `books` |

## Denormalization: breaking these rules on purpose

Normalization optimizes for **write safety** — update one row, the fact is corrected everywhere. Denormalization trades that away for **read speed**, by deliberately storing redundant or precomputed data so a query doesn't have to `JOIN` or aggregate to get an answer.

A concrete case in this schema: counting how many books each author has written currently means a `JOIN` plus `GROUP BY` every time:

```sql-try
SELECT a.name, COUNT(*) AS book_count
FROM authors a
JOIN books b ON b.author_id = a.id
GROUP BY a.id;
```

A denormalized design might add a `book_count` column directly onto `authors`, updated whenever a book is inserted or deleted, so reading it back is a single-table lookup with no `JOIN` or aggregation at all. That's the trade: every `INSERT INTO books` now also has to update `authors.book_count` (more write work, and a risk the two drift out of sync if you forget), in exchange for reads that no longer need to compute anything.

**When it's worth it:**
- Read-heavy workloads where the same aggregate is queried far more often than the underlying rows change (a dashboard showing author book counts to thousands of readers, updated by only a handful of writers)
- Reporting/analytics tables, where a nightly job can rebuild denormalized summary columns and staleness for a few hours is acceptable
- Avoiding an expensive `JOIN` across tables that have grown too large for it to stay cheap

**When it's not:** anywhere correctness matters more than read speed, or writes are frequent enough that keeping the redundant copy in sync becomes its own source of bugs — which is why you normalize by default and denormalize deliberately, only once a specific read pattern proves it's worth the trade.

## Key takeaways

- Normalization (1NF → 2NF → 3NF) is the formal name for what `author_id`/`genre_id` foreign keys already do in this schema: each fact stored once, referenced everywhere it's needed.
- BCNF/4NF/5NF exist but rarely matter outside interview trivia — most real schemas stop at 3NF.
- Denormalization is the deliberate reverse: duplicate or precompute data to skip `JOIN`s/aggregation on read, at the cost of extra write work and a risk of the copies drifting apart.
- Default to normalized; denormalize only a specific, measured hot path — not the whole schema.
$md$, 20, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Dates & Useful Functions
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('146b0641-5cfc-5f8c-811b-09a129b2d8c5', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'Dates & Useful Functions', 8)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('113a2912-8ee1-55cb-a0b0-23cdb463294a', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '146b0641-5cfc-5f8c-811b-09a129b2d8c5', 'Working with Dates, NULLs, and Comments', 'notes', 0, $md$Every date in this database — `books.published_year`, `members.joined_date`, `loans.loan_date`, `loans.return_date` — is stored as plain **text** in `YYYY-MM-DD` format (or a plain integer, for `published_year`). SQLite has no dedicated `DATE` or `DATETIME` type; it stores whatever you hand it and gives you a family of date *functions* that know how to parse ISO-8601 text. This is a real difference worth knowing for interviews: PostgreSQL, MySQL, and SQL Server all have native `DATE`/`DATETIME` column types with their own storage format and functions (`DATEDIFF`, `DATE_ADD`, and so on). In SQLite, a "date" is just a sortable string — which turns out to be more convenient than it sounds, as you'll see below.

## Comparing dates as strings

Because `YYYY-MM-DD` is a fixed-width format with the biggest unit first, ordinary string comparison operators sort dates chronologically for free:

```sql-try
SELECT id, loan_date
FROM loans
WHERE loan_date BETWEEN '2024-01-01' AND '2024-01-31'
ORDER BY loan_date;
```

That returns exactly the loans opened in January 2024 (ids 4, 5, 6) — `BETWEEN` here is doing plain text comparison, not calendar-aware math, but because the format is zero-padded and big-endian, `'2024-01-03' < '2024-01-31'` compares correctly. This trick breaks the moment a format isn't zero-padded (`'2024-1-3'` would sort in the wrong place), which is exactly why ISO-8601 is the standard for storing dates as text.

## Pulling out the current date

`date('now')` returns today's date as a `YYYY-MM-DD` string:

```sql-try
SELECT date('now') AS today;
```

The result changes depending on when you run it — useful in real applications (e.g. "loans older than 30 days"), but not something a lesson can hardcode.

## Extracting parts of a date with strftime

`strftime(format, column)` reformats a date string using the same format codes as C's `strftime` — `%Y` for a 4-digit year, `%m` for month, `%d` for day, and so on. Pull the year out of every loan and count loans per year:

```sql-try
SELECT strftime('%Y', loan_date) AS loan_year, COUNT(*) AS num_loans
FROM loans
GROUP BY loan_year
ORDER BY loan_year;
```

This groups all 20 loans by year: 3 loans were opened in 2023, and 17 in 2024 — the library clearly picked up members over time.

## Computing a duration with julianday

To measure elapsed time between two dates, convert both to Julian day numbers with `julianday()` and subtract — the result is a day count as a plain number:

```sql-try
SELECT id, loan_date, return_date,
       julianday(return_date) - julianday(loan_date) AS days_out
FROM loans
WHERE return_date IS NOT NULL
ORDER BY id;
```

Look closely at `days_out`: almost every closed loan lasted exactly **14 days** — this library clearly runs a 14-day standard loan period. Loan 1 (13 days) and loan 3 (11 days) are the only ones returned early. `julianday()` is the general-purpose tool for date *arithmetic* in SQLite, the same way `DATEDIFF` is in SQL Server or subtracting two `DATE` values is in PostgreSQL.

## COALESCE and IFNULL: filling in for NULL

`return_date` is `NULL` for any loan that's still open. Raw `NULL` values are easy to misread in results, so it's common to substitute a friendlier placeholder with `COALESCE` (returns the first non-NULL argument from a list) or its two-argument-only cousin `IFNULL`:

```sql-try
SELECT id, member_id, COALESCE(return_date, 'still out') AS status
FROM loans
LIMIT 6;
```

Loans 1, 2, 3, 5, and 6 show their actual return date; loan 4 — still open — shows `'still out'` instead of `NULL`. `IFNULL(return_date, 'still out')` gives the identical result here; `IFNULL` only ever takes two arguments, while `COALESCE` accepts any number and returns the first non-NULL one. For interview breadth: SQL Server's equivalent is `ISNULL(expr, value)`; MySQL and PostgreSQL both support `COALESCE`, and MySQL also has `IFNULL` — SQLite happens to support both spellings.

## SQL comments

Two comment styles, useful for annotating a query or temporarily disabling a line:

```sql-try
-- this is a single-line comment, ignored to the end of the line
SELECT title, price
FROM books
/* block comments
   can span multiple lines */
WHERE price < 15;
```

## Operator quick reference

A recap of the operators you've used across this course, in one place:

| Category | Operators |
|---|---|
| Arithmetic | `+`  `-`  `*`  `/`  `%` |
| Comparison | `=`  `!=` or `<>`  `<`  `>`  `<=`  `>=` |
| Range / membership | `BETWEEN ... AND ...`  `IN (...)` |
| Pattern matching | `LIKE` (with `%` and `_` wildcards) |
| NULL checks | `IS NULL`  `IS NOT NULL` |
| Logical | `AND`  `OR`  `NOT` |

## Date arithmetic with modifiers

Every SQLite date function accepts optional **modifiers** — strings like `'+7 days'`, `'-1 month'`, `'start of month'` — applied in sequence after the base date:

```sql-try
SELECT id, loan_date, date(loan_date, '+14 days') AS due_date
FROM loans
WHERE return_date IS NULL;
```

`date(loan_date, '+14 days')` computes the due date for every still-open loan, without you having to hand-calculate calendar math yourself — SQLite handles month lengths and leap years correctly. Modifiers chain: `date('now', 'start of month', '-1 day')` gives you the last day of last month, applying each modifier left to right. This is the same family of functions as `date('now')` from earlier in this lesson — `date()`, `time()`, `datetime()`, `julianday()`, and `strftime()` all accept the same modifier syntax.

## NULLIF: turning a specific value into NULL

`COALESCE` replaces `NULL` with something else; `NULLIF` does the opposite — it takes two arguments and returns `NULL` if they're equal, otherwise the first argument unchanged. It's useful for suppressing a "sentinel" value that means "no data" without an actual `NULL`:

```sql-try
SELECT title, stock, NULLIF(stock, 0) AS stock_or_null
FROM books
ORDER BY id
LIMIT 5;
```

Wherever `stock` is `0`, `stock_or_null` shows `NULL` instead — everywhere else, it passes the real stock count through unchanged. A common real use is guarding against division by zero: `price / NULLIF(stock, 0)` returns `NULL` instead of erroring when `stock` is `0`, since dividing by `NULL` is safely `NULL` rather than a crash.

## Knowledge check

Answer all three questions correctly to unlock **Mark as Complete** for this lesson. Every attempt is recorded.

```knowledge-check
{
  "questions": [
    {
      "id": "dates-and-functions-q1",
      "type": "mcq",
      "prompt": "Which function returns NULL if its two arguments are equal, and the first argument otherwise?",
      "options": [
        { "id": "a", "text": "COALESCE" },
        { "id": "b", "text": "NULLIF" },
        { "id": "c", "text": "IFNULL" },
        { "id": "d", "text": "strftime" }
      ],
      "correct": "b",
      "explanation": "NULLIF(a, b) returns NULL when a equals b, otherwise it returns a unchanged — the reverse of what COALESCE/IFNULL do for NULL values."
    },
    {
      "id": "dates-and-functions-q2",
      "type": "mcq",
      "prompt": "What does date(loan_date, '+14 days') compute?",
      "options": [
        { "id": "a", "text": "The date 14 days after loan_date" },
        { "id": "b", "text": "The number of days since loan_date" },
        { "id": "c", "text": "Whether loan_date is more than 14 days old" },
        { "id": "d", "text": "The date 14 days before loan_date" }
      ],
      "correct": "a",
      "explanation": "The '+14 days' modifier shifts the base date forward by 14 days, returning a new YYYY-MM-DD string."
    },
    {
      "id": "dates-and-functions-q3",
      "type": "sql",
      "prompt": "Write a query showing each loan's id and loan_date, plus a due_date column computed as loan_date plus 14 days.",
      "starter": "SELECT",
      "solution": "SELECT id, loan_date, date(loan_date, '+14 days') AS due_date FROM loans;"
    }
  ]
}
```

## What's next

You now have the full toolkit: querying, filtering, aggregating, joining, modifying, subquerying, designing schema, and working with dates. The final section puts it all together — classic query patterns you'll be asked to write in SQL interviews, using this same library database.
$md$, 25, $json$[{"id":"dates-and-functions-q1","type":"mcq","correct":"b"},{"id":"dates-and-functions-q2","type":"mcq","correct":"a"},{"id":"dates-and-functions-q3","type":"sql"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('8ac14422-9d70-5519-9c8b-0bbcdaac6942', '00000000-0000-0000-0000-000000000001', 'mcq', 'How does SQLite store a value like `loans.loan_date`?', 'beginner', 1, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('be8c472c-81bd-55ed-81da-e58c96b35a8a', '8ac14422-9d70-5519-9c8b-0bbcdaac6942', 1, $json${"prompt":"How does SQLite store a value like `loans.loan_date`?","multiple":false,"options":[{"id":"a","text":"As a native DATE type with its own binary format","is_correct":false},{"id":"b","text":"As plain TEXT in YYYY-MM-DD format","is_correct":true},{"id":"c","text":"As a UNIX timestamp integer","is_correct":false},{"id":"d","text":"SQLite refuses to store dates without an extension","is_correct":false},{"id":"e","text":"As a floating-point Julian day number by default","is_correct":false}],"explanation":"SQLite has no dedicated DATE/DATETIME column type — dates are stored as ordinary TEXT in ISO-8601 format, unlike PostgreSQL, MySQL, or SQL Server which have real date types."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('cb5ef77f-5f9f-5f4b-929e-e13bc984f1fe', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why does `WHERE loan_date BETWEEN ''2024-01-01'' AND ''2024-01-31''` correctly fi...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('cc8de933-50d9-5c14-8305-e01e4803c475', 'cb5ef77f-5f9f-5f4b-929e-e13bc984f1fe', 1, $json${"prompt":"Why does `WHERE loan_date BETWEEN '2024-01-01' AND '2024-01-31'` correctly filter to January 2024, even though loan_date is just TEXT?","multiple":false,"options":[{"id":"a","text":"SQLite silently converts the column to a DATE type at query time","is_correct":false},{"id":"b","text":"YYYY-MM-DD is zero-padded and big-endian, so plain string comparison happens to sort chronologically","is_correct":true},{"id":"c","text":"BETWEEN has special built-in awareness of calendar dates","is_correct":false},{"id":"d","text":"It doesn't — the query only works by coincidence for this specific dataset","is_correct":false},{"id":"e","text":"SQLite always compares numerically first","is_correct":false}],"explanation":"Because the year comes first and every field is zero-padded to a fixed width, ordinary lexicographic string comparison produces correct chronological ordering — this trick breaks if the format isn't zero-padded (e.g. '2024-1-3')."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('afbae17c-6be3-559e-9258-653cd0a8df40', '00000000-0000-0000-0000-000000000001', 'mcq', 'What does `julianday(return_date) - julianday(loan_date)` compute?', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('375533d3-0ab2-527b-85c6-d926308a39b0', 'afbae17c-6be3-559e-9258-653cd0a8df40', 1, $json${"prompt":"What does `julianday(return_date) - julianday(loan_date)` compute?","multiple":false,"options":[{"id":"a","text":"The number of days between loan_date and return_date","is_correct":true},{"id":"b","text":"A boolean indicating whether the loan is overdue","is_correct":false},{"id":"c","text":"The current date minus the loan date","is_correct":false},{"id":"d","text":"It always returns NULL if return_date is a string","is_correct":false},{"id":"e","text":"The year difference between the two dates","is_correct":false}],"explanation":"julianday() converts a date string to a Julian day number (a continuous count of days); subtracting two of them gives the elapsed day count between the dates — most loans in this library last exactly 14 days."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('405761e5-907a-5c86-aded-0e331e9b8d14', '00000000-0000-0000-0000-000000000001', 'mcq', 'For a loan where return_date IS NULL, what does `COALESCE(return_date, ''still...', 'beginner', 1, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('cdab25f8-ba7a-534a-af5f-4cb2be822089', '405761e5-907a-5c86-aded-0e331e9b8d14', 1, $json${"prompt":"For a loan where return_date IS NULL, what does `COALESCE(return_date, 'still out')` return?","multiple":false,"options":[{"id":"a","text":"NULL","is_correct":false},{"id":"b","text":"'still out'","is_correct":true},{"id":"c","text":"An empty string","is_correct":false},{"id":"d","text":"It raises an error because return_date is NULL","is_correct":false}],"explanation":"COALESCE returns the first non-NULL argument in its list — since return_date is NULL, it falls through to the literal 'still out'."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('cdbb785f-21be-5143-b485-1923c4041d26', '00000000-0000-0000-0000-000000000001', 'mcq', 'Given `SELECT strftime(''%Y'', loan_date) AS loan_year, COUNT(*) FROM loans GRO...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('c2a7d39c-0629-569f-a004-3114b7b7d577', 'cdbb785f-21be-5143-b485-1923c4041d26', 1, $json${"prompt":"Given `SELECT strftime('%Y', loan_date) AS loan_year, COUNT(*) FROM loans GROUP BY loan_year;` against the seed data, how many loans fall in 2023 vs 2024?","multiple":false,"options":[{"id":"a","text":"10 in 2023, 10 in 2024","is_correct":false},{"id":"b","text":"3 in 2023, 17 in 2024","is_correct":true},{"id":"c","text":"0 in 2023, 20 in 2024","is_correct":false},{"id":"d","text":"All 20 loans are in 2024 since strftime only reads the current year","is_correct":false}],"explanation":"Only loans 1, 2, and 3 were opened in 2023 (loan_date starting with '2023-'); the remaining 17 loans all have a 2024 loan_date."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('f6f9b2c8-00d3-5372-8013-bc6c3e3d166c', '00000000-0000-0000-0000-000000000001', 'mcq', 'SQL Server doesn''t support IFNULL/COALESCE-style substitution the same way as...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('d8ffb556-cbe6-5994-a215-2e9a96077658', 'f6f9b2c8-00d3-5372-8013-bc6c3e3d166c', 1, $json${"prompt":"SQL Server doesn't support IFNULL/COALESCE-style substitution the same way as SQLite's IFNULL — what's its equivalent single-purpose function?","multiple":false,"options":[{"id":"a","text":"NVL","is_correct":false},{"id":"b","text":"ISNULL","is_correct":true},{"id":"c","text":"NULLIF","is_correct":false},{"id":"d","text":"SQL Server has no equivalent function","is_correct":false}],"explanation":"SQL Server uses ISNULL(expr, value) for the two-argument case. (COALESCE itself is standard SQL and also works in SQL Server for the general multi-argument case — ISNULL is its SQL-Server-specific, two-argument-only cousin, mirroring SQLite's IFNULL.)"}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('ba8eee7d-7993-5182-8416-a296ae88b292', '00000000-0000-0000-0000-000000000001', 'Quiz: Dates & Useful Functions', 'sql-mastery-dates-and-functions-quiz', 'Quiz covering Dates & Useful Functions.', 'mcq', 'published', 'module', '3b62031f-738f-590e-bb0e-ea4bde6bd6a5', 10, 70, 5, 10, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('b717f1e6-9387-517c-8e0e-0a5702b46621', 'ba8eee7d-7993-5182-8416-a296ae88b292', '8ac14422-9d70-5519-9c8b-0bbcdaac6942', 'be8c472c-81bd-55ed-81da-e58c96b35a8a', 0, 1),
('500e22f8-ad77-51aa-8cb6-05c43a5330dc', 'ba8eee7d-7993-5182-8416-a296ae88b292', 'cb5ef77f-5f9f-5f4b-929e-e13bc984f1fe', 'cc8de933-50d9-5c14-8305-e01e4803c475', 1, 2),
('2c3131f9-44c8-5fa4-ba24-57fac4687979', 'ba8eee7d-7993-5182-8416-a296ae88b292', 'afbae17c-6be3-559e-9258-653cd0a8df40', '375533d3-0ab2-527b-85c6-d926308a39b0', 2, 2),
('58982716-9936-5685-8344-3619d6e4b3ec', 'ba8eee7d-7993-5182-8416-a296ae88b292', '405761e5-907a-5c86-aded-0e331e9b8d14', 'cdab25f8-ba7a-534a-af5f-4cb2be822089', 3, 1),
('ecb38ccc-c500-5bb2-b46b-6391359a42d9', 'ba8eee7d-7993-5182-8416-a296ae88b292', 'cdbb785f-21be-5143-b485-1923c4041d26', 'c2a7d39c-0629-569f-a004-3114b7b7d577', 4, 2),
('0b804513-114e-5d83-93f8-0aef8c03f9a1', 'ba8eee7d-7993-5182-8416-a296ae88b292', 'f6f9b2c8-00d3-5372-8013-bc6c3e3d166c', 'd8ffb556-cbe6-5994-a215-2e9a96077658', 5, 2)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('3b62031f-738f-590e-bb0e-ea4bde6bd6a5', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '146b0641-5cfc-5f8c-811b-09a129b2d8c5', 'Quiz: Dates & Useful Functions', 'assessment', 1, 10, 'ba8eee7d-7993-5182-8416-a296ae88b292')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

-- Section: Window Functions
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('1538b09b-a39c-5f45-af24-772ae0ebc7f7', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'Window Functions', 10)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('b5012113-9352-5d1c-a40e-8a70e3660e4f', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '1538b09b-a39c-5f45-af24-772ae0ebc7f7', 'Window Functions: OVER, PARTITION BY, RANK, and Running Totals', 'notes', 0, $md$Every aggregate function you've used so far — `COUNT`, `SUM`, `AVG` — collapses many rows into one, via `GROUP BY`. Window functions do something different: they compute an aggregate-like value **per row**, while still showing every row individually, by looking at a "window" of related rows around it. This is the tool for running totals, rankings, and "compare this row to the next/previous row" questions — genuinely common in reporting, dashboards, and interviews alike.

## OVER(): what makes a window function different from GROUP BY

```sql-try
SELECT title, price, genre_id,
  AVG(price) OVER (PARTITION BY genre_id) AS avg_genre_price
FROM books
ORDER BY genre_id, title;
```

Every book still appears as its own row — nothing gets collapsed — but `avg_genre_price` shows the average price of *that book's genre*, recomputed as a window rather than a single merged row. `GROUP BY` would have to drop `title` to compute this (since it isn't part of the grouping key); `OVER (PARTITION BY genre_id)` keeps every row intact while still giving each one access to a genre-wide aggregate. Any aggregate function you already know — `SUM`, `AVG`, `COUNT`, `MIN`, `MAX` — becomes a window function just by adding `OVER (...)` after it.

## ROW_NUMBER, RANK, and DENSE_RANK

These three assign a position to each row within an ordering, and differ only in how they handle ties:

```sql-try
SELECT title, price,
  ROW_NUMBER() OVER (ORDER BY price DESC) AS row_num,
  RANK() OVER (ORDER BY price DESC) AS rank_num,
  DENSE_RANK() OVER (ORDER BY price DESC) AS dense_rank_num
FROM books
ORDER BY price DESC;
```

Two books tie at $18.00 (*Kingdom of Ash Roses* and *Ash Roses: The Sequel*). `ROW_NUMBER()` still hands out distinct numbers to the tied rows (breaking the tie arbitrarily) — it never repeats a number. `RANK()` gives both tied rows the same rank, then **skips** the next number (if two books tie for rank 5, the next distinct book is rank 7, not 6). `DENSE_RANK()` also gives tied rows the same rank, but never skips — the next distinct book is rank 6. Interviewers ask about this distinction constantly; the mnemonic is "RANK leaves gaps, DENSE_RANK doesn't, ROW_NUMBER never ties."

## PARTITION BY: resetting the window per group

Add `PARTITION BY` to any of the above and the ranking (or running aggregate) restarts at the beginning of each partition, instead of running across the whole result:

```sql-try
SELECT title, genre_id, price,
  RANK() OVER (PARTITION BY genre_id ORDER BY price DESC) AS rank_in_genre
FROM books
ORDER BY genre_id, rank_in_genre;
```

Every genre now has its own rank 1 — the most expensive book *in that genre* — instead of one single ranking across all 15 books. This is the pattern behind "find the top N per category" questions: rank within a partition, then filter (typically inside a `WITH` CTE, since `WHERE`/`HAVING` can't reference a window function directly) for `rank_in_genre <= N`.

## Running totals with SUM() OVER

Ordering the window turns `SUM() OVER` into a running total — each row's sum includes every row before it (and itself) in the chosen order:

```sql-try
SELECT id, loan_date,
  SUM(1) OVER (ORDER BY loan_date, id) AS running_loan_count
FROM loans
ORDER BY loan_date, id;
```

Each row shows how many loans had happened *up to and including* that row, in date order — a running count. Swap `SUM(1)` for `SUM(b.price)` (joined against `books`) and the identical shape gives you cumulative revenue over time, one of the most common window-function interview questions there is.

## Naming the frame explicitly: ROWS BETWEEN

The running total above never named a frame — just `ORDER BY` — and SQLite defaulted that to "everything from the start up to this row," which is why it behaved like a running total. `ROWS BETWEEN` lets you say exactly which rows count, instead of accepting that default:

```sql-try
SELECT id, loan_date,
  SUM(1) OVER (
    ORDER BY loan_date, id
    ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
  ) AS loans_last_3
FROM loans
ORDER BY loan_date, id;
```

`ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` is a sliding window of exactly three rows — the current one plus the two immediately before it in the chosen order — instead of every row since the beginning. Once a fourth row exists, the first row drops back out of the window. Swap `SUM(1)` for `AVG(b.price)` (joined against `books`) and this becomes a 3-loan moving average of sale price — the shape behind "moving average" interview questions, distinct from a running total in that old rows eventually age out.

## LAG and LEAD: looking at neighboring rows

`LAG(column, n)` reaches back `n` rows behind the current one (within the same ordering/partition); `LEAD(column, n)` reaches forward. Both default to `n = 1` and return `NULL` when there's no such neighboring row:

```sql-try
SELECT id, member_id, loan_date,
  LAG(loan_date) OVER (PARTITION BY member_id ORDER BY loan_date) AS previous_loan_date
FROM loans
ORDER BY member_id, loan_date;
```

For each member, `previous_loan_date` shows the date of *that same member's* previous loan — `NULL` for their first loan, since there's nothing before it. This is exactly the shape you'd reach for to compute "days between a member's consecutive loans," by subtracting `previous_loan_date` from `loan_date` with `julianday()`.

## Knowledge check

Answer all three questions correctly to unlock **Mark as Complete** for this lesson. Every attempt is recorded.

```knowledge-check
{
  "questions": [
    {
      "id": "window-functions-q1",
      "type": "mcq",
      "prompt": "Two books are tied for the highest price within a genre. What's the key difference between RANK() and DENSE_RANK() for the row immediately after the tie?",
      "options": [
        { "id": "a", "text": "RANK() skips a number after the tie; DENSE_RANK() does not skip any number" },
        { "id": "b", "text": "DENSE_RANK() skips a number after the tie; RANK() does not" },
        { "id": "c", "text": "Both skip a number after any tie" },
        { "id": "d", "text": "Neither ever skips a number, regardless of ties" }
      ],
      "correct": "a",
      "explanation": "RANK() leaves a gap equal to the number of tied rows (e.g. two rows tied for rank 5 means the next rank is 7). DENSE_RANK() never leaves gaps."
    },
    {
      "id": "window-functions-q2",
      "type": "mcq",
      "prompt": "What does PARTITION BY do inside a window function?",
      "options": [
        { "id": "a", "text": "Removes duplicate rows from the result" },
        { "id": "b", "text": "Restarts the window computation independently for each group, without collapsing rows the way GROUP BY does" },
        { "id": "c", "text": "Sorts the entire result set by the partition column" },
        { "id": "d", "text": "Filters out rows that don't match the partition value" }
      ],
      "correct": "b",
      "explanation": "PARTITION BY splits the window into independent groups — each partition gets its own running rank/aggregate — while every row still appears individually in the output, unlike GROUP BY."
    },
    {
      "id": "window-functions-q3",
      "type": "sql",
      "prompt": "Write a query that shows each book's title, genre_id, and price, along with its rank by price within its own genre_id (highest price = rank 1).",
      "starter": "SELECT",
      "solution": "SELECT title, genre_id, price, RANK() OVER (PARTITION BY genre_id ORDER BY price DESC) AS rank_in_genre FROM books;"
    }
  ]
}
```

## What's next

Window functions round out how you can look at data per-row while still seeing the bigger picture. Next: **Indexing & Query Performance** — how the database actually finds the rows you ask for, fast, and when an index helps versus when it just slows writes down.
$md$, 30, $json$[{"id":"window-functions-q1","type":"mcq","correct":"a"},{"id":"window-functions-q2","type":"mcq","correct":"b"},{"id":"window-functions-q3","type":"sql"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('8cc622c0-fefe-5db0-ba78-369d729dff22', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '1538b09b-a39c-5f45-af24-772ae0ebc7f7', 'Notes: Gaps and Islands — Streaks and Missing IDs', 'notes', 1, $md$The main lesson's `LAG`/`LEAD` example finds the date of a member's *previous* loan. Two closely related interview shapes build on that same idea: finding a **run of consecutive rows** (an "island"), and finding a **missing value in a sequence** (a "gap").

## Finding a streak (the island half)

"Which members borrowed a book on 3+ consecutive days?" The trick: subtract a `ROW_NUMBER()` from the actual date. Within a real streak, the date advances by 1 each row while the row number also advances by 1 — so `date - row_number` stays **constant** for every row in that streak, and changes the moment the streak breaks:

```sql-try
WITH numbered AS (
  SELECT member_id, loan_date,
    ROW_NUMBER() OVER (PARTITION BY member_id ORDER BY loan_date) AS rn,
    date(loan_date, '-' || ROW_NUMBER() OVER (PARTITION BY member_id ORDER BY loan_date) || ' days') AS grp
  FROM (SELECT DISTINCT member_id, loan_date FROM loans)
)
SELECT member_id, MIN(loan_date) AS streak_start, COUNT(*) AS streak_len
FROM numbered
GROUP BY member_id, grp
HAVING COUNT(*) >= 3;
```

`grp` is identical for every row inside one unbroken run of days, so grouping by it collapses each streak into a single row. `HAVING COUNT(*) >= 3` keeps only streaks of 3+ days. This is the general "gaps and islands" technique — it works for any "N consecutive units" question (days, order numbers, log-in dates), not just this one.

## Finding a gap (the other half)

"Which book ids are missing from the sequence?" — i.e. ids that should exist between the min and max but don't:

```sql-try
SELECT id + 1 AS gap_starts_after
FROM books b
WHERE NOT EXISTS (SELECT 1 FROM books WHERE id = b.id + 1)
AND id < (SELECT MAX(id) FROM books);
```

For each row, check whether `id + 1` exists anywhere in the table; if it doesn't (and this isn't the last row), there's a gap right after it. This is the same anti-join shape from the interview-ready lesson, just applied to a self-comparison instead of a second table.

## Key takeaways

- **Islands** (consecutive runs): `ROW_NUMBER() - the ordered value` (a date, or an integer) is constant within one run — group by that difference to collapse each run into one row.
- **Gaps** (missing values): for each row, check whether `value + 1` exists in the same table — `NOT EXISTS` flags where the sequence breaks.
- Both are "known shape, not known trick" interview questions — recognizing which one applies matters more than memorizing the exact SQL.
$md$, 15, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('bf077b54-1574-5f51-9c07-c306ffdc166f', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '1538b09b-a39c-5f45-af24-772ae0ebc7f7', 'Notes: NTILE, Multi-Column Partitions, and Tie-Breaking', 'notes', 2, $md$The main lesson covered `ROW_NUMBER`/`RANK`/`DENSE_RANK`, `PARTITION BY`, running totals, and `LAG`/`LEAD`. A few syntax pieces from that same family didn't come up there.

## NTILE: splitting a partition into N equal buckets

`NTILE(n)` divides the (partitioned, ordered) rows into `n` roughly-equal groups and labels each row with its bucket number — the classic use is splitting data into quartiles/percentiles:

```sql-try
SELECT title, price,
  NTILE(4) OVER (ORDER BY price) AS price_quartile
FROM books
ORDER BY price;
```

With 15 books split into 4 buckets, the first ~4 (cheapest) books get bucket 1, the next ~4 get bucket 2, and so on — the last bucket absorbs any remainder. This is how "top 25% by revenue" or "which salary quartile is this employee in" questions get answered without hardcoding cutoff values.

## PARTITION BY with more than one column

`PARTITION BY` isn't limited to a single column — partitioning by `genre_id, author_id` together resets the window for every unique *combination* of the two, not just each genre:

```sql-try
SELECT title, genre_id, author_id, price,
  RANK() OVER (PARTITION BY genre_id, author_id ORDER BY price DESC) AS rank_in_group
FROM books;
```

## Tie-breaking with a second ORDER BY column

`ROW_NUMBER()` breaks ties arbitrarily unless you tell it what to fall back on. Adding a second column to `ORDER BY` inside `OVER (...)` makes the numbering deterministic instead of leaving equal-price rows in whatever order the engine happens to return them:

```sql-try
SELECT title, price,
  ROW_NUMBER() OVER (ORDER BY price DESC, title ASC) AS row_num
FROM books;
```

Now the two $18.00 books are always ordered alphabetically by title relative to each other, run after run — worth mentioning in an interview whenever the question involves ties and the interviewer asks "but which one comes first?"

## LAG/LEAD's third argument: a default instead of NULL

Both `LAG` and `LEAD` take an optional third argument — the value to return instead of `NULL` when there's no row to look at (e.g. the very first row has no "previous" row):

```sql-try
SELECT id, member_id, loan_date,
  LAG(loan_date, 1, 'none') OVER (PARTITION BY member_id ORDER BY loan_date) AS previous_loan_date
FROM loans;
```

A member's first loan now shows the literal string `'none'` instead of `NULL` in that column — useful when downstream code (or a report) can't cleanly handle `NULL` and needs a real placeholder value instead.

## Key takeaways

- `NTILE(n) OVER (ORDER BY ...)` buckets rows into `n` roughly-equal groups — the tool for quartiles/percentile splits.
- `PARTITION BY` accepts multiple columns — the window resets per unique combination, not per single column.
- A second `ORDER BY` column inside `OVER (...)` makes ranking/numbering deterministic when the first column has ties.
- `LAG(col, n, default)` / `LEAD(col, n, default)` — the third argument replaces the edge-row `NULL` with a value you choose.
$md$, 10, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Indexing & Query Performance
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('81fb90fc-1997-565d-af29-9667cea13a55', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'Indexing & Query Performance', 11)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('941b1547-2ce3-5551-aed1-50209e5c6de6', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '81fb90fc-1997-565d-af29-9667cea13a55', 'Indexing & Query Performance: CREATE INDEX and EXPLAIN QUERY PLAN', 'notes', 0, $md$You met `CREATE INDEX` briefly back in Database & Table Design. This lesson goes deeper: what an index actually is under the hood, when SQLite can and can't use one, how to check its query plan instead of guessing, and the tradeoff every index makes against write performance.

## What an index actually is

Without an index, finding rows that match a condition means SQLite reads every row in the table in order — a **full table scan** — checking each one against the condition. An index is a separate, sorted data structure (a B-tree, in SQLite) that maps column values to the rows that have them, so the database can jump straight to matching rows instead of checking all of them:

```sql-try
EXPLAIN QUERY PLAN
SELECT title FROM books WHERE genre_id = 3;
```

`EXPLAIN QUERY PLAN` doesn't run the query — it shows *how* SQLite intends to run it. Against a table with no index on `genre_id`, the plan shows `SCAN books` — a full scan of all 15 rows. That's invisible at 15 rows; it's the reason a database with millions of rows and no index can feel instantaneous on `SELECT * FROM t LIMIT 10` and grind to a halt on `WHERE some_unindexed_column = x`.

## Creating an index and watching the plan change

```sql-try
CREATE INDEX idx_books_genre ON books(genre_id);

EXPLAIN QUERY PLAN
SELECT title FROM books WHERE genre_id = 3;
```

Run this in the same query box as the `CREATE INDEX` (each `sql-try` box is a fresh database, so the index needs to exist before the `EXPLAIN` can see it), and the plan now reads `SEARCH books USING INDEX idx_books_genre (genre_id=?)` instead of `SCAN books` — SQLite is using the index to jump directly to genre 3's rows rather than checking all 15. The query returns the identical three titles either way; only the *path* to them changed.

## Sargable predicates: what lets SQLite actually use an index

An index only helps if the `WHERE` clause is written in a way SQLite can match against it directly — commonly called a **sargable** predicate (Search ARGument ABLE). Wrapping the indexed column in a function or expression usually defeats the index:

```sql-try
CREATE INDEX idx_books_price ON books(price);

EXPLAIN QUERY PLAN
SELECT title FROM books WHERE price * 1.1 > 20;
```

`price * 1.1 > 20` puts `price` inside an expression, so SQLite can't use `idx_books_price` to jump to the answer — it has to compute `price * 1.1` for every row first, meaning a full scan regardless of the index. Rewritten sargably — `WHERE price > 20 / 1.1` — the bare column is back on one side of the comparison and the index becomes usable again. The same trap applies to functions: `WHERE strftime('%Y', loan_date) = '2024'` can't use an index on `loan_date`, even though a plain `WHERE loan_date >= '2024-01-01' AND loan_date < '2025-01-01'` can.

## Composite indexes need their leading column

As covered briefly in Database & Table Design, a composite index `CREATE INDEX idx ON t(a, b)` is only usable starting from its leftmost column. Confirm it with the query plan:

```sql-try
CREATE INDEX idx_loans_member_date ON loans(member_id, loan_date);

EXPLAIN QUERY PLAN
SELECT * FROM loans WHERE loan_date > '2024-02-01';
```

Filtering on `loan_date` alone — the *second* column of the composite index — gets no benefit from `idx_loans_member_date` at all; the plan still shows a full scan. Filter on `member_id` instead (the leading column), and the index kicks in immediately.

## The write-cost tradeoff

Every index is a second structure the database must keep in sync — any `INSERT`, `UPDATE`, or `DELETE` that touches an indexed column has to update the index too, not just the table row itself. That means indexes speed up reads at the direct cost of slowing down writes, and take up extra disk space besides. The practical rule: index columns you filter, join, or sort on frequently, on tables large enough for a scan to actually hurt; don't index every column reflexively, and be especially cautious about adding indexes to tables with heavy write traffic — a logging table that's mostly `INSERT`s rarely benefits from many indexes at all.

## Knowledge check

Answer all three questions correctly to unlock **Mark as Complete** for this lesson. Every attempt is recorded.

```knowledge-check
{
  "questions": [
    {
      "id": "indexing-performance-q1",
      "type": "mcq",
      "prompt": "What does EXPLAIN QUERY PLAN show you?",
      "options": [
        { "id": "a", "text": "The actual result rows the query would return" },
        { "id": "b", "text": "How SQLite intends to execute the query — e.g. a full scan versus an index search — without running it for real results" },
        { "id": "c", "text": "How long the query took to run, in milliseconds" },
        { "id": "d", "text": "A list of every index that exists in the database" }
      ],
      "correct": "b",
      "explanation": "EXPLAIN QUERY PLAN reveals the execution strategy (SCAN vs SEARCH USING INDEX) rather than the query's actual data results."
    },
    {
      "id": "indexing-performance-q2",
      "type": "mcq",
      "prompt": "Given CREATE INDEX idx ON loans(member_id, loan_date), which WHERE clause can make use of this index?",
      "options": [
        { "id": "a", "text": "WHERE loan_date > '2024-01-01'" },
        { "id": "b", "text": "WHERE member_id = 3" },
        { "id": "c", "text": "WHERE return_date IS NULL" },
        { "id": "d", "text": "WHERE book_id = 5" }
      ],
      "correct": "b",
      "explanation": "A composite index is only usable starting from its leftmost column — member_id here. Filtering on loan_date alone, without member_id, can't take advantage of this index."
    },
    {
      "id": "indexing-performance-q3",
      "type": "sql",
      "prompt": "Write a query that creates an index on books(author_id), then selects every book title for author_id 3.",
      "starter": "CREATE INDEX",
      "solution": "CREATE INDEX idx_books_author ON books(author_id); SELECT title FROM books WHERE author_id = 3;"
    }
  ]
}
```

## What's next

You now know how the database finds your rows efficiently, and how to check its plan rather than guess. The next lesson, **Transactions & Concurrency**, covers what happens when multiple statements — or multiple users — touch the database at the same time.
$md$, 30, $json$[{"id":"indexing-performance-q1","type":"mcq","correct":"b"},{"id":"indexing-performance-q2","type":"mcq","correct":"b"},{"id":"indexing-performance-q3","type":"sql"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('c68c63ec-0668-515d-bd97-a30688f368ff', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '81fb90fc-1997-565d-af29-9667cea13a55', 'Notes: Clustered vs Non-Clustered Indexes', 'notes', 1, $md$The main lesson described an index as "a separate, sorted B-tree that maps column values to rows" — that's true of a **non-clustered** index. There's a second kind, and the distinction between the two is one of the most common database interview questions there is.

## Clustered index: the table data itself, in sorted order

A clustered index isn't a separate structure — the table's rows are physically stored on disk sorted by the index key. There's nothing to "look up and then jump to"; the data already is the sorted order. Think of a dictionary: the words themselves are printed in alphabetical order on the page, not listed separately in an index at the back.

Because rows can only be physically sorted one way at a time, **a table can have only one clustered index** — usually the primary key, by default, in engines that support this (SQL Server, MySQL/InnoDB).

## Non-clustered index: a separate lookup structure

A non-clustered index is the B-tree structure from the main lesson: a separate list of (indexed column value → pointer back to the row), while the table's own row order is untouched. Think of a textbook's index page: "Dragon — page 45, 112" is a separate list; the book's pages haven't been reordered around it. A table can have **many** non-clustered indexes, since each one is just an extra lookup structure sitting alongside the data.

## How a non-clustered lookup actually resolves (InnoDB)

In MySQL/InnoDB specifically, a non-clustered index (called a "secondary index" there) doesn't store a raw disk pointer — it stores the row's **primary key value**. So looking up a row by a secondary-indexed column is a two-step process:

1. Search the secondary index for the matching value → get back the primary key.
2. Use that primary key to look the row up in the clustered index (the actual table).

This is sometimes called a "bookmark lookup." The direct consequence: **every secondary index carries an internal copy of the primary key**, for every row. A large primary key (e.g. a 36-character UUID string) doesn't just bloat the primary key itself — it bloats every other index on the table too, since each one silently repeats it.

## Random primary keys cause fragmentation

Because a clustered index keeps rows in sorted key order, inserting a row means placing it in the *correct sorted position* — not just appending it. A sequential key (auto-increment integer, or a time-ordered UUIDv7) always inserts at the end, which is cheap. A random key (UUIDv4) inserts somewhere in the middle of existing sorted data almost every time.

When the data page that new row belongs to is full, the engine performs a **page split** — the full page divides into two so the row has somewhere to go. Repeated over many random inserts, this leaves pages half-empty and scattered instead of tightly packed and contiguous — **fragmentation**, which slows down both writes (more splits) and range scans (more pages to read for the same number of rows). This is the practical reason many teams prefer sequential IDs or UUIDv7 over UUIDv4 for primary keys on tables with heavy insert traffic.

## Engine caveat: this isn't universal

Not every engine implements "true" clustered indexes the way SQL Server and MySQL/InnoDB do:

- **PostgreSQL** has no maintained clustered index — its `CLUSTER` command physically reorders a table once, based on an index, but new inserts don't preserve that order afterward. Postgres tables are fundamentally heap-organized.
- **SQLite** (what this course runs on) stores ordinary tables in a B-tree keyed by an internal `rowid` — conceptually similar to a clustered index on that rowid — unless the table is declared `WITHOUT ROWID`, in which case the primary key itself becomes the clustering key.

Worth naming explicitly in an interview if the conversation is Postgres- or SQLite-specific — the clustered/non-clustered distinction is real, but "which engines actually maintain one automatically" varies.

## Key takeaways

- Clustered index = the table rows themselves, physically sorted by the key. Only one per table.
- Non-clustered index = a separate B-tree pointing back to the row. Many per table.
- InnoDB secondary indexes store the primary key internally, not a raw pointer — so a bloated primary key bloats every secondary index too.
- Random primary keys (UUIDv4) cause page splits and fragmentation because inserts land mid-sort, not at the end; sequential keys avoid this.
- Postgres and SQLite don't maintain a clustered index the same automatic way SQL Server/InnoDB do — check the engine before assuming.
$md$, 15, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Transactions & Concurrency
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('dffba7a6-fe2c-50b7-84a3-53fc15a08d92', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'Transactions & Concurrency', 12)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('10848ef6-6ec2-5a78-a754-29539e492765', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'dffba7a6-fe2c-50b7-84a3-53fc15a08d92', 'Transactions & Concurrency: BEGIN, COMMIT, ROLLBACK', 'notes', 0, $md$Every `INSERT`/`UPDATE`/`DELETE` in this course so far has run as its own standalone statement. Real applications frequently need several statements to succeed or fail *together* — moving stock from one book to another, or registering a new member and their first loan in one action. That's what a transaction gives you.

## BEGIN, COMMIT, and ROLLBACK

A transaction groups multiple statements into one all-or-nothing unit: `BEGIN` starts it, `COMMIT` makes every change inside it permanent, and `ROLLBACK` discards every change inside it as if none of it ever happened:

```sql-try
BEGIN;

UPDATE books SET stock = stock - 1 WHERE id = 1;
UPDATE books SET stock = stock + 1 WHERE id = 4;

COMMIT;

SELECT id, title, stock FROM books WHERE id IN (1, 4);
```

Both `UPDATE`s ran, then `COMMIT` made them permanent together. Now watch `ROLLBACK` undo an in-progress transaction instead:

```sql-try
BEGIN;

UPDATE books SET stock = 0 WHERE id = 1;

ROLLBACK;

SELECT id, title, stock FROM books WHERE id = 1;
```

Even though the `UPDATE` ran without error, `ROLLBACK` discards it entirely — the `SELECT` afterward shows book 1's original stock, untouched. Outside of an explicit transaction, SQLite (like most databases) treats every single statement as its own implicit transaction, auto-committed the instant it succeeds — which is why every earlier lesson's `UPDATE`/`DELETE` examples took effect immediately with no `BEGIN`/`COMMIT` of their own.

## Atomicity: why multi-statement updates need a transaction

**Atomicity** — the "A" in the classic ACID guarantees — means a transaction's statements succeed or fail as one indivisible unit; there's no such thing as "half-committed." This matters most when one statement depends on another leaving the data in a particular state. Imagine moving a book between two "locations" by decrementing stock in one row and incrementing it in another — without a transaction wrapping both `UPDATE`s, a crash or error between the two statements leaves the data inconsistent (stock removed from the first book, never added to the second, with no record of where it went). Wrapping both in `BEGIN ... COMMIT` guarantees that either both happen or neither does.

## Isolation levels: what one transaction can see of another

**Isolation** governs what one in-progress transaction can see of another transaction running at the same time — a real concern the moment more than one connection can write to the database concurrently. Two classic problems isolation levels are named after:

- **Dirty read** — reading a row that another transaction has changed but not yet committed. If that other transaction then rolls back, you've read data that never actually existed.
- **Non-repeatable read** — reading the same row twice within one transaction and getting two different answers, because another transaction committed a change to it in between your two reads.

Stricter isolation levels prevent more of these at the cost of more locking/blocking between concurrent transactions; looser levels allow more concurrency but open the door to these anomalies. SQLite's default locking behavior is actually stricter than the default in PostgreSQL or MySQL (`READ COMMITTED`) — worth knowing for interviews, since "what's the default isolation level" is a common follow-up question, and the honest answer is "it depends on the database," not a universal constant.

## A note on row locking

When one transaction is in the middle of writing to a row, most databases block a second transaction from writing to the same data until the first one finishes with `COMMIT` or `ROLLBACK` — this is what actually enforces isolation in practice. SQLite locks at a coarser grain than Postgres or MySQL (closer to whole-database-file than per-row for writers), which is part of why SQLite is a great fit for a single-application embedded database but not the first choice for a system with many concurrent writers.

## Knowledge check

Answer all three questions correctly to unlock **Mark as Complete** for this lesson. Every attempt is recorded.

```knowledge-check
{
  "questions": [
    {
      "id": "transactions-concurrency-q1",
      "type": "mcq",
      "prompt": "What does COMMIT do?",
      "options": [
        { "id": "a", "text": "Starts a new transaction" },
        { "id": "b", "text": "Makes every change made since BEGIN permanent" },
        { "id": "c", "text": "Undoes every change made since BEGIN" },
        { "id": "d", "text": "Locks the table so no one else can read it" }
      ],
      "correct": "b",
      "explanation": "COMMIT permanently applies all changes made within the transaction. ROLLBACK is what undoes them instead."
    },
    {
      "id": "transactions-concurrency-q2",
      "type": "mcq",
      "prompt": "What is a 'dirty read'?",
      "options": [
        { "id": "a", "text": "A query that returns duplicate rows" },
        { "id": "b", "text": "Reading a row that another transaction has changed but not yet committed" },
        { "id": "c", "text": "A read that ignores an available index" },
        { "id": "d", "text": "Reading a NULL value instead of the expected data" }
      ],
      "correct": "b",
      "explanation": "A dirty read means seeing another transaction's uncommitted change — if that transaction rolls back, you've read data that never actually existed."
    },
    {
      "id": "transactions-concurrency-q3",
      "type": "sql",
      "prompt": "Write a transaction that increases the stock of book id 2 by 2 and decreases the stock of book id 5 by 2, commits, then selects both books' id and stock.",
      "starter": "BEGIN;",
      "solution": "BEGIN; UPDATE books SET stock = stock + 2 WHERE id = 2; UPDATE books SET stock = stock - 2 WHERE id = 5; COMMIT; SELECT id, stock FROM books WHERE id IN (2, 5);"
    }
  ]
}
```

## What's next

That's every fundamental this course set out to teach — querying, filtering, aggregating, joining, modifying data safely inside transactions, subqueries, schema design, indexing, dates, and window functions. **SQL for Interviews** closes the course by walking through the classic problem shapes that combine everything you've learned.
$md$, 25, $json$[{"id":"transactions-concurrency-q1","type":"mcq","correct":"b"},{"id":"transactions-concurrency-q2","type":"mcq","correct":"b"},{"id":"transactions-concurrency-q3","type":"sql"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('e7c37c2a-24d3-50df-8990-bf7d79dfb34c', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'dffba7a6-fe2c-50b7-84a3-53fc15a08d92', 'Notes: The Full ACID Acronym', 'notes', 2, $md$The main lesson in this section already covered two of the four ACID letters in depth: **Atomicity** (the `BEGIN`/`COMMIT`/`ROLLBACK` all-or-nothing guarantee) and **Isolation** (dirty reads, non-repeatable reads, and how SQLite's locking compares to Postgres/MySQL). This note completes the picture with **Consistency** and **Durability**, and gives you the acronym as a single interview-ready answer.

## A quick recap of the two you already know

- **Atomicity** — a transaction's statements succeed or fail as one unit. No such thing as half-committed.
- **Isolation** — what one in-progress transaction can see of another one running concurrently.

## C — Consistency

Consistency means a transaction can only move the database from one **valid state** to another valid state — every constraint, `CHECK`, `NOT NULL`, `UNIQUE`, and foreign key rule you defined in the schema design lesson must still hold true after the transaction commits.

```sql-try
BEGIN;

INSERT INTO reviews (book_id, rating, comment) VALUES (1, 9, 'Too high!');

COMMIT;
```

This never reaches a "committed" state at all — the `CHECK (rating BETWEEN 1 AND 5)` constraint from the schema design lesson rejects the row before the transaction can commit, so the database is never left in an invalid state. That's Consistency in action: it isn't a separate mechanism you write code for, it's the database refusing to let a transaction complete if the result would violate a rule you already declared.

## D — Durability

Durability means once a transaction commits, the result survives — even a crash or power loss immediately afterward can't undo it. Databases achieve this with a **write-ahead log (WAL)**: before data pages on disk are actually modified, the change is first written to an append-only log file. If the database crashes mid-write, it replays the WAL on restart to redo any committed-but-not-yet-applied changes, and discards anything that never reached `COMMIT`.

```sql-try
PRAGMA journal_mode;
```

SQLite defaults to a rollback-journal mode, but can run in `WAL` mode explicitly (`PRAGMA journal_mode = WAL;`) — the same write-ahead-log idea PostgreSQL and MySQL use by default for durability. The mechanism differs in the details across databases, but the guarantee is identical: a `COMMIT` that returned successfully is permanent, full stop.

## The full acronym, as one interview answer

| Letter | Guarantee | What breaks without it |
|---|---|---|
| **A**tomicity | All statements in a transaction succeed or none do | Partial updates left half-applied |
| **C**onsistency | Every commit leaves the database satisfying its constraints | Invalid data (broken `CHECK`/`FK`/`UNIQUE` rules) slips through |
| **I**solation | Concurrent transactions don't see each other's uncommitted work | Dirty reads, non-repeatable reads |
| **D**urability | A committed transaction survives a crash | Data loss right after a successful commit |

**One-liner:** "ACID is the set of guarantees a transaction gives you: it's all-or-nothing (Atomicity), it never leaves the data in a state that violates a constraint (Consistency), concurrent transactions can't see each other's half-finished work (Isolation), and once it commits, it's permanent even through a crash (Durability)."

## Key takeaways

- Atomicity and Isolation were covered hands-on in the main lesson — Consistency and Durability complete the acronym here.
- Consistency isn't a separate feature to configure — it's the natural result of the constraints you already declare with `CHECK`, `NOT NULL`, `UNIQUE`, and foreign keys.
- Durability is implemented via a write-ahead log in every major database, SQLite included (`PRAGMA journal_mode = WAL`).
$md$, 15, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: SQL for Interviews
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('6f6f149b-633c-5cfa-a03f-40ecfc1e7fd7', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', 'SQL for Interviews', 13)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('4df7e7f0-4bda-5d3a-a45b-46fc1ceee9cb', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '6f6f149b-633c-5cfa-a03f-40ecfc1e7fd7', 'Classic SQL Interview Patterns', 'notes', 0, $md$You've now covered every SQL building block this course teaches: `SELECT`, filtering, aggregation, every join type, data modification, subqueries, schema design, and dates. SQL interviews rarely test a single keyword in isolation — they test whether you recognize a handful of recurring *shapes* of problem and can reach for the right pattern under pressure. This lesson walks through five of the most common ones, each against the same library database you already know, followed by advice on how to talk through your reasoning out loud.

## Pattern 1: Find the Nth highest value

"Find the second-highest-paid employee" is one of the most-asked SQL interview questions there is — here it's "find the second most expensive book." The direct tool is `ORDER BY ... LIMIT 1 OFFSET N-1`:

```sql-try
SELECT title, price
FROM books
ORDER BY price DESC
LIMIT 1 OFFSET 1;
```

`ORDER BY price DESC` puts the most expensive book first. `OFFSET 1` then *skips* the first row of that ordered result before `LIMIT 1` takes the next one — so `OFFSET 1` gives you the 2nd-highest, `OFFSET 2` would give the 3rd-highest, and so on. This returns **Diallo Speaks** at **$21.00** (the single most expensive book, *Watanabe: A Life* at $22.50, is skipped by the offset).

Interviewers sometimes also ask for the same answer without `LIMIT`/`OFFSET`, using a correlated subquery — worth knowing both:

```sql-try
SELECT title, price
FROM books
WHERE price < (SELECT MAX(price) FROM books)
ORDER BY price DESC
LIMIT 1;
```

The inner subquery finds the overall maximum price ($22.50). The outer query then finds the highest price *strictly less than* that maximum — which is the second-highest price, $21.00, on the same book. This specific trick only generalizes to "2nd highest" cleanly; for the 3rd-highest you'd need to nest it again (`WHERE price < (SELECT MAX(price) FROM books WHERE price < (SELECT MAX(price) FROM books))`), which is exactly why `LIMIT`/`OFFSET` is the pattern you reach for first in practice, and the subquery version is more of an "I also know this" answer.

## Pattern 2: Find duplicate values

"Find duplicate rows" comes up constantly — the shape is always `GROUP BY` the column(s) that define a duplicate, then `HAVING COUNT(*) > 1` to keep only the groups with more than one row:

```sql-try
SELECT price, COUNT(*) AS num_books
FROM books
GROUP BY price
HAVING COUNT(*) > 1;
```

Exactly one price repeats: **$18.00**, shared by two books. `HAVING` is required here rather than `WHERE` because the filter (`COUNT(*) > 1`) depends on the aggregate, and `WHERE` runs *before* grouping happens — `HAVING` is the version of `WHERE` that runs after. To see which books those are:

```sql-try
SELECT id, title, price
FROM books
WHERE price = 18.00
ORDER BY id;
```

That's **Kingdom of Ash Roses** (id 3) and **Ash Roses: The Sequel** (id 14) — presumably a book and its sequel priced identically on purpose.

## Pattern 3: Rows that never matched (anti-join)

"Find customers who never placed an order" is the general shape — here, "find books that have never been loaned." There are two equally common ways to write it, and interviewers often want to see you know both by name.

**`NOT IN` with a subquery:**

```sql-try
SELECT id, title
FROM books
WHERE id NOT IN (SELECT book_id FROM loans)
ORDER BY id;
```

**`LEFT JOIN` / `IS NULL` — the "anti-join" pattern:**

```sql-try
SELECT b.id, b.title
FROM books b
LEFT JOIN loans l ON l.book_id = b.id
WHERE l.id IS NULL
ORDER BY b.id;
```

Both return the same five books: ids 3, 7, 12, 13, and 14 — *Kingdom of Ash Roses*, *The Last Alchemist*, *Watanabe: A Life*, *Diallo Speaks*, and *Ash Roses: The Sequel* have never once appeared in `loans`. The `LEFT JOIN` keeps every book regardless of whether it matches a loan, filling in `NULL` for every loan column when there's no match; filtering `WHERE l.id IS NULL` then keeps only the books that matched nothing at all — hence "anti-join." One interview-worthy caveat: `NOT IN` silently returns **zero rows** if the subquery's column can ever contain a `NULL` value (it can't here, since `loans.book_id` is `NOT NULL`-ish by data, but it's a classic gotcha) — the `LEFT JOIN` version doesn't have that trap, which is why many interviewers prefer it as the "safe" answer.

## Pattern 4: Aggregate with a comparison to another aggregate

A genuinely tricky but common shape: "find members who borrowed more books than average." This needs a subquery *inside* a `HAVING` clause, comparing each group's count to the average of all groups' counts:

```sql-try
SELECT m.name, COUNT(*) AS num_loans
FROM loans l
JOIN members m ON m.id = l.member_id
GROUP BY l.member_id
HAVING COUNT(*) > (
  SELECT AVG(cnt) FROM (
    SELECT COUNT(*) AS cnt FROM loans GROUP BY member_id
  )
)
ORDER BY num_loans DESC;
```

Walk through this from the inside out, the way you should narrate it in an interview:

1. **Innermost subquery** — `SELECT COUNT(*) AS cnt FROM loans GROUP BY member_id` produces one row per member with how many loans they have: every one of the 10 members has borrowed either 1, 2, or 3 books.
2. **Middle subquery** — `SELECT AVG(cnt) FROM (...)` averages *those ten counts* (not the raw loan rows), giving 2.0 loans per member.
3. **Outer query** — groups `loans` by `member_id` again (joined to `members` for a readable name) and keeps only the group whose count exceeds that 2.0 average.

Only one member clears the bar: **Chloe Martin**, with 3 loans. Everyone else has 1 or 2, right at or below average.

## Pattern 5: Self-join for relationship data

Whenever one row can reference another row in the *same* table — an employee's manager, a category's parent category, or here, the member who referred another member — you join the table to itself under two aliases:

```sql-try
SELECT m.name AS member_name, r.name AS referred_by
FROM members m
LEFT JOIN members r ON m.referred_by = r.id
ORDER BY m.id;
```

`m` stands in for "the member," `r` stands in for "the referrer" — same table, two roles. `LEFT JOIN` (not `INNER JOIN`) matters here: members with no referrer at all (`referred_by IS NULL`) still need to appear in the results, just with `referred_by` showing `NULL` instead of being dropped entirely. Five members — Ana Torres, Chloe Martin, Elin Karlsson, Grace Kim, and Jonas Weber — joined without a referral; the rest show the name of whoever referred them.

## Pattern 6: Conditional aggregation (pivoting rows into columns)

"Show me one row per author, with separate columns for how many Fiction books and how many Fantasy books they've written" is a classic ask for turning row-based data into column-based summary — without a dedicated `PIVOT` keyword (SQLite doesn't have one), the standard trick is `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` per desired column:

```sql-try
SELECT a.name,
  SUM(CASE WHEN b.genre_id = 1 THEN 1 ELSE 0 END) AS fiction_count,
  SUM(CASE WHEN b.genre_id = 3 THEN 1 ELSE 0 END) AS fantasy_count
FROM authors a
JOIN books b ON b.author_id = a.id
GROUP BY a.id
ORDER BY a.name;
```

Each `CASE` evaluates once per row inside the group: it contributes `1` to its column when the row's `genre_id` matches, and `0` otherwise, and `SUM` adds those up per author. Amara Diallo shows `fantasy_count = 3` and `fiction_count = 0`; authors who wrote neither genre show `0` in both columns rather than being dropped from the result the way a plain `WHERE genre_id IN (1, 3)` filter would. This pattern generalizes to any fixed, known set of categories you want spread across columns — the moment the category list is unbounded or unknown ahead of time, you're better off with a plain `GROUP BY genre_id` instead.

## What to say out loud in an interview

The SQL itself is only half of what's being evaluated — the other half is whether you can narrate your thought process as you build it. A reliable order: start from the table that holds the thing you're ultimately selecting (books, members, whatever the question is *about*), join outward to whatever else you need column data from, add your `WHERE` filters, and only then layer on `GROUP BY`/`HAVING` if the question involves counting or comparing groups. Say each step as you type it — "I need book titles, so I'm starting from `books`; I need to know which ones were never loaned, so I'll left-join `loans` and look for the ones with no match" — rather than silently producing a finished query. Interviewers are watching for someone who can debug their own reasoning as they go, not just someone who memorized the right answer.

## Partitioning vs sharding

One more term that comes up as a follow-up once you've shown you can write the query: "how would this scale?" Two answers get confused constantly, and knowing the difference matters more than knowing another query pattern.

**Partitioning** splits *one logical table* into smaller physical pieces — by range or hash of a column — while it all still lives inside a single database instance. If `loans` grew to hundreds of millions of rows, a real-world engine might partition it by `loan_date` range (one partition per year), so a query for "loans in 2024" only scans that partition instead of the whole table. SQLite itself has no native table partitioning — it's a single file — but the concept is exactly how PostgreSQL, MySQL, and SQL Server handle a table like `loans` once it outgrows a single disk-friendly chunk.

**Sharding** splits data across *separate database instances/servers* entirely — each shard is its own database holding a subset of rows (say, members 1–5,000 on one server, 5,001–10,000 on another). It solves a different bottleneck than partitioning does: when one machine's disk, memory, or CPU can't keep up, not just when a single table scan is slow.

The distinction interviewers listen for: partitioning organizes data *within* one database for faster scans; sharding spreads data *across* multiple databases for horizontal scale. They're not mutually exclusive — a system at real scale often does both (shard `members` by region across servers, then partition each shard's `loans` table by date).

## Knowledge check

Answer all three questions correctly to unlock **Mark as Complete** for this lesson. Every attempt is recorded.

```knowledge-check
{
  "questions": [
    {
      "id": "interview-ready-q1",
      "type": "mcq",
      "prompt": "Which approach finds the second-highest price without using LIMIT/OFFSET?",
      "options": [
        { "id": "a", "text": "A correlated subquery comparing price against the overall MAX(price)" },
        { "id": "b", "text": "GROUP BY price alone, with no HAVING clause" },
        { "id": "c", "text": "A CREATE INDEX on the price column" },
        { "id": "d", "text": "UNION ALL between two identical SELECTs" }
      ],
      "correct": "a",
      "explanation": "WHERE price < (SELECT MAX(price) FROM books) followed by ORDER BY price DESC LIMIT 1 finds the second-highest price without OFFSET, by excluding the true maximum first."
    },
    {
      "id": "interview-ready-q2",
      "type": "mcq",
      "prompt": "In the conditional aggregation (pivot) pattern, what does SUM(CASE WHEN genre_id = 1 THEN 1 ELSE 0 END) compute per group?",
      "options": [
        { "id": "a", "text": "The total price of books in that group" },
        { "id": "b", "text": "The count of rows in that group where genre_id equals 1" },
        { "id": "c", "text": "Whether any row in the group has genre_id = 1" },
        { "id": "d", "text": "The average genre_id in the group" }
      ],
      "correct": "b",
      "explanation": "Each row contributes 1 to the sum when genre_id = 1 is true and 0 otherwise, so SUM effectively counts matching rows within each group — the standard SQL pivot trick."
    },
    {
      "id": "interview-ready-q3",
      "type": "sql",
      "prompt": "Write a query using the anti-join pattern (LEFT JOIN + IS NULL) to find every book that has never been loaned out.",
      "starter": "SELECT",
      "solution": "SELECT b.title FROM books b LEFT JOIN loans l ON l.book_id = b.id WHERE l.id IS NULL;"
    }
  ]
}
```
$md$, 40, $json$[{"id":"interview-ready-q1","type":"mcq","correct":"a"},{"id":"interview-ready-q2","type":"mcq","correct":"b"},{"id":"interview-ready-q3","type":"sql"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('897639d2-6192-57e4-8ecb-9a7bc7360335', '00000000-0000-0000-0000-000000000001', 'mcq', 'In `SELECT title, price FROM books ORDER BY price DESC LIMIT 1 OFFSET 1;`, wh...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('bd948830-7203-54ba-bfbe-f629ebd6a022', '897639d2-6192-57e4-8ecb-9a7bc7360335', 1, $json${"prompt":"In `SELECT title, price FROM books ORDER BY price DESC LIMIT 1 OFFSET 1;`, what does `OFFSET 1` do?","multiple":false,"options":[{"id":"a","text":"Skips the first row of the ordered result before LIMIT starts counting","is_correct":true},{"id":"b","text":"Limits the query to return only 1 column","is_correct":false},{"id":"c","text":"Adds 1 to every price value in the result","is_correct":false},{"id":"d","text":"Returns only rows where price = 1","is_correct":false}],"explanation":"ORDER BY price DESC puts the highest price first; OFFSET 1 then skips that single row before LIMIT 1 takes the next one — giving the 2nd-highest price ($21.00, Diallo Speaks), not the highest."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('d2c02ef0-ff60-5a55-8699-91436d5d638d', '00000000-0000-0000-0000-000000000001', 'mcq', 'Why must `HAVING COUNT(*) > 1` be used instead of `WHERE COUNT(*) > 1` when f...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('db40933f-d5e7-5dbc-ac77-4de1c39e149b', 'd2c02ef0-ff60-5a55-8699-91436d5d638d', 1, $json${"prompt":"Why must `HAVING COUNT(*) \u003e 1` be used instead of `WHERE COUNT(*) \u003e 1` when finding books that share the same price?","multiple":false,"options":[{"id":"a","text":"WHERE filters rows before GROUP BY runs and can't reference an aggregate like COUNT(*); HAVING filters after grouping","is_correct":true},{"id":"b","text":"WHERE and HAVING are fully interchangeable in SQLite","is_correct":false},{"id":"c","text":"COUNT(*) can only appear in a SELECT list, never in any filter","is_correct":false},{"id":"d","text":"HAVING is only required when ORDER BY is also present","is_correct":false}],"explanation":"WHERE filters individual rows before grouping/aggregation happens, so aggregate results aren't available to it yet. HAVING runs after GROUP BY and can filter on the aggregated value."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('ab26f027-2cab-5efd-9617-74238dc2385d', '00000000-0000-0000-0000-000000000001', 'mcq', 'Both `WHERE id NOT IN (SELECT book_id FROM loans)` and `LEFT JOIN loans ON .....', 'advanced', 3, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('1656f916-eb88-5db6-9a47-63e6177ba2a4', 'ab26f027-2cab-5efd-9617-74238dc2385d', 1, $json${"prompt":"Both `WHERE id NOT IN (SELECT book_id FROM loans)` and `LEFT JOIN loans ON ... WHERE loans.id IS NULL` find books that were never loaned. Why do many engineers treat the LEFT JOIN version as the 'safer' pattern?","multiple":false,"options":[{"id":"a","text":"If the NOT IN subquery's column ever contains a NULL, the whole NOT IN comparison silently returns zero rows; LEFT JOIN/IS NULL has no such failure mode","is_correct":true},{"id":"b","text":"LEFT JOIN is always faster than NOT IN, regardless of table size","is_correct":false},{"id":"c","text":"NOT IN cannot be combined with a subquery, only with a literal list","is_correct":false},{"id":"d","text":"LEFT JOIN works in more database engines than NOT IN does","is_correct":false}],"explanation":"If any row returned by the NOT IN subquery is NULL, every NOT IN comparison evaluates to UNKNOWN and the outer query returns nothing at all — a classic, easy-to-miss bug. The LEFT JOIN / IS NULL pattern doesn't have this trap."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('cea15ff0-445c-516d-bbb8-a8d6529c375c', '00000000-0000-0000-0000-000000000001', 'mcq', '`SELECT member_id, COUNT(*) FROM loans GROUP BY member_id HAVING COUNT(*) > (...', 'advanced', 3, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('24fab267-33c5-5c0c-81c2-2f18e69b367a', 'cea15ff0-445c-516d-bbb8-a8d6529c375c', 1, $json${"prompt":"`SELECT member_id, COUNT(*) FROM loans GROUP BY member_id HAVING COUNT(*) \u003e (SELECT AVG(cnt) FROM (SELECT COUNT(*) AS cnt FROM loans GROUP BY member_id));` — against the seed data, who ends up in the result?","multiple":false,"options":[{"id":"a","text":"All 10 members, since everyone has borrowed at least once","is_correct":false},{"id":"b","text":"Only member_id 3 (Chloe Martin), whose 3 loans exceed the 2.0 average loans-per-member","is_correct":true},{"id":"c","text":"No members — COUNT(*) can't be compared against AVG() in a HAVING clause","is_correct":false},{"id":"d","text":"The member with the fewest loans, since HAVING inverts the comparison","is_correct":false}],"explanation":"Every member's loan count is 1, 2, or 3, averaging to 2.0 across all 10 members. Only Chloe Martin has 3 loans, clearing that average — everyone else sits at or below it."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('75a37ce3-cf5c-5f0d-9eba-d18043e9f1fa', '00000000-0000-0000-0000-000000000001', 'mcq', 'In `SELECT m.name, r.name FROM members m LEFT JOIN members r ON m.referred_by...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('5de76063-e12f-502d-b686-72933f6dd402', '75a37ce3-cf5c-5f0d-9eba-d18043e9f1fa', 1, $json${"prompt":"In `SELECT m.name, r.name FROM members m LEFT JOIN members r ON m.referred_by = r.id;`, why is LEFT JOIN required instead of INNER JOIN?","multiple":false,"options":[{"id":"a","text":"A table cannot legally INNER JOIN to itself in SQLite","is_correct":false},{"id":"b","text":"INNER JOIN would silently drop every member whose referred_by is NULL; LEFT JOIN keeps them with a NULL referrer name","is_correct":true},{"id":"c","text":"LEFT JOIN is required any time two aliases of the same table are used","is_correct":false},{"id":"d","text":"referred_by must have a UNIQUE constraint before INNER JOIN can be used","is_correct":false}],"explanation":"5 of the 10 members have no referrer (referred_by IS NULL). INNER JOIN only keeps rows with a match on both sides, so it would drop those 5 members entirely; LEFT JOIN preserves every member row."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('3a9c87a2-ab5a-52f7-8c83-dd6e74982837', '00000000-0000-0000-0000-000000000001', 'mcq', 'For loan 5, return_date is ''2024-01-24'' (not NULL). What does `COALESCE(retur...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e19a0190-a24d-5ed6-ac37-caba100a62f7', '3a9c87a2-ab5a-52f7-8c83-dd6e74982837', 1, $json${"prompt":"For loan 5, return_date is '2024-01-24' (not NULL). What does `COALESCE(return_date, 'still out')` evaluate to for that row?","multiple":false,"options":[{"id":"a","text":"'still out'","is_correct":false},{"id":"b","text":"NULL","is_correct":false},{"id":"c","text":"'2024-01-24'","is_correct":true},{"id":"d","text":"'2024-01-24, still out'","is_correct":false}],"explanation":"COALESCE returns the first non-NULL argument in its list. Since return_date already has a value, that value passes through unchanged — the fallback only applies when the first argument is NULL."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('746e7b8d-a40e-55a8-8871-2f7b06663043', '00000000-0000-0000-0000-000000000001', 'mcq', 'Loan 3 has loan_date ''2023-11-20'' and return_date ''2023-12-01''. What does `ju...', 'intermediate', 2, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('e5eaf92a-b04c-58bf-b881-cd55155e7783', '746e7b8d-a40e-55a8-8871-2f7b06663043', 1, $json${"prompt":"Loan 3 has loan_date '2023-11-20' and return_date '2023-12-01'. What does `julianday(return_date) - julianday(loan_date)` evaluate to?","multiple":false,"options":[{"id":"a","text":"9","is_correct":false},{"id":"b","text":"10","is_correct":false},{"id":"c","text":"11","is_correct":true},{"id":"d","text":"14","is_correct":false}],"explanation":"November 20 to December 1 spans 11 days. This is one of only two closed loans shorter than the library's usual 14-day loan period (the other is loan 1, at 13 days)."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('5b8f48fc-6a1e-50a2-b903-87c23eb9a6d0', '00000000-0000-0000-0000-000000000001', 'mcq', 'books.author_id is declared `INTEGER REFERENCES authors(id)`. By default in S...', 'advanced', 3, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('4d7f815c-709d-5da8-bd92-ce3e267f97fc', '5b8f48fc-6a1e-50a2-b903-87c23eb9a6d0', 1, $json${"prompt":"books.author_id is declared `INTEGER REFERENCES authors(id)`. By default in SQLite, is inserting a books row with an author_id that doesn't exist in authors actually rejected?","multiple":false,"options":[{"id":"a","text":"Yes — foreign keys are enforced by default in SQLite","is_correct":false},{"id":"b","text":"No — SQLite parses the REFERENCES syntax but does not enforce it unless PRAGMA foreign_keys = ON is set for that connection","is_correct":true},{"id":"c","text":"No — SQLite doesn't support foreign key syntax at all","is_correct":false},{"id":"d","text":"Yes, but only for columns that are also INTEGER PRIMARY KEY","is_correct":false}],"explanation":"This is a well-known SQLite gotcha: REFERENCES is accepted and stored as metadata, but constraint enforcement is off by default and must be turned on per-connection with PRAGMA foreign_keys = ON."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('a0ab936a-57e0-519f-bde0-682a6d758283', '00000000-0000-0000-0000-000000000001', 'mcq', 'How do the row counts compare between `books INNER JOIN loans ON loans.book_i...', 'advanced', 3, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('daea6da7-b71f-5742-82ea-b72a09455126', 'a0ab936a-57e0-519f-bde0-682a6d758283', 1, $json${"prompt":"How do the row counts compare between `books INNER JOIN loans ON loans.book_id = books.id` and the same query with LEFT JOIN, given the seed data?","multiple":false,"options":[{"id":"a","text":"Both return 20 rows — every book has been loaned at least once","is_correct":false},{"id":"b","text":"INNER JOIN returns 20 rows (one per loan); LEFT JOIN returns 25 rows, adding one row per never-loaned book with loan columns as NULL","is_correct":true},{"id":"c","text":"INNER JOIN returns 15 rows (one per book); LEFT JOIN returns 20","is_correct":false},{"id":"d","text":"Both return exactly 15 rows, one per book","is_correct":false}],"explanation":"There are 20 loan rows total, so INNER JOIN produces 20 matched rows. 5 books (ids 3, 7, 12, 13, 14) were never loaned; LEFT JOIN still includes them, one row each with NULL loan columns, for 25 rows total."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('37272b09-4f6f-525c-853f-a6934e619ef9', '00000000-0000-0000-0000-000000000001', 'mcq', 'Which WHERE clause has a bug caused by AND/OR operator precedence, incorrectl...', 'advanced', 3, ARRAY['sql','databases','interview-prep'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('dae76970-a34b-5c37-b959-97e7127beaab', '37272b09-4f6f-525c-853f-a6934e619ef9', 1, $json${"prompt":"Which WHERE clause has a bug caused by AND/OR operator precedence, incorrectly including every Fantasy book (genre_id = 3) regardless of price?","multiple":false,"options":[{"id":"a","text":"WHERE price \u003c 15 AND genre_id = 1 OR genre_id = 3","is_correct":true},{"id":"b","text":"WHERE price \u003c 15 AND (genre_id = 1 OR genre_id = 3)","is_correct":false},{"id":"c","text":"WHERE price \u003c 15 AND genre_id IN (1, 3)","is_correct":false},{"id":"d","text":"WHERE genre_id IN (1, 3) AND price \u003c 15","is_correct":false}],"explanation":"AND binds more tightly than OR, so without parentheses `price \u003c 15 AND genre_id = 1 OR genre_id = 3` parses as `(price \u003c 15 AND genre_id = 1) OR genre_id = 3` — every Fantasy book is included no matter its price. Parenthesizing the OR, or using IN, avoids the bug."}$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;

INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)
VALUES ('3051448e-3ac4-5de4-9142-0ab52b7d3f25', '00000000-0000-0000-0000-000000000001', 'Final Assessment: SQL Mastery', 'sql-mastery-interview-ready-quiz', 'Quiz covering SQL for Interviews.', 'mcq', 'published', 'module', 'b395c65d-bb64-5d8c-ad58-297cd78ebfa6', 25, 70, 5, 25, true, true, true, true, '00000000-0000-0000-0000-000000000012', now())
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();

INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
('13685f52-88fe-585d-88bc-409213a8ee3b', '3051448e-3ac4-5de4-9142-0ab52b7d3f25', '897639d2-6192-57e4-8ecb-9a7bc7360335', 'bd948830-7203-54ba-bfbe-f629ebd6a022', 0, 2),
('a427c7e4-2b29-5cc2-809e-2d69eb35303e', '3051448e-3ac4-5de4-9142-0ab52b7d3f25', 'd2c02ef0-ff60-5a55-8699-91436d5d638d', 'db40933f-d5e7-5dbc-ac77-4de1c39e149b', 1, 2),
('2346bce1-c190-5513-83da-fd9c3f7fef9b', '3051448e-3ac4-5de4-9142-0ab52b7d3f25', 'ab26f027-2cab-5efd-9617-74238dc2385d', '1656f916-eb88-5db6-9a47-63e6177ba2a4', 2, 3),
('4dcb36a3-901e-5179-830d-0683f9e60eee', '3051448e-3ac4-5de4-9142-0ab52b7d3f25', 'cea15ff0-445c-516d-bbb8-a8d6529c375c', '24fab267-33c5-5c0c-81c2-2f18e69b367a', 3, 3),
('88868bb2-b496-544f-925f-8019c0a6fd02', '3051448e-3ac4-5de4-9142-0ab52b7d3f25', '75a37ce3-cf5c-5f0d-9eba-d18043e9f1fa', '5de76063-e12f-502d-b686-72933f6dd402', 4, 2),
('0433a56f-13dd-5e4f-bc43-f9a03473e4f0', '3051448e-3ac4-5de4-9142-0ab52b7d3f25', '3a9c87a2-ab5a-52f7-8c83-dd6e74982837', 'e19a0190-a24d-5ed6-ac37-caba100a62f7', 5, 2),
('3cbffbf2-49d6-5d6b-a179-451e10f27d1d', '3051448e-3ac4-5de4-9142-0ab52b7d3f25', '746e7b8d-a40e-55a8-8871-2f7b06663043', 'e5eaf92a-b04c-58bf-b881-cd55155e7783', 6, 2),
('9fbe0473-08fc-50ea-b5b4-7a3f2c9acae2', '3051448e-3ac4-5de4-9142-0ab52b7d3f25', '5b8f48fc-6a1e-50a2-b903-87c23eb9a6d0', '4d7f815c-709d-5da8-bd92-ce3e267f97fc', 7, 3),
('72a4167f-6be3-5269-bc44-b8475c3d8d4b', '3051448e-3ac4-5de4-9142-0ab52b7d3f25', 'a0ab936a-57e0-519f-bde0-682a6d758283', 'daea6da7-b71f-5742-82ea-b72a09455126', 8, 3),
('70ee30c6-62f6-509a-91ce-094d2a5609c8', '3051448e-3ac4-5de4-9142-0ab52b7d3f25', '37272b09-4f6f-525c-853f-a6934e619ef9', 'dae76970-a34b-5c37-b959-97e7127beaab', 9, 3)
ON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)
VALUES ('b395c65d-bb64-5d8c-ad58-297cd78ebfa6', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '6f6f149b-633c-5cfa-a03f-40ecfc1e7fd7', 'Final Assessment: SQL Mastery', 'assessment', 1, 20, '3051448e-3ac4-5de4-9142-0ab52b7d3f25')
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('126e0634-8a16-5ac5-8cef-bdc0d7926512', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '6f6f149b-633c-5cfa-a03f-40ecfc1e7fd7', 'Notes: SQL vs NoSQL', 'notes', 2, $md$Everything in this course has been relational SQL against a fixed schema — `books`, `authors`, `genres`, `members`, `loans`, each with declared columns and foreign keys tying them together. "SQL vs NoSQL" is one of the most common conceptual questions asked right alongside hands-on SQL, and it's really asking whether you understand *why* the library schema is shaped the way it is, not just how to query it.

## The core difference

A relational (SQL) database like the one this course uses requires a fixed schema up front — every `books` row has exactly the columns declared in `CREATE TABLE`, and every `loans` row must reference a real `book_id` and `member_id`. A NoSQL database (MongoDB, DynamoDB, Cassandra, Redis) drops that requirement — documents in the same collection can have completely different fields, and there's no schema-level guarantee that a reference actually points at something real.

| | SQL (this course) | NoSQL |
|---|---|---|
| Schema | Fixed — declared with `CREATE TABLE` | Flexible/dynamic — no upfront shape required |
| Relationships | Foreign keys + `JOIN` | Usually denormalized/embedded; joins are rare or absent |
| Consistency | ACID transactions (see the transactions section) | Often "eventual consistency" (BASE) instead |
| Scaling | Primarily vertical (bigger machine) | Primarily horizontal (more machines) |
| Examples | PostgreSQL, MySQL, SQLite (this course) | MongoDB, Cassandra, Redis, DynamoDB |

## Why this course's schema is relational, concretely

`loans.book_id` and `loans.member_id` only mean something because `books.id` and `members.id` are guaranteed to exist and be unique — that guarantee is exactly what a relational schema with foreign keys buys you, and exactly what a document store doesn't enforce by default. Denormalizing this same data into a NoSQL document store would typically mean embedding a copy of the book's title and the member's name directly inside each loan document, rather than referencing them by id — trading the `JOIN`s this course teaches for read speed and schema flexibility, at the cost of the single-source-of-truth guarantee normalization gives you (see the normalization note in Database & Table Design).

## When each is the right call

**Reach for SQL/relational** when:
- Data is naturally structured and relationships matter (this library schema is a textbook case: books have one author, loans reference exactly one book and one member)
- You need real transactions — the ACID guarantees covered in the Transactions & Concurrency section
- The query patterns aren't known in advance, and you want the flexibility of ad-hoc `JOIN`s/`GROUP BY` rather than data pre-shaped for one specific access pattern

**Reach for NoSQL** when:
- The data is naturally document-shaped or has no fixed structure across records
- Horizontal scale across many machines matters more than strict consistency
- Access patterns are known ahead of time and narrow enough that denormalized, pre-joined documents outperform relational joins at scale

## One-line interview answer

"SQL databases enforce a fixed schema and relationships through foreign keys, with strong ACID consistency — a good fit when data is structured and correctness matters, like this course's library schema. NoSQL trades that structure and consistency for flexible schemas and horizontal scale, which is the better fit at a scale or shape where relational joins become the bottleneck."

## Key takeaways

- The library schema this course uses (`books`/`authors`/`genres`/`members`/`loans` linked by foreign keys) is a relational design by nature — NoSQL would mean embedding/denormalizing that same data instead of referencing it.
- SQL: fixed schema, ACID transactions, joins. NoSQL: flexible schema, eventual consistency (BASE), horizontal scaling, joins rare or absent.
- This isn't "SQL is better" — it's a trade-off between consistency/structure and flexibility/scale, chosen based on the actual access pattern.
$md$, 15, $json$[]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO enrollments (id, user_id, course_id, enrolled_by)
VALUES ('3008a9b9-fd48-50a0-9aa6-06d300a965d6', '00000000-0000-0000-0000-000000000014', 'a4531b49-7973-5e3f-8659-8fcae686dbdd', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (user_id, course_id) DO NOTHING;

