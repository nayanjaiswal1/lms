DROP TABLE IF EXISTS public.workspace_ai_cache;
DROP TABLE IF EXISTS public.standup_updates;
DROP TABLE IF EXISTS public.meeting_attendance;
DROP TABLE IF EXISTS public.project_meetings;
DROP TABLE IF EXISTS public.work_item_reviews;
DROP TABLE IF EXISTS public.brief_approvals;
DROP TABLE IF EXISTS public.requirement_questions;

ALTER TABLE public.comments DROP CONSTRAINT IF EXISTS comments_subject_type_check;
ALTER TABLE public.comments ADD CONSTRAINT comments_subject_type_check
  CHECK (subject_type = ANY (ARRAY['wiki_page','interview_exp_qna']));
