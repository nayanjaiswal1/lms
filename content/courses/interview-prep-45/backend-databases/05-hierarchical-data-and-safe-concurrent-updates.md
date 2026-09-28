---
kind: lesson
id_key: interview-prep-45/db-hierarchical-data
course: interview-prep-45
section: backend-databases
section_title: "Databases (PostgreSQL)"
section_position: 9
section_group: "Backend"
title: "Hierarchical Data and Safe Concurrent Updates"
position: 5
estimated_minutes: 45
source:
    - interview-prep-notes.md
---

A category tree, an org chart, a threaded comment section: these are all the same shape, a hierarchy, and a database table with a flat list of rows is not naturally built for it. This lesson covers `ltree`, Postgres's own extension for tree-shaped data, then a set of concurrency-safety decisions that show up the moment you combine a tree with role-based permissions and real, simultaneous writers. This is the kind of "how did you actually handle X" follow-up that separates someone who has read about a topic from someone who has shipped it.

## Storing a tree: ltree and the alternatives

`ltree` is a Postgres extension: a data type for tree-shaped data stored as dot-separated label paths, with real index support so you don't need a recursive query to walk it.

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

| Operator | Meaning | Example |
|---|---|---|
| `@>` | is ancestor of | `'Top' @> 'Top.Science'` is true |
| `<@` | is descendant of | `'Top.Science' <@ 'Top'` is true |
| `~` | matches a pattern | `path ~ 'Top.Science.*'` |

```sql
-- every descendant of Top.Science
SELECT path FROM categories WHERE path <@ 'Top.Science';

-- direct children only, exactly one level down
SELECT path FROM categories WHERE path ~ 'Top.Science.*{1}';
```

Read that first query as: "is this row's path a descendant of `Top.Science`?" Postgres checks each stored path and keeps only the ones nested somewhere underneath it. An index type called GiST supports every one of these tree operators, while a plain B-tree index only helps with equality and sorting, not "is this an ancestor of that":

```sql
CREATE INDEX idx_path_gist ON categories USING GIST (path);
```

`ltree` is Postgres-only. Without it, three other approaches exist, each with a different trade-off:

| Approach | Read | Write | Notes |
|---|---|---|---|
| Adjacency list (`parent_id` on each row) | Slow, needs a recursive query | Easy | Simple to write, but re-walks the tree from scratch on every read |
| Materialized path (`'1.4.10'` as plain text, `LIKE '1.4.%'`) | Medium | Manual upkeep | Same idea as `ltree`, without an index built for it |
| Nested sets (`lft`/`rgt` bounds per node) | Fast, a simple range query | Costly | Every insert or move has to renumber the affected subtree |

The interview answer: `ltree` stores label-based tree paths and gives fast ancestor/descendant queries through a GiST index, avoiding a hand-written recursive query. Without it, you're choosing between recursion cost (adjacency list) and write cost (nested sets), so the right pick depends on your read/write ratio.

> **Remember:** `ltree` is a Postgres extension for tree paths with GiST-indexed ancestor/descendant queries. An adjacency list is easy to write but slow to read deep; nested sets are fast to read but expensive to write.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-hierarchical-ltree-q1", "type": "mcq",
      "prompt": "Why does a plain B-tree index on an ltree column fail to speed up an 'is this a descendant of X' query?",
      "options": [
        {"id":"a","text":"A B-tree only supports equality and sorting; it doesn't understand tree-relationship operators like <@ and @>, which need a GiST index instead"},
        {"id":"b","text":"ltree columns cannot be indexed at all"},
        {"id":"c","text":"B-tree indexes are always slower than GiST for every kind of query"},
        {"id":"d","text":"Descendant queries do not use indexes in Postgres under any circumstances"}
      ],
      "correct": "a",
      "explanation": "A B-tree is built for equality and ordering comparisons. Ancestor/descendant checks are structural relationships that need GiST, which is why ltree columns are indexed with USING GIST, not a default B-tree." }
] }
```

## Advisory checks vs authoritative triggers

This is the pattern that repeats through everything else in this lesson: **application-level validation is advisory. A database constraint that runs inside the same transaction as the write is authoritative.**

Python code cannot make a check-then-write sequence safe under concurrency without external locking, because two requests can both pass the check before either one commits.

```python
# Advisory only — a race window exists between this check and the actual save()
def clean(self):
    if self._would_create_cycle():
        raise ValidationError("cycle detected")
