package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"

	"gopkg.in/yaml.v3"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
	"github.com/mindforge/backend/internal/labauthor"
	"github.com/mindforge/backend/internal/labblock"
	"github.com/mindforge/backend/internal/labbuild"
	"github.com/mindforge/backend/internal/labkinds"
	"github.com/mindforge/backend/internal/labs"
)

// verifyTimeout bounds one recipe's whole render + matrix.
const verifyTimeout = 60 * time.Minute

// debugLabImage is the local debug-lab image (built by scripts/push-lab-images.sh).
const debugLabImage = "mindforge/lab-debug:1"

// defaultCoursesDir is the canonical course tree whose lab documents name the
// platform recipes (and so their deterministic recipe ids).
const defaultCoursesDir = "../content/courses"

// cacheRecipeFile is a verify-cache entry's recipe (a LabsetRecipe without id).
const cacheRecipeFile = "recipe.json"

// runtimeIDRe is what a runtime stamp must look like to name a cache entry.
var runtimeIDRe = regexp.MustCompile(`^[A-Za-z0-9._-]{8,128}$`)

// recipeInput is one recipe file resolved against the block tree.
type recipeInput struct {
	path     string
	ids      []string // lab_recipes ids of the lab documents using it (labset mode)
	recipe   *labblock.Recipe
	analysis *labauthor.Analysis
	issues   []labblock.Issue
}

