package courses

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("courses: not found")
var ErrForbidden = errors.New("courses: forbidden")
var ErrConflict = errors.New("courses: conflict")

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

func (r *Repo) tx(ctx context.Context, fn func(pgx.Tx) error) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("courses: begin tx: %w", err)
	}
	if err := fn(tx); err != nil {
		_ = tx.Rollback(ctx)
		return err
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("courses: commit tx: %w", err)
	}
	return nil
}

// CreateCourse inserts a new course and its default "Introduction" section
// atomically inside a single transaction.
func (r *Repo) CreateCourse(ctx context.Context, c Course) (Course, error) {
	err := r.tx(ctx, func(tx pgx.Tx) error {
		err := tx.QueryRow(ctx,
			`INSERT INTO courses (org_id, creator_id, title, slug, description, cover_url, difficulty, tags, status, price_cents, is_free, estimated_hours)
			 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
			 RETURNING id, created_at, updated_at`,
			c.OrgID, c.CreatorID, c.Title, c.Slug, c.Description, c.CoverURL, c.Difficulty,
			c.Tags, c.Status, c.PriceCents, c.IsFree, c.EstimatedHours,
		).Scan(&c.ID, &c.CreatedAt, &c.UpdatedAt)
		if err != nil {
			return fmt.Errorf("courses: create: %w", err)
		}
		if _, err := tx.Exec(ctx,
			`INSERT INTO course_sections (course_id, title, position) VALUES ($1, 'Introduction', 0)`,
			c.ID,
		); err != nil {
			return fmt.Errorf("courses: create default section: %w", err)
		}
		return nil
	})
	if err != nil {
		return Course{}, err
	}
	return c, nil
}

// GetCourse returns a single course by ID with org scope.
func (r *Repo) GetCourse(ctx context.Context, orgID, id string) (Course, error) {
	var c Course
	err := r.pool.QueryRow(ctx,
		`SELECT id, org_id, creator_id, title, slug, description, cover_url, difficulty, tags,
		        status, forked_from_id, price_cents, is_free, estimated_hours, created_at, updated_at
		 FROM courses WHERE id = $1 AND org_id = $2`, id, orgID,
	).Scan(&c.ID, &c.OrgID, &c.CreatorID, &c.Title, &c.Slug, &c.Description, &c.CoverURL,
		&c.Difficulty, &c.Tags, &c.Status, &c.ForkedFromID, &c.PriceCents, &c.IsFree,
		&c.EstimatedHours, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Course{}, ErrNotFound
		}
		return Course{}, fmt.Errorf("courses: get: %w", err)
	}
	return c, nil
}

// CourseFilter is used by ListCourses.
type CourseFilter struct {
	Status     string
	Difficulty string
	Search     string
	Limit      int
	Offset     int
}

// ListCourses returns courses matching the filter for an org.
func (r *Repo) ListCourses(ctx context.Context, orgID string, filter CourseFilter) ([]Course, int, error) {
	args := []any{orgID}
	where := "WHERE c.org_id = $1"
	n := 2

	if filter.Status != "" {
		where += fmt.Sprintf(" AND c.status = $%d", n)
		args = append(args, filter.Status)
		n++
	}
	if filter.Difficulty != "" {
		where += fmt.Sprintf(" AND c.difficulty = $%d", n)
		args = append(args, filter.Difficulty)
		n++
	}
	if filter.Search != "" {
		where += fmt.Sprintf(" AND (c.title ILIKE $%d OR c.description ILIKE $%d)", n, n)
		args = append(args, "%"+filter.Search+"%")
		n++
	}

	limit := filter.Limit
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	offset := filter.Offset
	if offset < 0 {
		offset = 0
	}

	var total int
	if err := r.pool.QueryRow(ctx, `SELECT count(*) FROM courses c `+where, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("courses: count: %w", err)
	}

	args = append(args, limit, offset)
	rows, err := r.pool.Query(ctx,
		`SELECT c.id, c.org_id, c.creator_id, c.title, c.slug, c.description, c.cover_url,
		        c.difficulty, c.tags, c.status, c.forked_from_id, c.price_cents, c.is_free,
		        c.estimated_hours, c.created_at, c.updated_at
		 FROM courses c `+where+fmt.Sprintf(` ORDER BY c.created_at DESC LIMIT $%d OFFSET $%d`, n, n+1),
		args...)
	if err != nil {
		return nil, 0, fmt.Errorf("courses: list: %w", err)
	}
	defer rows.Close()

	out := []Course{}
	for rows.Next() {
		var c Course
		if err := rows.Scan(&c.ID, &c.OrgID, &c.CreatorID, &c.Title, &c.Slug, &c.Description,
			&c.CoverURL, &c.Difficulty, &c.Tags, &c.Status, &c.ForkedFromID, &c.PriceCents,
			&c.IsFree, &c.EstimatedHours, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, 0, fmt.Errorf("courses: scan: %w", err)
		}
		out = append(out, c)
	}
	return out, total, rows.Err()
}

