# AI Personalized Roadmaps

User states a goal ("become job-ready backend engineer in 12 weeks", "master DSA for interviews") and the AI generates a structured learning path: **phases → milestones → modules**. Where a generated module matches something that already exists in MindForge (a course, a lab, a coding/DSA question), it links directly to it so the roadmap is clickable, not just a reading list.

---

## Overview

- **GENERATED mode**: the normal path — AI produces the full phase/milestone/module tree from a goal + profile inputs.
- **DEFINED mode**: same schema, but a roadmap that was hand-edited into existence by renaming/reordering/deleting on top of a generated tree rather than staying purely AI-authored. There is no from-scratch manual builder — DEFINED is what a GENERATED roadmap becomes once the user starts editing it.
- **Status lifecycle**: `generating` → `active` (or `failed` on AI/parse error) → `completed` (all modules done) / `archived` (user-hidden, not deleted).
- Generation runs **async** through the existing job queue (`internal/jobs`), the same pattern `course_outline` uses — the frontend polls `GET /api/roadmaps/:id` until `status` leaves `generating`.
- **AI called once per (re)generation**, result persisted — never regenerated on read.

---

## Personalization Input

Defaults are pre-filled from `user_profiles` (already collected at onboarding): `learning_goal`, `career_goal`, `skill_level`, `topics_interest`, `weekly_time_commitment`, `years_of_experience`. The create form lets the user override any of these per-roadmap (a roadmap's goal doesn't have to match the profile's general goal).

---

## Public Roadmaps ("Discover")

An owner can flag their own `active`/`completed` roadmap `is_public = true` (their choice to share it — no admin curation step). Any authenticated user can browse `GET /api/roadmaps/public` and **start** one via `POST /api/roadmaps/:id/start`, which forks it into a brand-new roadmap they own — active immediately, no AI call, no wait.

Forking never copies catalog links verbatim: courses/labs/questions are org-scoped catalogs, so a resource the original creator's org can see may not exist or be visible to the forking user's org. `RematchForOrg` (`matcher.go`) re-runs the exact same title-matching pass generation uses, scoped to the new owner's org, and discards the source's links. A public roadmap is a leaderboard of good goal → structure combinations, not a mechanism for leaking org-private catalog links across tenants.

---

## Catalog Matching

After the AI returns the phase/milestone/module structure, each module is best-effort matched against real MindForge content so it becomes actionable instead of a floating text item:

| `module_type` | Matched against | Visibility filter |
|---|---|---|
| `course` | `courses.title`/`tags` | `status='published' AND (is_public OR org_id = caller's org)` |
| `lab` | `lab_definitions.title` | `is_published AND org_id = caller's org` |
| `dsa_problem` | `questions.title`/`tags` where `type='coding'` | `status='active' AND org_id = caller's org` |
| `project`, `reading`, `quiz` | no catalog to match against | always unmatched — stays a plain checklist item |

Matching uses trigram similarity (`pg_trgm`, already available via Postgres) over title, scoped by tag overlap where the AI supplies tags. Below a confidence threshold, the module is left unmatched (`resource_type`/`resource_id` NULL) rather than guessing — a wrong link is worse than no link. **The AI never invents a URL or resource name**; the system prompt explicitly forbids it (`ai.RoadmapSystemPrompt`). All linking is done server-side against real rows.

---

## API Endpoints

```
POST   /api/roadmaps                              body: {title?, goal_description, target_role?,
                                                          skill_level?, timeframe_weeks?, focus_areas?[]}
                                                   → creates shell (status=generating), enqueues AI job
                                                   rate-limited: 3/day per user (see interviewprep.maxPlansPerDay pattern)
GET    /api/roadmaps                              list caller's roadmaps (paginated)
GET    /api/roadmaps/public                        browse gallery of roadmaps their owners marked public
GET    /api/roadmaps/:id                          full nested detail: phases → milestones → modules + status
POST   /api/roadmaps/:id/regenerate                re-runs generation into the same roadmap
                                                   409 if status already 'generating'
POST   /api/roadmaps/:id/start                     fork a public roadmap into a new one the caller owns
                                                   — active immediately, no AI call
PATCH  /api/roadmaps/:id                           body: {title?, status?, is_public?}
                                                   -- rename / archive / reactivate / share
DELETE /api/roadmaps/:id                           soft delete (sets deleted_at)

PATCH  /api/roadmaps/:id/modules/:moduleID         body: {title?, description?, position?}
                                                   -- DEFINED-mode light edit; flips roadmap.mode to 'defined'
DELETE /api/roadmaps/:id/modules/:moduleID         remove a single module
POST   /api/roadmaps/:id/modules/:moduleID/progress body: {completed: bool}
```

All routes require auth; ownership is enforced by `user_id = claims.UserID` on every read/write — a roadmap is private to the user who created it by default (not org-shared, unlike courses) unless its owner explicitly flips `is_public`, in which case it becomes readable (never writable) by anyone via the public endpoints only.

---

## Database Schema

```sql
roadmaps (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  org_id             UUID REFERENCES organizations(id),   -- caller's active org at creation time, nullable
  title              TEXT NOT NULL,
  mode               TEXT NOT NULL DEFAULT 'generated',    -- 'generated' | 'defined'
  status             TEXT NOT NULL DEFAULT 'generating',   -- 'generating' | 'active' | 'completed' | 'archived' | 'failed'
  is_public          BOOLEAN NOT NULL DEFAULT false,        -- owner-shared to the public "Discover" gallery
  goal_description   TEXT NOT NULL,
  target_role        TEXT,
  skill_level        TEXT,
  timeframe_weeks    INT,
  focus_areas        JSONB DEFAULT '[]'::jsonb,
  generation_error   TEXT,
  generated_at       TIMESTAMPTZ,
  created_at         TIMESTAMPTZ DEFAULT now(),
  updated_at         TIMESTAMPTZ DEFAULT now(),
  deleted_at         TIMESTAMPTZ
)

roadmap_phases (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  roadmap_id         UUID NOT NULL REFERENCES roadmaps(id) ON DELETE CASCADE,
  title              TEXT NOT NULL,
  description        TEXT,
  position           INT NOT NULL DEFAULT 0,
  estimated_weeks    INT,
  created_at         TIMESTAMPTZ DEFAULT now()
)

roadmap_milestones (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phase_id           UUID NOT NULL REFERENCES roadmap_phases(id) ON DELETE CASCADE,
  title              TEXT NOT NULL,
  description        TEXT,
  position           INT NOT NULL DEFAULT 0,
  estimated_hours    INT,
  created_at         TIMESTAMPTZ DEFAULT now()
)

roadmap_modules (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_id       UUID NOT NULL REFERENCES roadmap_milestones(id) ON DELETE CASCADE,
  title              TEXT NOT NULL,
  description        TEXT,
  position           INT NOT NULL DEFAULT 0,
  module_type        TEXT NOT NULL,   -- 'course' | 'lab' | 'dsa_problem' | 'project' | 'reading' | 'quiz'
  resource_type      TEXT,            -- 'course' | 'lab' | 'question' -- set only when matched
  resource_id        UUID,            -- loose ref, no FK (target table varies by resource_type)
  estimated_minutes  INT,
  completed_at       TIMESTAMPTZ,
  created_at         TIMESTAMPTZ DEFAULT now()
)
```

Indexes: `roadmaps(user_id, status) WHERE deleted_at IS NULL`, `roadmap_phases(roadmap_id, position)`, `roadmap_milestones(phase_id, position)`, `roadmap_modules(milestone_id, position)`.

---

## Edge Cases

- **AI/parse failure**: job sets `status='failed'` + `generation_error` inside the same transaction attempt rather than leaving the job to retry indefinitely into a stuck `generating` roadmap. User can retry via `regenerate`.
- **Regenerate while generating**: rejected with 409 — no concurrent generation into the same roadmap.
- **Regenerate on a DEFINED (edited) roadmap**: allowed, but replaces the entire phase/milestone/module tree (delete + reinsert in one transaction) — the user is warned client-side that manual edits will be lost.
- **Idempotency**: the job handler skips generation if the roadmap already has phases (guards against duplicate job delivery), mirroring `course_outline`'s module-count guard.
- **Ownership**: every roadmap read/write checks `user_id = claims.UserID`; a 404 (not 403) is returned on mismatch to avoid leaking existence.
- **Daily cap**: 3 roadmap creations per user per day (create + regenerate share the cap), enforced the same way as `interviewprep.maxPlansPerDay`.
