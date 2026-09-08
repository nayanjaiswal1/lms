---
kind: lesson
id_key: interview-prep-45/day-28
course: interview-prep-45
section: system-design
section_title: "System Design"
section_position: 2
title: "Database Design (LLD)"
position: 30
estimated_minutes: 120
source:
    - 45-day-interview-roadmap.md
---

Database design interviews test a different muscle than algorithms: modeling relationships correctly, knowing when normalization helps vs hurts, and writing joins/subqueries fluently under time pressure. Today covers ER modeling, the normal forms, denormalization trade-offs, and hands-on schema + query practice using a blog system as the running example.

## ER diagrams

An **Entity-Relationship diagram** models the real-world things (entities) a system tracks and how they relate. In interviews you rarely draw an actual diagram; you describe entities, their attributes, and relationship cardinality out loud or in a schema.

**Entity:** a table, e.g., `users`, `posts`, `comments`.

**Relationship cardinality** is the critical decision that shapes your schema:

| Cardinality | Example | Schema implication |
|---|---|---|
| One-to-one | `users` ↔ `user_profiles` | Foreign key on either side (usually the "detail" table holds the FK) |
| One-to-many | `users` → `posts` | Foreign key lives on the "many" side (`posts.user_id`) |
| Many-to-many | `posts` ↔ `tags` | Requires a junction/join table (`post_tags`) with two foreign keys |

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

-- Many-to-many: posts have many tags, tags apply to many posts
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

**The interview tell:** whenever you see "many-to-many," you need a junction table. Trying to model it with a foreign key on either "side" table directly (e.g., a `tag_ids` array column) is the classic beginner mistake and a normalization violation (see 1NF below).

## Normalization (1NF, 2NF, 3NF)

Normalization removes redundancy by splitting data into related tables, each normal form building on the previous.

**1NF (First Normal Form):** every column holds a single atomic value. No repeating groups, no comma-separated lists in one cell.

```sql
-- Violates 1NF: tags crammed into one column
-- posts(id, title, tags)  --  tags = "tech,python,backend"

-- Satisfies 1NF: tags broken into their own rows via a junction table
-- posts(id, title)
-- tags(id, name)
-- post_tags(post_id, tag_id)
```

**2NF (Second Normal Form):** must satisfy 1NF, and every non-key column depends on the **whole** primary key, not just part of it. Only relevant when the primary key is composite.

```sql
-- Violates 2NF: order_date depends only on order_id, not the full (order_id, product_id) key
-- order_items(order_id, product_id, quantity, order_date)

-- Satisfies 2NF: order_date moved to a table keyed only by order_id
-- orders(order_id, order_date)
-- order_items(order_id, product_id, quantity)
```

**3NF (Third Normal Form):** must satisfy 2NF, and no non-key column depends on another non-key column (no "transitive" dependency).

```sql
-- Violates 3NF: city and zip_code depend on each other, not directly on user_id
-- users(id, name, zip_code, city)  -- city is derivable from zip_code

-- Satisfies 3NF: city moved to a table keyed by zip_code
-- users(id, name, zip_code)
-- zip_codes(zip_code, city)
```

| Form | Rule | Fixes |
|---|---|---|
| 1NF | Atomic columns, no repeating groups | Comma-separated lists, arrays-as-columns |
| 2NF | Non-key columns depend on the *whole* composite key | Partial key dependency |
| 3NF | Non-key columns depend only on the key, not on each other | Transitive dependency |

**In an interview:** you don't need to cite "this violates 2NF" by name every time, but you do need to design a schema that avoids these issues instinctively, and be able to explain why a given design is normalized when asked.

## Denormalization trade-offs

Normalization optimizes for **write correctness and storage efficiency** (update one place, no duplication). Denormalization intentionally reintroduces redundancy to optimize for **read performance**, at the cost of write complexity and consistency risk.

| | Normalized | Denormalized |
|---|---|---|
| Writes | Simple, single source of truth | More complex; must keep duplicated data in sync |
| Reads | May require multiple joins | Fewer/no joins, faster for hot read paths |
| Storage | Minimal redundancy | Redundant data trades space for speed |
| Risk | None from redundancy | Data can drift out of sync if updates miss a copy |

**When to denormalize:** a read-heavy path where join cost is measurably a bottleneck. For example, storing `comment_count` directly on the `posts` table (updated via trigger or application logic on insert/delete) instead of running `COUNT(*)` on `comments` every time a post list renders. This is a common real-world pattern, not a violation of good design. It's a deliberate trade-off, and the interview answer is strongest when you name why you're accepting the write-side complexity for a specific read-side win, rather than denormalizing by default.

## Design SQL Schema (various)

**Intuition:** The interview format is usually "design a schema for X" (blog, e-commerce, ride-sharing). The process is the same every time: list entities, decide cardinalities, normalize to 3NF as a starting point, then call out any deliberate denormalization for known hot paths.

**Approach, worked example, blog system:**

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

