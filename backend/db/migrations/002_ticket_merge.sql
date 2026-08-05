-- ══════════════════════════════════════════════════════════════════════════
-- 002_ticket_merge.sql
--
-- Backs the merge of internal/support and internal/mentoring's ticket
-- lifecycles onto a single internal/tickets package (conversations/messages
-- were already shared via the kind/thread_type discriminator — no table
-- changes needed here, just permission + constraint fixes).
-- ══════════════════════════════════════════════════════════════════════════

-- mentoring.view_tickets replaces the RequireOrgRole(mentor, instructor,
-- tenant_admin) check that gated GET /api/mentor-tickets: a role check can't
-- be expressed in the frontend nav config (lib/nav.ts is permission-only),
-- which is why the "Ticket Queue" nav item was previously mis-gated on the
-- unrelated mentoring.manage_batches permission.
INSERT INTO public.permissions (id, code, name, description, module, is_active)
VALUES (
    'a1c9c9c1-6b8b-4b6a-9b0f-2f9c8f2d7e11',
    'mentoring.view_tickets',
    'View Mentor Ticket Queue',
    'See the mentor ticket queue (open and assigned requests)',
    'mentoring',
    true
)
ON CONFLICT (code) DO NOTHING;

-- Grant to the same three roles the old role check allowed: mentor,
-- instructor, tenant_admin (system role ids, seeded in 001_baseline.sql).
INSERT INTO public.role_permissions (role_id, permission_id)
VALUES
    ('11111111-1111-1111-1111-000000000003', 'a1c9c9c1-6b8b-4b6a-9b0f-2f9c8f2d7e11'), -- instructor
    ('11111111-1111-1111-1111-000000000004', 'a1c9c9c1-6b8b-4b6a-9b0f-2f9c8f2d7e11'), -- mentor
    ('11111111-1111-1111-1111-000000000005', 'a1c9c9c1-6b8b-4b6a-9b0f-2f9c8f2d7e11')  -- tenant_admin
ON CONFLICT DO NOTHING;

-- content_reports_reason_check never allowed the reasons
-- internal/mentoring.CreateReport actually writes (unresponsive,
-- inappropriate_behavior, unqualified) — reporting a mentor for anything but
-- "other" has been failing the CHECK constraint. Widen it to cover both the
-- original content-report reasons and the mentor-report reasons.
ALTER TABLE public.content_reports DROP CONSTRAINT IF EXISTS content_reports_reason_check;
ALTER TABLE public.content_reports ADD CONSTRAINT content_reports_reason_check
    CHECK ((reason = ANY (ARRAY[
        'illegal'::text, 'copyright'::text, 'spam'::text, 'harassment'::text,
        'unresponsive'::text, 'inappropriate_behavior'::text, 'unqualified'::text,
        'other'::text
    ])));
