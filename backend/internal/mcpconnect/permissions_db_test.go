package mcpconnect

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"slices"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/testdb"
	"github.com/mindforge/backend/internal/testdomain"
)

var systemRoles = []string{"viewer", "member", "instructor", "mentor", "tenant_admin", "support_agent"}

type permFixture struct {
	pool  *pgxpool.Pool
	rt    *Router
	orgID string
	users map[string]string // system role -> user id
}

func seedPermUser(t *testing.T, pool *pgxpool.Pool, orgID, tag, status string, roles ...string) string {
	t.Helper()
	ctx := context.Background()
	var id string
	if err := pool.QueryRow(ctx, `INSERT INTO users (email, name) VALUES ($1, $2) RETURNING id`,
		"mcp-perm-"+tag+"@"+testdomain.Domain, tag).Scan(&id); err != nil {
		t.Fatalf("seed user %s: %v", tag, err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO org_members (org_id, user_id, role, status) VALUES ($1, $2, 'learner', $3)`,
		orgID, id, status); err != nil {
		t.Fatalf("seed member %s: %v", tag, err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO user_roles (user_id, role_id, org_id)
		SELECT $1, id, $2 FROM roles WHERE is_system AND name = ANY($3)`, id, orgID, roles); err != nil {
		t.Fatalf("seed roles %s: %v", tag, err)
	}
	return id
}

func newPermFixture(t *testing.T) permFixture {
	t.Helper()
	pool := testdb.New(t)
	// Unreachable Redis: the permission cache misses and falls through to the DB.
	rdb := redis.NewClient(&redis.Options{Addr: "127.0.0.1:1", MaxRetries: -1})
	f := permFixture{
		pool:  pool,
		rt:    &Router{pool: pool, repo: NewRepo(pool), perms: authz.NewService(authz.NewRepo(pool), authz.NewCache(rdb))},
		users: map[string]string{},
	}
	if err := pool.QueryRow(context.Background(),
		`INSERT INTO organizations (name, slug) VALUES ('MCP Perm Org', 'mcp-perm-org') RETURNING id`).Scan(&f.orgID); err != nil {
		t.Fatalf("seed org: %v", err)
	}
	for _, role := range systemRoles {
		f.users[role] = seedPermUser(t, pool, f.orgID, role, "active", role)
	}
	return f
}

func allScopesIdentity(orgID, userID string) mcpIdentity {
	scopes := map[string]bool{}
	for _, s := range AllScopes {
		scopes[s] = true
	}
	return mcpIdentity{OrgID: orgID, UserID: userID, ConnectionID: "conn", Scopes: scopes}
}

// Every tool declares a Permission that is either the active-member
// sentinel or a live permission code, so a typo can never silently deny (or
// a missing value silently allow) a tool.
func TestToolPermissionsAreLiveCodes(t *testing.T) {
	pool := testdb.New(t)
	for _, tool := range tools {
		if tool.Permission == permActiveMember {
			continue
		}
		var exists bool
		if err := pool.QueryRow(context.Background(),
			`SELECT EXISTS(SELECT 1 FROM permissions WHERE code = $1 AND is_active)`, tool.Permission).Scan(&exists); err != nil {
			t.Fatalf("lookup %s: %v", tool.Permission, err)
		}
		if !exists {
			t.Errorf("tool %s declares unknown permission %q", tool.Name, tool.Permission)
		}
	}
}

// TestToolGate_MatchesRESTGate: one representative tool per REST gate, each
// system role's expected allow/deny copied from the REST route's
// RequirePermission (or its absence) and the golden role matrix.
func TestToolGate_MatchesRESTGate(t *testing.T) {
	f := newPermFixture(t)
	ctx := context.Background()
	all := systemRoles
	learners := []string{"member", "instructor", "mentor"}
	learnersAndAdmin := []string{"member", "instructor", "mentor", "tenant_admin"}

	cases := []struct {
		tool    string
		allowed []string
	}{
		{"list_my_courses", all},                // /api/enrollments/me: any member
		{"save_my_lesson_note", all},            // PUT /api/modules/{id}/notes: any member
		{"log_understanding", all},              // POST /api/modules/{id}/reflection: any member
		{"list_calendar_events", all},           // /api/calendar/events: any member
		{"list_habits", all},                    // /api/habits: any member
		{"log_mistake", learners},               // /api/mistakes: practice.use
		{"list_interview_prep_plans", learners}, // /api/interview-prep: practice.use
		{"get_due_revisions", learners},         // /api/srs/due: content.srs
		{"list_my_sheets", learners},            // /api/user/sheets: content.sheets
		{"update_problem_progress", learners},   // /api/progress/{tag}: content.sheets
		{"list_journal_entries", learners},      // /api/journal: content.learning_journal (tenant_admin lost it in 010)
		{"create_journal_entry", learners},
		{"list_system_design_attempts", learnersAndAdmin}, // content.system_design
		{"list_wiki_spaces", learnersAndAdmin},            // content.wiki
		{"create_wiki_page", learnersAndAdmin},
	}
	for _, c := range cases {
		tool, ok := findTool(c.tool)
		if !ok {
			t.Fatalf("unknown tool %s", c.tool)
		}
		for _, role := range systemRoles {
			id := allScopesIdentity(f.orgID, f.users[role])
			codes, err := f.rt.callerPermissions(ctx, id)
			if err != nil {
				t.Fatalf("%s callerPermissions: %v", role, err)
			}
			got, err := f.rt.toolPermitted(ctx, id, codes, tool)
			if err != nil {
				t.Fatalf("%s/%s: %v", c.tool, role, err)
			}
			if want := slices.Contains(c.allowed, role); got != want {
				t.Errorf("%s as %s: allowed=%v, want %v", c.tool, role, got, want)
			}
			if !got {
				if _, err := f.rt.callTool(ctx, id, c.tool, map[string]any{}); !errors.Is(err, errMissingPermission) {
					t.Errorf("%s as %s: callTool err = %v, want errMissingPermission", c.tool, role, err)
				}
			}
		}
	}
}

// A project-workspace member without content.wiki passes the wiki gate, the
// same as requireWikiOrProjectAccess admits them over REST.
func TestToolGate_WikiProjectMember(t *testing.T) {
	f := newPermFixture(t)
	ctx := context.Background()
	uid := f.users["support_agent"]
	id := allScopesIdentity(f.orgID, uid)
	tool, _ := findTool("list_wiki_spaces")

	codes, err := f.rt.callerPermissions(ctx, id)
	if err != nil {
		t.Fatalf("callerPermissions: %v", err)
	}
	if ok, err := f.rt.toolPermitted(ctx, id, codes, tool); err != nil || ok {
		t.Fatalf("before project membership: ok=%v err=%v, want denied", ok, err)
	}
	var projectID string
	if err := f.pool.QueryRow(ctx, `INSERT INTO workspace_projects (org_id, title, requirement, team_size_min, team_size_max, key_prefix, project_status, share_token, created_by)
		VALUES ($1, 'MCP Wiki Project', repeat('r', 60), 2, 5, 'MCW', 'recruiting', 'mcp-wiki-token-aaaaaaaaaaaaaaaa', $2) RETURNING id`, f.orgID, uid).Scan(&projectID); err != nil {
		t.Fatalf("seed project: %v", err)
	}
	if _, err := f.pool.Exec(ctx, `INSERT INTO project_members (project_id, user_id, role, status) VALUES ($1, $2, 'member', 'active')`,
		projectID, uid); err != nil {
		t.Fatalf("seed project member: %v", err)
	}
	if ok, err := f.rt.toolPermitted(ctx, id, codes, tool); err != nil || !ok {
		t.Fatalf("project member: ok=%v err=%v, want allowed", ok, err)
	}
}

// A suspended member's still-valid token reaches no tool at all.
func TestToolGate_InactiveMemberDenied(t *testing.T) {
	f := newPermFixture(t)
	uid := seedPermUser(t, f.pool, f.orgID, "suspended", "suspended", "member")
	_, err := f.rt.callTool(context.Background(), allScopesIdentity(f.orgID, uid), "list_habits", map[string]any{})
	if !errors.Is(err, errNotOrgMember) {
		t.Fatalf("err = %v, want errNotOrgMember", err)
	}
}

// tools/list hides tools the caller's role cannot call and tools whose scope
// the connection lacks.
func TestToolsList_FiltersByPermissionAndScope(t *testing.T) {
	f := newPermFixture(t)
	list := func(id mcpIdentity) []string {
		body, _ := json.Marshal(rpcRequest{JSONRPC: jsonRPCVersion, ID: json.RawMessage(`1`), Method: "tools/list"})
		req := httptest.NewRequest(http.MethodPost, "/mcp", bytes.NewReader(body))
		req = req.WithContext(context.WithValue(req.Context(), connectionContextKey, id))
		rec := httptest.NewRecorder()
		f.rt.HandleMCP(rec, req)
		var resp struct {
			Result struct {
				Tools []struct {
					Name string `json:"name"`
				} `json:"tools"`
			} `json:"result"`
		}
		if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
			t.Fatalf("decode tools/list: %v (%s)", err, rec.Body.String())
		}
		names := make([]string, 0, len(resp.Result.Tools))
		for _, tl := range resp.Result.Tools {
			names = append(names, tl.Name)
		}
		return names
	}

	admin := list(allScopesIdentity(f.orgID, f.users["tenant_admin"]))
	if slices.Contains(admin, "list_journal_entries") || slices.Contains(admin, "log_mistake") {
		t.Errorf("tenant_admin sees journal/practice tools: %v", admin)
	}
	if !slices.Contains(admin, "list_wiki_spaces") || !slices.Contains(admin, "list_habits") {
		t.Errorf("tenant_admin missing wiki/habit tools: %v", admin)
	}
	member := list(allScopesIdentity(f.orgID, f.users["member"]))
	if !slices.Contains(member, "list_journal_entries") {
		t.Errorf("member missing journal tools: %v", member)
	}
	coursesOnly := list(mcpIdentity{OrgID: f.orgID, UserID: f.users["member"], Scopes: map[string]bool{ScopeCoursesRead: true}})
	for _, name := range coursesOnly {
		if tool, _ := findTool(name); tool.Scope != ScopeCoursesRead {
			t.Errorf("courses:read-only connection lists %s (scope %s)", name, tool.Scope)
		}
	}
	if len(coursesOnly) == 0 {
		t.Error("courses:read-only connection lists no tools")
	}
}
