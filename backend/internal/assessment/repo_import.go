package assessment

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// Row status values computed by ValidateAndStatusRows for the review/preview
// step. These describe what an import will DO with a row, distinct from
// batch_member_details.status which tracks what the background job DID.
const (
	RowStatusNew             = "new"
	RowStatusExistingActive  = "existing_active"
	RowStatusPendingInvite   = "pending_invite"
	RowStatusDuplicateInFile = "duplicate_in_file"
	RowStatusInvalid         = "invalid"
)

// MemberDetailRow is one parsed/validated row of an Excel roster upload.
type MemberDetailRow struct {
	FullName    string            `json:"full_name"`
	Email       string            `json:"email"`
	RollNumber  string            `json:"roll_number,omitempty"`
	PhoneNumber string            `json:"phone_number,omitempty"`
	Department  string            `json:"department,omitempty"`
	OtherFields map[string]string `json:"other_fields,omitempty"`
	Status      string            `json:"status"`
	Errors      []string          `json:"errors,omitempty"`
}

// ValidateAndStatusRows checks required fields/email format, flags duplicate
// emails within the file, and classifies every remaining row as new /
// existing_active / pending_invite against the org and batch. Used for both
// the initial parse-preview and re-checks after the admin edits rows.
func (r *Repo) ValidateAndStatusRows(ctx context.Context, orgID, batchID string, rows []MemberDetailRow) ([]MemberDetailRow, error) {
	seen := make(map[string]bool, len(rows))
	emails := make([]string, 0, len(rows))

	for i := range rows {
		row := &rows[i]
		row.Email = strings.ToLower(strings.TrimSpace(row.Email))
		row.FullName = strings.TrimSpace(row.FullName)
		row.Errors = nil

		if row.FullName == "" {
			row.Errors = append(row.Errors, "Full name is required.")
		}
		if row.Email == "" {
			row.Errors = append(row.Errors, "Email is required.")
		} else if !emailPattern.MatchString(row.Email) {
			row.Errors = append(row.Errors, "Email is not valid.")
		}

		if len(row.Errors) > 0 {
			row.Status = RowStatusInvalid
			continue
		}

		if seen[row.Email] {
			row.Status = RowStatusDuplicateInFile
			row.Errors = append(row.Errors, "Duplicate email in this file.")
			continue
		}
		seen[row.Email] = true
		emails = append(emails, row.Email)
	}

	if len(emails) == 0 {
		return rows, nil
	}

	activeUserIDs, err := r.ActiveMemberUserIDs(ctx, orgID, emails)
	if err != nil {
		return nil, err
	}
	pendingSet, err := r.pendingInvitationEmails(ctx, batchID, emails)
	if err != nil {
		return nil, err
	}

	for i := range rows {
		row := &rows[i]
		if row.Status == RowStatusInvalid || row.Status == RowStatusDuplicateInFile {
			continue
		}
		switch {
		case activeUserIDs[row.Email] != "":
			row.Status = RowStatusExistingActive
		case pendingSet[row.Email]:
			row.Status = RowStatusPendingInvite
		default:
			row.Status = RowStatusNew
		}
	}
	return rows, nil
}

// ActiveMemberUserIDs returns a map of email -> user_id for every email in
// emails that belongs to an active member of orgID.
func (r *Repo) ActiveMemberUserIDs(ctx context.Context, orgID string, emails []string) (map[string]string, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT u.email, u.id FROM org_members m JOIN users u ON u.id = m.user_id
		 WHERE m.org_id = $1 AND m.status = 'active' AND u.email = ANY($2::text[])`,
		orgID, emails)
	if err != nil {
		return nil, fmt.Errorf("assessment: check active members: %w", err)
	}
	defer rows.Close()
	out := map[string]string{}
	for rows.Next() {
		var email, userID string
		if err := rows.Scan(&email, &userID); err != nil {
			return nil, fmt.Errorf("assessment: scan active member: %w", err)
		}
		out[email] = userID
	}
	return out, rows.Err()
}

func (r *Repo) pendingInvitationEmails(ctx context.Context, batchID string, emails []string) (map[string]bool, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT email FROM batch_invitations
		 WHERE batch_id = $1 AND accepted_at IS NULL AND declined_at IS NULL AND expires_at > now()
		   AND email = ANY($2::text[])`,
		batchID, emails)
	if err != nil {
		return nil, fmt.Errorf("assessment: check pending invitations: %w", err)
	}
	defer rows.Close()
	out := map[string]bool{}
	for rows.Next() {
		var email string
		if err := rows.Scan(&email); err != nil {
			return nil, fmt.Errorf("assessment: scan pending invitation: %w", err)
		}
		out[email] = true
	}
	return out, rows.Err()
}

