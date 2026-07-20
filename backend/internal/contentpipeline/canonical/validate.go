package canonical

import (
	"errors"
	"fmt"
	"strings"
)

// Allowed enum values, mirrored from the real DB CHECK constraints
// (backend/db/migrations/008_labs_core.sql lab_definitions.lab_type,
// backend/internal/assessment/models.go QuestionType*) so this leaf package
// never imports the domain packages that own those constraints.
var (
	validLabTypes = map[string]bool{
		"terminal":   true,
		"code":       true,
		"playground": true,
		"guided":     true,
		"sandbox":    true,
	}
	validQuestionTypes = map[string]bool{
		"mcq":        true,
		"coding":     true,
		"subjective": true,
	}
	// validLessonModuleTypeOverrides mirrors course_modules_type_check
	// (backend/db/migrations/011_system_design.sql) minus 'notes', which is
	// the Lesson default and never needs to be stated explicitly.
	validLessonModuleTypeOverrides = map[string]bool{
		"system_design": true,
	}
)

// context identifies a document for error messages: prefer id_key (stable,
// always intended to be present) and fall back to title so a document
// missing id_key still produces a locatable error instead of an empty label.
func (c Common) context(kind string) string {
	label := c.IDKey
	if label == "" {
		label = c.Title
	}
	if label == "" {
		label = "(unidentified)"
	}
	return fmt.Sprintf("%s %q", kind, label)
}

func (c Common) validate(kind string) []error {
	ctx := c.context(kind)
	var errs []error
	if strings.TrimSpace(c.IDKey) == "" {
		errs = append(errs, fmt.Errorf("%s: id_key is required", ctx))
	}
	if strings.TrimSpace(c.Course) == "" {
		errs = append(errs, fmt.Errorf("%s: course is required", ctx))
	}
	if strings.TrimSpace(c.Section) == "" {
		errs = append(errs, fmt.Errorf("%s: section is required", ctx))
	}
	if strings.TrimSpace(c.Title) == "" {
		errs = append(errs, fmt.Errorf("%s: title is required", ctx))
	}
	if c.Position < 0 {
		errs = append(errs, fmt.Errorf("%s: position must be >= 0, got %d", ctx, c.Position))
	}
	return errs
}

// Validate checks Lesson against the canonical schema rules. It returns a
// joined error (errors.Join) covering every violation found, not just the
// first, since this runs as a batch audit over dozens of authored files.
func (l *Lesson) Validate() error {
	ctx := l.Common.context("lesson")
	errs := l.Common.validate("lesson")
	if strings.TrimSpace(l.Body) == "" {
		errs = append(errs, fmt.Errorf("%s: body is empty", ctx))
	}
	if l.ModuleType != "" && !validLessonModuleTypeOverrides[l.ModuleType] {
		errs = append(errs, fmt.Errorf("%s: invalid type override %q", ctx, l.ModuleType))
	}
	return errors.Join(errs...)
}

// Validate checks Quiz against the canonical schema rules, including every
// question's type-specific requirements. Returns a joined error covering
// every violation found.
func (q *Quiz) Validate() error {
	ctx := q.Common.context("quiz")
	errs := q.Common.validate("quiz")

	if q.PassPercentage < 0 || q.PassPercentage > 100 {
		errs = append(errs, fmt.Errorf("%s: pass_percentage must be in [0,100], got %d", ctx, q.PassPercentage))
	}
	if len(q.Questions) == 0 {
		errs = append(errs, fmt.Errorf("%s: at least one question is required", ctx))
	}

	for i, question := range q.Questions {
		qctx := fmt.Sprintf("%s: question[%d] (id_key=%q)", ctx, i, question.IDKey)

		if !validQuestionTypes[question.Type] {
			errs = append(errs, fmt.Errorf("%s: invalid type %q", qctx, question.Type))
			continue
		}

		switch question.Type {
		case "mcq":
			if len(question.Options) < 2 {
				errs = append(errs, fmt.Errorf("%s: mcq requires at least 2 options, got %d", qctx, len(question.Options)))
			}
			correctCount := 0
			for _, opt := range question.Options {
				if opt.Correct {
					correctCount++
				}
			}
			if correctCount == 0 {
				errs = append(errs, fmt.Errorf("%s: mcq requires at least one correct option", qctx))
			} else if !question.Multiple && correctCount != 1 {
				errs = append(errs, fmt.Errorf("%s: mcq with multiple=false requires exactly one correct option, got %d", qctx, correctCount))
			}

		case "coding":
			if len(question.TestCases) == 0 {
				errs = append(errs, fmt.Errorf("%s: coding requires at least one test case", qctx))
			}
		}
	}

	return errors.Join(errs...)
}

