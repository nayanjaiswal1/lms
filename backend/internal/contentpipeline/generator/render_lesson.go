package generator

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strings"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
)

// knowledgeCheckBlockPattern matches a lesson's ```knowledge-check fenced
// JSON blocks. A lesson may author more than one — e.g. one small check
// placed after each ## concept heading, rather than a single block batching
// every concept at the end — and every block found is merged into one
// course_modules.knowledge_check array.
var knowledgeCheckBlockPattern = regexp.MustCompile("(?s)```knowledge-check\\s*\\n(.*?)\\n```")

// parseKnowledgeCheck extracts the server-side grading/gating key
// (id/type/correct per question) out of every ```knowledge-check fenced
// block in a lesson body, if any. Returns an empty (non-nil) slice when the
// lesson has no such block, so the caller always emits a valid `[]` jsonb
// literal rather than a bare/untyped empty array. Errors if two blocks in the
// same lesson declare the same question id — a likely copy-paste mistake
// when authoring one block per concept — since a duplicate id would grade
// one question against the other's answer key.
func parseKnowledgeCheck(body string) ([]knowledgeCheckEntryJSON, error) {
	entries := []knowledgeCheckEntryJSON{}
	seen := map[string]bool{}
	for _, match := range knowledgeCheckBlockPattern.FindAllStringSubmatch(body, -1) {
		var src knowledgeCheckSourceJSON
		if err := json.Unmarshal([]byte(match[1]), &src); err != nil {
			return nil, fmt.Errorf("parse knowledge-check block: %w", err)
		}
		for _, q := range src.Questions {
			if seen[q.ID] {
				return nil, fmt.Errorf("duplicate knowledge-check question id %q", q.ID)
			}
			seen[q.ID] = true
			entry := knowledgeCheckEntryJSON{ID: q.ID, Type: q.Type}
			if q.Type == "mcq" {
				entry.Correct = q.Correct
			}
			entries = append(entries, entry)
		}
	}
	return entries, nil
}

// renderLesson emits the course_modules row for a Lesson doc — type='notes'
// unless the frontmatter's `type:` override names another allowed type (see
// canonical.validLessonModuleTypeOverrides).
func renderLesson(out *strings.Builder, courseID, sectionID string, lesson *canonical.Lesson) error {
	moduleID := canonical.ID(lesson.IDKey, "module")
	estMinutes := lesson.EstimatedMinutes
	if estMinutes <= 0 {
		estMinutes = 20
	}
	moduleType := lesson.ModuleType
	if moduleType == "" {
		moduleType = "notes"
	}

	knowledgeCheck, err := parseKnowledgeCheck(lesson.Body)
	if err != nil {
		return fmt.Errorf("lesson %s: %w", lesson.IDKey, err)
	}
	knowledgeCheckJSON, err := sqlJSONB(knowledgeCheck)
	if err != nil {
		return fmt.Errorf("lesson %s: %w", lesson.IDKey, err)
	}

	fmt.Fprintf(out,
		"INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)\nVALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)\nON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();\n\n",
		sqlString(moduleID), sqlString(courseID), sqlString(sectionID),
		sqlString(lesson.Title), sqlString(moduleType), sqlInt(lesson.Position),
		dollarQuote("md", lesson.Body), sqlInt(estMinutes), knowledgeCheckJSON,
	)

	if lesson.Lab != nil {
		return renderLabRows(out, courseID, moduleID, lesson.IDKey, lesson.Title, lesson.Lab)
	}
	return nil
}
