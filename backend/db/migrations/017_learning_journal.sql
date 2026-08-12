-- Personal "Learning Journal" — a day-by-day log of what the user learned,
-- under a free-typed category (English, Backend, DSA, ...). User-owned only
-- (no org_id column), same shape as habits/sheets. FindSimilarEntries (see
-- internal/journal/repo.go) reuses the pg_trgm similarity() mechanism
-- courses.Repo.FindSimilarSelfCourse already uses, hence the trigram index.
CREATE TABLE public.learning_journal_entries (
    id          uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id     uuid NOT NULL,
    entry_date  date NOT NULL DEFAULT CURRENT_DATE,
    category    text NOT NULL,
    title       text NOT NULL,
    content     text NOT NULL,
    created_at  timestamptz DEFAULT now() NOT NULL,
    updated_at  timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT learning_journal_entries_pkey PRIMARY KEY (id),
    CONSTRAINT learning_journal_entries_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT learning_journal_entries_title_len_check CHECK (char_length(title) BETWEEN 1 AND 200),
    CONSTRAINT learning_journal_entries_category_len_check CHECK (char_length(category) BETWEEN 1 AND 60),
    CONSTRAINT learning_journal_entries_content_len_check CHECK (char_length(content) BETWEEN 1 AND 20000)
);

CREATE INDEX idx_learning_journal_entries_user_date
    ON public.learning_journal_entries (user_id, entry_date DESC, created_at DESC);
CREATE INDEX idx_learning_journal_entries_user_category
    ON public.learning_journal_entries (user_id, category);
CREATE INDEX idx_learning_journal_entries_title_trgm
    ON public.learning_journal_entries USING gin (title public.gin_trgm_ops);

INSERT INTO public.permissions (id, code, name, description, module, is_active, created_at, updated_at)
VALUES (gen_random_uuid(), 'content.learning_journal', 'Learning Journal',
        'Access the personal learning journal', 'content', true, now(), now());

-- Grant to every role content.sheets is granted to (member, mentor,
-- org_admin, tenant_admin — role ids 002/003/004/005 in 001_baseline.sql).
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.role_id, p.id
FROM (VALUES
    ('11111111-1111-1111-1111-000000000002'::uuid),
    ('11111111-1111-1111-1111-000000000003'::uuid),
    ('11111111-1111-1111-1111-000000000004'::uuid),
    ('11111111-1111-1111-1111-000000000005'::uuid)
) AS r(role_id), public.permissions p
WHERE p.code = 'content.learning_journal'
ON CONFLICT DO NOTHING;
