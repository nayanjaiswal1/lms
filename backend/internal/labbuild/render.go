package labbuild

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"regexp"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/labauthor"
	"github.com/mindforge/backend/internal/labblock"
	"github.com/mindforge/backend/internal/labkinds"
	"github.com/mindforge/backend/internal/labs"
	"github.com/mindforge/backend/internal/storage"
)

// contentError is a build failure caused by the recipe/blocks (an author can
// fix it): the build is marked failed and the job succeeds. Anything else is an
// infrastructure error and is returned so the job retries.
type contentError struct {
	msg    string
	issues []labblock.Issue
}

func (e *contentError) Error() string { return e.msg }

func contentErrf(format string, a ...any) error { return &contentError{msg: fmt.Sprintf(format, a...)} }

var safeNameRe = regexp.MustCompile(`[^A-Za-z0-9._-]`)

// blockPayload is a block's unpacked payload and the directory name it is
// placed under in the renderer's input.
type blockPayload struct {
	Dir   string
	Files map[string][]byte
}

// RunBuild is the lab.recipe_build job body: render every variant of a queued
// build in a validation sandbox, store the bundles, record the variants and
// block usages in one transaction, and hand off to verification.
// Safe to retry: status guards, content-addressed uploads and idempotent
// inserts make a second run a no-op or a clean redo.
func (s *Service) RunBuild(ctx context.Context, buildID string) error {
	b, err := s.repo.GetBuild(ctx, buildID)
	if errors.Is(err, ErrBuildNotFound) {
		return nil
	}
	if err != nil {
		return err
	}
	if b.Status != StatusQueued && b.Status != StatusRendering {
		return nil
	}
	if _, err := s.repo.Advance(ctx, b.ID, []string{StatusQueued}, StatusRendering); err != nil {
		return err
	}

	existing, err := s.repo.ListVariants(ctx, b.ID)
	if err != nil {
		return err
	}
	if len(existing) == 0 {
		if err := s.render(ctx, b); err != nil {
			var ce *contentError
			if errors.As(err, &ce) {
				return s.failBuild(ctx, b, Report{Error: ce.msg, Issues: ce.issues})
			}
			return err
		}
	}
	if _, err := s.enqueue(ctx, HandlerRecipeVerify, b.ID, b.CreatedBy, verifyJobTimeoutMS); err != nil {
		return err
	}
	return nil
}

func (s *Service) failBuild(ctx context.Context, b *Build, rep Report) error {
	slog.Warn("labbuild: build failed", "build_id", b.ID, "error", rep.Error)
	if _, err := s.repo.Finish(ctx, b.ID, StatusFailed, rep); err != nil {
		return err
	}
	return nil
}

func (s *Service) render(ctx context.Context, b *Build) error {
	started := time.Now()
	res, err := s.resolveSnapshot(ctx, b.Snapshot)
	if err != nil {
		return err
	}
	if !res.Analysis.Valid || res.Analysis.RecipeHash != b.RecipeHash {
		msg := "the recipe no longer validates"
		if res.Analysis.Valid {
			msg = "the recipe's resolved hash changed since the build was requested"
		}
		return &contentError{msg: msg, issues: res.Analysis.Issues}
	}

	variants, _, err := labauthor.EnumerateVariants(res.Recipe)
	if err != nil {
		return contentErrf("cannot enumerate variants: %v", err)
	}
	payloads, err := s.loadPayloads(ctx, res.Recipe.Blocks)
	if err != nil {
		return err
	}
	input, err := buildRendererInput(res, b.RecipeHash, variants, payloads)
	if err != nil {
		return err
	}
	artifacts, err := s.runRenderer(ctx, res.Kind.Image(), b, input, variants)
	if err != nil {
		return err
	}

	rows := make([]VariantRow, 0, len(artifacts))
	for _, a := range artifacts {
		row, err := s.storeVariant(ctx, b, a)
		if err != nil {
			return err
		}
		rows = append(rows, *row)
	}
	usage := make([]string, 0, len(res.Recipe.Blocks))
	for _, blk := range res.Recipe.Blocks {
		usage = append(usage, blk.VersionID)
	}
	if err := s.repo.InsertVariants(ctx, b.ID, rows, usage); err != nil {
		return err
	}
	rep := Report{RecipeHash: b.RecipeHash, Difficulty: res.Analysis.Difficulty, VariantCount: len(rows), RenderSecs: time.Since(started).Seconds()}
	return s.repo.SaveReport(ctx, b.ID, rep)
}

// loadPayloads downloads, sha256-verifies and unpacks every block payload.
func (s *Service) loadPayloads(ctx context.Context, blocks []*labblock.ResolvedBlock) (map[string]*blockPayload, error) {
	ids := make([]string, 0, len(blocks))
	for _, b := range blocks {
		ids = append(ids, b.VersionID)
	}
	refs, err := s.authoring.Repo().PayloadRefs(ctx, ids)
	if err != nil {
		return nil, err
	}
	out := map[string]*blockPayload{}
	for i, blk := range blocks {
		ref, ok := refs[blk.VersionID]
		if !ok || ref.Key == "" {
			continue // text-only block: no payload
		}
		raw, err := s.store.Download(ctx, ref.Key)
		if err != nil {
			return nil, fmt.Errorf("labbuild.Service.loadPayloads: download %s: %w", blk.Key, err)
		}
		sum := sha256.Sum256(raw)
		if !strings.EqualFold(hex.EncodeToString(sum[:]), ref.SHA) {
			return nil, fmt.Errorf("labbuild.Service.loadPayloads: %s: payload checksum mismatch", blk.Key)
		}
		p, err := newBlockPayload(i, blk, raw)
		if err != nil {
			return nil, err
		}
		out[blk.VersionID] = p
	}
	return out, nil
}

