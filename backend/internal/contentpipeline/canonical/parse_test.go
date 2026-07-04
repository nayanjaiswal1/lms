package canonical_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const validLessonMD = `---
kind: lesson
id_key: k8s/pods/lesson
course: fast-kubernetes
section: pod-fundamentals
section_title: "Pod Fundamentals"
section_position: 0
title: "Pods: Imperative and Declarative"
position: 0
estimated_minutes: 30
source: [K8s-Pod.md]
---
# Pods

Some body content about pods.
`

const validQuizMD = `---
kind: quiz
id_key: k8s/workloads/quiz
course: fast-kubernetes
section: workloads
section_title: "Workloads & Controllers"
section_position: 2
title: "Quiz: Workloads & Controllers"
position: 2
estimated_minutes: 20
source: [K8s-Deployment.md]
pass_percentage: 60
duration_minutes: 20
questions:
  - id_key: q1
    type: mcq
    difficulty: beginner
    points: 2
    prompt: "Default maxSurge for a RollingUpdate Deployment?"
    options:
      - {text: "0", correct: false}
      - {text: "25%", correct: true}
    explanation: "Both maxSurge and maxUnavailable default to 25%."
  - id_key: q2
    type: coding
    difficulty: intermediate
    points: 5
    prompt: "Write a script that prints the pod count."
    languages: [bash]
    starter_code: {bash: "#!/bin/bash\n"}
    test_cases:
      - {stdin: "", expected: "3", hidden: false, weight: 1}
---
`

const validLabMD = `---
kind: lab
id_key: k8s/workloads/deployment/lab
course: fast-kubernetes
section: workloads
section_title: "Workloads & Controllers"
section_position: 2
title: "Lab: Deploy, Scale and Roll Out an App"
position: 1
estimated_minutes: 60
source: [K8s-Deployment.md]
lab_type: terminal
environment: mindforge/lab-k8s:1.31
max_duration: 60
max_resets: 3
hint_penalty_pct: 10
is_required: true
setup_script: |
  #!/bin/bash
  kubectl cluster-info >/dev/null 2>&1 || { echo "cluster not ready"; exit 1; }
files:
  - path: deployment.yaml
    content: |
      apiVersion: apps/v1
      kind: Deployment
tasks:
  - id_key: t1
    title: "Create the demo namespace"
    points: 10
    is_optional: false
    is_stateful: false
    description: "Create a namespace named demo."
    verification_script: |
      #!/bin/bash
      kubectl get namespace demo >/dev/null 2>&1
    hint_context: "kubectl create namespace demo"
    explanation_context: "Namespaces scope names and quotas."
    solution_script: "kubectl create namespace demo"
---
`

const noDelimiterMD = `kind: lesson
title: "no frontmatter here"
`

func writeTemp(t *testing.T, name, content string) string {
	t.Helper()
	dir := t.TempDir()
	path := filepath.Join(dir, name)
	require.NoError(t, os.WriteFile(path, []byte(content), 0o644))
	return path
}

func TestSplitFrontmatter_MissingDelimiter(t *testing.T) {
	_, _, err := canonical.SplitFrontmatter([]byte(noDelimiterMD))
	require.Error(t, err)
	assert.Contains(t, err.Error(), "does not start with")
}

func TestSplitFrontmatter_MissingClosingDelimiter(t *testing.T) {
	_, _, err := canonical.SplitFrontmatter([]byte("---\nkind: lesson\n"))
	require.Error(t, err)
	assert.Contains(t, err.Error(), "closing")
}

func TestParseFile_Lesson(t *testing.T) {
	path := writeTemp(t, "lesson.md", validLessonMD)

	doc, err := canonical.ParseFile(path)
	require.NoError(t, err)
	require.Equal(t, canonical.KindLesson, doc.Kind)
	require.NotNil(t, doc.Lesson)
	assert.Nil(t, doc.Quiz)
	assert.Nil(t, doc.Lab)

	assert.Equal(t, "k8s/pods/lesson", doc.Lesson.IDKey)
	assert.Equal(t, "fast-kubernetes", doc.Lesson.Course)
	assert.Equal(t, "pod-fundamentals", doc.Lesson.Section)
	assert.Equal(t, []string{"K8s-Pod.md"}, doc.Lesson.Source)
	assert.Contains(t, doc.Lesson.Body, "# Pods")
	assert.Contains(t, doc.Lesson.Body, "Some body content about pods.")

	require.NoError(t, doc.Validate())
}

