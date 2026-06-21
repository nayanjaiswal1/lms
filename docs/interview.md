# Interview Board + Load Test

Everything about the live technical interview environment and the HTTP load test tool: flows, real-time sync, API endpoints, and database schema.

---

## Interview Board

### Overview

Interviewer creates a session, candidate joins via short link (no account needed), and both collaborate in real-time on a shared coding pad and system design canvas. Everything is saved for post-interview review.

### Live Session UI

```
┌───────────────────────────────────────────────────────────────────────┐
│  Interview: URL Shortener Design — Alice (interviewer) & Bob (cand.)  │
├───────────────────────────┬───────────────────────────────────────────┤
│  QUESTIONS (left panel)   │  MAIN AREA (tabs)                         │
│                           │  [Code Editor]  [System Design]           │
│  1. Intro + Problem       │                                           │
│  2. ► Two Sum (coding)    │  Language: [Python ▾]                     │
│  3.   URL Shortener (SD)  │                                           │
│  4.   Behavioral          │  def twoSum(nums, target):                │
│                           │      # Bob is typing here...             │
│  [+ Add Question]         │      pass                                 │
│  [From Bank]              │                                           │
│                           │  Alice sees Bob's cursor in real time     │
│  ─────────────────────    │                                           │
│  Notes (Q2):              ├───────────────────────────────────────────┤
│  [Good approach, missed   │  INTERVIEWER NOTES (right gutter)         │
│   edge case for empty     │  Score Q2: [★★★☆☆]                       │
│   array]                  │  Note: [good approach, missed edge case]  │
│                           │                                           │
│  Score: [3 / 5]           │  [End Question] [Next Question]           │
└───────────────────────────┴───────────────────────────────────────────┘
```

### Real-Time Sync (Yjs over WebSocket)

Both users connect to `WS /ws/interview/:id` (token delivered via POST, not query string). The server is a message relay hub — no transformation needed, just broadcasts Yjs CRDT messages to all participants.

| Y.js type | Synced to | Purpose |
|---|---|---|
| `Y.Text("code")` | Monaco Editor | Shared code — every keystroke synced |
| `Y.Map("canvas")` | React Flow | Shared nodes + edges |
| `Y.Map("cursor")` | Overlay | Each user's cursor position |

When the interviewer switches questions, the current code + canvas snapshot is saved to `interview_session_questions` and the Yjs doc resets for the next question.

### WebSocket Token

WS token is issued via `POST /api/interviews/join/:code/start` and returned in the response body. Client sends it in the `Sec-WebSocket-Protocol` header — never in the query string (query strings appear in logs).

### Question Bank

| Type | What candidate sees |
|---|---|
| `coding` | Problem prompt in left panel + shared Monaco editor |
| `system_design` | Design prompt in left panel + shared React Flow canvas |
| `behavioral` | Question text only; no editor |
| `conceptual` | Question text only; no editor |

Platform ships with a built-in bank. Org admins and instructors can add org-specific questions.

### Scorecard (Post-Interview)

| Dimension | Score |
|---|---|
| Communication | 1–5 |
| Problem Solving | 1–5 |
| Code Quality | 1–5 |
| System Design | 1–5 |
| Overall Notes | free text |
| Verdict | `strong_hire` · `hire` · `hold` · `no_hire` |

### Candidate Experience (No Account Needed)

1. Interviewer shares `/interview/join/ABC123`
2. Candidate opens link → sees session title + interviewer name
3. Clicks "Join" → enters live session
4. Session ends → "Thank you" page

The `join_code` is the candidate's credential for that session only. No account, no email, no registration.

---

## Load Test Simulator

### Mode 1 — Real HTTP Load Test

Fires real HTTP traffic from the platform backend to a target API.

```
Target URL:   https://my-api.example.com/api/users
Method:       GET
Headers:      Authorization: Bearer xxx
RPS:          50
Duration:     30s
Concurrency:  10
```

Results after completion:
```
p50: 42ms   p95: 180ms   p99: 450ms
Errors: 3 (0.2%)   Throughput: 49.8 req/s

Latency over time (chart — Recharts):
██░░░░░░░░░░░░░░ p50
█████░░░░░░░░░░░ p95 ← spike at 15s
████████░░░░░░░░ p99
```

**Safety rules (server-enforced):**
- Max 100 RPS, max 60s duration
- Blocks private IP ranges, localhost, and cloud metadata endpoint (see `infrastructure.md` for full SSRF denylist)
- DNS resolved → all IPs validated → connection pinned to validated IP → redirects re-validated
- Rate limit: 3 concurrent runs per user
- UI warning: "This sends real HTTP traffic. Only test systems you own."

Implementation: Go goroutine pool bounded by `concurrency`. Each goroutine fires requests, records latency. After run, p50/p95/p99 computed from sorted samples. Results stored in `load_test_runs.result` JSONB.

### Mode 2 — Canvas Traffic Animation

On any system design canvas, activate "Traffic Simulation" mode:

1. Select a node as the traffic source (e.g., Browser)
2. Set RPS (e.g., 1000 req/s)
3. Click "Simulate"

