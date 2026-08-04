-- ═════════════════════════════════════════════════════════════════════════
-- Migration 023 — content_reports
-- ═════════════════════════════════════════════════════════════════════════
-- Lets any org member flag a specific piece of user-generated content
-- (a wiki page, a course module) as illegal, infringing, or abusive, and
-- gives staff a queue to review and resolve those flags. Kept as its own
-- table rather than a support_tickets category: a report points at an
-- arbitrary content_type/content_id pair and has a different status
-- lifecycle (removed/dismissed, not an escalation chain).

CREATE TABLE public.content_reports (
    id              uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    org_id          uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    reporter_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    content_type    text NOT NULL,
    content_id      uuid NOT NULL,
    reason          text NOT NULL,
    description     text,
    status          text DEFAULT 'pending' NOT NULL,
    resolved_by     uuid REFERENCES public.users(id) ON DELETE SET NULL,
    resolution_note text,
    created_at      timestamp with time zone DEFAULT now() NOT NULL,
    updated_at      timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT content_reports_content_type_check CHECK (content_type = ANY (ARRAY['wiki_page'::text, 'course_module'::text])),
    CONSTRAINT content_reports_reason_check CHECK (reason = ANY (ARRAY['illegal'::text, 'copyright'::text, 'spam'::text, 'harassment'::text, 'other'::text])),
    CONSTRAINT content_reports_status_check CHECK (status = ANY (ARRAY['pending'::text, 'reviewing'::text, 'removed'::text, 'dismissed'::text]))
);

-- Staff queue's default view (org's open reports, newest first).
CREATE INDEX idx_content_reports_org_status ON public.content_reports (org_id, status, created_at DESC);
-- "Has this piece of content already been reported?" lookup.
CREATE INDEX idx_content_reports_content ON public.content_reports (content_type, content_id);

-- ── RBAC ─────────────────────────────────────────────────────────────────
-- Gates the staff moderation queue (view every report in the org, resolve
-- it). Filing a report needs no permission — any org member may do it.
INSERT INTO public.permissions (code, name, description, module)
VALUES ('content.moderate', 'Moderate Content Reports',
        'View and resolve reports of illegal or infringing content', 'moderation')
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
  FROM public.roles r
  CROSS JOIN public.permissions p
 WHERE p.code = 'content.moderate'
   AND r.is_system
   AND r.name IN ('tenant_admin')
ON CONFLICT DO NOTHING;
