package workspace

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
	"regexp"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/db"
	"github.com/mindforge/backend/internal/pagination"
	"github.com/mindforge/backend/internal/wiki"
)

// CompletionFeedbackWindow is how long after completion peer feedback stays
// open (00-decisions D11, 02 §7.1).
const CompletionFeedbackWindow = 14 * 24 * time.Hour

// keyPrefixPattern mirrors workspace_projects.key_prefix's own CHECK.
var keyPrefixPattern = regexp.MustCompile(`^[A-Z]{2,6}$`)

// deriveKeyPrefix builds a default key prefix from a title's word-initials,
// upper-cased and padded to keyPrefixPattern's 2-char floor with X.
func deriveKeyPrefix(title string) string {
	var b strings.Builder
	for _, w := range strings.Fields(title) {
		up := strings.ToUpper(w)
		for _, r := range up {
			if r < 'A' || r > 'Z' {
				continue
			}
			b.WriteRune(r)
			break
		}
		if b.Len() >= 6 {
			break
		}
	}
	out := b.String()
	for len(out) < 2 {
		out += "X"
	}
	return out
}

// generateShareToken mints a 256-bit crypto/rand token, base64url-encoded
// (02 §4.2).
func generateShareToken() (string, error) {
	buf := make([]byte, ShareTokenBytes)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("workspace: generate share token: %w", err)
	}
	return base64.RawURLEncoding.EncodeToString(buf), nil
}

// normalizeSkills trims/drops empties and enforces the length caps, returning
// a field-error message on violation.
func normalizeSkills(in []string) ([]string, string) {
	if len(in) > MaxSkills {
		return nil, fmt.Sprintf("List at most %d skills.", MaxSkills)
	}
	out := make([]string, 0, len(in))
	for _, s := range in {
		s = strings.TrimSpace(s)
		if s == "" {
			continue
		}
		if len(s) > MaxSkillLen {
			return nil, fmt.Sprintf("Each skill must be %d characters or fewer.", MaxSkillLen)
		}
		out = append(out, s)
	}
	return out, ""
}

// clampLimit applies the shared page-size defaults/ceiling to a list request.
func clampLimit(limit int) int {
	if limit <= 0 {
		return PageSizeDefault
	}
	if limit > PageSizeMax {
		return PageSizeMax
	}
	return limit
}

// writeAudit is the workspace package's one audit_logs writer — project
// lifecycle/security events (agent-hard-rules.md), mirroring orgs.writeAuditLog's
// shape without pulling in that package for one INSERT. Best-effort: an audit
// failure never fails the mutation that triggered it.
func writeAudit(ctx context.Context, db DBTX, orgID string, actorUserID *string, action, targetType, targetID string, after any) {
	var afterJSON []byte
	if after != nil {
		afterJSON, _ = json.Marshal(after)
	}
	if _, err := db.Exec(ctx,
		`INSERT INTO audit_logs (org_id, actor_user_id, action, target_type, target_id, after_state)
		 VALUES ($1,$2,$3,$4,$5,$6)`,
		orgID, actorUserID, action, targetType, targetID, afterJSON,
	); err != nil {
		slog.ErrorContext(ctx, "workspace: write audit log", "action", action, "error", err)
	}
}

// validateTeamSize checks the shared min/max rule (00-decisions: create and
// update both enforce "2 <= min <= max <= 50").
func validateTeamSize(fields map[string]string, min, max int) {
	if min < TeamSizeFloor {
		fields["team_size_min"] = fmt.Sprintf("Team size must be at least %d.", TeamSizeFloor)
	}
	if max < min || max > TeamSizeCeiling {
		fields["team_size_max"] = fmt.Sprintf("Max team size must be between team_size_min and %d.", TeamSizeCeiling)
	}
}

