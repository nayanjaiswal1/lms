package workspace

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"unicode/utf8"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/courses"
)

// cohortKeyPrefixAttempts bounds retries when concurrent creates race for the
// same key prefix (the unique constraint is the arbiter).
const cohortKeyPrefixAttempts = 5

// cohortRequirementFiller pads a short cohort description up to
// RequirementMinLen so the workspace's requirement is always valid.
const cohortRequirementFiller = "Deliver the cohort assignment as a team, following the shared cohort brief and checkpoints."

// CreateCohortWorkspaceRequest is POST /api/workspace-cohorts/{cohortID}/workspaces.
type CreateCohortWorkspaceRequest struct {
	Title         string   `json:"title"`
	MemberUserIDs []string `json:"member_user_ids"`
}

// nextFreeKeyPrefix returns the title-derived prefix, or the first
// base+letter variant not yet used in the org.
func (s *Service) nextFreeKeyPrefix(ctx context.Context, db DBTX, orgID, title string) (string, error) {
	base := deriveKeyPrefix(title)
	root := base[:min(len(base), 5)]
	candidates := []string{base}
	for c := 'A'; c <= 'Z'; c++ {
		candidates = append(candidates, root+string(c))
	}
	for _, c := range candidates {
		taken, err := s.repo.KeyPrefixTaken(ctx, db, orgID, c, "")
		if err != nil {
			return "", err
		}
		if !taken {
			return c, nil
		}
	}
	return "", ErrKeyPrefixTaken
}

// mapCohortGitlabErr maps gitlab sentinels (incl. ErrAlreadyOnTeam, which
// mapGitlabErr doesn't know) to workspace ones so they render 404/409.
func mapCohortGitlabErr(err error) error {
	if errors.Is(err, gitlab.ErrAlreadyOnTeam) {
		return fmt.Errorf("%w: %v", ErrConflict, err)
	}
	return mapGitlabErr(err)
}

// truncateRunes cuts s to at most max bytes without splitting a rune.
func truncateRunes(s string, max int) string {
	if len(s) <= max {
		return s
	}
	for max > 0 && !utf8.RuneStart(s[max]) {
		max--
	}
	return s[:max]
}

// CreateCohortWorkspace creates a workspace for one team of a cohort (a gitlab
// project_assignments row). The gitlab team + roster, the workspace row,
// owner/member rows, requirement and wiki space all land in ONE transaction;
// provisioning is enqueued only after commit. The fork itself is async via
// provision_team once the cohort is published.
func (s *Service) CreateCohortWorkspace(ctx context.Context, orgID, userID, cohortID string, req CreateCohortWorkspaceRequest) (*Project, error) {
	fields := map[string]string{}
	title := strings.TrimSpace(req.Title)
	if len(title) < TitleMinLen || len(title) > TitleMaxLen {
		fields["title"] = fmt.Sprintf("Title must be %d-%d characters.", TitleMinLen, TitleMaxLen)
	}
	seen := map[string]bool{}
	members := make([]string, 0, len(req.MemberUserIDs))
	for _, id := range req.MemberUserIDs {
		id = strings.TrimSpace(id)
		if id == "" || id == userID || seen[id] {
			continue
		}
		if _, err := uuid.Parse(id); err != nil {
			fields["member_user_ids"] = "Member ids must be valid user ids."
			continue
		}
		seen[id] = true
		members = append(members, id)
	}
	if len(members) >= TeamSizeCeiling {
		fields["member_user_ids"] = fmt.Sprintf("At most %d members.", TeamSizeCeiling-1)
	}
	if len(fields) > 0 {
		return nil, &FieldError{Fields: fields}
	}

	cohort, err := s.gitlab.GetAssignment(ctx, orgID, cohortID)
	if err != nil {
		return nil, mapCohortGitlabErr(fmt.Errorf("workspace: create cohort workspace: get cohort: %w", err))
	}
	if cohort.Status != gitlab.AssignmentStatusDraft && cohort.Status != gitlab.AssignmentStatusActive {
		return nil, fmt.Errorf("%w: cohort is %s", ErrConflict, cohort.Status)
	}
	requirement := strings.TrimSpace(cohort.Title)
	if cohort.Description != nil {
		requirement += "\n\n" + strings.TrimSpace(*cohort.Description)
	}
	if len(requirement) < RequirementMinLen {
		requirement += "\n\n" + cohortRequirementFiller
	}
	requirement = truncateRunes(requirement, RequirementMaxLen)

	token, err := generateShareToken()
	if err != nil {
		return nil, err
	}
	teamMin := max(TeamSizeFloor, len(members)+1)

	var project *Project
	var team *gitlab.ProjectTeam
	var provision bool
	for attempt := 0; attempt < cohortKeyPrefixAttempts; attempt++ {
		project, team, provision = nil, nil, false
		err = s.repo.InTx(ctx, func(tx pgx.Tx) error {
			for _, m := range members {
				active, err := s.repo.IsActiveOrgMember(ctx, tx, orgID, m)
				if err != nil {
					return err
				}
				if !active {
					return ErrNotOrgMember
				}
			}
			keyPrefix, err := s.nextFreeKeyPrefix(ctx, tx, orgID, title)
			if err != nil {
				return err
			}
			slug := courses.Slugify(title) + "-" + strings.ToLower(keyPrefix)
			team, provision, err = s.gitlab.CreateTeamWithMembersTx(ctx, tx, orgID, userID, cohortID, title, slug, members)
			if err != nil {
				return mapCohortGitlabErr(fmt.Errorf("workspace: create cohort workspace: team: %w", err))
			}
			createdBy := userID
			p, err := s.insertProjectTx(ctx, tx, userID, Project{
				OrgID: orgID, Title: title, Requirement: requirement,
				TeamSizeMin: teamMin, TeamSizeMax: TeamSizeCeiling,
				KeyPrefix: keyPrefix, ShareToken: token, GitlabEnabled: true,
				CreatedBy: &createdBy, TeamID: &team.ID, CohortID: &cohortID,
			}, slug)
			if err != nil {
				return err
			}
			for _, m := range members {
				if err := s.repo.UpsertMember(ctx, tx, p.ID, m, RoleMember, MemberActive, &createdBy); err != nil {
					return fmt.Errorf("workspace: create cohort workspace: member: %w", err)
				}
			}
			project = p
			return nil
		})
		if !errors.Is(err, ErrKeyPrefixTaken) {
			break
		}
	}
	if err != nil {
		return nil, err
	}
	if provision {
		s.gitlab.EnqueueNewTeamProvision(ctx, orgID, team.ID)
	}
	return project, nil
}