// runBlocksVerify builds and verifies recipes against the local block tree in
// local Docker (labbuild.VerifyLocal). With --artifact it writes a labset (the
// platform-lab release artifact ImportLabset imports), reusing --cache entries
// so an unchanged recipe on an unchanged lab runtime is never verified twice.
func runBlocksVerify(args []string) error {
	fs := newFlagSet("blocks verify")
	in := fs.String("in", defaultBlocksDir, "block tree")
	parallel := fs.Int("parallel", 4, "concurrent clean-room sandboxes")
	reportPath := fs.String("report", "", "write the JSON reports to this file")
	outDir := fs.String("out", "", "keep each variant's renderer output under DIR/<recipe>/<variant>/")
	artifact := fs.String("artifact", "", "write a labset (manifest.json + bundles/) to this new or empty directory")
	cacheDir := fs.String("cache", "", "verified-recipe cache: entries <recipe_hash>-<runtime_id> are reused, not re-verified")
	cachedOnly := fs.Bool("cached-only", false, "with --artifact: assemble from --cache only (no Docker); fail if a recipe is not cached")
	prune := fs.Bool("prune", false, "with --artifact and --cache and no recipe arguments: after success, delete cache entries not used by the current recipes and runtime")
	runtimeID := fs.String("runtime-id", "", "lab runtime stamp the labset is for (default: read from the local lab image)")
	coursesDir := fs.String("courses", defaultCoursesDir, "canonical course tree mapping recipe files to platform recipe ids")
	gitSHA := fs.String("git-sha", os.Getenv("GIT_COMMIT"), "source commit recorded in the labset")
	ciBuild := fs.String("ci-build", os.Getenv("BUILD_NUMBER"), "CI build number recorded in the labset")
	if err := fs.Parse(args); err != nil {
		return err
	}
	labset := *artifact != ""
	if *cachedOnly && (!labset || *cacheDir == "") {
		return fmt.Errorf("blocks verify: --cached-only needs --artifact and --cache")
	}
	if *prune && (!labset || *cacheDir == "" || fs.NArg() > 0) {
		return fmt.Errorf("blocks verify: --prune needs --artifact and --cache and verifies every platform recipe (no recipe arguments), otherwise it would delete entries other recipes still need")
	}
	if (*cacheDir != "" || *runtimeID != "") && !labset {
		return fmt.Errorf("blocks verify: --cache and --runtime-id only apply with --artifact")
	}

	loaded, err := labauthor.LoadBlockTree(*in)
	if err != nil {
		return fmt.Errorf("blocks verify: load block tree: %w", err)
	}
	versions := map[string]*labblock.ResolvedBlock{}
	payloads := map[string][]byte{}
	for _, lb := range loaded {
		versions[lb.VersionID] = &labblock.ResolvedBlock{
			BlockID: lb.BlockID, VersionID: lb.VersionID, Key: lb.Manifest.ID, Version: lb.Manifest.Version,
			ContentHash: lb.ContentHash, Manifest: lb.Manifest,
		}
		if lb.Payload != nil {
			payloads[lb.VersionID] = lb.Payload
		}
	}

	paths := fs.Args()
	var ids map[string][]string
	if labset {
		if ids, err = platformRecipeIDs(*coursesDir); err != nil {
			return fmt.Errorf("blocks verify: %w", err)
		}
		if len(paths) == 0 {
			for p := range ids {
				paths = append(paths, p)
			}
			sort.Strings(paths)
		}
	}
	if len(paths) == 0 {
		return fmt.Errorf("%s", blocksUsage)
	}
	inputs := make([]recipeInput, 0, len(paths))
	for _, path := range paths {
		ri, err := resolveRecipeFile(path, versions)
		if err != nil {
			return fmt.Errorf("%s: %w", path, err)
		}
		if labset {
			abs, err := filepath.Abs(path)
			if err != nil {
				return fmt.Errorf("blocks verify: %w", err)
			}
			if ri.ids = ids[abs]; len(ri.ids) == 0 {
				return fmt.Errorf("blocks verify: %s is not the recipe of any lab document under %s", path, *coursesDir)
			}
		}
		inputs = append(inputs, ri)
	}

	var rt labs.ContainerRuntime
	if !*cachedOnly {
		rt = labs.NewDockerContainerService(map[string]labs.ImageProfile{debugLabImage: labs.DebugIDEProfile()})
	}
	verify := func(ri recipeInput) (*labbuild.Report, []labbuild.VariantArtifact, error) {
		fmt.Printf("== %s\n", ri.path)
		return verifyRecipe(rt, ri, payloads, *parallel, *outDir)
	}

	if !labset {
		reports := map[string]*labbuild.Report{}
		var failed []string
		for _, ri := range inputs {
			rep, _, err := verify(ri)
			if err != nil {
				return fmt.Errorf("%s: %w", ri.path, err)
			}
			reports[ri.path] = rep
			if !rep.Passed() {
				failed = append(failed, ri.path)
			}
			printReport(rep)
		}
		if err := writeReports(*reportPath, reports); err != nil {
			return err
		}
		if len(failed) > 0 {
			return fmt.Errorf("%d of %d recipe(s) failed verification: %s", len(failed), len(inputs), strings.Join(failed, ", "))
		}
		fmt.Printf("coursegen blocks verify: %d recipe(s) verified\n", len(inputs))
		return nil
	}

	if *runtimeID == "" {
		if *runtimeID, err = imageRuntimeID(inputs); err != nil {
			return fmt.Errorf("blocks verify: %w", err)
		}
	}
	cache := *cacheDir
	if cache == "" {
		tmp, err := os.MkdirTemp("", "mf-labset-cache-")
		if err != nil {
			return fmt.Errorf("blocks verify: %w", err)
		}
		defer os.RemoveAll(tmp)
		cache = tmp
	}
	b := labsetBuild{cacheDir: cache, outDir: *artifact, runtimeID: *runtimeID, cachedOnly: *cachedOnly, verify: verify,
		payloads: payloads, gitSHA: *gitSHA, ciBuild: *ciBuild}
	if b.gitSHA == "" {
		b.gitSHA = gitHead()
	}
	if b.ciBuild == "" {
		b.ciBuild = "local"
	}
	res, err := b.run(inputs)
	if res != nil {
		if werr := writeReports(*reportPath, res.reports); werr != nil {
			return werr
		}
	}
	if err != nil {
		return err
	}
	fmt.Printf("coursegen blocks verify: labset %s: %d recipe(s), %d verified now, %d from cache (runtime %.12s)\n",
		*artifact, len(inputs), res.verified, res.cached, *runtimeID)
	if *prune {
		n, err := pruneCache(cache, inputs, *runtimeID)
		if err != nil {
			return err
		}
		fmt.Printf("coursegen blocks verify: pruned %d unused cache entr%s\n", n, map[bool]string{true: "y", false: "ies"}[n == 1])
	}
	return nil
}

// labsetBuild assembles a labset from the verify cache, verifying (and caching)
// only the recipes that are not cached yet.
type labsetBuild struct {
	cacheDir, outDir, runtimeID string
	cachedOnly                  bool
	verify                      func(recipeInput) (*labbuild.Report, []labbuild.VariantArtifact, error)
	payloads                    map[string][]byte // block version id -> payload tar.gz
	gitSHA, ciBuild             string
}

type labsetResult struct {
	verified, cached int
	reports          map[string]*labbuild.Report
}

