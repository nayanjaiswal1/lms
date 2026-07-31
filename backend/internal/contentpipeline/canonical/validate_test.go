package canonical_test

import (
	"testing"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func baseCommon() canonical.Common {
	return canonical.Common{
		Kind:             canonical.KindLesson,
		IDKey:            "k8s/pods/lesson",
		Course:           "fast-kubernetes",
		Section:          "pod-fundamentals",
		SectionTitle:     "Pod Fundamentals",
		SectionPosition:  0,
		Title:            "Pods",
		Position:         0,
		EstimatedMinutes: 30,
		Source:           []string{"K8s-Pod.md"},
	}
}

func TestLessonValidate(t *testing.T) {
	tests := []struct {
		name    string
		lesson  canonical.Lesson
		wantErr bool
	}{
		{
			name:   "valid",
			lesson: canonical.Lesson{Common: baseCommon(), Body: "# Pods\n\nContent."},
		},
		{
			name:    "empty body rejected",
			lesson:  canonical.Lesson{Common: baseCommon(), Body: "   \n  "},
			wantErr: true,
		},
		{
			name: "missing id_key rejected",
			lesson: func() canonical.Lesson {
				c := baseCommon()
				c.IDKey = ""
				return canonical.Lesson{Common: c, Body: "content"}
			}(),
			wantErr: true,
		},
		{
			name: "negative position rejected",
			lesson: func() canonical.Lesson {
				c := baseCommon()
				c.Position = -1
				return canonical.Lesson{Common: c, Body: "content"}
			}(),
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.lesson.Validate()
			if tt.wantErr {
				require.Error(t, err)
			} else {
				require.NoError(t, err)
			}
		})
	}
}

func validLabSpec() *canonical.LabSpec {
	return &canonical.LabSpec{
		LabType:     "terminal",
		Environment: "mindforge/lab-docker:27",
		MaxDuration: 45,
		MaxResets:   3,
		Tasks:       []canonical.Task{validTask(), validTask()},
	}
}

func TestLessonValidate_AttachedLab(t *testing.T) {
	tests := []struct {
		name      string
		body      string
		lab       *canonical.LabSpec
		wantErr   bool
		errSubstr string
	}{
		{
			name: "valid hybrid lesson with markers matching every task",
			body: "# Concept\n\n[[lab-task:1]]\n\n# Concept two\n\n[[lab-task:2]]\n",
			lab:  validLabSpec(),
		},
		{
			name:      "lab with tasks but no marker is unreachable",
			body:      "# Concept\n\nJust prose, no marker.",
			lab:       validLabSpec(),
			wantErr:   true,
			errSubstr: "would be unreachable",
		},
		{
			name:      "marker position beyond task count",
			body:      "[[lab-task:1]]\n\n[[lab-task:5]]\n",
			lab:       validLabSpec(),
			wantErr:   true,
			errSubstr: "does not match any of the lab's 2 task(s)",
		},
		{
			name:      "marker present with no lab attached",
			body:      "# Concept\n\n[[lab-task:1]]\n",
			lab:       nil,
			wantErr:   true,
			errSubstr: "no lab: block is attached",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			lesson := canonical.Lesson{Common: baseCommon(), Body: tt.body, Lab: tt.lab}
			err := lesson.Validate()
			if tt.wantErr {
				require.Error(t, err)
				if tt.errSubstr != "" {
					assert.Contains(t, err.Error(), tt.errSubstr)
				}
			} else {
				require.NoError(t, err)
			}
		})
	}
}

func validQuestion() canonical.Question {
	return canonical.Question{
		IDKey:      "q1",
		Type:       "mcq",
		Difficulty: "beginner",
		Points:     2,
		Prompt:     "Which is correct?",
		Multiple:   false,
		Options: []canonical.QuizOption{
			{Text: "a", Correct: false},
			{Text: "b", Correct: true},
		},
	}
}

func TestQuizValidate(t *testing.T) {
	tests := []struct {
		name      string
		mutate    func(q *canonical.Quiz)
		wantErr   bool
		errSubstr string
	}{
		{
			name:   "valid",
			mutate: func(q *canonical.Quiz) {},
		},
		{
			name: "zero questions rejected",
			mutate: func(q *canonical.Quiz) {
				q.Questions = nil
			},
			wantErr:   true,
			errSubstr: "at least one question",
		},
		{
			name: "mcq zero correct options rejected",
			mutate: func(q *canonical.Quiz) {
				q.Questions[0].Options = []canonical.QuizOption{
					{Text: "a", Correct: false},
					{Text: "b", Correct: false},
				}
			},
			wantErr:   true,
			errSubstr: "at least one correct option",
		},
		{
			name: "mcq single-correct requires exactly one when multiple=false",
			mutate: func(q *canonical.Quiz) {
				q.Questions[0].Options = []canonical.QuizOption{
					{Text: "a", Correct: true},
					{Text: "b", Correct: true},
				}
			},
			wantErr:   true,
			errSubstr: "exactly one correct option",
		},
		{
			name: "mcq multiple=true allows more than one correct",
			mutate: func(q *canonical.Quiz) {
				q.Questions[0].Multiple = true
				q.Questions[0].Options = []canonical.QuizOption{
					{Text: "a", Correct: true},
					{Text: "b", Correct: true},
				}
			},
			wantErr: false,
		},
		{
			name: "mcq fewer than 2 options rejected",
			mutate: func(q *canonical.Quiz) {
				q.Questions[0].Options = []canonical.QuizOption{{Text: "a", Correct: true}}
			},
			wantErr:   true,
			errSubstr: "at least 2 options",
		},
		{
			name: "coding with zero test cases rejected",
			mutate: func(q *canonical.Quiz) {
				q.Questions[0].Type = "coding"
				q.Questions[0].TestCases = nil
			},
			wantErr:   true,
			errSubstr: "at least one test case",
		},
		{
			name: "coding with test cases valid",
			mutate: func(q *canonical.Quiz) {
				q.Questions[0].Type = "coding"
				q.Questions[0].TestCases = []canonical.QuizTestCase{
					{Stdin: "", Expected: "ok", Hidden: false, Weight: 1},
				}
			},
			wantErr: false,
		},
		{
			name: "unknown question type rejected",
			mutate: func(q *canonical.Quiz) {
				q.Questions[0].Type = "essay"
			},
			wantErr:   true,
			errSubstr: "invalid type",
		},
		{
			name: "pass_percentage out of range rejected",
			mutate: func(q *canonical.Quiz) {
				q.PassPercentage = 150
			},
			wantErr:   true,
			errSubstr: "pass_percentage",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			c := baseCommon()
			c.Kind = canonical.KindQuiz
			q := canonical.Quiz{
				Common:          c,
				PassPercentage:  60,
				DurationMinutes: 20,
				Questions:       []canonical.Question{validQuestion()},
			}
			tt.mutate(&q)

			err := q.Validate()
			if tt.wantErr {
				require.Error(t, err)
				if tt.errSubstr != "" {
					assert.Contains(t, err.Error(), tt.errSubstr)
				}
			} else {
				require.NoError(t, err)
			}
		})
	}
}

