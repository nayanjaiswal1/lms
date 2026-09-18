-- "What's new" changelog entries shown in the sidebar's sparkle-icon panel
-- (frontend/components/shared/whats-new-dialog.tsx). Previously a hardcoded
-- WHATS_NEW array in frontend/lib/whats-new.ts — every release note required
-- a rebuild+redeploy. Moving it here lets a platform admin publish an entry
-- from /platform/whats-new without touching code, same rationale as
-- 004_pricing_tiers.sql.
CREATE TABLE public.whats_new_entries (
    id           uuid DEFAULT gen_random_uuid() NOT NULL,
    title        text NOT NULL,
    description  text NOT NULL,
    icon         text NOT NULL DEFAULT 'sparkles',
    cta_label    text NOT NULL,
    cta_href     text NOT NULL,
    published    boolean NOT NULL DEFAULT true,
    published_at timestamptz DEFAULT now() NOT NULL,
    created_by   uuid,
    updated_at   timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT whats_new_entries_pkey PRIMARY KEY (id),
    CONSTRAINT whats_new_entries_created_by_fkey
        FOREIGN KEY (created_by) REFERENCES public.users(id) ON DELETE SET NULL,
    CONSTRAINT whats_new_entries_icon_check
        CHECK (icon IN ('sparkles', 'book-open-check', 'list-checks', 'shield-check', 'rocket', 'megaphone', 'zap', 'star')),
    CONSTRAINT whats_new_entries_title_len_check CHECK (char_length(title) BETWEEN 1 AND 120),
    CONSTRAINT whats_new_entries_description_len_check CHECK (char_length(description) BETWEEN 1 AND 500),
    CONSTRAINT whats_new_entries_cta_label_len_check CHECK (char_length(cta_label) BETWEEN 1 AND 40)
);

CREATE INDEX idx_whats_new_entries_published
    ON public.whats_new_entries (published, published_at DESC);
