package labs

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

// TestSessionBuildID_RepublishDoesNotRepointInFlightSession guards the debug-lab
// republish bug: a session pinned to a task version must keep resolving the
// build that version was published from, while a session started after the
// republish resolves the new build — even though lab_definitions.build_id has
// already moved on.
func TestSessionBuildID_RepublishDoesNotRepointInFlightSession(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	orgID, userID, _, labID := seedLabFixture(t, ctx, pool)

	var recipeID, otherUserID string
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO lab_recipes (org_id, owner_id, lab_kind, title, spec) VALUES ($1,$2,'debug','Recipe','[]'::jsonb) RETURNING id`,
		orgID, userID).Scan(&recipeID))
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO users (email, name) VALUES ('student@`+testdomain.Domain+`', 'Student') RETURNING id`,
	).Scan(&otherUserID))

	// publish mirrors labbuild's publishLab: new build -> new task version
	// carrying build_id -> lab_definitions points at both.
	publish := func(version int, hash string) (buildID, versionID string) {
		require.NoError(t, pool.QueryRow(ctx,
			`INSERT INTO lab_builds (recipe_id, recipe_hash, spec_snapshot, status, created_by) VALUES ($1,$2,'{}'::jsonb,'verified',$3) RETURNING id`,
			recipeID, hash, userID).Scan(&buildID))
		require.NoError(t, pool.QueryRow(ctx,
			`INSERT INTO lab_task_versions (lab_id, version, tasks, published_by, build_id) VALUES ($1,$2,'[]'::jsonb,$3,$4) RETURNING id`,
			labID, version, userID, buildID).Scan(&versionID))
		_, err := pool.Exec(ctx,
			`UPDATE lab_definitions SET published_version_id=$2, build_id=$3 WHERE id=$1`, labID, versionID, buildID)
		require.NoError(t, err)
		return buildID, versionID
	}
	startSession := func(uid, versionID string) *LabSession {
		tx, err := pool.Begin(ctx)
		require.NoError(t, err)
		s, err := repo.CreateSession(ctx, tx, CreateSessionParams{
			LabID: labID, TaskVersionID: versionID, UserID: uid, OrgID: orgID,
			ExpiresAt: time.Now().Add(time.Hour),
		})
		require.NoError(t, err)
		require.NoError(t, tx.Commit(ctx))
		return s
	}

	build1, version1 := publish(2, "hash-build-1")
	inFlight := startSession(userID, version1)

	build2, version2 := publish(3, "hash-build-2")
	require.NotEqual(t, build1, build2)

	lab, err := repo.GetLab(ctx, labID, orgID)
	require.NoError(t, err)
	require.NotNil(t, lab.BuildID)
	require.Equal(t, build2, *lab.BuildID, "lab's current build must be the republished one")

	require.Equal(t, build1, sessionBuildID(ctx, repo, lab, inFlight), "in-flight session must stay pinned to build 1")
	fresh := startSession(otherUserID, version2)
	require.Equal(t, build2, sessionBuildID(ctx, repo, lab, fresh), "new session must resolve build 2")
}
