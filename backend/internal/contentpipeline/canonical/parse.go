package canonical

import (
	"fmt"
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

const frontmatterDelim = "---"

// Document is the discriminated union returned by ParseFile: exactly one of
// Lesson, Quiz, or Lab is set, matching Kind.
type Document struct {
	Path   string // the source file path, for error messages elsewhere in the pipeline
	Kind   Kind
	Lesson *Lesson // set iff Kind == KindLesson
	Quiz   *Quiz   // set iff Kind == KindQuiz
	Lab    *Lab    // set iff Kind == KindLab
}

// SplitFrontmatter finds the leading "---" delimiter pair and splits raw into
// the YAML frontmatter between them and the markdown body after the second
// delimiter, trimmed of at most one leading newline (a blank separator line
// between the closing delimiter and the body is conventional but optional).
func SplitFrontmatter(raw []byte) (frontmatter []byte, body string, err error) {
	lines := strings.Split(string(raw), "\n")
	if len(lines) == 0 || strings.TrimRight(lines[0], "\r") != frontmatterDelim {
		return nil, "", fmt.Errorf("canonical.SplitFrontmatter: file does not start with a %q frontmatter delimiter", frontmatterDelim)
	}

	endIdx := -1
	for i := 1; i < len(lines); i++ {
		if strings.TrimRight(lines[i], "\r") == frontmatterDelim {
			endIdx = i
			break
		}
	}
	if endIdx == -1 {
		return nil, "", fmt.Errorf("canonical.SplitFrontmatter: missing closing %q frontmatter delimiter", frontmatterDelim)
	}

	frontmatter = []byte(strings.Join(lines[1:endIdx], "\n"))
	body = strings.Join(lines[endIdx+1:], "\n")
	body = strings.TrimPrefix(body, "\n")
	return frontmatter, body, nil
}

// kindProbe unmarshals only enough of the frontmatter to discriminate the
// concrete document type before doing the full unmarshal.
type kindProbe struct {
	Kind Kind `yaml:"kind"`
}

// ParseFile reads path, splits it into frontmatter and body, and unmarshals
// the frontmatter into the concrete type selected by its "kind" field.
func ParseFile(path string) (*Document, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("canonical.ParseFile: %s: %w", path, err)
	}

	fm, body, err := SplitFrontmatter(raw)
	if err != nil {
		return nil, fmt.Errorf("canonical.ParseFile: %s: %w", path, err)
	}

	var probe kindProbe
	if err := yaml.Unmarshal(fm, &probe); err != nil {
		return nil, fmt.Errorf("canonical.ParseFile: %s: %w", path, err)
	}

	doc := &Document{Path: path, Kind: probe.Kind}

	switch probe.Kind {
	case KindLesson:
		var lesson Lesson
		if err := yaml.Unmarshal(fm, &lesson); err != nil {
			return nil, fmt.Errorf("canonical.ParseFile: %s: %w", path, err)
		}
		lesson.Body = body
		doc.Lesson = &lesson

	case KindQuiz:
		var quiz Quiz
		if err := yaml.Unmarshal(fm, &quiz); err != nil {
			return nil, fmt.Errorf("canonical.ParseFile: %s: %w", path, err)
		}
		// Quiz has no Body field in the schema (questions carry all
		// content); the trailing markdown, if any, is intentionally
		// discarded rather than silently dropped into an unexported
		// field nothing would ever read.
		doc.Quiz = &quiz

	case KindLab:
		var lab Lab
		if err := yaml.Unmarshal(fm, &lab); err != nil {
			return nil, fmt.Errorf("canonical.ParseFile: %s: %w", path, err)
		}
		// Same reasoning as Quiz above: Lab has no Body field, content
		// lives in Description/SetupScript/Files.
		doc.Lab = &lab

	default:
		return nil, fmt.Errorf("canonical.ParseFile: %s: unknown kind %q", path, probe.Kind)
	}

	return doc, nil
}
