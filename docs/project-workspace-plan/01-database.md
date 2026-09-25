Source design: [../project-workspace.md](../project-workspace.md). Planning only — no code changed.

> **Overridden by [00-decisions.md](00-decisions.md):** D1 (own `workspace_projects` table, not extending `project_requirements`) and D2 (no `project_tasks` migration — 038/039 dropped). D19 replaces §5 migration order.


**Key decisions:**
- Extend `project_requirements` rather than adding a new table. The name `projects` is already taken (026, personal list). `project_status` NULL means a legacy marketplace-only row.
- Reuse the existing `brief` column as the raw requirement text; don't add `raw_requirement`.
- Keys come from `UPDATE … item_seq+1 RETURNING` on the project row. Composite FKs keep parents, links and tracks inside the same project.
- Split `project_tasks` into expand (038) and contract (039), with a shared idempotent backfill function, keyed by id (`work_items.id = task.id`).

**Top risks:**
1. The local DB is prod and migrations run at startup, so running any branch applies its migrations to prod.
2. Dropping `project_tasks` means creating a workspace for every classroom team, now and on every future team.
3. Having both `status` and `project_status`, plus two intake tables (applications and interests), gives two sources of truth.

**Design-doc corrections:**
- `wiki_page_versions` doesn't exist; versions live in `content_versions`, and no v1 row is written on page create.
- Invite role `student` → `learner`.
- `project.create` → `projects.create`.
- `work_item_gitlab.gitlab_event_id UNIQUE` is wrong.
- Missing tables: watchers, brief approvals, AI cache, meeting occurrence.
- A `draft` item status is referenced but not defined.

---

# 01 — Database plan: Project Workspace

## 0. Ground truth found in the code (drives every decision below)

