package practice

import (
	"context"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

// Practice items live in attempt_answers, which has no ordering column of its
// own: position comes from the linked assessment_questions row. These tests
// run the real schema end to end.
func TestRepo_SessionItemsRoundTrip(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)

	var orgID, userID string
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO organizations (slug, name) VALUES ('acme-practice', 'Acme') RETURNING id`).Scan(&orgID))
	require.NoError(t, pool.QueryRow(ctx,
		`INSERT INTO users (email, name) VALUES ('learner@`+testdomain.Domain+`', 'Learner') RETURNING id`).Scan(&userID))

	session, err := repo.CreateSession(ctx, PracticeSession{UserID: userID, OrgID: &orgID, Technology: "Go"})
	require.NoError(t, err)

	// A second session for the same technology must not collide on the slug.
	_, err = repo.CreateSession(ctx, PracticeSession{UserID: userID, OrgID: &orgID, Technology: "Go"})
	require.NoError(t, err)

	items, err := repo.InsertItems(ctx, session.ID, []string{"What is a goroutine?", "What is a channel?", "What is select?"})
	require.NoError(t, err)
	require.Len(t, items, 3)

	got, err := repo.GetSession(ctx, session.ID, userID)
	require.NoError(t, err)
	require.Equal(t, "Go", got.Technology)
	require.Equal(t, StatusActive, got.Status)
	require.Equal(t, 3, got.QuestionCount)
	require.Len(t, got.Items, 3)
	for i, it := range got.Items {
		require.Equal(t, i, it.Position)
	}
	require.Equal(t, "What is a channel?", got.Items[1].QuestionText)

	saved, _, err := repo.SaveAnswer(ctx, session.ID, userID, 1, "A typed conduit between goroutines")
	require.NoError(t, err)
	require.Equal(t, 1, saved.Position)
	require.Equal(t, "What is a channel?", saved.QuestionText)
	require.NotNil(t, saved.UserAnswer)

	_, _, err = repo.SaveAnswer(ctx, session.ID, userID, 9, "no such item")
	require.ErrorIs(t, err, ErrNotFound)

	withFeedback, err := repo.SaveFeedback(ctx, saved.ID, AIFeedback{Score: 7, MaxScore: 10})
	require.NoError(t, err)
	require.Equal(t, 1, withFeedback.Position)

	byPos, err := repo.GetItemByPosition(ctx, session.ID, userID, 1)
	require.NoError(t, err)
	require.NotNil(t, byPos.AIFeedback)
	require.Equal(t, 7, byPos.AIFeedback.Score)

	require.NoError(t, repo.UpdateSessionStatus(ctx, session.ID, userID, StatusCompleted))
	done, err := repo.GetSession(ctx, session.ID, userID)
	require.NoError(t, err)
	require.Equal(t, StatusCompleted, done.Status)
	require.NotNil(t, done.CompletedAt)

	_, err = repo.GetSession(ctx, session.ID, "00000000-0000-0000-0000-000000000099")
	require.ErrorIs(t, err, ErrNotFound)
}
