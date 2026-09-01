---
kind: lesson
id_key: interview-prep-45/note-rbac-hierarchical-concurrency-safety
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: RBAC + Hierarchical Data — Concurrency-Safe Design Decisions"
position: 114
estimated_minutes: 20
source:
    - interview-prep-notes.md
---

This course covers what RBAC *is* (roles vs. permissions vs. bearer tokens) and covers `ltree` as a hierarchy-storage mechanism elsewhere, but neither covers what happens when you combine them in a real system: scoped roles over a tree-shaped org structure, under concurrent writes. This note is a distilled set of architectural decisions from a production RBAC-plus-hierarchy build, the kind of "how did you handle X" follow-up that separates a candidate who's read about RBAC from one who's shipped it.

## Advisory checks vs authoritative triggers: the core pattern

The recurring shape across every decision below is that **application-level validation is advisory, and the database constraint is authoritative.** Python (or any app-layer) code cannot make a check-then-write sequence concurrency-safe without external locking, because two requests can both pass the check before either commits. A database trigger or constraint that runs *inside the same transaction as the write* closes that window.

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

The race the Python-only version misses: two concurrent requests can each call `clean()`, each find no cycle (because neither has committed yet), and each then proceed to save, together creating a cycle that neither individual check ever saw. The interview framing: Python-level validation cannot be made concurrency-safe without serializing all writes through a single process, whereas a Postgres trigger runs inside the same transaction as the mutation, so it's the only place a cycle check is actually race-free. Keep the Python check anyway. It gives a fast, friendly error in the common case, while the trigger is the backstop for the concurrent case.

## Scoped RBAC: additive overlap, not precedence

When roles can be assigned at any node of an org tree (a role at `/company/sales` and another at `/company/sales/india`), the design question is whether overlapping grants combine, or whether the more specific one wins.

**Decision: additive (union) semantics, no precedence model.** A user with a role at `/company/sales` and a different role at `/company/sales/india` gets the union of both roles' permissions inside `/company/sales/india`. This is simpler to reason about and to audit: "why can this user do X" is always "some ancestor scope granted it," never "which of these two conflicting grants wins." Precedence can be added later via a `priority` field without breaking any existing grant, so leaving it out for now is a safe thing to defer rather than a corner cut.

## The query most systems get wrong: filtering "currently active" grants

A naive scoped-role query filters only `deleted_at IS NULL`. But a role assignment with a past `expires_at` is soft-deleted-looking, not actually deleted, and still passes that filter, silently granting access that should have lapsed. The fix is a single canonical queryset method (`currently_active()`) that every permission check must go through, rather than trusting every call site to remember both conditions:

```python
class ScopedRoleAssignmentQuerySet(models.QuerySet):
    def currently_active(self):
        return self.filter(
            models.Q(expires_at__isnull=True) | models.Q(expires_at__gt=timezone.now())
        )
```

This is the same "one blessed path, not a convention every caller has to remember" principle as a shared response helper or a single auth-check function. A permission leak from a forgotten `.filter()` is a security bug, not a style nit.

## Soft delete breaks chained querysets unless the manager is built right

`ActiveManager.get_queryset()` returning a plain `models.QuerySet` looks fine until someone chains `.filter(...).delete()`. The *type* of the returned queryset determines whether `.delete()` does a soft delete or a real SQL `DELETE`. The fix is to build the manager from a custom `QuerySet` subclass, so every chained call preserves soft-delete semantics all the way down:

```python
class SoftDeleteQuerySet(models.QuerySet):
    def delete(self):
        return self.update(deleted_at=timezone.now(), updated_at=timezone.now())  # bulk soft delete
    def hard_delete(self):
        return super().delete()

ActiveManager = models.Manager.from_queryset(SoftDeleteQuerySet)
```

The trap this avoids: Django's `auto_now=True` only fires on `.save()`. A bulk `.update()` call, which is what a queryset-level soft delete has to use, silently skips it. Any custom `.delete()` override on a queryset must set `updated_at` explicitly, or every soft-deleted row ends up with a stale `updated_at`.

## Locking a subtree: lock the root, not every descendant

Moving or soft-deleting a subtree needs to serialize concurrent operations on that same subtree. But `select_for_update()` on the *entire descendant set* can hold thousands of row locks for the whole transaction, blocking unrelated reads on nodes that aren't even involved in the conflict. The fix is to **lock only the subtree root** to serialize concurrent callers; the bulk `UPDATE` that follows acquires its own row locks atomically as it touches each row, which is sufficient, since you don't need to pre-lock what the `UPDATE` will lock anyway.

```python
def move_subtree(self, new_parent):
    with transaction.atomic():
        # lock only the root — .exists() forces evaluation, a lazy queryset locks nothing
        OrgUnit.objects.select_for_update().filter(id=self.id).exists()
        ...
```

Two concrete bugs hide in that one line if you're not careful. First, a `select_for_update().filter(...)` queryset that's never evaluated (never iterated, or checked with something like `.exists()`) sends no lock request to Postgres at all, so the lock silently does nothing. Second, locking every descendant instead of just the root is lock amplification: correct, but needlessly expensive.

## Partial indexes: the condition Postgres won't let you write

A composite index on `(user_id, deleted_at)` still leaves `expires_at` as a post-scan filter. The instinct is to add a partial index with `WHERE expires_at > now()`. Postgres rejects this, because a partial index's condition is evaluated once at index-build/definition time, and `now()` is not immutable, since it changes every call. The workable partial index instead targets the *permanent*-grant hot path, which has no time-based condition:

```sql
CREATE INDEX scoped_role_user_permanent_active_idx
  ON scoped_role_assignment (user_id)
  WHERE deleted_at IS NULL AND expires_at IS NULL;
```

Time-bound (expiring) grants fall back to the regular composite index. Documenting *why* they can't get the same partial-index treatment is itself the interview-worthy part of this answer, not just knowing partial indexes exist.

## Audit log immutability: two layers, one authoritative

Application-level immutability, meaning blocking `UPDATE`/`DELETE` in the model's `save()`/`delete()` methods, only holds if every write goes through the ORM. A raw SQL client bypasses it entirely. The fix is defense in depth: keep the Django-layer guard, which fails fast with a good error message and no round trip needed to discover the problem, *and* add a Postgres trigger that raises on any `UPDATE`/`DELETE` to the audit table regardless of what wrote it:

```sql
CREATE OR REPLACE FUNCTION prevent_audit_mutation() RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'audit_log rows are immutable';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_immutable_update BEFORE UPDATE ON audit_log
  FOR EACH ROW EXECUTE FUNCTION prevent_audit_mutation();
```

The Django guard is convenience; the trigger is the actual guarantee. It's the same advisory-vs-authoritative split as the cycle check at the top of this note, showing up again in a different corner of the same system.
