-- ═════════════════════════════════════════════════════════════════════════
-- Migration 021 — support_tickets
-- ═════════════════════════════════════════════════════════════════════════
-- General-purpose helpdesk, deliberately separate from mentor_tickets
-- (internal/mentoring) — that table is a per-student "needs a mentor for
-- this course" match record with no subject/category, whereas a support
-- ticket is any org member (student, mentor, instructor, admin) raising an
-- arbitrary issue (billing, technical, account, course content) with no
-- course-enrollment relationship at all. Modeled closely on mentor_tickets +
-- mentor_chat_messages (status lifecycle, a durable reply thread) since that
-- shape has already proven out, but kept in its own table rather than
-- overloaded onto mentor_tickets.

CREATE TABLE public.support_tickets (
    id           uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    org_id       uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    user_id      uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    subject      text NOT NULL,
    category     text DEFAULT 'other' NOT NULL,
    priority     text DEFAULT 'normal' NOT NULL,
    status       text DEFAULT 'open' NOT NULL,
    assigned_to  uuid REFERENCES public.users(id) ON DELETE SET NULL,
    resolved_at  timestamp with time zone,
    created_at   timestamp with time zone DEFAULT now() NOT NULL,
    updated_at   timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT support_tickets_subject_check CHECK ((length(subject) >= 3) AND (length(subject) <= 200)),
    CONSTRAINT support_tickets_category_check CHECK (category = ANY (ARRAY['technical'::text, 'billing'::text, 'account'::text, 'course_content'::text, 'other'::text])),
    CONSTRAINT support_tickets_priority_check CHECK (priority = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text])),
    CONSTRAINT support_tickets_status_check CHECK (status = ANY (ARRAY['open'::text, 'in_progress'::text, 'resolved'::text, 'closed'::text]))
);

-- The staff queue's default view (all open org tickets, newest first) and
-- "my tickets" (a user's own, any status) are the only two access patterns.
CREATE INDEX idx_support_tickets_org_status ON public.support_tickets (org_id, status, created_at DESC);
CREATE INDEX idx_support_tickets_user ON public.support_tickets (user_id, created_at DESC);

-- One reply thread per ticket, same shape as mentor_chat_messages — every
-- party (the reporter and whichever staff member picks it up) posts here.
CREATE TABLE public.support_ticket_messages (
    id         uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    org_id     uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    ticket_id  uuid NOT NULL REFERENCES public.support_tickets(id) ON DELETE CASCADE,
    sender_id  uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    body       text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT support_ticket_messages_body_check CHECK ((length(body) >= 1) AND (length(body) <= 4000))
);

CREATE INDEX idx_support_ticket_messages_ticket ON public.support_ticket_messages (ticket_id, created_at ASC);

-- ── RBAC ─────────────────────────────────────────────────────────────────
-- Gates the staff queue (view every ticket in the org, reply, change
-- status). Raising a ticket about yourself, viewing your own tickets, and
-- replying on your own ticket's thread need no permission at all — that's
-- every org member. Granted by default to mentor/instructor/tenant_admin —
-- the people already handling student-facing issues day to day.
INSERT INTO public.permissions (code, name, description, module)
VALUES ('support.manage', 'Manage Support Tickets',
        'View every support ticket in the org, reply, and change ticket status', 'support')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
  FROM public.roles r
  CROSS JOIN public.permissions p
 WHERE p.code = 'support.manage'
   AND r.is_system
   AND r.name IN ('tenant_admin', 'instructor', 'mentor')
ON CONFLICT DO NOTHING;
