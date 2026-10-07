package labs

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"

	"github.com/mindforge/backend/internal/testdb"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// seedLabFixture inserts the minimum org/user/course/section/module rows a
// DB-backed labs test needs, plus one published lab linked through
// course_modules.lab_id (migration 044_course_library.sql) — the resolution
// path GetLabByModuleID now uses instead of lab_definitions.module_id.
func seedLabFixture(t *testing.T, ctx context.Context, pool *pgxpool.Pool) (orgID, userID, moduleID, labID string) {
	t.Helper()

	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO organizations (slug, name) VALUES ('acme-labs', 'Acme Labs') RETURNING id`,
	).Scan(&orgID))
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO users (email, name) VALUES ('instructor@example.com', 'Instructor') RETURNING id`,
	).Scan(&userID))

	var courseID, sectionID string
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO courses (org_id, creator_id, title, slug) VALUES ($1,$2,'Course','course') RETURNING id`,
		orgID, userID,
	).Scan(&courseID))
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO course_sections (course_id, title, position) VALUES ($1,'Section',0) RETURNING id`,
		courseID,
	).Scan(&sectionID))

	// lab_definitions first (module_id NULL — the legacy column, unused on
	// this resolution path) since course_modules.lab_id's FK is DEFERRABLE
	// INITIALLY DEFERRED specifically so either insert order works; here we
	// have the lab row ready before the module needs to reference it.
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO lab_definitions (org_id, title, lab_type, environment, is_published, created_by, library_visibility, scope)
		 VALUES ($1,'Lab','terminal','mindforge/lab-terminal:1',true,$2,'org','standalone') RETURNING id`,
		orgID, userID,
	).Scan(&labID))
	var versionID string
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO lab_task_versions (lab_id, version, tasks, published_by) VALUES ($1,1,'[]'::jsonb,$2) RETURNING id`,
		labID, userID,
	).Scan(&versionID))
	_, err := pool.Exec(ctx, `UPDATE lab_definitions SET published_version_id=$2 WHERE id=$1`, labID, versionID)
	require.NoError(t, err)

	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO course_modules (course_id, section_id, title, type, position, lab_id, lab_is_required)
		 VALUES ($1,$2,'Lab Module','lab',0,$3,true) RETURNING id`,
		courseID, sectionID, labID,
	).Scan(&moduleID))

	return orgID, userID, moduleID, labID
}

// TestGetLabByModuleID_ResolvesThroughLabID is the regression check for the
// fork bug (docs/debug-labs.md L0): resolution must go through
// course_modules.lab_id, not lab_definitions.module_id (which this fixture
// deliberately leaves NULL), and must return the PLACEMENT's
// lab_is_required, not the lab's own legacy default.
func TestGetLabByModuleID_ResolvesThroughLabID(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	orgID, _, moduleID, labID := seedLabFixture(t, ctx, pool)

	lab, err := repo.GetLabByModuleID(ctx, moduleID, orgID)
	require.NoError(t, err)
	require.Equal(t, labID, lab.ID)
	require.Nil(t, lab.ModuleID, "lab_definitions.module_id was left NULL by the fixture — resolution must not depend on it")
	require.True(t, lab.IsRequired, "IsRequired must come from the placement's course_modules.lab_is_required")
}

// TestGetLabByModuleID_CrossOrgRejected confirms a module in one org never
// resolves a lab through a course belonging to another org, even if the
// caller somehow guesses a real module id.
func TestGetLabByModuleID_CrossOrgRejected(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	_, _, moduleID, _ := seedLabFixture(t, ctx, pool)

	var otherOrgID string
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO organizations (slug, name) VALUES ('other-org', 'Other Org') RETURNING id`,
	).Scan(&otherOrgID))

	_, err := repo.GetLabByModuleID(ctx, moduleID, otherOrgID)
	require.ErrorIs(t, err, ErrNotFound)
}
