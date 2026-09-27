package workspace

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
)

// repo_release.go — Phase 5 (contract-phase5.md 5a) data layer for releases
// and release_snapshots (migration 040).

const releaseColumns = `r.id, r.version, r.status, r.target_at, r.frozen_at, r.released_at, r.created_by, r.created_at`

func scanRelease(row pgx.Row) (*Release, error) {
	var rel Release
	if err := row.Scan(&rel.ID, &rel.Version, &rel.Status, &rel.TargetAt, &rel.FrozenAt, &rel.ReleasedAt, &rel.CreatedBy, &rel.CreatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("workspace: scan release: %w", err)
	}
	return &rel, nil
}

// releaseRollupColumns appends the feature/bug rollup counts ListReleases and
// GetRelease both need — a per-release features_total/features_done/
// open_bugs used by the release panel's readiness checklist.
const releaseRollupSelect = releaseColumns + `,
	count(w.id) FILTER (WHERE w.type = 'feature' AND w.archived_at IS NULL),
	count(w.id) FILTER (WHERE w.type = 'feature' AND w.archived_at IS NULL AND w.status IN ('done','wont_do')),
	count(w.id) FILTER (WHERE w.type = 'bug' AND w.archived_at IS NULL AND w.status NOT IN ('done','wont_do'))`

func scanReleaseWithRollup(row pgx.Row) (*Release, error) {
	var rel Release
	err := row.Scan(&rel.ID, &rel.Version, &rel.Status, &rel.TargetAt, &rel.FrozenAt, &rel.ReleasedAt, &rel.CreatedBy, &rel.CreatedAt,
		&rel.FeaturesTotal, &rel.FeaturesDone, &rel.OpenBugs)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("workspace: scan release rollup: %w", err)
	}
	return &rel, nil
}

// ListReleases returns every release for a project, newest first, with
// rollup counts.
func (r *Repo) ListReleases(ctx context.Context, db DBTX, projectID string) ([]Release, error) {
	rows, err := db.Query(ctx,
		`SELECT `+releaseRollupSelect+`
		   FROM releases r LEFT JOIN work_items w ON w.release_id = r.id
		  WHERE r.project_id = $1
		  GROUP BY r.id
		  ORDER BY r.created_at DESC`,
		projectID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list releases: %w", err)
	}
	defer rows.Close()
	out := []Release{}
	for rows.Next() {
		rel, err := scanReleaseWithRollup(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *rel)
	}
	return out, rows.Err()
}

// GetRelease returns one release with rollup counts.
func (r *Repo) GetRelease(ctx context.Context, db DBTX, projectID, releaseID string) (*Release, error) {
	return scanReleaseWithRollup(db.QueryRow(ctx,
		`SELECT `+releaseRollupSelect+`
		   FROM releases r LEFT JOIN work_items w ON w.release_id = r.id
		  WHERE r.id = $1 AND r.project_id = $2
		  GROUP BY r.id`,
		releaseID, projectID))
}

// LockRelease is GetRelease's own-row-only variant under FOR UPDATE — the
// lock UpdateRelease holds across its status check and its write (contract:
// "all under release row FOR UPDATE").
func (r *Repo) LockRelease(ctx context.Context, tx pgx.Tx, projectID, releaseID string) (*Release, error) {
	return scanRelease(tx.QueryRow(ctx,
		`SELECT `+releaseColumns+` FROM releases r WHERE r.id = $1 AND r.project_id = $2 FOR UPDATE`,
		releaseID, projectID))
}

// InsertRelease creates a new planned release.
func (r *Repo) InsertRelease(ctx context.Context, db DBTX, projectID, version string, targetAt *time.Time, createdBy string) (*Release, error) {
	row := db.QueryRow(ctx,
		`INSERT INTO releases (project_id, version, target_at, created_by) VALUES ($1,$2,$3,$4)
		 RETURNING id, version, status, target_at, frozen_at, released_at, created_by, created_at`,
		projectID, version, targetAt, createdBy,
	)
	return scanRelease(row)
}

// UpdateReleaseFields renames the version and/or updates target_at (no
// status change — UpdateReleaseStatus below handles that).
func (r *Repo) UpdateReleaseFields(ctx context.Context, tx pgx.Tx, projectID, releaseID, version string, targetAt *time.Time, clearTarget bool) (*Release, error) {
	row := tx.QueryRow(ctx,
		`UPDATE releases SET version = $3, target_at = CASE WHEN $4::boolean THEN NULL ELSE COALESCE($5, target_at) END, updated_at = now()
		  WHERE id = $1 AND project_id = $2
		 RETURNING id, version, status, target_at, frozen_at, released_at, created_by, created_at`,
		releaseID, projectID, version, clearTarget, targetAt,
	)
	return scanRelease(row)
}

