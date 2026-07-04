package generator

import (
	"fmt"
	"strings"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
)

// renderLesson emits the course_modules(type='notes') row for a Lesson doc.
func renderLesson(out *strings.Builder, courseID, sectionID string, lesson *canonical.Lesson) error {
	moduleID := canonical.ID(lesson.IDKey, "module")
	estMinutes := lesson.EstimatedMinutes
	if estMinutes <= 0 {
		estMinutes = 20
	}

	fmt.Fprintf(out,
		"INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes)\nVALUES (%s, %s, %s, %s, 'notes', %s, %s, %s)\nON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();\n\n",
		sqlString(moduleID), sqlString(courseID), sqlString(sectionID),
		sqlString(lesson.Title), sqlInt(lesson.Position),
		dollarQuote("md", lesson.Body), sqlInt(estMinutes),
	)
	return nil
}
