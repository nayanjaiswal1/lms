-- ══════════════════════════════════════════════════════════════════════════
-- Dev fixtures — seed data for local development only
-- All passwords are: Admin123!
-- Hashes generated inline by pgcrypto crypt() with bcrypt cost 12.
-- Safe to run multiple times (ON CONFLICT DO NOTHING throughout).
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Users ────────────────────────────────────────────────────────────────────
-- Password for all dev users: Admin123!
-- Hash is computed by Postgres at seed time using pgcrypto — no pre-computed hash needed.

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES (
  '00000000-0000-0000-0000-000000000010',
  'admin@mindforge.dev',
  'Platform Admin',
  crypt('Admin123!', gen_salt('bf', 12)),
  'super_admin',
  true
)
ON CONFLICT (email) DO NOTHING;

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES (
  '00000000-0000-0000-0000-000000000011',
  'orgadmin@mindforge.dev',
  'Org Admin',
  crypt('Admin123!', gen_salt('bf', 12)),
  'user',
  true
)
ON CONFLICT (email) DO NOTHING;

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES (
  '00000000-0000-0000-0000-000000000012',
  'instructor@mindforge.dev',
  'Nayan Jaiswal',
  crypt('Admin123!', gen_salt('bf', 12)),
  'user',
  true
)
ON CONFLICT (email) DO NOTHING;

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES (
  '00000000-0000-0000-0000-000000000013',
  'mentor@mindforge.dev',
  'Dev Mentor',
  crypt('Admin123!', gen_salt('bf', 12)),
  'user',
  true
)
ON CONFLICT (email) DO NOTHING;

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES (
  '00000000-0000-0000-0000-000000000014',
  'student@mindforge.dev',
  'Dev Student',
  crypt('Admin123!', gen_salt('bf', 12)),
  'user',
  true
)
ON CONFLICT (email) DO NOTHING;

-- ─── Org membership ───────────────────────────────────────────────────────────
-- All five users are members of the default org with their respective roles.
-- The super_admin (platform-level) also gets org 'admin' role for full access in UI.

INSERT INTO org_members (id, org_id, user_id, role)
VALUES (
  '00000000-0000-0000-0000-000000000020',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000010',
  'admin'
)
ON CONFLICT (org_id, user_id) DO NOTHING;

INSERT INTO org_members (id, org_id, user_id, role)
VALUES (
  '00000000-0000-0000-0000-000000000021',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000011',
  'admin'
)
ON CONFLICT (org_id, user_id) DO NOTHING;

INSERT INTO org_members (id, org_id, user_id, role)
VALUES (
  '00000000-0000-0000-0000-000000000022',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000012',
  'instructor'
)
ON CONFLICT (org_id, user_id) DO NOTHING;

INSERT INTO org_members (id, org_id, user_id, role)
VALUES (
  '00000000-0000-0000-0000-000000000023',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000013',
  'mentor'
)
ON CONFLICT (org_id, user_id) DO NOTHING;

INSERT INTO org_members (id, org_id, user_id, role)
VALUES (
  '00000000-0000-0000-0000-000000000024',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000014',
  'learner'
)
ON CONFLICT (org_id, user_id) DO NOTHING;

