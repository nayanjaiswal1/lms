package labbuild

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sync"

	"github.com/mindforge/backend/internal/labauthor"
	"github.com/mindforge/backend/internal/labblock"
	"github.com/mindforge/backend/internal/labkinds"
	"github.com/mindforge/backend/internal/labs"
)

// LocalOptions tunes VerifyLocal.
type LocalOptions struct {
	// Parallel bounds concurrent clean-room sandboxes (default 1).
	Parallel int
	// OnRun, when set, is called after each finished run (progress output).
	OnRun func(variant string, rr RunReport)
	// OnRendered, when set, receives each variant's renderer output files
	// (workspace.tar.gz, grader.tar.gz, verify.tar.gz, meta.json) before verification.
	OnRendered func(variant string, files map[string][]byte) error
}

// VerifyLocal renders and verifies a resolved recipe exactly like the
// lab.recipe_build + lab.recipe_verify jobs (same renderer input, renderer,
// verification matrix, clean-room grade and expectations), but with block
// payloads read from the repo tree and no database, bundle store or metering:
// the CI/authoring check behind `coursegen blocks verify`.
//
// payloads maps a block version id to its payload tar.gz (labauthor.LoadedBlock.Payload).
func VerifyLocal(ctx context.Context, rt labs.ContainerRuntime, recipe *labblock.Recipe, an *labauthor.Analysis, payloads map[string][]byte, opts LocalOptions) (*Report, error) {
	kind, ok := labkinds.Get(recipe.LabKind)
	if !ok {
		return nil, fmt.Errorf("labbuild.VerifyLocal: unknown lab kind %q", recipe.LabKind)
	}
	if !an.Valid || an.RecipeHash == "" {
		return &Report{Error: "the recipe does not validate", Issues: an.Issues}, nil
	}
	rep := &Report{RecipeHash: an.RecipeHash, Difficulty: an.Difficulty}
	variants, _, err := labauthor.EnumerateVariants(recipe)
	if err != nil {
		return nil, fmt.Errorf("labbuild.VerifyLocal: %w", err)
	}
	bp := map[string]*blockPayload{}
	for i, blk := range recipe.Blocks {
		raw, ok := payloads[blk.VersionID]
		if !ok {
			continue
		}
		p, err := newBlockPayload(i, blk, raw)
		if err != nil {
			return contentReport(rep, err)
		}
		bp[blk.VersionID] = p
	}
	res := &resolved{Recipe: recipe, Analysis: an, Kind: kind}
	input, err := buildRendererInput(res, an.RecipeHash, variants, bp)
	if err != nil {
		return contentReport(rep, err)
	}
	rendered, err := renderInSandbox(ctx, rt, kind.Image(), "local-"+an.RecipeHash[:16], input, variants)
	if err != nil {
		return contentReport(rep, err)
	}
	rep.VariantCount = len(rendered)

	grade := func(ctx context.Context, target labs.GradeTarget, v *labkinds.VariantView, overlay []byte, modes []string, seed string) (map[string]*labs.GradeResult, error) {
		return labs.GradeModesInSandbox(ctx, rt, target, v, overlay, modes, seed)
	}
	for _, a := range rendered {
		if opts.OnRendered != nil {
			if err := opts.OnRendered(a.Key, a.Files); err != nil {
				return nil, fmt.Errorf("labbuild.VerifyLocal: %w", err)
			}
		}
		vr, err := verifyRenderedLocal(ctx, rt, grade, kind, an.RecipeHash, a, opts)
		if err != nil {
			return contentReport(rep, err)
		}
		rep.Variants = append(rep.Variants, *vr)
	}
	return rep, nil
}

// contentReport turns a content error into a failed report; anything else is returned.
func contentReport(rep *Report, err error) (*Report, error) {
	var ce *contentError
	if errors.As(err, &ce) {
		rep.Error, rep.Issues = ce.msg, ce.issues
		return rep, nil
	}
	return nil, err
}

// verifyRenderedLocal runs one rendered variant's whole matrix.
func verifyRenderedLocal(ctx context.Context, rt labs.ContainerRuntime, grade gradeFunc, kind labkinds.Kind, recipeHash string, a renderedVariant, opts LocalOptions) (*VariantReport, error) {
	if err := a.checkBudgets(); err != nil {
		return nil, err
	}
	var m meta
	if err := json.Unmarshal(a.Files["meta.json"], &m); err != nil {
		return nil, fmt.Errorf("labbuild.verifyRenderedLocal: meta: %w", err)
	}
	payload, err := json.Marshal(m.Payload)
	if err != nil {
		return nil, fmt.Errorf("labbuild.verifyRenderedLocal: payload: %w", err)
	}
	overlays, err := overlaysFromVerifyTar(a.Files["verify.tar.gz"])
	if err != nil {
		return nil, err
	}
	bundles := &variantBundles{
		view: &labkinds.VariantView{VariantKey: a.Key, WorkspaceBundle: a.Files["workspace.tar.gz"], GraderBundle: a.Files["grader.tar.gz"],
			BriefMD: m.BriefMD, ProtectedManifest: m.ProtectedManifest, AppPorts: m.AppPorts, Payload: payload},
		overlays: overlays,
	}
	matrix := kind.VerifyMatrix(kind.VerifyInput(payload))
	box := newCaptureBox(m.Captures)

	runs := make([]RunReport, len(matrix))
	errs := make([]error, len(matrix))
	slots := make(chan struct{}, max(opts.Parallel, 1))
	var wg sync.WaitGroup
	var mu sync.Mutex
	for i, run := range matrix {
		wg.Add(1)
		go func() {
			defer wg.Done()
			slots <- struct{}{}
			defer func() { <-slots }()
			var runBox *captureBox
			if run.Capture && len(m.Captures) > 0 {
				runBox = box
			}
			runs[i], errs[i] = executeRun(ctx, rt, grade, "local-"+recipeHash, "", kind, bundles, run, runBox)
			if errs[i] == nil && opts.OnRun != nil {
				mu.Lock()
				opts.OnRun(a.Key, runs[i])
				mu.Unlock()
			}
		}()
	}
	wg.Wait()
	if err := errors.Join(errs...); err != nil {
		return nil, fmt.Errorf("labbuild.verifyRenderedLocal: %w", err)
	}

	vr := &VariantReport{Key: a.Key, Passed: true, Runs: runs, Captured: box.snapshot()}
	for _, r := range runs {
		vr.Passed = vr.Passed && r.Passed
	}
	if vr.Passed && len(m.Captures) > 0 {
		if _, missing := substituteCaptures(m.BriefMD, vr.Captured); len(missing) > 0 {
			vr.Passed, vr.CaptureNote = false, fmt.Sprintf("could not capture %v from the broken run: %v", missing, box.errs)
		} else {
			vr.BriefFilled = true
		}
	}
	return vr, nil
}
