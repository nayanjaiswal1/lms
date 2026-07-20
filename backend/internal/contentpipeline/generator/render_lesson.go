package generator

import (
	"encoding/json"
	"fmt"
	"regexp"
	"strings"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
)

// knowledgeCheckBlockPattern matches a lesson's optional ```knowledge-check
// fenced JSON block. At most one is authored per lesson.
var knowledgeCheckBlockPattern = regexp.MustCompile("(?s)```knowledge-check\\s*\\n(.*?)\\n```")

// parseKnowledgeCheck extracts the server-side grading/gating key
// (id/type/correct per question) out of a lesson body's ```knowledge-check
// fenced block, if present. Returns an empty (non-nil) slice when the lesson
// has no such block, so the caller always emits a valid `[]` jsonb literal
// rather than a bare/untyped empty array.
func parseKnowledgeCheck(body string) ([]knowledgeCheckEntryJSON, error) {
	entries := []knowledgeCheckEntryJSON{}
	match := knowledgeCheckBlockPattern.FindStringSubmatch(body)
	if match == nil {
		return entries, nil
	}
	var src knowledgeCheckSourceJSON
	if err := json.Unmarshal([]byte(match[1]), &src); err != nil {
		return nil, fmt.Errorf("parse knowledge-check block: %w", err)
	}
	for _, q := range src.Questions {
		entry := knowledgeCheckEntryJSON{ID: q.ID, Type: q.Type}
		if q.Type == "mcq" {
			entry.Correct = q.Correct
		}
		entries = append(entries, entry)
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
		"INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)\nVALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)\nON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();\n\n",
		sqlString(moduleID), sqlString(courseID), sqlString(sectionID),
		sqlString(lesson.Title), sqlString(moduleType), sqlInt(lesson.Position),
		dollarQuote("md", lesson.Body), sqlInt(estMinutes), knowledgeCheckJSON,
	)
	return nil
}
