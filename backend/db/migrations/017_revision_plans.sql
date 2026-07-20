-- 017_revision_plans.sql
-- AI-generated, per-(user, course) revision plan: once a learner completes a
-- course, they can request a plan built from their ACTUAL performance signals
-- in that course — lesson reflections (016_lesson_reflections.sql) and
-- knowledge-check accuracy (012_lesson_knowledge_checks.sql) — returning
-- ranked weak topics with a concrete recommendation for each. Mirrors the
-- roadmaps table's shell-then-async-generate shape (015_roadmaps.sql): a row
-- is created with status='generating' immediately, then a background job
-- (internal/jobs/handlers/llm.go, task "revision_plan_generate") fills in the
-- topics and flips status to 'ready' or 'failed'.
CREATE TABLE revision_plans (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    course_id uuid NOT NULL,
    org_id uuid NOT NULL,
    status text DEFAULT 'generating'::text NOT NULL,
    generation_error text,
    generated_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT revision_plans_pkey PRIMARY KEY (id),
    CONSTRAINT revision_plans_user_course_key UNIQUE (user_id, course_id),
    CONSTRAINT revision_plans_status_check CHECK (status = ANY (ARRAY['generating'::text, 'ready'::text, 'failed'::text])),
    CONSTRAINT revision_plans_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT revision_plans_course_id_fkey FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE,
    CONSTRAINT revision_plans_org_id_fkey FOREIGN KEY (org_id) REFERENCES organizations(id) ON DELETE CASCADE
);

CREATE INDEX revision_plans_user_course_idx ON revision_plans (user_id, course_id);

CREATE TABLE revision_plan_topics (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    revision_plan_id uuid NOT NULL,
    module_id uuid,
    title text NOT NULL,
    reason text NOT NULL,
    recommendation text NOT NULL,
    priority integer DEFAULT 3 NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    CONSTRAINT revision_plan_topics_pkey PRIMARY KEY (id),
    CONSTRAINT revision_plan_topics_title_check CHECK ((length(title) >= 1) AND (length(title) <= 200)),
    CONSTRAINT revision_plan_topics_priority_check CHECK (priority >= 1 AND priority <= 5),
    CONSTRAINT revision_plan_topics_revision_plan_id_fkey FOREIGN KEY (revision_plan_id) REFERENCES revision_plans(id) ON DELETE CASCADE,
    CONSTRAINT revision_plan_topics_module_id_fkey FOREIGN KEY (module_id) REFERENCES course_modules(id) ON DELETE SET NULL
);

CREATE INDEX revision_plan_topics_plan_position_idx ON revision_plan_topics (revision_plan_id, "position");