func (b labsetBuild) run(inputs []recipeInput) (*labsetResult, error) {
	if !runtimeIDRe.MatchString(b.runtimeID) {
		return nil, fmt.Errorf("blocks verify: runtime id %q is not a lab image stamp", b.runtimeID)
	}
	if err := requireEmptyDir(b.outDir); err != nil {
		return nil, err
	}
	res := &labsetResult{reports: map[string]*labbuild.Report{}}
	entries := make([]string, len(inputs))
	recipes := make([]labbuild.LabsetRecipe, len(inputs))
	var failed []string
	for i, ri := range inputs {
		if ri.analysis == nil || !ri.analysis.Valid {
			rep := &labbuild.Report{Error: "the recipe does not resolve or validate", Issues: ri.issues}
			if ri.analysis != nil {
				rep.Issues = append(rep.Issues, ri.analysis.Issues...)
			}
			fmt.Printf("== %s\n", ri.path)
			printReport(rep)
			res.reports[ri.path], failed = rep, append(failed, ri.path)
			continue
		}
		entry := filepath.Join(b.cacheDir, ri.analysis.RecipeHash+"-"+b.runtimeID)
		raw, err := os.ReadFile(filepath.Join(entry, cacheRecipeFile))
		switch {
		case err == nil:
			if err := json.Unmarshal(raw, &recipes[i]); err != nil {
				return res, fmt.Errorf("blocks verify: cache entry %s: %w (delete it)", entry, err)
			}
			entries[i] = entry
			res.cached++
			res.reports[ri.path] = &recipes[i].Report
			fmt.Printf("== %s: cached (%.12s)\n", ri.path, ri.analysis.RecipeHash)
			continue
		case !errors.Is(err, fs.ErrNotExist):
			return res, fmt.Errorf("blocks verify: %w", err)
		case b.cachedOnly:
			fmt.Printf("== %s: not in the cache (%.12s-%.12s)\n", ri.path, ri.analysis.RecipeHash, b.runtimeID)
			failed = append(failed, ri.path)
			continue
		}
		rep, arts, err := b.verify(ri)
		if err != nil {
			return res, fmt.Errorf("%s: %w", ri.path, err)
		}
		res.reports[ri.path] = rep
		printReport(rep)
		res.verified++
		if !rep.Passed() {
			failed = append(failed, ri.path)
			continue
		}
		recipes[i] = labbuild.LabsetRecipeFrom(ri.recipe.LabKind, blockVersionIDs(ri.recipe), rep, arts)
		if err := writeCacheEntry(entry, recipes[i], arts); err != nil {
			return res, err
		}
		entries[i] = entry
	}
	if len(failed) > 0 {
		return res, fmt.Errorf("%d of %d recipe(s) failed verification, no labset written: %s", len(failed), len(inputs), strings.Join(failed, ", "))
	}

	if err := os.MkdirAll(b.outDir, 0o700); err != nil {
		return res, fmt.Errorf("blocks verify: %w", err)
	}
	m := &labbuild.Labset{RuntimeID: b.runtimeID, GitSHA: b.gitSHA, CIBuild: b.ciBuild}
	for i, ri := range inputs {
		for _, v := range recipes[i].Variants {
			for _, sha := range []string{v.WorkspaceSHA, v.GraderSHA, v.VerifySHA} {
				if err := labbuild.CopyLabsetBundle(entries[i], b.outDir, sha); err != nil {
					return res, fmt.Errorf("blocks verify: %w (delete cache entry %s)", err, entries[i])
				}
			}
		}
		for _, id := range recipes[i].BlockVersionIDs {
			if p := b.payloads[id]; p != nil {
				if err := labbuild.WriteLabsetBundle(b.outDir, p); err != nil {
					return res, fmt.Errorf("blocks verify: %w", err)
				}
			}
		}
		for _, id := range ri.ids {
			r := recipes[i]
			r.RecipeID = id
			m.Recipes = append(m.Recipes, r)
		}
	}
	if err := labbuild.WriteLabsetManifest(b.outDir, m); err != nil {
		return res, fmt.Errorf("blocks verify: %w", err)
	}
	return res, nil
}

