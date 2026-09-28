package courses

import (
	"context"
	"errors"
	"fmt"
	"math"

	"github.com/jackc/pgx/v5"
	"github.com/mindforge/backend/internal/db"
)

const (
	BundleStatusDraft     = "draft"
	BundleStatusPublished = "published"
)

// bundleColumns selects a Bundle row (aliased b) with its course count.
const bundleColumns = `b.id, b.org_id, b.creator_id, b.title, b.slug, b.description, b.cover_url, b.status,
	(SELECT COUNT(*) FROM course_bundle_items bi WHERE bi.bundle_id = b.id), b.created_at, b.updated_at`

func scanBundle(row pgx.Row) (Bundle, error) {
	var b Bundle
	err := row.Scan(&b.ID, &b.OrgID, &b.CreatorID, &b.Title, &b.Slug, &b.Description, &b.CoverURL,
		&b.Status, &b.CourseCount, &b.CreatedAt, &b.UpdatedAt)
	return b, err
}

// CreateBundle inserts a new bundle. A slug collision (Slugify's random
// suffix makes this near-impossible) surfaces as ErrConflict.
func (r *Repo) CreateBundle(ctx context.Context, b Bundle) (Bundle, error) {
	err := r.pool.QueryRow(ctx,
		`INSERT INTO course_bundles (org_id, creator_id, title, slug, description, cover_url, status)
		 VALUES ($1,$2,$3,$4,$5,$6,$7)
		 RETURNING id, created_at, updated_at`,
		b.OrgID, b.CreatorID, b.Title, b.Slug, b.Description, b.CoverURL, b.Status,
	).Scan(&b.ID, &b.CreatedAt, &b.UpdatedAt)
	if err != nil {
		if db.IsUniqueViolation(err) {
			return Bundle{}, ErrConflict
		}
		return Bundle{}, fmt.Errorf("courses: create bundle: %w", err)
	}
	return b, nil
}

// UpdateBundle replaces a bundle's editable metadata.
func (r *Repo) UpdateBundle(ctx context.Context, orgID string, b Bundle) (Bundle, error) {
	updated, err := scanBundle(r.pool.QueryRow(ctx,
		`WITH u AS (
		   UPDATE course_bundles SET title=$3, description=$4, cover_url=$5, status=$6, updated_at=now()
		   WHERE id=$1 AND org_id=$2
		   RETURNING *
		 )
		 SELECT `+bundleColumns+` FROM u b`,
		b.ID, orgID, b.Title, b.Description, b.CoverURL, b.Status))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Bundle{}, ErrNotFound
		}
		return Bundle{}, fmt.Errorf("courses: update bundle: %w", err)
	}
	return updated, nil
}

