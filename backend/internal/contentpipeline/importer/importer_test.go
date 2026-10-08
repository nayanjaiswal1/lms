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
// content/fast-kubernetes/ snapshot into a temp dir. It must never write to
// content/courses/fast-kubernetes/: that directory holds hand-authored
// lessons, labs, and quizzes, and an earlier version of this test that
// RemoveAll'd it wiped every authored lab task and quiz on each `go test`.
func TestImport_RealSnapshot(t *testing.T) {
	root := findRepoRoot(t)
	vendorDir := filepath.Join(root, "content", "fast-kubernetes")
	outDir := t.TempDir()

	require.NoError(t, Import(vendorDir, outDir))
	require.Error(t, Import(vendorDir, outDir), "re-import over existing files must refuse instead of overwriting")

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
			// Task authoring state is upstream-content state, not import behaviour,
			// so only the import guarantee is asserted: starter files come through.
			require.NotEmpty(t, labDoc.Lab.Files, "lab stub %q should carry starter files from the upstream labs/ dir", labMeta.Dir)
			labCount++
		}
	}

	require.Equal(t, len(Sections), lessonCount)
	require.Positive(t, labCount)
	t.Logf("imported %d lesson(s) and %d lab stub(s) across %d section(s)", lessonCount, labCount, len(Sections))
}
