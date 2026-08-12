-- Learning journal entries move from a single free-typed category to a
-- category -> subcategory path (e.g. Backend / Redis), same free-typed
-- shape and length limit as category. Additive on top of 017 (already
-- applied), not a rewrite of the category column.
ALTER TABLE public.learning_journal_entries
    ADD COLUMN subcategory text NOT NULL DEFAULT 'General';
ALTER TABLE public.learning_journal_entries
    ALTER COLUMN subcategory DROP DEFAULT;
ALTER TABLE public.learning_journal_entries
    ADD CONSTRAINT learning_journal_entries_subcategory_len_check CHECK (char_length(subcategory) BETWEEN 1 AND 60);

-- Replaces idx_learning_journal_entries_user_category: the (user_id,
-- category) filter still hits this index as a prefix, and the filter chips
-- now need to narrow by subcategory within a category too.
DROP INDEX IF EXISTS idx_learning_journal_entries_user_category;
CREATE INDEX idx_learning_journal_entries_user_category_subcategory
    ON public.learning_journal_entries (user_id, category, subcategory);
