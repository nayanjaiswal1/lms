package importer

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
)

// findRepoRoot walks up from the current working directory until it finds
// content/fast-kubernetes/UPSTREAM.md, so this test works regardless of the
// working directory `go test` is invoked from.
func findRepoRoot(t *testing.T) string {
	t.Helper()
	dir, err := os.Getwd()
	require.NoError(t, err)
	for {
		if _, err := os.Stat(filepath.Join(dir, "content", "fast-kubernetes", "UPSTREAM.md")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Fatal("could not locate repo root (content/fast-kubernetes/UPSTREAM.md not found in any ancestor)")
		}
		dir = parent
	}
}

// TestImport_RealSnapshot runs Import against the real vendored
// content/fast-kubernetes/ snapshot and writes the real scaffolded output to
// content/courses/fast-kubernetes/ — this is the actual deliverable content,
// not a synthetic fixture, per the importer workstream brief.
func TestImport_RealSnapshot(t *testing.T) {
	root := findRepoRoot(t)
	vendorDir := filepath.Join(root, "content", "fast-kubernetes")
	outDir := filepath.Join(root, "content", "courses", "fast-kubernetes")

	require.NoError(t, os.RemoveAll(outDir))
	require.NoError(t, Import(vendorDir, outDir))

	var lessonCount, labCount int
	for _, sec := range Sections {
		lessonPath := filepath.Join(outDir, sec.Slug, "01-lesson.md")
		doc, err := canonical.ParseFile(lessonPath)
		require.NoErrorf(t, err, "parsing lesson for section %q", sec.Slug)
		require.Equal(t, canonical.KindLesson, doc.Kind)
		require.NoErrorf(t, doc.Validate(), "validating lesson for section %q", sec.Slug)
		lessonCount++

		for i, labMeta := range sec.Labs {
			nn := i + 2 // 01 is the lesson, labs start at 02
			labPath := filepath.Join(outDir, sec.Slug, fmt.Sprintf("%02d-lab-%s.md", nn, labMeta.Dir))
			labDoc, err := canonical.ParseFile(labPath)
			require.NoErrorf(t, err, "parsing lab stub %q for section %q", labMeta.Dir, sec.Slug)
			require.Equal(t, canonical.KindLab, labDoc.Kind)
			require.NotNil(t, labDoc.Lab)
			// Lab stubs are an intentional WIP hand-off: Tasks is empty, so
			// full Validate() is expected to fail on the "at least one task
			// required" rule. Assert that specific, expected shape instead
			// of a clean pass.
			require.Empty(t, labDoc.Lab.Tasks, "lab stub %q should have empty tasks awaiting authoring", labMeta.Dir)
			require.NotEmpty(t, labDoc.Lab.Files, "lab stub %q should carry starter files from the upstream labs/ dir", labMeta.Dir)
			err = labDoc.Validate()
			require.Error(t, err, "lab stub %q is expected to fail Validate() until tasks are authored", labMeta.Dir)
			labCount++
		}
	}

	require.Equal(t, len(Sections), lessonCount)
	require.Positive(t, labCount)
	t.Logf("imported %d lesson(s) and %d lab stub(s) across %d section(s)", lessonCount, labCount, len(Sections))
}
