package assessment

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
)

// ─── Cohort groups (optional hierarchy above batches, e.g. Class/Section) ─────

var (
	ErrInvalidParent = errors.New("assessment: invalid cohort group parent")
	ErrCyclicParent  = errors.New("assessment: cannot move a cohort group under its own descendant")
)

func (r *Repo) CreateCohortGroup(ctx context.Context, g CohortGroup) (CohortGroup, error) {
	err := r.pool.QueryRow(ctx,
		`INSERT INTO cohort_groups (org_id, parent_id, name, slug, level_label, created_by)
		 SELECT $1, $2, $3, $4, $5, $6
		 WHERE $2::uuid IS NULL OR EXISTS (SELECT 1 FROM cohort_groups WHERE id = $2 AND org_id = $1)
		 RETURNING id, status, created_at, updated_at`,
		g.OrgID, g.ParentID, g.Name, g.Slug, g.LevelLabel, g.CreatedBy,
	).Scan(&g.ID, &g.Status, &g.CreatedAt, &g.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return CohortGroup{}, ErrInvalidParent
		}
		return CohortGroup{}, fmt.Errorf("assessment: create cohort group: %w", err)
	}
	return g, nil
}

// UpdateCohortGroup updates a group's editable fields. Scoped to orgID;
// rejects (ErrCyclicParent) re-parenting a group under itself or one of its
// own descendants, and (ErrInvalidParent via ErrNotFound) a parent outside
// the org.
func (r *Repo) UpdateCohortGroup(ctx context.Context, orgID string, g CohortGroup) (CohortGroup, error) {
	if g.ParentID != nil {
		if *g.ParentID == g.ID {
			return CohortGroup{}, ErrCyclicParent
		}
		cyclic, err := r.isCohortGroupDescendant(ctx, orgID, g.ID, *g.ParentID)
		if err != nil {
			return CohortGroup{}, err
		}
		if cyclic {
			return CohortGroup{}, ErrCyclicParent
		}
	}
	err := r.pool.QueryRow(ctx,
		`UPDATE cohort_groups SET name=$3, parent_id=$4, level_label=$5, updated_at=now()
		 WHERE id=$1 AND org_id=$2
		   AND ($4::uuid IS NULL OR EXISTS (SELECT 1 FROM cohort_groups WHERE id=$4 AND org_id=$2))
		 RETURNING id, org_id, parent_id, name, slug, level_label, status, created_by, created_at, updated_at`,
		g.ID, orgID, g.Name, g.ParentID, g.LevelLabel,
	).Scan(&g.ID, &g.OrgID, &g.ParentID, &g.Name, &g.Slug, &g.LevelLabel, &g.Status, &g.CreatedBy, &g.CreatedAt, &g.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return CohortGroup{}, ErrNotFound
		}
		return CohortGroup{}, fmt.Errorf("assessment: update cohort group: %w", err)
	}
	return g, nil
}

