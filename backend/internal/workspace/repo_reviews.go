package workspace

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
)

// repo_reviews.go — work_item_reviews data layer (feature-spec / code review
// gate, contract-phase3.md) plus the work_items doc-gate columns it drives,
// and the tiny raw reads workspace needs from wiki_pages/wiki_spaces for the
// doc/brief views (workspace can import wiki for its exported helpers, but a
// plain scoped SELECT here avoids needing a wiki.Service instance just to
// read a title/slug/version this package already owns the FK for).

const itemReviewColumns = `r.id, r.item_id, r.reviewer_id, COALESCE(u.name, 'Former member'), r.target, r.verdict,
	r.comment, r.wiki_version, r.merge_request_id, r.created_at`

func scanItemReview(row pgx.Row) (*ItemReview, error) {
	var v ItemReview
	err := row.Scan(&v.ID, &v.ItemID, &v.ReviewerID, &v.ReviewerName, &v.Target, &v.Verdict,
		&v.Comment, &v.WikiVersion, &v.MergeRequestID, &v.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("workspace: scan item review: %w", err)
	}
	return &v, nil
}

// InsertDocReview appends one 'doc' verdict row (ReviewDoc).
func (r *Repo) InsertDocReview(ctx context.Context, tx pgx.Tx, projectID, itemID, reviewerID, verdict string, comment *string, wikiVersion int) (*ItemReview, error) {
	row := tx.QueryRow(ctx,
		`WITH ins AS (
			INSERT INTO work_item_reviews (project_id, item_id, reviewer_id, target, verdict, comment, wiki_version)
			VALUES ($1,$2,$3,'doc',$4,$5,$6)
			RETURNING id
		 )
		 SELECT `+itemReviewColumns+`
		   FROM work_item_reviews r LEFT JOIN users u ON u.id = r.reviewer_id
		  WHERE r.id = (SELECT id FROM ins)`,
		projectID, itemID, reviewerID, verdict, comment, wikiVersion,
	)
	return scanItemReview(row)
}

// ListItemReviews returns every review of one target ("doc" or "code") on an
// item, newest first.
func (r *Repo) ListItemReviews(ctx context.Context, db DBTX, itemID, target string) ([]ItemReview, error) {
	rows, err := db.Query(ctx,
		`SELECT `+itemReviewColumns+` FROM work_item_reviews r LEFT JOIN users u ON u.id = r.reviewer_id
		  WHERE r.item_id = $1 AND r.target = $2 ORDER BY r.created_at DESC`,
		itemID, target)
	if err != nil {
		return nil, fmt.Errorf("workspace: list item reviews: %w", err)
	}
	defer rows.Close()
	out := []ItemReview{}
	for rows.Next() {
		v, err := scanItemReview(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *v)
	}
	return out, rows.Err()
}

// AllCurrentReviewersApproved reports whether the item has at least one
// current reviewer assignee, and every current reviewer's latest 'doc'
// review at exactly wikiVersion is 'approved' (contract-phase3.md
// "ReviewDoc"). A reviewer removed from the item stops counting even if
// their old review said approved; a current reviewer with no review yet at
// this version fails the check.
func (r *Repo) AllCurrentReviewersApproved(ctx context.Context, tx pgx.Tx, itemID string, wikiVersion int) (bool, error) {
	var ok bool
	err := tx.QueryRow(ctx,
		`WITH current_reviewers AS (
			SELECT user_id FROM work_item_assignees WHERE item_id = $1 AND role = 'reviewer'
		 ), latest AS (
			SELECT DISTINCT ON (reviewer_id) reviewer_id, verdict
			  FROM work_item_reviews
			 WHERE item_id = $1 AND target = 'doc' AND wiki_version = $2 AND reviewer_id IS NOT NULL
			 ORDER BY reviewer_id, created_at DESC
		 )
		 SELECT EXISTS(SELECT 1 FROM current_reviewers) AND NOT EXISTS (
			SELECT 1 FROM current_reviewers cr LEFT JOIN latest l ON l.reviewer_id = cr.user_id
			 WHERE l.verdict IS DISTINCT FROM 'approved'
		 )`,
		itemID, wikiVersion,
	).Scan(&ok)
	if err != nil {
		return false, fmt.Errorf("workspace: check reviewer approvals: %w", err)
	}
	return ok, nil
}

// SetItemDocPage points a freshly created feature item at its spec page
// (CreateWorkItem, in the same tx as the insert) — doc_status starts 'draft'.
func (r *Repo) SetItemDocPage(ctx context.Context, tx pgx.Tx, projectID, itemID, pageID string) error {
	if _, err := tx.Exec(ctx,
		`UPDATE work_items SET doc_wiki_page_id = $3, doc_status = 'draft', updated_at = now()
		  WHERE id = $1 AND project_id = $2`,
		itemID, projectID, pageID,
	); err != nil {
		return fmt.Errorf("workspace: set item doc page: %w", err)
	}
	return nil
}

