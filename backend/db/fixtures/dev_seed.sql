-- Consolidated dev fixtures: non-course seed data in one idempotent file.
-- Order: base org/users, role grants, role test accounts, GitLab teams,
-- habits, system sheet. Course content lives in *.generated.sql.

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║ merged from fixtures/dev_seed.sql
-- ╚══════════════════════════════════════════════════════════════════════╝

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
INSERT INTO content_assignments (id, content_type, content_id, assignee_type, assignee_id, assigned_by)
VALUES (
  '00000000-0000-0000-0000-000000000140',
  'assessment',
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

INSERT INTO assessments (id, org_id, title, slug, type, parent_type, status, duration_minutes, pass_percentage, max_attempts, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by)
VALUES ('00000000-0000-0000-0000-000000000540', '00000000-0000-0000-0000-000000000001', 'Go practice', 'seed-go-practice', 'practice', 'standalone', 'active', 1, 0, 1, false, false, false, false, '00000000-0000-0000-0000-000000000015')
ON CONFLICT (id) DO NOTHING;

INSERT INTO assessment_attempts (id, assessment_id, user_id, org_id, attempt_number, status, started_at, submitted_at)
VALUES ('00000000-0000-0000-0000-000000000500', '00000000-0000-0000-0000-000000000540', '00000000-0000-0000-0000-000000000015', '00000000-0000-0000-0000-000000000001', 1, 'in_progress', now() - interval '2 days', NULL)
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

INSERT INTO assessments (id, org_id, title, slug, type, parent_type, status, duration_minutes, pass_percentage, max_attempts, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by)
VALUES ('00000000-0000-0000-0000-000000000541', '00000000-0000-0000-0000-000000000001', 'Go, PostgreSQL, Distributed Systems practice', 'seed-go-postgresql-distributed-systems-practice', 'practice', 'standalone', 'active', 1, 0, 1, false, false, false, false, '00000000-0000-0000-0000-000000000015')
ON CONFLICT (id) DO NOTHING;

INSERT INTO assessment_attempts (id, assessment_id, user_id, org_id, attempt_number, status, started_at, submitted_at)
VALUES ('00000000-0000-0000-0000-000000000501', '00000000-0000-0000-0000-000000000541', '00000000-0000-0000-0000-000000000015', '00000000-0000-0000-0000-000000000001', 1, 'submitted', now() - interval '2 days', now() - interval '2 days')
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

INSERT INTO assessments (id, org_id, title, slug, type, parent_type, status, duration_minutes, pass_percentage, max_attempts, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by)
VALUES ('00000000-0000-0000-0000-000000000542', '00000000-0000-0000-0000-000000000001', 'Stakeholder Management, Prioritization, Roadmapping practice', 'seed-stakeholder-management-practice', 'practice', 'standalone', 'active', 1, 0, 1, false, false, false, false, '00000000-0000-0000-0000-000000000015')
ON CONFLICT (id) DO NOTHING;

INSERT INTO assessment_attempts (id, assessment_id, user_id, org_id, attempt_number, status, started_at, submitted_at)
VALUES ('00000000-0000-0000-0000-000000000502', '00000000-0000-0000-0000-000000000542', '00000000-0000-0000-0000-000000000015', '00000000-0000-0000-0000-000000000001', 1, 'submitted', now() - interval '2 days', now() - interval '2 days')
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

-- ─── Practice items for the three sessions above ───────────────────────────
-- A practice item is questions -> question_versions -> assessment_questions
-- (owns `position`) -> attempt_answers, exactly as practice.Repo.InsertItems
-- writes it. Idempotent: a session that already has answers is skipped.

DO $$
DECLARE
  s record;
  q text;
  i int;
  qid uuid;
  vid uuid;
  aqid uuid;
BEGIN
  FOR s IN
    SELECT * FROM (VALUES
      ('00000000-0000-0000-0000-000000000500'::uuid, '00000000-0000-0000-0000-000000000540'::uuid,
        ARRAY['What is a goroutine and how does the scheduler run it?', 'When would you pick a buffered channel over an unbuffered one?', 'How does context cancellation propagate?']),
      ('00000000-0000-0000-0000-000000000501'::uuid, '00000000-0000-0000-0000-000000000541'::uuid,
        ARRAY['How do you choose between a B-tree and a GIN index in PostgreSQL?', 'Explain how a quorum read/write keeps replicas consistent.']),
      ('00000000-0000-0000-0000-000000000502'::uuid, '00000000-0000-0000-0000-000000000542'::uuid,
        ARRAY['Tell me about a time you pushed back on a stakeholder request.', 'How do you prioritise when everything is urgent?'])
    ) AS t(attempt_id, assessment_id, questions)
  LOOP
    CONTINUE WHEN EXISTS (SELECT 1 FROM attempt_answers WHERE attempt_id = s.attempt_id);
    i := 0;
    FOREACH q IN ARRAY s.questions LOOP
      INSERT INTO questions (org_id, type, title, created_by)
      VALUES ('00000000-0000-0000-0000-000000000001', 'interview_prep', left(q, 500), '00000000-0000-0000-0000-000000000015')
      RETURNING id INTO qid;
      INSERT INTO question_versions (question_id, version, content, created_by)
      VALUES (qid, 1, jsonb_build_object('question_text', q), '00000000-0000-0000-0000-000000000015')
      RETURNING id INTO vid;
      INSERT INTO assessment_questions (assessment_id, question_id, version_id, position)
      VALUES (s.assessment_id, qid, vid, i)
      RETURNING id INTO aqid;
      INSERT INTO attempt_answers (attempt_id, assessment_question_id, question_id, answer)
      VALUES (s.attempt_id, aqid, qid, jsonb_build_object('question_text', q));
      i := i + 1;
    END LOOP;
  END LOOP;
END $$;

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


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║ merged from fixtures/grant_all_roles_jaiswal.sql
-- ╚══════════════════════════════════════════════════════════════════════╝

-- Grant jaiswal2062@gmail.com every role and permission on the platform.
-- Safe to run multiple times (all writes are idempotent).
--
-- Notes on the org_members role column:
--   owner > admin > instructor > mentor > student
--   The enforce_last_owner trigger blocks demoting the last active owner.
--   We only upgrade non-owner members — owners are already the highest.
--
-- Notes on user_roles (RBAC):
--   Requires migrations 016 + 017. The block below is guarded by a table
--   existence check so this file stays safe to run before those migrations.
--
-- Notes on feature grants:
--   Feature grants are permission rows coded "features.<key>" in the
--   permissions table, held per-user via user_permission_overrides (see
--   backend/internal/features/repo.go GrantedFeatureKeys). There is no
--   separate feature_grants table.

-- 1. Platform-level: elevate to super_admin
UPDATE users
SET    platform_role = 'super_admin',
       email_verified = true,
       updated_at     = now()
WHERE  email = 'jaiswal2062@gmail.com';

-- 2. Org-level: add to the default org as owner if not already a member
INSERT INTO org_members (org_id, user_id, role)
SELECT '00000000-0000-0000-0000-000000000001',
       u.id,
       'owner'
FROM   users u
WHERE  u.email = 'jaiswal2062@gmail.com'
ON CONFLICT (org_id, user_id) DO NOTHING;

-- 3. Org-level: upgrade non-owner memberships to admin
--    (owners are not touched — demoting the last owner is blocked by trigger)
UPDATE org_members
SET    role = 'admin'
WHERE  user_id = (SELECT id FROM users WHERE email = 'jaiswal2062@gmail.com')
  AND  role NOT IN ('owner');

-- 4. RBAC: assign every system role per org (only if migrations 016+017 applied)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_roles'
  ) THEN
    INSERT INTO user_roles (user_id, role_id, org_id)
    SELECT u.id,
           r.id,
           om.org_id
    FROM   users u
    JOIN   org_members om ON om.user_id = u.id
    CROSS  JOIN roles r
    WHERE  u.email = 'jaiswal2062@gmail.com'
      AND  r.is_system = true
    ON CONFLICT DO NOTHING;
  END IF;
END $$;

-- 5. Feature grants: personal features with no org/plan concept
INSERT INTO user_permission_overrides (user_id, org_id, permission_id, granted_by)
SELECT u.id,
       om.org_id,
       p.id,
       u.id
FROM   users u
JOIN   org_members om ON om.user_id = u.id
CROSS  JOIN permissions p
WHERE  u.email = 'jaiswal2062@gmail.com'
  AND  p.code IN ('features.what_now', 'features.revision_digest', 'content.captures')
  AND  p.is_active = true
ON CONFLICT (user_id, org_id, permission_id) DO NOTHING;