// writeCacheEntry stores a verified recipe under entry, atomically (a crashed
// run never leaves a half-written entry that later runs would trust).
func writeCacheEntry(entry string, r labbuild.LabsetRecipe, arts []labbuild.VariantArtifact) error {
	tmp := fmt.Sprintf("%s.tmp-%d", entry, os.Getpid())
	if err := os.RemoveAll(tmp); err != nil {
		return fmt.Errorf("blocks verify: cache: %w", err)
	}
	for _, a := range arts {
		for _, data := range [][]byte{a.Workspace, a.Grader, a.Verify} {
			if err := labbuild.WriteLabsetBundle(tmp, data); err != nil {
				return fmt.Errorf("blocks verify: cache: %w", err)
			}
		}
	}
	raw, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		return fmt.Errorf("blocks verify: cache: %w", err)
	}
	if err := os.WriteFile(filepath.Join(tmp, cacheRecipeFile), raw, 0o600); err != nil {
		return fmt.Errorf("blocks verify: cache: %w", err)
	}
	if err := os.Rename(tmp, entry); err != nil {
		return fmt.Errorf("blocks verify: cache: %w", err)
	}
	return nil
}

// cacheEntryRe matches verify-cache entry names (<recipe_hash>-<runtime_id>); anything else in the
// cache directory, including in-flight ".tmp-" writes, is left alone.
var cacheEntryRe = regexp.MustCompile(`^[0-9a-f]{16,}-[A-Za-z0-9_-][A-Za-z0-9._-]{7,127}$`)

// pruneCache removes cache entries that no current recipe uses for runtimeID: a cache hit never
// changes an entry, so age says nothing about whether it is still needed. Only call it after a run
// that covered every platform recipe (an entry for a recipe that was not in inputs would be lost).
func pruneCache(cacheDir string, inputs []recipeInput, runtimeID string) (int, error) {
	keep := map[string]bool{}
	for _, ri := range inputs {
		if ri.analysis != nil {
			keep[ri.analysis.RecipeHash+"-"+runtimeID] = true
		}
	}
	ents, err := os.ReadDir(cacheDir)
	if err != nil {
		return 0, fmt.Errorf("blocks verify: prune: %w", err)
	}
	pruned := 0
	for _, e := range ents {
		if !e.IsDir() || strings.Contains(e.Name(), ".tmp-") || !cacheEntryRe.MatchString(e.Name()) || keep[e.Name()] {
			continue
		}
		if err := os.RemoveAll(filepath.Join(cacheDir, e.Name())); err != nil {
			return pruned, fmt.Errorf("blocks verify: prune: %w", err)
		}
		pruned++
	}
	return pruned, nil
}

func requireEmptyDir(dir string) error {
	ents, err := os.ReadDir(dir)
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("blocks verify: %w", err)
	}
	if len(ents) > 0 {
		return fmt.Errorf("blocks verify: --artifact %s must be a new or empty directory", dir)
	}
	return nil
}

func blockVersionIDs(r *labblock.Recipe) []string {
	out := make([]string, 0, len(r.Blocks))
	for _, b := range r.Blocks {
		out = append(out, b.VersionID)
	}
	return out
}

