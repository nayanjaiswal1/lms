---
kind: lesson
id_key: sql-mastery/dates-and-functions/lesson
course: sql-mastery
section: dates-and-functions
section_title: "Dates & Useful Functions"
section_position: 8
title: "Working with Dates, NULLs, and Comments"
position: 0
estimated_minutes: 25
source: [sql-mastery-curriculum.md]
---
Every date in this database — `books.published_year`, `members.joined_date`, `loans.loan_date`, `loans.return_date` — is stored as plain **text** in `YYYY-MM-DD` format (or a plain integer, for `published_year`). SQLite has no dedicated `DATE` or `DATETIME` type; it stores whatever you hand it and gives you a family of date *functions* that know how to parse ISO-8601 text. This is a real difference worth knowing for interviews: PostgreSQL, MySQL, and SQL Server all have native `DATE`/`DATETIME` column types with their own storage format and functions (`DATEDIFF`, `DATE_ADD`, and so on). In SQLite, a "date" is just a sortable string — which turns out to be more convenient than it sounds, as you'll see below.

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