// newBlockPayload unpacks the payload of the recipe's i-th block.
func newBlockPayload(i int, blk *labblock.ResolvedBlock, raw []byte) (*blockPayload, error) {
	files, err := readTar(raw)
	if err != nil {
		return nil, contentErrf("block %s@%s has an unreadable payload: %v", blk.Key, blk.Version, err)
	}
	return &blockPayload{Dir: fmt.Sprintf("%02d-%s", i, safeNameRe.ReplaceAllString(blk.Key, "_")), Files: files}, nil
}

// buildRendererInput assembles the renderer's stdin tar: spec.json + blocks/<dir>/<file>.
func buildRendererInput(res *resolved, recipeHash string, variants []labauthor.Variant, payloads map[string]*blockPayload) ([]byte, error) {
	dirs := map[string]string{}
	for id, p := range payloads {
		dirs[id] = p.Dir
	}
	readFile := func(versionID, rel string) ([]byte, error) {
		p, ok := payloads[versionID]
		if !ok {
			return nil, fmt.Errorf("block has no payload")
		}
		data, ok := p.Files[rel]
		if !ok {
			return nil, fmt.Errorf("%s not in payload", rel)
		}
		return data, nil
	}
	specs := make([]json.RawMessage, 0, len(variants))
	for _, v := range variants {
		active := map[string]bool{}
		for _, id := range v.Active {
			active[id] = true
		}
		raw, err := res.Kind.RenderSpec(labkinds.RenderInput{
			Recipe: res.Recipe, VariantKey: v.Key, Seed: variantSeed(recipeHash, v.Key, res.Recipe.Spec.Seed),
			ActiveIDs: active, AxisParams: v.Params, BlockDirs: dirs, ReadFile: readFile, Literal: labauthor.RenderLiteral,
		})
		if err != nil {
			return nil, contentErrf("variant %s: %v", v.Key, err)
		}
		specs = append(specs, raw)
	}
	doc, err := json.Marshal(map[string]any{"schema": 1, "variants": specs})
	if err != nil {
		return nil, fmt.Errorf("labbuild.buildRendererInput: %w", err)
	}
	entries := []tarEntry{{Name: "spec.json", Data: doc}}
	for _, p := range payloads {
		for rel, data := range p.Files {
			entries = append(entries, tarEntry{Name: "blocks/" + p.Dir + "/" + rel, Data: data})
		}
	}
	return packTarGz(entries)
}

// renderedVariant is one variant's collected renderer output.
type renderedVariant struct {
	Key   string
	Files map[string][]byte // workspace.tar.gz, grader.tar.gz, verify.tar.gz, meta.json
}

// runRenderer renders a build's variants in a validation sandbox, metering
// the sandbox time against the org.
func (s *Service) runRenderer(ctx context.Context, image string, b *Build, input []byte, variants []labauthor.Variant) ([]renderedVariant, error) {
	started := time.Now()
	defer func() {
		secs := int64(time.Since(started).Seconds()) + 1
		if mErr := s.labsRepo.RecordValidationUsage(context.Background(), b.Snapshot.OrgID, "", image, secs); mErr != nil {
			slog.Error("labbuild: meter render time", "build_id", b.ID, "error", mErr)
		}
	}()
	return renderInSandbox(ctx, s.runtime, image, "build-"+strings.ReplaceAll(b.ID, "-", "")[:16], input, variants)
}

