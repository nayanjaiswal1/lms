package courses

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("courses: not found")
var ErrForbidden = errors.New("courses: forbidden")
var ErrConflict = errors.New("courses: conflict")

// ValidationError is returned by Service methods that are reachable directly
// from an MCP tool call — with no HTTP handler in front of them to pre-check
// input — when a caller-supplied field would otherwise fail a DB CHECK
// constraint. Handler-level pre-checks (e.g. CreateCourse's inline title/
// difficulty validation) exist for immediate UI feedback; this is the
// boundary-of-last-resort so a bad field from an AI client surfaces as a
// clean 422 with a field name instead of a raw wrapped Postgres error
// mapped to a generic 500 by writeDomainError's default case.
type ValidationError struct {
	Field   string
	Message string
}

func (e ValidationError) Error() string { return e.Message }

// courseRatingJoin aggregates course_reviews per course; joined wherever a
// query needs avg_rating/review_count alongside the courses row (aliased c).
const courseRatingJoin = `
			 LEFT JOIN (
			   SELECT subject_id AS course_id, AVG(rating) AS avg_rating, COUNT(*) AS review_count
			   FROM feedback WHERE subject_type='course' AND kind='rating' GROUP BY subject_id
			 ) cr ON cr.course_id = c.id`

type Repo struct {
	pool *pgxpool.Pool
}

