package generator

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
)

const (
	defaultMaxDuration = 60 // minutes
	defaultMaxResets   = 3
	labFileHeredocTag  = "MFEOF"
	labFileWorkdir     = "/home/labuser/work"
)

// renderLab emits, in FK-safe order: the linking course_modules(type='lab')
// row (lab_definitions.module_id references it and is NOT NULL for
// scope='module' labs, so it must exist first), the lab_definitions row
// (unpublished), the lab_tasks rows, the lab_task_versions snapshot, and
// finally the publish UPDATE. Mirrors the 4-step shape of
// backend/db/fixtures/k8s_08_lab1.sql exactly, with canonical.ID-derived
// UUIDs in place of the old ad-hoc hex ones.
func renderLab(out *strings.Builder, courseID, sectionID string, lab *canonical.Lab) error {
	moduleID := canonical.ID(lab.IDKey, "module")
	labID := canonical.ID(lab.IDKey, "lab")
	versionID := canonical.ID(lab.IDKey, "version")

	maxDuration := lab.MaxDuration
	if maxDuration <= 0 {
		maxDuration = defaultMaxDuration
	}
	maxResets := lab.MaxResets
	if maxResets <= 0 {
		maxResets = defaultMaxResets
	}
	estMinutes := lab.EstimatedMinutes
	if estMinutes <= 0 {
		estMinutes = 30
	}

	// 0. Linking course_modules row — must exist before lab_definitions
	//    references it via module_id.
	fmt.Fprintf(out,
		"INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes)\nVALUES (%s, %s, %s, %s, 'lab', %s, %s)\nON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, updated_at=now();\n\n",
		sqlString(moduleID), sqlString(courseID), sqlString(sectionID), sqlString(lab.Title), sqlInt(lab.Position), sqlInt(estMinutes),
	)

	// 1. lab_definitions (unpublished; published_version_id set by the
	//    UPDATE at the end once lab_task_versions exists).
	setupScript := buildSetupScript(lab)
	runScript := "NULL"
	if strings.TrimSpace(lab.RunScript) != "" {
		runScript = dollarQuote("script", lab.RunScript)
	}
	fmt.Fprintf(out,
		"INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, created_by)\nVALUES (%s, %s, %s, %s, 'module', %s, NULL, %s, %s, %s, %s, %s, %s, %s, %s, %s, false, NULL, %s)\nON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, updated_at=now();\n\n",
		sqlString(labID), sqlString(seededOrgID), sqlString(courseID), sqlString(moduleID),
		sqlString(lab.Title),
		sqlString(lab.LabType), sqlString(lab.Environment), sqlInt(lab.PreviewPort), dollarQuote("script", setupScript), runScript,
		sqlInt(maxDuration), sqlInt(maxResets), sqlInt(lab.HintPenaltyPct), sqlBool(lab.IsRequired),
		sqlString(seededInstructorID),
	)

	// 2. lab_tasks (live editable copy).
	snapshots := make([]taskSnapshotJSON, 0, len(lab.Tasks))
	if len(lab.Tasks) > 0 {
		out.WriteString("INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)\nVALUES\n")
		rows := make([]string, 0, len(lab.Tasks))
		for i, task := range lab.Tasks {
			taskID := canonical.ID(lab.IDKey, "task:"+task.IDKey)
			position := i + 1
			rows = append(rows, fmt.Sprintf(
				"(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
				sqlString(taskID), sqlString(labID), sqlInt(position),
				sqlString(task.Title), dollarQuote("md", task.Description),
				dollarQuote("script", task.VerificationScript),
				sqlNullableString(task.HintContext), sqlNullableString(task.ExplanationContext),
				sqlInt(task.Points), sqlBool(task.IsOptional), sqlBool(task.IsStateful),
			))
			snapshots = append(snapshots, taskSnapshotJSON{
				ID: taskID, LabID: labID, Position: position,
				Title: task.Title, Description: task.Description,
				VerificationScript: task.VerificationScript,
				HintContext:        task.HintContext,
				ExplanationContext: task.ExplanationContext,
				Points:             task.Points,
				IsOptional:         task.IsOptional,
				IsStateful:         task.IsStateful,
			})
			// solution_script is intentionally never referenced above or
			// below — it must never reach lab_tasks, lab_task_versions, or
			// any other emitted row.
		}
		out.WriteString(strings.Join(rows, ",\n"))
		out.WriteString("\nON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;\n\n")
	}

	// 3. lab_task_versions — dev/seed-time convenience: this UPSERTs version 1
	//    in place on every regenerate rather than cutting a new version each
	//    time. That is safe ONLY because seed/dev databases have no in-flight
	//    student sessions at generate time; production content edits must
	//    still go through the real POST /instructor/labs/:id/publish endpoint,
	//    which correctly cuts a new immutable version per docs/labs.md.
	tasksJSON, err := json.Marshal(snapshots)
	if err != nil {
		return fmt.Errorf("renderLab: marshaling task snapshots for %q: %w", lab.IDKey, err)
	}
	fmt.Fprintf(out,
		"INSERT INTO lab_task_versions (id, lab_id, version, tasks, published_by)\nVALUES (%s, %s, 1, %s::jsonb, %s)\nON CONFLICT (lab_id, version) DO UPDATE SET tasks=EXCLUDED.tasks, published_by=EXCLUDED.published_by;\n\n",
		sqlString(versionID), sqlString(labID), dollarQuote("json", string(tasksJSON)), sqlString(seededInstructorID),
	)

	// 3b. lab_task_version_items — the rows sessions actually read.
	//     Repo.GetPublishedVersion selects from this table (the tasks JSONB
	//     above is legacy), and it returns ErrNotFound on zero rows, which
	//     404s every student-facing lab endpoint. A generated lab without
	//     these rows is invisible in the app even though it "loaded fine".
	if len(lab.Tasks) > 0 {
		out.WriteString("INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)\nVALUES\n")
		rows := make([]string, 0, len(lab.Tasks))
		for i, task := range lab.Tasks {
			taskID := canonical.ID(lab.IDKey, "task:"+task.IDKey)
			itemID := canonical.ID(lab.IDKey, "version-item:"+task.IDKey)
			rows = append(rows, fmt.Sprintf(
				"(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
				sqlString(itemID), sqlString(versionID), sqlString(taskID), sqlInt(i+1),
				sqlString(task.Title), dollarQuote("md", task.Description),
				dollarQuote("script", task.VerificationScript),
				sqlNullableString(task.HintContext), sqlNullableString(task.ExplanationContext),
				sqlInt(task.Points), sqlBool(task.IsOptional), sqlBool(task.IsStateful),
			))
		}
		out.WriteString(strings.Join(rows, ",\n"))
		out.WriteString("\nON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;\n\n")
	}

	// 4. Publish. Guard matches k8s_08_lab1.sql exactly: only fires while
	//    published_version_id is still NULL (first generate). Once set, the
	//    id is stable across regenerates anyway (both are deterministic
	//    derivations of lab.IDKey), and the guard also means a real
	//    instructor publish that later points published_version_id at a
	//    genuinely newer version is never clobbered back to v1 by a
	//    subsequent `coursegen generate` run.
	fmt.Fprintf(out,
		"UPDATE lab_definitions\nSET is_published = true, published_version_id = %s, updated_at = now()\nWHERE id = %s AND published_version_id IS NULL;\n\n",
		sqlString(versionID), sqlString(labID),
	)

	return nil
}

