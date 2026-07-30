# Interview Experiences

Crowd-sourced interview experience board: company/position-tagged posts, multi-user continuation, threaded Q&A discussion, voting.

---

## Overview

Users post an interview experience (company, position, language/framework tags). Anyone can append additional rounds to an existing experience ("continue add exp" — e.g. someone else who interviewed for the same role adds their onsite round to the thread). Q&A pairs can hang off a specific round, **or directly off the post with no round at all** — a bare "what's asked at Google onsite for L4 backend" question doesn't need a full round-by-round narrative wrapped around it. Any Q&A or comment can be replied to at unlimited depth (nested discussion), and answers/comments can be upvoted/downvoted.

**Visibility:** unlike most MindForge content, interview experiences are platform-wide (cross-org), not org-siloed — a "Google Backend Engineer" thread is useful to every org's students, not just one tenant's. This deviates from the `org_id`-on-every-table convention (see `docs/overview.md`); tables below carry no `org_id`.

**LinkedIn ingestion:** manual, not automated. User pastes LinkedIn post text into Claude Code chat; Claude parses it and creates/updates the relevant experience via the API (same pattern as the `fold-in-notes` skill). No in-app parser.

**Naming note:** this is unrelated to `docs/interview.md` (live mock-interview board / Yjs coding pad). Tables and permission code are named `interview_exp*` / `content.interview_exp` to avoid collision with that feature's `interview_sessions` / `content.interview_board`.

---

## Data Model

```sql
interview_exp_posts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id     UUID NOT NULL REFERENCES users(id),
  company       TEXT NOT NULL,
  position      TEXT NOT NULL,
  tags          TEXT[] NOT NULL DEFAULT '{}',   -- language/framework e.g. {'react','node'}
  title         TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at    TIMESTAMPTZ
);
CREATE INDEX ON interview_exp_posts (company, position);
CREATE INDEX ON interview_exp_posts USING GIN (tags);

interview_exp_entries (   -- OPTIONAL round/continuation added by the original author or anyone else.
                          -- A post can have zero entries and just carry standalone Q&A (see below).
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id       UUID NOT NULL REFERENCES interview_exp_posts(id) ON DELETE CASCADE,
  author_id     UUID NOT NULL REFERENCES users(id),
  round_label   TEXT NOT NULL,          -- 'Phone Screen', 'Onsite Round 2', ...
  content       TEXT NOT NULL,          -- plain text narrative (not TipTap JSON — no rich formatting need for v1)
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at    TIMESTAMPTZ
);
CREATE INDEX ON interview_exp_entries (post_id);

interview_exp_qna (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id       UUID NOT NULL REFERENCES interview_exp_posts(id) ON DELETE CASCADE,
  entry_id      UUID REFERENCES interview_exp_entries(id) ON DELETE CASCADE,  -- NULL = standalone question on the post, not tied to a specific round
  author_id     UUID NOT NULL REFERENCES users(id),
  question      TEXT NOT NULL,
  answer        TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at    TIMESTAMPTZ
);
CREATE INDEX ON interview_exp_qna (post_id);
CREATE INDEX ON interview_exp_qna (entry_id) WHERE entry_id IS NOT NULL;

interview_exp_comments (   -- unlimited-depth nesting via self-reference (wiki_comments caps at 1 level; this doesn't)
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  qna_id        UUID NOT NULL REFERENCES interview_exp_qna(id) ON DELETE CASCADE,
  parent_id     UUID REFERENCES interview_exp_comments(id) ON DELETE CASCADE,
  author_id     UUID NOT NULL REFERENCES users(id),
  content       TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at    TIMESTAMPTZ
);
CREATE INDEX ON interview_exp_comments (qna_id, parent_id);

interview_exp_votes (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id),
  target_type   TEXT NOT NULL CHECK (target_type IN ('qna', 'comment')),
  target_id     UUID NOT NULL,
  value         SMALLINT NOT NULL CHECK (value IN (-1, 1)),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, target_type, target_id)
);
```

Vote score = `SUM(value)` computed on read, grouped by `(target_type, target_id)`. No denormalized counter column. *(ponytail: query-time aggregation; add a denormalized score column only if this measurably shows up as a bottleneck.)*

---

## API

Backend package `backend/internal/interviewexp/` — same 5-file layout as `wiki`: `handler.go`, `models.go`, `repo.go`, `service.go`, `routes.go`. Wired into `api/router.go` the same way.

