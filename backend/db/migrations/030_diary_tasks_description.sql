ALTER TABLE public.diary_tasks ADD COLUMN description text NOT NULL DEFAULT '';
ALTER TABLE public.diary_tasks ADD CONSTRAINT diary_tasks_description_len_check CHECK (char_length(description) <= 2000);