-- ─── Lab org config ─────────────────────────────────────────────────────────
-- Without this row the dev org's allowed_images is empty, and labs.Service.
-- StartSession refuses every lab whose image is mapped to the "nested-docker"
-- profile in LABS_IMAGE_PROFILES ("This lab is not available for your
-- organization") — such an image is never a platform default and always needs
-- an explicit allowlist entry.
--
-- allowed_images is all-or-nothing: once non-empty it also restricts ordinary
-- images, so this list must name EVERY image the dev course fixtures use, not
-- just the nested-Docker ones. Adding a lab on a new image means adding it
-- here too.
-- Disabled: lab_org_config has no migration anywhere in db/migrations/ (grepped
-- clean) and doesn't exist in the actual database — this INSERT has been
-- silently failing every dev seed since whenever it was added, rolling back
-- the ENTIRE dev_seed.sql (SeedDev runs each file as one pool.Exec, which
-- Postgres wraps in one implicit transaction) because a table-doesn't-exist
-- error aborts the whole multi-statement blob. Re-enable once a real
-- migration creates the table — see docs/labs.md / REMAINING_PHASES.md #29
-- for the intended shape (also has max_session_duration).
-- INSERT INTO lab_org_config (org_id, allowed_images)
-- VALUES (
--   '00000000-0000-0000-0000-000000000001',
--   ARRAY[
--     'mindforge/lab-docker:27',
--     'mindforge/lab-docker-sysbox:27',
--     'mindforge/lab-k8s:1.31',
--     'mindforge/lab-node-web:22',
--     'mindforge/lab-python-web:3.12',
--     'node:18-alpine'
--   ]
-- )
-- ON CONFLICT (org_id) DO UPDATE SET allowed_images = EXCLUDED.allowed_images;

-- ══════════════════════════════════════════════════════════════════════════
-- Assessment fixture — "React Fundamentals" test (MCQ + coding)
-- Authored by the dev instructor, assigned to a batch that contains the dev
-- student, so logging in as student@mindforge.dev surfaces it under /assessments.
-- Dollar-quoted JSON ($json$…$json$) avoids escaping in the gradable content.
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Category ───────────────────────────────────────────────────────────────
INSERT INTO question_categories (id, org_id, name, slug)
VALUES (
  '00000000-0000-0000-0000-000000000101',
  '00000000-0000-0000-0000-000000000001',
  'React',
  'react'
)
ON CONFLICT (id) DO NOTHING;

-- ─── Question 1 — MCQ (single answer) ───────────────────────────────────────
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES (
  '00000000-0000-0000-0000-000000000110',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101',
  'mcq', 'React state hook', 'beginner', 1, ARRAY['react','hooks'], 1,
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES (
  '00000000-0000-0000-0000-000000000111',
  '00000000-0000-0000-0000-000000000110', 1,
  $json${
    "prompt": "Which hook manages local state in a function component?",
    "multiple": false,
    "options": [
      {"id": "a", "text": "useState", "is_correct": true},
      {"id": "b", "text": "useEffect", "is_correct": false},
      {"id": "c", "text": "useContext", "is_correct": false},
      {"id": "d", "text": "useRef", "is_correct": false}
    ],
    "explanation": "useState returns a stateful value and a setter function."
  }$json$::jsonb,
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (id) DO NOTHING;

-- ─── Question 2 — MCQ (multiple answers) ────────────────────────────────────
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES (
  '00000000-0000-0000-0000-000000000112',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101',
  'mcq', 'Identify React hooks', 'intermediate', 1, ARRAY['react','hooks'], 1,
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES (
  '00000000-0000-0000-0000-000000000113',
  '00000000-0000-0000-0000-000000000112', 1,
  $json${
    "prompt": "Select all valid built-in React hooks.",
    "multiple": true,
    "options": [
      {"id": "a", "text": "useMemo", "is_correct": true},
      {"id": "b", "text": "useCallback", "is_correct": true},
      {"id": "c", "text": "useFetch", "is_correct": false},
      {"id": "d", "text": "componentDidMount", "is_correct": false}
    ],
    "explanation": "useMemo and useCallback are built-in; useFetch is not, and componentDidMount is a class lifecycle method."
  }$json$::jsonb,
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (id) DO NOTHING;

-- ─── Question 3 — Coding ────────────────────────────────────────────────────
INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES (
  '00000000-0000-0000-0000-000000000114',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101',
  'coding', 'Sum of two integers', 'beginner', 2, ARRAY['io','math'], 1,
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES (
  '00000000-0000-0000-0000-000000000115',
  '00000000-0000-0000-0000-000000000114', 1,
  $json${
    "prompt": "Read two space-separated integers from stdin and print their sum.",
    "languages": ["python", "javascript"],
    "starter_code": {
      "python": "a, b = map(int, input().split())\nprint(a + b)\n",
      "javascript": "const [a, b] = require('fs').readFileSync(0, 'utf8').trim().split(' ').map(Number);\nconsole.log(a + b);\n"
    },
    "time_limit_ms": 2000,
    "memory_limit_kb": 262144,
    "test_cases": [
      {"id": "t1", "stdin": "2 3", "expected": "5", "hidden": false, "weight": 1},
      {"id": "t2", "stdin": "10 20", "expected": "30", "hidden": true, "weight": 1},
      {"id": "t3", "stdin": "100 250", "expected": "350", "hidden": true, "weight": 1}
    ]
  }$json$::jsonb,
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (id) DO NOTHING;

-- ─── Assessment ─────────────────────────────────────────────────────────────
INSERT INTO assessments (
  id, org_id, title, slug, description, type, status, parent_type,
  duration_minutes, pass_percentage, max_attempts, total_points,
  shuffle_questions, shuffle_options, allow_backtrack, show_results,
  proctoring, created_by, published_at
)
VALUES (
  '00000000-0000-0000-0000-000000000120',
  '00000000-0000-0000-0000-000000000001',
  'React Fundamentals', 'react-fundamentals',
  'A short proctored test covering React hooks and basic problem solving.',
  'mixed', 'published', 'standalone',
  30, 50, 3, 4,
  false, true, true, true,
  $json${
    "require_fullscreen": true,
    "block_copy_paste": true,
    "block_right_click": true,
    "block_devtools": true,
    "max_tab_switches": 3,
    "max_focus_loss": 5,
    "auto_submit_on_violation": true,
    "heartbeat_seconds": 15
  }$json$::jsonb,
  '00000000-0000-0000-0000-000000000012',
  now()
)
ON CONFLICT (id) DO NOTHING;

-- ─── Attach questions (pin their version) ───────────────────────────────────
INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
  ('00000000-0000-0000-0000-000000000121', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000110', '00000000-0000-0000-0000-000000000111', 0, 1),
  ('00000000-0000-0000-0000-000000000122', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000112', '00000000-0000-0000-0000-000000000113', 1, 1),
  ('00000000-0000-0000-0000-000000000123', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000114', '00000000-0000-0000-0000-000000000115', 2, 2)
ON CONFLICT (id) DO NOTHING;

-- ─── Batch + membership (dev student) ───────────────────────────────────────
INSERT INTO batches (id, org_id, name, slug, description, mentor_id, created_by)
VALUES (
  '00000000-0000-0000-0000-000000000130',
  '00000000-0000-0000-0000-000000000001',
  'Frontend Cohort 2026', 'frontend-cohort-2026',
  'Dev fixture batch for the React Fundamentals assessment.',
  '00000000-0000-0000-0000-000000000013',
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO batch_members (batch_id, user_id)
VALUES (
  '00000000-0000-0000-0000-000000000130',
  '00000000-0000-0000-0000-000000000014'
)
ON CONFLICT (batch_id, user_id) DO NOTHING;

-- ─── Assignment (batch → assessment) ────────────────────────────────────────
INSERT INTO assessment_assignments (id, assessment_id, assignee_type, assignee_id, assigned_by)
VALUES (
  '00000000-0000-0000-0000-000000000140',
  '00000000-0000-0000-0000-000000000120',
  'batch',
  '00000000-0000-0000-0000-000000000130',
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (id) DO NOTHING;

-- ══════════════════════════════════════════════════════════════════════════
-- Extended React assessment — 20-question mix (MCQ + code snippets +
-- subjective + coding), max_attempts = 100 (unlimited), assigned to
-- jaiswal2062@gmail.com via the Frontend Cohort 2026 batch.
-- ══════════════════════════════════════════════════════════════════════════

-- ─── User: jaiswal2062@gmail.com ──────────────────────────────────────────────
INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES (
  '00000000-0000-0000-0000-000000000015',
  'jaiswal2062@gmail.com',
  'Jaiswal Dev',
  crypt('K4djM2GjA95s$2', gen_salt('bf', 12)),
  'user',
  true
)
ON CONFLICT (email) DO UPDATE SET password_hash = crypt('K4djM2GjA95s$2', gen_salt('bf', 12)), updated_at = now();

INSERT INTO org_members (id, org_id, user_id, role)
SELECT gen_random_uuid(), '00000000-0000-0000-0000-000000000001', id, 'learner'
FROM users WHERE email = 'jaiswal2062@gmail.com'
ON CONFLICT (org_id, user_id) DO NOTHING;

INSERT INTO batch_members (batch_id, user_id)
SELECT '00000000-0000-0000-0000-000000000130', id
FROM users WHERE email = 'jaiswal2062@gmail.com'
ON CONFLICT (batch_id, user_id) DO NOTHING;

-- ─── Questions 4–8: additional MCQ ───────────────────────────────────────────

INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000000150', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101', 'mcq', 'JSX compilation', 'beginner', 1,
  ARRAY['react','jsx'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000000151', '00000000-0000-0000-0000-000000000150', 1,
  $json${
    "prompt": "Which of the following correctly describes what JSX `<MyComponent color=\"red\" />` compiles to?",
    "multiple": false,
    "options": [
      {"id": "a", "text": "React.createElement(MyComponent, { color: 'red' })", "is_correct": true},
      {"id": "b", "text": "MyComponent.render({ color: 'red' })", "is_correct": false},
      {"id": "c", "text": "new MyComponent({ color: 'red' })", "is_correct": false},
      {"id": "d", "text": "ReactDOM.render(MyComponent, { color: 'red' })", "is_correct": false}
    ],
    "explanation": "JSX is syntactic sugar for React.createElement(type, props, ...children)."
  }$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000000152', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101', 'mcq', 'useEffect dependency array', 'beginner', 1,
  ARRAY['react','hooks','useEffect'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000000153', '00000000-0000-0000-0000-000000000152', 1,
  $json${
    "prompt": "What happens when you pass an empty array `[]` as the second argument to `useEffect`?",
    "multiple": false,
    "options": [
      {"id": "a", "text": "The effect runs after every render", "is_correct": false},
      {"id": "b", "text": "The effect runs only once after the initial mount", "is_correct": true},
      {"id": "c", "text": "The effect never runs", "is_correct": false},
      {"id": "d", "text": "The effect runs before the initial render", "is_correct": false}
    ],
    "explanation": "An empty dependency array tells React the effect has no dependencies, so it only runs once after mount."
  }$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000000154', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101', 'mcq', 'Purpose of React list keys', 'beginner', 1,
  ARRAY['react','lists','keys'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000000155', '00000000-0000-0000-0000-000000000154', 1,
  $json${
    "prompt": "Why should each item in a React list have a unique `key` prop?",
    "multiple": false,
    "options": [
      {"id": "a", "text": "To style individual list items with CSS", "is_correct": false},
      {"id": "b", "text": "To allow React to identify which items changed, were added, or removed during reconciliation", "is_correct": true},
      {"id": "c", "text": "To enable event delegation on list items", "is_correct": false},
      {"id": "d", "text": "Keys are only required when using TypeScript", "is_correct": false}
    ],
    "explanation": "Keys help React identify elements across re-renders. Without them, React must re-render entire lists inefficiently."
  }$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000000156', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101', 'mcq', 'Controlled vs uncontrolled components', 'intermediate', 1,
  ARRAY['react','forms'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000000157', '00000000-0000-0000-0000-000000000156', 1,
  $json${
    "prompt": "What distinguishes a controlled component from an uncontrolled component in React?",
    "multiple": false,
    "options": [
      {"id": "a", "text": "Controlled components use class syntax; uncontrolled components use function syntax", "is_correct": false},
      {"id": "b", "text": "Controlled components store form data in React state; uncontrolled components store it in the DOM", "is_correct": true},
      {"id": "c", "text": "Controlled components cannot have event handlers", "is_correct": false},
      {"id": "d", "text": "Uncontrolled components require Redux for state management", "is_correct": false}
    ],
    "explanation": "In a controlled component, form data is driven by React state via value and onChange. Uncontrolled components let the DOM hold state, accessed via a ref."
  }$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000000158', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101', 'mcq', 'React.memo purpose', 'intermediate', 1,
  ARRAY['react','performance','memo'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000000159', '00000000-0000-0000-0000-000000000158', 1,
  $json${
    "prompt": "What is the primary purpose of `React.memo()`?",
    "multiple": false,
    "options": [
      {"id": "a", "text": "To memoize expensive function return values", "is_correct": false},
      {"id": "b", "text": "To prevent a component from re-rendering when its props have not changed", "is_correct": true},
      {"id": "c", "text": "To cache API responses between renders", "is_correct": false},
      {"id": "d", "text": "To create memoized event handlers", "is_correct": false}
    ],
    "explanation": "React.memo is a higher-order component that skips re-rendering when props are shallowly equal to the previous render."
  }$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- ─── Questions 9–14: code-snippet MCQ ────────────────────────────────────────

INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000000160', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101', 'mcq', 'Identify stale closure output', 'intermediate', 1,
  ARRAY['react','closures','useEffect'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000000161', '00000000-0000-0000-0000-000000000160', 1,
  $json${
    "prompt": "What will be logged to the console 3 seconds after this component mounts (assume the button is clicked once immediately after mount)?\n\n```jsx\nfunction Counter() {\n  const [count, setCount] = React.useState(0);\n\n  React.useEffect(() => {\n    const timer = setTimeout(() => {\n      console.log('Count is:', count);\n    }, 3000);\n    return () => clearTimeout(timer);\n  }, []);\n\n  return <button onClick={() => setCount(c => c + 1)}>Clicked {count}</button>;\n}\n```",
    "multiple": false,
    "options": [
      {"id": "a", "text": "Count is: 0", "is_correct": true},
      {"id": "b", "text": "Count is: 1", "is_correct": false},
      {"id": "c", "text": "The timer is cancelled and nothing is logged", "is_correct": false},
      {"id": "d", "text": "Count is: undefined", "is_correct": false}
    ],
    "explanation": "The empty dependency array causes the effect to capture count = 0 at mount time. This is the stale closure problem — the setTimeout callback closes over the initial value and never sees subsequent updates."
  }$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000000162', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101', 'mcq', 'Spot the infinite re-fetch bug', 'intermediate', 1,
  ARRAY['react','useEffect','bugs'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000000163', '00000000-0000-0000-0000-000000000162', 1,
  $json${
    "prompt": "What is wrong with the following component?\n\n```jsx\nfunction UserList() {\n  const [users, setUsers] = React.useState([]);\n\n  React.useEffect(() => {\n    fetch('/api/users')\n      .then(r => r.json())\n      .then(data => setUsers(data));\n  }, [users]);\n\n  return <ul>{users.map(u => <li key={u.id}>{u.name}</li>)}</ul>;\n}\n```",
    "multiple": false,
    "options": [
      {"id": "a", "text": "The fetch call is missing async/await", "is_correct": false},
      {"id": "b", "text": "Including `users` in the dependency array causes an infinite re-fetch loop", "is_correct": true},
      {"id": "c", "text": "useState cannot hold arrays", "is_correct": false},
      {"id": "d", "text": "The list items are missing a wrapping fragment", "is_correct": false}
    ],
    "explanation": "setUsers triggers a re-render which produces a new users reference, which triggers the effect again. The fix is to use [] as the dependency array so the fetch runs only once on mount."
  }$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000000164', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101', 'mcq', 'Rules of Hooks violation', 'intermediate', 1,
  ARRAY['react','hooks','rules'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000000165', '00000000-0000-0000-0000-000000000164', 1,
  $json${
    "prompt": "Why is the following code invalid?\n\n```jsx\nfunction Form({ isLoggedIn }) {\n  if (isLoggedIn) {\n    const [name, setName] = React.useState('');\n  }\n  return <input />;\n}\n```",
    "multiple": false,
    "options": [
      {"id": "a", "text": "useState cannot be used inside a function component", "is_correct": false},
      {"id": "b", "text": "Hooks must not be called inside conditional statements — they must be called at the top level", "is_correct": true},
      {"id": "c", "text": "The input element is missing an onChange handler", "is_correct": false},
      {"id": "d", "text": "You cannot destructure the useState return value inside an if block", "is_correct": false}
    ],
    "explanation": "The Rules of Hooks require hooks to be called at the top level of a component, never inside conditions, loops, or nested functions, so React can guarantee consistent hook call order across renders."
  }$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000000166', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101', 'mcq', 'Trace useReducer result', 'intermediate', 1,
  ARRAY['react','useReducer','state'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000000167', '00000000-0000-0000-0000-000000000166', 1,
  $json${
    "prompt": "What does this reducer return when `action.type` is `'increment'` and `state` is `{ count: 5 }`?\n\n```js\nfunction reducer(state, action) {\n  switch (action.type) {\n    case 'increment':\n      return { ...state, count: state.count + 1 };\n    case 'decrement':\n      return { ...state, count: state.count - 1 };\n    case 'reset':\n      return { count: 0 };\n    default:\n      return state;\n  }\n}\n```",
    "multiple": false,
    "options": [
      {"id": "a", "text": "{ count: 5 }", "is_correct": false},
      {"id": "b", "text": "{ count: 6 }", "is_correct": true},
      {"id": "c", "text": "{ count: 4 }", "is_correct": false},
      {"id": "d", "text": "undefined", "is_correct": false}
    ],
    "explanation": "The spread copies the existing state object, then count is overridden with state.count + 1 = 6."
  }$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000000168', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101', 'mcq', 'Custom hook return value', 'intermediate', 1,
  ARRAY['react','custom-hooks'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000000169', '00000000-0000-0000-0000-000000000168', 1,
  $json${
    "prompt": "What does calling `useWindowWidth()` return?\n\n```js\nfunction useWindowWidth() {\n  const [width, setWidth] = React.useState(window.innerWidth);\n\n  React.useEffect(() => {\n    const handler = () => setWidth(window.innerWidth);\n    window.addEventListener('resize', handler);\n    return () => window.removeEventListener('resize', handler);\n  }, []);\n\n  return width;\n}\n```",
    "multiple": false,
    "options": [
      {"id": "a", "text": "An object with width and setWidth properties", "is_correct": false},
      {"id": "b", "text": "The current browser window width as a number, updating reactively on resize", "is_correct": true},
      {"id": "c", "text": "A Promise that resolves to the window width", "is_correct": false},
      {"id": "d", "text": "The resize event handler function", "is_correct": false}
    ],
    "explanation": "The hook initialises width from window.innerWidth, subscribes to the resize event, and returns the reactive width number."
  }$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000000170', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101', 'mcq', 'React Context value resolution', 'intermediate', 1,
  ARRAY['react','context','useContext'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000000171', '00000000-0000-0000-0000-000000000170', 1,
  $json${
    "prompt": "Which value is rendered by `<Child />` when this tree mounts?\n\n```jsx\nconst ThemeContext = React.createContext('light');\n\nfunction App() {\n  return (\n    <ThemeContext.Provider value=\"dark\">\n      <Child />\n    </ThemeContext.Provider>\n  );\n}\n\nfunction Child() {\n  const theme = React.useContext(ThemeContext);\n  return <div>{theme}</div>;\n}\n```",
    "multiple": false,
    "options": [
      {"id": "a", "text": "light", "is_correct": false},
      {"id": "b", "text": "dark", "is_correct": true},
      {"id": "c", "text": "undefined", "is_correct": false},
      {"id": "d", "text": "The component throws a missing-provider error", "is_correct": false}
    ],
    "explanation": "useContext reads the closest Provider's value. The Provider supplies 'dark', so Child renders 'dark'. The default 'light' is only used when no Provider exists in the tree."
  }$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- ─── Questions 15–17: subjective ─────────────────────────────────────────────

INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000000172', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101', 'subjective', 'React reconciliation algorithm', 'advanced', 3,
  ARRAY['react','virtual-dom','reconciliation'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000000173', '00000000-0000-0000-0000-000000000172', 1,
  $json${
    "prompt": "Explain how React's reconciliation algorithm (the \"diffing\" process) works. In your answer describe: (1) how React compares old and new virtual DOM trees, (2) the role of keys in list reconciliation, and (3) one scenario where React skips reconciliation entirely.",
    "word_limit": 400,
    "rubric": [
      "Explains that React builds a virtual DOM tree and diffs it against the previous tree before touching the real DOM",
      "Mentions that React compares elements by type and position, unmounting/remounting when the type changes",
      "Correctly describes how keys let React match list items by identity rather than position",
      "Identifies at least one skipping mechanism: React.memo, shouldComponentUpdate, or PureComponent"
    ]
  }$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000000174', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101', 'subjective', 'State management trade-offs', 'advanced', 3,
  ARRAY['react','state-management','context','redux'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000000175', '00000000-0000-0000-0000-000000000174', 1,
  $json${
    "prompt": "Compare three approaches to sharing state in a React application: (1) prop drilling, (2) React Context API, and (3) an external state manager such as Redux or Zustand. For each approach, describe a concrete use case where it is the best choice and explain why.",
    "word_limit": 500,
    "rubric": [
      "Correctly identifies prop drilling as suitable for shallow trees with a small number of consumers",
      "Explains that Context API is ideal for low-frequency global values such as theme or auth status",
      "Identifies external stores as the right choice for complex, frequently-updated, cross-feature state",
      "Mentions at least one concrete trade-off: performance re-renders, boilerplate, or debugging tooling"
    ]
  }$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000000176', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101', 'subjective', 'Optimise a 10 000-item list', 'expert', 3,
  ARRAY['react','performance','virtualisation'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000000177', '00000000-0000-0000-0000-000000000176', 1,
  $json${
    "prompt": "You are asked to render a virtualized list of 10,000 product cards in React. The list must support filtering by category and sorting by price. Describe your optimisation strategy, naming at least three specific techniques or libraries you would use and explaining why each one helps.",
    "word_limit": 450,
    "rubric": [
      "Mentions windowing / virtualisation (react-window or @tanstack/virtual)",
      "References useMemo or useCallback to avoid recomputing filtered / sorted lists on every render",
      "Suggests server-side filtering or pagination as an alternative or complement to client-side work",
      "Names React.memo or stable key values to prevent unnecessary card re-renders",
      "Demonstrates understanding of why rendering 10,000 DOM nodes simultaneously is slow"
    ]
  }$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- ─── Questions 18–20: coding ──────────────────────────────────────────────────

INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000000178', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101', 'coding', 'FizzBuzz', 'beginner', 2,
  ARRAY['io','conditionals'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000000179', '00000000-0000-0000-0000-000000000178', 1,
  $json${
    "prompt": "Read an integer N from stdin. Print numbers 1 through N on separate lines. For multiples of 3 print Fizz, for multiples of 5 print Buzz, for multiples of both print FizzBuzz.",
    "languages": ["python", "javascript"],
    "starter_code": {
      "python": "n = int(input())\nfor i in range(1, n + 1):\n    if i % 15 == 0:\n        print('FizzBuzz')\n    elif i % 3 == 0:\n        print('Fizz')\n    elif i % 5 == 0:\n        print('Buzz')\n    else:\n        print(i)\n",
      "javascript": "const n = parseInt(require('fs').readFileSync(0, 'utf8').trim());\nfor (let i = 1; i <= n; i++) {\n  if (i % 15 === 0) console.log('FizzBuzz');\n  else if (i % 3 === 0) console.log('Fizz');\n  else if (i % 5 === 0) console.log('Buzz');\n  else console.log(i);\n}\n"
    },
    "time_limit_ms": 2000,
    "memory_limit_kb": 262144,
    "test_cases": [
      {"id": "t1", "stdin": "5",  "expected": "1\n2\nFizz\n4\nBuzz", "hidden": false, "weight": 1},
      {"id": "t2", "stdin": "15", "expected": "1\n2\nFizz\n4\nBuzz\nFizz\n7\n8\nFizz\nBuzz\n11\nFizz\n13\n14\nFizzBuzz", "hidden": true, "weight": 2},
      {"id": "t3", "stdin": "1",  "expected": "1", "hidden": true, "weight": 1}
    ]
  }$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000000180', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101', 'coding', 'Reverse a string', 'beginner', 2,
  ARRAY['strings','loops'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000000181', '00000000-0000-0000-0000-000000000180', 1,
  $json${
    "prompt": "Read a string from stdin and print it reversed. Do not use any built-in reverse function or slice shorthand.",
    "languages": ["python", "javascript"],
    "starter_code": {
      "python": "s = input()\nresult = ''\nfor ch in s:\n    result = ch + result\nprint(result)\n",
      "javascript": "const s = require('fs').readFileSync(0, 'utf8').trim();\nlet result = '';\nfor (const ch of s) result = ch + result;\nconsole.log(result);\n"
    },
    "time_limit_ms": 2000,
    "memory_limit_kb": 262144,
    "test_cases": [
      {"id": "t1", "stdin": "hello", "expected": "olleh", "hidden": false, "weight": 1},
      {"id": "t2", "stdin": "React", "expected": "tcaeR", "hidden": true,  "weight": 1},
      {"id": "t3", "stdin": "a",     "expected": "a",     "hidden": true,  "weight": 1}
    ]
  }$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO questions (id, org_id, category_id, type, title, difficulty, default_points, tags, current_version, created_by)
VALUES ('00000000-0000-0000-0000-000000000182', '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000101', 'coding', 'Count vowels', 'beginner', 2,
  ARRAY['strings','counting'], 1, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

INSERT INTO question_versions (id, question_id, version, content, created_by)
VALUES ('00000000-0000-0000-0000-000000000183', '00000000-0000-0000-0000-000000000182', 1,
  $json${
    "prompt": "Read a string from stdin and print the count of vowels (a, e, i, o, u — case-insensitive).",
    "languages": ["python", "javascript"],
    "starter_code": {
      "python": "s = input().lower()\nprint(sum(1 for c in s if c in 'aeiou'))\n",
      "javascript": "const s = require('fs').readFileSync(0, 'utf8').trim().toLowerCase();\nconsole.log([...s].filter(c => 'aeiou'.includes(c)).length);\n"
    },
    "time_limit_ms": 2000,
    "memory_limit_kb": 262144,
    "test_cases": [
      {"id": "t1", "stdin": "Hello World", "expected": "3", "hidden": false, "weight": 1},
      {"id": "t2", "stdin": "React Hooks", "expected": "3", "hidden": true,  "weight": 1},
      {"id": "t3", "stdin": "rhythm",      "expected": "0", "hidden": true,  "weight": 1}
    ]
  }$json$::jsonb, '00000000-0000-0000-0000-000000000012')
ON CONFLICT (id) DO NOTHING;

-- ─── Update assessment: 20 questions, 60 min, unlimited attempts (100) ────────
UPDATE assessments
SET max_attempts     = 100,
    total_points     = 30,
    duration_minutes = 60,
    description      = 'A comprehensive proctored test covering React hooks, JSX, state management, code analysis, subjective design questions, and algorithmic problem solving.'
WHERE id = '00000000-0000-0000-0000-000000000120';

-- ─── Attach new questions to assessment (positions 3–19) ─────────────────────
INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)
VALUES
  ('00000000-0000-0000-0000-000000000184', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000150', '00000000-0000-0000-0000-000000000151',  3, 1),
  ('00000000-0000-0000-0000-000000000185', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000152', '00000000-0000-0000-0000-000000000153',  4, 1),
  ('00000000-0000-0000-0000-000000000186', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000154', '00000000-0000-0000-0000-000000000155',  5, 1),
  ('00000000-0000-0000-0000-000000000187', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000156', '00000000-0000-0000-0000-000000000157',  6, 1),
  ('00000000-0000-0000-0000-000000000188', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000158', '00000000-0000-0000-0000-000000000159',  7, 1),
  ('00000000-0000-0000-0000-000000000189', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000160', '00000000-0000-0000-0000-000000000161',  8, 1),
  ('00000000-0000-0000-0000-000000000190', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000162', '00000000-0000-0000-0000-000000000163',  9, 1),
  ('00000000-0000-0000-0000-000000000191', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000164', '00000000-0000-0000-0000-000000000165', 10, 1),
  ('00000000-0000-0000-0000-000000000192', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000166', '00000000-0000-0000-0000-000000000167', 11, 1),
  ('00000000-0000-0000-0000-000000000193', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000168', '00000000-0000-0000-0000-000000000169', 12, 1),
  ('00000000-0000-0000-0000-000000000194', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000170', '00000000-0000-0000-0000-000000000171', 13, 1),
  ('00000000-0000-0000-0000-000000000195', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000172', '00000000-0000-0000-0000-000000000173', 14, 3),
  ('00000000-0000-0000-0000-000000000196', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000174', '00000000-0000-0000-0000-000000000175', 15, 3),
  ('00000000-0000-0000-0000-000000000197', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000176', '00000000-0000-0000-0000-000000000177', 16, 3),
  ('00000000-0000-0000-0000-000000000198', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000178', '00000000-0000-0000-0000-000000000179', 17, 2),
  ('00000000-0000-0000-0000-000000000199', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000180', '00000000-0000-0000-0000-000000000181', 18, 2),
  ('00000000-0000-0000-0000-000000000200', '00000000-0000-0000-0000-000000000120',
   '00000000-0000-0000-0000-000000000182', '00000000-0000-0000-0000-000000000183', 19, 2)
ON CONFLICT (id) DO NOTHING;

-- ══════════════════════════════════════════════════════════════════════════
-- Labs fixture — "JavaScript Fundamentals Lab" (code type, standalone)
-- Student can navigate to /labs/00000000-0000-0000-0000-000000000300
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Lab definition (insert unpublished; update to published after version exists) ──
INSERT INTO lab_definitions (id, org_id, scope, title, description, lab_type, environment,
  language, max_duration, max_resets, hint_penalty_pct, is_required, is_published, created_by)
VALUES (
  '00000000-0000-0000-0000-000000000300',
  '00000000-0000-0000-0000-000000000001',
  'standalone',
  'JavaScript Fundamentals Lab',
  'A hands-on lab to practice core JavaScript concepts: array methods, closures, and async patterns.',
  'code',
  'node:18-alpine',
  'javascript',
  60,
  3,
  10,
  false,
  false,
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (id) DO NOTHING;

-- ─── Lab tasks ────────────────────────────────────────────────────────────────
INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script,
  hint_context, explanation_context, points, is_optional, is_stateful)
VALUES
  (
    '00000000-0000-0000-0000-000000000310',
    '00000000-0000-0000-0000-000000000300',
    1,
    'Filter Even Numbers',
    'Write a function filterEvens(arr) that takes an array of integers and returns only the even numbers.',
    'const result = filterEvens([1,2,3,4,5,6]); if (!Array.isArray(result) || result.join(",") !== "2,4,6") throw new Error("Expected [2,4,6]");',
    'Use Array.prototype.filter with the modulo operator.',
    'The filter() method creates a new array with all elements that pass a test. Use n % 2 === 0 to check evenness.',
    20,
    false,
    false
  ),
  (
    '00000000-0000-0000-0000-000000000311',
    '00000000-0000-0000-0000-000000000300',
    2,
    'Write a Counter Closure',
    'Implement makeCounter() that returns an object with increment(), decrement(), and value() methods, using a closure to store the count.',
    'const c = makeCounter(); c.increment(); c.increment(); c.decrement(); if (c.value() !== 1) throw new Error("Expected 1");',
    'Return an object literal from a function that closes over a private variable.',
    'A closure lets inner functions access the outer function scope. Declare let count = 0 inside makeCounter, then return methods that read and modify it.',
    30,
    false,
    false
  ),
  (
    '00000000-0000-0000-0000-000000000312',
    '00000000-0000-0000-0000-000000000300',
    3,
    'Async Fetch Wrapper',
    'Write fetchJSON(url) that calls the Fetch API, parses the JSON response, and returns the parsed object. Return null on error.',
    'fetchJSON("https://jsonplaceholder.typicode.com/todos/1").then(r => { if (!r || !r.id) throw new Error("Expected id field"); });',
    'Use fetch(url).then(r => r.json()).',
    'Chain .then(response => response.json()) to parse the body. Add .catch(() => null) for error handling.',
    20,
    true,
    false
  )
ON CONFLICT (id) DO NOTHING;

-- ─── Published task version (immutable JSONB snapshot) ───────────────────────
INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)
VALUES (
  '00000000-0000-0000-0000-000000000320',
  '00000000-0000-0000-0000-000000000300',
  1,
  $tasks$[
    {
      "id": "00000000-0000-0000-0000-000000000310",
      "position": 1,
      "title": "Filter Even Numbers",
      "description": "Write a function filterEvens(arr) that takes an array of integers and returns only the even numbers.",
      "verification_script": "const result = filterEvens([1,2,3,4,5,6]); if (!Array.isArray(result) || result.join(',') !== '2,4,6') throw new Error('Expected [2,4,6]');",
      "hint_context": "Use Array.prototype.filter with the modulo operator.",
      "explanation_context": "The filter() method creates a new array with all elements that pass a test. Use n % 2 === 0 to check evenness.",
      "points": 20,
      "is_optional": false,
      "is_stateful": false
    },
    {
      "id": "00000000-0000-0000-0000-000000000311",
      "position": 2,
      "title": "Write a Counter Closure",
      "description": "Implement makeCounter() that returns an object with increment(), decrement(), and value() methods, using a closure to store the count.",
      "verification_script": "const c = makeCounter(); c.increment(); c.increment(); c.decrement(); if (c.value() !== 1) throw new Error('Expected 1');",
      "hint_context": "Return an object literal from a function that closes over a private variable.",
      "explanation_context": "A closure lets inner functions access the outer function scope. Declare let count = 0 inside makeCounter, then return methods that read and modify it.",
      "points": 30,
      "is_optional": false,
      "is_stateful": false
    },
    {
      "id": "00000000-0000-0000-0000-000000000312",
      "position": 3,
      "title": "Async Fetch Wrapper",
      "description": "Write fetchJSON(url) that calls the Fetch API, parses the JSON response, and returns the parsed object. Return null on error.",
      "verification_script": "fetchJSON('https://jsonplaceholder.typicode.com/todos/1').then(r => { if (!r || !r.id) throw new Error('Expected id field'); });",
      "hint_context": "Use fetch(url).then(r => r.json()).",
      "explanation_context": "Chain .then(response => response.json()) to parse the body. Add .catch(() => null) for error handling.",
      "points": 20,
      "is_optional": true,
      "is_stateful": false
    }
  ]$tasks$::jsonb,
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (id) DO NOTHING;

-- ─── Publish the lab (idempotent: only sets version when not yet set) ─────────
UPDATE lab_definitions
SET is_published = true,
    published_version_id = '00000000-0000-0000-0000-000000000320'
WHERE id = '00000000-0000-0000-0000-000000000300'
  AND published_version_id IS NULL;

-- ══════════════════════════════════════════════════════════════════════════
-- Interview Prep fixtures — jaiswal2062@gmail.com, one of each plan shape
-- (quick, targeted-technical, targeted-non-technical/behavioral), fully
-- answered/graded so the merged UI has real-looking data to browse without
-- needing a live AI provider. See internal/interviewprep + internal/practice.
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Quick plan: "Go", technical, 3 questions answered ─────────────────────

INSERT INTO practice_sessions (id, user_id, org_id, technology, difficulty, category, question_count, status, ai_model)
VALUES (
  '00000000-0000-0000-0000-000000000500',
  '00000000-0000-0000-0000-000000000015',
  '00000000-0000-0000-0000-000000000001',
  'Go', 'intermediate', 'technical', 3, 'active', 'seed-fixture'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO practice_items (id, session_id, "position", question_text, user_answer, ai_feedback, answered_at, feedback_at)
VALUES
  ('00000000-0000-0000-0000-000000000510', '00000000-0000-0000-0000-000000000500', 0,
   'Explain how goroutines are scheduled onto OS threads in Go.',
   'The Go runtime uses an M:N scheduler — M goroutines are multiplexed onto N OS threads (GOMAXPROCS) via a work-stealing scheduler with P (processor) contexts.',
   '{"score":9,"max_score":10,"strengths":["Correctly named M:N scheduling","Mentioned GOMAXPROCS and work-stealing"],"gaps":["Did not mention the G-M-P model by name"],"suggested_answer":"Go uses a G-M-P scheduler: Goroutines (G) are scheduled onto OS threads (M) via logical Processors (P), which hold a local run queue. Idle Ps steal work from busy ones (work-stealing).","follow_up_resources":["Go scheduler design doc","GOMAXPROCS tuning"],"model":"seed-fixture"}'::jsonb,
   now() - interval '2 days', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000000511', '00000000-0000-0000-0000-000000000500', 1,
   'What is the difference between a buffered and unbuffered channel?',
   'An unbuffered channel blocks the sender until a receiver is ready (synchronous handoff). A buffered channel only blocks once the buffer is full.',
   '{"score":10,"max_score":10,"strengths":["Precise, correct definition of both"],"gaps":[],"suggested_answer":"Unbuffered channels synchronize sender and receiver (rendezvous); buffered channels decouple them up to capacity N, blocking only when full (send) or empty (receive).","follow_up_resources":[],"model":"seed-fixture"}'::jsonb,
   now() - interval '2 days', now() - interval '2 days'),
  ('00000000-0000-0000-0000-000000000512', '00000000-0000-0000-0000-000000000500', 2,
   'How does Go''s garbage collector avoid stop-the-world pauses?',
   'It uses a concurrent tri-color mark-and-sweep collector with write barriers, so most marking happens concurrently with the program.',
   '{"score":7,"max_score":10,"strengths":["Correctly named tri-color mark-and-sweep","Mentioned write barriers"],"gaps":["Did not mention the brief stop-the-world phases still used for stack scanning at GC start/end"],"suggested_answer":"Go''s GC is concurrent tri-color mark-and-sweep with write barriers, running alongside the mutator. Very short STW pauses remain only at the start (turn on write barrier) and end (turn off) of a GC cycle.","follow_up_resources":["Go GC guide","GOGC tuning"],"model":"seed-fixture"}'::jsonb,
   now() - interval '2 days', now() - interval '2 days')
ON CONFLICT (id) DO NOTHING;

INSERT INTO interview_prep_plans (id, user_id, org_id, plan_type, category, job_title, extracted_role, extracted_seniority, extracted_skills, status, ai_model, created_at)
VALUES (
  '00000000-0000-0000-0000-000000000520',
  '00000000-0000-0000-0000-000000000015',
  '00000000-0000-0000-0000-000000000001',
  'quick', 'technical', 'Go', '', '', ARRAY[]::text[], 'ready', 'seed-fixture', now() - interval '2 days'
)
ON CONFLICT (id) DO NOTHING;

UPDATE interview_prep_plans SET technology = 'Go', difficulty = 'intermediate'
WHERE id = '00000000-0000-0000-0000-000000000520';

INSERT INTO interview_prep_rounds (id, plan_id, round_type, order_index, practice_session_id, status)
VALUES (
  '00000000-0000-0000-0000-000000000530',
  '00000000-0000-0000-0000-000000000520',
  'conceptual', 0, '00000000-0000-0000-0000-000000000500', 'active'
)
ON CONFLICT (id) DO NOTHING;

-- ─── Targeted plan: Senior Backend Engineer, technical, 2 rounds + report ──

INSERT INTO practice_sessions (id, user_id, org_id, technology, difficulty, category, question_count, status, ai_model)
VALUES (
  '00000000-0000-0000-0000-000000000501',
  '00000000-0000-0000-0000-000000000015',
  '00000000-0000-0000-0000-000000000001',
  'Go, PostgreSQL, Distributed Systems', 'advanced', 'technical', 3, 'completed', 'seed-fixture'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO practice_items (id, session_id, "position", question_text, user_answer, ai_feedback, answered_at, feedback_at)
VALUES
  ('00000000-0000-0000-0000-000000000513', '00000000-0000-0000-0000-000000000501', 0,
   'How would you design a rate limiter shared across multiple backend instances?',
   'Use a centralized store like Redis with a sliding-window or token-bucket algorithm implemented via a Lua script for atomicity.',
   '{"score":9,"max_score":10,"strengths":["Correct centralized approach","Mentioned atomicity via Lua script"],"gaps":["Did not compare token-bucket vs sliding-window tradeoffs"],"suggested_answer":"A Redis-backed token bucket, refilled via a Lua script (atomic check-and-decrement), scales across instances since state is centralized. Sliding-window log is more accurate but costlier in memory.","follow_up_resources":["Redis rate limiting patterns"],"model":"seed-fixture"}'::jsonb,
   now() - interval '5 days', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000000514', '00000000-0000-0000-0000-000000000501', 1,
   'Explain how you would handle a hot partition in a sharded PostgreSQL setup.',
   'Identify the hot key via query stats, then either split the shard further or move that specific key range to its own dedicated node.',
   '{"score":8,"max_score":10,"strengths":["Correct diagnosis approach","Practical mitigation (isolate the hot key)"],"gaps":["Did not mention read replicas as a shorter-term mitigation"],"suggested_answer":"Diagnose via pg_stat_statements/pg_stat_user_tables, then mitigate short-term with a read replica for that shard, and long-term by re-sharding on a key that distributes the hot range.","follow_up_resources":["PostgreSQL partitioning docs"],"model":"seed-fixture"}'::jsonb,
   now() - interval '5 days', now() - interval '5 days'),
  ('00000000-0000-0000-0000-000000000515', '00000000-0000-0000-0000-000000000501', 2,
   'What consistency model would you choose for a distributed shopping cart, and why?',
   'Eventual consistency with conflict resolution (e.g. last-write-wins or CRDTs) since availability during network partitions matters more than strict consistency for a cart.',
   '{"score":10,"max_score":10,"strengths":["Correct AP tradeoff reasoning","Named a concrete conflict-resolution strategy (CRDTs)"],"gaps":[],"suggested_answer":"Eventual consistency (AP under CAP) fits a shopping cart well: merge concurrent updates with a CRDT (e.g. a grow-only set for added items) rather than blocking on strict consistency.","follow_up_resources":[],"model":"seed-fixture"}'::jsonb,
   now() - interval '5 days', now() - interval '5 days')
ON CONFLICT (id) DO NOTHING;

INSERT INTO interview_prep_plans (id, user_id, org_id, plan_type, category, job_title, jd_text, extracted_role, extracted_seniority, extracted_skills, status, report, ai_model, created_at, completed_at)
VALUES (
  '00000000-0000-0000-0000-000000000521',
  '00000000-0000-0000-0000-000000000015',
  '00000000-0000-0000-0000-000000000001',
  'targeted', 'technical', 'Senior Backend Engineer',
  'We are hiring a Senior Backend Engineer with 5+ years of experience in distributed systems, Go, and PostgreSQL.',
  'Senior Backend Engineer', 'advanced', ARRAY['Go','PostgreSQL','Distributed Systems'],
  'completed',
  '{"readiness_score":83.5,"conceptual_score_pct":90,"coding_pass_rate_pct":77,"strong_skills":["Distributed Systems","Go"],"weak_skills":["PostgreSQL"],"summary":"Strong grasp of distributed systems tradeoffs and Go internals. Coding round shows solid fundamentals with room to tighten edge-case handling under time pressure.","next_steps":["Practice more PostgreSQL indexing/partitioning scenarios","Time-box coding round practice to sharpen edge-case coverage"],"cards_added":1,"ai_model":"seed-fixture"}'::jsonb,
  'seed-fixture', now() - interval '5 days', now() - interval '5 days'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO interview_prep_rounds (id, plan_id, round_type, order_index, practice_session_id, status)
VALUES (
  '00000000-0000-0000-0000-000000000531',
  '00000000-0000-0000-0000-000000000521',
  'conceptual', 0, '00000000-0000-0000-0000-000000000501', 'completed'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO interview_prep_rounds (id, plan_id, round_type, order_index, items, status, score, completed_at)
VALUES (
  '00000000-0000-0000-0000-000000000532',
  '00000000-0000-0000-0000-000000000521',
  'coding', 1,
  '[
    {
      "id": "item-0",
      "prompt": "Write a function that merges two sorted integer slices into one sorted slice.",
      "language": "go",
      "starter_code": "func merge(a, b []int) []int {\n\t// TODO\n}",
      "test_cases": [{"stdin":"1 3 5\n2 4 6","expected":"1 2 3 4 5 6","hidden":false}],
      "skill": "Data Structures",
      "submitted_code": "func merge(a, b []int) []int {\n\ti, j := 0, 0\n\tout := make([]int, 0, len(a)+len(b))\n\tfor i < len(a) && j < len(b) {\n\t\tif a[i] <= b[j] { out = append(out, a[i]); i++ } else { out = append(out, b[j]); j++ }\n\t}\n\treturn append(append(out, a[i:]...), b[j:]...)\n}",
      "run_result": {"status":"passed","tests_total":3,"tests_passed":3},
      "passed": true
    },
    {
      "id": "item-1",
      "prompt": "Implement a bounded worker pool that processes jobs from a channel with N concurrent workers.",
      "language": "go",
      "starter_code": "func workerPool(jobs <-chan int, n int) {\n\t// TODO\n}",
      "test_cases": [{"stdin":"5 2","expected":"done","hidden":false}],
      "skill": "Concurrency",
      "submitted_code": "func workerPool(jobs <-chan int, n int) {\n\tvar wg sync.WaitGroup\n\tfor i := 0; i < n; i++ {\n\t\twg.Add(1)\n\t\tgo func() { defer wg.Done(); for range jobs {} }()\n\t}\n\twg.Wait()\n}",
      "run_result": {"status":"failed","tests_total":3,"tests_passed":1},
      "passed": false
    }
  ]'::jsonb,
  'completed', 77, now() - interval '5 days'
)
ON CONFLICT (id) DO NOTHING;

-- ─── Targeted plan: Senior Product Manager, non-technical, single behavioral round + report ──

INSERT INTO practice_sessions (id, user_id, org_id, technology, difficulty, category, question_count, status, ai_model)
VALUES (
  '00000000-0000-0000-0000-000000000502',
  '00000000-0000-0000-0000-000000000015',
  '00000000-0000-0000-0000-000000000001',
  'Stakeholder Management, Prioritization, Roadmapping', 'advanced', 'behavioral', 3, 'completed', 'seed-fixture'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO practice_items (id, session_id, "position", question_text, user_answer, ai_feedback, answered_at, feedback_at)
VALUES
  ('00000000-0000-0000-0000-000000000516', '00000000-0000-0000-0000-000000000502', 0,
   'Tell me about a time you had to say no to a stakeholder''s feature request.',
   'A sales lead wanted a custom integration for one account. I showed the opportunity-cost data against our roadmap, proposed a smaller interim workaround, and got buy-in within a week.',
   '{"score":8,"max_score":10,"strengths":["Clear situation and concrete outcome","Used data to justify the decision"],"gaps":["Result lacked a measurable business metric"],"suggested_answer":"Structure with STAR: Situation (the ask), Task (protect roadmap integrity), Action (data-backed pushback + alternative), Result (quantified outcome, e.g. retained the account without derailing the quarter).","follow_up_resources":["STAR method"],"model":"seed-fixture"}'::jsonb,
   now() - interval '3 days', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000000517', '00000000-0000-0000-0000-000000000502', 1,
   'Describe a time a launch didn''t go as planned. What did you do?',
   'A pricing page redesign hurt conversion in the first 48 hours. I rolled back the riskiest change, kept the rest, and re-tested incrementally.',
   '{"score":9,"max_score":10,"strengths":["Fast, decisive response to signal","Incremental re-testing shows good process"],"gaps":["Could name the specific metric drop for credibility"],"suggested_answer":"Add the number: e.g. \"conversion dropped 12% in 48 hours\" makes the story concrete and memorable to an interviewer.","follow_up_resources":[],"model":"seed-fixture"}'::jsonb,
   now() - interval '3 days', now() - interval '3 days'),
  ('00000000-0000-0000-0000-000000000518', '00000000-0000-0000-0000-000000000502', 2,
   'How do you prioritize when engineering, design, and sales all want different things this quarter?',
   'I run a lightweight RICE scoring pass with each lead, then present the ranked list with tradeoffs in a single planning session so the decision is visible and shared.',
   '{"score":9,"max_score":10,"strengths":["Named a concrete framework (RICE)","Emphasized shared visibility, not unilateral decisions"],"gaps":[],"suggested_answer":"This is a strong answer as-is — naming RICE and making the tradeoff session cross-functional both signal maturity.","follow_up_resources":[],"model":"seed-fixture"}'::jsonb,
   now() - interval '3 days', now() - interval '3 days')
ON CONFLICT (id) DO NOTHING;

INSERT INTO interview_prep_plans (id, user_id, org_id, plan_type, category, job_title, jd_text, extracted_role, extracted_seniority, extracted_skills, status, report, ai_model, created_at, completed_at)
VALUES (
  '00000000-0000-0000-0000-000000000522',
  '00000000-0000-0000-0000-000000000015',
  '00000000-0000-0000-0000-000000000001',
  'targeted', 'behavioral', 'Senior Product Manager',
  'Looking for a Senior PM to own our core product roadmap, working closely with engineering, design, and sales.',
  'Senior Product Manager', 'advanced', ARRAY['Stakeholder Management','Prioritization','Roadmapping'],
  'completed',
  '{"readiness_score":86.7,"conceptual_score_pct":86.7,"coding_pass_rate_pct":0,"strong_skills":["Prioritization","Stakeholder Management"],"weak_skills":[],"summary":"Consistently strong STAR-structured answers with clear decision frameworks. Ready for senior PM loops; adding hard numbers to results would push these from good to excellent.","next_steps":["Add a quantified metric to every behavioral story","Prepare one more example centered on a failed prioritization call"],"cards_added":0,"ai_model":"seed-fixture"}'::jsonb,
  'seed-fixture', now() - interval '3 days', now() - interval '3 days'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO interview_prep_rounds (id, plan_id, round_type, order_index, practice_session_id, status)
VALUES (
  '00000000-0000-0000-0000-000000000533',
  '00000000-0000-0000-0000-000000000522',
  'behavioral', 0, '00000000-0000-0000-0000-000000000502', 'completed'
)
ON CONFLICT (id) DO NOTHING;

-- ══════════════════════════════════════════════════════════════════════════
-- Public Discover roadmaps — pulled from system-design-12-week.vercel.app
-- and system-design-24-week.vercel.app, owned by the dev student account,
-- is_public so they render on the anonymous /roadmaps Discover gallery.
-- Nested phase->milestone->module tree lives in roadmaps.structure (JSONB) —
-- see internal/roadmap/repo.go getTree for the exact shape it parses.
-- Node ids are generated by gen_random_uuid() at insert time.
-- ══════════════════════════════════════════════════════════════════════════

INSERT INTO roadmaps (id, user_id, org_id, title, mode, status, is_public, goal_description, target_role, skill_level, timeframe_weeks, focus_areas, generated_at, structure)
VALUES (
  '00000000-0000-0000-0000-000000007001',
  '00000000-0000-0000-0000-000000000014',
  '00000000-0000-0000-0000-000000000001',
  'System Design Mental Models — 12 Week Roadmap',
  'defined', 'active', true,
  'Build the mental models for every system design trade-off conversation: scalability, databases, caching, APIs, async systems, reliability, microservices, real-time systems, search, security, and AI-native infrastructure — 5-6 hours a week, AI-guided.',
  'Backend Engineer', 'intermediate', 12,
  '["system-design","backend","interview-prep"]'::jsonb, now(),
  jsonb_build_object('phases', jsonb_build_array(

    jsonb_build_object(
      'id', gen_random_uuid(), 'title', 'Phase 1: Scalability, Databases & Caching', 'description', 'Foundation', 'position', 0, 'estimated_weeks', 3,
      'milestones', jsonb_build_array(

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Week 01 — Scalability Thinking & System Primitives', 'description', 'Develop the vocabulary and mental models for every trade-off conversation. Before you can design systems, you need to understand what ''scale'' means and where systems break.', 'position', 0, 'estimated_hours', 6, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 1 — How Systems Break', 'description', 'Horizontal vs vertical scaling; Stateless vs stateful services; CAP theorem in practice; Latency vs throughput; P99 / P999 tail latencies; Little''s Law (L = λW); The 8 fallacies of distributed computing', 'position', 0, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 2 — Estimation & Reliability', 'description', 'Back-of-envelope estimation; QPS, storage, bandwidth calculations; Numbers every engineer must memorize; SLOs, SLAs, error budgets; Single points of failure (SPOF); Active-active vs active-passive redundancy; Load balancing algorithms', 'position', 1, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design Exercise: Estimate Twitter & WhatsApp at scale', 'description', 'Estimate Twitter at 500M DAU — calculate peak QPS, daily storage for tweets and media, and bandwidth. State every assumption. Then repeat for WhatsApp. 30 minutes per system.', 'position', 2, 'type', 'project', 'estimated_minutes', 60)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Week 02 — Databases — Internals, Scaling & Schema Design', 'description', 'The database is almost always the hardest layer to change. A wrong choice compounds for years.', 'position', 1, 'estimated_hours', 6, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 1 — Database Internals', 'description', 'Storage engines: B-tree vs LSM-tree; Write-Ahead Log (WAL); Change Data Capture (CDC); MVCC & isolation levels; Indexing strategies (covering, composite); Connection pooling (PgBouncer); Replication: single-leader, multi-leader, leaderless', 'position', 0, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 2 — Choosing & Scaling', 'description', 'Database taxonomy (SQL, NoSQL, NewSQL, Vector); ACID vs BASE; Sharding: range, hash, consistent hashing; Hot partition problem; Denormalization trade-offs; Schema design principles; Distributed transactions', 'position', 1, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design Exercise: Design the Instagram Database', 'description', 'Model the schema for users, posts, followers, likes. Choose the DB(s), justify the choice, identify the first shard point.', 'position', 2, 'type', 'project', 'estimated_minutes', 60)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Week 03 — Caching Architecture & CDNs', 'description', 'Caching buys 10x performance for a fraction of the cost — but wrong strategies cause subtle production disasters.', 'position', 2, 'estimated_hours', 6, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 1 — Caching Strategies', 'description', 'Cache-aside (lazy loading); Read-through & write-through; Write-behind & write-around; TTL vs event-driven invalidation; Eviction policies: LRU, LFU, ARC; Multi-level caching (L1 -> L2 -> CDN -> DB); Negative caching', 'position', 0, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 2 — Failure Modes & CDNs', 'description', 'Thundering herd / cache stampede; Cache avalanche; Hot key problem; Probabilistic expiration (PER algorithm); CDN architecture & origin shielding; Stale-while-revalidate; Edge computing (Cloudflare Workers)', 'position', 1, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design Exercise: Design a Redis Cache Strategy for Twitter', 'description', 'Decide what data to cache, TTLs, invalidation strategy, and how to handle cache stampede for viral tweets.', 'position', 2, 'type', 'project', 'estimated_minutes', 60)
        ))

      )
    ),

    jsonb_build_object(
      'id', gen_random_uuid(), 'title', 'Phase 2: APIs, Async Systems & Fault Tolerance', 'description', 'Communication', 'position', 1, 'estimated_weeks', 3,
      'milestones', jsonb_build_array(

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Week 04 — API Design, Service Communication & Rate Limiting', 'description', 'Modern systems mix REST, gRPC, and GraphQL. Designing APIs that evolve without breaking clients is a core senior skill.', 'position', 0, 'estimated_hours', 6, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 1 — API Design', 'description', 'REST principles & idempotency; gRPC & Protocol Buffers; GraphQL — when it helps/hurts; API versioning strategies; Pagination: cursor vs offset vs keyset; Idempotency keys (Stripe pattern); Status codes that matter', 'position', 0, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 2 — Gateways & Rate Limiting', 'description', 'API gateway responsibilities; Backend for Frontend (BFF) pattern; Service mesh (Istio / Linkerd); Rate limiting: token bucket, leaky bucket, sliding window; Distributed rate limiting with Redis; Retry with exponential backoff + jitter; Timeout cascade hierarchy', 'position', 1, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design Exercise: Design a Public Payment API', 'description', 'REST endpoints for charge/refund/dispute, idempotency keys, versioning strategy, and per-tier rate limits.', 'position', 2, 'type', 'project', 'estimated_minutes', 60)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Week 05 — Async Systems — Queues, Kafka & Event-Driven Patterns', 'description', 'Every system above ~10K RPS has async components. Event-driven architecture decouples services.', 'position', 1, 'estimated_hours', 6, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 1 — Queues & Kafka', 'description', 'At-most-once / at-least-once / exactly-once; Queue vs stream vs pub/sub; Kafka: topics, partitions, offsets, consumer groups; Partition key design; Dead letter queues (DLQ); Backpressure handling; Log compaction', 'position', 0, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 2 — Event-Driven Patterns', 'description', 'Transactional outbox pattern; CDC with Debezium; CQRS; Event sourcing; Saga pattern: choreography vs orchestration; Compensating transactions; Temporal.io — durable workflows', 'position', 1, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design Exercise: Design an Event-Driven Order Pipeline', 'description', 'payment -> inventory -> fulfillment -> notification via Kafka, using the Saga pattern, with failure handling.', 'position', 2, 'type', 'project', 'estimated_minutes', 60)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Week 06 — Reliability Engineering — Fault Tolerance & Observability', 'description', 'A system that doesn''t fail gracefully isn''t production-ready. Observability is first-class.', 'position', 2, 'estimated_hours', 6, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 1 — Fault Tolerance', 'description', 'Circuit breaker (Closed/Open/Half-Open); Bulkhead isolation; Timeout cascade strategy; Fallback responses; Graceful degradation; Health checks: liveness vs readiness; Blue-green, canary & rolling deployments; Feature flags', 'position', 0, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 2 — Observability', 'description', 'Metrics: RED method, USE method; Structured logging + correlation IDs; Distributed tracing: spans, traces, sampling; OpenTelemetry; Alert on symptoms, not causes; Multi-burn-rate SLO alerting; Runbooks for every alert', 'position', 1, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design Exercise: Failure Mode Analysis — Order Pipeline', 'description', 'For each Week 5 service, list the top 3 failure modes, circuit breaker thresholds, fallback responses, and alerting rules.', 'position', 2, 'type', 'project', 'estimated_minutes', 60)
        ))

      )
    ),

    jsonb_build_object(
      'id', gen_random_uuid(), 'title', 'Phase 3: Microservices, Real-Time & Search', 'description', 'Advanced', 'position', 2, 'estimated_weeks', 3,
      'milestones', jsonb_build_array(

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Week 07 — Microservices & Cloud-Native Architecture', 'description', 'Microservices are dominant but commonly botched. Service boundaries via DDD separate architects from implementers.', 'position', 0, 'estimated_hours', 6, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 1 — Service Design', 'description', 'DDD fundamentals; Bounded contexts & aggregates; Conway''s Law in practice; Service granularity trade-offs; Anti-corruption layer (ACL); Strangler Fig migration pattern; Shared database anti-pattern', 'position', 0, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 2 — Cloud-Native Operations', 'description', 'Kubernetes: Pod, Deployment, HPA; GitOps with ArgoCD/Flux; Serverless (Lambda, Cloud Run) — when it fits; KEDA event-driven autoscaling; Temporal.io workflow orchestration; Helm chart patterns; Cost optimization at scale', 'position', 1, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design Exercise: Break a Monolith into Microservices', 'description', 'Apply DDD to an e-commerce monolith: bounded contexts, service map, data ownership, and the first extraction target.', 'position', 2, 'type', 'project', 'estimated_minutes', 60)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Week 08 — Real-Time Systems — WebSockets, SSE & Live Architectures', 'description', 'Real-time is now standard; a technically underrated, high-leverage area.', 'position', 1, 'estimated_hours', 6, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 1 — Transport Protocols', 'description', 'WebSocket lifecycle & connection management; Server-Sent Events (SSE); Long polling (legacy); HTTP/2 multiplexing; WebRTC for P2P media; Protocol selection by use case; Scaling stateful connections', 'position', 0, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 2 — Scaling Real-Time', 'description', 'Fan-out-on-write vs fan-out-on-read; Celebrity/high-follower problem; Presence systems (heartbeat + Redis TTL); WebSocket clustering with Redis Pub/Sub; CRDTs: Yjs/Automerge; Operational transforms (OT); Collaborative editing persistence & catch-up', 'position', 1, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design Exercise: Design a Real-Time Notification System', 'description', '10M users, 300 avg followers. Define the fan-out strategy, delivery latency SLO, and handling for 10M+ follower accounts.', 'position', 2, 'type', 'project', 'estimated_minutes', 60)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Week 09 — Search Systems, Feed Ranking & Data Pipelines', 'description', 'Search and feed systems combine indexing, ranking, caching, and real-time updates — highest architectural complexity per feature.', 'position', 2, 'estimated_hours', 6, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 1 — Search Architecture', 'description', 'Inverted index fundamentals; BM25 scoring (Elasticsearch default); Typeahead/autocomplete design; Spell correction (Levenshtein, n-gram); Faceted search & geo-search; Index sharding & zero-downtime reindex; Semantic search + vector embeddings (HNSW)', 'position', 0, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 2 — Feeds & Pipelines', 'description', 'Feed ranking pipeline stages; Feature store design (online vs offline); Lambda vs Kappa architecture; Apache Flink stream processing; Hybrid search: BM25 + vector (RRF); A/B test infrastructure for ranking; Data lakehouse (Apache Iceberg)', 'position', 1, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design Exercise: Design Twitter''s "For You" Feed', 'description', '300M DAU. Design the full pipeline: candidate generation, ranking stages, the celebrity problem, and A/B testing.', 'position', 2, 'type', 'project', 'estimated_minutes', 60)
        ))

      )
    ),

    jsonb_build_object(
      'id', gen_random_uuid(), 'title', 'Phase 4: Security, AI Infrastructure & Design Mastery', 'description', 'Modern Frontiers', 'position', 3, 'estimated_weeks', 3,
      'milestones', jsonb_build_array(

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Week 10 — Security Architecture & Multi-Tenancy', 'description', 'Security has moved to a first-class architecture concern.', 'position', 0, 'estimated_hours', 6, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 1 — Auth & Identity', 'description', 'OAuth 2.0 + PKCE flows; JWT: access token + refresh token pattern; JWT vs opaque tokens (revocation trade-off); OIDC & SSO patterns; mTLS for service-to-service auth; RBAC, ABAC, ReBAC (Google Zanzibar); Open Policy Agent (OPA)', 'position', 0, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 2 — Data Security & Multi-Tenancy', 'description', 'Encryption at rest vs in transit; PII tokenization; Secret management (Vault, AWS Secrets Manager); Multi-tenancy models: silo, pool, bridge; Row-level security (PostgreSQL RLS); GDPR-compliant data deletion pipeline; Audit logging design', 'position', 1, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design Exercise: Design Auth for a Multi-Tenant SaaS', 'description', 'Tenant isolation, session management, token refresh, and a revoke-all-in-60s incident response plan.', 'position', 2, 'type', 'project', 'estimated_minutes', 60)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Week 11 — AI-Native Infrastructure — LLMs, RAG & Vector Systems', 'description', 'Backend engineers are now expected to integrate AI components into production systems.', 'position', 1, 'estimated_hours', 6, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 1 — LLM Serving', 'description', 'KV cache & memory management for inference; Continuous batching (vLLM/PagedAttention); Token streaming via SSE; TTFT vs total latency; Model quantization (INT8/INT4) trade-offs; Multi-GPU model sharding (70B+ models); LLM gateway pattern', 'position', 0, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 2 — RAG & Vector Systems', 'description', 'RAG pipeline: ingest -> chunk -> embed -> index -> retrieve -> generate; Chunking strategies (fixed, semantic, recursive); ANN algorithms: HNSW, IVF, IVF-PQ; Hybrid retrieval: BM25 + vector (RRF); Re-ranking with cross-encoders; Prompt caching; Agent tool-call orchestration & guardrails', 'position', 1, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design Exercise: Design a Production RAG System', 'description', 'A customer support chatbot over 10M documents with P99 latency under 2 seconds.', 'position', 2, 'type', 'project', 'estimated_minutes', 60)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Week 12 — Design Interview Mastery & Synthesis', 'description', 'System design interviews reward structured thinking under time pressure.', 'position', 2, 'estimated_hours', 6, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 1 — The Design Framework', 'description', 'Clarify requirements (5 min); Capacity estimation (3 min); High-level design (10 min); Deep dive 2-3 components (15 min); Trade-offs & bottlenecks (5 min); Failure modes & observability (5 min); Time-boxing each phase', 'position', 0, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Session 2 — Mock Interviews & Synthesis', 'description', 'Common failure modes in design discussions; Phrases that signal seniority; Writing a design doc (500-word format); Component cheat sheet library; Recording & reviewing mock sessions; Feedback loop', 'position', 1, 'type', 'reading', 'estimated_minutes', 150),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Capstone: 3 Full Mock Design Sessions', 'description', 'Run three 45-minute mock system design interviews end to end, then review and score each one.', 'position', 2, 'type', 'project', 'estimated_minutes', 135)
        ))

      )
    ),

    jsonb_build_object(
      'id', gen_random_uuid(), 'title', 'Phase 5: Practice & Capstone Projects', 'description', 'Optional — apply the mental models to real design problems and hands-on builds.', 'position', 4, 'estimated_weeks', 0,
      'milestones', jsonb_build_array(

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Practice Problems', 'description', 'Timed system-design practice problems spanning the full roadmap.', 'position', 0, 'estimated_hours', 16, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design a URL Shortener', 'description', 'Base62, Redis, Analytics — Medium', 'position', 0, 'type', 'project', 'estimated_minutes', 60),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design a Rate Limiter', 'description', 'Token bucket, Redis, Distributed — Medium', 'position', 1, 'type', 'project', 'estimated_minutes', 60),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design Instagram Stories', 'description', 'TTL, CDN, Fan-out — Medium', 'position', 2, 'type', 'project', 'estimated_minutes', 60),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design a Chat System (WhatsApp)', 'description', 'WebSocket, Presence, E2E encryption — Hard', 'position', 3, 'type', 'project', 'estimated_minutes', 90),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design YouTube / Netflix Streaming', 'description', 'CDN, Adaptive bitrate, Transcoding — Hard', 'position', 4, 'type', 'project', 'estimated_minutes', 90),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design Google Maps', 'description', 'Graph, Geo-index, Tile server — Hard', 'position', 5, 'type', 'project', 'estimated_minutes', 90),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design a Distributed Cache', 'description', 'Consistent hash, Replication — Hard', 'position', 6, 'type', 'project', 'estimated_minutes', 90),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design a Web Crawler', 'description', 'BFS, Politeness, Dedup — Medium', 'position', 7, 'type', 'project', 'estimated_minutes', 60),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design a Typeahead / Autocomplete', 'description', 'Trie, Ranking, Prefix — Medium', 'position', 8, 'type', 'project', 'estimated_minutes', 60),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design a Notification Service', 'description', 'Fan-out, Priority queues — Medium', 'position', 9, 'type', 'project', 'estimated_minutes', 60),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design an Object Storage (S3)', 'description', 'Chunking, Replication — Expert', 'position', 10, 'type', 'project', 'estimated_minutes', 120),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design a Flash Sale System', 'description', 'Inventory lock, Queue — Hard', 'position', 11, 'type', 'project', 'estimated_minutes', 90),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design a RAG Support Chatbot', 'description', 'Vector DB, LLM gateway — Hard', 'position', 12, 'type', 'project', 'estimated_minutes', 90),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design LLM Serving Infrastructure', 'description', 'GPU batching, vLLM — Expert', 'position', 13, 'type', 'project', 'estimated_minutes', 120),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design a Distributed Job Scheduler', 'description', 'DAG, Exactly-once — Hard', 'position', 14, 'type', 'project', 'estimated_minutes', 90)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Hands-On Mini Projects', 'description', 'Build real, runnable systems to cement each phase.', 'position', 1, 'estimated_hours', 20, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Distributed URL Shortener', 'description', 'Redis, PostgreSQL, Nginx, Fly.io multi-region — pairs with Weeks 1-2', 'position', 0, 'type', 'project', 'estimated_minutes', 240),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Event-Driven Order Pipeline', 'description', 'Kafka, PostgreSQL outbox, Debezium CDC, Docker Compose — pairs with Weeks 4-5', 'position', 1, 'type', 'project', 'estimated_minutes', 240),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Real-Time Presence System', 'description', 'WebSocket, Redis Pub/Sub, k6 load testing, Node.js cluster — pairs with Weeks 6-8', 'position', 2, 'type', 'project', 'estimated_minutes', 240),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Hybrid Search Engine', 'description', 'Elasticsearch, pgvector, Sentence transformers, FastAPI — pairs with Week 9', 'position', 3, 'type', 'project', 'estimated_minutes', 240),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Production RAG Pipeline', 'description', 'Anthropic API, Qdrant, LlamaIndex, OpenTelemetry — pairs with Week 11', 'position', 4, 'type', 'project', 'estimated_minutes', 240),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Full Observability Stack', 'description', 'Prometheus, Grafana, Loki, Tempo — ongoing throughout', 'position', 5, 'type', 'project', 'estimated_minutes', 240)
        ))

      )
    )

  ))
)
ON CONFLICT (id) DO UPDATE SET structure = EXCLUDED.structure, updated_at = now();

INSERT INTO roadmaps (id, user_id, org_id, title, mode, status, is_public, goal_description, target_role, skill_level, timeframe_weeks, focus_areas, generated_at, structure)
VALUES (
  '00000000-0000-0000-0000-000000007002',
  '00000000-0000-0000-0000-000000000014',
  '00000000-0000-0000-0000-000000000001',
  'System Design Implementation — 26 Week Roadmap',
  'defined', 'active', true,
  'From fundamentals to AI-era system design: networking, databases, distributed systems, reliability, cloud infrastructure, and building production AI agents — implementation-heavy, 7-8 hours a week. Complete Phase 1+2 (core), then pick Phase 3-6 based on your goal.',
  'Backend Engineer', 'advanced', 26,
  '["system-design","backend","cloud","ai-infrastructure"]'::jsonb, now(),
  jsonb_build_object('phases', jsonb_build_array(

    jsonb_build_object(
      'id', gen_random_uuid(), 'title', 'Phase 1: Foundations', 'description', 'Beginner — Weeks 1-4', 'position', 0, 'estimated_weeks', 4,
      'milestones', jsonb_build_array(

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Networking Basics', 'description', null, 'position', 0, 'estimated_hours', 8, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'OSI & TCP/IP model', 'description', '7 layers, protocols, packets', 'position', 0, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'HTTP/HTTPS/HTTP2/HTTP3', 'description', 'Request lifecycle, headers, TLS', 'position', 1, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'DNS & CDN', 'description', 'Resolution, TTL, Anycast', 'position', 2, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'WebSockets & SSE', 'description', 'Real-time communication', 'position', 3, 'type', 'reading', 'estimated_minutes', 30),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'REST vs GraphQL vs gRPC', 'description', 'API design trade-offs', 'position', 4, 'type', 'reading', 'estimated_minutes', 45)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Storage & Databases', 'description', null, 'position', 1, 'estimated_hours', 8, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Relational DBs / SQL', 'description', 'ACID, normalization, indexing', 'position', 0, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'NoSQL DBs', 'description', 'MongoDB, Cassandra, DynamoDB', 'position', 1, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'CAP theorem', 'description', 'Consistency vs availability', 'position', 2, 'type', 'reading', 'estimated_minutes', 30),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'ACID vs BASE', 'description', 'Transaction models', 'position', 3, 'type', 'reading', 'estimated_minutes', 30),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Database indexing', 'description', 'B-tree, hash, composite', 'position', 4, 'type', 'reading', 'estimated_minutes', 45)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'OS & Compute Basics', 'description', null, 'position', 2, 'estimated_hours', 4, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Processes & threads', 'description', 'Concurrency, parallelism', 'position', 0, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Memory management', 'description', 'Heap, stack, paging', 'position', 1, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'I/O & file systems', 'description', 'Disk, SSD, block vs object', 'position', 2, 'type', 'reading', 'estimated_minutes', 45)
        ))

      )
    ),

    jsonb_build_object(
      'id', gen_random_uuid(), 'title', 'Phase 2: Core System Design', 'description', 'Intermediate — Weeks 5-10', 'position', 1, 'estimated_weeks', 6,
      'milestones', jsonb_build_array(

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Scalability', 'description', null, 'position', 0, 'estimated_hours', 9, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Horizontal vs vertical scaling', 'description', null, 'position', 0, 'type', 'reading', 'estimated_minutes', 30),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Load balancers', 'description', 'Round-robin, least-conn, L4/L7', 'position', 1, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Caching strategies', 'description', 'Redis, Memcached, TTL, eviction', 'position', 2, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'CDN architecture', 'description', 'Edge caching, invalidation', 'position', 3, 'type', 'reading', 'estimated_minutes', 30),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Database sharding', 'description', 'Horizontal partitioning, shard keys', 'position', 4, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Read replicas', 'description', 'Leader-follower, replication lag', 'position', 5, 'type', 'reading', 'estimated_minutes', 30)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Distributed Systems', 'description', null, 'position', 1, 'estimated_hours', 9, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Consistent hashing', 'description', 'Node addition, virtual nodes', 'position', 0, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Replication', 'description', 'Sync vs async, quorum writes', 'position', 1, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Consensus / Raft / Paxos', 'description', 'Leader election, log replication', 'position', 2, 'type', 'reading', 'estimated_minutes', 60),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Distributed transactions', 'description', '2PC, saga pattern', 'position', 3, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Clock & ordering', 'description', 'Lamport clocks, vector clocks', 'position', 4, 'type', 'reading', 'estimated_minutes', 45)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Messaging & Async', 'description', null, 'position', 2, 'estimated_hours', 6, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Message queues', 'description', 'Kafka, RabbitMQ, SQS', 'position', 0, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Event-driven architecture', 'description', 'Pub-sub, CQRS', 'position', 1, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Exactly-once delivery', 'description', 'Idempotency, dedup', 'position', 2, 'type', 'reading', 'estimated_minutes', 30),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Stream processing', 'description', 'Kafka Streams, Flink basics', 'position', 3, 'type', 'reading', 'estimated_minutes', 45)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'High-Level Design (HLD)', 'description', null, 'position', 3, 'estimated_hours', 12, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'System estimation', 'description', 'QPS, storage, bandwidth math', 'position', 0, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Component design', 'description', 'API gateway, service mesh', 'position', 1, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Microservices patterns', 'description', 'Decomposition, circuit breaker', 'position', 2, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design a URL shortener', 'description', null, 'position', 3, 'type', 'project', 'estimated_minutes', 60),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design Instagram / Twitter', 'description', 'Feed, fan-out', 'position', 4, 'type', 'project', 'estimated_minutes', 90),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design WhatsApp', 'description', 'Messaging at scale', 'position', 5, 'type', 'project', 'estimated_minutes', 90)
        ))

      )
    ),

    jsonb_build_object(
      'id', gen_random_uuid(), 'title', 'Phase 3: Advanced & Reliability', 'description', 'Advanced — Weeks 11-16, pick based on need', 'position', 2, 'estimated_weeks', 6,
      'milestones', jsonb_build_array(

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Reliability & Resilience', 'description', null, 'position', 0, 'estimated_hours', 8, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Circuit breaker pattern', 'description', 'Hystrix, resilience4j', 'position', 0, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Bulkhead & retry logic', 'description', 'Timeout, exponential backoff', 'position', 1, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'SLA / SLO / SLI', 'description', null, 'position', 2, 'type', 'reading', 'estimated_minutes', 30),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Chaos engineering', 'description', 'Chaos Monkey, fault injection', 'position', 3, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Disaster recovery', 'description', 'RTO, RPO, geo-redundancy', 'position', 4, 'type', 'reading', 'estimated_minutes', 45)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Observability', 'description', null, 'position', 1, 'estimated_hours', 6, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Distributed tracing', 'description', 'Jaeger, Zipkin, OpenTelemetry', 'position', 0, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Metrics & alerting', 'description', 'Prometheus, Grafana', 'position', 1, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Structured logging', 'description', 'ELK stack, correlation IDs', 'position', 2, 'type', 'reading', 'estimated_minutes', 30),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Rate limiting', 'description', 'Token bucket, leaky bucket', 'position', 3, 'type', 'reading', 'estimated_minutes', 30)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Security in Design', 'description', null, 'position', 2, 'estimated_hours', 6, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Auth patterns', 'description', 'OAuth2, JWT, SAML, SSO', 'position', 0, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Zero-trust architecture', 'description', null, 'position', 1, 'type', 'reading', 'estimated_minutes', 30),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'API security', 'description', 'RBAC, secrets management', 'position', 2, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Data encryption', 'description', 'At-rest, in-transit, KMS', 'position', 3, 'type', 'reading', 'estimated_minutes', 30)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Low-Level Design (LLD)', 'description', null, 'position', 3, 'estimated_hours', 8, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'SOLID principles', 'description', null, 'position', 0, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design patterns', 'description', 'Factory, Strategy, Observer, Decorator', 'position', 1, 'type', 'reading', 'estimated_minutes', 60),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'LLD: Parking lot / Elevator', 'description', null, 'position', 2, 'type', 'project', 'estimated_minutes', 90),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'LLD: Rate limiter / Cache', 'description', null, 'position', 3, 'type', 'project', 'estimated_minutes', 90)
        ))

      )
    ),

    jsonb_build_object(
      'id', gen_random_uuid(), 'title', 'Phase 4: Cloud & Infrastructure', 'description', 'Weeks 17-20, pick based on need', 'position', 3, 'estimated_weeks', 4,
      'milestones', jsonb_build_array(

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Cloud-Native Architecture', 'description', null, 'position', 0, 'estimated_hours', 8, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'AWS / GCP / Azure fundamentals', 'description', 'EC2, S3, VPC', 'position', 0, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Container orchestration', 'description', 'Docker, Kubernetes, Helm', 'position', 1, 'type', 'reading', 'estimated_minutes', 60),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Serverless architecture', 'description', 'Lambda, Cloud Functions', 'position', 2, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Infrastructure as Code', 'description', 'Terraform, Pulumi, CDK', 'position', 3, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Service mesh', 'description', 'Istio, Envoy, sidecar', 'position', 4, 'type', 'reading', 'estimated_minutes', 45)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Data & Storage at Scale', 'description', null, 'position', 1, 'estimated_hours', 6, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Data warehouses', 'description', 'BigQuery, Redshift, Snowflake', 'position', 0, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Data lakes', 'description', 'S3+Athena, Delta Lake', 'position', 1, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Object storage design', 'description', 'HDFS concepts, blob storage', 'position', 2, 'type', 'reading', 'estimated_minutes', 30),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Time-series databases', 'description', 'InfluxDB, TimescaleDB', 'position', 3, 'type', 'reading', 'estimated_minutes', 30)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'CI/CD & DevOps', 'description', null, 'position', 2, 'estimated_hours', 4, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'CI/CD pipelines', 'description', 'GitHub Actions, Jenkins', 'position', 0, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Blue-green / canary deploys', 'description', null, 'position', 1, 'type', 'reading', 'estimated_minutes', 30),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Feature flags', 'description', 'LaunchDarkly, phased rollout', 'position', 2, 'type', 'reading', 'estimated_minutes', 30)
        ))

      )
    ),

    jsonb_build_object(
      'id', gen_random_uuid(), 'title', 'Phase 5: AI Fundamentals & RAG', 'description', 'Weeks 21-23, pick based on need', 'position', 4, 'estimated_weeks', 3,
      'milestones', jsonb_build_array(

        jsonb_build_object('id', gen_random_uuid(), 'title', 'LLM Fundamentals for Engineers', 'description', null, 'position', 0, 'estimated_hours', 8, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Transformer architecture', 'description', 'Attention, embeddings, tokens', 'position', 0, 'type', 'reading', 'estimated_minutes', 60),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'LLM inference pipeline', 'description', 'Tokenization -> decode -> output', 'position', 1, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Context windows & KV cache', 'description', null, 'position', 2, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Model serving / vLLM / TGI', 'description', 'Batching, quantization, VRAM', 'position', 3, 'type', 'reading', 'estimated_minutes', 60),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Prompt engineering', 'description', 'Zero-shot, few-shot, CoT, ReAct', 'position', 4, 'type', 'reading', 'estimated_minutes', 45)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'RAG', 'description', null, 'position', 1, 'estimated_hours', 9, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Vector databases', 'description', 'Pinecone, Qdrant, pgvector, FAISS', 'position', 0, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Embedding models', 'description', 'Dimensions, similarity search', 'position', 1, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Chunking strategies', 'description', 'Semantic vs fixed, chunk size', 'position', 2, 'type', 'reading', 'estimated_minutes', 30),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Hybrid search', 'description', 'BM25+vector, reranking', 'position', 3, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'RAG evaluation', 'description', 'Faithfulness, answer relevance, RAGAS', 'position', 4, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Advanced RAG patterns', 'description', 'HyDE, self-query, parent-child chunks', 'position', 5, 'type', 'reading', 'estimated_minutes', 45)
        ))

      )
    ),

    jsonb_build_object(
      'id', gen_random_uuid(), 'title', 'Phase 6: AI Agents & Production Systems', 'description', 'Weeks 24-26, pick based on need', 'position', 5, 'estimated_weeks', 3,
      'milestones', jsonb_build_array(

        jsonb_build_object('id', gen_random_uuid(), 'title', 'AI Agents & Orchestration', 'description', null, 'position', 0, 'estimated_hours', 8, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Agent architecture', 'description', 'Tool use, memory, planning loops', 'position', 0, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'LangChain / LlamaIndex', 'description', 'Orchestration frameworks', 'position', 1, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Multi-agent systems', 'description', 'AutoGen, CrewAI patterns', 'position', 2, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'MCP protocol', 'description', 'Model Context Protocol, tool servers', 'position', 3, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Agentic memory', 'description', 'Short/long-term, episodic', 'position', 4, 'type', 'reading', 'estimated_minutes', 30)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'AI Infrastructure & Production', 'description', null, 'position', 1, 'estimated_hours', 8, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Fine-tuning vs RAG', 'description', 'LoRA/QLoRA', 'position', 0, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'LLM gateway design', 'description', 'Rate limiting, fallback, routing', 'position', 1, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Guardrails & safety layers', 'description', 'I/O filtering, PII masking', 'position', 2, 'type', 'reading', 'estimated_minutes', 45),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'AI observability', 'description', 'LangSmith, Helicone, token tracking', 'position', 3, 'type', 'reading', 'estimated_minutes', 30),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Cost optimization', 'description', 'Caching LLM calls, model tiering', 'position', 4, 'type', 'reading', 'estimated_minutes', 30)
        )),

        jsonb_build_object('id', gen_random_uuid(), 'title', 'Designing AI-Powered Systems', 'description', null, 'position', 2, 'estimated_hours', 10, 'modules', jsonb_build_array(
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design an AI chatbot', 'description', 'RAG+memory+streaming', 'position', 0, 'type', 'project', 'estimated_minutes', 90),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design a recommendation engine', 'description', 'Embeddings+real-time inference', 'position', 1, 'type', 'project', 'estimated_minutes', 90),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design a code assistant', 'description', 'IDE integration, context window', 'position', 2, 'type', 'project', 'estimated_minutes', 90),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'Design a document Q&A system', 'description', 'Ingestion pipeline+RAG', 'position', 3, 'type', 'project', 'estimated_minutes', 90),
          jsonb_build_object('id', gen_random_uuid(), 'title', 'ML platform design', 'description', 'Feature store, model registry, serving', 'position', 4, 'type', 'project', 'estimated_minutes', 90)
        ))

      )
    )

  ))
)
ON CONFLICT (id) DO UPDATE SET structure = EXCLUDED.structure, updated_at = now();
