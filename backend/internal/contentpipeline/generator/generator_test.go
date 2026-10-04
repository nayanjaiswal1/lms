package generator

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
)

func sampleDocs() []*canonical.Document {
	lesson := &canonical.Lesson{
		Common: canonical.Common{
			Kind: canonical.KindLesson, IDKey: "test/section/lesson",
			Course: "test-course", Section: "section", SectionTitle: "Section", SectionPosition: 1,
			Title: "Lesson Title", Position: 0, EstimatedMinutes: 20,
			Source: []string{"upstream.md"},
		},
		Body: "# Hello\n\nSome content with a 'quote' in it.",
	}

	lab := &canonical.Lab{
		Common: canonical.Common{
			Kind: canonical.KindLab, IDKey: "test/section/lab",
			Course: "test-course", Section: "section", SectionTitle: "Section", SectionPosition: 1,
			Title: "Lab Title", Position: 1, EstimatedMinutes: 30,
			Source: []string{"upstream.yaml"},
		},
		LabSpec: canonical.LabSpec{
			LabType: "terminal", Environment: "mindforge/lab-k8s:1.31",
			MaxDuration: 60, MaxResets: 3, HintPenaltyPct: 10, IsRequired: true,
			SetupScript: "#!/bin/bash\necho setup",
			Files: []canonical.LabFile{
				{Path: "demo.yaml", Content: "apiVersion: v1\nkind: Namespace\n"},
			},
			Tasks: []canonical.Task{
				{
					IDKey: "t1", Title: "Task One", Points: 10,
					Description:        "Do the thing.",
					VerificationScript: "#!/bin/bash\nkubectl get ns demo",
					HintContext:        "hint",
					ExplanationContext: "explanation",
					SolutionScript:     "kubectl create namespace demo",
				},
			},
		},
	}

	quiz := &canonical.Quiz{
		Common: canonical.Common{
			Kind: canonical.KindQuiz, IDKey: "test/section/quiz",
			Course: "test-course", Section: "section", SectionTitle: "Section", SectionPosition: 1,
			Title: "Quiz Title", Position: 2, EstimatedMinutes: 20,
			Source: []string{"n/a"},
		},
		PassPercentage: 60, DurationMinutes: 20,
		Questions: []canonical.Question{
			{
				IDKey: "q1", Type: "mcq", Difficulty: "intermediate", Points: 2,
				Prompt: "What is a Pod?",
				Options: []canonical.QuizOption{
					{Text: "A", Correct: false},
					{Text: "B", Correct: true},
				},
				Explanation: "B is correct.",
			},
			{
				IDKey: "q2", Type: "coding", Difficulty: "intermediate", Points: 5,
				Prompt:      "Sum two numbers.",
				Languages:   []string{"python"},
				StarterCode: map[string]string{"python": "print(1)"},
				TestCases: []canonical.QuizTestCase{
					{Stdin: "1 2", Expected: "3", Hidden: false, Weight: 1},
				},
			},
		},
	}

	return []*canonical.Document{
		{Path: "lesson.md", Kind: canonical.KindLesson, Lesson: lesson},
		{Path: "lab.md", Kind: canonical.KindLab, Lab: lab},
		{Path: "quiz.md", Kind: canonical.KindQuiz, Quiz: quiz},
	}
}

func TestRender_Idempotent(t *testing.T) {
	docs := sampleDocs()
	out1, err := Render(docs, canonical.CourseMeta{})
	require.NoError(t, err)
	out2, err := Render(sampleDocs(), canonical.CourseMeta{}) // fresh structs, same content
	require.NoError(t, err)
	require.Equal(t, out1, out2, "Render must be byte-identical across runs on identical input")
}

func TestRender_NeverLeaksSolutionScript(t *testing.T) {
	out, err := Render(sampleDocs(), canonical.CourseMeta{})
	require.NoError(t, err)
	require.NotContains(t, out, "kubectl create namespace demo", "solution_script content must never appear in generated SQL")
}

