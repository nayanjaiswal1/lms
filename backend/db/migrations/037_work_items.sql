-- ══════════════════════════════════════════════════════════════════════════
-- 037_work_items.sql — Project Workspace, Phase 2
--
-- Epic → Feature → Task/Bug → Subtask work items with per-project keys
-- ({key_prefix}-{key_num}), multi-role assignees, blocks/relates/duplicates
-- links and an append-only event log. project_tasks (classroom teams) is not
-- touched (00-decisions D2). comments.subject_type widens for item and
-- requirement-question threads (D11).
--
-- Composite FKs (x_id, project_id) → t(id, project_id) keep parents, tracks,
-- links and events inside one project at the database level.
-- ══════════════════════════════════════════════════════════════════════════
SET LOCAL lock_timeout = '5s';

CREATE TABLE public.work_items (
  id                   uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id           uuid NOT NULL REFERENCES public.workspace_projects(id) ON DELETE CASCADE,
  key_num              integer NOT NULL CHECK (key_num > 0),
  type                 text NOT NULL CHECK (type IN ('epic','feature','task','bug','subtask')),   -- immutable after create
  parent_id            uuid,
  -- Ancestor pointers maintained with parent_id so roll-ups need no recursive CTE (D11).
  epic_id              uuid,
  feature_id           uuid,
  track_id             uuid,
  title                text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 300),
  description          text CHECK (description IS NULL OR char_length(description) <= 50000),
  status               text NOT NULL DEFAULT 'todo',
  priority             text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low','medium','high','urgent')),
  severity             text CHECK (severity IN ('S1','S2','S3','S4')),
  is_regression        boolean NOT NULL DEFAULT false,
  estimate_minutes     integer CHECK (estimate_minutes IS NULL OR estimate_minutes BETWEEN 1 AND 100000),
  doc_wiki_page_id     uuid REFERENCES public.wiki_pages(id),            -- NO ACTION
  doc_status           text CHECK (doc_status IN ('draft','in_review','changes_requested','approved')),
  approved_doc_version integer CHECK (approved_doc_version IS NULL OR approved_doc_version >= 1),  -- = wiki_pages.version at approval
  spec_changed_at      timestamptz,                                       -- set on a task when its feature's approved spec changes
  blocked_reason       text CHECK (blocked_reason IS NULL OR char_length(blocked_reason) <= 2000),
  reopen_count         integer NOT NULL DEFAULT 0 CHECK (reopen_count >= 0),
  version              integer NOT NULL DEFAULT 1 CHECK (version >= 1),  -- optimistic lock
  due_at               timestamptz,
  created_by           uuid REFERENCES public.users(id) ON DELETE SET NULL,
  archived_at          timestamptz,
  created_at           timestamptz DEFAULT now() NOT NULL,
  updated_at           timestamptz DEFAULT now() NOT NULL,
  UNIQUE (project_id, key_num),
  UNIQUE (id, project_id),
  FOREIGN KEY (parent_id, project_id)  REFERENCES public.work_items(id, project_id),       -- NO ACTION: a parent with children can't be deleted
  FOREIGN KEY (epic_id, project_id)    REFERENCES public.work_items(id, project_id),
  FOREIGN KEY (feature_id, project_id) REFERENCES public.work_items(id, project_id),
  FOREIGN KEY (track_id, project_id)   REFERENCES public.project_tracks(id, project_id),  -- a track in use can't be deleted
  CHECK (parent_id IS NULL OR parent_id <> id),
  CHECK (type <> 'epic' OR (parent_id IS NULL AND epic_id IS NULL AND feature_id IS NULL)),
  CHECK (type <> 'feature' OR feature_id IS NULL),
  CHECK (type <> 'subtask' OR parent_id IS NOT NULL),
  CHECK ((type IN ('epic','feature') AND status IN ('todo','in_progress','done','wont_do'))
      OR (type NOT IN ('epic','feature') AND status IN ('todo','in_progress','in_review','testing','done','blocked','reopened','wont_do'))),
  CHECK (type = 'bug' OR (severity IS NULL AND NOT is_regression)),
  CHECK (type = 'feature' OR (doc_wiki_page_id IS NULL AND doc_status IS NULL AND approved_doc_version IS NULL)),
  CHECK ((doc_wiki_page_id IS NULL) = (doc_status IS NULL)),
  CHECK (status = 'blocked' OR blocked_reason IS NULL)
);
CREATE INDEX idx_work_items_project_status ON public.work_items (project_id, status) WHERE archived_at IS NULL;
CREATE INDEX idx_work_items_project_type ON public.work_items (project_id, type, status) WHERE archived_at IS NULL;
CREATE INDEX idx_work_items_list ON public.work_items (project_id, created_at DESC, id) WHERE archived_at IS NULL;
CREATE INDEX idx_work_items_parent ON public.work_items (parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX idx_work_items_epic ON public.work_items (epic_id) WHERE epic_id IS NOT NULL;
CREATE INDEX idx_work_items_feature ON public.work_items (feature_id) WHERE feature_id IS NOT NULL;
CREATE INDEX idx_work_items_track ON public.work_items (track_id, status) WHERE track_id IS NOT NULL;
CREATE INDEX idx_work_items_overdue ON public.work_items (project_id, due_at)
  WHERE due_at IS NOT NULL AND archived_at IS NULL AND status NOT IN ('done','wont_do');
CREATE INDEX idx_work_items_open_bugs ON public.work_items (project_id, severity, created_at)
  WHERE type = 'bug' AND status NOT IN ('done','wont_do');
CREATE UNIQUE INDEX uq_work_items_doc_page ON public.work_items (doc_wiki_page_id) WHERE doc_wiki_page_id IS NOT NULL;
-- Duplicate detection uses `title % $q` on exactly this column (not similarity() > x),
-- so the planner can use the index (01 §0 / D10).
CREATE INDEX idx_work_items_title_trgm ON public.work_items USING gin (title gin_trgm_ops) WHERE archived_at IS NULL;

CREATE TABLE public.work_item_assignees (
  item_id     uuid NOT NULL REFERENCES public.work_items(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role        text NOT NULL CHECK (role IN ('owner','developer','reviewer','tester')),
  assigned_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  assigned_at timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (item_id, user_id, role)
);
-- Exactly one owner per item: a concurrent second claim gets 23505 → 409.
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
CREATE INDEX idx_work_item_links_project ON public.work_item_links (project_id, kind);
CREATE UNIQUE INDEX uq_work_item_links_relates ON public.work_item_links (LEAST(from_id, to_id), GREATEST(from_id, to_id)) WHERE kind = 'relates';
-- An item duplicates at most one original.
CREATE UNIQUE INDEX uq_work_item_links_one_original ON public.work_item_links (from_id) WHERE kind = 'duplicates';

CREATE TABLE public.work_item_events (           -- append-only: the repo exposes INSERT/SELECT only
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  project_id uuid NOT NULL,
  item_id    uuid NOT NULL,
  actor_id   uuid REFERENCES public.users(id) ON DELETE SET NULL,
  source     text NOT NULL DEFAULT 'user' CHECK (source IN ('user','gitlab','system')),
  kind       text NOT NULL CHECK (kind IN ('create','status','field','assign','unassign','link','unlink','parent',
                                           'severity','doc','review','sprint','release','archive')),
  field      text CHECK (field IS NULL OR char_length(field) <= 60),
  from_value text CHECK (from_value IS NULL OR char_length(from_value) <= 1000),
  to_value   text CHECK (to_value IS NULL OR char_length(to_value) <= 1000),
  reason     text CHECK (reason IS NULL OR char_length(reason) <= 2000),
  created_at timestamptz DEFAULT now() NOT NULL,
  FOREIGN KEY (item_id, project_id) REFERENCES public.work_items(id, project_id) ON DELETE CASCADE
);
CREATE INDEX idx_work_item_events_item ON public.work_item_events (item_id, id);
CREATE INDEX idx_work_item_events_project ON public.work_item_events (project_id, kind, created_at);
CREATE INDEX idx_work_item_events_project_time ON public.work_item_events (project_id, created_at);

ALTER TABLE public.comments DROP CONSTRAINT comments_subject_type_check,
  ADD CONSTRAINT comments_subject_type_check
    CHECK (subject_type IN ('wiki_page','interview_exp_qna','work_item','requirement_question'));