// UpdateReleaseStatus applies a machine-checked status transition, stamping
// frozen_at/released_at as appropriate. tx must already hold the release
// row's lock (LockRelease).
func (r *Repo) UpdateReleaseStatus(ctx context.Context, tx pgx.Tx, projectID, releaseID, to string) (*Release, error) {
	row := tx.QueryRow(ctx,
		`UPDATE releases SET
			status = $3,
			frozen_at = CASE WHEN $3 = 'frozen' AND frozen_at IS NULL THEN now() ELSE frozen_at END,
			released_at = CASE WHEN $3 = 'released' THEN now() ELSE released_at END,
			updated_at = now()
		 WHERE id = $1 AND project_id = $2
		 RETURNING id, version, status, target_at, frozen_at, released_at, created_by, created_at`,
		releaseID, projectID, to,
	)
	return scanRelease(row)
}

// CountFeaturesNotDoneInRelease reports how many non-archived features still
// target releaseID without being done/wont_do — UpdateRelease's own
// "released requires every targeted feature done|wont_do" gate.
func (r *Repo) CountFeaturesNotDoneInRelease(ctx context.Context, tx pgx.Tx, releaseID string) (int, error) {
	var n int
	if err := tx.QueryRow(ctx,
		`SELECT count(*) FROM work_items WHERE release_id = $1 AND type = 'feature' AND archived_at IS NULL AND status NOT IN ('done','wont_do')`,
		releaseID,
	).Scan(&n); err != nil {
		return 0, fmt.Errorf("workspace: count features not done in release: %w", err)
	}
	return n, nil
}

// ListItemsByRelease returns every non-archived item currently targeting
// releaseID — GetReleaseNotes' own "live" (not-yet-released) source, and the
// release panel's item list.
func (r *Repo) ListItemsByRelease(ctx context.Context, db DBTX, projectID, releaseID string) ([]WorkItem, error) {
	rows, err := db.Query(ctx,
		`SELECT `+workItemColumns+` FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.project_id = $1 AND w.release_id = $2 AND w.archived_at IS NULL
		  ORDER BY w.key_num ASC`,
		projectID, releaseID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list items by release: %w", err)
	}
	defer rows.Close()
	out := []WorkItem{}
	for rows.Next() {
		it, err := scanWorkItem(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, *it)
	}
	return out, rows.Err()
}

// InsertReleaseSnapshot upserts one item's shipped state into
// release_snapshots — UpdateRelease's own "writes release_snapshots (item
// status + approved_doc_version for every item targeting it)" step, run once
// per targeted item inside the same tx as the released transition.
func (r *Repo) InsertReleaseSnapshot(ctx context.Context, tx pgx.Tx, releaseID, itemID string, docVersion *int, status string) error {
	if _, err := tx.Exec(ctx,
		`INSERT INTO release_snapshots (release_id, item_id, doc_version, status) VALUES ($1,$2,$3,$4)
		 ON CONFLICT (release_id, item_id) DO UPDATE SET doc_version = EXCLUDED.doc_version, status = EXCLUDED.status`,
		releaseID, itemID, docVersion, status,
	); err != nil {
		return fmt.Errorf("workspace: insert release snapshot: %w", err)
	}
	return nil
}

// ListReleaseSnapshotItems returns a released release's frozen "what shipped"
// list — GetReleaseNotes' own source once a release has actually released.
func (r *Repo) ListReleaseSnapshotItems(ctx context.Context, db DBTX, projectID, releaseID string) ([]ReleaseNoteItem, error) {
	rows, err := db.Query(ctx,
		`SELECT w.id, p.key_prefix || '-' || w.key_num, w.type, w.title, rs.status, rs.doc_version
		   FROM release_snapshots rs
		   JOIN work_items w ON w.id = rs.item_id
		   JOIN workspace_projects p ON p.id = w.project_id
		  WHERE rs.release_id = $1 AND w.project_id = $2
		  ORDER BY w.key_num ASC`,
		releaseID, projectID)
	if err != nil {
		return nil, fmt.Errorf("workspace: list release snapshot items: %w", err)
	}
	defer rows.Close()
	out := []ReleaseNoteItem{}
	for rows.Next() {
		var it ReleaseNoteItem
		if err := rows.Scan(&it.Item.ID, &it.Item.Key, &it.Item.Type, &it.Item.Title, &it.Item.Status, &it.DocVersion); err != nil {
			return nil, fmt.Errorf("workspace: scan release snapshot item: %w", err)
		}
		out = append(out, it)
	}
	return out, rows.Err()
}

