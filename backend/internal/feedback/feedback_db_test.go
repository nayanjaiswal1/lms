package feedback

import (
	"context"
	"errors"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

// TestSubmitKinds: a rating and an experience report on the same subject are
// separate rows, each read back by its kind, and each kind only accepts its
// own answer.
func TestSubmitKinds(t *testing.T) {
	pool := testdb.New(t)
	svc := NewService(NewRepo(pool), nil)
	ctx := context.Background()

	var orgID, userID, subjectID string
	if err := pool.QueryRow(ctx, `INSERT INTO organizations (slug, name) VALUES ('fb-kinds', 'F') RETURNING id`).Scan(&orgID); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ('fb@`+testdomain.Domain+`', 'F') RETURNING id`).Scan(&userID); err != nil {
		t.Fatalf("seed user: %v", err)
	}
	if err := pool.QueryRow(ctx, `SELECT gen_random_uuid()::text`).Scan(&subjectID); err != nil {
		t.Fatalf("subject id: %v", err)
	}

	four := 4
	issue := Experience("issue")
	note := "timer froze"
	base := SubmitRequest{SubjectType: SubjectTypeAssessment, SubjectID: subjectID}

	rating := base
	rating.Rating = &four
	if _, err := svc.Submit(ctx, &orgID, userID, rating); err != nil {
		t.Fatalf("rating: %v", err)
	}
	exp := base
	exp.Kind, exp.Experience, exp.Comment = KindExperience, &issue, &note
	if _, err := svc.Submit(ctx, &orgID, userID, exp); err != nil {
		t.Fatalf("experience: %v", err)
	}

	got, err := svc.GetMine(ctx, KindExperience, SubjectTypeAssessment, subjectID, userID)
	if err != nil || got.Experience == nil || *got.Experience != issue || got.Rating != nil {
		t.Fatalf("experience read back = %+v, %v", got, err)
	}
	if got, err := svc.GetMine(ctx, KindRating, SubjectTypeAssessment, subjectID, userID); err != nil || got.Rating == nil || *got.Rating != 4 {
		t.Fatalf("rating read back = %+v, %v", got, err)
	}

	mixed := exp
	mixed.Rating = &four
	if _, err := svc.Submit(ctx, &orgID, userID, mixed); !errors.Is(err, ErrInvalid) {
		t.Fatalf("experience with rating: err = %v, want ErrInvalid", err)
	}
	missing := base
	missing.Kind = KindExperience
	if _, err := svc.Submit(ctx, &orgID, userID, missing); !errors.Is(err, ErrInvalid) {
		t.Fatalf("experience without answer: err = %v, want ErrInvalid", err)
	}
}
