ALTER TABLE courses ADD COLUMN kind text DEFAULT 'org'::text NOT NULL;
ALTER TABLE courses ADD COLUMN owner_id uuid;
ALTER TABLE courses ADD CONSTRAINT courses_kind_check CHECK ((kind = ANY (ARRAY['org'::text, 'self'::text])));
ALTER TABLE courses ADD CONSTRAINT courses_self_has_owner_check CHECK (((kind = 'org'::text) OR (owner_id IS NOT NULL)));
CREATE INDEX idx_courses_owner_self ON public.courses USING btree (owner_id) WHERE (kind = 'self'::text);
