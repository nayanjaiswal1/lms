DROP TABLE IF EXISTS public.gitlab_commit_files;
ALTER TABLE public.gitlab_merge_requests DROP COLUMN IF EXISTS ai_reviewed_at;
