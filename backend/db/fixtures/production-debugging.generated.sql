-- ══════════════════════════════════════════════════════════════════════════
-- GENERATED FILE — DO NOT EDIT.
-- Source: canonical markdown content (content/courses/**).
-- Regenerate via: cd backend && go run ./cmd/coursegen generate
-- Generated at: 2026-10-01T19:33:15Z
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Course: Production Debugging: Fix Real Bugs in a Live-Looking App ─────────────────────────────────────────────
INSERT INTO courses (id, org_id, creator_id, title, slug, description, cover_url, difficulty, tags, status, is_free, is_public, estimated_hours)
VALUES ('8af0a927-61bf-5a04-a2e9-e74f552564bf', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'Production Debugging: Fix Real Bugs in a Live-Looking App', 'production-debugging', 'Learn to debug the way it is done at work. Every lab drops you into a small, realistic e-commerce application (Django, PostgreSQL, Celery) inside a browser IDE with a real git history, a ticket from support or the on-call channel, logs, a database and a debugger. You reproduce the problem, follow the evidence to the root cause, fix it, prove the fix with a test that fails on the broken code, and write a short incident note. The Django track covers performance and query problems, data-model and money bugs, concurrency, migrations, configuration and calls to other services. Each section starts with a short lesson on the debugging skill, never on the answer.', NULL, 'intermediate', ARRAY['debugging','django','postgresql','performance','concurrency','migrations','incident-response'], 'published', true, true, 9.8)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, cover_url=EXCLUDED.cover_url, tags=EXCLUDED.tags, is_public=EXCLUDED.is_public, estimated_hours=EXCLUDED.estimated_hours, updated_at=now();

UPDATE course_sections SET position = position + 100000 WHERE course_id = '8af0a927-61bf-5a04-a2e9-e74f552564bf';
UPDATE course_modules SET position = position + 100000 WHERE course_id = '8af0a927-61bf-5a04-a2e9-e74f552564bf';

-- Section: Performance
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('db19aa3e-9ffb-5efc-a991-9344be87258c', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'Performance', 1, 'Django')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('660b721f-3bea-54bc-b2f9-7e9107365ccf', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'db19aa3e-9ffb-5efc-a991-9344be87258c', 'Debugging slow pages: measure first', 'notes', 1, $md$"The page is slow" is a symptom, not a diagnosis. Performance bugs are the ones where guessing costs the most: you can spend a day adding caches and indexes to code that only needed one line of queryset. The skill this section trains is turning a vague complaint into a number you can watch go down.

## Turn the complaint into a measurement

A useful performance investigation starts with three questions. What exactly is slow (one page, one endpoint, one customer)? How slow, compared with what? And what changed? A ticket rarely answers them, so your first job is to reproduce the slowness yourself with data that looks like the reporter's. A customer with two orders and a customer with two hundred can behave completely differently.

Once you can reproduce it, pick something to measure that will still be meaningful after you change the code. Wall-clock time on your laptop is noisy. The number of database statements a request runs is exact, repeatable, and usually what the slowness is made of.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-perf-measure-q1", "type": "mcq",
      "prompt": "A ticket says a page is slow only for some customers. What is the best first step?",
      "options": [
        {"id":"a","text":"Add caching in front of the page"},
        {"id":"b","text":"Reproduce it with data shaped like the affected customers and measure something repeatable"},
        {"id":"c","text":"Add indexes to every column the page reads"},
        {"id":"d","text":"Ask for a bigger database instance"}
      ],
      "correct": "b",
      "explanation": "Until you can reproduce the slowness and measure it, every change is a guess. Slow-for-some-customers usually means the cost depends on the data (how many rows a customer has), so the reproduction needs that shape." }
] }
```

## Count queries, not milliseconds

Django will tell you every statement it runs: the debug toolbar, the `django.db.backends` logger, `connection.queries`, or `CaptureQueriesContext` in a test. Load the page once with a small amount of data and once with a lot, and compare the counts. If the count grows with the amount of data, the code is doing work per row that could be done once for all rows. That shape has a name, N+1, and it is the most common cause of pages that get slower as customers get older.

```python
from django.db import connection
from django.test.utils import CaptureQueriesContext

with CaptureQueriesContext(connection) as ctx:
    client.get("/orders/")
print(len(ctx), "queries")
for q in ctx.captured_queries[:5]:
    print(q["sql"][:120])
```

A count that does not grow is a good sign; a count that does is a defect, whatever the timings say. It also gives you the assertion for the regression test you will write at the end.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-perf-count-q1", "type": "mcq",
      "prompt": "You load a page with 3 rows and it runs 7 queries; with 30 rows it runs 61. What does that tell you?",
      "options": [
        {"id":"a","text":"The database is under-provisioned"},
        {"id":"b","text":"The code runs a fixed number of queries per row (roughly 2 per row), which is an N+1 pattern"},
        {"id":"c","text":"The page needs a longer cache timeout"},
        {"id":"d","text":"Nothing, query counts do not matter"}
      ],
      "correct": "b",
      "explanation": "The count grows linearly with the rows shown: (61 - 7) / 27 = 2 extra queries per row. Work that scales with row count is work the queryset should have done once for all rows." }
] }
```

## Laziness is where the cost hides

Django querysets are lazy: nothing hits the database until something evaluates them, and the results are cached on the queryset only after a full evaluation. Related objects are lazy too: `order.customer` runs a query the first time you touch it, for every order. In templates this is invisible, because `{{ order.customer.name }}` looks like reading an attribute. The same laziness bites in a subtler way when you call `count()`, `exists()` and then iterate: each is its own query on an unevaluated queryset.

Read code with this question in mind: at which line does each queryset actually run, and how many times? The fixes are usually small (`select_related`, `prefetch_related`, evaluating once), but you only find the right line by tracing evaluation, not by reading the model definitions.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-perf-lazy-q1", "type": "mcq",
      "prompt": "On an unevaluated queryset qs, which of these sends a new SQL query each time it is called?",
      "options": [
        {"id":"a","text":"qs.count() and qs.exists()"},
        {"id":"b","text":"Only iterating over qs"},
        {"id":"c","text":"None of them, querysets are cached from creation"},
        {"id":"d","text":"Only qs.filter(...) because it changes the SQL"}
      ],
      "correct": "a",
      "explanation": "count() and exists() each run their own statement unless the queryset has already been evaluated. Iterating evaluates it once and caches the rows; after that len(qs) and bool(qs) are free." }
] }
```

In the labs that follow, the ticket gives you a symptom and a customer-shaped hint. The workflow is always the same: reproduce, count, find the line that evaluates, fix it there, and write a test that fails on the old code because the count is higher than it should be.
$md$, 20, $json$[{"id":"production-debugging-perf-measure-q1","type":"mcq","correct":"b"},{"id":"production-debugging-perf-count-q1","type":"mcq","correct":"b"},{"id":"production-debugging-perf-lazy-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('89a9c00f-9137-58f9-af1a-1a2e7364e812', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'db19aa3e-9ffb-5efc-a991-9344be87258c', 'Lab: The order list page is slow for repeat customers', 'lab', 2, 40, '09280cf0-b66f-5c34-a6ad-04655a503d7d', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('09280cf0-b66f-5c34-a6ad-04655a503d7d', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '89a9c00f-9137-58f9-af1a-1a2e7364e812', 'module', 'Lab: The order list page is slow for repeat customers', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && if [ "$(id -u)" = "0" ]; then exec runuser -u labuser -- bash .mf/setup.sh; else exec bash .mf/setup.sh; fi$script$, 90, 3, 0, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('94f9917f-7583-5471-8b83-71ecefd097f1', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: The order list page is slow for repeat customers', $json${"app_range":"^1","blocks":[{"block_version_id":"d2d258df-ad25-5c50-9595-4c27ebbb039d"},{"block_version_id":"ff8321d4-1b63-5941-9207-262198a0f4a1"},{"block_version_id":"9e99164a-d7e5-5eb5-b11b-a29cc511af93"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"b1e52808-dc29-542f-a644-96c307e21f42"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":1101}$json$::jsonb, '09280cf0-b66f-5c34-a6ad-04655a503d7d', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('46604227-42de-5739-ade3-783db7693447', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'db19aa3e-9ffb-5efc-a991-9344be87258c', 'Lab: The staff dashboard hits the database too often', 'lab', 3, 40, '5ce46d7b-c309-561b-86da-a76e2d8f32d3', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('5ce46d7b-c309-561b-86da-a76e2d8f32d3', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '46604227-42de-5739-ade3-783db7693447', 'module', 'Lab: The staff dashboard hits the database too often', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && if [ "$(id -u)" = "0" ]; then exec runuser -u labuser -- bash .mf/setup.sh; else exec bash .mf/setup.sh; fi$script$, 90, 3, 0, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('04125711-b999-5fb4-bd5f-4ee413caf37e', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: The staff dashboard hits the database too often', $json${"app_range":"^1","blocks":[{"block_version_id":"d2d258df-ad25-5c50-9595-4c27ebbb039d"},{"block_version_id":"f24d622b-2817-5a25-9e64-89cd1becae37"},{"block_version_id":"9e99164a-d7e5-5eb5-b11b-a29cc511af93"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"b1e52808-dc29-542f-a644-96c307e21f42"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":1104}$json$::jsonb, '5ce46d7b-c309-561b-86da-a76e2d8f32d3', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: Data model and money
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('28d5d409-2fd5-586f-9971-8a6380813e83', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'Data model and money', 2, 'Django')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0721aba0-a80b-55a8-80e4-56ee4429c1e2', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '28d5d409-2fd5-586f-9971-8a6380813e83', 'Debugging wrong data: trace the value, not the screen', 'notes', 1, $md$Wrong-data bugs are quiet. Nothing crashes: a total is a cent off, a day's revenue lands on the wrong day, a record is simply gone. By the time someone notices, the damage is already stored. The skill here is to stop staring at the screen and follow one wrong value backwards, from where it is displayed to where it was produced.

## Follow one value end to end

Pick one concrete wrong example (order 4812, invoice INV-2025-00031, the 50.00 subtotal) and walk it through the system: what the database holds, what the code reads, what each function returns, what is finally rendered. The first place the value is wrong is where the bug lives, and it is often earlier than you expect. If the stored value is already wrong, the bug is in the write path; if the stored value is right, it is in the read path.

Keep the example small enough to check by hand. A wrong number you can recompute on paper is worth more than a hundred you can only see in aggregate.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-data-trace-q1", "type": "mcq",
      "prompt": "An order total displayed on a page is one cent off. You check the database row and the stored total is already wrong. Where should you look next?",
      "options": [
        {"id":"a","text":"The template that renders the number"},
        {"id":"b","text":"The code path that computed and saved the total"},
        {"id":"c","text":"The browser cache"},
        {"id":"d","text":"The web server configuration"}
      ],
      "correct": "b",
      "explanation": "If the stored value is wrong, the write path produced it; the display code only shows what it was given. Follow the value back to where it was computed." }
] }
```

## Relationships decide what deletion does

Every foreign key answers a question the model author may not have asked: what should happen to me when the row I point at is deleted? `CASCADE` deletes me too, `PROTECT` refuses the deletion, `SET_NULL` keeps me but detaches me. Cascades follow chains: delete a customer and the orders go, and so does everything hanging off the orders. Django even shows you this list on the admin delete confirmation page.

For business records (orders, invoices, payments) the right answer is almost never to lose them. The bug is often a single word in a model, and it can lie dormant for months until someone deletes the wrong row.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-data-ondelete-q1", "type": "mcq",
      "prompt": "Invoice.order is a foreign key with CASCADE, and Order.customer is CASCADE too. What happens when a customer row is deleted?",
      "options": [
        {"id":"a","text":"Only the customer is deleted"},
        {"id":"b","text":"The customer, their orders and those orders' invoices are deleted"},
        {"id":"c","text":"Django refuses because invoices exist"},
        {"id":"d","text":"The orders stay and their customer field becomes empty"}
      ],
      "correct": "b",
      "explanation": "Cascades are transitive: the customer deletion collects the orders, and deleting the orders collects their invoices. PROTECT on the customer relation would refuse the whole operation instead." }
] }
```

## Money is exact and time has a zone

Two families of data bugs come from using the wrong kind of number. Binary floating point cannot represent most decimal fractions exactly, so money computed through floats drifts by a cent in a few percent of cases, and `round()` on a float does not round halves the way accounting expects. Keep money in `Decimal` from input to output and choose the rounding mode on purpose.

Time has the mirror-image problem. Django stores instants in UTC, but a business day (or a report row, or an invoice date) belongs to a time zone, and the offset changes with daylight saving. "Which day was this order placed?" has no answer until you say which zone you mean. Whenever a number sits next to a date, ask what zone the date is in and where the conversion happens.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-data-money-q1", "type": "mcq",
      "prompt": "Why is float(50.00) * float(0.0825) a risky way to compute tax to the cent?",
      "options": [
        {"id":"a","text":"Floats are too slow"},
        {"id":"b","text":"Binary floats cannot represent most decimal fractions exactly, so exact half-cent results can land just below the half and round the wrong way"},
        {"id":"c","text":"Python refuses to multiply floats by floats"},
        {"id":"d","text":"The result is always exactly right"}
      ],
      "correct": "b",
      "explanation": "50.00 at 8.25 percent is exactly 4.125, which must round to 4.13, but the float route can produce a value slightly under 4.125 and round to 4.12. Decimal keeps the arithmetic exact." },
    { "id": "production-debugging-data-money-q2", "type": "mcq",
      "prompt": "An evening order (22:30 in New York) shows up on the next day's revenue row. What is the most likely cause?",
      "options": [
        {"id":"a","text":"The order timestamp was saved incorrectly"},
        {"id":"b","text":"The day was computed in UTC instead of the business time zone"},
        {"id":"c","text":"The revenue query ran too early"},
        {"id":"d","text":"Daylight saving time does not exist in Django"}
      ],
      "correct": "b",
      "explanation": "22:30 in New York is 03:30 UTC the next calendar day. If the report groups by the UTC date, evening orders move to the next row." }
] }
```

Each lab in this section gives you one such lie to run to ground. The fix is only done when a test with a carefully chosen input (the 50.00 subtotal, the order just before midnight, the customer with orders) fails on the old code.
$md$, 20, $json$[{"id":"production-debugging-data-trace-q1","type":"mcq","correct":"b"},{"id":"production-debugging-data-ondelete-q1","type":"mcq","correct":"b"},{"id":"production-debugging-data-money-q1","type":"mcq","correct":"b"},{"id":"production-debugging-data-money-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('f0afbafc-7b67-5c97-a2bb-e19b9c19bca7', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '28d5d409-2fd5-586f-9971-8a6380813e83', 'Lab: Invoices vanish when a customer is deleted', 'lab', 2, 30, '558eca4d-99d4-5e87-a81d-c5ec61359b7b', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('558eca4d-99d4-5e87-a81d-c5ec61359b7b', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'f0afbafc-7b67-5c97-a2bb-e19b9c19bca7', 'module', 'Lab: Invoices vanish when a customer is deleted', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && if [ "$(id -u)" = "0" ]; then exec runuser -u labuser -- bash .mf/setup.sh; else exec bash .mf/setup.sh; fi$script$, 90, 3, 0, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('ef60563b-b093-53ed-9e21-7a822a72a048', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Invoices vanish when a customer is deleted', $json${"app_range":"^1","blocks":[{"block_version_id":"d2d258df-ad25-5c50-9595-4c27ebbb039d"},{"block_version_id":"9e2ce907-987e-59b5-9a47-6bd7c311621c"},{"block_version_id":"9e99164a-d7e5-5eb5-b11b-a29cc511af93"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":2001}$json$::jsonb, '558eca4d-99d4-5e87-a81d-c5ec61359b7b', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('16254531-52f4-5fe0-b1bd-743626184b8d', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '28d5d409-2fd5-586f-9971-8a6380813e83', 'Lab: Order totals are one cent off', 'lab', 3, 45, '993b6117-02b6-565e-a1b2-c3e11cc3585b', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('993b6117-02b6-565e-a1b2-c3e11cc3585b', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '16254531-52f4-5fe0-b1bd-743626184b8d', 'module', 'Lab: Order totals are one cent off', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && if [ "$(id -u)" = "0" ]; then exec runuser -u labuser -- bash .mf/setup.sh; else exec bash .mf/setup.sh; fi$script$, 90, 3, 0, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('c527cb95-499d-56a2-b31c-436f0eebdfb1', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Order totals are one cent off', $json${"app_range":"^1","blocks":[{"block_version_id":"d2d258df-ad25-5c50-9595-4c27ebbb039d"},{"block_version_id":"add44bea-d486-5b5b-8834-b44cf413976b"},{"block_version_id":"9e99164a-d7e5-5eb5-b11b-a29cc511af93"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"21287b22-d413-5e0d-8c7f-8b60beefee16"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":2002}$json$::jsonb, '993b6117-02b6-565e-a1b2-c3e11cc3585b', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('10220d66-172f-58ae-b876-f829c0a7260f', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '28d5d409-2fd5-586f-9971-8a6380813e83', 'Lab: Evening orders land on tomorrow''s report', 'lab', 4, 45, '2423b2fd-6c43-58fd-a69a-4f17bb8af4ff', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('2423b2fd-6c43-58fd-a69a-4f17bb8af4ff', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '10220d66-172f-58ae-b876-f829c0a7260f', 'module', 'Lab: Evening orders land on tomorrow''s report', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && if [ "$(id -u)" = "0" ]; then exec runuser -u labuser -- bash .mf/setup.sh; else exec bash .mf/setup.sh; fi$script$, 90, 3, 0, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('5c4be746-6827-5fb7-b2b6-541de68e5d98', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Evening orders land on tomorrow''s report', $json${"app_range":"^1","blocks":[{"block_version_id":"d2d258df-ad25-5c50-9595-4c27ebbb039d"},{"block_version_id":"a2d781fc-616b-59bb-a4a0-c43fd10f2824"},{"block_version_id":"bffa203a-d357-5772-9cb8-6b4bb6c77bf0"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"018de84a-34e1-5831-8782-8e877ed4ae16"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":2003}$json$::jsonb, '2423b2fd-6c43-58fd-a69a-4f17bb8af4ff', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: Concurrency
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('13dfba35-e5d7-565e-9324-7dda478ef6d8', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'Concurrency', 3, 'Django')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('1ff1d0ec-7999-50ed-981b-a5ddb014f554', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '13dfba35-e5d7-565e-9324-7dda478ef6d8', 'Debugging races: make the bug happen on purpose', 'notes', 1, $md$Race conditions are bugs that depend on timing, so they vanish when you look at them. Clicking through the site never shows them; a busy Tuesday does. The skill this section trains is refusing to reason about a race in your head and instead building a small experiment that makes it happen every time.

## Reproduce with load, not with clicks

A race needs two things to overlap. Send many identical requests at once (a thread pool and a short script is enough) against a state where only one of them should win: a product with 5 units in stock, an email address that may be registered once. Then assert an invariant about the data afterwards: stock never negative, sold units equal to stock removed, exactly one account per email. If the invariant breaks, you have a reproduction. If it never breaks, make the window bigger (more requests, a slower step in the middle) rather than concluding it is fine.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-conc-repro-q1", "type": "mcq",
      "prompt": "You suspect two requests can oversell the last unit. What is the most useful reproduction?",
      "options": [
        {"id":"a","text":"Click the buy button twice quickly in the browser"},
        {"id":"b","text":"Fire many concurrent purchase requests at a product with a small stock and check the stock and the number of successful orders afterwards"},
        {"id":"c","text":"Read the code very carefully and decide it is fine"},
        {"id":"d","text":"Restart the server and try again"}
      ],
      "correct": "b",
      "explanation": "A race needs overlapping requests. Concurrent requests against a tiny stock, followed by an invariant check on the data, turns a rare timing problem into a repeatable failure." }
] }
```

## Read-modify-write is the classic shape

Most races in web apps have the same shape: read a value, decide in Python, write a value back. Between the read and the write, someone else's request does the same thing, and one of the writes silently wins (a lost update). The same shape appears as check-then-insert: "does this email exist? no, so insert it", where two requests both see "no".

The cure is to make the check and the change one step the database guarantees. A conditional `UPDATE ... WHERE stock >= n` with an `F()` expression is atomic; `select_for_update()` inside a transaction locks the row while you work; a unique constraint is the only reliable arbiter of "at most one".

```knowledge-check
{ "questions": [
    { "id": "production-debugging-conc-shape-q1", "type": "mcq",
      "prompt": "Which change removes the lost update in a stock reservation?",
      "options": [
        {"id":"a","text":"Reading the row, checking on_hand in Python, and saving on_hand - 1"},
        {"id":"b","text":"One UPDATE statement that decrements on_hand only where on_hand is at least the quantity, checking how many rows it changed"},
        {"id":"c","text":"Adding a time.sleep before saving"},
        {"id":"d","text":"Wrapping the read-modify-write in try/except"}
      ],
      "correct": "b",
      "explanation": "A single conditional UPDATE makes the check and the decrement atomic in the database. Zero updated rows means the stock was not enough. Python-side checks, sleeps and exception handling do not close the window between read and write." }
] }
```

## Let the constraint decide, and handle its answer

When the rule is "at most one", enforce it with a unique constraint and make the code expect the failure: insert inside an atomic block, catch the integrity error, and turn it into the normal answer (409, "already registered"). A pre-check is still fine as a friendly fast path, but it can never be the guard. And be suspicious of in-process fixes: a Python lock only serialises threads of one process, and production runs several workers on several machines.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-conc-constraint-q1", "type": "mcq",
      "prompt": "Why is a module-level threading.Lock around check-then-insert not a real fix for a signup race?",
      "options": [
        {"id":"a","text":"Locks are too slow in Python"},
        {"id":"b","text":"It only serialises threads inside one process; other workers and hosts still race, and the database constraint is what actually guarantees uniqueness"},
        {"id":"c","text":"Django does not allow locks"},
        {"id":"d","text":"It fixes the race completely in every deployment"}
      ],
      "correct": "b",
      "explanation": "Production runs multiple processes and machines. Only the database can arbitrate between them, so the fix is the constraint plus handling its error." }
] }
```

In both labs the graders run the same experiment you should: many concurrent requests plus an invariant check, and a deterministic test that forces the interleaving.
$md$, 25, $json$[{"id":"production-debugging-conc-repro-q1","type":"mcq","correct":"b"},{"id":"production-debugging-conc-shape-q1","type":"mcq","correct":"b"},{"id":"production-debugging-conc-constraint-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('96a415c6-071c-523e-8fc0-fc624f9db203', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '13dfba35-e5d7-565e-9324-7dda478ef6d8', 'Lab: A burst of signups crashes with IntegrityError', 'lab', 2, 45, '93e8be17-50ba-5906-a165-ee41afb22179', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('93e8be17-50ba-5906-a165-ee41afb22179', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '96a415c6-071c-523e-8fc0-fc624f9db203', 'module', 'Lab: A burst of signups crashes with IntegrityError', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && if [ "$(id -u)" = "0" ]; then exec runuser -u labuser -- bash .mf/setup.sh; else exec bash .mf/setup.sh; fi$script$, 90, 3, 0, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('61d301a1-74eb-51e7-b3d2-c548cc1e8cc7', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: A burst of signups crashes with IntegrityError', $json${"app_range":"^1","blocks":[{"block_version_id":"d2d258df-ad25-5c50-9595-4c27ebbb039d"},{"block_version_id":"0327ef6a-d5a5-5564-8eae-346e547c68f1"},{"block_version_id":"9e99164a-d7e5-5eb5-b11b-a29cc511af93"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"21287b22-d413-5e0d-8c7f-8b60beefee16"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"14b19e4d-74e3-5640-a7f2-eb06fbd3b0bd"}],"seed":2004}$json$::jsonb, '93e8be17-50ba-5906-a165-ee41afb22179', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('d5571474-dee0-523d-8e8d-ec18d39875ea', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '13dfba35-e5d7-565e-9324-7dda478ef6d8', 'Lab: The last unit is sold twice', 'lab', 3, 60, '9342f9f0-f34e-59ce-8b57-fa78117d4a77', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('9342f9f0-f34e-59ce-8b57-fa78117d4a77', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'd5571474-dee0-523d-8e8d-ec18d39875ea', 'module', 'Lab: The last unit is sold twice', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && if [ "$(id -u)" = "0" ]; then exec runuser -u labuser -- bash .mf/setup.sh; else exec bash .mf/setup.sh; fi$script$, 90, 3, 0, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('856a727b-fbf6-5f9b-b730-88becb60676a', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: The last unit is sold twice', $json${"app_range":"^1","blocks":[{"block_version_id":"d2d258df-ad25-5c50-9595-4c27ebbb039d"},{"block_version_id":"7f8aacd2-d77c-55c5-b1c8-c14a33ade6c7"},{"block_version_id":"9e99164a-d7e5-5eb5-b11b-a29cc511af93"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"21287b22-d413-5e0d-8c7f-8b60beefee16"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":2005}$json$::jsonb, '9342f9f0-f34e-59ce-8b57-fa78117d4a77', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: Migrations
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('36b18bec-3fc7-5ea2-b7d0-b3b1015f663e', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'Migrations', 4, 'Django')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('9df2ff32-3dab-50ab-b05f-636076e3a25e', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '36b18bec-3fc7-5ea2-b7d0-b3b1015f663e', 'Debugging migrations: the graph and the data', 'notes', 1, $md$A migration bug is a deployment bug: it is discovered at the worst moment, on the machine you cannot experiment on. The skill this section trains is bringing the failure back to your own machine, by reproducing the exact starting state the migration ran on.

## Migrations are a graph, and the numbers are decoration

Each migration lists its dependencies; the file number is only a naming convention. Two migrations that depend on the same parent are two leaf nodes, and `migrate` refuses to choose an order. Learn to read the graph (`showmigrations`, the dependencies list at the top of each file) rather than the file names, and to fix a fork by merging it, not by deleting files that may already have been applied somewhere.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-mig-graph-q1", "type": "mcq",
      "prompt": "Two branches each add orders/migrations/0004_something.py depending on 0003. After merging, migrate fails with conflicting leaf nodes. What is the right fix?",
      "options": [
        {"id":"a","text":"Delete one of the migrations"},
        {"id":"b","text":"Add a merge migration that depends on both 0004 migrations"},
        {"id":"c","text":"Rename one file to 0005"},
        {"id":"d","text":"Run migrate with --fake"}
      ],
      "correct": "b",
      "explanation": "The dependencies define the graph, not the numbers. A merge migration depending on both leaves restores a single head without discarding history that may already be applied elsewhere." }
] }
```

## Reproduce the starting state, not just the code

A migration is a function of the schema and the data it meets. It can pass on an empty database and on staging and still fail on production because production has NULLs, duplicates and legacy values nobody remembers. To debug it, recreate that starting state: migrate a scratch database back to the migration before the failing one, insert rows shaped like production, then migrate forward and read the actual error.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-mig-data-q1", "type": "mcq",
      "prompt": "A migration works locally and in staging but fails on production with a unique-index error. What should you do first?",
      "options": [
        {"id":"a","text":"Re-run it on production until it works"},
        {"id":"b","text":"Reproduce it on a scratch database: migrate to the previous migration, insert production-shaped rows, then migrate forward"},
        {"id":"c","text":"Remove the unique constraint from the model"},
        {"id":"d","text":"Wrap the backfill in try/except"}
      ],
      "correct": "b",
      "explanation": "The migration depends on data you have not reproduced yet. Recreating the pre-migration state with realistic rows lets you see the exact failure and test the fix, on your machine." }
] }
```

## Expand, backfill, constrain

The safe shape for adding a required or unique column is three steps: add it nullable (expand), fill it with values that satisfy the future constraint by construction (backfill), then tighten it (constrain). Most migration failures on real data are a backfill that assumed the data was clean. Keep migrations reversible where you can, keep the model and the migrations in agreement (`makemigrations --check` in CI), and never weaken the model just to make a deploy pass.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-mig-shape-q1", "type": "mcq",
      "prompt": "You backfill a new unique slug column from an optional, non-unique title. What is the safest backfill?",
      "options": [
        {"id":"a","text":"slugify(title) alone"},
        {"id":"b","text":"A value that is unique by construction, for example the slugified title (or a default word) plus the primary key"},
        {"id":"c","text":"A random number with no relation to the row"},
        {"id":"d","text":"Leave the column empty and drop the unique constraint"}
      ],
      "correct": "b",
      "explanation": "Titles can be missing or repeated. Deriving the slug from data you do not control cannot guarantee uniqueness; adding the primary key does." }
] }
```
$md$, 20, $json$[{"id":"production-debugging-mig-graph-q1","type":"mcq","correct":"b"},{"id":"production-debugging-mig-data-q1","type":"mcq","correct":"b"},{"id":"production-debugging-mig-shape-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('ebbf18aa-4dc6-5a82-a825-66bdb47bc875', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '36b18bec-3fc7-5ea2-b7d0-b3b1015f663e', 'Lab: The release is blocked by conflicting migrations', 'lab', 2, 30, '176205d8-fda2-59cf-958e-294fc906f823', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('176205d8-fda2-59cf-958e-294fc906f823', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'ebbf18aa-4dc6-5a82-a825-66bdb47bc875', 'module', 'Lab: The release is blocked by conflicting migrations', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && if [ "$(id -u)" = "0" ]; then exec runuser -u labuser -- bash .mf/setup.sh; else exec bash .mf/setup.sh; fi$script$, 90, 3, 0, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('39e8f721-8aed-56e7-9f2a-6ed5072ce622', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: The release is blocked by conflicting migrations', $json${"app_range":"^1","blocks":[{"block_version_id":"d2d258df-ad25-5c50-9595-4c27ebbb039d"},{"block_version_id":"08ef39fa-ec16-5f50-bd05-b127de59a461"},{"block_version_id":"9e99164a-d7e5-5eb5-b11b-a29cc511af93"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"288860c8-832f-5945-8535-317aecb45d12"},{"block_version_id":"71dbc11d-7b43-5659-8899-01143803cf74"}],"seed":2006}$json$::jsonb, '176205d8-fda2-59cf-958e-294fc906f823', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('16e7356a-6487-5f42-9ddf-b6bcee59c28e', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '36b18bec-3fc7-5ea2-b7d0-b3b1015f663e', 'Lab: A migration that only fails on production data', 'lab', 3, 60, 'c5a95d95-e598-52f4-8a37-c15bc37ec911', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('c5a95d95-e598-52f4-8a37-c15bc37ec911', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '16e7356a-6487-5f42-9ddf-b6bcee59c28e', 'module', 'Lab: A migration that only fails on production data', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && if [ "$(id -u)" = "0" ]; then exec runuser -u labuser -- bash .mf/setup.sh; else exec bash .mf/setup.sh; fi$script$, 90, 3, 0, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('48a02064-da9c-5711-a78c-cce7fac02f0a', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: A migration that only fails on production data', $json${"app_range":"^1","blocks":[{"block_version_id":"d2d258df-ad25-5c50-9595-4c27ebbb039d"},{"block_version_id":"5395572b-11ec-5726-a5cf-e5eb2970a0f2"},{"block_version_id":"9e99164a-d7e5-5eb5-b11b-a29cc511af93"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"288860c8-832f-5945-8535-317aecb45d12"},{"block_version_id":"71dbc11d-7b43-5659-8899-01143803cf74"}],"seed":2007}$json$::jsonb, 'c5a95d95-e598-52f4-8a37-c15bc37ec911', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: Configuration and deployment
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('24ca35ad-5e2a-58ac-8dbe-a56c49ac3d26', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'Configuration and deployment', 5, 'Django')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('178a3b24-fc15-534e-a93a-909609f07a1d', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '24ca35ad-5e2a-58ac-8dbe-a56c49ac3d26', 'Debugging configuration: what differs between here and there', 'notes', 1, $md$"Works on my machine" is a configuration bug until proven otherwise. The application code is identical; what differs is the environment around it. The skill this section trains is listing the differences systematically instead of staring at the code.

## Make the failing environment reproducible

Start by running the app the way production runs it: the same settings module, DEBUG off, the same server, the same environment variables. Many bugs appear the moment you do. Then diff the two configurations: settings values, middleware, environment variables, installed packages, files that are generated at build time (collected static files, compiled assets).

```knowledge-check
{ "questions": [
    { "id": "production-debugging-config-repro-q1", "type": "mcq",
      "prompt": "A page looks fine locally but has no styles in production. What is the best first move?",
      "options": [
        {"id":"a","text":"Rewrite the CSS"},
        {"id":"b","text":"Run the app locally with the production settings and DEBUG off and look at what the browser requests and what it gets back"},
        {"id":"c","text":"Turn DEBUG on in production"},
        {"id":"d","text":"Clear the browser cache forever"}
      ],
      "correct": "b",
      "explanation": "Reproduce the failing environment first. Running with production settings usually shows the exact failing request (a 404 for /static/...) and narrows the question to what serves that URL when DEBUG is off." }
] }
```

## Know what serves what

Development conveniences hide dependencies. The development server serves static files by itself only while DEBUG is on; in production something else must: a web server, a CDN, or middleware such as WhiteNoise. The same is true for the database URL (a missing variable should fail loudly, not fall back to a local file), for allowed hosts and CSRF origins behind a proxy, and for cookies over HTTPS. For each feature that "just works" in development, ask who provides it in production.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-config-serves-q1", "type": "mcq",
      "prompt": "With DEBUG = False, who serves /static/ files in a typical Django deployment?",
      "options": [
        {"id":"a","text":"Django serves them automatically"},
        {"id":"b","text":"Something you configured: a front web server or CDN, or middleware such as WhiteNoise, fed by collectstatic"},
        {"id":"c","text":"The database"},
        {"id":"d","text":"Nobody, static files only work in development"}
      ],
      "correct": "b",
      "explanation": "Django's own static handling is a development convenience that only works with DEBUG on. Production needs an explicit serving path for the collected files." }
] }
```

## Fix the configuration, do not switch off the check

The tempting fixes are the ones that hide the difference: turning DEBUG on, adding development-only URL routes, changing a setting on the server by hand. Prefer the fix that makes the environments equivalent in code, keep it in version control, and back it with a test on the settings module so the next change cannot silently remove it.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-config-fix-q1", "type": "mcq",
      "prompt": "Which is the appropriate way to make static files work in production?",
      "options": [
        {"id":"a","text":"Set DEBUG = True in the production settings"},
        {"id":"b","text":"Restore the production static-file serving in the settings (for example the WhiteNoise middleware after SecurityMiddleware) and test the settings module"},
        {"id":"c","text":"Add staticfiles_urlpatterns() to urls.py and leave DEBUG off"},
        {"id":"d","text":"Copy the files by hand on the server"}
      ],
      "correct": "b",
      "explanation": "DEBUG on exposes internals; staticfiles_urlpatterns() returns nothing when DEBUG is off; hand-copying is not reproducible. Configure the serving path in code and pin it with a test." }
] }
```
$md$, 15, $json$[{"id":"production-debugging-config-repro-q1","type":"mcq","correct":"b"},{"id":"production-debugging-config-serves-q1","type":"mcq","correct":"b"},{"id":"production-debugging-config-fix-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('c1289e9b-a81a-5c22-8ac8-85a15b3849ad', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '24ca35ad-5e2a-58ac-8dbe-a56c49ac3d26', 'Lab: Production has no styles or scripts', 'lab', 2, 30, '3330d553-8e04-5420-a133-5668093c8825', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('3330d553-8e04-5420-a133-5668093c8825', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'c1289e9b-a81a-5c22-8ac8-85a15b3849ad', 'module', 'Lab: Production has no styles or scripts', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && if [ "$(id -u)" = "0" ]; then exec runuser -u labuser -- bash .mf/setup.sh; else exec bash .mf/setup.sh; fi$script$, 90, 3, 0, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('f6dd3e45-6344-5cd5-84d4-711ca66b3514', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Production has no styles or scripts', $json${"app_range":"^1","blocks":[{"block_version_id":"d2d258df-ad25-5c50-9595-4c27ebbb039d"},{"block_version_id":"fff28088-69e5-59a9-abd1-86168b836c15"},{"block_version_id":"9e99164a-d7e5-5eb5-b11b-a29cc511af93"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"d81b7cdb-921f-511e-ac06-b6f608c1e395"},{"block_version_id":"018de84a-34e1-5831-8782-8e877ed4ae16"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":2008}$json$::jsonb, '3330d553-8e04-5420-a133-5668093c8825', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: Calls to other services
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('14f3c3f5-c499-5877-a007-80c1d544ce15', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'Calls to other services', 6, 'Django')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('d361fad8-5183-5df6-9507-6e9cf5eaecc2', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '14f3c3f5-c499-5877-a007-80c1d544ce15', 'Debugging calls to other services: design for the failure', 'notes', 1, $md$Every outbound call is a promise about a machine you do not control. Bugs in this area rarely appear when the other service is healthy, so the skill this section trains is making the other side misbehave on purpose and watching what your code does.

## Reproduce by making the dependency slow, flaky or different

The lab environment ships a stand-in for the payments provider that you can make slow, make fail after it has done the work, or make answer in a new format. Use that: put the dependency into the bad state, run the operation, and watch three things. How long does the request wait? What state does your database end up in? What does the customer see? A ticket that says "checkout hangs" is answered by the first; "customers were charged twice" by the second.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-svc-repro-q1", "type": "mcq",
      "prompt": "Checkout hangs only when the payments provider is having a bad day. How do you reproduce it?",
      "options": [
        {"id":"a","text":"Wait for the provider to have another bad day"},
        {"id":"b","text":"Make the provider stand-in slow on purpose and time the request"},
        {"id":"c","text":"Increase the number of web workers"},
        {"id":"d","text":"Read the provider's documentation"}
      ],
      "correct": "b",
      "explanation": "Dependency faults must be injected deliberately: slow it, fail it, change its answer. Then the behavior of your code is observable and repeatable." }
] }
```

## Every call needs a timeout and a failure mode

The `requests` library waits forever unless you give it a timeout. While a call waits, a worker thread and usually a database transaction are held, so one slow dependency can starve unrelated pages. Decide, for each outbound call, the longest you are willing to wait (separate connect and read limits), what happens when that expires (retry? which error to the user?), and whether retrying is safe. Retrying a charge is only safe if the provider can recognise it as the same request, which is what an idempotency key is for.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-svc-timeout-q1", "type": "mcq",
      "prompt": "A request to the payments provider has no timeout and the provider stops answering. What happens?",
      "options": [
        {"id":"a","text":"The requests library gives up after 30 seconds by default"},
        {"id":"b","text":"The call can wait indefinitely, holding a worker and its open transaction, and requests pile up behind it"},
        {"id":"c","text":"Django raises an exception after 5 seconds"},
        {"id":"d","text":"The database aborts the request"}
      ],
      "correct": "b",
      "explanation": "requests has no default timeout. The waiting request keeps its worker thread and transaction, so unrelated requests queue behind it." }
] }
```

## Fail loudly and locally

When a dependency changes or breaks, the worst outcome is a silent default: a missing field treated as zero, an unexpected status treated as declined. Prefer strict parsing that raises a clear error at the boundary, and translate provider failures into your own explicit error types and HTTP answers (service unavailable, bad gateway). Then test the boundary: a fake client that times out, fails, or answers in the wrong shape.

```knowledge-check
{ "questions": [
    { "id": "production-debugging-svc-loud-q1", "type": "mcq",
      "prompt": "The provider renames a response field and your code does data.get('status', 'declined'). What is the risk?",
      "options": [
        {"id":"a","text":"None, defaults make code robust"},
        {"id":"b","text":"Every charge silently looks declined; a strict parse that raises a clear contract error would surface the change immediately"},
        {"id":"c","text":"The provider will reject the request"},
        {"id":"d","text":"Django will fail to start"}
      ],
      "correct": "b",
      "explanation": "A silent default hides a contract change behind wrong business behavior. Failing loudly at the boundary turns it into an alert instead of lost sales."
    }
] }
```
$md$, 20, $json$[{"id":"production-debugging-svc-repro-q1","type":"mcq","correct":"b"},{"id":"production-debugging-svc-timeout-q1","type":"mcq","correct":"b"},{"id":"production-debugging-svc-loud-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('8fa0d22a-ebbd-559a-b52c-c7286b4f4927', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '14f3c3f5-c499-5877-a007-80c1d544ce15', 'Lab: Checkout hangs when the payments provider is slow', 'lab', 2, 40, '88ddbf53-8044-5817-b80e-c310be928f1d', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('88ddbf53-8044-5817-b80e-c310be928f1d', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '8fa0d22a-ebbd-559a-b52c-c7286b4f4927', 'module', 'Lab: Checkout hangs when the payments provider is slow', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && if [ "$(id -u)" = "0" ]; then exec runuser -u labuser -- bash .mf/setup.sh; else exec bash .mf/setup.sh; fi$script$, 90, 3, 0, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('c362bd0d-4874-5795-bcb9-5a145b8d6ca3', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Checkout hangs when the payments provider is slow', $json${"app_range":"^1","blocks":[{"block_version_id":"d2d258df-ad25-5c50-9595-4c27ebbb039d"},{"block_version_id":"31c50908-4cea-55db-a30a-7bfc68e0e5df"},{"block_version_id":"9e99164a-d7e5-5eb5-b11b-a29cc511af93"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"2e74b2e3-46ce-59a4-9c07-7eb7b75d40f5"},{"block_version_id":"018de84a-34e1-5831-8782-8e877ed4ae16"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":2009}$json$::jsonb, '88ddbf53-8044-5817-b80e-c310be928f1d', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO enrollments (id, user_id, course_id, enrolled_by)
VALUES ('fd0481e0-44c4-5c39-b8c8-aaf8ca8488bc', '00000000-0000-0000-0000-000000000014', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (user_id, course_id) DO NOTHING;

DELETE FROM course_modules WHERE course_id = '8af0a927-61bf-5a04-a2e9-e74f552564bf' AND id NOT IN ('660b721f-3bea-54bc-b2f9-7e9107365ccf', '89a9c00f-9137-58f9-af1a-1a2e7364e812', '46604227-42de-5739-ade3-783db7693447', '0721aba0-a80b-55a8-80e4-56ee4429c1e2', 'f0afbafc-7b67-5c97-a2bb-e19b9c19bca7', '16254531-52f4-5fe0-b1bd-743626184b8d', '10220d66-172f-58ae-b876-f829c0a7260f', '1ff1d0ec-7999-50ed-981b-a5ddb014f554', '96a415c6-071c-523e-8fc0-fc624f9db203', 'd5571474-dee0-523d-8e8d-ec18d39875ea', '9df2ff32-3dab-50ab-b05f-636076e3a25e', 'ebbf18aa-4dc6-5a82-a825-66bdb47bc875', '16e7356a-6487-5f42-9ddf-b6bcee59c28e', '178a3b24-fc15-534e-a93a-909609f07a1d', 'c1289e9b-a81a-5c22-8ac8-85a15b3849ad', 'd361fad8-5183-5df6-9507-6e9cf5eaecc2', '8fa0d22a-ebbd-559a-b52c-c7286b4f4927');
DELETE FROM course_sections WHERE course_id = '8af0a927-61bf-5a04-a2e9-e74f552564bf' AND id NOT IN ('db19aa3e-9ffb-5efc-a991-9344be87258c', '28d5d409-2fd5-586f-9971-8a6380813e83', '13dfba35-e5d7-565e-9324-7dda478ef6d8', '36b18bec-3fc7-5ea2-b7d0-b3b1015f663e', '24ca35ad-5e2a-58ac-8dbe-a56c49ac3d26', '14f3c3f5-c499-5877-a007-80c1d544ce15');

