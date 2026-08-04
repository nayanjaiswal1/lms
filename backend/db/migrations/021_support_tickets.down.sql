-- ═════════════════════════════════════════════════════════════════════════
-- Migration 021 — support_tickets (rollback)
-- ═════════════════════════════════════════════════════════════════════════

DELETE FROM public.role_permissions
 WHERE permission_id = (SELECT id FROM public.permissions WHERE code = 'support.manage');

DELETE FROM public.permissions WHERE code = 'support.manage';

DROP TABLE IF EXISTS public.support_ticket_messages;
DROP TABLE IF EXISTS public.support_tickets;
