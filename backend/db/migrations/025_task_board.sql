-- Linked Task Board — extends whatnow_tasks with tags/urgency/importance/body,
-- plus two new tables: task_links (polymorphic task -> {task, note, project}
-- links, rendered as chips under a task) and task_templates (saved reusable
-- field sets, e.g. a "stuck protocol" — instantiating one reads the template
-- and creates a new task, the template row itself is never mutated).

-- tags: same pattern as habits.tags (011_habit_tags_icon.sql).
ALTER TABLE public.whatnow_tasks
    ADD COLUMN tags text[] NOT NULL DEFAULT '{}'::text[];

-- body: general optional free-text notes on a task. Deliberately a new
-- column rather than reusing resume_note, which is a live single-purpose
-- field for the pause/resume workflow (rendered with a resume mark in
-- now-stage.tsx) — repurposing it for template answers would let a later
-- pause silently overwrite them.
ALTER TABLE public.whatnow_tasks
    ADD COLUMN body text;

-- urgency/importance: independent and nullable. A task missing either axis
-- must stay list-only in the board UI, never forced into a matrix quadrant.
ALTER TABLE public.whatnow_tasks
    ADD COLUMN urgency    text,
    ADD COLUMN importance text,
    ADD CONSTRAINT whatnow_tasks_urgency_check
        CHECK (urgency IS NULL OR urgency = ANY (ARRAY['urgent'::text, 'not_urgent'::text])),
    ADD CONSTRAINT whatnow_tasks_importance_check
        CHECK (importance IS NULL OR importance = ANY (ARRAY['important'::text, 'not_important'::text]));

-- Deliberately no CHECK constraint on whatnow_tasks.category: it stays free
-- text so existing #hashtag categories from whatnow.ParseCapture keep
-- working. The board's own create/edit UI restricts its dropdown to
-- buy/health/learn/research/stuck/other client-side only.

-- Polymorphic link: a task links out to another task, a diary entry, a
-- learning-journal entry, or a project. No FK on target_id since targets
-- live in different tables depending on target_type — validated in the Go
-- service layer instead, the same trust boundary whatnow_tasks.depends_on
-- already uses today.
CREATE TABLE public.task_links (
    id             uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id        uuid NOT NULL,
    source_task_id uuid NOT NULL,
    target_type    text NOT NULL,
    target_id      uuid NOT NULL,
    target_label   text NOT NULL,
    created_at     timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT task_links_pkey PRIMARY KEY (id),
    CONSTRAINT task_links_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT task_links_source_task_fkey
        FOREIGN KEY (source_task_id) REFERENCES public.whatnow_tasks(id) ON DELETE CASCADE,
    CONSTRAINT task_links_target_type_check
        CHECK (target_type = ANY (ARRAY['task'::text, 'diary_entry'::text, 'journal_entry'::text, 'project'::text])),
    CONSTRAINT task_links_unique UNIQUE (source_task_id, target_type, target_id)
);

CREATE INDEX idx_task_links_source ON public.task_links (source_task_id);

-- Saved template shell. fields is a jsonb array of {id, label, kind} used to
-- render a dynamic form on instantiate; instantiating only READS this row.
CREATE TABLE public.task_templates (
    id         uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id    uuid NOT NULL,
    name       text NOT NULL,
    fields     jsonb NOT NULL DEFAULT '[]'::jsonb,
    created_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT task_templates_pkey PRIMARY KEY (id),
    CONSTRAINT task_templates_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT task_templates_name_len_check CHECK (char_length(name) BETWEEN 1 AND 120)
);
