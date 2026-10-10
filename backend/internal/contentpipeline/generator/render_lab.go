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
	labFileHeredocTag   = "MFEOF"
	labFileWorkdir      = "/home/labuser/work"
)

// renderLab emits the linking course_modules(type='lab') row, then delegates
// to renderLabRows for the rest. Mirrors the 4-step shape of
// backend/db/fixtures/k8s_08_lab1.sql exactly, with canonical.ID-derived
// UUIDs in place of the old ad-hoc hex ones.
func renderLab(out *strings.Builder, courseID, sectionID string, lab *canonical.Lab) error {
	moduleID := canonical.ID(lab.IDKey, "module")
	labID := canonical.ID(lab.IDKey, "lab") // must match renderLabRows' own derivation below
	estMinutes := lab.EstimatedMinutes
	if estMinutes <= 0 {
		estMinutes = 30
	}

	// 0. Linking course_modules row, already carrying lab_id/lab_is_required
	//    so lab_module_has_lab (migration 044_course_library.sql) holds for
	//    generated fixtures too. course_modules.lab_id is DEFERRABLE
	//    INITIALLY DEFERRED specifically for this: the lab_definitions row it
	//    points at doesn't exist until renderLabRows runs below, in the same
	//    generated script/transaction (see that migration's header comment).
	fmt.Fprintf(out,
		"INSERT INTO course_modules (id, course_id, section_id, title, type, position, estimated_minutes, lab_id, lab_is_required)\nVALUES (%s, %s, %s, %s, 'lab', %s, %s, %s, %s)\nON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, lab_id=EXCLUDED.lab_id, lab_is_required=EXCLUDED.lab_is_required, updated_at=now();\n\n",
		sqlString(moduleID), sqlString(courseID), sqlString(sectionID), sqlString(lab.Title), sqlInt(lab.Position), sqlInt(estMinutes),
		sqlString(labID), sqlBool(lab.IsRequired),
	)

	return renderLabRows(out, courseID, moduleID, lab.IDKey, lab.Title, &lab.LabSpec)
}

