DROP INDEX IF EXISTS idx_learning_journal_entries_user_category_subcategory;
CREATE INDEX idx_learning_journal_entries_user_category
    ON public.learning_journal_entries (user_id, category);
ALTER TABLE public.learning_journal_entries
    DROP CONSTRAINT IF EXISTS learning_journal_entries_subcategory_len_check;
ALTER TABLE public.learning_journal_entries
    DROP COLUMN IF EXISTS subcategory;
