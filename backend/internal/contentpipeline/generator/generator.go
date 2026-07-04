// Package generator renders Canonical Markdown documents (backend/internal/contentpipeline/canonical)
// into idempotent SQL fixtures matching MindForge's courses/labs/assessment schema exactly —
// the fixture-generator stage of the content pipeline: canonical markdown -> generated SQL -> DB.
package generator

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
)

// Seeded MindForge dev IDs this generator's output is attributed to. These are
// not content-pipeline-generic; the generator already targets MindForge's
// specific schema and fixture-loading convention (docker cp + psql -f into
// the dev database seeded by backend/db/fixtures/dev_seed.sql), so reusing
// the real seeded org/instructor/student rows here is consistent with that
// scope, not a layering violation.
const (
	seededOrgID        = "00000000-0000-0000-0000-000000000001"
	seededInstructorID = "00000000-0000-0000-0000-000000000012" // course creator_id / created_by
	seededStudentID    = "00000000-0000-0000-0000-000000000014" // student@mindforge.dev, auto-enrolled
)

// Generate loads every canonical markdown file under canonicalDir, validates
// all of them, and writes the rendered idempotent SQL fixture to
// outputSQLPath. It writes nothing if any document fails to parse or
// validate — partial/broken SQL is never an acceptable output.
func Generate(canonicalDir, outputSQLPath string) error {
	docs, err := Load(canonicalDir)
	if err != nil {
		return fmt.Errorf("generator.Generate: %w", err)
	}

	sql, err := Render(docs)
	if err != nil {
		return fmt.Errorf("generator.Generate: %w", err)
	}

	if err := os.MkdirAll(filepath.Dir(outputSQLPath), 0o755); err != nil {
		return fmt.Errorf("generator.Generate: creating output directory: %w", err)
	}
	if err := os.WriteFile(outputSQLPath, []byte(sql), 0o644); err != nil {
		return fmt.Errorf("generator.Generate: writing %q: %w", outputSQLPath, err)
	}
	return nil
}

// Load walks canonicalDir for every *.md file, parses it as Canonical
// Markdown, and validates it. All parse/validate errors across all files are
// collected and returned together (via errors.Join) so an author sees every
// problem in one pass instead of fixing files one at a time. Returned
// documents are sorted by (Course, SectionPosition, Position) for
// deterministic, diffable output.
func Load(canonicalDir string) ([]*canonical.Document, error) {
	var docs []*canonical.Document
	var errs []error

	walkErr := filepath.WalkDir(canonicalDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() || !strings.HasSuffix(path, ".md") {
			return nil
		}

		doc, parseErr := canonical.ParseFile(path)
		if parseErr != nil {
			errs = append(errs, parseErr)
			return nil
		}
		if validateErr := doc.Validate(); validateErr != nil {
			errs = append(errs, fmt.Errorf("%s: %w", path, validateErr))
			return nil
		}
		docs = append(docs, doc)
		return nil
	})
	if walkErr != nil {
		return nil, fmt.Errorf("generator.Load: walking %q: %w", canonicalDir, walkErr)
	}
	if len(errs) > 0 {
		return nil, fmt.Errorf("generator.Load: %d document(s) failed validation:\n%w", len(errs), errors.Join(errs...))
	}

	sort.Slice(docs, func(i, j int) bool {
		ci, cj := commonOf(docs[i]), commonOf(docs[j])
		if ci.Course != cj.Course {
			return ci.Course < cj.Course
		}
		if ci.SectionPosition != cj.SectionPosition {
			return ci.SectionPosition < cj.SectionPosition
		}
		return ci.Position < cj.Position
	})

	return docs, nil
}

// commonOf extracts the shared Common frontmatter fields regardless of the
// document's concrete kind.
func commonOf(doc *canonical.Document) canonical.Common {
	switch doc.Kind {
	case canonical.KindLesson:
		return doc.Lesson.Common
	case canonical.KindQuiz:
		return doc.Quiz.Common
	case canonical.KindLab:
		return doc.Lab.Common
	default:
		return canonical.Common{}
	}
}
