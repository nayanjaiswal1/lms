---
kind: lesson
id_key: interview-prep-45/day-28-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Day 28 — Migrations and Schema Changes"
position: 28
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Today is schema evolution: Django migrations, how to change a large production table without an outage, data migrations, and zero-downtime deploys. Every backend engineer eventually ships a migration that locks a table in production — interviewers ask this to find out if you've learned that lesson already or are about to learn it the hard way on their system.

## Django migrations — how they actually work

`makemigrations` diffs your models against the last known state (tracked via migration files, not the live DB) and generates a Python file describing the change. `migrate` applies pending migration files in dependency order and records which ones ran in the `django_migrations` table.

```python
# migrations/0007_add_phone_number.py
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [("accounts", "0006_alter_user_email")]

    operations = [
        migrations.AddField(
            model_name="user",
            name="phone_number",
            field=models.CharField(max_length=20, blank=True, default=""),
        ),
    ]
```

Best practices interviewers expect you to name:

- **One logical change per migration.** Don't bundle an unrelated index add with a column rename — if it needs a rollback, you want to roll back one thing, not three.
- **Never edit a migration that's already been applied anywhere** (staging, another dev's machine, prod). Migration files are treated as an append-only log; editing an applied one desyncs `django_migrations` state from reality. Write a new migration to fix a mistake.
- **Keep migrations reversible when practical** — implement `reverse_code` for `RunPython` operations so `migrate app 0006` actually works instead of throwing `IrreversibleError`.
- **Review the generated SQL before running in prod**: `python manage.py sqlmigrate accounts 0007`. This is the single highest-leverage habit — it turns "I think this is safe" into "I confirmed this doesn't rewrite the table."

```bash
python manage.py makemigrations accounts
python manage.py sqlmigrate accounts 0007
python manage.py migrate accounts
```

## Why some migrations are dangerous on a large table

Postgres (and MySQL similarly) needs to take a lock to change table structure. The danger isn't "will it work," it's "what lock does it take, and for how long."

| Operation | Lock in Postgres | Danger on a large table |
|---|---|---|
| `ADD COLUMN` with no default, nullable | `ACCESS EXCLUSIVE`, but metadata-only, near-instant (Postgres 11+) | Safe |
| `ADD COLUMN` with a non-null default | Historically rewrote the whole table; Postgres 11+ made this metadata-only too | Safe on Postgres 11+, but check your version |
| `ADD COLUMN` with a **volatile** default (e.g. `default=uuid.uuid4`) | Full table rewrite | Dangerous — locks the whole table for the rewrite duration |
| `ALTER COLUMN TYPE` | `ACCESS EXCLUSIVE`, full rewrite | Dangerous on large tables |
| `CREATE INDEX` (plain) | Blocks writes for the duration | Dangerous — use `CREATE INDEX CONCURRENTLY` |
| `ADD CONSTRAINT NOT NULL` | Full table scan to validate, holds a lock | Dangerous — split into `CHECK ... NOT VALID` + `VALIDATE CONSTRAINT` |
| `ADD FOREIGN KEY` | Scans both tables to validate | Same fix: `NOT VALID` then validate separately |

The `ACCESS EXCLUSIVE` lock blocks not just writes but *reads* on that table for every other connection while it's held — on a 50M-row table, a full rewrite can take minutes, during which your app effectively has an outage on anything touching that table.

## Implementing a safe migration for a large table

Take the worst case: adding a `NOT NULL` column with a default to a huge, high-traffic table, safely. The technique is to split one risky operation into several small, non-blocking ones, deployed incrementally.

**Step 1 — add the column, nullable, no default (fast metadata-only change):**

```python
# 0008_add_status_column.py
class Migration(migrations.Migration):
    dependencies = [("orders", "0007_previous")]
    operations = [
        migrations.AddField(
            model_name="order",
            name="status",
            field=models.CharField(max_length=20, null=True, blank=True),
        ),
    ]
```

**Step 2 — backfill in small batches, outside a single long transaction:**

