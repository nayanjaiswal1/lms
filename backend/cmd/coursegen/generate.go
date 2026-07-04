package main

import (
	"fmt"

	"github.com/mindforge/backend/internal/contentpipeline/generator"
)

// Defaults assume invocation from backend/ (e.g. `cd backend && go run
// ./cmd/coursegen generate`), matching the go run ./cmd/... convention every
// other MindForge command uses — content/ lives at the repo root, a sibling
// of backend/, hence the ../ prefix.
const (
	defaultCanonicalDir = "../content/courses/fast-kubernetes"
	defaultOutputSQL    = "db/fixtures/k8s_fastkube.generated.sql"
)

func runGenerate(args []string) error {
	fs := newFlagSet("generate")
	in := fs.String("in", defaultCanonicalDir, "canonical markdown directory to render")
	out := fs.String("out", defaultOutputSQL, "path to write the generated SQL fixture")
	if err := fs.Parse(args); err != nil {
		return err
	}

	if err := generator.Generate(*in, *out); err != nil {
		return err
	}
	fmt.Printf("coursegen generate: wrote %s\n", *out)
	return nil
}