// CreateProject validates req, then provisions the project row, its owner
// membership, requirement v1, and its project-scoped wiki space in one
// transaction.
func (s *Service) CreateProject(ctx context.Context, orgID, userID string, req CreateProjectRequest) (*Project, error) {
	fields := map[string]string{}
	title := strings.TrimSpace(req.Title)
	if len(title) < TitleMinLen || len(title) > TitleMaxLen {
		fields["title"] = fmt.Sprintf("Title must be %d-%d characters.", TitleMinLen, TitleMaxLen)
	}
	requirement := strings.TrimSpace(req.Requirement)
	if len(requirement) < RequirementMinLen || len(requirement) > RequirementMaxLen {
		fields["requirement"] = fmt.Sprintf("Requirement must be %d-%d characters.", RequirementMinLen, RequirementMaxLen)
	}
	validateTeamSize(fields, req.TeamSizeMin, req.TeamSizeMax)
	skills, skillsErr := normalizeSkills(req.Skills)
	if skillsErr != "" {
		fields["skills"] = skillsErr
	}
	keyPrefix := strings.ToUpper(strings.TrimSpace(req.KeyPrefix))
	if keyPrefix == "" {
		keyPrefix = deriveKeyPrefix(title)
	}
	if !keyPrefixPattern.MatchString(keyPrefix) {
		fields["key_prefix"] = "Key prefix must be 2-6 uppercase letters."
	}
	if len(fields) > 0 {
		return nil, &FieldError{Fields: fields}
	}

	if allowed, retryAfter := s.limiter.Allow(ctx, "rl:pw:create:"+userID, s.cfg.Workspace.CreatePerUserDay, 24*time.Hour); !allowed {
		return nil, &RateLimitError{RetryAfter: retryAfter}
	}

	token, err := generateShareToken()
	if err != nil {
		return nil, err
	}
	gitlabEnabled, sprintsEnabled := true, false
	if req.GitlabEnabled != nil {
		gitlabEnabled = *req.GitlabEnabled
	}
	if req.SprintsEnabled != nil {
		sprintsEnabled = *req.SprintsEnabled
	}
	// The key prefix is already unique per org, so appending it keeps the
	// wiki space's slug unique too — wiki_spaces.slug has no DB constraint of
	// its own, so a genuine collision would otherwise make GetSpaceBySlug's
	// single-row lookup non-deterministic.
	slug := courses.Slugify(title) + "-" + strings.ToLower(keyPrefix)

	var project *Project
	err = s.repo.InTx(ctx, func(tx pgx.Tx) error {
		createdBy := userID
		p, err := s.insertProjectTx(ctx, tx, userID, Project{
			OrgID: orgID, Title: title, Requirement: requirement, Skills: skills,
			TeamSizeMin: req.TeamSizeMin, TeamSizeMax: req.TeamSizeMax, InterestDeadline: req.InterestDeadline,
			KeyPrefix: keyPrefix, ShareToken: token, GitlabEnabled: gitlabEnabled, SprintsEnabled: sprintsEnabled,
			CreatedBy: &createdBy,
		}, slug)
		if err != nil {
			return err
		}
		project = p
		return nil
	})
	if err != nil {
		return nil, err
	}
	return project, nil
}

// insertProjectTx writes the project row, its owner membership, requirement
// v1 and wiki space inside tx — shared by CreateProject and CreateCohortWorkspace.
func (s *Service) insertProjectTx(ctx context.Context, tx pgx.Tx, userID string, in Project, wikiSlug string) (*Project, error) {
	taken, err := s.repo.KeyPrefixTaken(ctx, tx, in.OrgID, in.KeyPrefix, "")
	if err != nil {
		return nil, err
	}
	if taken {
		return nil, ErrKeyPrefixTaken
	}
	p, err := s.repo.InsertProject(ctx, tx, in)
	if err != nil {
		if db.IsUniqueViolation(err) {
			return nil, ErrKeyPrefixTaken
		}
		return nil, fmt.Errorf("workspace: create project: insert: %w", err)
	}
	if err := s.repo.UpsertMember(ctx, tx, p.ID, userID, RoleOwner, MemberActive, &userID); err != nil {
		return nil, fmt.Errorf("workspace: create project: owner member: %w", err)
	}
	if err := s.repo.InsertRequirementVersion(ctx, tx, p.ID, 1, in.Requirement, userID); err != nil {
		return nil, err
	}
	if _, err := wiki.CreateProjectSpaceTx(ctx, tx, in.OrgID, p.ID, in.Title, wikiSlug, userID); err != nil {
		return nil, fmt.Errorf("workspace: create project: wiki space: %w", err)
	}
	writeAudit(ctx, tx, in.OrgID, &userID, "project.created", "workspace_project", p.ID,
		map[string]string{"title": in.Title, "key_prefix": in.KeyPrefix})
	return p, nil
}