// UpdateCourse updates mutable course metadata.
func (r *Repo) UpdateCourse(ctx context.Context, orgID string, c Course) (Course, error) {
	err := r.pool.QueryRow(ctx,
		`UPDATE courses SET title=$3, description=$4, cover_url=$5, difficulty=$6, tags=$7,
		        estimated_hours=$8, price_cents=$9, is_free=$10, updated_at=now()
		 WHERE id=$1 AND org_id=$2
		 RETURNING updated_at`,
		c.ID, orgID, c.Title, c.Description, c.CoverURL, c.Difficulty, c.Tags,
		c.EstimatedHours, c.PriceCents, c.IsFree,
	).Scan(&c.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Course{}, ErrNotFound
		}
		return Course{}, fmt.Errorf("courses: update: %w", err)
	}
	return c, nil
}

// PublishCourse transitions a course from draft/review to published.
func (r *Repo) PublishCourse(ctx context.Context, orgID, id string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE courses SET status='published', updated_at=now()
		 WHERE id=$1 AND org_id=$2 AND status IN ('draft','review')`, id, orgID)
	if err != nil {
		return fmt.Errorf("courses: publish: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ArchiveCourse soft-archives a course.
func (r *Repo) ArchiveCourse(ctx context.Context, orgID, id string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE courses SET status='archived', updated_at=now() WHERE id=$1 AND org_id=$2`, id, orgID)
	if err != nil {
		return fmt.Errorf("courses: archive: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// GetCourseTree loads a course with all its sections and modules in a single query.
func (r *Repo) GetCourseTree(ctx context.Context, orgID, courseID string) (CourseTree, error) {
	c, err := r.GetCourse(ctx, orgID, courseID)
	if err != nil {
		return CourseTree{}, err
	}

	sectionRows, err := r.pool.Query(ctx,
		`SELECT id, course_id, title, position, created_at FROM course_sections
		 WHERE course_id = $1 ORDER BY position`, courseID)
	if err != nil {
		return CourseTree{}, fmt.Errorf("courses: get sections: %w", err)
	}
	defer sectionRows.Close()

	var sections []CourseSection
	for sectionRows.Next() {
		var s CourseSection
		if err := sectionRows.Scan(&s.ID, &s.CourseID, &s.Title, &s.Position, &s.CreatedAt); err != nil {
			return CourseTree{}, fmt.Errorf("courses: scan section: %w", err)
		}
		sections = append(sections, s)
	}
	if err := sectionRows.Err(); err != nil {
		return CourseTree{}, fmt.Errorf("courses: section rows: %w", err)
	}

	modRows, err := r.pool.Query(ctx,
		`SELECT id, course_id, section_id, title, type, position, is_free_preview,
		        storage_key, duration_seconds, content_body, assessment_id, estimated_minutes,
		        created_at, updated_at
		 FROM course_modules WHERE course_id = $1 AND deleted_at IS NULL ORDER BY section_id, position`, courseID)
	if err != nil {
		return CourseTree{}, fmt.Errorf("courses: get modules: %w", err)
	}
	defer modRows.Close()

	modsBySectionID := map[string][]CourseModule{}
	for modRows.Next() {
		var m CourseModule
		if err := modRows.Scan(&m.ID, &m.CourseID, &m.SectionID, &m.Title, &m.Type, &m.Position,
			&m.IsFreePreview, &m.StorageKey, &m.DurationSeconds, &m.ContentBody,
			&m.AssessmentID, &m.EstimatedMinutes, &m.CreatedAt, &m.UpdatedAt); err != nil {
			return CourseTree{}, fmt.Errorf("courses: scan module: %w", err)
		}
		modsBySectionID[m.SectionID] = append(modsBySectionID[m.SectionID], m)
	}
	if err := modRows.Err(); err != nil {
		return CourseTree{}, fmt.Errorf("courses: module rows: %w", err)
	}

	tree := CourseTree{Course: c}
	for _, s := range sections {
		swm := SectionWithModules{CourseSection: s, Modules: modsBySectionID[s.ID]}
		if swm.Modules == nil {
			swm.Modules = []CourseModule{}
		}
		tree.Sections = append(tree.Sections, swm)
	}
	if tree.Sections == nil {
		tree.Sections = []SectionWithModules{}
	}
	return tree, nil
}

// CreateSection inserts a course section.
func (r *Repo) CreateSection(ctx context.Context, s CourseSection) (CourseSection, error) {
	err := r.pool.QueryRow(ctx,
		`INSERT INTO course_sections (course_id, title, position)
		 VALUES ($1,$2, COALESCE((SELECT MAX(position)+1 FROM course_sections WHERE course_id=$1),0))
		 RETURNING id, position, created_at`,
		s.CourseID, s.Title,
	).Scan(&s.ID, &s.Position, &s.CreatedAt)
	if err != nil {
		return CourseSection{}, fmt.Errorf("courses: create section: %w", err)
	}
	return s, nil
}

// GetSectionForOrg returns a section only when its parent course belongs to orgID.
func (r *Repo) GetSectionForOrg(ctx context.Context, orgID, sectionID string) (CourseSection, error) {
	var s CourseSection
	err := r.pool.QueryRow(ctx,
		`SELECT cs.id, cs.course_id, cs.title, cs.position, cs.created_at
		 FROM course_sections cs
		 JOIN courses c ON c.id = cs.course_id
		 WHERE cs.id = $1 AND c.org_id = $2`, sectionID, orgID,
	).Scan(&s.ID, &s.CourseID, &s.Title, &s.Position, &s.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return CourseSection{}, ErrNotFound
		}
		return CourseSection{}, fmt.Errorf("courses: get section for org: %w", err)
	}
	return s, nil
}

// UpdateSection updates section title.
func (r *Repo) UpdateSection(ctx context.Context, orgID string, s CourseSection) (CourseSection, error) {
	err := r.pool.QueryRow(ctx,
		`UPDATE course_sections cs SET title=$2
		 FROM courses c WHERE cs.id=$1 AND cs.course_id=c.id AND c.org_id=$3
		 RETURNING cs.id, cs.course_id, cs.title, cs.position, cs.created_at`,
		s.ID, s.Title, orgID,
	).Scan(&s.ID, &s.CourseID, &s.Title, &s.Position, &s.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return CourseSection{}, ErrNotFound
		}
		return CourseSection{}, fmt.Errorf("courses: update section: %w", err)
	}
	return s, nil
}

