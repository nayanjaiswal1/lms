package canonical

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

const courseMetaFilename = "course.yaml"

var validDifficulties = map[string]bool{
	"beginner": true, "intermediate": true, "advanced": true, "expert": true,
}

// CourseMeta holds the course-level fields no canonical document carries —
// there is no "course" document kind, so title/description/difficulty/tags/
// pricing live in one course.yaml per course directory instead.
type CourseMeta struct {
	Title       string   `yaml:"title"`
	Description string   `yaml:"description"`
	Difficulty  string   `yaml:"difficulty"` // beginner|intermediate|advanced|expert
	Tags        []string `yaml:"tags"`
	IsFree      *bool    `yaml:"is_free"` // pointer: nil (unset) defaults to true, distinct from an explicit false
}

// LoadCourseMeta reads <canonicalDir>/course.yaml. A missing file is not an
// error — it returns a zero-value CourseMeta so courses authored before
// course.yaml existed keep rendering with the generator's historical
// defaults (title-cased slug, "intermediate", etc.) unchanged.
func LoadCourseMeta(canonicalDir string) (CourseMeta, error) {
	path := filepath.Join(canonicalDir, courseMetaFilename)
	raw, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return CourseMeta{}, nil
	}
	if err != nil {
		return CourseMeta{}, fmt.Errorf("canonical.LoadCourseMeta: %s: %w", path, err)
	}

	var meta CourseMeta
	if err := yaml.Unmarshal(raw, &meta); err != nil {
		return CourseMeta{}, fmt.Errorf("canonical.LoadCourseMeta: %s: %w", path, err)
	}
	if meta.Difficulty != "" && !validDifficulties[meta.Difficulty] {
		return CourseMeta{}, fmt.Errorf("canonical.LoadCourseMeta: %s: invalid difficulty %q", path, meta.Difficulty)
	}
	return meta, nil
}
