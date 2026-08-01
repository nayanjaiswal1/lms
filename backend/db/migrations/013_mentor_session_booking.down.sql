-- Reverse of 013_mentor_session_booking.sql. Dropped in dependency order
-- (children first) so no FK blocks the drop.
--
-- btree_gist is deliberately NOT dropped: CREATE EXTENSION IF NOT EXISTS is
-- a no-op when something else already installed it, so dropping it here
-- could remove an extension this migration never created.

-- role_permissions.permission_id has no ON DELETE CASCADE, so the grants must
-- go before the permission they reference.
DELETE FROM public.role_permissions
 WHERE permission_id IN (
   SELECT id FROM public.permissions WHERE code = 'mentoring.manage_session_booking'
 );
DELETE FROM public.permissions WHERE code = 'mentoring.manage_session_booking';

DROP TABLE IF EXISTS public.mentor_session_notes;
DROP TABLE IF EXISTS public.mentor_session_feedback;
DROP TABLE IF EXISTS public.session_credit_ledger;
DROP TABLE IF EXISTS public.mentor_sessions;
DROP TABLE IF EXISTS public.session_pack_purchases;
DROP TABLE IF EXISTS public.session_credit_packs;
DROP TABLE IF EXISTS public.mentor_availability_exceptions;
DROP TABLE IF EXISTS public.mentor_availability_rules;
DROP TABLE IF EXISTS public.org_session_booking_config;
