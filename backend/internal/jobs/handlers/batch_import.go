package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/smtp"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/assessment"
	"github.com/mindforge/backend/internal/authz"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/jobs"
)

// BatchImportPayload is the JSON payload stored in jobs.payload for
// batch_import.students jobs. The rows themselves live in
// batch_member_details (status='pending') so the job stays small and re-runs
// safely if retried.
type BatchImportPayload struct {
	BatchID   string `json:"batch_id"`
	InvitedBy string `json:"invited_by"`
}

// BatchImportHandler implements jobs.Handler for HandlerBatchImport jobs.
type BatchImportHandler struct {
	pool *pgxpool.Pool
	cfg  *config.Config
	repo *assessment.Repo
}

func NewBatchImportHandler(pool *pgxpool.Pool, cfg *config.Config) *BatchImportHandler {
	return &BatchImportHandler{pool: pool, cfg: cfg, repo: assessment.NewRepo(pool)}
}

func (h *BatchImportHandler) Handle(ctx context.Context, job jobs.Job) error {
	var p BatchImportPayload
	if err := json.Unmarshal(job.Payload, &p); err != nil {
		return fmt.Errorf("handlers.batch_import: unmarshal payload: %w", err)
	}
	if p.BatchID == "" {
		return fmt.Errorf("handlers.batch_import: payload missing batch_id")
	}

	orgID, batchName, err := h.repo.GetBatchOrgAndName(ctx, p.BatchID)
	if err != nil {
		return fmt.Errorf("handlers.batch_import: resolve batch: %w", err)
	}

	pendingRows, err := h.repo.GetPendingImportRows(ctx, p.BatchID)
	if err != nil {
		return fmt.Errorf("handlers.batch_import: load pending rows: %w", err)
	}
	if len(pendingRows) == 0 {
		return nil
	}

	emails := make([]string, len(pendingRows))
	fullNames := make(map[string]string, len(pendingRows))
	for i, row := range pendingRows {
		emails[i] = row.Email
		fullNames[row.Email] = row.FullName
	}

	activeUserIDs, err := h.repo.ActiveMemberUserIDs(ctx, orgID, emails)
	if err != nil {
		return fmt.Errorf("handlers.batch_import: resolve active members: %w", err)
	}

	var existingEmails, existingUserIDs, inviteEmails []string
	for _, email := range emails {
		if userID, ok := activeUserIDs[email]; ok {
			existingEmails = append(existingEmails, email)
			existingUserIDs = append(existingUserIDs, userID)
		} else {
			inviteEmails = append(inviteEmails, email)
		}
	}

	if len(existingUserIDs) > 0 {
		h.processExistingMembers(ctx, orgID, p.BatchID, existingEmails, existingUserIDs)
	}
	if len(inviteEmails) > 0 {
		h.processInvitees(ctx, orgID, p.BatchID, p.InvitedBy, batchName, job.ID, inviteEmails, fullNames)
	}

	authz.NewAuditRepo(h.pool).Write(ctx, orgID, p.InvitedBy, "batch_import.completed", "batch", p.BatchID,
		&authz.AuditDiff{After: map[string]int{
			"enrolled_existing": len(existingUserIDs),
			"invited":           len(inviteEmails),
		}},
	) //nolint:errcheck // audit logging is best-effort

	return nil
}

// processExistingMembers adds already-active org members directly to the
// batch and enrolls them in its current courses. Failures are recorded on
// the affected rows rather than failing the whole job.
func (h *BatchImportHandler) processExistingMembers(ctx context.Context, orgID, batchID string, emails, userIDs []string) {
	if err := h.repo.AddBatchMembers(ctx, orgID, batchID, userIDs); err != nil {
		slog.ErrorContext(ctx, "handlers.batch_import: add existing members", "batch_id", batchID, "error", err)
		msg := err.Error()
		if markErr := h.repo.MarkImportRowStatus(ctx, batchID, emails, "failed", &msg); markErr != nil {
			slog.ErrorContext(ctx, "handlers.batch_import: mark failed existing rows", "batch_id", batchID, "error", markErr)
		}
		return
	}
	if err := h.repo.EnrollInBatchCourses(ctx, batchID, userIDs); err != nil {
		// Membership succeeded; enrollment is best-effort so don't mark the row failed for it.
		slog.WarnContext(ctx, "handlers.batch_import: enroll existing members", "batch_id", batchID, "error", err)
	}
	if err := h.repo.MarkImportRowStatus(ctx, batchID, emails, "enrolled_existing", nil); err != nil {
		slog.ErrorContext(ctx, "handlers.batch_import: mark enrolled rows", "batch_id", batchID, "error", err)
	}
}