func validTask() canonical.Task {
	return canonical.Task{
		IDKey:              "t1",
		Title:              "Create the namespace",
		Points:             10,
		IsOptional:         false,
		IsStateful:         false,
		Description:        "Create a namespace named demo.",
		VerificationScript: "#!/bin/bash\nkubectl get namespace demo",
		HintContext:        "kubectl create namespace demo",
		ExplanationContext: "Namespaces scope names.",
	}
}

func TestLabValidate(t *testing.T) {
	tests := []struct {
		name      string
		mutate    func(l *canonical.Lab)
		wantErr   bool
		errSubstr string
	}{
		{
			name:   "valid",
			mutate: func(l *canonical.Lab) {},
		},
		{
			name: "invalid lab_type rejected",
			mutate: func(l *canonical.Lab) {
				l.LabType = "vm"
			},
			wantErr:   true,
			errSubstr: "invalid lab_type",
		},
		{
			name: "empty environment rejected",
			mutate: func(l *canonical.Lab) {
				l.Environment = ""
			},
			wantErr:   true,
			errSubstr: "environment",
		},
		{
			name: "zero tasks rejected for terminal lab",
			mutate: func(l *canonical.Lab) {
				l.Tasks = nil
			},
			wantErr:   true,
			errSubstr: "at least one task",
		},
		{
			name: "zero tasks allowed for playground lab",
			mutate: func(l *canonical.Lab) {
				l.LabType = "playground"
				l.IsRequired = false
				l.Tasks = nil
			},
			wantErr: false,
		},
		{
			name: "zero tasks allowed for sandbox lab",
			mutate: func(l *canonical.Lab) {
				l.LabType = "sandbox"
				l.IsRequired = false
				l.Tasks = nil
			},
			wantErr: false,
		},
		{
			name: "sandbox lab with tasks accepted",
			mutate: func(l *canonical.Lab) {
				l.LabType = "sandbox"
			},
			wantErr: false,
		},
		{
			name: "is_required with only optional tasks rejected",
			mutate: func(l *canonical.Lab) {
				l.IsRequired = true
				task := validTask()
				task.IsOptional = true
				l.Tasks = []canonical.Task{task}
			},
			wantErr:   true,
			errSubstr: "non-optional task",
		},
		{
			name: "task missing title rejected",
			mutate: func(l *canonical.Lab) {
				l.Tasks[0].Title = ""
			},
			wantErr:   true,
			errSubstr: "title is required",
		},
		{
			name: "task missing description rejected",
			mutate: func(l *canonical.Lab) {
				l.Tasks[0].Description = ""
			},
			wantErr:   true,
			errSubstr: "description is required",
		},
		{
			name: "task missing verification_script rejected",
			mutate: func(l *canonical.Lab) {
				l.Tasks[0].VerificationScript = ""
			},
			wantErr:   true,
			errSubstr: "verification_script is required",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			c := baseCommon()
			c.Kind = canonical.KindLab
			l := canonical.Lab{
				Common: c,
				LabSpec: canonical.LabSpec{
					LabType:        "terminal",
					Environment:    "mindforge/lab-k8s:1.31",
					MaxDuration:    60,
					MaxResets:      3,
					HintPenaltyPct: 10,
					IsRequired:     true,
					Tasks:          []canonical.Task{validTask()},
				},
			}
			tt.mutate(&l)

			err := l.Validate()
			if tt.wantErr {
				require.Error(t, err)
				if tt.errSubstr != "" {
					assert.Contains(t, err.Error(), tt.errSubstr)
				}
			} else {
				require.NoError(t, err)
			}
		})
	}
}

func TestDocumentValidate_Dispatch(t *testing.T) {
	c := baseCommon()
	c.Kind = canonical.KindLesson
	lesson := canonical.Lesson{Common: c, Body: "content"}

	doc := &canonical.Document{Path: "x.md", Kind: canonical.KindLesson, Lesson: &lesson}
	require.NoError(t, doc.Validate())

	docBad := &canonical.Document{Path: "x.md", Kind: canonical.KindQuiz, Quiz: nil}
	err := docBad.Validate()
	require.Error(t, err)
	assert.Contains(t, err.Error(), "Quiz is nil")
}
