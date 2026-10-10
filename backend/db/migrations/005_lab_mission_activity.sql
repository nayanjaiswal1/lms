-- 005_lab_mission_activity.sql
-- Mission mode for composed (debug) labs, used only by orgs whose
-- org_settings.labs.debug_ui is "new" (that key is JSONB, so it needs no DDL and
-- an absent key means "old"): the clock starts when the student presses Start on
-- the briefing, not when the sandbox finishes provisioning
-- (lab_sessions.mission_started_at), and the browser reports integrity signals
-- (tab away, paste, file open) into lab_activity_events for the result page.
-- Sessions that already exist are marked started so an in-flight lab never
-- re-shows its briefing or has its deadline moved. Idempotent.
ALTER TABLE public.lab_sessions ADD COLUMN IF NOT EXISTS mission_started_at timestamp with time zone;
UPDATE public.lab_sessions SET mission_started_at = started_at WHERE mission_started_at IS NULL;

CREATE TABLE IF NOT EXISTS public.lab_activity_events (
    id bigint GENERATED ALWAYS AS IDENTITY,
    session_id uuid NOT NULL,
    event_type text NOT NULL,
    -- file_open: the workspace-relative path; paste and tab_away: empty.
    detail text DEFAULT ''::text NOT NULL,
    -- tab_away: milliseconds spent away; paste: characters pasted; file_open: 0.
    value integer DEFAULT 0 NOT NULL,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT lab_activity_events_pkey PRIMARY KEY (id),
    CONSTRAINT lab_activity_events_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.lab_sessions(id) ON DELETE CASCADE,
    CONSTRAINT lab_activity_events_event_type_check CHECK (event_type = ANY (ARRAY['tab_away'::text, 'paste'::text, 'file_open'::text])),
    CONSTRAINT lab_activity_events_value_check CHECK (value >= 0)
);

CREATE INDEX IF NOT EXISTS lab_activity_events_session_idx
    ON public.lab_activity_events USING btree (session_id, occurred_at);
