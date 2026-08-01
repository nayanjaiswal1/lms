-- ═════════════════════════════════════════════════════════════════════════
-- Migration 006 — mentor_verification
-- ═════════════════════════════════════════════════════════════════════════
-- Adds a manually-toggled "verified expert" badge to mentor profiles (there
-- is no automated verification signal — this is an admin/instructor
-- attestation, so it's a plain stored flag, not a computed value like the
-- other mentor profile stats added in 007).

ALTER TABLE public.user_profiles
    ADD COLUMN mentor_verified boolean DEFAULT false NOT NULL,
    ADD COLUMN mentor_verified_at timestamp with time zone,
    ADD COLUMN mentor_verified_by uuid REFERENCES public.users(id) ON DELETE SET NULL;

INSERT INTO public.permissions (code, name, description, module)
VALUES ('mentoring.verify_mentors', 'Verify Mentors',
        'Toggle the verified-expert badge on a mentor profile', 'mentoring');