// ExistingInvitationEmails reports which of emails already have a
// batch_invitations row for batchID (used to label a re-upload as "resent"
// rather than "invited").
func (r *Repo) ExistingInvitationEmails(ctx context.Context, batchID string, emails []string) (map[string]bool, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT email FROM batch_invitations WHERE batch_id = $1 AND email = ANY($2::text[])`,
		batchID, emails)
	if err != nil {
		return nil, fmt.Errorf("assessment: check existing invitations: %w", err)
	}
	defer rows.Close()
	out := map[string]bool{}
	for rows.Next() {
		var email string
		if err := rows.Scan(&email); err != nil {
			return nil, fmt.Errorf("assessment: scan existing invitation: %w", err)
		}
		out[email] = true
	}
	return out, rows.Err()
}

// UpsertBatchMemberDetails persists the reviewed rows as pending import work.
// Rows still marked invalid or duplicate_in_file are skipped — the caller
// must have resolved those before confirming. A per-row roll-number conflict
// (partial unique index) surfaces as ErrConflict.
func (r *Repo) UpsertBatchMemberDetails(ctx context.Context, batchID string, rows []MemberDetailRow, lockedFields []string) error {
	if len(rows) == 0 {
		return nil
	}
	return r.tx(ctx, func(tx pgx.Tx) error {
		for _, row := range rows {
			if row.Status == RowStatusInvalid || row.Status == RowStatusDuplicateInFile {
				continue
			}
			other, err := json.Marshal(row.OtherFields)
			if err != nil {
				return fmt.Errorf("assessment: marshal other fields: %w", err)
			}
			if _, err := tx.Exec(ctx,
				`INSERT INTO batch_member_details
				    (batch_id, email, full_name, roll_number, phone_number, department, other_fields, locked_fields, status, error_message)
				 VALUES ($1, $2, $3, NULLIF($4, ''), NULLIF($5, ''), NULLIF($6, ''), $7, $8, 'pending', NULL)
				 ON CONFLICT (batch_id, email) DO UPDATE SET
				    full_name     = EXCLUDED.full_name,
				    roll_number   = EXCLUDED.roll_number,
				    phone_number  = EXCLUDED.phone_number,
				    department    = EXCLUDED.department,
				    other_fields  = EXCLUDED.other_fields,
				    locked_fields = EXCLUDED.locked_fields,
				    status        = 'pending',
				    error_message = NULL,
				    updated_at    = now()`,
				batchID, row.Email, row.FullName, row.RollNumber, row.PhoneNumber, row.Department, other, lockedFields,
			); err != nil {
				var pgErr *pgconn.PgError
				if errors.As(err, &pgErr) && pgErr.Code == "23505" {
					return fmt.Errorf("%w: roll number %q is already used in this batch", ErrConflict, row.RollNumber)
				}
				return fmt.Errorf("assessment: upsert batch member detail: %w", err)
			}
		}
		return nil
	})
}

// PendingImportRow is the minimal projection the background job needs to act
// on a row queued by UpsertBatchMemberDetails.
type PendingImportRow struct {
	Email    string
	FullName string
}

// GetPendingImportRows returns rows awaiting processing by the batch_import.students job.
func (r *Repo) GetPendingImportRows(ctx context.Context, batchID string) ([]PendingImportRow, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT email, full_name FROM batch_member_details WHERE batch_id = $1 AND status = 'pending'`,
		batchID)
	if err != nil {
		return nil, fmt.Errorf("assessment: get pending import rows: %w", err)
	}
	defer rows.Close()
	out := []PendingImportRow{}
	for rows.Next() {
		var row PendingImportRow
		if err := rows.Scan(&row.Email, &row.FullName); err != nil {
			return nil, fmt.Errorf("assessment: scan pending import row: %w", err)
		}
		out = append(out, row)
	}
	return out, rows.Err()
}