// DeleteSection cascades to modules (FK ON DELETE CASCADE).
func (r *Repo) DeleteSection(ctx context.Context, orgID, sectionID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM course_sections cs USING courses c
		 WHERE cs.id=$1 AND cs.course_id=c.id AND c.org_id=$2`, sectionID, orgID)
	if err != nil {
		return fmt.Errorf("courses: delete section: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ReorderSections sets positions for all sections in a course in a single query.
func (r *Repo) ReorderSections(ctx context.Context, orgID, courseID string, sectionIDs []string) error {
	if len(sectionIDs) == 0 {
		return nil
	}
	positions := make([]int, len(sectionIDs))
	for i := range positions {
		positions[i] = i
	}
	return r.tx(ctx, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx,
			`UPDATE course_sections cs
			 SET position = u.pos
			 FROM unnest($1::uuid[], $2::int[]) AS u(id, pos)
			 JOIN courses c ON c.id = cs.course_id
			 WHERE cs.id = u.id AND c.id = $3 AND c.org_id = $4`,
			sectionIDs, positions, courseID, orgID)
		if err != nil {
			return fmt.Errorf("courses: reorder sections: %w", err)
		}
		return nil
	})
}

// CreateModule inserts a course module in a section.
func (r *Repo) CreateModule(ctx context.Context, m CourseModule) (CourseModule, error) {
	err := r.pool.QueryRow(ctx,
		`INSERT INTO course_modules (course_id, section_id, title, type, position, is_free_preview,
		  storage_key, duration_seconds, content_body, assessment_id, estimated_minutes)
		 VALUES ($1,$2,$3,$4,
		   COALESCE((SELECT MAX(position)+1 FROM course_modules WHERE section_id=$2 AND deleted_at IS NULL),0),
		   $5,$6,$7,$8,$9,$10)
		 RETURNING id, position, created_at, updated_at`,
		m.CourseID, m.SectionID, m.Title, m.Type, m.IsFreePreview,
		m.StorageKey, m.DurationSeconds, m.ContentBody, m.AssessmentID, m.EstimatedMinutes,
	).Scan(&m.ID, &m.Position, &m.CreatedAt, &m.UpdatedAt)
	if err != nil {
		return CourseModule{}, fmt.Errorf("courses: create module: %w", err)
	}
	return m, nil
}

// GetModule returns a single module; respects org scope via course FK.
func (r *Repo) GetModule(ctx context.Context, orgID, moduleID string) (CourseModule, error) {
	var m CourseModule
	err := r.pool.QueryRow(ctx,
		`SELECT cm.id, cm.course_id, cm.section_id, cm.title, cm.type, cm.position,
		        cm.is_free_preview, cm.storage_key, cm.duration_seconds, cm.content_body,
		        cm.assessment_id, cm.estimated_minutes, cm.created_at, cm.updated_at
		 FROM course_modules cm
		 JOIN courses c ON c.id = cm.course_id
		 WHERE cm.id=$1 AND c.org_id=$2 AND cm.deleted_at IS NULL`, moduleID, orgID,
	).Scan(&m.ID, &m.CourseID, &m.SectionID, &m.Title, &m.Type, &m.Position,
		&m.IsFreePreview, &m.StorageKey, &m.DurationSeconds, &m.ContentBody,
		&m.AssessmentID, &m.EstimatedMinutes, &m.CreatedAt, &m.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return CourseModule{}, ErrNotFound
		}
		return CourseModule{}, fmt.Errorf("courses: get module: %w", err)
	}
	return m, nil
}

// UpdateModule updates mutable module fields.
func (r *Repo) UpdateModule(ctx context.Context, orgID string, m CourseModule) (CourseModule, error) {
	err := r.pool.QueryRow(ctx,
		`UPDATE course_modules cm SET title=$3, is_free_preview=$4, storage_key=$5,
		        duration_seconds=$6, content_body=$7, assessment_id=$8, estimated_minutes=$9, updated_at=now()
		 FROM courses c WHERE cm.id=$1 AND cm.course_id=c.id AND c.org_id=$2 AND cm.deleted_at IS NULL
		 RETURNING cm.updated_at`,
		m.ID, orgID, m.Title, m.IsFreePreview, m.StorageKey, m.DurationSeconds,
		m.ContentBody, m.AssessmentID, m.EstimatedMinutes,
	).Scan(&m.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return CourseModule{}, ErrNotFound
		}
		return CourseModule{}, fmt.Errorf("courses: update module: %w", err)
	}
	return m, nil
}

// SoftDeleteModule sets deleted_at; the module remains in DB for progress integrity.
func (r *Repo) SoftDeleteModule(ctx context.Context, orgID, moduleID string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE course_modules cm SET deleted_at=now()
		 FROM courses c WHERE cm.id=$1 AND cm.course_id=c.id AND c.org_id=$2 AND cm.deleted_at IS NULL`,
		moduleID, orgID)
	if err != nil {
		return fmt.Errorf("courses: soft delete module: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ReorderModules sets positions for modules in a section in a single query.
func (r *Repo) ReorderModules(ctx context.Context, orgID, sectionID string, moduleIDs []string) error {
	if len(moduleIDs) == 0 {
		return nil
	}
	positions := make([]int, len(moduleIDs))
	for i := range positions {
		positions[i] = i
	}
	return r.tx(ctx, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx,
			`UPDATE course_modules cm
			 SET position = u.pos
			 FROM unnest($1::uuid[], $2::int[]) AS u(id, pos)
			 JOIN course_sections cs ON cs.id = cm.section_id
			 JOIN courses c ON c.id = cs.course_id
			 WHERE cm.id = u.id AND cs.id = $3 AND c.org_id = $4 AND cm.deleted_at IS NULL`,
			moduleIDs, positions, sectionID, orgID)
		if err != nil {
			return fmt.Errorf("courses: reorder modules: %w", err)
		}
		return nil
	})
}

