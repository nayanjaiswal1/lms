-- Lightweight personal project list. NOT project_requirements
-- (020_project_marketplace.sql — an org-scoped staff marketplace board, a
-- different domain entirely). Exists purely as a task_links target_type =
-- 'project' target and a simple named grouping list — no status workflow,
-- no members, no marketplace fields, no detail page beyond create + list.
CREATE TABLE public.projects (
    id          uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id     uuid NOT NULL,
    name        text NOT NULL,
    description text NOT NULL DEFAULT '',
    created_at  timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT projects_pkey PRIMARY KEY (id),
    CONSTRAINT projects_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT projects_name_len_check CHECK (char_length(name) BETWEEN 1 AND 120)
);

CREATE INDEX idx_projects_user ON public.projects (user_id, created_at DESC);