-- 6. Revision digest and Knowledge Captures are meant to stay exclusive to
--    jaiswal (beta, no plan/add-on concept) — revoke any grant another user picked up
--    (manual testing, a stale seed) every time this fixture runs, so a
--    stray grant never survives a reseed.
DELETE FROM user_permission_overrides upo
USING  permissions p, users u
WHERE  upo.permission_id = p.id
  AND  upo.user_id = u.id
  AND  p.code IN ('features.revision_digest', 'content.captures')
  AND  u.email <> 'jaiswal2062@gmail.com';


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║ merged from fixtures/seed_role_test_accounts.sql
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ══════════════════════════════════════════════════════════════════════════
-- seed_role_test_accounts.sql — One dedicated dev login per RBAC system role
-- ══════════════════════════════════════════════════════════════════════════
-- Five accounts, each holding exactly one system RBAC role (unlike
-- grant_all_roles_jaiswal.sql, which grants jaiswal2062@gmail.com every
-- role on one account). Useful for testing role-gated UI/API in isolation.
-- All writes are idempotent — safe to run multiple times.
--
-- Login:  jaiswal2062+<role>@gmail.com / 123
--   jaiswal2062+viewer@gmail.com       -> viewer
--   jaiswal2062+member@gmail.com       -> member
--   jaiswal2062+instructor@gmail.com   -> instructor
--   jaiswal2062+mentor@gmail.com       -> mentor
--   jaiswal2062+tenant_admin@gmail.com -> tenant_admin

-- ─── Users ────────────────────────────────────────────────────────────────────

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES ('00000000-0000-0000-0000-000000000030', 'jaiswal2062+viewer@gmail.com', 'Test Viewer',
        crypt('123', gen_salt('bf', 12)), 'user', true)
ON CONFLICT (email) DO UPDATE SET password_hash = crypt('123', gen_salt('bf', 12)), updated_at = now();

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES ('00000000-0000-0000-0000-000000000031', 'jaiswal2062+member@gmail.com', 'Test Member',
        crypt('123', gen_salt('bf', 12)), 'user', true)
ON CONFLICT (email) DO UPDATE SET password_hash = crypt('123', gen_salt('bf', 12)), updated_at = now();

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES ('00000000-0000-0000-0000-000000000032', 'jaiswal2062+instructor@gmail.com', 'Test Instructor',
        crypt('123', gen_salt('bf', 12)), 'user', true)
ON CONFLICT (email) DO UPDATE SET password_hash = crypt('123', gen_salt('bf', 12)), updated_at = now();

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES ('00000000-0000-0000-0000-000000000033', 'jaiswal2062+mentor@gmail.com', 'Test Mentor',
        crypt('123', gen_salt('bf', 12)), 'user', true)
ON CONFLICT (email) DO UPDATE SET password_hash = crypt('123', gen_salt('bf', 12)), updated_at = now();

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES ('00000000-0000-0000-0000-000000000034', 'jaiswal2062+tenant_admin@gmail.com', 'Test Tenant Admin',
        crypt('123', gen_salt('bf', 12)), 'user', true)
ON CONFLICT (email) DO UPDATE SET password_hash = crypt('123', gen_salt('bf', 12)), updated_at = now();

-- ─── Org membership (coarse org_members.role) ────────────────────────────────
-- org_members.role only accepts owner/admin/instructor/mentor/learner — viewer
-- and member both map to the closest coarse role, 'learner'.

INSERT INTO org_members (id, org_id, user_id, role)
VALUES ('00000000-0000-0000-0000-000000000040', '00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000030', 'learner')
ON CONFLICT (org_id, user_id) DO NOTHING;

INSERT INTO org_members (id, org_id, user_id, role)
VALUES ('00000000-0000-0000-0000-000000000041', '00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000031', 'learner')
ON CONFLICT (org_id, user_id) DO NOTHING;

INSERT INTO org_members (id, org_id, user_id, role)
VALUES ('00000000-0000-0000-0000-000000000042', '00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000032', 'instructor')
ON CONFLICT (org_id, user_id) DO NOTHING;

INSERT INTO org_members (id, org_id, user_id, role)
VALUES ('00000000-0000-0000-0000-000000000043', '00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000033', 'mentor')
ON CONFLICT (org_id, user_id) DO NOTHING;

INSERT INTO org_members (id, org_id, user_id, role)
VALUES ('00000000-0000-0000-0000-000000000044', '00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000034', 'admin')
ON CONFLICT (org_id, user_id) DO NOTHING;

-- ─── Fine-grained RBAC (user_roles) — exactly one system role each ───────────

