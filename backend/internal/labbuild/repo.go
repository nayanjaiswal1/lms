package labbuild

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repo persists builds, variants and block usages (lab_builds,
// lab_build_variants, lab_block_usages).
type Repo struct{ pool *pgxpool.Pool }

// NewRepo returns a Repo over pool.
func NewRepo(pool *pgxpool.Pool) *Repo { return &Repo{pool: pool} }

const buildCols = `b.id, b.recipe_id, b.recipe_hash, b.status, b.report, b.derived_difficulty, b.created_by, b.created_at, b.finished_at, b.spec_snapshot`

func scanBuild(row pgx.Row) (*Build, error) {
	var b Build
	var snap []byte
	if err := row.Scan(&b.ID, &b.RecipeID, &b.RecipeHash, &b.Status, &b.Report, &b.DerivedDifficulty, &b.CreatedBy, &b.CreatedAt, &b.FinishedAt, &snap); err != nil {
		return nil, err
	}
	if err := json.Unmarshal(snap, &b.Snapshot); err != nil {
		return nil, fmt.Errorf("labbuild: build %s snapshot: %w", b.ID, err)
	}
	return &b, nil
}

// CreateBuild inserts a queued build. If the recipe already has an in-flight
// build for the same hash, that build is returned with ErrBuildInFlight.
func (r *Repo) CreateBuild(ctx context.Context, recipeID, hash string, snap Snapshot, difficulty, createdBy string) (*Build, error) {
	raw, err := json.Marshal(snap)
	if err != nil {
		return nil, fmt.Errorf("labbuild.Repo.CreateBuild: %w", err)
	}
	b, err := scanBuild(r.pool.QueryRow(ctx, `
		INSERT INTO public.lab_builds AS b (recipe_id, recipe_hash, spec_snapshot, status, derived_difficulty, created_by)
		VALUES ($1, $2, $3::jsonb, 'queued', NULLIF($4,''), $5)
		RETURNING `+buildCols, recipeID, hash, raw, difficulty, createdBy))
	if err != nil {
		var pe *pgconn.PgError
		if errors.As(err, &pe) && pe.Code == "23505" {
			existing, gerr := r.LatestBuild(ctx, recipeID, hash)
			if gerr != nil {
				return nil, gerr
			}
			return existing, ErrBuildInFlight
		}
		return nil, fmt.Errorf("labbuild.Repo.CreateBuild: %w", err)
	}
	return b, nil
}

// GetBuild loads a build by id (ErrBuildNotFound).
func (r *Repo) GetBuild(ctx context.Context, id string) (*Build, error) {
	b, err := scanBuild(r.pool.QueryRow(ctx, `SELECT `+buildCols+` FROM public.lab_builds b WHERE b.id = $1`, id))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrBuildNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("labbuild.Repo.GetBuild: %w", err)
	}
	return b, nil
}

// GetBuildForOrg loads a build only if its recipe belongs to orgID.
func (r *Repo) GetBuildForOrg(ctx context.Context, orgID, id string) (*Build, error) {
	b, err := scanBuild(r.pool.QueryRow(ctx, `
		SELECT `+buildCols+` FROM public.lab_builds b
		JOIN public.lab_recipes rc ON rc.id = b.recipe_id
		WHERE b.id = $1 AND rc.org_id = $2`, id, orgID))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrBuildNotFound
	}
	if err != nil {
		return nil, fmt.Errorf("labbuild.Repo.GetBuildForOrg: %w", err)
	}
	return b, nil
}

// LatestBuild returns the newest build of a recipe for a hash, or (nil, nil).
func (r *Repo) LatestBuild(ctx context.Context, recipeID, hash string) (*Build, error) {
	b, err := scanBuild(r.pool.QueryRow(ctx, `
		SELECT `+buildCols+` FROM public.lab_builds b
		WHERE b.recipe_id = $1 AND b.recipe_hash = $2 ORDER BY b.created_at DESC LIMIT 1`, recipeID, hash))
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("labbuild.Repo.LatestBuild: %w", err)
	}
	return b, nil
}

// SetJob records the enqueued job id.
func (r *Repo) SetJob(ctx context.Context, id, jobID string) error {
	if _, err := r.pool.Exec(ctx, `UPDATE public.lab_builds SET job_id = $2 WHERE id = $1`, id, jobID); err != nil {
		return fmt.Errorf("labbuild.Repo.SetJob: %w", err)
	}
	return nil
}

// Advance moves a build to status `to` if it is currently in one of `from`.
// It reports whether the transition happened, which is what makes the jobs safe
// to retry: a retried job whose build already moved on simply does nothing.
func (r *Repo) Advance(ctx context.Context, id string, from []string, to string) (bool, error) {
	tag, err := r.pool.Exec(ctx, `UPDATE public.lab_builds SET status = $3 WHERE id = $1 AND status = ANY($2)`, id, from, to)
	if err != nil {
		return false, fmt.Errorf("labbuild.Repo.Advance: %w", err)
	}
	return tag.RowsAffected() == 1, nil
}

