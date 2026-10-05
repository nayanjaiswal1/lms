ALTER TABLE sheet_items ADD COLUMN metadata jsonb DEFAULT '{}'::jsonb NOT NULL;