INSERT INTO user_roles (user_id, role_id, org_id)
VALUES ('00000000-0000-0000-0000-000000000030', '11111111-1111-1111-1111-000000000001', '00000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id, org_id)
VALUES ('00000000-0000-0000-0000-000000000031', '11111111-1111-1111-1111-000000000002', '00000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id, org_id)
VALUES ('00000000-0000-0000-0000-000000000032', '11111111-1111-1111-1111-000000000003', '00000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id, org_id)
VALUES ('00000000-0000-0000-0000-000000000033', '11111111-1111-1111-1111-000000000004', '00000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO user_roles (user_id, role_id, org_id)
VALUES ('00000000-0000-0000-0000-000000000034', '11111111-1111-1111-1111-000000000005', '00000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║ merged from fixtures/gitlab_integration_seed.sql
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ══════════════════════════════════════════════════════════════════════════
-- gitlab_integration_seed.sql — Batch 2 (Teams & provisioning) fixture
-- ══════════════════════════════════════════════════════════════════════════
-- Seeds MindForge's own project_assignments/project_teams/project_team_members
-- rows only, so the /projects UI has a real draft assignment + roster to
-- publish through the app. Reuses dev_seed.sql's default org
-- (00000000-0000-0000-0000-000000000001), instructor
-- (...-000000000012, "Nayan Jaiswal") and its existing dev student
-- (...-000000000014) — run dev_seed.sql first if starting from an empty
-- database. Three additional student users are added here (one goes on the
-- solo team, two more join the dev student on the multi-member team) using a
-- dedicated a1000000-... UUID block that cannot collide with dev_seed.sql's
-- own 00000000-...-0NNN/1NN/5NN ranges. All writes are idempotent
-- (ON CONFLICT ... DO NOTHING) — safe to run multiple times, and safe to run
-- before or after dev_seed.sql.
--
-- IMPORTANT CAVEAT: this fixture seeds MindForge's own tables only — it
-- cannot fake GitLab-side state (a real forked repo, subgroup, protected
-- branch, or synced membership). Those only come into existence once the
-- gitlab.provision_team job actually runs against a real or self-hosted-
-- sandbox GitLab instance, which only happens when a staff user publishes
-- this assignment for real through the UI/API (POST .../publish) — that is
-- the point of leaving the assignment in status='draft' here rather than
-- hand-inserting a fake "ready" provision_status. Before publishing for
-- real, an admin must first connect an org GitLab installation
-- (POST /api/gitlab/installations) and this assignment's template_project_path
-- must point at a real template repo that installation can see.
--
-- Login for the three new students: password Admin123! (same as dev_seed.sql).

-- ─── Additional student users (a1000000 block) ─────────────────────────────

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES (
  'a1000000-0000-0000-0000-000000000001',
  'gitlab-student1@mindforge.dev',
  'GitLab Test Student One',
  crypt('Admin123!', gen_salt('bf', 12)),
  'user',
  true
)
ON CONFLICT (email) DO NOTHING;

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES (
  'a1000000-0000-0000-0000-000000000002',
  'gitlab-student2@mindforge.dev',
  'GitLab Test Student Two',
  crypt('Admin123!', gen_salt('bf', 12)),
  'user',
  true
)
ON CONFLICT (email) DO NOTHING;

INSERT INTO users (id, email, name, password_hash, platform_role, email_verified)
VALUES (
  'a1000000-0000-0000-0000-000000000003',
  'gitlab-student3@mindforge.dev',
  'GitLab Test Student Three',
  crypt('Admin123!', gen_salt('bf', 12)),
  'user',
  true
)
ON CONFLICT (email) DO NOTHING;

-- ─── Org membership ─────────────────────────────────────────────────────────

INSERT INTO org_members (id, org_id, user_id, role)
VALUES
  ('a1000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'learner'),
  ('a1000000-0000-0000-0000-000000000012', '00000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000002', 'learner'),
  ('a1000000-0000-0000-0000-000000000013', '00000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000003', 'learner')
ON CONFLICT (org_id, user_id) DO NOTHING;

-- ─── Batch ───────────────────────────────────────────────────────────────────

INSERT INTO batches (id, org_id, name, slug, description, mentor_id, created_by)
VALUES (
  'a1000000-0000-0000-0000-000000000030',
  '00000000-0000-0000-0000-000000000001',
  'GitLab Projects Cohort 2026', 'gitlab-projects-cohort-2026',
  'Dev fixture batch for the GitLab integration Batch 2 (project assignments/teams/provisioning) feature.',
  '00000000-0000-0000-0000-000000000013',
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO batch_members (batch_id, user_id)
VALUES
  ('a1000000-0000-0000-0000-000000000030', '00000000-0000-0000-0000-000000000014'),
  ('a1000000-0000-0000-0000-000000000030', 'a1000000-0000-0000-0000-000000000001'),
  ('a1000000-0000-0000-0000-000000000030', 'a1000000-0000-0000-0000-000000000002'),
  ('a1000000-0000-0000-0000-000000000030', 'a1000000-0000-0000-0000-000000000003')
ON CONFLICT (batch_id, user_id) DO NOTHING;

-- ─── Project assignment (draft — publish for real through the UI) ─────────
-- template_project_path is a placeholder; point it at a real template repo
-- path your GitLab installation can see before publishing this assignment.

INSERT INTO project_assignments (
  id, org_id, batch_id, title, slug, description,
  template_project_path, visibility, required_approvals,
  protect_default_branch, default_branch, status, created_by
)
VALUES (
  'a1000000-0000-0000-0000-000000000040',
  '00000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000030',
  'Capstone: REST API Service', 'capstone-rest-api-service',
  'Dev fixture assignment — each team forks the template into their own subgroup project and submits checkpoints via merge request.',
  'mindforge-templates/capstone-rest-api-starter',
  'private', 1, true, 'main', 'draft',
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (id) DO NOTHING;

-- ─── Teams: one solo, one multi-member ─────────────────────────────────────

INSERT INTO project_teams (id, org_id, assignment_id, name, slug, provision_status, created_by)
VALUES (
  'a1000000-0000-0000-0000-000000000050',
  '00000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000040',
  'Solo — Student One', 'solo-student-one',
  'pending',
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO project_teams (id, org_id, assignment_id, name, slug, provision_status, created_by)
VALUES (
  'a1000000-0000-0000-0000-000000000051',
  '00000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000040',
  'Team Byte Bandits', 'team-byte-bandits',
  'pending',
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (id) DO NOTHING;

-- Solo team: gitlab-student1 only.
INSERT INTO project_team_members (team_id, user_id, assignment_id, role, gitlab_access_level, sync_status, added_by)
VALUES (
  'a1000000-0000-0000-0000-000000000050',
  'a1000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000040',
  'lead', 40, 'pending',
  '00000000-0000-0000-0000-000000000012'
)
ON CONFLICT (team_id, user_id) DO NOTHING;

-- Multi-member team: dev student (lead) + the other two new students.
INSERT INTO project_team_members (team_id, user_id, assignment_id, role, gitlab_access_level, sync_status, added_by)
VALUES
  ('a1000000-0000-0000-0000-000000000051', '00000000-0000-0000-0000-000000000014', 'a1000000-0000-0000-0000-000000000040', 'lead', 40, 'pending', '00000000-0000-0000-0000-000000000012'),
  ('a1000000-0000-0000-0000-000000000051', 'a1000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000040', 'member', 30, 'pending', '00000000-0000-0000-0000-000000000012'),
  ('a1000000-0000-0000-0000-000000000051', 'a1000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000040', 'member', 30, 'pending', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (team_id, user_id) DO NOTHING;


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║ merged from fixtures/habits_seed_jaiswal.sql
-- ╚══════════════════════════════════════════════════════════════════════╝

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


-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║ merged from fixtures/leetcode-150-roadmap.sql
-- ╚══════════════════════════════════════════════════════════════════════╝

-- LeetCode 150 Roadmap sheet fixture — 90-day plan (problems, review days, mocks)
-- generated from Downloads/Copy of LeetCode_150_Roadmap.xlsx.
-- System sheet (is_system = true): users subscribe or fork it, see docs/sheets.md.
-- topic_tag = problem slug (overlap key), category = pattern; the day lives in metadata.
-- Safe to re-run: items are keyed by
-- deterministic id and upserted, so user progress rows are never orphaned.

DO $$
DECLARE
  v_sheet_id UUID;
BEGIN
  INSERT INTO sheets (name, slug, description, category, is_system)
  VALUES ('LeetCode 150 Roadmap', 'leetcode-150-roadmap',
          '90-day plan covering 150 LeetCode problems by pattern, with review days and a final mock.',
          'dsa', true)
  ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description,
    category = EXCLUDED.category, updated_at = now()
  RETURNING id INTO v_sheet_id;

  INSERT INTO sheet_items (id, sheet_id, title, topic_tag, category, difficulty, external_url, order_index, metadata)
  VALUES
  ('47df551d-a002-5da2-9d2c-6d096c6524ec', v_sheet_id, 'Contains Duplicate', 'contains-duplicate', 'Arrays', 'easy', 'https://leetcode.com/problems/contains-duplicate/', 0, '{"day": 1}'::jsonb),
  ('fbf62a0d-006e-583d-bd73-4933ab9b6a96', v_sheet_id, 'Product of Array Except Self', 'product-of-array-except-self', 'Arrays', 'medium', 'https://leetcode.com/problems/product-of-array-except-self/', 1, '{"day": 1}'::jsonb),
  ('04ab4d95-2a0e-5dd6-9d29-0bb019dea276', v_sheet_id, 'Valid Sudoku', 'valid-sudoku', 'Arrays', 'medium', 'https://leetcode.com/problems/valid-sudoku/', 2, '{"day": 1}'::jsonb),
  ('f4881bfa-c50d-5463-8234-44a8b6755781', v_sheet_id, 'Valid Anagram', 'valid-anagram', 'Hashing', 'easy', 'https://leetcode.com/problems/valid-anagram/', 3, '{"day": 2}'::jsonb),
  ('90c96149-7d3b-55b7-8db2-ab286f64d041', v_sheet_id, 'Two Sum', 'two-sum', 'Hashing', 'easy', 'https://leetcode.com/problems/two-sum/', 4, '{"day": 2}'::jsonb),
  ('3e8d34f9-f797-5388-aaa5-c3296f16cb1d', v_sheet_id, 'Group Anagrams', 'group-anagrams', 'Hashing', 'medium', 'https://leetcode.com/problems/group-anagrams/', 5, '{"day": 2}'::jsonb),
  ('561a7d6a-9651-565a-b2c6-561d00316cd7', v_sheet_id, 'Top K Frequent Elements', 'top-k-frequent-elements', 'Hashing', 'medium', 'https://leetcode.com/problems/top-k-frequent-elements/', 6, '{"day": 3}'::jsonb),
  ('7f04d78d-73ea-522b-a369-bcc60905240f', v_sheet_id, 'Longest Consecutive Sequence', 'longest-consecutive-sequence', 'Hashing', 'medium', 'https://leetcode.com/problems/longest-consecutive-sequence/', 7, '{"day": 3}'::jsonb),
  ('57a861ca-2fbe-507b-8fb6-98cd4b9866ca', v_sheet_id, 'Subarray Sum Equals K', 'subarray-sum-equals-k', 'Hashing', 'medium', 'https://leetcode.com/problems/subarray-sum-equals-k/', 8, '{"day": 4}'::jsonb),
  ('243005df-3dbc-5171-b567-1b35c2bb7e1f', v_sheet_id, 'Valid Palindrome', 'valid-palindrome', 'Two Pointers', 'easy', 'https://leetcode.com/problems/valid-palindrome/', 9, '{"day": 5}'::jsonb),
  ('441f230c-e246-5d01-b0fd-b92fcfd0188f', v_sheet_id, 'Two Sum II - Input Array Is Sorted', 'two-sum-ii-input-array-is-sorted', 'Two Pointers', 'medium', 'https://leetcode.com/problems/two-sum-ii-input-array-is-sorted/', 10, '{"day": 5}'::jsonb),
  ('13efb8a8-7d45-588c-bb00-10fbb54af43e', v_sheet_id, 'Sort Colors', 'sort-colors', 'Two Pointers', 'medium', 'https://leetcode.com/problems/sort-colors/', 11, '{"day": 6}'::jsonb),
  ('ecf23886-241b-502e-9807-9210c2e41609', v_sheet_id, '3Sum', '3sum', 'Two Pointers', 'medium', 'https://leetcode.com/problems/3sum/', 12, '{"day": 6}'::jsonb),
  ('27afd09d-baa2-563c-bde9-042fa6d09deb', v_sheet_id, 'Review Day: redo Days 1-6', 'review-day-redo-days-1-6', 'Review', NULL, NULL, 13, '{"day": 7}'::jsonb),
  ('b4bea15f-5a5e-5eca-8319-4af544d84ac1', v_sheet_id, 'Container With Most Water', 'container-with-most-water', 'Two Pointers', 'medium', 'https://leetcode.com/problems/container-with-most-water/', 14, '{"day": 8}'::jsonb),
  ('21141272-cd4b-5d58-b59e-12756320e758', v_sheet_id, 'Trapping Rain Water', 'trapping-rain-water', 'Two Pointers', 'hard', 'https://leetcode.com/problems/trapping-rain-water/', 15, '{"day": 8}'::jsonb),
  ('aab43bb1-eb8b-5f9f-9d59-ef5cb1a8889f', v_sheet_id, 'Best Time to Buy and Sell Stock', 'best-time-to-buy-and-sell-stock', 'Sliding Window', 'easy', 'https://leetcode.com/problems/best-time-to-buy-and-sell-stock/', 16, '{"day": 9}'::jsonb),
  ('f2e09e4e-0d72-5297-90da-cef4858cb81b', v_sheet_id, 'Longest Substring Without Repeating Characters', 'longest-substring-without-repeating-characters', 'Sliding Window', 'medium', 'https://leetcode.com/problems/longest-substring-without-repeating-characters/', 17, '{"day": 9}'::jsonb),
  ('922c4656-3cde-55ae-8294-66e5c1e2b35a', v_sheet_id, 'Longest Repeating Character Replacement', 'longest-repeating-character-replacement', 'Sliding Window', 'medium', 'https://leetcode.com/problems/longest-repeating-character-replacement/', 18, '{"day": 10}'::jsonb),
  ('4e303abf-7d48-5cdb-aa8f-4a6b05825f29', v_sheet_id, 'Permutation in String', 'permutation-in-string', 'Sliding Window', 'medium', 'https://leetcode.com/problems/permutation-in-string/', 19, '{"day": 10}'::jsonb),
  ('128649a6-e7dc-5107-afcc-0e9cb369d571', v_sheet_id, 'Find All Anagrams in a String', 'find-all-anagrams-in-a-string', 'Sliding Window', 'medium', 'https://leetcode.com/problems/find-all-anagrams-in-a-string/', 20, '{"day": 11}'::jsonb),
  ('24d8e626-889b-5d64-926a-3392eb3ddb3f', v_sheet_id, 'Minimum Window Substring', 'minimum-window-substring', 'Sliding Window', 'hard', 'https://leetcode.com/problems/minimum-window-substring/', 21, '{"day": 11}'::jsonb),
  ('17ea91c4-1a7d-5e8e-89ac-d656cba1717f', v_sheet_id, 'Sliding Window Maximum', 'sliding-window-maximum', 'Sliding Window', 'hard', 'https://leetcode.com/problems/sliding-window-maximum/', 22, '{"day": 12}'::jsonb),
  ('8f31c3a6-9a2a-5bf9-b7b5-d4c4a9ad0c4a', v_sheet_id, 'Valid Parentheses', 'valid-parentheses', 'Stack', 'easy', 'https://leetcode.com/problems/valid-parentheses/', 23, '{"day": 13}'::jsonb),
  ('63136784-4894-56ff-bbf0-5eab1c9bda72', v_sheet_id, 'Implement Queue using Stacks', 'implement-queue-using-stacks', 'Stack', 'easy', 'https://leetcode.com/problems/implement-queue-using-stacks/', 24, '{"day": 13}'::jsonb),
  ('4d45c483-dc51-5a9f-ae4e-585890e1d2c2', v_sheet_id, 'Min Stack', 'min-stack', 'Stack', 'medium', 'https://leetcode.com/problems/min-stack/', 25, '{"day": 13}'::jsonb),
  ('6793fa60-ac88-5642-a0f5-f2f2558a180c', v_sheet_id, 'Review Day: redo Days 8-13', 'review-day-redo-days-8-13', 'Review', NULL, NULL, 26, '{"day": 14}'::jsonb),
  ('3aefa143-6173-510f-b992-13666de7b7a8', v_sheet_id, 'Evaluate Reverse Polish Notation', 'evaluate-reverse-polish-notation', 'Stack', 'medium', 'https://leetcode.com/problems/evaluate-reverse-polish-notation/', 27, '{"day": 15}'::jsonb),
  ('7524dd29-56b5-5a98-a65f-bd081ed4d37a', v_sheet_id, 'Daily Temperatures', 'daily-temperatures', 'Stack', 'medium', 'https://leetcode.com/problems/daily-temperatures/', 28, '{"day": 15}'::jsonb),
  ('d42d8233-029e-5ee4-8069-f7988fae971e', v_sheet_id, 'Generate Parentheses', 'generate-parentheses', 'Stack', 'medium', 'https://leetcode.com/problems/generate-parentheses/', 29, '{"day": 16}'::jsonb),
  ('1747947b-abf5-518b-8a50-497330b86814', v_sheet_id, 'Car Fleet', 'car-fleet', 'Stack', 'medium', 'https://leetcode.com/problems/car-fleet/', 30, '{"day": 16}'::jsonb),
  ('c932491e-6113-5a3a-bb18-3dc549ea1442', v_sheet_id, 'Largest Rectangle in Histogram', 'largest-rectangle-in-histogram', 'Stack', 'hard', 'https://leetcode.com/problems/largest-rectangle-in-histogram/', 31, '{"day": 17}'::jsonb),
  ('38acb79f-6732-5dc4-8811-b69f060f22f6', v_sheet_id, 'Binary Search', 'binary-search', 'Binary Search', 'easy', 'https://leetcode.com/problems/binary-search/', 32, '{"day": 18}'::jsonb),
  ('7716e15a-ffec-5568-a2ee-801efe680f74', v_sheet_id, 'Find First and Last Position in Sorted Array', 'find-first-and-last-position-of-element-in-sorted-array', 'Binary Search', 'medium', 'https://leetcode.com/problems/find-first-and-last-position-of-element-in-sorted-array/', 33, '{"day": 18}'::jsonb),
  ('fb699a1c-0a60-5330-a40c-0a4f93bf2169', v_sheet_id, 'Search a 2D Matrix', 'search-a-2d-matrix', 'Binary Search', 'medium', 'https://leetcode.com/problems/search-a-2d-matrix/', 34, '{"day": 19}'::jsonb),
  ('5f8cd434-d534-59f9-8bfd-f607e14bc8b5', v_sheet_id, 'Koko Eating Bananas', 'koko-eating-bananas', 'Binary Search', 'medium', 'https://leetcode.com/problems/koko-eating-bananas/', 35, '{"day": 19}'::jsonb),
  ('43926c73-e1c0-564e-a6f9-1831c7a55c79', v_sheet_id, 'Find Minimum in Rotated Sorted Array', 'find-minimum-in-rotated-sorted-array', 'Binary Search', 'medium', 'https://leetcode.com/problems/find-minimum-in-rotated-sorted-array/', 36, '{"day": 20}'::jsonb),
  ('7347fb31-a9c7-564d-9edd-01d663645ca2', v_sheet_id, 'Search in Rotated Sorted Array', 'search-in-rotated-sorted-array', 'Binary Search', 'medium', 'https://leetcode.com/problems/search-in-rotated-sorted-array/', 37, '{"day": 20}'::jsonb),
  ('d6c91592-8473-5249-ba21-3ef0d50d0ee4', v_sheet_id, 'Review Day: redo Days 15-20', 'review-day-redo-days-15-20', 'Review', NULL, NULL, 38, '{"day": 21}'::jsonb),
  ('89fcbb70-3dc6-5f8a-a5ed-dbc4f160adf2', v_sheet_id, 'Time Based Key-Value Store', 'time-based-key-value-store', 'Binary Search', 'medium', 'https://leetcode.com/problems/time-based-key-value-store/', 39, '{"day": 22}'::jsonb),
  ('0caa8ec7-3e7b-51f8-9048-430523113733', v_sheet_id, 'Median of Two Sorted Arrays', 'median-of-two-sorted-arrays', 'Binary Search', 'hard', 'https://leetcode.com/problems/median-of-two-sorted-arrays/', 40, '{"day": 22}'::jsonb),
  ('cb51c150-de0c-56e9-9b59-8c2c8f9dc434', v_sheet_id, 'Reverse Linked List', 'reverse-linked-list', 'Linked List', 'easy', 'https://leetcode.com/problems/reverse-linked-list/', 41, '{"day": 23}'::jsonb),
  ('835a452f-d5d8-5357-b9ea-4c045d0e9704', v_sheet_id, 'Merge Two Sorted Lists', 'merge-two-sorted-lists', 'Linked List', 'easy', 'https://leetcode.com/problems/merge-two-sorted-lists/', 42, '{"day": 23}'::jsonb),
  ('3bb03d47-056f-50b6-b655-49068df36c69', v_sheet_id, 'Linked List Cycle', 'linked-list-cycle', 'Linked List', 'easy', 'https://leetcode.com/problems/linked-list-cycle/', 43, '{"day": 23}'::jsonb),
  ('97768e4e-feee-5e2e-8d23-6307439cb712', v_sheet_id, 'Palindrome Linked List', 'palindrome-linked-list', 'Linked List', 'easy', 'https://leetcode.com/problems/palindrome-linked-list/', 44, '{"day": 24}'::jsonb),
  ('60e31d2b-7fd9-55c7-8888-6f1bd14c2999', v_sheet_id, 'Reorder List', 'reorder-list', 'Linked List', 'medium', 'https://leetcode.com/problems/reorder-list/', 45, '{"day": 24}'::jsonb),
  ('05b1430c-23af-5ffa-8bbe-6ad6cf6b770f', v_sheet_id, 'Remove Nth Node From End of List', 'remove-nth-node-from-end-of-list', 'Linked List', 'medium', 'https://leetcode.com/problems/remove-nth-node-from-end-of-list/', 46, '{"day": 25}'::jsonb),
  ('295f4853-ee81-5d93-9de5-d009ebb8aef3', v_sheet_id, 'Find the Duplicate Number', 'find-the-duplicate-number', 'Linked List', 'medium', 'https://leetcode.com/problems/find-the-duplicate-number/', 47, '{"day": 25}'::jsonb),
  ('b1cc5b49-ee70-5f51-8685-6d0ad5342e2a', v_sheet_id, 'Add Two Numbers', 'add-two-numbers', 'Linked List', 'medium', 'https://leetcode.com/problems/add-two-numbers/', 48, '{"day": 26}'::jsonb),
  ('76b6ca8b-a80d-5340-a89b-40739e2e3db0', v_sheet_id, 'Copy List with Random Pointer', 'copy-list-with-random-pointer', 'Linked List', 'medium', 'https://leetcode.com/problems/copy-list-with-random-pointer/', 49, '{"day": 26}'::jsonb),
  ('88e10dbd-2b7c-5d3b-ad27-23cd5dd3acfa', v_sheet_id, 'LRU Cache', 'lru-cache', 'Linked List', 'medium', 'https://leetcode.com/problems/lru-cache/', 50, '{"day": 27}'::jsonb),
  ('5dc539bd-a8e2-52ea-a495-61501dde81de', v_sheet_id, 'Merge K Sorted Lists', 'merge-k-sorted-lists', 'Linked List', 'hard', 'https://leetcode.com/problems/merge-k-sorted-lists/', 51, '{"day": 27}'::jsonb),
  ('727eb3e5-daaf-525e-b6da-fe37d0cc29e1', v_sheet_id, 'Review Day: redo Days 22-27', 'review-day-redo-days-22-27', 'Review', NULL, NULL, 52, '{"day": 28}'::jsonb),
  ('288d8564-b1f5-50c5-b890-e632c1a16335', v_sheet_id, 'Reverse Nodes in K-Group', 'reverse-nodes-in-k-group', 'Linked List', 'hard', 'https://leetcode.com/problems/reverse-nodes-in-k-group/', 53, '{"day": 29}'::jsonb),
  ('3104b07f-4e72-52a1-b31a-4513aba0922b', v_sheet_id, 'Invert Binary Tree', 'invert-binary-tree', 'Trees', 'easy', 'https://leetcode.com/problems/invert-binary-tree/', 54, '{"day": 30}'::jsonb),
  ('fcaca8f6-7c04-523e-8ab8-a04c89fc612c', v_sheet_id, 'Maximum Depth of Binary Tree', 'maximum-depth-of-binary-tree', 'Trees', 'easy', 'https://leetcode.com/problems/maximum-depth-of-binary-tree/', 55, '{"day": 30}'::jsonb),
  ('80c32778-ff82-5662-a6cf-1d03d4d60a67', v_sheet_id, 'Same Tree', 'same-tree', 'Trees', 'easy', 'https://leetcode.com/problems/same-tree/', 56, '{"day": 30}'::jsonb),
  ('a3b98c02-5a7d-5ee2-9d57-3f39fc97bce8', v_sheet_id, 'Diameter of Binary Tree', 'diameter-of-binary-tree', 'Trees', 'easy', 'https://leetcode.com/problems/diameter-of-binary-tree/', 57, '{"day": 31}'::jsonb),
  ('61d4a815-e3b5-55cb-b1e5-177da046a232', v_sheet_id, 'Balanced Binary Tree', 'balanced-binary-tree', 'Trees', 'easy', 'https://leetcode.com/problems/balanced-binary-tree/', 58, '{"day": 31}'::jsonb),
  ('d5dc7a28-3e59-5bf1-8895-cd3dcba0ca55', v_sheet_id, 'Subtree of Another Tree', 'subtree-of-another-tree', 'Trees', 'easy', 'https://leetcode.com/problems/subtree-of-another-tree/', 59, '{"day": 31}'::jsonb),
  ('ca892992-8abb-5c66-986e-870cfc01400e', v_sheet_id, 'Lowest Common Ancestor of a BST', 'lowest-common-ancestor-of-a-binary-search-tree', 'Trees', 'medium', 'https://leetcode.com/problems/lowest-common-ancestor-of-a-binary-search-tree/', 60, '{"day": 32}'::jsonb),
  ('00968822-2847-5f83-b0d6-20af5f2d1ee0', v_sheet_id, 'Binary Tree Level Order Traversal', 'binary-tree-level-order-traversal', 'Trees', 'medium', 'https://leetcode.com/problems/binary-tree-level-order-traversal/', 61, '{"day": 32}'::jsonb),
  ('f68b8e5a-a13f-578e-9e7e-9ec1ece5e3c7', v_sheet_id, 'Binary Tree Right Side View', 'binary-tree-right-side-view', 'Trees', 'medium', 'https://leetcode.com/problems/binary-tree-right-side-view/', 62, '{"day": 33}'::jsonb),
  ('a861247c-38dd-5c21-afd0-47f7954fd92a', v_sheet_id, 'Count Good Nodes in Binary Tree', 'count-good-nodes-in-binary-tree', 'Trees', 'medium', 'https://leetcode.com/problems/count-good-nodes-in-binary-tree/', 63, '{"day": 33}'::jsonb),
  ('612bddf8-7a66-5a99-9314-1d6baee9bef1', v_sheet_id, 'Validate Binary Search Tree', 'validate-binary-search-tree', 'Trees', 'medium', 'https://leetcode.com/problems/validate-binary-search-tree/', 64, '{"day": 34}'::jsonb),
  ('5da36662-90c9-52bc-85ce-4dccff928907', v_sheet_id, 'Kth Smallest Element in a BST', 'kth-smallest-element-in-a-bst', 'Trees', 'medium', 'https://leetcode.com/problems/kth-smallest-element-in-a-bst/', 65, '{"day": 34}'::jsonb),
  ('2581b5bf-a6e1-5b1d-b6f8-c0a3519a78d2', v_sheet_id, 'Review Day: redo Days 29-34', 'review-day-redo-days-29-34', 'Review', NULL, NULL, 66, '{"day": 35}'::jsonb),
  ('88ef1768-4c5a-5ba1-ab53-7ef1cf407641', v_sheet_id, 'Construct Binary Tree from Preorder and Inorder', 'construct-binary-tree-from-preorder-and-inorder-traversal', 'Trees', 'medium', 'https://leetcode.com/problems/construct-binary-tree-from-preorder-and-inorder-traversal/', 67, '{"day": 36}'::jsonb),
  ('d82ff3b3-8fc9-5799-a886-66974b1277d8', v_sheet_id, 'Binary Tree Maximum Path Sum', 'binary-tree-maximum-path-sum', 'Trees', 'hard', 'https://leetcode.com/problems/binary-tree-maximum-path-sum/', 68, '{"day": 36}'::jsonb),
  ('e531b51e-8b03-5d86-911a-956ee29df72f', v_sheet_id, 'Serialize and Deserialize Binary Tree', 'serialize-and-deserialize-binary-tree', 'Trees', 'hard', 'https://leetcode.com/problems/serialize-and-deserialize-binary-tree/', 69, '{"day": 37}'::jsonb),
  ('8799323e-db8f-5746-831c-4bc889a9f9af', v_sheet_id, 'Kth Largest Element in a Stream', 'kth-largest-element-in-a-stream', 'Heap / Priority Queue', 'easy', 'https://leetcode.com/problems/kth-largest-element-in-a-stream/', 70, '{"day": 38}'::jsonb),
  ('8fff4cc4-8425-59db-93c9-04d341019677', v_sheet_id, 'Last Stone Weight', 'last-stone-weight', 'Heap / Priority Queue', 'easy', 'https://leetcode.com/problems/last-stone-weight/', 71, '{"day": 38}'::jsonb),
  ('e7f54a78-10e5-599e-8e71-0e7f3e3757d9', v_sheet_id, 'K Closest Points to Origin', 'k-closest-points-to-origin', 'Heap / Priority Queue', 'medium', 'https://leetcode.com/problems/k-closest-points-to-origin/', 72, '{"day": 39}'::jsonb),
  ('97a58bd9-39ce-5716-b42f-4818874f2b25', v_sheet_id, 'Kth Largest Element in an Array', 'kth-largest-element-in-an-array', 'Heap / Priority Queue', 'medium', 'https://leetcode.com/problems/kth-largest-element-in-an-array/', 73, '{"day": 39}'::jsonb),
  ('0c1128c2-3b16-56fd-a729-0c1ee7b5dc82', v_sheet_id, 'Task Scheduler', 'task-scheduler', 'Heap / Priority Queue', 'medium', 'https://leetcode.com/problems/task-scheduler/', 74, '{"day": 40}'::jsonb),
  ('48c7b94e-5357-56fd-b0e4-385e5b77e3e9', v_sheet_id, 'Design Twitter', 'design-twitter', 'Heap / Priority Queue', 'medium', 'https://leetcode.com/problems/design-twitter/', 75, '{"day": 40}'::jsonb),
  ('1e6eadbf-5d99-5f9a-828a-8f56085087ef', v_sheet_id, 'Find Median from Data Stream', 'find-median-from-data-stream', 'Heap / Priority Queue', 'hard', 'https://leetcode.com/problems/find-median-from-data-stream/', 76, '{"day": 41}'::jsonb),
  ('d32d5f84-716e-5848-9969-a1161be57b76', v_sheet_id, 'Review Day: redo Days 36-41', 'review-day-redo-days-36-41', 'Review', NULL, NULL, 77, '{"day": 42}'::jsonb),
  ('5f273456-2645-5dd0-ba05-38ad38ec2069', v_sheet_id, 'Subsets', 'subsets', 'Backtracking', 'medium', 'https://leetcode.com/problems/subsets/', 78, '{"day": 43}'::jsonb),
  ('d8cc6409-01e3-5ca7-b6ce-ce2ede49956d', v_sheet_id, 'Subsets II', 'subsets-ii', 'Backtracking', 'medium', 'https://leetcode.com/problems/subsets-ii/', 79, '{"day": 43}'::jsonb),
  ('90a0f8b9-c16e-571d-a92f-abf6fba6c950', v_sheet_id, 'Combination Sum', 'combination-sum', 'Backtracking', 'medium', 'https://leetcode.com/problems/combination-sum/', 80, '{"day": 44}'::jsonb),
  ('92517500-a262-5827-a53c-5a0790f64ce2', v_sheet_id, 'Combination Sum II', 'combination-sum-ii', 'Backtracking', 'medium', 'https://leetcode.com/problems/combination-sum-ii/', 81, '{"day": 44}'::jsonb),
  ('e0db662e-b66c-5f54-b732-09c5b9d44fc7', v_sheet_id, 'Permutations', 'permutations', 'Backtracking', 'medium', 'https://leetcode.com/problems/permutations/', 82, '{"day": 45}'::jsonb),
  ('4d2275f3-1f3f-5ab9-8bb0-df66e206cd1d', v_sheet_id, 'Word Search', 'word-search', 'Backtracking', 'medium', 'https://leetcode.com/problems/word-search/', 83, '{"day": 45}'::jsonb),
  ('54662a55-b797-5a52-b59a-2f6961fdda6f', v_sheet_id, 'Palindrome Partitioning', 'palindrome-partitioning', 'Backtracking', 'medium', 'https://leetcode.com/problems/palindrome-partitioning/', 84, '{"day": 46}'::jsonb),
  ('f27c109e-ce6b-5e0a-ab3f-3e721a393c5c', v_sheet_id, 'Letter Combinations of a Phone Number', 'letter-combinations-of-a-phone-number', 'Backtracking', 'medium', 'https://leetcode.com/problems/letter-combinations-of-a-phone-number/', 85, '{"day": 46}'::jsonb),
  ('d4f346fb-aef0-5a5a-8243-b398aaa6de1e', v_sheet_id, 'N-Queens', 'n-queens', 'Backtracking', 'hard', 'https://leetcode.com/problems/n-queens/', 86, '{"day": 47}'::jsonb),
  ('796cfeee-0b7c-5155-8bac-a391b76c3478', v_sheet_id, 'Implement Trie (Prefix Tree)', 'implement-trie-prefix-tree', 'Tries', 'medium', 'https://leetcode.com/problems/implement-trie-prefix-tree/', 87, '{"day": 48}'::jsonb),
  ('364c63c5-cb28-5286-b0b1-b817f4c2aa32', v_sheet_id, 'Design Add and Search Words Data Structure', 'design-add-and-search-words-data-structure', 'Tries', 'medium', 'https://leetcode.com/problems/design-add-and-search-words-data-structure/', 88, '{"day": 48}'::jsonb),
  ('5cfa396c-27e0-5b1a-b6c8-4a6672acfeec', v_sheet_id, 'Review Day: redo Days 43-48', 'review-day-redo-days-43-48', 'Review', NULL, NULL, 89, '{"day": 49}'::jsonb),
  ('96f264f9-5666-5e70-bc4f-ba2961023885', v_sheet_id, 'Word Search II', 'word-search-ii', 'Tries', 'hard', 'https://leetcode.com/problems/word-search-ii/', 90, '{"day": 50}'::jsonb),
  ('d424c026-a142-58e4-be97-7230dc3d0e30', v_sheet_id, 'Number of Islands', 'number-of-islands', 'Graphs', 'medium', 'https://leetcode.com/problems/number-of-islands/', 91, '{"day": 50}'::jsonb),
  ('a4277507-8399-5445-8f7e-fd96cff41373', v_sheet_id, 'Max Area of Island', 'max-area-of-island', 'Graphs', 'medium', 'https://leetcode.com/problems/max-area-of-island/', 92, '{"day": 51}'::jsonb),
  ('b34c8d87-0620-5086-9247-96984369166c', v_sheet_id, 'Clone Graph', 'clone-graph', 'Graphs', 'medium', 'https://leetcode.com/problems/clone-graph/', 93, '{"day": 51}'::jsonb),
  ('44a789f8-140a-5ea6-b01a-a44352a04008', v_sheet_id, 'Number of Provinces', 'number-of-provinces', 'Graphs', 'medium', 'https://leetcode.com/problems/number-of-provinces/', 94, '{"day": 52}'::jsonb),
  ('2851fcaf-6d55-5be9-95b1-4470dd21f919', v_sheet_id, 'Rotting Oranges', 'rotting-oranges', 'Graphs', 'medium', 'https://leetcode.com/problems/rotting-oranges/', 95, '{"day": 52}'::jsonb),
  ('c3b5c256-65fe-5d20-afc2-48e4533370dd', v_sheet_id, 'Pacific Atlantic Water Flow', 'pacific-atlantic-water-flow', 'Graphs', 'medium', 'https://leetcode.com/problems/pacific-atlantic-water-flow/', 96, '{"day": 53}'::jsonb),
  ('cd03f253-dffd-5b6b-aef3-c04511e68c50', v_sheet_id, 'Surrounded Regions', 'surrounded-regions', 'Graphs', 'medium', 'https://leetcode.com/problems/surrounded-regions/', 97, '{"day": 53}'::jsonb),
  ('9076f98d-080a-5309-b774-bb6ca1a91aa3', v_sheet_id, 'Course Schedule', 'course-schedule', 'Graphs', 'medium', 'https://leetcode.com/problems/course-schedule/', 98, '{"day": 54}'::jsonb),
  ('fc2e5b26-383f-569c-a075-f21650c392cd', v_sheet_id, 'Course Schedule II', 'course-schedule-ii', 'Graphs', 'medium', 'https://leetcode.com/problems/course-schedule-ii/', 99, '{"day": 54}'::jsonb),
  ('05aed64d-c57e-5720-8af9-eeadf78382a9', v_sheet_id, 'Redundant Connection', 'redundant-connection', 'Graphs', 'medium', 'https://leetcode.com/problems/redundant-connection/', 100, '{"day": 55}'::jsonb),
  ('3d908202-4b7b-53b0-b6b8-0a407cc5afdb', v_sheet_id, 'Word Ladder', 'word-ladder', 'Graphs', 'hard', 'https://leetcode.com/problems/word-ladder/', 101, '{"day": 55}'::jsonb),
  ('0055ac67-ae78-56f5-93b1-a9711b57e541', v_sheet_id, 'Review Day: redo Days 50-55', 'review-day-redo-days-50-55', 'Review', NULL, NULL, 102, '{"day": 56}'::jsonb),
  ('d3026ca3-958a-5f5f-b37e-de0952dd9a99', v_sheet_id, 'Network Delay Time', 'network-delay-time', 'Graphs', 'medium', 'https://leetcode.com/problems/network-delay-time/', 103, '{"day": 57}'::jsonb),
  ('9f78ec86-8476-549f-8fb5-3d9c48fa4465', v_sheet_id, 'Min Cost to Connect All Points', 'min-cost-to-connect-all-points', 'Graphs', 'medium', 'https://leetcode.com/problems/min-cost-to-connect-all-points/', 104, '{"day": 57}'::jsonb),
  ('8db92ae1-1d96-5fa5-bf97-38f580a78c76', v_sheet_id, 'Cheapest Flights Within K Stops', 'cheapest-flights-within-k-stops', 'Graphs', 'medium', 'https://leetcode.com/problems/cheapest-flights-within-k-stops/', 105, '{"day": 58}'::jsonb),
  ('7976cd84-c7b5-5600-bbd2-548e411952c9', v_sheet_id, 'Swim in Rising Water', 'swim-in-rising-water', 'Graphs', 'hard', 'https://leetcode.com/problems/swim-in-rising-water/', 106, '{"day": 58}'::jsonb),
  ('e1a01b04-04b4-5de3-8397-f084625e5eaf', v_sheet_id, 'Reconstruct Itinerary', 'reconstruct-itinerary', 'Graphs', 'hard', 'https://leetcode.com/problems/reconstruct-itinerary/', 107, '{"day": 59}'::jsonb),
  ('97959e2b-349f-5293-af58-196f87693936', v_sheet_id, 'Climbing Stairs', 'climbing-stairs', 'DP - 1D', 'easy', 'https://leetcode.com/problems/climbing-stairs/', 108, '{"day": 60}'::jsonb),
  ('ddf704d0-0dd3-5fc2-ad10-553307b153db', v_sheet_id, 'Min Cost Climbing Stairs', 'min-cost-climbing-stairs', 'DP - 1D', 'easy', 'https://leetcode.com/problems/min-cost-climbing-stairs/', 109, '{"day": 60}'::jsonb),
  ('a80ddb9e-a521-54af-b7bd-9a83420b12be', v_sheet_id, 'House Robber', 'house-robber', 'DP - 1D', 'medium', 'https://leetcode.com/problems/house-robber/', 110, '{"day": 61}'::jsonb),
  ('d38413f5-1bbe-5ae6-a908-daeb2e14d66f', v_sheet_id, 'House Robber II', 'house-robber-ii', 'DP - 1D', 'medium', 'https://leetcode.com/problems/house-robber-ii/', 111, '{"day": 61}'::jsonb),
  ('44e43bc9-4251-5b11-a935-deff28621984', v_sheet_id, 'Longest Palindromic Substring', 'longest-palindromic-substring', 'DP - 1D', 'medium', 'https://leetcode.com/problems/longest-palindromic-substring/', 112, '{"day": 62}'::jsonb),
  ('652399c1-c44d-5383-96c1-b32e53948ade', v_sheet_id, 'Palindromic Substrings', 'palindromic-substrings', 'DP - 1D', 'medium', 'https://leetcode.com/problems/palindromic-substrings/', 113, '{"day": 62}'::jsonb),
  ('c19ab0a6-fe5a-5d0a-b597-378b6d140931', v_sheet_id, 'Review Day: redo Days 57-62', 'review-day-redo-days-57-62', 'Review', NULL, NULL, 114, '{"day": 63}'::jsonb),
  ('8e5802be-c070-58fa-ad5c-b9a0024f96a0', v_sheet_id, 'Decode Ways', 'decode-ways', 'DP - 1D', 'medium', 'https://leetcode.com/problems/decode-ways/', 115, '{"day": 64}'::jsonb),
  ('7a8abdfb-bac7-5a2e-9f19-ee91b0b0217e', v_sheet_id, 'Coin Change', 'coin-change', 'DP - 1D', 'medium', 'https://leetcode.com/problems/coin-change/', 116, '{"day": 64}'::jsonb),
  ('2bcc4cb2-78a6-5c82-991e-f2dd8143ef72', v_sheet_id, 'Maximum Product Subarray', 'maximum-product-subarray', 'DP - 1D', 'medium', 'https://leetcode.com/problems/maximum-product-subarray/', 117, '{"day": 65}'::jsonb),
  ('452fb57f-b4b4-5fe6-bce8-34b5627527cd', v_sheet_id, 'Word Break', 'word-break', 'DP - 1D', 'medium', 'https://leetcode.com/problems/word-break/', 118, '{"day": 65}'::jsonb),
  ('6ae5b35a-39f5-5093-9d2d-b071fe5e9aa0', v_sheet_id, 'Longest Increasing Subsequence', 'longest-increasing-subsequence', 'DP - 1D', 'medium', 'https://leetcode.com/problems/longest-increasing-subsequence/', 119, '{"day": 66}'::jsonb),
  ('645f2443-7801-5965-889d-3ba8ae97c7c6', v_sheet_id, 'Partition Equal Subset Sum', 'partition-equal-subset-sum', 'DP - 1D', 'medium', 'https://leetcode.com/problems/partition-equal-subset-sum/', 120, '{"day": 66}'::jsonb),
  ('5d6e8aa7-39b9-569e-8d6c-c3428762e5ef', v_sheet_id, 'Unique Paths', 'unique-paths', 'DP - 2D', 'medium', 'https://leetcode.com/problems/unique-paths/', 121, '{"day": 67}'::jsonb),
  ('8964a439-f791-5e09-a813-790baae35411', v_sheet_id, 'Longest Common Subsequence', 'longest-common-subsequence', 'DP - 2D', 'medium', 'https://leetcode.com/problems/longest-common-subsequence/', 122, '{"day": 67}'::jsonb),
  ('7ff6011a-3f13-5e77-ab81-d159dce61f58', v_sheet_id, 'Coin Change II', 'coin-change-ii', 'DP - 2D', 'medium', 'https://leetcode.com/problems/coin-change-ii/', 123, '{"day": 68}'::jsonb),
  ('d3621505-5fb5-5418-aeb3-bd296b9f8c36', v_sheet_id, 'Target Sum', 'target-sum', 'DP - 2D', 'medium', 'https://leetcode.com/problems/target-sum/', 124, '{"day": 68}'::jsonb),
  ('7cbe5701-79ac-5c6b-b1c3-4e06d50d9842', v_sheet_id, 'Best Time to Buy and Sell Stock with Cooldown', 'best-time-to-buy-and-sell-stock-with-cooldown', 'DP - 2D', 'medium', 'https://leetcode.com/problems/best-time-to-buy-and-sell-stock-with-cooldown/', 125, '{"day": 69}'::jsonb),
  ('0c6424e8-4aff-5130-81e1-a9f420581d68', v_sheet_id, 'Edit Distance', 'edit-distance', 'DP - 2D', 'medium', 'https://leetcode.com/problems/edit-distance/', 126, '{"day": 69}'::jsonb),
  ('1ca32a9e-1468-570b-b244-a1bfdc90ecb3', v_sheet_id, 'Review Day: redo Days 64-69', 'review-day-redo-days-64-69', 'Review', NULL, NULL, 127, '{"day": 70}'::jsonb),
  ('39695bd3-a803-50fa-ae83-6f5b680e83d9', v_sheet_id, 'Interleaving String', 'interleaving-string', 'DP - 2D', 'medium', 'https://leetcode.com/problems/interleaving-string/', 128, '{"day": 71}'::jsonb),
  ('77bd6ea0-e73b-5008-9d9c-879b80012408', v_sheet_id, 'Longest Increasing Path in a Matrix', 'longest-increasing-path-in-a-matrix', 'DP - 2D', 'hard', 'https://leetcode.com/problems/longest-increasing-path-in-a-matrix/', 129, '{"day": 71}'::jsonb),
  ('26f05ec7-e085-5ce1-bb9e-43e588a1c67b', v_sheet_id, 'Distinct Subsequences', 'distinct-subsequences', 'DP - 2D', 'hard', 'https://leetcode.com/problems/distinct-subsequences/', 130, '{"day": 72}'::jsonb),
  ('b99ffcf7-2e65-5408-b172-6c23d5f10a06', v_sheet_id, 'Burst Balloons', 'burst-balloons', 'DP - 2D', 'hard', 'https://leetcode.com/problems/burst-balloons/', 131, '{"day": 72}'::jsonb),
  ('c5b87c24-e9e8-5a23-8fd1-39a016686f33', v_sheet_id, 'Regular Expression Matching', 'regular-expression-matching', 'DP - 2D', 'hard', 'https://leetcode.com/problems/regular-expression-matching/', 132, '{"day": 73}'::jsonb),
  ('81da942a-6ad0-5d6a-8a92-6acba90d5eb7', v_sheet_id, 'Maximum Subarray', 'maximum-subarray', 'Greedy', 'medium', 'https://leetcode.com/problems/maximum-subarray/', 133, '{"day": 74}'::jsonb),
  ('ba020956-2128-56d1-836f-55ce2f0b4327', v_sheet_id, 'Jump Game', 'jump-game', 'Greedy', 'medium', 'https://leetcode.com/problems/jump-game/', 134, '{"day": 74}'::jsonb),
  ('72f4a064-7a14-564a-84d5-8093c2524ad1', v_sheet_id, 'Jump Game II', 'jump-game-ii', 'Greedy', 'medium', 'https://leetcode.com/problems/jump-game-ii/', 135, '{"day": 75}'::jsonb),
  ('e3be3775-3485-5c79-bf50-73775d91a456', v_sheet_id, 'Gas Station', 'gas-station', 'Greedy', 'medium', 'https://leetcode.com/problems/gas-station/', 136, '{"day": 75}'::jsonb),
  ('0f1d4a38-7f26-54c3-9ff4-398eafd6252d', v_sheet_id, 'Hand of Straights', 'hand-of-straights', 'Greedy', 'medium', 'https://leetcode.com/problems/hand-of-straights/', 137, '{"day": 76}'::jsonb),
  ('788491fe-06e3-5eef-8513-acbd47ff36dd', v_sheet_id, 'Merge Triplets to Form Target Triplet', 'merge-triplets-to-form-target-triplet', 'Greedy', 'medium', 'https://leetcode.com/problems/merge-triplets-to-form-target-triplet/', 138, '{"day": 76}'::jsonb),
  ('e895d2e1-2d1c-5976-b444-a7f6131037a6', v_sheet_id, 'Review Day: redo Days 71-76', 'review-day-redo-days-71-76', 'Review', NULL, NULL, 139, '{"day": 77}'::jsonb),
  ('f03e76c3-d111-5075-ac87-affa43033d8c', v_sheet_id, 'Partition Labels', 'partition-labels', 'Greedy', 'medium', 'https://leetcode.com/problems/partition-labels/', 140, '{"day": 78}'::jsonb),
  ('49085dbb-5a74-5a05-902d-7a54762b37cf', v_sheet_id, 'Valid Parenthesis String', 'valid-parenthesis-string', 'Greedy', 'medium', 'https://leetcode.com/problems/valid-parenthesis-string/', 141, '{"day": 78}'::jsonb),
  ('5a2adb83-86dd-5456-8cca-6e8f988c25f0', v_sheet_id, 'Insert Interval', 'insert-interval', 'Intervals', 'medium', 'https://leetcode.com/problems/insert-interval/', 142, '{"day": 79}'::jsonb),
  ('638c4b72-5c34-5be5-8b93-eecac52fcdac', v_sheet_id, 'Merge Intervals', 'merge-intervals', 'Intervals', 'medium', 'https://leetcode.com/problems/merge-intervals/', 143, '{"day": 79}'::jsonb),
  ('a13f0049-5148-5342-9d7b-5df397cd0039', v_sheet_id, 'Non-overlapping Intervals', 'non-overlapping-intervals', 'Intervals', 'medium', 'https://leetcode.com/problems/non-overlapping-intervals/', 144, '{"day": 80}'::jsonb),
  ('640949ec-c3ca-5c37-940d-e4e3437e3abc', v_sheet_id, 'Minimum Interval to Include Each Query', 'minimum-interval-to-include-each-query', 'Intervals', 'hard', 'https://leetcode.com/problems/minimum-interval-to-include-each-query/', 145, '{"day": 80}'::jsonb),
  ('e4b33ae4-6f45-531f-9ee8-6ed72a85c9b8', v_sheet_id, 'Rotate Image', 'rotate-image', 'Math & Geometry', 'medium', 'https://leetcode.com/problems/rotate-image/', 146, '{"day": 81}'::jsonb),
  ('4947a59a-8b28-51b5-be3f-167d3d02630f', v_sheet_id, 'Spiral Matrix', 'spiral-matrix', 'Math & Geometry', 'medium', 'https://leetcode.com/problems/spiral-matrix/', 147, '{"day": 81}'::jsonb),
  ('4d1059fd-21d2-5a6b-bd12-168e4391dd78', v_sheet_id, 'Set Matrix Zeroes', 'set-matrix-zeroes', 'Math & Geometry', 'medium', 'https://leetcode.com/problems/set-matrix-zeroes/', 148, '{"day": 82}'::jsonb),
  ('539d8563-4e99-51bd-b72f-fe0f4800405c', v_sheet_id, 'Happy Number', 'happy-number', 'Math & Geometry', 'easy', 'https://leetcode.com/problems/happy-number/', 149, '{"day": 82}'::jsonb),
  ('10e95f60-3f36-50d6-9d28-927af64103e2', v_sheet_id, 'Plus One', 'plus-one', 'Math & Geometry', 'easy', 'https://leetcode.com/problems/plus-one/', 150, '{"day": 83}'::jsonb),
  ('83fc3084-a938-53d5-b22b-ebf21b2679c1', v_sheet_id, 'Pow(x, n)', 'powx-n', 'Math & Geometry', 'medium', 'https://leetcode.com/problems/powx-n/', 151, '{"day": 83}'::jsonb),
  ('042910a6-33f1-5691-bacc-154aa8039203', v_sheet_id, 'Review Day: redo Days 78-83', 'review-day-redo-days-78-83', 'Review', NULL, NULL, 152, '{"day": 84}'::jsonb),
  ('32c25f38-112a-536d-af4b-07971e4fdfbd', v_sheet_id, 'Multiply Strings', 'multiply-strings', 'Math & Geometry', 'medium', 'https://leetcode.com/problems/multiply-strings/', 153, '{"day": 85}'::jsonb),
  ('f4827311-6a50-5e0d-9957-fe680aec30f3', v_sheet_id, 'Detect Squares', 'detect-squares', 'Math & Geometry', 'medium', 'https://leetcode.com/problems/detect-squares/', 154, '{"day": 85}'::jsonb),
  ('d0ceabee-4c22-5189-b979-b0406d107f98', v_sheet_id, 'Single Number', 'single-number', 'Bit Manipulation', 'easy', 'https://leetcode.com/problems/single-number/', 155, '{"day": 86}'::jsonb),
  ('07d99653-607e-57d4-b9ef-e407dcd2759f', v_sheet_id, 'Number of 1 Bits', 'number-of-1-bits', 'Bit Manipulation', 'easy', 'https://leetcode.com/problems/number-of-1-bits/', 156, '{"day": 86}'::jsonb),
  ('7c4eabc0-a5e9-5621-87c7-b8286dba4876', v_sheet_id, 'Counting Bits', 'counting-bits', 'Bit Manipulation', 'easy', 'https://leetcode.com/problems/counting-bits/', 157, '{"day": 87}'::jsonb),
  ('9cff6729-a031-5f13-8ada-5be850568a42', v_sheet_id, 'Reverse Bits', 'reverse-bits', 'Bit Manipulation', 'easy', 'https://leetcode.com/problems/reverse-bits/', 158, '{"day": 87}'::jsonb),
  ('d3896e35-5593-5dbb-a91d-81579d97e527', v_sheet_id, 'Missing Number', 'missing-number', 'Bit Manipulation', 'easy', 'https://leetcode.com/problems/missing-number/', 159, '{"day": 88}'::jsonb),
  ('9753ec8d-f579-5b6c-be34-a129afa1425e', v_sheet_id, 'Sum of Two Integers', 'sum-of-two-integers', 'Bit Manipulation', 'medium', 'https://leetcode.com/problems/sum-of-two-integers/', 160, '{"day": 88}'::jsonb),
  ('eea5e056-8257-5949-a8f4-f0cca7834dfc', v_sheet_id, 'Reverse Integer (then redo your 5 weakest problems)', 'reverse-integer', 'Bit Manipulation', 'medium', 'https://leetcode.com/problems/reverse-integer/', 161, '{"day": 89}'::jsonb),
  ('50be48ae-98e7-565e-a34d-70d5b8a05ed3', v_sheet_id, 'Final Mock: 2 random Mediums + 1 Hard, 45 min each', 'final-mock-2-random-mediums-1-hard-45-min-each', 'Mock', NULL, NULL, 162, '{"day": 90}'::jsonb)
  ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title, topic_tag = EXCLUDED.topic_tag,
    category = EXCLUDED.category, difficulty = EXCLUDED.difficulty,
    external_url = EXCLUDED.external_url, order_index = EXCLUDED.order_index,
    metadata = EXCLUDED.metadata;
END $$;

