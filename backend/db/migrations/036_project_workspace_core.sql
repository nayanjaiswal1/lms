-- ══════════════════════════════════════════════════════════════════════════
-- 036_project_workspace_core.sql — Project Workspace, Phase 1
--
-- Own table workspace_projects (docs/project-workspace-plan/00-decisions.md
-- D1): the marketplace's project_requirements/project_applications stay
-- untouched. Members, tracks, public interests, requirement history and the
-- onboarding checklist hang off it. wiki_spaces gains project_id for the
-- project-scoped space (D10). Permission seeds: projects.create,
-- projects.oversee (D5).
--
-- The runner wraps this file in one transaction, so no CONCURRENTLY; the
-- lock_timeout makes a blocked ALTER on wiki_spaces fail the startup
-- migration instead of queueing live traffic behind it (D18).
-- ══════════════════════════════════════════════════════════════════════════
SET LOCAL lock_timeout = '5s';

CREATE TABLE public.workspace_projects (
  id                     uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  org_id                 uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  title                  text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 3 AND 200),
  -- Raw requirement as the owner wrote it (current version); history lives in requirement_versions.
  requirement            text NOT NULL CHECK (char_length(requirement) BETWEEN 50 AND 20000),
  requirement_version    integer NOT NULL DEFAULT 1 CHECK (requirement_version >= 1),
  skills                 text[] NOT NULL DEFAULT '{}' CHECK (cardinality(skills) <= 30),
  team_size_min          integer NOT NULL CHECK (team_size_min >= 2),
  team_size_max          integer NOT NULL CHECK (team_size_max <= 50),
  interest_deadline      timestamptz,
  key_prefix             text NOT NULL CHECK (key_prefix ~ '^[A-Z]{2,6}$'),
  project_status         text NOT NULL DEFAULT 'draft'
                         CHECK (project_status IN ('draft','recruiting','active','paused','completed','cancelled','archived')),
  brief_status           text NOT NULL DEFAULT 'raw' CHECK (brief_status IN ('raw','clarifying','agreed')),
  share_token            text NOT NULL CHECK (char_length(share_token) BETWEEN 22 AND 64),
  share_token_rotated_at timestamptz,
  accepting_interests    boolean NOT NULL DEFAULT true,
  brief_wiki_page_id     uuid REFERENCES public.wiki_pages(id),           -- NO ACTION: the agreed brief can't silently vanish
  team_id                uuid REFERENCES public.project_teams(id) ON DELETE SET NULL,
  gitlab_enabled         boolean NOT NULL DEFAULT true,
  sprints_enabled        boolean NOT NULL DEFAULT false,
  wip_limit              integer NOT NULL DEFAULT 3 CHECK (wip_limit BETWEEN 1 AND 50),
  item_seq               integer NOT NULL DEFAULT 0 CHECK (item_seq >= 0),
  health_thresholds      jsonb NOT NULL DEFAULT
    '{"s1_open_hours":24,"forecast_red_pct":20,"blocked_red_pct":25,"review_wait_days":3,"reopen_yellow_pct":20}',
  activated_at           timestamptz,
  brief_agreed_at        timestamptz,
  completed_at           timestamptz,
  feedback_closes_at     timestamptz,
  created_by             uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at             timestamptz DEFAULT now() NOT NULL,
  updated_at             timestamptz DEFAULT now() NOT NULL,
  CHECK (team_size_min <= team_size_max),
  CHECK ((project_status = 'completed') = (completed_at IS NOT NULL) OR project_status = 'archived')
);
CREATE UNIQUE INDEX uq_workspace_projects_share_token ON public.workspace_projects (share_token);
CREATE UNIQUE INDEX uq_workspace_projects_key_prefix ON public.workspace_projects (org_id, key_prefix);
CREATE UNIQUE INDEX uq_workspace_projects_team ON public.workspace_projects (team_id) WHERE team_id IS NOT NULL;
CREATE INDEX idx_workspace_projects_org ON public.workspace_projects (org_id, project_status, created_at DESC, id);

