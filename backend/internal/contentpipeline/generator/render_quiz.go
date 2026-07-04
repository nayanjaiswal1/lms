package generator

import (
	"fmt"
	"strings"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
)

const questionIDLetters = "abcdefghijklmnopqrstuvwxyz"

// renderQuiz emits, in FK-safe order: the linking course_modules(type=
// 'assessment') row is emitted LAST here because assessments.id must exist
// first for course_modules.assessment_id to reference it (the reverse
// dependency direction from lab's module-before-definition ordering) — so
// this function emits assessments + questions + assessment_questions first,
// then the linking module row.
func renderQuiz(out *strings.Builder, courseID, sectionID string, quiz *canonical.Quiz) error {
	assessmentID := canonical.ID(quiz.IDKey, "assessment")
	moduleID := canonical.ID(quiz.IDKey, "module")

	totalPoints := 0
	typesSeen := map[string]bool{}
	for _, q := range quiz.Questions {
		totalPoints += q.Points
		typesSeen[q.Type] = true
	}
	assessmentType := "mixed"
	if len(typesSeen) == 1 {
		for t := range typesSeen {
			if t == "mcq" || t == "coding" {
				assessmentType = t
			}
		}
	}

	durationMinutes := quiz.DurationMinutes
	if durationMinutes <= 0 {
		durationMinutes = 20
	}
	passPct := quiz.PassPercentage
	if passPct <= 0 {
		passPct = 60
	}

	// 1. questions + question_versions, one pair per authored question.
	assessmentQuestionRows := make([]string, 0, len(quiz.Questions))
	for i, q := range quiz.Questions {
		questionID := canonical.ID(quiz.IDKey, "question:"+q.IDKey)
		versionID := canonical.ID(quiz.IDKey, "qversion:"+q.IDKey)
		aqID := canonical.ID(quiz.IDKey, "aq:"+q.IDKey)

		fmt.Fprintf(out,
			"INSERT INTO questions (id, org_id, type, title, difficulty, default_points, tags, current_version, created_by)\nVALUES (%s, %s, %s, %s, %s, %s, %s, 1, %s)\nON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, difficulty=EXCLUDED.difficulty, default_points=EXCLUDED.default_points, tags=EXCLUDED.tags, updated_at=now();\n\n",
			sqlString(questionID), sqlString(seededOrgID), sqlString(q.Type),
			sqlString(questionTitle(quiz, q)), sqlString(nonEmpty(q.Difficulty, "intermediate")),
			sqlInt(q.Points), sqlStringArray([]string{"kubernetes", "k8s"}), sqlString(seededInstructorID),
		)

		content, err := renderQuestionContent(q)
		if err != nil {
			return fmt.Errorf("renderQuiz: question %q: %w", q.IDKey, err)
		}
		fmt.Fprintf(out,
			"INSERT INTO question_versions (id, question_id, version, content, created_by)\nVALUES (%s, %s, 1, %s, %s)\nON CONFLICT (id) DO UPDATE SET content=EXCLUDED.content;\n\n",
			sqlString(versionID), sqlString(questionID), content, sqlString(seededInstructorID),
		)

		assessmentQuestionRows = append(assessmentQuestionRows, fmt.Sprintf(
			"(%s, %s, %s, %s, %s, %s)",
			sqlString(aqID), sqlString(assessmentID), sqlString(questionID), sqlString(versionID), sqlInt(i), sqlInt(q.Points),
		))
	}

	// 2. assessments.
	fmt.Fprintf(out,
		"INSERT INTO assessments (id, org_id, title, slug, description, type, status, parent_type, parent_id, duration_minutes, pass_percentage, max_attempts, total_points, shuffle_questions, shuffle_options, allow_backtrack, show_results, created_by, published_at)\nVALUES (%s, %s, %s, %s, %s, %s, 'published', 'module', %s, %s, %s, 5, %s, true, true, true, true, %s, now())\nON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, type=EXCLUDED.type, duration_minutes=EXCLUDED.duration_minutes, pass_percentage=EXCLUDED.pass_percentage, total_points=EXCLUDED.total_points, updated_at=now();\n\n",
		sqlString(assessmentID), sqlString(seededOrgID), sqlString(quiz.Title),
		sqlString(assessmentSlug(quiz)), sqlString(fmt.Sprintf("Quiz covering %s.", quiz.SectionTitle)),
		sqlString(assessmentType), sqlString(moduleID),
		sqlInt(durationMinutes), sqlInt(passPct), sqlInt(totalPoints),
		sqlString(seededInstructorID),
	)

	// 3. assessment_questions links.
	if len(assessmentQuestionRows) > 0 {
		out.WriteString("INSERT INTO assessment_questions (id, assessment_id, question_id, version_id, position, points)\nVALUES\n")
		out.WriteString(strings.Join(assessmentQuestionRows, ",\n"))
		out.WriteString("\nON CONFLICT (assessment_id, question_id) DO UPDATE SET version_id=EXCLUDED.version_id, position=EXCLUDED.position, points=EXCLUDED.points;\n\n")
	}

	// 4. Linking course_modules row — inserted after assessments so its
	//    assessment_id FK target already exists.
	estMinutes := quiz.EstimatedMinutes
	if estMinutes <= 0 {
		estMinutes = durationMinutes
	}
	fmt.Fprintf(out,
		"INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, assessment_id)\nVALUES (%s, %s, %s, %s, 'assessment', %s, %s, %s)\nON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, assessment_id=EXCLUDED.assessment_id, updated_at=now();\n\n",
		sqlString(moduleID), sqlString(courseID), sqlString(sectionID), sqlString(quiz.Title), sqlInt(quiz.Position), sqlInt(estMinutes), sqlString(assessmentID),
	)

	return nil
}