// SetItemRelease sets (or clears) an item's release_id under the optimistic
// version lock — mirrors UpdateItemFields' own "0 rows means stale version or
// gone" shape (service_release.go tells those apart with a follow-up read).
func (r *Repo) SetItemRelease(ctx context.Context, tx pgx.Tx, projectID, itemID string, expectedVersion int, releaseID *string) (*WorkItem, error) {
	row := tx.QueryRow(ctx,
		`WITH upd AS (
			UPDATE work_items SET release_id = $4, version = version + 1, updated_at = now()
			 WHERE id = $1 AND project_id = $2 AND version = $3 AND archived_at IS NULL
			RETURNING id
		 )
		 SELECT `+workItemColumns+`
		   FROM work_items w JOIN workspace_projects p ON p.id = w.project_id
		  WHERE w.id = (SELECT id FROM upd)`,
		itemID, projectID, expectedVersion, releaseID,
	)
	return scanWorkItem(row)
}

// ReleaseVersionTaken reports whether project+version is already used by
// another release — CreateRelease/UpdateRelease's own version-uniqueness
// pre-check (mirrors KeyPrefixTaken's shape).
func (r *Repo) ReleaseVersionTaken(ctx context.Context, db DBTX, projectID, version, excludeReleaseID string) (bool, error) {
	var taken bool
	if err := db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM releases WHERE project_id = $1 AND version = $2 AND id <> $3)`,
		projectID, version, excludeReleaseID,
	).Scan(&taken); err != nil {
		return false, fmt.Errorf("workspace: check release version: %w", err)
	}
	return taken, nil
}

// NearestRelease returns the project's nearest planned/frozen release
// (soonest target_at, released ones last) — the dashboard's own "no release=
// filter" default (contract-phase5.md: "or the nearest planned/frozen
// release").
func (r *Repo) NearestRelease(ctx context.Context, db DBTX, projectID string) (*Release, error) {
	return scanRelease(db.QueryRow(ctx,
		`SELECT `+releaseColumns+` FROM releases r
		  WHERE r.project_id = $1 AND r.status IN ('planned','frozen')
		  ORDER BY (r.target_at IS NULL), r.target_at ASC, r.created_at ASC LIMIT 1`,
		projectID))
}

// ScopeAddedAfterFreeze counts `release` events after a release's freeze
// time targeting it — the release metrics' own scope-churn signal.
func (r *Repo) ScopeAddedAfterFreeze(ctx context.Context, db DBTX, releaseID string, frozenAt time.Time) (int, error) {
	var n int
	if err := db.QueryRow(ctx,
		`SELECT count(*) FROM work_item_events e
		  WHERE e.kind = 'release' AND e.to_value = $1 AND e.created_at > $2`,
		releaseID, frozenAt,
	).Scan(&n); err != nil {
		return 0, fmt.Errorf("workspace: count scope added after freeze: %w", err)
	}
	return n, nil
}

// CountDocsNotApprovedInRelease counts features targeting releaseID whose
// spec doc isn't approved — one of ReleaseMetrics' readiness signals.
func (r *Repo) CountDocsNotApprovedInRelease(ctx context.Context, db DBTX, releaseID string) (int, error) {
	var n int
	if err := db.QueryRow(ctx,
		`SELECT count(*) FROM work_items WHERE release_id = $1 AND type = 'feature' AND archived_at IS NULL
		   AND (doc_status IS DISTINCT FROM 'approved')`,
		releaseID,
	).Scan(&n); err != nil {
		return 0, fmt.Errorf("workspace: count docs not approved in release: %w", err)
	}
	return n, nil
}

// OpenBugsBySeverityInRelease breaks down a release's open bug count by
// severity — ReleaseMetrics.OpenBugsBySeverity.
func (r *Repo) OpenBugsBySeverityInRelease(ctx context.Context, db DBTX, releaseID string) (map[string]int, error) {
	rows, err := db.Query(ctx,
		`SELECT severity, count(*) FROM work_items
		  WHERE release_id = $1 AND type = 'bug' AND archived_at IS NULL AND status NOT IN ('done','wont_do')
		  GROUP BY severity`,
		releaseID)
	if err != nil {
		return nil, fmt.Errorf("workspace: open bugs by severity in release: %w", err)
	}
	defer rows.Close()
	out := map[string]int{}
	for rows.Next() {
		var sev *string
		var n int
		if err := rows.Scan(&sev, &n); err != nil {
			return nil, err
		}
		if sev != nil {
			out[*sev] = n
		}
	}
	return out, rows.Err()
}