// renderLabRows emits, in FK-safe order, everything a lab needs once its
// linking course_modules row already exists: the lab_definitions row
// (unpublished), the lab_tasks rows, the lab_task_versions snapshot, the
// lab_task_version_items rows, and finally the publish UPDATE.
//
// moduleID may belong to a course_modules row of ANY type — lab_definitions
// has no type constraint on module_id — which is what lets a `kind: lesson`
// doc attach a lab directly to its own notes module (see renderLesson) rather
// than requiring a separate `kind: lab` module in the section.
func renderLabRows(out *strings.Builder, courseID, moduleID, idKey, title string, spec *canonical.LabSpec) error {
	if spec.Recipe != "" {
		return renderRecipeLabRows(out, courseID, moduleID, idKey, title, spec)
	}
	labID := canonical.ID(idKey, "lab")
	versionID := canonical.ID(idKey, "version")

	maxDuration := spec.MaxDuration
	if maxDuration <= 0 {
		maxDuration = defaultMaxDuration
	}
	maxResets := spec.MaxResets
	if maxResets <= 0 {
		maxResets = defaultMaxResets
	}
	workspaceLayout := spec.WorkspaceLayout
	if workspaceLayout == "" {
		workspaceLayout = "split"
	}

	// 1. lab_definitions (unpublished; published_version_id set by the
	//    UPDATE at the end once lab_task_versions exists).
	setupScript := buildSetupScript(spec)
	runScript := "NULL"
	if strings.TrimSpace(spec.RunScript) != "" {
		runScript = dollarQuote("script", spec.RunScript)
	}
	fmt.Fprintf(out,
		"INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, run_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)\nVALUES (%s, %s, %s, %s, 'module', %s, NULL, %s, %s, %s, %s, %s, %s, %s, %s, %s, false, NULL, %s, %s)\nON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, preview_port=EXCLUDED.preview_port, setup_script=EXCLUDED.setup_script, run_script=EXCLUDED.run_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();\n\n",
		sqlString(labID), sqlString(seededOrgID), sqlString(courseID), sqlString(moduleID),
		sqlString(title),
		sqlString(spec.LabType), sqlString(spec.Environment), sqlInt(spec.PreviewPort), dollarQuote("script", setupScript), runScript,
		sqlInt(maxDuration), sqlInt(maxResets), sqlInt(spec.HintPenaltyPct), sqlBool(spec.IsRequired),
		sqlString(workspaceLayout), sqlString(seededInstructorID),
	)

	// 1b. Prune and park existing task rows before the upserts below. A task
	//     removed from the markdown would otherwise stay in the lab forever
	//     (upserts never delete), and because both tables are UNIQUE on
	//     position, a new task id landing on an old task's position would
	//     fail the whole script. Parking survivors at position+100000 lets
	//     the upserts reorder freely without transient unique violations.
	taskIDs := make([]string, 0, len(spec.Tasks))
	itemIDs := make([]string, 0, len(spec.Tasks))
	for _, task := range spec.Tasks {
		taskIDs = append(taskIDs, sqlString(canonical.ID(idKey, "task:"+task.IDKey)))
		itemIDs = append(itemIDs, sqlString(canonical.ID(idKey, "version-item:"+task.IDKey)))
	}
	fmt.Fprintf(out,
		"DELETE FROM lab_task_version_items WHERE task_version_id = %s%s;\nUPDATE lab_task_version_items SET position = position + 100000 WHERE task_version_id = %s;\nDELETE FROM lab_tasks WHERE lab_id = %s%s;\nUPDATE lab_tasks SET position = position + 100000 WHERE lab_id = %s;\n\n",
		sqlString(versionID), notInClause("id", itemIDs), sqlString(versionID),
		sqlString(labID), notInClause("id", taskIDs), sqlString(labID),
	)

	// 2. lab_tasks (live editable copy).
	snapshots := make([]taskSnapshotJSON, 0, len(spec.Tasks))
	if len(spec.Tasks) > 0 {
		out.WriteString("INSERT INTO lab_tasks (id, lab_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)\nVALUES\n")
		rows := make([]string, 0, len(spec.Tasks))
		for i, task := range spec.Tasks {
			taskID := canonical.ID(idKey, "task:"+task.IDKey)
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
		out.WriteString("\nON CONFLICT (id) DO UPDATE SET position=EXCLUDED.position, title=EXCLUDED.title, description=EXCLUDED.description, verification_script=EXCLUDED.verification_script, hint_context=EXCLUDED.hint_context, explanation_context=EXCLUDED.explanation_context, points=EXCLUDED.points, is_optional=EXCLUDED.is_optional, is_stateful=EXCLUDED.is_stateful;\n\n")
	}

	// 3. lab_task_versions — dev/seed-time convenience: this UPSERTs version 1
	//    in place on every regenerate rather than cutting a new version each
	//    time. That is safe ONLY because seed/dev databases have no in-flight
	//    student sessions at generate time; production content edits must
	//    still go through the real POST /instructor/labs/:id/publish endpoint,
	//    which correctly cuts a new immutable version per docs/labs.md.
	tasksJSON, err := json.Marshal(snapshots)
	if err != nil {
		return fmt.Errorf("renderLabRows: marshaling task snapshots for %q: %w", idKey, err)
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
	if len(spec.Tasks) > 0 {
		out.WriteString("INSERT INTO lab_task_version_items (id, task_version_id, source_task_id, position, title, description, verification_script, hint_context, explanation_context, points, is_optional, is_stateful)\nVALUES\n")
		rows := make([]string, 0, len(spec.Tasks))
		for i, task := range spec.Tasks {
			taskID := canonical.ID(idKey, "task:"+task.IDKey)
			itemID := canonical.ID(idKey, "version-item:"+task.IDKey)
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
	//    derivations of idKey), and the guard also means a real instructor
	//    publish that later points published_version_id at a genuinely newer
	//    version is never clobbered back to v1 by a subsequent
	//    `coursegen generate` run.
	fmt.Fprintf(out,
		"UPDATE lab_definitions\nSET is_published = true, published_version_id = %s, updated_at = now()\nWHERE id = %s AND published_version_id IS NULL;\n\n",
		sqlString(versionID), sqlString(labID),
	)

	return nil
}

// buildSetupScript prepends one heredoc write per spec.Files entry (so
// multi-file starter projects exist in the container workdir at session
// start) to the author's own setup_script.
//
// Lab containers run with --cap-drop ALL and this script runs as the image
// user (labuser), so files it writes are already labuser-owned; the explicit
// chmod 666 / 777 keeps them editable even if a script runs as another user.
// Every written file gets chmod 666 and every directory this script
// creates gets chmod 777 — otherwise starter files are read-only to the
// student in the terminal and the file-explorer PUT endpoint alike.
func buildSetupScript(spec *canonical.LabSpec) string {
	var b strings.Builder
	if len(spec.Files) > 0 {
		fmt.Fprintf(&b, "mkdir -p %s\n", labFileWorkdir)
		seenDirs := map[string]bool{}
		for _, f := range spec.Files {
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
	b.WriteString(spec.SetupScript)
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

// notInClause renders " AND <col> NOT IN (...)" for a prune DELETE, or ""
// when ids is empty (the DELETE then removes every row, which is correct:
// the document now declares none).
func notInClause(col string, ids []string) string {
	if len(ids) == 0 {
		return ""
	}
	return " AND " + col + " NOT IN (" + strings.Join(ids, ", ") + ")"
}