func TestParseFile_Quiz(t *testing.T) {
	path := writeTemp(t, "quiz.md", validQuizMD)

	doc, err := canonical.ParseFile(path)
	require.NoError(t, err)
	require.Equal(t, canonical.KindQuiz, doc.Kind)
	require.NotNil(t, doc.Quiz)
	assert.Nil(t, doc.Lesson)
	assert.Nil(t, doc.Lab)

	require.Len(t, doc.Quiz.Questions, 2)
	assert.Equal(t, "mcq", doc.Quiz.Questions[0].Type)
	assert.Equal(t, 60, doc.Quiz.PassPercentage)
	require.Len(t, doc.Quiz.Questions[0].Options, 2)
	assert.True(t, doc.Quiz.Questions[0].Options[1].Correct)

	require.NoError(t, doc.Validate())
}

func TestParseFile_Lab(t *testing.T) {
	path := writeTemp(t, "lab.md", validLabMD)

	doc, err := canonical.ParseFile(path)
	require.NoError(t, err)
	require.Equal(t, canonical.KindLab, doc.Kind)
	require.NotNil(t, doc.Lab)
	assert.Nil(t, doc.Lesson)
	assert.Nil(t, doc.Quiz)

	assert.Equal(t, "terminal", doc.Lab.LabType)
	assert.Equal(t, "mindforge/lab-k8s:1.31", doc.Lab.Environment)
	require.Len(t, doc.Lab.Files, 1)
	assert.Equal(t, "deployment.yaml", doc.Lab.Files[0].Path)
	require.Len(t, doc.Lab.Tasks, 1)
	assert.Equal(t, "kubectl create namespace demo", doc.Lab.Tasks[0].SolutionScript)
	assert.Contains(t, doc.Lab.Tasks[0].VerificationScript, "kubectl get namespace demo")

	require.NoError(t, doc.Validate())
}

func TestParseFile_MissingDelimiter(t *testing.T) {
	path := writeTemp(t, "bad.md", noDelimiterMD)

	_, err := canonical.ParseFile(path)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "canonical.ParseFile")
	assert.Contains(t, err.Error(), path)
}

func TestParseFile_MissingFile(t *testing.T) {
	_, err := canonical.ParseFile(filepath.Join(t.TempDir(), "does-not-exist.md"))
	require.Error(t, err)
	assert.Contains(t, err.Error(), "canonical.ParseFile")
}

func TestParseFile_UnknownKind(t *testing.T) {
	path := writeTemp(t, "unknown.md", "---\nkind: bogus\n---\nbody\n")

	_, err := canonical.ParseFile(path)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "unknown kind")
}

func TestID_Deterministic(t *testing.T) {
	a := canonical.ID("k8s/workloads/deployment/lab", "lab")
	b := canonical.ID("k8s/workloads/deployment/lab", "lab")
	assert.Equal(t, a, b)
}

func TestID_DifferentSuffixesDiffer(t *testing.T) {
	labID := canonical.ID("k8s/workloads/deployment/lab", "lab")
	taskID := canonical.ID("k8s/workloads/deployment/lab", "task:t1")
	versionID := canonical.ID("k8s/workloads/deployment/lab", "version")

	assert.NotEqual(t, labID, taskID)
	assert.NotEqual(t, labID, versionID)
	assert.NotEqual(t, taskID, versionID)
}

func TestID_DifferentIDKeysDiffer(t *testing.T) {
	a := canonical.ID("k8s/workloads/deployment/lab", "lab")
	b := canonical.ID("k8s/workloads/daemonset/lab", "lab")
	assert.NotEqual(t, a, b)
}
