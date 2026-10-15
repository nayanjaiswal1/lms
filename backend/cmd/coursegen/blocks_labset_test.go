package main

import (
	"archive/tar"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"sync"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
	"github.com/mindforge/backend/internal/labauthor"
	"github.com/mindforge/backend/internal/labblock"
	"github.com/mindforge/backend/internal/labbuild"
	"github.com/mindforge/backend/internal/storage"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

const (
	testBlocksDir  = "../../../content/lab-blocks"
	testCoursesDir = "../../../content/courses"
	testRecipe     = "../../../content/courses/production-debugging/recipes/dj-money-rounding.yaml"
	testRuntime    = "runtime-0123456789ab"
)

// fakeArtifacts stands in for VerifyLocal: one passing variant whose bundles
// are distinct per recipe hash.
func fakeArtifacts(ri recipeInput) (*labbuild.Report, []labbuild.VariantArtifact) {
	ws, gr, vf := []byte("ws-"+ri.analysis.RecipeHash), []byte("gr-"+ri.analysis.RecipeHash), []byte("vf-"+ri.analysis.RecipeHash)
	payload, _ := json.Marshal(map[string]any{"verify_bundle_key": storageKey(vf), "verify_bundle_sha256": sha(vf), "cheat_diffs": map[string]string{}})
	art := labbuild.VariantArtifact{
		Row: labbuild.VariantRow{Key: "v0", WorkspaceKey: storageKey(ws), WorkspaceSHA: sha(ws), GraderKey: storageKey(gr), GraderSHA: sha(gr),
			BriefMD: "brief", ProtectedManifest: json.RawMessage(`{}`), AppPorts: []int{}, Payload: payload},
		Workspace: ws, Grader: gr, Verify: vf,
	}
	rep := &labbuild.Report{RecipeHash: ri.analysis.RecipeHash, Difficulty: ri.analysis.Difficulty, VariantCount: 1,
		Variants: []labbuild.VariantReport{{Key: "v0", Passed: true}}}
	return rep, []labbuild.VariantArtifact{art}
}

func sha(b []byte) string {
	sum := sha256.Sum256(b)
	return hex.EncodeToString(sum[:])
}

// storageKey is the content address of b (what PutBundle would return).
func storageKey(b []byte) string { return storage.BundleKey(sha(b)) }

type discardStore struct{}

func (discardStore) Upload(context.Context, string, string, io.Reader, int64) error { return nil }
func (discardStore) Download(context.Context, string) ([]byte, error)               { return nil, nil }
func (discardStore) Delete(context.Context, string) error                           { return nil }
func (discardStore) List(context.Context, string) ([]storage.PrivateObject, error)  { return nil, nil }

// testInputs resolves the real recipe against the real block tree, with the
// recipe id the lab document under content/courses gives it.
func testInputs(t *testing.T) ([]recipeInput, map[string][]byte) {
	t.Helper()
	loaded, err := labauthor.LoadBlockTree(testBlocksDir)
	require.NoError(t, err)
	versions := map[string]*labblock.ResolvedBlock{}
	payloads := map[string][]byte{}
	for _, lb := range loaded {
		versions[lb.VersionID] = &labblock.ResolvedBlock{BlockID: lb.BlockID, VersionID: lb.VersionID, Key: lb.Manifest.ID,
			Version: lb.Manifest.Version, ContentHash: lb.ContentHash, Manifest: lb.Manifest}
		if lb.Payload != nil {
			payloads[lb.VersionID] = lb.Payload
		}
	}
	ids, err := platformRecipeIDs(testCoursesDir)
	require.NoError(t, err)
	ri, err := resolveRecipeFile(testRecipe, versions)
	require.NoError(t, err)
	abs, err := filepath.Abs(testRecipe)
	require.NoError(t, err)
	ri.ids = ids[abs]
	require.Equal(t, []string{canonical.LabRecipeID("production-debugging/lab-dj-money-rounding")}, ri.ids)
	return []recipeInput{ri}, payloads
}

func newTestBuild(t *testing.T, cache string, payloads map[string][]byte, calls *int) labsetBuild {
	var mu sync.Mutex
	return labsetBuild{cacheDir: cache, outDir: filepath.Join(t.TempDir(), "labset"), runtimeID: testRuntime, payloads: payloads,
		gitSHA: "abc", ciBuild: "7",
		verify: func(ri recipeInput) (*labbuild.Report, []labbuild.VariantArtifact, error) {
			mu.Lock()
			*calls++
			mu.Unlock()
			rep, arts := fakeArtifacts(ri)
			return rep, arts, nil
		}}
}

func TestLabsetBuild_ManifestAndCache(t *testing.T) {
	inputs, payloads := testInputs(t)
	cache := t.TempDir()
	calls := 0

	b := newTestBuild(t, cache, payloads, &calls)
	res, err := b.run(inputs)
	require.NoError(t, err)
	require.Equal(t, 1, res.verified)
	require.Equal(t, 1, calls)

	m, err := labbuild.ReadLabset(b.outDir)
	require.NoError(t, err)
	require.Equal(t, testRuntime, m.RuntimeID)
	require.Equal(t, "abc", m.GitSHA)
	require.Equal(t, "7", m.CIBuild)
	require.Len(t, m.Recipes, 1)
	r := m.Recipes[0]
	require.Equal(t, inputs[0].ids[0], r.RecipeID)
	require.Equal(t, inputs[0].analysis.RecipeHash, r.RecipeHash)
	require.Equal(t, blockVersionIDs(inputs[0].recipe), r.BlockVersionIDs)
	for _, v := range r.Variants {
		for _, sha := range []string{v.WorkspaceSHA, v.GraderSHA, v.VerifySHA} {
			require.Contains(t, m.Files, labbuild.LabsetBundlePath(sha))
		}
	}
	for _, id := range r.BlockVersionIDs {
		if p := payloads[id]; p != nil {
			require.Contains(t, m.Files, labbuild.LabsetBundlePath(sha(p)))
		}
	}
	raw, err := os.ReadFile(filepath.Join(b.outDir, labbuild.LabsetManifest))
	require.NoError(t, err)
	require.NotContains(t, string(raw), "org_id", "the importer derives ids; the labset carries none")

	// Second run, same cache: nothing verified, same manifest content.
	b2 := newTestBuild(t, cache, payloads, &calls)
	res, err = b2.run(inputs)
	require.NoError(t, err)
	require.Equal(t, 0, res.verified)
	require.Equal(t, 1, res.cached)
	require.Equal(t, 1, calls)
	m2, err := labbuild.ReadLabset(b2.outDir)
	require.NoError(t, err)
	require.Equal(t, m.Files, m2.Files)

	// Cached-only with an empty cache refuses instead of verifying.
	b3 := newTestBuild(t, t.TempDir(), payloads, &calls)
	b3.cachedOnly = true
	_, err = b3.run(inputs)
	require.ErrorContains(t, err, "failed verification")
	require.Equal(t, 1, calls)
	_, err = os.Stat(b3.outDir)
	require.True(t, errors.Is(err, os.ErrNotExist), "no labset written on failure")

	// A bundle edited after the fact fails the manifest check.
	ents, err := os.ReadDir(filepath.Join(b.outDir, "bundles"))
	require.NoError(t, err)
	require.NoError(t, os.WriteFile(filepath.Join(b.outDir, "bundles", ents[0].Name()), []byte("tampered"), 0o600))
	_, err = labbuild.ReadLabset(b.outDir)
	require.ErrorIs(t, err, labbuild.ErrLabsetCorrupt)
}

func TestExtractTarRejectsUnsafeEntries(t *testing.T) {
	for name, hdr := range map[string]*tar.Header{
		"escape":  {Name: "../evil", Typeflag: tar.TypeReg, Size: 1, Mode: 0o600},
		"abs":     {Name: "/etc/evil", Typeflag: tar.TypeReg, Size: 1, Mode: 0o600},
		"symlink": {Name: "bundles/x", Typeflag: tar.TypeSymlink, Linkname: "/etc/passwd"},
	} {
		t.Run(name, func(t *testing.T) {
			var buf bytes.Buffer
			tw := tar.NewWriter(&buf)
			require.NoError(t, tw.WriteHeader(hdr))
			if hdr.Size > 0 {
				_, err := tw.Write([]byte("x"))
				require.NoError(t, err)
			}
			require.NoError(t, tw.Close())
			require.Error(t, extractTar(&buf, t.TempDir(), 1<<20))
		})
	}
}

// End to end on a fixture: verify (faked) -> labset -> tar on stdin -> import.
func TestBlocksImport_FromTarOnStdin(t *testing.T) {
	ctx := context.Background()
	inputs, payloads := testInputs(t)
	calls := 0
	b := newTestBuild(t, t.TempDir(), payloads, &calls)
	_, err := b.run(inputs)
	require.NoError(t, err)

	pool := testdb.New(t)
	loaded, err := labauthor.LoadBlockTree(testBlocksDir)
	require.NoError(t, err)
	sql, err := labauthor.RenderSyncSQL(loaded)
	require.NoError(t, err)
	_, err = pool.Exec(ctx, sql)
	require.NoError(t, err)
	var orgID, userID string
	require.NoError(t, pool.QueryRow(ctx, `INSERT INTO organizations (slug, name) VALUES ('platform', 'Platform') RETURNING id`).Scan(&orgID))
	require.NoError(t, pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('author@`+testdomain.Domain+`', 'Author') RETURNING id`).Scan(&userID))
	rs, err := canonical.LoadRecipe(testRecipe)
	require.NoError(t, err)
	spec, err := rs.Spec()
	require.NoError(t, err)
	specJSON, err := json.Marshal(spec)
	require.NoError(t, err)
	labID := canonical.ID("production-debugging/lab-dj-money-rounding", "lab")
	_, err = pool.Exec(ctx, `INSERT INTO lab_definitions (id, org_id, scope, title, lab_type, environment, created_by)
		VALUES ($1, $2, 'standalone', 'Money rounding', 'debug', 'mindforge/lab-debug:1', $3)`, labID, orgID, userID)
	require.NoError(t, err)
	_, err = pool.Exec(ctx, `INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)
		VALUES ($1, $2, $3, $4, 'Money rounding', $5::jsonb, $6, true)`, inputs[0].ids[0], orgID, userID, rs.LabKind, specJSON, labID)
	require.NoError(t, err)

	var tarBuf bytes.Buffer
	tw := tar.NewWriter(&tarBuf)
	require.NoError(t, filepath.Walk(b.outDir, func(p string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return err
		}
		rel, _ := filepath.Rel(b.outDir, p)
		data, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		if err := tw.WriteHeader(&tar.Header{Name: "./" + filepath.ToSlash(rel), Typeflag: tar.TypeReg, Mode: 0o600, Size: int64(len(data))}); err != nil {
			return err
		}
		_, err = tw.Write(data)
		return err
	}))
	require.NoError(t, tw.Close())

	imp := labbuild.NewImporter(pool, discardStore{})
	require.Error(t, importLabsetFrom(ctx, imp, "-", bytes.NewReader(tarBuf.Bytes()), labbuild.ImportOptions{ExpectRuntimeID: "other-runtime-id"}))
	require.NoError(t, importLabsetFrom(ctx, imp, "-", bytes.NewReader(tarBuf.Bytes()), labbuild.ImportOptions{ExpectRuntimeID: testRuntime}))

	var published bool
	var catalog int
	require.NoError(t, pool.QueryRow(ctx, `SELECT is_published, (SELECT count(*) FROM lab_catalog_meta WHERE lab_id = $1)
		FROM lab_definitions WHERE id = $1`, labID).Scan(&published, &catalog))
	require.True(t, published)
	require.Equal(t, 1, catalog)
}

func TestPruneCacheKeepsOnlyCurrentEntries(t *testing.T) {
	cache := t.TempDir()
	hash := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	stale := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
	for _, name := range []string{hash + "-rt-current-1", hash + "-rt-old-0001", stale + "-rt-current-1", stale + "-rt-current-1.tmp-42", "notes"} {
		require.NoError(t, os.MkdirAll(filepath.Join(cache, name), 0o700))
	}
	inputs := []recipeInput{{analysis: &labauthor.Analysis{RecipeHash: hash}}, {}}

	n, err := pruneCache(cache, inputs, "rt-current-1")
	require.NoError(t, err)
	require.Equal(t, 2, n, "old runtime and stale hash go")

	var left []string
	ents, err := os.ReadDir(cache)
	require.NoError(t, err)
	for _, e := range ents {
		left = append(left, e.Name())
	}
	require.ElementsMatch(t, []string{hash + "-rt-current-1", stale + "-rt-current-1.tmp-42", "notes"}, left,
		"current entry kept; in-flight .tmp- write and unrelated dirs untouched")
}