// MarkImportRowStatus updates the outcome status (and optional error) for a
// set of batch_member_details rows by email.
func (r *Repo) MarkImportRowStatus(ctx context.Context, batchID string, emails []string, status string, errMsg *string) error {
	if len(emails) == 0 {
		return nil
	}
	_, err := r.pool.Exec(ctx,
		`UPDATE batch_member_details SET status = $3, error_message = $4, updated_at = now()
		 WHERE batch_id = $1 AND email = ANY($2::text[])`,
		batchID, emails, status, errMsg)
	if err != nil {
		return fmt.Errorf("assessment: mark import row status: %w", err)
	}
	return nil
}

// EnrollInBatchCourses is the exported entry point the batch_import job uses
// to enroll a set of existing-member users into the batch's current courses.
func (r *Repo) EnrollInBatchCourses(ctx context.Context, batchID string, userIDs []string) error {
	return enrollInBatchCourses(ctx, r.pool, batchID, userIDs)
}

// GetBatchOrgAndName resolves the org and display name for a batch, used by
// the import job to scope queries and build the invitation email.
func (r *Repo) GetBatchOrgAndName(ctx context.Context, batchID string) (orgID, name string, err error) {
	err = r.pool.QueryRow(ctx, `SELECT org_id, name FROM batches WHERE id = $1`, batchID).Scan(&orgID, &name)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return "", "", ErrNotFound
		}
		return "", "", fmt.Errorf("assessment: get batch org and name: %w", err)
	}
	return orgID, name, nil
}

// ImportReport summarizes a batch's current roster import outcome for the
// completion screen — it reflects the whole batch, not a single run, since
// batch_member_details rows are upserted by (batch_id, email).
type ImportReport struct {
	Counts     map[string]int    `json:"counts"`
	FailedRows []FailedImportRow `json:"failed_rows"`
}

type FailedImportRow struct {
	Email        string `json:"email"`
	FullName     string `json:"full_name"`
	ErrorMessage string `json:"error_message"`
}

func (r *Repo) GetImportReport(ctx context.Context, orgID, batchID string) (ImportReport, error) {
	var exists bool
	if err := r.pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM batches WHERE id = $1 AND org_id = $2)`, batchID, orgID,
	).Scan(&exists); err != nil {
		return ImportReport{}, fmt.Errorf("assessment: verify batch: %w", err)
	}
	if !exists {
		return ImportReport{}, ErrNotFound
	}

	report := ImportReport{Counts: map[string]int{}, FailedRows: []FailedImportRow{}}

	statusRows, err := r.pool.Query(ctx,
		`SELECT status, count(*) FROM batch_member_details WHERE batch_id = $1 GROUP BY status`, batchID)
	if err != nil {
		return ImportReport{}, fmt.Errorf("assessment: count import status: %w", err)
	}
	for statusRows.Next() {
		var status string
		var count int
		if err := statusRows.Scan(&status, &count); err != nil {
			statusRows.Close()
			return ImportReport{}, fmt.Errorf("assessment: scan import status: %w", err)
		}
		report.Counts[status] = count
	}
	statusRows.Close()
	if err := statusRows.Err(); err != nil {
		return ImportReport{}, fmt.Errorf("assessment: iterate import status: %w", err)
	}

	failedRows, err := r.pool.Query(ctx,
		`SELECT email, full_name, COALESCE(error_message, '') FROM batch_member_details
		 WHERE batch_id = $1 AND status = 'failed' ORDER BY updated_at DESC`, batchID)
	if err != nil {
		return ImportReport{}, fmt.Errorf("assessment: list failed rows: %w", err)
	}
	defer failedRows.Close()
	for failedRows.Next() {
		var fr FailedImportRow
		if err := failedRows.Scan(&fr.Email, &fr.FullName, &fr.ErrorMessage); err != nil {
			return ImportReport{}, fmt.Errorf("assessment: scan failed row: %w", err)
		}
		report.FailedRows = append(report.FailedRows, fr)
	}
	return report, failedRows.Err()
}
