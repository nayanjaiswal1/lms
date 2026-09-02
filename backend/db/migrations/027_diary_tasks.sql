-- Diary-owned todo/buy checklist — replaces the diary's earlier read-only
-- projection of the What Now? inbox (whatnow_tasks). Diary no longer depends
-- on internal/whatnow at all: task_new/buy_new highlights detected in a diary
-- entry create rows here directly, and task_done highlights resolve against
-- this table instead of the whatnow inbox. See internal/diary/service.go.
CREATE TABLE public.diary_tasks (
    id              uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id         uuid NOT NULL,
    title           text NOT NULL,
    kind            text NOT NULL DEFAULT 'todo',
    tags            text[] NOT NULL DEFAULT '{}',
    done            boolean NOT NULL DEFAULT false,
    source_entry_id uuid,
    created_at      timestamptz DEFAULT now() NOT NULL,
    updated_at      timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT diary_tasks_pkey PRIMARY KEY (id),
    CONSTRAINT diary_tasks_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT diary_tasks_source_entry_fkey
        FOREIGN KEY (source_entry_id) REFERENCES public.diary_entries(id) ON DELETE SET NULL,
    CONSTRAINT diary_tasks_kind_check CHECK (kind IN ('todo', 'buy')),
    CONSTRAINT diary_tasks_title_len_check CHECK (char_length(title) BETWEEN 1 AND 300)
);

CREATE INDEX idx_diary_tasks_user_open
    ON public.diary_tasks (user_id, done, created_at DESC);

CREATE INDEX idx_diary_tasks_tags
    ON public.diary_tasks USING GIN (tags);