func (r *Repo) ListCohortGroups(ctx context.Context, orgID string) ([]CohortGroup, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT g.id, g.org_id, g.parent_id, g.name, g.slug, g.level_label, g.status,
		        g.created_by, g.created_at, g.updated_at,
		        (SELECT count(*) FROM batches b WHERE b.cohort_group_id = g.id AND b.status = 'active') AS batch_count,
		        (SELECT count(*) FROM cohort_groups c WHERE c.parent_id = g.id AND c.status = 'active') AS child_count
		 FROM cohort_groups g
		 WHERE g.org_id = $1 AND g.status = 'active'
		 ORDER BY g.created_at`, orgID)
	if err != nil {
		return nil, fmt.Errorf("assessment: list cohort groups: %w", err)
	}
	defer rows.Close()

	out := []CohortGroup{}
	for rows.Next() {
		var g CohortGroup
		if err := rows.Scan(&g.ID, &g.OrgID, &g.ParentID, &g.Name, &g.Slug, &g.LevelLabel, &g.Status,
			&g.CreatedBy, &g.CreatedAt, &g.UpdatedAt, &g.BatchCount, &g.ChildCount); err != nil {
			return nil, fmt.Errorf("assessment: scan cohort group: %w", err)
		}
		out = append(out, g)
	}
	return out, rows.Err()
}

func (r *Repo) GetCohortGroup(ctx context.Context, orgID, id string) (CohortGroup, error) {
	var g CohortGroup
	err := r.pool.QueryRow(ctx,
		`SELECT g.id, g.org_id, g.parent_id, g.name, g.slug, g.level_label, g.status,
		        g.created_by, g.created_at, g.updated_at,
		        (SELECT count(*) FROM batches b WHERE b.cohort_group_id = g.id AND b.status = 'active'),
		        (SELECT count(*) FROM cohort_groups c WHERE c.parent_id = g.id AND c.status = 'active')
		 FROM cohort_groups g WHERE g.id = $1 AND g.org_id = $2`, id, orgID,
	).Scan(&g.ID, &g.OrgID, &g.ParentID, &g.Name, &g.Slug, &g.LevelLabel, &g.Status,
		&g.CreatedBy, &g.CreatedAt, &g.UpdatedAt, &g.BatchCount, &g.ChildCount)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return CohortGroup{}, ErrNotFound
		}
		return CohortGroup{}, fmt.Errorf("assessment: get cohort group: %w", err)
	}
	return g, nil
}

func (r *Repo) ArchiveCohortGroup(ctx context.Context, orgID, id string) error {
	tag, err := r.pool.Exec(ctx,
		`UPDATE cohort_groups SET status = 'archived', updated_at = now() WHERE id = $1 AND org_id = $2`,
		id, orgID)
	if err != nil {
		return fmt.Errorf("assessment: archive cohort group: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// MoveBatchToGroup lives in repo_batch.go (it mutates batches, not cohort_groups).

// isCohortGroupDescendant reports whether candidateID is ancestorID itself or
// a descendant of it in the cohort_groups tree — used to reject a re-parent
// that would create a cycle (Postgres has no declarative way to CHECK this).
func (r *Repo) isCohortGroupDescendant(ctx context.Context, orgID, ancestorID, candidateID string) (bool, error) {
	var exists bool
	err := r.pool.QueryRow(ctx, `
		WITH RECURSIVE subtree AS (
			SELECT id FROM cohort_groups WHERE id = $1 AND org_id = $2
			UNION ALL
			SELECT cg.id FROM cohort_groups cg JOIN subtree s ON cg.parent_id = s.id
		)
		SELECT EXISTS(SELECT 1 FROM subtree WHERE id = $3)`,
		ancestorID, orgID, candidateID,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("assessment: check cohort group cycle: %w", err)
	}
	return exists, nil
}

// DescendantBatchIDs returns the ids of all active batches under groupID's
// subtree (the group itself plus every descendant group) — the primitive a
// group-scoped leaderboard/analytics rollup resolves against.
func (r *Repo) DescendantBatchIDs(ctx context.Context, orgID, groupID string) ([]string, error) {
	rows, err := r.pool.Query(ctx, `
		WITH RECURSIVE subtree AS (
			SELECT id FROM cohort_groups WHERE id = $1 AND org_id = $2
			UNION ALL
			SELECT cg.id FROM cohort_groups cg JOIN subtree s ON cg.parent_id = s.id
		)
		SELECT b.id FROM batches b
		JOIN subtree s ON b.cohort_group_id = s.id
		WHERE b.status = 'active'`,
		groupID, orgID)
	if err != nil {
		return nil, fmt.Errorf("assessment: descendant batch ids: %w", err)
	}
	defer rows.Close()

	out := []string{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("assessment: scan descendant batch id: %w", err)
		}
		out = append(out, id)
	}
	return out, rows.Err()
}
