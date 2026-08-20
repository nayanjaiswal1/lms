package gitlab

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/notifications"
	"github.com/mindforge/backend/internal/secrets"
)

// Service is the gitlab domain's business logic layer. Batch 1 covered
// installation (org-level PAT/OAuth credential) and per-user connection
// (OAuth+PKCE) lifecycle; Batch 2 adds assignment/team/roster provisioning
// (service_provision.go, service_roster.go) — later batches add
// webhooks/checkpoints/dashboards/originality/handoff as their own
// service_<concern>.go files alongside these.
type Service struct {
	repo          *Repo
	cfg           *config.Config
	vault         *secrets.Vault
	pool          *pgxpool.Pool
	jobsRegistry  *jobs.Registry
	notifications *notifications.Service
	// aiProvider backs Batch 8's one-comment-per-MR reviewer
	// (service_ai_review.go) — the same ai.LLMProvider interface every other
	// AI-calling domain shares.
	aiProvider ai.LLMProvider
}

// NewService builds the gitlab Service. vault must be the same *secrets.Vault
// instance the rest of the app shares (derived once from cfg.EncryptionKey),
// so tokens encrypted by one request handler decrypt correctly in another.
// jobsRegistry is used by service_provision.go/service_roster.go to enqueue
// gitlab.provision_team/gitlab.sync_members jobs via the Job Management System.
// notifSvc is the generic notifications domain (internal/notifications) —
// Batch 5's peer-review/CI-alert flows (service_checkpoint.go,
// service_webhook.go) call it directly rather than gitlab owning its own
// notification table; nil-safety is not needed here since a notifications.Service
// holds no optional state itself (always constructed alongside gitlab.Service —
// see internal/api/router.go/cmd/server/main.go's wiring). aiProvider is
// Batch 8's AI MR reviewer dependency — see Service's own field doc comment.
func NewService(pool *pgxpool.Pool, cfg *config.Config, vault *secrets.Vault, jobsRegistry *jobs.Registry, notifSvc *notifications.Service, aiProvider ai.LLMProvider) *Service {
	return &Service{repo: NewRepo(pool), cfg: cfg, vault: vault, pool: pool, jobsRegistry: jobsRegistry, notifications: notifSvc, aiProvider: aiProvider}
}

// resolveInstallation looks up the installation a caller should use:
// installationID's row when non-nil (an assignment's explicit override, org-
// and id-scoped so a foreign-org ID can never resolve), else the org's
// current default. Returns ErrNotFound if the org has never connected any
// installation — callers treat that as "GitLab integration not configured
// for this org," not a logged error.
func (s *Service) resolveInstallation(ctx context.Context, orgID string, installationID *string) (*GitlabInstallation, error) {
	if installationID != nil {
		return s.repo.GetInstallationByID(ctx, orgID, *installationID)
	}
	return s.repo.GetDefaultInstallation(ctx, orgID)
}

// clientFor resolves an installation credential into a ready-to-use API
// client — the org's default when installationID is nil, or that specific
// pool entry when an assignment has pinned itself to one. Used by
// VerifyInstallation and every team/project provisioning call site.
func (s *Service) clientFor(ctx context.Context, orgID string, installationID *string) (*Client, error) {
	inst, err := s.resolveInstallation(ctx, orgID, installationID)
	if err != nil {
		return nil, err
	}
	token, err := s.vault.Decrypt(inst.AccessTokenEnc)
	if err != nil {
		return nil, fmt.Errorf("gitlab: decrypt installation token: %w", err)
	}
	return NewClient(inst.BaseURL, string(token)), nil
}

// clientForTeam resolves a team's assignment override (if any) and returns a
// ready-to-use client — the common shape across checkpoint/webhook/roster/
// handoff/poll code that only has a team in hand, not its assignment.
func (s *Service) clientForTeam(ctx context.Context, orgID, assignmentID string) (*Client, error) {
	assignment, err := s.repo.GetAssignmentByID(ctx, assignmentID)
	if err != nil {
		return nil, fmt.Errorf("gitlab: resolve team's assignment: %w", err)
	}
	return s.clientFor(ctx, orgID, assignment.InstallationID)
}

// userClientFor resolves a specific member's own GitLab connection into a
// ready-to-use API client. Always against the org's default installation —
// personal "connect your own account" is scoped to one host per org by
// design (a member's OAuth token is host-specific; letting it vary per
// assignment would mean re-consenting per project, which nothing here asks
// for). Later batches (lab commit attribution, capstone handoff) call it to
// act as the real person rather than the installation's service account.
func (s *Service) userClientFor(ctx context.Context, orgID, userID string) (*Client, error) {
	inst, err := s.repo.GetDefaultInstallation(ctx, orgID)
	if err != nil {
		return nil, err
	}
	conn, err := s.repo.GetConnection(ctx, orgID, userID)
	if err != nil {
		return nil, err
	}
	token, err := s.vault.Decrypt(conn.AccessTokenEnc)
	if err != nil {
		return nil, fmt.Errorf("gitlab: decrypt connection token: %w", err)
	}
	return NewClient(inst.BaseURL, string(token)), nil
}

