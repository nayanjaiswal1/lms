package assessment

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sort"
	"testing"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/testdb"
)

type mentorFixture struct {
	pool                         *pgxpool.Pool
	orgID                        string
	mentorA, mentorB, instructor string
	batchA, batchB, batchViaMem  string
}

func mentorSeedUser(t *testing.T, pool *pgxpool.Pool, orgID, role, tag string) string {
	t.Helper()
	ctx := context.Background()
	var id string
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`,
		fmt.Sprintf("mentor-scope-%s@example.com", tag), tag).Scan(&id); err != nil {
		t.Fatalf("seed user %s: %v", tag, err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO org_members (org_id, user_id, role) VALUES ($1, $2, $3)`, orgID, id, role); err != nil {
		t.Fatalf("seed member %s: %v", tag, err)
	}
	return id
}

func mentorSeedBatch(t *testing.T, pool *pgxpool.Pool, orgID, createdBy string, mentorID *string, slug string) string {
	t.Helper()
	var id string
	if err := pool.QueryRow(context.Background(),
		`INSERT INTO batches (org_id, name, slug, created_by, mentor_id) VALUES ($1, $2, $2, $3, $4) RETURNING id`,
		orgID, slug, createdBy, mentorID).Scan(&id); err != nil {
		t.Fatalf("seed batch %s: %v", slug, err)
	}
	return id
}

// newMentorFixture: mentorA owns batchA via batches.mentor_id and batchViaMem
// via a batch_members 'mentor' row; mentorB owns batchB.
func newMentorFixture(t *testing.T) mentorFixture {
	t.Helper()
	pool := testdb.New(t)
	ctx := context.Background()
	f := mentorFixture{pool: pool}
	if err := pool.QueryRow(ctx, `INSERT INTO organizations (name, slug) VALUES ('Mentor Scope Org', 'mentor-scope-org') RETURNING id`).Scan(&f.orgID); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	f.mentorA = mentorSeedUser(t, pool, f.orgID, "mentor", "a")
	f.mentorB = mentorSeedUser(t, pool, f.orgID, "mentor", "b")
	f.instructor = mentorSeedUser(t, pool, f.orgID, "instructor", "i")
	f.batchA = mentorSeedBatch(t, pool, f.orgID, f.instructor, &f.mentorA, "batch-a")
	f.batchB = mentorSeedBatch(t, pool, f.orgID, f.instructor, &f.mentorB, "batch-b")
	f.batchViaMem = mentorSeedBatch(t, pool, f.orgID, f.instructor, nil, "batch-mem")
	if _, err := pool.Exec(ctx, `INSERT INTO batch_members (batch_id, user_id, role) VALUES ($1, $2, 'mentor')`, f.batchViaMem, f.mentorA); err != nil {
		t.Fatalf("seed batch member: %v", err)
	}
	return f
}

func TestMentorBatchIDs_OnlyOwnBatches(t *testing.T) {
	f := newMentorFixture(t)
	ctx := context.Background()

	got, err := mentorBatchIDs(ctx, f.pool, f.orgID, f.mentorA)
	if err != nil {
		t.Fatalf("mentorBatchIDs: %v", err)
	}
	want := []string{f.batchA, f.batchViaMem}
	sort.Strings(got)
	sort.Strings(want)
	if fmt.Sprint(got) != fmt.Sprint(want) {
		t.Fatalf("mentorA batches = %v, want %v", got, want)
	}

	gotB, err := mentorBatchIDs(ctx, f.pool, f.orgID, f.mentorB)
	if err != nil || len(gotB) != 1 || gotB[0] != f.batchB {
		t.Fatalf("mentorB batches = %v (err %v), want [%s]", gotB, err, f.batchB)
	}

	var otherOrg string
	if err := f.pool.QueryRow(ctx, `INSERT INTO organizations (name, slug) VALUES ('Other Org', 'mentor-scope-other') RETURNING id`).Scan(&otherOrg); err != nil {
		t.Fatalf("seed other org: %v", err)
	}
	if ids, _ := mentorBatchIDs(ctx, f.pool, otherOrg, f.mentorA); len(ids) != 0 {
		t.Fatalf("mentor must see nothing in another org, got %v", ids)
	}
}

