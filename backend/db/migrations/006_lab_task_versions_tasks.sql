-- ══════════════════════════════════════════════════════════════════════════
-- 006_lab_task_versions_tasks.sql
-- lab_task_versions.tasks backs the legacy snapshot column every generated
-- lab INSERT writes (backend/internal/contentpipeline/generator/render_lab.go
-- step 3 — superseded by lab_task_version_items, which
-- Repo.GetPublishedVersion actually reads, but still written for
-- convenience). No migration ever created the column.
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.lab_task_versions
    ADD COLUMN tasks jsonb DEFAULT '[]'::jsonb NOT NULL;
