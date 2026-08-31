-- Smart Digital Diary — one free-form prose entry per user per calendar day.
-- Distinct from learning_journal_entries (a topic-tagged "what I learned"
-- log): this is a single running "Today" entry, and its AI analysis writes
-- INTO the existing habit/whatnow domains (habit completions, whatnow
-- tasks) rather than owning duplicate habit/checklist data itself — see
-- internal/diary/service.go's Analyze. ai_analysis/analyzed_hash/analyzed_at
-- cache the last AI pass over content so an unchanged save doesn't re-run it.
CREATE TABLE public.diary_entries (
    id            uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id       uuid NOT NULL,
    entry_date    date NOT NULL DEFAULT CURRENT_DATE,
    content       text NOT NULL DEFAULT '',
    ai_analysis   jsonb,
    analyzed_hash text,
    analyzed_at   timestamptz,
    created_at    timestamptz DEFAULT now() NOT NULL,
    updated_at    timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT diary_entries_pkey PRIMARY KEY (id),
    CONSTRAINT diary_entries_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT diary_entries_user_date_unique UNIQUE (user_id, entry_date),
    CONSTRAINT diary_entries_content_len_check CHECK (char_length(content) <= 20000)
);

CREATE INDEX idx_diary_entries_user_date
    ON public.diary_entries (user_id, entry_date DESC);

INSERT INTO public.permissions (id, code, name, description, module, is_active, created_at, updated_at)
VALUES (gen_random_uuid(), 'content.diary', 'Diary',
        'Access the personal digital diary', 'content', true, now(), now());

-- Grant to the same roles content.learning_journal is granted to (member,
-- mentor, org_admin, tenant_admin — role ids 002/003/004/005 in 001_baseline.sql).
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.role_id, p.id
FROM (VALUES
    ('11111111-1111-1111-1111-000000000002'::uuid),
    ('11111111-1111-1111-1111-000000000003'::uuid),
    ('11111111-1111-1111-1111-000000000004'::uuid),
    ('11111111-1111-1111-1111-000000000005'::uuid)
) AS r(role_id), public.permissions p
WHERE p.code = 'content.diary'
ON CONFLICT DO NOTHING;
