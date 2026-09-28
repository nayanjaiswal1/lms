---
kind: lesson
id_key: interview-prep-45/day-28
course: interview-prep-45
section: lld
section_title: "Low-Level Design"
section_position: 5
title: "Database Design for LLD"
position: 17
estimated_minutes: 120
source:
    - 45-day-interview-roadmap.md
---

A database design interview tests a completely different muscle than an algorithms one. It's about modelling relationships correctly, knowing when spreading data across tables actually helps versus when it just gets in the way, and writing joins and subqueries fluently while someone watches. This lesson covers entity-relationship modelling, the normal forms, when it makes sense to deliberately break them, and hands-on schema and query practice using a blog as the running example.

## ER diagrams

An **entity-relationship diagram** models the real things a system needs to track — entities — and how they connect to each other. In an actual interview, you'll rarely draw a real diagram. You'll describe the entities, their fields, and how they relate, either out loud or directly as a schema.

**An entity is just a table** — `users`, `posts`, `comments`.

**How two entities relate — their cardinality — is the single decision that shapes your whole schema:**

| Cardinality | Example | What it means for the schema |
|---|---|---|
| One-to-one | `users` and `user_profiles` | A foreign key on either side works — usually the "detail" table holds it |
| One-to-many | `users` to `posts` | The foreign key lives on the "many" side (`posts.user_id`) |
| Many-to-many | `posts` and `tags` | You need a separate junction table (`post_tags`) holding both foreign keys |

```sql
-- One-to-many: a user has many posts
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    title VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Many-to-many: a post has many tags, and a tag applies to many posts
CREATE TABLE tags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE post_tags (
    post_id INTEGER NOT NULL REFERENCES posts(id),
    tag_id INTEGER NOT NULL REFERENCES tags(id),
    PRIMARY KEY (post_id, tag_id)
);
```

**Here's the tell interviewers watch for**: the moment you hear "many-to-many," you need a junction table. Trying to model it with a foreign key sitting directly on either side — say, a `tag_ids` array column — is the classic beginner mistake, and it also breaks the first normal form covered next.

> **Remember:** "many-to-many" always means a junction table with two foreign keys. There's no way around it.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-17-er-q1", "type": "mcq",
      "prompt": "You're modelling posts and tags, where a post can have many tags and a tag can apply to many posts. What's the right schema shape?",
      "options": [
        {"id":"a","text":"A `tag_ids` array column directly on the `posts` table"},
        {"id":"b","text":"A separate junction table, `post_tags`, holding a `post_id` and a `tag_id` together as its primary key"},
        {"id":"c","text":"A `post_id` column added directly onto the `tags` table"},
        {"id":"d","text":"Duplicate the tag's data into every post row that uses it"}
      ],
      "correct": "b",
      "explanation": "Any true many-to-many relationship needs a junction table with a foreign key pointing each way. An array column on one side is the classic beginner shortcut, and it breaks first normal form on top of everything else." }
] }
```

## Normalization: 1NF, 2NF, 3NF

Normalization is about removing repeated data by splitting it across related tables, with each normal form building directly on the one before it.

**1NF (first normal form): every column holds one single, plain value.** No repeating groups, and no comma-separated lists crammed into a single cell.

```sql
-- Breaks 1NF: tags crammed into one column
-- posts(id, title, tags)  --  tags = "tech,python,backend"

-- Follows 1NF: tags broken out into their own rows, through a junction table
-- posts(id, title)
-- tags(id, name)
-- post_tags(post_id, tag_id)
```

**2NF (second normal form): on top of 1NF, every non-key column has to depend on the *whole* primary key, not just part of it.** This one only matters when the primary key is made of more than one column.

```sql
-- Breaks 2NF: order_date really only depends on order_id, not on the full (order_id, product_id) key
-- order_items(order_id, product_id, quantity, order_date)

-- Follows 2NF: order_date moves to a table keyed only by order_id
-- orders(order_id, order_date)
-- order_items(order_id, product_id, quantity)
```

**3NF (third normal form): on top of 2NF, no non-key column should depend on another non-key column.** This is called a "transitive" dependency.

```sql
-- Breaks 3NF: city and zip_code depend on each other, not directly on user_id
-- users(id, name, zip_code, city)  -- city can be worked out from zip_code alone

