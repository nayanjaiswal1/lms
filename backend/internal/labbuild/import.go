package labbuild

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"sort"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/contentpipeline/canonical"
	"github.com/mindforge/backend/internal/labauthor"
	"github.com/mindforge/backend/internal/storage"
)

// Labset import errors.
var (
	ErrLabsetRuntime    = errors.New("labbuild: the labset was verified against a different lab runtime")
	ErrLabsetIncomplete = errors.New("labbuild: the labset does not cover every platform recipe")
	ErrLabsetRecipe     = errors.New("labbuild: the labset does not match this database's platform recipes")
)

// ImportOptions tunes ImportLabset.
type ImportOptions struct {
	// ExpectRuntimeID is the runtime stamp of the lab image this environment
	// runs (read from the image, never by starting a sandbox). Required.
	ExpectRuntimeID string
	// Partial imports just the labset's recipes instead of requiring every
	// platform recipe (the authoring loop: one edited recipe on a dev box).
	// Deploys never set it.
	Partial bool
}

// ImportedRecipe is one recipe's outcome.
type ImportedRecipe struct {
	RecipeID, BuildID, LabID, TaskVersionID string
	Version                                 int
	// ReusedBuild: an in-app build already holds this (recipe, hash, runtime)
	// verified slot, or a previous import created it.
	ReusedBuild bool
	// Unchanged: the lab was already published from this build (no new version).
	Unchanged bool
}

// ImportResult summarises an import.
type ImportResult struct {
	Recipes  []ImportedRecipe
	Uploaded int
}

// NewImporter is the Service subset ImportLabset needs: the database and the
// private bundle store. It has no container runtime or Redis, so nothing an
// import does can start a sandbox.
func NewImporter(pool *pgxpool.Pool, store storage.PrivateStore) *Service {
	return &Service{pool: pool, store: store, authoring: labauthor.NewService(labauthor.NewRepo(pool), nil), repo: NewRepo(pool)}
}

// importPlan is one checked labset recipe, ready to write.
type importPlan struct {
	in     LabsetRecipe
	recipe *labauthor.Recipe
	res    *resolved
	rows   []VariantRow
	usage  []string
}

