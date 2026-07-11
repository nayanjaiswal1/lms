-- Instructors opt a course into the anonymous public marketplace (landing-page
-- catalog). Default false so org-internal published courses stay private.
ALTER TABLE courses ADD COLUMN is_public BOOLEAN NOT NULL DEFAULT false;
