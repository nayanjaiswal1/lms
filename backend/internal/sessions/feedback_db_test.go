package sessions

import (
	"context"
	"testing"
	"time"
)

// TestUpsertFeedbackCarriesSessionOrg: feedback.org_id is NOT NULL, so a
// session rating must take its org from the session row.
func TestUpsertFeedbackCarriesSessionOrg(t *testing.T) {
	f := newBookingFixture(t, false)
	student := f.addMember(t, f.orgID, "student", "learner")
	sess, err := f.book(student, time.Now().Add(48*time.Hour).Truncate(time.Hour))
	if err != nil {
		t.Fatalf("book: %v", err)
	}
	if _, err := f.repo.UpsertFeedback(context.Background(), Feedback{SessionID: sess.ID, AuthorID: student, Rating: 5}); err != nil {
		t.Fatalf("upsert feedback: %v", err)
	}
	var orgID string
	if err := f.repo.pool.QueryRow(context.Background(),
		`SELECT org_id FROM feedback WHERE subject_type = 'mentor_session' AND subject_id = $1`, sess.ID).Scan(&orgID); err != nil || orgID != f.orgID {
		t.Fatalf("feedback org = %q, %v; want %q", orgID, err, f.orgID)
	}
}
