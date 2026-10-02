package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
	"github.com/mindforge/backend/internal/labauthor"
	"github.com/mindforge/backend/internal/labblock"
	"github.com/mindforge/backend/internal/labbuild"
	"github.com/mindforge/backend/internal/labs"
)

// verifyTimeout bounds one recipe's whole render + matrix.
const verifyTimeout = 60 * time.Minute

// runBlocksVerify builds and verifies each recipe file against the local
// block tree in local Docker (labbuild.VerifyLocal).
func runBlocksVerify(args []string) error {
	fs := newFlagSet("blocks verify")
	in := fs.String("in", defaultBlocksDir, "block tree")
	parallel := fs.Int("parallel", 4, "concurrent clean-room sandboxes")
	reportPath := fs.String("report", "", "write the JSON reports to this file")
	outDir := fs.String("out", "", "keep each variant's renderer output under DIR/<recipe>/<variant>/")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if fs.NArg() == 0 {
		return fmt.Errorf("%s", blocksUsage)
	}

	loaded, err := labauthor.LoadBlockTree(*in)
	if err != nil {
		return err
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
	rt := labs.NewDockerContainerService(map[string]labs.ImageProfile{
		"mindforge/lab-debug:1": {Name: labs.ImageProfileDebugIDE, CPU: labs.DebugIDEContainerCPU, MemoryMB: labs.DebugIDEContainerMemoryMB},
	})

	reports := map[string]*labbuild.Report{}
	var failed []string
	for _, path := range fs.Args() {
		fmt.Printf("== %s\n", path)
		rep, err := verifyRecipeFile(rt, path, versions, payloads, *parallel, *outDir)
		if err != nil {
			return fmt.Errorf("%s: %w", path, err)
		}
		reports[path] = rep
		if !reportPassed(rep) {
			failed = append(failed, path)
		}
		printReport(rep)
	}
	if *reportPath != "" {
		raw, err := json.MarshalIndent(reports, "", "  ")
		if err != nil {
			return fmt.Errorf("blocks verify: %w", err)
		}
		if err := os.WriteFile(*reportPath, raw, 0o644); err != nil {
			return fmt.Errorf("blocks verify: %w", err)
		}
	}
	if len(failed) > 0 {
		return fmt.Errorf("%d of %d recipe(s) failed verification: %s", len(failed), fs.NArg(), strings.Join(failed, ", "))
	}
	fmt.Printf("coursegen blocks verify: %d recipe(s) verified\n", fs.NArg())
	return nil
}

func verifyRecipeFile(rt labs.ContainerRuntime, path string, versions map[string]*labblock.ResolvedBlock, payloads map[string][]byte, parallel int, outDir string) (*labbuild.Report, error) {
	rs, err := canonical.LoadRecipe(path)
	if err != nil {
		return nil, err
	}
	spec, err := rs.Spec()
	if err != nil {
		return nil, err
	}
	recipe, issues := labauthor.BuildRecipe(rs.LabKind, "", spec, versions)
	if len(issues) > 0 {
		return &labbuild.Report{Error: "the recipe does not resolve against the block tree", Issues: issues}, nil
	}
	an := labauthor.Analyze(recipe)
	ctx, cancel := context.WithTimeout(context.Background(), verifyTimeout)
	defer cancel()
	opts := labbuild.LocalOptions{
		Parallel: parallel,
		OnRun: func(variant string, rr labbuild.RunReport) {
			fmt.Printf("   [%s] %-22s %s\n", variant, rr.Name, passWord(rr.Passed))
		},
	}
	if outDir != "" {
		base := filepath.Join(outDir, strings.TrimSuffix(filepath.Base(path), filepath.Ext(path)))
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
	return labbuild.VerifyLocal(ctx, rt, recipe, an, payloads, opts)
}

func reportPassed(rep *labbuild.Report) bool {
	if rep.Error != "" || len(rep.Variants) == 0 {
		return false
	}
	for _, v := range rep.Variants {
		if !v.Passed {
			return false
		}
	}
	return true
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
	fmt.Printf("   => %s (hash %.12s, difficulty %s, %d variant(s))\n", passWord(reportPassed(rep)), rep.RecipeHash, rep.Difficulty, rep.VariantCount)
}

func passWord(ok bool) string {
	if ok {
		return "PASS"
	}
	return "FAIL"
}
