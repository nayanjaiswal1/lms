-- ══════════════════════════════════════════════════════════════════════════
-- 044_course_library.sql — Course library (Phase A, docs/debug-labs.md Part 3)
--
-- Fixes the forked-course-labs bug: course_modules.lab_id becomes the link
-- from a module to its lab (the same pattern assessment_id already uses),
-- so a forked course's lab modules resolve correctly and one published lab
-- can be placed in more than one module/course ("Add from library").
--
-- course_modules.lab_id is DEFERRABLE INITIALLY DEFERRED: the coursegen
-- fixture pipeline inserts a course_modules row and its lab_definitions row
-- in the same generated script, each referencing the other's id
-- (lab_definitions.module_id -> course_modules.id, course_modules.lab_id ->
-- lab_definitions.id) — a normal FK can't be satisfied at INSERT time on
-- either side, so the check is deferred to the end of that script's implicit
-- transaction (pool.Exec/tx.Exec run a whole multi-statement file as one
-- transaction — see backend/db/seed.go, backend/db/migrate.go).
-- ══════════════════════════════════════════════════════════════════════════
SET LOCAL lock_timeout = '5s';

ALTER TABLE public.course_modules
  ADD COLUMN lab_id UUID REFERENCES public.lab_definitions(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
  ADD COLUMN lab_is_required BOOLEAN NOT NULL DEFAULT false, -- gating is per placement, not per lab
  ADD COLUMN copied_from_module_id UUID REFERENCES public.course_modules(id) ON DELETE SET NULL;

-- Backfill: every existing lab module already has exactly one lab_definitions
-- row pointing back at it via module_id — link them directly.
UPDATE public.course_modules m
SET lab_id = l.id, lab_is_required = l.is_required
FROM public.lab_definitions l
WHERE l.module_id = m.id AND m.type = 'lab' AND m.lab_id IS NULL;

-- Relink already-forked lab modules: copySectionsAndModules (backend/internal/
-- courses/repo.go) never copied a lab link, so a forked course's lab modules
-- have no matching lab_definitions.module_id and were skipped above. Match
-- each still-unlinked lab module back to the original course's lab module at
-- the same (section position, module position) — copySectionsAndModules
-- preserves both — and copy its now-backfilled lab_id/lab_is_required.
UPDATE public.course_modules fm
SET lab_id = om.lab_id, lab_is_required = om.lab_is_required
FROM public.course_sections fs, public.courses fc, public.course_sections os, public.course_modules om
WHERE fm.section_id = fs.id
  AND fs.course_id = fc.id
  AND fc.forked_from_id IS NOT NULL
  AND os.course_id = fc.forked_from_id
  AND os.position = fs.position
  AND om.section_id = os.id
  AND om.position = fm.position
  AND fm.type = 'lab'
  AND fm.lab_id IS NULL
  AND om.lab_id IS NOT NULL;

-- The UPDATEs above queue deferred FK checks for lab_id (INITIALLY DEFERRED).
-- Postgres refuses ALTER TABLE on a table with pending trigger events (55006),
-- so run those checks now, before the ALTERs below.
SET CONSTRAINTS ALL IMMEDIATE;

-- Added NOT VALID (metadata-only, no table scan/lock) so this ships even if
-- the relink above couldn't match every row; VALIDATE only runs — and only
-- takes the cheap ShareUpdateExclusiveLock, not a rewrite — when the backfill
-- report below is actually clean. A dirty backfill leaves the constraint
-- enforced for all NEW/UPDATEd rows (NOT VALID never skips that) but not yet
-- proven for old ones; operator follow-up plus a manual VALIDATE closes it.
ALTER TABLE public.course_modules
  ADD CONSTRAINT lab_module_has_lab CHECK ((type = 'lab') = (lab_id IS NOT NULL)) NOT VALID;

DO $$
DECLARE
  unmatched_count int;
BEGIN
  SELECT count(*) INTO unmatched_count FROM public.course_modules WHERE type = 'lab' AND lab_id IS NULL;
  IF unmatched_count = 0 THEN
    -- DDL isn't a directly-usable PL/pgSQL statement — EXECUTE is required
    -- even though there's nothing dynamic about this particular ALTER TABLE.
    EXECUTE 'ALTER TABLE public.course_modules VALIDATE CONSTRAINT lab_module_has_lab';
    RAISE NOTICE 'lab_module_has_lab: backfill clean, constraint validated';
  ELSE
    RAISE WARNING 'lab_module_has_lab: % course_modules row(s) of type ''lab'' have no lab_id after backfill+relink; constraint left NOT VALID. Run: SELECT id, course_id, section_id, position FROM course_modules WHERE type=''lab'' AND lab_id IS NULL; then VALIDATE CONSTRAINT once fixed.', unmatched_count;
  END IF;
END $$;

ALTER TABLE public.lab_definitions
  ADD COLUMN library_visibility TEXT NOT NULL DEFAULT 'org'
    CHECK (library_visibility IN ('private', 'org', 'platform'));

-- Which placement (course module) launched a session — completion/unlock use
-- this instead of lab_definitions.module_id, so one lab placed in two
-- courses completes the right module in each.
ALTER TABLE public.lab_sessions
  ADD COLUMN module_id UUID REFERENCES public.course_modules(id);

CREATE INDEX idx_course_modules_lab_id ON public.course_modules (lab_id) WHERE lab_id IS NOT NULL;