func TestMentorScopeIDs_NonMentorUnscoped(t *testing.T) {
	f := newMentorFixture(t)
	ids, scoped, err := mentorScopeIDs(context.Background(), f.pool, &auth.Claims{UserID: f.instructor, OrgID: f.orgID})
	if err != nil || scoped || ids != nil {
		t.Fatalf("instructor: ids=%v scoped=%v err=%v, want unscoped", ids, scoped, err)
	}
	_, scoped, err = mentorScopeIDs(context.Background(), f.pool, &auth.Claims{UserID: f.mentorA, OrgID: f.orgID})
	if err != nil || !scoped {
		t.Fatalf("mentor: scoped=%v err=%v, want scoped", scoped, err)
	}
}

func TestMentorBatchScope_Middleware(t *testing.T) {
	f := newMentorFixture(t)
	r := chi.NewRouter()
	r.With(mentorBatchScope(f.pool)).Get("/batches/{batchID}", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	call := func(userID, batchID string) int {
		req := httptest.NewRequest(http.MethodGet, "/batches/"+batchID, nil)
		req = req.WithContext(auth.SetClaims(req.Context(), &auth.Claims{UserID: userID, OrgID: f.orgID}))
		rec := httptest.NewRecorder()
		r.ServeHTTP(rec, req)
		return rec.Code
	}

	cases := []struct {
		name    string
		user    string
		batch   string
		wantHTT int
	}{
		{"mentor own batch via mentor_id", f.mentorA, f.batchA, http.StatusOK},
		{"mentor own batch via membership", f.mentorA, f.batchViaMem, http.StatusOK},
		{"mentor other mentor's batch", f.mentorA, f.batchB, http.StatusForbidden},
		{"other mentor reading A's batch", f.mentorB, f.batchA, http.StatusForbidden},
		{"instructor unrestricted", f.instructor, f.batchB, http.StatusOK},
	}
	for _, c := range cases {
		if got := call(c.user, c.batch); got != c.wantHTT {
			t.Errorf("%s: status %d, want %d", c.name, got, c.wantHTT)
		}
	}
}

func TestMentorAssessmentScope_OnlyAssignedToOwnBatches(t *testing.T) {
	f := newMentorFixture(t)
	ctx := context.Background()
	var assessmentID string
	if err := f.pool.QueryRow(ctx,
		`INSERT INTO assessments (org_id, title, slug, created_by) VALUES ($1, 'Scope Quiz', 'scope-quiz', $2) RETURNING id`,
		f.orgID, f.instructor).Scan(&assessmentID); err != nil {
		t.Fatalf("seed assessment: %v", err)
	}
	if _, err := f.pool.Exec(ctx,
		`INSERT INTO content_assignments (content_type, content_id, assignee_type, assignee_id, assigned_by)
		 VALUES ('assessment', $1, 'batch', $2, $3)`,
		assessmentID, f.batchB, f.instructor); err != nil {
		t.Fatalf("seed assignment: %v", err)
	}

	r := chi.NewRouter()
	r.With(mentorAssessmentScope(f.pool)).Get("/assessments/{assessmentID}", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
	call := func(userID string) int {
		req := httptest.NewRequest(http.MethodGet, "/assessments/"+assessmentID, nil)
		req = req.WithContext(auth.SetClaims(req.Context(), &auth.Claims{UserID: userID, OrgID: f.orgID}))
		rec := httptest.NewRecorder()
		r.ServeHTTP(rec, req)
		return rec.Code
	}
	if got := call(f.mentorB); got != http.StatusOK {
		t.Errorf("mentorB (assigned batch): status %d, want 200", got)
	}
	if got := call(f.mentorA); got != http.StatusForbidden {
		t.Errorf("mentorA (unassigned): status %d, want 403", got)
	}
}