// GetStatus returns the combined installation-pool + personal-connection
// picture the settings page needs — never includes token material.
func (s *Service) GetStatus(ctx context.Context, orgID, userID string) (*StatusView, error) {
	view := StatusView{Installations: []InstallationStatusView{}}

	installations, err := s.repo.ListInstallations(ctx, orgID)
	if err != nil {
		return nil, fmt.Errorf("gitlab: get status: list installations: %w", err)
	}
	for _, inst := range installations {
		view.Installations = append(view.Installations, toInstallationView(&inst))
	}

	conn, err := s.repo.GetConnection(ctx, orgID, userID)
	switch {
	case err == nil:
		view.Connection = ConnectionStatusView{
			Connected:      true,
			GitlabUsername: conn.GitlabUsername,
			Status:         conn.Status,
			Scopes:         conn.Scopes,
			LastUsedAt:     conn.LastUsedAt,
			CreatedAt:      &conn.CreatedAt,
		}
	case errors.Is(err, ErrNotFound):
		// no personal connection yet
	default:
		return nil, fmt.Errorf("gitlab: get status: get connection: %w", err)
	}

	return &view, nil
}

// ListInstallations returns every installation in the org's pool for the
// admin settings page.
func (s *Service) ListInstallations(ctx context.Context, orgID string) ([]GitlabInstallation, error) {
	return s.repo.ListInstallations(ctx, orgID)
}

// SetDefaultInstallation moves the org's default flag onto id.
func (s *Service) SetDefaultInstallation(ctx context.Context, orgID, id string) (*GitlabInstallation, error) {
	if err := s.repo.SetDefaultInstallation(ctx, orgID, id); err != nil {
		return nil, err
	}
	return s.repo.GetInstallationByID(ctx, orgID, id)
}

// GetOrgConfig returns the org's GitLab policy, defaulting
// AllowProjectOverride to true when the org has never set one explicitly —
// same absence-means-default convention as GetDefaultInstallation.
func (s *Service) GetOrgConfig(ctx context.Context, orgID string) (*GitlabOrgConfig, error) {
	cfg, err := s.repo.GetOrgConfig(ctx, orgID)
	if errors.Is(err, ErrNotFound) {
		return &GitlabOrgConfig{OrgID: orgID, AllowProjectOverride: true}, nil
	}
	if err != nil {
		return nil, err
	}
	return cfg, nil
}

// SetOrgConfig sets the org's allow_project_override policy.
func (s *Service) SetOrgConfig(ctx context.Context, orgID string, allowOverride bool) (*GitlabOrgConfig, error) {
	return s.repo.UpsertOrgConfig(ctx, orgID, allowOverride)
}

// VerifyInstallation re-checks a stored installation token against GET /user
// and records the result.
func (s *Service) VerifyInstallation(ctx context.Context, orgID, id string) (*GitlabInstallation, error) {
	inst, err := s.repo.GetInstallationByID(ctx, orgID, id)
	if err != nil {
		return nil, err
	}
	token, err := s.vault.Decrypt(inst.AccessTokenEnc)
	if err != nil {
		return nil, fmt.Errorf("gitlab: decrypt installation token: %w", err)
	}
	client := NewClient(inst.BaseURL, string(token))
	_, verifyErr := client.VerifyUser(ctx)
	var lastError *string
	if verifyErr != nil {
		msg := verifyErr.Error()
		lastError = &msg
	}
	if err := s.repo.UpdateInstallationVerification(ctx, id, verifyErr == nil, lastError); err != nil {
		return nil, err
	}
	return s.repo.GetInstallationByID(ctx, orgID, id)
}

// DeleteInstallation removes one installation from the org's pool. See
// Repo.DeleteInstallationByID's own doc comment for the default/in-use guards.
func (s *Service) DeleteInstallation(ctx context.Context, orgID, id string) error {
	return s.repo.DeleteInstallationByID(ctx, orgID, id)
}

// Disconnect removes a member's own GitLab connection. Best-effort revokes
// the token on GitLab's side first — a revoke failure (e.g. the instance is
// briefly unreachable) does not block the local disconnect, since the point
// of disconnecting is that MindForge stops being able to use the token
// either way; on failure it simply lingers until its own natural expiry.
func (s *Service) Disconnect(ctx context.Context, orgID, userID string) error {
	conn, err := s.repo.GetConnection(ctx, orgID, userID)
	if err != nil {
		return err
	}
	if inst, instErr := s.repo.GetDefaultInstallation(ctx, orgID); instErr == nil && inst.OAuthClientID != nil {
		if token, decErr := s.vault.Decrypt(conn.AccessTokenEnc); decErr == nil {
			var secret string
			if inst.OAuthClientSecretEnc != nil {
				if dec, derr := s.vault.Decrypt(inst.OAuthClientSecretEnc); derr == nil {
					secret = string(dec)
				}
			}
			httpClient := &http.Client{Timeout: 10 * time.Second}
			if revokeErr := RevokeToken(ctx, httpClient, inst.BaseURL, *inst.OAuthClientID, secret, string(token)); revokeErr != nil {
				slog.WarnContext(ctx, "gitlab: revoke token on disconnect failed (continuing with local disconnect)",
					"org_id", orgID, "user_id", userID, "error", revokeErr)
			}
		}
	}
	return s.repo.DeleteConnection(ctx, orgID, userID)
}