// SaveReport stores the live report without changing status.
func (r *Repo) SaveReport(ctx context.Context, id string, rep Report) error {
	raw, err := json.Marshal(rep)
	if err != nil {
		return fmt.Errorf("labbuild.Repo.SaveReport: %w", err)
	}
	if _, err := r.pool.Exec(ctx, `UPDATE public.lab_builds SET report = $2::jsonb WHERE id = $1`, id, raw); err != nil {
		return fmt.Errorf("labbuild.Repo.SaveReport: %w", err)
	}
	return nil
}

// Finish sets a terminal status (verified|failed) with its report, only from an
// in-flight status (a verified build is never overwritten).
func (r *Repo) Finish(ctx context.Context, id, status string, rep Report) (bool, error) {
	raw, err := json.Marshal(rep)
	if err != nil {
		return false, fmt.Errorf("labbuild.Repo.Finish: %w", err)
	}
	tag, err := r.pool.Exec(ctx, `
		UPDATE public.lab_builds SET status = $2, report = $3::jsonb, finished_at = $4
		WHERE id = $1 AND status IN ('queued','rendering','verifying')`, id, status, raw, time.Now().UTC())
	if err != nil {
		return false, fmt.Errorf("labbuild.Repo.Finish: %w", err)
	}
	return tag.RowsAffected() == 1, nil
}

// InsertVariants stores the rendered variants and the block versions used, and
// moves the build rendering -> verifying, all in one transaction. Idempotent
// (ON CONFLICT DO NOTHING), so a retried render job cannot duplicate rows.
func (r *Repo) InsertVariants(ctx context.Context, buildID string, rows []VariantRow, usageVersionIDs []string) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("labbuild.Repo.InsertVariants: begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	for _, v := range rows {
		if _, err := tx.Exec(ctx, `
			INSERT INTO public.lab_build_variants (build_id, variant_key, workspace_bundle_key, workspace_bundle_sha256,
				grader_bundle_key, grader_bundle_sha256, brief_md, protected_manifest, app_ports, payload)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8::jsonb,$9,$10::jsonb)
			ON CONFLICT (build_id, variant_key) DO NOTHING`,
			buildID, v.Key, v.WorkspaceKey, v.WorkspaceSHA, v.GraderKey, v.GraderSHA, v.BriefMD, []byte(v.ProtectedManifest), v.AppPorts, []byte(v.Payload)); err != nil {
			return fmt.Errorf("labbuild.Repo.InsertVariants: variant %s: %w", v.Key, err)
		}
	}
	for _, id := range usageVersionIDs {
		if _, err := tx.Exec(ctx, `INSERT INTO public.lab_block_usages (build_id, block_version_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`, buildID, id); err != nil {
			return fmt.Errorf("labbuild.Repo.InsertVariants: usage: %w", err)
		}
	}
	if _, err := tx.Exec(ctx, `UPDATE public.lab_builds SET status = 'verifying' WHERE id = $1 AND status IN ('queued','rendering')`, buildID); err != nil {
		return fmt.Errorf("labbuild.Repo.InsertVariants: advance: %w", err)
	}
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("labbuild.Repo.InsertVariants: commit: %w", err)
	}
	return nil
}

// ListVariants returns a build's variants ordered by key.
func (r *Repo) ListVariants(ctx context.Context, buildID string) ([]VariantRow, error) {
	rows, err := r.pool.Query(ctx, `
		SELECT build_id, variant_key, workspace_bundle_key, workspace_bundle_sha256, grader_bundle_key, grader_bundle_sha256,
		       brief_md, protected_manifest, app_ports, payload
		FROM public.lab_build_variants WHERE build_id = $1 ORDER BY variant_key`, buildID)
	if err != nil {
		return nil, fmt.Errorf("labbuild.Repo.ListVariants: %w", err)
	}
	defer rows.Close()
	var out []VariantRow
	for rows.Next() {
		var v VariantRow
		var ports []int32
		if err := rows.Scan(&v.BuildID, &v.Key, &v.WorkspaceKey, &v.WorkspaceSHA, &v.GraderKey, &v.GraderSHA,
			&v.BriefMD, &v.ProtectedManifest, &ports, &v.Payload); err != nil {
			return nil, fmt.Errorf("labbuild.Repo.ListVariants: scan: %w", err)
		}
		for _, p := range ports {
			v.AppPorts = append(v.AppPorts, int(p))
		}
		out = append(out, v)
	}
	return out, rows.Err()
}

// UpdateVariantBrief replaces a variant's workspace bundle and brief (the
// captured trace was substituted after the broken run).
func (r *Repo) UpdateVariantBrief(ctx context.Context, buildID, key, wsKey, wsSHA, brief string) error {
	if _, err := r.pool.Exec(ctx, `
		UPDATE public.lab_build_variants SET workspace_bundle_key = $3, workspace_bundle_sha256 = $4, brief_md = $5
		WHERE build_id = $1 AND variant_key = $2`, buildID, key, wsKey, wsSHA, brief); err != nil {
		return fmt.Errorf("labbuild.Repo.UpdateVariantBrief: %w", err)
	}
	return nil
}
