-- ═════════════════════════════════════════════════════════════════════════
-- Migration 023 — add_gitlab_integration_and_notifications
--
-- Full schema for the GitLab integration feature, landed in one migration
-- even though the feature itself is built across six delivery batches (see
-- kind-herding-cookie.md §7) — later batches read/write these tables from
-- new service/job code, they do not add new tables for functionality already
-- described here. If a later batch's implementer finds a genuine schema gap
-- while this migration is still unapplied to any shared/deployed database,
-- amend this file directly; once applied anywhere, use an additive
-- follow-up migration instead.
--
--   1. Connection layer (§1.1): gitlab_installations (one org-level PAT or
--      OAuth-service-account credential — auth_kind — doing all admin-level
--      group/project/member/webhook work; also carries the one registered
--      GitLab OAuth Application, oauth_client_id/secret, that powers every
--      member's own personal connect below, independent of the
--      installation's own auth_kind), gitlab_connections (per-user,
--      OAuth+PKCE, opt-in — attributes commits/MRs to the real person),
--      gitlab_oauth_states (server-side PKCE verifier + pending-flow state;
--      `purpose` disambiguates the two flows sharing one callback route).
--   2. Project/team layer (§1.2): project_assignments, project_teams,
--      project_team_members. The (team_id, assignment_id) composite FK
--      against project_teams(id, assignment_id) is what makes "one team per
--      student per assignment" a real DB constraint (Postgres has no other
--      way to express a cross-table uniqueness predicate directly).
--   3. Checkpoints/submissions (§1.3): project_checkpoints,
--      project_team_checkpoints — one table carries MR-as-submission, CI
--      result, deadline snapshot, lateness, approval count, and grade.
--   4. Activity mirror (§1.4, webhook-fed): gitlab_commits,
--      gitlab_merge_requests, gitlab_mr_reviews, gitlab_pipelines,
--      gitlab_issues, gitlab_webhook_events.
--   5. Originality + handoff (§1.5): project_originality_reports,
--      project_originality_matches, project_handoffs.
--   6. Generic notifications (§1.6, own domain, not GitLab-owned):
--      notifications — UNIQUE(user_id, dedupe_key) + ON CONFLICT DO NOTHING
--      is what makes webhook-redelivery-safe notification writes possible.
--   7. Column additions (§1.7): lab_sessions gains project_team_id,
--      repo_clone_status, repo_clone_error for the lab-container auto-clone
--      hook (Batch 3).
--   8. RBAC seed (§1.8): projects.view / projects.manage permissions,
--      granted to the real RBAC role slugs (viewer/member/instructor/
--      mentor/tenant_admin and instructor/tenant_admin respectively — NOT
--      the separate org_members.role enum's "admin"/"learner" values; see
--      001_baseline.sql ~line 3251 for the roles this joins against).
-- ═════════════════════════════════════════════════════════════════════════

CREATE TABLE public.gitlab_installations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    base_url text NOT NULL,
    tier text DEFAULT 'free'::text NOT NULL,
    gitlab_user_id bigint,
    gitlab_username text,
    access_token_enc bytea,
    access_token_expires_at timestamp with time zone,
    refresh_token_enc bytea,
    auth_kind text NOT NULL,
    oauth_client_id text,
    oauth_client_secret_enc bytea,
    root_group_id bigint,
    root_group_path text,
    webhook_secret_enc bytea,
    webhook_mode text DEFAULT 'poll'::text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    last_error text,
    last_verified_at timestamp with time zone,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT gitlab_installations_pkey PRIMARY KEY (id),
    CONSTRAINT gitlab_installations_org_key UNIQUE (org_id),
    CONSTRAINT gitlab_installations_org_fk FOREIGN KEY (org_id)
        REFERENCES public.organizations(id) ON DELETE CASCADE,
    CONSTRAINT gitlab_installations_created_by_fk FOREIGN KEY (created_by)
        REFERENCES public.users(id) ON DELETE SET NULL,
    CONSTRAINT gitlab_installations_tier_check CHECK (tier = ANY (ARRAY['free'::text, 'premium'::text, 'ultimate'::text])),
    CONSTRAINT gitlab_installations_auth_kind_check CHECK (auth_kind = ANY (ARRAY['oauth'::text, 'pat'::text])),
    CONSTRAINT gitlab_installations_webhook_mode_check CHECK (webhook_mode = ANY (ARRAY['webhook'::text, 'poll'::text])),
    CONSTRAINT gitlab_installations_status_check CHECK (status = ANY (ARRAY['pending'::text, 'active'::text, 'error'::text, 'revoked'::text, 'expired'::text])),
    CONSTRAINT gitlab_installations_base_url_not_blank_check CHECK (btrim(base_url) <> ''::text)
);

