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
//
// It also returns every verified variant's artifact (row + bundles), shaped by
// the same variantRowFrom/finalizeBrief the jobs use: the content of a CI labset.
func VerifyLocal(ctx context.Context, rt labs.ContainerRuntime, recipe *labblock.Recipe, an *labauthor.Analysis, payloads map[string][]byte, opts LocalOptions) (*Report, []VariantArtifact, error) {
	kind, ok := labkinds.Get(recipe.LabKind)
	if !ok {
		return nil, nil, fmt.Errorf("labbuild.VerifyLocal: unknown lab kind %q", recipe.LabKind)
	}
	if !an.Valid || an.RecipeHash == "" {
		return &Report{Error: "the recipe does not validate", Issues: an.Issues}, nil, nil
	}
	rep := &Report{RecipeHash: an.RecipeHash, Difficulty: an.Difficulty}
	variants, _, err := labauthor.EnumerateVariants(recipe)
	if err != nil {
		return nil, nil, fmt.Errorf("labbuild.VerifyLocal: %w", err)
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
	arts := make([]VariantArtifact, 0, len(rendered))
	for _, a := range rendered {
		if opts.OnRendered != nil {
			if err := opts.OnRendered(a.Key, a.Files); err != nil {
				return nil, nil, fmt.Errorf("labbuild.VerifyLocal: %w", err)
			}
		}
		vr, art, err := verifyRenderedLocal(ctx, rt, grade, kind, an.RecipeHash, a, opts)
		if err != nil {
			return contentReport(rep, err)
		}
		rep.Variants = append(rep.Variants, *vr)
		arts = append(arts, *art)
	}
	return rep, arts, nil
}

// contentReport turns a content error into a failed report; anything else is returned.
func contentReport(rep *Report, err error) (*Report, []VariantArtifact, error) {
	var ce *contentError
	if errors.As(err, &ce) {
		rep.Error, rep.Issues = ce.msg, ce.issues
		return rep, nil, nil
	}
	return nil, nil, err
}

// verifyRenderedLocal runs one rendered variant's whole matrix and returns its
// artifact, with the captured output filled into the brief when it passed.
func verifyRenderedLocal(ctx context.Context, rt labs.ContainerRuntime, grade gradeFunc, kind labkinds.Kind, recipeHash string, a renderedVariant, opts LocalOptions) (*VariantReport, *VariantArtifact, error) {
	art, err := variantRowFrom("", a)
	if err != nil {
		return nil, nil, fmt.Errorf("labbuild.verifyRenderedLocal: %w", err)
	}
	row := art.Row
	overlays, err := overlaysFromVerifyTar(art.Verify)
	if err != nil {
		return nil, nil, fmt.Errorf("labbuild.verifyRenderedLocal: %w", err)
	}
	bundles := &variantBundles{
		view: &labkinds.VariantView{VariantKey: row.Key, WorkspaceBundle: art.Workspace, GraderBundle: art.Grader,
			BriefMD: row.BriefMD, ProtectedManifest: row.ProtectedManifest, AppPorts: row.AppPorts, Payload: row.Payload},
		overlays: overlays,
	}
	matrix := kind.VerifyMatrix(kind.VerifyInput(row.Payload))
	var p struct {
		Captures []string `json:"captures"`
	}
	if err := json.Unmarshal(row.Payload, &p); err != nil {
		return nil, nil, fmt.Errorf("labbuild.verifyRenderedLocal: payload: %w", err)
	}
	box := newCaptureBox(p.Captures)

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
			if run.Capture && len(p.Captures) > 0 {
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
		return nil, nil, fmt.Errorf("labbuild.verifyRenderedLocal: %w", err)
	}

	vr := &VariantReport{Key: a.Key, Passed: true, Runs: runs, Captured: box.snapshot()}
	for _, r := range runs {
		vr.Passed = vr.Passed && r.Passed
	}
	if vr.Passed && len(p.Captures) > 0 {
		brief, ws, err := finalizeBrief(row.BriefMD, art.Workspace, box)
		var ce *contentError
		switch {
		case errors.As(err, &ce):
			vr.Passed, vr.CaptureNote = false, ce.msg
		case err != nil:
			return nil, nil, fmt.Errorf("labbuild.verifyRenderedLocal: %w", err)
		default:
			art.setBrief(brief, ws)
			vr.BriefFilled = true
		}
	}
	return vr, art, nil
}
