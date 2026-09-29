package labbuild

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"sync"
	"time"

	"github.com/mindforge/backend/internal/labkinds"
	"github.com/mindforge/backend/internal/labs"
	"github.com/mindforge/backend/internal/storage"
)

const (
	graderBusyRetries = 20
	graderBusyBackoff = 3 * time.Second
)

// infraChecks are grader checks that mean "the app never got far enough to be
// graded"; an expected failure must come from a real probe/test, not from these.
var infraChecks = map[string]bool{"setup": true, "application starts": true, "integrity": true}

// orgSemaphores bounds concurrent verification sandboxes per organization
// (docs/debug-labs.md B3: "up to the org validation cap of 5"). In-process:
// each worker replica enforces the cap for its own runs.
type orgSemaphores struct {
	limit int
	mu    sync.Mutex
	m     map[string]chan struct{}
}

func (o *orgSemaphores) acquire(ctx context.Context, org string) (release func(), err error) {
	o.mu.Lock()
	if o.m == nil {
		o.m = map[string]chan struct{}{}
	}
	ch, ok := o.m[org]
	if !ok {
		ch = make(chan struct{}, o.limit)
		o.m[org] = ch
	}
	o.mu.Unlock()
	select {
	case ch <- struct{}{}:
		return func() { <-ch }, nil
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

// RunVerify is the lab.recipe_verify job body: run the kind's verification
// matrix for every variant through the clean-room grader, fill the ticket's
// captured placeholders from the broken run, and mark the build verified or
// failed. A grading infrastructure error is returned (the job retries); a
// failed expectation is a normal, reported outcome.
func (s *Service) RunVerify(ctx context.Context, buildID string) error {
	b, err := s.repo.GetBuild(ctx, buildID)
	if errors.Is(err, ErrBuildNotFound) {
		return nil
	}
	if err != nil {
		return err
	}
	if b.Status != StatusVerifying {
		return nil
	}
	kind, ok := labkinds.Get(b.Snapshot.LabKind)
	if !ok {
		return s.failBuild(ctx, b, Report{Error: "unknown lab kind " + b.Snapshot.LabKind})
	}
	variants, err := s.repo.ListVariants(ctx, b.ID)
	if err != nil {
		return err
	}
	if len(variants) == 0 {
		return s.failBuild(ctx, b, Report{Error: "the build has no variants"})
	}

	rep := Report{RecipeHash: b.RecipeHash}
	if b.DerivedDifficulty != nil {
		rep.Difficulty = *b.DerivedDifficulty
	}
	rep.VariantCount = len(variants)
	allPassed := true
	var infraErr error
	for _, v := range variants {
		vr, err := s.verifyVariant(ctx, b, kind, v)
		if err != nil {
			infraErr = err
			vr = &VariantReport{Key: v.Key}
			vr.Runs = append(vr.Runs, RunReport{Name: "infrastructure", Error: err.Error()})
		}
		allPassed = allPassed && vr.Passed
		rep.Variants = append(rep.Variants, *vr)
		if serr := s.repo.SaveReport(ctx, b.ID, rep); serr != nil {
			slog.Warn("labbuild: save live report", "build_id", b.ID, "error", serr)
		}
	}
	if infraErr != nil {
		return fmt.Errorf("labbuild.Service.RunVerify: %w", infraErr)
	}

	status := StatusFailed
	if allPassed {
		status = StatusVerified
	}
	moved, err := s.repo.Finish(ctx, b.ID, status, rep)
	if err != nil {
		return err
	}
	if moved && allPassed && b.Snapshot.AutoPublish {
		if err := s.autoPublish(ctx, b); err != nil {
			// The build stays verified; the next platform sync retries the publish.
			slog.Error("labbuild: auto-publish", "build_id", b.ID, "error", err)
		}
	}
	return nil
}

// variantBundles are a variant's downloaded artifacts.
type variantBundles struct {
	view     *labkinds.VariantView
	overlays map[string][]byte // "fix-1.tgz", "cheat-0-0.tgz"
}

func (s *Service) downloadVerified(ctx context.Context, key, wantSHA string) ([]byte, error) {
	data, err := s.store.Download(ctx, key)
	if err != nil {
		return nil, fmt.Errorf("download %s: %w", key, err)
	}
	sum := sha256.Sum256(data)
	if !strings.EqualFold(hex.EncodeToString(sum[:]), wantSHA) {
		return nil, fmt.Errorf("bundle %s failed its checksum", key)
	}
	return data, nil
}

func (s *Service) loadVariantBundles(ctx context.Context, v VariantRow) (*variantBundles, error) {
	ws, err := s.downloadVerified(ctx, v.WorkspaceKey, v.WorkspaceSHA)
	if err != nil {
		return nil, err
	}
	gr, err := s.downloadVerified(ctx, v.GraderKey, v.GraderSHA)
	if err != nil {
		return nil, err
	}
	var vb VerifyBundle
	if err := json.Unmarshal(v.Payload, &vb); err != nil || vb.Key == "" {
		return nil, fmt.Errorf("variant %s has no verification overlay bundle", v.Key)
	}
	raw, err := s.downloadVerified(ctx, vb.Key, vb.SHA)
	if err != nil {
		return nil, err
	}
	files, err := readTar(raw)
	if err != nil {
		return nil, err
	}
	overlays := map[string][]byte{}
	for name, data := range files {
		overlays[strings.TrimPrefix(name, "overlays/")] = data
	}
	return &variantBundles{
		view: &labkinds.VariantView{BuildID: v.BuildID, VariantKey: v.Key, WorkspaceBundle: ws, GraderBundle: gr,
			BriefMD: v.BriefMD, ProtectedManifest: v.ProtectedManifest, AppPorts: v.AppPorts, Payload: v.Payload},
		overlays: overlays,
	}, nil
}

// overlayFile maps a labkinds overlay selector to its file in the verify bundle.
func overlayFile(sel string) string {
	return strings.ReplaceAll(sel, ":", "-") + ".tgz"
}

// verifyVariant runs the kind's matrix for one variant.
func (s *Service) verifyVariant(ctx context.Context, b *Build, kind labkinds.Kind, v VariantRow) (*VariantReport, error) {
	bundles, err := s.loadVariantBundles(ctx, v)
	if err != nil {
		return nil, err
	}
	input := kind.VerifyInput(v.Payload)
	matrix := kind.VerifyMatrix(input)

	var captureNames []string
	var p struct {
		Captures []string `json:"captures"`
	}
	_ = json.Unmarshal(v.Payload, &p)
	captureNames = p.Captures
	box := newCaptureBox(captureNames)

	reports := make([]RunReport, len(matrix))
	errs := make([]error, len(matrix))
	var wg sync.WaitGroup
	for i, run := range matrix {
		wg.Add(1)
		go func(i int, run labkinds.VerifyRun) {
			defer wg.Done()
			var runBox *captureBox
			if run.Capture && len(captureNames) > 0 {
				runBox = box
			}
			reports[i], errs[i] = s.executeRun(ctx, b, kind, bundles, run, runBox)
		}(i, run)
	}
	wg.Wait()
	for _, e := range errs {
		if e != nil {
			return nil, e
		}
	}

	vr := &VariantReport{Key: v.Key, Runs: reports, Passed: true}
	for _, r := range reports {
		vr.Passed = vr.Passed && r.Passed
	}
	if vr.Passed && len(captureNames) > 0 {
		if err := s.fillCaptures(ctx, b, v, bundles, box); err != nil {
			var ce *contentError
			if errors.As(err, &ce) {
				vr.Passed, vr.CaptureNote = false, ce.msg
			} else {
				return nil, err
			}
		} else {
			vr.BriefFilled = true
		}
	}
	return vr, nil
}

// fillCaptures substitutes the captured text into the brief and the workspace's
// TICKET.md and re-uploads the workspace bundle.
func (s *Service) fillCaptures(ctx context.Context, b *Build, v VariantRow, bundles *variantBundles, box *captureBox) error {
	box.mu.Lock()
	got, errs := box.got, append([]string(nil), box.errs...)
	box.mu.Unlock()
	brief, missing := substituteCaptures(v.BriefMD, got)
	if len(missing) > 0 {
		return contentErrf("could not capture %s from the broken run: %s", strings.Join(missing, ", "), strings.Join(errs, "; "))
	}
	ws, err := replaceTarEntry(bundles.view.WorkspaceBundle, "TICKET.md", []byte(brief))
	if err != nil {
		return fmt.Errorf("labbuild.Service.fillCaptures: %w", err)
	}
	key, sha, err := storage.PutBundle(ctx, s.store, ws)
	if err != nil {
		return err
	}
	return s.repo.UpdateVariantBrief(ctx, b.ID, v.Key, key, sha, brief)
}

// executeRun grades one matrix run (all its seeds) and evaluates its expectations.
func (s *Service) executeRun(ctx context.Context, b *Build, kind labkinds.Kind, bundles *variantBundles, run labkinds.VerifyRun, box *captureBox) (RunReport, error) {
	rr := RunReport{Name: run.Name, Description: run.Description, Overlay: run.Overlay, Passed: true}
	var overlay []byte
	if run.Overlay != labkinds.OverlayNone {
		var ok bool
		if overlay, ok = bundles.overlays[overlayFile(run.Overlay)]; !ok {
			rr.Passed, rr.Error = false, "the renderer produced no overlay "+run.Overlay
			return rr, nil
		}
	}
	seeds := max(run.Seeds, 1)
	image := kind.Image()
	for i := 0; i < seeds; i++ {
		seed := runSeed(b.ID, bundles.view.VariantKey, run.Name, i)
		var hook func(context.Context, string) error
		if box != nil && i == 0 {
			hook = box.hook(s.runtime)
		}
		results, err := s.gradeWithRetry(ctx, b.Snapshot.OrgID, labs.GradeTarget{Image: image, OrgID: b.Snapshot.OrgID, AfterGrade: hook},
			bundles.view, overlay, run.Modes, seed)
		if err != nil {
			return rr, fmt.Errorf("run %s: %w", run.Name, err)
		}
		sr := SeedResult{Seed: seed, Modes: map[string]ModeResult{}}
		for mode, res := range results {
			mr := ModeResult{Passed: res.Passed, Error: res.Error}
			for _, c := range res.Checks {
				mr.Checks = append(mr.Checks, CheckResult{Name: c.Name, Passed: c.Passed, Message: c.Message})
			}
			sr.Modes[mode] = mr
			if !res.Passed {
				for _, c := range res.Checks {
					if !c.Passed && c.Message != "" {
						rr.Messages = append(rr.Messages, c.Message)
					}
				}
			}
			if res.SetupSeconds > rr.SetupSeconds {
				rr.SetupSeconds = res.SetupSeconds
			}
			if res.StderrTail != "" && rr.StderrTail == "" {
				rr.StderrTail = res.StderrTail
			}
		}
		rr.Seeds = append(rr.Seeds, sr)
	}
	evaluate(&rr, kind, run)
	return rr, nil
}

// gradeWithRetry runs the clean-room grade under the per-org concurrency cap,
// backing off while this replica's clean-room slots are busy.
func (s *Service) gradeWithRetry(ctx context.Context, org string, target labs.GradeTarget, v *labkinds.VariantView, overlay []byte, modes []string, seed string) (map[string]*labs.GradeResult, error) {
	release, err := s.sems.acquire(ctx, org)
	if err != nil {
		return nil, err
	}
	defer release()
	for attempt := 0; ; attempt++ {
		res, err := s.labs.GradeModesInCleanRoom(ctx, target, v, overlay, modes, seed)
		if !errors.Is(err, labs.ErrGradeBusy) || attempt >= graderBusyRetries {
			return res, err
		}
		select {
		case <-time.After(graderBusyBackoff):
		case <-ctx.Done():
			return nil, ctx.Err()
		}
	}
}

// evaluate checks a run's expectations against its results and fills
// Expectations / Failures / Passed.
func evaluate(rr *RunReport, kind labkinds.Kind, run labkinds.VerifyRun) {
	modeOf := map[string]string{}
	optional := map[string]bool{}
	for _, t := range kind.Tasks() {
		if t.Grader == "script" {
			modeOf[t.Key] = t.Mode
			optional[t.Key] = t.IsOptional
		}
	}
	fail := func(format string, a ...any) { rr.Failures = append(rr.Failures, fmt.Sprintf(format, a...)) }

	for _, sr := range rr.Seeds {
		for _, key := range run.ExpectTasksPass {
			rr.addExpectation(fmt.Sprintf("task %s passes", key))
			m, ok := sr.Modes[modeOf[key]]
			if !ok {
				fail("task %s was not graded", key)
			} else if !m.Passed {
				fail("task %s should pass but %s", key, describeFailure(m))
			}
		}
		for _, key := range run.ExpectTasksFail {
			rr.addExpectation(fmt.Sprintf("task %s fails on a real check", key))
			m, ok := sr.Modes[modeOf[key]]
			switch {
			case !ok:
				fail("task %s was not graded", key)
			case m.Error != "":
				fail("task %s could not be graded: %s", key, m.Error)
			case !hasRealFailure(m, nil):
				fail("task %s should fail on a probe or test, but %s", key, describeFailure(m))
			}
		}
		if run.ExpectAnyRequiredFail {
			rr.addExpectation("at least one required task fails")
			failed := false
			for key, mode := range modeOf {
				if optional[key] {
					continue
				}
				if m, ok := sr.Modes[mode]; ok && !m.Passed && m.Error == "" {
					failed = true
				}
			}
			if !failed {
				fail("the overlay passes every required task (the grader accepts a cheat)")
			}
		}
		sym := sr.Modes[modeOf["symptom"]]
		for _, i := range run.ExpectIssuesFail {
			rr.addExpectation(fmt.Sprintf("issue %d still fails", i+1))
			if !hasRealFailure(sym, func(name string) bool { return labkinds.IssueOfCheck(name) == i }) {
				fail("issue %d should still fail, but no probe of it failed", i+1)
			}
		}
		for _, i := range run.ExpectIssuesPass {
			rr.addExpectation(fmt.Sprintf("issue %d passes", i+1))
			if sym.Error != "" || failedAny(sym, func(name string) bool { return labkinds.IssueOfCheck(name) == i }) {
				fail("issue %d should pass but %s", i+1, describeFailure(sym))
			}
		}
	}
	if run.MaxSetupSeconds > 0 {
		rr.addExpectation(fmt.Sprintf("sandbox setup <= %ds", run.MaxSetupSeconds))
		if rr.SetupSeconds > float64(run.MaxSetupSeconds) {
			fail("sandbox setup took %.1fs (limit %ds)", rr.SetupSeconds, run.MaxSetupSeconds)
		}
	}
	rr.Failures = dedupe(rr.Failures)
	rr.Expectations = dedupe(rr.Expectations)
	rr.Passed = len(rr.Failures) == 0
}

func (r *RunReport) addExpectation(s string) { r.Expectations = append(r.Expectations, s) }

// hasRealFailure reports whether a mode has at least one failed check that is
// not an infrastructure check, optionally restricted to checks `match` accepts.
func hasRealFailure(m ModeResult, match func(string) bool) bool {
	for _, c := range m.Checks {
		if !c.Passed && !infraChecks[c.Name] && (match == nil || match(c.Name)) {
			return true
		}
	}
	return false
}

func failedAny(m ModeResult, match func(string) bool) bool {
	for _, c := range m.Checks {
		if !c.Passed && (match == nil || match(c.Name)) {
			return true
		}
	}
	return false
}

func describeFailure(m ModeResult) string {
	if m.Error != "" {
		return "the grader reported: " + m.Error
	}
	var names []string
	for _, c := range m.Checks {
		if !c.Passed {
			names = append(names, c.Name)
		}
	}
	if len(names) == 0 {
		return "it did not pass"
	}
	return "failing checks: " + strings.Join(names, ", ")
}

func dedupe(in []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, s := range in {
		if !seen[s] {
			seen[s] = true
			out = append(out, s)
		}
	}
	return out
}
