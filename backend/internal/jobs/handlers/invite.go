package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/mailer"
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

// NewInviteDeadHook returns a DeadLetterHook for HandlerBulkInvite. A dead
// chunk means the transient error path in Handle (org lookup, DB write) kept
// failing across every retry — the individual invite rows for this chunk may
// or may not exist depending on how far it got. It logs the failure and marks
// every invite of the chunk whose email never went out (email_status still
// 'pending') as 'failed', so the org admin sees "Failed — resend".
func NewInviteDeadHook(pool *pgxpool.Pool) jobs.DeadLetterHook {
	return func(ctx context.Context, job jobs.Job) {
		var p BulkInvitePayload
		if err := json.Unmarshal(job.Payload, &p); err != nil {
			slog.Error("invite.bulk dead hook: unmarshal payload", "job_id", job.ID, "error", err)
			return
		}
		lastErr := ""
		if job.LastError != nil {
			lastErr = *job.LastError
		}
		slog.Error("invite.bulk permanently failed — some invites in this chunk may not be created/emailed",
			"job_id", job.ID, "org_id", p.OrgID, "email_count", len(p.Emails), "last_error", lastErr)

		emails := make([]string, len(p.Emails))
		for i, e := range p.Emails {
			emails[i] = strings.ToLower(strings.TrimSpace(e))
		}
		reason := truncateErr("invite.bulk job failed: "+lastErr, maxEmailErrorLen)
		if _, err := pool.Exec(ctx,
			`UPDATE org_invites SET email_status = $4, email_error = $3, updated_at = now()
			 WHERE org_id = $1 AND email = ANY($2::citext[]) AND email_status = $5
			   AND accepted_at IS NULL AND revoked_at IS NULL`,
			p.OrgID, emails, reason, inviteEmailFailed, inviteEmailPending,
		); err != nil {
			slog.Error("invite.bulk dead hook: mark invites failed", "job_id", job.ID, "org_id", p.OrgID, "error", err)
		}
	}
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

// newSender returns the per-chunk send function and its cleanup. SMTP sends
// share one connection for the whole chunk (mailer.Session) instead of one
// dial/handshake/auth per invite; the Brevo API path is connectionless.
func (h *InviteHandler) newSender() (send func(context.Context, *orgs.Invite, string) error, closeFn func()) {
	var sess *mailer.Session
	if h.cfg.BrevoAPIKey == "" {
		sess = mailer.NewSession(h.cfg.SMTPHost, h.cfg.SMTPPort, h.cfg.SMTPUser, h.cfg.SMTPPass, h.cfg.EmailFrom)
	}
	send = func(ctx context.Context, inv *orgs.Invite, token string) error {
		return h.sendInviteEmail(ctx, sess, inv, token)
	}
	return send, func() {
		if sess != nil {
			sess.Close()
		}
	}
}

// pace sleeps for the configured inter-send delay, returning early on ctx cancel.
func (h *InviteHandler) pace(ctx context.Context) {
	if h.cfg.InviteSendDelay <= 0 {
		return
	}
	t := time.NewTimer(h.cfg.InviteSendDelay)
	defer t.Stop()
	select {
	case <-ctx.Done():
	case <-t.C:
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
	send, closeSend := h.newSender()
	defer closeSend()
	sentAny := false

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

		// Send the invite email. Non-fatal: the invite row exists and can be
		// resent manually; the outcome is recorded on the row so the admin can
		// see which invites need that.
		if sentAny {
			h.pace(ctx)
		}
		sentAny = true
		if emailErr := send(ctx, inv, token); emailErr != nil {
			slog.WarnContext(ctx, "handlers.invite: send invite email failed (invite created, needs resend)",
				"org_id", p.OrgID, "invite_id", inv.ID, "email", email, "error", emailErr)
			setInviteEmailStatus(ctx, h.pool, inv.ID, inviteEmailFailed, truncateErr(emailErr.Error(), maxEmailErrorLen))
			continue
		}
		setInviteEmailStatus(ctx, h.pool, inv.ID, inviteEmailSent, "")
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

// sendInviteEmail delivers the org invite email to the invitee, over sess when
// non-nil (SMTP) or the Brevo API otherwise.
// In development it logs to stdout instead of sending, unless inv.Email is
// in DEV_EMAIL_ALLOWLIST — mirrors every other email path's
// cfg.ShouldSendRealEmail gate (auth/email.go, EmailHandler.sendEvalComplete)
// so org-invite emails can be tested against a real inbox in dev the same way.
func (h *InviteHandler) sendInviteEmail(ctx context.Context, sess *mailer.Session, inv *orgs.Invite, token string) error {
	if !h.cfg.ShouldSendRealEmail(inv.Email) {
		// The token value is never logged: logs are routinely copied into
		// tickets and chat, and an invite token is a credential.
		slog.Info("DEV EMAIL: org invite suppressed (dev)",
			"to", inv.Email, "org_id", inv.OrgID, "role", inv.Role)
		return nil
	}

	subject, body := inviteEmailContent(h.cfg, inv.Role, token)

	// The Brevo API path is used when configured — needed on hosts that block
	// outbound SMTP ports (e.g. Render's free tier; see mailer.BrevoAPISender).
	var err error
	if sess == nil {
		err = mailer.SendViaBrevoAPI(ctx, h.cfg.BrevoAPIKey, h.cfg.EmailFrom, h.cfg.EmailFromName, inv.Email, subject, body)
	} else {
		err = sess.Send(ctx, inv.Email, []byte(buildInviteMessage(h.cfg.EmailFromHeader(), inv.Email, subject, body)))
	}
	if err != nil {
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