| Fact | Where | Consequence |
|---|---|---|
| The migration runner wraps **each file in one tx** and runs at app startup. It never runs `.down.sql` and tracks by filename | `backend/db/migrate.go:21-97` | No `CREATE INDEX CONCURRENTLY`. Downs are manual only. Every file must be safe to run while the previous binary is still serving |
| DB is Neon, **pooled endpoint** (PgBouncer, transaction mode), PG 16.14 | `backend/.env`, `001_baseline.sql:23` | Session-level advisory locks and `set_limit()` are unsafe. Use `pg_advisory_xact_lock` (already used in `sessions/repo.go:337`) and `SET LOCAL`. PG16 gives `btree_gist` EXCLUDE with uuid |
| Extensions already installed: `pg_trgm`, `btree_gist`, `citext`, `pgcrypto` | `001_baseline.sql:41-83` | No new extensions |
| `public.projects` **already exists** (personal project list, `task_links.target_type='project'`) | `026_projects.sql` | A new "projects" table can't use that name |
| `project_requirements` has `status draft/open/closed/archived`, `brief text NOT NULL`, `team_size_min/max`, `application_deadline NOT NULL`, `created_by RESTRICT` | `020_…sql` | Extend it. `brief` already *is* the raw requirement |
| No persistent link requirement→team; `CreateTeamFromSelection` needs a pre-existing assignment. Assignments need `batch_id NOT NULL` | `projectmarket/service.go:264`, baseline `project_assignments` | Add `team_id` on the project. GitLab for workspaces still needs a batch/assignment. Flag for the backend slice |
| `project_tasks` is **team-scoped** (`team_id NOT NULL`, `checkpoint_id`), status `todo/in_progress/review/done`, hard-deleted | `022_…sql`, `gitlab/repo_task.go` | Migrating it to project-scoped `work_items` needs a workspace per team (§3) |
| **No `wiki_page_versions` table.** Versions go to `content_versions(content_type='wiki_page', content_id, version)` and only on UPDATE. `CreatePage` writes no v1 row | `wiki/repo.go:231-275`, baseline `content_versions` | Store the approved **version number** (`int`) and compare it to `wiki_pages.version`; no FK. The wiki slice must insert the v1 row on create so the approved-v1 diff works |
| `comments.subject_type` CHECK is `('wiki_page','interview_exp_qna')` | baseline:743 | Widen it for work-item and question threads |
| `org_invites.role` is `admin/mentor/instructor/learner`; `uq_org_invite_pending (org_id,email)` is partial unique | baseline:2078, 7534 | There is no "student" role. Only **one** pending invite per org+email, so interests must *link* an existing pending invite, and the link can't be unique per invite |
| `org_invites` insert/`Join` run on pool/own tx | `orgs/invite.go:33,341` | Accept→invite needs a tx-accepting variant (backend slice) |
| Permission codes are `projects.view` / `projects.manage`. Role ids `…0003` instructor, `…0004` mentor, `…0005` tenant_admin | baseline:3645, 3895 | Seed `projects.create` |
| `gitlab_webhook_events UNIQUE (org_id, event_uuid)` already dedups replays | baseline:4983 | `work_item_gitlab` doesn't need an event-id unique |
| `gitlab_merge_requests` has no pipeline column | baseline:1151 | Add `head_pipeline_status` there, once per MR, not per link |
| Existing trgm index `idx_wiki_pages_search_text_trgm` is on `search_text`, but the query uses `similarity(p.title||' '||p.search_text, $2) > $4` | `035_…sql`, `wiki/repo.go:528` | That index is **never used** (expression mismatch, plus `similarity()>x` isn't indexable). Don't repeat this: use the `%` operator on the exact indexed column |
| Users are never hard-deleted in prod (`status deactivated`), but tests `DELETE FROM users` | baseline users, `*_test.go` | History rows: user FK `ON DELETE SET NULL` (nullable, shown as "Former member"). Current-state rows: `CASCADE`. Never RESTRICT (breaks test cleanup) |

## 1. Decision: extend `project_requirements` (no new projects table)

**Extend it.** Reasons:
- The design locks it.
- `project_applications.requirement_id`, AI scoring, `CloseExpired` and `CreateTeamFromSelection` all hang off it.
- `projects` is taken.
- A parallel table would need a 1:1 FK back to it anyway.

Rules:
- **`project_status IS NULL` = legacy marketplace-only listing** (all existing rows). A workspace is a row with `project_status NOT NULL`, created by `POST /api/projects`. No backfill of existing rows, no invented members.
- **Reuse `brief` as the raw requirement (current version).** Don't add `raw_requirement`: it would duplicate `brief`, which is `NOT NULL` and already rendered. `requirement_versions` keeps the history. "Brief" in the design (the agreed wiki doc) lives in `brief_wiki_page_id`. Add a `COMMENT ON COLUMN` to spell this out.
- The old `status` stays as the **listing/intake state**. `project_status` is the lifecycle. A CHECK ties them together (below) so they can't drift. The existing `CloseExpired` job (open→closed at deadline) stays valid and does what §5 wants ("deadline passed → form closed").
- New tables use the column name **`project_id`** (FK → `project_requirements(id)`), including `project_interests` (the design says `requirement_id`). `project_applications` keeps `requirement_id`.
- Backend follow-up: the legacy board query `status='open'` would list workspaces too. Add `AND project_status IS NULL`, and use `project_interests` as the **single** intake for workspaces (§1 of the design says reuse applications, while §5/§17 add interests; pick one).

**How work_items relate to teams/assignments:** `work_items.project_id → project_requirements`. The project optionally owns **one** GitLab team via `project_requirements.team_id` (partial unique, both directions 1:1). The webhook resolves `team_id → project → key_num`, so `MF-n` needs no global prefix, and a key from another project can't match. Work items never reference `project_teams` or `project_assignments` directly. Checkpoints stay the graded classroom gate. The `project_tasks.checkpoint_id` link is kept only in the migration map (see §3; this is a product decision).

## 2. DDL

Conventions:
- `uuid DEFAULT gen_random_uuid()` PKs, `timestamptz DEFAULT now() NOT NULL`, `public.` prefix, `text + CHECK` enums (codebase style).
- Child→project `ON DELETE CASCADE`, matching org-delete cascade; projects are archived, never deleted.
- Wiki page/space links that must not silently vanish use default `NO ACTION`. It is checked at end of statement, so org-delete cascades still work, but deleting a project's wiki space directly is blocked.
- Composite FKs `(x_id, project_id) → t(id, project_id)` keep references within a project at DB level. This is the same pattern as `project_team_members_team_assignment_fk`.

### 036 — project core (Phase 1)
```sql
SET LOCAL lock_timeout = '5s';

ALTER TABLE public.project_requirements
  ADD COLUMN project_status text CHECK (project_status IN ('draft','recruiting','active','paused','completed','cancelled','archived')),
  ADD COLUMN brief_status text CHECK (brief_status IN ('raw','clarifying','agreed')),
  ADD COLUMN requirement_version integer NOT NULL DEFAULT 0 CHECK (requirement_version >= 0),
  ADD COLUMN share_token text CHECK (share_token IS NULL OR char_length(share_token) BETWEEN 22 AND 64),
  ADD COLUMN share_token_rotated_at timestamptz,
  ADD COLUMN accepting_interests boolean NOT NULL DEFAULT true,
  ADD COLUMN wiki_space_id uuid REFERENCES public.wiki_spaces(id),            -- NO ACTION
  ADD COLUMN brief_wiki_page_id uuid REFERENCES public.wiki_pages(id),        -- NO ACTION
  ADD COLUMN team_id uuid REFERENCES public.project_teams(id) ON DELETE SET NULL,
  ADD COLUMN gitlab_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN sprints_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN wip_limit integer NOT NULL DEFAULT 3 CHECK (wip_limit BETWEEN 1 AND 50),
  ADD COLUMN item_seq integer NOT NULL DEFAULT 0 CHECK (item_seq >= 0),
  ADD COLUMN health_thresholds jsonb NOT NULL DEFAULT
    '{"s1_open_hours":24,"forecast_red_pct":20,"blocked_red_pct":25,"review_wait_days":3,"reopen_yellow_pct":20}',
  ADD COLUMN activated_at timestamptz,          -- first draft/recruiting→active
  ADD COLUMN brief_agreed_at timestamptz;       -- first agreement (metric: days active→agreed)

ALTER TABLE public.project_requirements
  ADD CONSTRAINT project_requirements_workspace_chk CHECK (
        (project_status IS NULL AND brief_status IS NULL AND share_token IS NULL AND team_id IS NULL)
     OR (project_status IS NOT NULL AND brief_status IS NOT NULL)),
  ADD CONSTRAINT project_requirements_status_sync_chk CHECK (
        project_status IS NULL
     OR (project_status = 'draft' AND status = 'draft')
     OR (project_status IN ('recruiting','active') AND status IN ('open','closed'))
     OR (project_status IN ('paused','completed','cancelled','archived') AND status IN ('closed','archived')));

COMMENT ON COLUMN public.project_requirements.brief IS
  'Raw requirement text (current version) as posted by the owner. The agreed brief is brief_wiki_page_id.';

CREATE UNIQUE INDEX uq_project_requirements_share_token ON public.project_requirements (share_token) WHERE share_token IS NOT NULL;
CREATE UNIQUE INDEX uq_project_requirements_team ON public.project_requirements (team_id) WHERE team_id IS NOT NULL;
CREATE UNIQUE INDEX uq_project_requirements_wiki_space ON public.project_requirements (wiki_space_id) WHERE wiki_space_id IS NOT NULL;
CREATE INDEX idx_project_requirements_workspace ON public.project_requirements (org_id, project_status, created_at DESC) WHERE project_status IS NOT NULL;

CREATE TABLE public.project_members (
  project_id uuid NOT NULL REFERENCES public.project_requirements(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role       text NOT NULL CHECK (role IN ('owner','manager','member','viewer')),
  status     text NOT NULL DEFAULT 'active' CHECK (status IN ('active','left','removed')),
  added_by   uuid REFERENCES public.users(id) ON DELETE SET NULL,
  joined_at  timestamptz DEFAULT now() NOT NULL,
  left_at    timestamptz,
  updated_at timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (project_id, user_id),
  CHECK ((status = 'active') = (left_at IS NULL)),
  CHECK (role <> 'owner' OR status = 'active')          -- owner can't leave (§4)
);
CREATE UNIQUE INDEX uq_project_members_one_owner ON public.project_members (project_id) WHERE role = 'owner';
CREATE INDEX idx_project_members_user ON public.project_members (user_id) WHERE status = 'active';

CREATE TABLE public.project_tracks (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id   uuid NOT NULL REFERENCES public.project_requirements(id) ON DELETE CASCADE,
  name         text NOT NULL CHECK (char_length(btrim(name)) BETWEEN 1 AND 60),
  lead_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_by   uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at   timestamptz DEFAULT now() NOT NULL,
  updated_at   timestamptz DEFAULT now() NOT NULL,
  UNIQUE (id, project_id)
);
CREATE UNIQUE INDEX uq_project_tracks_name ON public.project_tracks (project_id, lower(name));

CREATE TABLE public.project_track_members (
  track_id    uuid NOT NULL,
  project_id  uuid NOT NULL,
  user_id     uuid NOT NULL,
  status      text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved')),  -- §6 step 4: lead approves
  approved_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at  timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (track_id, user_id),
  FOREIGN KEY (track_id, project_id) REFERENCES public.project_tracks(id, project_id) ON DELETE CASCADE,
  FOREIGN KEY (project_id, user_id) REFERENCES public.project_members(project_id, user_id) ON DELETE CASCADE
);
CREATE INDEX idx_project_track_members_member ON public.project_track_members (project_id, user_id);

CREATE TABLE public.project_interests (
  id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id    uuid NOT NULL REFERENCES public.project_requirements(id) ON DELETE CASCADE,
  name          text NOT NULL CHECK (char_length(btrim(name)) BETWEEN 1 AND 120),
  email         public.citext NOT NULL CHECK (char_length(email) BETWEEN 3 AND 254),
  skills        text[] NOT NULL DEFAULT '{}' CHECK (cardinality(skills) <= 30),
  portfolio_url text CHECK (portfolio_url IS NULL OR char_length(portfolio_url) <= 500),
  message       text CHECK (message IS NULL OR char_length(message) <= 4000),
  status        text NOT NULL DEFAULT 'new' CHECK (status IN ('new','accepted','rejected','invite_expired','joined')),
  invite_id     uuid REFERENCES public.org_invites(id) ON DELETE SET NULL,   -- NOT unique: one pending org invite may serve several projects
  user_id       uuid REFERENCES public.users(id) ON DELETE SET NULL,
  ai_score      double precision CHECK (ai_score IS NULL OR ai_score BETWEEN 0 AND 100),
  ai_rationale  text,
  ai_scored_at  timestamptz,
  reviewed_by   uuid REFERENCES public.users(id) ON DELETE SET NULL,
  reviewed_at   timestamptz,
  created_at    timestamptz DEFAULT now() NOT NULL,
  updated_at    timestamptz DEFAULT now() NOT NULL,
  UNIQUE (project_id, email),                         -- citext = case-insensitive; no lower() index needed
  CHECK (status = 'new' OR reviewed_at IS NOT NULL)
);
CREATE INDEX idx_project_interests_review ON public.project_interests (project_id, status, created_at DESC, id);
CREATE INDEX idx_project_interests_invite ON public.project_interests (invite_id) WHERE invite_id IS NOT NULL;
CREATE INDEX idx_project_interests_purge  ON public.project_interests (updated_at) WHERE status IN ('new','rejected','invite_expired');

CREATE TABLE public.requirement_versions (
  project_id      uuid NOT NULL REFERENCES public.project_requirements(id) ON DELETE CASCADE,
  version         integer NOT NULL CHECK (version >= 1),
  raw_requirement text NOT NULL CHECK (char_length(raw_requirement) BETWEEN 50 AND 20000),
  created_by      uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at      timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (project_id, version)
);

CREATE TABLE public.onboarding_steps (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id   uuid NOT NULL REFERENCES public.project_requirements(id) ON DELETE CASCADE,
  title        text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 200),
  wiki_page_id uuid REFERENCES public.wiki_pages(id) ON DELETE SET NULL,
  required     boolean NOT NULL DEFAULT true,
  position     integer NOT NULL CHECK (position >= 0),
  created_at   timestamptz DEFAULT now() NOT NULL
);
CREATE INDEX idx_onboarding_steps_project ON public.onboarding_steps (project_id, position, id);

CREATE TABLE public.onboarding_progress (
  step_id uuid NOT NULL REFERENCES public.onboarding_steps(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  done_at timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (step_id, user_id)
);

INSERT INTO public.permissions (code, name, description, module)
SELECT 'projects.create', 'Create Projects', 'Create project workspaces (share link, team, work items)', 'projects'
WHERE NOT EXISTS (SELECT 1 FROM public.permissions WHERE code = 'projects.create');
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r, p.id FROM public.permissions p,
  unnest(ARRAY['11111111-1111-1111-1111-000000000003','11111111-1111-1111-1111-000000000004','11111111-1111-1111-1111-000000000005']::uuid[]) r
WHERE p.code = 'projects.create' ON CONFLICT DO NOTHING;
```
No unique on `onboarding_steps.position`: reordering then needs no deferrable constraint; order by `(position, id)`.

### 037 — work items (Phase 2)
```sql
SET LOCAL lock_timeout = '5s';

CREATE TABLE public.work_items (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id       uuid NOT NULL REFERENCES public.project_requirements(id) ON DELETE CASCADE,
  key_num          integer NOT NULL CHECK (key_num > 0),
  type             text NOT NULL CHECK (type IN ('epic','feature','task','bug','subtask')),   -- immutable after create (service)
  parent_id        uuid,
  track_id         uuid,
  title            text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 300),
  description      text CHECK (description IS NULL OR char_length(description) <= 50000),
  status           text NOT NULL DEFAULT 'todo',
  priority         text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low','medium','high','urgent')),
  severity         text CHECK (severity IN ('S1','S2','S3','S4')),
  labels           text[] NOT NULL DEFAULT '{}',            -- e.g. 'regression' (same pattern as whatnow_tasks.tags)
  estimate_minutes integer CHECK (estimate_minutes IS NULL OR estimate_minutes BETWEEN 1 AND 100000),
  doc_wiki_page_id uuid REFERENCES public.wiki_pages(id),  -- NO ACTION
  doc_status       text CHECK (doc_status IN ('draft','in_review','changes_requested','approved')),
  approved_doc_version integer CHECK (approved_doc_version IS NULL OR approved_doc_version >= 1),  -- = wiki_pages.version at approval
  blocked_reason   text CHECK (blocked_reason IS NULL OR char_length(blocked_reason) <= 2000),
  reopen_count     integer NOT NULL DEFAULT 0 CHECK (reopen_count >= 0),
  version          integer NOT NULL DEFAULT 1 CHECK (version >= 1),   -- optimistic lock
  due_at           timestamptz,
  created_by       uuid REFERENCES public.users(id) ON DELETE SET NULL,
  archived_at      timestamptz,
  created_at       timestamptz DEFAULT now() NOT NULL,
  updated_at       timestamptz DEFAULT now() NOT NULL,
  UNIQUE (project_id, key_num),
  UNIQUE (id, project_id),
  FOREIGN KEY (parent_id, project_id) REFERENCES public.work_items(id, project_id),       -- same project; NO ACTION: parent with children can't be deleted
  FOREIGN KEY (track_id, project_id)  REFERENCES public.project_tracks(id, project_id),  -- same project; track in use can't be deleted
  CHECK (parent_id IS NULL OR parent_id <> id),
  CHECK (type <> 'epic' OR parent_id IS NULL),
  CHECK (type <> 'subtask' OR parent_id IS NOT NULL),
  CHECK ((type IN ('epic','feature') AND status IN ('todo','in_progress','done','wont_do'))
      OR (type NOT IN ('epic','feature') AND status IN ('todo','in_progress','in_review','testing','done','blocked','reopened','wont_do'))),
  CHECK (type = 'bug' OR severity IS NULL),
  CHECK (type = 'feature' OR (doc_wiki_page_id IS NULL AND doc_status IS NULL AND approved_doc_version IS NULL)),
  CHECK ((doc_wiki_page_id IS NULL) = (doc_status IS NULL)),
  CHECK (status = 'blocked' OR blocked_reason IS NULL)
);
CREATE INDEX idx_work_items_project_status ON public.work_items (project_id, status) WHERE archived_at IS NULL;
CREATE INDEX idx_work_items_parent ON public.work_items (parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX idx_work_items_track ON public.work_items (track_id, status) WHERE track_id IS NOT NULL;
CREATE INDEX idx_work_items_overdue ON public.work_items (project_id, due_at)
  WHERE due_at IS NOT NULL AND archived_at IS NULL AND status NOT IN ('done','wont_do');
CREATE INDEX idx_work_items_open_bugs ON public.work_items (project_id, severity, created_at)
  WHERE type = 'bug' AND status NOT IN ('done','wont_do');
CREATE UNIQUE INDEX uq_work_items_doc_page ON public.work_items (doc_wiki_page_id) WHERE doc_wiki_page_id IS NOT NULL;
CREATE INDEX idx_work_items_title_trgm ON public.work_items USING gin (title gin_trgm_ops) WHERE archived_at IS NULL;

CREATE TABLE public.work_item_assignees (
  item_id     uuid NOT NULL REFERENCES public.work_items(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role        text NOT NULL CHECK (role IN ('owner','developer','reviewer','tester')),
  assigned_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  assigned_at timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (item_id, user_id, role)
);
CREATE UNIQUE INDEX uq_work_item_assignees_one_owner ON public.work_item_assignees (item_id) WHERE role = 'owner';
CREATE INDEX idx_work_item_assignees_user ON public.work_item_assignees (user_id, role);

CREATE TABLE public.work_item_links (
  project_id uuid NOT NULL,
  from_id    uuid NOT NULL,
  to_id      uuid NOT NULL,
  kind       text NOT NULL CHECK (kind IN ('blocks','relates','duplicates')),
  created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (from_id, to_id, kind),
  FOREIGN KEY (from_id, project_id) REFERENCES public.work_items(id, project_id) ON DELETE CASCADE,
  FOREIGN KEY (to_id, project_id)   REFERENCES public.work_items(id, project_id) ON DELETE CASCADE,
  CHECK (from_id <> to_id)
);
CREATE INDEX idx_work_item_links_to ON public.work_item_links (to_id, kind);
CREATE UNIQUE INDEX uq_work_item_links_relates ON public.work_item_links (LEAST(from_id,to_id), GREATEST(from_id,to_id)) WHERE kind = 'relates';
CREATE UNIQUE INDEX uq_work_item_links_one_original ON public.work_item_links (from_id) WHERE kind = 'duplicates';

CREATE TABLE public.work_item_events (           -- append-only: repo exposes INSERT/SELECT only
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  project_id uuid NOT NULL,
  item_id    uuid NOT NULL,
  actor_id   uuid REFERENCES public.users(id) ON DELETE SET NULL,
  source     text NOT NULL DEFAULT 'user' CHECK (source IN ('user','gitlab','system','import')),
  kind       text NOT NULL CHECK (kind IN ('create','status','field','assign','unassign','link','unlink','move','doc','review','sprint','release','archive')),
  field      text,
  from_value text,
  to_value   text,
  reason     text CHECK (reason IS NULL OR char_length(reason) <= 2000),
  created_at timestamptz DEFAULT now() NOT NULL,
  FOREIGN KEY (item_id, project_id) REFERENCES public.work_items(id, project_id) ON DELETE CASCADE
);
CREATE INDEX idx_work_item_events_item ON public.work_item_events (item_id, id);
CREATE INDEX idx_work_item_events_project ON public.work_item_events (project_id, kind, created_at);

CREATE TABLE public.work_item_watchers (          -- §7 "moves its watchers" — missing from §17
  item_id    uuid NOT NULL REFERENCES public.work_items(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (item_id, user_id)
);
CREATE INDEX idx_work_item_watchers_user ON public.work_item_watchers (user_id);

ALTER TABLE public.comments DROP CONSTRAINT comments_subject_type_check,
  ADD CONSTRAINT comments_subject_type_check CHECK (subject_type IN ('wiki_page','interview_exp_qna','work_item','requirement_question'));
```
- `project_id` is denormalised onto events, links, time logs and gitlab rows, and a composite FK guarantees it matches. This lets dashboard range queries hit `(project_id, kind, created_at)` without joining `work_items`. Items never change project.
- No `org_id` on child tables: `RequireProjectRole` resolves project→org once.
- No parent-cycle check is needed. The type ladder (epic > feature > task|bug > subtask, with parent level strictly higher) makes cycles impossible. Drop "cycle-free" for parents from §7; it's still needed for `blocks` links.

### 038 — `project_tasks` → `work_items` backfill (expand; Phase 2)
```sql
CREATE TABLE public.project_team_imports (       -- workspaces this migration synthesised (for down)
  project_id uuid PRIMARY KEY REFERENCES public.project_requirements(id) ON DELETE CASCADE,
  team_id    uuid NOT NULL
);
CREATE TABLE public.project_task_migration_map (  -- task_id = work_items.id
  task_id       uuid PRIMARY KEY,
  project_id    uuid NOT NULL REFERENCES public.project_requirements(id) ON DELETE CASCADE,
  team_id       uuid NOT NULL,
  checkpoint_id uuid,                               -- preserved only here (work_items has no checkpoint link)
  migrated_at   timestamptz DEFAULT now() NOT NULL
);

CREATE FUNCTION public.mf_migrate_project_tasks() RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  -- 1. one workspace per team that has tasks and no workspace yet
  CREATE TEMP TABLE _np ON COMMIT DROP AS
  WITH ins AS (
    INSERT INTO public.project_requirements
      (org_id, title, brief, team_size_min, team_size_max, application_deadline, status,
       project_status, brief_status, accepting_interests, team_id, created_by, activated_at)
    SELECT pt.org_id, left(pa.title || ' / ' || pt.name, 200),
           COALESCE(NULLIF(btrim(pa.description), ''), pa.title),
           1, GREATEST(1, (SELECT count(*) FROM public.project_team_members m WHERE m.team_id = pt.id)),
           COALESCE(pa.due_at, pt.created_at), 'closed', 'active', 'agreed', false, pt.id, pa.created_by, pt.created_at
    FROM public.project_teams pt JOIN public.project_assignments pa ON pa.id = pt.assignment_id
    WHERE EXISTS (SELECT 1 FROM public.project_tasks t WHERE t.team_id = pt.id)
      AND NOT EXISTS (SELECT 1 FROM public.project_requirements r WHERE r.team_id = pt.id)
    RETURNING id, team_id, created_by)
  SELECT * FROM ins;
  INSERT INTO public.project_team_imports SELECT id, team_id FROM _np;
  INSERT INTO public.project_members (project_id, user_id, role) SELECT id, created_by, 'owner' FROM _np;
  INSERT INTO public.project_members (project_id, user_id, role, added_by, joined_at)
  SELECT np.id, m.user_id, CASE m.role WHEN 'lead' THEN 'manager' ELSE 'member' END, m.added_by, m.added_at
  FROM _np np JOIN public.project_team_members m ON m.team_id = np.team_id
  WHERE m.user_id <> np.created_by;

  -- 2. catch-up: tasks already migrated but edited later by an old binary (last writer wins)
  UPDATE public.work_items w SET title = left(btrim(t.title),300), description = t.description,
         status = CASE t.status WHEN 'review' THEN 'in_review' ELSE t.status END,
         due_at = t.due_at, updated_at = t.updated_at, version = w.version + 1
  FROM public.project_tasks t JOIN public.project_task_migration_map mm ON mm.task_id = t.id
  WHERE w.id = t.id AND t.updated_at > w.updated_at;

  -- 3. new tasks → items, keys continue from item_seq in created order
  CREATE TEMP TABLE _src ON COMMIT DROP AS
  SELECT t.*, r.id AS project_id,
         r.item_seq + row_number() OVER (PARTITION BY r.id ORDER BY t.created_at, t.id) AS key_num
  FROM public.project_tasks t JOIN public.project_requirements r ON r.team_id = t.team_id
  WHERE NOT EXISTS (SELECT 1 FROM public.project_task_migration_map mm WHERE mm.task_id = t.id);

  INSERT INTO public.work_items (id, project_id, key_num, type, title, description, status, due_at, created_by, created_at, updated_at)
  SELECT id, project_id, key_num, 'task', COALESCE(NULLIF(left(btrim(title),300),''),'(untitled)'), description,
         CASE status WHEN 'review' THEN 'in_review' ELSE status END, due_at, created_by, created_at, updated_at
  FROM _src;
  UPDATE public.project_requirements r SET item_seq = s.max_key
  FROM (SELECT project_id, max(key_num) AS max_key FROM _src GROUP BY project_id) s WHERE r.id = s.project_id;
  INSERT INTO public.work_item_assignees (item_id, user_id, role, assigned_by, assigned_at)
  SELECT id, assignee_user_id, 'owner', created_by, updated_at FROM _src WHERE assignee_user_id IS NOT NULL;
  INSERT INTO public.work_item_events (project_id, item_id, actor_id, source, kind, to_value, reason, created_at)
  SELECT project_id, id, created_by, 'import', 'create',
         CASE status WHEN 'review' THEN 'in_review' ELSE status END, 'imported from project_tasks', created_at FROM _src;
  INSERT INTO public.project_task_migration_map (task_id, project_id, team_id, checkpoint_id)
  SELECT id, project_id, team_id, checkpoint_id FROM _src;
END $$;

SELECT public.mf_migrate_project_tasks();
```
`project_tasks` is **not** touched here.

### 039 — contract (Phase 2, *next* release after the code switch is live)
```sql
SET LOCAL lock_timeout = '5s';
SELECT public.mf_migrate_project_tasks();   -- catch writes made by old binaries since 038
DROP FUNCTION public.mf_migrate_project_tasks();
DROP TABLE public.project_tasks;
```

### 040 — clarification, doc gate, meetings, AI cache (Phase 3)
```sql
CREATE TABLE public.requirement_questions (
  id                  uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id          uuid NOT NULL,
  requirement_version integer NOT NULL,
  asked_by            uuid REFERENCES public.users(id) ON DELETE SET NULL,
  question            text NOT NULL CHECK (char_length(btrim(question)) BETWEEN 5 AND 2000),
  answer              text CHECK (answer IS NULL OR char_length(answer) <= 10000),
  answered_by         uuid REFERENCES public.users(id) ON DELETE SET NULL,
  answered_at         timestamptz,
  is_assumption       boolean NOT NULL DEFAULT false,
  created_at          timestamptz DEFAULT now() NOT NULL,
  updated_at          timestamptz DEFAULT now() NOT NULL,
  FOREIGN KEY (project_id, requirement_version) REFERENCES public.requirement_versions(project_id, version) ON DELETE CASCADE,
  CHECK ((answer IS NULL) = (answered_at IS NULL)),
  CHECK (NOT is_assumption OR answer IS NOT NULL)          -- assumption must be written down
);
CREATE INDEX idx_requirement_questions_project ON public.requirement_questions (project_id, created_at DESC, id);
CREATE INDEX idx_requirement_questions_unanswered ON public.requirement_questions (created_at) WHERE answered_at IS NULL;  -- 3d/5d reminder job
CREATE INDEX idx_requirement_questions_trgm ON public.requirement_questions USING gin (question gin_trgm_ops);

CREATE TABLE public.brief_approvals (            -- missing from §17: owner + manager sign-off
  project_id          uuid NOT NULL,
  requirement_version integer NOT NULL,
  approver_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  approver_role       text NOT NULL CHECK (approver_role IN ('owner','manager','track_lead')),
  wiki_version        integer NOT NULL CHECK (wiki_version >= 1),   -- must equal brief page's current version (service)
  created_at          timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (project_id, requirement_version, approver_id),
  FOREIGN KEY (project_id, requirement_version) REFERENCES public.requirement_versions(project_id, version) ON DELETE CASCADE
);

CREATE TABLE public.work_item_reviews (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  item_id          uuid NOT NULL REFERENCES public.work_items(id) ON DELETE CASCADE,
  reviewer_id      uuid REFERENCES public.users(id) ON DELETE SET NULL,
  target           text NOT NULL CHECK (target IN ('doc','code')),
  verdict          text NOT NULL CHECK (verdict IN ('approved','changes_requested','commented')),
  comment          text CHECK (comment IS NULL OR char_length(comment) <= 10000),
  wiki_version     integer CHECK (wiki_version IS NULL OR wiki_version >= 1),
  merge_request_id uuid REFERENCES public.gitlab_merge_requests(id) ON DELETE SET NULL,
  created_at       timestamptz DEFAULT now() NOT NULL,
  CHECK ((target = 'doc') = (wiki_version IS NOT NULL)),
  CHECK (target = 'code' OR merge_request_id IS NULL),
  CHECK (verdict <> 'changes_requested' OR comment IS NOT NULL)
);
CREATE INDEX idx_work_item_reviews_item ON public.work_item_reviews (item_id, target, created_at);
CREATE INDEX idx_work_item_reviews_reviewer ON public.work_item_reviews (reviewer_id, created_at);

CREATE TABLE public.project_meetings (
  calendar_event_id  uuid PRIMARY KEY REFERENCES public.calendar_events(id) ON DELETE CASCADE,
  project_id         uuid NOT NULL REFERENCES public.project_requirements(id) ON DELETE CASCADE,
  kind               text NOT NULL CHECK (kind IN ('kickoff','sprint_planning','standup','design_review','retro','demo')),
  item_id            uuid REFERENCES public.work_items(id) ON DELETE SET NULL,   -- design review for a feature
  notes_wiki_page_id uuid REFERENCES public.wiki_pages(id) ON DELETE SET NULL,
  created_at         timestamptz DEFAULT now() NOT NULL
);
CREATE INDEX idx_project_meetings_project ON public.project_meetings (project_id, kind);

CREATE TABLE public.meeting_attendance (
  calendar_event_id uuid NOT NULL REFERENCES public.project_meetings(calendar_event_id) ON DELETE CASCADE,
  occurrence_at     timestamptz NOT NULL,   -- recurring events expand virtually; = starts_at for one-offs
  user_id           uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  status            text NOT NULL CHECK (status IN ('attended','missed')),
  recorded_by       uuid REFERENCES public.users(id) ON DELETE SET NULL,
  recorded_at       timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (calendar_event_id, occurrence_at, user_id)
);
CREATE INDEX idx_meeting_attendance_user ON public.meeting_attendance (user_id, occurrence_at);

CREATE TABLE public.standup_updates (
  project_id uuid NOT NULL REFERENCES public.project_requirements(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  standup_on date NOT NULL,
  yesterday  text NOT NULL CHECK (char_length(yesterday) <= 2000),
  today      text NOT NULL CHECK (char_length(today) <= 2000),
  blockers   text CHECK (blockers IS NULL OR char_length(blockers) <= 2000),
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (project_id, user_id, standup_on)
);
CREATE INDEX idx_standup_updates_day ON public.standup_updates (project_id, standup_on);

CREATE TABLE public.project_ai_cache (            -- "AI called once": gaps, epic/task suggestions, weekly summary, why-late, release notes
  project_id uuid NOT NULL REFERENCES public.project_requirements(id) ON DELETE CASCADE,
  kind       text NOT NULL CHECK (kind IN ('requirement_gaps','epic_suggestions','task_breakdown','assignee_suggestion','weekly_summary','late_explanation','release_notes')),
  subject_id uuid NOT NULL,        -- project / item / release id
  cache_key  text NOT NULL,        -- requirement version | doc version | ISO week | date
  content    jsonb NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (project_id, kind, subject_id, cache_key)
);
```

### 041 — GitLab linking + time logs (Phase 4)
```sql
SET LOCAL lock_timeout = '5s';
ALTER TABLE public.gitlab_merge_requests
  ADD COLUMN head_pipeline_status text CHECK (head_pipeline_status IS NULL OR head_pipeline_status IN ('pending','running','success','failed','canceled'));

CREATE TABLE public.work_item_gitlab (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id       uuid NOT NULL,
  item_id          uuid NOT NULL,
  kind             text NOT NULL CHECK (kind IN ('branch','mr','commit')),
  gitlab_ref       text NOT NULL CHECK (char_length(gitlab_ref) BETWEEN 1 AND 255),   -- branch name | MR iid | sha
  merge_request_id uuid REFERENCES public.gitlab_merge_requests(id) ON DELETE SET NULL,  -- MR state/pipeline read via join
  sync_status      text NOT NULL DEFAULT 'synced' CHECK (sync_status IN ('synced','pending','failed')),  -- reviewer sync → MR
  first_seen_at    timestamptz DEFAULT now() NOT NULL,
  updated_at       timestamptz DEFAULT now() NOT NULL,
  UNIQUE (item_id, kind, gitlab_ref),
  FOREIGN KEY (item_id, project_id) REFERENCES public.work_items(id, project_id) ON DELETE CASCADE,
  CHECK (kind = 'mr' OR merge_request_id IS NULL)
);
CREATE INDEX idx_work_item_gitlab_mr ON public.work_item_gitlab (merge_request_id) WHERE merge_request_id IS NOT NULL;
CREATE INDEX idx_work_item_gitlab_project ON public.work_item_gitlab (project_id, kind);

CREATE TABLE public.work_item_time_logs (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id uuid NOT NULL,
  item_id    uuid NOT NULL,
  user_id    uuid REFERENCES public.users(id) ON DELETE SET NULL,
  minutes    integer NOT NULL CHECK (minutes BETWEEN 1 AND 720),
  note       text CHECK (note IS NULL OR char_length(note) <= 1000),
  logged_on  date NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  FOREIGN KEY (item_id, project_id) REFERENCES public.work_items(id, project_id) ON DELETE CASCADE
);
CREATE INDEX idx_work_item_time_logs_user_day ON public.work_item_time_logs (user_id, logged_on);
CREATE INDEX idx_work_item_time_logs_project_day ON public.work_item_time_logs (project_id, logged_on);
CREATE INDEX idx_work_item_time_logs_item ON public.work_item_time_logs (item_id);
```

### 042 — releases, sprints, completion (Phase 5)
```sql
SET LOCAL lock_timeout = '5s';
CREATE TABLE public.releases (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id  uuid NOT NULL REFERENCES public.project_requirements(id) ON DELETE CASCADE,
  version     text NOT NULL CHECK (char_length(btrim(version)) BETWEEN 1 AND 40),
  status      text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','frozen','released')),
  target_at   timestamptz,                 -- §16.6 "days to target" — missing from §17
  frozen_at   timestamptz,
  released_at timestamptz,
  created_by  uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at  timestamptz DEFAULT now() NOT NULL,
  updated_at  timestamptz DEFAULT now() NOT NULL,
  UNIQUE (project_id, version), UNIQUE (id, project_id),
  CHECK ((status = 'released') = (released_at IS NOT NULL)),
  CHECK (status = 'planned' OR frozen_at IS NOT NULL)
);
CREATE TABLE public.release_snapshots (         -- §13 "what spec shipped in v1.2"
  release_id  uuid NOT NULL REFERENCES public.releases(id) ON DELETE CASCADE,
  item_id     uuid NOT NULL REFERENCES public.work_items(id) ON DELETE CASCADE,
  doc_version integer,
  status      text NOT NULL,
  PRIMARY KEY (release_id, item_id)
);
CREATE TABLE public.sprints (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id uuid NOT NULL REFERENCES public.project_requirements(id) ON DELETE CASCADE,
  name       text NOT NULL CHECK (char_length(btrim(name)) BETWEEN 1 AND 80),
  starts_on  date NOT NULL,
  ends_on    date NOT NULL,
  status     text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','active','completed')),
  created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE (id, project_id),
  CHECK (ends_on > starts_on AND ends_on - starts_on <= 28),
  EXCLUDE USING gist (project_id WITH =, daterange(starts_on, ends_on, '[]') WITH &&)
);
CREATE UNIQUE INDEX uq_sprints_one_active ON public.sprints (project_id) WHERE status = 'active';

ALTER TABLE public.work_items
  ADD COLUMN release_id uuid, ADD COLUMN sprint_id uuid,
  ADD CONSTRAINT work_items_release_fk FOREIGN KEY (release_id, project_id) REFERENCES public.releases(id, project_id),
  ADD CONSTRAINT work_items_sprint_fk  FOREIGN KEY (sprint_id, project_id)  REFERENCES public.sprints(id, project_id);
CREATE INDEX idx_work_items_release ON public.work_items (release_id) WHERE release_id IS NOT NULL;
CREATE INDEX idx_work_items_sprint  ON public.work_items (sprint_id)  WHERE sprint_id IS NOT NULL;

CREATE TABLE public.peer_feedback (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id uuid NOT NULL REFERENCES public.project_requirements(id) ON DELETE CASCADE,
  from_user  uuid REFERENCES public.users(id) ON DELETE SET NULL,
  to_user    uuid REFERENCES public.users(id) ON DELETE SET NULL,
  rating     smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment    text CHECK (comment IS NULL OR char_length(comment) <= 2000),
  created_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE (project_id, from_user, to_user),
  CHECK (from_user <> to_user)
);
CREATE INDEX idx_peer_feedback_to ON public.peer_feedback (to_user, project_id);

ALTER TABLE public.project_members ADD COLUMN showcase_opt_in boolean NOT NULL DEFAULT false;  -- §15.4
```
All new columns are nullable or have constant defaults, so these ALTERs are metadata-only (no rewrite). The new FKs validate over NULL columns, which is instant.

### Dashboard index map (§16)
| Metric | Served by |
|---|---|
| Board, progress %, the "complete" precheck (no open in_progress/in_review/testing) | `idx_work_items_project_status` |
| Plan tree / roll-up | `idx_work_items_parent` |
| Track table | `idx_work_items_track` |
| Overdue | `idx_work_items_overdue` |
| Bugs by severity/age, S1 >24h | `idx_work_items_open_bugs` |
| Burndown, throughput, lead/cycle/stage time, scope churn | `idx_work_item_events_project (project_id, kind, created_at)` |
| Per-item timeline | `idx_work_item_events_item` |
| Load by role, WIP | `idx_work_item_assignees_user` + item PK |
| Review responsiveness, rounds | `idx_work_item_reviews_*` |
| Time logged | `idx_work_item_time_logs_project_day` / `_user_day` |
| CI pass rate, MR size | `work_item_gitlab → gitlab_merge_requests` |
| Commits | existing `idx_gitlab_commits_team_committed` via `project.team_id` |
| Requirement clarity | `idx_requirement_questions_project` |
| Onboarding % | `onboarding_progress` PK + `idx_onboarding_steps_project` |
| Last active | max over events / commits / time logs per user; indexes above |

No aggregation tables. Add a nightly materialised view only when a measured query is slow (per §16).

## 3. `project_tasks` → `work_items` migration

**Order (zero-downtime; migrations run at startup of the new binary while the old one may still serve):**
1. **Release A** ships 037 (empty tables, no readers). Nothing changes for users.
2. **Release B** ships 038 plus code that switches `/api/projects/teams/{teamID}/tasks*` to `work_items`, using `team_id → project`. If a team has no workspace, `EnsureWorkspaceForTeam` creates one in the same tx, reusing the INSERT shape from 038.
   - 038 backfills. `project_tasks` stays in place, so rolling code back to A is safe: A still reads `project_tasks`.
   - Writes made by old binaries during the rollout, or during a code rollback, keep landing in `project_tasks`.
3. **Release C** ships 039. Its first step re-runs the **same idempotent function**: inserts unmapped tasks, and applies later edits where `t.updated_at > w.updated_at`. Then it drops the function and `project_tasks`.
   - Tasks hard-deleted by an old binary in the B window stay as items. This is documented: a minutes-long window.

**Key assignment:** `row_number() OVER (PARTITION BY project ORDER BY created_at, id)` offset by the current `item_seq`. `item_seq` is then set to the max. `UNIQUE (project_id, key_num)` is the backstop.

**Mapping:**
- `id` is preserved (`work_items.id = project_tasks.id`), so old links and URLs resolve.
- Status `review`→`in_review`.
- `assignee_user_id` → `work_item_assignees(role='owner')`.
- One `create` event with `source='import'`, so cycle-time metrics can exclude imports.
- `checkpoint_id` is kept only in the map table.
- Synthesised workspaces:
  - `project_status='active'`, `brief_status='agreed'` (otherwise the "nothing past todo until agreed" gate would contradict existing in-progress/done rows), `status='closed'`, `requirement_version=0`, `wiki_space_id` NULL (the service creates it lazily).
  - Owner = assignment creator. Team `lead`→`manager`, `member`→`member`.

**Rollback:**
- `039.down.sql`: recreate `project_tasks` with the exact 022 DDL and index. Repopulate from `work_items JOIN project_task_migration_map`, with the reverse status map (`in_review|testing`→`review`, `blocked|reopened`→`in_progress`, `wont_do`→`done`). Take the assignee from the owner row and the checkpoint from the map. It does **not** delete from `work_items`, so no data is lost. Items created after the switch aren't projected back; they're documented as work_items-only.
- `038.down.sql`: `DROP FUNCTION IF EXISTS`. Delete `work_items` whose id is in the map (cascades assignees and events). Delete `project_requirements` whose id is in `project_team_imports` (cascades members). Drop both map tables. This is only valid before any child item has been created under a migrated task: the parent FK is `NO ACTION`, so the down fails loudly rather than orphaning data.
- `037.down.sql`: restore the old `comments` CHECK (fails if `work_item` comments exist, which is correct). Drop the tables in reverse order.
- `036.down.sql`: delete the permission grant and code. Drop the tables. Drop the constraints and columns.

**Pre-flight (read-only, run before Release B):**
```sql
SELECT count(*) AS tasks, count(DISTINCT team_id) AS teams,
       count(*) FILTER (WHERE char_length(btrim(title)) > 300 OR btrim(title) = '') AS bad_titles
FROM project_tasks;
```
I couldn't run this: no psql available, and I didn't touch prod.

## 4. Concurrency patterns

**Canonical lock order, to avoid deadlocks:** project row → project-graph advisory lock → `project_members` row(s) → work item rows in ascending id, leaf before ancestors. Every write path takes locks in this order.

**Item key counter** (gap-free, because a rollback undoes the increment):
```sql
-- inside the create-item tx
UPDATE project_requirements SET item_seq = item_seq + 1
 WHERE id = $1 AND project_status IN ('draft','recruiting','active')
RETURNING item_seq;             -- 0 rows → 409 project not writable
INSERT INTO work_items (project_id, key_num, ...) VALUES ($1, $seq, ...);
INSERT INTO work_item_events (... 'create' ...);
```
This row lock serialises item creation per project. That's fine at team scale. It is a HOT update: `item_seq` isn't indexed.

**Seat cap.** A seat is counted by active `manager`/`member` rows **plus accepted-not-yet-joined interests**, which reserve seats. Owner and viewers don't count. This definition is a design decision (flag).
```sql
BEGIN;
SELECT team_size_max FROM project_requirements WHERE id = $1 AND org_id = $2 FOR UPDATE;
SELECT (SELECT count(*) FROM project_members WHERE project_id = $1 AND status = 'active' AND role IN ('manager','member'))
     + (SELECT count(*) FROM project_interests WHERE project_id = $1 AND status = 'accepted');
-- >= team_size_max → 409
UPDATE project_interests SET status = 'accepted', reviewed_by = $u, reviewed_at = now(), invite_id = $inv, updated_at = now()
 WHERE id = $iid AND project_id = $1 AND status = 'new' RETURNING id;   -- 0 rows → 409 already reviewed
-- direct path: INSERT project_members … ; interest → 'joined'
-- invite path: INSERT org_invites (same tx — needs tx-accepting InviteService variant), or reuse the existing pending invite (uq_org_invite_pending)
COMMIT;
```
**Join hook** (inside the `Join` tx, respecting lock order):
```sql
SELECT r.id FROM project_requirements r JOIN project_interests i ON i.project_id = r.id
 WHERE i.invite_id = $inv AND i.status = 'accepted' AND r.project_status IN ('recruiting','active')
 ORDER BY r.id FOR UPDATE OF r;
-- per project: INSERT project_members … ON CONFLICT (project_id,user_id) DO UPDATE SET status='active', left_at=NULL
-- UPDATE project_interests SET status='joined', user_id=$u
```

**Interest upsert** (dedup, plus reapply after 30 days):
```sql
INSERT INTO project_interests (project_id, name, email, skills, portfolio_url, message) VALUES (...)
ON CONFLICT (project_id, email) DO UPDATE
  SET name = EXCLUDED.name, skills = EXCLUDED.skills, portfolio_url = EXCLUDED.portfolio_url, message = EXCLUDED.message,
      status = 'new', ai_score = NULL, ai_rationale = NULL, ai_scored_at = NULL, reviewed_by = NULL, reviewed_at = NULL, updated_at = now()
  WHERE project_interests.status = 'new'
     OR (project_interests.status = 'rejected' AND project_interests.reviewed_at < now() - interval '30 days')
RETURNING id;     -- 0 rows → neutral "already received"
```

**Optimistic locking:**
```sql
UPDATE work_items SET title = $4, ..., version = version + 1, updated_at = now()
 WHERE id = $1 AND project_id = $2 AND version = $3 AND archived_at IS NULL
RETURNING <cols>;
-- 0 rows → SELECT <cols> WHERE id=$1 AND project_id=$2 → found: 409 + current row; missing: 404
```
Transitions: `SELECT … FOR UPDATE` on the item, validate from→to and the gates in the service, then UPDATE (with version bump) plus the event insert. The parent roll-up is recomputed in the same tx, with the parent locked after the child.

**WIP limit:** `SELECT 1 FROM project_members WHERE project_id=$1 AND user_id=$2 FOR UPDATE`, then count owned `in_progress` items, then transition.

**One owner / self-assign only when unassigned:** the `uq_work_item_assignees_one_owner` partial index. A concurrent second claim gets `23505` → 409. Role-separation rules (reviewer ≠ developer, tester ≠ developer) are checked in the service under the item's `FOR UPDATE` lock. A constraint can't express them.

**`blocks` acyclicity** (two concurrent A→B / B→A inserts would both pass an unlocked check):
```sql
SELECT pg_advisory_xact_lock(hashtextextended('work_item_graph:' || $project_id, 0));
WITH RECURSIVE reach(id) AS (
  SELECT $to::uuid UNION
  SELECT l.to_id FROM work_item_links l JOIN reach r ON l.from_id = r.id WHERE l.kind = 'blocks')
SELECT EXISTS (SELECT 1 FROM reach WHERE id = $from);   -- true → 409 cycle
INSERT INTO work_item_links ...;
```
`UNION` (not `UNION ALL`) terminates on existing cycles. Parent moves take the same advisory lock.

**Time log ≤ 1440 min/user/day:**
```sql
SELECT pg_advisory_xact_lock(hashtextextended('time_log:' || $user || ':' || $day, 0));
SELECT COALESCE(sum(minutes),0) FROM work_item_time_logs WHERE user_id = $1 AND logged_on = $2;   -- + new > 1440 → 422
INSERT ...;
```
Xact-scoped advisory locks are safe behind the Neon transaction pooler; session-scoped ones are not.

**Dedup** (index-backed; `similarity() > x` never uses the index):
```sql
BEGIN; SET LOCAL pg_trgm.similarity_threshold = 0.4;
SELECT id, key_num, title, similarity(title, $2) AS sim FROM work_items
 WHERE project_id = $1 AND archived_at IS NULL AND status NOT IN ('done','wont_do') AND title % $2
 ORDER BY sim DESC LIMIT 5;
COMMIT;
```
Use `SET LOCAL`, not `set_limit()`, which is session-scoped and unsafe on the pooler. The same pattern applies to `requirement_questions.question`.

## 5. Migration files (apply order ↔ phase)
Ship each file with the phase whose code uses it. Don't create Phase 3–5 tables early (YAGNI, and less schema drift).

| # | File | Phase | Contents |
|---|---|---|---|
| 036 | `036_project_workspace_core.sql` / `.down.sql` | 1 | `project_requirements` columns, CHECKs, indexes; `project_members`, `project_tracks`, `project_track_members`, `project_interests`, `requirement_versions`, `onboarding_steps`, `onboarding_progress`; `projects.create` seed |
| 037 | `037_work_items.sql` / `.down.sql` | 2 | `work_items`, `work_item_assignees`, `work_item_links`, `work_item_events`, `work_item_watchers`; `comments.subject_type` widened |
| 038 | `038_project_tasks_backfill.sql` / `.down.sql` | 2 (Release B) | map tables, `mf_migrate_project_tasks()`, first run |
| 039 | `039_drop_project_tasks.sql` / `.down.sql` | 2 (Release C, after B is live) | catch-up run, drop function, drop `project_tasks`; down recreates and repopulates |
| 040 | `040_requirement_clarification_doc_gate.sql` / `.down.sql` | 3 | `requirement_questions`, `brief_approvals`, `work_item_reviews`, `project_meetings`, `meeting_attendance`, `standup_updates`, `project_ai_cache` |
| 041 | `041_work_item_gitlab_time_logs.sql` / `.down.sql` | 4 | `gitlab_merge_requests.head_pipeline_status`, `work_item_gitlab`, `work_item_time_logs` |
| 042 | `042_releases_sprints_completion.sql` / `.down.sql` | 5 | `releases`, `release_snapshots`, `sprints`, `work_items.release_id/sprint_id` + FKs, `peer_feedback`, `project_members.showcase_opt_in` |

Every file that alters an existing table starts with `SET LOCAL lock_timeout = '5s'`. A blocked `ACCESS EXCLUSIVE` then fails the startup migration instead of queueing all traffic behind it. Numbers are claimed by filename: renumber if another branch lands 036 first. The runner will happily apply two `036_*` files, as it already did with `002_*`.

Repo-layer tests must use `internal/testdb`, including one test that runs 038 against seeded `project_tasks` and asserts keys, statuses and owners.

## 6. Risks
1. **Shared prod DB plus auto-migrate on startup.** Running any feature branch locally applies its migrations to production, permanently: they're tracked by filename, and downs are manual. Develop migrations against a Neon branch (a `DATABASE_URL` override) or `internal/testdb` only, and merge to main before any run against the shared DB. This matters most for 038/039.
2. **Dropping `project_tasks` couples every classroom team to a workspace.**
   - 038 creates synthetic `project_requirements` rows, one per team with tasks.
   - Every future `CreateTeam` path, and the task endpoints, must call `EnsureWorkspaceForTeam` in the same tx.
   - `checkpoint_id` grouping on tasks is lost from the UI.
   - The alternative is to keep `project_tasks` for the classroom product and skip 038/039. That needs a product decision before Phase 2.
3. **Two status columns and two intakes.** `status` and `project_status` are held together by `project_requirements_status_sync_chk`, but every lifecycle write must update both in one statement. The legacy board (`status='open'`) will list workspaces unless it filters `project_status IS NULL`. Applications vs interests must be one intake per project.
4. **Hot project row.** Item create (`item_seq`), seat accept and project edits all lock `project_requirements(id)`. This is fine at ≤ tens of writes per second per project. The upgrade path is a separate `project_counters` row if contention is measured.
5. **Webhook fan-out.** One push can reference many keys. Linking must be per `(item, kind, ref)` upsert, with replay safety coming from `gitlab_webhook_events`.
6. **The wiki trgm index from 035 is unused today** (see §0). This is a separate small fix in the wiki slice.

## 7. Design-doc corrections (§17 and elsewhere)
- `wiki_page_versions` / `approved_doc_version_id` / `wiki_version_id` → there is no such table. Use `content_versions` implicitly and store integer `approved_doc_version` / `wiki_version` compared against `wiki_pages.version`. The wiki `CreatePage` must also write the v1 `content_versions` row.
- `org invite (role=student)` → `learner`. Invites aren't project-scoped: link them via `project_interests.invite_id` (non-unique, because of `uq_org_invite_pending`).
- `project.create` → `projects.create` (the module convention is `projects.*`).
- `raw_requirement` column → reuse the existing `brief` column. `requirement_versions` holds the history.
- `project_interests.requirement_id` → `project_id`. `UNIQUE(project_id, lower(email))` → `citext` plus a plain UNIQUE.
- `work_item_gitlab.gitlab_event_id UNIQUE` is wrong: one event touches many items, and one MR has many events. Use `UNIQUE(item_id, kind, gitlab_ref)` and join `gitlab_merge_requests` for state. Pipeline status goes on the MR row.
- `work_item_assignees` PK alone doesn't give "exactly one owner": add the partial unique index.
- The parent "cycle-free" check is redundant given the type ladder; keep it only for `blocks`.
- §2 "only `draft` items … can be deleted", but §9 defines no `draft` item status. Either add `draft` or change the rule to "`todo` items with only a `create` event".
- Missing tables/columns:
  - `work_item_watchers` (§7.3)
  - `brief_approvals` (§6b)
  - `project_track_members.status` (§6 lead approval)
  - `releases.target_at` (§16.6)
  - `release_snapshots` (§13)
  - an AI cache store (§6b, §16.9)
  - `meeting_attendance.occurrence_at` (recurring standups share one `calendar_event_id`)
  - `project_members.showcase_opt_in` (§15)
  - item comments: widen `comments.subject_type`
- `work_item_events.kind` needs more than `status|assign|link|doc|comment`, plus a `source` column for gitlab/system/import.
- "Seat" isn't defined. Proposed: active manager/member rows plus accepted-pending interests; owner and viewers excluded.
- Project lifecycle audit has no table. Reuse the existing `audit_logs` (`orgs/audit.go`) plus the `activated_at`/`brief_agreed_at` columns.

### Critical Files for Implementation
- C:\dev\dream\mindforge\backend\db\migrate.go
- C:\dev\dream\mindforge\backend\db\migrations\020_project_marketplace.sql
- C:\dev\dream\mindforge\backend\db\migrations\022_project_sdlc_workflow.sql
- C:\dev\dream\mindforge\backend\internal\gitlab\repo_task.go
- C:\dev\dream\mindforge\backend\internal\orgs\invite.go
- C:\dev\dream\mindforge\backend\internal\wiki\repo.go