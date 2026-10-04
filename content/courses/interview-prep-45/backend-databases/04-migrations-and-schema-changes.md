---
kind: lesson
id_key: interview-prep-45/day-28-backend
course: interview-prep-45
section: backend-databases
section_title: "Databases (PostgreSQL)"
section_position: 9
section_group: "Backend"
title: "Migrations and Schema Changes"
position: 4
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---

Every backend engineer eventually ships a migration that locks a table in production. Interviewers ask about migrations to find out whether you've already learned that lesson, or you're about to learn it the hard way on their system. This lesson covers how Django migrations actually work, which schema changes are dangerous on a big table, and how to change a live table without an outage.

## How Django migrations actually work

`makemigrations` compares your models against the last known state, tracked through migration files rather than the live database, and writes a Python file describing the difference. `migrate` applies pending migration files in dependency order and records which ones ran, in a `django_migrations` table.

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

Four habits interviewers expect you to name:

- **One logical change per migration.** Don't bundle an unrelated index add with a column rename. A rollback should undo one thing, not three.
- **Never edit a migration that has already run anywhere** (staging, a teammate's machine, production). Treat migration files as an append-only log. Editing an already-applied one desyncs `django_migrations`'s record from what actually happened. Write a new migration to fix a mistake instead.
- **Keep migrations reversible when you can.** Implement `reverse_code` for a `RunPython` operation, so `migrate app 0006` actually works instead of throwing `IrreversibleError`.
- **Read the generated SQL before running it in production**, with `python manage.py sqlmigrate accounts 0007`. This one habit turns "I think this is safe" into "I checked exactly what lock this takes."

```bash
python manage.py makemigrations accounts
python manage.py sqlmigrate accounts 0007
python manage.py migrate accounts
```

> **Remember:** run `sqlmigrate` before every production deploy. It's the difference between guessing a migration is safe and knowing exactly what lock it takes.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-migrations-workflow-q1", "type": "mcq",
      "prompt": "A migration was already applied on staging, and it turns out to be wrong. What should you do?",
      "options": [
        {"id":"a","text":"Edit that migration file directly and re-run migrate everywhere"},
        {"id":"b","text":"Write a new migration that fixes the problem, and leave the applied one untouched"},
        {"id":"c","text":"Delete the migration file and hope Django regenerates it correctly"},
        {"id":"d","text":"Manually edit rows in the django_migrations table instead"}
      ],
      "correct": "b",
      "explanation": "An applied migration is part of an append-only history. Editing it after the fact desyncs django_migrations's record from what environments actually ran. A new migration is the safe fix." }
] }
```

## Why some migrations lock the whole table

Changing a table's structure needs a lock. The real question to ask is not "will this work," it's "which lock does it take, and for how long."

| Operation | Lock in Postgres | Danger on a large table |
|---|---|---|
| `ADD COLUMN`, nullable, no default | Metadata-only, near-instant (Postgres 11+) | Safe |
| `ADD COLUMN` with a non-null default | Metadata-only on Postgres 11+ | Safe on 11+; check your version |
| `ADD COLUMN` with a **volatile** default (like `uuid.uuid4`) | Full table rewrite | Dangerous: locks the whole table for the rewrite |
| `ALTER COLUMN TYPE` | Full rewrite, exclusive lock | Dangerous on a large table |
| `CREATE INDEX` (plain) | Blocks writes for the duration | Dangerous: use `CREATE INDEX CONCURRENTLY` instead |
| `ADD CONSTRAINT NOT NULL` | Full scan to validate, holds a lock | Dangerous: split into `NOT VALID` plus a separate `VALIDATE CONSTRAINT` |
| `ADD FOREIGN KEY` | Scans both tables to validate | Same fix: `NOT VALID`, then validate separately |

The dangerous rows all take an `ACCESS EXCLUSIVE` lock, which blocks both writes *and* reads from every other connection while it's held. On a table with 50 million rows, a full rewrite can take minutes. During that window, your app effectively has an outage on anything touching that table.

> **Remember:** the danger question is never "will this migration work," it's "what lock does it take, and for how long." `ACCESS EXCLUSIVE` blocks reads too, not just writes.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-migrations-locks-q1", "type": "mcq",
      "prompt": "Why is ADD COLUMN with a volatile default like uuid.uuid4 dangerous on a huge table, when a plain non-null default is safe on modern Postgres?",
      "options": [
        {"id":"a","text":"There is no real difference; both are equally safe"},
        {"id":"b","text":"A volatile default produces a different value per row, so Postgres must actually rewrite the whole table rather than making a fast, metadata-only change"},
        {"id":"c","text":"UUIDs are always slower to compute than other data types"},
        {"id":"d","text":"Volatile defaults are rejected by Postgres and never actually run"}
      ],
      "correct": "b",
      "explanation": "A constant default lets Postgres record the value once, as metadata. A volatile default must be computed separately for every existing row, which forces a full table rewrite under an ACCESS EXCLUSIVE lock." }
] }
```

