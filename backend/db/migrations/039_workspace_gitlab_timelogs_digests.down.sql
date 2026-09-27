SET LOCAL lock_timeout = '5s';

DROP TABLE IF EXISTS public.workspace_digests;
DROP TABLE IF EXISTS public.work_item_time_logs;
DROP TABLE IF EXISTS public.work_item_gitlab;

ALTER TABLE public.gitlab_merge_requests
  DROP COLUMN IF EXISTS deletions,
  DROP COLUMN IF EXISTS additions,
  DROP COLUMN IF EXISTS head_pipeline_status;