func TestRender_MutableTablesUseOnConflict(t *testing.T) {
	out, err := Render(sampleDocs(), canonical.CourseMeta{})
	require.NoError(t, err)
	for _, table := range []string{
		"INSERT INTO courses",
		"INSERT INTO course_sections",
		"INSERT INTO course_modules",
		"INSERT INTO lab_definitions",
		"INSERT INTO lab_tasks",
		"INSERT INTO lab_task_versions",
		"INSERT INTO questions",
		"INSERT INTO question_versions",
		"INSERT INTO assessments",
		"INSERT INTO assessment_questions",
	} {
		require.Contains(t, out, table)
	}
	// Every INSERT block in the output is followed somewhere by an
	// ON CONFLICT clause before the next INSERT — spot check counts match.
	inserts := strings.Count(out, "INSERT INTO")
	onConflicts := strings.Count(out, "ON CONFLICT")
	require.Equal(t, inserts, onConflicts, "every INSERT must have a matching ON CONFLICT clause")
}

func TestRender_DeterministicIDsMatchCanonicalPackage(t *testing.T) {
	out, err := Render(sampleDocs(), canonical.CourseMeta{})
	require.NoError(t, err)
	labID := canonical.ID("test/section/lab", "lab")
	require.Contains(t, out, labID)
}

func TestRender_EmptyInputErrors(t *testing.T) {
	_, err := Render(nil, canonical.CourseMeta{})
	require.Error(t, err)
}

func TestRender_CourseMetaOverridesDefaults(t *testing.T) {
	notFree := false
	meta := canonical.CourseMeta{
		Title:       "Test Course Title",
		Description: "A custom description.",
		Difficulty:  "advanced",
		Tags:        []string{"go", "backend"},
		IsFree:      &notFree,
	}
	out, err := Render(sampleDocs(), meta)
	require.NoError(t, err)
	require.Contains(t, out, "Test Course Title")
	require.Contains(t, out, "A custom description.")
	require.Contains(t, out, "'advanced'")
	require.Contains(t, out, "ARRAY['go','backend']")
	require.NotContains(t, out, "kubernetes")
}

func TestRender_CourseMetaDefaultsWhenEmpty(t *testing.T) {
	out, err := Render(sampleDocs(), canonical.CourseMeta{})
	require.NoError(t, err)
	require.Contains(t, out, "'intermediate'")
	require.Contains(t, out, "true") // is_free defaults true
}

func TestParseKnowledgeCheck_MergesMultipleBlocks(t *testing.T) {
	body := "# Concept A\n\ntext\n\n```knowledge-check\n" +
		`{"questions":[{"id":"q1","type":"mcq","correct":"a"}]}` +
		"\n```\n\n# Concept B\n\ntext\n\n```knowledge-check\n" +
		`{"questions":[{"id":"q2","type":"mcq","correct":"b"}]}` +
		"\n```\n"
	entries, err := parseKnowledgeCheck(body)
	require.NoError(t, err)
	require.Len(t, entries, 2)
	require.Equal(t, "q1", entries[0].ID)
	require.Equal(t, "a", entries[0].Correct)
	require.Equal(t, "q2", entries[1].ID)
	require.Equal(t, "b", entries[1].Correct)
}

func TestParseKnowledgeCheck_DuplicateIDAcrossBlocksErrors(t *testing.T) {
	body := "```knowledge-check\n" +
		`{"questions":[{"id":"dup","type":"mcq","correct":"a"}]}` +
		"\n```\n\n```knowledge-check\n" +
		`{"questions":[{"id":"dup","type":"mcq","correct":"b"}]}` +
		"\n```\n"
	_, err := parseKnowledgeCheck(body)
	require.Error(t, err)
	require.Contains(t, err.Error(), `duplicate knowledge-check question id "dup"`)
}

func TestParseKnowledgeCheck_NoBlockReturnsEmptyNonNilSlice(t *testing.T) {
	entries, err := parseKnowledgeCheck("# Just prose\n\nNo checks here.")
	require.NoError(t, err)
	require.NotNil(t, entries)
	require.Empty(t, entries)
}

