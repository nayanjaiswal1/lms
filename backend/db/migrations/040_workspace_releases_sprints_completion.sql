-- ══════════════════════════════════════════════════════════════════════════
-- 040_workspace_releases_sprints_completion.sql — Project Workspace, Phase 5
--
-- Releases (planned → frozen → released, with the spec version that shipped),
-- optional sprints with a commitment snapshot, work_items.release_id /
-- sprint_id, peer feedback and the showcase opt-in.
-- ══════════════════════════════════════════════════════════════════════════
SET LOCAL lock_timeout = '5s';

CREATE TABLE public.releases (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id  uuid NOT NULL REFERENCES public.workspace_projects(id) ON DELETE CASCADE,
  version     text NOT NULL CHECK (char_length(btrim(version)) BETWEEN 1 AND 40),
  status      text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','frozen','released')),
  target_at   timestamptz,
  frozen_at   timestamptz,
  released_at timestamptz,
  created_by  uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at  timestamptz DEFAULT now() NOT NULL,
  updated_at  timestamptz DEFAULT now() NOT NULL,
  UNIQUE (project_id, version),
  UNIQUE (id, project_id),
  CHECK ((status = 'released') = (released_at IS NOT NULL)),
  CHECK (status = 'planned' OR frozen_at IS NOT NULL)
);
CREATE INDEX idx_releases_project ON public.releases (project_id, created_at DESC, id);

-- "What spec shipped in v1.2" (design §13): item status + doc version at release.
CREATE TABLE public.release_snapshots (
  release_id  uuid NOT NULL REFERENCES public.releases(id) ON DELETE CASCADE,
  item_id     uuid NOT NULL REFERENCES public.work_items(id) ON DELETE CASCADE,
  doc_version integer,
  status      text NOT NULL,
  PRIMARY KEY (release_id, item_id)
);

CREATE TABLE public.sprints (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id uuid NOT NULL REFERENCES public.workspace_projects(id) ON DELETE CASCADE,
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

-- Snapshot at sprint start → "sprint commitment %" (D11).
CREATE TABLE public.sprint_commitments (
  sprint_id    uuid NOT NULL REFERENCES public.sprints(id) ON DELETE CASCADE,
  item_id      uuid NOT NULL REFERENCES public.work_items(id) ON DELETE CASCADE,
  committed_at timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (sprint_id, item_id)
);

ALTER TABLE public.work_items
  ADD COLUMN release_id uuid,
  ADD COLUMN sprint_id uuid,
  ADD CONSTRAINT work_items_release_fk FOREIGN KEY (release_id, project_id) REFERENCES public.releases(id, project_id),
  ADD CONSTRAINT work_items_sprint_fk  FOREIGN KEY (sprint_id, project_id)  REFERENCES public.sprints(id, project_id);
CREATE INDEX idx_work_items_release ON public.work_items (release_id, status) WHERE release_id IS NOT NULL;
CREATE INDEX idx_work_items_sprint  ON public.work_items (sprint_id, status)  WHERE sprint_id IS NOT NULL;

CREATE TABLE public.peer_feedback (
  id         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id uuid NOT NULL REFERENCES public.workspace_projects(id) ON DELETE CASCADE,
  from_user  uuid REFERENCES public.users(id) ON DELETE SET NULL,
  to_user    uuid REFERENCES public.users(id) ON DELETE SET NULL,
  rating     smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment    text CHECK (comment IS NULL OR char_length(comment) <= 2000),
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  UNIQUE (project_id, from_user, to_user),
  CHECK (from_user <> to_user)
);
CREATE INDEX idx_peer_feedback_to ON public.peer_feedback (to_user, project_id);

ALTER TABLE public.project_members ADD COLUMN showcase_opt_in boolean NOT NULL DEFAULT false;
