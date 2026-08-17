-- Seed 3 daily habits for jaiswal2062@gmail.com: Sleep (with night-wake
-- tracking), Read Book, Learn English. Safe to run multiple times — each
-- INSERT is guarded by NOT EXISTS on (user_id, name) so a rerun is a no-op.
--
-- Mirrors the exact INSERT shape used by Repo.Create (internal/habit/repo.go)
-- — same color-rotation/sort_order derivation from the user's existing habit
-- count, so these seeded rows are indistinguishable from ones added via the
-- "Add Habit" UI.

WITH target_user AS (
  SELECT id FROM users WHERE email = 'jaiswal2062@gmail.com'
),
existing AS (
  SELECT COUNT(*) AS n, COALESCE(MAX(sort_order) + 1, 0) AS next_order
  FROM habits, target_user
  WHERE habits.user_id = target_user.id
)
INSERT INTO habits (user_id, name, cadence, sort_order, color, target_count, weekdays, type, custom_fields, icon, tags)
SELECT target_user.id, 'Sleep', 'daily', existing.next_order,
       (ARRAY['blue','orange','aqua','yellow','magenta','green','violet','red'])[(existing.n % 8) + 1],
       1, '{}', 'sleep', '[]'::jsonb, '', '{}'
FROM existing, target_user
WHERE NOT EXISTS (
  SELECT 1 FROM habits WHERE habits.user_id = target_user.id AND habits.name = 'Sleep'
);

WITH target_user AS (
  SELECT id FROM users WHERE email = 'jaiswal2062@gmail.com'
),
existing AS (
  SELECT COUNT(*) AS n, COALESCE(MAX(sort_order) + 1, 0) AS next_order
  FROM habits, target_user
  WHERE habits.user_id = target_user.id
)
INSERT INTO habits (user_id, name, cadence, sort_order, color, target_count, weekdays, type, custom_fields, icon, tags)
SELECT target_user.id, 'Read Book', 'daily', existing.next_order,
       (ARRAY['blue','orange','aqua','yellow','magenta','green','violet','red'])[(existing.n % 8) + 1],
       1, '{}', 'reading', '[]'::jsonb, '', '{}'
FROM existing, target_user
WHERE NOT EXISTS (
  SELECT 1 FROM habits WHERE habits.user_id = target_user.id AND habits.name = 'Read Book'
);

-- Learn English has no built-in type, so it's "custom" with two fields:
-- minutes practiced (number) and topic/activity (text) — both analyzable the
-- same way the built-in types' numeric/text fields are.
WITH target_user AS (
  SELECT id FROM users WHERE email = 'jaiswal2062@gmail.com'
),
existing AS (
  SELECT COUNT(*) AS n, COALESCE(MAX(sort_order) + 1, 0) AS next_order
  FROM habits, target_user
  WHERE habits.user_id = target_user.id
)
INSERT INTO habits (user_id, name, cadence, sort_order, color, target_count, weekdays, type, custom_fields, icon, tags)
SELECT target_user.id, 'Learn English', 'daily', existing.next_order,
       (ARRAY['blue','orange','aqua','yellow','magenta','green','violet','red'])[(existing.n % 8) + 1],
       1, '{}', 'custom',
       '[{"key":"minutes","label":"Minutes Practiced","kind":"number"},{"key":"topic","label":"Topic / Activity","kind":"text"}]'::jsonb,
       '', '{}'
FROM existing, target_user
WHERE NOT EXISTS (
  SELECT 1 FROM habits WHERE habits.user_id = target_user.id AND habits.name = 'Learn English'
);
