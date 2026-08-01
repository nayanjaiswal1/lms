-- ═════════════════════════════════════════════════════════════════════════
-- Migration 013 — mentor session booking
-- ═════════════════════════════════════════════════════════════════════════
-- Before this, a "mentor session" was nothing but a calendar_events row of
-- event_type='mentor_session' created ad hoc by ScheduleSessionButton: no
-- availability model, no limit on how many a student could create, no
-- cancellation rules, no record of what happened afterwards. This migration
-- introduces the booking domain proper and leaves calendar_events as what it
-- already is — the *projection* a session shows up as on everyone's calendar
-- (and therefore in the existing ICS feed), linked back by
-- mentor_sessions.calendar_event_id.
--
-- Three correctness rules are enforced here rather than in Go, because Go
-- cannot enforce them across concurrent requests without a lock it would
-- have to remember to take:
--
--  1. mentor_sessions_no_overlap / _student_no_overlap — two students hitting
--     "book" on the same slot in the same millisecond is the normal case for
--     a popular mentor, not an exotic race. A gist EXCLUDE constraint rejects
--     the loser at the DB; an app-side "is this slot free?" SELECT cannot.
--     Requires btree_gist for the uuid `WITH =` half of the constraint.
--
--  2. session_credit_ledger_booking_uq / _refund_uq — the ledger is
--     append-only (balance = SUM(delta)), so a retried cancel must not be
--     able to refund the same session twice and mint credits out of nothing.
--     One partial unique index per reason makes both writes idempotent.
--
--  3. mentor_sessions_subject_chk — a session belongs to exactly one subject:
--     a student (1:1) or a batch (whole-cohort). Neither-or-both is a bug
--     with no sensible read behaviour, so it cannot be represented.

CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ── 1. Org-level toggle + booking policy ─────────────────────────────────
-- Mirrors org_ai_connector_config exactly: no row means "never toggled", and
-- the defaults below are what a missing row resolves to (see
-- features.Repo.OrgSessionBookingEnabled). enabled defaults true because
-- session scheduling already worked for every org before this migration —
-- shipping it off would silently remove a capability people are using.
--
-- require_credits, by contrast, defaults FALSE: turning it on before the org
-- has created any session_credit_packs would leave every student at a zero
-- balance with nothing to buy, i.e. the feature bricked. It is the org
-- admin's explicit step once packs exist.
CREATE TABLE public.org_session_booking_config (
    org_id uuid PRIMARY KEY REFERENCES public.organizations(id) ON DELETE CASCADE,
    enabled boolean DEFAULT true NOT NULL,
    require_credits boolean DEFAULT false NOT NULL,
    -- Cancel at least this many hours ahead to get the credit back. Cancelling
    -- later is still allowed (the alternative is a student stuck attending),
    -- it just forfeits the credit — see sessions.Service.Cancel.
    cancel_cutoff_hours integer DEFAULT 12 NOT NULL,
    -- A slot starting sooner than this is not offered and cannot be booked;
    -- stops a student from booking a mentor 4 minutes from now.
    min_notice_hours integer DEFAULT 2 NOT NULL,
    -- How far ahead slots are published at all.
    booking_horizon_days integer DEFAULT 60 NOT NULL,
    -- Anti-hoarding: how many scheduled (not yet completed) sessions one
    -- student may hold at once. This is the limit whose absence prompted
    -- this whole migration.
    max_upcoming_per_student integer DEFAULT 3 NOT NULL,
    default_duration_minutes integer DEFAULT 30 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT org_session_booking_cancel_cutoff_chk CHECK (cancel_cutoff_hours >= 0 AND cancel_cutoff_hours <= 336),
    CONSTRAINT org_session_booking_min_notice_chk CHECK (min_notice_hours >= 0 AND min_notice_hours <= 336),
    CONSTRAINT org_session_booking_horizon_chk CHECK (booking_horizon_days >= 1 AND booking_horizon_days <= 365),
    CONSTRAINT org_session_booking_max_upcoming_chk CHECK (max_upcoming_per_student >= 1 AND max_upcoming_per_student <= 100),
    CONSTRAINT org_session_booking_duration_chk CHECK (default_duration_minutes >= 5 AND default_duration_minutes <= 480)
);

