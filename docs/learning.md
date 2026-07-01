# Learning

Everything about the student learning experience: coding challenges, in-browser compiler, quiz, spaced repetition, revision plans, and certificates.

---

## Student Learning Flow

```
1. Enroll (free or paid)
2. Work through sections in order:
   └─ Read lesson / Watch video
   └─ Solve coding problem (in-browser compiler)
   └─ Take module quiz
   └─ Complete lab
3. Mentor interaction (if assigned):
   └─ Ask questions in mentor chat
   └─ Submit code for mentor review
4. Complete all sections
   └─ AI generates Revision Plan (based on quiz scores + weak modules)
   └─ Follow revision plan (spaced repetition cards resurface due items)
5. Take Final Test (when ready)
   └─ Pass → certificate issued
   └─ Fail → revision plan updated, retry allowed
```

---

## Coding Challenge UI

### Resizable Split-Pane Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  Navbar: Course > Section > Problem Title          [Submit] [Run]│
├───────────────────────┬─────────────────────────────────────────┤
│  LEFT PANEL           ║  RIGHT PANEL (top)                      │
│  (resizable)          ║  Language selector + Monaco Editor       │
│                       ║                                          │
│  Tabs:                ║  def twoSum(nums, target):               │
│  [Description]        ║      pass                                │
│  [Submissions]        ║                                          │
│  [Solutions]          ╠═════════════════════════════════════════╣
│  [Discussion]         ║  RIGHT PANEL (bottom)                   │
│                       ║  Tabs: [Test Cases] [Result] [Console]   │
│  Problem text,        ║  ✓ Test 1 passed (12ms)                  │
│  examples,            ║  ✗ Test 2 failed: expected [2,0] got []  │
│  constraints          ║                                          │
└───────────────────────┴─────────────────────────────────────────┘
```

- Resize: drag vertical divider (min 300px each side); drag horizontal divider in right panel (min 200px)
- Layout preference saved to `localStorage` per user
- Collapse left panel button for full-screen editor mode
- Mobile: stacked layout (no split pane)
- Library: `react-resizable-panels`

### Monaco Editor

- Syntax highlighting, auto-complete, bracket matching, line numbers
- Font size control; follows system dark/light theme
- `Ctrl+Enter` = Run · `Ctrl+Shift+Enter` = Submit
- **Component:** `components/shared/code-editor.tsx` — lazy-loaded via `next/dynamic` (ssr: false) with `<Skeleton>` fallback; uses `var(--font-jetbrains-mono)` from the design system
- Props: `language`, `value`, `onChange`, `readOnly`, `height`, `className`

### Run vs Submit

- **Run**: executes against visible test cases only — client-side where possible (instant, no server round-trip)
- **Submit**: executes against all test cases including hidden ones — always server-side for fairness

---

## In-Browser Compiler

Strategy: run in browser via WebAssembly wherever possible. Server only for heavy/unsafe languages.

| Language | Execution | Server Load |
|---|---|---|
| Python | Pyodide (WASM) | Zero |
| JavaScript / TypeScript | Native browser execution | Zero |
| SQL | sql.js (SQLite WASM) | Zero |
| HTML / CSS | Browser iframe sandbox | Zero |
| Go | Docker sandbox (server) | Low |
| Java | Docker sandbox (server) | Low |
| C / C++ | Docker sandbox (server) | Low |
| Rust | Docker sandbox (server) | Low |

### Client-side flow (Python/JS/SQL)

1. Student writes code in Monaco Editor
2. Code sent to Web Worker (no UI freeze)
3. WASM runtime executes code + runs test cases
4. Results returned instantly — no network round-trip

### Server-side flow (Go/Java/C++)

1. Code submitted to `POST /api/code/run`
2. Server forwards to **Piston** (`PISTON_URL`) or Judge0 (`JUDGE0_URL`) — Piston takes priority when both are set
3. Executor runs all test cases, captures stdout/stderr per case
4. Returns `RunResult` with per-case pass/fail and aggregate status
5. Rate limit: 20 submissions per user per hour

**Executor selection** (`internal/assessment/executor.go`):
- `PISTON_URL` set → `pistonExecutor` (self-hosted, free, supports 15+ languages)
- `JUDGE0_URL` set → `judge0Executor` (fallback)
- Neither set → `unavailableExecutor` — coding grading deferred to instructor manual review; MCQ unaffected

Self-host Piston: `docker run -p 2000:2000 ghcr.io/engineer-man/piston`

### Problem data format

```json
{
  "title": "Reverse a Linked List",
  "description": "Given head of linked list...",
  "difficulty": "medium",
  "starter_code": {
    "python": "def reverseList(head):\n    pass",
    "go": "func reverseList(head *ListNode) *ListNode {\n}"
  },
  "test_cases": [
    { "input": "[1,2,3,4,5]", "expected": "[5,4,3,2,1]", "is_hidden": false },
    { "input": "[1,2]", "expected": "[2,1]", "is_hidden": true }
  ],
  "time_limit_ms": 1000,
  "memory_limit_mb": 256
}
```

---

## Quiz

- Module quiz: MCQ and short answer, time-limited, scored immediately on submit
- Per-module: one quiz per module
- Attempt recorded with answers + score + pass/fail
- Results inform the AI revision plan (low-scoring modules get more revision weight)

---

## Spaced Repetition (SM-2)

Pure SM-2 algorithm — no AI, no ML. Math only.

Cards are generated per module (by AI once, then served from DB). Each card has:
- `ease_factor` (starts at 2.5)
- `interval_days` (days until next review)
- `repetitions` (number of times seen)
- `due_at` (next scheduled date)

On each review, student grades recall 0–5. SM-2 updates `ease_factor`, `interval_days`, `due_at`.

The dashboard shows all cards `due_at <= now()` as a review session.

---

## Revision Plan + Final Test + Certificates

- AI generates one revision plan per course completion (stored, never auto-regenerated)
- Plan identifies weak modules + schedules review sessions using card due dates
- Final test: time-limited MCQ + coding, must pass to receive certificate
- Certificate: issued with a unique `cert_uuid`; publicly verifiable at `/certificates/:uuid`
- Max retry attempts and passing score are configurable per course

---

## API Endpoints

```
POST /api/code/run                   body: {code, language, problem_id} → result
GET  /api/problems/:id               problem detail + starter code
GET  /api/problems/:id/submissions/me list my submissions for this problem