CREATE TABLE public.gitlab_connections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    gitlab_user_id bigint NOT NULL,
    gitlab_username text NOT NULL,
    gitlab_email text,
    avatar_url text,
    access_token_enc bytea NOT NULL,
    access_token_expires_at timestamp with time zone,
    refresh_token_enc bytea,
    scopes text[] DEFAULT '{}'::text[] NOT NULL,
    status text DEFAULT 'active'::text NOT NULL,
    last_used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    CONSTRAINT gitlab_connections_pkey PRIMARY KEY (id),
    CONSTRAINT gitlab_connections_org_user_key UNIQUE (org_id, user_id),
    CONSTRAINT gitlab_connections_org_gitlab_user_key UNIQUE (org_id, gitlab_user_id),
    CONSTRAINT gitlab_connections_org_fk FOREIGN KEY (org_id)
        REFERENCES public.organizations(id) ON DELETE CASCADE,
    CONSTRAINT gitlab_connections_user_fk FOREIGN KEY (user_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT gitlab_connections_status_check CHECK (status = ANY (ARRAY['active'::text, 'expired'::text, 'revoked'::text]))
);

CREATE INDEX idx_gitlab_connections_active_gitlab_user
    ON public.gitlab_connections (org_id, gitlab_user_id) WHERE (status = 'active'::text);

CREATE INDEX idx_gitlab_connections_expiring
    ON public.gitlab_connections (access_token_expires_at) WHERE (status = 'active'::text);

CREATE TABLE public.gitlab_oauth_states (
    state text NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    purpose text DEFAULT 'connection'::text NOT NULL,
    code_verifier text NOT NULL,
    base_url text,
    oauth_client_id text,
    oauth_client_secret_enc bytea,
    redirect_to text,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT gitlab_oauth_states_pkey PRIMARY KEY (state),
    CONSTRAINT gitlab_oauth_states_org_fk FOREIGN KEY (org_id)
        REFERENCES public.organizations(id) ON DELETE CASCADE,
    CONSTRAINT gitlab_oauth_states_user_fk FOREIGN KEY (user_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT gitlab_oauth_states_purpose_check CHECK (purpose = ANY (ARRAY['installation'::text, 'connection'::text]))
);

CREATE INDEX idx_gitlab_oauth_states_expires ON public.gitlab_oauth_states (expires_at);

-- ─── project/team layer (§1.2, Batch 2) ────────────────────────────────────

CREATE TABLE public.project_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    batch_id uuid NOT NULL,
    course_id uuid,
    lab_id uuid,
    title text NOT NULL,
    slug text NOT NULL,
    description text,
    template_project_id bigint,
    template_project_path text,
    gitlab_group_id bigint,
    gitlab_group_path text,
    visibility text DEFAULT 'private'::text NOT NULL,
    required_approvals integer DEFAULT 1 NOT NULL,
    protect_default_branch boolean DEFAULT true NOT NULL,
    default_branch text DEFAULT 'main'::text NOT NULL,
    starts_at timestamp with time zone,
    due_at timestamp with time zone,
    status text DEFAULT 'draft'::text NOT NULL,
    created_by uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT project_assignments_pkey PRIMARY KEY (id),
    CONSTRAINT project_assignments_batch_slug_key UNIQUE (batch_id, slug),
    CONSTRAINT project_assignments_org_fk FOREIGN KEY (org_id)
        REFERENCES public.organizations(id) ON DELETE CASCADE,
    CONSTRAINT project_assignments_batch_fk FOREIGN KEY (batch_id)
        REFERENCES public.batches(id) ON DELETE CASCADE,
    CONSTRAINT project_assignments_course_fk FOREIGN KEY (course_id)
        REFERENCES public.courses(id) ON DELETE SET NULL,
    CONSTRAINT project_assignments_lab_fk FOREIGN KEY (lab_id)
        REFERENCES public.lab_definitions(id) ON DELETE SET NULL,
    CONSTRAINT project_assignments_created_by_fk FOREIGN KEY (created_by)
        REFERENCES public.users(id) ON DELETE RESTRICT,
    CONSTRAINT project_assignments_visibility_check CHECK (visibility = ANY (ARRAY['private'::text, 'internal'::text])),
    CONSTRAINT project_assignments_status_check CHECK (status = ANY (ARRAY['draft'::text, 'active'::text, 'archived'::text])),
    CONSTRAINT project_assignments_required_approvals_check CHECK (required_approvals >= 0),
    CONSTRAINT project_assignments_schedule_chk CHECK ((starts_at IS NULL) OR (due_at IS NULL) OR (due_at > starts_at)),
    CONSTRAINT project_assignments_title_not_blank_check CHECK (btrim(title) <> ''::text)
);