// Validate checks Lab against the canonical schema rules, including the
// publish-time invariants mirrored from docs/labs.md's "Required lab blocks
// section unlock" rule (a required lab must have at least one non-optional
// task, or it could never be completed). Returns a joined error covering
// every violation found.
func (l *Lab) Validate() error {
	ctx := l.Common.context("lab")
	errs := l.Common.validate("lab")

	if !validLabTypes[l.LabType] {
		errs = append(errs, fmt.Errorf("%s: invalid lab_type %q", ctx, l.LabType))
	}
	if strings.TrimSpace(l.Environment) == "" {
		errs = append(errs, fmt.Errorf("%s: environment is required", ctx))
	}
	// playground and sandbox labs may have zero tasks — free exploration; a
	// sandbox with tasks is graded via batch Submit instead of per-task Check.
	if l.LabType != "playground" && l.LabType != "sandbox" && len(l.Tasks) == 0 {
		errs = append(errs, fmt.Errorf("%s: at least one task is required (lab_type != playground|sandbox)", ctx))
	}
	if l.PreviewPort < 0 || l.PreviewPort > 65535 {
		errs = append(errs, fmt.Errorf("%s: preview_port must be in [0,65535], got %d", ctx, l.PreviewPort))
	}

	if l.IsRequired {
		hasNonOptional := false
		for _, t := range l.Tasks {
			if !t.IsOptional {
				hasNonOptional = true
				break
			}
		}
		if !hasNonOptional {
			errs = append(errs, fmt.Errorf("%s: is_required labs need at least one non-optional task", ctx))
		}
	}

	for i, task := range l.Tasks {
		tctx := fmt.Sprintf("%s: task[%d] (id_key=%q)", ctx, i, task.IDKey)
		if strings.TrimSpace(task.Title) == "" {
			errs = append(errs, fmt.Errorf("%s: title is required", tctx))
		}
		if strings.TrimSpace(task.Description) == "" {
			errs = append(errs, fmt.Errorf("%s: description is required", tctx))
		}
		if strings.TrimSpace(task.VerificationScript) == "" {
			errs = append(errs, fmt.Errorf("%s: verification_script is required", tctx))
		}
	}

	return errors.Join(errs...)
}

// Validate dispatches to the concrete document's Validate method based on
// Kind.
func (d *Document) Validate() error {
	switch d.Kind {
	case KindLesson:
		if d.Lesson == nil {
			return fmt.Errorf("canonical.Document.Validate: %s: kind is lesson but Lesson is nil", d.Path)
		}
		return d.Lesson.Validate()
	case KindQuiz:
		if d.Quiz == nil {
			return fmt.Errorf("canonical.Document.Validate: %s: kind is quiz but Quiz is nil", d.Path)
		}
		return d.Quiz.Validate()
	case KindLab:
		if d.Lab == nil {
			return fmt.Errorf("canonical.Document.Validate: %s: kind is lab but Lab is nil", d.Path)
		}
		return d.Lab.Validate()
	default:
		return fmt.Errorf("canonical.Document.Validate: %s: unknown kind %q", d.Path, d.Kind)
	}
}
