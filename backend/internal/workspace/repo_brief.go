package workspace

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
)

// repo_brief.go — brief_approvals data layer (D13's two-person brief sign-off).

// UpsertBriefApproval records/updates the caller's approval of the brief page
// at its current wiki version, for the current requirement version.
// approverRole is one of 'owner','manager','track_lead' — the role the
// approver held at the moment they approved, so a later demotion can't be
// backdated into "never approved."
func (r *Repo) UpsertBriefApproval(ctx context.Context, tx pgx.Tx, projectID string, requirementVersion int, approverID, approverRole string, wikiVersion int) error {
	if _, err := tx.Exec(ctx,
		`INSERT INTO brief_approvals (project_id, requirement_version, approver_id, approver_role, wiki_version)
		 VALUES ($1,$2,$3,$4,$5)
		 ON CONFLICT (project_id, requirement_version, approver_id)
		   DO UPDATE SET approver_role = EXCLUDED.approver_role, wiki_version = EXCLUDED.wiki_version, created_at = now()`,
		projectID, requirementVersion, approverID, approverRole, wikiVersion,
	); err != nil {
		return fmt.Errorf("workspace: upsert brief approval: %w", err)
	}
	return nil
}

// ListBriefApprovals lists every approval on the current requirement version,
// newest first, with the approver's current name.
func (r *Repo) ListBriefApprovals(ctx context.Context, db DBTX, projectID string, requirementVersion int) ([]BriefApproval, error) {
	rows, err := db.Query(ctx,
		`SELECT a.approver_id, COALESCE(u.name, 'Former member'), a.approver_role, a.wiki_version, a.created_at
		   FROM brief_approvals a LEFT JOIN users u ON u.id = a.approver_id
		  WHERE a.project_id = $1 AND a.requirement_version = $2
		  ORDER BY a.created_at DESC`,
		projectID, requirementVersion)
	if err != nil {
		return nil, fmt.Errorf("workspace: list brief approvals: %w", err)
	}
	defer rows.Close()
	out := []BriefApproval{}
	for rows.Next() {
		var a BriefApproval
		if err := rows.Scan(&a.ApproverID, &a.ApproverName, &a.ApproverRole, &a.WikiVersion, &a.CreatedAt); err != nil {
			return nil, fmt.Errorf("workspace: scan brief approval: %w", err)
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// IsBriefAgreed reports whether, among approvals on requirementVersion at
// exactly wikiVersion, there is one by the project owner and one by a
// different user holding manager or track_lead (D13's "agreed" rule).
func IsBriefAgreed(approvals []BriefApproval, wikiVersion int) bool {
	var ownerID string
	hasOwner := false
	hasOtherManagerOrLead := false
	for _, a := range approvals {
		if a.WikiVersion != wikiVersion {
			continue
		}
		if a.ApproverRole == RoleOwner {
			hasOwner = true
			ownerID = a.ApproverID
		}
	}
	for _, a := range approvals {
		if a.WikiVersion != wikiVersion {
			continue
		}
		if (a.ApproverRole == RoleManager || a.ApproverRole == "track_lead") && a.ApproverID != ownerID {
			hasOtherManagerOrLead = true
		}
	}
	return hasOwner && hasOtherManagerOrLead
}

// SetBriefWikiPageID stores the brief page pointer (CreateBriefPage, once).
func (r *Repo) SetBriefWikiPageID(ctx context.Context, tx pgx.Tx, projectID, pageID string) error {
	if _, err := tx.Exec(ctx,
		`UPDATE workspace_projects SET brief_wiki_page_id = $2, updated_at = now() WHERE id = $1`,
		projectID, pageID,
	); err != nil {
		return fmt.Errorf("workspace: set brief wiki page: %w", err)
	}
	return nil
}

// SetBriefStatus moves brief_status directly (ApproveBrief's own write, under
// the project row lock already held by the caller) and stamps
// brief_agreed_at the first time it becomes agreed.
func (r *Repo) SetBriefStatus(ctx context.Context, tx pgx.Tx, projectID, status string) (*Project, error) {
	row := tx.QueryRow(ctx,
		`UPDATE workspace_projects SET
			brief_status = $2,
			brief_agreed_at = CASE WHEN $2 = 'agreed' THEN COALESCE(brief_agreed_at, now()) ELSE brief_agreed_at END,
			updated_at = now()
		 WHERE id = $1
		 RETURNING `+projectColumns,
		projectID, status,
	)
	return scanProject(row)
}
