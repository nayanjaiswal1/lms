---
kind: lesson
id_key: interview-prep-45/note-postgres-ltree-hierarchical-data
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: PostgreSQL ltree — Hierarchical Data & the Alternatives"
position: 112
estimated_minutes: 10
source:
    - interview-prep-notes.md
---

PostgreSQL indexing and query optimization are covered elsewhere in this course, but hierarchical or tree-shaped data (category trees, org charts, threaded comments) is a recurring modeling problem with no single obvious answer, and it isn't touched there. This note covers `ltree`, the PostgreSQL-specific extension built for it, plus the alternatives you'd reach for on databases that don't have it.

## `ltree`: label-path hierarchies

`ltree` is a PostgreSQL contrib extension: a data type for storing and querying tree-shaped data as dot-separated label paths, with index support that avoids recursive CTEs.

```sql
CREATE EXTENSION ltree;

CREATE TABLE categories (
    id   SERIAL PRIMARY KEY,
    path ltree
);

INSERT INTO categories (path) VALUES
  ('Top'), ('Top.Science'), ('Top.Science.Biology'),
  ('Top.Science.Physics'), ('Top.Arts'), ('Top.Arts.Music');
```

Key operators:

| Operator | Meaning | Example |
|---|---|---|
| `@>` | is ancestor of | `'Top' @> 'Top.Science'` returns true |
| `<@` | is descendant of | `'Top.Science' <@ 'Top'` returns true |
| `~` | match `lquery` pattern | `path ~ 'Top.Science.*'` |
| `?` | match any `lquery` in an array | `path ? array['Top.Arts.*'::lquery]` |

```sql
-- all descendants of Top.Science
SELECT path FROM categories WHERE path <@ 'Top.Science';

-- direct children only (exactly one level down)
SELECT path FROM categories WHERE path ~ 'Top.Science.*{1}';

-- all ancestors of a node
SELECT path FROM categories WHERE path @> 'Top.Science.Biology';
```

Tracing the first query: `path <@ 'Top.Science'` reads as "is this row's path a descendant of `Top.Science`." Postgres checks each stored path (`Top.Science.Biology`, `Top.Science.Physics`, and so on) against that condition and returns only the rows whose label path starts with `Top.Science` as a proper prefix of dot-separated labels, which is exactly the set of categories nested somewhere under Science.

For indexing, GiST supports every operator above (`@>`, `<@`, `~`, `?`), while a plain BTree index only helps with equality and sorting, not these tree-relationship operators:

```sql
CREATE INDEX idx_path_gist ON categories USING GIST (path);
```

An "extension" in Postgres is a plugin bundled with the server but inactive by default. `CREATE EXTENSION ltree` just turns it on per-database. Other common ones include `hstore` (key-value), `pgcrypto`, `pg_trgm` (fuzzy text search), PostGIS, and `uuid-ossp`.

`ltree` is Postgres-only. Other databases don't have a drop-in equivalent:

| Database | Closest approach |
|---|---|
| MySQL / MariaDB | No native equivalent; recursive CTEs or closure tables |
| Oracle | `CONNECT BY` / `SYS_CONNECT_BY_PATH` |
| SQL Server | `hierarchyid` (same idea, different syntax) |
| SQLite | No native support; manual implementation |

## Solving it without `ltree`

**Adjacency list.** Each row stores `parent_id`. Simple to write, but reading a whole subtree needs a recursive CTE:

```sql
WITH RECURSIVE tree AS (
  SELECT * FROM categories WHERE id = 2
  UNION ALL
  SELECT c.* FROM categories c JOIN tree t ON c.parent_id = t.id
)
SELECT * FROM tree;
```
This slows down on deep hierarchies, since every read re-walks the recursion from the root of the requested subtree down.

**Materialized path.** Store the path as plain text yourself, like `'1.4.10'`, and query with `LIKE '1.4.%'`. This is `ltree` without the extension: there's no operator or index support, so `LIKE` prefix scans replace what GiST would do, and the path has to be kept in sync by hand on every move of a node.

**Nested sets.** Store `lft`/`rgt` bounds per node, so descendants become a simple range query (`lft > 2 AND rgt < 11`). Reads are fast, but every insert, update, or move has to renumber the affected subtree's bounds, which gets expensive under write-heavy workloads.

| Approach | Read | Write | Query complexity |
|---|---|---|---|
| Adjacency list | Slow (recursion) | Easy | High |
| Materialized path | Medium | Manual upkeep | Medium (`LIKE` scans) |
| Nested sets | Fast | Costly (renumbering) | Low |
| `ltree` | Fast | Easy | Low |

The interview one-liner: `ltree` is a PostgreSQL extension that stores label-based tree paths and gives efficient ancestor/descendant queries via GiST indexes, avoiding hand-written recursive CTEs. The trade-off other databases face without it is recursion cost with an adjacency list versus write cost with nested sets, so pick based on the read/write ratio and expected hierarchy depth.