func TestRender_HybridLessonWithAttachedLab(t *testing.T) {
	lesson := &canonical.Lesson{
		Common: canonical.Common{
			Kind: canonical.KindLesson, IDKey: "test/section/hybrid-lesson",
			Course: "test-course", Section: "section", SectionTitle: "Section", SectionPosition: 1,
			Title: "Hybrid Lesson", Position: 0, EstimatedMinutes: 40,
			Source: []string{"upstream.md"},
		},
		Body: "# Concept one\n\n[[lab-task:1]]\n\n# Concept two\n\n[[lab-task:2]]\n",
		Lab: &canonical.LabSpec{
			LabType: "terminal", Environment: "mindforge/lab-docker:27",
			MaxDuration: 45, MaxResets: 3,
			Tasks: []canonical.Task{
				{IDKey: "t1", Title: "Task One", Points: 10, Description: "Do thing one.", VerificationScript: "true"},
				{IDKey: "t2", Title: "Task Two", Points: 10, Description: "Do thing two.", VerificationScript: "true"},
			},
		},
	}
	docs := []*canonical.Document{{Path: "hybrid.md", Kind: canonical.KindLesson, Lesson: lesson}}

	out, err := Render(docs, canonical.CourseMeta{})
	require.NoError(t, err)

	require.Equal(t, 1, strings.Count(out, "INSERT INTO course_modules"), "hybrid lesson must emit exactly one course_modules row")
	require.Contains(t, out, "'notes'")

	moduleID := canonical.ID(lesson.IDKey, "module")
	require.Contains(t, out, "INSERT INTO lab_definitions")
	require.Contains(t, out, moduleID, "lab_definitions.module_id must be the notes module's own id")
	require.Contains(t, out, "INSERT INTO lab_tasks")
	require.Contains(t, out, "INSERT INTO lab_task_versions")
	require.Contains(t, out, "INSERT INTO lab_task_version_items")
	require.Contains(t, out, fmt.Sprintf("UPDATE lab_definitions\nSET is_published = true, published_version_id = %s", sqlString(canonical.ID(lesson.IDKey, "version"))))
}

func TestLoad_InvalidDocumentAggregatesErrors(t *testing.T) {
	dir := t.TempDir()
	// missing course/section/title, empty body
	require.NoError(t, os.WriteFile(filepath.Join(dir, "bad.md"), []byte("---\nkind: lesson\nid_key: x\n---\n"), 0o644))
	_, err := Load(dir)
	require.Error(t, err)
	require.Contains(t, err.Error(), "course is required")
}

// Tasks/questions removed from a document must be pruned on reseed, and
// surviving tasks parked off their positions before the upsert, or a new task
// landing on an old task's position violates UNIQUE(lab_id, position).
func TestRender_PrunesRemovedTasksAndQuestions(t *testing.T) {
	out, err := Render(sampleDocs(), canonical.CourseMeta{})
	require.NoError(t, err)

	labID := canonical.ID("test/section/lab", "lab")
	taskID := canonical.ID("test/section/lab", "task:t1")
	require.Contains(t, out, fmt.Sprintf("DELETE FROM lab_tasks WHERE lab_id = '%s' AND id NOT IN ('%s');", labID, taskID))
	park := strings.Index(out, fmt.Sprintf("UPDATE lab_tasks SET position = position + 100000 WHERE lab_id = '%s';", labID))
	insert := strings.Index(out, "INSERT INTO lab_tasks")
	require.True(t, park >= 0 && park < insert, "tasks must be parked before the lab_tasks upsert")
	require.Contains(t, out, "ON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title")

	assessmentID := canonical.ID("test/section/quiz", "assessment")
	require.Contains(t, out, fmt.Sprintf("DELETE FROM assessment_questions WHERE assessment_id = '%s' AND question_id NOT IN (", assessmentID))
	require.Contains(t, out, "ON CONFLICT (id) DO UPDATE SET type=EXCLUDED.type")
}

// A section's group_title comes from the first document seen for that
// section (same first-wins rule already used for section_title), and is
// NULL when no document sets section_group.
func TestRender_SectionGroupTitle(t *testing.T) {
	docs := sampleDocs()
	docs[0].Lesson.SectionGroup = "Backend"

	out, err := Render(docs, canonical.CourseMeta{})
	require.NoError(t, err)
	require.Contains(t, out, "INSERT INTO course_sections (id, course_id, title, position, group_title)")
	require.Contains(t, out, "ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, group_title=EXCLUDED.group_title;")
	require.Contains(t, out, "'Backend'")
}

