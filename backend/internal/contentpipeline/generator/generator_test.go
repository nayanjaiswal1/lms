package generator

import (
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
	out1, err := Render(docs)
	require.NoError(t, err)
	out2, err := Render(sampleDocs()) // fresh structs, same content
	require.NoError(t, err)
	require.Equal(t, out1, out2, "Render must be byte-identical across runs on identical input")
}

func TestRender_NeverLeaksSolutionScript(t *testing.T) {
	out, err := Render(sampleDocs())
	require.NoError(t, err)
	require.NotContains(t, out, "kubectl create namespace demo", "solution_script content must never appear in generated SQL")
}

func TestRender_MutableTablesUseOnConflict(t *testing.T) {
	out, err := Render(sampleDocs())
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
	out, err := Render(sampleDocs())
	require.NoError(t, err)
	labID := canonical.ID("test/section/lab", "lab")
	require.Contains(t, out, labID)
}

func TestRender_EmptyInputErrors(t *testing.T) {
	_, err := Render(nil)
	require.Error(t, err)
}

func TestLoad_InvalidDocumentAggregatesErrors(t *testing.T) {
	dir := t.TempDir()
	// missing course/section/title, empty body
	require.NoError(t, os.WriteFile(filepath.Join(dir, "bad.md"), []byte("---\nkind: lesson\nid_key: x\n---\n"), 0o644))
	_, err := Load(dir)
	require.Error(t, err)
	require.Contains(t, err.Error(), "course is required")
}
