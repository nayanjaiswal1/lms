package workspace

import (
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/mindforge/backend/internal/ai"
	"github.com/mindforge/backend/internal/calendar"
	"github.com/mindforge/backend/internal/certificates"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/gitlab"
	"github.com/mindforge/backend/internal/jobs"
	"github.com/mindforge/backend/internal/notifications"
	"github.com/mindforge/backend/internal/orgs"
	"github.com/mindforge/backend/internal/profile"
	"github.com/mindforge/backend/internal/ratelimit"
)

// Deps are the shared instances the workspace service needs; built once in
// internal/api/router.go. Later phases add fields here rather than growing a
// positional constructor.
type Deps struct {
	Pool    *pgxpool.Pool
	Cfg     *config.Config
	Perms   PermissionChecker
	Invites *orgs.InviteService
	Notif   *notifications.Service
	AI      ai.LLMProvider
	Jobs    *jobs.Registry
	Limiter *ratelimit.Limiter
	// Profile supplies an applicant's skills/GitHub link to RankInterest; nil
	// (jobs-only Deps) skips the profile signal.
	Profile *profile.Repo
	// Calendar backs Phase 3 meetings (contract-phase3.md) — nil in the
	// jobs-only Deps (cmd/server/main.go's workspaceSvcForJobs), which never
	// schedules a meeting.
	Calendar *calendar.Service
	// Gitlab backs Phase 4 GitLab provisioning/reviewer-sync (service_gitlab.go)
	// — nil in the jobs-only Deps, since none of the cron jobs
	// (inactivity_sweep, manager_digest, purge, reminders) touch GitLab. The
	// reverse direction (gitlab calling into workspace to link a ticket key)
	// goes through the late-bound gitlab.WorkItemLinker interface instead
	// (see gitlab.Service.SetWorkItemLinker's own doc comment) — this field
	// is the forward direction only, and creates no import cycle since gitlab
	// never imports workspace.
	Gitlab *gitlab.Service
	// Certificates backs Phase 5's project-completion certificate issuance
	// (service_feedback.go's IssueCertificate) — reuses certificates.Service's
	// additive project-completion path rather than duplicating cert issuance
	// here. nil in the jobs-only Deps (cmd/server/main.go's workspaceSvcForJobs):
	// no cron job issues certificates, only the owner-triggered HTTP route.
	Certificates *certificates.Service
	// Now is the clock; nil means time.Now. Tests inject a fixed clock for
	// reminder / cooldown / retention windows.
	Now func() time.Time
}

// Service holds every workspace flow. Each flow lives in its own
// service_*.go file; lifecycle rules come from statemachine.go only.
type Service struct {
	repo     *Repo
	pool     *pgxpool.Pool
	cfg      *config.Config
	perms    PermissionChecker
	invites  *orgs.InviteService
	notif    *notifications.Service
	ai       ai.LLMProvider
	jobs     *jobs.Registry
	limiter  *ratelimit.Limiter
	profile  *profile.Repo
	calendar *calendar.Service
	gitlab   *gitlab.Service
	certs    *certificates.Service
	now      func() time.Time
}

func NewService(d Deps) *Service {
	now := d.Now
	if now == nil {
		now = time.Now
	}
	return &Service{
		repo:     NewRepo(d.Pool),
		pool:     d.Pool,
		cfg:      d.Cfg,
		perms:    d.Perms,
		invites:  d.Invites,
		notif:    d.Notif,
		ai:       d.AI,
		jobs:     d.Jobs,
		limiter:  d.Limiter,
		profile:  d.Profile,
		calendar: d.Calendar,
		gitlab:   d.Gitlab,
		certs:    d.Certificates,
		now:      now,
	}
}

// Repo exposes the data layer (jobs and tests).
func (s *Service) Repo() *Repo { return s.repo }