// ListProjects returns every project the caller is an active member of, or
// (with projects.oversee) every project in the org.
func (s *Service) ListProjects(ctx context.Context, orgID, userID, cohortID, cursor string, limit int) (Page[ProjectSummary], error) {
	limit = clampLimit(limit)
	cursorAt, cursorID, err := pagination.DecodeCursor(cursor, "workspace")
	if err != nil {
		cursorAt, cursorID = time.Time{}, ""
	}
	overseer, err := s.perms.HasPermission(ctx, userID, orgID, PermProjectsOversee)
	if err != nil {
		return Page[ProjectSummary]{}, fmt.Errorf("workspace: list projects: check overseer: %w", err)
	}
	items, err := s.repo.ListProjects(ctx, orgID, userID, overseer, cohortID, cursorAt, cursorID, limit+1)
	if err != nil {
		return Page[ProjectSummary]{}, err
	}
	page := Page[ProjectSummary]{Items: items}
	if len(items) > limit {
		page.Items = items[:limit]
		last := page.Items[limit-1]
		page.NextCursor = pagination.EncodeCursor(last.CreatedAt, last.ID)
	}
	return page, nil
}

// GetProject assembles the detail view: the row plus the caller's live role,
// track memberships, seat count and wiki space pointer.
func (s *Service) GetProject(ctx context.Context, pc *ProjectCtx) (*ProjectDetail, error) {
	p, err := s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	seats, err := s.SeatsUsed(ctx, s.pool, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	myTracks, err := s.repo.ListMyTrackIDs(ctx, s.pool, pc.ProjectID, pc.UserID)
	if err != nil {
		return nil, err
	}
	ledTracks, err := s.repo.ListLedTrackIDs(ctx, s.pool, pc.ProjectID, pc.UserID)
	if err != nil {
		return nil, err
	}
	onboardingDone, err := s.repo.IsOnboardingComplete(ctx, s.pool, pc.ProjectID, pc.UserID)
	if err != nil {
		return nil, err
	}
	wikiID, wikiSlug, err := s.repo.GetProjectWikiSpace(ctx, s.pool, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	gl, err := s.repo.GetProjectGitlab(ctx, s.pool, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	return &ProjectDetail{
		GitlabWebURL: gl.WebURL, GitlabPagesURL: gl.PagesURL, ProvisionStatus: gl.ProvisionStatus, ProvisionError: gl.ProvisionError,
		Project: *p, MyRole: pc.Role, IsOverseer: pc.Overseer, MyTrackIDs: myTracks, LedTrackIDs: ledTracks,
		SeatsUsed: seats, WikiSpaceID: wikiID, WikiSpaceSlug: wikiSlug, OnboardingDone: onboardingDone,
	}, nil
}

// UpdateProject applies a partial settings patch (owner only, requirement
// text goes through UpdateRequirement instead).
func (s *Service) UpdateProject(ctx context.Context, pc *ProjectCtx, req UpdateProjectRequest) (*Project, error) {
	current, err := s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
	if err != nil {
		return nil, err
	}

	patch := projectPatch{
		Title: current.Title, Skills: current.Skills, TeamSizeMin: current.TeamSizeMin, TeamSizeMax: current.TeamSizeMax,
		InterestDeadline: current.InterestDeadline, KeyPrefix: current.KeyPrefix, AcceptingInterests: current.AcceptingInterests,
		GitlabEnabled: current.GitlabEnabled, SprintsEnabled: current.SprintsEnabled, WipLimit: current.WipLimit,
		HealthThresholds: current.HealthThresholds,
	}
	fields := map[string]string{}

	if req.Title != nil {
		t := strings.TrimSpace(*req.Title)
		if len(t) < TitleMinLen || len(t) > TitleMaxLen {
			fields["title"] = fmt.Sprintf("Title must be %d-%d characters.", TitleMinLen, TitleMaxLen)
		}
		patch.Title = t
	}
	if req.Skills != nil {
		skills, skillsErr := normalizeSkills(*req.Skills)
		if skillsErr != "" {
			fields["skills"] = skillsErr
		}
		patch.Skills = skills
	}
	if req.TeamSizeMin != nil {
		patch.TeamSizeMin = *req.TeamSizeMin
	}
	if req.TeamSizeMax != nil {
		patch.TeamSizeMax = *req.TeamSizeMax
	}
	validateTeamSize(fields, patch.TeamSizeMin, patch.TeamSizeMax)
	if req.ClearDeadline {
		patch.InterestDeadline = nil
	} else if req.InterestDeadline != nil {
		patch.InterestDeadline = req.InterestDeadline
	}
	if req.AcceptingInterests != nil {
		patch.AcceptingInterests = *req.AcceptingInterests
	}
	if req.GitlabEnabled != nil {
		patch.GitlabEnabled = *req.GitlabEnabled
	}
	if req.SprintsEnabled != nil {
		patch.SprintsEnabled = *req.SprintsEnabled
	}
	if req.WipLimit != nil {
		patch.WipLimit = *req.WipLimit
		if patch.WipLimit < 1 || patch.WipLimit > 50 {
			fields["wip_limit"] = "WIP limit must be between 1 and 50."
		}
	}
	if req.HealthThresholds != nil {
		patch.HealthThresholds = *req.HealthThresholds
	}

	if req.KeyPrefix != nil {
		kp := strings.ToUpper(strings.TrimSpace(*req.KeyPrefix))
		if kp != current.KeyPrefix {
			if current.ItemSeq > 0 {
				return nil, ErrKeyPrefixLocked
			}
			if !keyPrefixPattern.MatchString(kp) {
				fields["key_prefix"] = "Key prefix must be 2-6 uppercase letters."
			} else {
				taken, err := s.repo.KeyPrefixTaken(ctx, s.pool, pc.OrgID, kp, pc.ProjectID)
				if err != nil {
					return nil, err
				}
				if taken {
					return nil, ErrKeyPrefixTaken
				}
			}
			patch.KeyPrefix = kp
		}
	}

	if len(fields) > 0 {
		return nil, &FieldError{Fields: fields}
	}

	seats, err := s.SeatsUsed(ctx, s.pool, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	if patch.TeamSizeMax < seats {
		return nil, &FieldError{Fields: map[string]string{"team_size_max": "Max team size can't be below the number of seats already used."}}
	}

	updated, err := s.repo.UpdateProject(ctx, s.pool, pc.ProjectID, patch)
	if err != nil {
		if db.IsUniqueViolation(err) {
			return nil, ErrKeyPrefixTaken
		}
		return nil, err
	}
	return updated, nil
}

// SetProjectStatus is the single entry point for every project lifecycle
// transition (00-decisions, contract-phase1.md).
func (s *Service) SetProjectStatus(ctx context.Context, pc *ProjectCtx, to string) (*Project, error) {
	var updated *Project
	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		p, err := s.repo.LockProject(ctx, tx, pc.ProjectID)
		if err != nil {
			return err
		}
		from := p.ProjectStatus
		if !ProjectStatusMachine.Allowed(from, to) {
			return fmt.Errorf("%w: cannot move from %s to %s", ErrInvalidState, from, to)
		}

		setBriefClarifying, setActivatedAt := false, false
		switch {
		case from == ProjectDraft && to == ProjectRecruiting:
			if len(strings.TrimSpace(p.Requirement)) < RequirementMinLen {
				return fmt.Errorf("%w: requirement must be at least %d characters before recruiting", ErrPreconditionFail, RequirementMinLen)
			}
		case from == ProjectRecruiting && to == ProjectActive:
			active, err := s.repo.CountActiveManagersAndMembers(ctx, tx, pc.ProjectID)
			if err != nil {
				return err
			}
			if active < p.TeamSizeMin {
				return fmt.Errorf("%w: need at least %d active managers/members before starting", ErrPreconditionFail, p.TeamSizeMin)
			}
			var trackCount int
			if err := tx.QueryRow(ctx, `SELECT count(*) FROM project_tracks WHERE project_id = $1`, pc.ProjectID).Scan(&trackCount); err != nil {
				return fmt.Errorf("workspace: count tracks: %w", err)
			}
			if trackCount < 1 {
				return fmt.Errorf("%w: at least one track is required before starting", ErrPreconditionFail)
			}
			if p.GitlabEnabled && p.TeamID == nil {
				return fmt.Errorf("%w: a GitLab team must be provisioned before starting (added in a later phase)", ErrPreconditionFail)
			}
			setActivatedAt = true
			setBriefClarifying = true
		case from == ProjectActive && to == ProjectCompleted:
			// contract-phase5.md 5b: a project can't be marked completed while
			// work is still actively moving — finish it, send it back to
			// backlog (todo/blocked), or explicitly close it (wont_do) first.
			openExecution, err := s.repo.CountOpenExecutionItems(ctx, tx, pc.ProjectID)
			if err != nil {
				return err
			}
			if openExecution > 0 {
				return ErrCompleteBlocked
			}
		}

		updated, err = s.repo.UpdateProjectStatus(ctx, tx, pc.ProjectID, from, to, setBriefClarifying, setActivatedAt, to == ProjectCompleted, CompletionFeedbackWindow)
		if err != nil {
			return err
		}

		if pc.Overseer && pc.MemberStatus != MemberActive {
			writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "project.oversee_action", "workspace_project", pc.ProjectID,
				map[string]string{"action": "status_changed", "from": from, "to": to})
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "project.status_changed", "workspace_project", pc.ProjectID,
			map[string]string{"from": from, "to": to})
		return nil
	})
	if err != nil {
		return nil, err
	}
	// contract-phase5.md 5b: archive the project's GitLab repo once it's
	// actually completed — best-effort and after commit, since a slow or
	// failing GitLab API call must never roll back (or block) the status
	// change itself.
	if to == ProjectCompleted && updated.GitlabEnabled && updated.TeamID != nil {
		s.archiveGitlabRepoBestEffort(ctx, pc.OrgID, *updated.TeamID)
	}
	return updated, nil
}

// archiveGitlabRepoBestEffort mirrors ProvisionGitlab/syncMRReviewers' own
// "resolve team, resolve client, one API call, log-only on failure" shape
// (service_gitlab.go) — never returns an error, since nothing downstream of
// SetProjectStatus should be able to fail on a GitLab archive attempt.
func (s *Service) archiveGitlabRepoBestEffort(ctx context.Context, orgID, teamID string) {
	if s.gitlab == nil {
		return
	}
	team, err := s.gitlab.GetTeam(ctx, orgID, teamID)
	if err != nil {
		slog.ErrorContext(ctx, "workspace: archive gitlab repo: resolve team", "team_id", teamID, "error", err)
		return
	}
	if team.GitlabProjectID == nil {
		return
	}
	client, err := s.gitlab.ClientForTeam(ctx, orgID, teamID)
	if err != nil {
		slog.ErrorContext(ctx, "workspace: archive gitlab repo: resolve client", "team_id", teamID, "error", err)
		return
	}
	if _, err := client.ArchiveProject(ctx, *team.GitlabProjectID); err != nil {
		slog.ErrorContext(ctx, "workspace: archive gitlab repo failed", "team_id", teamID, "error", err)
	}
}

// RotateShareToken mints a new token, invalidating the old link immediately.
func (s *Service) RotateShareToken(ctx context.Context, pc *ProjectCtx) (string, error) {
	if allowed, retryAfter := s.limiter.Allow(ctx, "rl:pw:rotate:"+pc.ProjectID, s.cfg.Workspace.RotateTokenPerHour, time.Hour); !allowed {
		return "", &RateLimitError{RetryAfter: retryAfter}
	}
	token, err := generateShareToken()
	if err != nil {
		return "", err
	}
	if err := s.repo.RotateShareToken(ctx, s.pool, pc.ProjectID, token); err != nil {
		return "", err
	}
	writeAudit(ctx, s.pool, pc.OrgID, &pc.UserID, "project.share_token_rotated", "workspace_project", pc.ProjectID, nil)
	return token, nil
}

// TransferOwner swaps the owner role onto an existing active manager.
func (s *Service) TransferOwner(ctx context.Context, pc *ProjectCtx, toUserID string) error {
	return s.repo.InTx(ctx, func(tx pgx.Tx) error {
		if _, err := s.repo.LockProject(ctx, tx, pc.ProjectID); err != nil {
			return err
		}
		target, err := s.repo.GetMember(ctx, tx, pc.ProjectID, toUserID)
		if err != nil {
			return err
		}
		if target.Role != RoleManager || target.Status != MemberActive {
			return fmt.Errorf("%w: transfer target must be an active manager", ErrInvalidInput)
		}
		if err := s.repo.SwapOwner(ctx, tx, pc.ProjectID, toUserID); err != nil {
			return err
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "project.owner_transferred", "workspace_project", pc.ProjectID,
			map[string]string{"to_user_id": toUserID})
		return nil
	})
}

// GetRequirement returns the current requirement plus its version history.
func (s *Service) GetRequirement(ctx context.Context, pc *ProjectCtx) (*RequirementView, error) {
	p, err := s.repo.GetProject(ctx, s.pool, pc.OrgID, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	versions, err := s.repo.ListRequirementVersions(ctx, s.pool, pc.ProjectID)
	if err != nil {
		return nil, err
	}
	return &RequirementView{Requirement: p.Requirement, RequirementVersion: p.RequirementVersion, BriefStatus: p.BriefStatus, Versions: versions}, nil
}

// UpdateRequirement (owner) appends a new requirement version and reopens
// brief review if it had already been agreed.
func (s *Service) UpdateRequirement(ctx context.Context, pc *ProjectCtx, text string) (*RequirementView, error) {
	text = strings.TrimSpace(text)
	if len(text) < RequirementMinLen || len(text) > RequirementMaxLen {
		return nil, &FieldError{Fields: map[string]string{
			"requirement": fmt.Sprintf("Requirement must be %d-%d characters.", RequirementMinLen, RequirementMaxLen),
		}}
	}
	var view *RequirementView
	err := s.repo.InTx(ctx, func(tx pgx.Tx) error {
		p, err := s.repo.LockProject(ctx, tx, pc.ProjectID)
		if err != nil {
			return err
		}
		newVersion := p.RequirementVersion + 1
		if err := s.repo.InsertRequirementVersion(ctx, tx, pc.ProjectID, newVersion, text, pc.UserID); err != nil {
			return err
		}
		updated, err := s.repo.UpdateRequirementText(ctx, tx, pc.ProjectID, text, newVersion)
		if err != nil {
			return err
		}

		// contract-phase3.md "UpdateRequirement (extend Phase 1)": a new
		// requirement version reopens every feature spec that was already
		// approved, since the spec may no longer match what's being asked for.
		reopened, err := s.repo.ListFeaturesWithApprovedDoc(ctx, tx, pc.ProjectID)
		if err != nil {
			return err
		}
		for _, feature := range reopened {
			if _, err := s.repo.SetDocStatus(ctx, tx, pc.ProjectID, feature.ID, DocInReview, nil, false); err != nil {
				return err
			}
			if err := s.repo.MarkChildTasksSpecChanged(ctx, tx, pc.ProjectID, feature.ID); err != nil {
				return err
			}
			reason := "requirement changed"
			if err := s.repo.InsertItemEvent(ctx, tx, eventInsert{
				ProjectID: pc.ProjectID, ItemID: feature.ID, ActorID: &pc.UserID, Source: SourceUser, Kind: EventDoc, Reason: &reason,
			}); err != nil {
				return err
			}
		}

		versions, err := s.repo.ListRequirementVersions(ctx, tx, pc.ProjectID)
		if err != nil {
			return err
		}
		writeAudit(ctx, tx, pc.OrgID, &pc.UserID, "project.requirement_updated", "workspace_project", pc.ProjectID,
			map[string]any{"version": newVersion, "features_reopened": len(reopened)})
		view = &RequirementView{Requirement: updated.Requirement, RequirementVersion: updated.RequirementVersion, BriefStatus: updated.BriefStatus, Versions: versions}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return view, nil
}