```

```sql
-- Authoritative — runs inside the same transaction as the INSERT/UPDATE, no race window
CREATE OR REPLACE FUNCTION check_no_cycle() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.hierarchy_path <@ (SELECT parent_path FROM org_units WHERE id = NEW.parent_id) THEN
    RAISE EXCEPTION 'cycle detected: % would become an ancestor of itself', NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

Here's the race the Python-only version misses: two concurrent requests can each call `clean()`, each find no cycle because neither has committed yet, and both proceed to save. Together they create a cycle that neither individual check ever saw. A Postgres trigger runs inside the same transaction as the write itself, so it's the only place this check is actually race-free.

Keep the Python check anyway. It gives a fast, friendly error in the common case, while the trigger is the backstop for the case where two requests land at nearly the same instant.

The same split shows up anywhere you need a guarantee that holds no matter what wrote the data. Blocking `UPDATE`/`DELETE` inside a model's `save()`/`delete()` methods only works if every write goes through the ORM; a raw SQL client bypasses it completely. An audit log that must truly never change needs a Postgres trigger that rejects any `UPDATE`/`DELETE` outright, on top of the Django-layer guard:

```sql
CREATE OR REPLACE FUNCTION prevent_audit_mutation() RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'audit_log rows are immutable';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_immutable_update BEFORE UPDATE ON audit_log
  FOR EACH ROW EXECUTE FUNCTION prevent_audit_mutation();
```

> **Remember:** an app-level check and a database trigger are not doing the same job. The check is a fast, friendly error for the common case; the trigger is the only thing that's actually race-free.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-hierarchical-triggers-q1", "type": "mcq",
      "prompt": "Two concurrent requests each call a Python clean() method that checks for a cycle before saving. Why can a cycle still get created?",
      "options": [
        {"id":"a","text":"Python's clean() method always has a bug"},
        {"id":"b","text":"Both requests can run their check before either one commits, so each sees no cycle, and then both save, together creating one that neither check individually saw"},
        {"id":"c","text":"Django does not support cycle detection"},
        {"id":"d","text":"This can never actually happen in practice"}
      ],
      "correct": "b",
      "explanation": "An application-level check-then-write has a race window unless something serializes the two requests. A database trigger closes that window because it runs inside the same transaction as the write itself." }
] }
```

## Scoped roles over a hierarchy: additive, not precedence

When a role can be granted at any node of a tree, for example a role at `/company/sales` and a different role at `/company/sales/india`, you have to decide: do overlapping grants combine, or does the more specific one win?

**Decision: additive (union) semantics, no precedence.** A user with a role at `/company/sales` and a different role at `/company/sales/india` gets the union of both roles' permissions inside `/company/sales/india`. This is simpler to reason about and to audit: "why can this user do X" is always "some ancestor scope granted it," never "which of two conflicting grants wins." Precedence can be added later through a priority field without breaking any existing grant, so leaving it out now is a safe thing to defer, not a corner you're cutting.

> **Remember:** overlapping scoped roles add up; they don't override each other. That keeps "why can this user do X" answerable with one sentence instead of a precedence table.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-hierarchical-scoped-q1", "type": "mcq",
      "prompt": "A user has one role granted at /company/sales and a different role granted at /company/sales/india. Under additive scoped-role semantics, what permissions do they have inside /company/sales/india?",
      "options": [
        {"id":"a","text":"Only the permissions from the more specific /company/sales/india role"},
        {"id":"b","text":"The union of both roles' permissions, since ancestor and descendant scopes combine rather than override each other"},
        {"id":"c","text":"Only the permissions from the /company/sales role"},
        {"id":"d","text":"Neither role applies because they conflict"}
      ],
      "correct": "b",
      "explanation": "Additive semantics mean every scope that covers a given node contributes its permissions. There's no precedence to resolve, so the answer is always the union of every applicable grant." }
] }
```

## Locking a subtree: lock the root, not every row

Moving or soft-deleting a subtree needs to stop two concurrent operations from touching the same subtree at once. Locking the *entire descendant set* with `select_for_update()` can hold thousands of row locks for the whole transaction, blocking unrelated reads on nodes that were never actually in conflict.

The fix: **lock only the subtree root.** The bulk `UPDATE` that follows acquires its own row locks as it goes, which is all it needs, since you don't have to pre-lock what the update will lock anyway.

```python
def move_subtree(self, new_parent):
    with transaction.atomic():
        # .exists() forces the query to actually run — a lazy queryset locks nothing
        OrgUnit.objects.select_for_update().filter(id=self.id).exists()
        ...
```

Two concrete bugs hide in that one line if you're not careful. First, a `select_for_update()` queryset that's never evaluated, never iterated or checked with `.exists()`, sends no lock request to Postgres at all: the lock silently does nothing. Second, locking every descendant instead of just the root is far more expensive than it needs to be for the same correctness.

