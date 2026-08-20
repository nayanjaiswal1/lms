# Project Marketplace (Design Draft — not yet built)

Extends the existing `project_assignments` / `project_teams` / `project_checkpoints` system
(`backend/internal/gitlab`, batches 1–6) with a marketplace layer in front of it, and a
lightweight day-to-day task board + AI code-review layer on top of it.

**What already exists and is reused as-is:** GitLab team provisioning, checkpoints with
MR/CI gating and grading, contribution dashboards, leaderboards, burndown, originality
(plagiarism) detection, handoff-to-student. None of that is rebuilt.

**What's new:** requirement postings, student applications, AI-assisted matching, team
task board, voting on design/architecture proposals, AI MR-review comments, and a
completion showcase page.

---

## Decisions locked in

| Question | Decision |
|---|---|
| Who posts a requirement | Org staff/mentors only (same trust level as course creation) |
| AI matching input | GitHub OAuth (public repo/contribution/language data) + student-uploaded resume/portfolio. **No LinkedIn/social scraping** — no public API, violates ToS |
| Workflow scope | Both: SDLC gates (requirement doc, design review, architecture review, MR review) as new `project_checkpoints` kinds; day-to-day task assignment as a new lightweight task board, separate from graded checkpoints |
| AI code automation | Review/comment only — AI never opens commits or pushes code. Feature-ownership signal comes from existing mirrored `gitlab_commits` authorship data (no AI call needed for that part) |

Open question to confirm before Phase A ships: does final team selection need a human
(staff) approval step after AI ranks applicants, or should AI selection be authoritative?
Defaulting to **staff approves AI's shortlist** (matches "role middleware everywhere" /
no-fully-autonomous-decisions posture) unless you say otherwise.

---

## Phase A — Requirement board + applications + AI shortlist

New tables:

- `project_requirements` — org_id, title, brief, required_skills (text[]), team_size_min/max,
  application_deadline, status (draft/open/closed/matched/archived), created_by, optional
  batch_id/course_id link
- `project_applications` — requirement_id, user_id, motivation, status
  (submitted/shortlisted/selected/rejected), ai_score, ai_rationale, applied_at
- `user_external_profiles` — user_id, github_username, github_oauth_token (encrypted),
  resume_storage_key, portfolio_url — one-time connect, reused across applications

Flow: staff opens a requirement → students browse an open board and apply → on deadline,
an AI job scores each applicant (GitHub signal + resume text vs. `required_skills`) →
staff reviews the AI-ranked shortlist and confirms the team → confirming creates a
`project_assignment` + `project_team` + `project_team_members` via the **existing**
provisioning path, unchanged.

## Phase B — SDLC checkpoints + task board + voting

- Add `kind` enum to `project_checkpoints` (`requirement_doc`, `design_review`,
  `architecture_review`, `mr_review`, `milestone`) — reuses all existing MR/CI-gating and
  grading columns, no new submission machinery
- `project_design_proposals` + `project_design_votes` — team members submit UI/architecture
  proposals, vote, top proposal becomes the checkpoint's accepted submission
- `project_tasks` — team_id, checkpoint_id (nullable), title, assignee_user_id, status
  (todo/in_progress/review/done), due_at — day-to-day work items, ungraded, distinct from
  checkpoints

## Phase C — AI MR review + showcase page

- On GitLab MR webhook, one AI call per MR (cached by SHA — "AI called once" rule) posts a
  quality/style comment back to the MR via GitLab API. No auto-commit, no auto-merge.
- Feature-ownership view: aggregate existing `gitlab_commits` by file path per author —
  pure aggregation, not an AI call, same pattern as `repo_dashboard.go`'s contribution rollups
- Showcase page: composes existing `AssignmentDashboardView` / `TeamDashboardSummary` /
  checkpoints / originality report with the new application history and task-board
  completion — no new aggregation tables, a new handler joining what already exists

---

## Sequencing note

Phase A is the only phase that needs genuinely new infrastructure (external OAuth,
resume parsing, AI scoring job). Phases B and C are additive columns/tables on top of the
existing project domain and are each a normal 1–4 file Sonnet-tier change once A exists.
