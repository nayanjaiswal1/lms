package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/mailer"
	"github.com/mindforge/backend/internal/orgs"
)

// WorkspaceInviteEmailPayload is the workspace.project_invite_email job's
// payload (docs/project-workspace-plan/contract-phase1.md's Jobs section) —
// see workspace.Service's enqueueInviteEmail.
type WorkspaceInviteEmailPayload struct {
	OrgID        string `json:"org_id"`
	InviteID     string `json:"invite_id"`
	ProjectTitle string `json:"project_title"`
}

// WorkspaceInviteEmailHandler implements jobs.Handler for
// HandlerWorkspaceProjectInviteEmail jobs. It mints the invite's deliverable
// token right before sending (IssueProjectInviteToken) rather than the
// caller passing one in, so a plaintext credential never sits in a job
// payload — same treatment InviteHandler gives every other invite email.
type WorkspaceInviteEmailHandler struct {
	cfg     *config.Config
	invites *orgs.InviteService
}

// NewWorkspaceInviteEmailHandler constructs a WorkspaceInviteEmailHandler.
func NewWorkspaceInviteEmailHandler(pool *pgxpool.Pool, cfg *config.Config) *WorkspaceInviteEmailHandler {
	return &WorkspaceInviteEmailHandler{cfg: cfg, invites: orgs.NewInviteService(pool, cfg)}
}

// Handle sends one accepted-interest invite email.
func (h *WorkspaceInviteEmailHandler) Handle(ctx context.Context, job jobs.Job) error {
	var p WorkspaceInviteEmailPayload
	if err := json.Unmarshal(job.Payload, &p); err != nil {
		return fmt.Errorf("handlers.workspace_invite_email: decode payload: %w", err)
	}
	if p.OrgID == "" || p.InviteID == "" {
		return fmt.Errorf("handlers.workspace_invite_email: payload missing org_id or invite_id")
	}

	inv, token, err := h.invites.IssueProjectInviteToken(ctx, p.OrgID, p.InviteID)
	if err != nil {
		if errors.Is(err, orgs.ErrNotFound) {
			// Already accepted or revoked between the accept and this job
			// running — nothing left to email, and not worth retrying.
			slog.InfoContext(ctx, "handlers.workspace_invite_email: invite no longer pending, skipping", "invite_id", p.InviteID)
			return nil
		}
		return fmt.Errorf("handlers.workspace_invite_email: issue token: %w", err)
	}

	if !h.cfg.ShouldSendRealEmail(inv.Email) {
		// The token value is never logged: an invite token is a credential.
		slog.Info("DEV EMAIL: workspace invite suppressed (dev)", "to", inv.Email, "org_id", inv.OrgID, "project_title", p.ProjectTitle)
		return nil
	}

	subject := fmt.Sprintf("You're invited to join %q on MindForge", p.ProjectTitle)
	link := h.cfg.FrontendURL + "/orgs/join?token=" + token
	body := fmt.Sprintf(
		"Someone expressed interest in the project %q using this email address on MindForge.\n\n"+
			"If that was you, click the link below to join:\n\n%s\n\n"+
			"This invitation expires in 7 days. If you did not expect this email, no action is needed.",
		p.ProjectTitle, link,
	)

	// Same Brevo-API-first, SMTP-fallback path every other transactional
	// email in this codebase uses (internal/auth, jobs/handlers/invite.go).
	var sendErr error
	if h.cfg.BrevoAPIKey != "" {
		sendErr = mailer.SendViaBrevoAPI(ctx, h.cfg.BrevoAPIKey, h.cfg.EmailFrom, h.cfg.EmailFromName, inv.Email, subject, body)
	} else {
		msg := buildInviteMessage(h.cfg.EmailFromHeader(), inv.Email, subject, body)
		sendErr = mailer.SendRaw(ctx, h.cfg.SMTPHost, h.cfg.SMTPPort, h.cfg.SMTPUser, h.cfg.SMTPPass, h.cfg.EmailFrom, inv.Email, []byte(msg))
	}
	if sendErr != nil {
		return fmt.Errorf("handlers.workspace_invite_email: send to %s: %w", inv.Email, sendErr)
	}
	return nil
}