// Pool exposes the underlying connection pool for callers that need to build
// middleware over the same database (RequireOrgRole resolves the caller's live
// org role). Kept read-only by convention: use the Repo's own methods for
// queries that belong to this domain.
func (r *Repo) Pool() *pgxpool.Pool { return r.pool }

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
// atomically inside a single transaction. Kind defaults to KindOrg when the
// caller (the instructor-authoring handler) leaves it unset, since that path
// predates the self/org split and never populates it.
func (r *Repo) CreateCourse(ctx context.Context, c Course) (Course, error) {
	if c.Kind == "" {
		c.Kind = KindOrg
	}
	err := r.tx(ctx, func(tx pgx.Tx) error {
		err := tx.QueryRow(ctx,
			`INSERT INTO courses (org_id, creator_id, title, slug, description, cover_url, difficulty, tags, status, price_cents, is_free, estimated_hours, starts_at, ends_at, kind, owner_id)
			 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)
			 RETURNING id, created_at, updated_at`,
			c.OrgID, c.CreatorID, c.Title, c.Slug, c.Description, c.CoverURL, c.Difficulty,
			c.Tags, c.Status, c.PriceCents, c.IsFree, c.EstimatedHours, c.StartsAt, c.EndsAt,
			c.Kind, c.OwnerID,
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
		`SELECT c.id, c.org_id, c.creator_id, c.title, c.slug, c.description, c.cover_url, c.difficulty, c.tags,
		        c.status, c.forked_from_id, c.price_cents, c.is_free, c.is_public, c.estimated_hours,
		        u.name, cr.avg_rating, COALESCE(cr.review_count, 0), c.starts_at, c.ends_at,
		        c.kind, c.owner_id, c.certificate_threshold_percent, c.created_at, c.updated_at
		 FROM courses c
		 JOIN users u ON u.id = c.creator_id`+courseRatingJoin+`
		 WHERE c.id = $1 AND c.org_id = $2`, id, orgID,
	).Scan(&c.ID, &c.OrgID, &c.CreatorID, &c.Title, &c.Slug, &c.Description, &c.CoverURL,
		&c.Difficulty, &c.Tags, &c.Status, &c.ForkedFromID, &c.PriceCents, &c.IsFree, &c.IsPublic,
		&c.EstimatedHours, &c.InstructorName, &c.AvgRating, &c.ReviewCount, &c.StartsAt, &c.EndsAt,
		&c.Kind, &c.OwnerID, &c.CertificateThresholdPercent, &c.CreatedAt, &c.UpdatedAt)
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
	// Self-courses are private to their owner and never appear in the org
	// browse listing — only GetMyEnrollments (auto-enrolled at creation) or a
	// direct owner-scoped fetch surfaces them.
	where := "WHERE c.org_id = $1 AND c.kind = 'org'"
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
		        c.difficulty, c.tags, c.status, c.forked_from_id, c.price_cents, c.is_free, c.is_public,
		        c.estimated_hours, u.name, cr.avg_rating, COALESCE(cr.review_count, 0),
		        c.starts_at, c.ends_at, c.kind, c.owner_id, c.certificate_threshold_percent, c.created_at, c.updated_at
		 FROM courses c
		 JOIN users u ON u.id = c.creator_id`+courseRatingJoin+`
		 `+where+fmt.Sprintf(` ORDER BY c.created_at DESC LIMIT $%d OFFSET $%d`, n, n+1),
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
			&c.IsFree, &c.IsPublic, &c.EstimatedHours, &c.InstructorName, &c.AvgRating, &c.ReviewCount,
			&c.StartsAt, &c.EndsAt, &c.Kind, &c.OwnerID, &c.CertificateThresholdPercent, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, 0, fmt.Errorf("courses: scan: %w", err)
		}
		out = append(out, c)
	}
	return out, total, rows.Err()
}

// ListPublicCourses returns published courses whose instructors opted into
// the public marketplace. No org scope — this backs the anonymous
// landing-page catalog, so it must only ever expose opted-in rows.
func (r *Repo) ListPublicCourses(ctx context.Context, limit, offset int) ([]Course, int, error) {
	if limit <= 0 || limit > 50 {
		limit = 12
	}
	if offset < 0 {
		offset = 0
	}
	// kind = 'org' is redundant with is_public today (self-courses have no
	// path to set is_public), but kept explicit — this is the anonymous
	// landing-page catalog, the one place a leak would be worst.
	const where = `WHERE c.status = 'published' AND c.is_public AND c.kind = 'org'`

	var total int
	if err := r.pool.QueryRow(ctx, `SELECT count(*) FROM courses c `+where).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("courses: public count: %w", err)
	}

	rows, err := r.pool.Query(ctx,
		`SELECT c.id, c.org_id, c.creator_id, c.title, c.slug, c.description, c.cover_url,
		        c.difficulty, c.tags, c.status, c.forked_from_id, c.price_cents, c.is_free,
		        c.is_public, c.estimated_hours, u.name, cr.avg_rating, COALESCE(cr.review_count, 0),
		        c.starts_at, c.ends_at, c.kind, c.owner_id, c.certificate_threshold_percent, c.created_at, c.updated_at
		 FROM courses c
		 JOIN users u ON u.id = c.creator_id`+courseRatingJoin+`
		 `+where+` ORDER BY COALESCE(cr.review_count, 0) DESC, c.created_at DESC LIMIT $1 OFFSET $2`,
		limit, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("courses: public list: %w", err)
	}
	defer rows.Close()

	out := []Course{}
	for rows.Next() {
		var c Course
		if err := rows.Scan(&c.ID, &c.OrgID, &c.CreatorID, &c.Title, &c.Slug, &c.Description,
			&c.CoverURL, &c.Difficulty, &c.Tags, &c.Status, &c.ForkedFromID, &c.PriceCents,
			&c.IsFree, &c.IsPublic, &c.EstimatedHours, &c.InstructorName, &c.AvgRating, &c.ReviewCount,
			&c.StartsAt, &c.EndsAt, &c.Kind, &c.OwnerID, &c.CertificateThresholdPercent, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, 0, fmt.Errorf("courses: public scan: %w", err)
		}
		out = append(out, c)
	}
	return out, total, rows.Err()
}

// UpdateCourse updates mutable course metadata.
func (r *Repo) UpdateCourse(ctx context.Context, orgID string, c Course) (Course, error) {
	err := r.pool.QueryRow(ctx,
		`UPDATE courses SET title=$3, description=$4, cover_url=$5, difficulty=$6, tags=$7,
		        estimated_hours=$8, price_cents=$9, is_free=$10, is_public=$11, starts_at=$12, ends_at=$13, updated_at=now()
		 WHERE id=$1 AND org_id=$2
		 RETURNING updated_at`,
		c.ID, orgID, c.Title, c.Description, c.CoverURL, c.Difficulty, c.Tags,
		c.EstimatedHours, c.PriceCents, c.IsFree, c.IsPublic, c.StartsAt, c.EndsAt,
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

// GetCourseBySlug returns a single course by slug with org scope — mirrors
// GetCourse, letting a caller that only has a URL slug (the course detail
// page) resolve it directly in SQL instead of fetching the whole catalog to
// find the one matching row.
func (r *Repo) GetCourseBySlug(ctx context.Context, orgID, slug string) (Course, error) {
	var c Course
	err := r.pool.QueryRow(ctx,
		`SELECT c.id, c.org_id, c.creator_id, c.title, c.slug, c.description, c.cover_url, c.difficulty, c.tags,
		        c.status, c.forked_from_id, c.price_cents, c.is_free, c.is_public, c.estimated_hours,
		        u.name, cr.avg_rating, COALESCE(cr.review_count, 0), c.starts_at, c.ends_at,
		        c.kind, c.owner_id, c.certificate_threshold_percent, c.created_at, c.updated_at
		 FROM courses c
		 JOIN users u ON u.id = c.creator_id`+courseRatingJoin+`
		 WHERE c.slug = $1 AND c.org_id = $2`, slug, orgID,
	).Scan(&c.ID, &c.OrgID, &c.CreatorID, &c.Title, &c.Slug, &c.Description, &c.CoverURL,
		&c.Difficulty, &c.Tags, &c.Status, &c.ForkedFromID, &c.PriceCents, &c.IsFree, &c.IsPublic,
		&c.EstimatedHours, &c.InstructorName, &c.AvgRating, &c.ReviewCount, &c.StartsAt, &c.EndsAt,
		&c.Kind, &c.OwnerID, &c.CertificateThresholdPercent, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Course{}, ErrNotFound
		}
		return Course{}, fmt.Errorf("courses: get by slug: %w", err)
	}
	return c, nil
}

// GetCourseTree loads a course with all its sections and modules in a single
// query. userID gates visibility: a kind='self' course is only ever visible
// to its own owner — anyone else gets ErrNotFound (never ErrForbidden, so a
// guessed ID doesn't confirm the course's existence, same rationale as
// internal/roadmap's ownership check).
func (r *Repo) GetCourseTree(ctx context.Context, orgID, userID, courseID string) (CourseTree, error) {
	c, err := r.GetCourse(ctx, orgID, courseID)
	if err != nil {
		return CourseTree{}, err
	}
	if c.Kind == KindSelf && (c.OwnerID == nil || *c.OwnerID != userID) {
		return CourseTree{}, ErrNotFound
	}
	return r.buildCourseTree(ctx, c)
}

// GetCourseTreeBySlug is GetCourseTree's slug-keyed counterpart, used by the
// course detail page's slug-resolution endpoint — same visibility rule,
// different lookup key.
func (r *Repo) GetCourseTreeBySlug(ctx context.Context, orgID, userID, slug string) (CourseTree, error) {
	c, err := r.GetCourseBySlug(ctx, orgID, slug)
	if err != nil {
		return CourseTree{}, err
	}
	if c.Kind == KindSelf && (c.OwnerID == nil || *c.OwnerID != userID) {
		return CourseTree{}, ErrNotFound
	}
	return r.buildCourseTree(ctx, c)
}

// buildCourseTree loads c's sections and modules — the shared body of
// GetCourseTree and GetCourseTreeBySlug, which differ only in how c itself
// was resolved (by id vs. by slug).
func (r *Repo) buildCourseTree(ctx context.Context, c Course) (CourseTree, error) {
	sectionRows, err := r.pool.Query(ctx,
		`SELECT id, course_id, title, position, created_at FROM course_sections
		 WHERE course_id = $1 ORDER BY position`, c.ID)
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
		        starts_at, ends_at, created_at, updated_at
		 FROM course_modules WHERE course_id = $1 AND deleted_at IS NULL ORDER BY section_id, position`, c.ID)
	if err != nil {
		return CourseTree{}, fmt.Errorf("courses: get modules: %w", err)
	}
	defer modRows.Close()

	modsBySectionID := map[string][]CourseModule{}
	for modRows.Next() {
		var m CourseModule
		if err := modRows.Scan(&m.ID, &m.CourseID, &m.SectionID, &m.Title, &m.Type, &m.Position,
			&m.IsFreePreview, &m.StorageKey, &m.DurationSeconds, &m.ContentBody,
			&m.AssessmentID, &m.EstimatedMinutes, &m.StartsAt, &m.EndsAt, &m.CreatedAt, &m.UpdatedAt); err != nil {
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

// queryRower is satisfied by both *pgxpool.Pool and pgx.Tx — lets a helper
// run either standalone or inside an in-flight transaction without a second
// copy of the query.
type queryRower interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// firstSectionID returns the lowest-position section id for a course — used
// to default an omitted/unset section_id on a self-course module write, or a
// proposal approval, without loading the whole tree just to read one field.
func firstSectionID(ctx context.Context, q queryRower, courseID string) (string, error) {
	var id string
	err := q.QueryRow(ctx,
		`SELECT id FROM course_sections WHERE course_id=$1 ORDER BY position LIMIT 1`, courseID,
	).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", ErrNotFound
		}
		return "", fmt.Errorf("courses: get first section: %w", err)
	}
	return id, nil
}

// GetFirstSectionID is firstSectionID run outside any transaction.
func (r *Repo) GetFirstSectionID(ctx context.Context, courseID string) (string, error) {
	return firstSectionID(ctx, r.pool, courseID)
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
		  storage_key, duration_seconds, content_body, assessment_id, estimated_minutes, starts_at, ends_at)
		 VALUES ($1,$2,$3,$4,
		   COALESCE((SELECT MAX(position)+1 FROM course_modules WHERE section_id=$2 AND deleted_at IS NULL),0),
		   $5,$6,$7,$8,$9,$10,$11,$12)
		 RETURNING id, position, created_at, updated_at`,
		m.CourseID, m.SectionID, m.Title, m.Type, m.IsFreePreview,
		m.StorageKey, m.DurationSeconds, m.ContentBody, m.AssessmentID, m.EstimatedMinutes,
		m.StartsAt, m.EndsAt,
	).Scan(&m.ID, &m.Position, &m.CreatedAt, &m.UpdatedAt)
	if err != nil {
		return CourseModule{}, fmt.Errorf("courses: create module: %w", err)
	}
	return m, nil
}

// GetModule returns a single module; respects org scope via course FK.
func (r *Repo) GetModule(ctx context.Context, orgID, moduleID string) (CourseModule, error) {
	var m CourseModule
	var knowledgeCheckRaw []byte
	err := r.pool.QueryRow(ctx,
		`SELECT cm.id, cm.course_id, cm.section_id, cm.title, cm.type, cm.position,
		        cm.is_free_preview, cm.storage_key, cm.duration_seconds, cm.content_body,
		        cm.assessment_id, cm.estimated_minutes, cm.knowledge_check, cm.starts_at, cm.ends_at, cm.created_at, cm.updated_at
		 FROM course_modules cm
		 JOIN courses c ON c.id = cm.course_id
		 WHERE cm.id=$1 AND c.org_id=$2 AND cm.deleted_at IS NULL`, moduleID, orgID,
	).Scan(&m.ID, &m.CourseID, &m.SectionID, &m.Title, &m.Type, &m.Position,
		&m.IsFreePreview, &m.StorageKey, &m.DurationSeconds, &m.ContentBody,
		&m.AssessmentID, &m.EstimatedMinutes, &knowledgeCheckRaw, &m.StartsAt, &m.EndsAt, &m.CreatedAt, &m.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return CourseModule{}, ErrNotFound
		}
		return CourseModule{}, fmt.Errorf("courses: get module: %w", err)
	}
	if err := json.Unmarshal(knowledgeCheckRaw, &m.KnowledgeCheck); err != nil {
		return CourseModule{}, fmt.Errorf("courses: get module: decode knowledge_check: %w", err)
	}
	return m, nil
}

// GetModuleByAssessmentID returns the course module that embeds the given
// assessment, if any. Standalone assessments not attached to a course module
// return ErrNotFound — callers treat that as "nothing to auto-complete".
func (r *Repo) GetModuleByAssessmentID(ctx context.Context, orgID, assessmentID string) (CourseModule, error) {
	var m CourseModule
	err := r.pool.QueryRow(ctx,
		`SELECT cm.id, cm.course_id, cm.section_id, cm.title, cm.type, cm.position,
		        cm.is_free_preview, cm.storage_key, cm.duration_seconds, cm.content_body,
		        cm.assessment_id, cm.estimated_minutes, cm.starts_at, cm.ends_at, cm.created_at, cm.updated_at
		 FROM course_modules cm
		 JOIN courses c ON c.id = cm.course_id
		 WHERE cm.assessment_id=$1 AND c.org_id=$2 AND cm.deleted_at IS NULL`, assessmentID, orgID,
	).Scan(&m.ID, &m.CourseID, &m.SectionID, &m.Title, &m.Type, &m.Position,
		&m.IsFreePreview, &m.StorageKey, &m.DurationSeconds, &m.ContentBody,
		&m.AssessmentID, &m.EstimatedMinutes, &m.StartsAt, &m.EndsAt, &m.CreatedAt, &m.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return CourseModule{}, ErrNotFound
		}
		return CourseModule{}, fmt.Errorf("courses: get module by assessment: %w", err)
	}
	return m, nil
}

// UpdateModule updates mutable module fields.
func (r *Repo) UpdateModule(ctx context.Context, orgID string, m CourseModule) (CourseModule, error) {
	err := r.pool.QueryRow(ctx,
		`UPDATE course_modules cm SET title=$3, type=$4, is_free_preview=$5, storage_key=$6,
		        duration_seconds=$7, content_body=$8, assessment_id=$9, estimated_minutes=$10,
		        starts_at=$11, ends_at=$12, updated_at=now()
		 FROM courses c WHERE cm.id=$1 AND cm.course_id=c.id AND c.org_id=$2 AND cm.deleted_at IS NULL
		 RETURNING cm.updated_at`,
		m.ID, orgID, m.Title, m.Type, m.IsFreePreview, m.StorageKey, m.DurationSeconds,
		m.ContentBody, m.AssessmentID, m.EstimatedMinutes, m.StartsAt, m.EndsAt,
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

// RestoreModule clears deleted_at — the undo half of SoftDeleteModule, used
// by the MCP delete_self_course_module tool's Revert.
func (r *Repo) RestoreModule(ctx context.Context, orgID, moduleID string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE course_modules cm SET deleted_at=NULL
		 FROM courses c WHERE cm.id=$1 AND cm.course_id=c.id AND c.org_id=$2 AND cm.deleted_at IS NOT NULL`,
		moduleID, orgID)
	if err != nil {
		return fmt.Errorf("courses: restore module: %w", err)
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

// CreateEnrollmentTx is the tx-aware counterpart of CreateEnrollment, used by
// mentoring.Service.PurchaseCourse so the paid-course enrollment insert
// stays identical to the free-course one (same ON CONFLICT DO NOTHING logic)
// instead of being duplicated in another package.
func (r *Repo) CreateEnrollmentTx(ctx context.Context, tx pgx.Tx, e Enrollment) (Enrollment, error) {
	err := tx.QueryRow(ctx,
		`INSERT INTO enrollments (user_id, course_id, batch_id, enrolled_by)
		 VALUES ($1,$2,$3,$4)
		 ON CONFLICT (user_id, course_id) DO NOTHING
		 RETURNING id, enrolled_at`,
		e.UserID, e.CourseID, e.BatchID, e.EnrolledBy,
	).Scan(&e.ID, &e.EnrolledAt)
	if err != nil {
		return Enrollment{}, fmt.Errorf("courses: create enrollment (tx): %w", err)
	}
	return e, nil
}

// RevokeEnrollmentTx removes a course enrollment within tx — the mirror of
// CreateEnrollmentTx, used by mentoring.Service.Refund so a refunded
// purchase also revokes the access it granted. A no-op if the student was
// never enrolled (e.g. the enrollment was already removed by an admin).
func (r *Repo) RevokeEnrollmentTx(ctx context.Context, tx pgx.Tx, userID, courseID string) error {
	if _, err := tx.Exec(ctx,
		`DELETE FROM enrollments WHERE user_id = $1 AND course_id = $2`,
		userID, courseID,
	); err != nil {
		return fmt.Errorf("courses: revoke enrollment (tx): %w", err)
	}
	return nil
}

// IsEnrolled checks if a user is enrolled in a course.
func (r *Repo) IsEnrolled(ctx context.Context, userID, courseID string) (bool, error) {
	var ok bool
	err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM enrollments WHERE user_id=$1 AND course_id=$2)`, userID, courseID,
	).Scan(&ok)
	return ok, err
}

// UpsertReview creates or updates the student's star rating for a course.
func (r *Repo) UpsertReview(ctx context.Context, rev CourseReview) (CourseReview, error) {
	// ponytail: org_id not available in CourseReview; fetch from courses to populate feedback.org_id
	var orgID string
	if err := r.pool.QueryRow(ctx, `SELECT org_id FROM courses WHERE id=$1`, rev.CourseID).Scan(&orgID); err != nil {
		return CourseReview{}, fmt.Errorf("courses: upsert review: get org: %w", err)
	}
	err := r.pool.QueryRow(ctx,
		`INSERT INTO feedback (org_id, subject_type, subject_id, user_id, rating, kind)
		 VALUES ($1,'course',$2,$3,$4,'rating')
		 ON CONFLICT (subject_type, subject_id, user_id) DO UPDATE
		   SET rating = EXCLUDED.rating, updated_at = now()
		 RETURNING id, created_at, updated_at`,
		orgID, rev.CourseID, rev.UserID, rev.Rating,
	).Scan(&rev.ID, &rev.CreatedAt, &rev.UpdatedAt)
	if err != nil {
		return CourseReview{}, fmt.Errorf("courses: upsert review: %w", err)
	}
	return rev, nil
}

// GetMyReview returns the authenticated user's existing rating for a course, if any.
func (r *Repo) GetMyReview(ctx context.Context, userID, courseID string) (CourseReview, error) {
	var rev CourseReview
	err := r.pool.QueryRow(ctx,
		`SELECT id, subject_id, user_id, rating, created_at, updated_at
		 FROM feedback WHERE user_id = $1 AND subject_id = $2 AND subject_type='course' AND kind='rating'`, userID, courseID,
	).Scan(&rev.ID, &rev.CourseID, &rev.UserID, &rev.Rating, &rev.CreatedAt, &rev.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return CourseReview{}, ErrNotFound
		}
		return CourseReview{}, fmt.Errorf("courses: get my review: %w", err)
	}
	return rev, nil
}

// UpsertReflection creates or updates the student's free-text reflection for
// a lesson module. One row per (user, module) — resubmitting replaces the
// previous answer rather than accumulating a history, same rationale as
// UpsertReview: only the current state matters to readers.
func (r *Repo) UpsertReflection(ctx context.Context, ref LessonReflection) (LessonReflection, error) {
	if ref.Source == "" {
		ref.Source = "manual"
	}
	err := r.pool.QueryRow(ctx,
		`WITH deleted AS (
		   DELETE FROM learning_annotations
		   WHERE user_id=$2 AND source_type='module' AND source_id=$3 AND annotation_type='reflection'
		   RETURNING id
		 )
		 INSERT INTO learning_annotations (org_id, user_id, source_type, source_id, annotation_type, text, meta)
		 VALUES ($1,$2,'module',$3,'reflection',$4,jsonb_build_object('source', $5))
		 RETURNING id, created_at, created_at`,
		ref.OrgID, ref.UserID, ref.ModuleID, ref.Response, ref.Source,
	).Scan(&ref.ID, &ref.CreatedAt, &ref.UpdatedAt)
	if err != nil {
		return LessonReflection{}, fmt.Errorf("courses: upsert reflection: %w", err)
	}
	return ref, nil
}

// GetMyReflection returns the authenticated user's existing reflection for a
// module, if any — used to prefill the textarea so revisiting a lesson shows
// what was already submitted instead of a blank box.
func (r *Repo) GetMyReflection(ctx context.Context, userID, moduleID string) (LessonReflection, error) {
	var ref LessonReflection
	var metaRaw []byte
	err := r.pool.QueryRow(ctx,
		`SELECT id, source_id, text, meta, created_at, created_at
		 FROM learning_annotations WHERE user_id = $1 AND source_id = $2 AND source_type='module' AND annotation_type='reflection'`, userID, moduleID,
	).Scan(&ref.ID, &ref.ModuleID, &ref.Response, &metaRaw, &ref.CreatedAt, &ref.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return LessonReflection{}, ErrNotFound
		}
		return LessonReflection{}, fmt.Errorf("courses: get my reflection: %w", err)
	}
	var meta map[string]interface{}
	if err := json.Unmarshal(metaRaw, &meta); err == nil {
		if src, ok := meta["source"].(string); ok {
			ref.Source = src
		}
	}
	return ref, nil
}

// UpsertLessonNote creates or updates the student's personal note overlay for
// a lesson module. One row per (user, module) — saving replaces the previous
// note, same rationale as UpsertReflection.
func (r *Repo) UpsertLessonNote(ctx context.Context, note LessonNote) (LessonNote, error) {
	if note.Source == "" {
		note.Source = "manual"
	}
	err := r.pool.QueryRow(ctx,
		`WITH deleted AS (
		   DELETE FROM learning_annotations
		   WHERE user_id=$2 AND source_type='module' AND source_id=$3 AND annotation_type='note'
		   RETURNING id
		 )
		 INSERT INTO learning_annotations (org_id, user_id, source_type, source_id, annotation_type, text, meta)
		 VALUES ($1,$2,'module',$3,'note',$4,jsonb_build_object('source', $5))
		 RETURNING id, created_at, created_at`,
		note.OrgID, note.UserID, note.ModuleID, note.Content, note.Source,
	).Scan(&note.ID, &note.CreatedAt, &note.UpdatedAt)
	if err != nil {
		return LessonNote{}, fmt.Errorf("courses: upsert lesson note: %w", err)
	}
	return note, nil
}

// GetMyLessonNote returns the authenticated user's existing note for a
// module, if any — used to prefill the notes panel.
func (r *Repo) GetMyLessonNote(ctx context.Context, userID, moduleID string) (LessonNote, error) {
	var note LessonNote
	var metaRaw []byte
	err := r.pool.QueryRow(ctx,
		`SELECT id, source_id, text, meta, created_at, created_at
		 FROM learning_annotations WHERE user_id = $1 AND source_id = $2 AND source_type='module' AND annotation_type='note'`, userID, moduleID,
	).Scan(&note.ID, &note.ModuleID, &note.Content, &metaRaw, &note.CreatedAt, &note.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return LessonNote{}, ErrNotFound
		}
		return LessonNote{}, fmt.Errorf("courses: get my lesson note: %w", err)
	}
	var meta map[string]interface{}
	if err := json.Unmarshal(metaRaw, &meta); err == nil {
		if src, ok := meta["source"].(string); ok {
			note.Source = src
		}
	}
	return note, nil
}

// DeleteReflection removes the student's reflection for a module, if any —
// used to revert an MCP log_understanding call that created one where none
// existed before.
func (r *Repo) DeleteReflection(ctx context.Context, orgID, userID, moduleID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM learning_annotations WHERE org_id=$1 AND user_id=$2 AND source_id=$3 AND source_type='module' AND annotation_type='reflection'`,
		orgID, userID, moduleID)
	if err != nil {
		return fmt.Errorf("courses: delete reflection: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// DeleteLessonNote removes the student's note for a module, if any — used to
// revert an MCP save_my_lesson_note call that created one where none existed
// before.
func (r *Repo) DeleteLessonNote(ctx context.Context, orgID, userID, moduleID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM learning_annotations WHERE org_id=$1 AND user_id=$2 AND source_id=$3 AND source_type='module' AND annotation_type='note'`,
		orgID, userID, moduleID)
	if err != nil {
		return fmt.Errorf("courses: delete lesson note: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// DeleteOwnedSelfCourse permanently removes a self-course the caller owns —
// used to revert an MCP create_self_course call. Unlike ArchiveCourse (a
// soft status flip with no kind/ownership check, meant for an instructor
// retiring a real org course), this is a hard delete scoped to kind='self'
// and the given ownerID, so it can never touch an org course or another
// student's private course. course_modules/course_sections both cascade on
// courses.id, so this also removes everything the student added under it.
func (r *Repo) DeleteOwnedSelfCourse(ctx context.Context, orgID, ownerID, courseID string) error {
	tag, err := r.pool.Exec(ctx,
		`DELETE FROM courses WHERE id=$1 AND org_id=$2 AND kind='self' AND owner_id=$3`,
		courseID, orgID, ownerID)
	if err != nil {
		return fmt.Errorf("courses: delete owned self course: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// GetMyEnrollments returns all courses a student is enrolled in within an
// org, with course data and per-course progress joined in a single query
// (via a LATERAL subquery over course_modules/module_progress) — callers
// that need progress alongside enrollments (e.g. the dashboard) get it in
// one round trip instead of one GetCourseProgress call per enrollment.
func (r *Repo) GetMyEnrollments(ctx context.Context, userID, orgID string) ([]Enrollment, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT e.id, e.user_id, e.course_id, e.batch_id, e.enrolled_by, e.enrolled_at, e.completed_at,
		        c.id, c.org_id, c.creator_id, c.title, c.slug, c.description, c.cover_url,
		        c.difficulty, c.tags, c.status, c.forked_from_id, c.price_cents, c.is_free, c.is_public,
		        c.estimated_hours, u.name, cr.avg_rating, COALESCE(cr.review_count, 0),
		        c.kind, c.owner_id, c.certificate_threshold_percent, c.created_at, c.updated_at,
		        COALESCE(mp.completed, 0), COALESCE(mp.total, 0), COALESCE(mp.pct, 0), mp.last_activity_at
		 FROM enrollments e
		 JOIN courses c ON c.id = e.course_id
		 JOIN users u ON u.id = c.creator_id`+courseRatingJoin+`
		 LEFT JOIN LATERAL (
		   SELECT
		     COUNT(*) FILTER (WHERE cmp.status = 'completed') AS completed,
		     COUNT(*) AS total,
		     ROUND(100.0 * COUNT(*) FILTER (WHERE cmp.status = 'completed') / NULLIF(COUNT(*), 0), 1) AS pct,
		     MAX(cmp.updated_at) AS last_activity_at
		   FROM course_modules cm
		   LEFT JOIN module_progress cmp ON cmp.module_id = cm.id AND cmp.user_id = e.user_id
		   WHERE cm.course_id = c.id AND cm.deleted_at IS NULL
		 ) mp ON true
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
			&e.Course.Status, &e.Course.ForkedFromID, &e.Course.PriceCents, &e.Course.IsFree, &e.Course.IsPublic,
			&e.Course.EstimatedHours, &e.Course.InstructorName, &e.Course.AvgRating, &e.Course.ReviewCount,
			&e.Course.Kind, &e.Course.OwnerID, &e.Course.CertificateThresholdPercent, &e.Course.CreatedAt, &e.Course.UpdatedAt,
			&e.Progress.Completed, &e.Progress.Total, &e.Progress.Pct, &e.Progress.LastActivityAt,
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

// UpsertProgressCompleted marks a module completed and reports whether it was
// already completed beforehand (same pre-statement snapshot as the write, so
// concurrent-request races can't both see "not completed"). The caller uses
// wasAlreadyCompleted to skip re-awarding one-time completion XP when a
// student unmarks and remarks a module complete.
func (r *Repo) UpsertProgressCompleted(ctx context.Context, p ModuleProgress) (updated ModuleProgress, wasAlreadyCompleted bool, err error) {
	err = r.pool.QueryRow(ctx,
		`WITH previous AS (
		   SELECT status FROM module_progress WHERE user_id = $1 AND module_id = $2
		 )
		 INSERT INTO module_progress (user_id, module_id, course_id, status, last_position_seconds, completed_at)
		 VALUES ($1,$2,$3,$4,$5,$6)
		 ON CONFLICT (user_id, module_id) DO UPDATE
		   SET status=EXCLUDED.status, last_position_seconds=EXCLUDED.last_position_seconds,
		       completed_at=EXCLUDED.completed_at, updated_at=now()
		 RETURNING id, updated_at, COALESCE((SELECT status FROM previous), '') = $4`,
		p.UserID, p.ModuleID, p.CourseID, p.Status, p.LastPositionSeconds, p.CompletedAt,
	).Scan(&p.ID, &p.UpdatedAt, &wasAlreadyCompleted)
	if err != nil {
		return ModuleProgress{}, false, fmt.Errorf("courses: upsert progress completed: %w", err)
	}
	return p, wasAlreadyCompleted, nil
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

// InsertCheckAttempt records one lesson knowledge-check attempt (correct or
// wrong) — the append-only history the product wants for future
// analytics/spaced-repetition weighting, and the source UpdateProgress checks
// before allowing a gated notes module to be marked complete.
func (r *Repo) InsertCheckAttempt(ctx context.Context, a LessonCheckAttempt) (LessonCheckAttempt, error) {
	err := r.tx(ctx, func(tx pgx.Tx) error {
		// Get the knowledge-check assessment for this module
		var assessmentID string
		err := tx.QueryRow(ctx,
			`SELECT id FROM assessments WHERE parent_type='module' AND parent_id=$1 AND type='knowledge_check'`,
			a.ModuleID,
		).Scan(&assessmentID)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				// No assessment for this module; create a simplified entry anyway (legacy compatibility)
				// ponytail: module has no knowledge_check assessment; skipping attempt record
				a.ID = "00000000-0000-0000-0000-000000000000"
				a.CreatedAt = time.Now()
				return nil
			}
			return fmt.Errorf("courses: insert check attempt: get assessment: %w", err)
		}

		// Get or create assessment_attempts row for this user+assessment
		var attemptID string
		err = tx.QueryRow(ctx,
			`INSERT INTO assessment_attempts (assessment_id, user_id, org_id, status, started_at)
			 VALUES ($1,$2,$3,'in_progress',now())
			 ON CONFLICT (assessment_id, user_id) DO UPDATE SET updated_at=now() RETURNING id`,
			assessmentID, a.UserID, a.OrgID,
		).Scan(&attemptID)
		if err != nil {
			return fmt.Errorf("courses: insert check attempt: upsert attempt: %w", err)
		}

		// Find the assessment_question that matches this question_id (stored in question_versions.content->>'id')
		var assessmentQuestionID, questionID string
		err = tx.QueryRow(ctx,
			`SELECT aq.id, aq.question_id
			 FROM assessment_questions aq
			 JOIN question_versions qv ON qv.id = aq.version_id
			 WHERE aq.assessment_id=$1 AND qv.content->>'id'=$2`,
			assessmentID, a.QuestionID,
		).Scan(&assessmentQuestionID, &questionID)
		if err != nil {
			return fmt.Errorf("courses: insert check attempt: find question: %w", err)
		}

		// Insert attempt_answer
		err = tx.QueryRow(ctx,
			`INSERT INTO attempt_answers (attempt_id, assessment_question_id, question_id, answer, is_correct, evaluated_at)
			 VALUES ($1,$2,$3,$4,$5,now())
			 RETURNING id`,
			attemptID, assessmentQuestionID, questionID, a.Answer, a.IsCorrect,
		).Scan(&a.ID)
		if err != nil {
			return fmt.Errorf("courses: insert check attempt: insert answer: %w", err)
		}
		a.CreatedAt = time.Now()
		return nil
	})
	if err != nil {
		return LessonCheckAttempt{}, err
	}
	return a, nil
}

// GetPassedQuestionIDs returns the distinct knowledge-check question IDs the
// user has ever answered correctly for the given module.
func (r *Repo) GetPassedQuestionIDs(ctx context.Context, userID, moduleID string) ([]string, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT DISTINCT qv.content->>'id'
		 FROM attempt_answers aa
		 JOIN assessment_attempts aat ON aat.id = aa.attempt_id
		 JOIN assessments a ON a.id = aat.assessment_id
		 LEFT JOIN question_versions qv ON qv.question_id = aa.question_id
		 WHERE a.parent_type='module' AND a.parent_id=$1 AND aat.user_id=$2 AND aa.is_correct`,
		moduleID, userID,
	)
	if err != nil {
		return nil, fmt.Errorf("courses: get passed question ids: %w", err)
	}
	defer rows.Close()

	ids := []string{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("courses: get passed question ids: %w", err)
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// GetModuleProgressForCourse returns the per-module progress rows for a user
// in a course, so callers can look up completion status by module_id.
func (r *Repo) GetModuleProgressForCourse(ctx context.Context, userID, courseID string) ([]ModuleProgress, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT mp.id, mp.user_id, mp.module_id, mp.course_id, mp.status,
		        mp.last_position_seconds, mp.completed_at, mp.updated_at
		 FROM module_progress mp
		 JOIN course_modules cm ON cm.id = mp.module_id
		 WHERE mp.user_id=$1 AND mp.course_id=$2 AND cm.deleted_at IS NULL`,
		userID, courseID,
	)
	if err != nil {
		return nil, fmt.Errorf("courses: get module progress: %w", err)
	}
	defer rows.Close()

	out := []ModuleProgress{}
	for rows.Next() {
		var p ModuleProgress
		if err := rows.Scan(&p.ID, &p.UserID, &p.ModuleID, &p.CourseID, &p.Status,
			&p.LastPositionSeconds, &p.CompletedAt, &p.UpdatedAt); err != nil {
			return nil, fmt.Errorf("courses: scan module progress: %w", err)
		}
		out = append(out, p)
	}
	return out, rows.Err()
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
			 RETURNING id, org_id, creator_id, title, slug, description, difficulty, tags, status, forked_from_id, price_cents, is_free, kind, owner_id, created_at, updated_at`,
			orgID, creatorID, newTitle, newSlug, originalID,
		).Scan(&newCourse.ID, &newCourse.OrgID, &newCourse.CreatorID, &newCourse.Title, &newCourse.Slug,
			&newCourse.Description, &newCourse.Difficulty, &newCourse.Tags, &newCourse.Status,
			&newCourse.ForkedFromID, &newCourse.PriceCents, &newCourse.IsFree,
			&newCourse.Kind, &newCourse.OwnerID, &newCourse.CreatedAt, &newCourse.UpdatedAt)
		if err != nil {
			return fmt.Errorf("courses: fork course: %w", err)
		}
		return copySectionsAndModules(ctx, tx, originalID, newCourse.ID)
	})
	if err != nil {
		return Course{}, err
	}
	return newCourse, nil
}

// copySectionsAndModules copies every section and (non-deleted) module from
// fromCourseID into toCourseID, preserving position order — the shared body
// of ForkCourse and ForkToSelfCourse, which differ only in how the
// destination course row itself is created (instructor-owned org copy vs.
// student-owned private copy).
func copySectionsAndModules(ctx context.Context, tx pgx.Tx, fromCourseID, toCourseID string) error {
	origSecs, err := tx.Query(ctx, `SELECT id FROM course_sections WHERE course_id=$1 ORDER BY position`, fromCourseID)
	if err != nil {
		return fmt.Errorf("courses: copy sections: fetch orig: %w", err)
	}
	defer origSecs.Close()
	var origSecIDs []string
	for origSecs.Next() {
		var id string
		if err := origSecs.Scan(&id); err != nil {
			return fmt.Errorf("courses: copy sections: scan orig: %w", err)
		}
		origSecIDs = append(origSecIDs, id)
	}
	if err := origSecs.Err(); err != nil {
		return fmt.Errorf("courses: copy sections: orig rows: %w", err)
	}

	secRows, err := tx.Query(ctx,
		`INSERT INTO course_sections (course_id, title, position)
		 SELECT $1, title, position FROM course_sections WHERE course_id=$2 ORDER BY position
		 RETURNING id`,
		toCourseID, fromCourseID)
	if err != nil {
		return fmt.Errorf("courses: copy sections: insert: %w", err)
	}
	defer secRows.Close()
	var newSecIDs []string
	for secRows.Next() {
		var id string
		if err := secRows.Scan(&id); err != nil {
			return fmt.Errorf("courses: copy sections: scan new: %w", err)
		}
		newSecIDs = append(newSecIDs, id)
	}
	if err := secRows.Err(); err != nil {
		return fmt.Errorf("courses: copy sections: new rows: %w", err)
	}

	for i, origSecID := range origSecIDs {
		if i >= len(newSecIDs) {
			break
		}
		if _, err := tx.Exec(ctx,
			`INSERT INTO course_modules (course_id, section_id, title, type, position, is_free_preview, storage_key, duration_seconds, content_body, assessment_id, estimated_minutes)
			 SELECT $1,$2,title,type,position,is_free_preview,storage_key,duration_seconds,content_body,assessment_id,estimated_minutes
			 FROM course_modules WHERE section_id=$3 AND deleted_at IS NULL ORDER BY position`,
			toCourseID, newSecIDs[i], origSecID); err != nil {
			return fmt.Errorf("courses: copy modules for section %s: %w", origSecID, err)
		}
	}
	return nil
}

// ─── Self-courses ─────────────────────────────────────────────────────────────

// CreateSelfCourse creates a student's own private course from scratch —
// kind='self', owned by ownerID, published immediately (there is no audience
// to gate a draft from), with a default "Introduction" section and the owner
// auto-enrolled in the same transaction — so every existing
// enrollment/progress/module code path treats it like any other course with
// no self-course special-casing required there.
func (r *Repo) CreateSelfCourse(ctx context.Context, orgID, ownerID, title string, description *string, difficulty string, tags []string) (Course, error) {
	if difficulty == "" {
		difficulty = DifficultyBeginner
	}
	if tags == nil {
		tags = []string{}
	}
	c := Course{
		OrgID: orgID, CreatorID: ownerID, Title: title, Slug: Slugify(title),
		Description: description, Difficulty: difficulty, Tags: tags,
		Status: StatusPublished, IsFree: true, Kind: KindSelf, OwnerID: &ownerID,
	}
	err := r.tx(ctx, func(tx pgx.Tx) error {
		err := tx.QueryRow(ctx,
			`INSERT INTO courses (org_id, creator_id, title, slug, description, difficulty, tags, status, is_free, kind, owner_id)
			 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
			 RETURNING id, created_at, updated_at`,
			c.OrgID, c.CreatorID, c.Title, c.Slug, c.Description, c.Difficulty, c.Tags, c.Status, c.IsFree, c.Kind, c.OwnerID,
		).Scan(&c.ID, &c.CreatedAt, &c.UpdatedAt)
		if err != nil {
			return fmt.Errorf("courses: create self course: %w", err)
		}
		if _, err := tx.Exec(ctx,
			`INSERT INTO course_sections (course_id, title, position) VALUES ($1, 'Introduction', 0)`, c.ID,
		); err != nil {
			return fmt.Errorf("courses: create self course default section: %w", err)
		}
		if _, err := tx.Exec(ctx,
			`INSERT INTO enrollments (user_id, course_id, enrolled_by) VALUES ($1,$2,$1)
			 ON CONFLICT (user_id, course_id) DO NOTHING`, ownerID, c.ID,
		); err != nil {
			return fmt.Errorf("courses: create self course auto-enroll: %w", err)
		}
		return nil
	})
	if err != nil {
		return Course{}, err
	}
	return c, nil
}

// selfContentMatchThreshold mirrors internal/roadmap/matcher.go's
// matchThreshold — the minimum pg_trgm similarity score trusted before
// treating two titles as "the same thing." Below it, nothing is returned
// rather than guessing: a false match would misdirect new content into the
// wrong course/module, which is worse than a duplicate.
const selfContentMatchThreshold = 0.3

// FindSimilarSelfCourse returns the closest-titled self-course ownerID
// already has, if any title clears selfContentMatchThreshold. Used by the
// create_self_course MCP tool (only — the human-driven "Create course" web
// form calls CreateSelfCourse directly and always means a new course) so a
// connected AI that misunderstood and re-requested a course the student
// already has resumes it instead of spinning up a duplicate.
func (r *Repo) FindSimilarSelfCourse(ctx context.Context, orgID, ownerID, title string) (Course, bool, error) {
	var id string
	err := r.pool.QueryRow(ctx,
		`SELECT id FROM courses
		 WHERE org_id=$1 AND kind='self' AND owner_id=$2
		   AND similarity(title, $3) > $4
		 ORDER BY similarity(title, $3) DESC LIMIT 1`,
		orgID, ownerID, title, selfContentMatchThreshold,
	).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Course{}, false, nil
		}
		return Course{}, false, fmt.Errorf("courses: find similar self course: %w", err)
	}
	c, err := r.GetCourse(ctx, orgID, id)
	if err != nil {
		return Course{}, false, err
	}
	return c, true, nil
}