Animations (client-side only, no real HTTP):
- **Animated edge particles** flow along connections
- **Node heat color** — nodes receiving high traffic turn orange/red
- **Bottleneck detection** — if incoming RPS exceeds configured threshold → pulses red + "Bottleneck" badge

---

## API Endpoints

```
-- Sessions (interviewer manages)
POST   /api/interviews                           (instructor | org_admin)
                                                 body: {title, candidate_email, scheduled_at?, question_ids[]?}
GET    /api/interviews                           list my sessions as interviewer
GET    /api/interviews/:id                       session + questions + scorecard
PATCH  /api/interviews/:id                       body: {status?, scheduled_at?, title?}
DELETE /api/interviews/:id

-- Candidate join (no auth)
GET    /api/interviews/join/:code                {title, interviewer_name, status, scheduled_at}
POST   /api/interviews/join/:code/start          marks session 'live'; returns ws_token in body

-- WebSocket
WS     /ws/interview/:id                         Yjs relay; ws_token in Sec-WebSocket-Protocol header

-- Questions within a session
POST   /api/interviews/:id/questions             body: {question_id?, type, title, prompt, order_index}
PATCH  /api/interviews/:id/questions/:qid        body: {code_snapshot?, code_language?,
                                                        design_snapshot?, interviewer_notes?, score?}
DELETE /api/interviews/:id/questions/:qid

-- Scorecard
POST   /api/interviews/:id/scorecard             body: {communication, problem_solving, code_quality,
                                                        system_design, overall_notes, verdict}
GET    /api/interviews/:id/scorecard

-- Question bank
GET    /api/interview-questions                  platform questions + org questions
POST   /api/interview-questions                  body: {type, title, prompt, difficulty, tags[]}
PATCH  /api/interview-questions/:id              (creator | org_admin)
DELETE /api/interview-questions/:id

-- Load test
POST   /api/load-tests                           body: {target_url, method, headers[]?, body?,
                                                        rps, duration_s, concurrency}
                                                 → returns {id, status: "pending"} immediately
GET    /api/load-tests/:id                       poll for {status, result} until status=done|failed
GET    /api/load-tests                           history of my runs (paginated)
DELETE /api/load-tests/:id                       cancel a running test
```

---

## Database Schema

```sql
interview_sessions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id           UUID REFERENCES organizations(id) ON DELETE CASCADE,
  interviewer_id   UUID NOT NULL REFERENCES users(id),
  candidate_id     UUID REFERENCES users(id),    -- NULL if external candidate
  candidate_email  TEXT,
  title            TEXT NOT NULL,
  status           TEXT NOT NULL DEFAULT 'scheduled',  -- 'scheduled' | 'live' | 'completed' | 'cancelled'
  join_code        TEXT NOT NULL UNIQUE,
  scheduled_at     TIMESTAMPTZ,
  started_at       TIMESTAMPTZ,
  ended_at         TIMESTAMPTZ,
  created_at       TIMESTAMPTZ DEFAULT now()
)

interview_questions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      UUID REFERENCES organizations(id) ON DELETE CASCADE,  -- NULL = platform-wide
  type        TEXT NOT NULL,   -- 'coding' | 'system_design' | 'behavioral' | 'conceptual'
  title       TEXT NOT NULL,
  prompt      TEXT NOT NULL,
  difficulty  TEXT,
  tags        TEXT[],
  created_by  UUID REFERENCES users(id),
  created_at  TIMESTAMPTZ DEFAULT now()
)

interview_session_questions (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id        UUID NOT NULL REFERENCES interview_sessions(id) ON DELETE CASCADE,
  question_id       UUID REFERENCES interview_questions(id),  -- NULL if ad-hoc
  type              TEXT NOT NULL,
  title             TEXT NOT NULL,
  prompt            TEXT NOT NULL,
  order_index       INT NOT NULL DEFAULT 0,
  code_snapshot     TEXT,
  code_language     TEXT,
  design_snapshot   JSONB,
  interviewer_notes TEXT,
  score             INT,    -- 1–5
  created_at        TIMESTAMPTZ DEFAULT now()
)

interview_scorecards (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id      UUID NOT NULL UNIQUE REFERENCES interview_sessions(id) ON DELETE CASCADE,
  communication   INT,
  problem_solving INT,
  code_quality    INT,
  system_design   INT,
  overall_notes   TEXT,
  verdict         TEXT,    -- 'strong_hire' | 'hire' | 'no_hire' | 'hold'
  submitted_at    TIMESTAMPTZ DEFAULT now()
)

load_test_runs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id),
  org_id       UUID REFERENCES organizations(id),
  target_url   TEXT NOT NULL,
  method       TEXT NOT NULL DEFAULT 'GET',
  headers      JSONB,
  body         TEXT,
  rps          INT NOT NULL,
  duration_s   INT NOT NULL,
  concurrency  INT NOT NULL DEFAULT 10,
  status       TEXT NOT NULL DEFAULT 'pending',  -- 'pending' | 'running' | 'done' | 'failed'
  result       JSONB,   -- {total, errors, p50_ms, p95_ms, p99_ms, throughput, timeline:[{t,rps,p95}]}
  error        TEXT,
  started_at   TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at   TIMESTAMPTZ DEFAULT now()
)
```
