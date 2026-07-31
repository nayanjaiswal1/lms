package mcpconnect

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/mindforge/backend/internal/calendar"
	"github.com/mindforge/backend/internal/config"
	"github.com/mindforge/backend/internal/courses"
	"github.com/mindforge/backend/internal/interviewprep"
	"github.com/mindforge/backend/internal/mistakes"
	"github.com/mindforge/backend/internal/srs"
	"github.com/mindforge/backend/internal/systemdesign"
)

// Router wires the mcpconnect domain — OAuth 2.1+PKCE for external MCP
// clients, plus the MCP tool server itself — into the main chi router.
// Every tool delegates to an existing domain (courses, calendar, mistakes,
// srs, interviewprep, systemdesign); this package owns no content, progress,
// or event data of its own beyond connection/token bookkeeping.
type Router struct {
	cfg              *config.Config
	repo             *Repo
	coursesRepo      *courses.Repo
	coursesSvc       *courses.Service
	calendarSvc      *calendar.Service
	mistakesRepo     *mistakes.Repo
	mistakesSvc      *mistakes.Service
	srsRepo          *srs.Repo
	interviewPrepSvc *interviewprep.Service
	systemDesignSvc  *systemdesign.Service
}

// New builds the mcpconnect Router with its full dependency graph.
// coursesRepo/coursesSvc/calendarSvc/mistakesRepo/mistakesSvc/srsRepo/
// interviewPrepSvc/systemDesignSvc are the exact same instances the rest of
// the API router shares, so MCP tool calls are authorized by the identical
// rules — and enforce the identical daily rate limit, in interviewPrepSvc's
// case — as the student-facing API.
func New(cfg *config.Config, pool *pgxpool.Pool, coursesRepo *courses.Repo, coursesSvc *courses.Service, calendarSvc *calendar.Service, mistakesRepo *mistakes.Repo, mistakesSvc *mistakes.Service, srsRepo *srs.Repo, interviewPrepSvc *interviewprep.Service, systemDesignSvc *systemdesign.Service) *Router {
	return &Router{
		cfg: cfg, repo: NewRepo(pool),
		coursesRepo: coursesRepo, coursesSvc: coursesSvc, calendarSvc: calendarSvc,
		mistakesRepo: mistakesRepo, mistakesSvc: mistakesSvc, srsRepo: srsRepo,
		interviewPrepSvc: interviewPrepSvc, systemDesignSvc: systemDesignSvc,
	}
}
