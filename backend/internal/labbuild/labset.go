package labbuild

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
)

// A labset is the release artifact of platform labs (docs/debug-labs.md B5
// "Platform course content"): CI renders and verifies every platform recipe
// offline (`coursegen blocks verify --artifact`), and each environment imports
// the result (`coursegen blocks import`, ImportLabset) instead of building in
// the app. Layout:
//
//	manifest.json             LabsetManifest
//	bundles/<sha256>.tar.gz   variant bundles + block payloads, content-addressed
//
// The labset is SECRET: bundles carry graders and fix/cheat overlays and the
// manifest carries root causes, fix and cheat diffs. Never publish or archive it.
const (
	LabsetSchema   = 1
	LabsetManifest = "manifest.json"
	labsetBundles  = "bundles"
)

// ErrLabsetCorrupt means a labset failed its own integrity check (unknown
// schema, a file missing, extra or not matching its sha256).
var ErrLabsetCorrupt = errors.New("labbuild: labset is corrupt")

// Labset is manifest.json. It deliberately has no org, build, lab or task
// version ids: the importer derives them from the target database.
type Labset struct {
	Schema    int    `json:"schema"`
	RuntimeID string `json:"runtime_id"`
	GitSHA    string `json:"git_sha"`
	CIBuild   string `json:"ci_build"`
	// Files is the sha256 of every file in the labset except manifest.json.
	Files   map[string]string `json:"files"`
	Recipes []LabsetRecipe    `json:"recipes"`
}

// LabsetRecipe is one verified platform recipe.
type LabsetRecipe struct {
	RecipeID          string          `json:"recipe_id"`
	RecipeHash        string          `json:"recipe_hash"`
	LabKind           string          `json:"lab_kind"`
	DerivedDifficulty string          `json:"derived_difficulty"`
	BlockVersionIDs   []string        `json:"block_version_ids"`
	Report            Report          `json:"report"`
	Variants          []LabsetVariant `json:"variants"`
}

// LabsetVariant is a lab_build_variants row with its bundles by sha256
// (payload includes verify_bundle_*, captures and cheat_diffs, as stored).
type LabsetVariant struct {
	Key               string          `json:"key"`
	BriefMD           string          `json:"brief_md"`
	ProtectedManifest json.RawMessage `json:"protected_manifest"`
	AppPorts          []int           `json:"app_ports"`
	Payload           json.RawMessage `json:"payload"`
	WorkspaceSHA      string          `json:"workspace_sha256"`
	GraderSHA         string          `json:"grader_sha256"`
	VerifySHA         string          `json:"verify_sha256"`
}

// LabsetRecipeFrom shapes a passing VerifyLocal result. blockVersionIDs are the
// recipe's resolved blocks (lab_block_usages).
func LabsetRecipeFrom(labKind string, blockVersionIDs []string, rep *Report, arts []VariantArtifact) LabsetRecipe {
	r := LabsetRecipe{RecipeHash: rep.RecipeHash, LabKind: labKind, DerivedDifficulty: rep.Difficulty,
		BlockVersionIDs: append([]string(nil), blockVersionIDs...), Report: *rep}
	for _, a := range arts {
		var vf VerifyBundle
		_ = json.Unmarshal(a.Row.Payload, &vf) // shaped by variantRowFrom
		r.Variants = append(r.Variants, LabsetVariant{
			Key: a.Row.Key, BriefMD: a.Row.BriefMD, ProtectedManifest: a.Row.ProtectedManifest, AppPorts: a.Row.AppPorts,
			Payload: a.Row.Payload, WorkspaceSHA: a.Row.WorkspaceSHA, GraderSHA: a.Row.GraderSHA, VerifySHA: vf.SHA,
		})
	}
	return r
}

// Passed reports whether every variant of a build verified.
func (r *Report) Passed() bool {
	if r.Error != "" || len(r.Variants) == 0 {
		return false
	}
	for _, v := range r.Variants {
		if !v.Passed {
			return false
		}
	}
	return true
}

// LabsetBundlePath is a bundle's path relative to the labset root.
func LabsetBundlePath(sha string) string { return labsetBundles + "/" + sha + ".tar.gz" }

// WriteLabsetBundle writes data under dir as its content-addressed bundle.
func WriteLabsetBundle(dir string, data []byte) error {
	p := filepath.Join(dir, filepath.FromSlash(LabsetBundlePath(sha256Hex(data))))
	if err := os.MkdirAll(filepath.Dir(p), 0o700); err != nil {
		return fmt.Errorf("labbuild.WriteLabsetBundle: %w", err)
	}
	if err := os.WriteFile(p, data, 0o600); err != nil {
		return fmt.Errorf("labbuild.WriteLabsetBundle: %w", err)
	}
	return nil
}

