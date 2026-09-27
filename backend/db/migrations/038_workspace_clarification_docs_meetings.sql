-- ══════════════════════════════════════════════════════════════════════════
-- 038_workspace_clarification_docs_meetings.sql — Project Workspace, Phase 3
--
-- Vague requirement → agreed brief (questions, two-person brief approval),
-- feature-spec / code reviews, meetings + attendance per occurrence, async
-- standups, and the workspace AI cache ("AI called once", D11).
-- Only new tables — nothing existing is altered.
-- ══════════════════════════════════════════════════════════════════════════

-- The shared `comments` table (001_baseline.sql) only allowed wiki_page /
-- interview_exp_qna subjects; question threads and item threads
-- (contract-phase3.md's comments section) reuse it rather than a new table.
SET LOCAL lock_timeout = '5s';
ALTER TABLE public.comments DROP CONSTRAINT comments_subject_type_check;
ALTER TABLE public.comments ADD CONSTRAINT comments_subject_type_check
  CHECK (subject_type = ANY (ARRAY['wiki_page','interview_exp_qna','requirement_question','work_item']));

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
  CHECK (NOT is_assumption OR answer IS NOT NULL)          -- an assumption must be written down
);
CREATE INDEX idx_requirement_questions_project ON public.requirement_questions (project_id, created_at DESC, id);
CREATE INDEX idx_requirement_questions_unanswered ON public.requirement_questions (created_at) WHERE answered_at IS NULL;
-- Duplicate check uses `question % $q` on exactly this column.
CREATE INDEX idx_requirement_questions_trgm ON public.requirement_questions USING gin (question gin_trgm_ops);

-- Brief sign-off: owner + a different manager/track lead on the same
-- requirement version and brief page version (design §6b, D13).
CREATE TABLE public.brief_approvals (
  project_id          uuid NOT NULL,
  requirement_version integer NOT NULL,
  approver_id         uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  approver_role       text NOT NULL CHECK (approver_role IN ('owner','manager','track_lead')),
  wiki_version        integer NOT NULL CHECK (wiki_version >= 1),
  created_at          timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (project_id, requirement_version, approver_id),
  FOREIGN KEY (project_id, requirement_version) REFERENCES public.requirement_versions(project_id, version) ON DELETE CASCADE
);

CREATE TABLE public.work_item_reviews (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  project_id       uuid NOT NULL,
  item_id          uuid NOT NULL,
  reviewer_id      uuid REFERENCES public.users(id) ON DELETE SET NULL,
  target           text NOT NULL CHECK (target IN ('doc','code')),
  verdict          text NOT NULL CHECK (verdict IN ('approved','changes_requested','commented')),
  comment          text CHECK (comment IS NULL OR char_length(comment) <= 10000),
  wiki_version     integer CHECK (wiki_version IS NULL OR wiki_version >= 1),
  merge_request_id uuid REFERENCES public.gitlab_merge_requests(id) ON DELETE SET NULL,
  created_at       timestamptz DEFAULT now() NOT NULL,
  FOREIGN KEY (item_id, project_id) REFERENCES public.work_items(id, project_id) ON DELETE CASCADE,
  CHECK ((target = 'doc') = (wiki_version IS NOT NULL)),
  CHECK (target = 'code' OR merge_request_id IS NULL),
  CHECK (verdict <> 'changes_requested' OR comment IS NOT NULL)
);
CREATE INDEX idx_work_item_reviews_item ON public.work_item_reviews (item_id, target, created_at);
CREATE INDEX idx_work_item_reviews_reviewer ON public.work_item_reviews (reviewer_id, created_at);
CREATE INDEX idx_work_item_reviews_project ON public.work_item_reviews (project_id, target, created_at);

CREATE TABLE public.project_meetings (
  calendar_event_id  uuid PRIMARY KEY REFERENCES public.calendar_events(id) ON DELETE CASCADE,
  project_id         uuid NOT NULL REFERENCES public.workspace_projects(id) ON DELETE CASCADE,
  kind               text NOT NULL CHECK (kind IN ('kickoff','sprint_planning','standup','design_review','retro','demo')),
  item_id            uuid REFERENCES public.work_items(id) ON DELETE SET NULL,     -- design review for a feature
  notes_wiki_page_id uuid REFERENCES public.wiki_pages(id) ON DELETE SET NULL,
  created_by         uuid REFERENCES public.users(id) ON DELETE SET NULL,
  created_at         timestamptz DEFAULT now() NOT NULL
);
CREATE INDEX idx_project_meetings_project ON public.project_meetings (project_id, kind, created_at DESC);

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
  project_id uuid NOT NULL REFERENCES public.workspace_projects(id) ON DELETE CASCADE,
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

-- AI called once: every cached suggestion keyed by what it was computed from
-- (requirement version, approved doc version, ISO week, date, release).
-- Assignee suggestion is deliberately not cached (D20).
CREATE TABLE public.workspace_ai_cache (
  project_id uuid NOT NULL REFERENCES public.workspace_projects(id) ON DELETE CASCADE,
  kind       text NOT NULL CHECK (kind IN ('requirement_gaps','epic_suggestions','task_breakdown','change_impact',
                                           'weekly_summary','late_explanation','release_notes')),
  cache_key  text NOT NULL CHECK (char_length(cache_key) BETWEEN 1 AND 200),
  output     jsonb NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  PRIMARY KEY (project_id, kind, cache_key)
);