-- ── 2. Mentor availability ───────────────────────────────────────────────
-- A weekly recurring pattern, expressed in the mentor's OWN timezone rather
-- than UTC minutes-of-week. Storing UTC would be one column shorter and
-- wrong twice a year: "every Tuesday 09:00" is a wall-clock promise, and a
-- DST shift must move the UTC instant, not the mentor's morning. Slot
-- expansion resolves this per-date via the IANA zone named here.
CREATE TABLE public.mentor_availability_rules (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    mentor_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    -- 0=Sunday .. 6=Saturday, matching Go's time.Weekday.
    weekday smallint NOT NULL,
    -- Minutes from local midnight. end_minute may be 1440 (midnight next day).
    start_minute integer NOT NULL,
    end_minute integer NOT NULL,
    -- Bookable slot granularity within the window; the window length need not
    -- divide evenly, any trailing remainder shorter than slot_minutes is not
    -- offered as a slot.
    slot_minutes integer DEFAULT 30 NOT NULL,
    timezone text DEFAULT 'UTC' NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mentor_availability_weekday_chk CHECK (weekday >= 0 AND weekday <= 6),
    CONSTRAINT mentor_availability_window_chk CHECK (start_minute >= 0 AND end_minute <= 1440 AND end_minute > start_minute),
    CONSTRAINT mentor_availability_slot_chk CHECK (slot_minutes >= 5 AND slot_minutes <= 480),
    CONSTRAINT mentor_availability_tz_chk CHECK (length(timezone) BETWEEN 1 AND 64)
);

CREATE INDEX mentor_availability_rules_mentor_idx
    ON public.mentor_availability_rules (mentor_id, org_id)
    WHERE active;

-- One-off overrides on top of the weekly pattern: a blocked holiday
-- (is_blocked=true) or an extra ad-hoc window opened on a day the weekly
-- rules don't cover (is_blocked=false). NULL start/end means the whole day.
CREATE TABLE public.mentor_availability_exceptions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    mentor_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    on_date date NOT NULL,
    start_minute integer,
    end_minute integer,
    is_blocked boolean DEFAULT true NOT NULL,
    slot_minutes integer DEFAULT 30 NOT NULL,
    timezone text DEFAULT 'UTC' NOT NULL,
    note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mentor_availability_exc_window_chk CHECK (
        (start_minute IS NULL AND end_minute IS NULL)
        OR (start_minute >= 0 AND end_minute <= 1440 AND end_minute > start_minute)
    ),
    -- An "extra window" with no window is meaningless — an all-day OPEN would
    -- be a 24h shift nobody intends. Only a block may span the whole day.
    CONSTRAINT mentor_availability_exc_open_needs_window_chk CHECK (
        is_blocked OR start_minute IS NOT NULL
    ),
    CONSTRAINT mentor_availability_exc_slot_chk CHECK (slot_minutes >= 5 AND slot_minutes <= 480),
    CONSTRAINT mentor_availability_exc_note_chk CHECK (note IS NULL OR length(note) <= 500)
);

CREATE INDEX mentor_availability_exceptions_lookup_idx
    ON public.mentor_availability_exceptions (mentor_id, on_date);

-- ── 3. Session credits ───────────────────────────────────────────────────
-- What an org sells. price_cents is in PAYMENTS_CURRENCY, like every other
-- *_cents column in this schema.
CREATE TABLE public.session_credit_packs (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    name text NOT NULL,
    description text,
    sessions integer NOT NULL,
    price_cents integer NOT NULL,
    currency text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT session_credit_packs_name_chk CHECK (length(name) BETWEEN 1 AND 120),
    CONSTRAINT session_credit_packs_desc_chk CHECK (description IS NULL OR length(description) <= 1000),
    CONSTRAINT session_credit_packs_sessions_chk CHECK (sessions >= 1 AND sessions <= 1000),
    CONSTRAINT session_credit_packs_price_chk CHECK (price_cents >= 0)
);

CREATE INDEX session_credit_packs_org_idx ON public.session_credit_packs (org_id) WHERE active;

-- A pack checkout. Deliberately a separate table from course_purchases rather
-- than a nullable course_id on it: the two have different confirmation side
-- effects (enrollment + mentor ticket vs. a credit ledger entry) and the
-- existing unique indexes on course_purchases all assume a real course.
CREATE TABLE public.session_pack_purchases (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    pack_id uuid NOT NULL REFERENCES public.session_credit_packs(id) ON DELETE RESTRICT,
    -- Copied off the pack at checkout time, not read through the FK: an admin
    -- editing a pack's size later must not retroactively change what an
    -- already-paid purchase granted.
    sessions integer NOT NULL,
    amount_cents integer NOT NULL,
    currency text NOT NULL,
    provider text DEFAULT 'stub' NOT NULL,
    provider_ref text NOT NULL,
    payment_ref text,
    status text DEFAULT 'pending' NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    CONSTRAINT session_pack_purchases_sessions_chk CHECK (sessions >= 1),
    CONSTRAINT session_pack_purchases_amount_chk CHECK (amount_cents >= 0),
    CONSTRAINT session_pack_purchases_provider_chk CHECK (provider = ANY (ARRAY['stub'::text, 'stripe'::text, 'razorpay'::text])),
    CONSTRAINT session_pack_purchases_status_chk CHECK (status = ANY (ARRAY['pending'::text, 'completed'::text, 'failed'::text, 'refunded'::text]))
);