-- Follows 3NF: city moves to its own table, keyed by zip_code
-- users(id, name, zip_code)
-- zip_codes(zip_code, city)
```

| Form | The rule | What it fixes |
|---|---|---|
| 1NF | Plain columns, no repeating groups | Comma-separated lists, arrays used as columns |
| 2NF | Non-key columns depend on the *whole* composite key | A column that only depends on part of the key |
| 3NF | Non-key columns depend only on the key, never on each other | A column that's derivable from another non-key column |

**In practice**: you don't have to say "this breaks 2NF" out loud every time, but you do need to design a schema that avoids these problems instinctively, and be ready to explain why a given schema is properly normalized if someone asks.

> **Remember:** 1NF is atomic columns. 2NF is depending on the whole key. 3NF is not depending on another non-key column. Each one builds on the last.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-17-normalization-q1", "type": "mcq",
      "prompt": "A `users` table has columns `id, name, zip_code, city`, where `city` can always be worked out from `zip_code`. Which normal form does this break?",
      "options": [
        {"id":"a","text":"1NF, because zip_code isn't atomic"},
        {"id":"b","text":"3NF — city depends on zip_code, which is itself a non-key column, rather than depending directly on the primary key. Moving city into its own table keyed by zip_code fixes it"},
        {"id":"c","text":"2NF, because the primary key isn't composite here"},
        {"id":"d","text":"Nothing — this is a perfectly normal design"}
      ],
      "correct": "b",
      "explanation": "This is exactly a transitive dependency: city depends on zip_code, and zip_code depends on the actual key (id), rather than city depending on id directly. 3NF is the rule that specifically rules this out." }
] }
```

## Denormalization trade-offs

Normalization optimizes for **correct writes and efficient storage** — update one place, with nothing duplicated anywhere. Denormalization deliberately brings some duplication back, in order to optimize for **read speed** instead, at the cost of more complicated writes and some risk of things drifting out of sync.

| | Normalized | Denormalized |
|---|---|---|
| Writes | Simple — one single source of truth | More complex — duplicated copies have to be kept in sync |
| Reads | Might need several joins | Fewer or no joins, faster on the hot read path |
| Storage | Minimal duplication | Some duplication, trading space for speed |
| Risk | None, from duplication at least | Data can quietly drift apart if an update misses a copy |

**When it's worth denormalizing**: a read-heavy path where the cost of a join is a real, measured bottleneck. For example, storing `comment_count` directly on the `posts` table, kept up to date by a trigger or in application code whenever a comment is added or removed, instead of running `COUNT(*)` against `comments` on every single page load. This is a normal, well-understood pattern in real systems, not a mistake. It's a deliberate trade-off, and the strongest answer names exactly *why* you're accepting the extra write-side complexity, for a specific, named read-side win — rather than denormalizing out of habit.

> **Remember:** denormalize only for a specific, named hot read path — and always say how you'll keep the duplicated copy in sync.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-17-denorm-q1", "type": "mcq",
      "prompt": "A blog stores `comment_count` directly on the `posts` table instead of always running `COUNT(*)` on `comments`. What's the correct way to think about this?",
      "options": [
        {"id":"a","text":"It's always a mistake, since it breaks normalization"},
        {"id":"b","text":"It's a deliberate trade-off: a specific hot read path (rendering the post list) gets faster, in exchange for having to keep the duplicated count in sync on every insert or delete — and it should be named as such, not applied by default"},
        {"id":"c","text":"It's required by 3NF"},
        {"id":"d","text":"It only matters for tables with more than a million rows"}
      ],
      "correct": "b",
      "explanation": "Denormalization is a genuine engineering trade-off, not an error. The strongest answer names exactly which read path it speeds up and exactly how the duplicated value gets kept in sync — rather than treating it as either always wrong or a free lunch." }
] }
```

## Designing a SQL schema

**The interview format is usually "design a schema for X"** — a blog, an e-commerce site, a ride-sharing app. The process is the same every time: list out the entities, decide on cardinalities, normalize to 3NF as your starting point, then call out any denormalization you're deliberately choosing for a known hot path.

**A worked example — a blog:**

```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    author_id INTEGER NOT NULL REFERENCES users(id),
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    published_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL REFERENCES posts(id),
    author_id INTEGER NOT NULL REFERENCES users(id),
    body TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE tags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE post_tags (
    post_id INTEGER NOT NULL REFERENCES posts(id),
    tag_id INTEGER NOT NULL REFERENCES tags(id),
    PRIMARY KEY (post_id, tag_id)
);