CREATE TABLE public.project_members (
  project_id  uuid NOT NULL REFERENCES public.workspace_projects(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role        text NOT NULL CHECK (role IN ('owner','manager','member','viewer')),
  status      text NOT NULL DEFAULT 'active' CHECK (status IN ('invited','active','left','removed')),
  added_by    uuid REFERENCES public.users(id) ON DELETE SET NULL,
  joined_at   timestamptz DEFAULT now() NOT NULL,
  left_at     timestamptz,
  updated_at  timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (project_id, user_id),
  CHECK ((status IN ('left','removed')) = (left_at IS NOT NULL)),
  CHECK (role <> 'owner' OR status = 'active')          -- owner can't leave; transfer first
);
CREATE UNIQUE INDEX uq_project_members_one_owner ON public.project_members (project_id) WHERE role = 'owner';
CREATE INDEX idx_project_members_user ON public.project_members (user_id, status);

CREATE TABLE public.project_tracks (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id   uuid NOT NULL REFERENCES public.workspace_projects(id) ON DELETE CASCADE,
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
  status      text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved')),
  approved_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at  timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (track_id, user_id),
  FOREIGN KEY (track_id, project_id) REFERENCES public.project_tracks(id, project_id) ON DELETE CASCADE,
  FOREIGN KEY (project_id, user_id) REFERENCES public.project_members(project_id, user_id) ON DELETE CASCADE
);
CREATE INDEX idx_project_track_members_member ON public.project_track_members (project_id, user_id);

CREATE TABLE public.project_interests (
  id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id    uuid NOT NULL REFERENCES public.workspace_projects(id) ON DELETE CASCADE,
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
  UNIQUE (project_id, email),                         -- citext: case-insensitive
  CHECK (status = 'new' OR reviewed_at IS NOT NULL)
);
CREATE INDEX idx_project_interests_review ON public.project_interests (project_id, status, created_at DESC, id);
CREATE INDEX idx_project_interests_invite ON public.project_interests (invite_id) WHERE invite_id IS NOT NULL;
CREATE INDEX idx_project_interests_purge  ON public.project_interests (updated_at) WHERE status IN ('new','rejected','invite_expired');

CREATE TABLE public.requirement_versions (
  project_id      uuid NOT NULL REFERENCES public.workspace_projects(id) ON DELETE CASCADE,
  version         integer NOT NULL CHECK (version >= 1),
  raw_requirement text NOT NULL CHECK (char_length(raw_requirement) BETWEEN 50 AND 20000),
  created_by      uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at      timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (project_id, version)
);

CREATE TABLE public.onboarding_steps (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id   uuid NOT NULL REFERENCES public.workspace_projects(id) ON DELETE CASCADE,
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

-- Project-scoped wiki space: read = active project members + overseers,
-- edit = project member+, instead of the org-wide space ACL (02 §7.0).
ALTER TABLE public.wiki_spaces
  ADD COLUMN project_id uuid REFERENCES public.workspace_projects(id) ON DELETE CASCADE;
CREATE UNIQUE INDEX uq_wiki_spaces_project ON public.wiki_spaces (project_id) WHERE project_id IS NOT NULL;

INSERT INTO public.permissions (code, name, description, module)
VALUES
  ('projects.create',  'Create Project Workspaces', 'Create a project workspace (share link, team, work items) and become its owner', 'projects'),
  ('projects.oversee', 'Oversee Project Workspaces', 'Act as owner on every project workspace in the organization', 'projects')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.role_id, p.id
FROM public.permissions p
JOIN (VALUES
  ('11111111-1111-1111-1111-000000000003'::uuid, 'projects.create'),   -- instructor
  ('11111111-1111-1111-1111-000000000004'::uuid, 'projects.create'),   -- mentor
  ('11111111-1111-1111-1111-000000000005'::uuid, 'projects.create'),   -- tenant_admin
  ('11111111-1111-1111-1111-000000000005'::uuid, 'projects.oversee')   -- tenant_admin
) AS r(role_id, code) ON r.code = p.code
ON CONFLICT DO NOTHING;