// WriteLabsetManifest hashes every file already under dir into m.Files and
// writes manifest.json. Call it last.
func WriteLabsetManifest(dir string, m *Labset) error {
	m.Schema = LabsetSchema
	files, err := hashTree(dir)
	if err != nil {
		return fmt.Errorf("labbuild.WriteLabsetManifest: %w", err)
	}
	m.Files = files
	sort.Slice(m.Recipes, func(i, j int) bool { return m.Recipes[i].RecipeID < m.Recipes[j].RecipeID })
	raw, err := json.MarshalIndent(m, "", "  ")
	if err != nil {
		return fmt.Errorf("labbuild.WriteLabsetManifest: %w", err)
	}
	if err := os.WriteFile(filepath.Join(dir, LabsetManifest), raw, 0o600); err != nil {
		return fmt.Errorf("labbuild.WriteLabsetManifest: %w", err)
	}
	return nil
}

// ReadLabset parses dir's manifest and checks the labset is exactly what the
// manifest says: every listed file present with its sha256, nothing extra.
func ReadLabset(dir string) (*Labset, error) {
	raw, err := os.ReadFile(filepath.Join(dir, LabsetManifest))
	if err != nil {
		return nil, fmt.Errorf("labbuild.ReadLabset: %w", err)
	}
	var m Labset
	if err := json.Unmarshal(raw, &m); err != nil {
		return nil, fmt.Errorf("%w: manifest: %v", ErrLabsetCorrupt, err)
	}
	if m.Schema != LabsetSchema {
		return nil, fmt.Errorf("%w: schema %d, want %d", ErrLabsetCorrupt, m.Schema, LabsetSchema)
	}
	got, err := hashTree(dir)
	if err != nil {
		return nil, fmt.Errorf("labbuild.ReadLabset: %w", err)
	}
	for name, sha := range m.Files {
		if got[name] != sha {
			return nil, fmt.Errorf("%w: %s is missing or does not match its sha256", ErrLabsetCorrupt, name)
		}
	}
	for name := range got {
		if _, ok := m.Files[name]; !ok {
			return nil, fmt.Errorf("%w: %s is not in the manifest", ErrLabsetCorrupt, name)
		}
	}
	return &m, nil
}

// RuntimeStampPath is where a lab image carries its runtime id; CI and the
// import script read it with `docker run --entrypoint cat`, never from a pod.
const RuntimeStampPath = runtimeStampPath

// CopyLabsetBundle copies bundle sha from one labset-shaped directory (a labset
// or a verify cache entry) to another, refusing content that does not match sha.
func CopyLabsetBundle(fromDir, toDir, sha string) error {
	data, err := os.ReadFile(filepath.Join(fromDir, filepath.FromSlash(LabsetBundlePath(sha))))
	if err != nil {
		return fmt.Errorf("labbuild.CopyLabsetBundle: %w", err)
	}
	if sha256Hex(data) != sha {
		return fmt.Errorf("%w: %s in %s does not match its sha256", ErrLabsetCorrupt, sha, fromDir)
	}
	return WriteLabsetBundle(toDir, data)
}

// readBundle reads a bundle the manifest lists (ReadLabset verified it).
func (m *Labset) readBundle(dir, sha string) ([]byte, error) {
	rel := LabsetBundlePath(sha)
	if _, ok := m.Files[rel]; !ok {
		return nil, fmt.Errorf("%w: bundle %s is not in the labset", ErrLabsetCorrupt, sha)
	}
	data, err := os.ReadFile(filepath.Join(dir, filepath.FromSlash(rel)))
	if err != nil {
		return nil, fmt.Errorf("labbuild.Labset.readBundle: %w", err)
	}
	if sha256Hex(data) != sha {
		return nil, fmt.Errorf("%w: bundle %s changed after it was checked", ErrLabsetCorrupt, sha)
	}
	return data, nil
}

// hashTree returns sha256 of every regular file under dir except the manifest,
// keyed by slash-separated relative path. Anything that is not a regular file
// or directory (a symlink, a device) is rejected.
func hashTree(dir string) (map[string]string, error) {
	out := map[string]string{}
	err := filepath.WalkDir(dir, func(p string, d fs.DirEntry, werr error) error {
		if werr != nil {
			return werr
		}
		if d.IsDir() {
			return nil
		}
		rel, err := filepath.Rel(dir, p)
		if err != nil {
			return err
		}
		rel = filepath.ToSlash(rel)
		if rel == LabsetManifest {
			return nil
		}
		if !d.Type().IsRegular() {
			return fmt.Errorf("%w: %s is not a regular file", ErrLabsetCorrupt, rel)
		}
		data, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		out[rel] = sha256Hex(data)
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("labbuild.hashTree: %w", err)
	}
	return out, nil
}