-- indexes for the access patterns you'll actually run
CREATE INDEX idx_posts_author ON posts(author_id);
CREATE INDEX idx_comments_post ON comments(post_id);
```

**Common mistakes to avoid**: forgetting foreign key constraints (`REFERENCES`), which lets orphaned rows pile up quietly; skipping indexes on foreign key columns, which turns a join on `posts.author_id` or `comments.post_id` into a full table scan; and not explicitly deciding cardinality before writing a single `CREATE TABLE` statement. Users to posts is one-to-many. Posts to tags is many-to-many. Get that settled first, and the actual table definitions follow directly from it.

> **Remember:** decide every relationship's cardinality before you write a single `CREATE TABLE` statement — the tables follow directly from that decision.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-17-schema-q1", "type": "mcq",
      "prompt": "You create `posts.author_id REFERENCES users(id)` but forget to add an index on `posts.author_id`. What actually happens?",
      "options": [
        {"id":"a","text":"Nothing — foreign keys are automatically indexed by every database"},
        {"id":"b","text":"A join or filter on `posts.author_id` degrades into a full table scan, since there's no index to look the value up quickly — foreign key columns need their own explicit index"},
        {"id":"c","text":"The foreign key constraint itself will simply fail to be created"},
        {"id":"d","text":"Inserts into `posts` become impossible"}
      ],
      "correct": "b",
      "explanation": "A `REFERENCES` clause enforces the relationship, but it doesn't automatically create an index for looking things up by that column. Without one, any query filtering or joining on `author_id` has to scan every single row in the table." }
] }
```

## Writing SQL queries

**Beyond just designing the schema**, you're expected to write correct, efficient queries against it. Aggregation, filtering, and ranking come up the most often.

```sql
-- Posts per user, most active authors first
SELECT u.username, COUNT(p.id) AS post_count
FROM users u
JOIN posts p ON p.author_id = u.id
GROUP BY u.username
ORDER BY post_count DESC;

-- Users who have never posted (a LEFT JOIN plus a NULL check)
SELECT u.username
FROM users u
LEFT JOIN posts p ON p.author_id = u.id
WHERE p.id IS NULL;

-- Posts with more than 5 comments
SELECT p.title, COUNT(c.id) AS comment_count
FROM posts p
JOIN comments c ON c.post_id = p.id
GROUP BY p.id, p.title
HAVING COUNT(c.id) > 5;
```

**Common mistakes**: using `WHERE` when you actually mean `HAVING` to filter on an aggregate. `WHERE` filters rows *before* they're grouped; `HAVING` filters groups *after* aggregation, and the two are not interchangeable. Also worth watching: in strict SQL modes, every non-aggregated column you select has to also appear in `GROUP BY` — `p.id, p.title` above, not just `p.title` on its own.

> **Remember:** `WHERE` filters rows before grouping happens. `HAVING` filters the groups afterward. They are never interchangeable.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-17-queries-q1", "type": "mcq",
      "prompt": "You want posts with more than 5 comments. Why does `WHERE COUNT(c.id) > 5` fail, while `HAVING COUNT(c.id) > 5` works?",
      "options": [
        {"id":"a","text":"`WHERE` and `HAVING` are actually interchangeable, and either one should work fine"},
        {"id":"b","text":"`WHERE` filters individual rows before any grouping happens, so the aggregate `COUNT(c.id)` doesn't exist yet at that point; `HAVING` filters the groups after aggregation, once the count is available"},
        {"id":"c","text":"`WHERE` only works on string columns"},
        {"id":"d","text":"`COUNT` can never appear inside a `WHERE` clause for any reason"}
      ],
      "correct": "b",
      "explanation": "This is the single most common SQL interview slip. Aggregates like COUNT only exist after GROUP BY has run, so filtering on them has to happen in HAVING, which runs after grouping — never in WHERE, which runs before it." }
] }
```

## Join exercises

**Four join types answer four different questions about how two tables relate.** Picking the wrong one is probably the most common SQL mistake in interviews.

| Join type | What it returns | Use it when |
|---|---|---|
| `INNER JOIN` | Only rows that have a match on both sides | You only care about pairs that exist in both tables |
| `LEFT JOIN` | Every row from the left table, matched or not (`NULL` on the right if there's no match) | "Show me everything, with related data attached where it exists" |
| `RIGHT JOIN` | Every row from the right table, matched or not | Rare in practice — usually just rewritten as a `LEFT JOIN` with the tables swapped |
| `FULL OUTER JOIN` | Every row from both tables, matched wherever possible | You need the unmatched rows from *both* sides at once |

```sql
-- INNER JOIN: only posts that actually have an author record
SELECT p.title, u.username
FROM posts p
INNER JOIN users u ON p.author_id = u.id;

