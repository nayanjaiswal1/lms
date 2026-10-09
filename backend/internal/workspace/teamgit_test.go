package workspace

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/mindforge/backend/internal/gitlab"
)

func TestMapGitlabErr(t *testing.T) {
	if !errors.Is(mapGitlabErr(gitlab.ErrNotFound), ErrNotFound) {
		t.Fatal("gitlab.ErrNotFound must map to workspace ErrNotFound (404)")
	}
	if !errors.Is(mapGitlabErr(gitlab.ErrConflict), ErrConflict) {
		t.Fatal("gitlab.ErrConflict must map to workspace ErrConflict (409)")
	}
	if mapGitlabErr(nil) != nil {
		t.Fatal("nil must stay nil")
	}
}

// Unauthenticated callers never reach a team-git handler.
func TestTeamGitRolesRejectAnonymous(t *testing.T) {
	for _, role := range []string{RoleViewer, RoleMember, RoleOwner} {
		h := RequireProjectRole(nil, nil, role)(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
			t.Fatal("handler reached without auth")
		}))
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/api/workspaces/x/checkpoints", nil))
		if rec.Code != http.StatusUnauthorized {
			t.Fatalf("%s: got %d want 401", role, rec.Code)
		}
	}
}

// ProposalAction must stop at a missing team before touching any proposal.
func TestProposalActionRequiresTeam(t *testing.T) {
	s := &Service{}
	err := s.ProposalAction(context.Background(), &ProjectCtx{}, "p1", func(*gitlab.Service, string, string) error {
		t.Fatal("fn must not run")
		return nil
	})
	if !errors.Is(err, ErrInvalidState) {
		t.Fatalf("got %v want ErrInvalidState", err)
	}
}
