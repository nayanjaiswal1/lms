package generator

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/mindforge/backend/internal/contentpipeline/canonical"
	"github.com/mindforge/backend/internal/labkinds"
)

// renderRecipeLabRows emits a recipe lab (docs/debug-labs.md Part 2 B5
// "Platform course content"): the lab_definitions row UNPUBLISHED (lab type,
// image and setup script come from the lab kind) and a platform lab_recipes row
// pinned to the recipe's blocks. It emits no tasks, task version or publish:
// lab.platform_recipes_sync builds and verifies the recipe and publishes the lab
// through the same publish path instructors use, which creates the tasks and
// the task version from the kind. The recipe row is an idempotent upsert; its
// revision only moves when the spec actually changes.
func renderRecipeLabRows(out *strings.Builder, courseID, moduleID, idKey, title string, spec *canonical.LabSpec) error {
	rs := spec.RecipeSpec
	kind, ok := labkinds.Get(rs.LabKind)
	if !ok {
		return fmt.Errorf("renderRecipeLabRows: %q: unknown lab kind %q", idKey, rs.LabKind)
	}
	recipeSpec, err := rs.Spec()
	if err != nil {
		return fmt.Errorf("renderRecipeLabRows: %q: %w", idKey, err)
	}
	specJSON, err := json.Marshal(recipeSpec)
	if err != nil {
		return fmt.Errorf("renderRecipeLabRows: %q: marshaling recipe spec: %w", idKey, err)
	}

	labID := canonical.ID(idKey, "lab") // must match renderLab's module link
	maxDuration := spec.MaxDuration
	if maxDuration <= 0 {
		maxDuration = defaultMaxDuration
	}
	maxResets := spec.MaxResets
	if maxResets <= 0 {
		maxResets = defaultMaxResets
	}
	hintPenaltyPct := spec.HintPenaltyPct
	if hintPenaltyPct <= 0 {
		hintPenaltyPct = defaultRecipeHintPenaltyPct
	}
	workspaceLayout := spec.WorkspaceLayout
	if workspaceLayout == "" {
		workspaceLayout = "split"
	}
	fmt.Fprintf(out,
		"INSERT INTO lab_definitions (id, org_id, course_id, module_id, scope, title, description, lab_type, environment, preview_port, setup_script, max_duration, max_resets, hint_penalty_pct, is_required, is_published, published_version_id, workspace_layout, created_by)\nVALUES (%s, %s, %s, %s, 'module', %s, NULL, %s, %s, 0, %s, %s, %s, %s, %s, false, NULL, %s, %s)\nON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_type=EXCLUDED.lab_type, environment=EXCLUDED.environment, setup_script=EXCLUDED.setup_script, max_duration=EXCLUDED.max_duration, max_resets=EXCLUDED.max_resets, hint_penalty_pct=EXCLUDED.hint_penalty_pct, is_required=EXCLUDED.is_required, workspace_layout=EXCLUDED.workspace_layout, updated_at=now();\n\n",
		sqlString(labID), sqlString(seededOrgID), sqlString(courseID), sqlString(moduleID), sqlString(title),
		sqlString(kind.Name()), sqlString(kind.Image()), dollarQuote("script", kind.SetupScript()),
		sqlInt(maxDuration), sqlInt(maxResets), sqlInt(hintPenaltyPct), sqlBool(spec.IsRequired),
		sqlString(workspaceLayout), sqlString(seededInstructorID),
	)
	fmt.Fprintf(out,
		"INSERT INTO lab_recipes (id, org_id, owner_id, lab_kind, title, spec, lab_id, is_platform)\nVALUES (%s, %s, %s, %s, %s, %s::jsonb, %s, true)\nON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, lab_kind=EXCLUDED.lab_kind, lab_id=EXCLUDED.lab_id,\n  revision = CASE WHEN lab_recipes.spec IS DISTINCT FROM EXCLUDED.spec THEN lab_recipes.revision + 1 ELSE lab_recipes.revision END,\n  spec=EXCLUDED.spec, updated_at=now();\n\n",
		sqlString(canonical.LabRecipeID(idKey)), sqlString(seededOrgID), sqlString(seededInstructorID),
		sqlString(kind.Name()), sqlString(title), dollarQuote("json", string(specJSON)), sqlString(labID),
	)
	return nil
}