// platformRecipeIDs maps each recipe file (absolute path) to the lab_recipes
// ids of the lab documents under dir that use it (canonical.LabRecipeID).
func platformRecipeIDs(dir string) (map[string][]string, error) {
	out := map[string][]string{}
	err := filepath.WalkDir(dir, func(p string, d fs.DirEntry, werr error) error {
		if werr != nil {
			return werr
		}
		if d.IsDir() || !strings.HasSuffix(p, ".md") {
			return nil
		}
		raw, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		fm, _, err := canonical.SplitFrontmatter(raw)
		if err != nil {
			return nil // not a canonical document
		}
		var doc struct {
			Kind   string `yaml:"kind"`
			IDKey  string `yaml:"id_key"`
			Recipe string `yaml:"recipe"`
		}
		if err := yaml.Unmarshal(fm, &doc); err != nil || doc.Kind != string(canonical.KindLab) || doc.Recipe == "" {
			return nil
		}
		abs, err := filepath.Abs(filepath.Join(filepath.Dir(p), doc.Recipe))
		if err != nil {
			return err
		}
		out[abs] = append(out[abs], canonical.LabRecipeID(doc.IDKey))
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("platformRecipeIDs: %w", err)
	}
	return out, nil
}

// imageRuntimeID reads the runtime stamp of the local image the recipes'
// lab kind runs in. A labset is for exactly one runtime.
func imageRuntimeID(inputs []recipeInput) (string, error) {
	id := ""
	for _, ri := range inputs {
		kind, ok := labkinds.Get(ri.recipe.LabKind)
		if !ok {
			return "", fmt.Errorf("%s: unknown lab kind %q", ri.path, ri.recipe.LabKind)
		}
		out, err := exec.Command("docker", "run", "--rm", "--entrypoint", "cat", kind.Image(), labbuild.RuntimeStampPath).Output()
		if err != nil {
			return "", fmt.Errorf("read the runtime stamp of %s (build it first: scripts/push-lab-images.sh): %w", kind.Image(), err)
		}
		got := strings.TrimSpace(string(out))
		if id != "" && got != id {
			return "", fmt.Errorf("recipes span lab runtimes %s and %s; a labset holds one", id, got)
		}
		id = got
	}
	return id, nil
}

// gitHead is the checked-out commit, or "unknown" outside a git work tree.
func gitHead() string {
	out, err := exec.Command("git", "rev-parse", "HEAD").Output()
	if err != nil {
		return "unknown"
	}
	return strings.TrimSpace(string(out))
}

func resolveRecipeFile(path string, versions map[string]*labblock.ResolvedBlock) (recipeInput, error) {
	ri := recipeInput{path: path}
	rs, err := canonical.LoadRecipe(path)
	if err != nil {
		return ri, err
	}
	spec, err := rs.Spec()
	if err != nil {
		return ri, err
	}
	recipe, issues := labauthor.BuildRecipe(rs.LabKind, "", spec, versions)
	ri.recipe = recipe
	if len(issues) > 0 {
		ri.issues = issues
		return ri, nil
	}
	ri.analysis = labauthor.Analyze(recipe)
	return ri, nil
}

func verifyRecipe(rt labs.ContainerRuntime, ri recipeInput, payloads map[string][]byte, parallel int, outDir string) (*labbuild.Report, []labbuild.VariantArtifact, error) {
	if ri.analysis == nil {
		return &labbuild.Report{Error: "the recipe does not resolve against the block tree", Issues: ri.issues}, nil, nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), verifyTimeout)
	defer cancel()
	opts := labbuild.LocalOptions{
		Parallel: parallel,
		OnRun: func(variant string, rr labbuild.RunReport) {
			fmt.Printf("   [%s] %-22s %s\n", variant, rr.Name, passWord(rr.Passed))
		},
	}
	if outDir != "" {
		base := filepath.Join(outDir, strings.TrimSuffix(filepath.Base(ri.path), filepath.Ext(ri.path)))
		opts.OnRendered = func(variant string, files map[string][]byte) error {
			dir := filepath.Join(base, variant)
			if err := os.MkdirAll(dir, 0o755); err != nil {
				return err
			}
			for name, data := range files {
				if err := os.WriteFile(filepath.Join(dir, filepath.Base(name)), data, 0o644); err != nil {
					return err
				}
			}
			return nil
		}
	}
	return labbuild.VerifyLocal(ctx, rt, ri.recipe, ri.analysis, payloads, opts)
}

func writeReports(path string, reports map[string]*labbuild.Report) error {
	if path == "" {
		return nil
	}
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetIndent("", "  ")
	if err := enc.Encode(reports); err != nil {
		return fmt.Errorf("blocks verify: %w", err)
	}
	if err := os.WriteFile(path, buf.Bytes(), 0o644); err != nil {
		return fmt.Errorf("blocks verify: %w", err)
	}
	return nil
}

// printReport prints the failures of a report (passes were streamed by OnRun).
func printReport(rep *labbuild.Report) {
	if rep.Error != "" {
		fmt.Printf("   ERROR %s\n", rep.Error)
	}
	for _, is := range rep.Issues {
		fmt.Printf("   ISSUE %s [%s] %s: %s\n", is.Severity, is.Code, is.Block, is.Message)
	}
	for _, v := range rep.Variants {
		for _, r := range v.Runs {
			for _, f := range r.Failures {
				fmt.Printf("   [%s] %s: %s\n", v.Key, r.Name, f)
			}
			if !r.Passed && r.StderrTail != "" {
				fmt.Printf("   [%s] %s stderr: %s\n", v.Key, r.Name, r.StderrTail)
			}
		}
		if v.CaptureNote != "" {
			fmt.Printf("   [%s] capture: %s\n", v.Key, v.CaptureNote)
		}
	}
	fmt.Printf("   => %s (hash %.12s, difficulty %s, %d variant(s))\n", passWord(rep.Passed()), rep.RecipeHash, rep.Difficulty, rep.VariantCount)
}

func passWord(ok bool) string {
	if ok {
		return "PASS"
	}
	return "FAIL"
}