-- The webhook's lookup key, and the guard against one gateway session being
-- credited to two purchase rows.
CREATE UNIQUE INDEX session_pack_purchases_provider_ref_uq
    ON public.session_pack_purchases (provider, provider_ref);

CREATE INDEX session_pack_purchases_user_idx
    ON public.session_pack_purchases (user_id, org_id, created_at DESC);

-- Append-only. A user's balance is SUM(delta) over their rows — there is no
-- mutable balance column to drift out of sync with its own history, and
-- every movement carries the reason and the row that caused it.
CREATE TABLE public.session_credit_ledger (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    -- Positive grants, negative spends. Never zero: a no-op ledger row is
    -- noise that still has to be read on every balance query.
    delta integer NOT NULL,
    reason text NOT NULL,
    session_id uuid,
    purchase_id uuid REFERENCES public.session_pack_purchases(id) ON DELETE SET NULL,
    note text,
    created_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT session_credit_ledger_delta_chk CHECK (delta <> 0),
    CONSTRAINT session_credit_ledger_reason_chk CHECK (reason = ANY (ARRAY[
        'purchase'::text,
        'admin_grant'::text,
        'admin_revoke'::text,
        'booking'::text,
        'cancellation_refund'::text
    ])),
    CONSTRAINT session_credit_ledger_note_chk CHECK (note IS NULL OR length(note) <= 500)
);

CREATE INDEX session_credit_ledger_balance_idx
    ON public.session_credit_ledger (user_id, org_id);

-- ── 4. The booking itself ────────────────────────────────────────────────
CREATE TABLE public.mentor_sessions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    org_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    mentor_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    -- Exactly one of student_id / batch_id is set — see the subject CHECK.
    student_id uuid REFERENCES public.users(id) ON DELETE CASCADE,
    batch_id uuid REFERENCES public.batches(id) ON DELETE CASCADE,
    title text NOT NULL,
    agenda text,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    status text DEFAULT 'scheduled' NOT NULL,
    -- Who pressed book. Either side may schedule, and the cancellation rules
    -- read differently depending on which side backed out.
    booked_by uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    meeting_url text,
    -- The calendar_events row this session projects onto, so cancelling the
    -- booking also clears everyone's calendar. Nullable + ON DELETE SET NULL:
    -- losing the projection must never delete the booking record itself.
    calendar_event_id uuid REFERENCES public.calendar_events(id) ON DELETE SET NULL,
    cancelled_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
    cancelled_at timestamp with time zone,
    cancel_reason text,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mentor_sessions_subject_chk CHECK (
        (student_id IS NOT NULL AND batch_id IS NULL)
        OR (student_id IS NULL AND batch_id IS NOT NULL)
    ),
    CONSTRAINT mentor_sessions_window_chk CHECK (ends_at > starts_at),
    CONSTRAINT mentor_sessions_title_chk CHECK (length(title) BETWEEN 1 AND 200),
    CONSTRAINT mentor_sessions_agenda_chk CHECK (agenda IS NULL OR length(agenda) <= 5000),
    CONSTRAINT mentor_sessions_cancel_reason_chk CHECK (cancel_reason IS NULL OR length(cancel_reason) <= 500),
    CONSTRAINT mentor_sessions_status_chk CHECK (status = ANY (ARRAY[
        'scheduled'::text,
        'completed'::text,
        'cancelled'::text,
        'no_show'::text
    ])),
    -- A mentor cannot mentor themselves, and a student cannot be their own
    -- mentor for a session that then shows up twice on one calendar.
    CONSTRAINT mentor_sessions_distinct_parties_chk CHECK (student_id IS NULL OR student_id <> mentor_id)
);

-- Rule 1: no mentor is ever in two scheduled sessions at once. Cancelled and
-- completed rows are excluded so a cancelled 10:00 frees 10:00 for rebooking.
ALTER TABLE public.mentor_sessions
    ADD CONSTRAINT mentor_sessions_no_overlap
    EXCLUDE USING gist (
        mentor_id WITH =,
        tstzrange(starts_at, ends_at) WITH &&
    ) WHERE (status = 'scheduled');