// FindSimilarModuleInCourse looks for a module already in courseID whose
// title closely matches title — a repeated "new lesson" about the same
// sub-topic should merge into the existing module instead of forking into a
// sibling duplicate within the same course.
func (r *Repo) FindSimilarModuleInCourse(ctx context.Context, orgID, courseID, title string) (CourseModule, bool, error) {
	var id string
	err := r.pool.QueryRow(ctx,
		`SELECT cm.id FROM course_modules cm
		 JOIN courses c ON c.id = cm.course_id
		 WHERE cm.course_id=$1 AND c.org_id=$2 AND cm.deleted_at IS NULL
		   AND similarity(cm.title, $3) > $4
		 ORDER BY similarity(cm.title, $3) DESC LIMIT 1`,
		courseID, orgID, title, selfContentMatchThreshold,
	).Scan(&id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return CourseModule{}, false, nil
		}
		return CourseModule{}, false, fmt.Errorf("courses: find similar module in course: %w", err)
	}
	m, err := r.GetModule(ctx, orgID, id)
	if err != nil {
		return CourseModule{}, false, err
	}
	return m, true, nil
}

// FindSimilarModuleElsewhere searches every OTHER self-course ownerID has
// (excluding excludeCourseID) for a module whose title closely matches
// title. Read-only signal, never auto-merged: cross-course content overlap
// is surfaced to the caller so a connected AI can point the student at what
// they already covered elsewhere, but only a same-course match
// (FindSimilarModuleInCourse) is trusted enough to merge into automatically
// — merging across courses risks folding content into the wrong context.
func (r *Repo) FindSimilarModuleElsewhere(ctx context.Context, orgID, ownerID, excludeCourseID, title string) (SimilarModuleElsewhere, bool, error) {
	var m SimilarModuleElsewhere
	err := r.pool.QueryRow(ctx,
		`SELECT cm.id, cm.title, c.id, c.title
		 FROM course_modules cm
		 JOIN courses c ON c.id = cm.course_id
		 WHERE c.org_id=$1 AND c.kind='self' AND c.owner_id=$2 AND c.id != $3
		   AND cm.deleted_at IS NULL
		   AND similarity(cm.title, $4) > $5
		 ORDER BY similarity(cm.title, $4) DESC LIMIT 1`,
		orgID, ownerID, excludeCourseID, title, selfContentMatchThreshold,
	).Scan(&m.ModuleID, &m.ModuleTitle, &m.CourseID, &m.CourseTitle)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return SimilarModuleElsewhere{}, false, nil
		}
		return SimilarModuleElsewhere{}, false, fmt.Errorf("courses: find similar module elsewhere: %w", err)
	}
	return m, true, nil
}

