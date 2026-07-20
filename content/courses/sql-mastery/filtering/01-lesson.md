---
kind: lesson
id_key: sql-mastery/filtering/lesson
course: sql-mastery
section: filtering
section_title: "Filtering & Sorting"
section_position: 2
title: "Filtering Rows with WHERE and Sorting with ORDER BY"
position: 0
estimated_minutes: 30
source: [sql-mastery-curriculum.md]
---
So far every query has returned *every* row in a table. Real questions are narrower — "which books cost less than $12," "which members joined from Paris." `WHERE` picks rows; `ORDER BY` decides what order they come back in. Both work on the same library schema from the last lesson.

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
