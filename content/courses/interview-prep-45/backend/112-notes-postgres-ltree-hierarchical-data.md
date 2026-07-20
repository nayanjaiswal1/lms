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

Day 4-5 cover PostgreSQL indexing and query optimization but don't touch hierarchical/tree-shaped data — a recurring modeling problem (category trees, org charts, threaded comments) that has no single obvious answer. This note covers `ltree`, the PostgreSQL-specific extension built for it, plus the alternatives you'd reach for on databases that don't have it.

## `ltree`: label-path hierarchies

`ltree` is a **PostgreSQL contrib extension** — a data type for storing and querying tree-shaped data as dot-separated label paths, with index support that avoids recursive CTEs.

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

**Key operators:**

| Operator | Meaning | Example |
|---|---|---|
| `@>` | is ancestor of | `'Top' @> 'Top.Science'` → true |
| `<@` | is descendant of | `'Top.Science' <@ 'Top'` → true |
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

**Indexing:** GiST supports every operator above (`@>`, `<@`, `~`, `?`); BTree only helps with equality/sorting.

```sql
CREATE INDEX idx_path_gist ON categories USING GIST (path);
```

An "extension" in Postgres is a plugin bundled with the server but inactive by default — `CREATE EXTENSION ltree` just turns it on per-database. Other common ones: `hstore` (key-value), `pgcrypto`, `pg_trgm` (fuzzy text search), `PostGIS`, `uuid-ossp`.

**`ltree` is Postgres-only.** Other databases don't have a drop-in equivalent:

| Database | Closest approach |
|---|---|
| MySQL / MariaDB | No native equivalent — recursive CTEs or closure tables |
| Oracle | `CONNECT BY` / `SYS_CONNECT_BY_PATH` |
| SQL Server | `hierarchyid` (same idea, different syntax) |
| SQLite | No native support — manual implementation |

## Solving it without `ltree`

**1. Adjacency list** — each row stores `parent_id`. Simple to write, but reading a whole subtree needs a recursive CTE:

```sql
WITH RECURSIVE tree AS (
  SELECT * FROM categories WHERE id = 2
  UNION ALL
  SELECT c.* FROM categories c JOIN tree t ON c.parent_id = t.id
)
SELECT * FROM tree;
```
Slows down on deep hierarchies since every read re-walks the recursion.

**2. Materialized path** — store the path as plain text yourself (`'1.4.10'`), query with `LIKE '1.4.%'`. This is `ltree` without the extension: no operator/index support, so `LIKE` prefix scans replace what GiST would do, and the path has to be kept in sync manually on every move.

**3. Nested sets** — store `lft`/`rgt` bounds per node; descendants are a simple range query (`lft > 2 AND rgt < 11`). Fast reads, but every insert/update/move re-numbers the affected subtree — expensive under write-heavy workloads.

| Approach | Read | Write | Query complexity |
|---|---|---|---|
| Adjacency list | Slow (recursion) | Easy | High |
| Materialized path | Medium | Manual upkeep | Medium (`LIKE` scans) |
| Nested sets | Fast | Costly (renumbering) | Low |
| `ltree` | Fast | Easy | Low |

## Key takeaways

- `ltree` trades the general-purpose recursive-CTE approach for a purpose-built label-path type with GiST/GIN index support — fast ancestor/descendant queries without writing recursion yourself.
- It's Postgres-specific; on other engines the realistic choices are adjacency list + recursive query (simplest, worst on deep reads), materialized path (manual `ltree`), or nested sets (fastest reads, costly writes) — pick based on read/write ratio and hierarchy depth.
- Interview one-liner: *"`ltree` is a PostgreSQL extension that stores label-based tree paths and gives you efficient ancestor/descendant queries via GiST/GIN indexes, avoiding hand-written recursive CTEs — the tradeoff other databases face without it is recursion cost (adjacency list) vs. write cost (nested sets)."*
