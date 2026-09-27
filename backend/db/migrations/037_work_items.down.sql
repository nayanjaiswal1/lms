SET LOCAL lock_timeout = '5s';

-- Fails if work_item / requirement_question comments exist, which is correct:
-- deleting them silently would lose discussion history.
ALTER TABLE public.comments DROP CONSTRAINT comments_subject_type_check,
  ADD CONSTRAINT comments_subject_type_check CHECK (subject_type IN ('wiki_page','interview_exp_qna'));

DROP TABLE IF EXISTS public.work_item_events;
DROP TABLE IF EXISTS public.work_item_links;
DROP TABLE IF EXISTS public.work_item_assignees;
DROP TABLE IF EXISTS public.work_items;