| Method | Path | Notes |
|---|---|---|
| GET | `/api/interview-exp/posts` | list, filter by `company`, `position`, `tag`, free-text search |
| POST | `/api/interview-exp/posts` | create post |
| GET | `/api/interview-exp/posts/:id` | detail: entries + qna + comment trees + vote scores |
| POST | `/api/interview-exp/posts/:id/entries` | add a round to an existing post — any member, not just the author |
| POST | `/api/interview-exp/posts/:id/qna` | add a standalone Q&A pair directly on the post, no round |
| POST | `/api/interview-exp/entries/:id/qna` | add a Q&A pair scoped to a specific round |
| POST | `/api/interview-exp/qna/:id/comments` | add comment; `parent_id` optional for nesting |
| POST | `/api/interview-exp/vote` | body `{target_type, target_id, value}`; `value: 0` clears the caller's vote (upsert on the unique key) |
| PATCH/DELETE | `/api/interview-exp/{entries,qna,comments}/:id` | author-only edit / soft delete |

Response envelope, auth, and error handling follow the existing `httputil.WriteJSON` / `apiGet`/`apiAction` conventions used by wiki and courses.

---

## RBAC

New permission `content.interview_exp` (`docs/rbac.md` §3 pattern), granted to the `member` role by default — any authenticated user can post, add entries, comment, and vote. No org-scoped check on read (public), but writes still require an authenticated `member`+ role in *some* org (reuses existing auth middleware, just skips the `org_id` filter on queries).

---

## Frontend

```
frontend/app/(app)/interview-exp/
  page.tsx              -- list + filters (company/position/tag chips, search)
  [id]/page.tsx          -- detail: entries timeline, Q&A with nested comment threads, vote buttons
  new/page.tsx           -- create form: "Ask a question" (post + standalone qna) or "Share an experience" (post + first round entry) — same post row either way, just whether an entry gets created up front
frontend/lib/interview-exp/
  types.ts, hooks.ts, queries.ts   -- mirrors lib/wiki/
```

Entry `content` is a plain `<Textarea>`, not TipTap — a round write-up doesn't need rich formatting for v1; revisit if requested. Comment threading is a small recursive client component (arbitrary depth, unlike wiki's 1-level cap); `VoteButtons` is a new small up/down-arrow component.

---

## Frequently Asked Questions Page

`/interview-exp/faq` — a cross-post aggregate of every Q&A on the platform, styled and behaved like the Sheet Tracker (`docs/sheets` equivalent): grouped by topic (primary tag), each item shows an overall + per-tag progress bar, and every question gets the same todo → done → revisit status cycle Sheets uses (`sheet_items`/`user_problem_progress` pattern), plus a star toggle. "Frequency" is approximated by vote score (the community signal we already have) rather than duplicate-text detection across posts — that would need fuzzy text matching and isn't worth the complexity for v1.

This is a new table scoped to `interview_exp_qna` directly, **not** a mirrored/synced `sheet_items` row — the two content types (curated DSA problems vs. organically-created interview questions) are different enough that forcing them through one polymorphic table would need sync jobs and awkward joins. Reusing the *pattern* (status enum, cycle order, progress bar markup) instead of the *table* avoids that coupling.

```sql
interview_exp_qna_progress (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  qna_id        UUID NOT NULL REFERENCES interview_exp_qna(id) ON DELETE CASCADE,
  status        TEXT NOT NULL DEFAULT 'todo' CHECK (status IN ('todo', 'done', 'revisit')),
  is_starred    BOOLEAN NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, qna_id)
);
```

No SRS-style revision scheduling (no `revision_at`/`review_count`/growth scheme) — that's Sheets' spaced-repetition layer, out of scope here; only the 3-state status + star, matching what was asked for.

| Method | Path | Notes |
|---|---|---|
| GET | `/api/interview-exp/faq` | every qna platform-wide, joined with post company/position/tags, vote score, and the caller's own progress/star — filterable by `company`, `tag`, `status` |
| PATCH | `/api/interview-exp/faq/:qnaId/progress` | body `{status}`, upserts the caller's progress row |
| PATCH | `/api/interview-exp/faq/:qnaId/star` | body `{starred}` |

Frontend: `app/(app)/interview-exp/faq/page.tsx`, grouped by `tags[0]` into collapsible sections (uncategorized bucket for posts with no tags), each with a `.progress-track`/`.progress-fill` bar like `sheets/[slug]/page.tsx`; row status cycle button reuses the exact `NEXT_STATUS`/`STATUS_ICON`/`STATUS_CLASS` shape from `sheet-table-row.tsx`.

## Build Phases

1. Migration — 5 tables above + indexes + `content.interview_exp` RBAC seed row
2. Backend — `interviewexp` package, wired into router
3. Frontend — list/detail/new pages, nested comment UI, vote buttons
4. LinkedIn ingestion — no code; Claude creates/updates posts directly via the API when the user pastes content in chat (same as `fold-in-notes`)
5. FAQ page — `interview_exp_qna_progress` migration, `/api/interview-exp/faq` endpoints, `/interview-exp/faq` page grouped by tag with Sheets-style progress tracking
