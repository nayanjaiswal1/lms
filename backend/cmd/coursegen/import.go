package main

import (
	"fmt"

	"github.com/mindforge/backend/internal/contentpipeline/importer"
)

// Assumes invocation from backend/ — see the comment in generate.go.
const (
	defaultVendorDir = "../content/fast-kubernetes"
)

func runImport(args []string) error {
	fs := newFlagSet("import")
	vendor := fs.String("vendor", defaultVendorDir, "vendored upstream snapshot directory")
	out := fs.String("out", defaultCanonicalDir, "directory to write scaffolded canonical markdown into")
	if err := fs.Parse(args); err != nil {
		return err
	}

	if err := importer.Import(*vendor, *out); err != nil {
		return err
	}
	fmt.Printf("coursegen import: scaffolded canonical markdown under %s\n", *out)
	return nil
}