// processInvitees creates/refreshes batch invitations for emails with no
// active org membership yet and emails the invite link. jobID tags the
// created rows so the invite history UI can group everyone invited by this
// job — a bulk Excel import or a single "invite new" — as one unit.
func (h *BatchImportHandler) processInvitees(ctx context.Context, orgID, batchID, invitedBy, batchName, jobID string, emails []string, fullNames map[string]string) {
	alreadyInvited, err := h.repo.ExistingInvitationEmails(ctx, batchID, emails)
	if err != nil {
		slog.ErrorContext(ctx, "handlers.batch_import: check existing invitations", "batch_id", batchID, "error", err)
		return
	}

	tokens, err := h.repo.CreateBatchInvitations(ctx, orgID, batchID, invitedBy, emails, &jobID)
	if err != nil {
		slog.ErrorContext(ctx, "handlers.batch_import: create invitations", "batch_id", batchID, "error", err)
		msg := err.Error()
		if markErr := h.repo.MarkImportRowStatus(ctx, batchID, emails, "failed", &msg); markErr != nil {
			slog.ErrorContext(ctx, "handlers.batch_import: mark failed invite rows", "batch_id", batchID, "error", markErr)
		}
		return
	}

	tokenByEmail := make(map[string]string, len(tokens))
	for _, t := range tokens {
		tokenByEmail[t.Email] = t.Token
	}

	var invitedEmails, resentEmails []string
	for _, email := range emails {
		token, ok := tokenByEmail[email]
		if !ok {
			continue
		}
		h.sendImportInviteEmail(email, fullNames[email], token, batchName)
		if alreadyInvited[email] {
			resentEmails = append(resentEmails, email)
		} else {
			invitedEmails = append(invitedEmails, email)
		}
	}

	if err := h.repo.MarkImportRowStatus(ctx, batchID, invitedEmails, "invited", nil); err != nil {
		slog.ErrorContext(ctx, "handlers.batch_import: mark invited rows", "batch_id", batchID, "error", err)
	}
	if err := h.repo.MarkImportRowStatus(ctx, batchID, resentEmails, "resent", nil); err != nil {
		slog.ErrorContext(ctx, "handlers.batch_import: mark resent rows", "batch_id", batchID, "error", err)
	}
}

// sendImportInviteEmail delivers the batch invite email for a bulk-imported
// student. Non-fatal: the invitation row exists regardless and can be
// resent manually from the batch invitations list.
func (h *BatchImportHandler) sendImportInviteEmail(to, name, token, batchName string) {
	if !h.cfg.IsProd() {
		slog.Info("DEV EMAIL: Batch import invite", "to", to, "batch", batchName, "token", token)
		return
	}

	greeting := "Hi there"
	if name != "" {
		greeting = "Hi " + strings.SplitN(name, " ", 2)[0]
	}
	link := h.cfg.FrontendURL + "/invitations/accept?token=" + token
	subject := fmt.Sprintf("You've been invited to join %s on MindForge", batchName)
	body := greeting + ",\n\n" +
		"You've been added to \"" + batchName + "\" on MindForge.\n\n" +
		"Click the link below to accept your invitation:\n\n" + link + "\n\n" +
		"This invitation expires in 7 days. If you did not expect this email, no action is needed."

	addr := h.cfg.SMTPHost + ":" + h.cfg.SMTPPort
	var smtpAuth smtp.Auth
	if h.cfg.SMTPUser != "" {
		smtpAuth = smtp.PlainAuth("", h.cfg.SMTPUser, h.cfg.SMTPPass, h.cfg.SMTPHost)
	}

	msg := buildInviteMessage(h.cfg.EmailFrom, to, subject, body)
	if err := smtp.SendMail(addr, smtpAuth, h.cfg.EmailFrom, []string{to}, []byte(msg)); err != nil {
		slog.Warn("handlers.batch_import: send invite email", "to", to, "batch", batchName, "error", err)
	}
}