-- The same guarantee from the student's side: a student cannot hold two
-- overlapping 1:1 sessions with two different mentors.
ALTER TABLE public.mentor_sessions
    ADD CONSTRAINT mentor_sessions_student_no_overlap
    EXCLUDE USING gist (
        student_id WITH =,
        tstzrange(starts_at, ends_at) WITH &&
    ) WHERE (status = 'scheduled' AND student_id IS NOT NULL);

CREATE INDEX mentor_sessions_mentor_idx ON public.mentor_sessions (mentor_id, starts_at DESC);
CREATE INDEX mentor_sessions_student_idx ON public.mentor_sessions (student_id, starts_at DESC) WHERE student_id IS NOT NULL;
CREATE INDEX mentor_sessions_batch_idx ON public.mentor_sessions (batch_id, starts_at DESC) WHERE batch_id IS NOT NULL;
CREATE INDEX mentor_sessions_org_upcoming_idx ON public.mentor_sessions (org_id, starts_at) WHERE status = 'scheduled';

ALTER TABLE public.session_credit_ledger
    ADD CONSTRAINT session_credit_ledger_session_id_fkey
    FOREIGN KEY (session_id) REFERENCES public.mentor_sessions(id) ON DELETE SET NULL;

-- Rule 2: exactly one charge and at most one refund per session, ever. These
-- are what make Book and Cancel safe to retry — the second attempt hits a
-- unique violation instead of double-charging or minting a free credit.
CREATE UNIQUE INDEX session_credit_ledger_booking_uq
    ON public.session_credit_ledger (session_id)
    WHERE reason = 'booking' AND session_id IS NOT NULL;

CREATE UNIQUE INDEX session_credit_ledger_refund_uq
    ON public.session_credit_ledger (session_id)
    WHERE reason = 'cancellation_refund' AND session_id IS NOT NULL;

-- ── 5. Post-session feedback and notes ───────────────────────────────────
-- Both sides rate each other once. UNIQUE (session_id, author_id) makes the
-- form an upsert rather than an append, so a resubmit edits rather than
-- stacking duplicate ratings that would skew the mentor's average.
CREATE TABLE public.mentor_session_feedback (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id uuid NOT NULL REFERENCES public.mentor_sessions(id) ON DELETE CASCADE,
    author_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    author_role text NOT NULL,
    rating smallint NOT NULL,
    comment text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mentor_session_feedback_role_chk CHECK (author_role = ANY (ARRAY['student'::text, 'mentor'::text])),
    CONSTRAINT mentor_session_feedback_rating_chk CHECK (rating >= 1 AND rating <= 5),
    CONSTRAINT mentor_session_feedback_comment_chk CHECK (comment IS NULL OR length(comment) <= 2000)
);

CREATE UNIQUE INDEX mentor_session_feedback_author_uq
    ON public.mentor_session_feedback (session_id, author_id);

-- One notes document per session, owned by the mentor. PK on session_id
-- rather than a list of note rows: this is the mentor's write-up of what
-- happened, which they edit, not a thread.
--
-- visible_to_student defaults FALSE — a mentor's working notes about a
-- mentee are private by default and shared deliberately, never the reverse.
CREATE TABLE public.mentor_session_notes (
    session_id uuid PRIMARY KEY REFERENCES public.mentor_sessions(id) ON DELETE CASCADE,
    mentor_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    body text NOT NULL,
    visible_to_student boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT mentor_session_notes_body_chk CHECK (length(body) <= 20000)
);

-- ── 6. RBAC ──────────────────────────────────────────────────────────────
-- Gates the org-admin surface: booking policy, credit packs, admin credit
-- grants, and whole-batch scheduling. Booking a session for yourself needs no
-- permission at all — that's every member.
--
-- Granted to tenant_admin and instructor by default, the same pair
-- mentoring.assign_tickets defaults to: the people who already run the
-- mentoring programme are the people who set its rules.
INSERT INTO public.permissions (code, name, description, module)
VALUES ('mentoring.manage_session_booking', 'Manage Session Booking',
        'Configure the session booking policy, credit packs, credit grants, and batch sessions', 'mentoring');

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
  FROM public.roles r
  CROSS JOIN public.permissions p
 WHERE p.code = 'mentoring.manage_session_booking'
   AND r.is_system
   AND r.name IN ('tenant_admin', 'instructor');
