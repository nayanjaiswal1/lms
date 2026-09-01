---
kind: lesson
id_key: interview-prep-45/day-37
course: interview-prep-45
section: final-prep
section_title: "Weakness Focus & Final Prep"
section_position: 8
title: "Weakness Focus — Backend, System Design, Behavioral"
position: 37
estimated_minutes: 240
source:
    - 45-day-interview-roadmap.md
---

Backend interviews at this stage aren't "do you know Django." They're "can you write the migration, the lock, and the test that a senior engineer would actually ship." This day forces production-shaped answers in three domains: backend depth, two hard system designs, and behavioral delivery so tight it survives interruptions.

## Block 1 (120 min): Backend Deep Dive

### Database migration with data backfill (45 min)

The interview trap: candidates write a schema-only migration and forget the data has to move safely, in production, without locking the table for minutes.

```python
# Django migration: add a non-nullable column to an existing table
# without a table-wide lock or a maintenance window.

from django.db import migrations, models


def backfill_full_name(apps, schema_editor):
    User = apps.get_model("accounts", "User")
    batch_size = 1000
    qs = User.objects.filter(full_name__isnull=True).order_by("pk")
    while True:
        batch = list(qs[:batch_size])
        if not batch:
            break
        for user in batch:
            user.full_name = f"{user.first_name} {user.last_name}".strip()
        User.objects.bulk_update(batch, ["full_name"], batch_size=batch_size)
        # re-query from last pk instead of re-fetching from the top each loop
        qs = User.objects.filter(
            full_name__isnull=True, pk__gt=batch[-1].pk
        ).order_by("pk")


def reverse_noop(apps, schema_editor):
    pass  # data backfill isn't reversed; the column drop handles rollback


class Migration(migrations.Migration):
    dependencies = [("accounts", "0011_previous_migration")]

    operations = [
        # step 1: add column as nullable, instant, no table lock
        migrations.AddField(
            model_name="user",
            name="full_name",
            field=models.CharField(max_length=255, null=True, blank=True),
        ),
        # step 2: backfill in batches, off the request path
        migrations.RunPython(backfill_full_name, reverse_noop),
        # step 3 (separate deploy, once backfill confirmed complete):
        # migrations.AlterField(..., field=models.CharField(max_length=255))
        # makes it NOT NULL only after every row is populated
    ]
```

Say this out loud in the interview: "I split this into three phases: add nullable, backfill in batches so I never hold a long transaction or lock the whole table, then tighten to NOT NULL in a follow-up deploy once the backfill is confirmed done." That sequencing is the actual signal they're testing for.

### Redis distributed lock (45 min)

```python
import uuid
import redis

r = redis.Redis(host="localhost", port=6379, db=0)


def acquire_lock(lock_name: str, ttl_ms: int = 10_000) -> str | None:
    """Returns a unique token if the lock was acquired, else None."""
    token = str(uuid.uuid4())
    # NX = only set if not exists, PX = TTL in ms: atomic acquire+expire
    acquired = r.set(f"lock:{lock_name}", token, nx=True, px=ttl_ms)
    return token if acquired else None


# Release must be atomic compare-and-delete: you can only ever delete
# a lock you own. Otherwise you can delete someone else's lock after
# your TTL expired and it was re-acquired by another process.
RELEASE_SCRIPT = """
if redis.call("get", KEYS[1]) == ARGV[1] then
    return redis.call("del", KEYS[1])
else
    return 0
end
"""


def release_lock(lock_name: str, token: str) -> bool:
    result = r.eval(RELEASE_SCRIPT, 1, f"lock:{lock_name}", token)
    return result == 1


def with_lock(lock_name: str, ttl_ms: int = 10_000):
    """Usage: with_lock('order:123') as acquired: ..."""
    class _Lock:
        def __enter__(self):
            self.token = acquire_lock(lock_name, ttl_ms)
            if self.token is None:
                raise RuntimeError(f"could not acquire lock {lock_name}")
            return self.token

        def __exit__(self, *exc):
            release_lock(lock_name, self.token)

    return _Lock()
```