// SetDocStatus writes a feature's doc-gate status transition. approvedVersion
// non-nil sets approved_doc_version (an approval); clearSpecChanged nulls
// spec_changed_at (a fresh approval or re-approval resolves any prior churn
// flag). Returns the updated item so the caller can log an event/audit off
// its fields.
func (r *Repo) SetDocStatus(ctx context.Context, tx pgx.Tx, projectID, itemID, status string, approvedVersion *int, clearSpecChanged bool) (*WorkItem, error) {
	row := tx.QueryRow(ctx,
		`WITH upd AS (
			UPDATE work_items SET
				doc_status = $3,
				approved_doc_version = COALESCE($4, approved_doc_version),
				spec_changed_at = CASE WHEN $5::boolean THEN NULL ELSE spec_changed_at END,
				updated_at = now()
			 WHERE id = $1 AND project_id = $2
			RETURNING id
		 )
		 SELECT `+workItemColumns+`
		   FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.id = (SELECT id FROM upd)`,
		itemID, projectID, status, approvedVersion, clearSpecChanged,
	)
	return scanWorkItem(row)
}

// MarkChildTasksSpecChanged flags every task/subtask under a feature as
// affected by a spec change after approval (Flow F) — informational only,
// never blocks their own transitions.
func (r *Repo) MarkChildTasksSpecChanged(ctx context.Context, tx pgx.Tx, projectID, featureID string) error {
	if _, err := tx.Exec(ctx,
		`UPDATE work_items SET spec_changed_at = now(), updated_at = now()
		  WHERE project_id = $1 AND feature_id = $2 AND type IN ('task','subtask') AND archived_at IS NULL`,
		projectID, featureID,
	); err != nil {
		return fmt.Errorf("workspace: mark child tasks spec changed: %w", err)
	}
	return nil
}

// ClearChildTasksSpecChanged nulls spec_changed_at on every task/subtask
// under a feature — a fresh full approval of the spec resolves any prior
// churn flag those children were carrying (contract-phase3.md "ReviewDoc").
func (r *Repo) ClearChildTasksSpecChanged(ctx context.Context, tx pgx.Tx, projectID, featureID string) error {
	if _, err := tx.Exec(ctx,
		`UPDATE work_items SET spec_changed_at = NULL, updated_at = now()
		  WHERE project_id = $1 AND feature_id = $2 AND type IN ('task','subtask') AND archived_at IS NULL AND spec_changed_at IS NOT NULL`,
		projectID, featureID,
	); err != nil {
		return fmt.Errorf("workspace: clear child tasks spec changed: %w", err)
	}
	return nil
}

// GetFeatureByDocPage resolves a wiki page id back to the feature item that
// owns it (RequestDocChange's own lookup, called from inside wiki's UpdatePage
// tx with only a page id in hand) — 0 rows (ErrNotFound) is a normal, silent
// no-op for every wiki page that isn't a feature spec.
func (r *Repo) GetFeatureByDocPage(ctx context.Context, tx pgx.Tx, pageID string) (*WorkItem, error) {
	return scanWorkItem(tx.QueryRow(ctx,
		`SELECT `+workItemColumns+` FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.doc_wiki_page_id = $1 AND w.type = 'feature' FOR UPDATE OF w`,
		pageID))
}

// ListFeaturesWithApprovedDoc returns every non-archived feature in the
// project whose doc_status is currently 'approved' — UpdateRequirement's own
// fan-out (contract-phase3.md: a new requirement version reopens every
// already-approved feature spec for review).
func (r *Repo) ListFeaturesWithApprovedDoc(ctx context.Context, tx pgx.Tx, projectID string) ([]WorkItem, error) {
	rows, err := tx.Query(ctx,
		`SELECT `+workItemColumns+` FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.project_id = $1 AND w.type = 'feature' AND w.doc_status = 'approved' AND w.archived_at IS NULL
		  FOR UPDATE OF w`,
		projectID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list features with approved doc: %w", err)
	}
	defer rows.Close()
	out := []WorkItem{}
	for rows.Next() {
		item, err := scanWorkItem(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *item)
	}
	return out, rows.Err()
}

// GetWikiPageInfo reads a page's slug/version and its space's slug — the
// small, already-FK'd read the doc/brief views need without a wiki.Service
// instance (see file doc comment).
func (r *Repo) GetWikiPageInfo(ctx context.Context, db DBTX, pageID string) (slug, spaceSlug string, version int, err error) {
	err = db.QueryRow(ctx,
		`SELECT p.slug, s.slug, p.version FROM wiki_pages p JOIN wiki_spaces s ON s.id = p.space_id
		  WHERE p.id = $1 AND p.deleted_at IS NULL`,
		pageID,
	).Scan(&slug, &spaceSlug, &version)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", "", 0, ErrNotFound
	}
	if err != nil {
		return "", "", 0, fmt.Errorf("workspace: get wiki page info: %w", err)
	}
	return slug, spaceSlug, version, nil
}

// GetWikiPageText reads a page's title, plain-text body (wiki_pages'
// search_text — already maintained by wiki.CreatePageTx/UpdatePage as a
// TipTap-JSON-to-plain-text mirror for full-text search, and just as usable
// as an AI prompt's source text), and version — Phase 5's own AI methods
// (SuggestTaskBreakdown, ChangeImpact) read a feature's spec doc this way
// rather than parsing wiki_pages.content's TipTap JSON a second time.
func (r *Repo) GetWikiPageText(ctx context.Context, db DBTX, pageID string) (title, text string, version int, err error) {
	err = db.QueryRow(ctx,
		`SELECT title, search_text, version FROM wiki_pages WHERE id = $1 AND deleted_at IS NULL`,
		pageID,
	).Scan(&title, &text, &version)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", "", 0, ErrNotFound
	}
	if err != nil {
		return "", "", 0, fmt.Errorf("workspace: get wiki page text: %w", err)
	}
	return title, text, version, nil
}
