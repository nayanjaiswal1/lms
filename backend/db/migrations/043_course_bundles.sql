-- ══════════════════════════════════════════════════════════════════════════
-- 043_course_bundles.sql — Course bundles
--
-- Additive: a bundle clubs several existing courses together in an order.
-- It only references courses (never copies them), so editing a course shows
-- up in every bundle it belongs to; enrollment/progress/certificates stay
-- per course (see docs/courses.md "Bundles").
-- ══════════════════════════════════════════════════════════════════════════
SET LOCAL lock_timeout = '5s';

CREATE TABLE public.course_bundles (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      uuid        NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  creator_id  uuid        NOT NULL REFERENCES public.users(id)         ON DELETE RESTRICT,
  title       text        NOT NULL CHECK (char_length(title) BETWEEN 3 AND 200),
  slug        text        NOT NULL,
  description text        CHECK (description IS NULL OR char_length(description) <= 2000),
  cover_url   text,
  status      text        NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (org_id, slug)
);

CREATE TABLE public.course_bundle_items (
  bundle_id uuid NOT NULL REFERENCES public.course_bundles(id) ON DELETE CASCADE,
  course_id uuid NOT NULL REFERENCES public.courses(id)        ON DELETE CASCADE,
  position  int  NOT NULL CHECK (position >= 0),
  PRIMARY KEY (bundle_id, course_id),
  UNIQUE (bundle_id, position) DEFERRABLE INITIALLY DEFERRED
);

-- "Part of: <bundle>" lookup from a course page.
CREATE INDEX idx_course_bundle_items_course ON public.course_bundle_items (course_id);
