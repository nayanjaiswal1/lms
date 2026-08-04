package moderation

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var (
	ErrNotFound = errors.New("moderation: not found")
	// ErrContentNotFound is returned when content_id doesn't resolve to a
	// real, non-deleted row of content_type — a report cannot be filed
	// against content that doesn't exist.
	ErrContentNotFound = errors.New("moderation: content not found")
)

type Repo struct {
	pool *pgxpool.Pool
}

func NewRepo(pool *pgxpool.Pool) *Repo {
	return &Repo{pool: pool}
}

const reportColumns = `id, org_id, reporter_id, content_type, content_id, reason, description,
	status, resolved_by, resolution_note, created_at, updated_at`

type rowScanner interface {
	Scan(dest ...any) error
}

func scanReport(row rowScanner) (Report, error) {
	var rp Report
	err := row.Scan(&rp.ID, &rp.OrgID, &rp.ReporterID, &rp.ContentType, &rp.ContentID, &rp.Reason,
		&rp.Description, &rp.Status, &rp.ResolvedBy, &rp.ResolutionNote, &rp.CreatedAt, &rp.UpdatedAt)
	return rp, err
}

// contentOrgQueries resolves the tenant a piece of content belongs to, and
// doubles as the existence check — a deleted or nonexistent row returns no
// org, which the caller treats as "content not found". Each query also
// requires the row not already be soft-deleted.
var contentOrgQueries = map[string]string{
	ContentWikiPage: `SELECT ws.org_id FROM wiki_pages wp
	                    JOIN wiki_spaces ws ON ws.id = wp.space_id
	                   WHERE wp.id = $1 AND wp.deleted_at IS NULL`,
	ContentCourseModule: `SELECT c.org_id FROM course_modules cm
	                        JOIN courses c ON c.id = cm.course_id
	                       WHERE cm.id = $1 AND cm.deleted_at IS NULL`,
}

// ContentOrgID returns the org a live piece of content belongs to, or
// ErrContentNotFound if contentType/contentID doesn't resolve to one.
func (r *Repo) ContentOrgID(ctx context.Context, contentType, contentID string) (string, error) {
	query, ok := contentOrgQueries[contentType]
	if !ok {
		return "", ErrContentNotFound
	}
	var orgID string
	err := r.pool.QueryRow(ctx, query, contentID).Scan(&orgID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", ErrContentNotFound
		}
		return "", fmt.Errorf("moderation: content org lookup: %w", err)
	}
	return orgID, nil
}

// softDeleteQueries takes down the underlying content when a report is
// resolved as 'removed' — the same deleted_at column each content type
// already uses for its own delete/unpublish flow, not a new mechanism.
var softDeleteQueries = map[string]string{
	ContentWikiPage:     `UPDATE wiki_pages SET deleted_at = now() WHERE id = $1 AND deleted_at IS NULL`,
	ContentCourseModule: `UPDATE course_modules SET deleted_at = now() WHERE id = $1 AND deleted_at IS NULL`,
}

// TakeDownContent soft-deletes contentID, mirroring the content type's own
// deleted_at convention. A no-op if it's already gone.
func (r *Repo) TakeDownContent(ctx context.Context, contentType, contentID string) error {
	query, ok := softDeleteQueries[contentType]
	if !ok {
		return ErrContentNotFound
	}
	if _, err := r.pool.Exec(ctx, query, contentID); err != nil {
		return fmt.Errorf("moderation: take down content: %w", err)
	}
	return nil
}

// CreateReport files a new 'pending' report.
func (r *Repo) CreateReport(ctx context.Context, rp Report) (Report, error) {
	row := r.pool.QueryRow(ctx,
		`INSERT INTO content_reports (org_id, reporter_id, content_type, content_id, reason, description, status)
		 VALUES ($1,$2,$3,$4,$5,$6,'pending')
		 RETURNING `+reportColumns,
		rp.OrgID, rp.ReporterID, rp.ContentType, rp.ContentID, rp.Reason, rp.Description,
	)
	created, err := scanReport(row)
	if err != nil {
		return Report{}, fmt.Errorf("moderation: create report: %w", err)
	}
	return created, nil
}

// GetReport returns a single report by ID, scoped to orgID.
func (r *Repo) GetReport(ctx context.Context, orgID, reportID string) (Report, error) {
	row := r.pool.QueryRow(ctx, `SELECT `+reportColumns+` FROM content_reports WHERE id = $1 AND org_id = $2`, reportID, orgID)
	rp, err := scanReport(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Report{}, ErrNotFound
		}
		return Report{}, fmt.Errorf("moderation: get report: %w", err)
	}
	return rp, nil
}

// ListReports returns orgID's reports, most recent first, optionally
// filtered by status and/or content_type — the staff queue.
func (r *Repo) ListReports(ctx context.Context, orgID string, status, contentType *string) ([]Report, error) {
	args := []any{orgID}
	where := "WHERE org_id = $1"
	n := 2
	if status != nil && *status != "" {
		where += fmt.Sprintf(" AND status = $%d", n)
		args = append(args, *status)
		n++
	}
	if contentType != nil && *contentType != "" {
		where += fmt.Sprintf(" AND content_type = $%d", n)
		args = append(args, *contentType)
		n++
	}
	rows, err := r.pool.Query(ctx, `SELECT `+reportColumns+` FROM content_reports `+where+` ORDER BY created_at DESC`, args...)
	if err != nil {
		return nil, fmt.Errorf("moderation: list reports: %w", err)
	}
	defer rows.Close()
	out := []Report{}
	for rows.Next() {
		rp, err := scanReport(rows)
		if err != nil {
			return nil, fmt.Errorf("moderation: scan report: %w", err)
		}
		out = append(out, rp)
	}
	return out, rows.Err()
}

// Resolve transitions a report's status within orgID and records who
// resolved it and why.
func (r *Repo) Resolve(ctx context.Context, orgID, reportID, status, resolvedBy string, note *string) (Report, error) {
	row := r.pool.QueryRow(ctx,
		`UPDATE content_reports
		 SET status = $1, resolved_by = $2, resolution_note = $3, updated_at = now()
		 WHERE id = $4 AND org_id = $5
		 RETURNING `+reportColumns,
		status, resolvedBy, note, reportID, orgID)
	rp, err := scanReport(row)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Report{}, ErrNotFound
		}
		return Report{}, fmt.Errorf("moderation: resolve report: %w", err)
	}
	return rp, nil
}
