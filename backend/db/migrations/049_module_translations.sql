-- Per-lesson translations of a notes lesson's body (course_modules.content_body).
-- Only the body is translated: titles, quizzes and the rest of the course stay
-- in the original language. A lesson with no rows here shows no language
-- switcher. Rows follow the lesson's lifecycle (hard-deleted with the module;
-- a soft-deleted module is hidden by the course_modules.deleted_at filter on
-- every read path).
SET LOCAL lock_timeout = '5s';

CREATE TABLE public.module_translations (
  module_id    UUID        NOT NULL REFERENCES public.course_modules(id) ON DELETE CASCADE,
  locale       TEXT        NOT NULL CHECK (locale ~ '^[a-z]{2,3}(-[A-Za-z0-9]{2,8})?$'),
  content_body TEXT        NOT NULL CHECK (length(content_body) > 0),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (module_id, locale)
);