CREATE INDEX idx_project_assignments_batch_status ON public.project_assignments (batch_id, status);

CREATE TABLE public.project_teams (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    assignment_id uuid NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    gitlab_project_id bigint,
    gitlab_project_path text,
    gitlab_web_url text,
    gitlab_hook_id bigint,
    pages_url text,
    provision_status text DEFAULT 'pending'::text NOT NULL,
    provision_error text,
    provisioned_at timestamp with time zone,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT project_teams_pkey PRIMARY KEY (id),
    CONSTRAINT project_teams_assignment_slug_key UNIQUE (assignment_id, slug),
    -- Composite-FK target for project_team_members below — makes "one team
    -- per student per assignment" a real DB constraint.
    CONSTRAINT project_teams_id_assignment_key UNIQUE (id, assignment_id),
    CONSTRAINT project_teams_gitlab_project_id_key UNIQUE (gitlab_project_id),
    CONSTRAINT project_teams_org_fk FOREIGN KEY (org_id)
        REFERENCES public.organizations(id) ON DELETE CASCADE,
    CONSTRAINT project_teams_assignment_fk FOREIGN KEY (assignment_id)
        REFERENCES public.project_assignments(id) ON DELETE CASCADE,
    CONSTRAINT project_teams_created_by_fk FOREIGN KEY (created_by)
        REFERENCES public.users(id) ON DELETE SET NULL,
    CONSTRAINT project_teams_provision_status_check CHECK (provision_status = ANY (ARRAY['pending'::text, 'provisioning'::text, 'ready'::text, 'failed'::text]))
);

CREATE INDEX idx_project_teams_assignment ON public.project_teams (assignment_id);

