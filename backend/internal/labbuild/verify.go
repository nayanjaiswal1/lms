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

const ()

// infraChecks are grader checks that mean "the app never got far enough to be
// graded"; an expected failure must come from a real probe/test, not from these.
var infraChecks = map[string]bool{"setup": true, "application starts": true, "integrity": true}

// Verification sandboxes are capped per organization GLOBALLY (all worker
// replicas together, docs/debug-labs.md B3: "the org validation cap") by a
// Redis-backed counting semaphore (ratelimit.Semaphore). This is deliberately
// different from labs.CleanRoomMaxConcurrent, which is a per-process cap
// protecting the local node's CPU/memory and stays in-process on purpose.
//
// A full semaphore never blocks: runs that cannot get a lease stay pending, the
// completed runs are saved in the report, and the verify job re-enqueues itself
// (delayed) through the jobs system.
const (
	verifySemKeyPrefix = "labbuild:verify:org:"
	// verifyLeaseTTL bounds how long a crashed worker can hold a slot; live
	// holders renew every ttl/3.
	verifyLeaseTTL = 2 * time.Minute
	// verifyBusyBackoff is the delay before a deferred verify job runs again.
	verifyBusyBackoff = 30 * time.Second
)

// errRunBusy means this replica's clean-room slots are full (labs.ErrGradeBusy):
// the run is deferred like a full semaphore.
var errRunBusy = errors.New("labbuild: clean-room capacity busy")

func verifySemKey(org string) string { return verifySemKeyPrefix + org }

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
		return fmt.Errorf("labbuild.RunVerify: %w", err)
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
		return fmt.Errorf("labbuild.RunVerify: %w", err)
	}
	if len(variants) == 0 {
		return s.failBuild(ctx, b, Report{Error: "the build has no variants"})
	}

	rep := Report{RecipeHash: b.RecipeHash}
	if b.DerivedDifficulty != nil {
		rep.Difficulty = *b.DerivedDifficulty
	}
	rep.VariantCount = len(variants)
	prior := priorVariantReports(b.Report)
	allPassed, deferred := true, false
	var infraErr error
	for _, v := range variants {
		vr, err := s.verifyVariant(ctx, b, kind, v, prior[v.Key])
		if err != nil {
			infraErr = err
			vr = &VariantReport{Key: v.Key}
			vr.Runs = append(vr.Runs, RunReport{Name: "infrastructure", Error: err.Error()})
		}
		allPassed = allPassed && vr.Passed
		deferred = deferred || len(vr.Pending) > 0
		rep.Variants = append(rep.Variants, *vr)
		if serr := s.repo.SaveReport(ctx, b.ID, rep); serr != nil {
			slog.Warn("labbuild: save live report", "build_id", b.ID, "error", serr)
		}
	}
	if infraErr != nil {
		return fmt.Errorf("labbuild.Service.RunVerify: %w", infraErr)
	}
	if deferred {
		// Some runs could not get a slot: come back later with the finished runs kept.
		at := time.Now().Add(verifyBusyBackoff)
		_, err := s.enqueueAt(ctx, HandlerRecipeVerify, b.ID, b.CreatedBy, verifyJobTimeoutMS, &at, fmt.Sprintf(":%d", at.Unix()))
		return err
	}

	status := StatusFailed
	if allPassed {
		status = StatusVerified
	}
	moved, err := s.repo.Finish(ctx, b.ID, status, rep)
	if err != nil {
		return fmt.Errorf("labbuild.RunVerify: %w", err)
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
		return nil, fmt.Errorf("labbuild.loadVariantBundles: %w", err)
	}
	gr, err := s.downloadVerified(ctx, v.GraderKey, v.GraderSHA)
	if err != nil {
		return nil, fmt.Errorf("labbuild.loadVariantBundles: %w", err)
	}
	var vb VerifyBundle
	if err := json.Unmarshal(v.Payload, &vb); err != nil || vb.Key == "" {
		return nil, fmt.Errorf("variant %s has no verification overlay bundle", v.Key)
	}
	raw, err := s.downloadVerified(ctx, vb.Key, vb.SHA)
	if err != nil {
		return nil, fmt.Errorf("labbuild.loadVariantBundles: %w", err)
	}
	overlays, err := overlaysFromVerifyTar(raw)
	if err != nil {
		return nil, fmt.Errorf("labbuild.loadVariantBundles: %w", err)
	}
	return &variantBundles{
		view: &labkinds.VariantView{BuildID: v.BuildID, VariantKey: v.Key, WorkspaceBundle: ws, GraderBundle: gr,
			BriefMD: v.BriefMD, ProtectedManifest: v.ProtectedManifest, AppPorts: v.AppPorts, Payload: v.Payload},
		overlays: overlays,
	}, nil
}

// overlaysFromVerifyTar unpacks a verify.tar.gz into overlay file -> tar.
func overlaysFromVerifyTar(raw []byte) (map[string][]byte, error) {
	files, err := readTar(raw)
	if err != nil {
		return nil, fmt.Errorf("labbuild.overlaysFromVerifyTar: %w", err)
	}
	overlays := map[string][]byte{}
	for name, data := range files {
		overlays[strings.TrimPrefix(name, "overlays/")] = data
	}
	return overlays, nil
}

