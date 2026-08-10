-- ══════════════════════════════════════════════════════════════════════════
-- 005_course_modules_knowledge_check.sql
-- course_modules.knowledge_check backs CourseModule.KnowledgeCheck
-- (backend/internal/courses/models.go) and every generated notes-module
-- INSERT (backend/internal/contentpipeline/generator/render_lesson.go) —
-- both already read/write this column, but no migration ever created it.
-- NOT NULL DEFAULT '[]'::jsonb matches repo.go's GetModule, which always
-- json.Unmarshal()s the raw column value with no NULL guard.
-- ══════════════════════════════════════════════════════════════════════════

ALTER TABLE public.course_modules
    ADD COLUMN knowledge_check jsonb DEFAULT '[]'::jsonb NOT NULL;
