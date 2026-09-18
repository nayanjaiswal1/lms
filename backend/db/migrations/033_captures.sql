-- Knowledge Captures — the "I screenshotted a reel/LinkedIn post/article and
-- never opened it again" inbox. A capture ingests a screenshot, a PDF, or a
-- link, extracts its text (OCR / pdftotext / server-side fetch, done
-- asynchronously by the captures.process job), then reuses the existing AI
-- structuring + dedup mechanisms rather than inventing new ones:
--   kind = 'note'     -> promoted into learning_journal_entries, using the
--                        same similarity(title, ...) dedup journal already
--                        trusts (see internal/journal/repo.go FindSimilarEntries).
--   kind = 'question' -> promoted into srs_cards (source_type = 'capture'),
--                        the existing generic SM-2 card table — no schema
--                        change needed there, it was never actually locked to
--                        course modules (see internal/srs/models.go).
-- No pgvector/embeddings: title-trigram is the same mechanism journal already
-- ships with, and the AI-generated title is already normalized text, not raw
-- OCR noise, so it's the same bet journal already made — upgrade path is
-- identical to journal's own noted one if this proves insufficient in practice.
CREATE TABLE public.captures (
    id              uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id         uuid NOT NULL,
    type            text NOT NULL,
    storage_key     text,
    source_url      text,
    status          text NOT NULL DEFAULT 'pending',
    extracted_text  text,
    kind            text,
    category        text,
    subcategory     text,
    title           text,
    content         text,
    journal_entry_id uuid,
    srs_card_id     uuid,
    error_message   text,
    created_at      timestamptz DEFAULT now() NOT NULL,
    processed_at    timestamptz,
    CONSTRAINT captures_pkey PRIMARY KEY (id),
    CONSTRAINT captures_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT captures_journal_entry_id_fkey
        FOREIGN KEY (journal_entry_id) REFERENCES public.learning_journal_entries(id) ON DELETE SET NULL,
    CONSTRAINT captures_srs_card_id_fkey
        FOREIGN KEY (srs_card_id) REFERENCES public.srs_cards(id) ON DELETE SET NULL,
    CONSTRAINT captures_type_check CHECK (type IN ('image', 'pdf', 'link', 'html')),
    CONSTRAINT captures_status_check CHECK (status IN ('pending', 'processing', 'ready', 'failed', 'promoted', 'dismissed')),
    CONSTRAINT captures_kind_check CHECK (kind IS NULL OR kind IN ('note', 'question')),
    CONSTRAINT captures_title_len_check CHECK (title IS NULL OR char_length(title) BETWEEN 1 AND 200),
    CONSTRAINT captures_content_len_check CHECK (content IS NULL OR char_length(content) BETWEEN 1 AND 20000)
);

-- Inbox listing: "my ready-to-review items", "my failed items to retry", etc.
CREATE INDEX idx_captures_user_status
    ON public.captures (user_id, status, created_at DESC);

-- srs_cards never had this before (nothing needed cross-card title matching
-- until now) — partial, only for capture-sourced cards, so it doesn't grow
-- unbounded with assessment/mistake cards that will never be queried this way.
CREATE INDEX idx_srs_cards_front_trgm_capture
    ON public.srs_cards USING gin (front public.gin_trgm_ops)
    WHERE source_type = 'capture';

INSERT INTO public.permissions (id, code, name, description, module, is_active, created_at, updated_at)
VALUES (gen_random_uuid(), 'content.captures', 'Knowledge Captures',
        'Capture and organize screenshots/PDFs/links into the journal or SRS cards', 'content', true, now(), now());

-- Same roles as content.learning_journal (member, mentor, org_admin, tenant_admin).
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.role_id, p.id
FROM (VALUES
    ('11111111-1111-1111-1111-000000000002'::uuid),
    ('11111111-1111-1111-1111-000000000003'::uuid),
    ('11111111-1111-1111-1111-000000000004'::uuid),
    ('11111111-1111-1111-1111-000000000005'::uuid)
) AS r(role_id), public.permissions p
WHERE p.code = 'content.captures'
ON CONFLICT DO NOTHING;