// ForkToSelfCourse copies a published org course's sections and modules into
// a brand-new private course owned by the forking student — same shape as
// ForkCourse, but the result is kind='self' (never listed in the org
// catalog) and the owner is auto-enrolled in the same transaction. Only a
// published kind='org' course can be forked this way: forking another
// student's private self-course, or an instructor's still-drafting course,
// is refused with ErrForbidden.
func (r *Repo) ForkToSelfCourse(ctx context.Context, orgID, originalID, ownerID, newTitle string) (Course, error) {
	var newCourse Course
	err := r.tx(ctx, func(tx pgx.Tx) error {
		var origKind, origStatus string
		if err := tx.QueryRow(ctx,
			`SELECT kind, status FROM courses WHERE id=$1 AND org_id=$2`, originalID, orgID,
		).Scan(&origKind, &origStatus); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return ErrNotFound
			}
			return fmt.Errorf("courses: fork to self: lookup original: %w", err)
		}
		if origKind != KindOrg || origStatus != StatusPublished {
			return ErrForbidden
		}

		newSlug := Slugify(newTitle)
		err := tx.QueryRow(ctx,
			`INSERT INTO courses (org_id, creator_id, title, slug, description, difficulty, tags, forked_from_id, price_cents, is_free, status, kind, owner_id)
			 SELECT $1,$2,$3,$4,description,difficulty,tags,$5,0,true,'published','self',$2
			 FROM courses WHERE id=$5 AND org_id=$1
			 RETURNING id, org_id, creator_id, title, slug, description, difficulty, tags, status, forked_from_id, price_cents, is_free, kind, owner_id, created_at, updated_at`,
			orgID, ownerID, newTitle, newSlug, originalID,
		).Scan(&newCourse.ID, &newCourse.OrgID, &newCourse.CreatorID, &newCourse.Title, &newCourse.Slug,
			&newCourse.Description, &newCourse.Difficulty, &newCourse.Tags, &newCourse.Status,
			&newCourse.ForkedFromID, &newCourse.PriceCents, &newCourse.IsFree,
			&newCourse.Kind, &newCourse.OwnerID, &newCourse.CreatedAt, &newCourse.UpdatedAt)
		if err != nil {
			return fmt.Errorf("courses: fork to self: insert: %w", err)
		}
		if err := copySectionsAndModules(ctx, tx, originalID, newCourse.ID); err != nil {
			return err
		}

		if _, err := tx.Exec(ctx,
			`INSERT INTO enrollments (user_id, course_id, enrolled_by) VALUES ($1,$2,$1)
			 ON CONFLICT (user_id, course_id) DO NOTHING`, ownerID, newCourse.ID,
		); err != nil {
			return fmt.Errorf("courses: fork to self: auto-enroll: %w", err)
		}
		return nil
	})
	if err != nil {
		return Course{}, err
	}
	return newCourse, nil
}