```python
# 0009_backfill_status.py
from django.db import migrations


def backfill_status(apps, schema_editor):
    Order = apps.get_model("orders", "Order")
    batch_size = 5000
    last_id = 0
    while True:
        batch = list(
            Order.objects.filter(id__gt=last_id, status__isnull=True)
            .order_by("id")
            .values_list("id", flat=True)[:batch_size]
        )
        if not batch:
            break
        Order.objects.filter(id__in=batch).update(status="pending")
        last_id = batch[-1]


def noop_reverse(apps, schema_editor):
    pass  # backfill has no meaningful reverse


class Migration(migrations.Migration):
    dependencies = [("orders", "0008_add_status_column")]
    operations = [
        migrations.RunPython(backfill_status, reverse_code=noop_reverse),
    ]
```

Batching matters for two reasons: a single `UPDATE orders SET status = 'pending'` on 50M rows holds row locks and generates a massive amount of WAL/undo in one transaction, and it's all-or-nothing — if it fails at row 40M you redo all 40M. Batches of a few thousand commit independently and can resume from `last_id` on failure.

**Step 3 — add the `NOT NULL` constraint safely** (two-phase, avoids the full-table-scan lock happening as one blocking operation):

```sql
-- Add as NOT VALID: instant, doesn't scan existing rows, only enforces on new writes
ALTER TABLE orders ADD CONSTRAINT orders_status_not_null CHECK (status IS NOT NULL) NOT VALID;

-- Validate separately: scans the table but only takes a lighter lock (SHARE UPDATE EXCLUSIVE),
-- which does not block reads or writes, just other schema changes
ALTER TABLE orders VALIDATE CONSTRAINT orders_status_not_null;
```

```python
# 0010_add_not_null_constraint.py
class Migration(migrations.Migration):
    dependencies = [("orders", "0009_backfill_status")]
    operations = [
        migrations.RunSQL(
            sql="ALTER TABLE orders ADD CONSTRAINT orders_status_not_null CHECK (status IS NOT NULL) NOT VALID;",
            reverse_sql="ALTER TABLE orders DROP CONSTRAINT orders_status_not_null;",
        ),
        migrations.RunSQL(
            sql="ALTER TABLE orders VALIDATE CONSTRAINT orders_status_not_null;",
            reverse_sql=migrations.RunSQL.noop,
        ),
    ]
```

**Step 4 — once confident (constraint validated, app always writes a value), make Django's model match reality:**

```python
# 0011_finalize_status_not_null.py
class Migration(migrations.Migration):
    dependencies = [("orders", "0010_add_not_null_constraint")]
    operations = [
        migrations.AlterField(
            model_name="order",
            name="status",
            field=models.CharField(max_length=20, default="pending"),
        ),
    ]
```

Four small migrations instead of one big blocking one — every step is either instant or takes a non-blocking lock. This sequencing (add nullable → backfill in batches → add constraint `NOT VALID` → validate → tighten the model) is the answer to "how do you add a required column to a huge table."

## Data migrations with Django

A data migration transforms existing data rather than schema. Use `RunPython` and **always fetch models via `apps.get_model`**, not by importing the real model class — the historical model reflects the schema at that point in migration history, which matters if the real model later gains fields or methods the migration doesn't expect.

```python
# migrations/0012_split_full_name.py
from django.db import migrations


def split_full_name(apps, schema_editor):
    User = apps.get_model("accounts", "User")
    for user in User.objects.filter(first_name="", last_name="").iterator():
        parts = user.full_name.split(" ", 1)
        user.first_name = parts[0]
        user.last_name = parts[1] if len(parts) > 1 else ""
        user.save(update_fields=["first_name", "last_name"])


def rejoin_full_name(apps, schema_editor):
    User = apps.get_model("accounts", "User")
    for user in User.objects.iterator():
        user.full_name = f"{user.first_name} {user.last_name}".strip()
        user.save(update_fields=["full_name"])


class Migration(migrations.Migration):
    dependencies = [("accounts", "0011_add_first_last_name")]
    operations = [
        migrations.RunPython(split_full_name, reverse_code=rejoin_full_name),
    ]
```

