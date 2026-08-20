-- ══════════════════════════════════════════════════════════════════════════
-- 021_project_marketplace_scoring.sql
-- Finishes Phase A of docs/project-marketplace.md: lets a student attach a
-- plain-text resume at apply time (no PDF upload/parsing infra — an LLM
-- prompt needs the same final text either way, so a textarea gets there with
-- far less surface than a file-upload + parser pipeline) and lets staff run
-- one AI scoring pass per requirement. GitHub signal comes from the
-- student's own profile.social_links.github (already collected — no new
-- OAuth connection table needed) fetched from GitHub's public,
-- unauthenticated API at scoring time, not stored here.
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.project_applications
    ADD COLUMN resume_text  text,
    ADD COLUMN ai_score     double precision CHECK (ai_score IS NULL OR (ai_score >= 0 AND ai_score <= 100)),
    ADD COLUMN ai_rationale text,
    ADD COLUMN ai_scored_at timestamp with time zone;