// GetRecentReflections returns a user's most recently updated
// lesson_reflections across every course, newest first, with the
// lesson/course title already joined in — the "what have I recently
// understood or struggled with" feed behind get_learning_context.
func (r *Repo) GetRecentReflections(ctx context.Context, orgID, userID string, limit int) ([]ReflectionSummary, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT c.title, cm.title, cm.id, la.text, la.meta, la.created_at
		 FROM learning_annotations la
		 JOIN course_modules cm ON cm.id = la.source_id
		 JOIN courses c ON c.id = cm.course_id
		 WHERE la.user_id = $1 AND la.org_id = $2 AND la.source_type='module' AND la.annotation_type='reflection'
		 ORDER BY la.created_at DESC LIMIT $3`, userID, orgID, limit)
	if err != nil {
		return nil, fmt.Errorf("courses: get recent reflections: %w", err)
	}
	defer rows.Close()
	out := []ReflectionSummary{}
	for rows.Next() {
		var s ReflectionSummary
		var metaRaw []byte
		if err := rows.Scan(&s.CourseTitle, &s.ModuleTitle, &s.ModuleID, &s.Response, &metaRaw, &s.UpdatedAt); err != nil {
			return nil, fmt.Errorf("courses: scan recent reflection: %w", err)
		}
		var meta map[string]interface{}
		if err := json.Unmarshal(metaRaw, &meta); err == nil {
			if src, ok := meta["source"].(string); ok {
				s.Source = src
			}
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// GetRecentSelfCourseModules returns the most recently updated modules
// across every self-course ownerID owns — the "what have I been building
// lately" feed behind get_learning_context.
func (r *Repo) GetRecentSelfCourseModules(ctx context.Context, orgID, ownerID string, limit int) ([]SelfModuleSummary, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT c.id, c.title, cm.id, cm.title, cm.updated_at
		 FROM course_modules cm
		 JOIN courses c ON c.id = cm.course_id
		 WHERE c.kind = 'self' AND c.owner_id = $1 AND c.org_id = $2 AND cm.deleted_at IS NULL
		 ORDER BY cm.updated_at DESC LIMIT $3`, ownerID, orgID, limit)
	if err != nil {
		return nil, fmt.Errorf("courses: get recent self-course modules: %w", err)
	}
	defer rows.Close()
	out := []SelfModuleSummary{}
	for rows.Next() {
		var s SelfModuleSummary
		if err := rows.Scan(&s.CourseID, &s.CourseTitle, &s.ModuleID, &s.ModuleTitle, &s.UpdatedAt); err != nil {
			return nil, fmt.Errorf("courses: scan recent self-course module: %w", err)
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// GetOwnedSelfCourse returns courseID only if it is a kind='self' course
// owned by ownerID — the single authorization check every self-course write
// path (in-app, or via the owner's connected MCP client) must pass before
// touching its sections/modules.
func (r *Repo) GetOwnedSelfCourse(ctx context.Context, orgID, ownerID, courseID string) (Course, error) {
	c, err := r.GetCourse(ctx, orgID, courseID)
	if err != nil {
		return Course{}, err
	}
	if c.Kind != KindSelf || c.OwnerID == nil || *c.OwnerID != ownerID {
		return Course{}, ErrForbidden
	}
	return c, nil
}

// ─── Content proposals (self-course → org-course contribution audit) ─────────

// changeRequestProposalPayload is the requested_change jsonb shape stored on
// change_requests rows with kind='course_content_proposal' — this table
// replaced the dedicated course_content_proposals table in migration 025.
type changeRequestProposalPayload struct {
	SourceCourseID  *string `json:"source_course_id,omitempty"`
	SourceModuleID  *string `json:"source_module_id,omitempty"`
	TargetSectionID *string `json:"target_section_id,omitempty"`
	Title           string  `json:"title"`
	Type            string  `json:"type"`
	Body            string  `json:"body"`
}

// CreateProposal inserts a pending contribution from a student's self-course
// module into a shared org course. It never touches course_modules itself —
// only ApproveProposal does that, after an instructor/admin reviews it.
func (r *Repo) CreateProposal(ctx context.Context, p CourseContentProposal) (CourseContentProposal, error) {
	payload, err := json.Marshal(changeRequestProposalPayload{
		SourceCourseID:  p.SourceCourseID,
		SourceModuleID:  p.SourceModuleID,
		TargetSectionID: p.TargetSectionID,
		Title:           p.Title,
		Type:            p.Type,
		Body:            p.ContentBody,
	})
	if err != nil {
		return CourseContentProposal{}, fmt.Errorf("courses: create proposal: marshal payload: %w", err)
	}
	err = r.pool.QueryRow(ctx,
		`INSERT INTO change_requests (org_id, kind, requester_id, subject_type, subject_id, requested_change)
		 VALUES ($1,'course_content_proposal',$2,'course',$3,$4)
		 RETURNING id, status, created_at`,
		p.OrgID, p.ProposerID, p.TargetCourseID, payload,
	).Scan(&p.ID, &p.Status, &p.CreatedAt)
	if err != nil {
		return CourseContentProposal{}, fmt.Errorf("courses: create proposal: %w", err)
	}
	p.UpdatedAt = p.CreatedAt
	return p, nil
}

const proposalColumns = `p.id, p.requester_id, p.subject_id, p.requested_change, p.status, p.review_note,
		        p.reviewed_by, p.reviewed_at, p.result_id, p.created_at`

// scanProposal decodes a change_requests row (kind='course_content_proposal')
// into a CourseContentProposal, unpacking the requested_change jsonb payload.
func scanProposal(row pgx.Row, p *CourseContentProposal) error {
	var payloadRaw []byte
	if err := row.Scan(&p.ID, &p.ProposerID, &p.TargetCourseID, &payloadRaw, &p.Status, &p.ReviewNote,
		&p.ReviewedBy, &p.ReviewedAt, &p.CreatedModuleID, &p.CreatedAt); err != nil {
		return err
	}
	var payload changeRequestProposalPayload
	if err := json.Unmarshal(payloadRaw, &payload); err != nil {
		return fmt.Errorf("unmarshal requested_change: %w", err)
	}
	p.SourceCourseID = payload.SourceCourseID
	p.SourceModuleID = payload.SourceModuleID
	p.TargetSectionID = payload.TargetSectionID
	p.Title = payload.Title
	p.Type = payload.Type
	p.ContentBody = payload.Body
	if p.ReviewedAt != nil {
		p.UpdatedAt = *p.ReviewedAt
	} else {
		p.UpdatedAt = p.CreatedAt
	}
	return nil
}

// ListProposalsForCourse returns proposals targeting courseID, newest first —
// the instructor/admin review queue. status filters to one status when set,
// otherwise returns every proposal regardless of status.
func (r *Repo) ListProposalsForCourse(ctx context.Context, orgID, courseID, status string) ([]CourseContentProposal, error) {
	args := []any{orgID, "course_content_proposal", courseID}
	where := "WHERE p.org_id=$1 AND p.kind=$2 AND p.subject_type='course' AND p.subject_id=$3"
	if status != "" {
		args = append(args, status)
		where += fmt.Sprintf(" AND p.status=$%d", len(args))
	}
	// ponytail: hard cap, no pagination params on this endpoint yet — add offset/limit query params if a course ever needs more than 100 pending proposals.
	rows, err := r.pool.Query(ctx, `SELECT `+proposalColumns+` FROM change_requests p `+where+` ORDER BY p.created_at DESC LIMIT 100`, args...)
	if err != nil {
		return nil, fmt.Errorf("courses: list proposals: %w", err)
	}
	defer rows.Close()
	out := []CourseContentProposal{}
	for rows.Next() {
		var p CourseContentProposal
		if err := scanProposal(rows, &p); err != nil {
			return nil, fmt.Errorf("courses: scan proposal: %w", err)
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// GetProposalForOrg returns a single proposal scoped to orgID.
func (r *Repo) GetProposalForOrg(ctx context.Context, orgID, proposalID string) (CourseContentProposal, error) {
	var p CourseContentProposal
	err := scanProposal(r.pool.QueryRow(ctx,
		`SELECT `+proposalColumns+` FROM change_requests p WHERE p.id=$1 AND p.org_id=$2 AND p.kind='course_content_proposal'`, proposalID, orgID,
	), &p)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return CourseContentProposal{}, ErrNotFound
		}
		return CourseContentProposal{}, fmt.Errorf("courses: get proposal: %w", err)
	}
	return p, nil
}

// ApproveProposal transactionally re-checks the proposal is still pending
// (FOR UPDATE, so two simultaneous approvals can't both create a module),
// inserts a real course_modules row from its snapshot (into target_section_id
// if set, else the target course's first section by position), and marks the
// proposal approved with the resulting module id — all in one transaction so
// a proposal can never end up "approved" without a module to show for it.
func (r *Repo) ApproveProposal(ctx context.Context, orgID, proposalID, reviewerID string, reviewNote *string) (CourseContentProposal, error) {
	var out CourseContentProposal
	err := r.tx(ctx, func(tx pgx.Tx) error {
		var p CourseContentProposal
		var payloadRaw []byte
		err := tx.QueryRow(ctx,
			`SELECT id, subject_id, requested_change, status
			 FROM change_requests WHERE id=$1 AND org_id=$2 AND kind='course_content_proposal' FOR UPDATE`, proposalID, orgID,
		).Scan(&p.ID, &p.TargetCourseID, &payloadRaw, &p.Status)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return ErrNotFound
			}
			return fmt.Errorf("courses: approve proposal: lookup: %w", err)
		}
		var payload changeRequestProposalPayload
		if err := json.Unmarshal(payloadRaw, &payload); err != nil {
			return fmt.Errorf("courses: approve proposal: unmarshal requested_change: %w", err)
		}
		p.TargetSectionID, p.Title, p.Type, p.ContentBody = payload.TargetSectionID, payload.Title, payload.Type, payload.Body
		if p.Status != ProposalStatusPending {
			return ErrConflict
		}

		sectionID := p.TargetSectionID
		if sectionID == nil {
			id, err := firstSectionID(ctx, tx, p.TargetCourseID)
			if err != nil {
				return fmt.Errorf("courses: approve proposal: find target section: %w", err)
			}
			sectionID = &id
		}

		var moduleID string
		if err := tx.QueryRow(ctx,
			`INSERT INTO course_modules (course_id, section_id, title, type, position, content_body)
			 VALUES ($1,$2,$3,$4, COALESCE((SELECT MAX(position)+1 FROM course_modules WHERE section_id=$2 AND deleted_at IS NULL),0), $5)
			 RETURNING id`,
			p.TargetCourseID, *sectionID, p.Title, p.Type, p.ContentBody,
		).Scan(&moduleID); err != nil {
			return fmt.Errorf("courses: approve proposal: create module: %w", err)
		}

		if err := scanProposal(tx.QueryRow(ctx,
			`UPDATE change_requests p
			 SET status='approved', reviewed_by=$2, reviewed_at=now(), review_note=$3, result_id=$4
			 WHERE p.id=$1
			 RETURNING `+proposalColumns,
			proposalID, reviewerID, reviewNote, moduleID,
		), &out); err != nil {
			return fmt.Errorf("courses: approve proposal: update: %w", err)
		}
		return nil
	})
	if err != nil {
		return CourseContentProposal{}, err
	}
	return out, nil
}

// RejectProposal marks a pending proposal rejected without creating a
// module. Returns ErrConflict if the proposal has already been reviewed.
func (r *Repo) RejectProposal(ctx context.Context, orgID, proposalID, reviewerID string, reviewNote *string) (CourseContentProposal, error) {
	var out CourseContentProposal
	err := r.tx(ctx, func(tx pgx.Tx) error {
		var status string
		if err := tx.QueryRow(ctx,
			`SELECT status FROM change_requests WHERE id=$1 AND org_id=$2 AND kind='course_content_proposal' FOR UPDATE`, proposalID, orgID,
		).Scan(&status); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return ErrNotFound
			}
			return fmt.Errorf("courses: reject proposal: lookup: %w", err)
		}
		if status != ProposalStatusPending {
			return ErrConflict
		}
		return scanProposal(tx.QueryRow(ctx,
			`UPDATE change_requests p
			 SET status='rejected', reviewed_by=$2, reviewed_at=now(), review_note=$3
			 WHERE p.id=$1
			 RETURNING `+proposalColumns,
			proposalID, reviewerID, reviewNote,
		), &out)
	})
	if err != nil {
		return CourseContentProposal{}, err
	}
	return out, nil
}