`iterator()` avoids loading the whole queryset into memory at once — important once "existing data" means millions of rows. For very large tables, batch this the same way as the backfill example above rather than one unbounded `iterator()` pass inside a single migration transaction.

## Migrations on production — the interview answer

The core tension: Django wraps each migration in a transaction by default (for Postgres), which is good for atomicity but means a long-running migration holds its locks for the whole transaction. The practical rules:

1. **Run `sqlmigrate` and review the SQL before every prod deploy** — know exactly what lock each statement takes.
2. **Separate schema changes from data backfills into different migrations**, and run backfills as a management command or Celery task outside the deploy window if they'll take more than a few seconds, rather than as a migration that blocks deploy.
3. **Never deploy a migration that depends on application code changes shipping in the exact same instant** — see zero-downtime section below.
4. **Take a fresh backup / ensure PITR is enabled** before any migration that touches a large or critical table, regardless of how safe you believe it is.
5. **Run migrations before the new app code rolls out**, and make sure the *old* app code still works against the *new* schema during the rollout window (next section explains why).

## Zero-downtime migrations

The core idea: during a rolling deploy, old and new application code run **simultaneously** against the **same database** for some window of time (while pods/instances cycle through). A migration is zero-downtime only if both the old and new code can operate correctly against the schema at every point in that window.

This rules out any single-step change that both adds and requires a column at once. The standard technique is the **expand/contract pattern**:

1. **Expand**: add the new column/table, additive only, backward compatible. Old code ignores it; nothing breaks.
2. **Migrate + dual-write**: deploy app code that writes to both old and new columns (or reads new-with-fallback-to-old), and backfill existing rows.
3. **Contract**: once all app instances are on the new code and backfill is complete, deploy a migration that removes the old column and the compatibility code.

Concretely for a **column rename** (`username` → `handle`), which cannot be done as a single `ALTER TABLE ... RENAME COLUMN` in a zero-downtime deploy because old code would immediately break on the missing `username` column:

```python
# Step 1 (expand): add `handle`, keep `username`
migrations.AddField(model_name="user", name="handle", field=models.CharField(max_length=50, null=True))

# App code deployed after step 1: write to both fields
def save_username(user, value):
    user.username = value
    user.handle = value
    user.save()

# Step 2: backfill handle from username for existing rows (batched, as shown earlier)

# Step 3 (contract), only after ALL instances run code that no longer reads `username`:
migrations.RemoveField(model_name="user", name="username")
```

**Interview answer, condensed**: "Zero-downtime migration means old and new code both work against the schema during a rolling deploy — you get there with expand/contract: add new structure additively, dual-write and backfill while both code paths coexist, then remove the old structure only after every instance is running the new code." Naming "expand/contract" by name is what signals you've actually done this, not just read about it.

## Key takeaways

- Always run `sqlmigrate` before applying a migration in production — know the exact SQL and the lock it takes, don't guess.
- The danger in schema changes is lock type and duration, not the change itself: `CREATE INDEX CONCURRENTLY` and `ADD CONSTRAINT ... NOT VALID` + `VALIDATE CONSTRAINT` avoid blocking reads/writes that a naive version would cause.
- Adding a required column to a huge table safely is a four-step sequence: nullable column → batched backfill → `NOT VALID` constraint → validate → tighten the model — never one big migration.
- Data migrations use `apps.get_model` (historical models) and `iterator()`/batching for large tables, with a real `reverse_code` where feasible.
- Zero-downtime requires the expand/contract pattern because old and new app code run simultaneously against the same schema during a rolling deploy — any migration that isn't backward-compatible with the currently-running old code causes an outage.
- Never edit an already-applied migration; write a new one.

## Today's checklist

- [ ] Read up on Django migration best practices (sqlmigrate, reversibility, one change per migration)
- [ ] Implement a safe migration for adding a required column to a large table
- [ ] Implement a data migration using `apps.get_model` and batching
- [ ] Be able to answer: how do you handle migrations on production, what is zero-downtime migration
- [ ] Implement a migration that adds a column with a default, safely, on a large table