CREATE TABLE public.project_team_members (
    team_id uuid NOT NULL,
    user_id uuid NOT NULL,
    assignment_id uuid NOT NULL,
    role text DEFAULT 'member'::text NOT NULL,
    gitlab_access_level integer DEFAULT 30 NOT NULL,
    sync_status text DEFAULT 'pending'::text NOT NULL,
    sync_error text,
    synced_at timestamp with time zone,
    added_by uuid,
    added_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT project_team_members_pkey PRIMARY KEY (team_id, user_id),
    -- One team per student per assignment, enforced via the composite FK
    -- below (project_teams(id, assignment_id)) rather than app code.
    CONSTRAINT project_team_members_assignment_user_key UNIQUE (assignment_id, user_id),
    CONSTRAINT project_team_members_team_assignment_fk FOREIGN KEY (team_id, assignment_id)
        REFERENCES public.project_teams(id, assignment_id) ON DELETE CASCADE,
    CONSTRAINT project_team_members_user_fk FOREIGN KEY (user_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT project_team_members_added_by_fk FOREIGN KEY (added_by)
        REFERENCES public.users(id) ON DELETE SET NULL,
    CONSTRAINT project_team_members_role_check CHECK (role = ANY (ARRAY['lead'::text, 'member'::text])),
    CONSTRAINT project_team_members_access_level_check CHECK (gitlab_access_level = ANY (ARRAY[20, 30, 40])),
    CONSTRAINT project_team_members_sync_status_check CHECK (sync_status = ANY (ARRAY['pending'::text, 'synced'::text, 'failed'::text, 'removing'::text]))
);

CREATE INDEX idx_project_team_members_user ON public.project_team_members (user_id);

-- ─── checkpoints/submissions (§1.3, Batch 5) ───────────────────────────────

CREATE TABLE public.project_checkpoints (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    assignment_id uuid NOT NULL,
    title text NOT NULL,
    description text,
    position integer NOT NULL,
    due_at timestamp with time zone,
    weight integer DEFAULT 100 NOT NULL,
    requires_mr boolean DEFAULT true NOT NULL,
    requires_ci_pass boolean DEFAULT true NOT NULL,
    gitlab_milestone_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT project_checkpoints_pkey PRIMARY KEY (id),
    CONSTRAINT project_checkpoints_assignment_position_key UNIQUE (assignment_id, position),
    CONSTRAINT project_checkpoints_assignment_fk FOREIGN KEY (assignment_id)
        REFERENCES public.project_assignments(id) ON DELETE CASCADE,
    CONSTRAINT project_checkpoints_weight_check CHECK (weight >= 0),
    CONSTRAINT project_checkpoints_title_not_blank_check CHECK (btrim(title) <> ''::text)
);

CREATE TABLE public.project_team_checkpoints (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    team_id uuid NOT NULL,
    checkpoint_id uuid NOT NULL,
    mr_iid bigint,
    mr_id bigint,
    mr_web_url text,
    mr_state text,
    approvals_count integer DEFAULT 0 NOT NULL,
    ci_status text DEFAULT 'none'::text NOT NULL,
    ci_pipeline_id bigint,
    snapshot_sha text,
    snapshot_at timestamp with time zone,
    is_late boolean DEFAULT false NOT NULL,
    late_commit_count integer DEFAULT 0 NOT NULL,
    score numeric(6,2),
    feedback text,
    graded_by uuid,
    graded_at timestamp with time zone,
    status text DEFAULT 'open'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT project_team_checkpoints_pkey PRIMARY KEY (id),
    CONSTRAINT project_team_checkpoints_team_checkpoint_key UNIQUE (team_id, checkpoint_id),
    CONSTRAINT project_team_checkpoints_team_fk FOREIGN KEY (team_id)
        REFERENCES public.project_teams(id) ON DELETE CASCADE,
    CONSTRAINT project_team_checkpoints_checkpoint_fk FOREIGN KEY (checkpoint_id)
        REFERENCES public.project_checkpoints(id) ON DELETE CASCADE,
    CONSTRAINT project_team_checkpoints_graded_by_fk FOREIGN KEY (graded_by)
        REFERENCES public.users(id) ON DELETE SET NULL,
    CONSTRAINT project_team_checkpoints_mr_state_check CHECK (mr_state IS NULL OR mr_state = ANY (ARRAY['opened'::text, 'merged'::text, 'closed'::text, 'locked'::text])),
    CONSTRAINT project_team_checkpoints_ci_status_check CHECK (ci_status = ANY (ARRAY['none'::text, 'pending'::text, 'running'::text, 'success'::text, 'failed'::text, 'canceled'::text])),
    CONSTRAINT project_team_checkpoints_status_check CHECK (status = ANY (ARRAY['open'::text, 'submitted'::text, 'approved'::text, 'merged'::text, 'graded'::text])),
    CONSTRAINT project_team_checkpoints_score_check CHECK ((score IS NULL) OR ((score >= 0) AND (score <= 100)))
);

CREATE INDEX idx_project_team_checkpoints_checkpoint_status ON public.project_team_checkpoints (checkpoint_id, status);

-- ─── activity mirror, webhook-fed (§1.4, Batch 3) ──────────────────────────

CREATE TABLE public.gitlab_commits (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    team_id uuid NOT NULL,
    sha text NOT NULL,
    branch text,
    author_gitlab_user_id bigint,
    user_id uuid,
    author_email text,
    author_name text,
    message text,
    additions integer,
    deletions integer,
    files_changed integer,
    is_merge boolean DEFAULT false NOT NULL,
    committed_at timestamp with time zone,
    recorded_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT gitlab_commits_pkey PRIMARY KEY (id),
    CONSTRAINT gitlab_commits_team_sha_key UNIQUE (team_id, sha),
    CONSTRAINT gitlab_commits_team_fk FOREIGN KEY (team_id)
        REFERENCES public.project_teams(id) ON DELETE CASCADE,
    CONSTRAINT gitlab_commits_user_fk FOREIGN KEY (user_id)
        REFERENCES public.users(id) ON DELETE SET NULL
);

CREATE INDEX idx_gitlab_commits_team_committed ON public.gitlab_commits (team_id, committed_at DESC);
CREATE INDEX idx_gitlab_commits_user_committed ON public.gitlab_commits (user_id, committed_at DESC) WHERE (user_id IS NOT NULL);
-- Pending-stats queue: rows the commit_stats job still needs to fetch
-- per-commit diff stats for.
CREATE INDEX idx_gitlab_commits_pending_stats ON public.gitlab_commits (team_id) WHERE (additions IS NULL);

CREATE TABLE public.gitlab_merge_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    team_id uuid NOT NULL,
    mr_iid bigint NOT NULL,
    mr_id bigint,
    title text NOT NULL,
    description text,
    state text DEFAULT 'opened'::text NOT NULL,
    source_branch text,
    target_branch text,
    author_gitlab_user_id bigint,
    author_user_id uuid,
    web_url text,
    approvals_count integer DEFAULT 0 NOT NULL,
    changes_count integer,
    opened_at timestamp with time zone,
    merged_at timestamp with time zone,
    closed_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT gitlab_merge_requests_pkey PRIMARY KEY (id),
    CONSTRAINT gitlab_merge_requests_team_mr_iid_key UNIQUE (team_id, mr_iid),
    CONSTRAINT gitlab_merge_requests_team_fk FOREIGN KEY (team_id)
        REFERENCES public.project_teams(id) ON DELETE CASCADE,
    CONSTRAINT gitlab_merge_requests_author_user_fk FOREIGN KEY (author_user_id)
        REFERENCES public.users(id) ON DELETE SET NULL,
    CONSTRAINT gitlab_merge_requests_state_check CHECK (state = ANY (ARRAY['opened'::text, 'merged'::text, 'closed'::text, 'locked'::text]))
);