// ─── Random topic discovery ───────────────────────────────────────────────────

// RandomTopicFilter narrows the candidate pool GetRandomPublishedCourse picks
// from. A zero-value filter means "no filter" for that dimension.
type RandomTopicFilter struct {
	// Tags, when non-empty, requires case-insensitive overlap with the
	// course's own tags. Course tags are freeform instructor-typed text while
	// Tags here comes from the fixed topics_interest vocabulary, so this
	// can't be a plain `&&` array-overlap (misses on casing, loses the
	// courses_tags_gin index either way) — matched via unnest+lower instead.
	Tags []string
	// ExcludeCourseIDs, when non-empty, excludes those courses from the pool
	// — used to keep a "surprise me" pick from resurfacing something the
	// student is already enrolled in.
	ExcludeCourseIDs []string
}

// GetRandomPublishedCourse picks one published, org-kind, free course at
// random from orgID's own catalog (the same visibility rule ListCourses
// uses), narrowed by filter. Paid courses are excluded — "surprise me" must
// never route an unpurchased course into a checkout flow. Returns
// ErrNotFound when the filtered pool is empty — callers decide whether/how
// to widen the filter and retry.
func (r *Repo) GetRandomPublishedCourse(ctx context.Context, orgID string, filter RandomTopicFilter) (Course, error) {
	args := []any{orgID}
	where := "WHERE c.org_id = $1 AND c.kind = 'org' AND c.status = 'published' AND c.is_free = true"
	n := 2
	if len(filter.Tags) > 0 {
		lowered := make([]string, len(filter.Tags))
		for i, t := range filter.Tags {
			lowered[i] = strings.ToLower(t)
		}
		where += fmt.Sprintf(" AND EXISTS (SELECT 1 FROM unnest(c.tags) AS ct WHERE lower(ct) = ANY($%d::text[]))", n)
		args = append(args, lowered)
		n++
	}
	if len(filter.ExcludeCourseIDs) > 0 {
		where += fmt.Sprintf(" AND NOT (c.id = ANY($%d::uuid[]))", n)
		args = append(args, filter.ExcludeCourseIDs)
		n++
	}

	var c Course
	err := r.pool.QueryRow(ctx,
		`SELECT c.id, c.org_id, c.creator_id, c.title, c.slug, c.description, c.cover_url, c.difficulty, c.tags,
		        c.status, c.forked_from_id, c.price_cents, c.is_free, c.is_public, c.estimated_hours,
		        u.name, cr.avg_rating, COALESCE(cr.review_count, 0), c.starts_at, c.ends_at,
		        c.kind, c.owner_id, c.certificate_threshold_percent, c.created_at, c.updated_at
		 FROM courses c
		 JOIN users u ON u.id = c.creator_id`+courseRatingJoin+`
		 `+where+`
		 ORDER BY random() LIMIT 1`,
		args...,
	).Scan(&c.ID, &c.OrgID, &c.CreatorID, &c.Title, &c.Slug, &c.Description, &c.CoverURL,
		&c.Difficulty, &c.Tags, &c.Status, &c.ForkedFromID, &c.PriceCents, &c.IsFree, &c.IsPublic,
		&c.EstimatedHours, &c.InstructorName, &c.AvgRating, &c.ReviewCount, &c.StartsAt, &c.EndsAt,
		&c.Kind, &c.OwnerID, &c.CertificateThresholdPercent, &c.CreatedAt, &c.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Course{}, ErrNotFound
		}
		return Course{}, fmt.Errorf("courses: get random published course: %w", err)
	}
	return c, nil
}

// GetTopicsInterest returns the student's stated topic interests from
// onboarding (user_profiles.topics_interest) — empty if they never set any or
// have no profile row at all, never an error for that case, since "no stated
// interest" is a normal, common state, not a failure.
func (r *Repo) GetTopicsInterest(ctx context.Context, userID string) ([]string, error) {
	var tags []string
	err := r.pool.QueryRow(ctx,
		`SELECT topics_interest FROM user_profiles WHERE user_id = $1`, userID,
	).Scan(&tags)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return []string{}, nil
		}
		return nil, fmt.Errorf("courses: get topics interest: %w", err)
	}
	return tags, nil
}
