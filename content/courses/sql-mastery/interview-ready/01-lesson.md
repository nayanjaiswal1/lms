---
kind: lesson
id_key: sql-mastery/interview-ready/lesson
course: sql-mastery
section: interview-ready
section_title: "SQL for Interviews"
section_position: 13
title: "Classic SQL Interview Patterns"
position: 0
estimated_minutes: 40
source: [sql-mastery-curriculum.md]
---
You've now covered every SQL building block this course teaches: `SELECT`, filtering, aggregation, every join type, data modification, subqueries, schema design, and dates. SQL interviews rarely test a single keyword in isolation — they test whether you recognize a handful of recurring *shapes* of problem and can reach for the right pattern under pressure. This lesson walks through five of the most common ones, each against the same library database you already know, followed by advice on how to talk through your reasoning out loud.

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