## Adding a required column to a huge table, safely

Take the worst case: adding a `NOT NULL` column with a default to a huge, high-traffic table, without an outage. The trick is splitting one risky operation into several small, non-blocking ones, deployed one at a time.

**Step 1: add the column, nullable, no default.** Fast, metadata-only.

```python
migrations.AddField(
    model_name="order", name="status",
    field=models.CharField(max_length=20, null=True, blank=True),
)
```

**Step 2: backfill in small batches**, off the request path, never as one giant transaction.

```python
def backfill_status(apps, schema_editor):
    Order = apps.get_model("orders", "Order")
    batch_size = 5000
    last_id = 0
    while True:
        batch = list(
            Order.objects.filter(id__gt=last_id, status__isnull=True)
            .order_by("id").values_list("id", flat=True)[:batch_size]
        )
        if not batch:
            break
        Order.objects.filter(id__in=batch).update(status="pending")
        last_id = batch[-1]
```

Batching matters for two reasons. One giant `UPDATE` on 50 million rows holds row locks and generates a mountain of write-ahead log in a single transaction. And it's all-or-nothing: if it dies at row 40 million, you redo all 40 million. Batches of a few thousand commit independently and pick up from `last_id` if interrupted.

**Step 3: add the `NOT NULL` constraint in two phases**, so the full-table scan does not block anything.

```sql
-- Instant: doesn't scan existing rows, only enforces the rule on new writes
ALTER TABLE orders ADD CONSTRAINT orders_status_not_null CHECK (status IS NOT NULL) NOT VALID;

-- Scans the table but takes a lighter lock that never blocks reads or writes
ALTER TABLE orders VALIDATE CONSTRAINT orders_status_not_null;
```

**Step 4: once confident**, backfill complete and the constraint validated, update the Django model to match.

```python
migrations.AlterField(
    model_name="order", name="status",
    field=models.CharField(max_length=20, default="pending"),
)
```

Four small migrations, each either instant or non-blocking, instead of one migration that locks the whole table. Say this in an interview and name the sequence: "add nullable, backfill in batches so I never hold a long transaction or lock the whole table, then tighten to `NOT NULL` in a follow-up deploy once the backfill is confirmed complete." That sequencing, not any single line of code, is the actual thing being tested.

> **Remember:** a required column on a huge table is four small migrations: add nullable, backfill in batches, add the constraint `NOT VALID`, then validate it. Never one big blocking migration.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-migrations-backfill-q1", "type": "mcq",
      "prompt": "Why split a NOT NULL constraint into ADD CONSTRAINT ... NOT VALID followed by a separate VALIDATE CONSTRAINT, instead of adding it directly?",
      "options": [
        {"id":"a","text":"NOT VALID is only a syntax preference with no real effect"},
        {"id":"b","text":"Adding it directly requires a full-table scan under a blocking lock; NOT VALID applies instantly and only enforces the rule going forward, while VALIDATE CONSTRAINT scans under a much lighter, non-blocking lock"},
        {"id":"c","text":"VALIDATE CONSTRAINT is faster because it skips checking any rows"},
        {"id":"d","text":"NOT VALID constraints are never actually enforced"}
      ],
      "correct": "b",
      "explanation": "Adding a validated constraint directly requires scanning the whole table while holding a blocking lock. Splitting it lets the instant NOT VALID step enforce new writes immediately, while the scan for existing rows happens later under a lock that doesn't block reads or writes." }
] }
```

## Data migrations and the historical model trap

A data migration transforms existing rows rather than the schema. Always fetch models through `apps.get_model`, never by importing the real model class directly: the historical model reflects the schema at that exact point in migration history, which matters once the real model gains fields or methods the migration was never written to expect.

```python
def split_full_name(apps, schema_editor):
    User = apps.get_model("accounts", "User")
    for user in User.objects.filter(first_name="", last_name="").iterator():
        parts = user.full_name.split(" ", 1)
        user.first_name = parts[0]
        user.last_name = parts[1] if len(parts) > 1 else ""
        user.save(update_fields=["first_name", "last_name"])