// buildSetupScript prepends one heredoc write per lab.Files entry (so
// multi-file starter projects exist in the container workdir at session
// start) to the author's own setup_script.
//
// Lab containers run with --cap-drop ALL, which strips CAP_CHOWN and
// CAP_DAC_OVERRIDE even from the root user this script runs as: root cannot
// chown its writes over to labuser, and labuser cannot edit a root-owned
// 0644 file. Every written file therefore gets chmod 666 (root owns it, so
// plain-ownership chmod needs no capability) and every directory this script
// creates gets chmod 777 — otherwise starter files are read-only to the
// student in the terminal and the file-explorer PUT endpoint alike.
func buildSetupScript(lab *canonical.Lab) string {
	var b strings.Builder
	if len(lab.Files) > 0 {
		fmt.Fprintf(&b, "mkdir -p %s\n", labFileWorkdir)
		seenDirs := map[string]bool{}
		for _, f := range lab.Files {
			for _, dir := range parentDirs(f.Path) {
				if seenDirs[dir] {
					continue
				}
				seenDirs[dir] = true
				fmt.Fprintf(&b, "mkdir -p %s/%s && chmod 777 %s/%s\n", labFileWorkdir, dir, labFileWorkdir, dir)
			}
			fmt.Fprintf(&b, "cat > %s/%s <<'%s'\n%s\n%s\n", labFileWorkdir, f.Path, labFileHeredocTag, f.Content, labFileHeredocTag)
			fmt.Fprintf(&b, "chmod 666 %s/%s\n", labFileWorkdir, f.Path)
		}
	}
	b.WriteString(lab.SetupScript)
	return b.String()
}

// parentDirs returns every directory prefix of a workdir-relative file path,
// shallowest first ("a/b/c.py" -> ["a", "a/b"]), so buildSetupScript can
// mkdir each level before the heredoc write and chmod it student-writable.
func parentDirs(filePath string) []string {
	var dirs []string
	segments := strings.Split(filePath, "/")
	for i := 1; i < len(segments); i++ {
		dirs = append(dirs, strings.Join(segments[:i], "/"))
	}
	return dirs
}
