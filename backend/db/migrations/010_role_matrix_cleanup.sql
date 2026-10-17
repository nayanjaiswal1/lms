-- 010_role_matrix_cleanup.sql
-- Phase 3 of the RBAC consolidation: the system role -> permission matrix is
-- fixed in data instead of being papered over in the UI.
--
--   D1  tenant_admin loses the learner-only codes: practice.use, content.srs,
--       content.sheets, content.learning_journal, content.diary,
--       content.captures, content.interview_exp, content.certificates.
--       Kept: courses.enroll (no route enforces it; enrolling to preview a
--       course is an admin action), content.wiki, content.system_design.
--       Staff routes that used to ride on practice.use (starting a lab from a
--       course module, the lab catalog) now also admit courses.edit.
--   D4  viewer loses projects.view.
--   Dead codes content.interview_board and content.load_test are deleted with
--       every grant and override that references them (no route, MCP tool or
--       frontend gate checks them).
--
-- Before revoking, every owner/admin membership (active or suspended) with
-- learner activity in that org is granted the system member role, so admins
-- who actually use the learner tools keep them. Activity is org-scoped where
-- the table carries org_id (interview_prep_plans, roadmaps, practice
-- attempts, learning_annotations, certificates via their course); rows in
-- user-scoped tables (journal, diary, captures, SRS, sheet progress,
-- interview experiences) count only when the user belongs to exactly one org.
-- Grants are recorded in rbac_backfill_010; every removed row is snapshotted
-- into rbac_010_removed_* so the down migration restores exactly what was
-- here. Custom roles keep their grants, except grants of the two dead codes.
-- Cached permission sets (Redis rbac:perms:*) refresh within their 5-minute TTL.

CREATE TABLE rbac_backfill_010 (
    user_id uuid NOT NULL,
    role_id uuid NOT NULL,
    org_id  uuid NOT NULL,
    PRIMARY KEY (user_id, role_id, org_id)
);

WITH single_org AS (
    SELECT user_id, min(org_id::text)::uuid AS org_id
    FROM org_members
    GROUP BY user_id
    HAVING count(*) = 1
),
activity(user_id, org_id) AS (
    SELECT user_id, org_id FROM interview_prep_plans
    UNION SELECT user_id, org_id FROM roadmaps
    UNION SELECT aa.user_id, aa.org_id FROM assessment_attempts aa
          JOIN assessments a ON a.id = aa.assessment_id AND a.type = 'practice'
    UNION SELECT la.user_id, COALESCE(la.org_id, s.org_id) FROM learning_annotations la
          LEFT JOIN single_org s ON s.user_id = la.user_id
    UNION SELECT c.user_id, co.org_id FROM certificates c JOIN courses co ON co.id = c.course_id
    UNION SELECT s.user_id, s.org_id FROM single_org s
          WHERE EXISTS (SELECT 1 FROM learning_journal_entries x WHERE x.user_id = s.user_id)
             OR EXISTS (SELECT 1 FROM diary_entries x WHERE x.user_id = s.user_id)
             OR EXISTS (SELECT 1 FROM diary_tasks x WHERE x.user_id = s.user_id)
             OR EXISTS (SELECT 1 FROM captures x WHERE x.user_id = s.user_id)
             OR EXISTS (SELECT 1 FROM srs_cards x WHERE x.user_id = s.user_id)
             OR EXISTS (SELECT 1 FROM srs_reviews x WHERE x.user_id = s.user_id)
             OR EXISTS (SELECT 1 FROM user_problem_progress x WHERE x.user_id = s.user_id)
             OR EXISTS (SELECT 1 FROM user_sheets x WHERE x.user_id = s.user_id)
             OR EXISTS (SELECT 1 FROM interview_exp_posts x WHERE x.author_id = s.user_id)
             OR EXISTS (SELECT 1 FROM interview_exp_qna_progress x WHERE x.user_id = s.user_id)
),
inserted AS (
    INSERT INTO user_roles (user_id, role_id, org_id)
    SELECT DISTINCT om.user_id, r.id, om.org_id
    FROM org_members om
    JOIN activity a ON a.user_id = om.user_id AND a.org_id = om.org_id
    JOIN roles r ON r.name = 'member' AND r.is_system
    WHERE om.role IN ('owner', 'admin')
      AND om.status IN ('active', 'suspended')
    ON CONFLICT DO NOTHING
    RETURNING user_id, role_id, org_id
)
INSERT INTO rbac_backfill_010 (user_id, role_id, org_id)
SELECT user_id, role_id, org_id FROM inserted;

CREATE TABLE rbac_010_removed_grants AS
SELECT rp.role_id, rp.permission_id
FROM role_permissions rp
JOIN permissions p ON p.id = rp.permission_id
JOIN roles r ON r.id = rp.role_id
WHERE p.code IN ('content.interview_board', 'content.load_test')
   OR (r.is_system AND r.name = 'tenant_admin' AND p.code IN (
        'practice.use', 'content.srs', 'content.sheets', 'content.learning_journal',
        'content.diary', 'content.captures', 'content.interview_exp', 'content.certificates'))
   OR (r.is_system AND r.name = 'viewer' AND p.code = 'projects.view');

CREATE TABLE rbac_010_removed_overrides AS
SELECT upo.*
FROM user_permission_overrides upo
JOIN permissions p ON p.id = upo.permission_id
WHERE p.code IN ('content.interview_board', 'content.load_test');

CREATE TABLE rbac_010_removed_permissions AS
SELECT * FROM permissions WHERE code IN ('content.interview_board', 'content.load_test');

DELETE FROM role_permissions rp
USING rbac_010_removed_grants g
WHERE rp.role_id = g.role_id AND rp.permission_id = g.permission_id;

DELETE FROM user_permission_overrides upo
USING rbac_010_removed_permissions p
WHERE upo.permission_id = p.id;

DELETE FROM permissions p
USING rbac_010_removed_permissions d
WHERE p.id = d.id;