```

`iterator()` avoids loading the whole queryset into memory at once, which matters once "existing data" means millions of rows. For very large tables, batch this the same way as the backfill above, rather than one unbounded `iterator()` pass inside a single migration transaction.

> **Remember:** always fetch models through `apps.get_model` inside a data migration. It gives you the schema as it existed at that point in history, not whatever the real model currently looks like.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-migrations-datamigration-q1", "type": "mcq",
      "prompt": "Why does a data migration use apps.get_model('accounts', 'User') instead of importing the real User model directly?",
      "options": [
        {"id":"a","text":"apps.get_model is faster to import"},
        {"id":"b","text":"It returns a historical version of the model matching the schema at that point in migration history, which stays correct even after the real model gains new fields or methods later"},
        {"id":"c","text":"Importing the real model is not allowed anywhere in Django"},
        {"id":"d","text":"There is no difference between the two"}
      ],
      "correct": "b",
      "explanation": "A data migration might run long after it was written, against a codebase whose real model has since changed. apps.get_model gives back the model as it looked at that historical point, so the migration keeps working." }
] }
```

## Zero-downtime migrations: expand, migrate, contract

During a rolling deploy, old and new application code run against the *same* database at the same time, for as long as it takes instances to cycle through. A migration is zero-downtime only if both versions of the code work correctly against the schema at every point in that window.

That rules out any single step that both adds and immediately requires a column. The standard technique is **expand/contract**:

1. **Expand**: add the new column or table, purely additive. Old code ignores it; nothing breaks.
2. **Migrate and dual-write**: deploy code that writes to both the old and new columns (or reads the new one with a fallback to the old), and backfill existing rows.
3. **Contract**: once every instance runs the new code and the backfill is done, remove the old column and the compatibility code.

A column rename (`username` to `handle`) can never be a single `RENAME COLUMN` in a zero-downtime deploy, because old code would break the instant the old column disappeared:

```python
# Expand: add handle, keep username
migrations.AddField(model_name="user", name="handle", field=models.CharField(max_length=50, null=True))

# App code deployed after this: write to both
def save_username(user, value):
    user.username = value
    user.handle = value
    user.save()

# Backfill handle from username for existing rows (batched, as above)

# Contract, only once every instance has stopped reading username:
migrations.RemoveField(model_name="user", name="username")
```

The interview answer, said plainly: "Zero-downtime means both old and new code work against the schema during a rolling deploy. Expand adds new structure additively, dual-write and backfill keep both paths working while they coexist, and contract removes the old structure only once every instance is on the new code." Naming "expand/contract" is what signals you've actually done this, not just read about it once.

> **Remember:** expand adds, contract removes. Never combine them into one step, or old code breaks the instant new code deploys.

```knowledge-check
{ "questions": [
    { "id": "backend-databases-migrations-zerodowntime-q1", "type": "mcq",
      "prompt": "Why can't a column rename be done as a single RENAME COLUMN during a zero-downtime rolling deploy?",
      "options": [
        {"id":"a","text":"RENAME COLUMN does not exist in Postgres"},
        {"id":"b","text":"During the rollout window, old app code instances still expect the original column name, and it would already be gone"},
        {"id":"c","text":"Renaming a column always requires downtime, regardless of deploy strategy"},
        {"id":"d","text":"Django does not support RenameField as a migration operation"}
      ],
      "correct": "b",
      "explanation": "A rolling deploy runs old and new code side by side for a while. A single rename removes the old name immediately, breaking every old-code instance still reading it. Expand/contract keeps both names valid until every instance is on the new code." }
] }
```
