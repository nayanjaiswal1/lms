package main

import (
	"fmt"
	"io/fs"
	"path/filepath"
	"sort"
	"strings"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
)

// auditExempt lists vendored files that are not educational content and so
// are never expected to be cited by any canonical document's source: list.
var auditExempt = map[string]bool{
	"UPSTREAM.md": true,
	"LICENSE":     true,
	"index.html":  true,
}

func runAudit(args []string) error {
	fs2 := newFlagSet("audit")
	vendor := fs2.String("vendor", defaultVendorDir, "vendored upstream snapshot directory")
	canonicalDir := fs2.String("canonical", defaultCanonicalDir, "canonical markdown directory")
	if err := fs2.Parse(args); err != nil {
		return err
	}

	vendored, err := listVendoredFiles(*vendor)
	if err != nil {
		return fmt.Errorf("listing vendored files: %w", err)
	}

	covered, err := collectSourceCoverage(*canonicalDir)
	if err != nil {
		return fmt.Errorf("collecting source coverage: %w", err)
	}

	var uncovered []string
	for _, rel := range vendored {
		if auditExempt[rel] {
			continue
		}
		if !covered[rel] {
			uncovered = append(uncovered, rel)
		}
	}
	sort.Strings(uncovered)

	if len(uncovered) > 0 {
		fmt.Printf("coursegen audit: %d/%d vendored file(s) have NO canonical source: coverage:\n", len(uncovered), len(vendored))
		for _, rel := range uncovered {
			fmt.Printf("  - %s\n", rel)
		}
		return fmt.Errorf("%d uncovered upstream file(s)", len(uncovered))
	}

	fmt.Printf("coursegen audit: 100%% coverage — all %d vendored file(s) (minus %d exempt) are cited by canonical markdown\n", len(vendored), len(auditExempt))
	return nil
}

// listVendoredFiles returns every regular file under vendorDir, as paths
// relative to vendorDir with forward slashes, sorted.
func listVendoredFiles(vendorDir string) ([]string, error) {
	var rels []string
	err := filepath.WalkDir(vendorDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		rel, relErr := filepath.Rel(vendorDir, path)
		if relErr != nil {
			return relErr
		}
		rels = append(rels, filepath.ToSlash(rel))
		return nil
	})
	if err != nil {
		return nil, err
	}
	sort.Strings(rels)
	return rels, nil
}

// collectSourceCoverage parses every canonical markdown file under
// canonicalDir and returns the set of every upstream filename cited across
// all documents' source: lists.
func collectSourceCoverage(canonicalDir string) (map[string]bool, error) {
	covered := map[string]bool{}
	err := filepath.WalkDir(canonicalDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() || !strings.HasSuffix(path, ".md") {
			return nil
		}
		doc, parseErr := canonical.ParseFile(path)
		if parseErr != nil {
			return fmt.Errorf("%s: %w", path, parseErr)
		}
		for _, src := range sourceOf(doc) {
			covered[src] = true
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return covered, nil
}

// sourceOf returns the Source field regardless of the document's concrete kind.
func sourceOf(doc *canonical.Document) []string {
	switch doc.Kind {
	case canonical.KindLesson:
		if doc.Lesson != nil {
			return doc.Lesson.Source
		}
	case canonical.KindQuiz:
		if doc.Quiz != nil {
			return doc.Quiz.Source
		}
	case canonical.KindLab:
		if doc.Lab != nil {
			return doc.Lab.Source
		}
	}
	return nil
}
