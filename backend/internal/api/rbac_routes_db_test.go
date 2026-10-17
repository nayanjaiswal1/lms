package api

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"slices"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/redis/go-redis/v9"

	"github.com/mindforge/backend/internal/assessment"
	"github.com/mindforge/backend/internal/auth"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/certificates"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/entitlements"
	"github.com/mindforge/backend/internal/features"
	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/labs"
	"github.com/mindforge/backend/internal/library"
	"github.com/mindforge/backend/internal/mentoring"
	"github.com/mindforge/backend/internal/messaging"
	"github.com/mindforge/backend/internal/moderation"
	"github.com/mindforge/backend/internal/orgs"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
	"github.com/mindforge/backend/internal/tickets"
	"github.com/mindforge/backend/internal/wiki"
)

// TestRouteGuards_MatchLegacyOrgRoles runs one representative endpoint per
// former RequireOrgRole / CallerRole mapping for every system role and checks
// that the permission-code guard admits exactly the org_members.role labels
// the legacy check admitted. A guard denial is any 403; anything else (the
// handler ran: 2xx, 400, 404, 422, or a 500 from nil test dependencies) means
// the guard let the request through.
func TestRouteGuards_MatchLegacyOrgRoles(t *testing.T) {
	pool := testdb.New(t)
	ctx := context.Background()

	var orgID string
	if err := pool.QueryRow(ctx,
		`INSERT INTO organizations (name, slug, status) VALUES ('Guard Org', 'guard-org', 'active') RETURNING id`,
	).Scan(&orgID); err != nil {
		t.Fatalf("seed org: %v", err)
	}

	// Each persona is an org_members label plus the system roles it holds.
	// viewer and support_agent are learners whose member role an admin
	// replaced through the RBAC admin.
	personas := []struct {
		name, label string
		roles       []string
	}{
		{"viewer", "learner", []string{"viewer"}},
		{"member", "learner", []string{"member"}},
		{"instructor", "instructor", []string{"instructor"}},
		{"mentor", "mentor", []string{"mentor"}},
		{"tenant_admin/owner", "owner", []string{"tenant_admin"}},
		{"tenant_admin/admin", "admin", []string{"tenant_admin"}},
		{"support_agent", "learner", []string{"support_agent"}},
	}
	userIDs := map[string]string{}
	for i, p := range personas {
		var userID string
		if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`,
			fmt.Sprintf("guard-%d@%s", i, testdomain.Domain), p.name).Scan(&userID); err != nil {
			t.Fatalf("seed user %s: %v", p.name, err)
		}
		if _, err := pool.Exec(ctx,
			`INSERT INTO org_members (org_id, user_id, role, status) VALUES ($1, $2, $3, 'active')`,
			orgID, userID, p.label); err != nil {
			t.Fatalf("seed member %s: %v", p.name, err)
		}
		if _, err := pool.Exec(ctx,
			`INSERT INTO user_roles (user_id, role_id, org_id)
			 SELECT $1, id, $2 FROM roles WHERE is_system AND name = ANY($3)`,
			userID, orgID, p.roles); err != nil {
			t.Fatalf("seed roles %s: %v", p.name, err)
		}
		userIDs[p.name] = userID
	}

	// Unreachable Redis: the permission cache misses and every check reads
	// the database.
	rdb := redis.NewClient(&redis.Options{Addr: "127.0.0.1:1", MaxRetries: -1})
	perms := authz.NewService(authz.NewRepo(pool), authz.NewCache(rdb))
	cfg := &config.Config{}
	coursesRepo := courses.NewRepo(pool)

	r := chi.NewRouter()
	r.Use(chimw.Recoverer)
	features.New(pool, entitlements.New(pool, orgID).Service).RegisterOrgAdminRoutes(r, perms)
	orgs.NewHandler(cfg, pool, nil, nil, nil).RegisterRoutes(r, perms)
	jobs.NewHTTPHandler(pool, rdb, cfg, nil).RegisterRoutes(r, perms)
	messaging.New(pool, perms).RegisterRoutes(r)
	assessment.New(pool, cfg, nil, nil, nil, nil, nil).RegisterRoutes(r, perms)
	courses.NewHandler(coursesRepo, courses.NewService(coursesRepo, nil, nil, cfg, nil), nil, nil, rdb, cfg, perms).RegisterRoutes(r)
	wiki.New(pool, coursesRepo).RegisterRoutes(r, perms)
	mentoring.New(pool, tickets.NewRepo(pool), nil, nil, coursesRepo, nil, perms, cfg).RegisterRoutes(r)
	certificates.New(pool, coursesRepo, nil, nil, nil).RegisterRoutes(r, perms)
	library.New(pool, coursesRepo, nil, nil, nil).RegisterRoutes(r, perms)
	gitlab.New(pool, cfg, nil, nil, nil, nil).RegisterRoutes(r, perms)
	moderation.New(pool, perms).RegisterRoutes(r)
	labs.NewHandler(labs.NewRepo(pool), nil, pool, rdb, "", "", nil).RegisterAdminRoutes(r, perms)

	const missing = "00000000-0000-0000-0000-00000000dead"
	org := "/api/orgs/" + orgID
	ownerAdmin := []string{"owner", "admin"}
	authors := []string{"owner", "admin", "instructor"}
	staff := []string{"owner", "admin", "instructor", "mentor"}

	rows := []struct {
		name, method, path, body string
		legacy                   []string // org_members labels the legacy role check admitted
	}{
		{"features member flags: admin.manage_org", http.MethodGet, org + "/user-features/" + missing, "", ownerAdmin},
		{"org update: admin.manage_org", http.MethodPatch, org, "{}", ownerAdmin},
		{"org auth-config: admin.manage_org", http.MethodGet, org + "/auth-config", "", ownerAdmin},
		{"org domains: admin.manage_org", http.MethodGet, org + "/domains", "", ownerAdmin},
		{"org members: admin.manage_members", http.MethodGet, org + "/members", "", ownerAdmin},
		{"org invites: admin.manage_members", http.MethodGet, org + "/invites", "", ownerAdmin},
		{"gitlab installations: admin.manage_org", http.MethodGet, "/api/gitlab/installations", "", ownerAdmin},
		{"gitlab cohorts: projects.manage", http.MethodGet, "/api/workspace-cohorts", "", authors},
		{"gitlab dashboard: projects.manage|mentoring.view_students", http.MethodGet, "/api/workspace-cohorts/" + missing + "/dashboard", "", staff},
		{"org jobs: admin.manage_org|courses.edit", http.MethodGet, org + "/jobs/stats", "", authors},
		{"library: courses.edit", http.MethodGet, "/api/library", "", authors},
		{"course create: courses.create", http.MethodPost, "/api/courses", "{", authors},
		{"course edit: courses.edit", http.MethodPatch, "/api/courses/" + missing, "{", authors},
		{"course publish: courses.publish", http.MethodPost, "/api/courses/" + missing + "/publish", "", authors},
		{"course delete: courses.delete", http.MethodDelete, "/api/courses/" + missing, "", authors},
		{"course progress: courses.edit|mentoring.view_students", http.MethodGet, "/api/courses/" + missing + "/progress", "", staff},
		{"certificate threshold: courses.edit", http.MethodPut, "/api/courses/" + missing + "/certificate-threshold", "{", authors},
		{"certificate issue: courses.edit|mentoring.view_students", http.MethodPost, "/api/courses/" + missing + "/certificates/issue", "{", staff},
		{"faq create: courses.edit", http.MethodPost, "/api/courses/" + missing + "/faqs", "{", authors},
		// Legacy: owner, admin, instructor, mentor at the route.
		{"message resolve: messaging.moderate", http.MethodPost, "/api/messages/" + missing + "/resolve", "", staff},
		{"categories: assessments.manage_questions", http.MethodGet, "/api/categories", "", authors},
		{"batch create: assessments.manage_batches", http.MethodPost, "/api/batches", "{", authors},
		{"assessment create: assessments.create", http.MethodPost, "/api/assessments", "{", authors},
		{"assessment list: assessments.edit", http.MethodGet, "/api/assessments", "", authors},
		{"assessment status: assessments.publish", http.MethodPost, "/api/assessments/" + missing + "/status", "{", authors},
		{"batch list: assessments.view_results", http.MethodGet, "/api/batches", "", staff},
		// Legacy route gate admitted owner and admin; the service then
		// refused owner (it compared against "admin" only), which content.moderate fixes.
		{"wiki space delete: content.moderate", http.MethodDelete, "/api/wiki/spaces/" + missing, "", ownerAdmin},
		{"ticket claim: mentoring.claim_tickets", http.MethodPost, "/api/mentor-tickets/" + missing + "/claim", "", []string{"mentor"}},
		// Dashboard helpers — no legacy check; expected labels follow the
		// system role matrix for the route's code.
		{"grading queue: assessments.view_results", http.MethodGet, "/api/assessments/grading-queue", "", staff},
		{"my course summaries: courses.view_analytics", http.MethodGet, "/api/analytics/courses?mine=true", "", authors},
		{"report counts: content.moderate", http.MethodGet, "/api/content-reports/counts", "", ownerAdmin},
		{"lab usage: admin.manage_org", http.MethodGet, "/api/admin/labs/usage", "", ownerAdmin},
	}

	for _, row := range rows {
		for _, p := range personas {
			want := slices.Contains(row.legacy, p.label)
			req := httptest.NewRequest(row.method, row.path, strings.NewReader(row.body))
			req.Header.Set("Content-Type", "application/json")
			req = req.WithContext(auth.SetClaims(req.Context(), &auth.Claims{UserID: userIDs[p.name], OrgID: orgID}))
			rec := httptest.NewRecorder()
			r.ServeHTTP(rec, req)
			got := rec.Code != http.StatusForbidden
			if got != want {
				t.Errorf("%s as %s: allowed=%v (status %d: %s), legacy allowed=%v",
					row.name, p.name, got, rec.Code, strings.TrimSpace(rec.Body.String()), want)
			}
		}
	}
}