GET  /api/modules/:id/quiz           quiz for this module
POST /api/quiz/:id/attempt           body: {answers} → {score, total, passed}
GET  /api/quiz/:id/attempts/me       my attempt history

GET  /api/cards/due                  cards due for review today
POST /api/cards/review               body: {card_id, grade: 0-5} → updated schedule

POST /api/courses/:id/revision        generate AI revision plan (if not already exists)
GET  /api/courses/:id/revision        current revision plan

GET  /api/courses/:id/final-test      final test questions
POST /api/courses/:id/final-test/attempt  body: {answers} → {score, passed}

GET  /api/certificates/me             my certificates
GET  /api/certificates/:uuid          public verification (no auth)

POST /api/messages                   body: {recipient_id, course_id, content}
GET  /api/messages/:user_id          conversation thread with a mentor
GET  /api/mentor/students            (mentor) list assigned students

POST /api/highlights                 body: {source_type, source_id, selected_text, position_start?, position_end?, save_for_revision} → Highlight
POST /api/highlights/explain         body: {source_type, source_id, selected_text} → {highlight_id, explanation}
GET  /api/highlights/me              ?saved_only=true → [Highlight]
PATCH /api/highlights/:id/revision   body: {save_for_revision} → Highlight
GET  /api/admin/highlights/analytics ?limit=50 → [AnalyticsEntry]  (super_admin only)
```

---

## Highlight Flow

Students can highlight text in any wiki page, lesson, or coding problem description.

### DB Tables
- `highlights` — per-user text selection anchors (source_type, source_id, selected_text, text_hash, saved_for_revision)
- `highlight_explanations` — shared AI explanation cache keyed by `hash(text + source_type)`. `serve_count` tracks how many times each explanation was served (token-savings analytics).

### Cache key
`SHA-256(normalize(selected_text) + "|" + source_type)` — same text in the same surface type (e.g., all wiki pages) shares one cached explanation. Same text in a lesson vs a wiki page gets separate context-aware explanations.

### Assessment restriction
The `HighlightProvider` component must **not** be mounted on assessment attempt pages. `source_type` does not accept `"assessment"` (DB CHECK constraint enforces this). AI assist during a live exam is cheating.

### Frontend
- `<HighlightProvider sourceType="lesson" sourceId={id}>` wraps any reading surface
- On text selection: `HighlightPopup` appears with "Save for revision" and "Explain now"
- "Explain now" → cached or fresh AI explanation in `ExplanationPanel` (bottom-right slide-up)
- Saved highlights visible at `/highlights` (My Saved Highlights page)

### Analytics
`GET /api/admin/highlights/analytics` returns top N most-served explanations, ranked by `serve_count` — shows which concepts students find most confusing.

---

## Database Schema

```sql
coding_problems (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  module_id       UUID NOT NULL REFERENCES course_modules(id) ON DELETE CASCADE,
  title           TEXT NOT NULL,
  description     TEXT NOT NULL,
  difficulty      TEXT,
  starter_code    JSONB NOT NULL DEFAULT '{}',  -- {language: code}
  test_cases      JSONB NOT NULL DEFAULT '[]',
  time_limit_ms   INT NOT NULL DEFAULT 1000,
  memory_limit_mb INT NOT NULL DEFAULT 256
)

