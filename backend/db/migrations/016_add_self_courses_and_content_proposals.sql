-- ═════════════════════════════════════════════════════════════════════════
-- Migration 016 — add_self_courses_and_content_proposals
-- Splits courses into two kinds:
--   'org'  — the existing shared, instructor-authored course (unchanged
--            behavior/default).
--   'self' — a student's own private course, owned by owner_id, created
--            either from scratch or by forking a published org course.
--            Never listed in the org-wide browse/public catalogs; visible
--            only to its owner. The owner is auto-enrolled at creation so
--            every existing enrollment/progress/module code path works
--            unchanged — no self-course special-casing needed there.
-- A self-course's connected AI (via the MCP connector) can freely create and
-- edit its own modules with no review gate — it's the student's private
-- content. Contributing that content back into a shared org course instead
-- goes through course_content_proposals: a pending row an org
-- admin/instructor must approve before anything merges into the shared
-- course_modules table. Self-course writes are never applied directly to an
-- org course.
-- ═════════════════════════════════════════════════════════════════════════

ALTER TABLE public.courses
    ADD COLUMN kind text DEFAULT 'org'::text NOT NULL,
    ADD COLUMN owner_id uuid,
    ADD CONSTRAINT courses_kind_check CHECK (kind = ANY (ARRAY['org'::text, 'self'::text])),
    ADD CONSTRAINT courses_self_has_owner_check CHECK (kind = 'org' OR owner_id IS NOT NULL),
    ADD CONSTRAINT courses_owner_fk FOREIGN KEY (owner_id)
        REFERENCES public.users(id) ON DELETE CASCADE;

CREATE INDEX idx_courses_owner_self ON public.courses (owner_id) WHERE kind = 'self';

CREATE TABLE public.course_content_proposals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    proposer_id uuid NOT NULL,
    source_course_id uuid,
    source_module_id uuid,
    target_course_id uuid NOT NULL,
    target_section_id uuid,
    title text NOT NULL,
    type text NOT NULL,
    content_body text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    review_note text,
    reviewed_by uuid,
    reviewed_at timestamp with time zone,
    created_module_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT course_content_proposals_pkey PRIMARY KEY (id),
    CONSTRAINT course_content_proposals_org_fk FOREIGN KEY (org_id)
        REFERENCES public.organizations(id) ON DELETE CASCADE,
    CONSTRAINT course_content_proposals_proposer_fk FOREIGN KEY (proposer_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT course_content_proposals_source_course_fk FOREIGN KEY (source_course_id)
        REFERENCES public.courses(id) ON DELETE SET NULL,
    CONSTRAINT course_content_proposals_source_module_fk FOREIGN KEY (source_module_id)
        REFERENCES public.course_modules(id) ON DELETE SET NULL,
    CONSTRAINT course_content_proposals_target_course_fk FOREIGN KEY (target_course_id)
        REFERENCES public.courses(id) ON DELETE CASCADE,
    CONSTRAINT course_content_proposals_target_section_fk FOREIGN KEY (target_section_id)
        REFERENCES public.course_sections(id) ON DELETE SET NULL,
    CONSTRAINT course_content_proposals_reviewed_by_fk FOREIGN KEY (reviewed_by)
        REFERENCES public.users(id) ON DELETE SET NULL,
    CONSTRAINT course_content_proposals_created_module_fk FOREIGN KEY (created_module_id)
        REFERENCES public.course_modules(id) ON DELETE SET NULL,
    -- Text-only content types: the proposer is always an MCP tool call (no
    -- file-upload transport), so only types storable as content_body apply.
    CONSTRAINT course_content_proposals_type_check
        CHECK (type = ANY (ARRAY['notes'::text, 'assessment'::text])),
    CONSTRAINT course_content_proposals_status_check
        CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text]))
);

CREATE INDEX idx_content_proposals_target_pending
    ON public.course_content_proposals (target_course_id, status);
CREATE INDEX idx_content_proposals_proposer
    ON public.course_content_proposals (proposer_id);