-- LEFT JOIN: every post, with tag names where they exist (posts with no tags still show up)
SELECT p.title, t.name
FROM posts p
LEFT JOIN post_tags pt ON pt.post_id = p.id
LEFT JOIN tags t ON t.id = pt.tag_id;
```

**Common mistakes**: reaching for `LEFT JOIN` by default "just to be safe" when the question actually calls for an `INNER JOIN`. This quietly returns extra `NULL`-padded rows, which can silently break aggregation logic downstream — `COUNT(c.id)` will happily count a `NULL` from an unmatched `LEFT JOIN` if you forget an `IS NOT NULL` guard. Also watch for chaining several joins without checking whether each one might multiply your row count unexpectedly: joining `posts` to both `comments` and `post_tags` in the same query multiplies rows against each other, which is a classic, quiet bug.

> **Remember:** an `INNER JOIN` says "only pairs that exist on both sides." A `LEFT JOIN` says "everything on the left, matched or not." Picking the wrong one silently changes your results.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-17-joins-q1", "type": "mcq",
      "prompt": "You join `posts` to both `comments` and `post_tags` in one query to count comments per post. Why might the comment count come out wrong?",
      "options": [
        {"id":"a","text":"You can never join more than two tables in one query"},
        {"id":"b","text":"Joining to two separate one-to-many tables at once multiplies rows against each other — a post with 3 comments and 2 tags produces 6 joined rows, not 3, which silently inflates any COUNT you run on comments"},
        {"id":"c","text":"`post_tags` has to come before `comments` in the FROM clause"},
        {"id":"d","text":"LEFT JOIN can only be used once per query"}
      ],
      "correct": "b",
      "explanation": "Chaining joins against two independent one-to-many relationships multiplies row counts together — this is called a fan-out. It's a quiet, common bug, usually fixed by aggregating each relationship separately before combining them, or using a subquery for one side." }
] }
```

## Subqueries

**Subqueries let you filter or compute a result using another, smaller query's result set.** Sometimes it's the cleanest way to express "compare this against an aggregate." Other times, a join does the same job faster.

```sql
-- Posts by the single most prolific author (a subquery inside WHERE)
SELECT title
FROM posts
WHERE author_id = (
    SELECT author_id
    FROM posts
    GROUP BY author_id
    ORDER BY COUNT(*) DESC
    LIMIT 1
);

-- Users whose post count is above the overall average
SELECT u.username
FROM users u
WHERE (
    SELECT COUNT(*) FROM posts p WHERE p.author_id = u.id
) > (
    SELECT AVG(post_count) FROM (
        SELECT COUNT(*) AS post_count FROM posts GROUP BY author_id
    ) counts
);

-- The same result, written as a CTE — often easier to read than nested subqueries
WITH post_counts AS (
    SELECT author_id, COUNT(*) AS post_count
    FROM posts
    GROUP BY author_id
)
SELECT u.username
FROM users u
JOIN post_counts pc ON pc.author_id = u.id
WHERE pc.post_count > (SELECT AVG(post_count) FROM post_counts);
```

**Common mistakes**: writing a **correlated subquery** — one that references a value from the outer query, so it re-runs once per outer row — when an uncorrelated subquery or a plain join would do the exact same job. Correlated subqueries can genuinely become a serious performance problem on a large table, since they run over and over. It's also worth reaching for a CTE (`WITH ... AS`) whenever nested subqueries start getting hard to read, especially if the same subquery result is needed more than once in the same outer query.

> **Remember:** a correlated subquery re-runs once for every single outer row. On a large table, that's a real performance problem, not just a style preference.

```knowledge-check
{ "questions": [
    { "id": "ip45-lld-17-subquery-q1", "type": "mcq",
      "prompt": "Why can a correlated subquery become a serious performance problem on a large table?",
      "options": [
        {"id":"a","text":"Correlated subqueries always return the wrong result"},
        {"id":"b","text":"A correlated subquery references a value from the outer query, so the database has to re-run it once for every single outer row — on a large table that adds up fast, whereas an uncorrelated subquery or a join runs only once"},
        {"id":"c","text":"Correlated subqueries can't use aggregate functions"},
        {"id":"d","text":"Correlated subqueries only work inside a WHERE clause"}
      ],
      "correct": "b",
      "explanation": "The defining trait of a correlated subquery is that it depends on the outer row, so it has to be re-evaluated for every single one of them. An uncorrelated subquery, or an equivalent join, is computed just once and reused, which is usually far faster on a large table." }
] }
```

## Quick recap

- Relationship cardinality decides your schema's shape before you write a single line of DDL. Many-to-many always needs a junction table, and 1NF, 2NF, and 3NF build directly on each other: atomic columns first, then full-key dependency, then no dependency between two non-key columns.
- Denormalization is a deliberate trade-off for a specific, named read-heavy path — never a default. Always name exactly which reads you're speeding up, and exactly how you'll keep the duplicated data in sync.
- The two most common SQL slips in interviews are mixing up `WHERE` (filters rows before grouping) with `HAVING` (filters groups after aggregation), and reaching for `LEFT JOIN` "just to be safe" when an `INNER JOIN` is what the question actually calls for — which quietly changes the result and can corrupt an aggregate count.