func renderQuestionContent(q canonical.Question) (string, error) {
	switch q.Type {
	case "mcq":
		options := make([]mcqOptionJSON, 0, len(q.Options))
		for i, opt := range q.Options {
			letter := "opt" + sqlInt(i)
			if i < len(questionIDLetters) {
				letter = string(questionIDLetters[i])
			}
			options = append(options, mcqOptionJSON{ID: letter, Text: opt.Text, IsCorrect: opt.Correct})
		}
		return sqlJSONB(mcqContentJSON{
			Prompt: q.Prompt, Multiple: q.Multiple, Options: options, Explanation: q.Explanation,
		})

	case "coding":
		return sqlJSONB(codingContentJSON{
			Prompt: q.Prompt, Languages: q.Languages, StarterCode: q.StarterCode,
			TimeLimitMs: defaultCodingTimeLimitMs, MemoryLimitKB: defaultCodingMemoryLimitKB,
			TestCases: mapTestCases(q.TestCases),
		})

	case "subjective":
		return sqlJSONB(subjectiveContentJSON{
			Prompt: q.Prompt, WordLimit: defaultSubjectiveWordLimit,
			Rubric: []subjectiveRubricCriterionJSON{
				{Criterion: "Overall correctness", Weight: 1.0, Description: nonEmpty(q.Explanation, "Answer addresses the prompt accurately and completely.")},
			},
		})

	default:
		return "", fmt.Errorf("unsupported question type %q", q.Type)
	}
}

func mapTestCases(cases []canonical.QuizTestCase) []codingTestCaseJSON {
	out := make([]codingTestCaseJSON, 0, len(cases))
	for i, tc := range cases {
		id := "t" + sqlInt(i+1)
		out = append(out, codingTestCaseJSON{ID: id, Stdin: tc.Stdin, Expected: tc.Expected, Hidden: tc.Hidden, Weight: tc.Weight})
	}
	return out
}

func questionTitle(quiz *canonical.Quiz, q canonical.Question) string {
	if len(q.Prompt) <= 80 {
		return q.Prompt
	}
	return q.Prompt[:77] + "..."
}

func assessmentSlug(quiz *canonical.Quiz) string {
	return strings.ToLower(strings.ReplaceAll(quiz.IDKey, "/", "-"))
}

func nonEmpty(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}