CREATE TABLE public.gitlab_mr_reviews (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    merge_request_id uuid NOT NULL,
    reviewer_gitlab_user_id bigint,
    reviewer_user_id uuid,
    kind text NOT NULL,
    note_id bigint NOT NULL,
    body text,
    file_path text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT gitlab_mr_reviews_pkey PRIMARY KEY (id),
    CONSTRAINT gitlab_mr_reviews_mr_note_key UNIQUE (merge_request_id, note_id),
    CONSTRAINT gitlab_mr_reviews_mr_fk FOREIGN KEY (merge_request_id)
        REFERENCES public.gitlab_merge_requests(id) ON DELETE CASCADE,
    CONSTRAINT gitlab_mr_reviews_reviewer_user_fk FOREIGN KEY (reviewer_user_id)
        REFERENCES public.users(id) ON DELETE SET NULL,
    CONSTRAINT gitlab_mr_reviews_kind_check CHECK (kind = ANY (ARRAY['comment'::text, 'approval'::text, 'change_request'::text]))
);

CREATE TABLE public.gitlab_pipelines (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    team_id uuid NOT NULL,
    pipeline_id bigint NOT NULL,
    sha text,
    ref text,
    status text NOT NULL,
    web_url text,
    duration_seconds integer,
    started_at timestamp with time zone,
    finished_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT gitlab_pipelines_pkey PRIMARY KEY (id),
    CONSTRAINT gitlab_pipelines_team_pipeline_key UNIQUE (team_id, pipeline_id),
    CONSTRAINT gitlab_pipelines_team_fk FOREIGN KEY (team_id)
        REFERENCES public.project_teams(id) ON DELETE CASCADE
);

CREATE INDEX idx_gitlab_pipelines_team_updated ON public.gitlab_pipelines (team_id, updated_at DESC);

CREATE TABLE public.gitlab_issues (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    team_id uuid NOT NULL,
    issue_iid bigint NOT NULL,
    issue_id bigint,
    title text NOT NULL,
    state text DEFAULT 'opened'::text NOT NULL,
    milestone_id bigint,
    checkpoint_id uuid,
    assignee_gitlab_user_id bigint,
    assignee_user_id uuid,
    weight integer,
    labels text[] DEFAULT '{}'::text[] NOT NULL,
    gl_created_at timestamp with time zone,
    gl_closed_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT gitlab_issues_pkey PRIMARY KEY (id),
    CONSTRAINT gitlab_issues_team_issue_iid_key UNIQUE (team_id, issue_iid),
    CONSTRAINT gitlab_issues_team_fk FOREIGN KEY (team_id)
        REFERENCES public.project_teams(id) ON DELETE CASCADE,
    CONSTRAINT gitlab_issues_checkpoint_fk FOREIGN KEY (checkpoint_id)
        REFERENCES public.project_checkpoints(id) ON DELETE SET NULL,
    CONSTRAINT gitlab_issues_assignee_user_fk FOREIGN KEY (assignee_user_id)
        REFERENCES public.users(id) ON DELETE SET NULL,
    CONSTRAINT gitlab_issues_state_check CHECK (state = ANY (ARRAY['opened'::text, 'closed'::text]))
);