func TestRender_SectionGroupTitleNullWhenUnset(t *testing.T) {
	out, err := Render(sampleDocs(), canonical.CourseMeta{})
	require.NoError(t, err)
	sectionID := canonical.ID("test-course/section", "section")
	require.Contains(t, out, fmt.Sprintf("VALUES (%s, %s, 'Section', 1, NULL)", sqlString(sectionID), sqlString(canonical.ID("test-course", "course"))))
}

// A section/module removed from the canonical markdown (merged lesson,
// deleted quiz, etc.) must actually disappear from course_sections/
// course_modules on reseed instead of lingering forever, and existing rows
// must be parked off their positions before the per-course upserts run so a
// new row landing on a stale row's position doesn't violate
// UNIQUE(course_id/section_id, position).
func TestRender_PrunesRemovedSectionsAndModules(t *testing.T) {
	out, err := Render(sampleDocs(), canonical.CourseMeta{})
	require.NoError(t, err)

	courseID := canonical.ID("test-course", "course")
	sectionID := canonical.ID("test-course/section", "section")
	lessonModuleID := canonical.ID("test/section/lesson", "module")
	labModuleID := canonical.ID("test/section/lab", "module")
	quizModuleID := canonical.ID("test/section/quiz", "module")

	parkSections := fmt.Sprintf("UPDATE course_sections SET position = position + 100000 WHERE course_id = %s;", sqlString(courseID))
	parkModules := fmt.Sprintf("UPDATE course_modules SET position = position + 100000 WHERE course_id = %s;", sqlString(courseID))
	require.Contains(t, out, parkSections)
	require.Contains(t, out, parkModules)

	sectionInsert := strings.Index(out, "INSERT INTO course_sections (id, course_id, title, position, group_title)")
	require.True(t, strings.Index(out, parkSections) < sectionInsert, "sections must be parked before the course_sections upsert")
	require.True(t, strings.Index(out, parkModules) < sectionInsert, "modules must be parked before any module upsert")

	pruneModules := fmt.Sprintf("DELETE FROM course_modules WHERE course_id = %s AND id NOT IN (%s, %s, %s);",
		sqlString(courseID), sqlString(lessonModuleID), sqlString(labModuleID), sqlString(quizModuleID))
	pruneSections := fmt.Sprintf("DELETE FROM course_sections WHERE course_id = %s AND id NOT IN (%s);", sqlString(courseID), sqlString(sectionID))
	require.Contains(t, out, pruneModules)
	require.Contains(t, out, pruneSections)
	require.True(t, strings.Index(out, pruneModules) < strings.Index(out, pruneSections), "modules must be pruned before their sections, never via section-delete cascade")
	require.True(t, strings.Index(out, pruneModules) > sectionInsert, "pruning must run after this course's sections/modules are emitted")
}

// section_group must agree across every document in the same (course,
// section) — Render (like it already does for section_title) only takes the
// first value it sees and silently ignores the rest, so a mismatch has to be
// caught at Load time or an author's typo would silently detach a section
// from its intended group.
func TestLoad_SectionGroupMismatchErrors(t *testing.T) {
	dir := t.TempDir()
	docA := "---\nkind: lesson\nid_key: a\ncourse: c\nsection: s\nsection_title: S\nsection_position: 0\nsection_group: Backend\ntitle: A\nposition: 0\nestimated_minutes: 10\nsource: [x.md]\n---\nbody\n"
	docB := "---\nkind: lesson\nid_key: b\ncourse: c\nsection: s\nsection_title: S\nsection_position: 0\nsection_group: Frontend\ntitle: B\nposition: 1\nestimated_minutes: 10\nsource: [x.md]\n---\nbody\n"
	require.NoError(t, os.WriteFile(filepath.Join(dir, "a.md"), []byte(docA), 0o644))
	require.NoError(t, os.WriteFile(filepath.Join(dir, "b.md"), []byte(docB), 0o644))

	_, err := Load(dir)
	require.Error(t, err)
	require.Contains(t, err.Error(), "section_group")
	require.Contains(t, err.Error(), `"Frontend"`)
	require.Contains(t, err.Error(), `"Backend"`)
}
