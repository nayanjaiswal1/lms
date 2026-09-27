-- ══════════════════════════════════════════════════════════════════════════
-- 039_workspace_gitlab_timelogs_digests.sql — Project Workspace, Phase 4
--
-- GitLab ticket-key linking (work_item_gitlab, D9), MR pipeline status and
-- size on the existing MR mirror, per-person time logs, and one digest row
-- per project per day (digest idempotency + previous health colour, D11).
-- ══════════════════════════════════════════════════════════════════════════
SET LOCAL lock_timeout = '5s';

-- Stored once per MR (not per link); additions/deletions back the MR-size
-- metric (flag > 400 lines). Nullable, no default → metadata-only ALTER.
ALTER TABLE public.gitlab_merge_requests
  ADD COLUMN head_pipeline_status text
    CHECK (head_pipeline_status IS NULL OR head_pipeline_status IN ('pending','running','success','failed','canceled')),
  ADD COLUMN additions integer CHECK (additions IS NULL OR additions >= 0),
  ADD COLUMN deletions integer CHECK (deletions IS NULL OR deletions >= 0);

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
CREATE INDEX idx_work_item_gitlab_pending ON public.work_item_gitlab (updated_at) WHERE sync_status = 'pending';

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
CREATE INDEX idx_work_item_time_logs_item ON public.work_item_time_logs (item_id, created_at DESC, id);

CREATE TABLE public.workspace_digests (
  project_id   uuid NOT NULL REFERENCES public.workspace_projects(id) ON DELETE CASCADE,
  digest_date  date NOT NULL,
  health_color text NOT NULL CHECK (health_color IN ('green','yellow','red')),
  sent_at      timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (project_id, digest_date)
);
