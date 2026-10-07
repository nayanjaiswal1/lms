package library

import (
	"context"
	"github.com/mindforge/backend/internal/testdomain"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"

	"github.com/mindforge/backend/internal/assessment"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/labs"
	"github.com/mindforge/backend/internal/testdb"
)

func TestMain(m *testing.M) { testdb.RunMain(m) }

// libraryFixture is the minimum org/user/course/section rows every Attach
// test needs, plus one published, org-visible lab ready to place.
type libraryFixture struct {
	orgID, userID, courseID, sectionID, labID string
}

func seedLibraryFixture(t *testing.T, ctx context.Context, pool *pgxpool.Pool) libraryFixture {
	t.Helper()
	var f libraryFixture

	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO organizations (slug, name) VALUES ('acme-library', 'Acme Library') RETURNING id`,
	).Scan(&f.orgID))
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO users (email, name) VALUES ('builder@`+testdomain.Domain+`', 'Builder') RETURNING id`,
	).Scan(&f.userID))
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO courses (org_id, creator_id, title, slug) VALUES ($1,$2,'Course','course') RETURNING id`,
		f.orgID, f.userID,
	).Scan(&f.courseID))
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO course_sections (course_id, title, position) VALUES ($1,'Section',0) RETURNING id`,
		f.courseID,
	).Scan(&f.sectionID))

	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO lab_definitions (org_id, title, lab_type, environment, is_published, created_by, library_visibility, scope)
		 VALUES ($1,'Debug Django','terminal','mindforge/lab-terminal:1',true,$2,'org','standalone') RETURNING id`,
		f.orgID, f.userID,
	).Scan(&f.labID))
	var versionID string
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO lab_task_versions (lab_id, version, tasks, published_by) VALUES ($1,1,'[]'::jsonb,$2) RETURNING id`,
		f.labID, f.userID,
	).Scan(&versionID))
	_, err := pool.Exec(ctx, `UPDATE lab_definitions SET published_version_id=$2 WHERE id=$1`, f.labID, versionID)
	require.NoError(t, err)

	return f
}

func newTestService(pool *pgxpool.Pool) *Service {
	return NewService(pool, NewRepo(pool), courses.NewRepo(pool), labs.NewRepo(pool), nil, assessment.NewRepo(pool))
}

// TestAttach_InsertsLabModuleAndShiftsPositions is the regression check for
// docs/debug-labs.md L3 steps 4-5: attaching at an existing position shifts
// every module at or after it down by one, and the new module lands at
// exactly the requested position with lab_id/lab_is_required set.
func TestAttach_InsertsLabModuleAndShiftsPositions(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	f := seedLibraryFixture(t, ctx, pool)
	svc := newTestService(pool)

	coursesRepo := courses.NewRepo(pool)
	// Two pre-existing modules at position 0 and 1.
	first, err := coursesRepo.CreateModule(ctx, courses.CourseModule{
		CourseID: f.courseID, SectionID: f.sectionID, Title: "First", Type: courses.ModuleTypeVideo,
	})
	require.NoError(t, err)
	second, err := coursesRepo.CreateModule(ctx, courses.CourseModule{
		CourseID: f.courseID, SectionID: f.sectionID, Title: "Second", Type: courses.ModuleTypeVideo,
	})
	require.NoError(t, err)
	require.Equal(t, 0, first.Position)
	require.Equal(t, 1, second.Position)

	insertAt := 1
	inserted, err := svc.Attach(ctx, f.orgID, f.userID, AttachReq{
		SectionID:  f.sectionID,
		Position:   &insertAt,
		Kind:       KindLab,
		ItemID:     f.labID,
		IsRequired: true,
	})
	require.NoError(t, err)
	require.Equal(t, 1, inserted.Position)
	require.Equal(t, courses.ModuleTypeLab, inserted.Type)
	require.NotNil(t, inserted.LabID)
	require.Equal(t, f.labID, *inserted.LabID)
	require.True(t, inserted.LabIsRequired)

	// "Second" must have shifted from 1 to 2; "First" stays at 0.
	reloadedFirst, err := coursesRepo.GetModule(ctx, f.orgID, first.ID)
	require.NoError(t, err)
	require.Equal(t, 0, reloadedFirst.Position)
	reloadedSecond, err := coursesRepo.GetModule(ctx, f.orgID, second.ID)
	require.NoError(t, err)
	require.Equal(t, 2, reloadedSecond.Position)
}

// TestAttach_AppendsWhenPositionOmitted covers the nil-Position "append at
// end" default the frontend picker always uses in Phase A.
func TestAttach_AppendsWhenPositionOmitted(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	f := seedLibraryFixture(t, ctx, pool)
	svc := newTestService(pool)

	coursesRepo := courses.NewRepo(pool)
	_, err := coursesRepo.CreateModule(ctx, courses.CourseModule{
		CourseID: f.courseID, SectionID: f.sectionID, Title: "Only", Type: courses.ModuleTypeVideo,
	})
	require.NoError(t, err)

	inserted, err := svc.Attach(ctx, f.orgID, f.userID, AttachReq{
		SectionID: f.sectionID, Kind: KindLab, ItemID: f.labID,
	})
	require.NoError(t, err)
	require.Equal(t, 1, inserted.Position)
}

// TestAttach_CrossOrgSectionRejected confirms an actor from another org
// can't attach into a section it doesn't own — LockSectionForOrg's org-scoped
// query is the "actor can edit this course" check (docs/debug-labs.md L3
// step 2).
func TestAttach_CrossOrgSectionRejected(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	f := seedLibraryFixture(t, ctx, pool)
	svc := newTestService(pool)

	var otherOrgID string
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO organizations (slug, name) VALUES ('other-library-org', 'Other Org') RETURNING id`,
	).Scan(&otherOrgID))

	_, err := svc.Attach(ctx, otherOrgID, f.userID, AttachReq{
		SectionID: f.sectionID, Kind: KindLab, ItemID: f.labID,
	})
	require.ErrorIs(t, err, courses.ErrNotFound)
}

// TestAttach_CrossOrgLabRejected confirms a lab owned by another org (and not
// library_visibility='platform') cannot be attached even into a section the
// actor genuinely owns.
func TestAttach_CrossOrgLabRejected(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	f := seedLibraryFixture(t, ctx, pool)
	svc := newTestService(pool)

	var otherOrgID, otherUserID, otherLabID string
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO organizations (slug, name) VALUES ('other-lab-org', 'Other Lab Org') RETURNING id`,
	).Scan(&otherOrgID))
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO users (email, name) VALUES ('other@`+testdomain.Domain+`', 'Other') RETURNING id`,
	).Scan(&otherUserID))
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO lab_definitions (org_id, title, lab_type, environment, is_published, created_by, library_visibility, scope)
		 VALUES ($1,'Private Lab','terminal','mindforge/lab-terminal:1',true,$2,'org','standalone') RETURNING id`,
		otherOrgID, otherUserID,
	).Scan(&otherLabID))

	_, err := svc.Attach(ctx, f.orgID, f.userID, AttachReq{
		SectionID: f.sectionID, Kind: KindLab, ItemID: otherLabID,
	})
	require.ErrorIs(t, err, ErrNotFound)
}