// overlayFile maps a labkinds overlay selector to its file in the verify bundle.
func overlayFile(sel string) string {
	return strings.ReplaceAll(sel, ":", "-") + ".tgz"
}

// verifyVariant runs the kind's matrix for one variant.
func (s *Service) verifyVariant(ctx context.Context, b *Build, kind labkinds.Kind, v VariantRow, prior *VariantReport) (*VariantReport, error) {
	bundles, err := s.loadVariantBundles(ctx, v)
	if err != nil {
		return nil, fmt.Errorf("labbuild.verifyVariant: %w", err)
	}
	matrix := kind.VerifyMatrix(kind.VerifyInput(v.Payload))

	var p struct {
		Captures []string `json:"captures"`
	}
	_ = json.Unmarshal(v.Payload, &p)
	captureNames := p.Captures
	box := newCaptureBox(captureNames)

	// Runs finished in an earlier attempt of this job are kept, not redone.
	done := map[string]RunReport{}
	if prior != nil {
		for _, r := range prior.Runs {
			if r.Error == "" && len(r.Seeds) > 0 {
				done[r.Name] = r
			}
		}
		for k, val := range prior.Captured {
			box.got[k] = val
		}
	}
	var pending []int
	for i, run := range matrix {
		if _, ok := done[run.Name]; !ok {
			pending = append(pending, i)
		}
	}

	limit := max(s.cfg.VerifyParallelPerOrg, 1)
	key := verifySemKey(b.Snapshot.OrgID)
	var mu sync.Mutex
	var runErr error
	for len(pending) > 0 && runErr == nil {
		var wg sync.WaitGroup
		var next []int
		progressed := 0
		for _, i := range pending {
			lease, err := s.sem.TryAcquire(ctx, key, limit, verifyLeaseTTL)
			if err != nil {
				runErr = err
				break
			}
			if lease == nil {
				next = append(next, i)
				continue
			}
			wg.Add(1)
			go func(i int, run labkinds.VerifyRun) {
				defer wg.Done()
				defer lease.Release()
				var runBox *captureBox
				if run.Capture && len(captureNames) > 0 {
					runBox = box
				}
				rr, err := executeRun(lease.Ctx, s.runtime, s.labs.GradeModesInCleanRoom, b.ID, b.Snapshot.OrgID, kind, bundles, run, runBox)
				mu.Lock()
				defer mu.Unlock()
				switch {
				case errors.Is(err, errRunBusy):
					next = append(next, i)
				case err != nil:
					runErr = err
				default:
					done[run.Name] = rr
					progressed++
				}
			}(i, matrix[i])
		}
		wg.Wait()
		if progressed == 0 {
			pending = next
			break
		}
		pending = next
	}
	if runErr != nil {
		return nil, runErr
	}

	vr := &VariantReport{Key: v.Key, Passed: true, Captured: box.snapshot()}
	for _, run := range matrix {
		if r, ok := done[run.Name]; ok {
			vr.Runs = append(vr.Runs, r)
			vr.Passed = vr.Passed && r.Passed
		} else {
			vr.Pending = append(vr.Pending, run.Name)
		}
	}
	if len(vr.Pending) > 0 {
		vr.Passed = false
		return vr, nil
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

// priorVariantReports reads the per-variant results saved by an earlier attempt.
func priorVariantReports(raw json.RawMessage) map[string]*VariantReport {
	out := map[string]*VariantReport{}
	var rep Report
	if len(raw) == 0 || json.Unmarshal(raw, &rep) != nil {
		return out
	}
	for i := range rep.Variants {
		out[rep.Variants[i].Key] = &rep.Variants[i]
	}
	return out
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
		return fmt.Errorf("labbuild.fillCaptures: %w", err)
	}
	return s.repo.UpdateVariantBrief(ctx, b.ID, v.Key, key, sha, brief)
}

// gradeFunc grades modes in a clean room: labs.Service.GradeModesInCleanRoom
// in the jobs, an uncapped labs.GradeModesInSandbox offline.
type gradeFunc func(ctx context.Context, target labs.GradeTarget, v *labkinds.VariantView, editableTar []byte, modes []string, seed string) (map[string]*labs.GradeResult, error)

// executeRun grades one matrix run (all its seeds) and evaluates its expectations.
func executeRun(ctx context.Context, rt labs.ContainerRuntime, grade gradeFunc, buildID, orgID string, kind labkinds.Kind, bundles *variantBundles, run labkinds.VerifyRun, box *captureBox) (RunReport, error) {
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
		seed := runSeed(buildID, bundles.view.VariantKey, run.Name, i)
		var hook func(context.Context, string) error
		if box != nil && i == 0 {
			hook = box.hook(rt)
		}
		results, err := grade(ctx, labs.GradeTarget{Image: image, OrgID: orgID, AfterGrade: hook},
			bundles.view, overlay, run.Modes, seed)
		if errors.Is(err, labs.ErrGradeBusy) {
			return rr, errRunBusy
		}
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