> **Remember:** lock the subtree root, not every descendant. A `select_for_update()` queryset does nothing until something forces it to actually run, like `.exists()`.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-hierarchical-locking-q1", "type": "mcq",
      "prompt": "Why is calling OrgUnit.objects.select_for_update().filter(id=self.id) alone, without .exists() or iterating it, a silent bug?",
      "options": [
        {"id":"a","text":"It raises an exception immediately"},
        {"id":"b","text":"A queryset is lazy: it sends no query to Postgres, and therefore requests no lock, until something forces it to evaluate"},
        {"id":"c","text":"select_for_update() only works inside Celery tasks"},
        {"id":"d","text":"It locks every row in the entire table instead of just one"}
      ],
      "correct": "b",
      "explanation": "Django querysets don't hit the database until evaluated. A select_for_update() call that's never iterated or checked never actually runs, so no lock is ever taken, and the code silently isn't safe under concurrency." }
] }
```

## Soft delete, expiring grants, and the partial index Postgres won't let you write

A naive "currently active" query on a scoped role filters only `deleted_at IS NULL`. But a role assignment with a past `expires_at` looks soft-deleted in every way that matters, without actually being soft-deleted, and it still passes that filter, silently granting access that should have lapsed.

The fix is one canonical queryset method that every permission check goes through, instead of trusting every call site to remember both conditions:

```python
class ScopedRoleAssignmentQuerySet(models.QuerySet):
    def currently_active(self):
        return self.filter(
            models.Q(expires_at__isnull=True) | models.Q(expires_at__gt=timezone.now())
        )
```

This is the same "one blessed path, not a convention every caller has to remember" principle as a shared response helper or a single auth-check function. A permission leak from a forgotten `.filter()` is a security bug, not a style nit.

A related trap: `ActiveManager.get_queryset()` returning a plain `models.QuerySet` looks fine until someone chains `.filter(...).delete()`. The *type* of the returned queryset decides whether that `.delete()` does a soft delete or a real SQL `DELETE`. Building the manager from a custom queryset subclass keeps soft-delete semantics all the way down any chain:

```python
class SoftDeleteQuerySet(models.QuerySet):
    def delete(self):
        return self.update(deleted_at=timezone.now(), updated_at=timezone.now())
    def hard_delete(self):
        return super().delete()

ActiveManager = models.Manager.from_queryset(SoftDeleteQuerySet)
```

Django's `auto_now=True` only fires on `.save()`. A bulk `.update()`, which any queryset-level soft delete has to use, silently skips it. Any custom `.delete()` override on a queryset has to set `updated_at` explicitly, or every soft-deleted row ends up with a stale timestamp.

Now the indexing question: a composite index on `(user_id, deleted_at)` still leaves `expires_at` as a check done after the index scan. The instinct is a partial index with `WHERE expires_at > now()`. Postgres rejects this, because a partial index's condition is evaluated once, at the moment the index is defined, and `now()` changes every time it's called, so it can never be an immutable condition. The workable partial index instead targets the *permanent* grants, which have no time-based condition at all:

```sql
CREATE INDEX scoped_role_user_permanent_active_idx
  ON scoped_role_assignment (user_id)
  WHERE deleted_at IS NULL AND expires_at IS NULL;
```

Grants that do expire fall back to the regular composite index. Being able to explain *why* they can't get the same partial-index treatment is the actually interview-worthy part of this answer, not just knowing partial indexes exist.

> **Remember:** a partial index's `WHERE` clause must be immutable. `expires_at > now()` fails that test, since `now()` changes every call; only a condition on fixed columns like `expires_at IS NULL` works.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-hierarchical-partialindex-q1", "type": "mcq",
      "prompt": "Why does Postgres reject a partial index with the condition WHERE expires_at > now()?",
      "options": [
        {"id":"a","text":"Partial indexes cannot use comparison operators"},
        {"id":"b","text":"A partial index's condition is fixed once, at definition time, but now() returns a different value on every call, so it can never be a stable, immutable condition"},
        {"id":"c","text":"expires_at is not allowed to be indexed at all"},
        {"id":"d","text":"Postgres actually allows this; the example is describing a nonexistent restriction"}
      ],
      "correct": "b",
      "explanation": "A partial index needs a condition that's true or false forever once the index is built. now() is not immutable, so Postgres can't evaluate it once and rely on that answer staying correct. A condition on fixed columns, like expires_at IS NULL, works fine." }
] }
```