-- Burndown query: per-checkpoint issue close-out over time.
CREATE INDEX idx_gitlab_issues_burndown ON public.gitlab_issues (team_id, checkpoint_id, gl_closed_at);

CREATE TABLE public.gitlab_webhook_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    project_id bigint,
    event_type text NOT NULL,
    event_uuid text NOT NULL,
    payload jsonb NOT NULL,
    status text DEFAULT 'received'::text NOT NULL,
    error text,
    received_at timestamp with time zone DEFAULT now() NOT NULL,
    processed_at timestamp with time zone,
    CONSTRAINT gitlab_webhook_events_pkey PRIMARY KEY (id),
    -- (org_id, event_uuid) + ON CONFLICT DO NOTHING on X-Gitlab-Event-UUID is
    -- what makes webhook redelivery idempotent.
    CONSTRAINT gitlab_webhook_events_org_event_uuid_key UNIQUE (org_id, event_uuid),
    CONSTRAINT gitlab_webhook_events_org_fk FOREIGN KEY (org_id)
        REFERENCES public.organizations(id) ON DELETE CASCADE,
    CONSTRAINT gitlab_webhook_events_status_check CHECK (status = ANY (ARRAY['received'::text, 'dispatched'::text, 'ignored'::text, 'failed'::text]))
);

CREATE INDEX idx_gitlab_webhook_events_received ON public.gitlab_webhook_events (received_at) WHERE (status = 'received'::text);

-- ─── originality + handoff (§1.5, Batch 6) ─────────────────────────────────

CREATE TABLE public.project_originality_reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    assignment_id uuid NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    teams_scanned integer DEFAULT 0 NOT NULL,
    files_scanned integer DEFAULT 0 NOT NULL,
    error text,
    requested_by uuid,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    CONSTRAINT project_originality_reports_pkey PRIMARY KEY (id),
    CONSTRAINT project_originality_reports_assignment_fk FOREIGN KEY (assignment_id)
        REFERENCES public.project_assignments(id) ON DELETE CASCADE,
    CONSTRAINT project_originality_reports_requested_by_fk FOREIGN KEY (requested_by)
        REFERENCES public.users(id) ON DELETE SET NULL,
    CONSTRAINT project_originality_reports_status_check CHECK (status = ANY (ARRAY['pending'::text, 'running'::text, 'complete'::text, 'failed'::text]))
);

CREATE TABLE public.project_originality_matches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    report_id uuid NOT NULL,
    team_a_id uuid NOT NULL,
    team_b_id uuid,
    file_path_a text NOT NULL,
    file_path_b text NOT NULL,
    similarity numeric(5,4) NOT NULL,
    matched_lines integer,
    sample text,
    CONSTRAINT project_originality_matches_pkey PRIMARY KEY (id),
    CONSTRAINT project_originality_matches_report_fk FOREIGN KEY (report_id)
        REFERENCES public.project_originality_reports(id) ON DELETE CASCADE,
    CONSTRAINT project_originality_matches_team_a_fk FOREIGN KEY (team_a_id)
        REFERENCES public.project_teams(id) ON DELETE CASCADE,
    -- Nullable: null means the match is against the template project itself,
    -- not another team.
    CONSTRAINT project_originality_matches_team_b_fk FOREIGN KEY (team_b_id)
        REFERENCES public.project_teams(id) ON DELETE CASCADE,
    CONSTRAINT project_originality_matches_similarity_check CHECK ((similarity >= 0) AND (similarity <= 1))
);

CREATE INDEX idx_project_originality_matches_report_similarity ON public.project_originality_matches (report_id, similarity DESC);

