-- ═════════════════════════════════════════════════════════════════════════
-- Migration 012 — add_sheet_revision_settings
-- Per-(user, sheet) spaced-repetition configuration for the sheet tracker:
-- a base interval and a growth scheme, so successive reviews push
-- revision_at further out instead of reapplying the same interval every
-- time. Scoped per sheet, not globally per user, since different sheets
-- can warrant different revision cadences.
-- ═════════════════════════════════════════════════════════════════════════

CREATE TABLE public.user_sheet_settings (
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    sheet_id uuid NOT NULL REFERENCES public.sheets(id) ON DELETE CASCADE,
    base_revision_days integer DEFAULT 7 NOT NULL,
    growth_scheme text DEFAULT 'doubling' NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    PRIMARY KEY (user_id, sheet_id),
    CONSTRAINT user_sheet_settings_base_revision_days_check
        CHECK (base_revision_days BETWEEN 1 AND 365),
    CONSTRAINT user_sheet_settings_growth_scheme_check
        CHECK (growth_scheme IN ('doubling', 'ladder', 'linear'))
);