The two things interviewers listen for: (1) the release is a **Lua script**, not a plain `DEL`, because check-then-delete is a race condition without atomicity; (2) the lock has a **TTL** so a crashed holder doesn't block everyone forever. If asked "what if the holder is slow and the TTL expires mid-operation?" the honest answer is you need a watchdog/lease-extension pattern (like Redlock or a background renewer). Single-instance Redis locking is best-effort, not linearizable, so for real correctness guarantees you'd reach for a consensus store (etcd/ZooKeeper) or a DB-level advisory lock.

### Unit tests with mocking (30 min)

```python
from unittest.mock import patch, MagicMock
import pytest

from orders.services import charge_and_create_order


@patch("orders.services.payment_gateway")
def test_charge_and_create_order_success(mock_gateway):
    mock_gateway.charge.return_value = MagicMock(id="ch_123", status="succeeded")

    order = charge_and_create_order(user_id=1, amount_cents=2500)

    mock_gateway.charge.assert_called_once_with(amount_cents=2500, user_id=1)
    assert order.status == "paid"
    assert order.charge_id == "ch_123"


@patch("orders.services.payment_gateway")
def test_charge_and_create_order_gateway_failure_rolls_back(mock_gateway):
    mock_gateway.charge.side_effect = Exception("card declined")

    with pytest.raises(Exception, match="card declined"):
        charge_and_create_order(user_id=1, amount_cents=2500)

    # verify no partial order was persisted: the transaction rolled back
    from orders.models import Order
    assert not Order.objects.filter(user_id=1).exists()
```

The rule to state out loud: **mock at the boundary** (the payment gateway client), not the function under test. Testing that a DB write rolled back on failure is worth more in an interview than testing the happy path twice.

## Block 2 (75 min): System Design Practice

Two designs, timeboxed, full six-step checklist (requirements → capacity → API → high-level → deep dive → bottlenecks) from Days 1-35:

- **Design Amazon (product catalog + checkout), 45 min.** The hard part is inventory consistency under concurrent purchases (optimistic locking / reserved-stock pattern) and search/catalog read scaling (denormalized read models, ES/OpenSearch).
- **Design WhatsApp, 45 min.** The hard part is message delivery guarantees (at-least-once plus client-side idempotency/dedup), online presence at scale (fan-out cost), and end-to-end encryption's effect on server-side features (no server-side search or content moderation on message bodies).

After each: self-evaluate against the checklist. Which step did you rush? That's the note to bring into tomorrow's mock.

## Block 3 (45 min): Behavioral Final Prep

By now you have 10 STAR stories. Today is about **delivery**, not content:

- Say all 10 out loud, hard cap of **2 minutes each**. If a story runs long, the fix is almost always cutting Situation/Task, not Result: interviewers want the decision and the outcome, not the backstory.
- Record yourself (phone voice memo is fine). Listening back is uncomfortable, and that discomfort is exactly why it works. You catch things live delivery hides.
- Count filler words (`um`, `like`, `basically`, `so yeah`) per story. Target: near zero. The fix isn't trying harder. It's pausing silently instead of filling the gap with a sound.

**Verify you're actually strong here (all three blocks):**
- Backend: re-explain the Redis lock's release script from memory. If you can't say why `GET` + `DEL` isn't safe without looking, redo the section.
- System design: pick one bottleneck from today's two designs and describe the fix in under 90 seconds.
- Behavioral: play back one recording. If you can't name your filler-word count without re-listening, you weren't actually listening the first time. Do it again.

Notice the pattern across all three blocks: phased migrations, TTL-plus-token locks, and Result-heavy stories are all versions of the same discipline, sequencing the response so the risky part is contained instead of spread across the whole answer. That's the habit today was built to install.
