---
kind: lesson
id_key: sql-mastery/aggregation/lesson
course: sql-mastery
section: aggregation
section_title: "Aggregation"
section_position: 3
title: "Aggregate Functions and GROUP BY"
position: 0
estimated_minutes: 25
source: [sql-mastery-curriculum.md]
---
Filtering picks rows. **Aggregation** turns many rows into a single summary number — "how many books do we have," "what's the average price," "how many books per genre." That last kind of question needs `GROUP BY`, which is where aggregation gets genuinely powerful.

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
