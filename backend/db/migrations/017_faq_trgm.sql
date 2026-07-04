-- ════════════════════════════════════════════════════════════════════════════
-- 017_faq_trgm.sql — Trigram similarity search for course FAQ dedup
-- ════════════════════════════════════════════════════════════════════════════
-- Students posting a course question have no way to see whether it has
-- already been answered, leading to duplicate FAQs. pg_trgm lets us rank
-- existing course_faqs.question rows by trigram similarity against a
-- student's draft question so near-duplicates can be surfaced before they
-- post, without an AI call.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX idx_course_faqs_question_trgm
  ON course_faqs USING GIN (question gin_trgm_ops);
