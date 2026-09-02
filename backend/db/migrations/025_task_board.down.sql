DROP TABLE IF EXISTS public.task_templates;
DROP TABLE IF EXISTS public.task_links;

ALTER TABLE public.whatnow_tasks
    DROP CONSTRAINT IF EXISTS whatnow_tasks_importance_check,
    DROP CONSTRAINT IF EXISTS whatnow_tasks_urgency_check,
    DROP COLUMN IF EXISTS importance,
    DROP COLUMN IF EXISTS urgency,
    DROP COLUMN IF EXISTS body,
    DROP COLUMN IF EXISTS tags;
