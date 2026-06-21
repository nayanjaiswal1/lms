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
  'Dev Instructor',
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

INSERT INTO batch_members (id, batch_id, user_id)
VALUES (
  '00000000-0000-0000-0000-000000000131',
  '00000000-0000-0000-0000-000000000130',
  '00000000-0000-0000-0000-000000000014'
)
ON CONFLICT (id) DO NOTHING;

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
  crypt('Admin123!', gen_salt('bf', 12)),
  'user',
  true
)
ON CONFLICT (email) DO NOTHING;

INSERT INTO org_members (id, org_id, user_id, role)
SELECT gen_random_uuid(), '00000000-0000-0000-0000-000000000001', id, 'learner'
FROM users WHERE email = 'jaiswal2062@gmail.com'
ON CONFLICT (org_id, user_id) DO NOTHING;

INSERT INTO batch_members (id, batch_id, user_id)
SELECT gen_random_uuid(), '00000000-0000-0000-0000-000000000130', id
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