-- indexes for common access patterns
CREATE INDEX idx_posts_author ON posts(author_id);
CREATE INDEX idx_comments_post ON comments(post_id);
```

**Common mistakes:** Forgetting foreign key constraints (`REFERENCES`), which lets orphaned rows accumulate; skipping indexes on foreign key columns (joins on `posts.author_id` or `comments.post_id` will be full table scans without them); not deciding cardinality explicitly before writing `CREATE TABLE` statements. Users to posts is one-to-many, posts to tags is many-to-many. Get this right first and the DDL follows directly.

## SQL queries for typical problems

**Intuition:** Beyond schema design, you're expected to write correct, efficient queries against a given schema. Aggregations, filtering, and ranking are the most common asks.

```sql
-- Posts per user, most active authors first
SELECT u.username, COUNT(p.id) AS post_count
FROM users u
JOIN posts p ON p.author_id = u.id
GROUP BY u.username
ORDER BY post_count DESC;

-- Users who have never posted (LEFT JOIN + NULL check)
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

**Common mistakes:** Using `WHERE` instead of `HAVING` to filter on an aggregate: `WHERE` filters rows before grouping, `HAVING` filters groups after aggregation, and they are not interchangeable. Also, forgetting `GROUP BY` must include every non-aggregated selected column (`p.id, p.title` above, not just `p.title`, in strict SQL modes).

## Join exercises

**Intuition:** Four join types answer four different questions about how two tables relate. Picking the wrong one is the most common SQL interview mistake.

| Join type | Returns | Use when |
|---|---|---|
| `INNER JOIN` | Only rows with matches in both tables | You only care about pairs that exist on both sides |
| `LEFT JOIN` | All rows from the left table, matched or not (`NULL` on the right if unmatched) | "Show me everything, with related data if it exists" |
| `RIGHT JOIN` | All rows from the right table, matched or not | Rare in practice, usually rewritten as a `LEFT JOIN` with tables swapped |
| `FULL OUTER JOIN` | All rows from both tables, matched where possible | You need unmatched rows from *both* sides |

```sql
-- INNER JOIN: only posts that have an author record
SELECT p.title, u.username
FROM posts p
INNER JOIN users u ON p.author_id = u.id;

-- LEFT JOIN: every post, with tag names where tags exist (posts without tags still appear)
SELECT p.title, t.name
FROM posts p
LEFT JOIN post_tags pt ON pt.post_id = p.id
LEFT JOIN tags t ON t.id = pt.tag_id;
```

**Common mistakes:** Reaching for `LEFT JOIN` by default "to be safe" when an `INNER JOIN` is what the question actually asks for. This silently returns extra `NULL`-padded rows that can break downstream aggregation logic (`COUNT(c.id)` counting a `NULL` from an unmatched `LEFT JOIN` if you forget the `IS NOT NULL` guard). Also, chaining multiple joins without checking whether each one could fan out row counts unexpectedly: joining `posts` to both `comments` and `post_tags` in the same query multiplies rows, a classic silent bug.

## Subquery practice

**Intuition:** Subqueries let you filter or compute using an intermediate result set. Sometimes it's the only clean way to express "compare against an aggregate," sometimes it's replaceable by a join for better performance.

```sql
-- Posts by the most prolific author (subquery in WHERE)
SELECT title
FROM posts
WHERE author_id = (
    SELECT author_id
    FROM posts
    GROUP BY author_id
    ORDER BY COUNT(*) DESC
    LIMIT 1
);

-- Users whose post count is above the average (correlated-free subquery)
SELECT u.username
FROM users u
WHERE (
    SELECT COUNT(*) FROM posts p WHERE p.author_id = u.id
) > (
    SELECT AVG(post_count) FROM (
        SELECT COUNT(*) AS post_count FROM posts GROUP BY author_id
    ) counts
);

-- Same result via CTE (often more readable than nested subqueries)
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

**Common mistakes:** Writing a **correlated subquery** (one that references the outer query's row on every evaluation) when an uncorrelated one or a join would work. Correlated subqueries re-execute once per outer row and can be a serious performance problem on large tables. Also worth considering: a CTE (`WITH ... AS`) as a readability upgrade over deeply nested subqueries, especially when the same subquery result is needed more than once in the outer query.

## Key takeaways

- Relationship cardinality determines your schema shape before you write any DDL. Many-to-many always needs a junction table, and 1NF/2NF/3NF build on each other: atomic columns, then full-key dependency, then no transitive dependency between non-key columns.
- Denormalization is a deliberate read-performance trade-off for a specific hot path, not a default. Always name which reads you're optimizing for and how you'll keep the duplicated data consistent.
- The two most common SQL interview slips are mixing up `WHERE` (filters rows before grouping) with `HAVING` (filters groups after aggregation), and defaulting to `LEFT JOIN` "to be safe" when an `INNER JOIN` is what the question actually calls for, which silently changes result semantics and can corrupt aggregate counts.