// DeleteBundle hard-deletes a bundle. It owns no student data (enrollments
// live on the courses), so nothing is lost beyond the grouping itself.
func (r *Repo) DeleteBundle(ctx context.Context, orgID, bundleID string) error {
	tag, err := r.pool.Exec(ctx, `DELETE FROM course_bundles WHERE id=$1 AND org_id=$2`, bundleID, orgID)
	if err != nil {
		return fmt.Errorf("courses: delete bundle: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ListBundles returns an org's bundles, newest first. publishedOnly is the
// student browse listing; the instructor management listing passes false.
func (r *Repo) ListBundles(ctx context.Context, orgID string, publishedOnly bool) ([]Bundle, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT `+bundleColumns+` FROM course_bundles b
		 WHERE b.org_id = $1 AND (NOT $2 OR b.status = 'published')
		 ORDER BY b.created_at DESC`, orgID, publishedOnly)
	if err != nil {
		return nil, fmt.Errorf("courses: list bundles: %w", err)
	}
	defer rows.Close()
	out := []Bundle{}
	for rows.Next() {
		b, err := scanBundle(rows)
		if err != nil {
			return nil, fmt.Errorf("courses: scan bundle: %w", err)
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

// GetBundleDetail loads a bundle (by id or slug, whichever key is set) with
// its ordered courses and userID's enrollment/progress in each. Student
// callers pass publishedOnly=true: a draft bundle is then ErrNotFound and
// unpublished courses inside a published bundle are hidden.
func (r *Repo) GetBundleDetail(ctx context.Context, orgID, userID, bundleID, slug string, publishedOnly bool) (BundleDetail, error) {
	b, err := scanBundle(r.pool.QueryRow(ctx,
		`SELECT `+bundleColumns+` FROM course_bundles b
		 WHERE b.org_id = $1 AND (b.id::text = $2 OR b.slug = $3) AND (NOT $4 OR b.status = 'published')`,
		orgID, bundleID, slug, publishedOnly))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return BundleDetail{}, ErrNotFound
		}
		return BundleDetail{}, fmt.Errorf("courses: get bundle: %w", err)
	}

	rows, err := r.pool.Query(ctx,
		`SELECT c.id, c.slug, c.title, c.description, c.cover_url, c.difficulty, c.status, c.is_free,
		        c.price_cents, c.estimated_hours, bi.position, e.id IS NOT NULL,
		        COALESCE(mp.completed, 0), COALESCE(mp.total, 0), COALESCE(mp.pct, 0)
		 FROM course_bundle_items bi
		 JOIN courses c ON c.id = bi.course_id
		 LEFT JOIN enrollments e ON e.course_id = c.id AND e.user_id = $2
		 LEFT JOIN LATERAL (
		   SELECT
		     COUNT(*) FILTER (WHERE cmp.status = 'completed') AS completed,
		     COUNT(*) AS total,
		     ROUND(100.0 * COUNT(*) FILTER (WHERE cmp.status = 'completed') / NULLIF(COUNT(*), 0), 1) AS pct
		   FROM course_modules cm
		   LEFT JOIN module_progress cmp ON cmp.module_id = cm.id AND cmp.user_id = $2
		   WHERE cm.course_id = c.id AND cm.deleted_at IS NULL
		 ) mp ON true
		 WHERE bi.bundle_id = $1 AND (NOT $3 OR c.status = 'published')
		 ORDER BY bi.position`, b.ID, userID, publishedOnly)
	if err != nil {
		return BundleDetail{}, fmt.Errorf("courses: bundle courses: %w", err)
	}
	defer rows.Close()
	d := BundleDetail{Bundle: b, Courses: []BundleCourse{}}
	for rows.Next() {
		var bc BundleCourse
		if err := rows.Scan(&bc.ID, &bc.Slug, &bc.Title, &bc.Description, &bc.CoverURL, &bc.Difficulty,
			&bc.Status, &bc.IsFree, &bc.PriceCents, &bc.EstimatedHours, &bc.Position, &bc.IsEnrolled,
			&bc.Progress.Completed, &bc.Progress.Total, &bc.Progress.Pct); err != nil {
			return BundleDetail{}, fmt.Errorf("courses: scan bundle course: %w", err)
		}
		d.Courses = append(d.Courses, bc)
		d.Progress.Completed += bc.Progress.Completed
		d.Progress.Total += bc.Progress.Total
	}
	if err := rows.Err(); err != nil {
		return BundleDetail{}, fmt.Errorf("courses: bundle courses: %w", err)
	}
	d.Progress.Pct = bundlePct(d.Progress.Completed, d.Progress.Total)
	d.CourseCount = len(d.Courses)
	return d, nil
}

// bundlePct rounds to one decimal, matching the per-course SQL ROUND(…, 1).
func bundlePct(completed, total int) float64 {
	if total == 0 {
		return 0
	}
	return math.Round(1000*float64(completed)/float64(total)) / 10
}

// SetBundleCourses replaces a bundle's course list with courseIDs in that
// order — one call covers add, remove and reorder. Every course must belong
// to the bundle's org; duplicates are rejected by the caller.
func (r *Repo) SetBundleCourses(ctx context.Context, orgID, bundleID string, courseIDs []string) error {
	return r.tx(ctx, func(tx pgx.Tx) error {
		// Row lock serializes concurrent replacements of the same bundle's list.
		var locked string
		if err := tx.QueryRow(ctx,
			`SELECT id FROM course_bundles WHERE id=$1 AND org_id=$2 FOR UPDATE`,
			bundleID, orgID).Scan(&locked); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return ErrNotFound
			}
			return fmt.Errorf("courses: lock bundle: %w", err)
		}
		var inOrg int
		if err := tx.QueryRow(ctx,
			`SELECT COUNT(*) FROM courses WHERE id = ANY($1::uuid[]) AND org_id = $2`,
			courseIDs, orgID).Scan(&inOrg); err != nil {
			return fmt.Errorf("courses: check bundle courses: %w", err)
		}
		if inOrg != len(courseIDs) {
			return ValidationError{Field: "course_ids", Message: "Every course must exist in this organization."}
		}
		if _, err := tx.Exec(ctx, `DELETE FROM course_bundle_items WHERE bundle_id=$1`, bundleID); err != nil {
			return fmt.Errorf("courses: clear bundle courses: %w", err)
		}
		if _, err := tx.Exec(ctx,
			`INSERT INTO course_bundle_items (bundle_id, course_id, position)
			 SELECT $1, u.id, u.ord - 1 FROM unnest($2::uuid[]) WITH ORDINALITY AS u(id, ord)`,
			bundleID, courseIDs); err != nil {
			return fmt.Errorf("courses: insert bundle courses: %w", err)
		}
		if _, err := tx.Exec(ctx, `UPDATE course_bundles SET updated_at=now() WHERE id=$1`, bundleID); err != nil {
			return fmt.Errorf("courses: touch bundle: %w", err)
		}
		return nil
	})
}

// EnrollInBundle enrolls userID in every published free course of a
// published bundle in one statement (existing enrollments are left alone),
// and reports the paid courses the student still has to buy one by one.
func (r *Repo) EnrollInBundle(ctx context.Context, orgID, userID, bundleID string) (BundleEnrollResult, error) {
	res := BundleEnrollResult{EnrolledCourseIDs: []string{}, RequiresPurchaseCourseIDs: []string{}}
	err := r.tx(ctx, func(tx pgx.Tx) error {
		var exists bool
		if err := tx.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM course_bundles WHERE id=$1 AND org_id=$2 AND status='published')`,
			bundleID, orgID).Scan(&exists); err != nil {
			return fmt.Errorf("courses: check bundle: %w", err)
		}
		if !exists {
			return ErrNotFound
		}
		rows, err := tx.Query(ctx,
			`INSERT INTO enrollments (user_id, course_id, enrolled_by)
			 SELECT $2, c.id, $2
			 FROM course_bundle_items bi JOIN courses c ON c.id = bi.course_id
			 WHERE bi.bundle_id = $1 AND c.status = 'published' AND c.is_free
			 ON CONFLICT (user_id, course_id) DO NOTHING
			 RETURNING course_id`, bundleID, userID)
		if err != nil {
			return fmt.Errorf("courses: bundle enroll: %w", err)
		}
		for rows.Next() {
			var id string
			if err := rows.Scan(&id); err != nil {
				rows.Close()
				return fmt.Errorf("courses: scan bundle enroll: %w", err)
			}
			res.EnrolledCourseIDs = append(res.EnrolledCourseIDs, id)
		}
		rows.Close()
		if err := rows.Err(); err != nil {
			return fmt.Errorf("courses: bundle enroll: %w", err)
		}

		paid, err := tx.Query(ctx,
			`SELECT c.id FROM course_bundle_items bi JOIN courses c ON c.id = bi.course_id
			 WHERE bi.bundle_id = $1 AND c.status = 'published' AND NOT c.is_free
			   AND NOT EXISTS (SELECT 1 FROM enrollments e WHERE e.course_id = c.id AND e.user_id = $2)
			 ORDER BY bi.position`, bundleID, userID)
		if err != nil {
			return fmt.Errorf("courses: bundle paid courses: %w", err)
		}
		defer paid.Close()
		for paid.Next() {
			var id string
			if err := paid.Scan(&id); err != nil {
				return fmt.Errorf("courses: scan bundle paid course: %w", err)
			}
			res.RequiresPurchaseCourseIDs = append(res.RequiresPurchaseCourseIDs, id)
		}
		return paid.Err()
	})
	if err != nil {
		return BundleEnrollResult{}, err
	}
	return res, nil
}

// GetBundlesForCourse returns the published bundles a course belongs to, for
// the course page's "Part of" chip.
func (r *Repo) GetBundlesForCourse(ctx context.Context, orgID, courseID string) ([]BundleRef, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT b.id, b.slug, b.title FROM course_bundle_items bi
		 JOIN course_bundles b ON b.id = bi.bundle_id
		 WHERE bi.course_id = $1 AND b.org_id = $2 AND b.status = 'published'
		 ORDER BY b.title`, courseID, orgID)
	if err != nil {
		return nil, fmt.Errorf("courses: bundles for course: %w", err)
	}
	defer rows.Close()
	out := []BundleRef{}
	for rows.Next() {
		var ref BundleRef
		if err := rows.Scan(&ref.ID, &ref.Slug, &ref.Title); err != nil {
			return nil, fmt.Errorf("courses: scan bundle ref: %w", err)
		}
		out = append(out, ref)
	}
	return out, rows.Err()
}