// renderInSandbox starts a validation sandbox, streams the input to mf-build
// and collects each variant's output directory back as a tar.
func renderInSandbox(ctx context.Context, rt labs.ContainerRuntime, image, sandboxID string, input []byte, variants []labauthor.Variant) ([]renderedVariant, error) {
	containerID, _, err := rt.StartValidation(ctx, sandboxID, image)
	if err != nil {
		return nil, fmt.Errorf("labbuild.renderInSandbox: start sandbox: %w", err)
	}
	defer func() { _ = rt.Kill(context.Background(), containerID) }()

	script := "rm -rf " + outputDir + " && " + rendererCmd
	stdout, stderr, exit, err := rt.ExecStdin(ctx, containerID, script, input, renderExecTimeoutSeconds)
	if err != nil {
		return nil, fmt.Errorf("labbuild.renderInSandbox: exec: %w", err)
	}
	var status struct {
		OK    bool   `json:"ok"`
		Error string `json:"error"`
	}
	line := lastLine(stdout)
	if jerr := json.Unmarshal([]byte(line), &status); jerr != nil || exit != 0 || !status.OK {
		msg := status.Error
		if msg == "" {
			msg = fmt.Sprintf("renderer exited %d: %s", exit, tail(strings.TrimSpace(stderr+" "+stdout), 1200))
		}
		return nil, contentErrf("render failed: %s", msg)
	}

	out := make([]renderedVariant, 0, len(variants))
	for _, v := range variants {
		tarOut, errOut, code, err := rt.ExecCapture(ctx, containerID, "tar -C "+outputDir+"/"+v.Key+" -cf - .", labs.MaxCapturedWorkspaceBytes)
		if err != nil {
			return nil, fmt.Errorf("labbuild.renderInSandbox: collect %s: %w", v.Key, err)
		}
		if code != 0 {
			return nil, fmt.Errorf("labbuild.renderInSandbox: collect %s exited %d: %s", v.Key, code, strings.TrimSpace(errOut))
		}
		if len(tarOut) >= labs.MaxCapturedWorkspaceBytes {
			return nil, contentErrf("variant %s output exceeds %d bytes", v.Key, labs.MaxCapturedWorkspaceBytes)
		}
		files, err := readTar([]byte(tarOut))
		if err != nil {
			return nil, fmt.Errorf("labbuild.renderInSandbox: parse %s output: %w", v.Key, err)
		}
		for _, need := range []string{"workspace.tar.gz", "grader.tar.gz", "verify.tar.gz", "meta.json"} {
			if _, ok := files[need]; !ok {
				return nil, fmt.Errorf("labbuild.renderInSandbox: variant %s output lacks %s", v.Key, need)
			}
		}
		out = append(out, renderedVariant{Key: v.Key, Files: files})
	}
	return out, nil
}

// meta is mf-build's meta.json.
type meta struct {
	ProtectedManifest json.RawMessage `json:"protected_manifest"`
	AppPorts          []int           `json:"app_ports"`
	BriefMD           string          `json:"brief_md"`
	Captures          []string        `json:"captures"`
	Cheats            []struct {
		Issue   int    `json:"issue"`
		Name    string `json:"name"`
		Overlay string `json:"overlay"`
		Diff    string `json:"diff"`
	} `json:"cheats"`
	Payload map[string]any `json:"payload"`
}

// storeVariant checks bundle budgets, uploads the three bundles, and builds the
// lab_build_variants row.
func (s *Service) storeVariant(ctx context.Context, b *Build, a renderedVariant) (*VariantRow, error) {
	var m meta
	if err := json.Unmarshal(a.Files["meta.json"], &m); err != nil {
		return nil, fmt.Errorf("labbuild.Service.storeVariant: meta: %w", err)
	}
	ws, gr, vf := a.Files["workspace.tar.gz"], a.Files["grader.tar.gz"], a.Files["verify.tar.gz"]
	if err := a.checkBudgets(); err != nil {
		return nil, err
	}
	wsKey, wsSHA, err := storage.PutBundle(ctx, s.store, ws)
	if err != nil {
		return nil, err
	}
	grKey, grSHA, err := storage.PutBundle(ctx, s.store, gr)
	if err != nil {
		return nil, err
	}
	vfKey, vfSHA, err := storage.PutBundle(ctx, s.store, vf)
	if err != nil {
		return nil, err
	}
	payload := m.Payload
	if payload == nil {
		payload = map[string]any{}
	}
	payload["verify_bundle_key"], payload["verify_bundle_sha256"] = vfKey, vfSHA
	payload["captures"] = m.Captures
	diffs := map[string]string{}
	for _, c := range m.Cheats {
		diffs[c.Overlay] = c.Diff
	}
	payload["cheat_diffs"] = diffs
	rawPayload, err := json.Marshal(payload)
	if err != nil {
		return nil, fmt.Errorf("labbuild.Service.storeVariant: payload: %w", err)
	}
	if len(m.AppPorts) == 0 {
		m.AppPorts = []int{}
	}
	return &VariantRow{
		BuildID: b.ID, Key: a.Key, WorkspaceKey: wsKey, WorkspaceSHA: wsSHA, GraderKey: grKey, GraderSHA: grSHA,
		BriefMD: m.BriefMD, ProtectedManifest: m.ProtectedManifest, AppPorts: m.AppPorts, Payload: rawPayload,
	}, nil
}

// checkBudgets enforces the workspace and grader bundle size limits.
func (a renderedVariant) checkBudgets() error {
	if n := len(a.Files["workspace.tar.gz"]); n > labauthor.MaxWorkspaceBytes {
		return contentErrf("variant %s: workspace bundle is %d bytes (limit %d)", a.Key, n, labauthor.MaxWorkspaceBytes)
	}
	if n := len(a.Files["grader.tar.gz"]); n > labauthor.MaxGraderBytes {
		return contentErrf("variant %s: grader bundle is %d bytes (limit %d)", a.Key, n, labauthor.MaxGraderBytes)
	}
	return nil
}

func lastLine(s string) string {
	s = strings.TrimSpace(s)
	if i := strings.LastIndexByte(s, '\n'); i >= 0 {
		return s[i+1:]
	}
	return s
}

func tail(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return "…" + s[len(s)-n:]
}
