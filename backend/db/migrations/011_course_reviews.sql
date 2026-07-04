-- ════════════════════════════════════════════════════════════════════════════
-- 011_course_reviews.sql
-- One star rating (1-5) per enrolled student per course. Powers the
-- aggregate avg_rating / review_count surfaced on course cards.
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE course_reviews (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id  UUID        NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
  rating     INT         NOT NULL CHECK (rating BETWEEN 1 AND 5),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (course_id, user_id)
);

CREATE INDEX idx_course_reviews_course ON course_reviews (course_id);
