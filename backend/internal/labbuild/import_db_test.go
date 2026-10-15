package labbuild

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
	"github.com/mindforge/backend/internal/labauthor"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

const (
	testBlocksDir  = "../../../content/lab-blocks"
	testRecipeFile = "../../../content/courses/production-debugging/recipes/dj-money-rounding.yaml"
	runtimeA       = "runtime-aaaaaaaaaaaa"
	runtimeB       = "runtime-bbbbbbbbbbbb"
)

// importFixture is a migrated test DB with the repo's platform blocks synced
// and one platform recipe (a real recipe file) on an unpublished lab.
type importFixture struct {
	pool                *pgxpool.Pool
	store               *memStore
	svc                 *Service
	payloads            map[string][]byte // block version id -> payload
	orgID, userID       string
	recipeID, labID     string
	recipeHash, labKind string
	blockIDs            []string
}

func newImportFixture(t *testing.T) *importFixture {
	t.Helper()
	ctx := context.Background()
	pool := testdb.New(t)
	blocks, err := labauthor.LoadBlockTree(testBlocksDir)
	require.NoError(t, err)
	sql, err := labauthor.RenderSyncSQL(blocks)
	require.NoError(t, err)
	_, err = pool.Exec(ctx, sql)
	require.NoError(t, err)

	f := &importFixture{pool: pool, store: newMemStore(), payloads: map[string][]byte{}}
	for _, b := range blocks {
		if b.Payload != nil {
			f.payloads[b.VersionID] = b.Payload
		}
	}
	f.svc = NewImporter(pool, f.store)
	require.NoError(t, pool.QueryRow(ctx, `INSERT INTO organizations (slug, name) VALUES ('platform', 'Platform') RETURNING id`).Scan(&f.orgID))
	require.NoError(t, pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('author@`+testdomain.Domain+`', 'Author') RETURNING id`).Scan(&f.userID))
	f.recipeID, f.labID = f.addPlatformRecipe(t, "production-debugging/lab-dj-money-rounding")

	rc, err := f.svc.authoring.Repo().GetRecipe(ctx, f.orgID, f.recipeID)
	require.NoError(t, err)
	res, err := f.svc.resolveSnapshot(ctx, Snapshot{LabKind: rc.LabKind, OrgID: rc.OrgID, Spec: rc.Spec})
	require.NoError(t, err)
	require.True(t, res.Analysis.Valid, "%+v", res.Analysis.Issues)
	f.recipeHash, f.labKind = res.Analysis.RecipeHash, rc.LabKind
	for _, b := range res.Recipe.Blocks {
		f.blockIDs = append(f.blockIDs, b.VersionID)
	}
	return f
}

// addPlatformRecipe inserts an unpublished lab and its platform recipe (the
// shape `coursegen generate` emits) and returns (recipe id, lab id).
func (f *importFixture) addPlatformRecipe(t *testing.T, idKey string) (string, string) {
	t.Helper()
	ctx := context.Background()
	rs, err := canonical.LoadRecipe(testRecipeFile)
	require.NoError(t, err)
	spec, err := rs.Spec()
	require.NoError(t, err)
	raw, err := json.Marshal(spec)
	require.NoError(t, err)
	labID, recipeID := canonical.ID(idKey, "lab"), canonical.LabRecipeID(idKey)
	_, err = f.pool.Exec(ctx, `
		INSERT INTO lab_definitions (id, org_id, scope, title, lab_type, environment, is_published, created_by)
		VALUES ($1, $2, 'standalone', 'Money rounding', 'debug', 'mindforge/lab-debug:1', false, $3)`, labID, f.orgID, f.userID)
	require.NoError(t, err)
	_, err = f.pool.Exec(ctx, `
		INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
		VALUES ($1, $2, $3, $4, 'Money rounding', $5::jsonb, $6, true)`, recipeID, f.orgID, f.userID, rs.LabKind, raw, labID)
	require.NoError(t, err)
	return recipeID, labID
}

// writeLabset writes a labset for the fixture's recipe through the same writer
// the CLI uses. seed varies the bundle bytes so two labsets differ.
func (f *importFixture) writeLabset(t *testing.T, runtimeID, seed string) string {
	t.Helper()
	dir := t.TempDir()
	a := testRendered(t, "v0")
	a.Files["grader.tar.gz"] = append(append([]byte(nil), a.Files["grader.tar.gz"]...), []byte(seed)...)
	art, err := variantRowFrom("", a)
	require.NoError(t, err)
	rep := &Report{RecipeHash: f.recipeHash, Difficulty: "intermediate", VariantCount: 1, Variants: []VariantReport{{Key: "v0", Passed: true}}}
	r := LabsetRecipeFrom(f.labKind, f.blockIDs, rep, []VariantArtifact{*art})
	r.RecipeID = f.recipeID
	for _, data := range [][]byte{art.Workspace, art.Grader, art.Verify} {
		require.NoError(t, WriteLabsetBundle(dir, data))
	}
	for _, id := range f.blockIDs {
		if p := f.payloads[id]; p != nil {
			require.NoError(t, WriteLabsetBundle(dir, p))
		}
	}
	require.NoError(t, WriteLabsetManifest(dir, &Labset{RuntimeID: runtimeID, GitSHA: "abc", CIBuild: "1", Recipes: []LabsetRecipe{r}}))
	return dir
}

func (f *importFixture) published(t *testing.T) (buildID string, version int) {
	t.Helper()
	require.NoError(t, f.pool.QueryRow(context.Background(), `
		SELECT ld.build_id, tv.version FROM lab_definitions ld
		JOIN lab_task_versions tv ON tv.id = ld.published_version_id
		WHERE ld.id = $1 AND ld.is_published AND tv.build_id = ld.build_id`, f.labID).Scan(&buildID, &version))
	return buildID, version
}

func TestImportLabset_PublishesAndIsIdempotent(t *testing.T) {
	ctx := context.Background()
	f := newImportFixture(t)
	dir := f.writeLabset(t, runtimeA, "a")

	res, err := f.svc.ImportLabset(ctx, dir, ImportOptions{ExpectRuntimeID: runtimeA})
	require.NoError(t, err)
	require.Len(t, res.Recipes, 1)
	got := res.Recipes[0]
	wantBuild := canonical.ID(f.recipeID, "build:"+f.recipeHash+":"+runtimeA)
	require.Equal(t, wantBuild, got.BuildID)
	require.False(t, got.ReusedBuild)
	require.False(t, got.Unchanged)

	buildID, version := f.published(t)
	require.Equal(t, wantBuild, buildID)
	require.Equal(t, 1, version)

	var status, runtimeID string
	var variants, usages int
	require.NoError(t, f.pool.QueryRow(ctx, `SELECT status, runtime_id,
		(SELECT count(*) FROM lab_build_variants WHERE build_id = b.id),
		(SELECT count(*) FROM lab_block_usages WHERE build_id = b.id)
		FROM lab_builds b WHERE id = $1`, buildID).Scan(&status, &runtimeID, &variants, &usages))
	require.Equal(t, StatusVerified, status)
	require.Equal(t, runtimeA, runtimeID)
	require.Equal(t, 1, variants)
	require.Equal(t, len(f.blockIDs), usages)

	var stack, category, difficulty string
	require.NoError(t, f.pool.QueryRow(ctx, `SELECT stack, category, difficulty FROM lab_catalog_meta WHERE lab_id = $1`, f.labID).
		Scan(&stack, &category, &difficulty))
	require.Equal(t, "django", stack)
	require.NotEmpty(t, category)
	require.NotEmpty(t, difficulty)

	// Every referenced object is in the store: variant bundles and block payloads.
	var keys []string
	rows, err := f.pool.Query(ctx, `
		SELECT workspace_bundle_key FROM lab_build_variants WHERE build_id = $1
		UNION SELECT grader_bundle_key FROM lab_build_variants WHERE build_id = $1
		UNION SELECT payload->>'verify_bundle_key' FROM lab_build_variants WHERE build_id = $1
		UNION SELECT v.payload_key FROM lab_block_usages u JOIN lab_block_versions v ON v.id = u.block_version_id
		      WHERE u.build_id = $1 AND v.payload_key IS NOT NULL`, buildID)
	require.NoError(t, err)
	for rows.Next() {
		var k string
		require.NoError(t, rows.Scan(&k))
		keys = append(keys, k)
	}
	require.NoError(t, rows.Err())
	require.Greater(t, len(keys), 3)
	for _, k := range keys {
		_, err := f.store.Download(ctx, k)
		require.NoError(t, err, "object %s uploaded", k)
	}

	// Re-run: nothing new.
	res, err = f.svc.ImportLabset(ctx, dir, ImportOptions{ExpectRuntimeID: runtimeA})
	require.NoError(t, err)
	require.True(t, res.Recipes[0].ReusedBuild)
	require.True(t, res.Recipes[0].Unchanged)
	_, version = f.published(t)
	require.Equal(t, 1, version)
	var builds, versions int
	require.NoError(t, f.pool.QueryRow(ctx, `SELECT (SELECT count(*) FROM lab_builds), (SELECT count(*) FROM lab_task_versions WHERE lab_id = $1)`, f.labID).
		Scan(&builds, &versions))
	require.Equal(t, 1, builds)
	require.Equal(t, 1, versions)
}

func TestImportLabset_RollbackCutsNewVersionOnOlderBuild(t *testing.T) {
	ctx := context.Background()
	f := newImportFixture(t)
	a, b := f.writeLabset(t, runtimeA, "a"), f.writeLabset(t, runtimeB, "b")

	_, err := f.svc.ImportLabset(ctx, a, ImportOptions{ExpectRuntimeID: runtimeA})
	require.NoError(t, err)
	buildA, _ := f.published(t)
	_, err = f.svc.ImportLabset(ctx, b, ImportOptions{ExpectRuntimeID: runtimeB})
	require.NoError(t, err)
	buildB, v2 := f.published(t)
	require.NotEqual(t, buildA, buildB)
	require.Equal(t, 2, v2)

	res, err := f.svc.ImportLabset(ctx, a, ImportOptions{ExpectRuntimeID: runtimeA})
	require.NoError(t, err)
	require.True(t, res.Recipes[0].ReusedBuild)
	require.False(t, res.Recipes[0].Unchanged)
	build, v3 := f.published(t)
	require.Equal(t, buildA, build)
	require.Equal(t, 3, v3)
}

func TestImportLabset_ReusesInAppVerifiedBuild(t *testing.T) {
	ctx := context.Background()
	f := newImportFixture(t)
	var inApp string
	require.NoError(t, f.pool.QueryRow(ctx, `
		INSERT INTO lab_builds (recipe_id, recipe_hash, runtime_id, spec_snapshot, status, created_by)
		VALUES ($1, $2, $3, '{}'::jsonb, 'verified', $4) RETURNING id`, f.recipeID, f.recipeHash, runtimeA, f.userID).Scan(&inApp))

	res, err := f.svc.ImportLabset(ctx, f.writeLabset(t, runtimeA, "a"), ImportOptions{ExpectRuntimeID: runtimeA})
	require.NoError(t, err)
	require.Equal(t, inApp, res.Recipes[0].BuildID)
	require.True(t, res.Recipes[0].ReusedBuild)
	build, _ := f.published(t)
	require.Equal(t, inApp, build)
}

// Platform recipes have no in-app build path: CI + import only.
func TestStartBuild_RefusesPlatformRecipe(t *testing.T) {
	f := newImportFixture(t)
	_, err := f.svc.StartBuild(context.Background(), f.orgID, f.userID, f.recipeID)
	require.ErrorIs(t, err, ErrPlatformRecipe)
}

func TestImportLabset_Refusals(t *testing.T) {
	ctx := context.Background()

	t.Run("runtime mismatch", func(t *testing.T) {
		f := newImportFixture(t)
		_, err := f.svc.ImportLabset(ctx, f.writeLabset(t, runtimeA, "a"), ImportOptions{ExpectRuntimeID: runtimeB})
		require.ErrorIs(t, err, ErrLabsetRuntime)
		f.requireNothingWritten(t)
	})
	t.Run("tampered file", func(t *testing.T) {
		f := newImportFixture(t)
		dir := f.writeLabset(t, runtimeA, "a")
		ents, err := os.ReadDir(filepath.Join(dir, "bundles"))
		require.NoError(t, err)
		p := filepath.Join(dir, "bundles", ents[0].Name())
		data, err := os.ReadFile(p)
		require.NoError(t, err)
		data[len(data)-1] ^= 0xff
		require.NoError(t, os.WriteFile(p, data, 0o600))
		_, err = f.svc.ImportLabset(ctx, dir, ImportOptions{ExpectRuntimeID: runtimeA})
		require.ErrorIs(t, err, ErrLabsetCorrupt)
		f.requireNothingWritten(t)
	})
	t.Run("extra file", func(t *testing.T) {
		f := newImportFixture(t)
		dir := f.writeLabset(t, runtimeA, "a")
		require.NoError(t, os.WriteFile(filepath.Join(dir, "bundles", "planted.tar.gz"), []byte("x"), 0o600))
		_, err := f.svc.ImportLabset(ctx, dir, ImportOptions{ExpectRuntimeID: runtimeA})
		require.ErrorIs(t, err, ErrLabsetCorrupt)
	})
	t.Run("stale hash", func(t *testing.T) {
		f := newImportFixture(t)
		_, err := f.pool.Exec(ctx, `UPDATE lab_recipes SET spec = jsonb_set(spec, '{seed}', '987654') WHERE id = $1`, f.recipeID)
		require.NoError(t, err)
		_, err = f.svc.ImportLabset(ctx, f.writeLabset(t, runtimeA, "a"), ImportOptions{ExpectRuntimeID: runtimeA})
		require.ErrorIs(t, err, ErrBuildStale)
		f.requireNothingWritten(t)
	})
	t.Run("yanked block", func(t *testing.T) {
		f := newImportFixture(t)
		_, err := f.pool.Exec(ctx, `UPDATE lab_block_versions SET yanked_at = now(), yanked_reason = 'test' WHERE id = $1`, f.blockIDs[0])
		require.NoError(t, err)
		_, err = f.svc.ImportLabset(ctx, f.writeLabset(t, runtimeA, "a"), ImportOptions{ExpectRuntimeID: runtimeA})
		var inv *labauthor.InvalidRecipeError
		require.ErrorAs(t, err, &inv)
		f.requireNothingWritten(t)
	})
	t.Run("platform recipe without artifact", func(t *testing.T) {
		f := newImportFixture(t)
		dir := f.writeLabset(t, runtimeA, "a")
		f.addPlatformRecipe(t, "production-debugging/lab-other")
		_, err := f.svc.ImportLabset(ctx, dir, ImportOptions{ExpectRuntimeID: runtimeA})
		require.ErrorIs(t, err, ErrLabsetIncomplete)
		f.requireNothingWritten(t)
		_, err = f.svc.ImportLabset(ctx, dir, ImportOptions{ExpectRuntimeID: runtimeA, Partial: true})
		require.NoError(t, err)
	})
	t.Run("not a platform recipe here", func(t *testing.T) {
		f := newImportFixture(t)
		dir := f.writeLabset(t, runtimeA, "a")
		_, err := f.pool.Exec(ctx, `UPDATE lab_recipes SET is_platform = false WHERE id = $1`, f.recipeID)
		require.NoError(t, err)
		_, err = f.svc.ImportLabset(ctx, dir, ImportOptions{ExpectRuntimeID: runtimeA})
		require.ErrorIs(t, err, ErrLabsetRecipe)
	})
}

// requireNothingWritten: a refused import leaves no build, no publish, no catalog row.
func (f *importFixture) requireNothingWritten(t *testing.T) {
	t.Helper()
	var builds, catalog int
	var published bool
	require.NoError(t, f.pool.QueryRow(context.Background(), `SELECT (SELECT count(*) FROM lab_builds),
		(SELECT count(*) FROM lab_catalog_meta), (SELECT is_published FROM lab_definitions WHERE id = $1)`, f.labID).
		Scan(&builds, &catalog, &published))
	require.Zero(t, builds)
	require.Zero(t, catalog)
	require.False(t, published)
	for k := range f.store.objs {
		require.Failf(t, "uploaded before refusing", "%s", k)
	}
}
