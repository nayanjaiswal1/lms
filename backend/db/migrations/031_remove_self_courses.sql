-- Self-courses (a student's own private course tree) are removed. Any
-- existing kind='self' rows would otherwise silently reappear as ordinary
-- org courses once the kind/owner_id columns are dropped, so delete them
-- first — cascades to their sections/modules/enrollments via existing FKs.
DELETE FROM courses WHERE kind = 'self';

ALTER TABLE courses DROP CONSTRAINT courses_self_has_owner_check;
ALTER TABLE courses DROP CONSTRAINT courses_kind_check;
DROP INDEX idx_courses_owner_self;
ALTER TABLE courses DROP COLUMN kind;
ALTER TABLE courses DROP COLUMN owner_id;
