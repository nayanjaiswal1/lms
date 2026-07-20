-- 015_roadmaps.sql
-- AI Personalized Roadmaps (Phase 20, docs/roadmap.md). A user states a goal,
-- the AI generates a phase -> milestone -> module tree, and modules are
-- best-effort matched against real courses/labs/questions so the roadmap is
-- actionable rather than a plain reading list. resource_id is a loose
-- reference (no FK) because the target table depends on resource_type.
CREATE TABLE roadmaps (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    org_id uuid,
    title text NOT NULL,
    mode text DEFAULT 'generated'::text NOT NULL,
    status text DEFAULT 'generating'::text NOT NULL,
    is_public boolean DEFAULT false NOT NULL,
    goal_description text NOT NULL,
    target_role text,
    skill_level text,
    timeframe_weeks integer,
    focus_areas jsonb DEFAULT '[]'::jsonb NOT NULL,
    generation_error text,
    generated_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT roadmaps_pkey PRIMARY KEY (id),
    CONSTRAINT roadmaps_title_check CHECK ((length(title) >= 1) AND (length(title) <= 200)),
    CONSTRAINT roadmaps_goal_description_check CHECK ((length(goal_description) >= 1) AND (length(goal_description) <= 2000)),
    CONSTRAINT roadmaps_mode_check CHECK (mode = ANY (ARRAY['generated'::text, 'defined'::text])),
    CONSTRAINT roadmaps_status_check CHECK (status = ANY (ARRAY['generating'::text, 'active'::text, 'completed'::text, 'archived'::text, 'failed'::text])),
    CONSTRAINT roadmaps_timeframe_weeks_check CHECK (timeframe_weeks IS NULL OR (timeframe_weeks > 0 AND timeframe_weeks <= 104)),
    CONSTRAINT roadmaps_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT roadmaps_org_id_fkey FOREIGN KEY (org_id) REFERENCES organizations(id) ON DELETE SET NULL
);

CREATE INDEX roadmaps_user_status_idx ON roadmaps (user_id, status) WHERE deleted_at IS NULL;
CREATE INDEX roadmaps_public_idx ON roadmaps (created_at DESC) WHERE is_public AND deleted_at IS NULL;

CREATE TABLE roadmap_phases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    roadmap_id uuid NOT NULL,
    title text NOT NULL,
    description text,
    "position" integer DEFAULT 0 NOT NULL,
    estimated_weeks integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT roadmap_phases_pkey PRIMARY KEY (id),
    CONSTRAINT roadmap_phases_title_check CHECK ((length(title) >= 1) AND (length(title) <= 200)),
    CONSTRAINT roadmap_phases_estimated_weeks_check CHECK (estimated_weeks IS NULL OR estimated_weeks > 0),
    CONSTRAINT roadmap_phases_roadmap_id_fkey FOREIGN KEY (roadmap_id) REFERENCES roadmaps(id) ON DELETE CASCADE
);

CREATE INDEX roadmap_phases_roadmap_position_idx ON roadmap_phases (roadmap_id, "position");

CREATE TABLE roadmap_milestones (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    phase_id uuid NOT NULL,
    title text NOT NULL,
    description text,
    "position" integer DEFAULT 0 NOT NULL,
    estimated_hours integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT roadmap_milestones_pkey PRIMARY KEY (id),
    CONSTRAINT roadmap_milestones_title_check CHECK ((length(title) >= 1) AND (length(title) <= 200)),
    CONSTRAINT roadmap_milestones_estimated_hours_check CHECK (estimated_hours IS NULL OR estimated_hours > 0),
    CONSTRAINT roadmap_milestones_phase_id_fkey FOREIGN KEY (phase_id) REFERENCES roadmap_phases(id) ON DELETE CASCADE
);

CREATE INDEX roadmap_milestones_phase_position_idx ON roadmap_milestones (phase_id, "position");

CREATE TABLE roadmap_modules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    milestone_id uuid NOT NULL,
    title text NOT NULL,
    description text,
    "position" integer DEFAULT 0 NOT NULL,
    module_type text NOT NULL,
    resource_type text,
    resource_id uuid,
    estimated_minutes integer,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT roadmap_modules_pkey PRIMARY KEY (id),
    CONSTRAINT roadmap_modules_title_check CHECK ((length(title) >= 1) AND (length(title) <= 200)),
    CONSTRAINT roadmap_modules_estimated_minutes_check CHECK (estimated_minutes IS NULL OR estimated_minutes > 0),
    CONSTRAINT roadmap_modules_module_type_check CHECK (module_type = ANY (ARRAY['course'::text, 'lab'::text, 'dsa_problem'::text, 'project'::text, 'reading'::text, 'quiz'::text])),
    CONSTRAINT roadmap_modules_resource_type_check CHECK (resource_type IS NULL OR resource_type = ANY (ARRAY['course'::text, 'lab'::text, 'question'::text])),
    CONSTRAINT roadmap_modules_resource_consistency CHECK ((resource_type IS NULL) = (resource_id IS NULL)),
    CONSTRAINT roadmap_modules_milestone_id_fkey FOREIGN KEY (milestone_id) REFERENCES roadmap_milestones(id) ON DELETE CASCADE
);

CREATE INDEX roadmap_modules_milestone_position_idx ON roadmap_modules (milestone_id, "position");
