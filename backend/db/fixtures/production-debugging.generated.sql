-- ══════════════════════════════════════════════════════════════════════════
-- GENERATED FILE — DO NOT EDIT.
-- Source: canonical markdown content (content/courses/**).
-- Regenerate via: cd backend && go run ./cmd/coursegen generate
-- Generated at: 2026-10-10T10:57:54Z
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Course: Production Debugging: Fix Real Bugs in a Live-Looking App ─────────────────────────────────────────────
INSERT INTO courses (id, org_id, creator_id, title, slug, description, cover_url, difficulty, tags, status, is_free, is_public, estimated_hours)
VALUES ('8af0a927-61bf-5a04-a2e9-e74f552564bf', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'Production Debugging: Fix Real Bugs in a Live-Looking App', 'production-debugging', 'Learn to debug the way it is done at work. Every lab drops you into a small, realistic e-commerce application (Django or FastAPI with PostgreSQL, and a React dashboard) inside a browser IDE with a real git history, a ticket from support or the on-call channel, logs, a database and a debugger. You reproduce the problem, follow the evidence to the root cause, fix it, prove the fix with a test that fails on the broken code, and write a short incident note. The Django track covers performance and query problems, data-model and money bugs, concurrency, migrations, configuration and calls to other services. The FastAPI track covers Alembic migrations, async SQLAlchemy performance, event-loop and concurrency bugs, outbound calls and error contracts, validation models, proxy configuration and authorization. The React track covers hooks and closures, async races, state and keys, render performance and leaks, and API and build configuration. The Fullstack track covers sessions, cookies and CORS, API contracts, and values that change meaning between browser and API. Each section starts with a short lesson on the debugging skill, never on the answer.', '/course-covers/production-debugging.svg', 'intermediate', ARRAY['debugging','django','fastapi','react','postgresql','performance','concurrency','migrations','incident-response'], 'published', true, true, 35.2)
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
VALUES ('09280cf0-b66f-5c34-a6ad-04655a503d7d', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '89a9c00f-9137-58f9-af1a-1a2e7364e812', 'module', 'Lab: The order list page is slow for repeat customers', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
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
VALUES ('5ce46d7b-c309-561b-86da-a76e2d8f32d3', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '46604227-42de-5739-ade3-783db7693447', 'module', 'Lab: The staff dashboard hits the database too often', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
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
VALUES ('558eca4d-99d4-5e87-a81d-c5ec61359b7b', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'f0afbafc-7b67-5c97-a2bb-e19b9c19bca7', 'module', 'Lab: Invoices vanish when a customer is deleted', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
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
VALUES ('993b6117-02b6-565e-a1b2-c3e11cc3585b', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '16254531-52f4-5fe0-b1bd-743626184b8d', 'module', 'Lab: Order totals are one cent off', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
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
VALUES ('2423b2fd-6c43-58fd-a69a-4f17bb8af4ff', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '10220d66-172f-58ae-b876-f829c0a7260f', 'module', 'Lab: Evening orders land on tomorrow''s report', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
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
VALUES ('93e8be17-50ba-5906-a165-ee41afb22179', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '96a415c6-071c-523e-8fc0-fc624f9db203', 'module', 'Lab: A burst of signups crashes with IntegrityError', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
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
VALUES ('9342f9f0-f34e-59ce-8b57-fa78117d4a77', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'd5571474-dee0-523d-8e8d-ec18d39875ea', 'module', 'Lab: The last unit is sold twice', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
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
VALUES ('176205d8-fda2-59cf-958e-294fc906f823', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'ebbf18aa-4dc6-5a82-a825-66bdb47bc875', 'module', 'Lab: The release is blocked by conflicting migrations', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
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
VALUES ('c5a95d95-e598-52f4-8a37-c15bc37ec911', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '16e7356a-6487-5f42-9ddf-b6bcee59c28e', 'module', 'Lab: A migration that only fails on production data', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
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
VALUES ('3330d553-8e04-5420-a133-5668093c8825', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'c1289e9b-a81a-5c22-8ac8-85a15b3849ad', 'module', 'Lab: Production has no styles or scripts', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
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
VALUES ('88ddbf53-8044-5817-b80e-c310be928f1d', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '8fa0d22a-ebbd-559a-b52c-c7286b4f4927', 'module', 'Lab: Checkout hangs when the payments provider is slow', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('c362bd0d-4874-5795-bcb9-5a145b8d6ca3', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Checkout hangs when the payments provider is slow', $json${"app_range":"^1","blocks":[{"block_version_id":"d2d258df-ad25-5c50-9595-4c27ebbb039d"},{"block_version_id":"31c50908-4cea-55db-a30a-7bfc68e0e5df"},{"block_version_id":"9e99164a-d7e5-5eb5-b11b-a29cc511af93"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"2e74b2e3-46ce-59a4-9c07-7eb7b75d40f5"},{"block_version_id":"018de84a-34e1-5831-8782-8e877ed4ae16"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":2009}$json$::jsonb, '88ddbf53-8044-5817-b80e-c310be928f1d', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: Migrations (Alembic)
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('2331f636-e8f9-5020-9bb0-4dc991097e89', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'Migrations (Alembic)', 7, 'FastAPI')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6d493c90-6a47-579d-8ee4-041b20e04e87', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '2331f636-e8f9-5020-9bb0-4dc991097e89', 'Debugging Alembic: the revision graph and the data it meets', 'notes', 1, $md$A migration bug is a deployment bug: it shows up at the worst moment, on the machine you cannot experiment on. The skill this section trains is bringing the failure back to your own machine by reproducing the exact starting state the migration ran on.

## Alembic revisions are a graph, not a list

Each revision names its parent in `down_revision`. File names, dates and the order in which people merged branches mean nothing. Two revisions with the same parent are two heads, and `alembic upgrade head` refuses to choose. Learn to read the graph with `alembic heads` and `alembic history`, and to fix a fork with a merge revision (`down_revision` is a tuple of both heads) instead of deleting files that may already have been applied elsewhere.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-alembic-graph-q1",
      "type": "mcq",
      "prompt": "Two Alembic revisions both list the same down_revision after a merge, and upgrade head fails with multiple heads. What is the safe fix?",
      "options": [
        {
          "id": "a",
          "text": "Delete one of the revisions"
        },
        {
          "id": "b",
          "text": "Add a merge revision whose down_revision is the tuple of both heads"
        },
        {
          "id": "c",
          "text": "Rename one file so it sorts later"
        },
        {
          "id": "d",
          "text": "Run upgrade with the --sql flag"
        }
      ],
      "correct": "b",
      "explanation": "The graph is defined by down_revision. A merge revision depending on both heads restores a single head without discarding history that may already be applied elsewhere."
    }
  ]
}
```

## A migration is a function of the schema and the data

A migration can pass on an empty database and on a freshly built staging database, and still fail on production, because production has rows. Adding a NOT NULL column with no default, creating a unique index over duplicates, changing a type over legacy values: all of these only fail when there is data. To debug one, bring a scratch database to the revision before the failing one (`alembic upgrade <revision>`), insert rows shaped like production, then upgrade forward and read the real error.

The usual fix is expand, backfill, constrain: add the column in a form existing rows can satisfy (nullable or with a server default), fill it, then tighten it.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-alembic-notnull-q1",
      "type": "mcq",
      "prompt": "A revision adds a NOT NULL column without a server default. It passes in CI and fails in production. Why?",
      "options": [
        {
          "id": "a",
          "text": "CI uses a different Alembic version"
        },
        {
          "id": "b",
          "text": "CI starts from an empty table, production has rows that need a value for the new column"
        },
        {
          "id": "c",
          "text": "PostgreSQL ignores NOT NULL in CI"
        },
        {
          "id": "d",
          "text": "The model had a default, which Alembic applies automatically"
        }
      ],
      "correct": "b",
      "explanation": "The migration runs against existing rows. Without a default or a backfill there is no value for them, and PostgreSQL aborts the ALTER TABLE."
    }
  ]
}
```
$md$, 20, $json$[{"id":"production-debugging-fa-alembic-graph-q1","type":"mcq","correct":"b"},{"id":"production-debugging-fa-alembic-notnull-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('ecfe452d-d7ac-5781-a44e-34fd8a62c665', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '2331f636-e8f9-5020-9bb0-4dc991097e89', 'Lab: The release is blocked by multiple Alembic heads', 'lab', 2, 30, '1b36fcfb-f6f6-5536-99bb-6444f985c8fa', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('1b36fcfb-f6f6-5536-99bb-6444f985c8fa', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'ecfe452d-d7ac-5781-a44e-34fd8a62c665', 'module', 'Lab: The release is blocked by multiple Alembic heads', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('30c15990-076d-54d7-b792-462de42471d7', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: The release is blocked by multiple Alembic heads', $json${"app_range":"^1","blocks":[{"block_version_id":"7f4707a2-1c83-5c77-9c17-3daf6d0ddf6e"},{"block_version_id":"8dbb8952-8962-5e1a-8ef8-b1866ff38aad"},{"block_version_id":"592cc315-ea72-5910-b845-b2bbe06c8ed1"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"288860c8-832f-5945-8535-317aecb45d12"},{"block_version_id":"71dbc11d-7b43-5659-8899-01143803cf74"}],"seed":3001}$json$::jsonb, '1b36fcfb-f6f6-5536-99bb-6444f985c8fa', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('23b9f1d1-15f2-53f7-9f8b-049ac030323c', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '2331f636-e8f9-5020-9bb0-4dc991097e89', 'Lab: A migration works in staging and crashes on production', 'lab', 3, 40, '2cd9777f-6b4c-5b82-a26b-216ccea83c55', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('2cd9777f-6b4c-5b82-a26b-216ccea83c55', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '23b9f1d1-15f2-53f7-9f8b-049ac030323c', 'module', 'Lab: A migration works in staging and crashes on production', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('375f68ea-d450-5702-bbc4-20ce3861780f', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: A migration works in staging and crashes on production', $json${"app_range":"^1","blocks":[{"block_version_id":"7f4707a2-1c83-5c77-9c17-3daf6d0ddf6e"},{"block_version_id":"2e42c65b-106b-5445-971d-ef43fd99f971"},{"block_version_id":"592cc315-ea72-5910-b845-b2bbe06c8ed1"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"288860c8-832f-5945-8535-317aecb45d12"},{"block_version_id":"71dbc11d-7b43-5659-8899-01143803cf74"}],"seed":3002}$json$::jsonb, '2cd9777f-6b4c-5b82-a26b-216ccea83c55', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: Performance (SQLAlchemy)
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('f6ccdc79-34fc-5ec3-a606-ef0c4b200d90', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'Performance (SQLAlchemy)', 8, 'FastAPI')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('d46741c3-3276-5ccb-a9a4-ce47acc6ab1f', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'f6ccdc79-34fc-5ec3-a606-ef0c4b200d90', 'Measure first: counting statements in async SQLAlchemy', 'notes', 1, $md$A slow endpoint is a claim about time; a cause is a claim about work. The skill this section trains is turning "it is slow" into a number you can reproduce: how many SQL statements does one request run, and does that number grow with the data?

## Count statements, not milliseconds

Wall-clock time depends on the machine, the cache and the network. The number of statements a request runs does not. Turn on statement logging (`echo=True` on the engine or the `sqlalchemy.engine` logger at INFO), call the endpoint for a small and a large customer, and compare. A count that grows with the number of rows is an N+1: one query for the list and one more for every row.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-sa-count-q1",
      "type": "mcq",
      "prompt": "An endpoint returns in 40 ms for a customer with 2 orders and 8 s for one with 400 orders. What do you measure first?",
      "options": [
        {
          "id": "a",
          "text": "CPU frequency of the server"
        },
        {
          "id": "b",
          "text": "How many SQL statements each request runs for the small and the large customer"
        },
        {
          "id": "c",
          "text": "The size of the JSON response in bytes"
        },
        {
          "id": "d",
          "text": "The Python version"
        }
      ],
      "correct": "b",
      "explanation": "A statement count that grows with the number of rows is the signature of an N+1 and is independent of machine speed."
    }
  ]
}
```

## Relationships here never load implicitly

In this service relationships are declared with `lazy="raise"`: touching an unloaded relationship raises instead of silently issuing SQL, because a lazy load inside async code cannot work. That protects you from hidden queries, but it also means the data is loaded wherever the query is written. Eager loading (`selectinload` for collections, `joinedload` for single parents) loads the related rows for all returned objects at once, in a constant number of statements.

Fix the query, then prove it: a test that records the statements of one request for a small and a large dataset and asserts that the count is equal.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-sa-eager-q1",
      "type": "mcq",
      "prompt": "What does selectinload(Order.items) do for a list of 50 orders?",
      "options": [
        {
          "id": "a",
          "text": "Runs one extra statement per order"
        },
        {
          "id": "b",
          "text": "Loads the items of all 50 orders with one extra statement"
        },
        {
          "id": "c",
          "text": "Caches the items in the process"
        },
        {
          "id": "d",
          "text": "Defers loading until the attribute is accessed"
        }
      ],
      "correct": "b",
      "explanation": "selectinload issues one additional SELECT ... WHERE order_id IN (...) for all returned parents, so the number of statements does not grow with the rows."
    }
  ]
}
```
$md$, 20, $json$[{"id":"production-debugging-fa-sa-count-q1","type":"mcq","correct":"b"},{"id":"production-debugging-fa-sa-eager-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('a6ca0747-5929-5d25-9aef-4a125bb1bed4', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'f6ccdc79-34fc-5ec3-a606-ef0c4b200d90', 'Lab: The order list is slow for repeat customers', 'lab', 2, 40, 'f639e9d6-87be-5d44-b327-3e9212ad6e1b', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('f639e9d6-87be-5d44-b327-3e9212ad6e1b', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'a6ca0747-5929-5d25-9aef-4a125bb1bed4', 'module', 'Lab: The order list is slow for repeat customers', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('15e15a45-4422-5e75-a486-b50ad3b2f4ea', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: The order list is slow for repeat customers', $json${"app_range":"^1","blocks":[{"block_version_id":"7f4707a2-1c83-5c77-9c17-3daf6d0ddf6e"},{"block_version_id":"ff9ec0f5-0cc3-5c35-aee0-a3c45917e0b2"},{"block_version_id":"592cc315-ea72-5910-b845-b2bbe06c8ed1"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"b1e52808-dc29-542f-a644-96c307e21f42"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":3003}$json$::jsonb, 'f639e9d6-87be-5d44-b327-3e9212ad6e1b', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: Async and concurrency
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('f22bb6dc-9cc9-56a5-881c-54d11c5fd8bf', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'Async and concurrency', 9, 'FastAPI')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('735a6afc-cb17-5887-884c-d999886d79ed', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'f22bb6dc-9cc9-56a5-881c-54d11c5fd8bf', 'Debugging async code: the loop and the races between awaits', 'notes', 1, $md$Async bugs look like load problems: everything is fine for one user and strange for many. The skill this section trains is asking, for every `await` and every blocking call, who else gets to run at that point.

## One event loop, many requests

An `async def` handler runs on the event loop thread, which serves every request of the process. Any call that does not yield (CPU-bound work, `time.sleep`, a blocking library) stops the whole loop until it returns, so unrelated requests, even the health check, wait. Plain `def` endpoints and `run_in_threadpool` move work to worker threads. Reproduce it by timing a cheap endpoint while the suspect endpoint runs.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-async-loop-q1",
      "type": "mcq",
      "prompt": "A login endpoint calls bcrypt directly inside an async def. What is the effect on other requests?",
      "options": [
        {
          "id": "a",
          "text": "None, async handlers run in parallel automatically"
        },
        {
          "id": "b",
          "text": "Each login freezes the event loop, so every other request in the process waits"
        },
        {
          "id": "c",
          "text": "Only other logins are affected"
        },
        {
          "id": "d",
          "text": "The database connection is closed"
        }
      ],
      "correct": "b",
      "explanation": "bcrypt is CPU-bound and synchronous. On the event loop thread it blocks all coroutines until it finishes; run it in the thread pool instead."
    }
  ]
}
```

## Await is a scheduling point

A single-threaded loop does not make code atomic. Between two awaits other requests run, and the database sees interleaved statements from many sessions. "Read the value, compute in Python, write it back" across awaits loses updates exactly like threads do. Push the arithmetic into one statement (`UPDATE ... SET x = x + :n`), or lock the row (`SELECT ... FOR UPDATE`); an in-process lock does not survive a second worker.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-async-race-q1",
      "type": "mcq",
      "prompt": "Two concurrent credits read the same balance, add their amount in Python and write it back. What happens?",
      "options": [
        {
          "id": "a",
          "text": "Both are applied, asyncio serialises them"
        },
        {
          "id": "b",
          "text": "One credit is lost, because both wrote balance plus their own amount"
        },
        {
          "id": "c",
          "text": "The second request fails with an error"
        },
        {
          "id": "d",
          "text": "PostgreSQL merges the two writes"
        }
      ],
      "correct": "b",
      "explanation": "The read and the write are separate round trips with awaits in between. Both requests saw the old balance, so the later write overwrites the earlier one."
    }
  ]
}
```
$md$, 20, $json$[{"id":"production-debugging-fa-async-loop-q1","type":"mcq","correct":"b"},{"id":"production-debugging-fa-async-race-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('dc648be3-e909-5f93-984c-ca1a144edf7e', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'f22bb6dc-9cc9-56a5-881c-54d11c5fd8bf', 'Lab: The whole API freezes whenever somebody logs in', 'lab', 2, 40, '0336fcfa-9081-5a32-9b83-868418ec94fd', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('0336fcfa-9081-5a32-9b83-868418ec94fd', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'dc648be3-e909-5f93-984c-ca1a144edf7e', 'module', 'Lab: The whole API freezes whenever somebody logs in', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('15d75968-6b2d-54d2-8e7d-e7b2aa76b0ee', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: The whole API freezes whenever somebody logs in', $json${"app_range":"^1","blocks":[{"block_version_id":"7f4707a2-1c83-5c77-9c17-3daf6d0ddf6e"},{"block_version_id":"17ca7706-7f2f-5996-8815-232b0cf3cfd8"},{"block_version_id":"592cc315-ea72-5910-b845-b2bbe06c8ed1"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"58f7c05b-d75f-5118-b108-b11d2bc735d2"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":3004}$json$::jsonb, '0336fcfa-9081-5a32-9b83-868418ec94fd', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('aebc53b8-eba9-5cfa-b938-2864e04ab883', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'f22bb6dc-9cc9-56a5-881c-54d11c5fd8bf', 'Lab: Store credit goes missing under load', 'lab', 3, 50, 'b7c76879-3c9b-5e19-b968-824586f84950', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('b7c76879-3c9b-5e19-b968-824586f84950', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'aebc53b8-eba9-5cfa-b938-2864e04ab883', 'module', 'Lab: Store credit goes missing under load', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('00f0d894-2723-5c43-9e49-200950a151f9', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Store credit goes missing under load', $json${"app_range":"^1","blocks":[{"block_version_id":"7f4707a2-1c83-5c77-9c17-3daf6d0ddf6e"},{"block_version_id":"2cd187d1-a611-5668-bf74-451272de0ba8"},{"block_version_id":"592cc315-ea72-5910-b845-b2bbe06c8ed1"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"21287b22-d413-5e0d-8c7f-8b60beefee16"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":3005}$json$::jsonb, 'b7c76879-3c9b-5e19-b968-824586f84950', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: Service calls and errors
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('7ba71527-a3f1-5f33-8baa-08c884adf01e', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'Service calls and errors', 10, 'FastAPI')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('31028379-3faa-5d91-93f5-97ae7fa8af99', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '7ba71527-a3f1-5f33-8baa-08c884adf01e', 'Debugging outbound calls and the errors you report', 'notes', 1, $md$Every outbound call is a promise about a machine you do not control, and every error response is a promise to the callers of your own API. The skill this section trains is making the dependency misbehave on purpose and checking what your service says about it.

## Every call needs a timeout

httpx lets you set `timeout=None`, which waits forever. A waiting request holds a database connection and often a row lock, so a slow provider starves unrelated endpoints until the pool is empty. Decide the longest you will wait (connect and read), turn that into a clear error for the caller (a 504), and take the value from configuration. The lab environment ships a payments stand-in with a fault switch so you can reproduce the slow provider.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-svc-timeout-q1",
      "type": "mcq",
      "prompt": "The payments provider stops answering and the httpx client was created with timeout=None. What happens to pay requests?",
      "options": [
        {
          "id": "a",
          "text": "httpx gives up after 5 seconds by default"
        },
        {
          "id": "b",
          "text": "They wait indefinitely while holding a database connection, and the pool eventually runs dry"
        },
        {
          "id": "c",
          "text": "FastAPI cancels them after 30 seconds"
        },
        {
          "id": "d",
          "text": "The database aborts them"
        }
      ],
      "correct": "b",
      "explanation": "timeout=None disables every httpx timeout. Stuck requests keep their sessions, so unrelated endpoints that need a connection start failing too."
    }
  ]
}
```

## Status codes are the contract

Load balancers, retry logic, SDKs, dashboards and alerts decide success from the status code, not from the body. A handler that turns a failure into `200 {"status": "error"}` is invisible to all of them: zero errors on the dashboard while customers cannot pay. Map each failure to the status that matches it (402 for a decline, 504 for a provider timeout, 502 for an unreachable provider) and keep the human-readable message in the body. Then test the mapping with a fake client that fails in each way.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-svc-status-q1",
      "type": "mcq",
      "prompt": "A pay endpoint answers 200 with an error message in the body when the provider is down. Which part of the system is blind to the failure?",
      "options": [
        {
          "id": "a",
          "text": "Only the database"
        },
        {
          "id": "b",
          "text": "Clients, monitoring and alerts that decide success from the status code"
        },
        {
          "id": "c",
          "text": "Nothing, the body carries the error"
        },
        {
          "id": "d",
          "text": "Only the browser"
        }
      ],
      "correct": "b",
      "explanation": "Anything keyed to the HTTP status sees a success. Failures must be reported with an error status so the surrounding tooling can react."
    }
  ]
}
```
$md$, 20, $json$[{"id":"production-debugging-fa-svc-timeout-q1","type":"mcq","correct":"b"},{"id":"production-debugging-fa-svc-status-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('4053b2d0-9f6a-55ef-bf2e-14ab6e45ef5d', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '7ba71527-a3f1-5f33-8baa-08c884adf01e', 'Lab: Paying hangs when the payments provider is slow', 'lab', 2, 40, '4c10f9a6-d415-5ad5-ac39-ceaa6da526f1', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('4c10f9a6-d415-5ad5-ac39-ceaa6da526f1', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '4053b2d0-9f6a-55ef-bf2e-14ab6e45ef5d', 'module', 'Lab: Paying hangs when the payments provider is slow', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('33d416eb-7e5e-5f9c-b279-10bd35aeee46', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Paying hangs when the payments provider is slow', $json${"app_range":"^1","blocks":[{"block_version_id":"7f4707a2-1c83-5c77-9c17-3daf6d0ddf6e"},{"block_version_id":"df05f196-fe06-5a8a-9f15-cfbc96b84173"},{"block_version_id":"592cc315-ea72-5910-b845-b2bbe06c8ed1"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"2e74b2e3-46ce-59a4-9c07-7eb7b75d40f5"},{"block_version_id":"018de84a-34e1-5831-8782-8e877ed4ae16"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":3006}$json$::jsonb, '4c10f9a6-d415-5ad5-ac39-ceaa6da526f1', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('8e19bd8c-f21d-555a-b0d3-88598b3185dc', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '7ba71527-a3f1-5f33-8baa-08c884adf01e', 'Lab: Customers cannot pay but the dashboards show no errors', 'lab', 3, 30, '4c9d53d1-38d6-5cd4-a2c0-e036fd299b72', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('4c9d53d1-38d6-5cd4-a2c0-e036fd299b72', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '8e19bd8c-f21d-555a-b0d3-88598b3185dc', 'module', 'Lab: Customers cannot pay but the dashboards show no errors', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('252636f4-6b11-59e8-8780-92a52f88adaf', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Customers cannot pay but the dashboards show no errors', $json${"app_range":"^1","blocks":[{"block_version_id":"7f4707a2-1c83-5c77-9c17-3daf6d0ddf6e"},{"block_version_id":"a2b729ce-362a-5286-956d-13df67739048"},{"block_version_id":"592cc315-ea72-5910-b845-b2bbe06c8ed1"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"2e74b2e3-46ce-59a4-9c07-7eb7b75d40f5"},{"block_version_id":"018de84a-34e1-5831-8782-8e877ed4ae16"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":3010}$json$::jsonb, '4c9d53d1-38d6-5cd4-a2c0-e036fd299b72', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: Data model and validation
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('d443dfcc-5cdc-5ad5-a262-ebc3bb1e5af4', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'Data model and validation', 11, 'FastAPI')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('3b20905c-f13e-52f9-bf4f-b5db45df634d', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'd443dfcc-5cdc-5ad5-a262-ebc3bb1e5af4', 'Debugging validation models: absent is not the same as null', 'notes', 1, $md$Pydantic models are the boundary between the outside world and your data. A bug here rarely raises: it quietly writes the wrong thing. The skill this section trains is asking, for every field, what the model does when the client sends it, omits it, or sends null.

## Three states, two representations

A PATCH body can contain a value, an explicit null (clear this field) or nothing at all (leave it alone). A model field with a default of `None` collapses the last two. Pydantic remembers which fields were actually provided: `model_dump(exclude_unset=True)` returns exactly those. `model_dump()` returns everything, defaults included, so applying it overwrites the fields the client never mentioned. Reproduce it by sending a single field and reading the whole resource back.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-pyd-unset-q1",
      "type": "mcq",
      "prompt": "A PATCH model has phone: str | None = None and company: str | None = None. The client sends only {\"phone\": \"123\"}. What does payload.model_dump() contain?",
      "options": [
        {
          "id": "a",
          "text": "Only phone"
        },
        {
          "id": "b",
          "text": "phone and company (company as None)"
        },
        {
          "id": "c",
          "text": "Nothing"
        },
        {
          "id": "d",
          "text": "An error"
        }
      ],
      "correct": "b",
      "explanation": "model_dump() includes every field with its default. Use exclude_unset=True to get only the fields the client sent."
    }
  ]
}
```
$md$, 20, $json$[{"id":"production-debugging-fa-pyd-unset-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('96911d8c-e8ed-548f-b3bc-f10f9f4b0ab8', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'd443dfcc-5cdc-5ad5-a262-ebc3bb1e5af4', 'Lab: Saving one profile field erases the others', 'lab', 2, 35, 'd2870ad8-26f4-57af-a8ee-60193e008157', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('d2870ad8-26f4-57af-a8ee-60193e008157', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '96911d8c-e8ed-548f-b3bc-f10f9f4b0ab8', 'module', 'Lab: Saving one profile field erases the others', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('b3369799-07c9-5535-9f7f-9834c99a177c', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Saving one profile field erases the others', $json${"app_range":"^1","blocks":[{"block_version_id":"7f4707a2-1c83-5c77-9c17-3daf6d0ddf6e"},{"block_version_id":"534f2bcf-b615-5c90-a586-a644805512c4"},{"block_version_id":"592cc315-ea72-5910-b845-b2bbe06c8ed1"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"018de84a-34e1-5831-8782-8e877ed4ae16"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":3007}$json$::jsonb, 'd2870ad8-26f4-57af-a8ee-60193e008157', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: Configuration and security
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('a085bf16-522a-52c6-8c87-7fe214b3c60e', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'Configuration and security', 12, 'FastAPI')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('5ac0efb6-16e1-5d01-a142-a381c0a7e10d', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'a085bf16-522a-52c6-8c87-7fe214b3c60e', 'Debugging deployment settings and authorization', 'notes', 1, $md$Two kinds of bugs only exist outside your laptop: the ones created by the environment around the app, and the ones created by people who are not you. The skill this section trains is checking what the app assumes about both.

## The proxy is part of the environment

Behind a gateway the service is often mounted under a path prefix that the proxy strips before forwarding. The app learns the prefix as `root_path` (uvicorn's `--root-path`) and needs it only for URLs it hands back to the browser, such as the OpenAPI document that the docs page fetches. Built-in FastAPI routes handle that; a hand-written URL like `/openapi.json` does not. Test it the way the proxy sees it: `TestClient(app, root_path="/api")`, with more than one prefix so a hard-coded value cannot pass.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-cfg-root-q1",
      "type": "mcq",
      "prompt": "The docs page works locally and is blank behind the gateway that mounts the service under /api. The page requests /openapi.json. Why does the browser get a 404?",
      "options": [
        {
          "id": "a",
          "text": "The schema is not generated in production"
        },
        {
          "id": "b",
          "text": "The schema URL ignores the gateway's path prefix (root_path), so it points at the gateway root"
        },
        {
          "id": "c",
          "text": "CORS is blocking it"
        },
        {
          "id": "d",
          "text": "Swagger UI does not support proxies"
        }
      ],
      "correct": "b",
      "explanation": "The proxy strips /api before forwarding but the browser still has to request /api/openapi.json. The prefix must come from root_path instead of being hard-coded."
    }
  ]
}
```

## Authentication is not authorization

A valid token says who is calling, not what they may touch. An endpoint that takes an id from the URL must scope the query to the caller (`WHERE id = :id AND customer_id = :me`) so that somebody else's id is indistinguishable from a missing one. Sequential ids make the missing check trivially exploitable (an insecure direct object reference), but random ids only make it harder to guess, not safe. Test with two users: the owner gets the object, the stranger gets a 404.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-sec-idor-q1",
      "type": "mcq",
      "prompt": "GET /orders/{id} returns any order to any signed-in customer. What is the correct fix?",
      "options": [
        {
          "id": "a",
          "text": "Use random UUIDs instead of sequential ids"
        },
        {
          "id": "b",
          "text": "Scope the query to the signed-in customer so other people's ids return 404"
        },
        {
          "id": "c",
          "text": "Rate-limit the endpoint"
        },
        {
          "id": "d",
          "text": "Hide the endpoint from the docs page"
        }
      ],
      "correct": "b",
      "explanation": "The vulnerability is the missing ownership check. Scoping the query fixes the root cause, whatever the id format."
    }
  ]
}
```
$md$, 20, $json$[{"id":"production-debugging-fa-cfg-root-q1","type":"mcq","correct":"b"},{"id":"production-debugging-fa-sec-idor-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('913e0966-7661-5e6d-80b2-d6cfd7e556c5', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'a085bf16-522a-52c6-8c87-7fe214b3c60e', 'Lab: The API docs are blank behind the gateway', 'lab', 2, 35, '68da45aa-f1ac-57c7-a836-dd5b98ac929a', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('68da45aa-f1ac-57c7-a836-dd5b98ac929a', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '913e0966-7661-5e6d-80b2-d6cfd7e556c5', 'module', 'Lab: The API docs are blank behind the gateway', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('0894e92c-fbb4-566e-98c8-e6e1272d2263', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: The API docs are blank behind the gateway', $json${"app_range":"^1","blocks":[{"block_version_id":"7f4707a2-1c83-5c77-9c17-3daf6d0ddf6e"},{"block_version_id":"f64d080c-a589-5a1a-80f6-f885b250a0ac"},{"block_version_id":"592cc315-ea72-5910-b845-b2bbe06c8ed1"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":3008}$json$::jsonb, '68da45aa-f1ac-57c7-a836-dd5b98ac929a', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('8eb9f7c2-90d2-5ba9-998f-46a268def26b', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'a085bf16-522a-52c6-8c87-7fe214b3c60e', 'Lab: Any customer can read any order', 'lab', 3, 35, '2148d76b-cec8-5f1b-8ff8-8e99edebe34b', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('2148d76b-cec8-5f1b-8ff8-8e99edebe34b', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '8eb9f7c2-90d2-5ba9-998f-46a268def26b', 'module', 'Lab: Any customer can read any order', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('e5e8ff02-2907-54a5-91c8-377a75db0dbb', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Any customer can read any order', $json${"app_range":"^1","blocks":[{"block_version_id":"7f4707a2-1c83-5c77-9c17-3daf6d0ddf6e"},{"block_version_id":"5ccabd41-3c70-5b74-9d6f-ff7bd65bb0a0"},{"block_version_id":"592cc315-ea72-5910-b845-b2bbe06c8ed1"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"018de84a-34e1-5831-8782-8e877ed4ae16"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"9f013da8-2692-5987-9ddf-8f056d257d87"}],"seed":3009}$json$::jsonb, '2148d76b-cec8-5f1b-8ff8-8e99edebe34b', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('800220a8-7363-5f99-8424-bf66ef070c48', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'a085bf16-522a-52c6-8c87-7fe214b3c60e', 'Expert lab: Double charges, then a frozen API, then a kill switch that does nothing', 'lab', 4, 120, '72f351e0-3d75-56b5-b3e2-fc26f79f8b38', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('72f351e0-3d75-56b5-b3e2-fc26f79f8b38', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '800220a8-7363-5f99-8424-bf66ef070c48', 'module', 'Expert lab: Double charges, then a frozen API, then a kill switch that does nothing', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 180, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('200c1c6d-4312-5b50-80a9-139f54bae11d', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Expert lab: Double charges, then a frozen API, then a kill switch that does nothing', $json${"app_range":"^1","blocks":[{"block_version_id":"7f4707a2-1c83-5c77-9c17-3daf6d0ddf6e"},{"block_version_id":"39b24a45-8b9e-5344-9663-9218993b5694"},{"block_version_id":"b25adfa3-c22d-5048-9cb5-22872fa70222"},{"block_version_id":"695cacfd-9ca1-5de4-bd1d-99cf249b8c98"},{"block_version_id":"592cc315-ea72-5910-b845-b2bbe06c8ed1"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"138b9154-6030-58ce-ba37-68f3c50e861e"},{"block_version_id":"018de84a-34e1-5831-8782-8e877ed4ae16"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":3012}$json$::jsonb, '72f351e0-3d75-56b5-b3e2-fc26f79f8b38', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: React hooks
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('04e3dbe5-5840-5ac9-a2e2-23f30ce162df', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'React hooks', 13, 'React')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('1d6973ab-711f-5053-96f7-a31386b782f7', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '04e3dbe5-5840-5ac9-a2e2-23f30ce162df', 'Debugging hooks: dependencies, closures and identity', 'notes', 1, $md$## An effect is a closure over one render

Every render creates new functions that see that render's props and state. A timer or listener created in one render keeps reading that render's values until it is replaced, which is why a counter freezes or a filter is ignored. Debug it by asking which render a callback was created in, and what its dependency array promises about when it is recreated.

The fixes are small and specific: read the latest value through a functional update, list every value the effect reads, and keep dependencies stable.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-re-hooks-q1",
      "type": "mcq",
      "prompt": "An interval callback does setSeconds(seconds + 1) and the badge stops at 1. Why?",
      "options": [
        {
          "id": "a",
          "text": "setState is asynchronous"
        },
        {
          "id": "b",
          "text": "The callback closes over the seconds value of the render that created the interval"
        },
        {
          "id": "c",
          "text": "React batches interval updates"
        },
        {
          "id": "d",
          "text": "The interval is cleared on each render"
        }
      ],
      "correct": "b",
      "explanation": "The callback was created once and always sees the first render's value. A functional update (current => current + 1) reads the latest state instead."
    }
  ]
}
```

## Objects are new on every render

An object or array created in a component body is a new reference each render. Put it in an effect's dependency array and the effect re-runs every render; if the effect sets state or fetches, that is an endless loop visible in the network tab. Depend on the primitive fields the effect actually reads.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-re-hooks-q2",
      "type": "mcq",
      "prompt": "An effect lists an options object built in the parent's body in its dependencies, and requests repeat forever. What is the fix?",
      "options": [
        {
          "id": "a",
          "text": "Remove the dependency array"
        },
        {
          "id": "b",
          "text": "Depend on the primitive values the effect reads, such as options.days"
        },
        {
          "id": "c",
          "text": "Wrap the fetch in setTimeout"
        },
        {
          "id": "d",
          "text": "Call the effect from a click handler"
        }
      ],
      "correct": "b",
      "explanation": "Primitives compare by value, so the effect only re-runs when the data it uses changes."
    }
  ]
}
```
$md$, 15, $json$[{"id":"production-debugging-re-hooks-q1","type":"mcq","correct":"b"},{"id":"production-debugging-re-hooks-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('bab1cceb-f2ea-5518-b789-de8c33541f2d', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '04e3dbe5-5840-5ac9-a2e2-23f30ce162df', 'Lab: The updated badge never gets past 1', 'lab', 2, 25, '98252ca4-7c95-5bee-a5f9-f530175625a5', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('98252ca4-7c95-5bee-a5f9-f530175625a5', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'bab1cceb-f2ea-5518-b789-de8c33541f2d', 'module', 'Lab: The updated badge never gets past 1', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('1d4b0d83-489c-52b7-ac99-9c8524151c46', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: The updated badge never gets past 1', $json${"app_range":"^1","blocks":[{"block_version_id":"bcc03b0f-33fa-5a67-b2a9-e0660bc70325"},{"block_version_id":"39983e5c-8662-5c0b-9ae8-0665476a54b6"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"cdfbc19a-8f9d-5e97-96b4-99201f8eb49a"}],"seed":4108}$json$::jsonb, '98252ca4-7c95-5bee-a5f9-f530175625a5', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('87886ae8-7324-53d6-a83d-8e0c5cbbf329', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '04e3dbe5-5840-5ac9-a2e2-23f30ce162df', 'Lab: Changing the status filter does not reload orders', 'lab', 3, 30, '661c83aa-ccd7-5fc7-b731-e7b03640ecb4', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('661c83aa-ccd7-5fc7-b731-e7b03640ecb4', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '87886ae8-7324-53d6-a83d-8e0c5cbbf329', 'module', 'Lab: Changing the status filter does not reload orders', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('f0376762-73dd-54a5-88bb-aad8e120b5f5', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Changing the status filter does not reload orders', $json${"app_range":"^1","blocks":[{"block_version_id":"bcc03b0f-33fa-5a67-b2a9-e0660bc70325"},{"block_version_id":"895b9be7-cf96-50b8-b6d6-88e2c3d80bb1"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"cdfbc19a-8f9d-5e97-96b4-99201f8eb49a"}],"seed":4106}$json$::jsonb, '661c83aa-ccd7-5fc7-b731-e7b03640ecb4', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('0339708c-c52d-5c88-9f1a-3c998f99afa5', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '04e3dbe5-5840-5ac9-a2e2-23f30ce162df', 'Lab: The Reports page hammers the API', 'lab', 4, 30, '20bf8288-5894-53b3-bf78-38a2cf43027e', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('20bf8288-5894-53b3-bf78-38a2cf43027e', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '0339708c-c52d-5c88-9f1a-3c998f99afa5', 'module', 'Lab: The Reports page hammers the API', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('dd6f159b-85cc-5866-8078-c0016246ce81', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: The Reports page hammers the API', $json${"app_range":"^1","blocks":[{"block_version_id":"bcc03b0f-33fa-5a67-b2a9-e0660bc70325"},{"block_version_id":"04951822-47aa-544a-9e9d-4220e689055a"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"cdfbc19a-8f9d-5e97-96b4-99201f8eb49a"}],"seed":4107}$json$::jsonb, '20bf8288-5894-53b3-bf78-38a2cf43027e', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: Async and races
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('06f976a5-6d4e-5961-bd6c-40e192be837f', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'Async and races', 14, 'React')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('5b282640-e3f3-5709-8fe5-1bddc42f7c14', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '06f976a5-6d4e-5961-bd6c-40e192be837f', 'Debugging async UI: ordering and failure paths', 'notes', 1, $md$## Responses do not arrive in the order requests were sent

A typeahead that applies every response will show the answer to an older query whenever that request is slower. Reproduce it by delaying the first response in a test, then make the effect ignore stale results or abort the previous request in its cleanup.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-re-async-q1",
      "type": "mcq",
      "prompt": "A search box shows results for an earlier query after typing quickly. What is the usual cause?",
      "options": [
        {
          "id": "a",
          "text": "The server caches responses"
        },
        {
          "id": "b",
          "text": "Every response is applied, including slower answers to older queries"
        },
        {
          "id": "c",
          "text": "React renders effects out of order"
        },
        {
          "id": "d",
          "text": "The input is uncontrolled"
        }
      ],
      "correct": "b",
      "explanation": "Nothing ties a response to the current query. Cleanup that cancels or ignores the previous request fixes it."
    }
  ]
}
```

## Optimistic updates need a rollback

Updating the UI before the server confirms is fine, but the failure branch must restore the previous state as well as show a message. Read the catch block and ask what state the screen is left in.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-re-async-q2",
      "type": "mcq",
      "prompt": "An optimistic flag toggle shows an error but the flag stays on. What is missing?",
      "options": [
        {
          "id": "a",
          "text": "A loading spinner"
        },
        {
          "id": "b",
          "text": "Restoring the previous state in the failure path"
        },
        {
          "id": "c",
          "text": "A longer timeout"
        },
        {
          "id": "d",
          "text": "A second request"
        }
      ],
      "correct": "b",
      "explanation": "The optimistic change was never undone, so the screen disagrees with the server."
    }
  ]
}
```
$md$, 15, $json$[{"id":"production-debugging-re-async-q1","type":"mcq","correct":"b"},{"id":"production-debugging-re-async-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('5eba040b-3ebf-5599-abf0-8b7ab1cd2bed', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '06f976a5-6d4e-5961-bd6c-40e192be837f', 'Lab: Customer search shows results for an older query', 'lab', 2, 35, 'd8045b28-345c-5469-8bd9-055d231a1a5e', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('d8045b28-345c-5469-8bd9-055d231a1a5e', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '5eba040b-3ebf-5599-abf0-8b7ab1cd2bed', 'module', 'Lab: Customer search shows results for an older query', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('906d4566-350f-5b18-ba31-8809bf0f5546', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Customer search shows results for an older query', $json${"app_range":"^1","blocks":[{"block_version_id":"bcc03b0f-33fa-5a67-b2a9-e0660bc70325"},{"block_version_id":"20bf5a47-62a4-57cd-8eb4-cb85cbedf041"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"cdfbc19a-8f9d-5e97-96b4-99201f8eb49a"}],"seed":4104}$json$::jsonb, 'd8045b28-345c-5469-8bd9-055d231a1a5e', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('996c0dc8-fbc6-5b48-9857-94180ed1e198', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '06f976a5-6d4e-5961-bd6c-40e192be837f', 'Lab: An order stays flagged after the server refused it', 'lab', 3, 30, '1e370030-2d5c-5002-b0cb-6b9cc3150cb2', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('1e370030-2d5c-5002-b0cb-6b9cc3150cb2', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '996c0dc8-fbc6-5b48-9857-94180ed1e198', 'module', 'Lab: An order stays flagged after the server refused it', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('7c0b59d2-e2e9-5da9-8aa9-53440183e28b', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: An order stays flagged after the server refused it', $json${"app_range":"^1","blocks":[{"block_version_id":"bcc03b0f-33fa-5a67-b2a9-e0660bc70325"},{"block_version_id":"9c825b72-92ce-50db-9a63-4c173e6e40e6"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"cdfbc19a-8f9d-5e97-96b4-99201f8eb49a"}],"seed":4103}$json$::jsonb, '1e370030-2d5c-5002-b0cb-6b9cc3150cb2', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: State and identity
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('a96af7a6-3458-50ec-865e-11c1523aee57', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'State and identity', 15, 'React')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('993606a2-8f4c-54bc-badc-009ca1160a88', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'a96af7a6-3458-50ec-865e-11c1523aee57', 'Debugging state: who owns it and which component it belongs to', 'notes', 1, $md$## State belongs to a position in the tree

React keeps state by component type and position, or by key. An index key gives the state of a deleted row to the row that moved up, and a form that copies a prop into state once keeps the old values when the prop changes. Use a stable id as the key, and a key on the form to reset it when the entity changes.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-re-state-q1",
      "type": "mcq",
      "prompt": "After deleting a list item the next item shows the deleted item's draft text. Why?",
      "options": [
        {
          "id": "a",
          "text": "The list is not memoized"
        },
        {
          "id": "b",
          "text": "Rows are keyed by index, so row state follows the position"
        },
        {
          "id": "c",
          "text": "The delete request was slow"
        },
        {
          "id": "d",
          "text": "The draft is stored in localStorage"
        }
      ],
      "correct": "b",
      "explanation": "With index keys the surviving row reuses the removed row's component instance and its state."
    }
  ]
}
```
$md$, 15, $json$[{"id":"production-debugging-re-state-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('acab63e0-30fd-5f5a-9d08-d14e2dc39e91', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'a96af7a6-3458-50ec-865e-11c1523aee57', 'Lab: Deleting a note makes the next note show the wrong text', 'lab', 2, 25, '48fca65c-2762-5a4e-bfea-962aa441b86e', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('48fca65c-2762-5a4e-bfea-962aa441b86e', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'acab63e0-30fd-5f5a-9d08-d14e2dc39e91', 'module', 'Lab: Deleting a note makes the next note show the wrong text', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('91244c11-b83e-50e9-aa0f-05002d973253', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Deleting a note makes the next note show the wrong text', $json${"app_range":"^1","blocks":[{"block_version_id":"bcc03b0f-33fa-5a67-b2a9-e0660bc70325"},{"block_version_id":"151dae61-5dac-51f9-86a6-52220614f452"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"cdfbc19a-8f9d-5e97-96b4-99201f8eb49a"}],"seed":4112}$json$::jsonb, '48fca65c-2762-5a4e-bfea-962aa441b86e', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('968ea5f2-548a-58e8-9aff-18f3ba2a89e5', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'a96af7a6-3458-50ec-865e-11c1523aee57', 'Lab: The customer editor shows the previous customer', 'lab', 3, 30, '34e21ade-b702-5e7c-aad4-b01ada76bb77', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('34e21ade-b702-5e7c-aad4-b01ada76bb77', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '968ea5f2-548a-58e8-9aff-18f3ba2a89e5', 'module', 'Lab: The customer editor shows the previous customer', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('906ade13-8722-5b4b-bf76-b6b81236fe46', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: The customer editor shows the previous customer', $json${"app_range":"^1","blocks":[{"block_version_id":"bcc03b0f-33fa-5a67-b2a9-e0660bc70325"},{"block_version_id":"5f026929-8781-5eca-95c8-3cf4cd25b107"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"cdfbc19a-8f9d-5e97-96b4-99201f8eb49a"}],"seed":4111}$json$::jsonb, '34e21ade-b702-5e7c-aad4-b01ada76bb77', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: Performance
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('ceaa8b25-53fe-50e4-89ba-a617938c1d73', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'Performance', 16, 'React')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6ec6cbc1-de48-570e-a00a-8030205d70d8', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'ceaa8b25-53fe-50e4-89ba-a617938c1d73', 'Debugging React performance: measure renders and leaks', 'notes', 1, $md$## Count renders and listeners before changing code

Use the Profiler or a render counter to prove who re-renders and why. A context provider that builds a new value object each render re-renders every consumer, and a listener added without cleanup leaves a copy per visit. Fix the identity or the cleanup, then show the count dropped.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-re-perf-q1",
      "type": "mcq",
      "prompt": "Every consumer of a context re-renders when the provider's parent does. What is the likely cause?",
      "options": [
        {
          "id": "a",
          "text": "Consumers are not wrapped in memo"
        },
        {
          "id": "b",
          "text": "The provider passes a new value object each render"
        },
        {
          "id": "c",
          "text": "The context has too many fields"
        },
        {
          "id": "d",
          "text": "React.StrictMode is on"
        }
      ],
      "correct": "b",
      "explanation": "A new object identity counts as a change for every consumer. useMemo keeps it stable."
    }
  ]
}
```
$md$, 15, $json$[{"id":"production-debugging-re-perf-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('8106dcc1-83f9-58ca-9196-834f9a50c349', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'ceaa8b25-53fe-50e4-89ba-a617938c1d73', 'Lab: Typing in the quick filter makes every page re-render', 'lab', 2, 35, '27b49a0c-72ec-54fe-996c-f44afb96003a', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('27b49a0c-72ec-54fe-996c-f44afb96003a', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '8106dcc1-83f9-58ca-9196-834f9a50c349', 'module', 'Lab: Typing in the quick filter makes every page re-render', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('97c1845a-b355-5f8d-8e49-0f90e6aa77df', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Typing in the quick filter makes every page re-render', $json${"app_range":"^1","blocks":[{"block_version_id":"bcc03b0f-33fa-5a67-b2a9-e0660bc70325"},{"block_version_id":"cdbfaa65-5bae-54ce-9cc6-1e67f2a0fb7d"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"cdfbc19a-8f9d-5e97-96b4-99201f8eb49a"}],"seed":4109}$json$::jsonb, '27b49a0c-72ec-54fe-996c-f44afb96003a', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('31a8c60c-b409-5cf2-a1dc-3f12cfef7e02', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'ceaa8b25-53fe-50e4-89ba-a617938c1d73', 'Lab: Memory and CPU grow every time Orders is opened', 'lab', 3, 35, 'd90b19a1-beef-59e6-81e1-23ca12fc2091', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('d90b19a1-beef-59e6-81e1-23ca12fc2091', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '31a8c60c-b409-5cf2-a1dc-3f12cfef7e02', 'module', 'Lab: Memory and CPU grow every time Orders is opened', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('11a60eee-731a-5130-861b-e98266798313', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Memory and CPU grow every time Orders is opened', $json${"app_range":"^1","blocks":[{"block_version_id":"bcc03b0f-33fa-5a67-b2a9-e0660bc70325"},{"block_version_id":"578643f9-80b1-5027-99ec-32778f703a33"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"cdfbc19a-8f9d-5e97-96b4-99201f8eb49a"}],"seed":4110}$json$::jsonb, 'd90b19a1-beef-59e6-81e1-23ca12fc2091', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: API and configuration
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('2689f97b-9792-51bc-a6df-3d8739e41e3f', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'API and configuration', 17, 'React')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('f0563bd4-61e0-5626-a282-0806735ba631', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '2689f97b-9792-51bc-a6df-3d8739e41e3f', 'Debugging the edges: API results, dates and build-time config', 'notes', 1, $md$## The client decides what failure means

A fetch promise only rejects on network errors, so the API client must turn error statuses into errors. Check the status handling for every range, and read dates without a time zone as local calendar days. Build-time configuration is baked in: a bundler only exposes variables with its public prefix, so a missing prefix silently falls back to a default.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-re-api-q1",
      "type": "mcq",
      "prompt": "A Vite app reads import.meta.env.API_URL and always calls relative URLs in staging. Why?",
      "options": [
        {
          "id": "a",
          "text": "The staging server blocks CORS"
        },
        {
          "id": "b",
          "text": "Vite only exposes variables prefixed VITE_ to client code"
        },
        {
          "id": "c",
          "text": "The URL needs a trailing slash"
        },
        {
          "id": "d",
          "text": "Env files load only in production"
        }
      ],
      "correct": "b",
      "explanation": "Unprefixed variables are not exposed, so the value is undefined and the fallback is used."
    }
  ]
}
```
$md$, 15, $json$[{"id":"production-debugging-re-api-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('3692d718-969b-5bf7-af51-922ea5d5be3d', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '2689f97b-9792-51bc-a6df-3d8739e41e3f', 'Lab: The UI says Saved while the server was down', 'lab', 2, 30, '8b0a788a-3f7b-5cf4-a787-36df241b3f0e', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('8b0a788a-3f7b-5cf4-a787-36df241b3f0e', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '3692d718-969b-5bf7-af51-922ea5d5be3d', 'module', 'Lab: The UI says Saved while the server was down', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('680837d0-7db6-5751-bc28-bb9cd11e46a4', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: The UI says Saved while the server was down', $json${"app_range":"^1","blocks":[{"block_version_id":"bcc03b0f-33fa-5a67-b2a9-e0660bc70325"},{"block_version_id":"4e5bb575-d622-5fb2-8e84-e5ac6a7f0f08"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"cdfbc19a-8f9d-5e97-96b4-99201f8eb49a"}],"seed":4102}$json$::jsonb, '8b0a788a-3f7b-5cf4-a787-36df241b3f0e', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('a3488ba4-f261-5b6e-8820-361e4453d5f3', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '2689f97b-9792-51bc-a6df-3d8739e41e3f', 'Lab: Revenue report shows the previous day for US users', 'lab', 3, 30, '078ba2a5-8955-5710-a101-ca37113ef9e7', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('078ba2a5-8955-5710-a101-ca37113ef9e7', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'a3488ba4-f261-5b6e-8820-361e4453d5f3', 'module', 'Lab: Revenue report shows the previous day for US users', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('10ae3aa8-f72f-5e1d-b922-ac28e3c79405', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Revenue report shows the previous day for US users', $json${"app_range":"^1","blocks":[{"block_version_id":"bcc03b0f-33fa-5a67-b2a9-e0660bc70325"},{"block_version_id":"bb492a31-e22e-5e71-b0ea-1847f9b118ed"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"cdfbc19a-8f9d-5e97-96b4-99201f8eb49a"}],"seed":4101}$json$::jsonb, '078ba2a5-8955-5710-a101-ca37113ef9e7', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('05c56672-9259-532a-b121-4ebfa56bb8e2', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '2689f97b-9792-51bc-a6df-3d8739e41e3f', 'Lab: The staging build still calls its own host', 'lab', 4, 25, 'bb0ad065-2116-53d8-afb4-6baa4db3394f', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('bb0ad065-2116-53d8-afb4-6baa4db3394f', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '05c56672-9259-532a-b121-4ebfa56bb8e2', 'module', 'Lab: The staging build still calls its own host', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('fb8f34d1-e29d-5939-b489-d3e049463b92', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: The staging build still calls its own host', $json${"app_range":"^1","blocks":[{"block_version_id":"bcc03b0f-33fa-5a67-b2a9-e0660bc70325"},{"block_version_id":"d667a06c-719f-5634-987c-09e4edd48666"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"cdfbc19a-8f9d-5e97-96b4-99201f8eb49a"}],"seed":4105}$json$::jsonb, 'bb0ad065-2116-53d8-afb4-6baa4db3394f', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: Sessions, cookies and CORS
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('7f3c3c6a-b9d5-5b47-9378-87f28a8bca94', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'Sessions, cookies and CORS', 18, 'Fullstack')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('96bf42b2-cc53-51f8-b4eb-fb4b622fe9f6', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '7f3c3c6a-b9d5-5b47-9378-87f28a8bca94', 'Where the browser and the API disagree: sessions, cookies and CORS', 'notes', 1, $md$## Sessions, cookies and CORS

A cookie session crosses three boundaries: CORS decides whether the browser lets a page use credentials, cookie attributes (Path, HttpOnly, SameSite) decide where the cookie travels and who can read it, and the CSRF token has to be read by script and echoed in a header. Break any one and sign-in looks fine while every later request fails. Reproduce with the network tab: check Set-Cookie flags, the request's Cookie header and the response's Access-Control-* headers.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fullstack-sessions-cors-q1",
      "type": "mcq",
      "prompt": "A script must echo the CSRF token in a header. Which cookie flag breaks that?",
      "options": [
        {
          "id": "a",
          "text": "HttpOnly on the CSRF cookie"
        },
        {
          "id": "b",
          "text": "Secure on the CSRF cookie"
        },
        {
          "id": "c",
          "text": "SameSite=Lax on the CSRF cookie"
        },
        {
          "id": "d",
          "text": "Path=/ on the CSRF cookie"
        }
      ],
      "correct": "a",
      "explanation": "HttpOnly hides the cookie from document.cookie, so the client cannot read the token to send it."
    }
  ]
}
```
$md$, 15, $json$[{"id":"production-debugging-fullstack-sessions-cors-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('56f76ab1-4a77-5f99-b8a5-cfb5d1dc639d', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '7f3c3c6a-b9d5-5b47-9378-87f28a8bca94', 'Lab: Staging console cannot sign in - the form just says "Failed to fetch', 'lab', 2, 30, '7bc9193c-687f-550c-b883-5e006419c19a', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('7bc9193c-687f-550c-b883-5e006419c19a', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '56f76ab1-4a77-5f99-b8a5-cfb5d1dc639d', 'module', 'Lab: Staging console cannot sign in - the form just says "Failed to fetch', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('93797a4b-207d-55e8-bb00-22398ed0c4d4', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Staging console cannot sign in - the form just says "Failed to fetch', $json${"app_range":"^1","blocks":[{"block_version_id":"4bbf77a8-8483-5a32-8b44-529cbad7bf37"},{"block_version_id":"220c5a09-55b1-59de-ad8e-bb27fd865ffd"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"9aa45629-917c-5db7-994f-5a7ad10df22a"}],"seed":5101}$json$::jsonb, '7bc9193c-687f-550c-b883-5e006419c19a', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('ce4f240e-8057-5c91-9791-8ba3e28cec0a', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '7f3c3c6a-b9d5-5b47-9378-87f28a8bca94', 'Lab: Sign-in succeeds, then Orders and Profile say "Sign in to continue', 'lab', 3, 30, '84ed348e-c808-5817-bebb-53a4b0b8a211', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('84ed348e-c808-5817-bebb-53a4b0b8a211', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'ce4f240e-8057-5c91-9791-8ba3e28cec0a', 'module', 'Lab: Sign-in succeeds, then Orders and Profile say "Sign in to continue', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('cba6c2cc-ca88-5201-9870-c764d53af449', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Sign-in succeeds, then Orders and Profile say "Sign in to continue', $json${"app_range":"^1","blocks":[{"block_version_id":"4bbf77a8-8483-5a32-8b44-529cbad7bf37"},{"block_version_id":"daa16472-f51e-5641-b949-c5deef4f1907"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"9aa45629-917c-5db7-994f-5a7ad10df22a"}],"seed":5103}$json$::jsonb, '84ed348e-c808-5817-bebb-53a4b0b8a211', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('4552504e-4b77-56ba-95cc-84405942e2d6', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '7f3c3c6a-b9d5-5b47-9378-87f28a8bca94', 'Lab: Saving anything fails with "The request could not be verified', 'lab', 4, 30, 'c4169e83-1ef3-56db-b570-9631d78326ac', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('c4169e83-1ef3-56db-b570-9631d78326ac', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '4552504e-4b77-56ba-95cc-84405942e2d6', 'module', 'Lab: Saving anything fails with "The request could not be verified', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('82ec77ec-4ceb-5f95-a73c-d1bdb3287b16', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Saving anything fails with "The request could not be verified', $json${"app_range":"^1","blocks":[{"block_version_id":"4bbf77a8-8483-5a32-8b44-529cbad7bf37"},{"block_version_id":"0fe2ed52-7966-5c00-b578-d866322a942a"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"9aa45629-917c-5db7-994f-5a7ad10df22a"}],"seed":5104}$json$::jsonb, 'c4169e83-1ef3-56db-b570-9631d78326ac', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('9e5e163a-751a-5888-8dab-f228bc7908ef', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '7f3c3c6a-b9d5-5b47-9378-87f28a8bca94', 'Lab: Saving the profile fails with "The request could not be verified', 'lab', 5, 30, 'e413e172-749f-5e64-98ba-fe489348d86f', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('e413e172-749f-5e64-98ba-fe489348d86f', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '9e5e163a-751a-5888-8dab-f228bc7908ef', 'module', 'Lab: Saving the profile fails with "The request could not be verified', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('40920b92-7270-5cf5-b107-984ecf35be23', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Saving the profile fails with "The request could not be verified', $json${"app_range":"^1","blocks":[{"block_version_id":"4bbf77a8-8483-5a32-8b44-529cbad7bf37"},{"block_version_id":"ddd0f123-6323-5252-8c10-680228d13074"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"9aa45629-917c-5db7-994f-5a7ad10df22a"}],"seed":5106}$json$::jsonb, 'e413e172-749f-5e64-98ba-fe489348d86f', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: The API contract
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('01054f35-310a-5551-99a0-cde874af2b87', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'The API contract', 19, 'Fullstack')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('fe491a1e-658d-534e-a99e-47cb64187af1', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '01054f35-310a-5551-99a0-cde874af2b87', 'Contracts across the wire: error bodies, query strings and paging', 'notes', 1, $md$## The API contract

Frontend and backend only agree through the wire format. Error bodies must have the shape the client reads, query strings must be encoded, and page numbers must mean the same thing on both sides (1-based vs 0-based). Test the contract end to end: send the real request and read the real response before blaming either side.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fullstack-api-contract-q1",
      "type": "mcq",
      "prompt": "A search for \"R&D Kit\" returns every product containing R. What is the most likely cause?",
      "options": [
        {
          "id": "a",
          "text": "The query was not URL-encoded so & started a new parameter"
        },
        {
          "id": "b",
          "text": "The API lowercases the query"
        },
        {
          "id": "c",
          "text": "The database collation is wrong"
        },
        {
          "id": "d",
          "text": "The browser caches the response"
        }
      ],
      "correct": "a",
      "explanation": "An unencoded & ends the q parameter, so the server sees q=R."
    }
  ]
}
```
$md$, 15, $json$[{"id":"production-debugging-fullstack-api-contract-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('49a9fe3e-0cb1-54f1-887c-78938172112f', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '01054f35-310a-5551-99a0-cde874af2b87', 'Lab: Error messages are gone - not-found and forbidden failures show "Request failed"', 'lab', 2, 30, 'e25eb9a1-b064-58d0-b8fc-fc91f0aa5d04', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('e25eb9a1-b064-58d0-b8fc-fc91f0aa5d04', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '49a9fe3e-0cb1-54f1-887c-78938172112f', 'module', 'Lab: Error messages are gone - not-found and forbidden failures show "Request failed"', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('0cc50778-7b84-586b-b012-f05ffcfd049b', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Error messages are gone - not-found and forbidden failures show "Request failed"', $json${"app_range":"^1","blocks":[{"block_version_id":"4bbf77a8-8483-5a32-8b44-529cbad7bf37"},{"block_version_id":"9e82d478-dc15-598e-9463-63abf5919151"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"9aa45629-917c-5db7-994f-5a7ad10df22a"}],"seed":5102}$json$::jsonb, 'e25eb9a1-b064-58d0-b8fc-fc91f0aa5d04', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('2645e125-8b67-57ee-93a1-a55d5e5d4ba4', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '01054f35-310a-5551-99a0-cde874af2b87', 'Lab: Searching for "R&D Kit" lists everything containing an R', 'lab', 3, 30, '788ffa65-9fca-50af-86f4-37dc3ed2941f', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('788ffa65-9fca-50af-86f4-37dc3ed2941f', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '2645e125-8b67-57ee-93a1-a55d5e5d4ba4', 'module', 'Lab: Searching for "R&D Kit" lists everything containing an R', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('360a1933-38e6-5e14-a8fa-2440069af248', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Searching for "R&D Kit" lists everything containing an R', $json${"app_range":"^1","blocks":[{"block_version_id":"4bbf77a8-8483-5a32-8b44-529cbad7bf37"},{"block_version_id":"034adb8a-31fd-5662-a658-5c2bb0b4f93d"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"9aa45629-917c-5db7-994f-5a7ad10df22a"}],"seed":5105}$json$::jsonb, '788ffa65-9fca-50af-86f4-37dc3ed2941f', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('17bef067-f75d-5d03-ae43-5ad6b2109c14', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '01054f35-310a-5551-99a0-cde874af2b87', 'Lab: Our newest orders are missing from the order history', 'lab', 4, 30, 'f01d1f65-4518-5dd1-bd85-448627c47285', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('f01d1f65-4518-5dd1-bd85-448627c47285', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '17bef067-f75d-5d03-ae43-5ad6b2109c14', 'module', 'Lab: Our newest orders are missing from the order history', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('32e61c9e-d884-5913-a1a1-1f34ec2a5e11', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Our newest orders are missing from the order history', $json${"app_range":"^1","blocks":[{"block_version_id":"4bbf77a8-8483-5a32-8b44-529cbad7bf37"},{"block_version_id":"956db87f-1c39-547e-8461-717e90101bdc"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"9aa45629-917c-5db7-994f-5a7ad10df22a"}],"seed":5107}$json$::jsonb, 'f01d1f65-4518-5dd1-bd85-448627c47285', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: Data and state
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('ff923b9c-b062-5a66-bf4c-b3781174e8ae', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'Data and state', 20, 'Fullstack')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('843c1dbe-bd45-5049-9d88-1f622d9b2877', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'ff923b9c-b062-5a66-bf4c-b3781174e8ae', 'Values that change meaning on the way: time zones, money and stale writes', 'notes', 1, $md$## Data and state

A value crosses the wire as text and means different things on each side: a timestamp without an offset is read as local time, an amount in dollars is formatted as cents, and a save based on an old version overwrites newer data. Agree on one representation (UTC with an offset, integer cents, an explicit version check) and enforce it at the API boundary.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fullstack-data-state-q1",
      "type": "mcq",
      "prompt": "Why does a timestamp like 2025-03-06T02:30:00 (no offset) show the wrong day in some browsers?",
      "options": [
        {
          "id": "a",
          "text": "JavaScript parses it as local time, not UTC"
        },
        {
          "id": "b",
          "text": "Browsers cannot parse ISO dates"
        },
        {
          "id": "c",
          "text": "The server clock is wrong"
        },
        {
          "id": "d",
          "text": "Daylight saving is off"
        }
      ],
      "correct": "a",
      "explanation": "Without an offset the string is interpreted in the viewer's local time zone."
    }
  ]
}
```
$md$, 15, $json$[{"id":"production-debugging-fullstack-data-state-q1","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('d8b60b31-11ba-5e32-b4b2-4a90e7921e4a', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'ff923b9c-b062-5a66-bf4c-b3781174e8ae', 'Lab: The order I placed this evening is dated tomorrow', 'lab', 2, 30, 'facafe9d-0da6-5f4d-a5ba-dc0bb3112920', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('facafe9d-0da6-5f4d-a5ba-dc0bb3112920', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'd8b60b31-11ba-5e32-b4b2-4a90e7921e4a', 'module', 'Lab: The order I placed this evening is dated tomorrow', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('f98d1eb8-7696-5c32-81f8-99a6c8b6f858', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: The order I placed this evening is dated tomorrow', $json${"app_range":"^1","blocks":[{"block_version_id":"4bbf77a8-8483-5a32-8b44-529cbad7bf37"},{"block_version_id":"be5b426e-5233-559a-90bb-336008158f22"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"9aa45629-917c-5db7-994f-5a7ad10df22a"}],"seed":5108}$json$::jsonb, 'facafe9d-0da6-5f4d-a5ba-dc0bb3112920', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('1308a02d-abce-5c58-be4a-38d7a6105ff0', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'ff923b9c-b062-5a66-bf4c-b3781174e8ae', 'Lab: Every order in the history shows a total of under a dollar', 'lab', 3, 30, '293ff23d-fc4e-59d3-a7f7-e0d09388db59', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('293ff23d-fc4e-59d3-a7f7-e0d09388db59', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '1308a02d-abce-5c58-be4a-38d7a6105ff0', 'module', 'Lab: Every order in the history shows a total of under a dollar', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('e1532e27-0d4f-5ddb-a2ff-debd7f491381', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Every order in the history shows a total of under a dollar', $json${"app_range":"^1","blocks":[{"block_version_id":"4bbf77a8-8483-5a32-8b44-529cbad7bf37"},{"block_version_id":"ac8dd9f1-1547-5334-afbd-f9f1a3052f5a"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"9aa45629-917c-5db7-994f-5a7ad10df22a"}],"seed":5109}$json$::jsonb, '293ff23d-fc4e-59d3-a7f7-e0d09388db59', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('0d53544c-dcb8-5c9a-9a9e-b60e097aa157', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'ff923b9c-b062-5a66-bf4c-b3781174e8ae', 'Lab: Saving my profile on my laptop erased the phone number I just changed on my phone', 'lab', 4, 30, '6aae679d-2e98-57d7-bc8f-3ec0f094ee8a', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('6aae679d-2e98-57d7-bc8f-3ec0f094ee8a', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '0d53544c-dcb8-5c9a-9a9e-b60e097aa157', 'module', 'Lab: Saving my profile on my laptop erased the phone number I just changed on my phone', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('9090bd42-6f56-520b-bcce-17dd1325ff51', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: Saving my profile on my laptop erased the phone number I just changed on my phone', $json${"app_range":"^1","blocks":[{"block_version_id":"4bbf77a8-8483-5a32-8b44-529cbad7bf37"},{"block_version_id":"6f0a36a4-6ebc-51e9-b29b-0aa63cda4c79"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"888d8445-6ac3-5eb7-94d7-90dab52f3ebb"},{"block_version_id":"9aa45629-917c-5db7-994f-5a7ad10df22a"}],"seed":5110}$json$::jsonb, '6aae679d-2e98-57d7-bc8f-3ec0f094ee8a', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

-- Section: Latency and slow APIs
INSERT INTO course_sections (id, course_id, title, position, group_title)
VALUES ('361f09e1-308c-5853-a954-96dca1a98e3a', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'Latency and slow APIs', 21, 'FastAPI')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('2c35c57b-0789-568c-8ca0-8b2bb6804b48', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '361f09e1-308c-5853-a954-96dca1a98e3a', 'Debugging a slow API: blocked loops, sequential awaits and throwaway clients', 'notes', 1, $md$A slow API has three usual suspects that no profiler of your own code shows at first: something stops the event loop, independent waits run one after another, or every call pays for setup it should have paid once. The skill this section trains is turning "it feels slow" into a number that points at one of them.

## A blocking call stops everyone

An `async def` handler shares one thread with every other request of the process. A synchronous call that waits (`time.sleep`, `requests`, a legacy client, heavy CPU work) holds that thread, so unrelated requests, even `/healthz`, wait behind it. The test is to time a cheap endpoint while the suspect endpoint runs. The cure is to move the call off the loop (`run_in_threadpool`, `asyncio.to_thread`) or to use an async client. Adding `await` in front of a synchronous function, a lock around it, or `asyncio.wait_for` does not make it yield.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-latency-blocking-q1",
      "type": "mcq",
      "prompt": "Search calls a synchronous lookup that waits 300 ms inside an async def handler. While 5 searches run, what happens to GET /healthz?",
      "options": [
        { "id": "a", "text": "It answers normally, async handlers run in parallel" },
        { "id": "b", "text": "It waits behind the searches, because the blocked event loop cannot run anything else" },
        { "id": "c", "text": "It fails with a 500 because the pool is full" },
        { "id": "d", "text": "Only requests from the same client are delayed" }
      ],
      "correct": "b",
      "explanation": "The synchronous call keeps the single event loop thread busy. Every other coroutine, including the health check, only runs when the loop is free again."
    }
  ]
}
```

## Independent waits should overlap

When a handler needs two things that do not depend on each other (two remote services, two queries on separate sessions), `await a(); await b()` costs the sum of both. `asyncio.gather(a(), b())` starts both and costs the longest. Measure each dependency alone, then the endpoint: a total close to the sum is the signature. Calls that need each other's result, or that share one `AsyncSession`, must stay sequential.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-latency-gather-q1",
      "type": "mcq",
      "prompt": "A page awaits two independent 300 ms lookups one after another. Roughly how long does it take, and what is the fix?",
      "options": [
        { "id": "a", "text": "About 300 ms, nothing to fix" },
        { "id": "b", "text": "About 600 ms; start both with asyncio.gather" },
        { "id": "c", "text": "About 600 ms; wrap each lookup in asyncio.wait_for" },
        { "id": "d", "text": "About 300 ms; add a lock so they do not interfere" }
      ],
      "correct": "b",
      "explanation": "Sequential awaits add their latencies. gather runs the two waits at the same time, so the total becomes the longer one. wait_for only adds a timeout and a lock would force them to run one at a time."
    }
  ]
}
```

## Build the client once

An `httpx.AsyncClient` owns a connection pool with keep-alive. Creating one per call and closing it at the end of the block throws the pool away, so every call pays for a new TCP (and in production TLS) handshake and leaves a socket in TIME_WAIT. On localhost this is invisible, which is why it survives review. Create the client once at startup, share it, and close it at shutdown. Counting how often the client is constructed is a better test than timing.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-latency-client-q1",
      "type": "mcq",
      "prompt": "Why does building an httpx.AsyncClient inside every request handler hurt, even though each call succeeds?",
      "options": [
        { "id": "a", "text": "The client is not thread safe" },
        { "id": "b", "text": "Each client discards its connection pool, so every call opens a new connection and handshake" },
        { "id": "c", "text": "httpx forbids more than one client per process" },
        { "id": "d", "text": "It makes the response body larger" }
      ],
      "correct": "b",
      "explanation": "The pool and its keep-alive connections belong to the client. A client that lives for one call can never reuse a connection, so the setup cost is paid every time."
    }
  ]
}
```
$md$, 20, $json$[{"id":"production-debugging-fa-latency-blocking-q1","type":"mcq","correct":"b"},{"id":"production-debugging-fa-latency-gather-q1","type":"mcq","correct":"b"},{"id":"production-debugging-fa-latency-client-q1","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('b8a029a0-54f9-5991-86f1-93c50b0d8c8a', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '361f09e1-308c-5853-a954-96dca1a98e3a', 'Lab: The API stalls while shoppers search', 'lab', 2, 40, '790aaa28-274b-54c3-90f3-9aca9f9d4f8b', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('790aaa28-274b-54c3-90f3-9aca9f9d4f8b', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'b8a029a0-54f9-5991-86f1-93c50b0d8c8a', 'module', 'Lab: The API stalls while shoppers search', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('dfc92ad6-f464-5eec-9128-7363900a2a22', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: The API stalls while shoppers search', $json${"app_range":"^1","blocks":[{"block_version_id":"7f4707a2-1c83-5c77-9c17-3daf6d0ddf6e"},{"block_version_id":"298fed14-819b-5f66-9a55-d27c63e050a4"},{"block_version_id":"592cc315-ea72-5910-b845-b2bbe06c8ed1"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"58f7c05b-d75f-5118-b108-b11d2bc735d2"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":3101}$json$::jsonb, '790aaa28-274b-54c3-90f3-9aca9f9d4f8b', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('898d4ce2-b69b-5132-84d7-8f33d0bbe190', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '361f09e1-308c-5853-a954-96dca1a98e3a', 'Lab: The storefront takes the sum of its dependencies', 'lab', 3, 30, '559c99e0-5ef4-54f4-8a8f-d309b1b555db', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('559c99e0-5ef4-54f4-8a8f-d309b1b555db', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '898d4ce2-b69b-5132-84d7-8f33d0bbe190', 'module', 'Lab: The storefront takes the sum of its dependencies', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('bd8cb683-8856-5cb7-aa53-77c4fbb0438a', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: The storefront takes the sum of its dependencies', $json${"app_range":"^1","blocks":[{"block_version_id":"7f4707a2-1c83-5c77-9c17-3daf6d0ddf6e"},{"block_version_id":"6d6d7586-dcb4-5837-bebc-035c7abe6769"},{"block_version_id":"592cc315-ea72-5910-b845-b2bbe06c8ed1"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"58f7c05b-d75f-5118-b108-b11d2bc735d2"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":3102}$json$::jsonb, '559c99e0-5ef4-54f4-8a8f-d309b1b555db', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)
VALUES ('b5d83fbd-b24d-5df2-ad8b-c79163b18347', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '361f09e1-308c-5853-a954-96dca1a98e3a', 'Lab: A new connection for every charge', 'lab', 4, 40, 'daec8d8f-6e9d-514c-af3a-478aa6d30dbd', false)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();

INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)
VALUES ('daec8d8f-6e9d-514c-af3a-478aa6d30dbd', '00000000-0000-0000-0000-000000000001', '8af0a927-61bf-5a04-a2e9-e74f552564bf', 'b5d83fbd-b24d-5df2-ad8b-c79163b18347', 'module', 'Lab: A new connection for every charge', NULL, 'debug', 'mindforge/lab-debug:1', 0, $script$cd /home/labuser/work && exec bash .mf/setup.sh$script$, 90, 3, 10, false, false, NULL, 'split', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();

INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
VALUES ('ab078c80-40b6-53b4-ab41-bae6587f7f28', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'debug', 'Lab: A new connection for every charge', $json${"app_range":"^1","blocks":[{"block_version_id":"7f4707a2-1c83-5c77-9c17-3daf6d0ddf6e"},{"block_version_id":"97f45860-af16-55cf-ae49-852303bacf79"},{"block_version_id":"592cc315-ea72-5910-b845-b2bbe06c8ed1"},{"block_version_id":"1f38f850-53f5-54c5-b661-fcbb2f200510"},{"block_version_id":"b3f57e3d-def5-588d-987c-2f3f59fda7b5"},{"block_version_id":"5b34e087-f9c6-5c92-aa98-23578da4a3ee"}],"seed":3103}$json$::jsonb, 'daec8d8f-6e9d-514c-af3a-478aa6d30dbd', true)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,
  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,
  spec=EXCLUDED.spec, updated_at=now();

INSERT INTO enrollments (id, user_id, course_id, enrolled_by)
VALUES ('fd0481e0-44c4-5c39-b8c8-aaf8ca8488bc', '00000000-0000-0000-0000-000000000014', '8af0a927-61bf-5a04-a2e9-e74f552564bf', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (user_id, course_id) DO NOTHING;

DELETE FROM course_modules WHERE course_id = '8af0a927-61bf-5a04-a2e9-e74f552564bf' AND id NOT IN ('660b721f-3bea-54bc-b2f9-7e9107365ccf', '89a9c00f-9137-58f9-af1a-1a2e7364e812', '46604227-42de-5739-ade3-783db7693447', '0721aba0-a80b-55a8-80e4-56ee4429c1e2', 'f0afbafc-7b67-5c97-a2bb-e19b9c19bca7', '16254531-52f4-5fe0-b1bd-743626184b8d', '10220d66-172f-58ae-b876-f829c0a7260f', '1ff1d0ec-7999-50ed-981b-a5ddb014f554', '96a415c6-071c-523e-8fc0-fc624f9db203', 'd5571474-dee0-523d-8e8d-ec18d39875ea', '9df2ff32-3dab-50ab-b05f-636076e3a25e', 'ebbf18aa-4dc6-5a82-a825-66bdb47bc875', '16e7356a-6487-5f42-9ddf-b6bcee59c28e', '178a3b24-fc15-534e-a93a-909609f07a1d', 'c1289e9b-a81a-5c22-8ac8-85a15b3849ad', 'd361fad8-5183-5df6-9507-6e9cf5eaecc2', '8fa0d22a-ebbd-559a-b52c-c7286b4f4927', '6d493c90-6a47-579d-8ee4-041b20e04e87', 'ecfe452d-d7ac-5781-a44e-34fd8a62c665', '23b9f1d1-15f2-53f7-9f8b-049ac030323c', 'd46741c3-3276-5ccb-a9a4-ce47acc6ab1f', 'a6ca0747-5929-5d25-9aef-4a125bb1bed4', '735a6afc-cb17-5887-884c-d999886d79ed', 'dc648be3-e909-5f93-984c-ca1a144edf7e', 'aebc53b8-eba9-5cfa-b938-2864e04ab883', '31028379-3faa-5d91-93f5-97ae7fa8af99', '4053b2d0-9f6a-55ef-bf2e-14ab6e45ef5d', '8e19bd8c-f21d-555a-b0d3-88598b3185dc', '3b20905c-f13e-52f9-bf4f-b5db45df634d', '96911d8c-e8ed-548f-b3bc-f10f9f4b0ab8', '5ac0efb6-16e1-5d01-a142-a381c0a7e10d', '913e0966-7661-5e6d-80b2-d6cfd7e556c5', '8eb9f7c2-90d2-5ba9-998f-46a268def26b', '800220a8-7363-5f99-8424-bf66ef070c48', '1d6973ab-711f-5053-96f7-a31386b782f7', 'bab1cceb-f2ea-5518-b789-de8c33541f2d', '87886ae8-7324-53d6-a83d-8e0c5cbbf329', '0339708c-c52d-5c88-9f1a-3c998f99afa5', '5b282640-e3f3-5709-8fe5-1bddc42f7c14', '5eba040b-3ebf-5599-abf0-8b7ab1cd2bed', '996c0dc8-fbc6-5b48-9857-94180ed1e198', '993606a2-8f4c-54bc-badc-009ca1160a88', 'acab63e0-30fd-5f5a-9d08-d14e2dc39e91', '968ea5f2-548a-58e8-9aff-18f3ba2a89e5', '6ec6cbc1-de48-570e-a00a-8030205d70d8', '8106dcc1-83f9-58ca-9196-834f9a50c349', '31a8c60c-b409-5cf2-a1dc-3f12cfef7e02', 'f0563bd4-61e0-5626-a282-0806735ba631', '3692d718-969b-5bf7-af51-922ea5d5be3d', 'a3488ba4-f261-5b6e-8820-361e4453d5f3', '05c56672-9259-532a-b121-4ebfa56bb8e2', '96bf42b2-cc53-51f8-b4eb-fb4b622fe9f6', '56f76ab1-4a77-5f99-b8a5-cfb5d1dc639d', 'ce4f240e-8057-5c91-9791-8ba3e28cec0a', '4552504e-4b77-56ba-95cc-84405942e2d6', '9e5e163a-751a-5888-8dab-f228bc7908ef', 'fe491a1e-658d-534e-a99e-47cb64187af1', '49a9fe3e-0cb1-54f1-887c-78938172112f', '2645e125-8b67-57ee-93a1-a55d5e5d4ba4', '17bef067-f75d-5d03-ae43-5ad6b2109c14', '843c1dbe-bd45-5049-9d88-1f622d9b2877', 'd8b60b31-11ba-5e32-b4b2-4a90e7921e4a', '1308a02d-abce-5c58-be4a-38d7a6105ff0', '0d53544c-dcb8-5c9a-9a9e-b60e097aa157', '2c35c57b-0789-568c-8ca0-8b2bb6804b48', 'b8a029a0-54f9-5991-86f1-93c50b0d8c8a', '898d4ce2-b69b-5132-84d7-8f33d0bbe190', 'b5d83fbd-b24d-5df2-ad8b-c79163b18347');
DELETE FROM course_sections WHERE course_id = '8af0a927-61bf-5a04-a2e9-e74f552564bf' AND id NOT IN ('db19aa3e-9ffb-5efc-a991-9344be87258c', '28d5d409-2fd5-586f-9971-8a6380813e83', '13dfba35-e5d7-565e-9324-7dda478ef6d8', '36b18bec-3fc7-5ea2-b7d0-b3b1015f663e', '24ca35ad-5e2a-58ac-8dbe-a56c49ac3d26', '14f3c3f5-c499-5877-a007-80c1d544ce15', '2331f636-e8f9-5020-9bb0-4dc991097e89', 'f6ccdc79-34fc-5ec3-a606-ef0c4b200d90', 'f22bb6dc-9cc9-56a5-881c-54d11c5fd8bf', '7ba71527-a3f1-5f33-8baa-08c884adf01e', 'd443dfcc-5cdc-5ad5-a262-ebc3bb1e5af4', 'a085bf16-522a-52c6-8c87-7fe214b3c60e', '04e3dbe5-5840-5ac9-a2e2-23f30ce162df', '06f976a5-6d4e-5961-bd6c-40e192be837f', 'a96af7a6-3458-50ec-865e-11c1523aee57', 'ceaa8b25-53fe-50e4-89ba-a617938c1d73', '2689f97b-9792-51bc-a6df-3d8739e41e3f', '7f3c3c6a-b9d5-5b47-9378-87f28a8bca94', '01054f35-310a-5551-99a0-cde874af2b87', 'ff923b9c-b062-5a66-bf4c-b3781174e8ae', '361f09e1-308c-5853-a954-96dca1a98e3a');