coding_submissions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id),
  problem_id  UUID NOT NULL REFERENCES coding_problems(id),
  code        TEXT NOT NULL,
  language    TEXT NOT NULL,
  status      TEXT NOT NULL,  -- 'pending' | 'running' | 'passed' | 'failed' | 'error'
  result      JSONB,
  runtime_ms  INT,
  memory_mb   INT,
  created_at  TIMESTAMPTZ DEFAULT now()
)

quizzes (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  module_id             UUID NOT NULL REFERENCES course_modules(id) ON DELETE CASCADE,
  questions             JSONB NOT NULL,
  time_limit_minutes    INT,
  passing_score_percent INT NOT NULL DEFAULT 70
)

quiz_attempts (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id),
  quiz_id      UUID NOT NULL REFERENCES quizzes(id),
  answers      JSONB NOT NULL,
  score        INT NOT NULL,
  total        INT NOT NULL,
  passed       BOOLEAN NOT NULL,
  completed_at TIMESTAMPTZ DEFAULT now()
)

cards (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  module_id     UUID NOT NULL REFERENCES course_modules(id) ON DELETE CASCADE,
  front         TEXT NOT NULL,
  back          TEXT NOT NULL,
  ease_factor   FLOAT NOT NULL DEFAULT 2.5,
  interval_days INT NOT NULL DEFAULT 1,
  repetitions   INT NOT NULL DEFAULT 0,
  due_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at    TIMESTAMPTZ DEFAULT now()
)

revision_plans (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id),
  course_id    UUID NOT NULL REFERENCES courses(id),
  plan         JSONB NOT NULL,
  generated_at TIMESTAMPTZ DEFAULT now()
)

final_tests (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id             UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  questions             JSONB NOT NULL,
  time_limit_minutes    INT NOT NULL,
  passing_score_percent INT NOT NULL DEFAULT 70,
  max_attempts          INT NOT NULL DEFAULT 3
)

final_test_attempts (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES users(id),
  final_test_id     UUID NOT NULL REFERENCES final_tests(id),
  answers           JSONB NOT NULL,
  score             INT NOT NULL,
  total             INT NOT NULL,
  passed            BOOLEAN NOT NULL,
  completed_at      TIMESTAMPTZ DEFAULT now()
)

certificates (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES users(id),
  course_id             UUID NOT NULL REFERENCES courses(id),
  final_test_attempt_id UUID NOT NULL REFERENCES final_test_attempts(id),
  issued_at             TIMESTAMPTZ DEFAULT now(),
  cert_uuid             UUID NOT NULL UNIQUE DEFAULT gen_random_uuid()
)

mentor_profiles (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id   UUID NOT NULL UNIQUE REFERENCES users(id),
  bio       TEXT,
  expertise TEXT[],
  available BOOLEAN NOT NULL DEFAULT true
)

mentor_assignments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mentor_id   UUID NOT NULL REFERENCES users(id),
  student_id  UUID NOT NULL REFERENCES users(id),
  course_id   UUID NOT NULL REFERENCES courses(id),
  assigned_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (mentor_id, student_id, course_id)
)

mentor_messages (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id    UUID NOT NULL REFERENCES users(id),
  recipient_id UUID NOT NULL REFERENCES users(id),
  course_id    UUID NOT NULL REFERENCES courses(id),
  content      TEXT NOT NULL,
  read_at      TIMESTAMPTZ,
  created_at   TIMESTAMPTZ DEFAULT now()
)
```
