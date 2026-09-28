package courses

import (
	"context"
	"testing"

	"github.com/mindforge/backend/internal/testdb"
)

// TestBundles covers the two paths where a mistake leaks access: enroll-in-all
// must only grant free published courses (paid ones reported, never enrolled),
// and the student view must hide draft bundles and unpublished courses.
func TestBundles(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()
	repo := NewRepo(pool)
	orgID, userID, draftCourseID := seedCourseFixture(t, ctx, pool)

	insertCourse := func(slug string, isFree bool) string {
		var id string
		if err := pool.QueryRow(ctx,
			`INSERT INTO courses (org_id, creator_id, title, slug, status, is_free, price_cents)
			 VALUES ($1, $2, $3, $3, 'published', $4, CASE WHEN $4 THEN 0 ELSE 49900 END) RETURNING id`,
			orgID, userID, slug, isFree,
		).Scan(&id); err != nil {
			t.Fatalf("seed course %s: %v", slug, err)
		}
		return id
	}
	freeID := insertCourse("free-course", true)
	paidID := insertCourse("paid-course", false)

	b, err := repo.CreateBundle(ctx, Bundle{OrgID: orgID, CreatorID: userID, Title: "Backend Path", Slug: "backend-path", Status: BundleStatusDraft})
	if err != nil {
		t.Fatalf("CreateBundle: %v", err)
	}
	if err := repo.SetBundleCourses(ctx, orgID, b.ID, []string{paidID, draftCourseID, freeID}); err != nil {
		t.Fatalf("SetBundleCourses: %v", err)
	}

	if _, err := repo.GetBundleDetail(ctx, orgID, userID, "", "backend-path", true); err != ErrNotFound {
		t.Fatalf("draft bundle visible to students: got %v", err)
	}
	if _, err := repo.EnrollInBundle(ctx, orgID, userID, b.ID); err != ErrNotFound {
		t.Fatalf("enroll into draft bundle: expected ErrNotFound, got %v", err)
	}

	b.Status = BundleStatusPublished
	if _, err := repo.UpdateBundle(ctx, orgID, b); err != nil {
		t.Fatalf("UpdateBundle: %v", err)
	}
	d, err := repo.GetBundleDetail(ctx, orgID, userID, "", "backend-path", true)
	if err != nil {
		t.Fatalf("GetBundleDetail: %v", err)
	}
	if len(d.Courses) != 2 || d.Courses[0].ID != paidID || d.Courses[1].ID != freeID {
		t.Fatalf("expected [paid, free] with draft hidden, got %+v", d.Courses)
	}
	if all, _ := repo.GetBundleDetail(ctx, orgID, userID, b.ID, "", false); len(all.Courses) != 3 {
		t.Fatalf("editor view should include the draft course, got %d", len(all.Courses))
	}

	res, err := repo.EnrollInBundle(ctx, orgID, userID, b.ID)
	if err != nil {
		t.Fatalf("EnrollInBundle: %v", err)
	}
	if len(res.EnrolledCourseIDs) != 1 || res.EnrolledCourseIDs[0] != freeID {
		t.Errorf("expected only the free course enrolled, got %v", res.EnrolledCourseIDs)
	}
	if len(res.RequiresPurchaseCourseIDs) != 1 || res.RequiresPurchaseCourseIDs[0] != paidID {
		t.Errorf("expected the paid course reported, got %v", res.RequiresPurchaseCourseIDs)
	}
	if ok, _ := repo.IsEnrolled(ctx, userID, paidID); ok {
		t.Error("paid course must never be enrolled through a bundle")
	}
	if again, err := repo.EnrollInBundle(ctx, orgID, userID, b.ID); err != nil || len(again.EnrolledCourseIDs) != 0 {
		t.Errorf("re-enroll should be a no-op, got %+v, %v", again, err)
	}

	if refs, err := repo.GetBundlesForCourse(ctx, orgID, freeID); err != nil || len(refs) != 1 || refs[0].Slug != "backend-path" {
		t.Errorf("GetBundlesForCourse: got %+v, %v", refs, err)
	}

	var otherOrg string
	if err := pool.QueryRow(ctx, `INSERT INTO organizations (slug, name) VALUES ('other-org', 'Other') RETURNING id`).Scan(&otherOrg); err != nil {
		t.Fatalf("seed other org: %v", err)
	}
	if err := repo.SetBundleCourses(ctx, otherOrg, b.ID, []string{freeID}); err != ErrNotFound {
		t.Errorf("cross-org SetBundleCourses: expected ErrNotFound, got %v", err)
	}
}