// CreateEnrollment enrolls a user in a course. Ignores duplicate (ON CONFLICT DO NOTHING).
func (r *Repo) CreateEnrollment(ctx context.Context, e Enrollment) (Enrollment, error) {
	err := r.pool.QueryRow(ctx,
		`INSERT INTO enrollments (user_id, course_id, batch_id, enrolled_by)
		 VALUES ($1,$2,$3,$4)
		 ON CONFLICT (user_id, course_id) DO NOTHING
		 RETURNING id, enrolled_at`,
		e.UserID, e.CourseID, e.BatchID, e.EnrolledBy,
	).Scan(&e.ID, &e.EnrolledAt)
	if err != nil {
		return Enrollment{}, fmt.Errorf("courses: create enrollment: %w", err)
	}
	return e, nil
}

// IsEnrolled checks if a user is enrolled in a course.
func (r *Repo) IsEnrolled(ctx context.Context, userID, courseID string) (bool, error) {
	var ok bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM enrollments WHERE user_id=$1 AND course_id=$2)`, userID, courseID,
	).Scan(&ok)
	return ok, err
}

// GetMyEnrollments returns all courses a student is enrolled in within an org, with course data joined.
func (r *Repo) GetMyEnrollments(ctx context.Context, userID, orgID string) ([]Enrollment, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT e.id, e.user_id, e.course_id, e.batch_id, e.enrolled_by, e.enrolled_at, e.completed_at,
		        c.id, c.org_id, c.creator_id, c.title, c.slug, c.description, c.cover_url,
		        c.difficulty, c.tags, c.status, c.forked_from_id, c.price_cents, c.is_free,
		        c.estimated_hours, c.created_at, c.updated_at
		 FROM enrollments e
		 JOIN courses c ON c.id = e.course_id
		 WHERE e.user_id = $1 AND c.org_id = $2
		 ORDER BY e.enrolled_at DESC`, userID, orgID)
	if err != nil {
		return nil, fmt.Errorf("courses: my enrollments: %w", err)
	}
	defer rows.Close()
	out := []Enrollment{}
	for rows.Next() {
		var e Enrollment
		if err := rows.Scan(
			&e.ID, &e.UserID, &e.CourseID, &e.BatchID, &e.EnrolledBy, &e.EnrolledAt, &e.CompletedAt,
			&e.Course.ID, &e.Course.OrgID, &e.Course.CreatorID, &e.Course.Title, &e.Course.Slug,
			&e.Course.Description, &e.Course.CoverURL, &e.Course.Difficulty, &e.Course.Tags,
			&e.Course.Status, &e.Course.ForkedFromID, &e.Course.PriceCents, &e.Course.IsFree,
			&e.Course.EstimatedHours, &e.Course.CreatedAt, &e.Course.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("courses: scan enrollment: %w", err)
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// UpsertProgress creates or updates module progress.
func (r *Repo) UpsertProgress(ctx context.Context, p ModuleProgress) (ModuleProgress, error) {
	err := r.pool.QueryRow(ctx,
		`INSERT INTO module_progress (user_id, module_id, course_id, status, last_position_seconds, completed_at)
		 VALUES ($1,$2,$3,$4,$5,$6)
		 ON CONFLICT (user_id, module_id) DO UPDATE
		   SET status=EXCLUDED.status, last_position_seconds=EXCLUDED.last_position_seconds,
		       completed_at=EXCLUDED.completed_at, updated_at=now()
		 RETURNING id, updated_at`,
		p.UserID, p.ModuleID, p.CourseID, p.Status, p.LastPositionSeconds, p.CompletedAt,
	).Scan(&p.ID, &p.UpdatedAt)
	if err != nil {
		return ModuleProgress{}, fmt.Errorf("courses: upsert progress: %w", err)
	}
	return p, nil
}

// GetCourseProgress computes the completion percentage for a user in a course.
func (r *Repo) GetCourseProgress(ctx context.Context, userID, courseID string) (CourseProgress, error) {
	var cp CourseProgress
	err := r.pool.QueryRow(ctx,
		`SELECT
		   COUNT(*) FILTER (WHERE mp.status = 'completed') AS completed,
		   COUNT(*) AS total,
		   ROUND(100.0 * COUNT(*) FILTER (WHERE mp.status = 'completed') / NULLIF(COUNT(*), 0), 1)
		 FROM course_modules cm
		 LEFT JOIN module_progress mp ON mp.module_id = cm.id AND mp.user_id = $1
		 WHERE cm.course_id = $2 AND cm.deleted_at IS NULL`,
		userID, courseID,
	).Scan(&cp.Completed, &cp.Total, &cp.Pct)
	if err != nil {
		return CourseProgress{}, fmt.Errorf("courses: get progress: %w", err)
	}
	return cp, nil
}

// GetAllStudentProgress returns progress rows for all enrolled students (instructor view).
func (r *Repo) GetAllStudentProgress(ctx context.Context, orgID, courseID string) ([]StudentProgress, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT u.id, u.name, u.email,
		        COUNT(*) FILTER (WHERE mp.status = 'completed') AS completed,
		        COUNT(*) AS total,
		        ROUND(100.0 * COUNT(*) FILTER (WHERE mp.status = 'completed') / NULLIF(COUNT(*), 0), 1) AS pct
		 FROM enrollments e
		 JOIN users u ON u.id=e.user_id
		 JOIN courses c ON c.id=e.course_id
		 LEFT JOIN course_modules cm ON cm.course_id=e.course_id AND cm.deleted_at IS NULL
		 LEFT JOIN module_progress mp ON mp.module_id=cm.id AND mp.user_id=e.user_id
		 WHERE e.course_id=$1 AND c.org_id=$2
		 GROUP BY u.id, u.name, u.email`, courseID, orgID)
	if err != nil {
		return nil, fmt.Errorf("courses: all student progress: %w", err)
	}
	defer rows.Close()
	out := []StudentProgress{}
	for rows.Next() {
		var sp StudentProgress
		if err := rows.Scan(&sp.UserID, &sp.Name, &sp.Email, &sp.Completed, &sp.Total, &sp.Pct); err != nil {
			return nil, fmt.Errorf("courses: scan student progress: %w", err)
		}
		out = append(out, sp)
	}
	return out, rows.Err()
}

// ForkCourse copies a course (with sections and modules) under a new creator.
func (r *Repo) ForkCourse(ctx context.Context, orgID, originalID, creatorID, newTitle, newSlug string) (Course, error) {
	var newCourse Course
	err := r.tx(ctx, func(tx pgx.Tx) error {
		err := tx.QueryRow(ctx,
			`INSERT INTO courses (org_id, creator_id, title, slug, description, difficulty, tags, forked_from_id, price_cents, is_free)
			 SELECT $1,$2,$3,$4,description,difficulty,tags,$5,price_cents,is_free
			 FROM courses WHERE id=$5 AND org_id=$1
			 RETURNING id, org_id, creator_id, title, slug, description, difficulty, tags, status, forked_from_id, price_cents, is_free, created_at, updated_at`,
			orgID, creatorID, newTitle, newSlug, originalID,
		).Scan(&newCourse.ID, &newCourse.OrgID, &newCourse.CreatorID, &newCourse.Title, &newCourse.Slug,
			&newCourse.Description, &newCourse.Difficulty, &newCourse.Tags, &newCourse.Status,
			&newCourse.ForkedFromID, &newCourse.PriceCents, &newCourse.IsFree, &newCourse.CreatedAt, &newCourse.UpdatedAt)
		if err != nil {
			return fmt.Errorf("courses: fork course: %w", err)
		}

		// Fetch original section IDs in order
		origSecs, err := tx.Query(ctx, `SELECT id FROM course_sections WHERE course_id=$1 ORDER BY position`, originalID)
		if err != nil {
			return fmt.Errorf("courses: fork get orig sections: %w", err)
		}
		defer origSecs.Close()
		var origSecIDs []string
		for origSecs.Next() {
			var id string
			if err := origSecs.Scan(&id); err != nil {
				return fmt.Errorf("courses: fork scan orig section: %w", err)
			}
			origSecIDs = append(origSecIDs, id)
		}
		if err := origSecs.Err(); err != nil {
			return fmt.Errorf("courses: fork orig section rows: %w", err)
		}

		// Copy sections and collect new IDs in order
		secRows, err := tx.Query(ctx,
			`INSERT INTO course_sections (course_id, title, position)
			 SELECT $1, title, position FROM course_sections WHERE course_id=$2 ORDER BY position
			 RETURNING id`,
			newCourse.ID, originalID)
		if err != nil {
			return fmt.Errorf("courses: fork sections: %w", err)
		}
		defer secRows.Close()
		var newSecIDs []string
		for secRows.Next() {
			var id string
			if err := secRows.Scan(&id); err != nil {
				return fmt.Errorf("courses: fork scan new section: %w", err)
			}
			newSecIDs = append(newSecIDs, id)
		}
		if err := secRows.Err(); err != nil {
			return fmt.Errorf("courses: fork new section rows: %w", err)
		}

		// Copy modules for each section
		for i, origSecID := range origSecIDs {
			if i >= len(newSecIDs) {
				break
			}
			if _, err := tx.Exec(ctx,
				`INSERT INTO course_modules (course_id, section_id, title, type, position, is_free_preview, storage_key, duration_seconds, content_body, assessment_id, estimated_minutes)
				 SELECT $1,$2,title,type,position,is_free_preview,storage_key,duration_seconds,content_body,assessment_id,estimated_minutes
				 FROM course_modules WHERE section_id=$3 AND deleted_at IS NULL ORDER BY position`,
				newCourse.ID, newSecIDs[i], origSecID); err != nil {
				return fmt.Errorf("courses: fork modules for section %s: %w", origSecID, err)
			}
		}
		return nil
	})
	if err != nil {
		return Course{}, err
	}
	return newCourse, nil
}