// ImportLabset publishes a CI-verified labset (docs/debug-labs.md B5
// "Platform course content"). Nothing is written unless everything checks out:
//  1. every file matches the manifest's sha256 and the labset was verified
//     against opt.ExpectRuntimeID;
//  2. every platform recipe in the database has an entry (unless opt.Partial),
//     and every entry is a platform recipe whose CURRENT spec resolves, still
//     validates (no yanked block) and hashes to the verified hash;
//  3. bundles and block payloads are uploaded (content-addressed, idempotent,
//     before the transaction that references them);
//  4. ONE transaction records a verified build per recipe (deterministic id;
//     an existing verified build of the same recipe/hash/runtime is reused) and
//     publishes it through publishLab, which writes the catalog row.
//
// Re-importing the same labset changes nothing. Importing an older labset
// rolls back: it cuts a new task version pointing at the older build. Running
// sessions stay pinned to their task version either way.
func (s *Service) ImportLabset(ctx context.Context, dir string, opt ImportOptions) (*ImportResult, error) {
	if opt.ExpectRuntimeID == "" {
		return nil, fmt.Errorf("labbuild.ImportLabset: the expected runtime id is required")
	}
	m, err := ReadLabset(dir)
	if err != nil {
		return nil, fmt.Errorf("labbuild.ImportLabset: %w", err)
	}
	if m.RuntimeID != opt.ExpectRuntimeID {
		return nil, fmt.Errorf("%w: labset %q, environment %q", ErrLabsetRuntime, m.RuntimeID, opt.ExpectRuntimeID)
	}

	orgOf, err := s.platformRecipes(ctx)
	if err != nil {
		return nil, fmt.Errorf("labbuild.ImportLabset: %w", err)
	}
	seen := map[string]bool{}
	for _, r := range m.Recipes {
		if seen[r.RecipeID] {
			return nil, fmt.Errorf("%w: recipe %s is listed twice", ErrLabsetCorrupt, r.RecipeID)
		}
		seen[r.RecipeID] = true
	}
	if !opt.Partial {
		var missing []string
		for id := range orgOf {
			if !seen[id] {
				missing = append(missing, id)
			}
		}
		if len(missing) > 0 {
			sort.Strings(missing)
			return nil, fmt.Errorf("%w: no artifact for %v", ErrLabsetIncomplete, missing)
		}
	}

	uploads := map[string]bool{}
	plans := make([]importPlan, 0, len(m.Recipes))
	for _, r := range m.Recipes {
		org, ok := orgOf[r.RecipeID]
		if !ok {
			return nil, fmt.Errorf("%w: %s is not a platform recipe here", ErrLabsetRecipe, r.RecipeID)
		}
		p, err := s.planImport(ctx, m, org, r, uploads)
		if err != nil {
			return nil, fmt.Errorf("labbuild.ImportLabset: recipe %s: %w", r.RecipeID, err)
		}
		plans = append(plans, *p)
	}
	sort.Slice(plans, func(i, j int) bool { return plans[i].in.RecipeID < plans[j].in.RecipeID })

	shas := make([]string, 0, len(uploads))
	for sha := range uploads {
		shas = append(shas, sha)
	}
	sort.Strings(shas)
	for _, sha := range shas {
		data, err := m.readBundle(dir, sha)
		if err != nil {
			return nil, fmt.Errorf("labbuild.ImportLabset: %w", err)
		}
		if _, _, err := storage.PutBundle(ctx, s.store, data); err != nil {
			return nil, fmt.Errorf("labbuild.ImportLabset: %w", err)
		}
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("labbuild.ImportLabset: begin: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()
	out := &ImportResult{Uploaded: len(shas)}
	for _, p := range plans {
		buildID, reused, err := s.recordImportedBuild(ctx, tx, m.RuntimeID, p)
		if err != nil {
			return nil, fmt.Errorf("labbuild.ImportLabset: recipe %s: %w", p.in.RecipeID, err)
		}
		pub, err := s.publishLab(ctx, tx, publishIn{
			OrgID: p.recipe.OrgID, UserID: p.recipe.OwnerID, Build: &Build{ID: buildID}, Kind: p.res.Kind,
			LabID: *p.recipe.LabID, Title: p.recipe.Title, RecipeID: p.recipe.ID,
			Catalog: catalogOf(p.res.Recipe, p.res.Analysis.Difficulty),
		})
		if err != nil {
			return nil, fmt.Errorf("labbuild.ImportLabset: recipe %s: %w", p.in.RecipeID, err)
		}
		out.Recipes = append(out.Recipes, ImportedRecipe{RecipeID: p.in.RecipeID, BuildID: buildID, LabID: pub.LabID,
			TaskVersionID: pub.VersionID, Version: pub.Version, ReusedBuild: reused, Unchanged: pub.Unchanged})
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("labbuild.ImportLabset: commit: %w", err)
	}
	slog.Info("labbuild: labset imported", "runtime_id", m.RuntimeID, "git_sha", m.GitSHA, "ci_build", m.CIBuild,
		"recipes", len(out.Recipes), "bundles", out.Uploaded)
	return out, nil
}

// platformRecipes maps every platform recipe id to its org.
func (s *Service) platformRecipes(ctx context.Context) (map[string]string, error) {
	rows, err := s.pool.Query(ctx, `SELECT id, org_id FROM public.lab_recipes WHERE is_platform`)
	if err != nil {
		return nil, fmt.Errorf("labbuild.platformRecipes: %w", err)
	}
	defer rows.Close()
	out := map[string]string{}
	for rows.Next() {
		var id, org string
		if err := rows.Scan(&id, &org); err != nil {
			return nil, fmt.Errorf("labbuild.platformRecipes: scan: %w", err)
		}
		out[id] = org
	}
	return out, rows.Err()
}

// planImport checks one labset recipe against the database's current recipe
// and collects the bundles it needs uploaded.
func (s *Service) planImport(ctx context.Context, m *Labset, orgID string, in LabsetRecipe, uploads map[string]bool) (*importPlan, error) {
	rc, err := s.authoring.Repo().GetRecipe(ctx, orgID, in.RecipeID)
	if err != nil {
		return nil, fmt.Errorf("labbuild.planImport: %w", err)
	}
	if rc.LabID == nil {
		return nil, fmt.Errorf("%w: platform recipe has no lab", ErrLabsetRecipe)
	}
	if rc.LabKind != in.LabKind {
		return nil, fmt.Errorf("%w: lab kind %q in the labset, %q here", ErrBuildStale, in.LabKind, rc.LabKind)
	}
	res, err := s.resolveSnapshot(ctx, Snapshot{LabKind: rc.LabKind, OrgID: rc.OrgID, Spec: rc.Spec})
	if err != nil {
		return nil, fmt.Errorf("labbuild.planImport: %w", err)
	}
	if !res.Analysis.Valid {
		return nil, &labauthor.InvalidRecipeError{Analysis: res.Analysis}
	}
	if res.Analysis.RecipeHash != in.RecipeHash {
		return nil, fmt.Errorf("%w: verified hash %s, current %s", ErrBuildStale, in.RecipeHash, res.Analysis.RecipeHash)
	}
	if !in.Report.Passed() {
		return nil, fmt.Errorf("%w: the labset entry did not pass verification", ErrLabsetCorrupt)
	}

	p := &importPlan{in: in, recipe: rc, res: res}
	need := func(sha string) error {
		if _, ok := m.Files[LabsetBundlePath(sha)]; !ok {
			return fmt.Errorf("%w: bundle %s is not in the labset", ErrLabsetCorrupt, sha)
		}
		uploads[sha] = true
		return nil
	}
	for _, v := range in.Variants {
		var vf VerifyBundle
		if err := json.Unmarshal(v.Payload, &vf); err != nil || vf.SHA != v.VerifySHA || vf.Key != storage.BundleKey(v.VerifySHA) {
			return nil, fmt.Errorf("%w: variant %s payload does not name its verify bundle", ErrLabsetCorrupt, v.Key)
		}
		for _, sha := range []string{v.WorkspaceSHA, v.GraderSHA, v.VerifySHA} {
			if err := need(sha); err != nil {
				return nil, err
			}
		}
		ports := v.AppPorts
		if ports == nil {
			ports = []int{}
		}
		p.rows = append(p.rows, VariantRow{Key: v.Key,
			WorkspaceKey: storage.BundleKey(v.WorkspaceSHA), WorkspaceSHA: v.WorkspaceSHA,
			GraderKey: storage.BundleKey(v.GraderSHA), GraderSHA: v.GraderSHA,
			BriefMD: v.BriefMD, ProtectedManifest: v.ProtectedManifest, AppPorts: ports, Payload: v.Payload})
	}
	if len(p.rows) == 0 {
		return nil, fmt.Errorf("%w: the labset entry has no variants", ErrLabsetCorrupt)
	}
	for _, b := range res.Recipe.Blocks {
		p.usage = append(p.usage, b.VersionID)
	}
	refs, err := s.authoring.Repo().PayloadRefs(ctx, p.usage)
	if err != nil {
		return nil, fmt.Errorf("labbuild.planImport: %w", err)
	}
	for id, ref := range refs {
		if ref.Key != storage.BundleKey(ref.SHA) {
			return nil, fmt.Errorf("labbuild.planImport: block version %s payload key %q is not content-addressed", id, ref.Key)
		}
		if err := need(ref.SHA); err != nil {
			return nil, fmt.Errorf("block version %s payload: %w", id, err)
		}
	}
	return p, nil
}

// recordImportedBuild inserts the verified build of a labset recipe under its
// deterministic id with its variants and block usages, or reuses the verified
// build that already holds the (recipe, hash, runtime) slot.
func (s *Service) recordImportedBuild(ctx context.Context, tx pgx.Tx, runtimeID string, p importPlan) (string, bool, error) {
	id := canonical.ID(p.in.RecipeID, "build:"+p.in.RecipeHash+":"+runtimeID)
	snap, err := json.Marshal(Snapshot{LabKind: p.recipe.LabKind, OrgID: p.recipe.OrgID, Spec: p.recipe.Spec})
	if err != nil {
		return "", false, fmt.Errorf("labbuild.recordImportedBuild: %w", err)
	}
	rep := p.in.Report
	rep.RuntimeID = runtimeID
	rawRep, err := json.Marshal(rep)
	if err != nil {
		return "", false, fmt.Errorf("labbuild.recordImportedBuild: %w", err)
	}
	tag, err := tx.Exec(ctx, `
		INSERT INTO public.lab_builds (id, recipe_id, recipe_hash, runtime_id, spec_snapshot, status, report, derived_difficulty, created_by, finished_at)
		VALUES ($1, $2, $3, $4, $5::jsonb, 'verified', $6::jsonb, NULLIF($7, ''), $8, now())
		ON CONFLICT DO NOTHING`,
		id, p.in.RecipeID, p.in.RecipeHash, runtimeID, snap, rawRep, p.res.Analysis.Difficulty, p.recipe.OwnerID)
	if err != nil {
		return "", false, fmt.Errorf("labbuild.recordImportedBuild: %w", err)
	}
	if tag.RowsAffected() == 0 {
		var existing string
		if err := tx.QueryRow(ctx, `
			SELECT id FROM public.lab_builds
			WHERE recipe_id = $1 AND recipe_hash = $2 AND runtime_id = $3 AND status = 'verified'`,
			p.in.RecipeID, p.in.RecipeHash, runtimeID).Scan(&existing); err != nil {
			return "", false, fmt.Errorf("labbuild.recordImportedBuild: find the verified build: %w", err)
		}
		return existing, true, nil
	}
	if err := insertVariants(ctx, tx, id, p.rows, p.usage); err != nil {
		return "", false, fmt.Errorf("labbuild.recordImportedBuild: %w", err)
	}
	return id, false, nil
}
