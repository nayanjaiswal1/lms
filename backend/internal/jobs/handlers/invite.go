package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/smtp"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/orgs"
)

// BulkInvitePayload is the JSON payload stored in jobs.payload for invite.bulk jobs.
// Emails is a pre-chunked slice (max 50 per job) so the worker retries a bounded set.
type BulkInvitePayload struct {
	OrgID     string   `json:"org_id"`
	InviterID string   `json:"inviter_id"`
	Emails    []string `json:"emails"` // this chunk's emails (max 50)
	Role      string   `json:"role"`
}

// InviteHandler implements jobs.Handler for HandlerBulkInvite jobs.
type InviteHandler struct {
	pool   *pgxpool.Pool
	cfg    *config.Config
	invSvc *orgs.InviteService
}

// NewInviteHandler constructs an InviteHandler with all dependencies injected.
func NewInviteHandler(pool *pgxpool.Pool, cfg *config.Config) *InviteHandler {
	return &InviteHandler{
		pool:   pool,
		cfg:    cfg,
		invSvc: orgs.NewInviteService(pool, cfg),
	}
}

// Handle processes a single invite.bulk job, issuing one org invite per email in the chunk.
// If any individual invite fails due to a transient error the whole job returns an error so
// the worker pool can retry the chunk. Conflicts (already_member, invite_pending) are logged
// and skipped so a single duplicate does not block the rest of the batch.
func (h *InviteHandler) Handle(ctx context.Context, job jobs.Job) error {
	var p BulkInvitePayload
	if err := json.Unmarshal(job.Payload, &p); err != nil {
		return fmt.Errorf("handlers.invite: unmarshal payload: %w", err)
	}
	if p.OrgID == "" {
		return fmt.Errorf("handlers.invite: payload missing org_id")
	}
	if p.InviterID == "" {
		return fmt.Errorf("handlers.invite: payload missing inviter_id")
	}
	if p.Role == "" {
		return fmt.Errorf("handlers.invite: payload missing role")
	}
	if len(p.Emails) == 0 {
		return fmt.Errorf("handlers.invite: payload emails list is empty")
	}

	// Resolve the inviter's org role — required by InviteService.Create for CanGrantRole checks.
	inviterRole, err := h.fetchMemberRole(ctx, p.OrgID, p.InviterID)
	if err != nil {
		return fmt.Errorf("handlers.invite: resolve inviter role (org=%s inviter=%s): %w",
			p.OrgID, p.InviterID, err)
	}

	var firstTransientErr error

	for _, email := range p.Emails {
		inv, token, createErr := h.invSvc.Create(ctx, p.OrgID, p.InviterID, inviterRole,
			orgs.CreateInviteRequest{Email: email, Role: p.Role})

		if createErr != nil {
			// Conflict errors are not retryable — skip and log.
			if errors.Is(createErr, orgs.ErrAlreadyMember) {
				slog.InfoContext(ctx, "handlers.invite: skipping already-member",
					"org_id", p.OrgID, "email", email)
				continue
			}
			if errors.Is(createErr, orgs.ErrInvitePending) {
				slog.InfoContext(ctx, "handlers.invite: skipping pending invite",
					"org_id", p.OrgID, "email", email)
				continue
			}
			if errors.Is(createErr, orgs.ErrForbidden) {
				// The inviter cannot grant the requested role — this is a configuration
				// error in the enqueuing caller; fail fast rather than retry.
				return fmt.Errorf("handlers.invite: forbidden: inviter %s cannot grant role %s in org %s",
					p.InviterID, p.Role, p.OrgID)
			}
			// Transient / unknown error — record and continue so remaining emails are attempted,
			// then return the error to trigger a retry of the whole chunk.
			slog.ErrorContext(ctx, "handlers.invite: create invite failed",
				"org_id", p.OrgID, "email", email, "error", createErr)
			if firstTransientErr == nil {
				firstTransientErr = createErr
			}
			continue
		}

		// Send the invite email. Non-fatal: the invite row exists and can be resent manually.
		if emailErr := h.sendInviteEmail(inv, token); emailErr != nil {
			slog.WarnContext(ctx, "handlers.invite: send invite email failed (invite created, will need resend)",
				"org_id", p.OrgID, "invite_id", inv.ID, "email", email, "error", emailErr)
		}
	}

	if firstTransientErr != nil {
		return fmt.Errorf("handlers.invite: one or more invites failed in org %s: %w", p.OrgID, firstTransientErr)
	}
	return nil
}

// fetchMemberRole returns the role of userID in orgID from org_members.
// Returns an error if the user is not an active member of the org.
func (h *InviteHandler) fetchMemberRole(ctx context.Context, orgID, userID string) (string, error) {
	var role string
	err := h.pool.QueryRow(ctx,
		`SELECT role FROM org_members WHERE org_id = $1 AND user_id = $2 AND status = 'active'`,
		orgID, userID,
	).Scan(&role)
	if err != nil {
		return "", fmt.Errorf("fetch member role: %w", err)
	}
	return role, nil
}

// sendInviteEmail delivers the org invite email to the invitee.
// In development it logs to stdout instead of using SMTP.
func (h *InviteHandler) sendInviteEmail(inv *orgs.Invite, token string) error {
	if !h.cfg.IsProd() {
		slog.Info("DEV EMAIL: Org invite",
			"to", inv.Email, "org_id", inv.OrgID,
			"role", inv.Role, "token", token)
		return nil
	}

	subject := "You've been invited to join an organization on MindForge"
	link := h.cfg.FrontendURL + "/orgs/join?token=" + token
	body := "You have been invited to join an organization on MindForge as " + inv.Role + ".\n\n" +
		"Click the link below to accept your invitation:\n\n" + link + "\n\n" +
		"This invitation expires in 7 days. If you did not expect this email, no action is needed."

	addr := h.cfg.SMTPHost + ":" + h.cfg.SMTPPort
	var smtpAuth smtp.Auth
	if h.cfg.SMTPUser != "" {
		smtpAuth = smtp.PlainAuth("", h.cfg.SMTPUser, h.cfg.SMTPPass, h.cfg.SMTPHost)
	}

	msg := buildInviteMessage(h.cfg.EmailFrom, inv.Email, subject, body)
	if err := smtp.SendMail(addr, smtpAuth, h.cfg.EmailFrom, []string{inv.Email}, []byte(msg)); err != nil {
		return fmt.Errorf("smtp send to %s: %w", inv.Email, err)
	}
	return nil
}

// buildInviteMessage constructs a minimal RFC 5322 plain-text message for an invite email.
func buildInviteMessage(from, to, subject, body string) string {
	var sb strings.Builder
	sb.WriteString("From: " + from + "\r\n")
	sb.WriteString("To: " + to + "\r\n")
	sb.WriteString("Subject: " + subject + "\r\n")
	sb.WriteString("MIME-Version: 1.0\r\n")
	sb.WriteString("Content-Type: text/plain; charset=UTF-8\r\n")
	sb.WriteString("\r\n")
	sb.WriteString(body)
	return sb.String()
}