CREATE TABLE public.project_handoffs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    team_id uuid NOT NULL,
    user_id uuid NOT NULL,
    mode text NOT NULL,
    target_namespace_id bigint,
    target_namespace_path text,
    new_project_id bigint,
    new_web_url text,
    status text DEFAULT 'pending'::text NOT NULL,
    error text,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    CONSTRAINT project_handoffs_pkey PRIMARY KEY (id),
    CONSTRAINT project_handoffs_team_user_key UNIQUE (team_id, user_id),
    CONSTRAINT project_handoffs_team_fk FOREIGN KEY (team_id)
        REFERENCES public.project_teams(id) ON DELETE CASCADE,
    CONSTRAINT project_handoffs_user_fk FOREIGN KEY (user_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT project_handoffs_mode_check CHECK (mode = ANY (ARRAY['fork'::text, 'transfer'::text])),
    CONSTRAINT project_handoffs_status_check CHECK (status = ANY (ARRAY['pending'::text, 'running'::text, 'complete'::text, 'failed'::text]))
);

-- ─── generic notifications (§1.6, Batch 5 — own domain, not GitLab-owned) ──

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    type text NOT NULL,
    title text NOT NULL,
    body text,
    link_url text,
    entity_type text,
    entity_id uuid,
    actor_user_id uuid,
    priority text DEFAULT 'normal'::text NOT NULL,
    dedupe_key text NOT NULL,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT notifications_pkey PRIMARY KEY (id),
    -- UNIQUE(user_id, dedupe_key) + INSERT ... ON CONFLICT DO NOTHING is what
    -- makes webhook-redelivery-safe notification writes possible.
    CONSTRAINT notifications_user_dedupe_key_key UNIQUE (user_id, dedupe_key),
    CONSTRAINT notifications_org_fk FOREIGN KEY (org_id)
        REFERENCES public.organizations(id) ON DELETE CASCADE,
    CONSTRAINT notifications_user_fk FOREIGN KEY (user_id)
        REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT notifications_actor_user_fk FOREIGN KEY (actor_user_id)
        REFERENCES public.users(id) ON DELETE SET NULL,
    CONSTRAINT notifications_priority_check CHECK (priority = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text])),
    CONSTRAINT notifications_title_not_blank_check CHECK (btrim(title) <> ''::text)
);

CREATE INDEX idx_notifications_user_created ON public.notifications (user_id, created_at DESC);
CREATE INDEX idx_notifications_user_unread ON public.notifications (user_id) WHERE (read_at IS NULL);

-- ─── column additions (§1.7, Batch 3 lab-container auto-clone hook) ────────

ALTER TABLE public.lab_sessions
    ADD COLUMN project_team_id uuid,
    ADD COLUMN repo_clone_status text,
    ADD COLUMN repo_clone_error text;

ALTER TABLE public.lab_sessions
    ADD CONSTRAINT lab_sessions_project_team_fk FOREIGN KEY (project_team_id)
        REFERENCES public.project_teams(id) ON DELETE SET NULL,
    ADD CONSTRAINT lab_sessions_repo_clone_status_check CHECK ((repo_clone_status IS NULL) OR (repo_clone_status = ANY (ARRAY['pending'::text, 'cloned'::text, 'failed'::text, 'skipped'::text])));

-- ─── RBAC seed ───────────────────────────────────────────────────────────────
-- projects.view / projects.manage back the GitLab settings/admin pages this
-- batch delivers. Granted by joining on the real granular-RBAC role slugs
-- (public.roles.name) — distinct from the separate org_members.role enum
-- ('owner'|'admin'|'instructor'|'mentor'|'learner') that middleware.RequireOrgRole
-- checks. role_permissions has only (role_id, permission_id) — no timestamp
-- columns to populate.
INSERT INTO public.permissions (code, name, description, module)
VALUES
    ('projects.view', 'View Projects', 'View GitLab-backed project assignments, teams, and checkpoints', 'projects'),
    ('projects.manage', 'Manage Projects', 'Create and manage GitLab-backed project assignments, teams, and the org''s GitLab installation', 'projects')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r, public.permissions p
WHERE r.name IN ('viewer', 'member', 'instructor', 'mentor', 'tenant_admin')
  AND p.code = 'projects.view'
ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r, public.permissions p
WHERE r.name IN ('instructor', 'tenant_admin')
  AND p.code = 'projects.manage'
ON CONFLICT DO NOTHING;
