package generator

import (
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
)

// sectionMeta accumulates a course section's identity the first time any
// document in that section is seen, so it only needs to be inserted once.
type sectionMeta struct {
	slug     string
	title    string
	position int
}

// Render renders every document (already loaded, validated, and sorted by
// Load) into one idempotent SQL script: one INSERT/UPDATE block per course,
// section, and module, using deterministic canonical.ID-derived UUIDs so
// re-running Render on unchanged input produces byte-identical SQL, and
// re-running it on edited input updates existing rows via ON CONFLICT ...
// DO UPDATE rather than duplicating them.
func Render(docs []*canonical.Document, meta canonical.CourseMeta) (string, error) {
	if len(docs) == 0 {
		return "", fmt.Errorf("generator.Render: no documents to render")
	}

	byCourse := map[string][]*canonical.Document{}
	var courseSlugs []string
	for _, doc := range docs {
		c := commonOf(doc).Course
		if _, seen := byCourse[c]; !seen {
			courseSlugs = append(courseSlugs, c)
		}
		byCourse[c] = append(byCourse[c], doc)
	}
	sort.Strings(courseSlugs)

	var out strings.Builder
	out.WriteString("-- ══════════════════════════════════════════════════════════════════════════\n")
	out.WriteString("-- GENERATED FILE — DO NOT EDIT.\n")
	out.WriteString("-- Source: canonical markdown content (content/courses/**).\n")
	out.WriteString("-- Regenerate via: cd backend && go run ./cmd/coursegen generate\n")
	out.WriteString(fmt.Sprintf("-- Generated at: %s\n", time.Now().UTC().Format(time.RFC3339)))
	out.WriteString("-- ══════════════════════════════════════════════════════════════════════════\n\n")

	for _, slug := range courseSlugs {
		if err := renderCourse(&out, slug, byCourse[slug], meta); err != nil {
			return "", fmt.Errorf("generator.Render: course %q: %w", slug, err)
		}
	}

	return out.String(), nil
}

func renderCourse(out *strings.Builder, slug string, docs []*canonical.Document, meta canonical.CourseMeta) error {
	courseID := canonical.ID(slug, "course")

	title := meta.Title
	if title == "" {
		title = titleCase(slug)
	}
	description := meta.Description
	if description == "" {
		description = fmt.Sprintf("Course content imported and generated from the canonical markdown content pipeline for %q.", title)
	}
	difficulty := meta.Difficulty
	if difficulty == "" {
		difficulty = "intermediate"
	}
	tags := meta.Tags
	if tags == nil {
		tags = []string{}
	}
	isFree := true
	if meta.IsFree != nil {
		isFree = *meta.IsFree
	}

	totalMinutes := 0
	for _, doc := range docs {
		totalMinutes += commonOf(doc).EstimatedMinutes
	}
	estimatedHours := float64(totalMinutes) / 60.0
	if estimatedHours <= 0 {
		estimatedHours = 1.0
	}

	fmt.Fprintf(out, "-- ─── Course: %s ─────────────────────────────────────────────\n", title)
	fmt.Fprintf(out,
		"INSERT INTO courses (id, org_id, creator_id, title, slug, description, cover_url, difficulty, tags, status, is_free, estimated_hours)\nVALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %.1f)\nON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, cover_url=EXCLUDED.cover_url, tags=EXCLUDED.tags, estimated_hours=EXCLUDED.estimated_hours, updated_at=now();\n\n",
		sqlString(courseID),
		sqlString(seededOrgID),
		sqlString(seededInstructorID),
		sqlString(title),
		sqlString(slug),
		sqlString(description),
		sqlNullableString(meta.CoverURL),
		sqlString(difficulty),
		sqlStringArray(tags),
		sqlString("published"),
		sqlBool(isFree),
		estimatedHours,
	)

	// Collect and order sections.
	sectionsBySlug := map[string]sectionMeta{}
	for _, doc := range docs {
		c := commonOf(doc)
		if _, ok := sectionsBySlug[c.Section]; !ok {
			sectionsBySlug[c.Section] = sectionMeta{slug: c.Section, title: c.SectionTitle, position: c.SectionPosition}
		}
	}
	sections := make([]sectionMeta, 0, len(sectionsBySlug))
	for _, sm := range sectionsBySlug {
		sections = append(sections, sm)
	}
	sort.Slice(sections, func(i, j int) bool { return sections[i].position < sections[j].position })

	docsBySection := map[string][]*canonical.Document{}
	for _, doc := range docs {
		sec := commonOf(doc).Section
		docsBySection[sec] = append(docsBySection[sec], doc)
	}

	for _, sec := range sections {
		sectionID := canonical.ID(slug+"/"+sec.slug, "section")
		fmt.Fprintf(out, "-- Section: %s\n", sec.title)
		fmt.Fprintf(out,
			"INSERT INTO course_sections (id, course_id, title, position)\nVALUES (%s, %s, %s, %s)\nON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;\n\n",
			sqlString(sectionID), sqlString(courseID), sqlString(sec.title), sqlInt(sec.position),
		)

		secDocs := docsBySection[sec.slug]
		sort.Slice(secDocs, func(i, j int) bool { return commonOf(secDocs[i]).Position < commonOf(secDocs[j]).Position })

		for _, doc := range secDocs {
			var err error
			switch doc.Kind {
			case canonical.KindLesson:
				err = renderLesson(out, courseID, sectionID, doc.Lesson)
			case canonical.KindLab:
				err = renderLab(out, courseID, sectionID, doc.Lab)
			case canonical.KindQuiz:
				err = renderQuiz(out, courseID, sectionID, doc.Quiz, tags)
			default:
				err = fmt.Errorf("unknown document kind %q at %s", doc.Kind, doc.Path)
			}
			if err != nil {
				return err
			}
		}
	}

	// Auto-enroll the seeded dev student in every generated course.
	enrollmentID := canonical.ID(slug, "enrollment:"+seededStudentID)
	fmt.Fprintf(out,
		"INSERT INTO enrollments (id, user_id, course_id, enrolled_by)\nVALUES (%s, %s, %s, %s)\nON CONFLICT (user_id, course_id) DO NOTHING;\n\n",
		sqlString(enrollmentID), sqlString(seededStudentID), sqlString(courseID), sqlString(seededInstructorID),
	)

	return nil
}

// titleCase turns a kebab-case slug ("fast-kubernetes") into a display title
// ("Fast Kubernetes"). Used only as a sensible default course title derived
// from the slug the canonical markdown declares — this package has no
// separate "course" document kind to source a title from.
func titleCase(slug string) string {
	words := strings.Split(slug, "-")
	for i, w := range words {
		if w == "" {
			continue
		}
		words[i] = strings.ToUpper(w[:1]) + w[1:]
	}
	return strings.Join(words, " ")
}
